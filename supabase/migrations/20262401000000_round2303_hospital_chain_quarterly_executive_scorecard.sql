BEGIN;

-- Tables ------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.hospital_chain_quarterly_scorecards_r2303 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  quarter_label text NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  jobs_completed int NOT NULL DEFAULT 0,
  jobs_cancelled int NOT NULL DEFAULT 0,
  nps_score numeric(5,2) NOT NULL DEFAULT 0,
  nps_responses int NOT NULL DEFAULT 0,
  active_units int NOT NULL DEFAULT 0,
  amc_units int NOT NULL DEFAULT 0,
  amc_penetration_pct numeric(5,2) NOT NULL DEFAULT 0,
  complaints_count int NOT NULL DEFAULT 0,
  complaints_resolved int NOT NULL DEFAULT 0,
  revenue_rupees bigint NOT NULL DEFAULT 0,
  revenue_prev_rupees bigint NOT NULL DEFAULT 0,
  revenue_trend_pct numeric(6,2) NOT NULL DEFAULT 0,
  health_grade text NOT NULL DEFAULT 'B' CHECK (health_grade IN ('A','B','C','D','F')),
  notes_md text NOT NULL DEFAULT '',
  generated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_name, quarter_label)
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_scorecard_reviews_r2303 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scorecard_id uuid NOT NULL REFERENCES public.hospital_chain_quarterly_scorecards_r2303(id) ON DELETE CASCADE,
  reviewer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewer_email text NOT NULL,
  review_md text NOT NULL,
  action_item text NOT NULL DEFAULT '',
  decision text NOT NULL DEFAULT 'noted' CHECK (decision IN ('noted','escalate','win_back','expand','exit')),
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcqs_r2303_chain ON public.hospital_chain_quarterly_scorecards_r2303(chain_name);
CREATE INDEX IF NOT EXISTS idx_hcqs_r2303_quarter ON public.hospital_chain_quarterly_scorecards_r2303(quarter_label);
CREATE INDEX IF NOT EXISTS idx_hcqs_r2303_grade ON public.hospital_chain_quarterly_scorecards_r2303(health_grade);
CREATE INDEX IF NOT EXISTS idx_hcsr_r2303_scorecard ON public.hospital_chain_scorecard_reviews_r2303(scorecard_id);

ALTER TABLE public.hospital_chain_quarterly_scorecards_r2303 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_scorecard_reviews_r2303 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hcqs_r2303 ON public.hospital_chain_quarterly_scorecards_r2303;
CREATE POLICY founder_all_hcqs_r2303 ON public.hospital_chain_quarterly_scorecards_r2303
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hcsr_r2303 ON public.hospital_chain_scorecard_reviews_r2303;
CREATE POLICY founder_all_hcsr_r2303 ON public.hospital_chain_scorecard_reviews_r2303
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPCs --------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_chain_scorecards_r2303()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  period_start date,
  period_end date,
  jobs_completed int,
  jobs_cancelled int,
  nps_score numeric,
  nps_responses int,
  active_units int,
  amc_units int,
  amc_penetration_pct numeric,
  complaints_count int,
  complaints_resolved int,
  revenue_rupees bigint,
  revenue_prev_rupees bigint,
  revenue_trend_pct numeric,
  health_grade text,
  notes_md text,
  generated_at timestamptz,
  review_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.chain_name,
    s.quarter_label,
    s.period_start,
    s.period_end,
    s.jobs_completed,
    s.jobs_cancelled,
    s.nps_score,
    s.nps_responses,
    s.active_units,
    s.amc_units,
    s.amc_penetration_pct,
    s.complaints_count,
    s.complaints_resolved,
    s.revenue_rupees,
    s.revenue_prev_rupees,
    s.revenue_trend_pct,
    s.health_grade,
    s.notes_md,
    s.generated_at,
    (SELECT (COUNT(*))::int FROM public.hospital_chain_scorecard_reviews_r2303 r WHERE r.scorecard_id = s.id) AS review_count
  FROM public.hospital_chain_quarterly_scorecards_r2303 s
  ORDER BY s.period_end DESC, s.chain_name ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_chain_scorecard_r2303(
  p_chain_name text,
  p_quarter_label text,
  p_period_start date,
  p_period_end date,
  p_jobs_completed int,
  p_jobs_cancelled int,
  p_nps_score numeric,
  p_nps_responses int,
  p_active_units int,
  p_amc_units int,
  p_complaints_count int,
  p_complaints_resolved int,
  p_revenue_rupees bigint,
  p_revenue_prev_rupees bigint,
  p_health_grade text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_pen numeric;
  v_trend numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_pen := CASE WHEN p_active_units > 0
                THEN ROUND(100.0 * p_amc_units::numeric / p_active_units::numeric, 2)
                ELSE 0 END;

  v_trend := CASE WHEN p_revenue_prev_rupees > 0
                  THEN ROUND(100.0 * (p_revenue_rupees - p_revenue_prev_rupees)::numeric / p_revenue_prev_rupees::numeric, 2)
                  ELSE 0 END;

  INSERT INTO public.hospital_chain_quarterly_scorecards_r2303 AS s (
    chain_name, quarter_label, period_start, period_end,
    jobs_completed, jobs_cancelled,
    nps_score, nps_responses,
    active_units, amc_units, amc_penetration_pct,
    complaints_count, complaints_resolved,
    revenue_rupees, revenue_prev_rupees, revenue_trend_pct,
    health_grade, notes_md
  ) VALUES (
    p_chain_name, p_quarter_label, p_period_start, p_period_end,
    p_jobs_completed, p_jobs_cancelled,
    p_nps_score, p_nps_responses,
    p_active_units, p_amc_units, v_pen,
    p_complaints_count, p_complaints_resolved,
    p_revenue_rupees, p_revenue_prev_rupees, v_trend,
    p_health_grade, p_notes_md
  )
  ON CONFLICT (chain_name, quarter_label) DO UPDATE
  SET period_start = EXCLUDED.period_start,
      period_end = EXCLUDED.period_end,
      jobs_completed = EXCLUDED.jobs_completed,
      jobs_cancelled = EXCLUDED.jobs_cancelled,
      nps_score = EXCLUDED.nps_score,
      nps_responses = EXCLUDED.nps_responses,
      active_units = EXCLUDED.active_units,
      amc_units = EXCLUDED.amc_units,
      amc_penetration_pct = EXCLUDED.amc_penetration_pct,
      complaints_count = EXCLUDED.complaints_count,
      complaints_resolved = EXCLUDED.complaints_resolved,
      revenue_rupees = EXCLUDED.revenue_rupees,
      revenue_prev_rupees = EXCLUDED.revenue_prev_rupees,
      revenue_trend_pct = EXCLUDED.revenue_trend_pct,
      health_grade = EXCLUDED.health_grade,
      notes_md = EXCLUDED.notes_md,
      generated_at = now(),
      updated_at = now()
  RETURNING s.id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'upsert_chain_scorecard_r2303',
    jsonb_build_object('scorecard_id', v_id, 'chain_name', p_chain_name, 'quarter_label', p_quarter_label, 'health_grade', p_health_grade));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_chain_scorecard_reviews_r2303(p_scorecard_id uuid)
