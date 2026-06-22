BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_2200_milestone_awards_r2180 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  award_label text NOT NULL,
  award_category text NOT NULL CHECK (award_category IN ('1000_jobs','2000_jobs','5_year_tenure','master_certified','customer_champion','safety_leader')),
  awarded_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','awarded','celebrated','promoted')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_award_action_log_r2180 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  award_id uuid NOT NULL REFERENCES public.engineer_2200_milestone_awards_r2180(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('nominated','awarded','announced','bonused','promoted')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_2200_milestone_awards_r2180 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_award_action_log_r2180 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_awards_r2180 ON public.engineer_2200_milestone_awards_r2180;
CREATE POLICY founder_all_awards_r2180 ON public.engineer_2200_milestone_awards_r2180
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2180 ON public.engineer_award_action_log_r2180;
CREATE POLICY founder_all_actions_r2180 ON public.engineer_award_action_log_r2180
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_awards_r2180()
RETURNS TABLE(id uuid, engineer_user_id uuid, award_label text, award_category text, awarded_at timestamptz, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.engineer_user_id, a.award_label, a.award_category, a.awarded_at, a.status, a.captured_at
    FROM public.engineer_2200_milestone_awards_r2180 a ORDER BY a.awarded_at DESC LIMIT 500;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_awards_r2180() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_awards_r2180() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_award_r2180(p_engineer_user_id uuid, p_award_label text, p_award_category text, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_2200_milestone_awards_r2180(engineer_user_id, award_label, award_category, status)
    VALUES (p_engineer_user_id, p_award_label, p_award_category, COALESCE(p_status,'pending')) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_award_r2180', jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'label', p_award_label));
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION public.log_award_r2180(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_award_r2180(uuid, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2180()
RETURNS TABLE(id uuid, award_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.award_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.engineer_award_action_log_r2180 l ORDER BY l.taken_at DESC LIMIT 500;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2180() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2180() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_action_r2180(p_award_id uuid, p_action_type text, p_by_email text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_award_action_log_r2180(award_id, action_type, by_email, notes_md)
    VALUES (p_award_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2180', jsonb_build_object('id', v_id, 'award_id', p_award_id, 'action', p_action_type));
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2180(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2180(uuid, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_status_r2180(p_award_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_2200_milestone_awards_r2180 SET status = p_status, updated_at = now() WHERE id = p_award_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2180', jsonb_build_object('id', p_award_id, 'status', p_status));
END; $$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2180(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2180(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_awards_r2180()
RETURNS TABLE(id uuid, engineer_user_id uuid, award_label text, award_category text, awarded_at timestamptz, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.engineer_user_id, a.award_label, a.award_category, a.awarded_at, a.status
    FROM public.engineer_2200_milestone_awards_r2180 a WHERE a.awarded_at >= now() - interval '90 days' ORDER BY a.awarded_at DESC LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION public.recent_awards_r2180() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_awards_r2180() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_actions_r2180()
RETURNS TABLE(id uuid, award_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.award_id, l.action_type, l.taken_at, l.by_email
    FROM public.engineer_award_action_log_r2180 l WHERE l.taken_at >= now() - interval '90 days' ORDER BY l.taken_at DESC LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2180() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2180() TO authenticated;

COMMIT;
