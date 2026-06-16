BEGIN;
DROP FUNCTION IF EXISTS public.founder_spot_audits_by_month();
CREATE OR REPLACE FUNCTION public.founder_spot_audits_by_month()
RETURNS TABLE (
  month_ist     date,
  invitations   bigint,
  responses     bigint,
  response_pct  numeric,
  avg_rating    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.spot_audit_invitations i
       WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.spot_audit_responses r
       WHERE date_trunc('month', (r.responded_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint,
    CASE WHEN coalesce(
      (SELECT count(*) FROM public.spot_audit_invitations i WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) = 0
      THEN 0::numeric
      ELSE round(
        (SELECT count(*)::numeric FROM public.spot_audit_responses r WHERE date_trunc('month', (r.responded_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist)
        / (SELECT count(*)::numeric FROM public.spot_audit_invitations i WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist) * 100.0,
      1)
    END,
    coalesce(
      (SELECT round(avg(r.rating)::numeric, 2) FROM public.spot_audit_responses r
       WHERE date_trunc('month', (r.responded_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spot_audits_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spot_audits_by_month() TO authenticated;
COMMIT;
