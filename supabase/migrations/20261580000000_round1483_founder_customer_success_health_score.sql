BEGIN;

-- =========================================================================
-- r1483 — Founder customer-success health-score ladder
-- Aggregates NPS + AMC payment cadence + ticket volume + escalation count
-- into a 1-100 health score per account. Surfaces at-risk + champion candidates.
-- =========================================================================

-- ---- Tables -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS founder_cs_health_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  captured_at timestamptz NOT NULL DEFAULT now(),
  nps_score numeric(5,2),
  amc_cadence_score numeric(5,2),
  ticket_volume_score numeric(5,2),
  escalation_score numeric(5,2),
  composite_score numeric(5,2) NOT NULL CHECK (composite_score >= 0 AND composite_score <= 100),
  band text NOT NULL CHECK (band IN ('at_risk','watch','steady','champion')),
  rationale text,
  created_by uuid REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_fcshs_org ON founder_cs_health_snapshots(organization_id, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_fcshs_band ON founder_cs_health_snapshots(band, captured_at DESC);

ALTER TABLE founder_cs_health_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_select_fcshs ON founder_cs_health_snapshots;
CREATE POLICY founder_only_select_fcshs ON founder_cs_health_snapshots
  FOR SELECT USING (is_founder());

DROP POLICY IF EXISTS founder_only_write_fcshs ON founder_cs_health_snapshots;
CREATE POLICY founder_only_write_fcshs ON founder_cs_health_snapshots
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS founder_cs_health_interventions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  intervention_type text NOT NULL CHECK (intervention_type IN ('founder_call','exec_visit','discount_offer','engineer_swap','renewal_push','champion_nurture')),
  notes text,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  outcome text CHECK (outcome IN ('pending','recovered','churned','escalated','converted_champion')),
  created_by uuid REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_fcshi_org ON founder_cs_health_interventions(organization_id, opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_fcshi_outcome ON founder_cs_health_interventions(outcome, opened_at DESC);

ALTER TABLE founder_cs_health_interventions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_select_fcshi ON founder_cs_health_interventions;
CREATE POLICY founder_only_select_fcshi ON founder_cs_health_interventions
  FOR SELECT USING (is_founder());

DROP POLICY IF EXISTS founder_only_write_fcshi ON founder_cs_health_interventions;
CREATE POLICY founder_only_write_fcshi ON founder_cs_health_interventions
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());


-- ---- READ RPCs ----------------------------------------------------------

CREATE OR REPLACE FUNCTION founder_cs_health_summary()
RETURNS TABLE (
  total_accounts bigint,
  at_risk_count bigint,
  watch_count bigint,
  steady_count bigint,
  champion_count bigint,
  avg_score numeric,
  median_score numeric,
  open_interventions bigint,
  closed_recovered bigint,
  closed_churned bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (organization_id) organization_id, composite_score, band
    FROM founder_cs_health_snapshots
    ORDER BY organization_id, captured_at DESC
  )
  SELECT
    (SELECT COUNT(*) FROM latest),
    (SELECT COUNT(*) FROM latest WHERE band='at_risk'),
    (SELECT COUNT(*) FROM latest WHERE band='watch'),
    (SELECT COUNT(*) FROM latest WHERE band='steady'),
    (SELECT COUNT(*) FROM latest WHERE band='champion'),
    COALESCE((SELECT AVG(composite_score) FROM latest), 0)::numeric,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY composite_score) FROM latest), 0)::numeric,
    (SELECT COUNT(*) FROM founder_cs_health_interventions WHERE closed_at IS NULL),
    (SELECT COUNT(*) FROM founder_cs_health_interventions WHERE outcome='recovered'),
    (SELECT COUNT(*) FROM founder_cs_health_interventions WHERE outcome='churned');
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cs_health_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cs_health_summary() TO authenticated;


