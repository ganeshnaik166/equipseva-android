BEGIN;

-- ============================================================
-- r1464 engineer attrition risk scoring
-- ============================================================

CREATE TABLE IF NOT EXISTS engineer_attrition_scores_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  scored_at timestamptz NOT NULL DEFAULT now(),
  risk_score numeric(5,2) NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
  risk_band text NOT NULL CHECK (risk_band IN ('red','yellow','green')),
  last_login_age_days int,
  accept_rate_30d numeric(5,2),
  accept_rate_decline_pct numeric(5,2),
  nps_score numeric(5,2),
  nps_drop_pct numeric(5,2),
  late_payout_count_90d int DEFAULT 0,
  mental_health_flag bool DEFAULT false,
  peer_neg_feedback_count_90d int DEFAULT 0,
  signal_breakdown jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eas_v2_eng ON engineer_attrition_scores_v2(engineer_id, scored_at DESC);
CREATE INDEX IF NOT EXISTS idx_eas_v2_band ON engineer_attrition_scores_v2(risk_band, scored_at DESC);

ALTER TABLE engineer_attrition_scores_v2 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS engineer_attrition_interventions_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  intervention_type text NOT NULL CHECK (intervention_type IN ('call','meeting','bonus','training','mental_health_referral','payout_expedite','reassignment','other')),
  notes text,
  outcome text CHECK (outcome IS NULL OR outcome IN ('resolved','monitoring','escalated','attrited')),
  performed_by uuid REFERENCES profiles(id),
  performed_at timestamptz NOT NULL DEFAULT now(),
  follow_up_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eai_v2_eng ON engineer_attrition_interventions_v2(engineer_id, performed_at DESC);
CREATE INDEX IF NOT EXISTS idx_eai_v2_followup ON engineer_attrition_interventions_v2(follow_up_at) WHERE follow_up_at IS NOT NULL;

