BEGIN;
DROP FUNCTION IF EXISTS public.founder_repair_jobs_status_snapshot();
CREATE OR REPLACE FUNCTION public.founder_repair_jobs_status_snapshot()
RETURNS TABLE (
  status      text,
  cnt         bigint,
  share_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total FROM public.repair_jobs;
  RETURN QUERY
  SELECT
    rj.status::text,
    count(*)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(count(*)::numeric / v_total::numeric * 100.0, 1)
    END
  FROM public.repair_jobs rj
  GROUP BY rj.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_repair_jobs_status_snapshot() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_jobs_status_snapshot() TO authenticated;
COMMIT;
