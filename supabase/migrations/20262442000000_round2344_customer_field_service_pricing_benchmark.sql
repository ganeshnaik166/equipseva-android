BEGIN;

CREATE TABLE IF NOT EXISTS public.field_service_pricing_benchmarks_r2344 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city text NOT NULL,
  equipment_class text NOT NULL,
  service_type text NOT NULL,
  our_price_rupees numeric(12,2) NOT NULL,
  competitor_avg_price_rupees numeric(12,2) NOT NULL,
  competitor_min_price_rupees numeric(12,2),
  competitor_max_price_rupees numeric(12,2),
  competitor_sample_size integer NOT NULL DEFAULT 0,
  market_position text NOT NULL DEFAULT 'unknown',
  source_notes text,
  benchmarked_at timestamptz NOT NULL DEFAULT now(),
  benchmarked_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fspb_r2344_city ON public.field_service_pricing_benchmarks_r2344(city);
CREATE INDEX IF NOT EXISTS idx_fspb_r2344_equipment ON public.field_service_pricing_benchmarks_r2344(equipment_class);
CREATE INDEX IF NOT EXISTS idx_fspb_r2344_benchmarked_at ON public.field_service_pricing_benchmarks_r2344(benchmarked_at DESC);

CREATE TABLE IF NOT EXISTS public.field_service_pricing_actions_r2344 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  benchmark_id uuid REFERENCES public.field_service_pricing_benchmarks_r2344(id) ON DELETE CASCADE,
  action_type text NOT NULL,
  recommended_new_price_rupees numeric(12,2),
  rationale text,
  status text NOT NULL DEFAULT 'pending',
  decided_at timestamptz,
  decided_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fspa_r2344_benchmark ON public.field_service_pricing_actions_r2344(benchmark_id);
CREATE INDEX IF NOT EXISTS idx_fspa_r2344_status ON public.field_service_pricing_actions_r2344(status);

