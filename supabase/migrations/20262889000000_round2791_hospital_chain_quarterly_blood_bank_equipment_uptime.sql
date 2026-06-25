BEGIN;

-- Round 2791 — Hospital Chain Quarterly Blood Bank Equipment Uptime
-- Tables: blood bank refrigerator uptime + intervention outcomes

DROP TABLE IF EXISTS blood_bank_refrigerator_uptime_r2791 CASCADE;
CREATE TABLE blood_bank_refrigerator_uptime_r2791 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  blood_bank_name text NOT NULL,
  refrigerator_tag text NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('Q1-2026','Q2-2026','Q3-2026','Q4-2026')),
  uptime_pct numeric(5,2) NOT NULL CHECK (uptime_pct >= 0 AND uptime_pct <= 100),
  downtime_minutes integer NOT NULL CHECK (downtime_minutes >= 0),
  alarm_count integer NOT NULL CHECK (alarm_count >= 0),
  temperature_excursions integer NOT NULL CHECK (temperature_excursions >= 0),
  units_at_risk integer NOT NULL CHECK (units_at_risk >= 0),
  sla_status text NOT NULL CHECK (sla_status IN ('green','amber','red')),
  measured_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE blood_bank_refrigerator_uptime_r2791 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON blood_bank_refrigerator_uptime_r2791;
CREATE POLICY founder_all ON blood_bank_refrigerator_uptime_r2791
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO blood_bank_refrigerator_uptime_r2791
  (chain_name, blood_bank_name, refrigerator_tag, quarter, uptime_pct, downtime_minutes, alarm_count, temperature_excursions, units_at_risk, sla_status, measured_on)
VALUES
  ('Apollo Hospitals', 'Apollo Jubilee Blood Bank', 'BB-REF-001', 'Q2-2026', 99.82, 78, 4, 1, 12, 'green', '2026-06-15'::date),
  ('Apollo Hospitals', 'Apollo Secunderabad', 'BB-REF-002', 'Q2-2026', 98.41, 612, 18, 5, 84, 'amber', '2026-06-15'::date),
  ('Yashoda Hospitals', 'Yashoda Somajiguda BB', 'BB-REF-003', 'Q2-2026', 99.95, 21, 1, 0, 3, 'green', '2026-06-15'::date),
  ('Care Hospitals', 'Care Banjara BB', 'BB-REF-004', 'Q2-2026', 96.12, 1410, 41, 12, 220, 'red', '2026-06-15'::date),
  ('KIMS Hospitals', 'KIMS Kondapur BB', 'BB-REF-005', 'Q2-2026', 99.20, 326, 9, 2, 28, 'amber', '2026-06-15'::date),
  ('Apollo Hospitals', 'Apollo DRDO BB', 'BB-REF-006', 'Q1-2026', 99.71, 124, 6, 1, 17, 'green', '2026-03-31'::date),
  ('Care Hospitals', 'Care Hi-Tech BB', 'BB-REF-007', 'Q2-2026', 97.55, 950, 27, 8, 142, 'red', '2026-06-15'::date);

DROP TABLE IF EXISTS bb_uptime_interventions_r2791 CASCADE;
CREATE TABLE bb_uptime_interventions_r2791 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  refrigerator_tag text NOT NULL,
  intervention_kind text NOT NULL CHECK (intervention_kind IN ('compressor_swap','sensor_recalibrate','door_gasket_replace','firmware_update','full_replacement','preventive_amc')),
  intervened_on date NOT NULL,
  cost_rupees integer NOT NULL CHECK (cost_rupees >= 0),
  outcome text NOT NULL CHECK (outcome IN ('resolved','improved','no_change','escalated')),
  uptime_delta_pct numeric(5,2) NOT NULL,
  engineer_name text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE bb_uptime_interventions_r2791 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON bb_uptime_interventions_r2791;
CREATE POLICY founder_all ON bb_uptime_interventions_r2791
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO bb_uptime_interventions_r2791
  (refrigerator_tag, intervention_kind, intervened_on, cost_rupees, outcome, uptime_delta_pct, engineer_name, notes)
