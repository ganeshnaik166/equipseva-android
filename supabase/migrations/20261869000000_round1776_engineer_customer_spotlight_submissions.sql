BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_customer_spotlight_submissions_r1776 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  story_title text NOT NULL,
  story_md text NOT NULL,
  photo_url text,
  video_url text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','under_review','approved','featured','rejected')),
  reward_rupees int NOT NULL DEFAULT 0,
  featured_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_spotlight_reviewer_notes_r1776 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES public.engineer_customer_spotlight_submissions_r1776(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('approve','featured','reject')),
  decision_note text,
  decided_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_spotlight_submissions_r1776 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_spotlight_reviewer_notes_r1776 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_subs_r1776 ON public.engineer_customer_spotlight_submissions_r1776;
CREATE POLICY founder_all_subs_r1776 ON public.engineer_customer_spotlight_submissions_r1776
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_notes_r1776 ON public.engineer_spotlight_reviewer_notes_r1776;
CREATE POLICY founder_all_notes_r1776 ON public.engineer_spotlight_reviewer_notes_r1776
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_spotlight_submissions_r1776()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_user_id uuid,
  hospital_email text,
  story_title text,
  status text,
  reward_rupees int,
  submitted_at timestamptz,
  featured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.engineer_user_id, ep.email, s.hospital_user_id, hp.email,
           s.story_title, s.status, s.reward_rupees, s.submitted_at, s.featured_at
    FROM public.engineer_customer_spotlight_submissions_r1776 s
    LEFT JOIN public.profiles ep ON ep.id = s.engineer_user_id
    LEFT JOIN public.profiles hp ON hp.id = s.hospital_user_id
    ORDER BY s.submitted_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_spotlight_r1776(
  p_engineer_user_id uuid,
  p_hospital_user_id uuid,
  p_title text,
  p_story_md text,
  p_photo_url text,
  p_video_url text
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
  INSERT INTO public.engineer_customer_spotlight_submissions_r1776(
    engineer_user_id, hospital_user_id, story_title, story_md, photo_url, video_url
  ) VALUES (p_engineer_user_id, p_hospital_user_id, p_title, p_story_md, p_photo_url, p_video_url)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'submit_spotlight_r1776',
          jsonb_build_object('submission_id', v_id, 'engineer_user_id', p_engineer_user_id, 'title', p_title));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_spotlight_reviewer_notes_r1776(p_submission_id uuid)
RETURNS TABLE(
  id uuid,
  submission_id uuid,
  reviewer_email text,
  decision text,
  decision_note text,
  decided_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT n.id, n.submission_id, n.reviewer_email, n.decision, n.decision_note, n.decided_at
    FROM public.engineer_spotlight_reviewer_notes_r1776 n
    WHERE n.submission_id = p_submission_id
    ORDER BY n.decided_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_spotlight_review_r1776(
  p_submission_id uuid,
  p_reviewer_email text,
  p_decision text,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_new_status text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_spotlight_reviewer_notes_r1776(submission_id, reviewer_email, decision, decision_note)
  VALUES (p_submission_id, p_reviewer_email, p_decision, p_note)
  RETURNING id INTO v_id;

  v_new_status := CASE p_decision
    WHEN 'approve' THEN 'approved'
    WHEN 'featured' THEN 'featured'
    WHEN 'reject' THEN 'rejected'
    ELSE 'under_review'
  END;

  UPDATE public.engineer_customer_spotlight_submissions_r1776
  SET status = v_new_status,
      featured_at = CASE WHEN p_decision = 'featured' THEN now() ELSE featured_at END,
      updated_at = now()
  WHERE id = p_submission_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_spotlight_review_r1776',
          jsonb_build_object('submission_id', p_submission_id, 'decision', p_decision));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.feature_spotlight_submission_r1776(
  p_submission_id uuid,
  p_reward_rupees int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_customer_spotlight_submissions_r1776
  SET status = 'featured',
      featured_at = now(),
      reward_rupees = COALESCE(p_reward_rupees, reward_rupees),
      updated_at = now()
  WHERE id = p_submission_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'feature_spotlight_submission_r1776',
          jsonb_build_object('submission_id', p_submission_id, 'reward_rupees', p_reward_rupees));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_contributing_engineers_r1776()
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  total_submissions int,
  featured_count int,
  total_reward_rupees int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.engineer_user_id,
           p.email,
           COUNT(*)::int,
           (COUNT(*) FILTER (WHERE s.status = 'featured'))::int,
           COALESCE(SUM(s.reward_rupees), 0)::int
    FROM public.engineer_customer_spotlight_submissions_r1776 s
    LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
    GROUP BY s.engineer_user_id, p.email
    ORDER BY COUNT(*) DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_featured_stories_r1776()
RETURNS TABLE(
  id uuid,
  story_title text,
  engineer_email text,
  hospital_email text,
  reward_rupees int,
  featured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.story_title, ep.email, hp.email, s.reward_rupees, s.featured_at
    FROM public.engineer_customer_spotlight_submissions_r1776 s
    LEFT JOIN public.profiles ep ON ep.id = s.engineer_user_id
    LEFT JOIN public.profiles hp ON hp.id = s.hospital_user_id
    WHERE s.status = 'featured'
    ORDER BY s.featured_at DESC NULLS LAST
    LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_spotlight_submissions_r1776() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.submit_spotlight_r1776(uuid, uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_spotlight_reviewer_notes_r1776(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_spotlight_review_r1776(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.feature_spotlight_submission_r1776(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_contributing_engineers_r1776() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_featured_stories_r1776() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_spotlight_submissions_r1776() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_spotlight_r1776(uuid, uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_spotlight_reviewer_notes_r1776(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_spotlight_review_r1776(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.feature_spotlight_submission_r1776(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_contributing_engineers_r1776() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_featured_stories_r1776() TO authenticated;

COMMIT;