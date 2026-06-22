BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_round_forecasts_r1961 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_label text NOT NULL,
  target_amount_rupees bigint NOT NULL DEFAULT 0,
  projected_valuation_pre_money_rupees bigint NOT NULL DEFAULT 0,
  projected_valuation_post_money_rupees bigint NOT NULL DEFAULT 0,
  founder_dilution_pct numeric(6,3) NOT NULL DEFAULT 0,
  projected_close_date date,
  status text NOT NULL DEFAULT 'modeled' CHECK (status IN ('modeled','in_progress','closed','cancelled','superseded')),
  modeled_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_cap_round_scenario_log_r1961 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forecast_id uuid NOT NULL REFERENCES public.investor_cap_round_forecasts_r1961(id) ON DELETE CASCADE,
  scenario_type text NOT NULL CHECK (scenario_type IN ('best_case','base_case','worst_case','walk_away','bridge')),
  scenario_md text NOT NULL DEFAULT '',
  projected_dilution_pct numeric(6,3) NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_round_forecasts_r1961 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_cap_round_scenario_log_r1961 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_forecasts_r1961 ON public.investor_cap_round_forecasts_r1961;
CREATE POLICY founder_all_forecasts_r1961 ON public.investor_cap_round_forecasts_r1961
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_scenarios_r1961 ON public.investor_cap_round_scenario_log_r1961;
CREATE POLICY founder_all_scenarios_r1961 ON public.investor_cap_round_scenario_log_r1961
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_forecasts_r1961()
RETURNS TABLE(id uuid, round_label text, target_amount_rupees bigint, projected_valuation_pre_money_rupees bigint, projected_valuation_post_money_rupees bigint, founder_dilution_pct numeric, projected_close_date date, status text, modeled_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT f.id, f.round_label, f.target_amount_rupees, f.projected_valuation_pre_money_rupees, f.projected_valuation_post_money_rupees, f.founder_dilution_pct, f.projected_close_date, f.status, f.modeled_at
    FROM public.investor_cap_round_forecasts_r1961 f
    ORDER BY f.modeled_at DESC
    LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_forecast_r1961(
  p_round_label text,
  p_target_amount_rupees bigint,
  p_projected_valuation_pre_money_rupees bigint,
  p_projected_valuation_post_money_rupees bigint,
  p_founder_dilution_pct numeric,
  p_projected_close_date date,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_round_forecasts_r1961(round_label, target_amount_rupees, projected_valuation_pre_money_rupees, projected_valuation_post_money_rupees, founder_dilution_pct, projected_close_date, status)
    VALUES (p_round_label, COALESCE(p_target_amount_rupees,0), COALESCE(p_projected_valuation_pre_money_rupees,0), COALESCE(p_projected_valuation_post_money_rupees,0), COALESCE(p_founder_dilution_pct,0), p_projected_close_date, COALESCE(p_status,'modeled'))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_forecast_r1961', jsonb_build_object('id', v_id, 'round_label', p_round_label));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_scenarios_r1961(p_forecast_id uuid)
RETURNS TABLE(id uuid, forecast_id uuid, scenario_type text, scenario_md text, projected_dilution_pct numeric, recorded_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.id, s.forecast_id, s.scenario_type, s.scenario_md, s.projected_dilution_pct, s.recorded_at, s.by_email
    FROM public.investor_cap_round_scenario_log_r1961 s
    WHERE s.forecast_id = p_forecast_id
    ORDER BY s.recorded_at DESC
    LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.log_scenario_r1961(
  p_forecast_id uuid,
  p_scenario_type text,
  p_scenario_md text,
  p_projected_dilution_pct numeric
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  INSERT INTO public.investor_cap_round_scenario_log_r1961(forecast_id, scenario_type, scenario_md, projected_dilution_pct, by_email)
    VALUES (p_forecast_id, p_scenario_type, COALESCE(p_scenario_md,''), COALESCE(p_projected_dilution_pct,0), v_email)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'log_scenario_r1961', jsonb_build_object('id', v_id, 'forecast_id', p_forecast_id, 'scenario_type', p_scenario_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1961(p_forecast_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_round_forecasts_r1961 SET status = p_status, updated_at = now() WHERE id = p_forecast_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1961', jsonb_build_object('id', p_forecast_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.modeled_rounds_r1961()
RETURNS TABLE(status text, round_count bigint, total_target_rupees numeric, avg_dilution_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT f.status, COUNT(*)::bigint, COALESCE(SUM(f.target_amount_rupees),0)::numeric, COALESCE(AVG(f.founder_dilution_pct),0)::numeric
    FROM public.investor_cap_round_forecasts_r1961 f
    GROUP BY f.status
    ORDER BY f.status;
END $$;

CREATE OR REPLACE FUNCTION public.recent_scenarios_r1961()
RETURNS TABLE(id uuid, forecast_id uuid, round_label text, scenario_type text, projected_dilution_pct numeric, recorded_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.id, s.forecast_id, f.round_label, s.scenario_type, s.projected_dilution_pct, s.recorded_at, s.by_email
    FROM public.investor_cap_round_scenario_log_r1961 s
    JOIN public.investor_cap_round_forecasts_r1961 f ON f.id = s.forecast_id
    ORDER BY s.recorded_at DESC
    LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_forecasts_r1961() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_forecast_r1961(text,bigint,bigint,bigint,numeric,date,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_scenarios_r1961(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_scenario_r1961(uuid,text,text,numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1961(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.modeled_rounds_r1961() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_scenarios_r1961() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_forecasts_r1961() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_forecast_r1961(text,bigint,bigint,bigint,numeric,date,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_scenarios_r1961(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_scenario_r1961(uuid,text,text,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1961(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.modeled_rounds_r1961() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_scenarios_r1961() TO authenticated;

COMMIT;