VALUES
  ('BB-REF-002', 'compressor_swap', '2026-05-22'::date, 84000, 'resolved', 1.42, 'Suresh Kumar', 'Compressor coil failure; swapped with OEM part.'),
  ('BB-REF-004', 'full_replacement', '2026-06-02'::date, 425000, 'improved', 3.20, 'Naveen Reddy', 'End-of-life unit; replaced with new Haier BB-330.'),
  ('BB-REF-004', 'sensor_recalibrate', '2026-04-18'::date, 6500, 'no_change', 0.10, 'Priya Sharma', 'Sensor recalibration insufficient; needed full swap.'),
  ('BB-REF-005', 'door_gasket_replace', '2026-05-30'::date, 12000, 'resolved', 0.65, 'Ravi Teja', 'Door seal failure causing temp excursions.'),
  ('BB-REF-007', 'firmware_update', '2026-06-05'::date, 0, 'improved', 0.85, 'Anil Kumar', 'OEM firmware patch v3.2 deployed.'),
  ('BB-REF-007', 'preventive_amc', '2026-04-10'::date, 18000, 'no_change', 0.05, 'Suresh Kumar', 'AMC visit failed to detect coil degradation.'),
  ('BB-REF-001', 'preventive_amc', '2026-04-15'::date, 18000, 'resolved', 0.12, 'Priya Sharma', 'Routine AMC; all clear.');

