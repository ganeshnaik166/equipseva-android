BEGIN;

-- Round 1526: Hospital escalation routing v2 — severity + AMC tier + history-based routing,
-- per-route SLA, auto-escalate on breach.

CREATE TABLE IF NOT EXISTS hospital_escalation_routes_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  opened_by_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  amc_tier_at_open text,
  prior_escalations_count int NOT NULL DEFAULT 0,
  route_to text NOT NULL CHECK (route_to IN ('founder','cto','sales','ops')),
  routing_reason text NOT NULL,
  sla_minutes int NOT NULL,
  opened_at timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz,
  resolved_at timestamptz,
  breached boolean NOT NULL DEFAULT false,
  breached_at timestamptz,
  auto_escalated_to text,
  auto_escalated_at timestamptz,
  notes text
);

CREATE INDEX IF NOT EXISTS hosp_esc_v2_open_idx
  ON hospital_escalation_routes_v2 (opened_at DESC);
CREATE INDEX IF NOT EXISTS hosp_esc_v2_hosp_idx
  ON hospital_escalation_routes_v2 (hospital_org_id, opened_at DESC);
CREATE INDEX IF NOT EXISTS hosp_esc_v2_route_idx
  ON hospital_escalation_routes_v2 (route_to, breached);

ALTER TABLE hospital_escalation_routes_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hosp_esc_v2_founder ON hospital_escalation_routes_v2;
CREATE POLICY hosp_esc_v2_founder ON hospital_escalation_routes_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_escalation_route_audit_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id uuid NOT NULL REFERENCES hospital_escalation_routes_v2(id) ON DELETE CASCADE,
  action text NOT NULL,
  actor_user_id uuid,
  actor_email text,
  details jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hosp_esc_v2_audit_route_idx
  ON hospital_escalation_route_audit_v2 (route_id, created_at DESC);

ALTER TABLE hospital_escalation_route_audit_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hosp_esc_v2_audit_founder ON hospital_escalation_route_audit_v2;
CREATE POLICY hosp_esc_v2_audit_founder ON hospital_escalation_route_audit_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- log_founder helpers -------------------------------------------------------

