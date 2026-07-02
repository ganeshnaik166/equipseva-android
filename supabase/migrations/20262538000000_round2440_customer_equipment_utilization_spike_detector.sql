-- Round 2440: Customer Equipment Utilization Spike Detector
-- Detects usage spikes against baseline, surfaces revenue uplift opportunities + cross-sell hints.

BEGIN;

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.equipment_utilization_spikes_r2440 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  equipment_kind text NOT NULL
    CHECK (equipment_kind IN ('ventilator','dialysis','mri','ct','xray','ultrasound','monitor','infusion_pump','autoclave','centrifuge','anesthesia','ecg','other')),
  baseline_usage_pct numeric NOT NULL CHECK (baseline_usage_pct >= 0 AND baseline_usage_pct <= 100),
  current_usage_pct numeric NOT NULL CHECK (current_usage_pct >= 0 AND current_usage_pct <= 100),
  delta_pct numeric NOT NULL,
  observation_period_start date NOT NULL,
  observation_period_end date NOT NULL,
  revenue_uplift_estimate_rupees bigint NOT NULL DEFAULT 0 CHECK (revenue_uplift_estimate_rupees >= 0),
  cross_sell_hint text,
  owner_email text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','contacted','quoted','won','lost','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (observation_period_end >= observation_period_start)
);

