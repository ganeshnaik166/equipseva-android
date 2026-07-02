BEGIN;

-- =========================================================================
-- Round 2852 — Customer Monthly Engineer On-Site Time Optimization
-- Tables:
--   customer_monthly_engineer_on_site_time_jobs_r2852
--   customer_monthly_engineer_on_site_time_causes_r2852
-- =========================================================================

DROP TABLE IF EXISTS customer_monthly_engineer_on_site_time_jobs_r2852 CASCADE;
CREATE TABLE customer_monthly_engineer_on_site_time_jobs_r2852 (
    id                       bigserial PRIMARY KEY,
    month_label              text        NOT NULL,
    customer_name            text        NOT NULL,
    job_code                 text        NOT NULL,
    job_type                 text        NOT NULL CHECK (job_type IN ('repair','maintenance','installation','amc_visit','calibration')),
    engineer_name            text        NOT NULL,
    scheduled_minutes        integer     NOT NULL CHECK (scheduled_minutes > 0),
    actual_minutes           integer     NOT NULL CHECK (actual_minutes >= 0),
    deviation_minutes        integer     NOT NULL,
    deviation_pct            numeric(6,2) NOT NULL,
    primary_cause_code       text        NOT NULL,
    refine_action            text        NOT NULL,
    status                   text        NOT NULL CHECK (status IN ('on_track','minor_drift','over_run','severe_over_run')),
    visit_date               date        NOT NULL,
    created_at               timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_monthly_engineer_on_site_time_jobs_r2852 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON customer_monthly_engineer_on_site_time_jobs_r2852
    FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_monthly_engineer_on_site_time_jobs_r2852
    (month_label, customer_name, job_code, job_type, engineer_name, scheduled_minutes, actual_minutes, deviation_minutes, deviation_pct, primary_cause_code, refine_action, status, visit_date)
VALUES
    ('2026-06', 'Apollo Health City',     'JOB-2852-001', 'repair',       'R. Kumar',    90,  148, 58,   64.44, 'parts_wait',         'Pre-stage common spares in van',                  'severe_over_run', '2026-06-04'::date),
    ('2026-06', 'KIMS Secunderabad',      'JOB-2852-002', 'maintenance',  'S. Reddy',    60,  72,  12,   20.00, 'access_delay',       'Issue lift pass 1 day ahead',                     'minor_drift',     '2026-06-07'::date),
    ('2026-06', 'Yashoda Hospitals',      'JOB-2852-003', 'amc_visit',    'M. Anand',    45,  44,  -1,   -2.22, 'none',               'Maintain checklist v3 cadence',                   'on_track',        '2026-06-09'::date),
    ('2026-06', 'Continental Hospitals',  'JOB-2852-004', 'calibration',  'P. Vyas',     75,  118, 43,   57.33, 'firmware_update',    'Bundle firmware push pre-visit',                  'over_run',        '2026-06-12'::date),
    ('2026-06', 'Sunshine Hospitals',     'JOB-2852-005', 'installation', 'A. Iyer',    120,  150, 30,   25.00, 'customer_signoff',   'Send signoff doc 24h before arrival',             'over_run',        '2026-06-14'::date),
    ('2026-06', 'Care Hospitals Banjara', 'JOB-2852-006', 'repair',       'R. Kumar',    90,  85,  -5,   -5.56, 'none',               'Replicate diagnostic flow used here',             'on_track',        '2026-06-16'::date),
    ('2026-06', 'Rainbow Childrens',      'JOB-2852-007', 'maintenance',  'S. Reddy',    60,  95,  35,   58.33, 'patient_in_room',    'Coordinate with ward nurse for slot',             'severe_over_run', '2026-06-18'::date);

-- -------------------------------------------------------------------------
DROP TABLE IF EXISTS customer_monthly_engineer_on_site_time_causes_r2852 CASCADE;
CREATE TABLE customer_monthly_engineer_on_site_time_causes_r2852 (
    id                  bigserial PRIMARY KEY,
    cause_code          text        NOT NULL UNIQUE,
    cause_label         text        NOT NULL,
    category            text        NOT NULL CHECK (category IN ('logistics','technical','customer','process','none')),
    occurrence_count    integer     NOT NULL CHECK (occurrence_count >= 0),
    avg_excess_minutes  numeric(6,2) NOT NULL,
    refine_action       text        NOT NULL,
    owner               text        NOT NULL,
    priority            text        NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
    created_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_monthly_engineer_on_site_time_causes_r2852 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON customer_monthly_engineer_on_site_time_causes_r2852
    FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_monthly_engineer_on_site_time_causes_r2852
    (cause_code, cause_label, category, occurrence_count, avg_excess_minutes, refine_action, owner, priority)
VALUES
    ('parts_wait',        'Spare part not in van',          'logistics', 12, 42.50, 'Pre-stage top-20 spares per route',     'Ops Lead',        'p0'),
    ('access_delay',      'Hospital entry / lift wait',     'logistics',  8, 15.25, 'Issue passes 24h ahead',                'Customer Success','p1'),
    ('firmware_update',   'On-site firmware push',          'technical',  5, 38.00, 'Bundle firmware pre-visit via VPN',     'Engineering',     'p1'),
    ('customer_signoff',  'Signoff paperwork delay',        'customer',   6, 22.00, 'Send signoff doc 24h before arrival',   'Customer Success','p2'),
    ('patient_in_room',   'Patient occupying equipment',    'customer',   7, 28.50, 'Coordinate ward slot booking',          'Field Lead',      'p1'),
    ('none',              'No deviation cause',             'none',      18,  0.00, 'Maintain current flow',                 'Ops Lead',        'p3');

-- =========================================================================
-- RPCs
-- =========================================================================

-- 1) KPI summary
DROP FUNCTION IF EXISTS get_customer_monthly_engineer_on_site_time_kpi_r2852();
CREATE OR REPLACE FUNCTION get_customer_monthly_engineer_on_site_time_kpi_r2852()
RETURNS TABLE (
    total_jobs         integer,
    on_track_jobs      integer,
    over_run_jobs      integer,
    severe_jobs        integer,
    avg_deviation_pct  numeric,
    total_excess_min   integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT
        COUNT(*)::int,
        COUNT(*) FILTER (WHERE status = 'on_track')::int,
        COUNT(*) FILTER (WHERE status IN ('over_run','severe_over_run'))::int,
        COUNT(*) FILTER (WHERE status = 'severe_over_run')::int,
        ROUND(AVG(deviation_pct)::numeric, 2),
        COALESCE(SUM(GREATEST(deviation_minutes, 0)), 0)::int
    FROM customer_monthly_engineer_on_site_time_jobs_r2852;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_customer_monthly_engineer_on_site_time_kpi_r2852() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_customer_monthly_engineer_on_site_time_kpi_r2852() TO authenticated;

-- 2) List jobs
DROP FUNCTION IF EXISTS list_customer_monthly_engineer_on_site_time_jobs_r2852();
CREATE OR REPLACE FUNCTION list_customer_monthly_engineer_on_site_time_jobs_r2852()
RETURNS SETOF customer_monthly_engineer_on_site_time_jobs_r2852
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT * FROM customer_monthly_engineer_on_site_time_jobs_r2852
    ORDER BY deviation_pct DESC NULLS LAST, visit_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_customer_monthly_engineer_on_site_time_jobs_r2852() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_customer_monthly_engineer_on_site_time_jobs_r2852() TO authenticated;

-- 3) List causes
DROP FUNCTION IF EXISTS list_customer_monthly_engineer_on_site_time_causes_r2852();
CREATE OR REPLACE FUNCTION list_customer_monthly_engineer_on_site_time_causes_r2852()
RETURNS SETOF customer_monthly_engineer_on_site_time_causes_r2852
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT * FROM customer_monthly_engineer_on_site_time_causes_r2852
    ORDER BY priority ASC, avg_excess_minutes DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_customer_monthly_engineer_on_site_time_causes_r2852() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_customer_monthly_engineer_on_site_time_causes_r2852() TO authenticated;

