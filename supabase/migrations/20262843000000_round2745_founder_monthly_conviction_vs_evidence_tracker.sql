BEGIN;

-- Round 2745: Founder Monthly Conviction vs Evidence Tracker
-- Topic x Conviction x Evidence x Change x Signal x Action x Calibrate

CREATE TABLE IF NOT EXISTS founder_conviction_topics_r2745 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_month date NOT NULL,
  topic_code text NOT NULL,
  topic_label text NOT NULL,
  topic_domain text NOT NULL CHECK (topic_domain IN ('market','product','ops','people','capital','tech','brand')),
  prior_conviction_score int NOT NULL CHECK (prior_conviction_score BETWEEN 0 AND 100),
  current_conviction_score int NOT NULL CHECK (current_conviction_score BETWEEN 0 AND 100),
  conviction_delta int NOT NULL,
  evidence_count int NOT NULL DEFAULT 0,
  supporting_evidence_count int NOT NULL DEFAULT 0,
  contradicting_evidence_count int NOT NULL DEFAULT 0,
  net_signal text NOT NULL CHECK (net_signal IN ('strong_support','mild_support','neutral','mild_contradict','strong_contradict')),
  recommended_action text NOT NULL CHECK (recommended_action IN ('double_down','hold','re_test','pivot','kill')),
  calibration_status text NOT NULL CHECK (calibration_status IN ('open','reviewed','locked','reopened')),
  last_calibrated_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS founder_conviction_evidence_r2745 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id uuid NOT NULL REFERENCES founder_conviction_topics_r2745(id) ON DELETE CASCADE,
  evidence_date date NOT NULL,
  evidence_kind text NOT NULL CHECK (evidence_kind IN ('metric','customer_quote','expert','data_pull','experiment','market_event')),
  evidence_polarity text NOT NULL CHECK (evidence_polarity IN ('supports','contradicts','neutral')),
  evidence_weight int NOT NULL CHECK (evidence_weight BETWEEN 1 AND 5),
  evidence_summary text NOT NULL,
  source_label text NOT NULL,
  drove_score_change int NOT NULL DEFAULT 0,
  signal_strength text NOT NULL CHECK (signal_strength IN ('weak','moderate','strong')),
  action_triggered text NOT NULL CHECK (action_triggered IN ('none','flag','review','escalate','decide')),
  reviewed_by_founder boolean NOT NULL DEFAULT false,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_conviction_topics_r2745 ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_conviction_evidence_r2745 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON founder_conviction_topics_r2745;
CREATE POLICY founder_all ON founder_conviction_topics_r2745 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON founder_conviction_evidence_r2745;
CREATE POLICY founder_all ON founder_conviction_evidence_r2745 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed topics
INSERT INTO founder_conviction_topics_r2745 (cycle_month, topic_code, topic_label, topic_domain, prior_conviction_score, current_conviction_score, conviction_delta, evidence_count, supporting_evidence_count, contradicting_evidence_count, net_signal, recommended_action, calibration_status, last_calibrated_at, notes) VALUES
('2026-06-01'::date,'tier1_hospitals','Tier-1 hospitals are core ICP','market',82,88,6,9,7,2,'strong_support','double_down','locked',now() - interval '2 days','Renewal rate 96% in cohort'),
('2026-06-01'::date,'amc_payment_first','AMC payment-first removes free-service abuse','product',70,84,14,7,6,1,'strong_support','double_down','reviewed',now() - interval '4 days','Free service attack dropped to zero'),
('2026-06-01'::date,'dental_vertical','Dental vertical worth dedicated sales','market',65,52,-13,6,2,4,'mild_contradict','re_test','open',NULL,'CAC 3x larger than radiology'),
('2026-06-01'::date,'engineer_marketplace','Engineer marketplace beats W2 hires','people',60,55,-5,5,2,3,'mild_contradict','hold','reviewed',now() - interval '7 days','Quality variance still high'),
('2026-06-01'::date,'cashfree_payouts','Cashfree exclusive payout rail','capital',75,40,-35,4,1,3,'strong_contradict','pivot','open',NULL,'KYC stuck 14 days, evaluate RazorpayX'),
('2026-06-01'::date,'investor_data_room_v2','Investor data room v2 closes rounds faster','brand',55,72,17,5,4,1,'strong_support','double_down','reviewed',now() - interval '5 days','3 of 4 LPs cited live metrics'),
('2026-06-01'::date,'ai_triage_in_app','AI triage replaces 60% of dispatcher load','tech',68,58,-10,6,3,3,'mild_contradict','re_test','open',NULL,'Hallucination on rare equipment types');

