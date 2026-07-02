BEGIN;

-- ============================================================
-- r2250: Engineer cross-training matrix
-- Track each engineer's certification status across equipment modalities
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_modality_certifications_r2250 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  modality text NOT NULL CHECK (modality IN ('ct_scanner','mri','ventilator','patient_monitor','xray','ultrasound','dialysis','anesthesia','defibrillator','infusion_pump')),
  status text NOT NULL CHECK (status IN ('certified','in_progress','none')),
  certified_at timestamptz,
  expires_at timestamptz,
  training_hours_logged numeric(6,2) NOT NULL DEFAULT 0,
  proficiency_score numeric(4,2) CHECK (proficiency_score IS NULL OR (proficiency_score >= 0 AND proficiency_score <= 5)),
  last_repair_at timestamptz,
  jobs_completed_30d int NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(engineer_user_id, modality)
);

CREATE INDEX IF NOT EXISTS idx_emc_r2250_engineer ON public.engineer_modality_certifications_r2250(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_emc_r2250_modality_status ON public.engineer_modality_certifications_r2250(modality, status);
CREATE INDEX IF NOT EXISTS idx_emc_r2250_expires ON public.engineer_modality_certifications_r2250(expires_at) WHERE expires_at IS NOT NULL;

ALTER TABLE public.engineer_modality_certifications_r2250 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS emc_r2250_founder_all ON public.engineer_modality_certifications_r2250;
CREATE POLICY emc_r2250_founder_all ON public.engineer_modality_certifications_r2250
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.modality_training_demand_r2250 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  modality text NOT NULL CHECK (modality IN ('ct_scanner','mri','ventilator','patient_monitor','xray','ultrasound','dialysis','anesthesia','defibrillator','infusion_pump')),
  region text NOT NULL CHECK (region IN ('north','south','east','west','central')),
  open_jobs_30d int NOT NULL DEFAULT 0,
  certified_engineers_count int NOT NULL DEFAULT 0,
  demand_supply_ratio numeric(6,2) NOT NULL DEFAULT 0,
  priority text NOT NULL CHECK (priority IN ('critical','high','medium','low')),
  recommended_action text,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(modality, region, snapshot_at)
);

CREATE INDEX IF NOT EXISTS idx_mtd_r2250_modality ON public.modality_training_demand_r2250(modality);
CREATE INDEX IF NOT EXISTS idx_mtd_r2250_priority ON public.modality_training_demand_r2250(priority);

ALTER TABLE public.modality_training_demand_r2250 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mtd_r2250_founder_all ON public.modality_training_demand_r2250;
CREATE POLICY mtd_r2250_founder_all ON public.modality_training_demand_r2250
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Seed sample data
-- ============================================================

INSERT INTO public.engineer_modality_certifications_r2250 (engineer_user_id, modality, status, certified_at, expires_at, training_hours_logged, proficiency_score, last_repair_at, jobs_completed_30d, notes)
SELECT p.id, m.modality, m.status, m.certified_at, m.expires_at, m.training_hours, m.score, m.last_repair, m.jobs, m.notes
FROM (
  SELECT id FROM public.profiles ORDER BY created_at LIMIT 6
) p
CROSS JOIN LATERAL (
  VALUES
    ('ct_scanner','certified', now() - interval '180 days', now() + interval '185 days', 120.0::numeric, 4.2::numeric, now() - interval '8 days', 5, 'Senior cert holder'),
    ('mri','in_progress', NULL::timestamptz, NULL::timestamptz, 35.5::numeric, NULL::numeric, NULL::timestamptz, 0, 'Module 3 of 6 complete'),
    ('ventilator','certified', now() - interval '90 days', now() + interval '275 days', 60.0::numeric, 4.5::numeric, now() - interval '3 days', 12, 'High-volume operator'),
    ('patient_monitor','none', NULL::timestamptz, NULL::timestamptz, 0.0::numeric, NULL::numeric, NULL::timestamptz, 0, NULL)
) AS m(modality, status, certified_at, expires_at, training_hours, score, last_repair, jobs, notes)
ON CONFLICT (engineer_user_id, modality) DO NOTHING;

