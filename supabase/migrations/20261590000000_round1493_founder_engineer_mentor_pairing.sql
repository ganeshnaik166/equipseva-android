BEGIN;

-- =====================================================================
-- r1493 — Engineer Mentor-Pairing Program
-- Pair senior engineers with juniors; track session cadence, completion,
-- skills covered, mentor NPS; per-pair surface + stale-no-meeting alerts.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Pairs table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_engineer_mentor_pairs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  mentee_engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  cadence_days int NOT NULL DEFAULT 14 CHECK (cadence_days BETWEEN 1 AND 90),
  focus_skills text[] NOT NULL DEFAULT ARRAY[]::text[],
  goal_summary text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','completed','cancelled')),
  started_on date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  target_end_on date,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT mentor_ne_mentee CHECK (mentor_engineer_id <> mentee_engineer_id)
);

CREATE INDEX IF NOT EXISTS idx_femp_mentor ON founder_engineer_mentor_pairs(mentor_engineer_id);
CREATE INDEX IF NOT EXISTS idx_femp_mentee ON founder_engineer_mentor_pairs(mentee_engineer_id);
CREATE INDEX IF NOT EXISTS idx_femp_status ON founder_engineer_mentor_pairs(status);

ALTER TABLE founder_engineer_mentor_pairs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder_only_femp" ON founder_engineer_mentor_pairs;
CREATE POLICY "founder_only_femp" ON founder_engineer_mentor_pairs
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------------------------------------------------------------------
-- 2) Sessions table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_engineer_mentor_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pair_id uuid NOT NULL REFERENCES founder_engineer_mentor_pairs(id) ON DELETE CASCADE,
  session_on date NOT NULL,
  duration_minutes int CHECK (duration_minutes BETWEEN 0 AND 600),
  skills_covered text[] NOT NULL DEFAULT ARRAY[]::text[],
  notes text,
  mentor_nps int CHECK (mentor_nps BETWEEN 0 AND 10),
  mentee_nps int CHECK (mentee_nps BETWEEN 0 AND 10),
  completed boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fems_pair ON founder_engineer_mentor_sessions(pair_id);
CREATE INDEX IF NOT EXISTS idx_fems_date ON founder_engineer_mentor_sessions(session_on DESC);

