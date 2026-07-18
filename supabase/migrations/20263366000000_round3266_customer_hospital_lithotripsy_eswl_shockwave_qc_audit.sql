-- Round 3266: Customer Hospital Lithotripsy (ESWL) Shockwave QC Audit
-- Lithotripsy QA — shock-source type × energy-output error × focal accuracy × source life × coupling membrane × X-ray/US localization × water degassing × ECG-gating × safety interlock × CAPA

-- =============================================================================
-- TABLE 1: lithotripsy_qc_r3266 — per-device ESWL shockwave QC checks
-- =============================================================================
create table if not exists public.lithotripsy_qc_r3266 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  shock_source_type text not null check (shock_source_type in (
    'electrohydraulic','electromagnetic','piezoelectric'
  )),
  department text not null,
  check_date date not null,
  shocks_since_source_change int not null,
  source_life_remaining_pct numeric(5,2),
  energy_output_error_pct numeric(5,2),
  focal_accuracy_mm numeric(4,2),
  coupling_membrane_condition text not null check (coupling_membrane_condition in (
    'good','worn','leak_detected','replace_due'
  )),
  xray_or_us_localization_ok boolean not null,
  water_degassing_ok boolean not null,
  ecg_gating_test text not null check (ecg_gating_test in (
    'pass','fail','not_applicable'
  )),
  safety_interlock_ok boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lithotripsy_qc_r3266 enable row level security;

create index if not exists idx_lithotripsy_qc_r3266_org on public.lithotripsy_qc_r3266(organization_id);
create index if not exists idx_lithotripsy_qc_r3266_date on public.lithotripsy_qc_r3266(check_date);
create index if not exists idx_lithotripsy_qc_r3266_verdict on public.lithotripsy_qc_r3266(qc_verdict);

