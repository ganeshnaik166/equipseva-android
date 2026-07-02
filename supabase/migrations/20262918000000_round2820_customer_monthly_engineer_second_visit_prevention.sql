BEGIN;

-- ============================================================================
-- Round 2820 — Customer Monthly Engineer Second Visit Prevention
-- HEAVY ★★★★ founder console: job × first visit × prevention measure ×
-- second visit × cause × success
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: second_visit_prevention_jobs_r2820
-- Tracks repair jobs where second visit was a risk, prevention measure
-- applied, and whether second visit was prevented.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.second_visit_prevention_jobs_r2820 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_code text NOT NULL UNIQUE,
  customer_name text NOT NULL,
  hospital_name text NOT NULL,
  city text NOT NULL,
  equipment text NOT NULL,
  first_visit_at timestamptz NOT NULL,
  first_visit_engineer text NOT NULL,
  first_visit_diagnosis text NOT NULL,
  prevention_measure text NOT NULL CHECK (prevention_measure IN (
    'extended_diagnostic','spare_part_preorder','second_engineer_pair',
    'remote_followup','customer_training','none'
  )),
  prevention_applied_at timestamptz,
  second_visit_required boolean NOT NULL DEFAULT false,
  second_visit_at timestamptz,
  second_visit_cause text CHECK (second_visit_cause IN (
    'misdiagnosis','missing_part','customer_misuse','intermittent_fault',
    'new_fault','none'
  )),
  prevention_success boolean NOT NULL DEFAULT false,
  cost_avoided_rupees integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.second_visit_prevention_jobs_r2820 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.second_visit_prevention_jobs_r2820;
CREATE POLICY founder_all ON public.second_visit_prevention_jobs_r2820
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.second_visit_prevention_jobs_r2820 (
  job_code, customer_name, hospital_name, city, equipment,
  first_visit_at, first_visit_engineer, first_visit_diagnosis,
  prevention_measure, prevention_applied_at,
  second_visit_required, second_visit_at, second_visit_cause,
  prevention_success, cost_avoided_rupees
) VALUES
  ('JOB-2820-001','Dr. Rao','Apollo Hyderabad','Hyderabad','Ventilator V60',
   '2026-06-01 09:30:00+05:30','Suresh K','Flow sensor drift suspected',
   'spare_part_preorder','2026-06-01 10:00:00+05:30',
   false, NULL, 'none', true, 4200),
  ('JOB-2820-002','Dr. Iyer','Fortis Bangalore','Bangalore','Anesthesia A7',
   '2026-06-03 11:00:00+05:30','Rakesh M','Vaporizer leak',
   'extended_diagnostic','2026-06-03 11:30:00+05:30',
   true, '2026-06-05 10:00:00+05:30', 'missing_part', false, 0),
  ('JOB-2820-003','Dr. Menon','KIMS Cochin','Kochi','Defibrillator X3',
   '2026-06-05 14:00:00+05:30','Pradeep N','Battery degradation',
   'spare_part_preorder','2026-06-05 14:30:00+05:30',
   false, NULL, 'none', true, 3800),
  ('JOB-2820-004','Dr. Shah','Hinduja Mumbai','Mumbai','Patient Monitor M50',
   '2026-06-08 09:00:00+05:30','Anil R','ECG cable intermittent',
   'remote_followup','2026-06-08 16:00:00+05:30',
   true, '2026-06-12 10:00:00+05:30', 'intermittent_fault', false, 0),
  ('JOB-2820-005','Dr. Banerjee','AMRI Kolkata','Kolkata','Infusion Pump P3',
   '2026-06-10 10:00:00+05:30','Soumen D','Occlusion alarm false',
   'customer_training','2026-06-10 11:00:00+05:30',
   false, NULL, 'none', true, 2400),
  ('JOB-2820-006','Dr. Verma','Max Delhi','Delhi','Ultrasound U9',
   '2026-06-12 13:00:00+05:30','Vikram T','Probe noise',
   'second_engineer_pair','2026-06-12 13:30:00+05:30',
   false, NULL, 'none', true, 5600),
  ('JOB-2820-007','Dr. Pillai','Manipal Vijayawada','Vijayawada','Syringe Pump S2',
   '2026-06-14 08:30:00+05:30','Karthik V','Motor stall',
   'none','2026-06-14 09:00:00+05:30',
   true, '2026-06-16 11:00:00+05:30', 'misdiagnosis', false, 0);

