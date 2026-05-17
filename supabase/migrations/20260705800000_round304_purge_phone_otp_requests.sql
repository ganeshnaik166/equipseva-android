-- Round 304 — TTL purge for phone_otp_requests.
--
-- phone_otp_requests is written by phone_otp_can_request on every OTP
-- send (5 per phone per hour). No purge function exists. The table
-- grows unbounded: assuming 1K active users * 1 OTP/month average,
-- that's 12K rows/year. At 10K active users it's 120K/year. Eventually
-- a meaningful chunk of disk + slows the per-phone count() query the
-- rate-limit RPC runs on every call.
--
-- Add `purge_old_phone_otp_requests` that keeps rows from the trailing
-- 7 days (the rate-limit window is 1 hour, so 7 days is generous for
-- forensic audits / fraud investigation). Match the other purges'
-- shape so cron-tick + pg_cron wiring is uniform.

CREATE OR REPLACE FUNCTION public.purge_old_phone_otp_requests()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  WITH gone AS (
    DELETE FROM public.phone_otp_requests
     WHERE requested_at < now() - interval '7 days'
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM gone;
  RETURN v_count;
END;
$$;

ALTER FUNCTION public.purge_old_phone_otp_requests() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.purge_old_phone_otp_requests() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_old_phone_otp_requests() TO service_role;

-- Wire into pg_cron (Pro tier) at 03:25 UTC after the other purges.
DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('purge-old-phone-otp-requests');
    PERFORM cron.schedule(
      'purge-old-phone-otp-requests',
      '25 3 * * *',
      $job$SELECT public.purge_old_phone_otp_requests();$job$
    );
  END IF;
EXCEPTION
  WHEN insufficient_privilege OR undefined_function OR undefined_table THEN
    RAISE NOTICE 'pg_cron: schedule failed. SQLSTATE=%, SQLERRM=%', SQLSTATE, SQLERRM;
END
$cron$;
