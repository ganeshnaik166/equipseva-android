-- v2.1 PR-C3: AMC auto-create-visits + auto-renewal cron helpers.
--
-- PR-C1 set up amc_contracts with next_visit_at + visit_frequency +
-- auto_renew + renewal_term_months. PR-C2 wired the pre-paid escrow
-- pool. This migration adds the cron-side glue that drives the
-- subscription forward without anyone clicking buttons:
--
--   1. auto_create_due_amc_visits()        — scans contracts where
--      next_visit_at <= now() and creates a maintenance repair_jobs
--      row with engineer_id pre-assigned, advances next_visit_at by
--      visit_frequency, increments visits_scheduled. Engineer picks
--      up the new job from their existing Active Work feed; PR-C5's
--      auto-assign trigger will add the FCM push side-channel.
--
--   2. amc_renewal_attempts                — append-only retry log
--      for renewal charges. Postgres can't reach Razorpay HTTP, so
--      this table is the queue an external worker (scheduled edge
--      fn or cron daemon) drains by id.
--
--   3. auto_renew_expiring_amc_contracts() — scans contracts with
--      end_date inside the 7-day renewal window and queues a fresh
--      attempt row by calling enqueue_amc_renewal_attempt.
--
--   4. enqueue_amc_renewal_attempt(uuid)   — inserts a 'pending' row
--      with attempt_number = max(prior)+1, returns the id.
--
--   5. process_amc_renewal_outcome(uuid, boolean, text, text) — the
--      external worker calls this with the Razorpay outcome. On
--      success: extends end_date by renewal_term_months, creates a
--      paid amc_payment_orders row, calls apply_amc_pool_credit so
--      the pool is topped up. On failure: leaves contract for
--      retry until attempt_number reaches 3, then trips the contract
--      to status='renewal_failed' and disables auto_renew.
--
-- All helpers are SECURITY DEFINER, granted to service_role only.
-- pg_cron wiring at the bottom is guarded behind an extension
-- existence check — Supabase Free tier doesn't expose pg_cron.
--
-- Spec resolution notes:
--   - "years elapsed" cap on visit creation: computed as the floor
--     of months-elapsed / 12 plus 1 (i.e. year 1 = first 12 months,
--     year 2 starts at month 13). The cap = visits_per_year *
--     years_elapsed; if visits_completed + visits_scheduled is
--     already >= cap, we skip creating a new visit but still advance
--     next_visit_at so the contract doesn't deadlock.
--   - "first equipment_categories element": uses array index 1
--     (Postgres arrays are 1-indexed); NULL when array is empty.
--   - amc_visit_number = visits_completed + visits_scheduled + 1
--     (i.e. the next visit's ordinal across the contract lifetime).
--   - Renewal extension on success uses (end_date + N months) via
--     `make_interval(months => renewal_term_months)`; this matches
--     calendar-month semantics and handles end-of-month rollovers.

-- ---------------------------------------------------------------------
-- 1. amc_renewal_attempts retry log table.
-- ---------------------------------------------------------------------
CREATE TABLE public.amc_renewal_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,

  -- Monotonic retry counter scoped per contract. The cron only ever
  -- inserts attempt_number = max(prior)+1; a 3rd consecutive failure
  -- flips the parent contract to 'renewal_failed'.
  attempt_number int NOT NULL CHECK (attempt_number >= 1),

  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','succeeded','failed','abandoned')),

  -- Snapshotted at attempt creation = monthly_fee * renewal_term_months.
  -- Worker passes back razorpay ids on resolution.
  amount_rupees       numeric(10,2),
  razorpay_order_id   text,
  razorpay_payment_id text,
  error_message       text,

  attempted_at timestamptz NOT NULL DEFAULT now(),
  resolved_at  timestamptz
);

CREATE INDEX amc_renewal_attempts_contract_attempt_idx
  ON public.amc_renewal_attempts (amc_contract_id, attempt_number);
CREATE INDEX amc_renewal_attempts_status_idx
  ON public.amc_renewal_attempts (status, attempted_at)
  WHERE status = 'pending';

ALTER TABLE public.amc_renewal_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY amc_renewal_attempts_hospital_own ON public.amc_renewal_attempts
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
      WHERE c.id = amc_renewal_attempts.amc_contract_id
        AND c.hospital_user_id = auth.uid()
    )
  );