-- RPC 1: chain-level rollup
DROP FUNCTION IF EXISTS r2791_chain_uptime_rollup();
CREATE OR REPLACE FUNCTION r2791_chain_uptime_rollup()
RETURNS TABLE(chain_name text, fridges integer, avg_uptime numeric, total_downtime_min integer, red_count integer, units_at_risk integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.chain_name,
         count(*)::integer,
         round(avg(u.uptime_pct), 2),
         sum(u.downtime_minutes)::integer,
         count(*) FILTER (WHERE u.sla_status = 'red')::integer,
         sum(u.units_at_risk)::integer
  FROM blood_bank_refrigerator_uptime_r2791 u
  WHERE u.quarter = 'Q2-2026'
  GROUP BY u.chain_name
  ORDER BY avg(u.uptime_pct) ASC;
END $$;
REVOKE EXECUTE ON FUNCTION r2791_chain_uptime_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2791_chain_uptime_rollup() TO authenticated;

-- RPC 2: red-status fridges
DROP FUNCTION IF EXISTS r2791_red_fridges();
CREATE OR REPLACE FUNCTION r2791_red_fridges()
RETURNS TABLE(chain_name text, blood_bank_name text, refrigerator_tag text, uptime_pct numeric, downtime_minutes integer, units_at_risk integer, alarm_count integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.chain_name, u.blood_bank_name, u.refrigerator_tag, u.uptime_pct, u.downtime_minutes, u.units_at_risk, u.alarm_count
  FROM blood_bank_refrigerator_uptime_r2791 u
  WHERE u.sla_status = 'red' AND u.quarter = 'Q2-2026'
  ORDER BY u.uptime_pct ASC;
END $$;
REVOKE EXECUTE ON FUNCTION r2791_red_fridges() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2791_red_fridges() TO authenticated;

-- RPC 3: intervention outcomes
DROP FUNCTION IF EXISTS r2791_intervention_outcomes();
CREATE OR REPLACE FUNCTION r2791_intervention_outcomes()
RETURNS TABLE(intervention_kind text, n integer, resolved_count integer, improved_count integer, avg_delta numeric, total_cost integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.intervention_kind,
         count(*)::integer,
         count(*) FILTER (WHERE i.outcome = 'resolved')::integer,
         count(*) FILTER (WHERE i.outcome = 'improved')::integer,
         round(avg(i.uptime_delta_pct), 2),
         sum(i.cost_rupees)::integer
  FROM bb_uptime_interventions_r2791 i
  GROUP BY i.intervention_kind
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2791_intervention_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2791_intervention_outcomes() TO authenticated;

-- RPC 4: KPI summary
DROP FUNCTION IF EXISTS r2791_kpi_summary();
CREATE OR REPLACE FUNCTION r2791_kpi_summary()
RETURNS TABLE(total_fridges integer, avg_uptime numeric, red_count integer, total_units_at_risk integer, total_intervention_cost integer, resolved_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total integer; v_resolved integer;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_total FROM bb_uptime_interventions_r2791;
  SELECT count(*) INTO v_resolved FROM bb_uptime_interventions_r2791 WHERE outcome = 'resolved';
  RETURN QUERY
  SELECT
    (SELECT count(*)::integer FROM blood_bank_refrigerator_uptime_r2791 WHERE quarter='Q2-2026'),
    (SELECT round(avg(uptime_pct), 2) FROM blood_bank_refrigerator_uptime_r2791 WHERE quarter='Q2-2026'),
    (SELECT count(*)::integer FROM blood_bank_refrigerator_uptime_r2791 WHERE sla_status='red' AND quarter='Q2-2026'),
    (SELECT sum(units_at_risk)::integer FROM blood_bank_refrigerator_uptime_r2791 WHERE quarter='Q2-2026'),
    (SELECT sum(cost_rupees)::integer FROM bb_uptime_interventions_r2791),
    CASE WHEN v_total = 0 THEN 0 ELSE round(100.0 * v_resolved / v_total, 2) END;
END $$;
REVOKE EXECUTE ON FUNCTION r2791_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2791_kpi_summary() TO authenticated;

-- RPC 5: worst fridges by downtime
DROP FUNCTION IF EXISTS r2791_worst_downtime();
CREATE OR REPLACE FUNCTION r2791_worst_downtime()
RETURNS TABLE(refrigerator_tag text, chain_name text, blood_bank_name text, downtime_minutes integer, alarm_count integer, temperature_excursions integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.refrigerator_tag, u.chain_name, u.blood_bank_name, u.downtime_minutes, u.alarm_count, u.temperature_excursions
  FROM blood_bank_refrigerator_uptime_r2791 u
  WHERE u.quarter = 'Q2-2026'
  ORDER BY u.downtime_minutes DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION r2791_worst_downtime() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2791_worst_downtime() TO authenticated;

-- RPC 6: recent interventions log
DROP FUNCTION IF EXISTS r2791_recent_interventions();
CREATE OR REPLACE FUNCTION r2791_recent_interventions()
RETURNS TABLE(refrigerator_tag text, intervention_kind text, intervened_on date, cost_rupees integer, outcome text, uptime_delta_pct numeric, engineer_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.refrigerator_tag, i.intervention_kind, i.intervened_on, i.cost_rupees, i.outcome, i.uptime_delta_pct, i.engineer_name
  FROM bb_uptime_interventions_r2791 i
  ORDER BY i.intervened_on DESC
  LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION r2791_recent_interventions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2791_recent_interventions() TO authenticated;

-- RPC 7: log a new intervention
DROP FUNCTION IF EXISTS r2791_log_intervention(text, text, integer, text, numeric, text, text);
CREATE OR REPLACE FUNCTION r2791_log_intervention(
  p_refrigerator_tag text,
  p_intervention_kind text,
  p_cost_rupees integer,
  p_outcome text,
  p_uptime_delta_pct numeric,
  p_engineer_name text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO bb_uptime_interventions_r2791
    (refrigerator_tag, intervention_kind, intervened_on, cost_rupees, outcome, uptime_delta_pct, engineer_name, notes)
  VALUES (p_refrigerator_tag, p_intervention_kind, current_date, p_cost_rupees, p_outcome, p_uptime_delta_pct, p_engineer_name, p_notes)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION r2791_log_intervention(text, text, integer, text, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2791_log_intervention(text, text, integer, text, numeric, text, text) TO authenticated;

-- RPC 8: chain SLA scorecard
DROP FUNCTION IF EXISTS r2791_chain_sla_scorecard();
CREATE OR REPLACE FUNCTION r2791_chain_sla_scorecard()
RETURNS TABLE(chain_name text, green_count integer, amber_count integer, red_count integer, sla_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.chain_name,
         count(*) FILTER (WHERE u.sla_status='green')::integer,
         count(*) FILTER (WHERE u.sla_status='amber')::integer,
         count(*) FILTER (WHERE u.sla_status='red')::integer,
         round(100.0 * count(*) FILTER (WHERE u.sla_status='green') / count(*), 2)
  FROM blood_bank_refrigerator_uptime_r2791 u
  WHERE u.quarter = 'Q2-2026'
  GROUP BY u.chain_name
  ORDER BY 5 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2791_chain_sla_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2791_chain_sla_scorecard() TO authenticated;

COMMIT;
