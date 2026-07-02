BEGIN;

-- ============================================================
-- r1592 — Founder Investor ESOP Grant Ledger
-- Log ESOP grants, vesting (1y cliff + monthly), unvested
-- balance per grantee, founder approval audit.
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_esop_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grantee_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  grantee_email text NOT NULL,
  grantee_name text NOT NULL,
  grantee_role text,
  options_granted integer NOT NULL CHECK (options_granted > 0),
  strike_price_rupees numeric(12,2) NOT NULL CHECK (strike_price_rupees >= 0),
  grant_date date NOT NULL DEFAULT CURRENT_DATE,
  cliff_months integer NOT NULL DEFAULT 12 CHECK (cliff_months >= 0),
  vest_months_total integer NOT NULL DEFAULT 48 CHECK (vest_months_total > 0),
  status text NOT NULL DEFAULT 'pending_approval' CHECK (status IN ('pending_approval','approved','rejected','cancelled','exercised')),
  approved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_esop_grants_grantee ON founder_esop_grants(grantee_user_id);
CREATE INDEX IF NOT EXISTS idx_esop_grants_status ON founder_esop_grants(status);
CREATE INDEX IF NOT EXISTS idx_esop_grants_grant_date ON founder_esop_grants(grant_date);

ALTER TABLE founder_esop_grants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_esop_grants_founder_all ON founder_esop_grants;
CREATE POLICY p_esop_grants_founder_all ON founder_esop_grants
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS founder_esop_grant_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grant_id uuid NOT NULL REFERENCES founder_esop_grants(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('created','approved','rejected','cancelled','exercised','note_added')),
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_email text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_esop_events_grant ON founder_esop_grant_events(grant_id);
CREATE INDEX IF NOT EXISTS idx_esop_events_occurred ON founder_esop_grant_events(occurred_at);

ALTER TABLE founder_esop_grant_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_esop_events_founder_all ON founder_esop_grant_events;
CREATE POLICY p_esop_events_founder_all ON founder_esop_grant_events
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


