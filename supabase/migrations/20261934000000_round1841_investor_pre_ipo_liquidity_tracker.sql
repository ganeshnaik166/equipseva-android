BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_pre_ipo_liquidity_offers_r1841 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  instrument_type text NOT NULL CHECK (instrument_type IN ('equity_shares','options','safe','warrant')),
  shares_offered bigint NOT NULL CHECK (shares_offered > 0),
  price_per_share_rupees numeric(14,2) NOT NULL CHECK (price_per_share_rupees >= 0),
  valuation_implied_rupees bigint NOT NULL CHECK (valuation_implied_rupees >= 0),
  status text NOT NULL DEFAULT 'offered' CHECK (status IN ('offered','accepted','declined','expired')),
  offer_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_liquidity_secondary_buyers_r1841 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id uuid NOT NULL REFERENCES public.investor_pre_ipo_liquidity_offers_r1841(id) ON DELETE CASCADE,
  buyer_name text NOT NULL,
  buyer_type text NOT NULL CHECK (buyer_type IN ('founder','employee','fund','family_office','strategic')),
  buyer_amount_rupees bigint NOT NULL CHECK (buyer_amount_rupees >= 0),
  accepted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pre_ipo_offers_r1841_status ON public.investor_pre_ipo_liquidity_offers_r1841(status);
CREATE INDEX IF NOT EXISTS idx_pre_ipo_offers_r1841_investor ON public.investor_pre_ipo_liquidity_offers_r1841(investor_id);
CREATE INDEX IF NOT EXISTS idx_pre_ipo_buyers_r1841_offer ON public.investor_liquidity_secondary_buyers_r1841(offer_id);

ALTER TABLE public.investor_pre_ipo_liquidity_offers_r1841 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_liquidity_secondary_buyers_r1841 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pre_ipo_offers_r1841 ON public.investor_pre_ipo_liquidity_offers_r1841;
CREATE POLICY founder_all_pre_ipo_offers_r1841 ON public.investor_pre_ipo_liquidity_offers_r1841
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_pre_ipo_buyers_r1841 ON public.investor_liquidity_secondary_buyers_r1841;
CREATE POLICY founder_all_pre_ipo_buyers_r1841 ON public.investor_liquidity_secondary_buyers_r1841
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_offers
CREATE OR REPLACE FUNCTION public.list_pre_ipo_offers_r1841()
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_email text,
  instrument_type text,
  shares_offered bigint,
  price_per_share_rupees numeric,
  valuation_implied_rupees bigint,
  status text,
  offer_at timestamptz,
  decided_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.investor_id, p.email, o.instrument_type, o.shares_offered,
           o.price_per_share_rupees, o.valuation_implied_rupees, o.status,
           o.offer_at, o.decided_at
    FROM public.investor_pre_ipo_liquidity_offers_r1841 o
    LEFT JOIN public.profiles p ON p.id = o.investor_id
    ORDER BY o.offer_at DESC;
END $$;

