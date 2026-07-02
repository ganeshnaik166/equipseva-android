BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_director_elections_r2001 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  election_type text NOT NULL CHECK (election_type IN ('initial_election','re_election','replacement','term_renewal')),
  candidate_name text NOT NULL,
  election_date date NOT NULL,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','voted','elected','declined','superseded')),
  term_end_date date,
  votes_for int NOT NULL DEFAULT 0,
  votes_against int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_director_action_log_r2001 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  election_id uuid NOT NULL REFERENCES public.investor_director_elections_r2001(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('nominated','vote_held','elected','rejected','term_renewed','replaced')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_director_elections_r2001 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_director_action_log_r2001 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2001_elections ON public.investor_director_elections_r2001;
CREATE POLICY founder_all_r2001_elections ON public.investor_director_elections_r2001
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2001_actions ON public.investor_director_action_log_r2001;
CREATE POLICY founder_all_r2001_actions ON public.investor_director_action_log_r2001
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_director_elections_r2001()
RETURNS SETOF public.investor_director_elections_r2001
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_director_elections_r2001 ORDER BY election_date DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_director_election_r2001(
  p_investor_id uuid,
  p_election_type text,
  p_candidate_name text,
  p_election_date date,
  p_term_end_date date DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_director_elections_r2001(investor_id, election_type, candidate_name, election_date, term_end_date)
  VALUES (p_investor_id, p_election_type, p_candidate_name, p_election_date, p_term_end_date)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_director_election_r2001', jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'election_type', p_election_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_director_actions_r2001(p_election_id uuid)
RETURNS SETOF public.investor_director_action_log_r2001
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_director_action_log_r2001 WHERE election_id = p_election_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_director_action_r2001(
  p_election_id uuid,
  p_action_type text,
  p_by_email text DEFAULT NULL,
  p_notes_md text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_director_action_log_r2001(election_id, action_type, by_email, notes_md)
  VALUES (p_election_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_director_action_r2001', jsonb_build_object('id', v_id, 'election_id', p_election_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_director_election_status_r2001(
  p_election_id uuid,
  p_status text,
  p_votes_for int DEFAULT NULL,
  p_votes_against int DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_director_elections_r2001
  SET status = p_status,
      votes_for = COALESCE(p_votes_for, votes_for),
      votes_against = COALESCE(p_votes_against, votes_against),
      updated_at = now()
  WHERE id = p_election_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_director_election_status_r2001', jsonb_build_object('id', p_election_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.upcoming_director_elections_r2001()
RETURNS SETOF public.investor_director_elections_r2001
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_director_elections_r2001
    WHERE election_date >= CURRENT_DATE AND status = 'scheduled'
    ORDER BY election_date ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_director_actions_r2001(p_limit int DEFAULT 50)
RETURNS SETOF public.investor_director_action_log_r2001
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_director_action_log_r2001 ORDER BY taken_at DESC LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_director_elections_r2001() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_director_election_r2001(uuid, text, text, date, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_director_actions_r2001(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_director_action_r2001(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_director_election_status_r2001(uuid, text, int, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_director_elections_r2001() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_director_actions_r2001(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_director_elections_r2001() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_director_election_r2001(uuid, text, text, date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_director_actions_r2001(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_director_action_r2001(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_director_election_status_r2001(uuid, text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_director_elections_r2001() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_director_actions_r2001(int) TO authenticated;

COMMIT;
