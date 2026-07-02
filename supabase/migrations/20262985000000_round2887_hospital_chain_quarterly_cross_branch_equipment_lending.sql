-- Round 2887 — Hospital Chain Quarterly Cross-Branch Equipment Lending Ledger
-- Multi-branch hospital chains lend equipment between branches; founder needs
-- visibility into utilization, settlement, depreciation, chargeback risk.

BEGIN;

-- ============================================================
-- Table 1: lending transactions between branches
-- ============================================================
CREATE TABLE IF NOT EXISTS hospital_chain_branch_lending_txn_r2887 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_code text NOT NULL,
  lender_branch_code text NOT NULL,
  borrower_branch_code text NOT NULL,
  equipment_category text NOT NULL,
  equipment_serial text NOT NULL,
  lent_at timestamptz NOT NULL,
  expected_return_at timestamptz NOT NULL,
  actual_return_at timestamptz,
  daily_rental_rupees integer NOT NULL,
  total_billed_rupees integer NOT NULL DEFAULT 0,
  settlement_status text NOT NULL DEFAULT 'pending',
  condition_on_return text,
  damage_chargeback_rupees integer NOT NULL DEFAULT 0,
  quarter text NOT NULL,
  notes text
);

ALTER TABLE hospital_chain_branch_lending_txn_r2887 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Table 2: branch utilization rollup per quarter
-- ============================================================
CREATE TABLE IF NOT EXISTS hospital_chain_branch_quarter_rollup_r2887 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_code text NOT NULL,
  branch_code text NOT NULL,
  branch_city text NOT NULL,
  quarter text NOT NULL,
  equipment_owned integer NOT NULL DEFAULT 0,
  equipment_lent_out_days integer NOT NULL DEFAULT 0,
  equipment_borrowed_days integer NOT NULL DEFAULT 0,
  net_rental_income_rupees integer NOT NULL DEFAULT 0,
  net_rental_expense_rupees integer NOT NULL DEFAULT 0,
  utilization_pct numeric(5,2) NOT NULL DEFAULT 0,
  downtime_avoided_hours integer NOT NULL DEFAULT 0,
  capex_deferred_rupees integer NOT NULL DEFAULT 0,
  disputes_open integer NOT NULL DEFAULT 0
);

ALTER TABLE hospital_chain_branch_quarter_rollup_r2887 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Seed: lending transactions (18 rows)
-- ============================================================
INSERT INTO hospital_chain_branch_lending_txn_r2887
  (chain_code, lender_branch_code, borrower_branch_code, equipment_category, equipment_serial,
   lent_at, expected_return_at, actual_return_at, daily_rental_rupees, total_billed_rupees,
   settlement_status, condition_on_return, damage_chargeback_rupees, quarter, notes)
