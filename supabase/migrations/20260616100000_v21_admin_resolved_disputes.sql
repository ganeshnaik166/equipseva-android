-- v2.1 PR-D40: admin ledger of recently resolved escrow disputes.
--
-- PR-D21's admin_list_open_escrow_disputes only returns rows currently
-- in_dispute. Once resolved (released | refunded) they disappear from
-- the queue — but admin still wants to look back: "what did I decide
-- last week, and why?". The dispute_resolved event lives in the
-- timeline (PR-D26) but to find it you have to know which escrow_id.
--
-- This RPC is the missing ledger view: list resolved disputes in the
-- trailing window with the resolution row's outcome + note +
-- resolved_by + amount + party names. Admin can re-open dispute
-- detail (PR-D26 timeline) for any one of them.
--
-- Default 30-day window matches the natural "this month" review
-- cadence. Bumpable via parameter (max 365).

CREATE OR REPLACE FUNCTION public.admin_list_recent_resolved_disputes(
  p_window_days int DEFAULT 30,
  p_limit       int DEFAULT 100
)
RETURNS TABLE (
  escrow_id              uuid,
  repair_job_id          uuid,
  job_number             text,
  hospital_user_id       uuid,
  hospital_name          text,
  engineer_user_id       uuid,
  engineer_name          text,
  amount_rupees          numeric,
  outcome                text,                -- 'release' | 'refund'
  resolved_at            timestamptz,
  resolved_by            uuid,
  resolved_by_name       text,
  resolution_note        text,
  dispute_reason         text,
  engineer_response      text
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
  IF p_window_days <= 0 OR p_window_days > 365 OR p_limit <= 0 OR p_limit > 500 THEN
    RAISE EXCEPTION 'window_days 1..365 / limit 1..500' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    e.id                                 AS escrow_id,
    e.repair_job_id,
    rj.job_number,
    e.hospital_user_id,
    coalesce(p_hosp.full_name, '(unnamed)') AS hospital_name,
    e.engineer_user_id,
    coalesce(p_eng.full_name, '(unnamed)')  AS engineer_name,
    e.amount_rupees,
    e.dispute_resolution                 AS outcome,
    e.dispute_resolved_at                AS resolved_at,
    e.dispute_resolved_by                AS resolved_by,
    coalesce(p_act.full_name, '(unknown)')  AS resolved_by_name,
    e.dispute_resolution_note            AS resolution_note,
    e.dispute_reason,
    e.engineer_response
    FROM public.repair_job_escrow e
    LEFT JOIN public.repair_jobs rj   ON rj.id     = e.repair_job_id
    LEFT JOIN public.profiles p_hosp  ON p_hosp.id = e.hospital_user_id
    LEFT JOIN public.profiles p_eng   ON p_eng.id  = e.engineer_user_id
    LEFT JOIN public.profiles p_act   ON p_act.id  = e.dispute_resolved_by
   WHERE e.dispute_resolved_at IS NOT NULL
     AND e.dispute_resolved_at >= now() - make_interval(days => p_window_days)
   ORDER BY e.dispute_resolved_at DESC
   LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_list_recent_resolved_disputes(int, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_list_recent_resolved_disputes(int, int) TO authenticated;
