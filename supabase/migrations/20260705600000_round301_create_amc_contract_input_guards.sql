-- Round 301 — guard create_amc_contract against array-bomb + unverified
-- fallback engineers.
--
-- The original create_amc_contract (20260509100000) accepts:
--   * p_equipment_categories text[]
--   * p_fallback_engineer_ids uuid[]
--
-- Neither has a length cap. The FOREACH loop at line 251 then INSERTs
-- one row per fallback into amc_engineer_rotation. A malicious or
-- buggy caller passing 100K ids would either time out the RPC or
-- bloat the rotation table.
--
-- Original primary-engineer check only validates the primary is
-- verified. Fallback engineers are inserted into the rotation
-- regardless of verification_status. assign_next_available_amc_engineer
-- correctly skips unverified engineers at runtime (filters
-- verification_status='verified'), so this is a quality-of-rotation
-- issue rather than a security one — but easy to fix at the gate.
--
-- This migration recreates the RPC with:
--   * array_length cap of 32 on each array (sane upper bound for a
--     single contract — typical rotation has 1-5 engineers, typical
--     equipment scope has 1-10 categories).
--   * verified-status guard on every fallback engineer id.

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
  v_fallback_verified boolean;
  v_priority int := 2;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  -- Round 301: cap array inputs.
  IF coalesce(array_length(p_equipment_categories, 1), 0) > 32 THEN
    RAISE EXCEPTION 'too many equipment_categories (max 32)' USING ERRCODE = '22023';
  END IF;
  IF coalesce(array_length(p_fallback_engineer_ids, 1), 0) > 32 THEN
    RAISE EXCEPTION 'too many fallback_engineer_ids (max 32)' USING ERRCODE = '22023';
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
    p_start_date::timestamptz + interval '12 hours',
    p_response_time_emergency_hours, p_response_time_standard_hours,
    p_auto_renew, p_renewal_term_months
  ) RETURNING id INTO v_contract_id;

  INSERT INTO public.amc_engineer_rotation (amc_contract_id, engineer_id, priority, active)
  VALUES (v_contract_id, p_primary_engineer_id, 1, true);

  IF p_fallback_engineer_ids IS NOT NULL THEN
    FOREACH v_fallback_id IN ARRAY p_fallback_engineer_ids LOOP
      IF v_fallback_id IS NOT NULL AND v_fallback_id <> p_primary_engineer_id THEN
        -- Round 301: enforce verified status on each fallback. The
        -- runtime assigner already filters unverified engineers out,
        -- but rejecting at create-time gives the hospital a clearer
        -- error instead of "rotation works but never picks engineer X".
        SELECT (verification_status::text = 'verified') INTO v_fallback_verified
          FROM public.engineers WHERE id = v_fallback_id;
        IF v_fallback_verified IS NULL OR NOT v_fallback_verified THEN
          RAISE EXCEPTION 'fallback engineer % is not verified', v_fallback_id
            USING ERRCODE = '22023';
        END IF;

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
