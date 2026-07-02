BEGIN;

-- =====================================================================
-- Round 1832 — Engineer Equipment Calibration Schedule
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.engineer_equipment_calibration_schedules_r1832 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid NOT NULL,
  equipment_name text NOT NULL,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_calibrated_at timestamptz,
  next_due_at timestamptz,
  calibration_interval_months int NOT NULL DEFAULT 12 CHECK (calibration_interval_months > 0),
  status text NOT NULL DEFAULT 'up_to_date' CHECK (status IN ('up_to_date','overdue','exempt','under_review')),
  calibration_proof_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_calibration_audit_log_r1832 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id uuid NOT NULL REFERENCES public.engineer_equipment_calibration_schedules_r1832(id) ON DELETE CASCADE,
  audit_type text NOT NULL CHECK (audit_type IN ('internal','external','regulator')),
  audit_at timestamptz NOT NULL DEFAULT now(),
  audit_outcome text NOT NULL CHECK (audit_outcome IN ('passed','failed','partial')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_calib_sched_r1832_hospital ON public.engineer_equipment_calibration_schedules_r1832(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_calib_sched_r1832_status ON public.engineer_equipment_calibration_schedules_r1832(status);
CREATE INDEX IF NOT EXISTS idx_calib_sched_r1832_due ON public.engineer_equipment_calibration_schedules_r1832(next_due_at);
CREATE INDEX IF NOT EXISTS idx_calib_audit_r1832_sched ON public.engineer_calibration_audit_log_r1832(schedule_id);
CREATE INDEX IF NOT EXISTS idx_calib_audit_r1832_at ON public.engineer_calibration_audit_log_r1832(audit_at);

ALTER TABLE public.engineer_equipment_calibration_schedules_r1832 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_calibration_audit_log_r1832 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS calib_sched_r1832_founder_all ON public.engineer_equipment_calibration_schedules_r1832;
CREATE POLICY calib_sched_r1832_founder_all ON public.engineer_equipment_calibration_schedules_r1832
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS calib_audit_r1832_founder_all ON public.engineer_calibration_audit_log_r1832;
CREATE POLICY calib_audit_r1832_founder_all ON public.engineer_calibration_audit_log_r1832
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_schedules
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_calibration_schedules_r1832(p_status text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  equipment_id uuid,
  equipment_name text,
  hospital_user_id uuid,
  last_calibrated_at timestamptz,
  next_due_at timestamptz,
  calibration_interval_months int,
  status text,
  calibration_proof_url text,
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
  SELECT s.id, s.equipment_id, s.equipment_name, s.hospital_user_id,
         s.last_calibrated_at, s.next_due_at, s.calibration_interval_months,
         s.status, s.calibration_proof_url, s.created_at
  FROM public.engineer_equipment_calibration_schedules_r1832 s
  WHERE p_status IS NULL OR s.status = p_status
  ORDER BY s.next_due_at NULLS LAST, s.created_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 2: set_schedule
-- =====================================================================
CREATE OR REPLACE FUNCTION public.set_calibration_schedule_r1832(
  p_equipment_id uuid,
  p_equipment_name text,
  p_hospital_user_id uuid,
  p_last_calibrated_at timestamptz,
  p_interval_months int,
  p_status text,
  p_proof_url text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_next timestamptz;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_next := COALESCE(p_last_calibrated_at, now()) + (p_interval_months || ' months')::interval;

  INSERT INTO public.engineer_equipment_calibration_schedules_r1832(
    equipment_id, equipment_name, hospital_user_id, last_calibrated_at,
    next_due_at, calibration_interval_months, status, calibration_proof_url
  ) VALUES (
    p_equipment_id, p_equipment_name, p_hospital_user_id, p_last_calibrated_at,
    v_next, p_interval_months, COALESCE(p_status,'up_to_date'), p_proof_url
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_calibration_schedule_r1832',
          jsonb_build_object('id', v_id, 'equipment_id', p_equipment_id, 'status', p_status));
  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_audits
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_calibration_audits_r1832(p_schedule_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  schedule_id uuid,
  audit_type text,
  audit_at timestamptz,
  audit_outcome text,
  notes text,
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
  SELECT a.id, a.schedule_id, a.audit_type, a.audit_at, a.audit_outcome, a.notes, a.created_at
  FROM public.engineer_calibration_audit_log_r1832 a
  WHERE p_schedule_id IS NULL OR a.schedule_id = p_schedule_id
  ORDER BY a.audit_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 4: log_audit
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_calibration_audit_r1832(
  p_schedule_id uuid,
  p_audit_type text,
  p_audit_outcome text,
  p_notes text
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
  INSERT INTO public.engineer_calibration_audit_log_r1832(schedule_id, audit_type, audit_outcome, notes)
  VALUES (p_schedule_id, p_audit_type, p_audit_outcome, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_calibration_audit_r1832',
          jsonb_build_object('id', v_id, 'schedule_id', p_schedule_id, 'outcome', p_audit_outcome));
  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5: mark_calibrated
-- =====================================================================
CREATE OR REPLACE FUNCTION public.mark_calibration_done_r1832(
  p_schedule_id uuid,
  p_proof_url text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_interval int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT calibration_interval_months INTO v_interval
  FROM public.engineer_equipment_calibration_schedules_r1832
  WHERE id = p_schedule_id;

  IF v_interval IS NULL THEN
    RAISE EXCEPTION 'schedule_not_found';
  END IF;

  UPDATE public.engineer_equipment_calibration_schedules_r1832
  SET last_calibrated_at = now(),
      next_due_at = now() + (v_interval || ' months')::interval,
      status = 'up_to_date',
      calibration_proof_url = COALESCE(p_proof_url, calibration_proof_url),
      updated_at = now()
  WHERE id = p_schedule_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_calibration_done_r1832',
          jsonb_build_object('schedule_id', p_schedule_id));
END;
$$;

-- =====================================================================
-- RPC 6: overdue_calibrations
-- =====================================================================
CREATE OR REPLACE FUNCTION public.overdue_calibrations_r1832()
RETURNS TABLE (
  id uuid,
  equipment_name text,
  hospital_user_id uuid,
  next_due_at timestamptz,
  days_overdue int,
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
  SELECT s.id, s.equipment_name, s.hospital_user_id, s.next_due_at,
         GREATEST(0, EXTRACT(DAY FROM (now() - s.next_due_at))::int) AS days_overdue,
         s.status
  FROM public.engineer_equipment_calibration_schedules_r1832 s
  WHERE s.next_due_at < now()
    AND s.status NOT IN ('exempt')
  ORDER BY s.next_due_at ASC
  LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 7: upcoming_calibrations
-- =====================================================================
CREATE OR REPLACE FUNCTION public.upcoming_calibrations_r1832(p_days int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  equipment_name text,
  hospital_user_id uuid,
  next_due_at timestamptz,
  days_until int,
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
  SELECT s.id, s.equipment_name, s.hospital_user_id, s.next_due_at,
         EXTRACT(DAY FROM (s.next_due_at - now()))::int AS days_until,
         s.status
  FROM public.engineer_equipment_calibration_schedules_r1832 s
  WHERE s.next_due_at BETWEEN now() AND now() + (p_days || ' days')::interval
    AND s.status NOT IN ('exempt')
  ORDER BY s.next_due_at ASC
  LIMIT 200;
END;
$$;

-- =====================================================================
-- Grants
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.list_calibration_schedules_r1832(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_calibration_schedule_r1832(uuid, text, uuid, timestamptz, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_calibration_audits_r1832(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_calibration_audit_r1832(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_calibration_done_r1832(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_calibrations_r1832() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_calibrations_r1832(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_calibration_schedules_r1832(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_calibration_schedule_r1832(uuid, text, uuid, timestamptz, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_calibration_audits_r1832(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_calibration_audit_r1832(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_calibration_done_r1832(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_calibrations_r1832() TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_calibrations_r1832(int) TO authenticated;

COMMIT;