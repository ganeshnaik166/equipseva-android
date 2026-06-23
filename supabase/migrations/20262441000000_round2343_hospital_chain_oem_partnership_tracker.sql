BEGIN;

-- Chain-level OEM preference tracker (which OEM each hospital chain favors)
CREATE TABLE IF NOT EXISTS public.chain_oem_preferences_r2343 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier_1','tier_2','tier_3','regional')),
  oem_vendor text NOT NULL CHECK (oem_vendor IN ('GE','Philips','Siemens','Mindray','Drager','Nihon_Kohden','BPL','Other')),
  preference_rank int NOT NULL CHECK (preference_rank BETWEEN 1 AND 5),
  installed_base_count int NOT NULL DEFAULT 0 CHECK (installed_base_count >= 0),
  annual_capex_inr_lakhs numeric(12,2) NOT NULL DEFAULT 0 CHECK (annual_capex_inr_lakhs >= 0),
  procurement_contact_name text,
  procurement_contact_email text,
  procurement_contact_phone text,
  exclusive_contract boolean NOT NULL DEFAULT false,
  contract_expiry_date date,
  notes text,
  source_evidence text,
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chain_oem_unique UNIQUE (chain_name, oem_vendor)
);

CREATE INDEX IF NOT EXISTS idx_chain_oem_pref_chain_r2343 ON public.chain_oem_preferences_r2343(chain_name);
CREATE INDEX IF NOT EXISTS idx_chain_oem_pref_vendor_r2343 ON public.chain_oem_preferences_r2343(oem_vendor);
CREATE INDEX IF NOT EXISTS idx_chain_oem_pref_tier_r2343 ON public.chain_oem_preferences_r2343(chain_tier);

ALTER TABLE public.chain_oem_preferences_r2343 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chain_oem_pref_founder_all_r2343 ON public.chain_oem_preferences_r2343;
CREATE POLICY chain_oem_pref_founder_all_r2343 ON public.chain_oem_preferences_r2343
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Our partnership posture with each OEM (the gap side)
CREATE TABLE IF NOT EXISTS public.oem_partnership_status_r2343 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oem_vendor text NOT NULL UNIQUE CHECK (oem_vendor IN ('GE','Philips','Siemens','Mindray','Drager','Nihon_Kohden','BPL','Other')),
  partnership_stage text NOT NULL CHECK (partnership_stage IN ('none','intro','warm_lead','msa_drafted','signed','active','dormant')),
  authorized_service_partner boolean NOT NULL DEFAULT false,
  spare_parts_access text NOT NULL DEFAULT 'none' CHECK (spare_parts_access IN ('none','grey_market','distributor','direct')),
  training_certified_engineers int NOT NULL DEFAULT 0 CHECK (training_certified_engineers >= 0),
  india_hq_contact_name text,
  india_hq_contact_email text,
  india_hq_contact_phone text,
  msa_signed_date date,
  msa_expiry_date date,
  revenue_share_pct numeric(5,2) CHECK (revenue_share_pct IS NULL OR (revenue_share_pct >= 0 AND revenue_share_pct <= 100)),
  blocker_summary text,
  next_action text,
  next_action_due date,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_oem_partnership_stage_r2343 ON public.oem_partnership_status_r2343(partnership_stage);
CREATE INDEX IF NOT EXISTS idx_oem_partnership_due_r2343 ON public.oem_partnership_status_r2343(next_action_due);

ALTER TABLE public.oem_partnership_status_r2343 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS oem_partnership_founder_all_r2343 ON public.oem_partnership_status_r2343;
CREATE POLICY oem_partnership_founder_all_r2343 ON public.oem_partnership_status_r2343
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: Snapshot — total chains, OEMs tracked, active partnerships, gap chains
CREATE OR REPLACE FUNCTION public.fn_r2343_snapshot()
RETURNS TABLE (
  total_chains_tracked bigint,
  total_oems_tracked bigint,
  active_partnerships bigint,
  msa_signed_partnerships bigint,
  chains_with_no_partnership bigint,
  total_installed_base bigint,
  total_annual_capex_lakhs numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(DISTINCT chain_name) FROM public.chain_oem_preferences_r2343),
    (SELECT COUNT(*) FROM public.oem_partnership_status_r2343),
    (SELECT COUNT(*) FROM public.oem_partnership_status_r2343 WHERE partnership_stage = 'active'),
    (SELECT COUNT(*) FROM public.oem_partnership_status_r2343 WHERE partnership_stage IN ('signed','active')),
    (SELECT COUNT(DISTINCT c.chain_name)
       FROM public.chain_oem_preferences_r2343 c
       WHERE c.preference_rank = 1
         AND NOT EXISTS (
           SELECT 1 FROM public.oem_partnership_status_r2343 p
           WHERE p.oem_vendor = c.oem_vendor
             AND p.partnership_stage IN ('signed','active')
         )),
    COALESCE((SELECT SUM(installed_base_count) FROM public.chain_oem_preferences_r2343), 0)::bigint,
    COALESCE((SELECT SUM(annual_capex_inr_lakhs) FROM public.chain_oem_preferences_r2343), 0);
