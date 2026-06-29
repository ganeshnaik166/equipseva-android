-- Round 2935: Hospital Chain Quarterly Equipment-Lifecycle Replacement Forecast Plan
-- HEAVY ★★★★

-- =========================================================
-- TABLE 1: chain_equipment_lifecycle_forecast_r2935
-- =========================================================
CREATE TABLE IF NOT EXISTS chain_equipment_lifecycle_forecast_r2935 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_count int NOT NULL CHECK (hospital_count > 0),
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','surgical','life_support','diagnostic','dental','laboratory','monitoring')),
  forecast_quarter text NOT NULL CHECK (forecast_quarter IN ('q1_2027','q2_2027','q3_2027','q4_2027','q1_2028','q2_2028')),
  units_due int NOT NULL CHECK (units_due >= 0),
  avg_age_years numeric(4,2) NOT NULL CHECK (avg_age_years >= 0),
  est_replacement_cost_lakh numeric(10,2) NOT NULL CHECK (est_replacement_cost_lakh >= 0),
  urgency_tier text NOT NULL CHECK (urgency_tier IN ('critical','high','medium','low','watch')),
  funding_status text NOT NULL CHECK (funding_status IN ('approved','pending_board','budgeting','sourcing','deferred')),
  notes text
);

ALTER TABLE chain_equipment_lifecycle_forecast_r2935 ENABLE ROW LEVEL SECURITY;

INSERT INTO chain_equipment_lifecycle_forecast_r2935
  (chain_name, hospital_count, equipment_category, forecast_quarter, units_due, avg_age_years, est_replacement_cost_lakh, urgency_tier, funding_status, notes)
VALUES
  ('Apollo MedChain', 18, 'imaging', 'q1_2027', 12, 9.50, 480.00, 'critical', 'approved', 'CT scanners EoL Bangalore + Hyderabad clusters'),
  ('Apollo MedChain', 18, 'surgical', 'q2_2027', 8, 7.20, 220.00, 'high', 'pending_board', 'OR tables refresh wave'),
  ('Fortis NetCare', 14, 'life_support', 'q1_2027', 22, 8.10, 165.00, 'critical', 'approved', 'Ventilator fleet pre-monsoon swap'),
  ('Fortis NetCare', 14, 'monitoring', 'q3_2027', 60, 6.40, 90.00, 'medium', 'sourcing', 'Patient monitors phase rollout'),
  ('Manipal HealthGroup', 22, 'diagnostic', 'q2_2027', 30, 7.80, 145.00, 'high', 'budgeting', 'USG + ECG combined refresh'),
  ('Manipal HealthGroup', 22, 'imaging', 'q4_2027', 6, 10.30, 720.00, 'critical', 'pending_board', 'MRI 1.5T → 3T upgrade'),
  ('Max Healthcare', 16, 'laboratory', 'q1_2027', 18, 9.20, 95.00, 'high', 'approved', 'Hematology analyzer chain'),
  ('Max Healthcare', 16, 'surgical', 'q3_2027', 5, 11.10, 380.00, 'critical', 'budgeting', 'Robotic surgery platform Gen-2'),
  ('Narayana Health', 25, 'dental', 'q2_2027', 14, 8.50, 42.00, 'medium', 'sourcing', 'Dental chairs municipal wing'),
  ('Narayana Health', 25, 'monitoring', 'q1_2028', 80, 7.00, 120.00, 'medium', 'budgeting', 'Cardio telemetry refresh'),
  ('AIIMS-Affiliated', 12, 'imaging', 'q2_2028', 4, 12.40, 560.00, 'critical', 'deferred', 'Linear accelerator capital ask'),
  ('AIIMS-Affiliated', 12, 'life_support', 'q3_2027', 16, 8.80, 140.00, 'high', 'pending_board', 'ICU ventilator + dialysis'),
  ('Kauvery Hospitals', 9, 'diagnostic', 'q1_2027', 11, 7.60, 68.00, 'medium', 'approved', 'X-ray digital retrofits'),
  ('Kauvery Hospitals', 9, 'surgical', 'q4_2027', 6, 9.30, 175.00, 'high', 'budgeting', 'Laparoscopy stack'),
  ('Yashoda Group', 11, 'imaging', 'q3_2027', 9, 8.90, 410.00, 'high', 'pending_board', 'CT 64-slice → 128-slice'),
  ('Yashoda Group', 11, 'laboratory', 'q1_2028', 22, 6.70, 78.00, 'low', 'sourcing', 'Biochem lab consolidation'),
  ('KIMS Hospitals', 13, 'monitoring', 'q2_2027', 45, 7.40, 85.00, 'medium', 'approved', 'OT + ICU monitor uplift'),
  ('KIMS Hospitals', 13, 'dental', 'q4_2027', 8, 9.10, 28.00, 'low', 'budgeting', 'Dental wing refresh'),
  ('Aster DM Healthcare', 17, 'surgical', 'q1_2027', 10, 8.20, 260.00, 'high', 'approved', 'C-arm + OR lights bundle'),
  ('Aster DM Healthcare', 17, 'life_support', 'q2_2028', 25, 7.90, 195.00, 'medium', 'deferred', 'Anaesthesia workstations'),
  ('Rainbow Children', 8, 'monitoring', 'q3_2027', 28, 6.80, 62.00, 'medium', 'sourcing', 'NICU multipara monitors'),
  ('Sankara Eye Network', 21, 'diagnostic', 'q1_2027', 35, 8.40, 105.00, 'high', 'approved', 'OCT + autorefractor wave'),
  ('Sankara Eye Network', 21, 'surgical', 'q4_2027', 12, 10.20, 220.00, 'critical', 'pending_board', 'Phaco machines EoL'),
  ('CARE Hospitals', 15, 'imaging', 'q2_2027', 7, 9.60, 340.00, 'critical', 'budgeting', 'Cathlab modernization'),
  ('CARE Hospitals', 15, 'laboratory', 'q3_2027', 19, 7.10, 88.00, 'medium', 'sourcing', 'Microbiology automation');

