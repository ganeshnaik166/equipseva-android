BEGIN;
-- Round 1558 — Founder Engineer Demand-Supply Gap Analyzer
-- Per-city/per-equipment-category demand (jobs requested) vs supply (engineers available)
-- Surfaces starved markets + over-served zones + hire/transfer recommendations


-- ---------- Tables ----------

CREATE TABLE IF NOT EXISTS founder_engineer_demand_supply_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  captured_at timestamptz NOT NULL DEFAULT now(),
  window_days int NOT NULL DEFAULT 30,
  city text NOT NULL,
  state text,
  equipment_category text NOT NULL,
  demand_jobs int NOT NULL DEFAULT 0,
  unfilled_jobs int NOT NULL DEFAULT 0,
  supply_engineers int NOT NULL DEFAULT 0,
  active_engineers int NOT NULL DEFAULT 0,
  gap_score numeric(8,2) NOT NULL DEFAULT 0,
  classification text NOT NULL DEFAULT 'balanced',
  notes text,
  captured_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_feds_snap_city ON founder_engineer_demand_supply_snapshots(city);
CREATE INDEX IF NOT EXISTS idx_feds_snap_cat ON founder_engineer_demand_supply_snapshots(equipment_category);
CREATE INDEX IF NOT EXISTS idx_feds_snap_when ON founder_engineer_demand_supply_snapshots(captured_at DESC);

ALTER TABLE founder_engineer_demand_supply_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_feds_snap ON founder_engineer_demand_supply_snapshots;
CREATE POLICY founder_only_feds_snap ON founder_engineer_demand_supply_snapshots
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_engineer_hiring_recommendations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  city text NOT NULL,
  state text,
  equipment_category text NOT NULL,
  recommendation_kind text NOT NULL DEFAULT 'hire',
  headcount_delta int NOT NULL DEFAULT 1,
  urgency text NOT NULL DEFAULT 'medium',
  rationale text,
  status text NOT NULL DEFAULT 'open',
  closed_at timestamptz,
  closed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_feds_rec_status ON founder_engineer_hiring_recommendations(status);
CREATE INDEX IF NOT EXISTS idx_feds_rec_city ON founder_engineer_hiring_recommendations(city);
CREATE INDEX IF NOT EXISTS idx_feds_rec_kind ON founder_engineer_hiring_recommendations(recommendation_kind);

ALTER TABLE founder_engineer_hiring_recommendations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_feds_rec ON founder_engineer_hiring_recommendations;
CREATE POLICY founder_only_feds_rec ON founder_engineer_hiring_recommendations
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- READ RPCs ----------

