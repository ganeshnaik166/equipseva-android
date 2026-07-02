BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_decision_journal_r2309 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decided_on date NOT NULL DEFAULT CURRENT_DATE,
  decision_title text NOT NULL,
  context_md text NOT NULL DEFAULT '',
  options_considered_md text NOT NULL DEFAULT '',
  decision_made_md text NOT NULL DEFAULT '',
  expected_outcome_md text NOT NULL DEFAULT '',
  confidence_pct int NOT NULL DEFAULT 50 CHECK (confidence_pct BETWEEN 0 AND 100),
  reversibility text NOT NULL DEFAULT 'reversible' CHECK (reversibility IN ('reversible','one_way_door','partially_reversible')),
  category text NOT NULL DEFAULT 'product' CHECK (category IN ('product','people','capital','market','ops','tech','legal')),
  review_due_date date NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '7 days')::date,
  status text NOT NULL DEFAULT 'pending_review' CHECK (status IN ('pending_review','reviewed','superseded')),
  author_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_decision_retros_r2309 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.founder_decision_journal_r2309(id) ON DELETE CASCADE,
  reviewed_on date NOT NULL DEFAULT CURRENT_DATE,
  actual_outcome_md text NOT NULL DEFAULT '',
  outcome_rating text NOT NULL DEFAULT 'on_track' CHECK (outcome_rating IN ('better_than_expected','on_track','worse_than_expected','too_early')),
  lessons_md text NOT NULL DEFAULT '',
  follow_up_action_md text NOT NULL DEFAULT '',
  reviewer_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_decision_journal_r2309 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_decision_retros_r2309 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_journal_r2309 ON public.founder_decision_journal_r2309;
