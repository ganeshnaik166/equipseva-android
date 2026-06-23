BEGIN;

-- =============================================================================
-- Round 2388: Customer service-engineer assignment continuity
-- =============================================================================
-- Tracks % of time same engineer serves same hospital and quantifies churn
-- impact of frequent engineer rotation on hospital relationships.
-- =============================================================================

-- Per-hospital continuity snapshot
CREATE TABLE IF NOT EXISTS public.engineer_continuity_hospital_snapshots_r2388 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  hospital_name text NOT NULL,
  hospital_city text,
  total_jobs_90d int NOT NULL DEFAULT 0,
  distinct_engineers_90d int NOT NULL DEFAULT 0,
  primary_engineer_id uuid REFERENCES public.profiles(id),
  primary_engineer_name text,
  primary_engineer_job_count int NOT NULL DEFAULT 0,
  continuity_pct numeric(5,2) NOT NULL DEFAULT 0,
  rotation_score numeric(5,2) NOT NULL DEFAULT 0,
  churn_risk_band text NOT NULL DEFAULT 'low'
    CHECK (churn_risk_band IN ('low','medium','high','critical')),
  amc_active boolean NOT NULL DEFAULT false,
  amc_monthly_rupees int NOT NULL DEFAULT 0,
  last_job_at timestamptz,
  notes text,
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id)
);

CREATE INDEX IF NOT EXISTS idx_econt_hosp_r2388_band
  ON public.engineer_continuity_hospital_snapshots_r2388 (churn_risk_band, continuity_pct);
CREATE INDEX IF NOT EXISTS idx_econt_hosp_r2388_org
  ON public.engineer_continuity_hospital_snapshots_r2388 (hospital_org_id, computed_at DESC);

ALTER TABLE public.engineer_continuity_hospital_snapshots_r2388 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_continuity_hospital_snapshots_r2388;
CREATE POLICY founder_all ON public.engineer_continuity_hospital_snapshots_r2388
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Churn impact events: when continuity drops + AMC lapses or hospital complains
CREATE TABLE IF NOT EXISTS public.engineer_continuity_churn_events_r2388 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  hospital_name text NOT NULL,
  event_type text NOT NULL
    CHECK (event_type IN ('rotation_spike','amc_lapse','complaint','win_back','escalation')),
  prior_continuity_pct numeric(5,2),
  current_continuity_pct numeric(5,2),
  delta_pct numeric(5,2),
  prior_engineer_id uuid REFERENCES public.profiles(id),
  prior_engineer_name text,
  new_engineer_id uuid REFERENCES public.profiles(id),
  new_engineer_name text,
  revenue_at_risk_rupees int NOT NULL DEFAULT 0,
  action_taken text,
  resolution_status text NOT NULL DEFAULT 'open'
    CHECK (resolution_status IN ('open','investigating','resolved','lost')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  notes text,
  recorded_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_econt_churn_r2388_status
  ON public.engineer_continuity_churn_events_r2388 (resolution_status, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_econt_churn_r2388_hospital
  ON public.engineer_continuity_churn_events_r2388 (hospital_org_id, occurred_at DESC);

ALTER TABLE public.engineer_continuity_churn_events_r2388 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_continuity_churn_events_r2388;
CREATE POLICY founder_all ON public.engineer_continuity_churn_events_r2388
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================================
-- RPCs (7) — all is_founder gated, plpgsql, search_path locked
-- =============================================================================

-- 1) Overview KPIs
CREATE OR REPLACE FUNCTION public.r2388_continuity_overview()
RETURNS TABLE (
  hospitals_tracked int,
  avg_continuity_pct numeric,
  high_continuity_hospitals int,
  critical_rotation_hospitals int,
  open_churn_events int,
  revenue_at_risk_rupees bigint,
  win_back_count_30d int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.engineer_continuity_hospital_snapshots_r2388),
    (SELECT COALESCE(ROUND(AVG(continuity_pct),2),0) FROM public.engineer_continuity_hospital_snapshots_r2388),
    (SELECT COUNT(*)::int FROM public.engineer_continuity_hospital_snapshots_r2388 WHERE continuity_pct >= 75),
    (SELECT COUNT(*)::int FROM public.engineer_continuity_hospital_snapshots_r2388 WHERE churn_risk_band = 'critical'),
    (SELECT COUNT(*)::int FROM public.engineer_continuity_churn_events_r2388 WHERE resolution_status = 'open'),
    (SELECT COALESCE(SUM(revenue_at_risk_rupees),0)::bigint FROM public.engineer_continuity_churn_events_r2388 WHERE resolution_status IN ('open','investigating')),
    (SELECT COUNT(*)::int FROM public.engineer_continuity_churn_events_r2388 WHERE event_type = 'win_back' AND occurred_at > now() - interval '30 days');
END;
$$;

REVOKE ALL ON FUNCTION public.r2388_continuity_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2388_continuity_overview() TO authenticated;

-- 2) Hospital continuity list
CREATE OR REPLACE FUNCTION public.r2388_hospital_continuity_list()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  hospital_city text,
  total_jobs_90d int,
  distinct_engineers_90d int,
  primary_engineer_name text,
  primary_engineer_job_count int,
  continuity_pct numeric,
  rotation_score numeric,
  churn_risk_band text,
  amc_active boolean,
  amc_monthly_rupees int,
  last_job_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    s.id, s.hospital_name, s.hospital_city, s.total_jobs_90d, s.distinct_engineers_90d,
    s.primary_engineer_name, s.primary_engineer_job_count, s.continuity_pct, s.rotation_score,
    s.churn_risk_band, s.amc_active, s.amc_monthly_rupees, s.last_job_at
  FROM public.engineer_continuity_hospital_snapshots_r2388 s
  ORDER BY
    CASE s.churn_risk_band
      WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4
    END,
    s.continuity_pct ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2388_hospital_continuity_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2388_hospital_continuity_list() TO authenticated;