VALUES
  ('APOLLO',   'HYD-JUB',  'HYD-SEC',  'Ventilator',         'VNT-AP-2201', now()-interval '88 days', now()-interval '74 days', now()-interval '73 days',  2500,  37500, 'settled',     'good',      0,    'Q2-2026', 'ICU overflow Apr surge'),
  ('APOLLO',   'HYD-JUB',  'BLR-BAN',  'CT Scanner Module',  'CTM-AP-1108', now()-interval '76 days', now()-interval '62 days', now()-interval '60 days',  8000, 128000, 'settled',     'good',      0,    'Q2-2026', 'BLR machine down 16d'),
  ('APOLLO',   'CHN-OMR',  'HYD-JUB',  'Defibrillator',      'DFB-AP-9912', now()-interval '70 days', now()-interval '56 days', now()-interval '55 days',  1200,  18000, 'settled',     'good',      0,    'Q2-2026', NULL),
  ('APOLLO',   'BLR-BAN',  'CHN-OMR',  'Anesthesia Machine', 'ANS-AP-4421', now()-interval '64 days', now()-interval '50 days', now()-interval '46 days',  4500,  81000, 'disputed',    'minor_dent', 12000, 'Q2-2026', 'Chargeback contested by borrower'),
  ('FORTIS',   'DEL-VKT',  'MUM-MUL',  'Ultrasound Cart',    'USC-FT-3301', now()-interval '60 days', now()-interval '46 days', now()-interval '45 days',  3000,  45000, 'settled',     'good',      0,    'Q2-2026', NULL),
  ('FORTIS',   'MUM-MUL',  'DEL-VKT',  'Dialysis Machine',   'DLY-FT-2207', now()-interval '54 days', now()-interval '40 days', now()-interval '38 days',  3500,  56000, 'settled',     'good',      0,    'Q2-2026', 'Reciprocal lend'),
  ('FORTIS',   'BLR-CUN',  'MUM-MUL',  'Infusion Pump Bank', 'IPB-FT-7782', now()-interval '50 days', now()-interval '36 days', now()-interval '36 days',  1800,  25200, 'settled',     'good',      0,    'Q2-2026', NULL),
  ('FORTIS',   'DEL-VKT',  'BLR-CUN',  'C-Arm',              'CRM-FT-5519', now()-interval '46 days', now()-interval '32 days', NULL,                      5500,  77000, 'overdue',     NULL,         0,    'Q2-2026', 'Borrower extended w/o approval'),
  ('MAX',      'DEL-SAK',  'DEL-PAT',  'ECG Machine',        'ECG-MX-1102', now()-interval '42 days', now()-interval '35 days', now()-interval '35 days',   800,   5600, 'settled',     'good',      0,    'Q2-2026', NULL),
  ('MAX',      'DEL-PAT',  'DEL-SAK',  'Patient Monitor',    'PMN-MX-6634', now()-interval '38 days', now()-interval '28 days', now()-interval '27 days',  1500,  16500, 'settled',     'good',      0,    'Q2-2026', NULL),
  ('MAX',      'DEL-SAK',  'GGN-CYB',  'Surgical Microscope','SRM-MX-8801', now()-interval '34 days', now()-interval '20 days', now()-interval '18 days',  7000, 112000, 'settled',     'good',      0,    'Q2-2026', 'Neurosurg scheduled cluster'),
  ('NARAYANA', 'BLR-HSR',  'BLR-BOM',  'Cath Lab Console',   'CLC-NR-2298', now()-interval '30 days', now()-interval '16 days', now()-interval '15 days', 12000, 180000, 'settled',     'good',      0,    'Q2-2026', 'Highest-value lend Q2'),
  ('NARAYANA', 'BLR-BOM',  'AHM-SAT',  'Bone Saw',           'BSW-NR-3318', now()-interval '26 days', now()-interval '19 days', now()-interval '20 days',   900,   6300, 'settled',     'minor_wear', 0,    'Q2-2026', NULL),
  ('NARAYANA', 'BLR-HSR',  'KOL-MUK',  'Heart-Lung Machine', 'HLM-NR-0091', now()-interval '22 days', now()-interval '8 days',  NULL,                      9500, 133000, 'pending',     NULL,         0,    'Q2-2026', 'Settlement pending end of qtr'),
  ('AIIMS',    'DEL-AII',  'BPL-AII',  'MRI Coil Set',       'MRC-AI-7762', now()-interval '18 days', now()-interval '11 days', now()-interval '10 days',  6000,  48000, 'settled',     'good',      0,    'Q2-2026', 'Inter-AIIMS govt protocol'),
  ('AIIMS',    'BPL-AII',  'RBL-AII',  'Phototherapy Unit',  'PTU-AI-3341', now()-interval '14 days', now()-interval '7 days',  now()-interval '6 days',   400,   3200, 'settled',     'good',      0,    'Q2-2026', NULL),
  ('AIIMS',    'DEL-AII',  'JDH-AII',  'Endoscopy Tower',    'EDT-AI-9928', now()-interval '10 days', now()-interval '3 days',  NULL,                      4200,  29400, 'overdue',     NULL,         0,    'Q2-2026', NULL),
  ('MANIPAL',  'BLR-OLD',  'BLR-WHT',  'Linear Accelerator', 'LAC-MN-0002', now()-interval '8 days',  now()+interval '6 days',  NULL,                     15000, 120000, 'in_progress', NULL,         0,    'Q2-2026', 'Onco scheduling overflow');

-- ============================================================
-- Seed: branch quarter rollup (14 rows)
-- ============================================================
INSERT INTO hospital_chain_branch_quarter_rollup_r2887
  (chain_code, branch_code, branch_city, quarter, equipment_owned, equipment_lent_out_days,
   equipment_borrowed_days, net_rental_income_rupees, net_rental_expense_rupees,
   utilization_pct, downtime_avoided_hours, capex_deferred_rupees, disputes_open)