-- ============================================================
-- log helpers (VOLATILE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_esop_grant_created(
  p_grant_id uuid, p_payload jsonb
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_esop_grant_events(grant_id, event_type, actor_user_id, actor_email, payload)
  VALUES (p_grant_id, 'created', auth.uid(), (auth.jwt()->>'email'), COALESCE(p_payload,'{}'::jsonb));
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'esop_grant_created', jsonb_build_object('grant_id', p_grant_id, 'payload', p_payload));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_esop_grant_created(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_esop_grant_created(uuid, jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_esop_grant_approved(
  p_grant_id uuid, p_payload jsonb
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_esop_grant_events(grant_id, event_type, actor_user_id, actor_email, payload)
  VALUES (p_grant_id, 'approved', auth.uid(), (auth.jwt()->>'email'), COALESCE(p_payload,'{}'::jsonb));
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'esop_grant_approved', jsonb_build_object('grant_id', p_grant_id));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_esop_grant_approved(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_esop_grant_approved(uuid, jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_esop_grant_rejected(
  p_grant_id uuid, p_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_esop_grant_events(grant_id, event_type, actor_user_id, actor_email, payload)
  VALUES (p_grant_id, 'rejected', auth.uid(), (auth.jwt()->>'email'), jsonb_build_object('reason', p_reason));
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'esop_grant_rejected', jsonb_build_object('grant_id', p_grant_id, 'reason', p_reason));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_esop_grant_rejected(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_esop_grant_rejected(uuid, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_esop_grant_cancelled(
  p_grant_id uuid, p_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_esop_grant_events(grant_id, event_type, actor_user_id, actor_email, payload)
  VALUES (p_grant_id, 'cancelled', auth.uid(), (auth.jwt()->>'email'), jsonb_build_object('reason', p_reason));
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'esop_grant_cancelled', jsonb_build_object('grant_id', p_grant_id, 'reason', p_reason));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_esop_grant_cancelled(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_esop_grant_cancelled(uuid, text) TO authenticated;


-- ============================================================
-- Read RPCs (STABLE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_esop_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH g AS (
    SELECT *,
      GREATEST(0, LEAST(vest_months_total,
        FLOOR(EXTRACT(EPOCH FROM (now() - (grant_date::timestamptz)))/86400.0/30.4375)::int
      )) AS months_elapsed
    FROM founder_esop_grants
  ),
  v AS (
    SELECT *,
      CASE
        WHEN status <> 'approved' THEN 0
        WHEN months_elapsed < cliff_months THEN 0
        ELSE FLOOR(options_granted::numeric * months_elapsed / vest_months_total)::int
      END AS vested
    FROM g
  )
  SELECT jsonb_build_object(
    'total_grants', (SELECT COUNT(*) FROM founder_esop_grants),
    'pending_grants', (SELECT COUNT(*) FROM founder_esop_grants WHERE status='pending_approval'),
    'approved_grants', (SELECT COUNT(*) FROM founder_esop_grants WHERE status='approved'),
    'rejected_grants', (SELECT COUNT(*) FROM founder_esop_grants WHERE status='rejected'),
    'cancelled_grants', (SELECT COUNT(*) FROM founder_esop_grants WHERE status='cancelled'),
    'exercised_grants', (SELECT COUNT(*) FROM founder_esop_grants WHERE status='exercised'),
    'unique_grantees', (SELECT COUNT(DISTINCT grantee_email) FROM founder_esop_grants),
    'total_options_granted', COALESCE((SELECT SUM(options_granted) FROM founder_esop_grants WHERE status='approved'),0),
    'total_options_vested', COALESCE((SELECT SUM(vested) FROM v),0),
    'total_options_unvested', COALESCE((SELECT SUM(options_granted - vested) FROM v WHERE status='approved'),0),
    'avg_strike_rupees', COALESCE((SELECT ROUND(AVG(strike_price_rupees),2) FROM founder_esop_grants WHERE status='approved'),0),
    'in_cliff_grants', (SELECT COUNT(*) FROM v WHERE status='approved' AND months_elapsed < cliff_months),
    'past_cliff_grants', (SELECT COUNT(*) FROM v WHERE status='approved' AND months_elapsed >= cliff_months),
    'fully_vested_grants', (SELECT COUNT(*) FROM v WHERE status='approved' AND months_elapsed >= vest_months_total),
    'grants_last_30d', (SELECT COUNT(*) FROM founder_esop_grants WHERE created_at > now() - interval '30 days'),
    'events_last_7d', (SELECT COUNT(*) FROM founder_esop_grant_events WHERE occurred_at > now() - interval '7 days')
  ) INTO r;
  RETURN r;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_esop_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_esop_kpis() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_esop_grants_list(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid, grantee_name text, grantee_email text, grantee_role text,
  options_granted int, strike_price_rupees numeric, status text,
  grant_date date, cliff_months int, vest_months_total int,
  approved_at timestamptz, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.grantee_name, g.grantee_email, g.grantee_role,
         g.options_granted, g.strike_price_rupees, g.status,
         g.grant_date, g.cliff_months, g.vest_months_total,
         g.approved_at, g.created_at
  FROM founder_esop_grants g
  ORDER BY g.created_at DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 200));
END $$;
REVOKE EXECUTE ON FUNCTION rpc_esop_grants_list(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_esop_grants_list(int) TO authenticated;


CREATE OR REPLACE FUNCTION rpc_esop_vesting_per_grantee()
RETURNS TABLE(
  grantee_email text, grantee_name text,
  options_granted bigint, options_vested bigint, options_unvested bigint,
  grants_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH g AS (
    SELECT *,
      GREATEST(0, LEAST(vest_months_total,
        FLOOR(EXTRACT(EPOCH FROM (now() - (grant_date::timestamptz)))/86400.0/30.4375)::int
      )) AS months_elapsed
    FROM founder_esop_grants
    WHERE status='approved'
  ),
  v AS (
    SELECT grantee_email, grantee_name, options_granted,
      CASE WHEN months_elapsed < cliff_months THEN 0
           ELSE FLOOR(options_granted::numeric * months_elapsed / vest_months_total)::int
      END AS vested
    FROM g
  )
  SELECT v.grantee_email, MAX(v.grantee_name)::text,
         SUM(v.options_granted)::bigint,
         SUM(v.vested)::bigint,
         SUM(v.options_granted - v.vested)::bigint,
         COUNT(*)::bigint
  FROM v
  GROUP BY v.grantee_email
  ORDER BY SUM(v.options_granted) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_esop_vesting_per_grantee() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_esop_vesting_per_grantee() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_esop_pending_approvals()
RETURNS TABLE(
  id uuid, grantee_name text, grantee_email text, grantee_role text,
  options_granted int, strike_price_rupees numeric, grant_date date,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.grantee_name, g.grantee_email, g.grantee_role,
         g.options_granted, g.strike_price_rupees, g.grant_date, g.created_at
  FROM founder_esop_grants g
  WHERE g.status='pending_approval'
  ORDER BY g.created_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_esop_pending_approvals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_esop_pending_approvals() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_esop_recent_events(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid, grant_id uuid, event_type text,
  actor_email text, payload jsonb, occurred_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.grant_id, e.event_type, e.actor_email, e.payload, e.occurred_at
  FROM founder_esop_grant_events e
  ORDER BY e.occurred_at DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 100));
END $$;
REVOKE EXECUTE ON FUNCTION rpc_esop_recent_events(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_esop_recent_events(int) TO authenticated;


CREATE OR REPLACE FUNCTION rpc_esop_status_breakdown()
RETURNS TABLE(status text, grants_count bigint, options_sum bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.status, COUNT(*)::bigint, COALESCE(SUM(g.options_granted),0)::bigint
  FROM founder_esop_grants g
  GROUP BY g.status
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_esop_status_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_esop_status_breakdown() TO authenticated;


-- ============================================================
-- Write RPCs (VOLATILE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_esop_grant_create(
  p_grantee_email text, p_grantee_name text, p_grantee_role text,
  p_options int, p_strike_rupees numeric,
  p_cliff_months int DEFAULT 12, p_vest_months_total int DEFAULT 48,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_esop_grants(
    grantee_email, grantee_name, grantee_role,
    options_granted, strike_price_rupees,
    cliff_months, vest_months_total, notes
  ) VALUES (
    p_grantee_email, p_grantee_name, p_grantee_role,
    p_options, p_strike_rupees,
    COALESCE(p_cliff_months,12), COALESCE(p_vest_months_total,48), p_notes
  ) RETURNING id INTO new_id;

  PERFORM log_founder_esop_grant_created(new_id, jsonb_build_object(
    'email', p_grantee_email, 'options', p_options, 'strike', p_strike_rupees
  ));
  RETURN new_id;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_esop_grant_create(text,text,text,int,numeric,int,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_esop_grant_create(text,text,text,int,numeric,int,int,text) TO authenticated;

COMMIT;