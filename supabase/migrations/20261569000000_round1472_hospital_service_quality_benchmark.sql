BEGIN;

-- ============================================================
-- r1472 — Hospital Service-Quality Benchmark
-- Quarterly composite score: NPS + uptime + first-response + recurrence
-- Ranks hospitals A/B/C/D; surfaces bottom-quartile for founder review.
-- ============================================================

-- 1. Score snapshots (per hospital per quarter)
CREATE TABLE IF NOT EXISTS hospital_sq_benchmark_snapshots (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  quarter_label   text NOT NULL,
  period_start    date NOT NULL,
  period_end      date NOT NULL,
  jobs_completed              int  NOT NULL DEFAULT 0,
  avg_hospital_rating         numeric(4,2),
  nps_score                   numeric(5,2),
  uptime_pct                  numeric(5,2),
  first_response_minutes_avg  numeric(8,2),
  recurrence_rate_pct         numeric(5,2),
  composite_score             numeric(5,2),
  letter_grade                text CHECK (letter_grade IN ('A','B','C','D')),
  flagged_for_review          boolean NOT NULL DEFAULT false,
  notes                       text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hospital_org_id, quarter_label)
);
CREATE INDEX IF NOT EXISTS idx_hsq_snap_quarter ON hospital_sq_benchmark_snapshots(quarter_label);
CREATE INDEX IF NOT EXISTS idx_hsq_snap_grade ON hospital_sq_benchmark_snapshots(letter_grade);
CREATE INDEX IF NOT EXISTS idx_hsq_snap_flagged ON hospital_sq_benchmark_snapshots(flagged_for_review) WHERE flagged_for_review;

ALTER TABLE hospital_sq_benchmark_snapshots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hsq_snap_founder_only ON hospital_sq_benchmark_snapshots;
CREATE POLICY hsq_snap_founder_only ON hospital_sq_benchmark_snapshots
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- 2. Review actions log (founder decisions on bottom-quartile)
CREATE TABLE IF NOT EXISTS hospital_sq_review_actions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id     uuid NOT NULL REFERENCES hospital_sq_benchmark_snapshots(id) ON DELETE CASCADE,
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  action_kind     text NOT NULL CHECK (action_kind IN ('escalate','outreach','suspend','clear','watchlist')),
  action_notes    text,
  created_by      uuid NOT NULL REFERENCES profiles(id),
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hsq_action_snapshot ON hospital_sq_review_actions(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_hsq_action_hospital ON hospital_sq_review_actions(hospital_org_id);

ALTER TABLE hospital_sq_review_actions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hsq_action_founder_only ON hospital_sq_review_actions;
CREATE POLICY hsq_action_founder_only ON hospital_sq_review_actions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

-- A) Overall KPIs
DROP FUNCTION IF EXISTS founder_hsq_overview();
CREATE OR REPLACE FUNCTION founder_hsq_overview()
RETURNS TABLE (
  total_hospitals        bigint,
  hospitals_graded       bigint,
  grade_a_count          bigint,
  grade_b_count          bigint,
  grade_c_count          bigint,
  grade_d_count          bigint,
  flagged_count          bigint,
  avg_composite_score    numeric,
  avg_nps_score          numeric,
  avg_uptime_pct         numeric,
  avg_first_response_min numeric,
  avg_recurrence_pct     numeric,
  latest_quarter         text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE q text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT MAX(quarter_label) INTO q FROM hospital_sq_benchmark_snapshots;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM organizations WHERE org_type = 'hospital')::bigint,
    (SELECT count(DISTINCT hospital_org_id) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q)::bigint,
    (SELECT count(*) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q AND letter_grade = 'A')::bigint,
    (SELECT count(*) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q AND letter_grade = 'B')::bigint,
    (SELECT count(*) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q AND letter_grade = 'C')::bigint,
    (SELECT count(*) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q AND letter_grade = 'D')::bigint,
    (SELECT count(*) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q AND flagged_for_review)::bigint,
    (SELECT round(avg(composite_score)::numeric, 2) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q),
    (SELECT round(avg(nps_score)::numeric, 2) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q),
    (SELECT round(avg(uptime_pct)::numeric, 2) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q),
    (SELECT round(avg(first_response_minutes_avg)::numeric, 2) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q),
    (SELECT round(avg(recurrence_rate_pct)::numeric, 2) FROM hospital_sq_benchmark_snapshots WHERE quarter_label = q),
    q;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hsq_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hsq_overview() TO authenticated;

