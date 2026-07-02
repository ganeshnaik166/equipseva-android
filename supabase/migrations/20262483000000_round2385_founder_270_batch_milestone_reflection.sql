BEGIN;

-- Round 2385: Founder 270-batch milestone reflection
-- Two tables capturing top system-level patterns learned across 270 batches
-- plus strategic direction for the next 270.

CREATE TABLE IF NOT EXISTS public.founder_270_batch_patterns_r2385 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pattern_rank int NOT NULL CHECK (pattern_rank BETWEEN 1 AND 10),
  pattern_name text NOT NULL,
  pattern_category text NOT NULL CHECK (pattern_category IN (
    'schema_discipline','sql_safety','jsx_safety','rls_security',
    'workflow_orchestration','design_consistency','ops_velocity',
    'audit_loop','founder_ux','milestone_cadence'
  )),
  batches_observed_in int NOT NULL DEFAULT 0,
  bugs_prevented_count int NOT NULL DEFAULT 0,
  evidence_summary text NOT NULL,
  remediation_codified_in text,
  noted_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  noted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_next_270_directions_r2385 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  direction_rank int NOT NULL CHECK (direction_rank BETWEEN 1 AND 10),
  direction_title text NOT NULL,
  strategic_theme text NOT NULL CHECK (strategic_theme IN (
    'revenue_acceleration','founder_leverage','automation_depth',
    'audit_resilience','design_system_maturity','data_room_polish',
    'compliance_moat','operator_dashboard','international_pilot',
    'platform_consolidation'
  )),
  target_batch_window text NOT NULL,
  expected_ship_count int NOT NULL DEFAULT 0,
  owner_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  rationale text NOT NULL,
  success_metric text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_270_batch_patterns_r2385 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_next_270_directions_r2385 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_270_batch_patterns_r2385;
CREATE POLICY founder_all ON public.founder_270_batch_patterns_r2385
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_next_270_directions_r2385;
CREATE POLICY founder_all ON public.founder_next_270_directions_r2385
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list top-10 patterns
CREATE OR REPLACE FUNCTION public.founder_r2385_list_patterns()
RETURNS TABLE (
  id uuid,
  pattern_rank int,
  pattern_name text,
  pattern_category text,
  batches_observed_in int,
  bugs_prevented_count int,
  evidence_summary text,
  remediation_codified_in text,
  noted_at timestamptz
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
    SELECT p.id, p.pattern_rank, p.pattern_name, p.pattern_category,
           p.batches_observed_in, p.bugs_prevented_count,
           p.evidence_summary, p.remediation_codified_in, p.noted_at
    FROM public.founder_270_batch_patterns_r2385 p
    ORDER BY p.pattern_rank ASC;
END;
$$;

-- RPC 2: list next-270 directions
CREATE OR REPLACE FUNCTION public.founder_r2385_list_directions()
RETURNS TABLE (
  id uuid,
  direction_rank int,
  direction_title text,
  strategic_theme text,
  target_batch_window text,
  expected_ship_count int,
  rationale text,
  success_metric text
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
    SELECT d.id, d.direction_rank, d.direction_title, d.strategic_theme,
           d.target_batch_window, d.expected_ship_count,
           d.rationale, d.success_metric
    FROM public.founder_next_270_directions_r2385 d
    ORDER BY d.direction_rank ASC;
END;
$$;

-- RPC 3: pattern category rollup
CREATE OR REPLACE FUNCTION public.founder_r2385_pattern_category_rollup()
RETURNS TABLE (
  pattern_category text,
  patterns_count bigint,
  total_bugs_prevented bigint,
  total_batches_observed bigint
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
    SELECT p.pattern_category,
           count(*)::bigint,
           coalesce(sum(p.bugs_prevented_count),0)::bigint,
           coalesce(sum(p.batches_observed_in),0)::bigint
    FROM public.founder_270_batch_patterns_r2385 p
    GROUP BY p.pattern_category
    ORDER BY total_bugs_prevented DESC;
END;
$$;

-- RPC 4: direction theme rollup
CREATE OR REPLACE FUNCTION public.founder_r2385_direction_theme_rollup()
RETURNS TABLE (
  strategic_theme text,
  directions_count bigint,
  total_expected_ships bigint
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
    SELECT d.strategic_theme,
           count(*)::bigint,
           coalesce(sum(d.expected_ship_count),0)::bigint
    FROM public.founder_next_270_directions_r2385 d
    GROUP BY d.strategic_theme
    ORDER BY total_expected_ships DESC;
END;
$$;

-- RPC 5: overall milestone stats
CREATE OR REPLACE FUNCTION public.founder_r2385_milestone_stats()
RETURNS TABLE (
  patterns_logged bigint,
  total_bugs_prevented bigint,
  directions_logged bigint,
  total_expected_ships bigint,
  avg_bugs_per_pattern numeric
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
      (SELECT count(*) FROM public.founder_270_batch_patterns_r2385)::bigint,
      (SELECT coalesce(sum(bugs_prevented_count),0) FROM public.founder_270_batch_patterns_r2385)::bigint,
      (SELECT count(*) FROM public.founder_next_270_directions_r2385)::bigint,
      (SELECT coalesce(sum(expected_ship_count),0) FROM public.founder_next_270_directions_r2385)::bigint,
      (SELECT coalesce(round(avg(bugs_prevented_count)::numeric, 2), 0)
         FROM public.founder_270_batch_patterns_r2385);
END;
$$;

-- RPC 6: upsert a pattern
CREATE OR REPLACE FUNCTION public.founder_r2385_upsert_pattern(
  p_rank int,
  p_name text,
  p_category text,
  p_batches int,
  p_bugs int,
  p_evidence text,
  p_remediation text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_profile uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT id INTO v_profile
  FROM public.profiles
  WHERE email = auth.jwt()->>'email'
  LIMIT 1;

  INSERT INTO public.founder_270_batch_patterns_r2385
    (pattern_rank, pattern_name, pattern_category,
     batches_observed_in, bugs_prevented_count,
     evidence_summary, remediation_codified_in, noted_by_profile_id)
  VALUES (p_rank, p_name, p_category, p_batches, p_bugs,
          p_evidence, p_remediation, v_profile)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- RPC 7: upsert a direction
CREATE OR REPLACE FUNCTION public.founder_r2385_upsert_direction(
  p_rank int,
  p_title text,
  p_theme text,
  p_window text,
  p_expected_ships int,
  p_rationale text,
  p_metric text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_profile uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT id INTO v_profile
  FROM public.profiles
  WHERE email = auth.jwt()->>'email'
  LIMIT 1;

  INSERT INTO public.founder_next_270_directions_r2385
    (direction_rank, direction_title, strategic_theme,
     target_batch_window, expected_ship_count,
     owner_profile_id, rationale, success_metric)
  VALUES (p_rank, p_title, p_theme, p_window, p_expected_ships,
          v_profile, p_rationale, p_metric)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2385_list_patterns() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_r2385_list_directions() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_r2385_pattern_category_rollup() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_r2385_direction_theme_rollup() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_r2385_milestone_stats() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_r2385_upsert_pattern(int,text,text,int,int,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_r2385_upsert_direction(int,text,text,text,int,text,text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_r2385_list_patterns() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_r2385_list_directions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_r2385_pattern_category_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_r2385_direction_theme_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_r2385_milestone_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_r2385_upsert_pattern(int,text,text,int,int,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_r2385_upsert_direction(int,text,text,text,int,text,text) TO authenticated;

COMMIT;
