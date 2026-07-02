BEGIN;

-- =====================================================================
-- r2316: Customer service-SLA adherence per equipment class
-- Tracks response time, breach %, and cause by equipment category
-- (CT / MRI / Ventilator / Ultrasound / etc.)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: SLA targets + measured response per service ticket
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.customer_service_sla_tickets_r2316 (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_code           text NOT NULL UNIQUE,
  equipment_category    text NOT NULL CHECK (equipment_category IN (
                          'ct_scanner','mri','ventilator','ultrasound',
                          'xray','ecg','dialysis','anesthesia',
                          'patient_monitor','infusion_pump','defibrillator',
                          'autoclave','endoscope','c_arm','other'
                        )),
  equipment_class       text NOT NULL CHECK (equipment_class IN ('class_a','class_b','class_c','class_d')),
  hospital_org_id       uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  reported_by_email     text NOT NULL,
  reported_at           timestamptz NOT NULL DEFAULT now(),
  first_response_at     timestamptz,
  resolved_at           timestamptz,
  target_response_min   integer NOT NULL CHECK (target_response_min > 0),
  target_resolve_min    integer NOT NULL CHECK (target_resolve_min > 0),
  actual_response_min   integer GENERATED ALWAYS AS (
                          CASE WHEN first_response_at IS NOT NULL
                          THEN GREATEST(0, (EXTRACT(EPOCH FROM (first_response_at - reported_at))/60)::int)
                          ELSE NULL END
                        ) STORED,
  actual_resolve_min    integer GENERATED ALWAYS AS (
                          CASE WHEN resolved_at IS NOT NULL
                          THEN GREATEST(0, (EXTRACT(EPOCH FROM (resolved_at - reported_at))/60)::int)
                          ELSE NULL END
                        ) STORED,
  sla_response_breached boolean NOT NULL DEFAULT false,
  sla_resolve_breached  boolean NOT NULL DEFAULT false,
  severity              text NOT NULL DEFAULT 'normal' CHECK (severity IN ('critical','high','normal','low')),
  status                text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','closed','cancelled')),
  created_by            uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cs_sla_tix_cat_r2316 ON public.customer_service_sla_tickets_r2316(equipment_category);
CREATE INDEX IF NOT EXISTS idx_cs_sla_tix_reported_r2316 ON public.customer_service_sla_tickets_r2316(reported_at DESC);
CREATE INDEX IF NOT EXISTS idx_cs_sla_tix_breach_r2316 ON public.customer_service_sla_tickets_r2316(sla_response_breached) WHERE sla_response_breached = true;

ALTER TABLE public.customer_service_sla_tickets_r2316 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cs_sla_tix_r2316 ON public.customer_service_sla_tickets_r2316;
CREATE POLICY founder_all_cs_sla_tix_r2316 ON public.customer_service_sla_tickets_r2316
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------
-- Table 2: Root cause log for breaches
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.customer_service_sla_breach_causes_r2316 (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id           uuid NOT NULL REFERENCES public.customer_service_sla_tickets_r2316(id) ON DELETE CASCADE,
  cause_category      text NOT NULL CHECK (cause_category IN (
                        'no_engineer_available','parts_unavailable','engineer_late',
                        'hospital_access_delay','triage_misroute','customer_unreachable',
                        'tool_kit_missing','training_gap','vendor_dependency','other'
                      )),
  minutes_over_target integer NOT NULL CHECK (minutes_over_target >= 0),
  cause_notes         text,
  preventive_action   text,
  action_owner_email  text,
  logged_by           uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  logged_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cs_sla_cause_ticket_r2316 ON public.customer_service_sla_breach_causes_r2316(ticket_id);
CREATE INDEX IF NOT EXISTS idx_cs_sla_cause_cat_r2316 ON public.customer_service_sla_breach_causes_r2316(cause_category);

ALTER TABLE public.customer_service_sla_breach_causes_r2316 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cs_sla_cause_r2316 ON public.customer_service_sla_breach_causes_r2316;
CREATE POLICY founder_all_cs_sla_cause_r2316 ON public.customer_service_sla_breach_causes_r2316
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- 7 RPCs (all is_founder gated)
-- =====================================================================

-- RPC 1: Overview KPIs
DROP FUNCTION IF EXISTS public.founder_cs_sla_overview_r2316();
CREATE FUNCTION public.founder_cs_sla_overview_r2316()
RETURNS TABLE (
  total_tickets bigint,
  resolved_tickets bigint,
  avg_response_min numeric,
  avg_resolve_min numeric,
  response_breach_count bigint,
  resolve_breach_count bigint,
  response_breach_pct numeric,
  open_unresolved bigint
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
    COUNT(*) FILTER (WHERE status IN ('resolved','closed'))::bigint,
    ROUND(AVG(actual_response_min)::numeric, 1),
    ROUND(AVG(actual_resolve_min)::numeric, 1),
    COUNT(*) FILTER (WHERE sla_response_breached)::bigint,
    COUNT(*) FILTER (WHERE sla_resolve_breached)::bigint,
    CASE WHEN COUNT(*) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE sla_response_breached)::numeric / COUNT(*)::numeric, 1)
      ELSE 0 END,
    COUNT(*) FILTER (WHERE status IN ('open','in_progress'))::bigint
  FROM public.customer_service_sla_tickets_r2316;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_cs_sla_overview_r2316() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cs_sla_overview_r2316() TO authenticated;

-- RPC 2: By equipment category — avg response, breach %
DROP FUNCTION IF EXISTS public.founder_cs_sla_by_category_r2316();
CREATE FUNCTION public.founder_cs_sla_by_category_r2316()
RETURNS TABLE (
  equipment_category text,
  ticket_count bigint,
  avg_response_min numeric,
  avg_resolve_min numeric,
  breach_count bigint,
  breach_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.equipment_category,
    COUNT(*)::bigint,
    ROUND(AVG(t.actual_response_min)::numeric, 1),
    ROUND(AVG(t.actual_resolve_min)::numeric, 1),
    COUNT(*) FILTER (WHERE t.sla_response_breached)::bigint,
    CASE WHEN COUNT(*) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE t.sla_response_breached)::numeric / COUNT(*)::numeric, 1)
      ELSE 0 END
  FROM public.customer_service_sla_tickets_r2316 t
  GROUP BY t.equipment_category
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_cs_sla_by_category_r2316() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cs_sla_by_category_r2316() TO authenticated;

