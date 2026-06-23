BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_pricing_overrides_r2372 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_id uuid,
  customer_name text NOT NULL,
  service_code text NOT NULL,
  service_name text NOT NULL,
  rate_card_price_rupees numeric(12,2) NOT NULL,
  approved_price_rupees numeric(12,2) NOT NULL,
  discount_pct numeric(6,2) GENERATED ALWAYS AS (
    CASE WHEN rate_card_price_rupees > 0
      THEN ROUND(((rate_card_price_rupees - approved_price_rupees) / rate_card_price_rupees) * 100, 2)
      ELSE 0 END
  ) STORED,
  cost_to_serve_rupees numeric(12,2) NOT NULL DEFAULT 0,
  margin_impact_rupees numeric(12,2) GENERATED ALWAYS AS (approved_price_rupees - cost_to_serve_rupees) STORED,
  justification text NOT NULL,
  category text NOT NULL DEFAULT 'strategic' CHECK (category IN ('strategic','retention','volume','competitive','goodwill','escalation')),
  recurring_exception boolean NOT NULL DEFAULT false,
  recurrence_window text,
  approved_by_profile_id uuid REFERENCES public.profiles(id),
  approved_by_email text NOT NULL,
  approved_at timestamptz NOT NULL DEFAULT now(),
  effective_from date NOT NULL DEFAULT current_date,
  effective_to date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','revoked','superseded')),
  revoked_at timestamptz,
  revoked_reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cpo_r2372_customer ON public.customer_pricing_overrides_r2372(customer_name);
CREATE INDEX IF NOT EXISTS idx_cpo_r2372_status ON public.customer_pricing_overrides_r2372(status);
CREATE INDEX IF NOT EXISTS idx_cpo_r2372_recurring ON public.customer_pricing_overrides_r2372(recurring_exception) WHERE recurring_exception = true;
CREATE INDEX IF NOT EXISTS idx_cpo_r2372_approved_at ON public.customer_pricing_overrides_r2372(approved_at DESC);

CREATE TABLE IF NOT EXISTS public.customer_pricing_override_events_r2372 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  override_id uuid NOT NULL REFERENCES public.customer_pricing_overrides_r2372(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('created','revoked','extended','renewed','flagged','reviewed','note_added')),
  actor_profile_id uuid REFERENCES public.profiles(id),
  actor_email text NOT NULL,
  notes text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cpoe_r2372_override ON public.customer_pricing_override_events_r2372(override_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cpoe_r2372_type ON public.customer_pricing_override_events_r2372(event_type);

ALTER TABLE public.customer_pricing_overrides_r2372 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_pricing_override_events_r2372 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cpo_r2372 ON public.customer_pricing_overrides_r2372;
CREATE POLICY founder_all_cpo_r2372 ON public.customer_pricing_overrides_r2372
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_cpoe_r2372 ON public.customer_pricing_override_events_r2372;
CREATE POLICY founder_all_cpoe_r2372 ON public.customer_pricing_override_events_r2372
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2372_list_overrides()
RETURNS TABLE (
  id uuid,
  customer_name text,
  service_name text,
  service_code text,
  rate_card_price_rupees numeric,
  approved_price_rupees numeric,
  discount_pct numeric,
  margin_impact_rupees numeric,
  category text,
  recurring_exception boolean,
  status text,
  approved_by_email text,
  approved_at timestamptz,
  effective_from date,
  effective_to date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.customer_name, o.service_name, o.service_code,
           o.rate_card_price_rupees, o.approved_price_rupees, o.discount_pct,
           o.margin_impact_rupees, o.category, o.recurring_exception, o.status,
           o.approved_by_email, o.approved_at, o.effective_from, o.effective_to
    FROM public.customer_pricing_overrides_r2372 o
    ORDER BY o.approved_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2372_summary()
RETURNS TABLE (
  total_overrides bigint,
  active_overrides bigint,
  recurring_count bigint,
  total_margin_impact_rupees numeric,
  avg_discount_pct numeric,
  high_discount_count bigint,
  revoked_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::bigint,
      COUNT(*) FILTER (WHERE status = 'active')::bigint,
      COUNT(*) FILTER (WHERE recurring_exception = true)::bigint,
      COALESCE(SUM(margin_impact_rupees), 0)::numeric,
      COALESCE(ROUND(AVG(discount_pct), 2), 0)::numeric,
      COUNT(*) FILTER (WHERE discount_pct >= 25)::bigint,
      COUNT(*) FILTER (WHERE status = 'revoked')::bigint
    FROM public.customer_pricing_overrides_r2372;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2372_by_category()
RETURNS TABLE (
  category text,
  override_count bigint,
  total_margin_impact_rupees numeric,
  avg_discount_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.category,
           COUNT(*)::bigint,
           COALESCE(SUM(o.margin_impact_rupees), 0)::numeric,
           COALESCE(ROUND(AVG(o.discount_pct), 2), 0)::numeric
    FROM public.customer_pricing_overrides_r2372 o
    GROUP BY o.category
    ORDER BY COUNT(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2372_top_customers()
RETURNS TABLE (
  customer_name text,
  override_count bigint,
  total_discount_rupees numeric,
  avg_discount_pct numeric,
  recurring_flag boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.customer_name,
           COUNT(*)::bigint,
           COALESCE(SUM(o.rate_card_price_rupees - o.approved_price_rupees), 0)::numeric,
           COALESCE(ROUND(AVG(o.discount_pct), 2), 0)::numeric,
           BOOL_OR(o.recurring_exception)
    FROM public.customer_pricing_overrides_r2372 o
    GROUP BY o.customer_name
    ORDER BY COUNT(*) DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2372_recurring_exceptions()
RETURNS TABLE (
  id uuid,
  customer_name text,
  service_name text,
  approved_price_rupees numeric,
  discount_pct numeric,
  recurrence_window text,
  approved_by_email text,
  approved_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.customer_name, o.service_name, o.approved_price_rupees,
           o.discount_pct, o.recurrence_window, o.approved_by_email, o.approved_at
    FROM public.customer_pricing_overrides_r2372 o
    WHERE o.recurring_exception = true AND o.status = 'active'
    ORDER BY o.approved_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2372_recent_events()
RETURNS TABLE (
  id uuid,
  override_id uuid,
  event_type text,
  actor_email text,
  notes text,
  created_at timestamptz,
  customer_name text,
  service_name text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, e.override_id, e.event_type, e.actor_email, e.notes, e.created_at,
           o.customer_name, o.service_name
    FROM public.customer_pricing_override_events_r2372 e
    JOIN public.customer_pricing_overrides_r2372 o ON o.id = e.override_id
    ORDER BY e.created_at DESC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2372_margin_leakage_by_month()
RETURNS TABLE (
  month_start date,
  override_count bigint,
  total_margin_impact_rupees numeric,
  total_discount_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', o.approved_at)::date,
           COUNT(*)::bigint,
           COALESCE(SUM(o.margin_impact_rupees), 0)::numeric,
           COALESCE(SUM(o.rate_card_price_rupees - o.approved_price_rupees), 0)::numeric
    FROM public.customer_pricing_overrides_r2372 o
    GROUP BY 1
    ORDER BY 1 DESC
    LIMIT 12;
END;
$$;

REVOKE ALL ON FUNCTION public.r2372_list_overrides() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2372_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2372_by_category() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2372_top_customers() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2372_recurring_exceptions() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2372_recent_events() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2372_margin_leakage_by_month() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2372_list_overrides() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2372_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2372_by_category() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2372_top_customers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2372_recurring_exceptions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2372_recent_events() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2372_margin_leakage_by_month() TO authenticated;

COMMIT;
