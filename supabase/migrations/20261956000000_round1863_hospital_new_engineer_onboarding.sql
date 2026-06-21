BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_new_engineer_onboarding_r1863 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  started_on date NOT NULL DEFAULT CURRENT_DATE,
  first_30d_review_at date,
  completed_30d_review_at timestamptz,
  hospital_satisfaction_score int CHECK (hospital_satisfaction_score BETWEEN 1 AND 10),
  engineer_satisfaction_score int CHECK (engineer_satisfaction_score BETWEEN 1 AND 10),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','withdrew_engineer')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_engineer_onboarding_checkpoints_r1863 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL REFERENCES public.hospital_new_engineer_onboarding_r1863(id) ON DELETE CASCADE,
  checkpoint text NOT NULL CHECK (checkpoint IN ('meet_team','first_call','first_visit','handover_complete','first_repair')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hneo_r1863_engineer ON public.hospital_new_engineer_onboarding_r1863(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_hneo_r1863_hospital ON public.hospital_new_engineer_onboarding_r1863(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hneo_r1863_status ON public.hospital_new_engineer_onboarding_r1863(status);
CREATE INDEX IF NOT EXISTS idx_heoc_r1863_onboarding ON public.hospital_engineer_onboarding_checkpoints_r1863(onboarding_id);

ALTER TABLE public.hospital_new_engineer_onboarding_r1863 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_engineer_onboarding_checkpoints_r1863 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hneo_r1863_founder_all ON public.hospital_new_engineer_onboarding_r1863;
CREATE POLICY hneo_r1863_founder_all ON public.hospital_new_engineer_onboarding_r1863
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS heoc_r1863_founder_all ON public.hospital_engineer_onboarding_checkpoints_r1863;
CREATE POLICY heoc_r1863_founder_all ON public.hospital_engineer_onboarding_checkpoints_r1863
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- list_onboardings
CREATE OR REPLACE FUNCTION public.list_onboardings_r1863()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  started_on date,
  first_30d_review_at date,
  completed_30d_review_at timestamptz,
  hospital_satisfaction_score int,
  engineer_satisfaction_score int,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.engineer_user_id, o.hospital_user_id, o.started_on, o.first_30d_review_at,
         o.completed_30d_review_at, o.hospital_satisfaction_score, o.engineer_satisfaction_score,
         o.status, o.created_at
  FROM public.hospital_new_engineer_onboarding_r1863 o
  ORDER BY o.started_on DESC, o.created_at DESC
  LIMIT 200;
END;
$$;

-- log_onboarding
CREATE OR REPLACE FUNCTION public.log_onboarding_r1863(
  p_engineer_user_id uuid,
  p_hospital_user_id uuid,
  p_started_on date DEFAULT CURRENT_DATE
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_new_engineer_onboarding_r1863(engineer_user_id, hospital_user_id, started_on, first_30d_review_at)
  VALUES (p_engineer_user_id, p_hospital_user_id, p_started_on, p_started_on + 30)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_onboarding_r1863',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'hospital_user_id', p_hospital_user_id));
  RETURN v_id;
END;
$$;

-- list_checkpoints
CREATE OR REPLACE FUNCTION public.list_checkpoints_r1863(p_onboarding_id uuid)
RETURNS TABLE (
  id uuid,
  onboarding_id uuid,
  checkpoint text,
  completed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.onboarding_id, c.checkpoint, c.completed_at, c.created_at
  FROM public.hospital_engineer_onboarding_checkpoints_r1863 c
  WHERE c.onboarding_id = p_onboarding_id
  ORDER BY c.created_at ASC;
END;
$$;

-- mark_checkpoint
CREATE OR REPLACE FUNCTION public.mark_checkpoint_r1863(
  p_onboarding_id uuid,
  p_checkpoint text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_engineer_onboarding_checkpoints_r1863(onboarding_id, checkpoint, completed_at)
  VALUES (p_onboarding_id, p_checkpoint, now())
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_checkpoint_r1863',
          jsonb_build_object('id', v_id, 'onboarding_id', p_onboarding_id, 'checkpoint', p_checkpoint));
  RETURN v_id;
END;
$$;

-- complete_onboarding
CREATE OR REPLACE FUNCTION public.complete_onboarding_r1863(
  p_id uuid,
  p_hospital_score int,
  p_engineer_score int,
  p_status text DEFAULT 'completed'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_new_engineer_onboarding_r1863
     SET completed_30d_review_at = now(),
         hospital_satisfaction_score = p_hospital_score,
         engineer_satisfaction_score = p_engineer_score,
         status = p_status,
         updated_at = now()
   WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_onboarding_r1863',
          jsonb_build_object('id', p_id, 'status', p_status, 'hospital_score', p_hospital_score, 'engineer_score', p_engineer_score));
  RETURN p_id;
END;
$$;

-- satisfaction_summary
CREATE OR REPLACE FUNCTION public.satisfaction_summary_r1863()
RETURNS TABLE (
  total_completed int,
  avg_hospital_score numeric,
  avg_engineer_score numeric,
  withdrew_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE status = 'completed'))::int AS total_completed,
    (AVG(hospital_satisfaction_score) FILTER (WHERE status = 'completed'))::numeric AS avg_hospital_score,
    (AVG(engineer_satisfaction_score) FILTER (WHERE status = 'completed'))::numeric AS avg_engineer_score,
    (COUNT(*) FILTER (WHERE status = 'withdrew_engineer'))::int AS withdrew_count
  FROM public.hospital_new_engineer_onboarding_r1863;
END;
$$;

-- in_progress
CREATE OR REPLACE FUNCTION public.in_progress_r1863()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  started_on date,
  first_30d_review_at date,
  days_elapsed int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.engineer_user_id, o.hospital_user_id, o.started_on, o.first_30d_review_at,
         (CURRENT_DATE - o.started_on)::int AS days_elapsed
  FROM public.hospital_new_engineer_onboarding_r1863 o
  WHERE o.status = 'active'
  ORDER BY o.started_on ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_onboardings_r1863() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_onboarding_r1863(uuid, uuid, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_checkpoints_r1863(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_checkpoint_r1863(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_onboarding_r1863(uuid, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.satisfaction_summary_r1863() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.in_progress_r1863() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_onboardings_r1863() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_onboarding_r1863(uuid, uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_checkpoints_r1863(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_checkpoint_r1863(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_onboarding_r1863(uuid, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.satisfaction_summary_r1863() TO authenticated;
GRANT EXECUTE ON FUNCTION public.in_progress_r1863() TO authenticated;

COMMIT;