BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_termination_watchlist_r2065 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  watch_reason text NOT NULL CHECK (watch_reason IN ('declining_engagement','concerns_raised','competing_investment','founder_friction','policy_change')),
  risk_score int NOT NULL CHECK (risk_score BETWEEN 1 AND 10),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','escalated','resolved','terminated','recovered')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_termination_action_log_r2065 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  watch_id uuid NOT NULL REFERENCES public.investor_termination_watchlist_r2065(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engagement_call','concern_addressed','win_back_offer','terminated','recovered')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_termination_watchlist_r2065 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_termination_action_log_r2065 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_watch_r2065 ON public.investor_termination_watchlist_r2065;
CREATE POLICY founder_all_watch_r2065 ON public.investor_termination_watchlist_r2065
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2065 ON public.investor_termination_action_log_r2065;
CREATE POLICY founder_all_action_r2065 ON public.investor_termination_action_log_r2065
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_investor_termination_watches_r2065()
RETURNS TABLE(id uuid, investor_id uuid, watch_reason text, risk_score int, status text, captured_at timestamptz, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT w.id, w.investor_id, w.watch_reason, w.risk_score, w.status, w.captured_at, w.notes_md
    FROM public.investor_termination_watchlist_r2065 w
    ORDER BY w.captured_at DESC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_investor_termination_watch_r2065(
  p_investor_id uuid, p_reason text, p_risk int, p_notes text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_termination_watchlist_r2065(investor_id, watch_reason, risk_score, notes_md)
    VALUES (p_investor_id, p_reason, p_risk, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_termination_watch_r2065',
      jsonb_build_object('watch_id', v_id, 'investor_id', p_investor_id, 'reason', p_reason, 'risk', p_risk));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_investor_termination_actions_r2065(p_watch_id uuid)
RETURNS TABLE(id uuid, watch_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.watch_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_termination_action_log_r2065 a
    WHERE a.watch_id = p_watch_id ORDER BY a.taken_at DESC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_investor_termination_action_r2065(
  p_watch_id uuid, p_action_type text, p_notes text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_termination_action_log_r2065(watch_id, action_type, by_email, notes_md)
    VALUES (p_watch_id, p_action_type, (auth.jwt()->>'email'), p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_termination_action_r2065',
      jsonb_build_object('action_id', v_id, 'watch_id', p_watch_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_investor_termination_status_r2065(
  p_watch_id uuid, p_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_termination_watchlist_r2065 SET status = p_status, updated_at = now()
    WHERE id = p_watch_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_investor_termination_status_r2065',
      jsonb_build_object('watch_id', p_watch_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.high_risk_investor_terminations_r2065()
RETURNS TABLE(id uuid, investor_id uuid, watch_reason text, risk_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT w.id, w.investor_id, w.watch_reason, w.risk_score, w.status, w.captured_at
    FROM public.investor_termination_watchlist_r2065 w
    WHERE w.risk_score >= 7 AND w.status IN ('active','escalated')
    ORDER BY w.risk_score DESC, w.captured_at DESC LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.recent_investor_termination_actions_r2065()
RETURNS TABLE(id uuid, watch_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.watch_id, a.action_type, a.taken_at, a.by_email
    FROM public.investor_termination_action_log_r2065 a
    ORDER BY a.taken_at DESC LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_investor_termination_watches_r2065() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_termination_watch_r2065(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_investor_termination_actions_r2065(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_termination_action_r2065(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_investor_termination_status_r2065(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.high_risk_investor_terminations_r2065() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_investor_termination_actions_r2065() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_investor_termination_watches_r2065() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_termination_watch_r2065(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_investor_termination_actions_r2065(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_termination_action_r2065(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_investor_termination_status_r2065(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.high_risk_investor_terminations_r2065() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_investor_termination_actions_r2065() TO authenticated;

COMMIT;
