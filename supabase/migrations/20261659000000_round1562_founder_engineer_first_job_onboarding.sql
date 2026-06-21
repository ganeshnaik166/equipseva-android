BEGIN;

-- =====================================================================
-- r1562: Engineer first-job onboarding tracker
-- Every new engineer must complete first paid job within 14 days.
-- Tracks time-to-first-job and per-engineer onboarding state.
-- Founder reviews stuck engineers.
-- =====================================================================

-- ---------- TABLE: engineer_first_job_onboarding ---------------------
CREATE TABLE IF NOT EXISTS engineer_first_job_onboarding (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  onboarding_started_at timestamptz NOT NULL DEFAULT now(),
  deadline_at timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  first_job_id uuid REFERENCES repair_jobs(id) ON DELETE SET NULL,
  first_job_completed_at timestamptz,
  first_payout_id uuid REFERENCES engineer_payouts(id) ON DELETE SET NULL,
  first_paid_at timestamptz,
  state text NOT NULL DEFAULT 'in_progress'
    CHECK (state IN ('in_progress','completed_on_time','completed_late','stuck','churned','founder_extended')),
  founder_note text,
  extension_days int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT engineer_first_job_onboarding_engineer_unique UNIQUE (engineer_id)
);

CREATE INDEX IF NOT EXISTS idx_efjo_state ON engineer_first_job_onboarding(state);
CREATE INDEX IF NOT EXISTS idx_efjo_deadline ON engineer_first_job_onboarding(deadline_at);
CREATE INDEX IF NOT EXISTS idx_efjo_engineer ON engineer_first_job_onboarding(engineer_id);

ALTER TABLE engineer_first_job_onboarding ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS efjo_founder_only ON engineer_first_job_onboarding;
CREATE POLICY efjo_founder_only ON engineer_first_job_onboarding
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- TABLE: engineer_first_job_reviews ------------------------
CREATE TABLE IF NOT EXISTS engineer_first_job_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL REFERENCES engineer_first_job_onboarding(id) ON DELETE CASCADE,
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('extend','churn','approve_completion','flag_stuck','clear_flag')),
  extension_days int NOT NULL DEFAULT 0,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efjr_engineer ON engineer_first_job_reviews(engineer_id);
CREATE INDEX IF NOT EXISTS idx_efjr_decision ON engineer_first_job_reviews(decision);
CREATE INDEX IF NOT EXISTS idx_efjr_created ON engineer_first_job_reviews(created_at DESC);

