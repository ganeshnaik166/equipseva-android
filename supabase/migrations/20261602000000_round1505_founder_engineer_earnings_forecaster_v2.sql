BEGIN;

-- Forecaster v2 snapshot table
CREATE TABLE IF NOT EXISTS public.founder_engineer_earnings_forecast_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  forecast_month date NOT NULL,
  rolling_90d_total_rupees bigint NOT NULL DEFAULT 0,
  rolling_90d_jobs_count integer NOT NULL DEFAULT 0,
  amc_visits_scheduled integer NOT NULL DEFAULT 0,
  amc_visit_revenue_rupees bigint NOT NULL DEFAULT 0,
  tier_cap_rupees bigint NOT NULL DEFAULT 0,
  predicted_earnings_rupees bigint NOT NULL DEFAULT 0,
  prior_month_earnings_rupees bigint NOT NULL DEFAULT 0,
  drop_pct numeric(6,2) NOT NULL DEFAULT 0,
  is_cliff boolean NOT NULL DEFAULT false,
  cliff_severity text NOT NULL DEFAULT 'none',
  computed_at timestamptz NOT NULL DEFAULT now(),
  notes text
);

CREATE INDEX IF NOT EXISTS idx_feefv2_engineer ON public.founder_engineer_earnings_forecast_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_feefv2_month ON public.founder_engineer_earnings_forecast_v2(forecast_month);
CREATE INDEX IF NOT EXISTS idx_feefv2_cliff ON public.founder_engineer_earnings_forecast_v2(is_cliff) WHERE is_cliff = true;

ALTER TABLE public.founder_engineer_earnings_forecast_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS feefv2_founder_all ON public.founder_engineer_earnings_forecast_v2;
CREATE POLICY feefv2_founder_all
  ON public.founder_engineer_earnings_forecast_v2
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Cliff alerts table
CREATE TABLE IF NOT EXISTS public.founder_earnings_cliff_alerts_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  forecast_month date NOT NULL,
  drop_pct numeric(6,2) NOT NULL,
  severity text NOT NULL DEFAULT 'high',
  acknowledged boolean NOT NULL DEFAULT false,
  acknowledged_by uuid REFERENCES auth.users(id),
  acknowledged_at timestamptz,
  resolution_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fecav2_engineer ON public.founder_earnings_cliff_alerts_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_fecav2_open ON public.founder_earnings_cliff_alerts_v2(acknowledged) WHERE acknowledged = false;

ALTER TABLE public.founder_earnings_cliff_alerts_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fecav2_founder_all ON public.founder_earnings_cliff_alerts_v2;
CREATE POLICY fecav2_founder_all
  ON public.founder_earnings_cliff_alerts_v2
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============ READ RPCs (STABLE) ============

