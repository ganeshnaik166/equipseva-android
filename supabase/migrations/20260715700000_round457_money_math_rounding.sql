-- Round 457 — money-math rounding bundle (2 HIGH + 1 MED + 1 LOW from
-- the 2026-06-07 third-pass audit). All server-side paise-drift bugs;
-- bundled because each is the same residual-derivation fix pattern.
--
--   1. HIGH — get_repair_invoice_payload (round 449) computes CGST and
--      SGST independently as round(gst_total/2.0, 2). For any gst_total
--      ending in an odd number of paise (very common — ₹10 → 1.53),
--      half-up rounding gives cgst+sgst = 1.54 ≠ gst_total 1.53. The
--      invoice line items show 0.77 + 0.77 = 1.54, the totals row
--      shows GST 1.53 + taxable 8.47 = 10.00. GSTR-3B reconciliation
--      breaks line-item-vs-summary; mismatch flagged by automated
--      compliance.
--      Fix: residual-derive sgst = gst_total - cgst.
--
--   2. HIGH — debit_amc_pool_on_visit_complete computes per-visit cost
--      as round(monthly_fee * 12 / visits_per_year, 2) and debits that
--      on EVERY visit. visits_per_year permits 1..52 but only
--      {1,2,3,4,6,12} divide 12 evenly. UI exposes "Weekly" (52),
--      "Bi-weekly" (26), and a free 1-52 input — most non-divisors
--      drift by 1-3 paise per annual cycle, flipping the contract to
--      'paused' on the LAST visit even though the hospital pre-paid
--      the full year.
--      Fix: snap the LAST visit of each annual cycle to the exact
--      remaining envelope (annual_envelope - sum_of_prior_debits)
--      instead of the rounded per-visit constant. All other visits
--      keep the rounded value for predictable book-keeping.
--
--   3. MED — engineer_my_amc_earnings computes engineer_payout +
--      platform_take as two independent round() calls. For amounts
--      with odd half-paise the two halves don't sum to amount_rupees.
--      Engineer's surfaced "paid" total reads 1 paisa above the
--      ledger debit for those rows.
--      Fix: residual-derive platform_take = amount - engineer_payout.
--
--   4. LOW — notify_warranty_fee_waived push body concats
--      round(contracted_amount_rupees) with no precision arg, which
--      returns the rupees truncated to 0 dp ("you'll get the full ₹9"
--      for a ₹9.30 job). No real money loss (the ledger amount is
--      separate), but engineer sees the wrong number and disputes.
--      Fix: format with to_char(..., 'FM999G999G999D00').

-- ---------------------------------------------------------------------
-- 1. get_repair_invoice_payload — residual SGST derivation
-- ---------------------------------------------------------------------
-- Signature preserved (26 cols, same order) so CREATE OR REPLACE
-- doesn't trip 42P13.
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
  v_fy_start_yr  int;
  v_fy_end_yr    int;
  v_invoice_no   text;
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
  -- Round 457 fix #1: residual SGST derivation. cgst + sgst MUST equal
  -- gst_total exactly so the line-item row sums match the totals row.
  -- Without this, GSTR-3B reconciliation breaks for any gst_total
  -- ending in odd paise (very common — every ₹10 invoice).
  v_cgst := round(v_gst_total / 2.0, 2);
  v_sgst := v_gst_total - v_cgst;

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
-- 2. debit_amc_pool_on_visit_complete — snap the last-of-year debit to
-- the remaining envelope so the annual cycle balances to zero.
-- ---------------------------------------------------------------------
-- The trigger fires once per maintenance visit reaching status='completed'.
-- We compute v_per_visit_cost normally for every visit EXCEPT the
-- N-th visit of the current annual cycle, where N = visits_per_year.
-- For that final visit, debit (annual_envelope - sum_of_prior_debits_
-- within_this_cycle) so the running balance lands exactly at the
-- pre-cycle balance + the year's credits = 0 drift.
--
-- "Cycle" = the visits scheduled within the same 12-month window.
-- visits_completed grows monotonically across years (per the round 447
-- modular display fix), so we use modulo to detect the last-of-cycle:
-- (visits_completed + 1) mod visits_per_year == 0.