-- Seed evidence
WITH t AS (SELECT id, topic_code FROM founder_conviction_topics_r2745 WHERE cycle_month = '2026-06-01'::date)
INSERT INTO founder_conviction_evidence_r2745 (topic_id, evidence_date, evidence_kind, evidence_polarity, evidence_weight, evidence_summary, source_label, drove_score_change, signal_strength, action_triggered, reviewed_by_founder, reviewed_at)
SELECT t.id, '2026-06-12'::date,'metric','supports',5,'Tier-1 hospital renewal MRR up 18% MoM','metrics_warehouse',3,'strong','escalate',true, now() - interval '3 days' FROM t WHERE topic_code='tier1_hospitals'
UNION ALL
SELECT t.id, '2026-06-15'::date,'customer_quote','supports',4,'Apollo Hyd: "your AMC is the only one we trust"','crm_notes',2,'strong','review',true, now() - interval '1 day' FROM t WHERE topic_code='tier1_hospitals'
UNION ALL
SELECT t.id, '2026-06-09'::date,'experiment','supports',5,'Payment-first variant zero free-service abuse vs 14 prior','ab_test_log',5,'strong','decide',true, now() - interval '6 days' FROM t WHERE topic_code='amc_payment_first'
UNION ALL
SELECT t.id, '2026-06-14'::date,'metric','contradicts',4,'Dental CAC Rs 38k vs Rs 12k radiology','finance_ledger',-4,'strong','escalate',true, now() - interval '2 days' FROM t WHERE topic_code='dental_vertical'
UNION ALL
SELECT t.id, '2026-06-11'::date,'market_event','contradicts',3,'Two dental chains went captive in-house','market_intel',-3,'moderate','flag',false, NULL FROM t WHERE topic_code='dental_vertical'
UNION ALL
SELECT t.id, '2026-06-08'::date,'expert','contradicts',3,'Ex-Indegene CTO: marketplace fails on regulated repairs','advisor_call',-2,'moderate','review',true, now() - interval '4 days' FROM t WHERE topic_code='engineer_marketplace'
UNION ALL
SELECT t.id, '2026-06-13'::date,'data_pull','contradicts',5,'Cashfree KYC SLA p90 = 11 days vs 2 days RazorpayX','vendor_eval',-5,'strong','decide',true, now() - interval '1 day' FROM t WHERE topic_code='cashfree_payouts'
UNION ALL
SELECT t.id, '2026-06-16'::date,'customer_quote','supports',4,'LP Sequoia: "data room is best-in-class"','investor_crm',3,'strong','review',true, now() - interval '12 hours' FROM t WHERE topic_code='investor_data_room_v2'
UNION ALL
SELECT t.id, '2026-06-17'::date,'experiment','contradicts',4,'AI triage 38% hallucination on imaging equipment','experiment_log',-3,'strong','escalate',true, now() - interval '6 hours' FROM t WHERE topic_code='ai_triage_in_app'
UNION ALL
SELECT t.id, '2026-06-18'::date,'metric','supports',3,'AI triage cut dispatcher load 22% on routine jobs','ops_dashboard',2,'moderate','flag',false, NULL FROM t WHERE topic_code='ai_triage_in_app';

