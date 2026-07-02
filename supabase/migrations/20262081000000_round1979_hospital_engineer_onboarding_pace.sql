BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_engineer_onboarding_pace_r1979 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  first_visit_at timestamptz,
  jobs_first_30d int NOT NULL DEFAULT 0,
  jobs_first_60d int NOT NULL DEFAULT 0,
  jobs_first_90d int NOT NULL DEFAULT 0,
  ramp_status text NOT NULL DEFAULT 'normal' CHECK (ramp_status IN ('fast','normal','slow','blocked')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_onboarding_pace_action_log_r1979 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pace_id uuid NOT NULL REFERENCES public.hospital_engineer_onboarding_pace_r1979(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('support_provided','shadow_assigned','training_added','recovery_plan','rotated_away')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_engineer_onboarding_pace_r1979 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_onboarding_pace_action_log_r1979 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pace_r1979 ON public.hospital_engineer_onboarding_pace_r1979;
CREATE POLICY founder_all_pace_r1979 ON public.hospital_engineer_onboarding_pace_r1979
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_pace_action_r1979 ON public.hospital_onboarding_pace_action_log_r1979;
CREATE POLICY founder_all_pace_action_r1979 ON public.hospital_onboarding_pace_action_log_r1979
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_paces_r1979()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  engineer_user_id uuid,
  engineer_email text,
  first_visit_at timestamptz,
  jobs_first_30d int,
  jobs_first_60d int,
  jobs_first_90d int,
  ramp_status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.hospital_id, o.name, p.engineer_user_id, pr.email,
           p.first_visit_at, p.jobs_first_30d, p.jobs_first_60d, p.jobs_first_90d,
           p.ramp_status, p.captured_at
    FROM public.hospital_engineer_onboarding_pace_r1979 p
    LEFT JOIN public.organizations o ON o.id = p.hospital_id
    LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
    ORDER BY p.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_pace_r1979(
  p_hospital_id uuid,
  p_engineer_user_id uuid,
  p_first_visit_at timestamptz,
  p_jobs_first_30d int,
  p_jobs_first_60d int,
  p_jobs_first_90d int,
  p_ramp_status text
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
  INSERT INTO public.hospital_engineer_onboarding_pace_r1979 (
    hospital_id, engineer_user_id, first_visit_at,
    jobs_first_30d, jobs_first_60d, jobs_first_90d, ramp_status
  ) VALUES (
    p_hospital_id, p_engineer_user_id, p_first_visit_at,
    COALESCE(p_jobs_first_30d, 0), COALESCE(p_jobs_first_60d, 0),
    COALESCE(p_jobs_first_90d, 0), COALESCE(p_ramp_status, 'normal')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pace_r1979',
          jsonb_build_object('pace_id', v_id, 'hospital_id', p_hospital_id, 'engineer_user_id', p_engineer_user_id));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1979(p_pace_id uuid)
RETURNS TABLE (
  id uuid,
  pace_id uuid,
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
    SELECT a.id, a.pace_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_onboarding_pace_action_log_r1979 a
    WHERE a.pace_id = p_pace_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1979(
  p_pace_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.hospital_onboarding_pace_action_log_r1979 (
    pace_id, action_type, by_email, notes_md
  ) VALUES (
    p_pace_id, p_action_type, p_by_email, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1979',
          jsonb_build_object('action_id', v_id, 'pace_id', p_pace_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1979(
  p_pace_id uuid,
  p_ramp_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_engineer_onboarding_pace_r1979
  SET ramp_status = p_ramp_status, updated_at = now()
  WHERE id = p_pace_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1979',
          jsonb_build_object('pace_id', p_pace_id, 'ramp_status', p_ramp_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.slow_ramps_r1979()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  engineer_user_id uuid,
  engineer_email text,
  jobs_first_30d int,
  jobs_first_60d int,
  jobs_first_90d int,
  ramp_status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.hospital_id, o.name, p.engineer_user_id, pr.email,
           p.jobs_first_30d, p.jobs_first_60d, p.jobs_first_90d,
           p.ramp_status, p.captured_at
    FROM public.hospital_engineer_onboarding_pace_r1979 p
    LEFT JOIN public.organizations o ON o.id = p.hospital_id
    LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
    WHERE p.ramp_status IN ('slow','blocked')
    ORDER BY p.captured_at DESC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1979()
RETURNS TABLE (
  id uuid,
  pace_id uuid,
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
    SELECT a.id, a.pace_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_onboarding_pace_action_log_r1979 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_paces_r1979() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pace_r1979(uuid, uuid, timestamptz, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1979(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1979(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1979(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.slow_ramps_r1979() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1979() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_paces_r1979() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pace_r1979(uuid, uuid, timestamptz, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1979(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1979(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1979(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.slow_ramps_r1979() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1979() TO authenticated;

COMMIT;