CREATE OR REPLACE FUNCTION public.debit_amc_pool_on_visit_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_monthly_fee     numeric(10,2);
  v_visits_per_yr   int;
  v_visits_done     int;
  v_per_visit_cost  numeric(10,2);
  v_balance         numeric(10,2);
  v_existing_id     uuid;
  v_annual_envelope numeric(10,2);
  v_cycle_visits_done int;
  v_cycle_prior_debits numeric(10,2);
  v_is_last_of_cycle boolean;
BEGIN
  IF NEW.kind <> 'maintenance' OR NEW.amc_contract_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.status::text <> 'completed' OR OLD.status::text = 'completed' THEN
    RETURN NEW;
  END IF;

  -- Idempotency: skip if we already debited this visit.
  SELECT id INTO v_existing_id
    FROM public.amc_payment_pool
   WHERE source_visit_id = NEW.id AND ledger_kind = 'debit'
   LIMIT 1;
  IF v_existing_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT monthly_fee_rupees, visits_per_year, visits_completed
    INTO v_monthly_fee, v_visits_per_yr, v_visits_done
    FROM public.amc_contracts
   WHERE id = NEW.amc_contract_id
   FOR UPDATE;

  IF v_monthly_fee IS NULL OR v_visits_per_yr IS NULL OR v_visits_per_yr = 0 THEN
    RETURN NEW;
  END IF;

  v_annual_envelope := v_monthly_fee * 12;
  v_per_visit_cost := round(v_annual_envelope / v_visits_per_yr, 2);

  -- Round 457 fix #2: detect last-of-cycle and snap the debit to the
  -- remaining envelope so the annual ledger balances. v_visits_done is
  -- the count BEFORE this visit lands; the visit being processed is
  -- the (v_visits_done + 1)-th overall. Within the current cycle it's
  -- ((v_visits_done) mod visits_per_year) + 1. When that equals
  -- visits_per_year, it's the last-of-cycle.
  v_cycle_visits_done := v_visits_done % v_visits_per_yr;
  v_is_last_of_cycle := (v_cycle_visits_done + 1) = v_visits_per_yr;

  IF v_is_last_of_cycle THEN
    -- Sum prior debits within the same cycle = the last (visits_per_year - 1)
    -- debits on this contract. We pull them in DESC order so a contract
    -- that ran multiple years stays accurate cycle-by-cycle.
    SELECT coalesce(sum(amount_rupees), 0)
      INTO v_cycle_prior_debits
      FROM (
        SELECT amount_rupees
          FROM public.amc_payment_pool
         WHERE amc_contract_id = NEW.amc_contract_id
           AND ledger_kind = 'debit'
         ORDER BY created_at DESC
         LIMIT (v_visits_per_yr - 1)
      ) cycle_debits;

    v_per_visit_cost := greatest(
      round(v_annual_envelope - v_cycle_prior_debits, 2),
      0::numeric
    );
  END IF;

  SELECT coalesce(
           SUM(CASE WHEN ledger_kind = 'debit' THEN -amount_rupees
                    ELSE amount_rupees END),
           0)
       - v_per_visit_cost
    INTO v_balance
    FROM public.amc_payment_pool
    WHERE amc_contract_id = NEW.amc_contract_id;

  INSERT INTO public.amc_payment_pool (
    amc_contract_id, ledger_kind, amount_rupees, balance_after,
    source_visit_id, description
  ) VALUES (
    NEW.amc_contract_id, 'debit', v_per_visit_cost, v_balance,
    NEW.id,
    CASE WHEN v_is_last_of_cycle
         THEN 'AMC visit completion ' || NEW.id::text || ' (cycle-end true-up)'
         ELSE 'AMC visit completion ' || NEW.id::text
    END
  );

  UPDATE public.amc_contracts
     SET visits_completed = visits_completed + 1,
         updated_at = now(),
         status = CASE
           WHEN v_balance < 0 AND status = 'active' THEN 'paused'
           ELSE status
         END
   WHERE id = NEW.amc_contract_id;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.debit_amc_pool_on_visit_complete() FROM PUBLIC;

