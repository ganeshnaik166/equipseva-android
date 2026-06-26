BEGIN;

-- ============================================================================
-- Round 2794: Engineer Monthly Tier Promotion Time-to-Readiness
-- engineer × current × target × milestones met × gaps × weeks-to-ready × verdict
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_tier_readiness_snapshots_r2794 (
  id BIGSERIAL PRIMARY KEY,
  snapshot_month DATE NOT NULL,
  engineer_id UUID NOT NULL,
  engineer_name TEXT NOT NULL,
  region TEXT NOT NULL,
  current_tier TEXT NOT NULL CHECK (current_tier IN ('bronze','silver','gold','platinum')),
  target_tier TEXT NOT NULL CHECK (target_tier IN ('silver','gold','platinum','diamond')),
  milestones_required INT NOT NULL CHECK (milestones_required > 0),
  milestones_met INT NOT NULL CHECK (milestones_met >= 0),
  gaps_count INT NOT NULL CHECK (gaps_count >= 0),
  weeks_to_ready NUMERIC(5,1) NOT NULL CHECK (weeks_to_ready >= 0),
  current_velocity_per_week NUMERIC(5,2) NOT NULL CHECK (current_velocity_per_week >= 0),
  verdict TEXT NOT NULL CHECK (verdict IN ('on_track','at_risk','blocked','ready_now','stalled')),
  promotion_recommended BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE engineer_tier_readiness_snapshots_r2794 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_tier_readiness_snapshots_r2794;
CREATE POLICY founder_all ON engineer_tier_readiness_snapshots_r2794
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_tier_milestone_gaps_r2794 (
  id BIGSERIAL PRIMARY KEY,
  snapshot_id BIGINT NOT NULL REFERENCES engineer_tier_readiness_snapshots_r2794(id) ON DELETE CASCADE,
  milestone_code TEXT NOT NULL,
  milestone_label TEXT NOT NULL,
  required_value NUMERIC(10,2) NOT NULL,
  current_value NUMERIC(10,2) NOT NULL,
  gap_value NUMERIC(10,2) NOT NULL,
  unit TEXT NOT NULL CHECK (unit IN ('count','percent','rupees','days','jobs')),
  blocker_type TEXT NOT NULL CHECK (blocker_type IN ('volume','quality','training','certification','tenure','none')),
  estimated_weeks_to_close NUMERIC(5,1) NOT NULL CHECK (estimated_weeks_to_close >= 0),
  status TEXT NOT NULL CHECK (status IN ('open','in_progress','closed','blocked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE engineer_tier_milestone_gaps_r2794 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_tier_milestone_gaps_r2794;
CREATE POLICY founder_all ON engineer_tier_milestone_gaps_r2794
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- SEEDS
-- ============================================================================

INSERT INTO engineer_tier_readiness_snapshots_r2794
  (snapshot_month, engineer_id, engineer_name, region, current_tier, target_tier,
   milestones_required, milestones_met, gaps_count, weeks_to_ready,
   current_velocity_per_week, verdict, promotion_recommended, notes)
VALUES
  ('2026-06-01'::date, '11111111-1111-1111-1111-111111111111'::uuid, 'Ravi Kumar', 'south',
   'bronze', 'silver', 5, 5, 0, 0.0, 1.20, 'ready_now', true,
   'All 5 silver milestones met for 2 consecutive months. Promote.'),
  ('2026-06-01'::date, '22222222-2222-2222-2222-222222222222'::uuid, 'Anjali Sharma', 'north',
   'silver', 'gold', 7, 5, 2, 4.5, 0.80, 'on_track', false,
   'Needs +12 repair jobs and one OEM cert. Pace OK.'),
  ('2026-06-01'::date, '33333333-3333-3333-3333-333333333333'::uuid, 'Suresh Patel', 'west',
   'silver', 'gold', 7, 3, 4, 11.0, 0.40, 'at_risk', false,
   'CSAT below 4.5 threshold. Coaching scheduled.'),
  ('2026-06-01'::date, '44444444-4444-4444-4444-444444444444'::uuid, 'Priya Nair', 'south',
   'gold', 'platinum', 9, 4, 5, 18.0, 0.30, 'blocked', false,
   'Hospital-network certification expired. Re-cert required first.'),
  ('2026-06-01'::date, '55555555-5555-5555-5555-555555555555'::uuid, 'Mohammed Ali', 'east',
   'bronze', 'silver', 5, 2, 3, 9.0, 0.50, 'at_risk', false,
   'Tenure clock at 4 months of 6 required.'),
  ('2026-06-01'::date, '66666666-6666-6666-6666-666666666666'::uuid, 'Deepika Rao', 'south',
   'gold', 'platinum', 9, 9, 0, 0.0, 1.00, 'ready_now', true,
   'Diamond-tier candidate next quarter.'),
  ('2026-06-01'::date, '77777777-7777-7777-7777-777777777777'::uuid, 'Karthik Iyer', 'south',
   'silver', 'gold', 7, 1, 6, 24.0, 0.10, 'stalled', false,
   'No new jobs in 8 weeks. Outreach pending.');

INSERT INTO engineer_tier_milestone_gaps_r2794
  (snapshot_id, milestone_code, milestone_label, required_value, current_value,
   gap_value, unit, blocker_type, estimated_weeks_to_close, status)
VALUES
  (2, 'jobs_completed_90d', '90-day repair job count', 60, 48, 12, 'count', 'volume', 3.0, 'in_progress'),
  (2, 'oem_certs', 'OEM certifications held', 3, 2, 1, 'count', 'certification', 4.5, 'open'),
  (3, 'csat_score', 'Rolling CSAT score', 4.50, 4.20, 0.30, 'percent', 'quality', 8.0, 'in_progress'),
  (3, 'first_visit_fix', 'First-visit fix rate', 0.85, 0.72, 0.13, 'percent', 'quality', 6.0, 'open'),
  (3, 'training_modules', 'Advanced training modules', 4, 2, 2, 'count', 'training', 5.0, 'open'),
  (3, 'jobs_completed_90d', '90-day repair job count', 60, 55, 5, 'count', 'volume', 2.0, 'in_progress'),
  (4, 'hospital_network_cert', 'Hospital network certification', 1, 0, 1, 'count', 'certification', 12.0, 'blocked'),
  (4, 'csat_score', 'Rolling CSAT score', 4.75, 4.60, 0.15, 'percent', 'quality', 6.0, 'open'),
  (5, 'tenure_months', 'Months on platform', 6, 4, 2, 'days', 'tenure', 8.0, 'in_progress'),
  (5, 'training_modules', 'Foundation training modules', 5, 3, 2, 'count', 'training', 3.0, 'in_progress'),
  (7, 'jobs_completed_90d', '90-day repair job count', 60, 8, 52, 'count', 'volume', 22.0, 'blocked');

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2794_readiness_kpis();
CREATE OR REPLACE FUNCTION founder_r2794_readiness_kpis()
RETURNS TABLE (
  total_engineers BIGINT,
  ready_now BIGINT,
  on_track BIGINT,
  at_risk BIGINT,
  blocked_or_stalled BIGINT,
  avg_weeks_to_ready NUMERIC,
  recommended_for_promotion BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT,
    COUNT(*) FILTER (WHERE verdict = 'ready_now')::BIGINT,
    COUNT(*) FILTER (WHERE verdict = 'on_track')::BIGINT,
    COUNT(*) FILTER (WHERE verdict = 'at_risk')::BIGINT,
    COUNT(*) FILTER (WHERE verdict IN ('blocked','stalled'))::BIGINT,
    ROUND(AVG(weeks_to_ready)::NUMERIC, 1),
    COUNT(*) FILTER (WHERE promotion_recommended)::BIGINT
  FROM engineer_tier_readiness_snapshots_r2794
  WHERE snapshot_month = (SELECT MAX(snapshot_month) FROM engineer_tier_readiness_snapshots_r2794);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2794_readiness_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2794_readiness_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2794_readiness_roster();
CREATE OR REPLACE FUNCTION founder_r2794_readiness_roster()
RETURNS TABLE (
  id BIGINT,
  engineer_name TEXT,
  region TEXT,
  current_tier TEXT,
  target_tier TEXT,
  milestones_met INT,
  milestones_required INT,
  gaps_count INT,
  weeks_to_ready NUMERIC,
  verdict TEXT,
  promotion_recommended BOOLEAN,
  notes TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_name, s.region, s.current_tier, s.target_tier,
         s.milestones_met, s.milestones_required, s.gaps_count,
         s.weeks_to_ready, s.verdict, s.promotion_recommended, s.notes
  FROM engineer_tier_readiness_snapshots_r2794 s
  WHERE s.snapshot_month = (SELECT MAX(snapshot_month) FROM engineer_tier_readiness_snapshots_r2794)
  ORDER BY
    CASE s.verdict
      WHEN 'ready_now' THEN 1
      WHEN 'on_track' THEN 2
      WHEN 'at_risk' THEN 3
      WHEN 'blocked' THEN 4
      WHEN 'stalled' THEN 5
    END,
    s.weeks_to_ready ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2794_readiness_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2794_readiness_roster() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2794_promotion_recommendations();
CREATE OR REPLACE FUNCTION founder_r2794_promotion_recommendations()
RETURNS TABLE (
  engineer_name TEXT,
  region TEXT,
  current_tier TEXT,
  target_tier TEXT,
  milestones_met INT,
  weeks_to_ready NUMERIC,
  verdict TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.region, s.current_tier, s.target_tier,
         s.milestones_met, s.weeks_to_ready, s.verdict
  FROM engineer_tier_readiness_snapshots_r2794 s
  WHERE s.promotion_recommended = true
    AND s.snapshot_month = (SELECT MAX(snapshot_month) FROM engineer_tier_readiness_snapshots_r2794)
  ORDER BY s.engineer_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2794_promotion_recommendations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2794_promotion_recommendations() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2794_verdict_breakdown();
CREATE OR REPLACE FUNCTION founder_r2794_verdict_breakdown()
RETURNS TABLE (
  verdict TEXT,
  engineers BIGINT,
  avg_weeks_to_ready NUMERIC,
  avg_milestones_met NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.verdict,
         COUNT(*)::BIGINT,
         ROUND(AVG(s.weeks_to_ready)::NUMERIC, 1),
         ROUND(AVG(s.milestones_met)::NUMERIC, 1)
  FROM engineer_tier_readiness_snapshots_r2794 s
  WHERE s.snapshot_month = (SELECT MAX(snapshot_month) FROM engineer_tier_readiness_snapshots_r2794)
  GROUP BY s.verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2794_verdict_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2794_verdict_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2794_tier_path_summary();
CREATE OR REPLACE FUNCTION founder_r2794_tier_path_summary()
RETURNS TABLE (
  current_tier TEXT,
  target_tier TEXT,
  engineers BIGINT,
  ready_now BIGINT,
  avg_weeks NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.current_tier, s.target_tier,
         COUNT(*)::BIGINT,
         COUNT(*) FILTER (WHERE s.verdict = 'ready_now')::BIGINT,
         ROUND(AVG(s.weeks_to_ready)::NUMERIC, 1)
  FROM engineer_tier_readiness_snapshots_r2794 s
  WHERE s.snapshot_month = (SELECT MAX(snapshot_month) FROM engineer_tier_readiness_snapshots_r2794)
  GROUP BY s.current_tier, s.target_tier
  ORDER BY s.current_tier, s.target_tier;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2794_tier_path_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2794_tier_path_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2794_top_gaps();
CREATE OR REPLACE FUNCTION founder_r2794_top_gaps()
RETURNS TABLE (
  milestone_code TEXT,
  milestone_label TEXT,
  blocker_type TEXT,
  engineers_affected BIGINT,
  avg_gap NUMERIC,
  avg_weeks_to_close NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.milestone_code, g.milestone_label, g.blocker_type,
         COUNT(*)::BIGINT,
         ROUND(AVG(g.gap_value)::NUMERIC, 2),
         ROUND(AVG(g.estimated_weeks_to_close)::NUMERIC, 1)
  FROM engineer_tier_milestone_gaps_r2794 g
  WHERE g.status IN ('open','in_progress','blocked')
  GROUP BY g.milestone_code, g.milestone_label, g.blocker_type
  ORDER BY COUNT(*) DESC, AVG(g.estimated_weeks_to_close) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2794_top_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2794_top_gaps() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2794_region_readiness();
CREATE OR REPLACE FUNCTION founder_r2794_region_readiness()
RETURNS TABLE (
  region TEXT,
  engineers BIGINT,
  ready_now BIGINT,
  at_risk_or_blocked BIGINT,
  avg_weeks NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.region,
         COUNT(*)::BIGINT,
         COUNT(*) FILTER (WHERE s.verdict = 'ready_now')::BIGINT,
         COUNT(*) FILTER (WHERE s.verdict IN ('at_risk','blocked','stalled'))::BIGINT,
         ROUND(AVG(s.weeks_to_ready)::NUMERIC, 1)
  FROM engineer_tier_readiness_snapshots_r2794 s
  WHERE s.snapshot_month = (SELECT MAX(snapshot_month) FROM engineer_tier_readiness_snapshots_r2794)
  GROUP BY s.region
  ORDER BY s.region;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2794_region_readiness() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2794_region_readiness() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2794_blocked_engineers();
CREATE OR REPLACE FUNCTION founder_r2794_blocked_engineers()
RETURNS TABLE (
  engineer_name TEXT,
  region TEXT,
  current_tier TEXT,
  target_tier TEXT,
  gaps_count INT,
  weeks_to_ready NUMERIC,
  verdict TEXT,
  notes TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.region, s.current_tier, s.target_tier,
         s.gaps_count, s.weeks_to_ready, s.verdict, s.notes
  FROM engineer_tier_readiness_snapshots_r2794 s
  WHERE s.verdict IN ('blocked','stalled','at_risk')
    AND s.snapshot_month = (SELECT MAX(snapshot_month) FROM engineer_tier_readiness_snapshots_r2794)
  ORDER BY s.weeks_to_ready DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2794_blocked_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2794_blocked_engineers() TO authenticated;

COMMIT;
