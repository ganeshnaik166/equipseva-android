BEGIN;

-- =========================================================================
-- r1701 — Investor Voting Rights Tracker
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.investor_voting_rights_r1701 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  total_votes bigint NOT NULL DEFAULT 0 CHECK (total_votes >= 0),
  voting_class text NOT NULL CHECK (voting_class IN ('common','preferred_a','preferred_b','observer')),
  board_seats int NOT NULL DEFAULT 0 CHECK (board_seats >= 0),
  since_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ivr_r1701_investor ON public.investor_voting_rights_r1701(investor_id);
CREATE INDEX IF NOT EXISTS idx_ivr_r1701_class ON public.investor_voting_rights_r1701(voting_class);

CREATE TABLE IF NOT EXISTS public.investor_vote_events_r1701 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vote_id uuid NOT NULL DEFAULT gen_random_uuid(),
  voting_right_id uuid NOT NULL REFERENCES public.investor_voting_rights_r1701(id) ON DELETE CASCADE,
  vote_topic text NOT NULL,
  vote_date date NOT NULL DEFAULT CURRENT_DATE,
  vote_cast text NOT NULL CHECK (vote_cast IN ('yes','no','abstain','absent')),
  vote_weight bigint NOT NULL DEFAULT 0 CHECK (vote_weight >= 0),
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ive_r1701_right ON public.investor_vote_events_r1701(voting_right_id);
CREATE INDEX IF NOT EXISTS idx_ive_r1701_topic ON public.investor_vote_events_r1701(vote_topic);
CREATE INDEX IF NOT EXISTS idx_ive_r1701_date ON public.investor_vote_events_r1701(vote_date DESC);
CREATE INDEX IF NOT EXISTS idx_ive_r1701_cast ON public.investor_vote_events_r1701(vote_cast);

ALTER TABLE public.investor_voting_rights_r1701 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_vote_events_r1701 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ivr_r1701_founder_all ON public.investor_voting_rights_r1701;
CREATE POLICY ivr_r1701_founder_all ON public.investor_voting_rights_r1701
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS ive_r1701_founder_all ON public.investor_vote_events_r1701;
CREATE POLICY ive_r1701_founder_all ON public.investor_vote_events_r1701
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC: list_voting_rights
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_voting_rights_r1701()
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_email text,
  total_votes bigint,
  voting_class text,
  board_seats int,
  since_date date,
  events_count int,
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
  SELECT
    v.id,
    v.investor_id,
    p.email::text AS investor_email,
    v.total_votes,
    v.voting_class,
    v.board_seats,
    v.since_date,
    (SELECT (COUNT(*))::int FROM public.investor_vote_events_r1701 e WHERE e.voting_right_id = v.id) AS events_count,
    v.created_at
  FROM public.investor_voting_rights_r1701 v
  LEFT JOIN public.profiles p ON p.id = v.investor_id
  ORDER BY v.total_votes DESC, v.created_at DESC
  LIMIT 500;
END;
$$;

-- =========================================================================
-- RPC: set_voting_rights
-- =========================================================================
CREATE OR REPLACE FUNCTION public.set_voting_rights_r1701(
  p_investor_id uuid,
  p_total_votes bigint,
  p_voting_class text,
  p_board_seats int,
  p_since_date date
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
  INSERT INTO public.investor_voting_rights_r1701(investor_id, total_votes, voting_class, board_seats, since_date)
  VALUES (p_investor_id, p_total_votes, p_voting_class, p_board_seats, COALESCE(p_since_date, CURRENT_DATE))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_voting_rights_r1701',
    jsonb_build_object('right_id', v_id, 'investor_id', p_investor_id, 'total_votes', p_total_votes, 'voting_class', p_voting_class, 'board_seats', p_board_seats));

  RETURN v_id;
END;
$$;

