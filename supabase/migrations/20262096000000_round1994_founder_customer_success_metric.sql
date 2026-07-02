BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_customer_success_metric_r1994 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  retention_rate_pct numeric,
  nps_score int,
  csat_score numeric,
  expansion_rate_pct numeric,
  churn_rate_pct numeric,
  composite_success_score int,
  status text CHECK (status IN ('trending_up','stable','declining','concerning')) DEFAULT 'stable',
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_customer_success_action_log_r1994 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_id uuid REFERENCES public.founder_customer_success_metric_r1994(id) ON DELETE CASCADE,
  action_type text CHECK (action_type IN ('intervention_added','cohort_review','feature_request','retention_call','expansion_offer')) NOT NULL,
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_customer_success_metric_r1994 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_customer_success_action_log_r1994 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_metric_r1994 ON public.founder_customer_success_metric_r1994;
CREATE POLICY founder_only_metric_r1994 ON public.founder_customer_success_metric_r1994
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_action_r1994 ON public.founder_customer_success_action_log_r1994;
CREATE POLICY founder_only_action_r1994 ON public.founder_customer_success_action_log_r1994
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_customer_success_metrics_r1994()
RETURNS SETOF public.founder_customer_success_metric_r1994
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_customer_success_metric_r1994 ORDER BY captured_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_customer_success_metric_r1994(
  p_period_label text,
  p_retention_rate_pct numeric,
  p_nps_score int,
  p_csat_score numeric,
  p_expansion_rate_pct numeric,
  p_churn_rate_pct numeric,
  p_composite_success_score int,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_customer_success_metric_r1994(period_label, retention_rate_pct, nps_score, csat_score, expansion_rate_pct, churn_rate_pct, composite_success_score, status)
  VALUES (p_period_label, p_retention_rate_pct, p_nps_score, p_csat_score, p_expansion_rate_pct, p_churn_rate_pct, p_composite_success_score, COALESCE(p_status,'stable'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(id, actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (gen_random_uuid(), auth.uid(), (auth.jwt()->>'email'), 'log_customer_success_metric_r1994', jsonb_build_object('id', v_id, 'period_label', p_period_label, 'composite_success_score', p_composite_success_score), now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_customer_success_actions_r1994(p_metric_id uuid)
RETURNS SETOF public.founder_customer_success_action_log_r1994
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_customer_success_action_log_r1994 WHERE metric_id = p_metric_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_customer_success_action_r1994(
  p_metric_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_customer_success_action_log_r1994(metric_id, action_type, by_email, notes_md)
  VALUES (p_metric_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(id, actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (gen_random_uuid(), auth.uid(), (auth.jwt()->>'email'), 'log_customer_success_action_r1994', jsonb_build_object('id', v_id, 'metric_id', p_metric_id, 'action_type', p_action_type), now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_customer_success_status_r1994(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_customer_success_metric_r1994 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(id, actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (gen_random_uuid(), auth.uid(), (auth.jwt()->>'email'), 'mark_customer_success_status_r1994', jsonb_build_object('id', p_id, 'status', p_status), now());
END;
$$;

CREATE OR REPLACE FUNCTION public.customer_success_trend_r1994()
RETURNS TABLE(period_label text, composite_success_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.period_label, m.composite_success_score, m.status, m.captured_at
    FROM public.founder_customer_success_metric_r1994 m ORDER BY m.captured_at DESC LIMIT 24;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_customer_success_actions_r1994()
RETURNS SETOF public.founder_customer_success_action_log_r1994
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_customer_success_action_log_r1994 ORDER BY taken_at DESC LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_customer_success_metrics_r1994() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_customer_success_metric_r1994(text, numeric, int, numeric, numeric, numeric, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_customer_success_actions_r1994(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_customer_success_action_r1994(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_customer_success_status_r1994(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.customer_success_trend_r1994() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_customer_success_actions_r1994() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_customer_success_metrics_r1994() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_customer_success_metric_r1994(text, numeric, int, numeric, numeric, numeric, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_customer_success_actions_r1994(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_customer_success_action_r1994(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_customer_success_status_r1994(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.customer_success_trend_r1994() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_customer_success_actions_r1994() TO authenticated;

COMMIT;
