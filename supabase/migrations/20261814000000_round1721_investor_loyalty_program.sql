BEGIN;

-- =====================================================================
-- Round 1721 — Investor Loyalty Program
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.investor_loyalty_tiers_r1721 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  loyalty_tier text NOT NULL CHECK (loyalty_tier IN ('bronze','silver','gold','platinum')),
  total_invested_rupees bigint NOT NULL DEFAULT 0,
  years_since_first_check int NOT NULL DEFAULT 0,
  perks_unlocked_md text,
  last_recomputed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_loyalty_tiers_r1721_investor
  ON public.investor_loyalty_tiers_r1721(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv_loyalty_tiers_r1721_tier
  ON public.investor_loyalty_tiers_r1721(loyalty_tier);

CREATE TABLE IF NOT EXISTS public.investor_loyalty_perk_activations_r1721 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_id uuid NOT NULL REFERENCES public.investor_loyalty_tiers_r1721(id) ON DELETE CASCADE,
  perk_type text NOT NULL CHECK (perk_type IN ('early_access','special_meeting','anniversary_gift','founder_dinner','family_office_intro')),
  activated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  used boolean NOT NULL DEFAULT false,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_loyalty_perk_acts_r1721_tier
  ON public.investor_loyalty_perk_activations_r1721(tier_id);
CREATE INDEX IF NOT EXISTS idx_inv_loyalty_perk_acts_r1721_used
  ON public.investor_loyalty_perk_activations_r1721(used);

ALTER TABLE public.investor_loyalty_tiers_r1721 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_loyalty_perk_activations_r1721 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r1721_tiers ON public.investor_loyalty_tiers_r1721;
CREATE POLICY founder_all_r1721_tiers ON public.investor_loyalty_tiers_r1721
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r1721_perks ON public.investor_loyalty_perk_activations_r1721;
CREATE POLICY founder_all_r1721_perks ON public.investor_loyalty_perk_activations_r1721
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_tiers
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1721_list_tiers();
CREATE OR REPLACE FUNCTION public.r1721_list_tiers()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  loyalty_tier text,
  total_invested_rupees bigint,
  years_since_first_check int,
  perks_unlocked_md text,
  last_recomputed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.investor_id, p.email::text, t.loyalty_tier, t.total_invested_rupees,
         t.years_since_first_check, t.perks_unlocked_md, t.last_recomputed_at
  FROM public.investor_loyalty_tiers_r1721 t
  LEFT JOIN public.profiles p ON p.id = t.investor_id
  ORDER BY t.total_invested_rupees DESC NULLS LAST;
END;
$$;

-- =====================================================================
-- RPC 2: compute_tier (write)
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1721_compute_tier(uuid, bigint, int, text);
CREATE OR REPLACE FUNCTION public.r1721_compute_tier(
  p_investor_id uuid,
  p_total_invested_rupees bigint,
  p_years_since_first_check int,
  p_perks_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tier text;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_tier := CASE
    WHEN p_total_invested_rupees >= 10000000 AND p_years_since_first_check >= 3 THEN 'platinum'
    WHEN p_total_invested_rupees >= 5000000  AND p_years_since_first_check >= 2 THEN 'gold'
    WHEN p_total_invested_rupees >= 2000000  AND p_years_since_first_check >= 1 THEN 'silver'
    ELSE 'bronze'
  END;

  INSERT INTO public.investor_loyalty_tiers_r1721(
    investor_id, loyalty_tier, total_invested_rupees,
    years_since_first_check, perks_unlocked_md, last_recomputed_at
  )
  VALUES (p_investor_id, v_tier, p_total_invested_rupees, p_years_since_first_check, p_perks_md, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1721_compute_tier',
    jsonb_build_object('tier_id', v_id, 'investor_id', p_investor_id, 'tier', v_tier)
  );

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_perks
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1721_list_perks();
CREATE OR REPLACE FUNCTION public.r1721_list_perks()
RETURNS TABLE (
  id uuid,
  tier_id uuid,
  investor_id uuid,
  loyalty_tier text,
  perk_type text,
  activated_at timestamptz,
  expires_at timestamptz,
  used boolean,
  used_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.tier_id, t.investor_id, t.loyalty_tier, a.perk_type,
         a.activated_at, a.expires_at, a.used, a.used_at
  FROM public.investor_loyalty_perk_activations_r1721 a
  JOIN public.investor_loyalty_tiers_r1721 t ON t.id = a.tier_id
  ORDER BY a.activated_at DESC;
END;
$$;

-- =====================================================================
-- RPC 4: activate_perk (write)
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1721_activate_perk(uuid, text, timestamptz);
CREATE OR REPLACE FUNCTION public.r1721_activate_perk(
  p_tier_id uuid,
  p_perk_type text,
  p_expires_at timestamptz
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

  INSERT INTO public.investor_loyalty_perk_activations_r1721(
    tier_id, perk_type, activated_at, expires_at, used
  )
  VALUES (p_tier_id, p_perk_type, now(), p_expires_at, false)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1721_activate_perk',
    jsonb_build_object('activation_id', v_id, 'tier_id', p_tier_id, 'perk_type', p_perk_type)
  );

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5: mark_perk_used (write)
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1721_mark_perk_used(uuid);
CREATE OR REPLACE FUNCTION public.r1721_mark_perk_used(
  p_activation_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.investor_loyalty_perk_activations_r1721
  SET used = true, used_at = now(), updated_at = now()
  WHERE id = p_activation_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1721_mark_perk_used',
    jsonb_build_object('activation_id', p_activation_id)
  );
END;
$$;

-- =====================================================================
-- RPC 6: tier_distribution
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1721_tier_distribution();
CREATE OR REPLACE FUNCTION public.r1721_tier_distribution()
RETURNS TABLE (
  loyalty_tier text,
  investor_count int,
  total_invested_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.loyalty_tier,
         (COUNT(*))::int AS investor_count,
         COALESCE(SUM(t.total_invested_rupees), 0)::bigint AS total_invested_rupees
  FROM public.investor_loyalty_tiers_r1721 t
  GROUP BY t.loyalty_tier
  ORDER BY t.loyalty_tier;
END;
$$;

-- =====================================================================
-- RPC 7: unused_perks_per_investor
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1721_unused_perks_per_investor();
CREATE OR REPLACE FUNCTION public.r1721_unused_perks_per_investor()
RETURNS TABLE (
  investor_id uuid,
  investor_email text,
  loyalty_tier text,
  unused_perks int,
  total_perks int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.investor_id,
         p.email::text,
         t.loyalty_tier,
         (COUNT(*) FILTER (WHERE a.used = false))::int AS unused_perks,
         (COUNT(a.id))::int AS total_perks
  FROM public.investor_loyalty_tiers_r1721 t
  LEFT JOIN public.investor_loyalty_perk_activations_r1721 a ON a.tier_id = t.id
  LEFT JOIN public.profiles p ON p.id = t.investor_id
  GROUP BY t.investor_id, p.email, t.loyalty_tier
  ORDER BY unused_perks DESC;
END;
$$;

-- =====================================================================
-- GRANTS
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.r1721_list_tiers() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1721_list_tiers() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1721_compute_tier(uuid, bigint, int, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1721_compute_tier(uuid, bigint, int, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1721_list_perks() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1721_list_perks() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1721_activate_perk(uuid, text, timestamptz) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1721_activate_perk(uuid, text, timestamptz) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1721_mark_perk_used(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1721_mark_perk_used(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1721_tier_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1721_tier_distribution() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1721_unused_perks_per_investor() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1721_unused_perks_per_investor() TO authenticated;

COMMIT;