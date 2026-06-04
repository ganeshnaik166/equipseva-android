-- Round 446 — close 6 HIGH findings from the 2026-06-04 audit:
--
--   1. AMC SLA tracker never fires for auto-created visits (the trigger
--      gates on UPDATE OF status only). When engineer NEVER responds —
--      the exact case SLA tracking exists to catch — no breach row gets
--      inserted, no goodwill credit, no admin push. Silent failure of
--      the entire AMC SLA guardrail.
--
--   2. auto_create_due_amc_visits — INSERT/UPDATE not wrapped in
--      per-row EXCEPTION. One bad row (FK violation, future NOT NULL,
--      unique violation on job_number) strands the whole batch — the
--      same shape that hid the round 442 enum-cast bug.
--
--   3. auto_create_due_amc_visits assigns visits to primary engineer
--      without re-checking is_available + verified. Stale primaries
--      (quit, de-verified, set themselves unavailable) keep getting
--      pushed visits forever.
--
--   4. edit_my_chat_message SECDEF RPC bypasses chat_messages PII mask
--      trigger (trigger is BEFORE INSERT only, RPC does UPDATE). A
--      hospital can send a benign message then edit it to include a
--      raw phone/email and dodge the platform-keep guardrail.
--
--   5. re_rotate_on_engineer_unavailable notifies new engineer +
--      hospital but never tells the displaced primary they lost the
--      visit. Their UI still shows the assignment, leading to confused
--      side-by-side state when they flip back available.
--
--   6. get_repair_job_escrow RPC missing engineer_response columns —
--      Android EscrowRow declares them but the server SELECT never
--      includes them. Hospital never sees the engineer's PR-D29
--      dispute rebuttal.

-- ---------------------------------------------------------------------
-- 1. AMC SLA sweep for unresponded auto-created visits
-- ---------------------------------------------------------------------
-- The existing trigger trg_check_amc_sla_on_visit_status_change only
-- fires AFTER UPDATE OF status. Manually-created repair_jobs hit it on
-- the engineer's first status flip. Auto-created visits stay at
-- status='requested' if the engineer never responds — exactly the case
-- SLA tracking should catch.
--
-- Fix: periodic sweep RPC that scans 'requested' maintenance visits
-- past their response window and inserts the breach row (+ goodwill
-- credit) via the same logic the trigger uses. Idempotent via the
-- existing partial-unique index on (amc_contract_id, visit_id,
-- breach_type='response_time').

CREATE OR REPLACE FUNCTION public.sweep_amc_sla_unresponded_visits()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_visit            record;
  v_contract         public.amc_contracts%ROWTYPE;
  v_severity         text;
  v_target_hours     numeric;
  v_elapsed_hours    numeric;
  v_per_visit_cost   numeric;
  v_credit_amount    numeric;
  v_breach_id        uuid;
  v_ledger_id        uuid;
  v_running_balance  numeric;
  v_count            int := 0;
