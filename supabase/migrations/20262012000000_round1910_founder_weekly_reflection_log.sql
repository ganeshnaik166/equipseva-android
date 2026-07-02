BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_weekly_reflections_r1910 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  what_worked_md text NOT NULL DEFAULT '',
  what_did_not_md text NOT NULL DEFAULT '',
  key_learning_md text NOT NULL DEFAULT '',
  energy_score int NOT NULL DEFAULT 5,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  written_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_reflection_threads_r1910 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reflection_id uuid NOT NULL REFERENCES public.founder_weekly_reflections_r1910(id) ON DELETE CASCADE,
  thread_type text NOT NULL CHECK (thread_type IN ('followup','incident','decision','celebration')),
  thread_md text NOT NULL DEFAULT '',
  recorded_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_weekly_reflections_r1910 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_reflection_threads_r1910 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reflections_founder_all_r1910 ON public.founder_weekly_reflections_r1910;
CREATE POLICY reflections_founder_all_r1910 ON public.founder_weekly_reflections_r1910
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS threads_founder_all_r1910 ON public.founder_reflection_threads_r1910;
CREATE POLICY threads_founder_all_r1910 ON public.founder_reflection_threads_r1910
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_reflections_week_r1910 ON public.founder_weekly_reflections_r1910(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_reflections_status_r1910 ON public.founder_weekly_reflections_r1910(status);
CREATE INDEX IF NOT EXISTS idx_threads_reflection_r1910 ON public.founder_reflection_threads_r1910(reflection_id);
CREATE INDEX IF NOT EXISTS idx_threads_type_r1910 ON public.founder_reflection_threads_r1910(thread_type);

-- RPC 1: list_reflections
CREATE OR REPLACE FUNCTION public.list_reflections_r1910()
RETURNS TABLE(
  id uuid,
  week_start date,
  status text,
  energy_score int,
  what_worked_md text,
  what_did_not_md text,
  key_learning_md text,
  written_at timestamptz,
  published_at timestamptz,
  thread_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.week_start, r.status, r.energy_score,
         r.what_worked_md, r.what_did_not_md, r.key_learning_md,
         r.written_at, r.published_at,
         (SELECT COUNT(*) FROM public.founder_reflection_threads_r1910 t WHERE t.reflection_id = r.id)::int
  FROM public.founder_weekly_reflections_r1910 r
  ORDER BY r.week_start DESC
  LIMIT 100;
END;
$$;

-- RPC 2: log_reflection
CREATE OR REPLACE FUNCTION public.log_reflection_r1910(
  p_week_start date,
  p_what_worked text,
  p_what_did_not text,
  p_key_learning text,
  p_energy int
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
  INSERT INTO public.founder_weekly_reflections_r1910(week_start, what_worked_md, what_did_not_md, key_learning_md, energy_score)
  VALUES (p_week_start, COALESCE(p_what_worked,''), COALESCE(p_what_did_not,''), COALESCE(p_key_learning,''), COALESCE(p_energy,5))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reflection_r1910',
          jsonb_build_object('reflection_id', v_id, 'week_start', p_week_start, 'energy', p_energy));
  RETURN v_id;
END;
$$;

-- RPC 3: list_threads
CREATE OR REPLACE FUNCTION public.list_threads_r1910(p_reflection_id uuid)
RETURNS TABLE(
  id uuid,
  reflection_id uuid,
  thread_type text,
  thread_md text,
  recorded_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.reflection_id, t.thread_type, t.thread_md, t.recorded_at, t.by_email
  FROM public.founder_reflection_threads_r1910 t
  WHERE p_reflection_id IS NULL OR t.reflection_id = p_reflection_id
  ORDER BY t.recorded_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: log_thread
CREATE OR REPLACE FUNCTION public.log_thread_r1910(
  p_reflection_id uuid,
  p_thread_type text,
  p_thread_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_reflection_threads_r1910(reflection_id, thread_type, thread_md, by_email)
  VALUES (p_reflection_id, p_thread_type, COALESCE(p_thread_md,''), v_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_thread_r1910',
          jsonb_build_object('thread_id', v_id, 'reflection_id', p_reflection_id, 'type', p_thread_type));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_published
CREATE OR REPLACE FUNCTION public.mark_published_r1910(p_reflection_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_weekly_reflections_r1910
     SET status = 'published', published_at = now(), updated_at = now()
   WHERE id = p_reflection_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_published_r1910',
          jsonb_build_object('reflection_id', p_reflection_id));
END;
$$;

-- RPC 6: recent_reflections
CREATE OR REPLACE FUNCTION public.recent_reflections_r1910()
RETURNS TABLE(
  id uuid,
  week_start date,
  status text,
  energy_score int,
  written_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.week_start, r.status, r.energy_score, r.written_at
  FROM public.founder_weekly_reflections_r1910 r
  WHERE r.written_at >= now() - interval '90 days'
  ORDER BY r.written_at DESC
  LIMIT 20;
END;
$$;

-- RPC 7: energy_trend
CREATE OR REPLACE FUNCTION public.energy_trend_r1910()
RETURNS TABLE(
  week_start date,
  energy_score int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.week_start, r.energy_score, r.status
  FROM public.founder_weekly_reflections_r1910 r
  ORDER BY r.week_start DESC
  LIMIT 26;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reflections_r1910() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reflection_r1910(date, text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_threads_r1910(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_thread_r1910(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_published_r1910(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_reflections_r1910() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.energy_trend_r1910() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reflections_r1910() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reflection_r1910(date, text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_threads_r1910(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_thread_r1910(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_published_r1910(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reflections_r1910() TO authenticated;
GRANT EXECUTE ON FUNCTION public.energy_trend_r1910() TO authenticated;

COMMIT;
