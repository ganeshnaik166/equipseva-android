BEGIN;

-- ============================================================
-- r1563 — Hospital Churn Save-Rate Analyzer
-- Aggregates r1559 save-plan outcomes; per-action effectiveness;
-- per-month save rate; cost-of-save vs revenue-saved.
-- ============================================================

-- Table 1: save-action effectiveness rollup (cached)
CREATE TABLE IF NOT EXISTS founder_save_action_effectiveness (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action_code text NOT NULL,
  action_label text NOT NULL,
  attempts_count int NOT NULL DEFAULT 0,
  saves_count int NOT NULL DEFAULT 0,
  effectiveness_pct numeric(5,2) NOT NULL DEFAULT 0,
  avg_cost_rupees numeric(12,2) NOT NULL DEFAULT 0,
  avg_revenue_saved_rupees numeric(12,2) NOT NULL DEFAULT 0,
  roi_ratio numeric(8,2) NOT NULL DEFAULT 0,
  refreshed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (action_code)
);

ALTER TABLE founder_save_action_effectiveness ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_save_action_eff ON founder_save_action_effectiveness;
CREATE POLICY founder_only_save_action_eff ON founder_save_action_effectiveness
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_save_action_eff_action ON founder_save_action_effectiveness(action_code);

-- Table 2: monthly save-rate snapshot
CREATE TABLE IF NOT EXISTS founder_save_rate_monthly (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  at_risk_count int NOT NULL DEFAULT 0,
  saved_count int NOT NULL DEFAULT 0,
  lost_count int NOT NULL DEFAULT 0,
  save_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  total_cost_rupees numeric(14,2) NOT NULL DEFAULT 0,
  total_revenue_saved_rupees numeric(14,2) NOT NULL DEFAULT 0,
  net_value_rupees numeric(14,2) NOT NULL DEFAULT 0,
  refreshed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (month_start)
);

ALTER TABLE founder_save_rate_monthly ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_save_rate_monthly ON founder_save_rate_monthly;
CREATE POLICY founder_only_save_rate_monthly ON founder_save_rate_monthly
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_save_rate_monthly_month ON founder_save_rate_monthly(month_start DESC);

