BEGIN;

-- =========================================================================
-- r1579 — Founder Hospital Tier-A Onboarding Playbook
-- Top-50 hospitals get white-glove onboarding: CEO visit, dedicated engineer,
-- CTO call. 10-step checklist with per-hospital state and founder review.
-- =========================================================================

CREATE TABLE IF NOT EXISTS hospital_tier_a_onboarding (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  tier_a_rank int NOT NULL CHECK (tier_a_rank BETWEEN 1 AND 50),
  playbook_status text NOT NULL DEFAULT 'pending'
    CHECK (playbook_status IN ('pending','in_progress','on_hold','launched','dropped')),
  assigned_engineer_id uuid REFERENCES engineers(id),
  ceo_sponsor_name text,
  ceo_sponsor_email text,
  cto_sponsor_name text,
  cto_sponsor_email text,
  target_launch_date date,
  actual_launch_at timestamptz,
  contract_value_rupees bigint DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hospital_org_id)
);

CREATE INDEX IF NOT EXISTS idx_htao_status ON hospital_tier_a_onboarding(playbook_status);
CREATE INDEX IF NOT EXISTS idx_htao_rank ON hospital_tier_a_onboarding(tier_a_rank);
CREATE INDEX IF NOT EXISTS idx_htao_target ON hospital_tier_a_onboarding(target_launch_date);

ALTER TABLE hospital_tier_a_onboarding ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS htao_founder_only ON hospital_tier_a_onboarding;
CREATE POLICY htao_founder_only ON hospital_tier_a_onboarding
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS hospital_tier_a_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL REFERENCES hospital_tier_a_onboarding(id) ON DELETE CASCADE,
  step_no int NOT NULL CHECK (step_no BETWEEN 1 AND 10),
  step_name text NOT NULL,
  step_owner text NOT NULL CHECK (step_owner IN ('ceo','cto','founder','engineer','ops')),
  state text NOT NULL DEFAULT 'todo'
    CHECK (state IN ('todo','in_progress','blocked','done','skipped')),
  founder_reviewed boolean NOT NULL DEFAULT false,
  founder_review_note text,
  founder_reviewed_at timestamptz,
  due_date date,
  completed_at timestamptz,
  evidence_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (onboarding_id, step_no)
);

CREATE INDEX IF NOT EXISTS idx_htas_onboarding ON hospital_tier_a_steps(onboarding_id);
CREATE INDEX IF NOT EXISTS idx_htas_state ON hospital_tier_a_steps(state);
CREATE INDEX IF NOT EXISTS idx_htas_reviewed ON hospital_tier_a_steps(founder_reviewed);

ALTER TABLE hospital_tier_a_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS htas_founder_only ON hospital_tier_a_steps;
CREATE POLICY htas_founder_only ON hospital_tier_a_steps
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


-- =========================================================================
-- Read RPCs (STABLE)
-- =========================================================================

CREATE OR REPLACE FUNCTION rpc_founder_tier_a_overview()
RETURNS TABLE (
  total_hospitals int,
  in_progress int,
  launched int,
  on_hold int,
  pending int,
  dropped int,
  total_steps int,
  steps_done int,
  steps_blocked int,
  steps_pending_review int,
  total_contract_value_rupees bigint,
  avg_days_to_launch numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM hospital_tier_a_onboarding),
    (SELECT COUNT(*)::int FROM hospital_tier_a_onboarding WHERE playbook_status='in_progress'),
    (SELECT COUNT(*)::int FROM hospital_tier_a_onboarding WHERE playbook_status='launched'),
    (SELECT COUNT(*)::int FROM hospital_tier_a_onboarding WHERE playbook_status='on_hold'),
    (SELECT COUNT(*)::int FROM hospital_tier_a_onboarding WHERE playbook_status='pending'),
    (SELECT COUNT(*)::int FROM hospital_tier_a_onboarding WHERE playbook_status='dropped'),
    (SELECT COUNT(*)::int FROM hospital_tier_a_steps),
    (SELECT COUNT(*)::int FROM hospital_tier_a_steps WHERE state='done'),
    (SELECT COUNT(*)::int FROM hospital_tier_a_steps WHERE state='blocked'),
    (SELECT COUNT(*)::int FROM hospital_tier_a_steps WHERE state='done' AND NOT founder_reviewed),
    (SELECT COALESCE(SUM(contract_value_rupees),0)::bigint FROM hospital_tier_a_onboarding WHERE playbook_status='launched'),
    (SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (actual_launch_at - created_at))/86400.0),0)::numeric
       FROM hospital_tier_a_onboarding WHERE actual_launch_at IS NOT NULL);
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_founder_tier_a_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_a_overview() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_a_hospitals()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  city text,
  state text,
  tier_a_rank int,
  playbook_status text,
  steps_done int,
  steps_total int,
  pct_complete numeric,
  target_launch_date date,
  actual_launch_at timestamptz,
  contract_value_rupees bigint,
  days_in_progress numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    h.id,
    h.hospital_org_id,
    o.name AS hospital_name,
    o.city,
    o.state,
    h.tier_a_rank,
    h.playbook_status,
    (SELECT COUNT(*)::int FROM hospital_tier_a_steps s WHERE s.onboarding_id=h.id AND s.state='done'),
    (SELECT COUNT(*)::int FROM hospital_tier_a_steps s WHERE s.onboarding_id=h.id),
    COALESCE(
      (SELECT (COUNT(*) FILTER (WHERE s.state='done'))::numeric / NULLIF(COUNT(*),0) * 100
         FROM hospital_tier_a_steps s WHERE s.onboarding_id=h.id), 0)::numeric,
    h.target_launch_date,
    h.actual_launch_at,
    h.contract_value_rupees,
    EXTRACT(EPOCH FROM (now() - h.created_at))/86400.0
  FROM hospital_tier_a_onboarding h
  JOIN organizations o ON o.id = h.hospital_org_id
  ORDER BY h.tier_a_rank ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_founder_tier_a_hospitals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_a_hospitals() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_a_pending_review()
