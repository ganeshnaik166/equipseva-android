BEGIN;

-- Round 1504: Founder Weekly Top-3 Priorities
-- Monday declaration of top-3 priorities with measurable outcomes,
-- per-priority owner + blocker tracking, Friday hit/miss review.

CREATE TABLE IF NOT EXISTS founder_weekly_top_3 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start_date date NOT NULL,
  slot smallint NOT NULL CHECK (slot IN (1,2,3)),
  title text NOT NULL,
  measurable_outcome text NOT NULL,
  owner_user_id uuid REFERENCES profiles(id),
  owner_label text,
  declared_at timestamptz NOT NULL DEFAULT now(),
  declared_by uuid REFERENCES profiles(id),
  review_status text NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending','hit','miss','partial','dropped')),
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (week_start_date, slot)
);

CREATE INDEX IF NOT EXISTS idx_fwt3_week ON founder_weekly_top_3(week_start_date DESC);
CREATE INDEX IF NOT EXISTS idx_fwt3_owner ON founder_weekly_top_3(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_fwt3_status ON founder_weekly_top_3(review_status);

ALTER TABLE founder_weekly_top_3 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fwt3_founder_only ON founder_weekly_top_3;
CREATE POLICY fwt3_founder_only ON founder_weekly_top_3
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_weekly_top_3_blockers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  priority_id uuid NOT NULL REFERENCES founder_weekly_top_3(id) ON DELETE CASCADE,
  blocker_text text NOT NULL,
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  raised_at timestamptz NOT NULL DEFAULT now(),
  raised_by uuid REFERENCES profiles(id),
  resolved_at timestamptz,
  resolution_note text
);

CREATE INDEX IF NOT EXISTS idx_fwt3_blockers_pri ON founder_weekly_top_3_blockers(priority_id);
CREATE INDEX IF NOT EXISTS idx_fwt3_blockers_open ON founder_weekly_top_3_blockers(resolved_at) WHERE resolved_at IS NULL;

ALTER TABLE founder_weekly_top_3_blockers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fwt3_blockers_founder_only ON founder_weekly_top_3_blockers;
CREATE POLICY fwt3_blockers_founder_only ON founder_weekly_top_3_blockers
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- log helpers
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_fwt3_declared(
  p_priority_id uuid, p_week date, p_slot int, p_title text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(),
          (SELECT email FROM profiles WHERE id = auth.uid()),
          'fwt3.declared',
          jsonb_build_object('priority_id', p_priority_id, 'week', p_week, 'slot', p_slot, 'title', p_title));
END; $$;

CREATE OR REPLACE FUNCTION log_founder_fwt3_reviewed(
  p_priority_id uuid, p_status text, p_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(),
          (SELECT email FROM profiles WHERE id = auth.uid()),
          'fwt3.reviewed',
          jsonb_build_object('priority_id', p_priority_id, 'status', p_status, 'note', p_note));
END; $$;

CREATE OR REPLACE FUNCTION log_founder_fwt3_blocker_raised(
  p_blocker_id uuid, p_priority_id uuid, p_severity text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(),
          (SELECT email FROM profiles WHERE id = auth.uid()),
          'fwt3.blocker_raised',
          jsonb_build_object('blocker_id', p_blocker_id, 'priority_id', p_priority_id, 'severity', p_severity));
END; $$;

CREATE OR REPLACE FUNCTION log_founder_fwt3_blocker_resolved(
  p_blocker_id uuid, p_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(),
          (SELECT email FROM profiles WHERE id = auth.uid()),
          'fwt3.blocker_resolved',
          jsonb_build_object('blocker_id', p_blocker_id, 'note', p_note));
END; $$;

-- ============================================================
-- read RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION fwt3_current_week()
RETURNS TABLE (
  id uuid, week_start_date date, slot smallint, title text,
  measurable_outcome text, owner_label text, review_status text,
  declared_at timestamptz, open_blocker_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.week_start_date, p.slot, p.title, p.measurable_outcome,
         COALESCE(p.owner_label, (SELECT email FROM profiles WHERE id = p.owner_user_id)),
         p.review_status, p.declared_at,
         (SELECT COUNT(*) FROM founder_weekly_top_3_blockers b
            WHERE b.priority_id = p.id AND b.resolved_at IS NULL)
  FROM founder_weekly_top_3 p
  WHERE p.week_start_date = date_trunc('week', CURRENT_DATE)::date
  ORDER BY p.slot;
END; $$;

CREATE OR REPLACE FUNCTION fwt3_recent_weeks(p_limit int DEFAULT 12)
RETURNS TABLE (
  week_start_date date, total int, hit int, miss int, partial int, dropped int, pending int,
  hit_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.week_start_date,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE p.review_status = 'hit')::int,
         COUNT(*) FILTER (WHERE p.review_status = 'miss')::int,
         COUNT(*) FILTER (WHERE p.review_status = 'partial')::int,
         COUNT(*) FILTER (WHERE p.review_status = 'dropped')::int,
         COUNT(*) FILTER (WHERE p.review_status = 'pending')::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE p.review_status = 'hit') / NULLIF(COUNT(*),0), 1)
  FROM founder_weekly_top_3 p
  GROUP BY p.week_start_date
  ORDER BY p.week_start_date DESC
  LIMIT p_limit;
