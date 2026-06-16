BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_tenure();
CREATE OR REPLACE FUNCTION public.founder_engineer_tenure()
RETURNS TABLE (
  bucket  text,
  cnt     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT (now() - e.created_at) AS age
    FROM public.engineers e
    WHERE e.verification_status = 'verified'
  ), buckets(label, ord, lo_days, hi_days) AS (
    VALUES
      ('0-30d'::text,   1, 0,   30),
      ('31-90d'::text,  2, 31,  90),
      ('91-180d'::text, 3, 91,  180),
      ('>180d'::text,   4, 181, 100000)
  )
  SELECT b.label,
         coalesce(count(*) FILTER (
           WHERE base.age >= make_interval(days => b.lo_days)
             AND base.age <  make_interval(days => b.hi_days + 1)
         ), 0)::bigint
  FROM buckets b LEFT JOIN base ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_tenure() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_tenure() TO authenticated;
COMMIT;
