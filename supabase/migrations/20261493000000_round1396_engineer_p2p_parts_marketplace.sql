BEGIN;
-- round1396_engineer_p2p_parts_marketplace.sql
-- Engineer-to-Engineer P2P Parts Marketplace infrastructure (v0.6 Phase 3)
-- 3 tables + 8 RPCs (founder admin + engineer-callable RLS-scoped + cron)



-- ============================================================
-- TABLE 1: engineer_p2p_parts_listings
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_p2p_parts_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  part_category text NOT NULL CHECK (part_category IN (
    'oem_module','consumable','calibration_tool','accessory',
    'probe_sensor','battery','display_unit','other'
  )),
  part_label text NOT NULL,
  manufacturer text,
  model_compatibility text,
  condition_band text NOT NULL CHECK (condition_band IN (
    'new_sealed','new_open','like_new','good_used','functional_only'
  )),
  ask_price_rupees numeric NOT NULL CHECK (ask_price_rupees >= 0),
  quantity_available int NOT NULL DEFAULT 1 CHECK (quantity_available >= 0),
  listing_status text NOT NULL DEFAULT 'active' CHECK (listing_status IN (
    'draft','active','reserved','sold','withdrawn','flagged'
  )),
  listed_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '60 days'),
  description text,
  evidence_photo_uris text[] DEFAULT ARRAY[]::text[],
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_p2p_listings_seller
  ON public.engineer_p2p_parts_listings(seller_engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_listings_status
  ON public.engineer_p2p_parts_listings(listing_status);
CREATE INDEX IF NOT EXISTS idx_p2p_listings_listed_at
  ON public.engineer_p2p_parts_listings(listed_at DESC);
CREATE INDEX IF NOT EXISTS idx_p2p_listings_category
  ON public.engineer_p2p_parts_listings(part_category);

ALTER TABLE public.engineer_p2p_parts_listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p2p_listings_seller_select ON public.engineer_p2p_parts_listings;
CREATE POLICY p2p_listings_seller_select ON public.engineer_p2p_parts_listings
  FOR SELECT TO authenticated
  USING (
    seller_engineer_user_id = auth.uid()
    OR listing_status = 'active'
    OR public.is_founder()
  );

DROP POLICY IF EXISTS p2p_listings_seller_insert ON public.engineer_p2p_parts_listings;
CREATE POLICY p2p_listings_seller_insert ON public.engineer_p2p_parts_listings
  FOR INSERT TO authenticated
  WITH CHECK (seller_engineer_user_id = auth.uid());

DROP POLICY IF EXISTS p2p_listings_seller_update ON public.engineer_p2p_parts_listings;
CREATE POLICY p2p_listings_seller_update ON public.engineer_p2p_parts_listings
  FOR UPDATE TO authenticated
  USING (seller_engineer_user_id = auth.uid() OR public.is_founder())
  WITH CHECK (seller_engineer_user_id = auth.uid() OR public.is_founder());

-- ============================================================
-- TABLE 2: engineer_p2p_parts_bids
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_p2p_parts_bids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES public.engineer_p2p_parts_listings(id) ON DELETE CASCADE,
  bidder_engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  bid_amount_rupees numeric NOT NULL CHECK (bid_amount_rupees >= 0),
  bid_status text NOT NULL DEFAULT 'placed' CHECK (bid_status IN (
    'placed','accepted','rejected','withdrawn','expired'
  )),
  bid_message text,
  placed_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_p2p_bids_listing ON public.engineer_p2p_parts_bids(listing_id);
CREATE INDEX IF NOT EXISTS idx_p2p_bids_bidder ON public.engineer_p2p_parts_bids(bidder_engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_bids_status ON public.engineer_p2p_parts_bids(bid_status);

ALTER TABLE public.engineer_p2p_parts_bids ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p2p_bids_select ON public.engineer_p2p_parts_bids;
CREATE POLICY p2p_bids_select ON public.engineer_p2p_parts_bids
  FOR SELECT TO authenticated
  USING (
    bidder_engineer_user_id = auth.uid()
    OR listing_id IN (
      SELECT id FROM public.engineer_p2p_parts_listings WHERE seller_engineer_user_id = auth.uid()
    )
    OR public.is_founder()
  );

DROP POLICY IF EXISTS p2p_bids_insert ON public.engineer_p2p_parts_bids;
CREATE POLICY p2p_bids_insert ON public.engineer_p2p_parts_bids
  FOR INSERT TO authenticated
  WITH CHECK (bidder_engineer_user_id = auth.uid());

-- ============================================================
-- TABLE 3: engineer_p2p_parts_transactions
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_p2p_parts_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid REFERENCES public.engineer_p2p_parts_listings(id) ON DELETE SET NULL,
  bid_id uuid REFERENCES public.engineer_p2p_parts_bids(id) ON DELETE SET NULL,
  seller_engineer_user_id uuid NOT NULL,
  buyer_engineer_user_id uuid NOT NULL,
  transaction_amount_rupees numeric NOT NULL CHECK (transaction_amount_rupees >= 0),
  platform_fee_rupees numeric NOT NULL DEFAULT 0 CHECK (platform_fee_rupees >= 0),
  transaction_status text NOT NULL DEFAULT 'pending_payment' CHECK (transaction_status IN (
    'pending_payment','escrow_held','shipped','delivered','disputed','refunded','complete','cancelled'
  )),
  shipped_at timestamptz,
  delivered_at timestamptz,
  completed_at timestamptz,
  evidence_uris text[] DEFAULT ARRAY[]::text[],
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_p2p_txn_seller ON public.engineer_p2p_parts_transactions(seller_engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_txn_buyer ON public.engineer_p2p_parts_transactions(buyer_engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_txn_status ON public.engineer_p2p_parts_transactions(transaction_status);
CREATE INDEX IF NOT EXISTS idx_p2p_txn_created ON public.engineer_p2p_parts_transactions(created_at DESC);

ALTER TABLE public.engineer_p2p_parts_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p2p_txn_select ON public.engineer_p2p_parts_transactions;
CREATE POLICY p2p_txn_select ON public.engineer_p2p_parts_transactions
  FOR SELECT TO authenticated
  USING (
    seller_engineer_user_id = auth.uid()
    OR buyer_engineer_user_id = auth.uid()
    OR public.is_founder()
  );

-- ============================================================
-- RPC 1: founder_engineer_p2p_marketplace_summary (founder, 16 KPIs)
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_engineer_p2p_marketplace_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_p2p_marketplace_summary()
RETURNS TABLE (
  total_listings bigint,
  active_listings bigint,
  reserved_listings bigint,
  sold_listings bigint,
  withdrawn_listings bigint,
  flagged_listings bigint,
  total_bids bigint,
  accepted_bids bigint,
  rejected_bids bigint,
  pending_bids bigint,
  total_transactions bigint,
  pending_payment_txn bigint,
  escrow_held_txn bigint,
  complete_txn bigint,
  total_transaction_volume_rupees numeric,
  avg_listing_price_rupees numeric,
  total_platform_fees_rupees numeric,
  top_part_category text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.engineer_p2p_parts_listings)::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_listings WHERE listing_status = 'active')::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_listings WHERE listing_status = 'reserved')::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_listings WHERE listing_status = 'sold')::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_listings WHERE listing_status = 'withdrawn')::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_listings WHERE listing_status = 'flagged')::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_bids)::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_bids WHERE bid_status = 'accepted')::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_bids WHERE bid_status = 'rejected')::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_bids WHERE bid_status = 'placed')::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_transactions)::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_transactions WHERE transaction_status = 'pending_payment')::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_transactions WHERE transaction_status = 'escrow_held')::bigint,
    (SELECT count(*) FROM public.engineer_p2p_parts_transactions WHERE transaction_status = 'complete')::bigint,
    COALESCE((SELECT sum(transaction_amount_rupees) FROM public.engineer_p2p_parts_transactions WHERE transaction_status IN ('complete','escrow_held','delivered','shipped')), 0)::numeric,
    COALESCE((SELECT avg(ask_price_rupees) FROM public.engineer_p2p_parts_listings WHERE listing_status = 'active'), 0)::numeric,
    COALESCE((SELECT sum(platform_fee_rupees) FROM public.engineer_p2p_parts_transactions WHERE transaction_status = 'complete'), 0)::numeric,
    COALESCE((
      SELECT part_category FROM public.engineer_p2p_parts_listings
      GROUP BY part_category ORDER BY count(*) DESC LIMIT 1
    ), 'n/a')::text;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_p2p_marketplace_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_p2p_marketplace_summary() TO authenticated;

