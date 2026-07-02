-- Round 2893 — Founder Monthly Government Tender Pursuit & Win-Rate Drilldown
-- HEAVY ★★★★ — CEO-grade view of govt tender pipeline + EMD exposure + L1 win economics.

BEGIN;

-- ============================================================================
-- TABLE 1: govt_tender_pursuits_r2893
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.govt_tender_pursuits_r2893 (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at            timestamptz NOT NULL DEFAULT now(),
  tender_ref            text NOT NULL,
  authority             text NOT NULL,
  state_code            text NOT NULL,
  category              text NOT NULL,
  estimated_value_lakh  numeric(12,2) NOT NULL,
  emd_lakh              numeric(12,2) NOT NULL,
  bid_submitted_at      timestamptz,
  bid_due_at            timestamptz NOT NULL,
  status                text NOT NULL,
  l1_price_lakh         numeric(12,2),
  our_price_lakh        numeric(12,2),
  competitor_count      int NOT NULL DEFAULT 0,
  win_probability_pct   int NOT NULL DEFAULT 0,
  pursuit_month         date NOT NULL,
  outcome               text,
  notes                 text
);

ALTER TABLE public.govt_tender_pursuits_r2893 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS govt_tender_pursuits_r2893_founder_read ON public.govt_tender_pursuits_r2893;
CREATE POLICY govt_tender_pursuits_r2893_founder_read
  ON public.govt_tender_pursuits_r2893 FOR SELECT TO authenticated
  USING (public.is_founder());

INSERT INTO public.govt_tender_pursuits_r2893
  (tender_ref, authority, state_code, category, estimated_value_lakh, emd_lakh, bid_submitted_at, bid_due_at, status, l1_price_lakh, our_price_lakh, competitor_count, win_probability_pct, pursuit_month, outcome, notes)
