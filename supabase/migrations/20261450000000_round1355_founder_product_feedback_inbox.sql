BEGIN;
-- r1355 founder product feedback inbox: feature requests + voting + sentiment
-- Captures product signals from engineers, hospital admins, founder team, investors, prospects.
-- Drives roadmap prioritization with vote-weighted demand + sentiment band.



-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_product_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('feature_request','bug_report','ux_friction','pricing_concern','integration_request','compliment','other')),
  submitted_by_kind text CHECK (submitted_by_kind IN ('engineer','hospital_admin','founder_team','investor','prospect','external_user')),
  submitted_by_user_id uuid REFERENCES auth.users(id),
  description text,
  sentiment text CHECK (sentiment IN ('very_positive','positive','neutral','negative','very_negative')),
  priority text DEFAULT 'p2' CHECK (priority IN ('p0','p1','p2','p3')),
  vote_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','triaged','planned','in_progress','shipped','wont_do','duplicate')),
  shipped_round text,
  wont_do_reason text,
  related_surface text,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS founder_product_feedback_status_idx ON public.founder_product_feedback(status);
CREATE INDEX IF NOT EXISTS founder_product_feedback_kind_idx ON public.founder_product_feedback(kind);
CREATE INDEX IF NOT EXISTS founder_product_feedback_votes_desc_idx ON public.founder_product_feedback(vote_count DESC);
CREATE INDEX IF NOT EXISTS founder_product_feedback_created_idx ON public.founder_product_feedback(created_at DESC);

ALTER TABLE public.founder_product_feedback ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.founder_product_feedback_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feedback_id uuid NOT NULL REFERENCES public.founder_product_feedback(id) ON DELETE CASCADE,
  voter_user_id uuid REFERENCES auth.users(id),
  vote_kind text NOT NULL DEFAULT 'upvote' CHECK (vote_kind IN ('upvote','strong_upvote','downvote')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(feedback_id, voter_user_id)
);

CREATE INDEX IF NOT EXISTS founder_product_feedback_votes_feedback_idx ON public.founder_product_feedback_votes(feedback_id);

