-- Round r2907 — Hospital Chain Quarterly OT-Schedule Disruption Root-Cause Audit
-- HEAVY founder ops round: 2 tables + 7 RPCs + seed data

-- =========================================================================
-- TABLE 1: ot_disruption_events_r2907
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.ot_disruption_events_r2907 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_site text NOT NULL,
  ot_room_code text NOT NULL,
  event_date date NOT NULL,
  quarter_label text NOT NULL,
  scheduled_start_at timestamptz NOT NULL,
  actual_start_at timestamptz,
  delay_minutes integer NOT NULL DEFAULT 0,
  cancelled boolean NOT NULL DEFAULT false,
  root_cause_category text NOT NULL,
  root_cause_detail text NOT NULL,
  equipment_involved text,
  severity text NOT NULL DEFAULT 'p2',
  revenue_loss_rupees numeric(12,2) NOT NULL DEFAULT 0,
  surgeon_name text,
  case_count integer NOT NULL DEFAULT 1
);

ALTER TABLE public.ot_disruption_events_r2907 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- TABLE 2: ot_chain_corrective_actions_r2907
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.ot_chain_corrective_actions_r2907 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_site text NOT NULL,
  quarter_label text NOT NULL,
  action_title text NOT NULL,
  owner_role text NOT NULL,
  due_date date NOT NULL,
  status text NOT NULL DEFAULT 'open',
  expected_disruption_reduction_pct numeric(5,2) NOT NULL DEFAULT 0,
  estimated_cost_rupees numeric(12,2) NOT NULL DEFAULT 0,
  related_root_cause_category text NOT NULL,
  founder_priority text NOT NULL DEFAULT 'normal',
  last_update_note text
);

ALTER TABLE public.ot_chain_corrective_actions_r2907 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- SEED: ot_disruption_events_r2907 (20 rows)
-- =========================================================================
INSERT INTO public.ot_disruption_events_r2907
  (chain_name, hospital_site, ot_room_code, event_date, quarter_label, scheduled_start_at, actual_start_at, delay_minutes, cancelled, root_cause_category, root_cause_detail, equipment_involved, severity, revenue_loss_rupees, surgeon_name, case_count)
