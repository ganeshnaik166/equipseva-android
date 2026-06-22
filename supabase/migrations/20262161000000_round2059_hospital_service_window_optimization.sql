BEGIN;

-- ============================================================================
-- r2059 — Hospital Service Window Optimization
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_service_window_optimization_r2059 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_window_start time NOT NULL,
  current_window_end time NOT NULL,
  proposed_window_start time NOT NULL,
  proposed_window_end time NOT NULL,
  expected_efficiency_gain_pct numeric(6,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'current' CHECK (status IN ('current','proposed','adopted','declined')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsw_opt_r2059_hospital ON public.hospital_service_window_optimization_r2059(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hsw_opt_r2059_status ON public.hospital_service_window_optimization_r2059(status);
CREATE INDEX IF NOT EXISTS idx_hsw_opt_r2059_captured ON public.hospital_service_window_optimization_r2059(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_window_optimization_log_r2059 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  optimization_id uuid NOT NULL REFERENCES public.hospital_service_window_optimization_r2059(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('proposed','discussed','adopted','declined','escalated','superseded')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hwo_log_r2059_opt ON public.hospital_window_optimization_log_r2059(optimization_id);
CREATE INDEX IF NOT EXISTS idx_hwo_log_r2059_taken ON public.hospital_window_optimization_log_r2059(taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_hwo_log_r2059_action ON public.hospital_window_optimization_log_r2059(action_type);

ALTER TABLE public.hospital_service_window_optimization_r2059 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_window_optimization_log_r2059 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsw_opt_r2059_founder_all ON public.hospital_service_window_optimization_r2059;
CREATE POLICY hsw_opt_r2059_founder_all ON public.hospital_service_window_optimization_r2059
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hwo_log_r2059_founder_all ON public.hospital_window_optimization_log_r2059;
CREATE POLICY hwo_log_r2059_founder_all ON public.hospital_window_optimization_log_r2059
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_optimizations
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_optimizations_r2059(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  current_window_start time,
  current_window_end time,
  proposed_window_start time,
  proposed_window_end time,
  expected_efficiency_gain_pct numeric,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.hospital_id, COALESCE(p.full_name, p.email, 'Hospital'),
           o.current_window_start, o.current_window_end,
           o.proposed_window_start, o.proposed_window_end,
           o.expected_efficiency_gain_pct, o.status, o.captured_at
    FROM public.hospital_service_window_optimization_r2059 o
    LEFT JOIN public.profiles p ON p.id = o.hospital_id
    ORDER BY o.captured_at DESC
    LIMIT p_limit;
END;
$$;

-- ============================================================================
-- RPC 2: log_optimization (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_optimization_r2059(
  p_hospital_id uuid,
  p_current_start time,
  p_current_end time,
  p_proposed_start time,
  p_proposed_end time,
  p_gain_pct numeric,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_window_optimization_r2059(
    hospital_id, current_window_start, current_window_end,
    proposed_window_start, proposed_window_end,
    expected_efficiency_gain_pct, status
  )
  VALUES (p_hospital_id, p_current_start, p_current_end,
          p_proposed_start, p_proposed_end,
          COALESCE(p_gain_pct, 0), COALESCE(p_status, 'proposed'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_optimization_r2059',
          jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'gain_pct', p_gain_pct));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r2059(p_optimization_id uuid DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  optimization_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.optimization_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.hospital_window_optimization_log_r2059 l
    WHERE p_optimization_id IS NULL OR l.optimization_id = p_optimization_id
    ORDER BY l.taken_at DESC
    LIMIT p_limit;
END;
$$;

-- ============================================================================
-- RPC 4: log_action (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_action_r2059(
  p_optimization_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_window_optimization_log_r2059(optimization_id, action_type, by_email, notes_md)
  VALUES (p_optimization_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2059',
          jsonb_build_object('id', v_id, 'optimization_id', p_optimization_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2059(p_optimization_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_window_optimization_r2059
    SET status = p_status, updated_at = now()
    WHERE id = p_optimization_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2059',
          jsonb_build_object('id', p_optimization_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 6: proposed_optimizations
-- ============================================================================
CREATE OR REPLACE FUNCTION public.proposed_optimizations_r2059()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  proposed_window_start time,
  proposed_window_end time,
  expected_efficiency_gain_pct numeric,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.hospital_id, COALESCE(p.full_name, p.email, 'Hospital'),
           o.proposed_window_start, o.proposed_window_end,
           o.expected_efficiency_gain_pct, o.captured_at
    FROM public.hospital_service_window_optimization_r2059 o
    LEFT JOIN public.profiles p ON p.id = o.hospital_id
    WHERE o.status = 'proposed'
    ORDER BY o.expected_efficiency_gain_pct DESC NULLS LAST, o.captured_at DESC;
END;
$$;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r2059(p_days int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  optimization_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.optimization_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.hospital_window_optimization_log_r2059 l
    WHERE l.taken_at >= now() - (p_days || ' days')::interval
    ORDER BY l.taken_at DESC;
END;
$$;

-- ============================================================================
-- GRANTS — REVOKE from PUBLIC/anon, GRANT to authenticated
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_optimizations_r2059(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_optimizations_r2059(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_optimization_r2059(uuid, time, time, time, time, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_optimization_r2059(uuid, time, time, time, time, numeric, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_actions_r2059(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2059(uuid, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_action_r2059(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2059(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_status_r2059(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2059(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.proposed_optimizations_r2059() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.proposed_optimizations_r2059() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r2059(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2059(int) TO authenticated;

COMMIT;