RETURNS TABLE (
  id uuid,
  scorecard_id uuid,
  reviewer_user_id uuid,
  reviewer_email text,
  review_md text,
  action_item text,
  decision text,
  reviewed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.scorecard_id, r.reviewer_user_id, r.reviewer_email, r.review_md, r.action_item, r.decision, r.reviewed_at
  FROM public.hospital_chain_scorecard_reviews_r2303 r
  WHERE r.scorecard_id = p_scorecard_id
  ORDER BY r.reviewed_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_chain_scorecard_review_r2303(
  p_scorecard_id uuid,
  p_review_md text,
  p_action_item text,
  p_decision text
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
  IF p_decision NOT IN ('noted','escalate','win_back','expand','exit') THEN
    RAISE EXCEPTION 'invalid decision %', p_decision;
  END IF;

  INSERT INTO public.hospital_chain_scorecard_reviews_r2303(scorecard_id, reviewer_user_id, reviewer_email, review_md, action_item, decision)
  VALUES (p_scorecard_id, auth.uid(), (auth.jwt()->>'email'), p_review_md, p_action_item, p_decision)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_chain_scorecard_review_r2303',
    jsonb_build_object('review_id', v_id, 'scorecard_id', p_scorecard_id, 'decision', p_decision));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_chain_scorecard_grade_r2303(
  p_scorecard_id uuid,
  p_health_grade text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_health_grade NOT IN ('A','B','C','D','F') THEN
    RAISE EXCEPTION 'invalid grade %', p_health_grade;
  END IF;

  UPDATE public.hospital_chain_quarterly_scorecards_r2303
  SET health_grade = p_health_grade,
      updated_at = now()
  WHERE id = p_scorecard_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_chain_scorecard_grade_r2303',
    jsonb_build_object('scorecard_id', p_scorecard_id, 'health_grade', p_health_grade));
END;
$$;

CREATE OR REPLACE FUNCTION public.chain_scorecard_rollup_r2303()
RETURNS TABLE (
  chain_name text,
  quarters_tracked int,
  latest_quarter text,
  latest_jobs int,
  latest_nps numeric,
  latest_amc_penetration_pct numeric,
  latest_complaints int,
  latest_revenue_rupees bigint,
  latest_revenue_trend_pct numeric,
  latest_grade text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ranked AS (
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.chain_name ORDER BY s.period_end DESC) AS rn
    FROM public.hospital_chain_quarterly_scorecards_r2303 s
  ),
  counts AS (
    SELECT s.chain_name, (COUNT(*))::int AS quarters_tracked
    FROM public.hospital_chain_quarterly_scorecards_r2303 s
    GROUP BY s.chain_name
  )
  SELECT
    r.chain_name,
    c.quarters_tracked,
    r.quarter_label AS latest_quarter,
    r.jobs_completed AS latest_jobs,
    r.nps_score AS latest_nps,
    r.amc_penetration_pct AS latest_amc_penetration_pct,
    r.complaints_count AS latest_complaints,
    r.revenue_rupees AS latest_revenue_rupees,
    r.revenue_trend_pct AS latest_revenue_trend_pct,
    r.health_grade AS latest_grade
  FROM ranked r
  JOIN counts c ON c.chain_name = r.chain_name
  WHERE r.rn = 1
  ORDER BY r.revenue_rupees DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.chain_scorecard_program_summary_r2303()
RETURNS TABLE (
  total_scorecards int,
  chains_tracked int,
  quarters_tracked int,
  avg_nps numeric,
  avg_amc_penetration_pct numeric,
  total_revenue_rupees bigint,
  grade_a_count int,
  grade_b_count int,
  grade_c_count int,
  grade_d_count int,
  grade_f_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_scorecards,
    (COUNT(DISTINCT chain_name))::int AS chains_tracked,
    (COUNT(DISTINCT quarter_label))::int AS quarters_tracked,
    COALESCE(ROUND(AVG(nps_score)::numeric, 2), 0) AS avg_nps,
    COALESCE(ROUND(AVG(amc_penetration_pct)::numeric, 2), 0) AS avg_amc_penetration_pct,
    COALESCE(SUM(revenue_rupees), 0)::bigint AS total_revenue_rupees,
    (COUNT(*) FILTER (WHERE health_grade = 'A'))::int AS grade_a_count,
    (COUNT(*) FILTER (WHERE health_grade = 'B'))::int AS grade_b_count,
    (COUNT(*) FILTER (WHERE health_grade = 'C'))::int AS grade_c_count,
    (COUNT(*) FILTER (WHERE health_grade = 'D'))::int AS grade_d_count,
    (COUNT(*) FILTER (WHERE health_grade = 'F'))::int AS grade_f_count
  FROM public.hospital_chain_quarterly_scorecards_r2303;
END;
$$;

CREATE OR REPLACE FUNCTION public.chain_scorecard_at_risk_r2303()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  health_grade text,
  nps_score numeric,
  amc_penetration_pct numeric,
  complaints_count int,
  revenue_trend_pct numeric,
  revenue_rupees bigint,
  risk_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.chain_name,
    s.quarter_label,
    s.health_grade,
    s.nps_score,
    s.amc_penetration_pct,
    s.complaints_count,
    s.revenue_trend_pct,
    s.revenue_rupees,
    ROUND(
      (CASE WHEN s.health_grade = 'F' THEN 40
            WHEN s.health_grade = 'D' THEN 30
            WHEN s.health_grade = 'C' THEN 20
            WHEN s.health_grade = 'B' THEN 10
            ELSE 0 END)::numeric
      + GREATEST(0, (50 - s.nps_score)) * 0.4
      + LEAST(s.complaints_count * 2, 30)
      + (CASE WHEN s.revenue_trend_pct < 0 THEN LEAST(ABS(s.revenue_trend_pct), 30) ELSE 0 END)
    , 2) AS risk_score
  FROM public.hospital_chain_quarterly_scorecards_r2303 s
  WHERE s.health_grade IN ('C','D','F')
     OR s.nps_score < 40
     OR s.revenue_trend_pct < 0
  ORDER BY risk_score DESC, s.period_end DESC;
END;
$$;

-- Grants ------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.list_chain_scorecards_r2303() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_chain_scorecard_r2303(text, text, date, date, int, int, numeric, int, int, int, int, int, bigint, bigint, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_chain_scorecard_reviews_r2303(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_chain_scorecard_review_r2303(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_chain_scorecard_grade_r2303(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.chain_scorecard_rollup_r2303() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.chain_scorecard_program_summary_r2303() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.chain_scorecard_at_risk_r2303() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_chain_scorecards_r2303() TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_chain_scorecard_r2303(text, text, date, date, int, int, numeric, int, int, int, int, int, bigint, bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_chain_scorecard_reviews_r2303(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_chain_scorecard_review_r2303(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_chain_scorecard_grade_r2303(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chain_scorecard_rollup_r2303() TO authenticated;
GRANT EXECUTE ON FUNCTION public.chain_scorecard_program_summary_r2303() TO authenticated;
GRANT EXECUTE ON FUNCTION public.chain_scorecard_at_risk_r2303() TO authenticated;

COMMIT;
