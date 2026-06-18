-- r918 — Renamed wrapper around the existing service_role-only
-- founder_code_red_recent(integer,integer) so the founder web app can
-- call it from an authenticated SSR session. r848 added authenticated
-- grant on the original; this is a sibling list-view (status + duration)
-- without paging args, more aligned with other r9xx _recent surfaces.
BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_recent_v2();
CREATE OR REPLACE FUNCTION public.founder_code_red_recent_v2()
RETURNS TABLE (
  id              uuid,
  hospital_name   text,
  equipment_type  text,
  status          text,
  accepted_at     timestamptz,
  resolved_at     timestamptz,
  created_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    coalesce(p.full_name, '(hospital)'),
    r.equipment_type,
    r.status::text,
    r.accepted_at,
    r.resolved_at,
    r.created_at
  FROM public.code_red_requests r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  WHERE r.created_at >= now() - interval '30 days'
  ORDER BY r.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_recent_v2() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_recent_v2() TO authenticated;
COMMIT;
