-- v2.1 PR-C4: AMC SLA breach detection + automatic credit issuance.
--
-- AMC contracts (PR-C1) carry response_time_standard_hours and
-- response_time_emergency_hours targets. Until now those fields were
-- written into the contract on creation but nothing watched them. This
-- migration adds the watch-dog:
--
--   * Whenever an AMC maintenance repair_jobs row transitions through
--     'assigned' / 'en_route' / 'in_progress' the trigger compares the
--     elapsed time (since repair_jobs.created_at) against the contract
--     SLA. If we missed the window we record a breach in
--     amc_sla_breaches and issue a goodwill credit back into the
--     hospital's AMC payment pool (PR-C2 ledger).
--
--   * Each breach also auto-fires a push notification (re-using the
--     notifications-table pattern from
--     20260428020000_engineer_side_push_event_triggers.sql) to both the
--     hospital and the assigned engineer (when one is assigned).
--
-- Severity decision: there's no `repair_jobs.severity` column today, so
-- v2.1 derives "this is an emergency contract" from the contract's
-- equipment_categories array. If it contains 'emergency' or
-- 'life_support' the visit is treated as emergency (uses
-- response_time_emergency_hours); otherwise standard. This is the same
-- heuristic the matching layer will adopt in PR-C5.
--
-- Credit math: 25% of the per-visit cost
-- (monthly_fee_rupees * 12 / visits_per_year * 0.25). Goodwill credit,
-- not full refund — we still expect the engineer to complete the visit.
--
-- Idempotency: a UNIQUE INDEX on (amc_contract_id, visit_id, breach_type)
-- prevents the trigger firing multiple times for the same logical
-- breach as the visit moves through its status timeline.
--
-- Ledger separation: PR-C2 already had unique partial indexes on
-- amc_payment_pool keyed by source_payment_order_id (credits) and
-- source_visit_id (debits). SLA credits ALSO reference a visit but as
-- a CREDIT not a debit, so they don't collide with the debit unique
-- index. To keep provenance crystal clear and to allow multiple
-- distinct breaches per visit (response_time + no_show, etc.) to each
-- carry their own credit row, we add a new column
-- amc_payment_pool.source_breach_id which the SLA path uses (not the
-- Razorpay-credit path). A unique partial index on source_breach_id
-- guarantees one credit row per breach.

-- ---------------------------------------------------------------------------
-- 1. amc_payment_pool.source_breach_id — wiring before we create the
--    breaches table itself, then we round-trip the FK back to it after.
-- ---------------------------------------------------------------------------
ALTER TABLE public.amc_payment_pool
  ADD COLUMN IF NOT EXISTS source_breach_id uuid;

-- ---------------------------------------------------------------------------
-- 2. amc_sla_breaches — the breach ledger.
-- ---------------------------------------------------------------------------
CREATE TABLE public.amc_sla_breaches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  visit_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,

  breach_type text NOT NULL
    CHECK (breach_type IN ('response_time','no_show','quality')),
  severity    text NOT NULL DEFAULT 'standard'
    CHECK (severity IN ('emergency','standard')),

  expected_within_hours int NOT NULL CHECK (expected_within_hours > 0),
  actual_hours          numeric(10,2),

  credit_issued_rupees numeric(10,2) NOT NULL DEFAULT 0
    CHECK (credit_issued_rupees >= 0),
  -- Forward-pointer back into the ledger row generated for this breach.
  -- Nullable in case we ever record a breach that issued no credit
  -- (e.g. quality breaches resolved by service-credit elsewhere).
  credit_ledger_id uuid REFERENCES public.amc_payment_pool(id),

  notes text,
  detected_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX amc_sla_breaches_contract_detected_idx
  ON public.amc_sla_breaches (amc_contract_id, detected_at DESC);
CREATE INDEX amc_sla_breaches_open_idx
  ON public.amc_sla_breaches (amc_contract_id) WHERE resolved_at IS NULL;
-- Idempotency guard: at most one breach row per (contract, visit, type).
CREATE UNIQUE INDEX amc_sla_breaches_unique_per_visit_type_uidx
  ON public.amc_sla_breaches (amc_contract_id, visit_id, breach_type)
  WHERE visit_id IS NOT NULL;

