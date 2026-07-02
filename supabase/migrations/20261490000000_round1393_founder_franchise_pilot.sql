BEGIN;
-- r1393 · founder_franchise_pilot · state-level franchise model pilot tracker (v0.6 Phase 6)


-- ============================================================================
-- TABLE: founder_franchise_partners
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_franchise_partners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_name text NOT NULL UNIQUE,
  partner_kind text CHECK (partner_kind IN (
    'individual_entrepreneur',
    'existing_biomedical_company',
    'hospital_chain_partnership',
    'engineering_college',
    'distributor'
  )),
  state text NOT NULL,
  primary_district text,
  primary_contact_name text,
  primary_contact_email text,
  primary_contact_phone text,
  partnership_status text DEFAULT 'identified' CHECK (partnership_status IN (
    'identified','contacted','due_diligence','term_negotiation',
    'signed','active','dormant','dissolved'
  )),
  franchise_fee_rupees numeric DEFAULT 0,
  royalty_pct numeric DEFAULT 5.0,
  expected_hospitals_target int DEFAULT 0,
  expected_engineers_target int DEFAULT 0,
  signed_at date,
  activated_at date,
  dissolved_at date,
  notes text,
  recruiter_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_franchise_partners_state ON public.founder_franchise_partners(state);
CREATE INDEX IF NOT EXISTS idx_franchise_partners_status ON public.founder_franchise_partners(partnership_status);
CREATE INDEX IF NOT EXISTS idx_franchise_partners_created ON public.founder_franchise_partners(created_at DESC);

ALTER TABLE public.founder_franchise_partners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS franchise_partners_founder_all ON public.founder_franchise_partners;
CREATE POLICY franchise_partners_founder_all ON public.founder_franchise_partners
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE: founder_franchise_milestones
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_franchise_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id uuid REFERENCES public.founder_franchise_partners(id) ON DELETE CASCADE,
  milestone_kind text CHECK (milestone_kind IN (
    'hospital_onboarded','engineer_recruited','training_completed',
    'first_revenue_event','quarterly_review','contract_renewal','termination'
  )),
  description text NOT NULL,
  achieved_at timestamptz DEFAULT now(),
  value_rupees numeric DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_franchise_milestones_partner ON public.founder_franchise_milestones(partner_id);
CREATE INDEX IF NOT EXISTS idx_franchise_milestones_kind ON public.founder_franchise_milestones(milestone_kind);
CREATE INDEX IF NOT EXISTS idx_franchise_milestones_achieved ON public.founder_franchise_milestones(achieved_at DESC);

