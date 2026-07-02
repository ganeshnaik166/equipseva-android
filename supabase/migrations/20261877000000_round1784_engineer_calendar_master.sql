BEGIN;

-- ============================================================================
-- Round 1784: Engineer Calendar Master
-- Tables: engineer_calendar_events_r1784, engineer_calendar_conflicts_r1784
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_calendar_events_r1784 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_date date NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('job','shift','leave','training','meeting','personal')),
  start_time time,
  end_time time,
  event_title text NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','completed','cancelled')),
  repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_cal_events_r1784_eng_date ON public.engineer_calendar_events_r1784(engineer_user_id, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_eng_cal_events_r1784_date ON public.engineer_calendar_events_r1784(event_date DESC);
CREATE INDEX IF NOT EXISTS idx_eng_cal_events_r1784_type ON public.engineer_calendar_events_r1784(event_type);
CREATE INDEX IF NOT EXISTS idx_eng_cal_events_r1784_status ON public.engineer_calendar_events_r1784(status);

ALTER TABLE public.engineer_calendar_events_r1784 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eng_cal_events_r1784 ON public.engineer_calendar_events_r1784;
CREATE POLICY founder_all_eng_cal_events_r1784 ON public.engineer_calendar_events_r1784
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_calendar_conflicts_r1784 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  conflict_date date NOT NULL,
  conflict_type text NOT NULL CHECK (conflict_type IN ('job_vs_shift','job_vs_leave','job_vs_training','shift_vs_meeting')),
  severity text NOT NULL CHECK (severity IN ('info','warning','critical')),
  resolution_action text,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_cal_conflicts_r1784_eng_date ON public.engineer_calendar_conflicts_r1784(engineer_user_id, conflict_date DESC);
CREATE INDEX IF NOT EXISTS idx_eng_cal_conflicts_r1784_severity ON public.engineer_calendar_conflicts_r1784(severity);
CREATE INDEX IF NOT EXISTS idx_eng_cal_conflicts_r1784_unresolved ON public.engineer_calendar_conflicts_r1784(resolved_at) WHERE resolved_at IS NULL;

ALTER TABLE public.engineer_calendar_conflicts_r1784 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eng_cal_conflicts_r1784 ON public.engineer_calendar_conflicts_r1784;
CREATE POLICY founder_all_eng_cal_conflicts_r1784 ON public.engineer_calendar_conflicts_r1784
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_events
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_events_r1784(date, date, text);
CREATE OR REPLACE FUNCTION public.list_events_r1784(
  p_from date DEFAULT (CURRENT_DATE - INTERVAL '7 days')::date,
  p_to   date DEFAULT (CURRENT_DATE + INTERVAL '14 days')::date,
  p_event_type text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  event_date date,
  event_type text,
  start_time time,
  end_time time,
  event_title text,
  status text,
  repair_job_id uuid,
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
  SELECT
    e.id,
    e.engineer_user_id,
    p.email::text AS engineer_email,
    e.event_date,
    e.event_type,
    e.start_time,
    e.end_time,
    e.event_title,
    e.status,
    e.repair_job_id,
    e.created_at
  FROM public.engineer_calendar_events_r1784 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  WHERE e.event_date BETWEEN p_from AND p_to
    AND (p_event_type IS NULL OR e.event_type = p_event_type)
  ORDER BY e.event_date DESC, e.start_time NULLS LAST
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_events_r1784(date, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_events_r1784(date, date, text) TO authenticated;

-- ============================================================================
-- RPC 2: schedule_event
-- ============================================================================
DROP FUNCTION IF EXISTS public.schedule_event_r1784(uuid, date, text, time, time, text, uuid);
CREATE OR REPLACE FUNCTION public.schedule_event_r1784(
  p_engineer_user_id uuid,
  p_event_date date,
  p_event_type text,
  p_start_time time,
  p_end_time time,
  p_event_title text,
  p_repair_job_id uuid DEFAULT NULL
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

  INSERT INTO public.engineer_calendar_events_r1784(
    engineer_user_id, event_date, event_type, start_time, end_time, event_title, repair_job_id
  ) VALUES (
    p_engineer_user_id, p_event_date, p_event_type, p_start_time, p_end_time, p_event_title, p_repair_job_id
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'schedule_event_r1784',
    jsonb_build_object(
      'event_id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'event_date', p_event_date,
      'event_type', p_event_type,
      'event_title', p_event_title
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.schedule_event_r1784(uuid, date, text, time, time, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.schedule_event_r1784(uuid, date, text, time, time, text, uuid) TO authenticated;

-- ============================================================================
-- RPC 3: list_conflicts
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_conflicts_r1784(text, boolean);
CREATE OR REPLACE FUNCTION public.list_conflicts_r1784(
  p_severity text DEFAULT NULL,
  p_only_unresolved boolean DEFAULT true
)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  conflict_date date,
  conflict_type text,
  severity text,
  resolution_action text,
  resolved_at timestamptz,
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
  SELECT
    c.id,
    c.engineer_user_id,
    p.email::text AS engineer_email,
    c.conflict_date,
    c.conflict_type,
    c.severity,
    c.resolution_action,
    c.resolved_at,
    c.created_at
  FROM public.engineer_calendar_conflicts_r1784 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE (p_severity IS NULL OR c.severity = p_severity)
    AND (NOT p_only_unresolved OR c.resolved_at IS NULL)
  ORDER BY c.conflict_date DESC, c.severity
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_conflicts_r1784(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_conflicts_r1784(text, boolean) TO authenticated;

-- ============================================================================
-- RPC 4: detect_conflicts
-- ============================================================================
DROP FUNCTION IF EXISTS public.detect_conflicts_r1784(date);
CREATE OR REPLACE FUNCTION public.detect_conflicts_r1784(
  p_target_date date DEFAULT CURRENT_DATE
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inserted int := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  -- job_vs_leave conflicts
  WITH conflicts AS (
    INSERT INTO public.engineer_calendar_conflicts_r1784(engineer_user_id, conflict_date, conflict_type, severity)
    SELECT DISTINCT a.engineer_user_id, a.event_date, 'job_vs_leave', 'critical'
    FROM public.engineer_calendar_events_r1784 a
    JOIN public.engineer_calendar_events_r1784 b
      ON a.engineer_user_id = b.engineer_user_id
     AND a.event_date = b.event_date
     AND a.id <> b.id
    WHERE a.event_date = p_target_date
      AND a.event_type = 'job'
      AND b.event_type = 'leave'
      AND a.status NOT IN ('cancelled','completed')
      AND b.status NOT IN ('cancelled','completed')
    ON CONFLICT DO NOTHING
    RETURNING 1
  )
  SELECT COUNT(*)::int INTO v_inserted FROM conflicts;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'detect_conflicts_r1784',
    jsonb_build_object('target_date', p_target_date, 'inserted', v_inserted)
  );

  RETURN v_inserted;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.detect_conflicts_r1784(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.detect_conflicts_r1784(date) TO authenticated;

-- ============================================================================
-- RPC 5: resolve_conflict
-- ============================================================================
DROP FUNCTION IF EXISTS public.resolve_conflict_r1784(uuid, text);
CREATE OR REPLACE FUNCTION public.resolve_conflict_r1784(
  p_conflict_id uuid,
  p_resolution_action text
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

  UPDATE public.engineer_calendar_conflicts_r1784
  SET resolution_action = p_resolution_action,
      resolved_at = now(),
      updated_at = now()
  WHERE id = p_conflict_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'resolve_conflict_r1784',
    jsonb_build_object('conflict_id', p_conflict_id, 'resolution_action', p_resolution_action)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.resolve_conflict_r1784(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_conflict_r1784(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: daily_summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.daily_summary_r1784(date);
CREATE OR REPLACE FUNCTION public.daily_summary_r1784(
  p_target_date date DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_events int,
  jobs int,
  shifts int,
  leaves int,
  trainings int,
  meetings int,
  conflicts int
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
    e.engineer_user_id,
    p.email::text AS engineer_email,
    (COUNT(*))::int AS total_events,
    (COUNT(*) FILTER (WHERE e.event_type = 'job'))::int AS jobs,
    (COUNT(*) FILTER (WHERE e.event_type = 'shift'))::int AS shifts,
    (COUNT(*) FILTER (WHERE e.event_type = 'leave'))::int AS leaves,
    (COUNT(*) FILTER (WHERE e.event_type = 'training'))::int AS trainings,
    (COUNT(*) FILTER (WHERE e.event_type = 'meeting'))::int AS meetings,
    COALESCE((
      SELECT COUNT(*)::int
      FROM public.engineer_calendar_conflicts_r1784 c
      WHERE c.engineer_user_id = e.engineer_user_id
        AND c.conflict_date = p_target_date
    ), 0) AS conflicts
  FROM public.engineer_calendar_events_r1784 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  WHERE e.event_date = p_target_date
  GROUP BY e.engineer_user_id, p.email
  ORDER BY total_events DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.daily_summary_r1784(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.daily_summary_r1784(date) TO authenticated;

-- ============================================================================
-- RPC 7: weekly_load
-- ============================================================================
DROP FUNCTION IF EXISTS public.weekly_load_r1784(date);
CREATE OR REPLACE FUNCTION public.weekly_load_r1784(
  p_week_start date DEFAULT (CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::int) || ' days')::interval)::date
)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  week_start date,
  total_jobs int,
  total_shifts int,
  total_leaves int,
  total_trainings int,
  load_score numeric
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
    e.engineer_user_id,
    p.email::text AS engineer_email,
    p_week_start AS week_start,
    (COUNT(*) FILTER (WHERE e.event_type = 'job'))::int AS total_jobs,
    (COUNT(*) FILTER (WHERE e.event_type = 'shift'))::int AS total_shifts,
    (COUNT(*) FILTER (WHERE e.event_type = 'leave'))::int AS total_leaves,
    (COUNT(*) FILTER (WHERE e.event_type = 'training'))::int AS total_trainings,
    ROUND(
      (COUNT(*) FILTER (WHERE e.event_type = 'job'))::numeric * 1.5
      + (COUNT(*) FILTER (WHERE e.event_type = 'shift'))::numeric * 1.0
      + (COUNT(*) FILTER (WHERE e.event_type = 'training'))::numeric * 0.5,
      2
    ) AS load_score
  FROM public.engineer_calendar_events_r1784 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  WHERE e.event_date >= p_week_start
    AND e.event_date < (p_week_start + INTERVAL '7 days')::date
  GROUP BY e.engineer_user_id, p.email
  ORDER BY load_score DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.weekly_load_r1784(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_load_r1784(date) TO authenticated;

COMMIT;