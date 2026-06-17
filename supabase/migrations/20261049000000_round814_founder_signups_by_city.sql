BEGIN;
DROP FUNCTION IF EXISTS public.founder_signups_by_city();
CREATE OR REPLACE FUNCTION public.founder_signups_by_city()
RETURNS TABLE (
  city          text,
  signups_90d   bigint,
  engineers     bigint,
  hospitals     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH recent AS (
    SELECT
      coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
      p.role::text                                     AS role
    FROM public.profiles p
    WHERE p.created_at >= now() - interval '90 days'
  )
  SELECT
    r.city,
    count(*)::bigint,
    count(*) FILTER (WHERE r.role = 'engineer')::bigint,
    count(*) FILTER (WHERE r.role = 'hospital')::bigint
  FROM recent r
  GROUP BY r.city
  ORDER BY signups_90d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_signups_by_city() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_signups_by_city() TO authenticated;
COMMIT;
