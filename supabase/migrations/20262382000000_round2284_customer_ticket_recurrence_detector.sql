BEGIN;

-- Round 2284: Customer service-ticket recurrence detector
-- Same hospital filing same issue repeatedly → product/process problem, root-cause log

CREATE TABLE IF NOT EXISTS public.ticket_recurrence_clusters_r2284 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  issue_signature text NOT NULL,
  issue_category text NOT NULL CHECK (issue_category IN (
    'equipment_failure','parts_quality','engineer_skill','process_gap',
    'sla_breach','documentation','training_gap','vendor_issue'
  )),
  ticket_count int NOT NULL DEFAULT 1,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  window_days int NOT NULL DEFAULT 30,
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  pattern_type text NOT NULL CHECK (pattern_type IN (
    'same_equipment','same_engineer','same_part','same_workflow','escalation_loop'
  )),
  cluster_status text NOT NULL DEFAULT 'open' CHECK (cluster_status IN ('open','investigating','rca_logged','resolved','monitoring')),
  detected_at timestamptz NOT NULL DEFAULT now(),
  notes text
);

CREATE TABLE IF NOT EXISTS public.ticket_recurrence_rca_log_r2284 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cluster_id uuid REFERENCES public.ticket_recurrence_clusters_r2284(id) ON DELETE CASCADE,
  root_cause text NOT NULL,
  root_cause_category text NOT NULL CHECK (root_cause_category IN (
    'product_defect','process_failure','training_gap','vendor_quality','documentation_gap','customer_misuse','systemic'
  )),
  corrective_action text NOT NULL,
  preventive_action text,
  owner_user_id uuid REFERENCES public.profiles(id),
  owner_email text,
  target_close_date date,
  actual_close_date date,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','closed','verified')),
  effectiveness_score int CHECK (effectiveness_score BETWEEN 1 AND 10),
  logged_by_email text NOT NULL,
  logged_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);

ALTER TABLE public.ticket_recurrence_clusters_r2284 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_recurrence_rca_log_r2284 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.ticket_recurrence_clusters_r2284;
CREATE POLICY founder_all ON public.ticket_recurrence_clusters_r2284
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.ticket_recurrence_rca_log_r2284;
CREATE POLICY founder_all ON public.ticket_recurrence_rca_log_r2284
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed clusters using existing organizations (no profile insert)
INSERT INTO public.ticket_recurrence_clusters_r2284
  (hospital_org_id, hospital_name, issue_signature, issue_category, ticket_count, first_seen_at, last_seen_at, window_days, severity, pattern_type, cluster_status, notes)
SELECT
  o.id,
  COALESCE(o.name, 'Hospital ' || substr(o.id::text, 1, 6)),
  sig.signature,
  sig.category,
  sig.cnt,
  now() - (sig.first_offset || ' days')::interval,
  now() - (sig.last_offset || ' hours')::interval,
  30,
  sig.sev,
  sig.pat,
  sig.stat,
  sig.note
FROM (
  SELECT id, name FROM public.organizations ORDER BY created_at DESC LIMIT 6
) o
CROSS JOIN LATERAL (
  VALUES
    ('Ventilator pressure sensor recalibration', 'equipment_failure', 7, 28, 6, 'high', 'same_equipment', 'investigating', 'Same model recalibration 7x in 30 days — sensor drift suspected'),
    ('AMC service slip not generated', 'process_gap', 5, 22, 12, 'medium', 'same_workflow', 'rca_logged', 'Front-desk skipping slip generation step'),
    ('X-ray tube replacement parts mismatch', 'parts_quality', 4, 19, 24, 'critical', 'same_part', 'open', 'Wrong tube model shipped 4x — supplier catalog stale'),
    ('Engineer arrived without spare part kit', 'engineer_skill', 6, 25, 3, 'high', 'same_engineer', 'investigating', 'Same engineer rotation — kit checklist missing'),
    ('SLA breach on critical OT equipment', 'sla_breach', 3, 15, 8, 'critical', 'escalation_loop', 'open', 'Each escalation re-opens because root not fixed')
) sig(signature, category, cnt, first_offset, last_offset, sev, pat, stat, note)
ON CONFLICT DO NOTHING;

