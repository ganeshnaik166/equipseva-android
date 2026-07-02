BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_repeat_repair_failure_detector_r2168 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  repeat_failure_count int NOT NULL DEFAULT 0,
  total_repairs int NOT NULL DEFAULT 0,
  repeat_failure_rate_pct numeric(6,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'normal' CHECK (status IN ('normal','elevated','concerning','critical')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_err_failure_detector_r2168_engineer ON public.engineer_repeat_repair_failure_detector_r2168(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_err_failure_detector_r2168_status ON public.engineer_repeat_repair_failure_detector_r2168(status);
CREATE INDEX IF NOT EXISTS idx_err_failure_detector_r2168_captured ON public.engineer_repeat_repair_failure_detector_r2168(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_failure_action_log_r2168 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  detector_id uuid NOT NULL REFERENCES public.engineer_repeat_repair_failure_detector_r2168(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coached','retrained','escalated','closed','exit_planned')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_err_failure_action_log_r2168_detector ON public.engineer_failure_action_log_r2168(detector_id);
CREATE INDEX IF NOT EXISTS idx_err_failure_action_log_r2168_taken ON public.engineer_failure_action_log_r2168(taken_at DESC);

ALTER TABLE public.engineer_repeat_repair_failure_detector_r2168 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_failure_action_log_r2168 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_err_detector_r2168 ON public.engineer_repeat_repair_failure_detector_r2168;
CREATE POLICY founder_all_err_detector_r2168 ON public.engineer_repeat_repair_failure_detector_r2168
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_err_action_log_r2168 ON public.engineer_failure_action_log_r2168;
CREATE POLICY founder_all_err_action_log_r2168 ON public.engineer_failure_action_log_r2168
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_detectors
DROP FUNCTION IF EXISTS public.list_detectors_r2168();
CREATE OR REPLACE FUNCTION public.list_detectors_r2168()
RETURNS SETOF public.engineer_repeat_repair_failure_detector_r2168
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_repeat_repair_failure_detector_r2168
    ORDER BY captured_at DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_detectors_r2168() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_detectors_r2168() TO authenticated;

-- RPC 2: log_detector
DROP FUNCTION IF EXISTS public.log_detector_r2168(uuid, text, int, int, numeric, text);
CREATE OR REPLACE FUNCTION public.log_detector_r2168(
  p_engineer_user_id uuid,
  p_period_label text,
  p_repeat_failure_count int,
  p_total_repairs int,
  p_repeat_failure_rate_pct numeric,
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
  INSERT INTO public.engineer_repeat_repair_failure_detector_r2168(
    engineer_user_id, period_label, repeat_failure_count, total_repairs, repeat_failure_rate_pct, status
  ) VALUES (
    p_engineer_user_id, p_period_label, p_repeat_failure_count, p_total_repairs, p_repeat_failure_rate_pct, p_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_detector_r2168',
    jsonb_build_object('detector_id', v_id, 'engineer_user_id', p_engineer_user_id, 'status', p_status)
  );
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_detector_r2168(uuid, text, int, int, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_detector_r2168(uuid, text, int, int, numeric, text) TO authenticated;

-- RPC 3: list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2168(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2168(p_detector_id uuid)
RETURNS SETOF public.engineer_failure_action_log_r2168
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_failure_action_log_r2168
    WHERE detector_id = p_detector_id
    ORDER BY taken_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2168(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2168(uuid) TO authenticated;

-- RPC 4: log_action
DROP FUNCTION IF EXISTS public.log_action_r2168(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2168(
  p_detector_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_failure_action_log_r2168(detector_id, action_type, by_email, notes_md)
  VALUES (p_detector_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_action_r2168',
    jsonb_build_object('action_id', v_id, 'detector_id', p_detector_id, 'action_type', p_action_type)
  );
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2168(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2168(uuid, text, text, text) TO authenticated;

-- RPC 5: mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2168(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2168(p_detector_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_repeat_repair_failure_detector_r2168
     SET status = p_status, updated_at = now()
   WHERE id = p_detector_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r2168',
    jsonb_build_object('detector_id', p_detector_id, 'status', p_status)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2168(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2168(uuid, text) TO authenticated;

-- RPC 6: critical_engineers
DROP FUNCTION IF EXISTS public.critical_engineers_r2168();
CREATE OR REPLACE FUNCTION public.critical_engineers_r2168()
RETURNS SETOF public.engineer_repeat_repair_failure_detector_r2168
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_repeat_repair_failure_detector_r2168
    WHERE status IN ('concerning','critical')
    ORDER BY repeat_failure_rate_pct DESC
    LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.critical_engineers_r2168() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.critical_engineers_r2168() TO authenticated;

-- RPC 7: recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2168();
CREATE OR REPLACE FUNCTION public.recent_actions_r2168()
RETURNS SETOF public.engineer_failure_action_log_r2168
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_failure_action_log_r2168
    ORDER BY taken_at DESC
    LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2168() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2168() TO authenticated;

COMMIT;
