BEGIN;

-- =====================================================================
-- Round 1794 — Founder Annual Goals Tracker
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_annual_goals_r1794 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_year int NOT NULL,
  goal_title text NOT NULL,
  goal_category text NOT NULL CHECK (goal_category IN ('growth','financial','personal','team','product','customer')),
  target_value numeric NOT NULL DEFAULT 0,
  target_unit text NOT NULL DEFAULT '',
  current_value numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','at_risk','missed','exceeded','dropped')),
  weight int NOT NULL DEFAULT 5 CHECK (weight BETWEEN 1 AND 10),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_annual_goal_quarterly_progress_r1794 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id uuid NOT NULL REFERENCES public.founder_annual_goals_r1794(id) ON DELETE CASCADE,
  quarter text NOT NULL CHECK (quarter IN ('Q1','Q2','Q3','Q4')),
  progress_value numeric NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','at_risk','missed','exceeded')),
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fag_r1794_year ON public.founder_annual_goals_r1794(goal_year);
CREATE INDEX IF NOT EXISTS idx_fag_r1794_status ON public.founder_annual_goals_r1794(status);
CREATE INDEX IF NOT EXISTS idx_fagqp_r1794_goal ON public.founder_annual_goal_quarterly_progress_r1794(goal_id);
CREATE INDEX IF NOT EXISTS idx_fagqp_r1794_recorded ON public.founder_annual_goal_quarterly_progress_r1794(recorded_at DESC);

