BEGIN;

-- ============================================================
-- Round 2694: Engineer Quarterly Cross-Region Rotation
-- ============================================================

-- Table 1: rotation plans
CREATE TABLE IF NOT EXISTS engineer_cross_region_rotations_r2694 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  quarter text NOT NULL,
  from_region text NOT NULL,
  to_region text NOT NULL,
  duration_weeks int NOT NULL CHECK (duration_weeks BETWEEN 2 AND 26),
  skill_goal text NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','active','completed','cancelled','deferred')),
  outcome text CHECK (outcome IS NULL OR outcome IN ('exceeded','met','partial','missed','pending')),
  jobs_completed int NOT NULL DEFAULT 0,
  csat_avg numeric(3,2),
  start_on date NOT NULL,
  end_on date NOT NULL,
  travel_cost_rupees int NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_cross_region_rotations_r2694 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_cross_region_rotations_r2694;
CREATE POLICY founder_all ON engineer_cross_region_rotations_r2694 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_cross_region_rotations_r2694
  (engineer_code, engineer_name, quarter, from_region, to_region, duration_weeks, skill_goal, status, outcome, jobs_completed, csat_avg, start_on, end_on, travel_cost_rupees, notes)
VALUES
  ('ENG-1042','Ravi Kumar','2026-Q3','Hyderabad','Mumbai',8,'CT scanner field-service certification','completed','exceeded',47,4.82,'2026-04-05'::date,'2026-05-31'::date,38500,'Apollo Mumbai placement; closed 3 escalations'),
  ('ENG-1087','Priya Nair','2026-Q3','Chennai','Bengaluru',6,'MRI cryogen handling exposure','completed','met',31,4.55,'2026-04-12'::date,'2026-05-24'::date,21000,'Manipal hospital cluster'),
  ('ENG-1153','Arjun Reddy','2026-Q3','Hyderabad','Delhi NCR',12,'Cath-lab senior shadowing','active','pending',22,4.40,'2026-05-01'::date,'2026-07-24'::date,54200,'Max Saket + Fortis Gurugram'),
  ('ENG-1199','Meera Iyer','2026-Q3','Pune','Kolkata',4,'Ventilator depot turnaround','completed','partial',14,3.95,'2026-04-20'::date,'2026-05-18'::date,28800,'Backlog cleared but CSAT below 4.2 threshold'),
  ('ENG-1224','Suresh Patil','2026-Q3','Mumbai','Hyderabad',10,'Reverse rotation — dialysis tier-1','active','pending',18,4.65,'2026-05-10'::date,'2026-07-19'::date,17500,'Returning home region with new vertical'),
  ('ENG-1278','Anita Desai','2026-Q3','Bengaluru','Chennai',8,'Endoscopy tower cross-training','planned',NULL,0,NULL,'2026-07-01'::date,'2026-08-26'::date,22000,'Q3 wave-2 placement'),
  ('ENG-1311','Vikram Singh','2026-Q3','Delhi NCR','Pune',6,'Linac calibration apprenticeship','planned',NULL,0,NULL,'2026-07-15'::date,'2026-08-26'::date,31000,'Ruby Hall partnership');

-- Table 2: skill checkpoints captured during rotation
CREATE TABLE IF NOT EXISTS engineer_rotation_skill_checkpoints_r2694 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rotation_id uuid NOT NULL REFERENCES engineer_cross_region_rotations_r2694(id) ON DELETE CASCADE,
  checkpoint_week int NOT NULL CHECK (checkpoint_week BETWEEN 1 AND 26),
  skill_area text NOT NULL,
  proficiency_before int NOT NULL CHECK (proficiency_before BETWEEN 1 AND 5),
  proficiency_after int NOT NULL CHECK (proficiency_after BETWEEN 1 AND 5),
  mentor_code text NOT NULL,
  signed_off boolean NOT NULL DEFAULT false,
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_rotation_skill_checkpoints_r2694 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_rotation_skill_checkpoints_r2694;
CREATE POLICY founder_all ON engineer_rotation_skill_checkpoints_r2694 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_rotation_skill_checkpoints_r2694
  (rotation_id, checkpoint_week, skill_area, proficiency_before, proficiency_after, mentor_code, signed_off, notes)
