-- round2100 — Engineer 2100-Series Mastery Badges
BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_2100_mastery_badges_r2100 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  badge_label text NOT NULL,
  badge_category text NOT NULL CHECK (badge_category IN ('technical_mastery','customer_master','safety_champion','teamwork_leader','innovation_pioneer','long_tenure')),
  awarded_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'earned' CHECK (status IN ('earned','displayed','retired')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_badge_action_log_r2100 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  badge_id uuid NOT NULL REFERENCES public.engineer_2100_mastery_badges_r2100(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('awarded','published','featured','upgraded','retired')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_2100_mastery_badges_r2100 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_badge_action_log_r2100 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_badges_r2100 ON public.engineer_2100_mastery_badges_r2100;
CREATE POLICY founder_all_badges_r2100 ON public.engineer_2100_mastery_badges_r2100
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2100 ON public.engineer_badge_action_log_r2100;
CREATE POLICY founder_all_actions_r2100 ON public.engineer_badge_action_log_r2100
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- list_badges
DROP FUNCTION IF EXISTS public.r2100_list_badges();
CREATE OR REPLACE FUNCTION public.r2100_list_badges()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  badge_label text,
  badge_category text,
  awarded_at timestamptz,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.engineer_user_id, b.badge_label, b.badge_category, b.awarded_at, b.status, b.captured_at
  FROM public.engineer_2100_mastery_badges_r2100 b
  ORDER BY b.awarded_at DESC
  LIMIT 200;
END;
$$;

-- log_badge
DROP FUNCTION IF EXISTS public.r2100_log_badge(uuid, text, text);
CREATE OR REPLACE FUNCTION public.r2100_log_badge(
  p_engineer_user_id uuid,
  p_badge_label text,
  p_badge_category text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_2100_mastery_badges_r2100 (engineer_user_id, badge_label, badge_category)
  VALUES (p_engineer_user_id, p_badge_label, p_badge_category)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2100_log_badge',
    jsonb_build_object('badge_id', v_id, 'engineer_user_id', p_engineer_user_id, 'category', p_badge_category));
  RETURN v_id;
END;
$$;

-- list_actions
DROP FUNCTION IF EXISTS public.r2100_list_actions();
CREATE OR REPLACE FUNCTION public.r2100_list_actions()
RETURNS TABLE (
  id uuid,
  badge_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.badge_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_badge_action_log_r2100 a
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- log_action
DROP FUNCTION IF EXISTS public.r2100_log_action(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.r2100_log_action(
  p_badge_id uuid,
  p_action_type text,
  p_by_email text,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_badge_action_log_r2100 (badge_id, action_type, by_email, notes_md)
  VALUES (p_badge_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2100_log_action',
    jsonb_build_object('action_id', v_id, 'badge_id', p_badge_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- mark_status
DROP FUNCTION IF EXISTS public.r2100_mark_status(uuid, text);
CREATE OR REPLACE FUNCTION public.r2100_mark_status(
  p_badge_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_2100_mastery_badges_r2100
  SET status = p_status, updated_at = now()
  WHERE id = p_badge_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2100_mark_status',
    jsonb_build_object('badge_id', p_badge_id, 'status', p_status));
END;
$$;

-- by_category
DROP FUNCTION IF EXISTS public.r2100_by_category(text);
CREATE OR REPLACE FUNCTION public.r2100_by_category(p_category text)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  badge_label text,
  badge_category text,
  awarded_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.engineer_user_id, b.badge_label, b.badge_category, b.awarded_at, b.status
  FROM public.engineer_2100_mastery_badges_r2100 b
  WHERE b.badge_category = p_category
  ORDER BY b.awarded_at DESC
  LIMIT 200;
END;
$$;

-- recent_actions
DROP FUNCTION IF EXISTS public.r2100_recent_actions(int);
CREATE OR REPLACE FUNCTION public.r2100_recent_actions(p_days int)
RETURNS TABLE (
  id uuid,
  badge_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.badge_id, a.action_type, a.taken_at, a.by_email
  FROM public.engineer_badge_action_log_r2100 a
  WHERE a.taken_at >= now() - make_interval(days => COALESCE(p_days, 30))
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2100_list_badges() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2100_log_badge(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2100_list_actions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2100_log_action(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2100_mark_status(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2100_by_category(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2100_recent_actions(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2100_list_badges() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2100_log_badge(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2100_list_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2100_log_action(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2100_mark_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2100_by_category(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2100_recent_actions(int) TO authenticated;

COMMIT;
