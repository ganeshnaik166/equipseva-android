-- Round 2456: Customer Feature Request ROI Scorer
-- Founder-only. RLS enabled. All RPCs SECURITY DEFINER + is_founder() gate.

BEGIN;

-- ============================================================================
-- Table 1: customer_feature_requests_r2456
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.customer_feature_requests_r2456 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  request_title text NOT NULL,
  request_kind text NOT NULL CHECK (request_kind IN ('workflow','integration','reporting','automation','mobile','ai')),
  request_summary_md text NOT NULL DEFAULT '',
  frequency_score int NOT NULL DEFAULT 0 CHECK (frequency_score BETWEEN 0 AND 100),
  revenue_impact_estimate_rupees bigint NOT NULL DEFAULT 0 CHECK (revenue_impact_estimate_rupees >= 0),
  engineering_cost_estimate_rupees bigint NOT NULL DEFAULT 1 CHECK (engineering_cost_estimate_rupees > 0),
  roi_score numeric NOT NULL DEFAULT 0,
  priority_rank int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','triaged','planned','in_progress','shipped','dropped')),
  shipped_at timestamptz,
  owner_email text,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_cfr_r2456_status ON public.customer_feature_requests_r2456(status);
CREATE INDEX IF NOT EXISTS idx_cfr_r2456_submitted_at ON public.customer_feature_requests_r2456(submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_cfr_r2456_kind ON public.customer_feature_requests_r2456(request_kind);
CREATE INDEX IF NOT EXISTS idx_cfr_r2456_roi ON public.customer_feature_requests_r2456(roi_score DESC);

ALTER TABLE public.customer_feature_requests_r2456 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_feature_requests_r2456;
CREATE POLICY founder_all ON public.customer_feature_requests_r2456
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- Table 2: feature_request_scoring_log_r2456
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.feature_request_scoring_log_r2456 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  request_id uuid NOT NULL REFERENCES public.customer_feature_requests_r2456(id) ON DELETE CASCADE,
  scored_at timestamptz NOT NULL DEFAULT now(),
  scored_by_email text NOT NULL,
  frequency_score_delta int NOT NULL DEFAULT 0,
  revenue_score_delta int NOT NULL DEFAULT 0,
  cost_score_delta int NOT NULL DEFAULT 0,
  final_roi numeric NOT NULL DEFAULT 0,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_frsl_r2456_request_id ON public.feature_request_scoring_log_r2456(request_id);
CREATE INDEX IF NOT EXISTS idx_frsl_r2456_scored_at ON public.feature_request_scoring_log_r2456(scored_at DESC);

ALTER TABLE public.feature_request_scoring_log_r2456 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.feature_request_scoring_log_r2456;
CREATE POLICY founder_all ON public.feature_request_scoring_log_r2456
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- Seed data
-- ============================================================================
DO $seed$
DECLARE
  v_req1 uuid;
  v_req2 uuid;
  v_req3 uuid;
  v_req4 uuid;
  v_req5 uuid;
BEGIN
  INSERT INTO public.customer_feature_requests_r2456
    (submitted_at, request_title, request_kind, request_summary_md, frequency_score, revenue_impact_estimate_rupees, engineering_cost_estimate_rupees, roi_score, priority_rank, status, owner_email, notes)
  VALUES
    ('2026-05-12 10:00:00+00'::timestamptz, 'One-tap AMC renewal from hospital app', 'workflow', 'Hospitals want a single button to renew lapsed AMC without re-uploading docs.', 88, 4500000, 250000, 18.0, 1, 'in_progress', 'ganesh@equipseva.com', 'Top requested across 14 hospitals.')
  RETURNING id INTO v_req1;

  INSERT INTO public.customer_feature_requests_r2456
    (submitted_at, request_title, request_kind, request_summary_md, frequency_score, revenue_impact_estimate_rupees, engineering_cost_estimate_rupees, roi_score, priority_rank, status, owner_email, notes)
  VALUES
    ('2026-05-18 11:30:00+00'::timestamptz, 'NABH compliance report auto-export', 'reporting', 'PDF + Excel monthly report ready by 1st of each month.', 72, 2200000, 180000, 12.2, 2, 'planned', 'ganesh@equipseva.com', 'Asked by 9 hospitals; required for NABH audits.')
  RETURNING id INTO v_req2;

  INSERT INTO public.customer_feature_requests_r2456
    (submitted_at, request_title, request_kind, request_summary_md, frequency_score, revenue_impact_estimate_rupees, engineering_cost_estimate_rupees, roi_score, priority_rank, status, owner_email, notes)
  VALUES
    ('2026-05-22 09:15:00+00'::timestamptz, 'WhatsApp engineer ETA push', 'automation', 'Auto-send engineer ETA on WhatsApp to hospital biomed.', 95, 1800000, 90000, 20.0, 3, 'triaged', 'ganesh@equipseva.com', 'Cheap + viral.')
  RETURNING id INTO v_req3;

  INSERT INTO public.customer_feature_requests_r2456
    (submitted_at, request_title, request_kind, request_summary_md, frequency_score, revenue_impact_estimate_rupees, engineering_cost_estimate_rupees, roi_score, priority_rank, status, shipped_at, owner_email, notes)
  VALUES
    ('2026-04-10 14:00:00+00'::timestamptz, 'AI triage of repair tickets', 'ai', 'Auto-classify ticket severity + route to right engineer tier.', 65, 3200000, 1200000, 2.7, 4, 'shipped', '2026-06-01 12:00:00+00'::timestamptz, 'ganesh@equipseva.com', 'Shipped v0.5 phase 7.')
  RETURNING id INTO v_req4;

  INSERT INTO public.customer_feature_requests_r2456
    (submitted_at, request_title, request_kind, request_summary_md, frequency_score, revenue_impact_estimate_rupees, engineering_cost_estimate_rupees, roi_score, priority_rank, status, owner_email, notes)
  VALUES
    ('2026-06-01 16:45:00+00'::timestamptz, 'Mobile dashboard for CFO', 'mobile', 'Hospital CFO mobile drilldown of spend + downtime.', 45, 800000, 600000, 1.3, 5, 'submitted', 'ganesh@equipseva.com', 'Nice-to-have; low frequency.')
  RETURNING id INTO v_req5;

  INSERT INTO public.feature_request_scoring_log_r2456
    (request_id, scored_at, scored_by_email, frequency_score_delta, revenue_score_delta, cost_score_delta, final_roi, notes)
  VALUES
    (v_req1, '2026-05-13 09:00:00+00'::timestamptz, 'ganesh@equipseva.com', 15, 20, -5, 18.0, 'Initial scoring after first 5 hospital interviews.'),
    (v_req2, '2026-05-19 10:00:00+00'::timestamptz, 'ganesh@equipseva.com', 10, 15, 0, 12.2, 'NABH audit pressure noted.'),
    (v_req3, '2026-05-23 11:00:00+00'::timestamptz, 'ganesh@equipseva.com', 25, 10, -10, 20.0, 'WhatsApp BSP cost lower than expected.'),
    (v_req4, '2026-04-12 13:00:00+00'::timestamptz, 'ganesh@equipseva.com', -5, 5, 20, 2.7, 'Eng cost ballooned post-discovery.'),
    (v_req5, '2026-06-02 17:00:00+00'::timestamptz, 'ganesh@equipseva.com', 0, 0, 5, 1.3, 'Deferred.');
END
$seed$;

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1. list_requests_r2456
CREATE OR REPLACE FUNCTION public.list_requests_r2456()
RETURNS TABLE (
  id uuid,
  submitted_at timestamptz,
  request_title text,
  request_kind text,
  frequency_score int,
  revenue_impact_estimate_rupees bigint,
  engineering_cost_estimate_rupees bigint,
  roi_score numeric,
  priority_rank int,
  status text,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.submitted_at, r.request_title, r.request_kind, r.frequency_score,
           r.revenue_impact_estimate_rupees, r.engineering_cost_estimate_rupees,
           r.roi_score, r.priority_rank, r.status, r.owner_email
    FROM public.customer_feature_requests_r2456 r
    ORDER BY r.priority_rank ASC, r.submitted_at DESC
    LIMIT 200;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_requests_r2456() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_requests_r2456() TO authenticated;

-- 2. list_scoring_log_r2456
CREATE OR REPLACE FUNCTION public.list_scoring_log_r2456()
RETURNS TABLE (
  id uuid,
  request_id uuid,
  request_title text,
  scored_at timestamptz,
  scored_by_email text,
  frequency_score_delta int,
  revenue_score_delta int,
  cost_score_delta int,
  final_roi numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.request_id, r.request_title, l.scored_at, l.scored_by_email,
           l.frequency_score_delta, l.revenue_score_delta, l.cost_score_delta,
           l.final_roi, l.notes
    FROM public.feature_request_scoring_log_r2456 l
    LEFT JOIN public.customer_feature_requests_r2456 r ON r.id = l.request_id
    ORDER BY l.scored_at DESC
    LIMIT 200;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_scoring_log_r2456() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_scoring_log_r2456() TO authenticated;

-- 3. top_roi_requests_r2456
CREATE OR REPLACE FUNCTION public.top_roi_requests_r2456()
RETURNS TABLE (
  request_title text,
  request_kind text,
  roi_score numeric,
  revenue_impact_estimate_rupees bigint,
  engineering_cost_estimate_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.request_title, r.request_kind, r.roi_score,
           r.revenue_impact_estimate_rupees, r.engineering_cost_estimate_rupees, r.status
    FROM public.customer_feature_requests_r2456 r
    WHERE r.status NOT IN ('shipped','dropped')
    ORDER BY r.roi_score DESC NULLS LAST
    LIMIT 10;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.top_roi_requests_r2456() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_roi_requests_r2456() TO authenticated;

-- 4. status_funnel_r2456
CREATE OR REPLACE FUNCTION public.status_funnel_r2456()
RETURNS TABLE (
  status text,
  request_count bigint,
  total_revenue_impact_rupees numeric,
  total_eng_cost_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.status,
           COUNT(*)::bigint AS request_count,
           COALESCE(SUM(r.revenue_impact_estimate_rupees), 0)::numeric AS total_revenue_impact_rupees,
           COALESCE(SUM(r.engineering_cost_estimate_rupees), 0)::numeric AS total_eng_cost_rupees
    FROM public.customer_feature_requests_r2456 r
    GROUP BY r.status
    ORDER BY request_count DESC;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2456() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2456() TO authenticated;

-- 5. kind_breakdown_r2456
CREATE OR REPLACE FUNCTION public.kind_breakdown_r2456()
RETURNS TABLE (
  request_kind text,
  request_count bigint,
  avg_roi numeric,
  total_revenue_impact_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.request_kind,
           COUNT(*)::bigint AS request_count,
           ROUND(AVG(r.roi_score)::numeric, 2) AS avg_roi,
           COALESCE(SUM(r.revenue_impact_estimate_rupees), 0)::numeric AS total_revenue_impact_rupees
    FROM public.customer_feature_requests_r2456 r
    GROUP BY r.request_kind
    ORDER BY avg_roi DESC NULLS LAST;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.kind_breakdown_r2456() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_breakdown_r2456() TO authenticated;

-- 6. weekly_submission_trend_r2456
CREATE OR REPLACE FUNCTION public.weekly_submission_trend_r2456()
RETURNS TABLE (
  week_start date,
  submissions bigint,
  shipped_in_week bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    WITH weeks AS (
      SELECT generate_series(
        date_trunc('week', (now() - interval '12 weeks'))::date,
        date_trunc('week', now())::date,
        interval '1 week'
      )::date AS week_start
    ),
    submitted AS (
      SELECT date_trunc('week', r.submitted_at)::date AS week_start, COUNT(*)::bigint AS submissions
      FROM public.customer_feature_requests_r2456 r
      WHERE r.submitted_at >= (now() - interval '12 weeks')
      GROUP BY 1
    ),
    shipped AS (
      SELECT date_trunc('week', r.shipped_at)::date AS week_start, COUNT(*)::bigint AS shipped_in_week
      FROM public.customer_feature_requests_r2456 r
      WHERE r.shipped_at IS NOT NULL AND r.shipped_at >= (now() - interval '12 weeks')
      GROUP BY 1
    )
    SELECT w.week_start,
           COALESCE(s.submissions, 0)::bigint,
           COALESCE(sh.shipped_in_week, 0)::bigint
    FROM weeks w
    LEFT JOIN submitted s ON s.week_start = w.week_start
    LEFT JOIN shipped sh ON sh.week_start = w.week_start
    ORDER BY w.week_start ASC;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.weekly_submission_trend_r2456() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_submission_trend_r2456() TO authenticated;

-- 7. top_hospitals_by_requests_r2456
CREATE OR REPLACE FUNCTION public.top_hospitals_by_requests_r2456()
RETURNS TABLE (
  hospital_email text,
  request_count bigint,
  avg_frequency numeric,
  total_revenue_impact_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(p.email, 'unknown')::text AS hospital_email,
           COUNT(*)::bigint AS request_count,
           ROUND(AVG(r.frequency_score)::numeric, 1) AS avg_frequency,
           COALESCE(SUM(r.revenue_impact_estimate_rupees), 0)::numeric AS total_revenue_impact_rupees
    FROM public.customer_feature_requests_r2456 r
    LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
    GROUP BY p.email
    ORDER BY request_count DESC, total_revenue_impact_rupees DESC
    LIMIT 20;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_by_requests_r2456() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_requests_r2456() TO authenticated;

