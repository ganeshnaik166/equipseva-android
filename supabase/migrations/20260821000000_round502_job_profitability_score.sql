-- =====================================================================
-- Round 502 — Job Profitability Score (v0.4 Phase 5 #5)
-- =====================================================================
--
-- Engineer-lens brainstorm surfaced: "me no want drive 40km for ₹800
-- job. Need see real net pay before accept, after platform cut + GST
-- + travel cost." Today engineer sees gross bid only; many accept low
-- jobs then realise after travel + tax they're paid below minimum wage.
-- Result: high cancellation rate + bad engineer experience.
--
-- This migration ships a server-side estimator the engineer-side
-- client calls BEFORE accepting a bid:
--   profitability_for_repair_bid(bid_id) → table with:
--     - gross_bid_rupees
--     - platform_fee_rupees (7% take rate)
--     - gst_on_fee_rupees (18% GST on the platform fee — RCM means
--       the engineer doesn't actually pay this; included for clarity)
--     - tds_estimate_rupees (1% if engineer crosses §194-O threshold)
--     - estimated_travel_cost_rupees (haversine distance × ₹4/km)
--     - estimated_net_rupees (gross - platform_fee - tds - travel)
--     - below_floor_flag (true if net < engineer's user-set floor)
--
-- Engineer can set per-engineer floor via update_my_profitability_floor.
-- Default floor = ₹1,500 / visit.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Add per-engineer profitability_floor_rupees
-- ---------------------------------------------------------------------
ALTER TABLE public.engineers
  ADD COLUMN IF NOT EXISTS profitability_floor_rupees numeric(10,2)
    NOT NULL DEFAULT 1500.00 CHECK (profitability_floor_rupees >= 0);

COMMENT ON COLUMN public.engineers.profitability_floor_rupees IS
  'Round 502 — engineer-set minimum net payout per visit. Bids below this floor get a red badge in the bid card before accept.';

-- ---------------------------------------------------------------------
-- 2. update_my_profitability_floor (engineer-callable)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_my_profitability_floor(
  p_floor_rupees numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_floor_rupees IS NULL OR p_floor_rupees < 0 OR p_floor_rupees > 50000 THEN
    RAISE EXCEPTION 'floor must be between 0 and 50000' USING ERRCODE = '22023';
  END IF;
  UPDATE public.engineers
     SET profitability_floor_rupees = round(p_floor_rupees, 2)
   WHERE user_id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'engineer_profile_not_found' USING ERRCODE = '02000';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_my_profitability_floor(numeric)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.update_my_profitability_floor(numeric)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. profitability_for_repair_bid — main RPC
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

  SELECT * INTO v_bid FROM public.repair_job_bids WHERE id = p_bid_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bid_not_found' USING ERRCODE = '02000';
  END IF;
  -- Authorization: only the bidding engineer or founder can see it
  IF v_bid.engineer_user_id <> v_caller AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'only_bidder_can_see' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = v_bid.repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'job_not_found' USING ERRCODE = '02000';
  END IF;

  -- Engineer location from engineers.latitude/longitude
  SELECT latitude, longitude, profitability_floor_rupees
    INTO v_engineer_lat, v_engineer_lng, v_floor
    FROM public.engineers
   WHERE user_id = v_bid.engineer_user_id;
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

  -- TDS estimate: 1% if engineer's cumulative FY gross already > ₹5L
  SELECT coalesce(sum(amount_rupees), 0)
    INTO v_cumulative_fy
    FROM public.engineer_payouts
   WHERE engineer_user_id = v_bid.engineer_user_id
     AND status IN ('processed','dispatched')
     AND coalesce(dispatched_at, updated_at) >= (
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

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'engineers'
      AND column_name = 'profitability_floor_rupees'
  ) THEN
    RAISE EXCEPTION 'round 502: profitability_floor_rupees column not created';
  END IF;
  RAISE NOTICE 'round 502 job profitability score verified: column + 2 RPCs ready';
END;
$$;
