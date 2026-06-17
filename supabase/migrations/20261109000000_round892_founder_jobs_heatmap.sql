BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_heatmap();
CREATE OR REPLACE FUNCTION public.founder_jobs_heatmap()
RETURNS TABLE (
  weekday   int,
  hour_ist  int,
  cnt       bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    extract(isodow FROM (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::int AS weekday,
    extract(hour   FROM (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::int AS hour_ist,
    count(*)::bigint
  FROM public.repair_jobs rj
  WHERE rj.created_at >= now() - interval '90 days'
  GROUP BY 1, 2
  ORDER BY 1, 2;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_heatmap() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_heatmap() TO authenticated;
COMMIT;
