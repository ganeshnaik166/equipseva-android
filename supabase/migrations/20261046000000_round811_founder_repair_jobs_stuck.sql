BEGIN;
DROP FUNCTION IF EXISTS public.founder_repair_jobs_stuck();
CREATE OR REPLACE FUNCTION public.founder_repair_jobs_stuck()
RETURNS TABLE (
  status         text,
  cnt            bigint,
  oldest_days    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    rj.status::text,
    count(*)::bigint,
    coalesce(round(extract(epoch FROM (now() - min(rj.created_at))) / 86400.0, 1)::numeric, 0)::numeric
  FROM public.repair_jobs rj
  WHERE rj.status NOT IN ('completed','cancelled')
    AND rj.created_at < now() - interval '14 days'
  GROUP BY rj.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_repair_jobs_stuck() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_jobs_stuck() TO authenticated;
COMMIT;
