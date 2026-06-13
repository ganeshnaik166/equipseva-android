-- =====================================================================
-- Round 507 — Predictive PM Calendar Backbone (v0.4 Phase 4 #4)
-- =====================================================================
--
-- Preventive Maintenance (PM) is the biggest revenue lever in the
-- biomedical-equipment service market. Hospital forgets, AMC lapses,
-- equipment fails during NABH accreditation week + CFO hates the
-- surprise capex. Today we have no PM cadence — every job is
-- reactive.
--
-- This migration ships:
--   * equipment_pm_intervals — OEM-recommended PM cadence per
--     (equipment_type, equipment_brand). Founder-curated.
--   * equipment_pm_schedule — per-installed-equipment forward calendar
--     auto-computed from last DSR + interval.
--   * recompute_pm_schedule(hospital_user_id) — daily-cron-callable
--     RPC that walks the hospital's equipment fleet + emits next
--     scheduled dates.
--   * hospital_upcoming_pm(days_ahead) — hospital-facing read.
--   * founder_pm_overdue_summary — cockpit query for "X hospitals
--     have overdue PM" red-flag.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. equipment_pm_intervals — OEM-recommended cadence
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.equipment_pm_intervals (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_type        text        NOT NULL,
  equipment_brand       text,
  -- Days between PMs. Most equipment: 90 / 180 / 365. Heavy use: 30.
  interval_days         int         NOT NULL CHECK (interval_days BETWEEN 7 AND 730),
  -- Optional hint for the engineer: what the PM should cover
  scope_summary         text,
  source                text        NOT NULL DEFAULT 'OEM_recommended'
                                    CHECK (source IN ('OEM_recommended','EquipSeva_curated','custom')),
  notes                 text,
  active                boolean     NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pm_intervals_uniq UNIQUE (equipment_type, equipment_brand)
);

CREATE INDEX IF NOT EXISTS pm_intervals_active_idx
  ON public.equipment_pm_intervals (equipment_type, equipment_brand)
  WHERE active = true;

ALTER TABLE public.equipment_pm_intervals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pm_intervals_select ON public.equipment_pm_intervals;
CREATE POLICY pm_intervals_select
  ON public.equipment_pm_intervals
  FOR SELECT
  TO authenticated, service_role
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.equipment_pm_intervals
  FROM anon, authenticated;

-- Seed defaults for our 5 in-scope equipment_types from r486
INSERT INTO public.equipment_pm_intervals (equipment_type, equipment_brand, interval_days, scope_summary, source) VALUES
  ('dental',             NULL, 180, 'Chair upholstery + suction line + handpiece bearings + compressor air filter', 'EquipSeva_curated'),
  ('ophthalmology',      NULL, 180, 'Slit lamp lubrication + fundus camera optics calibration + autorefractor lens cleaning', 'EquipSeva_curated'),
  ('sterilization',      NULL,  90, 'Autoclave gasket + temperature calibration + chamber clean', 'EquipSeva_curated'),
  ('patient_monitoring', NULL, 180, 'BP cuff calibration + ECG lead integrity + alarm function test + battery health', 'EquipSeva_curated'),
  ('laboratory',         NULL, 180, 'Centrifuge balance + microscope optics + incubator temperature calibration', 'EquipSeva_curated')
ON CONFLICT (equipment_type, equipment_brand) DO NOTHING;

-- ---------------------------------------------------------------------
-- 2. equipment_pm_schedule — per-equipment forward calendar
-- ---------------------------------------------------------------------
-- A "row of equipment" = identified by (hospital_user_id, equipment_type,
-- equipment_brand, equipment_model, equipment_serial). NULL serial =
-- whole-class scheduling (less precise but works for hospitals that
-- haven't itemized serials yet).
CREATE TABLE IF NOT EXISTS public.equipment_pm_schedule (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id         uuid        NOT NULL,
  CONSTRAINT pm_schedule_hospital_fk
    FOREIGN KEY (hospital_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,

  equipment_type           text        NOT NULL,
  equipment_brand          text,
  equipment_model          text,
  equipment_serial         text,
  interval_days            int         NOT NULL,

  last_service_at          timestamptz,
  last_dsr_id              uuid        REFERENCES public.dsr_reports(id) ON DELETE SET NULL,
  next_pm_due_at           timestamptz NOT NULL,
  -- Status reflects current state vs due-date
  status                   text        NOT NULL DEFAULT 'scheduled'
                                       CHECK (status IN ('scheduled','upcoming','due','overdue','completed','cancelled')),
  reminder_sent_at         timestamptz,
  -- T-30 days quote prep
  prequote_sent_at         timestamptz,

  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT pm_schedule_uniq UNIQUE (
    hospital_user_id, equipment_type, equipment_brand, equipment_model, equipment_serial
  )
);

CREATE INDEX IF NOT EXISTS pm_schedule_hospital_idx
  ON public.equipment_pm_schedule (hospital_user_id, next_pm_due_at);
CREATE INDEX IF NOT EXISTS pm_schedule_due_idx
  ON public.equipment_pm_schedule (next_pm_due_at, status)
  WHERE status IN ('scheduled','upcoming','due','overdue');

ALTER TABLE public.equipment_pm_schedule ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pm_schedule_select ON public.equipment_pm_schedule;
CREATE POLICY pm_schedule_select
  ON public.equipment_pm_schedule
  FOR SELECT
  TO authenticated, service_role
  USING (hospital_user_id = auth.uid() OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.equipment_pm_schedule
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. recompute_pm_schedule(hospital_user_id)
-- ---------------------------------------------------------------------
-- Walks the hospital's distinct equipment (across repair_jobs + DSRs)
-- and emits / updates a forward calendar row per piece. Idempotent.
CREATE OR REPLACE FUNCTION public.recompute_pm_schedule(
  p_hospital_user_id uuid
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_eq           record;
  v_interval     int;
  v_count        int := 0;
  v_now          timestamptz := now();
BEGIN
  IF NOT (auth.role() = 'service_role'
          OR public.is_founder()
          OR auth.uid() = p_hospital_user_id) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  -- For each distinct equipment seen on this hospital's repair_jobs
  -- (signed DSR being the gold-standard last_service event)
  FOR v_eq IN
    SELECT DISTINCT
      d.equipment_type,
      d.equipment_brand,
      d.equipment_model,
      d.equipment_serial,
      (SELECT max(d2.engineer_signature_at)
         FROM public.dsr_reports d2
        WHERE d2.hospital_user_id = p_hospital_user_id
          AND d2.equipment_type = d.equipment_type
          AND coalesce(d2.equipment_brand, '') = coalesce(d.equipment_brand, '')
          AND coalesce(d2.equipment_model, '') = coalesce(d.equipment_model, '')
          AND coalesce(d2.equipment_serial, '') = coalesce(d.equipment_serial, '')
          AND d2.status = 'signed'
      ) AS last_service_at,
      (SELECT d3.id
         FROM public.dsr_reports d3
        WHERE d3.hospital_user_id = p_hospital_user_id
          AND d3.equipment_type = d.equipment_type
          AND coalesce(d3.equipment_brand, '') = coalesce(d.equipment_brand, '')
          AND coalesce(d3.equipment_model, '') = coalesce(d.equipment_model, '')
          AND coalesce(d3.equipment_serial, '') = coalesce(d.equipment_serial, '')
          AND d3.status = 'signed'
        ORDER BY d3.engineer_signature_at DESC
        LIMIT 1
      ) AS last_dsr_id
    FROM public.dsr_reports d
    WHERE d.hospital_user_id = p_hospital_user_id
  LOOP
    -- Resolve PM interval — brand-specific overrides type-default
    SELECT interval_days INTO v_interval
      FROM public.equipment_pm_intervals
     WHERE equipment_type = v_eq.equipment_type
       AND (equipment_brand = v_eq.equipment_brand
            OR (equipment_brand IS NULL AND v_eq.equipment_brand IS NULL)
            OR equipment_brand IS NULL)
       AND active = true
     ORDER BY (equipment_brand IS NOT NULL) DESC
     LIMIT 1;

    -- If no interval configured for this equipment_type, default 180d
    IF v_interval IS NULL THEN
      v_interval := 180;
    END IF;

    INSERT INTO public.equipment_pm_schedule (
      hospital_user_id, equipment_type, equipment_brand,
      equipment_model, equipment_serial, interval_days,
      last_service_at, last_dsr_id,
      next_pm_due_at, status
    ) VALUES (
      p_hospital_user_id, v_eq.equipment_type, v_eq.equipment_brand,
      v_eq.equipment_model, v_eq.equipment_serial, v_interval,
      v_eq.last_service_at, v_eq.last_dsr_id,
      coalesce(v_eq.last_service_at, v_now) + (v_interval || ' days')::interval,
      CASE
        WHEN v_eq.last_service_at IS NULL THEN 'scheduled'
        WHEN coalesce(v_eq.last_service_at, v_now) + (v_interval || ' days')::interval < v_now THEN 'overdue'
        WHEN coalesce(v_eq.last_service_at, v_now) + (v_interval || ' days')::interval < v_now + interval '7 days' THEN 'due'
        WHEN coalesce(v_eq.last_service_at, v_now) + (v_interval || ' days')::interval < v_now + interval '30 days' THEN 'upcoming'
        ELSE 'scheduled'
      END
    )
    ON CONFLICT (hospital_user_id, equipment_type, equipment_brand, equipment_model, equipment_serial)
    DO UPDATE SET
      interval_days = EXCLUDED.interval_days,
      last_service_at = EXCLUDED.last_service_at,
      last_dsr_id = EXCLUDED.last_dsr_id,
      next_pm_due_at = EXCLUDED.next_pm_due_at,
      status = EXCLUDED.status,
      updated_at = now();

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recompute_pm_schedule(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.recompute_pm_schedule(uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. recompute_all_pm_schedules — daily cron over all hospitals
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recompute_all_pm_schedules()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_h     record;
  v_count int := 0;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  FOR v_h IN
    SELECT DISTINCT hospital_user_id
      FROM public.dsr_reports
  LOOP
    PERFORM public.recompute_pm_schedule(v_h.hospital_user_id);
    v_count := v_count + 1;
  END LOOP;

  -- Also walk the status state machine for already-existing schedules:
  -- a row may have been 'scheduled' yesterday and become 'due' today.
  UPDATE public.equipment_pm_schedule
     SET status = CASE
       WHEN next_pm_due_at < now() THEN 'overdue'
       WHEN next_pm_due_at < now() + interval '7 days' THEN 'due'
       WHEN next_pm_due_at < now() + interval '30 days' THEN 'upcoming'
       ELSE 'scheduled'
     END,
     updated_at = now()
   WHERE status NOT IN ('completed','cancelled');

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recompute_all_pm_schedules()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.recompute_all_pm_schedules() TO service_role;

-- ---------------------------------------------------------------------
-- 5. hospital_upcoming_pm — hospital-facing read
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hospital_upcoming_pm(
  p_days_ahead integer DEFAULT 60
)
RETURNS TABLE(
  id                  uuid,
  equipment_type      text,
  equipment_brand     text,
  equipment_model     text,
  equipment_serial    text,
  interval_days       int,
  last_service_at     timestamptz,
  next_pm_due_at      timestamptz,
  days_until_due      numeric,
  status              text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT s.id, s.equipment_type, s.equipment_brand, s.equipment_model,
         s.equipment_serial, s.interval_days,
         s.last_service_at, s.next_pm_due_at,
         EXTRACT(EPOCH FROM (s.next_pm_due_at - now())) / 86400 AS days_until_due,
         s.status
    FROM public.equipment_pm_schedule s
   WHERE s.hospital_user_id = auth.uid()
     AND s.status NOT IN ('completed','cancelled')
     AND s.next_pm_due_at < now() + (greatest(coalesce(p_days_ahead, 60), 1)::text || ' days')::interval
   ORDER BY s.next_pm_due_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.hospital_upcoming_pm(integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.hospital_upcoming_pm(integer) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 6. founder_pm_overdue_summary — cockpit red-flag query
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_pm_overdue_summary(
  p_limit integer DEFAULT 100
)
RETURNS TABLE(
  hospital_user_id     uuid,
  hospital_email       text,
  overdue_count        int,
  due_count            int,
  upcoming_count       int,
  oldest_overdue_at    timestamptz
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
  SELECT
    s.hospital_user_id,
    coalesce((SELECT email FROM auth.users WHERE id = s.hospital_user_id), 'unknown'),
    count(*) FILTER (WHERE s.status = 'overdue')::int,
    count(*) FILTER (WHERE s.status = 'due')::int,
    count(*) FILTER (WHERE s.status = 'upcoming')::int,
    min(s.next_pm_due_at) FILTER (WHERE s.status = 'overdue')
  FROM public.equipment_pm_schedule s
  WHERE s.status IN ('overdue','due','upcoming')
  GROUP BY s.hospital_user_id
  HAVING count(*) FILTER (WHERE s.status IN ('overdue','due')) > 0
  ORDER BY count(*) FILTER (WHERE s.status = 'overdue') DESC, min(s.next_pm_due_at) ASC NULLS LAST
  LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_pm_overdue_summary(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_pm_overdue_summary(integer) TO service_role;

-- ---------------------------------------------------------------------
-- 7. Daily cron schedule
-- ---------------------------------------------------------------------
DO $$
BEGIN
  PERFORM cron.schedule(
    'recompute_all_pm_schedules_daily',
    '30 22 * * *',  -- 22:30 UTC = 04:00 IST
    $cron$SELECT public.recompute_all_pm_schedules();$cron$
  );
  RAISE NOTICE 'round 507: PM recompute cron scheduled';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'round 507: pg_cron unavailable; recompute_all_pm_schedules() callable from edge fn / manual';
END;
$$;

COMMIT;

DO $$
DECLARE
  v_intervals_count int;
BEGIN
  SELECT count(*) INTO v_intervals_count FROM public.equipment_pm_intervals WHERE active = true;
  IF v_intervals_count < 5 THEN
    RAISE EXCEPTION 'round 507: expected at least 5 seeded PM intervals, got %', v_intervals_count;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = 'equipment_pm_schedule'
      AND relnamespace = 'public'::regnamespace AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 507: equipment_pm_schedule RLS not enabled';
  END IF;
  RAISE NOTICE 'round 507 predictive PM calendar verified: 2 tables (+ 5 seeded intervals), 4 RPCs';
END;
$$;
