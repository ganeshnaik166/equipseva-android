BEGIN;
DROP FUNCTION IF EXISTS public.founder_supervised_outcomes();
CREATE OR REPLACE FUNCTION public.founder_supervised_outcomes()
RETURNS TABLE (
  status         text,
  cnt            bigint,
  share_pct      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total FROM public.supervised_job_assignments;
  RETURN QUERY
  SELECT
    s.status,
    count(*)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(count(*)::numeric / v_total::numeric * 100.0, 1)
    END
  FROM public.supervised_job_assignments s
  GROUP BY s.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_supervised_outcomes() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_supervised_outcomes() TO authenticated;
COMMIT;
