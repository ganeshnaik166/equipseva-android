BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_side_letter_bookkeeping_r2113 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  side_letter_label text NOT NULL,
  signed_date date,
  key_obligation_md text,
  obligation_type text CHECK (obligation_type IN ('info_rights','reporting','governance','financial','operational')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','superseded','amended')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_side_letter_action_log_r2113 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  letter_id uuid NOT NULL REFERENCES public.investor_side_letter_bookkeeping_r2113(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('signed','obligation_met','extended','superseded','disputed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_side_letter_bookkeeping_r2113 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_side_letter_action_log_r2113 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_bookkeeping_r2113 ON public.investor_side_letter_bookkeeping_r2113;
CREATE POLICY founder_all_bookkeeping_r2113 ON public.investor_side_letter_bookkeeping_r2113
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actionlog_r2113 ON public.investor_side_letter_action_log_r2113;
CREATE POLICY founder_all_actionlog_r2113 ON public.investor_side_letter_action_log_r2113
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_letters
CREATE OR REPLACE FUNCTION public.list_letters_r2113()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  side_letter_label text,
  signed_date date,
  key_obligation_md text,
  obligation_type text,
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
    SELECT l.id, l.investor_id, l.side_letter_label, l.signed_date,
           l.key_obligation_md, l.obligation_type, l.status, l.captured_at
    FROM public.investor_side_letter_bookkeeping_r2113 l
    ORDER BY l.captured_at DESC
    LIMIT 200;
END;
$$;

-- 2. log_letter
CREATE OR REPLACE FUNCTION public.log_letter_r2113(
  p_investor_id uuid,
  p_label text,
  p_signed_date date,
  p_obligation_md text,
  p_obligation_type text,
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
  INSERT INTO public.investor_side_letter_bookkeeping_r2113
    (investor_id, side_letter_label, signed_date, key_obligation_md, obligation_type, status)
  VALUES (p_investor_id, p_label, p_signed_date, p_obligation_md, p_obligation_type, COALESCE(p_status,'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_letter_r2113',
          jsonb_build_object('letter_id', v_id, 'label', p_label, 'status', p_status));
  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2113(p_letter_id uuid)
RETURNS TABLE (
  id uuid,
  letter_id uuid,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.letter_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_side_letter_action_log_r2113 a
    WHERE a.letter_id = p_letter_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_action_r2113(
  p_letter_id uuid,
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
  INSERT INTO public.investor_side_letter_action_log_r2113
    (letter_id, action_type, by_email, notes_md)
  VALUES (p_letter_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2113',
          jsonb_build_object('letter_id', p_letter_id, 'action', p_action_type));
  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2113(
  p_letter_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_side_letter_bookkeeping_r2113
     SET status = p_status, updated_at = now()
   WHERE id = p_letter_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2113',
          jsonb_build_object('letter_id', p_letter_id, 'status', p_status));
END;
$$;

-- 6. active_letters
CREATE OR REPLACE FUNCTION public.active_letters_r2113()
RETURNS TABLE (
  id uuid,
  side_letter_label text,
  obligation_type text,
  signed_date date,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.side_letter_label, l.obligation_type, l.signed_date, l.captured_at
    FROM public.investor_side_letter_bookkeeping_r2113 l
    WHERE l.status = 'active'
    ORDER BY l.signed_date DESC NULLS LAST
    LIMIT 200;
END;
$$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2113()
RETURNS TABLE (
  id uuid,
  letter_id uuid,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.letter_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_side_letter_action_log_r2113 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_letters_r2113() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_letter_r2113(uuid, text, date, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2113(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2113(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2113(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_letters_r2113() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2113() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_letters_r2113() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_letter_r2113(uuid, text, date, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2113(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2113(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2113(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_letters_r2113() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2113() TO authenticated;

COMMIT;
