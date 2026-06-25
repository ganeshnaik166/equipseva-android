BEGIN;

-- =====================================================================
-- Round r2750: Engineer Monthly Recall Action Readiness
-- Engineer x OEM recall x kit ready x training x turnaround x verification
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: engineer recall readiness scorecard
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS engineer_recall_readiness_r2750 CASCADE;

CREATE TABLE engineer_recall_readiness_r2750 (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code    text NOT NULL,
  engineer_name    text NOT NULL,
  region           text NOT NULL CHECK (region IN ('north','south','east','west','central')),
  oem_partner      text NOT NULL,
  recall_campaign  text NOT NULL,
  cycle_month      date NOT NULL,
  units_assigned   int  NOT NULL CHECK (units_assigned >= 0),
  units_completed  int  NOT NULL CHECK (units_completed >= 0),
  kit_ready_pct    numeric(5,2) NOT NULL CHECK (kit_ready_pct >= 0 AND kit_ready_pct <= 100),
  training_pct     numeric(5,2) NOT NULL CHECK (training_pct >= 0 AND training_pct <= 100),
  avg_turnaround_h numeric(6,2) NOT NULL CHECK (avg_turnaround_h >= 0),
  verification_pass_pct numeric(5,2) NOT NULL CHECK (verification_pass_pct >= 0 AND verification_pass_pct <= 100),
  readiness_grade  text NOT NULL CHECK (readiness_grade IN ('A','B','C','D','F')),
  blocker_note     text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_recall_readiness_r2750 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_recall_readiness_r2750;
CREATE POLICY founder_all ON engineer_recall_readiness_r2750
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_recall_readiness_r2750
  (engineer_code, engineer_name, region, oem_partner, recall_campaign, cycle_month,
   units_assigned, units_completed, kit_ready_pct, training_pct, avg_turnaround_h,
   verification_pass_pct, readiness_grade, blocker_note)
VALUES
  ('ENG-1041','Ravi Teja','south','GE Healthcare','Vivid-T8 transducer cable',
   '2026-06-01'::date, 28, 27, 96.50, 100.00, 18.40, 98.20, 'A', NULL),
  ('ENG-1052','Priya Nair','south','Philips','IntelliVue X3 battery latch',
   '2026-06-01'::date, 22, 19, 88.00, 92.50, 24.10, 91.50, 'B', 'kit shipment delayed 2d'),
  ('ENG-1063','Arjun Mehta','west','Siemens','MAGNETOM coil clip',
   '2026-06-01'::date, 16, 11, 72.00, 80.00, 33.80, 84.60, 'C', 'training module v2 pending'),
  ('ENG-1074','Sneha Iyer','north','Mindray','BeneVision N17 power module',
   '2026-06-01'::date, 31, 30, 94.00, 100.00, 19.20, 96.10, 'A', NULL),
  ('ENG-1085','Karthik Rao','central','Drager','Evita V300 valve seal',
   '2026-06-01'::date, 14,  6, 58.00, 65.00, 42.30, 70.20, 'D', 'spare parts back-order'),
  ('ENG-1096','Anita Pillai','east','BPL Medical','DefiGard battery',
   '2026-06-01'::date, 19, 18, 92.00, 95.00, 21.70, 94.40, 'B', NULL),
  ('ENG-1107','Vikram Shah','west','GE Healthcare','Carescape monitor cable',
   '2026-06-01'::date, 25, 24, 90.50, 100.00, 20.10, 95.80, 'B', NULL),
  ('ENG-1118','Meera Joshi','south','Roche Diagnostics','Cobas c311 syringe',
   '2026-06-01'::date,  9,  3, 45.00, 50.00, 51.40, 62.00, 'F', 'engineer on medical leave');

-- ---------------------------------------------------------------------
-- Table 2: recall blocker resolution actions
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS recall_blocker_actions_r2750 CASCADE;

CREATE TABLE recall_blocker_actions_r2750 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code   text NOT NULL,
  blocker_type    text NOT NULL CHECK (blocker_type IN ('kit','training','tool','access','health','documentation')),
  severity        text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  units_blocked   int  NOT NULL CHECK (units_blocked >= 0),
  reported_at     timestamptz NOT NULL,
  due_by          timestamptz NOT NULL,
  owner_team      text NOT NULL CHECK (owner_team IN ('ops','training','supply','field','founder')),
  status          text NOT NULL CHECK (status IN ('open','in_progress','resolved','escalated')),
  resolution_note text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE recall_blocker_actions_r2750 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON recall_blocker_actions_r2750;
CREATE POLICY founder_all ON recall_blocker_actions_r2750
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO recall_blocker_actions_r2750
  (engineer_code, blocker_type, severity, units_blocked, reported_at, due_by, owner_team, status, resolution_note)
VALUES
  ('ENG-1052','kit','high', 3,'2026-06-05 09:14:00+05:30','2026-06-08 18:00:00+05:30','supply','in_progress','expedited courier dispatched'),
  ('ENG-1063','training','medium', 5,'2026-06-04 11:30:00+05:30','2026-06-10 18:00:00+05:30','training','open','module v2 in QA'),
  ('ENG-1085','tool','critical', 8,'2026-06-03 08:05:00+05:30','2026-06-07 18:00:00+05:30','supply','escalated','OEM back-order, requesting alt SKU'),
  ('ENG-1118','health','high', 6,'2026-06-02 10:00:00+05:30','2026-06-14 18:00:00+05:30','ops','open','reassigning to ENG-1107 standby'),
  ('ENG-1063','access','low', 2,'2026-06-06 14:22:00+05:30','2026-06-12 18:00:00+05:30','field','resolved','hospital biomed gate-pass cleared'),
  ('ENG-1085','documentation','medium', 0,'2026-06-07 09:48:00+05:30','2026-06-11 18:00:00+05:30','ops','in_progress','recall consent letter v3 drafted'),
  ('ENG-1041','kit','low', 0,'2026-06-08 12:00:00+05:30','2026-06-13 18:00:00+05:30','supply','resolved','restock confirmed');

-- ---------------------------------------------------------------------
-- RPCs (7+, all SECURITY DEFINER, is_founder() gated)
-- ---------------------------------------------------------------------

-- 1) headline kpis
DROP FUNCTION IF EXISTS founder_r2750_kpis();
CREATE OR REPLACE FUNCTION founder_r2750_kpis()
RETURNS TABLE (
  engineers_tracked     int,
  units_assigned_total  int,
  units_completed_total int,
  completion_pct        numeric,
  open_blockers         int,
  critical_blockers     int,
  avg_verification_pct  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM engineer_recall_readiness_r2750),
    (SELECT COALESCE(SUM(units_assigned),0)::int FROM engineer_recall_readiness_r2750),
    (SELECT COALESCE(SUM(units_completed),0)::int FROM engineer_recall_readiness_r2750),
    (SELECT ROUND(100.0 * SUM(units_completed)::numeric / NULLIF(SUM(units_assigned),0), 2)
       FROM engineer_recall_readiness_r2750),
    (SELECT COUNT(*)::int FROM recall_blocker_actions_r2750 WHERE status IN ('open','in_progress','escalated')),
    (SELECT COUNT(*)::int FROM recall_blocker_actions_r2750 WHERE severity = 'critical' AND status <> 'resolved'),
    (SELECT ROUND(AVG(verification_pass_pct)::numeric, 2) FROM engineer_recall_readiness_r2750);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2750_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2750_kpis() TO authenticated;

