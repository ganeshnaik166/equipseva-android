BEGIN;

-- =============================================================
-- r1521 — Founder Engineer Skills Graph
-- per-engineer skill matrix (equipment categories × proficiency)
-- aggregate fleet-coverage gaps; surface skill bottlenecks
-- =============================================================

-- Table 1: engineer skill entries
CREATE TABLE IF NOT EXISTS founder_engineer_skill_entries_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  equipment_category text NOT NULL,
  proficiency_level text NOT NULL CHECK (proficiency_level IN ('novice','competent','proficient','expert','master')),
  proficiency_score int NOT NULL DEFAULT 0 CHECK (proficiency_score BETWEEN 0 AND 100),
  jobs_completed int NOT NULL DEFAULT 0,
  last_assessed_at timestamptz,
  certified boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_id, equipment_category)
);

CREATE INDEX IF NOT EXISTS idx_fes_entries_v2_engineer ON founder_engineer_skill_entries_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_fes_entries_v2_category ON founder_engineer_skill_entries_v2(equipment_category);
CREATE INDEX IF NOT EXISTS idx_fes_entries_v2_level ON founder_engineer_skill_entries_v2(proficiency_level);

ALTER TABLE founder_engineer_skill_entries_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fes_entries_v2_founder_only ON founder_engineer_skill_entries_v2;
CREATE POLICY fes_entries_v2_founder_only ON founder_engineer_skill_entries_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Table 2: fleet category coverage snapshots
CREATE TABLE IF NOT EXISTS founder_skill_coverage_snapshots_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_category text NOT NULL,
  total_engineers_covering int NOT NULL DEFAULT 0,
  expert_count int NOT NULL DEFAULT 0,
  proficient_count int NOT NULL DEFAULT 0,
  fleet_jobs_30d int NOT NULL DEFAULT 0,
  coverage_ratio numeric(6,3) NOT NULL DEFAULT 0,
  gap_score numeric(6,3) NOT NULL DEFAULT 0,
  snapshot_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsc_snapshots_v2_category ON founder_skill_coverage_snapshots_v2(equipment_category);
CREATE INDEX IF NOT EXISTS idx_fsc_snapshots_v2_when ON founder_skill_coverage_snapshots_v2(snapshot_at DESC);

ALTER TABLE founder_skill_coverage_snapshots_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fsc_snapshots_v2_founder_only ON founder_skill_coverage_snapshots_v2;
CREATE POLICY fsc_snapshots_v2_founder_only ON founder_skill_coverage_snapshots_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =============================================================
-- log helpers (write-side, VOLATILE)
-- =============================================================

