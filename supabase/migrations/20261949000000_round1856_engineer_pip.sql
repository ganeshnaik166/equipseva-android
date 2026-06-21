BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_pips_r1856 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  started_on date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  duration_days int NOT NULL DEFAULT 30 CHECK (duration_days BETWEEN 7 AND 180),
  focus_areas text[] NOT NULL DEFAULT '{}',
  improvement_targets_md text NOT NULL DEFAULT '',
  mentor_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','passed','failed','voluntary_separation','extended')),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_pips_r1856_engineer_idx ON public.engineer_pips_r1856(engineer_user_id);
CREATE INDEX IF NOT EXISTS engineer_pips_r1856_status_idx ON public.engineer_pips_r1856(status);
CREATE INDEX IF NOT EXISTS engineer_pips_r1856_started_idx ON public.engineer_pips_r1856(started_on DESC);

CREATE TABLE IF NOT EXISTS public.engineer_pip_check_ins_r1856 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pip_id uuid NOT NULL REFERENCES public.engineer_pips_r1856(id) ON DELETE CASCADE,
  check_in_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  progress_score int NOT NULL CHECK (progress_score BETWEEN 1 AND 10),
  on_track boolean NOT NULL DEFAULT false,
  mentor_note_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_pip_check_ins_r1856_pip_idx ON public.engineer_pip_check_ins_r1856(pip_id);
CREATE INDEX IF NOT EXISTS engineer_pip_check_ins_r1856_date_idx ON public.engineer_pip_check_ins_r1856(check_in_date DESC);

ALTER TABLE public.engineer_pips_r1856 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_pip_check_ins_r1856 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_pips_r1856_founder ON public.engineer_pips_r1856;
CREATE POLICY engineer_pips_r1856_founder ON public.engineer_pips_r1856
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS engineer_pip_check_ins_r1856_founder ON public.engineer_pip_check_ins_r1856;
CREATE POLICY engineer_pip_check_ins_r1856_founder ON public.engineer_pip_check_ins_r1856
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_pips_r1856()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  started_on date,
  duration_days int,
  focus_areas text[],
  mentor_user_id uuid,
  mentor_email text,
  status text,
  decided_at timestamptz,
  created_at timestamptz,
  check_in_count int,
  avg_progress numeric
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
    p.engineer_user_id,
    e.email::text,
    p.started_on,
    p.duration_days,
    p.focus_areas,
    p.mentor_user_id,
    m.email::text,
    p.status,
    p.decided_at,
    p.created_at,
    (SELECT COUNT(*) FROM public.engineer_pip_check_ins_r1856 c WHERE c.pip_id = p.id)::int,
    (SELECT AVG(c.progress_score)::numeric(4,2) FROM public.engineer_pip_check_ins_r1856 c WHERE c.pip_id = p.id)
  FROM public.engineer_pips_r1856 p
  LEFT JOIN public.profiles e ON e.id = p.engineer_user_id
  LEFT JOIN public.profiles m ON m.id = p.mentor_user_id
  ORDER BY p.created_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.start_pip_r1856(
  p_engineer_user_id uuid,
  p_duration_days int,
  p_focus_areas text[],
  p_improvement_targets_md text,
  p_mentor_user_id uuid
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
  INSERT INTO public.engineer_pips_r1856(engineer_user_id, duration_days, focus_areas, improvement_targets_md, mentor_user_id)
  VALUES (p_engineer_user_id, COALESCE(p_duration_days, 30), COALESCE(p_focus_areas, '{}'), COALESCE(p_improvement_targets_md, ''), p_mentor_user_id)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'start_pip_r1856',
    jsonb_build_object('pip_id', v_id, 'engineer_user_id', p_engineer_user_id, 'duration_days', p_duration_days));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_check_ins_r1856(p_pip_id uuid)
RETURNS TABLE (
  id uuid,
  pip_id uuid,
  check_in_date date,
  progress_score int,
  on_track boolean,
  mentor_note_md text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.pip_id, c.check_in_date, c.progress_score, c.on_track, c.mentor_note_md, c.created_at
  FROM public.engineer_pip_check_ins_r1856 c
  WHERE c.pip_id = p_pip_id
  ORDER BY c.check_in_date DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_check_in_r1856(
  p_pip_id uuid,
  p_progress_score int,
  p_on_track boolean,
  p_mentor_note_md text
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
  INSERT INTO public.engineer_pip_check_ins_r1856(pip_id, progress_score, on_track, mentor_note_md)
  VALUES (p_pip_id, p_progress_score, COALESCE(p_on_track, false), COALESCE(p_mentor_note_md, ''))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_check_in_r1856',
    jsonb_build_object('check_in_id', v_id, 'pip_id', p_pip_id, 'progress_score', p_progress_score, 'on_track', p_on_track));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.complete_pip_r1856(
  p_pip_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('passed','failed','voluntary_separation','extended') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;
  UPDATE public.engineer_pips_r1856
  SET status = p_status,
      decided_at = now(),
      updated_at = now()
  WHERE id = p_pip_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_pip_r1856',
    jsonb_build_object('pip_id', p_pip_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.active_pips_summary_r1856()
RETURNS TABLE (
  active_count int,
  avg_duration numeric,
  with_mentor_count int,
  overdue_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE status = 'active'))::int,
    (AVG(duration_days) FILTER (WHERE status = 'active'))::numeric(6,1),
    (COUNT(*) FILTER (WHERE status = 'active' AND mentor_user_id IS NOT NULL))::int,
    (COUNT(*) FILTER (WHERE status = 'active' AND (started_on + (duration_days || ' days')::interval)::date < (now() AT TIME ZONE 'Asia/Kolkata')::date))::int
  FROM public.engineer_pips_r1856;
END $$;

CREATE OR REPLACE FUNCTION public.recent_completions_r1856()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  status text,
  decided_at timestamptz,
  duration_days int,
  focus_areas text[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, e.email::text, p.status, p.decided_at, p.duration_days, p.focus_areas
  FROM public.engineer_pips_r1856 p
  LEFT JOIN public.profiles e ON e.id = p.engineer_user_id
  WHERE p.status IN ('passed','failed','voluntary_separation','extended')
    AND p.decided_at IS NOT NULL
  ORDER BY p.decided_at DESC
  LIMIT 50;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_pips_r1856() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.start_pip_r1856(uuid, int, text[], text, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_check_ins_r1856(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_check_in_r1856(uuid, int, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_pip_r1856(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_pips_summary_r1856() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_completions_r1856() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pips_r1856() TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_pip_r1856(uuid, int, text[], text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_check_ins_r1856(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_check_in_r1856(uuid, int, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_pip_r1856(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_pips_summary_r1856() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_completions_r1856() TO authenticated;

COMMIT;