-- Round 1234 — Device integrity checks snapshot summary for /device-integrity-checks-summary.
--
-- One-row, 14-KPI rollup over public.device_integrity_checks for the founder
-- console. The table is Play Integrity attestation log (server-only writes
-- via verify-play-integrity Edge Function). Each row = one verification
-- attempt with Google + the X-Equipseva-Integrity client self-report.
--
-- KPIs cover three lenses:
--   * volume — total checks all-time + 24h/7d/30d
--   * failure — fail counts + pass% across 7d/30d windows
--   * tamper — client-header self-reports (tampered / root / frida / emu)
--
-- Columns confirmed against migrations:
--   device_integrity_checks(id, user_id, action, device_verdict, app_verdict,
--     licensing_verdict, raw_token_hash, pass, created_at,
--     client_integrity_header)
BEGIN;

DROP FUNCTION IF EXISTS public.founder_device_integrity_checks_summary();
CREATE OR REPLACE FUNCTION public.founder_device_integrity_checks_summary()
RETURNS TABLE (
  total_all_time          bigint,
  checks_24h              bigint,
  checks_7d               bigint,
  checks_30d              bigint,
  fail_7d                 bigint,
  fail_30d                bigint,
  pass_pct_7d             numeric,
  pass_pct_30d            numeric,
  dirty_header_7d         bigint,
  dirty_header_30d        bigint,
  rooted_30d              bigint,
  emulator_30d            bigint,
  unique_users_failed_30d bigint,
  last_check_at           timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      c.user_id,
      c.pass,
      c.client_integrity_header,
      c.created_at
    FROM public.device_integrity_checks c
  )
  SELECT
    (SELECT count(*)::bigint FROM base) AS total_all_time,
    (SELECT count(*)::bigint FROM base WHERE created_at >= now() - interval '24 hours') AS checks_24h,
    (SELECT count(*)::bigint FROM base WHERE created_at >= now() - interval '7 days') AS checks_7d,
    (SELECT count(*)::bigint FROM base WHERE created_at >= now() - interval '30 days') AS checks_30d,
    (SELECT count(*)::bigint FROM base WHERE created_at >= now() - interval '7 days' AND NOT pass) AS fail_7d,
    (SELECT count(*)::bigint FROM base WHERE created_at >= now() - interval '30 days' AND NOT pass) AS fail_30d,
    CASE WHEN (SELECT count(*) FROM base WHERE created_at >= now() - interval '7 days') = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM base WHERE created_at >= now() - interval '7 days' AND pass)
           / (SELECT count(*)::numeric FROM base WHERE created_at >= now() - interval '7 days')
           * 100.0, 1)
    END AS pass_pct_7d,
    CASE WHEN (SELECT count(*) FROM base WHERE created_at >= now() - interval '30 days') = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM base WHERE created_at >= now() - interval '30 days' AND pass)
           / (SELECT count(*)::numeric FROM base WHERE created_at >= now() - interval '30 days')
           * 100.0, 1)
    END AS pass_pct_30d,
    (SELECT count(*)::bigint FROM base
      WHERE created_at >= now() - interval '7 days'
        AND client_integrity_header LIKE '%tampered%') AS dirty_header_7d,
    (SELECT count(*)::bigint FROM base
      WHERE created_at >= now() - interval '30 days'
        AND client_integrity_header LIKE '%tampered%') AS dirty_header_30d,
    (SELECT count(*)::bigint FROM base
      WHERE created_at >= now() - interval '30 days'
        AND client_integrity_header LIKE '%root=1%') AS rooted_30d,
    (SELECT count(*)::bigint FROM base
      WHERE created_at >= now() - interval '30 days'
        AND client_integrity_header LIKE '%emu=1%') AS emulator_30d,
    (SELECT count(DISTINCT user_id)::bigint FROM base
      WHERE created_at >= now() - interval '30 days'
        AND NOT pass) AS unique_users_failed_30d,
    (SELECT max(created_at) FROM base) AS last_check_at;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_device_integrity_checks_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_device_integrity_checks_summary() TO authenticated;

COMMIT;
