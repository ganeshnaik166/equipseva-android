BEGIN;

-- Round 2230: Founder 1400 SHIPS milestone memo
-- Tracks founder reflection memos at the 1400 ships milestone, top lessons learned,
-- next-phase plans, plus reaction log from team/investors/customers.

CREATE TABLE IF NOT EXISTS public.founder_1400_ships_memos_r2230 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_title text NOT NULL,
  ship_count_at_memo int NOT NULL DEFAULT 1400,
  milestone_date date NOT NULL DEFAULT CURRENT_DATE,
  founder_reflection text NOT NULL,
  top_lessons jsonb NOT NULL DEFAULT '[]'::jsonb,
  next_phase_plan text NOT NULL,
  what_worked text,
  what_failed text,
  proudest_ship text,
  biggest_regret text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  published_at timestamptz,
  authored_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_1400_ships_reactions_r2230 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id uuid NOT NULL REFERENCES public.founder_1400_ships_memos_r2230(id) ON DELETE CASCADE,
  reactor_name text NOT NULL,
  reactor_type text NOT NULL CHECK (reactor_type IN ('team','investor','customer','engineer','hospital','press','other')),
  reactor_email text,
  reaction_text text NOT NULL,
  sentiment text NOT NULL DEFAULT 'positive' CHECK (sentiment IN ('positive','neutral','negative','mixed')),
  shared_publicly boolean NOT NULL DEFAULT false,
  received_at timestamptz NOT NULL DEFAULT now(),
  logged_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_f1400_memos_status_r2230
  ON public.founder_1400_ships_memos_r2230(status, milestone_date DESC);