VALUES
  ('Apollo Group','Apollo Hyderabad Jubilee','OT-3','2026-04-08'::date,'Q1-2026','2026-04-08 08:30:00+05:30'::timestamptz,'2026-04-08 10:05:00+05:30'::timestamptz,95,false,'equipment_failure','C-arm imaging module overheated at boot','Siemens Cios Alpha C-arm','p1',185000,'Dr. R. Menon',1),
  ('Apollo Group','Apollo Chennai Greams Road','OT-1','2026-04-12'::date,'Q1-2026','2026-04-12 09:00:00+05:30'::timestamptz,NULL,0,true,'equipment_failure','Anesthesia workstation vaporizer leak — case cancelled','GE Aisys CS2','p0',420000,'Dr. S. Iyer',2),
  ('Apollo Group','Apollo Bangalore Bannerghatta','OT-5','2026-04-21'::date,'Q1-2026','2026-04-21 07:30:00+05:30'::timestamptz,'2026-04-21 08:15:00+05:30'::timestamptz,45,false,'staffing','Scrub nurse no-show, replacement from float pool','—','p2',60000,'Dr. K. Rao',1),
  ('Apollo Group','Apollo Hyderabad Jubilee','OT-2','2026-05-03'::date,'Q2-2026','2026-05-03 08:00:00+05:30'::timestamptz,'2026-05-03 09:30:00+05:30'::timestamptz,90,false,'sterilization','CSSD autoclave cycle failure — re-sterilization required','Getinge HS66','p1',150000,'Dr. R. Menon',1),
  ('Apollo Group','Apollo Chennai Greams Road','OT-4','2026-05-17'::date,'Q2-2026','2026-05-17 10:00:00+05:30'::timestamptz,'2026-05-17 11:20:00+05:30'::timestamptz,80,false,'equipment_failure','Electrosurgical unit foot-pedal intermittent','Covidien Force Triad','p2',95000,'Dr. P. Verma',1),
  ('Apollo Group','Apollo Bangalore Bannerghatta','OT-1','2026-06-04'::date,'Q2-2026','2026-06-04 07:00:00+05:30'::timestamptz,NULL,0,true,'patient_factor','Patient INR out of range — postponed','—','p3',0,'Dr. K. Rao',1),
  ('Manipal Hospitals','Manipal Whitefield','OT-7','2026-04-10'::date,'Q1-2026','2026-04-10 08:30:00+05:30'::timestamptz,'2026-04-10 10:45:00+05:30'::timestamptz,135,false,'equipment_failure','OT lights driver board failure mid-setup','Trumpf TruLight 5000','p0',310000,'Dr. M. Bhat',2),
  ('Manipal Hospitals','Manipal Old Airport Road','OT-2','2026-04-23'::date,'Q1-2026','2026-04-23 09:00:00+05:30'::timestamptz,'2026-04-23 09:55:00+05:30'::timestamptz,55,false,'sterilization','Instrument tray missing — re-pack from CSSD','—','p2',72000,'Dr. A. Shetty',1),
  ('Manipal Hospitals','Manipal Whitefield','OT-3','2026-05-09'::date,'Q2-2026','2026-05-09 08:00:00+05:30'::timestamptz,'2026-05-09 09:10:00+05:30'::timestamptz,70,false,'equipment_failure','Patient monitor display blanked intermittently','Mindray ePM 12M','p2',88000,'Dr. M. Bhat',1),
  ('Manipal Hospitals','Manipal Old Airport Road','OT-6','2026-05-22'::date,'Q2-2026','2026-05-22 07:30:00+05:30'::timestamptz,NULL,0,true,'equipment_failure','Anesthesia ventilator O2 cell expired — no spare on site','Drager Fabius Tiro','p0',380000,'Dr. A. Shetty',2),
  ('Manipal Hospitals','Manipal Whitefield','OT-1','2026-06-11'::date,'Q2-2026','2026-06-11 10:00:00+05:30'::timestamptz,'2026-06-11 11:15:00+05:30'::timestamptz,75,false,'staffing','Anesthesiologist stuck in earlier case overrun','—','p2',105000,'Dr. M. Bhat',1),
  ('Fortis Healthcare','Fortis Mulund','OT-2','2026-04-15'::date,'Q1-2026','2026-04-15 08:00:00+05:30'::timestamptz,'2026-04-15 09:30:00+05:30'::timestamptz,90,false,'equipment_failure','Operating table hydraulic drift on Trendelenburg','Maquet Yuno II','p1',165000,'Dr. N. Pillai',1),
  ('Fortis Healthcare','Fortis Gurgaon','OT-4','2026-04-28'::date,'Q1-2026','2026-04-28 09:30:00+05:30'::timestamptz,'2026-04-28 10:50:00+05:30'::timestamptz,80,false,'sterilization','Plasma sterilizer cycle alarm — repeat needed','Sterrad NX','p2',98000,'Dr. V. Kapoor',1),
  ('Fortis Healthcare','Fortis Mulund','OT-5','2026-05-14'::date,'Q2-2026','2026-05-14 07:00:00+05:30'::timestamptz,NULL,0,true,'equipment_failure','Laparoscopy stack camera head fluid ingress','Karl Storz IMAGE1 S','p0',455000,'Dr. N. Pillai',2),
  ('Fortis Healthcare','Fortis Gurgaon','OT-1','2026-05-26'::date,'Q2-2026','2026-05-26 08:30:00+05:30'::timestamptz,'2026-05-26 09:25:00+05:30'::timestamptz,55,false,'staffing','OT technician late — traffic incident','—','p2',62000,'Dr. V. Kapoor',1),
  ('Fortis Healthcare','Fortis Mulund','OT-3','2026-06-17'::date,'Q2-2026','2026-06-17 10:00:00+05:30'::timestamptz,'2026-06-17 11:40:00+05:30'::timestamptz,100,false,'equipment_failure','Diathermy unit ground-fault interrupt repeated trips','ERBE VIO 300 D','p1',175000,'Dr. N. Pillai',1),
  ('Max Healthcare','Max Saket','OT-2','2026-04-19'::date,'Q1-2026','2026-04-19 08:00:00+05:30'::timestamptz,'2026-04-19 09:45:00+05:30'::timestamptz,105,false,'equipment_failure','Anesthesia gas scavenging line blockage','—','p1',195000,'Dr. T. Singh',1),
  ('Max Healthcare','Max Patparganj','OT-1','2026-05-06'::date,'Q2-2026','2026-05-06 07:30:00+05:30'::timestamptz,NULL,0,true,'sterilization','Bowie-Dick test failure — entire AM list shifted','Getinge HS66','p0',520000,'Dr. L. Khanna',3),
  ('Max Healthcare','Max Saket','OT-4','2026-05-29'::date,'Q2-2026','2026-05-29 09:00:00+05:30'::timestamptz,'2026-05-29 10:15:00+05:30'::timestamptz,75,false,'equipment_failure','Microscope balance arm drift','Leica M530 OH6','p2',115000,'Dr. T. Singh',1),
  ('Max Healthcare','Max Patparganj','OT-3','2026-06-20'::date,'Q2-2026','2026-06-20 08:30:00+05:30'::timestamptz,'2026-06-20 09:40:00+05:30'::timestamptz,70,false,'patient_factor','Pre-op consent re-do required','—','p3',45000,'Dr. L. Khanna',1);

