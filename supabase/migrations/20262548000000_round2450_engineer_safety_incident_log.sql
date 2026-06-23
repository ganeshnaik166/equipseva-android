-- Round 2450 — Engineer Safety Incident Log
-- Tables: engineer_safety_incidents_r2450 + safety_incident_metrics_r2450
-- 7 RPCs for founder triage of safety events, root causes, repeat offenders, trends.

-- =====================================================================
-- TABLE 1: engineer_safety_incidents_r2450
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_safety_incidents_r2450 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  incident_at timestamptz NOT NULL DEFAULT now(),
  incident_kind text NOT NULL CHECK (incident_kind IN (
    'electrical_shock','radiation','chemical','cut','fall',
    'equipment_drop','burn','biohazard','near_miss'
  )),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  root_cause_kind text NOT NULL CHECK (root_cause_kind IN (
    'human_error','process_gap','equipment_failure','PPE_miss','communication','training'
  )),
  root_cause_md text NOT NULL DEFAULT '',
  corrective_action_md text NOT NULL DEFAULT '',
  near_miss boolean NOT NULL DEFAULT false,
  repeat_offender boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','investigating','closed','escalated')),
  owner_email text NOT NULL DEFAULT '',
  closed_at timestamptz,
  closed_by_email text,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_esi_r2450_at ON public.engineer_safety_incidents_r2450(incident_at DESC);
CREATE INDEX IF NOT EXISTS idx_esi_r2450_severity ON public.engineer_safety_incidents_r2450(severity);
CREATE INDEX IF NOT EXISTS idx_esi_r2450_status ON public.engineer_safety_incidents_r2450(status);
CREATE INDEX IF NOT EXISTS idx_esi_r2450_engineer ON public.engineer_safety_incidents_r2450(engineer_user_id);