-- Now wire up the back-reference FK on the ledger column we added in (1).
ALTER TABLE public.amc_payment_pool
  ADD CONSTRAINT amc_payment_pool_source_breach_id_fkey
  FOREIGN KEY (source_breach_id) REFERENCES public.amc_sla_breaches(id);

-- And one credit row per breach — keeps the trigger replay-safe.
CREATE UNIQUE INDEX amc_payment_pool_credit_per_breach_uidx
  ON public.amc_payment_pool (source_breach_id)
  WHERE source_breach_id IS NOT NULL AND ledger_kind = 'credit';

-- ---------------------------------------------------------------------------
-- 3. RLS — same pattern as amc_payment_pool: hospital sees own (via the
--    parent contract), engineer sees breaches on visits they're the
--    assigned engineer for, admin/founder bypass. Client writes are
--    revoked entirely; only the SECURITY DEFINER trigger inserts.
-- ---------------------------------------------------------------------------
ALTER TABLE public.amc_sla_breaches ENABLE ROW LEVEL SECURITY;

CREATE POLICY amc_sla_breaches_hospital_own ON public.amc_sla_breaches
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
      WHERE c.id = amc_sla_breaches.amc_contract_id
        AND c.hospital_user_id = auth.uid()
    )
  );

CREATE POLICY amc_sla_breaches_engineer_assigned ON public.amc_sla_breaches
  FOR SELECT
  USING (
    -- Either the assigned engineer on the breaching visit, or any
    -- engineer in the contract's rotation (so the rotation engineer
    -- sees breaches even when re-assignment is mid-flight).
    EXISTS (
      SELECT 1
      FROM public.repair_jobs rj
      JOIN public.engineers e ON e.id = rj.engineer_id
      WHERE rj.id = amc_sla_breaches.visit_id
        AND e.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM public.amc_engineer_rotation r
      JOIN public.engineers e ON e.id = r.engineer_id
      WHERE r.amc_contract_id = amc_sla_breaches.amc_contract_id
        AND r.active = true
        AND e.user_id = auth.uid()
    )
  );