ALTER TABLE engineer_first_job_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS efjr_founder_only ON engineer_first_job_reviews;
CREATE POLICY efjr_founder_only ON engineer_first_job_reviews
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =====================================================================
-- LOG HELPERS (VOLATILE SECDEF, founder-gated)
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_efjo_extension(
  p_engineer_id uuid,
  p_days int,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'efjo_extension',
    jsonb_build_object('engineer_id', p_engineer_id, 'days', p_days, 'reason', p_reason)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_efjo_extension(uuid, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_efjo_extension(uuid, int, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_efjo_churn(
  p_engineer_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'efjo_churn',
    jsonb_build_object('engineer_id', p_engineer_id, 'reason', p_reason)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_efjo_churn(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_efjo_churn(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_efjo_flag_stuck(
  p_engineer_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'efjo_flag_stuck',
    jsonb_build_object('engineer_id', p_engineer_id, 'reason', p_reason)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_efjo_flag_stuck(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_efjo_flag_stuck(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_efjo_backfill(
  p_created_count int
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'efjo_backfill',
    jsonb_build_object('created_count', p_created_count)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_efjo_backfill(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_efjo_backfill(int) TO authenticated;

-- =====================================================================
-- READ RPCs (STABLE SECDEF, founder-gated)
-- =====================================================================

-- 1. Top-level KPIs
CREATE OR REPLACE FUNCTION founder_efjo_kpis()
RETURNS TABLE(
  total_tracked int,
  in_progress_count int,
  completed_on_time int,
  completed_late int,
  stuck_count int,
  churned_count int,
  founder_extended_count int,
  on_time_rate_pct numeric,
  avg_days_to_first_job numeric,
  median_days_to_first_job numeric,
  fastest_days numeric,
  slowest_days numeric,
  due_within_3_days int,
  overdue_count int,
  extensions_granted int,
  total_extension_days int
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
    COUNT(*)::int AS total_tracked,
    COUNT(*) FILTER (WHERE state = 'in_progress')::int AS in_progress_count,
    COUNT(*) FILTER (WHERE state = 'completed_on_time')::int AS completed_on_time,
    COUNT(*) FILTER (WHERE state = 'completed_late')::int AS completed_late,
    COUNT(*) FILTER (WHERE state = 'stuck')::int AS stuck_count,
    COUNT(*) FILTER (WHERE state = 'churned')::int AS churned_count,
    COUNT(*) FILTER (WHERE state = 'founder_extended')::int AS founder_extended_count,
    COALESCE(round(
      100.0 * COUNT(*) FILTER (WHERE state = 'completed_on_time')::numeric
      / NULLIF(COUNT(*) FILTER (WHERE state IN ('completed_on_time','completed_late')), 0),
      1
    ), 0)::numeric AS on_time_rate_pct,
    COALESCE(round(AVG(
      EXTRACT(EPOCH FROM (first_paid_at - onboarding_started_at)) / 86400.0
    ) FILTER (WHERE first_paid_at IS NOT NULL), 1), 0)::numeric AS avg_days_to_first_job,
    COALESCE(round(
      (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (first_paid_at - onboarding_started_at)) / 86400.0))::numeric,
      1
    ), 0)::numeric AS median_days_to_first_job,
    COALESCE(round(MIN(
      EXTRACT(EPOCH FROM (first_paid_at - onboarding_started_at)) / 86400.0
    )::numeric, 1), 0)::numeric AS fastest_days,
    COALESCE(round(MAX(
      EXTRACT(EPOCH FROM (first_paid_at - onboarding_started_at)) / 86400.0
    )::numeric, 1), 0)::numeric AS slowest_days,
    COUNT(*) FILTER (WHERE state = 'in_progress' AND deadline_at <= now() + interval '3 days' AND deadline_at > now())::int AS due_within_3_days,
    COUNT(*) FILTER (WHERE state = 'in_progress' AND deadline_at <= now())::int AS overdue_count,
    COUNT(*) FILTER (WHERE extension_days > 0)::int AS extensions_granted,
    COALESCE(SUM(extension_days), 0)::int AS total_extension_days
  FROM engineer_first_job_onboarding;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_efjo_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_efjo_kpis() TO authenticated;

-- 2. Stuck engineers (in_progress past deadline or explicitly stuck)
CREATE OR REPLACE FUNCTION founder_efjo_stuck_engineers()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  engineer_phone text,
  tier text,
  onboarding_started_at timestamptz,
  deadline_at timestamptz,
  days_elapsed numeric,
  days_overdue numeric,
  state text,
  extension_days int
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
    o.id,
    o.engineer_id,
    COALESCE(p.full_name, 'Unknown')::text AS engineer_name,
    COALESCE(p.phone, '')::text AS engineer_phone,
    COALESCE(e.cached_highest_tier, 'none')::text AS tier,
    o.onboarding_started_at,
    o.deadline_at,
    round(EXTRACT(EPOCH FROM (now() - o.onboarding_started_at)) / 86400.0, 1)::numeric AS days_elapsed,
    round(EXTRACT(EPOCH FROM (now() - o.deadline_at)) / 86400.0, 1)::numeric AS days_overdue,
    o.state,
    o.extension_days
  FROM engineer_first_job_onboarding o
  JOIN engineers e ON e.id = o.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE o.state IN ('stuck','in_progress')
    AND o.deadline_at <= now() + interval '3 days'
  ORDER BY o.deadline_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_efjo_stuck_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_efjo_stuck_engineers() TO authenticated;

-- 3. Recently completed first jobs
CREATE OR REPLACE FUNCTION founder_efjo_recent_completions()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  tier text,
  first_job_id uuid,
  first_paid_at timestamptz,
  days_to_first_job numeric,
  state text
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
    o.id,
    o.engineer_id,
    COALESCE(p.full_name, 'Unknown')::text AS engineer_name,
    COALESCE(e.cached_highest_tier, 'none')::text AS tier,
    o.first_job_id,
    o.first_paid_at,
    round(EXTRACT(EPOCH FROM (o.first_paid_at - o.onboarding_started_at)) / 86400.0, 1)::numeric AS days_to_first_job,
    o.state
  FROM engineer_first_job_onboarding o
  JOIN engineers e ON e.id = o.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE o.first_paid_at IS NOT NULL
  ORDER BY o.first_paid_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_efjo_recent_completions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_efjo_recent_completions() TO authenticated;

-- 4. Cohort breakdown by week joined
CREATE OR REPLACE FUNCTION founder_efjo_cohort_breakdown()
RETURNS TABLE(
  cohort_week date,
  cohort_size int,
  completed_count int,
  on_time_count int,
  stuck_count int,
  on_time_rate_pct numeric,
  avg_days numeric
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
    date_trunc('week', o.onboarding_started_at)::date AS cohort_week,
    COUNT(*)::int AS cohort_size,
    COUNT(*) FILTER (WHERE o.first_paid_at IS NOT NULL)::int AS completed_count,
    COUNT(*) FILTER (WHERE o.state = 'completed_on_time')::int AS on_time_count,
    COUNT(*) FILTER (WHERE o.state IN ('stuck','churned'))::int AS stuck_count,
    COALESCE(round(
      100.0 * COUNT(*) FILTER (WHERE o.state = 'completed_on_time')::numeric
      / NULLIF(COUNT(*), 0),
      1
    ), 0)::numeric AS on_time_rate_pct,
    COALESCE(round(AVG(
      EXTRACT(EPOCH FROM (o.first_paid_at - o.onboarding_started_at)) / 86400.0
    ) FILTER (WHERE o.first_paid_at IS NOT NULL), 1), 0)::numeric AS avg_days
  FROM engineer_first_job_onboarding o
  GROUP BY date_trunc('week', o.onboarding_started_at)::date
  ORDER BY cohort_week DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_efjo_cohort_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_efjo_cohort_breakdown() TO authenticated;

-- 5. Recent founder reviews
CREATE OR REPLACE FUNCTION founder_efjo_recent_reviews()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  reviewer_email text,
  decision text,
  extension_days int,
  reason text,
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
    r.id,
    r.engineer_id,
    COALESCE(p.full_name, 'Unknown')::text AS engineer_name,
    r.reviewer_email,
    r.decision,
    r.extension_days,
    r.reason,
    r.created_at
  FROM engineer_first_job_reviews r
  JOIN engineers e ON e.id = r.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY r.created_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_efjo_recent_reviews() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_efjo_recent_reviews() TO authenticated;

-- 6. Tier distribution of onboarded engineers
CREATE OR REPLACE FUNCTION founder_efjo_tier_distribution()
RETURNS TABLE(
  tier text,
  total_count int,
  on_time_count int,
  stuck_count int,
  on_time_rate_pct numeric,
  avg_days numeric
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
    COALESCE(e.cached_highest_tier, 'none')::text AS tier,
    COUNT(*)::int AS total_count,
    COUNT(*) FILTER (WHERE o.state = 'completed_on_time')::int AS on_time_count,
    COUNT(*) FILTER (WHERE o.state IN ('stuck','churned'))::int AS stuck_count,
    COALESCE(round(
      100.0 * COUNT(*) FILTER (WHERE o.state = 'completed_on_time')::numeric
      / NULLIF(COUNT(*), 0),
      1
    ), 0)::numeric AS on_time_rate_pct,
    COALESCE(round(AVG(
      EXTRACT(EPOCH FROM (o.first_paid_at - o.onboarding_started_at)) / 86400.0
    ) FILTER (WHERE o.first_paid_at IS NOT NULL), 1), 0)::numeric AS avg_days
  FROM engineer_first_job_onboarding o
  JOIN engineers e ON e.id = o.engineer_id
  GROUP BY COALESCE(e.cached_highest_tier, 'none')
  ORDER BY total_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_efjo_tier_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_efjo_tier_distribution() TO authenticated;

-- 7. Untracked engineers (need backfill)
CREATE OR REPLACE FUNCTION founder_efjo_untracked_engineers()
RETURNS TABLE(
  engineer_id uuid,
  engineer_name text,
  tier text,
  engineer_created_at timestamptz,
  days_since_signup numeric
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
    e.id AS engineer_id,
    COALESCE(p.full_name, 'Unknown')::text AS engineer_name,
    COALESCE(e.cached_highest_tier, 'none')::text AS tier,
    e.created_at AS engineer_created_at,
    round(EXTRACT(EPOCH FROM (now() - e.created_at)) / 86400.0, 1)::numeric AS days_since_signup
  FROM engineers e
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN engineer_first_job_onboarding o ON o.engineer_id = e.id
  WHERE o.id IS NULL
  ORDER BY e.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_efjo_untracked_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_efjo_untracked_engineers() TO authenticated;

COMMIT;