-- ----------------------------------------------------------------------------
-- Table 2: prevention_measures_catalog_r2820
-- Catalog of prevention measures with cost and effectiveness baseline.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.prevention_measures_catalog_r2820 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  measure_code text NOT NULL UNIQUE,
  measure_name text NOT NULL,
  measure_category text NOT NULL CHECK (measure_category IN (
    'diagnostic','logistics','training','staffing','followup'
  )),
  unit_cost_rupees integer NOT NULL,
  baseline_success_rate numeric(5,2) NOT NULL CHECK (baseline_success_rate BETWEEN 0 AND 100),
  recommended_for text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.prevention_measures_catalog_r2820 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.prevention_measures_catalog_r2820;
CREATE POLICY founder_all ON public.prevention_measures_catalog_r2820
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.prevention_measures_catalog_r2820 (
  measure_code, measure_name, measure_category, unit_cost_rupees,
  baseline_success_rate, recommended_for, active
) VALUES
  ('extended_diagnostic','Extended on-site diagnostic (2hr)','diagnostic',1200,72.50,'Intermittent faults', true),
  ('spare_part_preorder','Preorder likely spare part','logistics',800,86.30,'Known degradation patterns', true),
  ('second_engineer_pair','Pair senior engineer on first visit','staffing',2200,91.40,'High-value equipment', true),
  ('remote_followup','24hr remote telemetry followup','followup',300,64.10,'Connected devices', true),
  ('customer_training','On-site customer training session','training',600,78.90,'Misuse-driven faults', true),
  ('none','No prevention applied','diagnostic',0,42.00,'Baseline / control', true);

-- ============================================================================
-- RPCs — all SECURITY DEFINER, is_founder() gated
-- ============================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS public.rpc_r2820_kpi_summary();
CREATE OR REPLACE FUNCTION public.rpc_r2820_kpi_summary()
RETURNS TABLE (
  total_jobs bigint,
  second_visits_prevented bigint,
  second_visits_required bigint,
  prevention_rate numeric,
  total_cost_avoided_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE prevention_success)::bigint,
    COUNT(*) FILTER (WHERE second_visit_required)::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE prevention_success) / NULLIF(COUNT(*),0), 2),
    COALESCE(SUM(cost_avoided_rupees),0)::bigint
  FROM public.second_visit_prevention_jobs_r2820;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2820_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2820_kpi_summary() TO authenticated;

-- RPC 2: List jobs
DROP FUNCTION IF EXISTS public.rpc_r2820_list_jobs();
CREATE OR REPLACE FUNCTION public.rpc_r2820_list_jobs()
RETURNS TABLE (
  job_code text,
  customer_name text,
  hospital_name text,
  city text,
  equipment text,
  first_visit_at timestamptz,
  prevention_measure text,
  second_visit_required boolean,
  second_visit_cause text,
  prevention_success boolean,
  cost_avoided_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.job_code, j.customer_name, j.hospital_name, j.city, j.equipment,
         j.first_visit_at, j.prevention_measure, j.second_visit_required,
         j.second_visit_cause, j.prevention_success, j.cost_avoided_rupees
  FROM public.second_visit_prevention_jobs_r2820 j
  ORDER BY j.first_visit_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2820_list_jobs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2820_list_jobs() TO authenticated;

-- RPC 3: Measure effectiveness rollup
DROP FUNCTION IF EXISTS public.rpc_r2820_measure_effectiveness();
CREATE OR REPLACE FUNCTION public.rpc_r2820_measure_effectiveness()
RETURNS TABLE (
  prevention_measure text,
  jobs_applied bigint,
  successes bigint,
  success_rate numeric,
  cost_avoided_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    j.prevention_measure,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE j.prevention_success)::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE j.prevention_success) / NULLIF(COUNT(*),0), 2),
    COALESCE(SUM(j.cost_avoided_rupees),0)::bigint
  FROM public.second_visit_prevention_jobs_r2820 j
  GROUP BY j.prevention_measure
  ORDER BY 4 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2820_measure_effectiveness() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2820_measure_effectiveness() TO authenticated;

