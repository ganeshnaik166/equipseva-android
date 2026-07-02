-- Round 2333: Founder upcoming-decision queue
-- 30-day forecasted decisions with dependencies, owners, deadlines

BEGIN;

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_upcoming_decisions_r2333 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_title text NOT NULL,
  decision_category text NOT NULL CHECK (decision_category IN (
    'hiring','fundraise','product','pricing','partnership','vendor',
    'compliance','expansion','marketing','ops','tech','legal','finance'
  )),
  decision_summary text NOT NULL,
  options_considered jsonb NOT NULL DEFAULT '[]'::jsonb,
  recommended_option text,
  blast_radius text NOT NULL CHECK (blast_radius IN ('low','medium','high','company_defining')),
  reversibility text NOT NULL CHECK (reversibility IN ('one_way','two_way','easy')),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  owner_role text,
  deadline_at timestamptz NOT NULL,
  scheduled_for_at timestamptz,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN (
    'pending','prepping','ready_for_review','decided','deferred','cancelled'
  )),
  outcome text,
  outcome_decided_at timestamptz,
  outcome_decided_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  estimated_prep_hours numeric(6,2),
  inputs_needed jsonb NOT NULL DEFAULT '[]'::jsonb,
  stakeholders_to_consult jsonb NOT NULL DEFAULT '[]'::jsonb,
  forecast_confidence numeric(3,2) CHECK (forecast_confidence >= 0 AND forecast_confidence <= 1),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fud_r2333_deadline
  ON public.founder_upcoming_decisions_r2333(deadline_at)
  WHERE status NOT IN ('decided','cancelled');

CREATE INDEX IF NOT EXISTS idx_fud_r2333_status
  ON public.founder_upcoming_decisions_r2333(status);

CREATE INDEX IF NOT EXISTS idx_fud_r2333_owner
  ON public.founder_upcoming_decisions_r2333(owner_user_id);

