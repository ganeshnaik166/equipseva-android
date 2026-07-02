BEGIN;

-- ============================================================
-- r1542: Founder Engineer Territory Map
-- Engineer primary city/zone ownership, per-territory metrics,
-- coverage gap analysis, founder rebalance queue
-- ============================================================

-- Engineer territory ownership assignments
CREATE TABLE IF NOT EXISTS founder_engineer_territories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  primary_city text NOT NULL,
  primary_state text NOT NULL,
  zone_label text NOT NULL,
  is_primary boolean NOT NULL DEFAULT true,
  coverage_radius_km integer NOT NULL DEFAULT 25,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  assigned_by uuid REFERENCES auth.users(id),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_founder_engineer_territories_primary
  ON founder_engineer_territories(engineer_id) WHERE is_primary = true;
CREATE INDEX IF NOT EXISTS idx_founder_engineer_territories_city
  ON founder_engineer_territories(primary_city, primary_state);
CREATE INDEX IF NOT EXISTS idx_founder_engineer_territories_zone
  ON founder_engineer_territories(zone_label);

ALTER TABLE founder_engineer_territories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_engineer_territories ON founder_engineer_territories;
CREATE POLICY founder_only_engineer_territories ON founder_engineer_territories
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- Founder rebalance queue: pending territory reassignment proposals
CREATE TABLE IF NOT EXISTS founder_territory_rebalance_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  from_city text,
  from_zone text,
  to_city text NOT NULL,
  to_zone text NOT NULL,
  to_state text NOT NULL,
  reason text NOT NULL,
  priority text NOT NULL DEFAULT 'normal',
  status text NOT NULL DEFAULT 'pending',
  proposed_at timestamptz NOT NULL DEFAULT now(),
  proposed_by uuid REFERENCES auth.users(id),
  resolved_at timestamptz,
  resolved_by uuid REFERENCES auth.users(id),
  resolution_notes text
);

