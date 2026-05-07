-- v2.1 PR-D22: notify admins when an escrow dispute opens or an AMC
-- escalation lands.
--
-- Without these triggers, the new admin ops queues (PR-D21) only show
-- once the founder happens to open the dashboard — the operational
-- pager is missing. Both events are user-blocking (engineer payout
-- frozen / hospital AMC visit unassigned), so a real-time push to
-- every admin closes the loop.
--
-- Two AFTER triggers:
--   1. repair_job_escrow status flips pending|held → in_dispute
--   2. amc_admin_escalations insert
--
-- Best-effort fan-out to admin + founder users (mirrors the pattern in
-- 20260525100000_v21_cash_auto_suspend.sql). EXCEPTION clause swallows
-- per-row notify failures so a flaky notifications insert can't roll
-- back the dispute / escalation itself.

-- ---------------------------------------------------------------------
-- 1. notify_admins_on_escrow_dispute
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_admins_on_escrow_dispute()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
  FOR v_admin_user IN
    SELECT id FROM auth.users u
     WHERE EXISTS (
       SELECT 1 FROM public.profiles p
        WHERE p.id = u.id
          AND (p.role::text = 'admin' OR p.is_founder = true)
     )
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
$$;
ALTER FUNCTION public.notify_admins_on_escrow_dispute() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_admins_on_escrow_dispute() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_admins_on_escrow_dispute_trg ON public.repair_job_escrow;
CREATE TRIGGER notify_admins_on_escrow_dispute_trg
  AFTER UPDATE ON public.repair_job_escrow
  FOR EACH ROW
  WHEN (NEW.status = 'in_dispute' AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.notify_admins_on_escrow_dispute();

-- ---------------------------------------------------------------------
-- 2. notify_admins_on_amc_escalation
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_admins_on_amc_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin_user uuid;
  v_title text;
BEGIN
  v_title := CASE NEW.reason
              WHEN 'rotation_exhausted'      THEN 'AMC rotation exhausted'
              WHEN 'no_engineers_available'  THEN 'No AMC engineer available'
              ELSE 'AMC needs admin attention'
            END;
  FOR v_admin_user IN
    SELECT id FROM auth.users u
     WHERE EXISTS (
       SELECT 1 FROM public.profiles p
        WHERE p.id = u.id
          AND (p.role::text = 'admin' OR p.is_founder = true)
     )
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
$$;
ALTER FUNCTION public.notify_admins_on_amc_escalation() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_admins_on_amc_escalation() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_admins_on_amc_escalation_trg ON public.amc_admin_escalations;
CREATE TRIGGER notify_admins_on_amc_escalation_trg
  AFTER INSERT ON public.amc_admin_escalations
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_on_amc_escalation();
