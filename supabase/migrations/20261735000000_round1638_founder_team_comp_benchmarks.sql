BEGIN;

-- ============================================================
-- r1638 — Founder Team Comp Benchmarks
-- Per-role compensation benchmarks vs market median,
-- per-employee delta, founder approval queue for raises.
-- ============================================================

-- 1. Tables --------------------------------------------------

CREATE TABLE IF NOT EXISTS founder_role_comp_benchmarks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_title text NOT NULL,
  level text NOT NULL,
  market_median_rupees bigint NOT NULL CHECK (market_median_rupees >= 0),
  market_p25_rupees bigint NOT NULL CHECK (market_p25_rupees >= 0),
  market_p75_rupees bigint NOT NULL CHECK (market_p75_rupees >= 0),
  source_label text,
  notes text,
  effective_from date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (role_title, level, effective_from)
);

CREATE TABLE IF NOT EXISTS founder_comp_raise_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role_title text NOT NULL,
  level text NOT NULL,
  current_rupees bigint NOT NULL CHECK (current_rupees >= 0),
  proposed_rupees bigint NOT NULL CHECK (proposed_rupees >= 0),
  justification text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
  decided_at timestamptz,
  decided_by_user_id uuid REFERENCES profiles(id),
  decision_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comp_raise_requests_status
  ON founder_comp_raise_requests(status, created_at DESC);

-- founder_action_log already exists from r482

-- 2. RLS -----------------------------------------------------

ALTER TABLE founder_role_comp_benchmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_comp_raise_requests   ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_action_log            ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_only ON founder_role_comp_benchmarks;
CREATE POLICY p_founder_only ON founder_role_comp_benchmarks
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS p_founder_only ON founder_comp_raise_requests;
CREATE POLICY p_founder_only ON founder_comp_raise_requests
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS p_founder_only ON founder_action_log;
CREATE POLICY p_founder_only ON founder_action_log
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- 3. log helper ---------------------------------------------

