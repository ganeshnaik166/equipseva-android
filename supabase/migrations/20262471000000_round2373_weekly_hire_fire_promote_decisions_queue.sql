BEGIN;

-- =========================================================
-- r2373 — Founder weekly hire/fire/promote decisions queue
-- =========================================================

CREATE TABLE IF NOT EXISTS public.founder_people_decisions_r2373 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  subject_name text NOT NULL,
  subject_role text NOT NULL,
  decision_type text NOT NULL CHECK (decision_type IN ('hire','fire','promote','demote','reassign','pip','bonus')),
  decision_status text NOT NULL DEFAULT 'pending'
    CHECK (decision_status IN ('pending','approved','rejected','deferred','executed')),
  urgency text NOT NULL DEFAULT 'normal' CHECK (urgency IN ('low','normal','high','critical')),
  rationale text,
  proposed_by_email text,
  proposed_at timestamptz NOT NULL DEFAULT now(),
  decision_deadline_at timestamptz,
  decided_at timestamptz,
  decided_by_email text,
  downstream_impact text,
  blast_radius_users int DEFAULT 0,
  monthly_cost_delta_rupees bigint DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpd_r2373_status ON public.founder_people_decisions_r2373(decision_status);
CREATE INDEX IF NOT EXISTS idx_fpd_r2373_deadline ON public.founder_people_decisions_r2373(decision_deadline_at);
CREATE INDEX IF NOT EXISTS idx_fpd_r2373_proposed ON public.founder_people_decisions_r2373(proposed_at DESC);

ALTER TABLE public.founder_people_decisions_r2373 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_people_decisions_r2373;
CREATE POLICY founder_all ON public.founder_people_decisions_r2373
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_people_decision_events_r2373 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.founder_people_decisions_r2373(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('proposed','reviewed','approved','rejected','deferred','executed','note','escalated')),
  event_actor_email text,
  event_note text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpde_r2373_decision ON public.founder_people_decision_events_r2373(decision_id);
CREATE INDEX IF NOT EXISTS idx_fpde_r2373_when ON public.founder_people_decision_events_r2373(recorded_at DESC);

ALTER TABLE public.founder_people_decision_events_r2373 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_people_decision_events_r2373;
CREATE POLICY founder_all ON public.founder_people_decision_events_r2373
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================
-- RPCs (7) — all founder-gated
-- =========================================================