-- ---------------------------------------------------------------------
-- 3. engineer_my_amc_earnings — residual platform-take derivation
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.engineer_my_amc_earnings()
RETURNS TABLE (
  visit_id uuid,
  visit_completed_at timestamptz,
  amc_contract_id uuid,
  per_visit_cost_rupees numeric,
  engineer_payout_rupees numeric,
  platform_take_rupees numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH my AS (
    SELECT id FROM public.engineers WHERE user_id = auth.uid()
  )
  SELECT
    rj.id AS visit_id,
    rj.completed_at AS visit_completed_at,
    rj.amc_contract_id,
    p.amount_rupees AS per_visit_cost_rupees,
    -- Round 457 fix #3: residual platform-take. round(0.85) then
    -- amount - engineer guarantees engineer + platform = amount for
    -- every per-visit cost. Was two independent round() calls that
    -- drifted by 1 paisa on odd-half-paise inputs.
    round(p.amount_rupees * 0.85, 2) AS engineer_payout_rupees,
    p.amount_rupees - round(p.amount_rupees * 0.85, 2) AS platform_take_rupees
  FROM public.amc_payment_pool p
  JOIN public.repair_jobs rj
    ON rj.id = p.source_visit_id
  WHERE p.ledger_kind = 'debit'
    AND rj.engineer_id IN (SELECT id FROM my)
    AND rj.status::text = 'completed'
  ORDER BY rj.completed_at DESC NULLS LAST
  LIMIT 200;
$$;

ALTER FUNCTION public.engineer_my_amc_earnings() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.engineer_my_amc_earnings() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.engineer_my_amc_earnings() TO authenticated;

-- ---------------------------------------------------------------------
-- 4. notify_warranty_fee_waived — format rupees to 2 dp in push copy
-- ---------------------------------------------------------------------
-- to_char(..., 'FM999G999G999D00') uses the session's lc_numeric for
-- the grouping/decimal separators. We want '₹9.30', so explicitly
-- ride the standard format mask (trim avoids leading whitespace).
-- The Indian-grouping render is handled client-side on display; this
-- push body just needs to surface the correct paise.

CREATE OR REPLACE FUNCTION public.notify_warranty_fee_waived()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_engineer_user uuid;
  v_job_number    text;
  v_amount_text   text;
BEGIN
  IF NEW.status::text <> 'completed' THEN RETURN NEW; END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;
  IF NOT NEW.is_warranty_covered THEN RETURN NEW; END IF;
  IF NEW.engineer_id IS NULL THEN RETURN NEW; END IF;

  SELECT user_id INTO v_engineer_user
    FROM public.engineers WHERE id = NEW.engineer_id;
  IF v_engineer_user IS NULL THEN RETURN NEW; END IF;

  v_job_number := COALESCE(NEW.job_number, substring(NEW.id::text, 1, 8));
  -- Round 457 fix #4: 2-dp format so ₹9.30 stays ₹9.30 (was rendering
  -- as ₹9. because the prior body used round(..., 0)::text).
  v_amount_text := trim(to_char(COALESCE(NEW.contracted_amount_rupees, 0), 'FM999999990.00'));

  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      v_engineer_user,
      'warranty_fee_waived',
      'Platform covered this re-visit',
      concat(
        'Job ', v_job_number,
        ' was within 30-day warranty. EquipSeva covered the platform fee — you''ll get the full ₹',
        v_amount_text, '.'
      ),
      jsonb_build_object(
        'repair_job_id', NEW.id,
        'job_number',    v_job_number,
        'engineer_payout', COALESCE(NEW.engineer_payout, 0)
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'warranty_fee_waived notify failed: % / %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;
ALTER FUNCTION public.notify_warranty_fee_waived() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_warranty_fee_waived() FROM PUBLIC;
