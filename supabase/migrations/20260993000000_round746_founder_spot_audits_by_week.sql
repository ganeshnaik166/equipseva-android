BEGIN;
DROP FUNCTION IF EXISTS public.founder_spot_audits_by_week();
CREATE OR REPLACE FUNCTION public.founder_spot_audits_by_week()
RETURNS TABLE (
  week_start   date,
  invitations  bigint,
  responses    bigint,
  response_pct numeric,
  avg_rating   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '12 weeks'),
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.spot_audit_invitations i
              WHERE date_trunc('week', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.spot_audit_responses r
              WHERE date_trunc('week', (r.responded_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.spot_audit_invitations i WHERE date_trunc('week', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0) = 0
      THEN 0::numeric
      ELSE round(
        (SELECT count(*)::numeric FROM public.spot_audit_responses r WHERE date_trunc('week', (r.responded_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start)
        / (SELECT count(*)::numeric FROM public.spot_audit_invitations i WHERE date_trunc('week', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start) * 100.0,
      1)
    END,
    coalesce((SELECT round(avg(r.rating)::numeric, 2) FROM public.spot_audit_responses r
              WHERE date_trunc('week', (r.responded_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spot_audits_by_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spot_audits_by_week() TO authenticated;
COMMIT;
