BEGIN;

-- ============================================================================
-- Round 1931 — Hospital Annual Spend Forecast
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_annual_spend_forecast_r1931 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fiscal_year text NOT NULL,
  forecast_amount_rupees bigint NOT NULL DEFAULT 0,
  actual_spend_rupees bigint NOT NULL DEFAULT 0,
  variance_pct numeric(8,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'projected' CHECK (status IN ('projected','in_period','closed','escalated')),
  forecasted_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hasf_r1931_hospital ON public.hospital_annual_spend_forecast_r1931(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hasf_r1931_status ON public.hospital_annual_spend_forecast_r1931(status);
CREATE INDEX IF NOT EXISTS idx_hasf_r1931_year ON public.hospital_annual_spend_forecast_r1931(fiscal_year);

ALTER TABLE public.hospital_annual_spend_forecast_r1931 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hasf_r1931_founder ON public.hospital_annual_spend_forecast_r1931;
CREATE POLICY hasf_r1931_founder ON public.hospital_annual_spend_forecast_r1931
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_spend_review_log_r1931 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forecast_id uuid NOT NULL REFERENCES public.hospital_annual_spend_forecast_r1931(id) ON DELETE CASCADE,
  review_type text NOT NULL CHECK (review_type IN ('quarterly','annual','escalation','contract_renewal')),
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  action_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsrl_r1931_forecast ON public.hospital_spend_review_log_r1931(forecast_id);
CREATE INDEX IF NOT EXISTS idx_hsrl_r1931_reviewed ON public.hospital_spend_review_log_r1931(reviewed_at DESC);

ALTER TABLE public.hospital_spend_review_log_r1931 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsrl_r1931_founder ON public.hospital_spend_review_log_r1931;
CREATE POLICY hsrl_r1931_founder ON public.hospital_spend_review_log_r1931
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_forecasts_r1931()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  fiscal_year text,
  forecast_amount_rupees bigint,
  actual_spend_rupees bigint,
  variance_pct numeric,
  status text,
  forecasted_at timestamptz,
  closed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.id, f.hospital_id, f.fiscal_year, f.forecast_amount_rupees,
         f.actual_spend_rupees, f.variance_pct, f.status, f.forecasted_at, f.closed_at
  FROM public.hospital_annual_spend_forecast_r1931 f
  ORDER BY f.forecasted_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_forecast_r1931(
  p_hospital_id uuid,
  p_fiscal_year text,
  p_forecast_amount_rupees bigint,
  p_actual_spend_rupees bigint,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_variance numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_forecast_amount_rupees > 0 THEN
    v_variance := ((p_actual_spend_rupees - p_forecast_amount_rupees)::numeric / p_forecast_amount_rupees::numeric) * 100;
  ELSE
    v_variance := 0;
  END IF;
  INSERT INTO public.hospital_annual_spend_forecast_r1931
    (hospital_id, fiscal_year, forecast_amount_rupees, actual_spend_rupees, variance_pct, status)
  VALUES (p_hospital_id, p_fiscal_year, p_forecast_amount_rupees, p_actual_spend_rupees, v_variance, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_forecast_r1931',
    jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'fiscal_year', p_fiscal_year, 'status', p_status)
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_reviews_r1931(p_forecast_id uuid)
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  review_type text,
  reviewed_at timestamptz,
  by_email text,
  action_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.forecast_id, r.review_type, r.reviewed_at, r.by_email, r.action_md
  FROM public.hospital_spend_review_log_r1931 r
  WHERE r.forecast_id = p_forecast_id
  ORDER BY r.reviewed_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_review_r1931(
  p_forecast_id uuid,
  p_review_type text,
  p_by_email text,
  p_action_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_spend_review_log_r1931 (forecast_id, review_type, by_email, action_md)
  VALUES (p_forecast_id, p_review_type, p_by_email, p_action_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_review_r1931',
    jsonb_build_object('id', v_id, 'forecast_id', p_forecast_id, 'review_type', p_review_type)
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_closed_r1931(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.hospital_annual_spend_forecast_r1931
  SET status = 'closed', closed_at = now(), updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_closed_r1931',
    jsonb_build_object('id', p_id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.top_overrun_forecasts_r1931()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  fiscal_year text,
  forecast_amount_rupees bigint,
  actual_spend_rupees bigint,
  variance_pct numeric,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.id, f.hospital_id, f.fiscal_year, f.forecast_amount_rupees,
         f.actual_spend_rupees, f.variance_pct, f.status
  FROM public.hospital_annual_spend_forecast_r1931 f
  WHERE f.variance_pct > 0
  ORDER BY f.variance_pct DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_reviews_r1931()
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  review_type text,
  reviewed_at timestamptz,
  by_email text,
  action_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.forecast_id, r.review_type, r.reviewed_at, r.by_email, r.action_md
  FROM public.hospital_spend_review_log_r1931 r
  ORDER BY r.reviewed_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_forecasts_r1931() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_forecast_r1931(uuid, text, bigint, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reviews_r1931(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_review_r1931(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_closed_r1931(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_overrun_forecasts_r1931() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_reviews_r1931() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_forecasts_r1931() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_forecast_r1931(uuid, text, bigint, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reviews_r1931(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_review_r1931(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_closed_r1931(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_overrun_forecasts_r1931() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reviews_r1931() TO authenticated;

COMMIT;
