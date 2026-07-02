BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_customer_wishlist_r1730 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_title text NOT NULL,
  source text NOT NULL CHECK (source IN ('call','email','visit','survey','support_ticket')),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  importance text NOT NULL CHECK (importance IN ('critical','important','nice_to_have')),
  status text NOT NULL DEFAULT 'captured' CHECK (status IN ('captured','triaged','in_roadmap','built','declined')),
  votes_count int NOT NULL DEFAULT 0,
  captured_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_customer_wishlist_votes_r1730 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wishlist_id uuid NOT NULL REFERENCES public.founder_customer_wishlist_r1730(id) ON DELETE CASCADE,
  voter_email text NOT NULL,
  voter_role text NOT NULL CHECK (voter_role IN ('engineer','hospital','founder')),
  voted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_customer_wishlist_r1730 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_customer_wishlist_votes_r1730 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_wishlist_r1730 ON public.founder_customer_wishlist_r1730;
CREATE POLICY founder_only_wishlist_r1730 ON public.founder_customer_wishlist_r1730
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_wishlist_votes_r1730 ON public.founder_customer_wishlist_votes_r1730;
CREATE POLICY founder_only_wishlist_votes_r1730 ON public.founder_customer_wishlist_votes_r1730
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1) list_wishlist
CREATE OR REPLACE FUNCTION public.list_wishlist_r1730()
RETURNS TABLE (
  id uuid,
  request_title text,
  source text,
  hospital_user_id uuid,
  importance text,
  status text,
  votes_count int,
  captured_by_email text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.request_title, w.source, w.hospital_user_id, w.importance, w.status, w.votes_count, w.captured_by_email, w.created_at
  FROM public.founder_customer_wishlist_r1730 w
  ORDER BY w.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_wishlist_r1730() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_wishlist_r1730() TO authenticated;

-- 2) capture_request
CREATE OR REPLACE FUNCTION public.capture_request_r1730(
  p_request_title text,
  p_source text,
  p_hospital_user_id uuid,
  p_importance text
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
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_customer_wishlist_r1730 (request_title, source, hospital_user_id, importance, captured_by_email)
  VALUES (p_request_title, p_source, p_hospital_user_id, p_importance, v_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'capture_request_r1730',
    jsonb_build_object('id', v_id, 'request_title', p_request_title, 'source', p_source, 'importance', p_importance));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.capture_request_r1730(text, text, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.capture_request_r1730(text, text, uuid, text) TO authenticated;

-- 3) list_votes
CREATE OR REPLACE FUNCTION public.list_votes_r1730(p_wishlist_id uuid)
RETURNS TABLE (
  id uuid,
  wishlist_id uuid,
  voter_email text,
  voter_role text,
  voted_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.wishlist_id, v.voter_email, v.voter_role, v.voted_at
  FROM public.founder_customer_wishlist_votes_r1730 v
  WHERE v.wishlist_id = p_wishlist_id
  ORDER BY v.voted_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_votes_r1730(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_votes_r1730(uuid) TO authenticated;

-- 4) add_vote
CREATE OR REPLACE FUNCTION public.add_vote_r1730(
  p_wishlist_id uuid,
  p_voter_email text,
  p_voter_role text
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
  INSERT INTO public.founder_customer_wishlist_votes_r1730 (wishlist_id, voter_email, voter_role)
  VALUES (p_wishlist_id, p_voter_email, p_voter_role)
  RETURNING id INTO v_id;

  UPDATE public.founder_customer_wishlist_r1730
  SET votes_count = votes_count + 1, updated_at = now()
  WHERE id = p_wishlist_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_vote_r1730',
    jsonb_build_object('vote_id', v_id, 'wishlist_id', p_wishlist_id, 'voter_email', p_voter_email, 'voter_role', p_voter_role));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.add_vote_r1730(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_vote_r1730(uuid, text, text) TO authenticated;

-- 5) update_status
CREATE OR REPLACE FUNCTION public.update_status_r1730(
  p_wishlist_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_customer_wishlist_r1730
  SET status = p_status, updated_at = now()
  WHERE id = p_wishlist_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_status_r1730',
    jsonb_build_object('wishlist_id', p_wishlist_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.update_status_r1730(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_status_r1730(uuid, text) TO authenticated;

-- 6) top_voted_requests
CREATE OR REPLACE FUNCTION public.top_voted_requests_r1730()
RETURNS TABLE (
  id uuid,
  request_title text,
  importance text,
  status text,
  votes_count int,
  source text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.request_title, w.importance, w.status, w.votes_count, w.source
  FROM public.founder_customer_wishlist_r1730 w
  ORDER BY w.votes_count DESC, w.created_at DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_voted_requests_r1730() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_voted_requests_r1730() TO authenticated;

-- 7) recent_capture_summary
CREATE OR REPLACE FUNCTION public.recent_capture_summary_r1730()
RETURNS TABLE (
  total_requests int,
  critical_count int,
  in_roadmap_count int,
  built_count int,
  declined_count int,
  last_7d_count int,
  total_votes int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_requests,
    (COUNT(*) FILTER (WHERE w.importance = 'critical'))::int AS critical_count,
    (COUNT(*) FILTER (WHERE w.status = 'in_roadmap'))::int AS in_roadmap_count,
    (COUNT(*) FILTER (WHERE w.status = 'built'))::int AS built_count,
    (COUNT(*) FILTER (WHERE w.status = 'declined'))::int AS declined_count,
    (COUNT(*) FILTER (WHERE w.created_at >= now() - interval '7 days'))::int AS last_7d_count,
    (COALESCE(SUM(w.votes_count), 0))::int AS total_votes
  FROM public.founder_customer_wishlist_r1730 w;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_capture_summary_r1730() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_capture_summary_r1730() TO authenticated;

COMMIT;