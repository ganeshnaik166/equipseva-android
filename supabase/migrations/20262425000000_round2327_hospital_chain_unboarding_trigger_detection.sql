BEGIN;

-- ============================================================================
-- r2327: Hospital chain unboarding-trigger detection
-- Track signals 30/60/90 days before chain churn to predict departures
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.chain_unboarding_signals_r2327 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  chain_name text NOT NULL,
  signal_type text NOT NULL CHECK (signal_type IN (
    'usage_drop',
    'payment_delay',
    'ticket_spike',
    'nps_decline',
    'exec_contact_lost',
    'amc_non_renewal',
    'competitor_inquiry',
    'volume_decline',
    'escalation_increase',
    'engagement_drop'
  )),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  days_before_potential_churn int NOT NULL CHECK (days_before_potential_churn IN (30, 60, 90)),
  signal_value_numeric numeric,
  signal_value_text text,
  baseline_value numeric,
  delta_pct numeric,
  detected_at timestamptz NOT NULL DEFAULT now(),
  detection_window_days int NOT NULL DEFAULT 7,
  acknowledged_by uuid REFERENCES public.profiles(id),
  acknowledged_at timestamptz,
  resolved_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_unboarding_signals_r2327_chain
  ON public.chain_unboarding_signals_r2327(chain_org_id);
CREATE INDEX IF NOT EXISTS idx_chain_unboarding_signals_r2327_detected
  ON public.chain_unboarding_signals_r2327(detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_chain_unboarding_signals_r2327_severity
  ON public.chain_unboarding_signals_r2327(severity, days_before_potential_churn);

ALTER TABLE public.chain_unboarding_signals_r2327 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_unboarding_signals_r2327;
CREATE POLICY founder_all ON public.chain_unboarding_signals_r2327
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- chain_churn_risk_scores_r2327: rolled-up risk per chain
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.chain_churn_risk_scores_r2327 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  chain_name text NOT NULL,
  risk_score int NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
  risk_band text NOT NULL CHECK (risk_band IN ('green','yellow','orange','red')),
  active_signal_count int NOT NULL DEFAULT 0,
  critical_signal_count int NOT NULL DEFAULT 0,
  predicted_churn_window_days int,
  arr_at_risk_rupees bigint NOT NULL DEFAULT 0,
  primary_trigger text,
  last_recomputed_at timestamptz NOT NULL DEFAULT now(),
  assigned_owner_id uuid REFERENCES public.profiles(id),
  intervention_status text NOT NULL DEFAULT 'none' CHECK (intervention_status IN (
    'none','assigned','in_progress','recovered','lost'
  )),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_org_id)
);

CREATE INDEX IF NOT EXISTS idx_chain_churn_risk_scores_r2327_band
  ON public.chain_churn_risk_scores_r2327(risk_band, risk_score DESC);
CREATE INDEX IF NOT EXISTS idx_chain_churn_risk_scores_r2327_arr
  ON public.chain_churn_risk_scores_r2327(arr_at_risk_rupees DESC);

ALTER TABLE public.chain_churn_risk_scores_r2327 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_churn_risk_scores_r2327;
CREATE POLICY founder_all ON public.chain_churn_risk_scores_r2327
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: dashboard summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2327_dashboard_summary();
CREATE OR REPLACE FUNCTION public.r2327_dashboard_summary()
RETURNS TABLE (
  total_chains_tracked bigint,
  red_band_chains bigint,
  orange_band_chains bigint,
  yellow_band_chains bigint,
  green_band_chains bigint,
  total_arr_at_risk_rupees bigint,
  active_signals_30d bigint,
  active_signals_60d bigint,
  active_signals_90d bigint,
  critical_signals_open bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.chain_churn_risk_scores_r2327),
    (SELECT count(*) FROM public.chain_churn_risk_scores_r2327 WHERE risk_band = 'red'),
    (SELECT count(*) FROM public.chain_churn_risk_scores_r2327 WHERE risk_band = 'orange'),
    (SELECT count(*) FROM public.chain_churn_risk_scores_r2327 WHERE risk_band = 'yellow'),
    (SELECT count(*) FROM public.chain_churn_risk_scores_r2327 WHERE risk_band = 'green'),
    COALESCE((SELECT sum(arr_at_risk_rupees) FROM public.chain_churn_risk_scores_r2327 WHERE risk_band IN ('orange','red')), 0)::bigint,
    (SELECT count(*) FROM public.chain_unboarding_signals_r2327 WHERE days_before_potential_churn = 30 AND resolved_at IS NULL),
    (SELECT count(*) FROM public.chain_unboarding_signals_r2327 WHERE days_before_potential_churn = 60 AND resolved_at IS NULL),
    (SELECT count(*) FROM public.chain_unboarding_signals_r2327 WHERE days_before_potential_churn = 90 AND resolved_at IS NULL),
    (SELECT count(*) FROM public.chain_unboarding_signals_r2327 WHERE severity = 'critical' AND resolved_at IS NULL);
END $$;
REVOKE ALL ON FUNCTION public.r2327_dashboard_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2327_dashboard_summary() TO authenticated;

