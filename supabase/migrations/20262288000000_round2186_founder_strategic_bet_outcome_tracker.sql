BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_strategic_bet_outcome_tracker_r2186 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_label text NOT NULL,
  bet_size text NOT NULL CHECK (bet_size IN ('small','medium','large','company_bet')),
  outcome text NOT NULL CHECK (outcome IN ('winning','losing','too_early','won','lost')),
  confidence_at_outcome int NOT NULL CHECK (confidence_at_outcome BETWEEN 0 AND 100),
  status text NOT NULL CHECK (status IN ('active','won','lost','walked_away','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_bet_outcome_action_log_r2186 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_id uuid NOT NULL REFERENCES public.founder_strategic_bet_outcome_tracker_r2186(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('observed','escalated','won','lost','closed','lessons_documented')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_strategic_bet_outcome_tracker_r2186 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_bet_outcome_action_log_r2186 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_bets_r2186 ON public.founder_strategic_bet_outcome_tracker_r2186;
CREATE POLICY founder_all_bets_r2186 ON public.founder_strategic_bet_outcome_tracker_r2186
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2186 ON public.founder_bet_outcome_action_log_r2186;
CREATE POLICY founder_all_actions_r2186 ON public.founder_bet_outcome_action_log_r2186
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_bets_r2186()
RETURNS SETOF public.founder_strategic_bet_outcome_tracker_r2186
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_strategic_bet_outcome_tracker_r2186 ORDER BY captured_at DESC LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_bets_r2186() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bets_r2186() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_bet_r2186(
  p_bet_label text,
  p_bet_size text,
  p_outcome text,
  p_confidence int,
  p_status text
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
  INSERT INTO public.founder_strategic_bet_outcome_tracker_r2186(bet_label, bet_size, outcome, confidence_at_outcome, status)
  VALUES (p_bet_label, p_bet_size, p_outcome, p_confidence, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_bet_r2186', jsonb_build_object('id', v_id, 'bet_label', p_bet_label));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_bet_r2186(text, text, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_bet_r2186(text, text, text, int, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2186(p_bet_id uuid)
RETURNS SETOF public.founder_bet_outcome_action_log_r2186
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_bet_outcome_action_log_r2186 WHERE bet_id = p_bet_id ORDER BY taken_at DESC LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2186(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2186(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_action_r2186(
  p_bet_id uuid,
  p_action_type text,
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
  INSERT INTO public.founder_bet_outcome_action_log_r2186(bet_id, action_type, by_email, notes_md)
  VALUES (p_bet_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2186', jsonb_build_object('id', v_id, 'bet_id', p_bet_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2186(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2186(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_status_r2186(p_bet_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_strategic_bet_outcome_tracker_r2186 SET status = p_status, updated_at = now() WHERE id = p_bet_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2186', jsonb_build_object('bet_id', p_bet_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2186(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2186(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.winning_bets_r2186()
RETURNS SETOF public.founder_strategic_bet_outcome_tracker_r2186
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_strategic_bet_outcome_tracker_r2186
    WHERE outcome IN ('winning','won') AND status = 'active'
    ORDER BY confidence_at_outcome DESC, captured_at DESC LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.winning_bets_r2186() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.winning_bets_r2186() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_actions_r2186()
RETURNS SETOF public.founder_bet_outcome_action_log_r2186
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_bet_outcome_action_log_r2186 ORDER BY taken_at DESC LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2186() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2186() TO authenticated;

COMMIT;