CREATE OR REPLACE FUNCTION log_founder_route_open(p_route_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hosp_esc_v2_route_open', p_payload);
  INSERT INTO hospital_escalation_route_audit_v2 (route_id, action, actor_user_id, actor_email, details)
  VALUES (p_route_id, 'route_open', auth.uid(), (auth.jwt()->>'email'), p_payload);
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_route_ack(p_route_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hosp_esc_v2_route_ack', p_payload);
  INSERT INTO hospital_escalation_route_audit_v2 (route_id, action, actor_user_id, actor_email, details)
  VALUES (p_route_id, 'route_ack', auth.uid(), (auth.jwt()->>'email'), p_payload);
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_route_breach(p_route_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hosp_esc_v2_breach', p_payload);
  INSERT INTO hospital_escalation_route_audit_v2 (route_id, action, actor_user_id, actor_email, details)
  VALUES (p_route_id, 'breach', auth.uid(), (auth.jwt()->>'email'), p_payload);
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_route_auto_escalate(p_route_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hosp_esc_v2_auto_escalate', p_payload);
  INSERT INTO hospital_escalation_route_audit_v2 (route_id, action, actor_user_id, actor_email, details)
  VALUES (p_route_id, 'auto_escalate', auth.uid(), (auth.jwt()->>'email'), p_payload);
END;
$$;

-- Read RPCs (STABLE) --------------------------------------------------------

CREATE OR REPLACE FUNCTION founder_hosp_esc_v2_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'open_total',           COUNT(*) FILTER (WHERE resolved_at IS NULL),
    'open_p0',              COUNT(*) FILTER (WHERE resolved_at IS NULL AND severity='p0'),
    'open_p1',              COUNT(*) FILTER (WHERE resolved_at IS NULL AND severity='p1'),
    'open_p2',              COUNT(*) FILTER (WHERE resolved_at IS NULL AND severity='p2'),
    'open_p3',              COUNT(*) FILTER (WHERE resolved_at IS NULL AND severity='p3'),
    'route_founder',        COUNT(*) FILTER (WHERE resolved_at IS NULL AND route_to='founder'),
    'route_cto',            COUNT(*) FILTER (WHERE resolved_at IS NULL AND route_to='cto'),
    'route_sales',          COUNT(*) FILTER (WHERE resolved_at IS NULL AND route_to='sales'),
    'route_ops',            COUNT(*) FILTER (WHERE resolved_at IS NULL AND route_to='ops'),
    'breached_open',        COUNT(*) FILTER (WHERE resolved_at IS NULL AND breached),
    'auto_escalated_open',  COUNT(*) FILTER (WHERE resolved_at IS NULL AND auto_escalated_at IS NOT NULL),
    'resolved_7d',          COUNT(*) FILTER (WHERE resolved_at IS NOT NULL AND resolved_at > now() - interval '7 days'),
    'opened_7d',            COUNT(*) FILTER (WHERE opened_at > now() - interval '7 days'),
    'avg_ack_minutes_7d',   COALESCE(AVG(EXTRACT(EPOCH FROM (acknowledged_at - opened_at))/60.0)
                                     FILTER (WHERE acknowledged_at IS NOT NULL AND opened_at > now() - interval '7 days'), 0),
    'avg_resolve_hours_7d', COALESCE(AVG(EXTRACT(EPOCH FROM (resolved_at - opened_at))/3600.0)
                                     FILTER (WHERE resolved_at IS NOT NULL AND resolved_at > now() - interval '7 days'), 0),
    'breach_rate_7d',       CASE WHEN COUNT(*) FILTER (WHERE opened_at > now() - interval '7 days') > 0
                              THEN (COUNT(*) FILTER (WHERE breached AND opened_at > now() - interval '7 days'))::numeric
                                   / COUNT(*) FILTER (WHERE opened_at > now() - interval '7 days') * 100.0
                              ELSE 0 END
  )
  INTO v
  FROM hospital_escalation_routes_v2;
  RETURN v;
END;
$$;

CREATE OR REPLACE FUNCTION founder_hosp_esc_v2_open()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  severity text,
  route_to text,
  amc_tier_at_open text,
  prior_escalations_count int,
  sla_minutes int,
  opened_at timestamptz,
  acknowledged_at timestamptz,
  breached boolean,
  age_minutes numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_org_id, o.name,
         r.severity, r.route_to, r.amc_tier_at_open,
         r.prior_escalations_count, r.sla_minutes,
         r.opened_at, r.acknowledged_at, r.breached,
         EXTRACT(EPOCH FROM (now() - r.opened_at))/60.0
  FROM hospital_escalation_routes_v2 r
  LEFT JOIN organizations o ON o.id = r.hospital_org_id
  WHERE r.resolved_at IS NULL
  ORDER BY
    CASE r.severity WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    r.opened_at ASC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_hosp_esc_v2_breached()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  severity text,
  route_to text,
  sla_minutes int,
  opened_at timestamptz,
  breached_at timestamptz,
  auto_escalated_to text,
  minutes_over_sla numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, o.name, r.severity, r.route_to, r.sla_minutes,
         r.opened_at, r.breached_at, r.auto_escalated_to,
         (EXTRACT(EPOCH FROM (COALESCE(r.resolved_at, now()) - r.opened_at))/60.0) - r.sla_minutes
  FROM hospital_escalation_routes_v2 r
  LEFT JOIN organizations o ON o.id = r.hospital_org_id
  WHERE r.breached
  ORDER BY r.breached_at DESC NULLS LAST
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION founder_hosp_esc_v2_by_route()
RETURNS TABLE (
  route_to text,
  open_count bigint,
  breached_count bigint,
  avg_ack_minutes numeric,
  avg_resolve_hours numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.route_to,
         COUNT(*) FILTER (WHERE r.resolved_at IS NULL),
         COUNT(*) FILTER (WHERE r.breached),
         COALESCE(AVG(EXTRACT(EPOCH FROM (r.acknowledged_at - r.opened_at))/60.0)
                  FILTER (WHERE r.acknowledged_at IS NOT NULL), 0),
         COALESCE(AVG(EXTRACT(EPOCH FROM (r.resolved_at - r.opened_at))/3600.0)
                  FILTER (WHERE r.resolved_at IS NOT NULL), 0)
  FROM hospital_escalation_routes_v2 r
  GROUP BY r.route_to
  ORDER BY r.route_to;
END;
$$;

CREATE OR REPLACE FUNCTION founder_hosp_esc_v2_top_hospitals()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  escalations_30d bigint,
  breach_count bigint,
  last_opened_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.hospital_org_id, o.name,
         COUNT(*) FILTER (WHERE r.opened_at > now() - interval '30 days'),
         COUNT(*) FILTER (WHERE r.breached),
         MAX(r.opened_at)
  FROM hospital_escalation_routes_v2 r
  LEFT JOIN organizations o ON o.id = r.hospital_org_id
  GROUP BY r.hospital_org_id, o.name
  HAVING COUNT(*) FILTER (WHERE r.opened_at > now() - interval '30 days') > 0
  ORDER BY COUNT(*) FILTER (WHERE r.opened_at > now() - interval '30 days') DESC
  LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION founder_hosp_esc_v2_recent_audit()
RETURNS TABLE (
  id uuid,
  route_id uuid,
  action text,
  actor_email text,
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
  SELECT a.id, a.route_id, a.action, a.actor_email, a.created_at
  FROM hospital_escalation_route_audit_v2 a
  ORDER BY a.created_at DESC
  LIMIT 50;
END;
$$;

-- Write RPC (VOLATILE) — auto-escalate breached routes
CREATE OR REPLACE FUNCTION founder_hosp_esc_v2_auto_escalate_breaches()
RETURNS int
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  n int := 0;
  new_route text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  FOR r IN
    SELECT * FROM hospital_escalation_routes_v2
    WHERE resolved_at IS NULL
      AND auto_escalated_at IS NULL
      AND EXTRACT(EPOCH FROM (now() - opened_at))/60.0 > sla_minutes
  LOOP
    new_route := CASE r.route_to
                   WHEN 'ops'    THEN 'sales'
                   WHEN 'sales'  THEN 'cto'
                   WHEN 'cto'    THEN 'founder'
                   ELSE 'founder'
                 END;
    UPDATE hospital_escalation_routes_v2
       SET breached = true,
           breached_at = COALESCE(breached_at, now()),
           auto_escalated_to = new_route,
           auto_escalated_at = now()
     WHERE id = r.id;
    PERFORM log_founder_route_breach(r.id, jsonb_build_object('severity', r.severity, 'from_route', r.route_to));
    PERFORM log_founder_route_auto_escalate(r.id, jsonb_build_object('from_route', r.route_to, 'to_route', new_route));
    n := n + 1;
  END LOOP;
  RETURN n;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_route_open(uuid, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_route_ack(uuid, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_route_breach(uuid, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_route_auto_escalate(uuid, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hosp_esc_v2_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hosp_esc_v2_open() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hosp_esc_v2_breached() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hosp_esc_v2_by_route() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hosp_esc_v2_top_hospitals() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hosp_esc_v2_recent_audit() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hosp_esc_v2_auto_escalate_breaches() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION log_founder_route_open(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_route_ack(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_route_breach(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_route_auto_escalate(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hosp_esc_v2_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hosp_esc_v2_open() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hosp_esc_v2_breached() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hosp_esc_v2_by_route() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hosp_esc_v2_top_hospitals() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hosp_esc_v2_recent_audit() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hosp_esc_v2_auto_escalate_breaches() TO authenticated;

COMMIT;