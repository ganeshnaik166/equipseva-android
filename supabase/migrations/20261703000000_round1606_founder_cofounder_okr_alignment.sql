BEGIN;
-- Round 1606 — Founder Cofounder OKR Alignment
-- HEAVY founder console feature: per-cofounder OKR sets, dependency graph, weekly sync log.

-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_cofounder_okrs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cofounder_user_id uuid NOT NULL,
  cofounder_name text NOT NULL,
  cofounder_role text NOT NULL,
  quarter text NOT NULL,
  objective text NOT NULL,
  key_result text NOT NULL,
  target_value numeric(14,2) NOT NULL DEFAULT 0,
  current_value numeric(14,2) NOT NULL DEFAULT 0,
  unit text NOT NULL DEFAULT 'count',
  status text NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','at_risk','off_track','done')),
  weight_pct numeric(5,2) NOT NULL DEFAULT 25.0,
  depends_on_okr_id uuid REFERENCES founder_cofounder_okrs(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_cofounder_okrs_quarter ON founder_cofounder_okrs(quarter);
CREATE INDEX IF NOT EXISTS idx_founder_cofounder_okrs_cofounder ON founder_cofounder_okrs(cofounder_user_id);
CREATE INDEX IF NOT EXISTS idx_founder_cofounder_okrs_status ON founder_cofounder_okrs(status);
CREATE INDEX IF NOT EXISTS idx_founder_cofounder_okrs_dep ON founder_cofounder_okrs(depends_on_okr_id);

ALTER TABLE founder_cofounder_okrs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_cofounder_okrs ON founder_cofounder_okrs;
CREATE POLICY founder_only_cofounder_okrs ON founder_cofounder_okrs
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_cofounder_sync_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sync_date date NOT NULL,
  week_label text NOT NULL,
  attendees text[] NOT NULL DEFAULT ARRAY[]::text[],
  topics_discussed text NOT NULL,
  decisions text,
  action_items text,
  blockers text,
  health_score smallint NOT NULL DEFAULT 5 CHECK (health_score BETWEEN 1 AND 10),
  next_sync_date date,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_cofounder_sync_log_date ON founder_cofounder_sync_log(sync_date DESC);

ALTER TABLE founder_cofounder_sync_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_cofounder_sync ON founder_cofounder_sync_log;
CREATE POLICY founder_only_cofounder_sync ON founder_cofounder_sync_log
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- Read RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_cofounder_okr_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH okr AS (
    SELECT
      COUNT(*)::int AS total_okrs,
      COUNT(DISTINCT cofounder_user_id)::int AS cofounder_count,
      COUNT(*) FILTER (WHERE status='on_track')::int AS on_track,
      COUNT(*) FILTER (WHERE status='at_risk')::int AS at_risk,
      COUNT(*) FILTER (WHERE status='off_track')::int AS off_track,
      COUNT(*) FILTER (WHERE status='done')::int AS done_count,
      COUNT(*) FILTER (WHERE depends_on_okr_id IS NOT NULL)::int AS with_deps,
      COALESCE(AVG(CASE WHEN target_value > 0 THEN LEAST(100, current_value/target_value*100) ELSE 0 END), 0)::numeric(6,2) AS avg_progress,
      COUNT(DISTINCT quarter)::int AS quarters_tracked
    FROM founder_cofounder_okrs
  ),
  sync AS (
    SELECT
      COUNT(*)::int AS sync_count,
      COALESCE(AVG(health_score),0)::numeric(4,2) AS avg_health,
      MAX(sync_date) AS last_sync,
      COUNT(*) FILTER (WHERE sync_date >= CURRENT_DATE - INTERVAL '30 days')::int AS syncs_30d,
      COUNT(*) FILTER (WHERE health_score <= 4)::int AS low_health_syncs
    FROM founder_cofounder_sync_log
  )
  SELECT jsonb_build_object(
    'total_okrs', okr.total_okrs,
    'cofounder_count', okr.cofounder_count,
    'on_track', okr.on_track,
    'at_risk', okr.at_risk,
    'off_track', okr.off_track,
    'done_count', okr.done_count,
    'with_deps', okr.with_deps,
    'avg_progress_pct', okr.avg_progress,
    'quarters_tracked', okr.quarters_tracked,
    'sync_count', sync.sync_count,
    'avg_health', sync.avg_health,
    'last_sync', sync.last_sync,
    'syncs_30d', sync.syncs_30d,
    'low_health_syncs', sync.low_health_syncs,
    'alignment_score', CASE WHEN okr.total_okrs > 0 THEN ROUND((okr.on_track + okr.done_count)::numeric / okr.total_okrs * 100, 1) ELSE 0 END,
    'dep_density_pct', CASE WHEN okr.total_okrs > 0 THEN ROUND(okr.with_deps::numeric / okr.total_okrs * 100, 1) ELSE 0 END
  ) INTO result FROM okr, sync;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION founder_cofounder_okr_list()
RETURNS TABLE(id uuid, cofounder_name text, cofounder_role text, quarter text, objective text, key_result text, target_value numeric, current_value numeric, unit text, status text, weight_pct numeric, progress_pct numeric, depends_on uuid, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.cofounder_name, o.cofounder_role, o.quarter, o.objective, o.key_result,
         o.target_value, o.current_value, o.unit, o.status, o.weight_pct,
         CASE WHEN o.target_value > 0 THEN ROUND(LEAST(100, o.current_value/o.target_value*100), 2) ELSE 0 END,
         o.depends_on_okr_id, o.created_at
  FROM founder_cofounder_okrs o
  ORDER BY o.quarter DESC, o.cofounder_name, o.weight_pct DESC;
END $$;

CREATE OR REPLACE FUNCTION founder_cofounder_per_cofounder_rollup()
RETURNS TABLE(id uuid, cofounder_name text, cofounder_role text, okr_count bigint, on_track bigint, at_risk bigint, off_track bigint, done_count bigint, avg_progress numeric, total_weight numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT gen_random_uuid(), o.cofounder_name, o.cofounder_role,
         COUNT(*) AS okr_count,
         COUNT(*) FILTER (WHERE o.status='on_track'),
         COUNT(*) FILTER (WHERE o.status='at_risk'),
         COUNT(*) FILTER (WHERE o.status='off_track'),
         COUNT(*) FILTER (WHERE o.status='done'),
         COALESCE(AVG(CASE WHEN o.target_value > 0 THEN LEAST(100, o.current_value/o.target_value*100) ELSE 0 END), 0)::numeric(6,2),
         COALESCE(SUM(o.weight_pct), 0)::numeric(8,2)
  FROM founder_cofounder_okrs o
  GROUP BY o.cofounder_name, o.cofounder_role
  ORDER BY okr_count DESC;
END $$;

CREATE OR REPLACE FUNCTION founder_cofounder_dependency_graph()
RETURNS TABLE(id uuid, dependent_name text, dependent_okr text, parent_name text, parent_okr text, parent_status text, risk_flag text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT child.id, child.cofounder_name, child.objective,
         parent.cofounder_name, parent.objective, parent.status,
         CASE
           WHEN parent.status IN ('off_track','at_risk') THEN 'blocked_upstream'
           WHEN child.cofounder_user_id = parent.cofounder_user_id THEN 'self_dep'
           ELSE 'ok'
         END
  FROM founder_cofounder_okrs child
  JOIN founder_cofounder_okrs parent ON parent.id = child.depends_on_okr_id
  ORDER BY child.created_at DESC;
END $$;

CREATE OR REPLACE FUNCTION founder_cofounder_sync_recent()
RETURNS TABLE(id uuid, sync_date date, week_label text, attendee_count int, health_score smallint, topics_preview text, blockers_preview text, next_sync_date date, days_since int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.sync_date, s.week_label,
         COALESCE(array_length(s.attendees, 1), 0),
         s.health_score,
         LEFT(s.topics_discussed, 140),
         LEFT(COALESCE(s.blockers, '—'), 140),
         s.next_sync_date,
         (CURRENT_DATE - s.sync_date)::int
  FROM founder_cofounder_sync_log s
  ORDER BY s.sync_date DESC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION founder_cofounder_quarter_breakdown()
RETURNS TABLE(id uuid, quarter text, okr_count bigint, avg_progress numeric, on_track bigint, off_track bigint, done_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT gen_random_uuid(), o.quarter, COUNT(*),
         COALESCE(AVG(CASE WHEN o.target_value > 0 THEN LEAST(100, o.current_value/o.target_value*100) ELSE 0 END), 0)::numeric(6,2),
         COUNT(*) FILTER (WHERE o.status='on_track'),
         COUNT(*) FILTER (WHERE o.status='off_track'),
         COUNT(*) FILTER (WHERE o.status='done')
  FROM founder_cofounder_okrs o
  GROUP BY o.quarter
  ORDER BY o.quarter DESC;
END $$;

CREATE OR REPLACE FUNCTION founder_cofounder_misalignment_signals()
RETURNS TABLE(id uuid, signal_kind text, severity text, detail text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT gen_random_uuid(), 'sync_overdue'::text, 'high'::text,
         ('Last sync ' || (CURRENT_DATE - MAX(s.sync_date))::text || ' days ago')::text
  FROM founder_cofounder_sync_log s
  HAVING COALESCE(MAX(s.sync_date), CURRENT_DATE - 30) < CURRENT_DATE - INTERVAL '14 days'
  UNION ALL
  SELECT gen_random_uuid(), 'weight_imbalance'::text, 'medium'::text,
         (r.cofounder_name || ' carries ' || r.total_weight::text || '% weight')
  FROM (
    SELECT o.cofounder_name, SUM(o.weight_pct) AS total_weight
    FROM founder_cofounder_okrs o
    GROUP BY o.cofounder_name
  ) r
  WHERE r.total_weight > 150 OR r.total_weight < 25
  UNION ALL
  SELECT gen_random_uuid(), 'low_health'::text, 'high'::text,
         ('Sync on ' || s.sync_date::text || ' scored ' || s.health_score::text || '/10')
  FROM founder_cofounder_sync_log s
  WHERE s.health_score <= 4 AND s.sync_date >= CURRENT_DATE - INTERVAL '60 days'
  ORDER BY 3 DESC;
END $$;

-- ============================================================
-- Write RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_cofounder_okr_upsert(
  p_cofounder_user_id uuid,
  p_cofounder_name text,
  p_cofounder_role text,
  p_quarter text,
  p_objective text,
  p_key_result text,
  p_target_value numeric,
  p_weight_pct numeric
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_cofounder_okrs (cofounder_user_id, cofounder_name, cofounder_role, quarter, objective, key_result, target_value, weight_pct)
  VALUES (p_cofounder_user_id, p_cofounder_name, p_cofounder_role, p_quarter, p_objective, p_key_result, p_target_value, p_weight_pct)
  RETURNING id INTO new_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cofounder_okr_upsert',
          jsonb_build_object('okr_id', new_id, 'cofounder', p_cofounder_name, 'quarter', p_quarter));
  RETURN new_id;
END $$;

CREATE OR REPLACE FUNCTION log_founder_cofounder_okr_progress(
  p_okr_id uuid,
  p_current_value numeric,
  p_status text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_cofounder_okrs
     SET current_value = p_current_value,
         status = p_status,
         updated_at = now()
   WHERE id = p_okr_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cofounder_okr_progress',
          jsonb_build_object('okr_id', p_okr_id, 'current_value', p_current_value, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION log_founder_cofounder_sync_record(
  p_sync_date date,
  p_week_label text,
  p_attendees text[],
  p_topics text,
  p_health_score smallint
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_cofounder_sync_log (sync_date, week_label, attendees, topics_discussed, health_score)
  VALUES (p_sync_date, p_week_label, p_attendees, p_topics, p_health_score)
  RETURNING id INTO new_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cofounder_sync_record',
          jsonb_build_object('sync_id', new_id, 'sync_date', p_sync_date, 'health', p_health_score));
  RETURN new_id;
END $$;

CREATE OR REPLACE FUNCTION log_founder_cofounder_dep_link(
  p_child_okr_id uuid,
  p_parent_okr_id uuid
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_cofounder_okrs
     SET depends_on_okr_id = p_parent_okr_id,
         updated_at = now()
   WHERE id = p_child_okr_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cofounder_dep_link',
          jsonb_build_object('child', p_child_okr_id, 'parent', p_parent_okr_id));
END $$;

-- ============================================================
-- Grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION founder_cofounder_okr_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_cofounder_okr_list() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_cofounder_per_cofounder_rollup() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_cofounder_dependency_graph() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_cofounder_sync_recent() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_cofounder_quarter_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_cofounder_misalignment_signals() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_cofounder_okr_upsert(uuid, text, text, text, text, text, numeric, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_cofounder_okr_progress(uuid, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_cofounder_sync_record(date, text, text[], text, smallint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_cofounder_dep_link(uuid, uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_cofounder_okr_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_cofounder_okr_list() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_cofounder_per_cofounder_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_cofounder_dependency_graph() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_cofounder_sync_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_cofounder_quarter_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_cofounder_misalignment_signals() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_cofounder_okr_upsert(uuid, text, text, text, text, text, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_cofounder_okr_progress(uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_cofounder_sync_record(date, text, text[], text, smallint) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_cofounder_dep_link(uuid, uuid) TO authenticated;

COMMIT;