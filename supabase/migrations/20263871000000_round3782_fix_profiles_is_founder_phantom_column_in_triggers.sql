-- =====================================================================
-- Round 3782 — CRITICAL: opening an escrow dispute was impossible
-- =====================================================================
--
-- `public.profiles` has NO column named `is_founder`. Verified:
--   SELECT count(*) FROM information_schema.columns
--    WHERE table_schema='public' AND table_name='profiles'
--      AND column_name='is_founder';   -->  0
--
-- `is_founder` is a zero-argument FUNCTION:
--   is_founder() := lower(auth.email()) = lower('<founder email>')
-- It tests the CURRENT SESSION's user and therefore cannot be used to
-- test an arbitrary row. Four functions nevertheless referenced it as
-- if it were a boolean column on profiles:
--
--   SELECT 1 FROM public.profiles p
--    WHERE p.id = u.id
--      AND (p.role::text = 'admin' OR p.is_founder = true)   <-- 42703
--
-- Every one of them raises `42703: column p.is_founder does not exist`
-- the instant that statement is reached. Three of the four are
-- TRIGGERS, so the exception propagates out and ABORTS THE USER'S
-- WRITE — this is not a silently-degraded notification, it is a hard
-- transaction failure.
--
-- IMPACT, by trigger (all three fixed here):
--
--   notify_admins_on_escrow_dispute  AFTER UPDATE ON repair_job_escrow
--     WHEN (new.status='in_dispute' AND old.status IS DISTINCT FROM new.status)
--     ==> OPENING AN ESCROW DISPUTE HAS ALWAYS FAILED OUTRIGHT.
--     Confirmed empirically against production before this fix: setting
--     an escrow row to 'in_dispute' returns
--     `ERROR: 42703: column p.is_founder does not exist`.
--     Escrow is the marketplace's core trust mechanism (per ROADMAP_v04
--     it is the #3-ranked must-have: "Engineers stay on WhatsApp cash
--     forever" without it), and the dispute path — the thing that makes
--     a held escrow safe for the HOSPITAL — could not be entered at all.
--
--   notify_admins_on_amc_escalation  AFTER INSERT ON amc_admin_escalations
--     The broken loop is unconditional, so EVERY AMC escalation insert
--     failed. The whole AMC admin-escalation queue could never receive
--     a row.
--
--   maybe_auto_suspend_engineer_on_cash_flag  AFTER INSERT ON cash_survey_responses
--     Reached only once an engineer crosses the 3-distinct-hospital
--     cash-flag threshold. So: the anti-disintermediation auto-suspend
--     never fired, AND the third hospital's cash-flag submission itself
--     failed. Below the threshold the trigger returns before the broken
--     statement, which is why ordinary cash surveys still worked and
--     hid the defect.
--
-- The fourth site, engineer_respond_to_escrow_dispute() (an RPC, not a
-- trigger), is fixed in round3783 alongside the other broken
-- Android-called RPCs — it reuses the helper introduced here.
--
-- HOW THIS WAS FOUND: `plpgsql_check` 2.8 (available on this Supabase
-- instance, installed temporarily for the sweep and dropped again)
-- statically analysed every plpgsql function against the real catalog.
-- Its 42702/42703/42804/42883 findings proved 100% accurate on every
-- one of the 12 cases spot-checked by live execution; its 42846
-- "cannot cast type <table> to jsonb" findings on
-- founder_audit_table_mutation were FALSE POSITIVES (verified: an
-- UPDATE on repair_jobs completes fine — it does not model
-- to_jsonb(NEW) on a trigger pseudo-record). Worth remembering both
-- halves of that calibration before trusting or dismissing a future
-- run.
--
-- FIX: introduce ONE helper, public.admin_or_founder_user_ids(), that
-- resolves "admin or founder" row-wise and correctly, and have all
-- callers use it. This removes the duplicated predicate entirely so it
-- cannot drift again — which is the actual root cause here, since the
-- broken predicate was copy-pasted identically into four places.

BEGIN;

