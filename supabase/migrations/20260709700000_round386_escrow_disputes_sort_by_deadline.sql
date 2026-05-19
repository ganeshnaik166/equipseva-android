-- Round 386 — admin_list_open_escrow_disputes: sort by approaching
-- auto-release deadline first.
--
-- Current ORDER BY dispute_opened_at DESC sorts by recency. But the
-- scheduled_release_at column already on the response is the actual
-- urgency cue — an open dispute scheduled to auto-release in 6h needs
-- founder attention more than one opened yesterday but with a week to
-- run. Match r376/r377/r385 pattern.
--
-- New order:
--   1. scheduled_release_at ASC NULLS LAST — soonest auto-release first.
--   2. dispute_opened_at DESC — recency tie-break.

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
   -- Round 386 — auto-release deadline first, recency tie-break.
   ORDER BY e.scheduled_release_at ASC NULLS LAST,
            e.dispute_opened_at DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_list_open_escrow_disputes() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_list_open_escrow_disputes() TO authenticated;
