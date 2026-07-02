BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_daily_reading_log_r2074 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_label text NOT NULL,
  item_type text NOT NULL CHECK (item_type IN ('book','article','podcast','newsletter','video')),
  source_url text,
  started_at timestamptz,
  completed_at timestamptz,
  takeaways_md text,
  status text NOT NULL DEFAULT 'reading' CHECK (status IN ('reading','completed','abandoned')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_reading_action_log_r2074 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.founder_daily_reading_log_r2074(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('started','recommended_to_team','applied_lesson','discarded','finished')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_daily_reading_log_r2074 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_reading_action_log_r2074 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reading_log_founder_r2074 ON public.founder_daily_reading_log_r2074;
CREATE POLICY reading_log_founder_r2074 ON public.founder_daily_reading_log_r2074
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS reading_action_founder_r2074 ON public.founder_reading_action_log_r2074;
CREATE POLICY reading_action_founder_r2074 ON public.founder_reading_action_log_r2074
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2074_list_items()
RETURNS SETOF public.founder_daily_reading_log_r2074
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_daily_reading_log_r2074 ORDER BY captured_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.r2074_log_item(
  p_label text, p_type text, p_url text, p_started timestamptz, p_takeaways text, p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_daily_reading_log_r2074(item_label, item_type, source_url, started_at, takeaways_md, status)
  VALUES (p_label, p_type, p_url, COALESCE(p_started, now()), p_takeaways, COALESCE(p_status,'reading'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2074_log_item', jsonb_build_object('id', v_id, 'label', p_label, 'type', p_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.r2074_list_actions()
RETURNS SETOF public.founder_reading_action_log_r2074
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_reading_action_log_r2074 ORDER BY taken_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.r2074_log_action(
  p_item uuid, p_action text, p_email text, p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_reading_action_log_r2074(item_id, action_type, by_email, notes_md)
  VALUES (p_item, p_action, p_email, p_notes)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2074_log_action', jsonb_build_object('id', v_id, 'item', p_item, 'action', p_action));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.r2074_mark_status(p_item uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_daily_reading_log_r2074
     SET status = p_status,
         completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
         updated_at = now()
   WHERE id = p_item;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2074_mark_status', jsonb_build_object('id', p_item, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.r2074_by_type()
RETURNS TABLE(item_type text, total bigint, completed bigint, abandoned bigint, reading bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.item_type,
         count(*)::bigint,
         count(*) FILTER (WHERE r.status = 'completed')::bigint,
         count(*) FILTER (WHERE r.status = 'abandoned')::bigint,
         count(*) FILTER (WHERE r.status = 'reading')::bigint
  FROM public.founder_daily_reading_log_r2074 r
  GROUP BY r.item_type
  ORDER BY count(*) DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2074_recent_actions(p_limit int)
RETURNS SETOF public.founder_reading_action_log_r2074
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_reading_action_log_r2074 ORDER BY taken_at DESC LIMIT COALESCE(p_limit, 50);
END $$;

REVOKE EXECUTE ON FUNCTION public.r2074_list_items() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2074_log_item(text, text, text, timestamptz, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2074_list_actions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2074_log_action(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2074_mark_status(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2074_by_type() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2074_recent_actions(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2074_list_items() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2074_log_item(text, text, text, timestamptz, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2074_list_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2074_log_action(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2074_mark_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2074_by_type() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2074_recent_actions(int) TO authenticated;

COMMIT;
