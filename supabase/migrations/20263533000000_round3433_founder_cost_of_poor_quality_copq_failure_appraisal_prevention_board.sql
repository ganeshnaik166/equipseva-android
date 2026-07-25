-- Round 3433: Founder Cost-of-Poor-Quality (COPQ) — Failure / Appraisal / Prevention Board
-- COPQ board — cost item × COPQ category (internal/external failure, appraisal, prevention) ×
-- cost driver × department × cost rupees × % of revenue × period month × trend × preventable × CAPA

-- =============================================================================
-- TABLE 1: founder_copq_failure_appraisal_prevention_r3433 — per-item quality-cost lines
-- =============================================================================
create table if not exists public.founder_copq_failure_appraisal_prevention_r3433 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cost_code text not null,
  cost_item text not null,
  copq_category text not null check (copq_category in (
    'internal_failure','external_failure','appraisal','prevention'
  )),
  cost_driver text not null check (cost_driver in (
    'scrap','rework','warranty_claim','field_return','complaint_handling',
    'reinspection','inspection','training','process_improvement'
  )),
  department text not null,
  cost_owner text,
  cost_rupees numeric(18,2),
  pct_of_revenue numeric(6,3),
  units_affected integer,
  period_month date,
  cost_trend text not null check (cost_trend in (
    'rising','stable','falling'
  )),
  preventable boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.founder_copq_failure_appraisal_prevention_r3433 enable row level security;

create index if not exists idx_copq_r3433_org on public.founder_copq_failure_appraisal_prevention_r3433(organization_id);
create index if not exists idx_copq_r3433_cat on public.founder_copq_failure_appraisal_prevention_r3433(copq_category);
create index if not exists idx_copq_r3433_trend on public.founder_copq_failure_appraisal_prevention_r3433(cost_trend);

