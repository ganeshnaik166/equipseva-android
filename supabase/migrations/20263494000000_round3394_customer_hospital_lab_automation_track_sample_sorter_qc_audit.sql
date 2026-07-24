-- Round 3394: Customer Hospital Laboratory-Automation Track (TLA) & Sample-Sorter QC Audit
-- Lab automation QA — system type × lab section × throughput × routing accuracy × barcode read × jam rate × STAT routing × LIS connectivity × decap/recap × centrifuge balance × CAPA

-- =============================================================================
-- TABLE 1: lab_automation_qc_r3394 — per-module QC checks
-- =============================================================================
create table if not exists public.lab_automation_qc_r3394 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  unit_code text not null,
  system_type text not null check (system_type in (
    'track_conveyor','sample_sorter','centrifuge_module','aliquoter',
    'decapper_recapper','refrigerated_storage_module','connection_bridge'
  )),
  lab_section text not null,
  check_date date not null,
  throughput_ok boolean not null,
  sample_routing_accuracy_error_pct numeric(5,2),
  barcode_read_rate_pct numeric(5,2),
  jam_rate_ok boolean not null,
  stat_priority_routing_ok boolean not null,
  connectivity_lis_ok boolean not null,
  decap_recap_ok text not null check (decap_recap_ok in (
    'ok','misaligned','fail','not_applicable'
  )),
  centrifuge_balance_ok text not null check (centrifuge_balance_ok in (
    'ok','imbalance','fail','not_applicable'
  )),
  preventive_maint_current boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lab_automation_qc_r3394 enable row level security;

create index if not exists idx_lab_automation_qc_r3394_org on public.lab_automation_qc_r3394(organization_id);
create index if not exists idx_lab_automation_qc_r3394_date on public.lab_automation_qc_r3394(check_date);
create index if not exists idx_lab_automation_qc_r3394_verdict on public.lab_automation_qc_r3394(qc_verdict);

