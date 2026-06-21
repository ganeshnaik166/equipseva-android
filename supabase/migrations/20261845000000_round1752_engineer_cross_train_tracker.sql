BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_cross_train_assignments_r1752 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_equipment_category text NOT NULL,
  trainer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  started_on date NOT NULL DEFAULT CURRENT_DATE,
  target_completion_date date,
  hours_logged int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','passed','failed','dropped')),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_cross_train_assessments_r1752 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id uuid NOT NULL REFERENCES public.engineer_cross_train_assignments_r1752(id) ON DELETE CASCADE,
  assessment_date date NOT NULL DEFAULT CURRENT_DATE,
  assessment_type text NOT NULL CHECK (assessment_type IN ('written','practical','shadow','independent_job')),
  score int,
  passed boolean NOT NULL DEFAULT false,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_xtrain_assign_r1752_eng ON public.engineer_cross_train_assignments_r1752(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_xtrain_assign_r1752_status ON public.engineer_cross_train_assignments_r1752(status);
CREATE INDEX IF NOT EXISTS idx_xtrain_assess_r1752_assign ON public.engineer_cross_train_assessments_r1752(assignment_id);

ALTER TABLE public.engineer_cross_train_assignments_r1752 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_cross_train_assessments_r1752 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_xtrain_assign_r1752 ON public.engineer_cross_train_assignments_r1752;
CREATE POLICY founder_all_xtrain_assign_r1752 ON public.engineer_cross_train_assignments_r1752
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_xtrain_assess_r1752 ON public.engineer_cross_train_assessments_r1752;
CREATE POLICY founder_all_xtrain_assess_r1752 ON public.engineer_cross_train_assessments_r1752
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_assignments
CREATE OR REPLACE FUNCTION public.list_cross_train_assignments_r1752()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  target_equipment_category text,
  trainer_user_id uuid,
  trainer_email text,
  started_on date,
  target_completion_date date,
  hours_logged int,
  status text,
  decided_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_user_id, e.email::text, a.target_equipment_category,
         a.trainer_user_id, t.email::text, a.started_on, a.target_completion_date,
         a.hours_logged, a.status, a.decided_at, a.created_at
  FROM public.engineer_cross_train_assignments_r1752 a
  LEFT JOIN public.profiles e ON e.id = a.engineer_user_id
  LEFT JOIN public.profiles t ON t.id = a.trainer_user_id
  ORDER BY a.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: assign_cross_train
CREATE OR REPLACE FUNCTION public.assign_cross_train_r1752(
  p_engineer_user_id uuid,
  p_target_equipment_category text,
  p_trainer_user_id uuid,
  p_target_completion_date date
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
  INSERT INTO public.engineer_cross_train_assignments_r1752(engineer_user_id, target_equipment_category, trainer_user_id, target_completion_date)
  VALUES (p_engineer_user_id, p_target_equipment_category, p_trainer_user_id, p_target_completion_date)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'assign_cross_train_r1752',
          jsonb_build_object('id', v_id, 'engineer', p_engineer_user_id, 'category', p_target_equipment_category));
  RETURN v_id;
END;
$$;

-- RPC 3: list_assessments
CREATE OR REPLACE FUNCTION public.list_cross_train_assessments_r1752(p_assignment_id uuid)
RETURNS TABLE (
  id uuid,
  assignment_id uuid,
  assessment_date date,
  assessment_type text,
  score int,
  passed boolean,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.assignment_id, a.assessment_date, a.assessment_type, a.score, a.passed, a.note, a.created_at
  FROM public.engineer_cross_train_assessments_r1752 a
  WHERE (p_assignment_id IS NULL OR a.assignment_id = p_assignment_id)
  ORDER BY a.assessment_date DESC
  LIMIT 200;
END;
$$;

-- RPC 4: record_assessment
CREATE OR REPLACE FUNCTION public.record_cross_train_assessment_r1752(
  p_assignment_id uuid,
  p_assessment_type text,
  p_score int,
  p_passed boolean,
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
  INSERT INTO public.engineer_cross_train_assessments_r1752(assignment_id, assessment_type, score, passed, note)
  VALUES (p_assignment_id, p_assessment_type, p_score, p_passed, p_note)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_cross_train_assessment_r1752',
          jsonb_build_object('id', v_id, 'assignment', p_assignment_id, 'type', p_assessment_type, 'passed', p_passed));
  RETURN v_id;
END;
$$;

-- RPC 5: decide_assignment
CREATE OR REPLACE FUNCTION public.decide_cross_train_assignment_r1752(
  p_assignment_id uuid,
  p_decision text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_decision NOT IN ('passed','failed','dropped') THEN RAISE EXCEPTION 'invalid decision'; END IF;
  UPDATE public.engineer_cross_train_assignments_r1752
  SET status = p_decision, decided_at = now(), updated_at = now()
  WHERE id = p_assignment_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'decide_cross_train_assignment_r1752',
          jsonb_build_object('id', p_assignment_id, 'decision', p_decision));
END;
$$;

-- RPC 6: progress_summary
CREATE OR REPLACE FUNCTION public.cross_train_progress_summary_r1752()
RETURNS TABLE (
  status text,
  cnt int,
  total_hours int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status, COUNT(*)::int, COALESCE(SUM(a.hours_logged),0)::int
  FROM public.engineer_cross_train_assignments_r1752 a
  GROUP BY a.status
  ORDER BY a.status;
END;
$$;

-- RPC 7: completed_cross_trains
CREATE OR REPLACE FUNCTION public.completed_cross_trains_r1752()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  target_equipment_category text,
  status text,
  hours_logged int,
  decided_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_user_id, p.email::text, a.target_equipment_category, a.status, a.hours_logged, a.decided_at
  FROM public.engineer_cross_train_assignments_r1752 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_user_id
  WHERE a.status IN ('passed','failed','dropped')
  ORDER BY a.decided_at DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_cross_train_assignments_r1752() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.assign_cross_train_r1752(uuid, text, uuid, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_cross_train_assessments_r1752(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_cross_train_assessment_r1752(uuid, text, int, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decide_cross_train_assignment_r1752(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.cross_train_progress_summary_r1752() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.completed_cross_trains_r1752() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_cross_train_assignments_r1752() TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_cross_train_r1752(uuid, text, uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_cross_train_assessments_r1752(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_cross_train_assessment_r1752(uuid, text, int, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_cross_train_assignment_r1752(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cross_train_progress_summary_r1752() TO authenticated;
GRANT EXECUTE ON FUNCTION public.completed_cross_trains_r1752() TO authenticated;

COMMIT;