-- ============================================================================
-- RPC 2: high-risk chains
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2327_high_risk_chains();
CREATE OR REPLACE FUNCTION public.r2327_high_risk_chains()
RETURNS TABLE (
  id uuid,
  chain_name text,
  risk_score int,
  risk_band text,
  active_signal_count int,
  critical_signal_count int,
  predicted_churn_window_days int,
  arr_at_risk_rupees bigint,
  primary_trigger text,
  intervention_status text,
  last_recomputed_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id, s.chain_name, s.risk_score, s.risk_band,
    s.active_signal_count, s.critical_signal_count,
    s.predicted_churn_window_days, s.arr_at_risk_rupees,
    s.primary_trigger, s.intervention_status, s.last_recomputed_at
  FROM public.chain_churn_risk_scores_r2327 s
  WHERE s.risk_band IN ('orange','red')
  ORDER BY s.risk_score DESC, s.arr_at_risk_rupees DESC
  LIMIT 50;
END $$;
REVOKE ALL ON FUNCTION public.r2327_high_risk_chains() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2327_high_risk_chains() TO authenticated;

-- ============================================================================
-- RPC 3: recent signals
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2327_recent_signals();
CREATE OR REPLACE FUNCTION public.r2327_recent_signals()
RETURNS TABLE (
  id uuid,
  chain_name text,
  signal_type text,
  severity text,
  days_before_potential_churn int,
  delta_pct numeric,
  baseline_value numeric,
  signal_value_numeric numeric,
  detected_at timestamptz,
  acknowledged_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id, s.chain_name, s.signal_type, s.severity,
    s.days_before_potential_churn, s.delta_pct,
    s.baseline_value, s.signal_value_numeric,
    s.detected_at, s.acknowledged_at
  FROM public.chain_unboarding_signals_r2327 s
  WHERE s.resolved_at IS NULL
  ORDER BY s.detected_at DESC
  LIMIT 100;
END $$;
REVOKE ALL ON FUNCTION public.r2327_recent_signals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2327_recent_signals() TO authenticated;

-- ============================================================================
-- RPC 4: signal-type breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2327_signal_type_breakdown();
CREATE OR REPLACE FUNCTION public.r2327_signal_type_breakdown()
RETURNS TABLE (
  signal_type text,
  occurrence_count bigint,
  critical_count bigint,
  high_count bigint,
  avg_days_before_churn numeric,
  chains_affected bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.signal_type,
    count(*)::bigint,
    count(*) FILTER (WHERE s.severity = 'critical')::bigint,
    count(*) FILTER (WHERE s.severity = 'high')::bigint,
    round(avg(s.days_before_potential_churn)::numeric, 1),
    count(DISTINCT s.chain_org_id)::bigint
  FROM public.chain_unboarding_signals_r2327 s
  GROUP BY s.signal_type
  ORDER BY count(*) DESC;
END $$;
REVOKE ALL ON FUNCTION public.r2327_signal_type_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2327_signal_type_breakdown() TO authenticated;

-- ============================================================================
-- RPC 5: churn window distribution
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2327_churn_window_distribution();
CREATE OR REPLACE FUNCTION public.r2327_churn_window_distribution()
RETURNS TABLE (
  window_label text,
  signal_count bigint,
  unique_chains bigint,
  critical_signals bigint,
  arr_at_risk_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (s.days_before_potential_churn::text || ' days')::text,
    count(*)::bigint,
    count(DISTINCT s.chain_org_id)::bigint,
    count(*) FILTER (WHERE s.severity = 'critical')::bigint,
    COALESCE(sum(r.arr_at_risk_rupees), 0)::bigint
  FROM public.chain_unboarding_signals_r2327 s
  LEFT JOIN public.chain_churn_risk_scores_r2327 r ON r.chain_org_id = s.chain_org_id
  WHERE s.resolved_at IS NULL
  GROUP BY s.days_before_potential_churn
  ORDER BY s.days_before_potential_churn ASC;
END $$;
REVOKE ALL ON FUNCTION public.r2327_churn_window_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2327_churn_window_distribution() TO authenticated;

-- ============================================================================
-- RPC 6: intervention status pipeline
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2327_intervention_pipeline();
CREATE OR REPLACE FUNCTION public.r2327_intervention_pipeline()
RETURNS TABLE (
  intervention_status text,
  chain_count bigint,
  total_arr_at_risk_rupees bigint,
  avg_risk_score numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.intervention_status,
    count(*)::bigint,
    COALESCE(sum(r.arr_at_risk_rupees), 0)::bigint,
    round(avg(r.risk_score)::numeric, 1)
  FROM public.chain_churn_risk_scores_r2327 r
  GROUP BY r.intervention_status
  ORDER BY count(*) DESC;
END $$;
REVOKE ALL ON FUNCTION public.r2327_intervention_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2327_intervention_pipeline() TO authenticated;

-- ============================================================================
-- RPC 7: severity distribution
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2327_severity_distribution();
CREATE OR REPLACE FUNCTION public.r2327_severity_distribution()
RETURNS TABLE (
  severity text,
  signal_count bigint,
  acknowledged_count bigint,
  unacknowledged_count bigint,
  avg_delta_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.severity,
    count(*)::bigint,
    count(*) FILTER (WHERE s.acknowledged_at IS NOT NULL)::bigint,
    count(*) FILTER (WHERE s.acknowledged_at IS NULL)::bigint,
    round(avg(s.delta_pct)::numeric, 2)
  FROM public.chain_unboarding_signals_r2327 s
  WHERE s.resolved_at IS NULL
  GROUP BY s.severity
  ORDER BY
    CASE s.severity
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
    END;
END $$;
REVOKE ALL ON FUNCTION public.r2327_severity_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2327_severity_distribution() TO authenticated;

COMMIT;
