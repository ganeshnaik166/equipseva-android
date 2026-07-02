BEGIN;

-- ============================================================
-- Round r2724 — Customer Monthly Engineer Language Preference Match
-- HEAVY ★★★★ founder console
-- ============================================================

-- Drop existing objects (idempotent re-run)
DROP TABLE IF EXISTS public.customer_language_match_r2724 CASCADE;
DROP TABLE IF EXISTS public.customer_language_switch_action_r2724 CASCADE;

-- ============================================================
-- TABLE 1: customer_language_match_r2724
-- One row per customer x month x assigned engineer language-match snapshot
-- ============================================================
CREATE TABLE public.customer_language_match_r2724 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  customer_name text NOT NULL,
  customer_org text NOT NULL,
  customer_city text NOT NULL,
  preferred_language text NOT NULL CHECK (preferred_language IN ('hindi','telugu','tamil','kannada','marathi','bengali','english','gujarati')),
  secondary_language text NOT NULL CHECK (secondary_language IN ('hindi','telugu','tamil','kannada','marathi','bengali','english','gujarati','none')),
  assigned_engineer_name text NOT NULL,
  engineer_primary_language text NOT NULL CHECK (engineer_primary_language IN ('hindi','telugu','tamil','kannada','marathi','bengali','english','gujarati')),
  engineer_secondary_language text NOT NULL CHECK (engineer_secondary_language IN ('hindi','telugu','tamil','kannada','marathi','bengali','english','gujarati','none')),
  match_grade text NOT NULL CHECK (match_grade IN ('exact','secondary','english_fallback','mismatch')),
  match_score_pct numeric(5,2) NOT NULL CHECK (match_score_pct BETWEEN 0 AND 100),
  jobs_completed int NOT NULL CHECK (jobs_completed >= 0),
  satisfaction_csat numeric(3,2) NOT NULL CHECK (satisfaction_csat BETWEEN 0 AND 5),
  language_complaint_count int NOT NULL DEFAULT 0 CHECK (language_complaint_count >= 0),
  rebook_rate_pct numeric(5,2) NOT NULL CHECK (rebook_rate_pct BETWEEN 0 AND 100),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_language_match_r2724 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_language_match_r2724;
CREATE POLICY founder_all ON public.customer_language_match_r2724
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.customer_language_match_r2724
(month_start, customer_name, customer_org, customer_city, preferred_language, secondary_language,
 assigned_engineer_name, engineer_primary_language, engineer_secondary_language,
 match_grade, match_score_pct, jobs_completed, satisfaction_csat, language_complaint_count, rebook_rate_pct, notes)
VALUES
('2026-06-01'::date,'Dr. Lakshmi Narayanan','Apollo Spectra Chennai','Chennai','tamil','english','Suresh Kumar','tamil','hindi','exact',98.50,7,4.80,0,92.00,'Perfect tamil match, customer requested same eng for next month'),
('2026-06-01'::date,'Dr. Pradeep Sharma','Max Hospital Saket','Delhi','hindi','english','Rakesh Yadav','hindi','english','exact',97.20,9,4.70,0,88.50,'Strong hindi rapport, fast turnaround'),
('2026-06-01'::date,'Dr. Anitha Reddy','KIMS Secunderabad','Hyderabad','telugu','english','Venkat Rao','telugu','english','exact',99.10,11,4.90,0,95.00,'Telugu-first comms increased trust'),
('2026-06-01'::date,'Dr. Sridhar Murthy','Manipal Whitefield','Bengaluru','kannada','english','Arun Patil','marathi','english','english_fallback',62.00,5,3.80,1,55.00,'Customer escalated about kannada gap, switched mid-month'),
('2026-06-01'::date,'Dr. Mehul Patel','Sterling Ahmedabad','Ahmedabad','gujarati','hindi','Nilesh Joshi','marathi','hindi','secondary',74.50,6,4.10,0,70.00,'Hindi fallback worked, gujarati eng requested for next'),
('2026-06-01'::date,'Dr. Subroto Banerjee','Fortis Anandapur','Kolkata','bengali','english','Kunal Das','bengali','english','exact',96.80,8,4.75,0,90.00,'Bengali pair driving rebook 90%'),
('2026-06-01'::date,'Dr. Rajan Iyer','Wockhardt Mumbai','Mumbai','tamil','english','Ganesh Pillai','tamil','marathi','exact',95.50,7,4.65,0,85.00,'Tamil + marathi combo strong in Mumbai'),
('2026-06-01'::date,'Dr. Kavitha Krishnan','Aster Medcity','Kochi','tamil','english','Rajesh Nair','english','none','english_fallback',55.00,4,3.50,2,40.00,'CRITICAL: 2 language complaints, lost relationship'),
('2026-06-01'::date,'Dr. Vikram Singh','Medanta Gurgaon','Gurgaon','hindi','english','Amit Verma','hindi','english','exact',98.00,10,4.85,0,93.00,'Hindi belt strong, repeat customer'),
('2026-06-01'::date,'Dr. Shobha Devi','Narayana Bommasandra','Bengaluru','kannada','english','Mahesh Gowda','kannada','english','exact',97.50,9,4.80,0,91.00,'Kannada eng deployed correctly after r2700 swap');

