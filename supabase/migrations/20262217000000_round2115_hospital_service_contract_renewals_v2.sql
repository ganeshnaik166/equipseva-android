BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_service_contract_renewals_v2_r2115 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  contract_label text NOT NULL,
  current_value_rupees bigint NOT NULL DEFAULT 0,
  renewal_value_rupees bigint NOT NULL DEFAULT 0,
  renewal_likelihood_pct numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','quoted','negotiating','renewed','lost','walked_away')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_renewal_v2_action_log_r2115 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  renewal_id uuid NOT NULL REFERENCES public.hospital_service_contract_renewals_v2_r2115(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('quote_sent','negotiation_call','final_offer','renewed','lost','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  value_change_rupees bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hscrv2_r2115_status ON public.hospital_service_contract_renewals_v2_r2115(status);
CREATE INDEX IF NOT EXISTS idx_hscrv2_r2115_captured ON public.hospital_service_contract_renewals_v2_r2115(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_hrv2_action_r2115_renewal ON public.hospital_renewal_v2_action_log_r2115(renewal_id);
CREATE INDEX IF NOT EXISTS idx_hrv2_action_r2115_taken ON public.hospital_renewal_v2_action_log_r2115(taken_at DESC);

ALTER TABLE public.hospital_service_contract_renewals_v2_r2115 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_renewal_v2_action_log_r2115 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hscrv2_r2115 ON public.hospital_service_contract_renewals_v2_r2115;
CREATE POLICY founder_all_hscrv2_r2115 ON public.hospital_service_contract_renewals_v2_r2115
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hrv2_action_r2115 ON public.hospital_renewal_v2_action_log_r2115;
CREATE POLICY founder_all_hrv2_action_r2115 ON public.hospital_renewal_v2_action_log_r2115
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_renewals
CREATE OR REPLACE FUNCTION public.list_renewals_r2115()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  contract_label text,
  current_value_rupees bigint,
  renewal_value_rupees bigint,
  renewal_likelihood_pct numeric,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_id, r.contract_label, r.current_value_rupees,
         r.renewal_value_rupees, r.renewal_likelihood_pct, r.status, r.captured_at
  FROM public.hospital_service_contract_renewals_v2_r2115 r
  ORDER BY r.captured_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: log_renewal
CREATE OR REPLACE FUNCTION public.log_renewal_r2115(
  p_hospital_id uuid,
  p_contract_label text,
  p_current_value_rupees bigint,
  p_renewal_value_rupees bigint,
  p_renewal_likelihood_pct numeric,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_contract_renewals_v2_r2115
    (hospital_id, contract_label, current_value_rupees, renewal_value_rupees, renewal_likelihood_pct, status)
  VALUES (p_hospital_id, p_contract_label, p_current_value_rupees, p_renewal_value_rupees, p_renewal_likelihood_pct, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_renewal_r2115',
          jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'status', p_status));

  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2115(p_renewal_id uuid)
RETURNS TABLE (
  id uuid,
  renewal_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  value_change_rupees bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.renewal_id, a.action_type, a.taken_at, a.by_email, a.value_change_rupees, a.notes_md
  FROM public.hospital_renewal_v2_action_log_r2115 a
  WHERE a.renewal_id = p_renewal_id
  ORDER BY a.taken_at DESC;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r2115(
  p_renewal_id uuid,
  p_action_type text,
  p_by_email text,
  p_value_change_rupees bigint,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_renewal_v2_action_log_r2115
    (renewal_id, action_type, by_email, value_change_rupees, notes_md)
  VALUES (p_renewal_id, p_action_type, p_by_email, p_value_change_rupees, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2115',
          jsonb_build_object('id', v_id, 'renewal_id', p_renewal_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2115(p_renewal_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_contract_renewals_v2_r2115
  SET status = p_status, updated_at = now()
  WHERE id = p_renewal_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2115',
          jsonb_build_object('renewal_id', p_renewal_id, 'status', p_status));
END;
$$;

-- RPC 6: high_likelihood
CREATE OR REPLACE FUNCTION public.high_likelihood_r2115()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  contract_label text,
  renewal_value_rupees bigint,
  renewal_likelihood_pct numeric,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_id, r.contract_label, r.renewal_value_rupees,
         r.renewal_likelihood_pct, r.status, r.captured_at
  FROM public.hospital_service_contract_renewals_v2_r2115 r
  WHERE r.renewal_likelihood_pct >= 70
    AND r.status IN ('pending','quoted','negotiating')
  ORDER BY r.renewal_likelihood_pct DESC, r.renewal_value_rupees DESC
  LIMIT 100;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2115()
RETURNS TABLE (
  id uuid,
  renewal_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  value_change_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.renewal_id, a.action_type, a.taken_at, a.by_email, a.value_change_rupees
  FROM public.hospital_renewal_v2_action_log_r2115 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_renewals_r2115() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_renewal_r2115(uuid, text, bigint, bigint, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2115(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2115(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2115(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.high_likelihood_r2115() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2115() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_renewals_r2115() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_renewal_r2115(uuid, text, bigint, bigint, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2115(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2115(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2115(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.high_likelihood_r2115() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2115() TO authenticated;

COMMIT;
