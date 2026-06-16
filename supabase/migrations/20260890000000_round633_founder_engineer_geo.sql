BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_geo();
CREATE OR REPLACE FUNCTION public.founder_engineer_geo()
RETURNS TABLE (
  city            text,
  verified_cnt    bigint,
  pending_cnt     bigint,
  rejected_cnt    bigint,
  total_cnt       bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(trim(e.city), ''), '(unknown)')                                    AS city,
    count(*) FILTER (WHERE e.verification_status = 'verified')::bigint                 AS verified_cnt,
    count(*) FILTER (WHERE e.verification_status = 'pending')::bigint                  AS pending_cnt,
    count(*) FILTER (WHERE e.verification_status = 'rejected')::bigint                 AS rejected_cnt,
    count(*)::bigint                                                                    AS total_cnt
  FROM public.engineers e
  GROUP BY 1
  ORDER BY total_cnt DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_geo() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_geo() TO authenticated;
COMMIT;
