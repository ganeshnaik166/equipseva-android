BEGIN;
DROP FUNCTION IF EXISTS public.founder_signups_recent();
CREATE OR REPLACE FUNCTION public.founder_signups_recent()
RETURNS TABLE (
  user_id      uuid,
  display_name text,
  role         text,
  state        text,
  city         text,
  created_at   timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    coalesce(p.full_name, '(unnamed)'),
    p.role::text,
    coalesce(nullif(trim(p.state), ''), '—'),
    coalesce(nullif(trim(p.city), ''), '—'),
    p.created_at
  FROM public.profiles p
  WHERE p.created_at >= now() - interval '7 days'
  ORDER BY p.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_signups_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_signups_recent() TO authenticated;
COMMIT;
