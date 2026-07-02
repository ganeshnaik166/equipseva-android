BEGIN;

-- ============================================================================
-- Round 2768 — Customer Monthly Engineer Language Mismatch Incidents
-- Tracks job-level language-mismatch incidents between engineer and customer,
-- translator involvement, and monthly outcome metrics.
-- ============================================================================

CREATE TABLE IF NOT EXISTS lang_mismatch_incidents_r2768 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_month date NOT NULL,
  job_code text NOT NULL,
  city text NOT NULL,
  hospital_name text NOT NULL,
  engineer_name text NOT NULL,
  engineer_language text NOT NULL CHECK (engineer_language IN ('hindi','telugu','tamil','kannada','marathi','bengali','english','gujarati')),
  customer_language text NOT NULL CHECK (customer_language IN ('hindi','telugu','tamil','kannada','marathi','bengali','english','gujarati')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  translator_used boolean NOT NULL DEFAULT false,
  translator_minutes integer NOT NULL DEFAULT 0 CHECK (translator_minutes >= 0),
  outcome text NOT NULL CHECK (outcome IN ('resolved','escalated','reassigned','customer_refunded','pending')),
  csat_delta_pct numeric(6,2) NOT NULL DEFAULT 0,
  extra_cost_rupees numeric(12,2) NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE lang_mismatch_incidents_r2768 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON lang_mismatch_incidents_r2768;
CREATE POLICY founder_all ON lang_mismatch_incidents_r2768
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS lang_mismatch_monthly_rollup_r2768 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rollup_month date NOT NULL UNIQUE,
  total_incidents integer NOT NULL DEFAULT 0 CHECK (total_incidents >= 0),
  critical_incidents integer NOT NULL DEFAULT 0 CHECK (critical_incidents >= 0),
  translator_invocations integer NOT NULL DEFAULT 0 CHECK (translator_invocations >= 0),
  translator_minutes_total integer NOT NULL DEFAULT 0 CHECK (translator_minutes_total >= 0),
  reassignments integer NOT NULL DEFAULT 0 CHECK (reassignments >= 0),
  refunds_issued integer NOT NULL DEFAULT 0 CHECK (refunds_issued >= 0),
  avg_csat_delta_pct numeric(6,2) NOT NULL DEFAULT 0,
  total_extra_cost_rupees numeric(14,2) NOT NULL DEFAULT 0,
  top_mismatch_pair text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE lang_mismatch_monthly_rollup_r2768 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON lang_mismatch_monthly_rollup_r2768;
CREATE POLICY founder_all ON lang_mismatch_monthly_rollup_r2768
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- Seed data
-- ============================================================================

INSERT INTO lang_mismatch_incidents_r2768
  (incident_month, job_code, city, hospital_name, engineer_name, engineer_language, customer_language, severity, translator_used, translator_minutes, outcome, csat_delta_pct, extra_cost_rupees, notes)
VALUES
  ('2026-06-01'::date, 'JOB-44021', 'Chennai', 'Apollo Greams Rd', 'R. Kumar', 'hindi', 'tamil', 'high', true, 38, 'resolved', -12.50, 850.00, 'Translator bridged C-arm install briefing'),
  ('2026-06-01'::date, 'JOB-44102', 'Hyderabad', 'AIG Gachibowli', 'S. Mehta', 'hindi', 'telugu', 'medium', true, 22, 'resolved', -6.20, 420.00, 'Short call, glossary covered most terms'),
  ('2026-06-01'::date, 'JOB-44188', 'Kolkata', 'AMRI Salt Lake', 'P. Nair', 'tamil', 'bengali', 'critical', false, 0, 'reassigned', -28.40, 2100.00, 'Reassigned to Bengali engineer same day'),
  ('2026-06-01'::date, 'JOB-44219', 'Bengaluru', 'Manipal Whitefield', 'V. Iyer', 'tamil', 'kannada', 'low', false, 0, 'resolved', -3.10, 0.00, 'English fallback worked'),
  ('2026-06-01'::date, 'JOB-44303', 'Pune', 'Ruby Hall', 'A. Singh', 'hindi', 'marathi', 'medium', true, 14, 'resolved', -4.80, 260.00, 'Brief translator on closure form'),
  ('2026-06-01'::date, 'JOB-44417', 'Ahmedabad', 'CIMS Hosp', 'K. Reddy', 'telugu', 'gujarati', 'high', true, 45, 'escalated', -18.90, 980.00, 'Escalated to ops, translator stayed full visit'),
  ('2026-06-01'::date, 'JOB-44528', 'Mumbai', 'Lilavati', 'M. Das', 'bengali', 'marathi', 'critical', true, 62, 'customer_refunded', -34.20, 4500.00, 'Refund issued, severe miscommunication on dosage knob');

INSERT INTO lang_mismatch_monthly_rollup_r2768
  (rollup_month, total_incidents, critical_incidents, translator_invocations, translator_minutes_total, reassignments, refunds_issued, avg_csat_delta_pct, total_extra_cost_rupees, top_mismatch_pair)
VALUES
  ('2026-02-01'::date, 18, 2, 11, 312, 3, 1, -9.80, 14200.00, 'hindi -> tamil'),
  ('2026-03-01'::date, 22, 3, 14, 388, 4, 2, -11.40, 17850.00, 'hindi -> telugu'),
  ('2026-04-01'::date, 19, 1, 12, 295, 2, 0, -8.20, 9600.00, 'tamil -> kannada'),
  ('2026-05-01'::date, 24, 4, 17, 451, 5, 2, -13.10, 22400.00, 'hindi -> bengali'),
  ('2026-06-01'::date, 7, 2, 5, 181, 1, 1, -15.44, 9110.00, 'hindi -> tamil'),
  ('2026-01-01'::date, 16, 1, 9, 248, 2, 0, -7.60, 8100.00, 'hindi -> marathi');

-- ============================================================================
-- RPCs (all SECURITY DEFINER, is_founder gated)
-- ============================================================================

DROP FUNCTION IF EXISTS founder_lang_mismatch_kpis_r2768();
CREATE OR REPLACE FUNCTION founder_lang_mismatch_kpis_r2768()
RETURNS TABLE (
  total_incidents bigint,
  critical_incidents bigint,
  translator_use_pct numeric,
  avg_translator_minutes numeric,
  avg_csat_delta_pct numeric,
  total_extra_cost_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE severity = 'critical')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE translator_used) / NULLIF(COUNT(*),0), 2),
    ROUND(AVG(translator_minutes)::numeric, 2),
    ROUND(AVG(csat_delta_pct)::numeric, 2),
    ROUND(SUM(extra_cost_rupees)::numeric, 2)
  FROM lang_mismatch_incidents_r2768;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_lang_mismatch_kpis_r2768() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lang_mismatch_kpis_r2768() TO authenticated;

