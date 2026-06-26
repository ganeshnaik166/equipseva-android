BEGIN;

-- ============================================================================
-- Round 2818: Engineer Monthly Customer Recommendation Engine
-- Surfaces engineer x customer match scores, satisfaction, repeat history,
-- and promote actions to drive monthly assignment recommendations.
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_customer_recommendations_r2818 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  customer_code text NOT NULL,
  customer_name text NOT NULL,
  customer_segment text NOT NULL CHECK (customer_segment IN ('hospital','clinic','diagnostic','dental','veterinary')),
  city text NOT NULL,
  match_score numeric(5,2) NOT NULL CHECK (match_score >= 0 AND match_score <= 100),
  satisfaction_score numeric(4,2) NOT NULL CHECK (satisfaction_score >= 0 AND satisfaction_score <= 5),
  repeat_jobs_count int NOT NULL DEFAULT 0 CHECK (repeat_jobs_count >= 0),
  last_job_date date,
  promote_action text NOT NULL CHECK (promote_action IN ('promote','hold','review','retire')),
  recommendation_reason text NOT NULL,
  expected_revenue_rupees bigint NOT NULL DEFAULT 0 CHECK (expected_revenue_rupees >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_customer_recommendations_r2818 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_customer_recommendations_r2818;
CREATE POLICY founder_all ON engineer_customer_recommendations_r2818
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_promote_actions_r2818 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recommendation_id uuid REFERENCES engineer_customer_recommendations_r2818(id) ON DELETE CASCADE,
  month_start date NOT NULL,
  engineer_code text NOT NULL,
  customer_code text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('promote','hold','review','retire','reassign')),
  action_status text NOT NULL CHECK (action_status IN ('pending','approved','rejected','executed')),
  acted_by text NOT NULL,
  acted_at timestamptz NOT NULL DEFAULT now(),
  notes text
);

ALTER TABLE engineer_promote_actions_r2818 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_promote_actions_r2818;
CREATE POLICY founder_all ON engineer_promote_actions_r2818
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed recommendations
INSERT INTO engineer_customer_recommendations_r2818
  (month_start, engineer_code, engineer_name, engineer_tier, customer_code, customer_name, customer_segment, city, match_score, satisfaction_score, repeat_jobs_count, last_job_date, promote_action, recommendation_reason, expected_revenue_rupees)
VALUES
  ('2026-06-01'::date, 'ENG-001', 'Ravi Kumar', 'platinum', 'CUST-101', 'Apollo Hospitals Jubilee', 'hospital', 'Hyderabad', 96.50, 4.80, 12, '2026-05-28'::date, 'promote', 'Top match - high repeat + 4.8 CSAT across 12 jobs', 280000),
  ('2026-06-01'::date, 'ENG-002', 'Anjali Sharma', 'gold', 'CUST-102', 'Yashoda Hospitals Secunderabad', 'hospital', 'Hyderabad', 91.20, 4.60, 8, '2026-05-22'::date, 'promote', 'Strong CT scanner skills - aligned with Yashoda needs', 195000),
  ('2026-06-01'::date, 'ENG-003', 'Suresh Reddy', 'silver', 'CUST-103', 'Cure Dental Clinic', 'dental', 'Bangalore', 78.40, 4.20, 5, '2026-05-15'::date, 'hold', 'Decent match but needs more dental cert hours', 65000),
  ('2026-06-01'::date, 'ENG-004', 'Priya Nair', 'gold', 'CUST-104', 'Vijaya Diagnostics', 'diagnostic', 'Hyderabad', 88.70, 4.55, 9, '2026-05-30'::date, 'promote', 'X-ray + MRI cross-trained - matches diagnostic portfolio', 175000),
  ('2026-06-01'::date, 'ENG-005', 'Karthik Iyer', 'bronze', 'CUST-105', 'Krishna Pet Clinic', 'veterinary', 'Chennai', 62.30, 3.80, 2, '2026-04-10'::date, 'review', 'Low repeat count - review before promotion', 35000),
  ('2026-06-01'::date, 'ENG-006', 'Meera Patel', 'platinum', 'CUST-106', 'Manipal Hospital Whitefield', 'hospital', 'Bangalore', 94.80, 4.75, 14, '2026-05-29'::date, 'promote', 'Highest repeat in dataset - keep this engineer paired', 320000),
  ('2026-06-01'::date, 'ENG-007', 'Vikram Singh', 'silver', 'CUST-107', 'Hyderabad Dental Care', 'dental', 'Hyderabad', 71.50, 4.10, 4, '2026-05-08'::date, 'hold', 'Solid baseline - upskill needed for tier upgrade', 55000),
  ('2026-06-01'::date, 'ENG-008', 'Lakshmi Rao', 'bronze', 'CUST-108', 'Tirumala Clinic', 'clinic', 'Vijayawada', 48.20, 3.20, 1, '2026-03-15'::date, 'retire', 'Low match + low CSAT - retire pairing', 18000),
  ('2026-05-01'::date, 'ENG-001', 'Ravi Kumar', 'platinum', 'CUST-101', 'Apollo Hospitals Jubilee', 'hospital', 'Hyderabad', 95.10, 4.78, 11, '2026-04-30'::date, 'promote', 'Trending up - May baseline before June ramp', 265000),
  ('2026-05-01'::date, 'ENG-009', 'Sneha Joshi', 'gold', 'CUST-109', 'Continental Hospitals', 'hospital', 'Hyderabad', 89.40, 4.65, 7, '2026-04-25'::date, 'promote', 'Cath lab specialist - revenue compounding', 210000);

