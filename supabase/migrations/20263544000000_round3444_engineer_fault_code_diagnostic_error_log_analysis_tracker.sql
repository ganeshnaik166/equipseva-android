-- Round 3444: Engineer Device Fault-Code / Diagnostic Error-Log Analysis Tracker
-- Field-engineer device fault-code / diagnostic error-log capture, analysis & resolution tracker —
-- engineer × hospital × device model × fault code × severity × subsystem × occurrences × downtime × recurrence × CAPA

-- =============================================================================
-- TABLE 1: fault_code_errorlog_r3444 — per-fault diagnostic error-log entries
-- =============================================================================
create table if not exists public.fault_code_errorlog_r3444 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  log_ref text not null,
  engineer_name text not null,
  hospital_name text not null,
  device_model text not null,
  fault_code text not null,
  severity text not null check (severity in (
    'critical','major','minor','warning','info'
  )),
  subsystem text not null check (subsystem in (
    'power','imaging_chain','mechanical','software','sensor','network','cooling'
  )),
  occurrences int not null,
  first_seen date not null,
  last_seen date not null,
  resolution_status text not null check (resolution_status in (
    'open','diagnosed','part_ordered','resolved','recurring','no_fault_found'
  )),
  downtime_hours numeric(7,2),
  recurring_flag boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fault_code_errorlog_r3444 enable row level security;

create index if not exists idx_fault_code_errorlog_r3444_org on public.fault_code_errorlog_r3444(organization_id);
create index if not exists idx_fault_code_errorlog_r3444_last on public.fault_code_errorlog_r3444(last_seen);
create index if not exists idx_fault_code_errorlog_r3444_status on public.fault_code_errorlog_r3444(resolution_status);

