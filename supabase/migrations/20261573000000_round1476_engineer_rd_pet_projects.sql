BEGIN;

-- ============================================================================
-- r1476: Engineer R&D pet-project log
-- Two tables: engineer_rd_projects + engineer_rd_validations
-- 7 SECDEF RPCs (1 STABLE read, 6 VOLATILE write) + 3 log_founder_* helpers
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_rd_projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES profiles(id),
  title text NOT NULL,
  description text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('repair_technique','time_saver_hack','tool_build','process_improvement','diagnostic_method','safety_innovation','cost_reducer','training_aid')),
  problem_statement text,
  solution_summary text,
  estimated_time_saved_minutes int DEFAULT 0,
  estimated_cost_saved_rupees int DEFAULT 0,
  evidence_url text,
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','under_review','validated','rejected','promoted_to_sop','archived')),
  founder_validation_tier int DEFAULT 0 CHECK (founder_validation_tier BETWEEN 0 AND 5),
  promote_to_sop boolean DEFAULT false,
  sop_promoted_at timestamptz,
  founder_notes text,
  reward_rupees int DEFAULT 0,
  reward_paid_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_rd_projects_engineer ON engineer_rd_projects(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_rd_projects_status ON engineer_rd_projects(status);
CREATE INDEX IF NOT EXISTS idx_rd_projects_kind ON engineer_rd_projects(kind);
CREATE INDEX IF NOT EXISTS idx_rd_projects_created ON engineer_rd_projects(created_at DESC);

CREATE TABLE IF NOT EXISTS engineer_rd_validations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES engineer_rd_projects(id) ON DELETE CASCADE,
  validator_user_id uuid NOT NULL REFERENCES profiles(id),
  tier_assigned int NOT NULL CHECK (tier_assigned BETWEEN 0 AND 5),
  validation_note text,
  validated_at timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_rd_validations_project ON engineer_rd_validations(project_id);
CREATE INDEX IF NOT EXISTS idx_rd_validations_validated ON engineer_rd_validations(validated_at DESC);

ALTER TABLE engineer_rd_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineer_rd_validations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rd_projects_founder_only ON engineer_rd_projects;
CREATE POLICY rd_projects_founder_only ON engineer_rd_projects
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS rd_validations_founder_only ON engineer_rd_validations;
CREATE POLICY rd_validations_founder_only ON engineer_rd_validations
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- log_founder_* helpers (VOLATILE SECDEF, is_founder gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_rd_project_action(
  p_op text,
  p_project_id uuid,
  p_payload jsonb
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, p_op, jsonb_build_object('project_id', p_project_id) || COALESCE(p_payload, '{}'::jsonb));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_rd_project_action(text, uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_rd_project_action(text, uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_rd_validation(
  p_project_id uuid,
  p_tier int,
  p_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'rd_validate',
    jsonb_build_object('project_id', p_project_id, 'tier', p_tier, 'note', p_note));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_rd_validation(uuid, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_rd_validation(uuid, int, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_rd_sop_promotion(
  p_project_id uuid,
  p_promoted boolean
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'rd_sop_promotion',
    jsonb_build_object('project_id', p_project_id, 'promoted', p_promoted));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_rd_sop_promotion(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_rd_sop_promotion(uuid, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_rd_reward(
  p_project_id uuid,
  p_rupees int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'rd_reward',
    jsonb_build_object('project_id', p_project_id, 'rupees', p_rupees));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_rd_reward(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_rd_reward(uuid, int) TO authenticated;

-- ============================================================================
-- READ RPC (STABLE) — dashboard rollup
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_rd_projects_dashboard()
RETURNS TABLE (
  total_projects bigint,
  submitted_count bigint,
  under_review_count bigint,
  validated_count bigint,
  rejected_count bigint,
  promoted_to_sop_count bigint,
  archived_count bigint,
  distinct_engineers bigint,
  distinct_kinds bigint,
  total_time_saved_minutes bigint,
  total_cost_saved_rupees bigint,
  total_rewards_paid_rupees bigint,
  avg_validation_tier numeric,
  projects_last_30d bigint,
  projects_last_7d bigint,
  sop_promotion_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status='submitted')::bigint,
    COUNT(*) FILTER (WHERE status='under_review')::bigint,
    COUNT(*) FILTER (WHERE status='validated')::bigint,
    COUNT(*) FILTER (WHERE status='rejected')::bigint,
    COUNT(*) FILTER (WHERE status='promoted_to_sop')::bigint,
    COUNT(*) FILTER (WHERE status='archived')::bigint,
    COUNT(DISTINCT engineer_user_id)::bigint,
    COUNT(DISTINCT kind)::bigint,
    COALESCE(SUM(estimated_time_saved_minutes),0)::bigint,
    COALESCE(SUM(estimated_cost_saved_rupees),0)::bigint,
    COALESCE(SUM(CASE WHEN reward_paid_at IS NOT NULL THEN reward_rupees ELSE 0 END),0)::bigint,
    COALESCE(AVG(founder_validation_tier) FILTER (WHERE founder_validation_tier > 0), 0)::numeric,
    COUNT(*) FILTER (WHERE created_at >= now() - interval '30 days')::bigint,
    COUNT(*) FILTER (WHERE created_at >= now() - interval '7 days')::bigint,
    CASE WHEN COUNT(*) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE promote_to_sop) / COUNT(*), 2)
      ELSE 0::numeric END
  FROM engineer_rd_projects;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rd_projects_dashboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rd_projects_dashboard() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE) — 6 mutators
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_rd_create_project(
  p_engineer_user_id uuid,
  p_title text,
  p_description text,
  p_kind text,
  p_problem_statement text,
  p_solution_summary text,
  p_time_saved_minutes int,
  p_cost_saved_rupees int,
  p_evidence_url text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_rd_projects (
    engineer_user_id, title, description, kind, problem_statement, solution_summary,
    estimated_time_saved_minutes, estimated_cost_saved_rupees, evidence_url
  ) VALUES (
    p_engineer_user_id, p_title, p_description, p_kind, p_problem_statement, p_solution_summary,
    COALESCE(p_time_saved_minutes, 0), COALESCE(p_cost_saved_rupees, 0), p_evidence_url
  )
  RETURNING id INTO v_id;
  PERFORM log_founder_rd_project_action('rd_create', v_id, jsonb_build_object('title', p_title, 'kind', p_kind));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rd_create_project(uuid, text, text, text, text, text, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rd_create_project(uuid, text, text, text, text, text, int, int, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_rd_set_status(
  p_project_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_rd_projects
     SET status = p_status, updated_at = now()
   WHERE id = p_project_id;
  PERFORM log_founder_rd_project_action('rd_set_status', p_project_id, jsonb_build_object('status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rd_set_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rd_set_status(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_rd_validate(
  p_project_id uuid,
  p_tier int,
  p_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_rd_validations (project_id, validator_user_id, tier_assigned, validation_note)
  VALUES (p_project_id, auth.uid(), p_tier, p_note);
  UPDATE engineer_rd_projects
     SET founder_validation_tier = p_tier,
         status = CASE WHEN p_tier >= 3 THEN 'validated' ELSE 'under_review' END,
         founder_notes = COALESCE(founder_notes,'') || E'\n[' || now()::text || '] ' || COALESCE(p_note,''),
         updated_at = now()
   WHERE id = p_project_id;
  PERFORM log_founder_rd_validation(p_project_id, p_tier, p_note);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rd_validate(uuid, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rd_validate(uuid, int, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_rd_promote_to_sop(
  p_project_id uuid,
  p_promote boolean
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_rd_projects
     SET promote_to_sop = p_promote,
         sop_promoted_at = CASE WHEN p_promote THEN now() ELSE NULL END,
         status = CASE WHEN p_promote THEN 'promoted_to_sop' ELSE status END,
         updated_at = now()
   WHERE id = p_project_id;
  PERFORM log_founder_rd_sop_promotion(p_project_id, p_promote);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rd_promote_to_sop(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rd_promote_to_sop(uuid, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION founder_rd_pay_reward(
  p_project_id uuid,
  p_rupees int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_rd_projects
     SET reward_rupees = p_rupees,
         reward_paid_at = now(),
         updated_at = now()
   WHERE id = p_project_id;
  PERFORM log_founder_rd_reward(p_project_id, p_rupees);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rd_pay_reward(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rd_pay_reward(uuid, int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_rd_archive(
  p_project_id uuid
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_rd_projects
     SET status = 'archived', updated_at = now()
   WHERE id = p_project_id;
  PERFORM log_founder_rd_project_action('rd_archive', p_project_id, '{}'::jsonb);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rd_archive(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rd_archive(uuid) TO authenticated;

COMMIT;