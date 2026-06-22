BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_okr_objectives_r2237 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  fiscal_year int NOT NULL,
  quarter_num int NOT NULL CHECK (quarter_num BETWEEN 1 AND 4),
  objective_title text NOT NULL,
  objective_description text,
  key_result_text text NOT NULL,
  target_value numeric NOT NULL DEFAULT 0,
  baseline_value numeric NOT NULL DEFAULT 0,
  mid_quarter_value numeric,
  end_quarter_value numeric,
  weight_pct int NOT NULL DEFAULT 25 CHECK (weight_pct BETWEEN 0 AND 100),
  category text NOT NULL DEFAULT 'growth' CHECK (category IN ('growth','quality','ops','people','finance')),
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','active','mid_checked','scored','archived')),
  mid_check_at timestamptz,
  scored_at timestamptz,
  final_score_pct numeric,
  notes text,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_okr_lessons_r2237 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_id uuid REFERENCES public.founder_okr_objectives_r2237(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  lesson_type text NOT NULL DEFAULT 'learning' CHECK (lesson_type IN ('learning','blocker','win','rollforward')),
  lesson_text text NOT NULL,
  action_item text,
  rolled_to_quarter text,
  resolved boolean NOT NULL DEFAULT false,
  resolved_at timestamptz,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_okr_objectives_r2237 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_okr_lessons_r2237 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_okr_objectives_r2237;
CREATE POLICY founder_all ON public.founder_okr_objectives_r2237 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_okr_lessons_r2237;
CREATE POLICY founder_all ON public.founder_okr_lessons_r2237 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_okr_obj_quarter_r2237 ON public.founder_okr_objectives_r2237(quarter_label, status);
CREATE INDEX IF NOT EXISTS idx_okr_obj_fy_r2237 ON public.founder_okr_objectives_r2237(fiscal_year, quarter_num);
CREATE INDEX IF NOT EXISTS idx_okr_lessons_quarter_r2237 ON public.founder_okr_lessons_r2237(quarter_label, resolved);

DROP FUNCTION IF EXISTS public.founder_okr_quarter_summary_r2237();
CREATE FUNCTION public.founder_okr_quarter_summary_r2237()
RETURNS TABLE(quarter_label text, fiscal_year int, quarter_num int, objective_count int, active_count int, scored_count int, avg_score numeric, total_weight int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.quarter_label, o.fiscal_year, o.quarter_num,
         (COUNT(*))::int,
         (COUNT(*) FILTER (WHERE o.status = 'active'))::int,
         (COUNT(*) FILTER (WHERE o.status = 'scored'))::int,
         ROUND(AVG(o.final_score_pct) FILTER (WHERE o.final_score_pct IS NOT NULL), 1),
         (COALESCE(SUM(o.weight_pct), 0))::int
  FROM public.founder_okr_objectives_r2237 o
  GROUP BY o.quarter_label, o.fiscal_year, o.quarter_num
  ORDER BY o.fiscal_year DESC, o.quarter_num DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.founder_okr_objectives_list_r2237();
CREATE FUNCTION public.founder_okr_objectives_list_r2237()
RETURNS TABLE(id uuid, quarter_label text, objective_title text, key_result_text text, category text, target_value numeric, baseline_value numeric, mid_quarter_value numeric, end_quarter_value numeric, weight_pct int, status text, final_score_pct numeric, owner_email text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.quarter_label, o.objective_title, o.key_result_text, o.category,
         o.target_value, o.baseline_value, o.mid_quarter_value, o.end_quarter_value,
         o.weight_pct, o.status, o.final_score_pct, o.owner_email, o.created_at
  FROM public.founder_okr_objectives_r2237 o
  ORDER BY o.fiscal_year DESC, o.quarter_num DESC, o.weight_pct DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.founder_okr_category_breakdown_r2237();
CREATE FUNCTION public.founder_okr_category_breakdown_r2237()
RETURNS TABLE(category text, objective_count int, avg_score numeric, total_weight int, scored_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.category,
         (COUNT(*))::int,
         ROUND(AVG(o.final_score_pct) FILTER (WHERE o.final_score_pct IS NOT NULL), 1),
         (COALESCE(SUM(o.weight_pct), 0))::int,
         (COUNT(*) FILTER (WHERE o.status = 'scored'))::int
  FROM public.founder_okr_objectives_r2237 o
  GROUP BY o.category
  ORDER BY (COUNT(*))::int DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.founder_okr_mid_check_pending_r2237();
CREATE FUNCTION public.founder_okr_mid_check_pending_r2237()
RETURNS TABLE(id uuid, quarter_label text, objective_title text, key_result_text text, baseline_value numeric, target_value numeric, mid_quarter_value numeric, weight_pct int, owner_email text, days_since_created int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.quarter_label, o.objective_title, o.key_result_text,
         o.baseline_value, o.target_value, o.mid_quarter_value, o.weight_pct, o.owner_email,
         (EXTRACT(DAY FROM (now() - o.created_at)))::int
  FROM public.founder_okr_objectives_r2237 o
  WHERE o.status IN ('active','planned') AND o.mid_check_at IS NULL
  ORDER BY o.created_at ASC
  LIMIT 100;
END;
$$;

DROP FUNCTION IF EXISTS public.founder_okr_top_performers_r2237();
CREATE FUNCTION public.founder_okr_top_performers_r2237()
RETURNS TABLE(id uuid, quarter_label text, objective_title text, key_result_text text, final_score_pct numeric, weight_pct int, category text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.quarter_label, o.objective_title, o.key_result_text,
         o.final_score_pct, o.weight_pct, o.category
  FROM public.founder_okr_objectives_r2237 o
  WHERE o.status = 'scored' AND o.final_score_pct IS NOT NULL
  ORDER BY o.final_score_pct DESC
  LIMIT 50;
END;
$$;

DROP FUNCTION IF EXISTS public.founder_okr_lessons_list_r2237();
CREATE FUNCTION public.founder_okr_lessons_list_r2237()
RETURNS TABLE(id uuid, quarter_label text, lesson_type text, lesson_text text, action_item text, rolled_to_quarter text, resolved boolean, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.quarter_label, l.lesson_type, l.lesson_text, l.action_item,
         l.rolled_to_quarter, l.resolved, l.created_at
  FROM public.founder_okr_lessons_r2237 l
  ORDER BY l.created_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.founder_okr_rollforward_pending_r2237();
CREATE FUNCTION public.founder_okr_rollforward_pending_r2237()
RETURNS TABLE(id uuid, quarter_label text, lesson_type text, lesson_text text, action_item text, rolled_to_quarter text, age_days int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.quarter_label, l.lesson_type, l.lesson_text, l.action_item,
         l.rolled_to_quarter,
         (EXTRACT(DAY FROM (now() - l.created_at)))::int
  FROM public.founder_okr_lessons_r2237 l
  WHERE l.lesson_type = 'rollforward' AND l.resolved = false
  ORDER BY l.created_at ASC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_okr_quarter_summary_r2237() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_okr_objectives_list_r2237() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_okr_category_breakdown_r2237() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_okr_mid_check_pending_r2237() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_okr_top_performers_r2237() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_okr_lessons_list_r2237() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_okr_rollforward_pending_r2237() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_okr_quarter_summary_r2237() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_okr_objectives_list_r2237() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_okr_category_breakdown_r2237() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_okr_mid_check_pending_r2237() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_okr_top_performers_r2237() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_okr_lessons_list_r2237() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_okr_rollforward_pending_r2237() TO authenticated;

COMMIT;
