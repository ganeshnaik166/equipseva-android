BEGIN;
DROP FUNCTION IF EXISTS public.founder_payout_success_funnel_90d();
CREATE OR REPLACE FUNCTION public.founder_payout_success_funnel_90d()
RETURNS TABLE (
  stage           text,
  stage_order     int,
  payouts         bigint,
  total_inr       numeric,
  pct_of_queued   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_q bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_q
  FROM public.engineer_payouts
  WHERE queued_at >= now() - interval '90 days';
  IF v_q IS NULL THEN v_q := 0; END IF;

  RETURN QUERY
  WITH cohort AS (
    SELECT * FROM public.engineer_payouts
    WHERE queued_at >= now() - interval '90 days'
  ),
  stages AS (
    SELECT 'Queued (denominator)'::text   AS stage, 0 AS stage_order,
           count(*)::bigint                AS payouts,
           coalesce(sum(amount_inr),0)::numeric AS total_inr FROM cohort
    UNION ALL
    SELECT 'Processing', 1,
           count(*) FILTER (WHERE status = 'processing')::bigint,
           coalesce(sum(amount_inr) FILTER (WHERE status = 'processing'),0)::numeric FROM cohort
    UNION ALL
    SELECT 'Processed ✓', 2,
           count(*) FILTER (WHERE status IN ('processed','paid'))::bigint,
           coalesce(sum(amount_inr) FILTER (WHERE status IN ('processed','paid')),0)::numeric FROM cohort
    UNION ALL
    SELECT 'Failed ✗', 3,
           count(*) FILTER (WHERE status = 'failed')::bigint,
           coalesce(sum(amount_inr) FILTER (WHERE status = 'failed'),0)::numeric FROM cohort
    UNION ALL
    SELECT 'Still queued (no progress)', 4,
           count(*) FILTER (WHERE status = 'queued')::bigint,
           coalesce(sum(amount_inr) FILTER (WHERE status = 'queued'),0)::numeric FROM cohort
  )
  SELECT
    s.stage,
    s.stage_order,
    s.payouts,
    s.total_inr,
    CASE WHEN v_q = 0 THEN 0::numeric
         ELSE round(100.0 * s.payouts / v_q, 1)
    END AS pct_of_queued
  FROM stages s
  ORDER BY s.stage_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payout_success_funnel_90d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payout_success_funnel_90d() TO authenticated;
COMMIT;
