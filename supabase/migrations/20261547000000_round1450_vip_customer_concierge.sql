BEGIN;

-- ============================================================
-- r1450 VIP customer concierge tracker
-- Tier-A hospital chains get white-glove SLAs:
--   - founder call cadence (every N days)
--   - executive review meetings (quarterly)
--   - NPS surveys (quarterly)
-- Flag missed touches + roll up to KPI surface.
-- ============================================================

-- ---------- TABLES ----------
CREATE TABLE IF NOT EXISTS vip_concierge_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  tier text NOT NULL CHECK (tier IN ('tier_a','tier_a_plus','strategic')),
  founder_call_cadence_days integer NOT NULL DEFAULT 14 CHECK (founder_call_cadence_days BETWEEN 1 AND 180),
  exec_review_cadence_days integer NOT NULL DEFAULT 90 CHECK (exec_review_cadence_days BETWEEN 30 AND 365),
  nps_cadence_days integer NOT NULL DEFAULT 90 CHECK (nps_cadence_days BETWEEN 30 AND 365),
  assigned_founder_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  annual_contract_value_rupees bigint NOT NULL DEFAULT 0 CHECK (annual_contract_value_rupees >= 0),
  notes text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id)
);

CREATE INDEX IF NOT EXISTS idx_vip_concierge_accounts_active ON vip_concierge_accounts(active) WHERE active;
CREATE INDEX IF NOT EXISTS idx_vip_concierge_accounts_tier ON vip_concierge_accounts(tier);

