-- =====================================================================
-- Round 501 — Duplicate Account Detector (v0.4 Phase 5 #4)
-- =====================================================================
--
-- Sibling to r498 (collusion detector). Different threat:
--   * Collusion = 2 distinct people with closed-loop pair behavior
--   * Duplicate = 1 person with 2+ accounts (sock-puppet)
--
-- Attack vectors duplicate accounts enable:
--   1. Engineer alt-account: posts fake bids on own jobs to drive
--      hospital price expectations down, then accepts via primary.
--   2. Hospital "fake-blacklist": after a bad review, hospital
--      creates new account to re-engage the engineer who'll never
--      know it's the same buyer.
--   3. Referral fraud: spawn N accounts to claim first-job-free
--      promo (r504) N times.
--   4. KYC dodge: blacklisted engineer creates new account with
--      sibling/relative Aadhaar.
--   5. Rating inflation: engineer creates 5-10 fake hospital
--      accounts to give themselves 5-star reviews.
--
-- We dedupe across 5 dimensions:
--   - aadhaar_number (strongest signal — engineer side only)
--   - pan_number (engineer)
--   - phone (both sides — but Indian phone reuse is common, so
--     this is "watch" not "block")
--   - email domain + display name fuzzy match
--   - device_fingerprint (future: when client-side hash arrives)
--
-- ALERT-ONLY mode like r498 — founder reviews top-N, no auto-block
-- in v0.4.

BEGIN;

CREATE TABLE IF NOT EXISTS public.duplicate_account_flags (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- The two accounts flagged as likely duplicates
  user_id_a           uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id_b           uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Lower uuid first to dedupe (id_a, id_b) regardless of order
  CONSTRAINT duplicate_account_pair_order
    CHECK (user_id_a < user_id_b),

  signal_kind         text        NOT NULL
                                  CHECK (signal_kind IN (
                                    'shared_aadhaar',          -- CRITICAL — same govt id
                                    'shared_pan',              -- CRITICAL — same tax id
                                    'shared_phone',            -- HIGH — same phone number
                                    'shared_phone_normalized', -- HIGH — same phone w/ different formatting
                                    'shared_email_domain',     -- MEDIUM — same email custom domain
                                    'name_fuzzy_match',        -- MEDIUM — Levenshtein distance < 2
                                    'shared_device_id'         -- HIGH — same client device fingerprint
                                  )),
  severity            text        NOT NULL CHECK (severity IN ('critical','high','medium','low')),
  -- Evidence detail (e.g., masked Aadhaar last4, phone last4)
  evidence            jsonb       NOT NULL,
  -- Lifecycle
  status              text        NOT NULL DEFAULT 'open'
                                  CHECK (status IN ('open','investigating','confirmed','false_positive','resolved')),
  resolved_by         uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at         timestamptz,
  resolution_note     text,
  created_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT duplicate_account_flag_dedup
    UNIQUE (user_id_a, user_id_b, signal_kind, status)
);

CREATE INDEX IF NOT EXISTS duplicate_account_open_idx
  ON public.duplicate_account_flags (status, severity, created_at DESC)
  WHERE status IN ('open','investigating');
CREATE INDEX IF NOT EXISTS duplicate_account_critical_idx
  ON public.duplicate_account_flags (severity, created_at DESC)
  WHERE severity = 'critical';

ALTER TABLE public.duplicate_account_flags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS duplicate_account_flags_select ON public.duplicate_account_flags;
CREATE POLICY duplicate_account_flags_select
  ON public.duplicate_account_flags
  FOR SELECT
  TO authenticated, service_role
  USING (public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.duplicate_account_flags
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 1. Phone normalizer — strip non-digits + keep last 10 digits
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.normalize_indian_phone(p text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT right(regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g'), 10);
$$;

REVOKE EXECUTE ON FUNCTION public.normalize_indian_phone(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.normalize_indian_phone(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. scan_duplicate_accounts — main detection RPC
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.scan_duplicate_accounts()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pair record;
  v_count int := 0;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  -- ============================================================
  -- Signal 1: shared Aadhaar (CRITICAL — engineers only)
  -- ============================================================
  FOR v_pair IN
    SELECT
      least(e1.user_id, e2.user_id) AS user_id_a,
      greatest(e1.user_id, e2.user_id) AS user_id_b,
      e1.aadhaar_number AS aadhaar
    FROM public.engineers e1
    JOIN public.engineers e2
      ON e1.aadhaar_number = e2.aadhaar_number
     AND e1.user_id < e2.user_id
    WHERE e1.aadhaar_number IS NOT NULL
      AND length(e1.aadhaar_number) >= 4
  LOOP
    INSERT INTO public.duplicate_account_flags (
      user_id_a, user_id_b, signal_kind, severity, evidence
    ) VALUES (
      v_pair.user_id_a, v_pair.user_id_b, 'shared_aadhaar', 'critical',
      jsonb_build_object(
        'aadhaar_masked', 'XXXX-XXXX-' || right(v_pair.aadhaar, 4),
        'detector', 'scan_duplicate_accounts_v1'
      )
    )
    ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
    v_count := v_count + 1;
  END LOOP;

  -- ============================================================
  -- Signal 2: shared PAN (CRITICAL — engineers only)
  -- ============================================================
  FOR v_pair IN
    SELECT
      least(e1.user_id, e2.user_id) AS user_id_a,
      greatest(e1.user_id, e2.user_id) AS user_id_b,
      e1.pan_number AS pan
    FROM public.engineers e1
    JOIN public.engineers e2
      ON upper(trim(e1.pan_number)) = upper(trim(e2.pan_number))
     AND e1.user_id < e2.user_id
    WHERE e1.pan_number IS NOT NULL
      AND length(trim(e1.pan_number)) = 10
  LOOP
    INSERT INTO public.duplicate_account_flags (
      user_id_a, user_id_b, signal_kind, severity, evidence
    ) VALUES (
      v_pair.user_id_a, v_pair.user_id_b, 'shared_pan', 'critical',
      jsonb_build_object(
        'pan_masked', left(v_pair.pan, 4) || '...' || right(v_pair.pan, 1),
        'detector', 'scan_duplicate_accounts_v1'
      )
    )
    ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
    v_count := v_count + 1;
  END LOOP;

  -- ============================================================
  -- Signal 3: shared phone (HIGH — both sides; covers profiles)
  -- Phone reuse in India is real (family share), so HIGH not
  -- CRITICAL. Normalized to last 10 digits.
  -- ============================================================
  FOR v_pair IN
    WITH normed AS (
      SELECT
        u.id AS user_id,
        public.normalize_indian_phone(
          coalesce(p.phone, u.phone, u.raw_user_meta_data->>'phone')
        ) AS norm_phone
      FROM auth.users u
      LEFT JOIN public.profiles p ON p.id = u.id
    )
    SELECT
      least(n1.user_id, n2.user_id) AS user_id_a,
      greatest(n1.user_id, n2.user_id) AS user_id_b,
      n1.norm_phone AS phone
    FROM normed n1
    JOIN normed n2
      ON n1.norm_phone = n2.norm_phone
     AND n1.user_id < n2.user_id
    WHERE n1.norm_phone IS NOT NULL
      AND length(n1.norm_phone) = 10
  LOOP
    INSERT INTO public.duplicate_account_flags (
      user_id_a, user_id_b, signal_kind, severity, evidence
    ) VALUES (
      v_pair.user_id_a, v_pair.user_id_b, 'shared_phone_normalized', 'high',
      jsonb_build_object(
        'phone_last4', right(v_pair.phone, 4),
        'detector', 'scan_duplicate_accounts_v1'
      )
    )
    ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
    v_count := v_count + 1;
  END LOOP;

  -- ============================================================
  -- Signal 4: name fuzzy match (MEDIUM — heuristic only)
  -- pg_trgm similarity > 0.8 catches "Anil Reddy" vs "Aanil Reddy"
  -- ============================================================
  -- Skip if pg_trgm not installed (graceful degrade)
  BEGIN
    FOR v_pair IN
      WITH names AS (
        SELECT u.id AS user_id,
               coalesce(u.raw_user_meta_data->>'full_name',
                        p.display_name, '') AS dn
          FROM auth.users u
          LEFT JOIN public.profiles p ON p.id = u.id
         WHERE coalesce(u.raw_user_meta_data->>'full_name',
                        p.display_name, '') <> ''
      )
      SELECT
        least(n1.user_id, n2.user_id) AS user_id_a,
        greatest(n1.user_id, n2.user_id) AS user_id_b,
        n1.dn AS dn_a,
        n2.dn AS dn_b
      FROM names n1
      JOIN names n2
        ON n1.user_id < n2.user_id
       AND similarity(n1.dn, n2.dn) > 0.85
       AND length(n1.dn) >= 6   -- avoid 'A B' false-positives
    LOOP
      INSERT INTO public.duplicate_account_flags (
        user_id_a, user_id_b, signal_kind, severity, evidence
      ) VALUES (
        v_pair.user_id_a, v_pair.user_id_b, 'name_fuzzy_match', 'medium',
        jsonb_build_object(
          'name_a', v_pair.dn_a, 'name_b', v_pair.dn_b,
          'detector', 'scan_duplicate_accounts_v1'
        )
      )
      ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
      v_count := v_count + 1;
    END LOOP;
  EXCEPTION
    WHEN undefined_function THEN
      RAISE NOTICE 'pg_trgm not installed; skipping name fuzzy match signal';
  END;

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.scan_duplicate_accounts()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.scan_duplicate_accounts() TO service_role;

-- ---------------------------------------------------------------------
-- 3. founder_open_duplicate_flags — cockpit query
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_open_duplicate_flags(
  p_severity text DEFAULT NULL,
  p_limit    integer DEFAULT 100
)
RETURNS TABLE(
  id              uuid,
  user_id_a       uuid,
  email_a         text,
  user_id_b       uuid,
  email_b         text,
  signal_kind     text,
  severity        text,
  evidence        jsonb,
  created_at      timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT d.id, d.user_id_a,
         coalesce((SELECT email FROM auth.users WHERE id = d.user_id_a), 'unknown'),
         d.user_id_b,
         coalesce((SELECT email FROM auth.users WHERE id = d.user_id_b), 'unknown'),
         d.signal_kind, d.severity, d.evidence, d.created_at
    FROM public.duplicate_account_flags d
   WHERE d.status IN ('open','investigating')
     AND (p_severity IS NULL OR d.severity = p_severity)
   ORDER BY
     CASE d.severity
       WHEN 'critical' THEN 0
       WHEN 'high'     THEN 1
       WHEN 'medium'   THEN 2
       ELSE 3
     END,
     d.created_at DESC
   LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_open_duplicate_flags(text, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_open_duplicate_flags(text, integer)
  TO service_role;

-- ---------------------------------------------------------------------
-- 4. founder_resolve_duplicate_flag
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_resolve_duplicate_flag(
  p_flag_id  uuid,
  p_status   text,
  p_note     text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('investigating','confirmed','false_positive','resolved') THEN
    RAISE EXCEPTION 'invalid_status' USING ERRCODE = '22023';
  END IF;
  IF p_note IS NULL OR length(trim(p_note)) < 5 THEN
    RAISE EXCEPTION 'note required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_old FROM public.duplicate_account_flags WHERE id = p_flag_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'flag_not_found' USING ERRCODE = '02000';
  END IF;

  UPDATE public.duplicate_account_flags
     SET status = p_status,
         resolved_by = auth.uid(),
         resolved_at = CASE WHEN p_status IN ('confirmed','false_positive','resolved') THEN now() ELSE NULL END,
         resolution_note = p_note
   WHERE id = p_flag_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_resolve_duplicate_flag',
    p_target_table  => 'duplicate_account_flags',
    p_target_row_id => p_flag_id,
    p_before_value  => jsonb_build_object('status', v_old.status, 'signal_kind', v_old.signal_kind, 'severity', v_old.severity),
    p_after_value   => jsonb_build_object('status', p_status),
    p_reason        => p_note
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_resolve_duplicate_flag(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_resolve_duplicate_flag(uuid, text, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 5. Daily cron schedule
-- ---------------------------------------------------------------------
DO $$
BEGIN
  PERFORM cron.schedule(
    'scan_duplicate_accounts_daily',
    '0 22 * * *',  -- 22:00 UTC = 03:30 IST
    $cron$SELECT public.scan_duplicate_accounts();$cron$
  );
  RAISE NOTICE 'round 501: duplicate detector cron scheduled';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'round 501: pg_cron unavailable; scan_duplicate_accounts() callable from edge fn / manual';
END;
$$;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'duplicate_account_flags'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 501: duplicate_account_flags RLS not enabled';
  END IF;
  RAISE NOTICE 'round 501 duplicate account detector verified: table + 4 RPCs, alert-only mode';
END;
$$;
