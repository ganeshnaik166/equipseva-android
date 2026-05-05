-- v2.1 PR-C1: AMC (Annual Maintenance Contract) schema foundation.
--
-- Hospitals need monthly/regular preventive visits, not just on-demand
-- repair. The dormant `public.amcs` table existed since v1 with bare
-- columns (visits_per_year, annual_cost, status) but no RPCs, no
-- triggers, no UI surface, and zero rows. Equipment table FK'd to it
-- but also has zero rows, so we have a true clean slate.
--
-- Strategy: drop the dormant table + its single dependent FK, build a
-- richer `amc_contracts` table that supports the full AMC-full plan
-- (escrow pool in PR-C2, auto-renewal in PR-C3, SLA tracking in PR-C4,
-- multi-engineer rotation in PR-C5). Equipment.amc_id repoints to the
-- new table so equipment can still be tagged as covered-by-AMC later.
--
-- Visits are tracked as `repair_jobs` rows with `kind='maintenance'`
-- and `amc_contract_id` set — reuses the entire repair lifecycle
-- (status timeline, photos, completion, rating) instead of duplicating
-- it. Engineers see AMC visits in their existing Active Work feed.
--
-- This migration is the foundation only: schema + base RPCs + RLS.
-- Razorpay payment pool, auto-renewal cron, SLA breach detection, and
-- engineer rotation each get their own migration in subsequent PRs.

-- 1. Drop the old dormant table + its single inbound FK.
ALTER TABLE public.equipment DROP CONSTRAINT IF EXISTS equipment_amc_id_fkey;
DROP TABLE IF EXISTS public.amcs;

-- 2. Master AMC contract record. One row per active subscription.
CREATE TABLE public.amc_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  primary_engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE RESTRICT,

  -- Lifecycle. Set to 'paused' when payment pool runs negative
  -- (PR-C2 logic), 'renewal_failed' after PR-C3's 3x retry budget is
  -- exhausted, 'cancelled' on explicit termination by either party,
  -- 'expired' on natural end_date when auto_renew=false.
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','paused','expired','cancelled','renewal_failed')),

  -- Visit cadence + scope.
  visit_frequency text NOT NULL
    CHECK (visit_frequency IN ('weekly','biweekly','monthly','quarterly')),
  visits_per_year int NOT NULL CHECK (visits_per_year > 0 AND visits_per_year <= 52),
  monthly_fee_rupees numeric(10,2) NOT NULL CHECK (monthly_fee_rupees > 0),

  -- Contract dates. end_date is renewal target; auto-renewal extends it.
  start_date date NOT NULL,
  end_date date NOT NULL CHECK (end_date > start_date),

  -- Free-form scope text + structured equipment_categories array used
  -- by the matching layer (engineer must cover at least one category).
  -- equipment_categories uses the same enum as engineers.specializations.
  scope_text text,
  equipment_categories text[] NOT NULL DEFAULT ARRAY[]::text[],

  -- Auto-scheduling state. The cron helper in PR-C3 advances
  -- next_visit_at by visit_frequency on each completed visit and
  -- creates the next repair_jobs row.
  next_visit_at timestamptz,
  visits_completed int NOT NULL DEFAULT 0 CHECK (visits_completed >= 0),
  visits_scheduled int NOT NULL DEFAULT 0 CHECK (visits_scheduled >= 0),

  -- SLA targets. Used by PR-C4 to detect breaches when an AMC visit
  -- isn't assigned/started/completed within window. Defaults match
  -- "industry standard" expectations; hospital can override at create.
  response_time_emergency_hours int NOT NULL DEFAULT 4
    CHECK (response_time_emergency_hours > 0),
  response_time_standard_hours int NOT NULL DEFAULT 24
    CHECK (response_time_standard_hours > 0),

  -- Auto-renewal config. Renewal_term_months = how far end_date
  -- advances on a successful renewal charge.
  auto_renew boolean NOT NULL DEFAULT true,
  renewal_term_months int NOT NULL DEFAULT 12
    CHECK (renewal_term_months > 0 AND renewal_term_months <= 36),

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX amc_contracts_hospital_status_idx
  ON public.amc_contracts (hospital_user_id, status);
