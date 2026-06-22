BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_crisis_drill_log_r2142 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drill_label text NOT NULL,
  drill_type text NOT NULL CHECK (drill_type IN ('ransomware','data_breach','key_employee_loss','legal_action','customer_revolt','regulatory_action')),
  drill_date date NOT NULL DEFAULT CURRENT_DATE,
  lessons_md text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','completed','cancelled','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_drill_action_log_r2142 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drill_id uuid NOT NULL REFERENCES public.founder_crisis_drill_log_r2142(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('planned','conducted','lesson_documented','improvement_planned','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_crisis_drill_log_r2142 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_drill_action_log_r2142 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_drills_r2142 ON public.founder_crisis_drill_log_r2142;
CREATE POLICY founder_all_drills_r2142 ON public.founder_crisis_drill_log_r2142
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_drill_actions_r2142 ON public.founder_drill_action_log_r2142;
CREATE POLICY founder_all_drill_actions_r2142 ON public.founder_drill_action_log_r2142
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_drills_r2142_date ON public.founder_crisis_drill_log_r2142(drill_date DESC);
CREATE INDEX IF NOT EXISTS idx_drill_actions_r2142_drill ON public.founder_drill_action_log_r2142(drill_id, taken_at DESC);

-- list_drills
CREATE OR REPLACE FUNCTION public.list_drills_r2142()
RETURNS TABLE (id uuid, drill_label text, drill_type text, drill_date date, lessons_md text, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.drill_label, d.drill_type, d.drill_date, d.lessons_md, d.status, d.captured_at
    FROM public.founder_crisis_drill_log_r2142 d
    ORDER BY d.drill_date DESC, d.captured_at DESC
    LIMIT 200;
END $$;

-- log_drill
CREATE OR REPLACE FUNCTION public.log_drill_r2142(p_drill_label text, p_drill_type text, p_drill_date date, p_lessons_md text, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_crisis_drill_log_r2142(drill_label, drill_type, drill_date, lessons_md, status)
    VALUES (p_drill_label, p_drill_type, COALESCE(p_drill_date, CURRENT_DATE), p_lessons_md, COALESCE(p_status,'planned'))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_drill_r2142',
            jsonb_build_object('id', v_id, 'drill_label', p_drill_label, 'drill_type', p_drill_type, 'status', COALESCE(p_status,'planned')));
  RETURN v_id;
END $$;

-- list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2142(p_drill_id uuid)
RETURNS TABLE (id uuid, drill_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.drill_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_drill_action_log_r2142 a
    WHERE a.drill_id = p_drill_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END $$;

-- log_action
CREATE OR REPLACE FUNCTION public.log_action_r2142(p_drill_id uuid, p_action_type text, p_by_email text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_drill_action_log_r2142(drill_id, action_type, by_email, notes_md)
    VALUES (p_drill_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2142',
            jsonb_build_object('id', v_id, 'drill_id', p_drill_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

-- mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2142(p_drill_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_crisis_drill_log_r2142
    SET status = p_status, updated_at = now()
    WHERE id = p_drill_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2142',
            jsonb_build_object('drill_id', p_drill_id, 'status', p_status));
END $$;

-- recent_drills
CREATE OR REPLACE FUNCTION public.recent_drills_r2142(p_limit integer)
RETURNS TABLE (id uuid, drill_label text, drill_type text, drill_date date, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.drill_label, d.drill_type, d.drill_date, d.status, d.captured_at
    FROM public.founder_crisis_drill_log_r2142 d
    ORDER BY d.captured_at DESC
    LIMIT COALESCE(p_limit, 20);
END $$;

-- recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2142(p_limit integer)
RETURNS TABLE (id uuid, drill_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.drill_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_drill_action_log_r2142 a
    ORDER BY a.taken_at DESC
    LIMIT COALESCE(p_limit, 20);
END $$;

REVOKE EXECUTE ON FUNCTION public.list_drills_r2142() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_drill_r2142(text, text, date, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2142(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2142(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2142(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_drills_r2142(integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2142(integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_drills_r2142() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_drill_r2142(text, text, date, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2142(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2142(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2142(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_drills_r2142(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2142(integer) TO authenticated;

COMMIT;
