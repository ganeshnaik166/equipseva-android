BEGIN;

-- =========================================================================
-- r1618 — Founder Global Expansion Heatmap
-- visualize India penetration by state + tier-1/2/3 cities,
-- expansion priorities for next 12 months, founder decision queue.
-- =========================================================================

-- ---------- TABLE 1: state/city penetration snapshot ---------------------
CREATE TABLE IF NOT EXISTS founder_expansion_market_v2 (
  id uuid primary key default gen_random_uuid(),
  state text not null,
  city text not null,
  city_tier smallint not null check (city_tier in (1,2,3)),
  region text not null check (region in ('north','south','east','west','central','northeast')),
  hospital_count_target int not null default 0,
  hospital_count_live int not null default 0,
  engineer_count_target int not null default 0,
  engineer_count_live int not null default 0,
  monthly_gmv_rupees bigint not null default 0,
  penetration_pct numeric(5,2) not null default 0,
  priority_rank smallint not null default 99,
  launch_status text not null default 'planning' check (launch_status in ('planning','active','live','paused','dropped')),
  target_launch_month date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (state, city)
);

CREATE INDEX IF NOT EXISTS founder_expansion_market_v2_state_idx ON founder_expansion_market_v2 (state);
CREATE INDEX IF NOT EXISTS founder_expansion_market_v2_tier_idx ON founder_expansion_market_v2 (city_tier);
CREATE INDEX IF NOT EXISTS founder_expansion_market_v2_rank_idx ON founder_expansion_market_v2 (priority_rank);

