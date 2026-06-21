BEGIN;

-- ============================================================================
-- Round 1732: Engineer Shift Schedule Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_shifts_r1732 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  shift_date date NOT NULL,
  shift_start time NOT NULL,
  shift_end time NOT NULL,
  shift_type text NOT NULL CHECK (shift_type IN ('day','night','on_call','off_duty','leave')),
  swap_requested boolean NOT NULL DEFAULT false,
  swapped_with_user_id uuid REFERENCES public.profiles(id),
  locked_by_founder boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_shifts_r1732_eng_date
  ON public.engineer_shifts_r1732 (engineer_user_id, shift_date DESC);
CREATE INDEX IF NOT EXISTS idx_eng_shifts_r1732_date
  ON public.engineer_shifts_r1732 (shift_date DESC);

CREATE TABLE IF NOT EXISTS public.engineer_shift_swaps_r1732 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shift_id uuid NOT NULL REFERENCES public.engineer_shifts_r1732(id) ON DELETE CASCADE,
  requested_by_user_id uuid NOT NULL,
  target_user_id uuid NOT NULL,
  reason text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  approved boolean,
  decided_at timestamptz,
  decided_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_swaps_r1732_shift
  ON public.engineer_shift_swaps_r1732 (shift_id);
CREATE INDEX IF NOT EXISTS idx_eng_swaps_r1732_requested_at
  ON public.engineer_shift_swaps_r1732 (requested_at DESC);

ALTER TABLE public.engineer_shifts_r1732 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_shift_swaps_r1732 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_engineer_shifts_r1732 ON public.engineer_shifts_r1732;
CREATE POLICY founder_all_engineer_shifts_r1732 ON public.engineer_shifts_r1732
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_engineer_shift_swaps_r1732 ON public.engineer_shift_swaps_r1732;
CREATE POLICY founder_all_engineer_shift_swaps_r1732 ON public.engineer_shift_swaps_r1732
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC: list_shifts
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_shifts_r1732(
  p_from date DEFAULT (now()::date - 7),
  p_to date DEFAULT (now()::date + 14)
)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  shift_date date,
  shift_start time,
  shift_end time,
  shift_type text,
  swap_requested boolean,
  swapped_with_user_id uuid,
  locked_by_founder boolean,
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
  SELECT
    s.id,
    s.engineer_user_id,
    p.email,
    s.shift_date,
    s.shift_start,
    s.shift_end,
    s.shift_type,
    s.swap_requested,
    s.swapped_with_user_id,
    s.locked_by_founder,
    s.notes,
    s.created_at
  FROM public.engineer_shifts_r1732 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.shift_date BETWEEN p_from AND p_to
  ORDER BY s.shift_date ASC, s.shift_start ASC;
END;
$$;