CREATE INDEX amc_contracts_engineer_status_idx
  ON public.amc_contracts (primary_engineer_id, status);
-- Cron in PR-C3 scans this for due renewals + due visits.
CREATE INDEX amc_contracts_next_visit_idx
  ON public.amc_contracts (next_visit_at) WHERE status = 'active';
CREATE INDEX amc_contracts_end_date_active_idx
  ON public.amc_contracts (end_date) WHERE status = 'active' AND auto_renew = true;

-- 3. Engineer rotation list. Primary is mirrored on amc_contracts for
-- fast queries; secondary/fallback engineers live here. PR-C5 wires
-- the auto-rotation logic when primary is unavailable.
CREATE TABLE public.amc_engineer_rotation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE RESTRICT,
  -- 1 = primary (mirror of amc_contracts.primary_engineer_id, kept for
  -- uniform rotation queries), 2..N = fallbacks in priority order.
  priority int NOT NULL CHECK (priority >= 1),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (amc_contract_id, engineer_id),
  UNIQUE (amc_contract_id, priority)
);

CREATE INDEX amc_engineer_rotation_lookup_idx
  ON public.amc_engineer_rotation (amc_contract_id, priority) WHERE active = true;

-- 4. Extend repair_jobs so AMC visits live in the same table as
-- on-demand repairs. The kind discriminator + nullable amc_contract_id
-- let the existing repair flow render maintenance jobs unchanged
-- while the AMC UI can filter to its own.
ALTER TABLE public.repair_jobs
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'repair'
    CHECK (kind IN ('repair','maintenance')),
  ADD COLUMN IF NOT EXISTS amc_contract_id uuid REFERENCES public.amc_contracts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS amc_visit_number int CHECK (amc_visit_number IS NULL OR amc_visit_number > 0);

CREATE INDEX IF NOT EXISTS repair_jobs_amc_contract_idx
  ON public.repair_jobs (amc_contract_id) WHERE amc_contract_id IS NOT NULL;

-- 5. Repoint equipment.amc_id to the new table (orphaned column kept
-- for backwards compat — equipment table is empty so no rewrite cost).
ALTER TABLE public.equipment
  ADD CONSTRAINT equipment_amc_id_fkey FOREIGN KEY (amc_id)
  REFERENCES public.amc_contracts(id) ON DELETE SET NULL;

-- 6. RLS — hospital sees own contracts; engineer sees rotations
-- they're in OR contracts where they're primary; admin/founder bypass.
ALTER TABLE public.amc_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amc_engineer_rotation ENABLE ROW LEVEL SECURITY;

CREATE POLICY amc_contracts_hospital_own ON public.amc_contracts
  FOR SELECT
  USING (auth.uid() = hospital_user_id);

CREATE POLICY amc_contracts_engineer_assigned ON public.amc_contracts
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.engineers e
      WHERE e.id = primary_engineer_id AND e.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.amc_engineer_rotation r
      JOIN public.engineers e ON e.id = r.engineer_id
      WHERE r.amc_contract_id = amc_contracts.id
        AND e.user_id = auth.uid()
        AND r.active = true
    )
  );

CREATE POLICY amc_contracts_admin_all ON public.amc_contracts
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()) OR public.is_founder())
  WITH CHECK (public.is_admin(auth.uid()) OR public.is_founder());

CREATE POLICY amc_rotation_visible_to_party ON public.amc_engineer_rotation
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
      WHERE c.id = amc_engineer_rotation.amc_contract_id
        AND (
          c.hospital_user_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.engineers e
            WHERE e.id = amc_engineer_rotation.engineer_id AND e.user_id = auth.uid()
          )
          OR public.is_admin(auth.uid())
          OR public.is_founder()
        )
    )
  );

