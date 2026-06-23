BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_engineer_repair_mix_r2358 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  job_date date NOT NULL,
  coverage_type text NOT NULL CHECK (coverage_type IN ('warranty','amc','paid','goodwill','out_of_warranty')),
  equipment_category text,
  job_hours numeric(6,2) NOT NULL DEFAULT 0 CHECK (job_hours >= 0),
  revenue_rupees integer NOT NULL DEFAULT 0 CHECK (revenue_rupees >= 0),
  parts_cost_rupees integer NOT NULL DEFAULT 0 CHECK (parts_cost_rupees >= 0),
  payout_rupees integer NOT NULL DEFAULT 0 CHECK (payout_rupees >= 0),
  hospital_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_repair_mix_r2358_engineer_date ON public.founder_engineer_repair_mix_r2358(engineer_id, job_date DESC);
CREATE INDEX IF NOT EXISTS idx_repair_mix_r2358_coverage ON public.founder_engineer_repair_mix_r2358(coverage_type);
CREATE INDEX IF NOT EXISTS idx_repair_mix_r2358_date ON public.founder_engineer_repair_mix_r2358(job_date DESC);

ALTER TABLE public.founder_engineer_repair_mix_r2358 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_engineer_repair_mix_r2358;
CREATE POLICY founder_all ON public.founder_engineer_repair_mix_r2358
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_engineer_repair_targets_r2358 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_month date NOT NULL,
  warranty_target_pct numeric(5,2) NOT NULL DEFAULT 40.00 CHECK (warranty_target_pct BETWEEN 0 AND 100),
  amc_target_pct numeric(5,2) NOT NULL DEFAULT 35.00 CHECK (amc_target_pct BETWEEN 0 AND 100),
  paid_target_pct numeric(5,2) NOT NULL DEFAULT 25.00 CHECK (paid_target_pct BETWEEN 0 AND 100),
  monthly_revenue_target_rupees integer NOT NULL DEFAULT 0 CHECK (monthly_revenue_target_rupees >= 0),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_id, target_month)
);

CREATE INDEX IF NOT EXISTS idx_repair_targets_r2358_engineer_month ON public.founder_engineer_repair_targets_r2358(engineer_id, target_month DESC);

