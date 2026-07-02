-- Round 2940: Customer Monthly Engineer Bilateral-Loaner Equipment Tracking & Return Discipline
-- Founder console: track loaner equipment issued bilaterally between customers and engineers,
-- with monthly return discipline metrics.

-- =========================================================================
-- TABLE 1: loaner_issuance_r2940
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.loaner_issuance_r2940 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  issuance_month date NOT NULL,
  customer_org_name text NOT NULL,
  engineer_code text NOT NULL,
  equipment_model text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','monitoring','surgical','dental','lab','rehab')),
  issued_at timestamptz NOT NULL,
  expected_return_at timestamptz NOT NULL,
  actual_return_at timestamptz,
  return_status text NOT NULL CHECK (return_status IN ('on_time','late','overdue','open','damaged','lost')),
  loaner_value_rupees integer NOT NULL CHECK (loaner_value_rupees >= 0),
  deposit_rupees integer NOT NULL DEFAULT 0 CHECK (deposit_rupees >= 0),
  bilateral_agreement_signed boolean NOT NULL DEFAULT false,
  city text NOT NULL,
  state text NOT NULL,
  notes text
);

ALTER TABLE public.loaner_issuance_r2940 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- TABLE 2: loaner_return_discipline_r2940
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.loaner_return_discipline_r2940 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  issuance_id uuid REFERENCES public.loaner_issuance_r2940(id) ON DELETE CASCADE,
  review_month date NOT NULL,
  discipline_tier text NOT NULL CHECK (discipline_tier IN ('gold','silver','bronze','watchlist','blacklist')),
  days_overdue integer NOT NULL DEFAULT 0,
  penalty_rupees integer NOT NULL DEFAULT 0 CHECK (penalty_rupees >= 0),
  recovery_action text NOT NULL CHECK (recovery_action IN ('none','reminder','escalation','legal_notice','recovered','written_off')),
  customer_org_name text NOT NULL,
  engineer_code text NOT NULL,
  resolved boolean NOT NULL DEFAULT false,
  resolved_at timestamptz,
  founder_flag text NOT NULL DEFAULT 'normal' CHECK (founder_flag IN ('normal','review','urgent','board_pack'))
);

ALTER TABLE public.loaner_return_discipline_r2940 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- SEED: loaner_issuance_r2940 (20 rows)
-- =========================================================================
INSERT INTO public.loaner_issuance_r2940
  (issuance_month, customer_org_name, engineer_code, equipment_model, equipment_category,
   issued_at, expected_return_at, actual_return_at, return_status,
   loaner_value_rupees, deposit_rupees, bilateral_agreement_signed, city, state, notes)
