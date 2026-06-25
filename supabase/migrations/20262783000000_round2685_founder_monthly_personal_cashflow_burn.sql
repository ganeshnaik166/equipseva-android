BEGIN;

-- ============================================================
-- Round 2685: Founder Monthly Personal Cashflow Burn
-- Track founder personal monthly budget vs actuals, burn rate,
-- runway months, action items per category.
-- ============================================================

-- ------------------------------------------------------------
-- Table 1: personal_cashflow_categories_r2685
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS personal_cashflow_categories_r2685 (
  id              bigserial PRIMARY KEY,
  category        text NOT NULL,
  month_label     text NOT NULL,
  budget_rupees   numeric(14,2) NOT NULL CHECK (budget_rupees >= 0),
  spent_rupees    numeric(14,2) NOT NULL CHECK (spent_rupees >= 0),
  burn_rate_pct   numeric(6,2) NOT NULL CHECK (burn_rate_pct >= 0),
  runway_months   numeric(6,2) NOT NULL CHECK (runway_months >= 0),
  severity        text NOT NULL CHECK (severity IN ('green','amber','red','critical')),
  action_required text NOT NULL,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE personal_cashflow_categories_r2685 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON personal_cashflow_categories_r2685;
CREATE POLICY founder_all ON personal_cashflow_categories_r2685
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO personal_cashflow_categories_r2685
  (category, month_label, budget_rupees, spent_rupees, burn_rate_pct, runway_months, severity, action_required, notes)
VALUES
  ('Rent + Utilities',   '2026-06', 45000.00, 47200.00, 104.89,  8.40, 'amber',    'Negotiate rent renewal for July',                  'Power bill spiked due to summer AC load'),
  ('Groceries + Food',   '2026-06', 22000.00, 28400.00, 129.09,  6.20, 'red',      'Cut eating-out by 50% next month',                 'Swiggy/Zomato up 3x'),
  ('Transport + Fuel',   '2026-06', 12000.00,  9800.00,  81.67, 11.20, 'green',    'On track — maintain',                              'WFH days helped'),
  ('Health + Insurance', '2026-06', 18000.00, 17500.00,  97.22,  9.80, 'green',    'Continue current premium',                         'Annual term policy renewal due Aug'),
  ('Family Support',     '2026-06', 35000.00, 35000.00, 100.00,  8.10, 'amber',    'Lock-in via standing instruction',                 'Parents medical + sister tuition'),
  ('SaaS + Tools',       '2026-06',  8000.00, 14200.00, 177.50,  4.30, 'critical', 'Audit + cancel 5 unused subscriptions THIS WEEK',  'Notion + Linear + Cursor + AWS + Figma stacking'),
  ('Discretionary',      '2026-06', 15000.00, 22600.00, 150.67,  5.10, 'red',      'Freeze discretionary spend for 30 days',           'Books + gadgets + travel'),
  ('Taxes + Compliance', '2026-06', 25000.00, 24000.00,  96.00,  9.20, 'green',    'Advance tax June 15 done',                         'GST + TDS monthly');

-- ------------------------------------------------------------
-- Table 2: personal_cashflow_actions_r2685
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS personal_cashflow_actions_r2685 (
  id              bigserial PRIMARY KEY,
  category        text NOT NULL,
  action_title    text NOT NULL,
  expected_saving_rupees numeric(14,2) NOT NULL CHECK (expected_saving_rupees >= 0),
  due_date        date NOT NULL,
  priority        text NOT NULL CHECK (priority IN ('low','medium','high','urgent')),
  status          text NOT NULL CHECK (status IN ('pending','in_progress','done','dropped')),
  owner           text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE personal_cashflow_actions_r2685 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON personal_cashflow_actions_r2685;
CREATE POLICY founder_all ON personal_cashflow_actions_r2685
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO personal_cashflow_actions_r2685
  (category, action_title, expected_saving_rupees, due_date, priority, status, owner)
VALUES
  ('SaaS + Tools',     'Cancel Notion personal + use team seat',           1200.00, '2026-06-25', 'urgent',  'pending',     'Founder'),
  ('SaaS + Tools',     'Drop Cursor — switch to Claude Code only',         2000.00, '2026-06-30', 'urgent',  'in_progress', 'Founder'),
  ('Discretionary',    '30-day no-buy challenge on Amazon',                7500.00, '2026-07-15', 'high',    'pending',     'Founder'),
  ('Groceries + Food', 'Meal-prep Sunday — cut delivery to 2x/week',       6000.00, '2026-06-30', 'high',    'in_progress', 'Founder'),
  ('Rent + Utilities', 'Install smart plug to kill standby load',          1800.00, '2026-07-05', 'medium',  'pending',     'Founder'),
  ('Family Support',   'Convert to auto-debit standing instruction',          0.00, '2026-06-28', 'medium',  'done',        'Founder'),
  ('Transport + Fuel', 'Maintain WFH 3x/week schedule',                    2200.00, '2026-07-31', 'low',     'in_progress', 'Founder');

-- ============================================================
-- RPCs (7+) — all SECURITY DEFINER + is_founder() gated
-- ============================================================

-- RPC 1: list categories
DROP FUNCTION IF EXISTS founder_personal_cashflow_categories_r2685();
CREATE OR REPLACE FUNCTION founder_personal_cashflow_categories_r2685()
RETURNS SETOF personal_cashflow_categories_r2685
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM personal_cashflow_categories_r2685
  ORDER BY
    CASE severity WHEN 'critical' THEN 1 WHEN 'red' THEN 2 WHEN 'amber' THEN 3 ELSE 4 END,
    burn_rate_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_personal_cashflow_categories_r2685() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_personal_cashflow_categories_r2685() TO authenticated;

-- RPC 2: list actions
DROP FUNCTION IF EXISTS founder_personal_cashflow_actions_r2685();
CREATE OR REPLACE FUNCTION founder_personal_cashflow_actions_r2685()
RETURNS SETOF personal_cashflow_actions_r2685
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM personal_cashflow_actions_r2685
  ORDER BY
    CASE priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_personal_cashflow_actions_r2685() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_personal_cashflow_actions_r2685() TO authenticated;

-- RPC 3: KPI summary
DROP FUNCTION IF EXISTS founder_personal_cashflow_summary_r2685();
CREATE OR REPLACE FUNCTION founder_personal_cashflow_summary_r2685()
RETURNS TABLE (
  total_budget_rupees   numeric,
  total_spent_rupees    numeric,
  overall_burn_pct      numeric,
  weighted_runway_months numeric,
  category_count        bigint,
  critical_count        bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(SUM(budget_rupees),0)::numeric,
    COALESCE(SUM(spent_rupees),0)::numeric,
    CASE WHEN COALESCE(SUM(budget_rupees),0) = 0 THEN 0
         ELSE ROUND((SUM(spent_rupees) / SUM(budget_rupees) * 100)::numeric, 2)
    END,
    CASE WHEN COALESCE(SUM(spent_rupees),0) = 0 THEN 0
         ELSE ROUND((SUM(runway_months * spent_rupees) / SUM(spent_rupees))::numeric, 2)
    END,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE severity = 'critical')::bigint
  FROM personal_cashflow_categories_r2685;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_personal_cashflow_summary_r2685() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_personal_cashflow_summary_r2685() TO authenticated;

-- RPC 4: severity breakdown
DROP FUNCTION IF EXISTS founder_personal_cashflow_by_severity_r2685();
CREATE OR REPLACE FUNCTION founder_personal_cashflow_by_severity_r2685()
RETURNS TABLE (
  severity         text,
  category_count   bigint,
  total_spent      numeric,
  avg_burn_pct     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.severity,
    COUNT(*)::bigint,
    COALESCE(SUM(c.spent_rupees),0)::numeric,
    ROUND(AVG(c.burn_rate_pct)::numeric, 2)
  FROM personal_cashflow_categories_r2685 c
  GROUP BY c.severity
  ORDER BY
    CASE c.severity WHEN 'critical' THEN 1 WHEN 'red' THEN 2 WHEN 'amber' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_personal_cashflow_by_severity_r2685() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_personal_cashflow_by_severity_r2685() TO authenticated;

-- RPC 5: top overspend categories
DROP FUNCTION IF EXISTS founder_personal_cashflow_top_overspend_r2685(int);
CREATE OR REPLACE FUNCTION founder_personal_cashflow_top_overspend_r2685(p_limit int DEFAULT 5)
RETURNS TABLE (
  category        text,
  budget_rupees   numeric,
  spent_rupees    numeric,
  overspend_rupees numeric,
  burn_rate_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.category,
    c.budget_rupees,
    c.spent_rupees,
    GREATEST(c.spent_rupees - c.budget_rupees, 0)::numeric,
    c.burn_rate_pct
  FROM personal_cashflow_categories_r2685 c
  WHERE c.spent_rupees > c.budget_rupees
  ORDER BY (c.spent_rupees - c.budget_rupees) DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_personal_cashflow_top_overspend_r2685(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_personal_cashflow_top_overspend_r2685(int) TO authenticated;

-- RPC 6: actions by status
DROP FUNCTION IF EXISTS founder_personal_cashflow_actions_by_status_r2685();
CREATE OR REPLACE FUNCTION founder_personal_cashflow_actions_by_status_r2685()
RETURNS TABLE (
  status            text,
  action_count      bigint,
  expected_savings  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.status,
    COUNT(*)::bigint,
    COALESCE(SUM(a.expected_saving_rupees),0)::numeric
  FROM personal_cashflow_actions_r2685 a
  GROUP BY a.status
  ORDER BY
    CASE a.status WHEN 'pending' THEN 1 WHEN 'in_progress' THEN 2 WHEN 'done' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_personal_cashflow_actions_by_status_r2685() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_personal_cashflow_actions_by_status_r2685() TO authenticated;

-- RPC 7: runway alert — categories below threshold
DROP FUNCTION IF EXISTS founder_personal_cashflow_runway_alert_r2685(numeric);
CREATE OR REPLACE FUNCTION founder_personal_cashflow_runway_alert_r2685(p_threshold_months numeric DEFAULT 6.0)
RETURNS TABLE (
  category         text,
  runway_months    numeric,
  burn_rate_pct    numeric,
  action_required  text,
  severity         text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.category,
    c.runway_months,
    c.burn_rate_pct,
    c.action_required,
    c.severity
  FROM personal_cashflow_categories_r2685 c
  WHERE c.runway_months <= p_threshold_months
  ORDER BY c.runway_months ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_personal_cashflow_runway_alert_r2685(numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_personal_cashflow_runway_alert_r2685(numeric) TO authenticated;

-- RPC 8: potential savings if all pending+in_progress actions land
DROP FUNCTION IF EXISTS founder_personal_cashflow_potential_savings_r2685();
CREATE OR REPLACE FUNCTION founder_personal_cashflow_potential_savings_r2685()
RETURNS TABLE (
  open_action_count    bigint,
  potential_savings    numeric,
  urgent_count         bigint,
  due_within_7_days    bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE a.status IN ('pending','in_progress'))::bigint,
    COALESCE(SUM(a.expected_saving_rupees) FILTER (WHERE a.status IN ('pending','in_progress')),0)::numeric,
    COUNT(*) FILTER (WHERE a.priority = 'urgent' AND a.status IN ('pending','in_progress'))::bigint,
    COUNT(*) FILTER (WHERE a.due_date <= (CURRENT_DATE + INTERVAL '7 days') AND a.status IN ('pending','in_progress'))::bigint
  FROM personal_cashflow_actions_r2685 a;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_personal_cashflow_potential_savings_r2685() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_personal_cashflow_potential_savings_r2685() TO authenticated;

COMMIT;
