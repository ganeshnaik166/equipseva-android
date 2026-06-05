-- Round 449 — GST tax-invoice payload for completed repair jobs.
--
-- Why now: founder's GSTIN approved 2026-06-03 (Telangana). Hospitals
-- need GST invoices for their accounting / ITC claim. Founder needs
-- the same data for monthly GSTR-3B filing. Until now there was no
-- way to generate one — finance was tracked only via repair_jobs
-- columns (contracted_amount_rupees + commission/payout split).
--
-- Schema additions:
--   1. profiles.gstin           — optional B2B field for registered hospitals
--   2. profiles.business_address — multi-line billing address (hospitals)
--   3. profiles.city, profiles.pincode — already-missing locality cols
--
-- RPC:
--   get_repair_invoice_payload(p_job_id uuid)
--     RLS-gated. Returns the supplier (env-driven, see edge fn),
--     buyer, service line, and reverse-engineered GST split assuming
--     contracted_amount_rupees is INCLUSIVE of 18% GST.
--
-- GST math (intra-state, the default for Telangana → Telangana):
--   gross               = contracted_amount_rupees
--   taxable_value       = gross / 1.18
--   gst_total           = gross - taxable_value
--   cgst                = gst_total / 2   (9% of taxable)
--   sgst                = gst_total / 2   (9% of taxable)
-- For inter-state (buyer not in supplier state) the edge fn substitutes
-- IGST = gst_total in place of CGST+SGST. The RPC returns the raw
-- amounts; the edge fn does the intra/inter split based on the
-- supplier-state env var.
--
-- Invoice numbering:
--   EQ/YYYY-YY/<job_number_suffix>
--   e.g. EQ/2026-27/RPR-00034 → uniquely derived from job_number +
--   completion FY. No separate sequence — avoids gap/skip headaches
--   on retries and stays human-readable.

-- ---------------------------------------------------------------------
-- 1. Schema additions on profiles
-- ---------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS gstin            text,
  ADD COLUMN IF NOT EXISTS business_address text,
  ADD COLUMN IF NOT EXISTS city             text,
  ADD COLUMN IF NOT EXISTS pincode          text;

-- Light constraint: GSTIN is 15 chars, alphanumeric. We don't enforce
-- the checksum digit server-side — the app validates at input time.
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_gstin_format;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_gstin_format
  CHECK (gstin IS NULL OR (length(gstin) = 15 AND gstin ~ '^[0-9A-Z]{15}$'));

COMMENT ON COLUMN public.profiles.gstin IS
  'Optional B2B GSTIN. 15-char alphanumeric. App-side checksum + state-code validation; server-side format-only.';

