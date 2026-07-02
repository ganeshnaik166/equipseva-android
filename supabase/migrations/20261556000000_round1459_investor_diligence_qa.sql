BEGIN;

-- =========================================================================
-- r1459 — Investor Diligence Q&A Tracker
-- Capture investor due-diligence questions, answers, supporting docs,
-- status, and founder SLA response time during fundraise.
-- =========================================================================

CREATE TABLE IF NOT EXISTS investor_diligence_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_firm text,
  investor_email text,
  round_stage text NOT NULL DEFAULT 'seed' CHECK (round_stage IN ('pre_seed','seed','series_a','series_b','bridge','other')),
  category text NOT NULL DEFAULT 'general' CHECK (category IN ('financials','legal','product','market','team','customers','tech','compliance','unit_economics','cap_table','general')),
  priority text NOT NULL DEFAULT 'p2' CHECK (priority IN ('p0','p1','p2','p3')),
  question text NOT NULL,
  context_note text,
  answer text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','answered','blocked','wont_answer')),
  sla_hours integer NOT NULL DEFAULT 48,
  asked_at timestamptz NOT NULL DEFAULT now(),
  answered_at timestamptz,
  due_at timestamptz,
  supporting_doc_urls text[] DEFAULT '{}',
  internal_notes text,
  created_by uuid REFERENCES profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_idq_status ON investor_diligence_questions(status);
CREATE INDEX IF NOT EXISTS idx_idq_investor ON investor_diligence_questions(investor_name);
CREATE INDEX IF NOT EXISTS idx_idq_due ON investor_diligence_questions(due_at);
CREATE INDEX IF NOT EXISTS idx_idq_asked ON investor_diligence_questions(asked_at DESC);

ALTER TABLE investor_diligence_questions ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS investor_diligence_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid REFERENCES investor_diligence_questions(id) ON DELETE CASCADE,
  event_kind text NOT NULL CHECK (event_kind IN ('asked','answered','status_changed','priority_changed','doc_attached','reassigned','note_added','viewed','bulk_action')),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_user_id uuid REFERENCES profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ide_question ON investor_diligence_events(question_id);
CREATE INDEX IF NOT EXISTS idx_ide_kind ON investor_diligence_events(event_kind);
CREATE INDEX IF NOT EXISTS idx_ide_created ON investor_diligence_events(created_at DESC);

ALTER TABLE investor_diligence_events ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- Log helpers (VOLATILE SECDEF, is_founder gated)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_diligence_question_asked(
  p_question_id uuid,
  p_payload jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_diligence_events(question_id, event_kind, payload, actor_user_id)
  VALUES (p_question_id, 'asked', p_payload, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_diligence_question_asked(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_diligence_answer_posted(
  p_question_id uuid,
  p_payload jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_diligence_events(question_id, event_kind, payload, actor_user_id)
  VALUES (p_question_id, 'answered', p_payload, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_diligence_answer_posted(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_diligence_status_changed(
  p_question_id uuid,
  p_payload jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_diligence_events(question_id, event_kind, payload, actor_user_id)
  VALUES (p_question_id, 'status_changed', p_payload, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_diligence_status_changed(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_diligence_doc_attached(
  p_question_id uuid,
  p_payload jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_diligence_events(question_id, event_kind, payload, actor_user_id)
  VALUES (p_question_id, 'doc_attached', p_payload, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_diligence_doc_attached(uuid, jsonb) TO authenticated;

-- =========================================================================
-- 7 STABLE SECDEF read RPCs (founder console queries)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_diligence_qa_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_questions', COUNT(*),
    'open_questions', COUNT(*) FILTER (WHERE status = 'open'),
    'in_progress_questions', COUNT(*) FILTER (WHERE status = 'in_progress'),
    'answered_questions', COUNT(*) FILTER (WHERE status = 'answered'),
    'blocked_questions', COUNT(*) FILTER (WHERE status = 'blocked'),
    'overdue_questions', COUNT(*) FILTER (WHERE status NOT IN ('answered','wont_answer') AND due_at < now()),
    'p0_open', COUNT(*) FILTER (WHERE status NOT IN ('answered','wont_answer') AND priority = 'p0'),
    'p1_open', COUNT(*) FILTER (WHERE status NOT IN ('answered','wont_answer') AND priority = 'p1'),
    'investors_active', COUNT(DISTINCT investor_name) FILTER (WHERE status NOT IN ('answered','wont_answer')),
    'investors_total', COUNT(DISTINCT investor_name),
    'avg_response_hours', COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (answered_at - asked_at))/3600.0)::numeric, 1), 0),
    'p50_response_hours', COALESCE(ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (answered_at - asked_at))/3600.0)::numeric, 1), 0),
    'p90_response_hours', COALESCE(ROUND(percentile_cont(0.9) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (answered_at - asked_at))/3600.0)::numeric, 1), 0),
    'sla_met_count', COUNT(*) FILTER (WHERE answered_at IS NOT NULL AND answered_at <= due_at),
    'sla_missed_count', COUNT(*) FILTER (WHERE answered_at IS NOT NULL AND answered_at > due_at),
    'docs_attached_total', COALESCE(SUM(COALESCE(array_length(supporting_doc_urls, 1), 0)), 0),
    'asked_last_7d', COUNT(*) FILTER (WHERE asked_at > now() - interval '7 days')
  ) INTO v
  FROM investor_diligence_questions;
  RETURN v;
END $$;
GRANT EXECUTE ON FUNCTION founder_diligence_qa_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_diligence_qa_open_queue()
RETURNS TABLE(
  id uuid, investor_name text, investor_firm text, category text, priority text,
  question text, status text, asked_at timestamptz, due_at timestamptz, hours_remaining numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.investor_name, q.investor_firm, q.category, q.priority,
         q.question, q.status, q.asked_at, q.due_at,
         ROUND(EXTRACT(EPOCH FROM (q.due_at - now()))/3600.0, 1)::numeric AS hours_remaining
  FROM investor_diligence_questions q
  WHERE q.status IN ('open','in_progress','blocked')
  ORDER BY
    CASE q.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    q.due_at ASC
  LIMIT 100;
END $$;
GRANT EXECUTE ON FUNCTION founder_diligence_qa_open_queue() TO authenticated;

CREATE OR REPLACE FUNCTION founder_diligence_qa_by_investor()
RETURNS TABLE(
  id text, investor_name text, investor_firm text, total_questions bigint,
  open_questions bigint, answered_questions bigint, overdue_questions bigint,
  avg_response_hours numeric, last_activity timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    md5(q.investor_name)::text AS id,
    q.investor_name,
    MAX(q.investor_firm) AS investor_firm,
    COUNT(*)::bigint AS total_questions,
    COUNT(*) FILTER (WHERE q.status IN ('open','in_progress','blocked'))::bigint AS open_questions,
    COUNT(*) FILTER (WHERE q.status = 'answered')::bigint AS answered_questions,
    COUNT(*) FILTER (WHERE q.status NOT IN ('answered','wont_answer') AND q.due_at < now())::bigint AS overdue_questions,
    COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (q.answered_at - q.asked_at))/3600.0)::numeric, 1), 0) AS avg_response_hours,
    MAX(GREATEST(q.asked_at, COALESCE(q.answered_at, q.asked_at), q.updated_at)) AS last_activity
  FROM investor_diligence_questions q
  GROUP BY q.investor_name
  ORDER BY total_questions DESC
  LIMIT 50;
