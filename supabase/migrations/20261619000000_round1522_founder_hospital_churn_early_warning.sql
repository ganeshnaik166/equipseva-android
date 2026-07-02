BEGIN;

-- ============================================================================
-- Round 1522 — Founder Hospital Churn Early-Warning
-- Predict 90d hospital churn using AMC payment delay + ticket volume +
-- NPS drop + escalation count signals; founder action ladder per risk band.
-- ============================================================================

CREATE TABLE IF NOT EXISTS founder_hospital_churn_scores_v2 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  scored_at       timestamptz NOT NULL DEFAULT now(),
  -- raw signals
  amc_payment_delay_days  numeric(8,2) NOT NULL DEFAULT 0,
  ticket_volume_30d       int          NOT NULL DEFAULT 0,
  ticket_volume_delta_pct numeric(8,2) NOT NULL DEFAULT 0,
  nps_current             numeric(5,2),
  nps_drop_points         numeric(5,2) NOT NULL DEFAULT 0,
  escalation_count_60d    int          NOT NULL DEFAULT 0,
  -- derived
  risk_score        numeric(5,2) NOT NULL DEFAULT 0, -- 0..100
  risk_band         text NOT NULL DEFAULT 'green'
    CHECK (risk_band IN ('green','yellow','orange','red')),
  predicted_churn_at date,
  notes             text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhcs_v2_hosp     ON founder_hospital_churn_scores_v2(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fhcs_v2_band     ON founder_hospital_churn_scores_v2(risk_band);
CREATE INDEX IF NOT EXISTS idx_fhcs_v2_scored   ON founder_hospital_churn_scores_v2(scored_at DESC);

ALTER TABLE founder_hospital_churn_scores_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fhcs_v2_founder_all ON founder_hospital_churn_scores_v2;
CREATE POLICY p_fhcs_v2_founder_all ON founder_hospital_churn_scores_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_hospital_churn_actions_v2 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  score_id        uuid REFERENCES founder_hospital_churn_scores_v2(id) ON DELETE SET NULL,
  risk_band       text NOT NULL CHECK (risk_band IN ('green','yellow','orange','red')),
  action_step     text NOT NULL,
  -- ladder rung: 1=watch, 2=outreach, 3=discount/visit, 4=founder call/save
  ladder_rung     int  NOT NULL DEFAULT 1 CHECK (ladder_rung BETWEEN 1 AND 4),
  taken_at        timestamptz,
  taken_by_email  text,
  outcome         text CHECK (outcome IN ('pending','saved','churned','no_response')),
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhca_v2_hosp   ON founder_hospital_churn_actions_v2(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fhca_v2_band   ON founder_hospital_churn_actions_v2(risk_band);
CREATE INDEX IF NOT EXISTS idx_fhca_v2_rung   ON founder_hospital_churn_actions_v2(ladder_rung);

ALTER TABLE founder_hospital_churn_actions_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fhca_v2_founder_all ON founder_hospital_churn_actions_v2;
CREATE POLICY p_fhca_v2_founder_all ON founder_hospital_churn_actions_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

CREATE OR REPLACE FUNCTION rpc_founder_churn_summary_v2()
RETURNS TABLE (
  total_hospitals       int,
  green_count           int,
  yellow_count          int,
  orange_count          int,
  red_count             int,
  avg_risk_score        numeric,
  avg_payment_delay     numeric,
  avg_ticket_volume     numeric,
  avg_nps_drop          numeric,
  total_escalations     int,
  hospitals_at_risk     int,
  predicted_churns_90d  int,
  actions_pending       int,
  actions_saved         int,
  actions_churned       int,
  ladder_4_count        int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_org_id) *
    FROM founder_hospital_churn_scores_v2
    ORDER BY hospital_org_id, scored_at DESC
  )
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE risk_band='green')::int,
    COUNT(*) FILTER (WHERE risk_band='yellow')::int,
    COUNT(*) FILTER (WHERE risk_band='orange')::int,
    COUNT(*) FILTER (WHERE risk_band='red')::int,
    COALESCE(ROUND(AVG(risk_score)::numeric,2),0),
    COALESCE(ROUND(AVG(amc_payment_delay_days)::numeric,2),0),
    COALESCE(ROUND(AVG(ticket_volume_30d)::numeric,2),0),
    COALESCE(ROUND(AVG(nps_drop_points)::numeric,2),0),
    COALESCE(SUM(escalation_count_60d)::int,0),
    COUNT(*) FILTER (WHERE risk_band IN ('orange','red'))::int,
    COUNT(*) FILTER (WHERE predicted_churn_at IS NOT NULL
                       AND predicted_churn_at <= (CURRENT_DATE + 90))::int,
    (SELECT COUNT(*) FROM founder_hospital_churn_actions_v2 WHERE outcome='pending' OR outcome IS NULL)::int,
    (SELECT COUNT(*) FROM founder_hospital_churn_actions_v2 WHERE outcome='saved')::int,
    (SELECT COUNT(*) FROM founder_hospital_churn_actions_v2 WHERE outcome='churned')::int,
    (SELECT COUNT(*) FROM founder_hospital_churn_actions_v2 WHERE ladder_rung=4)::int
  FROM latest;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_churn_summary_v2() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_churn_summary_v2() TO authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rpc_founder_churn_latest_scores_v2(p_limit int DEFAULT 100)
