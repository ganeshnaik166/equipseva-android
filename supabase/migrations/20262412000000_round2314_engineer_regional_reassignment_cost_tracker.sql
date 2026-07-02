BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_reassignments_r2314 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_name text NOT NULL,
  from_region text NOT NULL,
  to_region text NOT NULL,
  move_reason text NOT NULL CHECK (move_reason IN ('demand_surge','attrition_backfill','skill_match','career_growth','underutilized','strategic_expansion','retention_save','other')),
  initiated_on date NOT NULL,
  effective_on date NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_transit','active','reverted','cancelled')),
  expected_duration_months int NOT NULL DEFAULT 12 CHECK (expected_duration_months > 0),
  initiator_notes text DEFAULT '',
  decision_owner text DEFAULT '',
  approval_state text NOT NULL DEFAULT 'approved' CHECK (approval_state IN ('proposed','approved','rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.reassignment_costs_r2314 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reassignment_id uuid NOT NULL REFERENCES public.engineer_reassignments_r2314(id) ON DELETE CASCADE,
  cost_category text NOT NULL CHECK (cost_category IN ('travel','relocation','housing_allowance','gap_days_lost','training_ramp','equipment_kit','signing_retention_bonus','admin_overhead','other')),
  cost_rupees int NOT NULL CHECK (cost_rupees >= 0),
  incurred_on date NOT NULL,
  gap_days int NOT NULL DEFAULT 0 CHECK (gap_days >= 0),
  expected_monthly_value_rupees int NOT NULL DEFAULT 0 CHECK (expected_monthly_value_rupees >= 0),
  actual_monthly_value_rupees int NOT NULL DEFAULT 0 CHECK (actual_monthly_value_rupees >= 0),
  realized_review_state text NOT NULL DEFAULT 'pending' CHECK (realized_review_state IN ('pending','positive_roi','break_even','negative_roi','too_early')),
  reviewer_notes text DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_r2314_reassign_engineer ON public.engineer_reassignments_r2314(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_r2314_reassign_status ON public.engineer_reassignments_r2314(status);
CREATE INDEX IF NOT EXISTS idx_r2314_reassign_effective ON public.engineer_reassignments_r2314(effective_on DESC);
CREATE INDEX IF NOT EXISTS idx_r2314_cost_reassign ON public.reassignment_costs_r2314(reassignment_id);
CREATE INDEX IF NOT EXISTS idx_r2314_cost_category ON public.reassignment_costs_r2314(cost_category);
CREATE INDEX IF NOT EXISTS idx_r2314_cost_review ON public.reassignment_costs_r2314(realized_review_state);

ALTER TABLE public.engineer_reassignments_r2314 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reassignment_costs_r2314 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2314_reassign ON public.engineer_reassignments_r2314;
CREATE POLICY founder_all_r2314_reassign ON public.engineer_reassignments_r2314 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2314_cost ON public.reassignment_costs_r2314;
CREATE POLICY founder_all_r2314_cost ON public.reassignment_costs_r2314 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1. list reassignments
DROP FUNCTION IF EXISTS public.list_reassignments_r2314();
CREATE FUNCTION public.list_reassignments_r2314()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  from_region text,
  to_region text,
  move_reason text,
  status text,
  approval_state text,
  initiated_on date,
  effective_on date,
  expected_duration_months int,
  decision_owner text,
  cost_entries int,
  total_cost_rupees bigint,
  total_gap_days int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, r.engineer_name, r.from_region, r.to_region, r.move_reason,
         r.status, r.approval_state, r.initiated_on, r.effective_on, r.expected_duration_months,
         r.decision_owner,
         COALESCE(c.cnt, 0)::int AS cost_entries,
         COALESCE(c.total_cost, 0)::bigint AS total_cost_rupees,
         COALESCE(c.total_gap, 0)::int AS total_gap_days
  FROM public.engineer_reassignments_r2314 r
  LEFT JOIN (
    SELECT reassignment_id,
           COUNT(*) AS cnt,
           SUM(cost_rupees) AS total_cost,
           SUM(gap_days) AS total_gap
    FROM public.reassignment_costs_r2314
    GROUP BY reassignment_id
  ) c ON c.reassignment_id = r.id
  ORDER BY r.effective_on DESC, r.created_at DESC;
END $$;

-- 2. list cost entries
DROP FUNCTION IF EXISTS public.list_reassignment_costs_r2314();
CREATE FUNCTION public.list_reassignment_costs_r2314()
RETURNS TABLE (
  id uuid,
  reassignment_id uuid,
  engineer_name text,
  from_region text,
  to_region text,
  cost_category text,
  cost_rupees int,
  incurred_on date,
  gap_days int,
  expected_monthly_value_rupees int,
  actual_monthly_value_rupees int,
  realized_review_state text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.reassignment_id, r.engineer_name, r.from_region, r.to_region,
         c.cost_category, c.cost_rupees, c.incurred_on, c.gap_days,
         c.expected_monthly_value_rupees, c.actual_monthly_value_rupees, c.realized_review_state
  FROM public.reassignment_costs_r2314 c
  JOIN public.engineer_reassignments_r2314 r ON r.id = c.reassignment_id
  ORDER BY c.incurred_on DESC, c.created_at DESC;
END $$;

-- 3. negative ROI watchlist
DROP FUNCTION IF EXISTS public.negative_roi_moves_r2314();
CREATE FUNCTION public.negative_roi_moves_r2314()
RETURNS TABLE (
  reassignment_id uuid,
  engineer_name text,
  from_region text,
  to_region text,
  status text,
  total_cost_rupees bigint,
  expected_monthly_value_rupees bigint,
  actual_monthly_value_rupees bigint,
  value_shortfall_rupees bigint,
  effective_on date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id AS reassignment_id, r.engineer_name, r.from_region, r.to_region, r.status,
         COALESCE(SUM(c.cost_rupees), 0)::bigint AS total_cost_rupees,
         COALESCE(SUM(c.expected_monthly_value_rupees), 0)::bigint AS expected_monthly_value_rupees,
         COALESCE(SUM(c.actual_monthly_value_rupees), 0)::bigint AS actual_monthly_value_rupees,
         (COALESCE(SUM(c.expected_monthly_value_rupees), 0) - COALESCE(SUM(c.actual_monthly_value_rupees), 0))::bigint AS value_shortfall_rupees,
         r.effective_on
  FROM public.engineer_reassignments_r2314 r
  JOIN public.reassignment_costs_r2314 c ON c.reassignment_id = r.id
  WHERE c.realized_review_state IN ('negative_roi','break_even')
     OR (c.actual_monthly_value_rupees < c.expected_monthly_value_rupees
         AND r.effective_on <= CURRENT_DATE - INTERVAL '60 days')
  GROUP BY r.id, r.engineer_name, r.from_region, r.to_region, r.status, r.effective_on
  ORDER BY value_shortfall_rupees DESC NULLS LAST;
END $$;

-- 4. per-engineer summary
DROP FUNCTION IF EXISTS public.engineer_move_summary_r2314();
CREATE FUNCTION public.engineer_move_summary_r2314()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_name text,
  move_count int,
  active_moves int,
  reverted_moves int,
  total_cost_rupees bigint,
  total_gap_days int,
  last_effective_on date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_user_id, r.engineer_name,
         COUNT(*)::int AS move_count,
         SUM(CASE WHEN r.status = 'active' THEN 1 ELSE 0 END)::int AS active_moves,
         SUM(CASE WHEN r.status = 'reverted' THEN 1 ELSE 0 END)::int AS reverted_moves,
         COALESCE(SUM(c.cost_rupees), 0)::bigint AS total_cost_rupees,
         COALESCE(SUM(c.gap_days), 0)::int AS total_gap_days,
         MAX(r.effective_on) AS last_effective_on
  FROM public.engineer_reassignments_r2314 r
  LEFT JOIN public.reassignment_costs_r2314 c ON c.reassignment_id = r.id
  GROUP BY r.engineer_user_id, r.engineer_name
  ORDER BY total_cost_rupees DESC;
END $$;

-- 5. route breakdown
DROP FUNCTION IF EXISTS public.route_breakdown_r2314();
CREATE FUNCTION public.route_breakdown_r2314()
RETURNS TABLE (
  from_region text,
  to_region text,
  move_count int,
  total_cost_rupees bigint,
  avg_cost_rupees bigint,
  total_gap_days int,
  reverted_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.from_region, r.to_region,
         COUNT(*)::int AS move_count,
         COALESCE(SUM(c.cost_rupees), 0)::bigint AS total_cost_rupees,
         CASE WHEN COUNT(*) > 0 THEN (COALESCE(SUM(c.cost_rupees), 0) / COUNT(*))::bigint ELSE 0::bigint END AS avg_cost_rupees,
         COALESCE(SUM(c.gap_days), 0)::int AS total_gap_days,
         SUM(CASE WHEN r.status = 'reverted' THEN 1 ELSE 0 END)::int AS reverted_count
  FROM public.engineer_reassignments_r2314 r
  LEFT JOIN public.reassignment_costs_r2314 c ON c.reassignment_id = r.id
  GROUP BY r.from_region, r.to_region
  ORDER BY total_cost_rupees DESC;
END $$;

-- 6. cost category mix
DROP FUNCTION IF EXISTS public.cost_category_mix_r2314();
CREATE FUNCTION public.cost_category_mix_r2314()
RETURNS TABLE (
  cost_category text,
  entry_count int,
  total_rupees bigint,
  avg_rupees bigint,
  total_gap_days int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.cost_category,
         COUNT(*)::int AS entry_count,
         COALESCE(SUM(c.cost_rupees), 0)::bigint AS total_rupees,
         CASE WHEN COUNT(*) > 0 THEN (COALESCE(SUM(c.cost_rupees), 0) / COUNT(*))::bigint ELSE 0::bigint END AS avg_rupees,
         COALESCE(SUM(c.gap_days), 0)::int AS total_gap_days
  FROM public.reassignment_costs_r2314 c
  GROUP BY c.cost_category
  ORDER BY total_rupees DESC;
END $$;

-- 7. monthly trend
DROP FUNCTION IF EXISTS public.monthly_reassignment_trend_r2314();
CREATE FUNCTION public.monthly_reassignment_trend_r2314()
RETURNS TABLE (
  month_start date,
  move_count int,
  total_cost_rupees bigint,
  total_gap_days int,
  reverted_count int,
  positive_roi_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', r.effective_on)::date AS month_start,
         COUNT(DISTINCT r.id)::int AS move_count,
         COALESCE(SUM(c.cost_rupees), 0)::bigint AS total_cost_rupees,
         COALESCE(SUM(c.gap_days), 0)::int AS total_gap_days,
         SUM(CASE WHEN r.status = 'reverted' THEN 1 ELSE 0 END)::int AS reverted_count,
         SUM(CASE WHEN c.realized_review_state = 'positive_roi' THEN 1 ELSE 0 END)::int AS positive_roi_count
  FROM public.engineer_reassignments_r2314 r
  LEFT JOIN public.reassignment_costs_r2314 c ON c.reassignment_id = r.id
  GROUP BY date_trunc('month', r.effective_on)
  ORDER BY month_start DESC;
END $$;

REVOKE ALL ON FUNCTION public.list_reassignments_r2314() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_reassignment_costs_r2314() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.negative_roi_moves_r2314() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.engineer_move_summary_r2314() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.route_breakdown_r2314() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cost_category_mix_r2314() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.monthly_reassignment_trend_r2314() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reassignments_r2314() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reassignment_costs_r2314() TO authenticated;
GRANT EXECUTE ON FUNCTION public.negative_roi_moves_r2314() TO authenticated;
GRANT EXECUTE ON FUNCTION public.engineer_move_summary_r2314() TO authenticated;
GRANT EXECUTE ON FUNCTION public.route_breakdown_r2314() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cost_category_mix_r2314() TO authenticated;
GRANT EXECUTE ON FUNCTION public.monthly_reassignment_trend_r2314() TO authenticated;

COMMIT;
