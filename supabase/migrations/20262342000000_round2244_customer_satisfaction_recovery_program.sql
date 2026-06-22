BEGIN;

-- =====================================================================
-- Round 2244 — Customer Satisfaction Recovery Program
-- Track escalations/complaints, recovery actions, post-recovery
-- satisfaction outcomes, and overall recovery effectiveness.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.satisfaction_recovery_cases_r2244 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  customer_org text,
  complaint_category text NOT NULL CHECK (complaint_category IN (
    'service_delay','engineer_quality','billing_dispute','part_quality',
    'communication_gap','amc_grievance','escalation_ignored','other'
  )),
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  initial_csat_score numeric(3,1) CHECK (initial_csat_score BETWEEN 0 AND 5),
  raised_at timestamptz NOT NULL DEFAULT now(),
  channel text NOT NULL DEFAULT 'email' CHECK (channel IN ('email','phone','whatsapp','app','escalation_ticket','social')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_recovery','recovered','unresolved','churned')),
  recovery_owner_email text,
  closed_at timestamptz,
  final_csat_score numeric(3,1) CHECK (final_csat_score BETWEEN 0 AND 5),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_satrec_cases_r2244_status ON public.satisfaction_recovery_cases_r2244(status);
CREATE INDEX IF NOT EXISTS idx_satrec_cases_r2244_severity ON public.satisfaction_recovery_cases_r2244(severity);
CREATE INDEX IF NOT EXISTS idx_satrec_cases_r2244_raised ON public.satisfaction_recovery_cases_r2244(raised_at DESC);

ALTER TABLE public.satisfaction_recovery_cases_r2244 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.satisfaction_recovery_cases_r2244;
CREATE POLICY founder_all ON public.satisfaction_recovery_cases_r2244
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.satisfaction_recovery_actions_r2244 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES public.satisfaction_recovery_cases_r2244(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN (
    'apology_call','refund','credit_note','free_service','engineer_swap',
    'priority_escalation','founder_callback','goodwill_amc_extension','other'
  )),
  action_value_rupees integer DEFAULT 0 CHECK (action_value_rupees >= 0),
  performed_by_email text NOT NULL,
  performed_at timestamptz NOT NULL DEFAULT now(),
  customer_response text CHECK (customer_response IN ('accepted','partially_accepted','rejected','no_response')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_satrec_actions_r2244_case ON public.satisfaction_recovery_actions_r2244(case_id);
CREATE INDEX IF NOT EXISTS idx_satrec_actions_r2244_performed ON public.satisfaction_recovery_actions_r2244(performed_at DESC);

ALTER TABLE public.satisfaction_recovery_actions_r2244 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.satisfaction_recovery_actions_r2244;
CREATE POLICY founder_all ON public.satisfaction_recovery_actions_r2244
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------
-- RPC 1: program summary
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.satrec_program_summary_r2244()
RETURNS TABLE (
  total_cases int,
  open_cases int,
  in_recovery int,
  recovered int,
  unresolved int,
  churned int,
  recovery_rate_pct numeric,
  avg_initial_csat numeric,
  avg_final_csat numeric,
  total_goodwill_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_cases,
    (COUNT(*) FILTER (WHERE c.status = 'open'))::int AS open_cases,
    (COUNT(*) FILTER (WHERE c.status = 'in_recovery'))::int AS in_recovery,
    (COUNT(*) FILTER (WHERE c.status = 'recovered'))::int AS recovered,
    (COUNT(*) FILTER (WHERE c.status = 'unresolved'))::int AS unresolved,
    (COUNT(*) FILTER (WHERE c.status = 'churned'))::int AS churned,
    ROUND(
      (COUNT(*) FILTER (WHERE c.status = 'recovered'))::numeric
       / NULLIF(COUNT(*) FILTER (WHERE c.status IN ('recovered','unresolved','churned')), 0) * 100,
      1
    ) AS recovery_rate_pct,
    ROUND(AVG(c.initial_csat_score), 2) AS avg_initial_csat,
    ROUND(AVG(c.final_csat_score), 2) AS avg_final_csat,
    COALESCE((
      SELECT SUM(action_value_rupees)::bigint
      FROM public.satisfaction_recovery_actions_r2244
    ), 0) AS total_goodwill_rupees
  FROM public.satisfaction_recovery_cases_r2244 c;
END;
$$;

REVOKE ALL ON FUNCTION public.satrec_program_summary_r2244() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.satrec_program_summary_r2244() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 2: cases by status
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.satrec_cases_by_status_r2244()
RETURNS TABLE (
  status text,
  case_count int,
  avg_days_open numeric,
  avg_final_csat numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.status,
    (COUNT(*))::int AS case_count,
    ROUND(AVG(EXTRACT(EPOCH FROM (COALESCE(c.closed_at, now()) - c.raised_at)) / 86400.0)::numeric, 1) AS avg_days_open,
    ROUND(AVG(c.final_csat_score), 2) AS avg_final_csat
  FROM public.satisfaction_recovery_cases_r2244 c
  GROUP BY c.status
  ORDER BY case_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.satrec_cases_by_status_r2244() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.satrec_cases_by_status_r2244() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 3: category breakdown
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.satrec_category_breakdown_r2244()
RETURNS TABLE (
  complaint_category text,
  case_count int,
  recovered_count int,
  recovery_rate_pct numeric,
  avg_csat_lift numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.complaint_category,
    (COUNT(*))::int AS case_count,
    (COUNT(*) FILTER (WHERE c.status = 'recovered'))::int AS recovered_count,
    ROUND(
      (COUNT(*) FILTER (WHERE c.status = 'recovered'))::numeric
       / NULLIF(COUNT(*), 0) * 100,
      1
    ) AS recovery_rate_pct,
    ROUND(AVG(c.final_csat_score - c.initial_csat_score), 2) AS avg_csat_lift
  FROM public.satisfaction_recovery_cases_r2244 c
  GROUP BY c.complaint_category
  ORDER BY case_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.satrec_category_breakdown_r2244() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.satrec_category_breakdown_r2244() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 4: severity breakdown
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.satrec_severity_breakdown_r2244()
RETURNS TABLE (
  severity text,
  case_count int,
  recovered_count int,
  churned_count int,
  recovery_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.severity,
    (COUNT(*))::int AS case_count,
    (COUNT(*) FILTER (WHERE c.status = 'recovered'))::int AS recovered_count,
    (COUNT(*) FILTER (WHERE c.status = 'churned'))::int AS churned_count,
    ROUND(
      (COUNT(*) FILTER (WHERE c.status = 'recovered'))::numeric
       / NULLIF(COUNT(*), 0) * 100,
      1
    ) AS recovery_rate_pct
  FROM public.satisfaction_recovery_cases_r2244 c
  GROUP BY c.severity
  ORDER BY
    CASE c.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END;
END;
$$;

REVOKE ALL ON FUNCTION public.satrec_severity_breakdown_r2244() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.satrec_severity_breakdown_r2244() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 5: action effectiveness
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.satrec_action_effectiveness_r2244()
RETURNS TABLE (
  action_type text,
  uses int,
  accepted int,
  rejected int,
  total_spend_rupees bigint,
  acceptance_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.action_type,
    (COUNT(*))::int AS uses,
    (COUNT(*) FILTER (WHERE a.customer_response = 'accepted'))::int AS accepted,
    (COUNT(*) FILTER (WHERE a.customer_response = 'rejected'))::int AS rejected,
    COALESCE(SUM(a.action_value_rupees), 0)::bigint AS total_spend_rupees,
    ROUND(
      (COUNT(*) FILTER (WHERE a.customer_response = 'accepted'))::numeric
       / NULLIF(COUNT(*), 0) * 100,
      1
    ) AS acceptance_rate_pct
  FROM public.satisfaction_recovery_actions_r2244 a
  GROUP BY a.action_type
  ORDER BY uses DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.satrec_action_effectiveness_r2244() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.satrec_action_effectiveness_r2244() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 6: open queue (most urgent first)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.satrec_open_queue_r2244()
RETURNS TABLE (
  case_id uuid,
  customer_name text,
  customer_org text,
  complaint_category text,
  severity text,
  status text,
  initial_csat_score numeric,
  raised_at timestamptz,
  days_open numeric,
  recovery_owner_email text,
  action_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id AS case_id,
    c.customer_name,
    c.customer_org,
    c.complaint_category,
    c.severity,
    c.status,
    c.initial_csat_score,
    c.raised_at,
    ROUND(EXTRACT(EPOCH FROM (now() - c.raised_at)) / 86400.0, 1) AS days_open,
    c.recovery_owner_email,
    (SELECT COUNT(*) FROM public.satisfaction_recovery_actions_r2244 a WHERE a.case_id = c.id)::int AS action_count
  FROM public.satisfaction_recovery_cases_r2244 c
  WHERE c.status IN ('open','in_recovery')
  ORDER BY
    CASE c.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END,
    c.raised_at ASC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.satrec_open_queue_r2244() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.satrec_open_queue_r2244() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 7: weekly trend (last 12 weeks)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.satrec_weekly_trend_r2244()
RETURNS TABLE (
  week_start date,
  cases_raised int,
  cases_recovered int,
  cases_churned int,
  recovery_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (date_trunc('week', c.raised_at))::date AS week_start,
    (COUNT(*))::int AS cases_raised,
    (COUNT(*) FILTER (WHERE c.status = 'recovered'))::int AS cases_recovered,
    (COUNT(*) FILTER (WHERE c.status = 'churned'))::int AS cases_churned,
    ROUND(
      (COUNT(*) FILTER (WHERE c.status = 'recovered'))::numeric
       / NULLIF(COUNT(*), 0) * 100,
      1
    ) AS recovery_rate_pct
  FROM public.satisfaction_recovery_cases_r2244 c
  WHERE c.raised_at >= now() - interval '12 weeks'
  GROUP BY week_start
  ORDER BY week_start DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.satrec_weekly_trend_r2244() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.satrec_weekly_trend_r2244() TO authenticated;

COMMIT;
