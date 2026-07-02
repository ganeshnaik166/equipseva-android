BEGIN;

-- =====================================================================
-- r1478: Founder Time-Tracking Ledger
-- Log founder time allocation across categories
-- Visualize where founder bottleneck is
-- =====================================================================

-- Time-tracking entries: one row per logged time block
CREATE TABLE IF NOT EXISTS founder_time_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_date date NOT NULL DEFAULT CURRENT_DATE,
  category text NOT NULL CHECK (category IN ('eng','sales','people','legal','investor','admin','product','support','strategy','ops')),
  hours numeric(5,2) NOT NULL CHECK (hours > 0 AND hours <= 24),
  note text,
  energy_level text CHECK (energy_level IN ('high','medium','low','drained')),
  is_bottleneck boolean NOT NULL DEFAULT false,
  was_planned boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_time_entries_date ON founder_time_entries(entry_date DESC);
CREATE INDEX IF NOT EXISTS idx_founder_time_entries_category ON founder_time_entries(category, entry_date DESC);
CREATE INDEX IF NOT EXISTS idx_founder_time_entries_bottleneck ON founder_time_entries(is_bottleneck, entry_date DESC) WHERE is_bottleneck = true;

ALTER TABLE founder_time_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_time_entries ON founder_time_entries;
CREATE POLICY founder_only_time_entries ON founder_time_entries
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Weekly targets per category (founder's ideal allocation)
CREATE TABLE IF NOT EXISTS founder_time_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL UNIQUE CHECK (category IN ('eng','sales','people','legal','investor','admin','product','support','strategy','ops')),
  target_weekly_hours numeric(5,2) NOT NULL CHECK (target_weekly_hours >= 0),
  rationale text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_time_targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_time_targets ON founder_time_targets;
CREATE POLICY founder_only_time_targets ON founder_time_targets
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Seed default targets
INSERT INTO founder_time_targets (category, target_weekly_hours, rationale) VALUES
  ('eng', 20, 'Code review + architecture decisions'),
  ('sales', 15, 'Hospital chain discovery calls'),
  ('people', 8, '1:1s with engineers + hiring'),
  ('legal', 4, 'Contracts + compliance review'),
  ('investor', 6, 'Updates + pipeline mgmt'),
  ('admin', 5, 'Banking + GST + filings'),
  ('product', 10, 'Roadmap + user research'),
  ('support', 5, 'Escalations from hospitals'),
  ('strategy', 5, 'Reading + thinking time'),
  ('ops', 2, 'Internal ops')
ON CONFLICT (category) DO NOTHING;

-- =====================================================================
-- READ RPCs (STABLE)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_time_kpis()
RETURNS TABLE (
  total_hours_7d numeric,
  total_hours_30d numeric,
  total_hours_90d numeric,
  total_entries_30d bigint,
  avg_daily_hours_30d numeric,
  bottleneck_hours_30d numeric,
  unplanned_hours_30d numeric,
  drained_hours_30d numeric,
  top_category_30d text,
  top_category_hours_30d numeric,
  bottom_category_30d text,
  bottom_category_hours_30d numeric,
  variance_vs_target_pct numeric,
  categories_overshooting bigint,
  categories_undershooting bigint,
  days_logged_30d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM founder_time_entries WHERE entry_date >= CURRENT_DATE - INTERVAL '90 days'
  ),
  cat30 AS (
    SELECT category, SUM(hours) h FROM base WHERE entry_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY category
  ),
  targets AS (
    SELECT t.category, t.target_weekly_hours, COALESCE(c.h, 0) AS actual_30d,
           (t.target_weekly_hours * 30.0/7.0) AS target_30d
    FROM founder_time_targets t
    LEFT JOIN cat30 c ON c.category = t.category
  )
  SELECT
    COALESCE((SELECT SUM(hours) FROM base WHERE entry_date >= CURRENT_DATE - INTERVAL '7 days'), 0),
    COALESCE((SELECT SUM(hours) FROM base WHERE entry_date >= CURRENT_DATE - INTERVAL '30 days'), 0),
    COALESCE((SELECT SUM(hours) FROM base), 0),
    (SELECT COUNT(*) FROM base WHERE entry_date >= CURRENT_DATE - INTERVAL '30 days'),
    ROUND(COALESCE((SELECT SUM(hours) FROM base WHERE entry_date >= CURRENT_DATE - INTERVAL '30 days'), 0) / 30.0, 2),
    COALESCE((SELECT SUM(hours) FROM base WHERE entry_date >= CURRENT_DATE - INTERVAL '30 days' AND is_bottleneck), 0),
    COALESCE((SELECT SUM(hours) FROM base WHERE entry_date >= CURRENT_DATE - INTERVAL '30 days' AND NOT was_planned), 0),
    COALESCE((SELECT SUM(hours) FROM base WHERE entry_date >= CURRENT_DATE - INTERVAL '30 days' AND energy_level = 'drained'), 0),
    (SELECT category FROM cat30 ORDER BY h DESC LIMIT 1),
    COALESCE((SELECT h FROM cat30 ORDER BY h DESC LIMIT 1), 0),
    (SELECT category FROM cat30 ORDER BY h ASC LIMIT 1),
    COALESCE((SELECT h FROM cat30 ORDER BY h ASC LIMIT 1), 0),
    ROUND(COALESCE((SELECT (SUM(actual_30d) - SUM(target_30d))/NULLIF(SUM(target_30d),0)*100 FROM targets), 0), 1),
    (SELECT COUNT(*) FROM targets WHERE actual_30d > target_30d * 1.2),
    (SELECT COUNT(*) FROM targets WHERE actual_30d < target_30d * 0.8),
    (SELECT COUNT(DISTINCT entry_date) FROM base WHERE entry_date >= CURRENT_DATE - INTERVAL '30 days');
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_time_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_time_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_time_weekly_breakdown()
RETURNS TABLE (
  id text,
  week_start date,
  category text,
  hours numeric,
  entry_count bigint,
  target_hours numeric,
  variance_hours numeric,
  variance_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (date_trunc('week', e.entry_date)::date || '-' || e.category) AS id,
    date_trunc('week', e.entry_date)::date AS week_start,
    e.category,
    SUM(e.hours)::numeric AS hours,
    COUNT(*)::bigint AS entry_count,
    COALESCE(t.target_weekly_hours, 0) AS target_hours,
    (SUM(e.hours) - COALESCE(t.target_weekly_hours, 0))::numeric AS variance_hours,
    ROUND(CASE WHEN COALESCE(t.target_weekly_hours,0) = 0 THEN 0
         ELSE (SUM(e.hours) - t.target_weekly_hours) / t.target_weekly_hours * 100 END, 1) AS variance_pct
  FROM founder_time_entries e
  LEFT JOIN founder_time_targets t ON t.category = e.category
  WHERE e.entry_date >= CURRENT_DATE - INTERVAL '12 weeks'
  GROUP BY date_trunc('week', e.entry_date), e.category, t.target_weekly_hours
  ORDER BY week_start DESC, hours DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_time_weekly_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_time_weekly_breakdown() TO authenticated;

CREATE OR REPLACE FUNCTION founder_time_category_summary()
RETURNS TABLE (
  id text,
  category text,
  hours_7d numeric,
  hours_30d numeric,
  hours_90d numeric,
  target_weekly numeric,
  bottleneck_hours numeric,
  unplanned_hours numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.category AS id,
    t.category,
    COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '7 days'), 0)::numeric,
    COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '30 days'), 0)::numeric,
    COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '90 days'), 0)::numeric,
    t.target_weekly_hours,
    COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '30 days' AND e.is_bottleneck), 0)::numeric,
    COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '30 days' AND NOT e.was_planned), 0)::numeric,
    CASE
      WHEN COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '7 days'), 0) > t.target_weekly_hours * 1.3 THEN 'overshoot'
      WHEN COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '7 days'), 0) < t.target_weekly_hours * 0.5 THEN 'undershoot'
      ELSE 'on-track'
    END AS status
  FROM founder_time_targets t
  LEFT JOIN founder_time_entries e ON e.category = t.category
  GROUP BY t.category, t.target_weekly_hours
  ORDER BY hours_30d DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_time_category_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_time_category_summary() TO authenticated;

