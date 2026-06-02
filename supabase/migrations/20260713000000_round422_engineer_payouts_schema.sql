-- Round 422 — engineer payouts schema (auto-pay v1 foundation).
--
-- Today: escrow flips to 'released' but engineer's bank/UPI never sees
-- the money. The founder owns the Razorpay merchant balance and has to
-- pay each engineer by hand. Round 421 surfaced this gap on the
-- 2026-06-02 ₹10 E2E demo (RPR-00034: escrow released, but engineer
-- received ₹0).
--
-- This round ships the SCHEMA + queueing trigger only. The edge
-- function that actually calls RazorpayX Payouts API lands in Round 424
-- (paired with the engineer-side UI in Round 423). Until the edge fn
-- is live + RAZORPAYX_KEY_ID env var is set, rows accumulate in
-- engineer_payouts with status='queued' and no money moves — exactly
-- the same situation as today, just observable.
--
-- Two tables:
--   engineer_payout_methods — one (or more) destination per engineer.
--     Holds UPI VPA or bank IFSC+account, plus cached Razorpay
--     contact_id + fund_account_id once the edge fn binds them.
--
--   engineer_payouts — one row per release-due payout. Inserted by
--     trigger when repair_job_escrow.status flips to 'released' AND
--     the engineer has a default payout method AND the post-commission
--     payout is > 0. State machine:
--       queued     — created by trigger, waiting for worker pickup
--       processing — worker has called RazorpayX, awaiting webhook
--       processed  — RazorpayX confirmed money delivered
--       failed     — RazorpayX rejected (invalid VPA, insufficient
--                    funds, etc); see failure_reason
--       cancelled  — admin voided (e.g. dispute reversed the release)
--
-- The trigger is intentionally SOFT: if the engineer has no default
-- payout method, the escrow still releases (existing flow unchanged)
-- and a placeholder row with status='queued' + destination_id=NULL is
-- inserted so we can chase the engineer to add a method. The worker
-- skips NULL-destination rows.

-- ---------------------------------------------------------------------
-- 1. engineer_payout_methods
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_payout_methods (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind                       text NOT NULL
                               CHECK (kind IN ('upi','bank')),
  -- UPI fields (kind='upi').
  vpa                        text,
  vpa_holder_name            text,
  -- Bank fields (kind='bank').
  bank_account_holder        text,
  bank_name                  text,
  ifsc                       text,
  account_number_encrypted   text,
  account_number_last4       text,
  -- Razorpay binding (filled by Round 424 edge fn first time we pay
  -- out to this method; cached so we don't re-create every payout).
  razorpay_contact_id        text,
  razorpay_fund_account_id   text,
  -- One row at a time gets is_default=true per engineer (partial
  -- unique index below); the worker picks that row when queueing.
  is_default                 boolean NOT NULL DEFAULT true,
  -- VPA verification status: 'unverified' on insert, 'verified' after
  -- a successful first payout, 'invalid' if RazorpayX rejected it.
  -- Distinct from bank_accounts.verified (which is KYC-admin only) —
  -- this is pure payment-rail health.
  status                     text NOT NULL DEFAULT 'unverified'
                               CHECK (status IN ('unverified','verified','invalid')),
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),

  -- Kind-specific NOT-NULL contracts. Either UPI vpa OR all four bank
  -- fields; never both, never neither.
  CONSTRAINT engineer_payout_methods_kind_fields_chk CHECK (
    (kind = 'upi' AND vpa IS NOT NULL AND length(trim(vpa)) > 0
        AND bank_account_holder IS NULL AND ifsc IS NULL
        AND account_number_encrypted IS NULL AND account_number_last4 IS NULL)
    OR
    (kind = 'bank' AND vpa IS NULL
        AND bank_account_holder IS NOT NULL AND length(trim(bank_account_holder)) > 0
        AND ifsc IS NOT NULL AND length(ifsc) = 11
        AND account_number_encrypted IS NOT NULL
        AND account_number_last4 IS NOT NULL AND length(account_number_last4) = 4)
  )
);

-- Only one default per engineer. Composite unique index lets us flip
-- the flag atomically (set old to false, set new to true) inside the
-- RPC transaction without tripping a hard unique on (user_id) alone.
CREATE UNIQUE INDEX IF NOT EXISTS idx_engineer_payout_methods_one_default
  ON public.engineer_payout_methods (user_id)
  WHERE is_default = true;

CREATE INDEX IF NOT EXISTS idx_engineer_payout_methods_user
  ON public.engineer_payout_methods (user_id);

