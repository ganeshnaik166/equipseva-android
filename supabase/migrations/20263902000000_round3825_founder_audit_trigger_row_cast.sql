-- =====================================================================
-- Round 3825 -- the founder audit trigger aborts every write the founder
--               makes to the seven tables it guards, and has never
--               recorded a single row
-- =====================================================================
--
-- FOUND BY: a plpgsql_check sweep over all 19,314 plpgsql functions in public,
-- re-run for trigger functions against the relation each one fires on (the plain
-- sweep refuses a trigger function with 22023, which is why this was invisible
-- the last time the class was swept). One finding, reported on all seven
-- audited tables: "cannot cast type repair_jobs to jsonb" (42846).
--
-- THE GAP: the body resolves the audited row id with
--     v_target_id := (NEW::jsonb)->>'id';
-- and Postgres has no cast from a composite row type to jsonb — the catalog has
-- no such pg_cast entry, so this raises 42846 every time it is reached. The
-- correct spelling is to_jsonb(NEW), which the SAME function already uses two
-- blocks further down for before_value/after_value. Only the id lookup is wrong.
--
-- WHY NOBODY HIT IT: the two guards above that line return early unless
-- auth.uid() IS NOT NULL *and* public.is_founder(). So the broken line executes
-- for exactly one person — the founder — and for nobody else. There is no
-- EXCEPTION handler around it, so the trigger does not merely fail to audit:
-- it aborts the founder's statement. Every table it guards is on the emergency
-- path in the founder runbook (engineer_payouts, engineers, repair_job_escrow,
-- repair_jobs, profiles, amc_contracts, amc_subscriptions), so the 2am commands
-- that runbook prescribes error out for the one account that needs them.
--
-- EVIDENCE that it has never worked: all seven triggers are enabled
-- (tgenabled = 'O'), and public.founder_action_log holds 5 rows of which ZERO
-- were written by this trigger (no op_name ending in :insert/:update/:delete).
-- The audit trail this function exists to build is empty.
--
-- WHAT THIS DOES: replaces the two `(NEW::jsonb)` / `(OLD::jsonb)` casts with
-- to_jsonb(...). Nothing else changes -- same signature, same guards, same
-- inserted columns, same return. The gates below prove the old body really did
-- fail and the new one really does write an audit row, both against a throwaway
-- temp table so no audited table is touched.
--
-- ROLLBACK (exact): re-create the function with `(NEW::jsonb)->>'id'` and
-- `(OLD::jsonb)->>'id'` in place of the to_jsonb calls; the pre-change body has
-- md5 ae8aaf5d4fd4f693ca03c921241f5dfb (CRLF normalised to LF). Nothing else in
-- this migration needs undoing: no grant, table or trigger is altered.

BEGIN;

-- ---------------------------------------------------------------------
-- PRECONDITION GATE
-- ---------------------------------------------------------------------
DO $gate$
DECLARE
  v_md5      text;
  v_trigs    int;
  v_enabled  int;
  v_sourced  int;
BEGIN
  SELECT md5(replace(prosrc, E'\r\n', E'\n')) INTO v_md5
    FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace
     AND proname = 'founder_audit_table_mutation';
  IF v_md5 IS NULL THEN
    RAISE EXCEPTION 'round 3825 PRECONDITION FAILED: founder_audit_table_mutation() is gone'
      USING ERRCODE = '55000';
  END IF;
  IF v_md5 <> 'ae8aaf5d4fd4f693ca03c921241f5dfb' THEN
    RAISE EXCEPTION 'round 3825 PRECONDITION FAILED: unexpected body (md5 %), review before replacing', v_md5
      USING ERRCODE = '55000';
  END IF;

  SELECT count(*), count(*) FILTER (WHERE tgenabled = 'O')
    INTO v_trigs, v_enabled
    FROM pg_trigger
   WHERE tgfoid = 'public.founder_audit_table_mutation()'::regprocedure
     AND NOT tgisinternal;
  IF v_trigs <> 7 OR v_enabled <> 7 THEN
    RAISE EXCEPTION 'round 3825 PRECONDITION FAILED: expected 7 enabled triggers, found % (% enabled)', v_trigs, v_enabled
      USING ERRCODE = '55000';
  END IF;

  SELECT count(*) INTO v_sourced
    FROM public.founder_action_log
   WHERE op_name LIKE '%:insert' OR op_name LIKE '%:update' OR op_name LIKE '%:delete';
  RAISE NOTICE 'round 3825: body pinned, 7/7 triggers enabled, % trigger-sourced audit rows exist today', v_sourced;
