-- v2.1 follow-up RPCs flagged in PR-C6 (#268).
--
-- Three small RPCs the Android UI already has slots for but couldn't
-- hook up because the read paths didn't exist:
--   1. list_amc_pool_ledger — drives the Pool tab transaction list
--      (currently shows running balance + hint copy only)
--   2. list_amc_visits_for_contract — drives the Visits tab
--      (currently points users at Active Work / My bookings)
--   3. count_completed_jobs_with_engineer — drives the real
--      repeat-booking nudge frequency rule
--      (currently the nudge only fires from a test prime path)
--
-- All three are SECURITY DEFINER + caller-gated. RLS handles the same
-- thing transitively but explicit gates here keep the surface tight
-- when other call sites land later.

-- 1. Pool ledger detail rows -----------------------------------------

CREATE OR REPLACE FUNCTION public.list_amc_pool_ledger(
  p_contract_id uuid,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  ledger_kind text,
  amount_rupees numeric,
  balance_after numeric,
  source_payment_order_id uuid,
  source_visit_id uuid,
  source_breach_id uuid,
  description text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  -- Hospital party check via SECDEF helper (same one PR-C1 hotfix
  -- introduced) keeps this rule consistent across all AMC reads.
  IF NOT public.amc_contract_is_party(p_contract_id, v_caller)
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not a party to this contract' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    pl.id,
    pl.ledger_kind,
    pl.amount_rupees,
    pl.balance_after,
    pl.source_payment_order_id,
    pl.source_visit_id,
    pl.source_breach_id,
    pl.description,
    pl.created_at
  FROM public.amc_payment_pool pl
  WHERE pl.amc_contract_id = p_contract_id
  ORDER BY pl.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_amc_pool_ledger(uuid, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_amc_pool_ledger(uuid, int) TO authenticated;

-- 2. Visits for a contract -------------------------------------------

CREATE OR REPLACE FUNCTION public.list_amc_visits_for_contract(
  p_contract_id uuid,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  job_number text,
  status text,
  amc_visit_number int,
  scheduled_date date,
  scheduled_time_slot text,
  engineer_id uuid,
  engineer_name text,
  equipment_type text,
  created_at timestamptz,
  completed_at timestamptz,
  hospital_rating int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT public.amc_contract_is_party(p_contract_id, v_caller)
     AND NOT public.amc_rotation_includes_user(p_contract_id, v_caller)
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not a party to this contract' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    rj.id,
    rj.job_number,
    rj.status::text,
    rj.amc_visit_number,
    rj.scheduled_date,
    rj.scheduled_time_slot,
    rj.engineer_id,
    coalesce(p.full_name, '(unnamed)') AS engineer_name,
    rj.equipment_type::text,
    rj.created_at,
    rj.completed_at,
    rj.hospital_rating
  FROM public.repair_jobs rj
  LEFT JOIN public.engineers e ON e.id = rj.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE rj.amc_contract_id = p_contract_id
    AND rj.kind = 'maintenance'
  ORDER BY coalesce(rj.amc_visit_number, 0) DESC, rj.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_amc_visits_for_contract(uuid, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_amc_visits_for_contract(uuid, int) TO authenticated;

-- 3. Repeat-booking count for the nudge gate -------------------------
--
-- Returns: how many completed repair jobs has THIS hospital had with
-- THIS engineer (engineer's user_id, not engineers.id, because the
-- repeat-nudge fires from EngineerPublicProfileScreen which only
-- knows the engineer row id — we resolve to user_id internally).
--
-- Hospital must be the caller. Counts both kinds (repair + maintenance)
-- since a hospital that's done 3 maintenance visits with the engineer
-- is at least as locked-in as 3 one-offs.

CREATE OR REPLACE FUNCTION public.count_completed_jobs_with_engineer(
  p_engineer_id uuid
)
RETURNS int
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT count(*)::int
  FROM public.repair_jobs rj
  WHERE rj.hospital_user_id = auth.uid()
    AND rj.engineer_id = p_engineer_id
    AND rj.status::text = 'completed';
$$;
REVOKE EXECUTE ON FUNCTION public.count_completed_jobs_with_engineer(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.count_completed_jobs_with_engineer(uuid) TO authenticated;