ALTER TABLE founder_expansion_market_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_expansion_market_v2_founder_only ON founder_expansion_market_v2;
CREATE POLICY founder_expansion_market_v2_founder_only ON founder_expansion_market_v2
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ---------- TABLE 2: founder decision queue ------------------------------
CREATE TABLE IF NOT EXISTS founder_expansion_decisions_v2 (
  id uuid primary key default gen_random_uuid(),
  state text not null,
  city text not null,
  decision_type text not null check (decision_type in ('launch','hire_engineer','partner_hospital','pause','exit','seed_capital')),
  rationale text not null,
  estimated_gmv_uplift_rupees bigint not null default 0,
  estimated_cost_rupees bigint not null default 0,
  status text not null default 'pending' check (status in ('pending','approved','rejected','executed')),
  decided_by uuid references auth.users(id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

CREATE INDEX IF NOT EXISTS founder_expansion_decisions_v2_status_idx ON founder_expansion_decisions_v2 (status);
CREATE INDEX IF NOT EXISTS founder_expansion_decisions_v2_state_idx ON founder_expansion_decisions_v2 (state);

ALTER TABLE founder_expansion_decisions_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_expansion_decisions_v2_founder_only ON founder_expansion_decisions_v2;
CREATE POLICY founder_expansion_decisions_v2_founder_only ON founder_expansion_decisions_v2
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- =========================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_expansion_market_upsert(p_state text, p_city text, p_payload jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'expansion_market_upsert',
    jsonb_build_object('state', p_state, 'city', p_city, 'payload', p_payload), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_expansion_market_upsert(text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_expansion_market_upsert(text, text, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_expansion_decision_create(p_state text, p_city text, p_decision_type text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'expansion_decision_create',
    jsonb_build_object('state', p_state, 'city', p_city, 'decision_type', p_decision_type), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_expansion_decision_create(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_expansion_decision_create(text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_expansion_decision_resolve(p_decision_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'expansion_decision_resolve',
    jsonb_build_object('decision_id', p_decision_id, 'status', p_status), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_expansion_decision_resolve(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_expansion_decision_resolve(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_expansion_heatmap_view(p_filter text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'expansion_heatmap_view',
    jsonb_build_object('filter', p_filter), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_expansion_heatmap_view(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_expansion_heatmap_view(text) TO authenticated;

-- =========================================================================
-- READ RPCs (STABLE SECDEF)
-- =========================================================================

-- 1. KPIs
CREATE OR REPLACE FUNCTION founder_expansion_kpis()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total_states int;
  v_total_cities int;
  v_t1 int; v_t2 int; v_t3 int;
  v_live_cities int;
  v_planning_cities int;
  v_paused_cities int;
  v_target_hospitals int;
  v_live_hospitals int;
  v_target_engineers int;
  v_live_engineers int;
  v_monthly_gmv bigint;
  v_avg_penetration numeric;
  v_pending_decisions int;
  v_approved_decisions int;
  v_executed_decisions int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(distinct state), count(*),
         count(*) filter (where city_tier=1),
         count(*) filter (where city_tier=2),
         count(*) filter (where city_tier=3),
         count(*) filter (where launch_status='live'),
         count(*) filter (where launch_status='planning'),
         count(*) filter (where launch_status='paused'),
         coalesce(sum(hospital_count_target),0),
         coalesce(sum(hospital_count_live),0),
         coalesce(sum(engineer_count_target),0),
         coalesce(sum(engineer_count_live),0),
         coalesce(sum(monthly_gmv_rupees),0),
         coalesce(avg(penetration_pct),0)
    INTO v_total_states, v_total_cities, v_t1, v_t2, v_t3,
         v_live_cities, v_planning_cities, v_paused_cities,
         v_target_hospitals, v_live_hospitals,
         v_target_engineers, v_live_engineers,
         v_monthly_gmv, v_avg_penetration
    FROM founder_expansion_market_v2;

  SELECT count(*) filter (where status='pending'),
         count(*) filter (where status='approved'),
         count(*) filter (where status='executed')
    INTO v_pending_decisions, v_approved_decisions, v_executed_decisions
    FROM founder_expansion_decisions_v2;

  RETURN jsonb_build_object(
    'total_states', v_total_states,
    'total_cities', v_total_cities,
    'tier_1', v_t1,
    'tier_2', v_t2,
    'tier_3', v_t3,
    'live_cities', v_live_cities,
    'planning_cities', v_planning_cities,
    'paused_cities', v_paused_cities,
    'target_hospitals', v_target_hospitals,
    'live_hospitals', v_live_hospitals,
    'target_engineers', v_target_engineers,
    'live_engineers', v_live_engineers,
    'monthly_gmv_rupees', v_monthly_gmv,
    'avg_penetration_pct', v_avg_penetration,
    'pending_decisions', v_pending_decisions,
    'approved_decisions', v_approved_decisions,
    'executed_decisions', v_executed_decisions
  );
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_kpis() TO authenticated;

-- 2. State-level heatmap
CREATE OR REPLACE FUNCTION founder_expansion_state_heatmap()
RETURNS TABLE (
  id uuid, state text, cities int, live_cities int,
  hospitals_target int, hospitals_live int,
  engineers_target int, engineers_live int,
  monthly_gmv_rupees bigint, avg_penetration_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT gen_random_uuid() AS id,
           m.state,
           count(*)::int AS cities,
           count(*) filter (where m.launch_status='live')::int AS live_cities,
           coalesce(sum(m.hospital_count_target),0)::int AS hospitals_target,
           coalesce(sum(m.hospital_count_live),0)::int AS hospitals_live,
           coalesce(sum(m.engineer_count_target),0)::int AS engineers_target,
           coalesce(sum(m.engineer_count_live),0)::int AS engineers_live,
           coalesce(sum(m.monthly_gmv_rupees),0)::bigint AS monthly_gmv_rupees,
           round(coalesce(avg(m.penetration_pct),0),2)::numeric AS avg_penetration_pct
      FROM founder_expansion_market_v2 m
     GROUP BY m.state
     ORDER BY monthly_gmv_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_state_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_state_heatmap() TO authenticated;

-- 3. City-tier breakdown
CREATE OR REPLACE FUNCTION founder_expansion_city_breakdown()
RETURNS TABLE (
  id uuid, state text, city text, city_tier smallint, region text,
  launch_status text, hospitals_live int, engineers_live int,
  monthly_gmv_rupees bigint, penetration_pct numeric, priority_rank smallint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.state, m.city, m.city_tier, m.region,
           m.launch_status,
           m.hospital_count_live AS hospitals_live,
           m.engineer_count_live AS engineers_live,
           m.monthly_gmv_rupees,
           m.penetration_pct,
           m.priority_rank
      FROM founder_expansion_market_v2 m
     ORDER BY m.priority_rank ASC, m.monthly_gmv_rupees DESC
     LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_city_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_city_breakdown() TO authenticated;

-- 4. Top expansion priorities
CREATE OR REPLACE FUNCTION founder_expansion_top_priorities()
RETURNS TABLE (
  id uuid, state text, city text, city_tier smallint,
  priority_rank smallint, target_launch_month date,
  hospitals_target int, engineers_target int, launch_status text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.state, m.city, m.city_tier,
           m.priority_rank, m.target_launch_month,
           m.hospital_count_target, m.engineer_count_target,
           m.launch_status
      FROM founder_expansion_market_v2 m
     WHERE m.launch_status in ('planning','active')
     ORDER BY m.priority_rank ASC NULLS LAST
     LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_top_priorities() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_top_priorities() TO authenticated;

-- 5. Decision queue (pending)
CREATE OR REPLACE FUNCTION founder_expansion_decision_queue()
RETURNS TABLE (
  id uuid, state text, city text, decision_type text,
  rationale text, estimated_gmv_uplift_rupees bigint,
  estimated_cost_rupees bigint, status text, created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.state, d.city, d.decision_type,
           d.rationale, d.estimated_gmv_uplift_rupees,
           d.estimated_cost_rupees, d.status, d.created_at
      FROM founder_expansion_decisions_v2 d
     WHERE d.status = 'pending'
     ORDER BY d.estimated_gmv_uplift_rupees DESC, d.created_at ASC
     LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_decision_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_decision_queue() TO authenticated;

-- 6. Region-level rollup (separate CTEs to avoid cartesian)
CREATE OR REPLACE FUNCTION founder_expansion_region_rollup()
RETURNS TABLE (
  id uuid, region text, cities int, live_cities int,
  hospitals_live int, monthly_gmv_rupees bigint, avg_penetration_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    WITH base AS (
      SELECT region,
             count(*) AS cities,
             count(*) filter (where launch_status='live') AS live_cities,
             coalesce(sum(hospital_count_live),0) AS hospitals_live,
             coalesce(sum(monthly_gmv_rupees),0) AS monthly_gmv_rupees,
             coalesce(avg(penetration_pct),0) AS avg_pen
        FROM founder_expansion_market_v2
       GROUP BY region
    )
    SELECT gen_random_uuid() AS id,
           b.region,
           b.cities::int,
           b.live_cities::int,
           b.hospitals_live::int,
           b.monthly_gmv_rupees::bigint,
           round(b.avg_pen,2)::numeric AS avg_penetration_pct
      FROM base b
     ORDER BY b.monthly_gmv_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_region_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_region_rollup() TO authenticated;

-- 7. Penetration gap (target vs live)
CREATE OR REPLACE FUNCTION founder_expansion_penetration_gap()
RETURNS TABLE (
  id uuid, state text, city text, city_tier smallint,
  hospital_gap int, engineer_gap int, gmv_potential_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.state, m.city, m.city_tier,
           greatest(m.hospital_count_target - m.hospital_count_live, 0) AS hospital_gap,
           greatest(m.engineer_count_target - m.engineer_count_live, 0) AS engineer_gap,
           m.monthly_gmv_rupees AS gmv_potential_rupees
      FROM founder_expansion_market_v2 m
     WHERE m.hospital_count_target > m.hospital_count_live
        OR m.engineer_count_target > m.engineer_count_live
     ORDER BY (m.hospital_count_target - m.hospital_count_live) DESC
     LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_penetration_gap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_penetration_gap() TO authenticated;

-- =========================================================================
-- WRITE RPC (VOLATILE)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_expansion_resolve_decision(p_decision_id uuid, p_status text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('approved','rejected','executed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE founder_expansion_decisions_v2
     SET status = p_status, decided_by = auth.uid(), decided_at = now()
   WHERE id = p_decision_id;
  PERFORM log_founder_expansion_decision_resolve(p_decision_id, p_status);
  RETURN jsonb_build_object('ok', true, 'decision_id', p_decision_id, 'status', p_status);
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_resolve_decision(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_resolve_decision(uuid, text) TO authenticated;

COMMIT;