INSERT INTO public.modality_training_demand_r2250 (modality, region, open_jobs_30d, certified_engineers_count, demand_supply_ratio, priority, recommended_action)
VALUES
  ('ct_scanner','south', 45, 8, 5.63, 'critical', 'Sponsor 6 engineers for CT cert in Q3'),
  ('mri','south', 22, 3, 7.33, 'critical', 'Partner with OEM for MRI bootcamp'),
  ('ventilator','west', 78, 24, 3.25, 'high', 'Run regional refresher in Mumbai'),
  ('patient_monitor','north', 56, 32, 1.75, 'medium', 'Maintain current pipeline'),
  ('dialysis','east', 18, 4, 4.50, 'high', 'Recruit 2 dialysis specialists in Kolkata'),
  ('xray','central', 34, 19, 1.79, 'medium', 'Cross-train ultrasound engineers'),
  ('defibrillator','south', 12, 22, 0.55, 'low', 'Surplus capacity'),
  ('anesthesia','west', 28, 7, 4.00, 'high', 'Hospital chain demand growing')
ON CONFLICT (modality, region, snapshot_at) DO NOTHING;

-- ============================================================
-- RPCs (7) — all founder-gated
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_engineer_cross_training_matrix_r2250()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  certified_count int,
  in_progress_count int,
  none_count int,
  total_modalities int,
  avg_proficiency numeric,
  total_training_hours numeric,
  coverage_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.engineer_user_id,
    p.email,
    (COUNT(*) FILTER (WHERE e.status = 'certified'))::int,
    (COUNT(*) FILTER (WHERE e.status = 'in_progress'))::int,
    (COUNT(*) FILTER (WHERE e.status = 'none'))::int,
    COUNT(*)::int,
    ROUND(AVG(e.proficiency_score) FILTER (WHERE e.proficiency_score IS NOT NULL), 2),
    ROUND(SUM(e.training_hours_logged), 1),
    ROUND((COUNT(*) FILTER (WHERE e.status = 'certified'))::numeric * 100.0 / NULLIF(COUNT(*), 0), 1)
  FROM public.engineer_modality_certifications_r2250 e
  JOIN public.profiles p ON p.id = e.engineer_user_id
  GROUP BY e.engineer_user_id, p.email
  ORDER BY (COUNT(*) FILTER (WHERE e.status = 'certified'))::int DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_engineer_cross_training_matrix_r2250() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_engineer_cross_training_matrix_r2250() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_modality_coverage_summary_r2250()
