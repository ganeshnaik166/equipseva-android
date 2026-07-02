BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_tool_inventory_r1904 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tool_name text NOT NULL,
  tool_category text NOT NULL CHECK (tool_category IN ('diagnostic','repair','consumable','measurement','safety')),
  condition text NOT NULL CHECK (condition IN ('new','good','fair','poor','needs_replacement')),
  last_used_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','lost','replaced','decommissioned')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_tool_lifecycle_log_r1904 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tool_id uuid NOT NULL REFERENCES public.engineer_tool_inventory_r1904(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('used','calibrated','replaced','lost','repaired')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_tool_inventory_r1904 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_tool_lifecycle_log_r1904 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_inventory_r1904 ON public.engineer_tool_inventory_r1904;
CREATE POLICY founder_all_inventory_r1904 ON public.engineer_tool_inventory_r1904
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_lifecycle_r1904 ON public.engineer_tool_lifecycle_log_r1904;
CREATE POLICY founder_all_lifecycle_r1904 ON public.engineer_tool_lifecycle_log_r1904
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_tool_inv_engineer_r1904 ON public.engineer_tool_inventory_r1904(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_tool_inv_status_r1904 ON public.engineer_tool_inventory_r1904(status);
CREATE INDEX IF NOT EXISTS idx_tool_inv_condition_r1904 ON public.engineer_tool_inventory_r1904(condition);
CREATE INDEX IF NOT EXISTS idx_tool_life_tool_r1904 ON public.engineer_tool_lifecycle_log_r1904(tool_id);
CREATE INDEX IF NOT EXISTS idx_tool_life_taken_r1904 ON public.engineer_tool_lifecycle_log_r1904(taken_at DESC);

-- RPC 1: list_tools
DROP FUNCTION IF EXISTS public.list_tools_r1904();
CREATE OR REPLACE FUNCTION public.list_tools_r1904()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  tool_name text,
  tool_category text,
  condition text,
  last_used_at timestamptz,
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
    SELECT t.id, t.engineer_user_id, p.email, t.tool_name, t.tool_category,
           t.condition, t.last_used_at, t.status, t.captured_at
    FROM public.engineer_tool_inventory_r1904 t
    LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
    ORDER BY t.captured_at DESC
    LIMIT 200;
END;
$$;

-- RPC 2: log_tool
DROP FUNCTION IF EXISTS public.log_tool_r1904(uuid, text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_tool_r1904(
  p_engineer uuid,
  p_name text,
  p_category text,
  p_condition text,
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
  INSERT INTO public.engineer_tool_inventory_r1904(
    engineer_user_id, tool_name, tool_category, condition, status
  ) VALUES (p_engineer, p_name, p_category, p_condition, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_tool_r1904',
          jsonb_build_object('tool_id', v_id, 'engineer', p_engineer, 'name', p_name));
  RETURN v_id;
END;
$$;

-- RPC 3: list_lifecycle
DROP FUNCTION IF EXISTS public.list_lifecycle_r1904(uuid);
CREATE OR REPLACE FUNCTION public.list_lifecycle_r1904(p_tool uuid)
RETURNS TABLE(
  id uuid,
  tool_id uuid,
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
    SELECT l.id, l.tool_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.engineer_tool_lifecycle_log_r1904 l
    WHERE l.tool_id = p_tool
    ORDER BY l.taken_at DESC
    LIMIT 100;
END;
$$;

-- RPC 4: log_lifecycle_action
DROP FUNCTION IF EXISTS public.log_lifecycle_action_r1904(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_lifecycle_action_r1904(
  p_tool uuid,
  p_action text,
  p_by_email text,
  p_notes text DEFAULT NULL
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
  INSERT INTO public.engineer_tool_lifecycle_log_r1904(tool_id, action_type, by_email, notes_md)
  VALUES (p_tool, p_action, p_by_email, p_notes)
  RETURNING id INTO v_id;

  UPDATE public.engineer_tool_inventory_r1904
  SET last_used_at = now(), updated_at = now()
  WHERE id = p_tool AND p_action = 'used';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_lifecycle_action_r1904',
          jsonb_build_object('tool', p_tool, 'action', p_action));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_replaced
DROP FUNCTION IF EXISTS public.mark_replaced_r1904(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_replaced_r1904(p_tool uuid, p_notes text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_tool_inventory_r1904
  SET status = 'replaced', condition = 'needs_replacement', updated_at = now()
  WHERE id = p_tool;

  INSERT INTO public.engineer_tool_lifecycle_log_r1904(tool_id, action_type, by_email, notes_md)
  VALUES (p_tool, 'replaced', (auth.jwt()->>'email'), p_notes);

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_replaced_r1904',
          jsonb_build_object('tool', p_tool));
END;
$$;

-- RPC 6: tools_needing_replacement
DROP FUNCTION IF EXISTS public.tools_needing_replacement_r1904();
CREATE OR REPLACE FUNCTION public.tools_needing_replacement_r1904()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  tool_name text,
  tool_category text,
  condition text,
  last_used_at timestamptz
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
    SELECT t.id, t.engineer_user_id, p.email, t.tool_name, t.tool_category,
           t.condition, t.last_used_at
    FROM public.engineer_tool_inventory_r1904 t
    LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
    WHERE t.condition IN ('poor','needs_replacement')
      AND t.status = 'active'
    ORDER BY t.captured_at DESC
    LIMIT 100;
END;
$$;

-- RPC 7: recent_lifecycle
DROP FUNCTION IF EXISTS public.recent_lifecycle_r1904();
CREATE OR REPLACE FUNCTION public.recent_lifecycle_r1904()
RETURNS TABLE(
  id uuid,
  tool_id uuid,
  tool_name text,
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
    SELECT l.id, l.tool_id, t.tool_name, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.engineer_tool_lifecycle_log_r1904 l
    LEFT JOIN public.engineer_tool_inventory_r1904 t ON t.id = l.tool_id
    ORDER BY l.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_tools_r1904() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tool_r1904(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_lifecycle_r1904(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_lifecycle_action_r1904(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_replaced_r1904(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.tools_needing_replacement_r1904() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_lifecycle_r1904() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tools_r1904() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tool_r1904(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_lifecycle_r1904(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_lifecycle_action_r1904(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_replaced_r1904(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tools_needing_replacement_r1904() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_lifecycle_r1904() TO authenticated;

COMMIT;