RETURNS TABLE (
  id                uuid,
  hospital_org_id   uuid,
  hospital_name     text,
  scored_at         timestamptz,
  risk_band         text,
  risk_score        numeric,
  amc_payment_delay_days numeric,
  ticket_volume_30d int,
  nps_drop_points   numeric,
  escalation_count_60d int,
  predicted_churn_at date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (s.hospital_org_id)
    s.id, s.hospital_org_id, o.name,
    s.scored_at, s.risk_band, s.risk_score,
    s.amc_payment_delay_days, s.ticket_volume_30d,
    s.nps_drop_points, s.escalation_count_60d, s.predicted_churn_at
  FROM founder_hospital_churn_scores_v2 s
  JOIN organizations o ON o.id = s.hospital_org_id
  ORDER BY s.hospital_org_id, s.scored_at DESC
  LIMIT GREATEST(p_limit, 1);
END $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_churn_latest_scores_v2(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_churn_latest_scores_v2(int) TO authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rpc_founder_churn_red_band_v2()
RETURNS TABLE (
  id                uuid,
  hospital_org_id   uuid,
  hospital_name     text,
  risk_score        numeric,
  amc_payment_delay_days numeric,
  ticket_volume_30d int,
  escalation_count_60d int,
  predicted_churn_at date,
  days_to_predicted_churn numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (s.hospital_org_id)
    s.id, s.hospital_org_id, o.name, s.risk_score,
    s.amc_payment_delay_days, s.ticket_volume_30d, s.escalation_count_60d,
    s.predicted_churn_at,
    CASE
      WHEN s.predicted_churn_at IS NOT NULL
      THEN EXTRACT(EPOCH FROM (s.predicted_churn_at::timestamp - now()))/86400.0
      ELSE NULL
    END
  FROM founder_hospital_churn_scores_v2 s
  JOIN organizations o ON o.id = s.hospital_org_id
  WHERE s.risk_band = 'red'
  ORDER BY s.hospital_org_id, s.scored_at DESC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_churn_red_band_v2() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_churn_red_band_v2() TO authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rpc_founder_churn_action_ladder_v2()
RETURNS TABLE (
  id              uuid,
  hospital_org_id uuid,
  hospital_name   text,
  risk_band       text,
  ladder_rung     int,
  action_step     text,
  outcome         text,
  taken_at        timestamptz,
  taken_by_email  text,
  created_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_org_id, o.name, a.risk_band, a.ladder_rung,
         a.action_step, a.outcome, a.taken_at, a.taken_by_email, a.created_at
  FROM founder_hospital_churn_actions_v2 a
  JOIN organizations o ON o.id = a.hospital_org_id
  ORDER BY a.ladder_rung DESC, a.created_at DESC
  LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_churn_action_ladder_v2() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_churn_action_ladder_v2() TO authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rpc_founder_churn_signal_breakdown_v2()
RETURNS TABLE (
  signal_name      text,
  avg_value        numeric,
  red_band_avg     numeric,
  green_band_avg   numeric,
  contribution_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_org_id) *
    FROM founder_hospital_churn_scores_v2
    ORDER BY hospital_org_id, scored_at DESC
  )
  SELECT 'amc_payment_delay_days'::text,
         COALESCE(ROUND(AVG(amc_payment_delay_days)::numeric,2),0),
         COALESCE(ROUND(AVG(amc_payment_delay_days) FILTER (WHERE risk_band='red')::numeric,2),0),
         COALESCE(ROUND(AVG(amc_payment_delay_days) FILTER (WHERE risk_band='green')::numeric,2),0),
         35.0::numeric
  FROM latest
  UNION ALL
  SELECT 'ticket_volume_30d',
         COALESCE(ROUND(AVG(ticket_volume_30d)::numeric,2),0),
         COALESCE(ROUND(AVG(ticket_volume_30d) FILTER (WHERE risk_band='red')::numeric,2),0),
         COALESCE(ROUND(AVG(ticket_volume_30d) FILTER (WHERE risk_band='green')::numeric,2),0),
         25.0::numeric
  FROM latest
  UNION ALL
  SELECT 'nps_drop_points',
         COALESCE(ROUND(AVG(nps_drop_points)::numeric,2),0),
         COALESCE(ROUND(AVG(nps_drop_points) FILTER (WHERE risk_band='red')::numeric,2),0),
         COALESCE(ROUND(AVG(nps_drop_points) FILTER (WHERE risk_band='green')::numeric,2),0),
         20.0::numeric
  FROM latest
  UNION ALL
  SELECT 'escalation_count_60d',
         COALESCE(ROUND(AVG(escalation_count_60d)::numeric,2),0),
         COALESCE(ROUND(AVG(escalation_count_60d) FILTER (WHERE risk_band='red')::numeric,2),0),
         COALESCE(ROUND(AVG(escalation_count_60d) FILTER (WHERE risk_band='green')::numeric,2),0),
         20.0::numeric
  FROM latest;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_churn_signal_breakdown_v2() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_churn_signal_breakdown_v2() TO authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rpc_founder_churn_band_trend_v2(p_days int DEFAULT 30)
RETURNS TABLE (
  bucket_date date,
  green_count int,
  yellow_count int,
  orange_count int,
  red_count   int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT scored_at::date,
         COUNT(*) FILTER (WHERE risk_band='green')::int,
         COUNT(*) FILTER (WHERE risk_band='yellow')::int,
         COUNT(*) FILTER (WHERE risk_band='orange')::int,
         COUNT(*) FILTER (WHERE risk_band='red')::int
  FROM founder_hospital_churn_scores_v2
  WHERE scored_at >= (now() - make_interval(days => GREATEST(p_days,1)))
  GROUP BY scored_at::date
  ORDER BY scored_at::date DESC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_churn_band_trend_v2(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_churn_band_trend_v2(int) TO authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rpc_founder_churn_save_rate_v2()
RETURNS TABLE (
  ladder_rung     int,
  total_actions   int,
  saved_count     int,
  churned_count   int,
  pending_count   int,
  save_rate_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.ladder_rung,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE outcome='saved')::int,
         COUNT(*) FILTER (WHERE outcome='churned')::int,
         COUNT(*) FILTER (WHERE outcome='pending' OR outcome IS NULL)::int,
         CASE WHEN COUNT(*) FILTER (WHERE outcome IN ('saved','churned')) = 0
              THEN 0
              ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE outcome='saved')
                         / NULLIF(COUNT(*) FILTER (WHERE outcome IN ('saved','churned')),0)::numeric, 2)
         END
  FROM founder_hospital_churn_actions_v2 a
  GROUP BY a.ladder_rung
  ORDER BY a.ladder_rung;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_churn_save_rate_v2() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_churn_save_rate_v2() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE) — log_founder_* helpers
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_churn_score_v2(
  p_hospital_org_id uuid,
  p_amc_payment_delay_days numeric,
  p_ticket_volume_30d int,
  p_ticket_volume_delta_pct numeric,
  p_nps_current numeric,
  p_nps_drop_points numeric,
  p_escalation_count_60d int,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_risk numeric;
  v_band text;
  v_predicted date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_risk := LEAST(100, GREATEST(0,
    0.35 * LEAST(p_amc_payment_delay_days, 90)
  + 0.25 * LEAST(p_ticket_volume_30d, 100)
  + 0.20 * LEAST(p_nps_drop_points * 5, 100)
  + 0.20 * LEAST(p_escalation_count_60d * 10, 100)
  ));

  v_band := CASE
    WHEN v_risk >= 75 THEN 'red'
    WHEN v_risk >= 50 THEN 'orange'
    WHEN v_risk >= 25 THEN 'yellow'
    ELSE 'green'
  END;

  v_predicted := CASE
    WHEN v_band IN ('orange','red')
    THEN (CURRENT_DATE + GREATEST(7, (90 - v_risk)::int))
    ELSE NULL
  END;

  INSERT INTO founder_hospital_churn_scores_v2 (
    hospital_org_id, amc_payment_delay_days, ticket_volume_30d,
    ticket_volume_delta_pct, nps_current, nps_drop_points,
    escalation_count_60d, risk_score, risk_band, predicted_churn_at, notes
  ) VALUES (
    p_hospital_org_id, p_amc_payment_delay_days, p_ticket_volume_30d,
    p_ticket_volume_delta_pct, p_nps_current, p_nps_drop_points,
    p_escalation_count_60d, v_risk, v_band, v_predicted, p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_churn_score_v2',
          jsonb_build_object('score_id', v_id, 'hospital_org_id', p_hospital_org_id,
                             'risk_score', v_risk, 'risk_band', v_band));
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_score_v2(uuid,numeric,int,numeric,numeric,numeric,int,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_churn_score_v2(uuid,numeric,int,numeric,numeric,numeric,int,text) TO authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_founder_churn_action_v2(
  p_hospital_org_id uuid,
  p_score_id uuid,
  p_risk_band text,
  p_action_step text,
  p_ladder_rung int
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_hospital_churn_actions_v2 (
    hospital_org_id, score_id, risk_band, action_step, ladder_rung, outcome
  ) VALUES (
    p_hospital_org_id, p_score_id, p_risk_band, p_action_step,
    GREATEST(1, LEAST(4, p_ladder_rung)), 'pending'
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_churn_action_v2',
          jsonb_build_object('action_id', v_id, 'hospital_org_id', p_hospital_org_id,
                             'ladder_rung', p_ladder_rung, 'risk_band', p_risk_band));
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_action_v2(uuid,uuid,text,text,int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_churn_action_v2(uuid,uuid,text,text,int) TO authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_founder_churn_outcome_v2(
  p_action_id uuid,
  p_outcome text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');

  UPDATE founder_hospital_churn_actions_v2
     SET outcome = p_outcome,
         taken_at = COALESCE(taken_at, now()),
         taken_by_email = COALESCE(taken_by_email, v_email)
   WHERE id = p_action_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_founder_churn_outcome_v2',
          jsonb_build_object('action_id', p_action_id, 'outcome', p_outcome));
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_outcome_v2(uuid,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_churn_outcome_v2(uuid,text) TO authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_founder_churn_note_v2(
  p_score_id uuid,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE founder_hospital_churn_scores_v2
     SET notes = p_note
   WHERE id = p_score_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_churn_note_v2',
          jsonb_build_object('score_id', p_score_id, 'note', p_note));
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_note_v2(uuid,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_churn_note_v2(uuid,text) TO authenticated;

COMMIT;