-- =====================================================================
-- Round 3815 -- equipment_pm_schedule grew a duplicate row on EVERY
--               recompute for equipment booked without a serial
-- =====================================================================
--
-- FOUND BY: the RPR-00040 full-chain probe (2026-09-07). After the first
-- Philips DSR with a serial landed, the payoff query showed the OTHER
-- monitor (GE CARESCAPE_B450, serial NULL) with FOUR identical schedule
-- rows: created 09-06 07:40 / 07:42 / 07:43 (two manual recomputes plus
-- the daily tick) and 09-07 03:51 (the probe's recompute). One new copy
-- per run.
--
-- WHY: pm_schedule_uniq is UNIQUE (hospital_user_id, equipment_type,
-- equipment_brand, equipment_model, equipment_serial). A plain UNIQUE
-- constraint treats NULLs as DISTINCT, so two rows with a NULL serial
-- never conflict -> recompute_pm_schedule's
--   INSERT ... ON CONFLICT (...) DO UPDATE
-- never takes the UPDATE arm for serial-less equipment and INSERTs again.
-- recompute_all_pm_schedules() runs from the daily cron-tick, so every
-- hospital's serial-less equipment (90% of jobs are booked without a
-- serial -- round3814) would gain one row per day: hospital_upcoming_pm,
-- hospital_fleet_health, asset_history and the founder summaries would
-- list the same device N times, and the reminder / pre-quote senders
-- would fire N times.
--
-- FIX: (1) dedupe, keeping the earliest-created row per NULL-safe key;
-- (2) re-create the constraint as UNIQUE NULLS NOT DISTINCT (PG 15+;
-- prod is 17.6). Same column list, so the ON CONFLICT arbiter inference
-- in recompute_pm_schedule resolves to the new index -- the function
-- itself is untouched. (3) Gate: run the REAL recompute twice under
-- service_role claims and prove the row count is stable, with no
-- EXCEPTION handler and asserted floors (round3801 lesson).
--
-- Not changed on purpose: a DSR filed without a serial and a later DSR
-- with one for the same physical device still produce two schedule
-- rows -- the data cannot prove they are the same unit, and collapsing
-- them would hide exactly the discrepancy an auditor wants to see.
-- =====================================================================
BEGIN;

-- 1. Dedupe. Earliest row per NULL-safe key survives; the rest go.
WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY hospital_user_id, equipment_type,
                        coalesce(equipment_brand, ''),
                        coalesce(equipment_model, ''),
                        coalesce(equipment_serial, '')
           ORDER BY created_at, id
         ) AS rn
    FROM public.equipment_pm_schedule
)
DELETE FROM public.equipment_pm_schedule s
 USING ranked r
 WHERE s.id = r.id
   AND r.rn > 1;

-- 2. NULL-safe uniqueness.
ALTER TABLE public.equipment_pm_schedule
  DROP CONSTRAINT pm_schedule_uniq;

ALTER TABLE public.equipment_pm_schedule
  ADD CONSTRAINT pm_schedule_uniq
  UNIQUE NULLS NOT DISTINCT
    (hospital_user_id, equipment_type, equipment_brand,
     equipment_model, equipment_serial);

-- 3. Gate.
DO $$
DECLARE
  v_before  int;
  v_after1  int;
  v_after2  int;
  v_dupes   int;
  v_ret     int;
  v_null    int;
BEGIN
  -- recompute_all_pm_schedules() is service_role/founder only; auth.role()
  -- reads request.jwt.claims. Transaction-local so nothing leaks.
  PERFORM set_config('request.jwt.claims', '{"role":"service_role"}', true);

  SELECT count(*) INTO v_before FROM public.equipment_pm_schedule;
  IF v_before < 1 THEN
    RAISE EXCEPTION 'r3815 gate: equipment_pm_schedule is empty -- nothing proven';
  END IF;

  SELECT count(*) INTO v_dupes
    FROM (SELECT 1
            FROM public.equipment_pm_schedule
           GROUP BY hospital_user_id, equipment_type, equipment_brand,
                    equipment_model, equipment_serial
          HAVING count(*) > 1) d;
  IF v_dupes <> 0 THEN
    RAISE EXCEPTION 'r3815 gate: % duplicate groups survived the dedupe', v_dupes;
  END IF;

  v_ret := public.recompute_all_pm_schedules();
  IF v_ret < 1 THEN
    RAISE EXCEPTION 'r3815 gate: recompute walked % hospitals -- nothing proven', v_ret;
  END IF;
  SELECT count(*) INTO v_after1 FROM public.equipment_pm_schedule;

  PERFORM public.recompute_all_pm_schedules();
  SELECT count(*) INTO v_after2 FROM public.equipment_pm_schedule;

  IF v_after1 <> v_before OR v_after2 <> v_before THEN
    RAISE EXCEPTION
      'r3815 gate: row count drifted % -> % -> % across two recomputes (upsert still not idempotent)',
      v_before, v_after1, v_after2;
  END IF;

  SELECT count(*) INTO v_null
    FROM public.equipment_pm_schedule
   WHERE equipment_serial IS NULL;

  RAISE NOTICE 'r3815 gate OK: % rows stable across 2 real recomputes (% hospitals walked), % NULL-serial rows, 0 duplicate groups',
    v_before, v_ret, v_null;
END $$;

COMMIT;