-- ============================================================
-- TABLE 2: customer_language_switch_action_r2724
-- Founder switch-engineer actions when language-mismatch causes friction
-- ============================================================
CREATE TABLE public.customer_language_switch_action_r2724 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  acted_at timestamptz NOT NULL DEFAULT now(),
  match_row_id uuid REFERENCES public.customer_language_match_r2724(id) ON DELETE SET NULL,
  customer_name text NOT NULL,
  trigger_reason text NOT NULL CHECK (trigger_reason IN ('csat_below_4','language_complaint','mismatch_detected','customer_request','rebook_drop')),
  old_engineer text NOT NULL,
  old_engineer_lang text NOT NULL,
  new_engineer text NOT NULL,
  new_engineer_lang text NOT NULL,
  switch_status text NOT NULL CHECK (switch_status IN ('proposed','approved','executed','customer_accepted','rolled_back')),
  expected_csat_lift numeric(3,2) NOT NULL CHECK (expected_csat_lift BETWEEN -2 AND 2),
  actual_csat_lift numeric(3,2),
  founder_note text NOT NULL,
  closed_at timestamptz
);

ALTER TABLE public.customer_language_switch_action_r2724 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_language_switch_action_r2724;
CREATE POLICY founder_all ON public.customer_language_switch_action_r2724
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.customer_language_switch_action_r2724
(acted_at, customer_name, trigger_reason, old_engineer, old_engineer_lang, new_engineer, new_engineer_lang, switch_status, expected_csat_lift, actual_csat_lift, founder_note, closed_at)
VALUES
(now() - interval '14 days','Dr. Sridhar Murthy','language_complaint','Arun Patil','marathi','Mahesh Gowda','kannada','executed',1.20,1.10,'Kannada eng paired, csat lifted 3.8 -> 4.9',now() - interval '7 days'),
(now() - interval '10 days','Dr. Kavitha Krishnan','csat_below_4','Rajesh Nair','english','Suresh Kumar','tamil','customer_accepted',1.50,NULL,'Tamil eng on next visit, awaiting first job',NULL),
(now() - interval '8 days','Dr. Mehul Patel','customer_request','Nilesh Joshi','marathi','Hiren Shah','gujarati','approved',0.80,NULL,'Gujarati eng allocated, scheduling',NULL),
(now() - interval '5 days','Dr. Lakshmi Narayanan','rebook_drop','Suresh Kumar','tamil','Suresh Kumar','tamil','rolled_back',-0.10,-0.05,'Customer asked to keep original tamil eng, no actual lang issue',now() - interval '4 days'),
(now() - interval '3 days','Dr. Anitha Reddy','mismatch_detected','Venkat Rao','telugu','Venkat Rao','telugu','proposed',0.00,NULL,'False alarm: detector flagged but eng is already telugu native',NULL),
(now() - interval '2 days','Dr. Subroto Banerjee','language_complaint','Kunal Das','bengali','Souvik Ghosh','bengali','executed',0.30,0.25,'Same bengali, swapped to senior, csat 4.75 -> 4.95',now() - interval '1 days');

