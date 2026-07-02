BEGIN;

-- Round 2765: Founder Quarterly Deep Work Time Audit
-- block × topic × minutes × interruption × output × calibrate decision

CREATE TABLE IF NOT EXISTS founder_deep_work_blocks_r2765 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_date date NOT NULL,
  block_label text NOT NULL,
  topic text NOT NULL,
  category text NOT NULL CHECK (category IN ('strategy','build','hiring','sales','ops','learning')),
  planned_minutes int NOT NULL CHECK (planned_minutes BETWEEN 15 AND 480),
  actual_minutes int NOT NULL CHECK (actual_minutes BETWEEN 0 AND 600),
  interruption_count int NOT NULL DEFAULT 0 CHECK (interruption_count BETWEEN 0 AND 50),
  flow_state_score int NOT NULL CHECK (flow_state_score BETWEEN 1 AND 10),
  output_artifact text NOT NULL,
  output_quality int NOT NULL CHECK (output_quality BETWEEN 1 AND 10),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_deep_work_blocks_r2765 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_deep_work_blocks_r2765;
CREATE POLICY founder_all ON founder_deep_work_blocks_r2765 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_deep_work_calibrations_r2765 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  calibration_date date NOT NULL,
  topic text NOT NULL,
  prior_avg_minutes int NOT NULL CHECK (prior_avg_minutes BETWEEN 0 AND 1000),
  observed_avg_minutes int NOT NULL CHECK (observed_avg_minutes BETWEEN 0 AND 1000),
  variance_pct numeric(6,2) NOT NULL,
  decision text NOT NULL CHECK (decision IN ('keep','double_down','reduce','kill','batch','delegate')),
  rationale text NOT NULL,
  next_target_minutes int NOT NULL CHECK (next_target_minutes BETWEEN 0 AND 600),
  reviewed_by text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_deep_work_calibrations_r2765 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_deep_work_calibrations_r2765;
CREATE POLICY founder_all ON founder_deep_work_calibrations_r2765 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed: deep work blocks
INSERT INTO founder_deep_work_blocks_r2765 (block_date, block_label, topic, category, planned_minutes, actual_minutes, interruption_count, flow_state_score, output_artifact, output_quality, notes) VALUES
('2026-06-23'::date, 'Mon AM-1', 'v0.6 roadmap synthesis', 'strategy', 120, 135, 2, 9, 'roadmap_v06.md draft', 9, 'flow held 2hr+'),
('2026-06-23'::date, 'Mon PM-1', 'AMC churn cohort review', 'ops', 90, 60, 5, 5, 'churn_cohort.csv', 6, 'slack pings broke focus'),
('2026-06-24'::date, 'Tue AM-1', 'engineer tier-3 rubric', 'hiring', 120, 110, 1, 8, 'tier3_rubric.md', 8, 'one cal nudge'),
('2026-06-24'::date, 'Tue PM-2', 'Cashfree payouts hardening', 'build', 180, 200, 3, 7, 'PR #1873 design', 8, 'over by 20m, worth it'),
('2026-06-25'::date, 'Wed AM-1', 'investor data room outline', 'sales', 90, 95, 0, 10, 'data_room_v1.md', 9, 'zero interruption block'),
('2026-06-25'::date, 'Wed AM-2', 'GST filing automation review', 'ops', 60, 75, 4, 4, 'gst_filing_notes', 5, 'too many context switches'),
('2026-06-25'::date, 'Wed PM-1', 'Compose recomposition deep-dive', 'learning', 120, 130, 1, 9, 'compose_notes.md', 9, 'paying off in r2700+');

-- Seed: calibrations
INSERT INTO founder_deep_work_calibrations_r2765 (calibration_date, topic, prior_avg_minutes, observed_avg_minutes, variance_pct, decision, rationale, next_target_minutes, reviewed_by) VALUES
('2026-06-25'::date, 'AMC churn cohort review', 90, 60, -33.33, 'delegate', 'ops manager can run weekly cut; founder only on quarterly review', 30, 'ganesh'),
('2026-06-25'::date, 'v0.6 roadmap synthesis', 120, 135, 12.50, 'keep', 'flow score 9 + clear artifact; protect this block', 120, 'ganesh'),
('2026-06-25'::date, 'engineer tier-3 rubric', 120, 110, -8.33, 'double_down', 'hiring velocity = ship speed; expand block', 150, 'ganesh'),
('2026-06-25'::date, 'GST filing automation review', 60, 75, 25.00, 'kill', 'CA can own this end-to-end after r2700 ship', 0, 'ganesh'),
('2026-06-25'::date, 'Cashfree payouts hardening', 180, 200, 11.11, 'batch', 'merge with payments review on Fridays', 240, 'ganesh'),
('2026-06-25'::date, 'investor data room outline', 90, 95, 5.56, 'double_down', 'fundraise window opens Q4; ramp to 2x', 180, 'ganesh');

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_dw_kpi_r2765();
CREATE OR REPLACE FUNCTION founder_dw_kpi_r2765()
RETURNS TABLE(
  total_blocks bigint,
  total_planned_min bigint,
  total_actual_min bigint,
  avg_flow numeric,
  avg_quality numeric,
  total_interruptions bigint,
  pct_variance numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(planned_minutes),0)::bigint,
    COALESCE(SUM(actual_minutes),0)::bigint,
    ROUND(AVG(flow_state_score)::numeric, 2),
    ROUND(AVG(output_quality)::numeric, 2),
    COALESCE(SUM(interruption_count),0)::bigint,
    ROUND((COALESCE(SUM(actual_minutes),0) - COALESCE(SUM(planned_minutes),0))::numeric
      / NULLIF(SUM(planned_minutes),0) * 100, 2)
  FROM founder_deep_work_blocks_r2765;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_dw_kpi_r2765() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dw_kpi_r2765() TO authenticated;

