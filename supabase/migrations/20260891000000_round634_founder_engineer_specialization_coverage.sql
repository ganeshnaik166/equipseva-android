BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_specialization_coverage();
CREATE OR REPLACE FUNCTION public.founder_engineer_specialization_coverage()
RETURNS TABLE (
  category        text,
  verified_cnt    bigint,
  total_cnt       bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH unrolled AS (
    SELECT e.id, e.verification_status, unnest(e.specializations) AS cat
    FROM public.engineers e
    WHERE e.specializations IS NOT NULL
      AND array_length(e.specializations, 1) IS NOT NULL
  )
  SELECT
    cat,
    count(*) FILTER (WHERE verification_status = 'verified')::bigint AS verified_cnt,
    count(*)::bigint                                                  AS total_cnt
  FROM unrolled
  GROUP BY cat
  ORDER BY verified_cnt DESC, total_cnt DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_specialization_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_specialization_coverage() TO authenticated;
COMMIT;