ALTER TABLE public.engineer_safety_incidents_r2450 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_safety_incidents_r2450;
CREATE POLICY founder_all ON public.engineer_safety_incidents_r2450
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE 2: safety_incident_metrics_r2450
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.safety_incident_metrics_r2450 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_start date NOT NULL,
  period_end date NOT NULL,
  incident_count int NOT NULL DEFAULT 0,
  near_miss_count int NOT NULL DEFAULT 0,
  severe_count int NOT NULL DEFAULT 0,
  repeat_offender_count int NOT NULL DEFAULT 0,
  days_since_last_incident int NOT NULL DEFAULT 0,
  top_root_cause text NOT NULL DEFAULT '',
  action_plan_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'green' CHECK (status IN ('green','amber','red')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sim_r2450_period ON public.safety_incident_metrics_r2450(period_start DESC);

ALTER TABLE public.safety_incident_metrics_r2450 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.safety_incident_metrics_r2450;
CREATE POLICY founder_all ON public.safety_incident_metrics_r2450
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- SEED DATA
-- =====================================================================
INSERT INTO public.engineer_safety_incidents_r2450
  (incident_at, incident_kind, severity, root_cause_kind, root_cause_md, corrective_action_md, near_miss, repeat_offender, status, owner_email, notes)
VALUES
  ('2026-06-18 09:30:00+05:30'::timestamptz, 'electrical_shock', 'high', 'PPE_miss',
   'Engineer skipped insulated gloves while opening CT power module.',
   'Mandatory PPE checklist before module open. Spot audits weekly.',
   false, false, 'investigating', 'safety@equipseva.in', 'Engineer hospitalized 6h, discharged.'),
  ('2026-06-19 14:10:00+05:30'::timestamptz, 'near_miss', 'low', 'communication',
   'Hospital tech energized line while engineer mid-service. No injury.',
   'Lockout-tagout SOP enforced; hospital briefing pre-service.',
   true, false, 'closed', 'safety@equipseva.in', 'Closed same day.'),
  ('2026-06-20 11:45:00+05:30'::timestamptz, 'equipment_drop', 'medium', 'human_error',
   'X-ray tube head slipped during install; no personnel impact, ₹85k damage.',
   'Two-person lift mandated for >25kg. Lift rigs purchased.',
   false, true, 'escalated', 'founder@equipseva.in', 'Same engineer dropped ultrasound probe Apr-2026.'),
  ('2026-06-21 08:20:00+05:30'::timestamptz, 'chemical', 'critical', 'training',
   'Engineer mixed incompatible disinfectants in autoclave room.',
   'Chemical compatibility chart laminated at every site. Re-training all engineers.',
   false, false, 'open', 'safety@equipseva.in', 'Vapor exposure 3 staff, OPD treatment.');

INSERT INTO public.safety_incident_metrics_r2450
  (period_start, period_end, incident_count, near_miss_count, severe_count, repeat_offender_count,
   days_since_last_incident, top_root_cause, action_plan_md, status, notes)
VALUES
  ('2026-04-01','2026-04-30', 2, 4, 0, 0, 14, 'PPE_miss',
   'Monthly PPE audit + spot checks.', 'green', 'Baseline month.'),
  ('2026-05-01','2026-05-31', 3, 5, 1, 1, 8, 'human_error',
   'Two-person lift rollout. Repeat-offender coaching.', 'amber', 'One repeat offender flagged.'),
  ('2026-06-01','2026-06-30', 4, 6, 2, 1, 0, 'training',
   'Chemical compatibility retraining all 32 engineers. PPE checklist enforcement.',
   'red', 'Two severe incidents this month including 1 critical.');

-- =====================================================================
-- RPC 1: list_incidents_r2450
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_incidents_r2450()
RETURNS TABLE (
  id uuid,
  incident_at timestamptz,
  incident_kind text,
  severity text,
  root_cause_kind text,
  near_miss boolean,
  repeat_offender boolean,
  status text,
  owner_email text,
  corrective_action_md text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.incident_at, s.incident_kind, s.severity, s.root_cause_kind,
         s.near_miss, s.repeat_offender, s.status, s.owner_email,
         s.corrective_action_md, s.notes
  FROM public.engineer_safety_incidents_r2450 s
  ORDER BY s.incident_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_incidents_r2450() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_incidents_r2450() TO authenticated;

-- =====================================================================
-- RPC 2: list_metrics_r2450
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_metrics_r2450()
RETURNS TABLE (
  id uuid,
  period_start date,
  period_end date,
  incident_count int,
  near_miss_count int,
  severe_count int,
  repeat_offender_count int,
  days_since_last_incident int,
  top_root_cause text,
  status text,
  action_plan_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.period_start, m.period_end, m.incident_count, m.near_miss_count,
         m.severe_count, m.repeat_offender_count, m.days_since_last_incident,
         m.top_root_cause, m.status, m.action_plan_md
  FROM public.safety_incident_metrics_r2450 m
  ORDER BY m.period_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_metrics_r2450() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_metrics_r2450() TO authenticated;

-- =====================================================================
-- RPC 3: severity_breakdown_r2450
-- =====================================================================
CREATE OR REPLACE FUNCTION public.severity_breakdown_r2450()
RETURNS TABLE (
  severity text,
  incident_count bigint,
  open_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.severity,
         COUNT(*)::bigint AS incident_count,
         COUNT(*) FILTER (WHERE s.status IN ('open','investigating','escalated'))::bigint AS open_count
  FROM public.engineer_safety_incidents_r2450 s
  GROUP BY s.severity
  ORDER BY CASE s.severity
    WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.severity_breakdown_r2450() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.severity_breakdown_r2450() TO authenticated;

-- =====================================================================
-- RPC 4: root_cause_breakdown_r2450
-- =====================================================================
CREATE OR REPLACE FUNCTION public.root_cause_breakdown_r2450()
RETURNS TABLE (
  root_cause_kind text,
  incident_count bigint,
  severe_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.root_cause_kind,
         COUNT(*)::bigint AS incident_count,
         COUNT(*) FILTER (WHERE s.severity IN ('high','critical'))::bigint AS severe_count
  FROM public.engineer_safety_incidents_r2450 s
  GROUP BY s.root_cause_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.root_cause_breakdown_r2450() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.root_cause_breakdown_r2450() TO authenticated;

-- =====================================================================
-- RPC 5: repeat_offenders_r2450
-- =====================================================================
CREATE OR REPLACE FUNCTION public.repeat_offenders_r2450()
RETURNS TABLE (
  engineer_user_id uuid,
  incident_count bigint,
  last_incident_at timestamptz,
  worst_severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_user_id,
         COUNT(*)::bigint AS incident_count,
         MAX(s.incident_at) AS last_incident_at,
         (ARRAY_AGG(s.severity ORDER BY CASE s.severity
            WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END))[1] AS worst_severity
  FROM public.engineer_safety_incidents_r2450 s
  WHERE s.repeat_offender = true OR s.engineer_user_id IS NOT NULL
  GROUP BY s.engineer_user_id
  HAVING COUNT(*) >= 1
  ORDER BY COUNT(*) DESC, MAX(s.incident_at) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.repeat_offenders_r2450() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.repeat_offenders_r2450() TO authenticated;

-- =====================================================================
-- RPC 6: monthly_incident_trend_r2450
-- =====================================================================
CREATE OR REPLACE FUNCTION public.monthly_incident_trend_r2450()
RETURNS TABLE (
  period_start date,
  incident_count int,
  near_miss_count int,
  severe_count int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.period_start, m.incident_count, m.near_miss_count, m.severe_count, m.status
  FROM public.safety_incident_metrics_r2450 m
  ORDER BY m.period_start ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_incident_trend_r2450() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_incident_trend_r2450() TO authenticated;

-- =====================================================================
-- RPC 7: days_since_last_r2450
-- =====================================================================
CREATE OR REPLACE FUNCTION public.days_since_last_r2450()
RETURNS TABLE (
  days_since_last_incident int,
  last_incident_at timestamptz,
  last_severity text,
  last_kind text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT GREATEST(0, EXTRACT(DAY FROM (now() - MAX(s.incident_at)))::int) AS days_since_last_incident,
         MAX(s.incident_at) AS last_incident_at,
         (ARRAY_AGG(s.severity ORDER BY s.incident_at DESC))[1] AS last_severity,
         (ARRAY_AGG(s.incident_kind ORDER BY s.incident_at DESC))[1] AS last_kind
  FROM public.engineer_safety_incidents_r2450 s
  WHERE s.near_miss = false;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.days_since_last_r2450() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.days_since_last_r2450() TO authenticated;