-- ============================================================
-- RPC 1: kpi_overview_r2724
-- ============================================================
DROP FUNCTION IF EXISTS public.kpi_overview_r2724();
CREATE OR REPLACE FUNCTION public.kpi_overview_r2724()
RETURNS TABLE(
  total_customers int,
  exact_match_pct numeric,
  mismatch_count int,
  avg_csat numeric,
  total_complaints int,
  pending_switches int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM customer_language_match_r2724),
    ROUND(100.0 * (SELECT COUNT(*) FROM customer_language_match_r2724 WHERE match_grade='exact')::numeric / NULLIF((SELECT COUNT(*) FROM customer_language_match_r2724),0), 2),
    (SELECT COUNT(*)::int FROM customer_language_match_r2724 WHERE match_grade IN ('mismatch','english_fallback')),
    (SELECT ROUND(AVG(satisfaction_csat)::numeric, 2) FROM customer_language_match_r2724),
    (SELECT COALESCE(SUM(language_complaint_count),0)::int FROM customer_language_match_r2724),
    (SELECT COUNT(*)::int FROM customer_language_switch_action_r2724 WHERE switch_status IN ('proposed','approved'));
END $$;
REVOKE EXECUTE ON FUNCTION public.kpi_overview_r2724() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kpi_overview_r2724() TO authenticated;