VALUES
  ('GEM/2026/JUN/AIIMS-DEL/0142', 'AIIMS Delhi', 'DL', 'dialysis_amc', 84.50, 2.10, '2026-06-03 11:22:00+05:30', '2026-06-05 17:00:00+05:30', 'won', 71.20, 70.80, 7, 78, '2026-06-01', 'L1', '5-yr AMC; technical waiver granted'),
  ('GEM/2026/JUN/PGI-CHD/0089', 'PGI Chandigarh', 'CH', 'icu_ventilator_amc', 56.00, 1.40, '2026-06-08 14:10:00+05:30', '2026-06-10 17:00:00+05:30', 'won', 48.90, 48.60, 5, 71, '2026-06-01', 'L1', 'Margin thin; locks 28 vents'),
  ('GEM/2026/JUN/JIPMER/0033', 'JIPMER Puducherry', 'PY', 'imaging_repair', 28.40, 0.71, '2026-06-12 09:45:00+05:30', '2026-06-15 17:00:00+05:30', 'lost', 19.20, 24.10, 9, 38, '2026-06-01', 'L2', 'Lost on price by 25%'),
  ('GEM/2026/JUN/RML-DEL/0211', 'RML Hospital Delhi', 'DL', 'biomed_amc_bundle', 112.30, 2.81, '2026-06-15 16:00:00+05:30', '2026-06-18 17:00:00+05:30', 'submitted', NULL, 94.50, 6, 62, '2026-06-01', NULL, 'Awaiting techno-commercial open'),
  ('GEM/2026/JUN/TS-DME/0407', 'TS Dir of Medical Edu', 'TS', 'multi_district_amc', 340.00, 8.50, '2026-06-18 12:00:00+05:30', '2026-06-22 17:00:00+05:30', 'submitted', NULL, 289.00, 4, 55, '2026-06-01', NULL, 'Anchor deal; 14 govt hospitals'),
  ('GEM/2026/JUN/KGMU-LKO/0156', 'KGMU Lucknow', 'UP', 'oxygen_plant_amc', 47.80, 1.20, '2026-06-19 10:15:00+05:30', '2026-06-21 17:00:00+05:30', 'lost', 32.10, 39.40, 8, 35, '2026-06-01', 'L3', 'Incumbent retained at sub-cost'),
  ('GEM/2026/JUN/AP-APMSIDC/0512', 'AP Med Services Infra Corp', 'AP', 'rural_chc_amc', 178.50, 4.46, '2026-06-20 15:30:00+05:30', '2026-06-23 17:00:00+05:30', 'submitted', NULL, 142.20, 5, 68, '2026-06-01', NULL, '23 CHCs; 6-month onboarding'),
  ('GEM/2026/JUN/SAFD-BLR/0078', 'St John Med College Blr', 'KA', 'pathology_amc', 38.60, 0.97, '2026-06-21 11:00:00+05:30', '2026-06-24 17:00:00+05:30', 'submitted', NULL, 31.40, 6, 58, '2026-06-01', NULL, 'Strong technical score expected'),
  ('GEM/2026/MAY/AIIMS-BPL/0098', 'AIIMS Bhopal', 'MP', 'dialysis_amc', 62.00, 1.55, '2026-05-04 13:20:00+05:30', '2026-05-07 17:00:00+05:30', 'won', 52.80, 52.40, 6, 72, '2026-05-01', 'L1', 'Renewed Year 2'),
  ('GEM/2026/MAY/NIMHANS/0042', 'NIMHANS Bengaluru', 'KA', 'eeg_amc', 22.40, 0.56, '2026-05-09 10:00:00+05:30', '2026-05-12 17:00:00+05:30', 'lost', 14.80, 18.60, 7, 42, '2026-05-01', 'L2', 'Lost narrowly'),
  ('GEM/2026/MAY/MH-DMER/0301', 'MH Dir of Med Edu', 'MH', 'multi_hospital_amc', 410.20, 10.25, '2026-05-14 09:30:00+05:30', '2026-05-18 17:00:00+05:30', 'won', 348.00, 346.50, 3, 81, '2026-05-01', 'L1', 'Single biggest contract YTD'),
  ('GEM/2026/MAY/SGPGI-LKO/0177', 'SGPGI Lucknow', 'UP', 'icu_ventilator_amc', 71.50, 1.79, '2026-05-21 14:45:00+05:30', '2026-05-24 17:00:00+05:30', 'lost', 58.20, 64.00, 8, 44, '2026-05-01', 'L2', 'Eligibility met but price L2'),
  ('GEM/2026/MAY/KL-KMSCL/0233', 'Kerala Med Services Corp', 'KL', 'rural_chc_amc', 198.30, 4.96, '2026-05-25 12:15:00+05:30', '2026-05-29 17:00:00+05:30', 'won', 162.40, 161.80, 5, 67, '2026-05-01', 'L1', '18 PHCs; coastal districts'),
  ('GEM/2026/JUN/AIIMS-RPR/0061', 'AIIMS Raipur', 'CG', 'imaging_repair', 31.20, 0.78, '2026-06-22 11:30:00+05:30', '2026-06-25 17:00:00+05:30', 'submitted', NULL, 25.60, 7, 51, '2026-06-01', NULL, 'CT + MRI bundle'),
  ('GEM/2026/JUN/GMC-AKL/0014', 'GMC Akola', 'MH', 'biomed_amc_bundle', 18.40, 0.46, '2026-06-09 15:00:00+05:30', '2026-06-11 17:00:00+05:30', 'won', 15.80, 15.40, 4, 74, '2026-06-01', 'L1', 'Tier-3 city anchor'),
  ('GEM/2026/JUN/ESIC-HYD/0119', 'ESIC Hyderabad', 'TS', 'dialysis_amc', 44.60, 1.12, '2026-06-16 10:30:00+05:30', '2026-06-19 17:00:00+05:30', 'no_bid', NULL, NULL, 11, 0, '2026-06-01', 'NO_BID', 'EMC blocked; capacity constraint'),
  ('GEM/2026/JUN/RIMS-RNC/0088', 'RIMS Ranchi', 'JH', 'oxygen_plant_amc', 39.80, 1.00, '2026-06-17 14:00:00+05:30', '2026-06-20 17:00:00+05:30', 'submitted', NULL, 32.50, 5, 60, '2026-06-01', NULL, 'Awaiting price open'),
  ('GEM/2026/MAY/ILBS-DEL/0044', 'Inst Liver & Biliary Sci', 'DL', 'pathology_amc', 26.70, 0.67, '2026-05-30 09:00:00+05:30', '2026-06-02 17:00:00+05:30', 'won', 22.10, 21.90, 6, 69, '2026-05-01', 'L1', 'Specialty unlock');