VALUES
  ('2026-06-01'::date, 'Apollo Jubilee Hills', 'ENG-HYD-001', 'Philips IntelliVue MX450', 'monitoring', '2026-06-02 09:30:00+05:30'::timestamptz, '2026-06-09 09:30:00+05:30'::timestamptz, '2026-06-09 08:15:00+05:30'::timestamptz, 'on_time', 480000, 50000, true, 'Hyderabad', 'TS', 'returned early'),
  ('2026-06-01'::date, 'KIMS Secunderabad', 'ENG-HYD-002', 'GE Logiq P9 ultrasound', 'imaging', '2026-06-03 11:00:00+05:30'::timestamptz, '2026-06-10 11:00:00+05:30'::timestamptz, '2026-06-12 14:20:00+05:30'::timestamptz, 'late', 1250000, 100000, true, 'Hyderabad', 'TS', '2 days late'),
  ('2026-06-01'::date, 'Yashoda Somajiguda', 'ENG-HYD-003', 'Mindray BeneVision N17', 'monitoring', '2026-06-04 10:00:00+05:30'::timestamptz, '2026-06-11 10:00:00+05:30'::timestamptz, NULL, 'overdue', 620000, 60000, true, 'Hyderabad', 'TS', 'no response 4 days'),
  ('2026-06-01'::date, 'Sunshine Begumpet', 'ENG-HYD-004', 'Stryker SDC3 endoscopy cart', 'surgical', '2026-06-05 08:45:00+05:30'::timestamptz, '2026-06-12 08:45:00+05:30'::timestamptz, '2026-06-12 09:10:00+05:30'::timestamptz, 'on_time', 1850000, 150000, true, 'Hyderabad', 'TS', NULL),
  ('2026-06-01'::date, 'Care Banjara Hills', 'ENG-HYD-005', 'Dentsply X-Smart Plus endo motor', 'dental', '2026-06-06 13:00:00+05:30'::timestamptz, '2026-06-13 13:00:00+05:30'::timestamptz, '2026-06-13 12:00:00+05:30'::timestamptz, 'on_time', 95000, 10000, true, 'Hyderabad', 'TS', NULL),
  ('2026-06-01'::date, 'Continental Gachibowli', 'ENG-HYD-006', 'Roche Cobas c311 analyzer', 'lab', '2026-06-07 15:30:00+05:30'::timestamptz, '2026-06-14 15:30:00+05:30'::timestamptz, NULL, 'open', 2200000, 200000, true, 'Hyderabad', 'TS', 'in service'),
  ('2026-05-01'::date, 'Manipal Bangalore', 'ENG-BLR-001', 'Philips Affiniti 50 ultrasound', 'imaging', '2026-05-08 10:00:00+05:30'::timestamptz, '2026-05-15 10:00:00+05:30'::timestamptz, '2026-05-15 09:00:00+05:30'::timestamptz, 'on_time', 980000, 80000, true, 'Bengaluru', 'KA', NULL),
  ('2026-05-01'::date, 'Fortis Bannerghatta', 'ENG-BLR-002', 'Drager Fabius GS premium', 'monitoring', '2026-05-10 09:00:00+05:30'::timestamptz, '2026-05-17 09:00:00+05:30'::timestamptz, '2026-05-19 11:00:00+05:30'::timestamptz, 'late', 1450000, 120000, true, 'Bengaluru', 'KA', 'replacement awaited'),
  ('2026-05-01'::date, 'Narayana Hrudayalaya', 'ENG-BLR-003', 'Karl Storz IMAGE1 S camera', 'surgical', '2026-05-12 14:00:00+05:30'::timestamptz, '2026-05-19 14:00:00+05:30'::timestamptz, NULL, 'lost', 2950000, 250000, true, 'Bengaluru', 'KA', 'lost in transit'),
  ('2026-05-01'::date, 'Aster CMI Hebbal', 'ENG-BLR-004', 'Mindray DC-70 ultrasound', 'imaging', '2026-05-14 11:30:00+05:30'::timestamptz, '2026-05-21 11:30:00+05:30'::timestamptz, '2026-05-22 16:00:00+05:30'::timestamptz, 'late', 1100000, 90000, true, 'Bengaluru', 'KA', NULL),
  ('2026-06-01'::date, 'Lilavati Bandra', 'ENG-MUM-001', 'GE Vivid E95 cardiac', 'imaging', '2026-06-08 09:00:00+05:30'::timestamptz, '2026-06-15 09:00:00+05:30'::timestamptz, NULL, 'open', 3200000, 300000, true, 'Mumbai', 'MH', 'cardiac dept'),
  ('2026-06-01'::date, 'Kokilaben DAH', 'ENG-MUM-002', 'Olympus CV-190 endoscopy', 'surgical', '2026-06-09 13:30:00+05:30'::timestamptz, '2026-06-16 13:30:00+05:30'::timestamptz, '2026-06-16 13:00:00+05:30'::timestamptz, 'on_time', 1750000, 150000, true, 'Mumbai', 'MH', NULL),
  ('2026-06-01'::date, 'Hinduja Mahim', 'ENG-MUM-003', 'Siemens ACUSON P500', 'imaging', '2026-06-10 10:00:00+05:30'::timestamptz, '2026-06-17 10:00:00+05:30'::timestamptz, '2026-06-19 09:00:00+05:30'::timestamptz, 'damaged', 1850000, 200000, true, 'Mumbai', 'MH', 'probe scratched'),
  ('2026-06-01'::date, 'Max Saket', 'ENG-DEL-001', 'Philips EPIQ 7 ultrasound', 'imaging', '2026-06-11 12:00:00+05:30'::timestamptz, '2026-06-18 12:00:00+05:30'::timestamptz, NULL, 'overdue', 2750000, 250000, true, 'Delhi', 'DL', 'overdue 3 days'),
  ('2026-06-01'::date, 'Medanta Gurgaon', 'ENG-DEL-002', 'Hill-Rom Centrella bed', 'rehab', '2026-06-12 14:30:00+05:30'::timestamptz, '2026-06-19 14:30:00+05:30'::timestamptz, '2026-06-19 14:00:00+05:30'::timestamptz, 'on_time', 580000, 50000, true, 'Gurgaon', 'HR', NULL),
  ('2026-06-01'::date, 'Fortis Escorts', 'ENG-DEL-003', 'GE MAC 5500 ECG', 'monitoring', '2026-06-13 09:30:00+05:30'::timestamptz, '2026-06-20 09:30:00+05:30'::timestamptz, '2026-06-20 09:00:00+05:30'::timestamptz, 'on_time', 240000, 25000, true, 'Delhi', 'DL', NULL),
  ('2026-05-01'::date, 'Apollo Chennai', 'ENG-CHN-001', 'Mindray ePM 12 monitor', 'monitoring', '2026-05-15 10:00:00+05:30'::timestamptz, '2026-05-22 10:00:00+05:30'::timestamptz, NULL, 'lost', 320000, 30000, false, 'Chennai', 'TN', 'no bilateral signed - dispute'),
  ('2026-05-01'::date, 'MIOT Chennai', 'ENG-CHN-002', 'Welch Allyn Spot Vital', 'monitoring', '2026-05-18 11:00:00+05:30'::timestamptz, '2026-05-25 11:00:00+05:30'::timestamptz, '2026-05-26 10:30:00+05:30'::timestamptz, 'late', 95000, 10000, true, 'Chennai', 'TN', NULL),
  ('2026-06-01'::date, 'AMRI Kolkata', 'ENG-KOL-001', 'Mortara X12+ telemetry', 'monitoring', '2026-06-14 13:00:00+05:30'::timestamptz, '2026-06-21 13:00:00+05:30'::timestamptz, NULL, 'open', 410000, 40000, true, 'Kolkata', 'WB', NULL),
  ('2026-06-01'::date, 'Ruby General Kolkata', 'ENG-KOL-002', 'Carestream DRX-Revolution', 'imaging', '2026-06-15 09:00:00+05:30'::timestamptz, '2026-06-22 09:00:00+05:30'::timestamptz, NULL, 'open', 4800000, 400000, true, 'Kolkata', 'WB', 'mobile X-ray');

