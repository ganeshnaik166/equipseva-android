BEGIN;

-- =============================================================================
-- r1652 — Founder Hospital Chain Master Contracts
-- Parent-chain agreements covering multiple hospital locations, with per-chain
-- inclusion/exclusion lists and rate-card binding.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Table 1: hospital_chain_master_contracts
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_chain_master_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  parent_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  contract_code text UNIQUE,
  master_tier text NOT NULL CHECK (master_tier IN ('bronze','silver','gold','platinum')),
  rate_card_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  effective_from date NOT NULL DEFAULT CURRENT_DATE,
  effective_to date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','active','suspended','terminated')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcmc_status ON public.hospital_chain_master_contracts(status);
CREATE INDEX IF NOT EXISTS idx_hcmc_parent ON public.hospital_chain_master_contracts(parent_org_id);

ALTER TABLE public.hospital_chain_master_contracts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcmc_founder_only ON public.hospital_chain_master_contracts;
CREATE POLICY hcmc_founder_only ON public.hospital_chain_master_contracts
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- -----------------------------------------------------------------------------
-- Table 2: hospital_chain_membership (inclusion/exclusion list per chain)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_chain_membership (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_contract_id uuid NOT NULL REFERENCES public.hospital_chain_master_contracts(id) ON DELETE CASCADE,
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  membership_kind text NOT NULL DEFAULT 'included' CHECK (membership_kind IN ('included','excluded')),
  binding_rate_card_override jsonb,
  added_at timestamptz NOT NULL DEFAULT now(),
  removed_at timestamptz,
  notes text,
  UNIQUE (chain_contract_id, hospital_org_id)
);