-- =========================================================================
-- RPC: list_vote_events
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_vote_events_r1701()
RETURNS TABLE(
  id uuid,
  vote_id uuid,
  voting_right_id uuid,
  investor_email text,
  voting_class text,
  vote_topic text,
  vote_date date,
  vote_cast text,
  vote_weight bigint,
  founder_note text,
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
  SELECT
    e.id,
    e.vote_id,
    e.voting_right_id,
    p.email::text AS investor_email,
    v.voting_class,
    e.vote_topic,
    e.vote_date,
    e.vote_cast,
    e.vote_weight,
    e.founder_note,
    e.created_at
  FROM public.investor_vote_events_r1701 e
  LEFT JOIN public.investor_voting_rights_r1701 v ON v.id = e.voting_right_id
  LEFT JOIN public.profiles p ON p.id = v.investor_id
  ORDER BY e.vote_date DESC, e.created_at DESC
  LIMIT 500;
END;
$$;

-- =========================================================================
-- RPC: record_vote
-- =========================================================================
CREATE OR REPLACE FUNCTION public.record_vote_r1701(
  p_voting_right_id uuid,
  p_vote_topic text,
  p_vote_date date,
  p_vote_cast text,
  p_vote_weight bigint,
  p_founder_note text
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
  INSERT INTO public.investor_vote_events_r1701(voting_right_id, vote_topic, vote_date, vote_cast, vote_weight, founder_note)
  VALUES (p_voting_right_id, p_vote_topic, COALESCE(p_vote_date, CURRENT_DATE), p_vote_cast, COALESCE(p_vote_weight, 0), p_founder_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_vote_r1701',
    jsonb_build_object('event_id', v_id, 'voting_right_id', p_voting_right_id, 'vote_topic', p_vote_topic, 'vote_cast', p_vote_cast, 'vote_weight', p_vote_weight));

  RETURN v_id;
END;
$$;

-- =========================================================================
-- RPC: voting_tally_per_topic
-- =========================================================================
CREATE OR REPLACE FUNCTION public.voting_tally_per_topic_r1701()
RETURNS TABLE(
  vote_topic text,
  events_count int,
  yes_weight bigint,
  no_weight bigint,
  abstain_weight bigint,
  absent_weight bigint,
  total_weight bigint,
  last_vote_date date
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
  SELECT
    e.vote_topic,
    (COUNT(*))::int AS events_count,
    COALESCE(SUM(e.vote_weight) FILTER (WHERE e.vote_cast = 'yes'), 0)::bigint AS yes_weight,
    COALESCE(SUM(e.vote_weight) FILTER (WHERE e.vote_cast = 'no'), 0)::bigint AS no_weight,
    COALESCE(SUM(e.vote_weight) FILTER (WHERE e.vote_cast = 'abstain'), 0)::bigint AS abstain_weight,
    COALESCE(SUM(e.vote_weight) FILTER (WHERE e.vote_cast = 'absent'), 0)::bigint AS absent_weight,
    COALESCE(SUM(e.vote_weight), 0)::bigint AS total_weight,
    MAX(e.vote_date) AS last_vote_date
  FROM public.investor_vote_events_r1701 e
  GROUP BY e.vote_topic
  ORDER BY MAX(e.vote_date) DESC NULLS LAST
  LIMIT 200;
END;
$$;

-- =========================================================================
-- RPC: board_seat_summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public.board_seat_summary_r1701()
RETURNS TABLE(
  voting_class text,
  investors_count int,
  total_votes_sum bigint,
  board_seats_sum int
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
  SELECT
    v.voting_class,
    (COUNT(*))::int AS investors_count,
    COALESCE(SUM(v.total_votes), 0)::bigint AS total_votes_sum,
    COALESCE(SUM(v.board_seats), 0)::int AS board_seats_sum
  FROM public.investor_voting_rights_r1701 v
  GROUP BY v.voting_class
  ORDER BY total_votes_sum DESC;
END;
$$;

-- =========================================================================
-- RPC: abstainers_recent
-- =========================================================================
CREATE OR REPLACE FUNCTION public.abstainers_recent_r1701()
RETURNS TABLE(
  id uuid,
  voting_right_id uuid,
  investor_email text,
  voting_class text,
  vote_topic text,
  vote_date date,
  vote_cast text,
  vote_weight bigint,
  founder_note text
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
  SELECT
    e.id,
    e.voting_right_id,
    p.email::text AS investor_email,
    v.voting_class,
    e.vote_topic,
    e.vote_date,
    e.vote_cast,
    e.vote_weight,
    e.founder_note
  FROM public.investor_vote_events_r1701 e
  LEFT JOIN public.investor_voting_rights_r1701 v ON v.id = e.voting_right_id
  LEFT JOIN public.profiles p ON p.id = v.investor_id
  WHERE e.vote_cast IN ('abstain','absent')
    AND e.vote_date >= (CURRENT_DATE - INTERVAL '180 days')
  ORDER BY e.vote_date DESC
  LIMIT 200;
END;
$$;

-- =========================================================================
-- GRANTS
-- =========================================================================
REVOKE EXECUTE ON FUNCTION public.list_voting_rights_r1701() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_voting_rights_r1701(uuid, bigint, text, int, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_vote_events_r1701() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_vote_r1701(uuid, text, date, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.voting_tally_per_topic_r1701() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.board_seat_summary_r1701() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.abstainers_recent_r1701() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_voting_rights_r1701() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_voting_rights_r1701(uuid, bigint, text, int, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_vote_events_r1701() TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_vote_r1701(uuid, text, date, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.voting_tally_per_topic_r1701() TO authenticated;
GRANT EXECUTE ON FUNCTION public.board_seat_summary_r1701() TO authenticated;
GRANT EXECUTE ON FUNCTION public.abstainers_recent_r1701() TO authenticated;

COMMIT;