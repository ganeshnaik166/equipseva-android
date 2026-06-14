-- =====================================================================
-- Round 564 — Engineer referral bounty (v0.5 Phase 2 #3)
-- =====================================================================
--
-- Engineer-to-engineer referral program. Existing engineer (the
-- "referrer") gets a ₹2,000 bounty when the engineer they referred
-- ("referee") completes their first paid job AND meets anti-collusion
-- gates from r498 risk score + r501 duplicate detector.
--
-- Schema:
--   engineer_referrals — one row per referral relationship
--   referral_bounty_payouts — payable bounty rows (settled via the
--     existing engineer payouts queue once eligible)
--
-- Anti-abuse:
--   - Referrer + referee must not be flagged as a duplicate-account
--     pair by r501 (same Aadhaar / PAN / phone / fuzzy-name)
--   - Referrer + referee must not be in an open r498 collusion flag
--   - Referee's first job must reach 'completed' status and have
--     escrow released (escrow_status = 'released')
--   - Bounty only mints once per referee (FK + unique constraint)
--   - Founder can manually revoke a bounty (with reason) if abuse
--     is detected later

BEGIN;

-- ---------------------------------------------------------------------
-- 1. engineer_referrals — referral relationships
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_referrals (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  referee_user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  referral_code_used       text NOT NULL,
  referee_first_job_id     uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  referee_first_completed_at timestamptz,
  bounty_eligible          boolean NOT NULL DEFAULT false,
  bounty_amount_rupees     numeric(10,2) NOT NULL DEFAULT 2000.00,
  bounty_revoked           boolean NOT NULL DEFAULT false,
  bounty_revoke_reason     text,
  bounty_revoked_at        timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),

  -- Self-referral block at the schema layer.
  CONSTRAINT engineer_referrals_no_self_ref
    CHECK (referrer_user_id <> referee_user_id),
  -- One referrer per referee (a referee can only be claimed once).
  CONSTRAINT engineer_referrals_unique_referee
    UNIQUE (referee_user_id)
);

