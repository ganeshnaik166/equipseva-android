BEGIN;

-- ============================================================================
-- Round 2728 — Customer Monthly Quote Conversion Funnel
-- quote × ask × discount × negotiate × close × loss reason × outcome
-- ============================================================================

-- ---------- Table 1: customer_quote_funnel_r2728 ----------
DROP TABLE IF EXISTS public.customer_quote_funnel_r2728 CASCADE;
CREATE TABLE public.customer_quote_funnel_r2728 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_ref text NOT NULL,
  month_label text NOT NULL,
  customer_name text NOT NULL,
  customer_segment text NOT NULL CHECK (customer_segment IN ('hospital','clinic','dental','diagnostic','pharma')),
  ask_amount_rupees integer NOT NULL CHECK (ask_amount_rupees > 0),
  quoted_amount_rupees integer NOT NULL CHECK (quoted_amount_rupees > 0),
  discount_pct numeric(5,2) NOT NULL CHECK (discount_pct >= 0 AND discount_pct <= 100),
  negotiation_rounds integer NOT NULL DEFAULT 0 CHECK (negotiation_rounds >= 0),
  closed_amount_rupees integer,
  outcome text NOT NULL CHECK (outcome IN ('won','lost','in_negotiation','quoted','expired')),
  loss_reason text CHECK (loss_reason IN ('price_too_high','competitor_won','no_budget','timing','spec_mismatch','no_response',NULL)),
  quote_sent_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_quote_funnel_r2728 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_quote_funnel_r2728;
CREATE POLICY founder_all ON public.customer_quote_funnel_r2728
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.customer_quote_funnel_r2728
  (quote_ref, month_label, customer_name, customer_segment, ask_amount_rupees, quoted_amount_rupees, discount_pct, negotiation_rounds, closed_amount_rupees, outcome, loss_reason, quote_sent_at, closed_at)
VALUES
  ('Q-2026-06-001','2026-06','Apollo Hyderabad','hospital',850000,820000,3.50,2,815000,'won',NULL,'2026-06-02'::date,'2026-06-08'::date),
  ('Q-2026-06-002','2026-06','SmileCare Dental','dental',120000,110000,8.30,3,NULL,'lost','price_too_high','2026-06-03'::date,'2026-06-11'::date),
  ('Q-2026-06-003','2026-06','Yashoda Clinic','clinic',340000,320000,5.90,1,318000,'won',NULL,'2026-06-04'::date,'2026-06-09'::date),
  ('Q-2026-06-004','2026-06','Vijaya Diagnostics','diagnostic',560000,540000,3.60,4,NULL,'in_negotiation',NULL,'2026-06-12'::date,NULL),
  ('Q-2026-06-005','2026-06','Rainbow Childrens','hospital',1200000,1140000,5.00,2,NULL,'lost','competitor_won','2026-06-05'::date,'2026-06-15'::date),
  ('Q-2026-06-006','2026-06','Hetero Pharma','pharma',780000,750000,3.80,3,745000,'won',NULL,'2026-06-06'::date,'2026-06-13'::date),
  ('Q-2026-06-007','2026-06','Care Hospital','hospital',460000,440000,4.30,2,NULL,'expired','no_response','2026-06-01'::date,'2026-06-20'::date);

-- ---------- Table 2: monthly_funnel_summary_r2728 ----------
DROP TABLE IF EXISTS public.monthly_funnel_summary_r2728 CASCADE;
CREATE TABLE public.monthly_funnel_summary_r2728 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL UNIQUE,
  quotes_sent integer NOT NULL CHECK (quotes_sent >= 0),
  quotes_negotiated integer NOT NULL CHECK (quotes_negotiated >= 0),
  quotes_won integer NOT NULL CHECK (quotes_won >= 0),
  quotes_lost integer NOT NULL CHECK (quotes_lost >= 0),
  total_ask_rupees bigint NOT NULL CHECK (total_ask_rupees >= 0),
  total_won_rupees bigint NOT NULL CHECK (total_won_rupees >= 0),
  avg_discount_pct numeric(5,2) NOT NULL CHECK (avg_discount_pct >= 0),
  avg_negotiation_rounds numeric(4,2) NOT NULL CHECK (avg_negotiation_rounds >= 0),
  win_rate_pct numeric(5,2) NOT NULL CHECK (win_rate_pct >= 0 AND win_rate_pct <= 100),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.monthly_funnel_summary_r2728 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.monthly_funnel_summary_r2728;
