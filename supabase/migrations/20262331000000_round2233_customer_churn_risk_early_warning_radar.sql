BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_churn_signals_r2233 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  hospital_name text NOT NULL,
  usage_drop_pct numeric(6,2) NOT NULL DEFAULT 0,
  open_complaints int NOT NULL DEFAULT 0,
  payment_delay_days int NOT NULL DEFAULT 0,
  nps_drop_points numeric(5,2) NOT NULL DEFAULT 0,
  composite_risk_score numeric(5,2) NOT NULL DEFAULT 0,
  risk_band text NOT NULL DEFAULT 'low' CHECK (risk_band IN ('low','medium','high','critical')),
  last_amc_renewal_at timestamptz,
  monthly_revenue_rupees int NOT NULL DEFAULT 0,
  notes text,
  detected_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_churn_actions_r2233 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_id uuid NOT NULL REFERENCES public.customer_churn_signals_r2233(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('call','visit','discount_offer','escalate','exec_review','closed_won','closed_lost')),
  action_summary text NOT NULL,
  outcome text,
  follow_up_at timestamptz,
  action_taken_by uuid REFERENCES public.profiles(id),
  action_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_churn_signals_r2233 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_churn_actions_r2233 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_churn_signals_r2233;
CREATE POLICY founder_all ON public.customer_churn_signals_r2233
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.customer_churn_actions_r2233;
CREATE POLICY founder_all ON public.customer_churn_actions_r2233
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_ccs_r2233_band ON public.customer_churn_signals_r2233(risk_band, composite_risk_score DESC);
CREATE INDEX IF NOT EXISTS idx_ccs_r2233_detected ON public.customer_churn_signals_r2233(detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_cca_r2233_signal ON public.customer_churn_actions_r2233(signal_id, action_at DESC);

CREATE OR REPLACE FUNCTION public.founder_churn_radar_overview_r2233()
RETURNS TABLE(total_at_risk int, critical_count int, high_count int, medium_count int, low_count int, revenue_at_risk_rupees int, avg_risk_score numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE risk_band IN ('medium','high','critical')))::int,
    (COUNT(*) FILTER (WHERE risk_band = 'critical'))::int,
    (COUNT(*) FILTER (WHERE risk_band = 'high'))::int,
    (COUNT(*) FILTER (WHERE risk_band = 'medium'))::int,
    (COUNT(*) FILTER (WHERE risk_band = 'low'))::int,
    (COALESCE(SUM(monthly_revenue_rupees) FILTER (WHERE risk_band IN ('high','critical')),0))::int,
    COALESCE(ROUND(AVG(composite_risk_score)::numeric, 2), 0)
  FROM public.customer_churn_signals_r2233;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_churn_radar_signals_r2233()
RETURNS SETOF public.customer_churn_signals_r2233
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.customer_churn_signals_r2233
  ORDER BY composite_risk_score DESC, detected_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_churn_radar_critical_r2233()
RETURNS SETOF public.customer_churn_signals_r2233
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.customer_churn_signals_r2233
  WHERE risk_band = 'critical'
  ORDER BY composite_risk_score DESC LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_churn_radar_actions_r2233()
RETURNS SETOF public.customer_churn_actions_r2233
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.customer_churn_actions_r2233
  ORDER BY action_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_churn_radar_by_band_r2233()
RETURNS TABLE(risk_band text, hospital_count int, total_revenue_rupees int, avg_score numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.risk_band, COUNT(*)::int, COALESCE(SUM(s.monthly_revenue_rupees),0)::int, COALESCE(ROUND(AVG(s.composite_risk_score)::numeric,2),0)
  FROM public.customer_churn_signals_r2233 s
  GROUP BY s.risk_band
  ORDER BY (CASE s.risk_band WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END);
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_churn_radar_action_types_r2233()
RETURNS TABLE(action_type text, action_count int, latest_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_type, COUNT(*)::int, MAX(a.action_at)
  FROM public.customer_churn_actions_r2233 a
  GROUP BY a.action_type
  ORDER BY COUNT(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_churn_radar_followups_r2233()
RETURNS SETOF public.customer_churn_actions_r2233
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.customer_churn_actions_r2233
  WHERE follow_up_at IS NOT NULL AND follow_up_at > now()
  ORDER BY follow_up_at ASC LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_churn_radar_overview_r2233() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_churn_radar_signals_r2233() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_churn_radar_critical_r2233() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_churn_radar_actions_r2233() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_churn_radar_by_band_r2233() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_churn_radar_action_types_r2233() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_churn_radar_followups_r2233() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_churn_radar_overview_r2233() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_churn_radar_signals_r2233() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_churn_radar_critical_r2233() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_churn_radar_actions_r2233() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_churn_radar_by_band_r2233() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_churn_radar_action_types_r2233() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_churn_radar_followups_r2233() TO authenticated;

COMMIT;
