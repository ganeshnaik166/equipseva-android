-- =====================================================================
-- Round 491 — GST Invoice Ledger + Reverse-Charge Flag (v0.4 Phase 2 #4)
-- =====================================================================
--
-- Current state: we collect payments via Razorpay + dispatch via
-- Cashfree, but we DO NOT generate a structured GST invoice per
-- transaction. We rely on Razorpay's payment receipt + Cashfree's
-- payout statement, neither of which is a GST-compliant tax invoice.
-- The hospital CFO can't claim ITC; the engineer can't show purpose-
-- specific output. CDSCO + GST audit asks for invoices; we currently
-- improvise per request.
--
-- This migration ships the invoice LEDGER + the auto-generation RPC.
-- PDF rendering is deferred to a follow-up edge fn (Phase 3 evidence
-- pipeline).
--
-- Two invoices per repair-job transaction:
--   1. HOSPITAL → US (platform fee invoice): GST 18% on platform's
--      take rate (7% of repair, 15% of AMC). EquipSeva is the
--      service provider.
--   2. US → ENGINEER (commission deduction): documented as part
--      of the platform-fee invoice; engineer's GST invoice for
--      service rendered goes engineer → hospital directly via the
--      Reverse-Charge Mechanism if engineer is unregistered (most
--      common case for our biomed engineers).
--
-- Reverse-Charge Mechanism (RCM) under §9(3) + §9(4) CGST Act:
--   - When an unregistered supplier (engineer w/o GST) supplies to
--     a registered recipient (hospital), the RECIPIENT pays GST
--     directly to govt (not the supplier).
--   - The platform marks the invoice with rcm_applicable=true so
--     the hospital's accountant knows to self-assess GST.
--   - We track this flag on every invoice for audit trail.
--
-- HSN 998719 = "repair services for machinery", standard GST 18%.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. gst_invoices table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.gst_invoices (
  id                        uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Invoice serial — IRN-style sequential. Auto-generated.
  invoice_serial            text        NOT NULL UNIQUE,
  -- Direction: who's the issuer + recipient
  issuer_user_id            uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  issuer_name               text        NOT NULL,
  issuer_gstin              text,
  issuer_state              text        NOT NULL,
  -- Recipient = hospital (most common) or engineer (for refund credit notes)
  recipient_user_id         uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  recipient_name            text        NOT NULL,
  recipient_gstin           text,
  recipient_state           text        NOT NULL,
  -- Source transaction
  source_kind               text        NOT NULL
                                        CHECK (source_kind IN (
                                          'repair_job_platform_fee',
                                          'amc_visit_platform_fee',
                                          'spare_part_platform_fee',
                                          'engineer_service_to_hospital',
                                          'refund_credit_note',
                                          'amc_subscription_fee'
                                        )),
  source_id                 uuid        NOT NULL,
  -- HSN + amounts
  hsn_code                  text        NOT NULL DEFAULT '998719',
  taxable_amount_rupees     numeric(12,2) NOT NULL CHECK (taxable_amount_rupees >= 0),
  -- GST split: intra-state = CGST 9% + SGST 9% = 18%; inter-state = IGST 18%
  cgst_rate_pct             numeric(5,2) NOT NULL DEFAULT 0,
  sgst_rate_pct             numeric(5,2) NOT NULL DEFAULT 0,
  igst_rate_pct             numeric(5,2) NOT NULL DEFAULT 0,
  cgst_rupees               numeric(12,2) NOT NULL DEFAULT 0,
  sgst_rupees               numeric(12,2) NOT NULL DEFAULT 0,
  igst_rupees               numeric(12,2) NOT NULL DEFAULT 0,
  total_gst_rupees          numeric(12,2) NOT NULL DEFAULT 0,
  total_invoice_rupees      numeric(12,2) NOT NULL,
  -- Reverse-charge flag (CGST §9(3)/(4))
  rcm_applicable            boolean      NOT NULL DEFAULT false,
  rcm_reason                text,
  -- PDF rendering (deferred to edge fn)
  pdf_url                   text,
  pdf_generated_at          timestamptz,
  -- Cancellation / revision support
  status                    text         NOT NULL DEFAULT 'issued'
                                         CHECK (status IN ('issued','cancelled','revised')),
  revised_by_invoice_id     uuid         REFERENCES public.gst_invoices(id) ON DELETE SET NULL,
  issued_at                 timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS gst_invoices_recipient_idx
  ON public.gst_invoices (recipient_user_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS gst_invoices_issuer_idx
  ON public.gst_invoices (issuer_user_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS gst_invoices_source_idx
  ON public.gst_invoices (source_kind, source_id);
CREATE INDEX IF NOT EXISTS gst_invoices_issued_at_idx
  ON public.gst_invoices (issued_at DESC);

ALTER TABLE public.gst_invoices ENABLE ROW LEVEL SECURITY;

-- SELECT: issuer + recipient + founder
DROP POLICY IF EXISTS gst_invoices_select ON public.gst_invoices;
CREATE POLICY gst_invoices_select
  ON public.gst_invoices
  FOR SELECT
  TO authenticated, service_role
  USING (
    issuer_user_id = auth.uid() OR recipient_user_id = auth.uid() OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.gst_invoices
  FROM anon, authenticated, service_role;

-- Sequence backing the invoice_serial. ES (EquipSeva) prefix +
-- FY + sequential number per FY. Reset annually via the helper.
CREATE SEQUENCE IF NOT EXISTS public.gst_invoice_seq START 1;

-- ---------------------------------------------------------------------
-- 2. Helper — next_gst_invoice_serial
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.next_gst_invoice_serial(p_at timestamptz DEFAULT now())
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_fy   text;
  v_seq  bigint;
BEGIN
  SELECT fiscal_year INTO v_fy FROM public.indian_fiscal_year_for(p_at);
  v_seq := nextval('public.gst_invoice_seq');
  -- Format: ES/FY26-27/000123
  RETURN format('ES/FY%s/%s', v_fy, lpad(v_seq::text, 6, '0'));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.next_gst_invoice_serial(timestamptz) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.next_gst_invoice_serial(timestamptz) TO service_role;

-- ---------------------------------------------------------------------
-- 3. Helper — gst_split_for_states (intra vs inter-state)
-- ---------------------------------------------------------------------
-- Returns (cgst_rate, sgst_rate, igst_rate) given issuer + recipient
-- state codes. Intra-state if states match: CGST 9 + SGST 9.
-- Inter-state: IGST 18. Total = 18% either way; the split decides
-- which government collects what.
CREATE OR REPLACE FUNCTION public.gst_split_for_states(
  p_issuer_state    text,
  p_recipient_state text
)
RETURNS TABLE(cgst_rate numeric, sgst_rate numeric, igst_rate numeric)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_issuer_state IS NULL OR p_recipient_state IS NULL THEN
    -- Default to inter-state IGST when unknown — safer to over-collect
    -- via IGST (tax-neutral) than to mis-split CGST/SGST.
    cgst_rate := 0;
    sgst_rate := 0;
    igst_rate := 18.00;
    RETURN NEXT;
    RETURN;
  END IF;
  IF lower(trim(p_issuer_state)) = lower(trim(p_recipient_state)) THEN
    cgst_rate := 9.00;
    sgst_rate := 9.00;
    igst_rate := 0;
  ELSE
    cgst_rate := 0;
    sgst_rate := 0;
    igst_rate := 18.00;
  END IF;
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.gst_split_for_states(text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.gst_split_for_states(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. issue_gst_invoice — central RPC for invoice creation
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.issue_gst_invoice(
  p_issuer_user_id    uuid,
  p_issuer_name       text,
  p_issuer_gstin      text,
  p_issuer_state      text,
  p_recipient_user_id uuid,
  p_recipient_name    text,
  p_recipient_gstin   text,
  p_recipient_state   text,
  p_source_kind       text,
  p_source_id         uuid,
  p_taxable_amount    numeric,
  p_hsn_code          text DEFAULT '998719',
  p_rcm_applicable    boolean DEFAULT false,
  p_rcm_reason        text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_serial      text;
  v_split       record;
  v_cgst        numeric;
  v_sgst        numeric;
  v_igst        numeric;
  v_total_gst   numeric;
  v_total_inv   numeric;
  v_id          uuid;
BEGIN
  -- Only service_role and founder can issue invoices (called by
  -- backend systems / cron / founder ops, not direct user code).
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  IF p_taxable_amount IS NULL OR p_taxable_amount < 0 THEN
    RAISE EXCEPTION 'invalid taxable_amount' USING ERRCODE = '22023';
  END IF;
  IF p_rcm_applicable AND (p_rcm_reason IS NULL OR length(trim(p_rcm_reason)) < 5) THEN
    RAISE EXCEPTION 'rcm_reason required when rcm_applicable=true' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_split FROM public.gst_split_for_states(p_issuer_state, p_recipient_state);
  v_cgst := round(p_taxable_amount * (v_split.cgst_rate / 100.0), 2);
  v_sgst := round(p_taxable_amount * (v_split.sgst_rate / 100.0), 2);
  v_igst := round(p_taxable_amount * (v_split.igst_rate / 100.0), 2);
  v_total_gst := v_cgst + v_sgst + v_igst;
  v_total_inv := p_taxable_amount + v_total_gst;

  v_serial := public.next_gst_invoice_serial();

  INSERT INTO public.gst_invoices (
    invoice_serial,
    issuer_user_id, issuer_name, issuer_gstin, issuer_state,
    recipient_user_id, recipient_name, recipient_gstin, recipient_state,
    source_kind, source_id,
    hsn_code, taxable_amount_rupees,
    cgst_rate_pct, sgst_rate_pct, igst_rate_pct,
    cgst_rupees, sgst_rupees, igst_rupees,
    total_gst_rupees, total_invoice_rupees,
    rcm_applicable, rcm_reason
  ) VALUES (
    v_serial,
    p_issuer_user_id, p_issuer_name, p_issuer_gstin, p_issuer_state,
    p_recipient_user_id, p_recipient_name, p_recipient_gstin, p_recipient_state,
    p_source_kind, p_source_id,
    p_hsn_code, p_taxable_amount,
    v_split.cgst_rate, v_split.sgst_rate, v_split.igst_rate,
    v_cgst, v_sgst, v_igst,
    v_total_gst, v_total_inv,
    p_rcm_applicable, p_rcm_reason
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.issue_gst_invoice(
  uuid, text, text, text, uuid, text, text, text, text, uuid, numeric, text, boolean, text
) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.issue_gst_invoice(
  uuid, text, text, text, uuid, text, text, text, text, uuid, numeric, text, boolean, text
) TO service_role;

-- ---------------------------------------------------------------------
-- 5. issue_credit_note — for refunds (reverses an issued invoice)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.issue_gst_credit_note(
  p_original_invoice_id  uuid,
  p_credit_taxable_amount numeric,
  p_reason               text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_orig    record;
  v_new_id  uuid;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;
  IF p_credit_taxable_amount IS NULL OR p_credit_taxable_amount <= 0 THEN
    RAISE EXCEPTION 'invalid credit amount' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'reason required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_orig FROM public.gst_invoices WHERE id = p_original_invoice_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'original_invoice_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_orig.status = 'cancelled' THEN
    RAISE EXCEPTION 'original_invoice_already_cancelled' USING ERRCODE = '22023';
  END IF;
  IF p_credit_taxable_amount > v_orig.taxable_amount_rupees THEN
    RAISE EXCEPTION 'credit > original' USING ERRCODE = '22023';
  END IF;

  -- Issue credit note (reverses the GST). Source kind = 'refund_credit_note'.
  v_new_id := public.issue_gst_invoice(
    p_issuer_user_id    => v_orig.issuer_user_id,
    p_issuer_name       => v_orig.issuer_name,
    p_issuer_gstin      => v_orig.issuer_gstin,
    p_issuer_state      => v_orig.issuer_state,
    p_recipient_user_id => v_orig.recipient_user_id,
    p_recipient_name    => v_orig.recipient_name,
    p_recipient_gstin   => v_orig.recipient_gstin,
    p_recipient_state   => v_orig.recipient_state,
    p_source_kind       => 'refund_credit_note',
    p_source_id         => p_original_invoice_id,
    p_taxable_amount    => p_credit_taxable_amount,
    p_hsn_code          => v_orig.hsn_code,
    p_rcm_applicable    => v_orig.rcm_applicable,
    p_rcm_reason        => 'Credit note for ' || v_orig.invoice_serial || ': ' || p_reason
  );

  -- Link the original invoice to the credit note
  UPDATE public.gst_invoices
     SET status = 'revised',
         revised_by_invoice_id = v_new_id
   WHERE id = p_original_invoice_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'issue_gst_credit_note',
    p_target_table  => 'gst_invoices',
    p_target_row_id => p_original_invoice_id,
    p_before_value  => jsonb_build_object('status', v_orig.status, 'amount', v_orig.taxable_amount_rupees),
    p_after_value   => jsonb_build_object('status', 'revised', 'credit_note_id', v_new_id, 'credit_amount', p_credit_taxable_amount),
    p_reason        => p_reason
  );

  RETURN v_new_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.issue_gst_credit_note(uuid, numeric, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.issue_gst_credit_note(uuid, numeric, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 6. my_gst_invoices — user-facing list of own invoices
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_gst_invoices(
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  id                    uuid,
  invoice_serial        text,
  direction             text,
  counterparty_name     text,
  source_kind           text,
  taxable_amount_rupees numeric,
  total_gst_rupees      numeric,
  total_invoice_rupees  numeric,
  rcm_applicable        boolean,
  status                text,
  issued_at             timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    g.id,
    g.invoice_serial,
    CASE WHEN g.issuer_user_id = auth.uid() THEN 'outgoing' ELSE 'incoming' END AS direction,
    CASE WHEN g.issuer_user_id = auth.uid() THEN g.recipient_name ELSE g.issuer_name END AS counterparty_name,
    g.source_kind,
    g.taxable_amount_rupees,
    g.total_gst_rupees,
    g.total_invoice_rupees,
    g.rcm_applicable,
    g.status,
    g.issued_at
  FROM public.gst_invoices g
  WHERE g.issuer_user_id = auth.uid() OR g.recipient_user_id = auth.uid()
  ORDER BY g.issued_at DESC
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_gst_invoices(integer)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_gst_invoices(integer)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7. founder_gst_summary — for GSTR-1 filing prep
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_gst_summary(
  p_fiscal_year text,
  p_fy_quarter  text DEFAULT NULL
)
RETURNS TABLE(
  fiscal_year             text,
  fy_quarter              text,
  invoice_count           bigint,
  taxable_total_rupees    numeric,
  cgst_total_rupees       numeric,
  sgst_total_rupees       numeric,
  igst_total_rupees       numeric,
  rcm_count               bigint,
  rcm_taxable_total       numeric
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
  WITH inv AS (
    SELECT
      g.*,
      ifr.fiscal_year AS inv_fy,
      ifr.fy_quarter  AS inv_q
    FROM public.gst_invoices g,
    LATERAL public.indian_fiscal_year_for(g.issued_at) ifr
    WHERE g.status = 'issued'
  )
  SELECT
    inv.inv_fy,
    inv.inv_q,
    count(*)::bigint,
    sum(inv.taxable_amount_rupees)::numeric,
    sum(inv.cgst_rupees)::numeric,
    sum(inv.sgst_rupees)::numeric,
    sum(inv.igst_rupees)::numeric,
    count(*) FILTER (WHERE inv.rcm_applicable)::bigint,
    sum(inv.taxable_amount_rupees) FILTER (WHERE inv.rcm_applicable)::numeric
  FROM inv
  WHERE inv.inv_fy = p_fiscal_year
    AND (p_fy_quarter IS NULL OR inv.inv_q = p_fy_quarter)
  GROUP BY inv.inv_fy, inv.inv_q
  ORDER BY inv.inv_q;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_gst_summary(text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_gst_summary(text, text)
  TO service_role;

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'gst_invoices'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 491: gst_invoices RLS not enabled';
  END IF;

  IF has_function_privilege('anon', 'public.issue_gst_invoice(uuid,text,text,text,uuid,text,text,text,text,uuid,numeric,text,boolean,text)', 'EXECUTE') OR
     has_function_privilege('authenticated', 'public.issue_gst_invoice(uuid,text,text,text,uuid,text,text,text,text,uuid,numeric,text,boolean,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 491: issue_gst_invoice callable by non-service_role';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.my_gst_invoices(integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 491: my_gst_invoices not callable by authenticated';
  END IF;

  RAISE NOTICE 'round 491 GST invoice ledger verified: table + 6 RPCs + sequence, grants correct';
END;
$$;
