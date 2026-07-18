-- Round 3156: Engineer Planned Preventive-Maintenance (PPM) Schedule Adherence & Backlog Tracker
-- PPM schedule log — equipment category × engineer × due/completed × days-late × adherence status × downtime risk × criticality × CAPA/backlog

-- =============================================================================
-- TABLE 1: ppm_schedule_r3156 — individual planned-maintenance schedule rows
-- =============================================================================
create table if not exists public.ppm_schedule_r3156 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  department text not null,
  equipment_category text not null check (equipment_category in (
    'ventilator','defibrillator','patient_monitor','anesthesia_machine','infusion_pump',
    'dialysis_machine','ct_scanner','mri_scanner','ultrasound_scanner','c_arm_xray',
    'autoclave_sterilizer','ecg_machine','surgical_diathermy','oxygen_concentrator'
  )),
  equipment_asset_tag text not null,
  equipment_model text not null,
  engineer_name text not null,
  ppm_frequency text not null check (ppm_frequency in (
    'weekly','monthly','quarterly','half_yearly','annual','biennial'
  )),
  scheduled_date date not null,
  due_date date not null,
  completed_date date,
  days_late int not null default 0,
  adherence_status text not null check (adherence_status in (
    'completed_on_time','completed_late','due_soon','overdue','skipped','in_progress','not_due'
  )),
  downtime_risk text not null check (downtime_risk in (
    'negligible','low','moderate','high','critical'
  )),
  criticality text not null check (criticality in (
    'life_support','high_risk','medium_risk','low_risk','non_critical'
  )),
  checklist_completion_pct numeric(5,2),
  amc_vendor text,
  created_at timestamptz not null default now()
);

alter table public.ppm_schedule_r3156 enable row level security;

create index if not exists idx_ppm_schedule_r3156_org on public.ppm_schedule_r3156(organization_id);
create index if not exists idx_ppm_schedule_r3156_due on public.ppm_schedule_r3156(due_date);
create index if not exists idx_ppm_schedule_r3156_adherence on public.ppm_schedule_r3156(adherence_status);

