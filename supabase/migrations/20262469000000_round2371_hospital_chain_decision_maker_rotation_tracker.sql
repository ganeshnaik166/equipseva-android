BEGIN;

-- =========================================================================
-- r2371: Hospital chain decision-maker rotation tracker
-- =========================================================================
-- When a chain CXO/CEO/Procurement Head rotates out, our existing
-- relationship may vaporize. This tracker logs every rotation event,
-- scores the transition risk, and prescribes a concrete action plan
-- to retain the account through the changeover.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.chain_decision_maker_rotations_r2371 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier1','tier2','tier3','strategic')),
  hospital_count int NOT NULL DEFAULT 1 CHECK (hospital_count > 0),
  annual_contract_value_rupees bigint NOT NULL DEFAULT 0,
  outgoing_person_name text NOT NULL,
  outgoing_person_role text NOT NULL,
  outgoing_relationship_strength text NOT NULL CHECK (outgoing_relationship_strength IN ('champion','supporter','neutral','blocker','unknown')),
  outgoing_tenure_months int,
  outgoing_last_day date,
  outgoing_destination text,
  incoming_person_name text,
  incoming_person_role text,
  incoming_start_date date,
  incoming_prior_company text,
  incoming_known_relationship text CHECK (incoming_known_relationship IN ('warm','cold','adversarial','unknown')),
  rotation_detected_at timestamptz NOT NULL DEFAULT now(),
  detection_source text NOT NULL CHECK (detection_source IN ('linkedin','press_release','insider_tip','client_email','sales_call','industry_event','other')),
  transition_risk_score int NOT NULL CHECK (transition_risk_score BETWEEN 0 AND 100),
  risk_category text NOT NULL CHECK (risk_category IN ('p0_existential','p1_critical','p2_elevated','p3_routine')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','action_in_progress','retained','lost','dormant')),
  retention_outcome text,
  retention_outcome_at timestamptz,
  notes text,
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cdmr_r2371_status ON public.chain_decision_maker_rotations_r2371(status, risk_category);
CREATE INDEX IF NOT EXISTS idx_cdmr_r2371_detected ON public.chain_decision_maker_rotations_r2371(rotation_detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_cdmr_r2371_chain ON public.chain_decision_maker_rotations_r2371(chain_name);

ALTER TABLE public.chain_decision_maker_rotations_r2371 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cdmr_r2371_founder_all ON public.chain_decision_maker_rotations_r2371;
CREATE POLICY cdmr_r2371_founder_all ON public.chain_decision_maker_rotations_r2371
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.chain_rotation_action_plans_r2371 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rotation_id uuid NOT NULL REFERENCES public.chain_decision_maker_rotations_r2371(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('intro_meeting','exec_lunch','case_study_send','reference_call','contract_pre_renewal','price_lock','executive_visit','procurement_audit_offer','sla_review','custom_demo','other')),
  action_title text NOT NULL,
  action_owner_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  action_owner_label text NOT NULL,
  due_date date NOT NULL,
  priority text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','done','skipped','blocked')),
  completed_at timestamptz,
  outcome_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crap_r2371_rotation ON public.chain_rotation_action_plans_r2371(rotation_id);
CREATE INDEX IF NOT EXISTS idx_crap_r2371_due ON public.chain_rotation_action_plans_r2371(due_date) WHERE status IN ('pending','in_progress');

ALTER TABLE public.chain_rotation_action_plans_r2371 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crap_r2371_founder_all ON public.chain_rotation_action_plans_r2371;
CREATE POLICY crap_r2371_founder_all ON public.chain_rotation_action_plans_r2371
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- =========================================================================
-- RPC 1: Summary KPIs
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_rotation_summary_r2371()
RETURNS TABLE(
  open_rotations int,
  p0_existential int,
  p1_critical int,
  total_arr_at_risk_rupees bigint,
  retained_last_90d int,
  lost_last_90d int,
  retention_rate_pct numeric,
  avg_risk_score numeric,
  overdue_actions int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.chain_decision_maker_rotations_r2371
  ),
  recent AS (
    SELECT status FROM base
    WHERE retention_outcome_at >= now() - interval '90 days'
  )
  SELECT
    (SELECT count(*)::int FROM base WHERE status IN ('open','action_in_progress')),
    (SELECT count(*)::int FROM base WHERE status IN ('open','action_in_progress') AND risk_category='p0_existential'),
    (SELECT count(*)::int FROM base WHERE status IN ('open','action_in_progress') AND risk_category='p1_critical'),
    (SELECT COALESCE(sum(annual_contract_value_rupees),0)::bigint FROM base WHERE status IN ('open','action_in_progress')),
    (SELECT count(*)::int FROM recent WHERE status='retained'),
    (SELECT count(*)::int FROM recent WHERE status='lost'),
    (SELECT CASE WHEN count(*)=0 THEN 0
       ELSE round(100.0 * count(*) FILTER (WHERE status='retained') / count(*), 1)
     END FROM recent),
    (SELECT COALESCE(round(avg(transition_risk_score)::numeric, 1), 0) FROM base WHERE status IN ('open','action_in_progress')),
    (SELECT count(*)::int FROM public.chain_rotation_action_plans_r2371
       WHERE status IN ('pending','in_progress') AND due_date < current_date);
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_rotation_summary_r2371() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_rotation_summary_r2371() TO authenticated;


-- =========================================================================
-- RPC 2: Open rotations queue (risk-sorted)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_rotation_open_queue_r2371()
RETURNS TABLE(
  id uuid,
  chain_name text,
  chain_tier text,
  hospital_count int,
  arr_rupees bigint,
  outgoing_label text,
  incoming_label text,
  risk_score int,
  risk_category text,
  status text,
  rotation_age_days int,
  open_actions int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.chain_name,
    r.chain_tier,
    r.hospital_count,
    r.annual_contract_value_rupees,
    r.outgoing_person_name || ' (' || r.outgoing_person_role || ')',
    COALESCE(r.incoming_person_name || ' (' || COALESCE(r.incoming_person_role,'TBD') || ')', 'unknown'),
    r.transition_risk_score,
    r.risk_category,
    r.status,
    GREATEST(0, (current_date - r.rotation_detected_at::date))::int,
    (SELECT count(*)::int FROM public.chain_rotation_action_plans_r2371 a
      WHERE a.rotation_id = r.id AND a.status IN ('pending','in_progress'))
  FROM public.chain_decision_maker_rotations_r2371 r
  WHERE r.status IN ('open','action_in_progress')
  ORDER BY
    CASE r.risk_category
      WHEN 'p0_existential' THEN 0
      WHEN 'p1_critical' THEN 1
      WHEN 'p2_elevated' THEN 2
      ELSE 3
    END,
    r.transition_risk_score DESC,
    r.annual_contract_value_rupees DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_rotation_open_queue_r2371() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_rotation_open_queue_r2371() TO authenticated;


-- =========================================================================
-- RPC 3: Overdue action items
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_rotation_overdue_actions_r2371()
RETURNS TABLE(
  action_id uuid,
  rotation_id uuid,
  chain_name text,
  action_title text,
  action_type text,
  owner_label text,
  due_date date,
  days_overdue int,
  priority text,
  risk_category text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    a.id,
    r.id,
    r.chain_name,
    a.action_title,
    a.action_type,
    a.action_owner_label,
    a.due_date,
    GREATEST(0, (current_date - a.due_date))::int,
    a.priority,
    r.risk_category
  FROM public.chain_rotation_action_plans_r2371 a
  JOIN public.chain_decision_maker_rotations_r2371 r ON r.id = a.rotation_id
  WHERE a.status IN ('pending','in_progress')
    AND a.due_date < current_date
  ORDER BY
    CASE a.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    a.due_date ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_rotation_overdue_actions_r2371() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_rotation_overdue_actions_r2371() TO authenticated;


-- =========================================================================
-- RPC 4: Risk-category breakdown
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_rotation_risk_breakdown_r2371()
RETURNS TABLE(
  risk_category text,
  rotation_count int,
  arr_at_risk_rupees bigint,
  hospital_count_at_risk int,
  avg_risk_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.risk_category,
    count(*)::int,
    COALESCE(sum(r.annual_contract_value_rupees),0)::bigint,
    COALESCE(sum(r.hospital_count),0)::int,
    COALESCE(round(avg(r.transition_risk_score)::numeric, 1), 0)
  FROM public.chain_decision_maker_rotations_r2371 r
  WHERE r.status IN ('open','action_in_progress')
  GROUP BY r.risk_category
  ORDER BY
    CASE r.risk_category
      WHEN 'p0_existential' THEN 0
      WHEN 'p1_critical' THEN 1
      WHEN 'p2_elevated' THEN 2
      ELSE 3
    END;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_rotation_risk_breakdown_r2371() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_rotation_risk_breakdown_r2371() TO authenticated;


-- =========================================================================
-- RPC 5: Recently resolved (last 90 days)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_rotation_recent_outcomes_r2371()
RETURNS TABLE(
  id uuid,
  chain_name text,
  outgoing_label text,
  resolved_status text,
  arr_rupees bigint,
  resolved_at timestamptz,
  outcome_summary text,
  days_to_resolve int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.chain_name,
    r.outgoing_person_name || ' (' || r.outgoing_person_role || ')',
    r.status,
    r.annual_contract_value_rupees,
    r.retention_outcome_at,
    COALESCE(r.retention_outcome, '—'),
    GREATEST(0, (r.retention_outcome_at::date - r.rotation_detected_at::date))::int
  FROM public.chain_decision_maker_rotations_r2371 r
  WHERE r.status IN ('retained','lost','dormant')
    AND r.retention_outcome_at >= now() - interval '90 days'
  ORDER BY r.retention_outcome_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_rotation_recent_outcomes_r2371() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_rotation_recent_outcomes_r2371() TO authenticated;


-- =========================================================================
-- RPC 6: Detection-source mix
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_rotation_detection_mix_r2371()
RETURNS TABLE(
  detection_source text,
  rotation_count int,
  share_pct numeric,
  retained_count int,
  lost_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT count(*) INTO v_total FROM public.chain_decision_maker_rotations_r2371;
  IF v_total = 0 THEN v_total := 1; END IF;

  RETURN QUERY
  SELECT
    r.detection_source,
    count(*)::int,
    round(100.0 * count(*) / v_total, 1),
    count(*) FILTER (WHERE r.status='retained')::int,
    count(*) FILTER (WHERE r.status='lost')::int
  FROM public.chain_decision_maker_rotations_r2371 r
  GROUP BY r.detection_source
  ORDER BY count(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_rotation_detection_mix_r2371() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_rotation_detection_mix_r2371() TO authenticated;


-- =========================================================================
-- RPC 7: Top action plan items (upcoming, prioritized)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_rotation_top_actions_r2371()
RETURNS TABLE(
  action_id uuid,
  chain_name text,
  risk_category text,
  action_title text,
  action_type text,
  owner_label text,
  due_date date,
  days_to_due int,
  priority text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    a.id,
    r.chain_name,
    r.risk_category,
    a.action_title,
    a.action_type,
    a.action_owner_label,
    a.due_date,
    (a.due_date - current_date)::int,
    a.priority,
    a.status
  FROM public.chain_rotation_action_plans_r2371 a
  JOIN public.chain_decision_maker_rotations_r2371 r ON r.id = a.rotation_id
  WHERE a.status IN ('pending','in_progress')
  ORDER BY
    CASE a.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    a.due_date ASC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_rotation_top_actions_r2371() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_rotation_top_actions_r2371() TO authenticated;

COMMIT;