CREATE POLICY founder_all ON public.monthly_funnel_summary_r2728
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.monthly_funnel_summary_r2728
  (month_label, quotes_sent, quotes_negotiated, quotes_won, quotes_lost, total_ask_rupees, total_won_rupees, avg_discount_pct, avg_negotiation_rounds, win_rate_pct)
VALUES
  ('2026-02', 42, 28, 18, 20, 18500000, 7800000, 4.50, 2.10, 42.85),
  ('2026-03', 48, 32, 22, 22, 21200000, 9400000, 4.80, 2.30, 45.83),
  ('2026-04', 51, 36, 26, 21, 23800000, 11200000, 5.10, 2.50, 50.98),
  ('2026-05', 55, 40, 30, 22, 26100000, 12800000, 5.20, 2.40, 54.54),
  ('2026-06', 58, 44, 33, 20, 28500000, 14200000, 4.90, 2.60, 56.89);

-- ============================================================================
-- RPCs (7+ SECURITY DEFINER, founder-gated)
-- ============================================================================

-- RPC 1: funnel_kpis_r2728
DROP FUNCTION IF EXISTS public.funnel_kpis_r2728();
CREATE OR REPLACE FUNCTION public.funnel_kpis_r2728()
RETURNS TABLE (
  total_quotes integer,
  won_count integer,
  lost_count integer,
  in_negotiation_count integer,
  win_rate_pct numeric,
  avg_discount_pct numeric,
  total_won_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE outcome = 'won')::int,
    COUNT(*) FILTER (WHERE outcome = 'lost')::int,
    COUNT(*) FILTER (WHERE outcome = 'in_negotiation')::int,
    ROUND((COUNT(*) FILTER (WHERE outcome = 'won')::numeric / NULLIF(COUNT(*),0)::numeric) * 100, 2),
    ROUND(AVG(discount_pct), 2),
    COALESCE(SUM(closed_amount_rupees) FILTER (WHERE outcome = 'won'), 0)::bigint
  FROM public.customer_quote_funnel_r2728;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.funnel_kpis_r2728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.funnel_kpis_r2728() TO authenticated;

