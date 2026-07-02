-- Round 2378: Engineer customer-handoff smoothness score
-- HEAVY founder console feature
-- Tracks engineer-to-engineer handoffs at hospitals: service gap, customer awareness, retention impact

BEGIN;

-- =====================================================================
-- TABLE 1: handoff events between outgoing and incoming engineers
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_customer_handoffs_r2378 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  outgoing_engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  incoming_engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  handoff_initiated_at timestamptz NOT NULL DEFAULT now(),
  handoff_completed_at timestamptz,
  reason text NOT NULL CHECK (reason IN ('reassignment','resignation','tier_upgrade','escalation','rotation','leave','termination')),
  handoff_status text NOT NULL DEFAULT 'in_progress' CHECK (handoff_status IN ('in_progress','completed','failed','abandoned')),
  service_gap_hours numeric(8,2) NOT NULL DEFAULT 0,
  customer_notified boolean NOT NULL DEFAULT false,
  customer_notified_at timestamptz,
  customer_acknowledged boolean NOT NULL DEFAULT false,
  knowledge_transfer_minutes int NOT NULL DEFAULT 0,
  shared_visit_count int NOT NULL DEFAULT 0,
  open_tickets_at_handoff int NOT NULL DEFAULT 0,
  open_tickets_resolved_during_handoff int NOT NULL DEFAULT 0,
  documentation_completeness_pct int NOT NULL DEFAULT 0 CHECK (documentation_completeness_pct BETWEEN 0 AND 100),
  smoothness_score int NOT NULL DEFAULT 0 CHECK (smoothness_score BETWEEN 0 AND 100),
  customer_blind boolean NOT NULL DEFAULT false,
  retention_status text NOT NULL DEFAULT 'pending' CHECK (retention_status IN ('pending','retained','at_risk','churned')),
  churn_attributed_to_handoff boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_handoffs_r2378_hospital ON public.engineer_customer_handoffs_r2378(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_handoffs_r2378_outgoing ON public.engineer_customer_handoffs_r2378(outgoing_engineer_id);
CREATE INDEX IF NOT EXISTS idx_handoffs_r2378_incoming ON public.engineer_customer_handoffs_r2378(incoming_engineer_id);
CREATE INDEX IF NOT EXISTS idx_handoffs_r2378_status ON public.engineer_customer_handoffs_r2378(handoff_status);
CREATE INDEX IF NOT EXISTS idx_handoffs_r2378_initiated ON public.engineer_customer_handoffs_r2378(handoff_initiated_at DESC);

ALTER TABLE public.engineer_customer_handoffs_r2378 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_handoffs_r2378 ON public.engineer_customer_handoffs_r2378;
CREATE POLICY founder_all_handoffs_r2378 ON public.engineer_customer_handoffs_r2378
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE 2: smoothness signal events captured during handoff window
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_handoff_signals_r2378 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  handoff_id uuid NOT NULL REFERENCES public.engineer_customer_handoffs_r2378(id) ON DELETE CASCADE,
  signal_kind text NOT NULL CHECK (signal_kind IN ('service_delay','customer_complaint','positive_feedback','missed_visit','escalation','sla_breach','csat_drop','csat_stable','amc_renewal_signal','amc_cancel_signal')),
  signal_weight int NOT NULL DEFAULT 0,
  signal_at timestamptz NOT NULL DEFAULT now(),
  detail text,
  source_table text,
  source_id uuid,
  resolved boolean NOT NULL DEFAULT false,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_signals_r2378_handoff ON public.engineer_handoff_signals_r2378(handoff_id);
CREATE INDEX IF NOT EXISTS idx_signals_r2378_kind ON public.engineer_handoff_signals_r2378(signal_kind);
CREATE INDEX IF NOT EXISTS idx_signals_r2378_at ON public.engineer_handoff_signals_r2378(signal_at DESC);

ALTER TABLE public.engineer_handoff_signals_r2378 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_signals_r2378 ON public.engineer_handoff_signals_r2378;
CREATE POLICY founder_all_signals_r2378 ON public.engineer_handoff_signals_r2378
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: overview KPIs
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2378_handoff_overview()
RETURNS TABLE(
  total_handoffs bigint,
  completed_handoffs bigint,
  in_progress_handoffs bigint,
  failed_handoffs bigint,
  avg_smoothness_score numeric,
  avg_service_gap_hours numeric,
  customer_blind_pct numeric,
  churn_attributed_count bigint,
  churn_attribution_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE handoff_status = 'completed')::bigint,
    COUNT(*) FILTER (WHERE handoff_status = 'in_progress')::bigint,
    COUNT(*) FILTER (WHERE handoff_status = 'failed')::bigint,
    COALESCE(ROUND(AVG(smoothness_score) FILTER (WHERE handoff_status = 'completed'), 1), 0)::numeric,
    COALESCE(ROUND(AVG(service_gap_hours) FILTER (WHERE handoff_status = 'completed'), 2), 0)::numeric,
    CASE WHEN COUNT(*) FILTER (WHERE handoff_status = 'completed') > 0
         THEN ROUND(100.0 * COUNT(*) FILTER (WHERE customer_blind AND handoff_status = 'completed') / COUNT(*) FILTER (WHERE handoff_status = 'completed'), 1)
         ELSE 0 END::numeric,
    COUNT(*) FILTER (WHERE churn_attributed_to_handoff)::bigint,
    CASE WHEN COUNT(*) FILTER (WHERE handoff_status = 'completed') > 0
         THEN ROUND(100.0 * COUNT(*) FILTER (WHERE churn_attributed_to_handoff) / COUNT(*) FILTER (WHERE handoff_status = 'completed'), 1)
         ELSE 0 END::numeric
  FROM public.engineer_customer_handoffs_r2378;
END;
$$;

-- =====================================================================
-- RPC 2: recent handoffs with full detail
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2378_recent_handoffs(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  hospital_name text,
  outgoing_engineer_email text,
  incoming_engineer_email text,
  handoff_initiated_at timestamptz,
  handoff_completed_at timestamptz,
  reason text,
  handoff_status text,
  smoothness_score int,
  service_gap_hours numeric,
  customer_blind boolean,
  retention_status text,
  open_tickets_at_handoff int,
  documentation_completeness_pct int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    h.id,
    COALESCE(o.name, 'unknown')::text,
    COALESCE(po.email, 'n/a')::text,
    COALESCE(pi.email, 'n/a')::text,
    h.handoff_initiated_at,
    h.handoff_completed_at,
    h.reason,
    h.handoff_status,
    h.smoothness_score,
    h.service_gap_hours,
    h.customer_blind,
    h.retention_status,
    h.open_tickets_at_handoff,
    h.documentation_completeness_pct
  FROM public.engineer_customer_handoffs_r2378 h
  LEFT JOIN public.organizations o ON o.id = h.hospital_org_id
  LEFT JOIN public.profiles po ON po.id = h.outgoing_engineer_id
  LEFT JOIN public.profiles pi ON pi.id = h.incoming_engineer_id
  ORDER BY h.handoff_initiated_at DESC
  LIMIT p_limit;
END;
$$;

-- =====================================================================
-- RPC 3: smoothness distribution buckets
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2378_smoothness_distribution()
RETURNS TABLE(
  bucket text,
  handoff_count bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*) INTO v_total FROM public.engineer_customer_handoffs_r2378 WHERE handoff_status = 'completed';
  IF v_total = 0 THEN v_total := 1; END IF;

  RETURN QUERY
  SELECT
    b.bucket::text,
    b.cnt::bigint,
    ROUND(100.0 * b.cnt / v_total, 1)::numeric
  FROM (
    SELECT 'excellent_90_100' AS bucket, COUNT(*) AS cnt FROM public.engineer_customer_handoffs_r2378 WHERE handoff_status = 'completed' AND smoothness_score >= 90
    UNION ALL
    SELECT 'good_75_89', COUNT(*) FROM public.engineer_customer_handoffs_r2378 WHERE handoff_status = 'completed' AND smoothness_score BETWEEN 75 AND 89
    UNION ALL
    SELECT 'acceptable_60_74', COUNT(*) FROM public.engineer_customer_handoffs_r2378 WHERE handoff_status = 'completed' AND smoothness_score BETWEEN 60 AND 74
    UNION ALL
    SELECT 'poor_40_59', COUNT(*) FROM public.engineer_customer_handoffs_r2378 WHERE handoff_status = 'completed' AND smoothness_score BETWEEN 40 AND 59
    UNION ALL
    SELECT 'critical_below_40', COUNT(*) FROM public.engineer_customer_handoffs_r2378 WHERE handoff_status = 'completed' AND smoothness_score < 40
  ) b
  ORDER BY
    CASE b.bucket
      WHEN 'excellent_90_100' THEN 1
      WHEN 'good_75_89' THEN 2
      WHEN 'acceptable_60_74' THEN 3
      WHEN 'poor_40_59' THEN 4
      ELSE 5 END;
END;
$$;

-- =====================================================================
-- RPC 4: at-risk handoffs needing intervention
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2378_at_risk_handoffs()
RETURNS TABLE(
  id uuid,
  hospital_name text,
  outgoing_engineer_email text,
  incoming_engineer_email text,
  handoff_initiated_at timestamptz,
  smoothness_score int,
  service_gap_hours numeric,
  open_tickets_at_handoff int,
  documentation_completeness_pct int,
  risk_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    h.id,
    COALESCE(o.name, 'unknown')::text,
    COALESCE(po.email, 'n/a')::text,
    COALESCE(pi.email, 'n/a')::text,
    h.handoff_initiated_at,
    h.smoothness_score,
    h.service_gap_hours,
    h.open_tickets_at_handoff,
    h.documentation_completeness_pct,
    CASE
      WHEN h.service_gap_hours > 24 THEN 'service_gap_exceeded_24h'
      WHEN h.documentation_completeness_pct < 50 THEN 'low_doc_completeness'
      WHEN h.open_tickets_at_handoff > 5 THEN 'high_open_ticket_load'
      WHEN NOT h.customer_notified THEN 'customer_not_notified'
      ELSE 'compound_risk'
    END::text
  FROM public.engineer_customer_handoffs_r2378 h
  LEFT JOIN public.organizations o ON o.id = h.hospital_org_id
  LEFT JOIN public.profiles po ON po.id = h.outgoing_engineer_id
  LEFT JOIN public.profiles pi ON pi.id = h.incoming_engineer_id
  WHERE h.handoff_status = 'in_progress'
    AND (
      h.service_gap_hours > 24
      OR h.documentation_completeness_pct < 50
      OR h.open_tickets_at_handoff > 5
      OR NOT h.customer_notified
    )
  ORDER BY h.handoff_initiated_at ASC;
END;
$$;

-- =====================================================================
-- RPC 5: signal breakdown by kind
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2378_signal_breakdown()
RETURNS TABLE(
  signal_kind text,
  total_signals bigint,
  unresolved_signals bigint,
  avg_weight numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    s.signal_kind::text,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE NOT s.resolved)::bigint,
    COALESCE(ROUND(AVG(s.signal_weight), 1), 0)::numeric
  FROM public.engineer_handoff_signals_r2378 s
  GROUP BY s.signal_kind
  ORDER BY COUNT(*) DESC;
END;
$$;

-- =====================================================================
-- RPC 6: retention impact analysis
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2378_retention_impact()
RETURNS TABLE(
  reason text,
  total_handoffs bigint,
  retained bigint,
  at_risk bigint,
  churned bigint,
  retention_pct numeric,
  avg_smoothness numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    h.reason::text,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE h.retention_status = 'retained')::bigint,
    COUNT(*) FILTER (WHERE h.retention_status = 'at_risk')::bigint,
    COUNT(*) FILTER (WHERE h.retention_status = 'churned')::bigint,
    CASE WHEN COUNT(*) > 0
         THEN ROUND(100.0 * COUNT(*) FILTER (WHERE h.retention_status = 'retained') / COUNT(*), 1)
         ELSE 0 END::numeric,
    COALESCE(ROUND(AVG(h.smoothness_score), 1), 0)::numeric
  FROM public.engineer_customer_handoffs_r2378 h
  WHERE h.handoff_status = 'completed'
  GROUP BY h.reason
  ORDER BY COUNT(*) DESC;
END;
$$;

-- =====================================================================
-- RPC 7: top performing outgoing engineers (best handoff hygiene)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2378_top_handoff_performers()
RETURNS TABLE(
  engineer_email text,
  handoff_count bigint,
  avg_smoothness numeric,
  avg_service_gap numeric,
  customer_blind_count bigint,
  retention_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    COALESCE(p.email, 'unknown')::text,
    COUNT(*)::bigint,
    COALESCE(ROUND(AVG(h.smoothness_score), 1), 0)::numeric,
    COALESCE(ROUND(AVG(h.service_gap_hours), 2), 0)::numeric,
    COUNT(*) FILTER (WHERE h.customer_blind)::bigint,
    CASE WHEN COUNT(*) > 0
         THEN ROUND(100.0 * COUNT(*) FILTER (WHERE h.retention_status = 'retained') / COUNT(*), 1)
         ELSE 0 END::numeric
  FROM public.engineer_customer_handoffs_r2378 h
  LEFT JOIN public.profiles p ON p.id = h.outgoing_engineer_id
  WHERE h.handoff_status = 'completed'
  GROUP BY p.email
  HAVING COUNT(*) >= 1
  ORDER BY AVG(h.smoothness_score) DESC NULLS LAST, COUNT(*) DESC
  LIMIT 25;
END;
$$;

-- =====================================================================
-- GRANTS
-- =====================================================================
GRANT EXECUTE ON FUNCTION public.r2378_handoff_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2378_recent_handoffs(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2378_smoothness_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2378_at_risk_handoffs() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2378_signal_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2378_retention_impact() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2378_top_handoff_performers() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r2378_handoff_overview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2378_recent_handoffs(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2378_smoothness_distribution() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2378_at_risk_handoffs() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2378_signal_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2378_retention_impact() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2378_top_handoff_performers() FROM PUBLIC, anon;

COMMIT;
