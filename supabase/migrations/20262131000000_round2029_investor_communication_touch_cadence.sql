BEGIN;

-- ============================================================
-- Round 2029 — Investor Communication Touch Cadence
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_communication_touch_cadence_r2029 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  current_cadence_days int NOT NULL DEFAULT 30,
  last_touched_at timestamptz,
  next_due_at timestamptz,
  status text NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','due','overdue','paused')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_touch_log_r2029 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cadence_id uuid NOT NULL REFERENCES public.investor_communication_touch_cadence_r2029(id) ON DELETE CASCADE,
  touch_type text NOT NULL CHECK (touch_type IN ('email','call','letter','in_person','video_update','event')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_communication_touch_cadence_r2029 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_touch_log_r2029 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cadence_r2029 ON public.investor_communication_touch_cadence_r2029;
CREATE POLICY founder_all_cadence_r2029 ON public.investor_communication_touch_cadence_r2029
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_touch_log_r2029 ON public.investor_touch_log_r2029;
CREATE POLICY founder_all_touch_log_r2029 ON public.investor_touch_log_r2029
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_cadences_r2029()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  current_cadence_days int,
  last_touched_at timestamptz,
  next_due_at timestamptz,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.investor_id, c.current_cadence_days, c.last_touched_at, c.next_due_at, c.status, c.captured_at
    FROM public.investor_communication_touch_cadence_r2029 c
    ORDER BY c.next_due_at NULLS LAST, c.captured_at DESC
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_cadence_r2029(
  p_investor_id uuid,
  p_current_cadence_days int,
  p_last_touched_at timestamptz,
  p_next_due_at timestamptz,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_communication_touch_cadence_r2029
    (investor_id, current_cadence_days, last_touched_at, next_due_at, status)
  VALUES
    (p_investor_id, COALESCE(p_current_cadence_days,30), p_last_touched_at, p_next_due_at, COALESCE(p_status,'on_track'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cadence_r2029',
    jsonb_build_object('cadence_id', v_id, 'investor_id', p_investor_id, 'status', p_status));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_touches_r2029(p_cadence_id uuid)
RETURNS TABLE (
  id uuid,
  cadence_id uuid,
  touch_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.cadence_id, t.touch_type, t.taken_at, t.by_email, t.outcome_md
    FROM public.investor_touch_log_r2029 t
    WHERE t.cadence_id = p_cadence_id
    ORDER BY t.taken_at DESC
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_touch_r2029(
  p_cadence_id uuid,
  p_touch_type text,
  p_taken_at timestamptz,
  p_by_email text,
  p_outcome_md text
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
  INSERT INTO public.investor_touch_log_r2029 (cadence_id, touch_type, taken_at, by_email, outcome_md)
  VALUES (p_cadence_id, p_touch_type, COALESCE(p_taken_at, now()), p_by_email, p_outcome_md)
  RETURNING id INTO v_id;

  UPDATE public.investor_communication_touch_cadence_r2029
  SET last_touched_at = COALESCE(p_taken_at, now()),
      next_due_at = COALESCE(p_taken_at, now()) + (current_cadence_days || ' days')::interval,
      status = 'on_track',
      updated_at = now()
  WHERE id = p_cadence_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_touch_r2029',
    jsonb_build_object('touch_id', v_id, 'cadence_id', p_cadence_id, 'touch_type', p_touch_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2029(p_cadence_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_communication_touch_cadence_r2029
  SET status = p_status, updated_at = now()
  WHERE id = p_cadence_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2029',
    jsonb_build_object('cadence_id', p_cadence_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.overdue_cadences_r2029()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  current_cadence_days int,
  last_touched_at timestamptz,
  next_due_at timestamptz,
  status text,
  days_overdue int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.investor_id, c.current_cadence_days, c.last_touched_at, c.next_due_at, c.status,
           GREATEST(0, EXTRACT(day FROM (now() - c.next_due_at))::int) AS days_overdue
    FROM public.investor_communication_touch_cadence_r2029 c
    WHERE c.status IN ('due','overdue')
       OR (c.next_due_at IS NOT NULL AND c.next_due_at < now())
    ORDER BY c.next_due_at NULLS LAST
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_touches_r2029()
RETURNS TABLE (
  id uuid,
  cadence_id uuid,
  touch_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.cadence_id, t.touch_type, t.taken_at, t.by_email, t.outcome_md
    FROM public.investor_touch_log_r2029 t
    ORDER BY t.taken_at DESC
    LIMIT 200;
END;
$$;

-- Permissions
REVOKE EXECUTE ON FUNCTION public.list_cadences_r2029() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cadence_r2029(uuid, int, timestamptz, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_touches_r2029(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_touch_r2029(uuid, text, timestamptz, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2029(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_cadences_r2029() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_touches_r2029() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_cadences_r2029() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cadence_r2029(uuid, int, timestamptz, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_touches_r2029(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_touch_r2029(uuid, text, timestamptz, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2029(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_cadences_r2029() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_touches_r2029() TO authenticated;

COMMIT;
