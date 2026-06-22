BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_210_batch_pulse_memo_r2138 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_label text NOT NULL,
  written_at timestamptz NOT NULL DEFAULT now(),
  summary_md text NOT NULL DEFAULT '',
  key_themes_md text NOT NULL DEFAULT '',
  status_check_md text NOT NULL DEFAULT '',
  founder_pulse_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_pulse_signal_log_r2138 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id uuid NOT NULL REFERENCES public.founder_210_batch_pulse_memo_r2138(id) ON DELETE CASCADE,
  signal_type text NOT NULL CHECK (signal_type IN ('team_pulse','customer_pulse','investor_pulse','founder_pulse','external_observer')),
  signal_md text NOT NULL DEFAULT '',
  recorded_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_210_batch_pulse_memo_r2138 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_pulse_signal_log_r2138 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_memo_r2138 ON public.founder_210_batch_pulse_memo_r2138;
CREATE POLICY founder_all_memo_r2138 ON public.founder_210_batch_pulse_memo_r2138
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_signal_r2138 ON public.founder_pulse_signal_log_r2138;
CREATE POLICY founder_all_signal_r2138 ON public.founder_pulse_signal_log_r2138
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_memos_r2138()
RETURNS SETOF public.founder_210_batch_pulse_memo_r2138
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_210_batch_pulse_memo_r2138 ORDER BY written_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_memo_r2138(
  p_milestone_label text,
  p_summary_md text,
  p_key_themes_md text,
  p_status_check_md text,
  p_founder_pulse_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_210_batch_pulse_memo_r2138 (milestone_label, summary_md, key_themes_md, status_check_md, founder_pulse_md)
  VALUES (p_milestone_label, p_summary_md, p_key_themes_md, p_status_check_md, p_founder_pulse_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_memo_r2138', jsonb_build_object('memo_id', v_id, 'milestone_label', p_milestone_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_signals_r2138(p_memo_id uuid)
RETURNS SETOF public.founder_pulse_signal_log_r2138
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_pulse_signal_log_r2138 WHERE memo_id = p_memo_id ORDER BY recorded_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_signal_r2138(
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
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_pulse_signal_log_r2138 (memo_id, signal_type, signal_md, by_email)
  VALUES (p_memo_id, p_signal_type, p_signal_md, p_by_email)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_signal_r2138', jsonb_build_object('signal_id', v_id, 'memo_id', p_memo_id, 'signal_type', p_signal_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2138(p_memo_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_210_batch_pulse_memo_r2138 SET status = p_status, updated_at = now() WHERE id = p_memo_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2138', jsonb_build_object('memo_id', p_memo_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_signals_r2138(p_limit int DEFAULT 20)
RETURNS SETOF public.founder_pulse_signal_log_r2138
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_pulse_signal_log_r2138 ORDER BY recorded_at DESC LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_signals_r2138()
RETURNS TABLE(signal_type text, signal_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.signal_type, count(*)::bigint AS signal_count
  FROM public.founder_pulse_signal_log_r2138 s
  GROUP BY s.signal_type
  ORDER BY signal_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_memos_r2138() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_memo_r2138(text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_signals_r2138(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_signal_r2138(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2138(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_signals_r2138(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_signals_r2138() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_memos_r2138() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_memo_r2138(text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_signals_r2138(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_signal_r2138(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2138(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_signals_r2138(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_signals_r2138() TO authenticated;

COMMIT;