RETURNS TABLE (
  modality text,
  certified_engineers int,
  in_progress_engineers int,
  total_engineers int,
  avg_jobs_30d numeric,
  avg_proficiency numeric,
  expiring_within_90d int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.modality,
    (COUNT(*) FILTER (WHERE e.status = 'certified'))::int,
    (COUNT(*) FILTER (WHERE e.status = 'in_progress'))::int,
    COUNT(*)::int,
    ROUND(AVG(e.jobs_completed_30d), 1),
    ROUND(AVG(e.proficiency_score) FILTER (WHERE e.proficiency_score IS NOT NULL), 2),
    (COUNT(*) FILTER (WHERE e.expires_at IS NOT NULL AND e.expires_at < now() + interval '90 days' AND e.status = 'certified'))::int
  FROM public.engineer_modality_certifications_r2250 e
  GROUP BY e.modality
  ORDER BY (COUNT(*) FILTER (WHERE e.status = 'certified'))::int DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_modality_coverage_summary_r2250() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_modality_coverage_summary_r2250() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_training_demand_gaps_r2250()
RETURNS TABLE (
  modality text,
  region text,
  open_jobs_30d int,
  certified_engineers_count int,
  demand_supply_ratio numeric,
  priority text,
  recommended_action text,
  snapshot_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.modality, m.region, m.open_jobs_30d, m.certified_engineers_count,
         m.demand_supply_ratio, m.priority, m.recommended_action, m.snapshot_at
  FROM public.modality_training_demand_r2250 m
  ORDER BY
    CASE m.priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    m.demand_supply_ratio DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_training_demand_gaps_r2250() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_training_demand_gaps_r2250() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_expiring_certifications_r2250()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  modality text,
  expires_at timestamptz,
  days_until_expiry int,
  proficiency_score numeric,
  jobs_completed_30d int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.engineer_user_id,
    p.email,
    e.modality,
    e.expires_at,
    EXTRACT(day FROM (e.expires_at - now()))::int,
    e.proficiency_score,
    e.jobs_completed_30d
  FROM public.engineer_modality_certifications_r2250 e
  JOIN public.profiles p ON p.id = e.engineer_user_id
  WHERE e.status = 'certified'
    AND e.expires_at IS NOT NULL
    AND e.expires_at < now() + interval '180 days'
  ORDER BY e.expires_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_expiring_certifications_r2250() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_expiring_certifications_r2250() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_high_performers_r2250()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  certified_modalities int,
  avg_proficiency numeric,
  total_jobs_30d int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.engineer_user_id,
    p.email,
    (COUNT(*) FILTER (WHERE e.status = 'certified'))::int,
    ROUND(AVG(e.proficiency_score) FILTER (WHERE e.proficiency_score IS NOT NULL), 2),
    SUM(e.jobs_completed_30d)::int
  FROM public.engineer_modality_certifications_r2250 e
  JOIN public.profiles p ON p.id = e.engineer_user_id
  GROUP BY e.engineer_user_id, p.email
  HAVING (COUNT(*) FILTER (WHERE e.status = 'certified'))::int >= 2
  ORDER BY AVG(e.proficiency_score) DESC NULLS LAST
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.get_high_performers_r2250() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_high_performers_r2250() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_in_progress_pipeline_r2250()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  modality text,
  training_hours_logged numeric,
  notes text,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.engineer_user_id,
    p.email,
    e.modality,
    e.training_hours_logged,
    e.notes,
    e.updated_at
  FROM public.engineer_modality_certifications_r2250 e
  JOIN public.profiles p ON p.id = e.engineer_user_id
  WHERE e.status = 'in_progress'
  ORDER BY e.training_hours_logged DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_in_progress_pipeline_r2250() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_in_progress_pipeline_r2250() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_cross_training_kpis_r2250()
RETURNS TABLE (
  total_engineers_tracked int,
  total_certifications int,
  total_in_progress int,
  avg_modalities_per_engineer numeric,
  critical_gap_regions int,
  expiring_90d int,
  multi_modality_engineers int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH per_eng AS (
    SELECT engineer_user_id, COUNT(*) FILTER (WHERE status = 'certified') AS cert_n
    FROM public.engineer_modality_certifications_r2250
    GROUP BY engineer_user_id
  )
  SELECT
    (SELECT COUNT(DISTINCT engineer_user_id)::int FROM public.engineer_modality_certifications_r2250),
    (SELECT (COUNT(*) FILTER (WHERE status = 'certified'))::int FROM public.engineer_modality_certifications_r2250),
    (SELECT (COUNT(*) FILTER (WHERE status = 'in_progress'))::int FROM public.engineer_modality_certifications_r2250),
    (SELECT ROUND(AVG(cert_n), 2) FROM per_eng),
    (SELECT (COUNT(*) FILTER (WHERE priority = 'critical'))::int FROM public.modality_training_demand_r2250),
    (SELECT (COUNT(*) FILTER (WHERE status = 'certified' AND expires_at IS NOT NULL AND expires_at < now() + interval '90 days'))::int FROM public.engineer_modality_certifications_r2250),
    (SELECT (COUNT(*) FILTER (WHERE cert_n >= 2))::int FROM per_eng);
END;
$$;

REVOKE ALL ON FUNCTION public.get_cross_training_kpis_r2250() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_cross_training_kpis_r2250() TO authenticated;

COMMIT;
