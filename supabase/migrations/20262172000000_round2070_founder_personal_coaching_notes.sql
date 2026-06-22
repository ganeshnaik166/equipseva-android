BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_personal_coaching_notes_r2070 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_name text NOT NULL,
  session_date date NOT NULL,
  key_themes_md text,
  breakthrough_md text,
  action_items_md text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed','archived')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_coaching_followup_log_r2070 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES public.founder_personal_coaching_notes_r2070(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('action_taken','blocker_hit','breakthrough','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_personal_coaching_notes_r2070 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_coaching_followup_log_r2070 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_notes_r2070 ON public.founder_personal_coaching_notes_r2070;
CREATE POLICY founder_all_notes_r2070 ON public.founder_personal_coaching_notes_r2070
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_followup_r2070 ON public.founder_coaching_followup_log_r2070;
CREATE POLICY founder_all_followup_r2070 ON public.founder_coaching_followup_log_r2070
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_coaching_notes_r2070()
RETURNS TABLE (
  id uuid,
  coach_name text,
  session_date date,
  key_themes_md text,
  breakthrough_md text,
  action_items_md text,
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
    SELECT n.id, n.coach_name, n.session_date, n.key_themes_md, n.breakthrough_md,
           n.action_items_md, n.status, n.captured_at
      FROM public.founder_personal_coaching_notes_r2070 n
     ORDER BY n.session_date DESC, n.captured_at DESC
     LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_coaching_note_r2070(
  p_coach_name text,
  p_session_date date,
  p_key_themes_md text,
  p_breakthrough_md text,
  p_action_items_md text,
  p_status text DEFAULT 'active'
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
  INSERT INTO public.founder_personal_coaching_notes_r2070(
    coach_name, session_date, key_themes_md, breakthrough_md, action_items_md, status
  ) VALUES (
    p_coach_name, p_session_date, p_key_themes_md, p_breakthrough_md, p_action_items_md, COALESCE(p_status,'active')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_coaching_note_r2070',
          jsonb_build_object('id', v_id, 'coach_name', p_coach_name, 'session_date', p_session_date, 'status', p_status));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_coaching_followups_r2070(p_note_id uuid)
RETURNS TABLE (
  id uuid,
  note_id uuid,
  action_type text,
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
    SELECT f.id, f.note_id, f.action_type, f.taken_at, f.by_email, f.notes_md
      FROM public.founder_coaching_followup_log_r2070 f
     WHERE f.note_id = p_note_id
     ORDER BY f.taken_at DESC
     LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_coaching_followup_r2070(
  p_note_id uuid,
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
  INSERT INTO public.founder_coaching_followup_log_r2070(note_id, action_type, by_email, notes_md)
  VALUES (p_note_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_coaching_followup_r2070',
          jsonb_build_object('id', v_id, 'note_id', p_note_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_coaching_status_r2070(
  p_note_id uuid,
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
  IF p_status NOT IN ('active','closed','archived') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.founder_personal_coaching_notes_r2070
     SET status = p_status, updated_at = now()
   WHERE id = p_note_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_coaching_status_r2070',
          jsonb_build_object('id', p_note_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_coaching_notes_r2070(p_limit int DEFAULT 25)
RETURNS TABLE (
  id uuid,
  coach_name text,
  session_date date,
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
    SELECT n.id, n.coach_name, n.session_date, n.status, n.captured_at
      FROM public.founder_personal_coaching_notes_r2070 n
     ORDER BY n.captured_at DESC
     LIMIT GREATEST(1, COALESCE(p_limit, 25));
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_coaching_followups_r2070(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  note_id uuid,
  action_type text,
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
    SELECT f.id, f.note_id, f.action_type, f.taken_at, f.by_email
      FROM public.founder_coaching_followup_log_r2070 f
     ORDER BY f.taken_at DESC
     LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_coaching_notes_r2070() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_coaching_note_r2070(text, date, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_coaching_followups_r2070(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_coaching_followup_r2070(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_coaching_status_r2070(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_coaching_notes_r2070(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_coaching_followups_r2070(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_coaching_notes_r2070() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_coaching_note_r2070(text, date, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_coaching_followups_r2070(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_coaching_followup_r2070(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_coaching_status_r2070(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_coaching_notes_r2070(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_coaching_followups_r2070(int) TO authenticated;

COMMIT;
