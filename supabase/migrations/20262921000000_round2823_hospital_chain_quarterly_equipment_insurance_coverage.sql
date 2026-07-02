BEGIN;

-- ============================================================================
-- Round 2823: Hospital Chain Quarterly Equipment Insurance Coverage
-- ============================================================================

CREATE TABLE IF NOT EXISTS chain_equipment_insurance_policies_r2823 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code text NOT NULL,
  chain_name text NOT NULL,
  asset_tag text NOT NULL,
  asset_category text NOT NULL CHECK (asset_category IN ('imaging','surgical','life_support','lab','dental','monitoring')),
  insurance_kind text NOT NULL CHECK (insurance_kind IN ('comprehensive','breakdown_only','third_party','extended_warranty','cyber_med')),
  insurer_name text NOT NULL,
  policy_number text NOT NULL,
  asset_value_rupees bigint NOT NULL CHECK (asset_value_rupees > 0),
  quarterly_premium_rupees bigint NOT NULL CHECK (quarterly_premium_rupees >= 0),
  coverage_start_date date NOT NULL,
  coverage_end_date date NOT NULL,
  deductible_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','lapsed','renewal_pending','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_equipment_insurance_policies_r2823 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_equipment_insurance_policies_r2823;
CREATE POLICY founder_all ON chain_equipment_insurance_policies_r2823
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_equipment_insurance_policies_r2823 (chain_code, chain_name, asset_tag, asset_category, insurance_kind, insurer_name, policy_number, asset_value_rupees, quarterly_premium_rupees, coverage_start_date, coverage_end_date, deductible_rupees, status, notes) VALUES
  ('APOLLO', 'Apollo Hospitals Group', 'APL-CT-128', 'imaging', 'comprehensive', 'Bajaj Allianz', 'BA-MED-2026-44128', 85000000, 425000, '2026-04-01'::date, '2026-06-30'::date, 250000, 'active', '128-slice CT, Hyderabad flagship'),
  ('FORTIS', 'Fortis Healthcare', 'FRT-MRI-3T', 'imaging', 'comprehensive', 'ICICI Lombard', 'ICL-EQ-2026-99812', 120000000, 580000, '2026-04-01'::date, '2026-06-30'::date, 500000, 'active', '3T MRI, Gurgaon'),
  ('MAX', 'Max Healthcare', 'MAX-VENT-04', 'life_support', 'breakdown_only', 'New India Assurance', 'NIA-BRK-2026-22041', 4500000, 18000, '2026-04-01'::date, '2026-06-30'::date, 50000, 'active', 'Drager Evita V500 ventilator'),
  ('MANIPAL', 'Manipal Hospitals', 'MNP-LAP-09', 'surgical', 'extended_warranty', 'HDFC Ergo', 'HDFC-EW-2026-77509', 6800000, 22000, '2026-04-01'::date, '2026-06-30'::date, 25000, 'renewal_pending', 'Karl Storz laparoscopic tower, renewal due 2026-06-30'),
  ('CLOVE', 'Clove Dental', 'CLV-DCH-241', 'dental', 'breakdown_only', 'Tata AIG', 'TATA-DEN-2026-31241', 850000, 4200, '2026-04-01'::date, '2026-06-30'::date, 10000, 'active', 'Sirona dental chair, Bengaluru cluster'),
  ('NARAYANA', 'Narayana Health', 'NH-ECMO-02', 'life_support', 'comprehensive', 'Bajaj Allianz', 'BA-MED-2026-55102', 22000000, 110000, '2026-04-01'::date, '2026-06-30'::date, 200000, 'lapsed', 'ECMO machine, lapsed due to premium dispute'),
  ('AIIMS-PVT', 'AIIMS Affiliated Pvt', 'AIM-LAB-014', 'lab', 'cyber_med', 'ICICI Lombard', 'ICL-CYB-2026-11014', 12000000, 95000, '2026-04-01'::date, '2026-06-30'::date, 100000, 'active', 'Lab analyser w/ network exposure');

