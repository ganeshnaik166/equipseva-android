-- Round 2624: Customer Equipment Installed-Base Cross-Sell
-- Tracks cross-sell opportunities into hospitals' installed equipment base
-- and the realized outcomes of those plays.

BEGIN;

-- =====================================================================
-- TABLE 1: pipeline
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.customer_cross_sell_pipeline_r2624 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  installed_equipment_label text NOT NULL,
  cross_sell_kind text NOT NULL CHECK (cross_sell_kind IN ('amc','training','consumables','equipment_add','data_subscription')),
  pipeline_value_rupees bigint NOT NULL DEFAULT 0,
  win_probability_pct int NOT NULL DEFAULT 0 CHECK (win_probability_pct BETWEEN 0 AND 100),
  owner_email text,
  status text NOT NULL DEFAULT 'prospecting' CHECK (status IN ('prospecting','quoted','won','lost','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_cross_sell_pipeline_r2624 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_cross_sell_pipeline_r2624;
CREATE POLICY founder_all ON public.customer_cross_sell_pipeline_r2624
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE 2: outcomes
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.cross_sell_outcomes_r2624 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.customer_cross_sell_pipeline_r2624(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('closed_won','closed_lost','postponed')),
  revenue_realized_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cross_sell_outcomes_r2624 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.cross_sell_outcomes_r2624;
CREATE POLICY founder_all ON public.cross_sell_outcomes_r2624
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- SEED DATA
-- =====================================================================
INSERT INTO public.customer_cross_sell_pipeline_r2624
  (installed_equipment_label, cross_sell_kind, pipeline_value_rupees, win_probability_pct, owner_email, status, notes)
VALUES
  ('Ultrasound Mindray DC-70 (Apollo Jubilee)', 'amc', 180000, 75, 'sales1@equipseva.in', 'quoted', 'AMC quote shared; awaiting PO'),
  ('Dental Chair Sirona (Smile Studio)', 'consumables', 45000, 60, 'sales2@equipseva.in', 'prospecting', 'Monthly consumables bundle proposal'),
  ('CT Scanner GE Brivo (KIMS Secunderabad)', 'training', 90000, 50, 'sales1@equipseva.in', 'prospecting', 'Operator training package for 4 techs'),
  ('Patient Monitor Philips IntelliVue (Yashoda)', 'equipment_add', 320000, 40, 'sales3@equipseva.in', 'quoted', 'Add-on monitor x2 for new ICU bay'),
  ('Lab Analyzer Roche Cobas (SRL Diagnostics)', 'data_subscription', 60000, 80, 'sales2@equipseva.in', 'won', 'Annual analytics subscription closed');

INSERT INTO public.cross_sell_outcomes_r2624
  (pipeline_id, observed_at, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, (now() - interval '12 days')::timestamptz, 'closed_won', 60000, owner_email, 'done', 'Subscription invoiced and paid'
FROM public.customer_cross_sell_pipeline_r2624 WHERE installed_equipment_label LIKE 'Lab Analyzer%' LIMIT 1;

INSERT INTO public.cross_sell_outcomes_r2624
  (pipeline_id, observed_at, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, (now() - interval '5 days')::timestamptz, 'postponed', 0, owner_email, 'open', 'Hospital deferred to next quarter budget'
FROM public.customer_cross_sell_pipeline_r2624 WHERE installed_equipment_label LIKE 'Patient Monitor%' LIMIT 1;

INSERT INTO public.cross_sell_outcomes_r2624
  (pipeline_id, observed_at, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, (now() - interval '2 days')::timestamptz, 'closed_lost', 0, owner_email, 'done', 'Competitor offered free training bundle'
FROM public.customer_cross_sell_pipeline_r2624 WHERE installed_equipment_label LIKE 'Dental Chair%' LIMIT 1;

-- =====================================================================
-- RPC 1: list_pipeline_r2624
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_pipeline_r2624()
RETURNS TABLE (
  id uuid,
  installed_equipment_label text,
  cross_sell_kind text,
  pipeline_value_rupees bigint,
  win_probability_pct int,
  weighted_value_rupees bigint,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.installed_equipment_label,
    p.cross_sell_kind,
    p.pipeline_value_rupees,
    p.win_probability_pct,
    (p.pipeline_value_rupees * p.win_probability_pct / 100)::bigint AS weighted_value_rupees,
    p.owner_email,
    p.status,
    p.notes,
    p.created_at
  FROM public.customer_cross_sell_pipeline_r2624 p
  ORDER BY p.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pipeline_r2624() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pipeline_r2624() TO authenticated;

-- =====================================================================
-- RPC 2: list_outcomes_r2624
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_outcomes_r2624()
RETURNS TABLE (
  id uuid,
  pipeline_id uuid,
  installed_equipment_label text,
  observed_at timestamptz,
  outcome_kind text,
  revenue_realized_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.pipeline_id,
    p.installed_equipment_label,
    o.observed_at,
    o.outcome_kind,
    o.revenue_realized_rupees,
    o.owner_email,
    o.status,
    o.notes
  FROM public.cross_sell_outcomes_r2624 o
  JOIN public.customer_cross_sell_pipeline_r2624 p ON p.id = o.pipeline_id
  ORDER BY o.observed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2624() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2624() TO authenticated;

-- =====================================================================
-- RPC 3: top_pipeline_focus_r2624
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_pipeline_focus_r2624()
RETURNS TABLE (
  installed_equipment_label text,
  cross_sell_kind text,
  pipeline_value_rupees bigint,
  win_probability_pct int,
  weighted_value_rupees bigint,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.installed_equipment_label,
    p.cross_sell_kind,
    p.pipeline_value_rupees,
    p.win_probability_pct,
    (p.pipeline_value_rupees * p.win_probability_pct / 100)::bigint AS weighted_value_rupees,
    p.owner_email,
    p.status
  FROM public.customer_cross_sell_pipeline_r2624 p
  WHERE p.status IN ('prospecting','quoted')
  ORDER BY (p.pipeline_value_rupees * p.win_probability_pct) DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_pipeline_focus_r2624() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_pipeline_focus_r2624() TO authenticated;

-- =====================================================================
-- RPC 4: cross_sell_kind_distribution_r2624
-- =====================================================================
CREATE OR REPLACE FUNCTION public.cross_sell_kind_distribution_r2624()
RETURNS TABLE (
  cross_sell_kind text,
  opportunity_count bigint,
  total_value_rupees bigint,
  weighted_value_rupees bigint,
  avg_win_probability_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.cross_sell_kind,
    COUNT(*)::bigint AS opportunity_count,
    COALESCE(SUM(p.pipeline_value_rupees), 0)::bigint AS total_value_rupees,
    COALESCE(SUM(p.pipeline_value_rupees * p.win_probability_pct / 100), 0)::bigint AS weighted_value_rupees,
    ROUND(AVG(p.win_probability_pct)::numeric, 1) AS avg_win_probability_pct
  FROM public.customer_cross_sell_pipeline_r2624 p
  GROUP BY p.cross_sell_kind
  ORDER BY total_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.cross_sell_kind_distribution_r2624() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cross_sell_kind_distribution_r2624() TO authenticated;

-- =====================================================================
-- RPC 5: status_funnel_r2624
-- =====================================================================
CREATE OR REPLACE FUNCTION public.status_funnel_r2624()
RETURNS TABLE (
  status text,
  opportunity_count bigint,
  total_value_rupees bigint,
  avg_win_probability_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.status,
    COUNT(*)::bigint AS opportunity_count,
    COALESCE(SUM(p.pipeline_value_rupees), 0)::bigint AS total_value_rupees,
    ROUND(AVG(p.win_probability_pct)::numeric, 1) AS avg_win_probability_pct
  FROM public.customer_cross_sell_pipeline_r2624 p
  GROUP BY p.status
  ORDER BY total_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2624() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2624() TO authenticated;

-- =====================================================================
-- RPC 6: monthly_pipeline_trend_r2624
-- =====================================================================
CREATE OR REPLACE FUNCTION public.monthly_pipeline_trend_r2624()
RETURNS TABLE (
  month_label text,
  pipeline_added bigint,
  pipeline_value_added_rupees bigint,
  outcomes_observed bigint,
  revenue_realized_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT to_char(date_trunc('month', p.created_at), 'YYYY-MM') AS month_label,
           date_trunc('month', p.created_at) AS month_start
    FROM public.customer_cross_sell_pipeline_r2624 p
    UNION
    SELECT to_char(date_trunc('month', o.observed_at), 'YYYY-MM'),
           date_trunc('month', o.observed_at)
    FROM public.cross_sell_outcomes_r2624 o
  ),
  pipe_agg AS (
    SELECT to_char(date_trunc('month', created_at), 'YYYY-MM') AS month_label,
           COUNT(*)::bigint AS cnt,
           COALESCE(SUM(pipeline_value_rupees), 0)::bigint AS val
    FROM public.customer_cross_sell_pipeline_r2624
    GROUP BY 1
  ),
  out_agg AS (
    SELECT to_char(date_trunc('month', observed_at), 'YYYY-MM') AS month_label,
           COUNT(*)::bigint AS cnt,
           COALESCE(SUM(revenue_realized_rupees), 0)::bigint AS rev
    FROM public.cross_sell_outcomes_r2624
    GROUP BY 1
  )
  SELECT
    m.month_label,
    COALESCE(pa.cnt, 0)::bigint AS pipeline_added,
    COALESCE(pa.val, 0)::bigint AS pipeline_value_added_rupees,
    COALESCE(oa.cnt, 0)::bigint AS outcomes_observed,
    COALESCE(oa.rev, 0)::bigint AS revenue_realized_rupees
  FROM (SELECT DISTINCT month_label, month_start FROM months) m
  LEFT JOIN pipe_agg pa ON pa.month_label = m.month_label
  LEFT JOIN out_agg oa ON oa.month_label = m.month_label
  ORDER BY m.month_start;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pipeline_trend_r2624() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pipeline_trend_r2624() TO authenticated;

-- =====================================================================
-- RPC 7: total_realized_summary_r2624
-- =====================================================================
CREATE OR REPLACE FUNCTION public.total_realized_summary_r2624()
RETURNS TABLE (
  metric_label text,
  metric_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'Total pipeline value'::text,
         COALESCE(SUM(pipeline_value_rupees), 0)::bigint
  FROM public.customer_cross_sell_pipeline_r2624
  UNION ALL
  SELECT 'Weighted pipeline value'::text,
         COALESCE(SUM(pipeline_value_rupees * win_probability_pct / 100), 0)::bigint
  FROM public.customer_cross_sell_pipeline_r2624
  UNION ALL
  SELECT 'Open pipeline value'::text,
         COALESCE(SUM(pipeline_value_rupees), 0)::bigint
  FROM public.customer_cross_sell_pipeline_r2624
  WHERE status IN ('prospecting','quoted')
  UNION ALL
  SELECT 'Closed-won pipeline value'::text,
         COALESCE(SUM(pipeline_value_rupees), 0)::bigint
  FROM public.customer_cross_sell_pipeline_r2624
  WHERE status = 'won'
  UNION ALL
  SELECT 'Revenue realized (all outcomes)'::text,
         COALESCE(SUM(revenue_realized_rupees), 0)::bigint
  FROM public.cross_sell_outcomes_r2624;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.total_realized_summary_r2624() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_realized_summary_r2624() TO authenticated;

COMMIT;
