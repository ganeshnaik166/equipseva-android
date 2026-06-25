BEGIN;

-- ============================================================================
-- Round r2696 — Customer Quarterly Budget Cycle Tracker
-- HEAVY ★★★★ — customer × budget cycle × allocation × spend × variance × refill
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: customer_quarterly_budget_cycles_r2696
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_quarterly_budget_cycles_r2696 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_name text NOT NULL,
  customer_tier text NOT NULL CHECK (customer_tier IN ('platinum','gold','silver','bronze')),
  fiscal_quarter text NOT NULL CHECK (fiscal_quarter IN ('FY26Q1','FY26Q2','FY26Q3','FY26Q4','FY27Q1')),
  cycle_start_date date NOT NULL,
  cycle_end_date date NOT NULL,
  allocated_budget_rupees numeric(14,2) NOT NULL CHECK (allocated_budget_rupees >= 0),
  spent_to_date_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (spent_to_date_rupees >= 0),
  committed_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (committed_rupees >= 0),
  variance_rupees numeric(14,2) NOT NULL DEFAULT 0,
  variance_pct numeric(6,2) NOT NULL DEFAULT 0,
  burn_rate_per_day_rupees numeric(12,2) NOT NULL DEFAULT 0,
  projected_overrun_rupees numeric(14,2) NOT NULL DEFAULT 0,
  cycle_status text NOT NULL CHECK (cycle_status IN ('on_track','watch','over_budget','exhausted','refilled')),
  refill_requested boolean NOT NULL DEFAULT false,
  refill_amount_rupees numeric(14,2) NOT NULL DEFAULT 0,
  last_spend_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_quarterly_budget_cycles_r2696 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_quarterly_budget_cycles_r2696;
CREATE POLICY founder_all ON customer_quarterly_budget_cycles_r2696
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_quarterly_budget_cycles_r2696
  (customer_org_name, customer_tier, fiscal_quarter, cycle_start_date, cycle_end_date,
   allocated_budget_rupees, spent_to_date_rupees, committed_rupees, variance_rupees,
   variance_pct, burn_rate_per_day_rupees, projected_overrun_rupees, cycle_status,
   refill_requested, refill_amount_rupees, last_spend_at)
VALUES
  ('Apollo Hospitals Hyderabad','platinum','FY26Q3','2026-04-01'::date,'2026-06-30'::date,
   1800000.00,1620000.00,90000.00,-90000.00,-5.00,18000.00,210000.00,'watch',
   true,300000.00,now() - interval '2 hours'),
  ('Yashoda Super Specialty','gold','FY26Q3','2026-04-01'::date,'2026-06-30'::date,
   900000.00,945000.00,15000.00,60000.00,6.67,10500.00,75000.00,'over_budget',
   true,200000.00,now() - interval '6 hours'),
  ('KIMS Secunderabad','platinum','FY26Q3','2026-04-01'::date,'2026-06-30'::date,
   2400000.00,1320000.00,180000.00,-900000.00,-37.50,14600.00,0.00,'on_track',
   false,0.00,now() - interval '1 day'),
  ('Care Hospital Banjara','silver','FY26Q3','2026-04-01'::date,'2026-06-30'::date,
   450000.00,448500.00,1500.00,0.00,0.00,5050.00,12000.00,'exhausted',
   true,100000.00,now() - interval '3 hours'),
  ('Continental Nanakramguda','gold','FY26Q3','2026-04-01'::date,'2026-06-30'::date,
   1200000.00,720000.00,60000.00,-420000.00,-35.00,8000.00,0.00,'on_track',
   false,0.00,now() - interval '12 hours'),
  ('Sunshine Hospitals Begumpet','bronze','FY26Q3','2026-04-01'::date,'2026-06-30'::date,
   300000.00,180000.00,40000.00,-80000.00,-26.67,2200.00,0.00,'on_track',
   false,0.00,now() - interval '2 days'),
  ('Star Hospitals Banjara Hills','silver','FY26Q3','2026-04-01'::date,'2026-06-30'::date,
   600000.00,615000.00,5000.00,20000.00,3.33,7100.00,45000.00,'over_budget',
   false,0.00,now() - interval '5 hours');

-- ----------------------------------------------------------------------------
-- Table 2: budget_cycle_refill_actions_r2696
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS budget_cycle_refill_actions_r2696 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES customer_quarterly_budget_cycles_r2696(id) ON DELETE CASCADE,
  customer_org_name text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('refill_request','refill_approved','refill_denied','reallocate','escalate','freeze')),
  action_status text NOT NULL CHECK (action_status IN ('pending','in_review','approved','rejected','completed')),
  requested_amount_rupees numeric(14,2) NOT NULL CHECK (requested_amount_rupees >= 0),
  approved_amount_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (approved_amount_rupees >= 0),
  justification text NOT NULL,
  decision_reason text,
  decided_by text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE budget_cycle_refill_actions_r2696 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON budget_cycle_refill_actions_r2696;
CREATE POLICY founder_all ON budget_cycle_refill_actions_r2696
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO budget_cycle_refill_actions_r2696
  (cycle_id, customer_org_name, action_type, action_status, requested_amount_rupees,
   approved_amount_rupees, justification, decision_reason, decided_by, requested_at, decided_at)