-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chain_insurance_claim_history_r2823 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id uuid NOT NULL REFERENCES chain_equipment_insurance_policies_r2823(id) ON DELETE CASCADE,
  claim_reference text NOT NULL UNIQUE,
  incident_date date NOT NULL,
  claim_amount_rupees bigint NOT NULL CHECK (claim_amount_rupees >= 0),
  approved_amount_rupees bigint NOT NULL DEFAULT 0,
  claim_status text NOT NULL CHECK (claim_status IN ('filed','under_review','approved','partially_approved','rejected','paid')),
  incident_kind text NOT NULL CHECK (incident_kind IN ('electrical','mechanical','water_damage','user_error','cyber','natural_calamity','theft')),
  resolution_days integer NOT NULL DEFAULT 0 CHECK (resolution_days >= 0),
  renewal_verdict text NOT NULL DEFAULT 'pending' CHECK (renewal_verdict IN ('pending','recommend_renew','recommend_drop','recommend_switch_insurer','recommend_raise_deductible')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_insurance_claim_history_r2823 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_insurance_claim_history_r2823;
CREATE POLICY founder_all ON chain_insurance_claim_history_r2823
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_insurance_claim_history_r2823 (policy_id, claim_reference, incident_date, claim_amount_rupees, approved_amount_rupees, claim_status, incident_kind, resolution_days, renewal_verdict, notes)
SELECT id, 'CLM-APL-2026-04-018', '2026-04-12'::date, 1850000, 1600000, 'paid', 'electrical', 22, 'recommend_renew', 'CT tube replacement, smooth claim'
FROM chain_equipment_insurance_policies_r2823 WHERE asset_tag='APL-CT-128';

INSERT INTO chain_insurance_claim_history_r2823 (policy_id, claim_reference, incident_date, claim_amount_rupees, approved_amount_rupees, claim_status, incident_kind, resolution_days, renewal_verdict, notes)
SELECT id, 'CLM-FRT-2026-05-007', '2026-05-04'::date, 4200000, 0, 'rejected', 'user_error', 38, 'recommend_switch_insurer', 'ICICI rejected citing operator negligence — chain disputes'
FROM chain_equipment_insurance_policies_r2823 WHERE asset_tag='FRT-MRI-3T';

INSERT INTO chain_insurance_claim_history_r2823 (policy_id, claim_reference, incident_date, claim_amount_rupees, approved_amount_rupees, claim_status, incident_kind, resolution_days, renewal_verdict, notes)
SELECT id, 'CLM-MAX-2026-04-031', '2026-04-22'::date, 220000, 180000, 'paid', 'mechanical', 14, 'recommend_renew', 'Vent solenoid replacement'
FROM chain_equipment_insurance_policies_r2823 WHERE asset_tag='MAX-VENT-04';

INSERT INTO chain_insurance_claim_history_r2823 (policy_id, claim_reference, incident_date, claim_amount_rupees, approved_amount_rupees, claim_status, incident_kind, resolution_days, renewal_verdict, notes)
SELECT id, 'CLM-MNP-2026-05-013', '2026-05-18'::date, 480000, 320000, 'partially_approved', 'mechanical', 19, 'recommend_raise_deductible', 'Karl Storz scope repeated breakdown — deductible too low'
FROM chain_equipment_insurance_policies_r2823 WHERE asset_tag='MNP-LAP-09';

INSERT INTO chain_insurance_claim_history_r2823 (policy_id, claim_reference, incident_date, claim_amount_rupees, approved_amount_rupees, claim_status, incident_kind, resolution_days, renewal_verdict, notes)
SELECT id, 'CLM-CLV-2026-06-002', '2026-06-02'::date, 38000, 28000, 'paid', 'water_damage', 9, 'recommend_renew', 'Chair hydraulics water ingress, monsoon Bengaluru'
FROM chain_equipment_insurance_policies_r2823 WHERE asset_tag='CLV-DCH-241';

INSERT INTO chain_insurance_claim_history_r2823 (policy_id, claim_reference, incident_date, claim_amount_rupees, approved_amount_rupees, claim_status, incident_kind, resolution_days, renewal_verdict, notes)
SELECT id, 'CLM-NH-2026-04-009', '2026-04-08'::date, 6800000, 0, 'rejected', 'mechanical', 45, 'recommend_drop', 'Lapsed before incident — coverage void; ECMO uninsurable at this insurer'
FROM chain_equipment_insurance_policies_r2823 WHERE asset_tag='NH-ECMO-02';

INSERT INTO chain_insurance_claim_history_r2823 (policy_id, claim_reference, incident_date, claim_amount_rupees, approved_amount_rupees, claim_status, incident_kind, resolution_days, renewal_verdict, notes)
SELECT id, 'CLM-AIM-2026-05-021', '2026-05-26'::date, 1450000, 1450000, 'approved', 'cyber', 7, 'recommend_renew', 'Ransomware on lab analyser — cyber_med kicked in'
FROM chain_equipment_insurance_policies_r2823 WHERE asset_tag='AIM-LAB-014';

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2823_kpis();
CREATE OR REPLACE FUNCTION founder_r2823_kpis()
RETURNS TABLE (
  total_policies bigint,
  active_policies bigint,
  total_quarterly_premium_rupees numeric,
  total_asset_value_rupees numeric,
  total_claims_filed bigint,
  total_claim_amount_rupees numeric,
  total_approved_amount_rupees numeric,
  claim_payout_ratio numeric,
  renewal_pending_count bigint,
  lapsed_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH p AS (SELECT * FROM chain_equipment_insurance_policies_r2823),
       c AS (SELECT * FROM chain_insurance_claim_history_r2823)
  SELECT
    (SELECT count(*) FROM p),
    (SELECT count(*) FROM p WHERE status='active'),
    (SELECT COALESCE(sum(quarterly_premium_rupees),0)::numeric FROM p),
    (SELECT COALESCE(sum(asset_value_rupees),0)::numeric FROM p),
    (SELECT count(*) FROM c),
    (SELECT COALESCE(sum(claim_amount_rupees),0)::numeric FROM c),
    (SELECT COALESCE(sum(approved_amount_rupees),0)::numeric FROM c),
    CASE WHEN (SELECT sum(claim_amount_rupees) FROM c) > 0
         THEN ROUND(((SELECT sum(approved_amount_rupees) FROM c)::numeric / (SELECT sum(claim_amount_rupees) FROM c)::numeric) * 100, 2)
         ELSE 0 END,
    (SELECT count(*) FROM p WHERE status='renewal_pending'),
    (SELECT count(*) FROM p WHERE status='lapsed');
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2823_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2823_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2823_policies_by_chain();
CREATE OR REPLACE FUNCTION founder_r2823_policies_by_chain()
RETURNS TABLE (
  chain_code text,
  chain_name text,
  policy_count bigint,
  quarterly_premium_rupees numeric,
  asset_value_rupees numeric,
  active_count bigint,
  lapsed_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_code, p.chain_name,
         count(*), sum(p.quarterly_premium_rupees)::numeric, sum(p.asset_value_rupees)::numeric,
         count(*) FILTER (WHERE p.status='active'),
         count(*) FILTER (WHERE p.status='lapsed')
  FROM chain_equipment_insurance_policies_r2823 p
  GROUP BY p.chain_code, p.chain_name
  ORDER BY sum(p.quarterly_premium_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2823_policies_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2823_policies_by_chain() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2823_by_insurance_kind();
CREATE OR REPLACE FUNCTION founder_r2823_by_insurance_kind()
RETURNS TABLE (
  insurance_kind text,
  policy_count bigint,
  quarterly_premium_rupees numeric,
  total_claim_amount_rupees numeric,
  total_approved_amount_rupees numeric,
  payout_ratio_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.insurance_kind,
         count(p.id),
         COALESCE(sum(p.quarterly_premium_rupees),0)::numeric,
         COALESCE(sum(c.claim_amount_rupees),0)::numeric,
         COALESCE(sum(c.approved_amount_rupees),0)::numeric,
         CASE WHEN COALESCE(sum(c.claim_amount_rupees),0) > 0
              THEN ROUND((COALESCE(sum(c.approved_amount_rupees),0)::numeric / sum(c.claim_amount_rupees)::numeric)*100, 2)
              ELSE 0 END
  FROM chain_equipment_insurance_policies_r2823 p
  LEFT JOIN chain_insurance_claim_history_r2823 c ON c.policy_id = p.id
  GROUP BY p.insurance_kind
  ORDER BY sum(p.quarterly_premium_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2823_by_insurance_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2823_by_insurance_kind() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2823_claim_detail();
CREATE OR REPLACE FUNCTION founder_r2823_claim_detail()
RETURNS TABLE (
  claim_reference text,
  chain_name text,
  asset_tag text,
  asset_category text,
  insurance_kind text,
  insurer_name text,
  incident_date date,
  incident_kind text,
  claim_amount_rupees bigint,
  approved_amount_rupees bigint,
  claim_status text,
  resolution_days integer,
  renewal_verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.claim_reference, p.chain_name, p.asset_tag, p.asset_category,
         p.insurance_kind, p.insurer_name, c.incident_date, c.incident_kind,
         c.claim_amount_rupees, c.approved_amount_rupees, c.claim_status,
         c.resolution_days, c.renewal_verdict
  FROM chain_insurance_claim_history_r2823 c
  JOIN chain_equipment_insurance_policies_r2823 p ON p.id = c.policy_id
  ORDER BY c.incident_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2823_claim_detail() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2823_claim_detail() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2823_renewal_verdicts();
CREATE OR REPLACE FUNCTION founder_r2823_renewal_verdicts()
RETURNS TABLE (
  renewal_verdict text,
  policy_count bigint,
  claim_count bigint,
  quarterly_premium_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.renewal_verdict,
         count(DISTINCT p.id),
         count(c.id),
         COALESCE(sum(p.quarterly_premium_rupees),0)::numeric
  FROM chain_insurance_claim_history_r2823 c
  JOIN chain_equipment_insurance_policies_r2823 p ON p.id = c.policy_id
  GROUP BY c.renewal_verdict
  ORDER BY count(c.id) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2823_renewal_verdicts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2823_renewal_verdicts() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2823_top_risk_assets();
CREATE OR REPLACE FUNCTION founder_r2823_top_risk_assets()
RETURNS TABLE (
  chain_name text,
  asset_tag text,
  asset_category text,
  total_claims bigint,
  total_claim_amount_rupees numeric,
  approved_amount_rupees numeric,
  rejected_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_name, p.asset_tag, p.asset_category,
         count(c.id),
         COALESCE(sum(c.claim_amount_rupees),0)::numeric,
         COALESCE(sum(c.approved_amount_rupees),0)::numeric,
         count(c.id) FILTER (WHERE c.claim_status='rejected')
  FROM chain_equipment_insurance_policies_r2823 p
  LEFT JOIN chain_insurance_claim_history_r2823 c ON c.policy_id = p.id
  GROUP BY p.chain_name, p.asset_tag, p.asset_category
  ORDER BY COALESCE(sum(c.claim_amount_rupees),0) DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2823_top_risk_assets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2823_top_risk_assets() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2823_insurer_performance();
CREATE OR REPLACE FUNCTION founder_r2823_insurer_performance()
RETURNS TABLE (
  insurer_name text,
  policy_count bigint,
  total_premium_rupees numeric,
  claims_filed bigint,
  claims_approved bigint,
  claims_rejected bigint,
  approval_rate_pct numeric,
  avg_resolution_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.insurer_name,
         count(DISTINCT p.id),
         COALESCE(sum(p.quarterly_premium_rupees),0)::numeric,
         count(c.id),
         count(c.id) FILTER (WHERE c.claim_status IN ('approved','paid','partially_approved')),
         count(c.id) FILTER (WHERE c.claim_status='rejected'),
         CASE WHEN count(c.id) > 0
              THEN ROUND((count(c.id) FILTER (WHERE c.claim_status IN ('approved','paid','partially_approved'))::numeric / count(c.id)::numeric) * 100, 2)
              ELSE 0 END,
         COALESCE(ROUND(AVG(c.resolution_days)::numeric, 1), 0)
  FROM chain_equipment_insurance_policies_r2823 p
  LEFT JOIN chain_insurance_claim_history_r2823 c ON c.policy_id = p.id
  GROUP BY p.insurer_name
  ORDER BY count(DISTINCT p.id) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2823_insurer_performance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2823_insurer_performance() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2823_renewal_pending();
CREATE OR REPLACE FUNCTION founder_r2823_renewal_pending()
RETURNS TABLE (
  chain_name text,
  asset_tag text,
  insurer_name text,
  policy_number text,
  coverage_end_date date,
  quarterly_premium_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_name, p.asset_tag, p.insurer_name, p.policy_number,
         p.coverage_end_date, p.quarterly_premium_rupees, p.status
  FROM chain_equipment_insurance_policies_r2823 p
  WHERE p.status IN ('renewal_pending','lapsed') OR p.coverage_end_date <= (CURRENT_DATE + INTERVAL '30 days')
  ORDER BY p.coverage_end_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2823_renewal_pending() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2823_renewal_pending() TO authenticated;

COMMIT;