CREATE POLICY founder_all_journal_r2309 ON public.founder_decision_journal_r2309
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_retros_r2309 ON public.founder_decision_retros_r2309;
CREATE POLICY founder_all_retros_r2309 ON public.founder_decision_retros_r2309
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list decisions
CREATE OR REPLACE FUNCTION public.list_decisions_r2309()
RETURNS TABLE (
  id uuid,
  decided_on date,
  decision_title text,
  category text,
  reversibility text,
  confidence_pct int,
  status text,
  review_due_date date,
  days_until_review int,
  has_retro boolean
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.decided_on,
    d.decision_title,
    d.category,
    d.reversibility,
    d.confidence_pct,
    d.status,
    d.review_due_date,
    (d.review_due_date - CURRENT_DATE)::int AS days_until_review,
    EXISTS (SELECT 1 FROM public.founder_decision_retros_r2309 r WHERE r.decision_id = d.id) AS has_retro
  FROM public.founder_decision_journal_r2309 d
  ORDER BY d.decided_on DESC, d.created_at DESC;
END;
$$;

-- RPC 2: log decision
CREATE OR REPLACE FUNCTION public.log_decision_r2309(
  p_decision_title text,
  p_context_md text,
  p_options_considered_md text,
  p_decision_made_md text,
  p_expected_outcome_md text,
  p_confidence_pct int,
  p_reversibility text,
  p_category text,
  p_review_due_date date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_decision_journal_r2309 (
    decision_title, context_md, options_considered_md, decision_made_md, expected_outcome_md,
    confidence_pct, reversibility, category, review_due_date, author_id
  )
  VALUES (
    p_decision_title,
    COALESCE(p_context_md,''),
    COALESCE(p_options_considered_md,''),
    COALESCE(p_decision_made_md,''),
    COALESCE(p_expected_outcome_md,''),
    COALESCE(p_confidence_pct, 50),
    COALESCE(p_reversibility, 'reversible'),
    COALESCE(p_category, 'product'),
    COALESCE(p_review_due_date, (CURRENT_DATE + INTERVAL '7 days')::date),
    auth.uid()
  )
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_decision_r2309', jsonb_build_object('decision_id', v_id, 'title', p_decision_title));
  RETURN v_id;
END;
$$;

-- RPC 3: due for review
CREATE OR REPLACE FUNCTION public.decisions_due_for_review_r2309()
RETURNS TABLE (
  id uuid,
  decision_title text,
  decided_on date,
  review_due_date date,
  days_overdue int,
  category text,
  reversibility text,
  confidence_pct int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.decision_title,
    d.decided_on,
    d.review_due_date,
    GREATEST(0, (CURRENT_DATE - d.review_due_date))::int AS days_overdue,
    d.category,
    d.reversibility,
    d.confidence_pct
  FROM public.founder_decision_journal_r2309 d
  WHERE d.status = 'pending_review'
    AND d.review_due_date <= CURRENT_DATE
    AND NOT EXISTS (SELECT 1 FROM public.founder_decision_retros_r2309 r WHERE r.decision_id = d.id)
  ORDER BY d.review_due_date ASC;
END;
$$;

-- RPC 4: log retro
CREATE OR REPLACE FUNCTION public.log_retro_r2309(
  p_decision_id uuid,
  p_actual_outcome_md text,
  p_outcome_rating text,
  p_lessons_md text,
  p_follow_up_action_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_decision_retros_r2309 (
    decision_id, actual_outcome_md, outcome_rating, lessons_md, follow_up_action_md, reviewer_id
  )
  VALUES (
    p_decision_id,
    COALESCE(p_actual_outcome_md,''),
    COALESCE(p_outcome_rating,'on_track'),
    COALESCE(p_lessons_md,''),
    COALESCE(p_follow_up_action_md,''),
    auth.uid()
  )
  RETURNING id INTO v_id;
  UPDATE public.founder_decision_journal_r2309
  SET status='reviewed', updated_at=now()
  WHERE id = p_decision_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_retro_r2309', jsonb_build_object('retro_id', v_id, 'decision_id', p_decision_id, 'rating', p_outcome_rating));
  RETURN v_id;
END;
$$;

-- RPC 5: list retros joined
CREATE OR REPLACE FUNCTION public.list_retros_r2309()
RETURNS TABLE (
  id uuid,
  decision_id uuid,
  decision_title text,
  decided_on date,
  reviewed_on date,
  outcome_rating text,
  lessons_md text,
  follow_up_action_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.decision_id,
    d.decision_title,
    d.decided_on,
    r.reviewed_on,
    r.outcome_rating,
    r.lessons_md,
    r.follow_up_action_md
  FROM public.founder_decision_retros_r2309 r
  JOIN public.founder_decision_journal_r2309 d ON d.id = r.decision_id
  ORDER BY r.reviewed_on DESC;
END;
$$;

-- RPC 6: calibration scorecard (confidence vs outcome)
CREATE OR REPLACE FUNCTION public.calibration_scorecard_r2309()
RETURNS TABLE (
  confidence_bucket text,
  decisions_count int,
  better_than_expected int,
  on_track int,
  worse_than_expected int,
  too_early int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN d.confidence_pct >= 80 THEN '80-100'
      WHEN d.confidence_pct >= 60 THEN '60-79'
      WHEN d.confidence_pct >= 40 THEN '40-59'
      WHEN d.confidence_pct >= 20 THEN '20-39'
      ELSE '0-19'
    END AS confidence_bucket,
    (COUNT(*))::int AS decisions_count,
    (COUNT(*) FILTER (WHERE r.outcome_rating='better_than_expected'))::int AS better_than_expected,
    (COUNT(*) FILTER (WHERE r.outcome_rating='on_track'))::int AS on_track,
    (COUNT(*) FILTER (WHERE r.outcome_rating='worse_than_expected'))::int AS worse_than_expected,
    (COUNT(*) FILTER (WHERE r.outcome_rating='too_early'))::int AS too_early
  FROM public.founder_decision_journal_r2309 d
  JOIN public.founder_decision_retros_r2309 r ON r.decision_id = d.id
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;

-- RPC 7: category breakdown
CREATE OR REPLACE FUNCTION public.decision_category_breakdown_r2309()
RETURNS TABLE (
  category text,
  total_decisions int,
  pending_review int,
  reviewed int,
  one_way_doors int,
  avg_confidence numeric
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.category,
    (COUNT(*))::int AS total_decisions,
    (COUNT(*) FILTER (WHERE d.status='pending_review'))::int AS pending_review,
    (COUNT(*) FILTER (WHERE d.status='reviewed'))::int AS reviewed,
    (COUNT(*) FILTER (WHERE d.reversibility='one_way_door'))::int AS one_way_doors,
    ROUND(AVG(d.confidence_pct)::numeric, 1) AS avg_confidence
  FROM public.founder_decision_journal_r2309 d
  GROUP BY d.category
  ORDER BY total_decisions DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_decisions_r2309() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_decision_r2309(text, text, text, text, text, int, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decisions_due_for_review_r2309() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_retro_r2309(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_retros_r2309() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.calibration_scorecard_r2309() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decision_category_breakdown_r2309() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_decisions_r2309() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_decision_r2309(text, text, text, text, text, int, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decisions_due_for_review_r2309() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_retro_r2309(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_retros_r2309() TO authenticated;
GRANT EXECUTE ON FUNCTION public.calibration_scorecard_r2309() TO authenticated;
GRANT EXECUTE ON FUNCTION public.decision_category_breakdown_r2309() TO authenticated;

COMMIT;
