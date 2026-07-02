BEGIN;

-- =====================================================================
-- r1619 — Founder Engineer Exit Interview Log
-- =====================================================================
-- when engineer leave, founder/HR do exit interview. record reason,
-- sentiment, would-rejoin score. aggregate pattern for retention strategy.
-- =====================================================================

-- ---------- table 1: exit interviews -------------------------------
CREATE TABLE IF NOT EXISTS founder_engineer_exit_interviews_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL,
  interviewer_user_id uuid NOT NULL,
  interview_date timestamptz NOT NULL DEFAULT now(),
  primary_reason text NOT NULL CHECK (primary_reason IN (
    'pay_too_low','schedule_conflict','health','relocation',
    'family','better_offer','dissatisfaction','platform_friction',
    'career_change','retirement','other'
  )),
  secondary_reason text,
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','negative','very_negative')),
  would_rejoin_score smallint NOT NULL CHECK (would_rejoin_score BETWEEN 0 AND 10),
  nps_score smallint CHECK (nps_score BETWEEN -100 AND 100),
  pay_satisfaction smallint CHECK (pay_satisfaction BETWEEN 1 AND 5),
  support_satisfaction smallint CHECK (support_satisfaction BETWEEN 1 AND 5),
  app_satisfaction smallint CHECK (app_satisfaction BETWEEN 1 AND 5),
  freeform_notes text,
  improvements_suggested text,
  tenure_days integer NOT NULL DEFAULT 0,
  total_jobs_completed integer NOT NULL DEFAULT 0,
  total_earnings_rupees integer NOT NULL DEFAULT 0,
  last_active_at timestamptz,
  exit_status text NOT NULL DEFAULT 'pending_followup' CHECK (exit_status IN ('pending_followup','closed','rejoin_attempted','rejoined')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_exit_iv_v2_engineer ON founder_engineer_exit_interviews_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_exit_iv_v2_date ON founder_engineer_exit_interviews_v2(interview_date DESC);
CREATE INDEX IF NOT EXISTS idx_exit_iv_v2_reason ON founder_engineer_exit_interviews_v2(primary_reason);
CREATE INDEX IF NOT EXISTS idx_exit_iv_v2_sentiment ON founder_engineer_exit_interviews_v2(sentiment);

ALTER TABLE founder_engineer_exit_interviews_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS exit_iv_v2_founder_all ON founder_engineer_exit_interviews_v2;
CREATE POLICY exit_iv_v2_founder_all ON founder_engineer_exit_interviews_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- table 2: retention insight patterns --------------------
CREATE TABLE IF NOT EXISTS founder_engineer_exit_patterns_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pattern_window text NOT NULL,
  pattern_key text NOT NULL,
  pattern_value text NOT NULL,
  exit_count integer NOT NULL DEFAULT 0,
  avg_would_rejoin numeric(4,2),
  avg_tenure_days numeric(8,1),
  recommended_action text,
  computed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pattern_window, pattern_key, pattern_value)
);

CREATE INDEX IF NOT EXISTS idx_exit_patt_v2_window ON founder_engineer_exit_patterns_v2(pattern_window, computed_at DESC);

ALTER TABLE founder_engineer_exit_patterns_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS exit_patt_v2_founder_all ON founder_engineer_exit_patterns_v2;
CREATE POLICY exit_patt_v2_founder_all ON founder_engineer_exit_patterns_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ====================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- ====================================================================