CREATE POLICY amc_sla_breaches_admin_all ON public.amc_sla_breaches
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()) OR public.is_founder())
  WITH CHECK (public.is_admin(auth.uid()) OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.amc_sla_breaches FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. SLA-check trigger. Fires on AMC maintenance visits when status
--    advances to assigned / en_route / in_progress. Compares elapsed
--    time since the visit was created against the contract SLA target;
--    if we exceeded it, INSERTs a breach row + a credit ledger row.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_amc_sla_on_visit_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract            public.amc_contracts%ROWTYPE;
  v_is_emergency        boolean;
  v_severity            text;
  v_target_hours        int;
  v_elapsed_hours       numeric(10,2);
  v_existing_breach_id  uuid;
  v_per_visit_cost      numeric(10,2);
  v_credit_amount       numeric(10,2);
  v_running_balance     numeric(10,2);
  v_breach_id           uuid;
  v_ledger_id           uuid;
BEGIN
  -- Only fires on the three "did the engineer show up in time" status
  -- gates. Completion is already covered by the prior gates and by the
  -- per-visit debit trigger (PR-C2).
  IF NEW.status::text NOT IN ('assigned','en_route','in_progress') THEN
    RETURN NEW;
  END IF;
  IF OLD.status::text = NEW.status::text THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_contract
    FROM public.amc_contracts
    WHERE id = NEW.amc_contract_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  -- v2.1 severity heuristic: emergency contract iff equipment_categories
  -- contains 'emergency' or 'life_support'. PR-C5 will replace this
  -- with a per-visit severity column once we wire ICU/ED triage flows.
  v_is_emergency := (
    v_contract.equipment_categories && ARRAY['emergency','life_support']::text[]
  );
  IF v_is_emergency THEN
    v_severity     := 'emergency';
    v_target_hours := v_contract.response_time_emergency_hours;
  ELSE
    v_severity     := 'standard';
    v_target_hours := v_contract.response_time_standard_hours;
  END IF;

  v_elapsed_hours := round(
    EXTRACT(EPOCH FROM (now() - NEW.created_at))::numeric / 3600.0, 2
  );

  -- Within window — nothing to record.
  IF v_elapsed_hours <= v_target_hours THEN
    RETURN NEW;
  END IF;

  -- Idempotency: skip if a response_time breach is already recorded
  -- for this visit (the next status-change replay would otherwise
  -- generate a duplicate row). The unique partial index is the hard
  -- guard; this fast-path avoids a constraint violation in the
  -- happy retry case.
  SELECT id INTO v_existing_breach_id
    FROM public.amc_sla_breaches
    WHERE amc_contract_id = NEW.amc_contract_id
      AND visit_id        = NEW.id
      AND breach_type     = 'response_time'
    LIMIT 1;
  IF v_existing_breach_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Goodwill credit = 25% of the visit's fair share of the annual
  -- envelope. Caps at 10000 rupees defensively in case of malformed
  -- contract numbers.
  v_per_visit_cost := round(
    v_contract.monthly_fee_rupees * 12::numeric / v_contract.visits_per_year, 2
  );
  v_credit_amount := least(round(v_per_visit_cost * 0.25, 2), 10000::numeric);

  IF v_credit_amount <= 0 THEN
    -- Edge case: contract numbers funky; record the breach without a
    -- credit so the hospital still sees the SLA miss in the UI.
    INSERT INTO public.amc_sla_breaches (
      amc_contract_id, visit_id, breach_type, severity,
      expected_within_hours, actual_hours, credit_issued_rupees, notes
    ) VALUES (
      NEW.amc_contract_id, NEW.id, 'response_time', v_severity,
      v_target_hours, v_elapsed_hours, 0,
      'response_time SLA exceeded; no credit issued (per_visit_cost <= 0)'
    );
    RETURN NEW;
  END IF;

  -- Insert the breach first so we have an id to anchor the ledger
  -- credit on (the unique partial index keys on source_breach_id).
  INSERT INTO public.amc_sla_breaches (
    amc_contract_id, visit_id, breach_type, severity,
    expected_within_hours, actual_hours, credit_issued_rupees, notes
  ) VALUES (
    NEW.amc_contract_id, NEW.id, 'response_time', v_severity,
    v_target_hours, v_elapsed_hours, v_credit_amount,
    concat('SLA miss on visit ', NEW.id, ': ',
           v_elapsed_hours, 'h vs ', v_target_hours, 'h target (',
           v_severity, ').')
  ) RETURNING id INTO v_breach_id;

  -- Snapshot the running balance, then add the credit row. Same signed
  -- sum derivation as apply_amc_pool_credit / debit_amc_pool_on_visit_complete.
  SELECT coalesce(
           SUM(CASE WHEN ledger_kind = 'debit' THEN -amount_rupees
                    ELSE amount_rupees END),
           0)
       + v_credit_amount
    INTO v_running_balance
    FROM public.amc_payment_pool
    WHERE amc_contract_id = NEW.amc_contract_id;

  INSERT INTO public.amc_payment_pool (
    amc_contract_id, ledger_kind, amount_rupees, balance_after,
    source_visit_id, source_breach_id, description
  ) VALUES (
    NEW.amc_contract_id, 'credit', v_credit_amount, v_running_balance,
    NEW.id, v_breach_id,
    concat('SLA goodwill credit (response_time, ', v_severity, ')')
  ) RETURNING id INTO v_ledger_id;

  -- Round-trip the ledger id back onto the breach for the UI.
  UPDATE public.amc_sla_breaches
     SET credit_ledger_id = v_ledger_id
     WHERE id = v_breach_id;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_amc_sla_on_visit_status_change() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_check_amc_sla_on_visit_status_change ON public.repair_jobs;
CREATE TRIGGER trg_check_amc_sla_on_visit_status_change
  AFTER UPDATE OF status ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.kind = 'maintenance' AND NEW.amc_contract_id IS NOT NULL)
  EXECUTE FUNCTION public.check_amc_sla_on_visit_status_change();