-- =========================================================================
-- SEED: loaner_return_discipline_r2940 (18 rows)
-- =========================================================================
INSERT INTO public.loaner_return_discipline_r2940
  (review_month, discipline_tier, days_overdue, penalty_rupees, recovery_action,
   customer_org_name, engineer_code, resolved, resolved_at, founder_flag)
VALUES
  ('2026-06-01'::date, 'gold',     0,      0, 'none',         'Apollo Jubilee Hills', 'ENG-HYD-001', true,  '2026-06-09 08:30:00+05:30'::timestamptz, 'normal'),
  ('2026-06-01'::date, 'silver',   2,   5000, 'reminder',     'KIMS Secunderabad',     'ENG-HYD-002', true,  '2026-06-12 15:00:00+05:30'::timestamptz, 'normal'),
  ('2026-06-01'::date, 'bronze',   4,  25000, 'escalation',   'Yashoda Somajiguda',    'ENG-HYD-003', false, NULL, 'review'),
  ('2026-06-01'::date, 'gold',     0,      0, 'none',         'Sunshine Begumpet',     'ENG-HYD-004', true,  '2026-06-12 09:15:00+05:30'::timestamptz, 'normal'),
  ('2026-06-01'::date, 'gold',     0,      0, 'none',         'Care Banjara Hills',    'ENG-HYD-005', true,  '2026-06-13 12:10:00+05:30'::timestamptz, 'normal'),
  ('2026-05-01'::date, 'gold',     0,      0, 'none',         'Manipal Bangalore',     'ENG-BLR-001', true,  '2026-05-15 09:10:00+05:30'::timestamptz, 'normal'),
  ('2026-05-01'::date, 'silver',   2,   8000, 'reminder',     'Fortis Bannerghatta',   'ENG-BLR-002', true,  '2026-05-19 11:30:00+05:30'::timestamptz, 'normal'),
  ('2026-05-01'::date, 'blacklist',35, 295000, 'legal_notice', 'Narayana Hrudayalaya',  'ENG-BLR-003', false, NULL, 'board_pack'),
  ('2026-05-01'::date, 'silver',   1,   4000, 'reminder',     'Aster CMI Hebbal',      'ENG-BLR-004', true,  '2026-05-22 16:30:00+05:30'::timestamptz, 'normal'),
  ('2026-06-01'::date, 'gold',     0,      0, 'none',         'Kokilaben DAH',         'ENG-MUM-002', true,  '2026-06-16 13:30:00+05:30'::timestamptz, 'normal'),
  ('2026-06-01'::date, 'bronze',   2,  18000, 'escalation',   'Hinduja Mahim',         'ENG-MUM-003', false, NULL, 'urgent'),
  ('2026-06-01'::date, 'watchlist',3,  27500, 'escalation',   'Max Saket',             'ENG-DEL-001', false, NULL, 'urgent'),
  ('2026-06-01'::date, 'gold',     0,      0, 'none',         'Medanta Gurgaon',       'ENG-DEL-002', true,  '2026-06-19 14:10:00+05:30'::timestamptz, 'normal'),
  ('2026-06-01'::date, 'gold',     0,      0, 'none',         'Fortis Escorts',        'ENG-DEL-003', true,  '2026-06-20 09:10:00+05:30'::timestamptz, 'normal'),
  ('2026-05-01'::date, 'blacklist',30, 320000, 'written_off',  'Apollo Chennai',        'ENG-CHN-001', false, NULL, 'board_pack'),
  ('2026-05-01'::date, 'silver',   1,   3000, 'reminder',     'MIOT Chennai',          'ENG-CHN-002', true,  '2026-05-26 11:00:00+05:30'::timestamptz, 'normal'),
  ('2026-06-01'::date, 'watchlist',0,      0, 'none',         'AMRI Kolkata',          'ENG-KOL-001', false, NULL, 'review'),
  ('2026-06-01'::date, 'watchlist',0,      0, 'none',         'Ruby General Kolkata',  'ENG-KOL-002', false, NULL, 'review');

