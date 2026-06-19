BEGIN;
DROP FUNCTION IF EXISTS public.founder_escrow_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_escrow_snapshot_summary()
RETURNS TABLE (
  total_all_time            bigint,
  pending_payment_now       bigint,
  held_now                  bigint,
  held_inr_now              numeric,
  in_dispute_now            bigint,
  in_dispute_inr_now        numeric,
  stuck_held_over_14d       bigint,
  stuck_inr_over_14d        numeric,
  released_30d              bigint,
  released_inr_30d          numeric,
  refunded_30d              bigint,
  refunded_inr_30d          numeric,
  refund_rate_pct_30d       numeric,
  scheduled_release_7d      bigint,
  scheduled_release_inr_7d  numeric,
  avg_amount_30d            numeric,
  created_30d               bigint,
  released_today            bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_terminal_30d bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_terminal_30d
    FROM public.repair_job_escrow
    WHERE status IN ('released','refunded')
      AND coalesce(released_at, refunded_at) >= now() - interval '30 days';
  IF v_terminal_30d IS NULL THEN v_terminal_30d := 0; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'pending'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'held'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.repair_job_escrow WHERE status = 'held'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'in_dispute'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.repair_job_escrow WHERE status = 'in_dispute'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'held' AND created_at < now() - interval '14 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.repair_job_escrow WHERE status = 'held' AND created_at < now() - interval '14 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'released' AND released_at >= now() - interval '30 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.repair_job_escrow WHERE status = 'released' AND released_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'refunded' AND refunded_at >= now() - interval '30 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.repair_job_escrow WHERE status = 'refunded' AND refunded_at >= now() - interval '30 days'), 0),
    CASE WHEN v_terminal_30d = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM public.repair_job_escrow
                                      WHERE status = 'refunded' AND refunded_at >= now() - interval '30 days'), 0)
                    / v_terminal_30d, 1) END,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'held' AND scheduled_release_at IS NOT NULL AND scheduled_release_at < now() + interval '7 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.repair_job_escrow WHERE status = 'held' AND scheduled_release_at IS NOT NULL AND scheduled_release_at < now() + interval '7 days'), 0),
    coalesce((SELECT round(avg(amount_rupees)::numeric, 2) FROM public.repair_job_escrow WHERE created_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'released' AND released_at >= v_today_start AND released_at < v_today_end), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_escrow_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_escrow_snapshot_summary() TO authenticated;
COMMIT;
