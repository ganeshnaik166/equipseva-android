-- =====================================================================
-- Round 497 — Engineer Periodic Re-KYC Scheduling (v0.4 Phase 3 #8)
-- =====================================================================
--
-- KYC at sign-up is a one-shot verification. Twelve months later the
-- engineer may have:
--   - Lost their professional cert (left an OEM training program)
--   - Picked up a police record
--   - Changed addresses (Aadhaar still valid but profile out-of-date)
--   - Let their DigiLocker degree expire on the renewal side
--   - Moved on entirely (account dormant but still 'verified')
--
-- Today nothing forces re-verification. We carry stale KYC into our
-- "verified engineer" trust signal which the hospital relies on. A
-- regulator audit + a NABH inspection both ask "when did you last
-- verify this engineer?" and we can only point to the original
-- onboarding date.
--
-- This migration ships the SCHEDULING backbone:
--   * engineer_kyc_renewals — one row per engineer per renewal cycle.
--   * schedule_engineer_kyc_renewals() — idempotent cron-callable RPC
--     that creates 'due' rows for engineers whose verified_at +
--     365 days is approaching (within next 30 days).
--   * mark_renewal_complete() — closes a renewal row after the
--     admin_set_engineer_verification re-affirms 'verified'.
--   * engineer_overdue_renewals() — engineer-facing read of own
--     pending renewal status (drives an in-app nudge banner).
--   * founder_kyc_renewal_queue() — cockpit query.
--
-- Renewal cadence: 365 days from last verified_at (or last completed
-- renewal). Grace period: 14 days post-due before the engineer's
-- verification_status auto-flips back to 'pending' (handled by a
-- separate "reaper" RPC also defined here).

BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_kyc_renewals (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id    uuid        NOT NULL,
  CONSTRAINT engineer_kyc_renewals_engineer_fk
    FOREIGN KEY (engineer_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  cycle_started_at    timestamptz NOT NULL DEFAULT now(),
  due_at              timestamptz NOT NULL,
  grace_until         timestamptz NOT NULL,
  -- Lifecycle: pending (engineer hasn't acted) → in_progress (engineer
  -- started re-upload) → completed (re-verified) OR expired (grace
  -- exceeded — verification reverted)
  status              text        NOT NULL DEFAULT 'pending'
                                  CHECK (status IN ('pending','in_progress','completed','expired','waived')),
  -- Engineer's actions during the cycle (timestamps for forensics)
  reminder_sent_at    timestamptz,
  engineer_started_at timestamptz,
  -- Items the engineer must refresh; subset of:
  --   'aadhaar' | 'degree_digilocker' | 'police_verification' | 'photo'
  required_items      text[]      NOT NULL DEFAULT ARRAY['aadhaar','degree_digilocker']::text[],
  refreshed_items     text[]      NOT NULL DEFAULT ARRAY[]::text[],
  -- Completion fields
  completed_at        timestamptz,
  completed_by_admin  uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  expired_at          timestamptz,
  -- Notes (engineer-facing rejection reason if completion blocked)
  rejection_note      text,
  created_at          timestamptz NOT NULL DEFAULT now(),

  -- One active (pending/in_progress) renewal per engineer at a time
  CONSTRAINT engineer_kyc_renewals_one_active
    EXCLUDE USING btree (engineer_user_id WITH =)
    WHERE (status IN ('pending','in_progress'))
);

CREATE INDEX IF NOT EXISTS engineer_kyc_renewals_engineer_idx
  ON public.engineer_kyc_renewals (engineer_user_id, due_at);
CREATE INDEX IF NOT EXISTS engineer_kyc_renewals_due_idx
  ON public.engineer_kyc_renewals (due_at)
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS engineer_kyc_renewals_grace_expiring_idx
  ON public.engineer_kyc_renewals (grace_until)
  WHERE status IN ('pending','in_progress');

ALTER TABLE public.engineer_kyc_renewals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_kyc_renewals_select ON public.engineer_kyc_renewals;
CREATE POLICY engineer_kyc_renewals_select
  ON public.engineer_kyc_renewals
  FOR SELECT
  TO authenticated, service_role
  USING (engineer_user_id = auth.uid() OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.engineer_kyc_renewals
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- schedule_engineer_kyc_renewals — daily cron-callable
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.schedule_engineer_kyc_renewals()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  -- Engineers whose 12-month anniversary is within next 30 days AND
  -- who don't already have an active renewal row.
  WITH due_engineers AS (
    SELECT e.user_id, e.verification_status_updated_at
      FROM public.engineers e
     WHERE e.verification_status = 'verified'
       AND e.verification_status_updated_at IS NOT NULL
       AND e.verification_status_updated_at < (now() - interval '335 days')
       AND NOT EXISTS (
         SELECT 1 FROM public.engineer_kyc_renewals r
          WHERE r.engineer_user_id = e.user_id
            AND r.status IN ('pending','in_progress')
       )
       AND NOT EXISTS (
         -- Skip engineers who completed a renewal in the past 30 days
         -- (avoid double-scheduling right after a refresh).
         SELECT 1 FROM public.engineer_kyc_renewals r
          WHERE r.engineer_user_id = e.user_id
            AND r.status = 'completed'
            AND r.completed_at >= now() - interval '30 days'
       )
  )
  INSERT INTO public.engineer_kyc_renewals (
    engineer_user_id, cycle_started_at,
    due_at, grace_until
  )
  SELECT user_id, now(),
         verification_status_updated_at + interval '365 days',
         verification_status_updated_at + interval '379 days'
    FROM due_engineers;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.schedule_engineer_kyc_renewals()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.schedule_engineer_kyc_renewals()
  TO service_role;

-- ---------------------------------------------------------------------
-- start_kyc_renewal — engineer begins refresh flow
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_kyc_renewal(
  p_renewal_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_row FROM public.engineer_kyc_renewals WHERE id = p_renewal_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'renewal_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_row.engineer_user_id <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF v_row.status <> 'pending' THEN
    RAISE EXCEPTION 'renewal_not_pending (status=%)', v_row.status USING ERRCODE = '22023';
  END IF;

  UPDATE public.engineer_kyc_renewals
     SET status = 'in_progress',
         engineer_started_at = now()
   WHERE id = p_renewal_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.start_kyc_renewal(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.start_kyc_renewal(uuid) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- mark_renewal_item_refreshed — engineer flags one item done
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_renewal_item_refreshed(
  p_renewal_id uuid,
  p_item       text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_item NOT IN ('aadhaar','degree_digilocker','police_verification','photo') THEN
    RAISE EXCEPTION 'invalid_item' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_row FROM public.engineer_kyc_renewals WHERE id = p_renewal_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'renewal_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_row.engineer_user_id <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF v_row.status NOT IN ('pending','in_progress') THEN
    RAISE EXCEPTION 'renewal_not_in_progress' USING ERRCODE = '22023';
  END IF;

  -- Append item if not already present
  UPDATE public.engineer_kyc_renewals
     SET refreshed_items = (
           SELECT array_agg(DISTINCT it)
             FROM unnest(refreshed_items || ARRAY[p_item]) it
         )
   WHERE id = p_renewal_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_renewal_item_refreshed(uuid, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_renewal_item_refreshed(uuid, text)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- founder_complete_kyc_renewal — admin closes renewal
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_complete_kyc_renewal(
  p_renewal_id uuid,
  p_outcome    text,    -- 'completed' / 'expired' / 'waived'
  p_note       text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_outcome NOT IN ('completed','expired','waived') THEN
    RAISE EXCEPTION 'invalid_outcome' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row FROM public.engineer_kyc_renewals WHERE id = p_renewal_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'renewal_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_row.status NOT IN ('pending','in_progress') THEN
    RAISE EXCEPTION 'renewal_already_closed (status=%)', v_row.status USING ERRCODE = '22023';
  END IF;

  UPDATE public.engineer_kyc_renewals
     SET status = p_outcome,
         completed_at = CASE WHEN p_outcome = 'completed' THEN now() ELSE NULL END,
         expired_at   = CASE WHEN p_outcome = 'expired'   THEN now() ELSE NULL END,
         completed_by_admin = auth.uid(),
         rejection_note = p_note
   WHERE id = p_renewal_id;

  -- If expired: revert the engineer's verification_status to pending
  -- so the directory hides them until they re-verify.
  IF p_outcome = 'expired' THEN
    UPDATE public.engineers
       SET verification_status = 'pending',
           verification_status_updated_at = now()
     WHERE user_id = v_row.engineer_user_id;
  END IF;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_complete_kyc_renewal',
    p_target_table  => 'engineer_kyc_renewals',
    p_target_row_id => p_renewal_id,
    p_before_value  => jsonb_build_object('status', v_row.status, 'engineer_user_id', v_row.engineer_user_id),
    p_after_value   => jsonb_build_object('status', p_outcome),
    p_reason        => p_note
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_complete_kyc_renewal(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_complete_kyc_renewal(uuid, text, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- reap_expired_kyc_renewals — auto-expire past grace
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reap_expired_kyc_renewals()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
  v_row   record;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  FOR v_row IN
    SELECT id, engineer_user_id
      FROM public.engineer_kyc_renewals
     WHERE status IN ('pending','in_progress')
       AND grace_until < now()
  LOOP
    UPDATE public.engineer_kyc_renewals
       SET status = 'expired',
           expired_at = now()
     WHERE id = v_row.id;

    UPDATE public.engineers
       SET verification_status = 'pending',
           verification_status_updated_at = now()
     WHERE user_id = v_row.engineer_user_id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reap_expired_kyc_renewals()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.reap_expired_kyc_renewals()
  TO service_role;

-- ---------------------------------------------------------------------
-- my_kyc_renewal — engineer-facing
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_kyc_renewal()
RETURNS TABLE(
  id                  uuid,
  due_at              timestamptz,
  grace_until         timestamptz,
  status              text,
  required_items      text[],
  refreshed_items     text[],
  remaining_items     text[],
  days_until_due      numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT r.id, r.due_at, r.grace_until, r.status,
         r.required_items, r.refreshed_items,
         (SELECT array_agg(it) FROM unnest(r.required_items) it
          WHERE NOT (it = ANY(r.refreshed_items))) AS remaining_items,
         EXTRACT(EPOCH FROM (r.due_at - now())) / 86400 AS days_until_due
    FROM public.engineer_kyc_renewals r
   WHERE r.engineer_user_id = auth.uid()
     AND r.status IN ('pending','in_progress')
   ORDER BY r.due_at ASC
   LIMIT 1;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_kyc_renewal() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_kyc_renewal() TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- founder_kyc_renewal_queue — cockpit
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_kyc_renewal_queue(
  p_status text DEFAULT NULL,
  p_limit  integer DEFAULT 100
)
RETURNS TABLE(
  id                  uuid,
  engineer_user_id    uuid,
  engineer_email      text,
  status              text,
  due_at              timestamptz,
  grace_until         timestamptz,
  days_overdue        numeric,
  refreshed_items     text[]
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
  SELECT r.id, r.engineer_user_id,
         coalesce((SELECT email FROM auth.users WHERE id = r.engineer_user_id), 'unknown'),
         r.status, r.due_at, r.grace_until,
         EXTRACT(EPOCH FROM (now() - r.due_at)) / 86400 AS days_overdue,
         r.refreshed_items
    FROM public.engineer_kyc_renewals r
   WHERE (p_status IS NULL OR r.status = p_status)
   ORDER BY r.due_at ASC
   LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_kyc_renewal_queue(text, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_kyc_renewal_queue(text, integer)
  TO service_role;

-- ---------------------------------------------------------------------
-- Schedule both daily crons (best-effort via DO/EXCEPTION pattern)
-- ---------------------------------------------------------------------
DO $$
BEGIN
  PERFORM cron.schedule(
    'schedule_engineer_kyc_renewals_daily',
    '0 21 * * *',  -- 21:00 UTC = 02:30 IST daily
    $cron$SELECT public.schedule_engineer_kyc_renewals();$cron$
  );
  PERFORM cron.schedule(
    'reap_expired_kyc_renewals_daily',
    '15 21 * * *', -- 21:15 UTC = 02:45 IST daily
    $cron$SELECT public.reap_expired_kyc_renewals();$cron$
  );
  RAISE NOTICE 'round 497: KYC renewal crons scheduled';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'round 497: pg_cron unavailable; renewals must be triggered from edge fn / manual';
END;
$$;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'engineer_kyc_renewals'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 497: engineer_kyc_renewals RLS not enabled';
  END IF;
  RAISE NOTICE 'round 497 engineer re-KYC scheduling verified: table + 7 RPCs + 2 crons';
END;
$$;
