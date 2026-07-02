BEGIN;

-- ============================================================================
-- Round 2323 — Hospital Chain Operational-Excellence Scorecard
-- Operational metrics per chain (uptime, SLA, escalations) graded A-F
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_chain_op_scorecards_r2323 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_code text NOT NULL UNIQUE,
  hospital_count integer NOT NULL DEFAULT 0,
  uptime_pct numeric(5,2) NOT NULL DEFAULT 0,
  sla_compliance_pct numeric(5,2) NOT NULL DEFAULT 0,
  escalation_count integer NOT NULL DEFAULT 0,
  avg_resolution_hours numeric(8,2) NOT NULL DEFAULT 0,
  total_repair_jobs integer NOT NULL DEFAULT 0,
  failed_jobs integer NOT NULL DEFAULT 0,
  csat_score numeric(3,2) NOT NULL DEFAULT 0,
  composite_score numeric(5,2) NOT NULL DEFAULT 0,
  letter_grade text NOT NULL DEFAULT 'F' CHECK (letter_grade IN ('A','B','C','D','F')),
  period_start date NOT NULL,
  period_end date NOT NULL,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_op_metric_events_r2323 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scorecard_id uuid NOT NULL REFERENCES public.hospital_chain_op_scorecards_r2323(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('uptime_drop','sla_breach','escalation','resolution','csat_response','grade_change')),
  severity text NOT NULL DEFAULT 'info' CHECK (severity IN ('info','warn','high','critical')),
  metric_name text NOT NULL,
  metric_value numeric(12,2),
  notes text,
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcops_r2323_grade ON public.hospital_chain_op_scorecards_r2323(letter_grade);
CREATE INDEX IF NOT EXISTS idx_hcops_r2323_period ON public.hospital_chain_op_scorecards_r2323(period_end DESC);
CREATE INDEX IF NOT EXISTS idx_hcops_r2323_evt_card ON public.hospital_chain_op_metric_events_r2323(scorecard_id, recorded_at DESC);

ALTER TABLE public.hospital_chain_op_scorecards_r2323 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_op_metric_events_r2323 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_op_scorecards_r2323;
CREATE POLICY founder_all ON public.hospital_chain_op_scorecards_r2323
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_op_metric_events_r2323;
CREATE POLICY founder_all ON public.hospital_chain_op_metric_events_r2323
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list scorecards
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2323_list_scorecards()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_code text,
  hospital_count integer,
  uptime_pct numeric,
  sla_compliance_pct numeric,
  escalation_count integer,
  avg_resolution_hours numeric,
  total_repair_jobs integer,
  failed_jobs integer,
  csat_score numeric,
  composite_score numeric,
  letter_grade text,
  period_start date,
  period_end date,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_name, s.chain_code, s.hospital_count, s.uptime_pct,
         s.sla_compliance_pct, s.escalation_count, s.avg_resolution_hours,
         s.total_repair_jobs, s.failed_jobs, s.csat_score, s.composite_score,
         s.letter_grade, s.period_start, s.period_end, s.created_at
  FROM public.hospital_chain_op_scorecards_r2323 s
  ORDER BY s.composite_score DESC, s.chain_name ASC;
END;
$$;