CREATE OR REPLACE FUNCTION founder_cs_health_at_risk(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  organization_id uuid,
  org_name text,
  composite_score numeric,
  band text,
  captured_at timestamptz,
  rationale text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.organization_id) s.*
    FROM founder_cs_health_snapshots s
    ORDER BY s.organization_id, s.captured_at DESC
  )
  SELECT l.id, l.organization_id, o.name, l.composite_score, l.band, l.captured_at, l.rationale
  FROM latest l
  JOIN organizations o ON o.id = l.organization_id
  WHERE l.band IN ('at_risk','watch')
  ORDER BY l.composite_score ASC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cs_health_at_risk(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cs_health_at_risk(int) TO authenticated;


CREATE OR REPLACE FUNCTION founder_cs_health_champions(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  organization_id uuid,
  org_name text,
  composite_score numeric,
  nps_score numeric,
  captured_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.organization_id) s.*
    FROM founder_cs_health_snapshots s
    ORDER BY s.organization_id, s.captured_at DESC
  )
  SELECT l.id, l.organization_id, o.name, l.composite_score, l.nps_score, l.captured_at
  FROM latest l
  JOIN organizations o ON o.id = l.organization_id
  WHERE l.band = 'champion'
  ORDER BY l.composite_score DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cs_health_champions(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cs_health_champions(int) TO authenticated;


CREATE OR REPLACE FUNCTION founder_cs_health_band_breakdown()
RETURNS TABLE (
  band text,
  account_count bigint,
  avg_score numeric,
  min_score numeric,
  max_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (organization_id) organization_id, composite_score, band
    FROM founder_cs_health_snapshots
    ORDER BY organization_id, captured_at DESC
  )
  SELECT l.band, COUNT(*)::bigint, AVG(l.composite_score)::numeric, MIN(l.composite_score)::numeric, MAX(l.composite_score)::numeric
  FROM latest l
  GROUP BY l.band
  ORDER BY CASE l.band WHEN 'at_risk' THEN 1 WHEN 'watch' THEN 2 WHEN 'steady' THEN 3 WHEN 'champion' THEN 4 END;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cs_health_band_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cs_health_band_breakdown() TO authenticated;


CREATE OR REPLACE FUNCTION founder_cs_health_recent_interventions(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  organization_id uuid,
  org_name text,
  intervention_type text,
  opened_at timestamptz,
  closed_at timestamptz,
  outcome text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.organization_id, o.name, i.intervention_type, i.opened_at, i.closed_at, i.outcome, i.notes
  FROM founder_cs_health_interventions i
  JOIN organizations o ON o.id = i.organization_id
  ORDER BY i.opened_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cs_health_recent_interventions(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cs_health_recent_interventions(int) TO authenticated;


CREATE OR REPLACE FUNCTION founder_cs_health_score_trend(p_days int DEFAULT 30)
RETURNS TABLE (
  day date,
  avg_score numeric,
  at_risk_count bigint,
  champion_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (s.captured_at AT TIME ZONE 'Asia/Kolkata')::date,
         AVG(s.composite_score)::numeric,
         COUNT(*) FILTER (WHERE s.band='at_risk')::bigint,
         COUNT(*) FILTER (WHERE s.band='champion')::bigint
  FROM founder_cs_health_snapshots s
  WHERE s.captured_at >= now() - make_interval(days => GREATEST(p_days,1))
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cs_health_score_trend(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cs_health_score_trend(int) TO authenticated;


CREATE OR REPLACE FUNCTION founder_cs_health_intervention_efficacy()
RETURNS TABLE (
  intervention_type text,
  total_opened bigint,
  recovered bigint,
  churned bigint,
  recovery_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.intervention_type,
         COUNT(*)::bigint AS total_opened,
         COUNT(*) FILTER (WHERE i.outcome='recovered')::bigint AS recovered,
         COUNT(*) FILTER (WHERE i.outcome='churned')::bigint AS churned,
         CASE WHEN COUNT(*) FILTER (WHERE i.outcome IN ('recovered','churned')) > 0
              THEN (COUNT(*) FILTER (WHERE i.outcome='recovered')::numeric * 100.0
                    / COUNT(*) FILTER (WHERE i.outcome IN ('recovered','churned'))::numeric)
              ELSE 0 END
  FROM founder_cs_health_interventions i
  GROUP BY i.intervention_type
  ORDER BY recovered DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cs_health_intervention_efficacy() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cs_health_intervention_efficacy() TO authenticated;


-- ---- WRITE / LOG helpers (VOLATILE) -------------------------------------

CREATE OR REPLACE FUNCTION log_founder_cs_snapshot(
  p_org uuid,
  p_nps numeric,
  p_amc numeric,
  p_tickets numeric,
  p_escalations numeric,
  p_composite numeric,
  p_band text,
  p_rationale text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_cs_health_snapshots (organization_id, nps_score, amc_cadence_score, ticket_volume_score, escalation_score, composite_score, band, rationale, created_by)
  VALUES (p_org, p_nps, p_amc, p_tickets, p_escalations, p_composite, p_band, p_rationale, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_cs_snapshot(uuid,numeric,numeric,numeric,numeric,numeric,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cs_snapshot(uuid,numeric,numeric,numeric,numeric,numeric,text,text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_cs_intervention_open(
  p_org uuid,
  p_type text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_cs_health_interventions (organization_id, intervention_type, notes, outcome, created_by)
  VALUES (p_org, p_type, p_notes, 'pending', auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_cs_intervention_open(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cs_intervention_open(uuid,text,text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_cs_intervention_close(
  p_id uuid,
  p_outcome text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_cs_health_interventions
     SET closed_at = now(), outcome = p_outcome
   WHERE id = p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_cs_intervention_close(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cs_intervention_close(uuid,text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_cs_snapshot_purge(p_days int)
RETURNS bigint
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH d AS (
    DELETE FROM founder_cs_health_snapshots
    WHERE captured_at < now() - make_interval(days => GREATEST(p_days,1))
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_count FROM d;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_cs_snapshot_purge(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cs_snapshot_purge(int) TO authenticated;

COMMIT;