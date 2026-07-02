BEGIN;

-- =========================================================================
-- Round 2715: Hospital Chain Monthly Finance Team Budget Cycle
-- =========================================================================

-- ---- Tables --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hospital_chain_finance_cfo_contacts_r2715 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  cfo_name text NOT NULL,
  cfo_email text NOT NULL,
  cfo_phone text NOT NULL,
  hq_city text NOT NULL,
  bed_count int NOT NULL CHECK (bed_count > 0),
  fy_budget_rupees bigint NOT NULL CHECK (fy_budget_rupees > 0),
  relationship_tier text NOT NULL CHECK (relationship_tier IN ('platinum','gold','silver','bronze')),
  last_touch_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS hospital_chain_monthly_budget_cycles_r2715 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES hospital_chain_finance_cfo_contacts_r2715(id) ON DELETE CASCADE,
  cycle_month date NOT NULL,
  proposed_amount_rupees bigint NOT NULL CHECK (proposed_amount_rupees >= 0),
  approved_amount_rupees bigint NOT NULL CHECK (approved_amount_rupees >= 0),
  disbursed_amount_rupees bigint NOT NULL CHECK (disbursed_amount_rupees >= 0),
  approval_status text NOT NULL CHECK (approval_status IN ('draft','submitted','approved','partially_approved','rejected','disbursed','closed')),
  outcome_status text NOT NULL CHECK (outcome_status IN ('pending','on_track','over_spend','under_spend','closed_clean','clawback')),
  proposal_submitted_at timestamptz,
  approved_at timestamptz,
  disbursed_at timestamptz,
  proposal_owner text NOT NULL,
  finance_reviewer text NOT NULL,
  utilisation_pct numeric(6,2) NOT NULL DEFAULT 0 CHECK (utilisation_pct >= 0),
  variance_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---- RLS -----------------------------------------------------------------

ALTER TABLE hospital_chain_finance_cfo_contacts_r2715 ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_chain_monthly_budget_cycles_r2715 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON hospital_chain_finance_cfo_contacts_r2715;
CREATE POLICY founder_all ON hospital_chain_finance_cfo_contacts_r2715
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON hospital_chain_monthly_budget_cycles_r2715;
CREATE POLICY founder_all ON hospital_chain_monthly_budget_cycles_r2715
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---- Seed: CFO contacts --------------------------------------------------

INSERT INTO hospital_chain_finance_cfo_contacts_r2715
  (chain_name, cfo_name, cfo_email, cfo_phone, hq_city, bed_count, fy_budget_rupees, relationship_tier, notes)
VALUES
  ('Apollo Hospitals Group','Krishnan Akileswaran','krishnan.cfo@apollo.example','+91-9000010001','Chennai',10000,1200000000,'platinum','Quarterly review cadence; CEO sponsor'),
  ('Fortis Healthcare','Vivek Goyal','vivek.cfo@fortis.example','+91-9000010002','Gurugram',4500,540000000,'platinum','Strong AMC pipeline; cycle owner = Anita Rao'),
  ('Manipal Hospitals','Anand Sankaranarayanan','anand.cfo@manipal.example','+91-9000010003','Bengaluru',8800,720000000,'gold','Pune + Goa expansion absorbs Q3 budget'),
  ('Max Healthcare','Abhay Soi','abhay.cfo@max.example','+91-9000010004','New Delhi',4000,480000000,'gold','Approves only on monthly OPEX board view'),
  ('Narayana Health','Viren Shetty','viren.cfo@narayana.example','+91-9000010005','Bengaluru',6200,360000000,'silver','Lean OPEX bias; price-sensitive'),
  ('AIIMS Network','Sanjeev Lalwani','sanjeev.cfo@aiims.example','+91-9000010006','New Delhi',12000,900000000,'platinum','PSU procurement rules; longer cycle'),
  ('Aster DM Healthcare','Sunil Kumar M R','sunil.cfo@aster.example','+91-9000010007','Kochi',4900,420000000,'gold','Kerala + Karnataka split P&L');

-- ---- Seed: Budget cycles -------------------------------------------------

INSERT INTO hospital_chain_monthly_budget_cycles_r2715
  (contact_id, cycle_month, proposed_amount_rupees, approved_amount_rupees, disbursed_amount_rupees,
   approval_status, outcome_status, proposal_submitted_at, approved_at, disbursed_at,
   proposal_owner, finance_reviewer, utilisation_pct, variance_rupees, notes)
SELECT id, '2026-04-01'::date, 9500000, 9000000, 8700000,
       'disbursed','on_track', now() - interval '70 days', now() - interval '60 days', now() - interval '50 days',
       'Ravi Menon','Krishnan Akileswaran', 96.67, -300000, 'April cycle ran clean; minor under-spend on spares'
