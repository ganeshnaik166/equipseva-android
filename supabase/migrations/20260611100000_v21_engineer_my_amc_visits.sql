-- v2.1 PR-D33: engineer-side AMC visit list.
--
-- Engineers get push when assigned to an AMC visit (PR-C5
-- amc_visit_assigned), but the app has no list view of their AMC
-- commitments. They have to dig through the general repair-job list
-- and mentally filter to kind='maintenance'. That kills the AMC
-- product story for the engineer side.
--
-- This RPC returns the engineer's assigned AMC visits in the last
-- 12 months (default; capped via parameter), pre-joined to the
-- contract + hospital + breach summary so the screen renders one
-- LazyColumn without per-row lookups.
--
-- breach_count: open SLA breaches on the visit. 0 = clean. >0 = the
-- engineer should see this visit prominently flagged in red.

CREATE OR REPLACE FUNCTION public.engineer_my_amc_visits(
  p_window_days int DEFAULT 365,
  p_limit       int DEFAULT 100
)
RETURNS TABLE (
  visit_id           uuid,
  job_number         text,
  amc_contract_id    uuid,
  hospital_user_id   uuid,
  hospital_name      text,
  visit_number       int,
  status             text,
  scheduled_date     date,
  completed_at       timestamptz,
  equipment_type     text,
  breach_count       int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller     uuid := auth.uid();
  v_engineer_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF p_window_days <= 0 OR p_limit <= 0 OR p_limit > 500 THEN
    RAISE EXCEPTION 'window_days must be > 0 and limit in 1..500' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_engineer_id
    FROM public.engineers
   WHERE user_id = v_caller
   LIMIT 1;

  -- Not an engineer -> empty result. UI shows the empty-state.
  IF v_engineer_id IS NULL THEN RETURN; END IF;

  RETURN QUERY
  SELECT
    rj.id                                AS visit_id,
    rj.job_number,
    rj.amc_contract_id,
    rj.hospital_user_id,
    coalesce(p.full_name, '(unnamed)')   AS hospital_name,
    rj.amc_visit_number                  AS visit_number,
    rj.status::text                      AS status,
    rj.scheduled_date,
    rj.completed_at,
    rj.equipment_type::text              AS equipment_type,
    coalesce((
      SELECT count(*)::int FROM public.amc_sla_breaches b
       WHERE b.visit_id = rj.id
         AND b.resolved_at IS NULL
    ), 0)                                 AS breach_count
    FROM public.repair_jobs rj
    LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
   WHERE rj.engineer_id = v_engineer_id
     AND rj.kind::text = 'maintenance'
     AND rj.amc_contract_id IS NOT NULL
     AND (
       rj.scheduled_date IS NULL
       OR rj.scheduled_date >= (now() - make_interval(days => p_window_days))::date
     )
   ORDER BY
     CASE WHEN rj.status::text IN ('completed','cancelled') THEN 1 ELSE 0 END,
     coalesce(rj.scheduled_date, current_date) DESC
   LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_my_amc_visits(int, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_my_amc_visits(int, int) TO authenticated;