VALUES
  ('APOLLO',   'HYD-JUB', 'Hyderabad',  'Q2-2026', 248, 28, 14,  165500,  37500, 87.40, 312, 4800000, 0),
  ('APOLLO',   'HYD-SEC', 'Hyderabad',  'Q2-2026', 142,  0, 14,       0,  37500, 78.20, 168, 1200000, 0),
  ('APOLLO',   'BLR-BAN', 'Bengaluru',  'Q2-2026', 196, 14, 14,   81000, 128000, 82.10, 264, 3600000, 0),
  ('APOLLO',   'CHN-OMR', 'Chennai',    'Q2-2026', 174, 14, 14,   18000,  81000, 79.60, 196,  900000, 1),
  ('FORTIS',   'DEL-VKT', 'Delhi',      'Q2-2026', 218, 28,  0,  101000,      0, 91.20, 288, 2400000, 1),
  ('FORTIS',   'MUM-MUL', 'Mumbai',     'Q2-2026', 232, 14, 28,   56000,  70200, 88.90, 224, 2100000, 0),
  ('FORTIS',   'BLR-CUN', 'Bengaluru',  'Q2-2026', 158, 14, 14,   25200,  77000, 76.40, 142,  800000, 0),
  ('MAX',      'DEL-SAK', 'Delhi',      'Q2-2026', 184,  7, 24,    5600, 128500, 84.30, 198, 1500000, 0),
  ('MAX',      'DEL-PAT', 'Delhi',      'Q2-2026', 126, 10,  7,   16500,   5600, 81.10, 132,  700000, 0),
  ('NARAYANA', 'BLR-HSR', 'Bengaluru',  'Q2-2026', 312, 28,  0,  313000,      0, 92.80, 384, 6200000, 0),
  ('NARAYANA', 'BLR-BOM', 'Bengaluru',  'Q2-2026', 168,  7, 14,    6300, 180000, 85.20, 168, 1800000, 0),
  ('AIIMS',    'DEL-AII', 'Delhi',      'Q2-2026', 412, 14,  0,   77400,      0, 88.10, 224,       0, 0),
  ('AIIMS',    'BPL-AII', 'Bhopal',     'Q2-2026', 184,  7,  7,    3200,  48000, 74.80, 112,       0, 0),
  ('MANIPAL',  'BLR-WHT', 'Bengaluru',  'Q2-2026', 246,  0,  8,       0, 120000, 86.40, 112, 1100000, 0);

-- ============================================================
-- RPC 1: KPI summary
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2887_kpi_summary()
RETURNS TABLE (
  total_lends integer,
  total_billed_rupees bigint,
  pending_settlement_rupees bigint,
  overdue_count integer,
  disputed_count integer,
  capex_deferred_rupees bigint,
  avg_utilization_pct numeric,
  chains_active integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM hospital_chain_branch_lending_txn_r2887),
    (SELECT COALESCE(SUM(total_billed_rupees),0)::bigint FROM hospital_chain_branch_lending_txn_r2887),
    (SELECT COALESCE(SUM(total_billed_rupees),0)::bigint FROM hospital_chain_branch_lending_txn_r2887 WHERE settlement_status IN ('pending','in_progress','overdue')),
    (SELECT COUNT(*)::int FROM hospital_chain_branch_lending_txn_r2887 WHERE settlement_status = 'overdue'),
    (SELECT COUNT(*)::int FROM hospital_chain_branch_lending_txn_r2887 WHERE settlement_status = 'disputed'),
    (SELECT COALESCE(SUM(capex_deferred_rupees),0)::bigint FROM hospital_chain_branch_quarter_rollup_r2887),
    (SELECT COALESCE(AVG(utilization_pct),0)::numeric FROM hospital_chain_branch_quarter_rollup_r2887),
    (SELECT COUNT(DISTINCT chain_code)::int FROM hospital_chain_branch_lending_txn_r2887);
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2887_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2887_kpi_summary() TO authenticated;

