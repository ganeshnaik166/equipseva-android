BEGIN;

-- Round 1631 — Engineer mentor effectiveness
-- Rate mentors by apprentice graduation rate + apprentice job-success rate.
-- Per-mentor effectiveness score. Founder can rebalance assignments.

-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_mentor_apprentice_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  apprentice_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  unassigned_at timestamptz,
  graduated_at timestamptz,
  notes text,
  CONSTRAINT mentor_not_self CHECK (mentor_user_id <> apprentice_user_id)
);

CREATE INDEX IF NOT EXISTS idx_fmal_mentor ON founder_mentor_apprentice_links(mentor_user_id) WHERE unassigned_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_fmal_apprentice ON founder_mentor_apprentice_links(apprentice_user_id) WHERE unassigned_at IS NULL;

CREATE TABLE IF NOT EXISTS founder_mentor_effectiveness_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  computed_at timestamptz NOT NULL DEFAULT now(),
  apprentice_count int NOT NULL DEFAULT 0,
  graduated_count int NOT NULL DEFAULT 0,
  graduation_rate numeric(5,2) NOT NULL DEFAULT 0,
  apprentice_jobs_total int NOT NULL DEFAULT 0,
  apprentice_jobs_success int NOT NULL DEFAULT 0,
  job_success_rate numeric(5,2) NOT NULL DEFAULT 0,
  effectiveness_score numeric(5,2) NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_fmes_mentor ON founder_mentor_effectiveness_snapshots(mentor_user_id, computed_at DESC);

