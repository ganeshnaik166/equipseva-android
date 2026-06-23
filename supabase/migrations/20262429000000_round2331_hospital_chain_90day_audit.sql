BEGIN;

-- =============================================================================
-- r2331 — Hospital chain post-onboarding 90-day audit
-- At day 90 after AMC start, audit chain satisfaction, issues found, course
-- correction. Founder-only console.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_chain_90day_audits_r2331 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  chain_name text NOT NULL,
  amc_start_date date NOT NULL,
  audit_due_date date NOT NULL,
  audit_status text NOT NULL DEFAULT 'pending'
    CHECK (audit_status IN ('pending','in_progress','completed','overdue','cancelled')),
  csat_score numeric(3,1) CHECK (csat_score IS NULL OR (csat_score >= 0 AND csat_score <= 10)),
  nps_score integer CHECK (nps_score IS NULL OR (nps_score >= -100 AND nps_score <= 100)),
  uptime_actual_pct numeric(5,2) CHECK (uptime_actual_pct IS NULL OR (uptime_actual_pct >= 0 AND uptime_actual_pct <= 100)),
  uptime_promised_pct numeric(5,2) CHECK (uptime_promised_pct IS NULL OR (uptime_promised_pct >= 0 AND uptime_promised_pct <= 100)),
  response_sla_hit_pct numeric(5,2) CHECK (response_sla_hit_pct IS NULL OR (response_sla_hit_pct >= 0 AND response_sla_hit_pct <= 100)),
  total_repairs integer NOT NULL DEFAULT 0,
  total_complaints integer NOT NULL DEFAULT 0,
  health_band text NOT NULL DEFAULT 'unknown'
    CHECK (health_band IN ('green','amber','red','unknown')),
  renewal_intent text NOT NULL DEFAULT 'unknown'
    CHECK (renewal_intent IN ('strong','likely','at_risk','will_churn','unknown')),
  founder_call_done boolean NOT NULL DEFAULT false,
  founder_call_at timestamptz,
  founder_notes text,
  audit_completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcaud_r2331_status ON public.hospital_chain_90day_audits_r2331(audit_status);
CREATE INDEX IF NOT EXISTS idx_hcaud_r2331_due ON public.hospital_chain_90day_audits_r2331(audit_due_date);
CREATE INDEX IF NOT EXISTS idx_hcaud_r2331_chain ON public.hospital_chain_90day_audits_r2331(chain_user_id);

CREATE TABLE IF NOT EXISTS public.hospital_chain_audit_issues_r2331 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.hospital_chain_90day_audits_r2331(id) ON DELETE CASCADE,
  issue_category text NOT NULL
    CHECK (issue_category IN ('uptime','response_time','engineer_quality','parts_delay','billing','communication','training','other')),
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  issue_description text NOT NULL,
  corrective_action text,
  assigned_to_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  due_date date,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','resolved','wont_fix')),
  resolved_at timestamptz,
  resolution_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcissue_r2331_audit ON public.hospital_chain_audit_issues_r2331(audit_id);
CREATE INDEX IF NOT EXISTS idx_hcissue_r2331_status ON public.hospital_chain_audit_issues_r2331(status);
CREATE INDEX IF NOT EXISTS idx_hcissue_r2331_severity ON public.hospital_chain_audit_issues_r2331(severity);

ALTER TABLE public.hospital_chain_90day_audits_r2331 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_audit_issues_r2331 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hcaud_r2331 ON public.hospital_chain_90day_audits_r2331;
CREATE POLICY founder_all_hcaud_r2331 ON public.hospital_chain_90day_audits_r2331
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hcissue_r2331 ON public.hospital_chain_audit_issues_r2331;
CREATE POLICY founder_all_hcissue_r2331 ON public.hospital_chain_audit_issues_r2331
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =============================================================================
-- RPCs
-- =============================================================================

