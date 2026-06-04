-- Round 444 — close notification gap for AMC visits inserted WITH
-- engineer_id pre-populated.
--
-- Discovery path (round 442 follow-up):
--   * Round 442 unblocked auto_create_due_amc_visits, two backlogged
--     AMC visits landed in repair_jobs.
--   * The existing fan-out trigger
--     `auto_assign_amc_visit_on_create_trg` (20260513100000) is gated
--     `WHEN (NEW.engineer_id IS NULL)` — it only fires for visits that
--     need rotation-based assignment. Visits that arrive with
--     engineer_id already set (the AMC primary engineer path) skip the
--     trigger entirely → no engineer push, no hospital confirmation.
--   * `auto_create_due_amc_visits` ALWAYS sets
--     engineer_id = v_contract.primary_engineer_id at the row level, so
--     in practice every auto-created AMC visit slips past the trigger.
--   * Net effect: an engineer who's on a hospital's AMC contract gets
--     a new maintenance job dropped into their feed at next_visit_at
--     with zero notification. Hospital also gets no confirmation. The
--     two visits from today's drain landed silently.
--
-- Fix: parallel trigger that fires on the same INSERT but the
-- complementary condition (`engineer_id IS NOT NULL`). Same
-- notification copy as the auto-assign path so engineers see one
-- consistent kind across both flows.
--
-- One-shot backfill at the bottom inserts the missed notifications for
-- any AMC visits created in the last 24h whose engineer + hospital
-- never got pinged. Idempotent — `WHERE NOT EXISTS` against
-- notifications ensures re-running this migration doesn't duplicate.

-- ---------------------------------------------------------------------
-- 1. Trigger fn: notify both sides when an AMC visit lands with
-- engineer_id already set (primary-engineer path).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_amc_visit_preassigned_on_create()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_engineer_user uuid;
  v_job_number    text;
BEGIN
  SELECT user_id INTO v_engineer_user
    FROM public.engineers
   WHERE id = NEW.engineer_id;

  v_job_number := COALESCE(NEW.job_number, substring(NEW.id::text, 1, 8));

  IF v_engineer_user IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_engineer_user,
        'amc_visit_assigned',
        'New AMC maintenance visit',
        concat(
          'You''ve been assigned visit ',
          v_job_number,
          '. Tap to plan the trip.'
        ),
        jsonb_build_object(
          'amc_contract_id', NEW.amc_contract_id,
          'repair_job_id',   NEW.id,
          'job_number',      v_job_number
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'notify_amc_visit_preassigned_on_create: engineer notify failed: % / %',
        SQLSTATE, SQLERRM;
    END;
  END IF;

  IF NEW.hospital_user_id IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        NEW.hospital_user_id,
        'amc_visit_engineer_assigned',
        'Maintenance visit scheduled',
        'An engineer has been assigned to your upcoming AMC visit.',
        jsonb_build_object(
          'amc_contract_id', NEW.amc_contract_id,
          'repair_job_id',   NEW.id,
          'engineer_id',     NEW.engineer_id
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'notify_amc_visit_preassigned_on_create: hospital notify failed: % / %',
        SQLSTATE, SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.notify_amc_visit_preassigned_on_create() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_amc_visit_preassigned_on_create() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_amc_visit_preassigned_on_create_trg ON public.repair_jobs;
CREATE TRIGGER notify_amc_visit_preassigned_on_create_trg
  AFTER INSERT ON public.repair_jobs
  FOR EACH ROW
  WHEN (
    NEW.kind = 'maintenance'
    AND NEW.amc_contract_id IS NOT NULL
    AND NEW.engineer_id IS NOT NULL
  )
  EXECUTE FUNCTION public.notify_amc_visit_preassigned_on_create();

-- ---------------------------------------------------------------------
-- 2. One-shot backfill — notify any AMC visit created in the last 24h
-- that slipped through silently. Idempotent: only inserts when a
-- matching notification doesn't already exist.
-- ---------------------------------------------------------------------
DO $$
DECLARE
  v_visit          record;
  v_engineer_user  uuid;
  v_job_number     text;
  v_count          int := 0;
BEGIN
  FOR v_visit IN
    SELECT rj.id, rj.amc_contract_id, rj.engineer_id, rj.hospital_user_id, rj.job_number
      FROM public.repair_jobs rj
     WHERE rj.kind = 'maintenance'
       AND rj.amc_contract_id IS NOT NULL
       AND rj.engineer_id IS NOT NULL
       AND rj.created_at >= now() - interval '24 hours'
  LOOP
    v_job_number := COALESCE(v_visit.job_number, substring(v_visit.id::text, 1, 8));

    SELECT user_id INTO v_engineer_user
      FROM public.engineers
     WHERE id = v_visit.engineer_id;

    IF v_engineer_user IS NOT NULL
       AND NOT EXISTS (
         SELECT 1 FROM public.notifications n
          WHERE n.user_id = v_engineer_user
            AND n.kind = 'amc_visit_assigned'
            AND (n.data ->> 'repair_job_id')::uuid = v_visit.id
       )
    THEN
      BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
          v_engineer_user,
          'amc_visit_assigned',
          'New AMC maintenance visit',
          concat(
            'You''ve been assigned visit ',
            v_job_number,
            '. Tap to plan the trip.'
          ),
          jsonb_build_object(
            'amc_contract_id', v_visit.amc_contract_id,
            'repair_job_id',   v_visit.id,
            'job_number',      v_job_number,
            'backfilled_by',   'round_444'
          )
        );
        v_count := v_count + 1;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'round 444 backfill: engineer notify failed for visit %: % / %',
          v_visit.id, SQLSTATE, SQLERRM;
      END;
    END IF;

    IF v_visit.hospital_user_id IS NOT NULL
       AND NOT EXISTS (
         SELECT 1 FROM public.notifications n
          WHERE n.user_id = v_visit.hospital_user_id
            AND n.kind = 'amc_visit_engineer_assigned'
            AND (n.data ->> 'repair_job_id')::uuid = v_visit.id
       )
    THEN
      BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
          v_visit.hospital_user_id,
          'amc_visit_engineer_assigned',
          'Maintenance visit scheduled',
          'An engineer has been assigned to your upcoming AMC visit.',
          jsonb_build_object(
            'amc_contract_id', v_visit.amc_contract_id,
            'repair_job_id',   v_visit.id,
            'engineer_id',     v_visit.engineer_id,
            'backfilled_by',   'round_444'
          )
        );
        v_count := v_count + 1;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'round 444 backfill: hospital notify failed for visit %: % / %',
          v_visit.id, SQLSTATE, SQLERRM;
      END;
    END IF;
  END LOOP;

  RAISE NOTICE 'round 444 backfill: % notifications inserted', v_count;
END $$;
