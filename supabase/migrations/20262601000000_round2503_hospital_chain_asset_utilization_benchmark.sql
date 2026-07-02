-- Round 2503: hospital-chain-asset-utilization-benchmark
-- chain × asset class × utilization × market benchmark × top quartile gap × growth opportunity

CREATE TABLE IF NOT EXISTS public.chain_asset_utilization_r2503 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  asset_class text NOT NULL CHECK (asset_class IN ('mri','ct','ultrasound','dialysis','ventilator','anesthesia','lab','dental')),
  our_utilization_pct numeric NOT NULL,
  market_benchmark_pct numeric NOT NULL,
  top_quartile_pct numeric NOT NULL,
  gap_to_top_pct numeric NOT NULL,
  growth_opportunity_rupees bigint NOT NULL,
  observed_period_start date NOT NULL,
  observed_period_end date NOT NULL,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.asset_utilization_growth_actions_r2503 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  utilization_id uuid NOT NULL REFERENCES public.chain_asset_utilization_r2503(id) ON DELETE CASCADE,
  action_kind text NOT NULL CHECK (action_kind IN ('marketing','extended_hours','cross_dept','training','equipment_swap')),
  action_at timestamptz NOT NULL DEFAULT now(),
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  expected_revenue_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_asset_utilization_r2503 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_utilization_growth_actions_r2503 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_asset_utilization_r2503;
CREATE POLICY founder_all ON public.chain_asset_utilization_r2503
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.asset_utilization_growth_actions_r2503;
CREATE POLICY founder_all ON public.asset_utilization_growth_actions_r2503
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed parent rows
INSERT INTO public.chain_asset_utilization_r2503
  (chain_name, asset_class, our_utilization_pct, market_benchmark_pct, top_quartile_pct, gap_to_top_pct, growth_opportunity_rupees, observed_period_start, observed_period_end, owner_email, notes)
VALUES
  ('Apollo Hyd','mri',58,68,82,24,4800000,'2026-05-01','2026-05-31','ops@equipseva.in','Night-shift idle 9pm-6am; outpatient bookings low'),
  ('Yashoda Group','ct',71,73,88,17,3200000,'2026-05-01','2026-05-31','ops@equipseva.in','Weekend CT volumes weak vs peers'),
  ('KIMS Network','dialysis',82,79,92,10,1800000,'2026-05-01','2026-05-31','renal@equipseva.in','3rd shift only 40% loaded'),
  ('Care Hospitals','ventilator',64,70,85,21,900000,'2026-05-01','2026-05-31','icu@equipseva.in','Step-down ICU using GA vents instead of dedicated'),
  ('Continental Health','dental',38,55,72,34,1400000,'2026-05-01','2026-05-31','dental@equipseva.in','New chair sitting idle 4 days/week');

-- Seed child rows
INSERT INTO public.asset_utilization_growth_actions_r2503
  (utilization_id, action_kind, owner_email, status, expected_revenue_rupees, notes)
SELECT id, 'marketing', 'mkt@equipseva.in', 'in_progress', 1200000, 'Outpatient MRI campaign'
FROM public.chain_asset_utilization_r2503 WHERE chain_name='Apollo Hyd' AND asset_class='mri';

INSERT INTO public.asset_utilization_growth_actions_r2503
  (utilization_id, action_kind, owner_email, status, expected_revenue_rupees, notes)
SELECT id, 'extended_hours', 'ops@equipseva.in', 'open', 800000, 'Open Saturday CT slots'
FROM public.chain_asset_utilization_r2503 WHERE chain_name='Yashoda Group' AND asset_class='ct';

INSERT INTO public.asset_utilization_growth_actions_r2503
  (utilization_id, action_kind, owner_email, status, expected_revenue_rupees, notes)
SELECT id, 'cross_dept', 'icu@equipseva.in', 'done', 400000, 'Route step-down patients to dedicated vents'
FROM public.chain_asset_utilization_r2503 WHERE chain_name='Care Hospitals' AND asset_class='ventilator';

INSERT INTO public.asset_utilization_growth_actions_r2503
  (utilization_id, action_kind, owner_email, status, expected_revenue_rupees, notes)
SELECT id, 'training', 'dental@equipseva.in', 'open', 600000, 'Cross-train hygienists on new chair'
FROM public.chain_asset_utilization_r2503 WHERE chain_name='Continental Health' AND asset_class='dental';

INSERT INTO public.asset_utilization_growth_actions_r2503
  (utilization_id, action_kind, owner_email, status, expected_revenue_rupees, notes)
SELECT id, 'equipment_swap', 'renal@equipseva.in', 'dropped', 200000, 'Swap dropped — chain prefers organic growth'
FROM public.chain_asset_utilization_r2503 WHERE chain_name='KIMS Network' AND asset_class='dialysis';

