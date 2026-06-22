BEGIN;

-- Engineer field equipment failures
CREATE TABLE IF NOT EXISTS public.engineer_field_equipment_failures_r1900 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  hospital_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  equipment_name text NOT NULL,
  failure_type text NOT NULL CHECK (failure_type IN ('engineer_caught','hospital_reported','diagnostic','wear_tear')),
  failure_at timestamptz NOT NULL DEFAULT now(),
  root_cause_md text,
  repaired_in_same_visit boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','repaired','escalated','replaced')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efef_r1900_engineer ON public.engineer_field_equipment_failures_r1900(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_efef_r1900_hospital ON public.engineer_field_equipment_failures_r1900(hospital_id);
CREATE INDEX IF NOT EXISTS idx_efef_r1900_status ON public.engineer_field_equipment_failures_r1900(status);
CREATE INDEX IF NOT EXISTS idx_efef_r1900_failure_at ON public.engineer_field_equipment_failures_r1900(failure_at DESC);

ALTER TABLE public.engineer_field_equipment_failures_r1900 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS efef_r1900_founder_all ON public.engineer_field_equipment_failures_r1900;
CREATE POLICY efef_r1900_founder_all ON public.engineer_field_equipment_failures_r1900
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Engineer failure response log
CREATE TABLE IF NOT EXISTS public.engineer_failure_response_log_r1900 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  failure_id uuid NOT NULL REFERENCES public.engineer_field_equipment_failures_r1900(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('immediate_repair','scheduled_repair','escalate_to_specialist','replace_equipment','order_parts')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efrl_r1900_failure ON public.engineer_failure_response_log_r1900(failure_id);
CREATE INDEX IF NOT EXISTS idx_efrl_r1900_taken ON public.engineer_failure_response_log_r1900(taken_at DESC);

ALTER TABLE public.engineer_failure_response_log_r1900 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS efrl_r1900_founder_all ON public.engineer_failure_response_log_r1900;
CREATE POLICY efrl_r1900_founder_all ON public.engineer_failure_response_log_r1900
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_failures
CREATE OR REPLACE FUNCTION public.list_failures_r1900()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  hospital_name text,
  equipment_name text,
  failure_type text,
  failure_at timestamptz,
  repaired_in_same_visit boolean,
  status text,
  root_cause_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id,
         p.email::text,
         o.name::text,
         f.equipment_name,
         f.failure_type,
         f.failure_at,
         f.repaired_in_same_visit,
         f.status,
         f.root_cause_md
  FROM public.engineer_field_equipment_failures_r1900 f
  LEFT JOIN public.profiles p ON p.id = f.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = f.hospital_id
  ORDER BY f.failure_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: log_failure
CREATE OR REPLACE FUNCTION public.log_failure_r1900(
  p_engineer_user_id uuid,
  p_repair_job_id uuid,
  p_hospital_id uuid,
  p_equipment_name text,
  p_failure_type text,
  p_root_cause_md text,
  p_repaired_in_same_visit boolean
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_field_equipment_failures_r1900(
    engineer_user_id, repair_job_id, hospital_id, equipment_name,
    failure_type, root_cause_md, repaired_in_same_visit
  ) VALUES (
    p_engineer_user_id, p_repair_job_id, p_hospital_id, p_equipment_name,
    p_failure_type, p_root_cause_md, COALESCE(p_repaired_in_same_visit, false)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_failure_r1900',
          jsonb_build_object('failure_id', v_id, 'engineer_user_id', p_engineer_user_id, 'equipment_name', p_equipment_name));

  RETURN v_id;
END;
$$;

-- RPC 3: list_responses
CREATE OR REPLACE FUNCTION public.list_responses_r1900(p_failure_id uuid)
RETURNS TABLE (
  id uuid,
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
  SELECT r.id, r.action_type, r.taken_at, r.by_email, r.outcome
  FROM public.engineer_failure_response_log_r1900 r
  WHERE r.failure_id = p_failure_id
  ORDER BY r.taken_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: log_response
CREATE OR REPLACE FUNCTION public.log_response_r1900(
  p_failure_id uuid,
  p_action_type text,
  p_outcome text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_failure_response_log_r1900(failure_id, action_type, by_email, outcome)
  VALUES (p_failure_id, p_action_type, (auth.jwt()->>'email'), p_outcome)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_response_r1900',
          jsonb_build_object('response_id', v_id, 'failure_id', p_failure_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- RPC 5: mark_repaired
CREATE OR REPLACE FUNCTION public.mark_repaired_r1900(p_failure_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_field_equipment_failures_r1900
  SET status = 'repaired', updated_at = now()
  WHERE id = p_failure_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_repaired_r1900',
          jsonb_build_object('failure_id', p_failure_id));
END;
$$;

-- RPC 6: failure_pattern_summary
CREATE OR REPLACE FUNCTION public.failure_pattern_summary_r1900()
RETURNS TABLE (
  failure_type text,
  total_count int,
  repaired_count int,
  open_count int,
  same_visit_repair_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.failure_type,
         COUNT(*)::int,
         (COUNT(*) FILTER (WHERE f.status = 'repaired'))::int,
         (COUNT(*) FILTER (WHERE f.status = 'open'))::int,
         (COUNT(*) FILTER (WHERE f.repaired_in_same_visit))::int
  FROM public.engineer_field_equipment_failures_r1900 f
  GROUP BY f.failure_type
  ORDER BY COUNT(*) DESC;
END;
$$;

-- RPC 7: recent_responses
CREATE OR REPLACE FUNCTION public.recent_responses_r1900()
RETURNS TABLE (
  id uuid,
  failure_id uuid,
  equipment_name text,
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
  SELECT r.id, r.failure_id, f.equipment_name, r.action_type, r.taken_at, r.by_email, r.outcome
  FROM public.engineer_failure_response_log_r1900 r
  LEFT JOIN public.engineer_field_equipment_failures_r1900 f ON f.id = r.failure_id
  ORDER BY r.taken_at DESC
  LIMIT 100;
END;
$$;

-- Permissions
REVOKE EXECUTE ON FUNCTION public.list_failures_r1900() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_failures_r1900() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_failure_r1900(uuid, uuid, uuid, text, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_failure_r1900(uuid, uuid, uuid, text, text, text, boolean) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_responses_r1900(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_responses_r1900(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_response_r1900(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_response_r1900(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_repaired_r1900(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_repaired_r1900(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.failure_pattern_summary_r1900() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.failure_pattern_summary_r1900() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_responses_r1900() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_responses_r1900() TO authenticated;

COMMIT;