-- =========================================================
-- TABLE 2: chain_replacement_funding_plan_r2935
-- =========================================================
CREATE TABLE IF NOT EXISTS chain_replacement_funding_plan_r2935 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  fiscal_quarter text NOT NULL CHECK (fiscal_quarter IN ('q1_2027','q2_2027','q3_2027','q4_2027','q1_2028','q2_2028')),
  funding_source text NOT NULL CHECK (funding_source IN ('internal_capex','bank_loan','vendor_finance','equipseva_amc_credit','government_grant','lease_back')),
  amount_lakh numeric(10,2) NOT NULL CHECK (amount_lakh >= 0),
  approval_state text NOT NULL CHECK (approval_state IN ('approved','submitted','draft','rejected','on_hold')),
  expected_disbursal_date date NOT NULL,
  decision_owner text NOT NULL,
  risk_flag text NOT NULL CHECK (risk_flag IN ('green','amber','red')),
  remarks text
);

ALTER TABLE chain_replacement_funding_plan_r2935 ENABLE ROW LEVEL SECURITY;

INSERT INTO chain_replacement_funding_plan_r2935
  (chain_name, fiscal_quarter, funding_source, amount_lakh, approval_state, expected_disbursal_date, decision_owner, risk_flag, remarks)
VALUES
  ('Apollo MedChain', 'q1_2027', 'internal_capex', 480.00, 'approved', '2027-02-15'::date, 'CFO Apollo', 'green', 'Board ratified Q4 FY26'),
  ('Apollo MedChain', 'q2_2027', 'bank_loan', 220.00, 'submitted', '2027-05-20'::date, 'HDFC RM', 'amber', 'Term sheet under review'),
  ('Fortis NetCare', 'q1_2027', 'vendor_finance', 165.00, 'approved', '2027-01-30'::date, 'GE Healthcare CapEq', 'green', '36-mo lease'),
  ('Fortis NetCare', 'q3_2027', 'internal_capex', 90.00, 'draft', '2027-08-10'::date, 'CFO Fortis', 'amber', 'Q1 FY27 board agenda'),
  ('Manipal HealthGroup', 'q2_2027', 'equipseva_amc_credit', 145.00, 'approved', '2027-04-25'::date, 'EquipSeva PSM', 'green', 'AMC credit pool drawdown'),
  ('Manipal HealthGroup', 'q4_2027', 'bank_loan', 720.00, 'on_hold', '2027-11-15'::date, 'SBI Health desk', 'red', 'Awaiting MRI vendor RFP'),
  ('Max Healthcare', 'q1_2027', 'internal_capex', 95.00, 'approved', '2027-03-05'::date, 'CFO Max', 'green', 'Lab automation tranche'),
  ('Max Healthcare', 'q3_2027', 'lease_back', 380.00, 'submitted', '2027-09-12'::date, 'Tata Capital', 'amber', 'Robot platform sale-leaseback'),
  ('Narayana Health', 'q2_2027', 'government_grant', 42.00, 'submitted', '2027-06-18'::date, 'KA Health Mission', 'amber', 'PMJAY linked'),
  ('Narayana Health', 'q1_2028', 'vendor_finance', 120.00, 'draft', '2028-02-22'::date, 'Mindray IN', 'amber', 'Bundled telemetry'),
  ('AIIMS-Affiliated', 'q2_2028', 'government_grant', 560.00, 'on_hold', '2028-05-30'::date, 'MoHFW Capital', 'red', 'Linac CapEx unblocked'),
  ('AIIMS-Affiliated', 'q3_2027', 'internal_capex', 140.00, 'approved', '2027-07-20'::date, 'AIIMS Dean', 'green', 'Emergency wing'),
  ('Kauvery Hospitals', 'q1_2027', 'bank_loan', 68.00, 'approved', '2027-02-08'::date, 'ICICI RM', 'green', 'Tier-2 expansion line'),
  ('Kauvery Hospitals', 'q4_2027', 'vendor_finance', 175.00, 'submitted', '2027-10-30'::date, 'Karl Storz IN', 'amber', 'Laparoscopy stack'),
  ('Yashoda Group', 'q3_2027', 'internal_capex', 410.00, 'submitted', '2027-08-25'::date, 'CFO Yashoda', 'amber', 'CT slice upgrade'),
  ('Yashoda Group', 'q1_2028', 'equipseva_amc_credit', 78.00, 'draft', '2028-01-15'::date, 'EquipSeva PSM', 'green', 'Pool credit available'),
  ('KIMS Hospitals', 'q2_2027', 'internal_capex', 85.00, 'approved', '2027-05-05'::date, 'CFO KIMS', 'green', 'Routine monitor refresh'),
  ('KIMS Hospitals', 'q4_2027', 'lease_back', 28.00, 'rejected', '2027-12-10'::date, 'Tata Capital', 'red', 'Ticket size too small'),
  ('Aster DM Healthcare', 'q1_2027', 'internal_capex', 260.00, 'approved', '2027-03-22'::date, 'CFO Aster', 'green', 'Surgical bundle'),
  ('Aster DM Healthcare', 'q2_2028', 'bank_loan', 195.00, 'on_hold', '2028-06-05'::date, 'Axis Bank', 'red', 'Anaesthesia deferred 2 quarters'),
  ('Rainbow Children', 'q3_2027', 'vendor_finance', 62.00, 'approved', '2027-07-30'::date, 'Drager IN', 'green', 'NICU lease'),
  ('Sankara Eye Network', 'q1_2027', 'equipseva_amc_credit', 105.00, 'approved', '2027-02-28'::date, 'EquipSeva PSM', 'green', 'OCT bundle via AMC pool'),
  ('Sankara Eye Network', 'q4_2027', 'government_grant', 220.00, 'submitted', '2027-11-18'::date, 'TN Health Mission', 'amber', 'Phaco grant under DBT'),
  ('CARE Hospitals', 'q2_2027', 'bank_loan', 340.00, 'approved', '2027-04-12'::date, 'Kotak Bank', 'green', 'Cathlab tranche-1');