-- =============================================================================
-- TABLE 2: lithotripsy_qc_capa_actions_r3266 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.lithotripsy_qc_capa_actions_r3266 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.lithotripsy_qc_r3266(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'energy_output_deviation','focal_accuracy_deviation','shock_source_end_of_life','coupling_membrane_fault',
    'localization_failure','water_degassing_failure','ecg_gating_failure','safety_interlock_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'shock_source_electrode_wear','source_end_of_life','coupling_membrane_perforation','water_system_degasser_fault',
    'localization_calibration_drift','ecg_gating_cable_fault','interlock_switch_fault','software_config_error',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_shock_source','replace_electrode','replace_coupling_membrane','service_water_degasser',
    'recalibrate_localization','replace_ecg_gating_cable','repair_safety_interlock','update_software_config',
    'retrain_lithotripsy_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','aerb_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lithotripsy_qc_capa_actions_r3266 enable row level security;

create index if not exists idx_lithotripsy_capa_r3266_log on public.lithotripsy_qc_capa_actions_r3266(qc_log_id);
create index if not exists idx_lithotripsy_capa_r3266_status on public.lithotripsy_qc_capa_actions_r3266(capa_status);

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

  -- 14 ESWL QC rows
  insert into public.lithotripsy_qc_r3266 (
    organization_id, hospital_name, device_code, shock_source_type, department, check_date,
    shocks_since_source_change, source_life_remaining_pct, energy_output_error_pct, focal_accuracy_mm,
    coupling_membrane_condition, xray_or_us_localization_ok, water_degassing_ok, ecg_gating_test,
    safety_interlock_ok, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dev, q.sst, q.dept, q.cd::date,
    q.ssc, q.slr, q.eoe, q.fac,
    q.cmc, q.xul, q.wdg, q.egt,
    q.sio, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','LT-APL-01','electrohydraulic','Urology','2026-07-02',
     45230,22.50,3.40,1.20,'good',true,true,'pass',true,'pass','Quarterly QC nominal; electrode at 22% life — swap planned next cycle'),
    ('Apollo Chennai Greams Road','LT-APL-02','electromagnetic','Lithotripsy Unit','2026-07-02',
     210000,8.00,9.50,2.40,'worn',true,true,'pass',true,'conditional_pass','Energy output 9.5% over tolerance and source at 8% life — recheck booked'),
    ('Fortis Gurgaon','LT-FRT-11','piezoelectric','Urology','2026-07-01',
     1200000,65.00,1.80,0.80,'good',true,true,'not_applicable',true,'pass','Piezo source healthy; ultrasound localization only'),
    ('Fortis Gurgaon','LT-FRT-12','electrohydraulic','Day Care Surgery','2026-07-01',
     78000,3.00,12.60,3.60,'leak_detected',true,false,'pass',true,'fail','Coupling membrane leak, energy 12.6% off and water degasser fault'),
    ('Manipal Bengaluru Old Airport Road','LT-MNP-21','electromagnetic','Nephrology','2026-06-30',
     95000,41.00,2.10,1.00,'good',true,true,'pass',true,'pass','Annual QC clean pass'),
    ('Manipal Bengaluru Old Airport Road','LT-MNP-22','electrohydraulic','Urology','2026-06-30',
     60000,15.50,4.20,1.90,'worn',true,true,'fail',true,'conditional_pass','ECG-gating dropped 3 of 20 test beats — cable check due'),
    ('AIIMS Delhi Ansari Nagar','LT-AIM-31','electromagnetic','Lithotripsy Unit','2026-06-29',
     260000,2.00,8.80,2.70,'replace_due',false,true,'pass',true,'fail','Source end-of-life, X-ray localization out and membrane replace due'),
    ('AIIMS Delhi Ansari Nagar','LT-AIM-32','piezoelectric','Urology','2026-06-29',
     900000,58.00,1.20,0.70,'good',true,true,'not_applicable',true,'pass','Routine QC pass'),
    ('CMC Vellore','LT-CMC-41','electrohydraulic','Urology','2026-06-28',
     88000,6.50,7.40,2.20,'worn',true,true,'pass',false,'removed_from_service','Safety interlock failed door test — unit locked out of service'),
    ('CMC Vellore','LT-CMC-42','electromagnetic','Nephrology','2026-06-28',
     140000,33.00,2.90,1.10,'good',true,true,'pass',true,'pass','Post-AMC verification pass'),
    ('KIMS Hyderabad','LT-KIM-51','piezoelectric','Day Care Surgery','2026-06-27',
     1500000,12.00,5.60,1.60,'worn',true,true,'not_applicable',true,'conditional_pass','Focal drift 1.6mm and energy 5.6% over — monitor next cycle'),
    ('KIMS Hyderabad','LT-KIM-52','electrohydraulic','Urology','2026-06-27',
     51000,28.00,3.10,1.30,'good',true,true,'pass',true,'pass','Electrode swapped last month — nominal QC'),
    ('Yashoda Somajiguda Hyderabad','LT-YSH-61','electromagnetic','Lithotripsy Unit','2026-06-26',
     175000,0.00,null,null,'replace_due',false,false,'fail',false,'removed_from_service','Multiple failures — QC aborted, source depleted, unit withdrawn'),
    ('Rainbow Children''s Hyderabad','LT-RBW-71','piezoelectric','Urology','2026-06-26',
     640000,72.00,1.50,0.90,'good',true,true,'not_applicable',true,'pass','Paediatric-capable unit; ultrasound localization verified')
  ) as q(hosp, dev, sst, dept, cd, ssc, slr, eoe, fac, cmc, xul, wdg, egt, sio, qv, nt);

  -- CAPA seed — attach to specific devices via device_code
  insert into public.lithotripsy_qc_capa_actions_r3266 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('LT-APL-02','energy_output_deviation','source_end_of_life','replace_shock_source','in_progress','cdsco_notifiable','2026-07-10',null,1450000.00,'Electromagnetic shock source RFQ raised with OEM'),
    ('LT-FRT-12','coupling_membrane_fault','coupling_membrane_perforation','replace_coupling_membrane','open','patient_safety_alert','2026-07-06',null,85000.00,'Membrane leak — coupling-loss patient-safety risk; unit held'),
    ('LT-AIM-31','shock_source_end_of_life','source_end_of_life','replace_shock_source','escalated','aerb_notifiable','2026-07-05',null,1650000.00,'Source depleted and X-ray localization out — AERB radiation-safety loop'),
    ('LT-MNP-22','ecg_gating_failure','ecg_gating_cable_fault','replace_ecg_gating_cable','closed','internal_only','2026-07-02','2026-06-30',7500.00,'Gating cable replaced, retest 20 of 20 beats'),
    ('LT-CMC-41','safety_interlock_failure','interlock_switch_fault','repair_safety_interlock','verification_pending','iso_13485_deviation','2026-07-04',null,32000.00,'Door interlock switch replaced — awaiting witnessed re-test'),
    ('LT-YSH-61','shock_source_end_of_life','source_end_of_life','remove_from_service','overdue','nabh_finding','2026-06-24',null,1580000.00,'Source depleted plus degasser and gating fail — withdrawal past target date'),
    ('LT-KIM-51','focal_accuracy_deviation','localization_calibration_drift','recalibrate_localization','open','internal_only','2026-07-09',null,22000.00,'Focal drift 1.6mm — schedule localization recalibration')
  ) as q(dev, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.lithotripsy_qc_r3266 e
    on e.organization_id = v_org_id and e.device_code = q.dev;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3266_qc_verdict_rollup()
returns table(qc_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lithotripsy_qc_r3266)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.lithotripsy_qc_r3266 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3266_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3266_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3266_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  membrane_issue bigint,
  localization_fail bigint,
  interlock_fail bigint,
  pass_pct numeric
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
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.coupling_membrane_condition in ('worn','leak_detected','replace_due'))::bigint,
    count(*) filter (where l.xray_or_us_localization_ok = false)::bigint,
    count(*) filter (where l.safety_interlock_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.lithotripsy_qc_r3266 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3266_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3266_hospital_scorecard() to authenticated;

-- 3) Shock-source type × department matrix
create or replace function public.founder_r3266_source_department_matrix()
returns table(shock_source_type text, department text, audits bigint, passed bigint, avg_energy_error_pct numeric, avg_focal_accuracy_mm numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.shock_source_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.energy_output_error_pct), 2),
    round(avg(l.focal_accuracy_mm), 2)
  from public.lithotripsy_qc_r3266 l
  group by l.shock_source_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3266_source_department_matrix() from public, anon;
