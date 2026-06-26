BEGIN;

-- =============================================================================
-- Round 2828 — Customer Monthly Engineer Arrival Buffer Time
-- Tracks: job × promised arrival × actual arrival × buffer × cause × refine action
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Table 1: arrival_buffer_jobs_r2828
-- One row per repair job tracked for arrival-buffer analysis
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.arrival_buffer_jobs_r2828 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_key text NOT NULL,                       -- e.g. '2026-06'
  job_code text NOT NULL UNIQUE,                 -- e.g. 'RJ-9821'
  customer_name text NOT NULL,
  hospital_city text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  device_category text NOT NULL,                 -- e.g. 'ventilator','xray','ultrasound'
  job_priority text NOT NULL CHECK (job_priority IN ('p0','p1','p2','p3')),
  promised_arrival_at timestamptz NOT NULL,
  actual_arrival_at timestamptz NOT NULL,
  buffer_minutes integer NOT NULL,               -- actual - promised in minutes (negative = early)
  buffer_bucket text NOT NULL CHECK (buffer_bucket IN ('early','on_time','slight_late','late','very_late')),
  primary_cause text NOT NULL CHECK (primary_cause IN ('traffic','parts_pickup','prior_job_overrun','customer_reschedule','address_unclear','engineer_health','vehicle_issue','none')),
  customer_csat integer NOT NULL CHECK (customer_csat BETWEEN 1 AND 5),
  customer_complained boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.arrival_buffer_jobs_r2828 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.arrival_buffer_jobs_r2828;
CREATE POLICY founder_all ON public.arrival_buffer_jobs_r2828
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- -----------------------------------------------------------------------------
-- Table 2: arrival_buffer_refine_actions_r2828
-- Refinement actions taken to reduce buffer drift
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.arrival_buffer_refine_actions_r2828 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_key text NOT NULL,
  action_code text NOT NULL UNIQUE,              -- e.g. 'RFA-001'
  target_cause text NOT NULL CHECK (target_cause IN ('traffic','parts_pickup','prior_job_overrun','customer_reschedule','address_unclear','engineer_health','vehicle_issue','all')),
  action_title text NOT NULL,
  action_detail text NOT NULL,
  owner_role text NOT NULL CHECK (owner_role IN ('founder','ops_lead','dispatch','engineering_lead','customer_success')),
  status text NOT NULL CHECK (status IN ('proposed','in_progress','shipped','blocked','dropped')),
  expected_buffer_reduction_minutes integer NOT NULL,
  observed_buffer_reduction_minutes integer,
  jobs_in_sample integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);

ALTER TABLE public.arrival_buffer_refine_actions_r2828 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.arrival_buffer_refine_actions_r2828;
CREATE POLICY founder_all ON public.arrival_buffer_refine_actions_r2828
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- -----------------------------------------------------------------------------
-- Seed: arrival_buffer_jobs_r2828 (12 rows)
-- -----------------------------------------------------------------------------
INSERT INTO public.arrival_buffer_jobs_r2828
  (month_key, job_code, customer_name, hospital_city, engineer_name, engineer_tier, device_category, job_priority, promised_arrival_at, actual_arrival_at, buffer_minutes, buffer_bucket, primary_cause, customer_csat, customer_complained)
