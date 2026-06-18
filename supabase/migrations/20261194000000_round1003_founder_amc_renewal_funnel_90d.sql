BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_funnel_90d();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_funnel_90d()
RETURNS TABLE (
  stage           text,
  stage_order     int,
  contracts       bigint,
  total_mrr_inr   numeric,
  pct_of_due      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_due bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- Denominator: contracts whose end_date fell in the last 90d (renewal was due)
  SELECT count(*)::bigint INTO v_due
  FROM public.amc_contracts c
  WHERE c.end_date IS NOT NULL
    AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date - 90
    AND c.end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date;
  IF v_due IS NULL THEN v_due := 0; END IF;

  RETURN QUERY
  WITH due AS (
    SELECT *
    FROM public.amc_contracts c
    WHERE c.end_date IS NOT NULL
      AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date - 90
      AND c.end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date
  ),
  stages AS (
    SELECT 'Due (denominator)'::text     AS stage, 0 AS stage_order,
           count(*)::bigint              AS contracts,
           coalesce(sum(amount_inr),0)::numeric AS total_mrr_inr FROM due
    UNION ALL
    SELECT 'Notify stage 1 sent', 1,
           count(*) FILTER (WHERE renewal_notifications_sent >= 1)::bigint,
           coalesce(sum(amount_inr) FILTER (WHERE renewal_notifications_sent >= 1),0)::numeric FROM due
    UNION ALL
    SELECT 'Notify stage 2 sent', 2,
           count(*) FILTER (WHERE renewal_notifications_sent >= 2)::bigint,
           coalesce(sum(amount_inr) FILTER (WHERE renewal_notifications_sent >= 2),0)::numeric FROM due
    UNION ALL
    SELECT 'Notify stage 3 sent', 3,
           count(*) FILTER (WHERE renewal_notifications_sent >= 3)::bigint,
           coalesce(sum(amount_inr) FILTER (WHERE renewal_notifications_sent >= 3),0)::numeric FROM due
    UNION ALL
    SELECT 'Renewed (status=active and end_date pushed forward)', 4,
           count(*) FILTER (WHERE status = 'active')::bigint,
           coalesce(sum(amount_inr) FILTER (WHERE status = 'active'),0)::numeric FROM due
    UNION ALL
    SELECT 'Expired (never renewed)', 5,
           count(*) FILTER (WHERE status = 'expired')::bigint,
           coalesce(sum(amount_inr) FILTER (WHERE status = 'expired'),0)::numeric FROM due
  )
  SELECT
    s.stage,
    s.stage_order,
    s.contracts,
    s.total_mrr_inr,
    CASE WHEN v_due = 0 THEN 0::numeric
         ELSE round(100.0 * s.contracts / v_due, 1)
    END AS pct_of_due
  FROM stages s
  ORDER BY s.stage_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_funnel_90d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_funnel_90d() TO authenticated;
COMMIT;