END;
$gate$;

-- ---------------------------------------------------------------------
-- RED PROBE -- prove the premise: the CURRENT body fails for a founder write.
-- Runs against a throwaway temp table carrying the same trigger, so no audited
-- table is touched and no other trigger participates.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE _r3825_probe (id uuid primary key, touched_at timestamptz) ON COMMIT DROP;
CREATE TRIGGER _r3825_probe_audit_trg
  AFTER UPDATE ON _r3825_probe
  FOR EACH ROW EXECUTE FUNCTION public.founder_audit_table_mutation('probe');

DO $red$
DECLARE
  v_id uuid := '00000000-0000-4000-8000-000000003825';
  v_failed_with text := NULL;
BEGIN
  INSERT INTO _r3825_probe (id, touched_at) VALUES (v_id, now());

  -- is_founder() reads auth.email() out of request.jwt.claims, and the trigger
  -- also needs a non-null auth.uid(); the real founder ids are used so the
  -- audit table's FK to auth.users holds. Transaction-local.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', '756a3373-1077-470e-bc0a-79b8d6673ef4',
                      'role', 'authenticated',
                      'email', 'ganesh1431.dhanavath@gmail.com')::text, true);

  BEGIN
    UPDATE _r3825_probe SET touched_at = now() WHERE id = v_id;
  EXCEPTION WHEN OTHERS THEN
    v_failed_with := SQLSTATE;
  END;

  IF v_failed_with IS NULL THEN
    RAISE EXCEPTION 'round 3825 PRECONDITION FAILED: the founder write did NOT fail, so the premise is wrong -- do not apply this migration blind';
  END IF;
  IF v_failed_with <> '42846' THEN
    RAISE EXCEPTION 'round 3825 PRECONDITION FAILED: expected 42846 (cannot cast), got %', v_failed_with;
  END IF;
  RAISE NOTICE 'round 3825 red probe: a founder write against the current body fails with 42846, as reported';
  PERFORM set_config('request.jwt.claims', NULL, true);
END;
$red$;

-- ---------------------------------------------------------------------
-- THE FIX -- to_jsonb(...) instead of a composite cast. Everything else is the
-- body as it stood; only the two id lookups change.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_audit_table_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id      uuid := auth.uid();
  v_actor_email   text;
  v_op_name       text := TG_ARGV[0];  -- caller supplies the op name
  v_target_id     uuid;
  v_before        jsonb;
  v_after         jsonb;
  v_outcome       text := 'success';
BEGIN
  -- Skip if no actor (system-level writes from migration scripts,
  -- pg_cron, etc.). We only want to capture privileged HUMAN actions.
  IF v_actor_id IS NULL THEN
    RETURN coalesce(NEW, OLD);
  END IF;

  -- The hot-path filter. is_founder() is a 1-row SELECT against
  -- auth.users; cached per-session by Postgres. Cheap.
  IF NOT public.is_founder() THEN
    RETURN coalesce(NEW, OLD);
  END IF;

  -- Resolve target row id. We assume every audited table has an
  -- 'id' column of type uuid (true for all tables in this catalog).
  -- to_jsonb(), never a direct cast: Postgres has no composite-to-jsonb cast,
  -- so casting the row raises 42846 and — with no handler here — aborted the
  -- founder's own statement instead of merely losing the audit row.
  IF TG_OP = 'DELETE' THEN
    v_target_id := (to_jsonb(OLD))->>'id';
  ELSE
    v_target_id := (to_jsonb(NEW))->>'id';
  END IF;

  -- Build before/after diff. For INSERT, before is null. For DELETE,
  -- after is null. For UPDATE, both are populated; downstream can
  -- compute the diff via jsonb_diff.
  IF TG_OP IN ('UPDATE','DELETE') THEN
    v_before := to_jsonb(OLD);
  END IF;
  IF TG_OP IN ('INSERT','UPDATE') THEN
    v_after := to_jsonb(NEW);
  END IF;

  -- Resolve actor email
  SELECT email INTO v_actor_email FROM auth.users WHERE id = v_actor_id;
  IF v_actor_email IS NULL THEN
    v_actor_email := 'unknown';
  END IF;

  INSERT INTO public.founder_action_log (
    actor_user_id, actor_email, op_name, target_table, target_row_id,
    before_value, after_value, reason, outcome
  ) VALUES (
    v_actor_id, v_actor_email,
    v_op_name || ':' || lower(TG_OP),
    TG_TABLE_NAME,
    v_target_id::uuid,
    v_before, v_after,
    -- Trigger-based audit can't capture the founder's stated REASON
    -- (no parameter to read). Reason will be populated by the
    -- explicit retrofits where they exist. For catch-all trigger
    -- entries, reason is NULL — the diff itself carries the forensic
    -- information.
    NULL,
    v_outcome
  );

  RETURN coalesce(NEW, OLD);
