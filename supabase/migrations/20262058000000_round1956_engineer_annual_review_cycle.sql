BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_annual_reviews_r1956 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  review_year int NOT NULL,
  overall_score numeric(5,2),
  technical_score int,
  customer_score int,
  teamwork_score int,
  leadership_score int,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','in_progress','completed','disputed','closed')),
  reviewer_email text,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_review_action_log_r1956 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES public.engineer_annual_reviews_r1956(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('goal_set','promotion_recommended','raise_proposed','training_assigned','coaching_required','exit_recommended')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_annual_reviews_r1956 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_review_action_log_r1956 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_reviews_r1956 ON public.engineer_annual_reviews_r1956;
CREATE POLICY founder_all_reviews_r1956 ON public.engineer_annual_reviews_r1956
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r1956 ON public.engineer_review_action_log_r1956;
CREATE POLICY founder_all_actions_r1956 ON public.engineer_review_action_log_r1956
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_reviews_r1956()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  review_year int,
  overall_score numeric,
  status text,
  reviewer_email text,
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
  SELECT r.id, r.engineer_user_id, p.email, r.review_year, r.overall_score,
         r.status, r.reviewer_email, r.completed_at, r.created_at
  FROM public.engineer_annual_reviews_r1956 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY r.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_review_r1956(
  p_engineer_user_id uuid,
  p_review_year int,
  p_overall_score numeric,
  p_technical_score int,
  p_customer_score int,
  p_teamwork_score int,
  p_leadership_score int,
  p_status text,
  p_reviewer_email text
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
  INSERT INTO public.engineer_annual_reviews_r1956(
    engineer_user_id, review_year, overall_score, technical_score,
    customer_score, teamwork_score, leadership_score, status, reviewer_email
  ) VALUES (
    p_engineer_user_id, p_review_year, p_overall_score, p_technical_score,
    p_customer_score, p_teamwork_score, p_leadership_score,
    COALESCE(p_status, 'scheduled'), p_reviewer_email
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_review_r1956',
          jsonb_build_object('review_id', v_id, 'engineer_user_id', p_engineer_user_id, 'year', p_review_year));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1956(p_review_id uuid)
RETURNS TABLE (
  id uuid,
  review_id uuid,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.review_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_review_action_log_r1956 a
  WHERE a.review_id = p_review_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1956(
  p_review_id uuid,
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
  INSERT INTO public.engineer_review_action_log_r1956(review_id, action_type, by_email, notes_md)
  VALUES (p_review_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1956',
          jsonb_build_object('action_id', v_id, 'review_id', p_review_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1956(p_review_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_annual_reviews_r1956
  SET status = p_status,
      completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_review_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1956',
          jsonb_build_object('review_id', p_review_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_reviewers_r1956()
RETURNS TABLE (
  reviewer_email text,
  review_count bigint,
  avg_overall numeric,
  completed_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.reviewer_email,
         count(*)::bigint,
         round(avg(r.overall_score)::numeric, 2),
         count(*) FILTER (WHERE r.status = 'completed')::bigint
  FROM public.engineer_annual_reviews_r1956 r
  WHERE r.reviewer_email IS NOT NULL
  GROUP BY r.reviewer_email
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1956()
RETURNS TABLE (
  id uuid,
  review_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  engineer_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.review_id, a.action_type, a.taken_at, a.by_email, p.email
  FROM public.engineer_review_action_log_r1956 a
  JOIN public.engineer_annual_reviews_r1956 r ON r.id = a.review_id
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reviews_r1956() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_review_r1956(uuid, int, numeric, int, int, int, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1956(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1956(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1956(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_reviewers_r1956() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1956() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reviews_r1956() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_review_r1956(uuid, int, numeric, int, int, int, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1956(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1956(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1956(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_reviewers_r1956() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1956() TO authenticated;

COMMIT;