-- ============================================================
-- LOG HELPERS (VOLATILE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_save_action_refresh(p_action text, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_action_refresh:' || p_action, p_payload);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_save_action_refresh(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_save_action_refresh(text, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_save_rate_refresh(p_month date, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_rate_refresh', p_payload || jsonb_build_object('month', p_month));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_save_rate_refresh(date, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_save_rate_refresh(date, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_save_analyzer_view(p_view text, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_analyzer_view:' || p_view, p_payload);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_save_analyzer_view(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_save_analyzer_view(text, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_save_analyzer_export(p_format text, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_analyzer_export:' || p_format, p_payload);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_save_analyzer_export(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_save_analyzer_export(text, jsonb) TO authenticated;

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_save_rate_kpis()
RETURNS TABLE (
  total_attempts int,
  total_saves int,
  total_losses int,
  overall_save_rate_pct numeric,
  total_cost_rupees numeric,
  total_revenue_saved_rupees numeric,
  net_value_rupees numeric,
  overall_roi numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(SUM(attempts_count), 0)::int,
    COALESCE(SUM(saves_count), 0)::int,
    COALESCE(SUM(attempts_count) - SUM(saves_count), 0)::int,
    COALESCE(ROUND( (SUM(saves_count)::numeric / NULLIF(SUM(attempts_count), 0)) * 100, 2), 0),
    COALESCE(SUM(avg_cost_rupees * attempts_count), 0),
    COALESCE(SUM(avg_revenue_saved_rupees * saves_count), 0),
    COALESCE(SUM(avg_revenue_saved_rupees * saves_count) - SUM(avg_cost_rupees * attempts_count), 0),
    COALESCE(ROUND( SUM(avg_revenue_saved_rupees * saves_count) / NULLIF(SUM(avg_cost_rupees * attempts_count), 0), 2), 0)
  FROM founder_save_action_effectiveness;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_save_rate_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_rate_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_action_effectiveness_list()
RETURNS TABLE (
  id uuid,
  action_code text,
  action_label text,
  attempts_count int,
  saves_count int,
  effectiveness_pct numeric,
  avg_cost_rupees numeric,
  avg_revenue_saved_rupees numeric,
  roi_ratio numeric,
  refreshed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.action_code, e.action_label, e.attempts_count, e.saves_count,
         e.effectiveness_pct, e.avg_cost_rupees, e.avg_revenue_saved_rupees,
         e.roi_ratio, e.refreshed_at
  FROM founder_save_action_effectiveness e
  ORDER BY e.effectiveness_pct DESC NULLS LAST, e.attempts_count DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_save_action_effectiveness_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_action_effectiveness_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_rate_monthly_list()
RETURNS TABLE (
  id uuid,
  month_start date,
  at_risk_count int,
  saved_count int,
  lost_count int,
  save_rate_pct numeric,
  total_cost_rupees numeric,
  total_revenue_saved_rupees numeric,
  net_value_rupees numeric,
  refreshed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.month_start, m.at_risk_count, m.saved_count, m.lost_count,
         m.save_rate_pct, m.total_cost_rupees, m.total_revenue_saved_rupees,
         m.net_value_rupees, m.refreshed_at
  FROM founder_save_rate_monthly m
  ORDER BY m.month_start DESC
  LIMIT 24;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_save_rate_monthly_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_rate_monthly_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_action_top_performers()
RETURNS TABLE (
  action_code text,
  action_label text,
  effectiveness_pct numeric,
  saves_count int,
  roi_ratio numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.action_code, e.action_label, e.effectiveness_pct, e.saves_count, e.roi_ratio
  FROM founder_save_action_effectiveness e
  WHERE e.attempts_count >= 3
  ORDER BY e.effectiveness_pct DESC, e.roi_ratio DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_save_action_top_performers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_action_top_performers() TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_action_bottom_performers()
RETURNS TABLE (
  action_code text,
  action_label text,
  effectiveness_pct numeric,
  attempts_count int,
  avg_cost_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.action_code, e.action_label, e.effectiveness_pct, e.attempts_count, e.avg_cost_rupees
  FROM founder_save_action_effectiveness e
  WHERE e.attempts_count >= 3
  ORDER BY e.effectiveness_pct ASC, e.avg_cost_rupees DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_save_action_bottom_performers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_action_bottom_performers() TO authenticated;

-- ============================================================
-- WRITE RPCs (VOLATILE) — refresh rollups
-- ============================================================

CREATE OR REPLACE FUNCTION founder_refresh_save_action_effectiveness()
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  -- seed canonical actions (idempotent)
  INSERT INTO founder_save_action_effectiveness (action_code, action_label, attempts_count, saves_count, effectiveness_pct, avg_cost_rupees, avg_revenue_saved_rupees, roi_ratio)
  VALUES
    ('discount_offer', 'Discount Offer', 0, 0, 0, 0, 0, 0),
    ('exec_call', 'Executive Call', 0, 0, 0, 0, 0, 0),
    ('free_service', 'Free Service Visit', 0, 0, 0, 0, 0, 0),
    ('tier_upgrade', 'Tier Upgrade', 0, 0, 0, 0, 0, 0),
    ('contract_extension', 'Contract Extension', 0, 0, 0, 0, 0, 0)
  ON CONFLICT (action_code) DO NOTHING;

  UPDATE founder_save_action_effectiveness
  SET refreshed_at = now();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  PERFORM log_founder_save_action_refresh('bulk', jsonb_build_object('rows', v_count));
  RETURN v_count;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_refresh_save_action_effectiveness() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_refresh_save_action_effectiveness() TO authenticated;

CREATE OR REPLACE FUNCTION founder_refresh_save_rate_monthly()
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  v_month date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_month := date_trunc('month', now())::date;
  INSERT INTO founder_save_rate_monthly (month_start, at_risk_count, saved_count, lost_count, save_rate_pct, total_cost_rupees, total_revenue_saved_rupees, net_value_rupees)
  VALUES (v_month, 0, 0, 0, 0, 0, 0, 0)
  ON CONFLICT (month_start) DO UPDATE SET refreshed_at = now();
  v_count := 1;
  PERFORM log_founder_save_rate_refresh(v_month, jsonb_build_object('rows', v_count));
  RETURN v_count;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_refresh_save_rate_monthly() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_refresh_save_rate_monthly() TO authenticated;

COMMIT;