END $$;
GRANT EXECUTE ON FUNCTION founder_diligence_qa_by_investor() TO authenticated;

CREATE OR REPLACE FUNCTION founder_diligence_qa_by_category()
RETURNS TABLE(
  id text, category text, total_questions bigint, open_questions bigint,
  answered_questions bigint, avg_response_hours numeric, sla_met_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q.category::text AS id,
    q.category,
    COUNT(*)::bigint AS total_questions,
    COUNT(*) FILTER (WHERE q.status IN ('open','in_progress','blocked'))::bigint AS open_questions,
    COUNT(*) FILTER (WHERE q.status = 'answered')::bigint AS answered_questions,
    COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (q.answered_at - q.asked_at))/3600.0)::numeric, 1), 0) AS avg_response_hours,
    CASE WHEN COUNT(*) FILTER (WHERE q.answered_at IS NOT NULL) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE q.answered_at IS NOT NULL AND q.answered_at <= q.due_at)
                          / NULLIF(COUNT(*) FILTER (WHERE q.answered_at IS NOT NULL), 0), 1)::numeric
    END AS sla_met_pct
  FROM investor_diligence_questions q
  GROUP BY q.category
  ORDER BY total_questions DESC;
END $$;
GRANT EXECUTE ON FUNCTION founder_diligence_qa_by_category() TO authenticated;

CREATE OR REPLACE FUNCTION founder_diligence_qa_sla_breaches()
RETURNS TABLE(
  id uuid, investor_name text, priority text, category text, question text,
  asked_at timestamptz, due_at timestamptz, hours_overdue numeric, status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.investor_name, q.priority, q.category, q.question,
         q.asked_at, q.due_at,
         ROUND(EXTRACT(EPOCH FROM (now() - q.due_at))/3600.0, 1)::numeric AS hours_overdue,
         q.status
  FROM investor_diligence_questions q
  WHERE q.status NOT IN ('answered','wont_answer')
    AND q.due_at < now()
  ORDER BY q.due_at ASC
  LIMIT 50;
END $$;
GRANT EXECUTE ON FUNCTION founder_diligence_qa_sla_breaches() TO authenticated;

CREATE OR REPLACE FUNCTION founder_diligence_qa_recent_answered()
RETURNS TABLE(
  id uuid, investor_name text, category text, priority text, question text,
  answer text, asked_at timestamptz, answered_at timestamptz,
  response_hours numeric, sla_hours integer, sla_met boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.investor_name, q.category, q.priority, q.question, q.answer,
         q.asked_at, q.answered_at,
         ROUND(EXTRACT(EPOCH FROM (q.answered_at - q.asked_at))/3600.0, 1)::numeric AS response_hours,
         q.sla_hours,
         (q.answered_at <= q.due_at) AS sla_met
  FROM investor_diligence_questions q
  WHERE q.status = 'answered' AND q.answered_at IS NOT NULL
  ORDER BY q.answered_at DESC
  LIMIT 50;
END $$;
GRANT EXECUTE ON FUNCTION founder_diligence_qa_recent_answered() TO authenticated;

CREATE OR REPLACE FUNCTION founder_diligence_qa_event_log()
RETURNS TABLE(
  id uuid, question_id uuid, event_kind text, payload jsonb,
  actor_user_id uuid, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.question_id, e.event_kind, e.payload, e.actor_user_id, e.created_at
  FROM investor_diligence_events e
  ORDER BY e.created_at DESC
  LIMIT 100;
END $$;
GRANT EXECUTE ON FUNCTION founder_diligence_qa_event_log() TO authenticated;

COMMIT;