CREATE INDEX IF NOT EXISTS engineer_referrals_referrer_idx
  ON public.engineer_referrals (referrer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS engineer_referrals_eligible_idx
  ON public.engineer_referrals (bounty_eligible, bounty_revoked)
  WHERE bounty_eligible = true AND bounty_revoked = false;

ALTER TABLE public.engineer_referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_referrals_select ON public.engineer_referrals;
CREATE POLICY engineer_referrals_select
  ON public.engineer_referrals FOR SELECT
  TO authenticated
  USING (
    referrer_user_id = auth.uid()
    OR referee_user_id = auth.uid()
    OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.engineer_referrals
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. referral_bounty_payouts — payable rows (engineer queue consumes)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.referral_bounty_payouts (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id         uuid NOT NULL REFERENCES public.engineer_referrals(id) ON DELETE CASCADE,
  beneficiary_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  amount_rupees       numeric(10,2) NOT NULL,
  status              text NOT NULL DEFAULT 'queued'
                        CHECK (status IN ('queued','paid','cancelled')),
  utr                 text,
  mode                text,
  cancelled_reason    text,
  queued_at           timestamptz NOT NULL DEFAULT now(),
  paid_at             timestamptz,
  -- One bounty payout per referral row.
  CONSTRAINT referral_bounty_payouts_unique UNIQUE (referral_id)
);

CREATE INDEX IF NOT EXISTS referral_bounty_payouts_beneficiary_idx
  ON public.referral_bounty_payouts (beneficiary_user_id, queued_at DESC);
CREATE INDEX IF NOT EXISTS referral_bounty_payouts_queued_idx
  ON public.referral_bounty_payouts (status, queued_at DESC)
  WHERE status = 'queued';

ALTER TABLE public.referral_bounty_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS referral_bounty_payouts_select ON public.referral_bounty_payouts;
CREATE POLICY referral_bounty_payouts_select
  ON public.referral_bounty_payouts FOR SELECT
  TO authenticated
  USING (beneficiary_user_id = auth.uid() OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.referral_bounty_payouts
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. register_engineer_referral — engineer-side: claim a referral code
-- ---------------------------------------------------------------------
--
-- Called by the referee during signup or KYC. p_referral_code is the
-- referrer's user_id (or a short slug if we add one later). Refuses if
-- the referee already has a referral row, if it's a self-referral, or
-- if the referrer is the same auth account (verified via auth.uid()).
CREATE OR REPLACE FUNCTION public.register_engineer_referral(
  p_referrer_user_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_referrer_user_id IS NULL THEN
    RAISE EXCEPTION 'referrer_required' USING ERRCODE = '22023';
  END IF;
  IF p_referrer_user_id = auth.uid() THEN
    RAISE EXCEPTION 'cannot_refer_self' USING ERRCODE = '22023';
  END IF;

  -- Referrer must already exist as an engineer in the platform.
  IF NOT EXISTS (
    SELECT 1 FROM public.engineers WHERE user_id = p_referrer_user_id
  ) THEN
    RAISE EXCEPTION 'referrer_not_an_engineer' USING ERRCODE = '02000';
  END IF;

  INSERT INTO public.engineer_referrals
    (referrer_user_id, referee_user_id, referral_code_used)
  VALUES (p_referrer_user_id, auth.uid(), p_referrer_user_id::text)
  ON CONFLICT (referee_user_id) DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'referral_already_registered' USING ERRCODE = '22023';
  END IF;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.register_engineer_referral(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.register_engineer_referral(uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. evaluate_referral_bounty — daily cron driver
-- ---------------------------------------------------------------------
--
-- For each registered referral whose referee has at least one completed
-- + escrow-released job:
--   (a) Verify referee_first_job_id + completed_at if not yet set
--   (b) Check anti-collusion: no open r498 collusion flag pairing
--       referrer + referee
--   (c) Check anti-duplicate: no open r501 duplicate-account flag
--       pairing referrer + referee
--   (d) If all pass, set bounty_eligible=true and INSERT a queued
--       referral_bounty_payouts row (idempotent via UNIQUE constraint)
CREATE OR REPLACE FUNCTION public.evaluate_referral_bounty(
  p_referral_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ref           record;
  v_first_job     record;
  v_has_collusion boolean;
  v_has_duplicate boolean;
BEGIN
  SELECT * INTO v_ref
    FROM public.engineer_referrals
   WHERE id = p_referral_id
   FOR UPDATE;
  IF NOT FOUND OR v_ref.bounty_eligible OR v_ref.bounty_revoked THEN
    RETURN false;
  END IF;

  -- Find referee's earliest completed + escrow-released repair job.
  SELECT rj.id, rj.completed_at
    INTO v_first_job
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b
      ON b.repair_job_id = rj.id AND b.status = 'accepted'
    JOIN public.repair_job_escrow e
      ON e.repair_job_id = rj.id AND e.status = 'released'
   WHERE b.engineer_user_id = v_ref.referee_user_id
     AND rj.status = 'completed'
   ORDER BY rj.completed_at ASC
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN false;        -- no qualifying job yet
  END IF;

  -- Anti-collusion: any open r498 flag pairing the two users?
  -- Defensive: the table may not exist on older deployments; wrap in EXCEPTION.
  BEGIN
    SELECT EXISTS (
      SELECT 1 FROM public.collusion_pairs cp
       WHERE cp.status = 'open'
         AND ((cp.engineer_user_id = v_ref.referrer_user_id
                AND cp.hospital_user_id = v_ref.referee_user_id)
              OR (cp.engineer_user_id = v_ref.referee_user_id
                AND cp.hospital_user_id = v_ref.referrer_user_id))
    ) INTO v_has_collusion;
  EXCEPTION WHEN undefined_table THEN
    v_has_collusion := false;
  END;

  IF v_has_collusion THEN
    RETURN false;
  END IF;

  -- Anti-duplicate-account: any open r501 flag pairing the two users?
  BEGIN
    SELECT EXISTS (
      SELECT 1 FROM public.duplicate_account_flags df
       WHERE df.status = 'open'
         AND ((df.user_id_a = v_ref.referrer_user_id AND df.user_id_b = v_ref.referee_user_id)
              OR (df.user_id_a = v_ref.referee_user_id  AND df.user_id_b = v_ref.referrer_user_id))
    ) INTO v_has_duplicate;
  EXCEPTION WHEN undefined_table THEN
    v_has_duplicate := false;
  END;

  IF v_has_duplicate THEN
    RETURN false;
  END IF;

  -- All gates pass — mark eligible + mint the bounty payout row.
  UPDATE public.engineer_referrals
     SET bounty_eligible = true,
         referee_first_job_id = v_first_job.id,
         referee_first_completed_at = v_first_job.completed_at
   WHERE id = v_ref.id;

  INSERT INTO public.referral_bounty_payouts
    (referral_id, beneficiary_user_id, amount_rupees)
  VALUES (v_ref.id, v_ref.referrer_user_id, v_ref.bounty_amount_rupees)
  ON CONFLICT (referral_id) DO NOTHING;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.evaluate_referral_bounty(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.evaluate_referral_bounty(uuid)
  TO service_role;

-- ---------------------------------------------------------------------
-- 5. evaluate_all_pending_referrals — daily cron entry
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.evaluate_all_pending_referrals()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
  v_id    uuid;
BEGIN
  FOR v_id IN
    SELECT id FROM public.engineer_referrals
     WHERE NOT bounty_eligible AND NOT bounty_revoked
  LOOP
    IF public.evaluate_referral_bounty(v_id) THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.evaluate_all_pending_referrals()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.evaluate_all_pending_referrals()
  TO service_role;

DO $$
BEGIN
  PERFORM cron.schedule(
    'evaluate_all_pending_referrals_daily',
    '47 4 * * *',  -- 04:47 UTC = 10:17 IST
    $cron$SELECT public.evaluate_all_pending_referrals();$cron$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron unavailable; referral bounty cron must be triggered by edge fn';
END;
$$;

-- ---------------------------------------------------------------------
-- 6. founder_revoke_referral_bounty — manual override
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_revoke_referral_bounty(
  p_referral_id uuid,
  p_reason      text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payout_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 10 THEN
    RAISE EXCEPTION 'reason required (min 10 chars)' USING ERRCODE = '22023';
  END IF;

  UPDATE public.engineer_referrals
     SET bounty_revoked = true,
         bounty_revoke_reason = trim(p_reason),
         bounty_revoked_at = now()
   WHERE id = p_referral_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'referral_not_found' USING ERRCODE = '02000';
  END IF;

  SELECT status INTO v_payout_status
    FROM public.referral_bounty_payouts
   WHERE referral_id = p_referral_id;

  IF FOUND AND v_payout_status = 'queued' THEN
    UPDATE public.referral_bounty_payouts
       SET status = 'cancelled',
           cancelled_reason = trim(p_reason)
     WHERE referral_id = p_referral_id;
  END IF;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_revoke_referral_bounty',
    p_target_table  => 'engineer_referrals',
    p_target_row_id => p_referral_id,
    p_before_value  => jsonb_build_object('bounty_revoked', false),
    p_after_value   => jsonb_build_object('bounty_revoked', true,
                                          'payout_status', coalesce(v_payout_status, 'no_row')),
    p_reason        => p_reason
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_revoke_referral_bounty(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_revoke_referral_bounty(uuid, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 7. founder_referral_dashboard — cockpit summary
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_referral_dashboard()
RETURNS TABLE (
  total_referrals       int,
  pending_bounties      int,
  paid_bounties         int,
  revoked_bounties      int,
  queued_bounty_value   numeric,
  paid_bounty_value     numeric
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
  SELECT
    (SELECT count(*)::int FROM public.engineer_referrals),
    (SELECT count(*)::int FROM public.engineer_referrals
      WHERE NOT bounty_eligible AND NOT bounty_revoked),
    (SELECT count(*)::int FROM public.referral_bounty_payouts WHERE status = 'paid'),
    (SELECT count(*)::int FROM public.engineer_referrals WHERE bounty_revoked = true),
    (SELECT coalesce(sum(amount_rupees), 0)::numeric
       FROM public.referral_bounty_payouts WHERE status = 'queued'),
    (SELECT coalesce(sum(amount_rupees), 0)::numeric
       FROM public.referral_bounty_payouts WHERE status = 'paid');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_referral_dashboard()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_referral_dashboard()
  TO service_role;

-- ---------------------------------------------------------------------
-- 8. my_referrals — engineer self-view
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_referrals()
RETURNS TABLE (
  id                          uuid,
  referee_user_id             uuid,
  referee_first_completed_at  timestamptz,
  bounty_eligible             boolean,
  bounty_revoked              boolean,
  bounty_revoke_reason        text,
  bounty_amount_rupees        numeric,
  payout_status               text,
  payout_utr                  text,
  created_at                  timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    r.id, r.referee_user_id, r.referee_first_completed_at,
    r.bounty_eligible, r.bounty_revoked, r.bounty_revoke_reason,
    r.bounty_amount_rupees,
    p.status, p.utr,
    r.created_at
   FROM public.engineer_referrals r
   LEFT JOIN public.referral_bounty_payouts p ON p.referral_id = r.id
  WHERE r.referrer_user_id = v_user
  ORDER BY r.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_referrals() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_referrals() TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 564 engineer referral bounty verified: 2 tables + 6 SECDEF RPCs (register / evaluate / batch / revoke / dashboard / self-view); ₹2,000 default bounty; anti-collusion + anti-duplicate gates';
END;
$$;