-- 3) Churn events list
CREATE OR REPLACE FUNCTION public.r2388_churn_events_list()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  event_type text,
  prior_continuity_pct numeric,
  current_continuity_pct numeric,
  delta_pct numeric,
  prior_engineer_name text,
  new_engineer_name text,
  revenue_at_risk_rupees int,
  action_taken text,
  resolution_status text,
  occurred_at timestamptz,
  resolved_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.id, e.hospital_name, e.event_type, e.prior_continuity_pct, e.current_continuity_pct,
    e.delta_pct, e.prior_engineer_name, e.new_engineer_name, e.revenue_at_risk_rupees,
    e.action_taken, e.resolution_status, e.occurred_at, e.resolved_at
  FROM public.engineer_continuity_churn_events_r2388 e
  ORDER BY
    CASE e.resolution_status WHEN 'open' THEN 1 WHEN 'investigating' THEN 2 WHEN 'lost' THEN 3 ELSE 4 END,
    e.occurred_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2388_churn_events_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2388_churn_events_list() TO authenticated;

-- 4) Band breakdown
CREATE OR REPLACE FUNCTION public.r2388_band_breakdown()
RETURNS TABLE (
  churn_risk_band text,
  hospital_count int,
  avg_continuity_pct numeric,
  amc_revenue_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    s.churn_risk_band,
    COUNT(*)::int,
    COALESCE(ROUND(AVG(s.continuity_pct),2),0),
    COALESCE(SUM(s.amc_monthly_rupees),0)::bigint
  FROM public.engineer_continuity_hospital_snapshots_r2388 s
  GROUP BY s.churn_risk_band
  ORDER BY
    CASE s.churn_risk_band
      WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4
    END;
END;
$$;

REVOKE ALL ON FUNCTION public.r2388_band_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2388_band_breakdown() TO authenticated;

-- 5) Event type breakdown
CREATE OR REPLACE FUNCTION public.r2388_event_type_breakdown()
RETURNS TABLE (
  event_type text,
  event_count int,
  avg_delta_pct numeric,
  total_revenue_at_risk_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.event_type,
    COUNT(*)::int,
    COALESCE(ROUND(AVG(e.delta_pct),2),0),
    COALESCE(SUM(e.revenue_at_risk_rupees),0)::bigint
  FROM public.engineer_continuity_churn_events_r2388 e
  GROUP BY e.event_type
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2388_event_type_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2388_event_type_breakdown() TO authenticated;

-- 6) Top primary engineers (most relied-upon)
CREATE OR REPLACE FUNCTION public.r2388_top_primary_engineers()
RETURNS TABLE (
  primary_engineer_name text,
  hospitals_served int,
  total_jobs int,
  avg_continuity_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    s.primary_engineer_name,
    COUNT(*)::int,
    SUM(s.primary_engineer_job_count)::int,
    COALESCE(ROUND(AVG(s.continuity_pct),2),0)
  FROM public.engineer_continuity_hospital_snapshots_r2388 s
  WHERE s.primary_engineer_name IS NOT NULL
  GROUP BY s.primary_engineer_name
  ORDER BY COUNT(*) DESC, SUM(s.primary_engineer_job_count) DESC
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.r2388_top_primary_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2388_top_primary_engineers() TO authenticated;

-- 7) Resolve / log churn event
CREATE OR REPLACE FUNCTION public.r2388_resolve_churn_event(
  p_event_id uuid,
  p_resolution_status text,
  p_action_taken text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_resolution_status NOT IN ('open','investigating','resolved','lost') THEN
    RAISE EXCEPTION 'invalid resolution_status';
  END IF;

  UPDATE public.engineer_continuity_churn_events_r2388
  SET resolution_status = p_resolution_status,
      action_taken = COALESCE(p_action_taken, action_taken),
      resolved_at = CASE WHEN p_resolution_status IN ('resolved','lost') THEN now() ELSE resolved_at END
  WHERE id = p_event_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'event not found';
  END IF;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.r2388_resolve_churn_event(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2388_resolve_churn_event(uuid, text, text) TO authenticated;

-- =============================================================================
-- Seed sample data
-- =============================================================================
INSERT INTO public.engineer_continuity_hospital_snapshots_r2388
  (hospital_org_id, hospital_name, hospital_city, total_jobs_90d, distinct_engineers_90d,
   primary_engineer_name, primary_engineer_job_count, continuity_pct, rotation_score,
   churn_risk_band, amc_active, amc_monthly_rupees, last_job_at, notes)
VALUES
  (gen_random_uuid(), 'Apollo Hyderabad', 'Hyderabad', 42, 2, 'Ravi Kumar', 38, 90.48, 1.10, 'low', true, 85000, now() - interval '2 days', 'Strong primary engineer attachment'),
  (gen_random_uuid(), 'KIMS Secunderabad', 'Secunderabad', 28, 3, 'Suresh Reddy', 22, 78.57, 1.40, 'low', true, 62000, now() - interval '4 days', 'Stable rotation, primary covers 78%'),
  (gen_random_uuid(), 'Care Banjara Hills', 'Hyderabad', 35, 5, 'Manoj Singh', 18, 51.43, 2.30, 'medium', true, 55000, now() - interval '6 days', 'Multiple engineers, AMC at risk if drops further'),
  (gen_random_uuid(), 'Yashoda Somajiguda', 'Hyderabad', 31, 6, 'Kiran Rao', 14, 45.16, 2.80, 'high', true, 72000, now() - interval '3 days', 'Rotation increased after Q3 reshuffle'),
  (gen_random_uuid(), 'Sunshine Paradise', 'Hyderabad', 24, 7, 'Anil Gupta', 9, 37.50, 3.20, 'high', false, 0, now() - interval '8 days', 'AMC lapsed last month — likely linked to rotation'),
  (gen_random_uuid(), 'Continental Gachibowli', 'Hyderabad', 19, 8, 'Vikram Joshi', 6, 31.58, 3.80, 'critical', true, 95000, now() - interval '5 days', 'Most rotated — escalation in progress'),
  (gen_random_uuid(), 'Star Hospitals', 'Hyderabad', 16, 9, 'Deepak Sharma', 4, 25.00, 4.20, 'critical', false, 0, now() - interval '12 days', 'AMC churned 30 days ago, engineer thrash precedes'),
  (gen_random_uuid(), 'Aware Gachibowli', 'Hyderabad', 22, 4, 'Prakash Iyer', 16, 72.73, 1.60, 'low', true, 48000, now() - interval '1 day', 'Healthy continuity'),
  (gen_random_uuid(), 'Olive Hospitals', 'Hyderabad', 18, 5, 'Sandeep Patel', 10, 55.56, 2.20, 'medium', true, 42000, now() - interval '7 days', 'Watch for rotation creep'),
  (gen_random_uuid(), 'Citizens Specialty', 'Hyderabad', 14, 6, 'Naveen Shetty', 5, 35.71, 3.40, 'high', true, 38000, now() - interval '9 days', 'Engineer churn from supervisor reassignments');

INSERT INTO public.engineer_continuity_churn_events_r2388
  (hospital_org_id, hospital_name, event_type, prior_continuity_pct, current_continuity_pct,
   delta_pct, prior_engineer_name, new_engineer_name, revenue_at_risk_rupees, action_taken,
   resolution_status, occurred_at)
VALUES
  ((SELECT hospital_org_id FROM public.engineer_continuity_hospital_snapshots_r2388 WHERE hospital_name='Continental Gachibowli'), 'Continental Gachibowli', 'rotation_spike', 65.00, 31.58, -33.42, 'Ravi Kumar', 'Vikram Joshi', 1140000, 'CSM call scheduled, re-assign primary', 'investigating', now() - interval '3 days'),
  ((SELECT hospital_org_id FROM public.engineer_continuity_hospital_snapshots_r2388 WHERE hospital_name='Star Hospitals'), 'Star Hospitals', 'amc_lapse', 48.00, 25.00, -23.00, 'Suresh Reddy', 'Deepak Sharma', 0, 'Lost — AMC not renewed', 'lost', now() - interval '30 days'),
  ((SELECT hospital_org_id FROM public.engineer_continuity_hospital_snapshots_r2388 WHERE hospital_name='Sunshine Paradise'), 'Sunshine Paradise', 'complaint', 55.00, 37.50, -17.50, 'Manoj Singh', 'Anil Gupta', 0, 'Hospital flagged rotation in CSAT, AMC lapsed', 'open', now() - interval '14 days'),
  ((SELECT hospital_org_id FROM public.engineer_continuity_hospital_snapshots_r2388 WHERE hospital_name='Yashoda Somajiguda'), 'Yashoda Somajiguda', 'rotation_spike', 70.00, 45.16, -24.84, 'Ravi Kumar', 'Kiran Rao', 864000, 'Founder review meeting set', 'open', now() - interval '5 days'),
  ((SELECT hospital_org_id FROM public.engineer_continuity_hospital_snapshots_r2388 WHERE hospital_name='Citizens Specialty'), 'Citizens Specialty', 'escalation', 60.00, 35.71, -24.29, 'Suresh Reddy', 'Naveen Shetty', 456000, 'Sales engaging chain leadership', 'investigating', now() - interval '7 days'),
  ((SELECT hospital_org_id FROM public.engineer_continuity_hospital_snapshots_r2388 WHERE hospital_name='Care Banjara Hills'), 'Care Banjara Hills', 'win_back', 32.00, 51.43, 19.43, 'Anil Gupta', 'Manoj Singh', 660000, 'Reassigned primary, AMC retained', 'resolved', now() - interval '20 days'),
  ((SELECT hospital_org_id FROM public.engineer_continuity_hospital_snapshots_r2388 WHERE hospital_name='Olive Hospitals'), 'Olive Hospitals', 'rotation_spike', 68.00, 55.56, -12.44, 'Kiran Rao', 'Sandeep Patel', 504000, 'Monitoring next 30 days', 'open', now() - interval '10 days');

COMMIT;
