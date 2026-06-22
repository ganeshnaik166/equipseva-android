BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_service_contract_renewals_r1939 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  contract_label text NOT NULL,
  current_value_rupees bigint NOT NULL DEFAULT 0,
  renewal_value_rupees bigint NOT NULL DEFAULT 0,
  renewal_date date NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','quoted','negotiating','renewed','lost','walked_away')),
  risk_score int NOT NULL DEFAULT 5 CHECK (risk_score BETWEEN 1 AND 10),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_renewal_action_log_r1939 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  renewal_id uuid NOT NULL REFERENCES public.hospital_service_contract_renewals_r1939(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('quote_sent','negotiation_call','final_offer','won','lost','walked')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_service_contract_renewals_r1939 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_renewal_action_log_r1939 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_renewals_r1939 ON public.hospital_service_contract_renewals_r1939;
CREATE POLICY founder_all_renewals_r1939 ON public.hospital_service_contract_renewals_r1939
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actionlog_r1939 ON public.hospital_renewal_action_log_r1939;
CREATE POLICY founder_all_actionlog_r1939 ON public.hospital_renewal_action_log_r1939
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_renewals_r1939()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  contract_label text,
  current_value_rupees bigint,
  renewal_value_rupees bigint,
  renewal_date date,
  status text,
  risk_score int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.hospital_id, p.email, r.contract_label, r.current_value_rupees,
           r.renewal_value_rupees, r.renewal_date, r.status, r.risk_score, r.created_at
    FROM public.hospital_service_contract_renewals_r1939 r
    LEFT JOIN public.profiles p ON p.id = r.hospital_id
    ORDER BY r.renewal_date ASC, r.created_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_renewal_r1939(
  p_hospital_id uuid,
  p_contract_label text,
  p_current_value_rupees bigint,
  p_renewal_value_rupees bigint,
  p_renewal_date date,
  p_risk_score int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_contract_renewals_r1939
    (hospital_id, contract_label, current_value_rupees, renewal_value_rupees, renewal_date, risk_score)
    VALUES (p_hospital_id, p_contract_label, p_current_value_rupees, p_renewal_value_rupees, p_renewal_date, p_risk_score)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_renewal_r1939',
      jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'label', p_contract_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1939(p_renewal_id uuid)
RETURNS TABLE (
  id uuid,
  renewal_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.renewal_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_renewal_action_log_r1939 a
    WHERE a.renewal_id = p_renewal_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1939(
  p_renewal_id uuid,
  p_action_type text,
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
  INSERT INTO public.hospital_renewal_action_log_r1939
    (renewal_id, action_type, by_email, notes_md)
    VALUES (p_renewal_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1939',
      jsonb_build_object('id', v_id, 'renewal_id', p_renewal_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1939(
  p_renewal_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('pending','quoted','negotiating','renewed','lost','walked_away') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.hospital_service_contract_renewals_r1939
    SET status = p_status, updated_at = now()
    WHERE id = p_renewal_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1939',
      jsonb_build_object('id', p_renewal_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.at_risk_renewals_r1939()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  contract_label text,
  current_value_rupees bigint,
  renewal_value_rupees bigint,
  renewal_date date,
  status text,
  risk_score int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.hospital_id, p.email, r.contract_label, r.current_value_rupees,
           r.renewal_value_rupees, r.renewal_date, r.status, r.risk_score
    FROM public.hospital_service_contract_renewals_r1939 r
    LEFT JOIN public.profiles p ON p.id = r.hospital_id
    WHERE r.risk_score >= 7
      AND r.status IN ('pending','quoted','negotiating')
    ORDER BY r.risk_score DESC, r.renewal_date ASC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1939()
RETURNS TABLE (
  id uuid,
  renewal_id uuid,
  contract_label text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.renewal_id, r.contract_label, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_renewal_action_log_r1939 a
    LEFT JOIN public.hospital_service_contract_renewals_r1939 r ON r.id = a.renewal_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_renewals_r1939() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_renewal_r1939(uuid, text, bigint, bigint, date, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1939(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1939(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1939(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_renewals_r1939() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1939() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_renewals_r1939() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_renewal_r1939(uuid, text, bigint, bigint, date, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1939(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1939(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1939(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_renewals_r1939() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1939() TO authenticated;

COMMIT;
