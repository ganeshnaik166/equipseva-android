BEGIN;
-- r1433: /founder-hospital-department-breakout
-- Per-department equipment + revenue breakout for hospital orgs.
-- 1 table (founder_hospital_departments) + 6 RPCs (4 read + 2 write-log).
-- All read RPCs: LANGUAGE plpgsql STABLE SECURITY DEFINER + is_founder() gate.
-- Write-log RPCs: VOLATILE SECURITY DEFINER + is_founder() gate.



-- =========================================================================
-- TABLE: founder_hospital_departments
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.founder_hospital_departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  department_label text NOT NULL,
  department_kind text NOT NULL CHECK (department_kind IN (
    'icu','ot','radiology','pathology_lab','dental_clinic',
    'outpatient','emergency','maternity','pharmacy','admin'
  )),
  total_equipment_count int NOT NULL DEFAULT 0 CHECK (total_equipment_count >= 0),
  total_visits_30d int NOT NULL DEFAULT 0 CHECK (total_visits_30d >= 0),
  last_visit_at timestamptz,
  primary_engineer_id uuid,
  department_lead_name text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hospital_user_id, department_label)
);

CREATE INDEX IF NOT EXISTS founder_hospital_departments_kind_idx
  ON public.founder_hospital_departments (department_kind);
CREATE INDEX IF NOT EXISTS founder_hospital_departments_hospital_idx
  ON public.founder_hospital_departments (hospital_user_id);
CREATE INDEX IF NOT EXISTS founder_hospital_departments_last_visit_idx
  ON public.founder_hospital_departments (last_visit_at DESC NULLS LAST);

ALTER TABLE public.founder_hospital_departments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_hosp_dept_founder_all ON public.founder_hospital_departments;
CREATE POLICY founder_hosp_dept_founder_all ON public.founder_hospital_departments
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_hospital_departments FROM PUBLIC, anon, authenticated;

-- =========================================================================
-- RPC 1: summary (14 KPIs)
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_department_breakout_summary();
CREATE OR REPLACE FUNCTION public.founder_hospital_department_breakout_summary()
RETURNS TABLE (
  total_departments bigint,
  top_dept_kind text,
  top_dept_kind_count bigint,
  hospitals_with_departments bigint,
  avg_departments_per_hospital numeric,
  total_equipment_across_depts bigint,
  total_visits_30d bigint,
  top_dept_by_visits text,
  top_dept_by_visits_count bigint,
  depts_with_no_visits_30d bigint,
  depts_idle_over_60d bigint,
  unique_engineers_assigned bigint,
  max_equipment_in_one_dept bigint,
  avg_equipment_per_dept numeric,
  generated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder gate' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_hospital_departments
  ),
  kind_agg AS (
    SELECT department_kind, COUNT(*)::bigint AS c
    FROM base GROUP BY department_kind
    ORDER BY c DESC NULLS LAST LIMIT 1
  ),
  visit_top AS (
    SELECT department_label, total_visits_30d
    FROM base ORDER BY total_visits_30d DESC NULLS LAST LIMIT 1
  )
  SELECT
    (SELECT COUNT(*)::bigint FROM base),
    (SELECT department_kind FROM kind_agg),
    COALESCE((SELECT c FROM kind_agg), 0),
    (SELECT COUNT(DISTINCT hospital_user_id)::bigint FROM base),
    COALESCE((SELECT ROUND(COUNT(*)::numeric / NULLIF(COUNT(DISTINCT hospital_user_id), 0), 2) FROM base), 0),
    COALESCE((SELECT SUM(total_equipment_count)::bigint FROM base), 0),
    COALESCE((SELECT SUM(total_visits_30d)::bigint FROM base), 0),
    (SELECT department_label FROM visit_top),
    COALESCE((SELECT total_visits_30d FROM visit_top), 0),
    (SELECT COUNT(*)::bigint FROM base WHERE total_visits_30d = 0),
    (SELECT COUNT(*)::bigint FROM base WHERE last_visit_at IS NULL OR last_visit_at < now() - interval '60 days'),
    (SELECT COUNT(DISTINCT primary_engineer_id)::bigint FROM base WHERE primary_engineer_id IS NOT NULL),
    COALESCE((SELECT MAX(total_equipment_count)::bigint FROM base), 0),
    COALESCE((SELECT ROUND(AVG(total_equipment_count)::numeric, 2) FROM base), 0),
    now();
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hospital_department_breakout_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_department_breakout_summary() TO authenticated;

-- =========================================================================
-- RPC 2: recent departments
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_department_breakout_recent(int);
CREATE OR REPLACE FUNCTION public.founder_hospital_department_breakout_recent(p_limit int DEFAULT 40)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  department_label text,
  department_kind text,
  total_equipment_count int,
  total_visits_30d int,
  last_visit_at timestamptz,
  department_lead_name text,
  primary_engineer_id uuid,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder gate' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT d.id, d.hospital_user_id, d.department_label, d.department_kind,
         d.total_equipment_count, d.total_visits_30d, d.last_visit_at,
         d.department_lead_name, d.primary_engineer_id, d.created_at, d.updated_at
  FROM public.founder_hospital_departments d
  ORDER BY d.updated_at DESC NULLS LAST, d.created_at DESC
  LIMIT GREATEST(LEAST(COALESCE(p_limit, 40), 200), 1);
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hospital_department_breakout_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_department_breakout_recent(int) TO authenticated;

