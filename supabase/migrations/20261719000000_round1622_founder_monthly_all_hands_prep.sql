BEGIN;

-- ============================================================================
-- Round 1622: Founder Monthly All-Hands Prep
-- ----------------------------------------------------------------------------
-- Monthly all-hands meeting agenda + slides + Q&A log + attendance.
-- Founder reviews what shipped + asks team for input.
-- ============================================================================

-- ---------- Tables ----------------------------------------------------------

CREATE TABLE IF NOT EXISTS founder_all_hands_meetings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_month date NOT NULL,                       -- first day of month
  title text NOT NULL,
  agenda_md text,
  slides_url text,
  recap_md text,
  status text NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','in_progress','completed','cancelled')),
  scheduled_at timestamptz,
  completed_at timestamptz,
  attendee_count int NOT NULL DEFAULT 0,
  question_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (meeting_month)
);

CREATE TABLE IF NOT EXISTS founder_all_hands_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES founder_all_hands_meetings(id) ON DELETE CASCADE,
  asker_user_id uuid REFERENCES auth.users(id),
  asker_email text,
  question_text text NOT NULL,
  answer_text text,
  category text NOT NULL DEFAULT 'general'
    CHECK (category IN ('general','product','ops','finance','people','strategy')),
  upvotes int NOT NULL DEFAULT 0,
  is_answered boolean NOT NULL DEFAULT false,
  answered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fahm_month ON founder_all_hands_meetings(meeting_month DESC);
CREATE INDEX IF NOT EXISTS idx_fahq_meeting ON founder_all_hands_questions(meeting_id, created_at DESC);

ALTER TABLE founder_all_hands_meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_all_hands_questions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fahm_founder_only ON founder_all_hands_meetings;
CREATE POLICY fahm_founder_only ON founder_all_hands_meetings
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS fahq_founder_only ON founder_all_hands_questions;
CREATE POLICY fahq_founder_only ON founder_all_hands_questions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- Helpers (VOLATILE SECDEF) ---------------------------------------

