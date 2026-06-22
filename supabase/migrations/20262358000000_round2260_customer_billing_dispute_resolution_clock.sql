BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_billing_disputes_r2260 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  invoice_ref text NOT NULL,
  disputed_amount_rupees integer NOT NULL CHECK (disputed_amount_rupees >= 0),
  dispute_category text NOT NULL CHECK (dispute_category IN ('overcharge','duplicate_charge','service_not_rendered','wrong_part','tax_error','amc_billing','other')),
  customer_claim text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','investigating','awaiting_customer','resolved','rejected','escalated')),
  resolution_path text CHECK (resolution_path IN ('full_refund','partial_refund','credit_note','invoice_correction','no_action','goodwill_credit')),
  resolution_amount_rupees integer CHECK (resolution_amount_rupees >= 0),
  opened_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  assigned_to_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_dispute_satisfaction_r2260 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id uuid NOT NULL REFERENCES public.customer_billing_disputes_r2260(id) ON DELETE CASCADE,
  csat_rating integer NOT NULL CHECK (csat_rating BETWEEN 1 AND 5),
  would_recommend boolean NOT NULL DEFAULT false,
  feedback_text text,
  surveyed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_billing_disputes_r2260 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_dispute_satisfaction_r2260 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_billing_disputes_r2260;
