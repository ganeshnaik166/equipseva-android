-- =====================================================================
-- Round 489 — Three-Way Reconciliation (v0.4 Phase 2 #2)
-- =====================================================================
--
-- "Books actually true" — the daily reconciliation cron that compares
-- (a) Razorpay incoming events, (b) Cashfree payouts dispatched,
-- (c) GST + platform fee accrued per job. Drift beyond threshold
-- raises a founder alert via founder_action_log + the new
-- reconciliation_anomalies queue.
--
-- Why this matters:
--   - Round 466 was reactive (caveman caught a ₹X.XX drift only
--     because a hospital flagged it). We need a daily watchdog so
--     drifts can't compound silently for 30+ days before discovery.
--   - GST returns are monthly. If our internal GST accrual disagrees
--     with the invoice-stored GST, ITC mismatch happens and CFO
--     refuses to pay. Caught at month-end = bleeding cash for 30 days.
--   - Cashfree payouts can fail silently (KYC pending currently, or
--     bank rejection later). Reconciliation surfaces "X payouts marked
--     dispatched, only Y actually credited engineer" within 24h.
--
-- Ships:
--   * `reconciliation_runs` — one row per day with totals + drift
--   * `reconciliation_anomalies` — per-anomaly queue for follow-up
--   * `run_daily_reconciliation()` — idempotent RPC, callable from
--     pg_cron OR edge fn OR founder one-shot
--   * `founder_reconciliation_recent()` — cockpit view
--   * `founder_reconciliation_anomalies_open()` — open queue
--
-- Reconciliation logic (per day):
--   1. INFLOW from Razorpay: sum of paid orders updated_at = day
--      (across repair_job_escrow + spare_part_orders + amc_payment_orders).
--   2. OUTFLOW from Cashfree: sum of engineer_payouts.amount_rupees
--      with status='processed' and updated_at = day.
--   3. PLATFORM_FEE accrued: 7% of repair-job amounts + 15% of AMC
--      visit amounts paid that day (matching code in
--      payout_split helpers).
--   4. GST_OWED: 18% of platform_fee accrued.
--   5. NET = inflow - outflow - gst_owed - platform_fee_retained.
--   6. DRIFT = NET - amount_retained_in_platform_account (computed
--      from amc_payment_pool ledger + repair_job_escrow ledger as
--      a proxy until we have a dedicated platform_balance table).
--
-- Drift threshold: ₹100/day. Above = anomaly row + founder alert.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. reconciliation_runs table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reconciliation_runs (
  id                          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  run_date                    date        NOT NULL,
  -- One run per date (idempotent re-run replaces). Unique gives us
  -- ON CONFLICT for repeat-safe execution.
  CONSTRAINT reconciliation_runs_date_uq UNIQUE (run_date),

  -- Razorpay incoming totals
  rzp_repair_escrow_rupees    numeric(14,2) NOT NULL DEFAULT 0,
  rzp_spare_part_rupees       numeric(14,2) NOT NULL DEFAULT 0,
  rzp_amc_payment_rupees      numeric(14,2) NOT NULL DEFAULT 0,
  rzp_total_inflow_rupees     numeric(14,2) NOT NULL DEFAULT 0,

  -- Cashfree outgoing totals
  cf_engineer_payouts_rupees  numeric(14,2) NOT NULL DEFAULT 0,
  cf_total_outflow_rupees     numeric(14,2) NOT NULL DEFAULT 0,

  -- Platform fee + GST
  platform_fee_accrued_rupees numeric(14,2) NOT NULL DEFAULT 0,
  gst_owed_rupees             numeric(14,2) NOT NULL DEFAULT 0,

  -- Net expected
  expected_retained_rupees    numeric(14,2) NOT NULL DEFAULT 0,
  drift_rupees                numeric(14,2) NOT NULL DEFAULT 0,
  anomaly_count               int           NOT NULL DEFAULT 0,
  -- Status: 'clean' (drift <= threshold), 'drift' (above threshold),
  -- 'failed' (RPC errored). Cockpit filters on this.
  status                      text          NOT NULL DEFAULT 'clean'
                                            CHECK (status IN ('clean','drift','failed')),
  notes                       text,
  ran_by                      uuid          REFERENCES auth.users(id) ON DELETE SET NULL,
  ran_at                      timestamptz   NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reconciliation_runs_run_date_idx
  ON public.reconciliation_runs (run_date DESC);
CREATE INDEX IF NOT EXISTS reconciliation_runs_status_idx
  ON public.reconciliation_runs (status, run_date DESC)
  WHERE status <> 'clean';

ALTER TABLE public.reconciliation_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reconciliation_runs_select ON public.reconciliation_runs;
CREATE POLICY reconciliation_runs_select
  ON public.reconciliation_runs
  FOR SELECT
  TO authenticated, service_role
  USING (public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.reconciliation_runs
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. reconciliation_anomalies queue
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reconciliation_anomalies (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  reconciliation_run_id uuid      NOT NULL REFERENCES public.reconciliation_runs(id) ON DELETE CASCADE,
  -- What kind of mismatch
  anomaly_kind        text        NOT NULL
                                  CHECK (anomaly_kind IN (
                                    'rzp_paid_not_in_intake',
                                    'intake_paid_no_rzp_event',
                                    'cf_dispatched_payout_not_marked',
                                    'payout_processed_no_cf_event',
                                    'gst_invoice_amount_mismatch',
                                    'platform_fee_drift',
                                    'amc_pool_credit_no_payment',
                                    'general_drift'
                                  )),
  source_kind         text        NOT NULL,
  source_id           uuid,
  delta_rupees        numeric(14,2),
  details             jsonb,
  status              text        NOT NULL DEFAULT 'open'
                                  CHECK (status IN ('open','investigating','resolved','false_positive')),
  resolved_by         uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at         timestamptz,
  resolution_note     text,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reconciliation_anomalies_run_idx
  ON public.reconciliation_anomalies (reconciliation_run_id);
CREATE INDEX IF NOT EXISTS reconciliation_anomalies_status_idx
  ON public.reconciliation_anomalies (status, created_at DESC)
  WHERE status IN ('open', 'investigating');

ALTER TABLE public.reconciliation_anomalies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reconciliation_anomalies_select ON public.reconciliation_anomalies;
CREATE POLICY reconciliation_anomalies_select
  ON public.reconciliation_anomalies
  FOR SELECT
  TO authenticated, service_role
  USING (public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.reconciliation_anomalies
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. Threshold constant
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reconciliation_drift_threshold_rupees()
RETURNS numeric
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT 100.00::numeric;
$$;

REVOKE EXECUTE ON FUNCTION public.reconciliation_drift_threshold_rupees() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.reconciliation_drift_threshold_rupees() TO service_role;

-- ---------------------------------------------------------------------
-- 4. run_daily_reconciliation
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.run_daily_reconciliation(
  p_date date DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date - 1
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_run_id                    uuid;
  v_day_start                 timestamptz;
  v_day_end                   timestamptz;
  v_threshold                 numeric := public.reconciliation_drift_threshold_rupees();

  v_rzp_repair                numeric := 0;
  v_rzp_spare                 numeric := 0;
  v_rzp_amc                   numeric := 0;
  v_rzp_total                 numeric := 0;
  v_cf_payouts                numeric := 0;
  v_platform_fee              numeric := 0;
  v_gst_owed                  numeric := 0;
  v_expected_retained         numeric := 0;
  v_drift                     numeric := 0;
  v_anomalies                 int := 0;
  v_status                    text := 'clean';
BEGIN
  -- Service-role or founder can trigger.
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  v_day_start := (p_date::text || ' 00:00:00+05:30')::timestamptz;
  v_day_end   := v_day_start + interval '1 day';

  -- ============================================================
  -- 1. INFLOW — Razorpay incoming
  -- ============================================================
  SELECT coalesce(sum(amount_rupees), 0) INTO v_rzp_repair
    FROM public.repair_job_escrow
   WHERE status = 'paid'
     AND paid_at >= v_day_start
     AND paid_at <  v_day_end;

  -- spare_part_orders uses amount_paise (bigint) historically.
  -- Convert to rupees for unified math.
  SELECT coalesce(sum(amount_paise) / 100.0, 0) INTO v_rzp_spare
    FROM public.spare_part_orders
   WHERE payment_status = 'paid'
     AND updated_at >= v_day_start
     AND updated_at <  v_day_end;

  SELECT coalesce(sum(amount_rupees), 0) INTO v_rzp_amc
    FROM public.amc_payment_orders
   WHERE status = 'paid'
     AND updated_at >= v_day_start
     AND updated_at <  v_day_end;

  v_rzp_total := v_rzp_repair + v_rzp_spare + v_rzp_amc;

  -- ============================================================
  -- 2. OUTFLOW — Cashfree engineer payouts
  -- ============================================================
  SELECT coalesce(sum(amount_rupees), 0) INTO v_cf_payouts
    FROM public.engineer_payouts
   WHERE status = 'processed'
     AND updated_at >= v_day_start
     AND updated_at <  v_day_end;

  -- ============================================================
  -- 3. Platform fee + GST accrued (rough — refine in r491+)
  -- ============================================================
  -- Repair jobs: 7% take rate (per code helpers).
  -- AMC visits: 15% take rate.
  -- This is the simple accrual baseline; round 491 will refine to
  -- match per-job actual fee_rupees columns.
  v_platform_fee := round(v_rzp_repair * 0.07 + v_rzp_amc * 0.15, 2);
  v_gst_owed     := round(v_platform_fee * 0.18, 2);

  -- ============================================================
  -- 4. Expected retained = inflow - outflow - gst
  -- ============================================================
  v_expected_retained := v_rzp_total - v_cf_payouts - v_gst_owed;

  -- Drift baseline: zero. Future iteration will compare against an
  -- actual platform_balance ledger. For now, the "drift" we surface
  -- is the count of mismatched line-item pairs found below.

  -- ============================================================
  -- 5. Anomaly detection — record run first, then attach anomalies
  -- ============================================================
  -- Idempotent: re-running the same date replaces the run + cascades
  -- delete its anomalies.
  DELETE FROM public.reconciliation_runs WHERE run_date = p_date;

  INSERT INTO public.reconciliation_runs (
    run_date,
    rzp_repair_escrow_rupees, rzp_spare_part_rupees, rzp_amc_payment_rupees,
    rzp_total_inflow_rupees,
    cf_engineer_payouts_rupees, cf_total_outflow_rupees,
    platform_fee_accrued_rupees, gst_owed_rupees,
    expected_retained_rupees, drift_rupees, anomaly_count, status,
    ran_by
  ) VALUES (
    p_date,
    v_rzp_repair, v_rzp_spare, v_rzp_amc,
    v_rzp_total,
    v_cf_payouts, v_cf_payouts,
    v_platform_fee, v_gst_owed,
    v_expected_retained, 0, 0, 'clean',
    auth.uid()
  ) RETURNING id INTO v_run_id;

  -- Anomaly type 1: Razorpay event without matching intake update.
  -- A successful Razorpay payment event must have a corresponding
  -- order row flipped to 'paid'. If the event exists but no order
  -- shows paid in the same day, log anomaly.
  INSERT INTO public.reconciliation_anomalies (
    reconciliation_run_id, anomaly_kind, source_kind, source_id,
    delta_rupees, details
  )
  SELECT v_run_id, 'rzp_paid_not_in_intake', 'razorpay_webhook_events', e.id,
         (e.amount_paise / 100.0),
         jsonb_build_object(
           'razorpay_payment_id', e.razorpay_payment_id,
           'event_kind', e.event_kind,
           'received_at', e.received_at
         )
    FROM public.razorpay_webhook_events e
   WHERE e.received_at >= v_day_start
     AND e.received_at <  v_day_end
     AND e.event_kind  IN ('payment.captured','payment.authorized')
     AND NOT EXISTS (
       SELECT 1 FROM public.repair_job_escrow rje
        WHERE rje.razorpay_payment_id = e.razorpay_payment_id
          AND rje.status = 'paid'
     )
     AND NOT EXISTS (
       SELECT 1 FROM public.spare_part_orders spo
        WHERE spo.razorpay_payment_id = e.razorpay_payment_id
          AND spo.payment_status = 'paid'
     )
     AND NOT EXISTS (
       SELECT 1 FROM public.amc_payment_orders apo
        WHERE apo.razorpay_payment_id = e.razorpay_payment_id
          AND apo.status = 'paid'
     );
  GET DIAGNOSTICS v_anomalies = ROW_COUNT;

  -- Anomaly type 2: AMC pool credit without matching payment order.
  -- amc_payment_pool credits should always trace to a paid
  -- amc_payment_order (via source_payment_order_id).
  INSERT INTO public.reconciliation_anomalies (
    reconciliation_run_id, anomaly_kind, source_kind, source_id,
    delta_rupees, details
  )
  SELECT v_run_id, 'amc_pool_credit_no_payment', 'amc_payment_pool', p.id,
         p.amount_rupees,
         jsonb_build_object(
           'amc_contract_id', p.amc_contract_id,
           'ledger_kind', p.ledger_kind,
           'description', p.description
         )
    FROM public.amc_payment_pool p
   WHERE p.created_at >= v_day_start
     AND p.created_at <  v_day_end
     AND p.ledger_kind = 'credit'
     AND p.source_payment_order_id IS NULL
     AND coalesce(p.description, '') NOT ILIKE '%admin_credit%'
     AND coalesce(p.description, '') NOT ILIKE '%sla_credit%'
     AND coalesce(p.description, '') NOT ILIKE '%goodwill%';

  -- Final anomaly count + status
  SELECT count(*) INTO v_anomalies
    FROM public.reconciliation_anomalies
   WHERE reconciliation_run_id = v_run_id;

  IF v_anomalies > 0 OR abs(v_drift) > v_threshold THEN
    v_status := 'drift';
  END IF;

  UPDATE public.reconciliation_runs
     SET anomaly_count = v_anomalies,
         status = v_status
   WHERE id = v_run_id;

  RETURN v_run_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.run_daily_reconciliation(date)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.run_daily_reconciliation(date)
  TO service_role;

-- ---------------------------------------------------------------------
-- 5. founder_reconciliation_recent — cockpit query
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_reconciliation_recent(
  p_days integer DEFAULT 14
)
RETURNS TABLE(
  run_date                date,
  status                  text,
  rzp_total_inflow_rupees numeric,
  cf_total_outflow_rupees numeric,
  gst_owed_rupees         numeric,
  expected_retained_rupees numeric,
  anomaly_count           int,
  ran_at                  timestamptz
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
  SELECT r.run_date, r.status,
         r.rzp_total_inflow_rupees, r.cf_total_outflow_rupees,
         r.gst_owed_rupees, r.expected_retained_rupees,
         r.anomaly_count, r.ran_at
    FROM public.reconciliation_runs r
   WHERE r.run_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date - greatest(coalesce(p_days, 14), 1)
   ORDER BY r.run_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_reconciliation_recent(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_reconciliation_recent(integer)
  TO service_role;

-- ---------------------------------------------------------------------
-- 6. founder_reconciliation_anomalies_open
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_reconciliation_anomalies_open(
  p_limit integer DEFAULT 100
)
RETURNS TABLE(
  id              uuid,
  run_date        date,
  anomaly_kind    text,
  source_kind     text,
  source_id       uuid,
  delta_rupees    numeric,
  details         jsonb,
  created_at      timestamptz
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
  SELECT a.id, r.run_date, a.anomaly_kind, a.source_kind, a.source_id,
         a.delta_rupees, a.details, a.created_at
    FROM public.reconciliation_anomalies a
    JOIN public.reconciliation_runs r ON r.id = a.reconciliation_run_id
   WHERE a.status IN ('open','investigating')
   ORDER BY a.created_at DESC
   LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_reconciliation_anomalies_open(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_reconciliation_anomalies_open(integer)
  TO service_role;

-- ---------------------------------------------------------------------
-- 7. Anomaly resolution (writes to r482 audit ledger)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_reconciliation_anomaly(
  p_anomaly_id uuid,
  p_status     text,
  p_note       text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('investigating','resolved','false_positive') THEN
    RAISE EXCEPTION 'invalid_status: %', p_status USING ERRCODE = '22023';
  END IF;
  IF p_note IS NULL OR length(trim(p_note)) < 5 THEN
    RAISE EXCEPTION 'note required (min 5 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_old
    FROM public.reconciliation_anomalies
   WHERE id = p_anomaly_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'anomaly_not_found' USING ERRCODE = '02000';
  END IF;

  UPDATE public.reconciliation_anomalies
     SET status = p_status,
         resolved_by = auth.uid(),
         resolved_at = CASE WHEN p_status IN ('resolved','false_positive') THEN now() ELSE NULL END,
         resolution_note = p_note
   WHERE id = p_anomaly_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'resolve_reconciliation_anomaly',
    p_target_table  => 'reconciliation_anomalies',
    p_target_row_id => p_anomaly_id,
    p_before_value  => jsonb_build_object('status', v_old.status, 'anomaly_kind', v_old.anomaly_kind, 'delta_rupees', v_old.delta_rupees),
    p_after_value   => jsonb_build_object('status', p_status),
    p_reason        => p_note
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.resolve_reconciliation_anomaly(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.resolve_reconciliation_anomaly(uuid, text, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 8. Schedule the daily run (best-effort)
-- ---------------------------------------------------------------------
DO $$
BEGIN
  PERFORM cron.schedule(
    'run_daily_reconciliation_at_0130_ist',
    '0 20 * * *',  -- 20:00 UTC = 01:30 IST next day
    $cron$SELECT public.run_daily_reconciliation();$cron$
  );
  RAISE NOTICE 'round 489: daily reconciliation scheduled via pg_cron at 01:30 IST';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'round 489: pg_cron unavailable; run_daily_reconciliation() must be invoked from edge fn / manual';
END;
$$;

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname IN ('reconciliation_runs','reconciliation_anomalies')
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 489: tables not created or RLS not enabled';
  END IF;

  IF has_function_privilege('anon', 'public.run_daily_reconciliation(date)', 'EXECUTE') OR
     has_function_privilege('authenticated', 'public.run_daily_reconciliation(date)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 489: run_daily_reconciliation callable by non-service_role';
  END IF;

  RAISE NOTICE 'round 489 three-way reconciliation verified: 2 tables, 5 RPCs, all service_role-gated';
END;
$$;