-- RPC 1: list utilization rows
CREATE OR REPLACE FUNCTION public.list_utilization_r2503()
RETURNS TABLE (
  id uuid,
  chain_name text,
  asset_class text,
  our_utilization_pct numeric,
  market_benchmark_pct numeric,
  top_quartile_pct numeric,
  gap_to_top_pct numeric,
  growth_opportunity_rupees bigint,
  observed_period_start date,
  observed_period_end date,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.chain_name, u.asset_class, u.our_utilization_pct, u.market_benchmark_pct,
         u.top_quartile_pct, u.gap_to_top_pct, u.growth_opportunity_rupees,
         u.observed_period_start, u.observed_period_end, u.owner_email, u.notes, u.created_at
  FROM public.chain_asset_utilization_r2503 u
  ORDER BY u.growth_opportunity_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_utilization_r2503() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_utilization_r2503() TO authenticated;

-- RPC 2: list growth actions
CREATE OR REPLACE FUNCTION public.list_growth_actions_r2503()
RETURNS TABLE (
  id uuid,
  utilization_id uuid,
  chain_name text,
  asset_class text,
  action_kind text,
  action_at timestamptz,
  owner_email text,
  status text,
  expected_revenue_rupees bigint,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.utilization_id, u.chain_name, u.asset_class, a.action_kind,
         a.action_at, a.owner_email, a.status, a.expected_revenue_rupees, a.notes
  FROM public.asset_utilization_growth_actions_r2503 a
  JOIN public.chain_asset_utilization_r2503 u ON u.id = a.utilization_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_growth_actions_r2503() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_growth_actions_r2503() TO authenticated;

-- RPC 3: top growth opportunities
CREATE OR REPLACE FUNCTION public.top_growth_opportunities_r2503()
RETURNS TABLE (
  chain_name text,
  asset_class text,
  gap_to_top_pct numeric,
  growth_opportunity_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.chain_name, u.asset_class, u.gap_to_top_pct, u.growth_opportunity_rupees
  FROM public.chain_asset_utilization_r2503 u
  ORDER BY u.growth_opportunity_rupees DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_growth_opportunities_r2503() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_growth_opportunities_r2503() TO authenticated;

-- RPC 4: summary by asset class
CREATE OR REPLACE FUNCTION public.asset_class_summary_r2503()
RETURNS TABLE (
  asset_class text,
  rows_count bigint,
  avg_our_pct numeric,
  avg_top_pct numeric,
  avg_gap_pct numeric,
  total_opportunity_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.asset_class,
         COUNT(*)::bigint,
         ROUND(AVG(u.our_utilization_pct)::numeric, 1),
         ROUND(AVG(u.top_quartile_pct)::numeric, 1),
         ROUND(AVG(u.gap_to_top_pct)::numeric, 1),
         COALESCE(SUM(u.growth_opportunity_rupees),0)::bigint
  FROM public.chain_asset_utilization_r2503 u
  GROUP BY u.asset_class
  ORDER BY COALESCE(SUM(u.growth_opportunity_rupees),0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.asset_class_summary_r2503() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.asset_class_summary_r2503() TO authenticated;

-- RPC 5: gap to top distribution
CREATE OR REPLACE FUNCTION public.gap_to_top_distribution_r2503()
RETURNS TABLE (
  bucket text,
  rows_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN u.gap_to_top_pct < 10 THEN '0-10%'
      WHEN u.gap_to_top_pct < 20 THEN '10-20%'
      WHEN u.gap_to_top_pct < 30 THEN '20-30%'
      ELSE '30%+'
    END AS bucket,
    COUNT(*)::bigint
  FROM public.chain_asset_utilization_r2503 u
  GROUP BY 1
  ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.gap_to_top_distribution_r2503() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gap_to_top_distribution_r2503() TO authenticated;

-- RPC 6: monthly growth action trend
CREATE OR REPLACE FUNCTION public.monthly_growth_action_trend_r2503()
RETURNS TABLE (
  month_label text,
  actions_count bigint,
  expected_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', a.action_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint,
         COALESCE(SUM(a.expected_revenue_rupees),0)::bigint
  FROM public.asset_utilization_growth_actions_r2503 a
  GROUP BY 1
  ORDER BY 1 DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_growth_action_trend_r2503() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_growth_action_trend_r2503() TO authenticated;

-- RPC 7: status funnel
CREATE OR REPLACE FUNCTION public.status_funnel_r2503()
RETURNS TABLE (
  status text,
  actions_count bigint,
  expected_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status,
         COUNT(*)::bigint,
         COALESCE(SUM(a.expected_revenue_rupees),0)::bigint
  FROM public.asset_utilization_growth_actions_r2503 a
  GROUP BY a.status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2503() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2503() TO authenticated;
