BEGIN;

-- ============================================================
-- r1454 — Spare Parts Demand Forecasting (founder console)
-- 90-day rolling demand by part_name, 30-day depletion forecast,
-- vs current bonded inventory, re-order recommendations.
-- ============================================================

-- ---------- TABLES ----------

CREATE TABLE IF NOT EXISTS public.spare_parts_demand_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  part_name text NOT NULL,
  window_start date NOT NULL,
  window_end date NOT NULL,
  units_consumed integer NOT NULL DEFAULT 0,
  orders_count integer NOT NULL DEFAULT 0,
  avg_unit_cost_rupees numeric(12,2) NOT NULL DEFAULT 0,
  daily_burn_rate numeric(12,4) NOT NULL DEFAULT 0,
  forecast_30d_units integer NOT NULL DEFAULT 0,
  forecast_30d_cost_rupees numeric(14,2) NOT NULL DEFAULT 0,
  bonded_on_hand_units integer NOT NULL DEFAULT 0,
  days_of_cover numeric(10,2),
  reorder_recommended boolean NOT NULL DEFAULT false,
  reorder_qty_suggested integer NOT NULL DEFAULT 0,
  meta jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_sp_demand_snap_part ON public.spare_parts_demand_snapshots(part_name);
CREATE INDEX IF NOT EXISTS idx_sp_demand_snap_at ON public.spare_parts_demand_snapshots(snapshot_at DESC);
CREATE INDEX IF NOT EXISTS idx_sp_demand_snap_reorder ON public.spare_parts_demand_snapshots(reorder_recommended) WHERE reorder_recommended = true;

ALTER TABLE public.spare_parts_demand_snapshots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.spare_parts_demand_snapshots FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.spare_parts_reorder_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  acted_at timestamptz NOT NULL DEFAULT now(),
  actor_user_id uuid NOT NULL,
  part_name text NOT NULL,
  action text NOT NULL CHECK (action IN ('flag_for_reorder','dismiss','adjust_qty','mark_ordered','note')),
  qty_adjusted integer,
  note text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_sp_reorder_actions_part ON public.spare_parts_reorder_actions(part_name);
CREATE INDEX IF NOT EXISTS idx_sp_reorder_actions_at ON public.spare_parts_reorder_actions(acted_at DESC);

ALTER TABLE public.spare_parts_reorder_actions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.spare_parts_reorder_actions FROM PUBLIC, anon, authenticated;

-- ---------- LOG HELPERS (VOLATILE SECDEF, founder-gated) ----------