CREATE POLICY amc_renewal_attempts_admin_all ON public.amc_renewal_attempts
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()) OR public.is_founder())
  WITH CHECK (public.is_admin(auth.uid()) OR public.is_founder());

-- All writes go through SECURITY DEFINER paths.
REVOKE INSERT, UPDATE, DELETE ON public.amc_renewal_attempts FROM anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. auto_create_due_amc_visits — scan + insert maintenance jobs.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_create_due_amc_visits()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract       public.amc_contracts%ROWTYPE;
  v_advance        interval;
  v_months_elapsed int;
  v_years_elapsed  int;
  v_max_visits     int;
  v_equipment_type text;
  v_job_number     text;
  v_created_count  int := 0;
BEGIN
  -- Lock each candidate row so concurrent invocations of the cron (or
  -- a manual call while pg_cron is also firing) don't double-insert.
  FOR v_contract IN
    SELECT *
      FROM public.amc_contracts
     WHERE status = 'active'
       AND next_visit_at IS NOT NULL
       AND next_visit_at <= now()
     ORDER BY next_visit_at ASC
     FOR UPDATE SKIP LOCKED
  LOOP
    -- Years-elapsed cap: visits_per_year * (year ordinal). One contract
    -- year = 12 calendar months from start_date.
    v_months_elapsed := GREATEST(
      0,
      (EXTRACT(YEAR FROM age(now()::date, v_contract.start_date)) * 12
       + EXTRACT(MONTH FROM age(now()::date, v_contract.start_date)))::int
    );
    v_years_elapsed := (v_months_elapsed / 12) + 1;
    v_max_visits := v_contract.visits_per_year * v_years_elapsed;

    -- Translate visit_frequency into the next-visit advance interval.
    v_advance := CASE v_contract.visit_frequency
      WHEN 'weekly'    THEN interval '7 days'
      WHEN 'biweekly'  THEN interval '14 days'
      WHEN 'monthly'   THEN interval '1 month'
      WHEN 'quarterly' THEN interval '3 months'
      ELSE interval '1 month'
    END;

    -- Cap reached: advance the cursor anyway so we don't busy-loop on
    -- this contract; skip the actual insert.
    IF v_contract.visits_completed + v_contract.visits_scheduled >= v_max_visits THEN
      UPDATE public.amc_contracts
         SET next_visit_at = next_visit_at + v_advance,
             updated_at = now()
       WHERE id = v_contract.id;
      CONTINUE;
    END IF;

    -- engineer_id = engineers.id (FK target). Engineer sees the
    -- new maintenance job in their existing Active Work feed; PR-C5
    -- adds the FCM push side-channel for direct assignments.
    --
    -- site_latitude / site_longitude intentionally left NULL — PR-C5
    -- will resolve hospital coords through the org-membership join.

    v_equipment_type := CASE
      WHEN v_contract.equipment_categories IS NULL THEN NULL
      WHEN array_length(v_contract.equipment_categories, 1) IS NULL THEN NULL
      ELSE v_contract.equipment_categories[1]
    END;

    -- Job number convention: AMC-<contract-prefix>-<visit-ordinal>.
    v_job_number := 'AMC-'
                  || substring(v_contract.id::text, 1, 8)
                  || '-'
                  || lpad((v_contract.visits_completed
                         + v_contract.visits_scheduled + 1)::text, 3, '0');

    -- Create the visit. status='requested' so the existing
    -- engineer-assignment notification trigger fires when engineer_id
    -- is set on the same row.
    INSERT INTO public.repair_jobs (
      job_number,
      hospital_user_id,
      engineer_id,
      kind,
      amc_contract_id,
      amc_visit_number,
      status,
      equipment_type,
      issue_description,
      scheduled_date,
      site_latitude,
      site_longitude,
      contracted_amount_rupees,
      created_at,
      updated_at
    ) VALUES (
      v_job_number,
      v_contract.hospital_user_id,
      v_contract.primary_engineer_id,
      'maintenance',
      v_contract.id,
      v_contract.visits_completed + v_contract.visits_scheduled + 1,
      'requested',
      v_equipment_type,
      coalesce(
        nullif(trim(coalesce(v_contract.scope_text, '')), ''),
        'Scheduled AMC maintenance visit'
      ),
      v_contract.next_visit_at::date,
      NULL,  -- site_latitude  filled by PR-C5
      NULL,  -- site_longitude filled by PR-C5
      0,     -- AMC visit cost is paid from the pre-paid escrow pool.
      now(),
      now()
    );

    -- Advance the contract: bump scheduled count + roll next_visit_at
    -- forward by the cadence.
    UPDATE public.amc_contracts
       SET visits_scheduled = visits_scheduled + 1,
           next_visit_at = next_visit_at + v_advance,
           updated_at = now()
     WHERE id = v_contract.id;

    v_created_count := v_created_count + 1;
  END LOOP;

  RETURN v_created_count;
