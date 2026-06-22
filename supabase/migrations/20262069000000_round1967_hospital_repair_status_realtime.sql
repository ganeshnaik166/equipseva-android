BEGIN;

-- =====================================================================
-- Round 1967 — Hospital Real-Time Repair Status
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.hospital_repair_status_realtime_r1967 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  repair_job_id uuid,
  status_phase text NOT NULL CHECK (status_phase IN ('assigned','in_transit','diagnosing','repairing','awaiting_parts','testing','complete')),
  engineer_user_id uuid REFERENCES public.profiles(id),
  expected_finish_at timestamptz,
  last_ping_at timestamptz,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_repair_status_action_log_r1967 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  status_id uuid NOT NULL REFERENCES public.hospital_repair_status_realtime_r1967(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('phase_changed','escalation','customer_notification','eta_revised','job_held')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_repair_status_realtime_r1967 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_repair_status_action_log_r1967 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_status_r1967 ON public.hospital_repair_status_realtime_r1967;
CREATE POLICY founder_all_status_r1967 ON public.hospital_repair_status_realtime_r1967
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actionlog_r1967 ON public.hospital_repair_status_action_log_r1967;
CREATE POLICY founder_all_actionlog_r1967 ON public.hospital_repair_status_action_log_r1967
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_status
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_repair_status_r1967()
RETURNS SETOF public.hospital_repair_status_realtime_r1967
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_repair_status_realtime_r1967 ORDER BY captured_at DESC LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_repair_status_r1967() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_repair_status_r1967() TO authenticated;

-- =====================================================================
-- RPC 2: log_status
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_repair_status_r1967(
  p_hospital_id uuid,
  p_repair_job_id uuid,
  p_status_phase text,
  p_engineer_user_id uuid,
  p_expected_finish_at timestamptz
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
  INSERT INTO public.hospital_repair_status_realtime_r1967(hospital_id, repair_job_id, status_phase, engineer_user_id, expected_finish_at, last_ping_at)
    VALUES (p_hospital_id, p_repair_job_id, p_status_phase, p_engineer_user_id, p_expected_finish_at, now())
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_repair_status_r1967', jsonb_build_object('status_id', v_id, 'phase', p_status_phase));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_repair_status_r1967(uuid, uuid, text, uuid, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_repair_status_r1967(uuid, uuid, text, uuid, timestamptz) TO authenticated;

-- =====================================================================
-- RPC 3: list_actions
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_repair_status_actions_r1967()
RETURNS SETOF public.hospital_repair_status_action_log_r1967
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_repair_status_action_log_r1967 ORDER BY taken_at DESC LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_repair_status_actions_r1967() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_repair_status_actions_r1967() TO authenticated;

-- =====================================================================
-- RPC 4: log_action
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_repair_status_action_r1967(
  p_status_id uuid,
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
  INSERT INTO public.hospital_repair_status_action_log_r1967(status_id, action_type, by_email, notes_md)
    VALUES (p_status_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_repair_status_action_r1967', jsonb_build_object('action_id', v_id, 'type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_repair_status_action_r1967(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_repair_status_action_r1967(uuid, text, text, text) TO authenticated;

-- =====================================================================
-- RPC 5: mark_status
-- =====================================================================
CREATE OR REPLACE FUNCTION public.mark_repair_status_r1967(
  p_status_id uuid,
  p_phase text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_repair_status_realtime_r1967
    SET status_phase = p_phase, last_ping_at = now(), updated_at = now()
    WHERE id = p_status_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_repair_status_r1967', jsonb_build_object('status_id', p_status_id, 'phase', p_phase));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_repair_status_r1967(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_repair_status_r1967(uuid, text) TO authenticated;

-- =====================================================================
-- RPC 6: in_flight_repairs
-- =====================================================================
CREATE OR REPLACE FUNCTION public.in_flight_repairs_r1967()
RETURNS TABLE(status_phase text, cnt bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.status_phase, count(*)::bigint
    FROM public.hospital_repair_status_realtime_r1967 s
    WHERE s.status_phase <> 'complete'
    GROUP BY s.status_phase
    ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.in_flight_repairs_r1967() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.in_flight_repairs_r1967() TO authenticated;

-- =====================================================================
-- RPC 7: recent_actions
-- =====================================================================
CREATE OR REPLACE FUNCTION public.recent_repair_status_actions_r1967(p_limit int DEFAULT 50)
RETURNS SETOF public.hospital_repair_status_action_log_r1967
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_repair_status_action_log_r1967 ORDER BY taken_at DESC LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_repair_status_actions_r1967(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_repair_status_actions_r1967(int) TO authenticated;

COMMIT;