-- =============================================================================
-- TABLE 2: fault_code_errorlog_capa_actions_r3444 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.fault_code_errorlog_capa_actions_r3444 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  fault_log_id uuid not null references public.fault_code_errorlog_r3444(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'recurring_fault','high_downtime','safety_critical_fault','unresolved_open_fault',
    'part_availability','no_fault_found_repeat','firmware_defect','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'component_end_of_life','power_supply_fault','firmware_bug','sensor_drift',
    'thermal_management_fault','connector_cable_fault','network_config_error',
    'operator_error','pending_investigation','environmental_condition'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_component','replace_power_supply','apply_firmware_update','recalibrate_sensor',
    'service_cooling_system','replace_cable','reconfigure_network','retrain_operator',
    'escalate_to_oem','monitor_no_action','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','nabh_finding','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fault_code_errorlog_capa_actions_r3444 enable row level security;

create index if not exists idx_fault_code_errorlog_capa_r3444_log on public.fault_code_errorlog_capa_actions_r3444(fault_log_id);
create index if not exists idx_fault_code_errorlog_capa_r3444_status on public.fault_code_errorlog_capa_actions_r3444(capa_status);

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

  -- 16 fault-code error-log rows
  insert into public.fault_code_errorlog_r3444 (
    organization_id, log_ref, engineer_name, hospital_name, device_model, fault_code,
    severity, subsystem, occurrences, first_seen, last_seen,
    resolution_status, downtime_hours, recurring_flag, notes
  )
  select v_org_id, q.lref, q.eng, q.hosp, q.model, q.fcode,
    q.sev, q.sub, q.occ, q.fs::date, q.ls::date,
    q.rstat, q.dt, q.rec, q.nt
  from (values
    ('FLT-APL-01','Ravi Kumar','Apollo Chennai','GE Optima CT660','E-1024',
     'critical','imaging_chain',7,'2026-06-10','2026-07-20','recurring',36.5,true,'Detector channel dropout recurring on CT — image artifacts'),
    ('FLT-APL-02','Ravi Kumar','Apollo Chennai','Siemens Magnetom Aera','C-2201',
     'major','cooling',3,'2026-06-15','2026-07-18','part_ordered',12.0,false,'Helium compressor cooling fault — chiller part ordered'),
    ('FLT-FRT-11','Anita Desai','Fortis Gurgaon','Philips Ingenuity CT','P-330',
     'major','power',4,'2026-06-20','2026-07-19','diagnosed',8.5,false,'Gantry power supply intermittent brownout during scan'),
    ('FLT-FRT-12','Anita Desai','Fortis Gurgaon','Mindray SV300 Ventilator','V-115',
     'critical','sensor',5,'2026-06-22','2026-07-21','open',6.0,true,'O2 flow sensor drift recurring — ICU ventilator'),
    ('FLT-MNP-21','Suresh Nair','Manipal Bengaluru','GE Carescape B650','M-909',
     'minor','software',2,'2026-06-25','2026-07-10','resolved',1.5,false,'Monitor firmware freeze on trend recall — patched'),
    ('FLT-MNP-22','Suresh Nair','Manipal Bengaluru','Siemens Ysio Max','X-540',
     'warning','mechanical',3,'2026-06-28','2026-07-15','diagnosed',4.0,false,'X-ray tube arm detent worn — mechanical play'),
    ('FLT-AIM-31','Pooja Sharma','AIIMS Delhi','Philips Azurion 7','A-770',
     'critical','imaging_chain',6,'2026-06-12','2026-07-22','recurring',28.0,true,'Cath lab flat-panel calibration fault recurring'),
    ('FLT-AIM-32','Pooja Sharma','AIIMS Delhi','Drager Fabius Plus','D-208',
     'major','mechanical',2,'2026-07-01','2026-07-14','part_ordered',5.5,false,'Anesthesia ventilator bellows leak — seal kit ordered'),
    ('FLT-CMC-41','George Mathew','CMC Vellore','GE Voluson E10','U-410',
     'minor','sensor',1,'2026-07-02','2026-07-12','resolved',0.5,false,'Ultrasound probe element noise — probe swapped'),
    ('FLT-CMC-42','George Mathew','CMC Vellore','Mindray BeneVision N22','M-220',
     'warning','network',2,'2026-07-03','2026-07-16','diagnosed',2.0,false,'Central station network packet loss — switch config'),
    ('FLT-KIM-51','Lakshmi Rao','KIMS Hyderabad','Siemens Somatom go.Top','C-2260',
     'critical','power',4,'2026-06-18','2026-07-20','open',14.5,true,'CT high-voltage generator trips recurring under load'),
    ('FLT-KIM-52','Lakshmi Rao','KIMS Hyderabad','Philips Efficia CM100','M-101',
     'info','software',1,'2026-07-05','2026-07-11','no_fault_found',0.0,false,'Monitor reboot report — no fault reproduced'),
    ('FLT-YSH-61','Arjun Menon','Yashoda Hyderabad','GE Discovery IQ PET','N-615',
     'major','cooling',3,'2026-06-27','2026-07-17','part_ordered',9.0,false,'PET detector cooling loop temperature high — pump ordered'),
    ('FLT-YSH-62','Arjun Menon','Yashoda Hyderabad','Drager Evita V500','V-500',
     'major','sensor',4,'2026-07-04','2026-07-19','diagnosed',7.5,true,'Ventilator flow sensor calibration recurring alarm'),
    ('FLT-KKB-71','Neha Iyer','Kokilaben Mumbai','Siemens Artis Q','A-900',
     'critical','imaging_chain',8,'2026-06-08','2026-07-23','recurring',42.0,true,'Cath lab C-arm image intensifier fault severe recurring'),
    ('FLT-KKB-72','Neha Iyer','Kokilaben Mumbai','Philips Respironics V60','V-601',
     'minor','network',2,'2026-07-06','2026-07-13','resolved',1.0,false,'NIV network dropout — patched firmware, resolved')
  ) as q(lref, eng, hosp, model, fcode, sev, sub, occ, fs, ls, rstat, dt, rec, nt);

  -- CAPA seed — attach to specific fault logs via log_ref
  insert into public.fault_code_errorlog_capa_actions_r3444 (
    organization_id, fault_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FLT-APL-01','recurring_fault','component_end_of_life','replace_component','in_progress','iso_13485_deviation','Ravi Kumar','2026-07-30',null,185000.00,'CT detector module replacement scheduled with OEM'),
    ('FLT-KKB-71','safety_critical_fault','component_end_of_life','replace_component','escalated','patient_safety_alert','Neha Iyer','2026-07-28',null,240000.00,'Cath lab image intensifier severe recurring — escalated OEM'),
    ('FLT-FRT-12','recurring_fault','sensor_drift','recalibrate_sensor','open','nabh_finding','Anita Desai','2026-07-29',null,12000.00,'Ventilator O2 sensor drift — recalibrate then verify'),
    ('FLT-KIM-51','safety_critical_fault','power_supply_fault','replace_power_supply','escalated','cdsco_notifiable','Lakshmi Rao','2026-07-27',null,95000.00,'CT HV generator trips — power supply replacement escalated'),
    ('FLT-AIM-31','recurring_fault','firmware_bug','apply_firmware_update','verification_pending','iso_13485_deviation','Pooja Sharma','2026-07-26',null,0.00,'Azurion panel calibration firmware update applied — verifying'),
    ('FLT-MNP-21','firmware_defect','firmware_bug','apply_firmware_update','closed','internal_only','Suresh Nair','2026-07-12','2026-07-10',0.00,'Monitor firmware patch applied and closed'),
    ('FLT-YSH-61','part_availability','thermal_management_fault','service_cooling_system','open','none','Arjun Menon','2026-08-02',null,54000.00,'PET cooling pump on order — cooling loop service pending'),
    ('FLT-APL-02','high_downtime','thermal_management_fault','service_cooling_system','overdue','nabh_finding','Ravi Kumar','2026-07-22',null,68000.00,'MRI helium compressor chiller part delayed — overdue')
  ) as q(lref, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.fault_code_errorlog_r3444 e
    on e.organization_id = v_org_id and e.log_ref = q.lref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Resolution-status distribution
create or replace function public.founder_r3444_resolution_status_rollup()
returns table(resolution_status text, faults bigint, total_occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fault_code_errorlog_r3444)
  select l.resolution_status, count(*)::bigint,
         coalesce(sum(l.occurrences),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fault_code_errorlog_r3444 l
  group by l.resolution_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3444_resolution_status_rollup() from public, anon;
grant execute on function public.founder_r3444_resolution_status_rollup() to authenticated;

-- 2) Device-model scorecard
create or replace function public.founder_r3444_device_model_scorecard()
returns table(
  device_model text,
  total_faults bigint,
  open_faults bigint,
  resolved bigint,
  recurring bigint,
  critical bigint,
  total_occurrences bigint,
  total_downtime_hours numeric,
  resolved_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_model,
    count(*)::bigint,
    count(*) filter (where l.resolution_status in ('open','recurring','part_ordered','diagnosed'))::bigint,
    count(*) filter (where l.resolution_status = 'resolved')::bigint,
    count(*) filter (where l.resolution_status = 'recurring' or l.recurring_flag = true)::bigint,
    count(*) filter (where l.severity = 'critical')::bigint,
    coalesce(sum(l.occurrences),0)::bigint,
    round(coalesce(sum(l.downtime_hours),0)::numeric, 2),
    round(100.0 * count(*) filter (where l.resolution_status = 'resolved')::numeric / nullif(count(*),0), 1)
  from public.fault_code_errorlog_r3444 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3444_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3444_device_model_scorecard() to authenticated;

-- 3) Subsystem × severity matrix
create or replace function public.founder_r3444_subsystem_severity_matrix()
returns table(subsystem text, severity text, faults bigint, total_occurrences bigint, total_downtime_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.subsystem, l.severity, count(*)::bigint,
    coalesce(sum(l.occurrences),0)::bigint,
    round(coalesce(sum(l.downtime_hours),0)::numeric, 2)
  from public.fault_code_errorlog_r3444 l
  group by l.subsystem, l.severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3444_subsystem_severity_matrix() from public, anon;
grant execute on function public.founder_r3444_subsystem_severity_matrix() to authenticated;

-- 4) Monthly fault trend
create or replace function public.founder_r3444_monthly_fault_trend()
returns table(fault_month date, faults bigint, total_occurrences bigint, resolved bigint, recurring bigint, total_downtime_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.last_seen)::date,
    count(*)::bigint,
    coalesce(sum(l.occurrences),0)::bigint,
    count(*) filter (where l.resolution_status = 'resolved')::bigint,
    count(*) filter (where l.resolution_status = 'recurring' or l.recurring_flag = true)::bigint,
    round(coalesce(sum(l.downtime_hours),0)::numeric, 2)
  from public.fault_code_errorlog_r3444 l
  group by date_trunc('month', l.last_seen)
  order by date_trunc('month', l.last_seen) desc;
end;
$$;

revoke execute on function public.founder_r3444_monthly_fault_trend() from public, anon;
grant execute on function public.founder_r3444_monthly_fault_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3444_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.fault_code_errorlog_capa_actions_r3444 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3444_capa_status_board() from public, anon;
grant execute on function public.founder_r3444_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3444_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fault_code_errorlog_capa_actions_r3444)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fault_code_errorlog_capa_actions_r3444 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3444_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3444_root_cause_pareto() to authenticated;

-- 7) Downtime-impact digest (by subsystem)
create or replace function public.founder_r3444_downtime_impact_digest()
returns table(
  subsystem text,
  faults bigint,
  total_occurrences bigint,
  total_downtime_hours numeric,
  avg_downtime_hours numeric,
  recurring_faults bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.subsystem,
    count(*)::bigint,
    coalesce(sum(l.occurrences),0)::bigint,
    round(coalesce(sum(l.downtime_hours),0)::numeric, 2),
    round(avg(l.downtime_hours)::numeric, 2),
    count(*) filter (where l.resolution_status = 'recurring' or l.recurring_flag = true)::bigint
  from public.fault_code_errorlog_r3444 l
  group by l.subsystem
  order by round(coalesce(sum(l.downtime_hours),0)::numeric, 2) desc;
end;
$$;

revoke execute on function public.founder_r3444_downtime_impact_digest() from public, anon;
grant execute on function public.founder_r3444_downtime_impact_digest() to authenticated;

-- 8) High-risk fault queue (critical / recurring / high-downtime / unresolved)
create or replace function public.founder_r3444_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  device_model text,
  fault_code text,
  severity text,
  subsystem text,
  occurrences int,
  last_seen date,
  resolution_status text,
  downtime_hours numeric,
  recurring_flag boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.device_model, l.fault_code, l.severity,
    l.subsystem, l.occurrences, l.last_seen, l.resolution_status, l.downtime_hours,
    l.recurring_flag, l.notes
  from public.fault_code_errorlog_r3444 l
  where l.severity in ('critical','major')
     or l.recurring_flag = true
     or l.resolution_status in ('open','recurring','part_ordered')
     or coalesce(l.downtime_hours,0) >= 10
  order by
    case when l.severity = 'critical' then 0 when l.severity = 'major' then 1 else 2 end,
    coalesce(l.downtime_hours,0) desc,
    l.last_seen desc;
end;
$$;

revoke execute on function public.founder_r3444_high_risk_queue() from public, anon;
grant execute on function public.founder_r3444_high_risk_queue() to authenticated;