CREATE OR REPLACE FUNCTION founder_eds_overview_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_cities_tracked', (SELECT count(DISTINCT city) FROM founder_engineer_demand_supply_snapshots),
    'total_categories_tracked', (SELECT count(DISTINCT equipment_category) FROM founder_engineer_demand_supply_snapshots),
    'starved_markets', (SELECT count(*) FROM founder_engineer_demand_supply_snapshots WHERE classification = 'starved' AND captured_at > now() - interval '7 days'),
    'over_served_zones', (SELECT count(*) FROM founder_engineer_demand_supply_snapshots WHERE classification = 'over_served' AND captured_at > now() - interval '7 days'),
    'balanced_zones', (SELECT count(*) FROM founder_engineer_demand_supply_snapshots WHERE classification = 'balanced' AND captured_at > now() - interval '7 days'),
    'open_hire_recs', (SELECT count(*) FROM founder_engineer_hiring_recommendations WHERE status = 'open' AND recommendation_kind = 'hire'),
    'open_transfer_recs', (SELECT count(*) FROM founder_engineer_hiring_recommendations WHERE status = 'open' AND recommendation_kind = 'transfer'),
    'open_freeze_recs', (SELECT count(*) FROM founder_engineer_hiring_recommendations WHERE status = 'open' AND recommendation_kind = 'freeze'),
    'urgent_recs', (SELECT count(*) FROM founder_engineer_hiring_recommendations WHERE status = 'open' AND urgency = 'high'),
    'closed_recs_30d', (SELECT count(*) FROM founder_engineer_hiring_recommendations WHERE status = 'closed' AND closed_at > now() - interval '30 days'),
    'jobs_last_30d', (SELECT count(*) FROM repair_jobs WHERE created_at > now() - interval '30 days'),
    'unfilled_jobs_last_30d', (SELECT count(*) FROM repair_jobs WHERE created_at > now() - interval '30 days' AND engineer_id IS NULL),
    'total_engineers', (SELECT count(*) FROM engineers),
    'engineers_with_recent_job', (SELECT count(DISTINCT e.id) FROM engineers e JOIN repair_jobs j ON j.engineer_id = e.id WHERE j.created_at > now() - interval '30 days'),
    'avg_gap_score', COALESCE((SELECT round(avg(gap_score)::numeric, 2) FROM founder_engineer_demand_supply_snapshots WHERE captured_at > now() - interval '7 days'), 0),
    'snapshots_total', (SELECT count(*) FROM founder_engineer_demand_supply_snapshots)
  ) INTO result;
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION founder_eds_recent_snapshots()
RETURNS TABLE(id uuid, captured_at timestamptz, city text, state text, equipment_category text, demand_jobs int, supply_engineers int, gap_score numeric, classification text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.captured_at, s.city, s.state, s.equipment_category,
         s.demand_jobs, s.supply_engineers, s.gap_score, s.classification
  FROM founder_engineer_demand_supply_snapshots s
  ORDER BY s.captured_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION founder_eds_starved_markets()
RETURNS TABLE(city text, equipment_category text, demand_jobs int, supply_engineers int, gap_score numeric, captured_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.city, s.equipment_category, s.demand_jobs, s.supply_engineers, s.gap_score, s.captured_at
  FROM founder_engineer_demand_supply_snapshots s
  WHERE s.classification = 'starved'
    AND s.captured_at > now() - interval '14 days'
  ORDER BY s.gap_score DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION founder_eds_over_served_zones()
RETURNS TABLE(city text, equipment_category text, demand_jobs int, supply_engineers int, gap_score numeric, captured_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.city, s.equipment_category, s.demand_jobs, s.supply_engineers, s.gap_score, s.captured_at
  FROM founder_engineer_demand_supply_snapshots s
  WHERE s.classification = 'over_served'
    AND s.captured_at > now() - interval '14 days'
  ORDER BY s.gap_score ASC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION founder_eds_open_recommendations()
RETURNS TABLE(id uuid, created_at timestamptz, city text, equipment_category text, recommendation_kind text, headcount_delta int, urgency text, rationale text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.created_at, r.city, r.equipment_category, r.recommendation_kind, r.headcount_delta, r.urgency, r.rationale
  FROM founder_engineer_hiring_recommendations r
  WHERE r.status = 'open'
  ORDER BY CASE r.urgency WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, r.created_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION founder_eds_live_demand_by_city()
RETURNS TABLE(city text, jobs_30d bigint, unfilled bigint, engineers_in_org_city bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(o.city, 'unknown') AS city,
         count(j.*) AS jobs_30d,
         count(*) FILTER (WHERE j.engineer_id IS NULL) AS unfilled,
         (SELECT count(DISTINCT e.id) FROM engineers e
            JOIN profiles p2 ON p2.id = e.user_id
            JOIN organizations o2 ON o2.id = p2.organization_id
            WHERE o2.city = o.city) AS engineers_in_org_city
  FROM repair_jobs j
  LEFT JOIN organizations o ON o.id = j.hospital_org_id
  WHERE j.created_at > now() - interval '30 days'
  GROUP BY o.city
  ORDER BY jobs_30d DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION founder_eds_closed_recommendations_30d()
RETURNS TABLE(id uuid, created_at timestamptz, closed_at timestamptz, city text, equipment_category text, recommendation_kind text, urgency text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.created_at, r.closed_at, r.city, r.equipment_category, r.recommendation_kind, r.urgency
  FROM founder_engineer_hiring_recommendations r
  WHERE r.status = 'closed'
    AND r.closed_at > now() - interval '30 days'
  ORDER BY r.closed_at DESC
  LIMIT 50;
END;
$$;

-- ---------- WRITE / LOG helpers ----------

CREATE OR REPLACE FUNCTION log_founder_eds_snapshot_captured(p_city text, p_equipment_category text, p_demand_jobs int, p_supply_engineers int, p_classification text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE new_id uuid; gap numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  gap := COALESCE(p_demand_jobs, 0) - COALESCE(p_supply_engineers, 0);
  INSERT INTO founder_engineer_demand_supply_snapshots(city, equipment_category, demand_jobs, supply_engineers, gap_score, classification, captured_by)
  VALUES (p_city, p_equipment_category, COALESCE(p_demand_jobs,0), COALESCE(p_supply_engineers,0), gap, COALESCE(p_classification, 'balanced'), auth.uid())
  RETURNING id INTO new_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'eds_snapshot_captured',
          jsonb_build_object('id', new_id, 'city', p_city, 'category', p_equipment_category, 'demand', p_demand_jobs, 'supply', p_supply_engineers, 'classification', p_classification));
  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_eds_recommendation_opened(p_city text, p_equipment_category text, p_kind text, p_delta int, p_urgency text, p_rationale text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_engineer_hiring_recommendations(city, equipment_category, recommendation_kind, headcount_delta, urgency, rationale, created_by)
  VALUES (p_city, p_equipment_category, COALESCE(p_kind, 'hire'), COALESCE(p_delta, 1), COALESCE(p_urgency, 'medium'), p_rationale, auth.uid())
  RETURNING id INTO new_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'eds_recommendation_opened',
          jsonb_build_object('id', new_id, 'city', p_city, 'category', p_equipment_category, 'kind', p_kind, 'delta', p_delta, 'urgency', p_urgency));
  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_eds_recommendation_closed(p_recommendation_id uuid, p_outcome text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_engineer_hiring_recommendations
    SET status = 'closed', closed_at = now(), closed_by = auth.uid()
    WHERE id = p_recommendation_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'eds_recommendation_closed',
          jsonb_build_object('id', p_recommendation_id, 'outcome', p_outcome));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_eds_market_marked_starved(p_city text, p_equipment_category text, p_note text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'eds_market_marked_starved',
          jsonb_build_object('city', p_city, 'category', p_equipment_category, 'note', p_note));
END;
$$;

-- ---------- Grants ----------

REVOKE EXECUTE ON FUNCTION founder_eds_overview_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eds_overview_kpis() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_eds_recent_snapshots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eds_recent_snapshots() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_eds_starved_markets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eds_starved_markets() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_eds_over_served_zones() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eds_over_served_zones() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_eds_open_recommendations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eds_open_recommendations() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_eds_live_demand_by_city() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eds_live_demand_by_city() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_eds_closed_recommendations_30d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eds_closed_recommendations_30d() TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_eds_snapshot_captured(text, text, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_eds_snapshot_captured(text, text, int, int, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_eds_recommendation_opened(text, text, text, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_eds_recommendation_opened(text, text, text, int, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_eds_recommendation_closed(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_eds_recommendation_closed(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_eds_market_marked_starved(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_eds_market_marked_starved(text, text, text) TO authenticated;

COMMIT;