-- =============================================================================
-- TABLE 2: lab_automation_qc_capa_actions_r3394 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.lab_automation_qc_capa_actions_r3394 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.lab_automation_qc_r3394(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'throughput_shortfall','routing_error','barcode_read_failure','frequent_jams',
    'stat_routing_failure','lis_connectivity_loss','decap_recap_failure',
    'centrifuge_imbalance','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'mechanical_wear','sensor_misalignment','barcode_scanner_degraded','software_config_error',
    'label_quality_issue','network_fault','gripper_wear','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'realign_sensors','replace_scanner','clean_track','update_software_config',
    'replace_gripper','repair_network','recalibrate','retrain_lab_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','none','internal_only','iso_15189_deviation','turnaround_time_breach'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lab_automation_qc_capa_actions_r3394 enable row level security;

create index if not exists idx_lab_automation_capa_r3394_log on public.lab_automation_qc_capa_actions_r3394(qc_log_id);
create index if not exists idx_lab_automation_capa_r3394_status on public.lab_automation_qc_capa_actions_r3394(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  insert into public.lab_automation_qc_r3394 (
    organization_id, hospital_name, unit_code, system_type, lab_section, check_date,
    throughput_ok, sample_routing_accuracy_error_pct, barcode_read_rate_pct, jam_rate_ok,
    stat_priority_routing_ok, connectivity_lis_ok, decap_recap_ok, centrifuge_balance_ok,
    preventive_maint_current, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.ucode, q.stype, q.sect, q.cdate::date,
    q.thru, q.rerr, q.brate, q.jam,
    q.stat, q.lis, q.decap, q.centbal,
    q.pm, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','TLA-APL-01','track_conveyor','central_lab','2026-07-03',
     true,0.4,99.6,true,true,true,'not_applicable','not_applicable',true,true,'pass','Quarterly QC — track conveyor throughput and routing nominal'),
    ('Apollo Chennai','TLA-APL-02','sample_sorter','central_lab','2026-07-03',
     true,0.7,99.2,true,true,true,'ok','not_applicable',true,true,'pass','Sample sorter routing accuracy within spec'),
    ('Fortis Gurgaon','TLA-FRT-11','centrifuge_module','central_lab','2026-07-02',
     true,null,null,true,true,true,'not_applicable','imbalance',true,true,'conditional_pass','Centrifuge module intermittent imbalance alarm — recheck booked'),
    ('Fortis Gurgaon','TLA-FRT-12','decapper_recapper','central_lab','2026-07-02',
     false,null,null,false,true,true,'fail','not_applicable',true,true,'fail','Decapper misgrips and frequent jams — throughput down, pulled'),
    ('Manipal Bengaluru','TLA-MNP-21','track_conveyor','central_lab','2026-07-01',
     true,1.8,97.1,true,false,true,'not_applicable','not_applicable',false,false,'conditional_pass','Routing error 1.8%, STAT routing failed once, PM and calibration overdue'),
    ('Manipal Bengaluru','TLA-MNP-22','aliquoter','central_lab','2026-07-01',
     true,0.5,99.4,true,true,true,'ok','not_applicable',true,true,'pass','Aliquoter QC nominal'),
    ('AIIMS Delhi','TLA-AIM-31','sample_sorter','central_lab','2026-06-30',
     true,0.9,98.6,true,true,true,'ok','not_applicable',true,true,'conditional_pass','Barcode read 98.6% — label quality flagged, monitor'),
    ('AIIMS Delhi','TLA-AIM-32','connection_bridge','central_lab','2026-06-30',
     false,null,null,true,true,false,'not_applicable','not_applicable',true,true,'fail','Connection bridge LIS connectivity lost and throughput halted'),
    ('CMC Vellore','TLA-CMC-41','centrifuge_module','central_lab','2026-06-29',
     true,null,null,true,true,true,'not_applicable','ok',true,true,'pass','Centrifuge module balance QC pass'),
    ('CMC Vellore','TLA-CMC-42','refrigerated_storage_module','central_lab','2026-06-29',
     true,0.6,99.0,true,true,true,'not_applicable','not_applicable',true,false,'conditional_pass','Storage module retrieval ok but calibration overdue — schedule'),
    ('KIMS Hyderabad','TLA-KIM-51','track_conveyor','central_lab','2026-06-28',
     true,0.3,99.7,true,true,true,'not_applicable','not_applicable',true,true,'pass','Track conveyor QC pass post-AMC'),
    ('KIMS Hyderabad','TLA-KIM-52','decapper_recapper','central_lab','2026-06-28',
     true,null,null,true,true,true,'misaligned','not_applicable',true,true,'conditional_pass','Decapper cap alignment drift — gripper adjust due'),
    ('Yashoda Hyderabad','TLA-YSH-61','aliquoter','central_lab','2026-06-27',
     true,0.5,99.3,true,true,true,'ok','not_applicable',true,true,'pass','Aliquoter QC nominal'),
    ('Kokilaben Mumbai','TLA-KKB-71','sample_sorter','central_lab','2026-06-27',
     false,4.2,92.0,false,false,false,'fail','not_applicable',false,false,'removed_from_service','Sample sorter multiple failures across routing, barcode, jams, LIS — removed')
  ) as q(hosp, ucode, stype, sect, cdate, thru, rerr, brate, jam, stat, lis, decap, centbal, pm, calcur, qv, nt);

  insert into public.lab_automation_qc_capa_actions_r3394 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TLA-FRT-12','decap_recap_failure','gripper_wear','replace_gripper','in_progress','iso_15189_deviation','2026-07-06',null,32000.00,'Decapper gripper replacement; jam clearance after'),
    ('TLA-MNP-21','stat_routing_failure','software_config_error','update_software_config','open','turnaround_time_breach','2026-07-05',null,8000.00,'STAT routing rule reconfigured; recalibrate and PM'),
    ('TLA-AIM-32','lis_connectivity_loss','network_fault','repair_network','escalated','turnaround_time_breach','2026-07-04',null,15000.00,'Connection bridge LIS link down — escalated to IT+OEM'),
    ('TLA-KKB-71','routing_error','sensor_misalignment','realign_sensors','closed','nabl_finding','2026-07-02','2026-06-28',45000.00,'Sorter removed; sensors realigned, scanner replaced, revalidated'),
    ('TLA-FRT-11','centrifuge_imbalance','mechanical_wear','schedule_oem_service','verification_pending','internal_only','2026-07-05',null,26000.00,'Centrifuge module bearing service — verify balance'),
    ('TLA-CMC-42','calibration_overdue','preventive_service_backlog','recalibrate','overdue','internal_only','2026-06-30',null,5000.00,'Storage module calibration past target — vendor delay'),
    ('TLA-KIM-52','decap_recap_failure','gripper_wear','replace_gripper','open','none','2026-07-07',null,12000.00,'Decapper gripper alignment adjustment scheduled')
  ) as q(ucode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.lab_automation_qc_r3394 e
    on e.organization_id = v_org_id and e.unit_code = q.ucode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3394_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lab_automation_qc_r3394)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.lab_automation_qc_r3394 l group by l.qc_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3394_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3394_qc_verdict_rollup() to authenticated;