-- =============================================================================
-- TABLE 2: ppm_schedule_capa_actions_r3156 — backlog / CAPA & compliance actions
-- =============================================================================
create table if not exists public.ppm_schedule_capa_actions_r3156 (
  id uuid primary key default gen_random_uuid(),
  ppm_schedule_id uuid not null references public.ppm_schedule_r3156(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'ppm_overdue','ppm_skipped','spare_unavailable','engineer_unavailable','calibration_drift',
    'safety_test_fail','downtime_breach','documentation_gap','recurring_breakdown','amc_lapsed'
  )),
  root_cause text not null check (root_cause in (
    'engineer_shortage','spare_parts_delay','access_denied_clinical_load','budget_hold','vendor_sla_breach',
    'planning_error','tool_calibration_pending','training_gap','pending_investigation','amc_renewal_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'reschedule_ppm','expedite_spare_procurement','assign_backup_engineer','escalate_to_amc_vendor','recalibrate_instrument',
    'retrain_engineer','block_ot_slot_for_ppm','renew_amc_contract','none_required','add_to_capex_plan'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ppm_schedule_capa_actions_r3156 enable row level security;

create index if not exists idx_ppm_capa_r3156_sched on public.ppm_schedule_capa_actions_r3156(ppm_schedule_id);
create index if not exists idx_ppm_capa_r3156_status on public.ppm_schedule_capa_actions_r3156(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only (per rule 8)
-- =============================================================================
do $$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 PPM schedule rows
  insert into public.ppm_schedule_r3156 (
    organization_id, hospital_name, department, equipment_category, equipment_asset_tag, equipment_model,
    engineer_name, ppm_frequency, scheduled_date, due_date, completed_date, days_late,
    adherence_status, downtime_risk, criticality, checklist_completion_pct, amc_vendor
  )
  select v_org_id, q.hosp, q.dept, q.cat, q.tag, q.model,
    q.eng, q.freq, q.sd::date, q.dd::date, q.cmp::date, q.dl,
    q.adh, q.risk, q.crit, q.pct, q.amc
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU','ventilator','PPM-APL-VEN-01','Hamilton C6',
     'Ravi Teja','monthly','2026-06-15','2026-06-20','2026-06-18',0,
     'completed_on_time','high','life_support',100.00,'Hamilton Medical AMC'),
    ('Apollo Hyderabad Jubilee Hills','Cath Lab','c_arm_xray','PPM-APL-CAR-02','Siemens Cios Alpha',
     'Ravi Teja','quarterly','2026-05-10','2026-05-20','2026-05-28',8,
     'completed_late','moderate','high_risk',95.00,'Siemens Healthineers'),
    ('Fortis Bannerghatta Bengaluru','Dialysis','dialysis_machine','PPM-FRT-DIA-03','Fresenius 5008S',
     'Karthik Nair','monthly','2026-06-25','2026-07-01',null,17,
     'overdue','high','high_risk',null,'Fresenius Medical AMC'),
    ('Fortis Bannerghatta Bengaluru','OT','anesthesia_machine','PPM-FRT-ANE-04','Drager Fabius Plus',
     'Karthik Nair','quarterly','2026-07-05','2026-07-22',null,0,
     'due_soon','moderate','life_support',null,'Drager India AMC'),
    ('Manipal Whitefield Bengaluru','NICU','patient_monitor','PPM-MNP-MON-05','Philips IntelliVue MX550',
     'Sneha Rao','quarterly','2026-06-01','2026-06-10','2026-06-09',0,
     'completed_on_time','low','high_risk',100.00,'Philips Healthcare AMC'),
    ('Manipal Whitefield Bengaluru','Radiology','ct_scanner','PPM-MNP-CT-06','GE Revolution EVO',
     'Sneha Rao','half_yearly','2026-04-15','2026-04-30',null,79,
     'overdue','critical','high_risk',null,'GE Healthcare — spare delay'),
    ('AIIMS New Delhi Ansari Nagar','MRI Suite','mri_scanner','PPM-AIM-MRI-07','Siemens Magnetom Vida',
     'Amit Kumar','half_yearly','2026-06-01','2026-06-15','2026-06-14',0,
     'completed_on_time','high','high_risk',98.00,'Siemens Healthineers'),
    ('AIIMS New Delhi Ansari Nagar','Emergency','defibrillator','PPM-AIM-DEF-08','Zoll R Series',
     'Amit Kumar','monthly','2026-06-20','2026-06-25','2026-07-02',7,
     'completed_late','high','life_support',90.00,'Zoll India AMC'),
    ('KIMS Secunderabad','ICU','infusion_pump','PPM-KIM-INF-09','BBraun Infusomat Space',
     'Priya Menon','quarterly','2026-05-20','2026-05-30',null,0,
     'skipped','low','medium_risk',null,'BBraun AMC — unit condemned'),
    ('KIMS Secunderabad','CSSD','autoclave_sterilizer','PPM-KIM-AUT-10','Tuttnauer 5075HSG',
     'Priya Menon','monthly','2026-06-28','2026-07-03',null,15,
     'overdue','moderate','medium_risk',null,'Tuttnauer AMC'),
    ('Care Hospitals Banjara Hills','CCU','ecg_machine','PPM-CAR-ECG-11','BPL Cardiart 9108',
     'Vikram Shah','half_yearly','2026-06-05','2026-06-20','2026-06-19',0,
     'completed_on_time','negligible','low_risk',100.00,'BPL Medical AMC'),
    ('Yashoda Somajiguda Hyderabad','OT','surgical_diathermy','PPM-YSH-SDT-12','Valleylab Force FX',
     'Deepak Reddy','quarterly','2026-06-10','2026-06-18','2026-06-24',6,
     'completed_late','moderate','high_risk',92.00,'Medtronic India AMC'),
    ('St John''s Bengaluru','Ward','oxygen_concentrator','PPM-STJ-OXY-13','Philips EverFlo',
     'Meera Iyer','monthly','2026-07-08','2026-07-20',null,0,
     'due_soon','low','medium_risk',null,'Philips Healthcare AMC'),
    ('Rainbow Children''s Hyderabad','PICU','ultrasound_scanner','PPM-RBW-USG-14','GE Vivid S60',
     'Anand Pillai','quarterly','2026-05-15','2026-05-25',null,54,
     'overdue','high','high_risk',null,'GE Healthcare — backlog'),
    ('Rainbow Children''s Hyderabad','NICU','infusion_pump','PPM-RBW-INF-15','BBraun Perfusor Space',
     'Anand Pillai','quarterly','2026-07-01','2026-07-16',null,0,
     'in_progress','moderate','medium_risk',40.00,'BBraun AMC')
  ) as q(hosp, dept, cat, tag, model, eng, freq, sd, dd, cmp, dl, adh, risk, crit, pct, amc);

  -- CAPA / backlog seed — attach to specific schedule rows via asset tag
  insert into public.ppm_schedule_capa_actions_r3156 (
    ppm_schedule_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('PPM-FRT-DIA-03','ppm_overdue','engineer_shortage','assign_backup_engineer','2026-07-08',null,'in_progress','nabh_finding',25000.00,'Dialysis PPM 17 days overdue — backup engineer assigned'),
    ('PPM-MNP-CT-06','ppm_overdue','spare_parts_delay','expedite_spare_procurement','2026-05-10',null,'overdue','patient_safety_alert',180000.00,'CT tube PM 79 days overdue — imaging downtime risk to oncology'),
    ('PPM-KIM-INF-09','ppm_skipped','budget_hold','add_to_capex_plan','2026-06-15','2026-06-12','closed','internal_only',0.00,'Pump condemned — removed from PPM roster, capex replacement raised'),
    ('PPM-KIM-AUT-10','ppm_overdue','access_denied_clinical_load','block_ot_slot_for_ppm','2026-07-10',null,'open','iso_13485_deviation',8000.00,'CSSD clinical load blocks autoclave PM window — OT slot to be blocked'),
    ('PPM-RBW-USG-14','recurring_breakdown','vendor_sla_breach','escalate_to_amc_vendor','2026-06-05',null,'escalated','nabh_finding',45000.00,'USG PM backlog 54 days plus repeat faults — vendor SLA breach escalated'),
    ('PPM-APL-CAR-02','calibration_drift','tool_calibration_pending','recalibrate_instrument','2026-06-05','2026-06-01','closed','cdsco_notifiable',15000.00,'C-arm dose calibration corrected during late PM, dosimeter revalidated')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.ppm_schedule_r3156 e
    on e.organization_id = v_org_id and e.equipment_asset_tag = q.tag_key;
end;
$$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Adherence status distribution
create or replace function public.founder_r3156_adherence_status_rollup()
returns table(adherence_status text, schedules bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ppm_schedule_r3156)
  select l.adherence_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ppm_schedule_r3156 l
  group by l.adherence_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3156_adherence_status_rollup() from public, anon;
grant execute on function public.founder_r3156_adherence_status_rollup() to authenticated;

-- 2) Hospital-level adherence scorecard
create or replace function public.founder_r3156_hospital_scorecard()
returns table(
  hospital_name text,
  total_ppm bigint,
  on_time bigint,
  late bigint,
  overdue bigint,
  skipped bigint,
  avg_days_late numeric,
  adherence_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.adherence_status = 'completed_on_time')::bigint,
    count(*) filter (where l.adherence_status = 'completed_late')::bigint,
    count(*) filter (where l.adherence_status = 'overdue')::bigint,
    count(*) filter (where l.adherence_status = 'skipped')::bigint,
    round(avg(l.days_late)::numeric, 1),
    round(100.0 * count(*) filter (where l.adherence_status = 'completed_on_time')::numeric / nullif(count(*),0), 1)
  from public.ppm_schedule_r3156 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3156_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3156_hospital_scorecard() to authenticated;

-- 3) Equipment category × frequency matrix
create or replace function public.founder_r3156_category_matrix()
returns table(equipment_category text, ppm_frequency text, schedules bigint, overdue_or_skipped bigint, avg_days_late numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_category, l.ppm_frequency, count(*)::bigint,
    count(*) filter (where l.adherence_status in ('overdue','skipped'))::bigint,
    round(avg(l.days_late)::numeric, 1)
  from public.ppm_schedule_r3156 l
  group by l.equipment_category, l.ppm_frequency
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3156_category_matrix() from public, anon;
grant execute on function public.founder_r3156_category_matrix() to authenticated;

-- 4) Due-date adherence trend
create or replace function public.founder_r3156_due_date_trend()
returns table(due_date date, scheduled bigint, on_time bigint, late bigint, overdue bigint, skipped bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.due_date,
    count(*)::bigint,
    count(*) filter (where l.adherence_status = 'completed_on_time')::bigint,
    count(*) filter (where l.adherence_status = 'completed_late')::bigint,
    count(*) filter (where l.adherence_status = 'overdue')::bigint,
    count(*) filter (where l.adherence_status = 'skipped')::bigint
  from public.ppm_schedule_r3156 l
  group by l.due_date
  order by l.due_date desc;
end;
$$;

revoke execute on function public.founder_r3156_due_date_trend() from public, anon;
grant execute on function public.founder_r3156_due_date_trend() to authenticated;

-- 5) CAPA / backlog status board
create or replace function public.founder_r3156_capa_status_board()
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
  from public.ppm_schedule_capa_actions_r3156 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3156_capa_status_board() from public, anon;
grant execute on function public.founder_r3156_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3156_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ppm_schedule_capa_actions_r3156)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ppm_schedule_capa_actions_r3156 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3156_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3156_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3156_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.ppm_schedule_capa_actions_r3156 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3156_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3156_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority backlog queue
create or replace function public.founder_r3156_priority_backlog_queue()
returns table(
  hospital_name text,
  department text,
  equipment_category text,
  equipment_asset_tag text,
  due_date date,
  adherence_status text,
  days_late int,
  downtime_risk text,
  criticality text,
  amc_vendor text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.department, l.equipment_category, l.equipment_asset_tag, l.due_date,
    l.adherence_status, l.days_late, l.downtime_risk, l.criticality, l.amc_vendor
  from public.ppm_schedule_r3156 l
  where l.adherence_status in ('overdue','skipped','due_soon','in_progress')
     or l.downtime_risk in ('high','critical')
     or l.criticality in ('life_support','high_risk')
  order by l.days_late desc, l.due_date;
end;
$$;

revoke execute on function public.founder_r3156_priority_backlog_queue() from public, anon;
grant execute on function public.founder_r3156_priority_backlog_queue() to authenticated;