-- ============================================================
-- RPC 2: match_grade_breakdown_r2724
-- ============================================================
DROP FUNCTION IF EXISTS public.match_grade_breakdown_r2724();
CREATE OR REPLACE FUNCTION public.match_grade_breakdown_r2724()
RETURNS TABLE(
  grade text,
  customer_count int,
  avg_csat numeric,
  avg_rebook_pct numeric,
  total_complaints int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.match_grade,
    COUNT(*)::int,
    ROUND(AVG(m.satisfaction_csat)::numeric, 2),
    ROUND(AVG(m.rebook_rate_pct)::numeric, 2),
    COALESCE(SUM(m.language_complaint_count),0)::int
  FROM customer_language_match_r2724 m
  GROUP BY m.match_grade
  ORDER BY 2 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.match_grade_breakdown_r2724() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.match_grade_breakdown_r2724() TO authenticated;

-- ============================================================
-- RPC 3: language_distribution_r2724
-- ============================================================
DROP FUNCTION IF EXISTS public.language_distribution_r2724();
CREATE OR REPLACE FUNCTION public.language_distribution_r2724()
RETURNS TABLE(
  preferred_language text,
  customer_count int,
  avg_match_score numeric,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.preferred_language,
    COUNT(*)::int,
    ROUND(AVG(m.match_score_pct)::numeric, 2),
    ROUND(AVG(m.satisfaction_csat)::numeric, 2)
  FROM customer_language_match_r2724 m
  GROUP BY m.preferred_language
  ORDER BY 2 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.language_distribution_r2724() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.language_distribution_r2724() TO authenticated;

-- ============================================================
-- RPC 4: top_mismatched_customers_r2724
-- ============================================================
DROP FUNCTION IF EXISTS public.top_mismatched_customers_r2724();
CREATE OR REPLACE FUNCTION public.top_mismatched_customers_r2724()
RETURNS TABLE(
  customer_name text,
  customer_org text,
  preferred_language text,
  engineer_primary_language text,
  match_grade text,
  satisfaction_csat numeric,
  language_complaint_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.customer_name, m.customer_org, m.preferred_language, m.engineer_primary_language,
    m.match_grade, m.satisfaction_csat, m.language_complaint_count
  FROM customer_language_match_r2724 m
  WHERE m.match_grade IN ('mismatch','english_fallback') OR m.language_complaint_count > 0
  ORDER BY m.language_complaint_count DESC, m.satisfaction_csat ASC
  LIMIT 20;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_mismatched_customers_r2724() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_mismatched_customers_r2724() TO authenticated;

-- ============================================================
-- RPC 5: switch_action_history_r2724
-- ============================================================
DROP FUNCTION IF EXISTS public.switch_action_history_r2724();
CREATE OR REPLACE FUNCTION public.switch_action_history_r2724()
RETURNS TABLE(
  acted_at timestamptz,
  customer_name text,
  trigger_reason text,
  old_engineer text,
  new_engineer text,
  switch_status text,
  expected_csat_lift numeric,
  actual_csat_lift numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.acted_at, s.customer_name, s.trigger_reason, s.old_engineer, s.new_engineer,
         s.switch_status, s.expected_csat_lift, s.actual_csat_lift
  FROM customer_language_switch_action_r2724 s
  ORDER BY s.acted_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.switch_action_history_r2724() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.switch_action_history_r2724() TO authenticated;

-- ============================================================
-- RPC 6: propose_switch_r2724
-- ============================================================
DROP FUNCTION IF EXISTS public.propose_switch_r2724(uuid, text, text);
CREATE OR REPLACE FUNCTION public.propose_switch_r2724(
  p_match_id uuid,
  p_new_engineer text,
  p_new_engineer_lang text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_row customer_language_match_r2724%ROWTYPE;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT * INTO v_row FROM customer_language_match_r2724 WHERE id = p_match_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'match row not found'; END IF;
  INSERT INTO customer_language_switch_action_r2724
    (match_row_id, customer_name, trigger_reason, old_engineer, old_engineer_lang,
     new_engineer, new_engineer_lang, switch_status, expected_csat_lift, founder_note)
  VALUES
    (p_match_id, v_row.customer_name, 'mismatch_detected', v_row.assigned_engineer_name,
     v_row.engineer_primary_language, p_new_engineer, p_new_engineer_lang, 'proposed', 0.50,
     'Auto-proposed via founder console')
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.propose_switch_r2724(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.propose_switch_r2724(uuid, text, text) TO authenticated;

-- ============================================================
-- RPC 7: city_language_health_r2724
-- ============================================================
DROP FUNCTION IF EXISTS public.city_language_health_r2724();
CREATE OR REPLACE FUNCTION public.city_language_health_r2724()
RETURNS TABLE(
  customer_city text,
  customer_count int,
  exact_match_count int,
  avg_csat numeric,
  total_complaints int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.customer_city,
    COUNT(*)::int,
    SUM(CASE WHEN m.match_grade='exact' THEN 1 ELSE 0 END)::int,
    ROUND(AVG(m.satisfaction_csat)::numeric, 2),
    COALESCE(SUM(m.language_complaint_count),0)::int
  FROM customer_language_match_r2724 m
  GROUP BY m.customer_city
  ORDER BY 2 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.city_language_health_r2724() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.city_language_health_r2724() TO authenticated;

-- ============================================================
-- RPC 8: csat_lift_summary_r2724
-- ============================================================
DROP FUNCTION IF EXISTS public.csat_lift_summary_r2724();
CREATE OR REPLACE FUNCTION public.csat_lift_summary_r2724()
RETURNS TABLE(
  switch_status text,
  action_count int,
  avg_expected_lift numeric,
  avg_actual_lift numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.switch_status,
    COUNT(*)::int,
    ROUND(AVG(s.expected_csat_lift)::numeric, 2),
    ROUND(AVG(s.actual_csat_lift)::numeric, 2)
  FROM customer_language_switch_action_r2724 s
  GROUP BY s.switch_status
  ORDER BY 2 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.csat_lift_summary_r2724() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.csat_lift_summary_r2724() TO authenticated;

COMMIT;