CREATE INDEX IF NOT EXISTS idx_hcm_chain ON public.hospital_chain_membership(chain_contract_id);
CREATE INDEX IF NOT EXISTS idx_hcm_hospital ON public.hospital_chain_membership(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_hcm_kind ON public.hospital_chain_membership(membership_kind);

ALTER TABLE public.hospital_chain_membership ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcm_founder_only ON public.hospital_chain_membership;
CREATE POLICY hcm_founder_only ON public.hospital_chain_membership
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================================
-- RPC 1 (READ): get_chain_master_overview
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_chain_master_overview()
RETURNS TABLE (
  total_chains int,
  active_chains int,
  suspended_chains int,
  draft_chains int,
  total_included_locations int,
  total_excluded_locations int,
  platinum_chains int,
  gold_chains int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.hospital_chain_master_contracts),
    (SELECT (COUNT(*) FILTER (WHERE status = 'active'))::int FROM public.hospital_chain_master_contracts),
    (SELECT (COUNT(*) FILTER (WHERE status = 'suspended'))::int FROM public.hospital_chain_master_contracts),
    (SELECT (COUNT(*) FILTER (WHERE status = 'draft'))::int FROM public.hospital_chain_master_contracts),
    (SELECT (COUNT(*) FILTER (WHERE membership_kind = 'included' AND removed_at IS NULL))::int FROM public.hospital_chain_membership),
    (SELECT (COUNT(*) FILTER (WHERE membership_kind = 'excluded' AND removed_at IS NULL))::int FROM public.hospital_chain_membership),
    (SELECT (COUNT(*) FILTER (WHERE master_tier = 'platinum'))::int FROM public.hospital_chain_master_contracts),
    (SELECT (COUNT(*) FILTER (WHERE master_tier = 'gold'))::int FROM public.hospital_chain_master_contracts);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_chain_master_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_chain_master_overview() TO authenticated;

-- =============================================================================
-- RPC 2 (READ): list_chain_master_contracts
-- =============================================================================
CREATE OR REPLACE FUNCTION public.list_chain_master_contracts()
RETURNS TABLE (
  id uuid,
  chain_name text,
  parent_org_id uuid,
  parent_org_name text,
  contract_code text,
  master_tier text,
  status text,
  effective_from date,
  effective_to date,
  included_count int,
  excluded_count int,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.chain_name,
    c.parent_org_id,
    o.name AS parent_org_name,
    c.contract_code,
    c.master_tier,
    c.status,
    c.effective_from,
    c.effective_to,
    (SELECT (COUNT(*) FILTER (WHERE m.membership_kind = 'included' AND m.removed_at IS NULL))::int
       FROM public.hospital_chain_membership m WHERE m.chain_contract_id = c.id) AS included_count,
    (SELECT (COUNT(*) FILTER (WHERE m.membership_kind = 'excluded' AND m.removed_at IS NULL))::int
       FROM public.hospital_chain_membership m WHERE m.chain_contract_id = c.id) AS excluded_count,
    c.created_at
  FROM public.hospital_chain_master_contracts c
  LEFT JOIN public.organizations o ON o.id = c.parent_org_id
  ORDER BY c.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_chain_master_contracts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_chain_master_contracts() TO authenticated;

-- =============================================================================
-- RPC 3 (READ): list_chain_memberships (recent inclusion/exclusion entries)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.list_chain_memberships()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_org_id uuid,
  hospital_name text,
  hospital_state text,
  membership_kind text,
  has_override boolean,
  added_at timestamptz,
  removed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    c.chain_name,
    m.hospital_org_id,
    o.name AS hospital_name,
    o.state AS hospital_state,
    m.membership_kind,
    (m.binding_rate_card_override IS NOT NULL) AS has_override,
    m.added_at,
    m.removed_at
  FROM public.hospital_chain_membership m
  JOIN public.hospital_chain_master_contracts c ON c.id = m.chain_contract_id
  LEFT JOIN public.organizations o ON o.id = m.hospital_org_id
  ORDER BY m.added_at DESC
  LIMIT 300;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_chain_memberships() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_chain_memberships() TO authenticated;

-- =============================================================================
-- RPC 4 (READ): get_chain_revenue_by_tier
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_chain_revenue_by_tier()
RETURNS TABLE (
  master_tier text,
  chain_count int,
  included_locations int,
  repair_jobs_30d int,
  revenue_30d_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.master_tier,
    COUNT(DISTINCT c.id)::int AS chain_count,
    (SELECT (COUNT(*) FILTER (WHERE m.membership_kind = 'included' AND m.removed_at IS NULL))::int
       FROM public.hospital_chain_membership m
       JOIN public.hospital_chain_master_contracts c2 ON c2.id = m.chain_contract_id
       WHERE c2.master_tier = c.master_tier) AS included_locations,
    (SELECT COUNT(*)::int FROM public.repair_jobs rj
       JOIN public.hospital_chain_membership m ON m.hospital_org_id = rj.hospital_org_id
       JOIN public.hospital_chain_master_contracts c3 ON c3.id = m.chain_contract_id
       WHERE c3.master_tier = c.master_tier
         AND m.membership_kind = 'included'
         AND rj.created_at > now() - interval '30 days') AS repair_jobs_30d,
    (SELECT COALESCE(SUM(rj.contracted_amount_rupees), 0)::bigint FROM public.repair_jobs rj
       JOIN public.hospital_chain_membership m ON m.hospital_org_id = rj.hospital_org_id
       JOIN public.hospital_chain_master_contracts c4 ON c4.id = m.chain_contract_id
       WHERE c4.master_tier = c.master_tier
         AND m.membership_kind = 'included'
         AND rj.created_at > now() - interval '30 days') AS revenue_30d_rupees
  FROM public.hospital_chain_master_contracts c
  GROUP BY c.master_tier
  ORDER BY c.master_tier;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_chain_revenue_by_tier() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_chain_revenue_by_tier() TO authenticated;

-- =============================================================================
-- RPC 5 (WRITE): create_chain_master_contract
-- =============================================================================
CREATE OR REPLACE FUNCTION public.create_chain_master_contract(
  p_chain_name text,
  p_parent_org_id uuid,
  p_contract_code text,
  p_master_tier text,
  p_rate_card_json jsonb,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.hospital_chain_master_contracts (
    chain_name, parent_org_id, contract_code, master_tier, rate_card_json, notes, created_by
  ) VALUES (
    p_chain_name, p_parent_org_id, p_contract_code, p_master_tier,
    COALESCE(p_rate_card_json, '{}'::jsonb), p_notes, auth.uid()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_email, action, target_kind, target_id, payload)
  VALUES (v_email, 'chain_contract_created', 'hospital_chain_master_contracts', v_id::text,
    jsonb_build_object('chain_name', p_chain_name, 'tier', p_master_tier));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_chain_master_contract(text, uuid, text, text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_chain_master_contract(text, uuid, text, text, jsonb, text) TO authenticated;

-- =============================================================================
-- RPC 6 (WRITE): add_chain_membership
-- =============================================================================
CREATE OR REPLACE FUNCTION public.add_chain_membership(
  p_chain_contract_id uuid,
  p_hospital_org_id uuid,
  p_membership_kind text,
  p_override_json jsonb,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.hospital_chain_membership (
    chain_contract_id, hospital_org_id, membership_kind, binding_rate_card_override, notes
  ) VALUES (
    p_chain_contract_id, p_hospital_org_id,
    COALESCE(p_membership_kind, 'included'), p_override_json, p_notes
  )
  ON CONFLICT (chain_contract_id, hospital_org_id) DO UPDATE
    SET membership_kind = EXCLUDED.membership_kind,
        binding_rate_card_override = EXCLUDED.binding_rate_card_override,
        removed_at = NULL,
        notes = EXCLUDED.notes
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_email, action, target_kind, target_id, payload)
  VALUES (v_email, 'chain_membership_added', 'hospital_chain_membership', v_id::text,
    jsonb_build_object('chain_contract_id', p_chain_contract_id, 'hospital_org_id', p_hospital_org_id, 'kind', p_membership_kind));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_chain_membership(uuid, uuid, text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_chain_membership(uuid, uuid, text, jsonb, text) TO authenticated;

-- =============================================================================
-- RPC 7 (WRITE): set_chain_contract_status
-- =============================================================================
CREATE OR REPLACE FUNCTION public.set_chain_contract_status(
  p_chain_contract_id uuid,
  p_new_status text,
  p_reason text
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_new_status NOT IN ('draft','active','suspended','terminated') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  v_email := (auth.jwt()->>'email');

  UPDATE public.hospital_chain_master_contracts
     SET status = p_new_status,
         updated_at = now()
   WHERE id = p_chain_contract_id;

  INSERT INTO public.founder_action_log (actor_email, action, target_kind, target_id, payload)
  VALUES (v_email, 'chain_contract_status_changed', 'hospital_chain_master_contracts', p_chain_contract_id::text,
    jsonb_build_object('new_status', p_new_status, 'reason', p_reason));

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_chain_contract_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_chain_contract_status(uuid, text, text) TO authenticated;

COMMIT;