FROM hospital_chain_finance_cfo_contacts_r2715 WHERE chain_name='Apollo Hospitals Group'
UNION ALL
SELECT id, '2026-05-01'::date, 6200000, 5800000, 5800000,
       'closed','closed_clean', now() - interval '45 days', now() - interval '40 days', now() - interval '30 days',
       'Anita Rao','Vivek Goyal', 100.00, 0, 'Fortis May cycle fully consumed'
FROM hospital_chain_finance_cfo_contacts_r2715 WHERE chain_name='Fortis Healthcare'
UNION ALL
SELECT id, '2026-06-01'::date, 7100000, 6500000, 6800000,
       'disbursed','over_spend', now() - interval '20 days', now() - interval '15 days', now() - interval '7 days',
       'Lakshmi Iyer','Anand Sankaranarayanan', 104.62, 300000, 'Pune emergency replacement caused overshoot'
FROM hospital_chain_finance_cfo_contacts_r2715 WHERE chain_name='Manipal Hospitals'
UNION ALL
SELECT id, '2026-06-01'::date, 4800000, 4200000, 4200000,
       'approved','on_track', now() - interval '18 days', now() - interval '10 days', NULL,
       'Pooja Saxena','Abhay Soi', 0.00, 0, 'Disbursement scheduled for 1st week July'
FROM hospital_chain_finance_cfo_contacts_r2715 WHERE chain_name='Max Healthcare'
UNION ALL
SELECT id, '2026-06-01'::date, 3000000, 2400000, 0,
       'partially_approved','pending', now() - interval '14 days', now() - interval '8 days', NULL,
       'Karthik Bhat','Viren Shetty', 0.00, 0, 'Narayana asked to defer 20% to next cycle'
FROM hospital_chain_finance_cfo_contacts_r2715 WHERE chain_name='Narayana Health'
UNION ALL
SELECT id, '2026-06-01'::date, 8200000, 0, 0,
       'submitted','pending', now() - interval '5 days', NULL, NULL,
       'Devika Sharma','Sanjeev Lalwani', 0.00, 0, 'AIIMS quote under PSU procurement review'
FROM hospital_chain_finance_cfo_contacts_r2715 WHERE chain_name='AIIMS Network'
UNION ALL
SELECT id, '2026-05-01'::date, 4100000, 4100000, 3600000,
       'closed','under_spend', now() - interval '50 days', now() - interval '42 days', now() - interval '30 days',
       'Neha Krishnan','Sunil Kumar M R', 87.80, -500000, 'Kerala monsoon delayed two installations'
FROM hospital_chain_finance_cfo_contacts_r2715 WHERE chain_name='Aster DM Healthcare';

-- ---- RPCs ----------------------------------------------------------------

-- 1. KPI summary
DROP FUNCTION IF EXISTS r2715_kpi_summary();
CREATE OR REPLACE FUNCTION r2715_kpi_summary()
RETURNS TABLE (
  total_chains int,
  active_cycles int,
  total_proposed_rupees bigint,
  total_approved_rupees bigint,
  total_disbursed_rupees bigint,
  approval_rate numeric,
  utilisation_avg numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM hospital_chain_finance_cfo_contacts_r2715),
    (SELECT count(*)::int FROM hospital_chain_monthly_budget_cycles_r2715
       WHERE approval_status NOT IN ('closed','rejected')),
    COALESCE(SUM(proposed_amount_rupees),0)::bigint,
    COALESCE(SUM(approved_amount_rupees),0)::bigint,
    COALESCE(SUM(disbursed_amount_rupees),0)::bigint,
    CASE WHEN SUM(proposed_amount_rupees) > 0
         THEN ROUND((SUM(approved_amount_rupees)::numeric / SUM(proposed_amount_rupees)) * 100, 2)
         ELSE 0 END,
    COALESCE(ROUND(AVG(utilisation_pct), 2), 0)
  FROM hospital_chain_monthly_budget_cycles_r2715;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2715_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2715_kpi_summary() TO authenticated;

