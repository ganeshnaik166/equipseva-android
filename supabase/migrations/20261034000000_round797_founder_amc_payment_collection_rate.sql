BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_payment_collection_rate();
CREATE OR REPLACE FUNCTION public.founder_amc_payment_collection_rate()
RETURNS TABLE (
  window_label    text,
  total_orders    bigint,
  paid_orders     bigint,
  failed_orders   bigint,
  collection_pct  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  )
  SELECT
    w.label,
    coalesce((SELECT count(*)::bigint FROM public.amc_payment_orders o WHERE o.created_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_payment_orders o WHERE o.status='paid' AND o.created_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_payment_orders o WHERE o.status='failed' AND o.created_at >= w.cutoff), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.amc_payment_orders o WHERE o.created_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.amc_payment_orders o WHERE o.status='paid' AND o.created_at >= w.cutoff)
           / (SELECT count(*)::numeric FROM public.amc_payment_orders o WHERE o.created_at >= w.cutoff)
           * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_payment_collection_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_payment_collection_rate() TO authenticated;
COMMIT;