-- ============================================================================
-- TABLE 2: govt_tender_emd_ledger_r2893
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.govt_tender_emd_ledger_r2893 (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at          timestamptz NOT NULL DEFAULT now(),
  pursuit_id          uuid REFERENCES public.govt_tender_pursuits_r2893(id) ON DELETE SET NULL,
  tender_ref          text NOT NULL,
  emd_lakh            numeric(12,2) NOT NULL,
  emd_instrument      text NOT NULL,
  bank_name           text NOT NULL,
  blocked_at          timestamptz NOT NULL,
  released_at         timestamptz,
  release_status      text NOT NULL,
  days_blocked        int NOT NULL DEFAULT 0,
  carry_cost_rupees   numeric(12,2) NOT NULL DEFAULT 0,
  remarks             text
);

ALTER TABLE public.govt_tender_emd_ledger_r2893 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS govt_tender_emd_ledger_r2893_founder_read ON public.govt_tender_emd_ledger_r2893;
CREATE POLICY govt_tender_emd_ledger_r2893_founder_read
  ON public.govt_tender_emd_ledger_r2893 FOR SELECT TO authenticated
  USING (public.is_founder());

INSERT INTO public.govt_tender_emd_ledger_r2893
  (tender_ref, emd_lakh, emd_instrument, bank_name, blocked_at, released_at, release_status, days_blocked, carry_cost_rupees, remarks)
VALUES
  ('GEM/2026/JUN/AIIMS-DEL/0142', 2.10, 'bank_guarantee', 'HDFC Bank', '2026-06-03', '2026-06-12', 'released', 9, 1551.78, 'Won — converted to PBG'),
  ('GEM/2026/JUN/PGI-CHD/0089', 1.40, 'bank_guarantee', 'HDFC Bank', '2026-06-08', '2026-06-17', 'released', 9, 1034.52, 'Won'),
  ('GEM/2026/JUN/JIPMER/0033', 0.71, 'fdr', 'ICICI Bank', '2026-06-12', '2026-06-22', 'released', 10, 583.01, 'Lost — refunded'),
  ('GEM/2026/JUN/RML-DEL/0211', 2.81, 'bank_guarantee', 'HDFC Bank', '2026-06-15', NULL, 'blocked', 6, 1383.78, 'Awaiting result'),
  ('GEM/2026/JUN/TS-DME/0407', 8.50, 'bank_guarantee', 'SBI', '2026-06-18', NULL, 'blocked', 3, 2095.89, 'Anchor deal — large EMD'),
  ('GEM/2026/JUN/KGMU-LKO/0156', 1.20, 'fdr', 'ICICI Bank', '2026-06-19', NULL, 'awaiting_release', 2, 197.26, 'Lost; refund SLA 14d'),
  ('GEM/2026/JUN/AP-APMSIDC/0512', 4.46, 'bank_guarantee', 'HDFC Bank', '2026-06-20', NULL, 'blocked', 1, 366.58, 'Strong probability'),
  ('GEM/2026/JUN/SAFD-BLR/0078', 0.97, 'fdr', 'Axis Bank', '2026-06-21', NULL, 'blocked', 0, 0, 'Just blocked'),
  ('GEM/2026/MAY/AIIMS-BPL/0098', 1.55, 'bank_guarantee', 'HDFC Bank', '2026-05-04', '2026-05-14', 'released', 10, 1273.97, 'Won'),
  ('GEM/2026/MAY/NIMHANS/0042', 0.56, 'fdr', 'Axis Bank', '2026-05-09', '2026-05-21', 'released', 12, 552.33, 'Lost — refunded'),
  ('GEM/2026/MAY/MH-DMER/0301', 10.25, 'bank_guarantee', 'SBI', '2026-05-14', '2026-05-28', 'released', 14, 11791.78, 'Won — biggest EMD release'),
  ('GEM/2026/MAY/SGPGI-LKO/0177', 1.79, 'fdr', 'ICICI Bank', '2026-05-21', '2026-06-04', 'released', 14, 2059.40, 'Lost; 14d refund'),
  ('GEM/2026/MAY/KL-KMSCL/0233', 4.96, 'bank_guarantee', 'HDFC Bank', '2026-05-25', '2026-06-08', 'released', 14, 5707.94, 'Won'),
  ('GEM/2026/JUN/AIIMS-RPR/0061', 0.78, 'fdr', 'Axis Bank', '2026-06-22', NULL, 'blocked', 0, 0, 'Just blocked'),
  ('GEM/2026/JUN/GMC-AKL/0014', 0.46, 'fdr', 'Axis Bank', '2026-06-09', '2026-06-15', 'released', 6, 226.85, 'Won'),
  ('GEM/2026/JUN/RIMS-RNC/0088', 1.00, 'fdr', 'ICICI Bank', '2026-06-17', NULL, 'blocked', 4, 328.77, 'Awaiting'),
  ('GEM/2026/MAY/ILBS-DEL/0044', 0.67, 'fdr', 'Axis Bank', '2026-05-30', '2026-06-10', 'released', 11, 605.48, 'Won');

