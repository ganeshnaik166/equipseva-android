BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_industry_watchlist_r2042 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  watch_label text NOT NULL,
  watch_type text NOT NULL CHECK (watch_type IN ('competitor','regulatory','technology','market','customer','financial')),
  importance text NOT NULL CHECK (importance IN ('critical','high','medium','low')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','watching','concerning','addressed','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_watch_action_log_r2042 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  watch_id uuid NOT NULL REFERENCES public.founder_industry_watchlist_r2042(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('observed','responded','escalated','addressed','closed','no_action')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_industry_watchlist_r2042 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_watch_action_log_r2042 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_watchlist_r2042 ON public.founder_industry_watchlist_r2042;
CREATE POLICY founder_all_watchlist_r2042 ON public.founder_industry_watchlist_r2042
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actionlog_r2042 ON public.founder_watch_action_log_r2042;
CREATE POLICY founder_all_actionlog_r2042 ON public.founder_watch_action_log_r2042
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_watches_r2042()
RETURNS SETOF public.founder_industry_watchlist_r2042
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_industry_watchlist_r2042 ORDER BY
    CASE importance WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    captured_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_watch_r2042(
  p_label text, p_type text, p_importance text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_industry_watchlist_r2042(watch_label, watch_type, importance)
    VALUES (p_label, p_type, p_importance) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_watch_r2042',
            jsonb_build_object('id', v_id, 'label', p_label, 'type', p_type, 'importance', p_importance));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2042(p_watch_id uuid)
RETURNS SETOF public.founder_watch_action_log_r2042
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_watch_action_log_r2042
    WHERE watch_id = p_watch_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2042(
  p_watch_id uuid, p_action_type text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_watch_action_log_r2042(watch_id, action_type, by_email, notes_md)
    VALUES (p_watch_id, p_action_type, (auth.jwt()->>'email'), p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2042',
            jsonb_build_object('id', v_id, 'watch_id', p_watch_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2042(
  p_watch_id uuid, p_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_industry_watchlist_r2042 SET status = p_status, updated_at = now()
    WHERE id = p_watch_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2042',
            jsonb_build_object('watch_id', p_watch_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.critical_watches_r2042()
RETURNS SETOF public.founder_industry_watchlist_r2042
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_industry_watchlist_r2042
    WHERE importance IN ('critical','high') AND status IN ('active','watching','concerning')
    ORDER BY captured_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2042(p_limit int DEFAULT 50)
RETURNS SETOF public.founder_watch_action_log_r2042
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_watch_action_log_r2042
    ORDER BY taken_at DESC LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_watches_r2042() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_watch_r2042(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2042(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2042(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2042(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_watches_r2042() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2042(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_watches_r2042() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_watch_r2042(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2042(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2042(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2042(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_watches_r2042() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2042(int) TO authenticated;

COMMIT;