DROP FUNCTION IF EXISTS founder_lang_mismatch_recent_incidents_r2768();
CREATE OR REPLACE FUNCTION founder_lang_mismatch_recent_incidents_r2768()
RETURNS TABLE (
  job_code text,
  city text,
  hospital_name text,
  engineer_name text,
  engineer_language text,
  customer_language text,
  severity text,
  outcome text,
  translator_minutes integer,
  csat_delta_pct numeric,
  extra_cost_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.job_code, i.city, i.hospital_name, i.engineer_name,
         i.engineer_language, i.customer_language, i.severity, i.outcome,
         i.translator_minutes, i.csat_delta_pct, i.extra_cost_rupees
  FROM lang_mismatch_incidents_r2768 i
  ORDER BY i.created_at DESC, i.severity DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_lang_mismatch_recent_incidents_r2768() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lang_mismatch_recent_incidents_r2768() TO authenticated;

DROP FUNCTION IF EXISTS founder_lang_mismatch_pair_breakdown_r2768();
CREATE OR REPLACE FUNCTION founder_lang_mismatch_pair_breakdown_r2768()
RETURNS TABLE (
  pair text,
  incidents bigint,
  critical_count bigint,
  translator_pct numeric,
  avg_csat_delta numeric,
  total_cost_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (i.engineer_language || ' -> ' || i.customer_language)::text,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE i.severity = 'critical')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE i.translator_used) / NULLIF(COUNT(*),0), 2),
    ROUND(AVG(i.csat_delta_pct)::numeric, 2),
    ROUND(SUM(i.extra_cost_rupees)::numeric, 2)
  FROM lang_mismatch_incidents_r2768 i
  GROUP BY i.engineer_language, i.customer_language
  ORDER BY COUNT(*) DESC, COUNT(*) FILTER (WHERE i.severity = 'critical') DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_lang_mismatch_pair_breakdown_r2768() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lang_mismatch_pair_breakdown_r2768() TO authenticated;

