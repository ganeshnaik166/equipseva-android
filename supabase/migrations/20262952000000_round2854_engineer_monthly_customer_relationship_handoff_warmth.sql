BEGIN;

-- ============================================================
-- Round 2854 — Engineer × Customer Monthly Relationship Handoff Warmth
-- ============================================================

-- Table 1: monthly engineer↔customer relationship signal capture
CREATE TABLE IF NOT EXISTS engineer_customer_warmth_signals_r2854 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  customer_code text NOT NULL,
  customer_name text NOT NULL,
  prior_engineer_code text,
  prior_engineer_name text,
  city text NOT NULL,
  visits_this_month int NOT NULL CHECK (visits_this_month >= 0),
  csat_avg numeric(3,2) NOT NULL CHECK (csat_avg >= 0 AND csat_avg <= 5),
  on_time_pct numeric(5,2) NOT NULL CHECK (on_time_pct >= 0 AND on_time_pct <= 100),
  handoff_quality_score numeric(5,2) NOT NULL CHECK (handoff_quality_score >= 0 AND handoff_quality_score <= 100),
  warmth_bucket text NOT NULL CHECK (warmth_bucket IN ('cold','cool','warm','hot','glowing')),
  continuity_status text NOT NULL CHECK (continuity_status IN ('new','reassigned','retained','escalated','at_risk')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_customer_warmth_signals_r2854 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_customer_warmth_signals_r2854;
CREATE POLICY founder_all ON engineer_customer_warmth_signals_r2854
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_customer_warmth_signals_r2854
  (month_start, engineer_code, engineer_name, customer_code, customer_name, prior_engineer_code, prior_engineer_name, city, visits_this_month, csat_avg, on_time_pct, handoff_quality_score, warmth_bucket, continuity_status, notes)
VALUES
  ('2026-06-01'::date,'ENG-101','Ravi Kumar','CUST-501','Apollo Dental Banjara','ENG-088','Suresh Iyer','Hyderabad',4,4.80,96.50,92.00,'glowing','retained','customer requested Ravi by name twice'),
  ('2026-06-01'::date,'ENG-102','Anita Sharma','CUST-502','MaxCure Hospitals','ENG-101','Ravi Kumar','Hyderabad',3,4.10,84.00,71.50,'warm','reassigned','transition smooth, sent intro WhatsApp'),
  ('2026-06-01'::date,'ENG-103','Mohit Verma','CUST-503','SunRise Diagnostics',NULL,NULL,'Bengaluru',2,3.20,72.00,55.00,'cool','new','first month, learning equipment'),
  ('2026-06-01'::date,'ENG-104','Lakshmi Reddy','CUST-504','Krishna Multispeciality','ENG-099','Pradeep Naik','Vijayawada',5,4.60,93.20,88.00,'hot','retained','strong rapport, customer offered tea'),
  ('2026-06-01'::date,'ENG-105','Pavan Joshi','CUST-505','OmniCare Clinic','ENG-077','Asha Banerjee','Pune',1,2.40,55.00,38.00,'cold','at_risk','customer complained about handoff gap'),
  ('2026-06-01'::date,'ENG-106','Sneha Pillai','CUST-506','GreenLeaf Hospital','ENG-103','Mohit Verma','Bengaluru',3,4.30,87.50,74.00,'warm','reassigned','positive bridge call done'),
  ('2026-06-01'::date,'ENG-107','Arjun Mehta','CUST-507','LifeSpring Maternity','ENG-104','Lakshmi Reddy','Vijayawada',2,3.80,80.00,62.00,'cool','escalated','escalation logged for AMC renewal');

CREATE INDEX IF NOT EXISTS idx_ecws_r2854_month ON engineer_customer_warmth_signals_r2854(month_start);
CREATE INDEX IF NOT EXISTS idx_ecws_r2854_eng ON engineer_customer_warmth_signals_r2854(engineer_code);

-- Table 2: handoff event log between prior and current engineer
CREATE TABLE IF NOT EXISTS engineer_handoff_events_r2854 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  occurred_on date NOT NULL,
  customer_code text NOT NULL,
  from_engineer_code text,
  to_engineer_code text NOT NULL,
  handoff_kind text NOT NULL CHECK (handoff_kind IN ('intro_call','site_visit','doc_transfer','escalation_meeting','goodbye_call')),
  outcome text NOT NULL CHECK (outcome IN ('clean','partial','dropped','recovered','pending')),
  warmth_delta numeric(4,2) NOT NULL,
  duration_minutes int NOT NULL CHECK (duration_minutes >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handoff_events_r2854 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handoff_events_r2854;
CREATE POLICY founder_all ON engineer_handoff_events_r2854
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_handoff_events_r2854
  (occurred_on, customer_code, from_engineer_code, to_engineer_code, handoff_kind, outcome, warmth_delta, duration_minutes, notes)
VALUES
  ('2026-06-03'::date,'CUST-502','ENG-101','ENG-102','intro_call','clean',0.40,25,'three-way call with founder'),
  ('2026-06-05'::date,'CUST-503',NULL,'ENG-103','site_visit','partial',-0.20,90,'tour incomplete, missing autoclave SOP'),
  ('2026-06-07'::date,'CUST-505','ENG-077','ENG-105','doc_transfer','dropped',-0.80,15,'paperwork only, no human contact'),
  ('2026-06-09'::date,'CUST-506','ENG-103','ENG-106','escalation_meeting','recovered',0.55,60,'customer agreed to AMC renewal'),
  ('2026-06-11'::date,'CUST-507','ENG-104','ENG-107','goodbye_call','pending',0.10,20,'awaiting follow-up'),
  ('2026-06-12'::date,'CUST-501','ENG-088','ENG-101','intro_call','clean',0.65,30,'customer remembered Ravi from prior site');

CREATE INDEX IF NOT EXISTS idx_ehe_r2854_date ON engineer_handoff_events_r2854(occurred_on);
CREATE INDEX IF NOT EXISTS idx_ehe_r2854_cust ON engineer_handoff_events_r2854(customer_code);

-- ============================================================
-- RPCs (7+) — all SECURITY DEFINER, is_founder() gated
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2854_kpis();
CREATE OR REPLACE FUNCTION founder_r2854_kpis()
RETURNS TABLE(
  active_pairs int,
  glowing_pairs int,
  at_risk_pairs int,
  avg_csat numeric,
  avg_handoff_score numeric,
  clean_handoffs int,
  dropped_handoffs int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM engineer_customer_warmth_signals_r2854),
    (SELECT count(*)::int FROM engineer_customer_warmth_signals_r2854 WHERE warmth_bucket = 'glowing'),
    (SELECT count(*)::int FROM engineer_customer_warmth_signals_r2854 WHERE continuity_status = 'at_risk'),
    (SELECT round(avg(csat_avg),2) FROM engineer_customer_warmth_signals_r2854),
    (SELECT round(avg(handoff_quality_score),2) FROM engineer_customer_warmth_signals_r2854),
    (SELECT count(*)::int FROM engineer_handoff_events_r2854 WHERE outcome = 'clean'),
    (SELECT count(*)::int FROM engineer_handoff_events_r2854 WHERE outcome = 'dropped');
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2854_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2854_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2854_warmth_signals();
CREATE OR REPLACE FUNCTION founder_r2854_warmth_signals()
RETURNS SETOF engineer_customer_warmth_signals_r2854
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM engineer_customer_warmth_signals_r2854
    ORDER BY month_start DESC, handoff_quality_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2854_warmth_signals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2854_warmth_signals() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2854_handoff_events();
CREATE OR REPLACE FUNCTION founder_r2854_handoff_events()
RETURNS SETOF engineer_handoff_events_r2854
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM engineer_handoff_events_r2854
    ORDER BY occurred_on DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2854_handoff_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2854_handoff_events() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2854_by_warmth_bucket();
CREATE OR REPLACE FUNCTION founder_r2854_by_warmth_bucket()
RETURNS TABLE(
  warmth_bucket text,
  pair_count int,
  avg_csat numeric,
  avg_handoff numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.warmth_bucket,
         count(*)::int,
         round(avg(s.csat_avg),2),
         round(avg(s.handoff_quality_score),2)
  FROM engineer_customer_warmth_signals_r2854 s
  GROUP BY s.warmth_bucket
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2854_by_warmth_bucket() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2854_by_warmth_bucket() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2854_by_continuity();
CREATE OR REPLACE FUNCTION founder_r2854_by_continuity()
RETURNS TABLE(
  continuity_status text,
  pair_count int,
  avg_visits numeric,
  avg_on_time numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.continuity_status,
         count(*)::int,
         round(avg(s.visits_this_month),2),
         round(avg(s.on_time_pct),2)
  FROM engineer_customer_warmth_signals_r2854 s
  GROUP BY s.continuity_status
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2854_by_continuity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2854_by_continuity() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2854_top_engineers();
CREATE OR REPLACE FUNCTION founder_r2854_top_engineers()
RETURNS TABLE(
  engineer_code text,
  engineer_name text,
  pairs int,
  avg_csat numeric,
  avg_handoff numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code,
         max(s.engineer_name),
         count(*)::int,
         round(avg(s.csat_avg),2),
         round(avg(s.handoff_quality_score),2)
  FROM engineer_customer_warmth_signals_r2854 s
  GROUP BY s.engineer_code
  ORDER BY round(avg(s.handoff_quality_score),2) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2854_top_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2854_top_engineers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2854_at_risk_customers();
CREATE OR REPLACE FUNCTION founder_r2854_at_risk_customers()
RETURNS TABLE(
  customer_code text,
  customer_name text,
  engineer_name text,
  prior_engineer_name text,
  city text,
  csat_avg numeric,
  warmth_bucket text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.customer_code, s.customer_name, s.engineer_name, s.prior_engineer_name,
         s.city, s.csat_avg, s.warmth_bucket, s.notes
  FROM engineer_customer_warmth_signals_r2854 s
  WHERE s.continuity_status IN ('at_risk','escalated') OR s.warmth_bucket IN ('cold','cool')
  ORDER BY s.csat_avg ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2854_at_risk_customers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2854_at_risk_customers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2854_handoff_outcomes();
CREATE OR REPLACE FUNCTION founder_r2854_handoff_outcomes()
RETURNS TABLE(
  outcome text,
  event_count int,
  avg_delta numeric,
  avg_duration numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.outcome,
         count(*)::int,
         round(avg(e.warmth_delta),2),
         round(avg(e.duration_minutes),2)
  FROM engineer_handoff_events_r2854 e
  GROUP BY e.outcome
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2854_handoff_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2854_handoff_outcomes() TO authenticated;

COMMIT;