CREATE OR REPLACE FUNCTION public.founder_eef_v2_summary()
RETURNS TABLE(
  total_engineers integer,
  total_forecast_rupees bigint,
  total_prior_rupees bigint,
  forecast_delta_rupees bigint,
  cliff_count integer,
  amc_visits_total integer,
  tier_cap_total bigint,
  avg_drop_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(DISTINCT f.engineer_id)::integer,
    COALESCE(SUM(f.predicted_earnings_rupees),0)::bigint,
    COALESCE(SUM(f.prior_month_earnings_rupees),0)::bigint,
    COALESCE(SUM(f.predicted_earnings_rupees) - SUM(f.prior_month_earnings_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE f.is_cliff)::integer,
    COALESCE(SUM(f.amc_visits_scheduled),0)::integer,
    COALESCE(SUM(f.tier_cap_rupees),0)::bigint,
    COALESCE(AVG(f.drop_pct),0)::numeric
  FROM founder_engineer_earnings_forecast_v2 f
  WHERE f.forecast_month = date_trunc('month', now() + interval '1 month')::date;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_eef_v2_top_forecasts(p_limit integer DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  tier text,
  predicted_earnings_rupees bigint,
  prior_month_earnings_rupees bigint,
  drop_pct numeric,
  amc_visits_scheduled integer,
  tier_cap_rupees bigint,
  is_cliff boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.engineer_id, COALESCE(p.full_name, p.email, e.id::text),
         COALESCE(e.cached_highest_tier,'none'),
         f.predicted_earnings_rupees, f.prior_month_earnings_rupees, f.drop_pct,
         f.amc_visits_scheduled, f.tier_cap_rupees, f.is_cliff
  FROM founder_engineer_earnings_forecast_v2 f
  JOIN engineers e ON e.id = f.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE f.forecast_month = date_trunc('month', now() + interval '1 month')::date
  ORDER BY f.predicted_earnings_rupees DESC
  LIMIT GREATEST(1, COALESCE(p_limit,50));
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_eef_v2_cliffs(p_limit integer DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  tier text,
  drop_pct numeric,
  predicted_earnings_rupees bigint,
  prior_month_earnings_rupees bigint,
  severity text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.engineer_id, COALESCE(p.full_name, p.email, e.id::text),
         COALESCE(e.cached_highest_tier,'none'),
         f.drop_pct, f.predicted_earnings_rupees, f.prior_month_earnings_rupees,
         f.cliff_severity
  FROM founder_engineer_earnings_forecast_v2 f
  JOIN engineers e ON e.id = f.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE f.forecast_month = date_trunc('month', now() + interval '1 month')::date
    AND f.is_cliff = true
  ORDER BY f.drop_pct DESC
  LIMIT GREATEST(1, COALESCE(p_limit,50));
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_eef_v2_tier_breakdown()
RETURNS TABLE(
  tier text,
  engineer_count integer,
  forecast_total_rupees bigint,
  prior_total_rupees bigint,
  avg_drop_pct numeric,
  cliff_count integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(e.cached_highest_tier,'none'),
         COUNT(*)::integer,
         COALESCE(SUM(f.predicted_earnings_rupees),0)::bigint,
         COALESCE(SUM(f.prior_month_earnings_rupees),0)::bigint,
         COALESCE(AVG(f.drop_pct),0)::numeric,
         COUNT(*) FILTER (WHERE f.is_cliff)::integer
  FROM founder_engineer_earnings_forecast_v2 f
  JOIN engineers e ON e.id = f.engineer_id
  WHERE f.forecast_month = date_trunc('month', now() + interval '1 month')::date
  GROUP BY COALESCE(e.cached_highest_tier,'none')
  ORDER BY 3 DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_eef_v2_open_cliff_alerts(p_limit integer DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  drop_pct numeric,
  severity text,
  age_hours numeric,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_id, COALESCE(p.full_name, p.email, e.id::text),
         a.drop_pct, a.severity,
         (EXTRACT(EPOCH FROM (now() - a.created_at))/3600.0)::numeric,
         a.created_at
  FROM founder_earnings_cliff_alerts_v2 a
  JOIN engineers e ON e.id = a.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE a.acknowledged = false
  ORDER BY a.drop_pct DESC, a.created_at ASC
  LIMIT GREATEST(1, COALESCE(p_limit,50));
END;
$$;

-- ============ WRITE RPCs (VOLATILE) ============

CREATE OR REPLACE FUNCTION public.founder_eef_v2_recompute()
RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_month date := date_trunc('month', now() + interval '1 month')::date;
  v_count integer := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  DELETE FROM founder_engineer_earnings_forecast_v2 WHERE forecast_month = v_month;

  INSERT INTO founder_engineer_earnings_forecast_v2(
    engineer_id, forecast_month, rolling_90d_total_rupees, rolling_90d_jobs_count,
    amc_visits_scheduled, amc_visit_revenue_rupees, tier_cap_rupees,
    predicted_earnings_rupees, prior_month_earnings_rupees, drop_pct, is_cliff, cliff_severity
  )
  SELECT
    e.id,
    v_month,
    COALESCE(r90.total_rupees, 0),
    COALESCE(r90.jobs_count, 0),
    COALESCE(amc.visits, 0),
    COALESCE(amc.visits, 0) * 1500,
    CASE COALESCE(e.cached_highest_tier,'none')
      WHEN 'pro' THEN 200000
      WHEN 'bgc' THEN 150000
      WHEN 'gst' THEN 120000
      WHEN 'pan' THEN 90000
      WHEN 'aadhaar' THEN 60000
      ELSE 40000
    END,
    LEAST(
      CASE COALESCE(e.cached_highest_tier,'none')
        WHEN 'pro' THEN 200000
        WHEN 'bgc' THEN 150000
        WHEN 'gst' THEN 120000
        WHEN 'pan' THEN 90000
        WHEN 'aadhaar' THEN 60000
        ELSE 40000
      END,
      (COALESCE(r90.total_rupees,0) / 3) + (COALESCE(amc.visits,0) * 1500)
    ),
    COALESCE(prior.total_rupees, 0),
    CASE
      WHEN COALESCE(prior.total_rupees,0) = 0 THEN 0
      ELSE GREATEST(0, ROUND(((prior.total_rupees - LEAST(
        CASE COALESCE(e.cached_highest_tier,'none')
          WHEN 'pro' THEN 200000 WHEN 'bgc' THEN 150000 WHEN 'gst' THEN 120000
          WHEN 'pan' THEN 90000 WHEN 'aadhaar' THEN 60000 ELSE 40000
        END,
        (COALESCE(r90.total_rupees,0) / 3) + (COALESCE(amc.visits,0) * 1500)
      ))::numeric / NULLIF(prior.total_rupees,0)::numeric) * 100, 2))
    END,
    CASE
      WHEN COALESCE(prior.total_rupees,0) = 0 THEN false
      WHEN (prior.total_rupees - LEAST(
        CASE COALESCE(e.cached_highest_tier,'none')
          WHEN 'pro' THEN 200000 WHEN 'bgc' THEN 150000 WHEN 'gst' THEN 120000
          WHEN 'pan' THEN 90000 WHEN 'aadhaar' THEN 60000 ELSE 40000
        END,
        (COALESCE(r90.total_rupees,0) / 3) + (COALESCE(amc.visits,0) * 1500)
      )) * 100 / NULLIF(prior.total_rupees,0) > 30 THEN true
      ELSE false
    END,
    CASE
      WHEN COALESCE(prior.total_rupees,0) = 0 THEN 'none'
      WHEN (prior.total_rupees - LEAST(
        CASE COALESCE(e.cached_highest_tier,'none')
          WHEN 'pro' THEN 200000 WHEN 'bgc' THEN 150000 WHEN 'gst' THEN 120000
          WHEN 'pan' THEN 90000 WHEN 'aadhaar' THEN 60000 ELSE 40000
        END,
        (COALESCE(r90.total_rupees,0) / 3) + (COALESCE(amc.visits,0) * 1500)
      )) * 100 / NULLIF(prior.total_rupees,0) > 50 THEN 'critical'
      WHEN (prior.total_rupees - LEAST(
        CASE COALESCE(e.cached_highest_tier,'none')
          WHEN 'pro' THEN 200000 WHEN 'bgc' THEN 150000 WHEN 'gst' THEN 120000
          WHEN 'pan' THEN 90000 WHEN 'aadhaar' THEN 60000 ELSE 40000
        END,
        (COALESCE(r90.total_rupees,0) / 3) + (COALESCE(amc.visits,0) * 1500)
      )) * 100 / NULLIF(prior.total_rupees,0) > 30 THEN 'high'
      ELSE 'none'
    END
  FROM engineers e
  LEFT JOIN LATERAL (
    SELECT SUM(ep.amount_rupees)::bigint AS total_rupees, COUNT(*)::integer AS jobs_count
    FROM engineer_payouts ep
    WHERE ep.engineer_user_id = e.user_id
      AND ep.created_at >= now() - interval '90 days'
  ) r90 ON true
  LEFT JOIN LATERAL (
    SELECT SUM(ep.amount_rupees)::bigint AS total_rupees
    FROM engineer_payouts ep
    WHERE ep.engineer_user_id = e.user_id
      AND ep.created_at >= date_trunc('month', now() - interval '1 month')
      AND ep.created_at < date_trunc('month', now())
  ) prior ON true
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::integer AS visits
    FROM repair_jobs rj
    WHERE rj.engineer_id = e.id
      AND rj.kind = 'maintenance'
      AND rj.scheduled_at >= date_trunc('month', now() + interval '1 month')
      AND rj.scheduled_at < date_trunc('month', now() + interval '2 month')
  ) amc ON true;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO founder_earnings_cliff_alerts_v2(engineer_id, forecast_month, drop_pct, severity)
  SELECT f.engineer_id, f.forecast_month, f.drop_pct, f.cliff_severity
  FROM founder_engineer_earnings_forecast_v2 f
  WHERE f.forecast_month = v_month AND f.is_cliff = true
    AND NOT EXISTS (
      SELECT 1 FROM founder_earnings_cliff_alerts_v2 a
      WHERE a.engineer_id = f.engineer_id AND a.forecast_month = f.forecast_month
    );

  PERFORM log_founder_eef_v2_recompute(v_count, v_month);
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_eef_v2_ack_cliff_alert(p_alert_id uuid, p_note text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_earnings_cliff_alerts_v2
  SET acknowledged = true, acknowledged_by = auth.uid(), acknowledged_at = now(), resolution_note = p_note
  WHERE id = p_alert_id;
  PERFORM log_founder_eef_v2_ack(p_alert_id, p_note);
END;
$$;

-- ============ log_founder_* helpers ============

CREATE OR REPLACE FUNCTION public.log_founder_eef_v2_recompute(p_count integer, p_month date)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_email text;
BEGIN
  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'eef_v2_recompute',
    jsonb_build_object('rows', p_count, 'forecast_month', p_month));
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_eef_v2_ack(p_alert_id uuid, p_note text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_email text;
BEGIN
  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'eef_v2_ack_cliff',
    jsonb_build_object('alert_id', p_alert_id, 'note', p_note));
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_eef_v2_view(p_view text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_email text;
BEGIN
  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'eef_v2_view',
    jsonb_build_object('view', p_view, 'at', now()));
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_eef_v2_export(p_count integer)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_email text;
BEGIN
  SELECT email INTO v_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'eef_v2_export',
    jsonb_build_object('count', p_count));
END;
$$;

-- ============ GRANTS ============

REVOKE EXECUTE ON FUNCTION public.founder_eef_v2_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_eef_v2_top_forecasts(integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_eef_v2_cliffs(integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_eef_v2_tier_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_eef_v2_open_cliff_alerts(integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_eef_v2_recompute() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_eef_v2_ack_cliff_alert(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_eef_v2_recompute(integer, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_eef_v2_ack(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_eef_v2_view(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_eef_v2_export(integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_eef_v2_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_eef_v2_top_forecasts(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_eef_v2_cliffs(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_eef_v2_tier_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_eef_v2_open_cliff_alerts(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_eef_v2_recompute() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_eef_v2_ack_cliff_alert(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_eef_v2_recompute(integer, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_eef_v2_ack(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_eef_v2_view(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_eef_v2_export(integer) TO authenticated;

COMMIT;