SELECT id, 4, 'CT gantry alignment', 2, 4, 'MNT-201', true, 'Cleared OEM checklist' FROM engineer_cross_region_rotations_r2694 WHERE engineer_code='ENG-1042'
UNION ALL
SELECT id, 8, 'CT tube swap end-to-end', 3, 5, 'MNT-201', true, 'Independent on tube change' FROM engineer_cross_region_rotations_r2694 WHERE engineer_code='ENG-1042'
UNION ALL
SELECT id, 3, 'Cryogen safety SOP', 2, 4, 'MNT-318', true, 'Passed practical' FROM engineer_cross_region_rotations_r2694 WHERE engineer_code='ENG-1087'
UNION ALL
SELECT id, 6, 'Coil diagnostics', 3, 4, 'MNT-318', true, 'Needs 1 more cycle' FROM engineer_cross_region_rotations_r2694 WHERE engineer_code='ENG-1087'
UNION ALL
SELECT id, 4, 'Cath-lab shadowing log', 1, 3, 'MNT-455', false, 'Awaiting senior sign-off' FROM engineer_cross_region_rotations_r2694 WHERE engineer_code='ENG-1153'
UNION ALL
SELECT id, 2, 'Vent preventive maintenance', 3, 4, 'MNT-507', true, 'Faster turnaround' FROM engineer_cross_region_rotations_r2694 WHERE engineer_code='ENG-1199'
UNION ALL
SELECT id, 5, 'Dialysis water-loop audit', 2, 4, 'MNT-612', true, 'Returns to home region certified' FROM engineer_cross_region_rotations_r2694 WHERE engineer_code='ENG-1224';

-- ============================================================
-- RPC 1: KPI summary
-- ============================================================
DROP FUNCTION IF EXISTS founder_r2694_rotation_kpis();
CREATE OR REPLACE FUNCTION founder_r2694_rotation_kpis()
RETURNS TABLE (
  total_rotations bigint,
  active_rotations bigint,
  completed_rotations bigint,
  planned_rotations bigint,
  total_travel_cost_rupees bigint,
  avg_csat numeric,
  avg_duration_weeks numeric,
  exceeded_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status='active')::bigint,
    COUNT(*) FILTER (WHERE status='completed')::bigint,
    COUNT(*) FILTER (WHERE status='planned')::bigint,
    COALESCE(SUM(travel_cost_rupees),0)::bigint,
    ROUND(AVG(csat_avg)::numeric, 2),
    ROUND(AVG(duration_weeks)::numeric, 1),
    COUNT(*) FILTER (WHERE outcome='exceeded')::bigint
  FROM engineer_cross_region_rotations_r2694;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2694_rotation_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2694_rotation_kpis() TO authenticated;