-- Seed promote actions
INSERT INTO engineer_promote_actions_r2818
  (month_start, engineer_code, customer_code, action_type, action_status, acted_by, notes)
VALUES
  ('2026-06-01'::date, 'ENG-001', 'CUST-101', 'promote', 'executed', 'founder', 'Locked Ravi to Apollo for Q2 - top performer'),
  ('2026-06-01'::date, 'ENG-002', 'CUST-102', 'promote', 'approved', 'founder', 'Promote Anjali to Yashoda primary engineer'),
  ('2026-06-01'::date, 'ENG-003', 'CUST-103', 'hold', 'pending', 'ops_lead', 'Wait for dental certification completion'),
  ('2026-06-01'::date, 'ENG-005', 'CUST-105', 'review', 'pending', 'founder', 'Schedule 1:1 to review fit and CSAT trend'),
  ('2026-06-01'::date, 'ENG-006', 'CUST-106', 'promote', 'executed', 'founder', 'Manipal anchor pair confirmed'),
  ('2026-06-01'::date, 'ENG-008', 'CUST-108', 'retire', 'approved', 'founder', 'Reassign Tirumala to ENG-007 next month'),
  ('2026-06-01'::date, 'ENG-004', 'CUST-104', 'promote', 'executed', 'ops_lead', 'Vijaya diagnostics auto-renewal triggered');

