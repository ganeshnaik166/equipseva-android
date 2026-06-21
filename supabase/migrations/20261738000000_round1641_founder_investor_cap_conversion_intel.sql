BEGIN;

-- =========================================================================
-- r1641 — Founder Investor Cap Conversion Intel
-- SAFEs converting to equity in next round; per-SAFE conversion math
-- (cap/discount/MFN); founder verifies before round closes.
-- =========================================================================

-- ---------------------------------------------------------------------
-- TABLE: founder_investor_safes
-- One row per outstanding SAFE held by an investor.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_investor_safes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_email text,
  principal_rupees bigint NOT NULL CHECK (principal_rupees > 0),
  signed_at timestamptz NOT NULL DEFAULT now(),
  valuation_cap_rupees bigint,                -- post-money cap (₹). NULL = uncapped
  discount_pct numeric(5,2) CHECK (discount_pct IS NULL OR (discount_pct >= 0 AND discount_pct <= 50)),
  mfn_flag boolean NOT NULL DEFAULT false,    -- most-favored-nation
  status text NOT NULL DEFAULT 'outstanding'
    CHECK (status IN ('outstanding','converted','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_investor_safes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_safes ON public.founder_investor_safes;
CREATE POLICY founder_only_safes
  ON public.founder_investor_safes
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_investor_safes FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON public.founder_investor_safes TO authenticated;

-- ---------------------------------------------------------------------
-- TABLE: founder_investor_cap_rounds
-- Proposed/active priced round used for conversion preview.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_investor_cap_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_name text NOT NULL,                   -- e.g. 'Seed 2026 Q3'
  premoney_valuation_rupees bigint NOT NULL CHECK (premoney_valuation_rupees > 0),
  new_money_rupees bigint NOT NULL CHECK (new_money_rupees > 0),
  new_share_price_rupees numeric(20,6) NOT NULL CHECK (new_share_price_rupees > 0),
  pre_round_shares bigint NOT NULL CHECK (pre_round_shares > 0),
  status text NOT NULL DEFAULT 'proposed'
    CHECK (status IN ('proposed','active','closed')),
  founder_verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_investor_cap_rounds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_cap_rounds ON public.founder_investor_cap_rounds;
CREATE POLICY founder_only_cap_rounds
  ON public.founder_investor_cap_rounds
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_investor_cap_rounds FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON public.founder_investor_cap_rounds TO authenticated;

-- ---------------------------------------------------------------------
-- LOG HELPER
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_founder_cap_conversion_op(
  p_op text,
  p_after jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, p_after, now());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_cap_conversion_op(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cap_conversion_op(text, jsonb) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 1: list_safes — outstanding + converted SAFEs
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_cap_list_safes()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_email text,
  principal_rupees bigint,
  signed_at timestamptz,
  valuation_cap_rupees bigint,
  discount_pct numeric,
  mfn_flag boolean,
  status text,
  age_days int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.investor_name,
    s.investor_email,
    s.principal_rupees,
    s.signed_at,
    s.valuation_cap_rupees,
    s.discount_pct,
    s.mfn_flag,
    s.status,
    EXTRACT(day FROM (now() - s.signed_at))::int AS age_days
  FROM public.founder_investor_safes s
  ORDER BY s.status, s.signed_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_list_safes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_list_safes() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 2: list_rounds — proposed/active/closed priced rounds
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_cap_list_rounds()
RETURNS TABLE (
  id uuid,
  round_name text,
  premoney_valuation_rupees bigint,
  new_money_rupees bigint,
  new_share_price_rupees numeric,
  pre_round_shares bigint,
  status text,
  founder_verified_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.round_name,
    r.premoney_valuation_rupees,
    r.new_money_rupees,
    r.new_share_price_rupees,
    r.pre_round_shares,
    r.status,
    r.founder_verified_at,
    r.created_at
  FROM public.founder_investor_cap_rounds r
  ORDER BY r.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_list_rounds() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_list_rounds() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 3: conversion_preview — per-SAFE conversion math (cap/discount/MFN)
-- For each outstanding SAFE, compute the effective price:
--   cap_price     = valuation_cap / pre_round_shares
--   discount_price= new_share_price * (1 - discount/100)
--   mfn_price     = best discount among other MFN-eligible SAFEs (simplified: lowest discount_price across MFN flag set; here = discount_price)
--   conversion_price = min(non-null of {cap_price, discount_price, new_share_price})
--   shares_issued = floor(principal / conversion_price)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_cap_conversion_preview(
  p_round_id uuid
)
RETURNS TABLE (
  safe_id uuid,
  investor_name text,
  principal_rupees bigint,
  cap_price numeric,
  discount_price numeric,
  new_share_price numeric,
  conversion_price numeric,
  price_source text,
  shares_issued bigint,
  ownership_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_price numeric;
  v_pre_shares bigint;
  v_total_post_shares bigint;
  v_new_money_shares bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT new_share_price_rupees, pre_round_shares,
         (new_money_rupees / new_share_price_rupees)::bigint
    INTO v_new_price, v_pre_shares, v_new_money_shares
  FROM public.founder_investor_cap_rounds
  WHERE id = p_round_id;

  IF v_new_price IS NULL THEN
    RETURN;
  END IF;

  -- estimate total post shares for ownership pct: pre + new money + safe converted shares estimate
  WITH safe_calc AS (
    SELECT
      s.id AS safe_id,
      s.investor_name,
      s.principal_rupees,
      CASE WHEN s.valuation_cap_rupees IS NOT NULL
           THEN s.valuation_cap_rupees::numeric / v_pre_shares
           ELSE NULL END AS cap_price,
      CASE WHEN s.discount_pct IS NOT NULL
           THEN v_new_price * (1 - s.discount_pct/100)
           ELSE NULL END AS discount_price
    FROM public.founder_investor_safes s
    WHERE s.status = 'outstanding'
  ),
  priced AS (
    SELECT
      sc.*,
      LEAST(
        COALESCE(sc.cap_price, v_new_price),
        COALESCE(sc.discount_price, v_new_price),
        v_new_price
      ) AS conv_price
    FROM safe_calc sc
  ),
  total_safe_shares AS (
    SELECT COALESCE(SUM(FLOOR(p.principal_rupees / p.conv_price))::bigint, 0) AS s
    FROM priced p
  )
  SELECT v_pre_shares + v_new_money_shares + (SELECT s FROM total_safe_shares)
    INTO v_total_post_shares;

  RETURN QUERY
  SELECT
    p.safe_id,
    p.investor_name,
    p.principal_rupees,
    p.cap_price,
    p.discount_price,
    v_new_price AS new_share_price,
    p.conv_price AS conversion_price,
    CASE
      WHEN p.conv_price = p.cap_price THEN 'cap'
      WHEN p.conv_price = p.discount_price THEN 'discount'
      ELSE 'new_price'
    END AS price_source,
    FLOOR(p.principal_rupees / p.conv_price)::bigint AS shares_issued,
    ROUND(
      (FLOOR(p.principal_rupees / p.conv_price)::numeric
        / NULLIF(v_total_post_shares, 0)) * 100,
      4
    ) AS ownership_pct
  FROM priced p
  ORDER BY p.principal_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_conversion_preview(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_conversion_preview(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 4: dilution_summary — pre/post ownership for founders + investors
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_cap_dilution_summary(
  p_round_id uuid
)
RETURNS TABLE (
  bucket text,
  shares bigint,
  pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_price numeric;
  v_pre_shares bigint;
  v_new_money_shares bigint;
  v_safe_shares bigint;
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT new_share_price_rupees, pre_round_shares,
         (new_money_rupees / new_share_price_rupees)::bigint
    INTO v_new_price, v_pre_shares, v_new_money_shares
  FROM public.founder_investor_cap_rounds
  WHERE id = p_round_id;

  IF v_new_price IS NULL THEN
    RETURN;
  END IF;

  WITH safe_calc AS (
    SELECT
      s.principal_rupees,
      LEAST(
        COALESCE(s.valuation_cap_rupees::numeric / v_pre_shares, v_new_price),
        COALESCE(v_new_price * (1 - COALESCE(s.discount_pct,0)/100), v_new_price),
        v_new_price
      ) AS conv_price
    FROM public.founder_investor_safes s
    WHERE s.status = 'outstanding'
  )
  SELECT COALESCE(SUM(FLOOR(principal_rupees / conv_price))::bigint, 0)
    INTO v_safe_shares FROM safe_calc;

  v_total := v_pre_shares + v_new_money_shares + v_safe_shares;

  RETURN QUERY
  SELECT 'pre_round_shareholders'::text, v_pre_shares,
         ROUND((v_pre_shares::numeric / NULLIF(v_total,0)) * 100, 4)
  UNION ALL
  SELECT 'new_money_investors'::text, v_new_money_shares,
         ROUND((v_new_money_shares::numeric / NULLIF(v_total,0)) * 100, 4)
  UNION ALL
  SELECT 'safe_converters'::text, v_safe_shares,
         ROUND((v_safe_shares::numeric / NULLIF(v_total,0)) * 100, 4);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_dilution_summary(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_dilution_summary(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 5: mfn_risk — flag SAFEs whose MFN clause could force re-pricing
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_cap_mfn_risk()
RETURNS TABLE (
  safe_id uuid,
  investor_name text,
  principal_rupees bigint,
  current_discount_pct numeric,
  best_other_discount_pct numeric,
  mfn_upgrade boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_best numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT MAX(discount_pct) INTO v_best
  FROM public.founder_investor_safes
  WHERE status = 'outstanding';

  RETURN QUERY
  SELECT
    s.id,
    s.investor_name,
    s.principal_rupees,
    COALESCE(s.discount_pct, 0)::numeric,
    COALESCE(v_best, 0)::numeric,
    (s.mfn_flag AND COALESCE(v_best,0) > COALESCE(s.discount_pct,0))
  FROM public.founder_investor_safes s
  WHERE s.status = 'outstanding' AND s.mfn_flag = true
  ORDER BY s.principal_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_mfn_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_mfn_risk() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 6: verify_round — founder confirms math before round closes
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_cap_verify_round(
  p_round_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.founder_investor_cap_rounds
  SET founder_verified_at = now(),
      status = 'active'
  WHERE id = p_round_id;

  PERFORM public.log_founder_cap_conversion_op(
    'cap_verify_round',
    jsonb_build_object('round_id', p_round_id)
  );

  RETURN p_round_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_verify_round(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_verify_round(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 7: capital_overview — totals across all outstanding SAFEs
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_cap_capital_overview()
RETURNS TABLE (
  outstanding_count int,
  outstanding_principal_rupees bigint,
  capped_count int,
  uncapped_count int,
  mfn_count int,
  oldest_signed_at timestamptz,
  newest_signed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE status='outstanding'))::int,
    COALESCE(SUM(principal_rupees) FILTER (WHERE status='outstanding'), 0)::bigint,
    (COUNT(*) FILTER (WHERE status='outstanding' AND valuation_cap_rupees IS NOT NULL))::int,
    (COUNT(*) FILTER (WHERE status='outstanding' AND valuation_cap_rupees IS NULL))::int,
    (COUNT(*) FILTER (WHERE status='outstanding' AND mfn_flag=true))::int,
    MIN(signed_at) FILTER (WHERE status='outstanding'),
    MAX(signed_at) FILTER (WHERE status='outstanding')
  FROM public.founder_investor_safes;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_capital_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_capital_overview() TO authenticated;

COMMIT;