-- =========================================================================
-- SEED: ot_chain_corrective_actions_r2907 (18 rows)
-- =========================================================================
INSERT INTO public.ot_chain_corrective_actions_r2907
  (chain_name, hospital_site, quarter_label, action_title, owner_role, due_date, status, expected_disruption_reduction_pct, estimated_cost_rupees, related_root_cause_category, founder_priority, last_update_note)
VALUES
  ('Apollo Group','Apollo Hyderabad Jubilee','Q2-2026','C-arm pre-op warmup SOP + bi-weekly calibration','biomed_lead','2026-07-15'::date,'in_progress',35.0,85000,'equipment_failure','high','SOP drafted, awaiting medical director sign-off'),
  ('Apollo Group','Apollo Chennai Greams Road','Q2-2026','Replace Aisys CS2 vaporizer O-rings across all 6 OTs','biomed_lead','2026-07-30'::date,'open',25.0,240000,'equipment_failure','critical','Parts on order from GE — 3 week lead time'),
  ('Apollo Group','Apollo Bangalore Bannerghatta','Q2-2026','Scrub nurse float pool expansion +4 FTE','nursing_director','2026-08-15'::date,'open',40.0,1800000,'staffing','high','HR posted reqs, 12 candidates screening'),
  ('Apollo Group','Apollo Hyderabad Jubilee','Q2-2026','CSSD autoclave preventive maintenance contract upgrade','procurement_head','2026-07-20'::date,'in_progress',50.0,320000,'sterilization','high','AMC quote from Getinge received'),
  ('Manipal Hospitals','Manipal Whitefield','Q2-2026','OT light LED driver board spare stocking (8 units)','biomed_lead','2026-07-10'::date,'completed',60.0,180000,'equipment_failure','critical','Spares received and stocked, drill test passed'),
  ('Manipal Hospitals','Manipal Old Airport Road','Q2-2026','CSSD tray pre-flight checklist digital tablet rollout','ot_manager','2026-08-05'::date,'in_progress',45.0,95000,'sterilization','normal','Pilot OT-2 onboarded'),
  ('Manipal Hospitals','Manipal Whitefield','Q2-2026','Patient monitor firmware update — Mindray ePM batch','biomed_lead','2026-07-25'::date,'open',30.0,0,'equipment_failure','normal','Awaiting Mindray FSE schedule'),
  ('Manipal Hospitals','Manipal Old Airport Road','Q2-2026','O2 cell expiry tracking — barcode + auto-reorder','biomed_lead','2026-07-12'::date,'completed',80.0,55000,'equipment_failure','critical','Live in inventory system'),
  ('Manipal Hospitals','Manipal Whitefield','Q2-2026','Anesthesia case-overrun escalation protocol','medical_director','2026-08-20'::date,'open',25.0,0,'staffing','normal','Draft circulated'),
  ('Fortis Healthcare','Fortis Mulund','Q2-2026','Maquet table hydraulic seal kit refresh — all 4 tables','biomed_lead','2026-07-28'::date,'in_progress',55.0,210000,'equipment_failure','high','2 of 4 done'),
  ('Fortis Healthcare','Fortis Gurgaon','Q2-2026','Sterrad consumable lot validation pre-cycle','cssd_lead','2026-07-18'::date,'completed',40.0,30000,'sterilization','normal','SOP live'),
  ('Fortis Healthcare','Fortis Mulund','Q2-2026','Karl Storz camera head dry-box storage retrofit','biomed_lead','2026-08-10'::date,'open',70.0,145000,'equipment_failure','critical','Vendor site survey done'),
  ('Fortis Healthcare','Fortis Gurgaon','Q2-2026','OT-tech on-call rotation + cab standby','ot_manager','2026-07-22'::date,'in_progress',35.0,72000,'staffing','normal','3 techs in rotation'),
  ('Fortis Healthcare','Fortis Mulund','Q2-2026','ERBE VIO 300 ground-pad audit + replacement','biomed_lead','2026-07-14'::date,'completed',65.0,48000,'equipment_failure','high','Closed'),
  ('Max Healthcare','Max Saket','Q2-2026','Anesthesia scavenging line annual deep-clean','biomed_lead','2026-08-25'::date,'open',40.0,165000,'equipment_failure','high','Schedule pending list approval'),
  ('Max Healthcare','Max Patparganj','Q2-2026','Daily Bowie-Dick + Helix test SOP digitization','cssd_lead','2026-07-16'::date,'in_progress',75.0,42000,'sterilization','critical','Tablet kits deployed'),
  ('Max Healthcare','Max Saket','Q2-2026','Leica microscope balance-arm spring service','biomed_lead','2026-07-29'::date,'open',45.0,68000,'equipment_failure','normal','Vendor visit booked'),
  ('Max Healthcare','Max Patparganj','Q2-2026','Pre-op consent dual-witness digital sign-off','quality_lead','2026-08-12'::date,'in_progress',55.0,38000,'patient_factor','normal','Form v2 piloting');