create or replace function public.founder_r3394_hospital_scorecard()
returns table(
  hospital_name text, total_checks bigint, passed bigint, conditional bigint, failed bigint,
  routing_issue bigint, lis_issue bigint, calibration_overdue bigint, pass_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.sample_routing_accuracy_error_pct > 1.0)::bigint,
    count(*) filter (where l.connectivity_lis_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.lab_automation_qc_r3394 l group by l.hospital_name order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3394_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3394_hospital_scorecard() to authenticated;

create or replace function public.founder_r3394_system_section_matrix()
returns table(system_type text, lab_section text, checks bigint, passed bigint, failed bigint, avg_barcode_rate numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_type, l.lab_section, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.barcode_read_rate_pct), 1)
  from public.lab_automation_qc_r3394 l group by l.system_type, l.lab_section order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3394_system_section_matrix() from public, anon;
grant execute on function public.founder_r3394_system_section_matrix() to authenticated;

create or replace function public.founder_r3394_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, routing_issue bigint, lis_issue bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.sample_routing_accuracy_error_pct > 1.0)::bigint,
    count(*) filter (where l.connectivity_lis_ok = false)::bigint
  from public.lab_automation_qc_r3394 l group by l.check_date order by l.check_date desc;
end;
$$;
revoke execute on function public.founder_r3394_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3394_daily_qc_trend() to authenticated;

create or replace function public.founder_r3394_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.lab_automation_qc_capa_actions_r3394 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3394_capa_status_board() from public, anon;
grant execute on function public.founder_r3394_capa_status_board() to authenticated;

create or replace function public.founder_r3394_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lab_automation_qc_capa_actions_r3394)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.lab_automation_qc_capa_actions_r3394 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3394_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3394_root_cause_pareto() to authenticated;

create or replace function public.founder_r3394_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.lab_automation_qc_capa_actions_r3394 c group by c.regulatory_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3394_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3394_regulatory_impact_digest() to authenticated;

create or replace function public.founder_r3394_high_risk_queue()
returns table(
  hospital_name text, unit_code text, system_type text, lab_section text, check_date date,
  qc_verdict text, decap_recap_ok text, centrifuge_balance_ok text, barcode_read_rate_pct numeric, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.unit_code, l.system_type, l.lab_section, l.check_date,
    l.qc_verdict, l.decap_recap_ok, l.centrifuge_balance_ok, l.barcode_read_rate_pct, l.notes
  from public.lab_automation_qc_r3394 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.throughput_ok = false
     or l.jam_rate_ok = false
     or l.stat_priority_routing_ok = false
     or l.connectivity_lis_ok = false
     or l.decap_recap_ok in ('misaligned','fail')
     or l.centrifuge_balance_ok in ('imbalance','fail')
     or l.calibration_current = false
     or l.preventive_maint_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;
revoke execute on function public.founder_r3394_high_risk_queue() from public, anon;
grant execute on function public.founder_r3394_high_risk_queue() to authenticated;
