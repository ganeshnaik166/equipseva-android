BEGIN;
DROP FUNCTION IF EXISTS public.founder_dpdp_grievance_pulse_summary();
CREATE OR REPLACE FUNCTION public.founder_dpdp_grievance_pulse_summary()
RETURNS TABLE (
  grievances_total          bigint,
  grievances_open           bigint,
  grievances_in_review      bigint,
  grievances_resolved       bigint,
  grievances_escalated      bigint,
  sla_breached_open         bigint,
  sla_at_risk_72h           bigint,
  type_erasure_open         bigint,
  type_correction_open      bigint,
  type_breach_notif_open    bigint,
  avg_resolution_days       numeric,
  filed_today               bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances WHERE status = 'open'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances WHERE status = 'in_review'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances WHERE status = 'resolved'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances WHERE status = 'escalated'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances
              WHERE status IN ('open','in_review') AND deadline_at < now()), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances
              WHERE status IN ('open','in_review')
                AND deadline_at >= now()
                AND deadline_at <= now() + interval '72 hours'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances
              WHERE status IN ('open','in_review') AND grievance_type = 'deletion_request'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances
              WHERE status IN ('open','in_review') AND grievance_type = 'correction_request'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances
              WHERE status IN ('open','in_review') AND grievance_type = 'data_breach_notification'), 0),
    coalesce((SELECT round(avg(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 86400)::numeric, 2)
              FROM public.dpdp_grievances
              WHERE resolved_at IS NOT NULL
                AND resolved_at >= now() - interval '90 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievances
              WHERE created_at >= v_today_start AND created_at < v_today_end), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_dpdp_grievance_pulse_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dpdp_grievance_pulse_summary() TO authenticated;
COMMIT;
