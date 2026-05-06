-- v2.1 PR-D21: admin/founder ops-queue list RPCs.
--
-- v2.1 shipped four admin pain points without UI:
--   * escrow disputes (admin_resolve_escrow_dispute exists, no list)
--   * AMC engineer-rotation exhaustion (amc_admin_escalations table
--     populated by trigger; no SECDEF list, just RLS-direct read)
--   * cash-flagged engineers (cash_auto_suspended_at column exists,
--     clear_cash_auto_suspension exists, no list)
--   * parts-cost outliers (list_parts_cost_outliers shipped in
--     PR-D13; no resolve action — adding here for parity)
--
-- This migration ships the missing list RPCs + a small resolve helper
-- for AMC escalations so the founder admin dashboard can surface each
-- queue with one round-trip per tab. Outlier list reuses the existing
-- list_parts_cost_outliers — no new RPC needed for that one.
--
-- All gated via is_admin() OR is_founder(). Anonymous access blocked
-- via REVOKE FROM PUBLIC — anon role cannot enumerate.

-- ---------------------------------------------------------------------
-- 1. admin_list_open_escrow_disputes()
-- ---------------------------------------------------------------------
-- Escrows currently in_dispute. Joined to repair_jobs for the job
-- number and to profiles for the two parties' display names so the
-- list renders without N+1 lookups.

CREATE OR REPLACE FUNCTION public.admin_list_open_escrow_disputes()
RETURNS TABLE (
  escrow_id           uuid,
  repair_job_id       uuid,
  job_number          text,
  hospital_user_id    uuid,
  hospital_name       text,
  engineer_user_id    uuid,
  engineer_name       text,
  amount_rupees       numeric,
  dispute_opened_at   timestamptz,
  dispute_reason      text,
  scheduled_release_at timestamptz
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
    e.id                             AS escrow_id,
    e.repair_job_id,
    rj.job_number,
    e.hospital_user_id,
    coalesce(p_hosp.full_name, '(unnamed)') AS hospital_name,
    e.engineer_user_id,
    coalesce(p_eng.full_name, '(unnamed)')  AS engineer_name,
    e.amount_rupees,
    e.dispute_opened_at,
    e.dispute_reason,
    e.scheduled_release_at
    FROM public.repair_job_escrow e
    LEFT JOIN public.repair_jobs rj   ON rj.id     = e.repair_job_id
    LEFT JOIN public.profiles p_hosp  ON p_hosp.id = e.hospital_user_id
    LEFT JOIN public.profiles p_eng   ON p_eng.id  = e.engineer_user_id
   WHERE e.status = 'in_dispute'
   ORDER BY e.dispute_opened_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_list_open_escrow_disputes() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_list_open_escrow_disputes() TO authenticated;

-- ---------------------------------------------------------------------
-- 2. admin_list_open_amc_escalations()
-- ---------------------------------------------------------------------
-- amc_admin_escalations rows where resolved_at IS NULL. Joined to
-- amc_contracts + repair_jobs so the row carries hospital + visit
-- context inline.

CREATE OR REPLACE FUNCTION public.admin_list_open_amc_escalations()
RETURNS TABLE (
  escalation_id     uuid,
  amc_contract_id   uuid,
  hospital_user_id  uuid,
  hospital_name     text,
  visit_id          uuid,
  visit_number      int,
  reason            text,
  notes             text,
  created_at        timestamptz
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
    esc.id                            AS escalation_id,
    esc.amc_contract_id,
    c.hospital_user_id,
    coalesce(p.full_name, '(unnamed)') AS hospital_name,
    esc.visit_id,
    rj.amc_visit_number               AS visit_number,
    esc.reason,
    esc.notes,
    esc.created_at
    FROM public.amc_admin_escalations esc
    LEFT JOIN public.amc_contracts c  ON c.id  = esc.amc_contract_id
    LEFT JOIN public.profiles p       ON p.id  = c.hospital_user_id
    LEFT JOIN public.repair_jobs rj   ON rj.id = esc.visit_id
   WHERE esc.resolved_at IS NULL
   ORDER BY esc.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_list_open_amc_escalations() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_list_open_amc_escalations() TO authenticated;

-- ---------------------------------------------------------------------
-- 3. admin_resolve_amc_escalation(id, notes)
-- ---------------------------------------------------------------------
-- Marks an escalation resolved (resolved_at = now(), resolved_by =
-- caller). Optionally appends a free-text note. No state machine —
-- escalations are advisory; the actual fix (engineer added to
-- rotation, contract paused, etc.) is whatever the admin did
-- out-of-band before flipping this row.

CREATE OR REPLACE FUNCTION public.admin_resolve_amc_escalation(
  p_escalation_id uuid,
  p_notes         text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_existing record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_existing
    FROM public.amc_admin_escalations
   WHERE id = p_escalation_id
   FOR UPDATE;
  IF v_existing IS NULL THEN
    RAISE EXCEPTION 'escalation not found' USING ERRCODE = '02000';
  END IF;
  IF v_existing.resolved_at IS NOT NULL THEN
    RAISE EXCEPTION 'already resolved at %', v_existing.resolved_at USING ERRCODE = '22023';
  END IF;

  UPDATE public.amc_admin_escalations
     SET resolved_at = now(),
         resolved_by = v_caller,
         notes       = coalesce(
                         CASE WHEN p_notes IS NULL OR length(trim(p_notes)) = 0
                              THEN v_existing.notes
                              ELSE coalesce(v_existing.notes || E'\n---\n', '') || p_notes
                         END,
                         v_existing.notes
                       )
   WHERE id = p_escalation_id;

  RETURN p_escalation_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_resolve_amc_escalation(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_resolve_amc_escalation(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 4. admin_list_cash_suspended_engineers()
-- ---------------------------------------------------------------------
-- Engineers currently auto-suspended for cash-payment flags
-- (cash_auto_suspended_at IS NOT NULL). Includes the 90-day flag
-- count for context — admin sees "suspended @ 3 flags" without a
-- second round-trip.

CREATE OR REPLACE FUNCTION public.admin_list_cash_suspended_engineers()
RETURNS TABLE (
  engineer_id                 uuid,
  user_id                     uuid,
  full_name                   text,
  cash_auto_suspended_at      timestamptz,
  cash_auto_suspension_reason text,
  flag_count_90d              int
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
    e.id                                AS engineer_id,
    e.user_id,
    coalesce(p.full_name, '(unnamed)')  AS full_name,
    e.cash_auto_suspended_at,
    e.cash_auto_suspension_reason,
    coalesce((
      SELECT count(*)::int FROM public.cash_survey_responses csr
       WHERE csr.engineer_id = e.id
         AND csr.response = 'asked_cash'
         AND csr.responded_at >= now() - interval '90 days'
    ), 0) AS flag_count_90d
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
   WHERE e.cash_auto_suspended_at IS NOT NULL
   ORDER BY e.cash_auto_suspended_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_list_cash_suspended_engineers() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_list_cash_suspended_engineers() TO authenticated;