CREATE INDEX IF NOT EXISTS idx_f1400_reactions_memo_r2230
  ON public.founder_1400_ships_reactions_r2230(memo_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_f1400_reactions_type_r2230
  ON public.founder_1400_ships_reactions_r2230(reactor_type, sentiment);

ALTER TABLE public.founder_1400_ships_memos_r2230 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_1400_ships_reactions_r2230 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_1400_ships_memos_r2230;
CREATE POLICY founder_all ON public.founder_1400_ships_memos_r2230
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_1400_ships_reactions_r2230;
CREATE POLICY founder_all ON public.founder_1400_ships_reactions_r2230
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list memos
CREATE OR REPLACE FUNCTION public.founder_1400_list_memos_r2230()
RETURNS TABLE (
  id uuid,
  memo_title text,
  ship_count_at_memo int,
  milestone_date date,
  status text,
  published_at timestamptz,
  reaction_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.memo_title, m.ship_count_at_memo, m.milestone_date,
           m.status, m.published_at,
           (SELECT COUNT(*) FROM public.founder_1400_ships_reactions_r2230 r WHERE r.memo_id = m.id)::int,
           m.created_at
    FROM public.founder_1400_ships_memos_r2230 m
    ORDER BY m.milestone_date DESC, m.created_at DESC
    LIMIT 200;
END;
$$;

-- RPC 2: list reactions
CREATE OR REPLACE FUNCTION public.founder_1400_list_reactions_r2230()
RETURNS TABLE (
  id uuid,
  memo_title text,
  reactor_name text,
  reactor_type text,
  sentiment text,
  reaction_text text,
  shared_publicly boolean,
  received_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, m.memo_title, r.reactor_name, r.reactor_type,
           r.sentiment, r.reaction_text, r.shared_publicly, r.received_at
    FROM public.founder_1400_ships_reactions_r2230 r
    JOIN public.founder_1400_ships_memos_r2230 m ON m.id = r.memo_id
    ORDER BY r.received_at DESC
    LIMIT 500;
END;
$$;

-- RPC 3: summary
CREATE OR REPLACE FUNCTION public.founder_1400_summary_r2230()
RETURNS TABLE (
  total_memos int,
  published_memos int,
  draft_memos int,
  total_reactions int,
  positive_reactions int,
  negative_reactions int,
  team_reactions int,
  investor_reactions int,
  customer_reactions int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*) FROM public.founder_1400_ships_memos_r2230)::int,
      (SELECT COUNT(*) FILTER (WHERE status = 'published') FROM public.founder_1400_ships_memos_r2230)::int,
      (SELECT COUNT(*) FILTER (WHERE status = 'draft') FROM public.founder_1400_ships_memos_r2230)::int,
      (SELECT COUNT(*) FROM public.founder_1400_ships_reactions_r2230)::int,
      (SELECT COUNT(*) FILTER (WHERE sentiment = 'positive') FROM public.founder_1400_ships_reactions_r2230)::int,
      (SELECT COUNT(*) FILTER (WHERE sentiment = 'negative') FROM public.founder_1400_ships_reactions_r2230)::int,
      (SELECT COUNT(*) FILTER (WHERE reactor_type = 'team') FROM public.founder_1400_ships_reactions_r2230)::int,
      (SELECT COUNT(*) FILTER (WHERE reactor_type = 'investor') FROM public.founder_1400_ships_reactions_r2230)::int,
      (SELECT COUNT(*) FILTER (WHERE reactor_type = 'customer') FROM public.founder_1400_ships_reactions_r2230)::int;
END;
$$;

-- RPC 4: create memo
CREATE OR REPLACE FUNCTION public.founder_1400_create_memo_r2230(
  p_title text,
  p_reflection text,
  p_next_phase text,
  p_top_lessons jsonb DEFAULT '[]'::jsonb,
  p_what_worked text DEFAULT NULL,
  p_what_failed text DEFAULT NULL,
  p_proudest_ship text DEFAULT NULL,
  p_biggest_regret text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_author uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_author FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  INSERT INTO public.founder_1400_ships_memos_r2230(
    memo_title, founder_reflection, next_phase_plan, top_lessons,
    what_worked, what_failed, proudest_ship, biggest_regret, authored_by
  )
  VALUES (p_title, p_reflection, p_next_phase, p_top_lessons,
          p_what_worked, p_what_failed, p_proudest_ship, p_biggest_regret, v_author)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 5: publish memo
CREATE OR REPLACE FUNCTION public.founder_1400_publish_memo_r2230(p_memo_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_1400_ships_memos_r2230
    SET status = 'published', published_at = COALESCE(published_at, now()), updated_at = now()
  WHERE id = p_memo_id;
END;
$$;

-- RPC 6: log reaction
CREATE OR REPLACE FUNCTION public.founder_1400_log_reaction_r2230(
  p_memo_id uuid,
  p_reactor_name text,
  p_reactor_type text,
  p_reaction_text text,
  p_sentiment text DEFAULT 'positive',
  p_reactor_email text DEFAULT NULL,
  p_shared_publicly boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_logger uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_logger FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  INSERT INTO public.founder_1400_ships_reactions_r2230(
    memo_id, reactor_name, reactor_type, reaction_text, sentiment,
    reactor_email, shared_publicly, logged_by
  )
  VALUES (p_memo_id, p_reactor_name, p_reactor_type, p_reaction_text, p_sentiment,
          p_reactor_email, p_shared_publicly, v_logger)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 7: sentiment breakdown by reactor type
CREATE OR REPLACE FUNCTION public.founder_1400_sentiment_breakdown_r2230()
RETURNS TABLE (
  reactor_type text,
  total_count int,
  positive_count int,
  neutral_count int,
  negative_count int,
  mixed_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.reactor_type,
           (COUNT(*))::int,
           (COUNT(*) FILTER (WHERE r.sentiment = 'positive'))::int,
           (COUNT(*) FILTER (WHERE r.sentiment = 'neutral'))::int,
           (COUNT(*) FILTER (WHERE r.sentiment = 'negative'))::int,
           (COUNT(*) FILTER (WHERE r.sentiment = 'mixed'))::int
    FROM public.founder_1400_ships_reactions_r2230 r
    GROUP BY r.reactor_type
    ORDER BY (COUNT(*))::int DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_1400_list_memos_r2230() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1400_list_reactions_r2230() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1400_summary_r2230() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1400_create_memo_r2230(text, text, text, jsonb, text, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1400_publish_memo_r2230(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1400_log_reaction_r2230(uuid, text, text, text, text, text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1400_sentiment_breakdown_r2230() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_1400_list_memos_r2230() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1400_list_reactions_r2230() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1400_summary_r2230() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1400_create_memo_r2230(text, text, text, jsonb, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1400_publish_memo_r2230(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1400_log_reaction_r2230(uuid, text, text, text, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1400_sentiment_breakdown_r2230() TO authenticated;

COMMIT;