-- ---------------------------------------------------------------------
-- 2. engineer_payouts
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_payouts (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id            uuid NOT NULL
                             REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  -- One payout per release. Re-release after a dispute reverse would
  -- need a separate row; unique on (repair_job_id) keeps the trigger
  -- safe from double-fire.
  CONSTRAINT engineer_payouts_one_per_job UNIQUE (repair_job_id),
  engineer_user_id         uuid NOT NULL REFERENCES auth.users(id),
  escrow_id                uuid REFERENCES public.repair_job_escrow(id) ON DELETE SET NULL,
  payout_method_id         uuid REFERENCES public.engineer_payout_methods(id) ON DELETE SET NULL,
  amount_paise             bigint NOT NULL CHECK (amount_paise > 0),
  -- Razorpay fields (set by edge fn).
  razorpay_payout_id       text,
  razorpayx_status         text,                       -- last seen RazorpayX status
  mode                     text CHECK (mode IN ('UPI','IMPS','NEFT','RTGS')),
  utr                      text,                       -- bank ref once processed
  failure_reason           text,
  attempts                 integer NOT NULL DEFAULT 0,
  -- Our state machine (decoupled from razorpayx_status which mirrors
  -- their vocabulary — queued vs processing vs processed vs reversed).
  status                   text NOT NULL DEFAULT 'queued'
                             CHECK (status IN (
                               'queued','processing','processed','failed','cancelled'
                             )),
  queued_at                timestamptz NOT NULL DEFAULT now(),
  last_attempt_at          timestamptz,
  processed_at             timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_payouts_queued
  ON public.engineer_payouts (queued_at)
  WHERE status = 'queued' AND payout_method_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_engineer_payouts_engineer_status
  ON public.engineer_payouts (engineer_user_id, status, queued_at DESC);
CREATE INDEX IF NOT EXISTS idx_engineer_payouts_razorpay
  ON public.engineer_payouts (razorpay_payout_id)
  WHERE razorpay_payout_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- 3. updated_at triggers (cheap, same shape as the rest of the schema)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.engineer_payout_methods_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;

DROP TRIGGER IF EXISTS engineer_payout_methods_touch_updated_at_trg
  ON public.engineer_payout_methods;
CREATE TRIGGER engineer_payout_methods_touch_updated_at_trg
  BEFORE UPDATE ON public.engineer_payout_methods
  FOR EACH ROW EXECUTE FUNCTION public.engineer_payout_methods_touch_updated_at();

CREATE OR REPLACE FUNCTION public.engineer_payouts_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;

DROP TRIGGER IF EXISTS engineer_payouts_touch_updated_at_trg
  ON public.engineer_payouts;
CREATE TRIGGER engineer_payouts_touch_updated_at_trg
  BEFORE UPDATE ON public.engineer_payouts
  FOR EACH ROW EXECUTE FUNCTION public.engineer_payouts_touch_updated_at();

-- ---------------------------------------------------------------------
-- 4. RLS — engineer sees own rows; only service_role mutates payouts
-- ---------------------------------------------------------------------
ALTER TABLE public.engineer_payout_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_payouts        ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS epm_select_self    ON public.engineer_payout_methods;
DROP POLICY IF EXISTS epm_select_admin   ON public.engineer_payout_methods;
DROP POLICY IF EXISTS ep_select_engineer ON public.engineer_payouts;
DROP POLICY IF EXISTS ep_select_admin    ON public.engineer_payouts;

CREATE POLICY epm_select_self
  ON public.engineer_payout_methods FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY epm_select_admin
  ON public.engineer_payout_methods FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
     WHERE p.id = auth.uid() AND p.role = 'admin'
  ));

CREATE POLICY ep_select_engineer
  ON public.engineer_payouts FOR SELECT TO authenticated
  USING (engineer_user_id = auth.uid());

CREATE POLICY ep_select_admin
  ON public.engineer_payouts FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
     WHERE p.id = auth.uid() AND p.role = 'admin'
  ));

-- No INSERT/UPDATE/DELETE policies — all writes go through SECDEF RPCs
-- (engineer-facing) or service_role (worker / webhook).