END;
$$;

-- RPC 2: Chain-by-chain OEM preference list
CREATE OR REPLACE FUNCTION public.fn_r2343_chain_preferences()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  oem_vendor text,
  preference_rank int,
  installed_base_count int,
  annual_capex_inr_lakhs numeric,
  exclusive_contract boolean,
  contract_expiry_date date,
  partnership_stage text,
  gap_flag boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.chain_name,
    c.chain_tier,
    c.oem_vendor,
    c.preference_rank,
    c.installed_base_count,
    c.annual_capex_inr_lakhs,
    c.exclusive_contract,
    c.contract_expiry_date,
    COALESCE(p.partnership_stage, 'none'),
    (c.preference_rank = 1 AND COALESCE(p.partnership_stage, 'none') NOT IN ('signed','active'))
  FROM public.chain_oem_preferences_r2343 c
  LEFT JOIN public.oem_partnership_status_r2343 p ON p.oem_vendor = c.oem_vendor
  ORDER BY c.chain_tier, c.chain_name, c.preference_rank;
END;
$$;

-- RPC 3: OEM partnership status overview
CREATE OR REPLACE FUNCTION public.fn_r2343_oem_status()
RETURNS TABLE (
  id uuid,
  oem_vendor text,
  partnership_stage text,
  authorized_service_partner boolean,
  spare_parts_access text,
  training_certified_engineers int,
  msa_signed_date date,
  msa_expiry_date date,
  revenue_share_pct numeric,
  next_action text,
  next_action_due date,
  chains_favoring_this_oem bigint,
  total_installed_base bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.oem_vendor,
    p.partnership_stage,
    p.authorized_service_partner,
    p.spare_parts_access,
    p.training_certified_engineers,
    p.msa_signed_date,
    p.msa_expiry_date,
    p.revenue_share_pct,
    p.next_action,
    p.next_action_due,
    COALESCE((SELECT COUNT(DISTINCT c.chain_name) FROM public.chain_oem_preferences_r2343 c WHERE c.oem_vendor = p.oem_vendor AND c.preference_rank = 1), 0)::bigint,
    COALESCE((SELECT SUM(c.installed_base_count) FROM public.chain_oem_preferences_r2343 c WHERE c.oem_vendor = p.oem_vendor), 0)::bigint
  FROM public.oem_partnership_status_r2343 p
  ORDER BY
    CASE p.partnership_stage
      WHEN 'active' THEN 1 WHEN 'signed' THEN 2 WHEN 'msa_drafted' THEN 3
      WHEN 'warm_lead' THEN 4 WHEN 'intro' THEN 5 WHEN 'dormant' THEN 6 WHEN 'none' THEN 7
    END;
END;
$$;

-- RPC 4: Gap analysis — chains favoring an OEM where we have no active partnership
CREATE OR REPLACE FUNCTION public.fn_r2343_gap_analysis()
RETURNS TABLE (
  chain_name text,
  chain_tier text,
  favored_oem text,
  installed_base_count int,
  annual_capex_inr_lakhs numeric,
  partnership_stage text,
  blocker_summary text,
  estimated_lost_arr_lakhs numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.chain_name,
    c.chain_tier,
    c.oem_vendor,
    c.installed_base_count,
    c.annual_capex_inr_lakhs,
    COALESCE(p.partnership_stage, 'none'),
    p.blocker_summary,
    -- estimate 8% of annual capex as service revenue potential lost
    ROUND(c.annual_capex_inr_lakhs * 0.08, 2)
  FROM public.chain_oem_preferences_r2343 c
  LEFT JOIN public.oem_partnership_status_r2343 p ON p.oem_vendor = c.oem_vendor
  WHERE c.preference_rank = 1
    AND COALESCE(p.partnership_stage, 'none') NOT IN ('signed','active')
  ORDER BY c.annual_capex_inr_lakhs DESC NULLS LAST;
END;
$$;

-- RPC 5: OEM vendor concentration — top OEMs by installed base
CREATE OR REPLACE FUNCTION public.fn_r2343_vendor_concentration()
RETURNS TABLE (
  oem_vendor text,
  chain_count bigint,
  total_installed_base bigint,
  total_capex_lakhs numeric,
  partnership_stage text,
  pct_of_total_capex numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT NULLIF(SUM(annual_capex_inr_lakhs), 0) INTO v_total FROM public.chain_oem_preferences_r2343;
  RETURN QUERY
  SELECT
    c.oem_vendor,
    COUNT(DISTINCT c.chain_name),
    COALESCE(SUM(c.installed_base_count), 0)::bigint,
    COALESCE(SUM(c.annual_capex_inr_lakhs), 0),
    COALESCE(p.partnership_stage, 'none'),
    CASE WHEN v_total IS NULL THEN 0 ELSE ROUND(SUM(c.annual_capex_inr_lakhs) / v_total * 100, 2) END
  FROM public.chain_oem_preferences_r2343 c
  LEFT JOIN public.oem_partnership_status_r2343 p ON p.oem_vendor = c.oem_vendor
  GROUP BY c.oem_vendor, p.partnership_stage
  ORDER BY SUM(c.annual_capex_inr_lakhs) DESC NULLS LAST;
END;
$$;

-- RPC 6: Upsert chain OEM preference (founder-only)
CREATE OR REPLACE FUNCTION public.fn_r2343_upsert_chain_pref(
  p_chain_name text,
  p_chain_tier text,
  p_oem_vendor text,
  p_preference_rank int,
  p_installed_base int,
  p_annual_capex_lakhs numeric,
  p_exclusive_contract boolean,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_uid uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT id INTO v_uid FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  INSERT INTO public.chain_oem_preferences_r2343 (
    chain_name, chain_tier, oem_vendor, preference_rank,
    installed_base_count, annual_capex_inr_lakhs, exclusive_contract, notes, recorded_by
  )
  VALUES (
    p_chain_name, p_chain_tier, p_oem_vendor, p_preference_rank,
    COALESCE(p_installed_base, 0), COALESCE(p_annual_capex_lakhs, 0),
    COALESCE(p_exclusive_contract, false), p_notes, v_uid
  )
  ON CONFLICT (chain_name, oem_vendor) DO UPDATE SET
    chain_tier = EXCLUDED.chain_tier,
    preference_rank = EXCLUDED.preference_rank,
    installed_base_count = EXCLUDED.installed_base_count,
    annual_capex_inr_lakhs = EXCLUDED.annual_capex_inr_lakhs,
    exclusive_contract = EXCLUDED.exclusive_contract,
    notes = EXCLUDED.notes,
    updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 7: Advance OEM partnership stage
CREATE OR REPLACE FUNCTION public.fn_r2343_advance_partnership(
  p_oem_vendor text,
  p_new_stage text,
  p_next_action text,
  p_next_action_due date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_uid uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT id INTO v_uid FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  INSERT INTO public.oem_partnership_status_r2343 (oem_vendor, partnership_stage, next_action, next_action_due, owner_user_id)
  VALUES (p_oem_vendor, p_new_stage, p_next_action, p_next_action_due, v_uid)
  ON CONFLICT (oem_vendor) DO UPDATE SET
    partnership_stage = EXCLUDED.partnership_stage,
    next_action = EXCLUDED.next_action,
    next_action_due = EXCLUDED.next_action_due,
    owner_user_id = COALESCE(EXCLUDED.owner_user_id, public.oem_partnership_status_r2343.owner_user_id),
    updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2343_snapshot() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2343_chain_preferences() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2343_oem_status() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2343_gap_analysis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2343_vendor_concentration() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2343_upsert_chain_pref(text, text, text, int, int, numeric, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2343_advance_partnership(text, text, text, date) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fn_r2343_snapshot() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2343_chain_preferences() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2343_oem_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2343_gap_analysis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2343_vendor_concentration() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2343_upsert_chain_pref(text, text, text, int, int, numeric, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2343_advance_partnership(text, text, text, date) TO authenticated;

COMMIT;