-- ---------------------------------------------------------------------------
-- 5. notify_on_amc_sla_breach — push fan-out to hospital + engineer.
--    Same defensive shape as the engineer-side triggers added in
--    20260428020000: SECURITY DEFINER, never roll back the parent insert
--    on a notification failure, log + continue.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_on_amc_sla_breach()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_hospital_user_id uuid;
  v_engineer_user_id uuid;
  v_visit_number     text;
  v_title            text;
  v_body             text;
  v_data             jsonb;
BEGIN
  SELECT c.hospital_user_id INTO v_hospital_user_id
    FROM public.amc_contracts c
    WHERE c.id = NEW.amc_contract_id;

  IF NEW.visit_id IS NOT NULL THEN
    SELECT rj.job_number, e.user_id
      INTO v_visit_number, v_engineer_user_id
      FROM public.repair_jobs rj
      LEFT JOIN public.engineers e ON e.id = rj.engineer_id
      WHERE rj.id = NEW.visit_id;
  END IF;

  v_title := CASE
    WHEN NEW.severity = 'emergency' THEN 'Emergency SLA missed'
    ELSE 'AMC SLA missed'
  END;
  v_body  := concat(
    'Visit ',
    coalesce(v_visit_number, substring(NEW.visit_id::text, 1, 8)),
    ' missed the ', NEW.expected_within_hours, 'h response window.',
    CASE
      WHEN NEW.credit_issued_rupees > 0
        THEN concat(' A goodwill credit of Rs. ',
                    NEW.credit_issued_rupees,
                    ' has been added to your AMC pool.')
      ELSE ''
    END
  );
  v_data := jsonb_build_object(
    'amc_contract_id',       NEW.amc_contract_id,
    'visit_id',              NEW.visit_id,
    'breach_id',             NEW.id,
    'breach_type',           NEW.breach_type,
    'severity',              NEW.severity,
    'expected_within_hours', NEW.expected_within_hours,
    'actual_hours',          NEW.actual_hours,
    'credit_issued_rupees',  NEW.credit_issued_rupees
  );

  IF v_hospital_user_id IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (v_hospital_user_id, 'amc_sla_breach', v_title, v_body, v_data);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'notify_on_amc_sla_breach: hospital insert failed: % / %',
        SQLSTATE, SQLERRM;
    END;
  END IF;

  -- Don't push to the engineer when they ARE the hospital (impossible
  -- in practice but defensive).
  IF v_engineer_user_id IS NOT NULL
     AND v_engineer_user_id IS DISTINCT FROM v_hospital_user_id THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (v_engineer_user_id, 'amc_sla_breach', v_title, v_body, v_data);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'notify_on_amc_sla_breach: engineer insert failed: % / %',
        SQLSTATE, SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.notify_on_amc_sla_breach() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_amc_sla_breach ON public.amc_sla_breaches;
CREATE TRIGGER notify_on_amc_sla_breach
  AFTER INSERT ON public.amc_sla_breaches
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_amc_sla_breach();

-- ---------------------------------------------------------------------------
-- 6. Convenience RPC for the hospital UI. STABLE + SECURITY INVOKER —
--    relies on amc_sla_breaches RLS (hospital_own policy above) to scope
--    rows. We still gate by p_contract_id so a hospital can't drag in
--    breaches across all their contracts at once unintentionally.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_amc_sla_breaches_for_contract(
  p_contract_id uuid
)
RETURNS TABLE (
  breach_id             uuid,
  visit_id              uuid,
  visit_code            text,
  breach_type           text,
  severity              text,
  expected_within_hours int,
  actual_hours          numeric,
  credit_issued_rupees  numeric,
  detected_at           timestamptz,
  resolved_at           timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT
    b.id              AS breach_id,
    b.visit_id        AS visit_id,
    rj.job_number     AS visit_code,
    b.breach_type,
    b.severity,
    b.expected_within_hours,
    b.actual_hours,
    b.credit_issued_rupees,
    b.detected_at,
    b.resolved_at
  FROM public.amc_sla_breaches b
  LEFT JOIN public.repair_jobs rj ON rj.id = b.visit_id
  WHERE b.amc_contract_id = p_contract_id
  ORDER BY b.detected_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.list_amc_sla_breaches_for_contract(uuid)
  TO authenticated;
