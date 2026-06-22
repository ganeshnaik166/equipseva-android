BEGIN;

-- =========================================================================
-- Round r2004 — Engineer Travel Time Tracker
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.engineer_travel_time_tracker_r2004 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  repair_job_id uuid,
  hospital_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  expected_travel_minutes int NOT NULL DEFAULT 0,
  actual_travel_minutes int NOT NULL DEFAULT 0,
  variance_minutes int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'on_time' CHECK (status IN ('on_time','delayed','early','cancelled')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_travel_action_log_r2004 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  travel_id uuid NOT NULL REFERENCES public.engineer_travel_time_tracker_r2004(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('arrived','delayed','cancelled','escalated','reimbursed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_travel_r2004_status ON public.engineer_travel_time_tracker_r2004(status);
CREATE INDEX IF NOT EXISTS idx_engineer_travel_r2004_captured ON public.engineer_travel_time_tracker_r2004(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_engineer_travel_action_r2004_taken ON public.engineer_travel_action_log_r2004(taken_at DESC);

ALTER TABLE public.engineer_travel_time_tracker_r2004 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_travel_action_log_r2004 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_engineer_travel_r2004 ON public.engineer_travel_time_tracker_r2004;
CREATE POLICY p_founder_all_engineer_travel_r2004 ON public.engineer_travel_time_tracker_r2004
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_all_engineer_travel_action_r2004 ON public.engineer_travel_action_log_r2004;
CREATE POLICY p_founder_all_engineer_travel_action_r2004 ON public.engineer_travel_action_log_r2004
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs
-- =========================================================================

DROP FUNCTION IF EXISTS public.list_travels_r2004();
CREATE OR REPLACE FUNCTION public.list_travels_r2004()
RETURNS TABLE(id uuid, engineer_user_id uuid, repair_job_id uuid, hospital_id uuid, expected_travel_minutes int, actual_travel_minutes int, variance_minutes int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.engineer_user_id, t.repair_job_id, t.hospital_id, t.expected_travel_minutes, t.actual_travel_minutes, t.variance_minutes, t.status, t.captured_at
    FROM public.engineer_travel_time_tracker_r2004 t
    ORDER BY t.captured_at DESC
    LIMIT 200;
END; $$;

DROP FUNCTION IF EXISTS public.log_travel_r2004(uuid, uuid, uuid, int, int, text);
CREATE OR REPLACE FUNCTION public.log_travel_r2004(
  p_engineer_user_id uuid,
  p_repair_job_id uuid,
  p_hospital_id uuid,
  p_expected_minutes int,
  p_actual_minutes int,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_variance int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_variance := COALESCE(p_actual_minutes,0) - COALESCE(p_expected_minutes,0);
  INSERT INTO public.engineer_travel_time_tracker_r2004(engineer_user_id, repair_job_id, hospital_id, expected_travel_minutes, actual_travel_minutes, variance_minutes, status)
    VALUES (p_engineer_user_id, p_repair_job_id, p_hospital_id, COALESCE(p_expected_minutes,0), COALESCE(p_actual_minutes,0), v_variance, COALESCE(p_status,'on_time'))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_travel_r2004', jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'status', p_status, 'variance', v_variance));
  RETURN v_id;
END; $$;

DROP FUNCTION IF EXISTS public.list_actions_r2004(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2004(p_travel_id uuid)
RETURNS TABLE(id uuid, travel_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.travel_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_travel_action_log_r2004 a
    WHERE a.travel_id = p_travel_id
    ORDER BY a.taken_at DESC;
END; $$;

DROP FUNCTION IF EXISTS public.log_action_r2004(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2004(
  p_travel_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_travel_action_log_r2004(travel_id, action_type, by_email, notes_md)
    VALUES (p_travel_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2004', jsonb_build_object('id', v_id, 'travel_id', p_travel_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

DROP FUNCTION IF EXISTS public.mark_status_r2004(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2004(p_travel_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_travel_time_tracker_r2004 SET status = p_status, updated_at = now() WHERE id = p_travel_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2004', jsonb_build_object('id', p_travel_id, 'status', p_status));
END; $$;

DROP FUNCTION IF EXISTS public.delayed_travels_r2004();
CREATE OR REPLACE FUNCTION public.delayed_travels_r2004()
RETURNS TABLE(id uuid, engineer_user_id uuid, hospital_id uuid, expected_travel_minutes int, actual_travel_minutes int, variance_minutes int, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.engineer_user_id, t.hospital_id, t.expected_travel_minutes, t.actual_travel_minutes, t.variance_minutes, t.captured_at
    FROM public.engineer_travel_time_tracker_r2004 t
    WHERE t.status = 'delayed'
    ORDER BY t.variance_minutes DESC
    LIMIT 100;
END; $$;

DROP FUNCTION IF EXISTS public.recent_actions_r2004();
CREATE OR REPLACE FUNCTION public.recent_actions_r2004()
RETURNS TABLE(id uuid, travel_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.travel_id, a.action_type, a.taken_at, a.by_email
    FROM public.engineer_travel_action_log_r2004 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END; $$;

-- =========================================================================
-- Permissions
-- =========================================================================

REVOKE EXECUTE ON FUNCTION public.list_travels_r2004() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_travel_r2004(uuid, uuid, uuid, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2004(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2004(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2004(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.delayed_travels_r2004() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2004() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_travels_r2004() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_travel_r2004(uuid, uuid, uuid, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2004(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2004(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2004(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delayed_travels_r2004() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2004() TO authenticated;

COMMIT;
