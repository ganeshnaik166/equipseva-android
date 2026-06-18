BEGIN;
DROP FUNCTION IF EXISTS public.founder_notifications_by_kind_30d();
CREATE OR REPLACE FUNCTION public.founder_notifications_by_kind_30d()
RETURNS TABLE (
  kind              text,
  sent              bigint,
  read              bigint,
  read_pct          numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(n.kind, '(unknown)')::text                                           AS kind,
    count(*)::bigint                                                              AS sent,
    count(*) FILTER (WHERE n.read_at IS NOT NULL)::bigint                         AS read,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE n.read_at IS NOT NULL) / count(*), 1)
    END                                                                            AS read_pct
  FROM public.notifications n
  WHERE n.created_at >= now() - interval '30 days'
  GROUP BY coalesce(n.kind, '(unknown)')
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_notifications_by_kind_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_notifications_by_kind_30d() TO authenticated;
COMMIT;