-- RPC 3: By equipment class (A/B/C/D)
DROP FUNCTION IF EXISTS public.founder_cs_sla_by_class_r2316();
CREATE FUNCTION public.founder_cs_sla_by_class_r2316()
RETURNS TABLE (
  equipment_class text,
  ticket_count bigint,
  avg_response_min numeric,
  breach_count bigint,
  breach_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.equipment_class,
    COUNT(*)::bigint,
    ROUND(AVG(t.actual_response_min)::numeric, 1),
    COUNT(*) FILTER (WHERE t.sla_response_breached)::bigint,
    CASE WHEN COUNT(*) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE t.sla_response_breached)::numeric / COUNT(*)::numeric, 1)
      ELSE 0 END
  FROM public.customer_service_sla_tickets_r2316 t
  GROUP BY t.equipment_class
  ORDER BY t.equipment_class;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_cs_sla_by_class_r2316() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cs_sla_by_class_r2316() TO authenticated;

-- RPC 4: By severity
DROP FUNCTION IF EXISTS public.founder_cs_sla_by_severity_r2316();
CREATE FUNCTION public.founder_cs_sla_by_severity_r2316()
RETURNS TABLE (
  severity text,
  ticket_count bigint,
  avg_response_min numeric,
  breach_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.severity,
    COUNT(*)::bigint,
    ROUND(AVG(t.actual_response_min)::numeric, 1),
    COUNT(*) FILTER (WHERE t.sla_response_breached)::bigint
  FROM public.customer_service_sla_tickets_r2316 t
  GROUP BY t.severity
  ORDER BY CASE t.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_cs_sla_by_severity_r2316() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cs_sla_by_severity_r2316() TO authenticated;

-- RPC 5: Recent breaches (joined with cause)
DROP FUNCTION IF EXISTS public.founder_cs_sla_recent_breaches_r2316();
CREATE FUNCTION public.founder_cs_sla_recent_breaches_r2316()
RETURNS TABLE (
  ticket_code text,
  equipment_category text,
  equipment_class text,
  severity text,
  target_response_min integer,
  actual_response_min integer,
  minutes_over integer,
  cause_category text,
  cause_notes text,
  reported_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.ticket_code,
    t.equipment_category,
    t.equipment_class,
    t.severity,
    t.target_response_min,
    t.actual_response_min,
    GREATEST(0, COALESCE(t.actual_response_min,0) - t.target_response_min),
    c.cause_category,
    c.cause_notes,
    t.reported_at
  FROM public.customer_service_sla_tickets_r2316 t
  LEFT JOIN LATERAL (
    SELECT cc.cause_category, cc.cause_notes
    FROM public.customer_service_sla_breach_causes_r2316 cc
    WHERE cc.ticket_id = t.id
    ORDER BY cc.logged_at DESC
    LIMIT 1
  ) c ON true
  WHERE t.sla_response_breached
  ORDER BY t.reported_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_cs_sla_recent_breaches_r2316() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cs_sla_recent_breaches_r2316() TO authenticated;

-- RPC 6: Top breach causes (root cause Pareto)
DROP FUNCTION IF EXISTS public.founder_cs_sla_top_causes_r2316();
CREATE FUNCTION public.founder_cs_sla_top_causes_r2316()
RETURNS TABLE (
  cause_category text,
  breach_count bigint,
  total_minutes_over bigint,
  avg_minutes_over numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.cause_category,
    COUNT(*)::bigint,
    SUM(c.minutes_over_target)::bigint,
    ROUND(AVG(c.minutes_over_target)::numeric, 1)
  FROM public.customer_service_sla_breach_causes_r2316 c
  GROUP BY c.cause_category
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_cs_sla_top_causes_r2316() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cs_sla_top_causes_r2316() TO authenticated;

-- RPC 7: Category vs cause crosstab (which equipment classes suffer which causes)
DROP FUNCTION IF EXISTS public.founder_cs_sla_category_cause_crosstab_r2316();
CREATE FUNCTION public.founder_cs_sla_category_cause_crosstab_r2316()
RETURNS TABLE (
  equipment_category text,
  cause_category text,
  breach_count bigint,
  avg_minutes_over numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.equipment_category,
    c.cause_category,
    COUNT(*)::bigint,
    ROUND(AVG(c.minutes_over_target)::numeric, 1)
  FROM public.customer_service_sla_breach_causes_r2316 c
  JOIN public.customer_service_sla_tickets_r2316 t ON t.id = c.ticket_id
  GROUP BY t.equipment_category, c.cause_category
  ORDER BY t.equipment_category, COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_cs_sla_category_cause_crosstab_r2316() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cs_sla_category_cause_crosstab_r2316() TO authenticated;

COMMIT;
