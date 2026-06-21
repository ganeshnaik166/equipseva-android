BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_decisions_r1714 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_date date NOT NULL DEFAULT CURRENT_DATE,
  decision_title text NOT NULL,
  context_md text NOT NULL DEFAULT '',
  options_considered_md text NOT NULL DEFAULT '',
  decision_md text NOT NULL DEFAULT '',
  expected_outcome_md text NOT NULL DEFAULT '',
  actual_outcome_md text,
  outcome_recorded_at timestamptz,
  lesson_md text,
  category text NOT NULL DEFAULT 'strategy' CHECK (category IN ('product','people','finance','strategy','legal','ops')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_decision_review_r1714 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.founder_decisions_r1714(id) ON DELETE CASCADE,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  judgment text NOT NULL CHECK (judgment IN ('correct','incorrect','mixed','too_early')),
  reviewer_email text,
  review_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fd_r1714_date ON public.founder_decisions_r1714(decision_date DESC);
CREATE INDEX IF NOT EXISTS idx_fd_r1714_category ON public.founder_decisions_r1714(category);
CREATE INDEX IF NOT EXISTS idx_fdr_r1714_decision ON public.founder_decision_review_r1714(decision_id);
CREATE INDEX IF NOT EXISTS idx_fdr_r1714_judgment ON public.founder_decision_review_r1714(judgment);

ALTER TABLE public.founder_decisions_r1714 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_decision_review_r1714 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fd_r1714 ON public.founder_decisions_r1714;
CREATE POLICY founder_all_fd_r1714 ON public.founder_decisions_r1714
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_fdr_r1714 ON public.founder_decision_review_r1714;
CREATE POLICY founder_all_fdr_r1714 ON public.founder_decision_review_r1714
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_decisions
CREATE OR REPLACE FUNCTION public.list_decisions_r1714()
RETURNS TABLE (
  id uuid,
  decision_date date,
  decision_title text,
  category text,
  has_actual_outcome boolean,
  outcome_recorded_at timestamptz,
  review_count int,
  correct_count int,
  incorrect_count int,
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
    d.id,
    d.decision_date,
    d.decision_title,
    d.category,
    (d.actual_outcome_md IS NOT NULL AND d.actual_outcome_md <> '') AS has_actual_outcome,
    d.outcome_recorded_at,
    (SELECT (COUNT(*))::int FROM public.founder_decision_review_r1714 r WHERE r.decision_id = d.id),
    (SELECT (COUNT(*) FILTER (WHERE r.judgment = 'correct'))::int FROM public.founder_decision_review_r1714 r WHERE r.decision_id = d.id),
    (SELECT (COUNT(*) FILTER (WHERE r.judgment = 'incorrect'))::int FROM public.founder_decision_review_r1714 r WHERE r.decision_id = d.id),
    d.created_at
  FROM public.founder_decisions_r1714 d
  ORDER BY d.decision_date DESC, d.created_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_decision
CREATE OR REPLACE FUNCTION public.log_decision_r1714(
  p_decision_date date,
  p_decision_title text,
  p_context_md text,
  p_options_considered_md text,
  p_decision_md text,
  p_expected_outcome_md text,
  p_category text
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
  IF p_category NOT IN ('product','people','finance','strategy','legal','ops') THEN
    RAISE EXCEPTION 'invalid_category';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_decisions_r1714(
    decision_date, decision_title, context_md, options_considered_md,
    decision_md, expected_outcome_md, category
  ) VALUES (
    COALESCE(p_decision_date, CURRENT_DATE),
    p_decision_title,
    COALESCE(p_context_md, ''),
    COALESCE(p_options_considered_md, ''),
    COALESCE(p_decision_md, ''),
    COALESCE(p_expected_outcome_md, ''),
    p_category
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_decision_r1714', jsonb_build_object('id', v_id, 'title', p_decision_title, 'category', p_category));

  RETURN v_id;
END;
$$;

-- 3. list_reviews
CREATE OR REPLACE FUNCTION public.list_reviews_r1714(p_decision_id uuid)
RETURNS TABLE (
  id uuid,
  decision_id uuid,
  reviewed_at timestamptz,
  judgment text,
  reviewer_email text,
  review_note text,
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
  SELECT r.id, r.decision_id, r.reviewed_at, r.judgment, r.reviewer_email, r.review_note, r.created_at
  FROM public.founder_decision_review_r1714 r
  WHERE (p_decision_id IS NULL OR r.decision_id = p_decision_id)
  ORDER BY r.reviewed_at DESC
  LIMIT 200;
END;
$$;

-- 4. add_review
CREATE OR REPLACE FUNCTION public.add_review_r1714(
  p_decision_id uuid,
  p_judgment text,
  p_reviewer_email text,
  p_review_note text
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
  IF p_judgment NOT IN ('correct','incorrect','mixed','too_early') THEN
    RAISE EXCEPTION 'invalid_judgment';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_decision_review_r1714(decision_id, judgment, reviewer_email, review_note)
  VALUES (p_decision_id, p_judgment, COALESCE(p_reviewer_email, v_email), p_review_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'add_review_r1714', jsonb_build_object('id', v_id, 'decision_id', p_decision_id, 'judgment', p_judgment));

  RETURN v_id;
END;
$$;

-- 5. mark_outcome
CREATE OR REPLACE FUNCTION public.mark_outcome_r1714(
  p_decision_id uuid,
  p_actual_outcome_md text,
  p_lesson_md text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  UPDATE public.founder_decisions_r1714
    SET actual_outcome_md = COALESCE(p_actual_outcome_md, actual_outcome_md),
        lesson_md = COALESCE(p_lesson_md, lesson_md),
        outcome_recorded_at = now(),
        updated_at = now()
    WHERE id = p_decision_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'mark_outcome_r1714', jsonb_build_object('id', p_decision_id));
END;
$$;

-- 6. judgment_distribution
CREATE OR REPLACE FUNCTION public.judgment_distribution_r1714()
RETURNS TABLE (
  category text,
  total_decisions int,
  with_outcome int,
  correct_count int,
  incorrect_count int,
  mixed_count int,
  too_early_count int
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
    d.category,
    (COUNT(*))::int AS total_decisions,
    (COUNT(*) FILTER (WHERE d.actual_outcome_md IS NOT NULL AND d.actual_outcome_md <> ''))::int AS with_outcome,
    (SELECT (COUNT(*) FILTER (WHERE r.judgment = 'correct'))::int
       FROM public.founder_decision_review_r1714 r
       JOIN public.founder_decisions_r1714 d2 ON d2.id = r.decision_id
       WHERE d2.category = d.category) AS correct_count,
    (SELECT (COUNT(*) FILTER (WHERE r.judgment = 'incorrect'))::int
       FROM public.founder_decision_review_r1714 r
       JOIN public.founder_decisions_r1714 d2 ON d2.id = r.decision_id
       WHERE d2.category = d.category) AS incorrect_count,
    (SELECT (COUNT(*) FILTER (WHERE r.judgment = 'mixed'))::int
       FROM public.founder_decision_review_r1714 r
       JOIN public.founder_decisions_r1714 d2 ON d2.id = r.decision_id
       WHERE d2.category = d.category) AS mixed_count,
    (SELECT (COUNT(*) FILTER (WHERE r.judgment = 'too_early'))::int
       FROM public.founder_decision_review_r1714 r
       JOIN public.founder_decisions_r1714 d2 ON d2.id = r.decision_id
       WHERE d2.category = d.category) AS too_early_count
  FROM public.founder_decisions_r1714 d
  GROUP BY d.category
  ORDER BY d.category;
END;
$$;

-- 7. recent_lessons
CREATE OR REPLACE FUNCTION public.recent_lessons_r1714()
RETURNS TABLE (
  id uuid,
  decision_date date,
  decision_title text,
  category text,
  lesson_md text,
  outcome_recorded_at timestamptz
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
  SELECT d.id, d.decision_date, d.decision_title, d.category, d.lesson_md, d.outcome_recorded_at
  FROM public.founder_decisions_r1714 d
  WHERE d.lesson_md IS NOT NULL AND d.lesson_md <> ''
  ORDER BY d.outcome_recorded_at DESC NULLS LAST, d.created_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_decisions_r1714() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_decision_r1714(date, text, text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reviews_r1714(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_review_r1714(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_outcome_r1714(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.judgment_distribution_r1714() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_lessons_r1714() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_decisions_r1714() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_decision_r1714(date, text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reviews_r1714(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_review_r1714(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_outcome_r1714(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.judgment_distribution_r1714() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_lessons_r1714() TO authenticated;

COMMIT;