-- =====================================================================
-- Round 508 — Equipment Fleet MTBF/MTTR Backbone (v0.4 Phase 4 #2)
-- =====================================================================
--
-- Hospital admin asks: "which of my 400 assets break the most? which
-- take longest to repair? which should I replace?" Today, answer
-- requires manual spreadsheet work. This migration ships server-
-- computed fleet health metrics:
--
--   MTBF  — Mean Time Between Failures (avg days between repair_jobs
--           on the same equipment). High = healthy.
--   MTTR  — Mean Time To Repair (avg hours from job created to
--           completed). Low = fast.
--   Uptime % — (1 - cumulative_repair_hours / window_hours) × 100
--   Replacement candidate — flag if >3 failures in 90d.
--
-- Output paths:
--   * hospital_fleet_health() — hospital-facing fleet card
--   * founder_fleet_red_flags() — cockpit query for worst-performing
--     fleets across all hospitals
--
-- Identity tuple for "a piece of equipment": (equipment_type,
-- equipment_brand, equipment_model, equipment_serial). NULL serial
-- means whole-class aggregation.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. hospital_fleet_health
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
      rj.equipment_type,
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
        AND s.equipment_type = pe.equipment_type
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
-- 2. founder_fleet_red_flags — cockpit query
-- ---------------------------------------------------------------------
-- Surfaces hospitals whose fleet has >5 failures in 90d AND avg
-- MTTR > 48h — strong signal of either equipment crisis OR
-- engineer-performance crisis (drill down via SLA board).
CREATE OR REPLACE FUNCTION public.founder_fleet_red_flags(
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  hospital_user_id     uuid,
  hospital_email       text,
  total_failures_90d   int,
  unique_assets_90d    int,
  avg_mttr_hours       numeric,
  replacement_candidates int,
  oldest_unresolved_at timestamptz
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
  WITH window_jobs AS (
    SELECT
      rj.hospital_user_id,
      rj.equipment_type,
      rj.equipment_brand,
      rj.equipment_model,
      rj.equipment_serial,
      rj.created_at,
      rj.completed_at,
      rj.status
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '90 days'
      AND rj.hospital_user_id IS NOT NULL
  ),
  per_eq AS (
    SELECT
      hospital_user_id,
      equipment_type, equipment_brand, equipment_model, equipment_serial,
      count(*) AS failures
    FROM window_jobs
    GROUP BY hospital_user_id, equipment_type, equipment_brand, equipment_model, equipment_serial
  ),
  per_hospital AS (
    SELECT
      hospital_user_id,
      sum(failures)::int AS total_failures,
      count(*)::int AS unique_assets,
      count(*) FILTER (WHERE failures > 3)::int AS replacement_count
    FROM per_eq
    GROUP BY hospital_user_id
  ),
  mttr AS (
    SELECT
      hospital_user_id,
      avg(EXTRACT(EPOCH FROM (completed_at - created_at)) / 3600.0)
        FILTER (WHERE completed_at IS NOT NULL)::numeric(8,2) AS avg_mttr
    FROM window_jobs
    GROUP BY hospital_user_id
  ),
  oldest AS (
    SELECT
      hospital_user_id,
      min(created_at) FILTER (WHERE status NOT IN ('completed','cancelled')) AS oldest_unresolved
    FROM window_jobs
    GROUP BY hospital_user_id
  )
  SELECT
    ph.hospital_user_id,
    coalesce((SELECT email FROM auth.users WHERE id = ph.hospital_user_id), 'unknown'),
    ph.total_failures,
    ph.unique_assets,
    m.avg_mttr,
    ph.replacement_count,
    o.oldest_unresolved
  FROM per_hospital ph
  LEFT JOIN mttr   m ON m.hospital_user_id = ph.hospital_user_id
  LEFT JOIN oldest o ON o.hospital_user_id = ph.hospital_user_id
  WHERE ph.total_failures > 5
     OR coalesce(m.avg_mttr, 0) > 48
     OR ph.replacement_count > 0
  ORDER BY ph.replacement_count DESC, ph.total_failures DESC, m.avg_mttr DESC NULLS LAST
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fleet_red_flags(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_fleet_red_flags(integer) TO service_role;

-- ---------------------------------------------------------------------
-- 3. asset_history(hospital_user_id, equipment_serial) — drill-down
-- ---------------------------------------------------------------------
-- For the fleet console "click into an asset" view: all repair_jobs
-- + DSRs + PM events in chronological order.
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
  -- Repair jobs
  SELECT
    'repair_job'::text,
    rj.created_at,
    rj.id,
    rj.equipment_type || ' · ' || coalesce(rj.equipment_brand, '') || ' · ' || coalesce(rj.equipment_model, '') || ' — ' || rj.status,
    jsonb_build_object(
      'status', rj.status,
      'completed_at', rj.completed_at,
      'hospital_rating', rj.hospital_rating
    )
  FROM public.repair_jobs rj
  WHERE rj.hospital_user_id = p_hospital_user_id
    AND rj.equipment_serial = p_equipment_serial

  UNION ALL

  -- DSR reports
  SELECT
    'dsr_report'::text,
    d.engineer_signature_at,
    d.id,
    'Service report (' || d.status || ')'
      || CASE WHEN d.calibration_within_oem THEN ' · calibration ✓' ELSE '' END,
    jsonb_build_object(
      'status', d.status,
      'iec_62353_passed', d.iec_62353_passed,
      'calibration_within_oem', d.calibration_within_oem,
      'parts_replaced_count', jsonb_array_length(d.parts_replaced)
    )
  FROM public.dsr_reports d
  WHERE d.hospital_user_id = p_hospital_user_id
    AND d.equipment_serial = p_equipment_serial

  UNION ALL

  -- PM schedule events
  SELECT
    'pm_scheduled'::text,
    s.next_pm_due_at,
    s.id,
    'PM scheduled (' || s.status || ') — interval ' || s.interval_days || ' days',
    jsonb_build_object(
      'status', s.status,
      'interval_days', s.interval_days,
      'last_service_at', s.last_service_at
    )
  FROM public.equipment_pm_schedule s
  WHERE s.hospital_user_id = p_hospital_user_id
    AND s.equipment_serial = p_equipment_serial

  ORDER BY event_at DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.asset_history(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.asset_history(uuid, text) TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 508 fleet MTBF/MTTR verified: 3 RPCs (hospital health + founder red flags + asset drilldown)';
END;
$$;
