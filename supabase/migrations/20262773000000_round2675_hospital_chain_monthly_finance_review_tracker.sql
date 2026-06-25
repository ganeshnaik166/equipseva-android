BEGIN;

-- ============================================================================
-- Round 2675: Hospital Chain Monthly Finance Review Tracker
-- chain x review month x ar days x dispute amount x fix action x outcome
-- ============================================================================

-- Table 1: chain monthly finance review records
DROP TABLE IF EXISTS hospital_chain_monthly_finance_reviews_r2675 CASCADE;
CREATE TABLE hospital_chain_monthly_finance_reviews_r2675 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier1','tier2','tier3')),
  review_month date NOT NULL,
  invoiced_rupees bigint NOT NULL DEFAULT 0,
  collected_rupees bigint NOT NULL DEFAULT 0,
  ar_outstanding_rupees bigint NOT NULL DEFAULT 0,
  ar_days_avg numeric(6,2) NOT NULL DEFAULT 0,
  dispute_count integer NOT NULL DEFAULT 0,
  dispute_amount_rupees bigint NOT NULL DEFAULT 0,
  health_score integer NOT NULL DEFAULT 0 CHECK (health_score BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_review','escalated','closed')),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_monthly_finance_reviews_r2675 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_monthly_finance_reviews_r2675;
CREATE POLICY founder_all ON hospital_chain_monthly_finance_reviews_r2675
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_monthly_finance_reviews_r2675
  (chain_name, chain_tier, review_month, invoiced_rupees, collected_rupees, ar_outstanding_rupees, ar_days_avg, dispute_count, dispute_amount_rupees, health_score, status, reviewed_at)
VALUES
  ('Apollo Multi-Hospital','tier1','2026-05-01', 4800000, 4320000,  480000, 28.50, 2, 180000, 82, 'closed',     now() - interval '12 days'),
  ('Yashoda Chain',       'tier1','2026-05-01', 3200000, 2560000,  640000, 41.20, 4, 290000, 64, 'escalated',  now() - interval '6 days'),
  ('Care Hospitals',      'tier2','2026-05-01', 1900000, 1710000,  190000, 22.00, 1,  55000, 88, 'closed',     now() - interval '15 days'),
  ('KIMS Network',        'tier1','2026-05-01', 2700000, 1890000,  810000, 58.75, 6, 420000, 51, 'in_review',  NULL),
  ('Continental Group',   'tier2','2026-05-01', 1450000, 1305000,  145000, 19.40, 0,      0, 91, 'closed',     now() - interval '20 days'),
  ('Sunshine Chain',      'tier3','2026-05-01',  680000,  476000,  204000, 47.10, 3, 138000, 58, 'open',       NULL);

-- Table 2: fix actions and outcomes attached to each review
DROP TABLE IF EXISTS hospital_chain_finance_fix_actions_r2675 CASCADE;
CREATE TABLE hospital_chain_finance_fix_actions_r2675 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES hospital_chain_monthly_finance_reviews_r2675(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('collection_call','dispute_resolution','credit_hold','escalate_legal','renegotiate_terms','write_off')),
  action_summary text NOT NULL,
  assigned_to text NOT NULL,
  due_date date NOT NULL,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','in_progress','recovered','partial','written_off','failed')),
  recovered_rupees bigint NOT NULL DEFAULT 0,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_finance_fix_actions_r2675 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_finance_fix_actions_r2675;
CREATE POLICY founder_all ON hospital_chain_finance_fix_actions_r2675
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_finance_fix_actions_r2675
  (review_id, action_type, action_summary, assigned_to, due_date, outcome, recovered_rupees, closed_at)
SELECT id, 'collection_call',     'Weekly call cadence for AR > 30d',           'finance_ops', current_date + 7,  'recovered', 480000, now() - interval '11 days' FROM hospital_chain_monthly_finance_reviews_r2675 WHERE chain_name = 'Apollo Multi-Hospital'
UNION ALL
SELECT id, 'dispute_resolution',  'Resolve 4 pending dispute lines',            'cs_lead',     current_date + 5,  'partial',   140000, now() - interval '5 days'  FROM hospital_chain_monthly_finance_reviews_r2675 WHERE chain_name = 'Yashoda Chain'
UNION ALL
SELECT id, 'credit_hold',         'Place credit hold on new POs until cleared', 'finance_ops', current_date + 3,  'in_progress',     0, NULL                       FROM hospital_chain_monthly_finance_reviews_r2675 WHERE chain_name = 'KIMS Network'
UNION ALL
SELECT id, 'escalate_legal',      'Send legal notice on 60+ day buckets',       'legal_team',  current_date + 14, 'pending',         0, NULL                       FROM hospital_chain_monthly_finance_reviews_r2675 WHERE chain_name = 'KIMS Network'
UNION ALL
SELECT id, 'renegotiate_terms',   'Move to advance billing on AMC renewal',     'sales_lead',  current_date + 21, 'in_progress',     0, NULL                       FROM hospital_chain_monthly_finance_reviews_r2675 WHERE chain_name = 'Sunshine Chain'
UNION ALL
SELECT id, 'write_off',           'Write off 18-month stale ar balance',        'finance_ops', current_date + 30, 'written_off', 30000, NULL                       FROM hospital_chain_monthly_finance_reviews_r2675 WHERE chain_name = 'Sunshine Chain';

-- ============================================================================
-- RPC 1: list reviews
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_finance_reviews_list_r2675();
CREATE OR REPLACE FUNCTION founder_chain_finance_reviews_list_r2675()
RETURNS TABLE(
  id uuid,
  chain_name text,
  chain_tier text,
  review_month date,
  invoiced_rupees bigint,
  collected_rupees bigint,
  ar_outstanding_rupees bigint,
  ar_days_avg numeric,
  dispute_count integer,
  dispute_amount_rupees bigint,
  health_score integer,
  status text,
  reviewed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.chain_tier, r.review_month, r.invoiced_rupees, r.collected_rupees,
         r.ar_outstanding_rupees, r.ar_days_avg, r.dispute_count, r.dispute_amount_rupees,
         r.health_score, r.status, r.reviewed_at
  FROM hospital_chain_monthly_finance_reviews_r2675 r
  ORDER BY r.health_score ASC, r.ar_outstanding_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_finance_reviews_list_r2675() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_finance_reviews_list_r2675() TO authenticated;

-- ============================================================================
-- RPC 2: KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_finance_kpis_r2675();
CREATE OR REPLACE FUNCTION founder_chain_finance_kpis_r2675()
RETURNS TABLE(
  total_chains integer,
  total_invoiced bigint,
  total_collected bigint,
  total_ar bigint,
  avg_ar_days numeric,
  total_dispute_amount bigint,
  collection_rate_pct numeric,
  escalated_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::integer,
    COALESCE(SUM(invoiced_rupees),0)::bigint,
    COALESCE(SUM(collected_rupees),0)::bigint,
    COALESCE(SUM(ar_outstanding_rupees),0)::bigint,
    COALESCE(AVG(ar_days_avg),0)::numeric,
    COALESCE(SUM(dispute_amount_rupees),0)::bigint,
    CASE WHEN COALESCE(SUM(invoiced_rupees),0) = 0 THEN 0
         ELSE ROUND((SUM(collected_rupees)::numeric / SUM(invoiced_rupees)::numeric) * 100, 2)
    END,
    SUM(CASE WHEN status = 'escalated' THEN 1 ELSE 0 END)::integer
  FROM hospital_chain_monthly_finance_reviews_r2675;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_finance_kpis_r2675() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_finance_kpis_r2675() TO authenticated;

-- ============================================================================
-- RPC 3: by tier breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_finance_by_tier_r2675();
CREATE OR REPLACE FUNCTION founder_chain_finance_by_tier_r2675()
RETURNS TABLE(
  chain_tier text,
  chain_count integer,
  ar_total bigint,
  ar_days_avg numeric,
  dispute_amount_total bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_tier,
         COUNT(*)::integer,
         COALESCE(SUM(r.ar_outstanding_rupees),0)::bigint,
         COALESCE(AVG(r.ar_days_avg),0)::numeric,
         COALESCE(SUM(r.dispute_amount_rupees),0)::bigint
  FROM hospital_chain_monthly_finance_reviews_r2675 r
  GROUP BY r.chain_tier
  ORDER BY r.chain_tier;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_finance_by_tier_r2675() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_finance_by_tier_r2675() TO authenticated;

-- ============================================================================
-- RPC 4: top-risk chains (AR > threshold or health < threshold)
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_finance_top_risk_r2675();
CREATE OR REPLACE FUNCTION founder_chain_finance_top_risk_r2675()
RETURNS TABLE(
  id uuid,
  chain_name text,
  ar_outstanding_rupees bigint,
  ar_days_avg numeric,
  health_score integer,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.ar_outstanding_rupees, r.ar_days_avg, r.health_score, r.status
  FROM hospital_chain_monthly_finance_reviews_r2675 r
  WHERE r.health_score < 70 OR r.ar_days_avg > 40
  ORDER BY r.health_score ASC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_finance_top_risk_r2675() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_finance_top_risk_r2675() TO authenticated;

-- ============================================================================
-- RPC 5: list fix actions
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_finance_actions_list_r2675();
CREATE OR REPLACE FUNCTION founder_chain_finance_actions_list_r2675()
RETURNS TABLE(
  id uuid,
  chain_name text,
  action_type text,
  action_summary text,
  assigned_to text,
  due_date date,
  outcome text,
  recovered_rupees bigint,
  closed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, r.chain_name, a.action_type, a.action_summary, a.assigned_to,
         a.due_date, a.outcome, a.recovered_rupees, a.closed_at
  FROM hospital_chain_finance_fix_actions_r2675 a
  JOIN hospital_chain_monthly_finance_reviews_r2675 r ON r.id = a.review_id
  ORDER BY a.due_date ASC, r.chain_name;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_finance_actions_list_r2675() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_finance_actions_list_r2675() TO authenticated;

-- ============================================================================
-- RPC 6: action outcomes summary
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_finance_action_outcomes_r2675();
CREATE OR REPLACE FUNCTION founder_chain_finance_action_outcomes_r2675()
RETURNS TABLE(
  outcome text,
  action_count integer,
  recovered_total bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.outcome,
         COUNT(*)::integer,
         COALESCE(SUM(a.recovered_rupees),0)::bigint
  FROM hospital_chain_finance_fix_actions_r2675 a
  GROUP BY a.outcome
  ORDER BY action_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_finance_action_outcomes_r2675() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_finance_action_outcomes_r2675() TO authenticated;

-- ============================================================================
-- RPC 7: mark review reviewed
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_finance_mark_reviewed_r2675(uuid, text);
CREATE OR REPLACE FUNCTION founder_chain_finance_mark_reviewed_r2675(p_review_id uuid, p_new_status text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status NOT IN ('open','in_review','escalated','closed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE hospital_chain_monthly_finance_reviews_r2675
     SET status = p_new_status,
         reviewed_at = CASE WHEN p_new_status = 'closed' THEN now() ELSE reviewed_at END
   WHERE id = p_review_id
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_finance_mark_reviewed_r2675(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_finance_mark_reviewed_r2675(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 8: pending actions count
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_finance_pending_actions_r2675();
CREATE OR REPLACE FUNCTION founder_chain_finance_pending_actions_r2675()
RETURNS TABLE(
  pending_count integer,
  in_progress_count integer,
  overdue_count integer,
  recovered_amount_total bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    SUM(CASE WHEN outcome = 'pending' THEN 1 ELSE 0 END)::integer,
    SUM(CASE WHEN outcome = 'in_progress' THEN 1 ELSE 0 END)::integer,
    SUM(CASE WHEN outcome IN ('pending','in_progress') AND due_date < current_date THEN 1 ELSE 0 END)::integer,
    COALESCE(SUM(recovered_rupees),0)::bigint
  FROM hospital_chain_finance_fix_actions_r2675;
END $$;
REVOKE EXECUTE ON FUNCTION founder_chain_finance_pending_actions_r2675() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_finance_pending_actions_r2675() TO authenticated;

COMMIT;
