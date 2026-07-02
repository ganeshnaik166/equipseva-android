BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_onboarding_pacing_r2172 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  days_to_first_job integer,
  days_to_first_solo integer,
  days_to_certification integer,
  onboarding_status text NOT NULL CHECK (onboarding_status IN ('fast','normal','slow','blocked','completed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_onboarding_action_log_r2172 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pacing_id uuid NOT NULL REFERENCES public.engineer_onboarding_pacing_r2172(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('started','first_job','first_solo','certified','blocked','completed','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_onboarding_pacing_r2172 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_onboarding_action_log_r2172 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pacing_r2172 ON public.engineer_onboarding_pacing_r2172;
CREATE POLICY founder_all_pacing_r2172 ON public.engineer_onboarding_pacing_r2172
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2172 ON public.engineer_onboarding_action_log_r2172;
CREATE POLICY founder_all_action_log_r2172 ON public.engineer_onboarding_action_log_r2172
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_pacings
DROP FUNCTION IF EXISTS public.list_pacings_r2172();
CREATE OR REPLACE FUNCTION public.list_pacings_r2172()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  days_to_first_job integer,
  days_to_first_solo integer,
  days_to_certification integer,
  onboarding_status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, p.days_to_first_job, p.days_to_first_solo,
         p.days_to_certification, p.onboarding_status, p.captured_at
  FROM public.engineer_onboarding_pacing_r2172 p
  ORDER BY p.captured_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pacings_r2172() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pacings_r2172() TO authenticated;

-- 2. log_pacing
DROP FUNCTION IF EXISTS public.log_pacing_r2172(uuid, integer, integer, integer, text);
CREATE OR REPLACE FUNCTION public.log_pacing_r2172(
  p_engineer_user_id uuid,
  p_days_to_first_job integer,
  p_days_to_first_solo integer,
  p_days_to_certification integer,
  p_onboarding_status text
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
  INSERT INTO public.engineer_onboarding_pacing_r2172(
    engineer_user_id, days_to_first_job, days_to_first_solo,
    days_to_certification, onboarding_status
  ) VALUES (
    p_engineer_user_id, p_days_to_first_job, p_days_to_first_solo,
    p_days_to_certification, p_onboarding_status
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pacing_r2172',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'status', p_onboarding_status));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_pacing_r2172(uuid, integer, integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_pacing_r2172(uuid, integer, integer, integer, text) TO authenticated;

-- 3. list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2172(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2172(p_pacing_id uuid)
RETURNS TABLE (
  id uuid,
  pacing_id uuid,
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
  SELECT a.id, a.pacing_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_onboarding_action_log_r2172 a
  WHERE a.pacing_id = p_pacing_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2172(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2172(uuid) TO authenticated;

-- 4. log_action
DROP FUNCTION IF EXISTS public.log_action_r2172(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2172(
  p_pacing_id uuid,
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
  INSERT INTO public.engineer_onboarding_action_log_r2172(pacing_id, action_type, by_email, notes_md)
  VALUES (p_pacing_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2172',
          jsonb_build_object('id', v_id, 'pacing_id', p_pacing_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2172(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2172(uuid, text, text, text) TO authenticated;

-- 5. mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2172(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2172(p_pacing_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_onboarding_pacing_r2172
    SET onboarding_status = p_status, updated_at = now()
    WHERE id = p_pacing_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2172',
          jsonb_build_object('pacing_id', p_pacing_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2172(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2172(uuid, text) TO authenticated;

-- 6. slow_onboardings
DROP FUNCTION IF EXISTS public.slow_onboardings_r2172();
CREATE OR REPLACE FUNCTION public.slow_onboardings_r2172()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  days_to_first_job integer,
  days_to_certification integer,
  onboarding_status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, p.days_to_first_job, p.days_to_certification,
         p.onboarding_status, p.captured_at
  FROM public.engineer_onboarding_pacing_r2172 p
  WHERE p.onboarding_status IN ('slow','blocked')
  ORDER BY p.captured_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.slow_onboardings_r2172() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.slow_onboardings_r2172() TO authenticated;

-- 7. recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2172();
CREATE OR REPLACE FUNCTION public.recent_actions_r2172()
RETURNS TABLE (
  id uuid,
  pacing_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.pacing_id, a.action_type, a.taken_at, a.by_email
  FROM public.engineer_onboarding_action_log_r2172 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2172() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2172() TO authenticated;

COMMIT;