-- ============================================================================
-- RPC: schedule_shift
-- ============================================================================
CREATE OR REPLACE FUNCTION public.schedule_shift_r1732(
  p_engineer_user_id uuid,
  p_shift_date date,
  p_shift_start time,
  p_shift_end time,
  p_shift_type text,
  p_locked boolean DEFAULT false,
  p_notes text DEFAULT NULL
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

  INSERT INTO public.engineer_shifts_r1732
    (engineer_user_id, shift_date, shift_start, shift_end, shift_type, locked_by_founder, notes)
  VALUES
    (p_engineer_user_id, p_shift_date, p_shift_start, p_shift_end, p_shift_type, COALESCE(p_locked,false), p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'schedule_shift_r1732',
    jsonb_build_object(
      'shift_id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'shift_date', p_shift_date,
      'shift_type', p_shift_type,
      'locked', p_locked
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC: list_swaps
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_swaps_r1732()
RETURNS TABLE (
  id uuid,
  shift_id uuid,
  shift_date date,
  shift_type text,
  requested_by_user_id uuid,
  requested_by_email text,
  target_user_id uuid,
  target_email text,
  reason text,
  requested_at timestamptz,
  approved boolean,
  decided_at timestamptz,
  decided_by_email text
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
    w.id,
    w.shift_id,
    s.shift_date,
    s.shift_type,
    w.requested_by_user_id,
    p1.email,
    w.target_user_id,
    p2.email,
    w.reason,
    w.requested_at,
    w.approved,
    w.decided_at,
    w.decided_by_email
  FROM public.engineer_shift_swaps_r1732 w
  LEFT JOIN public.engineer_shifts_r1732 s ON s.id = w.shift_id
  LEFT JOIN public.profiles p1 ON p1.id = w.requested_by_user_id
  LEFT JOIN public.profiles p2 ON p2.id = w.target_user_id
  ORDER BY w.requested_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC: request_swap
-- ============================================================================
CREATE OR REPLACE FUNCTION public.request_swap_r1732(
  p_shift_id uuid,
  p_requested_by_user_id uuid,
  p_target_user_id uuid,
  p_reason text DEFAULT NULL
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

  INSERT INTO public.engineer_shift_swaps_r1732
    (shift_id, requested_by_user_id, target_user_id, reason)
  VALUES (p_shift_id, p_requested_by_user_id, p_target_user_id, p_reason)
  RETURNING id INTO v_id;

  UPDATE public.engineer_shifts_r1732
     SET swap_requested = true,
         updated_at = now()
   WHERE id = p_shift_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'request_swap_r1732',
    jsonb_build_object(
      'swap_id', v_id,
      'shift_id', p_shift_id,
      'requested_by', p_requested_by_user_id,
      'target', p_target_user_id
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC: approve_swap
-- ============================================================================
CREATE OR REPLACE FUNCTION public.approve_swap_r1732(
  p_swap_id uuid,
  p_approve boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_shift_id uuid;
  v_target uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_shift_swaps_r1732
     SET approved = p_approve,
         decided_at = now(),
         decided_by_email = (auth.jwt()->>'email'),
         updated_at = now()
   WHERE id = p_swap_id
   RETURNING shift_id, target_user_id INTO v_shift_id, v_target;

  IF p_approve THEN
    UPDATE public.engineer_shifts_r1732
       SET swapped_with_user_id = v_target,
           swap_requested = false,
           updated_at = now()
     WHERE id = v_shift_id;
  ELSE
    UPDATE public.engineer_shifts_r1732
       SET swap_requested = false,
           updated_at = now()
     WHERE id = v_shift_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'approve_swap_r1732',
    jsonb_build_object(
      'swap_id', p_swap_id,
      'approved', p_approve
    )
  );
END;
$$;

-- ============================================================================
-- RPC: weekly_coverage_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.weekly_coverage_summary_r1732()
RETURNS TABLE (
  shift_date date,
  total_shifts int,
  day_shifts int,
  night_shifts int,
  on_call_shifts int,
  off_or_leave int,
  swap_pending int
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
    s.shift_date,
    COUNT(*)::int AS total_shifts,
    (COUNT(*) FILTER (WHERE s.shift_type = 'day'))::int AS day_shifts,
    (COUNT(*) FILTER (WHERE s.shift_type = 'night'))::int AS night_shifts,
    (COUNT(*) FILTER (WHERE s.shift_type = 'on_call'))::int AS on_call_shifts,
    (COUNT(*) FILTER (WHERE s.shift_type IN ('off_duty','leave')))::int AS off_or_leave,
    (COUNT(*) FILTER (WHERE s.swap_requested))::int AS swap_pending
  FROM public.engineer_shifts_r1732 s
  WHERE s.shift_date BETWEEN (now()::date - 1) AND (now()::date + 7)
  GROUP BY s.shift_date
  ORDER BY s.shift_date ASC;
END;
$$;

-- ============================================================================
-- RPC: locked_shifts
-- ============================================================================
CREATE OR REPLACE FUNCTION public.locked_shifts_r1732()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  shift_date date,
  shift_type text,
  shift_start time,
  shift_end time,
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
  SELECT
    s.id,
    s.engineer_user_id,
    p.email,
    s.shift_date,
    s.shift_type,
    s.shift_start,
    s.shift_end,
    s.notes,
    s.created_at
  FROM public.engineer_shifts_r1732 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.locked_by_founder = true
    AND s.shift_date >= (now()::date - 30)
  ORDER BY s.shift_date DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_shifts_r1732(date, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_shifts_r1732(date, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.schedule_shift_r1732(uuid, date, time, time, text, boolean, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.schedule_shift_r1732(uuid, date, time, time, text, boolean, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_swaps_r1732() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_swaps_r1732() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.request_swap_r1732(uuid, uuid, uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.request_swap_r1732(uuid, uuid, uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.approve_swap_r1732(uuid, boolean) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.approve_swap_r1732(uuid, boolean) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.weekly_coverage_summary_r1732() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.weekly_coverage_summary_r1732() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.locked_shifts_r1732() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.locked_shifts_r1732() TO authenticated;

COMMIT;