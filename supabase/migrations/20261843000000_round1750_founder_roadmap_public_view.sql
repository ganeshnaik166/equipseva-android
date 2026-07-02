BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_public_roadmap_r1750 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_title text NOT NULL,
  category text NOT NULL CHECK (category IN ('shipped','in_progress','planned','exploring')),
  target_quarter text,
  description_md text,
  vote_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'live' CHECK (status IN ('live','hidden')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_roadmap_subscriber_votes_r1750 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  roadmap_id uuid NOT NULL REFERENCES public.founder_public_roadmap_r1750(id) ON DELETE CASCADE,
  subscriber_email text NOT NULL,
  voted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (roadmap_id, subscriber_email)
);

ALTER TABLE public.founder_public_roadmap_r1750 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_roadmap_subscriber_votes_r1750 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_roadmap_r1750 ON public.founder_public_roadmap_r1750;
CREATE POLICY founder_all_roadmap_r1750 ON public.founder_public_roadmap_r1750
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_roadmap_votes_r1750 ON public.founder_roadmap_subscriber_votes_r1750;
CREATE POLICY founder_all_roadmap_votes_r1750 ON public.founder_roadmap_subscriber_votes_r1750
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_roadmap_r1750_category ON public.founder_public_roadmap_r1750(category);
CREATE INDEX IF NOT EXISTS idx_roadmap_r1750_status ON public.founder_public_roadmap_r1750(status);
CREATE INDEX IF NOT EXISTS idx_roadmap_votes_r1750_roadmap ON public.founder_roadmap_subscriber_votes_r1750(roadmap_id);

-- RPC 1: list_roadmap
DROP FUNCTION IF EXISTS public.list_roadmap_r1750();
CREATE OR REPLACE FUNCTION public.list_roadmap_r1750()
RETURNS TABLE (
  id uuid,
  item_title text,
  category text,
  target_quarter text,
  description_md text,
  vote_count int,
  status text,
  created_at timestamptz
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
    SELECT r.id, r.item_title, r.category, r.target_quarter, r.description_md, r.vote_count, r.status, r.created_at
    FROM public.founder_public_roadmap_r1750 r
    ORDER BY r.vote_count DESC, r.created_at DESC;
END;
$$;

-- RPC 2: add_item
DROP FUNCTION IF EXISTS public.add_item_r1750(text, text, text, text);
CREATE OR REPLACE FUNCTION public.add_item_r1750(
  p_item_title text,
  p_category text,
  p_target_quarter text,
  p_description_md text
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
  INSERT INTO public.founder_public_roadmap_r1750(item_title, category, target_quarter, description_md)
  VALUES (p_item_title, p_category, p_target_quarter, p_description_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_item_r1750',
    jsonb_build_object('id', v_id, 'item_title', p_item_title, 'category', p_category));
  RETURN v_id;
END;
$$;

-- RPC 3: list_votes
DROP FUNCTION IF EXISTS public.list_votes_r1750(uuid);
CREATE OR REPLACE FUNCTION public.list_votes_r1750(p_roadmap_id uuid)
RETURNS TABLE (
  id uuid,
  roadmap_id uuid,
  subscriber_email text,
  voted_at timestamptz
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
    SELECT v.id, v.roadmap_id, v.subscriber_email, v.voted_at
    FROM public.founder_roadmap_subscriber_votes_r1750 v
    WHERE v.roadmap_id = p_roadmap_id
    ORDER BY v.voted_at DESC;
END;
$$;

-- RPC 4: add_vote
DROP FUNCTION IF EXISTS public.add_vote_r1750(uuid, text);
CREATE OR REPLACE FUNCTION public.add_vote_r1750(p_roadmap_id uuid, p_subscriber_email text)
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
  INSERT INTO public.founder_roadmap_subscriber_votes_r1750(roadmap_id, subscriber_email)
  VALUES (p_roadmap_id, p_subscriber_email)
  ON CONFLICT (roadmap_id, subscriber_email) DO NOTHING
  RETURNING id INTO v_id;

  UPDATE public.founder_public_roadmap_r1750
  SET vote_count = (
    SELECT COUNT(*)::int FROM public.founder_roadmap_subscriber_votes_r1750 WHERE roadmap_id = p_roadmap_id
  ),
  updated_at = now()
  WHERE id = p_roadmap_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_vote_r1750',
    jsonb_build_object('roadmap_id', p_roadmap_id, 'subscriber_email', p_subscriber_email));
  RETURN v_id;
END;
$$;

-- RPC 5: update_status
DROP FUNCTION IF EXISTS public.update_status_r1750(uuid, text);
CREATE OR REPLACE FUNCTION public.update_status_r1750(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_public_roadmap_r1750
  SET status = p_status, updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_status_r1750',
    jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

-- RPC 6: top_voted_items
DROP FUNCTION IF EXISTS public.top_voted_items_r1750(int);
CREATE OR REPLACE FUNCTION public.top_voted_items_r1750(p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  item_title text,
  category text,
  vote_count int,
  target_quarter text
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
    SELECT r.id, r.item_title, r.category, r.vote_count, r.target_quarter
    FROM public.founder_public_roadmap_r1750 r
    WHERE r.status = 'live'
    ORDER BY r.vote_count DESC, r.created_at DESC
    LIMIT p_limit;
END;
$$;

-- RPC 7: public_roadmap_summary
DROP FUNCTION IF EXISTS public.public_roadmap_summary_r1750();
CREATE OR REPLACE FUNCTION public.public_roadmap_summary_r1750()
RETURNS TABLE (
  category text,
  item_count int,
  total_votes int
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
    SELECT r.category,
           (COUNT(*))::int AS item_count,
           (COALESCE(SUM(r.vote_count),0))::int AS total_votes
    FROM public.founder_public_roadmap_r1750 r
    WHERE r.status = 'live'
    GROUP BY r.category
    ORDER BY r.category;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_roadmap_r1750() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_item_r1750(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_votes_r1750(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_vote_r1750(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_status_r1750(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_voted_items_r1750(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.public_roadmap_summary_r1750() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_roadmap_r1750() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_item_r1750(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_votes_r1750(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_vote_r1750(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_status_r1750(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_voted_items_r1750(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.public_roadmap_summary_r1750() TO authenticated;

COMMIT;