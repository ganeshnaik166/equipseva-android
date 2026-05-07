-- v2.1 PR-D27: AMC escalation detail drill-down.
--
-- The escalation queue (PR-D21) shows row-level reason + notes only.
-- To resolve fairly the founder needs:
--   * contract scope (visit cadence, equipment categories, status)
--   * visit context (which visit number, due when)
--   * rotation roster (handled separately by list_amc_rotation, which
--     already accepts admin/founder via PR #270)
--
-- This RPC bundles the first two into one SELECT so the detail screen
-- renders without a chained round-trip. Rotation is loaded in parallel
-- by the existing list_amc_rotation RPC.

CREATE OR REPLACE FUNCTION public.admin_amc_escalation_detail(
  p_escalation_id uuid
)
RETURNS TABLE (
  escalation_id              uuid,
  amc_contract_id            uuid,
  visit_id                   uuid,
  reason                     text,
  notes                      text,
  resolved_at                timestamptz,
  created_at                 timestamptz,
  -- Contract context.
  hospital_user_id           uuid,
  hospital_name              text,
  contract_status            text,
  visit_frequency            text,
  monthly_fee_rupees         numeric,
  next_visit_at              timestamptz,
  contract_end_date          date,
  -- Visit context (NULL when escalation is contract-level).
  visit_number               int,
  visit_status               text,
  visit_scheduled_date       date,
  visit_equipment_type       text
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
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    esc.id                              AS escalation_id,
    esc.amc_contract_id,
    esc.visit_id,
    esc.reason,
    esc.notes,
    esc.resolved_at,
    esc.created_at,
    c.hospital_user_id,
    coalesce(p.full_name, '(unnamed)')  AS hospital_name,
    c.status::text                      AS contract_status,
    c.visit_frequency,
    c.monthly_fee_rupees,
    c.next_visit_at,
    c.end_date                          AS contract_end_date,
    rj.amc_visit_number                 AS visit_number,
    rj.status::text                     AS visit_status,
    rj.scheduled_date                   AS visit_scheduled_date,
    rj.equipment_type::text             AS visit_equipment_type
    FROM public.amc_admin_escalations esc
    LEFT JOIN public.amc_contracts c  ON c.id  = esc.amc_contract_id
    LEFT JOIN public.profiles p       ON p.id  = c.hospital_user_id
    LEFT JOIN public.repair_jobs rj   ON rj.id = esc.visit_id
   WHERE esc.id = p_escalation_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_amc_escalation_detail(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_amc_escalation_detail(uuid) TO authenticated;
