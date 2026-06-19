BEGIN;
-- Round 1323 — Dental vertical pilot (v0.5 Phase 4 P1)
-- Pilot ledger + bonded-parts suppliers + founder RPCs.
-- equipment_taxonomy_class exists (r486) but stores enum-level criticality,
-- not dental-specific categories — we embed dental category list as a constant
-- text[] in the pilot rows + RPC instead.


-- ============================================================================
-- 1. dental_pilot_clinics
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.dental_pilot_clinics (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_org_id               uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  clinic_name                 text NOT NULL,
  city                        text,
  cohort                      text NOT NULL DEFAULT 'hyderabad-pilot-2026q3'
                              CHECK (cohort IN ('hyderabad-pilot-2026q3','bengaluru-pilot-2026q4','expansion')),
  enrollment_status           text NOT NULL DEFAULT 'invited'
                              CHECK (enrollment_status IN ('invited','onboarding','live','paused','churned')),
  invited_at                  timestamptz NOT NULL DEFAULT now(),
  onboarded_at                timestamptz,
  first_amc_signed_at         timestamptz,
  primary_equipment_categories text[] NOT NULL DEFAULT ARRAY['autoclave','dental_xray','dental_chair','ultrasonic_scaler']::text[],
  pilot_lead_user_id          uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  notes                       text,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(clinic_org_id)
);

CREATE INDEX IF NOT EXISTS idx_dental_pilot_clinics_cohort
  ON public.dental_pilot_clinics(cohort);
CREATE INDEX IF NOT EXISTS idx_dental_pilot_clinics_status
  ON public.dental_pilot_clinics(enrollment_status);
CREATE INDEX IF NOT EXISTS idx_dental_pilot_clinics_invited_at
  ON public.dental_pilot_clinics(invited_at DESC);

ALTER TABLE public.dental_pilot_clinics ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dental_pilot_clinics_founder_only ON public.dental_pilot_clinics;
CREATE POLICY dental_pilot_clinics_founder_only ON public.dental_pilot_clinics
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- 2. dental_bonded_parts_suppliers
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.dental_bonded_parts_suppliers (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_org_id       uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  supplier_name         text NOT NULL,
  bonded_status         text NOT NULL DEFAULT 'pending'
                        CHECK (bonded_status IN ('pending','signed','active','revoked')),
  supported_categories  text[] NOT NULL DEFAULT ARRAY[]::text[],
  bond_amount_rupees    numeric NOT NULL DEFAULT 0,
  bond_signed_at        timestamptz,
  bond_expires_at       timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE(supplier_org_id)
);

CREATE INDEX IF NOT EXISTS idx_dental_bonded_suppliers_status
  ON public.dental_bonded_parts_suppliers(bonded_status);
CREATE INDEX IF NOT EXISTS idx_dental_bonded_suppliers_created_at
  ON public.dental_bonded_parts_suppliers(created_at DESC);

ALTER TABLE public.dental_bonded_parts_suppliers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dental_bonded_suppliers_founder_only ON public.dental_bonded_parts_suppliers;
CREATE POLICY dental_bonded_suppliers_founder_only ON public.dental_bonded_parts_suppliers
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- 3. Summary RPC — 12 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_dental_pilot_summary();
CREATE OR REPLACE FUNCTION public.founder_dental_pilot_summary()
RETURNS TABLE (
  total_clinics_invited        bigint,
  total_clinics_onboarded      bigint,
  total_clinics_live           bigint,
  total_clinics_paused         bigint,
  total_clinics_churned        bigint,
  total_amcs_signed            bigint,
  total_suppliers_signed       bigint,
  total_suppliers_pending      bigint,
  total_bond_value_rupees      numeric,
  days_since_pilot_start       integer,
  conversion_pct_invited_to_live numeric,
  days_to_first_amc_median     numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_invited bigint;
  v_live    bigint;
  v_first   timestamptz;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT count(*)                                              INTO v_invited FROM public.dental_pilot_clinics;
  SELECT count(*) FILTER (WHERE enrollment_status = 'live')    INTO v_live    FROM public.dental_pilot_clinics;
  SELECT min(invited_at)                                       INTO v_first   FROM public.dental_pilot_clinics;

  RETURN QUERY
  SELECT
    v_invited                                                                                AS total_clinics_invited,
    (SELECT count(*) FROM public.dental_pilot_clinics WHERE enrollment_status = 'onboarding') AS total_clinics_onboarded,
    v_live                                                                                   AS total_clinics_live,
    (SELECT count(*) FROM public.dental_pilot_clinics WHERE enrollment_status = 'paused')   AS total_clinics_paused,
    (SELECT count(*) FROM public.dental_pilot_clinics WHERE enrollment_status = 'churned')  AS total_clinics_churned,
    (SELECT count(*) FROM public.dental_pilot_clinics WHERE first_amc_signed_at IS NOT NULL) AS total_amcs_signed,
    (SELECT count(*) FROM public.dental_bonded_parts_suppliers WHERE bonded_status IN ('signed','active')) AS total_suppliers_signed,
    (SELECT count(*) FROM public.dental_bonded_parts_suppliers WHERE bonded_status = 'pending') AS total_suppliers_pending,
    COALESCE((SELECT sum(bond_amount_rupees) FROM public.dental_bonded_parts_suppliers WHERE bonded_status IN ('signed','active')), 0) AS total_bond_value_rupees,
    COALESCE(EXTRACT(DAY FROM (now() - v_first))::int, 0)                                    AS days_since_pilot_start,
    CASE WHEN v_invited > 0 THEN round((v_live::numeric / v_invited::numeric) * 100, 2) ELSE 0 END AS conversion_pct_invited_to_live,
    COALESCE((
      SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (first_amc_signed_at - invited_at)) / 86400.0)
      FROM public.dental_pilot_clinics
      WHERE first_amc_signed_at IS NOT NULL
    ), 0)::numeric                                                                           AS days_to_first_amc_median;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_dental_pilot_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_dental_pilot_summary() TO authenticated;