ALTER TABLE engineer_attrition_interventions_v2 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- helpers (log_founder_*)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_attrition_score(
  p_engineer_id uuid,
  p_risk_score numeric,
  p_risk_band text,
  p_breakdown jsonb
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_attrition_scores_v2(engineer_id, risk_score, risk_band, signal_breakdown)
  VALUES (p_engineer_id, p_risk_score, p_risk_band, COALESCE(p_breakdown,'{}'::jsonb))
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_attrition_score(uuid,numeric,text,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_attrition_intervention(
  p_engineer_id uuid,
  p_type text,
  p_notes text,
  p_follow_up_at timestamptz
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_attrition_interventions_v2(engineer_id, intervention_type, notes, performed_by, follow_up_at)
  VALUES (p_engineer_id, p_type, p_notes, auth.uid(), p_follow_up_at)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_attrition_intervention(uuid,text,text,timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_attrition_outcome(
  p_intervention_id uuid,
  p_outcome text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_attrition_interventions_v2 SET outcome = p_outcome WHERE id = p_intervention_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_attrition_outcome(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_attrition_bulk_refresh(
  p_count int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  -- placeholder for telemetry hook; intentionally no-op write to a heavy table
  RAISE NOTICE 'attrition bulk refresh count=%', p_count;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_attrition_bulk_refresh(int) TO authenticated;

-- ============================================================
-- SECDEF read RPCs (7)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_attrition_kpis()
RETURNS TABLE (
  total_engineers bigint,
  red_count bigint,
  yellow_count bigint,
  green_count bigint,
  avg_risk numeric,
  max_risk numeric,
  flagged_mental_health bigint,
  stale_login_30d bigint,
  open_interventions bigint,
  resolved_30d bigint,
  escalated_30d bigint,
  attrited_90d bigint,
  avg_accept_rate numeric,
  avg_nps numeric,
  total_late_payouts_90d bigint,
  total_peer_neg_90d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (engineer_id) *
    FROM engineer_attrition_scores_v2
    ORDER BY engineer_id, scored_at DESC
  )
  SELECT
    (SELECT count(*) FROM engineers)::bigint,
    (SELECT count(*) FROM latest WHERE risk_band='red')::bigint,
    (SELECT count(*) FROM latest WHERE risk_band='yellow')::bigint,
    (SELECT count(*) FROM latest WHERE risk_band='green')::bigint,
    COALESCE((SELECT round(avg(risk_score)::numeric,2) FROM latest),0)::numeric,
    COALESCE((SELECT max(risk_score) FROM latest),0)::numeric,
    (SELECT count(*) FROM latest WHERE mental_health_flag)::bigint,
    (SELECT count(*) FROM latest WHERE last_login_age_days >= 30)::bigint,
    (SELECT count(*) FROM engineer_attrition_interventions_v2 WHERE outcome IS NULL)::bigint,
    (SELECT count(*) FROM engineer_attrition_interventions_v2 WHERE outcome='resolved' AND performed_at >= now() - interval '30 days')::bigint,
    (SELECT count(*) FROM engineer_attrition_interventions_v2 WHERE outcome='escalated' AND performed_at >= now() - interval '30 days')::bigint,
    (SELECT count(*) FROM engineer_attrition_interventions_v2 WHERE outcome='attrited' AND performed_at >= now() - interval '90 days')::bigint,
    COALESCE((SELECT round(avg(accept_rate_30d)::numeric,2) FROM latest),0)::numeric,
    COALESCE((SELECT round(avg(nps_score)::numeric,2) FROM latest),0)::numeric,
    COALESCE((SELECT sum(late_payout_count_90d) FROM latest),0)::bigint,
    COALESCE((SELECT sum(peer_neg_feedback_count_90d) FROM latest),0)::bigint;
END $$;
GRANT EXECUTE ON FUNCTION founder_attrition_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_attrition_red_list()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  full_name text,
  risk_score numeric,
  last_login_age_days int,
  accept_rate_30d numeric,
  nps_score numeric,
  late_payout_count_90d int,
  mental_health_flag bool,
  scored_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.engineer_id) s.*
    FROM engineer_attrition_scores_v2 s
    ORDER BY s.engineer_id, s.scored_at DESC
  )
  SELECT l.id, l.engineer_id, COALESCE(p.full_name,'(unknown)'),
    l.risk_score, l.last_login_age_days, l.accept_rate_30d, l.nps_score,
    l.late_payout_count_90d, l.mental_health_flag, l.scored_at
  FROM latest l
  JOIN engineers e ON e.id = l.engineer_id
  LEFT JOIN profiles p ON p.id = e.profile_id
  WHERE l.risk_band = 'red'
  ORDER BY l.risk_score DESC
  LIMIT 200;
END $$;
GRANT EXECUTE ON FUNCTION founder_attrition_red_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_attrition_yellow_list()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  full_name text,
  risk_score numeric,
  last_login_age_days int,
  accept_rate_30d numeric,
  nps_score numeric,
  late_payout_count_90d int,
  scored_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.engineer_id) s.*
    FROM engineer_attrition_scores_v2 s
    ORDER BY s.engineer_id, s.scored_at DESC
  )
  SELECT l.id, l.engineer_id, COALESCE(p.full_name,'(unknown)'),
    l.risk_score, l.last_login_age_days, l.accept_rate_30d, l.nps_score,
    l.late_payout_count_90d, l.scored_at
  FROM latest l
  JOIN engineers e ON e.id = l.engineer_id
  LEFT JOIN profiles p ON p.id = e.profile_id
  WHERE l.risk_band = 'yellow'
  ORDER BY l.risk_score DESC
  LIMIT 200;
END $$;
GRANT EXECUTE ON FUNCTION founder_attrition_yellow_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_attrition_recent_interventions()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  full_name text,
  intervention_type text,
  notes text,
  outcome text,
  performed_at timestamptz,
  follow_up_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_id, COALESCE(p.full_name,'(unknown)'),
    i.intervention_type, i.notes, i.outcome, i.performed_at, i.follow_up_at
  FROM engineer_attrition_interventions_v2 i
  JOIN engineers e ON e.id = i.engineer_id
  LEFT JOIN profiles p ON p.id = e.profile_id
  ORDER BY i.performed_at DESC
  LIMIT 100;
END $$;
GRANT EXECUTE ON FUNCTION founder_attrition_recent_interventions() TO authenticated;

CREATE OR REPLACE FUNCTION founder_attrition_pending_followups()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  full_name text,
  intervention_type text,
  follow_up_at timestamptz,
  days_until_followup int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_id, COALESCE(p.full_name,'(unknown)'),
    i.intervention_type, i.follow_up_at,
    GREATEST(0, EXTRACT(DAY FROM (i.follow_up_at - now()))::int)
  FROM engineer_attrition_interventions_v2 i
  JOIN engineers e ON e.id = i.engineer_id
  LEFT JOIN profiles p ON p.id = e.profile_id
  WHERE i.outcome IS NULL AND i.follow_up_at IS NOT NULL
  ORDER BY i.follow_up_at ASC
  LIMIT 100;
END $$;
GRANT EXECUTE ON FUNCTION founder_attrition_pending_followups() TO authenticated;

CREATE OR REPLACE FUNCTION founder_attrition_band_trend()
RETURNS TABLE (
  week_start date,
  red_count bigint,
  yellow_count bigint,
  green_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', s.scored_at)::date AS week_start,
    count(*) FILTER (WHERE s.risk_band='red')::bigint,
    count(*) FILTER (WHERE s.risk_band='yellow')::bigint,
    count(*) FILTER (WHERE s.risk_band='green')::bigint
  FROM engineer_attrition_scores_v2 s
  WHERE s.scored_at >= now() - interval '12 weeks'
  GROUP BY 1
  ORDER BY 1 DESC;
END $$;
GRANT EXECUTE ON FUNCTION founder_attrition_band_trend() TO authenticated;

CREATE OR REPLACE FUNCTION founder_attrition_top_signals()
RETURNS TABLE (
  signal text,
  affected_engineers bigint,
  avg_contribution numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (engineer_id) *
    FROM engineer_attrition_scores_v2
    ORDER BY engineer_id, scored_at DESC
  )
  SELECT * FROM (
    VALUES
      ('stale_login_30d',
        (SELECT count(*) FROM latest WHERE last_login_age_days >= 30)::bigint,
        COALESCE((SELECT round(avg(last_login_age_days)::numeric,2) FROM latest WHERE last_login_age_days >= 30),0)::numeric),
      ('low_accept_rate',
        (SELECT count(*) FROM latest WHERE accept_rate_30d < 60)::bigint,
        COALESCE((SELECT round(avg(accept_rate_decline_pct)::numeric,2) FROM latest WHERE accept_rate_30d < 60),0)::numeric),
      ('nps_drop',
        (SELECT count(*) FROM latest WHERE nps_drop_pct >= 20)::bigint,
        COALESCE((SELECT round(avg(nps_drop_pct)::numeric,2) FROM latest WHERE nps_drop_pct >= 20),0)::numeric),
      ('late_payouts',
        (SELECT count(*) FROM latest WHERE late_payout_count_90d > 0)::bigint,
        COALESCE((SELECT round(avg(late_payout_count_90d)::numeric,2) FROM latest WHERE late_payout_count_90d > 0),0)::numeric),
      ('mental_health_flag',
        (SELECT count(*) FROM latest WHERE mental_health_flag)::bigint,
        0::numeric),
      ('peer_neg_feedback',
        (SELECT count(*) FROM latest WHERE peer_neg_feedback_count_90d > 0)::bigint,
        COALESCE((SELECT round(avg(peer_neg_feedback_count_90d)::numeric,2) FROM latest WHERE peer_neg_feedback_count_90d > 0),0)::numeric)
  ) AS t(signal, affected_engineers, avg_contribution);
END $$;
GRANT EXECUTE ON FUNCTION founder_attrition_top_signals() TO authenticated;

COMMIT;