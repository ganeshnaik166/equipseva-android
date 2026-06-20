BEGIN;

-- ============================================================================
-- r1481 — Hospital site-visit calendar
-- Founder/CTO/sales in-person visits to hospital orgs.
-- Visit-purpose taxonomy + outcome ledger + per-hospital last-visited surface.
-- Cadence redline raised when last visit > 90d for active hospital orgs.
-- ============================================================================

-- ---------- Tables ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS hospital_site_visits (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  visitor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  visitor_role    text NOT NULL CHECK (visitor_role IN ('founder','cto','sales','field_ops','other')),
  purpose         text NOT NULL CHECK (purpose IN (
                    'discovery','demo','pilot_kickoff','contract_signing',
                    'escalation_recovery','qbr','training','support','farewell','other')),
  scheduled_at    timestamptz NOT NULL,
  visited_at      timestamptz NULL,
  status          text NOT NULL DEFAULT 'scheduled'
                    CHECK (status IN ('scheduled','completed','cancelled','no_show')),
  notes           text NULL,
  created_by      uuid NOT NULL REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsv_hospital ON hospital_site_visits(hospital_org_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_hsv_status   ON hospital_site_visits(status, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_hsv_visitor  ON hospital_site_visits(visitor_user_id, scheduled_at DESC);

CREATE TABLE IF NOT EXISTS hospital_site_visit_outcomes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id        uuid NOT NULL REFERENCES hospital_site_visits(id) ON DELETE CASCADE,
  outcome_kind    text NOT NULL CHECK (outcome_kind IN (
                    'contract_won','contract_lost','pilot_started','pilot_extended',
                    'amc_upsell','escalation_resolved','escalation_open','no_decision','followup_needed')),
  arr_impact_rupees bigint NOT NULL DEFAULT 0,
  followup_due_at timestamptz NULL,
  notes           text NULL,
  recorded_by     uuid NOT NULL REFERENCES auth.users(id),
  recorded_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsvo_visit ON hospital_site_visit_outcomes(visit_id);
CREATE INDEX IF NOT EXISTS idx_hsvo_kind  ON hospital_site_visit_outcomes(outcome_kind, recorded_at DESC);

-- ---------- RLS ------------------------------------------------------------

ALTER TABLE hospital_site_visits          ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_site_visit_outcomes  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsv_founder_all   ON hospital_site_visits;
CREATE POLICY hsv_founder_all   ON hospital_site_visits
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS hsvo_founder_all  ON hospital_site_visit_outcomes;
CREATE POLICY hsvo_founder_all  ON hospital_site_visit_outcomes
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ---------- Founder log helpers -------------------------------------------

CREATE OR REPLACE FUNCTION log_founder_site_visit_scheduled(
  p_visit_id uuid, p_hospital_org_id uuid, p_purpose text, p_scheduled_at timestamptz
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'site_visit_scheduled',
          jsonb_build_object('visit_id', p_visit_id, 'hospital_org_id', p_hospital_org_id,
                             'purpose', p_purpose, 'scheduled_at', p_scheduled_at));
END;$$;

CREATE OR REPLACE FUNCTION log_founder_site_visit_completed(
  p_visit_id uuid, p_visited_at timestamptz
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'site_visit_completed',
          jsonb_build_object('visit_id', p_visit_id, 'visited_at', p_visited_at));
END;$$;

CREATE OR REPLACE FUNCTION log_founder_site_visit_outcome(
  p_visit_id uuid, p_outcome_kind text, p_arr_impact_rupees bigint
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'site_visit_outcome',
          jsonb_build_object('visit_id', p_visit_id, 'outcome_kind', p_outcome_kind,
                             'arr_impact_rupees', p_arr_impact_rupees));
END;$$;

CREATE OR REPLACE FUNCTION log_founder_site_visit_cancelled(
  p_visit_id uuid, p_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'site_visit_cancelled',
          jsonb_build_object('visit_id', p_visit_id, 'reason', p_reason));
END;$$;

-- ---------- Read RPCs (STABLE) --------------------------------------------

CREATE OR REPLACE FUNCTION founder_site_visit_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_visits',              (SELECT count(*) FROM hospital_site_visits),
    'visits_30d',                (SELECT count(*) FROM hospital_site_visits WHERE scheduled_at >= now() - interval '30 days'),
    'visits_90d',                (SELECT count(*) FROM hospital_site_visits WHERE scheduled_at >= now() - interval '90 days'),
    'visits_completed_30d',      (SELECT count(*) FROM hospital_site_visits WHERE status='completed' AND visited_at >= now() - interval '30 days'),
    'visits_scheduled_upcoming', (SELECT count(*) FROM hospital_site_visits WHERE status='scheduled' AND scheduled_at >= now()),
    'visits_no_show_90d',        (SELECT count(*) FROM hospital_site_visits WHERE status='no_show' AND scheduled_at >= now() - interval '90 days'),
    'visits_cancelled_90d',      (SELECT count(*) FROM hospital_site_visits WHERE status='cancelled' AND scheduled_at >= now() - interval '90 days'),
    'hospitals_visited_90d',     (SELECT count(DISTINCT hospital_org_id) FROM hospital_site_visits WHERE visited_at >= now() - interval '90 days'),
    'hospitals_never_visited',   (SELECT count(*) FROM organizations o WHERE o.kind='hospital'
                                    AND NOT EXISTS (SELECT 1 FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed')),
    'hospitals_redline_90d',     (SELECT count(*) FROM (
                                    SELECT o.id, max(v.visited_at) lv
                                    FROM organizations o
                                    LEFT JOIN hospital_site_visits v ON v.hospital_org_id=o.id AND v.status='completed'
                                    WHERE o.kind='hospital'
                                    GROUP BY o.id
                                    HAVING max(v.visited_at) IS NULL OR max(v.visited_at) < now() - interval '90 days'
                                  ) x),
    'outcomes_recorded_90d',     (SELECT count(*) FROM hospital_site_visit_outcomes WHERE recorded_at >= now() - interval '90 days'),
    'arr_won_90d_rupees',        (SELECT coalesce(sum(arr_impact_rupees),0) FROM hospital_site_visit_outcomes
                                    WHERE outcome_kind IN ('contract_won','amc_upsell','pilot_started','pilot_extended')
                                      AND recorded_at >= now() - interval '90 days'),
    'arr_lost_90d_rupees',       (SELECT coalesce(sum(arr_impact_rupees),0) FROM hospital_site_visit_outcomes
                                    WHERE outcome_kind='contract_lost' AND recorded_at >= now() - interval '90 days'),
    'followups_overdue',         (SELECT count(*) FROM hospital_site_visit_outcomes
                                    WHERE followup_due_at IS NOT NULL AND followup_due_at < now()),
    'avg_days_between_visits',   (SELECT coalesce(round(avg(EXTRACT(EPOCH FROM gap)/86400.0))::int, 0) FROM (
                                    SELECT hospital_org_id,
                                           visited_at - lag(visited_at) OVER (PARTITION BY hospital_org_id ORDER BY visited_at) gap
                                    FROM hospital_site_visits WHERE status='completed' AND visited_at IS NOT NULL
                                  ) g WHERE gap IS NOT NULL),
    'distinct_visitors_90d',     (SELECT count(DISTINCT visitor_user_id) FROM hospital_site_visits WHERE scheduled_at >= now() - interval '90 days')
  ) INTO r;
  RETURN r;
END;$$;

CREATE OR REPLACE FUNCTION founder_site_visit_upcoming(p_limit int DEFAULT 100)
RETURNS TABLE(id uuid, hospital_org_id uuid, hospital_name text, visitor_user_id uuid, visitor_email text,
              visitor_role text, purpose text, scheduled_at timestamptz, status text, days_until int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.hospital_org_id, o.name, v.visitor_user_id, u.email,
         v.visitor_role, v.purpose, v.scheduled_at, v.status,
         GREATEST(0, EXTRACT(DAY FROM v.scheduled_at - now())::int)
  FROM hospital_site_visits v
  JOIN organizations o ON o.id=v.hospital_org_id
  LEFT JOIN auth.users u ON u.id=v.visitor_user_id
  WHERE v.status='scheduled' AND v.scheduled_at >= now()
  ORDER BY v.scheduled_at ASC
  LIMIT p_limit;
END;$$;

CREATE OR REPLACE FUNCTION founder_site_visit_recent_completed(p_limit int DEFAULT 100)
RETURNS TABLE(id uuid, hospital_org_id uuid, hospital_name text, visitor_email text, visitor_role text,
              purpose text, visited_at timestamptz, outcome_kind text, arr_impact_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.hospital_org_id, o.name, u.email, v.visitor_role,
         v.purpose, v.visited_at,
         (SELECT outcome_kind FROM hospital_site_visit_outcomes x WHERE x.visit_id=v.id ORDER BY recorded_at DESC LIMIT 1),
         (SELECT coalesce(arr_impact_rupees,0) FROM hospital_site_visit_outcomes x WHERE x.visit_id=v.id ORDER BY recorded_at DESC LIMIT 1)
  FROM hospital_site_visits v
  JOIN organizations o ON o.id=v.hospital_org_id
  LEFT JOIN auth.users u ON u.id=v.visitor_user_id
  WHERE v.status='completed'
  ORDER BY v.visited_at DESC NULLS LAST
  LIMIT p_limit;
END;$$;

CREATE OR REPLACE FUNCTION founder_site_visit_per_hospital()
RETURNS TABLE(hospital_org_id uuid, hospital_name text, total_visits bigint,
              last_visited_at timestamptz, days_since_last int, next_scheduled_at timestamptz,
              redline boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.name,
         coalesce((SELECT count(*) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed'),0),
         (SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed'),
         CASE WHEN (SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed') IS NULL
              THEN NULL
              ELSE EXTRACT(DAY FROM now() - (SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed'))::int
         END,
         (SELECT min(scheduled_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='scheduled' AND v.scheduled_at >= now()),
         (SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed') IS NULL
           OR (SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed') < now() - interval '90 days'
  FROM organizations o
  WHERE o.kind='hospital'
  ORDER BY (SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed') NULLS FIRST;
END;$$;

CREATE OR REPLACE FUNCTION founder_site_visit_redline_90d()
RETURNS TABLE(hospital_org_id uuid, hospital_name text, last_visited_at timestamptz,
              days_since_last int, has_active_amc boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.name,
         (SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed') lv,
         CASE WHEN (SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed') IS NULL
              THEN NULL
              ELSE EXTRACT(DAY FROM now() - (SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed'))::int
         END,
         EXISTS (SELECT 1 FROM amc_contracts a WHERE a.hospital_org_id=o.id AND a.status='active')
  FROM organizations o
  WHERE o.kind='hospital'
    AND ((SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed') IS NULL
         OR (SELECT max(visited_at) FROM hospital_site_visits v WHERE v.hospital_org_id=o.id AND v.status='completed') < now() - interval '90 days')
  ORDER BY lv NULLS FIRST;
END;$$;

CREATE OR REPLACE FUNCTION founder_site_visit_outcomes_by_kind()
RETURNS TABLE(outcome_kind text, n bigint, arr_total_rupees bigint, last_recorded_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT x.outcome_kind, count(*), coalesce(sum(x.arr_impact_rupees),0), max(x.recorded_at)
  FROM hospital_site_visit_outcomes x
  GROUP BY x.outcome_kind
  ORDER BY count(*) DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_site_visit_followups_due()
RETURNS TABLE(visit_id uuid, hospital_org_id uuid, hospital_name text, outcome_kind text,
              followup_due_at timestamptz, days_overdue int, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT x.visit_id, v.hospital_org_id, o.name, x.outcome_kind, x.followup_due_at,
         GREATEST(0, EXTRACT(DAY FROM now() - x.followup_due_at)::int), x.notes
  FROM hospital_site_visit_outcomes x
  JOIN hospital_site_visits v ON v.id=x.visit_id
  JOIN organizations o ON o.id=v.hospital_org_id
  WHERE x.followup_due_at IS NOT NULL AND x.followup_due_at < now()
  ORDER BY x.followup_due_at ASC;
END;$$;

-- ---------- Grants ---------------------------------------------------------

REVOKE EXECUTE ON FUNCTION log_founder_site_visit_scheduled(uuid, uuid, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_site_visit_completed(uuid, timestamptz)             FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_site_visit_outcome(uuid, text, bigint)              FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_site_visit_cancelled(uuid, text)                    FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_site_visit_kpis()                                       FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_site_visit_upcoming(int)                                FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_site_visit_recent_completed(int)                        FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_site_visit_per_hospital()                               FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_site_visit_redline_90d()                                FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_site_visit_outcomes_by_kind()                           FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_site_visit_followups_due()                              FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION log_founder_site_visit_scheduled(uuid, uuid, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_site_visit_completed(uuid, timestamptz)             TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_site_visit_outcome(uuid, text, bigint)              TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_site_visit_cancelled(uuid, text)                    TO authenticated;
GRANT EXECUTE ON FUNCTION founder_site_visit_kpis()                                       TO authenticated;
GRANT EXECUTE ON FUNCTION founder_site_visit_upcoming(int)                                TO authenticated;
GRANT EXECUTE ON FUNCTION founder_site_visit_recent_completed(int)                        TO authenticated;
GRANT EXECUTE ON FUNCTION founder_site_visit_per_hospital()                               TO authenticated;
GRANT EXECUTE ON FUNCTION founder_site_visit_redline_90d()                                TO authenticated;
GRANT EXECUTE ON FUNCTION founder_site_visit_outcomes_by_kind()                           TO authenticated;
GRANT EXECUTE ON FUNCTION founder_site_visit_followups_due()                              TO authenticated;

COMMIT;