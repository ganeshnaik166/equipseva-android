BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_quarterly_okrs_r1914 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  objective_md text NOT NULL,
  key_results_md text NOT NULL,
  target_score int NOT NULL DEFAULT 100,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','abandoned','extended')),
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  final_score int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_okr_progress_log_r1914 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  okr_id uuid NOT NULL REFERENCES public.founder_quarterly_okrs_r1914(id) ON DELETE CASCADE,
  log_at timestamptz NOT NULL DEFAULT now(),
  progress_score int NOT NULL,
  blocker_md text,
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_quarterly_okrs_r1914 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_okr_progress_log_r1914 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS okrs_r1914_founder_all ON public.founder_quarterly_okrs_r1914;
CREATE POLICY okrs_r1914_founder_all ON public.founder_quarterly_okrs_r1914
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS okr_progress_r1914_founder_all ON public.founder_okr_progress_log_r1914;
CREATE POLICY okr_progress_r1914_founder_all ON public.founder_okr_progress_log_r1914
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_okrs_r1914_status ON public.founder_quarterly_okrs_r1914(status, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_okr_progress_r1914_okr ON public.founder_okr_progress_log_r1914(okr_id, log_at DESC);

CREATE OR REPLACE FUNCTION public.list_okrs_r1914()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  objective_md text,
  key_results_md text,
  target_score int,
  status text,
  started_at timestamptz,
  completed_at timestamptz,
  final_score int
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
  SELECT o.id, o.quarter_label, o.objective_md, o.key_results_md, o.target_score, o.status, o.started_at, o.completed_at, o.final_score
  FROM public.founder_quarterly_okrs_r1914 o
  ORDER BY o.started_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_okr_r1914(
  p_quarter_label text,
  p_objective_md text,
  p_key_results_md text,
  p_target_score int
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
  INSERT INTO public.founder_quarterly_okrs_r1914(quarter_label, objective_md, key_results_md, target_score)
  VALUES (p_quarter_label, p_objective_md, p_key_results_md, COALESCE(p_target_score, 100))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_okr_r1914', jsonb_build_object('id', v_id, 'quarter', p_quarter_label, 'target', p_target_score));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_progress_r1914(p_okr_id uuid)
RETURNS TABLE (
  id uuid,
  okr_id uuid,
  log_at timestamptz,
  progress_score int,
  blocker_md text,
  by_email text
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
  SELECT p.id, p.okr_id, p.log_at, p.progress_score, p.blocker_md, p.by_email
  FROM public.founder_okr_progress_log_r1914 p
  WHERE p.okr_id = p_okr_id
  ORDER BY p.log_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_progress_r1914(
  p_okr_id uuid,
  p_progress_score int,
  p_blocker_md text
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_okr_progress_log_r1914(okr_id, progress_score, blocker_md, by_email)
  VALUES (p_okr_id, p_progress_score, p_blocker_md, v_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_progress_r1914', jsonb_build_object('id', v_id, 'okr_id', p_okr_id, 'score', p_progress_score));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_completed_r1914(
  p_okr_id uuid,
  p_final_score int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_quarterly_okrs_r1914
  SET status = 'completed',
      completed_at = now(),
      final_score = p_final_score,
      updated_at = now()
  WHERE id = p_okr_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_completed_r1914', jsonb_build_object('id', p_okr_id, 'final_score', p_final_score));
END;
$$;

CREATE OR REPLACE FUNCTION public.active_okrs_r1914()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  objective_md text,
  target_score int,
  started_at timestamptz,
  latest_score int
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
  SELECT o.id, o.quarter_label, o.objective_md, o.target_score, o.started_at,
    (SELECT p.progress_score FROM public.founder_okr_progress_log_r1914 p WHERE p.okr_id = o.id ORDER BY p.log_at DESC LIMIT 1) AS latest_score
  FROM public.founder_quarterly_okrs_r1914 o
  WHERE o.status = 'active'
  ORDER BY o.started_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_progress_r1914()
RETURNS TABLE (
  id uuid,
  okr_id uuid,
  quarter_label text,
  log_at timestamptz,
  progress_score int,
  blocker_md text,
  by_email text
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
  SELECT p.id, p.okr_id, o.quarter_label, p.log_at, p.progress_score, p.blocker_md, p.by_email
  FROM public.founder_okr_progress_log_r1914 p
  JOIN public.founder_quarterly_okrs_r1914 o ON o.id = p.okr_id
  ORDER BY p.log_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_okrs_r1914() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_okr_r1914(text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_progress_r1914(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_progress_r1914(uuid, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_completed_r1914(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_okrs_r1914() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_progress_r1914() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_okrs_r1914() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_okr_r1914(text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_progress_r1914(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_progress_r1914(uuid, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_completed_r1914(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_okrs_r1914() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_progress_r1914() TO authenticated;

COMMIT;