CREATE OR REPLACE FUNCTION founder_time_bottleneck_entries()
RETURNS TABLE (
  id uuid,
  entry_date date,
  category text,
  hours numeric,
  note text,
  energy_level text,
  was_planned boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.entry_date, e.category, e.hours, e.note, e.energy_level, e.was_planned
  FROM founder_time_entries e
  WHERE e.is_bottleneck = true AND e.entry_date >= CURRENT_DATE - INTERVAL '60 days'
  ORDER BY e.entry_date DESC, e.hours DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_time_bottleneck_entries() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_time_bottleneck_entries() TO authenticated;

CREATE OR REPLACE FUNCTION founder_time_recent_entries()
RETURNS TABLE (
  id uuid,
  entry_date date,
  category text,
  hours numeric,
  note text,
  energy_level text,
  is_bottleneck boolean,
  was_planned boolean,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.entry_date, e.category, e.hours, e.note, e.energy_level, e.is_bottleneck, e.was_planned, e.created_at
  FROM founder_time_entries e
  ORDER BY e.entry_date DESC, e.created_at DESC
  LIMIT 30;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_time_recent_entries() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_time_recent_entries() TO authenticated;

CREATE OR REPLACE FUNCTION founder_time_daily_totals()
RETURNS TABLE (
  id text,
  entry_date date,
  total_hours numeric,
  entry_count bigint,
  bottleneck_hours numeric,
  drained_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.entry_date::text AS id,
    e.entry_date,
    SUM(e.hours)::numeric AS total_hours,
    COUNT(*)::bigint AS entry_count,
    COALESCE(SUM(e.hours) FILTER (WHERE e.is_bottleneck), 0)::numeric,
    COALESCE(SUM(e.hours) FILTER (WHERE e.energy_level = 'drained'), 0)::numeric
  FROM founder_time_entries e
  WHERE e.entry_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY e.entry_date
  ORDER BY e.entry_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_time_daily_totals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_time_daily_totals() TO authenticated;

CREATE OR REPLACE FUNCTION founder_time_targets_overview()
RETURNS TABLE (
  id uuid,
  category text,
  target_weekly_hours numeric,
  rationale text,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.category, t.target_weekly_hours, t.rationale, t.updated_at
  FROM founder_time_targets t
  ORDER BY t.target_weekly_hours DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_time_targets_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_time_targets_overview() TO authenticated;

-- =====================================================================
-- WRITE RPCs (VOLATILE) — log_founder_* helpers
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_time_entry(
  p_entry_date date,
  p_category text,
  p_hours numeric,
  p_note text,
  p_energy_level text,
  p_is_bottleneck boolean,
  p_was_planned boolean
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_time_entries (entry_date, category, hours, note, energy_level, is_bottleneck, was_planned)
  VALUES (COALESCE(p_entry_date, CURRENT_DATE), p_category, p_hours, p_note, p_energy_level, COALESCE(p_is_bottleneck, false), COALESCE(p_was_planned, true))
  RETURNING id INTO v_id;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_founder_time_entry',
    jsonb_build_object('id', v_id, 'category', p_category, 'hours', p_hours, 'date', p_entry_date));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_time_entry(date, text, numeric, text, text, boolean, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_time_entry(date, text, numeric, text, text, boolean, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_time_target_update(
  p_category text,
  p_target_weekly_hours numeric,
  p_rationale text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_time_targets (category, target_weekly_hours, rationale, updated_at)
  VALUES (p_category, p_target_weekly_hours, p_rationale, now())
  ON CONFLICT (category) DO UPDATE
    SET target_weekly_hours = EXCLUDED.target_weekly_hours,
        rationale = EXCLUDED.rationale,
        updated_at = now()
  RETURNING id INTO v_id;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_founder_time_target_update',
    jsonb_build_object('category', p_category, 'target_weekly_hours', p_target_weekly_hours));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_time_target_update(text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_time_target_update(text, numeric, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_time_entry_delete(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  DELETE FROM founder_time_entries WHERE id = p_id;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_founder_time_entry_delete',
    jsonb_build_object('id', p_id));
  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_time_entry_delete(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_time_entry_delete(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_time_bottleneck_flag(p_id uuid, p_is_bottleneck boolean)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_time_entries SET is_bottleneck = p_is_bottleneck, updated_at = now() WHERE id = p_id;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_founder_time_bottleneck_flag',
    jsonb_build_object('id', p_id, 'is_bottleneck', p_is_bottleneck));
  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_time_bottleneck_flag(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_time_bottleneck_flag(uuid, boolean) TO authenticated;

COMMIT;