ALTER TABLE public.field_service_pricing_benchmarks_r2344 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.field_service_pricing_actions_r2344 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.field_service_pricing_benchmarks_r2344;
CREATE POLICY founder_all ON public.field_service_pricing_benchmarks_r2344
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.field_service_pricing_actions_r2344;
CREATE POLICY founder_all ON public.field_service_pricing_actions_r2344
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.fspb_r2344_list_benchmarks()
RETURNS TABLE (
  id uuid,
  city text,
  equipment_class text,
  service_type text,
  our_price_rupees numeric,
  competitor_avg_price_rupees numeric,
  competitor_min_price_rupees numeric,
  competitor_max_price_rupees numeric,
  competitor_sample_size integer,
  market_position text,
  delta_pct numeric,
  benchmarked_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.city, b.equipment_class, b.service_type,
         b.our_price_rupees, b.competitor_avg_price_rupees,
         b.competitor_min_price_rupees, b.competitor_max_price_rupees,
         b.competitor_sample_size, b.market_position,
         CASE WHEN b.competitor_avg_price_rupees > 0
              THEN round(((b.our_price_rupees - b.competitor_avg_price_rupees) / b.competitor_avg_price_rupees) * 100, 2)
              ELSE 0 END AS delta_pct,
         b.benchmarked_at
  FROM public.field_service_pricing_benchmarks_r2344 b
  ORDER BY b.benchmarked_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.fspb_r2344_undercut_flags()
RETURNS TABLE (
  id uuid,
  city text,
  equipment_class text,
  service_type text,
  our_price_rupees numeric,
  competitor_avg_price_rupees numeric,
  delta_pct numeric,
  flag text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.city, b.equipment_class, b.service_type,
         b.our_price_rupees, b.competitor_avg_price_rupees,
         round(((b.our_price_rupees - b.competitor_avg_price_rupees) / NULLIF(b.competitor_avg_price_rupees,0)) * 100, 2) AS delta_pct,
         CASE
           WHEN b.our_price_rupees < b.competitor_avg_price_rupees * 0.9 THEN 'undercut'
           WHEN b.our_price_rupees > b.competitor_avg_price_rupees * 1.1 THEN 'overcharge'
           ELSE 'in_band'
         END AS flag
  FROM public.field_service_pricing_benchmarks_r2344 b
  WHERE b.competitor_avg_price_rupees > 0
  ORDER BY abs(b.our_price_rupees - b.competitor_avg_price_rupees) DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.fspb_r2344_by_city()
RETURNS TABLE (
  city text,
  benchmarks_count bigint,
  avg_delta_pct numeric,
  undercut_count bigint,
  overcharge_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.city,
         count(*) AS benchmarks_count,
         round(avg(((b.our_price_rupees - b.competitor_avg_price_rupees) / NULLIF(b.competitor_avg_price_rupees,0)) * 100), 2) AS avg_delta_pct,
         count(*) FILTER (WHERE b.our_price_rupees < b.competitor_avg_price_rupees * 0.9) AS undercut_count,
         count(*) FILTER (WHERE b.our_price_rupees > b.competitor_avg_price_rupees * 1.1) AS overcharge_count
  FROM public.field_service_pricing_benchmarks_r2344 b
  GROUP BY b.city
  ORDER BY benchmarks_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.fspb_r2344_by_equipment_class()
RETURNS TABLE (
  equipment_class text,
  benchmarks_count bigint,
  avg_our_price numeric,
  avg_competitor_price numeric,
  avg_delta_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.equipment_class,
         count(*) AS benchmarks_count,
         round(avg(b.our_price_rupees), 2) AS avg_our_price,
         round(avg(b.competitor_avg_price_rupees), 2) AS avg_competitor_price,
         round(avg(((b.our_price_rupees - b.competitor_avg_price_rupees) / NULLIF(b.competitor_avg_price_rupees,0)) * 100), 2) AS avg_delta_pct
  FROM public.field_service_pricing_benchmarks_r2344 b
  GROUP BY b.equipment_class
  ORDER BY benchmarks_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.fspb_r2344_pending_actions()
RETURNS TABLE (
  id uuid,
  benchmark_id uuid,
  city text,
  equipment_class text,
  action_type text,
  recommended_new_price_rupees numeric,
  rationale text,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.benchmark_id, b.city, b.equipment_class,
         a.action_type, a.recommended_new_price_rupees, a.rationale,
         a.status, a.created_at
  FROM public.field_service_pricing_actions_r2344 a
  LEFT JOIN public.field_service_pricing_benchmarks_r2344 b ON b.id = a.benchmark_id
  WHERE a.status = 'pending'
  ORDER BY a.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.fspb_r2344_summary()
RETURNS TABLE (
  total_benchmarks bigint,
  total_cities bigint,
  total_equipment_classes bigint,
  avg_delta_pct numeric,
  undercut_count bigint,
  overcharge_count bigint,
  in_band_count bigint,
  pending_actions bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.field_service_pricing_benchmarks_r2344),
    (SELECT count(DISTINCT city) FROM public.field_service_pricing_benchmarks_r2344),
    (SELECT count(DISTINCT equipment_class) FROM public.field_service_pricing_benchmarks_r2344),
    (SELECT round(avg(((our_price_rupees - competitor_avg_price_rupees) / NULLIF(competitor_avg_price_rupees,0)) * 100), 2)
       FROM public.field_service_pricing_benchmarks_r2344 WHERE competitor_avg_price_rupees > 0),
    (SELECT count(*) FROM public.field_service_pricing_benchmarks_r2344
       WHERE our_price_rupees < competitor_avg_price_rupees * 0.9),
    (SELECT count(*) FROM public.field_service_pricing_benchmarks_r2344
       WHERE our_price_rupees > competitor_avg_price_rupees * 1.1),
    (SELECT count(*) FROM public.field_service_pricing_benchmarks_r2344
       WHERE our_price_rupees BETWEEN competitor_avg_price_rupees * 0.9 AND competitor_avg_price_rupees * 1.1),
    (SELECT count(*) FROM public.field_service_pricing_actions_r2344 WHERE status = 'pending');
END;
$$;

CREATE OR REPLACE FUNCTION public.fspb_r2344_recent_actions()
RETURNS TABLE (
  id uuid,
  benchmark_id uuid,
  city text,
  equipment_class text,
  action_type text,
  status text,
  decided_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.benchmark_id, b.city, b.equipment_class,
         a.action_type, a.status, a.decided_at, a.created_at
  FROM public.field_service_pricing_actions_r2344 a
  LEFT JOIN public.field_service_pricing_benchmarks_r2344 b ON b.id = a.benchmark_id
  ORDER BY a.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.fspb_r2344_list_benchmarks() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fspb_r2344_undercut_flags() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fspb_r2344_by_city() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fspb_r2344_by_equipment_class() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fspb_r2344_pending_actions() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fspb_r2344_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fspb_r2344_recent_actions() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fspb_r2344_list_benchmarks() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fspb_r2344_undercut_flags() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fspb_r2344_by_city() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fspb_r2344_by_equipment_class() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fspb_r2344_pending_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fspb_r2344_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fspb_r2344_recent_actions() TO authenticated;

COMMIT;
