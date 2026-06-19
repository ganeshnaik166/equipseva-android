BEGIN;

-- =====================================================================
-- Round 1175 — founder_supervised_training_snapshot_summary
-- =====================================================================
-- Domain: supervised-training
-- Primary table: public.supervised_job_assignments (r576)
--
-- WHY:
--   Supervised training (r576) gates engineer tier promotion. 10+ sub
--   RPCs cover funnel/outcomes/active/success/by-week — but no single
--   snapshot of active trainees, pass rate, and pipeline depth that
--   founder can read in one glance. r1182 fills that gap.
--
-- COLUMNS USED (verified against r576 schema):
--   id, trainee_user_id, supervisor_user_id, repair_job_id,
--   trainee_tier_at_assignment, supervisor_tier_at_assignment,
--   status (pending_supervisor_accept | active | completed_successful
--           | completed_failed | declined | revoked),
--   signoff_outcome (successful | failed | disputed),
--   requested_at, accepted_at, completed_at, signoff_at
--
-- STUCK ALERTS:
--   - pending_over_48h: supervisor never accepts/declines
--   - active_over_14d: trainee shadowing dragged on with no signoff
--
-- IST-day boundary used for today_* KPIs.

DROP FUNCTION IF EXISTS public.founder_supervised_training_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_supervised_training_snapshot_summary()
RETURNS TABLE (
  total_all_time            bigint,
  pending_accept_now        bigint,
  active_now                bigint,
  pending_over_48h          bigint,
  active_over_14d           bigint,
  completed_successful_all  bigint,
  completed_failed_all      bigint,
  declined_all              bigint,
  revoked_all               bigint,
  requested_30d             bigint,
  signoff_successful_30d    bigint,
  signoff_failed_30d        bigint,
  requested_today           bigint,
  pass_rate_30d_pct         numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_succ_30d    bigint;
  v_fail_30d    bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT count(*)::bigint INTO v_succ_30d
    FROM public.supervised_job_assignments
   WHERE status = 'completed_successful'
     AND signoff_at >= now() - interval '30 days';
  IF v_succ_30d IS NULL THEN v_succ_30d := 0; END IF;

  SELECT count(*)::bigint INTO v_fail_30d
    FROM public.supervised_job_assignments
   WHERE status = 'completed_failed'
     AND signoff_at >= now() - interval '30 days';
  IF v_fail_30d IS NULL THEN v_fail_30d := 0; END IF;

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments
               WHERE status = 'pending_supervisor_accept'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments
               WHERE status = 'active'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments
               WHERE status = 'pending_supervisor_accept'
                 AND requested_at < now() - interval '48 hours'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments
               WHERE status = 'active'
                 AND coalesce(accepted_at, requested_at) < now() - interval '14 days'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments
               WHERE status = 'completed_successful'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments
               WHERE status = 'completed_failed'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments
               WHERE status = 'declined'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments
               WHERE status = 'revoked'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments
               WHERE requested_at >= now() - interval '30 days'), 0),
    v_succ_30d,
    v_fail_30d,
    coalesce((SELECT count(*)::bigint
                FROM public.supervised_job_assignments
               WHERE requested_at >= v_today_start
                 AND requested_at <  v_today_end), 0),
    CASE WHEN (v_succ_30d + v_fail_30d) = 0 THEN 0::numeric
         ELSE round(v_succ_30d::numeric * 100.0 / (v_succ_30d + v_fail_30d), 1)
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_supervised_training_snapshot_summary()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_supervised_training_snapshot_summary()
  TO authenticated;

COMMIT;
