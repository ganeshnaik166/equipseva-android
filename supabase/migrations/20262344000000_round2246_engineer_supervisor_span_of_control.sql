BEGIN;

CREATE TABLE IF NOT EXISTS public.supervisor_assignments_r2246 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  region text NOT NULL DEFAULT 'unassigned',
  assigned_on date NOT NULL DEFAULT CURRENT_DATE,
  unassigned_on date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','reassigned','terminated')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (supervisor_id, engineer_id, assigned_on)
);

CREATE TABLE IF NOT EXISTS public.supervisor_ratio_thresholds_r2246 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier text NOT NULL UNIQUE CHECK (tier IN ('junior','senior','lead','principal')),
  optimal_min int NOT NULL,
  optimal_max int NOT NULL,
  overload_threshold int NOT NULL,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (optimal_min <= optimal_max),
  CHECK (optimal_max <= overload_threshold)
);

ALTER TABLE public.supervisor_assignments_r2246 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisor_ratio_thresholds_r2246 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_assign_r2246 ON public.supervisor_assignments_r2246;
CREATE POLICY founder_all_assign_r2246 ON public.supervisor_assignments_r2246
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_thresh_r2246 ON public.supervisor_ratio_thresholds_r2246;
CREATE POLICY founder_all_thresh_r2246 ON public.supervisor_ratio_thresholds_r2246
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

INSERT INTO public.supervisor_ratio_thresholds_r2246 (tier, optimal_min, optimal_max, overload_threshold, notes) VALUES
  ('junior',    3,  6,  8,  'Junior supervisors: small team, close mentorship'),
  ('senior',    5,  9,  12, 'Senior supervisors: standard team size'),
  ('lead',      8,  14, 18, 'Lead supervisors: broader span, less direct mentorship'),
  ('principal', 12, 20, 25, 'Principal: regional oversight, indirect mentorship')
ON CONFLICT (tier) DO NOTHING;

-- RPC 1: list active assignments
CREATE OR REPLACE FUNCTION public.list_supervisor_assignments_r2246()
RETURNS TABLE (
  id uuid,
  supervisor_id uuid,
  engineer_id uuid,
  region text,
  assigned_on date,
  unassigned_on date,
  status text,
  days_assigned int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.supervisor_id, a.engineer_id, a.region, a.assigned_on, a.unassigned_on, a.status,
    (COALESCE(a.unassigned_on, CURRENT_DATE) - a.assigned_on)::int AS days_assigned
  FROM public.supervisor_assignments_r2246 a
  ORDER BY a.assigned_on DESC;
END;
$$;

-- RPC 2: span of control per supervisor
CREATE OR REPLACE FUNCTION public.supervisor_span_summary_r2246()
RETURNS TABLE (
  supervisor_id uuid,
  active_reports int,
  terminated_reports int,
  reassigned_reports int,
  regions_covered int,
  oldest_assignment_days int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.supervisor_id,
    (COUNT(*) FILTER (WHERE a.status = 'active'))::int AS active_reports,
    (COUNT(*) FILTER (WHERE a.status = 'terminated'))::int AS terminated_reports,
    (COUNT(*) FILTER (WHERE a.status = 'reassigned'))::int AS reassigned_reports,
    (COUNT(DISTINCT a.region) FILTER (WHERE a.status = 'active'))::int AS regions_covered,
    COALESCE(MAX((CURRENT_DATE - a.assigned_on)::int) FILTER (WHERE a.status = 'active'), 0)::int AS oldest_assignment_days
  FROM public.supervisor_assignments_r2246 a
  GROUP BY a.supervisor_id
  ORDER BY active_reports DESC;
END;
$$;

-- RPC 3: overloaded supervisors (active reports >= overload threshold for some tier; using lead default 18)
CREATE OR REPLACE FUNCTION public.overloaded_supervisors_r2246(p_threshold int DEFAULT 12)
RETURNS TABLE (
  supervisor_id uuid,
  active_reports int,
  threshold_used int,
  overload_by int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.supervisor_id, s.active_reports, p_threshold AS threshold_used,
    (s.active_reports - p_threshold)::int AS overload_by
  FROM (
    SELECT a.supervisor_id, (COUNT(*) FILTER (WHERE a.status = 'active'))::int AS active_reports
    FROM public.supervisor_assignments_r2246 a
    GROUP BY a.supervisor_id
  ) s
  WHERE s.active_reports >= p_threshold
  ORDER BY s.active_reports DESC;
END;
$$;

-- RPC 4: ratio thresholds list
CREATE OR REPLACE FUNCTION public.list_ratio_thresholds_r2246()
RETURNS TABLE (
  id uuid,
  tier text,
  optimal_min int,
  optimal_max int,
  overload_threshold int,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.tier, t.optimal_min, t.optimal_max, t.overload_threshold, t.notes
  FROM public.supervisor_ratio_thresholds_r2246 t
  ORDER BY t.optimal_max ASC;
END;
$$;

-- RPC 5: add assignment
CREATE OR REPLACE FUNCTION public.add_supervisor_assignment_r2246(
  p_supervisor_id uuid,
  p_engineer_id uuid,
  p_region text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.supervisor_assignments_r2246 (supervisor_id, engineer_id, region, notes)
  VALUES (p_supervisor_id, p_engineer_id, COALESCE(p_region, 'unassigned'), COALESCE(p_notes, ''))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 6: terminate assignment
CREATE OR REPLACE FUNCTION public.terminate_supervisor_assignment_r2246(
  p_assignment_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status NOT IN ('reassigned','terminated') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.supervisor_assignments_r2246
  SET status = p_new_status,
      unassigned_on = CURRENT_DATE,
      updated_at = now()
  WHERE id = p_assignment_id;
END;
$$;

-- RPC 7: org-wide stats
CREATE OR REPLACE FUNCTION public.supervisor_org_stats_r2246()
RETURNS TABLE (
  total_supervisors int,
  total_active_assignments int,
  avg_active_reports numeric,
  max_active_reports int,
  overloaded_count int,
  understaffed_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH per_sup AS (
    SELECT a.supervisor_id, (COUNT(*) FILTER (WHERE a.status = 'active'))::int AS active_reports
    FROM public.supervisor_assignments_r2246 a
    GROUP BY a.supervisor_id
  )
  SELECT
    (COUNT(*))::int AS total_supervisors,
    (COALESCE(SUM(active_reports), 0))::int AS total_active_assignments,
    ROUND(COALESCE(AVG(active_reports), 0)::numeric, 2) AS avg_active_reports,
    (COALESCE(MAX(active_reports), 0))::int AS max_active_reports,
    (COUNT(*) FILTER (WHERE active_reports >= 12))::int AS overloaded_count,
    (COUNT(*) FILTER (WHERE active_reports < 3 AND active_reports > 0))::int AS understaffed_count
  FROM per_sup;
END;
$$;

REVOKE ALL ON FUNCTION public.list_supervisor_assignments_r2246() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.supervisor_span_summary_r2246() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.overloaded_supervisors_r2246(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_ratio_thresholds_r2246() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.add_supervisor_assignment_r2246(uuid, uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.terminate_supervisor_assignment_r2246(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.supervisor_org_stats_r2246() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_supervisor_assignments_r2246() TO authenticated;
GRANT EXECUTE ON FUNCTION public.supervisor_span_summary_r2246() TO authenticated;
GRANT EXECUTE ON FUNCTION public.overloaded_supervisors_r2246(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_ratio_thresholds_r2246() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_supervisor_assignment_r2246(uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.terminate_supervisor_assignment_r2246(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.supervisor_org_stats_r2246() TO authenticated;

COMMIT;