-- ============================================================================
-- RPC 1: KPI summary
-- ============================================================================
DROP FUNCTION IF EXISTS founder_engineer_recommendation_kpis_r2818();
CREATE OR REPLACE FUNCTION founder_engineer_recommendation_kpis_r2818()
RETURNS TABLE (
  total_recommendations bigint,
  promote_count bigint,
  hold_count bigint,
  review_count bigint,
  retire_count bigint,
  avg_match_score numeric,
  avg_satisfaction numeric,
  total_expected_revenue bigint,
  total_repeat_jobs bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    count(*)::bigint AS total_recommendations,
    count(*) FILTER (WHERE promote_action = 'promote')::bigint AS promote_count,
    count(*) FILTER (WHERE promote_action = 'hold')::bigint AS hold_count,
    count(*) FILTER (WHERE promote_action = 'review')::bigint AS review_count,
    count(*) FILTER (WHERE promote_action = 'retire')::bigint AS retire_count,
    round(avg(match_score), 2) AS avg_match_score,
    round(avg(satisfaction_score), 2) AS avg_satisfaction,
    coalesce(sum(expected_revenue_rupees), 0)::bigint AS total_expected_revenue,
    coalesce(sum(repeat_jobs_count), 0)::bigint AS total_repeat_jobs
  FROM engineer_customer_recommendations_r2818
  WHERE month_start = (SELECT max(month_start) FROM engineer_customer_recommendations_r2818);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_recommendation_kpis_r2818() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_recommendation_kpis_r2818() TO authenticated;

-- ============================================================================
-- RPC 2: Top recommendations (promote action)
-- ============================================================================
DROP FUNCTION IF EXISTS founder_engineer_top_promotions_r2818();
CREATE OR REPLACE FUNCTION founder_engineer_top_promotions_r2818()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  engineer_tier text,
  customer_name text,
  customer_segment text,
  city text,
  match_score numeric,
  satisfaction_score numeric,
  repeat_jobs_count int,
  expected_revenue_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.engineer_code,
    r.engineer_name,
    r.engineer_tier,
    r.customer_name,
    r.customer_segment,
    r.city,
    r.match_score,
    r.satisfaction_score,
    r.repeat_jobs_count,
    r.expected_revenue_rupees
  FROM engineer_customer_recommendations_r2818 r
  WHERE r.month_start = (SELECT max(month_start) FROM engineer_customer_recommendations_r2818)
    AND r.promote_action = 'promote'
  ORDER BY r.match_score DESC, r.expected_revenue_rupees DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_top_promotions_r2818() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_top_promotions_r2818() TO authenticated;

-- ============================================================================
-- RPC 3: Action queue (hold/review/retire)
-- ============================================================================
DROP FUNCTION IF EXISTS founder_engineer_action_queue_r2818();
CREATE OR REPLACE FUNCTION founder_engineer_action_queue_r2818()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  customer_name text,
  promote_action text,
  match_score numeric,
  satisfaction_score numeric,
  recommendation_reason text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.engineer_code,
    r.engineer_name,
    r.customer_name,
    r.promote_action,
    r.match_score,
    r.satisfaction_score,
    r.recommendation_reason
  FROM engineer_customer_recommendations_r2818 r
  WHERE r.month_start = (SELECT max(month_start) FROM engineer_customer_recommendations_r2818)
    AND r.promote_action IN ('hold','review','retire')
  ORDER BY 
    CASE r.promote_action 
      WHEN 'retire' THEN 1 
      WHEN 'review' THEN 2 
      WHEN 'hold' THEN 3 
    END,
    r.match_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_action_queue_r2818() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_action_queue_r2818() TO authenticated;

-- ============================================================================
-- RPC 4: Segment breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS founder_engineer_segment_breakdown_r2818();
CREATE OR REPLACE FUNCTION founder_engineer_segment_breakdown_r2818()
RETURNS TABLE (
  customer_segment text,
  pair_count bigint,
  avg_match numeric,
  avg_csat numeric,
  total_revenue bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.customer_segment,
    count(*)::bigint AS pair_count,
    round(avg(r.match_score), 2) AS avg_match,
    round(avg(r.satisfaction_score), 2) AS avg_csat,
    coalesce(sum(r.expected_revenue_rupees), 0)::bigint AS total_revenue
  FROM engineer_customer_recommendations_r2818 r
  WHERE r.month_start = (SELECT max(month_start) FROM engineer_customer_recommendations_r2818)
  GROUP BY r.customer_segment
  ORDER BY total_revenue DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_segment_breakdown_r2818() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_segment_breakdown_r2818() TO authenticated;

-- ============================================================================
-- RPC 5: Tier breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS founder_engineer_tier_breakdown_r2818();
CREATE OR REPLACE FUNCTION founder_engineer_tier_breakdown_r2818()
RETURNS TABLE (
  engineer_tier text,
  engineer_count bigint,
  avg_match numeric,
  avg_csat numeric,
  total_repeat_jobs bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.engineer_tier,
    count(DISTINCT r.engineer_code)::bigint AS engineer_count,
    round(avg(r.match_score), 2) AS avg_match,
    round(avg(r.satisfaction_score), 2) AS avg_csat,
    coalesce(sum(r.repeat_jobs_count), 0)::bigint AS total_repeat_jobs
  FROM engineer_customer_recommendations_r2818 r
  WHERE r.month_start = (SELECT max(month_start) FROM engineer_customer_recommendations_r2818)
  GROUP BY r.engineer_tier
  ORDER BY 
    CASE r.engineer_tier 
      WHEN 'platinum' THEN 1 
      WHEN 'gold' THEN 2 
      WHEN 'silver' THEN 3 
      WHEN 'bronze' THEN 4 
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_tier_breakdown_r2818() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_tier_breakdown_r2818() TO authenticated;

-- ============================================================================
-- RPC 6: Recent promote actions
-- ============================================================================
DROP FUNCTION IF EXISTS founder_engineer_recent_actions_r2818();
CREATE OR REPLACE FUNCTION founder_engineer_recent_actions_r2818()
RETURNS TABLE (
  engineer_code text,
  customer_code text,
  action_type text,
  action_status text,
  acted_by text,
  acted_at timestamptz,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    a.engineer_code,
    a.customer_code,
    a.action_type,
    a.action_status,
    a.acted_by,
    a.acted_at,
    a.notes
  FROM engineer_promote_actions_r2818 a
  ORDER BY a.acted_at DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_recent_actions_r2818() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_recent_actions_r2818() TO authenticated;

-- ============================================================================
-- RPC 7: City performance
-- ============================================================================
DROP FUNCTION IF EXISTS founder_engineer_city_performance_r2818();
CREATE OR REPLACE FUNCTION founder_engineer_city_performance_r2818()
RETURNS TABLE (
  city text,
  pair_count bigint,
  avg_match numeric,
  avg_csat numeric,
  total_revenue bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.city,
    count(*)::bigint AS pair_count,
    round(avg(r.match_score), 2) AS avg_match,
    round(avg(r.satisfaction_score), 2) AS avg_csat,
    coalesce(sum(r.expected_revenue_rupees), 0)::bigint AS total_revenue
  FROM engineer_customer_recommendations_r2818 r
  WHERE r.month_start = (SELECT max(month_start) FROM engineer_customer_recommendations_r2818)
  GROUP BY r.city
  ORDER BY total_revenue DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_city_performance_r2818() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_city_performance_r2818() TO authenticated;

-- ============================================================================
-- RPC 8: Month-over-month trend
-- ============================================================================
DROP FUNCTION IF EXISTS founder_engineer_mom_trend_r2818();
CREATE OR REPLACE FUNCTION founder_engineer_mom_trend_r2818()
RETURNS TABLE (
  month_start date,
  pair_count bigint,
  promote_count bigint,
  avg_match numeric,
  total_revenue bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.month_start,
    count(*)::bigint AS pair_count,
    count(*) FILTER (WHERE r.promote_action = 'promote')::bigint AS promote_count,
    round(avg(r.match_score), 2) AS avg_match,
    coalesce(sum(r.expected_revenue_rupees), 0)::bigint AS total_revenue
  FROM engineer_customer_recommendations_r2818 r
  GROUP BY r.month_start
  ORDER BY r.month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_mom_trend_r2818() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_mom_trend_r2818() TO authenticated;

COMMIT;
