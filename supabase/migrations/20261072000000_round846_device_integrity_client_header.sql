-- Round 846 — Capture client-side integrity self-report alongside Play
-- Integrity verification.
--
-- The Android client (r844) stamps every Supabase request with an
-- X-Equipseva-Integrity header carrying its boot-time signature/install/
-- root/Frida verdicts. A tampered client CAN lie about this header, but
-- most lazy mods strip only one if-block in onCreate without touching the
-- snapshot — so the header still flags a lot of real-world tampering.
--
-- This migration:
--   1. Adds client_integrity_header text column to device_integrity_checks
--      so verify-play-integrity (r846 update) can persist the header value
--      alongside Google's verdict on every call.
--   2. Adds an index on dirty-self-reports so the founder /integrity-events
--      view can sort by them fast.
--   3. Adds a founder RPC that returns recent integrity events for the
--      console UI.
BEGIN;

ALTER TABLE public.device_integrity_checks
  ADD COLUMN IF NOT EXISTS client_integrity_header text;

CREATE INDEX IF NOT EXISTS device_integrity_checks_dirty_header_idx
  ON public.device_integrity_checks (created_at DESC)
  WHERE client_integrity_header IS NOT NULL
    AND client_integrity_header LIKE '%tampered%';

DROP FUNCTION IF EXISTS public.founder_integrity_events();
CREATE OR REPLACE FUNCTION public.founder_integrity_events()
RETURNS TABLE (
  id                  uuid,
  user_id             uuid,
  display_name        text,
  action              text,
  pass                boolean,
  device_verdict      text,
  app_verdict         text,
  client_header       text,
  created_at          timestamptz
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
    c.app_verdict,
    c.client_integrity_header,
    c.created_at
  FROM public.device_integrity_checks c
  LEFT JOIN public.profiles p ON p.id = c.user_id
  ORDER BY c.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_integrity_events() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_integrity_events() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_integrity_summary();
CREATE OR REPLACE FUNCTION public.founder_integrity_summary()
RETURNS TABLE (
  window_label    text,
  total_checks    bigint,
  pass_count      bigint,
  fail_count      bigint,
  dirty_header    bigint,
  pass_pct        numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  )
  SELECT
    w.label,
    coalesce((SELECT count(*)::bigint FROM public.device_integrity_checks c WHERE c.created_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.device_integrity_checks c WHERE c.created_at >= w.cutoff AND c.pass), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.device_integrity_checks c WHERE c.created_at >= w.cutoff AND NOT c.pass), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.device_integrity_checks c
              WHERE c.created_at >= w.cutoff
                AND c.client_integrity_header LIKE '%tampered%'), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.device_integrity_checks c WHERE c.created_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.device_integrity_checks c WHERE c.created_at >= w.cutoff AND c.pass)
           / (SELECT count(*)::numeric FROM public.device_integrity_checks c WHERE c.created_at >= w.cutoff)
           * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_integrity_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_integrity_summary() TO authenticated;

COMMIT;
