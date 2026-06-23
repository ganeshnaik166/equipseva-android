BEGIN;

CREATE TABLE IF NOT EXISTS public.warranty_extension_offers_r2392 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  equipment_category text NOT NULL,
  original_warranty_ends_on date NOT NULL,
  offer_sent_at timestamptz NOT NULL DEFAULT now(),
  offer_channel text NOT NULL CHECK (offer_channel IN ('email','sms','whatsapp','app_push','call')),
  extension_months int NOT NULL CHECK (extension_months > 0),
  offered_price_rupees numeric(12,2) NOT NULL CHECK (offered_price_rupees >= 0),
  discount_pct numeric(5,2) NOT NULL DEFAULT 0,
  funnel_stage text NOT NULL CHECK (funnel_stage IN ('sent','viewed','clicked','cart','purchased','expired','declined')),
  viewed_at timestamptz,
  clicked_at timestamptz,
  purchased_at timestamptz,
  decline_reason text,
  final_price_rupees numeric(12,2),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wext_offers_stage_r2392 ON public.warranty_extension_offers_r2392(funnel_stage);
CREATE INDEX IF NOT EXISTS idx_wext_offers_sent_r2392 ON public.warranty_extension_offers_r2392(offer_sent_at);
CREATE INDEX IF NOT EXISTS idx_wext_offers_category_r2392 ON public.warranty_extension_offers_r2392(equipment_category);

ALTER TABLE public.warranty_extension_offers_r2392 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all_wext_offers_r2392 ON public.warranty_extension_offers_r2392
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.warranty_extension_cohort_snapshots_r2392 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cohort_month date NOT NULL,
  equipment_category text NOT NULL,
  offers_sent int NOT NULL DEFAULT 0,
  offers_viewed int NOT NULL DEFAULT 0,
  offers_clicked int NOT NULL DEFAULT 0,
  offers_purchased int NOT NULL DEFAULT 0,
  total_offered_value_rupees numeric(14,2) NOT NULL DEFAULT 0,
  total_realized_value_rupees numeric(14,2) NOT NULL DEFAULT 0,
  computed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (cohort_month, equipment_category)
);

ALTER TABLE public.warranty_extension_cohort_snapshots_r2392 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all_wext_cohort_r2392 ON public.warranty_extension_cohort_snapshots_r2392
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1. Summary KPIs
CREATE OR REPLACE FUNCTION public.wext_buy_rate_summary_r2392()
RETURNS TABLE (
  total_offers bigint,
  offers_purchased bigint,
  buy_rate_pct numeric,
  view_rate_pct numeric,
  click_rate_pct numeric,
  total_offered_value_rupees numeric,
  total_realized_value_rupees numeric,
  value_left_on_table_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE funnel_stage = 'purchased')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE funnel_stage = 'purchased') / NULLIF(COUNT(*),0), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE viewed_at IS NOT NULL) / NULLIF(COUNT(*),0), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE clicked_at IS NOT NULL) / NULLIF(COUNT(*),0), 2),
    COALESCE(SUM(offered_price_rupees), 0),
    COALESCE(SUM(final_price_rupees) FILTER (WHERE funnel_stage = 'purchased'), 0),
    COALESCE(SUM(offered_price_rupees) FILTER (WHERE funnel_stage IN ('expired','declined','sent','viewed','clicked','cart')), 0)
  FROM public.warranty_extension_offers_r2392;
END;
$$;

REVOKE ALL ON FUNCTION public.wext_buy_rate_summary_r2392() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wext_buy_rate_summary_r2392() TO authenticated;

-- 2. Funnel stages
CREATE OR REPLACE FUNCTION public.wext_funnel_stages_r2392()
RETURNS TABLE (
  funnel_stage text,
  offer_count bigint,
  stage_value_rupees numeric,
  pct_of_total numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH t AS (SELECT COUNT(*)::numeric AS total FROM public.warranty_extension_offers_r2392)
  SELECT
    o.funnel_stage::text,
    COUNT(*)::bigint,
    COALESCE(SUM(o.offered_price_rupees), 0),
    ROUND(100.0 * COUNT(*) / NULLIF((SELECT total FROM t), 0), 2)
  FROM public.warranty_extension_offers_r2392 o
  GROUP BY o.funnel_stage
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.wext_funnel_stages_r2392() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wext_funnel_stages_r2392() TO authenticated;

-- 3. Buy rate by equipment category
CREATE OR REPLACE FUNCTION public.wext_buy_rate_by_category_r2392()
RETURNS TABLE (
  equipment_category text,
  offers_sent bigint,
  offers_purchased bigint,
  buy_rate_pct numeric,
  realized_value_rupees numeric,
  value_left_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.equipment_category::text,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE o.funnel_stage = 'purchased')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE o.funnel_stage = 'purchased') / NULLIF(COUNT(*),0), 2),
    COALESCE(SUM(o.final_price_rupees) FILTER (WHERE o.funnel_stage = 'purchased'), 0),
    COALESCE(SUM(o.offered_price_rupees) FILTER (WHERE o.funnel_stage <> 'purchased'), 0)
  FROM public.warranty_extension_offers_r2392 o
  GROUP BY o.equipment_category
  ORDER BY COUNT(*) FILTER (WHERE o.funnel_stage = 'purchased') DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.wext_buy_rate_by_category_r2392() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wext_buy_rate_by_category_r2392() TO authenticated;