CREATE OR REPLACE FUNCTION log_founder_comp_action(
  p_op text,
  p_after jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, p_after);
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_comp_action(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_comp_action(text, jsonb) TO authenticated;

-- 4. RPCs ----------------------------------------------------

-- 4.1 list benchmarks (STABLE)
CREATE OR REPLACE FUNCTION founder_team_comp_benchmarks_list()
RETURNS TABLE (
  id uuid,
  role_title text,
  level text,
  market_median_rupees bigint,
  market_p25_rupees bigint,
  market_p75_rupees bigint,
  source_label text,
  effective_from date,
  employees_in_role int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.role_title, b.level,
         b.market_median_rupees, b.market_p25_rupees, b.market_p75_rupees,
         b.source_label, b.effective_from,
         (SELECT COUNT(*)::int FROM profiles p
           WHERE p.role_title = b.role_title AND p.level = b.level) AS employees_in_role
  FROM founder_role_comp_benchmarks b
  ORDER BY b.role_title, b.level;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_team_comp_benchmarks_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_comp_benchmarks_list() TO authenticated;

-- 4.2 per-employee delta vs market (STABLE)
CREATE OR REPLACE FUNCTION founder_team_comp_employee_deltas()
RETURNS TABLE (
  employee_user_id uuid,
  employee_email text,
  role_title text,
  level text,
  current_rupees bigint,
  market_median_rupees bigint,
  delta_rupees bigint,
  delta_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT p.id AS employee_user_id,
         p.email AS employee_email,
         p.role_title,
         p.level,
         COALESCE(p.annual_comp_rupees, 0)::bigint AS current_rupees,
         COALESCE(b.market_median_rupees, 0)::bigint AS market_median_rupees,
         (COALESCE(p.annual_comp_rupees, 0) - COALESCE(b.market_median_rupees, 0))::bigint AS delta_rupees,
         CASE WHEN COALESCE(b.market_median_rupees, 0) = 0 THEN NULL
              ELSE ROUND(((p.annual_comp_rupees - b.market_median_rupees)::numeric
                           / b.market_median_rupees) * 100, 1)
         END AS delta_pct
  FROM profiles p
  LEFT JOIN founder_role_comp_benchmarks b
    ON b.role_title = p.role_title AND b.level = p.level
  WHERE p.role_title IS NOT NULL
  ORDER BY delta_pct NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_team_comp_employee_deltas() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_comp_employee_deltas() TO authenticated;

-- 4.3 raise queue (STABLE)
CREATE OR REPLACE FUNCTION founder_team_comp_raise_queue()
RETURNS TABLE (
  id uuid,
  employee_user_id uuid,
  employee_email text,
  role_title text,
  level text,
  current_rupees bigint,
  proposed_rupees bigint,
  raise_pct numeric,
  justification text,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.employee_user_id,
         p.email AS employee_email,
         r.role_title, r.level,
         r.current_rupees, r.proposed_rupees,
         CASE WHEN r.current_rupees = 0 THEN NULL
              ELSE ROUND(((r.proposed_rupees - r.current_rupees)::numeric
                           / r.current_rupees) * 100, 1)
         END AS raise_pct,
         r.justification, r.status, r.created_at
  FROM founder_comp_raise_requests r
  LEFT JOIN profiles p ON p.id = r.employee_user_id
  ORDER BY (r.status = 'pending') DESC, r.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_team_comp_raise_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_comp_raise_queue() TO authenticated;

-- 4.4 summary (STABLE)
CREATE OR REPLACE FUNCTION founder_team_comp_summary()
RETURNS TABLE (
  total_employees bigint,
  total_roles bigint,
  pending_raises bigint,
  under_market_count bigint,
  over_market_count bigint,
  total_annual_comp_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH deltas AS (
    SELECT p.id, p.annual_comp_rupees, b.market_median_rupees
    FROM profiles p
    LEFT JOIN founder_role_comp_benchmarks b
      ON b.role_title = p.role_title AND b.level = p.level
    WHERE p.role_title IS NOT NULL
  )
  SELECT
    (SELECT COUNT(*) FROM deltas),
    (SELECT COUNT(*) FROM founder_role_comp_benchmarks),
    (SELECT COUNT(*) FROM founder_comp_raise_requests WHERE status = 'pending'),
    (SELECT COUNT(*) FROM deltas WHERE annual_comp_rupees < market_median_rupees),
    (SELECT COUNT(*) FROM deltas WHERE annual_comp_rupees > market_median_rupees),
    (SELECT COALESCE(SUM(annual_comp_rupees), 0)::bigint FROM deltas);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_team_comp_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_comp_summary() TO authenticated;

-- 4.5 upsert benchmark (VOLATILE write)
CREATE OR REPLACE FUNCTION founder_team_comp_upsert_benchmark(
  p_role_title text,
  p_level text,
  p_median bigint,
  p_p25 bigint,
  p_p75 bigint,
  p_source text
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_role_comp_benchmarks
    (role_title, level, market_median_rupees, market_p25_rupees, market_p75_rupees, source_label)
  VALUES (p_role_title, p_level, p_median, p_p25, p_p75, p_source)
  ON CONFLICT (role_title, level, effective_from) DO UPDATE
    SET market_median_rupees = EXCLUDED.market_median_rupees,
        market_p25_rupees    = EXCLUDED.market_p25_rupees,
        market_p75_rupees    = EXCLUDED.market_p75_rupees,
        source_label         = EXCLUDED.source_label
  RETURNING id INTO v_id;

  PERFORM log_founder_comp_action('upsert_benchmark',
    jsonb_build_object('id', v_id, 'role', p_role_title, 'level', p_level, 'median', p_median));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_team_comp_upsert_benchmark(text, text, bigint, bigint, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_comp_upsert_benchmark(text, text, bigint, bigint, bigint, text) TO authenticated;

-- 4.6 submit raise request (VOLATILE write)
CREATE OR REPLACE FUNCTION founder_team_comp_submit_raise(
  p_employee_user_id uuid,
  p_proposed_rupees bigint,
  p_justification text
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_role text;
  v_level text;
  v_current bigint;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT p.role_title, p.level, COALESCE(p.annual_comp_rupees, 0)
    INTO v_role, v_level, v_current
  FROM profiles p WHERE p.id = p_employee_user_id;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'employee not found';
  END IF;

  INSERT INTO founder_comp_raise_requests
    (employee_user_id, role_title, level, current_rupees, proposed_rupees, justification)
  VALUES (p_employee_user_id, v_role, v_level, v_current, p_proposed_rupees, p_justification)
  RETURNING id INTO v_id;

  PERFORM log_founder_comp_action('submit_raise',
    jsonb_build_object('id', v_id, 'employee', p_employee_user_id, 'proposed', p_proposed_rupees));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_team_comp_submit_raise(uuid, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_comp_submit_raise(uuid, bigint, text) TO authenticated;

-- 4.7 decide raise (VOLATILE write)
CREATE OR REPLACE FUNCTION founder_team_comp_decide_raise(
  p_request_id uuid,
  p_decision text,
  p_note text
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_decision NOT IN ('approved','rejected') THEN
    RAISE EXCEPTION 'invalid decision';
  END IF;

  UPDATE founder_comp_raise_requests
     SET status = p_decision,
         decided_at = now(),
         decided_by_user_id = auth.uid(),
         decision_note = p_note
   WHERE id = p_request_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'request not found or already decided';
  END IF;

  PERFORM log_founder_comp_action('decide_raise',
    jsonb_build_object('id', p_request_id, 'decision', p_decision));
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_team_comp_decide_raise(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_comp_decide_raise(uuid, text, text) TO authenticated;

COMMIT;