-- ---------------------------------------------------------------------
-- 2. get_repair_invoice_payload — invoice data RPC
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_repair_invoice_payload(p_job_id uuid)
RETURNS TABLE (
  invoice_number     text,
  invoice_date       date,
  job_number         text,
  completed_at       timestamptz,
  hospital_user_id   uuid,
  hospital_name      text,
  hospital_email     text,
  hospital_phone     text,
  hospital_gstin     text,
  hospital_address   text,
  hospital_city      text,
  hospital_state     text,
  hospital_pincode   text,
  equipment_type     text,
  equipment_brand    text,
  equipment_model    text,
  equipment_serial   text,
  issue_description  text,
  work_done          text,
  gross_rupees       numeric,
  taxable_value      numeric,
  gst_total          numeric,
  cgst               numeric,
  sgst               numeric,
  igst               numeric,
  hsn_sac_code       text,
  service_description text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_job          public.repair_jobs%ROWTYPE;
  v_buyer        record;
  v_gross        numeric;
  v_taxable      numeric;
  v_gst_total    numeric;
  v_fy_start_yr  int;
  v_fy_end_yr    int;
  v_invoice_no   text;
BEGIN
  -- RLS-equivalent gate: caller must be hospital or engineer or
  -- founder/admin. Matches the surface get_repair_job_escrow uses.
  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_job_id;
  IF NOT FOUND THEN RETURN; END IF;

  IF NOT (
    public.is_founder()
    OR public.is_admin(auth.uid())
    OR auth.uid() = v_job.hospital_user_id
    OR auth.uid() IN (
      SELECT e.user_id FROM public.engineers e WHERE e.id = v_job.engineer_id
    )
  ) THEN
    RETURN;
  END IF;

  -- Only generate invoice for completed jobs (paid + service delivered).
  IF v_job.status::text <> 'completed' THEN
    RETURN;
  END IF;

  -- Buyer details.
  SELECT
    p.full_name, p.email, p.phone, p.gstin, p.business_address,
    p.city, p.state, p.pincode
    INTO v_buyer
    FROM public.profiles p
   WHERE p.id = v_job.hospital_user_id;

  -- Reverse 18% GST out of the gross.
  v_gross := coalesce(v_job.contracted_amount_rupees, 0);
  v_taxable := round(v_gross / 1.18, 2);
  v_gst_total := round(v_gross - v_taxable, 2);

  -- Invoice number = EQ/<FY>/<job_number>. FY = Apr 1 to Mar 31.
  -- Use completed_at, fallback to now() for newly-completed before
  -- completed_at is stamped (shouldn't happen post-RPC, but defensive).
  v_fy_start_yr := EXTRACT(YEAR FROM coalesce(v_job.completed_at, now()))::int;
  IF EXTRACT(MONTH FROM coalesce(v_job.completed_at, now()))::int < 4 THEN
    v_fy_start_yr := v_fy_start_yr - 1;
  END IF;
  v_fy_end_yr := v_fy_start_yr + 1;
  v_invoice_no := 'EQ/'
    || v_fy_start_yr::text
    || '-'
    || lpad((v_fy_end_yr % 100)::text, 2, '0')
    || '/'
    || coalesce(v_job.job_number, substring(v_job.id::text, 1, 8));

  RETURN QUERY SELECT
    v_invoice_no::text                  AS invoice_number,
    coalesce(v_job.completed_at, now())::date AS invoice_date,
    v_job.job_number,
    v_job.completed_at,
    v_job.hospital_user_id,
    coalesce(v_buyer.full_name, '—')::text   AS hospital_name,
    coalesce(v_buyer.email, '')::text        AS hospital_email,
    coalesce(v_buyer.phone, '')::text        AS hospital_phone,
    v_buyer.gstin                            AS hospital_gstin,
    coalesce(v_buyer.business_address, '')::text AS hospital_address,
    coalesce(v_buyer.city, '')::text         AS hospital_city,
    coalesce(v_buyer.state, '')::text        AS hospital_state,
    coalesce(v_buyer.pincode, '')::text      AS hospital_pincode,
    v_job.equipment_type::text               AS equipment_type,
    v_job.equipment_brand,
    v_job.equipment_model,
    v_job.equipment_serial,
    v_job.issue_description,
    v_job.work_done,
    v_gross                                  AS gross_rupees,
    v_taxable                                AS taxable_value,
    v_gst_total                              AS gst_total,
    -- Half-and-half split for intra-state. Edge fn substitutes IGST
    -- if buyer state differs from supplier state.
    round(v_gst_total / 2.0, 2)              AS cgst,
    round(v_gst_total / 2.0, 2)              AS sgst,
    0::numeric                               AS igst,
    '998739'::text                           AS hsn_sac_code,
    -- Free-form description for the line item; mirrors what hospitals
    -- can read on their books.
    concat(
      'Biomedical equipment repair services — ',
      coalesce(nullif(trim(v_job.equipment_type::text), ''), 'medical device'),
      CASE WHEN v_job.equipment_brand IS NOT NULL
           THEN ' (' || v_job.equipment_brand
                || coalesce(' ' || v_job.equipment_model, '')
                || ')'
           ELSE ''
      END
    )::text                                  AS service_description;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_repair_invoice_payload(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_repair_invoice_payload(uuid) TO authenticated;

COMMENT ON FUNCTION public.get_repair_invoice_payload(uuid) IS
  'Round 449 — returns GST tax-invoice payload for a completed repair_job. '
  'RLS-gated to participants + founder/admin. Reverses 18% GST inclusive '
  'from contracted_amount_rupees. Edge fn generate_repair_invoice does the '
  'intra/inter-state split + HTML render.';
