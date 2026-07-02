BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_onboarding_walkthroughs_r1790 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  walkthrough_kickoff_date date NOT NULL,
  scheduled_30d_review_at timestamptz,
  scheduled_60d_review_at timestamptz,
  completed_at timestamptz,
  founder_attended boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','in_progress','completed','cancelled')),
  satisfaction_score int CHECK (satisfaction_score BETWEEN 1 AND 10),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_walkthrough_checkpoints_r1790 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  walkthrough_id uuid NOT NULL REFERENCES public.founder_onboarding_walkthroughs_r1790(id) ON DELETE CASCADE,
  checkpoint text NOT NULL CHECK (checkpoint IN ('signup','equipment_setup','first_job','payment_setup','first_amc','team_introduction')),
  completed_at timestamptz,
  completed_by_email text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_walkthroughs_r1790_status ON public.founder_onboarding_walkthroughs_r1790(status);
CREATE INDEX IF NOT EXISTS idx_walkthroughs_r1790_hospital ON public.founder_onboarding_walkthroughs_r1790(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_checkpoints_r1790_walkthrough ON public.founder_walkthrough_checkpoints_r1790(walkthrough_id);

ALTER TABLE public.founder_onboarding_walkthroughs_r1790 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_walkthrough_checkpoints_r1790 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_walk_r1790 ON public.founder_onboarding_walkthroughs_r1790;
CREATE POLICY founder_all_walk_r1790 ON public.founder_onboarding_walkthroughs_r1790
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_chk_r1790 ON public.founder_walkthrough_checkpoints_r1790;
CREATE POLICY founder_all_chk_r1790 ON public.founder_walkthrough_checkpoints_r1790
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_walkthroughs
CREATE OR REPLACE FUNCTION public.list_walkthroughs_r1790()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  walkthrough_kickoff_date date,
  scheduled_30d_review_at timestamptz,
  scheduled_60d_review_at timestamptz,
  completed_at timestamptz,
  founder_attended boolean,
  status text,
  satisfaction_score int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.hospital_user_id, p.email, w.walkthrough_kickoff_date,
         w.scheduled_30d_review_at, w.scheduled_60d_review_at,
         w.completed_at, w.founder_attended, w.status, w.satisfaction_score, w.created_at
  FROM public.founder_onboarding_walkthroughs_r1790 w
  LEFT JOIN public.profiles p ON p.id = w.hospital_user_id
  ORDER BY w.created_at DESC
  LIMIT 200;
END;
$$;

-- 2. schedule_walkthrough
CREATE OR REPLACE FUNCTION public.schedule_walkthrough_r1790(
  p_hospital_user_id uuid,
  p_kickoff_date date
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
  INSERT INTO public.founder_onboarding_walkthroughs_r1790(
    hospital_user_id, walkthrough_kickoff_date,
    scheduled_30d_review_at, scheduled_60d_review_at, status
  ) VALUES (
    p_hospital_user_id, p_kickoff_date,
    (p_kickoff_date + interval '30 days')::timestamptz,
    (p_kickoff_date + interval '60 days')::timestamptz,
    'scheduled'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'schedule_walkthrough_r1790',
          jsonb_build_object('walkthrough_id', v_id, 'hospital_user_id', p_hospital_user_id), now());

  RETURN v_id;
END;
$$;

-- 3. list_checkpoints
CREATE OR REPLACE FUNCTION public.list_checkpoints_r1790(p_walkthrough_id uuid)
RETURNS TABLE(
  id uuid,
  walkthrough_id uuid,
  checkpoint text,
  completed_at timestamptz,
  completed_by_email text,
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
  SELECT c.id, c.walkthrough_id, c.checkpoint, c.completed_at, c.completed_by_email, c.note, c.created_at
  FROM public.founder_walkthrough_checkpoints_r1790 c
  WHERE c.walkthrough_id = p_walkthrough_id
  ORDER BY c.created_at ASC;
END;
$$;

-- 4. mark_checkpoint
CREATE OR REPLACE FUNCTION public.mark_checkpoint_r1790(
  p_walkthrough_id uuid,
  p_checkpoint text,
  p_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  INSERT INTO public.founder_walkthrough_checkpoints_r1790(
    walkthrough_id, checkpoint, completed_at, completed_by_email, note
  ) VALUES (
    p_walkthrough_id, p_checkpoint, now(), v_email, p_note
  ) RETURNING id INTO v_id;

  UPDATE public.founder_onboarding_walkthroughs_r1790
  SET status = CASE WHEN status = 'scheduled' THEN 'in_progress' ELSE status END,
      updated_at = now()
  WHERE id = p_walkthrough_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), v_email, 'mark_checkpoint_r1790',
          jsonb_build_object('walkthrough_id', p_walkthrough_id, 'checkpoint', p_checkpoint), now());

  RETURN v_id;
END;
$$;

-- 5. complete_walkthrough
CREATE OR REPLACE FUNCTION public.complete_walkthrough_r1790(
  p_walkthrough_id uuid,
  p_satisfaction_score int,
  p_founder_attended boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_onboarding_walkthroughs_r1790
  SET status = 'completed',
      completed_at = now(),
      satisfaction_score = p_satisfaction_score,
      founder_attended = p_founder_attended,
      updated_at = now()
  WHERE id = p_walkthrough_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_walkthrough_r1790',
          jsonb_build_object('walkthrough_id', p_walkthrough_id,
                             'satisfaction_score', p_satisfaction_score,
                             'founder_attended', p_founder_attended), now());
END;
$$;

-- 6. founder_attendance_summary
CREATE OR REPLACE FUNCTION public.founder_attendance_summary_r1790()
RETURNS TABLE(
  total_walkthroughs int,
  founder_attended_count int,
  attendance_rate_pct numeric,
  avg_satisfaction numeric,
  completed_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE founder_attended))::int,
    CASE WHEN COUNT(*) > 0
      THEN ROUND( (COUNT(*) FILTER (WHERE founder_attended))::numeric * 100.0 / COUNT(*)::numeric, 2)
      ELSE 0::numeric END,
    COALESCE(ROUND(AVG(satisfaction_score)::numeric, 2), 0::numeric),
    (COUNT(*) FILTER (WHERE status = 'completed'))::int
  FROM public.founder_onboarding_walkthroughs_r1790;
END;
$$;

-- 7. in_progress_walkthroughs
CREATE OR REPLACE FUNCTION public.in_progress_walkthroughs_r1790()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  walkthrough_kickoff_date date,
  scheduled_30d_review_at timestamptz,
  scheduled_60d_review_at timestamptz,
  status text,
  days_active int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.hospital_user_id, p.email, w.walkthrough_kickoff_date,
         w.scheduled_30d_review_at, w.scheduled_60d_review_at, w.status,
         (CURRENT_DATE - w.walkthrough_kickoff_date)::int
  FROM public.founder_onboarding_walkthroughs_r1790 w
  LEFT JOIN public.profiles p ON p.id = w.hospital_user_id
  WHERE w.status IN ('scheduled','in_progress')
  ORDER BY w.walkthrough_kickoff_date ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_walkthroughs_r1790() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.schedule_walkthrough_r1790(uuid, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_checkpoints_r1790(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_checkpoint_r1790(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_walkthrough_r1790(uuid, int, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_attendance_summary_r1790() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.in_progress_walkthroughs_r1790() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_walkthroughs_r1790() TO authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_walkthrough_r1790(uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_checkpoints_r1790(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_checkpoint_r1790(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_walkthrough_r1790(uuid, int, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_attendance_summary_r1790() TO authenticated;
GRANT EXECUTE ON FUNCTION public.in_progress_walkthroughs_r1790() TO authenticated;

COMMIT;