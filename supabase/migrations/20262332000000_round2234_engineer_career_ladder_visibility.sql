BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_ladder_snapshots_r2234 (
  id bigserial PRIMARY KEY,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_tier text NOT NULL,
  next_tier text,
  jobs_completed int NOT NULL DEFAULT 0,
  jobs_required_next int NOT NULL DEFAULT 0,
  days_active int NOT NULL DEFAULT 0,
  days_required_next int NOT NULL DEFAULT 0,
  csat_score numeric(4,2) NOT NULL DEFAULT 0,
  csat_required_next numeric(4,2) NOT NULL DEFAULT 0,
  promotion_eligible boolean NOT NULL DEFAULT false,
  snapshot_notes text,
  captured_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_ladder_snapshots_r2234 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_ladder_snapshots_r2234;
CREATE POLICY founder_all ON public.engineer_ladder_snapshots_r2234
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_ladder_promotion_events_r2234 (
  id bigserial PRIMARY KEY,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  from_tier text NOT NULL,
  to_tier text NOT NULL,
  event_kind text NOT NULL CHECK (event_kind IN ('promotion','demotion','hold','review')),
  triggered_by text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_ladder_promotion_events_r2234 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_ladder_promotion_events_r2234;
CREATE POLICY founder_all ON public.engineer_ladder_promotion_events_r2234
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.founder_ladder_summary_r2234()
RETURNS TABLE (
  total_engineers int,
  tier1_count int,
  tier2_count int,
  tier3_count int,
  promotion_eligible_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_engineers,
    (COUNT(*) FILTER (WHERE current_tier = 'tier1'))::int AS tier1_count,
    (COUNT(*) FILTER (WHERE current_tier = 'tier2'))::int AS tier2_count,
    (COUNT(*) FILTER (WHERE current_tier = 'tier3'))::int AS tier3_count,
    (COUNT(*) FILTER (WHERE promotion_eligible))::int AS promotion_eligible_count
  FROM public.engineer_ladder_snapshots_r2234;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ladder_summary_r2234() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ladder_summary_r2234() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_ladder_recent_snapshots_r2234()
RETURNS TABLE (
  id bigint,
  engineer_email text,
  current_tier text,
  next_tier text,
  jobs_completed int,
  jobs_required_next int,
  days_active int,
  csat_score numeric,
  promotion_eligible boolean,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    p.email::text AS engineer_email,
    s.current_tier,
    s.next_tier,
    s.jobs_completed,
    s.jobs_required_next,
    s.days_active,
    s.csat_score,
    s.promotion_eligible,
    s.captured_at
  FROM public.engineer_ladder_snapshots_r2234 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY s.captured_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ladder_recent_snapshots_r2234() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ladder_recent_snapshots_r2234() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_ladder_eligible_engineers_r2234()
RETURNS TABLE (
  engineer_email text,
  current_tier text,
  next_tier text,
  jobs_completed int,
  csat_score numeric,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.email::text AS engineer_email,
    s.current_tier,
    s.next_tier,
    s.jobs_completed,
    s.csat_score,
    s.captured_at
  FROM public.engineer_ladder_snapshots_r2234 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.promotion_eligible = true
  ORDER BY s.captured_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ladder_eligible_engineers_r2234() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ladder_eligible_engineers_r2234() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_ladder_promotion_events_r2234()
RETURNS TABLE (
  id bigint,
  engineer_email text,
  from_tier text,
  to_tier text,
  event_kind text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    p.email::text AS engineer_email,
    e.from_tier,
    e.to_tier,
    e.event_kind,
    e.notes,
    e.created_at
  FROM public.engineer_ladder_promotion_events_r2234 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  ORDER BY e.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ladder_promotion_events_r2234() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ladder_promotion_events_r2234() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_ladder_tier_distribution_r2234()
RETURNS TABLE (
  tier text,
  engineer_count int,
  avg_csat numeric,
  avg_jobs numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.current_tier AS tier,
    (COUNT(*))::int AS engineer_count,
    ROUND(AVG(s.csat_score)::numeric, 2) AS avg_csat,
    ROUND(AVG(s.jobs_completed)::numeric, 2) AS avg_jobs
  FROM public.engineer_ladder_snapshots_r2234 s
  GROUP BY s.current_tier
  ORDER BY s.current_tier;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ladder_tier_distribution_r2234() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ladder_tier_distribution_r2234() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_ladder_event_kind_breakdown_r2234()
RETURNS TABLE (
  event_kind text,
  event_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.event_kind,
    (COUNT(*))::int AS event_count
  FROM public.engineer_ladder_promotion_events_r2234 e
  GROUP BY e.event_kind
  ORDER BY event_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ladder_event_kind_breakdown_r2234() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ladder_event_kind_breakdown_r2234() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_ladder_near_promotion_r2234()
RETURNS TABLE (
  engineer_email text,
  current_tier text,
  next_tier text,
  jobs_remaining int,
  days_remaining int,
  csat_gap numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.email::text AS engineer_email,
    s.current_tier,
    s.next_tier,
    GREATEST(s.jobs_required_next - s.jobs_completed, 0) AS jobs_remaining,
    GREATEST(s.days_required_next - s.days_active, 0) AS days_remaining,
    ROUND(GREATEST(s.csat_required_next - s.csat_score, 0)::numeric, 2) AS csat_gap
  FROM public.engineer_ladder_snapshots_r2234 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.promotion_eligible = false
    AND s.next_tier IS NOT NULL
  ORDER BY (GREATEST(s.jobs_required_next - s.jobs_completed, 0)
          + GREATEST(s.days_required_next - s.days_active, 0)) ASC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ladder_near_promotion_r2234() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ladder_near_promotion_r2234() TO authenticated;

COMMIT;