-- ============================================================================
-- RPCs (7) — all is_founder() gated
-- ============================================================================

-- 1. Monthly pursuit summary
CREATE OR REPLACE FUNCTION public.r2893_monthly_pursuit_summary()
RETURNS TABLE(
  pursuit_month date,
  pursuits_count int,
  total_tcv_lakh numeric,
  won_count int,
  won_tcv_lakh numeric,
  win_rate_pct numeric,
  avg_competitor_count numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.pursuit_month,
    count(*)::int,
    round(sum(p.estimated_value_lakh)::numeric, 2),
    count(*) FILTER (WHERE p.status = 'won')::int,
    round(coalesce(sum(p.estimated_value_lakh) FILTER (WHERE p.status = 'won'), 0)::numeric, 2),
    round(100.0 * count(*) FILTER (WHERE p.status = 'won') / NULLIF(count(*) FILTER (WHERE p.status IN ('won','lost')), 0), 1),
    round(avg(p.competitor_count)::numeric, 1)
  FROM public.govt_tender_pursuits_r2893 p
  GROUP BY p.pursuit_month
  ORDER BY p.pursuit_month DESC;
END $$;

-- 2. Win-rate by category
CREATE OR REPLACE FUNCTION public.r2893_winrate_by_category()
RETURNS TABLE(
  category text,
  pursuits int,
  wins int,
  losses int,
  win_rate_pct numeric,
  avg_margin_lakh numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.category,
    count(*)::int,
    count(*) FILTER (WHERE p.status = 'won')::int,
    count(*) FILTER (WHERE p.status = 'lost')::int,
    round(100.0 * count(*) FILTER (WHERE p.status = 'won') / NULLIF(count(*) FILTER (WHERE p.status IN ('won','lost')), 0), 1),
    round(avg(p.our_price_lakh - p.l1_price_lakh) FILTER (WHERE p.l1_price_lakh IS NOT NULL)::numeric, 2)
  FROM public.govt_tender_pursuits_r2893 p
  GROUP BY p.category
  ORDER BY count(*) DESC;
END $$;

-- 3. State exposure heatmap
CREATE OR REPLACE FUNCTION public.r2893_state_exposure()
RETURNS TABLE(
  state_code text,
  pursuits int,
  wins int,
  total_tcv_lakh numeric,
  won_tcv_lakh numeric,
  win_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.state_code,
    count(*)::int,
    count(*) FILTER (WHERE p.status = 'won')::int,
    round(sum(p.estimated_value_lakh)::numeric, 2),
    round(coalesce(sum(p.estimated_value_lakh) FILTER (WHERE p.status = 'won'), 0)::numeric, 2),
    round(100.0 * count(*) FILTER (WHERE p.status = 'won') / NULLIF(count(*) FILTER (WHERE p.status IN ('won','lost')), 0), 1)
  FROM public.govt_tender_pursuits_r2893 p
  GROUP BY p.state_code
  ORDER BY sum(p.estimated_value_lakh) DESC;
END $$;

-- 4. Open EMD exposure
CREATE OR REPLACE FUNCTION public.r2893_open_emd_exposure()
RETURNS TABLE(
  tender_ref text,
  emd_lakh numeric,
  bank_name text,
  release_status text,
  days_blocked int,
  carry_cost_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.tender_ref,
    e.emd_lakh,
    e.bank_name,
    e.release_status,
    e.days_blocked,
    e.carry_cost_rupees
  FROM public.govt_tender_emd_ledger_r2893 e
  WHERE e.released_at IS NULL
  ORDER BY e.emd_lakh DESC;
END $$;

-- 5. Top wins this period
CREATE OR REPLACE FUNCTION public.r2893_top_wins()
RETURNS TABLE(
  tender_ref text,
  authority text,
  category text,
  our_price_lakh numeric,
  l1_price_lakh numeric,
  margin_lakh numeric,
  pursuit_month date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.tender_ref,
    p.authority,
    p.category,
    p.our_price_lakh,
    p.l1_price_lakh,
    round((p.our_price_lakh - p.l1_price_lakh)::numeric, 2),
    p.pursuit_month
  FROM public.govt_tender_pursuits_r2893 p
  WHERE p.status = 'won'
  ORDER BY p.our_price_lakh DESC NULLS LAST
  LIMIT 10;
END $$;

-- 6. Loss diagnostics
CREATE OR REPLACE FUNCTION public.r2893_loss_diagnostics()
RETURNS TABLE(
  tender_ref text,
  authority text,
  category text,
  our_price_lakh numeric,
  l1_price_lakh numeric,
  price_gap_pct numeric,
  competitor_count int,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.tender_ref,
    p.authority,
    p.category,
    p.our_price_lakh,
    p.l1_price_lakh,
    round((100.0 * (p.our_price_lakh - p.l1_price_lakh) / NULLIF(p.l1_price_lakh, 0))::numeric, 1),
    p.competitor_count,
    p.notes
  FROM public.govt_tender_pursuits_r2893 p
  WHERE p.status = 'lost'
  ORDER BY (p.our_price_lakh - p.l1_price_lakh) DESC NULLS LAST;
END $$;

-- 7. Pipeline forecast — submitted only
CREATE OR REPLACE FUNCTION public.r2893_pipeline_forecast()
RETURNS TABLE(
  tender_ref text,
  authority text,
  our_price_lakh numeric,
  win_probability_pct int,
  expected_value_lakh numeric,
  bid_due_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.tender_ref,
    p.authority,
    p.our_price_lakh,
    p.win_probability_pct,
    round((p.our_price_lakh * p.win_probability_pct / 100.0)::numeric, 2),
    p.bid_due_at
  FROM public.govt_tender_pursuits_r2893 p
  WHERE p.status = 'submitted'
  ORDER BY (p.our_price_lakh * p.win_probability_pct) DESC NULLS LAST;
END $$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.r2893_monthly_pursuit_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2893_winrate_by_category() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2893_state_exposure() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2893_open_emd_exposure() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2893_top_wins() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2893_loss_diagnostics() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2893_pipeline_forecast() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2893_monthly_pursuit_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2893_winrate_by_category() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2893_state_exposure() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2893_open_emd_exposure() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2893_top_wins() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2893_loss_diagnostics() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2893_pipeline_forecast() TO authenticated;

COMMIT;
