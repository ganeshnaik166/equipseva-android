BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_personal_roadmap_r1798 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  year int NOT NULL,
  focus_area text NOT NULL CHECK (focus_area IN ('leadership','health','learning','family','finance','spiritual')),
  goal_title text NOT NULL,
  current_state_md text,
  target_state_md text,
  deadline date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','achieved','missed','dropped')),
  priority text NOT NULL DEFAULT 'important' CHECK (priority IN ('critical','important','nice')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_personal_roadmap_actions_r1798 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  roadmap_id uuid NOT NULL REFERENCES public.founder_personal_roadmap_r1798(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  completed_at timestamptz,
  evidence_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_personal_roadmap_r1798 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_personal_roadmap_actions_r1798 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_r1798_a ON public.founder_personal_roadmap_r1798;
CREATE POLICY founder_only_r1798_a ON public.founder_personal_roadmap_r1798
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_r1798_b ON public.founder_personal_roadmap_actions_r1798;
CREATE POLICY founder_only_r1798_b ON public.founder_personal_roadmap_actions_r1798
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_roadmap_r1798(p_year int DEFAULT NULL)
RETURNS TABLE(id uuid, year int, focus_area text, goal_title text, current_state_md text, target_state_md text, deadline date, status text, priority text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.year, r.focus_area, r.goal_title, r.current_state_md, r.target_state_md, r.deadline, r.status, r.priority, r.created_at
    FROM public.founder_personal_roadmap_r1798 r
    WHERE (p_year IS NULL OR r.year = p_year)
    ORDER BY r.year DESC,
      CASE r.priority WHEN 'critical' THEN 1 WHEN 'important' THEN 2 ELSE 3 END,
      r.deadline NULLS LAST;
END $$;

CREATE OR REPLACE FUNCTION public.set_item_r1798(
  p_year int, p_focus_area text, p_goal_title text, p_current_state_md text,
  p_target_state_md text, p_deadline date, p_priority text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_personal_roadmap_r1798(year, focus_area, goal_title, current_state_md, target_state_md, deadline, priority)
    VALUES (p_year, p_focus_area, p_goal_title, p_current_state_md, p_target_state_md, p_deadline, COALESCE(p_priority,'important'))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_item_r1798', jsonb_build_object('id', v_id, 'year', p_year, 'focus_area', p_focus_area, 'goal_title', p_goal_title));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r1798(p_roadmap_id uuid)
RETURNS TABLE(id uuid, roadmap_id uuid, action_text text, completed_at timestamptz, evidence_md text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.roadmap_id, a.action_text, a.completed_at, a.evidence_md, a.created_at
    FROM public.founder_personal_roadmap_actions_r1798 a
    WHERE a.roadmap_id = p_roadmap_id
    ORDER BY a.completed_at NULLS FIRST, a.created_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r1798(p_roadmap_id uuid, p_action_text text, p_evidence_md text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_personal_roadmap_actions_r1798(roadmap_id, action_text, evidence_md, completed_at)
    VALUES (p_roadmap_id, p_action_text, p_evidence_md, now())
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1798', jsonb_build_object('id', v_id, 'roadmap_id', p_roadmap_id));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.complete_item_r1798(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('active','achieved','missed','dropped') THEN RAISE EXCEPTION 'bad status'; END IF;
  UPDATE public.founder_personal_roadmap_r1798 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_item_r1798', jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.year_summary_r1798(p_year int)
RETURNS TABLE(focus_area text, total int, achieved int, active int, missed int, dropped int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.focus_area,
      COUNT(*)::int AS total,
      (COUNT(*) FILTER (WHERE r.status = 'achieved'))::int AS achieved,
      (COUNT(*) FILTER (WHERE r.status = 'active'))::int AS active,
      (COUNT(*) FILTER (WHERE r.status = 'missed'))::int AS missed,
      (COUNT(*) FILTER (WHERE r.status = 'dropped'))::int AS dropped
    FROM public.founder_personal_roadmap_r1798 r
    WHERE r.year = p_year
    GROUP BY r.focus_area
    ORDER BY r.focus_area;
END $$;

CREATE OR REPLACE FUNCTION public.top_priority_items_r1798()
RETURNS TABLE(id uuid, year int, focus_area text, goal_title text, deadline date, priority text, status text, days_to_deadline int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.year, r.focus_area, r.goal_title, r.deadline, r.priority, r.status,
      CASE WHEN r.deadline IS NULL THEN NULL ELSE (r.deadline - CURRENT_DATE)::int END AS days_to_deadline
    FROM public.founder_personal_roadmap_r1798 r
    WHERE r.status = 'active' AND r.priority IN ('critical','important')
    ORDER BY CASE r.priority WHEN 'critical' THEN 1 ELSE 2 END, r.deadline NULLS LAST
    LIMIT 20;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_roadmap_r1798(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_item_r1798(int,text,text,text,text,date,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1798(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1798(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_item_r1798(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.year_summary_r1798(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_priority_items_r1798() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_roadmap_r1798(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_item_r1798(int,text,text,text,text,date,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1798(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1798(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_item_r1798(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.year_summary_r1798(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_priority_items_r1798() TO authenticated;

COMMIT;