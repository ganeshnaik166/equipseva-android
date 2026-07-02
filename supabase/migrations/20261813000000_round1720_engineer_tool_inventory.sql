BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_tool_inventory_r1720 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tool_name text NOT NULL,
  tool_category text NOT NULL CHECK (tool_category IN ('diagnostic','repair','calibration','safety','measurement')),
  condition text NOT NULL DEFAULT 'good' CHECK (condition IN ('new','good','fair','worn','needs_replacement')),
  last_inspected_at timestamptz,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  retired_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_tool_replacement_queue_r1720 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tool_id uuid NOT NULL REFERENCES public.engineer_tool_inventory_r1720(id) ON DELETE CASCADE,
  requested_at timestamptz NOT NULL DEFAULT now(),
  requested_by_email text,
  priority text NOT NULL DEFAULT 'med' CHECK (priority IN ('low','med','high','urgent')),
  cost_estimate_rupees int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','approved','ordered','received','cancelled')),
  fulfilled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_tool_inventory_r1720 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_tool_replacement_queue_r1720 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_tools_r1720 ON public.engineer_tool_inventory_r1720;
CREATE POLICY founder_all_tools_r1720 ON public.engineer_tool_inventory_r1720
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_replacements_r1720 ON public.engineer_tool_replacement_queue_r1720;
CREATE POLICY founder_all_replacements_r1720 ON public.engineer_tool_replacement_queue_r1720
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1) list_tools
CREATE OR REPLACE FUNCTION public.list_tools_r1720()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  tool_name text,
  tool_category text,
  condition text,
  last_inspected_at timestamptz,
  assigned_at timestamptz,
  retired_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.engineer_user_id, p.email, t.tool_name, t.tool_category,
           t.condition, t.last_inspected_at, t.assigned_at, t.retired_at, t.created_at
    FROM public.engineer_tool_inventory_r1720 t
    LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
    ORDER BY t.created_at DESC
    LIMIT 200;
END;
$$;

-- 2) assign_tool
CREATE OR REPLACE FUNCTION public.assign_tool_r1720(
  p_engineer_user_id uuid,
  p_tool_name text,
  p_tool_category text,
  p_condition text
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
  INSERT INTO public.engineer_tool_inventory_r1720 (engineer_user_id, tool_name, tool_category, condition)
  VALUES (p_engineer_user_id, p_tool_name, p_tool_category, COALESCE(p_condition, 'good'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'assign_tool_r1720',
          jsonb_build_object('tool_id', v_id, 'engineer_user_id', p_engineer_user_id,
                             'tool_name', p_tool_name, 'category', p_tool_category));
  RETURN v_id;
END;
$$;

-- 3) list_replacements
CREATE OR REPLACE FUNCTION public.list_replacements_r1720(p_status text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  tool_id uuid,
  tool_name text,
  tool_category text,
  engineer_email text,
  requested_at timestamptz,
  requested_by_email text,
  priority text,
  cost_estimate_rupees int,
  status text,
  fulfilled_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT q.id, q.tool_id, t.tool_name, t.tool_category, p.email,
           q.requested_at, q.requested_by_email, q.priority, q.cost_estimate_rupees,
           q.status, q.fulfilled_at
    FROM public.engineer_tool_replacement_queue_r1720 q
    JOIN public.engineer_tool_inventory_r1720 t ON t.id = q.tool_id
    LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
    WHERE p_status IS NULL OR q.status = p_status
    ORDER BY q.requested_at DESC
    LIMIT 200;
END;
$$;

-- 4) request_replacement
CREATE OR REPLACE FUNCTION public.request_replacement_r1720(
  p_tool_id uuid,
  p_priority text,
  p_cost_estimate_rupees int
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
  INSERT INTO public.engineer_tool_replacement_queue_r1720 (tool_id, requested_by_email, priority, cost_estimate_rupees)
  VALUES (p_tool_id, (auth.jwt()->>'email'), COALESCE(p_priority, 'med'), COALESCE(p_cost_estimate_rupees, 0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'request_replacement_r1720',
          jsonb_build_object('queue_id', v_id, 'tool_id', p_tool_id,
                             'priority', p_priority, 'cost_estimate_rupees', p_cost_estimate_rupees));
  RETURN v_id;
END;
$$;

-- 5) update_replacement_status
CREATE OR REPLACE FUNCTION public.update_replacement_status_r1720(
  p_queue_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_tool_replacement_queue_r1720
     SET status = p_status,
         fulfilled_at = CASE WHEN p_status = 'received' THEN now() ELSE fulfilled_at END,
         updated_at = now()
   WHERE id = p_queue_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_replacement_status_r1720',
          jsonb_build_object('queue_id', p_queue_id, 'status', p_status));
END;
$$;

-- 6) condition_summary
CREATE OR REPLACE FUNCTION public.condition_summary_r1720()
RETURNS TABLE (
  total_tools int,
  new_count int,
  good_count int,
  fair_count int,
  worn_count int,
  needs_replacement_count int,
  retired_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::int FROM public.engineer_tool_inventory_r1720),
      (SELECT (COUNT(*) FILTER (WHERE condition = 'new'))::int FROM public.engineer_tool_inventory_r1720),
      (SELECT (COUNT(*) FILTER (WHERE condition = 'good'))::int FROM public.engineer_tool_inventory_r1720),
      (SELECT (COUNT(*) FILTER (WHERE condition = 'fair'))::int FROM public.engineer_tool_inventory_r1720),
      (SELECT (COUNT(*) FILTER (WHERE condition = 'worn'))::int FROM public.engineer_tool_inventory_r1720),
      (SELECT (COUNT(*) FILTER (WHERE condition = 'needs_replacement'))::int FROM public.engineer_tool_inventory_r1720),
      (SELECT (COUNT(*) FILTER (WHERE retired_at IS NOT NULL))::int FROM public.engineer_tool_inventory_r1720);
END;
$$;

-- 7) urgent_replacements
CREATE OR REPLACE FUNCTION public.urgent_replacements_r1720()
RETURNS TABLE (
  id uuid,
  tool_id uuid,
  tool_name text,
  tool_category text,
  engineer_email text,
  priority text,
  cost_estimate_rupees int,
  requested_at timestamptz,
  days_open int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT q.id, q.tool_id, t.tool_name, t.tool_category, p.email,
           q.priority, q.cost_estimate_rupees, q.requested_at,
           EXTRACT(DAY FROM (now() - q.requested_at))::int
    FROM public.engineer_tool_replacement_queue_r1720 q
    JOIN public.engineer_tool_inventory_r1720 t ON t.id = q.tool_id
    LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
    WHERE q.status IN ('open','approved')
      AND q.priority IN ('high','urgent')
    ORDER BY
      CASE q.priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
      q.requested_at ASC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_tools_r1720() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.assign_tool_r1720(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_replacements_r1720(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.request_replacement_r1720(uuid, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_replacement_status_r1720(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.condition_summary_r1720() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.urgent_replacements_r1720() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tools_r1720() TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_tool_r1720(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_replacements_r1720(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_replacement_r1720(uuid, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_replacement_status_r1720(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.condition_summary_r1720() TO authenticated;
GRANT EXECUTE ON FUNCTION public.urgent_replacements_r1720() TO authenticated;

COMMIT;