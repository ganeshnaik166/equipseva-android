BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_sla_drift_log_r1807 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sla_type text NOT NULL CHECK (sla_type IN ('response','resolution','escalation')),
  contracted_minutes int NOT NULL CHECK (contracted_minutes >= 0),
  actual_minutes int NOT NULL CHECK (actual_minutes >= 0),
  drift_minutes int NOT NULL,
  recorded_at date NOT NULL DEFAULT CURRENT_DATE,
  drift_severity text NOT NULL CHECK (drift_severity IN ('minor','moderate','critical')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_sla_drift_actions_r1807 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drift_id uuid NOT NULL REFERENCES public.hospital_sla_drift_log_r1807(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('apology','credit','escalation','contract_amendment')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  customer_response text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_sla_drift_log_r1807 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_sla_drift_actions_r1807 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_drift_log ON public.hospital_sla_drift_log_r1807;
CREATE POLICY founder_all_drift_log ON public.hospital_sla_drift_log_r1807
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_drift_actions ON public.hospital_sla_drift_actions_r1807;
CREATE POLICY founder_all_drift_actions ON public.hospital_sla_drift_actions_r1807
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_drift_log_hospital_r1807 ON public.hospital_sla_drift_log_r1807(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_drift_log_recorded_r1807 ON public.hospital_sla_drift_log_r1807(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_drift_log_severity_r1807 ON public.hospital_sla_drift_log_r1807(drift_severity);
CREATE INDEX IF NOT EXISTS idx_drift_actions_drift_r1807 ON public.hospital_sla_drift_actions_r1807(drift_id);

-- RPC 1: list_drifts
CREATE OR REPLACE FUNCTION public.list_drifts_r1807(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  sla_type text,
  contracted_minutes int,
  actual_minutes int,
  drift_minutes int,
  recorded_at date,
  drift_severity text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.hospital_user_id, p.email, d.sla_type,
           d.contracted_minutes, d.actual_minutes, d.drift_minutes,
           d.recorded_at, d.drift_severity
    FROM public.hospital_sla_drift_log_r1807 d
    LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
    ORDER BY d.recorded_at DESC, d.created_at DESC
    LIMIT p_limit;
END;
$$;

-- RPC 2: log_drift
CREATE OR REPLACE FUNCTION public.log_drift_r1807(
  p_hospital_user_id uuid,
  p_sla_type text,
  p_contracted_minutes int,
  p_actual_minutes int,
  p_drift_severity text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_drift int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_drift := p_actual_minutes - p_contracted_minutes;
  INSERT INTO public.hospital_sla_drift_log_r1807(
    hospital_user_id, sla_type, contracted_minutes, actual_minutes,
    drift_minutes, drift_severity
  )
  VALUES (p_hospital_user_id, p_sla_type, p_contracted_minutes, p_actual_minutes,
          v_drift, p_drift_severity)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_drift_r1807',
          jsonb_build_object('drift_id', v_id, 'hospital_user_id', p_hospital_user_id, 'sla_type', p_sla_type, 'drift_minutes', v_drift));
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r1807(p_drift_id uuid DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  drift_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  customer_response text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.drift_id, a.action_type, a.taken_at, a.by_email, a.customer_response
    FROM public.hospital_sla_drift_actions_r1807 a
    WHERE (p_drift_id IS NULL OR a.drift_id = p_drift_id)
    ORDER BY a.taken_at DESC
    LIMIT p_limit;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r1807(
  p_drift_id uuid,
  p_action_type text,
  p_by_email text,
  p_customer_response text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_sla_drift_actions_r1807(drift_id, action_type, by_email, customer_response)
  VALUES (p_drift_id, p_action_type, p_by_email, p_customer_response)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1807',
          jsonb_build_object('action_id', v_id, 'drift_id', p_drift_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: top_drift_hospitals
CREATE OR REPLACE FUNCTION public.top_drift_hospitals_r1807(p_limit int DEFAULT 20)
RETURNS TABLE(
  hospital_user_id uuid,
  hospital_email text,
  drift_count int,
  total_drift_minutes int,
  critical_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.hospital_user_id,
           p.email,
           COUNT(*)::int,
           COALESCE(SUM(d.drift_minutes),0)::int,
           (COUNT(*) FILTER (WHERE d.drift_severity = 'critical'))::int
    FROM public.hospital_sla_drift_log_r1807 d
    LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
    GROUP BY d.hospital_user_id, p.email
    ORDER BY COUNT(*) DESC
    LIMIT p_limit;
END;
$$;

-- RPC 6: drift_trend_monthly
CREATE OR REPLACE FUNCTION public.drift_trend_monthly_r1807(p_months int DEFAULT 12)
RETURNS TABLE(
  month_start date,
  drift_count int,
  avg_drift_minutes numeric,
  critical_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', d.recorded_at)::date,
           COUNT(*)::int,
           COALESCE(AVG(d.drift_minutes),0)::numeric,
           (COUNT(*) FILTER (WHERE d.drift_severity = 'critical'))::int
    FROM public.hospital_sla_drift_log_r1807 d
    WHERE d.recorded_at >= (CURRENT_DATE - (p_months || ' months')::interval)
    GROUP BY 1
    ORDER BY 1 DESC;
END;
$$;

-- RPC 7: critical_drift_queue
CREATE OR REPLACE FUNCTION public.critical_drift_queue_r1807(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  sla_type text,
  drift_minutes int,
  recorded_at date,
  has_action boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.hospital_user_id, p.email, d.sla_type, d.drift_minutes, d.recorded_at,
           EXISTS(SELECT 1 FROM public.hospital_sla_drift_actions_r1807 a WHERE a.drift_id = d.id)
    FROM public.hospital_sla_drift_log_r1807 d
    LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
    WHERE d.drift_severity = 'critical'
    ORDER BY d.recorded_at DESC
    LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_drifts_r1807(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_drift_r1807(uuid, text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1807(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1807(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_drift_hospitals_r1807(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.drift_trend_monthly_r1807(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_drift_queue_r1807(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_drifts_r1807(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_drift_r1807(uuid, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1807(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1807(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_drift_hospitals_r1807(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.drift_trend_monthly_r1807(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_drift_queue_r1807(int) TO authenticated;

COMMIT;