CREATE OR REPLACE FUNCTION log_founder_exit_iv_create(p_interview_id uuid, p_engineer_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'exit_iv_create',
    jsonb_build_object('interview_id', p_interview_id, 'engineer_id', p_engineer_id, 'reason', p_reason),
    now()
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_exit_iv_create(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_exit_iv_create(uuid, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_exit_iv_update(p_interview_id uuid, p_field text, p_new_value text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'exit_iv_update',
    jsonb_build_object('interview_id', p_interview_id, 'field', p_field, 'value', p_new_value),
    now()
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_exit_iv_update(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_exit_iv_update(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_exit_pattern_refresh(p_window text, p_count integer)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'exit_pattern_refresh',
    jsonb_build_object('window', p_window, 'count', p_count),
    now()
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_exit_pattern_refresh(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_exit_pattern_refresh(text, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_exit_rejoin_attempt(p_interview_id uuid, p_outcome text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'exit_rejoin_attempt',
    jsonb_build_object('interview_id', p_interview_id, 'outcome', p_outcome),
    now()
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_exit_rejoin_attempt(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_exit_rejoin_attempt(uuid, text) TO authenticated;

-- ====================================================================
-- READ RPCs (STABLE SECDEF)
-- ====================================================================

-- 1) overview KPIs
CREATE OR REPLACE FUNCTION rpc_founder_exit_iv_overview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH base AS (
    SELECT * FROM founder_engineer_exit_interviews_v2
  ),
  totals AS (
    SELECT
      COUNT(*)::int AS total_interviews,
      COUNT(*) FILTER (WHERE interview_date >= now() - interval '30 days')::int AS last_30d,
      COUNT(*) FILTER (WHERE interview_date >= now() - interval '90 days')::int AS last_90d,
      COUNT(*) FILTER (WHERE exit_status = 'pending_followup')::int AS pending_followup,
      COUNT(*) FILTER (WHERE exit_status = 'rejoined')::int AS rejoined,
      COUNT(*) FILTER (WHERE exit_status = 'rejoin_attempted')::int AS rejoin_attempted,
      ROUND(AVG(would_rejoin_score)::numeric, 2) AS avg_rejoin_score,
      ROUND(AVG(NULLIF(nps_score, NULL))::numeric, 1) AS avg_nps,
      ROUND(AVG(tenure_days)::numeric, 1) AS avg_tenure,
      ROUND(AVG(pay_satisfaction)::numeric, 2) AS avg_pay_sat,
      ROUND(AVG(support_satisfaction)::numeric, 2) AS avg_support_sat,
      ROUND(AVG(app_satisfaction)::numeric, 2) AS avg_app_sat,
      COUNT(*) FILTER (WHERE sentiment IN ('negative','very_negative'))::int AS negative_sentiment,
      COUNT(*) FILTER (WHERE sentiment = 'positive')::int AS positive_sentiment,
      COUNT(*) FILTER (WHERE would_rejoin_score >= 7)::int AS high_rejoin_promoters,
      COUNT(*) FILTER (WHERE primary_reason = 'pay_too_low')::int AS pay_reason_count
    FROM base
  )
  SELECT to_jsonb(totals.*) INTO v_result FROM totals;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_exit_iv_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exit_iv_overview() TO authenticated;

-- 2) list interviews
CREATE OR REPLACE FUNCTION rpc_founder_exit_iv_list(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  interview_date timestamptz,
  primary_reason text,
  sentiment text,
  would_rejoin_score smallint,
  tenure_days integer,
  total_jobs_completed integer,
  total_earnings_rupees integer,
  exit_status text
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
    iv.id,
    iv.engineer_id,
    COALESCE(p.full_name, 'unknown')::text AS engineer_name,
    iv.interview_date,
    iv.primary_reason,
    iv.sentiment,
    iv.would_rejoin_score,
    iv.tenure_days,
    iv.total_jobs_completed,
    iv.total_earnings_rupees,
    iv.exit_status
  FROM founder_engineer_exit_interviews_v2 iv
  LEFT JOIN profiles p ON p.id = iv.engineer_user_id
  ORDER BY iv.interview_date DESC
  LIMIT GREATEST(COALESCE(p_limit, 50), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_exit_iv_list(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exit_iv_list(integer) TO authenticated;

-- 3) reason breakdown
CREATE OR REPLACE FUNCTION rpc_founder_exit_iv_by_reason()
RETURNS TABLE (
  primary_reason text,
  exit_count integer,
  avg_would_rejoin numeric,
  avg_tenure numeric,
  pct_negative numeric
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
    iv.primary_reason,
    COUNT(*)::int AS exit_count,
    ROUND(AVG(iv.would_rejoin_score)::numeric, 2) AS avg_would_rejoin,
    ROUND(AVG(iv.tenure_days)::numeric, 1) AS avg_tenure,
    ROUND((COUNT(*) FILTER (WHERE iv.sentiment IN ('negative','very_negative'))::numeric * 100.0 / NULLIF(COUNT(*),0)), 1) AS pct_negative
  FROM founder_engineer_exit_interviews_v2 iv
  GROUP BY iv.primary_reason
  ORDER BY exit_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_exit_iv_by_reason() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exit_iv_by_reason() TO authenticated;

-- 4) tenure buckets
CREATE OR REPLACE FUNCTION rpc_founder_exit_iv_tenure_buckets()
RETURNS TABLE (
  bucket text,
  exit_count integer,
  avg_would_rejoin numeric,
  top_reason text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH bucketed AS (
    SELECT
      CASE
        WHEN iv.tenure_days < 30 THEN '0-30d'
        WHEN iv.tenure_days < 90 THEN '30-90d'
        WHEN iv.tenure_days < 180 THEN '90-180d'
        WHEN iv.tenure_days < 365 THEN '180-365d'
        ELSE '365d+'
      END AS bucket_label,
      iv.would_rejoin_score,
      iv.primary_reason
    FROM founder_engineer_exit_interviews_v2 iv
  ),
  agg AS (
    SELECT
      bucket_label,
      COUNT(*)::int AS cnt,
      ROUND(AVG(would_rejoin_score)::numeric, 2) AS avg_rj
    FROM bucketed
    GROUP BY bucket_label
  ),
  top_reason_per AS (
    SELECT DISTINCT ON (bucket_label) bucket_label, primary_reason
    FROM bucketed
    GROUP BY bucket_label, primary_reason
    ORDER BY bucket_label, COUNT(*) DESC
  )
  SELECT
    a.bucket_label,
    a.cnt,
    a.avg_rj,
    COALESCE(tr.primary_reason, 'n/a')::text
  FROM agg a
  LEFT JOIN top_reason_per tr ON tr.bucket_label = a.bucket_label
  ORDER BY a.cnt DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_exit_iv_tenure_buckets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exit_iv_tenure_buckets() TO authenticated;

-- 5) sentiment distribution
CREATE OR REPLACE FUNCTION rpc_founder_exit_iv_sentiment()
RETURNS TABLE (
  sentiment text,
  count_total integer,
  avg_rejoin numeric,
  pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*) INTO v_total FROM founder_engineer_exit_interviews_v2;

  RETURN QUERY
  SELECT
    iv.sentiment,
    COUNT(*)::int,
    ROUND(AVG(iv.would_rejoin_score)::numeric, 2),
    ROUND((COUNT(*)::numeric * 100.0 / NULLIF(v_total, 0)), 1)
  FROM founder_engineer_exit_interviews_v2 iv
  GROUP BY iv.sentiment
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_exit_iv_sentiment() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exit_iv_sentiment() TO authenticated;

-- 6) retention patterns
CREATE OR REPLACE FUNCTION rpc_founder_exit_iv_patterns()
RETURNS TABLE (
  pattern_window text,
  pattern_key text,
  pattern_value text,
  exit_count integer,
  avg_would_rejoin numeric,
  avg_tenure_days numeric,
  recommended_action text,
  computed_at timestamptz
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
    p.pattern_window,
    p.pattern_key,
    p.pattern_value,
    p.exit_count,
    p.avg_would_rejoin,
    p.avg_tenure_days,
    COALESCE(p.recommended_action, '-')::text,
    p.computed_at
  FROM founder_engineer_exit_patterns_v2 p
  ORDER BY p.computed_at DESC, p.exit_count DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_exit_iv_patterns() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exit_iv_patterns() TO authenticated;

-- 7) record exit interview (WRITE)
CREATE OR REPLACE FUNCTION rpc_founder_exit_iv_record(
  p_engineer_id uuid,
  p_primary_reason text,
  p_sentiment text,
  p_would_rejoin_score smallint,
  p_freeform_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_engineer_user_id uuid;
  v_tenure int;
  v_jobs int;
  v_earnings int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT user_id INTO v_engineer_user_id FROM engineers WHERE id = p_engineer_id;
  IF v_engineer_user_id IS NULL THEN RAISE EXCEPTION 'engineer_not_found'; END IF;

  SELECT
    GREATEST(0, EXTRACT(EPOCH FROM (now() - MIN(created_at)))::int / 86400),
    COUNT(*)::int
  INTO v_tenure, v_jobs
  FROM repair_jobs rj
  WHERE rj.engineer_id = p_engineer_id;

  SELECT COALESCE(SUM(amount_rupees), 0)::int INTO v_earnings
  FROM engineer_payouts
  WHERE engineer_user_id = v_engineer_user_id
    AND paid_at IS NOT NULL;

  INSERT INTO founder_engineer_exit_interviews_v2 (
    engineer_id, engineer_user_id, interviewer_user_id,
    primary_reason, sentiment, would_rejoin_score,
    freeform_notes, tenure_days, total_jobs_completed, total_earnings_rupees
  ) VALUES (
    p_engineer_id, v_engineer_user_id, auth.uid(),
    p_primary_reason, p_sentiment, p_would_rejoin_score,
    p_freeform_notes, COALESCE(v_tenure, 0), COALESCE(v_jobs, 0), COALESCE(v_earnings, 0)
  ) RETURNING id INTO v_id;

  PERFORM log_founder_exit_iv_create(v_id, p_engineer_id, p_primary_reason);

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_exit_iv_record(uuid, text, text, smallint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exit_iv_record(uuid, text, text, smallint, text) TO authenticated;

COMMIT;