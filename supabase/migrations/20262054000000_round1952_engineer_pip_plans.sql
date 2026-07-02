BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.engineer_pip_plans_r1952 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pip_reason text NOT NULL CHECK (pip_reason IN ('repeat_complaints','quality_drops','no_show','safety_violation','expertise_gap')),
  pip_duration_days int NOT NULL DEFAULT 30,
  target_metrics_md text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','improved','extended','exited','completed')),
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_pip_milestone_log_r1952 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pip_id uuid NOT NULL REFERENCES public.engineer_pip_plans_r1952(id) ON DELETE CASCADE,
  milestone_type text NOT NULL CHECK (milestone_type IN ('weekly_review','monthly_review','improvement','setback','exit')),
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  score int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_pip_plans_r1952 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_pip_milestone_log_r1952 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_plans_r1952 ON public.engineer_pip_plans_r1952;
CREATE POLICY founder_all_plans_r1952 ON public.engineer_pip_plans_r1952
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_milestones_r1952 ON public.engineer_pip_milestone_log_r1952;
CREATE POLICY founder_all_milestones_r1952 ON public.engineer_pip_milestone_log_r1952
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC: list_pips
CREATE OR REPLACE FUNCTION public.list_pips_r1952()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  pip_reason text,
  pip_duration_days int,
  status text,
  started_at timestamptz,
  ended_at timestamptz,
  target_metrics_md text,
  outcome_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.engineer_user_id, pr.email::text, p.pip_reason, p.pip_duration_days,
           p.status, p.started_at, p.ended_at, p.target_metrics_md, p.outcome_md
    FROM public.engineer_pip_plans_r1952 p
    LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
    ORDER BY p.started_at DESC
    LIMIT 200;
END;
$$;

-- RPC: log_pip
CREATE OR REPLACE FUNCTION public.log_pip_r1952(
  p_engineer_user_id uuid,
  p_pip_reason text,
  p_pip_duration_days int,
  p_target_metrics_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_pip_plans_r1952(engineer_user_id, pip_reason, pip_duration_days, target_metrics_md)
  VALUES (p_engineer_user_id, p_pip_reason, COALESCE(p_pip_duration_days,30), p_target_metrics_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pip_r1952',
          jsonb_build_object('pip_id', v_id, 'engineer_user_id', p_engineer_user_id, 'reason', p_pip_reason));

  RETURN v_id;
END;
$$;

-- RPC: list_milestones
CREATE OR REPLACE FUNCTION public.list_milestones_r1952(p_pip_id uuid)
RETURNS TABLE (
  id uuid,
  pip_id uuid,
  milestone_type text,
  reviewed_at timestamptz,
  by_email text,
  notes_md text,
  score int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.pip_id, m.milestone_type, m.reviewed_at, m.by_email, m.notes_md, m.score
    FROM public.engineer_pip_milestone_log_r1952 m
    WHERE m.pip_id = p_pip_id
    ORDER BY m.reviewed_at DESC
    LIMIT 200;
END;
$$;

-- RPC: log_milestone
CREATE OR REPLACE FUNCTION public.log_milestone_r1952(
  p_pip_id uuid,
  p_milestone_type text,
  p_notes_md text,
  p_score int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_pip_milestone_log_r1952(pip_id, milestone_type, by_email, notes_md, score)
  VALUES (p_pip_id, p_milestone_type, (auth.jwt()->>'email'), p_notes_md, p_score)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_milestone_r1952',
          jsonb_build_object('milestone_id', v_id, 'pip_id', p_pip_id, 'type', p_milestone_type, 'score', p_score));

  RETURN v_id;
END;
$$;

-- RPC: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1952(
  p_pip_id uuid,
  p_status text,
  p_outcome_md text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_pip_plans_r1952
     SET status = p_status,
         outcome_md = COALESCE(p_outcome_md, outcome_md),
         ended_at = CASE WHEN p_status IN ('improved','exited','completed') THEN now() ELSE ended_at END,
         updated_at = now()
   WHERE id = p_pip_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1952',
          jsonb_build_object('pip_id', p_pip_id, 'status', p_status));
END;
$$;

-- RPC: active_pips
CREATE OR REPLACE FUNCTION public.active_pips_r1952()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  pip_reason text,
  pip_duration_days int,
  started_at timestamptz,
  days_elapsed int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.engineer_user_id, pr.email::text, p.pip_reason, p.pip_duration_days,
           p.started_at,
           GREATEST(0, EXTRACT(DAY FROM (now() - p.started_at))::int) AS days_elapsed
    FROM public.engineer_pip_plans_r1952 p
    LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
    WHERE p.status IN ('active','extended')
    ORDER BY p.started_at ASC
    LIMIT 100;
END;
$$;

-- RPC: recent_milestones
CREATE OR REPLACE FUNCTION public.recent_milestones_r1952()
RETURNS TABLE (
  id uuid,
  pip_id uuid,
  engineer_email text,
  milestone_type text,
  reviewed_at timestamptz,
  by_email text,
  score int,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.pip_id, pr.email::text, m.milestone_type, m.reviewed_at, m.by_email, m.score, m.notes_md
    FROM public.engineer_pip_milestone_log_r1952 m
    JOIN public.engineer_pip_plans_r1952 p ON p.id = m.pip_id
    LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
    ORDER BY m.reviewed_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pips_r1952() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pip_r1952(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_milestones_r1952(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_milestone_r1952(uuid, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1952(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_pips_r1952() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_milestones_r1952() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pips_r1952() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pip_r1952(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_milestones_r1952(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_milestone_r1952(uuid, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1952(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_pips_r1952() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_milestones_r1952() TO authenticated;

COMMIT;
