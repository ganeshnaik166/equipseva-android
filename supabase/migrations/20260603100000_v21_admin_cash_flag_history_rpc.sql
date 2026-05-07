-- v2.1 PR-D25: admin cash-flag history drill-down.
--
-- Admin sees "3 flags / 90d" on the cash-suspended engineer queue
-- (PR-D21) but no context — which hospitals reported, on which jobs,
-- when. Without that, "Clear suspension" is a coin flip.
--
-- This RPC returns every asked_cash response on the engineer in the
-- last 365 days (wider than the 90d window the auto-suspend uses, so
-- admin can see whether the suspension is a fresh pattern or a long-
-- running issue). Joined to repair_jobs (job_number, completed_at)
-- and profiles (hospital_name) so the screen renders without N+1
-- lookups.

CREATE OR REPLACE FUNCTION public.admin_engineer_cash_flag_history(
  p_engineer_id uuid
)
RETURNS TABLE (
  response_id      uuid,
  repair_job_id    uuid,
  job_number       text,
  hospital_user_id uuid,
  hospital_name    text,
  response         text,
  responded_at     timestamptz,
  completed_at     timestamptz
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
    csr.id                              AS response_id,
    csr.repair_job_id,
    rj.job_number,
    csr.hospital_user_id,
    coalesce(p.full_name, '(unnamed)')  AS hospital_name,
    csr.response,
    csr.responded_at,
    rj.completed_at
    FROM public.cash_survey_responses csr
    LEFT JOIN public.repair_jobs rj ON rj.id = csr.repair_job_id
    LEFT JOIN public.profiles    p  ON p.id  = csr.hospital_user_id
   WHERE csr.engineer_id = p_engineer_id
     AND csr.responded_at >= now() - interval '365 days'
   ORDER BY csr.responded_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_engineer_cash_flag_history(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_engineer_cash_flag_history(uuid) TO authenticated;