ALTER TABLE public.founder_product_feedback_votes ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SUMMARY RPC — 16 KPIs
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_product_feedback_summary();
CREATE OR REPLACE FUNCTION public.founder_product_feedback_summary()
RETURNS TABLE (
  total_items bigint,
  open_count bigint,
  triaged_count bigint,
  planned_count bigint,
  in_progress_count bigint,
  shipped_count bigint,
  wont_do_count bigint,
  top_kind text,
  top_kind_count bigint,
  avg_vote_count numeric,
  most_voted_id uuid,
  most_voted_title text,
  most_voted_votes int,
  items_last_30d bigint,
  sentiment_positive_pct numeric,
  oldest_open_age_days int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_product_feedback
  ),
  kind_rank AS (
    SELECT kind, count(*)::bigint AS c
    FROM base
    GROUP BY kind
    ORDER BY count(*) DESC, kind ASC
    LIMIT 1
  ),
  top_voted AS (
    SELECT id, title, vote_count
    FROM base
    WHERE status NOT IN ('shipped','wont_do','duplicate')
    ORDER BY vote_count DESC, created_at DESC
    LIMIT 1
  ),
  sentiment AS (
    SELECT
      count(*) FILTER (WHERE sentiment IN ('positive','very_positive'))::numeric AS pos,
      count(*) FILTER (WHERE sentiment IS NOT NULL)::numeric AS scored
    FROM base
  ),
  oldest AS (
    SELECT EXTRACT(DAY FROM (now() - min(created_at)))::int AS age
    FROM base
    WHERE status = 'open'
  )
  SELECT
    (SELECT count(*) FROM base)::bigint,
    (SELECT count(*) FROM base WHERE status = 'open')::bigint,
    (SELECT count(*) FROM base WHERE status = 'triaged')::bigint,
    (SELECT count(*) FROM base WHERE status = 'planned')::bigint,
    (SELECT count(*) FROM base WHERE status = 'in_progress')::bigint,
    (SELECT count(*) FROM base WHERE status = 'shipped')::bigint,
    (SELECT count(*) FROM base WHERE status = 'wont_do')::bigint,
    (SELECT kind FROM kind_rank),
    COALESCE((SELECT c FROM kind_rank), 0)::bigint,
    COALESCE((SELECT round(avg(vote_count)::numeric, 2) FROM base), 0),
    (SELECT id FROM top_voted),
    (SELECT title FROM top_voted),
    (SELECT vote_count FROM top_voted),
    (SELECT count(*) FROM base WHERE created_at >= now() - interval '30 days')::bigint,
    CASE WHEN (SELECT scored FROM sentiment) > 0
      THEN round(((SELECT pos FROM sentiment) / (SELECT scored FROM sentiment)) * 100, 1)
      ELSE 0 END,
    COALESCE((SELECT age FROM oldest), 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_product_feedback_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_product_feedback_summary() TO authenticated;

-- ============================================================================
-- RECENT LEDGER RPC
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_product_feedback_recent(text, text, int);
CREATE OR REPLACE FUNCTION public.founder_product_feedback_recent(
  p_status text DEFAULT NULL,
  p_kind text DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  title text,
  kind text,
  submitted_by_kind text,
  description text,
  sentiment text,
  priority text,
  vote_count int,
  status text,
  shipped_round text,
  related_surface text,
  created_at timestamptz,
  age_days int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    f.id,
    f.title,
    f.kind,
    f.submitted_by_kind,
    f.description,
    f.sentiment,
    f.priority,
    f.vote_count,
    f.status,
    f.shipped_round,
    f.related_surface,
    f.created_at,
    EXTRACT(DAY FROM (now() - f.created_at))::int AS age_days
  FROM public.founder_product_feedback f
  WHERE (p_status IS NULL OR f.status = p_status)
    AND (p_kind IS NULL OR f.kind = p_kind)
  ORDER BY f.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_product_feedback_recent(text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_product_feedback_recent(text, text, int) TO authenticated;

-- ============================================================================
-- MOST-VOTED RPC
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_product_feedback_most_voted(int);
CREATE OR REPLACE FUNCTION public.founder_product_feedback_most_voted(
  p_limit int DEFAULT 30
)
RETURNS TABLE (
  id uuid,
  title text,
  kind text,
  status text,
  priority text,
  sentiment text,
  vote_count int,
  submitted_by_kind text,
  related_surface text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    f.id,
    f.title,
    f.kind,
    f.status,
    f.priority,
    f.sentiment,
    f.vote_count,
    f.submitted_by_kind,
    f.related_surface,
    f.created_at
  FROM public.founder_product_feedback f
  WHERE f.status NOT IN ('shipped','wont_do','duplicate')
  ORDER BY f.vote_count DESC, f.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 100));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_product_feedback_most_voted(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_product_feedback_most_voted(int) TO authenticated;

-- ============================================================================
-- WRITE: submit feedback
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_product_feedback_submit(text, text, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_product_feedback_submit(
  p_title text,
  p_kind text,
  p_submitted_by_kind text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_sentiment text DEFAULT NULL,
  p_priority text DEFAULT 'p2',
  p_related_surface text DEFAULT NULL
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
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RAISE EXCEPTION 'title required' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.founder_product_feedback(
    title, kind, submitted_by_kind, submitted_by_user_id,
    description, sentiment, priority, related_surface
  ) VALUES (
    trim(p_title), p_kind, p_submitted_by_kind, auth.uid(),
    p_description, p_sentiment, COALESCE(p_priority, 'p2'), p_related_surface
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_product_feedback_submit(text, text, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_product_feedback_submit(text, text, text, text, text, text, text) TO authenticated;

-- ============================================================================
-- WRITE: vote (bumps vote_count atomically)
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_product_feedback_vote(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_product_feedback_vote(
  p_feedback_id uuid,
  p_kind text DEFAULT 'upvote'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_weight int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  v_weight := CASE p_kind
    WHEN 'strong_upvote' THEN 3
    WHEN 'upvote' THEN 1
    WHEN 'downvote' THEN -1
    ELSE 0
  END;

  INSERT INTO public.founder_product_feedback_votes(feedback_id, voter_user_id, vote_kind)
  VALUES (p_feedback_id, auth.uid(), COALESCE(p_kind, 'upvote'))
  ON CONFLICT (feedback_id, voter_user_id) DO UPDATE
    SET vote_kind = EXCLUDED.vote_kind;

  UPDATE public.founder_product_feedback
  SET vote_count = vote_count + v_weight,
      updated_at = now()
  WHERE id = p_feedback_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_product_feedback_vote(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_product_feedback_vote(uuid, text) TO authenticated;

-- ============================================================================
-- WRITE: status transition
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_product_feedback_status(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_product_feedback_status(
  p_id uuid,
  p_new_status text,
  p_reason text DEFAULT NULL,
  p_shipped_round text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  IF p_new_status NOT IN ('open','triaged','planned','in_progress','shipped','wont_do','duplicate') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_product_feedback
  SET status = p_new_status,
      wont_do_reason = CASE WHEN p_new_status = 'wont_do' THEN p_reason ELSE wont_do_reason END,
      shipped_round  = CASE WHEN p_new_status = 'shipped' THEN p_shipped_round ELSE shipped_round END,
      closed_at      = CASE WHEN p_new_status IN ('shipped','wont_do','duplicate') THEN now() ELSE NULL END,
      updated_at     = now()
  WHERE id = p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_product_feedback_status(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_product_feedback_status(uuid, text, text, text) TO authenticated;

COMMIT;