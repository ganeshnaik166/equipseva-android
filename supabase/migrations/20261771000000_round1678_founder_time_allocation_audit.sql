BEGIN;

-- Round r1678 — Founder Time Allocation Audit
-- Weekly time-allocation audit: hours per category (sales/eng/ops/admin/personal)

CREATE TABLE IF NOT EXISTS public.founder_time_allocations_r1678 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL UNIQUE,
  sales_hours numeric(6,2) NOT NULL DEFAULT 0,
  eng_hours numeric(6,2) NOT NULL DEFAULT 0,
  ops_hours numeric(6,2) NOT NULL DEFAULT 0,
  admin_hours numeric(6,2) NOT NULL DEFAULT 0,
  personal_hours numeric(6,2) NOT NULL DEFAULT 0,
  total_hours numeric(6,2) NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_time_targets_r1678 (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  category text PRIMARY KEY CHECK (category IN ('sales','eng','ops','admin','personal')),
  target_pct numeric(5,2) NOT NULL CHECK (target_pct >= 0 AND target_pct <= 100),
  set_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_time_allocations_r1678 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_time_targets_r1678 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_alloc_r1678 ON public.founder_time_allocations_r1678;
CREATE POLICY founder_only_alloc_r1678 ON public.founder_time_allocations_r1678
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_target_r1678 ON public.founder_time_targets_r1678;
CREATE POLICY founder_only_target_r1678 ON public.founder_time_targets_r1678
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_allocations
CREATE OR REPLACE FUNCTION public.r1678_list_allocations(p_limit int DEFAULT 26)
RETURNS TABLE (
  id uuid,
  week_start date,
  sales_hours numeric,
  eng_hours numeric,
  ops_hours numeric,
  admin_hours numeric,
  personal_hours numeric,
  total_hours numeric,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.week_start, a.sales_hours, a.eng_hours, a.ops_hours,
         a.admin_hours, a.personal_hours, a.total_hours, a.recorded_at
  FROM public.founder_time_allocations_r1678 a
  ORDER BY a.week_start DESC
  LIMIT p_limit;
END $$;

-- RPC 2: record_week
CREATE OR REPLACE FUNCTION public.r1678_record_week(
  p_week_start date,
  p_sales numeric,
  p_eng numeric,
  p_ops numeric,
  p_admin numeric,
  p_personal numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_total numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_total := COALESCE(p_sales,0) + COALESCE(p_eng,0) + COALESCE(p_ops,0)
           + COALESCE(p_admin,0) + COALESCE(p_personal,0);

  INSERT INTO public.founder_time_allocations_r1678
    (week_start, sales_hours, eng_hours, ops_hours, admin_hours, personal_hours, total_hours, recorded_at)
  VALUES
    (p_week_start, COALESCE(p_sales,0), COALESCE(p_eng,0), COALESCE(p_ops,0),
     COALESCE(p_admin,0), COALESCE(p_personal,0), v_total, now())
  ON CONFLICT (week_start) DO UPDATE
    SET sales_hours = EXCLUDED.sales_hours,
        eng_hours = EXCLUDED.eng_hours,
        ops_hours = EXCLUDED.ops_hours,
        admin_hours = EXCLUDED.admin_hours,
        personal_hours = EXCLUDED.personal_hours,
        total_hours = EXCLUDED.total_hours,
        recorded_at = now(),
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1678_record_week',
    jsonb_build_object('id', v_id, 'week_start', p_week_start, 'total', v_total));
  RETURN v_id;
END $$;

-- RPC 3: set_target
CREATE OR REPLACE FUNCTION public.r1678_set_target(
  p_category text,
  p_target_pct numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_category NOT IN ('sales','eng','ops','admin','personal') THEN
    RAISE EXCEPTION 'invalid category';
  END IF;

  INSERT INTO public.founder_time_targets_r1678 (category, target_pct, set_at)
  VALUES (p_category, p_target_pct, now())
  ON CONFLICT (category) DO UPDATE
    SET target_pct = EXCLUDED.target_pct,
        set_at = now(),
        updated_at = now();

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1678_set_target',
    jsonb_build_object('category', p_category, 'target_pct', p_target_pct));
END $$;

-- RPC 4: list_targets
CREATE OR REPLACE FUNCTION public.r1678_list_targets()
RETURNS TABLE (
  category text,
  target_pct numeric,
  set_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.category, t.target_pct, t.set_at
  FROM public.founder_time_targets_r1678 t
  ORDER BY t.category;
END $$;

-- RPC 5: current_vs_target
CREATE OR REPLACE FUNCTION public.r1678_current_vs_target()
RETURNS TABLE (
  category text,
  actual_pct numeric,
  target_pct numeric,
  delta_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total numeric;
  v_sales numeric;
  v_eng numeric;
  v_ops numeric;
  v_admin numeric;
  v_personal numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(SUM(a.sales_hours),0),
         COALESCE(SUM(a.eng_hours),0),
         COALESCE(SUM(a.ops_hours),0),
         COALESCE(SUM(a.admin_hours),0),
         COALESCE(SUM(a.personal_hours),0),
         COALESCE(SUM(a.total_hours),0)
    INTO v_sales, v_eng, v_ops, v_admin, v_personal, v_total
  FROM public.founder_time_allocations_r1678 a
  WHERE a.week_start >= (current_date - interval '28 days');

  IF v_total = 0 THEN v_total := 1; END IF;

  RETURN QUERY
  SELECT c.category,
         ROUND(c.actual / v_total * 100, 2) AS actual_pct,
         COALESCE(t.target_pct, 0) AS target_pct,
         ROUND(c.actual / v_total * 100 - COALESCE(t.target_pct, 0), 2) AS delta_pct
  FROM (VALUES
    ('sales', v_sales),
    ('eng', v_eng),
    ('ops', v_ops),
    ('admin', v_admin),
    ('personal', v_personal)
  ) AS c(category, actual)
  LEFT JOIN public.founder_time_targets_r1678 t ON t.category = c.category
  ORDER BY c.category;
END $$;

-- RPC 6: monthly_trend
CREATE OR REPLACE FUNCTION public.r1678_monthly_trend()
RETURNS TABLE (
  month_start date,
  sales_hours numeric,
  eng_hours numeric,
  ops_hours numeric,
  admin_hours numeric,
  personal_hours numeric,
  total_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', a.week_start)::date AS month_start,
         SUM(a.sales_hours)::numeric,
         SUM(a.eng_hours)::numeric,
         SUM(a.ops_hours)::numeric,
         SUM(a.admin_hours)::numeric,
         SUM(a.personal_hours)::numeric,
         SUM(a.total_hours)::numeric
  FROM public.founder_time_allocations_r1678 a
  WHERE a.week_start >= (current_date - interval '12 months')
  GROUP BY date_trunc('month', a.week_start)
  ORDER BY month_start DESC;
END $$;

-- RPC 7: category_summary
CREATE OR REPLACE FUNCTION public.r1678_category_summary()
RETURNS TABLE (
  category text,
  total_hours numeric,
  avg_weekly_hours numeric,
  weeks_recorded int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_weeks int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT (COUNT(*))::int INTO v_weeks
  FROM public.founder_time_allocations_r1678;

  IF v_weeks = 0 THEN v_weeks := 1; END IF;

  RETURN QUERY
  SELECT c.category,
         c.total_h::numeric,
         ROUND(c.total_h / v_weeks, 2) AS avg_weekly_hours,
         v_weeks AS weeks_recorded
  FROM (
    SELECT 'sales'::text AS category, COALESCE(SUM(sales_hours),0) AS total_h FROM public.founder_time_allocations_r1678
    UNION ALL
    SELECT 'eng', COALESCE(SUM(eng_hours),0) FROM public.founder_time_allocations_r1678
    UNION ALL
    SELECT 'ops', COALESCE(SUM(ops_hours),0) FROM public.founder_time_allocations_r1678
    UNION ALL
    SELECT 'admin', COALESCE(SUM(admin_hours),0) FROM public.founder_time_allocations_r1678
    UNION ALL
    SELECT 'personal', COALESCE(SUM(personal_hours),0) FROM public.founder_time_allocations_r1678
  ) c
  ORDER BY c.category;
END $$;

REVOKE EXECUTE ON FUNCTION public.r1678_list_allocations(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1678_record_week(date, numeric, numeric, numeric, numeric, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1678_set_target(text, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1678_list_targets() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1678_current_vs_target() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1678_monthly_trend() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1678_category_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1678_list_allocations(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1678_record_week(date, numeric, numeric, numeric, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1678_set_target(text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1678_list_targets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1678_current_vs_target() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1678_monthly_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1678_category_summary() TO authenticated;

COMMIT;