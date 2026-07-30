-- Round 3643: Medical-Device Essential-Principles Conformity-Assessment Board
-- MDR essential-principles conformity-assessment checklist completion per device —
-- device class × principle area × conformity status × principles met/gap × evidence attached
-- × standards referenced × reassessment due × monthly trend × CAPA closure.

-- =============================================================================
-- TABLE 1: essential_principles_r3643 — per-device essential-principles conformity assessment
-- =============================================================================
create table if not exists public.essential_principles_r3643 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  device_code text not null,
  device_name text not null,
  device_class text not null check (device_class in (
    'class_a','class_b','class_c','class_d'
  )),
  period_month date not null,
  principles_total int not null,
  principles_met int not null,
  principles_gap int not null,
  conformity_pct numeric(5,2),
  evidence_attached_pct numeric(5,2),
  standards_referenced int,
  assessment_date date not null,
  reassessment_due date,
  principle_area text not null check (principle_area in (
    'safety_performance','design_manufacture','chemical_biological','sterility','labeling_ifu'
  )),
  conformity_status text not null check (conformity_status in (
    'conformant','minor_gap','major_gap','non_conformant','not_assessed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.essential_principles_r3643 enable row level security;

create index if not exists idx_essential_principles_r3643_org on public.essential_principles_r3643(organization_id);
create index if not exists idx_essential_principles_r3643_month on public.essential_principles_r3643(period_month);
create index if not exists idx_essential_principles_r3643_status on public.essential_principles_r3643(conformity_status);

-- =============================================================================
-- TABLE 2: essential_principles_capa_actions_r3643 — CAPA & conformity remediation actions
-- =============================================================================
create table if not exists public.essential_principles_capa_actions_r3643 (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.essential_principles_r3643(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'clinical_evaluation_gap','risk_management_gap','biocompatibility_evidence_missing',
    'sterility_validation_gap','labeling_ifu_deficiency','design_verification_gap',
    'usability_evidence_missing','standards_not_referenced','post_market_surveillance_gap','software_lifecycle_gap'
  )),
  root_cause text not null check (root_cause in (
    'incomplete_technical_file','outdated_standard_reference','missing_test_report',
    'supplier_documentation_gap','design_change_uncontrolled','risk_analysis_incomplete',
    'pending_investigation','resource_constraint','regulatory_update_pending','translation_localization_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'compile_technical_documentation','update_standard_reference','commission_biocompatibility_test',
    'complete_sterility_validation','revise_labeling_ifu','perform_design_verification',
    'conduct_usability_study','update_risk_management_file','submit_to_notified_body','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','mdr_essential_principle_deviation','iso_13485_deviation',
    'iso_14971_deviation','none','internal_only'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.essential_principles_capa_actions_r3643 enable row level security;

create index if not exists idx_essential_principles_capa_r3643_assessment on public.essential_principles_capa_actions_r3643(assessment_id);
create index if not exists idx_essential_principles_capa_r3643_status on public.essential_principles_capa_actions_r3643(capa_status);

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

  -- 16 essential-principles assessment rows
  insert into public.essential_principles_r3643 (
    organization_id, device_code, device_name, device_class, period_month,
    principles_total, principles_met, principles_gap, conformity_pct, evidence_attached_pct,
    standards_referenced, assessment_date, reassessment_due, principle_area,
    conformity_status, trend_dir, notes
  )
  select v_org_id, q.dcode, q.dname, q.dclass, q.pmonth::date,
    q.ptot, q.pmet, q.pgap, q.cpct, q.epct,
    q.sref, q.adate::date, q.rdue::date, q.parea,
    q.cstat, q.tdir, q.nt
  from (values
    ('EQP-VENT-01','ICU Ventilator (Skanray)','class_c','2026-07-01',
     23,23,0,100.00,100.00,12,'2026-07-01','2027-07-01','safety_performance','conformant','stable','All 23 essential principles met; full technical file and standards evidence attached'),
    ('EQP-INFP-02','Infusion Pump (BPL)','class_c','2026-07-01',
     23,21,2,91.30,88.00,10,'2026-07-01','2027-01-01','design_manufacture','minor_gap','improving','Two design-manufacture principles pending updated IEC 60601-2-24 reference'),
    ('EQP-MON-03','Patient Monitor (Skanray)','class_b','2026-07-01',
     23,20,3,87.00,80.00,9,'2026-07-01','2027-01-01','labeling_ifu','minor_gap','stable','IFU labeling gaps on alarm-priority symbols; Hindi translation pending'),
    ('EQP-DIAL-04','Haemodialysis Machine (Nipro)','class_c','2026-07-01',
     24,18,6,75.00,65.00,8,'2026-07-01','2026-10-01','chemical_biological','major_gap','worsening','Biocompatibility evidence for blood-contact circuit incomplete per ISO 10993'),
    ('EQP-DEFI-05','Defibrillator (BPL)','class_d','2026-07-01',
     24,24,0,100.00,95.00,13,'2026-07-01','2027-07-01','safety_performance','conformant','stable','Energy-delivery safety principles fully evidenced; annual reassessment scheduled'),
    ('EQP-CARM-06','Mobile C-Arm (Allengers)','class_c','2026-06-01',
     23,16,7,69.60,55.00,7,'2026-06-01','2026-09-01','safety_performance','major_gap','worsening','Radiation-safety essential principles gap; AERB dose-report evidence missing'),
    ('EQP-SYRP-07','Syringe Pump (BPL)','class_c','2026-06-01',
     23,22,1,95.70,90.00,11,'2026-06-01','2027-06-01','design_manufacture','conformant','improving','Single occlusion-alarm verification item closed; conformity restored'),
    ('EQP-ANES-08','Anaesthesia Workstation (Skanray)','class_c','2026-06-01',
     24,14,10,58.30,40.00,6,'2026-06-01','2026-08-01','sterility','non_conformant','worsening','Breathing-circuit sterility validation absent; multiple principles unmet'),
    ('EQP-ECG-09','ECG Machine (BPL)','class_b','2026-06-01',
     22,21,1,95.50,92.00,10,'2026-06-01','2027-06-01','labeling_ifu','conformant','stable','Labeling and IFU essential principles conformant post-review'),
    ('EQP-OXIM-10','Pulse Oximeter (BPL)','class_b','2026-06-01',
     22,20,2,90.90,85.00,9,'2026-06-01','2027-01-01','safety_performance','minor_gap','improving','SpO2 accuracy clinical-evidence summary pending final sign-off'),
    ('EQP-INCU-11','Infant Incubator (Phoenix)','class_c','2026-05-01',
     23,17,6,73.90,60.00,8,'2026-05-01','2026-09-01','chemical_biological','major_gap','stable','Skin-contact material biocompatibility file incomplete; supplier data awaited'),
    ('EQP-SUCT-12','Suction Apparatus (Sunrise)','class_a','2026-05-01',
     20,20,0,100.00,98.00,7,'2026-05-01','2027-05-01','design_manufacture','conformant','stable','Low-risk Class A device; all essential principles evidenced'),
    ('EQP-NEBU-13','Nebulizer (Omron India)','class_a','2026-05-01',
     20,19,1,95.00,90.00,6,'2026-05-01','2027-05-01','labeling_ifu','conformant','improving','Minor IFU wording corrected; conformity confirmed'),
    ('EQP-CATH-14','Cath-Lab Imaging System (Allengers)','class_d','2026-05-01',
     24,12,12,50.00,35.00,5,'2026-05-01','2026-08-01','sterility','non_conformant','worsening','Sterile-field accessory validation and clinical evaluation both deficient'),
    ('EQP-BLDW-15','Blood Warmer (Sunrise)','class_b','2026-07-01',
     22,0,22,0.00,0.00,0,'2026-07-01','2026-08-15','safety_performance','not_assessed','stable','New model added to portfolio; essential-principles assessment not yet started'),
    ('EQP-ELEC-16','Electrosurgical Unit (BPL)','class_c','2026-07-01',
     23,19,4,82.60,70.00,9,'2026-07-01','2026-11-01','design_manufacture','minor_gap','improving','HF-leakage design-verification evidence being compiled per IEC 60601-2-2')
  ) as q(dcode, dname, dclass, pmonth, ptot, pmet, pgap, cpct, epct, sref, adate, rdue, parea, cstat, tdir, nt);

  -- CAPA seed — attach to specific assessments via device_code
  insert into public.essential_principles_capa_actions_r3643 (
    assessment_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('EQP-DIAL-04','biocompatibility_evidence_missing','missing_test_report','commission_biocompatibility_test','in_progress','iso_14971_deviation','QA Lead','2026-09-30',null,180000.00,'ISO 10993 cytotoxicity and haemocompatibility testing commissioned at NABL lab'),
    ('EQP-CARM-06','design_verification_gap','incomplete_technical_file','perform_design_verification','open','mdr_essential_principle_deviation','RA Manager','2026-09-01',null,120000.00,'AERB radiation-dose verification report to be added to technical file'),
    ('EQP-ANES-08','sterility_validation_gap','pending_investigation','complete_sterility_validation','escalated','cdsco_notifiable','Head QA','2026-08-15',null,250000.00,'Breathing-circuit sterility validation escalated; CDSCO notification under review'),
    ('EQP-CATH-14','clinical_evaluation_gap','incomplete_technical_file','compile_technical_documentation','overdue','cdsco_notifiable','RA Manager','2026-07-20',null,300000.00,'Clinical evaluation report overdue; Class D device flagged for priority remediation'),
    ('EQP-INCU-11','biocompatibility_evidence_missing','supplier_documentation_gap','commission_biocompatibility_test','verification_pending','iso_13485_deviation','QA Engineer','2026-09-01',null,95000.00,'Supplier material declarations received; confirmatory testing under verification'),
    ('EQP-MON-03','labeling_ifu_deficiency','translation_localization_gap','revise_labeling_ifu','closed','internal_only','Tech Writer','2026-07-10','2026-07-08',25000.00,'Alarm-priority symbols and Hindi IFU translation corrected and released'),
    ('EQP-INFP-02','standards_not_referenced','outdated_standard_reference','update_standard_reference','closed','none','RA Analyst','2026-07-05','2026-07-03',15000.00,'Technical file updated to latest IEC 60601-2-24 edition'),
    ('EQP-ELEC-16','design_verification_gap','design_change_uncontrolled','perform_design_verification','in_progress','iso_13485_deviation','Design Lead','2026-10-15',null,60000.00,'HF-leakage re-verification after uncontrolled design change under corrective control')
  ) as q(dcode, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.essential_principles_r3643 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Conformity-status distribution
create or replace function public.founder_r3643_conformity_status_rollup()
returns table(conformity_status text, assessments bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.essential_principles_r3643)
  select l.conformity_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.essential_principles_r3643 l
  group by l.conformity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3643_conformity_status_rollup() from public, anon;
grant execute on function public.founder_r3643_conformity_status_rollup() to authenticated;

-- 2) Device-class scorecard
create or replace function public.founder_r3643_device_class_scorecard()
returns table(
  device_class text,
  total_assessments bigint,
  conformant bigint,
  minor_gap bigint,
  major_or_non bigint,
  total_gaps bigint,
  avg_conformity_pct numeric,
  avg_evidence_pct numeric,
  conformant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_class,
    count(*)::bigint,
    count(*) filter (where l.conformity_status = 'conformant')::bigint,
    count(*) filter (where l.conformity_status = 'minor_gap')::bigint,
    count(*) filter (where l.conformity_status in ('major_gap','non_conformant'))::bigint,
    coalesce(sum(l.principles_gap),0)::bigint,
    round(avg(l.conformity_pct), 1),
    round(avg(l.evidence_attached_pct), 1),
    round(100.0 * count(*) filter (where l.conformity_status = 'conformant')::numeric / nullif(count(*),0), 1)
  from public.essential_principles_r3643 l
  group by l.device_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3643_device_class_scorecard() from public, anon;
grant execute on function public.founder_r3643_device_class_scorecard() to authenticated;

-- 3) Principle-area × conformity-status matrix
create or replace function public.founder_r3643_principle_area_status_matrix()
returns table(principle_area text, conformity_status text, assessments bigint, total_gaps bigint, avg_conformity_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.principle_area, l.conformity_status, count(*)::bigint,
    coalesce(sum(l.principles_gap),0)::bigint,
    round(avg(l.conformity_pct), 1)
  from public.essential_principles_r3643 l
  group by l.principle_area, l.conformity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3643_principle_area_status_matrix() from public, anon;
grant execute on function public.founder_r3643_principle_area_status_matrix() to authenticated;

-- 4) Monthly conformity trend
create or replace function public.founder_r3643_monthly_conformity_trend()
returns table(period_month date, assessments bigint, conformant bigint, major_or_non bigint, avg_conformity_pct numeric, avg_evidence_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.conformity_status = 'conformant')::bigint,
    count(*) filter (where l.conformity_status in ('major_gap','non_conformant'))::bigint,
    round(avg(l.conformity_pct), 1),
    round(avg(l.evidence_attached_pct), 1)
  from public.essential_principles_r3643 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3643_monthly_conformity_trend() from public, anon;
grant execute on function public.founder_r3643_monthly_conformity_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3643_capa_status_board()
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
  from public.essential_principles_capa_actions_r3643 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3643_capa_status_board() from public, anon;
grant execute on function public.founder_r3643_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3643_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.essential_principles_capa_actions_r3643)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.essential_principles_capa_actions_r3643 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3643_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3643_root_cause_pareto() to authenticated;

-- 7) Gap-impact digest (by regulatory impact)
create or replace function public.founder_r3643_gap_impact_digest()
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
  from public.essential_principles_capa_actions_r3643 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3643_gap_impact_digest() from public, anon;
grant execute on function public.founder_r3643_gap_impact_digest() to authenticated;

-- 8) High-risk queue (major_gap / non_conformant / low evidence)
create or replace function public.founder_r3643_high_risk_queue()
returns table(
  device_code text,
  device_name text,
  device_class text,
  principle_area text,
  period_month date,
  conformity_status text,
  principles_gap int,
  conformity_pct numeric,
  evidence_attached_pct numeric,
  reassessment_due date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_code, l.device_name, l.device_class, l.principle_area, l.period_month,
    l.conformity_status, l.principles_gap, l.conformity_pct, l.evidence_attached_pct,
    l.reassessment_due, l.notes
  from public.essential_principles_r3643 l
  where l.conformity_status in ('major_gap','non_conformant','not_assessed')
     or l.principles_gap >= 4
     or l.conformity_pct < 80.0
     or l.evidence_attached_pct < 70.0
     or l.trend_dir = 'worsening'
  order by l.conformity_pct asc nulls first, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3643_high_risk_queue() from public, anon;
grant execute on function public.founder_r3643_high_risk_queue() to authenticated;
