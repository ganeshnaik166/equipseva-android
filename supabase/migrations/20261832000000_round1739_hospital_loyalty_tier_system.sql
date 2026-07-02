BEGIN;

-- ============================================================
-- Round 1739: Hospital Loyalty Tier System
-- ============================================================

CREATE TABLE IF NOT EXISTS public.hospital_loyalty_tiers_r1739 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  loyalty_tier text NOT NULL CHECK (loyalty_tier IN ('bronze','silver','gold','platinum')),
  years_active int NOT NULL DEFAULT 0,
  total_spend_rupees bigint NOT NULL DEFAULT 0,
  last_assessed_at timestamptz,
  perks_unlocked_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hltr1739_hospital ON public.hospital_loyalty_tiers_r1739(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hltr1739_tier ON public.hospital_loyalty_tiers_r1739(loyalty_tier);

CREATE TABLE IF NOT EXISTS public.hospital_loyalty_perk_activations_r1739 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_id uuid NOT NULL REFERENCES public.hospital_loyalty_tiers_r1739(id) ON DELETE CASCADE,
  perk_type text NOT NULL CHECK (perk_type IN ('waiver','priority_dispatch','free_loaner','extended_warranty','founder_call')),
  activated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  used boolean NOT NULL DEFAULT false,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hlpa1739_tier ON public.hospital_loyalty_perk_activations_r1739(tier_id);
CREATE INDEX IF NOT EXISTS idx_hlpa1739_perk ON public.hospital_loyalty_perk_activations_r1739(perk_type);

ALTER TABLE public.hospital_loyalty_tiers_r1739 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_loyalty_perk_activations_r1739 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hltr1739 ON public.hospital_loyalty_tiers_r1739;
CREATE POLICY founder_all_hltr1739 ON public.hospital_loyalty_tiers_r1739
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hlpa1739 ON public.hospital_loyalty_perk_activations_r1739;
CREATE POLICY founder_all_hlpa1739 ON public.hospital_loyalty_perk_activations_r1739
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_loyalty_tiers_r1739()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  loyalty_tier text,
  years_active int,
  total_spend_rupees bigint,
  last_assessed_at timestamptz,
  perks_unlocked_md text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_user_id, p.email, t.loyalty_tier, t.years_active,
         t.total_spend_rupees, t.last_assessed_at, t.perks_unlocked_md, t.created_at
  FROM public.hospital_loyalty_tiers_r1739 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_user_id
  ORDER BY t.total_spend_rupees DESC NULLS LAST, t.created_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.assess_loyalty_tier_r1739(
  p_hospital_user_id uuid,
  p_years int,
  p_spend_rupees bigint
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

  IF p_years >= 5 AND p_spend_rupees >= 10000000 THEN
    v_tier := 'platinum';
  ELSIF p_years >= 3 AND p_spend_rupees >= 5000000 THEN
    v_tier := 'gold';
  ELSIF p_years >= 2 AND p_spend_rupees >= 2000000 THEN
    v_tier := 'silver';
  ELSE
    v_tier := 'bronze';
  END IF;

  INSERT INTO public.hospital_loyalty_tiers_r1739(
    hospital_user_id, loyalty_tier, years_active, total_spend_rupees, last_assessed_at
  )
  VALUES (p_hospital_user_id, v_tier, p_years, p_spend_rupees, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'assess_loyalty_tier_r1739',
    jsonb_build_object('id', v_id, 'tier', v_tier, 'hospital_user_id', p_hospital_user_id)
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_loyalty_perks_r1739()
RETURNS TABLE (
  id uuid,
  tier_id uuid,
  loyalty_tier text,
  hospital_email text,
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
  SELECT a.id, a.tier_id, t.loyalty_tier, p.email, a.perk_type,
         a.activated_at, a.expires_at, a.used, a.used_at
  FROM public.hospital_loyalty_perk_activations_r1739 a
  JOIN public.hospital_loyalty_tiers_r1739 t ON t.id = a.tier_id
  LEFT JOIN public.profiles p ON p.id = t.hospital_user_id
  ORDER BY a.activated_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.activate_loyalty_perk_r1739(
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

  INSERT INTO public.hospital_loyalty_perk_activations_r1739(
    tier_id, perk_type, expires_at
  )
  VALUES (p_tier_id, p_perk_type, p_expires_at)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'activate_loyalty_perk_r1739',
    jsonb_build_object('id', v_id, 'tier_id', p_tier_id, 'perk_type', p_perk_type)
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_loyalty_perk_used_r1739(p_perk_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.hospital_loyalty_perk_activations_r1739
  SET used = true, used_at = now(), updated_at = now()
  WHERE id = p_perk_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_loyalty_perk_used_r1739',
    jsonb_build_object('perk_id', p_perk_id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.loyalty_tier_distribution_r1739()
RETURNS TABLE (
  loyalty_tier text,
  hospital_count int,
  total_spend_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.loyalty_tier,
         (COUNT(*) FILTER (WHERE t.loyalty_tier IS NOT NULL))::int AS hospital_count,
         COALESCE(SUM(t.total_spend_rupees), 0)::bigint AS total_spend_rupees
  FROM public.hospital_loyalty_tiers_r1739 t
  GROUP BY t.loyalty_tier
  ORDER BY
    CASE t.loyalty_tier
      WHEN 'platinum' THEN 1
      WHEN 'gold' THEN 2
      WHEN 'silver' THEN 3
      WHEN 'bronze' THEN 4
      ELSE 5
    END;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_loyal_hospitals_r1739()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  loyalty_tier text,
  years_active int,
  total_spend_rupees bigint,
  perks_activated int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.hospital_user_id,
         p.email,
         t.loyalty_tier,
         t.years_active,
         t.total_spend_rupees,
         (COUNT(a.id) FILTER (WHERE a.id IS NOT NULL))::int AS perks_activated
  FROM public.hospital_loyalty_tiers_r1739 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_user_id
  LEFT JOIN public.hospital_loyalty_perk_activations_r1739 a ON a.tier_id = t.id
  GROUP BY t.hospital_user_id, p.email, t.loyalty_tier, t.years_active, t.total_spend_rupees
  ORDER BY t.total_spend_rupees DESC NULLS LAST
  LIMIT 50;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.list_loyalty_tiers_r1739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loyalty_tiers_r1739() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.assess_loyalty_tier_r1739(uuid, int, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assess_loyalty_tier_r1739(uuid, int, bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_loyalty_perks_r1739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loyalty_perks_r1739() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.activate_loyalty_perk_r1739(uuid, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activate_loyalty_perk_r1739(uuid, text, timestamptz) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_loyalty_perk_used_r1739(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_loyalty_perk_used_r1739(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.loyalty_tier_distribution_r1739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.loyalty_tier_distribution_r1739() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_loyal_hospitals_r1739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_loyal_hospitals_r1739() TO authenticated;

COMMIT;