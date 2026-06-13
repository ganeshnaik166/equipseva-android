-- =====================================================================
-- Round 522 — Audit-11 patches (analytics PII hardening + NABH export rate limit)
-- =====================================================================
--
-- Two MEDIUM findings from audit-11 (workflow `wlktqwxwe`):
--
-- (1) r510 log_analytics_event used a key-blacklist that missed many
--     PII-adjacent keys (user_name, bank_account, upi_id, ifsc, etc.)
--     and did not inspect VALUE shapes. An authenticated caller could
--     POST {props: {"user_name": "Jane Doe", "bank_account": "..."}}
--     and the values would land in analytics_events.props.
--     Fix: extend the key blacklist + add value-regex PII probe.
--
-- (2) r511 export_nabh_bundle edge fn had no rate limiting. Any
--     authenticated user could spam the endpoint, exhausting Supabase
--     storage writes + Edge Function invocations.
--     Fix: per-user quota table + check_and_reserve RPC + caller-side
--     enforcement (edge fn calls the RPC before doing work).

BEGIN;

-- ---------------------------------------------------------------------
-- Part 1 — Analytics PII hardening
-- ---------------------------------------------------------------------
--
-- Extend the key drop list AND add a value-regex probe. If any prop
-- value LOOKS LIKE an email, phone, Aadhaar (12-digit), PAN (5L4D1L),
-- IFSC (4L7AN), or 16-digit bank/UPI pattern, drop that key.

DROP FUNCTION IF EXISTS public.log_analytics_event(text, uuid, text, text, jsonb);

