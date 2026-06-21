BEGIN;

-- Tables ------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.engineer_innovation_submissions_r1708 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  description_md text NOT NULL,
  category text NOT NULL CHECK (category IN ('workflow','equipment','safety','customer_experience','cost_save')),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','reviewing','accepted','rejected','implemented')),
  decided_at timestamptz,
  reward_rupees int NOT NULL DEFAULT 0,
  implemented_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_innovation_reviews_r1708 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES public.engineer_innovation_submissions_r1708(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  review_md text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('accept','reject','iterate')),
  at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eis_r1708_status ON public.engineer_innovation_submissions_r1708(status);
CREATE INDEX IF NOT EXISTS idx_eis_r1708_engineer ON public.engineer_innovation_submissions_r1708(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eir_r1708_submission ON public.engineer_innovation_reviews_r1708(submission_id);

ALTER TABLE public.engineer_innovation_submissions_r1708 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_innovation_reviews_r1708 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eis_r1708 ON public.engineer_innovation_submissions_r1708;
CREATE POLICY founder_all_eis_r1708 ON public.engineer_innovation_submissions_r1708
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eir_r1708 ON public.engineer_innovation_reviews_r1708;
CREATE POLICY founder_all_eir_r1708 ON public.engineer_innovation_reviews_r1708
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPCs --------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_submissions_r1708()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  title text,
  description_md text,
  category text,
  submitted_at timestamptz,
  status text,
  decided_at timestamptz,
  reward_rupees int,
  implemented_at timestamptz,
  review_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.engineer_user_id,
    p.email AS engineer_email,
    s.title,
    s.description_md,
    s.category,
    s.submitted_at,
    s.status,
    s.decided_at,
    s.reward_rupees,
    s.implemented_at,
    (SELECT (COUNT(*))::int FROM public.engineer_innovation_reviews_r1708 r WHERE r.submission_id = s.id) AS review_count
  FROM public.engineer_innovation_submissions_r1708 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY s.submitted_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_innovation_r1708(
  p_engineer_user_id uuid,
  p_title text,
  p_description_md text,
  p_category text
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
  INSERT INTO public.engineer_innovation_submissions_r1708(engineer_user_id, title, description_md, category)
  VALUES (p_engineer_user_id, p_title, p_description_md, p_category)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'submit_innovation_r1708',
    jsonb_build_object('submission_id', v_id, 'engineer_user_id', p_engineer_user_id, 'category', p_category, 'title', p_title));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_reviews_r1708(p_submission_id uuid)
RETURNS TABLE (
  id uuid,
  submission_id uuid,
  reviewer_email text,
  review_md text,
  decision text,
  at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.submission_id, r.reviewer_email, r.review_md, r.decision, r.at
  FROM public.engineer_innovation_reviews_r1708 r
  WHERE r.submission_id = p_submission_id
  ORDER BY r.at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_review_r1708(
  p_submission_id uuid,
  p_reviewer_email text,
  p_review_md text,
  p_decision text
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
  INSERT INTO public.engineer_innovation_reviews_r1708(submission_id, reviewer_email, review_md, decision)
  VALUES (p_submission_id, p_reviewer_email, p_review_md, p_decision)
  RETURNING id INTO v_id;

  UPDATE public.engineer_innovation_submissions_r1708
  SET status = CASE WHEN status = 'new' THEN 'reviewing' ELSE status END,
      updated_at = now()
  WHERE id = p_submission_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_review_r1708',
    jsonb_build_object('review_id', v_id, 'submission_id', p_submission_id, 'decision', p_decision));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decide_innovation_r1708(
  p_submission_id uuid,
  p_status text,
  p_reward_rupees int DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('accepted','rejected','implemented') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;

  UPDATE public.engineer_innovation_submissions_r1708
  SET status = p_status,
      decided_at = CASE WHEN p_status IN ('accepted','rejected') AND decided_at IS NULL THEN now() ELSE decided_at END,
      implemented_at = CASE WHEN p_status = 'implemented' THEN now() ELSE implemented_at END,
      reward_rupees = COALESCE(NULLIF(p_reward_rupees, 0), reward_rupees),
      updated_at = now()
  WHERE id = p_submission_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'decide_innovation_r1708',
    jsonb_build_object('submission_id', p_submission_id, 'status', p_status, 'reward_rupees', p_reward_rupees));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_contributors_r1708()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  submissions_count int,
  accepted_count int,
  implemented_count int,
  total_reward_rupees int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_user_id,
    p.email AS engineer_email,
    (COUNT(*))::int AS submissions_count,
    (COUNT(*) FILTER (WHERE s.status IN ('accepted','implemented')))::int AS accepted_count,
    (COUNT(*) FILTER (WHERE s.status = 'implemented'))::int AS implemented_count,
    (COALESCE(SUM(s.reward_rupees), 0))::int AS total_reward_rupees
  FROM public.engineer_innovation_submissions_r1708 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  GROUP BY s.engineer_user_id, p.email
  ORDER BY implemented_count DESC, accepted_count DESC, submissions_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.implementation_summary_r1708()
RETURNS TABLE (
  total_submissions int,
  new_count int,
  reviewing_count int,
  accepted_count int,
  rejected_count int,
  implemented_count int,
  total_reward_rupees int,
  implemented_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_submissions,
    (COUNT(*) FILTER (WHERE status = 'new'))::int AS new_count,
    (COUNT(*) FILTER (WHERE status = 'reviewing'))::int AS reviewing_count,
    (COUNT(*) FILTER (WHERE status = 'accepted'))::int AS accepted_count,
    (COUNT(*) FILTER (WHERE status = 'rejected'))::int AS rejected_count,
    (COUNT(*) FILTER (WHERE status = 'implemented'))::int AS implemented_count,
    (COALESCE(SUM(reward_rupees), 0))::int AS total_reward_rupees,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(100.0 * (COUNT(*) FILTER (WHERE status = 'implemented'))::numeric / COUNT(*)::numeric, 1)
    END AS implemented_pct
  FROM public.engineer_innovation_submissions_r1708;
END;
$$;

-- Grants ------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.list_submissions_r1708() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.submit_innovation_r1708(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reviews_r1708(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_review_r1708(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decide_innovation_r1708(uuid, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_contributors_r1708() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.implementation_summary_r1708() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_submissions_r1708() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_innovation_r1708(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reviews_r1708(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_review_r1708(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_innovation_r1708(uuid, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_contributors_r1708() TO authenticated;
GRANT EXECUTE ON FUNCTION public.implementation_summary_r1708() TO authenticated;

COMMIT;