BEGIN;

-- ============================================================================
-- r1449 Engineer 360 Feedback Collector
-- Collect feedback from hospital contacts, peer engineers, founder
-- Aggregate score, surface concerning patterns
-- ============================================================================

-- Submissions table — one row per feedback submission
CREATE TABLE IF NOT EXISTS engineer_360_feedback_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  reviewer_kind text NOT NULL CHECK (reviewer_kind IN ('hospital_contact','peer_engineer','founder')),
  reviewer_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewer_label text,
  technical_score smallint NOT NULL CHECK (technical_score BETWEEN 1 AND 5),
  communication_score smallint NOT NULL CHECK (communication_score BETWEEN 1 AND 5),
  punctuality_score smallint NOT NULL CHECK (punctuality_score BETWEEN 1 AND 5),
  professionalism_score smallint NOT NULL CHECK (professionalism_score BETWEEN 1 AND 5),
  outcome_score smallint NOT NULL CHECK (outcome_score BETWEEN 1 AND 5),
  composite_score numeric(4,2) GENERATED ALWAYS AS (
    (technical_score + communication_score + punctuality_score + professionalism_score + outcome_score)::numeric / 5.0
  ) STORED,
  concern_flag boolean NOT NULL DEFAULT false,
  concern_category text CHECK (concern_category IN ('safety','rudeness','tardiness','technical_gap','dishonesty','attire','other') OR concern_category IS NULL),
  free_text text,
  related_job_id uuid REFERENCES repair_jobs(id) ON DELETE SET NULL,
  submitted_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng360_feedback_engineer ON engineer_360_feedback_submissions(engineer_id, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_eng360_feedback_concerns ON engineer_360_feedback_submissions(engineer_id) WHERE concern_flag = true;
CREATE INDEX IF NOT EXISTS idx_eng360_feedback_kind ON engineer_360_feedback_submissions(reviewer_kind, submitted_at DESC);

ALTER TABLE engineer_360_feedback_submissions ENABLE ROW LEVEL SECURITY;

-- Audit log for founder actions on this surface
CREATE TABLE IF NOT EXISTS engineer_360_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  engineer_id uuid REFERENCES engineers(id) ON DELETE SET NULL,
  submission_id uuid REFERENCES engineer_360_feedback_submissions(id) ON DELETE SET NULL,
  payload jsonb,
  logged_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng360_audit_actor ON engineer_360_audit_log(actor_user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_eng360_audit_engineer ON engineer_360_audit_log(engineer_id, logged_at DESC);

ALTER TABLE engineer_360_audit_log ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Log helpers (VOLATILE SECDEF, founder-gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_360_view(p_engineer_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_360_audit_log(actor_user_id, action, engineer_id, payload)
  VALUES (auth.uid(), 'view_engineer', p_engineer_id, jsonb_build_object('at', now()));
END;
$$;

GRANT EXECUTE ON FUNCTION log_founder_360_view(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_360_submission_created(p_submission_id uuid, p_engineer_id uuid, p_reviewer_kind text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_360_audit_log(actor_user_id, action, engineer_id, submission_id, payload)
  VALUES (auth.uid(), 'submission_created', p_engineer_id, p_submission_id, jsonb_build_object('reviewer_kind', p_reviewer_kind));
END;
$$;

GRANT EXECUTE ON FUNCTION log_founder_360_submission_created(uuid, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_360_concern_review(p_submission_id uuid, p_decision text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_360_audit_log(actor_user_id, action, submission_id, payload)
  VALUES (auth.uid(), 'concern_reviewed', p_submission_id, jsonb_build_object('decision', p_decision));
END;
$$;

GRANT EXECUTE ON FUNCTION log_founder_360_concern_review(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_360_export(p_filter text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_360_audit_log(actor_user_id, action, payload)
  VALUES (auth.uid(), 'export', jsonb_build_object('filter', p_filter));
END;
$$;

GRANT EXECUTE ON FUNCTION log_founder_360_export(text) TO authenticated;

-- ============================================================================
-- RPC 1: Top-line KPIs (16 metrics)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_eng360_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH base AS (
    SELECT * FROM engineer_360_feedback_submissions
  ),
  last30 AS (
    SELECT * FROM base WHERE submitted_at > now() - interval '30 days'
  ),
  last90 AS (
    SELECT * FROM base WHERE submitted_at > now() - interval '90 days'
  )
  SELECT jsonb_build_object(
    'total_submissions', (SELECT count(*) FROM base),
    'submissions_30d', (SELECT count(*) FROM last30),
    'submissions_90d', (SELECT count(*) FROM last90),
    'engineers_covered', (SELECT count(DISTINCT engineer_id) FROM base),
    'engineers_covered_30d', (SELECT count(DISTINCT engineer_id) FROM last30),
    'avg_composite_all', COALESCE((SELECT round(avg(composite_score)::numeric, 2) FROM base), 0),
    'avg_composite_30d', COALESCE((SELECT round(avg(composite_score)::numeric, 2) FROM last30), 0),
    'concern_count_all', (SELECT count(*) FROM base WHERE concern_flag = true),
    'concern_count_30d', (SELECT count(*) FROM last30 WHERE concern_flag = true),
    'hospital_share_30d', COALESCE((SELECT round((100.0 * count(*) FILTER (WHERE reviewer_kind='hospital_contact'))::numeric / NULLIF(count(*),0), 1) FROM last30), 0),
    'peer_share_30d', COALESCE((SELECT round((100.0 * count(*) FILTER (WHERE reviewer_kind='peer_engineer'))::numeric / NULLIF(count(*),0), 1) FROM last30), 0),
    'founder_share_30d', COALESCE((SELECT round((100.0 * count(*) FILTER (WHERE reviewer_kind='founder'))::numeric / NULLIF(count(*),0), 1) FROM last30), 0),
    'avg_technical_30d', COALESCE((SELECT round(avg(technical_score)::numeric, 2) FROM last30), 0),
    'avg_communication_30d', COALESCE((SELECT round(avg(communication_score)::numeric, 2) FROM last30), 0),
    'avg_punctuality_30d', COALESCE((SELECT round(avg(punctuality_score)::numeric, 2) FROM last30), 0),
    'avg_outcome_30d', COALESCE((SELECT round(avg(outcome_score)::numeric, 2) FROM last30), 0)
  ) INTO v;
  RETURN v;
END;
$$;

GRANT EXECUTE ON FUNCTION founder_eng360_kpis() TO authenticated;

-- ============================================================================
-- RPC 2: Engineer leaderboard
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_eng360_leaderboard()
RETURNS TABLE (
  id uuid,
  engineer_label text,
  submissions bigint,
  hospital_submissions bigint,
  peer_submissions bigint,
  avg_composite numeric,
  avg_technical numeric,
  avg_communication numeric,
  concern_count bigint,
  last_submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, 'engineer ' || substr(e.id::text,1,6)) AS engineer_label,
    count(s.*) AS submissions,
    count(s.*) FILTER (WHERE s.reviewer_kind='hospital_contact') AS hospital_submissions,
    count(s.*) FILTER (WHERE s.reviewer_kind='peer_engineer') AS peer_submissions,
    round(avg(s.composite_score)::numeric, 2) AS avg_composite,
    round(avg(s.technical_score)::numeric, 2) AS avg_technical,
    round(avg(s.communication_score)::numeric, 2) AS avg_communication,
    count(s.*) FILTER (WHERE s.concern_flag = true) AS concern_count,
    max(s.submitted_at) AS last_submitted_at
  FROM engineers e
  LEFT JOIN engineer_360_feedback_submissions s ON s.engineer_id = e.id
  LEFT JOIN profiles p ON p.id = e.user_id
  GROUP BY e.id, p.full_name
  HAVING count(s.*) > 0
  ORDER BY avg_composite DESC NULLS LAST, submissions DESC
  LIMIT 100;
END;
$$;

GRANT EXECUTE ON FUNCTION founder_eng360_leaderboard() TO authenticated;

-- ============================================================================
-- RPC 3: Concerning patterns (engineers with multiple concerns)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_eng360_concerning_patterns()
RETURNS TABLE (
  id uuid,
  engineer_label text,
  concern_30d bigint,
  concern_90d bigint,
  dominant_category text,
  avg_composite_30d numeric,
  last_concern_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH cat AS (
    SELECT s.engineer_id, s.concern_category, count(*) c,
      row_number() OVER (PARTITION BY s.engineer_id ORDER BY count(*) DESC) rn
    FROM engineer_360_feedback_submissions s
    WHERE s.concern_flag = true AND s.submitted_at > now() - interval '90 days'
    GROUP BY s.engineer_id, s.concern_category
  )
  SELECT
    e.id,
    COALESCE(p.full_name, 'engineer ' || substr(e.id::text,1,6)),
    count(s.*) FILTER (WHERE s.submitted_at > now() - interval '30 days' AND s.concern_flag=true),
    count(s.*) FILTER (WHERE s.submitted_at > now() - interval '90 days' AND s.concern_flag=true),
    (SELECT concern_category FROM cat WHERE cat.engineer_id = e.id AND rn=1),
    round(avg(s.composite_score) FILTER (WHERE s.submitted_at > now() - interval '30 days')::numeric, 2),
    max(s.submitted_at) FILTER (WHERE s.concern_flag=true)
  FROM engineers e
  JOIN engineer_360_feedback_submissions s ON s.engineer_id = e.id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE s.concern_flag = true
  GROUP BY e.id, p.full_name
  HAVING count(s.*) FILTER (WHERE s.submitted_at > now() - interval '90 days' AND s.concern_flag=true) >= 2
  ORDER BY 3 DESC, 4 DESC
  LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION founder_eng360_concerning_patterns() TO authenticated;

-- ============================================================================
-- RPC 4: Reviewer-kind breakdown per engineer
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_eng360_reviewer_breakdown()
RETURNS TABLE (
  id uuid,
  engineer_label text,
  hospital_avg numeric,
  peer_avg numeric,
  founder_avg numeric,
  hospital_n bigint,
  peer_n bigint,
  founder_n bigint,
  spread numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, 'engineer ' || substr(e.id::text,1,6)),
    round(avg(s.composite_score) FILTER (WHERE s.reviewer_kind='hospital_contact')::numeric, 2),
    round(avg(s.composite_score) FILTER (WHERE s.reviewer_kind='peer_engineer')::numeric, 2),
    round(avg(s.composite_score) FILTER (WHERE s.reviewer_kind='founder')::numeric, 2),
    count(s.*) FILTER (WHERE s.reviewer_kind='hospital_contact'),
    count(s.*) FILTER (WHERE s.reviewer_kind='peer_engineer'),
    count(s.*) FILTER (WHERE s.reviewer_kind='founder'),
    round((COALESCE(max(s.composite_score),0) - COALESCE(min(s.composite_score),0))::numeric, 2)
  FROM engineers e
  JOIN engineer_360_feedback_submissions s ON s.engineer_id = e.id
  LEFT JOIN profiles p ON p.id = e.user_id
  GROUP BY e.id, p.full_name
  HAVING count(s.*) >= 3
  ORDER BY spread DESC NULLS LAST
  LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION founder_eng360_reviewer_breakdown() TO authenticated;

-- ============================================================================
-- RPC 5: Recent submissions feed
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_eng360_recent_feed()
RETURNS TABLE (
  id uuid,
  engineer_label text,
  reviewer_kind text,
  reviewer_label text,
  composite_score numeric,
  concern_flag boolean,
  concern_category text,
  snippet text,
  submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    COALESCE(p.full_name, 'engineer ' || substr(e.id::text,1,6)),
    s.reviewer_kind,
    COALESCE(s.reviewer_label, '—'),
    s.composite_score,
    s.concern_flag,
    s.concern_category,
    LEFT(COALESCE(s.free_text, ''), 140),
    s.submitted_at
  FROM engineer_360_feedback_submissions s
  JOIN engineers e ON e.id = s.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY s.submitted_at DESC
  LIMIT 100;
END;
$$;

GRANT EXECUTE ON FUNCTION founder_eng360_recent_feed() TO authenticated;

-- ============================================================================
-- RPC 6: Coverage gaps — engineers w/ active jobs but few/no submissions
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_eng360_coverage_gaps()
RETURNS TABLE (
  id uuid,
  engineer_label text,
  jobs_90d bigint,
  submissions_90d bigint,
  last_submission timestamptz,
  days_since_submission integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, 'engineer ' || substr(e.id::text,1,6)),
    count(DISTINCT j.id) FILTER (WHERE j.created_at > now() - interval '90 days'),
    count(DISTINCT s.id) FILTER (WHERE s.submitted_at > now() - interval '90 days'),
    max(s.submitted_at),
    CASE WHEN max(s.submitted_at) IS NULL THEN NULL
         ELSE EXTRACT(day FROM now() - max(s.submitted_at))::integer END
  FROM engineers e
  LEFT JOIN repair_jobs j ON j.engineer_id = e.id
  LEFT JOIN engineer_360_feedback_submissions s ON s.engineer_id = e.id
  LEFT JOIN profiles p ON p.id = e.user_id
  GROUP BY e.id, p.full_name
  HAVING count(DISTINCT j.id) FILTER (WHERE j.created_at > now() - interval '90 days') >= 3
     AND count(DISTINCT s.id) FILTER (WHERE s.submitted_at > now() - interval '90 days') <= 1
  ORDER BY 3 DESC
  LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION founder_eng360_coverage_gaps() TO authenticated;

-- ============================================================================
-- RPC 7: Submit feedback (founder write-layer)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_eng360_submit(
  p_engineer_id uuid,
  p_reviewer_kind text,
  p_reviewer_label text,
  p_technical smallint,
  p_communication smallint,
  p_punctuality smallint,
  p_professionalism smallint,
  p_outcome smallint,
  p_concern_flag boolean,
  p_concern_category text,
  p_free_text text
)
RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_360_feedback_submissions(
    engineer_id, reviewer_kind, reviewer_user_id, reviewer_label,
    technical_score, communication_score, punctuality_score,
    professionalism_score, outcome_score,
    concern_flag, concern_category, free_text
  ) VALUES (
    p_engineer_id, p_reviewer_kind, auth.uid(), p_reviewer_label,
    p_technical, p_communication, p_punctuality, p_professionalism, p_outcome,
    COALESCE(p_concern_flag, false), p_concern_category, p_free_text
  ) RETURNING id INTO v_id;
  PERFORM log_founder_360_submission_created(v_id, p_engineer_id, p_reviewer_kind);
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION founder_eng360_submit(uuid, text, text, smallint, smallint, smallint, smallint, smallint, boolean, text, text) TO authenticated;

COMMIT;