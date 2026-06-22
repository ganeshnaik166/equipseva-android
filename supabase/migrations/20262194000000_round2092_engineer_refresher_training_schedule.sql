BEGIN;

-- ============================================================================
-- Round 2092 — Engineer Refresher Training Schedule
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_refresher_training_schedule_r2092 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  training_topic text NOT NULL,
  scheduled_date date NOT NULL,
  target_attendee_count int NOT NULL DEFAULT 0,
  actual_attendee_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','completed','postponed','cancelled')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_refresher_attendance_log_r2092 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  training_id uuid NOT NULL REFERENCES public.engineer_refresher_training_schedule_r2092(id) ON DELETE CASCADE,
  attendee_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  attended boolean NOT NULL DEFAULT false,
  comprehension_score int,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rts_r2092_date ON public.engineer_refresher_training_schedule_r2092(scheduled_date DESC);
CREATE INDEX IF NOT EXISTS idx_rts_r2092_status ON public.engineer_refresher_training_schedule_r2092(status);
CREATE INDEX IF NOT EXISTS idx_ral_r2092_training ON public.engineer_refresher_attendance_log_r2092(training_id);
CREATE INDEX IF NOT EXISTS idx_ral_r2092_user ON public.engineer_refresher_attendance_log_r2092(attendee_user_id);

ALTER TABLE public.engineer_refresher_training_schedule_r2092 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_refresher_attendance_log_r2092 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rts_r2092_founder_all ON public.engineer_refresher_training_schedule_r2092;
CREATE POLICY rts_r2092_founder_all ON public.engineer_refresher_training_schedule_r2092
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS ral_r2092_founder_all ON public.engineer_refresher_attendance_log_r2092;
CREATE POLICY ral_r2092_founder_all ON public.engineer_refresher_attendance_log_r2092
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_trainings
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_trainings_r2092()
RETURNS TABLE (
  id uuid,
  training_topic text,
  scheduled_date date,
  target_attendee_count int,
  actual_attendee_count int,
  status text,
  captured_at timestamptz
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
    SELECT t.id, t.training_topic, t.scheduled_date, t.target_attendee_count,
           t.actual_attendee_count, t.status, t.captured_at
    FROM public.engineer_refresher_training_schedule_r2092 t
    ORDER BY t.scheduled_date DESC
    LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: log_training (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_training_r2092(
  p_topic text,
  p_scheduled_date date,
  p_target_attendee_count int
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
  INSERT INTO public.engineer_refresher_training_schedule_r2092
    (training_topic, scheduled_date, target_attendee_count)
  VALUES (p_topic, p_scheduled_date, COALESCE(p_target_attendee_count, 0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_training_r2092',
    jsonb_build_object('id', v_id, 'topic', p_topic, 'date', p_scheduled_date)
  );
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_attendances
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_attendances_r2092(p_training_id uuid)
RETURNS TABLE (
  id uuid,
  training_id uuid,
  attendee_user_id uuid,
  attended boolean,
  comprehension_score int,
  recorded_at timestamptz,
  by_email text
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
    SELECT a.id, a.training_id, a.attendee_user_id, a.attended,
           a.comprehension_score, a.recorded_at, a.by_email
    FROM public.engineer_refresher_attendance_log_r2092 a
    WHERE a.training_id = p_training_id
    ORDER BY a.recorded_at DESC
    LIMIT 500;
END;
$$;

-- ============================================================================
-- RPC 4: log_attendance (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_attendance_r2092(
  p_training_id uuid,
  p_attendee_user_id uuid,
  p_attended boolean,
  p_score int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.engineer_refresher_attendance_log_r2092
    (training_id, attendee_user_id, attended, comprehension_score, by_email)
  VALUES (p_training_id, p_attendee_user_id, COALESCE(p_attended,false), p_score, v_email)
  RETURNING id INTO v_id;

  IF COALESCE(p_attended,false) THEN
    UPDATE public.engineer_refresher_training_schedule_r2092
      SET actual_attendee_count = actual_attendee_count + 1,
          updated_at = now()
      WHERE id = p_training_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_attendance_r2092',
    jsonb_build_object('id', v_id, 'training_id', p_training_id, 'attendee', p_attendee_user_id, 'attended', p_attended)
  );
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2092(
  p_training_id uuid,
  p_status text
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
  IF p_status NOT IN ('scheduled','completed','postponed','cancelled') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.engineer_refresher_training_schedule_r2092
    SET status = p_status, updated_at = now()
    WHERE id = p_training_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r2092',
    jsonb_build_object('training_id', p_training_id, 'status', p_status)
  );
END;
$$;

-- ============================================================================
-- RPC 6: upcoming_trainings
-- ============================================================================
CREATE OR REPLACE FUNCTION public.upcoming_trainings_r2092()
RETURNS TABLE (
  id uuid,
  training_topic text,
  scheduled_date date,
  target_attendee_count int,
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
    SELECT t.id, t.training_topic, t.scheduled_date, t.target_attendee_count, t.status
    FROM public.engineer_refresher_training_schedule_r2092 t
    WHERE t.scheduled_date >= CURRENT_DATE
      AND t.status = 'scheduled'
    ORDER BY t.scheduled_date ASC
    LIMIT 50;
END;
$$;

-- ============================================================================
-- RPC 7: recent_attendances
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_attendances_r2092()
RETURNS TABLE (
  id uuid,
  training_id uuid,
  training_topic text,
  attendee_user_id uuid,
  attended boolean,
  comprehension_score int,
  recorded_at timestamptz,
  by_email text
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
    SELECT a.id, a.training_id, t.training_topic, a.attendee_user_id, a.attended,
           a.comprehension_score, a.recorded_at, a.by_email
    FROM public.engineer_refresher_attendance_log_r2092 a
    JOIN public.engineer_refresher_training_schedule_r2092 t ON t.id = a.training_id
    ORDER BY a.recorded_at DESC
    LIMIT 100;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_trainings_r2092() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_training_r2092(text, date, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_attendances_r2092(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_attendance_r2092(uuid, uuid, boolean, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2092(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_trainings_r2092() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_attendances_r2092() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_trainings_r2092() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_training_r2092(text, date, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_attendances_r2092(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_attendance_r2092(uuid, uuid, boolean, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2092(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_trainings_r2092() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_attendances_r2092() TO authenticated;

COMMIT;
