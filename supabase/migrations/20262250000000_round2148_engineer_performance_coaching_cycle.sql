BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_performance_coaching_cycle_r2148 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  cycle_focus text NOT NULL CHECK (cycle_focus IN ('technical','customer','safety','teamwork','leadership')),
  started_at timestamptz NOT NULL DEFAULT now(),
  expected_complete_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','improved','closed','escalated','abandoned')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_coaching_milestone_log_r2148 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES public.engineer_performance_coaching_cycle_r2148(id) ON DELETE CASCADE,
  milestone_type text NOT NULL CHECK (milestone_type IN ('assessment','coaching_session','practical','feedback','exit')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  score int,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecc_r2148_engineer ON public.engineer_performance_coaching_cycle_r2148(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecc_r2148_status ON public.engineer_performance_coaching_cycle_r2148(status);
CREATE INDEX IF NOT EXISTS idx_ecml_r2148_cycle ON public.engineer_coaching_milestone_log_r2148(cycle_id);
CREATE INDEX IF NOT EXISTS idx_ecml_r2148_taken ON public.engineer_coaching_milestone_log_r2148(taken_at DESC);

ALTER TABLE public.engineer_performance_coaching_cycle_r2148 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_coaching_milestone_log_r2148 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ecc_r2148 ON public.engineer_performance_coaching_cycle_r2148;
CREATE POLICY founder_all_ecc_r2148 ON public.engineer_performance_coaching_cycle_r2148
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_ecml_r2148 ON public.engineer_coaching_milestone_log_r2148;
CREATE POLICY founder_all_ecml_r2148 ON public.engineer_coaching_milestone_log_r2148
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_cycles
DROP FUNCTION IF EXISTS public.list_cycles_r2148(int);
CREATE OR REPLACE FUNCTION public.list_cycles_r2148(p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  cycle_focus text,
  started_at timestamptz,
  expected_complete_at timestamptz,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.engineer_user_id, c.cycle_focus, c.started_at, c.expected_complete_at, c.status, c.captured_at
    FROM public.engineer_performance_coaching_cycle_r2148 c
    ORDER BY c.started_at DESC
    LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_cycles_r2148(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cycles_r2148(int) TO authenticated;

-- 2. log_cycle
DROP FUNCTION IF EXISTS public.log_cycle_r2148(uuid, text, timestamptz);
CREATE OR REPLACE FUNCTION public.log_cycle_r2148(
  p_engineer_user_id uuid,
  p_cycle_focus text,
  p_expected_complete_at timestamptz
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
  INSERT INTO public.engineer_performance_coaching_cycle_r2148(engineer_user_id, cycle_focus, expected_complete_at)
  VALUES (p_engineer_user_id, p_cycle_focus, p_expected_complete_at)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cycle_r2148',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'cycle_focus', p_cycle_focus));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_cycle_r2148(uuid, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_cycle_r2148(uuid, text, timestamptz) TO authenticated;

-- 3. list_milestones
DROP FUNCTION IF EXISTS public.list_milestones_r2148(uuid, int);
CREATE OR REPLACE FUNCTION public.list_milestones_r2148(p_cycle_id uuid, p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  cycle_id uuid,
  milestone_type text,
  taken_at timestamptz,
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
    SELECT m.id, m.cycle_id, m.milestone_type, m.taken_at, m.by_email, m.score, m.notes_md
    FROM public.engineer_coaching_milestone_log_r2148 m
    WHERE (p_cycle_id IS NULL OR m.cycle_id = p_cycle_id)
    ORDER BY m.taken_at DESC
    LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_milestones_r2148(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_milestones_r2148(uuid, int) TO authenticated;

-- 4. log_milestone
DROP FUNCTION IF EXISTS public.log_milestone_r2148(uuid, text, text, int, text);
CREATE OR REPLACE FUNCTION public.log_milestone_r2148(
  p_cycle_id uuid,
  p_milestone_type text,
  p_by_email text,
  p_score int,
  p_notes_md text
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
  INSERT INTO public.engineer_coaching_milestone_log_r2148(cycle_id, milestone_type, by_email, score, notes_md)
  VALUES (p_cycle_id, p_milestone_type, p_by_email, p_score, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_milestone_r2148',
          jsonb_build_object('id', v_id, 'cycle_id', p_cycle_id, 'milestone_type', p_milestone_type, 'score', p_score));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_milestone_r2148(uuid, text, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_milestone_r2148(uuid, text, text, int, text) TO authenticated;

-- 5. mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2148(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2148(p_cycle_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_performance_coaching_cycle_r2148
     SET status = p_status, updated_at = now()
   WHERE id = p_cycle_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2148',
          jsonb_build_object('cycle_id', p_cycle_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2148(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2148(uuid, text) TO authenticated;

-- 6. active_cycles
DROP FUNCTION IF EXISTS public.active_cycles_r2148();
CREATE OR REPLACE FUNCTION public.active_cycles_r2148()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  cycle_focus text,
  started_at timestamptz,
  expected_complete_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.engineer_user_id, c.cycle_focus, c.started_at, c.expected_complete_at, c.status
    FROM public.engineer_performance_coaching_cycle_r2148 c
    WHERE c.status = 'active'
    ORDER BY c.started_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.active_cycles_r2148() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_cycles_r2148() TO authenticated;

-- 7. recent_milestones
DROP FUNCTION IF EXISTS public.recent_milestones_r2148(int);
CREATE OR REPLACE FUNCTION public.recent_milestones_r2148(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  cycle_id uuid,
  milestone_type text,
  taken_at timestamptz,
  by_email text,
  score int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.cycle_id, m.milestone_type, m.taken_at, m.by_email, m.score
    FROM public.engineer_coaching_milestone_log_r2148 m
    ORDER BY m.taken_at DESC
    LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_milestones_r2148(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_milestones_r2148(int) TO authenticated;

COMMIT;
