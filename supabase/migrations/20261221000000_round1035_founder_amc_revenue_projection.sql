BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_revenue_projection();
CREATE OR REPLACE FUNCTION public.founder_amc_revenue_projection()
RETURNS TABLE (
  metric            text,
  metric_order      int,
  value_inr         numeric,
  notes             text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_active_mrr        numeric := 0;
  v_expiring_30d_mrr  numeric := 0;
  v_expiring_60d_mrr  numeric := 0;
  v_expiring_90d_mrr  numeric := 0;
  v_new_30d_mrr       numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT coalesce(sum(amount_inr), 0)::numeric INTO v_active_mrr
  FROM public.amc_contracts WHERE status = 'active';

  SELECT coalesce(sum(amount_inr), 0)::numeric INTO v_expiring_30d_mrr
  FROM public.amc_contracts
  WHERE status = 'active'
    AND end_date IS NOT NULL
    AND end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 30;

  SELECT coalesce(sum(amount_inr), 0)::numeric INTO v_expiring_60d_mrr
  FROM public.amc_contracts
  WHERE status = 'active'
    AND end_date IS NOT NULL
    AND end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 60;

  SELECT coalesce(sum(amount_inr), 0)::numeric INTO v_expiring_90d_mrr
  FROM public.amc_contracts
  WHERE status = 'active'
    AND end_date IS NOT NULL
    AND end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 90;

  SELECT coalesce(sum(amount_inr), 0)::numeric INTO v_new_30d_mrr
  FROM public.amc_contracts
  WHERE status IN ('active','paused')
    AND created_at >= now() - interval '30 days';

  RETURN QUERY
  VALUES
    ('Current MRR (active contracts)'::text, 1, v_active_mrr, 'baseline'::text),
    ('MRR expiring next 30d', 2, v_expiring_30d_mrr, 'at risk if no renewal'),
    ('MRR expiring next 60d', 3, v_expiring_60d_mrr, 'medium-term risk'),
    ('MRR expiring next 90d', 4, v_expiring_90d_mrr, 'long-term risk'),
    ('New MRR added last 30d', 5, v_new_30d_mrr, 'growth signal'),
    ('Projected MRR 30d forward (active − expiring30 + new30)', 6,
      v_active_mrr - v_expiring_30d_mrr + v_new_30d_mrr, 'if no renewals + same growth'),
    ('Projected MRR 90d forward (active − expiring90 + 3×new30)', 7,
      v_active_mrr - v_expiring_90d_mrr + 3 * v_new_30d_mrr, 'optimistic — renewals = 0');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_revenue_projection() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_revenue_projection() TO authenticated;
COMMIT;
