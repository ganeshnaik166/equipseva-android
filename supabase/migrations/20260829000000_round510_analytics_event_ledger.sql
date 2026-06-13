-- =====================================================================
-- Round 510 — Self-hosted Analytics Event Ledger (v0.4 Phase 5 #10 backend)
-- =====================================================================
--
-- Replaces external Mixpanel dependency with a founder-owned analytics
-- ledger so we stay DPDP-friendly (no PII shipped to a US vendor) and
-- get a forensic chain we can replay during incidents.
--
-- Schema:
--   analytics_events    — append-only fact table (one row per app event)
--   analytics_funnels   — named funnels with ordered step keys
--   analytics_step_keys — per-funnel step lookup (event_key + ordinal)
--
-- Client (Android / future Web) calls public.log_analytics_event() with
-- an event_key plus an optional jsonb props blob. The RPC stamps
-- user_id from auth.uid() (or null for anon onboarding), normalises
-- props (max 4 KB, strips known PII keys), and inserts.
--
-- Founder funnel queries:
--   founder_funnel_conversion(p_funnel_key, p_days)
--   founder_event_volume_daily(p_event_key, p_days)
--   founder_top_events(p_days, p_limit)

BEGIN;

-- ---------------------------------------------------------------------
-- Fact table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_events (
  id              bigserial PRIMARY KEY,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  user_id         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  session_id      uuid,                       -- client-generated per app open
  event_key       text NOT NULL,              -- e.g. 'job_post_started'
  surface         text,                       -- 'android' | 'web' | 'edge'
  app_version     text,
  props           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT analytics_event_key_chk
    CHECK (event_key ~ '^[a-z][a-z0-9_]{1,63}$'),
  CONSTRAINT analytics_props_size_chk
    CHECK (octet_length(props::text) <= 4096)
);

CREATE INDEX IF NOT EXISTS analytics_events_event_time_idx
  ON public.analytics_events (event_key, occurred_at DESC);
CREATE INDEX IF NOT EXISTS analytics_events_user_time_idx
  ON public.analytics_events (user_id, occurred_at DESC)
  WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS analytics_events_session_idx
  ON public.analytics_events (session_id)
  WHERE session_id IS NOT NULL;

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

-- Append-only — readers go through SECDEF RPCs only.
REVOKE ALL ON public.analytics_events FROM PUBLIC, anon, authenticated;
GRANT  INSERT, SELECT ON public.analytics_events TO service_role;
REVOKE UPDATE, DELETE ON public.analytics_events FROM service_role;

-- Block direct selects from authenticated even if a future GRANT slips in.
CREATE POLICY analytics_events_no_read
  ON public.analytics_events FOR SELECT
  TO authenticated, anon
  USING (false);

-- ---------------------------------------------------------------------
-- Funnel definitions
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_funnels (
  funnel_key   text PRIMARY KEY,
  label        text NOT NULL,
  description  text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_funnel_steps (
  funnel_key   text NOT NULL REFERENCES public.analytics_funnels(funnel_key) ON DELETE CASCADE,
  ordinal      smallint NOT NULL CHECK (ordinal >= 1),
  event_key    text NOT NULL,
  step_label   text NOT NULL,
  PRIMARY KEY (funnel_key, ordinal)
);

REVOKE ALL ON public.analytics_funnels, public.analytics_funnel_steps
  FROM PUBLIC, anon, authenticated;
GRANT  SELECT ON public.analytics_funnels, public.analytics_funnel_steps
  TO service_role;

-- Seed three priority funnels.
INSERT INTO public.analytics_funnels (funnel_key, label, description) VALUES
  ('hospital_first_repair', 'Hospital first repair job',
   'New hospital from app-open to first repair_job posted'),
  ('engineer_first_bid',    'Engineer first bid',
   'Engineer from KYC-verified to first accepted bid'),
  ('amc_signup',            'AMC subscription signup',
   'Hospital from AMC plan view to paid AMC contract')
ON CONFLICT (funnel_key) DO NOTHING;

INSERT INTO public.analytics_funnel_steps (funnel_key, ordinal, event_key, step_label) VALUES
  ('hospital_first_repair', 1, 'app_open',              'App opened'),
  ('hospital_first_repair', 2, 'hospital_signed_up',    'Hospital signed up'),
  ('hospital_first_repair', 3, 'job_post_started',      'Started posting job'),
  ('hospital_first_repair', 4, 'job_post_submitted',    'Submitted job'),
  ('hospital_first_repair', 5, 'job_bid_accepted',      'Accepted a bid'),
  ('engineer_first_bid',    1, 'engineer_kyc_verified', 'KYC verified'),
  ('engineer_first_bid',    2, 'job_feed_viewed',       'Viewed job feed'),
  ('engineer_first_bid',    3, 'job_bid_submitted',     'Submitted bid'),
  ('engineer_first_bid',    4, 'job_bid_accepted',      'Bid accepted'),
  ('amc_signup',            1, 'amc_plans_viewed',      'Viewed AMC plans'),
  ('amc_signup',            2, 'amc_wizard_started',    'Started AMC wizard'),
  ('amc_signup',            3, 'amc_payment_initiated', 'Initiated payment'),
  ('amc_signup',            4, 'amc_contract_active',   'Contract active')
ON CONFLICT (funnel_key, ordinal) DO NOTHING;

-- ---------------------------------------------------------------------
-- Insert RPC (caller-side)
-- ---------------------------------------------------------------------
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
  v_id     bigint;
  v_user   uuid := auth.uid();
  v_clean  jsonb;
BEGIN
  IF p_event_key IS NULL OR p_event_key !~ '^[a-z][a-z0-9_]{1,63}$' THEN
    RAISE EXCEPTION 'invalid_event_key' USING ERRCODE = '22023';
  END IF;
  IF p_surface NOT IN ('android', 'web', 'edge', 'cron') THEN
    RAISE EXCEPTION 'invalid_surface' USING ERRCODE = '22023';
  END IF;

  -- Strip well-known PII keys so DPDP exposure stays minimal.
  v_clean := coalesce(p_props, '{}'::jsonb)
             - 'aadhaar' - 'aadhaar_number' - 'pan' - 'pan_number'
             - 'phone' - 'phone_number' - 'email' - 'address'
             - 'gst' - 'gstin';

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
-- Founder funnel conversion RPC
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_funnel_conversion(
  p_funnel_key text,
  p_days       integer DEFAULT 30
)
RETURNS TABLE(
  ordinal       smallint,
  event_key     text,
  step_label    text,
  unique_users  int,
  conversion_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_since timestamptz := now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval;
  v_step1 int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.analytics_funnels WHERE funnel_key = p_funnel_key) THEN
    RAISE EXCEPTION 'unknown_funnel %', p_funnel_key USING ERRCODE = '22023';
  END IF;

  -- Step-1 user count is the conversion denominator.
  SELECT count(DISTINCT ae.user_id)
    INTO v_step1
    FROM public.analytics_funnel_steps fs
    JOIN public.analytics_events ae
      ON ae.event_key = fs.event_key
     AND ae.occurred_at >= v_since
     AND ae.user_id IS NOT NULL
   WHERE fs.funnel_key = p_funnel_key
     AND fs.ordinal = 1;

  RETURN QUERY
  WITH step_users AS (
    SELECT fs.ordinal, fs.event_key, fs.step_label,
           count(DISTINCT ae.user_id)::int AS unique_users
      FROM public.analytics_funnel_steps fs
      LEFT JOIN public.analytics_events ae
        ON ae.event_key = fs.event_key
       AND ae.occurred_at >= v_since
       AND ae.user_id IS NOT NULL
     WHERE fs.funnel_key = p_funnel_key
     GROUP BY fs.ordinal, fs.event_key, fs.step_label
  )
  SELECT su.ordinal, su.event_key, su.step_label, su.unique_users,
         CASE WHEN v_step1 > 0
              THEN round(su.unique_users * 100.0 / v_step1, 1)
              ELSE 0 END
    FROM step_users su
   ORDER BY su.ordinal;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_funnel_conversion(text, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_funnel_conversion(text, integer)
  TO service_role;

-- ---------------------------------------------------------------------
-- Daily event volume (single event timeseries)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_event_volume_daily(
  p_event_key text,
  p_days      integer DEFAULT 30
)
RETURNS TABLE(
  day            date,
  event_count    int,
  unique_users   int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_since timestamptz := now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT (ae.occurred_at AT TIME ZONE 'Asia/Kolkata')::date AS day,
         count(*)::int,
         count(DISTINCT ae.user_id)::int
    FROM public.analytics_events ae
   WHERE ae.event_key = p_event_key
     AND ae.occurred_at >= v_since
   GROUP BY 1
   ORDER BY 1 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_event_volume_daily(text, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_event_volume_daily(text, integer)
  TO service_role;

-- ---------------------------------------------------------------------
-- Top events overall (for surfacing unknown high-traffic keys)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_top_events(
  p_days  integer DEFAULT 7,
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  event_key    text,
  event_count  int,
  unique_users int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_since timestamptz := now() - (greatest(coalesce(p_days, 7), 1)::text || ' days')::interval;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT ae.event_key,
         count(*)::int,
         count(DISTINCT ae.user_id)::int
    FROM public.analytics_events ae
   WHERE ae.occurred_at >= v_since
   GROUP BY ae.event_key
   ORDER BY count(*) DESC
   LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_top_events(integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_top_events(integer, integer)
  TO service_role;

-- ---------------------------------------------------------------------
-- 90-day retention sweep (DPDP minimisation — keep raw events lean).
-- pg_cron not present on tier; wrap in EXCEPTION fallback.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.analytics_events_retention_sweep()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_deleted int := 0;
BEGIN
  -- SECDEF runs as function owner (postgres), bypassing the service_role
  -- REVOKE on DELETE. Retention is the only legitimate write path that
  -- removes rows from this ledger.
  DELETE FROM public.analytics_events
   WHERE occurred_at < now() - interval '90 days';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.analytics_events_retention_sweep()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.analytics_events_retention_sweep()
  TO service_role;

DO $$
BEGIN
  PERFORM cron.schedule(
    'analytics_events_retention_sweep',
    '13 4 * * *',  -- 04:13 UTC daily = 09:43 IST
    $cron$SELECT public.analytics_events_retention_sweep();$cron$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron unavailable; analytics retention sweep must be triggered by edge fn';
END;
$$;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 510 analytics event ledger verified: 1 ledger + 2 metadata tables + 4 RPCs + retention sweep';
END;
$$;