-- RPC 2: funnel_recent_quotes_r2728
DROP FUNCTION IF EXISTS public.funnel_recent_quotes_r2728();
CREATE OR REPLACE FUNCTION public.funnel_recent_quotes_r2728()
RETURNS TABLE (
  quote_ref text,
  customer_name text,
  customer_segment text,
  ask_amount_rupees integer,
  quoted_amount_rupees integer,
  discount_pct numeric,
  negotiation_rounds integer,
  outcome text,
  loss_reason text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.quote_ref, q.customer_name, q.customer_segment, q.ask_amount_rupees,
         q.quoted_amount_rupees, q.discount_pct, q.negotiation_rounds, q.outcome, q.loss_reason
  FROM public.customer_quote_funnel_r2728 q
  ORDER BY q.quote_sent_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.funnel_recent_quotes_r2728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.funnel_recent_quotes_r2728() TO authenticated;

-- RPC 3: funnel_loss_reasons_r2728
DROP FUNCTION IF EXISTS public.funnel_loss_reasons_r2728();
CREATE OR REPLACE FUNCTION public.funnel_loss_reasons_r2728()
RETURNS TABLE (loss_reason text, lost_count integer, lost_value_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.loss_reason, COUNT(*)::int, COALESCE(SUM(q.quoted_amount_rupees), 0)::bigint
  FROM public.customer_quote_funnel_r2728 q
  WHERE q.outcome IN ('lost','expired') AND q.loss_reason IS NOT NULL
  GROUP BY q.loss_reason
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.funnel_loss_reasons_r2728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.funnel_loss_reasons_r2728() TO authenticated;

-- RPC 4: funnel_segment_breakdown_r2728
DROP FUNCTION IF EXISTS public.funnel_segment_breakdown_r2728();
CREATE OR REPLACE FUNCTION public.funnel_segment_breakdown_r2728()
RETURNS TABLE (
  customer_segment text,
  quote_count integer,
  won_count integer,
  win_rate_pct numeric,
  avg_discount_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q.customer_segment,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE q.outcome = 'won')::int,
    ROUND((COUNT(*) FILTER (WHERE q.outcome = 'won')::numeric / NULLIF(COUNT(*),0)::numeric) * 100, 2),
    ROUND(AVG(q.discount_pct), 2)
  FROM public.customer_quote_funnel_r2728 q
  GROUP BY q.customer_segment
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.funnel_segment_breakdown_r2728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.funnel_segment_breakdown_r2728() TO authenticated;

-- RPC 5: funnel_monthly_trend_r2728
DROP FUNCTION IF EXISTS public.funnel_monthly_trend_r2728();
CREATE OR REPLACE FUNCTION public.funnel_monthly_trend_r2728()
RETURNS TABLE (
  month_label text,
  quotes_sent integer,
  quotes_won integer,
  win_rate_pct numeric,
  total_won_rupees bigint,
  avg_discount_pct numeric,
  avg_negotiation_rounds numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.month_label, s.quotes_sent, s.quotes_won, s.win_rate_pct,
         s.total_won_rupees, s.avg_discount_pct, s.avg_negotiation_rounds
  FROM public.monthly_funnel_summary_r2728 s
  ORDER BY s.month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.funnel_monthly_trend_r2728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.funnel_monthly_trend_r2728() TO authenticated;

-- RPC 6: funnel_negotiation_intensity_r2728
DROP FUNCTION IF EXISTS public.funnel_negotiation_intensity_r2728();
CREATE OR REPLACE FUNCTION public.funnel_negotiation_intensity_r2728()
RETURNS TABLE (
  rounds_bucket text,
  quote_count integer,
  won_count integer,
  win_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN q.negotiation_rounds = 0 THEN '0 rounds'
      WHEN q.negotiation_rounds = 1 THEN '1 round'
      WHEN q.negotiation_rounds = 2 THEN '2 rounds'
      WHEN q.negotiation_rounds = 3 THEN '3 rounds'
      ELSE '4+ rounds'
    END,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE q.outcome = 'won')::int,
    ROUND((COUNT(*) FILTER (WHERE q.outcome = 'won')::numeric / NULLIF(COUNT(*),0)::numeric) * 100, 2)
  FROM public.customer_quote_funnel_r2728 q
  GROUP BY 1
  ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.funnel_negotiation_intensity_r2728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.funnel_negotiation_intensity_r2728() TO authenticated;

-- RPC 7: funnel_ask_vs_close_r2728
DROP FUNCTION IF EXISTS public.funnel_ask_vs_close_r2728();
CREATE OR REPLACE FUNCTION public.funnel_ask_vs_close_r2728()
RETURNS TABLE (
  quote_ref text,
  customer_name text,
  ask_amount_rupees integer,
  closed_amount_rupees integer,
  drop_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.quote_ref, q.customer_name, q.ask_amount_rupees, q.closed_amount_rupees,
         ROUND(((q.ask_amount_rupees - q.closed_amount_rupees)::numeric / NULLIF(q.ask_amount_rupees,0)::numeric) * 100, 2)
  FROM public.customer_quote_funnel_r2728 q
  WHERE q.outcome = 'won' AND q.closed_amount_rupees IS NOT NULL
  ORDER BY q.closed_amount_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.funnel_ask_vs_close_r2728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.funnel_ask_vs_close_r2728() TO authenticated;

-- RPC 8: funnel_active_negotiations_r2728
DROP FUNCTION IF EXISTS public.funnel_active_negotiations_r2728();
CREATE OR REPLACE FUNCTION public.funnel_active_negotiations_r2728()
RETURNS TABLE (
  quote_ref text,
  customer_name text,
  quoted_amount_rupees integer,
  negotiation_rounds integer,
  days_open integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.quote_ref, q.customer_name, q.quoted_amount_rupees, q.negotiation_rounds,
         EXTRACT(DAY FROM (now() - q.quote_sent_at))::int
  FROM public.customer_quote_funnel_r2728 q
  WHERE q.outcome = 'in_negotiation'
  ORDER BY q.quote_sent_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.funnel_active_negotiations_r2728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.funnel_active_negotiations_r2728() TO authenticated;

COMMIT;