END;
$function$;

COMMENT ON FUNCTION public.founder_audit_table_mutation() IS
  'Catch-all audit trigger for privileged founder mutations on the money and identity tables. Resolves the row id with to_jsonb(NEW/OLD) -- a composite-to-jsonb cast does not exist in Postgres and, unguarded, aborted the founder''s own writes. Writes one public.founder_action_log row per founder mutation; every other caller returns early.';

-- ---------------------------------------------------------------------
-- GREEN PROBE -- the same founder write now succeeds AND records the audit row.
-- The probe row is rolled back through the sentinel; only the function change
-- survives this transaction.
-- ---------------------------------------------------------------------
DO $green$
DECLARE
  v_id      uuid := '00000000-0000-4000-8000-000000003825';
  v_before  int;
  v_after   int;
  v_logged  record;
  v_probed  boolean := false;
BEGIN
  SELECT count(*) INTO v_before FROM public.founder_action_log;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', '756a3373-1077-470e-bc0a-79b8d6673ef4',
                      'role', 'authenticated',
                      'email', 'ganesh1431.dhanavath@gmail.com')::text, true);

  BEGIN
    UPDATE _r3825_probe SET touched_at = now() WHERE id = v_id;

    SELECT count(*) INTO v_after FROM public.founder_action_log;
    IF v_after <> v_before + 1 THEN
      RAISE EXCEPTION 'round 3825 VERIFY FAILED: expected exactly one audit row, went % -> %', v_before, v_after;
    END IF;

    SELECT * INTO v_logged FROM public.founder_action_log ORDER BY created_at DESC, id DESC LIMIT 1;
    IF v_logged.target_row_id IS DISTINCT FROM v_id THEN
      RAISE EXCEPTION 'round 3825 VERIFY FAILED: audit row points at %, expected %', v_logged.target_row_id, v_id;
    END IF;
    IF v_logged.op_name <> 'probe:update' THEN
      RAISE EXCEPTION 'round 3825 VERIFY FAILED: op_name is %, expected probe:update', v_logged.op_name;
    END IF;
    IF v_logged.actor_email <> 'ganesh1431.dhanavath@gmail.com' THEN
      RAISE EXCEPTION 'round 3825 VERIFY FAILED: actor_email is %', v_logged.actor_email;
    END IF;
    IF v_logged.before_value IS NULL OR v_logged.after_value IS NULL THEN
      RAISE EXCEPTION 'round 3825 VERIFY FAILED: before/after diff not captured';
    END IF;

    RAISE NOTICE 'round 3825 green probe: the founder write succeeded and recorded % -> % with the right target and actor', v_before, v_after;
    RAISE EXCEPTION 'ROUND3825_PROBE_ROLLBACK';
  EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
      IF SQLERRM <> 'ROUND3825_PROBE_ROLLBACK' THEN RAISE; END IF;
      v_probed := true;
  END;

  IF NOT v_probed THEN
    RAISE EXCEPTION 'round 3825 VERIFY FAILED: the green probe never reached its rollback sentinel';
  END IF;
  PERFORM set_config('request.jwt.claims', NULL, true);

  -- Post-condition: the broken spelling is gone from the shipped body.
  IF EXISTS (
    SELECT 1 FROM pg_proc
     WHERE pronamespace = 'public'::regnamespace
       AND proname = 'founder_audit_table_mutation'
       AND (prosrc LIKE '%NEW::jsonb%' OR prosrc LIKE '%OLD::jsonb%')
  ) THEN
    RAISE EXCEPTION 'round 3825 VERIFY FAILED: a composite-to-jsonb cast is still in the body';
  END IF;

  SELECT count(*) INTO v_after FROM public.founder_action_log;
  IF v_after <> v_before THEN
    RAISE EXCEPTION 'round 3825 VERIFY FAILED: the probe audit row leaked (% rows, expected %)', v_after, v_before;
  END IF;

  RAISE NOTICE 'round 3825 verified: founder writes to the audited tables no longer abort, the audit row is written, and the probe left nothing behind';
END;
$green$;

DROP TRIGGER IF EXISTS _r3825_probe_audit_trg ON _r3825_probe;

COMMIT;