-- Seed RCA log entries
INSERT INTO public.ticket_recurrence_rca_log_r2284
  (cluster_id, root_cause, root_cause_category, corrective_action, preventive_action, owner_email, target_close_date, status, logged_by_email)
SELECT
  c.id,
  CASE c.issue_category
    WHEN 'equipment_failure' THEN 'Pressure sensor firmware bug in batch SN-2024-Q3'
    WHEN 'process_gap' THEN 'Slip generation step not in front-desk SOP'
    WHEN 'parts_quality' THEN 'Supplier catalog out of sync with manufacturer revisions'
    WHEN 'engineer_skill' THEN 'Spare part kit pre-flight check absent from engineer app'
    WHEN 'sla_breach' THEN 'Escalation closes ticket but does not trigger RCA workflow'
    ELSE 'Pending investigation'
  END,
  CASE c.issue_category
    WHEN 'equipment_failure' THEN 'product_defect'
    WHEN 'process_gap' THEN 'process_failure'
    WHEN 'parts_quality' THEN 'vendor_quality'
    WHEN 'engineer_skill' THEN 'training_gap'
    WHEN 'sla_breach' THEN 'systemic'
    ELSE 'systemic'
  END,
  'Recall affected units and field-upgrade firmware',
  'Add pre-shipment QA gate on sensor batches',
  'ops@equipseva.com',
  (now() + interval '14 days')::date,
  CASE c.cluster_status WHEN 'rca_logged' THEN 'in_progress' ELSE 'pending' END,
  'founder@equipseva.com'
FROM public.ticket_recurrence_clusters_r2284 c
WHERE c.cluster_status IN ('investigating','rca_logged','open')
ON CONFLICT DO NOTHING;

-- RPC 1: KPI summary
CREATE OR REPLACE FUNCTION public.r2284_recurrence_kpis()
RETURNS TABLE (
  total_clusters int,
  open_clusters int,
  critical_clusters int,
  rca_logged int,
  avg_tickets_per_cluster numeric,
  hospitals_affected int,
  resolved_clusters int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT (COUNT(*))::int FROM public.ticket_recurrence_clusters_r2284),
    (SELECT (COUNT(*) FILTER (WHERE cluster_status = 'open'))::int FROM public.ticket_recurrence_clusters_r2284),
    (SELECT (COUNT(*) FILTER (WHERE severity = 'critical'))::int FROM public.ticket_recurrence_clusters_r2284),
    (SELECT (COUNT(*))::int FROM public.ticket_recurrence_rca_log_r2284),
    (SELECT COALESCE(ROUND(AVG(ticket_count)::numeric, 1), 0) FROM public.ticket_recurrence_clusters_r2284),
    (SELECT (COUNT(DISTINCT hospital_org_id))::int FROM public.ticket_recurrence_clusters_r2284),
    (SELECT (COUNT(*) FILTER (WHERE cluster_status = 'resolved'))::int FROM public.ticket_recurrence_clusters_r2284);
END $$;

