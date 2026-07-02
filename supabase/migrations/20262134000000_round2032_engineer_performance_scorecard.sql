BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_performance_scorecard_r2032 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  technical_score int NOT NULL DEFAULT 0,
  customer_score int NOT NULL DEFAULT 0,
  reliability_score int NOT NULL DEFAULT 0,
  teamwork_score int NOT NULL DEFAULT 0,
  composite_score int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'stable' CHECK (status IN ('rising','stable','declining','at_risk','excellent')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_scorecard_action_log_r2032 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scorecard_id uuid NOT NULL REFERENCES public.engineer_performance_scorecard_r2032(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coached','promoted','bonused','escalated','recognized')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_performance_scorecard_r2032 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_scorecard_action_log_r2032 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_scorecard_r2032 ON public.engineer_performance_scorecard_r2032;
CREATE POLICY founder_all_scorecard_r2032 ON public.engineer_performance_scorecard_r2032
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2032 ON public.engineer_scorecard_action_log_r2032;
CREATE POLICY founder_all_action_log_r2032 ON public.engineer_scorecard_action_log_r2032
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_scorecards_r2032()
RETURNS TABLE(id uuid, engineer_user_id uuid, period_label text, technical_score int, customer_score int, reliability_score int, teamwork_score int, composite_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.id, s.engineer_user_id, s.period_label, s.technical_score, s.customer_score, s.reliability_score, s.teamwork_score, s.composite_score, s.status, s.captured_at
    FROM public.engineer_performance_scorecard_r2032 s ORDER BY s.captured_at DESC LIMIT 200;
END;$$;

CREATE OR REPLACE FUNCTION public.log_scorecard_r2032(p_engineer_user_id uuid, p_period_label text, p_technical int, p_customer int, p_reliability int, p_teamwork int, p_composite int, p_status text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_performance_scorecard_r2032(engineer_user_id, period_label, technical_score, customer_score, reliability_score, teamwork_score, composite_score, status)
    VALUES (p_engineer_user_id, p_period_label, p_technical, p_customer, p_reliability, p_teamwork, p_composite, p_status) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_scorecard_r2032', jsonb_build_object('id', v_id, 'engineer', p_engineer_user_id, 'composite', p_composite));
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2032(p_scorecard_id uuid)
RETURNS TABLE(id uuid, scorecard_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.scorecard_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_scorecard_action_log_r2032 a WHERE a.scorecard_id = p_scorecard_id ORDER BY a.taken_at DESC LIMIT 200;
END;$$;

CREATE OR REPLACE FUNCTION public.log_action_r2032(p_scorecard_id uuid, p_action_type text, p_by_email text, p_notes text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_scorecard_action_log_r2032(scorecard_id, action_type, by_email, notes_md)
    VALUES (p_scorecard_id, p_action_type, p_by_email, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2032', jsonb_build_object('id', v_id, 'scorecard', p_scorecard_id, 'action', p_action_type));
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2032(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_performance_scorecard_r2032 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2032', jsonb_build_object('id', p_id, 'status', p_status));
END;$$;

CREATE OR REPLACE FUNCTION public.at_risk_r2032()
RETURNS TABLE(id uuid, engineer_user_id uuid, period_label text, composite_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.id, s.engineer_user_id, s.period_label, s.composite_score, s.status, s.captured_at
    FROM public.engineer_performance_scorecard_r2032 s WHERE s.status IN ('at_risk','declining') ORDER BY s.captured_at DESC LIMIT 100;
END;$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2032()
RETURNS TABLE(id uuid, scorecard_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.scorecard_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_scorecard_action_log_r2032 a ORDER BY a.taken_at DESC LIMIT 100;
END;$$;

REVOKE EXECUTE ON FUNCTION public.list_scorecards_r2032() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_scorecard_r2032(uuid, text, int, int, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2032(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2032(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2032(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_r2032() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2032() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_scorecards_r2032() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_scorecard_r2032(uuid, text, int, int, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2032(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2032(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2032(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_r2032() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2032() TO authenticated;

COMMIT;
