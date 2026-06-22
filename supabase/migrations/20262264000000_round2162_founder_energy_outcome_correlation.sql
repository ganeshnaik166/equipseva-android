BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_energy_outcome_correlation_r2162 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  energy_level int NOT NULL CHECK (energy_level BETWEEN 1 AND 10),
  decisions_made int NOT NULL DEFAULT 0,
  escalations_handled int NOT NULL DEFAULT 0,
  deals_closed int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('thriving','balanced','stressed','exhausted')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_correlation_action_log_r2162 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id uuid NOT NULL REFERENCES public.founder_energy_outcome_correlation_r2162(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('celebrated','escalated','recovery','closed','coached')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_energy_outcome_correlation_r2162 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_correlation_action_log_r2162 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_periods_r2162 ON public.founder_energy_outcome_correlation_r2162;
CREATE POLICY founder_all_periods_r2162 ON public.founder_energy_outcome_correlation_r2162
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2162 ON public.founder_correlation_action_log_r2162;
CREATE POLICY founder_all_actions_r2162 ON public.founder_correlation_action_log_r2162
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1) list_periods
CREATE OR REPLACE FUNCTION public.r2162_list_periods()
RETURNS SETOF public.founder_energy_outcome_correlation_r2162
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_energy_outcome_correlation_r2162 ORDER BY captured_at DESC LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2162_list_periods() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2162_list_periods() TO authenticated;

-- 2) log_period
CREATE OR REPLACE FUNCTION public.r2162_log_period(p_label text, p_energy int, p_decisions int, p_escalations int, p_deals int, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_energy_outcome_correlation_r2162(period_label, energy_level, decisions_made, escalations_handled, deals_closed, status)
  VALUES (p_label, p_energy, p_decisions, p_escalations, p_deals, p_status) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2162_log_period', jsonb_build_object('id', v_id, 'label', p_label, 'energy', p_energy));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2162_log_period(text, int, int, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2162_log_period(text, int, int, int, int, text) TO authenticated;

-- 3) list_actions
CREATE OR REPLACE FUNCTION public.r2162_list_actions()
RETURNS SETOF public.founder_correlation_action_log_r2162
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_correlation_action_log_r2162 ORDER BY taken_at DESC LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2162_list_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2162_list_actions() TO authenticated;

-- 4) log_action
CREATE OR REPLACE FUNCTION public.r2162_log_action(p_period_id uuid, p_action_type text, p_by_email text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_correlation_action_log_r2162(period_id, action_type, by_email, notes_md)
  VALUES (p_period_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2162_log_action', jsonb_build_object('id', v_id, 'period_id', p_period_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2162_log_action(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2162_log_action(uuid, text, text, text) TO authenticated;

-- 5) mark_status
CREATE OR REPLACE FUNCTION public.r2162_mark_status(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_energy_outcome_correlation_r2162 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2162_mark_status', jsonb_build_object('id', p_id, 'status', p_status));
END $$;
REVOKE EXECUTE ON FUNCTION public.r2162_mark_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2162_mark_status(uuid, text) TO authenticated;

-- 6) low_energy
CREATE OR REPLACE FUNCTION public.r2162_low_energy()
RETURNS SETOF public.founder_energy_outcome_correlation_r2162
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_energy_outcome_correlation_r2162 WHERE energy_level <= 4 ORDER BY captured_at DESC LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2162_low_energy() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2162_low_energy() TO authenticated;

-- 7) recent_actions
CREATE OR REPLACE FUNCTION public.r2162_recent_actions(p_days int)
RETURNS SETOF public.founder_correlation_action_log_r2162
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_correlation_action_log_r2162 WHERE taken_at >= now() - make_interval(days => p_days) ORDER BY taken_at DESC LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2162_recent_actions(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2162_recent_actions(int) TO authenticated;

COMMIT;
