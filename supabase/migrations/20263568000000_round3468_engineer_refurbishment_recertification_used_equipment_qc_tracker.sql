-- Round 3468: Engineer Refurbishment / Recertification (Used-Equipment) QC Tracker
-- Used / pre-owned equipment refurb + recert QC — device category × refurb stage × stage status ×
-- electrical-safety × functional-test × recert grade × intake/certified dates × refurb cost × CAPA

-- =============================================================================
-- TABLE 1: refurb_recert_qc_r3468 — per-asset refurbishment / recertification QC log
-- =============================================================================
create table if not exists public.refurb_recert_qc_r3468 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  asset_tag text not null,
  device_model text not null,
  device_category text not null,
  refurb_stage text not null check (refurb_stage in (
    'intake','teardown','parts_replacement','calibration','safety_test','cosmetic','final_qc','certified'
  )),
  stage_status text not null check (stage_status in (
    'pending','in_progress','passed','failed','rework'
  )),
  electrical_safety_ok boolean not null,
  functional_test_ok boolean not null,
  recert_grade text not null check (recert_grade in (
    'grade_a','grade_b','grade_c','rejected'
  )),
  intake_date date not null,
  certified_date date,
  refurb_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.refurb_recert_qc_r3468 enable row level security;

create index if not exists idx_refurb_recert_qc_r3468_org on public.refurb_recert_qc_r3468(organization_id);
create index if not exists idx_refurb_recert_qc_r3468_intake on public.refurb_recert_qc_r3468(intake_date);
create index if not exists idx_refurb_recert_qc_r3468_grade on public.refurb_recert_qc_r3468(recert_grade);