-- =============================================================================
-- TABLE 2: founder_copq_failure_appraisal_prevention_capa_actions_r3433 — CAPA & remediation
-- =============================================================================
create table if not exists public.founder_copq_failure_appraisal_prevention_capa_actions_r3433 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  finding_key text not null,
  cost_item text not null,
  root_cause text not null check (root_cause in (
    'supplier_defect','process_variation','operator_error','design_deficiency',
    'inadequate_training','missing_preventive_maintenance','inspection_gap',
    'specification_ambiguity','material_nonconformance','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'supplier_corrective_action','process_control_improvement','operator_retraining',
    'design_change','poka_yoke_mistake_proofing','preventive_maintenance_plan',
    'incoming_inspection_tightening','update_work_instruction','invest_in_prevention','no_action_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact_rupees numeric(18,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.founder_copq_failure_appraisal_prevention_capa_actions_r3433 enable row level security;

create index if not exists idx_copq_capa_r3433_org on public.founder_copq_failure_appraisal_prevention_capa_actions_r3433(organization_id);
create index if not exists idx_copq_capa_r3433_status on public.founder_copq_failure_appraisal_prevention_capa_actions_r3433(capa_status);

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

  -- 16 quality-cost lines
  insert into public.founder_copq_failure_appraisal_prevention_r3433 (
    organization_id, cost_code, cost_item, copq_category, cost_driver, department,
    cost_owner, cost_rupees, pct_of_revenue, units_affected, period_month,
    cost_trend, preventable, notes
  )
  select v_org_id, q.ccode, q.citem, q.cat, q.driver, q.dept,
    q.own, q.rup, q.pct, q.units::int, q.pmonth::date,
    q.trend, q.prev, q.nt
  from (values
    ('COPQ-IF-01','Scrapped faulty ultrasound probe boards','internal_failure','scrap','Refurbishment',
     'R. Menon',320000,0.420,18,'2026-06-01','stable',true,'Probe boards scrapped after failing incoming refurb QC'),
    ('COPQ-IF-02','Rework of miscalibrated infusion pumps','internal_failure','rework','Calibration Lab',
     'S. Rao',185000,0.240,42,'2026-06-01','falling',true,'Rework labour after first-pass calibration failures'),
    ('COPQ-IF-03','Re-inspection of returned patient monitors','internal_failure','reinspection','Quality Assurance',
     'A. Nair',96000,0.130,60,'2026-06-01','stable',true,'Extra QC re-inspection cycle on returned batch'),
    ('COPQ-EF-04','Warranty replacement of ECG modules','external_failure','warranty_claim','Field Service',
     'V. Kulkarni',640000,0.840,22,'2026-06-01','rising',true,'In-warranty ECG module failures at customer sites'),
    ('COPQ-EF-05','Field returns of defective X-ray tubes','external_failure','field_return','Field Service',
     'V. Kulkarni',910000,1.190,9,'2026-06-01','rising',true,'X-ray tube early-life failures returned from hospitals'),
    ('COPQ-EF-06','Complaint handling for dialysis machine faults','external_failure','complaint_handling','Customer Support',
     'P. Sharma',210000,0.280,34,'2026-06-01','stable',false,'Support cost handling recurring dialysis alarms'),
    ('COPQ-AP-07','Incoming inspection of imported spares','appraisal','inspection','Procurement',
     'K. Iyer',145000,0.190,120,'2026-06-01','stable',false,'Routine incoming QC on imported spare parts'),
    ('COPQ-AP-08','Final inspection of refurbished ventilators','appraisal','inspection','Quality Assurance',
     'A. Nair',168000,0.220,48,'2026-06-01','stable',false,'Pre-dispatch inspection of refurbished ventilators'),
    ('COPQ-PR-09','Technician calibration training program','prevention','training','Calibration Lab',
     'S. Rao',275000,0.360,null,'2026-06-01','rising',false,'Structured training to cut first-pass cal failures'),
    ('COPQ-PR-10','Process improvement kaizen for probe QC','prevention','process_improvement','Refurbishment',
     'R. Menon',130000,0.170,null,'2026-06-01','rising',false,'Kaizen to reduce probe board scrap rate'),
    ('COPQ-IF-11','Scrapped defibrillator battery packs','internal_failure','scrap','Refurbishment',
     'R. Menon',240000,0.310,26,'2026-07-01','falling',true,'Battery packs scrapped after capacity-test failure'),
    ('COPQ-EF-12','Warranty claims on syringe pump drives','external_failure','warranty_claim','Field Service',
     'V. Kulkarni',720000,0.940,15,'2026-07-01','rising',true,'Syringe pump drive-gear failures under warranty'),
    ('COPQ-EF-13','Field return of faulty patient-monitor SpO2 boards','external_failure','field_return','Field Service',
     'D. Bose',530000,0.690,12,'2026-07-01','rising',true,'SpO2 board field returns from multi-site rollout'),
    ('COPQ-AP-14','Re-inspection after supplier PCB rejects','appraisal','reinspection','Quality Assurance',
     'A. Nair',88000,0.110,75,'2026-07-01','stable',false,'Re-inspection sweep after supplier PCB nonconformance'),
    ('COPQ-PR-15','Preventive process audit and SOP refresh','prevention','process_improvement','Quality Assurance',
     'A. Nair',160000,0.210,null,'2026-07-01','stable',false,'Prevention audit refreshing service SOPs'),
    ('COPQ-IF-16','Rework of failed autoclave gasket assemblies','internal_failure','rework','Refurbishment',
     'R. Menon',112000,0.150,30,'2026-07-01','falling',true,'Rework labour on autoclave gasket reseating')
  ) as q(ccode, citem, cat, driver, dept, own, rup, pct, units, pmonth, trend, prev, nt);

  -- CAPA seed — org-scoped remediation actions on flagged cost lines
  insert into public.founder_copq_failure_appraisal_prevention_capa_actions_r3433 (
    organization_id, finding_key, cost_item, root_cause, corrective_action,
    capa_status, financial_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, q.fk, q.ci, q.rc, q.ca,
    q.cst, q.fin, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('COPQ-EF-05','Field returns of defective X-ray tubes','supplier_defect','supplier_corrective_action','in_progress',910000,'Quality Head - A. Nair','2026-08-15',null,'8D raised with X-ray tube supplier for early-life failures'),
    ('COPQ-EF-04','Warranty replacement of ECG modules','design_deficiency','design_change','open',640000,'Engineering - V. Kulkarni','2026-08-30',null,'ECG module connector redesign to stop warranty failures'),
    ('COPQ-IF-02','Rework of miscalibrated infusion pumps','inadequate_training','operator_retraining','verification_pending',185000,'Cal Lab - S. Rao','2026-08-05','2026-08-02','Calibration retraining done — verifying first-pass yield'),
    ('COPQ-EF-12','Warranty claims on syringe pump drives','material_nonconformance','supplier_corrective_action','escalated',720000,'Procurement - K. Iyer','2026-08-20',null,'Escalated drive-gear material nonconformance to vendor'),
    ('COPQ-IF-01','Scrapped faulty ultrasound probe boards','process_variation','process_control_improvement','open',320000,'Refurb - R. Menon','2026-08-25',null,'Tighten reflow process control to cut probe scrap'),
    ('COPQ-EF-06','Complaint handling for dialysis machine faults','missing_preventive_maintenance','preventive_maintenance_plan','closed',210000,'Service - P. Sharma','2026-07-20','2026-07-18','PM schedule added for dialysis alarm subsystem'),
    ('COPQ-EF-13','Field return of faulty patient-monitor SpO2 boards','inspection_gap','incoming_inspection_tightening','overdue',530000,'QA - A. Nair','2026-07-15',null,'Incoming SpO2 board inspection overdue for tightening'),
    ('COPQ-AP-14','Re-inspection after supplier PCB rejects','specification_ambiguity','update_work_instruction','in_progress',88000,'QA - A. Nair','2026-08-10',null,'Clarify PCB acceptance spec in the work instruction')
  ) as q(fk, ci, rc, ca, cst, fin, own, tcd, acd, nt);
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) COPQ-category distribution
create or replace function public.founder_r3433_copq_category_rollup()
returns table(copq_category text, cost_items bigint, total_cost_rupees numeric, avg_pct_of_revenue numeric, preventable_items bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.founder_copq_failure_appraisal_prevention_r3433)
  select l.copq_category, count(*)::bigint,
    coalesce(sum(l.cost_rupees),0)::numeric,
    round(avg(l.pct_of_revenue), 3),
    count(*) filter (where l.preventable = true)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.founder_copq_failure_appraisal_prevention_r3433 l
  group by l.copq_category
  order by coalesce(sum(l.cost_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3433_copq_category_rollup() from public, anon;
grant execute on function public.founder_r3433_copq_category_rollup() to authenticated;

-- 2) Department COPQ scorecard
create or replace function public.founder_r3433_department_scorecard()
returns table(
  department text,
  cost_items bigint,
  total_cost_rupees numeric,
  internal_failure_rupees numeric,
  external_failure_rupees numeric,
  appraisal_rupees numeric,
  prevention_rupees numeric,
  preventable_items bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    coalesce(sum(l.cost_rupees),0)::numeric,
    coalesce(sum(l.cost_rupees) filter (where l.copq_category = 'internal_failure'),0)::numeric,
    coalesce(sum(l.cost_rupees) filter (where l.copq_category = 'external_failure'),0)::numeric,
    coalesce(sum(l.cost_rupees) filter (where l.copq_category = 'appraisal'),0)::numeric,
    coalesce(sum(l.cost_rupees) filter (where l.copq_category = 'prevention'),0)::numeric,
    count(*) filter (where l.preventable = true)::bigint
  from public.founder_copq_failure_appraisal_prevention_r3433 l
  group by l.department
  order by coalesce(sum(l.cost_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3433_department_scorecard() from public, anon;
grant execute on function public.founder_r3433_department_scorecard() to authenticated;

-- 3) Category × cost-driver matrix
create or replace function public.founder_r3433_category_driver_matrix()
returns table(copq_category text, cost_driver text, cost_items bigint, total_cost_rupees numeric, preventable_items bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.copq_category, l.cost_driver, count(*)::bigint,
    coalesce(sum(l.cost_rupees),0)::numeric,
    count(*) filter (where l.preventable = true)::bigint
  from public.founder_copq_failure_appraisal_prevention_r3433 l
  group by l.copq_category, l.cost_driver
  order by coalesce(sum(l.cost_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3433_category_driver_matrix() from public, anon;
grant execute on function public.founder_r3433_category_driver_matrix() to authenticated;

-- 4) Monthly COPQ trend
create or replace function public.founder_r3433_monthly_copq_trend()
returns table(
  period_month date,
  cost_items bigint,
  total_cost_rupees numeric,
  failure_rupees numeric,
  appraisal_rupees numeric,
  prevention_rupees numeric,
  external_failure_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.period_month)::date,
    count(*)::bigint,
    coalesce(sum(l.cost_rupees),0)::numeric,
    coalesce(sum(l.cost_rupees) filter (where l.copq_category in ('internal_failure','external_failure')),0)::numeric,
    coalesce(sum(l.cost_rupees) filter (where l.copq_category = 'appraisal'),0)::numeric,
    coalesce(sum(l.cost_rupees) filter (where l.copq_category = 'prevention'),0)::numeric,
    coalesce(sum(l.cost_rupees) filter (where l.copq_category = 'external_failure'),0)::numeric
  from public.founder_copq_failure_appraisal_prevention_r3433 l
  where l.period_month is not null
  group by date_trunc('month', l.period_month)
  order by date_trunc('month', l.period_month);
end;
$$;

revoke execute on function public.founder_r3433_monthly_copq_trend() from public, anon;
grant execute on function public.founder_r3433_monthly_copq_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3433_capa_status_board()
returns table(capa_status text, findings bigint, total_impact_rupees numeric, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric,
    round(avg(c.financial_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.founder_copq_failure_appraisal_prevention_capa_actions_r3433 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3433_capa_status_board() from public, anon;
grant execute on function public.founder_r3433_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3433_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.founder_copq_failure_appraisal_prevention_capa_actions_r3433)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.founder_copq_failure_appraisal_prevention_capa_actions_r3433 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3433_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3433_root_cause_pareto() to authenticated;

-- 7) Financial-impact digest by cost driver
create or replace function public.founder_r3433_financial_impact_digest()
returns table(
  cost_driver text,
  cost_items bigint,
  total_cost_rupees numeric,
  external_failure_rupees numeric,
  preventable_rupees numeric,
  avg_pct_of_revenue numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cost_driver, count(*)::bigint,
    coalesce(sum(l.cost_rupees),0)::numeric,
    coalesce(sum(l.cost_rupees) filter (where l.copq_category = 'external_failure'),0)::numeric,
    coalesce(sum(l.cost_rupees) filter (where l.preventable = true),0)::numeric,
    round(avg(l.pct_of_revenue), 3)
  from public.founder_copq_failure_appraisal_prevention_r3433 l
  group by l.cost_driver
  order by coalesce(sum(l.cost_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3433_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3433_financial_impact_digest() to authenticated;

-- 8) High-risk queue (largest / rising external-failure cost lines)
create or replace function public.founder_r3433_high_risk_queue()
returns table(
  cost_item text,
  cost_code text,
  copq_category text,
  cost_driver text,
  department text,
  cost_rupees numeric,
  pct_of_revenue numeric,
  period_month date,
  cost_trend text,
  preventable boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cost_item, l.cost_code, l.copq_category, l.cost_driver, l.department,
    l.cost_rupees, l.pct_of_revenue, l.period_month, l.cost_trend, l.preventable, l.notes
  from public.founder_copq_failure_appraisal_prevention_r3433 l
  where l.copq_category = 'external_failure'
     or l.cost_trend = 'rising'
     or l.cost_rupees >= 500000
  order by coalesce(l.cost_rupees,0) desc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3433_high_risk_queue() from public, anon;
grant execute on function public.founder_r3433_high_risk_queue() to authenticated;
