BEGIN;

-- ============================================================================
-- Round 1783: Hospital Audit Trail Compliance
-- Track audit trails NABH/NABL/JCI need (per-hospital evidence packs)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_audit_trail_compliance_r1783 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  audit_body text NOT NULL CHECK (audit_body IN ('nabh','nabl','jci','iso','internal')),
  last_audit_date date,
  next_audit_date date,
  evidence_pack_url text,
  compliance_score int CHECK (compliance_score BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'under_review' CHECK (status IN ('compliant','issues','under_review','non_compliant')),
  observations_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hatc_r1783_hospital ON public.hospital_audit_trail_compliance_r1783(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hatc_r1783_status ON public.hospital_audit_trail_compliance_r1783(status);
CREATE INDEX IF NOT EXISTS idx_hatc_r1783_next ON public.hospital_audit_trail_compliance_r1783(next_audit_date);

CREATE TABLE IF NOT EXISTS public.hospital_audit_observations_r1783 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  compliance_id uuid NOT NULL REFERENCES public.hospital_audit_trail_compliance_r1783(id) ON DELETE CASCADE,
  observation_severity text NOT NULL CHECK (observation_severity IN ('major','minor','observation','recommendation')),
  observation_text text NOT NULL,
  remediation_action text,
  remediated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hao_r1783_compliance ON public.hospital_audit_observations_r1783(compliance_id);
CREATE INDEX IF NOT EXISTS idx_hao_r1783_severity ON public.hospital_audit_observations_r1783(observation_severity);

ALTER TABLE public.hospital_audit_trail_compliance_r1783 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_audit_observations_r1783 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hatc_r1783_founder_all ON public.hospital_audit_trail_compliance_r1783;
CREATE POLICY hatc_r1783_founder_all ON public.hospital_audit_trail_compliance_r1783
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hao_r1783_founder_all ON public.hospital_audit_observations_r1783;
CREATE POLICY hao_r1783_founder_all ON public.hospital_audit_observations_r1783
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_compliance_r1783()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  audit_body text,
  last_audit_date date,
  next_audit_date date,
  evidence_pack_url text,
  compliance_score int,
  status text,
  observations_count int,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_user_id, p.email, c.audit_body, c.last_audit_date, c.next_audit_date,
         c.evidence_pack_url, c.compliance_score, c.status, c.observations_count, c.created_at
  FROM public.hospital_audit_trail_compliance_r1783 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  ORDER BY c.next_audit_date NULLS LAST, c.created_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.set_compliance_r1783(
  p_hospital_user_id uuid,
  p_audit_body text,
  p_last_audit_date date,
  p_next_audit_date date,
  p_evidence_pack_url text,
  p_compliance_score int,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_audit_trail_compliance_r1783(
    hospital_user_id, audit_body, last_audit_date, next_audit_date,
    evidence_pack_url, compliance_score, status
  ) VALUES (
    p_hospital_user_id, p_audit_body, p_last_audit_date, p_next_audit_date,
    p_evidence_pack_url, p_compliance_score, p_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1783.set_compliance',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'audit_body', p_audit_body, 'status', p_status));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_observations_r1783(p_compliance_id uuid)
RETURNS TABLE (
  id uuid,
  compliance_id uuid,
  observation_severity text,
  observation_text text,
  remediation_action text,
  remediated_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.compliance_id, o.observation_severity, o.observation_text,
         o.remediation_action, o.remediated_at, o.created_at
  FROM public.hospital_audit_observations_r1783 o
  WHERE (p_compliance_id IS NULL OR o.compliance_id = p_compliance_id)
  ORDER BY o.created_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_observation_r1783(
  p_compliance_id uuid,
  p_observation_severity text,
  p_observation_text text,
  p_remediation_action text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_audit_observations_r1783(
    compliance_id, observation_severity, observation_text, remediation_action
  ) VALUES (
    p_compliance_id, p_observation_severity, p_observation_text, p_remediation_action
  ) RETURNING id INTO v_id;

  UPDATE public.hospital_audit_trail_compliance_r1783
    SET observations_count = observations_count + 1, updated_at = now()
    WHERE id = p_compliance_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1783.log_observation',
    jsonb_build_object('id', v_id, 'compliance_id', p_compliance_id, 'severity', p_observation_severity));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.remediate_observation_r1783(
  p_observation_id uuid,
  p_remediation_action text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_audit_observations_r1783
    SET remediation_action = COALESCE(p_remediation_action, remediation_action),
        remediated_at = now(),
        updated_at = now()
    WHERE id = p_observation_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1783.remediate_observation',
    jsonb_build_object('id', p_observation_id));
END $$;

CREATE OR REPLACE FUNCTION public.upcoming_audits_r1783()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  audit_body text,
  next_audit_date date,
  days_until int,
  status text,
  compliance_score int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_user_id, p.email, c.audit_body, c.next_audit_date,
         (c.next_audit_date - CURRENT_DATE)::int AS days_until,
         c.status, c.compliance_score
  FROM public.hospital_audit_trail_compliance_r1783 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.next_audit_date IS NOT NULL
    AND c.next_audit_date >= CURRENT_DATE
    AND c.next_audit_date <= CURRENT_DATE + INTERVAL '90 days'
  ORDER BY c.next_audit_date ASC
  LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.top_at_risk_r1783()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  audit_body text,
  compliance_score int,
  status text,
  observations_count int,
  major_observations int,
  next_audit_date date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_user_id, p.email, c.audit_body, c.compliance_score,
         c.status, c.observations_count,
         (COUNT(o.*) FILTER (WHERE o.observation_severity = 'major' AND o.remediated_at IS NULL))::int AS major_observations,
         c.next_audit_date
  FROM public.hospital_audit_trail_compliance_r1783 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  LEFT JOIN public.hospital_audit_observations_r1783 o ON o.compliance_id = c.id
  WHERE c.status IN ('issues','non_compliant','under_review')
  GROUP BY c.id, p.email
  ORDER BY COALESCE(c.compliance_score, 0) ASC, major_observations DESC
  LIMIT 50;
END $$;

-- ============================================================================
-- REVOKE + GRANT
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_compliance_r1783() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_compliance_r1783(uuid, text, date, date, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_observations_r1783(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_observation_r1783(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.remediate_observation_r1783(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_audits_r1783() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_at_risk_r1783() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_compliance_r1783() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_compliance_r1783(uuid, text, date, date, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_observations_r1783(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_observation_r1783(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remediate_observation_r1783(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_audits_r1783() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_at_risk_r1783() TO authenticated;

COMMIT;