-- RPC 1: KPIs
DROP FUNCTION IF EXISTS founder_conviction_r2745_kpis();
CREATE OR REPLACE FUNCTION founder_conviction_r2745_kpis()
RETURNS TABLE(total_topics int, conviction_up int, conviction_down int, avg_current int, evidence_total int, double_down_count int, pivot_or_kill int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::int,
         COUNT(*) FILTER (WHERE conviction_delta > 0)::int,
         COUNT(*) FILTER (WHERE conviction_delta < 0)::int,
         COALESCE(AVG(current_conviction_score),0)::int,
         COALESCE(SUM(evidence_count),0)::int,
         COUNT(*) FILTER (WHERE recommended_action = 'double_down')::int,
         COUNT(*) FILTER (WHERE recommended_action IN ('pivot','kill'))::int
  FROM founder_conviction_topics_r2745;
END $$;
REVOKE EXECUTE ON FUNCTION founder_conviction_r2745_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_conviction_r2745_kpis() TO authenticated;

-- RPC 2: list topics
DROP FUNCTION IF EXISTS founder_conviction_r2745_topics();
CREATE OR REPLACE FUNCTION founder_conviction_r2745_topics()
RETURNS SETOF founder_conviction_topics_r2745
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM founder_conviction_topics_r2745 ORDER BY ABS(conviction_delta) DESC, current_conviction_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_conviction_r2745_topics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_conviction_r2745_topics() TO authenticated;

-- RPC 3: list evidence
DROP FUNCTION IF EXISTS founder_conviction_r2745_evidence();
CREATE OR REPLACE FUNCTION founder_conviction_r2745_evidence()
RETURNS TABLE(topic_label text, evidence_date date, evidence_kind text, evidence_polarity text, evidence_weight int, signal_strength text, action_triggered text, evidence_summary text, source_label text, drove_score_change int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.topic_label, e.evidence_date, e.evidence_kind, e.evidence_polarity, e.evidence_weight, e.signal_strength, e.action_triggered, e.evidence_summary, e.source_label, e.drove_score_change
  FROM founder_conviction_evidence_r2745 e
  JOIN founder_conviction_topics_r2745 t ON t.id = e.topic_id
  ORDER BY e.evidence_date DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_conviction_r2745_evidence() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_conviction_r2745_evidence() TO authenticated;

-- RPC 4: signal mix
DROP FUNCTION IF EXISTS founder_conviction_r2745_signal_mix();
CREATE OR REPLACE FUNCTION founder_conviction_r2745_signal_mix()
RETURNS TABLE(net_signal text, topic_count int, avg_delta int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT net_signal, COUNT(*)::int, COALESCE(AVG(conviction_delta),0)::int
  FROM founder_conviction_topics_r2745
  GROUP BY net_signal
  ORDER BY topic_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_conviction_r2745_signal_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_conviction_r2745_signal_mix() TO authenticated;

-- RPC 5: action queue
DROP FUNCTION IF EXISTS founder_conviction_r2745_action_queue();
CREATE OR REPLACE FUNCTION founder_conviction_r2745_action_queue()
RETURNS TABLE(topic_label text, topic_domain text, recommended_action text, current_conviction_score int, conviction_delta int, calibration_status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT topic_label, topic_domain, recommended_action, current_conviction_score, conviction_delta, calibration_status
  FROM founder_conviction_topics_r2745
  WHERE recommended_action IN ('double_down','re_test','pivot','kill')
  ORDER BY CASE recommended_action WHEN 'kill' THEN 1 WHEN 'pivot' THEN 2 WHEN 'double_down' THEN 3 WHEN 're_test' THEN 4 ELSE 5 END, ABS(conviction_delta) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_conviction_r2745_action_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_conviction_r2745_action_queue() TO authenticated;

-- RPC 6: domain rollup
DROP FUNCTION IF EXISTS founder_conviction_r2745_domain_rollup();
CREATE OR REPLACE FUNCTION founder_conviction_r2745_domain_rollup()
RETURNS TABLE(topic_domain text, topic_count int, avg_current int, avg_delta int, total_evidence int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT topic_domain, COUNT(*)::int, COALESCE(AVG(current_conviction_score),0)::int, COALESCE(AVG(conviction_delta),0)::int, COALESCE(SUM(evidence_count),0)::int
  FROM founder_conviction_topics_r2745
  GROUP BY topic_domain
  ORDER BY avg_current DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_conviction_r2745_domain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_conviction_r2745_domain_rollup() TO authenticated;

-- RPC 7: calibrate topic
DROP FUNCTION IF EXISTS founder_conviction_r2745_calibrate(uuid, text);
CREATE OR REPLACE FUNCTION founder_conviction_r2745_calibrate(p_topic_id uuid, p_status text)
RETURNS founder_conviction_topics_r2745
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE r founder_conviction_topics_r2745;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','reviewed','locked','reopened') THEN RAISE EXCEPTION 'bad_status'; END IF;
  UPDATE founder_conviction_topics_r2745
    SET calibration_status = p_status, last_calibrated_at = now()
  WHERE id = p_topic_id
  RETURNING * INTO r;
  RETURN r;
END $$;
REVOKE EXECUTE ON FUNCTION founder_conviction_r2745_calibrate(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_conviction_r2745_calibrate(uuid, text) TO authenticated;

-- RPC 8: top movers
DROP FUNCTION IF EXISTS founder_conviction_r2745_top_movers();
CREATE OR REPLACE FUNCTION founder_conviction_r2745_top_movers()
RETURNS TABLE(topic_label text, conviction_delta int, current_conviction_score int, net_signal text, recommended_action text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT topic_label, conviction_delta, current_conviction_score, net_signal, recommended_action
  FROM founder_conviction_topics_r2745
  ORDER BY ABS(conviction_delta) DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION founder_conviction_r2745_top_movers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_conviction_r2745_top_movers() TO authenticated;

COMMIT;