-- B) Latest-quarter rankings
DROP FUNCTION IF EXISTS founder_hsq_latest_rankings();
CREATE OR REPLACE FUNCTION founder_hsq_latest_rankings()
RETURNS TABLE (
  id                uuid,
  hospital_org_id   uuid,
  hospital_name     text,
  city              text,
  quarter_label     text,
  composite_score   numeric,
  letter_grade      text,
  nps_score         numeric,
  uptime_pct        numeric,
  first_response_min numeric,
  recurrence_pct    numeric,
  jobs_completed    int,
  flagged_for_review boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE q text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT MAX(quarter_label) INTO q FROM hospital_sq_benchmark_snapshots;
  RETURN QUERY
  SELECT s.id, s.hospital_org_id, o.name, o.city, s.quarter_label,
         s.composite_score, s.letter_grade, s.nps_score, s.uptime_pct,
         s.first_response_minutes_avg, s.recurrence_rate_pct, s.jobs_completed,
         s.flagged_for_review
  FROM hospital_sq_benchmark_snapshots s
  JOIN organizations o ON o.id = s.hospital_org_id
  WHERE s.quarter_label = q
  ORDER BY s.composite_score DESC NULLS LAST
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hsq_latest_rankings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hsq_latest_rankings() TO authenticated;

-- C) Bottom-quartile (review queue)
DROP FUNCTION IF EXISTS founder_hsq_bottom_quartile();
CREATE OR REPLACE FUNCTION founder_hsq_bottom_quartile()
RETURNS TABLE (
  id                uuid,
  hospital_org_id   uuid,
  hospital_name     text,
  city              text,
  composite_score   numeric,
  letter_grade      text,
  nps_score         numeric,
  uptime_pct        numeric,
  first_response_min numeric,
  recurrence_pct    numeric,
  jobs_completed    int,
  notes             text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE q text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT MAX(quarter_label) INTO q FROM hospital_sq_benchmark_snapshots;
  RETURN QUERY
  SELECT s.id, s.hospital_org_id, o.name, o.city,
         s.composite_score, s.letter_grade, s.nps_score, s.uptime_pct,
         s.first_response_minutes_avg, s.recurrence_rate_pct, s.jobs_completed,
         s.notes
  FROM hospital_sq_benchmark_snapshots s
  JOIN organizations o ON o.id = s.hospital_org_id
  WHERE s.quarter_label = q
    AND (s.letter_grade = 'D' OR s.flagged_for_review)
  ORDER BY s.composite_score ASC NULLS LAST
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hsq_bottom_quartile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hsq_bottom_quartile() TO authenticated;

-- D) Quarter-over-quarter trend (last 6 quarters)
DROP FUNCTION IF EXISTS founder_hsq_quarterly_trend();
CREATE OR REPLACE FUNCTION founder_hsq_quarterly_trend()
RETURNS TABLE (
  quarter_label          text,
  hospitals_graded       bigint,
  avg_composite          numeric,
  avg_nps                numeric,
  avg_uptime             numeric,
  avg_first_response_min numeric,
  avg_recurrence_pct     numeric,
  grade_d_count          bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter_label,
         count(*)::bigint,
         round(avg(s.composite_score)::numeric, 2),
         round(avg(s.nps_score)::numeric, 2),
         round(avg(s.uptime_pct)::numeric, 2),
         round(avg(s.first_response_minutes_avg)::numeric, 2),
         round(avg(s.recurrence_rate_pct)::numeric, 2),
         count(*) FILTER (WHERE s.letter_grade = 'D')::bigint
  FROM hospital_sq_benchmark_snapshots s
  GROUP BY s.quarter_label
  ORDER BY s.quarter_label DESC
  LIMIT 6;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hsq_quarterly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hsq_quarterly_trend() TO authenticated;

-- E) Recent review actions
DROP FUNCTION IF EXISTS founder_hsq_recent_actions();
CREATE OR REPLACE FUNCTION founder_hsq_recent_actions()
RETURNS TABLE (
  id              uuid,
  hospital_org_id uuid,
  hospital_name   text,
  action_kind     text,
  action_notes    text,
  created_at      timestamptz,
  actor_email     text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_org_id, o.name, a.action_kind, a.action_notes,
         a.created_at, p.email
  FROM hospital_sq_review_actions a
  JOIN organizations o ON o.id = a.hospital_org_id
  LEFT JOIN profiles p ON p.id = a.created_by
  ORDER BY a.created_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hsq_recent_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hsq_recent_actions() TO authenticated;

-- ============================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================

-- F) Recompute current-quarter snapshots from live data
DROP FUNCTION IF EXISTS founder_hsq_recompute_current_quarter();
CREATE OR REPLACE FUNCTION founder_hsq_recompute_current_quarter()
RETURNS TABLE (
  hospitals_scored bigint,
  quarter_label    text
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_q text;
  v_start date;
  v_end   date;
  v_count bigint := 0;
  v_actor_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_start := date_trunc('quarter', now())::date;
  v_end   := (date_trunc('quarter', now()) + interval '3 months - 1 day')::date;
  v_q     := to_char(v_start, 'YYYY') || '-Q' || to_char(v_start, 'Q');

  WITH hosp AS (
    SELECT DISTINCT hospital_org_id
    FROM repair_jobs
    WHERE created_at >= v_start
      AND created_at <  v_start + interval '3 months'
      AND hospital_org_id IS NOT NULL
  ),
  agg AS (
    SELECT
      r.hospital_org_id,
      count(*) FILTER (WHERE r.status = 'completed')::int AS jobs_completed,
      avg(r.hospital_rating) FILTER (WHERE r.hospital_rating IS NOT NULL) AS avg_rating,
      avg(EXTRACT(EPOCH FROM (r.accepted_at - r.created_at))/60.0)
        FILTER (WHERE r.accepted_at IS NOT NULL) AS first_resp_min,
      (count(*) FILTER (WHERE r.status = 'completed' AND r.is_recurrence)::numeric
         / NULLIF(count(*) FILTER (WHERE r.status = 'completed'), 0)) * 100 AS recur_pct
    FROM repair_jobs r
    WHERE r.created_at >= v_start
      AND r.created_at <  v_start + interval '3 months'
      AND r.hospital_org_id IS NOT NULL
    GROUP BY r.hospital_org_id
  ),
  scored AS (
    SELECT
      h.hospital_org_id,
      COALESCE(a.jobs_completed, 0) AS jobs_completed,
      ROUND(COALESCE(a.avg_rating, 0)::numeric, 2) AS avg_rating,
      ROUND(((COALESCE(a.avg_rating, 0) - 3) * 50)::numeric, 2) AS nps,
      ROUND(LEAST(100, GREATEST(0, 100 - COALESCE(a.recur_pct, 0)))::numeric, 2) AS uptime,
      ROUND(COALESCE(a.first_resp_min, 0)::numeric, 2) AS resp_min,
      ROUND(COALESCE(a.recur_pct, 0)::numeric, 2) AS recur,
      ROUND((
        (COALESCE(a.avg_rating, 0) / 5.0) * 40
        + (LEAST(100, GREATEST(0, 100 - COALESCE(a.recur_pct, 0))) / 100.0) * 30
        + (GREATEST(0, 1 - LEAST(120, COALESCE(a.first_resp_min, 120)) / 120.0)) * 20
        + (GREATEST(0, 1 - LEAST(50, COALESCE(a.recur_pct, 50)) / 50.0)) * 10
      )::numeric, 2) AS composite
    FROM hosp h
    LEFT JOIN agg a USING (hospital_org_id)
  )
  INSERT INTO hospital_sq_benchmark_snapshots (
    hospital_org_id, quarter_label, period_start, period_end,
    jobs_completed, avg_hospital_rating, nps_score, uptime_pct,
    first_response_minutes_avg, recurrence_rate_pct, composite_score,
    letter_grade, flagged_for_review
  )
  SELECT
    hospital_org_id, v_q, v_start, v_end,
    jobs_completed, avg_rating, nps, uptime, resp_min, recur, composite,
    CASE
      WHEN composite >= 80 THEN 'A'
      WHEN composite >= 65 THEN 'B'
      WHEN composite >= 50 THEN 'C'
      ELSE 'D'
    END,
    (composite < 50)
  FROM scored
  ON CONFLICT (hospital_org_id, quarter_label) DO UPDATE SET
    jobs_completed = EXCLUDED.jobs_completed,
    avg_hospital_rating = EXCLUDED.avg_hospital_rating,
    nps_score = EXCLUDED.nps_score,
    uptime_pct = EXCLUDED.uptime_pct,
    first_response_minutes_avg = EXCLUDED.first_response_minutes_avg,
    recurrence_rate_pct = EXCLUDED.recurrence_rate_pct,
    composite_score = EXCLUDED.composite_score,
    letter_grade = EXCLUDED.letter_grade,
    flagged_for_review = EXCLUDED.flagged_for_review;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  SELECT email INTO v_actor_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'hsq_recompute_quarter',
    jsonb_build_object('quarter', v_q, 'hospitals_scored', v_count));

  RETURN QUERY SELECT v_count, v_q;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hsq_recompute_current_quarter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hsq_recompute_current_quarter() TO authenticated;