SELECT id, 'Apollo Hospitals Hyderabad', 'refill_request', 'in_review', 300000.00,
       0.00, 'Q3 spike from CT scanner cluster failure; need buffer for remaining 30 days',
       NULL, NULL, now() - interval '2 hours', NULL
FROM customer_quarterly_budget_cycles_r2696 WHERE customer_org_name = 'Apollo Hospitals Hyderabad' LIMIT 1;

INSERT INTO budget_cycle_refill_actions_r2696
  (cycle_id, customer_org_name, action_type, action_status, requested_amount_rupees,
   approved_amount_rupees, justification, decision_reason, decided_by, requested_at, decided_at)
SELECT id, 'Yashoda Super Specialty', 'refill_approved', 'approved', 200000.00,
       180000.00, 'Critical biomedical equipment AMC overrun', 'Approved at 90% of ask',
       'ganesh@equipseva.com', now() - interval '1 day', now() - interval '20 hours'
FROM customer_quarterly_budget_cycles_r2696 WHERE customer_org_name = 'Yashoda Super Specialty' LIMIT 1;

INSERT INTO budget_cycle_refill_actions_r2696
  (cycle_id, customer_org_name, action_type, action_status, requested_amount_rupees,
   approved_amount_rupees, justification, decision_reason, decided_by, requested_at, decided_at)
SELECT id, 'Care Hospital Banjara', 'escalate', 'pending', 100000.00,
       0.00, 'Budget exhausted; pending CFO sign-off', NULL, NULL,
       now() - interval '4 hours', NULL
FROM customer_quarterly_budget_cycles_r2696 WHERE customer_org_name = 'Care Hospital Banjara' LIMIT 1;

INSERT INTO budget_cycle_refill_actions_r2696
  (cycle_id, customer_org_name, action_type, action_status, requested_amount_rupees,
   approved_amount_rupees, justification, decision_reason, decided_by, requested_at, decided_at)
SELECT id, 'Star Hospitals Banjara Hills', 'reallocate', 'completed', 30000.00,
       30000.00, 'Reallocate from Q4 forecast to cover overrun', 'Reallocation within FY26',
       'ganesh@equipseva.com', now() - interval '2 days', now() - interval '1 day'
FROM customer_quarterly_budget_cycles_r2696 WHERE customer_org_name = 'Star Hospitals Banjara Hills' LIMIT 1;

INSERT INTO budget_cycle_refill_actions_r2696
  (cycle_id, customer_org_name, action_type, action_status, requested_amount_rupees,
   approved_amount_rupees, justification, decision_reason, decided_by, requested_at, decided_at)
SELECT id, 'KIMS Secunderabad', 'refill_denied', 'rejected', 50000.00,
       0.00, 'Preemptive top-up request', 'Cycle 55% underspent; no refill needed',
       'ganesh@equipseva.com', now() - interval '5 days', now() - interval '4 days'
FROM customer_quarterly_budget_cycles_r2696 WHERE customer_org_name = 'KIMS Secunderabad' LIMIT 1;

INSERT INTO budget_cycle_refill_actions_r2696
  (cycle_id, customer_org_name, action_type, action_status, requested_amount_rupees,
   approved_amount_rupees, justification, decision_reason, decided_by, requested_at, decided_at)
SELECT id, 'Continental Nanakramguda', 'freeze', 'pending', 0.00,
       0.00, 'Freeze further AMC additions until Q4 budget locked', NULL, NULL,
       now() - interval '6 hours', NULL
FROM customer_quarterly_budget_cycles_r2696 WHERE customer_org_name = 'Continental Nanakramguda' LIMIT 1;