RETURNS TABLE (
  step_id uuid,
  onboarding_id uuid,
  hospital_name text,
  step_no int,
  step_name text,
  step_owner text,
  state text,
  completed_at timestamptz,
  days_waiting numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.onboarding_id,
    o.name,
    s.step_no,
    s.step_name,
    s.step_owner,
    s.state,
    s.completed_at,
    EXTRACT(EPOCH FROM (now() - COALESCE(s.completed_at, s.updated_at)))/86400.0
  FROM hospital_tier_a_steps s
  JOIN hospital_tier_a_onboarding h ON h.id = s.onboarding_id
  JOIN organizations o ON o.id = h.hospital_org_id
  WHERE s.state='done' AND NOT s.founder_reviewed
  ORDER BY s.completed_at ASC NULLS LAST
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_founder_tier_a_pending_review() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_a_pending_review() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_a_blocked_steps()
RETURNS TABLE (
  step_id uuid,
  hospital_name text,
  step_no int,
  step_name text,
  step_owner text,
  due_date date,
  days_blocked numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    o.name,
    s.step_no,
    s.step_name,
    s.step_owner,
    s.due_date,
    EXTRACT(EPOCH FROM (now() - s.updated_at))/86400.0
  FROM hospital_tier_a_steps s
  JOIN hospital_tier_a_onboarding h ON h.id = s.onboarding_id
  JOIN organizations o ON o.id = h.hospital_org_id
  WHERE s.state='blocked'
  ORDER BY s.updated_at ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_founder_tier_a_blocked_steps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_a_blocked_steps() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_a_step_breakdown()
RETURNS TABLE (
  step_no int,
  step_name text,
  total int,
  done int,
  in_progress int,
  blocked int,
  todo int,
  pct_done numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.step_no,
    MAX(s.step_name),
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE s.state='done')::int,
    COUNT(*) FILTER (WHERE s.state='in_progress')::int,
    COUNT(*) FILTER (WHERE s.state='blocked')::int,
    COUNT(*) FILTER (WHERE s.state='todo')::int,
    (COUNT(*) FILTER (WHERE s.state='done'))::numeric / NULLIF(COUNT(*),0) * 100
  FROM hospital_tier_a_steps s
  GROUP BY s.step_no
  ORDER BY s.step_no ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_founder_tier_a_step_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_a_step_breakdown() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_tier_a_recent_launches()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  tier_a_rank int,
  actual_launch_at timestamptz,
  contract_value_rupees bigint,
  days_to_launch numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    h.id,
    o.name,
    h.tier_a_rank,
    h.actual_launch_at,
    h.contract_value_rupees,
    EXTRACT(EPOCH FROM (h.actual_launch_at - h.created_at))/86400.0
  FROM hospital_tier_a_onboarding h
  JOIN organizations o ON o.id = h.hospital_org_id
  WHERE h.actual_launch_at IS NOT NULL
  ORDER BY h.actual_launch_at DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_founder_tier_a_recent_launches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_a_recent_launches() TO authenticated;


-- =========================================================================
-- Write RPC (VOLATILE)
-- =========================================================================

CREATE OR REPLACE FUNCTION rpc_founder_tier_a_review_step(
  p_step_id uuid,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_tier_a_steps
     SET founder_reviewed = true,
         founder_review_note = p_note,
         founder_reviewed_at = now(),
         updated_at = now()
   WHERE id = p_step_id
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_founder_tier_a_review_step(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_tier_a_review_step(uuid, text) TO authenticated;


-- =========================================================================
-- log_founder_* helpers (VOLATILE SECDEF)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_tier_a_playbook_created(
  p_onboarding_id uuid,
  p_hospital_org_id uuid,
  p_tier_a_rank int
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'tier_a_playbook_created',
    jsonb_build_object(
      'onboarding_id', p_onboarding_id,
      'hospital_org_id', p_hospital_org_id,
      'tier_a_rank', p_tier_a_rank
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_tier_a_playbook_created(uuid, uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tier_a_playbook_created(uuid, uuid, int) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_tier_a_step_reviewed(
  p_step_id uuid,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'tier_a_step_reviewed',
    jsonb_build_object('step_id', p_step_id, 'note', p_note)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_tier_a_step_reviewed(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tier_a_step_reviewed(uuid, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_tier_a_launched(
  p_onboarding_id uuid,
  p_contract_value_rupees bigint
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'tier_a_launched',
    jsonb_build_object(
      'onboarding_id', p_onboarding_id,
      'contract_value_rupees', p_contract_value_rupees
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_tier_a_launched(uuid, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tier_a_launched(uuid, bigint) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_tier_a_dropped(
  p_onboarding_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'tier_a_dropped',
    jsonb_build_object('onboarding_id', p_onboarding_id, 'reason', p_reason)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_tier_a_dropped(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tier_a_dropped(uuid, text) TO authenticated;

COMMIT;