ALTER TABLE public.founder_franchise_milestones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS franchise_milestones_founder_all ON public.founder_franchise_milestones;
CREATE POLICY franchise_milestones_founder_all ON public.founder_franchise_milestones
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC: founder_franchise_pilot_summary — 14 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_franchise_pilot_summary();
CREATE OR REPLACE FUNCTION public.founder_franchise_pilot_summary()
RETURNS TABLE (
  total_partners bigint,
  identified_count bigint,
  contacted_count bigint,
  dd_count bigint,
  signed_count bigint,
  active_count bigint,
  dormant_count bigint,
  dissolved_count bigint,
  conversion_pct_to_active numeric,
  total_franchise_fee_rupees numeric,
  total_milestones bigint,
  milestones_30d bigint,
  top_state text,
  top_state_partner_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_state text;
  v_top_state_count bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  SELECT state, count(*) INTO v_top_state, v_top_state_count
  FROM public.founder_franchise_partners
  GROUP BY state
  ORDER BY count(*) DESC NULLS LAST
  LIMIT 1;

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_franchise_partners),
    (SELECT count(*) FROM public.founder_franchise_partners WHERE partnership_status='identified'),
    (SELECT count(*) FROM public.founder_franchise_partners WHERE partnership_status='contacted'),
    (SELECT count(*) FROM public.founder_franchise_partners WHERE partnership_status='due_diligence'),
    (SELECT count(*) FROM public.founder_franchise_partners WHERE partnership_status='signed'),
    (SELECT count(*) FROM public.founder_franchise_partners WHERE partnership_status='active'),
    (SELECT count(*) FROM public.founder_franchise_partners WHERE partnership_status='dormant'),
    (SELECT count(*) FROM public.founder_franchise_partners WHERE partnership_status='dissolved'),
    COALESCE(ROUND(
      100.0 * (SELECT count(*) FROM public.founder_franchise_partners WHERE partnership_status='active')::numeric
      / NULLIF((SELECT count(*) FROM public.founder_franchise_partners), 0)
    , 2), 0),
    COALESCE((SELECT sum(franchise_fee_rupees) FROM public.founder_franchise_partners), 0),
    (SELECT count(*) FROM public.founder_franchise_milestones),
    (SELECT count(*) FROM public.founder_franchise_milestones WHERE achieved_at >= now() - interval '30 days'),
    COALESCE(v_top_state, '—'),
    COALESCE(v_top_state_count, 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_franchise_pilot_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_franchise_pilot_summary() TO authenticated;

-- ============================================================================
-- RPC: founder_franchise_partners_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_franchise_partners_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_franchise_partners_recent(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  partner_name text,
  partner_kind text,
  state text,
  primary_district text,
  partnership_status text,
  franchise_fee_rupees numeric,
  royalty_pct numeric,
  expected_hospitals_target int,
  expected_engineers_target int,
  signed_at date,
  activated_at date,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    p.id, p.partner_name, p.partner_kind, p.state, p.primary_district,
    p.partnership_status, p.franchise_fee_rupees, p.royalty_pct,
    p.expected_hospitals_target, p.expected_engineers_target,
    p.signed_at, p.activated_at, p.created_at
  FROM public.founder_franchise_partners p
  WHERE p_status IS NULL OR p.partnership_status = p_status
  ORDER BY p.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_franchise_partners_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_franchise_partners_recent(text, int) TO authenticated;

-- ============================================================================
-- RPC: founder_franchise_milestones_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_franchise_milestones_recent(uuid, int);
CREATE OR REPLACE FUNCTION public.founder_franchise_milestones_recent(
  p_partner_id uuid DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  partner_id uuid,
  partner_name text,
  state text,
  milestone_kind text,
  description text,
  value_rupees numeric,
  achieved_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    m.id, m.partner_id, p.partner_name, p.state,
    m.milestone_kind, m.description, m.value_rupees, m.achieved_at
  FROM public.founder_franchise_milestones m
  LEFT JOIN public.founder_franchise_partners p ON p.id = m.partner_id
  WHERE p_partner_id IS NULL OR m.partner_id = p_partner_id
  ORDER BY m.achieved_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_franchise_milestones_recent(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_franchise_milestones_recent(uuid, int) TO authenticated;

-- ============================================================================
-- LOG WRITERS
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_franchise_register_partner(text, text, text, text, text, text, text, numeric, numeric, int, int);
CREATE OR REPLACE FUNCTION public.log_founder_franchise_register_partner(
  p_partner_name text,
  p_partner_kind text,
  p_state text,
  p_primary_district text DEFAULT NULL,
  p_contact_name text DEFAULT NULL,
  p_contact_email text DEFAULT NULL,
  p_contact_phone text DEFAULT NULL,
  p_franchise_fee_rupees numeric DEFAULT 0,
  p_royalty_pct numeric DEFAULT 5.0,
  p_hospitals_target int DEFAULT 0,
  p_engineers_target int DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.founder_franchise_partners(
    partner_name, partner_kind, state, primary_district,
    primary_contact_name, primary_contact_email, primary_contact_phone,
    franchise_fee_rupees, royalty_pct,
    expected_hospitals_target, expected_engineers_target,
    recruiter_user_id
  )
  VALUES (
    p_partner_name, p_partner_kind, p_state, p_primary_district,
    p_contact_name, p_contact_email, p_contact_phone,
    COALESCE(p_franchise_fee_rupees, 0), COALESCE(p_royalty_pct, 5.0),
    COALESCE(p_hospitals_target, 0), COALESCE(p_engineers_target, 0),
    auth.uid()
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_franchise_register_partner(text, text, text, text, text, text, text, numeric, numeric, int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_franchise_register_partner(text, text, text, text, text, text, text, numeric, numeric, int, int) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_franchise_status(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_franchise_status(
  p_partner_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  UPDATE public.founder_franchise_partners
  SET partnership_status = p_new_status,
      signed_at = CASE WHEN p_new_status = 'signed' AND signed_at IS NULL THEN CURRENT_DATE ELSE signed_at END,
      activated_at = CASE WHEN p_new_status = 'active' AND activated_at IS NULL THEN CURRENT_DATE ELSE activated_at END,
      dissolved_at = CASE WHEN p_new_status = 'dissolved' AND dissolved_at IS NULL THEN CURRENT_DATE ELSE dissolved_at END,
      updated_at = now()
  WHERE id = p_partner_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_franchise_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_franchise_status(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_franchise_milestone(uuid, text, text, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_franchise_milestone(
  p_partner_id uuid,
  p_milestone_kind text,
  p_description text,
  p_value_rupees numeric DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.founder_franchise_milestones(partner_id, milestone_kind, description, value_rupees)
  VALUES (p_partner_id, p_milestone_kind, p_description, COALESCE(p_value_rupees, 0))
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_franchise_milestone(uuid, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_franchise_milestone(uuid, text, text, numeric) TO authenticated;

COMMIT;