-- =========================================================================
-- RPCs (7) — all SECURITY DEFINER, is_founder gated
-- =========================================================================

-- RPC 1: monthly issuance summary
CREATE OR REPLACE FUNCTION public.r2940_monthly_issuance_summary()
RETURNS TABLE (
  issuance_month date,
  total_issued bigint,
  total_value_rupees bigint,
  on_time_returns bigint,
  late_returns bigint,
  overdue_open bigint,
  on_time_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.issuance_month,
    count(*)::bigint,
    coalesce(sum(l.loaner_value_rupees),0)::bigint,
    (count(*) filter (where l.return_status = 'on_time'))::bigint,
    (count(*) filter (where l.return_status = 'late'))::bigint,
    (count(*) filter (where l.return_status in ('overdue','open','lost','damaged')))::bigint,
    round(100.0 * (count(*) filter (where l.return_status = 'on_time'))::numeric / nullif(count(*),0), 2)
  FROM public.loaner_issuance_r2940 l
  GROUP BY l.issuance_month
  ORDER BY l.issuance_month DESC;
END;
$$;

-- RPC 2: discipline tier breakdown
CREATE OR REPLACE FUNCTION public.r2940_discipline_tier_breakdown()
RETURNS TABLE (
  discipline_tier text,
  customer_count bigint,
  total_penalty_rupees bigint,
  unresolved_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.discipline_tier,
    count(*)::bigint,
    coalesce(sum(d.penalty_rupees),0)::bigint,
    (count(*) filter (where d.resolved = false))::bigint
  FROM public.loaner_return_discipline_r2940 d
  GROUP BY d.discipline_tier
  ORDER BY
    CASE d.discipline_tier
      WHEN 'gold' THEN 1 WHEN 'silver' THEN 2 WHEN 'bronze' THEN 3
      WHEN 'watchlist' THEN 4 WHEN 'blacklist' THEN 5 END;
END;
$$;

-- RPC 3: overdue loaners detail
CREATE OR REPLACE FUNCTION public.r2940_overdue_loaners_detail()
RETURNS TABLE (
  customer_org_name text,
  engineer_code text,
  equipment_model text,
  expected_return_at timestamptz,
  loaner_value_rupees integer,
  return_status text,
  city text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.customer_org_name, l.engineer_code, l.equipment_model,
         l.expected_return_at, l.loaner_value_rupees, l.return_status, l.city
  FROM public.loaner_issuance_r2940 l
  WHERE l.return_status IN ('overdue','open','lost','damaged')
  ORDER BY l.expected_return_at ASC;
END;
$$;

-- RPC 4: engineer return performance
CREATE OR REPLACE FUNCTION public.r2940_engineer_return_performance()
RETURNS TABLE (
  engineer_code text,
  loaners_issued bigint,
  on_time_count bigint,
  late_count bigint,
  problem_count bigint,
  on_time_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.engineer_code,
    count(*)::bigint,
    (count(*) filter (where l.return_status = 'on_time'))::bigint,
    (count(*) filter (where l.return_status = 'late'))::bigint,
    (count(*) filter (where l.return_status in ('overdue','lost','damaged')))::bigint,
    round(100.0 * (count(*) filter (where l.return_status = 'on_time'))::numeric / nullif(count(*),0), 2)
  FROM public.loaner_issuance_r2940 l
  GROUP BY l.engineer_code
  ORDER BY count(*) DESC;
END;
$$;

-- RPC 5: customer return performance
CREATE OR REPLACE FUNCTION public.r2940_customer_return_performance()
RETURNS TABLE (
  customer_org_name text,
  loaners_received bigint,
  total_value_rupees bigint,
  on_time_count bigint,
  problem_count bigint,
  on_time_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.customer_org_name,
    count(*)::bigint,
    coalesce(sum(l.loaner_value_rupees),0)::bigint,
    (count(*) filter (where l.return_status = 'on_time'))::bigint,
    (count(*) filter (where l.return_status in ('overdue','lost','damaged'))) ::bigint,
    round(100.0 * (count(*) filter (where l.return_status = 'on_time'))::numeric / nullif(count(*),0), 2)
  FROM public.loaner_issuance_r2940 l
  GROUP BY l.customer_org_name
  ORDER BY count(*) DESC;
END;
$$;

-- RPC 6: category risk
CREATE OR REPLACE FUNCTION public.r2940_category_risk()
RETURNS TABLE (
  equipment_category text,
  loaner_count bigint,
  total_value_at_risk_rupees bigint,
  problem_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.equipment_category,
    count(*)::bigint,
    coalesce(sum(l.loaner_value_rupees) filter (where l.return_status in ('overdue','open','lost','damaged')),0)::bigint,
    round(100.0 * (count(*) filter (where l.return_status in ('overdue','lost','damaged')))::numeric / nullif(count(*),0), 2)
  FROM public.loaner_issuance_r2940 l
  GROUP BY l.equipment_category
  ORDER BY count(*) DESC;
END;
$$;

-- RPC 7: recovery action queue
CREATE OR REPLACE FUNCTION public.r2940_recovery_action_queue()
RETURNS TABLE (
  founder_flag text,
  recovery_action text,
  customer_org_name text,
  engineer_code text,
  days_overdue integer,
  penalty_rupees integer,
  discipline_tier text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.founder_flag, d.recovery_action, d.customer_org_name, d.engineer_code,
         d.days_overdue, d.penalty_rupees, d.discipline_tier
  FROM public.loaner_return_discipline_r2940 d
  WHERE d.resolved = false
  ORDER BY
    CASE d.founder_flag WHEN 'board_pack' THEN 1 WHEN 'urgent' THEN 2 WHEN 'review' THEN 3 ELSE 4 END,
    d.days_overdue DESC;
END;
$$;

-- =========================================================================
-- GRANTS
-- =========================================================================
REVOKE EXECUTE ON FUNCTION public.r2940_monthly_issuance_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2940_discipline_tier_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2940_overdue_loaners_detail() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2940_engineer_return_performance() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2940_customer_return_performance() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2940_category_risk() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2940_recovery_action_queue() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2940_monthly_issuance_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2940_discipline_tier_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2940_overdue_loaners_detail() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2940_engineer_return_performance() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2940_customer_return_performance() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2940_category_risk() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2940_recovery_action_queue() TO authenticated;