CREATE TABLE IF NOT EXISTS public.founder_decision_dependencies_r2333 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.founder_upcoming_decisions_r2333(id) ON DELETE CASCADE,
  dependency_kind text NOT NULL CHECK (dependency_kind IN (
    'blocks','blocked_by','informs','informed_by','related'
  )),
  depends_on_decision_id uuid REFERENCES public.founder_upcoming_decisions_r2333(id) ON DELETE CASCADE,
  external_dependency text,
  dependency_status text NOT NULL DEFAULT 'pending' CHECK (dependency_status IN (
    'pending','satisfied','blocked','at_risk'
  )),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (depends_on_decision_id IS NOT NULL AND external_dependency IS NULL)
    OR (depends_on_decision_id IS NULL AND external_dependency IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_fdd_r2333_decision
  ON public.founder_decision_dependencies_r2333(decision_id);

CREATE INDEX IF NOT EXISTS idx_fdd_r2333_depends
  ON public.founder_decision_dependencies_r2333(depends_on_decision_id);

ALTER TABLE public.founder_upcoming_decisions_r2333 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_decision_dependencies_r2333 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_upcoming_decisions_r2333;
CREATE POLICY founder_all ON public.founder_upcoming_decisions_r2333
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_decision_dependencies_r2333;
CREATE POLICY founder_all ON public.founder_decision_dependencies_r2333
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: queue overview (30 day forecast)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_decision_queue_overview_r2333()
RETURNS TABLE (
  total_decisions int,
  due_within_7d int,
  due_within_30d int,
  overdue_count int,
  pending_count int,
  prepping_count int,
  ready_for_review_count int,
  company_defining_count int,
  blocked_count int,
  avg_prep_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_upcoming_decisions_r2333
    WHERE status NOT IN ('decided','cancelled')
  ),
  blocked AS (
    SELECT DISTINCT decision_id
    FROM public.founder_decision_dependencies_r2333
    WHERE dependency_status IN ('blocked','at_risk')
  )
  SELECT
    (SELECT count(*)::int FROM base),
    (SELECT count(*)::int FROM base WHERE deadline_at <= now() + interval '7 days' AND deadline_at >= now()),
    (SELECT count(*)::int FROM base WHERE deadline_at <= now() + interval '30 days' AND deadline_at >= now()),
    (SELECT count(*)::int FROM base WHERE deadline_at < now()),
    (SELECT count(*)::int FROM base WHERE status = 'pending'),
    (SELECT count(*)::int FROM base WHERE status = 'prepping'),
    (SELECT count(*)::int FROM base WHERE status = 'ready_for_review'),
    (SELECT count(*)::int FROM base WHERE blast_radius = 'company_defining'),
    (SELECT count(*)::int FROM base WHERE id IN (SELECT decision_id FROM blocked)),
    (SELECT COALESCE(round(avg(estimated_prep_hours)::numeric, 2), 0) FROM base WHERE estimated_prep_hours IS NOT NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.founder_decision_queue_overview_r2333() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_decision_queue_overview_r2333() TO authenticated;

-- ============================================================================
-- RPC 2: list upcoming decisions (30 day window)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_decision_queue_list_r2333(
  p_status_filter text DEFAULT NULL,
  p_days_ahead int DEFAULT 30
)
RETURNS TABLE (
  id uuid,
  decision_title text,
  decision_category text,
  blast_radius text,
  reversibility text,
  owner_email text,
  owner_role text,
  deadline_at timestamptz,
  days_until_deadline numeric,
  status text,
  estimated_prep_hours numeric,
  forecast_confidence numeric,
  dependency_count int,
  blocker_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.decision_title,
    d.decision_category,
    d.blast_radius,
    d.reversibility,
    p.email,
    d.owner_role,
    d.deadline_at,
    round(EXTRACT(EPOCH FROM (d.deadline_at - now()))::numeric / 86400.0, 2),
    d.status,
    d.estimated_prep_hours,
    d.forecast_confidence,
    (SELECT count(*)::int FROM public.founder_decision_dependencies_r2333 dep
       WHERE dep.decision_id = d.id),
    (SELECT count(*)::int FROM public.founder_decision_dependencies_r2333 dep
       WHERE dep.decision_id = d.id AND dep.dependency_status IN ('blocked','at_risk'))
  FROM public.founder_upcoming_decisions_r2333 d
  LEFT JOIN public.profiles p ON p.id = d.owner_user_id
  WHERE
    (p_status_filter IS NULL OR d.status = p_status_filter)
    AND d.status NOT IN ('decided','cancelled')
    AND d.deadline_at <= now() + (p_days_ahead || ' days')::interval
  ORDER BY d.deadline_at ASC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_decision_queue_list_r2333(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_decision_queue_list_r2333(text, int) TO authenticated;

-- ============================================================================
-- RPC 3: detail with dependencies
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_decision_detail_r2333(p_decision_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT jsonb_build_object(
    'decision', to_jsonb(d.*),
    'owner_email', p.email,
    'dependencies', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', dep.id,
        'kind', dep.dependency_kind,
        'status', dep.dependency_status,
        'depends_on_title', dod.decision_title,
        'external', dep.external_dependency,
        'notes', dep.notes
      ) ORDER BY dep.created_at)
      FROM public.founder_decision_dependencies_r2333 dep
      LEFT JOIN public.founder_upcoming_decisions_r2333 dod
        ON dod.id = dep.depends_on_decision_id
      WHERE dep.decision_id = d.id
    ), '[]'::jsonb)
  )
  INTO v_result
  FROM public.founder_upcoming_decisions_r2333 d
  LEFT JOIN public.profiles p ON p.id = d.owner_user_id
  WHERE d.id = p_decision_id;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.founder_decision_detail_r2333(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_decision_detail_r2333(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: breakdown by category
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_decision_category_breakdown_r2333()
RETURNS TABLE (
  decision_category text,
  total int,
  due_within_7d int,
  company_defining int,
  one_way_count int,
  avg_prep_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.decision_category,
    count(*)::int,
    count(*) FILTER (WHERE d.deadline_at <= now() + interval '7 days' AND d.deadline_at >= now())::int,
    count(*) FILTER (WHERE d.blast_radius = 'company_defining')::int,
    count(*) FILTER (WHERE d.reversibility = 'one_way')::int,
    COALESCE(round(avg(d.estimated_prep_hours)::numeric, 2), 0)
  FROM public.founder_upcoming_decisions_r2333 d
  WHERE d.status NOT IN ('decided','cancelled')
  GROUP BY d.decision_category
  ORDER BY count(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_decision_category_breakdown_r2333() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_decision_category_breakdown_r2333() TO authenticated;

-- ============================================================================
-- RPC 5: owner workload
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_decision_owner_workload_r2333()
RETURNS TABLE (
  owner_user_id uuid,
  owner_email text,
  owner_role text,
  open_decisions int,
  due_within_7d int,
  total_prep_hours numeric,
  oldest_deadline timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.owner_user_id,
    p.email,
    MAX(d.owner_role),
    count(*)::int,
    count(*) FILTER (WHERE d.deadline_at <= now() + interval '7 days')::int,
    COALESCE(sum(d.estimated_prep_hours), 0),
    min(d.deadline_at)
  FROM public.founder_upcoming_decisions_r2333 d
  LEFT JOIN public.profiles p ON p.id = d.owner_user_id
  WHERE d.status NOT IN ('decided','cancelled')
  GROUP BY d.owner_user_id, p.email
  ORDER BY count(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_decision_owner_workload_r2333() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_decision_owner_workload_r2333() TO authenticated;

-- ============================================================================
-- RPC 6: blocked / at-risk dependencies
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_decision_blocked_r2333()
RETURNS TABLE (
  decision_id uuid,
  decision_title text,
  deadline_at timestamptz,
  blast_radius text,
  blocker_kind text,
  blocker_status text,
  external_blocker text,
  upstream_decision_title text,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.decision_title,
    d.deadline_at,
    d.blast_radius,
    dep.dependency_kind,
    dep.dependency_status,
    dep.external_dependency,
    dod.decision_title,
    dep.notes
  FROM public.founder_decision_dependencies_r2333 dep
  JOIN public.founder_upcoming_decisions_r2333 d
    ON d.id = dep.decision_id
  LEFT JOIN public.founder_upcoming_decisions_r2333 dod
    ON dod.id = dep.depends_on_decision_id
  WHERE dep.dependency_status IN ('blocked','at_risk')
    AND d.status NOT IN ('decided','cancelled')
  ORDER BY d.deadline_at ASC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_decision_blocked_r2333() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_decision_blocked_r2333() TO authenticated;

-- ============================================================================
-- RPC 7: 30-day timeline buckets (day-by-day load)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_decision_timeline_r2333()
RETURNS TABLE (
  deadline_day date,
  decisions_due int,
  company_defining int,
  one_way int,
  total_prep_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.deadline_at::date AS deadline_day,
    count(*)::int,
    count(*) FILTER (WHERE d.blast_radius = 'company_defining')::int,
    count(*) FILTER (WHERE d.reversibility = 'one_way')::int,
    COALESCE(sum(d.estimated_prep_hours), 0)
  FROM public.founder_upcoming_decisions_r2333 d
  WHERE d.status NOT IN ('decided','cancelled')
    AND d.deadline_at >= now()
    AND d.deadline_at <= now() + interval '30 days'
  GROUP BY d.deadline_at::date
  ORDER BY d.deadline_at::date ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_decision_timeline_r2333() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_decision_timeline_r2333() TO authenticated;

COMMIT;
