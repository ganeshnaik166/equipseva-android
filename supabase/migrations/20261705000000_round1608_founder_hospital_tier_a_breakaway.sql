BEGIN;

-- =============================================================================
-- r1608 — Founder Hospital Tier-A Breakaway List
-- =============================================================================
-- Identify B-tier hospitals showing tier-A indicators (rev growth, NPS rise);
-- founder personal-attention list before competitors poach.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: breakaway candidate snapshots (one row per hospital per snapshot)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_hospital_breakaway_candidates_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  current_tier text NOT NULL CHECK (current_tier IN ('A','B','C','D')),
  candidate_tier text NOT NULL DEFAULT 'A' CHECK (candidate_tier IN ('A','B','C','D')),
  trailing_30d_revenue_rupees bigint NOT NULL DEFAULT 0,
  prior_30d_revenue_rupees bigint NOT NULL DEFAULT 0,
  revenue_growth_pct numeric(10,2) NOT NULL DEFAULT 0,
  trailing_nps numeric(5,2),
  prior_nps numeric(5,2),
  nps_delta numeric(5,2),
  job_count_30d int NOT NULL DEFAULT 0,
  active_amc_count int NOT NULL DEFAULT 0,
  breakaway_score numeric(8,2) NOT NULL DEFAULT 0,
  recommendation text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_breakaway_cand_v2_score ON founder_hospital_breakaway_candidates_v2 (breakaway_score DESC);
CREATE INDEX IF NOT EXISTS idx_breakaway_cand_v2_org ON founder_hospital_breakaway_candidates_v2 (hospital_org_id, snapshot_at DESC);

