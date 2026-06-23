-- Round 2470: Engineer Cross-Training Matrix
-- Skill x engineer x proficiency level x shadow-jobs done x certified x backup-engineer coverage

BEGIN;

-- =====================================================================
-- TABLE 1: engineer_cross_training_matrix_r2470
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_cross_training_matrix_r2470 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  skill_name text NOT NULL,
  skill_category text NOT NULL CHECK (skill_category IN ('electrical','mechanical','software','safety','imaging','anesthesia','dental')),
  proficiency_level text NOT NULL CHECK (proficiency_level IN ('none','beginner','intermediate','advanced','expert')),
  shadow_jobs_done int NOT NULL DEFAULT 0 CHECK (shadow_jobs_done >= 0),
  certified boolean NOT NULL DEFAULT false,
  certification_date date,
  certification_authority text,
  last_used_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_matrix_r2470_engineer ON public.engineer_cross_training_matrix_r2470(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_matrix_r2470_skill ON public.engineer_cross_training_matrix_r2470(skill_name);
CREATE INDEX IF NOT EXISTS idx_matrix_r2470_category ON public.engineer_cross_training_matrix_r2470(skill_category);

ALTER TABLE public.engineer_cross_training_matrix_r2470 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_cross_training_matrix_r2470;
CREATE POLICY founder_all ON public.engineer_cross_training_matrix_r2470
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE 2: backup_engineer_coverage_r2470
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.backup_engineer_coverage_r2470 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_name text NOT NULL,
  primary_engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  backup_engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  coverage_strength text NOT NULL CHECK (coverage_strength IN ('weak','moderate','strong','redundant')),
  gap_kind text NOT NULL CHECK (gap_kind IN ('no_backup','single_point','weak_backup','balanced')),
  action_required boolean NOT NULL DEFAULT false,
  action_owner_email text,
  action_due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coverage_r2470_skill ON public.backup_engineer_coverage_r2470(skill_name);
CREATE INDEX IF NOT EXISTS idx_coverage_r2470_primary ON public.backup_engineer_coverage_r2470(primary_engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_coverage_r2470_status ON public.backup_engineer_coverage_r2470(status);

ALTER TABLE public.backup_engineer_coverage_r2470 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.backup_engineer_coverage_r2470;
CREATE POLICY founder_all ON public.backup_engineer_coverage_r2470
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- SEED DATA
-- =====================================================================
DO $$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at OFFSET 2 LIMIT 1;

  IF v_eng1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.engineer_cross_training_matrix_r2470
    (engineer_user_id, skill_name, skill_category, proficiency_level, shadow_jobs_done, certified, certification_date, certification_authority, last_used_at, notes)
  VALUES
    (v_eng1, 'CT scanner calibration', 'imaging', 'expert', 28, true, '2025-09-12'::date, 'Siemens Healthineers', now() - interval '4 days', 'Lead trainer'),
    (v_eng1, 'Dental autoclave repair', 'dental', 'intermediate', 6, false, NULL, NULL, now() - interval '21 days', 'Needs cert by Q3'),
    (COALESCE(v_eng2, v_eng1), 'Anesthesia ventilator service', 'anesthesia', 'advanced', 14, true, '2026-01-05'::date, 'Drager Academy', now() - interval '9 days', 'Strong backup'),
    (COALESCE(v_eng3, v_eng1), 'PLC firmware flashing', 'software', 'beginner', 2, false, NULL, NULL, now() - interval '60 days', 'Shadow more jobs'),
    (COALESCE(v_eng2, v_eng1), 'Electrical safety audit', 'safety', 'expert', 35, true, '2025-06-30'::date, 'NABH', now() - interval '2 days', 'Single-point-of-failure on this skill');

  INSERT INTO public.backup_engineer_coverage_r2470
    (skill_name, primary_engineer_user_id, backup_engineer_user_id, coverage_strength, gap_kind, action_required, action_owner_email, action_due_at, status, notes)
  VALUES
    ('CT scanner calibration', v_eng1, v_eng2, 'moderate', 'weak_backup', true, 'training@equipseva.com', now() + interval '30 days', 'in_progress', 'Backup needs Siemens cert'),
    ('Electrical safety audit', COALESCE(v_eng2, v_eng1), NULL, 'weak', 'no_backup', true, 'founder@equipseva.com', now() + interval '14 days', 'open', 'NABH-cert holder is single point'),
    ('Anesthesia ventilator service', COALESCE(v_eng2, v_eng1), v_eng1, 'strong', 'balanced', false, NULL, NULL, 'closed', 'Two certified engineers'),
    ('Dental autoclave repair', v_eng1, COALESCE(v_eng3, v_eng1), 'weak', 'single_point', true, 'training@equipseva.com', now() + interval '45 days', 'open', 'Both need cert');
END $$;

-- =====================================================================
-- RPC 1: list_matrix_r2470
-- =====================================================================
DROP FUNCTION IF EXISTS public.list_matrix_r2470();
CREATE OR REPLACE FUNCTION public.list_matrix_r2470()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  skill_name text,
  skill_category text,
  proficiency_level text,
  shadow_jobs_done int,
  certified boolean,
  certification_date date,
  certification_authority text,
  last_used_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.engineer_user_id, m.skill_name, m.skill_category, m.proficiency_level,
         m.shadow_jobs_done, m.certified, m.certification_date, m.certification_authority,
         m.last_used_at, m.notes
  FROM public.engineer_cross_training_matrix_r2470 m
  ORDER BY m.skill_category, m.skill_name, m.proficiency_level DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_matrix_r2470() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_matrix_r2470() TO authenticated;

-- =====================================================================
-- RPC 2: list_coverage_r2470
-- =====================================================================
DROP FUNCTION IF EXISTS public.list_coverage_r2470();
CREATE OR REPLACE FUNCTION public.list_coverage_r2470()
RETURNS TABLE (
  id uuid,
  skill_name text,
  primary_engineer_user_id uuid,
  backup_engineer_user_id uuid,
  coverage_strength text,
  gap_kind text,
  action_required boolean,
  action_owner_email text,
  action_due_at timestamptz,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.skill_name, c.primary_engineer_user_id, c.backup_engineer_user_id,
         c.coverage_strength, c.gap_kind, c.action_required, c.action_owner_email,
         c.action_due_at, c.status, c.notes
  FROM public.backup_engineer_coverage_r2470 c
  ORDER BY
    CASE c.coverage_strength WHEN 'weak' THEN 1 WHEN 'moderate' THEN 2 WHEN 'strong' THEN 3 ELSE 4 END,
    c.skill_name;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_coverage_r2470() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_coverage_r2470() TO authenticated;

-- =====================================================================
-- RPC 3: single_point_risks_r2470
-- =====================================================================
DROP FUNCTION IF EXISTS public.single_point_risks_r2470();
CREATE OR REPLACE FUNCTION public.single_point_risks_r2470()
RETURNS TABLE (
  id uuid,
  skill_name text,
  primary_engineer_user_id uuid,
  gap_kind text,
  coverage_strength text,
  action_due_at timestamptz,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.skill_name, c.primary_engineer_user_id, c.gap_kind, c.coverage_strength,
         c.action_due_at, c.status, c.notes
  FROM public.backup_engineer_coverage_r2470 c
  WHERE c.gap_kind IN ('no_backup','single_point','weak_backup')
    AND c.status IN ('open','in_progress')
  ORDER BY
    CASE c.gap_kind WHEN 'no_backup' THEN 1 WHEN 'single_point' THEN 2 WHEN 'weak_backup' THEN 3 ELSE 4 END,
    c.action_due_at NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.single_point_risks_r2470() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.single_point_risks_r2470() TO authenticated;

-- =====================================================================
-- RPC 4: certification_pipeline_r2470
-- =====================================================================
DROP FUNCTION IF EXISTS public.certification_pipeline_r2470();
CREATE OR REPLACE FUNCTION public.certification_pipeline_r2470()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  skill_name text,
  skill_category text,
  proficiency_level text,
  shadow_jobs_done int,
  cert_ready boolean,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.engineer_user_id, m.skill_name, m.skill_category, m.proficiency_level,
         m.shadow_jobs_done,
         (m.shadow_jobs_done >= 5 AND m.proficiency_level IN ('intermediate','advanced','expert')) AS cert_ready,
         m.notes
  FROM public.engineer_cross_training_matrix_r2470 m
  WHERE m.certified = false
  ORDER BY
    CASE WHEN (m.shadow_jobs_done >= 5 AND m.proficiency_level IN ('intermediate','advanced','expert')) THEN 0 ELSE 1 END,
    m.shadow_jobs_done DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.certification_pipeline_r2470() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.certification_pipeline_r2470() TO authenticated;

-- =====================================================================
-- RPC 5: top_skill_gaps_r2470
-- =====================================================================
DROP FUNCTION IF EXISTS public.top_skill_gaps_r2470();
CREATE OR REPLACE FUNCTION public.top_skill_gaps_r2470()
RETURNS TABLE (
  skill_name text,
  certified_count bigint,
  total_engineers bigint,
  weak_coverage_count bigint,
  no_backup_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.skill_name,
    COUNT(*) FILTER (WHERE m.certified = true) AS certified_count,
    COUNT(*) AS total_engineers,
    COALESCE((SELECT COUNT(*) FROM public.backup_engineer_coverage_r2470 c
              WHERE c.skill_name = m.skill_name AND c.coverage_strength = 'weak'), 0)::bigint AS weak_coverage_count,
    COALESCE((SELECT COUNT(*) FROM public.backup_engineer_coverage_r2470 c
              WHERE c.skill_name = m.skill_name AND c.gap_kind = 'no_backup'), 0)::bigint AS no_backup_count
  FROM public.engineer_cross_training_matrix_r2470 m
  GROUP BY m.skill_name
  ORDER BY certified_count ASC, total_engineers DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_skill_gaps_r2470() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_skill_gaps_r2470() TO authenticated;

-- =====================================================================
-- RPC 6: engineer_coverage_summary_r2470
-- =====================================================================
DROP FUNCTION IF EXISTS public.engineer_coverage_summary_r2470();
CREATE OR REPLACE FUNCTION public.engineer_coverage_summary_r2470()
RETURNS TABLE (
  engineer_user_id uuid,
  total_skills bigint,
  certified_skills bigint,
  expert_skills bigint,
  beginner_skills bigint,
  total_shadow_jobs bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.engineer_user_id,
    COUNT(*) AS total_skills,
    COUNT(*) FILTER (WHERE m.certified = true) AS certified_skills,
    COUNT(*) FILTER (WHERE m.proficiency_level = 'expert') AS expert_skills,
    COUNT(*) FILTER (WHERE m.proficiency_level = 'beginner') AS beginner_skills,
    COALESCE(SUM(m.shadow_jobs_done), 0)::bigint AS total_shadow_jobs
  FROM public.engineer_cross_training_matrix_r2470 m
  GROUP BY m.engineer_user_id
  ORDER BY certified_skills DESC, total_skills DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.engineer_coverage_summary_r2470() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_coverage_summary_r2470() TO authenticated;

-- =====================================================================
-- RPC 7: weekly_certification_trend_r2470
-- =====================================================================
DROP FUNCTION IF EXISTS public.weekly_certification_trend_r2470();
CREATE OR REPLACE FUNCTION public.weekly_certification_trend_r2470()
RETURNS TABLE (
  week_start date,
  certifications_earned bigint,
  cumulative_certifications bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH weekly AS (
    SELECT
      date_trunc('week', m.certification_date)::date AS week_start,
      COUNT(*) AS certifications_earned
    FROM public.engineer_cross_training_matrix_r2470 m
    WHERE m.certified = true AND m.certification_date IS NOT NULL
    GROUP BY 1
  )
  SELECT
    w.week_start,
    w.certifications_earned,
    SUM(w.certifications_earned) OVER (ORDER BY w.week_start ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::bigint AS cumulative_certifications
  FROM weekly w
  ORDER BY w.week_start;
END $$;
REVOKE EXECUTE ON FUNCTION public.weekly_certification_trend_r2470() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_certification_trend_r2470() TO authenticated;

