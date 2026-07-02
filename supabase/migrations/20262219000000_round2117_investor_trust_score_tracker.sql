BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_trust_score_tracker_r2117 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  period_label text NOT NULL,
  trust_score int NOT NULL CHECK (trust_score BETWEEN 0 AND 100),
  trust_factors_md text,
  status text NOT NULL CHECK (status IN ('thriving','strong','concerning','at_risk','lost')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_trust_action_log_r2117 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score_id uuid NOT NULL REFERENCES public.investor_trust_score_tracker_r2117(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engagement','recovery_attempted','escalated','won_back','lost')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_trust_score_tracker_r2117 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_trust_action_log_r2117 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_scores_r2117 ON public.investor_trust_score_tracker_r2117;
CREATE POLICY founder_all_scores_r2117 ON public.investor_trust_score_tracker_r2117
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2117 ON public.investor_trust_action_log_r2117;
CREATE POLICY founder_all_actions_r2117 ON public.investor_trust_action_log_r2117
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_investor_trust_scores_r2117()
RETURNS TABLE(id uuid, investor_id uuid, period_label text, trust_score int, trust_factors_md text, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_id, s.period_label, s.trust_score, s.trust_factors_md, s.status, s.captured_at
  FROM public.investor_trust_score_tracker_r2117 s
  ORDER BY s.captured_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_investor_trust_score_r2117(
  p_investor_id uuid,
  p_period_label text,
  p_trust_score int,
  p_trust_factors_md text,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_trust_score_tracker_r2117(investor_id, period_label, trust_score, trust_factors_md, status)
  VALUES (p_investor_id, p_period_label, p_trust_score, p_trust_factors_md, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_trust_score_r2117',
          jsonb_build_object('score_id', v_id, 'investor_id', p_investor_id, 'trust_score', p_trust_score, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_investor_trust_actions_r2117(p_score_id uuid)
RETURNS TABLE(id uuid, score_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.score_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.investor_trust_action_log_r2117 a
  WHERE a.score_id = p_score_id
  ORDER BY a.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_investor_trust_action_r2117(
  p_score_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_trust_action_log_r2117(score_id, action_type, by_email, notes_md)
  VALUES (p_score_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_trust_action_r2117',
          jsonb_build_object('action_id', v_id, 'score_id', p_score_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_investor_trust_status_r2117(p_score_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_trust_score_tracker_r2117
  SET status = p_status, updated_at = now()
  WHERE id = p_score_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_investor_trust_status_r2117',
          jsonb_build_object('score_id', p_score_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.at_risk_investor_trust_r2117()
RETURNS TABLE(id uuid, investor_id uuid, period_label text, trust_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_id, s.period_label, s.trust_score, s.status, s.captured_at
  FROM public.investor_trust_score_tracker_r2117 s
  WHERE s.status IN ('at_risk','concerning','lost')
  ORDER BY s.captured_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_investor_trust_actions_r2117()
RETURNS TABLE(id uuid, score_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.score_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.investor_trust_action_log_r2117 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_investor_trust_scores_r2117() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_trust_score_r2117(uuid, text, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_investor_trust_actions_r2117(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_trust_action_r2117(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_investor_trust_status_r2117(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_investor_trust_r2117() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_investor_trust_actions_r2117() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_investor_trust_scores_r2117() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_trust_score_r2117(uuid, text, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_investor_trust_actions_r2117(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_trust_action_r2117(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_investor_trust_status_r2117(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_investor_trust_r2117() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_investor_trust_actions_r2117() TO authenticated;

COMMIT;