-- ============================================================================
-- RPC 1: list cycles
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2696_list_cycles();
CREATE OR REPLACE FUNCTION founder_r2696_list_cycles()
RETURNS TABLE(
  id uuid,
  customer_org_name text,
  customer_tier text,
  fiscal_quarter text,
  allocated_budget_rupees numeric,
  spent_to_date_rupees numeric,
  variance_pct numeric,
  cycle_status text,
  refill_requested boolean,
  last_spend_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.customer_org_name, c.customer_tier, c.fiscal_quarter,
         c.allocated_budget_rupees, c.spent_to_date_rupees, c.variance_pct,
         c.cycle_status, c.refill_requested, c.last_spend_at
  FROM customer_quarterly_budget_cycles_r2696 c
  ORDER BY c.variance_pct DESC, c.allocated_budget_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2696_list_cycles() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2696_list_cycles() TO authenticated;

-- ============================================================================
-- RPC 2: KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2696_kpis();
CREATE OR REPLACE FUNCTION founder_r2696_kpis()
RETURNS TABLE(
  total_cycles bigint,
  total_allocated_rupees numeric,
  total_spent_rupees numeric,
  over_budget_count bigint,
  exhausted_count bigint,
  pending_refill_count bigint,
  total_projected_overrun_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint,
         COALESCE(sum(allocated_budget_rupees),0)::numeric,
         COALESCE(sum(spent_to_date_rupees),0)::numeric,
         count(*) FILTER (WHERE cycle_status = 'over_budget')::bigint,
         count(*) FILTER (WHERE cycle_status = 'exhausted')::bigint,
         count(*) FILTER (WHERE refill_requested = true)::bigint,
         COALESCE(sum(projected_overrun_rupees),0)::numeric
  FROM customer_quarterly_budget_cycles_r2696;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2696_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2696_kpis() TO authenticated;

-- ============================================================================
-- RPC 3: by tier
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2696_by_tier();
CREATE OR REPLACE FUNCTION founder_r2696_by_tier()
RETURNS TABLE(
  customer_tier text,
  cycle_count bigint,
  total_allocated_rupees numeric,
  total_spent_rupees numeric,
  avg_variance_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.customer_tier,
         count(*)::bigint,
         COALESCE(sum(c.allocated_budget_rupees),0)::numeric,
         COALESCE(sum(c.spent_to_date_rupees),0)::numeric,
         COALESCE(avg(c.variance_pct),0)::numeric
  FROM customer_quarterly_budget_cycles_r2696 c
  GROUP BY c.customer_tier
  ORDER BY total_allocated_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2696_by_tier() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2696_by_tier() TO authenticated;

-- ============================================================================
-- RPC 4: refill actions list
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2696_refill_actions();
CREATE OR REPLACE FUNCTION founder_r2696_refill_actions()
RETURNS TABLE(
  id uuid,
  customer_org_name text,
  action_type text,
  action_status text,
  requested_amount_rupees numeric,
  approved_amount_rupees numeric,
  justification text,
  decided_by text,
  requested_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.customer_org_name, a.action_type, a.action_status,
         a.requested_amount_rupees, a.approved_amount_rupees,
         a.justification, a.decided_by, a.requested_at
  FROM budget_cycle_refill_actions_r2696 a
  ORDER BY a.requested_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2696_refill_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2696_refill_actions() TO authenticated;

-- ============================================================================
-- RPC 5: over-budget cycles
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2696_over_budget();
CREATE OR REPLACE FUNCTION founder_r2696_over_budget()
RETURNS TABLE(
  id uuid,
  customer_org_name text,
  customer_tier text,
  allocated_budget_rupees numeric,
  spent_to_date_rupees numeric,
  variance_rupees numeric,
  variance_pct numeric,
  projected_overrun_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.customer_org_name, c.customer_tier,
         c.allocated_budget_rupees, c.spent_to_date_rupees,
         c.variance_rupees, c.variance_pct, c.projected_overrun_rupees
  FROM customer_quarterly_budget_cycles_r2696 c
  WHERE c.cycle_status IN ('over_budget','exhausted')
  ORDER BY c.variance_pct DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2696_over_budget() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2696_over_budget() TO authenticated;

-- ============================================================================
-- RPC 6: pending refills
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2696_pending_refills();
CREATE OR REPLACE FUNCTION founder_r2696_pending_refills()
RETURNS TABLE(
  id uuid,
  customer_org_name text,
  requested_amount_rupees numeric,
  justification text,
  requested_at timestamptz,
  action_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.customer_org_name, a.requested_amount_rupees,
         a.justification, a.requested_at, a.action_status
  FROM budget_cycle_refill_actions_r2696 a
  WHERE a.action_status IN ('pending','in_review')
  ORDER BY a.requested_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2696_pending_refills() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2696_pending_refills() TO authenticated;

-- ============================================================================
-- RPC 7: burn-rate report
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2696_burn_rate();
CREATE OR REPLACE FUNCTION founder_r2696_burn_rate()
RETURNS TABLE(
  id uuid,
  customer_org_name text,
  burn_rate_per_day_rupees numeric,
  spent_to_date_rupees numeric,
  allocated_budget_rupees numeric,
  days_remaining int,
  projected_total_spend_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.customer_org_name, c.burn_rate_per_day_rupees,
         c.spent_to_date_rupees, c.allocated_budget_rupees,
         GREATEST((c.cycle_end_date - CURRENT_DATE), 0)::int AS days_remaining,
         (c.spent_to_date_rupees + (c.burn_rate_per_day_rupees * GREATEST((c.cycle_end_date - CURRENT_DATE), 0)))::numeric AS projected_total_spend_rupees
  FROM customer_quarterly_budget_cycles_r2696 c
  ORDER BY c.burn_rate_per_day_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2696_burn_rate() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2696_burn_rate() TO authenticated;

-- ============================================================================
-- RPC 8: approve refill
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2696_approve_refill(uuid, numeric, text);
CREATE OR REPLACE FUNCTION founder_r2696_approve_refill(
  p_action_id uuid,
  p_approved_amount numeric,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE budget_cycle_refill_actions_r2696
  SET action_status = 'approved',
      action_type = 'refill_approved',
      approved_amount_rupees = COALESCE(p_approved_amount, 0),
      decision_reason = p_reason,
      decided_by = 'founder',
      decided_at = now()
  WHERE id = p_action_id
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2696_approve_refill(uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2696_approve_refill(uuid, numeric, text) TO authenticated;

COMMIT;
