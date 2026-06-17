-- Round 850 — Recent dirty integrity events for the /security-overview page.
--
-- Pulls the last 50 device_integrity_checks rows where EITHER:
--   - pass = false  (Google said the device/app is dirty), OR
--   - client_integrity_header contains 'tampered' / 'root=1' / 'frida=1'
--     (client self-reported dirty)
-- so the founder can see fresh tamper signals at a glance.
BEGIN;

DROP FUNCTION IF EXISTS public.founder_integrity_recent_dirty();
CREATE OR REPLACE FUNCTION public.founder_integrity_recent_dirty()
RETURNS TABLE (
  id              uuid,
  user_id         uuid,
  display_name    text,
  action          text,
  pass            boolean,
  device_verdict  text,
  client_header   text,
  created_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.user_id,
    coalesce(p.full_name, '(user)'),
    c.action,
    c.pass,
    c.device_verdict,
    c.client_integrity_header,
    c.created_at
  FROM public.device_integrity_checks c
  LEFT JOIN public.profiles p ON p.id = c.user_id
  WHERE NOT c.pass
     OR c.client_integrity_header LIKE '%tampered%'
     OR c.client_integrity_header LIKE '%root=1%'
     OR c.client_integrity_header LIKE '%frida=1%'
     OR c.client_integrity_header LIKE '%emu=1%'
  ORDER BY c.created_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_integrity_recent_dirty() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_integrity_recent_dirty() TO authenticated;

COMMIT;