BEGIN
  FOR v_visit IN
    SELECT rj.id, rj.amc_contract_id, rj.created_at
      FROM public.repair_jobs rj
     WHERE rj.kind = 'maintenance'
       AND rj.amc_contract_id IS NOT NULL
       AND rj.status::text = 'requested'
       AND rj.created_at > now() - interval '30 days'
       AND NOT EXISTS (
         SELECT 1 FROM public.amc_sla_breaches b
          WHERE b.visit_id = rj.id
            AND b.breach_type = 'response_time'
       )
     FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      SELECT * INTO v_contract
        FROM public.amc_contracts WHERE id = v_visit.amc_contract_id;
      IF NOT FOUND THEN CONTINUE; END IF;

      -- Same severity branching as check_amc_sla_on_visit_status_change
      IF v_contract.response_time_critical_hours IS NOT NULL
         AND now() - v_visit.created_at >
             v_contract.response_time_critical_hours * interval '1 hour' THEN
        v_severity := 'critical';
        v_target_hours := v_contract.response_time_critical_hours;
      ELSE
        v_severity := 'standard';
        v_target_hours := v_contract.response_time_standard_hours;
      END IF;

      v_elapsed_hours := round(
        EXTRACT(EPOCH FROM (now() - v_visit.created_at))::numeric / 3600.0, 2
      );

      IF v_elapsed_hours <= v_target_hours THEN
        CONTINUE;
      END IF;

      v_per_visit_cost := round(
        v_contract.monthly_fee_rupees * 12::numeric / v_contract.visits_per_year, 2
      );
      v_credit_amount := least(round(v_per_visit_cost * 0.25, 2), 10000::numeric);

      IF v_credit_amount <= 0 THEN
        INSERT INTO public.amc_sla_breaches (
          amc_contract_id, visit_id, breach_type, severity,
          expected_within_hours, actual_hours, credit_issued_rupees, notes
        ) VALUES (
          v_visit.amc_contract_id, v_visit.id, 'response_time', v_severity,
          v_target_hours, v_elapsed_hours, 0,
          'response_time SLA exceeded; no credit (per_visit_cost <= 0); sweep'
        );
        v_count := v_count + 1;
        CONTINUE;
      END IF;

      INSERT INTO public.amc_sla_breaches (
        amc_contract_id, visit_id, breach_type, severity,
        expected_within_hours, actual_hours, credit_issued_rupees, notes
      ) VALUES (
        v_visit.amc_contract_id, v_visit.id, 'response_time', v_severity,
        v_target_hours, v_elapsed_hours, v_credit_amount,
        concat('SLA miss (sweep) on visit ', v_visit.id, ': ',
               v_elapsed_hours, 'h vs ', v_target_hours, 'h target (',
               v_severity, ').')
      ) RETURNING id INTO v_breach_id;

      SELECT coalesce(
               SUM(CASE WHEN ledger_kind = 'debit' THEN -amount_rupees
                        ELSE amount_rupees END),
               0)
           + v_credit_amount
        INTO v_running_balance
        FROM public.amc_payment_pool
        WHERE amc_contract_id = v_visit.amc_contract_id;

      INSERT INTO public.amc_payment_pool (
        amc_contract_id, ledger_kind, amount_rupees, balance_after,
        source_visit_id, source_breach_id, description
      ) VALUES (
        v_visit.amc_contract_id, 'credit', v_credit_amount, v_running_balance,
        v_visit.id, v_breach_id,
        concat('SLA goodwill credit (response_time, ', v_severity, ', sweep)')
      ) RETURNING id INTO v_ledger_id;

      UPDATE public.amc_sla_breaches
         SET credit_ledger_id = v_ledger_id
         WHERE id = v_breach_id;

      v_count := v_count + 1;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'sweep_amc_sla_unresponded_visits: skipped % (%): %',
        v_visit.id, SQLSTATE, SQLERRM;
    END;
  END LOOP;

  RETURN v_count;
END;
$$;

ALTER FUNCTION public.sweep_amc_sla_unresponded_visits() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.sweep_amc_sla_unresponded_visits()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sweep_amc_sla_unresponded_visits()
  TO service_role;

-- ---------------------------------------------------------------------
-- 2 + 3. auto_create_due_amc_visits — per-row EXCEPTION + eligibility check
-- ---------------------------------------------------------------------
-- Round 442 wrapped only the enum cast in EXCEPTION. The INSERT itself
-- + the follow-up amc_contracts UPDATE still runs at top scope. One
-- bad row (FK on engineer_id, future NOT NULL column, unique violation)
-- aborts the whole batch.
--
-- Round 446 wraps each LOOP iteration in BEGIN/EXCEPTION so a failing
-- row gets RAISE NOTICE'd and the loop continues. Also: re-checks the
-- primary engineer's availability + verified status before pre-assigning
-- — stale primaries no longer silently take visits they can't deliver.
-- When primary is ineligible, INSERT with engineer_id = NULL so the
-- existing auto_assign_amc_visit_on_create_trg fires and walks the
-- rotation roster as designed.

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
  v_equipment_type public.equipment_category;
  v_equipment_text text;
  v_job_number     text;
  v_eligible       boolean;
  v_assigned_id    uuid;
  v_created_count  int := 0;
