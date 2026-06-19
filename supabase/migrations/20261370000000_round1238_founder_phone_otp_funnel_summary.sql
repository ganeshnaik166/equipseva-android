BEGIN;
-- Round 1238 — founder_phone_otp_funnel_summary
-- Single-row snapshot of SMS-OTP layer health BEFORE the signup funnel begins.
-- Source: phone_otp_requests (id, phone, requested_at, user_id, ip_hash).
-- Verify success approximated by joining phone to auth.users.phone_confirmed_at.
-- Untapped signal: catches Twilio outages + bot bursts before founder hears
-- about it via support tickets.

DROP FUNCTION IF EXISTS public.founder_phone_otp_funnel_summary();
CREATE OR REPLACE FUNCTION public.founder_phone_otp_funnel_summary()
RETURNS TABLE (
  -- volume
  requests_24h            bigint,
  requests_7d             bigint,
  requests_30d            bigint,
  unique_phones_24h       bigint,
  unique_phones_7d        bigint,
  -- verify approximation
  verified_phones_7d      bigint,
  verify_rate_pct_7d      numeric,
  -- resend / abandonment behavior (multiple rows same phone, short window)
  resend_phones_24h       bigint,
  avg_attempts_per_phone_24h numeric,
  -- abuse / rate-limit
  rate_limit_hits_24h     bigint,
  burst_phones_24h        bigint,
  -- channel
  anon_share_pct_7d       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH r24 AS (
    SELECT * FROM public.phone_otp_requests
     WHERE requested_at > now() - interval '24 hours'
  ),
  r7 AS (
    SELECT * FROM public.phone_otp_requests
     WHERE requested_at > now() - interval '7 days'
  ),
  r30 AS (
    SELECT * FROM public.phone_otp_requests
     WHERE requested_at > now() - interval '30 days'
  ),
  per_phone_24h AS (
    SELECT phone, count(*)::bigint AS attempts
      FROM r24
     GROUP BY phone
  ),
  -- A "burst" = same phone hit the 5/hour cap (≥5 requests in any rolling hour
  -- inside the 24h window). Proxy: phones with ≥5 attempts in the last hour.
  bursts AS (
    SELECT phone
      FROM public.phone_otp_requests
     WHERE requested_at > now() - interval '1 hour'
     GROUP BY phone
    HAVING count(*) >= 5
  ),
  verify7 AS (
    SELECT count(DISTINCT r7.phone)::bigint AS verified
      FROM r7
      JOIN auth.users u
        ON u.phone = r7.phone
       AND u.phone_confirmed_at IS NOT NULL
       AND u.phone_confirmed_at >= r7.requested_at - interval '15 minutes'
  )
  SELECT
    (SELECT count(*)::bigint FROM r24),
    (SELECT count(*)::bigint FROM r7),
    (SELECT count(*)::bigint FROM r30),
    (SELECT count(DISTINCT phone)::bigint FROM r24),
    (SELECT count(DISTINCT phone)::bigint FROM r7),
    coalesce((SELECT verified FROM verify7), 0),
    CASE
      WHEN (SELECT count(DISTINCT phone) FROM r7) > 0
        THEN round(
          100.0 * coalesce((SELECT verified FROM verify7), 0)
          / (SELECT count(DISTINCT phone) FROM r7),
          1)
      ELSE 0
    END,
    (SELECT count(*)::bigint FROM per_phone_24h WHERE attempts >= 2),
    CASE
      WHEN (SELECT count(*) FROM per_phone_24h) > 0
        THEN round(
          (SELECT avg(attempts)::numeric FROM per_phone_24h), 2)
      ELSE 0
    END,
    -- rate_limit_hits_24h: phones that exceeded 5/hour at any point in 24h.
    -- Approximated by phones with ≥6 attempts in any single hour bucket.
    coalesce((
      SELECT count(DISTINCT phone)::bigint
        FROM (
          SELECT phone, date_trunc('hour', requested_at) AS hr, count(*) AS c
            FROM r24
           GROUP BY phone, date_trunc('hour', requested_at)
          HAVING count(*) >= 5
        ) x
    ), 0),
    (SELECT count(*)::bigint FROM bursts),
    CASE
      WHEN (SELECT count(*) FROM r7) > 0
        THEN round(
          100.0 * (SELECT count(*) FROM r7 WHERE user_id IS NULL)
          / (SELECT count(*) FROM r7),
          1)
      ELSE 0
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_phone_otp_funnel_summary()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_phone_otp_funnel_summary()
  TO authenticated;

COMMENT ON FUNCTION public.founder_phone_otp_funnel_summary() IS
  'Round 1238 — single-row SMS-OTP layer snapshot: volume, verify-rate, '
  'resend behavior, burst/rate-limit hits. Untapped pre-signup-funnel signal.';
COMMIT;