CREATE OR REPLACE FUNCTION log_founder_all_hands_create(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'all_hands_create', p_after, now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_all_hands_create(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_all_hands_create(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_all_hands_update(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'all_hands_update', p_after, now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_all_hands_update(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_all_hands_update(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_all_hands_question(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'all_hands_question', p_after, now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_all_hands_question(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_all_hands_question(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_all_hands_answer(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'all_hands_answer', p_after, now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_all_hands_answer(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_all_hands_answer(jsonb) TO authenticated;

-- ---------- Read RPCs (STABLE) ----------------------------------------------

CREATE OR REPLACE FUNCTION founder_all_hands_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := now();
  v_month_start date := date_trunc('month', v_now)::date;
  v_prev_start date := (date_trunc('month', v_now) - interval '1 month')::date;
  v_result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH
  meetings AS (
    SELECT
      count(*) FILTER (WHERE status='completed') AS completed_meetings,
      count(*) FILTER (WHERE status='planned') AS planned_meetings,
      count(*) FILTER (WHERE status='in_progress') AS in_progress_meetings,
      count(*) FILTER (WHERE meeting_month = v_month_start) AS this_month_meetings,
      count(*) FILTER (WHERE meeting_month = v_prev_start) AS prev_month_meetings,
      coalesce(sum(attendee_count),0) AS total_attendees,
      coalesce(sum(question_count),0) AS total_questions,
      count(*) AS total_meetings
    FROM founder_all_hands_meetings
  ),
  questions AS (
    SELECT
      count(*) FILTER (WHERE is_answered) AS answered_q,
      count(*) FILTER (WHERE NOT is_answered) AS open_q,
      count(*) FILTER (WHERE created_at >= v_now - interval '30 days') AS q_30d,
      count(DISTINCT category) AS distinct_categories,
      count(*) AS total_q
    FROM founder_all_hands_questions
  ),
  ships AS (
    SELECT count(*) AS ships_30d
    FROM founder_action_log
    WHERE created_at >= v_now - interval '30 days'
  ),
  next_meeting AS (
    SELECT min(scheduled_at) AS next_at
    FROM founder_all_hands_meetings
    WHERE status IN ('planned','in_progress') AND scheduled_at >= v_now
  ),
  last_meeting AS (
    SELECT max(completed_at) AS last_at
    FROM founder_all_hands_meetings
    WHERE status='completed'
  )
  SELECT jsonb_build_object(
    'total_meetings', m.total_meetings,
    'completed_meetings', m.completed_meetings,
    'planned_meetings', m.planned_meetings,
    'in_progress_meetings', m.in_progress_meetings,
    'this_month_meetings', m.this_month_meetings,
    'prev_month_meetings', m.prev_month_meetings,
    'total_attendees', m.total_attendees,
    'total_questions', m.total_questions,
    'answered_q', q.answered_q,
    'open_q', q.open_q,
    'q_30d', q.q_30d,
    'distinct_categories', q.distinct_categories,
    'ships_30d', s.ships_30d,
    'next_meeting_at', nm.next_at,
    'last_meeting_at', lm.last_at,
    'avg_attendees_per_meeting',
      CASE WHEN m.completed_meetings > 0
           THEN round((m.total_attendees::numeric / m.completed_meetings)::numeric, 1)
           ELSE 0 END
  )
  INTO v_result
  FROM meetings m, questions q, ships s, next_meeting nm, last_meeting lm;

  RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_all_hands_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_all_hands_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_all_hands_list_meetings()
RETURNS TABLE (
  id uuid,
  meeting_month date,
  title text,
  status text,
  scheduled_at timestamptz,
  completed_at timestamptz,
  attendee_count int,
  question_count int,
  has_slides boolean,
  has_recap boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.id,
    m.meeting_month,
    m.title,
    m.status,
    m.scheduled_at,
    m.completed_at,
    m.attendee_count,
    m.question_count,
    (m.slides_url IS NOT NULL AND length(m.slides_url) > 0) AS has_slides,
    (m.recap_md IS NOT NULL AND length(m.recap_md) > 0) AS has_recap
  FROM founder_all_hands_meetings m
  ORDER BY m.meeting_month DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_all_hands_list_meetings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_all_hands_list_meetings() TO authenticated;

CREATE OR REPLACE FUNCTION founder_all_hands_recent_questions()
RETURNS TABLE (
  id uuid,
  meeting_id uuid,
  meeting_title text,
  asker_email text,
  question_text text,
  category text,
  upvotes int,
  is_answered boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q.id,
    q.meeting_id,
    m.title AS meeting_title,
    q.asker_email,
    q.question_text,
    q.category,
    q.upvotes,
    q.is_answered,
    q.created_at
  FROM founder_all_hands_questions q
  JOIN founder_all_hands_meetings m ON m.id = q.meeting_id
  ORDER BY q.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_all_hands_recent_questions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_all_hands_recent_questions() TO authenticated;

CREATE OR REPLACE FUNCTION founder_all_hands_category_breakdown()
RETURNS TABLE (
  category text,
  total_q bigint,
  answered_q bigint,
  open_q bigint,
  avg_upvotes numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q.category,
    count(*) AS total_q,
    count(*) FILTER (WHERE q.is_answered) AS answered_q,
    count(*) FILTER (WHERE NOT q.is_answered) AS open_q,
    round(coalesce(avg(q.upvotes),0)::numeric, 1) AS avg_upvotes
  FROM founder_all_hands_questions q
  GROUP BY q.category
  ORDER BY total_q DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_all_hands_category_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_all_hands_category_breakdown() TO authenticated;

CREATE OR REPLACE FUNCTION founder_all_hands_ships_this_month()
RETURNS TABLE (
  op_name text,
  ship_count bigint,
  last_ship_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.op_name,
    count(*) AS ship_count,
    max(l.created_at) AS last_ship_at
  FROM founder_action_log l
  WHERE l.created_at >= date_trunc('month', now())
  GROUP BY l.op_name
  ORDER BY ship_count DESC
  LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_all_hands_ships_this_month() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_all_hands_ships_this_month() TO authenticated;

-- ---------- Write RPCs (VOLATILE) -------------------------------------------

CREATE OR REPLACE FUNCTION founder_all_hands_create_meeting(
  p_meeting_month date,
  p_title text,
  p_agenda_md text DEFAULT NULL,
  p_scheduled_at timestamptz DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_all_hands_meetings(meeting_month, title, agenda_md, scheduled_at, status)
  VALUES (date_trunc('month', p_meeting_month)::date, p_title, p_agenda_md, p_scheduled_at, 'planned')
  RETURNING id INTO v_id;

  PERFORM log_founder_all_hands_create(jsonb_build_object(
    'meeting_id', v_id,
    'meeting_month', p_meeting_month,
    'title', p_title
  ));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_all_hands_create_meeting(date, text, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_all_hands_create_meeting(date, text, text, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION founder_all_hands_complete_meeting(
  p_meeting_id uuid,
  p_attendee_count int,
  p_recap_md text DEFAULT NULL,
  p_slides_url text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_all_hands_meetings
  SET status='completed',
      completed_at = now(),
      attendee_count = greatest(0, p_attendee_count),
      recap_md = coalesce(p_recap_md, recap_md),
      slides_url = coalesce(p_slides_url, slides_url),
      updated_at = now()
  WHERE id = p_meeting_id;

  PERFORM log_founder_all_hands_update(jsonb_build_object(
    'meeting_id', p_meeting_id,
    'attendee_count', p_attendee_count,
    'completed', true
  ));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_all_hands_complete_meeting(uuid, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_all_hands_complete_meeting(uuid, int, text, text) TO authenticated;

COMMIT;