-- ============================================================
-- RPC 2: chain-level rollup
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2887_chain_rollup()
RETURNS TABLE (
  chain_code text,
  branches integer,
  total_lends integer,
  gross_billed_rupees bigint,
  avg_util_pct numeric,
  capex_deferred_rupees bigint,
  disputes_open integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT
    t.chain_code,
    (SELECT COUNT(DISTINCT branch_code)::int FROM hospital_chain_branch_quarter_rollup_r2887 r WHERE r.chain_code = t.chain_code),
    COUNT(*)::int,
    COALESCE(SUM(t.total_billed_rupees),0)::bigint,
    COALESCE((SELECT AVG(utilization_pct) FROM hospital_chain_branch_quarter_rollup_r2887 r WHERE r.chain_code = t.chain_code),0)::numeric,
    COALESCE((SELECT SUM(capex_deferred_rupees) FROM hospital_chain_branch_quarter_rollup_r2887 r WHERE r.chain_code = t.chain_code),0)::bigint,
    COALESCE((SELECT SUM(disputes_open) FROM hospital_chain_branch_quarter_rollup_r2887 r WHERE r.chain_code = t.chain_code),0)::int
  FROM hospital_chain_branch_lending_txn_r2887 t
  GROUP BY t.chain_code
  ORDER BY gross_billed_rupees DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2887_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2887_chain_rollup() TO authenticated;

-- ============================================================
-- RPC 3: branch leaderboard
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2887_branch_leaderboard()
RETURNS TABLE (
  chain_code text,
  branch_code text,
  branch_city text,
  utilization_pct numeric,
  net_rental_income_rupees integer,
  net_rental_expense_rupees integer,
  net_position_rupees integer,
  capex_deferred_rupees integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT
    r.chain_code, r.branch_code, r.branch_city,
    r.utilization_pct, r.net_rental_income_rupees, r.net_rental_expense_rupees,
    (r.net_rental_income_rupees - r.net_rental_expense_rupees),
    r.capex_deferred_rupees
  FROM hospital_chain_branch_quarter_rollup_r2887 r
  ORDER BY (r.net_rental_income_rupees - r.net_rental_expense_rupees) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2887_branch_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2887_branch_leaderboard() TO authenticated;

-- ============================================================
-- RPC 4: overdue + disputed risk queue
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2887_risk_queue()
RETURNS TABLE (
  id uuid,
  chain_code text,
  lender_branch_code text,
  borrower_branch_code text,
  equipment_category text,
  settlement_status text,
  expected_return_at timestamptz,
  days_overdue integer,
  total_billed_rupees integer,
  damage_chargeback_rupees integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT
    t.id, t.chain_code, t.lender_branch_code, t.borrower_branch_code,
    t.equipment_category, t.settlement_status, t.expected_return_at,
    GREATEST(0, EXTRACT(day FROM now() - t.expected_return_at)::int),
    t.total_billed_rupees, t.damage_chargeback_rupees
  FROM hospital_chain_branch_lending_txn_r2887 t
  WHERE t.settlement_status IN ('overdue','disputed','pending','in_progress')
  ORDER BY t.expected_return_at ASC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2887_risk_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2887_risk_queue() TO authenticated;

-- ============================================================
-- RPC 5: equipment category mix
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2887_category_mix()
RETURNS TABLE (
  equipment_category text,
  lend_count integer,
  total_billed_rupees bigint,
  avg_daily_rate numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT
    t.equipment_category,
    COUNT(*)::int,
    COALESCE(SUM(t.total_billed_rupees),0)::bigint,
    COALESCE(AVG(t.daily_rental_rupees),0)::numeric
  FROM hospital_chain_branch_lending_txn_r2887 t
  GROUP BY t.equipment_category
  ORDER BY total_billed_rupees DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2887_category_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2887_category_mix() TO authenticated;

-- ============================================================
-- RPC 6: recent lending ledger (full detail)
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2887_recent_ledger()
RETURNS TABLE (
  id uuid,
  chain_code text,
  lender_branch_code text,
  borrower_branch_code text,
  equipment_category text,
  equipment_serial text,
  lent_at timestamptz,
  expected_return_at timestamptz,
  actual_return_at timestamptz,
  daily_rental_rupees integer,
  total_billed_rupees integer,
  settlement_status text,
  damage_chargeback_rupees integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT
    t.id, t.chain_code, t.lender_branch_code, t.borrower_branch_code,
    t.equipment_category, t.equipment_serial, t.lent_at, t.expected_return_at,
    t.actual_return_at, t.daily_rental_rupees, t.total_billed_rupees,
    t.settlement_status, t.damage_chargeback_rupees
  FROM hospital_chain_branch_lending_txn_r2887 t
  ORDER BY t.lent_at DESC
  LIMIT 50;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2887_recent_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2887_recent_ledger() TO authenticated;

-- ============================================================
-- RPC 7: cross-branch reciprocity score (net give-vs-take)
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2887_reciprocity_score()
RETURNS TABLE (
  branch_code text,
  chain_code text,
  lends_given integer,
  lends_received integer,
  reciprocity_ratio numeric,
  net_position_rupees integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT
    r.branch_code,
    r.chain_code,
    (SELECT COUNT(*)::int FROM hospital_chain_branch_lending_txn_r2887 t WHERE t.lender_branch_code = r.branch_code),
    (SELECT COUNT(*)::int FROM hospital_chain_branch_lending_txn_r2887 t WHERE t.borrower_branch_code = r.branch_code),
    CASE
      WHEN (SELECT COUNT(*) FROM hospital_chain_branch_lending_txn_r2887 t WHERE t.borrower_branch_code = r.branch_code) = 0 THEN 0
      ELSE ROUND(
        (SELECT COUNT(*)::numeric FROM hospital_chain_branch_lending_txn_r2887 t WHERE t.lender_branch_code = r.branch_code)
        / NULLIF((SELECT COUNT(*) FROM hospital_chain_branch_lending_txn_r2887 t WHERE t.borrower_branch_code = r.branch_code), 0),
      2)
    END,
    (r.net_rental_income_rupees - r.net_rental_expense_rupees)
  FROM hospital_chain_branch_quarter_rollup_r2887 r
  ORDER BY net_position_rupees DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2887_reciprocity_score() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2887_reciprocity_score() TO authenticated;

COMMIT;