ALTER TABLE public.founder_engineer_repair_targets_r2358 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_engineer_repair_targets_r2358;
CREATE POLICY founder_all ON public.founder_engineer_repair_targets_r2358
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: overall mix snapshot (last 30 days)
CREATE OR REPLACE FUNCTION public.founder_repair_mix_snapshot_r2358()
RETURNS TABLE (
  window_days integer,
  total_jobs bigint,
  warranty_jobs bigint,
  amc_jobs bigint,
  paid_jobs bigint,
  total_revenue_rupees bigint,
  total_payout_rupees bigint,
  total_parts_cost_rupees bigint,
  net_margin_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    30,
    COUNT(*)::bigint,
    SUM(CASE WHEN coverage_type = 'warranty' THEN 1 ELSE 0 END)::bigint,
    SUM(CASE WHEN coverage_type = 'amc' THEN 1 ELSE 0 END)::bigint,
    SUM(CASE WHEN coverage_type = 'paid' THEN 1 ELSE 0 END)::bigint,
    COALESCE(SUM(revenue_rupees),0)::bigint,
    COALESCE(SUM(payout_rupees),0)::bigint,
    COALESCE(SUM(parts_cost_rupees),0)::bigint,
    (COALESCE(SUM(revenue_rupees),0) - COALESCE(SUM(payout_rupees),0) - COALESCE(SUM(parts_cost_rupees),0))::bigint
  FROM public.founder_engineer_repair_mix_r2358
  WHERE job_date >= CURRENT_DATE - INTERVAL '30 days';
END;
$$;

REVOKE ALL ON FUNCTION public.founder_repair_mix_snapshot_r2358() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_repair_mix_snapshot_r2358() TO authenticated;

-- RPC 2: coverage distribution (30 days)
CREATE OR REPLACE FUNCTION public.founder_repair_coverage_distribution_r2358()
RETURNS TABLE (
  coverage_type text,
  jobs bigint,
  pct_of_jobs numeric,
  total_revenue_rupees bigint,
  pct_of_revenue numeric,
  avg_job_hours numeric,
  avg_revenue_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_jobs bigint;
  v_total_rev bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*)::bigint, COALESCE(SUM(revenue_rupees),0)::bigint
  INTO v_total_jobs, v_total_rev
  FROM public.founder_engineer_repair_mix_r2358
  WHERE job_date >= CURRENT_DATE - INTERVAL '30 days';

  RETURN QUERY
  SELECT
    m.coverage_type,
    COUNT(*)::bigint,
    CASE WHEN v_total_jobs = 0 THEN 0::numeric
         ELSE ROUND(100.0 * COUNT(*) / v_total_jobs, 1) END,
    COALESCE(SUM(m.revenue_rupees),0)::bigint,
    CASE WHEN v_total_rev = 0 THEN 0::numeric
         ELSE ROUND(100.0 * SUM(m.revenue_rupees) / v_total_rev, 1) END,
    ROUND(AVG(m.job_hours)::numeric, 2),
    ROUND(AVG(m.revenue_rupees)::numeric, 0)
  FROM public.founder_engineer_repair_mix_r2358 m
  WHERE m.job_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY m.coverage_type
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_repair_coverage_distribution_r2358() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_repair_coverage_distribution_r2358() TO authenticated;

-- RPC 3: engineer revenue split
CREATE OR REPLACE FUNCTION public.founder_engineer_revenue_split_r2358()
RETURNS TABLE (
  engineer_id uuid,
  engineer_email text,
  total_jobs bigint,
  warranty_jobs bigint,
  amc_jobs bigint,
  paid_jobs bigint,
  warranty_revenue_rupees bigint,
  amc_revenue_rupees bigint,
  paid_revenue_rupees bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.engineer_id,
    p.email,
    COUNT(*)::bigint,
    SUM(CASE WHEN m.coverage_type = 'warranty' THEN 1 ELSE 0 END)::bigint,
    SUM(CASE WHEN m.coverage_type = 'amc' THEN 1 ELSE 0 END)::bigint,
    SUM(CASE WHEN m.coverage_type = 'paid' THEN 1 ELSE 0 END)::bigint,
    COALESCE(SUM(CASE WHEN m.coverage_type = 'warranty' THEN m.revenue_rupees ELSE 0 END),0)::bigint,
    COALESCE(SUM(CASE WHEN m.coverage_type = 'amc' THEN m.revenue_rupees ELSE 0 END),0)::bigint,
    COALESCE(SUM(CASE WHEN m.coverage_type = 'paid' THEN m.revenue_rupees ELSE 0 END),0)::bigint,
    COALESCE(SUM(m.revenue_rupees),0)::bigint
  FROM public.founder_engineer_repair_mix_r2358 m
  LEFT JOIN public.profiles p ON p.id = m.engineer_id
  WHERE m.job_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY m.engineer_id, p.email
  ORDER BY SUM(m.revenue_rupees) DESC NULLS LAST
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_revenue_split_r2358() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_revenue_split_r2358() TO authenticated;

-- RPC 4: weekly trend (last 8 weeks)
CREATE OR REPLACE FUNCTION public.founder_repair_weekly_trend_r2358()
RETURNS TABLE (
  week_start date,
  warranty_jobs bigint,
  amc_jobs bigint,
  paid_jobs bigint,
  total_jobs bigint,
  warranty_revenue_rupees bigint,
  amc_revenue_rupees bigint,
  paid_revenue_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', m.job_date)::date,
    SUM(CASE WHEN m.coverage_type = 'warranty' THEN 1 ELSE 0 END)::bigint,
    SUM(CASE WHEN m.coverage_type = 'amc' THEN 1 ELSE 0 END)::bigint,
    SUM(CASE WHEN m.coverage_type = 'paid' THEN 1 ELSE 0 END)::bigint,
    COUNT(*)::bigint,
    COALESCE(SUM(CASE WHEN m.coverage_type = 'warranty' THEN m.revenue_rupees ELSE 0 END),0)::bigint,
    COALESCE(SUM(CASE WHEN m.coverage_type = 'amc' THEN m.revenue_rupees ELSE 0 END),0)::bigint,
    COALESCE(SUM(CASE WHEN m.coverage_type = 'paid' THEN m.revenue_rupees ELSE 0 END),0)::bigint
  FROM public.founder_engineer_repair_mix_r2358 m
  WHERE m.job_date >= CURRENT_DATE - INTERVAL '56 days'
  GROUP BY date_trunc('week', m.job_date)
  ORDER BY date_trunc('week', m.job_date) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_repair_weekly_trend_r2358() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_repair_weekly_trend_r2358() TO authenticated;

-- RPC 5: equipment category mix (30 days)
CREATE OR REPLACE FUNCTION public.founder_repair_category_mix_r2358()
RETURNS TABLE (
  equipment_category text,
  total_jobs bigint,
  warranty_pct numeric,
  amc_pct numeric,
  paid_pct numeric,
  avg_revenue_rupees numeric,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(m.equipment_category, 'unknown'),
    COUNT(*)::bigint,
    ROUND(100.0 * SUM(CASE WHEN m.coverage_type = 'warranty' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 1),
    ROUND(100.0 * SUM(CASE WHEN m.coverage_type = 'amc' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 1),
    ROUND(100.0 * SUM(CASE WHEN m.coverage_type = 'paid' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 1),
    ROUND(AVG(m.revenue_rupees)::numeric, 0),
    COALESCE(SUM(m.revenue_rupees),0)::bigint
  FROM public.founder_engineer_repair_mix_r2358 m
  WHERE m.job_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY COALESCE(m.equipment_category, 'unknown')
  ORDER BY COUNT(*) DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_repair_category_mix_r2358() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_repair_category_mix_r2358() TO authenticated;

-- RPC 6: target vs actual (current month)
CREATE OR REPLACE FUNCTION public.founder_repair_target_vs_actual_r2358()
RETURNS TABLE (
  engineer_id uuid,
  engineer_email text,
  target_month date,
  warranty_target_pct numeric,
  amc_target_pct numeric,
  paid_target_pct numeric,
  actual_warranty_pct numeric,
  actual_amc_pct numeric,
  actual_paid_pct numeric,
  revenue_target_rupees integer,
  actual_revenue_rupees bigint,
  revenue_attainment_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH month_start AS (
    SELECT date_trunc('month', CURRENT_DATE)::date AS d
  ),
  actuals AS (
    SELECT
      m.engineer_id,
      COUNT(*)::bigint AS total_jobs,
      SUM(CASE WHEN m.coverage_type = 'warranty' THEN 1 ELSE 0 END)::bigint AS w_jobs,
      SUM(CASE WHEN m.coverage_type = 'amc' THEN 1 ELSE 0 END)::bigint AS a_jobs,
      SUM(CASE WHEN m.coverage_type = 'paid' THEN 1 ELSE 0 END)::bigint AS p_jobs,
      COALESCE(SUM(m.revenue_rupees),0)::bigint AS revenue
    FROM public.founder_engineer_repair_mix_r2358 m, month_start
    WHERE m.job_date >= month_start.d
    GROUP BY m.engineer_id
  )
  SELECT
    t.engineer_id,
    p.email,
    t.target_month,
    t.warranty_target_pct,
    t.amc_target_pct,
    t.paid_target_pct,
    CASE WHEN a.total_jobs IS NULL OR a.total_jobs = 0 THEN 0::numeric
         ELSE ROUND(100.0 * a.w_jobs / a.total_jobs, 1) END,
    CASE WHEN a.total_jobs IS NULL OR a.total_jobs = 0 THEN 0::numeric
         ELSE ROUND(100.0 * a.a_jobs / a.total_jobs, 1) END,
    CASE WHEN a.total_jobs IS NULL OR a.total_jobs = 0 THEN 0::numeric
         ELSE ROUND(100.0 * a.p_jobs / a.total_jobs, 1) END,
    t.monthly_revenue_target_rupees,
    COALESCE(a.revenue, 0),
    CASE WHEN t.monthly_revenue_target_rupees = 0 THEN 0::numeric
         ELSE ROUND(100.0 * COALESCE(a.revenue,0) / t.monthly_revenue_target_rupees, 1) END
  FROM public.founder_engineer_repair_targets_r2358 t
  LEFT JOIN public.profiles p ON p.id = t.engineer_id
  LEFT JOIN actuals a ON a.engineer_id = t.engineer_id
  WHERE t.target_month = (SELECT d FROM month_start)
  ORDER BY t.engineer_id
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_repair_target_vs_actual_r2358() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_repair_target_vs_actual_r2358() TO authenticated;

-- RPC 7: recent job log
CREATE OR REPLACE FUNCTION public.founder_repair_recent_jobs_r2358()
RETURNS TABLE (
  id uuid,
  job_date date,
  engineer_email text,
  coverage_type text,
  equipment_category text,
  job_hours numeric,
  revenue_rupees integer,
  parts_cost_rupees integer,
  payout_rupees integer,
  hospital_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.id,
    m.job_date,
    pe.email,
    m.coverage_type,
    m.equipment_category,
    m.job_hours,
    m.revenue_rupees,
    m.parts_cost_rupees,
    m.payout_rupees,
    ph.email,
    m.notes,
    m.created_at
  FROM public.founder_engineer_repair_mix_r2358 m
  LEFT JOIN public.profiles pe ON pe.id = m.engineer_id
  LEFT JOIN public.profiles ph ON ph.id = m.hospital_id
  WHERE m.job_date >= CURRENT_DATE - INTERVAL '14 days'
  ORDER BY m.job_date DESC, m.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_repair_recent_jobs_r2358() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_repair_recent_jobs_r2358() TO authenticated;

COMMIT;