-- 4. Buy rate by channel
CREATE OR REPLACE FUNCTION public.wext_buy_rate_by_channel_r2392()
RETURNS TABLE (
  offer_channel text,
  offers_sent bigint,
  offers_purchased bigint,
  buy_rate_pct numeric,
  avg_days_to_purchase numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.offer_channel::text,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE o.funnel_stage = 'purchased')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE o.funnel_stage = 'purchased') / NULLIF(COUNT(*),0), 2),
    ROUND(AVG(EXTRACT(EPOCH FROM (o.purchased_at - o.offer_sent_at))/86400.0) FILTER (WHERE o.purchased_at IS NOT NULL), 2)
  FROM public.warranty_extension_offers_r2392 o
  GROUP BY o.offer_channel
  ORDER BY ROUND(100.0 * COUNT(*) FILTER (WHERE o.funnel_stage = 'purchased') / NULLIF(COUNT(*),0), 2) DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.wext_buy_rate_by_channel_r2392() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wext_buy_rate_by_channel_r2392() TO authenticated;

-- 5. Decline reasons
CREATE OR REPLACE FUNCTION public.wext_decline_reasons_r2392()
RETURNS TABLE (
  decline_reason text,
  decline_count bigint,
  lost_value_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(o.decline_reason, 'unspecified')::text,
    COUNT(*)::bigint,
    COALESCE(SUM(o.offered_price_rupees), 0)
  FROM public.warranty_extension_offers_r2392 o
  WHERE o.funnel_stage = 'declined'
  GROUP BY o.decline_reason
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.wext_decline_reasons_r2392() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wext_decline_reasons_r2392() TO authenticated;

-- 6. Recent purchases
CREATE OR REPLACE FUNCTION public.wext_recent_purchases_r2392()
RETURNS TABLE (
  purchased_at timestamptz,
  equipment_label text,
  equipment_category text,
  extension_months int,
  final_price_rupees numeric,
  offer_channel text,
  days_to_close numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.purchased_at,
    o.equipment_label::text,
    o.equipment_category::text,
    o.extension_months,
    COALESCE(o.final_price_rupees, o.offered_price_rupees),
    o.offer_channel::text,
    ROUND(EXTRACT(EPOCH FROM (o.purchased_at - o.offer_sent_at))/86400.0, 2)
  FROM public.warranty_extension_offers_r2392 o
  WHERE o.funnel_stage = 'purchased'
  ORDER BY o.purchased_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.wext_recent_purchases_r2392() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wext_recent_purchases_r2392() TO authenticated;

-- 7. Monthly cohort trend
CREATE OR REPLACE FUNCTION public.wext_monthly_cohort_trend_r2392()
RETURNS TABLE (
  cohort_month text,
  offers_sent bigint,
  offers_purchased bigint,
  buy_rate_pct numeric,
  realized_value_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(date_trunc('month', o.offer_sent_at), 'YYYY-MM')::text,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE o.funnel_stage = 'purchased')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE o.funnel_stage = 'purchased') / NULLIF(COUNT(*),0), 2),
    COALESCE(SUM(o.final_price_rupees) FILTER (WHERE o.funnel_stage = 'purchased'), 0)
  FROM public.warranty_extension_offers_r2392 o
  WHERE o.offer_sent_at >= now() - interval '6 months'
  GROUP BY date_trunc('month', o.offer_sent_at)
  ORDER BY date_trunc('month', o.offer_sent_at);
END;
$$;

REVOKE ALL ON FUNCTION public.wext_monthly_cohort_trend_r2392() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wext_monthly_cohort_trend_r2392() TO authenticated;

COMMIT;
