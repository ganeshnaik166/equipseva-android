BEGIN;
-- Round 1392: Lab Diagnostics vertical pilot (v0.6 Phase 1)
-- Mirrors dental r1323; tracks clinic enrollment + bonded-parts suppliers for the
-- Hyderabad 2026Q4 lab diagnostics cohort. Founder-gated KPI surface.



-- =====================================================================
-- TABLE 1: lab_diagnostics_pilot_clinics
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.lab_diagnostics_pilot_clinics (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE UNIQUE,
    clinic_name text NOT NULL,
    city text,
    cohort text DEFAULT 'hyderabad-pilot-2026q4'
        CHECK (cohort IN ('hyderabad-pilot-2026q4','bangalore-pilot-2027q1','chennai-pilot-2027q2','expansion')),
    enrollment_status text DEFAULT 'invited'
        CHECK (enrollment_status IN ('invited','onboarding','live','paused','churned')),
    invited_at timestamptz DEFAULT now(),
    onboarded_at timestamptz,
    first_amc_signed_at timestamptz,
    primary_equipment_categories text[] DEFAULT ARRAY[
        'blood_analyzer','centrifuge','autoclave_lab','microscope','elisa_reader',
        'urine_analyzer','spectrophotometer','pcr_machine','immunoassay_analyzer'
    ]::text[],
    pilot_lead_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lab_diag_clinics_status ON public.lab_diagnostics_pilot_clinics(enrollment_status);
CREATE INDEX IF NOT EXISTS idx_lab_diag_clinics_cohort ON public.lab_diagnostics_pilot_clinics(cohort);
CREATE INDEX IF NOT EXISTS idx_lab_diag_clinics_invited ON public.lab_diagnostics_pilot_clinics(invited_at DESC);

ALTER TABLE public.lab_diagnostics_pilot_clinics ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- TABLE 2: lab_diagnostics_bonded_parts_suppliers
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.lab_diagnostics_bonded_parts_suppliers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE UNIQUE,
    supplier_name text NOT NULL,
    bonded_status text DEFAULT 'pending'
        CHECK (bonded_status IN ('pending','signed','active','revoked')),
    supported_categories text[] DEFAULT ARRAY[]::text[],
    bond_amount_rupees numeric DEFAULT 0,
    bond_signed_at timestamptz,
    bond_expires_at timestamptz,
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lab_diag_suppliers_status ON public.lab_diagnostics_bonded_parts_suppliers(bonded_status);

ALTER TABLE public.lab_diagnostics_bonded_parts_suppliers ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- RPC: founder_lab_diagnostics_pilot_summary (12 KPIs)
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_lab_diagnostics_pilot_summary();
CREATE OR REPLACE FUNCTION public.founder_lab_diagnostics_pilot_summary()
RETURNS TABLE (
    total_clinics_invited bigint,
    total_clinics_onboarded bigint,
    total_clinics_live bigint,
    total_clinics_paused bigint,
    total_clinics_churned bigint,
    total_amcs_signed bigint,
    total_suppliers_signed bigint,
    total_suppliers_pending bigint,
    total_bond_value_rupees numeric,
    days_since_pilot_start integer,
    conversion_pct_invited_to_live numeric,
    days_to_first_amc_median numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.is_founder() THEN
        RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
    END IF;

    RETURN QUERY
    WITH clinic_stats AS (
        SELECT
            COUNT(*) FILTER (WHERE enrollment_status = 'invited') AS c_invited,
            COUNT(*) FILTER (WHERE enrollment_status = 'onboarding') AS c_onboarding,
            COUNT(*) FILTER (WHERE enrollment_status = 'live') AS c_live,
            COUNT(*) FILTER (WHERE enrollment_status = 'paused') AS c_paused,
            COUNT(*) FILTER (WHERE enrollment_status = 'churned') AS c_churned,
            COUNT(*) FILTER (WHERE first_amc_signed_at IS NOT NULL) AS c_amcs,
            COUNT(*) AS c_total,
            MIN(invited_at) AS pilot_start,
            percentile_cont(0.5) WITHIN GROUP (
                ORDER BY EXTRACT(EPOCH FROM (first_amc_signed_at - invited_at)) / 86400.0
            ) FILTER (WHERE first_amc_signed_at IS NOT NULL) AS median_days_to_amc
        FROM public.lab_diagnostics_pilot_clinics
    ),
    supplier_stats AS (
        SELECT
            COUNT(*) FILTER (WHERE bonded_status IN ('signed','active')) AS s_signed,
            COUNT(*) FILTER (WHERE bonded_status = 'pending') AS s_pending,
            COALESCE(SUM(bond_amount_rupees) FILTER (WHERE bonded_status IN ('signed','active')), 0) AS bond_total
        FROM public.lab_diagnostics_bonded_parts_suppliers
    )
    SELECT
        c.c_invited,
        c.c_onboarding,
        c.c_live,
        c.c_paused,
        c.c_churned,
        c.c_amcs,
        s.s_signed,
        s.s_pending,
        s.bond_total::numeric,
        COALESCE(EXTRACT(DAY FROM (now() - c.pilot_start))::integer, 0),
        CASE WHEN c.c_total > 0 THEN ROUND((c.c_live::numeric / c.c_total::numeric) * 100, 2) ELSE 0 END,
        COALESCE(ROUND(c.median_days_to_amc::numeric, 1), 0)
    FROM clinic_stats c CROSS JOIN supplier_stats s;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_lab_diagnostics_pilot_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_lab_diagnostics_pilot_summary() TO authenticated;

-- =====================================================================
-- RPC: founder_lab_diagnostics_pilot_clinics (50-row ledger)
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_lab_diagnostics_pilot_clinics(int);
CREATE OR REPLACE FUNCTION public.founder_lab_diagnostics_pilot_clinics(p_limit int DEFAULT 50)
RETURNS TABLE (
    id uuid,
    clinic_name text,
    city text,
    cohort text,
    enrollment_status text,
    invited_at timestamptz,
    onboarded_at timestamptz,
    first_amc_signed_at timestamptz,
    categories_count integer,
    days_in_pipeline integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.is_founder() THEN
        RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.clinic_name,
        c.city,
        c.cohort,
        c.enrollment_status,
        c.invited_at,
        c.onboarded_at,
        c.first_amc_signed_at,
        COALESCE(array_length(c.primary_equipment_categories, 1), 0),
        EXTRACT(DAY FROM (now() - c.invited_at))::integer
    FROM public.lab_diagnostics_pilot_clinics c
    ORDER BY c.invited_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_lab_diagnostics_pilot_clinics(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_lab_diagnostics_pilot_clinics(int) TO authenticated;

-- =====================================================================
-- RPC: founder_lab_diagnostics_pilot_suppliers (30-row ledger)
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_lab_diagnostics_pilot_suppliers(int);
CREATE OR REPLACE FUNCTION public.founder_lab_diagnostics_pilot_suppliers(p_limit int DEFAULT 30)
RETURNS TABLE (
    id uuid,
    supplier_name text,
    bonded_status text,
    supported_count integer,
    bond_amount_rupees numeric,
    bond_signed_at timestamptz,
    bond_expires_at timestamptz,
    days_until_expiry integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.is_founder() THEN
        RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
    END IF;

    RETURN QUERY
    SELECT
        s.id,
        s.supplier_name,
        s.bonded_status,
        COALESCE(array_length(s.supported_categories, 1), 0),
        s.bond_amount_rupees,
        s.bond_signed_at,
        s.bond_expires_at,
        CASE WHEN s.bond_expires_at IS NOT NULL
             THEN EXTRACT(DAY FROM (s.bond_expires_at - now()))::integer
             ELSE NULL END
    FROM public.lab_diagnostics_bonded_parts_suppliers s
    ORDER BY s.created_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_lab_diagnostics_pilot_suppliers(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_lab_diagnostics_pilot_suppliers(int) TO authenticated;

-- =====================================================================
-- WRITE: log_founder_lab_diagnostics_enroll_clinic
-- =====================================================================
DROP FUNCTION IF EXISTS public.log_founder_lab_diagnostics_enroll_clinic(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_lab_diagnostics_enroll_clinic(
    p_clinic_org_id uuid,
    p_clinic_name text,
    p_city text DEFAULT NULL,
    p_cohort text DEFAULT 'hyderabad-pilot-2026q4'
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
    v_id uuid;
BEGIN
    IF NOT public.is_founder() THEN
        RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
    END IF;

    INSERT INTO public.lab_diagnostics_pilot_clinics (clinic_org_id, clinic_name, city, cohort)
    VALUES (p_clinic_org_id, p_clinic_name, p_city, p_cohort)
    ON CONFLICT (clinic_org_id) DO UPDATE
        SET clinic_name = EXCLUDED.clinic_name,
            city = COALESCE(EXCLUDED.city, public.lab_diagnostics_pilot_clinics.city),
            updated_at = now()
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_lab_diagnostics_enroll_clinic(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_lab_diagnostics_enroll_clinic(uuid, text, text, text) TO authenticated;

-- =====================================================================
-- WRITE: log_founder_lab_diagnostics_register_supplier
-- =====================================================================
DROP FUNCTION IF EXISTS public.log_founder_lab_diagnostics_register_supplier(uuid, text, numeric, text[]);
CREATE OR REPLACE FUNCTION public.log_founder_lab_diagnostics_register_supplier(
    p_supplier_org_id uuid,
    p_supplier_name text,
    p_bond_amount_rupees numeric DEFAULT 0,
    p_supported_categories text[] DEFAULT ARRAY[]::text[]
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
    v_id uuid;
BEGIN
    IF NOT public.is_founder() THEN
        RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
    END IF;

    INSERT INTO public.lab_diagnostics_bonded_parts_suppliers (
        supplier_org_id, supplier_name, bond_amount_rupees, supported_categories
    )
    VALUES (p_supplier_org_id, p_supplier_name, p_bond_amount_rupees, p_supported_categories)
    ON CONFLICT (supplier_org_id) DO UPDATE
        SET supplier_name = EXCLUDED.supplier_name,
            bond_amount_rupees = EXCLUDED.bond_amount_rupees,
            supported_categories = EXCLUDED.supported_categories
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_lab_diagnostics_register_supplier(uuid, text, numeric, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_lab_diagnostics_register_supplier(uuid, text, numeric, text[]) TO authenticated;

COMMIT;