-- =========================================================================
-- RPC 3: breakdown by kind
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_department_breakout_by_kind();
CREATE OR REPLACE FUNCTION public.founder_hospital_department_breakout_by_kind()
RETURNS TABLE (
  department_kind text,
  dept_count bigint,
  hospitals_count bigint,
  total_equipment bigint,
  total_visits_30d bigint,
  avg_equipment_per_dept numeric,
  avg_visits_per_dept numeric,
  idle_over_60d_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder gate' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    d.department_kind,
    COUNT(*)::bigint,
    COUNT(DISTINCT d.hospital_user_id)::bigint,
    COALESCE(SUM(d.total_equipment_count), 0)::bigint,
    COALESCE(SUM(d.total_visits_30d), 0)::bigint,
    COALESCE(ROUND(AVG(d.total_equipment_count)::numeric, 2), 0),
    COALESCE(ROUND(AVG(d.total_visits_30d)::numeric, 2), 0),
    COUNT(*) FILTER (WHERE d.last_visit_at IS NULL OR d.last_visit_at < now() - interval '60 days')::bigint
  FROM public.founder_hospital_departments d
  GROUP BY d.department_kind
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hospital_department_breakout_by_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_department_breakout_by_kind() TO authenticated;

-- =========================================================================
-- RPC 4: top revenue departments (proxy: visits * equipment as load score)
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_department_top_revenue(int);
CREATE OR REPLACE FUNCTION public.founder_hospital_department_top_revenue(p_limit int DEFAULT 20)
RETURNS TABLE (
  rank_pos int,
  id uuid,
  department_label text,
  department_kind text,
  hospital_user_id uuid,
  total_equipment_count int,
  total_visits_30d int,
  load_score numeric,
  last_visit_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder gate' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY (d.total_equipment_count::numeric * d.total_visits_30d::numeric) DESC)::int,
    d.id, d.department_label, d.department_kind, d.hospital_user_id,
    d.total_equipment_count, d.total_visits_30d,
    (d.total_equipment_count::numeric * d.total_visits_30d::numeric) AS load_score,
    d.last_visit_at
  FROM public.founder_hospital_departments d
  WHERE d.total_equipment_count > 0 OR d.total_visits_30d > 0
  ORDER BY load_score DESC
  LIMIT GREATEST(LEAST(COALESCE(p_limit, 20), 100), 1);
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hospital_department_top_revenue(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_department_top_revenue(int) TO authenticated;

-- =========================================================================
-- RPC 5: log register (write — upsert department)
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_founder_hospital_department_register(uuid, text, text, int, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_hospital_department_register(
  p_hospital_user_id uuid,
  p_department_label text,
  p_department_kind text,
  p_total_equipment_count int DEFAULT 0,
  p_department_lead_name text DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder gate' USING ERRCODE = '42501';
  END IF;

  IF p_hospital_user_id IS NULL OR p_department_label IS NULL OR p_department_kind IS NULL THEN
    RAISE EXCEPTION 'required: hospital_user_id, department_label, department_kind';
  END IF;

  INSERT INTO public.founder_hospital_departments (
    hospital_user_id, department_label, department_kind,
    total_equipment_count, department_lead_name, notes
  ) VALUES (
    p_hospital_user_id, p_department_label, p_department_kind,
    COALESCE(p_total_equipment_count, 0), p_department_lead_name, p_notes
  )
  ON CONFLICT (hospital_user_id, department_label) DO UPDATE
    SET department_kind = EXCLUDED.department_kind,
        total_equipment_count = EXCLUDED.total_equipment_count,
        department_lead_name = COALESCE(EXCLUDED.department_lead_name, public.founder_hospital_departments.department_lead_name),
        notes = COALESCE(EXCLUDED.notes, public.founder_hospital_departments.notes),
        updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_hospital_department_register(uuid, text, text, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_hospital_department_register(uuid, text, text, int, text, text) TO authenticated;

-- =========================================================================
-- RPC 6: log record visit (write — increment visits, bump last_visit_at)
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_founder_hospital_department_record_visit(uuid, int);
CREATE OR REPLACE FUNCTION public.log_founder_hospital_department_record_visit(
  p_department_id uuid,
  p_visit_increment int DEFAULT 1
) RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_found boolean := false;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder gate' USING ERRCODE = '42501';
  END IF;

  IF p_department_id IS NULL THEN
    RAISE EXCEPTION 'required: department_id';
  END IF;

  UPDATE public.founder_hospital_departments
     SET total_visits_30d = total_visits_30d + GREATEST(COALESCE(p_visit_increment, 1), 0),
         last_visit_at = now(),
         updated_at = now()
   WHERE id = p_department_id;

  v_found := FOUND;
  RETURN v_found;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_hospital_department_record_visit(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_hospital_department_record_visit(uuid, int) TO authenticated;

COMMIT;