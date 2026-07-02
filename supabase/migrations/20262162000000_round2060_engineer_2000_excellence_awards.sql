BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_2000_excellence_awards_r2060 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  award_category text NOT NULL CHECK (award_category IN ('technical_excellence','customer_champion','teamwork','mentorship','innovation','safety','dedication')),
  award_year int NOT NULL,
  award_label text NOT NULL,
  status text NOT NULL DEFAULT 'nominated' CHECK (status IN ('nominated','awarded','declined','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_award_action_log_r2060 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  award_id uuid NOT NULL REFERENCES public.engineer_2000_excellence_awards_r2060(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('nominated','awarded','announced','bonused','published')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_2000_excellence_awards_r2060 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_award_action_log_r2060 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS r2060_awards_founder ON public.engineer_2000_excellence_awards_r2060;
CREATE POLICY r2060_awards_founder ON public.engineer_2000_excellence_awards_r2060
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS r2060_actions_founder ON public.engineer_award_action_log_r2060;
CREATE POLICY r2060_actions_founder ON public.engineer_award_action_log_r2060
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2060_list_awards()
RETURNS SETOF public.engineer_2000_excellence_awards_r2060
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_2000_excellence_awards_r2060 ORDER BY captured_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2060_log_award(
  p_engineer_user_id uuid,
  p_award_category text,
  p_award_year int,
  p_award_label text,
  p_status text
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
  INSERT INTO public.engineer_2000_excellence_awards_r2060(engineer_user_id, award_category, award_year, award_label, status)
  VALUES (p_engineer_user_id, p_award_category, p_award_year, p_award_label, COALESCE(p_status,'nominated'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2060_log_award', jsonb_build_object('award_id', v_id, 'engineer_user_id', p_engineer_user_id, 'category', p_award_category));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2060_list_actions()
RETURNS SETOF public.engineer_award_action_log_r2060
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_award_action_log_r2060 ORDER BY taken_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2060_log_action(
  p_award_id uuid,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_award_action_log_r2060(award_id, action_type, by_email, notes_md)
  VALUES (p_award_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2060_log_action', jsonb_build_object('action_id', v_id, 'award_id', p_award_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2060_mark_status(
  p_award_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_2000_excellence_awards_r2060 SET status = p_status, updated_at = now() WHERE id = p_award_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2060_mark_status', jsonb_build_object('award_id', p_award_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.r2060_by_category()
RETURNS TABLE(award_category text, total bigint, awarded bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.award_category, COUNT(*)::bigint AS total,
    COUNT(*) FILTER (WHERE a.status = 'awarded')::bigint AS awarded
  FROM public.engineer_2000_excellence_awards_r2060 a
  GROUP BY a.award_category
  ORDER BY total DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2060_recent_actions()
RETURNS SETOF public.engineer_award_action_log_r2060
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_award_action_log_r2060 ORDER BY taken_at DESC LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2060_list_awards() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2060_log_award(uuid, text, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2060_list_actions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2060_log_action(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2060_mark_status(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2060_by_category() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2060_recent_actions() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2060_list_awards() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2060_log_award(uuid, text, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2060_list_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2060_log_action(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2060_mark_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2060_by_category() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2060_recent_actions() TO authenticated;

COMMIT;
