-- Round 2418: Engineer Onboarding Runway Tracker
-- Tracks new hire milestones, days since start, ramp-up curve, shadowing hours, first-solo-call timing.

BEGIN;

-- ============================================================
-- TABLE: engineer_onboarding_milestones_r2418
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_onboarding_milestones_r2418 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  engineer_name text NOT NULL,
  hire_date date NOT NULL,
  milestone_kind text NOT NULL
    CHECK (milestone_kind IN ('orientation','safety_cert','first_shadow','first_solo_call','first_pm','first_amc_signoff','first_critical_repair')),
  target_day integer NOT NULL,
  achieved_at timestamptz,
  days_to_achieve integer,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','achieved','overdue','waived')),
  mentor_email text,
  notes text,
  CHECK (target_day >= 0 AND target_day <= 365),
  CHECK (days_to_achieve IS NULL OR days_to_achieve >= 0)
);

ALTER TABLE public.engineer_onboarding_milestones_r2418 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_onboarding_milestones_r2418;
CREATE POLICY founder_all ON public.engineer_onboarding_milestones_r2418
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_onboarding_r2418_engineer
  ON public.engineer_onboarding_milestones_r2418(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_r2418_status
  ON public.engineer_onboarding_milestones_r2418(status);
CREATE INDEX IF NOT EXISTS idx_onboarding_r2418_kind
  ON public.engineer_onboarding_milestones_r2418(milestone_kind);
CREATE INDEX IF NOT EXISTS idx_onboarding_r2418_hire
  ON public.engineer_onboarding_milestones_r2418(hire_date DESC);

-- ============================================================
-- TABLE: engineer_ramp_metrics_r2418
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_ramp_metrics_r2418 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  engineer_name text NOT NULL,
  hire_date date NOT NULL,
  shadowing_hours numeric(8,2) NOT NULL DEFAULT 0,
  solo_jobs integer NOT NULL DEFAULT 0,
  supervised_jobs integer NOT NULL DEFAULT 0,
  csat_avg numeric(3,2),
  slo_breaches integer NOT NULL DEFAULT 0,
  ramp_score_pct integer NOT NULL DEFAULT 0,
  status_label text NOT NULL DEFAULT 'on_track'
    CHECK (status_label IN ('below_curve','on_track','above_curve')),
  notes text,
  CHECK (shadowing_hours >= 0),
  CHECK (solo_jobs >= 0),
  CHECK (supervised_jobs >= 0),
  CHECK (slo_breaches >= 0),
  CHECK (ramp_score_pct >= 0 AND ramp_score_pct <= 100),
  CHECK (csat_avg IS NULL OR (csat_avg >= 0 AND csat_avg <= 5))
);