ALTER TABLE founder_mentor_apprentice_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_mentor_effectiveness_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fmal_founder_only ON founder_mentor_apprentice_links;
CREATE POLICY fmal_founder_only ON founder_mentor_apprentice_links
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS fmes_founder_only ON founder_mentor_effectiveness_snapshots;
CREATE POLICY fmes_founder_only ON founder_mentor_effectiveness_snapshots
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- Read RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_mentor_effectiveness_list()
RETURNS TABLE(
  mentor_user_id uuid,
  mentor_email text,
  mentor_tier text,
  apprentice_count int,
  graduated_count int,
  graduation_rate numeric,
  apprentice_jobs_total bigint,
  apprentice_jobs_success bigint,
  job_success_rate numeric,
  effectiveness_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH links AS (
    SELECT l.mentor_user_id,
           COUNT(*)::int AS appr_total,
           COUNT(*) FILTER (WHERE l.graduated_at IS NOT NULL)::int AS grad_total
    FROM founder_mentor_apprentice_links l
    WHERE l.unassigned_at IS NULL
    GROUP BY l.mentor_user_id
  ),
  appr_jobs AS (
    SELECT l.mentor_user_id,
           COUNT(rj.id) AS jobs_total,
           COUNT(rj.id) FILTER (WHERE rj.hospital_rating IS NOT NULL AND rj.hospital_rating >= 4) AS jobs_success
    FROM founder_mentor_apprentice_links l
    JOIN engineers e ON e.user_id = l.apprentice_user_id
    LEFT JOIN repair_jobs rj ON rj.engineer_id = e.id AND rj.status = 'completed'
    WHERE l.unassigned_at IS NULL
    GROUP BY l.mentor_user_id
  )
  SELECT li.mentor_user_id,
         p.email,
         e.cached_highest_tier,
         COALESCE(li.appr_total, 0),
         COALESCE(li.grad_total, 0),
         CASE WHEN COALESCE(li.appr_total,0) > 0
              THEN ROUND((li.grad_total::numeric / li.appr_total) * 100, 2)
              ELSE 0 END,
         COALESCE(aj.jobs_total, 0),
         COALESCE(aj.jobs_success, 0),
         CASE WHEN COALESCE(aj.jobs_total,0) > 0
              THEN ROUND((aj.jobs_success::numeric / aj.jobs_total) * 100, 2)
              ELSE 0 END,
         ROUND(
           (CASE WHEN COALESCE(li.appr_total,0) > 0 THEN (li.grad_total::numeric / li.appr_total) * 50 ELSE 0 END) +
           (CASE WHEN COALESCE(aj.jobs_total,0) > 0 THEN (aj.jobs_success::numeric / aj.jobs_total) * 50 ELSE 0 END),
           2
         )
  FROM links li
  LEFT JOIN appr_jobs aj ON aj.mentor_user_id = li.mentor_user_id
  LEFT JOIN profiles p ON p.id = li.mentor_user_id
  LEFT JOIN engineers e ON e.user_id = li.mentor_user_id
  ORDER BY 10 DESC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION founder_mentor_apprentices_list()
RETURNS TABLE(
  link_id uuid,
  mentor_user_id uuid,
  mentor_email text,
  apprentice_user_id uuid,
  apprentice_email text,
  apprentice_tier text,
  assigned_at timestamptz,
  graduated_at timestamptz,
  jobs_completed bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id,
         l.mentor_user_id,
         pm.email,
         l.apprentice_user_id,
         pa.email,
         ea.cached_highest_tier,
         l.assigned_at,
         l.graduated_at,
         (SELECT COUNT(*) FROM repair_jobs rj
          WHERE rj.engineer_id = ea.id AND rj.status = 'completed')
  FROM founder_mentor_apprentice_links l
  LEFT JOIN profiles pm ON pm.id = l.mentor_user_id
  LEFT JOIN profiles pa ON pa.id = l.apprentice_user_id
  LEFT JOIN engineers ea ON ea.user_id = l.apprentice_user_id
  WHERE l.unassigned_at IS NULL
  ORDER BY l.assigned_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION founder_mentor_unassigned_apprentices()
RETURNS TABLE(
  apprentice_user_id uuid,
  apprentice_email text,
  cached_highest_tier text,
  jobs_completed bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.user_id,
         p.email,
         e.cached_highest_tier,
         (SELECT COUNT(*) FROM repair_jobs rj
          WHERE rj.engineer_id = e.id AND rj.status = 'completed')
  FROM engineers e
  JOIN profiles p ON p.id = e.user_id
  WHERE e.cached_highest_tier IN ('apprentice','junior')
    AND NOT EXISTS (
      SELECT 1 FROM founder_mentor_apprentice_links l
      WHERE l.apprentice_user_id = e.user_id AND l.unassigned_at IS NULL
    )
  ORDER BY p.email
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION founder_mentor_effectiveness_history(p_mentor uuid)
RETURNS TABLE(
  id uuid,
  computed_at timestamptz,
  apprentice_count int,
  graduated_count int,
  graduation_rate numeric,
  job_success_rate numeric,
  effectiveness_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.computed_at, s.apprentice_count, s.graduated_count,
         s.graduation_rate, s.job_success_rate, s.effectiveness_score
  FROM founder_mentor_effectiveness_snapshots s
  WHERE s.mentor_user_id = p_mentor
  ORDER BY s.computed_at DESC
  LIMIT 50;
END;
$$;

-- ============================================================
-- Write RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_mentor_assign(p_mentor uuid, p_apprentice uuid, p_notes text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_mentor_apprentice_links(mentor_user_id, apprentice_user_id, notes)
  VALUES (p_mentor, p_apprentice, p_notes)
  RETURNING id INTO v_id;
  PERFORM log_founder_mentor_assign(v_id, p_mentor, p_apprentice);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION founder_mentor_unassign(p_link_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_mentor_apprentice_links
  SET unassigned_at = now()
  WHERE id = p_link_id;
  PERFORM log_founder_mentor_unassign(p_link_id);
END;
$$;

CREATE OR REPLACE FUNCTION founder_mentor_mark_graduated(p_link_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_mentor_apprentice_links
  SET graduated_at = now()
  WHERE id = p_link_id AND graduated_at IS NULL;
  PERFORM log_founder_mentor_graduate(p_link_id);
END;
$$;

CREATE OR REPLACE FUNCTION founder_mentor_snapshot_compute()
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_mentor_effectiveness_snapshots(
    mentor_user_id, apprentice_count, graduated_count, graduation_rate,
    apprentice_jobs_total, apprentice_jobs_success, job_success_rate, effectiveness_score
  )
  SELECT r.mentor_user_id,
         r.apprentice_count,
         r.graduated_count,
         r.graduation_rate,
         r.apprentice_jobs_total::int,
         r.apprentice_jobs_success::int,
         r.job_success_rate,
         r.effectiveness_score
  FROM founder_mentor_effectiveness_list() r;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  PERFORM log_founder_mentor_snapshot(v_count);
  RETURN v_count;
END;
$$;

-- ============================================================
-- Logging helpers (gated)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_mentor_assign(p_link uuid, p_mentor uuid, p_apprentice uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mentor_assign',
          jsonb_build_object('link_id', p_link, 'mentor', p_mentor, 'apprentice', p_apprentice),
          now());
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_mentor_unassign(p_link uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mentor_unassign',
          jsonb_build_object('link_id', p_link), now());
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_mentor_graduate(p_link uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mentor_graduate',
          jsonb_build_object('link_id', p_link), now());
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_mentor_snapshot(p_count int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mentor_snapshot',
          jsonb_build_object('row_count', p_count), now());
END;
$$;

-- ============================================================
-- Grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION founder_mentor_effectiveness_list() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_mentor_apprentices_list() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_mentor_unassigned_apprentices() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_mentor_effectiveness_history(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_mentor_assign(uuid, uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_mentor_unassign(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_mentor_mark_graduated(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_mentor_snapshot_compute() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_mentor_assign(uuid, uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_mentor_unassign(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_mentor_graduate(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_mentor_snapshot(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_mentor_effectiveness_list() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_mentor_apprentices_list() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_mentor_unassigned_apprentices() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_mentor_effectiveness_history(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_mentor_assign(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_mentor_unassign(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_mentor_mark_graduated(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_mentor_snapshot_compute() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_mentor_assign(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_mentor_unassign(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_mentor_graduate(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_mentor_snapshot(int) TO authenticated;

COMMIT;