-- =========================================================
-- RPCs (7) — all SECURITY DEFINER, is_founder() gated
-- =========================================================

CREATE OR REPLACE FUNCTION r2935_chainwide_quarter_summary()
RETURNS TABLE(chain_name text, total_units int, total_cost_lakh numeric, critical_units int, approved_funding_lakh numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT f.chain_name,
         SUM(f.units_due)::int,
         ROUND(SUM(f.est_replacement_cost_lakh)::numeric, 2),
         (COUNT(*) FILTER (WHERE f.urgency_tier = 'critical'))::int,
         COALESCE((SELECT ROUND(SUM(p.amount_lakh)::numeric,2) FROM chain_replacement_funding_plan_r2935 p
                   WHERE p.chain_name = f.chain_name AND p.approval_state = 'approved'), 0)
  FROM chain_equipment_lifecycle_forecast_r2935 f
  GROUP BY f.chain_name
  ORDER BY SUM(f.est_replacement_cost_lakh) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION r2935_chainwide_quarter_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2935_chainwide_quarter_summary() TO authenticated;


CREATE OR REPLACE FUNCTION r2935_quarter_urgency_distribution()
RETURNS TABLE(forecast_quarter text, critical_count int, high_count int, medium_count int, low_count int, watch_count int, total_cost_lakh numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT f.forecast_quarter,
         (COUNT(*) FILTER (WHERE f.urgency_tier = 'critical'))::int,
         (COUNT(*) FILTER (WHERE f.urgency_tier = 'high'))::int,
         (COUNT(*) FILTER (WHERE f.urgency_tier = 'medium'))::int,
         (COUNT(*) FILTER (WHERE f.urgency_tier = 'low'))::int,
         (COUNT(*) FILTER (WHERE f.urgency_tier = 'watch'))::int,
         ROUND(SUM(f.est_replacement_cost_lakh)::numeric, 2)
  FROM chain_equipment_lifecycle_forecast_r2935 f
  GROUP BY f.forecast_quarter
  ORDER BY f.forecast_quarter;
END $$;

REVOKE EXECUTE ON FUNCTION r2935_quarter_urgency_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2935_quarter_urgency_distribution() TO authenticated;


CREATE OR REPLACE FUNCTION r2935_category_cost_breakdown()
RETURNS TABLE(equipment_category text, line_items int, total_units int, total_cost_lakh numeric, avg_age numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT f.equipment_category,
         COUNT(*)::int,
         SUM(f.units_due)::int,
         ROUND(SUM(f.est_replacement_cost_lakh)::numeric, 2),
         ROUND(AVG(f.avg_age_years)::numeric, 2)
  FROM chain_equipment_lifecycle_forecast_r2935 f
  GROUP BY f.equipment_category
  ORDER BY SUM(f.est_replacement_cost_lakh) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION r2935_category_cost_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2935_category_cost_breakdown() TO authenticated;


CREATE OR REPLACE FUNCTION r2935_funding_source_mix()
RETURNS TABLE(funding_source text, entries int, total_lakh numeric, approved_lakh numeric, red_flag_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT p.funding_source,
         COUNT(*)::int,
         ROUND(SUM(p.amount_lakh)::numeric, 2),
         ROUND(SUM(p.amount_lakh) FILTER (WHERE p.approval_state = 'approved')::numeric, 2),
         (COUNT(*) FILTER (WHERE p.risk_flag = 'red'))::int
  FROM chain_replacement_funding_plan_r2935 p
  GROUP BY p.funding_source
  ORDER BY SUM(p.amount_lakh) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION r2935_funding_source_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2935_funding_source_mix() TO authenticated;


CREATE OR REPLACE FUNCTION r2935_critical_unfunded_gaps()
RETURNS TABLE(chain_name text, equipment_category text, forecast_quarter text, units_due int, replacement_cost_lakh numeric, funding_status text, notes text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT f.chain_name, f.equipment_category, f.forecast_quarter, f.units_due,
         f.est_replacement_cost_lakh, f.funding_status, f.notes
  FROM chain_equipment_lifecycle_forecast_r2935 f
  WHERE f.urgency_tier = 'critical'
    AND f.funding_status IN ('pending_board','budgeting','sourcing','deferred')
  ORDER BY f.est_replacement_cost_lakh DESC;
END $$;

REVOKE EXECUTE ON FUNCTION r2935_critical_unfunded_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2935_critical_unfunded_gaps() TO authenticated;


CREATE OR REPLACE FUNCTION r2935_red_flag_funding_lines()
RETURNS TABLE(chain_name text, fiscal_quarter text, funding_source text, amount_lakh numeric, approval_state text, expected_disbursal_date date, decision_owner text, remarks text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT p.chain_name, p.fiscal_quarter, p.funding_source, p.amount_lakh,
         p.approval_state, p.expected_disbursal_date, p.decision_owner, p.remarks
  FROM chain_replacement_funding_plan_r2935 p
  WHERE p.risk_flag = 'red' OR p.approval_state IN ('rejected','on_hold')
  ORDER BY p.amount_lakh DESC;
END $$;

REVOKE EXECUTE ON FUNCTION r2935_red_flag_funding_lines() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2935_red_flag_funding_lines() TO authenticated;


CREATE OR REPLACE FUNCTION r2935_equipseva_credit_opportunity()
RETURNS TABLE(chain_name text, current_amc_credit_lakh numeric, forecast_total_lakh numeric, gap_lakh numeric, recommended_action text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT f.chain_name,
         COALESCE((SELECT ROUND(SUM(p.amount_lakh)::numeric,2) FROM chain_replacement_funding_plan_r2935 p
                   WHERE p.chain_name = f.chain_name AND p.funding_source = 'equipseva_amc_credit'), 0) AS current_credit,
         ROUND(SUM(f.est_replacement_cost_lakh)::numeric, 2) AS forecast_total,
         ROUND((SUM(f.est_replacement_cost_lakh) -
            COALESCE((SELECT SUM(p.amount_lakh) FROM chain_replacement_funding_plan_r2935 p
                      WHERE p.chain_name = f.chain_name AND p.funding_source = 'equipseva_amc_credit'), 0))::numeric, 2) AS gap,
         CASE
           WHEN SUM(f.est_replacement_cost_lakh) > 500 THEN 'pitch strategic AMC pool expansion'
           WHEN SUM(f.est_replacement_cost_lakh) > 200 THEN 'offer tiered AMC credit line'
           ELSE 'standard AMC renewal'
         END
  FROM chain_equipment_lifecycle_forecast_r2935 f
  GROUP BY f.chain_name
  ORDER BY SUM(f.est_replacement_cost_lakh) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION r2935_equipseva_credit_opportunity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2935_equipseva_credit_opportunity() TO authenticated;
