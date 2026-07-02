BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_customer_story_capture_r2088 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  hospital_id uuid REFERENCES public.organizations(id),
  story_title text NOT NULL,
  story_md text NOT NULL,
  story_type text NOT NULL CHECK (story_type IN ('positive','exceptional','heroic','lifesaving','award_worthy')),
  status text NOT NULL DEFAULT 'captured' CHECK (status IN ('captured','shared_internally','published','marketing_use')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_story_share_log_r2088 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id uuid NOT NULL REFERENCES public.engineer_customer_story_capture_r2088(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('shared_team','published_internal','published_external','marketing_use','awards')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_story_capture_r2088 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_story_share_log_r2088 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_stories_r2088 ON public.engineer_customer_story_capture_r2088;
CREATE POLICY founder_all_stories_r2088 ON public.engineer_customer_story_capture_r2088
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_shares_r2088 ON public.engineer_story_share_log_r2088;
CREATE POLICY founder_all_shares_r2088 ON public.engineer_story_share_log_r2088
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_stories_r2088()
RETURNS TABLE (id uuid, engineer_user_id uuid, hospital_id uuid, story_title text, story_type text, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.id, s.engineer_user_id, s.hospital_id, s.story_title, s.story_type, s.status, s.captured_at
    FROM public.engineer_customer_story_capture_r2088 s
    ORDER BY s.captured_at DESC
    LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_story_r2088(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_story_title text,
  p_story_md text,
  p_story_type text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_customer_story_capture_r2088(engineer_user_id, hospital_id, story_title, story_md, story_type)
    VALUES (p_engineer_user_id, p_hospital_id, p_story_title, p_story_md, p_story_type)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_story_r2088', jsonb_build_object('story_id', v_id, 'engineer_user_id', p_engineer_user_id, 'story_type', p_story_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_shares_r2088(p_story_id uuid)
RETURNS TABLE (id uuid, story_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.story_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.engineer_story_share_log_r2088 l
    WHERE l.story_id = p_story_id
    ORDER BY l.taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_share_r2088(
  p_story_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_story_share_log_r2088(story_id, action_type, by_email, notes_md)
    VALUES (p_story_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_share_r2088', jsonb_build_object('share_id', v_id, 'story_id', p_story_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2088(p_story_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_customer_story_capture_r2088
    SET status = p_status, updated_at = now()
    WHERE id = p_story_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2088', jsonb_build_object('story_id', p_story_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.top_stories_r2088()
RETURNS TABLE (story_type text, story_count bigint, published_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.story_type, count(*)::bigint AS story_count,
    count(*) FILTER (WHERE s.status IN ('published','marketing_use'))::bigint AS published_count
    FROM public.engineer_customer_story_capture_r2088 s
    GROUP BY s.story_type
    ORDER BY story_count DESC;
END $$;

CREATE OR REPLACE FUNCTION public.recent_shares_r2088()
RETURNS TABLE (id uuid, story_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.story_id, l.action_type, l.taken_at, l.by_email
    FROM public.engineer_story_share_log_r2088 l
    ORDER BY l.taken_at DESC
    LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_stories_r2088() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_story_r2088(uuid, uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_shares_r2088(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_share_r2088(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2088(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_stories_r2088() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_shares_r2088() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_stories_r2088() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_story_r2088(uuid, uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_shares_r2088(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_share_r2088(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2088(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_stories_r2088() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_shares_r2088() TO authenticated;

COMMIT;
