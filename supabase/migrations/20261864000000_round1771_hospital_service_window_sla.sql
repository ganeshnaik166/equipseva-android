BEGIN;

-- ============================================================================
-- Round 1771 — Hospital Service Window SLA
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_service_sla_r1771 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sla_type text NOT NULL CHECK (sla_type IN ('response_time','resolution_time','uptime','escalation')),
  target_minutes int NOT NULL CHECK (target_minutes > 0),
  breach_count int NOT NULL DEFAULT 0,
  last_breach_at timestamptz,
  status text NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','at_risk','breach')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hssla_r1771_hospital ON public.hospital_service_sla_r1771(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hssla_r1771_status ON public.hospital_service_sla_r1771(status);
CREATE INDEX IF NOT EXISTS idx_hssla_r1771_type ON public.hospital_service_sla_r1771(sla_type);

ALTER TABLE public.hospital_service_sla_r1771 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hssla_r1771_founder_all ON public.hospital_service_sla_r1771;
CREATE POLICY hssla_r1771_founder_all ON public.hospital_service_sla_r1771
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.hospital_sla_breach_log_r1771 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sla_id uuid NOT NULL REFERENCES public.hospital_service_sla_r1771(id) ON DELETE CASCADE,
  breach_event_at timestamptz NOT NULL DEFAULT now(),
  actual_minutes int NOT NULL CHECK (actual_minutes >= 0),
  breach_reason text,
  customer_credit_rupees int NOT NULL DEFAULT 0 CHECK (customer_credit_rupees >= 0),
  credited_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsblog_r1771_sla ON public.hospital_sla_breach_log_r1771(sla_id);
CREATE INDEX IF NOT EXISTS idx_hsblog_r1771_event ON public.hospital_sla_breach_log_r1771(breach_event_at DESC);
CREATE INDEX IF NOT EXISTS idx_hsblog_r1771_credited ON public.hospital_sla_breach_log_r1771(credited_at);

ALTER TABLE public.hospital_sla_breach_log_r1771 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsblog_r1771_founder_all ON public.hospital_sla_breach_log_r1771;
CREATE POLICY hsblog_r1771_founder_all ON public.hospital_sla_breach_log_r1771
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- ============================================================================
-- RPC 1: list_slas
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_slas_r1771()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  sla_type text,
  target_minutes int,
  breach_count int,
  last_breach_at timestamptz,
  status text,
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
  SELECT s.id, s.hospital_user_id, p.email::text, s.sla_type, s.target_minutes,
         s.breach_count, s.last_breach_at, s.status, s.created_at
  FROM public.hospital_service_sla_r1771 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY s.status DESC, s.last_breach_at DESC NULLS LAST, s.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_slas_r1771() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_slas_r1771() TO authenticated;


-- ============================================================================
-- RPC 2: set_sla
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_sla_r1771(
  p_hospital_user_id uuid,
  p_sla_type text,
  p_target_minutes int
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

  INSERT INTO public.hospital_service_sla_r1771(hospital_user_id, sla_type, target_minutes)
  VALUES (p_hospital_user_id, p_sla_type, p_target_minutes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_sla_r1771',
          jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id,
                             'sla_type', p_sla_type, 'target_minutes', p_target_minutes));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_sla_r1771(uuid, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_sla_r1771(uuid, text, int) TO authenticated;


-- ============================================================================
-- RPC 3: list_breaches
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_breaches_r1771()
RETURNS TABLE (
  id uuid,
  sla_id uuid,
  sla_type text,
  hospital_email text,
  breach_event_at timestamptz,
  actual_minutes int,
  target_minutes int,
  breach_reason text,
  customer_credit_rupees int,
  credited_at timestamptz
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
  SELECT b.id, b.sla_id, s.sla_type, p.email::text, b.breach_event_at,
         b.actual_minutes, s.target_minutes, b.breach_reason,
         b.customer_credit_rupees, b.credited_at
  FROM public.hospital_sla_breach_log_r1771 b
  JOIN public.hospital_service_sla_r1771 s ON s.id = b.sla_id
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY b.breach_event_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_breaches_r1771() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_breaches_r1771() TO authenticated;


-- ============================================================================
-- RPC 4: log_breach
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_breach_r1771(
  p_sla_id uuid,
  p_actual_minutes int,
  p_breach_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_new_count int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.hospital_sla_breach_log_r1771(sla_id, actual_minutes, breach_reason)
  VALUES (p_sla_id, p_actual_minutes, p_breach_reason)
  RETURNING id INTO v_id;

  UPDATE public.hospital_service_sla_r1771
     SET breach_count = breach_count + 1,
         last_breach_at = now(),
         status = CASE
           WHEN breach_count + 1 >= 5 THEN 'breach'
           WHEN breach_count + 1 >= 2 THEN 'at_risk'
           ELSE 'on_track'
         END,
         updated_at = now()
   WHERE id = p_sla_id
   RETURNING breach_count INTO v_new_count;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_breach_r1771',
          jsonb_build_object('id', v_id, 'sla_id', p_sla_id, 'actual_minutes', p_actual_minutes,
                             'breach_count', v_new_count));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_breach_r1771(uuid, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_breach_r1771(uuid, int, text) TO authenticated;


-- ============================================================================
-- RPC 5: credit_breach
-- ============================================================================
CREATE OR REPLACE FUNCTION public.credit_breach_r1771(
  p_breach_id uuid,
  p_credit_rupees int
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

  UPDATE public.hospital_sla_breach_log_r1771
     SET customer_credit_rupees = p_credit_rupees,
         credited_at = now(),
         updated_at = now()
   WHERE id = p_breach_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'credit_breach_r1771',
          jsonb_build_object('breach_id', p_breach_id, 'credit_rupees', p_credit_rupees));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.credit_breach_r1771(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.credit_breach_r1771(uuid, int) TO authenticated;


-- ============================================================================
-- RPC 6: breach_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.breach_summary_r1771()
RETURNS TABLE (
  sla_type text,
  total_breaches int,
  total_credits_rupees bigint,
  avg_actual_minutes numeric,
  pending_credit_count int
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
  SELECT s.sla_type,
         (COUNT(*) FILTER (WHERE b.id IS NOT NULL))::int AS total_breaches,
         COALESCE(SUM(b.customer_credit_rupees), 0)::bigint AS total_credits_rupees,
         ROUND(AVG(b.actual_minutes)::numeric, 2) AS avg_actual_minutes,
         (COUNT(*) FILTER (WHERE b.id IS NOT NULL AND b.credited_at IS NULL))::int AS pending_credit_count
    FROM public.hospital_service_sla_r1771 s
    LEFT JOIN public.hospital_sla_breach_log_r1771 b ON b.sla_id = s.id
   GROUP BY s.sla_type
   ORDER BY total_breaches DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.breach_summary_r1771() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.breach_summary_r1771() TO authenticated;


-- ============================================================================
-- RPC 7: sla_at_risk
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sla_at_risk_r1771()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  sla_type text,
  target_minutes int,
  breach_count int,
  last_breach_at timestamptz,
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
  SELECT s.id, p.email::text, s.sla_type, s.target_minutes,
         s.breach_count, s.last_breach_at, s.status
    FROM public.hospital_service_sla_r1771 s
    LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
   WHERE s.status IN ('at_risk','breach')
   ORDER BY (s.status = 'breach') DESC, s.last_breach_at DESC NULLS LAST
   LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sla_at_risk_r1771() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sla_at_risk_r1771() TO authenticated;

COMMIT;