CREATE INDEX IF NOT EXISTS idx_founder_territory_rebalance_queue_status
  ON founder_territory_rebalance_queue(status, proposed_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_territory_rebalance_queue_engineer
  ON founder_territory_rebalance_queue(engineer_id);

ALTER TABLE founder_territory_rebalance_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_territory_rebalance ON founder_territory_rebalance_queue;
CREATE POLICY founder_only_territory_rebalance ON founder_territory_rebalance_queue
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- log_founder_* helpers (VOLATILE SECDEF)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_territory_assignment(
  p_engineer_id uuid,
  p_city text,
  p_zone text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'territory_assigned',
    jsonb_build_object('engineer_id', p_engineer_id, 'city', p_city, 'zone', p_zone));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_territory_assignment(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_territory_assignment(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_rebalance_proposed(
  p_engineer_id uuid,
  p_to_city text,
  p_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'rebalance_proposed',
    jsonb_build_object('engineer_id', p_engineer_id, 'to_city', p_to_city, 'reason', p_reason));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_rebalance_proposed(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_rebalance_proposed(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_rebalance_resolved(
  p_rebalance_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'rebalance_resolved',
    jsonb_build_object('rebalance_id', p_rebalance_id, 'status', p_status));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_rebalance_resolved(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_rebalance_resolved(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_territory_viewed(
  p_city text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'territory_map_viewed',
    jsonb_build_object('city', p_city));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_territory_viewed(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_territory_viewed(text) TO authenticated;

-- ============================================================
-- Read RPCs (STABLE)
-- ============================================================

-- RPC 1: KPI summary
CREATE OR REPLACE FUNCTION founder_territory_map_kpis()
RETURNS TABLE (
  total_engineers integer,
  engineers_with_territory integer,
  engineers_no_territory integer,
  total_cities integer,
  total_zones integer,
  total_states integer,
  active_amc_contracts integer,
  open_jobs_30d integer,
  uncovered_cities integer,
  overstaffed_cities integer,
  pending_rebalance integer,
  approved_rebalance_7d integer,
  rejected_rebalance_7d integer,
  avg_engineers_per_city numeric,
  max_engineers_in_city integer,
  cities_single_engineer integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH terr AS (
    SELECT * FROM founder_engineer_territories WHERE is_primary = true
  ),
  city_counts AS (
    SELECT primary_city, COUNT(*)::int AS n FROM terr GROUP BY primary_city
  ),
  amc_city AS (
    SELECT o.city, COUNT(*)::int AS n
    FROM amc_contracts a
    JOIN profiles p ON p.id = a.hospital_user_id
    JOIN organizations o ON o.id = p.organization_id
    WHERE a.status = 'active'
    GROUP BY o.city
  )
  SELECT
    (SELECT COUNT(*)::int FROM engineers),
    (SELECT COUNT(DISTINCT engineer_id)::int FROM terr),
    (SELECT COUNT(*)::int FROM engineers e WHERE NOT EXISTS (SELECT 1 FROM terr t WHERE t.engineer_id = e.id)),
    (SELECT COUNT(DISTINCT primary_city)::int FROM terr),
    (SELECT COUNT(DISTINCT zone_label)::int FROM terr),
    (SELECT COUNT(DISTINCT primary_state)::int FROM terr),
    (SELECT COUNT(*)::int FROM amc_contracts WHERE status = 'active'),
    (SELECT COUNT(*)::int FROM repair_jobs WHERE created_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM amc_city ac WHERE NOT EXISTS (SELECT 1 FROM city_counts cc WHERE cc.primary_city = ac.city)),
    (SELECT COUNT(*)::int FROM city_counts WHERE n > 5),
    (SELECT COUNT(*)::int FROM founder_territory_rebalance_queue WHERE status = 'pending'),
    (SELECT COUNT(*)::int FROM founder_territory_rebalance_queue WHERE status = 'approved' AND resolved_at > now() - interval '7 days'),
    (SELECT COUNT(*)::int FROM founder_territory_rebalance_queue WHERE status = 'rejected' AND resolved_at > now() - interval '7 days'),
    COALESCE((SELECT ROUND(AVG(n)::numeric, 2) FROM city_counts), 0),
    COALESCE((SELECT MAX(n) FROM city_counts), 0),
    (SELECT COUNT(*)::int FROM city_counts WHERE n = 1);
END $$;
REVOKE EXECUTE ON FUNCTION founder_territory_map_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_territory_map_kpis() TO authenticated;

-- RPC 2: Per-territory aggregate (city-level)
CREATE OR REPLACE FUNCTION founder_territory_city_breakdown()
RETURNS TABLE (
  id text,
  city text,
  state text,
  engineer_count integer,
  amc_contracts integer,
  jobs_30d integer,
  coverage_status text,
  demand_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH terr AS (
    SELECT primary_city, primary_state, COUNT(*)::int AS n
    FROM founder_engineer_territories WHERE is_primary = true
    GROUP BY primary_city, primary_state
  ),
  amc AS (
    SELECT o.city, o.state, COUNT(*)::int AS n
    FROM amc_contracts a
    JOIN profiles p ON p.id = a.hospital_user_id
    JOIN organizations o ON o.id = p.organization_id
    WHERE a.status = 'active'
    GROUP BY o.city, o.state
  ),
  jobs AS (
    SELECT o.city, o.state, COUNT(*)::int AS n
    FROM repair_jobs rj
    JOIN organizations o ON o.id = rj.hospital_org_id
    WHERE rj.created_at > now() - interval '30 days'
    GROUP BY o.city, o.state
  ),
  all_cities AS (
    SELECT primary_city AS city, primary_state AS state FROM terr
    UNION
    SELECT city, state FROM amc WHERE city IS NOT NULL
    UNION
    SELECT city, state FROM jobs WHERE city IS NOT NULL
  )
  SELECT
    (ac.city || '|' || COALESCE(ac.state,'')) AS id,
    ac.city,
    COALESCE(ac.state, '-') AS state,
    COALESCE(t.n, 0) AS engineer_count,
    COALESCE(a.n, 0) AS amc_contracts,
    COALESCE(j.n, 0) AS jobs_30d,
    CASE
      WHEN COALESCE(t.n,0) = 0 AND (COALESCE(a.n,0) + COALESCE(j.n,0)) > 0 THEN 'gap'
      WHEN COALESCE(t.n,0) > 5 THEN 'overstaffed'
      WHEN COALESCE(t.n,0) >= 1 AND (COALESCE(a.n,0) + COALESCE(j.n,0)) > COALESCE(t.n,0) * 10 THEN 'stretched'
      ELSE 'balanced'
    END AS coverage_status,
    ROUND((COALESCE(a.n,0) * 2.0 + COALESCE(j.n,0))::numeric, 2) AS demand_score
  FROM all_cities ac
  LEFT JOIN terr t ON t.primary_city = ac.city AND t.primary_state = ac.state
  LEFT JOIN amc a ON a.city = ac.city AND a.state = ac.state
  LEFT JOIN jobs j ON j.city = ac.city AND j.state = ac.state
  ORDER BY demand_score DESC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_territory_city_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_territory_city_breakdown() TO authenticated;

-- RPC 3: Engineer territory listing
CREATE OR REPLACE FUNCTION founder_territory_engineer_assignments()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_email text,
  cached_tier text,
  primary_city text,
  primary_state text,
  zone_label text,
  coverage_radius_km integer,
  jobs_30d integer,
  assigned_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    fet.id,
    e.id,
    p.email,
    e.cached_highest_tier::text,
    fet.primary_city,
    fet.primary_state,
    fet.zone_label,
    fet.coverage_radius_km,
    (SELECT COUNT(*)::int FROM repair_jobs rj
       WHERE rj.engineer_id = e.id AND rj.created_at > now() - interval '30 days'),
    fet.assigned_at
  FROM founder_engineer_territories fet
  JOIN engineers e ON e.id = fet.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE fet.is_primary = true
  ORDER BY fet.assigned_at DESC
  LIMIT 300;
END $$;
REVOKE EXECUTE ON FUNCTION founder_territory_engineer_assignments() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_territory_engineer_assignments() TO authenticated;

-- RPC 4: Coverage gaps
CREATE OR REPLACE FUNCTION founder_territory_coverage_gaps()
RETURNS TABLE (
  id text,
  city text,
  state text,
  amc_count integer,
  jobs_30d integer,
  engineers_present integer,
  gap_severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH terr AS (
    SELECT primary_city, primary_state, COUNT(*)::int AS n
    FROM founder_engineer_territories WHERE is_primary = true
    GROUP BY primary_city, primary_state
  ),
  amc AS (
    SELECT o.city, o.state, COUNT(*)::int AS n
    FROM amc_contracts a
    JOIN profiles p ON p.id = a.hospital_user_id
    JOIN organizations o ON o.id = p.organization_id
    WHERE a.status = 'active' AND o.city IS NOT NULL
    GROUP BY o.city, o.state
  ),
  jobs AS (
    SELECT o.city, o.state, COUNT(*)::int AS n
    FROM repair_jobs rj
    JOIN organizations o ON o.id = rj.hospital_org_id
    WHERE rj.created_at > now() - interval '30 days' AND o.city IS NOT NULL
    GROUP BY o.city, o.state
  )
  SELECT
    (amc.city || '|' || COALESCE(amc.state,'')) AS id,
    amc.city,
    COALESCE(amc.state, '-'),
    amc.n,
    COALESCE(j.n, 0),
    COALESCE(t.n, 0),
    CASE
      WHEN COALESCE(t.n,0) = 0 AND amc.n >= 5 THEN 'critical'
      WHEN COALESCE(t.n,0) = 0 AND amc.n >= 1 THEN 'high'
      WHEN amc.n > COALESCE(t.n,0) * 8 THEN 'medium'
      ELSE 'low'
    END
  FROM amc
  LEFT JOIN terr t ON t.primary_city = amc.city AND t.primary_state = amc.state
  LEFT JOIN jobs j ON j.city = amc.city AND j.state = amc.state
  WHERE COALESCE(t.n,0) = 0 OR amc.n > COALESCE(t.n,0) * 5
  ORDER BY amc.n DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_territory_coverage_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_territory_coverage_gaps() TO authenticated;

-- RPC 5: Rebalance queue
CREATE OR REPLACE FUNCTION founder_territory_rebalance_pending()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_email text,
  from_city text,
  to_city text,
  to_zone text,
  reason text,
  priority text,
  status text,
  proposed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q.id, q.engineer_id, p.email,
    q.from_city, q.to_city, q.to_zone, q.reason, q.priority, q.status, q.proposed_at
  FROM founder_territory_rebalance_queue q
  JOIN engineers e ON e.id = q.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY
    CASE q.status WHEN 'pending' THEN 0 ELSE 1 END,
    CASE q.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 ELSE 2 END,
    q.proposed_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_territory_rebalance_pending() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_territory_rebalance_pending() TO authenticated;

-- RPC 6: Zone-level rollup
CREATE OR REPLACE FUNCTION founder_territory_zone_rollup()
RETURNS TABLE (
  id text,
  zone_label text,
  engineer_count integer,
  cities_covered integer,
  avg_radius_km numeric,
  states_in_zone integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    zone_label AS id,
    zone_label,
    COUNT(DISTINCT engineer_id)::int,
    COUNT(DISTINCT primary_city)::int,
    ROUND(AVG(coverage_radius_km)::numeric, 1),
    COUNT(DISTINCT primary_state)::int
  FROM founder_engineer_territories
  WHERE is_primary = true
  GROUP BY zone_label
  ORDER BY COUNT(*) DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_territory_zone_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_territory_zone_rollup() TO authenticated;

-- RPC 7: Propose rebalance (WRITE — VOLATILE)
CREATE OR REPLACE FUNCTION founder_territory_propose_rebalance(
  p_engineer_id uuid,
  p_to_city text,
  p_to_zone text,
  p_to_state text,
  p_reason text,
  p_priority text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_from_city text;
  v_from_zone text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT primary_city, zone_label INTO v_from_city, v_from_zone
  FROM founder_engineer_territories
  WHERE engineer_id = p_engineer_id AND is_primary = true
  LIMIT 1;

  INSERT INTO founder_territory_rebalance_queue
    (engineer_id, from_city, from_zone, to_city, to_zone, to_state, reason, priority, proposed_by)
  VALUES
    (p_engineer_id, v_from_city, v_from_zone, p_to_city, p_to_zone, p_to_state,
     p_reason, COALESCE(p_priority, 'normal'), auth.uid())
  RETURNING id INTO v_id;

  PERFORM log_founder_rebalance_proposed(p_engineer_id, p_to_city, p_reason);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_territory_propose_rebalance(uuid, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_territory_propose_rebalance(uuid, text, text, text, text, text) TO authenticated;

COMMIT;