-- RPC 2: Top recurring clusters
CREATE OR REPLACE FUNCTION public.r2284_top_clusters()
RETURNS TABLE (
  cluster_id uuid,
  hospital_name text,
  issue_signature text,
  issue_category text,
  ticket_count int,
  severity text,
  pattern_type text,
  cluster_status text,
  last_seen_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_name, c.issue_signature, c.issue_category,
         c.ticket_count, c.severity, c.pattern_type, c.cluster_status, c.last_seen_at
  FROM public.ticket_recurrence_clusters_r2284 c
  ORDER BY
    CASE c.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    c.ticket_count DESC
  LIMIT 25;
END $$;

-- RPC 3: Category breakdown
CREATE OR REPLACE FUNCTION public.r2284_category_breakdown()
RETURNS TABLE (
  category text,
  cluster_count int,
  total_tickets int,
  critical_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.issue_category,
    (COUNT(*))::int,
    (SUM(c.ticket_count))::int,
    (COUNT(*) FILTER (WHERE c.severity = 'critical'))::int
  FROM public.ticket_recurrence_clusters_r2284 c
  GROUP BY c.issue_category
  ORDER BY SUM(c.ticket_count) DESC;
END $$;

-- RPC 4: Hospital repeat-offender ranking
CREATE OR REPLACE FUNCTION public.r2284_hospital_ranking()
RETURNS TABLE (
  hospital_name text,
  cluster_count int,
  total_tickets int,
  worst_severity text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.hospital_name,
    (COUNT(*))::int,
    (SUM(c.ticket_count))::int,
    (MIN(CASE c.severity WHEN 'critical' THEN '1_critical' WHEN 'high' THEN '2_high' WHEN 'medium' THEN '3_medium' ELSE '4_low' END))::text
  FROM public.ticket_recurrence_clusters_r2284 c
  GROUP BY c.hospital_name
  ORDER BY SUM(c.ticket_count) DESC
  LIMIT 15;
END $$;

-- RPC 5: RCA log entries
CREATE OR REPLACE FUNCTION public.r2284_rca_log()
RETURNS TABLE (
  rca_id uuid,
  issue_signature text,
  root_cause text,
  root_cause_category text,
  corrective_action text,
  owner_email text,
  status text,
  target_close_date date,
  logged_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, c.issue_signature, r.root_cause, r.root_cause_category,
         r.corrective_action, r.owner_email, r.status, r.target_close_date, r.logged_at
  FROM public.ticket_recurrence_rca_log_r2284 r
  JOIN public.ticket_recurrence_clusters_r2284 c ON c.id = r.cluster_id
  ORDER BY r.logged_at DESC
  LIMIT 25;
END $$;

-- RPC 6: Pattern type analysis
CREATE OR REPLACE FUNCTION public.r2284_pattern_analysis()
RETURNS TABLE (
  pattern_type text,
  occurrence_count int,
  avg_ticket_count numeric,
  high_severity_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.pattern_type,
    (COUNT(*))::int,
    ROUND(AVG(c.ticket_count)::numeric, 1),
    ROUND((COUNT(*) FILTER (WHERE c.severity IN ('high','critical')))::numeric * 100.0 / NULLIF(COUNT(*), 0), 1)
  FROM public.ticket_recurrence_clusters_r2284 c
  GROUP BY c.pattern_type
  ORDER BY COUNT(*) DESC;
END $$;

-- RPC 7: RCA effectiveness
CREATE OR REPLACE FUNCTION public.r2284_rca_effectiveness()
RETURNS TABLE (
  metric text,
  value text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'Total RCAs Logged'::text,
         (SELECT (COUNT(*))::text FROM public.ticket_recurrence_rca_log_r2284)
  UNION ALL
  SELECT 'Pending RCAs'::text,
         (SELECT (COUNT(*) FILTER (WHERE status = 'pending'))::text FROM public.ticket_recurrence_rca_log_r2284)
  UNION ALL
  SELECT 'In Progress'::text,
         (SELECT (COUNT(*) FILTER (WHERE status = 'in_progress'))::text FROM public.ticket_recurrence_rca_log_r2284)
  UNION ALL
  SELECT 'Closed RCAs'::text,
         (SELECT (COUNT(*) FILTER (WHERE status IN ('closed','verified')))::text FROM public.ticket_recurrence_rca_log_r2284)
  UNION ALL
  SELECT 'Avg Effectiveness Score'::text,
         (SELECT COALESCE(ROUND(AVG(effectiveness_score)::numeric, 1)::text, 'n/a') FROM public.ticket_recurrence_rca_log_r2284 WHERE effectiveness_score IS NOT NULL);
END $$;

REVOKE ALL ON FUNCTION public.r2284_recurrence_kpis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2284_top_clusters() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2284_category_breakdown() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2284_hospital_ranking() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2284_rca_log() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2284_pattern_analysis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2284_rca_effectiveness() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2284_recurrence_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2284_top_clusters() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2284_category_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2284_hospital_ranking() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2284_rca_log() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2284_pattern_analysis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2284_rca_effectiveness() TO authenticated;

COMMIT;
