BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_net_of_tds();
CREATE OR REPLACE FUNCTION public.founder_payouts_net_of_tds()
RETURNS TABLE (
  window_label  text,
  gross_rupees  numeric,
  tds_withheld  numeric,
  net_paid      numeric,
  effective_tds_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('30d'::text, 1, now() - interval '30 days'),
      ('90d'::text, 2, now() - interval '90 days'),
      ('365d'::text, 3, now() - interval '365 days')
  )
  SELECT
    w.label,
    coalesce((SELECT round(sum(p.amount_paise)::numeric / 100.0, 2)
              FROM public.engineer_payouts p
              WHERE p.status='processed' AND p.processed_at >= w.cutoff), 0)::numeric,
    coalesce((SELECT sum(t.tds_rupees)::numeric FROM public.tds_deductions t WHERE t.created_at >= w.cutoff), 0)::numeric,
    coalesce((SELECT sum(t.net_payable_rupees)::numeric FROM public.tds_deductions t WHERE t.created_at >= w.cutoff), 0)::numeric,
    CASE WHEN coalesce((SELECT sum(t.gross_rupees) FROM public.tds_deductions t WHERE t.created_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           coalesce((SELECT sum(t.tds_rupees)::numeric FROM public.tds_deductions t WHERE t.created_at >= w.cutoff), 0)
           / coalesce((SELECT sum(t.gross_rupees)::numeric FROM public.tds_deductions t WHERE t.created_at >= w.cutoff), 1)
           * 100.0, 2)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_net_of_tds() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_net_of_tds() TO authenticated;
COMMIT;