CREATE OR REPLACE FUNCTION log_founder_skill_entry_upsert(
  p_engineer uuid,
  p_category text,
  p_level text,
  p_score int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_skill_entry_upsert',
    jsonb_build_object('engineer', p_engineer, 'category', p_category, 'level', p_level, 'score', p_score)
  );
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_skill_coverage_snapshot(
  p_category text,
  p_coverage numeric,
  p_gap numeric
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_skill_coverage_snapshot',
    jsonb_build_object('category', p_category, 'coverage', p_coverage, 'gap', p_gap)
  );
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_skill_bottleneck_flag(
  p_category text,
  p_severity text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_skill_bottleneck_flag',
    jsonb_build_object('category', p_category, 'severity', p_severity)
  );
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_skill_recompute(
  p_rows int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_skill_recompute',
    jsonb_build_object('rows', p_rows)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_skill_entry_upsert(uuid, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_skill_coverage_snapshot(text, numeric, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_skill_bottleneck_flag(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_skill_recompute(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_skill_entry_upsert(uuid, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_skill_coverage_snapshot(text, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_skill_bottleneck_flag(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_skill_recompute(int) TO authenticated;

-- =============================================================
-- Write RPCs (VOLATILE)
-- =============================================================

CREATE OR REPLACE FUNCTION founder_skill_entry_upsert(
  p_engineer uuid,
  p_category text,
  p_level text,
  p_score int,
  p_certified boolean DEFAULT false,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_engineer_skill_entries_v2 (engineer_id, equipment_category, proficiency_level, proficiency_score, certified, notes, last_assessed_at)
  VALUES (p_engineer, p_category, p_level, p_score, COALESCE(p_certified, false), p_notes, now())
  ON CONFLICT (engineer_id, equipment_category) DO UPDATE
    SET proficiency_level = EXCLUDED.proficiency_level,
        proficiency_score = EXCLUDED.proficiency_score,
        certified = EXCLUDED.certified,
        notes = EXCLUDED.notes,
        last_assessed_at = now(),
        updated_at = now()
  RETURNING id INTO v_id;
  PERFORM log_founder_skill_entry_upsert(p_engineer, p_category, p_level, p_score);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION founder_skill_recompute_coverage()
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rows int := 0;
  r record;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  FOR r IN
    SELECT equipment_category,
           COUNT(*)::int AS total_eng,
           COUNT(*) FILTER (WHERE proficiency_level IN ('expert','master'))::int AS experts,
           COUNT(*) FILTER (WHERE proficiency_level IN ('proficient','expert','master'))::int AS profs
    FROM founder_engineer_skill_entries_v2
    GROUP BY equipment_category
  LOOP
    INSERT INTO founder_skill_coverage_snapshots_v2 (
      equipment_category, total_engineers_covering, expert_count, proficient_count,
      fleet_jobs_30d, coverage_ratio, gap_score, snapshot_at
    ) VALUES (
      r.equipment_category, r.total_eng, r.experts, r.profs,
      0,
      CASE WHEN r.total_eng > 0 THEN (r.profs::numeric / r.total_eng) ELSE 0 END,
      CASE WHEN r.total_eng > 0 THEN GREATEST(0, 1 - (r.experts::numeric / GREATEST(r.total_eng,1))) ELSE 1 END,
      now()
    );
    v_rows := v_rows + 1;
  END LOOP;
  PERFORM log_founder_skill_recompute(v_rows);
  RETURN v_rows;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_skill_entry_upsert(uuid, text, text, int, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_skill_recompute_coverage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_skill_entry_upsert(uuid, text, text, int, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_skill_recompute_coverage() TO authenticated;

-- =============================================================
-- Read RPCs (STABLE) — 7 total SECDEF read fns
-- =============================================================

CREATE OR REPLACE FUNCTION founder_skill_matrix_kpis()
RETURNS TABLE (
  total_engineers bigint,
  total_skill_entries bigint,
  total_categories bigint,
  expert_count bigint,
  master_count bigint,
  proficient_count bigint,
  novice_count bigint,
  certified_count bigint,
  avg_score numeric,
  median_score numeric,
  uncovered_categories bigint,
  bottleneck_categories bigint,
  engineers_no_skills bigint,
  engineers_single_skill bigint,
  recent_assessments_30d bigint,
  stale_assessments_180d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ent AS (SELECT * FROM founder_engineer_skill_entries_v2),
  per_eng AS (
    SELECT engineer_id, COUNT(*) AS skills FROM ent GROUP BY engineer_id
  ),
  per_cat AS (
    SELECT equipment_category, COUNT(*) AS engs,
      COUNT(*) FILTER (WHERE proficiency_level IN ('expert','master')) AS experts
    FROM ent GROUP BY equipment_category
  )
  SELECT
    (SELECT COUNT(DISTINCT id) FROM engineers)::bigint,
    (SELECT COUNT(*) FROM ent)::bigint,
    (SELECT COUNT(DISTINCT equipment_category) FROM ent)::bigint,
    (SELECT COUNT(*) FROM ent WHERE proficiency_level = 'expert')::bigint,
    (SELECT COUNT(*) FROM ent WHERE proficiency_level = 'master')::bigint,
    (SELECT COUNT(*) FROM ent WHERE proficiency_level = 'proficient')::bigint,
    (SELECT COUNT(*) FROM ent WHERE proficiency_level = 'novice')::bigint,
    (SELECT COUNT(*) FROM ent WHERE certified = true)::bigint,
    COALESCE((SELECT AVG(proficiency_score) FROM ent),0)::numeric,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY proficiency_score) FROM ent),0)::numeric,
    (SELECT COUNT(*) FROM per_cat WHERE engs < 2)::bigint,
    (SELECT COUNT(*) FROM per_cat WHERE experts = 0)::bigint,
    GREATEST(0, (SELECT COUNT(*) FROM engineers) - (SELECT COUNT(*) FROM per_eng))::bigint,
    (SELECT COUNT(*) FROM per_eng WHERE skills = 1)::bigint,
    (SELECT COUNT(*) FROM ent WHERE last_assessed_at > now() - interval '30 days')::bigint,
    (SELECT COUNT(*) FROM ent WHERE last_assessed_at IS NULL OR last_assessed_at < now() - interval '180 days')::bigint;
END;
$$;

CREATE OR REPLACE FUNCTION founder_skill_matrix_by_engineer(p_limit int DEFAULT 100)
RETURNS TABLE (
  id text,
  engineer_id uuid,
  engineer_email text,
  tier text,
  skill_count bigint,
  avg_score numeric,
  expert_count bigint,
  certified_count bigint,
  last_assessed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id::text AS id,
    e.id AS engineer_id,
    COALESCE(p.email, '—') AS engineer_email,
    COALESCE(e.cached_highest_tier, 'none')::text AS tier,
    COUNT(s.id)::bigint,
    COALESCE(AVG(s.proficiency_score),0)::numeric,
    COUNT(*) FILTER (WHERE s.proficiency_level IN ('expert','master'))::bigint,
    COUNT(*) FILTER (WHERE s.certified = true)::bigint,
    MAX(s.last_assessed_at)
  FROM engineers e
  LEFT JOIN founder_engineer_skill_entries_v2 s ON s.engineer_id = e.id
  LEFT JOIN profiles p ON p.id = e.user_id
  GROUP BY e.id, p.email, e.cached_highest_tier
  ORDER BY COUNT(s.id) DESC NULLS LAST
  LIMIT GREATEST(COALESCE(p_limit,100),1);
END;
$$;

CREATE OR REPLACE FUNCTION founder_skill_fleet_coverage_gaps(p_limit int DEFAULT 50)
RETURNS TABLE (
  id text,
  equipment_category text,
  engineers_covering bigint,
  expert_count bigint,
  proficient_count bigint,
  avg_score numeric,
  coverage_ratio numeric,
  gap_severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT equipment_category,
      COUNT(*)::bigint AS engs,
      COUNT(*) FILTER (WHERE proficiency_level IN ('expert','master'))::bigint AS experts,
      COUNT(*) FILTER (WHERE proficiency_level IN ('proficient','expert','master'))::bigint AS profs,
      COALESCE(AVG(proficiency_score),0)::numeric AS avg_s
    FROM founder_engineer_skill_entries_v2
    GROUP BY equipment_category
  )
  SELECT
    equipment_category::text AS id,
    equipment_category,
    engs,
    experts,
    profs,
    avg_s,
    CASE WHEN engs > 0 THEN (profs::numeric / engs) ELSE 0 END,
    CASE
      WHEN engs = 0 THEN 'critical'
      WHEN experts = 0 THEN 'high'
      WHEN engs < 3 THEN 'medium'
      ELSE 'low'
    END::text
  FROM agg
  ORDER BY engs ASC, experts ASC
  LIMIT GREATEST(COALESCE(p_limit,50),1);
END;
$$;

CREATE OR REPLACE FUNCTION founder_skill_bottlenecks(p_limit int DEFAULT 25)
RETURNS TABLE (
  id text,
  equipment_category text,
  engineers_covering bigint,
  expert_count bigint,
  bottleneck_score numeric,
  recommendation text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT equipment_category,
      COUNT(*)::bigint AS engs,
      COUNT(*) FILTER (WHERE proficiency_level IN ('expert','master'))::bigint AS experts
    FROM founder_engineer_skill_entries_v2
    GROUP BY equipment_category
  )
  SELECT
    equipment_category::text,
    equipment_category,
    engs,
    experts,
    (1.0 - (experts::numeric / GREATEST(engs,1)))::numeric,
    CASE
      WHEN engs = 0 THEN 'hire_or_train_urgent'
      WHEN experts = 0 THEN 'upskill_to_expert'
      WHEN engs < 3 THEN 'add_redundancy'
      ELSE 'monitor'
    END::text
  FROM agg
  WHERE engs < 3 OR experts = 0
  ORDER BY experts ASC, engs ASC
  LIMIT GREATEST(COALESCE(p_limit,25),1);
END;
$$;

CREATE OR REPLACE FUNCTION founder_skill_proficiency_distribution()
RETURNS TABLE (
  id text,
  proficiency_level text,
  entry_count bigint,
  pct_of_total numeric,
  avg_score numeric,
  certified_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM founder_engineer_skill_entries_v2;
  RETURN QUERY
  SELECT
    proficiency_level::text AS id,
    proficiency_level,
    COUNT(*)::bigint,
    CASE WHEN v_total > 0 THEN (COUNT(*)::numeric / v_total * 100.0) ELSE 0 END::numeric,
    COALESCE(AVG(proficiency_score),0)::numeric,
    COUNT(*) FILTER (WHERE certified = true)::bigint
  FROM founder_engineer_skill_entries_v2
  GROUP BY proficiency_level
  ORDER BY COUNT(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_skill_recent_assessments(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_email text,
  equipment_category text,
  proficiency_level text,
  proficiency_score int,
  certified boolean,
  last_assessed_at timestamptz,
  days_since_assessed numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.engineer_id,
    COALESCE(p.email,'—'),
    s.equipment_category,
    s.proficiency_level,
    s.proficiency_score,
    s.certified,
    s.last_assessed_at,
    CASE WHEN s.last_assessed_at IS NOT NULL THEN
      (EXTRACT(EPOCH FROM (now() - s.last_assessed_at))/86400.0)::numeric
    ELSE NULL END
  FROM founder_engineer_skill_entries_v2 s
  LEFT JOIN engineers e ON e.id = s.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY s.last_assessed_at DESC NULLS LAST
  LIMIT GREATEST(COALESCE(p_limit,50),1);
END;
$$;

CREATE OR REPLACE FUNCTION founder_skill_coverage_history(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  equipment_category text,
  total_engineers_covering int,
  expert_count int,
  proficient_count int,
  coverage_ratio numeric,
  gap_score numeric,
  snapshot_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT id, equipment_category, total_engineers_covering, expert_count, proficient_count,
         coverage_ratio, gap_score, snapshot_at
  FROM founder_skill_coverage_snapshots_v2
  ORDER BY snapshot_at DESC
  LIMIT GREATEST(COALESCE(p_limit,50),1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_skill_matrix_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_skill_matrix_by_engineer(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_skill_fleet_coverage_gaps(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_skill_bottlenecks(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_skill_proficiency_distribution() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_skill_recent_assessments(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_skill_coverage_history(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_skill_matrix_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_skill_matrix_by_engineer(int) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_skill_fleet_coverage_gaps(int) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_skill_bottlenecks(int) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_skill_proficiency_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_skill_recent_assessments(int) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_skill_coverage_history(int) TO authenticated;

COMMIT;