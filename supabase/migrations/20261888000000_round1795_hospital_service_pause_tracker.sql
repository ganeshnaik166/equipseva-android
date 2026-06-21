BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_service_pauses_r1795 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pause_start timestamptz NOT NULL DEFAULT now(),
  pause_end timestamptz,
  pause_reason text NOT NULL CHECK (pause_reason IN ('vacation','equipment_offline','financial_hold','dispute','seasonal')),
  expected_resume_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','resumed','extended','converted_to_churn')),
  resumed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsp_r1795_hospital ON public.hospital_service_pauses_r1795(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hsp_r1795_status ON public.hospital_service_pauses_r1795(status);
CREATE INDEX IF NOT EXISTS idx_hsp_r1795_start ON public.hospital_service_pauses_r1795(pause_start DESC);

CREATE TABLE IF NOT EXISTS public.hospital_pause_resume_actions_r1795 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pause_id uuid NOT NULL REFERENCES public.hospital_service_pauses_r1795(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('check_in','incentive_offer','founder_call','escalation')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpra_r1795_pause ON public.hospital_pause_resume_actions_r1795(pause_id);
CREATE INDEX IF NOT EXISTS idx_hpra_r1795_taken ON public.hospital_pause_resume_actions_r1795(taken_at DESC);

ALTER TABLE public.hospital_service_pauses_r1795 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_pause_resume_actions_r1795 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsp_r1795_founder_all ON public.hospital_service_pauses_r1795;
CREATE POLICY hsp_r1795_founder_all ON public.hospital_service_pauses_r1795
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hpra_r1795_founder_all ON public.hospital_pause_resume_actions_r1795;
CREATE POLICY hpra_r1795_founder_all ON public.hospital_pause_resume_actions_r1795
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- list_pauses_r1795
CREATE OR REPLACE FUNCTION public.list_pauses_r1795(p_status text DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  organization_name text,
  pause_start timestamptz,
  pause_end timestamptz,
  pause_reason text,
  expected_resume_at timestamptz,
  status text,
  resumed_at timestamptz,
  days_paused int,
  action_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.hospital_user_id,
    pr.email AS hospital_email,
    o.name AS organization_name,
    p.pause_start,
    p.pause_end,
    p.pause_reason,
    p.expected_resume_at,
    p.status,
    p.resumed_at,
    GREATEST(0, EXTRACT(DAY FROM (COALESCE(p.resumed_at, now()) - p.pause_start))::int) AS days_paused,
    (SELECT COUNT(*) FROM public.hospital_pause_resume_actions_r1795 a WHERE a.pause_id = p.id) AS action_count
  FROM public.hospital_service_pauses_r1795 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = pr.organization_id
  WHERE (p_status IS NULL OR p.status = p_status)
  ORDER BY p.pause_start DESC
  LIMIT p_limit;
END;
$$;

-- log_pause_r1795
CREATE OR REPLACE FUNCTION public.log_pause_r1795(
  p_hospital_user_id uuid,
  p_pause_reason text,
  p_expected_resume_at timestamptz,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_pauses_r1795(hospital_user_id, pause_reason, expected_resume_at, notes)
  VALUES (p_hospital_user_id, p_pause_reason, p_expected_resume_at, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pause_r1795', jsonb_build_object('pause_id', v_id, 'hospital_user_id', p_hospital_user_id, 'reason', p_pause_reason));

  RETURN v_id;
END;
$$;

-- list_actions_r1795
CREATE OR REPLACE FUNCTION public.list_actions_r1795(p_pause_id uuid)
RETURNS TABLE(
  id uuid,
  pause_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.pause_id, a.action_type, a.taken_at, a.by_email, a.outcome
  FROM public.hospital_pause_resume_actions_r1795 a
  WHERE a.pause_id = p_pause_id
  ORDER BY a.taken_at DESC;
END;
$$;

-- log_action_r1795
CREATE OR REPLACE FUNCTION public.log_action_r1795(
  p_pause_id uuid,
  p_action_type text,
  p_outcome text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_pause_resume_actions_r1795(pause_id, action_type, by_email, outcome)
  VALUES (p_pause_id, p_action_type, (auth.jwt()->>'email'), p_outcome)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1795', jsonb_build_object('action_id', v_id, 'pause_id', p_pause_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- resume_service_r1795
CREATE OR REPLACE FUNCTION public.resume_service_r1795(p_pause_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_pauses_r1795
  SET status = 'resumed', resumed_at = now(), pause_end = now(), updated_at = now()
  WHERE id = p_pause_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'resume_service_r1795', jsonb_build_object('pause_id', p_pause_id));
END;
$$;

-- active_pauses_summary_r1795
CREATE OR REPLACE FUNCTION public.active_pauses_summary_r1795()
RETURNS TABLE(
  pause_reason text,
  active_count int,
  avg_days_paused numeric,
  longest_days int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.pause_reason,
    (COUNT(*) FILTER (WHERE p.status = 'active'))::int AS active_count,
    ROUND(AVG(EXTRACT(DAY FROM (COALESCE(p.resumed_at, now()) - p.pause_start)))::numeric, 1) AS avg_days_paused,
    MAX(EXTRACT(DAY FROM (COALESCE(p.resumed_at, now()) - p.pause_start)))::int AS longest_days
  FROM public.hospital_service_pauses_r1795 p
  GROUP BY p.pause_reason
  ORDER BY active_count DESC;
END;
$$;

-- churn_risk_pauses_r1795
CREATE OR REPLACE FUNCTION public.churn_risk_pauses_r1795()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  organization_name text,
  pause_reason text,
  pause_start timestamptz,
  expected_resume_at timestamptz,
  days_paused int,
  days_overdue int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.hospital_user_id,
    pr.email AS hospital_email,
    o.name AS organization_name,
    p.pause_reason,
    p.pause_start,
    p.expected_resume_at,
    EXTRACT(DAY FROM (now() - p.pause_start))::int AS days_paused,
    GREATEST(0, EXTRACT(DAY FROM (now() - COALESCE(p.expected_resume_at, p.pause_start)))::int) AS days_overdue,
    p.status
  FROM public.hospital_service_pauses_r1795 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = pr.organization_id
  WHERE p.status IN ('active','extended')
    AND (
      p.expected_resume_at IS NOT NULL AND now() > p.expected_resume_at
      OR EXTRACT(DAY FROM (now() - p.pause_start)) > 30
      OR p.pause_reason IN ('financial_hold','dispute')
    )
  ORDER BY days_paused DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pauses_r1795(text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pause_r1795(uuid, text, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1795(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1795(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.resume_service_r1795(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_pauses_summary_r1795() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.churn_risk_pauses_r1795() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pauses_r1795(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pause_r1795(uuid, text, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1795(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1795(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resume_service_r1795(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_pauses_summary_r1795() TO authenticated;
GRANT EXECUTE ON FUNCTION public.churn_risk_pauses_r1795() TO authenticated;

COMMIT;