-- ============================================================
-- RPC 2: founder_engineer_p2p_listings_recent
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_engineer_p2p_listings_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_engineer_p2p_listings_recent(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  seller_engineer_user_id uuid,
  part_category text,
  part_label text,
  manufacturer text,
  condition_band text,
  ask_price_rupees numeric,
  quantity_available int,
  listing_status text,
  listed_at timestamptz,
  expires_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT l.id, l.seller_engineer_user_id, l.part_category, l.part_label,
         l.manufacturer, l.condition_band, l.ask_price_rupees, l.quantity_available,
         l.listing_status, l.listed_at, l.expires_at
  FROM public.engineer_p2p_parts_listings l
  WHERE (p_status IS NULL OR l.listing_status = p_status)
  ORDER BY l.listed_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_p2p_listings_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_p2p_listings_recent(text, int) TO authenticated;

-- ============================================================
-- RPC 3: founder_engineer_p2p_transactions_recent
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_engineer_p2p_transactions_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_p2p_transactions_recent(
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  listing_id uuid,
  bid_id uuid,
  seller_engineer_user_id uuid,
  buyer_engineer_user_id uuid,
  transaction_amount_rupees numeric,
  platform_fee_rupees numeric,
  transaction_status text,
  shipped_at timestamptz,
  delivered_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT t.id, t.listing_id, t.bid_id, t.seller_engineer_user_id,
         t.buyer_engineer_user_id, t.transaction_amount_rupees, t.platform_fee_rupees,
         t.transaction_status, t.shipped_at, t.delivered_at, t.completed_at, t.created_at
  FROM public.engineer_p2p_parts_transactions t
  ORDER BY t.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_p2p_transactions_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_p2p_transactions_recent(int) TO authenticated;

-- ============================================================
-- RPC 4: engineer_p2p_create_listing (auth callable)
-- ============================================================
DROP FUNCTION IF EXISTS public.engineer_p2p_create_listing(text, text, text, text, text, numeric, int, text);
CREATE OR REPLACE FUNCTION public.engineer_p2p_create_listing(
  p_part_category text,
  p_part_label text,
  p_manufacturer text,
  p_model_compatibility text,
  p_condition_band text,
  p_ask_price_rupees numeric,
  p_quantity_available int,
  p_description text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.engineer_p2p_parts_listings (
    seller_engineer_user_id, part_category, part_label, manufacturer,
    model_compatibility, condition_band, ask_price_rupees, quantity_available, description
  ) VALUES (
    auth.uid(), p_part_category, p_part_label, p_manufacturer,
    p_model_compatibility, p_condition_band, p_ask_price_rupees,
    COALESCE(p_quantity_available, 1), p_description
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_p2p_create_listing(text, text, text, text, text, numeric, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_p2p_create_listing(text, text, text, text, text, numeric, int, text) TO authenticated;

-- ============================================================
-- RPC 5: engineer_p2p_place_bid (auth)
-- ============================================================
DROP FUNCTION IF EXISTS public.engineer_p2p_place_bid(uuid, numeric, text);
CREATE OR REPLACE FUNCTION public.engineer_p2p_place_bid(
  p_listing_id uuid,
  p_bid_amount_rupees numeric,
  p_bid_message text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_seller uuid;
  v_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='42501';
  END IF;

  SELECT seller_engineer_user_id, listing_status INTO v_seller, v_status
  FROM public.engineer_p2p_parts_listings WHERE id = p_listing_id;

  IF v_seller IS NULL THEN
    RAISE EXCEPTION 'listing not found' USING ERRCODE='P0002';
  END IF;
  IF v_seller = auth.uid() THEN
    RAISE EXCEPTION 'cannot bid on own listing' USING ERRCODE='42501';
  END IF;
  IF v_status <> 'active' THEN
    RAISE EXCEPTION 'listing not active' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.engineer_p2p_parts_bids (
    listing_id, bidder_engineer_user_id, bid_amount_rupees, bid_message
  ) VALUES (
    p_listing_id, auth.uid(), p_bid_amount_rupees, p_bid_message
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_p2p_place_bid(uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_p2p_place_bid(uuid, numeric, text) TO authenticated;

-- ============================================================
-- RPC 6: engineer_p2p_accept_bid (auth, seller only)
-- ============================================================
DROP FUNCTION IF EXISTS public.engineer_p2p_accept_bid(uuid);
CREATE OR REPLACE FUNCTION public.engineer_p2p_accept_bid(p_bid_id uuid)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_listing_id uuid;
  v_seller uuid;
  v_buyer uuid;
  v_amount numeric;
  v_txn_id uuid;
  v_fee numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='42501';
  END IF;

  SELECT b.listing_id, l.seller_engineer_user_id, b.bidder_engineer_user_id, b.bid_amount_rupees
  INTO v_listing_id, v_seller, v_buyer, v_amount
  FROM public.engineer_p2p_parts_bids b
  JOIN public.engineer_p2p_parts_listings l ON l.id = b.listing_id
  WHERE b.id = p_bid_id;

  IF v_seller IS NULL THEN
    RAISE EXCEPTION 'bid not found' USING ERRCODE='P0002';
  END IF;
  IF v_seller <> auth.uid() THEN
    RAISE EXCEPTION 'only seller can accept' USING ERRCODE='42501';
  END IF;

  v_fee := round(v_amount * 0.05, 2);

  UPDATE public.engineer_p2p_parts_bids
  SET bid_status = 'accepted', responded_at = now()
  WHERE id = p_bid_id;

  UPDATE public.engineer_p2p_parts_listings
  SET listing_status = 'reserved', updated_at = now()
  WHERE id = v_listing_id;

  INSERT INTO public.engineer_p2p_parts_transactions (
    listing_id, bid_id, seller_engineer_user_id, buyer_engineer_user_id,
    transaction_amount_rupees, platform_fee_rupees, transaction_status
  ) VALUES (
    v_listing_id, p_bid_id, v_seller, v_buyer, v_amount, v_fee, 'pending_payment'
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_p2p_accept_bid(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_p2p_accept_bid(uuid) TO authenticated;

-- ============================================================
-- RPC 7: engineer_p2p_my_listings + engineer_p2p_my_bids (auth, RLS-scoped)
-- ============================================================
DROP FUNCTION IF EXISTS public.engineer_p2p_my_listings();
CREATE OR REPLACE FUNCTION public.engineer_p2p_my_listings()
RETURNS TABLE (
  id uuid,
  part_category text,
  part_label text,
  ask_price_rupees numeric,
  listing_status text,
  listed_at timestamptz,
  expires_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT l.id, l.part_category, l.part_label, l.ask_price_rupees,
         l.listing_status, l.listed_at, l.expires_at
  FROM public.engineer_p2p_parts_listings l
  WHERE l.seller_engineer_user_id = auth.uid()
  ORDER BY l.listed_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_p2p_my_listings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_p2p_my_listings() TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_p2p_my_bids();
CREATE OR REPLACE FUNCTION public.engineer_p2p_my_bids()
RETURNS TABLE (
  id uuid,
  listing_id uuid,
  bid_amount_rupees numeric,
  bid_status text,
  placed_at timestamptz,
  responded_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT b.id, b.listing_id, b.bid_amount_rupees, b.bid_status, b.placed_at, b.responded_at
  FROM public.engineer_p2p_parts_bids b
  WHERE b.bidder_engineer_user_id = auth.uid()
  ORDER BY b.placed_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_p2p_my_bids() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_p2p_my_bids() TO authenticated;

-- ============================================================
-- RPC 8: log_founder_p2p_flag_listing (founder)
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_p2p_flag_listing(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_p2p_flag_listing(p_listing_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  UPDATE public.engineer_p2p_parts_listings
  SET listing_status = 'flagged', updated_at = now()
  WHERE id = p_listing_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_p2p_flag_listing(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_p2p_flag_listing(uuid) TO authenticated;

-- ============================================================
-- RPC 9: engineer_p2p_marketplace_expire_stale_listings (cron)
-- ============================================================
DROP FUNCTION IF EXISTS public.engineer_p2p_marketplace_expire_stale_listings();
CREATE OR REPLACE FUNCTION public.engineer_p2p_marketplace_expire_stale_listings()
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE public.engineer_p2p_parts_listings
  SET listing_status = 'withdrawn', updated_at = now()
  WHERE listing_status = 'active' AND expires_at < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;

  UPDATE public.engineer_p2p_parts_bids
  SET bid_status = 'expired', responded_at = now()
  WHERE bid_status = 'placed'
    AND listing_id IN (
      SELECT id FROM public.engineer_p2p_parts_listings WHERE listing_status = 'withdrawn'
    );

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_p2p_marketplace_expire_stale_listings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_p2p_marketplace_expire_stale_listings() TO authenticated;

COMMIT;