-- 4) Top causes (by avg excess)
DROP FUNCTION IF EXISTS top_customer_monthly_engineer_on_site_time_causes_r2852(integer);
CREATE OR REPLACE FUNCTION top_customer_monthly_engineer_on_site_time_causes_r2852(p_limit integer DEFAULT 5)
RETURNS TABLE (
    cause_code         text,
    cause_label        text,
    category           text,
    occurrence_count   integer,
    avg_excess_minutes numeric,
    refine_action      text,
    priority           text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT c.cause_code, c.cause_label, c.category, c.occurrence_count, c.avg_excess_minutes, c.refine_action, c.priority
    FROM customer_monthly_engineer_on_site_time_causes_r2852 c
    WHERE c.cause_code <> 'none'
    ORDER BY c.avg_excess_minutes DESC, c.occurrence_count DESC
    LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION top_customer_monthly_engineer_on_site_time_causes_r2852(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION top_customer_monthly_engineer_on_site_time_causes_r2852(integer) TO authenticated;

-- 5) Engineer summary
DROP FUNCTION IF EXISTS engineer_summary_customer_monthly_engineer_on_site_time_r2852();
CREATE OR REPLACE FUNCTION engineer_summary_customer_monthly_engineer_on_site_time_r2852()
RETURNS TABLE (
    engineer_name     text,
    job_count         integer,
    avg_deviation_pct numeric,
    excess_minutes    integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT j.engineer_name,
           COUNT(*)::int,
           ROUND(AVG(j.deviation_pct)::numeric, 2),
           COALESCE(SUM(GREATEST(j.deviation_minutes, 0)), 0)::int
    FROM customer_monthly_engineer_on_site_time_jobs_r2852 j
    GROUP BY j.engineer_name
    ORDER BY 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION engineer_summary_customer_monthly_engineer_on_site_time_r2852() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION engineer_summary_customer_monthly_engineer_on_site_time_r2852() TO authenticated;

-- 6) Customer summary
DROP FUNCTION IF EXISTS customer_summary_customer_monthly_engineer_on_site_time_r2852();
CREATE OR REPLACE FUNCTION customer_summary_customer_monthly_engineer_on_site_time_r2852()
RETURNS TABLE (
    customer_name     text,
    job_count         integer,
    avg_deviation_pct numeric,
    severe_count      integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT j.customer_name,
           COUNT(*)::int,
           ROUND(AVG(j.deviation_pct)::numeric, 2),
           COUNT(*) FILTER (WHERE j.status = 'severe_over_run')::int
    FROM customer_monthly_engineer_on_site_time_jobs_r2852 j
    GROUP BY j.customer_name
    ORDER BY 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION customer_summary_customer_monthly_engineer_on_site_time_r2852() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION customer_summary_customer_monthly_engineer_on_site_time_r2852() TO authenticated;

-- 7) Refine action backlog
DROP FUNCTION IF EXISTS refine_action_backlog_customer_monthly_engineer_on_site_time_r2852();
CREATE OR REPLACE FUNCTION refine_action_backlog_customer_monthly_engineer_on_site_time_r2852()
RETURNS TABLE (
    priority         text,
    cause_code       text,
    cause_label      text,
    refine_action    text,
    owner            text,
    occurrence_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT c.priority, c.cause_code, c.cause_label, c.refine_action, c.owner, c.occurrence_count
    FROM customer_monthly_engineer_on_site_time_causes_r2852 c
    WHERE c.cause_code <> 'none'
    ORDER BY CASE c.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
             c.occurrence_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION refine_action_backlog_customer_monthly_engineer_on_site_time_r2852() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION refine_action_backlog_customer_monthly_engineer_on_site_time_r2852() TO authenticated;

-- 8) Severe outliers
DROP FUNCTION IF EXISTS severe_outliers_customer_monthly_engineer_on_site_time_r2852();
CREATE OR REPLACE FUNCTION severe_outliers_customer_monthly_engineer_on_site_time_r2852()
RETURNS TABLE (
    job_code           text,
    customer_name      text,
    engineer_name      text,
    scheduled_minutes  integer,
    actual_minutes     integer,
    deviation_pct      numeric,
    primary_cause_code text,
    refine_action      text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT j.job_code, j.customer_name, j.engineer_name, j.scheduled_minutes, j.actual_minutes,
           j.deviation_pct, j.primary_cause_code, j.refine_action
    FROM customer_monthly_engineer_on_site_time_jobs_r2852 j
    WHERE j.status = 'severe_over_run'
    ORDER BY j.deviation_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION severe_outliers_customer_monthly_engineer_on_site_time_r2852() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION severe_outliers_customer_monthly_engineer_on_site_time_r2852() TO authenticated;

COMMIT;
