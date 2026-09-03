-- =====================================================================
-- Round 3784 — two payment-webhook handlers + the investor share reader
-- =====================================================================
--
-- Three more defects from the same static sweep (plpgsql_check) that
-- produced round3780-3783. All three are single-defect functions, and
-- for the two payment handlers the FUNCTION is correct — the TABLE is
-- missing the column it writes. That makes the minimal fix additive
-- DDL rather than a body rewrite, which is both smaller and safer.
--
-- 1. record_engineer_payout_webhook  ERRCODE 42703 (line 13)
--      column "razorpayx_status" of relation "payouts_webhook_events"
--      does not exist
--
--    This is the RazorpayX PAYOUT WEBHOOK handler — the callback that
--    tells us whether money actually left the platform to an engineer.
--    Its very first INSERT names a column the table never had, so
--    EVERY payout webhook delivery has failed. Consequence: payout
--    outcome (processed / reversed / failed, plus UTR) was never
--    recorded from the provider side, so engineer_payouts could only
--    ever reflect what WE optimistically wrote, never what RazorpayX
--    confirmed. That is a money-reconciliation hole, and it is
--    precisely the drift that ROADMAP_v04's #2-ranked must-have
--    ("Three-Way Recon ... silent rupee drift compounds") exists to
--    prevent.
--
--    `engineer_payouts` itself already carries a `razorpayx_status
--    text` column, so mirroring it onto the webhook-event row is
--    clearly the original intent; the table migration simply never
--    added it. Adding it preserves the provider status instead of
--    discarding it (which is what dropping the column from the INSERT
--    would have done).
--
-- 2. record_razorpay_payment_captured  ERRCODE 42703 (line 69)
--      column "paid_at" does not exist
--
--    The payment-captured handler. Line 69 is the AMC branch, which
--    marks an amc_payment_orders row paid. `amc_payment_orders` has
--    status / created_at / updated_at but no `paid_at`, so capturing an
--    AMC payment raised 42703. Adding `paid_at timestamptz` keeps the
--    distinction the function is reaching for — `updated_at` moves on
--    every touch, whereas "when did this order actually get paid" must
--    not.
--
--    Scope note, stated honestly: line 69 is one branch of this
--    function. Repair-job payment capture goes through a different
--    branch and is NOT implicated by this particular error, so this
--    fix should be read as "AMC payment capture was broken", not "all
--    payment capture was broken".
--
-- 3. investor_share_v2  ERRCODE 42883 (line 43)
--      function pg_catalog.btrim(equipment_category) does not exist
--
--    Found by end-to-end probing AFTER round3783 fixed this function's
--    pgcrypto defect — a textbook case of one bug masking the next
--    (the same pattern as round3781's stacked pair). With a genuinely
--    valid minted token the reader now got far enough to run:
--        coalesce(nullif(trim(equipment_type), ''), '(other)')
--    against public.repair_jobs. `repair_jobs.equipment_type` is the
--    ENUM `equipment_category`, and there is no btrim(equipment_category).
--
--    This is the FOURTH instance tonight of the same root invariant:
--    repair_jobs.equipment_type is an ENUM while every table that
--    denormalises it stores text, so any text operation on it needs an
--    explicit ::text cast. Prior instances: round3760
--    (repair_jobs_taxonomy_gate — had blocked ALL hospital job
--    posting), round3780 (hospital_fleet_health), round3780
--    (asset_history's concatenation, fixed pre-emptively).
--
--    NOTE: read_investor_brief_via_token re-checked clean after
--    round3783 — only investor_share_v2 carries this one.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. payouts_webhook_events.razorpayx_status
-- ---------------------------------------------------------------------
-- Nullable, no default: purely additive, existing rows unaffected.
ALTER TABLE public.payouts_webhook_events
  ADD COLUMN IF NOT EXISTS razorpayx_status text;

COMMENT ON COLUMN public.payouts_webhook_events.razorpayx_status IS
  'Round 3784 — provider-reported payout status from the RazorpayX webhook payload. record_engineer_payout_webhook() always wrote this column; the table never had it, so every payout webhook insert failed with 42703. Mirrors engineer_payouts.razorpayx_status.';

-- ---------------------------------------------------------------------
-- 2. amc_payment_orders.paid_at
-- ---------------------------------------------------------------------
ALTER TABLE public.amc_payment_orders
  ADD COLUMN IF NOT EXISTS paid_at timestamptz;

COMMENT ON COLUMN public.amc_payment_orders.paid_at IS
  'Round 3784 — when this AMC payment order was actually captured. record_razorpay_payment_captured() always set this; the table never had it, so AMC payment capture failed with 42703. Distinct from updated_at, which moves on every touch.';

-- Backfill: rows already marked paid pre-date the column. updated_at is
-- the closest available approximation of when they were captured, and
-- is strictly better than leaving a NULL that reads as "never paid".
-- Flagged as an approximation rather than presented as exact.
UPDATE public.amc_payment_orders
   SET paid_at = updated_at
 WHERE status = 'paid'
   AND paid_at IS NULL;

-- ---------------------------------------------------------------------
-- 3. investor_share_v2 — cast the enum before trim()
-- ---------------------------------------------------------------------
-- Same guarded-programmatic approach as round3783, and for the same
-- reason: this is an 88-line SECURITY DEFINER body gating access to
-- investor financials, and the required change is a single token. The
-- assertions below make the rewrite verifiably exact.
DO $$
DECLARE
  v_oid    oid;
  v_def    text;
  v_new    text;
  v_before int;
  v_after  int;
BEGIN
  SELECT p.oid INTO v_oid
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname = 'investor_share_v2';
  IF v_oid IS NULL THEN
    RAISE EXCEPTION 'round 3784: public.investor_share_v2 not found';
  END IF;

  v_def := pg_get_functiondef(v_oid);

  -- There are TWO occurrences of the identical expression — once in the
  -- SELECT list and once in the GROUP BY — and they MUST stay identical
  -- or the GROUP BY stops matching the projection. plpgsql_check only
  -- reported the first; the guard below is what caught the second on the
  -- initial attempt at this migration (it asserted 1 and correctly
  -- refused to run). Both are rewritten together.
  SELECT count(*) INTO v_before
    FROM regexp_matches(v_def, 'trim\([[:space:]]*equipment_type[[:space:]]*\)', 'g');
  IF v_before <> 2 THEN
    RAISE EXCEPTION
      'round 3784: expected exactly 2 bare trim(equipment_type) in investor_share_v2 (SELECT list + GROUP BY), found % — refusing to rewrite',
      v_before;
  END IF;

  v_new := regexp_replace(
             v_def,
             'trim\([[:space:]]*equipment_type[[:space:]]*\)',
             'trim(equipment_type::text)',
             'g');

  SELECT count(*) INTO v_after
    FROM regexp_matches(v_new, 'trim\([[:space:]]*equipment_type[[:space:]]*\)', 'g');
  IF v_after <> 0 THEN
    RAISE EXCEPTION 'round 3784: rewrite left % un-cast trim(equipment_type) — refusing to apply', v_after;
  END IF;

  -- THIRD defect in the same function, surfaced only once the two above
  -- were fixed and a REAL token could reach line 71:
  --     22P02 invalid input value for enum payment_status: ""
  -- from `WHERE coalesce(payment_status,'') = 'paid'` against
  -- public.spare_part_orders, whose payment_status is the ENUM
  -- `payment_status` — so coalesce() tries to coerce '' into the enum.
  -- Same root invariant as the equipment_type casts: an enum column
  -- being treated as text. Cast before the coalesce; the semantics are
  -- unchanged (a NULL payment_status did not equal 'paid' before and
  -- still does not).
  SELECT count(*) INTO v_before
    FROM regexp_matches(v_new, 'coalesce\([[:space:]]*payment_status[[:space:]]*,', 'gi');
  IF v_before <> 1 THEN
    RAISE EXCEPTION
      'round 3784: expected exactly 1 coalesce(payment_status, ...) in investor_share_v2, found % — refusing to rewrite',
      v_before;
  END IF;

  v_new := regexp_replace(
             v_new,
             'coalesce\([[:space:]]*payment_status[[:space:]]*,',
             'coalesce(payment_status::text,',
             'gi');

  SELECT count(*) INTO v_after
    FROM regexp_matches(v_new, 'coalesce\([[:space:]]*payment_status[[:space:]]*,', 'gi');
  IF v_after <> 0 THEN
    RAISE EXCEPTION 'round 3784: rewrite left % un-cast coalesce(payment_status) — refusing to apply', v_after;
  END IF;

  IF position('search_path' IN v_new) = 0 THEN
    RAISE EXCEPTION 'round 3784: rewrite lost the search_path pin — refusing to apply';
  END IF;

  EXECUTE v_new;
  RAISE NOTICE 'round 3784: cast equipment_type::text inside trim() in investor_share_v2';
END;
$$;

-- ---------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------
-- The payment handlers are money-writing and VOLATILE, so they are NOT
-- executed here. Their sole defect was the missing column, so asserting
-- the columns now exist verifies the fix exactly.
--
-- investor_share_v2 IS exercised end-to-end: mint a real token, read
-- through it, then roll the whole probe back via a subtransaction. A
-- bogus token is not sufficient here — that is exactly how the enum
-- defect stayed hidden through round3783, since an invalid token is
-- rejected before reaching line 43.
DO $$
DECLARE
  v_tok  text;
  v_rows int;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema='public' AND table_name='payouts_webhook_events'
       AND column_name='razorpayx_status'
  ) THEN
    RAISE EXCEPTION 'round 3784 VERIFY FAILED: payouts_webhook_events.razorpayx_status missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema='public' AND table_name='amc_payment_orders'
       AND column_name='paid_at'
  ) THEN
    RAISE EXCEPTION 'round 3784 VERIFY FAILED: amc_payment_orders.paid_at missing';
  END IF;
  RAISE NOTICE 'round 3784: both phantom columns now exist — payout webhook + AMC capture unblocked';

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object(
      'sub','756a3373-1077-470e-bc0a-79b8d6673ef4',
      'role','authenticated',
      'email','ganesh1431.dhanavath@gmail.com'
    )::text, true);

  BEGIN
    SELECT raw_token INTO v_tok
      FROM public.founder_mint_investor_share_token('round3784 verify probe', 1, 5);
    SELECT count(*) INTO v_rows FROM public.investor_share_v2(v_tok);
    RAISE NOTICE 'round 3784: investor_share_v2() returned % row(s) for a REAL token', v_rows;
    RAISE EXCEPTION 'ROUND3784_PROBE_ROLLBACK';
  EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
      RAISE NOTICE 'round 3784: investor-share probe rolled back (no probe token persisted)';
    WHEN OTHERS THEN
      RAISE EXCEPTION
        'round 3784 VERIFY FAILED: investor_share_v2 still errors on a valid token: % %',
        SQLSTATE, SQLERRM;
  END;

  RAISE NOTICE 'round 3784 verified: payout-webhook + AMC-capture columns added; investor_share_v2 works end-to-end on a real token';
END;
$$;

COMMIT;
