BEGIN;

-- =========================================================================
-- Round 1509: Founder Engineer Churn Cohort Analysis
-- Identify engineers who churned (no jobs 60d+); cohort by signup-month x
-- tier x city; correlate churn with NPS / payout-delay / peer-feedback.
-- =========================================================================

-- Cohort snapshot table (point-in-time snapshots of engineer cohorts)
CREATE TABLE IF NOT EXISTS founder_engineer_churn_cohort_snapshots_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  signup_month date NOT NULL,
  tier text NOT NULL,
  city text NOT NULL,
  cohort_size int NOT NULL DEFAULT 0,
  churned_count int NOT NULL DEFAULT 0,
  active_count int NOT NULL DEFAULT 0,
  churn_rate_pct numeric(6,2) NOT NULL DEFAULT 0,
  avg_days_since_last_job numeric(8,2),
  avg_nps numeric(4,2),
  avg_payout_delay_days numeric(8,2),
  avg_peer_feedback numeric(4,2),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_churn_cohort_snapshot_v2_month
  ON founder_engineer_churn_cohort_snapshots_v2(signup_month);
CREATE INDEX IF NOT EXISTS idx_churn_cohort_snapshot_v2_tier
  ON founder_engineer_churn_cohort_snapshots_v2(tier);
CREATE INDEX IF NOT EXISTS idx_churn_cohort_snapshot_v2_city
  ON founder_engineer_churn_cohort_snapshots_v2(city);

ALTER TABLE founder_engineer_churn_cohort_snapshots_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS churn_cohort_snap_v2_founder_all
  ON founder_engineer_churn_cohort_snapshots_v2;
CREATE POLICY churn_cohort_snap_v2_founder_all
  ON founder_engineer_churn_cohort_snapshots_v2
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- Per-engineer churn risk scores
CREATE TABLE IF NOT EXISTS founder_engineer_churn_risk_scores_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL,
  scored_at timestamptz NOT NULL DEFAULT now(),
  days_since_last_job int,
  nps_score numeric(4,2),
  payout_delay_days numeric(8,2),
  peer_feedback_score numeric(4,2),
  risk_score numeric(6,2) NOT NULL DEFAULT 0,
  risk_band text NOT NULL DEFAULT 'low',
  is_churned boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_churn_risk_scores_v2_engineer
  ON founder_engineer_churn_risk_scores_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_churn_risk_scores_v2_band
  ON founder_engineer_churn_risk_scores_v2(risk_band);
CREATE INDEX IF NOT EXISTS idx_churn_risk_scores_v2_scored
  ON founder_engineer_churn_risk_scores_v2(scored_at DESC);

ALTER TABLE founder_engineer_churn_risk_scores_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS churn_risk_scores_v2_founder_all
  ON founder_engineer_churn_risk_scores_v2;