VALUES
  ('2026-06','RJ-9821','Apollo Jubilee','Hyderabad','Ravi Kumar','gold','ventilator','p0',
    '2026-06-03 09:00:00+05:30','2026-06-03 09:42:00+05:30',42,'late','traffic',3,true),
  ('2026-06','RJ-9822','KIMS Secunderabad','Hyderabad','Anil Reddy','silver','xray','p1',
    '2026-06-04 11:00:00+05:30','2026-06-04 11:05:00+05:30',5,'on_time','none',5,false),
  ('2026-06','RJ-9823','Yashoda Somajiguda','Hyderabad','Priya Sharma','platinum','ultrasound','p1',
    '2026-06-05 14:30:00+05:30','2026-06-05 14:25:00+05:30',-5,'early','none',5,false),
  ('2026-06','RJ-9824','Care Banjara','Hyderabad','Ravi Kumar','gold','ventilator','p0',
    '2026-06-06 08:00:00+05:30','2026-06-06 08:55:00+05:30',55,'very_late','prior_job_overrun',2,true),
  ('2026-06','RJ-9825','Continental Gachibowli','Hyderabad','Suresh M','bronze','xray','p2',
    '2026-06-08 10:00:00+05:30','2026-06-08 10:18:00+05:30',18,'slight_late','parts_pickup',4,false),
  ('2026-06','RJ-9826','Rainbow Banjara','Hyderabad','Anil Reddy','silver','ultrasound','p1',
    '2026-06-09 15:00:00+05:30','2026-06-09 15:38:00+05:30',38,'late','address_unclear',3,true),
  ('2026-06','RJ-9827','AIG Gachibowli','Hyderabad','Priya Sharma','platinum','ventilator','p0',
    '2026-06-10 09:30:00+05:30','2026-06-10 09:32:00+05:30',2,'on_time','none',5,false),
  ('2026-06','RJ-9828','Sunshine Begumpet','Hyderabad','Suresh M','bronze','dental','p2',
    '2026-06-11 13:00:00+05:30','2026-06-11 14:05:00+05:30',65,'very_late','vehicle_issue',2,true),
  ('2026-06','RJ-9829','Medicover HiTech','Hyderabad','Ravi Kumar','gold','xray','p1',
    '2026-06-12 11:00:00+05:30','2026-06-12 10:58:00+05:30',-2,'early','none',5,false),
  ('2026-06','RJ-9830','Kamineni LB Nagar','Hyderabad','Anil Reddy','silver','ventilator','p0',
    '2026-06-15 09:00:00+05:30','2026-06-15 09:24:00+05:30',24,'slight_late','traffic',4,false),
  ('2026-06','RJ-9831','Olive Banjara','Hyderabad','Suresh M','bronze','ultrasound','p2',
    '2026-06-17 14:00:00+05:30','2026-06-17 14:48:00+05:30',48,'late','customer_reschedule',3,false),
  ('2026-06','RJ-9832','Renova Sapphire','Hyderabad','Priya Sharma','platinum','ventilator','p1',
    '2026-06-19 10:30:00+05:30','2026-06-19 10:35:00+05:30',5,'on_time','none',5,false);

-- -----------------------------------------------------------------------------
-- Seed: arrival_buffer_refine_actions_r2828 (7 rows)
-- -----------------------------------------------------------------------------
INSERT INTO public.arrival_buffer_refine_actions_r2828
  (month_key, action_code, target_cause, action_title, action_detail, owner_role, status, expected_buffer_reduction_minutes, observed_buffer_reduction_minutes, jobs_in_sample, closed_at)
VALUES
  ('2026-06','RFA-001','traffic','Pre-7am slotting for p0 jobs',
    'Shift all p0 promises to 07:30-09:00 window to dodge city traffic peak',
    'ops_lead','shipped',15,12,8,'2026-06-20 10:00:00+05:30'),
  ('2026-06','RFA-002','prior_job_overrun','60-min buffer between consecutive jobs',
    'Dispatch must insert 60-min idle between any two assigned slots for same engineer',
    'dispatch','in_progress',20,NULL,5,NULL),
  ('2026-06','RFA-003','parts_pickup','Pre-stage spares night before',
    'Engineer picks parts at 06:30 not at 08:00 enroute to first job',
    'engineering_lead','shipped',10,8,6,'2026-06-22 09:00:00+05:30'),
  ('2026-06','RFA-004','address_unclear','Mandatory pin-drop on booking',
    'Customer cannot confirm slot without dropping Google Maps pin',
    'customer_success','shipped',12,11,9,'2026-06-18 17:00:00+05:30'),
  ('2026-06','RFA-005','vehicle_issue','Pool 2 backup bikes per zone',
    'Park 2 backup two-wheelers at zone hubs for breakdown handover',
    'founder','proposed',25,NULL,0,NULL),
  ('2026-06','RFA-006','customer_reschedule','24h reschedule lock',
    'Customer cannot reschedule within 24h of slot without ops_lead override',
    'ops_lead','blocked',8,NULL,0,NULL),
  ('2026-06','RFA-007','all','Live buffer heatmap on dispatch screen',
    'Show running buffer-minutes per engineer in real time; auto-flag > 20 min',
    'engineering_lead','in_progress',15,NULL,3,NULL);

