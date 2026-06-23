BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_procurement_bypass_events_r2319 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL,
  chain_name text NOT NULL,
  hospital_org_id uuid,
  hospital_name text,
  initiated_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  initiated_by_email text,
  bypass_type text NOT NULL CHECK (bypass_type IN ('urgency_override','direct_purchase','off_panel_vendor','below_threshold_split','emergency_repair','executive_override')),
  bypassed_step text NOT NULL,
  declared_reason text,
  order_value_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (order_value_rupees >= 0),
  procurement_policy_threshold_rupees numeric(14,2),
  risk_score integer NOT NULL DEFAULT 0 CHECK (risk_score BETWEEN 0 AND 100),
  risk_flag text NOT NULL DEFAULT 'low' CHECK (risk_flag IN ('low','medium','high','critical')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  detected_at timestamptz NOT NULL DEFAULT now(),
  reviewed boolean NOT NULL DEFAULT false,
  reviewed_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  reviewer_disposition text CHECK (reviewer_disposition IN ('legitimate','minor_violation','policy_breach','fraud_suspected','escalated')),
  reviewer_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hcpbe_r2319_chain_idx ON public.hospital_chain_procurement_bypass_events_r2319(chain_id);
CREATE INDEX IF NOT EXISTS hcpbe_r2319_risk_idx ON public.hospital_chain_procurement_bypass_events_r2319(risk_flag, occurred_at DESC);
CREATE INDEX IF NOT EXISTS hcpbe_r2319_reviewed_idx ON public.hospital_chain_procurement_bypass_events_r2319(reviewed, occurred_at DESC);

ALTER TABLE public.hospital_chain_procurement_bypass_events_r2319 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcpbe_r2319_founder_all ON public.hospital_chain_procurement_bypass_events_r2319;
CREATE POLICY hcpbe_r2319_founder_all ON public.hospital_chain_procurement_bypass_events_r2319
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_chain_procurement_bypass_audit_log_r2319 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.hospital_chain_procurement_bypass_events_r2319(id) ON DELETE CASCADE,
  actor_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_email text,
  action text NOT NULL CHECK (action IN ('detected','reviewed','escalated','dismissed','reclassified','note_added')),
  prior_risk_flag text,
  new_risk_flag text,
  note text,
  acted_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hcpbal_r2319_event_idx ON public.hospital_chain_procurement_bypass_audit_log_r2319(event_id, acted_at DESC);

ALTER TABLE public.hospital_chain_procurement_bypass_audit_log_r2319 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcpbal_r2319_founder_all ON public.hospital_chain_procurement_bypass_audit_log_r2319;
CREATE POLICY hcpbal_r2319_founder_all ON public.hospital_chain_procurement_bypass_audit_log_r2319
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.list_bypass_events_r2319();
CREATE FUNCTION public.list_bypass_events_r2319()
RETURNS TABLE (
  id uuid,
  chain_id uuid,
  chain_name text,
  hospital_name text,
  bypass_type text,
  bypassed_step text,
  declared_reason text,
  order_value_rupees numeric,
  risk_score integer,
  risk_flag text,
  occurred_at timestamptz,
  reviewed boolean,
  reviewer_disposition text,
  initiated_by_email text,
  audit_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.chain_id, e.chain_name, e.hospital_name, e.bypass_type, e.bypassed_step,
         e.declared_reason, e.order_value_rupees, e.risk_score, e.risk_flag,
         e.occurred_at, e.reviewed, e.reviewer_disposition, e.initiated_by_email,
         (SELECT count(*) FROM public.hospital_chain_procurement_bypass_audit_log_r2319 al WHERE al.event_id = e.id)
  FROM public.hospital_chain_procurement_bypass_events_r2319 e
  ORDER BY e.occurred_at DESC
  LIMIT 500;
END;
$$;

REVOKE ALL ON FUNCTION public.list_bypass_events_r2319() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bypass_events_r2319() TO authenticated;

DROP FUNCTION IF EXISTS public.chain_bypass_summary_r2319();
CREATE FUNCTION public.chain_bypass_summary_r2319()
RETURNS TABLE (
  chain_id uuid,
  chain_name text,
  total_events bigint,
  critical_events bigint,
  high_events bigint,
  unreviewed_events bigint,
  total_bypassed_value_rupees numeric,
  avg_risk_score numeric,
  last_event_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.chain_id, max(e.chain_name),
         count(*),
         count(*) FILTER (WHERE e.risk_flag = 'critical'),
         count(*) FILTER (WHERE e.risk_flag = 'high'),
         count(*) FILTER (WHERE NOT e.reviewed),
         coalesce(sum(e.order_value_rupees), 0),
         round(avg(e.risk_score)::numeric, 1),
         max(e.occurred_at)
  FROM public.hospital_chain_procurement_bypass_events_r2319 e
  GROUP BY e.chain_id
  ORDER BY count(*) FILTER (WHERE e.risk_flag IN ('high','critical')) DESC, sum(e.order_value_rupees) DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.chain_bypass_summary_r2319() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_bypass_summary_r2319() TO authenticated;

DROP FUNCTION IF EXISTS public.unreviewed_high_risk_bypasses_r2319();
CREATE FUNCTION public.unreviewed_high_risk_bypasses_r2319()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_name text,
  bypass_type text,
  order_value_rupees numeric,
  risk_score integer,
  risk_flag text,
  occurred_at timestamptz,
  initiated_by_email text,
  declared_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.chain_name, e.hospital_name, e.bypass_type,
         e.order_value_rupees, e.risk_score, e.risk_flag,
         e.occurred_at, e.initiated_by_email, e.declared_reason
  FROM public.hospital_chain_procurement_bypass_events_r2319 e
  WHERE NOT e.reviewed AND e.risk_flag IN ('high','critical')
  ORDER BY e.risk_score DESC, e.occurred_at DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.unreviewed_high_risk_bypasses_r2319() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unreviewed_high_risk_bypasses_r2319() TO authenticated;

DROP FUNCTION IF EXISTS public.bypass_type_distribution_r2319();
CREATE FUNCTION public.bypass_type_distribution_r2319()
RETURNS TABLE (
  bypass_type text,
  event_count bigint,
  total_value_rupees numeric,
  avg_risk_score numeric,
  critical_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.bypass_type,
         count(*),
         coalesce(sum(e.order_value_rupees), 0),
         round(avg(e.risk_score)::numeric, 1),
         count(*) FILTER (WHERE e.risk_flag = 'critical')
  FROM public.hospital_chain_procurement_bypass_events_r2319 e
  GROUP BY e.bypass_type
  ORDER BY count(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.bypass_type_distribution_r2319() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bypass_type_distribution_r2319() TO authenticated;

DROP FUNCTION IF EXISTS public.recent_bypass_audit_log_r2319();
CREATE FUNCTION public.recent_bypass_audit_log_r2319()
RETURNS TABLE (
  id uuid,
  event_id uuid,
  chain_name text,
  actor_email text,
  action text,
  prior_risk_flag text,
  new_risk_flag text,
  note text,
  acted_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT al.id, al.event_id, e.chain_name, al.actor_email, al.action,
         al.prior_risk_flag, al.new_risk_flag, al.note, al.acted_at
  FROM public.hospital_chain_procurement_bypass_audit_log_r2319 al
  JOIN public.hospital_chain_procurement_bypass_events_r2319 e ON e.id = al.event_id
  ORDER BY al.acted_at DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.recent_bypass_audit_log_r2319() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_bypass_audit_log_r2319() TO authenticated;

DROP FUNCTION IF EXISTS public.bypass_kpi_r2319();
CREATE FUNCTION public.bypass_kpi_r2319()
RETURNS TABLE (
  total_events bigint,
  unreviewed_events bigint,
  critical_events bigint,
  high_events bigint,
  total_bypassed_value_rupees numeric,
  unique_chains bigint,
  last_30d_events bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*),
         count(*) FILTER (WHERE NOT reviewed),
         count(*) FILTER (WHERE risk_flag = 'critical'),
         count(*) FILTER (WHERE risk_flag = 'high'),
         coalesce(sum(order_value_rupees), 0),
         count(DISTINCT chain_id),
         count(*) FILTER (WHERE occurred_at >= now() - interval '30 days')
  FROM public.hospital_chain_procurement_bypass_events_r2319;
END;
$$;

REVOKE ALL ON FUNCTION public.bypass_kpi_r2319() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bypass_kpi_r2319() TO authenticated;

DROP FUNCTION IF EXISTS public.bypass_reviewer_disposition_breakdown_r2319();
CREATE FUNCTION public.bypass_reviewer_disposition_breakdown_r2319()
RETURNS TABLE (
  reviewer_disposition text,
  event_count bigint,
  total_value_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT coalesce(e.reviewer_disposition, 'unreviewed'),
         count(*),
         coalesce(sum(e.order_value_rupees), 0)
  FROM public.hospital_chain_procurement_bypass_events_r2319 e
  GROUP BY coalesce(e.reviewer_disposition, 'unreviewed')
  ORDER BY count(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.bypass_reviewer_disposition_breakdown_r2319() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bypass_reviewer_disposition_breakdown_r2319() TO authenticated;

COMMIT;