-- RPC 2: blocks by category
DROP FUNCTION IF EXISTS founder_dw_by_category_r2765();
CREATE OR REPLACE FUNCTION founder_dw_by_category_r2765()
RETURNS TABLE(category text, blocks bigint, total_minutes bigint, avg_flow numeric, avg_quality numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.category, COUNT(*)::bigint, COALESCE(SUM(b.actual_minutes),0)::bigint,
         ROUND(AVG(b.flow_state_score)::numeric,2), ROUND(AVG(b.output_quality)::numeric,2)
  FROM founder_deep_work_blocks_r2765 b
  GROUP BY b.category
  ORDER BY total_minutes DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_dw_by_category_r2765() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dw_by_category_r2765() TO authenticated;

-- RPC 3: recent blocks
DROP FUNCTION IF EXISTS founder_dw_recent_blocks_r2765();
CREATE OR REPLACE FUNCTION founder_dw_recent_blocks_r2765()
RETURNS TABLE(
  block_date date, block_label text, topic text, category text,
  planned_minutes int, actual_minutes int, interruption_count int,
  flow_state_score int, output_quality int, output_artifact text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.block_date, b.block_label, b.topic, b.category,
         b.planned_minutes, b.actual_minutes, b.interruption_count,
         b.flow_state_score, b.output_quality, b.output_artifact
  FROM founder_deep_work_blocks_r2765 b
  ORDER BY b.block_date DESC, b.block_label ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_dw_recent_blocks_r2765() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dw_recent_blocks_r2765() TO authenticated;

-- RPC 4: calibrations list
DROP FUNCTION IF EXISTS founder_dw_calibrations_r2765();
CREATE OR REPLACE FUNCTION founder_dw_calibrations_r2765()
RETURNS TABLE(
  calibration_date date, topic text, prior_avg_minutes int, observed_avg_minutes int,
  variance_pct numeric, decision text, rationale text, next_target_minutes int, reviewed_by text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.calibration_date, c.topic, c.prior_avg_minutes, c.observed_avg_minutes,
         c.variance_pct, c.decision, c.rationale, c.next_target_minutes, c.reviewed_by
  FROM founder_deep_work_calibrations_r2765 c
  ORDER BY c.calibration_date DESC, c.topic ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_dw_calibrations_r2765() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dw_calibrations_r2765() TO authenticated;

-- RPC 5: decision breakdown
DROP FUNCTION IF EXISTS founder_dw_decision_breakdown_r2765();
CREATE OR REPLACE FUNCTION founder_dw_decision_breakdown_r2765()
RETURNS TABLE(decision text, topics bigint, total_next_minutes bigint, avg_variance_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.decision, COUNT(*)::bigint,
         COALESCE(SUM(c.next_target_minutes),0)::bigint,
         ROUND(AVG(c.variance_pct)::numeric, 2)
  FROM founder_deep_work_calibrations_r2765 c
  GROUP BY c.decision
  ORDER BY topics DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_dw_decision_breakdown_r2765() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dw_decision_breakdown_r2765() TO authenticated;

-- RPC 6: top flow blocks
DROP FUNCTION IF EXISTS founder_dw_top_flow_r2765();
CREATE OR REPLACE FUNCTION founder_dw_top_flow_r2765()
RETURNS TABLE(topic text, block_date date, flow_state_score int, output_quality int, actual_minutes int, interruption_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.topic, b.block_date, b.flow_state_score, b.output_quality, b.actual_minutes, b.interruption_count
  FROM founder_deep_work_blocks_r2765 b
  ORDER BY b.flow_state_score DESC, b.output_quality DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_dw_top_flow_r2765() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dw_top_flow_r2765() TO authenticated;

-- RPC 7: log new block
DROP FUNCTION IF EXISTS founder_dw_log_block_r2765(date, text, text, text, int, int, int, int, text, int, text);
CREATE OR REPLACE FUNCTION founder_dw_log_block_r2765(
  p_date date, p_label text, p_topic text, p_category text,
  p_planned int, p_actual int, p_interruptions int, p_flow int,
  p_artifact text, p_quality int, p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_deep_work_blocks_r2765(block_date, block_label, topic, category, planned_minutes, actual_minutes, interruption_count, flow_state_score, output_artifact, output_quality, notes)
  VALUES (p_date, p_label, p_topic, p_category, p_planned, p_actual, p_interruptions, p_flow, p_artifact, p_quality, p_notes)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_dw_log_block_r2765(date, text, text, text, int, int, int, int, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dw_log_block_r2765(date, text, text, text, int, int, int, int, text, int, text) TO authenticated;

-- RPC 8: interruption hotspots
DROP FUNCTION IF EXISTS founder_dw_interruption_hotspots_r2765();
CREATE OR REPLACE FUNCTION founder_dw_interruption_hotspots_r2765()
RETURNS TABLE(topic text, total_interruptions bigint, avg_flow numeric, avg_quality numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.topic, COALESCE(SUM(b.interruption_count),0)::bigint,
         ROUND(AVG(b.flow_state_score)::numeric,2), ROUND(AVG(b.output_quality)::numeric,2)
  FROM founder_deep_work_blocks_r2765 b
  GROUP BY b.topic
  HAVING SUM(b.interruption_count) > 0
  ORDER BY total_interruptions DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_dw_interruption_hotspots_r2765() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dw_interruption_hotspots_r2765() TO authenticated;

COMMIT;