CREATE OR REPLACE FUNCTION public.log_founder_sp_demand_view(p_scope text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.spare_parts_reorder_actions(actor_user_id, part_name, action, payload)
  VALUES (auth.uid(), '__view__', 'note', jsonb_build_object('scope', p_scope, 'at', now()));
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_sp_reorder_flag(p_part text, p_qty integer)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.spare_parts_reorder_actions(actor_user_id, part_name, action, qty_adjusted, payload)
  VALUES (auth.uid(), p_part, 'flag_for_reorder', p_qty, jsonb_build_object('flagged_at', now()))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_sp_dismiss(p_part text, p_note text)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.spare_parts_reorder_actions(actor_user_id, part_name, action, note, payload)
  VALUES (auth.uid(), p_part, 'dismiss', p_note, jsonb_build_object('dismissed_at', now()))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_sp_snapshot_refresh()
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.spare_parts_reorder_actions(actor_user_id, part_name, action, payload)
  VALUES (auth.uid(), '__refresh__', 'note', jsonb_build_object('refreshed_at', now()));
END;
$$;

-- ---------- READ RPCs (STABLE SECDEF, founder-gated) ----------

-- 1. KPI rollup
CREATE OR REPLACE FUNCTION public.founder_sp_demand_kpis()
RETURNS TABLE (
  total_parts_tracked integer,
  parts_with_demand_90d integer,
  total_units_consumed_90d integer,
  total_cost_consumed_90d_rupees numeric,
  avg_daily_burn_units numeric,
  forecast_30d_units integer,
  forecast_30d_cost_rupees numeric,
  bonded_on_hand_units integer,
  bonded_on_hand_value_rupees numeric,
  parts_needing_reorder integer,
  parts_stockout_risk_7d integer,
  parts_stockout_risk_30d integer,
  parts_overstocked integer,
  avg_days_of_cover numeric,
  top_part_units integer,
  reorder_actions_30d integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH consumed AS (
    SELECT spo.part_name,
           COALESCE(SUM(spo.quantity),0)::int AS units,
           COALESCE(SUM(spo.quantity * spo.unit_cost_rupees),0)::numeric AS cost
    FROM public.spare_part_orders spo
    WHERE spo.created_at >= now() - interval '90 days'
    GROUP BY spo.part_name
  ),
  bonded AS (
    SELECT spo.part_name,
           COALESCE(SUM(spo.quantity),0)::int AS on_hand,
           COALESCE(SUM(spo.quantity * spo.unit_cost_rupees),0)::numeric AS value
    FROM public.spare_part_orders spo
    WHERE spo.status = 'bonded'
    GROUP BY spo.part_name
  ),
  joined AS (
    SELECT COALESCE(c.part_name, b.part_name) AS part_name,
           COALESCE(c.units,0) AS units_90d,
           COALESCE(c.cost,0) AS cost_90d,
           COALESCE(b.on_hand,0) AS on_hand,
           COALESCE(b.value,0) AS on_hand_value,
           CASE WHEN COALESCE(c.units,0) > 0
                THEN COALESCE(b.on_hand,0)::numeric / (COALESCE(c.units,0)::numeric / 90.0)
                ELSE NULL END AS doc
    FROM consumed c FULL OUTER JOIN bonded b ON b.part_name = c.part_name
  )
  SELECT
    (SELECT COUNT(*)::int FROM joined),
    (SELECT COUNT(*)::int FROM joined WHERE units_90d > 0),
    COALESCE((SELECT SUM(units_90d)::int FROM joined),0),
    COALESCE((SELECT SUM(cost_90d) FROM joined),0),
    COALESCE((SELECT AVG(units_90d/90.0) FROM joined WHERE units_90d>0),0),
    COALESCE((SELECT SUM(ROUND(units_90d/90.0 * 30))::int FROM joined),0),
    COALESCE((SELECT SUM(cost_90d/90.0 * 30) FROM joined),0),
    COALESCE((SELECT SUM(on_hand)::int FROM joined),0),
    COALESCE((SELECT SUM(on_hand_value) FROM joined),0),
    (SELECT COUNT(*)::int FROM joined WHERE doc IS NOT NULL AND doc < 30),
    (SELECT COUNT(*)::int FROM joined WHERE doc IS NOT NULL AND doc < 7),
    (SELECT COUNT(*)::int FROM joined WHERE doc IS NOT NULL AND doc < 30 AND doc >= 0),
    (SELECT COUNT(*)::int FROM joined WHERE doc IS NOT NULL AND doc > 180),
    COALESCE((SELECT AVG(doc) FROM joined WHERE doc IS NOT NULL),0),
    COALESCE((SELECT MAX(units_90d)::int FROM joined),0),
    (SELECT COUNT(*)::int FROM public.spare_parts_reorder_actions WHERE acted_at >= now() - interval '30 days' AND action <> 'note');
END;
$$;

-- 2. Demand by part (90d rolling)
CREATE OR REPLACE FUNCTION public.founder_sp_demand_by_part(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id text,
  part_name text,
  units_90d integer,
  orders_90d integer,
  cost_90d_rupees numeric,
  daily_burn numeric,
  forecast_30d_units integer,
  on_hand_units integer,
  days_of_cover numeric,
  risk_band text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH consumed AS (
    SELECT spo.part_name,
           SUM(spo.quantity)::int AS units,
           COUNT(*)::int AS orders,
           SUM(spo.quantity * spo.unit_cost_rupees)::numeric AS cost
    FROM public.spare_part_orders spo
    WHERE spo.created_at >= now() - interval '90 days'
    GROUP BY spo.part_name
  ),
  bonded AS (
    SELECT spo.part_name, SUM(spo.quantity)::int AS on_hand
    FROM public.spare_part_orders spo
    WHERE spo.status = 'bonded'
    GROUP BY spo.part_name
  )
  SELECT
    md5(COALESCE(c.part_name,b.part_name)) AS id,
    COALESCE(c.part_name, b.part_name) AS part_name,
    COALESCE(c.units,0),
    COALESCE(c.orders,0),
    COALESCE(c.cost,0),
    ROUND(COALESCE(c.units,0)/90.0, 4),
    ROUND(COALESCE(c.units,0)/90.0 * 30)::int,
    COALESCE(b.on_hand,0),
    CASE WHEN COALESCE(c.units,0) > 0
         THEN ROUND(COALESCE(b.on_hand,0)::numeric / (COALESCE(c.units,0)::numeric/90.0), 2)
         ELSE NULL END,
    CASE
      WHEN COALESCE(c.units,0) = 0 THEN 'no_demand'
      WHEN COALESCE(b.on_hand,0) = 0 THEN 'stockout'
      WHEN COALESCE(b.on_hand,0)::numeric / (COALESCE(c.units,0)::numeric/90.0) < 7 THEN 'critical'
      WHEN COALESCE(b.on_hand,0)::numeric / (COALESCE(c.units,0)::numeric/90.0) < 30 THEN 'low'
      WHEN COALESCE(b.on_hand,0)::numeric / (COALESCE(c.units,0)::numeric/90.0) > 180 THEN 'overstock'
      ELSE 'healthy'
    END
  FROM consumed c FULL OUTER JOIN bonded b ON b.part_name = c.part_name
  ORDER BY COALESCE(c.units,0) DESC
  LIMIT p_limit;
END;
$$;

-- 3. Re-order recommendations
CREATE OR REPLACE FUNCTION public.founder_sp_reorder_recommendations(p_limit integer DEFAULT 30)
RETURNS TABLE (
  id text,
  part_name text,
  days_of_cover numeric,
  on_hand_units integer,
  forecast_30d_units integer,
  suggested_reorder_qty integer,
  estimated_reorder_cost_rupees numeric,
  urgency text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH consumed AS (
    SELECT spo.part_name,
           SUM(spo.quantity)::int AS units,
           AVG(spo.unit_cost_rupees)::numeric AS avg_cost
    FROM public.spare_part_orders spo
    WHERE spo.created_at >= now() - interval '90 days'
    GROUP BY spo.part_name
  ),
  bonded AS (
    SELECT spo.part_name, SUM(spo.quantity)::int AS on_hand
    FROM public.spare_part_orders spo
    WHERE spo.status = 'bonded'
    GROUP BY spo.part_name
  ),
  calc AS (
    SELECT c.part_name,
           COALESCE(b.on_hand,0) AS on_hand,
           ROUND(c.units/90.0 * 30)::int AS forecast_30d,
           GREATEST(0, ROUND(c.units/90.0 * 60) - COALESCE(b.on_hand,0))::int AS suggest_qty,
           c.avg_cost,
           CASE WHEN c.units > 0
                THEN ROUND(COALESCE(b.on_hand,0)::numeric / (c.units::numeric/90.0), 2)
                ELSE NULL END AS doc
    FROM consumed c LEFT JOIN bonded b ON b.part_name = c.part_name
    WHERE c.units > 0
  )
  SELECT
    md5(part_name) AS id,
    part_name,
    doc,
    on_hand,
    forecast_30d,
    suggest_qty,
    (suggest_qty * avg_cost)::numeric,
    CASE
      WHEN doc IS NULL OR doc < 7 THEN 'urgent'
      WHEN doc < 14 THEN 'high'
      WHEN doc < 30 THEN 'medium'
      ELSE 'low'
    END
  FROM calc
  WHERE doc IS NULL OR doc < 30
  ORDER BY COALESCE(doc, -1) ASC, suggest_qty DESC
  LIMIT p_limit;
END;
$$;

-- 4. Weekly demand trend (last 13 weeks)
CREATE OR REPLACE FUNCTION public.founder_sp_weekly_trend(p_limit integer DEFAULT 13)
RETURNS TABLE (
  id text,
  week_start date,
  units_consumed integer,
  orders_count integer,
  cost_rupees numeric,
  distinct_parts integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(date_trunc('week', spo.created_at), 'YYYY-IW') AS id,
    date_trunc('week', spo.created_at)::date,
    SUM(spo.quantity)::int,
    COUNT(*)::int,
    SUM(spo.quantity * spo.unit_cost_rupees)::numeric,
    COUNT(DISTINCT spo.part_name)::int
  FROM public.spare_part_orders spo
  WHERE spo.created_at >= now() - (p_limit * interval '7 days')
  GROUP BY date_trunc('week', spo.created_at)
  ORDER BY date_trunc('week', spo.created_at) DESC;
END;
$$;

-- 5. Stockout risk parts (DOC < 7)
CREATE OR REPLACE FUNCTION public.founder_sp_stockout_risk(p_limit integer DEFAULT 25)
RETURNS TABLE (
  id text,
  part_name text,
  on_hand_units integer,
  daily_burn numeric,
  days_to_stockout numeric,
  last_order_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH consumed AS (
    SELECT spo.part_name,
           SUM(spo.quantity)::int AS units,
           MAX(spo.created_at) AS last_at
    FROM public.spare_part_orders spo
    WHERE spo.created_at >= now() - interval '90 days'
    GROUP BY spo.part_name
  ),
  bonded AS (
    SELECT spo.part_name, SUM(spo.quantity)::int AS on_hand
    FROM public.spare_part_orders spo
    WHERE spo.status = 'bonded'
    GROUP BY spo.part_name
  )
  SELECT
    md5(c.part_name) AS id,
    c.part_name,
    COALESCE(b.on_hand,0),
    ROUND(c.units/90.0, 4),
    CASE WHEN c.units > 0
         THEN ROUND(COALESCE(b.on_hand,0)::numeric / (c.units::numeric/90.0), 2)
         ELSE NULL END,
    c.last_at
  FROM consumed c LEFT JOIN bonded b ON b.part_name = c.part_name
  WHERE c.units > 0
    AND (COALESCE(b.on_hand,0) = 0 OR COALESCE(b.on_hand,0)::numeric / (c.units::numeric/90.0) < 7)
  ORDER BY COALESCE(b.on_hand,0)::numeric / NULLIF(c.units::numeric/90.0, 0) ASC NULLS FIRST
  LIMIT p_limit;
END;
$$;

-- 6. Overstocked parts (DOC > 180)
CREATE OR REPLACE FUNCTION public.founder_sp_overstocked(p_limit integer DEFAULT 25)
RETURNS TABLE (
  id text,
  part_name text,
  on_hand_units integer,
  on_hand_value_rupees numeric,
  days_of_cover numeric,
  excess_units integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH consumed AS (
    SELECT spo.part_name, SUM(spo.quantity)::int AS units
    FROM public.spare_part_orders spo
    WHERE spo.created_at >= now() - interval '90 days'
    GROUP BY spo.part_name
  ),
  bonded AS (
    SELECT spo.part_name,
           SUM(spo.quantity)::int AS on_hand,
           SUM(spo.quantity * spo.unit_cost_rupees)::numeric AS value
    FROM public.spare_part_orders spo
    WHERE spo.status = 'bonded'
    GROUP BY spo.part_name
  )
  SELECT
    md5(b.part_name) AS id,
    b.part_name,
    b.on_hand,
    b.value,
    CASE WHEN COALESCE(c.units,0) > 0
         THEN ROUND(b.on_hand::numeric / (c.units::numeric/90.0), 2)
         ELSE 9999 END,
    GREATEST(0, b.on_hand - ROUND(COALESCE(c.units,0)/90.0 * 60))::int
  FROM bonded b LEFT JOIN consumed c ON c.part_name = b.part_name
  WHERE COALESCE(c.units,0) = 0
     OR b.on_hand::numeric / NULLIF(c.units::numeric/90.0, 0) > 180
  ORDER BY b.value DESC
  LIMIT p_limit;
END;
$$;

-- 7. Recent reorder actions audit
CREATE OR REPLACE FUNCTION public.founder_sp_recent_actions(p_limit integer DEFAULT 30)
RETURNS TABLE (
  id uuid,
  acted_at timestamptz,
  part_name text,
  action text,
  qty_adjusted integer,
  note text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.acted_at, a.part_name, a.action, a.qty_adjusted, a.note
  FROM public.spare_parts_reorder_actions a
  WHERE a.action <> 'note'
  ORDER BY a.acted_at DESC
  LIMIT p_limit;
END;
$$;

-- ---------- GRANTS ----------

GRANT EXECUTE ON FUNCTION public.log_founder_sp_demand_view(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_sp_reorder_flag(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_sp_dismiss(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_sp_snapshot_refresh() TO authenticated;

GRANT EXECUTE ON FUNCTION public.founder_sp_demand_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_sp_demand_by_part(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_sp_reorder_recommendations(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_sp_weekly_trend(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_sp_stockout_risk(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_sp_overstocked(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_sp_recent_actions(integer) TO authenticated;

COMMIT;