-- =====================================================================
-- Round 614 — Founder AMC contract churn
-- =====================================================================
BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_churn();
CREATE OR REPLACE FUNCTION public.founder_amc_churn()
RETURNS TABLE (
  window_label  text,
  active_now    bigint,
  new_contracts bigint,
  cancelled     bigint,
  expired       bigint,
  renewal_failed bigint,
  churn_pct     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH windows(label, interval_val, ord) AS (
    VALUES ('30d', interval '30 days', 1),
           ('90d', interval '90 days', 2),
           ('180d', interval '180 days', 3)
  ),
  active AS (
    SELECT count(*)::bigint AS n FROM public.amc_contracts WHERE status = 'active'
  )
  SELECT
    w.label,
    (SELECT n FROM active),
    (SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.created_at >= now() - w.interval_val),
    (SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.status = 'cancelled' AND c.updated_at >= now() - w.interval_val),
    (SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.status = 'expired' AND c.updated_at >= now() - w.interval_val),
    (SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.status = 'renewal_failed' AND c.updated_at >= now() - w.interval_val),
    CASE WHEN (SELECT n FROM active) = 0 THEN 0::numeric
         ELSE round(
           ((SELECT count(*)::numeric FROM public.amc_contracts c
              WHERE c.status IN ('cancelled','expired','renewal_failed')
                AND c.updated_at >= now() - w.interval_val)
            / (SELECT n FROM active)::numeric) * 100.0,
           1
         )
    END AS churn_pct
  FROM windows w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_churn() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_churn() TO authenticated;
COMMIT;