END; $$;

CREATE OR REPLACE FUNCTION fwt3_open_blockers()
RETURNS TABLE (
  blocker_id uuid, priority_id uuid, priority_title text, week_start_date date,
  blocker_text text, severity text, raised_at timestamptz, age_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.priority_id, p.title, p.week_start_date,
         b.blocker_text, b.severity, b.raised_at,
         ROUND((EXTRACT(EPOCH FROM (now() - b.raised_at))/86400.0)::numeric, 1)
  FROM founder_weekly_top_3_blockers b
  JOIN founder_weekly_top_3 p ON p.id = b.priority_id
  WHERE b.resolved_at IS NULL
  ORDER BY CASE b.severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
           b.raised_at;
END; $$;

CREATE OR REPLACE FUNCTION fwt3_owner_scoreboard()
RETURNS TABLE (
  owner_label text, total_assigned int, hit int, miss int, hit_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(p.owner_label, (SELECT email FROM profiles WHERE id = p.owner_user_id), 'unassigned'),
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE p.review_status = 'hit')::int,
         COUNT(*) FILTER (WHERE p.review_status = 'miss')::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE p.review_status = 'hit') / NULLIF(COUNT(*),0), 1)
  FROM founder_weekly_top_3 p
  WHERE p.review_status IN ('hit','miss','partial')
  GROUP BY 1
  ORDER BY 5 DESC NULLS LAST, 2 DESC;
END; $$;

-- ============================================================
-- write RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION fwt3_declare_priority(
  p_week date, p_slot int, p_title text, p_outcome text,
  p_owner_user_id uuid, p_owner_label text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_slot NOT IN (1,2,3) THEN RAISE EXCEPTION 'slot must be 1,2,3'; END IF;
  INSERT INTO founder_weekly_top_3(week_start_date, slot, title, measurable_outcome,
                                   owner_user_id, owner_label, declared_by)
  VALUES (p_week, p_slot, p_title, p_outcome, p_owner_user_id, p_owner_label, auth.uid())
  RETURNING id INTO v_id;
  PERFORM log_founder_fwt3_declared(v_id, p_week, p_slot, p_title);
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION fwt3_review_priority(
  p_priority_id uuid, p_status text, p_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('hit','miss','partial','dropped') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;
  UPDATE founder_weekly_top_3
     SET review_status = p_status, review_note = p_note, reviewed_at = now()
   WHERE id = p_priority_id;
  PERFORM log_founder_fwt3_reviewed(p_priority_id, p_status, p_note);
END; $$;

CREATE OR REPLACE FUNCTION fwt3_raise_blocker(
  p_priority_id uuid, p_text text, p_severity text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_weekly_top_3_blockers(priority_id, blocker_text, severity, raised_by)
  VALUES (p_priority_id, p_text, COALESCE(p_severity,'medium'), auth.uid())
  RETURNING id INTO v_id;
  PERFORM log_founder_fwt3_blocker_raised(v_id, p_priority_id, COALESCE(p_severity,'medium'));
  RETURN v_id;
END; $$;

-- ============================================================
-- grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION fwt3_current_week()        FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fwt3_recent_weeks(int)     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fwt3_open_blockers()       FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fwt3_owner_scoreboard()    FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fwt3_declare_priority(date,int,text,text,uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fwt3_review_priority(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fwt3_raise_blocker(uuid,text,text)   FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION fwt3_current_week()        TO authenticated;
GRANT EXECUTE ON FUNCTION fwt3_recent_weeks(int)     TO authenticated;
GRANT EXECUTE ON FUNCTION fwt3_open_blockers()       TO authenticated;
GRANT EXECUTE ON FUNCTION fwt3_owner_scoreboard()    TO authenticated;
GRANT EXECUTE ON FUNCTION fwt3_declare_priority(date,int,text,text,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION fwt3_review_priority(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION fwt3_raise_blocker(uuid,text,text)   TO authenticated;

COMMIT;