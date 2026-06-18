BEGIN;
DROP FUNCTION IF EXISTS public.founder_supervised_by_day_30d();
CREATE OR REPLACE FUNCTION public.founder_supervised_by_day_30d()
RETURNS TABLE (
  day_ist          date,
  requested        bigint,
  active           bigint,
  successful       bigint,
  failed           bigint,
  declined         bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 29,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
              WHERE (s.requested_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS requested,
    coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
              WHERE s.status = 'active'
                AND (s.requested_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS active,
    coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
              WHERE s.status = 'completed_successful'
                AND (s.requested_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS successful,
    coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
              WHERE s.status = 'completed_failed'
                AND (s.requested_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS failed,
    coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
              WHERE s.status = 'declined'
                AND (s.requested_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS declined
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_supervised_by_day_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_supervised_by_day_30d() TO authenticated;
COMMIT;
