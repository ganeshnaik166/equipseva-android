BEGIN;

-- ============================================================
-- Round 2681: Founder Quarterly Product Bet Evaluation
-- bet × hypothesis × cost × actual outcome × learning × continue/kill
-- ============================================================

-- ---- Table 1: product bets ----
DROP TABLE IF EXISTS product_bets_r2681 CASCADE;
CREATE TABLE product_bets_r2681 (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter       text NOT NULL,
  bet_name      text NOT NULL,
  hypothesis    text NOT NULL,
  success_metric text NOT NULL,
  target_value  numeric NOT NULL,
  actual_value  numeric,
  cost_rupees   numeric NOT NULL,
  bet_tier      text NOT NULL CHECK (bet_tier IN ('small','medium','large','moonshot')),
  status        text NOT NULL CHECK (status IN ('running','succeeded','failed','partial')),
  owner         text NOT NULL,
  started_at    timestamptz NOT NULL DEFAULT now(),
  evaluated_at  timestamptz
);

ALTER TABLE product_bets_r2681 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON product_bets_r2681;
CREATE POLICY founder_all ON product_bets_r2681 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO product_bets_r2681 (quarter, bet_name, hypothesis, success_metric, target_value, actual_value, cost_rupees, bet_tier, status, owner, evaluated_at) VALUES
('Q2-2026','Hospital chain bulk onboarding','Chains will sign 5+ hospitals at once if discount tier shown','signed_hospitals',25,32,450000,'large','succeeded','founder', now() - interval '5 days'),
('Q2-2026','AI symptom triage','Engineers waste 40% time on misclassified jobs; AI cuts to 10%','triage_accuracy_pct',90,72,820000,'large','partial','engineering', now() - interval '3 days'),
('Q2-2026','Tier-1 city home repair','Home-repair LTV beats clinic LTV in metros','ltv_rupees',18000,9500,310000,'medium','failed','growth', now() - interval '7 days'),
('Q2-2026','Engineer certification ladder','Certified engineers retain 2x longer','retention_pct_12mo',75,84,180000,'small','succeeded','ops', now() - interval '10 days'),
('Q3-2026','Cashfree-at-scale','Auto-payouts daily kills reconciliation burden','manual_recon_hours_week',2,NULL,95000,'small','running','founder', NULL),
('Q3-2026','Sri Lanka pilot','International expansion viable at 3x ARPU','signed_clinics_lk',10,NULL,650000,'moonshot','running','founder', NULL),
('Q1-2026','GST invoice auto-file','Hospitals stay if GST filing automated','churn_pct_quarterly',8,6.2,220000,'medium','succeeded','finance', now() - interval '40 days');

