BEGIN;

-- =====================================================================
-- Round r1760 — Engineer Apprentice Program
-- Track new engineer apprentices + graduation progress through phases.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.engineer_apprentices_r1760 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  apprentice_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mentor_user_id uuid,
  started_on date NOT NULL DEFAULT CURRENT_DATE,
  expected_graduation_date date,
  current_phase text NOT NULL DEFAULT 'shadow'
    CHECK (current_phase IN ('shadow','co_pilot','supervised_solo','graduated','dropped')),
  hours_logged int NOT NULL DEFAULT 0,
  jobs_completed int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','paused','graduated','dropped')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_apprentices_r1760_status_idx
  ON public.engineer_apprentices_r1760 (status);
CREATE INDEX IF NOT EXISTS engineer_apprentices_r1760_phase_idx
  ON public.engineer_apprentices_r1760 (current_phase);
CREATE INDEX IF NOT EXISTS engineer_apprentices_r1760_apprentice_idx
  ON public.engineer_apprentices_r1760 (apprentice_user_id);

CREATE TABLE IF NOT EXISTS public.engineer_apprentice_milestones_r1760 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  apprentice_id uuid NOT NULL REFERENCES public.engineer_apprentices_r1760(id) ON DELETE CASCADE,
  milestone_name text NOT NULL
    CHECK (milestone_name IN ('first_solo_job','passing_assessment','certification_earned','customer_compliment','independent_work')),
  achieved_at timestamptz NOT NULL DEFAULT now(),
  awarded_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_apprentice_milestones_r1760_apprentice_idx
  ON public.engineer_apprentice_milestones_r1760 (apprentice_id);
CREATE INDEX IF NOT EXISTS engineer_apprentice_milestones_r1760_achieved_idx
  ON public.engineer_apprentice_milestones_r1760 (achieved_at DESC);

ALTER TABLE public.engineer_apprentices_r1760 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_apprentice_milestones_r1760 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_apprentices_r1760_founder_all ON public.engineer_apprentices_r1760;
CREATE POLICY engineer_apprentices_r1760_founder_all ON public.engineer_apprentices_r1760
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS engineer_apprentice_milestones_r1760_founder_all ON public.engineer_apprentice_milestones_r1760;
CREATE POLICY engineer_apprentice_milestones_r1760_founder_all ON public.engineer_apprentice_milestones_r1760
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPCs
-- =====================================================================

