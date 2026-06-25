BEGIN;

-- Round 2758: engineer monthly customer complaint resolution streak
-- 2 round-suffixed tables + 7 SECDEF RPCs (founder-gated)

CREATE TABLE IF NOT EXISTS engineer_complaint_resolution_streak_r2758 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  region text NOT NULL,
  month_label text NOT NULL,
  complaints_received int NOT NULL CHECK (complaints_received >= 0),
  complaints_resolved int NOT NULL CHECK (complaints_resolved >= 0),
  avg_resolve_days numeric(6,2) NOT NULL CHECK (avg_resolve_days >= 0),
  streak_months int NOT NULL CHECK (streak_months >= 0),
  bonus_rupees int NOT NULL CHECK (bonus_rupees >= 0),
  verdict text NOT NULL CHECK (verdict IN ('elite','strong','steady','watch','at_risk')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_complaint_resolution_streak_r2758 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_complaint_resolution_streak_r2758;
CREATE POLICY founder_all ON engineer_complaint_resolution_streak_r2758
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_complaint_streak_events_r2758 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  complaint_ref text NOT NULL,
  raised_on date NOT NULL,
  resolved_on date,
  resolve_days numeric(6,2),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  outcome text NOT NULL CHECK (outcome IN ('resolved','escalated','reopened','pending')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_complaint_streak_events_r2758 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_complaint_streak_events_r2758;
CREATE POLICY founder_all ON engineer_complaint_streak_events_r2758
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_complaint_resolution_streak_r2758
  (engineer_code, engineer_name, region, month_label, complaints_received, complaints_resolved, avg_resolve_days, streak_months, bonus_rupees, verdict)
VALUES
  ('ENG-HYD-014','Ravi Teja','Hyderabad','2026-06', 18, 18, 1.40, 9, 15000, 'elite'),
  ('ENG-BLR-022','Anitha Rao','Bengaluru','2026-06', 14, 13, 1.85, 6, 10000, 'strong'),
  ('ENG-MUM-031','Sandeep Joshi','Mumbai','2026-06', 11, 10, 2.30, 4,  6000, 'steady'),
  ('ENG-DEL-009','Priya Saxena','Delhi NCR','2026-06', 16, 12, 3.10, 1,  2000, 'watch'),
  ('ENG-CHN-018','Karthik N','Chennai','2026-06', 12,  7, 4.80, 0,     0, 'at_risk'),
  ('ENG-PUN-005','Meera Kulkarni','Pune','2026-06',  9,  9, 1.20, 7, 12000, 'elite');

INSERT INTO engineer_complaint_streak_events_r2758
  (engineer_code, complaint_ref, raised_on, resolved_on, resolve_days, severity, outcome, notes)
VALUES
  ('ENG-HYD-014','CMP-91201','2026-06-02'::date,'2026-06-03'::date, 1.0, 'medium','resolved','centrifuge calibration'),
  ('ENG-BLR-022','CMP-91245','2026-06-04'::date,'2026-06-06'::date, 2.0, 'high','resolved','autoclave seal'),
  ('ENG-MUM-031','CMP-91278','2026-06-07'::date,'2026-06-10'::date, 3.0, 'medium','resolved','ECG lead replace'),
  ('ENG-DEL-009','CMP-91290','2026-06-08'::date, NULL, NULL,'critical','escalated','infusion pump RCA pending'),
  ('ENG-CHN-018','CMP-91312','2026-06-09'::date,'2026-06-15'::date, 6.0,'high','reopened','ventilator alarm recurring'),
  ('ENG-PUN-005','CMP-91333','2026-06-11'::date,'2026-06-12'::date, 1.0,'low','resolved','dental chair lamp');

-- RPC 1: streak overview
DROP FUNCTION IF EXISTS founder_r2758_overview();
CREATE OR REPLACE FUNCTION founder_r2758_overview()
RETURNS TABLE(total_engineers int, elite_count int, at_risk_count int, total_bonus_rupees bigint, avg_streak numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::int,
           COUNT(*) FILTER (WHERE verdict='elite')::int,
           COUNT(*) FILTER (WHERE verdict='at_risk')::int,
           COALESCE(SUM(bonus_rupees),0)::bigint,
           COALESCE(ROUND(AVG(streak_months)::numeric,2),0)
    FROM engineer_complaint_resolution_streak_r2758;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2758_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2758_overview() TO authenticated;

-- RPC 2: leaderboard
DROP FUNCTION IF EXISTS founder_r2758_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2758_leaderboard()
RETURNS TABLE(engineer_code text, engineer_name text, region text, streak_months int, bonus_rupees int, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.engineer_code, s.engineer_name, s.region, s.streak_months, s.bonus_rupees, s.verdict
    FROM engineer_complaint_resolution_streak_r2758 s
    ORDER BY s.streak_months DESC, s.bonus_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2758_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2758_leaderboard() TO authenticated;

-- RPC 3: at-risk engineers
DROP FUNCTION IF EXISTS founder_r2758_at_risk();
CREATE OR REPLACE FUNCTION founder_r2758_at_risk()
RETURNS TABLE(engineer_code text, engineer_name text, region text, complaints_received int, complaints_resolved int, avg_resolve_days numeric, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.engineer_code, s.engineer_name, s.region, s.complaints_received, s.complaints_resolved, s.avg_resolve_days, s.verdict
    FROM engineer_complaint_resolution_streak_r2758 s
    WHERE s.verdict IN ('watch','at_risk')
    ORDER BY s.avg_resolve_days DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2758_at_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2758_at_risk() TO authenticated;

-- RPC 4: events feed
DROP FUNCTION IF EXISTS founder_r2758_events();
CREATE OR REPLACE FUNCTION founder_r2758_events()
RETURNS TABLE(engineer_code text, complaint_ref text, raised_on date, resolved_on date, resolve_days numeric, severity text, outcome text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.engineer_code, e.complaint_ref, e.raised_on, e.resolved_on, e.resolve_days, e.severity, e.outcome, e.notes
    FROM engineer_complaint_streak_events_r2758 e
    ORDER BY e.raised_on DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2758_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2758_events() TO authenticated;

-- RPC 5: region rollup
DROP FUNCTION IF EXISTS founder_r2758_region_rollup();
CREATE OR REPLACE FUNCTION founder_r2758_region_rollup()
RETURNS TABLE(region text, engineers int, avg_streak numeric, total_bonus bigint, elite_share numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.region,
           COUNT(*)::int,
           ROUND(AVG(s.streak_months)::numeric,2),
           SUM(s.bonus_rupees)::bigint,
           ROUND((COUNT(*) FILTER (WHERE s.verdict='elite')::numeric / NULLIF(COUNT(*),0)) * 100, 2)
    FROM engineer_complaint_resolution_streak_r2758 s
    GROUP BY s.region
    ORDER BY total_bonus DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2758_region_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2758_region_rollup() TO authenticated;

-- RPC 6: severity mix
DROP FUNCTION IF EXISTS founder_r2758_severity_mix();
CREATE OR REPLACE FUNCTION founder_r2758_severity_mix()
RETURNS TABLE(severity text, total int, resolved int, escalated int, reopened int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.severity,
           COUNT(*)::int,
           COUNT(*) FILTER (WHERE e.outcome='resolved')::int,
           COUNT(*) FILTER (WHERE e.outcome='escalated')::int,
           COUNT(*) FILTER (WHERE e.outcome='reopened')::int
    FROM engineer_complaint_streak_events_r2758 e
    GROUP BY e.severity
    ORDER BY total DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2758_severity_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2758_severity_mix() TO authenticated;

-- RPC 7: bonus payout queue
DROP FUNCTION IF EXISTS founder_r2758_bonus_queue();
CREATE OR REPLACE FUNCTION founder_r2758_bonus_queue()
RETURNS TABLE(engineer_code text, engineer_name text, streak_months int, bonus_rupees int, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.engineer_code, s.engineer_name, s.streak_months, s.bonus_rupees, s.verdict
    FROM engineer_complaint_resolution_streak_r2758 s
    WHERE s.bonus_rupees > 0
    ORDER BY s.bonus_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2758_bonus_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2758_bonus_queue() TO authenticated;

-- RPC 8: full streak table
DROP FUNCTION IF EXISTS founder_r2758_streak_table();
CREATE OR REPLACE FUNCTION founder_r2758_streak_table()
RETURNS TABLE(engineer_code text, engineer_name text, region text, month_label text, complaints_received int, complaints_resolved int, avg_resolve_days numeric, streak_months int, bonus_rupees int, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.engineer_code, s.engineer_name, s.region, s.month_label, s.complaints_received, s.complaints_resolved, s.avg_resolve_days, s.streak_months, s.bonus_rupees, s.verdict
    FROM engineer_complaint_resolution_streak_r2758 s
    ORDER BY s.streak_months DESC, s.engineer_name;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2758_streak_table() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2758_streak_table() TO authenticated;

COMMIT;
