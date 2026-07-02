-- Round r2496: customer-emergency-escalation-runbook
-- Incident x severity x escalation path x response time x resolution x lessons

CREATE TABLE IF NOT EXISTS public.customer_emergency_incidents_r2496 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  incident_at timestamptz NOT NULL,
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical','code_red')),
  equipment_label text,
  escalation_path_md text,
  response_minutes int CHECK (response_minutes IS NULL OR response_minutes >= 0),
  resolved_at timestamptz,
  resolution_minutes int CHECK (resolution_minutes IS NULL OR resolution_minutes >= 0),
  customer_satisfaction int CHECK (customer_satisfaction IS NULL OR (customer_satisfaction >= 0 AND customer_satisfaction <= 10)),
  escalation_owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.emergency_runbook_lessons_r2496 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid REFERENCES public.customer_emergency_incidents_r2496(id) ON DELETE CASCADE,
  lesson_kind text NOT NULL CHECK (lesson_kind IN ('process_gap','skill_gap','parts_missing','communication','escalation_failure')),
  lesson_md text,
  action_taken_md text,
  action_owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_emergency_incidents_r2496 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_runbook_lessons_r2496 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_emergency_incidents_r2496;
CREATE POLICY founder_all ON public.customer_emergency_incidents_r2496
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.emergency_runbook_lessons_r2496;
CREATE POLICY founder_all ON public.emergency_runbook_lessons_r2496
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed incidents (single-row INSERT with RETURNING into scalar is OK)
DO $$
DECLARE
  v_i1 uuid;
  v_i2 uuid;
  v_i3 uuid;
  v_i4 uuid;
  v_i5 uuid;
BEGIN
  INSERT INTO public.customer_emergency_incidents_r2496 (
    incident_at, severity, equipment_label, escalation_path_md, response_minutes,
    resolved_at, resolution_minutes, customer_satisfaction, escalation_owner_email, status, notes
  ) VALUES (
    '2026-06-18 09:15:00+05:30'::timestamptz, 'code_red', 'Apollo Hyderabad - MRI Coil Failure',
    '**L1** on-call engineer (5 min) => **L2** field lead (15 min) => **L3** founder + OEM (30 min)',
    8, '2026-06-18 13:42:00+05:30'::timestamptz, 267, 9,
    'marketingtools@getphyllo.com', 'resolved', 'Patient on table; OEM expedited spare via courier'
  ) RETURNING id INTO v_i1;

  INSERT INTO public.customer_emergency_incidents_r2496 (
    incident_at, severity, equipment_label, escalation_path_md, response_minutes,
    resolved_at, resolution_minutes, customer_satisfaction, escalation_owner_email, status, notes
  ) VALUES (
    '2026-06-19 14:22:00+05:30'::timestamptz, 'critical', 'KIMS - Ventilator Bay 3 Alarm',
    '**L1** on-call engineer (5 min) => **L2** field lead (20 min)',
    6, '2026-06-19 16:05:00+05:30'::timestamptz, 103, 8,
    'marketingtools@getphyllo.com', 'resolved', 'Bay swapped, original sent for module repair'
  ) RETURNING id INTO v_i2;

  INSERT INTO public.customer_emergency_incidents_r2496 (
    incident_at, severity, equipment_label, escalation_path_md, response_minutes,
    resolved_at, resolution_minutes, customer_satisfaction, escalation_owner_email, status, notes
  ) VALUES (
    '2026-06-20 11:00:00+05:30'::timestamptz, 'high', 'Yashoda - CT Scanner Power Loss',
    '**L1** on-call (10 min) => **L2** field lead (25 min)',
    12, '2026-06-20 14:30:00+05:30'::timestamptz, 210, 7,
    'marketingtools@getphyllo.com', 'resolved', 'UPS battery bank replaced'
  ) RETURNING id INTO v_i3;

  INSERT INTO public.customer_emergency_incidents_r2496 (
    incident_at, severity, equipment_label, escalation_path_md, response_minutes,
    resolved_at, resolution_minutes, customer_satisfaction, escalation_owner_email, status, notes
  ) VALUES (
    '2026-06-21 17:45:00+05:30'::timestamptz, 'medium', 'Care Hospitals - Dialysis Pump Slow',
    '**L1** on-call (15 min)',
    18, '2026-06-21 19:10:00+05:30'::timestamptz, 85, 8,
    'marketingtools@getphyllo.com', 'resolved', 'Pump head replaced from local stock'
  ) RETURNING id INTO v_i4;

  INSERT INTO public.customer_emergency_incidents_r2496 (
    incident_at, severity, equipment_label, escalation_path_md, response_minutes,
    resolved_at, resolution_minutes, customer_satisfaction, escalation_owner_email, status, notes
  ) VALUES (
    '2026-06-22 08:00:00+05:30'::timestamptz, 'low', 'Sunshine Hospitals - Defibrillator Battery Warning',
    '**L1** on-call (30 min)',
    35, '2026-06-22 10:15:00+05:30'::timestamptz, 135, 7,
    'marketingtools@getphyllo.com', 'resolved', 'Battery swap; preventive across all units scheduled'
  ) RETURNING id INTO v_i5;

  -- Seed lessons (one per incident; single-row INSERTs with RETURNING-into-scalar safe)
  INSERT INTO public.emergency_runbook_lessons_r2496 (
    incident_id, lesson_kind, lesson_md, action_taken_md, action_owner_email, status, notes
  ) VALUES
    (v_i1, 'parts_missing', 'MRI coil spares were not stocked locally; courier added 4 hours.', 'Bond 2 MRI coil spares at Hyderabad hub; OEM SLA tightened to 6h.', 'marketingtools@getphyllo.com', 'in_progress'::text, 'Awaiting bonded inventory PO close'),
    (v_i2, 'process_gap', 'No runbook for ventilator bay-swap; engineer improvised.', 'Wrote ventilator bay-swap SOP; trained all L1 in field.', 'marketingtools@getphyllo.com', 'done', 'SOP doc shipped 2026-06-21'),
    (v_i3, 'communication', 'Customer not informed during 3.5h fix; escalated to founder via call.', 'Added 30-min status SMS automation to escalation pipeline.', 'marketingtools@getphyllo.com', 'open', 'Automation in r2497 backlog'),
    (v_i4, 'skill_gap', 'L1 engineer needed L2 walkthrough for pump-head swap.', 'Added pump-head swap to L1 cert ladder + practical test.', 'marketingtools@getphyllo.com', 'done', 'Cert ladder updated'),
    (v_i5, 'escalation_failure', 'Low-severity ticket sat 30 min before pickup; routing rule missed device class.', 'Routing rule updated; severity-low SLA reduced 60m => 30m.', 'marketingtools@getphyllo.com', 'done', 'Routing live');

  -- Extra escalation-failure lesson on the code_red incident
  INSERT INTO public.emergency_runbook_lessons_r2496 (
    incident_id, lesson_kind, lesson_md, action_taken_md, action_owner_email, status, notes
  ) VALUES
    (v_i1, 'escalation_failure', 'L2 paged 12 min late because on-call rotation file was stale.', 'Migrated rotation to spot_audit cron-backed table; alerts now go to live owner.', 'marketingtools@getphyllo.com', 'in_progress', 'Verify in next code_red drill');
