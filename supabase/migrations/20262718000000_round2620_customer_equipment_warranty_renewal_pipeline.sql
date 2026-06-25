-- Round 2620: Customer Equipment Warranty Renewal Pipeline
-- Tracks expiring warranties, renewal opportunities, win probabilities, and realized outcomes.

CREATE TABLE IF NOT EXISTS public.customer_warranty_renewals_r2620 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  warranty_end_date date NOT NULL,
  days_to_expiry int NOT NULL DEFAULT 0,
  renewal_value_rupees bigint NOT NULL DEFAULT 0 CHECK (renewal_value_rupees >= 0),
  win_probability_pct int NOT NULL DEFAULT 50 CHECK (win_probability_pct BETWEEN 0 AND 100),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','quoted','won','lost','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.warranty_renewal_outcomes_r2620 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warranty_id uuid NOT NULL REFERENCES public.customer_warranty_renewals_r2620(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('renewed','lapsed','upgraded','declined')),
  revenue_realized_rupees bigint NOT NULL DEFAULT 0 CHECK (revenue_realized_rupees >= 0),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cwr_r2620_status ON public.customer_warranty_renewals_r2620(status);
CREATE INDEX IF NOT EXISTS idx_cwr_r2620_expiry ON public.customer_warranty_renewals_r2620(warranty_end_date);
CREATE INDEX IF NOT EXISTS idx_wro_r2620_warranty ON public.warranty_renewal_outcomes_r2620(warranty_id);
CREATE INDEX IF NOT EXISTS idx_wro_r2620_observed ON public.warranty_renewal_outcomes_r2620(observed_at DESC);

ALTER TABLE public.customer_warranty_renewals_r2620 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warranty_renewal_outcomes_r2620 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_warranty_renewals_r2620;
CREATE POLICY founder_all ON public.customer_warranty_renewals_r2620
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.warranty_renewal_outcomes_r2620;
CREATE POLICY founder_all ON public.warranty_renewal_outcomes_r2620
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.customer_warranty_renewals_r2620 (equipment_label, warranty_end_date, days_to_expiry, renewal_value_rupees, win_probability_pct, owner_email, status, notes) VALUES
  ('Philips CT Scanner Brilliance 64', (now() + interval '12 days')::date, 12, 480000, 75, 'sales1@equipseva.in', 'quoted', 'AMC quote sent; awaiting hospital board approval'),
  ('GE Logiq P9 Ultrasound', (now() + interval '28 days')::date, 28, 165000, 60, 'sales2@equipseva.in', 'monitoring', 'Customer comparing with OEM direct AMC'),
  ('Siemens MAGNETOM Avanto MRI', (now() + interval '45 days')::date, 45, 1250000, 55, 'sales1@equipseva.in', 'monitoring', 'High-value renewal; needs CFO meeting'),
  ('Mindray BeneHeart D6 Defibrillator', (now() - interval '5 days')::date, -5, 42000, 90, 'sales3@equipseva.in', 'won', 'Renewed for 24 months; auto-debit setup'),
  ('Drager Fabius Plus Anaesthesia', (now() - interval '15 days')::date, -15, 88000, 0, 'sales2@equipseva.in', 'lost', 'Lost to OEM; price gap 18 percent');

