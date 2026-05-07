-- v2.1 PR-D42: engineer self-view of disputes received.
--
-- Symmetric mirror of PR-D41's hospital_my_disputes. Hospital can see
-- the disputes they filed; engineer should see the disputes that were
-- filed against them. Same transparency rationale:
--   * Engineer may have missed a resolution push.
--   * Engineer can self-track their dispute received pattern (how many
--     released to them, refunded, still open) — an honest signal of
--     their professional standing.
--
-- Caller mapped via auth.uid -> escrow.engineer_user_id. Returns the
-- hospital_name + reason + engineer's own response (if they posted
-- one via PR-D29) + admin's resolution note (if resolved).

CREATE OR REPLACE FUNCTION public.engineer_my_disputes(
  p_window_days int DEFAULT 365,
  p_limit       int DEFAULT 100
)
RETURNS TABLE (
  escrow_id           uuid,
  repair_job_id       uuid,
  job_number          text,
  hospital_user_id    uuid,
  hospital_name       text,
  amount_rupees       numeric,
  status              text,
  outcome             text,                -- dispute_resolution: 'release' / 'refund' / NULL while open
  dispute_opened_at   timestamptz,
  dispute_resolved_at timestamptz,
  dispute_reason      text,
  engineer_response   text,
  resolution_note     text
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
  IF p_window_days <= 0 OR p_window_days > 730 OR p_limit <= 0 OR p_limit > 500 THEN
    RAISE EXCEPTION 'window_days 1..730 / limit 1..500' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    e.id                                AS escrow_id,
    e.repair_job_id,
    rj.job_number,
    e.hospital_user_id,
    coalesce(p_hosp.full_name, '(unnamed)') AS hospital_name,
    e.amount_rupees,
    e.status                            AS status,
    e.dispute_resolution                AS outcome,
    e.dispute_opened_at,
    e.dispute_resolved_at,
    e.dispute_reason,
    e.engineer_response,
    e.dispute_resolution_note           AS resolution_note
    FROM public.repair_job_escrow e
    LEFT JOIN public.repair_jobs rj   ON rj.id     = e.repair_job_id
    LEFT JOIN public.profiles p_hosp  ON p_hosp.id = e.hospital_user_id
   WHERE e.engineer_user_id = v_caller
     AND e.dispute_opened_at IS NOT NULL
     AND e.dispute_opened_at >= now() - make_interval(days => p_window_days)
   ORDER BY e.dispute_opened_at DESC
   LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_my_disputes(int, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_my_disputes(int, int) TO authenticated;