CREATE POLICY founder_all ON public.customer_billing_disputes_r2260 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.customer_dispute_satisfaction_r2260;
CREATE POLICY founder_all ON public.customer_dispute_satisfaction_r2260 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_cbd_r2260_status ON public.customer_billing_disputes_r2260(status);
CREATE INDEX IF NOT EXISTS idx_cbd_r2260_opened ON public.customer_billing_disputes_r2260(opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_cds_r2260_dispute ON public.customer_dispute_satisfaction_r2260(dispute_id);

-- RPC 1: open disputes with days-open clock
CREATE OR REPLACE FUNCTION public.r2260_open_disputes()
RETURNS TABLE(invoice_ref text, customer_email text, category text, amount_rupees integer, days_open integer, status text, assigned text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.invoice_ref, p.email,
         d.dispute_category, d.disputed_amount_rupees,
         EXTRACT(DAY FROM (now() - d.opened_at))::int,
         d.status, COALESCE(d.assigned_to_email,'unassigned')
  FROM public.customer_billing_disputes_r2260 d
  JOIN public.profiles p ON p.id = d.customer_user_id
  WHERE d.status NOT IN ('resolved','rejected')
  ORDER BY d.opened_at ASC;
END; $$;

-- RPC 2: aging buckets
CREATE OR REPLACE FUNCTION public.r2260_aging_buckets()
RETURNS TABLE(bucket text, dispute_count integer, total_amount_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.label,
         (COUNT(d.id) FILTER (WHERE d.id IS NOT NULL))::int,
         COALESCE(SUM(d.disputed_amount_rupees),0)::bigint
  FROM (VALUES ('0-3 days',0,3),('4-7 days',4,7),('8-15 days',8,15),('16-30 days',16,30),('over 30 days',31,99999)) b(label,lo,hi)
  LEFT JOIN public.customer_billing_disputes_r2260 d
    ON d.status NOT IN ('resolved','rejected')
   AND EXTRACT(DAY FROM (now() - d.opened_at))::int BETWEEN b.lo AND b.hi
  GROUP BY b.label, b.lo
  ORDER BY b.lo;
END; $$;

-- RPC 3: resolution path mix
CREATE OR REPLACE FUNCTION public.r2260_resolution_path_mix()
RETURNS TABLE(path text, resolved_count integer, total_refund_rupees bigint, avg_days_to_resolve numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(d.resolution_path,'unspecified'),
         (COUNT(*))::int,
         COALESCE(SUM(d.resolution_amount_rupees),0)::bigint,
         ROUND(AVG(EXTRACT(DAY FROM (d.resolved_at - d.opened_at)))::numeric, 1)
  FROM public.customer_billing_disputes_r2260 d
  WHERE d.status = 'resolved'
  GROUP BY d.resolution_path
  ORDER BY (COUNT(*)) DESC;
END; $$;

-- RPC 4: category breakdown
CREATE OR REPLACE FUNCTION public.r2260_category_breakdown()
RETURNS TABLE(category text, open_count integer, resolved_count integer, total_disputed_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.dispute_category,
         (COUNT(*) FILTER (WHERE d.status NOT IN ('resolved','rejected')))::int,
         (COUNT(*) FILTER (WHERE d.status = 'resolved'))::int,
         COALESCE(SUM(d.disputed_amount_rupees),0)::bigint
  FROM public.customer_billing_disputes_r2260 d
  GROUP BY d.dispute_category
  ORDER BY (COUNT(*)) DESC;
END; $$;

-- RPC 5: csat post-resolution
CREATE OR REPLACE FUNCTION public.r2260_csat_post_resolution()
RETURNS TABLE(metric text, value text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'surveys_completed'::text, COUNT(*)::text FROM public.customer_dispute_satisfaction_r2260
  UNION ALL
  SELECT 'avg_csat_rating', COALESCE(ROUND(AVG(csat_rating)::numeric,2)::text,'n/a') FROM public.customer_dispute_satisfaction_r2260
  UNION ALL
  SELECT 'would_recommend_pct', COALESCE(ROUND((COUNT(*) FILTER (WHERE would_recommend))::numeric * 100 / NULLIF(COUNT(*),0), 1)::text,'n/a') FROM public.customer_dispute_satisfaction_r2260
  UNION ALL
  SELECT 'csat_5_count', (COUNT(*) FILTER (WHERE csat_rating = 5))::text FROM public.customer_dispute_satisfaction_r2260
  UNION ALL
  SELECT 'csat_low_count', (COUNT(*) FILTER (WHERE csat_rating <= 2))::text FROM public.customer_dispute_satisfaction_r2260;
END; $$;

-- RPC 6: stale disputes (over 15 days)
CREATE OR REPLACE FUNCTION public.r2260_stale_disputes()
RETURNS TABLE(invoice_ref text, customer_email text, days_open integer, amount_rupees integer, assigned text, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.invoice_ref, p.email,
         EXTRACT(DAY FROM (now() - d.opened_at))::int,
         d.disputed_amount_rupees,
         COALESCE(d.assigned_to_email,'unassigned'), d.status
  FROM public.customer_billing_disputes_r2260 d
  JOIN public.profiles p ON p.id = d.customer_user_id
  WHERE d.status NOT IN ('resolved','rejected')
    AND EXTRACT(DAY FROM (now() - d.opened_at))::int > 15
  ORDER BY d.opened_at ASC;
END; $$;

-- RPC 7: kpi summary
CREATE OR REPLACE FUNCTION public.r2260_kpi_summary()
RETURNS TABLE(metric text, value text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'total_disputes'::text, COUNT(*)::text FROM public.customer_billing_disputes_r2260
  UNION ALL
  SELECT 'open_disputes', (COUNT(*) FILTER (WHERE status NOT IN ('resolved','rejected')))::text FROM public.customer_billing_disputes_r2260
  UNION ALL
  SELECT 'resolved_disputes', (COUNT(*) FILTER (WHERE status = 'resolved'))::text FROM public.customer_billing_disputes_r2260
  UNION ALL
  SELECT 'stale_over_15d', (COUNT(*) FILTER (WHERE status NOT IN ('resolved','rejected') AND EXTRACT(DAY FROM (now()-opened_at))::int > 15))::text FROM public.customer_billing_disputes_r2260
  UNION ALL
  SELECT 'avg_resolution_days', COALESCE(ROUND(AVG(EXTRACT(DAY FROM (resolved_at - opened_at)))::numeric,1)::text,'n/a') FROM public.customer_billing_disputes_r2260 WHERE status='resolved'
  UNION ALL
  SELECT 'total_disputed_rupees', COALESCE(SUM(disputed_amount_rupees),0)::text FROM public.customer_billing_disputes_r2260
  UNION ALL
  SELECT 'total_refunded_rupees', COALESCE(SUM(resolution_amount_rupees),0)::text FROM public.customer_billing_disputes_r2260 WHERE status='resolved';
END; $$;

REVOKE ALL ON FUNCTION public.r2260_open_disputes() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2260_aging_buckets() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2260_resolution_path_mix() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2260_category_breakdown() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2260_csat_post_resolution() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2260_stale_disputes() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2260_kpi_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2260_open_disputes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2260_aging_buckets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2260_resolution_path_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2260_category_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2260_csat_post_resolution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2260_stale_disputes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2260_kpi_summary() TO authenticated;

COMMIT;