-- Writes always go through SECURITY DEFINER RPCs below; clients have
-- no direct INSERT/UPDATE/DELETE grants on these tables.
REVOKE INSERT, UPDATE, DELETE ON public.amc_contracts FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.amc_engineer_rotation FROM anon, authenticated;

-- 7. Base RPCs. Payment pool create + auto-renewal + SLA + rotation
-- helpers all land in subsequent PRs; what's here is the minimum to
-- create + list + cancel a contract.

CREATE OR REPLACE FUNCTION public.create_amc_contract(
  p_primary_engineer_id uuid,
  p_visit_frequency text,
  p_visits_per_year int,
  p_monthly_fee_rupees numeric,
  p_start_date date,
  p_end_date date,
  p_equipment_categories text[],
  p_scope_text text DEFAULT NULL,
  p_response_time_emergency_hours int DEFAULT 4,
  p_response_time_standard_hours int DEFAULT 24,
  p_auto_renew boolean DEFAULT true,
  p_renewal_term_months int DEFAULT 12,
  p_fallback_engineer_ids uuid[] DEFAULT ARRAY[]::uuid[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_contract_id uuid;
  v_engineer_verified boolean;
  v_fallback_id uuid;
  v_priority int := 2;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  -- Guard: primary engineer must be a verified engineers row.
  SELECT (verification_status::text = 'verified') INTO v_engineer_verified
    FROM public.engineers WHERE id = p_primary_engineer_id;
  IF v_engineer_verified IS NULL OR NOT v_engineer_verified THEN
    RAISE EXCEPTION 'primary_engineer must be verified' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.amc_contracts (
    hospital_user_id, primary_engineer_id, status,
    visit_frequency, visits_per_year, monthly_fee_rupees,
    start_date, end_date,
    scope_text, equipment_categories,
    next_visit_at,
    response_time_emergency_hours, response_time_standard_hours,
    auto_renew, renewal_term_months
  ) VALUES (
    v_caller_id, p_primary_engineer_id, 'active',
    p_visit_frequency, p_visits_per_year, p_monthly_fee_rupees,
    p_start_date, p_end_date,
    p_scope_text, coalesce(p_equipment_categories, ARRAY[]::text[]),
    -- First visit nudge: same as start_date at noon local. Cron will
    -- pick this up and create the first repair_jobs row.
    p_start_date::timestamptz + interval '12 hours',
    p_response_time_emergency_hours, p_response_time_standard_hours,
    p_auto_renew, p_renewal_term_months
  ) RETURNING id INTO v_contract_id;

  -- Mirror primary into rotation table so PR-C5's lookup is uniform.
  INSERT INTO public.amc_engineer_rotation (amc_contract_id, engineer_id, priority, active)
  VALUES (v_contract_id, p_primary_engineer_id, 1, true);

  -- Insert fallback engineers in passed order.
  IF p_fallback_engineer_ids IS NOT NULL THEN
    FOREACH v_fallback_id IN ARRAY p_fallback_engineer_ids LOOP
      IF v_fallback_id IS NOT NULL AND v_fallback_id <> p_primary_engineer_id THEN
        INSERT INTO public.amc_engineer_rotation (amc_contract_id, engineer_id, priority, active)
        VALUES (v_contract_id, v_fallback_id, v_priority, true)
        ON CONFLICT (amc_contract_id, engineer_id) DO NOTHING;
        v_priority := v_priority + 1;
      END IF;
    END LOOP;
  END IF;

  RETURN v_contract_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.create_amc_contract(
  uuid, text, int, numeric, date, date, text[], text, int, int, boolean, int, uuid[]
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_amc_contract(
  uuid, text, int, numeric, date, date, text[], text, int, int, boolean, int, uuid[]
) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_amc_contracts_for_hospital()
RETURNS TABLE (
  id uuid,
  primary_engineer_id uuid,
  primary_engineer_name text,
  status text,
  visit_frequency text,
  visits_per_year int,
  monthly_fee_rupees numeric,
  start_date date,
  end_date date,
  scope_text text,
  equipment_categories text[],
  next_visit_at timestamptz,
  visits_completed int,
  visits_scheduled int,
  auto_renew boolean,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    c.id, c.primary_engineer_id, coalesce(p.full_name, '(unnamed)') AS primary_engineer_name,
    c.status::text, c.visit_frequency, c.visits_per_year, c.monthly_fee_rupees,
    c.start_date, c.end_date, c.scope_text, c.equipment_categories,
    c.next_visit_at, c.visits_completed, c.visits_scheduled,
    c.auto_renew, c.created_at
  FROM public.amc_contracts c
  LEFT JOIN public.engineers e ON e.id = c.primary_engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE c.hospital_user_id = auth.uid()
  ORDER BY c.created_at DESC;
$$;
GRANT EXECUTE ON FUNCTION public.list_amc_contracts_for_hospital() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_amc_contracts_for_engineer()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  status text,
  visit_frequency text,
  visits_per_year int,
  monthly_fee_rupees numeric,
  start_date date,
  end_date date,
  scope_text text,
  equipment_categories text[],
  next_visit_at timestamptz,
  visits_completed int,
  visits_scheduled int,
  is_primary boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT DISTINCT ON (c.id)
    c.id, c.hospital_user_id, coalesce(hp.full_name, '(unnamed)') AS hospital_name,
    c.status::text, c.visit_frequency, c.visits_per_year, c.monthly_fee_rupees,
    c.start_date, c.end_date, c.scope_text, c.equipment_categories,
    c.next_visit_at, c.visits_completed, c.visits_scheduled,
    (e.user_id = auth.uid()) AS is_primary
  FROM public.amc_contracts c
  JOIN public.engineers e ON e.id = c.primary_engineer_id
  LEFT JOIN public.profiles hp ON hp.id = c.hospital_user_id
  LEFT JOIN public.amc_engineer_rotation r ON r.amc_contract_id = c.id
  LEFT JOIN public.engineers er ON er.id = r.engineer_id
  WHERE e.user_id = auth.uid()
     OR (er.user_id = auth.uid() AND r.active = true)
  ORDER BY c.id, c.created_at DESC;
$$;
GRANT EXECUTE ON FUNCTION public.list_amc_contracts_for_engineer() TO authenticated;

CREATE OR REPLACE FUNCTION public.cancel_amc_contract(
  p_contract_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_hospital_id uuid;
  v_primary_engineer_user_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT c.hospital_user_id, e.user_id
    INTO v_hospital_id, v_primary_engineer_user_id
    FROM public.amc_contracts c
    JOIN public.engineers e ON e.id = c.primary_engineer_id
    WHERE c.id = p_contract_id;

  IF v_hospital_id IS NULL THEN
    RAISE EXCEPTION 'contract not found' USING ERRCODE = '42704';
  END IF;

  -- Either party (hospital or primary engineer) can cancel; admin
  -- bypass falls through via the policy.
  IF v_caller <> v_hospital_id
     AND v_caller IS DISTINCT FROM v_primary_engineer_user_id
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not a party to this contract' USING ERRCODE = '42501';
  END IF;

  UPDATE public.amc_contracts
     SET status = 'cancelled',
         auto_renew = false,
         updated_at = now(),
         scope_text = CASE
           WHEN p_reason IS NULL OR p_reason = '' THEN scope_text
           ELSE coalesce(scope_text, '') ||
                E'\n[cancelled: ' || left(p_reason, 200) || ']'
         END
   WHERE id = p_contract_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.cancel_amc_contract(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_amc_contract(uuid, text) TO authenticated;