-- 1. list_apprentices
CREATE OR REPLACE FUNCTION public.list_apprentices_r1760()
RETURNS TABLE (
  id uuid,
  apprentice_user_id uuid,
  apprentice_email text,
  mentor_user_id uuid,
  mentor_email text,
  started_on date,
  expected_graduation_date date,
  current_phase text,
  hours_logged int,
  jobs_completed int,
  status text,
  milestone_count int,
  created_at timestamptz
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
    SELECT
      a.id,
      a.apprentice_user_id,
      ap.email::text AS apprentice_email,
      a.mentor_user_id,
      mp.email::text AS mentor_email,
      a.started_on,
      a.expected_graduation_date,
      a.current_phase,
      a.hours_logged,
      a.jobs_completed,
      a.status,
      (SELECT COUNT(*) FROM public.engineer_apprentice_milestones_r1760 m WHERE m.apprentice_id = a.id)::int AS milestone_count,
      a.created_at
    FROM public.engineer_apprentices_r1760 a
    LEFT JOIN public.profiles ap ON ap.id = a.apprentice_user_id
    LEFT JOIN public.profiles mp ON mp.id = a.mentor_user_id
    ORDER BY a.created_at DESC;
END;
$$;

-- 2. add_apprentice
CREATE OR REPLACE FUNCTION public.add_apprentice_r1760(
  p_apprentice_user_id uuid,
  p_mentor_user_id uuid,
  p_expected_graduation_date date
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
  INSERT INTO public.engineer_apprentices_r1760
    (apprentice_user_id, mentor_user_id, expected_graduation_date)
  VALUES (p_apprentice_user_id, p_mentor_user_id, p_expected_graduation_date)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'add_apprentice_r1760',
    jsonb_build_object(
      'apprentice_id', v_id,
      'apprentice_user_id', p_apprentice_user_id,
      'mentor_user_id', p_mentor_user_id,
      'expected_graduation_date', p_expected_graduation_date
    )
  );
  RETURN v_id;
END;
$$;

-- 3. list_milestones
CREATE OR REPLACE FUNCTION public.list_milestones_r1760(p_apprentice_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  apprentice_id uuid,
  apprentice_email text,
  milestone_name text,
  achieved_at timestamptz,
  awarded_by_email text
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
    SELECT
      m.id,
      m.apprentice_id,
      ap.email::text AS apprentice_email,
      m.milestone_name,
      m.achieved_at,
      m.awarded_by_email
    FROM public.engineer_apprentice_milestones_r1760 m
    JOIN public.engineer_apprentices_r1760 a ON a.id = m.apprentice_id
    LEFT JOIN public.profiles ap ON ap.id = a.apprentice_user_id
    WHERE (p_apprentice_id IS NULL OR m.apprentice_id = p_apprentice_id)
    ORDER BY m.achieved_at DESC;
END;
$$;

-- 4. log_milestone
CREATE OR REPLACE FUNCTION public.log_milestone_r1760(
  p_apprentice_id uuid,
  p_milestone_name text,
  p_awarded_by_email text
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
  INSERT INTO public.engineer_apprentice_milestones_r1760
    (apprentice_id, milestone_name, awarded_by_email)
  VALUES (p_apprentice_id, p_milestone_name, p_awarded_by_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_milestone_r1760',
    jsonb_build_object(
      'milestone_id', v_id,
      'apprentice_id', p_apprentice_id,
      'milestone_name', p_milestone_name,
      'awarded_by_email', p_awarded_by_email
    )
  );
  RETURN v_id;
END;
$$;

-- 5. advance_phase
CREATE OR REPLACE FUNCTION public.advance_phase_r1760(
  p_apprentice_id uuid,
  p_new_phase text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_new_phase NOT IN ('shadow','co_pilot','supervised_solo','graduated','dropped') THEN
    RAISE EXCEPTION 'invalid phase: %', p_new_phase;
  END IF;
  v_new_status := CASE
    WHEN p_new_phase = 'graduated' THEN 'graduated'
    WHEN p_new_phase = 'dropped' THEN 'dropped'
    ELSE 'active'
  END;
  UPDATE public.engineer_apprentices_r1760
    SET current_phase = p_new_phase,
        status = v_new_status,
        updated_at = now()
    WHERE id = p_apprentice_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'advance_phase_r1760',
    jsonb_build_object(
      'apprentice_id', p_apprentice_id,
      'new_phase', p_new_phase,
      'new_status', v_new_status
    )
  );
END;
$$;

-- 6. top_progress_apprentices
CREATE OR REPLACE FUNCTION public.top_progress_apprentices_r1760()
RETURNS TABLE (
  apprentice_id uuid,
  apprentice_email text,
  current_phase text,
  hours_logged int,
  jobs_completed int,
  milestone_count int,
  progress_score int
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
    SELECT
      a.id AS apprentice_id,
      ap.email::text AS apprentice_email,
      a.current_phase,
      a.hours_logged,
      a.jobs_completed,
      (SELECT COUNT(*) FROM public.engineer_apprentice_milestones_r1760 m WHERE m.apprentice_id = a.id)::int AS milestone_count,
      (
        a.hours_logged
        + (a.jobs_completed * 10)
        + ((SELECT COUNT(*) FROM public.engineer_apprentice_milestones_r1760 m WHERE m.apprentice_id = a.id)::int * 25)
      )::int AS progress_score
    FROM public.engineer_apprentices_r1760 a
    LEFT JOIN public.profiles ap ON ap.id = a.apprentice_user_id
    WHERE a.status = 'active'
    ORDER BY progress_score DESC
    LIMIT 20;
END;
$$;

-- 7. recently_graduated
CREATE OR REPLACE FUNCTION public.recently_graduated_r1760()
RETURNS TABLE (
  apprentice_id uuid,
  apprentice_email text,
  started_on date,
  graduated_at timestamptz,
  hours_logged int,
  jobs_completed int,
  milestone_count int
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
    SELECT
      a.id AS apprentice_id,
      ap.email::text AS apprentice_email,
      a.started_on,
      a.updated_at AS graduated_at,
      a.hours_logged,
      a.jobs_completed,
      (SELECT COUNT(*) FROM public.engineer_apprentice_milestones_r1760 m WHERE m.apprentice_id = a.id)::int AS milestone_count
    FROM public.engineer_apprentices_r1760 a
    LEFT JOIN public.profiles ap ON ap.id = a.apprentice_user_id
    WHERE a.status = 'graduated'
    ORDER BY a.updated_at DESC
    LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_apprentices_r1760() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_apprentice_r1760(uuid, uuid, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_milestones_r1760(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_milestone_r1760(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.advance_phase_r1760(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_progress_apprentices_r1760() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recently_graduated_r1760() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_apprentices_r1760() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_apprentice_r1760(uuid, uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_milestones_r1760(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_milestone_r1760(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_phase_r1760(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_progress_apprentices_r1760() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recently_graduated_r1760() TO authenticated;

COMMIT;