-- ---- Table 2: bet learnings ----
DROP TABLE IF EXISTS bet_learnings_r2681 CASCADE;
CREATE TABLE bet_learnings_r2681 (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_id        uuid NOT NULL REFERENCES product_bets_r2681(id) ON DELETE CASCADE,
  learning_text text NOT NULL,
  decision      text NOT NULL CHECK (decision IN ('continue','double_down','kill','pivot','park')),
  rationale     text NOT NULL,
  confidence_pct numeric NOT NULL CHECK (confidence_pct BETWEEN 0 AND 100),
  recorded_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE bet_learnings_r2681 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON bet_learnings_r2681;
CREATE POLICY founder_all ON bet_learnings_r2681 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO bet_learnings_r2681 (bet_id, learning_text, decision, rationale, confidence_pct) VALUES
((SELECT id FROM product_bets_r2681 WHERE bet_name='Hospital chain bulk onboarding'),'Chains buy when shown ROI calc per hospital not flat discount','double_down','Hit 128% of target; pipeline 3x next quarter',92),
((SELECT id FROM product_bets_r2681 WHERE bet_name='AI symptom triage'),'Model needs domain fine-tune; pretrained too generic','pivot','72% accuracy below threshold; retrain on 6mo job data',65),
((SELECT id FROM product_bets_r2681 WHERE bet_name='Tier-1 city home repair'),'Home customers low repeat rate vs clinics 4x/yr','kill','LTV half of target; CAC too high; better channels exist',88),
((SELECT id FROM product_bets_r2681 WHERE bet_name='Engineer certification ladder'),'Certified engineers refer 2.3x more peers organically','double_down','Retention 84% beat 75% target; viral loop discovered',95),
((SELECT id FROM product_bets_r2681 WHERE bet_name='GST invoice auto-file'),'Churn dropped from 11% to 6.2% post-launch','continue','Compounding effect quarter-over-quarter',90),
((SELECT id FROM product_bets_r2681 WHERE bet_name='Cashfree-at-scale'),'Early signal positive: 5h saved in week 1','continue','Too early to call; monitor 2 more months',70),
((SELECT id FROM product_bets_r2681 WHERE bet_name='Sri Lanka pilot'),'Regulatory clarity better than expected; partner identified','continue','3 LOIs signed week 2; need full quarter signal',60);

-- ============================================================
-- RPCs (7+)
-- ============================================================

-- RPC 1: list all bets with computed metrics
DROP FUNCTION IF EXISTS founder_list_product_bets_r2681();
CREATE FUNCTION founder_list_product_bets_r2681()
RETURNS TABLE (
  id uuid, quarter text, bet_name text, hypothesis text, success_metric text,
  target_value numeric, actual_value numeric, attainment_pct numeric,
  cost_rupees numeric, bet_tier text, status text, owner text,
  started_at timestamptz, evaluated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.quarter, b.bet_name, b.hypothesis, b.success_metric,
    b.target_value, b.actual_value,
    CASE WHEN b.actual_value IS NULL OR b.target_value=0 THEN NULL
         ELSE round(100.0 * b.actual_value / NULLIF(b.target_value,0), 1) END,
    b.cost_rupees, b.bet_tier, b.status, b.owner, b.started_at, b.evaluated_at
  FROM product_bets_r2681 b
  ORDER BY b.started_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_list_product_bets_r2681() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_list_product_bets_r2681() TO authenticated;

-- RPC 2: bet summary kpis
DROP FUNCTION IF EXISTS founder_bet_summary_r2681();
CREATE FUNCTION founder_bet_summary_r2681()
RETURNS TABLE (
  total_bets bigint, running_bets bigint, succeeded_bets bigint,
  failed_bets bigint, partial_bets bigint,
  total_cost_rupees numeric, win_rate_pct numeric, avg_attainment_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE status='running')::bigint,
    count(*) FILTER (WHERE status='succeeded')::bigint,
    count(*) FILTER (WHERE status='failed')::bigint,
    count(*) FILTER (WHERE status='partial')::bigint,
    coalesce(sum(cost_rupees),0),
    CASE WHEN count(*) FILTER (WHERE status IN ('succeeded','failed','partial')) = 0 THEN 0
         ELSE round(100.0 * count(*) FILTER (WHERE status='succeeded')
              / count(*) FILTER (WHERE status IN ('succeeded','failed','partial')), 1) END,
    round(avg(CASE WHEN target_value=0 OR actual_value IS NULL THEN NULL
                   ELSE 100.0 * actual_value / target_value END), 1)
  FROM product_bets_r2681;
END $$;
REVOKE EXECUTE ON FUNCTION founder_bet_summary_r2681() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bet_summary_r2681() TO authenticated;

-- RPC 3: by tier
DROP FUNCTION IF EXISTS founder_bets_by_tier_r2681();
CREATE FUNCTION founder_bets_by_tier_r2681()
RETURNS TABLE (bet_tier text, bet_count bigint, total_cost numeric, win_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.bet_tier, count(*)::bigint, sum(b.cost_rupees),
         count(*) FILTER (WHERE b.status='succeeded')::bigint
  FROM product_bets_r2681 b
  GROUP BY b.bet_tier
  ORDER BY sum(b.cost_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_bets_by_tier_r2681() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bets_by_tier_r2681() TO authenticated;

-- RPC 4: by quarter
DROP FUNCTION IF EXISTS founder_bets_by_quarter_r2681();
CREATE FUNCTION founder_bets_by_quarter_r2681()
RETURNS TABLE (quarter text, bet_count bigint, total_cost numeric, succeeded bigint, failed bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.quarter, count(*)::bigint, sum(b.cost_rupees),
         count(*) FILTER (WHERE b.status='succeeded')::bigint,
         count(*) FILTER (WHERE b.status='failed')::bigint
  FROM product_bets_r2681 b
  GROUP BY b.quarter
  ORDER BY b.quarter DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_bets_by_quarter_r2681() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bets_by_quarter_r2681() TO authenticated;

-- RPC 5: learnings list
DROP FUNCTION IF EXISTS founder_list_learnings_r2681();
CREATE FUNCTION founder_list_learnings_r2681()
RETURNS TABLE (
  id uuid, bet_name text, learning_text text, decision text,
  rationale text, confidence_pct numeric, recorded_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, b.bet_name, l.learning_text, l.decision, l.rationale, l.confidence_pct, l.recorded_at
  FROM bet_learnings_r2681 l
  JOIN product_bets_r2681 b ON b.id = l.bet_id
  ORDER BY l.recorded_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_list_learnings_r2681() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_list_learnings_r2681() TO authenticated;

-- RPC 6: kill candidates
DROP FUNCTION IF EXISTS founder_kill_candidates_r2681();
CREATE FUNCTION founder_kill_candidates_r2681()
RETURNS TABLE (bet_name text, attainment_pct numeric, cost_rupees numeric, decision text, rationale text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.bet_name,
    round(100.0 * b.actual_value / NULLIF(b.target_value,0), 1),
    b.cost_rupees, l.decision, l.rationale
  FROM product_bets_r2681 b
  JOIN bet_learnings_r2681 l ON l.bet_id = b.id
  WHERE l.decision IN ('kill','pivot')
  ORDER BY b.cost_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_kill_candidates_r2681() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_kill_candidates_r2681() TO authenticated;

-- RPC 7: double-down winners
DROP FUNCTION IF EXISTS founder_double_down_winners_r2681();
CREATE FUNCTION founder_double_down_winners_r2681()
RETURNS TABLE (bet_name text, attainment_pct numeric, cost_rupees numeric, learning_text text, confidence_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.bet_name,
    round(100.0 * b.actual_value / NULLIF(b.target_value,0), 1),
    b.cost_rupees, l.learning_text, l.confidence_pct
  FROM product_bets_r2681 b
  JOIN bet_learnings_r2681 l ON l.bet_id = b.id
  WHERE l.decision = 'double_down'
  ORDER BY l.confidence_pct DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_double_down_winners_r2681() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_double_down_winners_r2681() TO authenticated;

-- RPC 8: capital efficiency by owner
DROP FUNCTION IF EXISTS founder_capital_efficiency_r2681();
CREATE FUNCTION founder_capital_efficiency_r2681()
RETURNS TABLE (owner text, total_cost numeric, win_count bigint, avg_attainment numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.owner, sum(b.cost_rupees),
         count(*) FILTER (WHERE b.status='succeeded')::bigint,
         round(avg(CASE WHEN b.target_value=0 OR b.actual_value IS NULL THEN NULL
                        ELSE 100.0 * b.actual_value / b.target_value END), 1)
  FROM product_bets_r2681 b
  GROUP BY b.owner
  ORDER BY sum(b.cost_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_capital_efficiency_r2681() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_efficiency_r2681() TO authenticated;

COMMIT;
