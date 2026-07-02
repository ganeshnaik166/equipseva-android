BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_customer_activation_funnel_v2_r2147 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  signed_at timestamptz,
  first_repair_at timestamptz,
  days_to_first_repair int,
  activation_status text NOT NULL CHECK (activation_status IN ('fast','normal','slow','at_risk','stalled')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_activation_action_log_r2147 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  funnel_id uuid NOT NULL REFERENCES public.hospital_customer_activation_funnel_v2_r2147(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('signed','onboarding_completed','first_repair','at_risk','recovered')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_activation_funnel_v2_r2147 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_activation_action_log_r2147 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS funnel_r2147_founder_all ON public.hospital_customer_activation_funnel_v2_r2147;
CREATE POLICY funnel_r2147_founder_all ON public.hospital_customer_activation_funnel_v2_r2147
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS action_log_r2147_founder_all ON public.hospital_activation_action_log_r2147;
CREATE POLICY action_log_r2147_founder_all ON public.hospital_activation_action_log_r2147
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_funnels
CREATE OR REPLACE FUNCTION public.list_hospital_activation_funnels_r2147(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  signed_at timestamptz,
  first_repair_at timestamptz,
  days_to_first_repair int,
  activation_status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.hospital_id, f.signed_at, f.first_repair_at, f.days_to_first_repair, f.activation_status, f.captured_at
    FROM public.hospital_customer_activation_funnel_v2_r2147 f
    ORDER BY f.captured_at DESC
    LIMIT p_limit;
END;
$$;

-- RPC 2: log_funnel
CREATE OR REPLACE FUNCTION public.log_hospital_activation_funnel_r2147(
  p_hospital_id uuid,
  p_signed_at timestamptz,
  p_first_repair_at timestamptz,
  p_days_to_first_repair int,
  p_activation_status text
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
  INSERT INTO public.hospital_customer_activation_funnel_v2_r2147(
    hospital_id, signed_at, first_repair_at, days_to_first_repair, activation_status
  ) VALUES (
    p_hospital_id, p_signed_at, p_first_repair_at, p_days_to_first_repair, p_activation_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_hospital_activation_funnel_r2147',
          jsonb_build_object('funnel_id', v_id, 'hospital_id', p_hospital_id, 'status', p_activation_status),
          now());
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_hospital_activation_actions_r2147(p_funnel_id uuid)
RETURNS TABLE (
  id uuid,
  funnel_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.funnel_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_activation_action_log_r2147 a
    WHERE a.funnel_id = p_funnel_id
    ORDER BY a.taken_at DESC;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_hospital_activation_action_r2147(
  p_funnel_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.hospital_activation_action_log_r2147(funnel_id, action_type, by_email, notes_md)
  VALUES (p_funnel_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_hospital_activation_action_r2147',
          jsonb_build_object('action_id', v_id, 'funnel_id', p_funnel_id, 'action_type', p_action_type),
          now());
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_hospital_activation_status_r2147(
  p_funnel_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_activation_funnel_v2_r2147
  SET activation_status = p_status, updated_at = now()
  WHERE id = p_funnel_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_hospital_activation_status_r2147',
          jsonb_build_object('funnel_id', p_funnel_id, 'status', p_status),
          now());
END;
$$;

-- RPC 6: stalled
CREATE OR REPLACE FUNCTION public.list_stalled_hospital_activations_r2147()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  signed_at timestamptz,
  days_to_first_repair int,
  activation_status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.hospital_id, f.signed_at, f.days_to_first_repair, f.activation_status, f.captured_at
    FROM public.hospital_customer_activation_funnel_v2_r2147 f
    WHERE f.activation_status IN ('stalled','at_risk')
    ORDER BY f.captured_at DESC;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.list_recent_hospital_activation_actions_r2147(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  funnel_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.funnel_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_activation_action_log_r2147 a
    ORDER BY a.taken_at DESC
    LIMIT p_limit;
END;
$$;

-- Lock down
REVOKE EXECUTE ON FUNCTION public.list_hospital_activation_funnels_r2147(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_hospital_activation_funnel_r2147(uuid, timestamptz, timestamptz, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_hospital_activation_actions_r2147(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_hospital_activation_action_r2147(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_hospital_activation_status_r2147(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_stalled_hospital_activations_r2147() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_recent_hospital_activation_actions_r2147(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_hospital_activation_funnels_r2147(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_hospital_activation_funnel_r2147(uuid, timestamptz, timestamptz, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_hospital_activation_actions_r2147(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_hospital_activation_action_r2147(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_hospital_activation_status_r2147(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_stalled_hospital_activations_r2147() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_recent_hospital_activation_actions_r2147(int) TO authenticated;

COMMIT;