CREATE TABLE IF NOT EXISTS vip_concierge_touchpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vip_account_id uuid NOT NULL REFERENCES vip_concierge_accounts(id) ON DELETE CASCADE,
  touchpoint_kind text NOT NULL CHECK (touchpoint_kind IN ('founder_call','exec_review','nps_survey','site_visit','escalation_call')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  nps_score integer CHECK (nps_score IS NULL OR nps_score BETWEEN 0 AND 10),
  duration_minutes integer CHECK (duration_minutes IS NULL OR duration_minutes >= 0),
  outcome text CHECK (outcome IS NULL OR outcome IN ('positive','neutral','concern','at_risk')),
  notes text,
  recorded_by_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vip_touch_account_time ON vip_concierge_touchpoints(vip_account_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_vip_touch_kind_time ON vip_concierge_touchpoints(touchpoint_kind, occurred_at DESC);

ALTER TABLE vip_concierge_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE vip_concierge_touchpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vip_concierge_accounts_no_direct ON vip_concierge_accounts;
CREATE POLICY vip_concierge_accounts_no_direct ON vip_concierge_accounts FOR ALL TO authenticated USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS vip_concierge_touchpoints_no_direct ON vip_concierge_touchpoints;
CREATE POLICY vip_concierge_touchpoints_no_direct ON vip_concierge_touchpoints FOR ALL TO authenticated USING (false) WITH CHECK (false);

-- ---------- KPI SUMMARY RPC ----------
DROP FUNCTION IF EXISTS founder_vip_concierge_kpis();
CREATE OR REPLACE FUNCTION founder_vip_concierge_kpis()
RETURNS TABLE (
  active_vip_count bigint,
  tier_a_plus_count bigint,
  strategic_count bigint,
  total_acv_rupees bigint,
  avg_acv_rupees bigint,
  founder_calls_30d bigint,
  exec_reviews_90d bigint,
  nps_surveys_90d bigint,
  avg_nps_90d numeric,
  promoters_90d bigint,
  detractors_90d bigint,
  passives_90d bigint,
  missed_founder_call_count bigint,
  missed_exec_review_count bigint,
  missed_nps_count bigint,
  at_risk_account_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH acc AS (
    SELECT * FROM vip_concierge_accounts WHERE active
  ),
  recent_tp AS (
    SELECT t.* FROM vip_concierge_touchpoints t
    JOIN acc a ON a.id = t.vip_account_id
  ),
  last_per AS (
    SELECT a.id AS vip_account_id,
           a.founder_call_cadence_days,
           a.exec_review_cadence_days,
           a.nps_cadence_days,
           MAX(CASE WHEN t.touchpoint_kind='founder_call' THEN t.occurred_at END) AS last_call,
           MAX(CASE WHEN t.touchpoint_kind='exec_review' THEN t.occurred_at END) AS last_review,
           MAX(CASE WHEN t.touchpoint_kind='nps_survey'  THEN t.occurred_at END) AS last_nps,
           MAX(CASE WHEN t.touchpoint_kind='nps_survey'  THEN t.nps_score END) AS last_nps_score,
           MAX(CASE WHEN t.outcome IN ('concern','at_risk') THEN 1 ELSE 0 END) AS has_risk
    FROM acc a
    LEFT JOIN vip_concierge_touchpoints t ON t.vip_account_id = a.id
    GROUP BY a.id, a.founder_call_cadence_days, a.exec_review_cadence_days, a.nps_cadence_days
  )
  SELECT
    (SELECT count(*) FROM acc),
    (SELECT count(*) FROM acc WHERE tier='tier_a_plus'),
    (SELECT count(*) FROM acc WHERE tier='strategic'),
    COALESCE((SELECT sum(annual_contract_value_rupees) FROM acc),0)::bigint,
    COALESCE((SELECT avg(annual_contract_value_rupees)::bigint FROM acc),0)::bigint,
    (SELECT count(*) FROM recent_tp WHERE touchpoint_kind='founder_call' AND occurred_at > now() - interval '30 days'),
    (SELECT count(*) FROM recent_tp WHERE touchpoint_kind='exec_review' AND occurred_at > now() - interval '90 days'),
    (SELECT count(*) FROM recent_tp WHERE touchpoint_kind='nps_survey' AND occurred_at > now() - interval '90 days'),
    COALESCE((SELECT round(avg(nps_score)::numeric, 1) FROM recent_tp WHERE touchpoint_kind='nps_survey' AND occurred_at > now() - interval '90 days'), 0),
    (SELECT count(*) FROM recent_tp WHERE touchpoint_kind='nps_survey' AND occurred_at > now() - interval '90 days' AND nps_score >= 9),
    (SELECT count(*) FROM recent_tp WHERE touchpoint_kind='nps_survey' AND occurred_at > now() - interval '90 days' AND nps_score <= 6),
    (SELECT count(*) FROM recent_tp WHERE touchpoint_kind='nps_survey' AND occurred_at > now() - interval '90 days' AND nps_score BETWEEN 7 AND 8),
    (SELECT count(*) FROM last_per WHERE last_call IS NULL OR last_call < now() - (founder_call_cadence_days || ' days')::interval),
    (SELECT count(*) FROM last_per WHERE last_review IS NULL OR last_review < now() - (exec_review_cadence_days || ' days')::interval),
    (SELECT count(*) FROM last_per WHERE last_nps IS NULL OR last_nps < now() - (nps_cadence_days || ' days')::interval),
    (SELECT count(*) FROM last_per WHERE has_risk = 1 OR (last_nps_score IS NOT NULL AND last_nps_score <= 6));
END;
$$;
GRANT EXECUTE ON FUNCTION founder_vip_concierge_kpis() TO authenticated;

-- ---------- ACCOUNT ROSTER ----------
DROP FUNCTION IF EXISTS founder_vip_concierge_accounts();
CREATE OR REPLACE FUNCTION founder_vip_concierge_accounts()
RETURNS TABLE (
  id uuid,
  organization_id uuid,
  organization_name text,
  tier text,
  annual_contract_value_rupees bigint,
  assigned_founder text,
  founder_call_cadence_days integer,
  last_founder_call timestamptz,
  founder_call_overdue_days integer,
  last_exec_review timestamptz,
  exec_review_overdue_days integer,
  last_nps timestamptz,
  last_nps_score integer,
  health text
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
    a.id,
    a.organization_id,
    o.name,
    a.tier,
    a.annual_contract_value_rupees,
    p.full_name,
    a.founder_call_cadence_days,
    lc.last_call,
    GREATEST(0, EXTRACT(day FROM (now() - COALESCE(lc.last_call, a.created_at)))::int - a.founder_call_cadence_days),
    lr.last_review,
    GREATEST(0, EXTRACT(day FROM (now() - COALESCE(lr.last_review, a.created_at)))::int - a.exec_review_cadence_days),
    ln.last_nps,
    ln.last_nps_score,
    CASE
      WHEN ln.last_nps_score IS NOT NULL AND ln.last_nps_score <= 6 THEN 'at_risk'
      WHEN lc.last_call IS NULL OR lc.last_call < now() - (a.founder_call_cadence_days || ' days')::interval THEN 'overdue'
      WHEN lr.last_review IS NULL OR lr.last_review < now() - (a.exec_review_cadence_days || ' days')::interval THEN 'overdue'
      WHEN ln.last_nps_score >= 9 THEN 'promoter'
      ELSE 'healthy'
    END
  FROM vip_concierge_accounts a
  JOIN organizations o ON o.id = a.organization_id
  LEFT JOIN profiles p ON p.id = a.assigned_founder_user_id
  LEFT JOIN LATERAL (
    SELECT MAX(occurred_at) AS last_call FROM vip_concierge_touchpoints
    WHERE vip_account_id = a.id AND touchpoint_kind='founder_call'
  ) lc ON true
  LEFT JOIN LATERAL (
    SELECT MAX(occurred_at) AS last_review FROM vip_concierge_touchpoints
    WHERE vip_account_id = a.id AND touchpoint_kind='exec_review'
  ) lr ON true
  LEFT JOIN LATERAL (
    SELECT occurred_at AS last_nps, nps_score AS last_nps_score
    FROM vip_concierge_touchpoints
    WHERE vip_account_id = a.id AND touchpoint_kind='nps_survey'
    ORDER BY occurred_at DESC LIMIT 1
  ) ln ON true
  WHERE a.active
  ORDER BY a.annual_contract_value_rupees DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION founder_vip_concierge_accounts() TO authenticated;

-- ---------- MISSED TOUCHES ----------
DROP FUNCTION IF EXISTS founder_vip_concierge_missed_touches();
CREATE OR REPLACE FUNCTION founder_vip_concierge_missed_touches()
RETURNS TABLE (
  id uuid,
  organization_name text,
  tier text,
  touchpoint_kind text,
  cadence_days integer,
  last_touch timestamptz,
  days_overdue integer,
  acv_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH base AS (
    SELECT a.id, o.name AS org_name, a.tier, a.annual_contract_value_rupees,
           a.founder_call_cadence_days, a.exec_review_cadence_days, a.nps_cadence_days,
           a.created_at
    FROM vip_concierge_accounts a
    JOIN organizations o ON o.id = a.organization_id
    WHERE a.active
  ),
  rows AS (
    SELECT b.id, b.org_name, b.tier, 'founder_call'::text AS kind, b.founder_call_cadence_days AS cad,
           (SELECT MAX(occurred_at) FROM vip_concierge_touchpoints WHERE vip_account_id=b.id AND touchpoint_kind='founder_call') AS last_t,
           b.annual_contract_value_rupees, b.created_at
    FROM base b
    UNION ALL
    SELECT b.id, b.org_name, b.tier, 'exec_review', b.exec_review_cadence_days,
           (SELECT MAX(occurred_at) FROM vip_concierge_touchpoints WHERE vip_account_id=b.id AND touchpoint_kind='exec_review'),
           b.annual_contract_value_rupees, b.created_at
    FROM base b
    UNION ALL
    SELECT b.id, b.org_name, b.tier, 'nps_survey', b.nps_cadence_days,
           (SELECT MAX(occurred_at) FROM vip_concierge_touchpoints WHERE vip_account_id=b.id AND touchpoint_kind='nps_survey'),
           b.annual_contract_value_rupees, b.created_at
    FROM base b
  )
  SELECT r.id, r.org_name, r.tier, r.kind, r.cad, r.last_t,
         GREATEST(0, EXTRACT(day FROM (now() - COALESCE(r.last_t, r.created_at)))::int - r.cad),
         r.annual_contract_value_rupees
  FROM rows r
  WHERE r.last_t IS NULL OR r.last_t < now() - (r.cad || ' days')::interval
  ORDER BY GREATEST(0, EXTRACT(day FROM (now() - COALESCE(r.last_t, r.created_at)))::int - r.cad) DESC,
           r.annual_contract_value_rupees DESC
  LIMIT 100;
END;
$$;
GRANT EXECUTE ON FUNCTION founder_vip_concierge_missed_touches() TO authenticated;

-- ---------- RECENT TOUCHPOINTS ----------
DROP FUNCTION IF EXISTS founder_vip_concierge_recent_touchpoints();
CREATE OR REPLACE FUNCTION founder_vip_concierge_recent_touchpoints()
RETURNS TABLE (
  id uuid,
  organization_name text,
  tier text,
  touchpoint_kind text,
  occurred_at timestamptz,
  nps_score integer,
  duration_minutes integer,
  outcome text,
  recorded_by text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT t.id, o.name, a.tier, t.touchpoint_kind, t.occurred_at,
         t.nps_score, t.duration_minutes, t.outcome, p.full_name, t.notes
  FROM vip_concierge_touchpoints t
  JOIN vip_concierge_accounts a ON a.id = t.vip_account_id
  JOIN organizations o ON o.id = a.organization_id
  LEFT JOIN profiles p ON p.id = t.recorded_by_user_id
  ORDER BY t.occurred_at DESC
  LIMIT 60;
END;
$$;
GRANT EXECUTE ON FUNCTION founder_vip_concierge_recent_touchpoints() TO authenticated;

-- ---------- NPS TREND BY MONTH ----------
DROP FUNCTION IF EXISTS founder_vip_concierge_nps_trend();
CREATE OR REPLACE FUNCTION founder_vip_concierge_nps_trend()
RETURNS TABLE (
  id text,
  month_label text,
  survey_count bigint,
  avg_nps numeric,
  promoters bigint,
  passives bigint,
  detractors bigint,
  nps_index numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH m AS (
    SELECT date_trunc('month', occurred_at) AS m, nps_score
    FROM vip_concierge_touchpoints
    WHERE touchpoint_kind='nps_survey' AND occurred_at > now() - interval '12 months'
  )
  SELECT to_char(m.m, 'YYYY-MM'),
         to_char(m.m, 'Mon YYYY'),
         count(*),
         round(avg(nps_score)::numeric, 1),
         count(*) FILTER (WHERE nps_score >= 9),
         count(*) FILTER (WHERE nps_score BETWEEN 7 AND 8),
         count(*) FILTER (WHERE nps_score <= 6),
         round(((count(*) FILTER (WHERE nps_score >= 9))::numeric - (count(*) FILTER (WHERE nps_score <= 6))::numeric) * 100.0 / NULLIF(count(*),0), 1)
  FROM m
  GROUP BY m.m
  ORDER BY m.m DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION founder_vip_concierge_nps_trend() TO authenticated;

-- ---------- TOUCH MIX BY TIER ----------
DROP FUNCTION IF EXISTS founder_vip_concierge_tier_mix();
CREATE OR REPLACE FUNCTION founder_vip_concierge_tier_mix()
RETURNS TABLE (
  id text,
  tier text,
  active_accounts bigint,
  acv_rupees bigint,
  founder_calls_90d bigint,
  exec_reviews_90d bigint,
  nps_surveys_90d bigint,
  avg_nps_90d numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT a.tier,
         a.tier,
         count(DISTINCT a.id),
         COALESCE(sum(a.annual_contract_value_rupees),0)::bigint,
         count(*) FILTER (WHERE t.touchpoint_kind='founder_call' AND t.occurred_at > now() - interval '90 days'),
         count(*) FILTER (WHERE t.touchpoint_kind='exec_review' AND t.occurred_at > now() - interval '90 days'),
         count(*) FILTER (WHERE t.touchpoint_kind='nps_survey'  AND t.occurred_at > now() - interval '90 days'),
         round(avg(CASE WHEN t.touchpoint_kind='nps_survey' AND t.occurred_at > now() - interval '90 days' THEN t.nps_score END)::numeric, 1)
  FROM vip_concierge_accounts a
  LEFT JOIN vip_concierge_touchpoints t ON t.vip_account_id = a.id
  WHERE a.active
  GROUP BY a.tier
  ORDER BY a.tier;
END;
$$;
GRANT EXECUTE ON FUNCTION founder_vip_concierge_tier_mix() TO authenticated;

-- ---------- AT-RISK ACCOUNTS ----------
DROP FUNCTION IF EXISTS founder_vip_concierge_at_risk();
CREATE OR REPLACE FUNCTION founder_vip_concierge_at_risk()
RETURNS TABLE (
  id uuid,
  organization_name text,
  tier text,
  acv_rupees bigint,
  last_nps_score integer,
  last_outcome text,
  reason text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH last_n AS (
    SELECT DISTINCT ON (vip_account_id) vip_account_id, nps_score, occurred_at
    FROM vip_concierge_touchpoints
    WHERE touchpoint_kind='nps_survey'
    ORDER BY vip_account_id, occurred_at DESC
  ),
  last_o AS (
    SELECT DISTINCT ON (vip_account_id) vip_account_id, outcome, occurred_at
    FROM vip_concierge_touchpoints
    WHERE outcome IS NOT NULL
    ORDER BY vip_account_id, occurred_at DESC
  )
  SELECT a.id, o.name, a.tier, a.annual_contract_value_rupees,
         ln.nps_score, lo.outcome,
         CASE
           WHEN ln.nps_score <= 6 THEN 'detractor_nps'
           WHEN lo.outcome = 'at_risk' THEN 'manual_at_risk'
           WHEN lo.outcome = 'concern' THEN 'concern_flagged'
           ELSE 'unknown'
         END
  FROM vip_concierge_accounts a
  JOIN organizations o ON o.id = a.organization_id
  LEFT JOIN last_n ln ON ln.vip_account_id = a.id
  LEFT JOIN last_o lo ON lo.vip_account_id = a.id
  WHERE a.active
    AND (ln.nps_score <= 6 OR lo.outcome IN ('concern','at_risk'))
  ORDER BY a.annual_contract_value_rupees DESC
  LIMIT 50;
END;
$$;
GRANT EXECUTE ON FUNCTION founder_vip_concierge_at_risk() TO authenticated;

-- ---------- LOG HELPERS (VOLATILE writers) ----------
DROP FUNCTION IF EXISTS log_founder_vip_concierge_enroll(uuid, text, integer, integer, integer, bigint, text);
CREATE OR REPLACE FUNCTION log_founder_vip_concierge_enroll(
  p_org uuid,
  p_tier text,
  p_call_cad integer,
  p_review_cad integer,
  p_nps_cad integer,
  p_acv bigint,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_tier NOT IN ('tier_a','tier_a_plus','strategic') THEN RAISE EXCEPTION 'invalid_tier'; END IF;

  INSERT INTO vip_concierge_accounts (organization_id, tier, founder_call_cadence_days, exec_review_cadence_days, nps_cadence_days, annual_contract_value_rupees, notes, assigned_founder_user_id)
  VALUES (p_org, p_tier, COALESCE(p_call_cad,14), COALESCE(p_review_cad,90), COALESCE(p_nps_cad,90), COALESCE(p_acv,0), p_notes, auth.uid())
  ON CONFLICT (organization_id) DO UPDATE
    SET tier = EXCLUDED.tier,
        founder_call_cadence_days = EXCLUDED.founder_call_cadence_days,
        exec_review_cadence_days = EXCLUDED.exec_review_cadence_days,
        nps_cadence_days = EXCLUDED.nps_cadence_days,
        annual_contract_value_rupees = EXCLUDED.annual_contract_value_rupees,
        notes = EXCLUDED.notes,
        active = true,
        updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION log_founder_vip_concierge_enroll(uuid, text, integer, integer, integer, bigint, text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_vip_concierge_touchpoint(uuid, text, integer, integer, text, text);
CREATE OR REPLACE FUNCTION log_founder_vip_concierge_touchpoint(
  p_account uuid,
  p_kind text,
  p_nps integer,
  p_minutes integer,
  p_outcome text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_kind NOT IN ('founder_call','exec_review','nps_survey','site_visit','escalation_call') THEN RAISE EXCEPTION 'invalid_kind'; END IF;
  IF p_outcome IS NOT NULL AND p_outcome NOT IN ('positive','neutral','concern','at_risk') THEN RAISE EXCEPTION 'invalid_outcome'; END IF;

  INSERT INTO vip_concierge_touchpoints (vip_account_id, touchpoint_kind, nps_score, duration_minutes, outcome, notes, recorded_by_user_id)
  VALUES (p_account, p_kind, p_nps, p_minutes, p_outcome, p_notes, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION log_founder_vip_concierge_touchpoint(uuid, text, integer, integer, text, text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_vip_concierge_deactivate(uuid, text);
CREATE OR REPLACE FUNCTION log_founder_vip_concierge_deactivate(
  p_account uuid,
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
  UPDATE vip_concierge_accounts
     SET active = false,
         notes = COALESCE(notes,'') || E'\n[deactivated ' || to_char(now(),'YYYY-MM-DD') || '] ' || COALESCE(p_reason,''),
         updated_at = now()
   WHERE id = p_account;
END;
$$;
GRANT EXECUTE ON FUNCTION log_founder_vip_concierge_deactivate(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_vip_concierge_reassign(uuid, uuid);
CREATE OR REPLACE FUNCTION log_founder_vip_concierge_reassign(
  p_account uuid,
  p_new_owner uuid
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE vip_concierge_accounts
     SET assigned_founder_user_id = p_new_owner,
         updated_at = now()
   WHERE id = p_account;
END;
$$;
GRANT EXECUTE ON FUNCTION log_founder_vip_concierge_reassign(uuid, uuid) TO authenticated;

COMMIT;