-- 2. log_offer
CREATE OR REPLACE FUNCTION public.log_pre_ipo_offer_r1841(
  p_investor_id uuid,
  p_instrument_type text,
  p_shares_offered bigint,
  p_price_per_share_rupees numeric,
  p_valuation_implied_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_pre_ipo_liquidity_offers_r1841(
    investor_id, instrument_type, shares_offered,
    price_per_share_rupees, valuation_implied_rupees
  ) VALUES (
    p_investor_id, p_instrument_type, p_shares_offered,
    p_price_per_share_rupees, p_valuation_implied_rupees
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pre_ipo_offer_r1841',
    jsonb_build_object('offer_id', v_id, 'investor_id', p_investor_id,
                       'shares_offered', p_shares_offered));
  RETURN v_id;
END $$;

-- 3. list_buyers
CREATE OR REPLACE FUNCTION public.list_pre_ipo_buyers_r1841(p_offer_id uuid)
RETURNS TABLE(
  id uuid,
  offer_id uuid,
  buyer_name text,
  buyer_type text,
  buyer_amount_rupees bigint,
  accepted_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.offer_id, b.buyer_name, b.buyer_type, b.buyer_amount_rupees, b.accepted_at
    FROM public.investor_liquidity_secondary_buyers_r1841 b
    WHERE b.offer_id = p_offer_id
    ORDER BY b.created_at DESC;
END $$;

-- 4. log_buyer
CREATE OR REPLACE FUNCTION public.log_pre_ipo_buyer_r1841(
  p_offer_id uuid,
  p_buyer_name text,
  p_buyer_type text,
  p_buyer_amount_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_liquidity_secondary_buyers_r1841(
    offer_id, buyer_name, buyer_type, buyer_amount_rupees, accepted_at
  ) VALUES (
    p_offer_id, p_buyer_name, p_buyer_type, p_buyer_amount_rupees, now()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pre_ipo_buyer_r1841',
    jsonb_build_object('buyer_id', v_id, 'offer_id', p_offer_id,
                       'buyer_name', p_buyer_name, 'amount', p_buyer_amount_rupees));
  RETURN v_id;
END $$;

-- 5. mark_decision
CREATE OR REPLACE FUNCTION public.mark_pre_ipo_decision_r1841(
  p_offer_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('offered','accepted','declined','expired') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.investor_pre_ipo_liquidity_offers_r1841
    SET status = p_status,
        decided_at = CASE WHEN p_status IN ('accepted','declined','expired') THEN now() ELSE decided_at END,
        updated_at = now()
    WHERE id = p_offer_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_pre_ipo_decision_r1841',
    jsonb_build_object('offer_id', p_offer_id, 'status', p_status));
END $$;

-- 6. total_secondary_volume
CREATE OR REPLACE FUNCTION public.total_pre_ipo_secondary_volume_r1841()
RETURNS TABLE(
  total_offers int,
  total_buyers int,
  total_volume_rupees bigint,
  accepted_offers int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*) FROM public.investor_pre_ipo_liquidity_offers_r1841)::int,
      (SELECT COUNT(*) FROM public.investor_liquidity_secondary_buyers_r1841)::int,
      COALESCE((SELECT SUM(buyer_amount_rupees) FROM public.investor_liquidity_secondary_buyers_r1841), 0)::bigint,
      (SELECT COUNT(*) FROM public.investor_pre_ipo_liquidity_offers_r1841 WHERE status = 'accepted')::int;
END $$;

-- 7. recent_secondaries
CREATE OR REPLACE FUNCTION public.recent_pre_ipo_secondaries_r1841()
RETURNS TABLE(
  buyer_id uuid,
  offer_id uuid,
  buyer_name text,
  buyer_type text,
  buyer_amount_rupees bigint,
  accepted_at timestamptz,
  instrument_type text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.offer_id, b.buyer_name, b.buyer_type, b.buyer_amount_rupees,
           b.accepted_at, o.instrument_type
    FROM public.investor_liquidity_secondary_buyers_r1841 b
    JOIN public.investor_pre_ipo_liquidity_offers_r1841 o ON o.id = b.offer_id
    ORDER BY b.created_at DESC
    LIMIT 25;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_pre_ipo_offers_r1841() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pre_ipo_offer_r1841(uuid, text, bigint, numeric, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_pre_ipo_buyers_r1841(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pre_ipo_buyer_r1841(uuid, text, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_pre_ipo_decision_r1841(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.total_pre_ipo_secondary_volume_r1841() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_pre_ipo_secondaries_r1841() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pre_ipo_offers_r1841() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pre_ipo_offer_r1841(uuid, text, bigint, numeric, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pre_ipo_buyers_r1841(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pre_ipo_buyer_r1841(uuid, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_pre_ipo_decision_r1841(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.total_pre_ipo_secondary_volume_r1841() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_pre_ipo_secondaries_r1841() TO authenticated;

COMMIT;