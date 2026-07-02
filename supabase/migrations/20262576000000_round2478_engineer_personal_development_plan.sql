-- Round r2478: Engineer Personal Development Plan
-- Per-engineer career goal x 90-day plan x milestones x manager check-in x promotion-readiness

BEGIN;

-- =========================================================
-- TABLE 1: engineer_pdp_goals_r2478
-- =========================================================
CREATE TABLE IF NOT EXISTS public.engineer_pdp_goals_r2478 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  goal_title text NOT NULL,
  career_track text NOT NULL CHECK (career_track IN ('senior_engineer','team_lead','specialist','manager','founder_track')),
  ninety_day_plan_md text NOT NULL DEFAULT '',
  manager_email text,
  last_check_in_at timestamptz,
  next_check_in_at timestamptz,
  promotion_readiness_pct integer NOT NULL DEFAULT 0 CHECK (promotion_readiness_pct BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','completed','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pdp_goals_r2478_engineer ON public.engineer_pdp_goals_r2478(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_pdp_goals_r2478_status ON public.engineer_pdp_goals_r2478(status);
CREATE INDEX IF NOT EXISTS idx_pdp_goals_r2478_track ON public.engineer_pdp_goals_r2478(career_track);
CREATE INDEX IF NOT EXISTS idx_pdp_goals_r2478_next_check ON public.engineer_pdp_goals_r2478(next_check_in_at);

ALTER TABLE public.engineer_pdp_goals_r2478 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_pdp_goals_r2478;
CREATE POLICY founder_all ON public.engineer_pdp_goals_r2478
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================
-- TABLE 2: engineer_pdp_milestones_r2478
-- =========================================================
CREATE TABLE IF NOT EXISTS public.engineer_pdp_milestones_r2478 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pdp_id uuid NOT NULL REFERENCES public.engineer_pdp_goals_r2478(id) ON DELETE CASCADE,
  milestone_title text NOT NULL,
  target_at timestamptz,
  completed_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','blocked','dropped')),
  evidence_md text NOT NULL DEFAULT '',
  manager_signoff_at timestamptz,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pdp_milestones_r2478_pdp ON public.engineer_pdp_milestones_r2478(pdp_id);
CREATE INDEX IF NOT EXISTS idx_pdp_milestones_r2478_status ON public.engineer_pdp_milestones_r2478(status);
CREATE INDEX IF NOT EXISTS idx_pdp_milestones_r2478_target ON public.engineer_pdp_milestones_r2478(target_at);

ALTER TABLE public.engineer_pdp_milestones_r2478 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_pdp_milestones_r2478;
CREATE POLICY founder_all ON public.engineer_pdp_milestones_r2478
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================
-- SEED DATA
-- =========================================================
DO $seed$
DECLARE
  v_eng_id uuid;
  v_goal1 uuid;
  v_goal2 uuid;
  v_goal3 uuid;
  v_goal4 uuid;
  v_goal5 uuid;
BEGIN
  SELECT id INTO v_eng_id FROM public.engineers ORDER BY created_at LIMIT 1;
  IF v_eng_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.engineer_pdp_goals_r2478 (engineer_user_id, goal_title, career_track, ninety_day_plan_md, manager_email, last_check_in_at, next_check_in_at, promotion_readiness_pct, status, notes)
  VALUES (v_eng_id, 'Promote to Senior Engineer', 'senior_engineer', '## 30-60-90\n- Lead 5 complex repairs\n- Mentor 1 junior\n- Pass NABH audit', 'manager@equipseva.in', (now() - interval '7 days')::timestamptz, (now() + interval '7 days')::timestamptz, 75, 'active', 'On track')
  RETURNING id INTO v_goal1;

  INSERT INTO public.engineer_pdp_goals_r2478 (engineer_user_id, goal_title, career_track, ninety_day_plan_md, manager_email, last_check_in_at, next_check_in_at, promotion_readiness_pct, status, notes)
  VALUES (v_eng_id, 'Move to Team Lead', 'team_lead', '## Plan\n- Run weekly standup\n- Own SLA dashboard', 'manager@equipseva.in', (now() - interval '14 days')::timestamptz, (now() + interval '14 days')::timestamptz, 55, 'active', 'Needs more leadership reps')
  RETURNING id INTO v_goal2;

  INSERT INTO public.engineer_pdp_goals_r2478 (engineer_user_id, goal_title, career_track, ninety_day_plan_md, manager_email, last_check_in_at, next_check_in_at, promotion_readiness_pct, status, notes)
  VALUES (v_eng_id, 'Become CT Scanner Specialist', 'specialist', '## Plan\n- GE CT certification\n- 20 successful CT repairs', 'specialist-lead@equipseva.in', (now() - interval '21 days')::timestamptz, (now() + interval '3 days')::timestamptz, 90, 'active', 'Close to promotion')
  RETURNING id INTO v_goal3;

  INSERT INTO public.engineer_pdp_goals_r2478 (engineer_user_id, goal_title, career_track, ninety_day_plan_md, manager_email, last_check_in_at, next_check_in_at, promotion_readiness_pct, status, notes)
  VALUES (v_eng_id, 'Move into Manager Role', 'manager', '## Plan\n- Manage 4 engineers\n- OKR rollouts', 'founder@equipseva.in', (now() - interval '30 days')::timestamptz, (now() + interval '30 days')::timestamptz, 40, 'paused', 'Paused - role not open yet')
  RETURNING id INTO v_goal4;

  INSERT INTO public.engineer_pdp_goals_r2478 (engineer_user_id, goal_title, career_track, ninety_day_plan_md, manager_email, last_check_in_at, next_check_in_at, promotion_readiness_pct, status, notes)
  VALUES (v_eng_id, 'Founder Track - Vertical Owner', 'founder_track', '## Plan\n- Own dental vertical P&L\n- Hire 2 engineers', 'founder@equipseva.in', (now() - interval '5 days')::timestamptz, (now() + interval '25 days')::timestamptz, 100, 'completed', 'Promoted last cycle')
  RETURNING id INTO v_goal5;

  -- Milestones
  INSERT INTO public.engineer_pdp_milestones_r2478 (pdp_id, milestone_title, target_at, completed_at, status, evidence_md, manager_signoff_at, notes)
  VALUES (v_goal1, 'Complete 5 complex repairs', (now() + interval '30 days')::timestamptz, NULL, 'in_progress', '3 of 5 done', NULL, '');

  INSERT INTO public.engineer_pdp_milestones_r2478 (pdp_id, milestone_title, target_at, completed_at, status, evidence_md, manager_signoff_at, notes)
  VALUES (v_goal1, 'Mentor 1 junior engineer', (now() + interval '60 days')::timestamptz, (now() - interval '2 days')::timestamptz, 'done', 'Paired with Ravi for 4 weeks', (now() - interval '1 days')::timestamptz, '');

  INSERT INTO public.engineer_pdp_milestones_r2478 (pdp_id, milestone_title, target_at, completed_at, status, evidence_md, manager_signoff_at, notes)
  VALUES (v_goal2, 'Run 8 weekly standups', (now() + interval '20 days')::timestamptz, NULL, 'open', '', NULL, '');

  INSERT INTO public.engineer_pdp_milestones_r2478 (pdp_id, milestone_title, target_at, completed_at, status, evidence_md, manager_signoff_at, notes)
  VALUES (v_goal3, 'GE CT certification exam', (now() - interval '10 days')::timestamptz, NULL, 'blocked', 'Exam slot delayed by GE', NULL, 'Reschedule needed');

  INSERT INTO public.engineer_pdp_milestones_r2478 (pdp_id, milestone_title, target_at, completed_at, status, evidence_md, manager_signoff_at, notes)
  VALUES (v_goal5, 'Hire 2 dental engineers', (now() - interval '60 days')::timestamptz, (now() - interval '45 days')::timestamptz, 'done', 'Both onboarded', (now() - interval '44 days')::timestamptz, '');
END
$seed$;

-- =========================================================
-- RPC 1: list_pdp_goals_r2478
-- =========================================================
CREATE OR REPLACE FUNCTION public.list_pdp_goals_r2478()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  goal_title text,
  career_track text,
  manager_email text,
  last_check_in_at timestamptz,
  next_check_in_at timestamptz,
  promotion_readiness_pct integer,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.engineer_user_id, g.goal_title, g.career_track, g.manager_email,
         g.last_check_in_at, g.next_check_in_at, g.promotion_readiness_pct, g.status, g.created_at
  FROM public.engineer_pdp_goals_r2478 g
  ORDER BY g.promotion_readiness_pct DESC, g.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pdp_goals_r2478() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pdp_goals_r2478() TO authenticated;

-- =========================================================
-- RPC 2: list_milestones_r2478
-- =========================================================
CREATE OR REPLACE FUNCTION public.list_milestones_r2478()
RETURNS TABLE (
  id uuid,
  pdp_id uuid,
  milestone_title text,
  target_at timestamptz,
  completed_at timestamptz,
  status text,
  manager_signoff_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.pdp_id, m.milestone_title, m.target_at, m.completed_at,
         m.status, m.manager_signoff_at, m.created_at
  FROM public.engineer_pdp_milestones_r2478 m
  ORDER BY COALESCE(m.target_at, m.created_at) DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_milestones_r2478() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_milestones_r2478() TO authenticated;

-- =========================================================
-- RPC 3: top_promotion_ready_r2478
-- =========================================================
CREATE OR REPLACE FUNCTION public.top_promotion_ready_r2478()
RETURNS TABLE (
  id uuid,
  goal_title text,
  career_track text,
  promotion_readiness_pct integer,
  status text,
  next_check_in_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.goal_title, g.career_track, g.promotion_readiness_pct, g.status, g.next_check_in_at
  FROM public.engineer_pdp_goals_r2478 g
  WHERE g.status = 'active' AND g.promotion_readiness_pct >= 70
  ORDER BY g.promotion_readiness_pct DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_promotion_ready_r2478() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_promotion_ready_r2478() TO authenticated;

-- =========================================================
-- RPC 4: overdue_milestones_r2478
-- =========================================================
CREATE OR REPLACE FUNCTION public.overdue_milestones_r2478()
RETURNS TABLE (
  id uuid,
  pdp_id uuid,
  milestone_title text,
  target_at timestamptz,
  status text,
  days_overdue integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.pdp_id, m.milestone_title, m.target_at, m.status,
         GREATEST(0, EXTRACT(DAY FROM (now() - m.target_at))::integer) AS days_overdue
  FROM public.engineer_pdp_milestones_r2478 m
  WHERE m.target_at IS NOT NULL
    AND m.target_at < now()
    AND m.status IN ('open','in_progress','blocked')
  ORDER BY m.target_at ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.overdue_milestones_r2478() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_milestones_r2478() TO authenticated;

-- =========================================================
-- RPC 5: manager_load_r2478
-- =========================================================
CREATE OR REPLACE FUNCTION public.manager_load_r2478()
RETURNS TABLE (
  manager_email text,
  active_goals bigint,
  avg_readiness_pct numeric,
  upcoming_checkins bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(g.manager_email, 'unassigned') AS manager_email,
         COUNT(*) FILTER (WHERE g.status = 'active') AS active_goals,
         ROUND(AVG(g.promotion_readiness_pct) FILTER (WHERE g.status = 'active'), 1) AS avg_readiness_pct,
         COUNT(*) FILTER (WHERE g.next_check_in_at IS NOT NULL AND g.next_check_in_at <= (now() + interval '14 days')::timestamptz) AS upcoming_checkins
  FROM public.engineer_pdp_goals_r2478 g
  GROUP BY COALESCE(g.manager_email, 'unassigned')
  ORDER BY active_goals DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.manager_load_r2478() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.manager_load_r2478() TO authenticated;

-- =========================================================
-- RPC 6: completion_rate_r2478
-- =========================================================
CREATE OR REPLACE FUNCTION public.completion_rate_r2478()
RETURNS TABLE (
  total_milestones bigint,
  done_count bigint,
  blocked_count bigint,
  in_progress_count bigint,
  completion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*) AS total_milestones,
         COUNT(*) FILTER (WHERE m.status = 'done') AS done_count,
         COUNT(*) FILTER (WHERE m.status = 'blocked') AS blocked_count,
         COUNT(*) FILTER (WHERE m.status = 'in_progress') AS in_progress_count,
         CASE WHEN COUNT(*) = 0 THEN 0
              ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE m.status = 'done') / COUNT(*), 1)
         END AS completion_pct
  FROM public.engineer_pdp_milestones_r2478 m;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.completion_rate_r2478() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.completion_rate_r2478() TO authenticated;

-- =========================================================
-- RPC 7: career_track_distribution_r2478
-- =========================================================
CREATE OR REPLACE FUNCTION public.career_track_distribution_r2478()
RETURNS TABLE (
  career_track text,
  goal_count bigint,
  avg_readiness_pct numeric,
  active_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.career_track,
         COUNT(*) AS goal_count,
         ROUND(AVG(g.promotion_readiness_pct), 1) AS avg_readiness_pct,
         COUNT(*) FILTER (WHERE g.status = 'active') AS active_count
  FROM public.engineer_pdp_goals_r2478 g
  GROUP BY g.career_track
  ORDER BY goal_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.career_track_distribution_r2478() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.career_track_distribution_r2478() TO authenticated;

