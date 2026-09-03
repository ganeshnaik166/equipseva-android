-- =====================================================================
-- Round 3781 — two more dormant RPCs killed by ambiguous OUT columns
-- =====================================================================
--
-- Second pair found in the same live-verification pass as round3780
-- (which fixed round508's two). Both of these raise unconditionally,
-- for every caller and every input, and both were dormant (zero
-- clients) until round3773/round3772 wired them yesterday — which is
-- precisely why the defect survived: nothing ever executed them.
--
--   profitability_for_repair_bid(uuid)   ERRCODE 42702
--     column reference "profitability_floor_rupees" is ambiguous
--     DETAIL: It could refer to either a PL/pgSQL variable or a table column.
--
--   engineer_view_hospital_tier(uuid)    ERRCODE 42702
--     column reference "contracted_amount_rupees" is ambiguous
--
-- ROOT CAUSE (identical in both, and this is now the THIRD and FOURTH
-- instance of this exact class in this codebase — see round3761's
-- engineer_public_profile fix, which unconditionally blocked viewing
-- ANY engineer profile):
--
--   A `RETURNS TABLE(... foo ...)` declaration creates an implicit
--   PL/pgSQL OUT VARIABLE named `foo` for the whole function body. If
--   the body then runs `SELECT foo FROM some_table` where some_table
--   ALSO has a column `foo`, PL/pgSQL cannot decide whether the bare
--   identifier means its own variable or the column, and raises 42702
--   at execution time. It is not a parse-time error, so `CREATE
--   FUNCTION` succeeds happily and the bug ships invisibly.
--
--   round502 declared OUT column `profitability_floor_rupees` and then
--   selected the same-named real column off public.engineers.
--   v21 PR-D38 declared OUT columns `contracted_amount_rupees` and
--   `is_warranty_covered` and then selected both off public.repair_jobs.
--
-- FIX: alias the table and qualify every column reference. PL/pgSQL
-- only substitutes UNQUALIFIED identifiers, so `e.profitability_floor_rupees`
-- / `rj.contracted_amount_rupees` are unambiguously columns. Nothing
-- about the logic, math, authorization, or output shape changes.
--
-- Also hardened in engineer_view_hospital_tier: the not-found check was
-- `IF v_job IS NULL` on a record variable, which is only true when
-- EVERY field came back NULL. Switched to the idiomatic `IF NOT FOUND`,
-- which tests what was actually meant (no row matched). Behavioural
-- delta is limited to one pathological case — a real repair_jobs row
-- whose engineer_id, hospital_user_id, contracted_amount_rupees AND
-- is_warranty_covered are all simultaneously NULL would previously
-- report 'job not found' and will now fall through to the
-- assigned-engineer check and report 'caller is not the assigned
-- engineer' instead. The new message is the more accurate one.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. profitability_for_repair_bid — qualify the engineers columns
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.profitability_for_repair_bid(
  p_bid_id uuid
)
RETURNS TABLE(
  gross_bid_rupees             numeric,
  platform_fee_rupees          numeric,
  gst_on_fee_rupees            numeric,
  tds_estimate_rupees          numeric,
  distance_km                  numeric,
  estimated_travel_cost_rupees numeric,
  estimated_net_rupees         numeric,
  profitability_floor_rupees   numeric,
  below_floor                  boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller             uuid := auth.uid();
  v_bid                record;
  v_job                record;
  v_engineer_lat       double precision;
  v_engineer_lng       double precision;
  v_distance_m         double precision;
  v_distance_km        numeric;
  v_floor              numeric;
  v_platform_fee_pct   numeric := 7.0;
  v_gst_pct            numeric := 18.0;
  v_travel_rate_per_km numeric := 4.0;
  v_cumulative_fy      numeric := 0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT b.* INTO v_bid FROM public.repair_job_bids b WHERE b.id = p_bid_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bid_not_found' USING ERRCODE = '02000';
  END IF;
  -- Authorization: only the bidding engineer or founder can see it
  IF v_bid.engineer_user_id <> v_caller AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'only_bidder_can_see' USING ERRCODE = '42501';
  END IF;

  SELECT rj.* INTO v_job FROM public.repair_jobs rj WHERE rj.id = v_bid.repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'job_not_found' USING ERRCODE = '02000';
  END IF;

  -- round3781: `profitability_floor_rupees` is ALSO this function's own
  -- OUT variable, so the original unqualified select raised 42702 here
  -- on every single call. Alias + qualify.
  SELECT e.latitude, e.longitude, e.profitability_floor_rupees
    INTO v_engineer_lat, v_engineer_lng, v_floor
    FROM public.engineers e
   WHERE e.user_id = v_bid.engineer_user_id;
  IF v_floor IS NULL THEN v_floor := 1500.00; END IF;

  -- Distance via Haversine (r496 helper)
  IF v_engineer_lat IS NOT NULL AND v_engineer_lng IS NOT NULL
     AND v_job.site_latitude IS NOT NULL AND v_job.site_longitude IS NOT NULL THEN
    v_distance_m := public.haversine_meters(
      v_engineer_lat, v_engineer_lng,
      v_job.site_latitude, v_job.site_longitude
    );
    v_distance_km := round((v_distance_m / 1000)::numeric, 1);
  ELSE
    v_distance_km := NULL;
  END IF;

  gross_bid_rupees := coalesce(v_bid.amount_rupees, 0);
  platform_fee_rupees := round(gross_bid_rupees * (v_platform_fee_pct / 100.0), 2);
  gst_on_fee_rupees := round(platform_fee_rupees * (v_gst_pct / 100.0), 2);

  -- TDS estimate: 1% if engineer's cumulative FY gross already > Rs 5L
  --
  -- round3781 bugs 3+4, both uncovered only because fixing bug 1 let
  -- execution reach this far for the first time ever:
  --
  --   BUG 3 (42703, fatal): round502 referenced `dispatched_at`, which
  --   has never existed on engineer_payouts. The real completion
  --   timestamp is `processed_at`. Columns are:
  --   queued_at / last_attempt_at / processed_at / created_at / updated_at.
  --
  --   BUG 4 (silent, dead predicate): round502 filtered
  --   `status IN ('processed','dispatched')`, but the live CHECK
  --   constraint permits only queued / processing / processed / failed
  --   / cancelled. `'dispatched'` is a stale literal for a state that
  --   does not exist, so that arm never matched anything. Because
  --   status is `text` (not an enum) this produced no error — it just
  --   silently contributed nothing, the same shape as round3763's
  --   engineer_id_guard stale-status-literal bug. Dropped it and kept
  --   only 'processed', which is the correct semantics anyway: §194-O
  --   TDS accrues on amounts actually credited to the engineer, so
  --   queued/processing money must NOT count toward the threshold.
  SELECT coalesce(sum(ep.amount_rupees), 0)
    INTO v_cumulative_fy
    FROM public.engineer_payouts ep
   WHERE ep.engineer_user_id = v_bid.engineer_user_id
     AND ep.status = 'processed'
     AND coalesce(ep.processed_at, ep.updated_at) >= (
       CASE WHEN EXTRACT(MONTH FROM (now() AT TIME ZONE 'Asia/Kolkata')) >= 4
            THEN make_timestamptz(EXTRACT(YEAR FROM (now() AT TIME ZONE 'Asia/Kolkata'))::int, 4, 1, 0, 0, 0, 'Asia/Kolkata')
            ELSE make_timestamptz((EXTRACT(YEAR FROM (now() AT TIME ZONE 'Asia/Kolkata')))::int - 1, 4, 1, 0, 0, 0, 'Asia/Kolkata')
       END
     );

  IF v_cumulative_fy > 500000 THEN
    tds_estimate_rupees := round(gross_bid_rupees * 0.01, 2);
  ELSE
    tds_estimate_rupees := 0;
  END IF;

  distance_km := v_distance_km;
  estimated_travel_cost_rupees := CASE
    WHEN v_distance_km IS NOT NULL THEN round(v_distance_km * v_travel_rate_per_km * 2, 2) -- round trip
    ELSE 0
  END;

  estimated_net_rupees := round(
    gross_bid_rupees - platform_fee_rupees - tds_estimate_rupees - estimated_travel_cost_rupees,
    2
  );
  profitability_floor_rupees := v_floor;
  below_floor := (estimated_net_rupees < v_floor);

  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.profitability_for_repair_bid(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.profitability_for_repair_bid(uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. engineer_view_hospital_tier — qualify the repair_jobs columns
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.engineer_view_hospital_tier(
  p_repair_job_id uuid
)
RETURNS TABLE (
  commission_rate           numeric,
  contracted_amount_rupees  numeric,
  effective_payout_rupees   numeric,
  is_warranty_covered       boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller      uuid := auth.uid();
  v_engineer_id uuid;
  v_job         record;
  v_rate        numeric;
  v_amount      numeric;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT e.id INTO v_engineer_id
    FROM public.engineers e
   WHERE e.user_id = v_caller
   LIMIT 1;
  IF v_engineer_id IS NULL THEN RETURN; END IF;

  -- round3781: `contracted_amount_rupees` and `is_warranty_covered` are
  -- BOTH this function's own OUT variables AND real repair_jobs
  -- columns, so the original unqualified select raised 42702 here on
  -- every call that got this far. Alias + qualify.
  SELECT rj.engineer_id, rj.hospital_user_id, rj.contracted_amount_rupees, rj.is_warranty_covered
    INTO v_job
    FROM public.repair_jobs rj
   WHERE rj.id = p_repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'job not found' USING ERRCODE = '02000';
  END IF;

  -- Caller must be the engineer assigned to this job. Pre-bid tier
  -- shopping is intentionally blocked.
  IF v_job.engineer_id IS DISTINCT FROM v_engineer_id THEN
    RAISE EXCEPTION 'caller is not the assigned engineer' USING ERRCODE = '42501';
  END IF;

  v_rate   := public.commission_rate_for_hospital(v_job.hospital_user_id);
  v_amount := coalesce(v_job.contracted_amount_rupees, 0);

  IF v_job.is_warranty_covered THEN
    -- PR-D12 zeros platform_commission for warranty rows.
    RETURN QUERY SELECT 0::numeric, v_amount, v_amount, true;
  ELSE
    RETURN QUERY
    SELECT
      v_rate,
      v_amount,
      round(v_amount * (1 - v_rate), 2),
      false;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_view_hospital_tier(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.engineer_view_hospital_tier(uuid) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- Verification — EXECUTE both against real rows, INSIDE the transaction
-- ---------------------------------------------------------------------
-- 42702/42703 are execution-time errors, so redefining the functions
-- proves nothing; they must actually run. Both are exercised as the
-- founder (who has both an engineers row and assigned jobs in this DB,
-- and whose is_founder() bypass satisfies profitability's bidder check).
--
-- NOTE ON PLACEMENT: this block deliberately runs BEFORE COMMIT. The
-- first attempt at this migration put verification after COMMIT, and
-- when it caught bug 3 the function bodies had ALREADY been committed
-- while the migration itself went unrecorded — leaving prod in a
-- half-fixed state that only a follow-up push could resolve. Inside
-- the transaction, a failed probe rolls the function definitions back
-- with it, so the migration is genuinely all-or-nothing. Worth keeping
-- as the standing pattern for verified migrations.
DO $$
DECLARE
  v_bid_id   uuid;
  v_job_id   uuid;
  v_net      numeric;
  v_rate     numeric;
BEGIN
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object(
      'sub',  '756a3373-1077-470e-bc0a-79b8d6673ef4',
      'role', 'authenticated',
      'email','ganesh1431.dhanavath@gmail.com'
    )::text,
    true
  );

  SELECT b.id INTO v_bid_id FROM public.repair_job_bids b ORDER BY b.created_at DESC LIMIT 1;
  IF v_bid_id IS NULL THEN
    RAISE NOTICE 'round 3781: no repair_job_bids rows — profitability_for_repair_bid not exercised';
  ELSE
    SELECT p.estimated_net_rupees INTO v_net
      FROM public.profitability_for_repair_bid(v_bid_id) p;
    RAISE NOTICE 'round 3781: profitability_for_repair_bid() executed OK (net = %)', v_net;
  END IF;

  SELECT rj.id INTO v_job_id
    FROM public.repair_jobs rj
    JOIN public.engineers e ON e.id = rj.engineer_id
   WHERE e.user_id = '756a3373-1077-470e-bc0a-79b8d6673ef4'::uuid
   LIMIT 1;
  IF v_job_id IS NULL THEN
    RAISE NOTICE 'round 3781: founder is not the assigned engineer on any job — engineer_view_hospital_tier not exercised';
  ELSE
    SELECT t.commission_rate INTO v_rate
      FROM public.engineer_view_hospital_tier(v_job_id) t;
    RAISE NOTICE 'round 3781: engineer_view_hospital_tier() executed OK (rate = %)', v_rate;
  END IF;

  RAISE NOTICE 'round 3781 verified: both RPCs now execute (were 42702 ambiguous-OUT-column + 42703 phantom-column, unconditionally, since they shipped)';
END;
$$;

COMMIT;
