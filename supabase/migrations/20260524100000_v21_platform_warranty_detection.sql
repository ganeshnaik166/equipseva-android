-- v2.1 PR-D9: 30-day platform warranty auto-detection (T3.12 in the
-- anti-disintermediation strategy memo).
--
-- Strategy memo: "every job done in-app gets 30-day platform-backed
-- warranty. Off-platform = no warranty."
--
-- This migration implements detection + notification only. The actual
-- fee waiver / free re-visit fulfilment lives in admin tooling for v1
-- (admin clicks a button that nulls platform_commission + flips
-- escrow → cancelled-with-refund). Automating the waiver is deferred
-- to v2.2 once we've watched a few real warranty claims play out in
-- prod.
--
-- Detection rule:
--   * NEW.kind = 'repair' (maintenance visits aren't warranty events
--     — they're already pre-paid via the AMC pool)
--   * Same hospital_user_id, AND
--   * Same equipment_serial (when present and non-empty) OR same
--     (equipment_brand, equipment_model) when serial is missing
--   * Most recent matching prior job is 'completed' within 30 days
--   * The prior job was NOT itself a warranty claim (avoid loops)
--
-- The "covered" decision uses the *most recent matching* prior job
-- so ancient repairs don't keep claiming warranty.
--
-- Notification + audit trail:
--   * is_warranty_covered column added to repair_jobs (boolean, default
--     false). Trigger fills it on INSERT. Surfaces as a query-able
--     flag for admin dashboards + future UI badges.
--   * warranty_source_job_id FK pointing at the original job — admin
--     can audit "what's this warranty against?" without re-running the
--     detection logic.
--   * Hospital notification kind='warranty_covered' on insert.
--
-- Future PR-D10 follow-ups:
--   * Engineer-facing notification "this is a warranty re-visit; your
--     payout is covered by the platform"
--   * Auto-zero platform_commission on completion + auto-cancel escrow
--   * UI badge "30-day warranty" on the new job's detail screen

ALTER TABLE public.repair_jobs
  ADD COLUMN IF NOT EXISTS is_warranty_covered      boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS warranty_source_job_id   uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_repair_jobs_warranty_source
  ON public.repair_jobs (warranty_source_job_id)
  WHERE warranty_source_job_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- Helper: is_repair_job_warranty_eligible
-- Pure read; can be called from the trigger or future admin tools.
-- Returns the source job id if eligible, NULL otherwise. Source-id
-- return form lets the trigger stamp warranty_source_job_id in one
-- call without re-querying.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.find_warranty_source_job(
  p_hospital_user_id uuid,
  p_equipment_serial text,
  p_equipment_brand  text,
  p_equipment_model  text,
  p_kind             text,
  p_self_id          uuid
)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT rj.id
    FROM public.repair_jobs rj
   WHERE rj.kind             = 'repair'
     AND rj.hospital_user_id = p_hospital_user_id
     AND rj.id              <> p_self_id
     AND rj.status::text     = 'completed'
     AND rj.completed_at IS NOT NULL
     AND rj.completed_at >= now() - interval '30 days'
     AND coalesce(rj.is_warranty_covered, false) = false
     AND p_kind = 'repair'
     AND (
       (
         coalesce(nullif(p_equipment_serial,''), '') <> ''
         AND coalesce(nullif(rj.equipment_serial,''), '') = coalesce(nullif(p_equipment_serial,''), '')
       )
       OR (
         coalesce(nullif(p_equipment_serial,''), '') = ''
         AND coalesce(rj.equipment_brand,'') = coalesce(p_equipment_brand,'')
         AND coalesce(rj.equipment_model,'') = coalesce(p_equipment_model,'')
         AND coalesce(p_equipment_brand,'') <> ''
       )
     )
   ORDER BY rj.completed_at DESC
   LIMIT 1;
$$;
REVOKE EXECUTE ON FUNCTION public.find_warranty_source_job(uuid, text, text, text, text, uuid) FROM PUBLIC;

-- ---------------------------------------------------------------------
-- Trigger: stamp is_warranty_covered + warranty_source_job_id on insert
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.repair_jobs_stamp_warranty_on_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_source uuid;
BEGIN
  IF NEW.kind IS DISTINCT FROM 'repair' THEN RETURN NEW; END IF;
  IF NEW.hospital_user_id IS NULL THEN RETURN NEW; END IF;
  IF NEW.is_warranty_covered THEN
    -- Already pre-flagged (admin manual override) — leave alone.
    RETURN NEW;
  END IF;

  v_source := public.find_warranty_source_job(
    NEW.hospital_user_id,
    NEW.equipment_serial,
    NEW.equipment_brand,
    NEW.equipment_model,
    'repair',
    NEW.id
  );

  IF v_source IS NOT NULL THEN
    NEW.is_warranty_covered    := true;
    NEW.warranty_source_job_id := v_source;
  END IF;

  RETURN NEW;
END;
$$;
ALTER FUNCTION public.repair_jobs_stamp_warranty_on_insert() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.repair_jobs_stamp_warranty_on_insert() FROM PUBLIC;

DROP TRIGGER IF EXISTS repair_jobs_stamp_warranty_on_insert_trg ON public.repair_jobs;
CREATE TRIGGER repair_jobs_stamp_warranty_on_insert_trg
  BEFORE INSERT ON public.repair_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.repair_jobs_stamp_warranty_on_insert();

-- ---------------------------------------------------------------------
-- Notification — fire only AFTER insert, so the row exists for the
-- deep-link payload + so an INSERT failure doesn't strand a phantom
-- notification.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_warranty_covered_after_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_job_number text;
BEGIN
  IF NOT NEW.is_warranty_covered THEN RETURN NEW; END IF;
  IF NEW.hospital_user_id IS NULL THEN RETURN NEW; END IF;

  v_job_number := COALESCE(NEW.job_number, substring(NEW.id::text, 1, 8));

  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      NEW.hospital_user_id,
      'warranty_covered',
      'Covered by 30-day warranty',
      concat(
        'Job ', v_job_number,
        ' is within 30 days of an earlier completed repair. Service fee is waived once an engineer is assigned.'
      ),
      jsonb_build_object(
        'repair_job_id',         NEW.id,
        'job_number',            v_job_number,
        'warranty_source_job_id', NEW.warranty_source_job_id
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'warranty_covered notify failed: % / %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;
ALTER FUNCTION public.notify_warranty_covered_after_insert() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_warranty_covered_after_insert() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_warranty_covered_after_insert_trg ON public.repair_jobs;
CREATE TRIGGER notify_warranty_covered_after_insert_trg
  AFTER INSERT ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.is_warranty_covered = true)
  EXECUTE FUNCTION public.notify_warranty_covered_after_insert();