-- ---------------------------------------------------------------------
-- 0. The helper the three triggers (and round3783's RPC) will share
-- ---------------------------------------------------------------------
-- Row-wise "is this user an admin or the founder?", expressed as a set
-- of user ids so callers can drive a FOR loop directly.
--
-- The founder is identified the same way public.is_founder() does it —
-- by pinned email — but resolved against auth.users so it works for an
-- ARBITRARY row rather than only the current session.
--
-- !! KEEP THE EMAIL LITERAL BELOW IN SYNC WITH public.is_founder() !!
-- It is deliberately duplicated rather than refactored out, because
-- is_founder() is load-bearing in a large number of RLS policies and
-- SECURITY DEFINER bodies across this schema; rewriting it to delegate
-- here would put every one of those policies in the blast radius of
-- this migration for no functional gain.
CREATE OR REPLACE FUNCTION public.admin_or_founder_user_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.id
    FROM auth.users u
   WHERE EXISTS (
           SELECT 1
             FROM public.profiles p
            WHERE p.id = u.id
              AND p.role::text = 'admin'
         )
      OR lower(u.email) = lower('ganesh1431.dhanavath@gmail.com');
$$;

COMMENT ON FUNCTION public.admin_or_founder_user_ids() IS
  'Round 3782 — row-wise "admin or founder" user-id set. Replaces the phantom `profiles.is_founder` column that four functions referenced (profiles has no such column; is_founder() is a session-scoped function). Intended for SECURITY DEFINER callers only — deliberately NOT granted to authenticated, since the full admin roster is not something a client should be able to enumerate.';

-- Callers are all SECURITY DEFINER and therefore execute as the owner,
-- so no client-facing grant is required. Keep the admin roster
-- un-enumerable by ordinary sessions.
REVOKE EXECUTE ON FUNCTION public.admin_or_founder_user_ids()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.admin_or_founder_user_ids() TO service_role;

-- ---------------------------------------------------------------------
-- 1. notify_admins_on_escrow_dispute — THE critical one
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_admins_on_escrow_dispute()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_admin_user uuid;
  v_engineer_user uuid;
BEGIN
  -- Only on a fresh dispute open, not on an already-disputed update.
  IF TG_OP <> 'UPDATE' THEN RETURN NEW; END IF;
  IF NEW.status <> 'in_dispute' OR OLD.status = 'in_dispute' THEN
    RETURN NEW;
  END IF;

  -- Engineer-side ping: their payout is frozen until admin resolves.
  v_engineer_user := NEW.engineer_user_id;
  IF v_engineer_user IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_engineer_user,
        'escrow_dispute_opened',
        'Hospital opened an escrow dispute',
        'Funds are paused while EquipSeva reviews. We will notify you when it resolves.',
        jsonb_build_object(
          'repair_job_id', NEW.repair_job_id,
          'escrow_id', NEW.id,
          'amount_rupees', NEW.amount_rupees
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'escrow_dispute_opened engineer notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END IF;

  -- Admin fan-out: every admin / founder user gets a queue alert.
  -- round3782: was an inline EXISTS on the non-existent column
  -- profiles.is_founder, which raised 42703 here and aborted the
  -- caller's UPDATE — making it impossible to open an escrow dispute.
  FOR v_admin_user IN
    SELECT uid FROM public.admin_or_founder_user_ids() AS uid
  LOOP
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_admin_user,
        'admin_escrow_dispute_opened',
        'Escrow dispute needs review',
        coalesce(NEW.dispute_reason, 'Hospital opened a dispute on a held escrow.'),
        jsonb_build_object(
          'repair_job_id', NEW.repair_job_id,
          'escrow_id', NEW.id,
          'amount_rupees', NEW.amount_rupees
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'admin_escrow_dispute_opened notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END LOOP;

  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------
-- 2. notify_admins_on_amc_escalation
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_admins_on_amc_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_admin_user uuid;
  v_title text;
BEGIN
  v_title := CASE NEW.reason
              WHEN 'rotation_exhausted'      THEN 'AMC rotation exhausted'
              WHEN 'no_engineers_available'  THEN 'No AMC engineer available'
              ELSE 'AMC needs admin attention'
            END;
  -- round3782: same phantom-column fix as above. This loop is
  -- unconditional, so every insert into amc_admin_escalations failed.
  FOR v_admin_user IN
    SELECT uid FROM public.admin_or_founder_user_ids() AS uid
  LOOP
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_admin_user,
        'amc_admin_escalation_raised',
        v_title,
        coalesce(NEW.notes, 'Open the AMC escalations queue to triage.'),
        jsonb_build_object(
          'amc_contract_id', NEW.amc_contract_id,
          'visit_id',        NEW.visit_id,
          'escalation_id',   NEW.id,
          'reason',          NEW.reason
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'amc_admin_escalation_raised notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END LOOP;
  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------
-- 3. maybe_auto_suspend_engineer_on_cash_flag
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.maybe_auto_suspend_engineer_on_cash_flag()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_distinct_hospitals int;
  v_total_flags        int;
  v_engineer_user      uuid;
  v_admin_user         uuid;
  v_already_suspended  boolean;
BEGIN
  IF NEW.response IS DISTINCT FROM 'asked_cash' THEN RETURN NEW; END IF;

  -- Round 384 — row-lock the engineer first so concurrent triggers
  -- serialize. Without this, two simultaneous flags both pass the
  -- "already suspended" guard and fire duplicate notification fan-outs.
  SELECT (cash_auto_suspended_at IS NOT NULL)
    INTO v_already_suspended
    FROM public.engineers
   WHERE id = NEW.engineer_id
     FOR UPDATE;

  IF v_already_suspended THEN RETURN NEW; END IF;

  SELECT
    count(DISTINCT hospital_user_id),
    count(*)
    INTO v_distinct_hospitals, v_total_flags
    FROM public.cash_survey_responses
   WHERE engineer_id = NEW.engineer_id
     AND response = 'asked_cash'
     AND responded_at >= now() - interval '90 days';

  IF v_distinct_hospitals < 3 THEN RETURN NEW; END IF;

  UPDATE public.engineers
     SET cash_auto_suspended_at      = now(),
         cash_auto_suspension_reason = concat(
           v_total_flags::text,
           ' cash-payment flags from ',
           v_distinct_hospitals::text,
           ' independent hospitals in the last 90 days. Awaiting admin review.'
         ),
         is_available = false
   WHERE id = NEW.engineer_id;

  SELECT user_id INTO v_engineer_user
    FROM public.engineers WHERE id = NEW.engineer_id;
  IF v_engineer_user IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_engineer_user,
        'engineer_auto_suspended',
        'Account paused pending review',
        'Multiple hospitals reported off-platform cash requests. Reach out to support to re-activate.',
        jsonb_build_object(
          'reason',              'cash_payment_flags',
          'flag_count',           v_total_flags,
          'distinct_hospitals',   v_distinct_hospitals
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'engineer_auto_suspended notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END IF;

  -- round3782: same phantom-column fix. Reached only past the
  -- 3-distinct-hospital threshold, so this both broke the auto-suspend
  -- itself AND made the threshold-crossing cash-flag insert fail.
  FOR v_admin_user IN
    SELECT uid FROM public.admin_or_founder_user_ids() AS uid
  LOOP
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_admin_user,
        'admin_engineer_auto_suspended',
        'Engineer auto-suspended (cash flags)',
        concat(
          v_total_flags::text, ' cash-flags from ',
          v_distinct_hospitals::text, ' hospitals in 90 days — review queue.'
        ),
        jsonb_build_object(
          'engineer_id',          NEW.engineer_id,
          'flag_count',           v_total_flags,
          'distinct_hospitals',   v_distinct_hospitals
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'admin auto-suspend notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END LOOP;

  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------
-- Verification — actually FIRE the critical trigger, then undo it
-- ---------------------------------------------------------------------
-- 42703 is an execution-time error, so redefining the functions proves
-- nothing. This drives a real escrow row into 'in_dispute' so the
-- trigger genuinely executes, then discards that write.
--
-- The inner BEGIN/EXCEPTION block is a plpgsql SUBTRANSACTION: raising
-- our own sentinel inside it rolls back the probe UPDATE (and any
-- notifications it inserted) while leaving the outer migration
-- transaction intact. The sentinel is distinguished from a real failure
-- by SQLSTATE — ours is P0001 (raise_exception), the bug was 42703 —
-- so a still-broken trigger fails the migration instead of being
-- mistaken for success.
DO $$
DECLARE
  v_id       uuid;
  v_probed   boolean := false;
BEGIN
  PERFORM count(*) FROM public.admin_or_founder_user_ids();
  RAISE NOTICE 'round 3782: admin_or_founder_user_ids() resolves % user(s)',
    (SELECT count(*) FROM public.admin_or_founder_user_ids());

  SELECT id INTO v_id
    FROM public.repair_job_escrow
   WHERE status IS DISTINCT FROM 'in_dispute'
   LIMIT 1;

  IF v_id IS NULL THEN
    RAISE NOTICE 'round 3782: no non-disputed escrow row available — dispute trigger not fired (fix still applied)';
  ELSE
    BEGIN
      UPDATE public.repair_job_escrow SET status = 'in_dispute' WHERE id = v_id;
      -- Trigger survived. Undo the probe write.
      RAISE EXCEPTION 'ROUND3782_PROBE_ROLLBACK';
    EXCEPTION
      WHEN SQLSTATE 'P0001' THEN
        v_probed := true;
      WHEN OTHERS THEN
        RAISE EXCEPTION
          'round 3782 VERIFY FAILED — opening an escrow dispute still errors: % %',
          SQLSTATE, SQLERRM;
    END;
    IF v_probed THEN
      RAISE NOTICE 'round 3782: escrow -> in_dispute fired notify_admins_on_escrow_dispute successfully (probe write rolled back)';
    END IF;
  END IF;

  RAISE NOTICE 'round 3782 verified: profiles.is_founder phantom-column removed from all 3 triggers; escrow disputes can be opened again';
END;
$$;

COMMIT;
