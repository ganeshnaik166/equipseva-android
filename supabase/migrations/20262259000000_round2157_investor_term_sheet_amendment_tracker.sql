BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_term_sheet_amendment_tracker_r2157 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  original_ts_label text NOT NULL,
  amendment_label text NOT NULL,
  amendment_md text NOT NULL DEFAULT '',
  signed_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','disputed','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_amendment_action_log_r2157 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amendment_id uuid NOT NULL REFERENCES public.investor_term_sheet_amendment_tracker_r2157(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('signed','superseded','disputed','closed','clarified')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL DEFAULT '',
  notes_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_term_sheet_amendment_tracker_r2157 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_amendment_action_log_r2157 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ts_amend_r2157 ON public.investor_term_sheet_amendment_tracker_r2157;
CREATE POLICY founder_all_ts_amend_r2157 ON public.investor_term_sheet_amendment_tracker_r2157
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2157 ON public.investor_amendment_action_log_r2157;
CREATE POLICY founder_all_action_r2157 ON public.investor_amendment_action_log_r2157
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_amendments_r2157()
RETURNS TABLE (id uuid, original_ts_label text, amendment_label text, amendment_md text, signed_at timestamptz, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.original_ts_label, a.amendment_label, a.amendment_md, a.signed_at, a.status, a.captured_at
    FROM public.investor_term_sheet_amendment_tracker_r2157 a
    ORDER BY a.captured_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.log_amendment_r2157(
  p_original_ts_label text, p_amendment_label text, p_amendment_md text, p_signed_at timestamptz, p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_term_sheet_amendment_tracker_r2157(original_ts_label, amendment_label, amendment_md, signed_at, status)
    VALUES (p_original_ts_label, p_amendment_label, COALESCE(p_amendment_md,''), p_signed_at, COALESCE(p_status,'active'))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_amendment_r2157',
      jsonb_build_object('id', v_id, 'original_ts_label', p_original_ts_label, 'amendment_label', p_amendment_label, 'status', p_status));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2157(p_amendment_id uuid)
RETURNS TABLE (id uuid, amendment_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.amendment_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.investor_amendment_action_log_r2157 l
    WHERE l.amendment_id = p_amendment_id
    ORDER BY l.taken_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2157(
  p_amendment_id uuid, p_action_type text, p_by_email text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_amendment_action_log_r2157(amendment_id, action_type, by_email, notes_md)
    VALUES (p_amendment_id, p_action_type, COALESCE(p_by_email,''), COALESCE(p_notes_md,''))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2157',
      jsonb_build_object('id', v_id, 'amendment_id', p_amendment_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2157(p_amendment_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_term_sheet_amendment_tracker_r2157
    SET status = p_status, updated_at = now()
    WHERE id = p_amendment_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2157',
      jsonb_build_object('id', p_amendment_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.recent_amendments_r2157(p_limit int)
RETURNS TABLE (id uuid, original_ts_label text, amendment_label text, status text, signed_at timestamptz, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.original_ts_label, a.amendment_label, a.status, a.signed_at, a.captured_at
    FROM public.investor_term_sheet_amendment_tracker_r2157 a
    ORDER BY a.captured_at DESC
    LIMIT COALESCE(p_limit, 20);
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2157(p_limit int)
RETURNS TABLE (id uuid, amendment_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.amendment_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.investor_amendment_action_log_r2157 l
    ORDER BY l.taken_at DESC
    LIMIT COALESCE(p_limit, 20);
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_amendments_r2157() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_amendment_r2157(text, text, text, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2157(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2157(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2157(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_amendments_r2157(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2157(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_amendments_r2157() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_amendment_r2157(text, text, text, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2157(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2157(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2157(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_amendments_r2157(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2157(int) TO authenticated;

COMMIT;