-- =============================================================================
-- TABLE 2: refurb_recert_qc_capa_actions_r3468 — CAPA & recert compliance actions
-- =============================================================================
create table if not exists public.refurb_recert_qc_capa_actions_r3468 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.refurb_recert_qc_r3468(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'electrical_safety_failure','functional_test_failure','calibration_out_of_tolerance',
    'worn_part_not_replaced','cosmetic_defect','missing_accessory','documentation_gap',
    'recert_grade_downgrade','safety_test_overdue','battery_end_of_life'
  )),
  root_cause text not null check (root_cause in (
    'component_end_of_life','counterfeit_spare_part','improper_reassembly','calibration_equipment_drift',
    'skipped_qc_step','oem_parts_unavailable','operator_error','pending_investigation',
    'wear_and_tear','firmware_incompatibility'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_component','source_genuine_oem_part','reassemble_and_retest','recalibrate_instrument',
    'repeat_full_qc','order_oem_spares','retrain_technician','downgrade_and_disclose',
    'scrap_and_reject','replace_battery_pack','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_refurb_compliance','bis_certification_gap','warranty_disclosure_required',
    'internal_only','customer_contract_breach','none'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.refurb_recert_qc_capa_actions_r3468 enable row level security;

create index if not exists idx_refurb_recert_capa_r3468_log on public.refurb_recert_qc_capa_actions_r3468(qc_log_id);
create index if not exists idx_refurb_recert_capa_r3468_status on public.refurb_recert_qc_capa_actions_r3468(capa_status);

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

  -- 16 refurb / recert QC rows
  insert into public.refurb_recert_qc_r3468 (
    organization_id, engineer_name, asset_tag, device_model, device_category,
    refurb_stage, stage_status, electrical_safety_ok, functional_test_ok, recert_grade,
    intake_date, certified_date, refurb_cost_rupees, notes
  )
  select v_org_id, q.eng, q.tag, q.model, q.cat,
    q.stage, q.sst, q.esafe, q.ftest, q.grade,
    q.idate::date, q.cdate::date, q.cost, q.nt
  from (values
    ('S. Krishnan','RF-3468-001','Philips IntelliVue MP40','patient_monitor',
     'certified','passed',true,true,'grade_a','2026-06-05','2026-06-18',18500.00,'Full recert passed, grade A — cleared for resale'),
    ('S. Krishnan','RF-3468-002','BPL EcoSpO2','pulse_oximeter',
     'final_qc','passed',true,true,'grade_b','2026-06-20','2026-06-30',3200.00,'Minor casing scuff, functional and safety pass — grade B'),
    ('A. Menon','RF-3468-003','Nihon Kohden TEC-5621','defibrillator',
     'safety_test','failed',false,true,'rejected','2026-06-10',null,9800.00,'Failed IEC 62353 earth-leakage test — HV section suspect'),
    ('A. Menon','RF-3468-004','Mindray SV300','ventilator',
     'calibration','in_progress',true,true,'grade_b','2026-06-22',null,26500.00,'O2 sensor recalibration underway, awaiting flow verification'),
    ('R. Pillai','RF-3468-005','BD Alaris GP','infusion_pump',
     'parts_replacement','rework',true,false,'grade_c','2026-06-14',null,5400.00,'Occlusion sensor drift on functional test — pump mechanism worn, rework'),
    ('R. Pillai','RF-3468-006','GE MAC 2000','ecg_machine',
     'certified','passed',true,true,'grade_a','2026-05-28','2026-06-12',7600.00,'Refurb ECG certified grade A after lead-set replacement'),
    ('V. Nair','RF-3468-007','Fresenius 4008S','dialysis_machine',
     'teardown','in_progress',true,true,'grade_c','2026-06-25',null,42000.00,'Hydraulic teardown; conductivity cell corroded, awaiting OEM spares'),
    ('V. Nair','RF-3468-008','Terumo TE-171','syringe_pump',
     'intake','pending',true,true,'grade_b','2026-07-01',null,2100.00,'Received from Apollo buy-back, intake inspection pending'),
    ('P. Deshmukh','RF-3468-009','Draeger Fabius Plus','anesthesia_workstation',
     'final_qc','passed',true,true,'grade_a','2026-05-30','2026-06-20',58000.00,'Anesthesia workstation vaporizer calibrated, full QC pass'),
    ('P. Deshmukh','RF-3468-010','Mindray DP-10','ultrasound',
     'cosmetic','in_progress',true,true,'grade_b','2026-06-18',null,15500.00,'Functional pass; refurbishing worn keypad and probe holder'),
    ('S. Krishnan','RF-3468-011','Philips HeartStart XL','defibrillator',
     'safety_test','passed',true,true,'grade_b','2026-06-08','2026-06-24',11200.00,'Battery pack replaced, safety test pass — grade B'),
    ('A. Menon','RF-3468-012','Skanray Star 60','patient_monitor',
     'calibration','rework',true,false,'grade_c','2026-06-16',null,4800.00,'NIBP module fails accuracy check — recalibration and reseat needed'),
    ('R. Pillai','RF-3468-013','Maquet Servo-i','ventilator',
     'final_qc','failed',true,false,'rejected','2026-06-02',null,31000.00,'Expiratory flow sensor irreparable, functional QC failed — reject'),
    ('V. Nair','RF-3468-014','BPL Relife 900','ventilator',
     'parts_replacement','in_progress',true,true,'grade_b','2026-06-27',null,19800.00,'Turbine and HEPA filter set replacement in progress'),
    ('P. Deshmukh','RF-3468-015','GE Vivid S60','ultrasound',
     'certified','passed',true,true,'grade_a','2026-05-25','2026-06-10',63000.00,'Cardiac ultrasound recertified grade A, all probes validated'),
    ('S. Krishnan','RF-3468-016','Contec CMS8000','patient_monitor',
     'intake','pending',false,true,'rejected','2026-07-03',null,3900.00,'Intake found cracked mainboard and earth-leakage fail — likely scrap')
  ) as q(eng, tag, model, cat, stage, sst, esafe, ftest, grade, idate, cdate, cost, nt);

  -- CAPA seed — attach to specific assets by asset_tag
  insert into public.refurb_recert_qc_capa_actions_r3468 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('RF-3468-003','electrical_safety_failure','component_end_of_life','replace_component','in_progress','warranty_disclosure_required','A. Menon','2026-07-10',null,14000.00,'HV board earth-leakage fail — sourcing genuine OEM board'),
    ('RF-3468-005','functional_test_failure','wear_and_tear','reassemble_and_retest','open','internal_only','R. Pillai','2026-07-08',null,5000.00,'Occlusion sensor and pump mechanism worn — rework and full retest'),
    ('RF-3468-013','functional_test_failure','oem_parts_unavailable','scrap_and_reject','escalated','customer_contract_breach','R. Pillai','2026-07-05',null,31000.00,'Expiratory flow sensor discontinued — unit scrapped, buyer notified'),
    ('RF-3468-012','calibration_out_of_tolerance','calibration_equipment_drift','recalibrate_instrument','verification_pending','internal_only','A. Menon','2026-07-09',null,3500.00,'NIBP recalibrated against reference — verify next QC batch'),
    ('RF-3468-016','electrical_safety_failure','component_end_of_life','scrap_and_reject','closed','none','S. Krishnan','2026-07-06','2026-07-04',3900.00,'Cracked mainboard and earth-leakage — condemned at intake'),
    ('RF-3468-004','calibration_out_of_tolerance','calibration_equipment_drift','recalibrate_instrument','open','cdsco_refurb_compliance','A. Menon','2026-07-12',null,4200.00,'O2 sensor drift — recalibrate and document per CDSCO refurb norms'),
    ('RF-3468-007','worn_part_not_replaced','component_end_of_life','order_oem_spares','overdue','internal_only','V. Nair','2026-07-02',null,22000.00,'Conductivity cell corroded — OEM spare order delayed by vendor'),
    ('RF-3468-011','battery_end_of_life','component_end_of_life','replace_battery_pack','closed','warranty_disclosure_required','S. Krishnan','2026-06-24','2026-06-23',8000.00,'Defib battery pack replaced and safety-tested before recert')
  ) as q(tag, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.refurb_recert_qc_r3468 e
    on e.organization_id = v_org_id and e.asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Stage-status distribution
create or replace function public.founder_r3468_stage_status_rollup()
returns table(stage_status text, units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.refurb_recert_qc_r3468)
  select l.stage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.refurb_recert_qc_r3468 l
  group by l.stage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3468_stage_status_rollup() from public, anon;
grant execute on function public.founder_r3468_stage_status_rollup() to authenticated;

-- 2) Refurb-stage scorecard
create or replace function public.founder_r3468_refurb_stage_scorecard()
returns table(
  refurb_stage text,
  total_units bigint,
  passed bigint,
  failed bigint,
  rework bigint,
  electrical_fail bigint,
  functional_fail bigint,
  avg_cost_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.refurb_stage,
    count(*)::bigint,
    count(*) filter (where l.stage_status = 'passed')::bigint,
    count(*) filter (where l.stage_status = 'failed')::bigint,
    count(*) filter (where l.stage_status = 'rework')::bigint,
    count(*) filter (where l.electrical_safety_ok = false)::bigint,
    count(*) filter (where l.functional_test_ok = false)::bigint,
    round(avg(l.refurb_cost_rupees)::numeric, 0)
  from public.refurb_recert_qc_r3468 l
  group by l.refurb_stage
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3468_refurb_stage_scorecard() from public, anon;
grant execute on function public.founder_r3468_refurb_stage_scorecard() to authenticated;

-- 3) Refurb-stage × recert-grade matrix
create or replace function public.founder_r3468_stage_grade_matrix()
returns table(refurb_stage text, recert_grade text, units bigint, passed bigint, failed bigint, avg_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.refurb_stage, l.recert_grade, count(*)::bigint,
    count(*) filter (where l.stage_status = 'passed')::bigint,
    count(*) filter (where l.stage_status in ('failed','rework'))::bigint,
    round(avg(l.refurb_cost_rupees)::numeric, 0)
  from public.refurb_recert_qc_r3468 l
  group by l.refurb_stage, l.recert_grade
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3468_stage_grade_matrix() from public, anon;
grant execute on function public.founder_r3468_stage_grade_matrix() to authenticated;

-- 4) Monthly throughput trend (by intake month)
create or replace function public.founder_r3468_monthly_throughput_trend()
returns table(intake_month text, intake_units bigint, certified_units bigint, rejected_units bigint, avg_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.intake_date), 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.refurb_stage = 'certified')::bigint,
    count(*) filter (where l.recert_grade = 'rejected')::bigint,
    round(avg(l.refurb_cost_rupees)::numeric, 0)
  from public.refurb_recert_qc_r3468 l
  group by date_trunc('month', l.intake_date)
  order by date_trunc('month', l.intake_date) desc;