-- ============================================================================
-- 4. Clinics ledger RPC
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_dental_pilot_clinics(int);
CREATE OR REPLACE FUNCTION public.founder_dental_pilot_clinics(p_limit int DEFAULT 50)
RETURNS TABLE (
  id                            uuid,
  clinic_name                   text,
  city                          text,
  cohort                        text,
  enrollment_status             text,
  invited_at                    timestamptz,
  onboarded_at                  timestamptz,
  first_amc_signed_at           timestamptz,
  primary_equipment_categories  text[],
  notes                         text
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
    c.id,
    c.clinic_name,
    COALESCE(c.city, o.city)                AS city,
    c.cohort::text,
    c.enrollment_status::text,
    c.invited_at,
    c.onboarded_at,
    c.first_amc_signed_at,
    c.primary_equipment_categories,
    c.notes
  FROM public.dental_pilot_clinics c
  LEFT JOIN public.organizations o ON o.id = c.clinic_org_id
  ORDER BY c.invited_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_dental_pilot_clinics(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_dental_pilot_clinics(int) TO authenticated;

-- ============================================================================
-- 5. Bonded suppliers ledger RPC
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_dental_pilot_suppliers(int);
CREATE OR REPLACE FUNCTION public.founder_dental_pilot_suppliers(p_limit int DEFAULT 30)
RETURNS TABLE (
  id                    uuid,
  supplier_name         text,
  bonded_status         text,
  supported_categories  text[],
  bond_amount_rupees    numeric,
  bond_signed_at        timestamptz,
  bond_expires_at       timestamptz,
  created_at            timestamptz
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
    s.id,
    s.supplier_name,
    s.bonded_status::text,
    s.supported_categories,
    s.bond_amount_rupees,
    s.bond_signed_at,
    s.bond_expires_at,
    s.created_at
  FROM public.dental_bonded_parts_suppliers s
  ORDER BY s.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 100));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_dental_pilot_suppliers(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_dental_pilot_suppliers(int) TO authenticated;

-- ============================================================================
-- 6. Write-layer — enroll clinic
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_dental_enroll_clinic(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_dental_enroll_clinic(
  p_org_id      uuid,
  p_clinic_name text,
  p_city        text,
  p_cohort      text DEFAULT 'hyderabad-pilot-2026q3'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.dental_pilot_clinics(clinic_org_id, clinic_name, city, cohort, pilot_lead_user_id)
  VALUES (p_org_id, p_clinic_name, p_city, p_cohort, auth.uid())
  ON CONFLICT (clinic_org_id) DO UPDATE
    SET clinic_name = EXCLUDED.clinic_name,
        city        = EXCLUDED.city,
        cohort      = EXCLUDED.cohort,
        updated_at  = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_dental_enroll_clinic(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_dental_enroll_clinic(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- 7. Write-layer — register bonded supplier
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_dental_register_supplier(uuid, text, text[], numeric);
CREATE OR REPLACE FUNCTION public.log_founder_dental_register_supplier(
  p_org_id              uuid,
  p_supplier_name       text,
  p_supported_categories text[],
  p_bond_amount_rupees  numeric DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.dental_bonded_parts_suppliers(
    supplier_org_id, supplier_name, supported_categories, bond_amount_rupees
  )
  VALUES (p_org_id, p_supplier_name, COALESCE(p_supported_categories, ARRAY[]::text[]), COALESCE(p_bond_amount_rupees, 0))
  ON CONFLICT (supplier_org_id) DO UPDATE
    SET supplier_name        = EXCLUDED.supplier_name,
        supported_categories = EXCLUDED.supported_categories,
        bond_amount_rupees   = EXCLUDED.bond_amount_rupees
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_dental_register_supplier(uuid, text, text[], numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_dental_register_supplier(uuid, text, text[], numeric) TO authenticated;

COMMIT;