END $$;

-- RPC 1: list incidents
CREATE OR REPLACE FUNCTION public.list_incidents_r2496()
RETURNS SETOF public.customer_emergency_incidents_r2496
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.customer_emergency_incidents_r2496 ORDER BY incident_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_incidents_r2496() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_incidents_r2496() TO authenticated;

-- RPC 2: list lessons
CREATE OR REPLACE FUNCTION public.list_lessons_r2496()
RETURNS SETOF public.emergency_runbook_lessons_r2496
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.emergency_runbook_lessons_r2496 ORDER BY created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_lessons_r2496() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_lessons_r2496() TO authenticated;

-- RPC 3: top severity focus
CREATE OR REPLACE FUNCTION public.top_severity_focus_r2496()
RETURNS TABLE(severity text, incident_count int, avg_response numeric, avg_resolution numeric, avg_csat numeric, open_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.severity,
           count(*)::int AS incident_count,
           round(avg(i.response_minutes)::numeric, 1) AS avg_response,
           round(avg(i.resolution_minutes)::numeric, 1) AS avg_resolution,
           round(avg(i.customer_satisfaction)::numeric, 2) AS avg_csat,
           count(*) FILTER (WHERE i.status IN ('open','in_progress'))::int AS open_count
    FROM public.customer_emergency_incidents_r2496 i
    GROUP BY i.severity
    ORDER BY
      CASE i.severity
        WHEN 'code_red' THEN 1
        WHEN 'critical' THEN 2
        WHEN 'high' THEN 3
        WHEN 'medium' THEN 4
        WHEN 'low' THEN 5
        ELSE 6
      END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_severity_focus_r2496() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_severity_focus_r2496() TO authenticated;

-- RPC 4: response time summary
CREATE OR REPLACE FUNCTION public.response_time_summary_r2496()
RETURNS TABLE(metric text, value numeric, detail text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_avg_response numeric;
  v_avg_resolution numeric;
  v_max_response int;
  v_max_resolution int;
  v_avg_csat numeric;
  v_open int;
  v_code_red int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(*)::int,
         round(avg(response_minutes)::numeric, 1),
         round(avg(resolution_minutes)::numeric, 1),
         max(response_minutes),
         max(resolution_minutes),
         round(avg(customer_satisfaction)::numeric, 2)
    INTO v_total, v_avg_response, v_avg_resolution, v_max_response, v_max_resolution, v_avg_csat
    FROM public.customer_emergency_incidents_r2496;

  SELECT count(*)::int INTO v_open
    FROM public.customer_emergency_incidents_r2496
    WHERE status IN ('open','in_progress');

  SELECT count(*)::int INTO v_code_red
    FROM public.customer_emergency_incidents_r2496
    WHERE severity = 'code_red';

  RETURN QUERY
    SELECT 'total_incidents'::text, COALESCE(v_total,0)::numeric, 'all logged incidents'::text
    UNION ALL SELECT 'avg_response_min'::text, COALESCE(v_avg_response,0), 'mean minutes to first response'::text
    UNION ALL SELECT 'avg_resolution_min'::text, COALESCE(v_avg_resolution,0), 'mean minutes to resolved'::text
    UNION ALL SELECT 'max_response_min'::text, COALESCE(v_max_response,0)::numeric, 'worst first-response time'::text
    UNION ALL SELECT 'max_resolution_min'::text, COALESCE(v_max_resolution,0)::numeric, 'worst resolution time'::text
    UNION ALL SELECT 'avg_csat'::text, COALESCE(v_avg_csat,0), 'mean customer satisfaction 0-10'::text
    UNION ALL SELECT 'open_or_in_progress'::text, COALESCE(v_open,0)::numeric, 'incidents not yet resolved'::text
    UNION ALL SELECT 'code_red_count'::text, COALESCE(v_code_red,0)::numeric, 'code_red incidents on record'::text;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.response_time_summary_r2496() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.response_time_summary_r2496() TO authenticated;

-- RPC 5: lesson kind breakdown
CREATE OR REPLACE FUNCTION public.lesson_kind_breakdown_r2496()
RETURNS TABLE(lesson_kind text, lesson_count int, open_count int, done_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.lesson_kind,
           count(*)::int AS lesson_count,
           count(*) FILTER (WHERE l.status = 'open')::int AS open_count,
           count(*) FILTER (WHERE l.status = 'done')::int AS done_count
    FROM public.emergency_runbook_lessons_r2496 l
    GROUP BY l.lesson_kind
    ORDER BY lesson_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.lesson_kind_breakdown_r2496() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lesson_kind_breakdown_r2496() TO authenticated;

-- RPC 6: monthly incident trend
CREATE OR REPLACE FUNCTION public.monthly_incident_trend_r2496()
RETURNS TABLE(month_start date, incident_count int, code_red_count int, avg_response numeric, avg_resolution numeric, avg_csat numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', incident_at)::date AS month_start,
           count(*)::int AS incident_count,
           count(*) FILTER (WHERE severity = 'code_red')::int AS code_red_count,
           round(avg(response_minutes)::numeric, 1) AS avg_response,
           round(avg(resolution_minutes)::numeric, 1) AS avg_resolution,
           round(avg(customer_satisfaction)::numeric, 2) AS avg_csat
    FROM public.customer_emergency_incidents_r2496
    GROUP BY 1
    ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_incident_trend_r2496() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_incident_trend_r2496() TO authenticated;

-- RPC 7: owner load
CREATE OR REPLACE FUNCTION public.owner_load_r2496()
RETURNS TABLE(owner_email text, incident_owned int, lessons_owned int, open_actions int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(i.escalation_owner_email, l.action_owner_email) AS owner_email,
           count(DISTINCT i.id)::int AS incident_owned,
           count(DISTINCT l.id)::int AS lessons_owned,
           count(DISTINCT l.id) FILTER (WHERE l.status = 'open')::int AS open_actions
    FROM public.customer_emergency_incidents_r2496 i
    FULL OUTER JOIN public.emergency_runbook_lessons_r2496 l
      ON l.action_owner_email = i.escalation_owner_email
    WHERE COALESCE(i.escalation_owner_email, l.action_owner_email) IS NOT NULL
    GROUP BY 1
    ORDER BY incident_owned DESC, lessons_owned DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2496() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2496() TO authenticated;