end;
$$;

revoke execute on function public.founder_r3468_monthly_throughput_trend() from public, anon;
grant execute on function public.founder_r3468_monthly_throughput_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3468_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.refurb_recert_qc_capa_actions_r3468 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3468_capa_status_board() from public, anon;
grant execute on function public.founder_r3468_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3468_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.refurb_recert_qc_capa_actions_r3468)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.refurb_recert_qc_capa_actions_r3468 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3468_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3468_root_cause_pareto() to authenticated;

-- 7) Refurb-cost impact digest (by device category)
create or replace function public.founder_r3468_refurb_cost_impact_digest()
returns table(device_category text, units bigint, rejected_units bigint, total_cost_rupees numeric, avg_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_category, count(*)::bigint,
    count(*) filter (where l.recert_grade = 'rejected')::bigint,
    coalesce(sum(l.refurb_cost_rupees),0)::numeric,
    round(avg(l.refurb_cost_rupees)::numeric, 0)
  from public.refurb_recert_qc_r3468 l
  group by l.device_category
  order by coalesce(sum(l.refurb_cost_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3468_refurb_cost_impact_digest() from public, anon;
grant execute on function public.founder_r3468_refurb_cost_impact_digest() to authenticated;

-- 8) High-risk refurb queue (failed / rejected / safety-fail / aging uncertified)
create or replace function public.founder_r3468_high_risk_queue()
returns table(
  engineer_name text,
  asset_tag text,
  device_model text,
  device_category text,
  refurb_stage text,
  stage_status text,
  recert_grade text,
  electrical_safety_ok text,
  functional_test_ok text,
  intake_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.asset_tag, l.device_model, l.device_category,
    l.refurb_stage, l.stage_status, l.recert_grade,
    case when l.electrical_safety_ok then 'yes' else 'no' end,
    case when l.functional_test_ok then 'yes' else 'no' end,
    l.intake_date, l.notes
  from public.refurb_recert_qc_r3468 l
  where l.stage_status in ('failed','rework')
     or l.recert_grade = 'rejected'
     or l.electrical_safety_ok = false
     or l.functional_test_ok = false
     or (l.certified_date is null and l.intake_date < current_date - interval '21 days')
  order by l.intake_date asc, l.asset_tag;
end;
$$;

revoke execute on function public.founder_r3468_high_risk_queue() from public, anon;
grant execute on function public.founder_r3468_high_risk_queue() to authenticated;
