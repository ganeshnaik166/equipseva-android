BEGIN;
DROP FUNCTION IF EXISTS public.founder_disputes_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_disputes_snapshot_summary()
RETURNS TABLE (
  total_all_time           bigint,
  open_now                 bigint,
  stuck_over_7d            bigint,
  drafts_now               bigint,
  accepted_30d             bigint,
  rejected_30d             bigint,
  withdrawn_30d            bigint,
  resolution_pct_30d       numeric,
  filer_hospital_30d       bigint,
  filer_engineer_30d       bigint,
  open_money_at_stake_inr  numeric,
  avg_resolve_hours_30d    numeric,
  created_today            bigint,
  resolved_today           bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_submitted_30d bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_submitted_30d
    FROM public.dispute_evidence_packs WHERE submitted_at IS NOT NULL AND submitted_at >= now() - interval '30 days';
  IF v_submitted_30d IS NULL THEN v_submitted_30d := 0; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE submitted_at IS NOT NULL), 0),
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE status = 'submitted' AND mediator_decision_at IS NULL), 0),
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE status = 'submitted' AND mediator_decision_at IS NULL AND submitted_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE status = 'draft'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE status = 'accepted' AND submitted_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE status = 'rejected' AND submitted_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE status = 'withdrawn' AND submitted_at >= now() - interval '30 days'), 0),
    CASE WHEN v_submitted_30d = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM public.dispute_evidence_packs
                                      WHERE submitted_at IS NOT NULL AND submitted_at >= now() - interval '30 days'
                                        AND mediator_decision_at IS NOT NULL), 0) / v_submitted_30d, 1) END,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE filer_role = 'hospital' AND submitted_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE filer_role = 'engineer' AND submitted_at >= now() - interval '30 days'), 0),
    coalesce((SELECT sum(total_money_at_stake_rupees)::numeric FROM public.dispute_evidence_packs WHERE status = 'submitted' AND mediator_decision_at IS NULL), 0),
    coalesce((SELECT round(avg(extract(epoch FROM (mediator_decision_at - submitted_at)) / 3600.0)::numeric, 1)
              FROM public.dispute_evidence_packs
              WHERE mediator_decision_at IS NOT NULL AND submitted_at IS NOT NULL
                AND submitted_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE submitted_at >= v_today_start AND submitted_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE mediator_decision_at >= v_today_start AND mediator_decision_at < v_today_end), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_disputes_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_disputes_snapshot_summary() TO authenticated;
COMMIT;
