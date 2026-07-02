BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_revenue_streams_r2292 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  stream_name text NOT NULL,
  stream_classification text NOT NULL CHECK (stream_classification IN ('subscription','transaction','one_time','usage_based','milestone')),
  recognition_policy text NOT NULL CHECK (recognition_policy IN ('ratable_over_term','point_in_time_delivery','percent_of_completion','milestone_based','usage_period')),
  policy_basis text NOT NULL,
  gross_amount_paise bigint NOT NULL DEFAULT 0,
  recognized_to_date_paise bigint NOT NULL DEFAULT 0,
  deferred_balance_paise bigint NOT NULL DEFAULT 0,
  recognition_start_date date,
  recognition_end_date date,
  term_months int,
  invoice_reference text,
  source_table text,
  source_id uuid,
  is_policy_compliant boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crs_r2292_customer ON public.customer_revenue_streams_r2292(customer_user_id);
CREATE INDEX IF NOT EXISTS idx_crs_r2292_classification ON public.customer_revenue_streams_r2292(stream_classification);
CREATE INDEX IF NOT EXISTS idx_crs_r2292_compliant ON public.customer_revenue_streams_r2292(is_policy_compliant);

ALTER TABLE public.customer_revenue_streams_r2292 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_crs_r2292 ON public.customer_revenue_streams_r2292;
CREATE POLICY founder_all_crs_r2292 ON public.customer_revenue_streams_r2292
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_policy_audit_findings_r2292 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id uuid NOT NULL REFERENCES public.customer_revenue_streams_r2292(id) ON DELETE CASCADE,
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  finding_type text NOT NULL CHECK (finding_type IN ('premature_recognition','deferred_misclassification','policy_mismatch','missing_basis','term_mismatch','unrecorded_deferral')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  description text NOT NULL,
  recommended_action text,
  variance_paise bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','investigating','resolved','accepted_risk','dismissed')),
  resolved_by_email text,
  resolved_at timestamptz,
  resolution_notes text,
  detected_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cpaf_r2292_stream ON public.customer_policy_audit_findings_r2292(stream_id);
CREATE INDEX IF NOT EXISTS idx_cpaf_r2292_customer ON public.customer_policy_audit_findings_r2292(customer_user_id);
CREATE INDEX IF NOT EXISTS idx_cpaf_r2292_status ON public.customer_policy_audit_findings_r2292(status);
CREATE INDEX IF NOT EXISTS idx_cpaf_r2292_severity ON public.customer_policy_audit_findings_r2292(severity);

ALTER TABLE public.customer_policy_audit_findings_r2292 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cpaf_r2292 ON public.customer_policy_audit_findings_r2292;
CREATE POLICY founder_all_cpaf_r2292 ON public.customer_policy_audit_findings_r2292
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.founder_r2292_list_revenue_streams();
CREATE FUNCTION public.founder_r2292_list_revenue_streams()
RETURNS TABLE (
  id uuid,
  customer_user_id uuid,
  customer_email text,
  stream_name text,
  stream_classification text,
  recognition_policy text,
  policy_basis text,
  gross_amount_paise bigint,
  recognized_to_date_paise bigint,
  deferred_balance_paise bigint,
  recognition_start_date date,
  recognition_end_date date,
  term_months int,
  invoice_reference text,
  is_policy_compliant boolean,
  notes text,
  created_at timestamptz
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
    s.id,
    s.customer_user_id,
    p.email,
    s.stream_name,
    s.stream_classification,
    s.recognition_policy,
    s.policy_basis,
    s.gross_amount_paise,
    s.recognized_to_date_paise,
    s.deferred_balance_paise,
    s.recognition_start_date,
    s.recognition_end_date,
    s.term_months,
    s.invoice_reference,
    s.is_policy_compliant,
    s.notes,
    s.created_at
  FROM public.customer_revenue_streams_r2292 s
  LEFT JOIN public.profiles p ON p.id = s.customer_user_id
  ORDER BY s.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2292_list_revenue_streams() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2292_list_revenue_streams() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_r2292_list_findings();
CREATE FUNCTION public.founder_r2292_list_findings()
RETURNS TABLE (
  id uuid,
  stream_id uuid,
  stream_name text,
  customer_user_id uuid,
  customer_email text,
  finding_type text,
  severity text,
  description text,
  recommended_action text,
  variance_paise bigint,
  status text,
  resolved_by_email text,
  resolved_at timestamptz,
  resolution_notes text,
  detected_at timestamptz
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
    f.id,
    f.stream_id,
    s.stream_name,
    f.customer_user_id,
    p.email,
    f.finding_type,
    f.severity,
    f.description,
    f.recommended_action,
    f.variance_paise,
    f.status,
    f.resolved_by_email,
    f.resolved_at,
    f.resolution_notes,
    f.detected_at
  FROM public.customer_policy_audit_findings_r2292 f
  LEFT JOIN public.customer_revenue_streams_r2292 s ON s.id = f.stream_id
  LEFT JOIN public.profiles p ON p.id = f.customer_user_id
  ORDER BY
    CASE f.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    f.detected_at DESC
  LIMIT 500;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2292_list_findings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2292_list_findings() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_r2292_by_classification();
CREATE FUNCTION public.founder_r2292_by_classification()
RETURNS TABLE (
  stream_classification text,
  stream_count int,
  total_gross_paise bigint,
  total_recognized_paise bigint,
  total_deferred_paise bigint,
  compliant_count int,
  non_compliant_count int
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
    s.stream_classification,
    (COUNT(*))::int,
    COALESCE(SUM(s.gross_amount_paise), 0)::bigint,
    COALESCE(SUM(s.recognized_to_date_paise), 0)::bigint,
    COALESCE(SUM(s.deferred_balance_paise), 0)::bigint,
    (COUNT(*) FILTER (WHERE s.is_policy_compliant))::int,
    (COUNT(*) FILTER (WHERE NOT s.is_policy_compliant))::int
  FROM public.customer_revenue_streams_r2292 s
  GROUP BY s.stream_classification
  ORDER BY total_gross_paise DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2292_by_classification() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2292_by_classification() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_r2292_by_policy();
CREATE FUNCTION public.founder_r2292_by_policy()
RETURNS TABLE (
  recognition_policy text,
  stream_count int,
  total_gross_paise bigint,
  total_recognized_paise bigint,
  total_deferred_paise bigint,
  pct_recognized numeric
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
    s.recognition_policy,
    (COUNT(*))::int,
    COALESCE(SUM(s.gross_amount_paise), 0)::bigint,
    COALESCE(SUM(s.recognized_to_date_paise), 0)::bigint,
    COALESCE(SUM(s.deferred_balance_paise), 0)::bigint,
    CASE WHEN COALESCE(SUM(s.gross_amount_paise), 0) = 0
      THEN 0
      ELSE ROUND((COALESCE(SUM(s.recognized_to_date_paise), 0)::numeric / SUM(s.gross_amount_paise)::numeric) * 100, 2)
    END
  FROM public.customer_revenue_streams_r2292 s
  GROUP BY s.recognition_policy
  ORDER BY total_gross_paise DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2292_by_policy() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2292_by_policy() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_r2292_findings_by_severity();
CREATE FUNCTION public.founder_r2292_findings_by_severity()
RETURNS TABLE (
  severity text,
  finding_count int,
  open_count int,
  resolved_count int,
  total_variance_paise bigint
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
    f.severity,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE f.status = 'open'))::int,
    (COUNT(*) FILTER (WHERE f.status = 'resolved'))::int,
    COALESCE(SUM(f.variance_paise), 0)::bigint
  FROM public.customer_policy_audit_findings_r2292 f
  GROUP BY f.severity
  ORDER BY
    CASE f.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2292_findings_by_severity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2292_findings_by_severity() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_r2292_top_offenders();
CREATE FUNCTION public.founder_r2292_top_offenders()
RETURNS TABLE (
  customer_user_id uuid,
  customer_email text,
  total_streams int,
  non_compliant_streams int,
  open_findings int,
  total_variance_paise bigint
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
    s.customer_user_id,
    p.email,
    (COUNT(DISTINCT s.id))::int,
    (COUNT(DISTINCT s.id) FILTER (WHERE NOT s.is_policy_compliant))::int,
    (COUNT(DISTINCT f.id) FILTER (WHERE f.status = 'open'))::int,
    COALESCE(SUM(f.variance_paise), 0)::bigint
  FROM public.customer_revenue_streams_r2292 s
  LEFT JOIN public.profiles p ON p.id = s.customer_user_id
  LEFT JOIN public.customer_policy_audit_findings_r2292 f ON f.customer_user_id = s.customer_user_id
  GROUP BY s.customer_user_id, p.email
  HAVING (COUNT(DISTINCT s.id) FILTER (WHERE NOT s.is_policy_compliant))::int > 0
      OR (COUNT(DISTINCT f.id) FILTER (WHERE f.status = 'open'))::int > 0
  ORDER BY non_compliant_streams DESC, open_findings DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2292_top_offenders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2292_top_offenders() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_r2292_compliance_totals();
CREATE FUNCTION public.founder_r2292_compliance_totals()
RETURNS TABLE (
  total_streams int,
  compliant_streams int,
  non_compliant_streams int,
  total_gross_paise bigint,
  total_recognized_paise bigint,
  total_deferred_paise bigint,
  total_findings int,
  open_findings int,
  critical_findings int,
  total_variance_paise bigint,
  compliance_pct numeric
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
    (SELECT COUNT(*) FROM public.customer_revenue_streams_r2292)::int,
    (SELECT COUNT(*) FROM public.customer_revenue_streams_r2292 WHERE is_policy_compliant)::int,
    (SELECT COUNT(*) FROM public.customer_revenue_streams_r2292 WHERE NOT is_policy_compliant)::int,
    (SELECT COALESCE(SUM(gross_amount_paise), 0) FROM public.customer_revenue_streams_r2292)::bigint,
    (SELECT COALESCE(SUM(recognized_to_date_paise), 0) FROM public.customer_revenue_streams_r2292)::bigint,
    (SELECT COALESCE(SUM(deferred_balance_paise), 0) FROM public.customer_revenue_streams_r2292)::bigint,
    (SELECT COUNT(*) FROM public.customer_policy_audit_findings_r2292)::int,
    (SELECT COUNT(*) FROM public.customer_policy_audit_findings_r2292 WHERE status = 'open')::int,
    (SELECT COUNT(*) FROM public.customer_policy_audit_findings_r2292 WHERE severity = 'critical')::int,
    (SELECT COALESCE(SUM(variance_paise), 0) FROM public.customer_policy_audit_findings_r2292)::bigint,
    CASE
      WHEN (SELECT COUNT(*) FROM public.customer_revenue_streams_r2292) = 0 THEN 0
      ELSE ROUND(
        ((SELECT COUNT(*) FROM public.customer_revenue_streams_r2292 WHERE is_policy_compliant)::numeric /
         (SELECT COUNT(*) FROM public.customer_revenue_streams_r2292)::numeric) * 100,
        2
      )
    END;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2292_compliance_totals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2292_compliance_totals() TO authenticated;

COMMIT;