-- 2) readiness scorecard list
DROP FUNCTION IF EXISTS founder_r2750_readiness_list();
CREATE OR REPLACE FUNCTION founder_r2750_readiness_list()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  region text,
  oem_partner text,
  recall_campaign text,
  units_assigned int,
  units_completed int,
  kit_ready_pct numeric,
  training_pct numeric,
  avg_turnaround_h numeric,
  verification_pass_pct numeric,
  readiness_grade text,
  blocker_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_code, r.engineer_name, r.region, r.oem_partner, r.recall_campaign,
         r.units_assigned, r.units_completed, r.kit_ready_pct, r.training_pct,
         r.avg_turnaround_h, r.verification_pass_pct, r.readiness_grade, r.blocker_note
    FROM engineer_recall_readiness_r2750 r
   ORDER BY r.readiness_grade ASC, r.verification_pass_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2750_readiness_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2750_readiness_list() TO authenticated;

-- 3) grade distribution
DROP FUNCTION IF EXISTS founder_r2750_grade_distribution();
CREATE OR REPLACE FUNCTION founder_r2750_grade_distribution()
RETURNS TABLE (
  readiness_grade text,
  engineers       int,
  units_assigned  int,
  units_completed int,
  completion_pct  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.readiness_grade,
         COUNT(*)::int,
         SUM(r.units_assigned)::int,
         SUM(r.units_completed)::int,
         ROUND(100.0 * SUM(r.units_completed)::numeric / NULLIF(SUM(r.units_assigned),0), 2)
    FROM engineer_recall_readiness_r2750 r
   GROUP BY r.readiness_grade
   ORDER BY r.readiness_grade ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2750_grade_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2750_grade_distribution() TO authenticated;

-- 4) blockers list
DROP FUNCTION IF EXISTS founder_r2750_blockers_list();
CREATE OR REPLACE FUNCTION founder_r2750_blockers_list()
RETURNS TABLE (
  engineer_code text,
  blocker_type  text,
  severity      text,
  units_blocked int,
  reported_at   timestamptz,
  due_by        timestamptz,
  owner_team    text,
  status        text,
  resolution_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.engineer_code, b.blocker_type, b.severity, b.units_blocked,
         b.reported_at, b.due_by, b.owner_team, b.status, b.resolution_note
    FROM recall_blocker_actions_r2750 b
   ORDER BY
     CASE b.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
     b.due_by ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2750_blockers_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2750_blockers_list() TO authenticated;

-- 5) oem partner rollup
DROP FUNCTION IF EXISTS founder_r2750_oem_rollup();
CREATE OR REPLACE FUNCTION founder_r2750_oem_rollup()
RETURNS TABLE (
  oem_partner          text,
  engineers            int,
  units_assigned       int,
  units_completed      int,
  completion_pct       numeric,
  avg_kit_ready        numeric,
  avg_verification     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.oem_partner,
         COUNT(*)::int,
         SUM(r.units_assigned)::int,
         SUM(r.units_completed)::int,
         ROUND(100.0 * SUM(r.units_completed)::numeric / NULLIF(SUM(r.units_assigned),0), 2),
         ROUND(AVG(r.kit_ready_pct)::numeric, 2),
         ROUND(AVG(r.verification_pass_pct)::numeric, 2)
    FROM engineer_recall_readiness_r2750 r
   GROUP BY r.oem_partner
   ORDER BY completion_pct ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2750_oem_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2750_oem_rollup() TO authenticated;

-- 6) region rollup
DROP FUNCTION IF EXISTS founder_r2750_region_rollup();
CREATE OR REPLACE FUNCTION founder_r2750_region_rollup()
RETURNS TABLE (
  region              text,
  engineers           int,
  units_assigned      int,
  units_completed     int,
  completion_pct      numeric,
  avg_turnaround_h    numeric,
  open_blockers       int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.region,
         COUNT(*)::int,
         SUM(r.units_assigned)::int,
         SUM(r.units_completed)::int,
         ROUND(100.0 * SUM(r.units_completed)::numeric / NULLIF(SUM(r.units_assigned),0), 2),
         ROUND(AVG(r.avg_turnaround_h)::numeric, 2),
         (SELECT COUNT(*)::int
            FROM recall_blocker_actions_r2750 b
            JOIN engineer_recall_readiness_r2750 e ON e.engineer_code = b.engineer_code
           WHERE e.region = r.region AND b.status IN ('open','in_progress','escalated'))
    FROM engineer_recall_readiness_r2750 r
   GROUP BY r.region
   ORDER BY completion_pct ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2750_region_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2750_region_rollup() TO authenticated;

-- 7) top at-risk engineers
DROP FUNCTION IF EXISTS founder_r2750_at_risk();
CREATE OR REPLACE FUNCTION founder_r2750_at_risk()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  region text,
  oem_partner text,
  units_remaining int,
  verification_pass_pct numeric,
  readiness_grade text,
  blocker_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_code, r.engineer_name, r.region, r.oem_partner,
         (r.units_assigned - r.units_completed)::int,
         r.verification_pass_pct, r.readiness_grade, r.blocker_note
    FROM engineer_recall_readiness_r2750 r
   WHERE r.readiness_grade IN ('C','D','F')
   ORDER BY (r.units_assigned - r.units_completed) DESC, r.verification_pass_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2750_at_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2750_at_risk() TO authenticated;

-- 8) turnaround band buckets
DROP FUNCTION IF EXISTS founder_r2750_turnaround_buckets();
CREATE OR REPLACE FUNCTION founder_r2750_turnaround_buckets()
RETURNS TABLE (
  bucket    text,
  engineers int,
  avg_verification numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN avg_turnaround_h < 20 THEN 'under_20h'
      WHEN avg_turnaround_h < 30 THEN '20_to_30h'
      WHEN avg_turnaround_h < 40 THEN '30_to_40h'
      ELSE 'over_40h'
    END AS bucket,
    COUNT(*)::int,
    ROUND(AVG(verification_pass_pct)::numeric, 2)
   FROM engineer_recall_readiness_r2750
  GROUP BY 1
  ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2750_turnaround_buckets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2750_turnaround_buckets() TO authenticated;

COMMIT;