END;
$$;

ALTER FUNCTION public.auto_create_due_amc_visits() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.auto_create_due_amc_visits() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auto_create_due_amc_visits() TO service_role;

-- ---------------------------------------------------------------------
-- 3. enqueue_amc_renewal_attempt — used by auto-renew scan.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enqueue_amc_renewal_attempt(p_contract_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_next_attempt int;
  v_amount       numeric(10,2);
  v_attempt_id   uuid;
BEGIN
  -- Compute the next attempt ordinal under a row lock on the parent
  -- contract so two concurrent enqueues can't collide.
  PERFORM 1 FROM public.amc_contracts WHERE id = p_contract_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'amc contract % not found', p_contract_id USING ERRCODE = '42704';
  END IF;

  SELECT coalesce(max(attempt_number), 0) + 1
    INTO v_next_attempt
    FROM public.amc_renewal_attempts
    WHERE amc_contract_id = p_contract_id;

  SELECT (monthly_fee_rupees * renewal_term_months)::numeric(10,2)
    INTO v_amount
    FROM public.amc_contracts
    WHERE id = p_contract_id;

  INSERT INTO public.amc_renewal_attempts (
    amc_contract_id, attempt_number, status, amount_rupees
  ) VALUES (
    p_contract_id, v_next_attempt, 'pending', v_amount
  ) RETURNING id INTO v_attempt_id;

  RETURN v_attempt_id;
END;
$$;

ALTER FUNCTION public.enqueue_amc_renewal_attempt(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.enqueue_amc_renewal_attempt(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enqueue_amc_renewal_attempt(uuid) TO service_role;

-- ---------------------------------------------------------------------
-- 4. auto_renew_expiring_amc_contracts — queue renewal attempts.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_renew_expiring_amc_contracts()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract_id   uuid;
  v_queued_count  int := 0;
  v_open_attempts int;
BEGIN
  FOR v_contract_id IN
    SELECT id
      FROM public.amc_contracts
     WHERE status = 'active'
       AND auto_renew = true
       AND end_date <= (now() + interval '7 days')::date
     FOR UPDATE SKIP LOCKED
  LOOP
    -- Skip if there's already an open pending attempt for this
    -- contract — the worker hasn't resolved it yet, queueing another
    -- would race the retry budget.
    SELECT count(*) INTO v_open_attempts
      FROM public.amc_renewal_attempts
      WHERE amc_contract_id = v_contract_id
        AND status = 'pending';

    IF v_open_attempts > 0 THEN
      CONTINUE;
    END IF;

    PERFORM public.enqueue_amc_renewal_attempt(v_contract_id);
    v_queued_count := v_queued_count + 1;
  END LOOP;

  RETURN v_queued_count;
END;
$$;

ALTER FUNCTION public.auto_renew_expiring_amc_contracts() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.auto_renew_expiring_amc_contracts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auto_renew_expiring_amc_contracts() TO service_role;

-- ---------------------------------------------------------------------
-- 5. process_amc_renewal_outcome — worker callback.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_amc_renewal_outcome(
  p_attempt_id    uuid,
  p_succeeded     boolean,
  p_payment_id    text DEFAULT NULL,
  p_error_message text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract_id    uuid;
  v_attempt_number int;
  v_attempt_status text;
  v_amount         numeric(10,2);
  v_monthly_fee    numeric(10,2);
  v_renewal_months int;
  v_payment_order  uuid;
BEGIN
  -- Lock the attempt row so concurrent worker resolutions serialize.
  SELECT amc_contract_id, attempt_number, status, amount_rupees
    INTO v_contract_id, v_attempt_number, v_attempt_status, v_amount
    FROM public.amc_renewal_attempts
    WHERE id = p_attempt_id
    FOR UPDATE;

  IF v_contract_id IS NULL THEN
    RAISE EXCEPTION 'renewal attempt % not found', p_attempt_id USING ERRCODE = '42704';
  END IF;

  -- Idempotency: don't double-resolve.
  IF v_attempt_status <> 'pending' THEN
    RETURN;
  END IF;

  -- Lock the parent contract row — both branches mutate it.
  SELECT monthly_fee_rupees, renewal_term_months
    INTO v_monthly_fee, v_renewal_months
    FROM public.amc_contracts
    WHERE id = v_contract_id
    FOR UPDATE;

  IF v_monthly_fee IS NULL THEN
    RAISE EXCEPTION 'parent contract % missing', v_contract_id USING ERRCODE = '42704';
  END IF;

  IF p_succeeded THEN
    -- Mark attempt succeeded.
    UPDATE public.amc_renewal_attempts
       SET status              = 'succeeded',
           razorpay_payment_id = p_payment_id,
           resolved_at         = now()
     WHERE id = p_attempt_id;

    -- Extend end_date by renewal_term_months (calendar-month math).
    -- Cast back to date — adding an interval to a date returns timestamp.
    UPDATE public.amc_contracts
       SET end_date   = (end_date + make_interval(months => v_renewal_months))::date,
           updated_at = now()
     WHERE id = v_contract_id;

    -- Persist the renewal as a paid amc_payment_orders row, then top
    -- the pool up via the existing PR-C2 credit RPC.
    INSERT INTO public.amc_payment_orders (
      amc_contract_id, months_paid, amount_rupees,
      razorpay_payment_id, status, updated_at
    ) VALUES (
      v_contract_id, v_renewal_months,
      coalesce(v_amount, (v_monthly_fee * v_renewal_months)::numeric(10,2)),
      p_payment_id, 'paid', now()
    ) RETURNING id INTO v_payment_order;

    PERFORM public.apply_amc_pool_credit(v_payment_order);
  ELSE
    -- Failure path. If retry budget remains (attempt < 3), just
    -- record the failure so the cron can re-enqueue on the next
    -- run; if attempt_number = 3, abandon this attempt and trip the
    -- contract.
    IF v_attempt_number < 3 THEN
      UPDATE public.amc_renewal_attempts
         SET status        = 'failed',
             error_message = p_error_message,
             resolved_at   = now()
       WHERE id = p_attempt_id;
    ELSE
      UPDATE public.amc_renewal_attempts
         SET status        = 'abandoned',
             error_message = p_error_message,
             resolved_at   = now()
       WHERE id = p_attempt_id;

      UPDATE public.amc_contracts
         SET status     = 'renewal_failed',
             auto_renew = false,
             updated_at = now()
       WHERE id = v_contract_id;
    END IF;
  END IF;
END;
$$;

ALTER FUNCTION public.process_amc_renewal_outcome(uuid, boolean, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.process_amc_renewal_outcome(uuid, boolean, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_amc_renewal_outcome(uuid, boolean, text, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 6. Optional pg_cron wiring. Guarded behind extension presence so the
-- migration is graceful on Free tier (no pg_cron) and self-installing
-- on Pro+ where pg_cron is available. Operator can also wire these
-- via a Supabase scheduled edge function instead.
-- ---------------------------------------------------------------------
DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- 09:00 UTC daily: create due maintenance visits.
    PERFORM cron.schedule(
      'amc-auto-create-visits',
      '0 9 * * *',
      $job$SELECT public.auto_create_due_amc_visits();$job$
    );
    -- 06:00 UTC daily: queue renewal attempts for contracts expiring
    -- in the next 7 days. External worker drains the queue.
    PERFORM cron.schedule(
      'amc-auto-renew',
      '0 6 * * *',
      $job$SELECT public.auto_renew_expiring_amc_contracts();$job$
    );
  END IF;
EXCEPTION WHEN insufficient_privilege OR undefined_function OR undefined_table THEN
  -- pg_cron not granted on this tier; ignore. Operator wires schedule
  -- via Supabase scheduled edge function or external cron daemon.
  NULL;
END
$cron$;
