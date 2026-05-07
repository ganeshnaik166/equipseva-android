-- v2.1 PR-D41: hospital self-view of their own escrow disputes.
--
-- Today the hospital files a dispute (PR-D4 dispute_repair_job_escrow)
-- and gets per-event pushes (PR-D22 opened, PR-D28 resolved). They
-- have no in-app history view of what they've filed + what the
-- admin's outcomes were. That's:
--   * a transparency gap (hospital may have missed a resolution push)
--   * a soft self-check ("I've filed 5 disputes this year, 1 upheld
--     — maybe pause before filing the 6th")
--
-- This RPC returns the caller-hospital's dispute history in the
-- trailing window. Caller mapped via auth.uid -> escrow.hospital_user_id.
-- Engineer-side mirror lands separately if/when needed.

CREATE OR REPLACE FUNCTION public.hospital_my_disputes(
  p_window_days int DEFAULT 365,
  p_limit       int DEFAULT 100
)
RETURNS TABLE (
  escrow_id          uuid,
  repair_job_id      uuid,
  job_number         text,
  engineer_user_id   uuid,
  engineer_name      text,
  amount_rupees      numeric,
  status             text,                 -- escrow status (in_dispute / released / refunded)
  outcome            text,                 -- dispute_resolution: 'release' / 'refund' / NULL when still open
  dispute_opened_at  timestamptz,
  dispute_resolved_at timestamptz,
  dispute_reason     text,
  resolution_note    text
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
    e.engineer_user_id,
    coalesce(p_eng.full_name, '(unnamed)') AS engineer_name,
    e.amount_rupees,
    e.status                            AS status,
    e.dispute_resolution                AS outcome,
    e.dispute_opened_at,
    e.dispute_resolved_at,
    e.dispute_reason,
    e.dispute_resolution_note           AS resolution_note
    FROM public.repair_job_escrow e
    LEFT JOIN public.repair_jobs rj  ON rj.id    = e.repair_job_id
    LEFT JOIN public.profiles p_eng  ON p_eng.id = e.engineer_user_id
   WHERE e.hospital_user_id = v_caller
     AND e.dispute_opened_at IS NOT NULL
     AND e.dispute_opened_at >= now() - make_interval(days => p_window_days)
   ORDER BY e.dispute_opened_at DESC
   LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.hospital_my_disputes(int, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.hospital_my_disputes(int, int) TO authenticated;
