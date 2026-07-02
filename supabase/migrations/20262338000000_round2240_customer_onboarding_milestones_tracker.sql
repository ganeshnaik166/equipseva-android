BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_onboarding_journeys_r2240 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  customer_email text,
  customer_phone text,
  organization_name text,
  onboarding_started_at timestamptz NOT NULL DEFAULT now(),
  target_completion_at timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  current_milestone text NOT NULL DEFAULT 'welcome_call' CHECK (current_milestone IN ('welcome_call','kit_dispatch','first_service','amc_signup','completed')),
  completion_pct int NOT NULL DEFAULT 0 CHECK (completion_pct BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','completed','stalled','abandoned')),
  assigned_csm_user_id uuid REFERENCES public.profiles(id),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coj_r2240_status ON public.customer_onboarding_journeys_r2240(status);
CREATE INDEX IF NOT EXISTS idx_coj_r2240_milestone ON public.customer_onboarding_journeys_r2240(current_milestone);
CREATE INDEX IF NOT EXISTS idx_coj_r2240_started ON public.customer_onboarding_journeys_r2240(onboarding_started_at DESC);

ALTER TABLE public.customer_onboarding_journeys_r2240 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_onboarding_journeys_r2240;
CREATE POLICY founder_all ON public.customer_onboarding_journeys_r2240
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_onboarding_milestone_events_r2240 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  journey_id uuid NOT NULL REFERENCES public.customer_onboarding_journeys_r2240(id) ON DELETE CASCADE,
  milestone text NOT NULL CHECK (milestone IN ('welcome_call','kit_dispatch','first_service','amc_signup')),
  event_type text NOT NULL CHECK (event_type IN ('started','completed','skipped','failed','delayed')),
  scheduled_at timestamptz,
  completed_at timestamptz,
  days_from_start int,
  performed_by_user_id uuid REFERENCES public.profiles(id),
  outcome_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_come_r2240_journey ON public.customer_onboarding_milestone_events_r2240(journey_id);
CREATE INDEX IF NOT EXISTS idx_come_r2240_milestone ON public.customer_onboarding_milestone_events_r2240(milestone);
CREATE INDEX IF NOT EXISTS idx_come_r2240_event ON public.customer_onboarding_milestone_events_r2240(event_type);

ALTER TABLE public.customer_onboarding_milestone_events_r2240 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_onboarding_milestone_events_r2240;
CREATE POLICY founder_all ON public.customer_onboarding_milestone_events_r2240
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: Active onboarding journeys list
DROP FUNCTION IF EXISTS public.r2240_active_journeys();
CREATE OR REPLACE FUNCTION public.r2240_active_journeys()
RETURNS TABLE (
  journey_id uuid,
  customer_name text,
  organization_name text,
  current_milestone text,
  completion_pct int,
  status text,
  days_in_progress int,
  days_remaining int,
  started_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    j.id,
    j.customer_name,
    j.organization_name,
    j.current_milestone,
    j.completion_pct,
    j.status,
    EXTRACT(DAY FROM (now() - j.onboarding_started_at))::int,
    GREATEST(0, EXTRACT(DAY FROM (j.target_completion_at - now()))::int),
    j.onboarding_started_at
  FROM public.customer_onboarding_journeys_r2240 j
  WHERE j.status = 'in_progress'
  ORDER BY j.onboarding_started_at DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.r2240_active_journeys() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2240_active_journeys() TO authenticated;

-- RPC 2: Milestone completion summary
DROP FUNCTION IF EXISTS public.r2240_milestone_summary();
CREATE OR REPLACE FUNCTION public.r2240_milestone_summary()
RETURNS TABLE (
  milestone text,
  total_started int,
  total_completed int,
  total_skipped int,
  total_delayed int,
  avg_days_to_complete numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    e.milestone,
    (COUNT(*) FILTER (WHERE e.event_type = 'started'))::int,
    (COUNT(*) FILTER (WHERE e.event_type = 'completed'))::int,
    (COUNT(*) FILTER (WHERE e.event_type = 'skipped'))::int,
    (COUNT(*) FILTER (WHERE e.event_type = 'delayed'))::int,
    ROUND(AVG(e.days_from_start) FILTER (WHERE e.event_type = 'completed'), 1)
  FROM public.customer_onboarding_milestone_events_r2240 e
  GROUP BY e.milestone
  ORDER BY e.milestone;
END;
$$;

REVOKE ALL ON FUNCTION public.r2240_milestone_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2240_milestone_summary() TO authenticated;

-- RPC 3: Stalled customers
DROP FUNCTION IF EXISTS public.r2240_stalled_customers();
CREATE OR REPLACE FUNCTION public.r2240_stalled_customers()
RETURNS TABLE (
  journey_id uuid,
  customer_name text,
  organization_name text,
  current_milestone text,
  completion_pct int,
  days_since_last_event int,
  days_overdue int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    j.id,
    j.customer_name,
    j.organization_name,
    j.current_milestone,
    j.completion_pct,
    EXTRACT(DAY FROM (now() - COALESCE((SELECT MAX(e.created_at) FROM public.customer_onboarding_milestone_events_r2240 e WHERE e.journey_id = j.id), j.onboarding_started_at)))::int,
    GREATEST(0, EXTRACT(DAY FROM (now() - j.target_completion_at))::int)
  FROM public.customer_onboarding_journeys_r2240 j
  WHERE j.status IN ('in_progress','stalled')
    AND now() > j.target_completion_at
  ORDER BY j.target_completion_at ASC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.r2240_stalled_customers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2240_stalled_customers() TO authenticated;

-- RPC 4: Funnel conversion
DROP FUNCTION IF EXISTS public.r2240_funnel_conversion();
CREATE OR REPLACE FUNCTION public.r2240_funnel_conversion()
RETURNS TABLE (
  stage text,
  customers_reached int,
  conversion_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  total_started int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COUNT(*)::int INTO total_started FROM public.customer_onboarding_journeys_r2240;
  IF total_started = 0 THEN
    total_started := 1;
  END IF;
  RETURN QUERY
  SELECT 'welcome_call'::text,
    (SELECT COUNT(DISTINCT journey_id) FROM public.customer_onboarding_milestone_events_r2240 WHERE milestone = 'welcome_call' AND event_type = 'completed')::int,
    ROUND(100.0 * (SELECT COUNT(DISTINCT journey_id) FROM public.customer_onboarding_milestone_events_r2240 WHERE milestone = 'welcome_call' AND event_type = 'completed') / total_started, 1)
  UNION ALL
  SELECT 'kit_dispatch'::text,
    (SELECT COUNT(DISTINCT journey_id) FROM public.customer_onboarding_milestone_events_r2240 WHERE milestone = 'kit_dispatch' AND event_type = 'completed')::int,
    ROUND(100.0 * (SELECT COUNT(DISTINCT journey_id) FROM public.customer_onboarding_milestone_events_r2240 WHERE milestone = 'kit_dispatch' AND event_type = 'completed') / total_started, 1)
  UNION ALL
  SELECT 'first_service'::text,
    (SELECT COUNT(DISTINCT journey_id) FROM public.customer_onboarding_milestone_events_r2240 WHERE milestone = 'first_service' AND event_type = 'completed')::int,
    ROUND(100.0 * (SELECT COUNT(DISTINCT journey_id) FROM public.customer_onboarding_milestone_events_r2240 WHERE milestone = 'first_service' AND event_type = 'completed') / total_started, 1)
  UNION ALL
  SELECT 'amc_signup'::text,
    (SELECT COUNT(DISTINCT journey_id) FROM public.customer_onboarding_milestone_events_r2240 WHERE milestone = 'amc_signup' AND event_type = 'completed')::int,
    ROUND(100.0 * (SELECT COUNT(DISTINCT journey_id) FROM public.customer_onboarding_milestone_events_r2240 WHERE milestone = 'amc_signup' AND event_type = 'completed') / total_started, 1);
END;
$$;

REVOKE ALL ON FUNCTION public.r2240_funnel_conversion() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2240_funnel_conversion() TO authenticated;

-- RPC 5: Recent events feed
DROP FUNCTION IF EXISTS public.r2240_recent_events();
CREATE OR REPLACE FUNCTION public.r2240_recent_events()
RETURNS TABLE (
  event_id uuid,
  customer_name text,
  milestone text,
  event_type text,
  days_from_start int,
  outcome_notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    e.id,
    j.customer_name,
    e.milestone,
    e.event_type,
    e.days_from_start,
    e.outcome_notes,
    e.created_at
  FROM public.customer_onboarding_milestone_events_r2240 e
  JOIN public.customer_onboarding_journeys_r2240 j ON j.id = e.journey_id
  ORDER BY e.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.r2240_recent_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2240_recent_events() TO authenticated;

-- RPC 6: KPI snapshot
DROP FUNCTION IF EXISTS public.r2240_kpi_snapshot();
CREATE OR REPLACE FUNCTION public.r2240_kpi_snapshot()
RETURNS TABLE (
  total_journeys int,
  in_progress_count int,
  completed_count int,
  stalled_count int,
  abandoned_count int,
  avg_completion_days numeric,
  avg_completion_pct numeric,
  amc_signup_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE status = 'in_progress'))::int,
    (COUNT(*) FILTER (WHERE status = 'completed'))::int,
    (COUNT(*) FILTER (WHERE status = 'stalled'))::int,
    (COUNT(*) FILTER (WHERE status = 'abandoned'))::int,
    ROUND(AVG(EXTRACT(DAY FROM (target_completion_at - onboarding_started_at))) FILTER (WHERE status = 'completed'), 1),
    ROUND(AVG(completion_pct), 1),
    ROUND(100.0 * (COUNT(*) FILTER (WHERE current_milestone = 'completed' OR current_milestone = 'amc_signup'))::numeric / NULLIF(COUNT(*), 0), 1)
  FROM public.customer_onboarding_journeys_r2240;
END;
$$;

REVOKE ALL ON FUNCTION public.r2240_kpi_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2240_kpi_snapshot() TO authenticated;

-- RPC 7: Day-by-day cohort breakdown
DROP FUNCTION IF EXISTS public.r2240_cohort_breakdown();
CREATE OR REPLACE FUNCTION public.r2240_cohort_breakdown()
RETURNS TABLE (
  cohort_week date,
  journeys_started int,
  journeys_completed int,
  avg_days_to_complete numeric,
  amc_signups int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', j.onboarding_started_at)::date AS cw,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE j.status = 'completed'))::int,
    ROUND(AVG(EXTRACT(DAY FROM (j.target_completion_at - j.onboarding_started_at))) FILTER (WHERE j.status = 'completed'), 1),
    (COUNT(*) FILTER (WHERE j.current_milestone IN ('amc_signup','completed')))::int
  FROM public.customer_onboarding_journeys_r2240 j
  WHERE j.onboarding_started_at > now() - interval '90 days'
  GROUP BY date_trunc('week', j.onboarding_started_at)
  ORDER BY cw DESC
  LIMIT 12;
END;
$$;

REVOKE ALL ON FUNCTION public.r2240_cohort_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2240_cohort_breakdown() TO authenticated;

COMMIT;
