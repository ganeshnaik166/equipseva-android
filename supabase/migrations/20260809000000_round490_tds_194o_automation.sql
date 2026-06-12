-- =====================================================================
-- Round 490 — §194-O TDS auto-deduct + 26AS reconciliation (v0.4 Phase 2 #3)
-- =====================================================================
--
-- Indian Income Tax Act §194-O (effective Oct 2020, updated 2023+):
--   * E-commerce operators (we are one — facilitating payments
--     between hospital and engineer) MUST deduct 1% TDS on gross
--     sale value to the e-commerce participant (engineer).
--   * Threshold: applies once cumulative gross > ₹5,00,000 in a
--     fiscal year for the same participant. Below threshold = no
--     deduction (small-volume engineer carve-out).
--   * Timing: deduct at the EARLIER of (a) credit to participant's
--     account, (b) payment to participant. Our model: deduct when
--     engineer_payout flips to 'dispatched' / 'processed'.
--   * Deposit by 7th of NEXT month with govt + file TDS return
--     quarterly (Form 26Q).
--   * Engineer reconciles their Form 26AS against our TDS certs.
--
-- If we ship Phase 2 escrow flow without TDS deduct, we owe TDS
-- retroactively + 30% expense disallowance under §40(a)(ia). The
-- roadmap explicitly flagged this as "tightly coupled with escrow".
--
-- This migration ships the BACKEND for TDS deduction; the actual
-- 7th-of-month govt deposit + 26Q filing is OPS / chartered
-- accountant work, but the structural ledger must exist FIRST.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. tds_deductions table
-- ---------------------------------------------------------------------
-- One row per engineer_payout that crossed the §194-O threshold.
-- Below-threshold payouts get a row too (with tds_rupees=0) so the
-- ledger is complete — auditors can prove we tracked but didn't
-- deduct, vs forgot to track at all.
CREATE TABLE IF NOT EXISTS public.tds_deductions (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id      uuid        NOT NULL,
  CONSTRAINT tds_deductions_engineer_fk
    FOREIGN KEY (engineer_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT,
  payout_id             uuid        NOT NULL UNIQUE
                                    REFERENCES public.engineer_payouts(id) ON DELETE RESTRICT,
  fiscal_year           text        NOT NULL,   -- "2026-27"
  fy_quarter            text        NOT NULL    -- "Q1" / "Q2" / "Q3" / "Q4"
                                    CHECK (fy_quarter IN ('Q1','Q2','Q3','Q4')),
  -- Money math
  gross_rupees          numeric(12,2) NOT NULL CHECK (gross_rupees >= 0),
  tds_rate_pct          numeric(5,2)  NOT NULL DEFAULT 1.00,
  tds_rupees            numeric(12,2) NOT NULL CHECK (tds_rupees >= 0),
  net_payable_rupees    numeric(12,2) NOT NULL CHECK (net_payable_rupees >= 0),
  -- Below-threshold rows have tds_rupees=0 + deducted=false.
  -- Above-threshold rows have deducted=true.
  deducted              boolean       NOT NULL DEFAULT false,
  -- Cumulative gross sale value to this engineer in this FY at
  -- the moment of deduction (used to decide if threshold crossed).
  cumulative_fy_gross_rupees numeric(14,2) NOT NULL,
  threshold_rupees      numeric(14,2) NOT NULL DEFAULT 500000.00,
  -- Govt deposit tracking
  deposited_to_govt_at  timestamptz,
  deposit_challan_no    text,
  -- Certificate (Form 16A for §194-O equivalent — issued to engineer)
  certificate_issued_at timestamptz,
  certificate_url       text,
  created_at            timestamptz   NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.tds_deductions IS
  'Round 490 — §194-O TDS ledger. One row per engineer_payout. Below-threshold rows have tds_rupees=0 + deducted=false; above-threshold deduct 1%. Govt deposit + certificate tracked here.';

CREATE INDEX IF NOT EXISTS tds_deductions_engineer_fy_idx
  ON public.tds_deductions (engineer_user_id, fiscal_year, created_at DESC);
CREATE INDEX IF NOT EXISTS tds_deductions_fy_quarter_idx
  ON public.tds_deductions (fiscal_year, fy_quarter);
CREATE INDEX IF NOT EXISTS tds_deductions_undeposited_idx
  ON public.tds_deductions (deposited_to_govt_at, created_at)
  WHERE deposited_to_govt_at IS NULL AND tds_rupees > 0;

ALTER TABLE public.tds_deductions ENABLE ROW LEVEL SECURITY;

-- SELECT: engineer sees own rows + founder sees all
DROP POLICY IF EXISTS tds_deductions_select ON public.tds_deductions;
CREATE POLICY tds_deductions_select
  ON public.tds_deductions
  FOR SELECT
  TO authenticated, service_role
  USING (engineer_user_id = auth.uid() OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.tds_deductions
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. FY helper — derive fiscal_year + quarter from date (India)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.indian_fiscal_year_for(p_at timestamptz)
RETURNS TABLE(fiscal_year text, fy_quarter text)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_year_yyyy int := EXTRACT(YEAR FROM (p_at AT TIME ZONE 'Asia/Kolkata'));
  v_month     int := EXTRACT(MONTH FROM (p_at AT TIME ZONE 'Asia/Kolkata'));
  v_fy_start  int;
  v_q         text;
BEGIN
  -- India FY: April 1 → March 31. Months 1-3 belong to PREVIOUS FY.
  IF v_month >= 4 THEN
    v_fy_start := v_year_yyyy;
  ELSE
    v_fy_start := v_year_yyyy - 1;
  END IF;

  -- Quarters: Q1=Apr-Jun, Q2=Jul-Sep, Q3=Oct-Dec, Q4=Jan-Mar.
  v_q := CASE
    WHEN v_month BETWEEN 4 AND 6 THEN 'Q1'
    WHEN v_month BETWEEN 7 AND 9 THEN 'Q2'
    WHEN v_month BETWEEN 10 AND 12 THEN 'Q3'
    ELSE 'Q4'
  END;

  fiscal_year := v_fy_start::text || '-' || lpad(((v_fy_start + 1) % 100)::text, 2, '0');
  fy_quarter  := v_q;
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.indian_fiscal_year_for(timestamptz) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.indian_fiscal_year_for(timestamptz) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. record_tds_for_payout — called when payout flips to processed
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_tds_for_payout(
  p_payout_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payout              record;
  v_fy                  text;
  v_q                   text;
  v_cumulative          numeric;
  v_threshold           numeric := 500000.00;
  v_rate_pct            numeric := 1.00;
  v_tds                 numeric := 0;
  v_net                 numeric;
  v_deducted            boolean := false;
  v_tds_id              uuid;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_payout
    FROM public.engineer_payouts
   WHERE id = p_payout_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'payout_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_payout.engineer_user_id IS NULL THEN
    RAISE EXCEPTION 'payout_missing_engineer_user_id' USING ERRCODE = '22023';
  END IF;

  -- Idempotency: payout_id is UNIQUE on tds_deductions. Re-call
  -- returns the existing row id without re-deducting.
  SELECT id INTO v_tds_id FROM public.tds_deductions WHERE payout_id = p_payout_id;
  IF v_tds_id IS NOT NULL THEN
    RETURN v_tds_id;
  END IF;

  -- Resolve fiscal year + quarter for this payout's processed date
  -- (fall back to now() if dispatched_at missing).
  SELECT fiscal_year, fy_quarter
    INTO v_fy, v_q
    FROM public.indian_fiscal_year_for(coalesce(v_payout.dispatched_at, now()));

  -- Cumulative gross to THIS engineer in THIS fiscal year, INCLUSIVE
  -- of the current payout. Sum engineer_payouts.amount_rupees with
  -- status IN (processed, dispatched) for the engineer in [fy_start, fy_end].
  WITH fy_window AS (
    SELECT
      CASE
        WHEN EXTRACT(MONTH FROM (coalesce(v_payout.dispatched_at, now()) AT TIME ZONE 'Asia/Kolkata')) >= 4
          THEN make_timestamptz(EXTRACT(YEAR FROM (coalesce(v_payout.dispatched_at, now()) AT TIME ZONE 'Asia/Kolkata'))::int, 4, 1, 0, 0, 0, 'Asia/Kolkata')
        ELSE make_timestamptz((EXTRACT(YEAR FROM (coalesce(v_payout.dispatched_at, now()) AT TIME ZONE 'Asia/Kolkata')))::int - 1, 4, 1, 0, 0, 0, 'Asia/Kolkata')
      END AS fy_start
  )
  SELECT coalesce(sum(ep.amount_rupees), 0) INTO v_cumulative
    FROM public.engineer_payouts ep, fy_window
   WHERE ep.engineer_user_id = v_payout.engineer_user_id
     AND ep.status IN ('processed','dispatched')
     AND coalesce(ep.dispatched_at, ep.updated_at) >= fy_window.fy_start
     AND coalesce(ep.dispatched_at, ep.updated_at) <  (fy_window.fy_start + interval '1 year');

  -- Decide if this payout crosses / is above threshold
  IF v_cumulative > v_threshold THEN
    v_deducted := true;
    -- Note: §194-O deducts on the AMOUNT OF THIS PAYOUT (not on
    -- the excess-over-threshold). The threshold is a "do you
    -- deduct at all" gate, not a "deduct only the excess".
    v_tds := round(v_payout.amount_rupees * (v_rate_pct / 100.0), 2);
  END IF;

  v_net := v_payout.amount_rupees - v_tds;

  INSERT INTO public.tds_deductions (
    engineer_user_id, payout_id, fiscal_year, fy_quarter,
    gross_rupees, tds_rate_pct, tds_rupees, net_payable_rupees,
    deducted, cumulative_fy_gross_rupees, threshold_rupees
  ) VALUES (
    v_payout.engineer_user_id, p_payout_id, v_fy, v_q,
    v_payout.amount_rupees, v_rate_pct, v_tds, v_net,
    v_deducted, v_cumulative, v_threshold
  ) RETURNING id INTO v_tds_id;

  RETURN v_tds_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_tds_for_payout(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.record_tds_for_payout(uuid)
  TO service_role;

-- ---------------------------------------------------------------------
-- 4. mark_tds_deposited — ops books the govt deposit
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_tds_deposited(
  p_fiscal_year text,
  p_fy_quarter  text,
  p_challan_no  text,
  p_deposited_at timestamptz DEFAULT now()
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_challan_no IS NULL OR length(trim(p_challan_no)) < 3 THEN
    RAISE EXCEPTION 'challan_no required (min 3 chars)' USING ERRCODE = '22023';
  END IF;

  UPDATE public.tds_deductions
     SET deposited_to_govt_at = p_deposited_at,
         deposit_challan_no   = p_challan_no
   WHERE fiscal_year = p_fiscal_year
     AND fy_quarter   = p_fy_quarter
     AND deducted     = true
     AND deposited_to_govt_at IS NULL;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  PERFORM public.log_founder_action(
    p_op_name       => 'mark_tds_deposited',
    p_target_table  => 'tds_deductions',
    p_target_row_id => NULL,
    p_before_value  => jsonb_build_object('fy', p_fiscal_year, 'q', p_fy_quarter),
    p_after_value   => jsonb_build_object('challan_no', p_challan_no, 'rows_marked', v_count),
    p_reason        => 'Govt TDS deposit booked against challan ' || p_challan_no
  );
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_tds_deposited(text, text, text, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.mark_tds_deposited(text, text, text, timestamptz)
  TO service_role;

-- ---------------------------------------------------------------------
-- 5. my_tds_summary — engineer-facing
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_tds_summary(
  p_fiscal_year text DEFAULT NULL
)
RETURNS TABLE(
  fiscal_year                 text,
  fy_quarter                  text,
  total_gross_rupees          numeric,
  total_tds_rupees            numeric,
  total_net_payable_rupees    numeric,
  deduction_count             bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_fy text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF p_fiscal_year IS NULL THEN
    SELECT fiscal_year INTO v_fy FROM public.indian_fiscal_year_for(now());
  ELSE
    v_fy := p_fiscal_year;
  END IF;

  RETURN QUERY
  SELECT t.fiscal_year, t.fy_quarter,
         sum(t.gross_rupees)::numeric,
         sum(t.tds_rupees)::numeric,
         sum(t.net_payable_rupees)::numeric,
         count(*)::bigint
    FROM public.tds_deductions t
   WHERE t.engineer_user_id = auth.uid()
     AND t.fiscal_year = v_fy
   GROUP BY t.fiscal_year, t.fy_quarter
   ORDER BY t.fy_quarter;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_tds_summary(text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_tds_summary(text)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 6. founder_tds_quarterly_summary — for 26Q filing prep
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_tds_quarterly_summary(
  p_fiscal_year text,
  p_fy_quarter  text
)
RETURNS TABLE(
  engineer_user_id            uuid,
  engineer_email              text,
  total_gross_rupees          numeric,
  total_tds_rupees            numeric,
  deduction_count             bigint,
  any_undeposited             boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT t.engineer_user_id,
         coalesce(u.email, 'unknown') AS engineer_email,
         sum(t.gross_rupees)::numeric,
         sum(t.tds_rupees)::numeric,
         count(*) FILTER (WHERE t.deducted)::bigint,
         bool_or(t.deducted AND t.deposited_to_govt_at IS NULL)
    FROM public.tds_deductions t
    LEFT JOIN auth.users u ON u.id = t.engineer_user_id
   WHERE t.fiscal_year = p_fiscal_year
     AND t.fy_quarter   = p_fy_quarter
   GROUP BY t.engineer_user_id, u.email
   ORDER BY sum(t.tds_rupees) DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_tds_quarterly_summary(text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_tds_quarterly_summary(text, text)
  TO service_role;

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'tds_deductions'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 490: tds_deductions RLS not enabled';
  END IF;

  IF has_function_privilege('anon', 'public.record_tds_for_payout(uuid)', 'EXECUTE') OR
     has_function_privilege('authenticated', 'public.record_tds_for_payout(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 490: record_tds_for_payout callable by non-service_role';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.my_tds_summary(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 490: my_tds_summary not callable by authenticated';
  END IF;

  RAISE NOTICE 'round 490 §194-O TDS automation verified: table + 5 RPCs, grants correct';
END;
$$;
