BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_200_batch_anniversary_memo_r2098 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_label text NOT NULL,
  written_at timestamptz NOT NULL DEFAULT now(),
  anniversary_md text NOT NULL DEFAULT '',
  top_3_lessons_md text NOT NULL DEFAULT '',
  what_changed_about_founder_md text NOT NULL DEFAULT '',
  next_chapter_outlook_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_anniversary_signal_log_r2098 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id uuid NOT NULL REFERENCES public.founder_200_batch_anniversary_memo_r2098(id) ON DELETE CASCADE,
  signal_type text NOT NULL CHECK (signal_type IN ('team_celebration','investor_milestone','customer_celebration','founder_emotion','external_observer')),
  signal_md text NOT NULL DEFAULT '',
  recorded_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_200_batch_anniversary_memo_r2098 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_anniversary_signal_log_r2098 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_memo_r2098 ON public.founder_200_batch_anniversary_memo_r2098;
CREATE POLICY founder_all_memo_r2098 ON public.founder_200_batch_anniversary_memo_r2098
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_signal_r2098 ON public.founder_anniversary_signal_log_r2098;
CREATE POLICY founder_all_signal_r2098 ON public.founder_anniversary_signal_log_r2098
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_anniversary_memos_r2098()
RETURNS SETOF public.founder_200_batch_anniversary_memo_r2098
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_200_batch_anniversary_memo_r2098 ORDER BY written_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_anniversary_memo_r2098(
  p_milestone_label text,
  p_anniversary_md text,
  p_top_3_lessons_md text,
  p_what_changed_about_founder_md text,
  p_next_chapter_outlook_md text
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
  INSERT INTO public.founder_200_batch_anniversary_memo_r2098(
    milestone_label, anniversary_md, top_3_lessons_md, what_changed_about_founder_md, next_chapter_outlook_md
  ) VALUES (
    p_milestone_label, p_anniversary_md, p_top_3_lessons_md, p_what_changed_about_founder_md, p_next_chapter_outlook_md
  ) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_anniversary_memo_r2098', jsonb_build_object('id', v_id, 'milestone_label', p_milestone_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_anniversary_signals_r2098(p_memo_id uuid)
RETURNS SETOF public.founder_anniversary_signal_log_r2098
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_anniversary_signal_log_r2098 WHERE memo_id = p_memo_id ORDER BY recorded_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_anniversary_signal_r2098(
  p_memo_id uuid,
  p_signal_type text,
  p_signal_md text,
  p_by_email text
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
  INSERT INTO public.founder_anniversary_signal_log_r2098(memo_id, signal_type, signal_md, by_email)
    VALUES (p_memo_id, p_signal_type, p_signal_md, p_by_email) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_anniversary_signal_r2098', jsonb_build_object('id', v_id, 'memo_id', p_memo_id, 'signal_type', p_signal_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_anniversary_memo_status_r2098(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('published','archived') THEN RAISE EXCEPTION 'bad_status'; END IF;
  UPDATE public.founder_200_batch_anniversary_memo_r2098 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_anniversary_memo_status_r2098', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_anniversary_signals_r2098(p_limit int DEFAULT 25)
RETURNS SETOF public.founder_anniversary_signal_log_r2098
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_anniversary_signal_log_r2098 ORDER BY recorded_at DESC LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.top_anniversary_signals_r2098()
RETURNS TABLE(signal_type text, signal_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.signal_type, count(*)::bigint AS signal_count
    FROM public.founder_anniversary_signal_log_r2098 s
    GROUP BY s.signal_type
    ORDER BY signal_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_anniversary_memos_r2098() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_anniversary_memo_r2098(text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_anniversary_signals_r2098(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_anniversary_signal_r2098(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_anniversary_memo_status_r2098(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_anniversary_signals_r2098(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_anniversary_signals_r2098() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_anniversary_memos_r2098() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_anniversary_memo_r2098(text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_anniversary_signals_r2098(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_anniversary_signal_r2098(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_anniversary_memo_status_r2098(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_anniversary_signals_r2098(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_anniversary_signals_r2098() TO authenticated;

COMMIT;
