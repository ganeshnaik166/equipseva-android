BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_tool_lending_library_r2064 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tool_label text NOT NULL,
  tool_category text NOT NULL CHECK (tool_category IN ('diagnostic','specialized','measurement','safety','lifting')),
  total_inventory int NOT NULL DEFAULT 0,
  borrowed_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available','all_borrowed','maintenance','retired')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_tool_lending_action_log_r2064 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tool_id uuid NOT NULL REFERENCES public.engineer_tool_lending_library_r2064(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('borrowed','returned','lost','repaired','retired')),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_tool_lending_library_r2064 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_tool_lending_action_log_r2064 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_tool_lib_r2064 ON public.engineer_tool_lending_library_r2064;
CREATE POLICY founder_all_tool_lib_r2064 ON public.engineer_tool_lending_library_r2064
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_tool_log_r2064 ON public.engineer_tool_lending_action_log_r2064;
CREATE POLICY founder_all_tool_log_r2064 ON public.engineer_tool_lending_action_log_r2064
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_tools_r2064()
RETURNS SETOF public.engineer_tool_lending_library_r2064
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_tool_lending_library_r2064 ORDER BY captured_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_tool_r2064(
  p_tool_label text,
  p_tool_category text,
  p_total_inventory int,
  p_borrowed_count int,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_tool_lending_library_r2064(tool_label, tool_category, total_inventory, borrowed_count, status)
  VALUES (p_tool_label, p_tool_category, COALESCE(p_total_inventory, 0), COALESCE(p_borrowed_count, 0), COALESCE(p_status, 'available'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_tool_r2064', jsonb_build_object('tool_id', v_id, 'tool_label', p_tool_label));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2064()
RETURNS SETOF public.engineer_tool_lending_action_log_r2064
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_tool_lending_action_log_r2064 ORDER BY taken_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2064(
  p_tool_id uuid,
  p_action_type text,
  p_engineer_user_id uuid,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_tool_lending_action_log_r2064(tool_id, action_type, engineer_user_id, by_email, notes_md)
  VALUES (p_tool_id, p_action_type, p_engineer_user_id, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2064', jsonb_build_object('action_id', v_id, 'tool_id', p_tool_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2064(p_tool_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_tool_lending_library_r2064 SET status = p_status, updated_at = now() WHERE id = p_tool_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2064', jsonb_build_object('tool_id', p_tool_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.low_inventory_r2064()
RETURNS SETOF public.engineer_tool_lending_library_r2064
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_tool_lending_library_r2064
    WHERE status IN ('all_borrowed','maintenance') OR (total_inventory - borrowed_count) <= 1
    ORDER BY (total_inventory - borrowed_count) ASC NULLS LAST
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2064(p_limit int)
RETURNS SETOF public.engineer_tool_lending_action_log_r2064
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_tool_lending_action_log_r2064
    ORDER BY taken_at DESC LIMIT COALESCE(p_limit, 50);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_tools_r2064() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tool_r2064(text, text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2064() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2064(uuid, text, uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2064(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.low_inventory_r2064() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2064(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tools_r2064() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tool_r2064(text, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2064() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2064(uuid, text, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2064(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.low_inventory_r2064() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2064(int) TO authenticated;

COMMIT;
