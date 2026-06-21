BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.founder_vision_boards_r1862 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL UNIQUE,
  where_in_5y_md text NOT NULL DEFAULT '',
  key_themes text[] NOT NULL DEFAULT '{}',
  non_negotiables_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','superseded')),
  locked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_vision_board_actions_r1862 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  board_id uuid NOT NULL REFERENCES public.founder_vision_boards_r1862(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fvb_actions_board_r1862 ON public.founder_vision_board_actions_r1862(board_id);
CREATE INDEX IF NOT EXISTS idx_fvb_actions_status_r1862 ON public.founder_vision_board_actions_r1862(status);

-- RLS
ALTER TABLE public.founder_vision_boards_r1862 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_vision_board_actions_r1862 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_boards_r1862 ON public.founder_vision_boards_r1862;
CREATE POLICY founder_all_boards_r1862 ON public.founder_vision_boards_r1862
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r1862 ON public.founder_vision_board_actions_r1862;
CREATE POLICY founder_all_actions_r1862 ON public.founder_vision_board_actions_r1862
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_boards
CREATE OR REPLACE FUNCTION public.list_vision_boards_r1862()
RETURNS TABLE(
  id uuid,
  quarter text,
  where_in_5y_md text,
  key_themes text[],
  non_negotiables_md text,
  status text,
  locked_at timestamptz,
  action_count int,
  open_count int,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.quarter, b.where_in_5y_md, b.key_themes, b.non_negotiables_md,
         b.status, b.locked_at,
         (COUNT(a.id))::int AS action_count,
         (COUNT(a.id) FILTER (WHERE a.status = 'open'))::int AS open_count,
         b.created_at
  FROM public.founder_vision_boards_r1862 b
  LEFT JOIN public.founder_vision_board_actions_r1862 a ON a.board_id = b.id
  GROUP BY b.id
  ORDER BY b.quarter DESC;
END;
$$;

-- 2. save_board
CREATE OR REPLACE FUNCTION public.save_vision_board_r1862(
  p_quarter text,
  p_where_in_5y_md text,
  p_key_themes text[],
  p_non_negotiables_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_vision_boards_r1862(quarter, where_in_5y_md, key_themes, non_negotiables_md)
  VALUES (p_quarter, COALESCE(p_where_in_5y_md,''), COALESCE(p_key_themes,'{}'), COALESCE(p_non_negotiables_md,''))
  ON CONFLICT (quarter) DO UPDATE
    SET where_in_5y_md = EXCLUDED.where_in_5y_md,
        key_themes = EXCLUDED.key_themes,
        non_negotiables_md = EXCLUDED.non_negotiables_md,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_vision_board_r1862',
    jsonb_build_object('board_id', v_id, 'quarter', p_quarter));

  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_vision_board_actions_r1862(p_board_id uuid)
RETURNS TABLE(
  id uuid,
  board_id uuid,
  action_text text,
  due_date date,
  status text,
  completed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.board_id, a.action_text, a.due_date, a.status, a.completed_at, a.created_at
  FROM public.founder_vision_board_actions_r1862 a
  WHERE a.board_id = p_board_id
  ORDER BY a.status ASC, a.due_date ASC NULLS LAST, a.created_at DESC;
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_vision_board_action_r1862(
  p_board_id uuid,
  p_action_text text,
  p_due_date date,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_status text;
  v_completed timestamptz;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_status := COALESCE(p_status, 'open');
  IF v_status NOT IN ('open','done','dropped') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  v_completed := CASE WHEN v_status = 'done' THEN now() ELSE NULL END;

  INSERT INTO public.founder_vision_board_actions_r1862(board_id, action_text, due_date, status, completed_at)
  VALUES (p_board_id, p_action_text, p_due_date, v_status, v_completed)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_vision_board_action_r1862',
    jsonb_build_object('action_id', v_id, 'board_id', p_board_id, 'status', v_status));

  RETURN v_id;
END;
$$;

-- 5. lock_board
CREATE OR REPLACE FUNCTION public.lock_vision_board_r1862(p_board_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  -- supersede any previous active
  UPDATE public.founder_vision_boards_r1862
  SET status = 'superseded', updated_at = now()
  WHERE status = 'active' AND id <> p_board_id;

  UPDATE public.founder_vision_boards_r1862
  SET status = 'active', locked_at = now(), updated_at = now()
  WHERE id = p_board_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'lock_vision_board_r1862',
    jsonb_build_object('board_id', p_board_id));

  RETURN p_board_id;
END;
$$;

-- 6. current_board
CREATE OR REPLACE FUNCTION public.current_vision_board_r1862()
RETURNS TABLE(
  id uuid,
  quarter text,
  where_in_5y_md text,
  key_themes text[],
  non_negotiables_md text,
  status text,
  locked_at timestamptz,
  open_actions int,
  done_actions int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.quarter, b.where_in_5y_md, b.key_themes, b.non_negotiables_md,
         b.status, b.locked_at,
         (COUNT(a.id) FILTER (WHERE a.status = 'open'))::int,
         (COUNT(a.id) FILTER (WHERE a.status = 'done'))::int
  FROM public.founder_vision_boards_r1862 b
  LEFT JOIN public.founder_vision_board_actions_r1862 a ON a.board_id = b.id
  WHERE b.status = 'active'
  GROUP BY b.id
  ORDER BY b.locked_at DESC NULLS LAST
  LIMIT 1;
END;
$$;

-- 7. theme_evolution
CREATE OR REPLACE FUNCTION public.vision_board_theme_evolution_r1862()
RETURNS TABLE(
  quarter text,
  status text,
  theme text,
  first_appearance boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH unnested AS (
    SELECT b.quarter, b.status, unnest(b.key_themes) AS theme
    FROM public.founder_vision_boards_r1862 b
  ),
  ranked AS (
    SELECT u.quarter, u.status, u.theme,
           ROW_NUMBER() OVER (PARTITION BY u.theme ORDER BY u.quarter ASC) = 1 AS first_appearance
    FROM unnested u
  )
  SELECT r.quarter, r.status, r.theme, r.first_appearance
  FROM ranked r
  ORDER BY r.quarter DESC, r.theme ASC;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_vision_boards_r1862() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.save_vision_board_r1862(text, text, text[], text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_vision_board_actions_r1862(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_vision_board_action_r1862(uuid, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.lock_vision_board_r1862(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_vision_board_r1862() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.vision_board_theme_evolution_r1862() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_vision_boards_r1862() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_vision_board_r1862(text, text, text[], text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_vision_board_actions_r1862(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_vision_board_action_r1862(uuid, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lock_vision_board_r1862(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_vision_board_r1862() TO authenticated;
GRANT EXECUTE ON FUNCTION public.vision_board_theme_evolution_r1862() TO authenticated;

COMMIT;