-- ---------------------------------------------------------------------
-- 5. RPC — set_engineer_payout_method
-- ---------------------------------------------------------------------
-- Engineer-facing UPSERT. UPI path: pass p_vpa + p_vpa_holder_name.
-- Bank path: pass p_bank_account_holder + p_ifsc + p_account_number +
-- p_bank_name. Caller MUST encrypt the account number client-side
-- (Round 423 wires this against the existing KYC encrypt path); the
-- RPC trusts the caller for now and stamps account_number_last4 from
-- it. We do NOT store plaintext.
CREATE OR REPLACE FUNCTION public.set_engineer_payout_method(
  p_kind                      text,
  p_vpa                       text DEFAULT NULL,
  p_vpa_holder_name           text DEFAULT NULL,
  p_bank_account_holder       text DEFAULT NULL,
  p_bank_name                 text DEFAULT NULL,
  p_ifsc                      text DEFAULT NULL,
  p_account_number_encrypted  text DEFAULT NULL,
  p_account_number_last4      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_role   text;
  v_id     uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  -- Engineers only (matches existing role gate on earnings RPCs).
  SELECT role INTO v_role FROM public.profiles WHERE id = v_caller;
  IF v_role <> 'engineer' THEN
    RAISE EXCEPTION 'only engineers can set payout method' USING ERRCODE = '42501';
  END IF;

  IF p_kind = 'upi' THEN
    IF p_vpa IS NULL OR length(trim(p_vpa)) = 0 THEN
      RAISE EXCEPTION 'vpa required for upi method' USING ERRCODE = '22023';
    END IF;
    -- Loose VPA shape check (final validation happens at Razorpay).
    IF p_vpa !~ '^[a-zA-Z0-9._-]+@[a-zA-Z]+$' THEN
      RAISE EXCEPTION 'invalid vpa format' USING ERRCODE = '22023';
    END IF;
  ELSIF p_kind = 'bank' THEN
    IF p_bank_account_holder IS NULL OR length(trim(p_bank_account_holder)) = 0
       OR p_ifsc IS NULL OR length(p_ifsc) <> 11
       OR p_account_number_encrypted IS NULL
       OR p_account_number_last4 IS NULL OR length(p_account_number_last4) <> 4 THEN
      RAISE EXCEPTION 'bank account fields incomplete' USING ERRCODE = '22023';
    END IF;
  ELSE
    RAISE EXCEPTION 'kind must be upi or bank' USING ERRCODE = '22023';
  END IF;

  -- Demote any existing default in one statement so the partial unique
  -- index never holds two rows at is_default=true within the same txn.
  UPDATE public.engineer_payout_methods
     SET is_default = false
   WHERE user_id = v_caller AND is_default = true;

  INSERT INTO public.engineer_payout_methods (
    user_id, kind, vpa, vpa_holder_name,
    bank_account_holder, bank_name, ifsc,
    account_number_encrypted, account_number_last4,
    is_default, status
  ) VALUES (
    v_caller,
    p_kind,
    CASE WHEN p_kind = 'upi'  THEN trim(p_vpa)             ELSE NULL END,
    CASE WHEN p_kind = 'upi'  THEN nullif(trim(p_vpa_holder_name), '') ELSE NULL END,
    CASE WHEN p_kind = 'bank' THEN trim(p_bank_account_holder) ELSE NULL END,
    CASE WHEN p_kind = 'bank' THEN nullif(trim(p_bank_name), '')      ELSE NULL END,
    CASE WHEN p_kind = 'bank' THEN upper(trim(p_ifsc))      ELSE NULL END,
    CASE WHEN p_kind = 'bank' THEN p_account_number_encrypted ELSE NULL END,
    CASE WHEN p_kind = 'bank' THEN p_account_number_last4    ELSE NULL END,
    true,
    'unverified'
  ) RETURNING id INTO v_id;

  RETURN v_id;
END
$$;
REVOKE EXECUTE ON FUNCTION public.set_engineer_payout_method(
  text, text, text, text, text, text, text, text
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.set_engineer_payout_method(
  text, text, text, text, text, text, text, text
) TO authenticated;

-- ---------------------------------------------------------------------
-- 6. Trigger — enqueue payout when escrow flips to 'released'
-- ---------------------------------------------------------------------
-- Why a trigger and not an explicit INSERT inside confirm_repair_job_escrow:
-- escrow can release via TWO paths — hospital early-confirm RPC, or
-- the auto-release cron after 48h. Both flip status to 'released'; a
-- trigger covers both with one code path. Edge case: dispute_resolved
-- with resolution='release' also lands at status='released'. Same
-- handling is correct.
CREATE OR REPLACE FUNCTION public.enqueue_engineer_payout_on_escrow_release()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payout_paise bigint;
  v_method_id    uuid;
BEGIN
  -- Only fire on the held->released transition.
  IF NEW.status <> 'released' OR OLD.status = 'released' THEN
    RETURN NEW;
  END IF;

  -- Pull engineer_payout in rupees from repair_jobs and convert to
  -- paise. trigger compute_repair_job_commission_on_complete_trg has
  -- already written it by the time the escrow flips (escrow release
  -- requires job status='completed', which fires that trigger first).
  SELECT (engineer_payout * 100)::bigint INTO v_payout_paise
    FROM public.repair_jobs
   WHERE id = NEW.repair_job_id;

  -- Skip when commission ate the entire amount (e.g. warranty waiver
  -- → engineer_payout = 0). The released escrow stays in the founder
  -- balance and nothing to pay out.
  IF v_payout_paise IS NULL OR v_payout_paise <= 0 THEN
    RETURN NEW;
  END IF;

  SELECT id INTO v_method_id
    FROM public.engineer_payout_methods
   WHERE user_id = NEW.engineer_user_id AND is_default = true
   LIMIT 1;

  -- INSERT even when v_method_id IS NULL — gives us a queued row we
  -- can chase the engineer to attach a method to. Worker filters
  -- NULL-method rows out of the pickup query.
  INSERT INTO public.engineer_payouts (
    repair_job_id, engineer_user_id, escrow_id,
    payout_method_id, amount_paise, status
  ) VALUES (
    NEW.repair_job_id, NEW.engineer_user_id, NEW.id,
    v_method_id, v_payout_paise, 'queued'
  )
  ON CONFLICT (repair_job_id) DO NOTHING;

  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS enqueue_engineer_payout_on_escrow_release_trg
  ON public.repair_job_escrow;
CREATE TRIGGER enqueue_engineer_payout_on_escrow_release_trg
  AFTER UPDATE OF status ON public.repair_job_escrow
  FOR EACH ROW
  EXECUTE FUNCTION public.enqueue_engineer_payout_on_escrow_release();

-- ---------------------------------------------------------------------
-- 7. Backfill — enqueue any already-released escrows that pre-date
--    this migration (so today's RPR-00034 ₹9.30 demo enters the queue
--    and gets paid out as soon as the edge fn ships in Round 424).
-- ---------------------------------------------------------------------
INSERT INTO public.engineer_payouts (
  repair_job_id, engineer_user_id, escrow_id, payout_method_id, amount_paise, status
)
SELECT
  e.repair_job_id,
  e.engineer_user_id,
  e.id,
  (SELECT id FROM public.engineer_payout_methods m
    WHERE m.user_id = e.engineer_user_id AND m.is_default = true LIMIT 1),
  (rj.engineer_payout * 100)::bigint,
  'queued'
FROM public.repair_job_escrow e
JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
WHERE e.status = 'released'
  AND COALESCE(rj.engineer_payout, 0) > 0
ON CONFLICT (repair_job_id) DO NOTHING;

-- ---------------------------------------------------------------------
-- 8. RPC — list_engineer_payouts (engineer-facing)
-- ---------------------------------------------------------------------
-- Could be a plain SELECT against the engineer_payouts RLS policy,
-- but join+enrich here keeps the Android repository to one round-trip
-- (job_number + UTR + masked destination in one shot).
CREATE OR REPLACE FUNCTION public.list_engineer_payouts(
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id                 uuid,
  repair_job_id      uuid,
  job_number         text,
  amount_paise       bigint,
  status             text,
  mode               text,
  utr                text,
  failure_reason     text,
  destination_label  text,
  queued_at          timestamptz,
  processed_at       timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT
    p.id,
    p.repair_job_id,
    rj.job_number,
    p.amount_paise,
    p.status,
    p.mode,
    p.utr,
    p.failure_reason,
    CASE
      WHEN m.id IS NULL                THEN 'No payout method on file'
      WHEN m.kind = 'upi'              THEN m.vpa
      WHEN m.kind = 'bank' AND m.bank_name IS NOT NULL
                                       THEN m.bank_name || ' •••• ' || m.account_number_last4
      ELSE                                 'Bank •••• ' || m.account_number_last4
    END AS destination_label,
    p.queued_at,
    p.processed_at
  FROM public.engineer_payouts p
  JOIN public.repair_jobs rj ON rj.id = p.repair_job_id
  LEFT JOIN public.engineer_payout_methods m ON m.id = p.payout_method_id
  WHERE p.engineer_user_id = auth.uid()
  ORDER BY p.queued_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
$$;
REVOKE EXECUTE ON FUNCTION public.list_engineer_payouts(int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.list_engineer_payouts(int) TO authenticated;

-- ---------------------------------------------------------------------
-- 9. Comments — for future maintainers reading psql \dt+
-- ---------------------------------------------------------------------
COMMENT ON TABLE  public.engineer_payout_methods IS
  'Engineer payout destinations (UPI VPA or bank). Round 422.';
COMMENT ON TABLE  public.engineer_payouts IS
  'One row per release-due engineer payout. Round 422; worker = Round 424.';
COMMENT ON COLUMN public.engineer_payouts.payout_method_id IS
  'NULL means engineer had no default method at release time — worker '
  'skips; we must chase the engineer to add one.';
