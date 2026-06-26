BEGIN;

-- =========================================================================
-- Round 2810 — Engineer Monthly Customer Feedback Loop Closure Rate
-- =========================================================================

-- ----- Tables ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineer_monthly_feedback_loop_r2810 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  month_start date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  region text NOT NULL,
  feedback_received_count integer NOT NULL CHECK (feedback_received_count >= 0),
  feedback_responded_count integer NOT NULL CHECK (feedback_responded_count >= 0),
  loops_closed_count integer NOT NULL CHECK (loops_closed_count >= 0),
  avg_response_hours numeric(8,2) NOT NULL CHECK (avg_response_hours >= 0),
  avg_closure_hours numeric(8,2) NOT NULL CHECK (avg_closure_hours >= 0),
  csat_score numeric(4,2) NOT NULL CHECK (csat_score >= 0 AND csat_score <= 5),
  tier_verdict text NOT NULL CHECK (tier_verdict IN ('promote','hold','watch','demote')),
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_feedback_loop_r2810 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_feedback_loop_r2810;
CREATE POLICY founder_all ON engineer_monthly_feedback_loop_r2810
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_feedback_loop_events_r2810 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loop_id uuid NOT NULL REFERENCES engineer_monthly_feedback_loop_r2810(id) ON DELETE CASCADE,
  event_at timestamptz NOT NULL,
  event_kind text NOT NULL CHECK (event_kind IN ('feedback_received','engineer_responded','loop_closed','escalated','reopened')),
  customer_label text NOT NULL,
  hours_elapsed numeric(8,2) NOT NULL CHECK (hours_elapsed >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_feedback_loop_events_r2810 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_feedback_loop_events_r2810;
CREATE POLICY founder_all ON engineer_feedback_loop_events_r2810
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ----- Seeds (8 engineers across 2 months) -------------------------------

INSERT INTO engineer_monthly_feedback_loop_r2810
  (id, month_label, month_start, engineer_code, engineer_name, engineer_tier, region,
   feedback_received_count, feedback_responded_count, loops_closed_count,
   avg_response_hours, avg_closure_hours, csat_score, tier_verdict, founder_note)
VALUES
  ('11111111-1111-1111-1111-111111111101','May 2026','2026-05-01'::date,'ENG-HYD-001','Rakesh Naidu','platinum','Hyderabad',
    28,28,27,1.80,9.50,4.82,'promote','100% response, 96% closure — anchor for South region'),
  ('11111111-1111-1111-1111-111111111102','May 2026','2026-05-01'::date,'ENG-BLR-014','Anita Sharma','gold','Bengaluru',
    22,21,18,3.20,18.40,4.55,'hold','One missed loop on ICU monitor — coach on escalation flow'),
  ('11111111-1111-1111-1111-111111111103','May 2026','2026-05-01'::date,'ENG-DEL-007','Vivek Kumar','silver','Delhi',
    19,17,12,6.80,32.10,4.10,'watch','Slow follow-up on dental chairs — assign mentor'),
  ('11111111-1111-1111-1111-111111111104','May 2026','2026-05-01'::date,'ENG-MUM-022','Priya Iyer','platinum','Mumbai',
    31,31,30,1.40,8.20,4.88,'promote','Cleanest closure metrics in the network'),
  ('11111111-1111-1111-1111-111111111105','May 2026','2026-05-01'::date,'ENG-CHN-009','Suresh Babu','bronze','Chennai',
    14,9,5,12.50,58.00,3.40,'demote','Drop to bronze probation — only 36% loop closure'),
  ('11111111-1111-1111-1111-111111111106','Jun 2026','2026-06-01'::date,'ENG-HYD-001','Rakesh Naidu','platinum','Hyderabad',
    30,30,29,1.60,8.80,4.85,'promote','Sustained excellence — fast-track to lead engineer'),
  ('11111111-1111-1111-1111-111111111107','Jun 2026','2026-06-01'::date,'ENG-BLR-014','Anita Sharma','gold','Bengaluru',
    25,25,23,2.40,14.20,4.68,'promote','Coaching worked — eligible for platinum next cycle'),
  ('11111111-1111-1111-1111-111111111108','Jun 2026','2026-06-01'::date,'ENG-CHN-009','Suresh Babu','bronze','Chennai',
    16,12,8,9.80,44.50,3.75,'watch','Recovering but still below threshold');

INSERT INTO engineer_feedback_loop_events_r2810
  (loop_id, event_at, event_kind, customer_label, hours_elapsed, notes)
VALUES
  ('11111111-1111-1111-1111-111111111101','2026-05-04 10:15+05:30','feedback_received','Apollo Hyd OT-3',0,'Probe calibration request'),
  ('11111111-1111-1111-1111-111111111101','2026-05-04 11:55+05:30','engineer_responded','Apollo Hyd OT-3',1.67,'Acknowledged within 2h'),
  ('11111111-1111-1111-1111-111111111101','2026-05-04 19:30+05:30','loop_closed','Apollo Hyd OT-3',9.25,'Customer signed off csat=5'),
  ('11111111-1111-1111-1111-111111111103','2026-05-09 09:20+05:30','feedback_received','MaxCure Delhi',0,'Dental chair hydraulic'),
  ('11111111-1111-1111-1111-111111111103','2026-05-09 17:10+05:30','engineer_responded','MaxCure Delhi',7.83,'Slow first response'),
  ('11111111-1111-1111-1111-111111111103','2026-05-11 13:00+05:30','escalated','MaxCure Delhi',51.66,'Escalated to L2'),
  ('11111111-1111-1111-1111-111111111105','2026-05-15 14:00+05:30','feedback_received','Kauvery Chennai',0,'Ventilator alarm'),
  ('11111111-1111-1111-1111-111111111105','2026-05-17 03:30+05:30','reopened','Kauvery Chennai',37.5,'Customer reopened ticket'),
  ('11111111-1111-1111-1111-111111111107','2026-06-12 08:00+05:30','feedback_received','Manipal Whitefield',0,'Anesthesia workstation'),
  ('11111111-1111-1111-1111-111111111107','2026-06-12 09:45+05:30','engineer_responded','Manipal Whitefield',1.75,'Within SLA'),
  ('11111111-1111-1111-1111-111111111107','2026-06-12 22:30+05:30','loop_closed','Manipal Whitefield',14.5,'csat=5 fast turnaround');

-- ----- RPCs --------------------------------------------------------------

DROP FUNCTION IF EXISTS r2810_kpis();
CREATE OR REPLACE FUNCTION r2810_kpis()
RETURNS TABLE (
  total_engineer_months integer,
  total_feedback_received bigint,
  total_responded bigint,
  total_loops_closed bigint,
  network_response_rate numeric,
  network_closure_rate numeric,
  avg_csat numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(feedback_received_count),0)::bigint,
    COALESCE(SUM(feedback_responded_count),0)::bigint,
    COALESCE(SUM(loops_closed_count),0)::bigint,
    ROUND(100.0 * COALESCE(SUM(feedback_responded_count),0)::numeric / NULLIF(SUM(feedback_received_count),0),2),
    ROUND(100.0 * COALESCE(SUM(loops_closed_count),0)::numeric / NULLIF(SUM(feedback_received_count),0),2),
    ROUND(AVG(csat_score)::numeric,2)
  FROM engineer_monthly_feedback_loop_r2810;
END $$;
REVOKE EXECUTE ON FUNCTION r2810_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2810_kpis() TO authenticated;

DROP FUNCTION IF EXISTS r2810_engineer_rows();
CREATE OR REPLACE FUNCTION r2810_engineer_rows()
RETURNS TABLE (
  id uuid,
  month_label text,
  engineer_code text,
  engineer_name text,
  engineer_tier text,
  region text,
  feedback_received_count integer,
  feedback_responded_count integer,
  loops_closed_count integer,
  response_rate_pct numeric,
  closure_rate_pct numeric,
  avg_response_hours numeric,
  avg_closure_hours numeric,
  csat_score numeric,
  tier_verdict text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.month_label, t.engineer_code, t.engineer_name, t.engineer_tier, t.region,
         t.feedback_received_count, t.feedback_responded_count, t.loops_closed_count,
         ROUND(100.0 * t.feedback_responded_count::numeric / NULLIF(t.feedback_received_count,0),2),
         ROUND(100.0 * t.loops_closed_count::numeric / NULLIF(t.feedback_received_count,0),2),
         t.avg_response_hours, t.avg_closure_hours, t.csat_score, t.tier_verdict
  FROM engineer_monthly_feedback_loop_r2810 t
  ORDER BY t.month_start DESC, t.csat_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2810_engineer_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2810_engineer_rows() TO authenticated;

DROP FUNCTION IF EXISTS r2810_tier_breakdown();
CREATE OR REPLACE FUNCTION r2810_tier_breakdown()
RETURNS TABLE (
  engineer_tier text,
  engineer_count bigint,
  feedback_received bigint,
  loops_closed bigint,
  closure_rate_pct numeric,
  avg_csat numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.engineer_tier,
         COUNT(*)::bigint,
         SUM(t.feedback_received_count)::bigint,
         SUM(t.loops_closed_count)::bigint,
         ROUND(100.0 * SUM(t.loops_closed_count)::numeric / NULLIF(SUM(t.feedback_received_count),0),2),
         ROUND(AVG(t.csat_score)::numeric,2)
  FROM engineer_monthly_feedback_loop_r2810 t
  GROUP BY t.engineer_tier
  ORDER BY closure_rate_pct DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION r2810_tier_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2810_tier_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2810_verdict_distribution();
CREATE OR REPLACE FUNCTION r2810_verdict_distribution()
RETURNS TABLE (
  tier_verdict text,
  engineer_count bigint,
  avg_closure_rate numeric,
  avg_csat numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.tier_verdict,
         COUNT(*)::bigint,
         ROUND(AVG(100.0 * t.loops_closed_count::numeric / NULLIF(t.feedback_received_count,0)),2),
         ROUND(AVG(t.csat_score)::numeric,2)
  FROM engineer_monthly_feedback_loop_r2810 t
  GROUP BY t.tier_verdict
  ORDER BY engineer_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2810_verdict_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2810_verdict_distribution() TO authenticated;

DROP FUNCTION IF EXISTS r2810_monthly_trend();
CREATE OR REPLACE FUNCTION r2810_monthly_trend()
RETURNS TABLE (
  month_label text,
  month_start date,
  feedback_received bigint,
  loops_closed bigint,
  closure_rate_pct numeric,
  avg_csat numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.month_label, t.month_start,
         SUM(t.feedback_received_count)::bigint,
         SUM(t.loops_closed_count)::bigint,
         ROUND(100.0 * SUM(t.loops_closed_count)::numeric / NULLIF(SUM(t.feedback_received_count),0),2),
         ROUND(AVG(t.csat_score)::numeric,2)
  FROM engineer_monthly_feedback_loop_r2810 t
  GROUP BY t.month_label, t.month_start
  ORDER BY t.month_start DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2810_monthly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2810_monthly_trend() TO authenticated;

DROP FUNCTION IF EXISTS r2810_open_loop_events();
CREATE OR REPLACE FUNCTION r2810_open_loop_events()
RETURNS TABLE (
  id uuid,
  event_at timestamptz,
  event_kind text,
  customer_label text,
  hours_elapsed numeric,
  engineer_name text,
  engineer_tier text,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_at, e.event_kind, e.customer_label, e.hours_elapsed,
         t.engineer_name, t.engineer_tier, e.notes
  FROM engineer_feedback_loop_events_r2810 e
  JOIN engineer_monthly_feedback_loop_r2810 t ON t.id = e.loop_id
  ORDER BY e.event_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION r2810_open_loop_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2810_open_loop_events() TO authenticated;

DROP FUNCTION IF EXISTS r2810_region_summary();
CREATE OR REPLACE FUNCTION r2810_region_summary()
RETURNS TABLE (
  region text,
  engineer_months bigint,
  feedback_received bigint,
  closure_rate_pct numeric,
  avg_csat numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.region,
         COUNT(*)::bigint,
         SUM(t.feedback_received_count)::bigint,
         ROUND(100.0 * SUM(t.loops_closed_count)::numeric / NULLIF(SUM(t.feedback_received_count),0),2),
         ROUND(AVG(t.csat_score)::numeric,2)
  FROM engineer_monthly_feedback_loop_r2810 t
  GROUP BY t.region
  ORDER BY closure_rate_pct DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION r2810_region_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2810_region_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2810_top_responders();
CREATE OR REPLACE FUNCTION r2810_top_responders()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  engineer_tier text,
  total_feedback bigint,
  total_closed bigint,
  best_csat numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.engineer_code, t.engineer_name, t.engineer_tier,
         SUM(t.feedback_received_count)::bigint,
         SUM(t.loops_closed_count)::bigint,
         MAX(t.csat_score)::numeric
  FROM engineer_monthly_feedback_loop_r2810 t
  GROUP BY t.engineer_code, t.engineer_name, t.engineer_tier
  ORDER BY SUM(t.loops_closed_count) DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION r2810_top_responders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2810_top_responders() TO authenticated;

COMMIT;