ALTER TABLE public.founder_annual_goals_r1794 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_annual_goal_quarterly_progress_r1794 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fag_r1794_founder ON public.founder_annual_goals_r1794;
CREATE POLICY fag_r1794_founder ON public.founder_annual_goals_r1794
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fagqp_r1794_founder ON public.founder_annual_goal_quarterly_progress_r1794;
CREATE POLICY fagqp_r1794_founder ON public.founder_annual_goal_quarterly_progress_r1794
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_goals
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_annual_goals_r1794(p_year int DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  goal_year int,
  goal_title text,
  goal_category text,
  target_value numeric,
  target_unit text,
  current_value numeric,
  status text,
  weight int,
  pct_progress numeric,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    g.id, g.goal_year, g.goal_title, g.goal_category,
    g.target_value, g.target_unit, g.current_value, g.status, g.weight,
    CASE WHEN g.target_value > 0 THEN ROUND((g.current_value / g.target_value) * 100, 2) ELSE 0 END,
    g.created_at
  FROM public.founder_annual_goals_r1794 g
  WHERE (p_year IS NULL OR g.goal_year = p_year)
  ORDER BY g.goal_year DESC, g.weight DESC, g.created_at DESC;
END;
$$;

-- =====================================================================
-- RPC 2: set_goal
-- =====================================================================
CREATE OR REPLACE FUNCTION public.set_annual_goal_r1794(
  p_goal_id uuid,
  p_year int,
  p_title text,
  p_category text,
  p_target_value numeric,
  p_target_unit text,
  p_weight int
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

  IF p_goal_id IS NULL THEN
    INSERT INTO public.founder_annual_goals_r1794(goal_year, goal_title, goal_category, target_value, target_unit, weight)
    VALUES (p_year, p_title, p_category, p_target_value, p_target_unit, p_weight)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.founder_annual_goals_r1794
       SET goal_year = p_year,
           goal_title = p_title,
           goal_category = p_category,
           target_value = p_target_value,
           target_unit = p_target_unit,
           weight = p_weight,
           updated_at = now()
     WHERE id = p_goal_id
    RETURNING id INTO v_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_annual_goal_r1794',
    jsonb_build_object('goal_id', v_id, 'year', p_year, 'title', p_title, 'category', p_category));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_progress
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_annual_goal_progress_r1794(p_goal_id uuid DEFAULT NULL, p_year int DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  goal_id uuid,
  goal_title text,
  goal_year int,
  quarter text,
  progress_value numeric,
  status text,
  note text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.goal_id, g.goal_title, g.goal_year, p.quarter,
    p.progress_value, p.status, p.note, p.recorded_at
  FROM public.founder_annual_goal_quarterly_progress_r1794 p
  JOIN public.founder_annual_goals_r1794 g ON g.id = p.goal_id
  WHERE (p_goal_id IS NULL OR p.goal_id = p_goal_id)
    AND (p_year IS NULL OR g.goal_year = p_year)
  ORDER BY p.recorded_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 4: record_progress
-- =====================================================================
CREATE OR REPLACE FUNCTION public.record_annual_goal_progress_r1794(
  p_goal_id uuid,
  p_quarter text,
  p_progress_value numeric,
  p_status text,
  p_note text
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

  INSERT INTO public.founder_annual_goal_quarterly_progress_r1794(goal_id, quarter, progress_value, status, note)
  VALUES (p_goal_id, p_quarter, p_progress_value, p_status, COALESCE(p_note, ''))
  RETURNING id INTO v_id;

  UPDATE public.founder_annual_goals_r1794
     SET current_value = p_progress_value,
         updated_at = now()
   WHERE id = p_goal_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_annual_goal_progress_r1794',
    jsonb_build_object('goal_id', p_goal_id, 'quarter', p_quarter, 'progress', p_progress_value, 'status', p_status));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5: update_goal_status
-- =====================================================================
CREATE OR REPLACE FUNCTION public.update_annual_goal_status_r1794(
  p_goal_id uuid,
  p_status text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.founder_annual_goals_r1794
     SET status = p_status,
         updated_at = now()
   WHERE id = p_goal_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_annual_goal_status_r1794',
    jsonb_build_object('goal_id', p_goal_id, 'status', p_status));

  RETURN true;
END;
$$;

-- =====================================================================
-- RPC 6: year_summary
-- =====================================================================
CREATE OR REPLACE FUNCTION public.annual_goals_year_summary_r1794(p_year int)
RETURNS TABLE (
  category text,
  total_goals int,
  on_track_count int,
  at_risk_count int,
  missed_count int,
  exceeded_count int,
  dropped_count int,
  avg_progress_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    g.goal_category,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE g.status = 'on_track'))::int,
    (COUNT(*) FILTER (WHERE g.status = 'at_risk'))::int,
    (COUNT(*) FILTER (WHERE g.status = 'missed'))::int,
    (COUNT(*) FILTER (WHERE g.status = 'exceeded'))::int,
    (COUNT(*) FILTER (WHERE g.status = 'dropped'))::int,
    ROUND(AVG(CASE WHEN g.target_value > 0 THEN (g.current_value / g.target_value) * 100 ELSE 0 END), 2)
  FROM public.founder_annual_goals_r1794 g
  WHERE g.goal_year = p_year
  GROUP BY g.goal_category
  ORDER BY g.goal_category;
END;
$$;

-- =====================================================================
-- RPC 7: top_at_risk_goals
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_at_risk_annual_goals_r1794(p_year int DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  goal_title text,
  goal_category text,
  goal_year int,
  weight int,
  status text,
  pct_progress numeric,
  current_value numeric,
  target_value numeric,
  target_unit text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    g.id, g.goal_title, g.goal_category, g.goal_year, g.weight, g.status,
    CASE WHEN g.target_value > 0 THEN ROUND((g.current_value / g.target_value) * 100, 2) ELSE 0 END AS pct,
    g.current_value, g.target_value, g.target_unit
  FROM public.founder_annual_goals_r1794 g
  WHERE g.status IN ('at_risk','missed')
    AND (p_year IS NULL OR g.goal_year = p_year)
  ORDER BY g.weight DESC,
    CASE WHEN g.target_value > 0 THEN (g.current_value / g.target_value) ELSE 0 END ASC
  LIMIT 20;
END;
$$;

-- =====================================================================
-- Permissions
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.list_annual_goals_r1794(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_annual_goal_r1794(uuid, int, text, text, numeric, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_annual_goal_progress_r1794(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_annual_goal_progress_r1794(uuid, text, numeric, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_annual_goal_status_r1794(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.annual_goals_year_summary_r1794(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_at_risk_annual_goals_r1794(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_annual_goals_r1794(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_annual_goal_r1794(uuid, int, text, text, numeric, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_annual_goal_progress_r1794(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_annual_goal_progress_r1794(uuid, text, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_annual_goal_status_r1794(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.annual_goals_year_summary_r1794(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_at_risk_annual_goals_r1794(int) TO authenticated;

COMMIT;