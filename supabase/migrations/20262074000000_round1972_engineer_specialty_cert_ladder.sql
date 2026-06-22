BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_specialty_cert_ladders_r1972 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  specialty text NOT NULL CHECK (specialty IN ('imaging','ventilator','anesthesia','lab','monitor','multi_modality')),
  current_tier text NOT NULL CHECK (current_tier IN ('basic','intermediate','advanced','expert','master')),
  target_tier text NOT NULL CHECK (target_tier IN ('basic','intermediate','advanced','expert','master')),
  target_completion_date date,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','blocked','completed','abandoned')),
  last_assessment_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_specialty_milestone_log_r1972 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ladder_id uuid NOT NULL REFERENCES public.engineer_specialty_cert_ladders_r1972(id) ON DELETE CASCADE,
  milestone_type text NOT NULL CHECK (milestone_type IN ('assessment','practical','cert_passed','upgrade_to_next_tier','blocked')),
  milestone_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  score int,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_specialty_cert_ladders_r1972 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_specialty_milestone_log_r1972 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ladders_r1972 ON public.engineer_specialty_cert_ladders_r1972;
CREATE POLICY founder_all_ladders_r1972 ON public.engineer_specialty_cert_ladders_r1972
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_milestones_r1972 ON public.engineer_specialty_milestone_log_r1972;
CREATE POLICY founder_all_milestones_r1972 ON public.engineer_specialty_milestone_log_r1972
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_ladders_r1972_engineer ON public.engineer_specialty_cert_ladders_r1972(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ladders_r1972_status ON public.engineer_specialty_cert_ladders_r1972(status);
CREATE INDEX IF NOT EXISTS idx_milestones_r1972_ladder ON public.engineer_specialty_milestone_log_r1972(ladder_id);

-- 1. list_ladders
CREATE OR REPLACE FUNCTION public.list_specialty_ladders_r1972()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  specialty text,
  current_tier text,
  target_tier text,
  target_completion_date date,
  status text,
  last_assessment_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.engineer_user_id, l.specialty, l.current_tier, l.target_tier,
           l.target_completion_date, l.status, l.last_assessment_at, l.created_at
    FROM public.engineer_specialty_cert_ladders_r1972 l
    ORDER BY l.created_at DESC
    LIMIT 200;
END; $$;

-- 2. log_ladder
CREATE OR REPLACE FUNCTION public.log_specialty_ladder_r1972(
  p_engineer_user_id uuid,
  p_specialty text,
  p_current_tier text,
  p_target_tier text,
  p_target_completion_date date,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_specialty_cert_ladders_r1972(
    engineer_user_id, specialty, current_tier, target_tier, target_completion_date, status
  ) VALUES (p_engineer_user_id, p_specialty, p_current_tier, p_target_tier, p_target_completion_date, COALESCE(p_status,'planned'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_specialty_ladder_r1972',
      jsonb_build_object('ladder_id', v_id, 'engineer_user_id', p_engineer_user_id, 'specialty', p_specialty));
  RETURN v_id;
END; $$;

-- 3. list_milestones
CREATE OR REPLACE FUNCTION public.list_specialty_milestones_r1972(p_ladder_id uuid)
RETURNS TABLE (
  id uuid,
  ladder_id uuid,
  milestone_type text,
  milestone_at timestamptz,
  by_email text,
  score int,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.ladder_id, m.milestone_type, m.milestone_at, m.by_email, m.score, m.notes_md
    FROM public.engineer_specialty_milestone_log_r1972 m
    WHERE m.ladder_id = p_ladder_id
    ORDER BY m.milestone_at DESC
    LIMIT 200;
END; $$;

-- 4. log_milestone
CREATE OR REPLACE FUNCTION public.log_specialty_milestone_r1972(
  p_ladder_id uuid,
  p_milestone_type text,
  p_by_email text,
  p_score int,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_specialty_milestone_log_r1972(
    ladder_id, milestone_type, by_email, score, notes_md
  ) VALUES (p_ladder_id, p_milestone_type, p_by_email, p_score, p_notes_md)
  RETURNING id INTO v_id;
  UPDATE public.engineer_specialty_cert_ladders_r1972
    SET last_assessment_at = now(), updated_at = now()
    WHERE id = p_ladder_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_specialty_milestone_r1972',
      jsonb_build_object('milestone_id', v_id, 'ladder_id', p_ladder_id, 'type', p_milestone_type));
  RETURN v_id;
END; $$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_specialty_ladder_status_r1972(p_ladder_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_specialty_cert_ladders_r1972
    SET status = p_status, updated_at = now()
    WHERE id = p_ladder_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_specialty_ladder_status_r1972',
      jsonb_build_object('ladder_id', p_ladder_id, 'status', p_status));
END; $$;

-- 6. engineers_at_tier
CREATE OR REPLACE FUNCTION public.specialty_engineers_at_tier_r1972()
RETURNS TABLE (
  current_tier text,
  specialty text,
  engineer_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.current_tier, l.specialty, COUNT(DISTINCT l.engineer_user_id)::bigint AS engineer_count
    FROM public.engineer_specialty_cert_ladders_r1972 l
    GROUP BY l.current_tier, l.specialty
    ORDER BY l.current_tier, l.specialty;
END; $$;

-- 7. recent_milestones
CREATE OR REPLACE FUNCTION public.specialty_recent_milestones_r1972()
RETURNS TABLE (
  id uuid,
  ladder_id uuid,
  milestone_type text,
  milestone_at timestamptz,
  by_email text,
  score int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.ladder_id, m.milestone_type, m.milestone_at, m.by_email, m.score
    FROM public.engineer_specialty_milestone_log_r1972 m
    ORDER BY m.milestone_at DESC
    LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_specialty_ladders_r1972() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_specialty_ladder_r1972(uuid, text, text, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_specialty_milestones_r1972(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_specialty_milestone_r1972(uuid, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_specialty_ladder_status_r1972(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.specialty_engineers_at_tier_r1972() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.specialty_recent_milestones_r1972() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_specialty_ladders_r1972() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_specialty_ladder_r1972(uuid, text, text, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_specialty_milestones_r1972(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_specialty_milestone_r1972(uuid, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_specialty_ladder_status_r1972(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.specialty_engineers_at_tier_r1972() TO authenticated;
GRANT EXECUTE ON FUNCTION public.specialty_recent_milestones_r1972() TO authenticated;

COMMIT;
