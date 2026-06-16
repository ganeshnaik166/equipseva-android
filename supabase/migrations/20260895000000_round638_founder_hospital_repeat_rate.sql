BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_repeat_rate();
CREATE OR REPLACE FUNCTION public.founder_hospital_repeat_rate()
RETURNS TABLE (
  bucket  text,
  cnt     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH counts AS (
    SELECT hospital_user_id, count(*)::int AS jobs
    FROM public.repair_jobs
    GROUP BY hospital_user_id
  ),
  buckets(label, ord) AS (
    VALUES
      ('1 job (one-shot)'::text, 1),
      ('2-3 jobs'::text,         2),
      ('4-10 jobs'::text,        3),
      ('>10 jobs (power)'::text, 4)
  )
  SELECT b.label,
    coalesce(
      count(*) FILTER (
        WHERE
          (b.ord = 1 AND c.jobs = 1) OR
          (b.ord = 2 AND c.jobs BETWEEN 2 AND 3) OR
          (b.ord = 3 AND c.jobs BETWEEN 4 AND 10) OR
          (b.ord = 4 AND c.jobs > 10)
      ),
      0
    )::bigint
  FROM buckets b LEFT JOIN counts c ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_repeat_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_repeat_rate() TO authenticated;
COMMIT;
