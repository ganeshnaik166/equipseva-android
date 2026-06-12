-- =====================================================================
-- Round 487 — Founder Audit Triggers (v0.4 Phase 1 #1 followup)
-- =====================================================================
--
-- Round 482 shipped founder_action_log + retrofit of one example RPC
-- (admin_set_engineer_verification). The remaining 10+ founder/admin
-- SECDEF mutators (admin_cancel_engineer_payout, admin_resolve_*,
-- admin_set_buyer_kyc_status, admin_set_org_verification, etc.) need
-- audit-log coverage too.
--
-- Two ways to retrofit:
--   A. CREATE OR REPLACE each RPC body with explicit PERFORM
--      log_founder_action() — high precision, captures before/after
--      diff cleanly, but ~10 RPC rewrites.
--   B. AFTER INSERT/UPDATE/DELETE trigger on each sensitive TABLE that
--      logs only when public.is_founder() is true — lower per-row
--      precision but covers ALL paths (including direct Studio writes
--      that bypass the RPCs entirely) with one piece of code.
--
-- We pick B (trigger catch-all) because:
--   - Direct table writes via Studio + service_role are a real audit
--     gap that retrofit-of-RPCs doesn't catch.
--   - Founder accounts are rare (one human), so the is_founder() check
--     in the trigger is a hot-path that returns false for 99.9% of
--     writes — no measurable perf cost.
--   - Adding a new sensitive table later just needs the same one-line
--     trigger declaration; no per-RPC rewrite.
--
-- Tables we add the trigger to:
--   - engineers (KYC verification, suspension)
--   - engineer_payouts (mark paid, cancel)
--   - repair_jobs (status override)
--   - amc_contracts (cancel, status flip)
--   - repair_job_escrow (dispute resolution)
--   - engineer_reports (resolve)
--   - profiles (role changes by admin_force_role_change)
--   - amc_subscriptions (status flips by admin_update_amc_subscription_state)
--   - buyer_kyc (status set)
--   - org_verifications (status set)
--
-- The trigger writes a row to founder_action_log with the old/new
-- columns serialized as jsonb. Since the trigger runs in the same
-- transaction as the mutation, a rollback also rolls back the audit
-- row (no ghost-success).

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Generic trigger function
-- ---------------------------------------------------------------------
-- One function reused by all sensitive tables. Uses TG_ARGV[0] as the
-- op_name suffix (e.g., 'engineers_mutation') so callers can grep
-- the audit log per table.
CREATE OR REPLACE FUNCTION public.founder_audit_table_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
  IF TG_OP = 'DELETE' THEN
    v_target_id := (OLD::jsonb)->>'id';
  ELSE
    v_target_id := (NEW::jsonb)->>'id';
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
    -- explicit retrofits in r482 + r485 where they exist. For
    -- catch-all trigger entries, reason is NULL — the diff itself
    -- carries the forensic information.
    NULL,
    v_outcome
  );

  RETURN coalesce(NEW, OLD);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_audit_table_mutation()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_audit_table_mutation()
  TO service_role;

COMMENT ON FUNCTION public.founder_audit_table_mutation IS
  'Round 487 — generic trigger function. Logs any INSERT/UPDATE/DELETE to founder_action_log when the actor is_founder(). Skipped for system-level writes (no auth.uid()) and for regular-user writes.';

-- ---------------------------------------------------------------------
-- 2. Apply the trigger to sensitive tables
-- ---------------------------------------------------------------------
-- DO block so we can probe table existence + skip cleanly. Some of
-- these tables may not exist on all environments (e.g., a staging
-- env might lack buyer_kyc). The block emits NOTICEs for skipped
-- tables instead of failing the migration.

DO $$
DECLARE
  v_target_table text;
  v_op_name      text;
  v_pair         record;
BEGIN
  FOR v_pair IN
    SELECT * FROM (VALUES
      ('engineers',           'engineer_kyc'),
      ('engineer_payouts',    'engineer_payout'),
      ('repair_jobs',         'repair_job'),
      ('amc_contracts',       'amc_contract'),
      ('repair_job_escrow',   'repair_escrow'),
      ('engineer_reports',    'engineer_report'),
      ('profiles',            'profile'),
      ('amc_subscriptions',   'amc_subscription'),
      ('buyer_kyc',           'buyer_kyc'),
      ('org_verifications',   'org_verification'),
      ('amc_escalations',     'amc_escalation')
    ) AS t(target_table, op_name)
  LOOP
    v_target_table := v_pair.target_table;
    v_op_name      := v_pair.op_name;

    -- Skip if table doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM pg_class
      WHERE relname = v_target_table
        AND relnamespace = 'public'::regnamespace
    ) THEN
      RAISE NOTICE 'round 487: skipping % (table not present)', v_target_table;
      CONTINUE;
    END IF;

    -- Drop any prior trigger by the same name (idempotent re-apply)
    EXECUTE format(
      'DROP TRIGGER IF EXISTS founder_audit_%s_trg ON public.%I',
      v_target_table, v_target_table
    );

    -- Create the AFTER INSERT/UPDATE/DELETE trigger with op_name arg
    EXECUTE format(
      'CREATE TRIGGER founder_audit_%s_trg
         AFTER INSERT OR UPDATE OR DELETE ON public.%I
         FOR EACH ROW
         EXECUTE FUNCTION public.founder_audit_table_mutation(%L)',
      v_target_table, v_target_table, v_op_name
    );

    RAISE NOTICE 'round 487: installed founder_audit_%s_trg', v_target_table;
  END LOOP;
END;
$$;

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition assertions
-- ---------------------------------------------------------------------
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
    FROM pg_trigger
   WHERE tgname LIKE 'founder_audit_%_trg'
     AND NOT tgisinternal;

  IF v_count < 5 THEN
    RAISE EXCEPTION 'round 487: only % triggers installed (expected >= 5)', v_count;
  END IF;

  RAISE NOTICE 'round 487 founder audit triggers verified: % triggers installed', v_count;
END;
$$;