ALTER TABLE public.engineer_ramp_metrics_r2418 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_ramp_metrics_r2418;
CREATE POLICY founder_all ON public.engineer_ramp_metrics_r2418
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_ramp_r2418_engineer
  ON public.engineer_ramp_metrics_r2418(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ramp_r2418_status
  ON public.engineer_ramp_metrics_r2418(status_label);
CREATE INDEX IF NOT EXISTS idx_ramp_r2418_score
  ON public.engineer_ramp_metrics_r2418(ramp_score_pct DESC);

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO public.engineer_onboarding_milestones_r2418
  (engineer_name, hire_date, milestone_kind, target_day, achieved_at, days_to_achieve, status, mentor_email, notes)
VALUES
  ('Ravi Kumar', '2026-05-01', 'orientation', 2, '2026-05-02T10:00:00Z'::timestamptz, 1, 'achieved', 'mentor.anil@equipseva.in', 'Day-1 orientation completed'),
  ('Ravi Kumar', '2026-05-01', 'safety_cert', 5, '2026-05-05T15:00:00Z'::timestamptz, 4, 'achieved', 'mentor.anil@equipseva.in', 'CDSCO safety module passed'),
  ('Ravi Kumar', '2026-05-01', 'first_shadow', 7, '2026-05-08T11:00:00Z'::timestamptz, 7, 'achieved', 'mentor.anil@equipseva.in', 'Shadowed 3 PM visits'),
  ('Ravi Kumar', '2026-05-01', 'first_solo_call', 21, NULL, NULL, 'pending', 'mentor.anil@equipseva.in', 'Scheduled next week'),
  ('Priya Sharma', '2026-04-15', 'orientation', 2, '2026-04-16T09:00:00Z'::timestamptz, 1, 'achieved', 'mentor.suresh@equipseva.in', NULL),
  ('Priya Sharma', '2026-04-15', 'first_solo_call', 21, '2026-05-04T14:00:00Z'::timestamptz, 19, 'achieved', 'mentor.suresh@equipseva.in', 'Solo PM, 4.5 CSAT'),
  ('Priya Sharma', '2026-04-15', 'first_pm', 30, '2026-05-13T10:00:00Z'::timestamptz, 28, 'achieved', 'mentor.suresh@equipseva.in', NULL),
  ('Priya Sharma', '2026-04-15', 'first_critical_repair', 60, NULL, NULL, 'pending', 'mentor.suresh@equipseva.in', 'Awaiting opportunity'),
  ('Arjun Mehta', '2026-03-10', 'first_solo_call', 21, NULL, NULL, 'overdue', 'mentor.deepak@equipseva.in', 'Confidence gap, extra shadow scheduled'),
  ('Arjun Mehta', '2026-03-10', 'first_pm', 30, '2026-05-15T11:00:00Z'::timestamptz, 66, 'achieved', 'mentor.deepak@equipseva.in', 'Late but completed'),
  ('Sneha Iyer', '2026-06-01', 'orientation', 2, '2026-06-02T10:00:00Z'::timestamptz, 1, 'achieved', 'mentor.anil@equipseva.in', 'Fresh hire'),
  ('Sneha Iyer', '2026-06-01', 'safety_cert', 5, NULL, NULL, 'pending', 'mentor.anil@equipseva.in', NULL);

INSERT INTO public.engineer_ramp_metrics_r2418
  (engineer_name, hire_date, shadowing_hours, solo_jobs, supervised_jobs, csat_avg, slo_breaches, ramp_score_pct, status_label, notes)
VALUES
  ('Ravi Kumar', '2026-05-01', 42.5, 2, 8, 4.40, 1, 55, 'on_track', 'Solid trajectory'),
  ('Priya Sharma', '2026-04-15', 68.0, 9, 14, 4.60, 0, 82, 'above_curve', 'Top of cohort'),
  ('Arjun Mehta', '2026-03-10', 95.0, 4, 18, 3.90, 5, 38, 'below_curve', 'Needs PIP'),
  ('Sneha Iyer', '2026-06-01', 8.0, 0, 1, NULL, 0, 12, 'on_track', 'Just started');

-- ============================================================
-- RPC 1: list_onboarding_r2418
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_onboarding_r2418()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  hire_date date,
  milestone_kind text,
  target_day integer,
  achieved_at timestamptz,
  days_to_achieve integer,
  status text,
  mentor_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.engineer_name, m.hire_date, m.milestone_kind, m.target_day,
         m.achieved_at, m.days_to_achieve, m.status, m.mentor_email, m.notes
  FROM public.engineer_onboarding_milestones_r2418 m
  ORDER BY m.hire_date DESC, m.target_day ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_onboarding_r2418() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_onboarding_r2418() TO authenticated;

-- ============================================================
-- RPC 2: list_ramp_metrics_r2418
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_ramp_metrics_r2418()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  hire_date date,
  shadowing_hours numeric,
  solo_jobs integer,
  supervised_jobs integer,
  csat_avg numeric,
  slo_breaches integer,
  ramp_score_pct integer,
  status_label text,
  days_since_hire integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_name, r.hire_date, r.shadowing_hours, r.solo_jobs,
         r.supervised_jobs, r.csat_avg, r.slo_breaches, r.ramp_score_pct,
         r.status_label,
         (CURRENT_DATE - r.hire_date)::integer AS days_since_hire
  FROM public.engineer_ramp_metrics_r2418 r
  ORDER BY r.ramp_score_pct DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_ramp_metrics_r2418() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_ramp_metrics_r2418() TO authenticated;

-- ============================================================
-- RPC 3: overdue_milestones_r2418
-- ============================================================
CREATE OR REPLACE FUNCTION public.overdue_milestones_r2418()
RETURNS TABLE (
  engineer_name text,
  hire_date date,
  milestone_kind text,
  target_day integer,
  days_past_target integer,
  mentor_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.engineer_name, m.hire_date, m.milestone_kind, m.target_day,
         ((CURRENT_DATE - m.hire_date) - m.target_day)::integer AS days_past_target,
         m.mentor_email
  FROM public.engineer_onboarding_milestones_r2418 m
  WHERE m.status IN ('pending','overdue')
    AND (CURRENT_DATE - m.hire_date) > m.target_day
  ORDER BY days_past_target DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.overdue_milestones_r2418() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_milestones_r2418() TO authenticated;

-- ============================================================
-- RPC 4: below_curve_engineers_r2418
-- ============================================================
CREATE OR REPLACE FUNCTION public.below_curve_engineers_r2418()
RETURNS TABLE (
  engineer_name text,
  hire_date date,
  ramp_score_pct integer,
  solo_jobs integer,
  csat_avg numeric,
  slo_breaches integer,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_name, r.hire_date, r.ramp_score_pct, r.solo_jobs,
         r.csat_avg, r.slo_breaches, r.notes
  FROM public.engineer_ramp_metrics_r2418 r
  WHERE r.status_label = 'below_curve'
  ORDER BY r.ramp_score_pct ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.below_curve_engineers_r2418() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.below_curve_engineers_r2418() TO authenticated;

-- ============================================================
-- RPC 5: top_ramp_performers_r2418
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_ramp_performers_r2418()
RETURNS TABLE (
  engineer_name text,
  hire_date date,
  ramp_score_pct integer,
  solo_jobs integer,
  csat_avg numeric,
  status_label text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_name, r.hire_date, r.ramp_score_pct, r.solo_jobs,
         r.csat_avg, r.status_label
  FROM public.engineer_ramp_metrics_r2418 r
  WHERE r.status_label = 'above_curve'
     OR r.ramp_score_pct >= 70
  ORDER BY r.ramp_score_pct DESC
  LIMIT 10;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_ramp_performers_r2418() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_ramp_performers_r2418() TO authenticated;

-- ============================================================
-- RPC 6: ramp_distribution_r2418
-- ============================================================
CREATE OR REPLACE FUNCTION public.ramp_distribution_r2418()
RETURNS TABLE (
  status_label text,
  engineer_count bigint,
  avg_score numeric,
  avg_solo_jobs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.status_label,
         COUNT(*)::bigint AS engineer_count,
         ROUND(AVG(r.ramp_score_pct)::numeric, 1) AS avg_score,
         ROUND(AVG(r.solo_jobs)::numeric, 1) AS avg_solo_jobs
  FROM public.engineer_ramp_metrics_r2418 r
  GROUP BY r.status_label
  ORDER BY avg_score DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.ramp_distribution_r2418() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ramp_distribution_r2418() TO authenticated;

-- ============================================================
-- RPC 7: mentor_load_r2418
-- ============================================================
CREATE OR REPLACE FUNCTION public.mentor_load_r2418()
RETURNS TABLE (
  mentor_email text,
  mentee_count bigint,
  pending_milestones bigint,
  achieved_milestones bigint,
  overdue_milestones bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.mentor_email,
         COUNT(DISTINCT m.engineer_name)::bigint AS mentee_count,
         COUNT(*) FILTER (WHERE m.status = 'pending')::bigint AS pending_milestones,
         COUNT(*) FILTER (WHERE m.status = 'achieved')::bigint AS achieved_milestones,
         COUNT(*) FILTER (WHERE m.status = 'overdue')::bigint AS overdue_milestones
  FROM public.engineer_onboarding_milestones_r2418 m
  WHERE m.mentor_email IS NOT NULL
  GROUP BY m.mentor_email
  ORDER BY mentee_count DESC, overdue_milestones DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mentor_load_r2418() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mentor_load_r2418() TO authenticated;