-- 2. List CFO contacts
DROP FUNCTION IF EXISTS r2715_list_contacts();
CREATE OR REPLACE FUNCTION r2715_list_contacts()
RETURNS TABLE (
  id uuid,
  chain_name text,
  cfo_name text,
  cfo_email text,
  hq_city text,
  bed_count int,
  fy_budget_rupees bigint,
  relationship_tier text,
  last_touch_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.cfo_name, c.cfo_email, c.hq_city,
         c.bed_count, c.fy_budget_rupees, c.relationship_tier, c.last_touch_at
  FROM hospital_chain_finance_cfo_contacts_r2715 c
  ORDER BY c.fy_budget_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2715_list_contacts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2715_list_contacts() TO authenticated;

-- 3. List cycles joined with chain
DROP FUNCTION IF EXISTS r2715_list_cycles();
CREATE OR REPLACE FUNCTION r2715_list_cycles()
RETURNS TABLE (
  id uuid,
  chain_name text,
  cfo_name text,
  cycle_month date,
  proposed_amount_rupees bigint,
  approved_amount_rupees bigint,
  disbursed_amount_rupees bigint,
  approval_status text,
  outcome_status text,
  utilisation_pct numeric,
  variance_rupees bigint,
  proposal_owner text,
  finance_reviewer text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, c.chain_name, c.cfo_name, b.cycle_month,
         b.proposed_amount_rupees, b.approved_amount_rupees, b.disbursed_amount_rupees,
         b.approval_status, b.outcome_status, b.utilisation_pct, b.variance_rupees,
         b.proposal_owner, b.finance_reviewer
  FROM hospital_chain_monthly_budget_cycles_r2715 b
  JOIN hospital_chain_finance_cfo_contacts_r2715 c ON c.id = b.contact_id
  ORDER BY b.cycle_month DESC, c.chain_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2715_list_cycles() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2715_list_cycles() TO authenticated;

-- 4. Approval funnel
DROP FUNCTION IF EXISTS r2715_approval_funnel();
CREATE OR REPLACE FUNCTION r2715_approval_funnel()
RETURNS TABLE (
  approval_status text,
  cycle_count int,
  proposed_sum bigint,
  approved_sum bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.approval_status, count(*)::int,
         SUM(b.proposed_amount_rupees)::bigint,
         SUM(b.approved_amount_rupees)::bigint
  FROM hospital_chain_monthly_budget_cycles_r2715 b
  GROUP BY b.approval_status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2715_approval_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2715_approval_funnel() TO authenticated;

-- 5. Outcome distribution
DROP FUNCTION IF EXISTS r2715_outcome_distribution();
CREATE OR REPLACE FUNCTION r2715_outcome_distribution()
RETURNS TABLE (
  outcome_status text,
  cycle_count int,
  disbursed_sum bigint,
  avg_utilisation numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.outcome_status, count(*)::int,
         SUM(b.disbursed_amount_rupees)::bigint,
         ROUND(AVG(b.utilisation_pct), 2)
  FROM hospital_chain_monthly_budget_cycles_r2715 b
  GROUP BY b.outcome_status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2715_outcome_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2715_outcome_distribution() TO authenticated;

-- 6. Top variance cycles
DROP FUNCTION IF EXISTS r2715_top_variance();
CREATE OR REPLACE FUNCTION r2715_top_variance()
RETURNS TABLE (
  chain_name text,
  cycle_month date,
  variance_rupees bigint,
  utilisation_pct numeric,
  outcome_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name, b.cycle_month, b.variance_rupees, b.utilisation_pct, b.outcome_status
  FROM hospital_chain_monthly_budget_cycles_r2715 b
  JOIN hospital_chain_finance_cfo_contacts_r2715 c ON c.id = b.contact_id
  ORDER BY abs(b.variance_rupees) DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2715_top_variance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2715_top_variance() TO authenticated;

-- 7. Tier mix
DROP FUNCTION IF EXISTS r2715_tier_mix();
CREATE OR REPLACE FUNCTION r2715_tier_mix()
RETURNS TABLE (
  relationship_tier text,
  chain_count int,
  fy_budget_sum bigint,
  bed_count_sum int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.relationship_tier, count(*)::int,
         SUM(c.fy_budget_rupees)::bigint,
         SUM(c.bed_count)::int
  FROM hospital_chain_finance_cfo_contacts_r2715 c
  GROUP BY c.relationship_tier
  ORDER BY SUM(c.fy_budget_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2715_tier_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2715_tier_mix() TO authenticated;

-- 8. Pending action queue
DROP FUNCTION IF EXISTS r2715_pending_actions();
CREATE OR REPLACE FUNCTION r2715_pending_actions()
RETURNS TABLE (
  chain_name text,
  cycle_month date,
  approval_status text,
  proposed_amount_rupees bigint,
  proposal_owner text,
  finance_reviewer text,
  days_in_status int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name, b.cycle_month, b.approval_status, b.proposed_amount_rupees,
         b.proposal_owner, b.finance_reviewer,
         GREATEST(0, EXTRACT(day FROM (now() - COALESCE(b.proposal_submitted_at, b.created_at)))::int)
  FROM hospital_chain_monthly_budget_cycles_r2715 b
  JOIN hospital_chain_finance_cfo_contacts_r2715 c ON c.id = b.contact_id
  WHERE b.approval_status IN ('draft','submitted','partially_approved','approved')
    AND (b.disbursed_at IS NULL OR b.disbursed_amount_rupees < b.approved_amount_rupees)
  ORDER BY b.proposal_submitted_at ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2715_pending_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2715_pending_actions() TO authenticated;

COMMIT;