-- G) Log a review action on a snapshot
DROP FUNCTION IF EXISTS founder_hsq_log_review_action(uuid, text, text);
CREATE OR REPLACE FUNCTION founder_hsq_log_review_action(
  p_snapshot_id uuid,
  p_action_kind text,
  p_notes       text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id  uuid;
  v_hid uuid;
  v_actor_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_action_kind NOT IN ('escalate','outreach','suspend','clear','watchlist') THEN
    RAISE EXCEPTION 'invalid action_kind: %', p_action_kind;
  END IF;

  SELECT hospital_org_id INTO v_hid
  FROM hospital_sq_benchmark_snapshots WHERE id = p_snapshot_id;
  IF v_hid IS NULL THEN RAISE EXCEPTION 'snapshot not found'; END IF;

  INSERT INTO hospital_sq_review_actions (
    snapshot_id, hospital_org_id, action_kind, action_notes, created_by
  ) VALUES (p_snapshot_id, v_hid, p_action_kind, p_notes, auth.uid())
  RETURNING id INTO v_id;

  IF p_action_kind = 'clear' THEN
    UPDATE hospital_sq_benchmark_snapshots
       SET flagged_for_review = false
     WHERE id = p_snapshot_id;
  ELSIF p_action_kind IN ('escalate','watchlist','suspend') THEN
    UPDATE hospital_sq_benchmark_snapshots
       SET flagged_for_review = true
     WHERE id = p_snapshot_id;
  END IF;

  SELECT email INTO v_actor_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'hsq_review_action',
    jsonb_build_object('snapshot_id', p_snapshot_id, 'action_kind', p_action_kind, 'notes', p_notes));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hsq_log_review_action(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hsq_log_review_action(uuid, text, text) TO authenticated;

-- ============================================================
-- log_founder_* helpers (VOLATILE SECDEF)
-- ============================================================

DROP FUNCTION IF EXISTS log_founder_hsq_view(text);
CREATE OR REPLACE FUNCTION log_founder_hsq_view(p_view text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_actor_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT email INTO v_actor_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'hsq_view',
    jsonb_build_object('view', p_view, 'at', now()));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_hsq_view(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hsq_view(text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_hsq_export(text, int);
CREATE OR REPLACE FUNCTION log_founder_hsq_export(p_kind text, p_row_count int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_actor_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT email INTO v_actor_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'hsq_export',
    jsonb_build_object('kind', p_kind, 'rows', p_row_count));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_hsq_export(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hsq_export(text, int) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_hsq_flag_toggle(uuid, boolean);
CREATE OR REPLACE FUNCTION log_founder_hsq_flag_toggle(p_snapshot_id uuid, p_flagged boolean)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_actor_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT email INTO v_actor_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'hsq_flag_toggle',
    jsonb_build_object('snapshot_id', p_snapshot_id, 'flagged', p_flagged));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_hsq_flag_toggle(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hsq_flag_toggle(uuid, boolean) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_hsq_drilldown(uuid);
CREATE OR REPLACE FUNCTION log_founder_hsq_drilldown(p_hospital_org_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_actor_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT email INTO v_actor_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'hsq_drilldown',
    jsonb_build_object('hospital_org_id', p_hospital_org_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_hsq_drilldown(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hsq_drilldown(uuid) TO authenticated;

COMMIT;