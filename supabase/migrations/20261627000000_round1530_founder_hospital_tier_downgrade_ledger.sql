BEGIN;

-- ============================================================
-- r1530 — Hospital Tier Downgrade Ledger
-- Log every hospital tier downgrade event with reasons, founder
-- approval and trend-over-time analytics.
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_hospital_tier_downgrade_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  from_tier text NOT NULL CHECK (from_tier IN ('platinum','gold','silver','bronze')),
  to_tier   text NOT NULL CHECK (to_tier   IN ('platinum','gold','silver','bronze','churned')),
  reason_code text NOT NULL CHECK (reason_code IN (
    'non_payment','low_volume','sla_breach','complaints','voluntary','consolidation','other'
  )),
  reason_note text,
  amc_value_lost_rupees integer NOT NULL DEFAULT 0,
  monthly_run_rate_delta_rupees integer NOT NULL DEFAULT 0,
  founder_approval_status text NOT NULL DEFAULT 'pending'
    CHECK (founder_approval_status IN ('pending','approved','rejected','auto')),
  founder_approved_by uuid REFERENCES auth.users(id),
  founder_approved_at timestamptz,
  effective_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhtde_org_eff
  ON founder_hospital_tier_downgrade_events(hospital_org_id, effective_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhtde_status
  ON founder_hospital_tier_downgrade_events(founder_approval_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhtde_reason
  ON founder_hospital_tier_downgrade_events(reason_code, effective_at DESC);

ALTER TABLE founder_hospital_tier_downgrade_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_fhtde ON founder_hospital_tier_downgrade_events;
CREATE POLICY founder_only_fhtde ON founder_hospital_tier_downgrade_events
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS founder_hospital_tier_downgrade_reason_taxonomy (
  reason_code text PRIMARY KEY,
  display_label text NOT NULL,
  severity_weight integer NOT NULL DEFAULT 1,
  is_recoverable boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_hospital_tier_downgrade_reason_taxonomy ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_fhtde_tax ON founder_hospital_tier_downgrade_reason_taxonomy;
CREATE POLICY founder_only_fhtde_tax ON founder_hospital_tier_downgrade_reason_taxonomy
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

INSERT INTO founder_hospital_tier_downgrade_reason_taxonomy(reason_code, display_label, severity_weight, is_recoverable) VALUES
  ('non_payment','Non-payment',5,true),
  ('low_volume','Low job volume',3,true),
  ('sla_breach','SLA breach',4,true),
  ('complaints','Complaints',4,true),
  ('voluntary','Voluntary downgrade',2,true),
  ('consolidation','Consolidation',2,false),
  ('other','Other',1,true)
ON CONFLICT (reason_code) DO NOTHING;


-- ============================================================
-- Helper log_founder_* writers
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_tier_downgrade_view(p_section text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'tier_downgrade_view',
          jsonb_build_object('section', p_section, 'at', now()));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_tier_downgrade_view(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tier_downgrade_view(text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_tier_downgrade_create(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'tier_downgrade_create',
          jsonb_build_object('event_id', p_event_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_tier_downgrade_create(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tier_downgrade_create(uuid) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_tier_downgrade_approve(p_event_id uuid, p_decision text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'tier_downgrade_approve',
          jsonb_build_object('event_id', p_event_id, 'decision', p_decision));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_tier_downgrade_approve(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tier_downgrade_approve(uuid, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_tier_downgrade_export(p_window_days integer)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'tier_downgrade_export',
          jsonb_build_object('window_days', p_window_days));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_tier_downgrade_export(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tier_downgrade_export(integer) TO authenticated;


-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_founder_tier_downgrade_kpis()
RETURNS TABLE(
  total_events integer,
  events_30d integer,
  events_7d integer,
  events_pending integer,
  events_approved integer,
  events_rejected integer,
  amc_value_lost_30d integer,
  amc_value_lost_total integer,
  mrr_delta_30d integer,
  unique_hospitals_30d integer,
  reason_non_payment_30d integer,
  reason_sla_breach_30d integer,
  reason_low_volume_30d integer,
  reason_complaints_30d integer,
  avg_days_to_approval numeric,
  churn_rate_30d numeric
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
    (SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events),
    (SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events WHERE created_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events WHERE created_at > now() - interval '7 days'),
    (SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events WHERE founder_approval_status = 'pending'),
    (SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events WHERE founder_approval_status = 'approved'),
    (SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events WHERE founder_approval_status = 'rejected'),
    (SELECT COALESCE(SUM(amc_value_lost_rupees),0)::int FROM founder_hospital_tier_downgrade_events WHERE created_at > now() - interval '30 days'),
    (SELECT COALESCE(SUM(amc_value_lost_rupees),0)::int FROM founder_hospital_tier_downgrade_events),
    (SELECT COALESCE(SUM(monthly_run_rate_delta_rupees),0)::int FROM founder_hospital_tier_downgrade_events WHERE created_at > now() - interval '30 days'),
    (SELECT COUNT(DISTINCT hospital_org_id)::int FROM founder_hospital_tier_downgrade_events WHERE created_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events WHERE reason_code = 'non_payment' AND created_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events WHERE reason_code = 'sla_breach' AND created_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events WHERE reason_code = 'low_volume' AND created_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events WHERE reason_code = 'complaints' AND created_at > now() - interval '30 days'),
    (SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (founder_approved_at - created_at))/86400.0), 0)::numeric
       FROM founder_hospital_tier_downgrade_events
       WHERE founder_approved_at IS NOT NULL),
    (SELECT CASE WHEN COUNT(*) = 0 THEN 0
            ELSE (COUNT(*) FILTER (WHERE to_tier = 'churned'))::numeric / COUNT(*)::numeric END
       FROM founder_hospital_tier_downgrade_events
       WHERE created_at > now() - interval '30 days');
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_tier_downgrade_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_downgrade_kpis() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_downgrade_recent(p_limit integer)
RETURNS TABLE(
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  from_tier text,
  to_tier text,
  reason_code text,
  amc_value_lost_rupees integer,
  founder_approval_status text,
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
  SELECT e.id, e.hospital_org_id, COALESCE(o.name,'(unknown)'),
         e.from_tier, e.to_tier, e.reason_code,
         e.amc_value_lost_rupees, e.founder_approval_status, e.created_at
  FROM founder_hospital_tier_downgrade_events e
  LEFT JOIN organizations o ON o.id = e.hospital_org_id
  ORDER BY e.created_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_tier_downgrade_recent(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_downgrade_recent(integer) TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_downgrade_pending()
RETURNS TABLE(
  id uuid,
  hospital_name text,
  from_tier text,
  to_tier text,
  reason_code text,
  reason_note text,
  amc_value_lost_rupees integer,
  age_days numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, COALESCE(o.name,'(unknown)'),
         e.from_tier, e.to_tier, e.reason_code, e.reason_note,
         e.amc_value_lost_rupees,
         (EXTRACT(EPOCH FROM (now() - e.created_at))/86400.0)::numeric
  FROM founder_hospital_tier_downgrade_events e
  LEFT JOIN organizations o ON o.id = e.hospital_org_id
  WHERE e.founder_approval_status = 'pending'
  ORDER BY e.created_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_tier_downgrade_pending() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_downgrade_pending() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_downgrade_by_reason()
RETURNS TABLE(
  reason_code text,
  display_label text,
  events_30d integer,
  events_90d integer,
  amc_value_lost_30d integer,
  severity_weight integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.reason_code, t.display_label,
    COALESCE((SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events e
              WHERE e.reason_code = t.reason_code AND e.created_at > now() - interval '30 days'), 0),
    COALESCE((SELECT COUNT(*)::int FROM founder_hospital_tier_downgrade_events e
              WHERE e.reason_code = t.reason_code AND e.created_at > now() - interval '90 days'), 0),
    COALESCE((SELECT SUM(amc_value_lost_rupees)::int FROM founder_hospital_tier_downgrade_events e
              WHERE e.reason_code = t.reason_code AND e.created_at > now() - interval '30 days'), 0),
    t.severity_weight
  FROM founder_hospital_tier_downgrade_reason_taxonomy t
  ORDER BY t.severity_weight DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_tier_downgrade_by_reason() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_downgrade_by_reason() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_downgrade_trend_weekly()
RETURNS TABLE(
  week_start date,
  event_count integer,
  unique_hospitals integer,
  amc_value_lost_rupees integer,
  churned_count integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (date_trunc('week', created_at))::date,
         COUNT(*)::int,
         COUNT(DISTINCT hospital_org_id)::int,
         COALESCE(SUM(amc_value_lost_rupees),0)::int,
         COUNT(*) FILTER (WHERE to_tier = 'churned')::int
  FROM founder_hospital_tier_downgrade_events
  WHERE created_at > now() - interval '12 weeks'
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_tier_downgrade_trend_weekly() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_downgrade_trend_weekly() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_downgrade_top_hospitals()
RETURNS TABLE(
  hospital_org_id uuid,
  hospital_name text,
  downgrade_events integer,
  total_amc_lost_rupees integer,
  last_event_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.hospital_org_id, COALESCE(o.name,'(unknown)'),
         COUNT(*)::int,
         COALESCE(SUM(e.amc_value_lost_rupees),0)::int,
         MAX(e.created_at)
  FROM founder_hospital_tier_downgrade_events e
  LEFT JOIN organizations o ON o.id = e.hospital_org_id
  GROUP BY e.hospital_org_id, o.name
  ORDER BY COUNT(*) DESC, COALESCE(SUM(e.amc_value_lost_rupees),0) DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_tier_downgrade_top_hospitals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_downgrade_top_hospitals() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_downgrade_approval_funnel()
RETURNS TABLE(
  status text,
  event_count integer,
  amc_value_rupees integer,
  avg_age_days numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.founder_approval_status,
         COUNT(*)::int,
         COALESCE(SUM(e.amc_value_lost_rupees),0)::int,
         COALESCE(AVG(EXTRACT(EPOCH FROM (now() - e.created_at))/86400.0),0)::numeric
  FROM founder_hospital_tier_downgrade_events e
  GROUP BY e.founder_approval_status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_tier_downgrade_approval_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_downgrade_approval_funnel() TO authenticated;

COMMIT;