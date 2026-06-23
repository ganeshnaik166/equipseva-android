BEGIN;

-- ============================================================
-- r2364: Customer Industry-Specific SLA Tracker
-- Different SLA targets per industry segment + per-customer compliance
-- ============================================================

-- Segment SLA targets table
CREATE TABLE IF NOT EXISTS public.customer_industry_sla_targets_r2364 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  segment text NOT NULL UNIQUE,
  segment_label text NOT NULL,
  response_target_hours numeric(6,2) NOT NULL,
  resolution_target_hours numeric(6,2) NOT NULL,
  uptime_target_pct numeric(5,2) NOT NULL,
  penalty_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  priority_rank int NOT NULL DEFAULT 5,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_industry_sla_targets_r2364 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_industry_sla_targets_r2364;
CREATE POLICY founder_all ON public.customer_industry_sla_targets_r2364
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Per-customer compliance snapshots
CREATE TABLE IF NOT EXISTS public.customer_industry_sla_compliance_r2364 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_email text NOT NULL,
  segment text NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  jobs_total int NOT NULL DEFAULT 0,
  jobs_response_met int NOT NULL DEFAULT 0,
  jobs_resolution_met int NOT NULL DEFAULT 0,
  avg_response_hours numeric(8,2),
  avg_resolution_hours numeric(8,2),
  uptime_observed_pct numeric(5,2),
  response_compliance_pct numeric(5,2),
  resolution_compliance_pct numeric(5,2),
  breach_count int NOT NULL DEFAULT 0,
  penalty_amount_rupees numeric(12,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'tracking',
  last_breach_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cust_sla_comp_seg_r2364 ON public.customer_industry_sla_compliance_r2364 (segment);
CREATE INDEX IF NOT EXISTS idx_cust_sla_comp_cust_r2364 ON public.customer_industry_sla_compliance_r2364 (customer_profile_id);
CREATE INDEX IF NOT EXISTS idx_cust_sla_comp_status_r2364 ON public.customer_industry_sla_compliance_r2364 (status);

ALTER TABLE public.customer_industry_sla_compliance_r2364 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_industry_sla_compliance_r2364;
CREATE POLICY founder_all ON public.customer_industry_sla_compliance_r2364
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed default segments
INSERT INTO public.customer_industry_sla_targets_r2364
  (segment, segment_label, response_target_hours, resolution_target_hours, uptime_target_pct, penalty_rate_pct, priority_rank, notes)
VALUES
  ('super_specialty', 'Super-Specialty Hospital', 1.0, 6.0, 99.50, 5.00, 1, 'Cath labs, ICU, OT — 24x7 critical'),
  ('multi_specialty', 'Multi-Specialty Hospital', 2.0, 12.0, 98.00, 3.00, 2, 'Tier 2/3 hospitals, mixed criticality'),
  ('diagnostic_chain', 'Diagnostic Chain', 4.0, 24.0, 97.00, 2.00, 3, 'Labs and imaging centers'),
  ('clinic', 'Clinic / Polyclinic', 8.0, 48.0, 95.00, 1.00, 4, 'Single-doctor and small clinics'),
  ('dental', 'Dental Practice', 12.0, 72.0, 93.00, 0.50, 5, 'Dental chairs, sterilizers'),
  ('veterinary', 'Veterinary', 24.0, 96.0, 90.00, 0.00, 6, 'No formal SLA, best-effort')
ON CONFLICT (segment) DO NOTHING;

-- ============================================================
-- RPC 1: list targets
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2364_list_targets()
RETURNS SETOF public.customer_industry_sla_targets_r2364
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.customer_industry_sla_targets_r2364
    ORDER BY priority_rank ASC, segment_label ASC;
END;
$$;

-- ============================================================
-- RPC 2: list compliance rows
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2364_list_compliance(p_segment text DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS SETOF public.customer_industry_sla_compliance_r2364
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.customer_industry_sla_compliance_r2364
    WHERE (p_segment IS NULL OR segment = p_segment)
    ORDER BY breach_count DESC, period_end DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

-- ============================================================
-- RPC 3: segment rollup
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2364_segment_rollup()
RETURNS TABLE (
  segment text,
  segment_label text,
  response_target_hours numeric,
  resolution_target_hours numeric,
  uptime_target_pct numeric,
  customers_tracked int,
  total_jobs int,
  avg_response_compliance_pct numeric,
  avg_resolution_compliance_pct numeric,
  total_breaches int,
  total_penalties_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      t.segment,
      t.segment_label,
      t.response_target_hours,
      t.resolution_target_hours,
      t.uptime_target_pct,
      COALESCE(COUNT(DISTINCT c.customer_profile_id)::int, 0) AS customers_tracked,
      COALESCE(SUM(c.jobs_total)::int, 0) AS total_jobs,
      ROUND(AVG(c.response_compliance_pct)::numeric, 2) AS avg_response_compliance_pct,
      ROUND(AVG(c.resolution_compliance_pct)::numeric, 2) AS avg_resolution_compliance_pct,
      COALESCE(SUM(c.breach_count)::int, 0) AS total_breaches,
      COALESCE(SUM(c.penalty_amount_rupees), 0)::numeric AS total_penalties_rupees
    FROM public.customer_industry_sla_targets_r2364 t
    LEFT JOIN public.customer_industry_sla_compliance_r2364 c USING (segment)
    GROUP BY t.segment, t.segment_label, t.response_target_hours, t.resolution_target_hours,
             t.uptime_target_pct, t.priority_rank
    ORDER BY t.priority_rank ASC;
END;
$$;

-- ============================================================
-- RPC 4: upsert compliance row
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2364_upsert_compliance(
  p_customer_profile_id uuid,
  p_customer_email text,
  p_segment text,
  p_period_start date,
  p_period_end date,
  p_jobs_total int,
  p_jobs_response_met int,
  p_jobs_resolution_met int,
  p_avg_response_hours numeric,
  p_avg_resolution_hours numeric,
  p_uptime_observed_pct numeric,
  p_breach_count int,
  p_penalty_amount_rupees numeric,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_resp_pct numeric;
  v_res_pct numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_resp_pct := CASE WHEN p_jobs_total > 0 THEN (p_jobs_response_met::numeric / p_jobs_total) * 100 ELSE NULL END;
  v_res_pct := CASE WHEN p_jobs_total > 0 THEN (p_jobs_resolution_met::numeric / p_jobs_total) * 100 ELSE NULL END;
  INSERT INTO public.customer_industry_sla_compliance_r2364
    (customer_profile_id, customer_email, segment, period_start, period_end,
     jobs_total, jobs_response_met, jobs_resolution_met,
     avg_response_hours, avg_resolution_hours, uptime_observed_pct,
     response_compliance_pct, resolution_compliance_pct,
     breach_count, penalty_amount_rupees, notes)
  VALUES
    (p_customer_profile_id, p_customer_email, p_segment, p_period_start, p_period_end,
     p_jobs_total, p_jobs_response_met, p_jobs_resolution_met,
     p_avg_response_hours, p_avg_resolution_hours, p_uptime_observed_pct,
     v_resp_pct, v_res_pct,
     p_breach_count, p_penalty_amount_rupees, p_notes)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: top breaching customers
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2364_top_breaches(p_limit int DEFAULT 25)
RETURNS TABLE (
  customer_email text,
  segment text,
  segment_label text,
  breach_count int,
  penalty_amount_rupees numeric,
  response_compliance_pct numeric,
  resolution_compliance_pct numeric,
  last_breach_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      c.customer_email,
      c.segment,
      t.segment_label,
      c.breach_count,
      c.penalty_amount_rupees,
      c.response_compliance_pct,
      c.resolution_compliance_pct,
      c.last_breach_at
    FROM public.customer_industry_sla_compliance_r2364 c
    LEFT JOIN public.customer_industry_sla_targets_r2364 t USING (segment)
    WHERE c.breach_count > 0
    ORDER BY c.breach_count DESC, c.penalty_amount_rupees DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

-- ============================================================
-- RPC 6: update target
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2364_update_target(
  p_segment text,
  p_response_target_hours numeric,
  p_resolution_target_hours numeric,
  p_uptime_target_pct numeric,
  p_penalty_rate_pct numeric,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.customer_industry_sla_targets_r2364
  SET response_target_hours = p_response_target_hours,
      resolution_target_hours = p_resolution_target_hours,
      uptime_target_pct = p_uptime_target_pct,
      penalty_rate_pct = p_penalty_rate_pct,
      notes = COALESCE(p_notes, notes),
      updated_at = now()
  WHERE segment = p_segment;
END;
$$;

-- ============================================================
-- RPC 7: kpi summary
-- ============================================================
CREATE OR REPLACE FUNCTION public.r2364_kpi_summary()
RETURNS TABLE (
  total_segments int,
  total_customers_tracked int,
  total_jobs int,
  total_breaches int,
  total_penalty_rupees numeric,
  worst_segment text,
  best_segment text,
  avg_response_compliance_pct numeric,
  avg_resolution_compliance_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_worst text;
  v_best text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT segment INTO v_worst
  FROM public.customer_industry_sla_compliance_r2364
  GROUP BY segment
  ORDER BY SUM(breach_count) DESC NULLS LAST
  LIMIT 1;
  SELECT segment INTO v_best
  FROM public.customer_industry_sla_compliance_r2364
  GROUP BY segment
  ORDER BY AVG(response_compliance_pct) DESC NULLS LAST
  LIMIT 1;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::int FROM public.customer_industry_sla_targets_r2364),
      (SELECT COUNT(DISTINCT customer_profile_id)::int FROM public.customer_industry_sla_compliance_r2364),
      COALESCE((SELECT SUM(jobs_total)::int FROM public.customer_industry_sla_compliance_r2364), 0),
      COALESCE((SELECT SUM(breach_count)::int FROM public.customer_industry_sla_compliance_r2364), 0),
      COALESCE((SELECT SUM(penalty_amount_rupees) FROM public.customer_industry_sla_compliance_r2364), 0)::numeric,
      v_worst,
      v_best,
      (SELECT ROUND(AVG(response_compliance_pct)::numeric, 2) FROM public.customer_industry_sla_compliance_r2364),
      (SELECT ROUND(AVG(resolution_compliance_pct)::numeric, 2) FROM public.customer_industry_sla_compliance_r2364);
END;
$$;

-- ============================================================
-- GRANT / REVOKE
-- ============================================================
REVOKE ALL ON FUNCTION public.r2364_list_targets() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2364_list_compliance(text, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2364_segment_rollup() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2364_upsert_compliance(uuid, text, text, date, date, int, int, int, numeric, numeric, numeric, int, numeric, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2364_top_breaches(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2364_update_target(text, numeric, numeric, numeric, numeric, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2364_kpi_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2364_list_targets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2364_list_compliance(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2364_segment_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2364_upsert_compliance(uuid, text, text, date, date, int, int, int, numeric, numeric, numeric, int, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2364_top_breaches(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2364_update_target(text, numeric, numeric, numeric, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2364_kpi_summary() TO authenticated;

COMMIT;
