-- Round 3410: Customer Hospital Viscoelastic (TEG/ROTEM) & ACT POCT QC Audit
-- OT/ICU bleeding-management POCT QA — device type × location × control level × channel temperature × pipetting accuracy × cartridge/reagent lot × CV% × LIS connectivity × operator competency × calibration × CAPA

-- =============================================================================
-- TABLE 1: viscoelastic_poct_qc_r3410 — per-device viscoelastic/ACT POCT QC checks
-- =============================================================================
create table if not exists public.viscoelastic_poct_qc_r3410 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'teg_analyzer','rotem_analyzer','act_machine','platelet_mapping','cartridge_teg'
  )),
  location text not null check (location in (
    'cardiac_ot','trauma_icu','liver_transplant_ot','labor_delivery','general_icu'
  )),
  check_date date not null,
  internal_qc_pass boolean not null,
  control_level_result text not null check (control_level_result in (
    'level_1_normal','level_2_abnormal','fail','not_run'
  )),
  channel_temperature_ok boolean not null,
  pipetting_accuracy_ok boolean not null,
  cartridge_reagent_lot_ok boolean not null,
  cv_percent numeric(5,2),
  connectivity_lis_ok boolean not null,
  operator_competency_current boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.viscoelastic_poct_qc_r3410 enable row level security;

create index if not exists idx_viscoelastic_poct_qc_r3410_org on public.viscoelastic_poct_qc_r3410(organization_id);
create index if not exists idx_viscoelastic_poct_qc_r3410_date on public.viscoelastic_poct_qc_r3410(check_date);
create index if not exists idx_viscoelastic_poct_qc_r3410_verdict on public.viscoelastic_poct_qc_r3410(qc_verdict);