grant execute on function public.founder_r3266_source_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3266_daily_qc_trend()
returns table(check_date date, audits bigint, passed bigint, failed bigint, membrane_issue bigint, source_low bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.coupling_membrane_condition in ('worn','leak_detected','replace_due'))::bigint,
    count(*) filter (where l.source_life_remaining_pct < 10)::bigint
  from public.lithotripsy_qc_r3266 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3266_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3266_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3266_capa_status_board()
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
  from public.lithotripsy_qc_capa_actions_r3266 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3266_capa_status_board() from public, anon;
grant execute on function public.founder_r3266_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3266_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lithotripsy_qc_capa_actions_r3266)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.lithotripsy_qc_capa_actions_r3266 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3266_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3266_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3266_regulatory_impact_digest()
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
  from public.lithotripsy_qc_capa_actions_r3266 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3266_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3266_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3266_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  shock_source_type text,
  check_date date,
  qc_verdict text,
  coupling_membrane_condition text,
  source_life_remaining_pct numeric,
  energy_output_error_pct numeric,
  focal_accuracy_mm numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.shock_source_type, l.check_date,
    l.qc_verdict, l.coupling_membrane_condition, l.source_life_remaining_pct,
    l.energy_output_error_pct, l.focal_accuracy_mm, l.notes
  from public.lithotripsy_qc_r3266 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.coupling_membrane_condition in ('leak_detected','replace_due')
     or l.source_life_remaining_pct < 10
     or l.xray_or_us_localization_ok = false
     or l.water_degassing_ok = false
     or l.ecg_gating_test = 'fail'
     or l.safety_interlock_ok = false
     or abs(l.energy_output_error_pct) > 5
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3266_high_risk_queue() from public, anon;
grant execute on function public.founder_r3266_high_risk_queue() to authenticated;
