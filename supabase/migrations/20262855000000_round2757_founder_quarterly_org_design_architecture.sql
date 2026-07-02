BEGIN;

-- ============================================================
-- Round 2757: Founder Quarterly Org Design Architecture
-- function x headcount x bottleneck x split/merge x redesign x outcome
-- ============================================================

CREATE TABLE IF NOT EXISTS org_function_capacity_r2757 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  function_name text NOT NULL,
  headcount_current int NOT NULL CHECK (headcount_current >= 0),
  headcount_target int NOT NULL CHECK (headcount_target >= 0),
  bottleneck_severity text NOT NULL CHECK (bottleneck_severity IN ('none','minor','moderate','severe','critical')),
  bottleneck_summary text NOT NULL,
  utilization_pct numeric(5,2) NOT NULL CHECK (utilization_pct >= 0 AND utilization_pct <= 200),
  attrition_pct numeric(5,2) NOT NULL CHECK (attrition_pct >= 0 AND attrition_pct <= 100),
  cost_per_quarter_rupees bigint NOT NULL CHECK (cost_per_quarter_rupees >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE org_function_capacity_r2757 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON org_function_capacity_r2757;
CREATE POLICY founder_all ON org_function_capacity_r2757 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS org_redesign_plays_r2757 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  function_name text NOT NULL,
  play_kind text NOT NULL CHECK (play_kind IN ('split','merge','hire','redesign','outsource','automate')),
  play_summary text NOT NULL,
  headcount_delta int NOT NULL,
  estimated_cost_rupees bigint NOT NULL CHECK (estimated_cost_rupees >= 0),
  expected_outcome text NOT NULL,
  outcome_status text NOT NULL CHECK (outcome_status IN ('proposed','approved','in_flight','realized','blocked','reversed')),
  realized_outcome text,
  effective_date date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE org_redesign_plays_r2757 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON org_redesign_plays_r2757;
CREATE POLICY founder_all ON org_redesign_plays_r2757 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seeds: capacity (5+ rows)
INSERT INTO org_function_capacity_r2757 (quarter, function_name, headcount_current, headcount_target, bottleneck_severity, bottleneck_summary, utilization_pct, attrition_pct, cost_per_quarter_rupees, notes) VALUES
('Q3-2026', 'Field Engineering', 42, 58, 'severe', 'Tier-2 cities understaffed, SLA breach risk', 118.50, 14.20, 2520000, 'Hyderabad + Vizag hotspots'),
('Q3-2026', 'Customer Support', 9, 12, 'moderate', 'Chat queue spikes evenings', 92.30, 8.50, 540000, 'Add 1 Telugu speaker'),
('Q3-2026', 'Spare Parts Ops', 5, 8, 'critical', 'Counterfeit gate manual review backlog', 145.00, 0.00, 350000, 'Hire QA + automate detection'),
('Q3-2026', 'Engineering (Software)', 6, 9, 'severe', 'Android + web feature pipeline starved', 132.00, 16.60, 1080000, 'Senior Android hire stuck 3mo'),
('Q3-2026', 'Finance & GST', 2, 3, 'moderate', 'Month-end close stretches 9 days', 105.00, 0.00, 240000, 'Promote junior to senior'),
('Q3-2026', 'Sales & BD', 8, 11, 'severe', 'Hospital chain RFPs slipping', 124.00, 12.50, 720000, 'Need enterprise AE'),
('Q3-2026', 'AMC Retention', 4, 4, 'minor', 'Healthy capacity post automation', 78.00, 0.00, 280000, 'Backstop for sick days only');

-- Seeds: plays (5+ rows)
INSERT INTO org_redesign_plays_r2757 (quarter, function_name, play_kind, play_summary, headcount_delta, estimated_cost_rupees, expected_outcome, outcome_status, realized_outcome, effective_date) VALUES
('Q3-2026', 'Field Engineering', 'split', 'Split into Tier-1 and Tier-2 pods with separate leads', 16, 960000, 'SLA breaches drop from 12pct to 4pct', 'in_flight', NULL, '2026-07-15'::date),
('Q3-2026', 'Spare Parts Ops', 'automate', 'Auto-classify counterfeit risk via CV model', 1, 180000, 'Manual review backlog from 48h to 6h', 'approved', NULL, '2026-08-01'::date),
('Q3-2026', 'Customer Support', 'merge', 'Merge AMC retention into support pod off-peak', -1, 0, 'Coverage hours extend without new hires', 'proposed', NULL, '2026-09-01'::date),
('Q3-2026', 'Engineering (Software)', 'hire', 'Senior Android + 1 backend + 1 designer', 3, 540000, 'Ship cadence doubles, audit debt halves', 'in_flight', 'Android hire signed offer', '2026-07-20'::date),
('Q3-2026', 'Sales & BD', 'redesign', 'Carve enterprise pod, separate AE/SDR ladders', 3, 360000, 'Hospital chain pipeline triples', 'approved', NULL, '2026-08-15'::date),
('Q2-2026', 'Finance & GST', 'redesign', 'Close calendar revamp + automation of filings', 0, 60000, 'Close days from 9 to 4', 'realized', 'Close ran in 5 days', '2026-04-15'::date),
('Q2-2026', 'Field Engineering', 'hire', 'Bulk hire 10 engineers Tier-2', 10, 600000, 'Coverage in 6 new pincodes', 'realized', '8 of 10 onboarded, 2 dropped', '2026-05-10'::date);

-- ============================================================
-- RPCs (7+)
-- ============================================================

DROP FUNCTION IF EXISTS founder_org_capacity_overview_r2757();
CREATE OR REPLACE FUNCTION founder_org_capacity_overview_r2757()
RETURNS TABLE (
  total_functions bigint,
  total_headcount bigint,
  total_target bigint,
  critical_functions bigint,
  severe_functions bigint,
  total_quarterly_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(headcount_current),0)::bigint,
    COALESCE(SUM(headcount_target),0)::bigint,
    COUNT(*) FILTER (WHERE bottleneck_severity='critical')::bigint,
    COUNT(*) FILTER (WHERE bottleneck_severity='severe')::bigint,
    COALESCE(SUM(cost_per_quarter_rupees),0)::bigint
  FROM org_function_capacity_r2757
  WHERE quarter='Q3-2026';
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_org_capacity_overview_r2757() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_org_capacity_overview_r2757() TO authenticated;

DROP FUNCTION IF EXISTS founder_org_capacity_list_r2757();
CREATE OR REPLACE FUNCTION founder_org_capacity_list_r2757()
RETURNS SETOF org_function_capacity_r2757
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM org_function_capacity_r2757
  ORDER BY
    CASE bottleneck_severity
      WHEN 'critical' THEN 1
      WHEN 'severe' THEN 2
      WHEN 'moderate' THEN 3
      WHEN 'minor' THEN 4
      ELSE 5
    END,
    utilization_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_org_capacity_list_r2757() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_org_capacity_list_r2757() TO authenticated;

DROP FUNCTION IF EXISTS founder_org_bottleneck_hotspots_r2757();
CREATE OR REPLACE FUNCTION founder_org_bottleneck_hotspots_r2757()
RETURNS TABLE (
  function_name text,
  headcount_gap int,
  utilization_pct numeric,
  attrition_pct numeric,
  bottleneck_severity text,
  cost_per_quarter_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.function_name,
    (c.headcount_target - c.headcount_current)::int,
    c.utilization_pct,
    c.attrition_pct,
    c.bottleneck_severity,
    c.cost_per_quarter_rupees
  FROM org_function_capacity_r2757 c
  WHERE c.bottleneck_severity IN ('severe','critical')
    AND c.quarter='Q3-2026'
  ORDER BY c.utilization_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_org_bottleneck_hotspots_r2757() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_org_bottleneck_hotspots_r2757() TO authenticated;

DROP FUNCTION IF EXISTS founder_org_plays_list_r2757();
CREATE OR REPLACE FUNCTION founder_org_plays_list_r2757()
RETURNS SETOF org_redesign_plays_r2757
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM org_redesign_plays_r2757
  ORDER BY effective_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_org_plays_list_r2757() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_org_plays_list_r2757() TO authenticated;

DROP FUNCTION IF EXISTS founder_org_plays_by_kind_r2757();
CREATE OR REPLACE FUNCTION founder_org_plays_by_kind_r2757()
RETURNS TABLE (
  play_kind text,
  total_plays bigint,
  total_headcount_delta bigint,
  total_cost_rupees bigint,
  realized_plays bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.play_kind,
    COUNT(*)::bigint,
    COALESCE(SUM(p.headcount_delta),0)::bigint,
    COALESCE(SUM(p.estimated_cost_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE p.outcome_status='realized')::bigint
  FROM org_redesign_plays_r2757 p
  GROUP BY p.play_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_org_plays_by_kind_r2757() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_org_plays_by_kind_r2757() TO authenticated;

DROP FUNCTION IF EXISTS founder_org_plays_outcome_summary_r2757();
CREATE OR REPLACE FUNCTION founder_org_plays_outcome_summary_r2757()
RETURNS TABLE (
  outcome_status text,
  total bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.outcome_status,
    COUNT(*)::bigint,
    COALESCE(SUM(p.estimated_cost_rupees),0)::bigint
  FROM org_redesign_plays_r2757 p
  GROUP BY p.outcome_status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_org_plays_outcome_summary_r2757() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_org_plays_outcome_summary_r2757() TO authenticated;

DROP FUNCTION IF EXISTS founder_org_function_play_alignment_r2757();
CREATE OR REPLACE FUNCTION founder_org_function_play_alignment_r2757()
RETURNS TABLE (
  function_name text,
  bottleneck_severity text,
  headcount_gap int,
  plays_in_flight bigint,
  plays_approved bigint,
  has_coverage boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.function_name,
    c.bottleneck_severity,
    (c.headcount_target - c.headcount_current)::int,
    COUNT(p.*) FILTER (WHERE p.outcome_status='in_flight')::bigint,
    COUNT(p.*) FILTER (WHERE p.outcome_status='approved')::bigint,
    (COUNT(p.*) FILTER (WHERE p.outcome_status IN ('in_flight','approved','realized')) > 0)
  FROM org_function_capacity_r2757 c
  LEFT JOIN org_redesign_plays_r2757 p
    ON p.function_name = c.function_name AND p.quarter = c.quarter
  WHERE c.quarter='Q3-2026'
  GROUP BY c.function_name, c.bottleneck_severity, c.headcount_target, c.headcount_current
  ORDER BY c.function_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_org_function_play_alignment_r2757() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_org_function_play_alignment_r2757() TO authenticated;

DROP FUNCTION IF EXISTS founder_org_quarterly_cost_trajectory_r2757();
CREATE OR REPLACE FUNCTION founder_org_quarterly_cost_trajectory_r2757()
RETURNS TABLE (
  quarter text,
  total_headcount bigint,
  total_cost_rupees bigint,
  realized_play_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.quarter,
    COALESCE(SUM(c.headcount_current),0)::bigint,
    COALESCE(SUM(c.cost_per_quarter_rupees),0)::bigint,
    COALESCE((SELECT SUM(p.estimated_cost_rupees) FROM org_redesign_plays_r2757 p WHERE p.quarter=c.quarter AND p.outcome_status='realized'),0)::bigint
  FROM org_function_capacity_r2757 c
  GROUP BY c.quarter
  ORDER BY c.quarter DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_org_quarterly_cost_trajectory_r2757() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_org_quarterly_cost_trajectory_r2757() TO authenticated;

COMMIT;
