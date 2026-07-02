BEGIN;

-- ============================================================
-- Round 2262: Engineer Regional Supervisor Roster
-- Supervisor per region, regional KPI accountability,
-- escalation matrix, monthly review
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_regional_supervisors_r2262 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  region_code text NOT NULL,
  region_name text NOT NULL,
  city text NOT NULL,
  state_code text NOT NULL,
  span_of_control int NOT NULL DEFAULT 0,
  tier text NOT NULL CHECK (tier IN ('lead','senior','principal')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','on_leave','probation','exiting')),
  escalation_level int NOT NULL DEFAULT 1 CHECK (escalation_level BETWEEN 1 AND 4),
  escalation_phone text,
  escalation_email text,
  kpi_jobs_target int NOT NULL DEFAULT 0,
  kpi_jobs_actual int NOT NULL DEFAULT 0,
  kpi_csat_target_bps int NOT NULL DEFAULT 8500,
  kpi_csat_actual_bps int NOT NULL DEFAULT 0,
  kpi_sla_target_bps int NOT NULL DEFAULT 9500,
  kpi_sla_actual_bps int NOT NULL DEFAULT 0,
  monthly_review_score int CHECK (monthly_review_score BETWEEN 0 AND 100),
  last_review_at timestamptz,
  next_review_at timestamptz,
  notes text,
  appointed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ers_r2262_region ON public.engineer_regional_supervisors_r2262(region_code);
CREATE INDEX IF NOT EXISTS idx_ers_r2262_status ON public.engineer_regional_supervisors_r2262(status);
CREATE INDEX IF NOT EXISTS idx_ers_r2262_tier ON public.engineer_regional_supervisors_r2262(tier);

ALTER TABLE public.engineer_regional_supervisors_r2262 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ers_r2262_founder_all ON public.engineer_regional_supervisors_r2262;
CREATE POLICY ers_r2262_founder_all ON public.engineer_regional_supervisors_r2262
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.supervisor_monthly_reviews_r2262 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id uuid NOT NULL REFERENCES public.engineer_regional_supervisors_r2262(id) ON DELETE CASCADE,
  review_month date NOT NULL,
  jobs_completed int NOT NULL DEFAULT 0,
  csat_bps int NOT NULL DEFAULT 0,
  sla_bps int NOT NULL DEFAULT 0,
  escalations_handled int NOT NULL DEFAULT 0,
  attrition_count int NOT NULL DEFAULT 0,
  review_score int NOT NULL CHECK (review_score BETWEEN 0 AND 100),
  rating text NOT NULL CHECK (rating IN ('exceeds','meets','below','pip')),
  reviewer_email text NOT NULL,
  comments text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_smr_r2262_supervisor ON public.supervisor_monthly_reviews_r2262(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_smr_r2262_month ON public.supervisor_monthly_reviews_r2262(review_month DESC);
CREATE INDEX IF NOT EXISTS idx_smr_r2262_rating ON public.supervisor_monthly_reviews_r2262(rating);

ALTER TABLE public.supervisor_monthly_reviews_r2262 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS smr_r2262_founder_all ON public.supervisor_monthly_reviews_r2262;
CREATE POLICY smr_r2262_founder_all ON public.supervisor_monthly_reviews_r2262
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- ============================================================
-- RPC 1: roster overview
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2262_roster_overview()
RETURNS TABLE(
  total_supervisors int,
  active_count int,
  on_leave_count int,
  probation_count int,
  exiting_count int,
  total_span int,
  avg_span numeric,
  regions_covered int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE status = 'active'))::int,
    (COUNT(*) FILTER (WHERE status = 'on_leave'))::int,
    (COUNT(*) FILTER (WHERE status = 'probation'))::int,
    (COUNT(*) FILTER (WHERE status = 'exiting'))::int,
    (COALESCE(SUM(span_of_control), 0))::int,
    ROUND(COALESCE(AVG(span_of_control), 0)::numeric, 1),
    (COUNT(DISTINCT region_code))::int
  FROM public.engineer_regional_supervisors_r2262;
END;
$$;

REVOKE ALL ON FUNCTION public.r2262_roster_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2262_roster_overview() TO authenticated;


-- ============================================================
-- RPC 2: roster list
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2262_roster_list()
RETURNS TABLE(
  id uuid,
  supervisor_email text,
  region_name text,
  city text,
  state_code text,
  tier text,
  status text,
  span_of_control int,
  escalation_level int,
  kpi_jobs_actual int,
  kpi_jobs_target int,
  kpi_csat_actual_bps int,
  kpi_sla_actual_bps int,
  monthly_review_score int,
  next_review_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    s.id,
    p.email,
    s.region_name,
    s.city,
    s.state_code,
    s.tier,
    s.status,
    s.span_of_control,
    s.escalation_level,
    s.kpi_jobs_actual,
    s.kpi_jobs_target,
    s.kpi_csat_actual_bps,
    s.kpi_sla_actual_bps,
    s.monthly_review_score,
    s.next_review_at
  FROM public.engineer_regional_supervisors_r2262 s
  JOIN public.profiles p ON p.id = s.supervisor_user_id
  ORDER BY s.tier, s.region_name;
END;
$$;

REVOKE ALL ON FUNCTION public.r2262_roster_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2262_roster_list() TO authenticated;


-- ============================================================
-- RPC 3: KPI performance by region
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2262_kpi_by_region()
RETURNS TABLE(
  region_name text,
  supervisor_count int,
  total_span int,
  jobs_target int,
  jobs_actual int,
  jobs_attainment_bps int,
  avg_csat_bps int,
  avg_sla_bps int,
  meets_jobs boolean,
  meets_csat boolean,
  meets_sla boolean
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    s.region_name,
    (COUNT(*))::int,
    (COALESCE(SUM(s.span_of_control), 0))::int,
    (COALESCE(SUM(s.kpi_jobs_target), 0))::int,
    (COALESCE(SUM(s.kpi_jobs_actual), 0))::int,
    CASE WHEN SUM(s.kpi_jobs_target) > 0
      THEN ((SUM(s.kpi_jobs_actual) * 10000) / SUM(s.kpi_jobs_target))::int
      ELSE 0 END,
    (COALESCE(AVG(s.kpi_csat_actual_bps), 0))::int,
    (COALESCE(AVG(s.kpi_sla_actual_bps), 0))::int,
    (COALESCE(SUM(s.kpi_jobs_actual), 0) >= COALESCE(SUM(s.kpi_jobs_target), 0) AND SUM(s.kpi_jobs_target) > 0),
    (COALESCE(AVG(s.kpi_csat_actual_bps), 0) >= COALESCE(AVG(s.kpi_csat_target_bps), 0)),
    (COALESCE(AVG(s.kpi_sla_actual_bps), 0) >= COALESCE(AVG(s.kpi_sla_target_bps), 0))
  FROM public.engineer_regional_supervisors_r2262 s
  WHERE s.status = 'active'
  GROUP BY s.region_name
  ORDER BY s.region_name;
END;
$$;

REVOKE ALL ON FUNCTION public.r2262_kpi_by_region() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2262_kpi_by_region() TO authenticated;


-- ============================================================
-- RPC 4: escalation matrix
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2262_escalation_matrix()
RETURNS TABLE(
  escalation_level int,
  level_label text,
  supervisor_count int,
  supervisor_emails text,
  regions_covered text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    s.escalation_level,
    CASE s.escalation_level
      WHEN 1 THEN 'L1 First Response'
      WHEN 2 THEN 'L2 Regional Lead'
      WHEN 3 THEN 'L3 Senior Supervisor'
      WHEN 4 THEN 'L4 Principal Director'
      ELSE 'Unknown'
    END,
    (COUNT(*))::int,
    string_agg(DISTINCT p.email, ', ' ORDER BY p.email),
    string_agg(DISTINCT s.region_name, ', ' ORDER BY s.region_name)
  FROM public.engineer_regional_supervisors_r2262 s
  JOIN public.profiles p ON p.id = s.supervisor_user_id
  WHERE s.status = 'active'
  GROUP BY s.escalation_level
  ORDER BY s.escalation_level;
END;
$$;

REVOKE ALL ON FUNCTION public.r2262_escalation_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2262_escalation_matrix() TO authenticated;


-- ============================================================
-- RPC 5: monthly review history
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2262_review_history()
RETURNS TABLE(
  review_month date,
  supervisor_email text,
  region_name text,
  jobs_completed int,
  csat_bps int,
  sla_bps int,
  escalations_handled int,
  attrition_count int,
  review_score int,
  rating text,
  reviewer_email text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    r.review_month,
    p.email,
    s.region_name,
    r.jobs_completed,
    r.csat_bps,
    r.sla_bps,
    r.escalations_handled,
    r.attrition_count,
    r.review_score,
    r.rating,
    r.reviewer_email
  FROM public.supervisor_monthly_reviews_r2262 r
  JOIN public.engineer_regional_supervisors_r2262 s ON s.id = r.supervisor_id
  JOIN public.profiles p ON p.id = s.supervisor_user_id
  ORDER BY r.review_month DESC, s.region_name;
END;
$$;

REVOKE ALL ON FUNCTION public.r2262_review_history() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2262_review_history() TO authenticated;


-- ============================================================
-- RPC 6: at-risk supervisors (below target or PIP)
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2262_at_risk_supervisors()
RETURNS TABLE(
  supervisor_email text,
  region_name text,
  tier text,
  status text,
  monthly_review_score int,
  kpi_jobs_actual int,
  kpi_jobs_target int,
  jobs_gap_pct int,
  last_rating text,
  risk_reason text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    p.email,
    s.region_name,
    s.tier,
    s.status,
    s.monthly_review_score,
    s.kpi_jobs_actual,
    s.kpi_jobs_target,
    CASE WHEN s.kpi_jobs_target > 0
      THEN (((s.kpi_jobs_target - s.kpi_jobs_actual) * 100) / s.kpi_jobs_target)::int
      ELSE 0 END,
    (SELECT r.rating FROM public.supervisor_monthly_reviews_r2262 r
       WHERE r.supervisor_id = s.id ORDER BY r.review_month DESC LIMIT 1),
    CASE
      WHEN s.status = 'probation' THEN 'On probation'
      WHEN s.status = 'exiting' THEN 'Exit in progress'
      WHEN s.monthly_review_score IS NOT NULL AND s.monthly_review_score < 60 THEN 'Low review score'
      WHEN s.kpi_jobs_target > 0 AND s.kpi_jobs_actual < (s.kpi_jobs_target * 75 / 100) THEN 'Jobs gap below 75 pct'
      WHEN s.kpi_csat_actual_bps < 7500 THEN 'CSAT below 75 pct'
      ELSE 'KPI gap'
    END
  FROM public.engineer_regional_supervisors_r2262 s
  JOIN public.profiles p ON p.id = s.supervisor_user_id
  WHERE s.status IN ('probation','exiting')
     OR (s.monthly_review_score IS NOT NULL AND s.monthly_review_score < 60)
     OR (s.kpi_jobs_target > 0 AND s.kpi_jobs_actual < (s.kpi_jobs_target * 75 / 100))
     OR s.kpi_csat_actual_bps < 7500
  ORDER BY s.monthly_review_score NULLS LAST, s.region_name;
END;
$$;

REVOKE ALL ON FUNCTION public.r2262_at_risk_supervisors() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2262_at_risk_supervisors() TO authenticated;


-- ============================================================
-- RPC 7: tier distribution
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2262_tier_distribution()
RETURNS TABLE(
  tier text,
  supervisor_count int,
  avg_span numeric,
  avg_review_score numeric,
  avg_csat_bps int,
  meets_target_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    s.tier,
    (COUNT(*))::int,
    ROUND(COALESCE(AVG(s.span_of_control), 0)::numeric, 1),
    ROUND(COALESCE(AVG(s.monthly_review_score), 0)::numeric, 1),
    (COALESCE(AVG(s.kpi_csat_actual_bps), 0))::int,
    (COUNT(*) FILTER (WHERE s.kpi_jobs_actual >= s.kpi_jobs_target AND s.kpi_jobs_target > 0))::int
  FROM public.engineer_regional_supervisors_r2262 s
  WHERE s.status = 'active'
  GROUP BY s.tier
  ORDER BY
    CASE s.tier WHEN 'principal' THEN 1 WHEN 'senior' THEN 2 WHEN 'lead' THEN 3 ELSE 4 END;
END;
$$;

REVOKE ALL ON FUNCTION public.r2262_tier_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2262_tier_distribution() TO authenticated;

COMMIT;
