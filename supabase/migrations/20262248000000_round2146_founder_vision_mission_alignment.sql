BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_vision_mission_alignment_r2146 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_label text NOT NULL,
  decision_md text,
  vision_alignment_score int NOT NULL CHECK (vision_alignment_score >= 0 AND vision_alignment_score <= 100),
  mission_alignment_score int NOT NULL CHECK (mission_alignment_score >= 0 AND mission_alignment_score <= 100),
  status text NOT NULL CHECK (status IN ('aligned','misaligned','partial','reviewed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_alignment_action_log_r2146 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.founder_vision_mission_alignment_r2146(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('approved','rejected','escalated','refined','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_vision_mission_alignment_r2146 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_alignment_action_log_r2146 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_only_vma_r2146 ON public.founder_vision_mission_alignment_r2146;
CREATE POLICY p_founder_only_vma_r2146 ON public.founder_vision_mission_alignment_r2146
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_only_aal_r2146 ON public.founder_alignment_action_log_r2146;
CREATE POLICY p_founder_only_aal_r2146 ON public.founder_alignment_action_log_r2146
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2146_list_decisions()
RETURNS TABLE(id uuid, decision_label text, vision_alignment_score int, mission_alignment_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT d.id, d.decision_label, d.vision_alignment_score, d.mission_alignment_score, d.status, d.captured_at
    FROM public.founder_vision_mission_alignment_r2146 d
    ORDER BY d.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2146_log_decision(p_label text, p_md text, p_vision int, p_mission int, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_vision_mission_alignment_r2146(decision_label, decision_md, vision_alignment_score, mission_alignment_score, status)
    VALUES (p_label, p_md, p_vision, p_mission, p_status)
    RETURNING id INTO new_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2146_log_decision', jsonb_build_object('id', new_id, 'label', p_label, 'status', p_status));
  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2146_list_actions(p_decision_id uuid)
RETURNS TABLE(id uuid, decision_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.decision_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_alignment_action_log_r2146 a
    WHERE a.decision_id = p_decision_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2146_log_action(p_decision_id uuid, p_action_type text, p_by_email text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_alignment_action_log_r2146(decision_id, action_type, by_email, notes_md)
    VALUES (p_decision_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO new_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2146_log_action', jsonb_build_object('id', new_id, 'decision_id', p_decision_id, 'action_type', p_action_type));
  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2146_mark_status(p_decision_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_vision_mission_alignment_r2146 SET status = p_status, updated_at = now() WHERE id = p_decision_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2146_mark_status', jsonb_build_object('id', p_decision_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.r2146_misaligned()
RETURNS TABLE(id uuid, decision_label text, vision_alignment_score int, mission_alignment_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT d.id, d.decision_label, d.vision_alignment_score, d.mission_alignment_score, d.status, d.captured_at
    FROM public.founder_vision_mission_alignment_r2146 d
    WHERE d.status = 'misaligned' OR d.vision_alignment_score < 50 OR d.mission_alignment_score < 50
    ORDER BY d.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2146_recent_actions()
RETURNS TABLE(id uuid, decision_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.decision_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_alignment_action_log_r2146 a
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2146_list_decisions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2146_log_decision(text, text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2146_list_actions(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2146_log_action(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2146_mark_status(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2146_misaligned() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2146_recent_actions() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2146_list_decisions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2146_log_decision(text, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2146_list_actions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2146_log_action(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2146_mark_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2146_misaligned() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2146_recent_actions() TO authenticated;

COMMIT;
