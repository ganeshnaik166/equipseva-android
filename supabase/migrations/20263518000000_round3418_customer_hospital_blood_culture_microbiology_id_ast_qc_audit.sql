-- Round 3418: Customer Hospital Blood-Culture & Microbiology ID/AST Analyzer QC Audit
-- Micro-lab QA — analyzer type × lab section × incubation × agitation × detection sensitivity × QC organism × reagent lot × contamination rate × LIS connectivity × TAT × PM/cal × CAPA

-- =============================================================================
-- TABLE 1: blood_culture_micro_qc_r3418 — per-analyzer microbiology QC checks
-- =============================================================================
create table if not exists public.blood_culture_micro_qc_r3418 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  analyzer_code text not null,
  analyzer_type text not null check (analyzer_type in (
    'blood_culture_system','id_ast_analyzer','maldi_tof_id',
    'automated_susceptibility','molecular_syndromic_panel'
  )),
  lab_section text not null check (lab_section in (
    'blood_culture_bench','bacteriology','rapid_id_ast','molecular_micro','mycobacteriology'
  )),
  check_date date not null,
  incubation_temperature_ok boolean not null,
  agitation_ok text not null check (agitation_ok in (
    'ok','erratic','fail','not_applicable'
  )),
  detection_sensitivity_ok boolean not null,
  qc_organism_result text not null check (qc_organism_result in (
    'pass','warn','fail','not_run'
  )),
  reagent_card_lot_ok boolean not null,
  contamination_rate_pct numeric(5,2),
  connectivity_lis_ok boolean not null,
  turnaround_time_ok boolean not null,
  preventive_maint_current boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','analyzer_grounded'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.blood_culture_micro_qc_r3418 enable row level security;

create index if not exists idx_blood_culture_micro_qc_r3418_org on public.blood_culture_micro_qc_r3418(organization_id);
create index if not exists idx_blood_culture_micro_qc_r3418_date on public.blood_culture_micro_qc_r3418(check_date);
create index if not exists idx_blood_culture_micro_qc_r3418_verdict on public.blood_culture_micro_qc_r3418(qc_verdict);