CREATE INDEX IF NOT EXISTS idx_spikes_r2440_status       ON public.equipment_utilization_spikes_r2440(status);
CREATE INDEX IF NOT EXISTS idx_spikes_r2440_kind         ON public.equipment_utilization_spikes_r2440(equipment_kind);
CREATE INDEX IF NOT EXISTS idx_spikes_r2440_hospital     ON public.equipment_utilization_spikes_r2440(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_spikes_r2440_period_end   ON public.equipment_utilization_spikes_r2440(observation_period_end);
CREATE INDEX IF NOT EXISTS idx_spikes_r2440_uplift       ON public.equipment_utilization_spikes_r2440(revenue_uplift_estimate_rupees);

CREATE TABLE IF NOT EXISTS public.utilization_action_log_r2440 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spike_id uuid NOT NULL REFERENCES public.equipment_utilization_spikes_r2440(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL
    CHECK (action_kind IN ('call','email','visit','quote','upsell')),
  owner_email text,
  outcome text NOT NULL DEFAULT 'pending'
    CHECK (outcome IN ('positive','neutral','negative','pending')),
  outcome_notes text,
  follow_up_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_action_r2440_spike        ON public.utilization_action_log_r2440(spike_id);
CREATE INDEX IF NOT EXISTS idx_action_r2440_observed_at  ON public.utilization_action_log_r2440(observed_at);
CREATE INDEX IF NOT EXISTS idx_action_r2440_kind         ON public.utilization_action_log_r2440(action_kind);
CREATE INDEX IF NOT EXISTS idx_action_r2440_outcome      ON public.utilization_action_log_r2440(outcome);
CREATE INDEX IF NOT EXISTS idx_action_r2440_follow_up    ON public.utilization_action_log_r2440(follow_up_at);

-- ============================================================================
-- RLS
-- ============================================================================

ALTER TABLE public.equipment_utilization_spikes_r2440 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.utilization_action_log_r2440 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.equipment_utilization_spikes_r2440;
CREATE POLICY founder_all ON public.equipment_utilization_spikes_r2440
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.utilization_action_log_r2440;
CREATE POLICY founder_all ON public.utilization_action_log_r2440
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED
-- ============================================================================

INSERT INTO public.equipment_utilization_spikes_r2440
  (id, hospital_user_id, equipment_label, equipment_kind, baseline_usage_pct, current_usage_pct, delta_pct, observation_period_start, observation_period_end, revenue_uplift_estimate_rupees, cross_sell_hint, owner_email, status, notes)
VALUES
  ('aaaaaaa1-0000-4000-8000-000000000001', NULL, 'Ventilator Bay 3 - Apollo Jubilee', 'ventilator',    42.0, 88.5, 46.5, (now() - interval '30 days')::date, (now() - interval '1 day')::date, 320000, 'Sell second ventilator + AMC Gold tier', 'founder@equipseva.in', 'open',      'Sustained 4-week spike post-monsoon respiratory wave'),
  ('aaaaaaa1-0000-4000-8000-000000000002', NULL, 'Dialysis Station 2 - Yashoda Somajiguda', 'dialysis',   55.0, 92.0, 37.0, (now() - interval '60 days')::date, (now() - interval '1 day')::date, 540000, 'Upgrade to 8-station bank + spare cartridges AMC', 'founder@equipseva.in', 'contacted', 'Chain CTO interested in chain-wide refresh'),
  ('aaaaaaa1-0000-4000-8000-000000000003', NULL, 'MRI 1.5T - KIMS Secunderabad', 'mri',                75.0, 96.5, 21.5, (now() - interval '45 days')::date, (now() - interval '1 day')::date, 1250000, 'AMC Platinum + helium supply contract', 'founder@equipseva.in', 'quoted',    'Awaiting board-level capex approval'),
  ('aaaaaaa1-0000-4000-8000-000000000004', NULL, 'Patient Monitor - Continental Gachibowli', 'monitor', 38.0, 71.0, 33.0, (now() - interval '21 days')::date, (now() - interval '1 day')::date, 85000, 'Cross-sell central station + 6 add-on monitors', 'founder@equipseva.in', 'won',       'PO received for 6 add-on monitors at INR 85k uplift/yr'),
  ('aaaaaaa1-0000-4000-8000-000000000005', NULL, 'CT Scanner 64-slice - Sunshine Paradise', 'ct',       60.0, 89.0, 29.0, (now() - interval '14 days')::date, (now() - interval '1 day')::date, 0, 'Patient backlog suggests second scanner; capex unlikely this FY', 'founder@equipseva.in', 'dropped', 'Capex frozen; revisit Q3');

INSERT INTO public.utilization_action_log_r2440
  (spike_id, observed_at, action_kind, owner_email, outcome, outcome_notes, follow_up_at, notes)
VALUES
  ('aaaaaaa1-0000-4000-8000-000000000002', now() - interval '6 days',  'call',   'founder@equipseva.in', 'positive', 'CTO wants chain-wide proposal',           now() + interval '2 days',  'Schedule site visit'),
  ('aaaaaaa1-0000-4000-8000-000000000002', now() - interval '2 days',  'email',  'founder@equipseva.in', 'neutral',  'Sent capacity-planning deck',             now() + interval '5 days',  'Follow up if no reply'),
  ('aaaaaaa1-0000-4000-8000-000000000003', now() - interval '10 days', 'visit',  'founder@equipseva.in', 'positive', 'Walkthrough with radiology head',         now() + interval '7 days',  'Push for board memo'),
  ('aaaaaaa1-0000-4000-8000-000000000003', now() - interval '4 days',  'quote',  'founder@equipseva.in', 'pending',  'Quote sent: AMC Platinum + helium SLA',   now() + interval '10 days', NULL),
  ('aaaaaaa1-0000-4000-8000-000000000004', now() - interval '12 days', 'upsell', 'founder@equipseva.in', 'positive', 'PO confirmed for 6 monitors',             NULL,                       'Closed-won'),
  ('aaaaaaa1-0000-4000-8000-000000000001', now() - interval '1 day',   'call',   'founder@equipseva.in', 'pending',  'Left voicemail with biomed engineer',     now() + interval '3 days',  'First touch'),
  ('aaaaaaa1-0000-4000-8000-000000000005', now() - interval '8 days',  'call',   'founder@equipseva.in', 'negative', 'Capex frozen this FY; revisit Q3 2026', now() + interval '90 days', 'Cold for now');

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_spikes_r2440()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  equipment_kind text,
  baseline_usage_pct numeric,
  current_usage_pct numeric,
  delta_pct numeric,
  observation_period_start date,
  observation_period_end date,
  revenue_uplift_estimate_rupees bigint,
  cross_sell_hint text,
  owner_email text,
  status text,
  action_count bigint,
  last_action_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.equipment_label,
    s.equipment_kind,
    s.baseline_usage_pct,
    s.current_usage_pct,
    s.delta_pct,
    s.observation_period_start,
    s.observation_period_end,
    s.revenue_uplift_estimate_rupees,
    s.cross_sell_hint,
    s.owner_email,
    s.status,
    COALESCE(COUNT(a.id), 0)::bigint AS action_count,
    MAX(a.observed_at) AS last_action_at,
    s.notes
  FROM public.equipment_utilization_spikes_r2440 s
  LEFT JOIN public.utilization_action_log_r2440 a ON a.spike_id = s.id
  GROUP BY s.id
  ORDER BY
    CASE s.status WHEN 'open' THEN 0 WHEN 'contacted' THEN 1 WHEN 'quoted' THEN 2 WHEN 'won' THEN 3 WHEN 'lost' THEN 4 ELSE 5 END,
    s.revenue_uplift_estimate_rupees DESC,
    s.delta_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_spikes_r2440() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_spikes_r2440() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_action_log_r2440()
RETURNS TABLE (
  id uuid,
  spike_id uuid,
  equipment_label text,
  equipment_kind text,
  observed_at timestamptz,
  action_kind text,
  owner_email text,
  outcome text,
  outcome_notes text,
  follow_up_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.spike_id,
    s.equipment_label,
    s.equipment_kind,
    a.observed_at,
    a.action_kind,
    a.owner_email,
    a.outcome,
    a.outcome_notes,
    a.follow_up_at,
    a.notes
  FROM public.utilization_action_log_r2440 a
  JOIN public.equipment_utilization_spikes_r2440 s ON s.id = a.spike_id
  ORDER BY a.observed_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_action_log_r2440() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_action_log_r2440() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_revenue_uplift_r2440()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  equipment_kind text,
  delta_pct numeric,
  revenue_uplift_estimate_rupees bigint,
  cross_sell_hint text,
  status text,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.equipment_label,
    s.equipment_kind,
    s.delta_pct,
    s.revenue_uplift_estimate_rupees,
    s.cross_sell_hint,
    s.status,
    s.owner_email
  FROM public.equipment_utilization_spikes_r2440 s
  WHERE s.status NOT IN ('won','lost','dropped')
  ORDER BY s.revenue_uplift_estimate_rupees DESC, s.delta_pct DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_revenue_uplift_r2440() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_revenue_uplift_r2440() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2440()
RETURNS TABLE (
  status text,
  spike_count bigint,
  total_uplift_rupees bigint,
  avg_delta_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.status,
    COUNT(*)::bigint AS spike_count,
    COALESCE(SUM(s.revenue_uplift_estimate_rupees), 0)::bigint AS total_uplift_rupees,
    ROUND(AVG(s.delta_pct)::numeric, 1) AS avg_delta_pct
  FROM public.equipment_utilization_spikes_r2440 s
  GROUP BY s.status
  ORDER BY
    CASE s.status WHEN 'open' THEN 0 WHEN 'contacted' THEN 1 WHEN 'quoted' THEN 2 WHEN 'won' THEN 3 WHEN 'lost' THEN 4 ELSE 5 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2440() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2440() TO authenticated;

CREATE OR REPLACE FUNCTION public.equipment_kind_summary_r2440()
RETURNS TABLE (
  equipment_kind text,
  spike_count bigint,
  avg_baseline_pct numeric,
  avg_current_pct numeric,
  avg_delta_pct numeric,
  total_uplift_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.equipment_kind,
    COUNT(*)::bigint AS spike_count,
    ROUND(AVG(s.baseline_usage_pct)::numeric, 1) AS avg_baseline_pct,
    ROUND(AVG(s.current_usage_pct)::numeric, 1) AS avg_current_pct,
    ROUND(AVG(s.delta_pct)::numeric, 1) AS avg_delta_pct,
    COALESCE(SUM(s.revenue_uplift_estimate_rupees), 0)::bigint AS total_uplift_rupees
  FROM public.equipment_utilization_spikes_r2440 s
  GROUP BY s.equipment_kind
  ORDER BY total_uplift_rupees DESC, spike_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.equipment_kind_summary_r2440() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipment_kind_summary_r2440() TO authenticated;

CREATE OR REPLACE FUNCTION public.this_week_action_calendar_r2440()
RETURNS TABLE (
  spike_id uuid,
  equipment_label text,
  equipment_kind text,
  action_kind text,
  owner_email text,
  follow_up_at timestamptz,
  outcome text,
  hours_until_due numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.spike_id,
    s.equipment_label,
    s.equipment_kind,
    a.action_kind,
    a.owner_email,
    a.follow_up_at,
    a.outcome,
    ROUND(EXTRACT(EPOCH FROM (a.follow_up_at - now())) / 3600.0, 1) AS hours_until_due
  FROM public.utilization_action_log_r2440 a
  JOIN public.equipment_utilization_spikes_r2440 s ON s.id = a.spike_id
  WHERE a.follow_up_at IS NOT NULL
    AND a.follow_up_at >= now()
    AND a.follow_up_at < now() + interval '7 days'
  ORDER BY a.follow_up_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.this_week_action_calendar_r2440() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.this_week_action_calendar_r2440() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_spike_trend_r2440()
RETURNS TABLE (
  month_start date,
  spike_count bigint,
  avg_delta_pct numeric,
  total_uplift_rupees bigint,
  won_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('month', s.observation_period_end)::date AS month_start,
    COUNT(*)::bigint AS spike_count,
    ROUND(AVG(s.delta_pct)::numeric, 1) AS avg_delta_pct,
    COALESCE(SUM(s.revenue_uplift_estimate_rupees), 0)::bigint AS total_uplift_rupees,
    COALESCE(SUM(CASE WHEN s.status = 'won' THEN 1 ELSE 0 END), 0)::bigint AS won_count
  FROM public.equipment_utilization_spikes_r2440 s
  GROUP BY date_trunc('month', s.observation_period_end)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_spike_trend_r2440() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_spike_trend_r2440() TO authenticated;

