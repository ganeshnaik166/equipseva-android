BEGIN;

DROP FUNCTION IF EXISTS public.founder_engineer_attendance_summary();

CREATE OR REPLACE FUNCTION public.founder_engineer_attendance_summary()
RETURNS TABLE (
  events_total                  bigint,
  arrivals_total                bigint,
  departures_total              bigint,
  events_last_24h               bigint,
  events_last_7d                bigint,
  arrivals_last_24h             bigint,
  unique_engineers_checked_in_24h bigint,
  unique_engineers_checked_in_7d  bigint,
  suspicious_events_total       bigint,
  suspicious_events_24h         bigint,
  suspicious_rate_pct           numeric,
  verified_engineers_no_checkin_7d bigint
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
  WITH base AS (
    SELECT
      ea.id,
      ea.engineer_user_id,
      ea.event_kind,
      ea.suspicious_distance,
      ea.device_captured_at,
      ea.created_at
    FROM public.engineer_attendance ea
  ),
  agg AS (
    SELECT
      count(*)::bigint AS events_total,
      count(*) FILTER (WHERE event_kind = 'arrival_checkin')::bigint AS arrivals_total,
      count(*) FILTER (WHERE event_kind = 'departure_checkout')::bigint AS departures_total,
      count(*) FILTER (WHERE created_at >= now() - interval '24 hours')::bigint AS events_last_24h,
      count(*) FILTER (WHERE created_at >= now() - interval '7 days')::bigint AS events_last_7d,
      count(*) FILTER (WHERE event_kind = 'arrival_checkin'
                         AND created_at >= now() - interval '24 hours')::bigint AS arrivals_last_24h,
      count(DISTINCT engineer_user_id) FILTER (
        WHERE event_kind = 'arrival_checkin'
          AND created_at >= now() - interval '24 hours'
      )::bigint AS unique_engineers_checked_in_24h,
      count(DISTINCT engineer_user_id) FILTER (
        WHERE event_kind = 'arrival_checkin'
          AND created_at >= now() - interval '7 days'
      )::bigint AS unique_engineers_checked_in_7d,
      count(*) FILTER (WHERE suspicious_distance = true)::bigint AS suspicious_events_total,
      count(*) FILTER (
        WHERE suspicious_distance = true
          AND created_at >= now() - interval '24 hours'
      )::bigint AS suspicious_events_24h
    FROM base
  ),
  verified AS (
    SELECT count(*)::bigint AS verified_total
    FROM public.engineers e
    WHERE e.verification_status = 'verified'
  ),
  recent_checkin_engineers AS (
    SELECT DISTINCT engineer_user_id
    FROM public.engineer_attendance
    WHERE event_kind = 'arrival_checkin'
      AND created_at >= now() - interval '7 days'
  )
  SELECT
    a.events_total,
    a.arrivals_total,
    a.departures_total,
    a.events_last_24h,
    a.events_last_7d,
    a.arrivals_last_24h,
    a.unique_engineers_checked_in_24h,
    a.unique_engineers_checked_in_7d,
    a.suspicious_events_total,
    a.suspicious_events_24h,
    CASE WHEN a.events_total > 0
         THEN round(a.suspicious_events_total * 100.0 / a.events_total, 2)
         ELSE 0
    END AS suspicious_rate_pct,
    GREATEST(
      (SELECT verified_total FROM verified)
      - (SELECT count(*) FROM public.engineers e
          WHERE e.verification_status = 'verified'
            AND e.user_id IN (SELECT engineer_user_id FROM recent_checkin_engineers)),
      0
    )::bigint AS verified_engineers_no_checkin_7d
  FROM agg a;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_attendance_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_attendance_summary() TO authenticated;

COMMIT;