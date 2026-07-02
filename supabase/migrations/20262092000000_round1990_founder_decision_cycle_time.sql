BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_decision_cycle_time_r1990 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_label text NOT NULL,
  decision_type text NOT NULL CHECK (decision_type IN ('hire','fire','strategic','financial','product','partnership')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  cycle_time_hours int,
  status text NOT NULL DEFAULT 'opened' CHECK (status IN ('opened','decided','deferred','abandoned')),
  urgency text NOT NULL DEFAULT 'medium' CHECK (urgency IN ('low','medium','high','critical')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_decision_phase_log_r1990 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.founder_decision_cycle_time_r1990(id) ON DELETE CASCADE,
  phase text NOT NULL CHECK (phase IN ('identified','data_gathering','options_discussed','committed','communicated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_decision_cycle_time_r1990 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_decision_phase_log_r1990 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_dct_r1990_founder ON public.founder_decision_cycle_time_r1990;
CREATE POLICY p_dct_r1990_founder ON public.founder_decision_cycle_time_r1990
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_dpl_r1990_founder ON public.founder_decision_phase_log_r1990;
CREATE POLICY p_dpl_r1990_founder ON public.founder_decision_phase_log_r1990
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_decisions_r1990()
RETURNS TABLE (
  id uuid,
  decision_label text,
  decision_type text,
  opened_at timestamptz,
  decided_at timestamptz,
  cycle_time_hours int,
  status text,
  urgency text
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
    SELECT d.id, d.decision_label, d.decision_type, d.opened_at, d.decided_at, d.cycle_time_hours, d.status, d.urgency
    FROM public.founder_decision_cycle_time_r1990 d
    ORDER BY d.opened_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_decision_r1990(
  p_label text,
  p_type text,
  p_urgency text
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
  INSERT INTO public.founder_decision_cycle_time_r1990 (decision_label, decision_type, urgency)
  VALUES (p_label, p_type, COALESCE(p_urgency, 'medium'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_decision_r1990',
    jsonb_build_object('id', v_id, 'label', p_label, 'type', p_type, 'urgency', p_urgency));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_phases_r1990(p_decision uuid)
RETURNS TABLE (
  id uuid,
  decision_id uuid,
  phase text,
  taken_at timestamptz,
  by_email text,
  notes_md text
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
    SELECT p.id, p.decision_id, p.phase, p.taken_at, p.by_email, p.notes_md
    FROM public.founder_decision_phase_log_r1990 p
    WHERE p.decision_id = p_decision
    ORDER BY p.taken_at ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_phase_r1990(
  p_decision uuid,
  p_phase text,
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
  INSERT INTO public.founder_decision_phase_log_r1990 (decision_id, phase, by_email, notes_md)
  VALUES (p_decision, p_phase, (auth.jwt()->>'email'), p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_phase_r1990',
    jsonb_build_object('phase_id', v_id, 'decision_id', p_decision, 'phase', p_phase));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1990(
  p_decision uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_opened timestamptz;
  v_hours int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT opened_at INTO v_opened FROM public.founder_decision_cycle_time_r1990 WHERE id = p_decision;
  IF p_status = 'decided' THEN
    v_hours := GREATEST(0, EXTRACT(EPOCH FROM (now() - v_opened))/3600)::int;
    UPDATE public.founder_decision_cycle_time_r1990
      SET status = p_status, decided_at = now(), cycle_time_hours = v_hours, updated_at = now()
      WHERE id = p_decision;
  ELSE
    UPDATE public.founder_decision_cycle_time_r1990
      SET status = p_status, updated_at = now()
      WHERE id = p_decision;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1990',
    jsonb_build_object('id', p_decision, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.fast_decisions_r1990()
RETURNS TABLE (
  id uuid,
  decision_label text,
  decision_type text,
  cycle_time_hours int,
  urgency text
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
    SELECT d.id, d.decision_label, d.decision_type, d.cycle_time_hours, d.urgency
    FROM public.founder_decision_cycle_time_r1990 d
    WHERE d.status = 'decided' AND d.cycle_time_hours IS NOT NULL
    ORDER BY d.cycle_time_hours ASC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_phases_r1990()
RETURNS TABLE (
  id uuid,
  decision_id uuid,
  decision_label text,
  phase text,
  taken_at timestamptz,
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
    SELECT p.id, p.decision_id, d.decision_label, p.phase, p.taken_at, p.by_email
    FROM public.founder_decision_phase_log_r1990 p
    JOIN public.founder_decision_cycle_time_r1990 d ON d.id = p.decision_id
    ORDER BY p.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_decisions_r1990() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_decision_r1990(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_phases_r1990(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_phase_r1990(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1990(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fast_decisions_r1990() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_phases_r1990() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_decisions_r1990() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_decision_r1990(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_phases_r1990(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_phase_r1990(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1990(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fast_decisions_r1990() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_phases_r1990() TO authenticated;

COMMIT;
