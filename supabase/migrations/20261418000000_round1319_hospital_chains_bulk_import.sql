BEGIN;

-- ============================================================
-- r1319 — Hospital Chains Bulk Import (v0.5 Phase 3 P0)
-- ============================================================
-- Founder registers multi-hospital chains as a single sales unit
-- and bulk-onboards member hospitals + AMC affidavit drafts.
-- ============================================================

-- ---------- TABLES ----------

CREATE TABLE IF NOT EXISTS public.hospital_chains (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL UNIQUE,
  chain_signer_name text,
  chain_signer_designation text,
  chain_signer_email text,
  chain_signer_phone text,
  default_amc_tier text CHECK (default_amc_tier IN ('starter','growth','enterprise')),
  default_monthly_fee_rupees numeric,
  default_equipment_categories text[],
  total_hospitals_target int DEFAULT 0,
  hospitals_onboarded_count int DEFAULT 0,
  status text NOT NULL DEFAULT 'prospecting'
    CHECK (status IN ('prospecting','negotiating','signed','onboarding','live','churned')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_chains_status_created
  ON public.hospital_chains (status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_chain_imports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL REFERENCES public.hospital_chains(id) ON DELETE CASCADE,
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  import_status text NOT NULL DEFAULT 'pending'
    CHECK (import_status IN ('pending','provisioned','amc_draft_created','live','failed')),
  failure_reason text,
  imported_at timestamptz,
  amc_contract_id uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_chain_imports_chain
  ON public.hospital_chain_imports (chain_id, created_at DESC);

ALTER TABLE public.hospital_chains ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_imports ENABLE ROW LEVEL SECURITY;

-- ---------- SUMMARY RPC ----------

DROP FUNCTION IF EXISTS public.founder_hospital_chains_summary();

CREATE OR REPLACE FUNCTION public.founder_hospital_chains_summary()
RETURNS TABLE (
  total_chains bigint,
  prospecting_count bigint,
  negotiating_count bigint,
  signed_count bigint,
  onboarding_count bigint,
  live_count bigint,
  churned_count bigint,
  total_hospitals_onboarded bigint,
  target_hospitals bigint,
  mrr_from_chains_rupees numeric,
  acquisition_velocity_hospitals_per_week numeric
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
    COUNT(*)::bigint AS total_chains,
    COUNT(*) FILTER (WHERE c.status = 'prospecting')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'negotiating')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'signed')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'onboarding')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'live')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'churned')::bigint,
    COALESCE(SUM(c.hospitals_onboarded_count), 0)::bigint,
    COALESCE(SUM(c.total_hospitals_target), 0)::bigint,
    COALESCE(SUM(
      CASE WHEN c.status IN ('live','onboarding')
        THEN c.hospitals_onboarded_count * COALESCE(c.default_monthly_fee_rupees, 0)
        ELSE 0
      END
    ), 0)::numeric,
    COALESCE((
      SELECT SUM(hospitals_onboarded_count)::numeric
             / NULLIF(EXTRACT(EPOCH FROM (now() - MIN(created_at))) / 604800.0, 0)
      FROM public.hospital_chains
      WHERE created_at > now() - interval '90 days'
    ), 0)::numeric
  FROM public.hospital_chains c;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_chains_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_chains_summary() TO authenticated;

-- ---------- RECENT CHAINS RPC ----------

DROP FUNCTION IF EXISTS public.founder_hospital_chains_recent(int);

CREATE OR REPLACE FUNCTION public.founder_hospital_chains_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  chain_name text,
  status text,
  default_amc_tier text,
  default_monthly_fee_rupees numeric,
  total_hospitals_target int,
  hospitals_onboarded_count int,
  mrr_contribution_rupees numeric,
  signer_name text,
  signer_email text,
  created_at timestamptz
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
    c.chain_name,
    c.status::text,
    c.default_amc_tier::text,
    c.default_monthly_fee_rupees,
    c.total_hospitals_target,
    c.hospitals_onboarded_count,
    (c.hospitals_onboarded_count * COALESCE(c.default_monthly_fee_rupees, 0))::numeric,
    c.chain_signer_name,
    c.chain_signer_email,
    c.created_at
  FROM public.hospital_chains c
  ORDER BY c.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_chains_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_chains_recent(int) TO authenticated;

-- ---------- WRITE: REGISTER NEW CHAIN ----------

DROP FUNCTION IF EXISTS public.log_founder_hospital_chain_register(text, text, text, text, text, numeric, int);

CREATE OR REPLACE FUNCTION public.log_founder_hospital_chain_register(
  p_chain_name text,
  p_signer_name text,
  p_signer_email text,
  p_signer_phone text,
  p_amc_tier text,
  p_monthly_fee_rupees numeric,
  p_target_hospitals int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_chain_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_chain_name IS NULL OR length(trim(p_chain_name)) = 0 THEN
    RAISE EXCEPTION 'chain_name required' USING ERRCODE = '22023';
  END IF;

  IF p_amc_tier IS NOT NULL AND p_amc_tier NOT IN ('starter','growth','enterprise') THEN
    RAISE EXCEPTION 'invalid amc_tier' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.hospital_chains (
    chain_name,
    chain_signer_name,
    chain_signer_email,
    chain_signer_phone,
    default_amc_tier,
    default_monthly_fee_rupees,
    total_hospitals_target,
    status
  )
  VALUES (
    trim(p_chain_name),
    NULLIF(trim(COALESCE(p_signer_name, '')), ''),
    NULLIF(trim(COALESCE(p_signer_email, '')), ''),
    NULLIF(trim(COALESCE(p_signer_phone, '')), ''),
    p_amc_tier,
    p_monthly_fee_rupees,
    COALESCE(p_target_hospitals, 0),
    'prospecting'
  )
  RETURNING id INTO v_chain_id;

  RETURN v_chain_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_hospital_chain_register(text, text, text, text, text, numeric, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_hospital_chain_register(text, text, text, text, text, numeric, int) TO authenticated;

-- ---------- WRITE: IMPORT HOSPITAL INTO CHAIN ----------

DROP FUNCTION IF EXISTS public.log_founder_hospital_chain_import_hospital(uuid, uuid);

CREATE OR REPLACE FUNCTION public.log_founder_hospital_chain_import_hospital(
  p_chain_id uuid,
  p_org_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_import_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_chain_id IS NULL OR p_org_id IS NULL THEN
    RAISE EXCEPTION 'chain_id and org_id required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.hospital_chain_imports (
    chain_id,
    hospital_org_id,
    import_status,
    imported_at
  )
  VALUES (p_chain_id, p_org_id, 'provisioned', now())
  RETURNING id INTO v_import_id;

  UPDATE public.hospital_chains
  SET hospitals_onboarded_count = hospitals_onboarded_count + 1,
      updated_at = now()
  WHERE id = p_chain_id;

  RETURN v_import_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_hospital_chain_import_hospital(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_hospital_chain_import_hospital(uuid, uuid) TO authenticated;

-- ---------- WRITE: STATUS TRANSITION ----------

DROP FUNCTION IF EXISTS public.log_founder_hospital_chain_status(uuid, text);

CREATE OR REPLACE FUNCTION public.log_founder_hospital_chain_status(
  p_chain_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_status NOT IN ('prospecting','negotiating','signed','onboarding','live','churned') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE = '22023';
  END IF;

  UPDATE public.hospital_chains
  SET status = p_status,
      updated_at = now()
  WHERE id = p_chain_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_hospital_chain_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_hospital_chain_status(uuid, text) TO authenticated;

COMMIT;