-- =============================================================================
-- RPC 1: KPI rollup
-- =============================================================================
DROP FUNCTION IF EXISTS public.r2828_kpi_rollup(text);
CREATE OR REPLACE FUNCTION public.r2828_kpi_rollup(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  total_jobs integer,
  on_time_or_early_pct numeric,
  avg_buffer_minutes numeric,
  median_buffer_minutes numeric,
  complaint_jobs integer,
  avg_csat numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COUNT(*)::int AS total_jobs,
    ROUND(100.0 * SUM(CASE WHEN buffer_bucket IN ('early','on_time') THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 1) AS on_time_or_early_pct,
    ROUND(AVG(buffer_minutes)::numeric, 1) AS avg_buffer_minutes,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY buffer_minutes))::numeric, 1) AS median_buffer_minutes,
    SUM(CASE WHEN customer_complained THEN 1 ELSE 0 END)::int AS complaint_jobs,
    ROUND(AVG(customer_csat)::numeric, 2) AS avg_csat
  FROM public.arrival_buffer_jobs_r2828
  WHERE month_key = p_month;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2828_kpi_rollup(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2828_kpi_rollup(text) TO authenticated;

-- =============================================================================
-- RPC 2: list jobs (worst-first)
-- =============================================================================
DROP FUNCTION IF EXISTS public.r2828_list_jobs(text);
CREATE OR REPLACE FUNCTION public.r2828_list_jobs(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  job_code text,
  customer_name text,
  engineer_name text,
  engineer_tier text,
  device_category text,
  job_priority text,
  promised_arrival_at timestamptz,
  actual_arrival_at timestamptz,
  buffer_minutes integer,
  buffer_bucket text,
  primary_cause text,
  customer_csat integer,
  customer_complained boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT j.job_code, j.customer_name, j.engineer_name, j.engineer_tier, j.device_category,
         j.job_priority, j.promised_arrival_at, j.actual_arrival_at, j.buffer_minutes,
         j.buffer_bucket, j.primary_cause, j.customer_csat, j.customer_complained
  FROM public.arrival_buffer_jobs_r2828 j
  WHERE j.month_key = p_month
  ORDER BY j.buffer_minutes DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2828_list_jobs(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2828_list_jobs(text) TO authenticated;

-- =============================================================================
-- RPC 3: cause breakdown
-- =============================================================================
DROP FUNCTION IF EXISTS public.r2828_cause_breakdown(text);
CREATE OR REPLACE FUNCTION public.r2828_cause_breakdown(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  primary_cause text,
  job_count integer,
  avg_buffer_minutes numeric,
  share_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total integer;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COUNT(*) INTO v_total FROM public.arrival_buffer_jobs_r2828 WHERE month_key = p_month;

  RETURN QUERY
  SELECT j.primary_cause,
         COUNT(*)::int AS job_count,
         ROUND(AVG(j.buffer_minutes)::numeric, 1) AS avg_buffer_minutes,
         ROUND(100.0 * COUNT(*)::numeric / NULLIF(v_total,0), 1) AS share_pct
  FROM public.arrival_buffer_jobs_r2828 j
  WHERE j.month_key = p_month
  GROUP BY j.primary_cause
  ORDER BY job_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2828_cause_breakdown(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2828_cause_breakdown(text) TO authenticated;

-- =============================================================================
-- RPC 4: engineer scorecard
-- =============================================================================
DROP FUNCTION IF EXISTS public.r2828_engineer_scorecard(text);
CREATE OR REPLACE FUNCTION public.r2828_engineer_scorecard(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  engineer_name text,
  engineer_tier text,
  jobs integer,
  avg_buffer_minutes numeric,
  worst_buffer_minutes integer,
  on_time_pct numeric,
  complaint_count integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT j.engineer_name, j.engineer_tier,
         COUNT(*)::int AS jobs,
         ROUND(AVG(j.buffer_minutes)::numeric, 1) AS avg_buffer_minutes,
         MAX(j.buffer_minutes)::int AS worst_buffer_minutes,
         ROUND(100.0 * SUM(CASE WHEN j.buffer_bucket IN ('early','on_time') THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 1) AS on_time_pct,
         SUM(CASE WHEN j.customer_complained THEN 1 ELSE 0 END)::int AS complaint_count
  FROM public.arrival_buffer_jobs_r2828 j
  WHERE j.month_key = p_month
  GROUP BY j.engineer_name, j.engineer_tier
  ORDER BY avg_buffer_minutes DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2828_engineer_scorecard(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2828_engineer_scorecard(text) TO authenticated;

-- =============================================================================
-- RPC 5: bucket distribution
-- =============================================================================
DROP FUNCTION IF EXISTS public.r2828_bucket_distribution(text);
CREATE OR REPLACE FUNCTION public.r2828_bucket_distribution(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  buffer_bucket text,
  job_count integer,
  share_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total integer;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COUNT(*) INTO v_total FROM public.arrival_buffer_jobs_r2828 WHERE month_key = p_month;

  RETURN QUERY
  SELECT j.buffer_bucket,
         COUNT(*)::int AS job_count,
         ROUND(100.0 * COUNT(*)::numeric / NULLIF(v_total,0), 1) AS share_pct
  FROM public.arrival_buffer_jobs_r2828 j
  WHERE j.month_key = p_month
  GROUP BY j.buffer_bucket
  ORDER BY
    CASE j.buffer_bucket
      WHEN 'early' THEN 1
      WHEN 'on_time' THEN 2
      WHEN 'slight_late' THEN 3
      WHEN 'late' THEN 4
      WHEN 'very_late' THEN 5
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2828_bucket_distribution(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2828_bucket_distribution(text) TO authenticated;

-- =============================================================================
-- RPC 6: refine actions list
-- =============================================================================
DROP FUNCTION IF EXISTS public.r2828_list_refine_actions(text);
CREATE OR REPLACE FUNCTION public.r2828_list_refine_actions(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  action_code text,
  target_cause text,
  action_title text,
  action_detail text,
  owner_role text,
  status text,
  expected_buffer_reduction_minutes integer,
  observed_buffer_reduction_minutes integer,
  jobs_in_sample integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT a.action_code, a.target_cause, a.action_title, a.action_detail, a.owner_role,
         a.status, a.expected_buffer_reduction_minutes, a.observed_buffer_reduction_minutes,
         a.jobs_in_sample
  FROM public.arrival_buffer_refine_actions_r2828 a
  WHERE a.month_key = p_month
  ORDER BY
    CASE a.status
      WHEN 'in_progress' THEN 1
      WHEN 'proposed' THEN 2
      WHEN 'shipped' THEN 3
      WHEN 'blocked' THEN 4
      WHEN 'dropped' THEN 5
    END,
    a.expected_buffer_reduction_minutes DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2828_list_refine_actions(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2828_list_refine_actions(text) TO authenticated;

-- =============================================================================
-- RPC 7: device-category drill
-- =============================================================================
DROP FUNCTION IF EXISTS public.r2828_device_category_drill(text);
CREATE OR REPLACE FUNCTION public.r2828_device_category_drill(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  device_category text,
  jobs integer,
  avg_buffer_minutes numeric,
  avg_csat numeric,
  complaint_count integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT j.device_category,
         COUNT(*)::int AS jobs,
         ROUND(AVG(j.buffer_minutes)::numeric, 1) AS avg_buffer_minutes,
         ROUND(AVG(j.customer_csat)::numeric, 2) AS avg_csat,
         SUM(CASE WHEN j.customer_complained THEN 1 ELSE 0 END)::int AS complaint_count
  FROM public.arrival_buffer_jobs_r2828 j
  WHERE j.month_key = p_month
  GROUP BY j.device_category
  ORDER BY avg_buffer_minutes DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2828_device_category_drill(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2828_device_category_drill(text) TO authenticated;

-- =============================================================================
-- RPC 8: priority impact
-- =============================================================================
DROP FUNCTION IF EXISTS public.r2828_priority_impact(text);
CREATE OR REPLACE FUNCTION public.r2828_priority_impact(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  job_priority text,
  jobs integer,
  avg_buffer_minutes numeric,
  very_late_count integer,
  on_time_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT j.job_priority,
         COUNT(*)::int AS jobs,
         ROUND(AVG(j.buffer_minutes)::numeric, 1) AS avg_buffer_minutes,
         SUM(CASE WHEN j.buffer_bucket = 'very_late' THEN 1 ELSE 0 END)::int AS very_late_count,
         ROUND(100.0 * SUM(CASE WHEN j.buffer_bucket IN ('early','on_time') THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 1) AS on_time_pct
  FROM public.arrival_buffer_jobs_r2828 j
  WHERE j.month_key = p_month
  GROUP BY j.job_priority
  ORDER BY j.job_priority;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2828_priority_impact(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2828_priority_impact(text) TO authenticated;

COMMIT;
