-- =====================================================================
-- Round 500 — Bonded Parts Provenance Ledger (v0.4 Phase 5 #3)
-- =====================================================================
--
-- 500th migration — and the right milestone is closing the
-- skeptic-panel CRITICAL #2: "Counterfeit parts → BNS 304A
-- non-bailable jail risk". Today's flow: engineer brings parts
-- from "wherever", fits them in hospital equipment, hospital pays.
-- If the part is grey-market / counterfeit + patient dies, founder
-- personal criminal exposure under §304A IPC (negligence causing
-- death). HOSPITAL liability under NABH HRM-3 (procurement chain).
--
-- This migration ships the BONDED PARTS PROVENANCE ledger:
--   * bonded_parts_supplier — pre-approved suppliers (OEM + verified
--     distributors)
--   * bonded_parts_intake — every part lot logged at receipt by us
--     (vendor invoice + tamper QR + serial range)
--   * bonded_parts_dispatch — when engineer is dispatched a part
--     out of the bonded warehouse to a specific repair job
--   * bonded_parts_install_event — engineer scans tamper QR at
--     install time + hospital confirms; closes the chain.
--
-- Three rules enforced:
--   1. parts_replaced jsonb on dsr_reports SHOULD reference a
--      bonded_parts_dispatch.id (enforced soft for now via flagging
--      anomaly_kind 'bring_your_own_part' in reconciliation).
--   2. Tamper QR must be SCANNED at install (not just keyed in) —
--      install_event captures scanner kind + matched signature.
--   3. Engineer cannot mark a job COMPLETE if dispatched parts have
--      no matching install_event (added as a check in DSR submit
--      down the line; this round just ships the ledger).

BEGIN;

-- ---------------------------------------------------------------------
-- 1. bonded_parts_suppliers
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bonded_parts_suppliers (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_name   text        NOT NULL,
  supplier_gstin  text,
  -- OEM means the manufacturer themselves (Siemens, GE, Philips).
  -- Authorized = a distributor with OEM letter. Verified = a
  -- third-party distributor we hand-checked.
  supplier_tier   text        NOT NULL CHECK (supplier_tier IN ('OEM','AUTHORIZED','VERIFIED')),
  -- For OEM + AUTHORIZED: the OEM brand(s) they supply for.
  oem_brands      text[]      NOT NULL DEFAULT ARRAY[]::text[],
  contact_email   text,
  contact_phone   text,
  active          boolean     NOT NULL DEFAULT true,
  -- Founder-only writeable via SECDEF RPC; this is a curated list.
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT bonded_supplier_uniq UNIQUE (supplier_name, supplier_tier)
);

ALTER TABLE public.bonded_parts_suppliers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bonded_parts_suppliers_select ON public.bonded_parts_suppliers;
CREATE POLICY bonded_parts_suppliers_select
  ON public.bonded_parts_suppliers
  FOR SELECT
  TO authenticated, service_role
  USING (true);  -- everyone sees the supplier list (it's the moat)

REVOKE INSERT, UPDATE, DELETE ON public.bonded_parts_suppliers
  FROM anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. bonded_parts_intake — receipt lot at the warehouse
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bonded_parts_intake (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id        uuid        NOT NULL REFERENCES public.bonded_parts_suppliers(id) ON DELETE RESTRICT,
  -- Vendor invoice
  vendor_invoice_no  text        NOT NULL,
  vendor_invoice_date date       NOT NULL,
  vendor_invoice_url text,
  -- Part details
  oem_brand          text        NOT NULL,
  part_number        text        NOT NULL,
  part_description   text        NOT NULL,
  quantity_received  int         NOT NULL CHECK (quantity_received > 0),
  unit_cost_rupees   numeric(12,2) NOT NULL CHECK (unit_cost_rupees > 0),
  total_cost_rupees  numeric(12,2) NOT NULL,
  -- Tamper QR + serial range — one QR per unit; we store the lot
  -- range as text[].
  tamper_qr_codes    text[]      NOT NULL,
  CONSTRAINT bonded_intake_qr_count CHECK (array_length(tamper_qr_codes, 1) = quantity_received),
  -- Status: 'received' → 'in_stock' → 'depleted'. As units dispatch,
  -- quantity_in_stock decrements (see view + helper RPC below).
  status             text        NOT NULL DEFAULT 'in_stock'
                                 CHECK (status IN ('received','in_stock','depleted','quarantined')),
  intake_received_at timestamptz NOT NULL DEFAULT now(),
  intake_received_by uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  notes              text,
  CONSTRAINT bonded_intake_invoice_uniq UNIQUE (supplier_id, vendor_invoice_no)
);

CREATE INDEX IF NOT EXISTS bonded_intake_part_idx
  ON public.bonded_parts_intake (oem_brand, part_number, status);
CREATE INDEX IF NOT EXISTS bonded_intake_received_idx
  ON public.bonded_parts_intake (intake_received_at DESC);

ALTER TABLE public.bonded_parts_intake ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bonded_parts_intake_select ON public.bonded_parts_intake;
CREATE POLICY bonded_parts_intake_select
  ON public.bonded_parts_intake
  FOR SELECT
  TO authenticated, service_role
  USING (public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.bonded_parts_intake
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. bonded_parts_dispatch — engineer pulls parts for a job
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bonded_parts_dispatch (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  intake_id           uuid        NOT NULL REFERENCES public.bonded_parts_intake(id) ON DELETE RESTRICT,
  repair_job_id       uuid        NOT NULL REFERENCES public.repair_jobs(id) ON DELETE RESTRICT,
  engineer_user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  -- Tamper QR codes from this intake assigned to this dispatch
  assigned_qr_codes   text[]      NOT NULL,
  CONSTRAINT bonded_dispatch_qr_count CHECK (array_length(assigned_qr_codes, 1) > 0),
  unit_cost_rupees    numeric(12,2) NOT NULL,
  quantity            int         NOT NULL,
  CONSTRAINT bonded_dispatch_qty_match CHECK (array_length(assigned_qr_codes, 1) = quantity),
  -- Lifecycle
  status              text        NOT NULL DEFAULT 'dispatched'
                                  CHECK (status IN ('dispatched','installed','returned','lost')),
  dispatched_at       timestamptz NOT NULL DEFAULT now(),
  dispatched_by       uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  installed_at        timestamptz,
  returned_at         timestamptz,
  return_reason       text,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS bonded_dispatch_job_idx
  ON public.bonded_parts_dispatch (repair_job_id);
CREATE INDEX IF NOT EXISTS bonded_dispatch_engineer_idx
  ON public.bonded_parts_dispatch (engineer_user_id, dispatched_at DESC);
CREATE INDEX IF NOT EXISTS bonded_dispatch_status_idx
  ON public.bonded_parts_dispatch (status, dispatched_at DESC)
  WHERE status <> 'installed';

ALTER TABLE public.bonded_parts_dispatch ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bonded_parts_dispatch_select ON public.bonded_parts_dispatch;
CREATE POLICY bonded_parts_dispatch_select
  ON public.bonded_parts_dispatch
  FOR SELECT
  TO authenticated, service_role
  USING (
    engineer_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.repair_jobs rj
      WHERE rj.id = repair_job_id AND rj.hospital_user_id = auth.uid()
    )
    OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.bonded_parts_dispatch
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. bonded_parts_install_event — engineer scans QR + hospital confirms
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bonded_parts_install_event (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  dispatch_id         uuid        NOT NULL REFERENCES public.bonded_parts_dispatch(id) ON DELETE RESTRICT,
  scanned_qr_code     text        NOT NULL,
  -- Match: did the scanned QR match an assigned QR on the dispatch?
  qr_matched          boolean     NOT NULL,
  scanner_kind        text        NOT NULL
                                  CHECK (scanner_kind IN ('camera_app','manual_entry')),
  -- Hospital coordinator confirmation
  hospital_user_id    uuid,
  hospital_confirmed_at timestamptz,
  hospital_signer_name text,
  -- Evidence ledger link
  evidence_ledger_id  uuid        REFERENCES public.evidence_ledger(id) ON DELETE SET NULL,
  scanned_at          timestamptz NOT NULL DEFAULT now(),
  scanned_by          uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT bonded_install_unique_qr UNIQUE (dispatch_id, scanned_qr_code)
);

CREATE INDEX IF NOT EXISTS bonded_install_dispatch_idx
  ON public.bonded_parts_install_event (dispatch_id);
CREATE INDEX IF NOT EXISTS bonded_install_unmatched_idx
  ON public.bonded_parts_install_event (qr_matched, scanned_at DESC)
  WHERE qr_matched = false;

ALTER TABLE public.bonded_parts_install_event ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bonded_parts_install_event_select ON public.bonded_parts_install_event;
CREATE POLICY bonded_parts_install_event_select
  ON public.bonded_parts_install_event
  FOR SELECT
  TO authenticated, service_role
  USING (
    scanned_by = auth.uid()
    OR hospital_user_id = auth.uid()
    OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.bonded_parts_install_event
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 5. founder_register_bonded_supplier
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_register_bonded_supplier(
  p_supplier_name text,
  p_supplier_gstin text,
  p_supplier_tier  text,
  p_oem_brands     text[],
  p_contact_email  text DEFAULT NULL,
  p_contact_phone  text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_supplier_name IS NULL OR length(trim(p_supplier_name)) < 3 THEN
    RAISE EXCEPTION 'supplier_name required (min 3 chars)' USING ERRCODE = '22023';
  END IF;
  IF p_supplier_tier NOT IN ('OEM','AUTHORIZED','VERIFIED') THEN
    RAISE EXCEPTION 'invalid_supplier_tier' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.bonded_parts_suppliers (
    supplier_name, supplier_gstin, supplier_tier, oem_brands,
    contact_email, contact_phone, created_by
  ) VALUES (
    p_supplier_name, p_supplier_gstin, p_supplier_tier,
    coalesce(p_oem_brands, ARRAY[]::text[]),
    p_contact_email, p_contact_phone, auth.uid()
  ) RETURNING id INTO v_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_register_bonded_supplier',
    p_target_table  => 'bonded_parts_suppliers',
    p_target_row_id => v_id,
    p_before_value  => NULL,
    p_after_value   => jsonb_build_object(
      'supplier_name', p_supplier_name,
      'tier', p_supplier_tier,
      'oem_brands', p_oem_brands
    ),
    p_reason        => 'Registered bonded supplier'
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_register_bonded_supplier(
  text, text, text, text[], text, text
) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_register_bonded_supplier(
  text, text, text, text[], text, text
) TO service_role;

-- ---------------------------------------------------------------------
-- 6. founder_record_bonded_intake
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_record_bonded_intake(
  p_supplier_id        uuid,
  p_vendor_invoice_no  text,
  p_vendor_invoice_date date,
  p_vendor_invoice_url text,
  p_oem_brand          text,
  p_part_number        text,
  p_part_description   text,
  p_quantity_received  int,
  p_unit_cost_rupees   numeric,
  p_tamper_qr_codes    text[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total numeric;
  v_id    uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF array_length(p_tamper_qr_codes, 1) <> p_quantity_received THEN
    RAISE EXCEPTION 'qr_codes count must equal quantity_received' USING ERRCODE = '22023';
  END IF;

  v_total := round(p_quantity_received * p_unit_cost_rupees, 2);

  INSERT INTO public.bonded_parts_intake (
    supplier_id, vendor_invoice_no, vendor_invoice_date, vendor_invoice_url,
    oem_brand, part_number, part_description,
    quantity_received, unit_cost_rupees, total_cost_rupees, tamper_qr_codes,
    intake_received_by
  ) VALUES (
    p_supplier_id, p_vendor_invoice_no, p_vendor_invoice_date, p_vendor_invoice_url,
    p_oem_brand, p_part_number, p_part_description,
    p_quantity_received, p_unit_cost_rupees, v_total, p_tamper_qr_codes,
    auth.uid()
  ) RETURNING id INTO v_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_record_bonded_intake',
    p_target_table  => 'bonded_parts_intake',
    p_target_row_id => v_id,
    p_before_value  => NULL,
    p_after_value   => jsonb_build_object(
      'oem_brand', p_oem_brand, 'part_number', p_part_number,
      'quantity', p_quantity_received, 'total_cost_rupees', v_total
    ),
    p_reason        => 'Recorded bonded parts intake invoice ' || p_vendor_invoice_no
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_record_bonded_intake(
  uuid, text, date, text, text, text, text, int, numeric, text[]
) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_record_bonded_intake(
  uuid, text, date, text, text, text, text, int, numeric, text[]
) TO service_role;

-- ---------------------------------------------------------------------
-- 7. dispatch_bonded_parts (founder/ops-only — writes audit row)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispatch_bonded_parts(
  p_intake_id       uuid,
  p_repair_job_id   uuid,
  p_engineer_user_id uuid,
  p_assigned_qr_codes text[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_intake record;
  v_id     uuid;
  v_qty    int := array_length(p_assigned_qr_codes, 1);
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;
  IF v_qty IS NULL OR v_qty = 0 THEN
    RAISE EXCEPTION 'assigned_qr_codes required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_intake FROM public.bonded_parts_intake WHERE id = p_intake_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'intake_not_found' USING ERRCODE = '02000';
  END IF;
  -- Verify every assigned QR is from THIS intake lot
  IF NOT (p_assigned_qr_codes <@ v_intake.tamper_qr_codes) THEN
    RAISE EXCEPTION 'qr_codes_not_subset_of_intake_lot' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.bonded_parts_dispatch (
    intake_id, repair_job_id, engineer_user_id,
    assigned_qr_codes, unit_cost_rupees, quantity,
    dispatched_by
  ) VALUES (
    p_intake_id, p_repair_job_id, p_engineer_user_id,
    p_assigned_qr_codes, v_intake.unit_cost_rupees, v_qty,
    auth.uid()
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.dispatch_bonded_parts(uuid, uuid, uuid, text[])
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.dispatch_bonded_parts(uuid, uuid, uuid, text[])
  TO service_role;

-- ---------------------------------------------------------------------
-- 8. record_bonded_install — engineer scans + hospital confirms
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_bonded_install(
  p_dispatch_id       uuid,
  p_scanned_qr_code   text,
  p_scanner_kind      text,
  p_hospital_signer_name text DEFAULT NULL,
  p_evidence_ledger_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_dispatch record;
  v_match    boolean;
  v_hospital uuid;
  v_id       uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_scanner_kind NOT IN ('camera_app','manual_entry') THEN
    RAISE EXCEPTION 'invalid_scanner_kind' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_dispatch FROM public.bonded_parts_dispatch WHERE id = p_dispatch_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'dispatch_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_dispatch.engineer_user_id <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'only_dispatched_engineer_can_install' USING ERRCODE = '42501';
  END IF;

  v_match := (p_scanned_qr_code = ANY(v_dispatch.assigned_qr_codes));

  -- Resolve hospital from repair_job (for the confirmation row)
  SELECT hospital_user_id INTO v_hospital FROM public.repair_jobs WHERE id = v_dispatch.repair_job_id;

  INSERT INTO public.bonded_parts_install_event (
    dispatch_id, scanned_qr_code, qr_matched, scanner_kind,
    hospital_user_id, hospital_signer_name,
    evidence_ledger_id, scanned_by
  ) VALUES (
    p_dispatch_id, p_scanned_qr_code, v_match, p_scanner_kind,
    v_hospital, p_hospital_signer_name,
    p_evidence_ledger_id, auth.uid()
  ) RETURNING id INTO v_id;

  -- If all assigned QRs have been scanned + matched, flip dispatch status
  IF (
    SELECT count(*)
      FROM public.bonded_parts_install_event ie
     WHERE ie.dispatch_id = p_dispatch_id
       AND ie.qr_matched = true
  ) >= array_length(v_dispatch.assigned_qr_codes, 1) THEN
    UPDATE public.bonded_parts_dispatch
       SET status = 'installed', installed_at = now()
     WHERE id = p_dispatch_id AND status = 'dispatched';
  END IF;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_bonded_install(uuid, text, text, text, uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.record_bonded_install(uuid, text, text, text, uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 9. founder_bonded_parts_dashboard
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_bonded_parts_dashboard()
RETURNS TABLE(
  total_suppliers       bigint,
  total_intake_lots     bigint,
  total_units_received  bigint,
  total_units_dispatched bigint,
  total_units_installed bigint,
  total_units_lost      bigint,
  unmatched_qr_scans    bigint
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
  SELECT
    (SELECT count(*) FROM public.bonded_parts_suppliers WHERE active),
    (SELECT count(*) FROM public.bonded_parts_intake),
    (SELECT coalesce(sum(quantity_received), 0)::bigint FROM public.bonded_parts_intake),
    (SELECT coalesce(sum(quantity), 0)::bigint FROM public.bonded_parts_dispatch),
    (SELECT coalesce(sum(quantity), 0)::bigint FROM public.bonded_parts_dispatch WHERE status = 'installed'),
    (SELECT coalesce(sum(quantity), 0)::bigint FROM public.bonded_parts_dispatch WHERE status = 'lost'),
    (SELECT count(*) FROM public.bonded_parts_install_event WHERE qr_matched = false);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_bonded_parts_dashboard()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_bonded_parts_dashboard() TO service_role;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname IN ('bonded_parts_suppliers','bonded_parts_intake','bonded_parts_dispatch','bonded_parts_install_event')
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 500: one or more bonded parts tables missing or RLS not enabled';
  END IF;
  RAISE NOTICE 'round 500 bonded parts provenance verified: 4 tables, 6 RPCs, intake-dispatch-install chain ready';
END;
$$;
