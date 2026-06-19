BEGIN;

DROP FUNCTION IF EXISTS public.founder_dsr_data_export_sla_summary();

CREATE OR REPLACE FUNCTION public.founder_dsr_data_export_sla_summary()
RETURNS TABLE (
  open_dsr_now              bigint,
  breached_sla_open         bigint,
  approaching_24h_open      bigint,
  filed_today               bigint,
  filed_7d                  bigint,
  filed_30d                 bigint,
  resolved_today            bigint,
  resolved_7d               bigint,
  resolved_30d              bigint,
  avg_resolution_hours_30d  numeric,
  p90_resolution_hours_30d  numeric,
  oldest_open_age_hours     numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH dsr AS (
    SELECT
      g.id,
      g.grievance_type,
      g.status,
      g.deadline_at,
      g.created_at,
      g.resolved_at,
      g.sla_hours
    FROM public.dpdp_grievances g
    WHERE g.grievance_type IN (
      'data_portability',
      'access_request',
      'deletion_request',
      'correction_request',
      'consent_withdrawal'
    )
  ),
  resolved_30 AS (
    SELECT
      EXTRACT(EPOCH FROM (resolved_at - created_at)) / 3600.0 AS hours
    FROM dsr
    WHERE status IN ('resolved','rejected')
      AND resolved_at IS NOT NULL
      AND resolved_at >= now() - interval '30 days'
      AND resolved_at >= created_at
  )
  SELECT
    -- open_dsr_now: anything still in open/in_review/escalated
    (SELECT count(*) FROM dsr WHERE status IN ('open','in_review','escalated'))::bigint,
    -- breached_sla_open: still open + past deadline
    (SELECT count(*) FROM dsr
      WHERE status IN ('open','in_review','escalated')
        AND deadline_at < now())::bigint,
    -- approaching_24h_open: still open + deadline within next 24h
    (SELECT count(*) FROM dsr
      WHERE status IN ('open','in_review','escalated')
        AND deadline_at >= now()
        AND deadline_at <= now() + interval '24 hours')::bigint,
    -- filed_today (IST day)
    (SELECT count(*) FROM dsr
      WHERE created_at >= v_today_start AND created_at < v_today_end)::bigint,
    -- filed_7d
    (SELECT count(*) FROM dsr
      WHERE created_at >= now() - interval '7 days')::bigint,
    -- filed_30d
    (SELECT count(*) FROM dsr
      WHERE created_at >= now() - interval '30 days')::bigint,
    -- resolved_today (IST day)
    (SELECT count(*) FROM dsr
      WHERE resolved_at >= v_today_start AND resolved_at < v_today_end
        AND status IN ('resolved','rejected'))::bigint,
    -- resolved_7d
    (SELECT count(*) FROM dsr
      WHERE resolved_at >= now() - interval '7 days'
        AND status IN ('resolved','rejected'))::bigint,
    -- resolved_30d
    (SELECT count(*) FROM dsr
      WHERE resolved_at >= now() - interval '30 days'
        AND status IN ('resolved','rejected'))::bigint,
    -- avg_resolution_hours_30d
    COALESCE((SELECT round(avg(hours)::numeric, 1) FROM resolved_30), 0::numeric),
    -- p90_resolution_hours_30d
    COALESCE((SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY hours)::numeric, 1) FROM resolved_30), 0::numeric),
    -- oldest_open_age_hours (open DSR creation lag)
    COALESCE((SELECT round((EXTRACT(EPOCH FROM (now() - min(created_at))) / 3600.0)::numeric, 1)
                FROM dsr WHERE status IN ('open','in_review','escalated')), 0::numeric);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_dsr_data_export_sla_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dsr_data_export_sla_summary() TO authenticated;

COMMIT;