ALTER TABLE founder_engineer_mentor_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder_only_fems" ON founder_engineer_mentor_sessions;
CREATE POLICY "founder_only_fems" ON founder_engineer_mentor_sessions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------------------------------------------------------------------
-- 3) Log helpers (VOLATILE SECDEF)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_founder_mentor_pair_created(p_pair_id uuid, p_mentor uuid, p_mentee uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'mentor_pair_created',
         jsonb_build_object('pair_id', p_pair_id, 'mentor_engineer_id', p_mentor, 'mentee_engineer_id', p_mentee)
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_mentor_pair_created(uuid,uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_mentor_pair_created(uuid,uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_mentor_pair_status(p_pair_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'mentor_pair_status',
         jsonb_build_object('pair_id', p_pair_id, 'status', p_status)
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_mentor_pair_status(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_mentor_pair_status(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_mentor_session_logged(p_session_id uuid, p_pair_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'mentor_session_logged',
         jsonb_build_object('session_id', p_session_id, 'pair_id', p_pair_id)
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_mentor_session_logged(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_mentor_session_logged(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_mentor_stale_alert(p_pair_id uuid, p_days_stale numeric)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'mentor_stale_alert',
         jsonb_build_object('pair_id', p_pair_id, 'days_stale', p_days_stale)
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_mentor_stale_alert(uuid,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_mentor_stale_alert(uuid,numeric) TO authenticated;

-- ---------------------------------------------------------------------
-- 4) Read RPCs (STABLE)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION founder_mentor_pairing_kpis()
RETURNS TABLE (
  total_pairs int,
  active_pairs int,
  paused_pairs int,
  completed_pairs int,
  cancelled_pairs int,
  total_sessions int,
  sessions_last_30d int,
  avg_mentor_nps numeric,
  avg_mentee_nps numeric,
  avg_duration_minutes numeric,
  unique_mentors int,
  unique_mentees int,
  stale_pairs int,
  overdue_pairs int,
  avg_cadence_days numeric,
  total_skills_covered int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH pair_last AS (
    SELECT p.id,
           p.status,
           p.cadence_days,
           MAX(s.session_on) AS last_session_on
    FROM founder_engineer_mentor_pairs p
    LEFT JOIN founder_engineer_mentor_sessions s ON s.pair_id = p.id AND s.completed = true
    GROUP BY p.id, p.status, p.cadence_days
  )
  SELECT
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_pairs),
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_pairs WHERE status='active'),
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_pairs WHERE status='paused'),
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_pairs WHERE status='completed'),
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_pairs WHERE status='cancelled'),
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_sessions),
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_sessions WHERE session_on >= (now() - interval '30 days')::date),
    COALESCE((SELECT ROUND(AVG(mentor_nps)::numeric, 2) FROM founder_engineer_mentor_sessions WHERE mentor_nps IS NOT NULL), 0),
    COALESCE((SELECT ROUND(AVG(mentee_nps)::numeric, 2) FROM founder_engineer_mentor_sessions WHERE mentee_nps IS NOT NULL), 0),
    COALESCE((SELECT ROUND(AVG(duration_minutes)::numeric, 1) FROM founder_engineer_mentor_sessions WHERE duration_minutes IS NOT NULL), 0),
    (SELECT COUNT(DISTINCT mentor_engineer_id)::int FROM founder_engineer_mentor_pairs),
    (SELECT COUNT(DISTINCT mentee_engineer_id)::int FROM founder_engineer_mentor_pairs),
    (SELECT COUNT(*)::int FROM pair_last
       WHERE status='active'
         AND (last_session_on IS NULL OR
              EXTRACT(EPOCH FROM (now() - last_session_on::timestamptz))/86400.0 > cadence_days)),
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_pairs
       WHERE status='active' AND target_end_on IS NOT NULL AND target_end_on < (now() AT TIME ZONE 'Asia/Kolkata')::date),
    COALESCE((SELECT ROUND(AVG(cadence_days)::numeric, 1) FROM founder_engineer_mentor_pairs WHERE status='active'), 0),
    COALESCE((SELECT SUM(array_length(skills_covered,1))::int FROM founder_engineer_mentor_sessions WHERE skills_covered IS NOT NULL AND array_length(skills_covered,1) > 0), 0);
END $$;
REVOKE EXECUTE ON FUNCTION founder_mentor_pairing_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_pairing_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_mentor_pairs_list()
RETURNS TABLE (
  id uuid,
  mentor_engineer_id uuid,
  mentor_name text,
  mentor_tier text,
  mentee_engineer_id uuid,
  mentee_name text,
  mentee_tier text,
  cadence_days int,
  status text,
  focus_skills text[],
  started_on date,
  target_end_on date,
  last_session_on date,
  sessions_total int,
  days_since_last_session numeric,
  is_stale boolean,
  avg_mentor_nps numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.mentor_engineer_id,
    COALESCE(pmt.full_name, pmt.email, 'Unknown'),
    em.cached_highest_tier::text,
    p.mentee_engineer_id,
    COALESCE(pme.full_name, pme.email, 'Unknown'),
    en.cached_highest_tier::text,
    p.cadence_days,
    p.status,
    p.focus_skills,
    p.started_on,
    p.target_end_on,
    (SELECT MAX(session_on) FROM founder_engineer_mentor_sessions s WHERE s.pair_id = p.id AND s.completed = true),
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_sessions s WHERE s.pair_id = p.id AND s.completed = true),
    CASE
      WHEN (SELECT MAX(session_on) FROM founder_engineer_mentor_sessions s WHERE s.pair_id = p.id AND s.completed = true) IS NULL THEN NULL
      ELSE ROUND(EXTRACT(EPOCH FROM (now() - (SELECT MAX(session_on) FROM founder_engineer_mentor_sessions s WHERE s.pair_id = p.id AND s.completed = true)::timestamptz))/86400.0, 1)
    END,
    CASE
      WHEN p.status <> 'active' THEN false
      WHEN (SELECT MAX(session_on) FROM founder_engineer_mentor_sessions s WHERE s.pair_id = p.id AND s.completed = true) IS NULL THEN
        EXTRACT(EPOCH FROM (now() - p.started_on::timestamptz))/86400.0 > p.cadence_days
      ELSE
        EXTRACT(EPOCH FROM (now() - (SELECT MAX(session_on) FROM founder_engineer_mentor_sessions s WHERE s.pair_id = p.id AND s.completed = true)::timestamptz))/86400.0 > p.cadence_days
    END,
    COALESCE((SELECT ROUND(AVG(mentor_nps)::numeric, 2) FROM founder_engineer_mentor_sessions s WHERE s.pair_id = p.id AND s.mentor_nps IS NOT NULL), 0)
  FROM founder_engineer_mentor_pairs p
  JOIN engineers em ON em.id = p.mentor_engineer_id
  JOIN engineers en ON en.id = p.mentee_engineer_id
  LEFT JOIN profiles pmt ON pmt.id = em.user_id
  LEFT JOIN profiles pme ON pme.id = en.user_id
  ORDER BY p.status, p.started_on DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_mentor_pairs_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_pairs_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_mentor_stale_pairs()
RETURNS TABLE (
  pair_id uuid,
  mentor_name text,
  mentee_name text,
  cadence_days int,
  last_session_on date,
  days_since_last numeric,
  days_overdue numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH last_s AS (
    SELECT p.id AS pid,
           p.cadence_days,
           p.started_on,
           MAX(s.session_on) AS last_on
    FROM founder_engineer_mentor_pairs p
    LEFT JOIN founder_engineer_mentor_sessions s ON s.pair_id = p.id AND s.completed = true
    WHERE p.status = 'active'
    GROUP BY p.id, p.cadence_days, p.started_on
  )
  SELECT
    p.id,
    COALESCE(pmt.full_name, pmt.email, 'Unknown'),
    COALESCE(pme.full_name, pme.email, 'Unknown'),
    p.cadence_days,
    ls.last_on,
    CASE WHEN ls.last_on IS NULL
         THEN ROUND(EXTRACT(EPOCH FROM (now() - p.started_on::timestamptz))/86400.0, 1)
         ELSE ROUND(EXTRACT(EPOCH FROM (now() - ls.last_on::timestamptz))/86400.0, 1) END,
    CASE WHEN ls.last_on IS NULL
         THEN ROUND(EXTRACT(EPOCH FROM (now() - p.started_on::timestamptz))/86400.0 - p.cadence_days, 1)
         ELSE ROUND(EXTRACT(EPOCH FROM (now() - ls.last_on::timestamptz))/86400.0 - p.cadence_days, 1) END
  FROM founder_engineer_mentor_pairs p
  JOIN last_s ls ON ls.pid = p.id
  JOIN engineers em ON em.id = p.mentor_engineer_id
  JOIN engineers en ON en.id = p.mentee_engineer_id
  LEFT JOIN profiles pmt ON pmt.id = em.user_id
  LEFT JOIN profiles pme ON pme.id = en.user_id
  WHERE (ls.last_on IS NULL AND EXTRACT(EPOCH FROM (now() - p.started_on::timestamptz))/86400.0 > p.cadence_days)
     OR (ls.last_on IS NOT NULL AND EXTRACT(EPOCH FROM (now() - ls.last_on::timestamptz))/86400.0 > p.cadence_days)
  ORDER BY 6 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_mentor_stale_pairs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_stale_pairs() TO authenticated;

CREATE OR REPLACE FUNCTION founder_mentor_recent_sessions()
RETURNS TABLE (
  session_id uuid,
  pair_id uuid,
  session_on date,
  mentor_name text,
  mentee_name text,
  duration_minutes int,
  mentor_nps int,
  mentee_nps int,
  skills_covered text[],
  completed boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.pair_id,
    s.session_on,
    COALESCE(pmt.full_name, pmt.email, 'Unknown'),
    COALESCE(pme.full_name, pme.email, 'Unknown'),
    s.duration_minutes,
    s.mentor_nps,
    s.mentee_nps,
    s.skills_covered,
    s.completed
  FROM founder_engineer_mentor_sessions s
  JOIN founder_engineer_mentor_pairs p ON p.id = s.pair_id
  JOIN engineers em ON em.id = p.mentor_engineer_id
  JOIN engineers en ON en.id = p.mentee_engineer_id
  LEFT JOIN profiles pmt ON pmt.id = em.user_id
  LEFT JOIN profiles pme ON pme.id = en.user_id
  ORDER BY s.session_on DESC, s.created_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_mentor_recent_sessions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_recent_sessions() TO authenticated;

CREATE OR REPLACE FUNCTION founder_mentor_top_mentors()
RETURNS TABLE (
  mentor_engineer_id uuid,
  mentor_name text,
  mentor_tier text,
  active_pairs int,
  total_sessions int,
  avg_mentor_nps numeric,
  total_skills_taught int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    em.id,
    COALESCE(pmt.full_name, pmt.email, 'Unknown'),
    em.cached_highest_tier::text,
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_pairs p WHERE p.mentor_engineer_id = em.id AND p.status='active'),
    (SELECT COUNT(*)::int FROM founder_engineer_mentor_sessions s
        JOIN founder_engineer_mentor_pairs p ON p.id = s.pair_id
        WHERE p.mentor_engineer_id = em.id AND s.completed = true),
    COALESCE((SELECT ROUND(AVG(s.mentor_nps)::numeric, 2)
              FROM founder_engineer_mentor_sessions s
              JOIN founder_engineer_mentor_pairs p ON p.id = s.pair_id
              WHERE p.mentor_engineer_id = em.id AND s.mentor_nps IS NOT NULL), 0),
    COALESCE((SELECT SUM(array_length(s.skills_covered,1))::int
              FROM founder_engineer_mentor_sessions s
              JOIN founder_engineer_mentor_pairs p ON p.id = s.pair_id
              WHERE p.mentor_engineer_id = em.id AND s.skills_covered IS NOT NULL AND array_length(s.skills_covered,1) > 0), 0)
  FROM engineers em
  LEFT JOIN profiles pmt ON pmt.id = em.user_id
  WHERE em.id IN (SELECT mentor_engineer_id FROM founder_engineer_mentor_pairs)
  ORDER BY 4 DESC, 5 DESC
  LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION founder_mentor_top_mentors() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_top_mentors() TO authenticated;

-- ---------------------------------------------------------------------
-- 5) Write RPCs (VOLATILE)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION founder_mentor_pair_create(
  p_mentor_engineer_id uuid,
  p_mentee_engineer_id uuid,
  p_cadence_days int,
  p_focus_skills text[],
  p_goal_summary text,
  p_target_end_on date
)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_engineer_mentor_pairs(mentor_engineer_id, mentee_engineer_id, cadence_days, focus_skills, goal_summary, target_end_on)
  VALUES (p_mentor_engineer_id, p_mentee_engineer_id, COALESCE(p_cadence_days, 14), COALESCE(p_focus_skills, ARRAY[]::text[]), p_goal_summary, p_target_end_on)
  RETURNING id INTO v_id;
  PERFORM log_founder_mentor_pair_created(v_id, p_mentor_engineer_id, p_mentee_engineer_id);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_mentor_pair_create(uuid,uuid,int,text[],text,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_pair_create(uuid,uuid,int,text[],text,date) TO authenticated;

CREATE OR REPLACE FUNCTION founder_mentor_pair_set_status(p_pair_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('active','paused','completed','cancelled') THEN RAISE EXCEPTION 'invalid_status'; END IF;
  UPDATE founder_engineer_mentor_pairs
     SET status = p_status,
         completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
         updated_at = now()
   WHERE id = p_pair_id;
  PERFORM log_founder_mentor_pair_status(p_pair_id, p_status);
END $$;
REVOKE EXECUTE ON FUNCTION founder_mentor_pair_set_status(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_pair_set_status(uuid,text) TO authenticated;

COMMIT;