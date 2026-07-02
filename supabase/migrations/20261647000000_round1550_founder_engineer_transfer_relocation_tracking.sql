BEGIN;

-- =========================================================
-- r1550 — Founder Engineer Transfer / Relocation Tracking
-- Engineers request city transfers; founder reviews queue;
-- impact on territory coverage tracked.
-- =========================================================

CREATE TABLE IF NOT EXISTS engineer_transfer_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id),
  from_city text NOT NULL,
  to_city text NOT NULL,
  from_state text,
  to_state text,
  reason text NOT NULL,
  reason_category text NOT NULL DEFAULT 'personal'
    CHECK (reason_category IN ('personal','family','medical','career','spouse_relocation','education','other')),
  desired_effective_date date,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','under_review','approved','rejected','withdrawn','completed')),
  founder_notes text,
  reviewed_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz,
  approved_effective_date date,
  coverage_risk_score int CHECK (coverage_risk_score BETWEEN 0 AND 100),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_etr_status ON engineer_transfer_requests(status);
CREATE INDEX IF NOT EXISTS idx_etr_engineer ON engineer_transfer_requests(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_etr_from_city ON engineer_transfer_requests(from_city);
CREATE INDEX IF NOT EXISTS idx_etr_to_city ON engineer_transfer_requests(to_city);
CREATE INDEX IF NOT EXISTS idx_etr_created ON engineer_transfer_requests(created_at DESC);

ALTER TABLE engineer_transfer_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS etr_founder_all ON engineer_transfer_requests;
CREATE POLICY etr_founder_all ON engineer_transfer_requests
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_transfer_coverage_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES engineer_transfer_requests(id) ON DELETE CASCADE,
  city text NOT NULL,
  engineers_before int NOT NULL DEFAULT 0,
  engineers_after int NOT NULL DEFAULT 0,
  active_jobs_in_city int NOT NULL DEFAULT 0,
  active_amc_in_city int NOT NULL DEFAULT 0,
  captured_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_etcs_request ON engineer_transfer_coverage_snapshots(request_id);
CREATE INDEX IF NOT EXISTS idx_etcs_city ON engineer_transfer_coverage_snapshots(city);

ALTER TABLE engineer_transfer_coverage_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS etcs_founder_all ON engineer_transfer_coverage_snapshots;
CREATE POLICY etcs_founder_all ON engineer_transfer_coverage_snapshots
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =========================================================
-- Helpers (VOLATILE SECDEF, founder-gated)
-- =========================================================

CREATE OR REPLACE FUNCTION log_founder_transfer_review(p_request_id uuid, p_decision text, p_notes text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'transfer_review',
          jsonb_build_object('request_id', p_request_id, 'decision', p_decision, 'notes', p_notes));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_transfer_review(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_transfer_review(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_transfer_snapshot(p_request_id uuid, p_city text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'transfer_coverage_snapshot',
          jsonb_build_object('request_id', p_request_id, 'city', p_city));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_transfer_snapshot(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_transfer_snapshot(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_transfer_bulk_review(p_count int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'transfer_bulk_review',
          jsonb_build_object('count', p_count));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_transfer_bulk_review(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_transfer_bulk_review(int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_transfer_view(p_view_name text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'transfer_view',
          jsonb_build_object('view', p_view_name));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_transfer_view(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_transfer_view(text) TO authenticated;

-- =========================================================
-- 7 SECDEF RPCs
-- =========================================================

-- RPC 1: STABLE — pending review queue
CREATE OR REPLACE FUNCTION founder_transfer_pending_queue()
RETURNS TABLE(
  request_id uuid,
  engineer_email text,
  from_city text,
  to_city text,
  reason_category text,
  desired_effective_date date,
  days_waiting numeric,
  coverage_risk_score int,
  status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT etr.id,
         u.email::text,
         etr.from_city,
         etr.to_city,
         etr.reason_category,
         etr.desired_effective_date,
         ROUND(EXTRACT(EPOCH FROM (now() - etr.created_at))/86400.0, 1)::numeric,
         etr.coverage_risk_score,
         etr.status
  FROM engineer_transfer_requests etr
  LEFT JOIN auth.users u ON u.id = etr.engineer_user_id
  WHERE etr.status IN ('pending','under_review')
  ORDER BY etr.created_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_transfer_pending_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_pending_queue() TO authenticated;

-- RPC 2: STABLE — city coverage impact
CREATE OR REPLACE FUNCTION founder_transfer_city_coverage_impact()
RETURNS TABLE(
  city text,
  current_engineers int,
  outbound_pending int,
  inbound_pending int,
  net_change int,
  active_jobs int,
  risk_label text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH cities AS (
    SELECT DISTINCT o.city AS city
    FROM engineers e
    JOIN profiles p ON p.id = e.user_id
    JOIN organizations o ON o.id = p.organization_id
    WHERE o.city IS NOT NULL
  ),
  cur AS (
    SELECT o.city, COUNT(*)::int AS n
    FROM engineers e
    JOIN profiles p ON p.id = e.user_id
    JOIN organizations o ON o.id = p.organization_id
    GROUP BY o.city
  ),
  out_p AS (
    SELECT from_city AS city, COUNT(*)::int AS n
    FROM engineer_transfer_requests
    WHERE status IN ('pending','under_review')
    GROUP BY from_city
  ),
  in_p AS (
    SELECT to_city AS city, COUNT(*)::int AS n
    FROM engineer_transfer_requests
    WHERE status IN ('pending','under_review')
    GROUP BY to_city
  ),
  jobs AS (
    SELECT o.city, COUNT(*)::int AS n
    FROM repair_jobs rj
    JOIN organizations o ON o.id = rj.hospital_org_id
    WHERE rj.status NOT IN ('completed','cancelled')
    GROUP BY o.city
  )
  SELECT c.city,
         COALESCE(cur.n,0),
         COALESCE(out_p.n,0),
         COALESCE(in_p.n,0),
         (COALESCE(in_p.n,0) - COALESCE(out_p.n,0))::int,
         COALESCE(jobs.n,0),
         CASE
           WHEN COALESCE(cur.n,0) - COALESCE(out_p.n,0) <= 0 THEN 'critical'
           WHEN COALESCE(cur.n,0) - COALESCE(out_p.n,0) <= 1 THEN 'high'
           WHEN COALESCE(out_p.n,0) > 0 THEN 'medium'
           ELSE 'low'
         END::text
  FROM cities c
  LEFT JOIN cur ON cur.city = c.city
  LEFT JOIN out_p ON out_p.city = c.city
  LEFT JOIN in_p ON in_p.city = c.city
  LEFT JOIN jobs ON jobs.city = c.city
  ORDER BY c.city;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_transfer_city_coverage_impact() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_city_coverage_impact() TO authenticated;

-- RPC 3: STABLE — reason breakdown
CREATE OR REPLACE FUNCTION founder_transfer_reason_breakdown()
RETURNS TABLE(
  reason_category text,
  total int,
  approved int,
  rejected int,
  pending int,
  approval_rate_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT etr.reason_category,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE etr.status = 'approved')::int,
         COUNT(*) FILTER (WHERE etr.status = 'rejected')::int,
         COUNT(*) FILTER (WHERE etr.status IN ('pending','under_review'))::int,
         ROUND(
           100.0 * COUNT(*) FILTER (WHERE etr.status = 'approved')::numeric
           / NULLIF(COUNT(*) FILTER (WHERE etr.status IN ('approved','rejected')),0),
           1)
  FROM engineer_transfer_requests etr
  GROUP BY etr.reason_category
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_transfer_reason_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_reason_breakdown() TO authenticated;

-- RPC 4: STABLE — recent decisions
CREATE OR REPLACE FUNCTION founder_transfer_recent_decisions()
RETURNS TABLE(
  request_id uuid,
  engineer_email text,
  from_city text,
  to_city text,
  decision text,
  reviewed_at timestamptz,
  days_to_decision numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT etr.id,
         u.email::text,
         etr.from_city,
         etr.to_city,
         etr.status,
         etr.reviewed_at,
         ROUND(EXTRACT(EPOCH FROM (etr.reviewed_at - etr.created_at))/86400.0, 1)::numeric
  FROM engineer_transfer_requests etr
  LEFT JOIN auth.users u ON u.id = etr.engineer_user_id
  WHERE etr.reviewed_at IS NOT NULL
  ORDER BY etr.reviewed_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_transfer_recent_decisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_recent_decisions() TO authenticated;

-- RPC 5: STABLE — kpis
CREATE OR REPLACE FUNCTION founder_transfer_kpis()
RETURNS TABLE(
  total_requests int,
  pending_count int,
  under_review_count int,
  approved_count int,
  rejected_count int,
  withdrawn_count int,
  completed_count int,
  avg_days_to_decision numeric,
  avg_days_waiting numeric,
  cities_at_risk int,
  top_outbound_city text,
  top_inbound_city text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_top_out text;
  v_top_in text;
  v_risk int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT from_city INTO v_top_out
  FROM engineer_transfer_requests
  WHERE status IN ('pending','under_review')
  GROUP BY from_city
  ORDER BY COUNT(*) DESC LIMIT 1;

  SELECT to_city INTO v_top_in
  FROM engineer_transfer_requests
  WHERE status IN ('pending','under_review')
  GROUP BY to_city
  ORDER BY COUNT(*) DESC LIMIT 1;

  WITH cur AS (
    SELECT o.city, COUNT(*)::int AS n
    FROM engineers e
    JOIN profiles p ON p.id = e.user_id
    JOIN organizations o ON o.id = p.organization_id
    GROUP BY o.city
  ),
  out_p AS (
    SELECT from_city AS city, COUNT(*)::int AS n
    FROM engineer_transfer_requests
    WHERE status IN ('pending','under_review')
    GROUP BY from_city
  )
  SELECT COUNT(*)::int INTO v_risk
  FROM cur LEFT JOIN out_p ON out_p.city = cur.city
  WHERE COALESCE(cur.n,0) - COALESCE(out_p.n,0) <= 1;

  RETURN QUERY
  SELECT COUNT(*)::int,
         COUNT(*) FILTER (WHERE status = 'pending')::int,
         COUNT(*) FILTER (WHERE status = 'under_review')::int,
         COUNT(*) FILTER (WHERE status = 'approved')::int,
         COUNT(*) FILTER (WHERE status = 'rejected')::int,
         COUNT(*) FILTER (WHERE status = 'withdrawn')::int,
         COUNT(*) FILTER (WHERE status = 'completed')::int,
         ROUND(AVG(EXTRACT(EPOCH FROM (reviewed_at - created_at))/86400.0) FILTER (WHERE reviewed_at IS NOT NULL)::numeric, 1),
         ROUND(AVG(EXTRACT(EPOCH FROM (now() - created_at))/86400.0) FILTER (WHERE status IN ('pending','under_review'))::numeric, 1),
         COALESCE(v_risk,0),
         COALESCE(v_top_out,'—'),
         COALESCE(v_top_in,'—')
  FROM engineer_transfer_requests;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_transfer_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_kpis() TO authenticated;

-- RPC 6: VOLATILE — approve / reject
CREATE OR REPLACE FUNCTION founder_transfer_review_request(
  p_request_id uuid,
  p_decision text,
  p_notes text,
  p_effective_date date
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_decision NOT IN ('approved','rejected','under_review') THEN
    RAISE EXCEPTION 'invalid decision';
  END IF;

  UPDATE engineer_transfer_requests
  SET status = p_decision,
      founder_notes = COALESCE(p_notes, founder_notes),
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      approved_effective_date = CASE WHEN p_decision = 'approved' THEN p_effective_date ELSE approved_effective_date END,
      updated_at = now()
  WHERE id = p_request_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'transfer_review_request',
          jsonb_build_object('request_id', p_request_id, 'decision', p_decision));
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_transfer_review_request(uuid, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_review_request(uuid, text, text, date) TO authenticated;

-- RPC 7: VOLATILE — capture coverage snapshot for a request
CREATE OR REPLACE FUNCTION founder_transfer_capture_coverage(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from text;
  v_to text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT from_city, to_city INTO v_from, v_to
  FROM engineer_transfer_requests WHERE id = p_request_id;

  IF v_from IS NULL THEN RAISE EXCEPTION 'request not found'; END IF;

  INSERT INTO engineer_transfer_coverage_snapshots(request_id, city, engineers_before, engineers_after, active_jobs_in_city, active_amc_in_city)
  SELECT p_request_id, v_from,
         COALESCE((SELECT COUNT(*) FROM engineers e JOIN profiles p ON p.id = e.user_id JOIN organizations o ON o.id = p.organization_id WHERE o.city = v_from),0),
         GREATEST(COALESCE((SELECT COUNT(*) FROM engineers e JOIN profiles p ON p.id = e.user_id JOIN organizations o ON o.id = p.organization_id WHERE o.city = v_from),0) - 1, 0),
         COALESCE((SELECT COUNT(*) FROM repair_jobs rj JOIN organizations o ON o.id = rj.hospital_org_id WHERE o.city = v_from AND rj.status NOT IN ('completed','cancelled')),0),
         COALESCE((SELECT COUNT(*) FROM amc_contracts ac JOIN profiles p ON p.id = ac.user_id JOIN organizations o ON o.id = p.organization_id WHERE o.city = v_from AND ac.status = 'active'),0);

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'transfer_capture_coverage',
          jsonb_build_object('request_id', p_request_id));
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_transfer_capture_coverage(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_capture_coverage(uuid) TO authenticated;

COMMIT;