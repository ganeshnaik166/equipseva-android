BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_stockholder_votes_r1977 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_label text NOT NULL,
  proposal_md text,
  vote_threshold_pct numeric NOT NULL DEFAULT 50,
  current_yes_shares bigint NOT NULL DEFAULT 0,
  current_no_shares bigint NOT NULL DEFAULT 0,
  abstain_shares bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','passing','failing','concluded_passed','concluded_failed')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closes_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_vote_log_r1977 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id uuid NOT NULL REFERENCES public.investor_stockholder_votes_r1977(id) ON DELETE CASCADE,
  voter_email text NOT NULL,
  vote text NOT NULL CHECK (vote IN ('yes','no','abstain')),
  shares_voted bigint NOT NULL DEFAULT 0,
  voted_at timestamptz NOT NULL DEFAULT now(),
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_stockholder_votes_r1977 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_vote_log_r1977 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_votes_r1977 ON public.investor_stockholder_votes_r1977;
CREATE POLICY founder_all_votes_r1977 ON public.investor_stockholder_votes_r1977
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_vote_log_r1977 ON public.investor_vote_log_r1977;
CREATE POLICY founder_all_vote_log_r1977 ON public.investor_vote_log_r1977
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_proposals_r1977()
RETURNS SETOF public.investor_stockholder_votes_r1977
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_stockholder_votes_r1977 ORDER BY opened_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_proposal_r1977(
  p_proposal_label text,
  p_proposal_md text,
  p_vote_threshold_pct numeric,
  p_closes_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_stockholder_votes_r1977(proposal_label, proposal_md, vote_threshold_pct, closes_at)
  VALUES (p_proposal_label, p_proposal_md, COALESCE(p_vote_threshold_pct, 50), p_closes_at)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_proposal_r1977', jsonb_build_object('id', v_id, 'label', p_proposal_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_votes_r1977(p_proposal_id uuid)
RETURNS SETOF public.investor_vote_log_r1977
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_vote_log_r1977 WHERE proposal_id = p_proposal_id ORDER BY voted_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_vote_r1977(
  p_proposal_id uuid,
  p_voter_email text,
  p_vote text,
  p_shares_voted bigint,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_vote_log_r1977(proposal_id, voter_email, vote, shares_voted, notes_md)
  VALUES (p_proposal_id, p_voter_email, p_vote, COALESCE(p_shares_voted, 0), p_notes_md)
  RETURNING id INTO v_id;

  UPDATE public.investor_stockholder_votes_r1977
  SET current_yes_shares = current_yes_shares + CASE WHEN p_vote = 'yes' THEN COALESCE(p_shares_voted,0) ELSE 0 END,
      current_no_shares  = current_no_shares  + CASE WHEN p_vote = 'no'  THEN COALESCE(p_shares_voted,0) ELSE 0 END,
      abstain_shares     = abstain_shares     + CASE WHEN p_vote = 'abstain' THEN COALESCE(p_shares_voted,0) ELSE 0 END,
      updated_at = now()
  WHERE id = p_proposal_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_vote_r1977', jsonb_build_object('id', v_id, 'proposal', p_proposal_id, 'vote', p_vote));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1977(p_proposal_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','passing','failing','concluded_passed','concluded_failed') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.investor_stockholder_votes_r1977
  SET status = p_status, updated_at = now()
  WHERE id = p_proposal_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1977', jsonb_build_object('id', p_proposal_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.open_proposals_r1977()
RETURNS SETOF public.investor_stockholder_votes_r1977
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_stockholder_votes_r1977
  WHERE status IN ('open','passing','failing')
  ORDER BY opened_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_votes_r1977(p_limit int)
RETURNS SETOF public.investor_vote_log_r1977
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_vote_log_r1977 ORDER BY voted_at DESC LIMIT COALESCE(p_limit, 50);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_proposals_r1977() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_proposal_r1977(text, text, numeric, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_votes_r1977(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_vote_r1977(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1977(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.open_proposals_r1977() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_votes_r1977(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_proposals_r1977() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_proposal_r1977(text, text, numeric, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_votes_r1977(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_vote_r1977(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1977(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_proposals_r1977() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_votes_r1977(int) TO authenticated;

COMMIT;