-- =========================================================================
-- RPC 1: chain_quarter_disruption_summary_r2907
-- =========================================================================
CREATE OR REPLACE FUNCTION public.chain_quarter_disruption_summary_r2907()
RETURNS TABLE (
  chain_name text,
  quarter_label text,
  events_total bigint,
  cancelled_count bigint,
  delayed_count bigint,
  avg_delay_minutes numeric,
  total_revenue_loss_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT
    e.chain_name,
    e.quarter_label,
    count(*)::bigint AS events_total,
    count(*) FILTER (WHERE e.cancelled)::bigint AS cancelled_count,
    count(*) FILTER (WHERE NOT e.cancelled AND e.delay_minutes > 0)::bigint AS delayed_count,
    round(avg(NULLIF(e.delay_minutes,0))::numeric, 1) AS avg_delay_minutes,
    sum(e.revenue_loss_rupees)::numeric AS total_revenue_loss_rupees
  FROM public.ot_disruption_events_r2907 e
  GROUP BY e.chain_name, e.quarter_label
  ORDER BY total_revenue_loss_rupees DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.chain_quarter_disruption_summary_r2907() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_quarter_disruption_summary_r2907() TO authenticated;

-- =========================================================================
-- RPC 2: root_cause_pareto_r2907
-- =========================================================================
CREATE OR REPLACE FUNCTION public.root_cause_pareto_r2907()
RETURNS TABLE (
  root_cause_category text,
  event_count bigint,
  revenue_loss_rupees numeric,
  pct_of_total_loss numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  SELECT NULLIF(sum(revenue_loss_rupees),0) INTO v_total FROM public.ot_disruption_events_r2907;

  RETURN QUERY
  SELECT
    e.root_cause_category,
    count(*)::bigint AS event_count,
    sum(e.revenue_loss_rupees)::numeric AS revenue_loss_rupees,
    round((sum(e.revenue_loss_rupees) / COALESCE(v_total,1)) * 100, 2) AS pct_of_total_loss
  FROM public.ot_disruption_events_r2907 e
  GROUP BY e.root_cause_category
  ORDER BY revenue_loss_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.root_cause_pareto_r2907() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.root_cause_pareto_r2907() TO authenticated;

-- =========================================================================
-- RPC 3: site_worst_offenders_r2907
-- =========================================================================
CREATE OR REPLACE FUNCTION public.site_worst_offenders_r2907()
RETURNS TABLE (
  hospital_site text,
  chain_name text,
  total_events bigint,
  cancellation_rate_pct numeric,
  total_loss_rupees numeric,
  top_root_cause text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  WITH agg AS (
    SELECT
      e.hospital_site,
      e.chain_name,
      count(*)::bigint AS total_events,
      round((count(*) FILTER (WHERE e.cancelled)::numeric / NULLIF(count(*),0)) * 100, 1) AS cancellation_rate_pct,
      sum(e.revenue_loss_rupees)::numeric AS total_loss_rupees
    FROM public.ot_disruption_events_r2907 e
    GROUP BY e.hospital_site, e.chain_name
  ),
  top_cause AS (
    SELECT DISTINCT ON (e.hospital_site)
      e.hospital_site,
      e.root_cause_category AS top_cause
    FROM public.ot_disruption_events_r2907 e
    GROUP BY e.hospital_site, e.root_cause_category
    ORDER BY e.hospital_site, sum(e.revenue_loss_rupees) DESC
  )
  SELECT a.hospital_site, a.chain_name, a.total_events, a.cancellation_rate_pct, a.total_loss_rupees, t.top_cause
  FROM agg a
  LEFT JOIN top_cause t USING (hospital_site)
  ORDER BY a.total_loss_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.site_worst_offenders_r2907() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.site_worst_offenders_r2907() TO authenticated;

-- =========================================================================
-- RPC 4: equipment_failure_hotlist_r2907
-- =========================================================================
CREATE OR REPLACE FUNCTION public.equipment_failure_hotlist_r2907()
RETURNS TABLE (
  equipment_involved text,
  failure_count bigint,
  total_delay_minutes bigint,
  total_loss_rupees numeric,
  last_event_date date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT
    e.equipment_involved,
    count(*)::bigint AS failure_count,
    sum(e.delay_minutes)::bigint AS total_delay_minutes,
    sum(e.revenue_loss_rupees)::numeric AS total_loss_rupees,
    max(e.event_date) AS last_event_date
  FROM public.ot_disruption_events_r2907 e
  WHERE e.root_cause_category = 'equipment_failure'
    AND e.equipment_involved IS NOT NULL
    AND e.equipment_involved <> '—'
  GROUP BY e.equipment_involved
  ORDER BY total_loss_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.equipment_failure_hotlist_r2907() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipment_failure_hotlist_r2907() TO authenticated;

-- =========================================================================
-- RPC 5: severity_distribution_r2907
-- =========================================================================
CREATE OR REPLACE FUNCTION public.severity_distribution_r2907()
RETURNS TABLE (
  severity text,
  event_count bigint,
  avg_delay_minutes numeric,
  total_loss_rupees numeric,
  cancellation_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT
    e.severity,
    count(*)::bigint AS event_count,
    round(avg(NULLIF(e.delay_minutes,0))::numeric, 1) AS avg_delay_minutes,
    sum(e.revenue_loss_rupees)::numeric AS total_loss_rupees,
    count(*) FILTER (WHERE e.cancelled)::bigint AS cancellation_count
  FROM public.ot_disruption_events_r2907 e
  GROUP BY e.severity
  ORDER BY e.severity ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.severity_distribution_r2907() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.severity_distribution_r2907() TO authenticated;

-- =========================================================================
-- RPC 6: corrective_action_progress_r2907
-- =========================================================================
CREATE OR REPLACE FUNCTION public.corrective_action_progress_r2907()
RETURNS TABLE (
  chain_name text,
  open_count bigint,
  in_progress_count bigint,
  completed_count bigint,
  critical_open bigint,
  total_estimated_cost numeric,
  expected_blended_reduction_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT
    a.chain_name,
    count(*) FILTER (WHERE a.status = 'open')::bigint AS open_count,
    count(*) FILTER (WHERE a.status = 'in_progress')::bigint AS in_progress_count,
    count(*) FILTER (WHERE a.status = 'completed')::bigint AS completed_count,
    count(*) FILTER (WHERE a.status <> 'completed' AND a.founder_priority = 'critical')::bigint AS critical_open,
    sum(a.estimated_cost_rupees)::numeric AS total_estimated_cost,
    round(avg(a.expected_disruption_reduction_pct)::numeric, 1) AS expected_blended_reduction_pct
  FROM public.ot_chain_corrective_actions_r2907 a
  GROUP BY a.chain_name
  ORDER BY critical_open DESC, open_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.corrective_action_progress_r2907() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.corrective_action_progress_r2907() TO authenticated;

-- =========================================================================
-- RPC 7: founder_priority_action_queue_r2907
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_priority_action_queue_r2907()
RETURNS TABLE (
  action_title text,
  chain_name text,
  hospital_site text,
  owner_role text,
  due_date date,
  status text,
  founder_priority text,
  expected_reduction_pct numeric,
  estimated_cost numeric,
  last_update_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT
    a.action_title,
    a.chain_name,
    a.hospital_site,
    a.owner_role,
    a.due_date,
    a.status,
    a.founder_priority,
    a.expected_disruption_reduction_pct,
    a.estimated_cost_rupees,
    a.last_update_note
  FROM public.ot_chain_corrective_actions_r2907 a
  WHERE a.founder_priority IN ('critical','high')
    AND a.status <> 'completed'
  ORDER BY
    CASE a.founder_priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
    a.due_date ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_priority_action_queue_r2907() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_priority_action_queue_r2907() TO authenticated;