-- =============================================================================
-- TABLE 2: blood_culture_micro_qc_capa_actions_r3418 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.blood_culture_micro_qc_capa_actions_r3418 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.blood_culture_micro_qc_r3418(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'incubation_temperature_out_of_range','agitation_mechanism_fault','detection_sensitivity_low',
    'qc_organism_failure','reagent_card_lot_issue','contamination_rate_high',
    'lis_connectivity_loss','turnaround_time_breach','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'incubator_thermostat_drift','agitation_motor_wear','photodetector_degraded','expired_reagent_card',
    'qc_strain_handling_error','blood_draw_contamination','lis_interface_config_error',
    'staffing_workflow_delay','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_incubator','replace_agitation_motor','replace_detector_module','replace_reagent_lot',
    'retrain_micro_staff','reinforce_draw_technique','reconfigure_lis_interface',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.blood_culture_micro_qc_capa_actions_r3418 enable row level security;

create index if not exists idx_blood_culture_micro_capa_r3418_log on public.blood_culture_micro_qc_capa_actions_r3418(qc_log_id);
create index if not exists idx_blood_culture_micro_capa_r3418_status on public.blood_culture_micro_qc_capa_actions_r3418(capa_status);

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
  insert into public.blood_culture_micro_qc_r3418 (
    organization_id, hospital_name, analyzer_code, analyzer_type, lab_section, check_date,
    incubation_temperature_ok, agitation_ok, detection_sensitivity_ok,
    qc_organism_result, reagent_card_lot_ok, contamination_rate_pct,
    connectivity_lis_ok, turnaround_time_ok, preventive_maint_current, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.acode, q.atype, q.lsec, q.cdate::date,
    q.inctemp, q.agit, q.detsens,
    q.qcorg, q.reagent, q.contam,
    q.lis, q.tat, q.pm, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','BCS-APL-01','blood_culture_system','blood_culture_bench','2026-07-03',
     true,'ok',true,'pass',true,0.9,true,true,true,true,'pass','Quarterly QC — blood culture incubator within tolerance'),
    ('Apollo Chennai','MALDI-APL-02','maldi_tof_id','bacteriology','2026-07-03',
     true,'not_applicable',true,'pass',true,null,true,true,true,true,'pass','MALDI-TOF ID QC organisms identified correctly'),
    ('Fortis Gurgaon','IDAST-FRT-11','id_ast_analyzer','rapid_id_ast','2026-07-02',
     true,'ok',true,'warn',true,2.1,true,true,true,true,'conditional_pass','ATCC AST QC one MIC off-scale — organism QC warn'),
    ('Fortis Gurgaon','BCS-FRT-12','blood_culture_system','blood_culture_bench','2026-07-02',
     false,'erratic',true,'pass',true,4.6,true,false,true,true,'fail','Incubator temp out of range, agitation erratic, contamination high and TAT breached'),
    ('Manipal Bengaluru','MSP-MNP-21','molecular_syndromic_panel','molecular_micro','2026-07-01',
     true,'not_applicable',false,'fail',false,null,true,true,false,false,'analyzer_grounded','Syndromic panel detection sensitivity low, QC organism fail, expired reagent lot — grounded'),
    ('Manipal Bengaluru','ASUS-MNP-22','automated_susceptibility','rapid_id_ast','2026-07-01',
     true,'ok',true,'pass',true,1.2,true,true,true,true,'pass','Automated susceptibility QC nominal'),
    ('AIIMS Delhi','BCS-AIM-31','blood_culture_system','blood_culture_bench','2026-06-30',
     true,'ok',true,'pass',true,3.4,true,true,true,true,'conditional_pass','Contamination rate trending up (3.4%) — phlebotomy audit flagged'),
    ('AIIMS Delhi','IDAST-AIM-32','id_ast_analyzer','bacteriology','2026-06-30',
     true,'ok',false,'warn',true,null,false,true,true,true,'fail','ID/AST detection sensitivity fail and LIS connectivity lost — results held'),
    ('CMC Vellore','MALDI-CMC-41','maldi_tof_id','bacteriology','2026-06-29',
     true,'not_applicable',true,'pass',true,null,true,true,true,true,'pass','MALDI-TOF QC pass post calibration'),
    ('CMC Vellore','MSP-CMC-42','molecular_syndromic_panel','molecular_micro','2026-06-29',
     true,'not_applicable',true,'warn',true,null,true,true,false,false,'conditional_pass','Syndromic panel QC warn, preventive maintenance and calibration overdue'),
    ('KIMS Hyderabad','BCS-KIM-51','blood_culture_system','blood_culture_bench','2026-06-28',
     true,'ok',true,'pass',true,0.7,true,true,true,true,'pass','Blood culture system QC pass post-AMC'),
    ('KIMS Hyderabad','ASUS-KIM-52','automated_susceptibility','rapid_id_ast','2026-06-28',
     true,'ok',true,'warn',false,1.5,true,false,true,true,'conditional_pass','AST card lot QC warn and TAT breach — new lot verification pending'),
    ('Yashoda Hyderabad','MALDI-YSH-61','maldi_tof_id','bacteriology','2026-06-27',
     true,'not_applicable',true,'pass',true,null,true,true,true,true,'pass','MALDI-TOF ID analyzer QC nominal'),
    ('Kokilaben Mumbai','BCS-KKB-71','blood_culture_system','blood_culture_bench','2026-06-27',
     false,'fail',false,'fail',false,6.2,false,false,false,false,'analyzer_grounded','Multiple failures: incubator, agitation, detection, contamination 6.2% — analyzer grounded')
  ) as q(hosp, acode, atype, lsec, cdate, inctemp, agit, detsens, qcorg, reagent, contam, lis, tat, pm, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via analyzer_code
  insert into public.blood_culture_micro_qc_capa_actions_r3418 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BCS-FRT-12','incubation_temperature_out_of_range','incubator_thermostat_drift','recalibrate_incubator','in_progress','iso_15189_deviation','2026-07-06',null,18000.00,'Incubator recalibrated; agitation motor check pending'),
    ('MSP-MNP-21','detection_sensitivity_low','expired_reagent_card','replace_reagent_lot','open','nabl_finding','2026-07-05',null,42000.00,'Expired syndromic panel lot removed; new lot QC pending'),
    ('IDAST-AIM-32','lis_connectivity_loss','lis_interface_config_error','reconfigure_lis_interface','escalated','patient_safety_alert','2026-07-04',null,9500.00,'LIS interface down — results manually verified, escalated to IT/OEM'),
    ('BCS-KKB-71','contamination_rate_high','blood_draw_contamination','reinforce_draw_technique','closed','cdsco_notifiable','2026-07-02','2026-06-30',51000.00,'Contamination 6.2% investigated; phlebotomy retraining done, analyzer serviced'),
    ('IDAST-FRT-11','qc_organism_failure','qc_strain_handling_error','retrain_micro_staff','verification_pending','internal_only','2026-07-05',null,3500.00,'QC strain re-run; retraining done — verify next QC'),
    ('MSP-CMC-42','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-30',null,26000.00,'Syndromic panel PM and calibration overdue — vendor delay'),
    ('ASUS-KIM-52','reagent_card_lot_issue','expired_reagent_card','replace_reagent_lot','open','none','2026-07-07',null,4800.00,'AST card lot flagged — new lot verification scheduled')
  ) as q(acode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.blood_culture_micro_qc_r3418 e
    on e.organization_id = v_org_id and e.analyzer_code = q.acode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3418_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.blood_culture_micro_qc_r3418)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.blood_culture_micro_qc_r3418 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3418_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3418_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3418_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  detection_fail bigint,
  organism_qc_issue bigint,
  calibration_overdue bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','analyzer_grounded'))::bigint,
    count(*) filter (where l.detection_sensitivity_ok = false)::bigint,
    count(*) filter (where l.qc_organism_result in ('warn','fail'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.blood_culture_micro_qc_r3418 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3418_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3418_hospital_scorecard() to authenticated;

-- 3) Analyzer-type × lab-section matrix
create or replace function public.founder_r3418_analyzer_type_section_matrix()
returns table(analyzer_type text, lab_section text, checks bigint, passed bigint, failed bigint, avg_contamination_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.analyzer_type, l.lab_section, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','analyzer_grounded'))::bigint,
    round(avg(l.contamination_rate_pct), 2)
  from public.blood_culture_micro_qc_r3418 l
  group by l.analyzer_type, l.lab_section
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3418_analyzer_type_section_matrix() from public, anon;
grant execute on function public.founder_r3418_analyzer_type_section_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3418_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, detection_fail bigint, organism_qc_issue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','analyzer_grounded'))::bigint,
    count(*) filter (where l.detection_sensitivity_ok = false)::bigint,
    count(*) filter (where l.qc_organism_result in ('warn','fail'))::bigint
  from public.blood_culture_micro_qc_r3418 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3418_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3418_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3418_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.blood_culture_micro_qc_capa_actions_r3418 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3418_capa_status_board() from public, anon;
grant execute on function public.founder_r3418_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3418_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.blood_culture_micro_qc_capa_actions_r3418)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.blood_culture_micro_qc_capa_actions_r3418 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3418_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3418_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3418_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.blood_culture_micro_qc_capa_actions_r3418 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3418_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3418_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3418_high_risk_queue()
returns table(
  hospital_name text,
  analyzer_code text,
  analyzer_type text,
  lab_section text,
  check_date date,
  qc_verdict text,
  agitation_ok text,
  qc_organism_result text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.analyzer_code, l.analyzer_type, l.lab_section, l.check_date,
    l.qc_verdict, l.agitation_ok, l.qc_organism_result, l.notes
  from public.blood_culture_micro_qc_r3418 l
  where l.qc_verdict in ('conditional_pass','fail','analyzer_grounded')
     or l.detection_sensitivity_ok = false
     or l.qc_organism_result in ('warn','fail')
     or l.agitation_ok in ('erratic','fail')
     or l.incubation_temperature_ok = false
     or l.reagent_card_lot_ok = false
     or l.connectivity_lis_ok = false
     or l.turnaround_time_ok = false
     or l.preventive_maint_current = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3418_high_risk_queue() from public, anon;
grant execute on function public.founder_r3418_high_risk_queue() to authenticated;
