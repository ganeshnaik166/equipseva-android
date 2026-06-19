BEGIN;

DROP FUNCTION IF EXISTS public.founder_rfq_marketplace_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_rfq_marketplace_snapshot_summary()
RETURNS TABLE (
  total_rfqs_all_time              bigint,
  distinct_requester_orgs          bigint,
  total_rfq_bids                   bigint,
  accepted_rfq_bids                bigint,
  bid_acceptance_rate_pct          numeric,
  rfqs_with_bids                   bigint,
  rfqs_with_zero_bids              bigint,
  avg_bids_per_rfq                 numeric,
  distinct_bidding_manufacturers   bigint,
  total_bid_value_rupees           numeric,
  rental_listings_total            bigint,
  rental_owner_orgs                bigint,
  marketplace_listings_total       bigint,
  financing_applications_total     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_total_rfqs       bigint;
  v_total_bids       bigint;
  v_accepted_bids    bigint;
  v_rfqs_with_bids   bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Pre-compute denominators so derived rates stay consistent.
  SELECT count(*)::bigint INTO v_total_rfqs FROM public.rfqs;
  SELECT count(*)::bigint INTO v_total_bids FROM public.rfq_bids;
  SELECT count(*)::bigint INTO v_accepted_bids FROM public.rfq_bids WHERE status = 'accepted';
  SELECT count(DISTINCT rfq_id)::bigint INTO v_rfqs_with_bids FROM public.rfq_bids;

  RETURN QUERY
  SELECT
    coalesce(v_total_rfqs, 0),
    coalesce((SELECT count(DISTINCT requester_org_id)::bigint
              FROM public.rfqs
              WHERE requester_org_id IS NOT NULL), 0),
    coalesce(v_total_bids, 0),
    coalesce(v_accepted_bids, 0),
    CASE
      WHEN coalesce(v_total_bids, 0) = 0 THEN 0::numeric
      ELSE round((v_accepted_bids::numeric / v_total_bids::numeric) * 100, 1)
    END,
    coalesce(v_rfqs_with_bids, 0),
    GREATEST(coalesce(v_total_rfqs, 0) - coalesce(v_rfqs_with_bids, 0), 0),
    CASE
      WHEN coalesce(v_total_rfqs, 0) = 0 THEN 0::numeric
      ELSE round(v_total_bids::numeric / v_total_rfqs::numeric, 2)
    END,
    coalesce((SELECT count(DISTINCT manufacturer_id)::bigint
              FROM public.rfq_bids
              WHERE manufacturer_id IS NOT NULL), 0),
    coalesce((SELECT round(sum(total_price)::numeric, 2)
              FROM public.rfq_bids), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.rental_listings), 0),
    coalesce((SELECT count(DISTINCT owner_org_id)::bigint
              FROM public.rental_listings
              WHERE owner_org_id IS NOT NULL), 0),
    coalesce((SELECT count(*)::bigint FROM public.marketplace_listings), 0),
    coalesce((SELECT count(*)::bigint FROM public.financing_applications), 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_rfq_marketplace_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_rfq_marketplace_snapshot_summary() TO authenticated;

COMMIT;
