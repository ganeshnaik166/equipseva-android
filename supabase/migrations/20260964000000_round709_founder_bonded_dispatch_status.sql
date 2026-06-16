BEGIN;
DROP FUNCTION IF EXISTS public.founder_bonded_dispatch_status();
CREATE OR REPLACE FUNCTION public.founder_bonded_dispatch_status()
RETURNS TABLE (
  status     text,
  cnt        bigint,
  total_qty  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    dp.status,
    count(*)::bigint,
    coalesce(sum(dp.quantity), 0)::bigint
  FROM public.bonded_parts_dispatch dp
  GROUP BY dp.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bonded_dispatch_status() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bonded_dispatch_status() TO authenticated;
COMMIT;
