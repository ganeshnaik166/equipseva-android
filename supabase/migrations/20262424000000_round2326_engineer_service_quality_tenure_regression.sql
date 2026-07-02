BEGIN;

-- Table 1: tenure cohort buckets with aggregate quality metrics
CREATE TABLE IF NOT EXISTS public.engineer_tenure_quality_cohorts_r2326 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cohort_label text NOT NULL,
  tenure_months_min int NOT NULL,
  tenure_months_max int NOT NULL,
  engineer_count int NOT NULL DEFAULT 0,
  job_count int NOT NULL DEFAULT 0,
  avg_rating numeric(4,2),
  avg_first_visit_fix_rate numeric(5,2),
  avg_rework_rate numeric(5,2),
  avg_sla_breach_rate numeric(5,2),
  avg_complaint_rate numeric(5,2),
  quality_index numeric(5,2),
  computed_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_etqc_r2326_tenure ON public.engineer_tenure_quality_cohorts_r2326(tenure_months_min);
CREATE INDEX IF NOT EXISTS idx_etqc_r2326_computed ON public.engineer_tenure_quality_cohorts_r2326(computed_at DESC);

ALTER TABLE public.engineer_tenure_quality_cohorts_r2326 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_tenure_quality_cohorts_r2326;
CREATE POLICY founder_all ON public.engineer_tenure_quality_cohorts_r2326
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: individual engineer tenure-quality datapoints + regression notes
CREATE TABLE IF NOT EXISTS public.engineer_tenure_quality_points_r2326 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_name text NOT NULL,
  tenure_months int NOT NULL,
  jobs_completed int NOT NULL DEFAULT 0,
  avg_rating numeric(4,2),
  first_visit_fix_rate numeric(5,2),
  rework_rate numeric(5,2),
  sla_breach_rate numeric(5,2),
  complaint_rate numeric(5,2),
  quality_index numeric(5,2),
  outlier_flag boolean NOT NULL DEFAULT false,
  outlier_reason text,
  plateau_segment text,
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewer_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_etqp_r2326_engineer ON public.engineer_tenure_quality_points_r2326(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_etqp_r2326_tenure ON public.engineer_tenure_quality_points_r2326(tenure_months);
CREATE INDEX IF NOT EXISTS idx_etqp_r2326_outlier ON public.engineer_tenure_quality_points_r2326(outlier_flag) WHERE outlier_flag = true;

ALTER TABLE public.engineer_tenure_quality_points_r2326 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_tenure_quality_points_r2326;
CREATE POLICY founder_all ON public.engineer_tenure_quality_points_r2326
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list cohort buckets (tenure curve)
CREATE OR REPLACE FUNCTION public.r2326_list_cohorts()
RETURNS TABLE (
  id uuid,
  cohort_label text,
  tenure_months_min int,
  tenure_months_max int,
  engineer_count int,
  job_count int,
  avg_rating numeric,
  avg_first_visit_fix_rate numeric,
  avg_rework_rate numeric,
  avg_sla_breach_rate numeric,
  avg_complaint_rate numeric,
  quality_index numeric,
  computed_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.cohort_label, c.tenure_months_min, c.tenure_months_max,
           c.engineer_count, c.job_count, c.avg_rating,
           c.avg_first_visit_fix_rate, c.avg_rework_rate,
           c.avg_sla_breach_rate, c.avg_complaint_rate,
           c.quality_index, c.computed_at
    FROM public.engineer_tenure_quality_cohorts_r2326 c
    ORDER BY c.tenure_months_min ASC;
END; $$;

-- RPC 2: list engineer datapoints
CREATE OR REPLACE FUNCTION public.r2326_list_points()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  tenure_months int,
  jobs_completed int,
  avg_rating numeric,
  first_visit_fix_rate numeric,
  rework_rate numeric,
  sla_breach_rate numeric,
  complaint_rate numeric,
  quality_index numeric,
  outlier_flag boolean,
  outlier_reason text,
  plateau_segment text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.engineer_name, p.tenure_months, p.jobs_completed,
           p.avg_rating, p.first_visit_fix_rate, p.rework_rate,
           p.sla_breach_rate, p.complaint_rate, p.quality_index,
           p.outlier_flag, p.outlier_reason, p.plateau_segment
    FROM public.engineer_tenure_quality_points_r2326 p
    ORDER BY p.tenure_months ASC, p.quality_index DESC NULLS LAST;
END; $$;

-- RPC 3: insert cohort row
CREATE OR REPLACE FUNCTION public.r2326_add_cohort(
  p_label text,
  p_min int,
  p_max int,
  p_engineer_count int,
  p_job_count int,
  p_avg_rating numeric,
  p_first_visit numeric,
  p_rework numeric,
  p_sla_breach numeric,
  p_complaint numeric,
  p_quality_index numeric,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_actor uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_actor FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  INSERT INTO public.engineer_tenure_quality_cohorts_r2326(
    cohort_label, tenure_months_min, tenure_months_max,
    engineer_count, job_count, avg_rating,
    avg_first_visit_fix_rate, avg_rework_rate,
    avg_sla_breach_rate, avg_complaint_rate,
    quality_index, notes, created_by
  ) VALUES (
    p_label, p_min, p_max, p_engineer_count, p_job_count, p_avg_rating,
    p_first_visit, p_rework, p_sla_breach, p_complaint,
    p_quality_index, p_notes, v_actor
  ) RETURNING id INTO v_id;
  RETURN v_id;
END; $$;

-- RPC 4: insert engineer point
CREATE OR REPLACE FUNCTION public.r2326_add_point(
  p_engineer_user_id uuid,
  p_engineer_name text,
  p_tenure_months int,
  p_jobs_completed int,
  p_avg_rating numeric,
  p_first_visit numeric,
  p_rework numeric,
  p_sla_breach numeric,
  p_complaint numeric,
  p_quality_index numeric,
  p_plateau_segment text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_tenure_quality_points_r2326(
    engineer_user_id, engineer_name, tenure_months, jobs_completed,
    avg_rating, first_visit_fix_rate, rework_rate,
    sla_breach_rate, complaint_rate, quality_index, plateau_segment
  ) VALUES (
    p_engineer_user_id, p_engineer_name, p_tenure_months, p_jobs_completed,
    p_avg_rating, p_first_visit, p_rework, p_sla_breach, p_complaint,
    p_quality_index, p_plateau_segment
  ) RETURNING id INTO v_id;
  RETURN v_id;
END; $$;

-- RPC 5: flag outlier
CREATE OR REPLACE FUNCTION public.r2326_flag_outlier(
  p_point_id uuid,
  p_reason text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_actor uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  SELECT id INTO v_actor FROM public.profiles WHERE email = v_email LIMIT 1;
  UPDATE public.engineer_tenure_quality_points_r2326
    SET outlier_flag = true,
        outlier_reason = p_reason,
        reviewed_at = now(),
        reviewed_by = v_actor,
        reviewer_email = v_email
    WHERE id = p_point_id;
END; $$;

-- RPC 6: summary metrics
CREATE OR REPLACE FUNCTION public.r2326_summary()
RETURNS TABLE (
  total_cohorts int,
  total_engineers_charted int,
  outlier_count int,
  peak_quality_cohort text,
  plateau_start_months int,
  rookie_quality_index numeric,
  peak_quality_index numeric,
  late_quality_index numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    WITH coh AS (SELECT * FROM public.engineer_tenure_quality_cohorts_r2326),
         pts AS (SELECT * FROM public.engineer_tenure_quality_points_r2326),
         peak AS (
           SELECT cohort_label, tenure_months_min, quality_index
           FROM coh ORDER BY quality_index DESC NULLS LAST LIMIT 1
         ),
         rookie AS (
           SELECT quality_index FROM coh ORDER BY tenure_months_min ASC LIMIT 1
         ),
         late AS (
           SELECT quality_index FROM coh ORDER BY tenure_months_min DESC LIMIT 1
         )
    SELECT
      (SELECT count(*)::int FROM coh),
      (SELECT count(DISTINCT engineer_user_id)::int FROM pts),
      (SELECT count(*)::int FROM pts WHERE outlier_flag),
      (SELECT cohort_label FROM peak),
      (SELECT tenure_months_min FROM peak),
      (SELECT quality_index FROM rookie),
      (SELECT quality_index FROM peak),
      (SELECT quality_index FROM late);
END; $$;

-- RPC 7: clear point flag
CREATE OR REPLACE FUNCTION public.r2326_clear_flag(p_point_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_tenure_quality_points_r2326
    SET outlier_flag = false,
        outlier_reason = NULL,
        reviewed_at = now()
    WHERE id = p_point_id;
END; $$;

REVOKE ALL ON FUNCTION public.r2326_list_cohorts() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2326_list_points() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2326_add_cohort(text,int,int,int,int,numeric,numeric,numeric,numeric,numeric,numeric,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2326_add_point(uuid,text,int,int,numeric,numeric,numeric,numeric,numeric,numeric,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2326_flag_outlier(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2326_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2326_clear_flag(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2326_list_cohorts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2326_list_points() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2326_add_cohort(text,int,int,int,int,numeric,numeric,numeric,numeric,numeric,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2326_add_point(uuid,text,int,int,numeric,numeric,numeric,numeric,numeric,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2326_flag_outlier(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2326_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2326_clear_flag(uuid) TO authenticated;

COMMIT;
