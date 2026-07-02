BEGIN;

-- ============================================================
-- Round 1772 — Engineer Equipment Damage Compensation
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_damage_compensations_r1772 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  damage_event_id uuid,
  equipment_name text NOT NULL,
  damage_assessment_rupees bigint NOT NULL DEFAULT 0,
  deduction_amount_rupees bigint NOT NULL DEFAULT 0,
  recovery_method text NOT NULL CHECK (recovery_method IN ('payroll_deduction','cash_payment','written_off')),
  status text NOT NULL DEFAULT 'assessed' CHECK (status IN ('assessed','agreed','recovering','recovered','written_off')),
  recovered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_edc_r1772_engineer ON public.engineer_damage_compensations_r1772(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_edc_r1772_status ON public.engineer_damage_compensations_r1772(status);
CREATE INDEX IF NOT EXISTS idx_edc_r1772_method ON public.engineer_damage_compensations_r1772(recovery_method);
CREATE INDEX IF NOT EXISTS idx_edc_r1772_created ON public.engineer_damage_compensations_r1772(created_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_damage_appeal_log_r1772 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  compensation_id uuid NOT NULL REFERENCES public.engineer_damage_compensations_r1772(id) ON DELETE CASCADE,
  appeal_at timestamptz NOT NULL DEFAULT now(),
  appeal_reason text,
  decision text CHECK (decision IN ('upheld','reduced','waived','escalated_to_legal')),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_edal_r1772_compensation ON public.engineer_damage_appeal_log_r1772(compensation_id);
CREATE INDEX IF NOT EXISTS idx_edal_r1772_decision ON public.engineer_damage_appeal_log_r1772(decision);
CREATE INDEX IF NOT EXISTS idx_edal_r1772_appeal_at ON public.engineer_damage_appeal_log_r1772(appeal_at DESC);

ALTER TABLE public.engineer_damage_compensations_r1772 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_damage_appeal_log_r1772 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_edc_r1772 ON public.engineer_damage_compensations_r1772;
CREATE POLICY founder_all_edc_r1772 ON public.engineer_damage_compensations_r1772
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_edal_r1772 ON public.engineer_damage_appeal_log_r1772;
CREATE POLICY founder_all_edal_r1772 ON public.engineer_damage_appeal_log_r1772
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_compensations_r1772
-- ============================================================
DROP FUNCTION IF EXISTS public.list_compensations_r1772();
CREATE OR REPLACE FUNCTION public.list_compensations_r1772()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  damage_event_id uuid,
  equipment_name text,
  damage_assessment_rupees bigint,
  deduction_amount_rupees bigint,
  recovery_method text,
  status text,
  recovered_at timestamptz,
  appeal_count int,
  created_at timestamptz
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
    c.id,
    c.engineer_user_id,
    ep.email::text AS engineer_email,
    c.damage_event_id,
    c.equipment_name,
    c.damage_assessment_rupees,
    c.deduction_amount_rupees,
    c.recovery_method,
    c.status,
    c.recovered_at,
    (SELECT COUNT(*) FROM public.engineer_damage_appeal_log_r1772 a WHERE a.compensation_id = c.id)::int AS appeal_count,
    c.created_at
  FROM public.engineer_damage_compensations_r1772 c
  LEFT JOIN public.profiles ep ON ep.id = c.engineer_user_id
  ORDER BY c.created_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================
-- RPC 2: log_compensation_r1772
-- ============================================================
DROP FUNCTION IF EXISTS public.log_compensation_r1772(uuid, uuid, text, bigint, bigint, text);
CREATE OR REPLACE FUNCTION public.log_compensation_r1772(
  p_engineer_user_id uuid,
  p_damage_event_id uuid,
  p_equipment_name text,
  p_damage_assessment_rupees bigint,
  p_deduction_amount_rupees bigint,
  p_recovery_method text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_recovery_method NOT IN ('payroll_deduction','cash_payment','written_off') THEN
    RAISE EXCEPTION 'invalid recovery_method: %', p_recovery_method;
  END IF;
  INSERT INTO public.engineer_damage_compensations_r1772(
    engineer_user_id, damage_event_id, equipment_name,
    damage_assessment_rupees, deduction_amount_rupees, recovery_method
  ) VALUES (
    p_engineer_user_id, p_damage_event_id, p_equipment_name,
    p_damage_assessment_rupees, p_deduction_amount_rupees, p_recovery_method
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_compensation_r1772',
    jsonb_build_object(
      'compensation_id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'equipment_name', p_equipment_name,
      'damage_assessment_rupees', p_damage_assessment_rupees,
      'deduction_amount_rupees', p_deduction_amount_rupees,
      'recovery_method', p_recovery_method
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: list_appeals_r1772
-- ============================================================
DROP FUNCTION IF EXISTS public.list_appeals_r1772(uuid);
CREATE OR REPLACE FUNCTION public.list_appeals_r1772(p_compensation_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  compensation_id uuid,
  equipment_name text,
  engineer_user_id uuid,
  appeal_at timestamptz,
  appeal_reason text,
  decision text,
  decided_at timestamptz,
  compensation_status text
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
    a.compensation_id,
    c.equipment_name,
    c.engineer_user_id,
    a.appeal_at,
    a.appeal_reason,
    a.decision,
    a.decided_at,
    c.status AS compensation_status
  FROM public.engineer_damage_appeal_log_r1772 a
  JOIN public.engineer_damage_compensations_r1772 c ON c.id = a.compensation_id
  WHERE p_compensation_id IS NULL OR a.compensation_id = p_compensation_id
  ORDER BY a.appeal_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================
-- RPC 4: log_appeal_r1772
-- ============================================================
DROP FUNCTION IF EXISTS public.log_appeal_r1772(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_appeal_r1772(
  p_compensation_id uuid,
  p_appeal_reason text,
  p_decision text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_decided_at timestamptz;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_decision IS NOT NULL AND p_decision NOT IN ('upheld','reduced','waived','escalated_to_legal') THEN
    RAISE EXCEPTION 'invalid decision: %', p_decision;
  END IF;

  v_decided_at := CASE WHEN p_decision IS NOT NULL THEN now() ELSE NULL END;

  INSERT INTO public.engineer_damage_appeal_log_r1772(
    compensation_id, appeal_reason, decision, decided_at
  ) VALUES (p_compensation_id, p_appeal_reason, p_decision, v_decided_at)
  RETURNING id INTO v_id;

  UPDATE public.engineer_damage_compensations_r1772
  SET updated_at = now()
  WHERE id = p_compensation_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_appeal_r1772',
    jsonb_build_object(
      'appeal_id', v_id,
      'compensation_id', p_compensation_id,
      'decision', p_decision
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: mark_recovered_r1772
-- ============================================================
DROP FUNCTION IF EXISTS public.mark_recovered_r1772(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_recovered_r1772(
  p_compensation_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_new_status NOT IN ('recovered','written_off') THEN
    RAISE EXCEPTION 'invalid status: %', p_new_status;
  END IF;

  UPDATE public.engineer_damage_compensations_r1772
  SET status = p_new_status,
      recovered_at = now(),
      updated_at = now()
  WHERE id = p_compensation_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_recovered_r1772',
    jsonb_build_object(
      'compensation_id', p_compensation_id,
      'new_status', p_new_status
    )
  );
END;
$$;

-- ============================================================
-- RPC 6: compensation_summary_r1772
-- ============================================================
DROP FUNCTION IF EXISTS public.compensation_summary_r1772();
CREATE OR REPLACE FUNCTION public.compensation_summary_r1772()
RETURNS TABLE (
  total_cases int,
  assessed_cases int,
  agreed_cases int,
  recovering_cases int,
  recovered_cases int,
  written_off_cases int,
  total_assessment_rupees bigint,
  total_deduction_rupees bigint,
  total_recovered_rupees bigint,
  total_written_off_rupees bigint,
  appeals_count int,
  appeals_waived int,
  cases_last_30d int
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
    (COUNT(*))::int AS total_cases,
    (COUNT(*) FILTER (WHERE c.status = 'assessed'))::int AS assessed_cases,
    (COUNT(*) FILTER (WHERE c.status = 'agreed'))::int AS agreed_cases,
    (COUNT(*) FILTER (WHERE c.status = 'recovering'))::int AS recovering_cases,
    (COUNT(*) FILTER (WHERE c.status = 'recovered'))::int AS recovered_cases,
    (COUNT(*) FILTER (WHERE c.status = 'written_off'))::int AS written_off_cases,
    COALESCE(SUM(c.damage_assessment_rupees), 0)::bigint AS total_assessment_rupees,
    COALESCE(SUM(c.deduction_amount_rupees), 0)::bigint AS total_deduction_rupees,
    COALESCE(SUM(c.deduction_amount_rupees) FILTER (WHERE c.status = 'recovered'), 0)::bigint AS total_recovered_rupees,
    COALESCE(SUM(c.damage_assessment_rupees) FILTER (WHERE c.status = 'written_off'), 0)::bigint AS total_written_off_rupees,
    (SELECT COUNT(*) FROM public.engineer_damage_appeal_log_r1772)::int AS appeals_count,
    (SELECT COUNT(*) FROM public.engineer_damage_appeal_log_r1772 WHERE decision = 'waived')::int AS appeals_waived,
    (COUNT(*) FILTER (WHERE c.created_at >= now() - interval '30 days'))::int AS cases_last_30d
  FROM public.engineer_damage_compensations_r1772 c;
END;
$$;

-- ============================================================
-- RPC 7: top_damage_engineers_r1772
-- ============================================================
DROP FUNCTION IF EXISTS public.top_damage_engineers_r1772();
CREATE OR REPLACE FUNCTION public.top_damage_engineers_r1772()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  case_count int,
  total_assessment_rupees bigint,
  total_deduction_rupees bigint,
  recovered_rupees bigint,
  open_cases int,
  appeal_count int
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
    c.engineer_user_id,
    ep.email::text AS engineer_email,
    (COUNT(*))::int AS case_count,
    COALESCE(SUM(c.damage_assessment_rupees), 0)::bigint AS total_assessment_rupees,
    COALESCE(SUM(c.deduction_amount_rupees), 0)::bigint AS total_deduction_rupees,
    COALESCE(SUM(c.deduction_amount_rupees) FILTER (WHERE c.status = 'recovered'), 0)::bigint AS recovered_rupees,
    (COUNT(*) FILTER (WHERE c.status IN ('assessed','agreed','recovering')))::int AS open_cases,
    (SELECT COUNT(*) FROM public.engineer_damage_appeal_log_r1772 a
       JOIN public.engineer_damage_compensations_r1772 c2 ON c2.id = a.compensation_id
       WHERE c2.engineer_user_id = c.engineer_user_id)::int AS appeal_count
  FROM public.engineer_damage_compensations_r1772 c
  LEFT JOIN public.profiles ep ON ep.id = c.engineer_user_id
  GROUP BY c.engineer_user_id, ep.email
  ORDER BY total_assessment_rupees DESC
  LIMIT 50;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.list_compensations_r1772() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_compensation_r1772(uuid, uuid, text, bigint, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_appeals_r1772(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_appeal_r1772(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_recovered_r1772(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.compensation_summary_r1772() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_damage_engineers_r1772() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_compensations_r1772() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_compensation_r1772(uuid, uuid, text, bigint, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_appeals_r1772(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_appeal_r1772(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_recovered_r1772(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.compensation_summary_r1772() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_damage_engineers_r1772() TO authenticated;

COMMIT;