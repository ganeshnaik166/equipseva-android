BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_escalation_root_causes_r2318 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  escalation_ref text NOT NULL,
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  root_cause text NOT NULL CHECK (root_cause IN ('engineer','customer','part','schedule','equipment','process','communication','external')),
  sub_cause text,
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  preventable boolean NOT NULL DEFAULT false,
  resolved boolean NOT NULL DEFAULT false,
  resolved_at timestamptz,
  classified_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_escalation_actions_r2318 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  root_cause_id uuid NOT NULL REFERENCES public.founder_escalation_root_causes_r2318(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coaching','process_change','part_swap','reschedule','refund','training','escalate_vendor','none')),
  action_owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  action_taken_at timestamptz NOT NULL DEFAULT now(),
  outcome text CHECK (outcome IN ('resolved','partial','failed','pending')),
  cost_rupees int NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_escalation_root_causes_r2318 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_escalation_actions_r2318 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_root_cause_r2318 ON public.founder_escalation_root_causes_r2318;
CREATE POLICY founder_all_root_cause_r2318 ON public.founder_escalation_root_causes_r2318
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2318 ON public.founder_escalation_actions_r2318;
CREATE POLICY founder_all_action_r2318 ON public.founder_escalation_actions_r2318
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_esc_rc_r2318_root_cause ON public.founder_escalation_root_causes_r2318(root_cause);
CREATE INDEX IF NOT EXISTS idx_esc_rc_r2318_classified ON public.founder_escalation_root_causes_r2318(classified_at);
CREATE INDEX IF NOT EXISTS idx_esc_rc_r2318_engineer ON public.founder_escalation_root_causes_r2318(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_esc_rc_r2318_resolved ON public.founder_escalation_root_causes_r2318(resolved);
CREATE INDEX IF NOT EXISTS idx_esc_action_r2318_rc ON public.founder_escalation_actions_r2318(root_cause_id);
CREATE INDEX IF NOT EXISTS idx_esc_action_r2318_outcome ON public.founder_escalation_actions_r2318(outcome);

DROP FUNCTION IF EXISTS public.list_escalation_root_causes_r2318();
CREATE OR REPLACE FUNCTION public.list_escalation_root_causes_r2318()
RETURNS TABLE (
  id uuid,
  escalation_ref text,
  engineer_user_id uuid,
  engineer_email text,
  hospital_user_id uuid,
  hospital_email text,
  root_cause text,
  sub_cause text,
  severity text,
  preventable boolean,
  resolved boolean,
  resolved_at timestamptz,
  classified_at timestamptz,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.escalation_ref, r.engineer_user_id, e.email::text,
         r.hospital_user_id, h.email::text,
         r.root_cause, r.sub_cause, r.severity, r.preventable,
         r.resolved, r.resolved_at, r.classified_at, r.notes
  FROM public.founder_escalation_root_causes_r2318 r
  LEFT JOIN public.profiles e ON e.id = r.engineer_user_id
  LEFT JOIN public.profiles h ON h.id = r.hospital_user_id
  ORDER BY r.classified_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.root_cause_distribution_r2318();
CREATE OR REPLACE FUNCTION public.root_cause_distribution_r2318()
RETURNS TABLE (
  root_cause text,
  total_count bigint,
  resolved_count bigint,
  preventable_count bigint,
  critical_count bigint,
  avg_resolution_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.root_cause,
         count(*)::bigint AS total_count,
         count(*) FILTER (WHERE r.resolved)::bigint AS resolved_count,
         count(*) FILTER (WHERE r.preventable)::bigint AS preventable_count,
         count(*) FILTER (WHERE r.severity = 'critical')::bigint AS critical_count,
         round(avg(EXTRACT(EPOCH FROM (r.resolved_at - r.classified_at)) / 3600.0) FILTER (WHERE r.resolved AND r.resolved_at IS NOT NULL), 2) AS avg_resolution_hours
  FROM public.founder_escalation_root_causes_r2318 r
  GROUP BY r.root_cause
  ORDER BY total_count DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.root_cause_trend_r2318(int);
CREATE OR REPLACE FUNCTION public.root_cause_trend_r2318(p_weeks int DEFAULT 12)
RETURNS TABLE (
  week_start date,
  root_cause text,
  weekly_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', r.classified_at)::date AS week_start,
         r.root_cause,
         count(*)::bigint AS weekly_count
  FROM public.founder_escalation_root_causes_r2318 r
  WHERE r.classified_at >= now() - (p_weeks || ' weeks')::interval
  GROUP BY week_start, r.root_cause
  ORDER BY week_start DESC, weekly_count DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.engineer_escalation_leaderboard_r2318();
CREATE OR REPLACE FUNCTION public.engineer_escalation_leaderboard_r2318()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_escalations bigint,
  engineer_fault_count bigint,
  critical_count bigint,
  resolved_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_user_id, p.email::text,
         count(*)::bigint AS total_escalations,
         count(*) FILTER (WHERE r.root_cause = 'engineer')::bigint AS engineer_fault_count,
         count(*) FILTER (WHERE r.severity = 'critical')::bigint AS critical_count,
         count(*) FILTER (WHERE r.resolved)::bigint AS resolved_count
  FROM public.founder_escalation_root_causes_r2318 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  WHERE r.engineer_user_id IS NOT NULL
  GROUP BY r.engineer_user_id, p.email
  ORDER BY total_escalations DESC
  LIMIT 50;
END;
$$;

DROP FUNCTION IF EXISTS public.unresolved_escalations_r2318();
CREATE OR REPLACE FUNCTION public.unresolved_escalations_r2318()
RETURNS TABLE (
  id uuid,
  escalation_ref text,
  root_cause text,
  severity text,
  engineer_email text,
  hospital_email text,
  classified_at timestamptz,
  age_days numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.escalation_ref, r.root_cause, r.severity,
         e.email::text, h.email::text, r.classified_at,
         round(EXTRACT(EPOCH FROM (now() - r.classified_at)) / 86400.0, 1) AS age_days
  FROM public.founder_escalation_root_causes_r2318 r
  LEFT JOIN public.profiles e ON e.id = r.engineer_user_id
  LEFT JOIN public.profiles h ON h.id = r.hospital_user_id
  WHERE r.resolved = false
  ORDER BY
    CASE r.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    r.classified_at ASC;
END;
$$;

DROP FUNCTION IF EXISTS public.action_outcome_summary_r2318();
CREATE OR REPLACE FUNCTION public.action_outcome_summary_r2318()
RETURNS TABLE (
  action_type text,
  total_actions bigint,
  resolved_count bigint,
  failed_count bigint,
  pending_count bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_type,
         count(*)::bigint AS total_actions,
         count(*) FILTER (WHERE a.outcome = 'resolved')::bigint AS resolved_count,
         count(*) FILTER (WHERE a.outcome = 'failed')::bigint AS failed_count,
         count(*) FILTER (WHERE a.outcome = 'pending')::bigint AS pending_count,
         coalesce(sum(a.cost_rupees), 0)::bigint AS total_cost_rupees
  FROM public.founder_escalation_actions_r2318 a
  GROUP BY a.action_type
  ORDER BY total_actions DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.preventable_escalations_summary_r2318();
CREATE OR REPLACE FUNCTION public.preventable_escalations_summary_r2318()
RETURNS TABLE (
  root_cause text,
  preventable_count bigint,
  total_count bigint,
  preventable_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.root_cause,
         count(*) FILTER (WHERE r.preventable)::bigint AS preventable_count,
         count(*)::bigint AS total_count,
         round(100.0 * count(*) FILTER (WHERE r.preventable)::numeric / NULLIF(count(*)::numeric, 0), 1) AS preventable_pct
  FROM public.founder_escalation_root_causes_r2318 r
  GROUP BY r.root_cause
  ORDER BY preventable_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_escalation_root_causes_r2318() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.root_cause_distribution_r2318() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.root_cause_trend_r2318(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.engineer_escalation_leaderboard_r2318() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unresolved_escalations_r2318() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.action_outcome_summary_r2318() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.preventable_escalations_summary_r2318() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_escalation_root_causes_r2318() TO authenticated;
GRANT EXECUTE ON FUNCTION public.root_cause_distribution_r2318() TO authenticated;
GRANT EXECUTE ON FUNCTION public.root_cause_trend_r2318(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.engineer_escalation_leaderboard_r2318() TO authenticated;
GRANT EXECUTE ON FUNCTION public.unresolved_escalations_r2318() TO authenticated;
GRANT EXECUTE ON FUNCTION public.action_outcome_summary_r2318() TO authenticated;
GRANT EXECUTE ON FUNCTION public.preventable_escalations_summary_r2318() TO authenticated;

COMMIT;
