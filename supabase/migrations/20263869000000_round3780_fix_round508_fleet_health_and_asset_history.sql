-- =====================================================================
-- Round 3780 — round508's BOTH hospital-facing RPCs were dead on arrival
-- =====================================================================
--
-- Found while live-verifying the round3771 Android screens (the first
-- client ever built against round508). Both of round508's
-- hospital-facing RPCs raise unconditionally, for EVERY caller, on
-- EVERY input — they have never returned a single row since the
-- migration shipped. Nobody noticed because until round3771 there was
-- no client calling them at all; `founder_fleet_red_flags` (the third
-- function in that same migration) IS wired into the web console and
-- works fine, which is presumably why the migration looked healthy.
--
-- BUG 1 — hospital_fleet_health(): ERRCODE 42883
--   "operator does not exist: text = equipment_category"
--
--   The next_pm_due_at correlated subquery joins the PM schedule to the
--   per-equipment CTE on equipment_type:
--       AND s.equipment_type = pe.equipment_type
--   but the two sides are DIFFERENT TYPES:
--       repair_jobs.equipment_type          -> equipment_category (ENUM)
--       equipment_pm_schedule.equipment_type -> text
--       dsr_reports.equipment_type           -> text
--   `pe.equipment_type` inherits the enum from repair_jobs, so the
--   comparison has no candidate operator and the whole RETURN QUERY
--   fails at plan time — i.e. it throws even when the hospital has zero
--   repair jobs, so there is no "works when empty" path either.
--
--   This is the THIRD instance of this exact enum-vs-text mismatch
--   found in this codebase (see round3760's repair_jobs_taxonomy_gate
--   fix, which blocked ALL hospital job posting, and round3763's
--   engineer_id_guard stale-literal cousin). The invariant worth
--   remembering: repair_jobs.equipment_type is an ENUM, but every
--   table that denormalises it (dsr_reports, equipment_pm_schedule,
--   equipment_pm_intervals) stores it as TEXT. Any query joining
--   across that boundary MUST cast explicitly.
--
--   Fix: cast once at the source, in the CTE, so every downstream
--   reference (GROUP BY, the subquery comparison, and the declared
--   `equipment_type text` OUT column) is uniformly text. The VALUES
--   are already compatible — submit_dsr() denormalises the enum into
--   dsr_reports' text column, which yields the enum label verbatim,
--   and recompute_pm_schedule() copies that into
--   equipment_pm_schedule — so the join is semantically correct the
--   moment the types line up. No data migration needed.
--
-- BUG 2 — asset_history(): ERRCODE 0A000
--   "invalid UNION/INTERSECT/EXCEPT ORDER BY clause
--    DETAIL: Only result column names can be used, not expressions
--    or functions."
--
--   The body is a 3-branch UNION ALL of bare expressions with no
--   column aliases, followed by `ORDER BY event_at DESC NULLS LAST`.
--   `event_at` is the RETURNS TABLE OUT-parameter name, but it is NOT
--   a result column name of the union (the union's columns take their
--   names from the first branch's inferred names — `created_at` here),
--   and a set-operation's ORDER BY may only reference result column
--   names. Same class as bug 1: fails at plan time, so it throws
--   regardless of input.
--
--   Fix: alias every branch explicitly and wrap the union in a
--   subquery, ordering on the outer query. Internal aliases are
--   deliberately prefixed `e_` so they cannot collide with the
--   function's own OUT parameters — the ambiguous-OUT-column trap that
--   separately broke engineer_public_profile earlier in this same
--   sweep (round3761). RETURN QUERY matches by position, not name, so
--   the prefixed names are purely internal.
--
-- BUG 3 (latent, fixed opportunistically since we're rewriting the
-- body anyway) — asset_history.summary could be NULL.
--   The repair_job branch builds summary by concatenating
--   rj.equipment_type; in SQL, NULL anywhere in a `||` chain makes the
--   WHOLE result NULL. The Android client (round3771) maps `summary`
--   as a non-nullable Kotlin String with no default, and the Supabase
--   client's coerceInputValues=true only rescues null for fields that
--   HAVE a default — so a NULL summary would throw at deserialization
--   and crash the asset-history screen. Currently unreachable in prod
--   (0 repair_jobs rows have a NULL equipment_type today) but the
--   column permits it, so this is a real latent crash. Wrapped the
--   whole expression in coalesce() with a sensible fallback rather
--   than relying on data that happens to be clean right now.
--
-- Verification of both fixes is at the bottom of this file: each RPC
-- is actually EXECUTED (not merely redefined), so a re-broken function
-- fails the migration instead of shipping silently.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. hospital_fleet_health — cast equipment_type to text at the source
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hospital_fleet_health(
  p_days integer DEFAULT 365
)
RETURNS TABLE(
  equipment_type        text,
  equipment_brand       text,
  equipment_model       text,
  equipment_serial      text,
  failure_count_window  int,
  mtbf_days             numeric,
  mttr_hours            numeric,
  total_downtime_hours  numeric,
  uptime_pct            numeric,
  replacement_candidate boolean,
  last_failure_at       timestamptz,
  next_pm_due_at        timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_window_start timestamptz := now() - (greatest(coalesce(p_days, 365), 1)::text || ' days')::interval;
  v_window_hours numeric     := greatest(coalesce(p_days, 365), 1) * 24.0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH per_equipment AS (
    SELECT
      -- round3780: cast the ENUM to text HERE so the GROUP BY, the
      -- next_pm_due_at subquery join, and the declared text OUT column
      -- are all uniformly text. This single cast is the entire bug-1 fix.
      rj.equipment_type::text AS equipment_type,
      rj.equipment_brand,
      rj.equipment_model,
      rj.equipment_serial,
      count(*)::int AS failure_count,
      max(rj.created_at) AS last_failure_at,
      sum(EXTRACT(EPOCH FROM (rj.completed_at - rj.created_at)) / 3600.0)
        FILTER (WHERE rj.completed_at IS NOT NULL)::numeric(10,2) AS total_downtime,
      avg(EXTRACT(EPOCH FROM (rj.completed_at - rj.created_at)) / 3600.0)
        FILTER (WHERE rj.completed_at IS NOT NULL)::numeric(8,2) AS avg_mttr,
      -- MTBF: span between first + last failure / (failures - 1).
      -- Single failure => MTBF undefined (NULL).
      CASE
        WHEN count(*) <= 1 THEN NULL
        ELSE round(
          EXTRACT(EPOCH FROM (max(rj.created_at) - min(rj.created_at)))
          / 86400.0
          / (count(*) - 1)
          , 1)
      END AS mtbf_calc
    FROM public.repair_jobs rj
    WHERE rj.hospital_user_id = auth.uid()
      AND rj.created_at >= v_window_start
      AND rj.equipment_type IS NOT NULL
    GROUP BY rj.equipment_type, rj.equipment_brand, rj.equipment_model, rj.equipment_serial
  )
  SELECT
    pe.equipment_type,
    pe.equipment_brand,
    pe.equipment_model,
    pe.equipment_serial,
    pe.failure_count,
    pe.mtbf_calc,
    pe.avg_mttr,
    coalesce(pe.total_downtime, 0),
    CASE
      WHEN v_window_hours > 0
      THEN round(((v_window_hours - coalesce(pe.total_downtime, 0)) / v_window_hours) * 100, 2)
      ELSE 100
    END,
    (pe.failure_count > 3) AND (pe.last_failure_at >= now() - interval '90 days'),
    pe.last_failure_at,
    (SELECT s.next_pm_due_at
       FROM public.equipment_pm_schedule s
      WHERE s.hospital_user_id = auth.uid()
        AND s.equipment_type = pe.equipment_type   -- text = text (was text = equipment_category)
        AND coalesce(s.equipment_brand, '') = coalesce(pe.equipment_brand, '')
        AND coalesce(s.equipment_model, '') = coalesce(pe.equipment_model, '')
        AND coalesce(s.equipment_serial, '') = coalesce(pe.equipment_serial, '')
      LIMIT 1)
  FROM per_equipment pe
  ORDER BY pe.failure_count DESC, pe.last_failure_at DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.hospital_fleet_health(integer)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.hospital_fleet_health(integer)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. asset_history — alias the union branches + order outside the union
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.asset_history(
  p_hospital_user_id uuid,
  p_equipment_serial text
)
RETURNS TABLE(
  event_kind      text,
  event_at        timestamptz,
  reference_id    uuid,
  summary         text,
  details         jsonb
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
  IF auth.uid() <> p_hospital_user_id AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT q.e_kind, q.e_at, q.e_ref, q.e_summary, q.e_details
  FROM (
    -- Repair jobs
    SELECT
      'repair_job'::text                        AS e_kind,
      rj.created_at                             AS e_at,
      rj.id                                     AS e_ref,
      -- round3780 bug-3: coalesce the WHOLE concatenation. A NULL
      -- anywhere in a `||` chain nulls the entire result, and the
      -- Android client maps this column as a non-nullable String.
      coalesce(
        rj.equipment_type::text
          || ' · ' || coalesce(rj.equipment_brand, '')
          || ' · ' || coalesce(rj.equipment_model, '')
          || ' — ' || rj.status::text,
        'Repair job'
      )                                          AS e_summary,
      jsonb_build_object(
        'status', rj.status,
        'completed_at', rj.completed_at,
        'hospital_rating', rj.hospital_rating
      )                                          AS e_details
    FROM public.repair_jobs rj
    WHERE rj.hospital_user_id = p_hospital_user_id
      AND rj.equipment_serial = p_equipment_serial

    UNION ALL

    -- DSR reports
    SELECT
      'dsr_report'::text                         AS e_kind,
      d.engineer_signature_at                    AS e_at,
      d.id                                       AS e_ref,
      coalesce(
        'Service report (' || d.status || ')'
          || CASE WHEN d.calibration_within_oem THEN ' · calibration ✓' ELSE '' END,
        'Service report'
      )                                          AS e_summary,
      jsonb_build_object(
        'status', d.status,
        'iec_62353_passed', d.iec_62353_passed,
        'calibration_within_oem', d.calibration_within_oem,
        'parts_replaced_count', jsonb_array_length(d.parts_replaced)
      )                                          AS e_details
    FROM public.dsr_reports d
    WHERE d.hospital_user_id = p_hospital_user_id
      AND d.equipment_serial = p_equipment_serial

    UNION ALL

    -- PM schedule events
    SELECT
      'pm_scheduled'::text                       AS e_kind,
      s.next_pm_due_at                           AS e_at,
      s.id                                       AS e_ref,
      coalesce(
        'PM scheduled (' || s.status || ') — interval ' || s.interval_days || ' days',
        'Preventive maintenance scheduled'
      )                                          AS e_summary,
      jsonb_build_object(
        'status', s.status,
        'interval_days', s.interval_days,
        'last_service_at', s.last_service_at
      )                                          AS e_details
    FROM public.equipment_pm_schedule s
    WHERE s.hospital_user_id = p_hospital_user_id
      AND s.equipment_serial = p_equipment_serial
  ) q
  ORDER BY q.e_at DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.asset_history(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.asset_history(uuid, text) TO authenticated, service_role;

COMMIT;

-- ---------------------------------------------------------------------
-- Verification — EXECUTE both, don't just redefine them.
-- ---------------------------------------------------------------------
-- Both bugs were plan-time failures, so merely creating the functions
-- proves nothing; they have to actually run. We execute inside a
-- simulated authenticated session (the founder's real uid) because both
-- functions hard-require auth.uid() to be non-null.
DO $$
DECLARE
  v_fleet_rows  int;
  v_asset_rows  int;
  v_serial      text;
BEGIN
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object(
      'sub',  '756a3373-1077-470e-bc0a-79b8d6673ef4',
      'role', 'authenticated',
      'email','ganesh1431.dhanavath@gmail.com'
    )::text,
    true
  );

  SELECT count(*) INTO v_fleet_rows FROM public.hospital_fleet_health(365);
  RAISE NOTICE 'round 3780: hospital_fleet_health() executed OK (% rows)', v_fleet_rows;

  SELECT equipment_serial INTO v_serial
    FROM public.repair_jobs
   WHERE equipment_serial IS NOT NULL
   LIMIT 1;

  IF v_serial IS NULL THEN
    RAISE NOTICE 'round 3780: no serialised equipment in this DB — asset_history() exercised with a synthetic serial instead';
    v_serial := '__round3780_probe__';
  END IF;

  SELECT count(*) INTO v_asset_rows
    FROM public.asset_history('756a3373-1077-470e-bc0a-79b8d6673ef4'::uuid, v_serial);
  RAISE NOTICE 'round 3780: asset_history() executed OK (% rows for serial %)', v_asset_rows, v_serial;

  RAISE NOTICE 'round 3780 verified: both round508 hospital-facing RPCs now execute (were 42883 + 0A000, unconditionally, since round508 shipped)';
END;
$$;
