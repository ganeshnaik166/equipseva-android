BEGIN;

-- =====================================================================
-- r1497 — Engineer Dispatch Density Heatmap
-- Per-state per-hour dispatch density (jobs assigned).
-- Identify under-capacity hours/regions; spawn overtime bonus prompts
-- for hot windows.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS founder_dispatch_density_snapshots (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  taken_at        timestamptz NOT NULL DEFAULT now(),
  window_start    timestamptz NOT NULL,
  window_end      timestamptz NOT NULL,
  state_code      text NOT NULL,
  hour_of_day     int  NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
  jobs_assigned   int  NOT NULL DEFAULT 0,
  active_engineers int NOT NULL DEFAULT 0,
  density_score   numeric(8,3) NOT NULL DEFAULT 0,
  is_hot_window   boolean NOT NULL DEFAULT false,
  is_cold_window  boolean NOT NULL DEFAULT false,
  note            text,
  created_by      uuid REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_density_snap_state_hour
  ON founder_dispatch_density_snapshots (state_code, hour_of_day, taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_density_snap_hot
  ON founder_dispatch_density_snapshots (is_hot_window, taken_at DESC)
  WHERE is_hot_window;

ALTER TABLE founder_dispatch_density_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_density_snap ON founder_dispatch_density_snapshots;
CREATE POLICY founder_only_density_snap
  ON founder_dispatch_density_snapshots
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS founder_overtime_bonus_prompts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  state_code      text NOT NULL,
  hour_of_day     int  NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
  density_score   numeric(8,3) NOT NULL,
  bonus_rupees    int  NOT NULL DEFAULT 0,
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','approved','sent','declined','expired')),
  approved_at     timestamptz,
  sent_at         timestamptz,
  payload         jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by      uuid REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_ot_bonus_status
  ON founder_overtime_bonus_prompts (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ot_bonus_state_hour
  ON founder_overtime_bonus_prompts (state_code, hour_of_day);

ALTER TABLE founder_overtime_bonus_prompts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_ot_bonus ON founder_overtime_bonus_prompts;
CREATE POLICY founder_only_ot_bonus
  ON founder_overtime_bonus_prompts
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


-- ---------------------------------------------------------------------
-- Log helpers (VOLATILE SECDEF)
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION log_founder_density_snapshot_taken(p_state text, p_hour int, p_score numeric)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.email(), 'density_snapshot_taken',
          jsonb_build_object('state', p_state, 'hour', p_hour, 'score', p_score));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_density_snapshot_taken(text,int,numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_density_snapshot_taken(text,int,numeric) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_ot_bonus_created(p_state text, p_hour int, p_rupees int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.email(), 'ot_bonus_created',
          jsonb_build_object('state', p_state, 'hour', p_hour, 'bonus_rupees', p_rupees));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_ot_bonus_created(text,int,int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_ot_bonus_created(text,int,int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_ot_bonus_status(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.email(), 'ot_bonus_status',
          jsonb_build_object('prompt_id', p_id, 'status', p_status));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_ot_bonus_status(uuid,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_ot_bonus_status(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_density_note(p_state text, p_hour int, p_note text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.email(), 'density_note',
          jsonb_build_object('state', p_state, 'hour', p_hour, 'note', p_note));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_density_note(text,int,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_density_note(text,int,text) TO authenticated;


-- ---------------------------------------------------------------------
-- Read RPCs (STABLE SECDEF)
-- ---------------------------------------------------------------------

-- 1. Per-state per-hour density grid (last 7 days)
CREATE OR REPLACE FUNCTION founder_dispatch_density_grid()
RETURNS TABLE (
  id text,
  state_code text,
  hour_of_day int,
  jobs_assigned bigint,
  density_score numeric,
  band text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT COALESCE(o.state, 'UNKNOWN') AS state_code,
           EXTRACT(hour FROM rj.created_at)::int AS hour_of_day,
           rj.id
    FROM repair_jobs rj
    LEFT JOIN organizations o ON o.id = rj.hospital_org_id
    WHERE rj.created_at >= now() - interval '7 days'
      AND rj.engineer_id IS NOT NULL
  ),
  agg AS (
    SELECT state_code, hour_of_day, COUNT(*)::bigint AS jobs_assigned
    FROM base
    GROUP BY 1,2
  ),
  maxv AS (SELECT GREATEST(MAX(jobs_assigned),1) AS m FROM agg)
  SELECT (a.state_code || '-' || a.hour_of_day) AS id,
         a.state_code,
         a.hour_of_day,
         a.jobs_assigned,
         ROUND((a.jobs_assigned::numeric / maxv.m) * 100, 2) AS density_score,
         CASE
           WHEN a.jobs_assigned::numeric / maxv.m >= 0.75 THEN 'hot'
           WHEN a.jobs_assigned::numeric / maxv.m <= 0.20 THEN 'cold'
           ELSE 'normal'
         END AS band
  FROM agg a CROSS JOIN maxv
  ORDER BY a.state_code, a.hour_of_day;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_dispatch_density_grid() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_dispatch_density_grid() TO authenticated;

-- 2. Hot windows (under-capacity)
CREATE OR REPLACE FUNCTION founder_dispatch_hot_windows()
RETURNS TABLE (
  id text,
  state_code text,
  hour_of_day int,
  jobs_assigned bigint,
  density_score numeric,
  active_engineers bigint,
  jobs_per_engineer numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT COALESCE(o.state, 'UNKNOWN') AS state_code,
           EXTRACT(hour FROM rj.created_at)::int AS hour_of_day,
           rj.id,
           rj.engineer_id
    FROM repair_jobs rj
    LEFT JOIN organizations o ON o.id = rj.hospital_org_id
    WHERE rj.created_at >= now() - interval '14 days'
      AND rj.engineer_id IS NOT NULL
  ),
  agg AS (
    SELECT state_code, hour_of_day,
           COUNT(*)::bigint AS jobs_assigned,
           COUNT(DISTINCT engineer_id)::bigint AS active_engineers
    FROM base GROUP BY 1,2
  ),
  maxv AS (SELECT GREATEST(MAX(jobs_assigned),1) AS m FROM agg)
  SELECT (a.state_code || '-' || a.hour_of_day) AS id,
         a.state_code, a.hour_of_day, a.jobs_assigned,
         ROUND((a.jobs_assigned::numeric / maxv.m) * 100, 2) AS density_score,
         a.active_engineers,
         ROUND(a.jobs_assigned::numeric / GREATEST(a.active_engineers,1), 2) AS jobs_per_engineer
  FROM agg a CROSS JOIN maxv
  WHERE a.jobs_assigned::numeric / maxv.m >= 0.75
  ORDER BY density_score DESC
  LIMIT 50;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_dispatch_hot_windows() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_dispatch_hot_windows() TO authenticated;

-- 3. Cold windows (over-capacity)
CREATE OR REPLACE FUNCTION founder_dispatch_cold_windows()
RETURNS TABLE (
  id text,
  state_code text,
  hour_of_day int,
  jobs_assigned bigint,
  density_score numeric,
  idle_engineers bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH state_engs AS (
    SELECT COALESCE(o.state,'UNKNOWN') AS state_code,
           COUNT(DISTINCT e.id) AS total_engs
    FROM engineers e
    LEFT JOIN profiles p ON p.id = e.user_id
    LEFT JOIN organizations o ON o.id = p.organization_id
    GROUP BY 1
  ),
  base AS (
    SELECT COALESCE(o.state,'UNKNOWN') AS state_code,
           EXTRACT(hour FROM rj.created_at)::int AS hour_of_day,
           rj.id,
           rj.engineer_id
    FROM repair_jobs rj
    LEFT JOIN organizations o ON o.id = rj.hospital_org_id
    WHERE rj.created_at >= now() - interval '14 days'
      AND rj.engineer_id IS NOT NULL
  ),
  agg AS (
    SELECT state_code, hour_of_day,
           COUNT(*)::bigint AS jobs_assigned,
           COUNT(DISTINCT engineer_id)::bigint AS active_engs
    FROM base GROUP BY 1,2
  ),
  maxv AS (SELECT GREATEST(MAX(jobs_assigned),1) AS m FROM agg)
  SELECT (a.state_code || '-' || a.hour_of_day) AS id,
         a.state_code, a.hour_of_day, a.jobs_assigned,
         ROUND((a.jobs_assigned::numeric / maxv.m) * 100, 2) AS density_score,
         GREATEST(COALESCE(se.total_engs,0) - a.active_engs, 0)::bigint AS idle_engineers
  FROM agg a CROSS JOIN maxv
  LEFT JOIN state_engs se ON se.state_code = a.state_code
  WHERE a.jobs_assigned::numeric / maxv.m <= 0.20
  ORDER BY density_score ASC, idle_engineers DESC
  LIMIT 50;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_dispatch_cold_windows() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_dispatch_cold_windows() TO authenticated;

-- 4. State capacity summary
CREATE OR REPLACE FUNCTION founder_dispatch_state_summary()
RETURNS TABLE (
  id text,
  state_code text,
  total_jobs bigint,
  total_engineers bigint,
  avg_jobs_per_hour numeric,
  peak_hour int,
  peak_jobs bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT COALESCE(o.state,'UNKNOWN') AS state_code,
           EXTRACT(hour FROM rj.created_at)::int AS hour_of_day,
           rj.id, rj.engineer_id
    FROM repair_jobs rj
    LEFT JOIN organizations o ON o.id = rj.hospital_org_id
    WHERE rj.created_at >= now() - interval '14 days'
      AND rj.engineer_id IS NOT NULL
  ),
  per_hour AS (
    SELECT state_code, hour_of_day, COUNT(*)::bigint AS jobs
    FROM base GROUP BY 1,2
  ),
  peaks AS (
    SELECT DISTINCT ON (state_code) state_code, hour_of_day, jobs
    FROM per_hour ORDER BY state_code, jobs DESC
  ),
  state_engs AS (
    SELECT COALESCE(o.state,'UNKNOWN') AS state_code,
           COUNT(DISTINCT e.id) AS engs
    FROM engineers e
    LEFT JOIN profiles p ON p.id = e.user_id
    LEFT JOIN organizations o ON o.id = p.organization_id
    GROUP BY 1
  )
  SELECT b.state_code AS id,
         b.state_code,
         COUNT(*)::bigint AS total_jobs,
         COALESCE(MAX(se.engs),0)::bigint AS total_engineers,
         ROUND(COUNT(*)::numeric / 24, 2) AS avg_jobs_per_hour,
         MAX(pk.hour_of_day) AS peak_hour,
         MAX(pk.jobs) AS peak_jobs
  FROM base b
  LEFT JOIN peaks pk ON pk.state_code = b.state_code
  LEFT JOIN state_engs se ON se.state_code = b.state_code
  GROUP BY b.state_code
  ORDER BY total_jobs DESC
  LIMIT 50;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_dispatch_state_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_dispatch_state_summary() TO authenticated;

-- 5. Recent snapshots
CREATE OR REPLACE FUNCTION founder_dispatch_recent_snapshots()
RETURNS TABLE (
  id uuid,
  taken_at timestamptz,
  state_code text,
  hour_of_day int,
  jobs_assigned int,
  density_score numeric,
  is_hot_window boolean,
  is_cold_window boolean,
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
  SELECT s.id, s.taken_at, s.state_code, s.hour_of_day, s.jobs_assigned,
         s.density_score, s.is_hot_window, s.is_cold_window, s.note
  FROM founder_dispatch_density_snapshots s
  ORDER BY s.taken_at DESC
  LIMIT 100;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_dispatch_recent_snapshots() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_dispatch_recent_snapshots() TO authenticated;

-- 6. Overtime bonus prompts list
CREATE OR REPLACE FUNCTION founder_dispatch_ot_bonus_prompts()
RETURNS TABLE (
  id uuid,
  created_at timestamptz,
  state_code text,
  hour_of_day int,
  density_score numeric,
  bonus_rupees int,
  status text,
  age_days numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.created_at, p.state_code, p.hour_of_day, p.density_score,
         p.bonus_rupees, p.status,
         ROUND(EXTRACT(EPOCH FROM (now() - p.created_at))/86400.0, 2) AS age_days
  FROM founder_overtime_bonus_prompts p
  ORDER BY p.created_at DESC
  LIMIT 100;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_dispatch_ot_bonus_prompts() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_dispatch_ot_bonus_prompts() TO authenticated;

-- 7. KPI rollup
CREATE OR REPLACE FUNCTION founder_dispatch_density_kpis()
RETURNS TABLE (
  total_jobs_7d bigint,
  total_jobs_24h bigint,
  hot_window_count bigint,
  cold_window_count bigint,
  states_covered bigint,
  total_engineers bigint,
  avg_density numeric,
  max_density numeric,
  bonus_prompts_pending bigint,
  bonus_prompts_sent bigint,
  bonus_rupees_committed bigint,
  snapshots_total bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH grid AS (
    SELECT COALESCE(o.state,'UNKNOWN') AS state_code,
           EXTRACT(hour FROM rj.created_at)::int AS hour_of_day,
           rj.id, rj.created_at
    FROM repair_jobs rj
    LEFT JOIN organizations o ON o.id = rj.hospital_org_id
    WHERE rj.created_at >= now() - interval '7 days'
      AND rj.engineer_id IS NOT NULL
  ),
  agg AS (
    SELECT state_code, hour_of_day, COUNT(*)::bigint AS jobs
    FROM grid GROUP BY 1,2
  ),
  maxv AS (SELECT GREATEST(MAX(jobs),1) AS m FROM agg),
  banded AS (
    SELECT a.state_code, a.hour_of_day, a.jobs,
           (a.jobs::numeric/maxv.m)*100 AS dens
    FROM agg a CROSS JOIN maxv
  )
  SELECT
    (SELECT COUNT(*)::bigint FROM grid) AS total_jobs_7d,
    (SELECT COUNT(*)::bigint FROM grid WHERE created_at >= now() - interval '24 hours') AS total_jobs_24h,
    (SELECT COUNT(*)::bigint FROM banded WHERE dens >= 75) AS hot_window_count,
    (SELECT COUNT(*)::bigint FROM banded WHERE dens <= 20) AS cold_window_count,
    (SELECT COUNT(DISTINCT state_code)::bigint FROM grid) AS states_covered,
    (SELECT COUNT(*)::bigint FROM engineers) AS total_engineers,
    (SELECT COALESCE(ROUND(AVG(dens),2),0) FROM banded) AS avg_density,
    (SELECT COALESCE(ROUND(MAX(dens),2),0) FROM banded) AS max_density,
    (SELECT COUNT(*)::bigint FROM founder_overtime_bonus_prompts WHERE status='pending') AS bonus_prompts_pending,
    (SELECT COUNT(*)::bigint FROM founder_overtime_bonus_prompts WHERE status='sent') AS bonus_prompts_sent,
    (SELECT COALESCE(SUM(bonus_rupees),0)::bigint FROM founder_overtime_bonus_prompts WHERE status IN ('approved','sent')) AS bonus_rupees_committed,
    (SELECT COUNT(*)::bigint FROM founder_dispatch_density_snapshots) AS snapshots_total;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_dispatch_density_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_dispatch_density_kpis() TO authenticated;

COMMIT;