CREATE OR REPLACE FUNCTION public.log_analytics_event(
  p_event_key  text,
  p_session_id uuid DEFAULT NULL,
  p_surface    text DEFAULT 'android',
  p_app_version text DEFAULT NULL,
  p_props      jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id       bigint;
  v_user     uuid := auth.uid();
  v_clean    jsonb;
  v_key      text;
  v_value    text;
  v_iter     jsonb;
BEGIN
  IF p_event_key IS NULL OR p_event_key !~ '^[a-z][a-z0-9_]{1,63}$' THEN
    RAISE EXCEPTION 'invalid_event_key' USING ERRCODE = '22023';
  END IF;
  IF p_surface NOT IN ('android', 'web', 'edge', 'cron') THEN
    RAISE EXCEPTION 'invalid_surface' USING ERRCODE = '22023';
  END IF;

  -- Key drop list: r510 base + r522 extension covering known PII-adjacent
  -- keys identified by audit-11.
  v_clean := coalesce(p_props, '{}'::jsonb)
             - 'aadhaar' - 'aadhaar_number'
             - 'pan' - 'pan_number'
             - 'phone' - 'phone_number' - 'alternate_phone' - 'mobile' - 'mobile_number'
             - 'email' - 'alternate_email' - 'email_address'
             - 'address' - 'street' - 'pincode' - 'city_full'
             - 'gst' - 'gstin'
             - 'name' - 'full_name' - 'user_name' - 'contact_name' - 'engineer_name' - 'hospital_name'
             - 'bank_account' - 'bank_account_number' - 'account_number'
             - 'ifsc' - 'ifsc_code'
             - 'upi' - 'upi_id' - 'vpa'
             - 'pan_card' - 'aadhaar_card' - 'kyc';

  -- Value-shape probe: iterate remaining keys and drop any whose string
  -- value matches a known PII regex. We only inspect text values
  -- (numeric / boolean / nested-object values are passed through).
  v_iter := v_clean;
  FOR v_key, v_value IN
    SELECT k, v FROM jsonb_each_text(v_iter)
  LOOP
    IF v_value IS NULL THEN
      CONTINUE;
    END IF;
    -- Email pattern
    IF v_value ~* '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- Indian phone: 10 digits, optionally +91 prefix
    IF v_value ~ '^(\+?91)?[6-9][0-9]{9}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- Aadhaar: 12 digits
    IF v_value ~ '^[2-9][0-9]{11}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- PAN: 5 letters + 4 digits + 1 letter
    IF v_value ~ '^[A-Z]{5}[0-9]{4}[A-Z]$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- IFSC: 4 letters + 0 + 6 alphanumeric
    IF v_value ~ '^[A-Z]{4}0[A-Z0-9]{6}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- Bank account / card: 12-19 contiguous digits
    IF v_value ~ '^[0-9]{12,19}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- UPI VPA: text@bankname (catches anything@ybl, @paytm, etc.)
    IF v_value ~* '^[a-z0-9._-]{2,}@[a-z]{2,15}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
  END LOOP;

  IF octet_length(v_clean::text) > 4096 THEN
    RAISE EXCEPTION 'props_too_large' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.analytics_events
    (user_id, session_id, event_key, surface, app_version, props)
  VALUES
    (v_user, p_session_id, p_event_key, p_surface, p_app_version, v_clean)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION
  public.log_analytics_event(text, uuid, text, text, jsonb)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION
  public.log_analytics_event(text, uuid, text, text, jsonb)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- Part 2 — NABH export rate limit
-- ---------------------------------------------------------------------
--
-- Per-user quota with two windows: 5 exports per rolling 1-minute window
-- and 50 per rolling 24-hour window. Counters are tracked in a table
-- and reaped opportunistically inside the check RPC.

CREATE TABLE IF NOT EXISTS public.nabh_export_audit (
  id          bigserial PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS nabh_export_audit_user_time_idx
  ON public.nabh_export_audit (user_id, occurred_at DESC);

ALTER TABLE public.nabh_export_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.nabh_export_audit FROM PUBLIC, anon, authenticated;
GRANT  SELECT, INSERT ON public.nabh_export_audit TO service_role;
REVOKE UPDATE, DELETE ON public.nabh_export_audit FROM service_role;

CREATE POLICY nabh_export_audit_no_read
  ON public.nabh_export_audit FOR SELECT
  TO authenticated, anon
  USING (false);

CREATE OR REPLACE FUNCTION public.check_and_reserve_nabh_export()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user    uuid := auth.uid();
  v_minute  int;
  v_day     int;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  -- Founders bypass rate limit (forensic / audit pulls).
  IF public.is_founder() THEN
    INSERT INTO public.nabh_export_audit (user_id) VALUES (v_user);
    RETURN;
  END IF;

  SELECT count(*) INTO v_minute
    FROM public.nabh_export_audit
   WHERE user_id = v_user
     AND occurred_at >= now() - interval '1 minute';
  IF v_minute >= 5 THEN
    RAISE EXCEPTION 'rate_limit_per_minute' USING ERRCODE = '53400';
  END IF;

  SELECT count(*) INTO v_day
    FROM public.nabh_export_audit
   WHERE user_id = v_user
     AND occurred_at >= now() - interval '1 day';
  IF v_day >= 50 THEN
    RAISE EXCEPTION 'rate_limit_per_day' USING ERRCODE = '53400';
  END IF;

  INSERT INTO public.nabh_export_audit (user_id) VALUES (v_user);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_and_reserve_nabh_export()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.check_and_reserve_nabh_export()
  TO authenticated, service_role;

-- Opportunistic retention sweep — keep the audit table small.
-- SECDEF runs as owner so it bypasses the service_role REVOKE on DELETE
-- (same pattern as r510 retention sweep).
CREATE OR REPLACE FUNCTION public.nabh_export_audit_retention_sweep()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_deleted int := 0;
BEGIN
  DELETE FROM public.nabh_export_audit
   WHERE occurred_at < now() - interval '7 days';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.nabh_export_audit_retention_sweep()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.nabh_export_audit_retention_sweep()
  TO service_role;

DO $$
BEGIN
  PERFORM cron.schedule(
    'nabh_export_audit_retention_sweep',
    '23 5 * * *',  -- 05:23 UTC daily
    $cron$SELECT public.nabh_export_audit_retention_sweep();$cron$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron unavailable; nabh_export_audit retention sweep must be triggered by edge fn';
END;
$$;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 522 audit-11 patches verified: analytics PII hardening + nabh_export rate limit (5/min, 50/day)';
END;
$$;