-- ============================================================
-- RPC 2: list all rotations
-- ============================================================
DROP FUNCTION IF EXISTS founder_r2694_list_rotations();
CREATE OR REPLACE FUNCTION founder_r2694_list_rotations()
RETURNS TABLE (
  id uuid,
  engineer_code text,
  engineer_name text,
  quarter text,
  from_region text,
  to_region text,
  duration_weeks int,
  skill_goal text,
  status text,
  outcome text,
  jobs_completed int,
  csat_avg numeric,
  start_on date,
  end_on date,
  travel_cost_rupees int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_code, r.engineer_name, r.quarter, r.from_region, r.to_region,
         r.duration_weeks, r.skill_goal, r.status, r.outcome, r.jobs_completed, r.csat_avg,
         r.start_on, r.end_on, r.travel_cost_rupees
  FROM engineer_cross_region_rotations_r2694 r
  ORDER BY r.start_on DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2694_list_rotations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2694_list_rotations() TO authenticated;

-- ============================================================
-- RPC 3: region flow matrix
-- ============================================================
DROP FUNCTION IF EXISTS founder_r2694_region_flow();
CREATE OR REPLACE FUNCTION founder_r2694_region_flow()
RETURNS TABLE (
  from_region text,
  to_region text,
  rotation_count bigint,
  total_weeks bigint,
  avg_csat numeric,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.from_region, r.to_region,
         COUNT(*)::bigint,
         COALESCE(SUM(r.duration_weeks),0)::bigint,
         ROUND(AVG(r.csat_avg)::numeric, 2),
         COALESCE(SUM(r.travel_cost_rupees),0)::bigint
  FROM engineer_cross_region_rotations_r2694 r
  GROUP BY r.from_region, r.to_region
  ORDER BY rotation_count DESC, r.from_region;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2694_region_flow() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2694_region_flow() TO authenticated;

-- ============================================================
-- RPC 4: outcome breakdown
-- ============================================================
DROP FUNCTION IF EXISTS founder_r2694_outcome_breakdown();
CREATE OR REPLACE FUNCTION founder_r2694_outcome_breakdown()
RETURNS TABLE (
  outcome_bucket text,
  rotation_count bigint,
  avg_jobs_completed numeric,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(r.outcome, 'in-progress') AS outcome_bucket,
         COUNT(*)::bigint,
         ROUND(AVG(r.jobs_completed)::numeric, 1),
         ROUND(AVG(r.csat_avg)::numeric, 2)
  FROM engineer_cross_region_rotations_r2694 r
  GROUP BY COALESCE(r.outcome, 'in-progress')
  ORDER BY rotation_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2694_outcome_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2694_outcome_breakdown() TO authenticated;

-- ============================================================
-- RPC 5: skill checkpoint roll-up
-- ============================================================
DROP FUNCTION IF EXISTS founder_r2694_skill_checkpoints();
CREATE OR REPLACE FUNCTION founder_r2694_skill_checkpoints()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  skill_area text,
  proficiency_before int,
  proficiency_after int,
  delta int,
  mentor_code text,
  signed_off boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_code, r.engineer_name, c.skill_area,
         c.proficiency_before, c.proficiency_after,
         (c.proficiency_after - c.proficiency_before),
         c.mentor_code, c.signed_off
  FROM engineer_rotation_skill_checkpoints_r2694 c
  JOIN engineer_cross_region_rotations_r2694 r ON r.id = c.rotation_id
  ORDER BY (c.proficiency_after - c.proficiency_before) DESC, r.engineer_code;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2694_skill_checkpoints() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2694_skill_checkpoints() TO authenticated;

-- ============================================================
-- RPC 6: top performers by csat per region
-- ============================================================
DROP FUNCTION IF EXISTS founder_r2694_top_performers();
CREATE OR REPLACE FUNCTION founder_r2694_top_performers()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  to_region text,
  skill_goal text,
  csat_avg numeric,
  jobs_completed int,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_code, r.engineer_name, r.to_region, r.skill_goal,
         r.csat_avg, r.jobs_completed, r.outcome
  FROM engineer_cross_region_rotations_r2694 r
  WHERE r.csat_avg IS NOT NULL
  ORDER BY r.csat_avg DESC, r.jobs_completed DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2694_top_performers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2694_top_performers() TO authenticated;

-- ============================================================
-- RPC 7: travel cost by quarter
-- ============================================================
DROP FUNCTION IF EXISTS founder_r2694_travel_cost_by_quarter();
CREATE OR REPLACE FUNCTION founder_r2694_travel_cost_by_quarter()
RETURNS TABLE (
  quarter text,
  rotation_count bigint,
  total_cost_rupees bigint,
  avg_cost_rupees numeric,
  avg_duration_weeks numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.quarter,
         COUNT(*)::bigint,
         COALESCE(SUM(r.travel_cost_rupees),0)::bigint,
         ROUND(AVG(r.travel_cost_rupees)::numeric, 0),
         ROUND(AVG(r.duration_weeks)::numeric, 1)
  FROM engineer_cross_region_rotations_r2694 r
  GROUP BY r.quarter
  ORDER BY r.quarter DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2694_travel_cost_by_quarter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2694_travel_cost_by_quarter() TO authenticated;

-- ============================================================
-- RPC 8: action items (planned + at-risk active)
-- ============================================================
DROP FUNCTION IF EXISTS founder_r2694_action_items();
CREATE OR REPLACE FUNCTION founder_r2694_action_items()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  to_region text,
  status text,
  start_on date,
  end_on date,
  flag text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_code, r.engineer_name, r.to_region, r.status, r.start_on, r.end_on,
         CASE
           WHEN r.status='planned' AND r.start_on <= (current_date + INTERVAL '14 days')::date THEN 'kickoff-due'
           WHEN r.status='active' AND r.csat_avg IS NOT NULL AND r.csat_avg < 4.20 THEN 'csat-below-bar'
           WHEN r.status='active' AND r.end_on <= (current_date + INTERVAL '14 days')::date THEN 'wrap-up-due'
           ELSE 'monitor'
         END
  FROM engineer_cross_region_rotations_r2694 r
  WHERE r.status IN ('planned','active')
  ORDER BY r.start_on;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2694_action_items() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2694_action_items() TO authenticated;

COMMIT;