-- =============================================================================
-- TABLE 2: viscoelastic_poct_qc_capa_actions_r3410 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.viscoelastic_poct_qc_capa_actions_r3410 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.viscoelastic_poct_qc_r3410(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'internal_qc_out_of_range','control_level_failure','channel_temperature_out_of_range',
    'pipetting_accuracy_error','cartridge_reagent_lot_issue','cv_high_imprecision',
    'connectivity_lis_failure','operator_competency_lapsed','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'reagent_lot_degraded','pipettor_out_of_calibration','channel_heater_drift','cartridge_expired',
    'control_material_expired','software_config_error','operator_technique_error',
    'pending_investigation','preventive_service_backlog','lis_interface_fault'
  )),
  corrective_action text not null check (corrective_action in (
    'rerun_qc_with_fresh_control','replace_reagent_lot','recalibrate_pipettor','service_channel_heater',
    'replace_cartridge_lot','update_software_config','retrain_operator',
    'remove_from_service','schedule_oem_service','repair_lis_interface','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.viscoelastic_poct_qc_capa_actions_r3410 enable row level security;

create index if not exists idx_viscoelastic_poct_capa_r3410_log on public.viscoelastic_poct_qc_capa_actions_r3410(qc_log_id);
create index if not exists idx_viscoelastic_poct_capa_r3410_status on public.viscoelastic_poct_qc_capa_actions_r3410(capa_status);

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

  -- 14 QC check rows
  insert into public.viscoelastic_poct_qc_r3410 (
    organization_id, hospital_name, device_code, device_type, location, check_date,
    internal_qc_pass, control_level_result, channel_temperature_ok, pipetting_accuracy_ok,
    cartridge_reagent_lot_ok, cv_percent, connectivity_lis_ok, operator_competency_current,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.loc, q.cdate::date,
    q.iqc, q.ctrl, q.temp, q.pip,
    q.lot, q.cv, q.lis, q.comp,
    q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','TEG-APL-01','teg_analyzer','cardiac_ot','2026-07-05',
     true,'level_1_normal',true,true,true,2.4,true,true,true,'pass','Cardiac OT TEG daily QC within tolerance'),
    ('Apollo Chennai','ROTEM-APL-02','rotem_analyzer','cardiac_ot','2026-07-05',
     true,'level_2_abnormal',true,true,true,3.1,true,true,true,'pass','ROTEM both control levels in range'),
    ('Fortis Gurgaon','ACT-FRT-11','act_machine','cardiac_ot','2026-07-04',
     true,'level_1_normal',true,true,true,4.2,false,true,true,'conditional_pass','ACT QC pass but LIS connectivity down — manual entry'),
    ('Fortis Gurgaon','TEG-FRT-12','teg_analyzer','trauma_icu','2026-07-04',
     false,'fail',true,true,false,8.6,true,true,true,'fail','Internal QC fail, reagent lot out of spec, CV high'),
    ('Manipal Bengaluru','PMAP-MNP-21','platelet_mapping','cardiac_ot','2026-07-03',
     true,'level_2_abnormal',false,true,true,5.4,true,true,false,'conditional_pass','Platelet mapping channel temp drift and calibration overdue'),
    ('Manipal Bengaluru','CTEG-MNP-22','cartridge_teg','trauma_icu','2026-07-03',
     true,'level_1_normal',true,true,true,2.9,true,true,true,'pass','Cartridge TEG QC nominal'),
    ('AIIMS Delhi','ROTEM-AIM-31','rotem_analyzer','liver_transplant_ot','2026-07-02',
     true,'level_1_normal',true,false,true,6.1,true,true,true,'conditional_pass','Pipetting accuracy drift flagged, CV borderline'),
    ('AIIMS Delhi','ACT-AIM-32','act_machine','trauma_icu','2026-07-02',
     false,'fail',true,true,true,9.8,true,false,true,'fail','ACT internal QC fail and operator competency lapsed'),
    ('CMC Vellore','TEG-CMC-41','teg_analyzer','liver_transplant_ot','2026-07-01',
     true,'level_1_normal',true,true,true,3.3,true,true,true,'pass','Liver transplant TEG QC pass'),
    ('CMC Vellore','CTEG-CMC-42','cartridge_teg','labor_delivery','2026-07-01',
     true,'level_2_abnormal',true,true,false,5.9,true,true,false,'conditional_pass','Cartridge lot mismatch and calibration overdue — recheck'),
    ('KIMS Hyderabad','ROTEM-KIM-51','rotem_analyzer','cardiac_ot','2026-06-30',
     true,'level_1_normal',true,true,true,2.7,true,true,true,'pass','ROTEM QC pass post-service'),
    ('KIMS Hyderabad','PMAP-KIM-52','platelet_mapping','general_icu','2026-06-30',
     true,'level_2_abnormal',true,true,true,7.2,false,true,true,'conditional_pass','Platelet mapping CV elevated and LIS interface intermittent'),
    ('Yashoda Hyderabad','ACT-YSH-61','act_machine','labor_delivery','2026-06-29',
     true,'level_1_normal',true,true,true,3.8,true,true,true,'pass','ACT machine QC nominal'),
    ('Kokilaben Mumbai','TEG-KKB-71','teg_analyzer','cardiac_ot','2026-06-29',
     false,'not_run',false,false,false,12.5,false,false,false,'removed_from_service','Multiple QC failures, control not run, removed from service')
  ) as q(hosp, dcode, dtype, loc, cdate, iqc, ctrl, temp, pip, lot, cv, lis, comp, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.viscoelastic_poct_qc_capa_actions_r3410 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TEG-FRT-12','internal_qc_out_of_range','reagent_lot_degraded','replace_reagent_lot','in_progress','iso_15189_deviation','2026-07-08',null,18000.00,'Reagent lot quarantined; fresh lot QC pending verification'),
    ('ACT-AIM-32','operator_competency_lapsed','operator_technique_error','retrain_operator','open','nabh_finding','2026-07-09',null,6000.00,'Operator competency re-assessment scheduled'),
    ('PMAP-MNP-21','channel_temperature_out_of_range','channel_heater_drift','service_channel_heater','escalated','patient_safety_alert','2026-07-07',null,24000.00,'Channel heater drift on platelet mapping — OEM escalated'),
    ('TEG-KKB-71','control_level_failure','control_material_expired','remove_from_service','closed','cdsco_notifiable','2026-07-05','2026-06-30',52000.00,'Analyzer removed; expired controls replaced and revalidated'),
    ('CTEG-CMC-42','cartridge_reagent_lot_issue','cartridge_expired','replace_cartridge_lot','verification_pending','internal_only','2026-07-06',null,9500.00,'Expired cartridge lot swapped — verify next run'),
    ('ROTEM-AIM-31','pipetting_accuracy_error','pipettor_out_of_calibration','recalibrate_pipettor','overdue','internal_only','2026-07-04',null,7000.00,'Pipettor recalibration past target — vendor delay'),
    ('ACT-FRT-11','connectivity_lis_failure','lis_interface_fault','repair_lis_interface','open','none','2026-07-10',null,0.00,'LIS interface fault logged — IT ticket raised')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.viscoelastic_poct_qc_r3410 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3410_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.viscoelastic_poct_qc_r3410)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.viscoelastic_poct_qc_r3410 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3410_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3410_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3410_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  internal_qc_fail bigint,
  competency_lapsed bigint,
  calibration_overdue bigint,
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
    count(*) filter (where l.internal_qc_pass = false)::bigint,
    count(*) filter (where l.operator_competency_current = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.viscoelastic_poct_qc_r3410 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3410_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3410_hospital_scorecard() to authenticated;

-- 3) Device-type × location matrix
create or replace function public.founder_r3410_device_type_location_matrix()
returns table(device_type text, location text, checks bigint, passed bigint, failed bigint, avg_cv_percent numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.location, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.cv_percent), 2)
  from public.viscoelastic_poct_qc_r3410 l
  group by l.device_type, l.location
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3410_device_type_location_matrix() from public, anon;
grant execute on function public.founder_r3410_device_type_location_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3410_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, internal_qc_fail bigint, competency_lapsed bigint)
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
    count(*) filter (where l.internal_qc_pass = false)::bigint,
    count(*) filter (where l.operator_competency_current = false)::bigint
  from public.viscoelastic_poct_qc_r3410 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3410_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3410_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3410_capa_status_board()
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
  from public.viscoelastic_poct_qc_capa_actions_r3410 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3410_capa_status_board() from public, anon;
grant execute on function public.founder_r3410_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3410_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.viscoelastic_poct_qc_capa_actions_r3410)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.viscoelastic_poct_qc_capa_actions_r3410 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3410_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3410_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3410_regulatory_impact_digest()
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
  from public.viscoelastic_poct_qc_capa_actions_r3410 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3410_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3410_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3410_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  location text,
  check_date date,
  qc_verdict text,
  control_level_result text,
  cv_percent numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.location, l.check_date,
    l.qc_verdict, l.control_level_result, l.cv_percent, l.notes
  from public.viscoelastic_poct_qc_r3410 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.internal_qc_pass = false
     or l.control_level_result in ('fail','not_run')
     or l.channel_temperature_ok = false
     or l.pipetting_accuracy_ok = false
     or l.cartridge_reagent_lot_ok = false
     or l.connectivity_lis_ok = false
     or l.operator_competency_current = false
     or l.calibration_current = false
     or l.cv_percent >= 5.0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3410_high_risk_queue() from public, anon;
grant execute on function public.founder_r3410_high_risk_queue() to authenticated;
