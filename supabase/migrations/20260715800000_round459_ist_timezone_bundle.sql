-- Round 459 — IST timezone bundle (1 CRITICAL + 3 HIGH + 1 MED).
--
-- India runs IST (UTC+5:30); Supabase runs UTC. Every place that
-- evaluates a timestamptz in the session timezone, casts timestamptz
-- to date, or extracts year/month/day silently uses UTC. For India
-- that drifts by 5h30m every midnight: jobs completed between 00:00
-- and 05:30 IST stamp as the prior UTC day, and FY rollover at
-- April 1 produces the wrong invoice FY for that 5.5h window.
--
-- This migration fixes:
--   1. CRITICAL — get_repair_invoice_payload FY + invoice_date use
--      UTC (round 449 + round 457 both affected). Jobs completed
--      00:00-05:30 IST on April 1 get FY 2025-26 instead of 2026-27.
--      GSTR-3B reconciliation breaks for that window.
--   2. HIGH — admin_dashboard_stats orders_today / integrity_failures_
--      today / new_signups_today count UTC day. Dashboard shows "0
--      today" until 05:30 IST even though activity since IST midnight.
--   3. MED — admin_amc_expiring_soon days_remaining drifts by 1 day
--      between 18:30 UTC and 05:30 IST. Same bug shape.
--
-- Edge functions (TypeScript) and Android-side date rendering fix
-- shipped in companion edits NOT in this migration.

-- ---------------------------------------------------------------------
-- 1. get_repair_invoice_payload — IST FY + invoice_date
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
  v_cgst         numeric;
  v_sgst         numeric;
  v_completed_ist timestamp;
  v_fy_start_yr  int;
  v_fy_end_yr    int;
  v_invoice_no   text;
  v_invoice_date date;
BEGIN
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

  IF v_job.status::text <> 'completed' THEN
    RETURN;
  END IF;

  SELECT
    p.full_name, p.email, p.phone, p.gstin, p.business_address,
    p.city, p.state, p.pincode
    INTO v_buyer
    FROM public.profiles p
   WHERE p.id = v_job.hospital_user_id;

  v_gross := coalesce(v_job.contracted_amount_rupees, 0);
  v_taxable := round(v_gross / 1.18, 2);
  v_gst_total := round(v_gross - v_taxable, 2);
  v_cgst := round(v_gst_total / 2.0, 2);
  v_sgst := v_gst_total - v_cgst;

  -- Round 459 fix: coerce completed_at to IST BEFORE extracting FY +
  -- invoice date. The naive `EXTRACT(... FROM timestamptz)` evaluated
  -- in UTC pushes the FY/date back 5h30m, so a job completed
  -- 2026-04-01 03:00 IST was getting FY 2025-26 / invoice_date
  -- 2026-03-31 — wrong filing month + wrong date on the document.
  v_completed_ist := (coalesce(v_job.completed_at, now()) AT TIME ZONE 'Asia/Kolkata');
  v_invoice_date := v_completed_ist::date;

  v_fy_start_yr := EXTRACT(YEAR FROM v_completed_ist)::int;
  IF EXTRACT(MONTH FROM v_completed_ist)::int < 4 THEN
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
    v_invoice_date                      AS invoice_date,
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
    v_cgst                                   AS cgst,
    v_sgst                                   AS sgst,
    0::numeric                               AS igst,
    '998739'::text                           AS hsn_sac_code,
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

-- ---------------------------------------------------------------------
-- 2. admin_dashboard_stats — IST day boundaries
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_dashboard_stats()
RETURNS TABLE (
  pending_kyc int,
  pending_sellers int,
  pending_reports int,
  orders_today int,
  integrity_failures_today int,
  new_signups_today int,
  active_repair_jobs int,
  amc_contracts_active int,
  amc_contracts_expired int,
  amc_contracts_expiring_soon int,
  amc_contracts_paused int,
  inactive_engineers_30d int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  -- Round 459 fix: anchor "today" to IST midnight, not UTC midnight.
  -- date_trunc('day', X AT TIME ZONE 'Asia/Kolkata') yields a naive
  -- timestamp at IST midnight; the outer AT TIME ZONE flips it back
  -- to a timestamptz anchored to that IST moment for comparison
  -- against created_at (timestamptz).
  v_ist_today_start timestamptz := date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';
  v_ist_today_date date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*)::int FROM public.engineers WHERE coalesce(verification_status,'pending') = 'pending'),
      (SELECT count(*)::int FROM public.seller_verification_requests WHERE status = 'pending'),
      (SELECT count(*)::int FROM public.content_reports WHERE status = 'pending'),
      (SELECT count(*)::int FROM public.spare_part_orders WHERE created_at >= v_ist_today_start),
      (SELECT count(*)::int FROM public.device_integrity_checks WHERE created_at >= v_ist_today_start AND coalesce(pass, true) = false),
      (SELECT count(*)::int FROM auth.users WHERE created_at >= v_ist_today_start),
      (SELECT count(*)::int FROM public.repair_jobs WHERE status IN ('requested','assigned','in_progress')),
      (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'active'),
      (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'expired'),
      (SELECT count(*)::int
         FROM public.amc_contracts
        WHERE status = 'active'
          AND end_date IS NOT NULL
          AND end_date >= v_ist_today_date
          AND end_date <= v_ist_today_date + interval '30 days'),
      (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'paused'),
      (SELECT count(*)::int
         FROM public.engineers e
        WHERE coalesce(e.verification_status,'pending') = 'verified'
          AND e.created_at < now() - interval '7 days'
          AND NOT EXISTS (
            SELECT 1 FROM public.repair_job_escrow rje
             WHERE rje.engineer_user_id = e.user_id
               AND rje.status = 'released'
               AND rje.released_at >= now() - interval '30 days'
          ));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_dashboard_stats() FROM PUBLIC, anon;

-- ---------------------------------------------------------------------
-- 3. admin_amc_expiring_soon — IST day for days_remaining + filter
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_amc_expiring_soon(
  p_days int DEFAULT 30
)
RETURNS TABLE (
  contract_id uuid,
  hospital_user_id uuid,
  hospital_name text,
  primary_engineer_id uuid,
  primary_engineer_name text,
  end_date date,
  days_remaining int,
  monthly_fee_rupees numeric,
  auto_renew boolean,
  renewal_notifications_sent int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_days int := greatest(1, least(coalesce(p_days, 30), 365));
  -- Round 459 fix: anchor "today" to IST so days_remaining doesn't
  -- drift between 18:30 UTC and 05:30 IST.
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT
      c.id,
      c.hospital_user_id,
      coalesce(hp.full_name, hp.email, '(unknown)'),
      c.primary_engineer_id,
      coalesce(ep.full_name, ep.email, '(unknown)'),
      c.end_date,
      (c.end_date - v_today)::int,
      c.monthly_fee_rupees,
      coalesce(c.auto_renew, false),
      coalesce(c.renewal_notifications_sent, 0)
    FROM public.amc_contracts c
    LEFT JOIN public.profiles hp ON hp.id = c.hospital_user_id
    LEFT JOIN public.engineers e ON e.id = c.primary_engineer_id
    LEFT JOIN public.profiles ep ON ep.id = e.user_id
    WHERE c.status = 'active'
      AND c.end_date IS NOT NULL
      AND c.end_date >= v_today
      AND c.end_date <= v_today + make_interval(days => v_days)
    ORDER BY c.end_date ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_amc_expiring_soon(int) TO authenticated;