DROP FUNCTION IF EXISTS founder_lang_mismatch_monthly_trend_r2768();
CREATE OR REPLACE FUNCTION founder_lang_mismatch_monthly_trend_r2768()
RETURNS TABLE (
  rollup_month date,
  total_incidents integer,
  critical_incidents integer,
  translator_invocations integer,
  translator_minutes_total integer,
  reassignments integer,
  refunds_issued integer,
  avg_csat_delta_pct numeric,
  total_extra_cost_rupees numeric,
  top_mismatch_pair text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.rollup_month, r.total_incidents, r.critical_incidents,
         r.translator_invocations, r.translator_minutes_total,
         r.reassignments, r.refunds_issued, r.avg_csat_delta_pct,
         r.total_extra_cost_rupees, r.top_mismatch_pair
  FROM lang_mismatch_monthly_rollup_r2768 r
  ORDER BY r.rollup_month ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_lang_mismatch_monthly_trend_r2768() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lang_mismatch_monthly_trend_r2768() TO authenticated;

DROP FUNCTION IF EXISTS founder_lang_mismatch_outcomes_r2768();
CREATE OR REPLACE FUNCTION founder_lang_mismatch_outcomes_r2768()
RETURNS TABLE (
  outcome text,
  incidents bigint,
  pct_of_total numeric,
  avg_csat_delta numeric,
  total_cost_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM lang_mismatch_incidents_r2768;
  RETURN QUERY
  SELECT i.outcome,
         COUNT(*)::bigint,
         ROUND(100.0 * COUNT(*) / NULLIF(v_total,0), 2),
         ROUND(AVG(i.csat_delta_pct)::numeric, 2),
         ROUND(SUM(i.extra_cost_rupees)::numeric, 2)
  FROM lang_mismatch_incidents_r2768 i
  GROUP BY i.outcome
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_lang_mismatch_outcomes_r2768() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lang_mismatch_outcomes_r2768() TO authenticated;

DROP FUNCTION IF EXISTS founder_lang_mismatch_city_hotspots_r2768();
CREATE OR REPLACE FUNCTION founder_lang_mismatch_city_hotspots_r2768()
RETURNS TABLE (
  city text,
  incidents bigint,
  critical_count bigint,
  translator_minutes_total integer,
  total_cost_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.city,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE i.severity = 'critical')::bigint,
         COALESCE(SUM(i.translator_minutes),0)::integer,
         ROUND(SUM(i.extra_cost_rupees)::numeric, 2)
  FROM lang_mismatch_incidents_r2768 i
  GROUP BY i.city
  ORDER BY COUNT(*) DESC, SUM(i.extra_cost_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_lang_mismatch_city_hotspots_r2768() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lang_mismatch_city_hotspots_r2768() TO authenticated;

DROP FUNCTION IF EXISTS founder_lang_mismatch_translator_roi_r2768();
CREATE OR REPLACE FUNCTION founder_lang_mismatch_translator_roi_r2768()
RETURNS TABLE (
  with_translator_avg_csat numeric,
  without_translator_avg_csat numeric,
  with_translator_avg_cost numeric,
  without_translator_avg_cost numeric,
  csat_swing_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_with_csat numeric;
  v_without_csat numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT AVG(csat_delta_pct) INTO v_with_csat
    FROM lang_mismatch_incidents_r2768 WHERE translator_used = true;
  SELECT AVG(csat_delta_pct) INTO v_without_csat
    FROM lang_mismatch_incidents_r2768 WHERE translator_used = false;
  RETURN QUERY
  SELECT
    ROUND(COALESCE(v_with_csat,0)::numeric, 2),
    ROUND(COALESCE(v_without_csat,0)::numeric, 2),
    ROUND((SELECT AVG(extra_cost_rupees) FROM lang_mismatch_incidents_r2768 WHERE translator_used = true)::numeric, 2),
    ROUND((SELECT AVG(extra_cost_rupees) FROM lang_mismatch_incidents_r2768 WHERE translator_used = false)::numeric, 2),
    ROUND((COALESCE(v_with_csat,0) - COALESCE(v_without_csat,0))::numeric, 2);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_lang_mismatch_translator_roi_r2768() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lang_mismatch_translator_roi_r2768() TO authenticated;

DROP FUNCTION IF EXISTS founder_lang_mismatch_severity_mix_r2768();
CREATE OR REPLACE FUNCTION founder_lang_mismatch_severity_mix_r2768()
RETURNS TABLE (
  severity text,
  incidents bigint,
  pct_of_total numeric,
  avg_translator_minutes numeric,
  total_cost_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM lang_mismatch_incidents_r2768;
  RETURN QUERY
  SELECT i.severity,
         COUNT(*)::bigint,
         ROUND(100.0 * COUNT(*) / NULLIF(v_total,0), 2),
         ROUND(AVG(i.translator_minutes)::numeric, 2),
         ROUND(SUM(i.extra_cost_rupees)::numeric, 2)
  FROM lang_mismatch_incidents_r2768 i
  GROUP BY i.severity
  ORDER BY
    CASE i.severity
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_lang_mismatch_severity_mix_r2768() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lang_mismatch_severity_mix_r2768() TO authenticated;

COMMIT;