BEGIN
  FOR v_contract IN
    SELECT *
      FROM public.amc_contracts
     WHERE status = 'active'
       AND next_visit_at IS NOT NULL
       AND next_visit_at <= now()
     ORDER BY next_visit_at ASC
     FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      v_months_elapsed := GREATEST(
        0,
        (EXTRACT(YEAR FROM age(now()::date, v_contract.start_date)) * 12
         + EXTRACT(MONTH FROM age(now()::date, v_contract.start_date)))::int
      );
      v_years_elapsed := (v_months_elapsed / 12) + 1;
      v_max_visits := v_contract.visits_per_year * v_years_elapsed;

      v_advance := CASE v_contract.visit_frequency
        WHEN 'weekly'    THEN interval '7 days'
        WHEN 'biweekly'  THEN interval '14 days'
        WHEN 'monthly'   THEN interval '1 month'
        WHEN 'quarterly' THEN interval '3 months'
        ELSE interval '1 month'
      END;

      IF v_contract.visits_completed + v_contract.visits_scheduled >= v_max_visits THEN
        UPDATE public.amc_contracts
           SET next_visit_at = next_visit_at + v_advance,
               updated_at = now()
         WHERE id = v_contract.id;
        CONTINUE;
      END IF;

      v_equipment_text := CASE
        WHEN v_contract.equipment_categories IS NULL THEN NULL
        WHEN array_length(v_contract.equipment_categories, 1) IS NULL THEN NULL
        ELSE v_contract.equipment_categories[1]
      END;

      BEGIN
        v_equipment_type := v_equipment_text::public.equipment_category;
      EXCEPTION WHEN invalid_text_representation THEN
        v_equipment_type := NULL;
      END;

      -- Round 446: re-check primary engineer eligibility. If they quit,
      -- got de-verified, or set themselves unavailable, leave engineer_id
      -- NULL so the existing auto_assign_amc_visit_on_create_trg fires
      -- and runs the rotation walk.
      v_eligible := false;
      IF v_contract.primary_engineer_id IS NOT NULL THEN
        SELECT (coalesce(e.is_available, false)
                AND e.verification_status::text = 'verified')
          INTO v_eligible
          FROM public.engineers e
         WHERE e.id = v_contract.primary_engineer_id;
      END IF;
      v_assigned_id := CASE WHEN v_eligible
                            THEN v_contract.primary_engineer_id
                            ELSE NULL
                       END;

      v_job_number := 'AMC-'
                    || substring(v_contract.id::text, 1, 8)
                    || '-'
                    || lpad((v_contract.visits_completed
                           + v_contract.visits_scheduled + 1)::text, 3, '0');

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
        v_assigned_id,
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
        NULL,
        NULL,
        0,
        now(),
        now()
      );

      UPDATE public.amc_contracts
         SET visits_scheduled = visits_scheduled + 1,
             next_visit_at = next_visit_at + v_advance,
             updated_at = now()
       WHERE id = v_contract.id;

      v_created_count := v_created_count + 1;
    EXCEPTION WHEN OTHERS THEN
      -- One bad contract doesn't strand the whole batch. next_visit_at
      -- was never advanced on this failed iteration so the next tick
      -- retries it.
      RAISE NOTICE 'auto_create_due_amc_visits: skipped contract % (%): %',
        v_contract.id, SQLSTATE, SQLERRM;
    END;
  END LOOP;

  RETURN v_created_count;
END;
$$;

ALTER FUNCTION public.auto_create_due_amc_visits() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.auto_create_due_amc_visits()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auto_create_due_amc_visits() TO service_role;

