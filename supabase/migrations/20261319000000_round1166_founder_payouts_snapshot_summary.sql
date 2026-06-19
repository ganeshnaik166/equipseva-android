BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_payouts_snapshot_summary()
RETURNS TABLE (
  total_all_time         bigint,
  queued_now             bigint,
  queued_inr_now         numeric,
  processing_now         bigint,
  processed_30d          bigint,
  processed_inr_30d      numeric,
  failed_30d             bigint,
  failed_inr_30d         numeric,
  stuck_over_7d          bigint,
  stuck_inr_over_7d      numeric,
  distinct_engs_paid_30d bigint,
  avg_amount_30d         numeric,
  queued_today           bigint,
  processed_today        bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE status = 'queued'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status = 'queued'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE status = 'processing'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE status IN ('processed','paid') AND queued_at >= now() - interval '30 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status IN ('processed','paid') AND queued_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE status = 'failed' AND queued_at >= now() - interval '30 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status = 'failed' AND queued_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE status IN ('queued','processing') AND queued_at < now() - interval '7 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status IN ('queued','processing') AND queued_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(DISTINCT engineer_user_id)::bigint FROM public.engineer_payouts WHERE status IN ('processed','paid') AND queued_at >= now() - interval '30 days'), 0),
    coalesce((SELECT round(avg(amount_rupees)::numeric, 2) FROM public.engineer_payouts WHERE status IN ('processed','paid') AND queued_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE queued_at >= v_today_start AND queued_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE status IN ('processed','paid') AND queued_at >= v_today_start AND queued_at < v_today_end), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_snapshot_summary() TO authenticated;
COMMIT;
