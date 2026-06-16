-- Round 719 — fix /unmatched-jobs status filter
--
-- r661 filtered repair_jobs.status IN ('posted','open') but the actual
-- enum is ('requested','assigned','in_progress','completed','cancelled')
-- per the v21 + AMC visit creators. Result: the page silently showed 0
-- rows forever. Fix: filter on 'requested' (no engineer yet) and confirm
-- still no accepted bid (defensive).
BEGIN;
DROP FUNCTION IF EXISTS public.founder_unmatched_jobs_7d();
CREATE OR REPLACE FUNCTION public.founder_unmatched_jobs_7d()
RETURNS TABLE (
  job_id            uuid,
  job_number        text,
  hospital_user_id  uuid,
  hospital_name     text,
  created_at        timestamptz,
  days_open         int,
  status            text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    rj.id,
    rj.job_number,
    rj.hospital_user_id,
    coalesce(p.full_name, '(hospital)'),
    rj.created_at,
    (extract(epoch FROM (now() - rj.created_at))::int / 86400),
    rj.status
  FROM public.repair_jobs rj
  LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  WHERE rj.created_at < now() - interval '7 days'
    AND rj.status = 'requested'
    AND NOT EXISTS (
      SELECT 1 FROM public.repair_job_bids b
      WHERE b.repair_job_id = rj.id AND b.status = 'accepted'
    )
  ORDER BY rj.created_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_unmatched_jobs_7d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_unmatched_jobs_7d() TO authenticated;
COMMIT;
