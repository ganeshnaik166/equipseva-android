BEGIN;

DROP FUNCTION IF EXISTS public.founder_founder_action_followups_summary();

CREATE OR REPLACE FUNCTION public.founder_founder_action_followups_summary()
RETURNS TABLE (
  total_followups_aged_7d        bigint,
  total_followups_aged_30d       bigint,
  open_disputes_over_7d          bigint,
  open_disputes_over_30d         bigint,
  spot_audit_fails_over_7d       bigint,
  spot_audit_fails_over_30d      bigint,
  stalled_dsrs_over_7d           bigint,
  stalled_dsrs_over_30d          bigint,
  idle_code_red_over_7d          bigint,
  idle_code_red_over_30d         bigint,
  oldest_dispute_age_days        numeric,
  oldest_dsr_age_days            numeric,
  oldest_code_red_age_days       numeric,
  oldest_spot_audit_fail_age_days numeric,
  founder_actions_7d             bigint,
  founder_actions_today          bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_disputes_7d  bigint;
  v_disputes_30d bigint;
  v_audits_7d    bigint;
  v_audits_30d   bigint;
  v_dsrs_7d      bigint;
  v_dsrs_30d     bigint;
  v_cr_7d        bigint;
  v_cr_30d       bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT coalesce(count(*)::bigint, 0) INTO v_disputes_7d
    FROM public.dispute_evidence_packs
   WHERE status = 'submitted'
     AND mediator_decision_at IS NULL
     AND submitted_at IS NOT NULL
     AND submitted_at < now() - interval '7 days';

  SELECT coalesce(count(*)::bigint, 0) INTO v_disputes_30d
    FROM public.dispute_evidence_packs
   WHERE status = 'submitted'
     AND mediator_decision_at IS NULL
     AND submitted_at IS NOT NULL
     AND submitted_at < now() - interval '30 days';

  SELECT coalesce(count(*)::bigint, 0) INTO v_audits_7d
    FROM public.spot_audit_responses
   WHERE rating <= 2
     AND responded_at < now() - interval '7 days'
     AND responded_at >= now() - interval '180 days';

  SELECT coalesce(count(*)::bigint, 0) INTO v_audits_30d
    FROM public.spot_audit_responses
   WHERE rating <= 2
     AND responded_at < now() - interval '30 days'
     AND responded_at >= now() - interval '180 days';

  SELECT coalesce(count(*)::bigint, 0) INTO v_dsrs_7d
    FROM public.dsr_reports
   WHERE status = 'pending_hospital_sign'
     AND updated_at < now() - interval '7 days';

  SELECT coalesce(count(*)::bigint, 0) INTO v_dsrs_30d
    FROM public.dsr_reports
   WHERE status = 'pending_hospital_sign'
     AND updated_at < now() - interval '30 days';

  SELECT coalesce(count(*)::bigint, 0) INTO v_cr_7d
    FROM public.code_red_requests
   WHERE status NOT IN ('resolved','timed_out','cancelled')
     AND created_at < now() - interval '7 days';

  SELECT coalesce(count(*)::bigint, 0) INTO v_cr_30d
    FROM public.code_red_requests
   WHERE status NOT IN ('resolved','timed_out','cancelled')
     AND created_at < now() - interval '30 days';

  RETURN QUERY
  SELECT
    (v_disputes_7d + v_audits_7d + v_dsrs_7d + v_cr_7d),
    (v_disputes_30d + v_audits_30d + v_dsrs_30d + v_cr_30d),
    v_disputes_7d,
    v_disputes_30d,
    v_audits_7d,
    v_audits_30d,
    v_dsrs_7d,
    v_dsrs_30d,
    v_cr_7d,
    v_cr_30d,
    coalesce((SELECT round(extract(epoch FROM (now() - min(submitted_at))) / 86400.0, 1)::numeric
                FROM public.dispute_evidence_packs
               WHERE status = 'submitted'
                 AND mediator_decision_at IS NULL
                 AND submitted_at IS NOT NULL), 0)::numeric,
    coalesce((SELECT round(extract(epoch FROM (now() - min(updated_at))) / 86400.0, 1)::numeric
                FROM public.dsr_reports
               WHERE status = 'pending_hospital_sign'), 0)::numeric,
    coalesce((SELECT round(extract(epoch FROM (now() - min(created_at))) / 86400.0, 1)::numeric
                FROM public.code_red_requests
               WHERE status NOT IN ('resolved','timed_out','cancelled')), 0)::numeric,
    coalesce((SELECT round(extract(epoch FROM (now() - min(responded_at))) / 86400.0, 1)::numeric
                FROM public.spot_audit_responses
               WHERE rating <= 2
                 AND responded_at >= now() - interval '180 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint
                FROM public.founder_action_log
               WHERE created_at >= now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint
                FROM public.founder_action_log
               WHERE created_at >= v_today_start
                 AND created_at <  v_today_end), 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_founder_action_followups_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_founder_action_followups_summary() TO authenticated;

COMMIT;