DROP FUNCTION IF EXISTS public.list_chain_90day_audits_r2331();
CREATE OR REPLACE FUNCTION public.list_chain_90day_audits_r2331()
RETURNS TABLE (
  id uuid,
  chain_user_id uuid,
  chain_name text,
  chain_email text,
  amc_start_date date,
  audit_due_date date,
  audit_status text,
  csat_score numeric,
  nps_score integer,
  uptime_actual_pct numeric,
  uptime_promised_pct numeric,
  response_sla_hit_pct numeric,
  total_repairs integer,
  total_complaints integer,
  health_band text,
  renewal_intent text,
  founder_call_done boolean,
  founder_call_at timestamptz,
  audit_completed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_user_id, a.chain_name, p.email::text,
         a.amc_start_date, a.audit_due_date, a.audit_status,
         a.csat_score, a.nps_score, a.uptime_actual_pct, a.uptime_promised_pct,
         a.response_sla_hit_pct, a.total_repairs, a.total_complaints,
         a.health_band, a.renewal_intent, a.founder_call_done, a.founder_call_at,
         a.audit_completed_at, a.created_at
  FROM public.hospital_chain_90day_audits_r2331 a
  LEFT JOIN public.profiles p ON p.id = a.chain_user_id
  ORDER BY a.audit_due_date ASC, a.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.audit_status_summary_r2331();
CREATE OR REPLACE FUNCTION public.audit_status_summary_r2331()
RETURNS TABLE (
  audit_status text,
  audit_count bigint,
  avg_csat numeric,
  avg_nps numeric,
  avg_uptime_gap numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.audit_status,
         COUNT(*)::bigint,
         ROUND(AVG(a.csat_score)::numeric, 2),
         ROUND(AVG(a.nps_score)::numeric, 1),
         ROUND(AVG(a.uptime_promised_pct - a.uptime_actual_pct)::numeric, 2)
  FROM public.hospital_chain_90day_audits_r2331 a
  GROUP BY a.audit_status
  ORDER BY COUNT(*) DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.audit_health_band_summary_r2331();
CREATE OR REPLACE FUNCTION public.audit_health_band_summary_r2331()
RETURNS TABLE (
  health_band text,
  chain_count bigint,
  avg_csat numeric,
  avg_total_complaints numeric,
  at_risk_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.health_band,
         COUNT(*)::bigint,
         ROUND(AVG(a.csat_score)::numeric, 2),
         ROUND(AVG(a.total_complaints)::numeric, 1),
         COUNT(*) FILTER (WHERE a.renewal_intent IN ('at_risk','will_churn'))::bigint
  FROM public.hospital_chain_90day_audits_r2331 a
  GROUP BY a.health_band
  ORDER BY CASE a.health_band WHEN 'red' THEN 1 WHEN 'amber' THEN 2 WHEN 'green' THEN 3 ELSE 4 END;
END;
$$;

DROP FUNCTION IF EXISTS public.overdue_audits_r2331();
CREATE OR REPLACE FUNCTION public.overdue_audits_r2331()
RETURNS TABLE (
  id uuid,
  chain_name text,
  audit_due_date date,
  days_overdue integer,
  amc_start_date date,
  audit_status text,
  founder_call_done boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.audit_due_date,
         GREATEST((CURRENT_DATE - a.audit_due_date)::integer, 0),
         a.amc_start_date, a.audit_status, a.founder_call_done
  FROM public.hospital_chain_90day_audits_r2331 a
  WHERE a.audit_status IN ('pending','in_progress','overdue')
    AND a.audit_due_date < CURRENT_DATE
  ORDER BY a.audit_due_date ASC;
END;
$$;

DROP FUNCTION IF EXISTS public.top_issue_categories_r2331();
CREATE OR REPLACE FUNCTION public.top_issue_categories_r2331()
RETURNS TABLE (
  issue_category text,
  issue_count bigint,
  open_count bigint,
  resolved_count bigint,
  critical_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.issue_category,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE i.status IN ('open','in_progress'))::bigint,
         COUNT(*) FILTER (WHERE i.status = 'resolved')::bigint,
         COUNT(*) FILTER (WHERE i.severity = 'critical')::bigint
  FROM public.hospital_chain_audit_issues_r2331 i
  GROUP BY i.issue_category
  ORDER BY COUNT(*) DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.open_critical_issues_r2331();
CREATE OR REPLACE FUNCTION public.open_critical_issues_r2331()
RETURNS TABLE (
  id uuid,
  audit_id uuid,
  chain_name text,
  issue_category text,
  severity text,
  issue_description text,
  corrective_action text,
  due_date date,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.audit_id, a.chain_name, i.issue_category, i.severity,
         i.issue_description, i.corrective_action, i.due_date, i.status, i.created_at
  FROM public.hospital_chain_audit_issues_r2331 i
  JOIN public.hospital_chain_90day_audits_r2331 a ON a.id = i.audit_id
  WHERE i.status IN ('open','in_progress')
    AND i.severity IN ('high','critical')
  ORDER BY
    CASE i.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
    i.due_date NULLS LAST, i.created_at;
END;
$$;

DROP FUNCTION IF EXISTS public.renewal_intent_breakdown_r2331();
CREATE OR REPLACE FUNCTION public.renewal_intent_breakdown_r2331()
RETURNS TABLE (
  renewal_intent text,
  chain_count bigint,
  avg_csat numeric,
  avg_complaints numeric,
  founder_calls_done bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.renewal_intent,
         COUNT(*)::bigint,
         ROUND(AVG(a.csat_score)::numeric, 2),
         ROUND(AVG(a.total_complaints)::numeric, 1),
         COUNT(*) FILTER (WHERE a.founder_call_done)::bigint
  FROM public.hospital_chain_90day_audits_r2331 a
  GROUP BY a.renewal_intent
  ORDER BY
    CASE a.renewal_intent
      WHEN 'will_churn' THEN 1
      WHEN 'at_risk' THEN 2
      WHEN 'likely' THEN 3
      WHEN 'strong' THEN 4
      ELSE 5
    END;
END;
$$;

-- GRANTs / REVOKEs
GRANT EXECUTE ON FUNCTION public.list_chain_90day_audits_r2331() TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_status_summary_r2331() TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_health_band_summary_r2331() TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_audits_r2331() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_issue_categories_r2331() TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_critical_issues_r2331() TO authenticated;
GRANT EXECUTE ON FUNCTION public.renewal_intent_breakdown_r2331() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_chain_90day_audits_r2331() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.audit_status_summary_r2331() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.audit_health_band_summary_r2331() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_audits_r2331() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_issue_categories_r2331() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.open_critical_issues_r2331() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.renewal_intent_breakdown_r2331() FROM PUBLIC, anon;

COMMIT;
