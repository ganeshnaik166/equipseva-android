BEGIN;

-- =====================================================================
-- r1607 — Founder Engineer 6-Month Retention Tracker
-- At-risk engineers approaching 6-month mark (industry's highest churn point)
-- Founder personal-call list to save churning engineers.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: founder_engineer_6mo_risk_snapshots
-- Daily snapshot of each engineer's 6-month retention risk profile.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_engineer_6mo_risk_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  snapshot_date date NOT NULL DEFAULT CURRENT_DATE,
  days_since_onboard integer NOT NULL,
  days_to_6mo_mark integer NOT NULL,
  risk_band text NOT NULL CHECK (risk_band IN ('safe','watch','warn','critical','past_6mo')),
  risk_score numeric(5,2) NOT NULL DEFAULT 0,
  jobs_last_30d integer NOT NULL DEFAULT 0,
  jobs_last_60d integer NOT NULL DEFAULT 0,
  earnings_last_30d_rupees integer NOT NULL DEFAULT 0,
  earnings_last_60d_rupees integer NOT NULL DEFAULT 0,
  avg_rating_last_30d numeric(3,2),
  payout_failures_last_30d integer NOT NULL DEFAULT 0,
  cached_tier text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(engineer_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_eng6mo_snap_date ON founder_engineer_6mo_risk_snapshots(snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_eng6mo_snap_band ON founder_engineer_6mo_risk_snapshots(risk_band);
CREATE INDEX IF NOT EXISTS idx_eng6mo_snap_eng ON founder_engineer_6mo_risk_snapshots(engineer_id);

ALTER TABLE founder_engineer_6mo_risk_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_eng6mo_snap ON founder_engineer_6mo_risk_snapshots;
CREATE POLICY founder_only_eng6mo_snap ON founder_engineer_6mo_risk_snapshots
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------------------------------------------------------------------
-- Table 2: founder_engineer_6mo_call_log
-- Founder personal-call outreach log to at-risk engineers.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_engineer_6mo_call_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  called_at timestamptz NOT NULL DEFAULT now(),
  duration_minutes integer,
  outcome text NOT NULL CHECK (outcome IN ('saved','at_risk','will_churn','no_answer','left_voicemail','scheduled_followup')),
  retention_offer text,
  notes text,
  followup_due_at timestamptz,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng6mo_call_eng ON founder_engineer_6mo_call_log(engineer_id);
CREATE INDEX IF NOT EXISTS idx_eng6mo_call_at ON founder_engineer_6mo_call_log(called_at DESC);
CREATE INDEX IF NOT EXISTS idx_eng6mo_call_outcome ON founder_engineer_6mo_call_log(outcome);

ALTER TABLE founder_engineer_6mo_call_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_eng6mo_call ON founder_engineer_6mo_call_log;
CREATE POLICY founder_only_eng6mo_call ON founder_engineer_6mo_call_log
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =====================================================================
-- Helpers (VOLATILE SECDEF) — founder action logging
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_eng6mo_snapshot_run(p_count int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'eng6mo_snapshot_run',
          jsonb_build_object('snapshot_count', p_count));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_eng6mo_snapshot_run(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_eng6mo_snapshot_run(int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_eng6mo_call_logged(p_engineer_id uuid, p_outcome text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'eng6mo_call_logged',
          jsonb_build_object('engineer_id', p_engineer_id, 'outcome', p_outcome));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_eng6mo_call_logged(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_eng6mo_call_logged(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_eng6mo_retention_offer(p_engineer_id uuid, p_offer text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'eng6mo_retention_offer',
          jsonb_build_object('engineer_id', p_engineer_id, 'offer', p_offer));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_eng6mo_retention_offer(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_eng6mo_retention_offer(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_eng6mo_view()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'eng6mo_view', jsonb_build_object('at', now()));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_eng6mo_view() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_eng6mo_view() TO authenticated;

-- =====================================================================
-- RPC 1: kpis — top-line retention KPIs
-- =====================================================================
CREATE OR REPLACE FUNCTION founder_eng6mo_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total int;
  v_approaching int;
  v_critical int;
  v_warn int;
  v_watch int;
  v_safe int;
  v_past_6mo int;
  v_calls_30d int;
  v_saved_30d int;
  v_will_churn_30d int;
  v_no_answer_30d int;
  v_pending_followups int;
  v_avg_score numeric;
  v_latest_snap date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT MAX(snapshot_date) INTO v_latest_snap FROM founder_engineer_6mo_risk_snapshots;

  SELECT COUNT(*), AVG(risk_score)
    INTO v_total, v_avg_score
  FROM founder_engineer_6mo_risk_snapshots
  WHERE snapshot_date = v_latest_snap;

  SELECT
    COUNT(*) FILTER (WHERE risk_band='critical'),
    COUNT(*) FILTER (WHERE risk_band='warn'),
    COUNT(*) FILTER (WHERE risk_band='watch'),
    COUNT(*) FILTER (WHERE risk_band='safe'),
    COUNT(*) FILTER (WHERE risk_band='past_6mo'),
    COUNT(*) FILTER (WHERE risk_band IN ('warn','critical'))
  INTO v_critical, v_warn, v_watch, v_safe, v_past_6mo, v_approaching
  FROM founder_engineer_6mo_risk_snapshots
  WHERE snapshot_date = v_latest_snap;

  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE outcome='saved'),
    COUNT(*) FILTER (WHERE outcome='will_churn'),
    COUNT(*) FILTER (WHERE outcome='no_answer')
  INTO v_calls_30d, v_saved_30d, v_will_churn_30d, v_no_answer_30d
  FROM founder_engineer_6mo_call_log
  WHERE called_at >= now() - interval '30 days';

  SELECT COUNT(*) INTO v_pending_followups
  FROM founder_engineer_6mo_call_log
  WHERE followup_due_at IS NOT NULL
    AND followup_due_at <= now() + interval '7 days'
    AND outcome IN ('scheduled_followup','at_risk','no_answer','left_voicemail');

  RETURN jsonb_build_object(
    'snapshot_date', v_latest_snap,
    'total_engineers_tracked', COALESCE(v_total, 0),
    'approaching_6mo', COALESCE(v_approaching, 0),
    'critical', COALESCE(v_critical, 0),
    'warn', COALESCE(v_warn, 0),
    'watch', COALESCE(v_watch, 0),
    'safe', COALESCE(v_safe, 0),
    'past_6mo', COALESCE(v_past_6mo, 0),
    'avg_risk_score', COALESCE(ROUND(v_avg_score, 2), 0),
    'calls_30d', COALESCE(v_calls_30d, 0),
    'saved_30d', COALESCE(v_saved_30d, 0),
    'will_churn_30d', COALESCE(v_will_churn_30d, 0),
    'no_answer_30d', COALESCE(v_no_answer_30d, 0),
    'pending_followups_7d', COALESCE(v_pending_followups, 0),
    'save_rate_pct', CASE WHEN COALESCE(v_calls_30d,0) > 0
        THEN ROUND(100.0 * COALESCE(v_saved_30d,0) / v_calls_30d, 1) ELSE 0 END,
    'churn_rate_pct', CASE WHEN COALESCE(v_calls_30d,0) > 0
        THEN ROUND(100.0 * COALESCE(v_will_churn_30d,0) / v_calls_30d, 1) ELSE 0 END
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_eng6mo_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eng6mo_kpis() TO authenticated;

-- =====================================================================
-- RPC 2: at_risk_engineers — personal-call list
-- =====================================================================
CREATE OR REPLACE FUNCTION founder_eng6mo_at_risk_engineers()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  engineer_phone text,
  days_since_onboard int,
  days_to_6mo_mark int,
  risk_band text,
  risk_score numeric,
  jobs_last_30d int,
  earnings_last_30d_rupees int,
  avg_rating_last_30d numeric,
  cached_tier text,
  last_call_at timestamptz,
  last_call_outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest_snap AS (
    SELECT MAX(snapshot_date) AS d FROM founder_engineer_6mo_risk_snapshots
  ),
  snaps AS (
    SELECT s.*
    FROM founder_engineer_6mo_risk_snapshots s, latest_snap
    WHERE s.snapshot_date = latest_snap.d
      AND s.risk_band IN ('watch','warn','critical')
  ),
  last_calls AS (
    SELECT DISTINCT ON (cl.engineer_id)
      cl.engineer_id, cl.called_at, cl.outcome
    FROM founder_engineer_6mo_call_log cl
    ORDER BY cl.engineer_id, cl.called_at DESC
  )
  SELECT
    s.id,
    s.engineer_id,
    COALESCE(p.full_name, 'Engineer ' || substr(s.engineer_id::text,1,8)) AS engineer_name,
    p.phone AS engineer_phone,
    s.days_since_onboard,
    s.days_to_6mo_mark,
    s.risk_band,
    s.risk_score,
    s.jobs_last_30d,
    s.earnings_last_30d_rupees,
    s.avg_rating_last_30d,
    s.cached_tier,
    lc.called_at AS last_call_at,
    lc.outcome AS last_call_outcome
  FROM snaps s
  LEFT JOIN engineers e ON e.id = s.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN last_calls lc ON lc.engineer_id = s.engineer_id
  ORDER BY
    CASE s.risk_band WHEN 'critical' THEN 1 WHEN 'warn' THEN 2 WHEN 'watch' THEN 3 ELSE 4 END,
    s.risk_score DESC,
    s.days_to_6mo_mark ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_eng6mo_at_risk_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eng6mo_at_risk_engineers() TO authenticated;

-- =====================================================================
-- RPC 3: recent_calls — founder outreach history
-- =====================================================================
CREATE OR REPLACE FUNCTION founder_eng6mo_recent_calls()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  called_at timestamptz,
  duration_minutes int,
  outcome text,
  retention_offer text,
  notes text,
  followup_due_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    cl.id,
    cl.engineer_id,
    COALESCE(p.full_name, 'Engineer ' || substr(cl.engineer_id::text,1,8)) AS engineer_name,
    cl.called_at,
    cl.duration_minutes,
    cl.outcome,
    cl.retention_offer,
    cl.notes,
    cl.followup_due_at
  FROM founder_engineer_6mo_call_log cl
  LEFT JOIN engineers e ON e.id = cl.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY cl.called_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_eng6mo_recent_calls() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eng6mo_recent_calls() TO authenticated;

-- =====================================================================
-- RPC 4: pending_followups — due in next 7 days
-- =====================================================================
CREATE OR REPLACE FUNCTION founder_eng6mo_pending_followups()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  engineer_phone text,
  last_called_at timestamptz,
  last_outcome text,
  followup_due_at timestamptz,
  days_until_due numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    cl.id,
    cl.engineer_id,
    COALESCE(p.full_name, 'Engineer ' || substr(cl.engineer_id::text,1,8)) AS engineer_name,
    p.phone AS engineer_phone,
    cl.called_at AS last_called_at,
    cl.outcome AS last_outcome,
    cl.followup_due_at,
    ROUND(EXTRACT(EPOCH FROM (cl.followup_due_at - now())) / 86400.0, 1) AS days_until_due
  FROM founder_engineer_6mo_call_log cl
  LEFT JOIN engineers e ON e.id = cl.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE cl.followup_due_at IS NOT NULL
    AND cl.followup_due_at <= now() + interval '14 days'
    AND cl.outcome IN ('scheduled_followup','at_risk','no_answer','left_voicemail')
  ORDER BY cl.followup_due_at ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_eng6mo_pending_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eng6mo_pending_followups() TO authenticated;

-- =====================================================================
-- RPC 5: risk_band_distribution — cohort breakdown
-- =====================================================================
CREATE OR REPLACE FUNCTION founder_eng6mo_risk_band_distribution()
RETURNS TABLE (
  risk_band text,
  engineer_count int,
  avg_score numeric,
  avg_jobs_30d numeric,
  avg_earnings_30d_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT MAX(snapshot_date) AS d FROM founder_engineer_6mo_risk_snapshots
  )
  SELECT
    s.risk_band,
    COUNT(*)::int AS engineer_count,
    ROUND(AVG(s.risk_score), 2) AS avg_score,
    ROUND(AVG(s.jobs_last_30d)::numeric, 1) AS avg_jobs_30d,
    ROUND(AVG(s.earnings_last_30d_rupees)::numeric, 0) AS avg_earnings_30d_rupees
  FROM founder_engineer_6mo_risk_snapshots s, latest
  WHERE s.snapshot_date = latest.d
  GROUP BY s.risk_band
  ORDER BY
    CASE s.risk_band WHEN 'critical' THEN 1 WHEN 'warn' THEN 2
      WHEN 'watch' THEN 3 WHEN 'safe' THEN 4 ELSE 5 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_eng6mo_risk_band_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eng6mo_risk_band_distribution() TO authenticated;

-- =====================================================================
-- RPC 6 (VOLATILE WRITE): refresh_snapshots — rebuild today's snapshot
-- =====================================================================
CREATE OR REPLACE FUNCTION founder_eng6mo_refresh_snapshots()
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_inserted int := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  DELETE FROM founder_engineer_6mo_risk_snapshots WHERE snapshot_date = CURRENT_DATE;

  WITH eng_base AS (
    SELECT
      e.id AS engineer_id,
      e.created_at AS onboarded_at,
      e.cached_highest_tier,
      FLOOR(EXTRACT(EPOCH FROM (now() - e.created_at)) / 86400.0)::int AS days_since,
      (180 - FLOOR(EXTRACT(EPOCH FROM (now() - e.created_at)) / 86400.0))::int AS days_to_6mo
    FROM engineers e
    WHERE e.created_at >= now() - interval '12 months'
  ),
  jobs_30 AS (
    SELECT engineer_id, COUNT(*)::int AS c30
    FROM repair_jobs
    WHERE engineer_id IS NOT NULL
      AND completed_at >= now() - interval '30 days'
    GROUP BY engineer_id
  ),
  jobs_60 AS (
    SELECT engineer_id, COUNT(*)::int AS c60
    FROM repair_jobs
    WHERE engineer_id IS NOT NULL
      AND completed_at >= now() - interval '60 days'
    GROUP BY engineer_id
  ),
  earn_30 AS (
    SELECT engineer_user_id, SUM(amount_rupees)::int AS e30
    FROM engineer_payouts
    WHERE paid_at IS NOT NULL
      AND paid_at >= now() - interval '30 days'
    GROUP BY engineer_user_id
  ),
  earn_60 AS (
    SELECT engineer_user_id, SUM(amount_rupees)::int AS e60
    FROM engineer_payouts
    WHERE paid_at IS NOT NULL
      AND paid_at >= now() - interval '60 days'
    GROUP BY engineer_user_id
  ),
  rating_30 AS (
    SELECT engineer_id, ROUND(AVG(hospital_rating)::numeric, 2) AS avg_r
    FROM repair_jobs
    WHERE engineer_id IS NOT NULL
      AND hospital_rating IS NOT NULL
      AND completed_at >= now() - interval '30 days'
    GROUP BY engineer_id
  ),
  payout_fail_30 AS (
    SELECT engineer_user_id, COUNT(*)::int AS fails
    FROM engineer_payouts
    WHERE paid_at IS NULL
      AND created_at >= now() - interval '30 days'
    GROUP BY engineer_user_id
  )
  INSERT INTO founder_engineer_6mo_risk_snapshots (
    engineer_id, snapshot_date, days_since_onboard, days_to_6mo_mark,
    risk_band, risk_score, jobs_last_30d, jobs_last_60d,
    earnings_last_30d_rupees, earnings_last_60d_rupees,
    avg_rating_last_30d, payout_failures_last_30d, cached_tier
  )
  SELECT
    eb.engineer_id,
    CURRENT_DATE,
    eb.days_since,
    eb.days_to_6mo,
    CASE
      WHEN eb.days_since > 180 THEN 'past_6mo'
      WHEN eb.days_to_6mo <= 30 AND COALESCE(j30.c30,0) = 0 THEN 'critical'
      WHEN eb.days_to_6mo <= 30 AND COALESCE(j30.c30,0) <= 2 THEN 'warn'
      WHEN eb.days_to_6mo <= 60 AND COALESCE(j30.c30,0) <= 3 THEN 'warn'
      WHEN eb.days_to_6mo <= 60 THEN 'watch'
      WHEN eb.days_to_6mo <= 90 AND COALESCE(j30.c30,0) <= 2 THEN 'watch'
      ELSE 'safe'
    END AS risk_band,
    LEAST(100, GREATEST(0,
      (CASE WHEN eb.days_to_6mo <= 30 THEN 40 WHEN eb.days_to_6mo <= 60 THEN 25 WHEN eb.days_to_6mo <= 90 THEN 10 ELSE 0 END)
      + (CASE WHEN COALESCE(j30.c30,0) = 0 THEN 30 WHEN COALESCE(j30.c30,0) <= 2 THEN 20 WHEN COALESCE(j30.c30,0) <= 5 THEN 10 ELSE 0 END)
      + (CASE WHEN COALESCE(pf.fails,0) > 0 THEN 15 ELSE 0 END)
      + (CASE WHEN COALESCE(r30.avg_r, 5) < 4.0 THEN 15 WHEN COALESCE(r30.avg_r, 5) < 4.5 THEN 5 ELSE 0 END)
    ))::numeric AS risk_score,
    COALESCE(j30.c30, 0),
    COALESCE(j60.c60, 0),
    COALESCE(e30.e30, 0),
    COALESCE(e60.e60, 0),
    r30.avg_r,
    COALESCE(pf.fails, 0),
    eb.cached_highest_tier
  FROM eng_base eb
  LEFT JOIN jobs_30 j30 ON j30.engineer_id = eb.engineer_id
  LEFT JOIN jobs_60 j60 ON j60.engineer_id = eb.engineer_id
  LEFT JOIN engineers e_e ON e_e.id = eb.engineer_id
  LEFT JOIN earn_30 e30 ON e30.engineer_user_id = e_e.user_id
  LEFT JOIN earn_60 e60 ON e60.engineer_user_id = e_e.user_id
  LEFT JOIN rating_30 r30 ON r30.engineer_id = eb.engineer_id
  LEFT JOIN payout_fail_30 pf ON pf.engineer_user_id = e_e.user_id;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  PERFORM log_founder_eng6mo_snapshot_run(v_inserted);

  RETURN jsonb_build_object('inserted', v_inserted, 'snapshot_date', CURRENT_DATE);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_eng6mo_refresh_snapshots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eng6mo_refresh_snapshots() TO authenticated;

-- =====================================================================
-- RPC 7 (VOLATILE WRITE): log_call
-- =====================================================================
CREATE OR REPLACE FUNCTION founder_eng6mo_log_call(
  p_engineer_id uuid,
  p_duration_minutes int,
  p_outcome text,
  p_retention_offer text,
  p_notes text,
  p_followup_due_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_outcome NOT IN ('saved','at_risk','will_churn','no_answer','left_voicemail','scheduled_followup') THEN
    RAISE EXCEPTION 'invalid outcome: %', p_outcome;
  END IF;

  INSERT INTO founder_engineer_6mo_call_log (
    engineer_id, duration_minutes, outcome, retention_offer, notes, followup_due_at, created_by
  )
  VALUES (p_engineer_id, p_duration_minutes, p_outcome, p_retention_offer, p_notes, p_followup_due_at, auth.uid())
  RETURNING id INTO v_id;

  PERFORM log_founder_eng6mo_call_logged(p_engineer_id, p_outcome);

  IF p_retention_offer IS NOT NULL AND length(p_retention_offer) > 0 THEN
    PERFORM log_founder_eng6mo_retention_offer(p_engineer_id, p_retention_offer);
  END IF;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_eng6mo_log_call(uuid, int, text, text, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_eng6mo_log_call(uuid, int, text, text, text, timestamptz) TO authenticated;

COMMIT;