-- ---------------------------------------------------------------------
-- 4. chat_messages mask PII on UPDATE (edit-path moderation)
-- ---------------------------------------------------------------------
-- Round 432 (PR-D46) shipped the INSERT mask. The function comment
-- explicitly deferred edit-path moderation ("would need a sister
-- trigger"). Hospitals can dodge the guardrail by editing a benign
-- message to include phone/email.
--
-- Fix: parallel trigger BEFORE UPDATE OF message that runs the SAME
-- mask function. The existing function reads NEW.message, so it works
-- unchanged in both events.

DROP TRIGGER IF EXISTS chat_messages_mask_pii_update_trg ON public.chat_messages;
CREATE TRIGGER chat_messages_mask_pii_update_trg
  BEFORE UPDATE OF message ON public.chat_messages
  FOR EACH ROW
  WHEN (NEW.message IS DISTINCT FROM OLD.message)
  EXECUTE FUNCTION public.chat_messages_mask_pii();

-- One-shot backfill: any chat_messages edited since the edit RPC
-- shipped that may contain raw PII the INSERT mask never saw. Idempotent
-- via the moderation events table's appended `backfilled_by_round_446`
-- marker — re-running the migration is a no-op.
DO $$
DECLARE
  v_row       record;
  v_phone_re  constant text := '(?:\+?\s?91[\s-]?|0)?[6-9]\d{9}';
  v_email_re  constant text := '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}';
  v_replace   constant text := '[contact removed — keep on EquipSeva]';
  v_masked    text;
  v_phone_n   int;
  v_email_n   int;
  v_kinds     text[];
  v_count     int := 0;
BEGIN
  FOR v_row IN
    SELECT id, conversation_id, sender_user_id, message
      FROM public.chat_messages
     WHERE edited_at IS NOT NULL
       AND (
         message ~ v_phone_re
         OR message ~ v_email_re
       )
       AND NOT EXISTS (
         SELECT 1 FROM public.chat_message_moderation_events e
          WHERE e.conversation_id = chat_messages.conversation_id
            AND e.sender_user_id = chat_messages.sender_user_id
            AND e.original_excerpt = LEFT(chat_messages.message, 200)
       )
  LOOP
    v_masked := v_row.message;
    v_kinds := ARRAY[]::text[];
    SELECT count(*) INTO v_phone_n
      FROM regexp_matches(v_masked, v_phone_re, 'g');
    IF v_phone_n > 0 THEN
      v_masked := regexp_replace(v_masked, v_phone_re, v_replace, 'g');
      v_kinds := array_append(v_kinds, 'phone');
    END IF;
    SELECT count(*) INTO v_email_n
      FROM regexp_matches(v_masked, v_email_re, 'g');
    IF v_email_n > 0 THEN
      v_masked := regexp_replace(v_masked, v_email_re, v_replace, 'g');
      v_kinds := array_append(v_kinds, 'email');
    END IF;
    IF coalesce(v_phone_n, 0) + coalesce(v_email_n, 0) > 0 THEN
      UPDATE public.chat_messages
         SET message = v_masked
       WHERE id = v_row.id;
      INSERT INTO public.chat_message_moderation_events (
        conversation_id, sender_user_id, original_excerpt, matched_kinds, masked_count
      ) VALUES (
        v_row.conversation_id, v_row.sender_user_id,
        LEFT(v_row.message, 200),
        v_kinds || ARRAY['backfilled_by_round_446'],
        coalesce(v_phone_n, 0) + coalesce(v_email_n, 0)
      );
      v_count := v_count + 1;
    END IF;
  END LOOP;
  RAISE NOTICE 'round 446 chat backfill: % messages re-masked', v_count;
END $$;

-- ---------------------------------------------------------------------
-- 5. re_rotate_on_engineer_unavailable — notify the displaced engineer
-- ---------------------------------------------------------------------
-- Existing fn (20260513100000) notifies the new engineer + the hospital
-- when a visit is reassigned. The displaced engineer is silently left
-- with a stale assignment in their feed. Add a third notification kind
-- 'amc_visit_unassigned' so they know to expect a different visit on
-- their schedule.
--
-- Implementation: extend the existing fn's body with an additional
-- INSERT INTO notifications keyed on the OLD engineer's user_id. The
-- old engineer's engineers.id is NEW.id at trigger time (the row being
-- updated IS the engineer who just toggled unavailable).

CREATE OR REPLACE FUNCTION public.re_rotate_on_engineer_unavailable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_visit record;
  v_new_engineer uuid;
  v_new_engineer_user uuid;
  v_old_engineer_user uuid;
  v_hours_elapsed numeric;
  v_half_window numeric;
