BEGIN;
DROP FUNCTION IF EXISTS public.founder_signups_by_state();
CREATE OR REPLACE FUNCTION public.founder_signups_by_state()
RETURNS TABLE (
  state         text,
  total_90d     bigint,
  engineers_90d bigint,
  hospitals_90d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
    count(*)::bigint,
    count(*) FILTER (WHERE p.role = 'engineer')::bigint,
    count(*) FILTER (WHERE p.role = 'hospital')::bigint
  FROM public.profiles p
  WHERE p.created_at >= now() - interval '90 days'
  GROUP BY 1
  ORDER BY total_90d DESC
  LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_signups_by_state() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_signups_by_state() TO authenticated;
COMMIT;
