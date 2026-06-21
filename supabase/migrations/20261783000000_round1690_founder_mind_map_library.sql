BEGIN;

-- ============================================================================
-- Round 1690 — Founder Mind Map Library
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_mind_maps_r1690 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  summary_md text,
  last_edited_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')),
  created_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fmm_r1690_status ON public.founder_mind_maps_r1690(status);
CREATE INDEX IF NOT EXISTS idx_fmm_r1690_last_edited ON public.founder_mind_maps_r1690(last_edited_at DESC);

CREATE TABLE IF NOT EXISTS public.founder_mind_map_nodes_r1690 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  map_id uuid NOT NULL REFERENCES public.founder_mind_maps_r1690(id) ON DELETE CASCADE,
  parent_node_id uuid REFERENCES public.founder_mind_map_nodes_r1690(id) ON DELETE CASCADE,
  node_text text NOT NULL,
  weight int NOT NULL DEFAULT 1,
  created_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fmmn_r1690_map ON public.founder_mind_map_nodes_r1690(map_id);
CREATE INDEX IF NOT EXISTS idx_fmmn_r1690_parent ON public.founder_mind_map_nodes_r1690(parent_node_id);

ALTER TABLE public.founder_mind_maps_r1690 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_mind_map_nodes_r1690 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fmm_r1690_founder_all ON public.founder_mind_maps_r1690;
CREATE POLICY fmm_r1690_founder_all ON public.founder_mind_maps_r1690
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fmmn_r1690_founder_all ON public.founder_mind_map_nodes_r1690;
CREATE POLICY fmmn_r1690_founder_all ON public.founder_mind_map_nodes_r1690
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_maps
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_mind_maps_r1690(p_status text DEFAULT 'active')
RETURNS TABLE (
  id uuid,
  title text,
  summary_md text,
  last_edited_at timestamptz,
  status text,
  node_count int,
  created_at timestamptz
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
  SELECT
    m.id,
    m.title,
    m.summary_md,
    m.last_edited_at,
    m.status,
    (SELECT (COUNT(*))::int FROM public.founder_mind_map_nodes_r1690 n WHERE n.map_id = m.id) AS node_count,
    m.created_at
  FROM public.founder_mind_maps_r1690 m
  WHERE (p_status IS NULL OR m.status = p_status)
  ORDER BY m.last_edited_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: create_map
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_mind_map_r1690(p_title text, p_summary_md text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.founder_mind_maps_r1690 (title, summary_md, created_by_email)
  VALUES (p_title, p_summary_md, v_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'create_mind_map_r1690',
    jsonb_build_object('map_id', v_id, 'title', p_title));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_nodes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_mind_map_nodes_r1690(p_map_id uuid)
RETURNS TABLE (
  id uuid,
  parent_node_id uuid,
  node_text text,
  weight int,
  created_by_email text,
  created_at timestamptz
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
  SELECT n.id, n.parent_node_id, n.node_text, n.weight, n.created_by_email, n.created_at
  FROM public.founder_mind_map_nodes_r1690 n
  WHERE n.map_id = p_map_id
  ORDER BY n.created_at ASC
  LIMIT 1000;
END;
$$;

-- ============================================================================
-- RPC 4: add_node
-- ============================================================================
CREATE OR REPLACE FUNCTION public.add_mind_map_node_r1690(
  p_map_id uuid,
  p_node_text text,
  p_parent_node_id uuid DEFAULT NULL,
  p_weight int DEFAULT 1
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.founder_mind_map_nodes_r1690 (map_id, parent_node_id, node_text, weight, created_by_email)
  VALUES (p_map_id, p_parent_node_id, p_node_text, COALESCE(p_weight, 1), v_email)
  RETURNING id INTO v_id;

  UPDATE public.founder_mind_maps_r1690 SET last_edited_at = now(), updated_at = now() WHERE id = p_map_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'add_mind_map_node_r1690',
    jsonb_build_object('map_id', p_map_id, 'node_id', v_id, 'text', p_node_text));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: update_node
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_mind_map_node_r1690(
  p_node_id uuid,
  p_node_text text DEFAULT NULL,
  p_weight int DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
  v_map_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  UPDATE public.founder_mind_map_nodes_r1690
  SET node_text = COALESCE(p_node_text, node_text),
      weight = COALESCE(p_weight, weight),
      updated_at = now()
  WHERE id = p_node_id
  RETURNING map_id INTO v_map_id;

  IF v_map_id IS NOT NULL THEN
    UPDATE public.founder_mind_maps_r1690 SET last_edited_at = now(), updated_at = now() WHERE id = v_map_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'update_mind_map_node_r1690',
    jsonb_build_object('node_id', p_node_id, 'text', p_node_text, 'weight', p_weight));

  RETURN TRUE;
END;
$$;

-- ============================================================================
-- RPC 6: archive_map
-- ============================================================================
CREATE OR REPLACE FUNCTION public.archive_mind_map_r1690(p_map_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  UPDATE public.founder_mind_maps_r1690
  SET status = 'archived', updated_at = now()
  WHERE id = p_map_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'archive_mind_map_r1690',
    jsonb_build_object('map_id', p_map_id));

  RETURN TRUE;
END;
$$;

-- ============================================================================
-- RPC 7: map_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mind_map_summary_r1690()
RETURNS TABLE (
  total_maps int,
  active_maps int,
  archived_maps int,
  total_nodes int,
  avg_nodes_per_active numeric,
  stale_active_maps int
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
  SELECT
    (SELECT (COUNT(*))::int FROM public.founder_mind_maps_r1690) AS total_maps,
    (SELECT (COUNT(*))::int FROM public.founder_mind_maps_r1690 WHERE status = 'active') AS active_maps,
    (SELECT (COUNT(*))::int FROM public.founder_mind_maps_r1690 WHERE status = 'archived') AS archived_maps,
    (SELECT (COUNT(*))::int FROM public.founder_mind_map_nodes_r1690) AS total_nodes,
    COALESCE((
      SELECT ROUND(AVG(nc)::numeric, 2) FROM (
        SELECT (SELECT (COUNT(*))::int FROM public.founder_mind_map_nodes_r1690 n WHERE n.map_id = m.id) AS nc
        FROM public.founder_mind_maps_r1690 m WHERE m.status = 'active'
      ) s
    ), 0) AS avg_nodes_per_active,
    (SELECT (COUNT(*))::int FROM public.founder_mind_maps_r1690 WHERE status = 'active' AND last_edited_at < now() - interval '14 days') AS stale_active_maps;
END;
$$;

-- ============================================================================
-- Permissions
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_mind_maps_r1690(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_mind_map_r1690(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_mind_map_nodes_r1690(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_mind_map_node_r1690(uuid, text, uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_mind_map_node_r1690(uuid, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.archive_mind_map_r1690(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mind_map_summary_r1690() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_mind_maps_r1690(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_mind_map_r1690(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_mind_map_nodes_r1690(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_mind_map_node_r1690(uuid, text, uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_mind_map_node_r1690(uuid, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archive_mind_map_r1690(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mind_map_summary_r1690() TO authenticated;

COMMIT;