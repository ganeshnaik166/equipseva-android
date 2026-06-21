BEGIN;

-- ============================================================================
-- r1655 — Founder Engineer Skill Gaps Map
-- Identify skill gaps by equipment category across engineer fleet.
-- Founder hiring + training queue.
-- ============================================================================

-- Equipment category catalog: founder-curated list of supported categories
CREATE TABLE IF NOT EXISTS founder_skill_gap_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL UNIQUE,
  target_engineer_count int NOT NULL DEFAULT 5,
  min_tier text NOT NULL DEFAULT 'silver',
  criticality text NOT NULL DEFAULT 'medium' CHECK (criticality IN ('low','medium','high','critical')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_skill_gap_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_skill_gap_categories ON founder_skill_gap_categories;
CREATE POLICY founder_only_skill_gap_categories ON founder_skill_gap_categories
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Hiring + training queue: founder actions to close gaps
CREATE TABLE IF NOT EXISTS founder_skill_gap_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL,
  action_kind text NOT NULL CHECK (action_kind IN ('hire','train','reassign')),
  candidate_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  target_city text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','cancelled')),
  priority int NOT NULL DEFAULT 3,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_skill_gap_queue_status_priority
  ON founder_skill_gap_queue (status, priority DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_skill_gap_queue_category
  ON founder_skill_gap_queue (category);

ALTER TABLE founder_skill_gap_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_skill_gap_queue ON founder_skill_gap_queue;
CREATE POLICY founder_only_skill_gap_queue ON founder_skill_gap_queue
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Seed a few core categories if empty
INSERT INTO founder_skill_gap_categories (category, target_engineer_count, min_tier, criticality)
SELECT * FROM (VALUES
  ('MRI', 5, 'gold', 'critical'),
  ('CT', 5, 'gold', 'critical'),
  ('Ultrasound', 8, 'silver', 'high'),
  ('XRay', 8, 'silver', 'high'),
  ('Ventilator', 6, 'silver', 'high'),
  ('Dialysis', 4, 'silver', 'medium'),
  ('Anesthesia', 4, 'silver', 'medium'),
  ('Dental', 6, 'silver', 'medium')
) AS v(category, target_engineer_count, min_tier, criticality)
WHERE NOT EXISTS (SELECT 1 FROM founder_skill_gap_categories);

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1. List skill gaps: compare actual engineer count per category to target
CREATE OR REPLACE FUNCTION founder_skill_gap_overview()
RETURNS TABLE (
  category text,
  target_count int,
  current_count int,
  gap int,
  criticality text,
  min_tier text,
  amc_contracts_count int,
  open_jobs_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.category,
    c.target_engineer_count AS target_count,
    COALESCE(eng.cnt, 0)::int AS current_count,
    GREATEST(c.target_engineer_count - COALESCE(eng.cnt, 0), 0)::int AS gap,
    c.criticality,
    c.min_tier,
    COALESCE(amc.cnt, 0)::int AS amc_contracts_count,
    COALESCE(jobs.cnt, 0)::int AS open_jobs_count
  FROM founder_skill_gap_categories c
  LEFT JOIN (
    SELECT unnest(skills) AS skill, COUNT(DISTINCT user_id)::int AS cnt
    FROM engineers
    WHERE skills IS NOT NULL
    GROUP BY 1
  ) eng ON eng.skill = c.category
  LEFT JOIN (
    SELECT unnest(equipment_categories) AS cat, COUNT(*)::int AS cnt
    FROM amc_contracts
    WHERE status = 'active'
    GROUP BY 1
  ) amc ON amc.cat = c.category
  LEFT JOIN (
    SELECT equipment_category AS cat, COUNT(*)::int AS cnt
    FROM repair_jobs
    WHERE status IN ('open','assigned','in_progress')
    GROUP BY 1
  ) jobs ON jobs.cat = c.category
  ORDER BY GREATEST(c.target_engineer_count - COALESCE(eng.cnt, 0), 0) DESC,
           CASE c.criticality
             WHEN 'critical' THEN 4 WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_skill_gap_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_skill_gap_overview() TO authenticated;

-- 2. Engineers per category breakdown with tier mix
CREATE OR REPLACE FUNCTION founder_skill_gap_engineer_breakdown()
RETURNS TABLE (
  category text,
  tier text,
  engineer_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    unnest(e.skills) AS category,
    COALESCE(e.cached_highest_tier, 'unranked') AS tier,
    COUNT(*)::int AS engineer_count
  FROM engineers e
  WHERE e.skills IS NOT NULL
  GROUP BY 1, 2
  ORDER BY 1, 2;
END $$;

REVOKE EXECUTE ON FUNCTION founder_skill_gap_engineer_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_skill_gap_engineer_breakdown() TO authenticated;

-- 3. Geographic gap: engineers per category per state
CREATE OR REPLACE FUNCTION founder_skill_gap_by_state(p_category text)
RETURNS TABLE (
  state text,
  engineer_count int,
  active_amc_count int,
  open_jobs_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(o.state, 'unknown') AS state,
    (COUNT(DISTINCT e.user_id) FILTER (WHERE p_category = ANY(e.skills)))::int AS engineer_count,
    (COUNT(DISTINCT a.id) FILTER (WHERE p_category = ANY(a.equipment_categories) AND a.status = 'active'))::int AS active_amc_count,
    (COUNT(DISTINCT rj.id) FILTER (WHERE rj.equipment_category = p_category AND rj.status IN ('open','assigned','in_progress')))::int AS open_jobs_count
  FROM organizations o
  LEFT JOIN profiles p ON p.organization_id = o.id
  LEFT JOIN engineers e ON e.user_id = p.id
  LEFT JOIN amc_contracts a ON a.hospital_user_id = p.id
  LEFT JOIN repair_jobs rj ON rj.hospital_org_id = o.id
  GROUP BY o.state
  ORDER BY engineer_count ASC, open_jobs_count DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_skill_gap_by_state(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_skill_gap_by_state(text) TO authenticated;

-- 4. List hiring + training queue
CREATE OR REPLACE FUNCTION founder_skill_gap_queue_list(p_status text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  category text,
  action_kind text,
  candidate_user_id uuid,
  candidate_email text,
  target_city text,
  status text,
  priority int,
  notes text,
  created_at timestamptz,
  closed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.category, q.action_kind, q.candidate_user_id,
         p.email AS candidate_email,
         q.target_city, q.status, q.priority, q.notes, q.created_at, q.closed_at
  FROM founder_skill_gap_queue q
  LEFT JOIN profiles p ON p.id = q.candidate_user_id
  WHERE (p_status IS NULL OR q.status = p_status)
  ORDER BY q.priority DESC, q.created_at DESC
  LIMIT 500;
END $$;

REVOKE EXECUTE ON FUNCTION founder_skill_gap_queue_list(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_skill_gap_queue_list(text) TO authenticated;

-- 5. Queue item create
CREATE OR REPLACE FUNCTION founder_skill_gap_queue_create(
  p_category text,
  p_action_kind text,
  p_candidate_user_id uuid,
  p_target_city text,
  p_priority int,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_skill_gap_queue (category, action_kind, candidate_user_id, target_city, priority, notes)
  VALUES (p_category, p_action_kind, p_candidate_user_id, p_target_city, COALESCE(p_priority, 3), p_notes)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_skill_gap_queue_create',
    jsonb_build_object('id', v_id, 'category', p_category, 'action_kind', p_action_kind, 'priority', p_priority),
    now()
  );
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION founder_skill_gap_queue_create(text, text, uuid, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_skill_gap_queue_create(text, text, uuid, text, int, text) TO authenticated;

-- 6. Queue status update
CREATE OR REPLACE FUNCTION founder_skill_gap_queue_update_status(
  p_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_skill_gap_queue
  SET status = p_new_status,
      updated_at = now(),
      closed_at = CASE WHEN p_new_status IN ('done','cancelled') THEN now() ELSE closed_at END
  WHERE id = p_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_skill_gap_queue_update_status',
    jsonb_build_object('id', p_id, 'new_status', p_new_status),
    now()
  );
END $$;

REVOKE EXECUTE ON FUNCTION founder_skill_gap_queue_update_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_skill_gap_queue_update_status(uuid, text) TO authenticated;

-- 7. Top candidates: engineers with adjacent skills who could be trained on the gap category
CREATE OR REPLACE FUNCTION founder_skill_gap_training_candidates(p_category text)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  current_skills text[],
  cached_highest_tier text,
  completed_jobs_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.user_id AS engineer_user_id,
    p.email AS engineer_email,
    e.skills AS current_skills,
    COALESCE(e.cached_highest_tier, 'unranked') AS cached_highest_tier,
    (SELECT COUNT(*) FROM repair_jobs rj
      WHERE rj.engineer_id = e.id AND rj.status = 'completed')::int AS completed_jobs_count
  FROM engineers e
  JOIN profiles p ON p.id = e.user_id
  WHERE e.skills IS NOT NULL
    AND NOT (p_category = ANY(e.skills))
    AND array_length(e.skills, 1) >= 1
  ORDER BY array_length(e.skills, 1) DESC,
           CASE COALESCE(e.cached_highest_tier, 'unranked')
             WHEN 'platinum' THEN 5 WHEN 'gold' THEN 4 WHEN 'silver' THEN 3 WHEN 'bronze' THEN 2 ELSE 1 END DESC
  LIMIT 50;
END $$;

REVOKE EXECUTE ON FUNCTION founder_skill_gap_training_candidates(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_skill_gap_training_candidates(text) TO authenticated;

COMMIT;