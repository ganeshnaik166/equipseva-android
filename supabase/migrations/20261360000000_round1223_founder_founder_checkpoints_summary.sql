BEGIN;
DROP FUNCTION IF EXISTS public.founder_founder_checkpoints_summary();
CREATE OR REPLACE FUNCTION public.founder_founder_checkpoints_summary()
RETURNS TABLE (
  days_since_launch          bigint,
  first_signup_at            timestamptz,
  lifetime_jobs_completed    bigint,
  first_job_completed_at     timestamptz,
  last_job_completed_at      timestamptz,
  lifetime_amc_signed        bigint,
  first_amc_signed_at        timestamptz,
  last_amc_signed_at         timestamptz,
  lifetime_payouts_processed bigint,
  first_payout_at            timestamptz,
  last_payout_at             timestamptz,
  founder_actions_total      bigint,
  founder_actions_7d         bigint,
  founder_actions_30d        bigint,
  distinct_ops_30d           bigint,
  last_founder_action_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_first_signup timestamptz;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT min(created_at) INTO v_first_signup FROM public.profiles;
  RETURN QUERY
  SELECT
    CASE WHEN v_first_signup IS NULL THEN 0::bigint
         ELSE greatest(1, ceil(extract(epoch FROM (now() - v_first_signup)) / 86400.0))::bigint END,
    v_first_signup,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'completed'), 0),
    (SELECT min(completed_at) FROM public.repair_jobs WHERE status = 'completed'),
    (SELECT max(completed_at) FROM public.repair_jobs WHERE status = 'completed'),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts), 0),
    (SELECT min(created_at) FROM public.amc_contracts),
    (SELECT max(created_at) FROM public.amc_contracts),
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE status IN ('processed','paid')), 0),
    (SELECT min(processed_at) FROM public.engineer_payouts WHERE status IN ('processed','paid')),
    (SELECT max(processed_at) FROM public.engineer_payouts WHERE status IN ('processed','paid')),
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log WHERE created_at >= now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT op_name)::bigint FROM public.founder_action_log WHERE created_at >= now() - interval '30 days'), 0),
    (SELECT max(created_at) FROM public.founder_action_log);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_founder_checkpoints_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_founder_checkpoints_summary() TO authenticated;
COMMIT;
