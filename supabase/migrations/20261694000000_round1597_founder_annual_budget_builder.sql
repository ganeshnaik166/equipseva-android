BEGIN;

-- Annual departmental budget header (one row per fiscal year)
CREATE TABLE IF NOT EXISTS founder_annual_budgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fiscal_year int NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','review','locked')),
  locked_at timestamptz,
  locked_by_email text,
  total_proposed_rupees numeric(14,2) NOT NULL DEFAULT 0,
  total_approved_rupees numeric(14,2) NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_annual_budgets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_annual_budgets_founder_only ON founder_annual_budgets;
CREATE POLICY founder_annual_budgets_founder_only ON founder_annual_budgets
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Per-line-item rows (department + line + proposed vs approved)
CREATE TABLE IF NOT EXISTS founder_annual_budget_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_id uuid NOT NULL REFERENCES founder_annual_budgets(id) ON DELETE CASCADE,
  department text NOT NULL CHECK (department IN ('engineering','sales','ops','marketing','g_and_a')),
  line_item text NOT NULL,
  category text NOT NULL DEFAULT 'opex' CHECK (category IN ('opex','capex','headcount','tooling','travel','other')),
  proposed_rupees numeric(14,2) NOT NULL DEFAULT 0,
  approved_rupees numeric(14,2) NOT NULL DEFAULT 0,
  actual_spend_rupees numeric(14,2) NOT NULL DEFAULT 0,
  variance_rupees numeric(14,2) NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_annual_budget_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_annual_budget_lines_founder_only ON founder_annual_budget_lines;
CREATE POLICY founder_annual_budget_lines_founder_only ON founder_annual_budget_lines
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_fab_lines_budget ON founder_annual_budget_lines(budget_id);
CREATE INDEX IF NOT EXISTS idx_fab_lines_dept ON founder_annual_budget_lines(department);

-- =========================================================
-- log helpers (VOLATILE SECDEF, founder-gated)
-- =========================================================

