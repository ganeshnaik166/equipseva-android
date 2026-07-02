BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_pre_service_checklists_r1892 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_category text NOT NULL,
  checklist_label text NOT NULL,
  checklist_items text[] NOT NULL DEFAULT ARRAY[]::text[],
  required_minutes int NOT NULL DEFAULT 5,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','under_review','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_epsc_r1892_status ON public.engineer_pre_service_checklists_r1892(status);
CREATE INDEX IF NOT EXISTS idx_epsc_r1892_category ON public.engineer_pre_service_checklists_r1892(equipment_category);

CREATE TABLE IF NOT EXISTS public.engineer_checklist_completions_r1892 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  checklist_id uuid NOT NULL REFERENCES public.engineer_pre_service_checklists_r1892(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL,
  repair_job_id uuid,
  completed_at timestamptz NOT NULL DEFAULT now(),
  completion_time_min int NOT NULL DEFAULT 0,
  all_passed boolean NOT NULL DEFAULT true,
  failed_items text[] NOT NULL DEFAULT ARRAY[]::text[],
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecc_r1892_checklist ON public.engineer_checklist_completions_r1892(checklist_id);
CREATE INDEX IF NOT EXISTS idx_ecc_r1892_engineer ON public.engineer_checklist_completions_r1892(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecc_r1892_completed_at ON public.engineer_checklist_completions_r1892(completed_at);

ALTER TABLE public.engineer_pre_service_checklists_r1892 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_checklist_completions_r1892 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_epsc_r1892_founder_all ON public.engineer_pre_service_checklists_r1892;
CREATE POLICY p_epsc_r1892_founder_all ON public.engineer_pre_service_checklists_r1892
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_ecc_r1892_founder_all ON public.engineer_checklist_completions_r1892;
CREATE POLICY p_ecc_r1892_founder_all ON public.engineer_checklist_completions_r1892
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_checklists
DROP FUNCTION IF EXISTS public.list_checklists_r1892();
CREATE OR REPLACE FUNCTION public.list_checklists_r1892()
RETURNS TABLE(
  id uuid,
  equipment_category text,
  checklist_label text,
  item_count int,
  required_minutes int,
  status text,
  updated_at timestamptz
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
  SELECT c.id, c.equipment_category, c.checklist_label,
         COALESCE(array_length(c.checklist_items,1),0)::int AS item_count,
         c.required_minutes, c.status, c.updated_at
  FROM public.engineer_pre_service_checklists_r1892 c
  ORDER BY c.updated_at DESC
  LIMIT 200;
END;
$$;

-- 2. save_checklist
DROP FUNCTION IF EXISTS public.save_checklist_r1892(uuid, text, text, text[], int, text);
CREATE OR REPLACE FUNCTION public.save_checklist_r1892(
  p_id uuid,
  p_equipment_category text,
  p_checklist_label text,
  p_checklist_items text[],
  p_required_minutes int,
  p_status text
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
  IF p_id IS NULL THEN
    INSERT INTO public.engineer_pre_service_checklists_r1892(equipment_category, checklist_label, checklist_items, required_minutes, status)
    VALUES (p_equipment_category, p_checklist_label, COALESCE(p_checklist_items, ARRAY[]::text[]), COALESCE(p_required_minutes,5), COALESCE(p_status,'active'))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.engineer_pre_service_checklists_r1892
    SET equipment_category = p_equipment_category,
        checklist_label = p_checklist_label,
        checklist_items = COALESCE(p_checklist_items, checklist_items),
        required_minutes = COALESCE(p_required_minutes, required_minutes),
        status = COALESCE(p_status, status),
        updated_at = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_checklist_r1892',
          jsonb_build_object('id', v_id, 'category', p_equipment_category, 'label', p_checklist_label, 'status', p_status));

  RETURN v_id;
END;
$$;

-- 3. list_completions
DROP FUNCTION IF EXISTS public.list_completions_r1892(int);
CREATE OR REPLACE FUNCTION public.list_completions_r1892(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  checklist_label text,
  equipment_category text,
  engineer_user_id uuid,
  repair_job_id uuid,
  completed_at timestamptz,
  completion_time_min int,
  all_passed boolean,
  failed_count int
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
  SELECT cc.id, c.checklist_label, c.equipment_category, cc.engineer_user_id,
         cc.repair_job_id, cc.completed_at, cc.completion_time_min, cc.all_passed,
         COALESCE(array_length(cc.failed_items,1),0)::int AS failed_count
  FROM public.engineer_checklist_completions_r1892 cc
  JOIN public.engineer_pre_service_checklists_r1892 c ON c.id = cc.checklist_id
  ORDER BY cc.completed_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

-- 4. log_completion
DROP FUNCTION IF EXISTS public.log_completion_r1892(uuid, uuid, uuid, int, boolean, text[]);
CREATE OR REPLACE FUNCTION public.log_completion_r1892(
  p_checklist_id uuid,
  p_engineer_user_id uuid,
  p_repair_job_id uuid,
  p_completion_time_min int,
  p_all_passed boolean,
  p_failed_items text[]
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
  INSERT INTO public.engineer_checklist_completions_r1892(
    checklist_id, engineer_user_id, repair_job_id, completion_time_min, all_passed, failed_items
  )
  VALUES (
    p_checklist_id, p_engineer_user_id, p_repair_job_id,
    COALESCE(p_completion_time_min, 0), COALESCE(p_all_passed, true),
    COALESCE(p_failed_items, ARRAY[]::text[])
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_completion_r1892',
          jsonb_build_object('id', v_id, 'checklist_id', p_checklist_id, 'engineer', p_engineer_user_id, 'passed', p_all_passed));

  RETURN v_id;
END;
$$;

-- 5. top_completions
DROP FUNCTION IF EXISTS public.top_completions_r1892();
CREATE OR REPLACE FUNCTION public.top_completions_r1892()
RETURNS TABLE(
  checklist_label text,
  equipment_category text,
  completions int,
  pass_count int,
  fail_count int,
  pass_rate_pct numeric,
  avg_time_min numeric
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
  SELECT c.checklist_label, c.equipment_category,
         COUNT(*)::int AS completions,
         (COUNT(*) FILTER (WHERE cc.all_passed))::int AS pass_count,
         (COUNT(*) FILTER (WHERE NOT cc.all_passed))::int AS fail_count,
         ROUND(100.0 * (COUNT(*) FILTER (WHERE cc.all_passed))::numeric / NULLIF(COUNT(*),0), 1) AS pass_rate_pct,
         ROUND(AVG(cc.completion_time_min)::numeric, 1) AS avg_time_min
  FROM public.engineer_checklist_completions_r1892 cc
  JOIN public.engineer_pre_service_checklists_r1892 c ON c.id = cc.checklist_id
  GROUP BY c.checklist_label, c.equipment_category
  ORDER BY completions DESC
  LIMIT 50;
END;
$$;

-- 6. failed_items_analysis
DROP FUNCTION IF EXISTS public.failed_items_analysis_r1892();
CREATE OR REPLACE FUNCTION public.failed_items_analysis_r1892()
RETURNS TABLE(
  failed_item text,
  fail_count int,
  last_failed_at timestamptz
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
  SELECT u.item AS failed_item,
         COUNT(*)::int AS fail_count,
         MAX(cc.completed_at) AS last_failed_at
  FROM public.engineer_checklist_completions_r1892 cc
  CROSS JOIN LATERAL unnest(cc.failed_items) AS u(item)
  WHERE NOT cc.all_passed
  GROUP BY u.item
  ORDER BY fail_count DESC, last_failed_at DESC
  LIMIT 50;
END;
$$;

-- 7. top_engineers
DROP FUNCTION IF EXISTS public.top_engineers_r1892();
CREATE OR REPLACE FUNCTION public.top_engineers_r1892()
RETURNS TABLE(
  engineer_user_id uuid,
  completions int,
  pass_count int,
  pass_rate_pct numeric,
  avg_time_min numeric,
  last_completed_at timestamptz
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
  SELECT cc.engineer_user_id,
         COUNT(*)::int AS completions,
         (COUNT(*) FILTER (WHERE cc.all_passed))::int AS pass_count,
         ROUND(100.0 * (COUNT(*) FILTER (WHERE cc.all_passed))::numeric / NULLIF(COUNT(*),0), 1) AS pass_rate_pct,
         ROUND(AVG(cc.completion_time_min)::numeric, 1) AS avg_time_min,
         MAX(cc.completed_at) AS last_completed_at
  FROM public.engineer_checklist_completions_r1892 cc
  GROUP BY cc.engineer_user_id
  ORDER BY completions DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_checklists_r1892() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.save_checklist_r1892(uuid, text, text, text[], int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_completions_r1892(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_completion_r1892(uuid, uuid, uuid, int, boolean, text[]) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_completions_r1892() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.failed_items_analysis_r1892() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_engineers_r1892() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_checklists_r1892() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_checklist_r1892(uuid, text, text, text[], int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_completions_r1892(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_completion_r1892(uuid, uuid, uuid, int, boolean, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_completions_r1892() TO authenticated;
GRANT EXECUTE ON FUNCTION public.failed_items_analysis_r1892() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_engineers_r1892() TO authenticated;

COMMIT;