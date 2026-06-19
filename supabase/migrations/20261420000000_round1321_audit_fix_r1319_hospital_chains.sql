BEGIN;
-- r1321 — CRITICAL audit-fix for r1319.
-- hospital_chains TABLE already existed (from r544 round544_hospital_chains_seed)
-- with a DIFFERENT schema: `name`, `billing_gstin`, `primary_admin_user_id`, status
-- CHECK ('active','paused','offboarded'). r1319 created with `IF NOT EXISTS` so
-- the new columns + new status CHECK never applied — all 5 RPCs would have failed
-- at runtime with "column does not exist" / status violations.
--
-- Fix: ADD the new columns onto the existing table, RELAX the status CHECK to
-- UNION old+new values, and rewrite RPCs to use `name` (the existing column)
-- instead of the non-existent `chain_name`.

-- ============================================================
-- 1. ALTER existing hospital_chains to add r1319 columns
-- ============================================================
ALTER TABLE public.hospital_chains
  ADD COLUMN IF NOT EXISTS chain_signer_name        text,
  ADD COLUMN IF NOT EXISTS chain_signer_designation text,
  ADD COLUMN IF NOT EXISTS chain_signer_email       text,
  ADD COLUMN IF NOT EXISTS chain_signer_phone       text,
  ADD COLUMN IF NOT EXISTS default_amc_tier         text,
  ADD COLUMN IF NOT EXISTS default_monthly_fee_rupees numeric,
  ADD COLUMN IF NOT EXISTS default_equipment_categories text[],
  ADD COLUMN IF NOT EXISTS total_hospitals_target   int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS hospitals_onboarded_count int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at               timestamptz DEFAULT now();

-- Add default_amc_tier CHECK only if missing
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'hospital_chains_default_amc_tier_check'
  ) THEN
    ALTER TABLE public.hospital_chains
      ADD CONSTRAINT hospital_chains_default_amc_tier_check
      CHECK (default_amc_tier IS NULL OR default_amc_tier IN ('starter','growth','enterprise'));
  END IF;
END
$do$;

-- Drop existing status CHECK + ADD new one that UNIONs old+new vocab
ALTER TABLE public.hospital_chains
  DROP CONSTRAINT IF EXISTS hospital_chains_status_check;

ALTER TABLE public.hospital_chains
  ADD CONSTRAINT hospital_chains_status_check
  CHECK (status IN (
    'active','paused','offboarded',
    'prospecting','negotiating','signed','onboarding','live','churned'
  ));

-- ============================================================
-- 2. Rewrite RPCs to use existing `name` column
-- ============================================================

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
  active_legacy_count bigint,
  total_hospitals_onboarded bigint,
  target_hospitals bigint,
  mrr_from_chains_rupees numeric,
  acquisition_velocity_hospitals_per_week numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE c.status = 'prospecting')::bigint,
    count(*) FILTER (WHERE c.status = 'negotiating')::bigint,
    count(*) FILTER (WHERE c.status = 'signed')::bigint,
    count(*) FILTER (WHERE c.status = 'onboarding')::bigint,
    count(*) FILTER (WHERE c.status IN ('live','active'))::bigint,
    count(*) FILTER (WHERE c.status = 'churned')::bigint,
    count(*) FILTER (WHERE c.status IN ('paused','offboarded'))::bigint,
    coalesce(sum(c.hospitals_onboarded_count), 0)::bigint,
    coalesce(sum(c.total_hospitals_target), 0)::bigint,
    coalesce(sum(
      CASE WHEN c.status IN ('live','active','onboarding')
        THEN coalesce(c.hospitals_onboarded_count, 0) * coalesce(c.default_monthly_fee_rupees, 0)
        ELSE 0 END
    ), 0)::numeric,
    coalesce((
      SELECT sum(hospitals_onboarded_count)::numeric
             / nullif(extract(epoch FROM (now() - min(created_at))) / 604800.0, 0)
      FROM public.hospital_chains
      WHERE created_at > now() - interval '90 days'
    ), 0)::numeric
  FROM public.hospital_chains c;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_chains_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_chains_summary() TO authenticated;

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
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.status::text,
    c.default_amc_tier::text,
    c.default_monthly_fee_rupees,
    c.total_hospitals_target,
    c.hospitals_onboarded_count,
    (coalesce(c.hospitals_onboarded_count, 0) * coalesce(c.default_monthly_fee_rupees, 0))::numeric,
    c.chain_signer_name,
    c.chain_signer_email,
    c.created_at
  FROM public.hospital_chains c
  ORDER BY c.created_at DESC
  LIMIT greatest(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_chains_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_chains_recent(int) TO authenticated;

-- ============================================================
-- 3. Register-new-chain RPC uses existing schema's required cols
-- ============================================================
-- The original table requires `primary_admin_user_id NOT NULL`. We default to the
-- caller's auth.uid() (the founder).
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
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_chain_id uuid;
  v_caller   uuid := auth.uid();
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_chain_name IS NULL OR length(trim(p_chain_name)) < 3 THEN
    RAISE EXCEPTION 'chain_name required (min 3 chars)' USING ERRCODE = '22023';
  END IF;
  IF p_amc_tier IS NOT NULL AND p_amc_tier NOT IN ('starter','growth','enterprise') THEN
    RAISE EXCEPTION 'invalid amc_tier' USING ERRCODE = '22023';
  END IF;
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth context required' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.hospital_chains (
    name, primary_admin_user_id, status,
    chain_signer_name, chain_signer_email, chain_signer_phone,
    default_amc_tier, default_monthly_fee_rupees, total_hospitals_target,
    created_by
  )
  VALUES (
    trim(p_chain_name), v_caller, 'prospecting',
    nullif(trim(coalesce(p_signer_name, '')), ''),
    nullif(trim(coalesce(p_signer_email, '')), ''),
    nullif(trim(coalesce(p_signer_phone, '')), ''),
    p_amc_tier, p_monthly_fee_rupees, coalesce(p_target_hospitals, 0),
    v_caller
  )
  RETURNING id INTO v_chain_id;

  RETURN v_chain_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_hospital_chain_register(text, text, text, text, text, numeric, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_hospital_chain_register(text, text, text, text, text, numeric, int) TO authenticated;

COMMIT;