ALTER TABLE founder_hospital_breakaway_candidates_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_breakaway_cand_v2_founder_all ON founder_hospital_breakaway_candidates_v2;
CREATE POLICY p_breakaway_cand_v2_founder_all ON founder_hospital_breakaway_candidates_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------------------------------------------------------------------------
-- Table 2: founder personal-attention actions taken on candidates
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_hospital_breakaway_actions_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  action_kind text NOT NULL CHECK (action_kind IN ('founder_call','tier_upgrade_offer','custom_quote','site_visit','retention_credit','escalate')),
  notes text,
  scheduled_for timestamptz,
  completed_at timestamptz,
  outcome text,
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_breakaway_act_v2_org ON founder_hospital_breakaway_actions_v2 (hospital_org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_breakaway_act_v2_kind ON founder_hospital_breakaway_actions_v2 (action_kind, created_at DESC);

ALTER TABLE founder_hospital_breakaway_actions_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_breakaway_act_v2_founder_all ON founder_hospital_breakaway_actions_v2;
CREATE POLICY p_breakaway_act_v2_founder_all ON founder_hospital_breakaway_actions_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ===========================================================================
-- READ RPCs (STABLE)
-- ===========================================================================

-- RPC 1: KPI summary
CREATE OR REPLACE FUNCTION founder_breakaway_kpis_v2()
RETURNS TABLE (
  total_candidates int,
  high_score_candidates int,
  total_trailing_revenue_rupees bigint,
  total_prior_revenue_rupees bigint,
  avg_growth_pct numeric,
  avg_nps_delta numeric,
  candidates_with_nps_rise int,
  candidates_revenue_doubled int,
  active_amc_total int,
  actions_logged_30d int,
  founder_calls_30d int,
  upgrades_offered_30d int,
  site_visits_30d int,
  candidates_no_action int,
  oldest_pending_days int,
  newest_snapshot_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_org_id) *
    FROM founder_hospital_breakaway_candidates_v2
    ORDER BY hospital_org_id, snapshot_at DESC
  ),
  acts AS (
    SELECT
      count(*) FILTER (WHERE created_at > now() - interval '30 days') AS acts_30,
      count(*) FILTER (WHERE action_kind = 'founder_call' AND created_at > now() - interval '30 days') AS calls_30,
      count(*) FILTER (WHERE action_kind = 'tier_upgrade_offer' AND created_at > now() - interval '30 days') AS upg_30,
      count(*) FILTER (WHERE action_kind = 'site_visit' AND created_at > now() - interval '30 days') AS sv_30
    FROM founder_hospital_breakaway_actions_v2
  ),
  no_act AS (
    SELECT count(*) AS cnt
    FROM latest l
    WHERE NOT EXISTS (
      SELECT 1 FROM founder_hospital_breakaway_actions_v2 a WHERE a.hospital_org_id = l.hospital_org_id
    )
  ),
  oldest AS (
    SELECT COALESCE(MAX(EXTRACT(EPOCH FROM (now() - l.snapshot_at))/86400.0), 0)::int AS d
    FROM latest l
    WHERE NOT EXISTS (
      SELECT 1 FROM founder_hospital_breakaway_actions_v2 a WHERE a.hospital_org_id = l.hospital_org_id
    )
  )
  SELECT
    (SELECT count(*)::int FROM latest),
    (SELECT count(*)::int FROM latest WHERE breakaway_score >= 70),
    COALESCE((SELECT SUM(trailing_30d_revenue_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT SUM(prior_30d_revenue_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT AVG(revenue_growth_pct) FROM latest), 0)::numeric,
    COALESCE((SELECT AVG(nps_delta) FROM latest WHERE nps_delta IS NOT NULL), 0)::numeric,
    (SELECT count(*)::int FROM latest WHERE nps_delta > 0),
    (SELECT count(*)::int FROM latest WHERE revenue_growth_pct >= 100),
    COALESCE((SELECT SUM(active_amc_count) FROM latest), 0)::int,
    (SELECT acts_30::int FROM acts),
    (SELECT calls_30::int FROM acts),
    (SELECT upg_30::int FROM acts),
    (SELECT sv_30::int FROM acts),
    (SELECT cnt::int FROM no_act),
    (SELECT d FROM oldest),
    (SELECT MAX(snapshot_at) FROM latest);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_breakaway_kpis_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_breakaway_kpis_v2() TO authenticated;

-- RPC 2: top breakaway candidates
CREATE OR REPLACE FUNCTION founder_breakaway_top_candidates_v2(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  hospital_state text,
  current_tier text,
  trailing_30d_revenue_rupees bigint,
  prior_30d_revenue_rupees bigint,
  revenue_growth_pct numeric,
  trailing_nps numeric,
  nps_delta numeric,
  job_count_30d int,
  active_amc_count int,
  breakaway_score numeric,
  recommendation text,
  snapshot_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (c.hospital_org_id) c.*
    FROM founder_hospital_breakaway_candidates_v2 c
    ORDER BY c.hospital_org_id, c.snapshot_at DESC
  )
  SELECT
    l.id,
    l.hospital_org_id,
    o.name AS hospital_name,
    o.state AS hospital_state,
    l.current_tier,
    l.trailing_30d_revenue_rupees,
    l.prior_30d_revenue_rupees,
    l.revenue_growth_pct,
    l.trailing_nps,
    l.nps_delta,
    l.job_count_30d,
    l.active_amc_count,
    l.breakaway_score,
    l.recommendation,
    l.snapshot_at
  FROM latest l
  JOIN organizations o ON o.id = l.hospital_org_id
  ORDER BY l.breakaway_score DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_breakaway_top_candidates_v2(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_breakaway_top_candidates_v2(int) TO authenticated;

-- RPC 3: recent founder actions
CREATE OR REPLACE FUNCTION founder_breakaway_recent_actions_v2(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  action_kind text,
  notes text,
  scheduled_for timestamptz,
  completed_at timestamptz,
  outcome text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_org_id, o.name, a.action_kind, a.notes,
         a.scheduled_for, a.completed_at, a.outcome, a.created_at
  FROM founder_hospital_breakaway_actions_v2 a
  JOIN organizations o ON o.id = a.hospital_org_id
  ORDER BY a.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_breakaway_recent_actions_v2(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_breakaway_recent_actions_v2(int) TO authenticated;

-- RPC 4: candidates with no action yet (priority follow-ups)
CREATE OR REPLACE FUNCTION founder_breakaway_no_action_v2(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  hospital_state text,
  breakaway_score numeric,
  revenue_growth_pct numeric,
  days_since_snapshot int,
  snapshot_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (c.hospital_org_id) c.*
    FROM founder_hospital_breakaway_candidates_v2 c
    ORDER BY c.hospital_org_id, c.snapshot_at DESC
  )
  SELECT
    l.id,
    l.hospital_org_id,
    o.name AS hospital_name,
    o.state,
    l.breakaway_score,
    l.revenue_growth_pct,
    (EXTRACT(EPOCH FROM (now() - l.snapshot_at))/86400.0)::int AS days_since_snapshot,
    l.snapshot_at
  FROM latest l
  JOIN organizations o ON o.id = l.hospital_org_id
  WHERE NOT EXISTS (
    SELECT 1 FROM founder_hospital_breakaway_actions_v2 a WHERE a.hospital_org_id = l.hospital_org_id
  )
  ORDER BY l.breakaway_score DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_breakaway_no_action_v2(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_breakaway_no_action_v2(int) TO authenticated;

-- RPC 5: action mix by kind
CREATE OR REPLACE FUNCTION founder_breakaway_action_mix_v2()
RETURNS TABLE (
  action_kind text,
  action_count int,
  with_outcome int,
  scheduled_pending int,
  last_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.action_kind,
    count(*)::int,
    count(*) FILTER (WHERE a.outcome IS NOT NULL)::int,
    count(*) FILTER (WHERE a.scheduled_for IS NOT NULL AND a.completed_at IS NULL)::int,
    MAX(a.created_at)
  FROM founder_hospital_breakaway_actions_v2 a
  GROUP BY a.action_kind
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_breakaway_action_mix_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_breakaway_action_mix_v2() TO authenticated;

-- ===========================================================================
-- WRITE RPCs (VOLATILE)
-- ===========================================================================

-- RPC 6: recompute breakaway candidates (snapshot insert)
CREATE OR REPLACE FUNCTION founder_breakaway_recompute_v2()
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_inserted int := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH trailing_rev AS (
    SELECT rj.hospital_org_id, SUM(COALESCE(rj.contracted_amount_rupees, 0))::bigint AS rev, count(*)::int AS jobs
    FROM repair_jobs rj
    WHERE rj.hospital_org_id IS NOT NULL
      AND rj.created_at > now() - interval '30 days'
    GROUP BY rj.hospital_org_id
  ),
  prior_rev AS (
    SELECT rj.hospital_org_id, SUM(COALESCE(rj.contracted_amount_rupees, 0))::bigint AS rev
    FROM repair_jobs rj
    WHERE rj.hospital_org_id IS NOT NULL
      AND rj.created_at > now() - interval '60 days'
      AND rj.created_at <= now() - interval '30 days'
    GROUP BY rj.hospital_org_id
  ),
  trailing_nps AS (
    SELECT rj.hospital_org_id, AVG(rj.hospital_rating)::numeric(5,2) AS nps
    FROM repair_jobs rj
    WHERE rj.hospital_org_id IS NOT NULL
      AND rj.hospital_rating IS NOT NULL
      AND rj.created_at > now() - interval '30 days'
    GROUP BY rj.hospital_org_id
  ),
  prior_nps AS (
    SELECT rj.hospital_org_id, AVG(rj.hospital_rating)::numeric(5,2) AS nps
    FROM repair_jobs rj
    WHERE rj.hospital_org_id IS NOT NULL
      AND rj.hospital_rating IS NOT NULL
      AND rj.created_at > now() - interval '60 days'
      AND rj.created_at <= now() - interval '30 days'
    GROUP BY rj.hospital_org_id
  ),
  amc_counts AS (
    SELECT p.organization_id AS hospital_org_id, count(*)::int AS amc_n
    FROM amc_contracts ac
    JOIN profiles p ON p.id = ac.hospital_user_id
    WHERE p.organization_id IS NOT NULL
      AND ac.status = 'active'
    GROUP BY p.organization_id
  ),
  combined AS (
    SELECT
      o.id AS hospital_org_id,
      COALESCE(tr.rev, 0) AS t_rev,
      COALESCE(pr.rev, 0) AS p_rev,
      COALESCE(tr.jobs, 0) AS t_jobs,
      tn.nps AS t_nps,
      pn.nps AS p_nps,
      COALESCE(ac.amc_n, 0) AS amc_n
    FROM organizations o
    LEFT JOIN trailing_rev tr ON tr.hospital_org_id = o.id
    LEFT JOIN prior_rev pr ON pr.hospital_org_id = o.id
    LEFT JOIN trailing_nps tn ON tn.hospital_org_id = o.id
    LEFT JOIN prior_nps pn ON pn.hospital_org_id = o.id
    LEFT JOIN amc_counts ac ON ac.hospital_org_id = o.id
    WHERE COALESCE(tr.rev, 0) > 0 OR COALESCE(pr.rev, 0) > 0
  ),
  scored AS (
    SELECT
      hospital_org_id,
      t_rev,
      p_rev,
      t_jobs,
      t_nps,
      p_nps,
      amc_n,
      CASE
        WHEN t_rev >= 500000 THEN 'A'
        WHEN t_rev >= 150000 THEN 'B'
        WHEN t_rev >= 50000 THEN 'C'
        ELSE 'D'
      END AS cur_tier,
      CASE
        WHEN p_rev > 0 THEN ((t_rev - p_rev)::numeric / p_rev * 100)::numeric(10,2)
        WHEN t_rev > 0 THEN 100.00::numeric(10,2)
        ELSE 0.00::numeric(10,2)
      END AS growth_pct,
      CASE
        WHEN t_nps IS NOT NULL AND p_nps IS NOT NULL THEN (t_nps - p_nps)
        ELSE NULL
      END AS nps_d
    FROM combined
  ),
  candidates AS (
    SELECT
      hospital_org_id,
      cur_tier,
      t_rev,
      p_rev,
      growth_pct,
      t_nps,
      p_nps,
      nps_d,
      t_jobs,
      amc_n,
      LEAST(100, GREATEST(0,
        (LEAST(GREATEST(growth_pct, 0), 200) * 0.35) +
        (LEAST(GREATEST(COALESCE(nps_d, 0) * 10, 0), 50) * 0.25) +
        (LEAST(t_jobs, 50) * 1.0 * 0.20) +
        (LEAST(amc_n, 20) * 5.0 * 0.20)
      ))::numeric(8,2) AS score
    FROM scored
    WHERE cur_tier = 'B'
      AND (growth_pct >= 25 OR COALESCE(nps_d, 0) >= 0.5)
  ),
  ins AS (
    INSERT INTO founder_hospital_breakaway_candidates_v2 (
      hospital_org_id, snapshot_at, current_tier, candidate_tier,
      trailing_30d_revenue_rupees, prior_30d_revenue_rupees, revenue_growth_pct,
      trailing_nps, prior_nps, nps_delta, job_count_30d, active_amc_count,
      breakaway_score, recommendation
    )
    SELECT
      hospital_org_id, now(), cur_tier, 'A',
      t_rev, p_rev, growth_pct,
      t_nps, p_nps, nps_d, t_jobs, amc_n,
      score,
      CASE
        WHEN score >= 80 THEN 'IMMEDIATE founder call + tier-A pricing'
        WHEN score >= 60 THEN 'Schedule founder call within 7d'
        WHEN score >= 40 THEN 'Custom retention offer'
        ELSE 'Monitor next snapshot'
      END
    FROM candidates
    RETURNING 1
  )
  SELECT count(*)::int INTO v_inserted FROM ins;

  RETURN v_inserted;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_breakaway_recompute_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_breakaway_recompute_v2() TO authenticated;

-- RPC 7: log a founder personal-attention action
CREATE OR REPLACE FUNCTION founder_breakaway_log_action_v2(
  p_hospital_org_id uuid,
  p_action_kind text,
  p_notes text DEFAULT NULL,
  p_scheduled_for timestamptz DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_hospital_breakaway_actions_v2 (hospital_org_id, action_kind, notes, scheduled_for)
  VALUES (p_hospital_org_id, p_action_kind, p_notes, p_scheduled_for)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_breakaway_log_action_v2',
    jsonb_build_object('hospital_org_id', p_hospital_org_id, 'action_kind', p_action_kind, 'id', v_id)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_breakaway_log_action_v2(uuid, text, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_breakaway_log_action_v2(uuid, text, text, timestamptz) TO authenticated;

-- ===========================================================================
-- log_founder_* helpers (VOLATILE SECDEF)
-- ===========================================================================

CREATE OR REPLACE FUNCTION log_founder_breakaway_view_v2(p_filter text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_breakaway_view_v2', jsonb_build_object('filter', p_filter));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_breakaway_view_v2(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_breakaway_view_v2(text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_breakaway_call_made_v2(p_hospital_org_id uuid, p_outcome text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_breakaway_call_made_v2',
          jsonb_build_object('hospital_org_id', p_hospital_org_id, 'outcome', p_outcome));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_breakaway_call_made_v2(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_breakaway_call_made_v2(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_breakaway_recompute_run_v2(p_inserted int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_breakaway_recompute_run_v2', jsonb_build_object('inserted', p_inserted));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_breakaway_recompute_run_v2(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_breakaway_recompute_run_v2(int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_breakaway_export_v2(p_row_count int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_breakaway_export_v2', jsonb_build_object('row_count', p_row_count));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_breakaway_export_v2(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_breakaway_export_v2(int) TO authenticated;

COMMIT;