-- ============================================================================
-- RPC 2: grade distribution
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2323_grade_distribution()
RETURNS TABLE (
  letter_grade text,
  chain_count bigint,
  avg_composite numeric,
  avg_uptime numeric,
  avg_sla numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.letter_grade,
         COUNT(*)::bigint,
         ROUND(AVG(s.composite_score),2),
         ROUND(AVG(s.uptime_pct),2),
         ROUND(AVG(s.sla_compliance_pct),2)
  FROM public.hospital_chain_op_scorecards_r2323 s
  GROUP BY s.letter_grade
  ORDER BY s.letter_grade ASC;
END;
$$;

-- ============================================================================
-- RPC 3: top + bottom performers
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2323_top_bottom_performers()
RETURNS TABLE (
  bucket text,
  chain_name text,
  chain_code text,
  composite_score numeric,
  letter_grade text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  (SELECT 'top'::text, s.chain_name, s.chain_code, s.composite_score, s.letter_grade
   FROM public.hospital_chain_op_scorecards_r2323 s
   ORDER BY s.composite_score DESC LIMIT 5)
  UNION ALL
  (SELECT 'bottom'::text, s.chain_name, s.chain_code, s.composite_score, s.letter_grade
   FROM public.hospital_chain_op_scorecards_r2323 s
   ORDER BY s.composite_score ASC LIMIT 5);
END;
$$;

-- ============================================================================
-- RPC 4: recent events
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2323_recent_events(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_code text,
  event_type text,
  severity text,
  metric_name text,
  metric_value numeric,
  notes text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, s.chain_name, s.chain_code, e.event_type, e.severity,
         e.metric_name, e.metric_value, e.notes, e.recorded_at
  FROM public.hospital_chain_op_metric_events_r2323 e
  JOIN public.hospital_chain_op_scorecards_r2323 s ON s.id = e.scorecard_id
  ORDER BY e.recorded_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- ============================================================================
-- RPC 5: aggregate KPIs
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2323_aggregate_kpis()
RETURNS TABLE (
  total_chains bigint,
  total_hospitals bigint,
  avg_uptime numeric,
  avg_sla numeric,
  avg_csat numeric,
  total_escalations bigint,
  a_grade_chains bigint,
  failing_chains bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::bigint,
         COALESCE(SUM(s.hospital_count),0)::bigint,
         ROUND(COALESCE(AVG(s.uptime_pct),0),2),
         ROUND(COALESCE(AVG(s.sla_compliance_pct),0),2),
         ROUND(COALESCE(AVG(s.csat_score),0),2),
         COALESCE(SUM(s.escalation_count),0)::bigint,
         COUNT(*) FILTER (WHERE s.letter_grade = 'A')::bigint,
         COUNT(*) FILTER (WHERE s.letter_grade IN ('D','F'))::bigint
  FROM public.hospital_chain_op_scorecards_r2323 s;
END;
$$;

-- ============================================================================
-- RPC 6: escalation hotspots
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2323_escalation_hotspots()
RETURNS TABLE (
  chain_name text,
  chain_code text,
  escalation_count integer,
  failed_jobs integer,
  total_repair_jobs integer,
  failure_rate_pct numeric,
  letter_grade text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.chain_name, s.chain_code, s.escalation_count, s.failed_jobs,
         s.total_repair_jobs,
         CASE WHEN s.total_repair_jobs > 0
              THEN ROUND((s.failed_jobs::numeric / s.total_repair_jobs::numeric) * 100, 2)
              ELSE 0 END,
         s.letter_grade
  FROM public.hospital_chain_op_scorecards_r2323 s
  WHERE s.escalation_count > 0 OR s.failed_jobs > 0
  ORDER BY s.escalation_count DESC, s.failed_jobs DESC
  LIMIT 25;
END;
$$;

-- ============================================================================
-- RPC 7: period coverage summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2323_period_coverage()
RETURNS TABLE (
  earliest_period date,
  latest_period date,
  scorecards_logged bigint,
  events_logged bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT MIN(s.period_start),
         MAX(s.period_end),
         (SELECT COUNT(*)::bigint FROM public.hospital_chain_op_scorecards_r2323),
         (SELECT COUNT(*)::bigint FROM public.hospital_chain_op_metric_events_r2323)
  FROM public.hospital_chain_op_scorecards_r2323 s;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE ALL ON FUNCTION public.r2323_list_scorecards() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2323_grade_distribution() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2323_top_bottom_performers() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2323_recent_events(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2323_aggregate_kpis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2323_escalation_hotspots() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2323_period_coverage() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2323_list_scorecards() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2323_grade_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2323_top_bottom_performers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2323_recent_events(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2323_aggregate_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2323_escalation_hotspots() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2323_period_coverage() TO authenticated;

COMMIT;