CREATE POLICY churn_risk_scores_v2_founder_all
  ON founder_engineer_churn_risk_scores_v2
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- =========================================================================
-- Log helpers (3)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_churn_cohort_view(p_filter jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'churn_cohort_view', p_filter);
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_cohort_view(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_churn_cohort_view(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_churn_snapshot_taken(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'churn_snapshot_taken', p_payload);
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_snapshot_taken(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_churn_snapshot_taken(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_churn_risk_recomputed(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'churn_risk_recomputed', p_payload);
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_risk_recomputed(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_churn_risk_recomputed(jsonb) TO authenticated;

-- =========================================================================
-- READ RPCs (STABLE)
-- =========================================================================

-- 1. KPIs
CREATE OR REPLACE FUNCTION founder_engineer_churn_kpis()
RETURNS TABLE(
  total_engineers bigint,
  active_engineers bigint,
  churned_engineers bigint,
  at_risk_engineers bigint,
  churn_rate_pct numeric,
  avg_days_since_last_job numeric,
  avg_nps numeric,
  avg_payout_delay_days numeric,
  high_risk_count bigint,
  med_risk_count bigint,
  low_risk_count bigint,
  total_cohorts bigint,
  worst_cohort_label text,
  worst_cohort_churn_pct numeric,
  best_cohort_label text,
  best_cohort_churn_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH eng_last AS (
    SELECT e.id AS engineer_id,
           e.created_at,
           e.cached_highest_tier,
           MAX(rj.completed_at) AS last_job_at
    FROM engineers e
    LEFT JOIN repair_jobs rj ON rj.engineer_id = e.id
    GROUP BY e.id, e.created_at, e.cached_highest_tier
  ),
  scored AS (
    SELECT engineer_id,
           COALESCE(EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0, 9999) AS days_since,
           CASE WHEN last_job_at IS NULL
                  OR EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0 >= 60
                THEN true ELSE false END AS churned
    FROM eng_last
  ),
  risk AS (
    SELECT risk_band, COUNT(*) AS c
    FROM (
      SELECT DISTINCT ON (engineer_id) engineer_id, risk_band
      FROM founder_engineer_churn_risk_scores_v2
      ORDER BY engineer_id, scored_at DESC
    ) x
    GROUP BY risk_band
  ),
  cohort AS (
    SELECT
      to_char(signup_month, 'YYYY-MM') || ' / ' || tier || ' / ' || city AS label,
      churn_rate_pct
    FROM founder_engineer_churn_cohort_snapshots_v2
    WHERE snapshot_at >= now() - interval '14 days'
  )
  SELECT
    (SELECT COUNT(*) FROM engineers)::bigint,
    (SELECT COUNT(*) FROM scored WHERE NOT churned)::bigint,
    (SELECT COUNT(*) FROM scored WHERE churned)::bigint,
    (SELECT COALESCE(SUM(c),0) FROM risk WHERE risk_band IN ('high','med'))::bigint,
    ROUND(100.0 * (SELECT COUNT(*) FROM scored WHERE churned)::numeric
          / NULLIF((SELECT COUNT(*) FROM scored), 0), 2),
    ROUND((SELECT AVG(days_since) FROM scored WHERE days_since < 9999)::numeric, 2),
    NULL::numeric,
    NULL::numeric,
    (SELECT COALESCE(c,0) FROM risk WHERE risk_band = 'high')::bigint,
    (SELECT COALESCE(c,0) FROM risk WHERE risk_band = 'med')::bigint,
    (SELECT COALESCE(c,0) FROM risk WHERE risk_band = 'low')::bigint,
    (SELECT COUNT(*) FROM founder_engineer_churn_cohort_snapshots_v2)::bigint,
    (SELECT label FROM cohort ORDER BY churn_rate_pct DESC NULLS LAST LIMIT 1),
    (SELECT churn_rate_pct FROM cohort ORDER BY churn_rate_pct DESC NULLS LAST LIMIT 1),
    (SELECT label FROM cohort ORDER BY churn_rate_pct ASC NULLS LAST LIMIT 1),
    (SELECT churn_rate_pct FROM cohort ORDER BY churn_rate_pct ASC NULLS LAST LIMIT 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_churn_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_churn_kpis() TO authenticated;

-- 2. Cohort grid (signup-month x tier x city)
CREATE OR REPLACE FUNCTION founder_engineer_churn_cohort_grid()
RETURNS TABLE(
  id text,
  signup_month text,
  tier text,
  city text,
  cohort_size bigint,
  churned_count bigint,
  active_count bigint,
  churn_rate_pct numeric,
  avg_days_since_last_job numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH eng AS (
    SELECT
      e.id AS engineer_id,
      date_trunc('month', e.created_at)::date AS signup_month,
      COALESCE(e.cached_highest_tier, 'none') AS tier,
      COALESCE(o.city, 'unknown') AS city,
      MAX(rj.completed_at) AS last_job_at
    FROM engineers e
    LEFT JOIN profiles p ON p.id = e.user_id
    LEFT JOIN organizations o ON o.id = p.organization_id
    LEFT JOIN repair_jobs rj ON rj.engineer_id = e.id
    GROUP BY e.id, e.created_at, e.cached_highest_tier, o.city
  )
  SELECT
    (to_char(signup_month,'YYYY-MM') || ':' || tier || ':' || city) AS id,
    to_char(signup_month,'YYYY-MM') AS signup_month,
    tier,
    city,
    COUNT(*)::bigint AS cohort_size,
    COUNT(*) FILTER (
      WHERE last_job_at IS NULL
         OR EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0 >= 60
    )::bigint AS churned_count,
    COUNT(*) FILTER (
      WHERE last_job_at IS NOT NULL
        AND EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0 < 60
    )::bigint AS active_count,
    ROUND(100.0 * COUNT(*) FILTER (
      WHERE last_job_at IS NULL
         OR EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0 >= 60
    )::numeric / NULLIF(COUNT(*),0), 2) AS churn_rate_pct,
    ROUND(AVG(
      CASE WHEN last_job_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0
      END
    )::numeric, 2) AS avg_days_since_last_job
  FROM eng
  GROUP BY signup_month, tier, city
  ORDER BY signup_month DESC, churn_rate_pct DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_churn_cohort_grid() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_churn_cohort_grid() TO authenticated;

-- 3. At-risk engineer list
CREATE OR REPLACE FUNCTION founder_engineer_churn_at_risk_list()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  tier text,
  city text,
  days_since_last_job numeric,
  payout_delay_days numeric,
  risk_band text,
  risk_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH last_payout AS (
    SELECT engineer_user_id,
           MIN(EXTRACT(EPOCH FROM (now() - created_at))/86400.0) AS oldest_pending_days
    FROM engineer_payouts
    WHERE paid_at IS NULL
    GROUP BY engineer_user_id
  ),
  eng AS (
    SELECT
      e.id AS engineer_id,
      COALESCE(p.full_name, 'Unknown') AS engineer_name,
      COALESCE(e.cached_highest_tier, 'none') AS tier,
      COALESCE(o.city, 'unknown') AS city,
      MAX(rj.completed_at) AS last_job_at,
      COALESCE(lp.oldest_pending_days, 0) AS payout_delay_days,
      e.user_id
    FROM engineers e
    LEFT JOIN profiles p ON p.id = e.user_id
    LEFT JOIN organizations o ON o.id = p.organization_id
    LEFT JOIN repair_jobs rj ON rj.engineer_id = e.id
    LEFT JOIN last_payout lp ON lp.engineer_user_id = e.user_id
    GROUP BY e.id, p.full_name, e.cached_highest_tier, o.city, lp.oldest_pending_days, e.user_id
  )
  SELECT
    gen_random_uuid() AS id,
    eng.engineer_id,
    eng.engineer_name,
    eng.tier,
    eng.city,
    ROUND(COALESCE(EXTRACT(EPOCH FROM (now() - eng.last_job_at))/86400.0, 9999)::numeric, 1) AS days_since_last_job,
    ROUND(eng.payout_delay_days::numeric, 1) AS payout_delay_days,
    CASE
      WHEN COALESCE(EXTRACT(EPOCH FROM (now() - eng.last_job_at))/86400.0, 9999) >= 60 THEN 'high'
      WHEN COALESCE(EXTRACT(EPOCH FROM (now() - eng.last_job_at))/86400.0, 9999) >= 30 THEN 'med'
      ELSE 'low'
    END AS risk_band,
    ROUND(LEAST(100,
      0.6 * LEAST(COALESCE(EXTRACT(EPOCH FROM (now() - eng.last_job_at))/86400.0, 9999), 90) +
      0.4 * LEAST(eng.payout_delay_days, 60)
    )::numeric, 2) AS risk_score
  FROM eng
  WHERE COALESCE(EXTRACT(EPOCH FROM (now() - eng.last_job_at))/86400.0, 9999) >= 30
  ORDER BY risk_score DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_churn_at_risk_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_churn_at_risk_list() TO authenticated;

-- 4. Tier correlation table
CREATE OR REPLACE FUNCTION founder_engineer_churn_tier_correlation()
RETURNS TABLE(
  id text,
  tier text,
  cohort_size bigint,
  churned_count bigint,
  churn_rate_pct numeric,
  avg_days_since_last_job numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH eng AS (
    SELECT
      e.id AS engineer_id,
      COALESCE(e.cached_highest_tier, 'none') AS tier,
      MAX(rj.completed_at) AS last_job_at
    FROM engineers e
    LEFT JOIN repair_jobs rj ON rj.engineer_id = e.id
    GROUP BY e.id, e.cached_highest_tier
  )
  SELECT
    tier AS id,
    tier,
    COUNT(*)::bigint AS cohort_size,
    COUNT(*) FILTER (
      WHERE last_job_at IS NULL
         OR EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0 >= 60
    )::bigint AS churned_count,
    ROUND(100.0 * COUNT(*) FILTER (
      WHERE last_job_at IS NULL
         OR EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0 >= 60
    )::numeric / NULLIF(COUNT(*),0), 2) AS churn_rate_pct,
    ROUND(AVG(
      CASE WHEN last_job_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0
      END
    )::numeric, 2) AS avg_days_since_last_job
  FROM eng
  GROUP BY tier
  ORDER BY churn_rate_pct DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_churn_tier_correlation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_churn_tier_correlation() TO authenticated;

-- 5. Payout delay vs churn signal
CREATE OR REPLACE FUNCTION founder_engineer_churn_payout_signal()
RETURNS TABLE(
  id text,
  delay_bucket text,
  engineer_count bigint,
  churned_count bigint,
  churn_rate_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH eng AS (
    SELECT
      e.id AS engineer_id,
      e.user_id,
      MAX(rj.completed_at) AS last_job_at
    FROM engineers e
    LEFT JOIN repair_jobs rj ON rj.engineer_id = e.id
    GROUP BY e.id, e.user_id
  ),
  delay AS (
    SELECT engineer_user_id,
           COALESCE(MAX(EXTRACT(EPOCH FROM (COALESCE(paid_at, now()) - created_at))/86400.0), 0) AS max_delay_days
    FROM engineer_payouts
    GROUP BY engineer_user_id
  ),
  joined AS (
    SELECT
      CASE
        WHEN COALESCE(d.max_delay_days,0) < 3 THEN '0-3d'
        WHEN COALESCE(d.max_delay_days,0) < 7 THEN '3-7d'
        WHEN COALESCE(d.max_delay_days,0) < 14 THEN '7-14d'
        WHEN COALESCE(d.max_delay_days,0) < 30 THEN '14-30d'
        ELSE '30d+'
      END AS delay_bucket,
      eng.engineer_id,
      CASE WHEN eng.last_job_at IS NULL
             OR EXTRACT(EPOCH FROM (now() - eng.last_job_at))/86400.0 >= 60
           THEN 1 ELSE 0 END AS churned
    FROM eng
    LEFT JOIN delay d ON d.engineer_user_id = eng.user_id
  )
  SELECT
    delay_bucket AS id,
    delay_bucket,
    COUNT(*)::bigint AS engineer_count,
    SUM(churned)::bigint AS churned_count,
    ROUND(100.0 * SUM(churned)::numeric / NULLIF(COUNT(*),0), 2) AS churn_rate_pct
  FROM joined
  GROUP BY delay_bucket
  ORDER BY
    CASE delay_bucket
      WHEN '0-3d' THEN 1
      WHEN '3-7d' THEN 2
      WHEN '7-14d' THEN 3
      WHEN '14-30d' THEN 4
      ELSE 5
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_churn_payout_signal() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_churn_payout_signal() TO authenticated;

-- 6. Recent snapshots
CREATE OR REPLACE FUNCTION founder_engineer_churn_recent_snapshots()
RETURNS TABLE(
  id uuid,
  snapshot_at timestamptz,
  signup_month date,
  tier text,
  city text,
  cohort_size int,
  churned_count int,
  churn_rate_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT s.id, s.snapshot_at, s.signup_month, s.tier, s.city,
         s.cohort_size, s.churned_count, s.churn_rate_pct
  FROM founder_engineer_churn_cohort_snapshots_v2 s
  ORDER BY s.snapshot_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_churn_recent_snapshots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_churn_recent_snapshots() TO authenticated;

-- =========================================================================
-- WRITE RPC (VOLATILE) -- take a snapshot
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_engineer_churn_take_snapshot()
RETURNS int
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH eng AS (
    SELECT
      e.id AS engineer_id,
      date_trunc('month', e.created_at)::date AS signup_month,
      COALESCE(e.cached_highest_tier, 'none') AS tier,
      COALESCE(o.city, 'unknown') AS city,
      MAX(rj.completed_at) AS last_job_at
    FROM engineers e
    LEFT JOIN profiles p ON p.id = e.user_id
    LEFT JOIN organizations o ON o.id = p.organization_id
    LEFT JOIN repair_jobs rj ON rj.engineer_id = e.id
    GROUP BY e.id, e.created_at, e.cached_highest_tier, o.city
  ),
  agg AS (
    SELECT signup_month, tier, city,
           COUNT(*) AS cohort_size,
           COUNT(*) FILTER (
             WHERE last_job_at IS NULL
                OR EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0 >= 60
           ) AS churned_count,
           AVG(
             CASE WHEN last_job_at IS NOT NULL
               THEN EXTRACT(EPOCH FROM (now() - last_job_at))/86400.0
             END
           ) AS avg_days_since
    FROM eng
    GROUP BY signup_month, tier, city
  ),
  ins AS (
    INSERT INTO founder_engineer_churn_cohort_snapshots_v2
      (signup_month, tier, city, cohort_size, churned_count, active_count,
       churn_rate_pct, avg_days_since_last_job)
    SELECT signup_month, tier, city, cohort_size, churned_count,
           (cohort_size - churned_count),
           ROUND(100.0 * churned_count::numeric / NULLIF(cohort_size, 0), 2),
           ROUND(avg_days_since::numeric, 2)
    FROM agg
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_count FROM ins;

  PERFORM log_founder_churn_snapshot_taken(
    jsonb_build_object('rows_inserted', v_count, 'at', now())
  );

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_churn_take_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_churn_take_snapshot() TO authenticated;

COMMIT;