-- 1. List pending queue with days waiting
DROP FUNCTION IF EXISTS public.fhfpdq_r2373_list_queue();
CREATE FUNCTION public.fhfpdq_r2373_list_queue()
RETURNS TABLE (
  id uuid,
  subject_name text,
  subject_role text,
  decision_type text,
  decision_status text,
  urgency text,
  rationale text,
  proposed_at timestamptz,
  days_waiting int,
  decision_deadline_at timestamptz,
  days_to_deadline int,
  downstream_impact text,
  blast_radius_users int,
  monthly_cost_delta_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.subject_name,
    d.subject_role,
    d.decision_type,
    d.decision_status,
    d.urgency,
    d.rationale,
    d.proposed_at,
    GREATEST(0, EXTRACT(day FROM (now() - d.proposed_at))::int) AS days_waiting,
    d.decision_deadline_at,
    CASE WHEN d.decision_deadline_at IS NULL THEN NULL
         ELSE EXTRACT(day FROM (d.decision_deadline_at - now()))::int END AS days_to_deadline,
    d.downstream_impact,
    d.blast_radius_users,
    d.monthly_cost_delta_rupees
  FROM public.founder_people_decisions_r2373 d
  WHERE d.decision_status = 'pending'
  ORDER BY
    CASE d.urgency WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 ELSE 3 END,
    d.decision_deadline_at NULLS LAST,
    d.proposed_at;
END;
$$;

REVOKE ALL ON FUNCTION public.fhfpdq_r2373_list_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fhfpdq_r2373_list_queue() TO authenticated;

-- 2. Summary KPIs
DROP FUNCTION IF EXISTS public.fhfpdq_r2373_summary();
CREATE FUNCTION public.fhfpdq_r2373_summary()
RETURNS TABLE (
  pending_total bigint,
  pending_critical bigint,
  pending_overdue bigint,
  avg_days_waiting numeric,
  decisions_this_week bigint,
  total_monthly_cost_delta bigint,
  total_blast_radius bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE decision_status = 'pending')::bigint AS pending_total,
    COUNT(*) FILTER (WHERE decision_status = 'pending' AND urgency = 'critical')::bigint AS pending_critical,
    COUNT(*) FILTER (WHERE decision_status = 'pending' AND decision_deadline_at IS NOT NULL AND decision_deadline_at < now())::bigint AS pending_overdue,
    COALESCE(AVG(EXTRACT(day FROM (now() - proposed_at))) FILTER (WHERE decision_status = 'pending'), 0)::numeric AS avg_days_waiting,
    COUNT(*) FILTER (WHERE decided_at >= now() - INTERVAL '7 days')::bigint AS decisions_this_week,
    COALESCE(SUM(monthly_cost_delta_rupees) FILTER (WHERE decision_status = 'pending'), 0)::bigint AS total_monthly_cost_delta,
    COALESCE(SUM(blast_radius_users) FILTER (WHERE decision_status = 'pending'), 0)::bigint AS total_blast_radius
  FROM public.founder_people_decisions_r2373;
END;
$$;

REVOKE ALL ON FUNCTION public.fhfpdq_r2373_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fhfpdq_r2373_summary() TO authenticated;

-- 3. Breakdown by decision type
DROP FUNCTION IF EXISTS public.fhfpdq_r2373_by_type();
CREATE FUNCTION public.fhfpdq_r2373_by_type()
RETURNS TABLE (
  decision_type text,
  pending_count bigint,
  avg_days_waiting numeric,
  total_blast_radius bigint,
  total_cost_delta bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.decision_type,
    COUNT(*)::bigint AS pending_count,
    COALESCE(AVG(EXTRACT(day FROM (now() - d.proposed_at))), 0)::numeric AS avg_days_waiting,
    COALESCE(SUM(d.blast_radius_users), 0)::bigint AS total_blast_radius,
    COALESCE(SUM(d.monthly_cost_delta_rupees), 0)::bigint AS total_cost_delta
  FROM public.founder_people_decisions_r2373 d
  WHERE d.decision_status = 'pending'
  GROUP BY d.decision_type
  ORDER BY pending_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.fhfpdq_r2373_by_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fhfpdq_r2373_by_type() TO authenticated;

-- 4. Overdue decisions (past deadline)
DROP FUNCTION IF EXISTS public.fhfpdq_r2373_overdue();
CREATE FUNCTION public.fhfpdq_r2373_overdue()
RETURNS TABLE (
  id uuid,
  subject_name text,
  subject_role text,
  decision_type text,
  urgency text,
  decision_deadline_at timestamptz,
  days_overdue int,
  downstream_impact text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.subject_name,
    d.subject_role,
    d.decision_type,
    d.urgency,
    d.decision_deadline_at,
    EXTRACT(day FROM (now() - d.decision_deadline_at))::int AS days_overdue,
    d.downstream_impact
  FROM public.founder_people_decisions_r2373 d
  WHERE d.decision_status = 'pending'
    AND d.decision_deadline_at IS NOT NULL
    AND d.decision_deadline_at < now()
  ORDER BY d.decision_deadline_at;
END;
$$;

REVOKE ALL ON FUNCTION public.fhfpdq_r2373_overdue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fhfpdq_r2373_overdue() TO authenticated;

-- 5. Recent decided history
DROP FUNCTION IF EXISTS public.fhfpdq_r2373_recent_decisions(int);
CREATE FUNCTION public.fhfpdq_r2373_recent_decisions(p_limit int DEFAULT 25)
RETURNS TABLE (
  id uuid,
  subject_name text,
  subject_role text,
  decision_type text,
  decision_status text,
  decided_at timestamptz,
  decided_by_email text,
  days_to_close int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.subject_name,
    d.subject_role,
    d.decision_type,
    d.decision_status,
    d.decided_at,
    d.decided_by_email,
    CASE WHEN d.decided_at IS NULL THEN NULL
         ELSE EXTRACT(day FROM (d.decided_at - d.proposed_at))::int END AS days_to_close
  FROM public.founder_people_decisions_r2373 d
  WHERE d.decided_at IS NOT NULL
  ORDER BY d.decided_at DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 25));
END;
$$;

REVOKE ALL ON FUNCTION public.fhfpdq_r2373_recent_decisions(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fhfpdq_r2373_recent_decisions(int) TO authenticated;

-- 6. Highest-impact pending
DROP FUNCTION IF EXISTS public.fhfpdq_r2373_top_impact(int);
CREATE FUNCTION public.fhfpdq_r2373_top_impact(p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  subject_name text,
  decision_type text,
  urgency text,
  blast_radius_users int,
  monthly_cost_delta_rupees bigint,
  downstream_impact text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.subject_name,
    d.decision_type,
    d.urgency,
    d.blast_radius_users,
    d.monthly_cost_delta_rupees,
    d.downstream_impact
  FROM public.founder_people_decisions_r2373 d
  WHERE d.decision_status = 'pending'
  ORDER BY
    (COALESCE(d.blast_radius_users,0) * 1000 + ABS(COALESCE(d.monthly_cost_delta_rupees,0)) / 1000) DESC,
    d.proposed_at
  LIMIT GREATEST(1, COALESCE(p_limit, 10));
END;
$$;

REVOKE ALL ON FUNCTION public.fhfpdq_r2373_top_impact(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fhfpdq_r2373_top_impact(int) TO authenticated;

-- 7. Recent activity events
DROP FUNCTION IF EXISTS public.fhfpdq_r2373_recent_events(int);
CREATE FUNCTION public.fhfpdq_r2373_recent_events(p_limit int DEFAULT 50)
RETURNS TABLE (
  recorded_at timestamptz,
  subject_name text,
  event_type text,
  event_actor_email text,
  event_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.recorded_at,
    d.subject_name,
    e.event_type,
    e.event_actor_email,
    e.event_note
  FROM public.founder_people_decision_events_r2373 e
  JOIN public.founder_people_decisions_r2373 d ON d.id = e.decision_id
  ORDER BY e.recorded_at DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

REVOKE ALL ON FUNCTION public.fhfpdq_r2373_recent_events(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fhfpdq_r2373_recent_events(int) TO authenticated;

COMMIT;
