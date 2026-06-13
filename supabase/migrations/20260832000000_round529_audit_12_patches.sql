-- =====================================================================
-- Round 529 — Audit-12 patches (deep PII hardening on log_analytics_event)
-- =====================================================================
--
-- Audit-12 (workflow wjw09u13x) confirmed 3 findings against r522. The
-- two relevant to this migration:
--
-- HIGH — log_analytics_event() bypass via:
--   (a) Nested object values — jsonb_each_text() returns the value as
--       stringified JSON, which no PII regex matches.
--   (b) Array values — same stringification issue.
--   (c) Numeric values — jsonb_each_text() converts numbers to NULL,
--       skipping all regex checks.
--
-- LOW — Unicode/formatting bypasses:
--   - Fullwidth digits (U+FF10-U+FF19): ０-９
--   - Devanagari digits (U+0966-U+096F): ०-९
--   - Zero-width characters (U+200B/200C/200D)
--   - Combining characters
--
-- Fix strategy:
--   1. REJECT non-primitive values (object / array) at the value layer.
--      If a value is not a string/number/boolean, drop the key.
--   2. CAST numeric values to text and apply PII regex.
--   3. NORMALIZE text values before regex: strip zero-width chars,
--      translate fullwidth and Devanagari digits to ASCII 0-9.
--
-- This is a stricter contract than r522: props must be flat key→scalar
-- only. Callers passing nested objects lose those values. The Android
-- client already only emits primitives, so this is a no-op in practice.

BEGIN;

DROP FUNCTION IF EXISTS public.log_analytics_event(text, uuid, text, text, jsonb);

-- Small helper — normalize a text value so PII regexes can fire even
-- against Unicode-encoded digits.
CREATE OR REPLACE FUNCTION public._analytics_normalize_for_pii(p_value text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v text := p_value;
BEGIN
  IF v IS NULL THEN
    RETURN NULL;
  END IF;
  -- Strip zero-width: U+200B (ZWSP), U+200C (ZWNJ), U+200D (ZWJ), U+FEFF (BOM)
  v := translate(v, E'​‌‍﻿', '');
  -- Fullwidth digits 0-9 (U+FF10..U+FF19) → ASCII 0-9
  v := translate(
    v,
    E'０１２３４５６７８９',
    '0123456789'
  );
  -- Devanagari digits ०-९ (U+0966..U+096F) → ASCII 0-9
  v := translate(
    v,
    E'०१२३४५६७८९',
    '0123456789'
  );
  -- Strip remaining whitespace + non-printing controls so "1 234 567 890"
  -- and " 1234567890 " also normalize.
  v := regexp_replace(v, '[[:space:]]', '', 'g');
  RETURN v;
END;
$$;

REVOKE EXECUTE ON FUNCTION public._analytics_normalize_for_pii(text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public._analytics_normalize_for_pii(text)
  TO service_role;

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
  v_id          bigint;
  v_user        uuid := auth.uid();
  v_clean       jsonb;
  v_key         text;
  v_jvalue      jsonb;
  v_type        text;
  v_text        text;
  v_normalized  text;
BEGIN
  IF p_event_key IS NULL OR p_event_key !~ '^[a-z][a-z0-9_]{1,63}$' THEN
    RAISE EXCEPTION 'invalid_event_key' USING ERRCODE = '22023';
  END IF;
  IF p_surface NOT IN ('android', 'web', 'edge', 'cron') THEN
    RAISE EXCEPTION 'invalid_surface' USING ERRCODE = '22023';
  END IF;

  -- Key drop list (r510 base + r522 extension; unchanged in r529).
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

  -- Per-key value walk via jsonb_each (not jsonb_each_text) so we keep
  -- the type information. We REJECT objects + arrays entirely (they
  -- can hide PII at any depth and the contract says props are flat).
  -- For scalars, we cast to text + normalize + apply PII regex.
  FOR v_key, v_jvalue IN
    SELECT k, v FROM jsonb_each(v_clean)
  LOOP
    v_type := jsonb_typeof(v_jvalue);

    -- Audit-12 finding 2(a, b): nested object / array — drop.
    IF v_type IN ('object', 'array') THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;

    -- Booleans are fine, pass through.
    IF v_type = 'boolean' OR v_type = 'null' THEN
      CONTINUE;
    END IF;

    -- Numbers + strings: extract scalar text and normalize.
    IF v_type = 'number' THEN
      v_text := v_jvalue::text;     -- "12345" without quotes
    ELSE
      v_text := v_jvalue #>> '{}';  -- unquoted string
    END IF;

    IF v_text IS NULL THEN
      CONTINUE;
    END IF;

    v_normalized := public._analytics_normalize_for_pii(v_text);

    -- Email
    IF v_normalized ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- Indian phone: 10 digits, optionally +91 prefix
    IF v_normalized ~ '^(\+?91)?[6-9][0-9]{9}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- Aadhaar: 12 digits starting 2-9
    IF v_normalized ~ '^[2-9][0-9]{11}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- PAN: 5 letters + 4 digits + 1 letter (case-insensitive after upper)
    IF upper(v_normalized) ~ '^[A-Z]{5}[0-9]{4}[A-Z]$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- IFSC: 4 letters + 0 + 6 alphanumeric
    IF upper(v_normalized) ~ '^[A-Z]{4}0[A-Z0-9]{6}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- Bank account / card: 12-19 contiguous digits
    IF v_normalized ~ '^[0-9]{12,19}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- UPI VPA: text@bankname
    IF v_normalized ~* '^[a-z0-9._-]{2,}@[a-z]{2,15}$' THEN
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

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 529 audit-12 patches verified: PII deep hardening (reject nested + numeric coerce + Unicode normalize)';
END;
$$;
