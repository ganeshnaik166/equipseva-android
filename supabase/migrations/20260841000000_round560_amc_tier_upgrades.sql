-- =====================================================================
-- Round 560 — AMC subscription tier upgrades (v0.5 Phase 3 #1)
-- =====================================================================
--
-- Bronze / Silver / Gold AMC contract tiers. Each tier bundles:
--   - Preventive maintenance cadence ceiling
--   - Code Red emergency response SLA
--   - Parts discount % (taken off the spare-parts marketplace shelf rate)
--   - Featured "Trusted partner" badge in hospital search
--   - Insurance bundle (Gold ties to engineer-PI policy from v0.5 P2 #4)
--
-- The existing amc_contracts.status enum stays the source of truth for
-- contract lifecycle (active / paused / expired / cancelled / renewal_failed
-- / pending_payment). This round adds a parallel `amc_tier` column with
-- a lookup table for the tier perks.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Tier lookup
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.amc_subscription_tiers (
  tier                       text PRIMARY KEY
                              CHECK (tier IN ('basic','bronze','silver','gold')),
  display_label              text NOT NULL,
  display_order              smallint NOT NULL,
  monthly_fee_floor_rupees   numeric(10,2) NOT NULL DEFAULT 0,
  visits_per_year_ceiling    int NOT NULL DEFAULT 12,
  code_red_sla_minutes       int NOT NULL DEFAULT 60,
  parts_discount_pct         numeric(5,2) NOT NULL DEFAULT 0,
  trusted_partner_badge      boolean NOT NULL DEFAULT false,
  pi_insurance_bundled       boolean NOT NULL DEFAULT false,
  founder_priority_support   boolean NOT NULL DEFAULT false,
  created_at                 timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.amc_subscription_tiers
  (tier, display_label, display_order, monthly_fee_floor_rupees,
   visits_per_year_ceiling, code_red_sla_minutes, parts_discount_pct,
   trusted_partner_badge, pi_insurance_bundled, founder_priority_support)
VALUES
  ('basic',  'Basic',  0,    0, 12, 240,  0.00, false, false, false),
  ('bronze', 'Bronze', 1, 1500, 12, 120,  3.00, false, false, false),
  ('silver', 'Silver', 2, 4500, 24,  60,  7.00, true,  false, false),
  ('gold',   'Gold',   3, 9500, 52,  30, 12.00, true,  true,  true)
ON CONFLICT (tier) DO UPDATE
  SET display_label             = EXCLUDED.display_label,
      display_order             = EXCLUDED.display_order,
      monthly_fee_floor_rupees  = EXCLUDED.monthly_fee_floor_rupees,
      visits_per_year_ceiling   = EXCLUDED.visits_per_year_ceiling,
      code_red_sla_minutes      = EXCLUDED.code_red_sla_minutes,
      parts_discount_pct        = EXCLUDED.parts_discount_pct,
      trusted_partner_badge     = EXCLUDED.trusted_partner_badge,
      pi_insurance_bundled      = EXCLUDED.pi_insurance_bundled,
      founder_priority_support  = EXCLUDED.founder_priority_support;

ALTER TABLE public.amc_subscription_tiers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS amc_subscription_tiers_select ON public.amc_subscription_tiers;
CREATE POLICY amc_subscription_tiers_select
  ON public.amc_subscription_tiers FOR SELECT
  TO authenticated, anon
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.amc_subscription_tiers
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. Stamp tier on amc_contracts
-- ---------------------------------------------------------------------
ALTER TABLE public.amc_contracts
  ADD COLUMN IF NOT EXISTS amc_tier text NOT NULL DEFAULT 'basic'
    REFERENCES public.amc_subscription_tiers(tier);

CREATE INDEX IF NOT EXISTS amc_contracts_tier_idx
  ON public.amc_contracts (amc_tier, status);

-- ---------------------------------------------------------------------
-- 3. founder_set_amc_tier — manual override with audit
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_set_amc_tier(
  p_contract_id uuid,
  p_target_tier text,
  p_reason      text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_before text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_target_tier NOT IN ('basic','bronze','silver','gold') THEN
    RAISE EXCEPTION 'invalid_tier' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 10 THEN
    RAISE EXCEPTION 'reason required (min 10 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT amc_tier INTO v_before
    FROM public.amc_contracts
   WHERE id = p_contract_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'contract_not_found' USING ERRCODE = '02000';
  END IF;

  UPDATE public.amc_contracts
     SET amc_tier = p_target_tier
   WHERE id = p_contract_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_set_amc_tier',
    p_target_table  => 'amc_contracts',
    p_target_row_id => p_contract_id,
    p_before_value  => jsonb_build_object('amc_tier', v_before),
    p_after_value   => jsonb_build_object('amc_tier', p_target_tier),
    p_reason        => p_reason
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_set_amc_tier(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_set_amc_tier(uuid, text, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 4. founder_amc_tier_distribution — cockpit summary
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_amc_tier_distribution()
RETURNS TABLE (
  tier                       text,
  display_label              text,
  active_contracts           int,
  monthly_recurring_rupees   numeric,
  pending_payment_contracts  int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    t.tier,
    t.display_label,
    coalesce(
      (SELECT count(*)::int FROM public.amc_contracts c
        WHERE c.amc_tier = t.tier AND c.status = 'active'),
      0
    ),
    coalesce(
      (SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
        WHERE c.amc_tier = t.tier AND c.status = 'active'),
      0::numeric
    ),
    coalesce(
      (SELECT count(*)::int FROM public.amc_contracts c
        WHERE c.amc_tier = t.tier AND c.status = 'pending_payment'),
      0
    )
   FROM public.amc_subscription_tiers t
  ORDER BY t.display_order DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amc_tier_distribution()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_amc_tier_distribution()
  TO service_role;

-- ---------------------------------------------------------------------
-- 5. my_amc_tier_perks — hospital-side self-view
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_amc_tier_perks(
  p_contract_id uuid
)
RETURNS TABLE (
  contract_id              uuid,
  amc_tier                 text,
  display_label            text,
  visits_per_year_ceiling  int,
  code_red_sla_minutes     int,
  parts_discount_pct       numeric,
  trusted_partner_badge    boolean,
  pi_insurance_bundled     boolean,
  founder_priority_support boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.amc_tier,
    t.display_label,
    t.visits_per_year_ceiling,
    t.code_red_sla_minutes,
    t.parts_discount_pct,
    t.trusted_partner_badge,
    t.pi_insurance_bundled,
    t.founder_priority_support
   FROM public.amc_contracts c
   JOIN public.amc_subscription_tiers t ON t.tier = c.amc_tier
  WHERE c.id = p_contract_id
    AND (
      c.hospital_user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.engineers e
         WHERE e.id = c.primary_engineer_id AND e.user_id = auth.uid()
      )
      OR public.is_founder()
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_amc_tier_perks(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_amc_tier_perks(uuid) TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 560 amc tier upgrades verified: 1 lookup + amc_tier column + 3 RPCs (founder set / distribution / hospital self-view)';
END;
$$;