-- RPC 4: Second-visit cause breakdown
DROP FUNCTION IF EXISTS public.rpc_r2820_cause_breakdown();
CREATE OR REPLACE FUNCTION public.rpc_r2820_cause_breakdown()
RETURNS TABLE (
  second_visit_cause text,
  occurrences bigint,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total
  FROM public.second_visit_prevention_jobs_r2820
  WHERE second_visit_required;

  RETURN QUERY
  SELECT
    j.second_visit_cause,
    COUNT(*)::bigint,
    ROUND(100.0 * COUNT(*) / NULLIF(total,0), 2)
  FROM public.second_visit_prevention_jobs_r2820 j
  WHERE j.second_visit_required
  GROUP BY j.second_visit_cause
  ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2820_cause_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2820_cause_breakdown() TO authenticated;

-- RPC 5: City rollup
DROP FUNCTION IF EXISTS public.rpc_r2820_city_rollup();
CREATE OR REPLACE FUNCTION public.rpc_r2820_city_rollup()
RETURNS TABLE (
  city text,
  jobs bigint,
  prevented bigint,
  prevention_rate numeric,
  cost_avoided_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    j.city,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE j.prevention_success)::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE j.prevention_success) / NULLIF(COUNT(*),0), 2),
    COALESCE(SUM(j.cost_avoided_rupees),0)::bigint
  FROM public.second_visit_prevention_jobs_r2820 j
  GROUP BY j.city
  ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2820_city_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2820_city_rollup() TO authenticated;

-- RPC 6: Catalog list
DROP FUNCTION IF EXISTS public.rpc_r2820_catalog();
CREATE OR REPLACE FUNCTION public.rpc_r2820_catalog()
RETURNS TABLE (
  measure_code text,
  measure_name text,
  measure_category text,
  unit_cost_rupees integer,
  baseline_success_rate numeric,
  recommended_for text,
  active boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.measure_code, c.measure_name, c.measure_category, c.unit_cost_rupees,
         c.baseline_success_rate, c.recommended_for, c.active
  FROM public.prevention_measures_catalog_r2820 c
  ORDER BY c.baseline_success_rate DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2820_catalog() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2820_catalog() TO authenticated;

-- RPC 7: Engineer rollup
DROP FUNCTION IF EXISTS public.rpc_r2820_engineer_rollup();
CREATE OR REPLACE FUNCTION public.rpc_r2820_engineer_rollup()
RETURNS TABLE (
  engineer text,
  jobs bigint,
  prevented bigint,
  prevention_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    j.first_visit_engineer,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE j.prevention_success)::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE j.prevention_success) / NULLIF(COUNT(*),0), 2)
  FROM public.second_visit_prevention_jobs_r2820 j
  GROUP BY j.first_visit_engineer
  ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2820_engineer_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2820_engineer_rollup() TO authenticated;

-- RPC 8: Failed prevention drilldown
DROP FUNCTION IF EXISTS public.rpc_r2820_failed_prevention();
CREATE OR REPLACE FUNCTION public.rpc_r2820_failed_prevention()
RETURNS TABLE (
  job_code text,
  hospital_name text,
  equipment text,
  first_visit_engineer text,
  prevention_measure text,
  second_visit_cause text,
  days_to_second_visit integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    j.job_code, j.hospital_name, j.equipment, j.first_visit_engineer,
    j.prevention_measure, j.second_visit_cause,
    EXTRACT(DAY FROM (j.second_visit_at - j.first_visit_at))::integer
  FROM public.second_visit_prevention_jobs_r2820 j
  WHERE j.second_visit_required
  ORDER BY j.first_visit_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2820_failed_prevention() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2820_failed_prevention() TO authenticated;

COMMIT;