CREATE OR REPLACE FUNCTION log_founder_budget_create(p_year int, p_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'budget_create', jsonb_build_object('fiscal_year', p_year, 'budget_id', p_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_budget_create(int, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_budget_create(int, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_budget_line_upsert(p_line_id uuid, p_dept text, p_proposed numeric, p_approved numeric)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'budget_line_upsert', jsonb_build_object('line_id', p_line_id, 'department', p_dept, 'proposed', p_proposed, 'approved', p_approved));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_budget_line_upsert(uuid, text, numeric, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_budget_line_upsert(uuid, text, numeric, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_budget_lock(p_id uuid, p_year int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'budget_lock', jsonb_build_object('budget_id', p_id, 'fiscal_year', p_year));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_budget_lock(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_budget_lock(uuid, int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_budget_variance_snapshot(p_id uuid, p_variance numeric)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'budget_variance_snapshot', jsonb_build_object('budget_id', p_id, 'variance_rupees', p_variance));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_budget_variance_snapshot(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_budget_variance_snapshot(uuid, numeric) TO authenticated;

-- =========================================================
-- READ RPCs (STABLE)
-- =========================================================

CREATE OR REPLACE FUNCTION founder_budget_kpis()
RETURNS TABLE(
  total_budgets bigint,
  current_year int,
  current_proposed numeric,
  current_approved numeric,
  current_actual numeric,
  current_variance numeric,
  locked_budgets bigint,
  draft_budgets bigint,
  eng_approved numeric,
  sales_approved numeric,
  ops_approved numeric,
  marketing_approved numeric,
  g_and_a_approved numeric,
  line_items_total bigint,
  over_budget_lines bigint,
  under_budget_lines bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cur int;
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT fiscal_year, id INTO v_cur, v_id
    FROM founder_annual_budgets ORDER BY fiscal_year DESC LIMIT 1;

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM founder_annual_budgets),
    COALESCE(v_cur, EXTRACT(YEAR FROM now())::int),
    COALESCE((SELECT total_proposed_rupees FROM founder_annual_budgets WHERE id = v_id), 0),
    COALESCE((SELECT total_approved_rupees FROM founder_annual_budgets WHERE id = v_id), 0),
    COALESCE((SELECT SUM(actual_spend_rupees) FROM founder_annual_budget_lines WHERE budget_id = v_id), 0),
    COALESCE((SELECT SUM(variance_rupees) FROM founder_annual_budget_lines WHERE budget_id = v_id), 0),
    (SELECT count(*) FROM founder_annual_budgets WHERE status = 'locked'),
    (SELECT count(*) FROM founder_annual_budgets WHERE status = 'draft'),
    COALESCE((SELECT SUM(approved_rupees) FROM founder_annual_budget_lines WHERE budget_id = v_id AND department='engineering'), 0),
    COALESCE((SELECT SUM(approved_rupees) FROM founder_annual_budget_lines WHERE budget_id = v_id AND department='sales'), 0),
    COALESCE((SELECT SUM(approved_rupees) FROM founder_annual_budget_lines WHERE budget_id = v_id AND department='ops'), 0),
    COALESCE((SELECT SUM(approved_rupees) FROM founder_annual_budget_lines WHERE budget_id = v_id AND department='marketing'), 0),
    COALESCE((SELECT SUM(approved_rupees) FROM founder_annual_budget_lines WHERE budget_id = v_id AND department='g_and_a'), 0),
    COALESCE((SELECT count(*) FROM founder_annual_budget_lines WHERE budget_id = v_id), 0),
    COALESCE((SELECT count(*) FROM founder_annual_budget_lines WHERE budget_id = v_id AND actual_spend_rupees > approved_rupees), 0),
    COALESCE((SELECT count(*) FROM founder_annual_budget_lines WHERE budget_id = v_id AND actual_spend_rupees < approved_rupees), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_budget_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_budget_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_budget_list_years()
RETURNS TABLE(
  id uuid,
  fiscal_year int,
  status text,
  total_proposed_rupees numeric,
  total_approved_rupees numeric,
  locked_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.fiscal_year, b.status, b.total_proposed_rupees, b.total_approved_rupees, b.locked_at, b.created_at
    FROM founder_annual_budgets b
   ORDER BY b.fiscal_year DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_budget_list_years() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_budget_list_years() TO authenticated;

CREATE OR REPLACE FUNCTION founder_budget_department_rollup()
RETURNS TABLE(
  department text,
  line_count bigint,
  proposed_rupees numeric,
  approved_rupees numeric,
  actual_spend_rupees numeric,
  variance_rupees numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_id FROM founder_annual_budgets ORDER BY fiscal_year DESC LIMIT 1;
  RETURN QUERY
  SELECT l.department,
         count(*)::bigint,
         COALESCE(SUM(l.proposed_rupees),0),
         COALESCE(SUM(l.approved_rupees),0),
         COALESCE(SUM(l.actual_spend_rupees),0),
         COALESCE(SUM(l.variance_rupees),0)
    FROM founder_annual_budget_lines l
   WHERE l.budget_id = v_id
   GROUP BY l.department
   ORDER BY 4 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_budget_department_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_budget_department_rollup() TO authenticated;

CREATE OR REPLACE FUNCTION founder_budget_lines_recent()
RETURNS TABLE(
  id uuid,
  fiscal_year int,
  department text,
  line_item text,
  category text,
  proposed_rupees numeric,
  approved_rupees numeric,
  actual_spend_rupees numeric,
  variance_rupees numeric,
  updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, b.fiscal_year, l.department, l.line_item, l.category,
         l.proposed_rupees, l.approved_rupees, l.actual_spend_rupees, l.variance_rupees, l.updated_at
    FROM founder_annual_budget_lines l
    JOIN founder_annual_budgets b ON b.id = l.budget_id
   ORDER BY l.updated_at DESC
   LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_budget_lines_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_budget_lines_recent() TO authenticated;

CREATE OR REPLACE FUNCTION founder_budget_top_variances()
RETURNS TABLE(
  id uuid,
  fiscal_year int,
  department text,
  line_item text,
  approved_rupees numeric,
  actual_spend_rupees numeric,
  variance_rupees numeric,
  variance_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, b.fiscal_year, l.department, l.line_item,
         l.approved_rupees, l.actual_spend_rupees, l.variance_rupees,
         CASE WHEN l.approved_rupees > 0 THEN ROUND((l.variance_rupees / l.approved_rupees) * 100.0, 2) ELSE 0 END
    FROM founder_annual_budget_lines l
    JOIN founder_annual_budgets b ON b.id = l.budget_id
   ORDER BY abs(l.variance_rupees) DESC NULLS LAST
   LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_budget_top_variances() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_budget_top_variances() TO authenticated;

-- =========================================================
-- WRITE RPCs (VOLATILE)
-- =========================================================

CREATE OR REPLACE FUNCTION founder_budget_create_year(p_year int, p_notes text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_annual_budgets(fiscal_year, notes)
  VALUES (p_year, p_notes)
  ON CONFLICT (fiscal_year) DO UPDATE SET notes = EXCLUDED.notes, updated_at = now()
  RETURNING id INTO v_id;
  PERFORM log_founder_budget_create(p_year, v_id);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_budget_create_year(int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_budget_create_year(int, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_budget_lock_year(p_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_year int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_annual_budgets
     SET status='locked', locked_at=now(), locked_by_email=(auth.jwt()->>'email'), updated_at=now()
   WHERE id = p_id
  RETURNING fiscal_year INTO v_year;
  PERFORM log_founder_budget_lock(p_id, v_year);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_budget_lock_year(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_budget_lock_year(uuid) TO authenticated;

COMMIT;