BEGIN
  -- Round 446: resolve OLD engineer's user_id once for the displaced
  -- notifications below.
  SELECT user_id INTO v_old_engineer_user
    FROM public.engineers WHERE id = NEW.id;

  FOR v_visit IN
    SELECT rj.*
      FROM public.repair_jobs rj
     WHERE rj.engineer_id = NEW.id
       AND rj.kind = 'maintenance'
       AND rj.amc_contract_id IS NOT NULL
       AND rj.status::text IN ('requested', 'assigned')
       AND coalesce(rj.scheduled_date, now()::date) >= now()::date
  LOOP
    SELECT response_time_standard_hours INTO v_half_window
      FROM public.amc_contracts WHERE id = v_visit.amc_contract_id;
    v_hours_elapsed := EXTRACT(EPOCH FROM (now() - v_visit.created_at)) / 3600.0;
    IF v_half_window IS NULL OR v_hours_elapsed < (v_half_window / 2.0) THEN
      CONTINUE;
    END IF;

    v_new_engineer := public.assign_next_available_amc_engineer(v_visit.id);
    IF v_new_engineer IS NULL OR v_new_engineer = NEW.id THEN
      CONTINUE;
    END IF;

    UPDATE public.repair_jobs
       SET engineer_id = v_new_engineer,
           updated_at = now()
     WHERE id = v_visit.id;

    SELECT user_id INTO v_new_engineer_user
      FROM public.engineers WHERE id = v_new_engineer;

    IF v_new_engineer_user IS NOT NULL THEN
      BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
          v_new_engineer_user,
          'amc_visit_assigned',
          'AMC visit reassigned to you',
          concat('Visit ',
                 coalesce(v_visit.job_number, substring(v_visit.id::text, 1, 8)),
                 ' was routed from a backup. Tap to plan the trip.'),
          jsonb_build_object(
            'amc_contract_id', v_visit.amc_contract_id,
            'repair_job_id',   v_visit.id,
            'reassigned',      true
          )
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 're_rotate: new engineer notify failed: % / %', SQLSTATE, SQLERRM;
      END;
    END IF;

    IF v_visit.hospital_user_id IS NOT NULL THEN
      BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
          v_visit.hospital_user_id,
          'amc_visit_engineer_changed',
          'AMC engineer changed',
          'Your AMC visit has been routed to a backup technician.',
          jsonb_build_object(
            'amc_contract_id', v_visit.amc_contract_id,
            'repair_job_id',   v_visit.id,
            'engineer_id',     v_new_engineer
          )
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 're_rotate: hospital notify failed: % / %', SQLSTATE, SQLERRM;
      END;
    END IF;

    -- Round 446: tell the displaced engineer their assignment moved.
    IF v_old_engineer_user IS NOT NULL THEN
      BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
          v_old_engineer_user,
          'amc_visit_unassigned',
          'AMC visit reassigned',
          concat(
            'Visit ',
            coalesce(v_visit.job_number, substring(v_visit.id::text, 1, 8)),
            ' was routed to a backup because you''re showing as unavailable. ',
            'Toggle availability back on in your profile to receive future visits.'
          ),
          jsonb_build_object(
            'amc_contract_id', v_visit.amc_contract_id,
            'repair_job_id',   v_visit.id,
            'reassigned_away', true
          )
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 're_rotate: displaced engineer notify failed: % / %', SQLSTATE, SQLERRM;
      END;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.re_rotate_on_engineer_unavailable() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.re_rotate_on_engineer_unavailable() FROM PUBLIC;

-- ---------------------------------------------------------------------
-- 6. get_repair_job_escrow — surface engineer_response columns
-- ---------------------------------------------------------------------
-- Android EscrowRow declares engineer_response + engineer_responded_at
-- but the server RPC's RETURNS TABLE never SELECTs them. Hospital never
-- sees engineer's dispute rebuttal.

CREATE OR REPLACE FUNCTION public.get_repair_job_escrow(p_repair_job_id uuid)
RETURNS TABLE (
  id                    uuid,
  status                text,
  amount_rupees         numeric,
  paid_at               timestamptz,
  scheduled_release_at  timestamptz,
  released_at           timestamptz,
  refunded_at           timestamptz,
  dispute_opened_at     timestamptz,
  dispute_reason        text,
  dispute_resolution    text,
  is_in_dispute_window  boolean,
  engineer_response     text,
  engineer_responded_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    e.id,
    e.status::text,
    e.amount_rupees,
    e.paid_at,
    e.scheduled_release_at,
    e.released_at,
    e.refunded_at,
    e.dispute_opened_at,
    e.dispute_reason,
    e.dispute_resolution,
    -- Same dispute-window derivation the original RPC used (PR-D4).
    (e.status::text = 'held'
     AND e.scheduled_release_at IS NOT NULL
     AND e.scheduled_release_at > now()) AS is_in_dispute_window,
    e.engineer_response,
    e.engineer_responded_at
    FROM public.repair_job_escrow e
   WHERE e.repair_job_id = p_repair_job_id
     AND (
       -- RLS-equivalent gate: caller must be the job's hospital or
       -- engineer or founder/admin (same allow-list the original
       -- get_repair_job_escrow used).
       public.is_founder()
       OR public.is_admin(auth.uid())
       OR auth.uid() IN (
         SELECT rj.hospital_user_id FROM public.repair_jobs rj
          WHERE rj.id = p_repair_job_id
         UNION
         SELECT eng.user_id
           FROM public.engineers eng
           JOIN public.repair_jobs rj ON rj.engineer_id = eng.id
          WHERE rj.id = p_repair_job_id
       )
     );
$$;

REVOKE EXECUTE ON FUNCTION public.get_repair_job_escrow(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_repair_job_escrow(uuid) TO authenticated;