INSERT INTO public.warranty_renewal_outcomes_r2620 (warranty_id, observed_at, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, now() - interval '5 days', 'renewed', 42000, owner_email, 'done', 'Annual renewal closed'
FROM public.customer_warranty_renewals_r2620 WHERE equipment_label = 'Mindray BeneHeart D6 Defibrillator' LIMIT 1;

INSERT INTO public.warranty_renewal_outcomes_r2620 (warranty_id, observed_at, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, now() - interval '15 days', 'lapsed', 0, owner_email, 'done', 'Customer chose OEM AMC'
FROM public.customer_warranty_renewals_r2620 WHERE equipment_label = 'Drager Fabius Plus Anaesthesia' LIMIT 1;

INSERT INTO public.warranty_renewal_outcomes_r2620 (warranty_id, observed_at, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, now() - interval '2 days', 'upgraded', 580000, owner_email, 'open', 'Customer upgraded to premium AMC tier'
FROM public.customer_warranty_renewals_r2620 WHERE equipment_label = 'Philips CT Scanner Brilliance 64' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_warranty_renewals_r2620()
RETURNS TABLE(id uuid, equipment_label text, warranty_end_date date, days_to_expiry int, renewal_value_rupees bigint, win_probability_pct int, owner_email text, status text, notes text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.equipment_label, r.warranty_end_date, r.days_to_expiry, r.renewal_value_rupees,
         r.win_probability_pct, r.owner_email, r.status, r.notes, r.created_at
  FROM public.customer_warranty_renewals_r2620 r
  ORDER BY r.warranty_end_date ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_warranty_renewals_r2620() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_warranty_renewals_r2620() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_outcomes_r2620()
RETURNS TABLE(id uuid, warranty_id uuid, equipment_label text, observed_at timestamptz, outcome_kind text, revenue_realized_rupees bigint, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.warranty_id, r.equipment_label, o.observed_at, o.outcome_kind,
         o.revenue_realized_rupees, o.owner_email, o.status, o.notes
  FROM public.warranty_renewal_outcomes_r2620 o
  JOIN public.customer_warranty_renewals_r2620 r ON r.id = o.warranty_id
  ORDER BY o.observed_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2620() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2620() TO authenticated;

CREATE OR REPLACE FUNCTION public.expiring_30d_focus_r2620()
RETURNS TABLE(equipment_label text, warranty_end_date date, days_to_expiry int, renewal_value_rupees bigint, win_probability_pct int, status text, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.equipment_label, r.warranty_end_date, r.days_to_expiry, r.renewal_value_rupees,
         r.win_probability_pct, r.status, r.owner_email
  FROM public.customer_warranty_renewals_r2620 r
  WHERE r.warranty_end_date BETWEEN current_date AND (current_date + 30)
    AND r.status IN ('monitoring','quoted')
  ORDER BY r.warranty_end_date ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.expiring_30d_focus_r2620() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expiring_30d_focus_r2620() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2620()
RETURNS TABLE(status text, opportunity_count bigint, total_value_rupees bigint, avg_win_probability_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.status, count(*)::bigint, coalesce(sum(r.renewal_value_rupees),0)::bigint,
         round(avg(r.win_probability_pct)::numeric, 1)
  FROM public.customer_warranty_renewals_r2620 r
  GROUP BY r.status
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2620() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2620() TO authenticated;

CREATE OR REPLACE FUNCTION public.win_probability_summary_r2620()
RETURNS TABLE(probability_band text, opportunity_count bigint, total_value_rupees bigint, weighted_value_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN r.win_probability_pct >= 75 THEN 'high (75-100)'
      WHEN r.win_probability_pct >= 50 THEN 'medium (50-74)'
      WHEN r.win_probability_pct >= 25 THEN 'low (25-49)'
      ELSE 'cold (0-24)'
    END AS probability_band,
    count(*)::bigint,
    coalesce(sum(r.renewal_value_rupees),0)::bigint,
    coalesce(sum((r.renewal_value_rupees * r.win_probability_pct) / 100),0)::bigint
  FROM public.customer_warranty_renewals_r2620 r
  WHERE r.status IN ('monitoring','quoted')
  GROUP BY 1
  ORDER BY 1;
END $$;
REVOKE EXECUTE ON FUNCTION public.win_probability_summary_r2620() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.win_probability_summary_r2620() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_renewal_trend_r2620()
RETURNS TABLE(month_label text, observed_outcomes bigint, renewed_count bigint, lapsed_count bigint, revenue_realized_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', o.observed_at), 'YYYY-MM') AS month_label,
         count(*)::bigint,
         count(*) FILTER (WHERE o.outcome_kind IN ('renewed','upgraded'))::bigint,
         count(*) FILTER (WHERE o.outcome_kind = 'lapsed')::bigint,
         coalesce(sum(o.revenue_realized_rupees),0)::bigint
  FROM public.warranty_renewal_outcomes_r2620 o
  GROUP BY 1
  ORDER BY 1 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_renewal_trend_r2620() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_renewal_trend_r2620() TO authenticated;

CREATE OR REPLACE FUNCTION public.revenue_summary_r2620()
RETURNS TABLE(metric_label text, metric_value_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'pipeline_value_open'::text,
         coalesce(sum(renewal_value_rupees),0)::bigint
  FROM public.customer_warranty_renewals_r2620
  WHERE status IN ('monitoring','quoted')
  UNION ALL
  SELECT 'weighted_pipeline_value'::text,
         coalesce(sum((renewal_value_rupees * win_probability_pct) / 100),0)::bigint
  FROM public.customer_warranty_renewals_r2620
  WHERE status IN ('monitoring','quoted')
  UNION ALL
  SELECT 'revenue_realized_total'::text,
         coalesce(sum(revenue_realized_rupees),0)::bigint
  FROM public.warranty_renewal_outcomes_r2620
  UNION ALL
  SELECT 'revenue_lost_lapsed'::text,
         coalesce(sum(renewal_value_rupees),0)::bigint
  FROM public.customer_warranty_renewals_r2620
  WHERE status = 'lost';
END $$;
REVOKE EXECUTE ON FUNCTION public.revenue_summary_r2620() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revenue_summary_r2620() TO authenticated;
