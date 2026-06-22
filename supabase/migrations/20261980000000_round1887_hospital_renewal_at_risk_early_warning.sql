BEGIN;

-- =====================================================================
-- r1887 Hospital Renewal-At-Risk Early Warning
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.hospital_renewal_at_risk_signals_r1887 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  signal_type text NOT NULL CHECK (signal_type IN ('tickets_spike','satisfaction_drop','payment_delay','engineer_change','competitive_visit','champion_left')),
  signal_severity text NOT NULL CHECK (signal_severity IN ('info','warning','critical')),
  signal_value text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_intervention','cleared','lost')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rar_signals_r1887_hospital ON public.hospital_renewal_at_risk_signals_r1887(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_rar_signals_r1887_status ON public.hospital_renewal_at_risk_signals_r1887(status);
CREATE INDEX IF NOT EXISTS idx_rar_signals_r1887_recorded ON public.hospital_renewal_at_risk_signals_r1887(recorded_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_renewal_at_risk_interventions_r1887 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_id uuid NOT NULL REFERENCES public.hospital_renewal_at_risk_signals_r1887(id) ON DELETE CASCADE,
  intervention_type text NOT NULL CHECK (intervention_type IN ('founder_call','discount_offer','early_renewal','champion_replacement','escalation')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rar_intv_r1887_signal ON public.hospital_renewal_at_risk_interventions_r1887(signal_id);
CREATE INDEX IF NOT EXISTS idx_rar_intv_r1887_taken ON public.hospital_renewal_at_risk_interventions_r1887(taken_at DESC);

-- RLS
ALTER TABLE public.hospital_renewal_at_risk_signals_r1887 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_renewal_at_risk_interventions_r1887 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rar_signals_r1887_founder ON public.hospital_renewal_at_risk_signals_r1887;
CREATE POLICY rar_signals_r1887_founder ON public.hospital_renewal_at_risk_signals_r1887
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS rar_intv_r1887_founder ON public.hospital_renewal_at_risk_interventions_r1887;
CREATE POLICY rar_intv_r1887_founder ON public.hospital_renewal_at_risk_interventions_r1887
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_signals
-- =====================================================================
DROP FUNCTION IF EXISTS public.rar_r1887_list_signals(text, int);
CREATE OR REPLACE FUNCTION public.rar_r1887_list_signals(p_status text DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  org_name text,
  signal_type text,
  signal_severity text,
  signal_value text,
  recorded_at timestamptz,
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
    s.id,
    s.hospital_user_id,
    p.email::text,
    o.name::text,
    s.signal_type,
    s.signal_severity,
    s.signal_value,
    s.recorded_at,
    s.status
  FROM public.hospital_renewal_at_risk_signals_r1887 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE (p_status IS NULL OR s.status = p_status)
  ORDER BY s.recorded_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;

-- =====================================================================
-- RPC 2: log_signal
-- =====================================================================
DROP FUNCTION IF EXISTS public.rar_r1887_log_signal(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.rar_r1887_log_signal(
  p_hospital_user_id uuid,
  p_signal_type text,
  p_signal_severity text,
  p_signal_value text
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
  INSERT INTO public.hospital_renewal_at_risk_signals_r1887(hospital_user_id, signal_type, signal_severity, signal_value)
  VALUES (p_hospital_user_id, p_signal_type, p_signal_severity, p_signal_value)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'rar_r1887_log_signal',
    jsonb_build_object('signal_id', v_id, 'hospital_user_id', p_hospital_user_id, 'signal_type', p_signal_type, 'signal_severity', p_signal_severity));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_interventions
-- =====================================================================
DROP FUNCTION IF EXISTS public.rar_r1887_list_interventions(uuid, int);
CREATE OR REPLACE FUNCTION public.rar_r1887_list_interventions(p_signal_id uuid DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  signal_id uuid,
  intervention_type text,
  taken_at timestamptz,
  by_email text,
  outcome text,
  hospital_user_id uuid,
  signal_type text,
  signal_severity text
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
    i.id,
    i.signal_id,
    i.intervention_type,
    i.taken_at,
    i.by_email,
    i.outcome,
    s.hospital_user_id,
    s.signal_type,
    s.signal_severity
  FROM public.hospital_renewal_at_risk_interventions_r1887 i
  JOIN public.hospital_renewal_at_risk_signals_r1887 s ON s.id = i.signal_id
  WHERE (p_signal_id IS NULL OR i.signal_id = p_signal_id)
  ORDER BY i.taken_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;

-- =====================================================================
-- RPC 4: log_intervention
-- =====================================================================
DROP FUNCTION IF EXISTS public.rar_r1887_log_intervention(uuid, text, text);
CREATE OR REPLACE FUNCTION public.rar_r1887_log_intervention(
  p_signal_id uuid,
  p_intervention_type text,
  p_outcome text
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
  INSERT INTO public.hospital_renewal_at_risk_interventions_r1887(signal_id, intervention_type, by_email, outcome)
  VALUES (p_signal_id, p_intervention_type, (auth.jwt()->>'email'), p_outcome)
  RETURNING id INTO v_id;

  UPDATE public.hospital_renewal_at_risk_signals_r1887
  SET status = 'in_intervention', updated_at = now()
  WHERE id = p_signal_id AND status = 'open';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'rar_r1887_log_intervention',
    jsonb_build_object('intervention_id', v_id, 'signal_id', p_signal_id, 'intervention_type', p_intervention_type));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5: mark_cleared
-- =====================================================================
DROP FUNCTION IF EXISTS public.rar_r1887_mark_cleared(uuid, text);
CREATE OR REPLACE FUNCTION public.rar_r1887_mark_cleared(p_signal_id uuid, p_final_status text DEFAULT 'cleared')
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_final_status NOT IN ('cleared','lost') THEN
    RAISE EXCEPTION 'invalid final status';
  END IF;
  UPDATE public.hospital_renewal_at_risk_signals_r1887
  SET status = p_final_status, updated_at = now()
  WHERE id = p_signal_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'rar_r1887_mark_cleared',
    jsonb_build_object('signal_id', p_signal_id, 'final_status', p_final_status));
END;
$$;

-- =====================================================================
-- RPC 6: critical_signals_summary
-- =====================================================================
DROP FUNCTION IF EXISTS public.rar_r1887_critical_signals_summary();
CREATE OR REPLACE FUNCTION public.rar_r1887_critical_signals_summary()
RETURNS TABLE (
  total_open int,
  total_critical_open int,
  total_warning_open int,
  total_info_open int,
  total_in_intervention int,
  total_cleared int,
  total_lost int,
  hospitals_at_risk int
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
    (COUNT(*) FILTER (WHERE status = 'open'))::int,
    (COUNT(*) FILTER (WHERE status = 'open' AND signal_severity = 'critical'))::int,
    (COUNT(*) FILTER (WHERE status = 'open' AND signal_severity = 'warning'))::int,
    (COUNT(*) FILTER (WHERE status = 'open' AND signal_severity = 'info'))::int,
    (COUNT(*) FILTER (WHERE status = 'in_intervention'))::int,
    (COUNT(*) FILTER (WHERE status = 'cleared'))::int,
    (COUNT(*) FILTER (WHERE status = 'lost'))::int,
    (COUNT(DISTINCT hospital_user_id) FILTER (WHERE status IN ('open','in_intervention')))::int
  FROM public.hospital_renewal_at_risk_signals_r1887;
END;
$$;

-- =====================================================================
-- RPC 7: recent_interventions
-- =====================================================================
DROP FUNCTION IF EXISTS public.rar_r1887_recent_interventions(int);
CREATE OR REPLACE FUNCTION public.rar_r1887_recent_interventions(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  signal_id uuid,
  intervention_type text,
  taken_at timestamptz,
  by_email text,
  outcome text,
  hospital_email text,
  signal_severity text
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
    i.id,
    i.signal_id,
    i.intervention_type,
    i.taken_at,
    i.by_email,
    i.outcome,
    p.email::text,
    s.signal_severity
  FROM public.hospital_renewal_at_risk_interventions_r1887 i
  JOIN public.hospital_renewal_at_risk_signals_r1887 s ON s.id = i.signal_id
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY i.taken_at DESC
  LIMIT COALESCE(p_limit, 20);
END;
$$;

-- =====================================================================
-- GRANTS
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.rar_r1887_list_signals(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rar_r1887_list_signals(text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.rar_r1887_log_signal(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rar_r1887_log_signal(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.rar_r1887_list_interventions(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rar_r1887_list_interventions(uuid, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.rar_r1887_log_intervention(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rar_r1887_log_intervention(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.rar_r1887_mark_cleared(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rar_r1887_mark_cleared(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.rar_r1887_critical_signals_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rar_r1887_critical_signals_summary() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.rar_r1887_recent_interventions(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rar_r1887_recent_interventions(int) TO authenticated;

COMMIT;