BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_daily_focus_r2209 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  focus_date date NOT NULL,
  theme text NOT NULL,
  priority_1 text NOT NULL,
  priority_2 text,
  priority_3 text,
  energy_level text NOT NULL DEFAULT 'medium' CHECK (energy_level IN ('low','medium','high','peak')),
  focus_block_hours numeric(4,2) NOT NULL DEFAULT 4.0,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','completed','blown','rolled_over')),
  evening_reflection text,
  completion_pct int CHECK (completion_pct BETWEEN 0 AND 100),
  blockers text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  reflected_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.founder_focus_pattern_log_r2209 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  focus_id uuid REFERENCES public.founder_daily_focus_r2209(id) ON DELETE CASCADE,
  pattern_type text NOT NULL CHECK (pattern_type IN ('procrastination','flow_state','context_switch','deep_work','interruption','energy_dip')),
  pattern_note text NOT NULL,
  logged_at timestamptz NOT NULL DEFAULT now(),
  logged_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

ALTER TABLE public.founder_daily_focus_r2209 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_focus_pattern_log_r2209 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_daily_focus_r2209;
CREATE POLICY founder_all ON public.founder_daily_focus_r2209 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_focus_pattern_log_r2209;
CREATE POLICY founder_all ON public.founder_focus_pattern_log_r2209 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_daily_focus_r2209 FROM PUBLIC, anon;
REVOKE ALL ON public.founder_focus_pattern_log_r2209 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON public.founder_daily_focus_r2209 TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.founder_focus_pattern_log_r2209 TO authenticated;

CREATE OR REPLACE FUNCTION public.list_focus_r2209()
RETURNS TABLE(id uuid, focus_date date, theme text, priority_1 text, priority_2 text, priority_3 text,
              energy_level text, focus_block_hours numeric, status text, completion_pct int,
              evening_reflection text, blockers text, created_at timestamptz, reflected_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.focus_date, f.theme, f.priority_1, f.priority_2, f.priority_3,
         f.energy_level, f.focus_block_hours, f.status, f.completion_pct,
         f.evening_reflection, f.blockers, f.created_at, f.reflected_at
  FROM public.founder_daily_focus_r2209 f
  ORDER BY f.focus_date DESC, f.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2209()
RETURNS TABLE(id bigint, actor_email text, op_name text, after_value jsonb, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.actor_email, l.op_name, l.after_value, l.created_at
  FROM public.founder_action_log l
  WHERE l.op_name LIKE 'op_r2209%'
  ORDER BY l.created_at DESC LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_focus_status_r2209()
RETURNS TABLE(status text, day_count int, avg_completion numeric, total_focus_hours numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.status,
         (COUNT(*) FILTER (WHERE f.status IS NOT NULL))::int AS day_count,
         ROUND(AVG(COALESCE(f.completion_pct,0))::numeric, 1) AS avg_completion,
         ROUND(SUM(f.focus_block_hours)::numeric, 1) AS total_focus_hours
  FROM public.founder_daily_focus_r2209 f
  GROUP BY f.status
  ORDER BY day_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_focus_r2209(
  p_focus_date date, p_theme text, p_priority_1 text, p_priority_2 text, p_priority_3 text,
  p_energy_level text, p_focus_block_hours numeric
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_daily_focus_r2209(focus_date, theme, priority_1, priority_2, priority_3,
                                                energy_level, focus_block_hours, created_by)
  VALUES (p_focus_date, p_theme, p_priority_1, p_priority_2, p_priority_3,
          COALESCE(p_energy_level,'medium'), COALESCE(p_focus_block_hours,4.0), auth.uid())
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2209_log_focus',
          jsonb_build_object('id', v_id, 'focus_date', p_focus_date, 'theme', p_theme));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2209(p_focus_id uuid, p_pattern_type text, p_pattern_note text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_focus_pattern_log_r2209(focus_id, pattern_type, pattern_note, logged_by)
  VALUES (p_focus_id, p_pattern_type, p_pattern_note, auth.uid())
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2209_log_pattern',
          jsonb_build_object('id', v_id, 'focus_id', p_focus_id, 'pattern_type', p_pattern_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2209(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_daily_focus_r2209
  SET status = p_status,
      reflected_at = CASE WHEN p_status IN ('completed','blown','rolled_over') THEN now() ELSE reflected_at END
  WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2209_mark_status',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_or_search_r2209(p_days int)
RETURNS TABLE(focus_week text, day_count int, completed_count int, blown_count int,
              avg_completion numeric, avg_energy text, total_hours numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('week', f.focus_date), 'IYYY-IW') AS focus_week,
         (COUNT(*) FILTER (WHERE f.id IS NOT NULL))::int AS day_count,
         (COUNT(*) FILTER (WHERE f.status = 'completed'))::int AS completed_count,
         (COUNT(*) FILTER (WHERE f.status = 'blown'))::int AS blown_count,
         ROUND(AVG(COALESCE(f.completion_pct,0))::numeric, 1) AS avg_completion,
         (CASE
            WHEN AVG(CASE f.energy_level WHEN 'low' THEN 1 WHEN 'medium' THEN 2 WHEN 'high' THEN 3 WHEN 'peak' THEN 4 ELSE 2 END) >= 3.5 THEN 'peak'
            WHEN AVG(CASE f.energy_level WHEN 'low' THEN 1 WHEN 'medium' THEN 2 WHEN 'high' THEN 3 WHEN 'peak' THEN 4 ELSE 2 END) >= 2.5 THEN 'high'
            WHEN AVG(CASE f.energy_level WHEN 'low' THEN 1 WHEN 'medium' THEN 2 WHEN 'high' THEN 3 WHEN 'peak' THEN 4 ELSE 2 END) >= 1.5 THEN 'medium'
            ELSE 'low'
          END)::text AS avg_energy,
         ROUND(SUM(f.focus_block_hours)::numeric, 1) AS total_hours
  FROM public.founder_daily_focus_r2209 f
  WHERE f.focus_date >= (CURRENT_DATE - (COALESCE(p_days,30) || ' days')::interval)::date
  GROUP BY focus_week
  ORDER BY focus_week DESC
  LIMIT 26;
END;
$$;

REVOKE ALL ON FUNCTION public.list_focus_r2209() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2209() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_focus_status_r2209() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_focus_r2209(date, text, text, text, text, text, numeric) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2209(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2209(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_or_search_r2209(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_focus_r2209() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2209() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_focus_status_r2209() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_focus_r2209(date, text, text, text, text, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2209(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2209(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_or_search_r2209(int) TO authenticated;

COMMIT;
