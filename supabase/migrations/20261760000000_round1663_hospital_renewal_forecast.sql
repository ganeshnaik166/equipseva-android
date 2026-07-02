BEGIN;

-- ============================================================================
-- r1663 Hospital Renewal Forecast
-- AMC renewal forecast: per-hospital expiring contracts, likelihood, revenue at
-- risk, action queue.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_amc_renewal_forecasts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  expiry_date date NOT NULL,
  monthly_fee_rupees numeric(12,2) NOT NULL DEFAULT 0,
  renewal_likelihood text NOT NULL DEFAULT 'med' CHECK (renewal_likelihood IN ('low','med','high')),
  risk_note text,
  last_assessed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (contract_id)
);

CREATE INDEX IF NOT EXISTS idx_r1663_forecast_hospital   ON public.hospital_amc_renewal_forecasts(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_r1663_forecast_expiry     ON public.hospital_amc_renewal_forecasts(expiry_date);
CREATE INDEX IF NOT EXISTS idx_r1663_forecast_likelihood ON public.hospital_amc_renewal_forecasts(renewal_likelihood);

CREATE TABLE IF NOT EXISTS public.hospital_amc_renewal_actions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  forecast_id uuid NOT NULL REFERENCES public.hospital_amc_renewal_forecasts(id) ON DELETE CASCADE,
  action_type text NOT NULL,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','cancelled')),
  taken_at timestamptz,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_r1663_action_forecast ON public.hospital_amc_renewal_actions(forecast_id);
CREATE INDEX IF NOT EXISTS idx_r1663_action_status   ON public.hospital_amc_renewal_actions(status);

ALTER TABLE public.hospital_amc_renewal_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_amc_renewal_actions   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS r1663_forecast_founder_all ON public.hospital_amc_renewal_forecasts;
CREATE POLICY r1663_forecast_founder_all ON public.hospital_amc_renewal_forecasts
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS r1663_action_founder_all ON public.hospital_amc_renewal_actions;
CREATE POLICY r1663_action_founder_all ON public.hospital_amc_renewal_actions
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: founder_list_renewal_forecasts
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_list_renewal_forecasts()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  hospital_city text,
  contract_id uuid,
  amc_tier text,
  expiry_date date,
  days_to_expiry int,
  monthly_fee_rupees numeric,
  renewal_likelihood text,
  risk_note text,
  last_assessed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    f.hospital_user_id,
    COALESCE(o.name, p.full_name, p.email) AS hospital_name,
    o.city AS hospital_city,
    f.contract_id,
    c.amc_tier::text,
    f.expiry_date,
    (f.expiry_date - CURRENT_DATE)::int AS days_to_expiry,
    f.monthly_fee_rupees,
    f.renewal_likelihood,
    f.risk_note,
    f.last_assessed_at
  FROM public.hospital_amc_renewal_forecasts f
  LEFT JOIN public.amc_contracts c ON c.id = f.contract_id
  LEFT JOIN public.profiles p      ON p.id = f.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY f.expiry_date ASC, f.renewal_likelihood ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_list_renewal_forecasts() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_list_renewal_forecasts() TO authenticated;

-- ============================================================================
-- RPC 2: founder_assess_forecast (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_assess_forecast(
  p_contract_id uuid,
  p_likelihood text,
  p_risk_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
VOLATILE
AS $$
DECLARE
  v_id uuid;
  v_hospital uuid;
  v_expiry date;
  v_fee numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_likelihood NOT IN ('low','med','high') THEN
    RAISE EXCEPTION 'invalid likelihood: %', p_likelihood;
  END IF;

  SELECT hospital_user_id,
         COALESCE(deactivated_at::date, (activated_at + interval '365 days')::date, CURRENT_DATE + 30),
         monthly_fee_rupees
    INTO v_hospital, v_expiry, v_fee
    FROM public.amc_contracts
   WHERE id = p_contract_id;

  IF v_hospital IS NULL THEN
    RAISE EXCEPTION 'contract not found';
  END IF;

  INSERT INTO public.hospital_amc_renewal_forecasts AS f
    (hospital_user_id, contract_id, expiry_date, monthly_fee_rupees, renewal_likelihood, risk_note, last_assessed_at)
  VALUES
    (v_hospital, p_contract_id, v_expiry, COALESCE(v_fee, 0), p_likelihood, p_risk_note, now())
  ON CONFLICT (contract_id) DO UPDATE
    SET renewal_likelihood = EXCLUDED.renewal_likelihood,
        risk_note          = EXCLUDED.risk_note,
        last_assessed_at   = now(),
        updated_at         = now()
  RETURNING f.id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1663_assess_forecast',
          jsonb_build_object('id', v_id, 'contract_id', p_contract_id, 'likelihood', p_likelihood));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_assess_forecast(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_assess_forecast(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 3: founder_add_action (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_add_action(
  p_forecast_id uuid,
  p_action_type text,
  p_owner_email text DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
VOLATILE
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.hospital_amc_renewal_actions
    (forecast_id, action_type, owner_email, status, note)
  VALUES
    (p_forecast_id, p_action_type, p_owner_email, 'open', p_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1663_add_action',
          jsonb_build_object('id', v_id, 'forecast_id', p_forecast_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_add_action(uuid, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_add_action(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 4: founder_complete_action (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_complete_action(
  p_action_id uuid,
  p_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
VOLATILE
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.hospital_amc_renewal_actions
     SET status = 'done',
         taken_at = now(),
         note = COALESCE(p_note, note),
         updated_at = now()
   WHERE id = p_action_id
   RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'action not found';
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1663_complete_action',
          jsonb_build_object('id', v_id, 'note', p_note));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_complete_action(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_complete_action(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 5: founder_renewal_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_renewal_summary()
RETURNS TABLE (
  total_forecasts int,
  total_revenue_at_risk_rupees numeric,
  low_count int,
  med_count int,
  high_count int,
  open_actions int,
  done_actions int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.hospital_amc_renewal_forecasts)::int AS total_forecasts,
    COALESCE((SELECT SUM(monthly_fee_rupees * 12)
                FROM public.hospital_amc_renewal_forecasts
               WHERE renewal_likelihood IN ('low','med')), 0)::numeric AS total_revenue_at_risk_rupees,
    (COUNT(*) FILTER (WHERE renewal_likelihood = 'low'))::int  AS low_count,
    (COUNT(*) FILTER (WHERE renewal_likelihood = 'med'))::int  AS med_count,
    (COUNT(*) FILTER (WHERE renewal_likelihood = 'high'))::int AS high_count,
    (SELECT (COUNT(*) FILTER (WHERE status IN ('open','in_progress')))::int
       FROM public.hospital_amc_renewal_actions) AS open_actions,
    (SELECT (COUNT(*) FILTER (WHERE status = 'done'))::int
       FROM public.hospital_amc_renewal_actions) AS done_actions
  FROM public.hospital_amc_renewal_forecasts;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_renewal_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_renewal_summary() TO authenticated;

-- ============================================================================
-- RPC 6: founder_expiring_in_window
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_expiring_in_window(p_days int)
RETURNS TABLE (
  id uuid,
  hospital_name text,
  amc_tier text,
  expiry_date date,
  days_to_expiry int,
  monthly_fee_rupees numeric,
  renewal_likelihood text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    COALESCE(o.name, p.full_name, p.email) AS hospital_name,
    c.amc_tier::text,
    f.expiry_date,
    (f.expiry_date - CURRENT_DATE)::int AS days_to_expiry,
    f.monthly_fee_rupees,
    f.renewal_likelihood
  FROM public.hospital_amc_renewal_forecasts f
  LEFT JOIN public.amc_contracts c ON c.id = f.contract_id
  LEFT JOIN public.profiles p      ON p.id = f.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE f.expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + GREATEST(p_days, 0))
  ORDER BY f.expiry_date ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_expiring_in_window(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_expiring_in_window(int) TO authenticated;

-- ============================================================================
-- RPC 7: founder_high_risk_renewals
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_high_risk_renewals()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  hospital_city text,
  amc_tier text,
  expiry_date date,
  days_to_expiry int,
  monthly_fee_rupees numeric,
  annual_revenue_at_risk numeric,
  risk_note text,
  last_assessed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    COALESCE(o.name, p.full_name, p.email) AS hospital_name,
    o.city AS hospital_city,
    c.amc_tier::text,
    f.expiry_date,
    (f.expiry_date - CURRENT_DATE)::int AS days_to_expiry,
    f.monthly_fee_rupees,
    (f.monthly_fee_rupees * 12)::numeric AS annual_revenue_at_risk,
    f.risk_note,
    f.last_assessed_at
  FROM public.hospital_amc_renewal_forecasts f
  LEFT JOIN public.amc_contracts c ON c.id = f.contract_id
  LEFT JOIN public.profiles p      ON p.id = f.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE f.renewal_likelihood = 'low'
  ORDER BY f.expiry_date ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_high_risk_renewals() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_high_risk_renewals() TO authenticated;

COMMIT;