BEGIN;

-- ============================================================================
-- Round 1915: Hospital Service Quality Dashboard
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_service_quality_dashboard_r1915 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  avg_rating numeric(3,2),
  repeat_booking_rate numeric(5,2),
  escalation_rate numeric(5,2),
  quality_score int,
  status text NOT NULL CHECK (status IN ('excellent','good','fair','poor','at_risk')),
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsqd_r1915_hospital ON public.hospital_service_quality_dashboard_r1915(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hsqd_r1915_period ON public.hospital_service_quality_dashboard_r1915(period_start DESC);
CREATE INDEX IF NOT EXISTS idx_hsqd_r1915_status ON public.hospital_service_quality_dashboard_r1915(status);

CREATE TABLE IF NOT EXISTS public.hospital_quality_action_log_r1915 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dashboard_id uuid NOT NULL REFERENCES public.hospital_service_quality_dashboard_r1915(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('escalation_call','quality_review','account_save','upgrade_offered')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hqal_r1915_dashboard ON public.hospital_quality_action_log_r1915(dashboard_id);
CREATE INDEX IF NOT EXISTS idx_hqal_r1915_taken ON public.hospital_quality_action_log_r1915(taken_at DESC);

ALTER TABLE public.hospital_service_quality_dashboard_r1915 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_quality_action_log_r1915 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsqd_r1915_founder_all ON public.hospital_service_quality_dashboard_r1915;
CREATE POLICY hsqd_r1915_founder_all ON public.hospital_service_quality_dashboard_r1915
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hqal_r1915_founder_all ON public.hospital_quality_action_log_r1915;
CREATE POLICY hqal_r1915_founder_all ON public.hospital_quality_action_log_r1915
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_dashboards
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_dashboards_r1915()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  period_start date,
  avg_rating numeric,
  repeat_booking_rate numeric,
  escalation_rate numeric,
  quality_score int,
  status text,
  computed_at timestamptz
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
    SELECT d.id, d.hospital_id, p.email, d.period_start, d.avg_rating,
           d.repeat_booking_rate, d.escalation_rate, d.quality_score, d.status, d.computed_at
    FROM public.hospital_service_quality_dashboard_r1915 d
    LEFT JOIN public.profiles p ON p.id = d.hospital_id
    ORDER BY d.computed_at DESC
    LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_dashboards_r1915() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_dashboards_r1915() TO authenticated;

-- ============================================================================
-- RPC 2: log_dashboard
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_dashboard_r1915(
  p_hospital_id uuid,
  p_period_start date,
  p_avg_rating numeric,
  p_repeat_booking_rate numeric,
  p_escalation_rate numeric,
  p_quality_score int,
  p_status text
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
  INSERT INTO public.hospital_service_quality_dashboard_r1915(
    hospital_id, period_start, avg_rating, repeat_booking_rate,
    escalation_rate, quality_score, status
  ) VALUES (
    p_hospital_id, p_period_start, p_avg_rating, p_repeat_booking_rate,
    p_escalation_rate, p_quality_score, p_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_dashboard_r1915',
          jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'status', p_status));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_dashboard_r1915(uuid, date, numeric, numeric, numeric, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_dashboard_r1915(uuid, date, numeric, numeric, numeric, int, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r1915(p_dashboard_id uuid)
RETURNS TABLE (
  id uuid,
  dashboard_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text
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
    SELECT a.id, a.dashboard_id, a.action_type, a.taken_at, a.by_email, a.outcome_md
    FROM public.hospital_quality_action_log_r1915 a
    WHERE a.dashboard_id = p_dashboard_id
    ORDER BY a.taken_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_actions_r1915(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r1915(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_action_r1915(
  p_dashboard_id uuid,
  p_action_type text,
  p_by_email text,
  p_outcome_md text
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
  INSERT INTO public.hospital_quality_action_log_r1915(
    dashboard_id, action_type, by_email, outcome_md
  ) VALUES (
    p_dashboard_id, p_action_type, p_by_email, p_outcome_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1915',
          jsonb_build_object('id', v_id, 'dashboard_id', p_dashboard_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_action_r1915(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r1915(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_period_closed
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_period_closed_r1915(p_dashboard_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.hospital_service_quality_dashboard_r1915
     SET status = p_status, updated_at = now()
   WHERE id = p_dashboard_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_period_closed_r1915',
          jsonb_build_object('id', p_dashboard_id, 'status', p_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_period_closed_r1915(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_period_closed_r1915(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: at_risk_hospitals
-- ============================================================================
CREATE OR REPLACE FUNCTION public.at_risk_hospitals_r1915()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  period_start date,
  quality_score int,
  status text,
  computed_at timestamptz
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
    SELECT d.id, d.hospital_id, p.email, d.period_start, d.quality_score, d.status, d.computed_at
    FROM public.hospital_service_quality_dashboard_r1915 d
    LEFT JOIN public.profiles p ON p.id = d.hospital_id
    WHERE d.status IN ('poor','at_risk')
    ORDER BY d.computed_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.at_risk_hospitals_r1915() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.at_risk_hospitals_r1915() TO authenticated;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r1915()
RETURNS TABLE (
  id uuid,
  dashboard_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text
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
    SELECT a.id, a.dashboard_id, a.action_type, a.taken_at, a.by_email, a.outcome_md
    FROM public.hospital_quality_action_log_r1915 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r1915() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1915() TO authenticated;

COMMIT;
