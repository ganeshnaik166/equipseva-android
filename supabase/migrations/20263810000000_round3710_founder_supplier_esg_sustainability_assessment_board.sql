-- Round 3710: Founder Supplier ESG / Sustainability Assessment Board
-- Supplier-level ESG — env/social/governance scores × criticality × declarations × trend × CAPA
-- (supplier-level board; NOT the company-level ESG-BRSR composite)

-- =============================================================================
-- TABLE 1: supplier_esg_r3710 — per-supplier ESG / sustainability assessments
-- =============================================================================
create table if not exists public.supplier_esg_r3710 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_code text not null,
  supplier_name text not null,
  supply_category text not null,
  period_month date not null,
  esg_assessed boolean not null,
  assessment_date date,
  env_score numeric(5,2),
  social_score numeric(5,2),
  governance_score numeric(5,2),
  overall_esg_score numeric(5,2),
  child_labor_declaration boolean not null,
  conflict_minerals_declared boolean not null,
  corrective_plans_open int not null default 0,
  reassessment_due date,
  criticality text not null check (criticality in (
    'critical','major','standard','low_risk'
  )),
  esg_status text not null check (esg_status in (
    'leader','compliant','improvement_needed','high_risk','not_assessed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.supplier_esg_r3710 enable row level security;

create index if not exists idx_supplier_esg_r3710_org on public.supplier_esg_r3710(organization_id);
create index if not exists idx_supplier_esg_r3710_month on public.supplier_esg_r3710(period_month);
create index if not exists idx_supplier_esg_r3710_status on public.supplier_esg_r3710(esg_status);

-- =============================================================================
-- TABLE 2: supplier_esg_capa_actions_r3710 — ESG CAPA & remediation actions
-- =============================================================================
create table if not exists public.supplier_esg_capa_actions_r3710 (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.supplier_esg_r3710(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'environmental_noncompliance','social_noncompliance','governance_gap',
    'declaration_missing','assessment_overdue','score_deterioration'
  )),
  root_cause text not null check (root_cause in (
    'untreated_effluent_discharge','no_esg_policy','labor_records_gap',
    'no_grievance_mechanism','conflict_minerals_data_missing','questionnaire_not_returned',
    'high_energy_intensity','packaging_waste_excess','board_disclosure_gap','single_source_dependency'
  )),
  corrective_action text not null check (corrective_action in (
    'effluent_treatment_upgrade','esg_policy_rollout','third_party_social_audit',
    'grievance_mechanism_setup','collect_smelter_declarations','escalate_to_sourcing_council',
    'energy_efficiency_program','packaging_redesign','governance_disclosure_training',
    'dual_source_qualification','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  esg_risk_area text not null check (esg_risk_area in (
    'environment','social','governance','regulatory','reputational','supply_continuity'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.supplier_esg_capa_actions_r3710 enable row level security;

create index if not exists idx_supplier_esg_capa_r3710_assess on public.supplier_esg_capa_actions_r3710(assessment_id);
create index if not exists idx_supplier_esg_capa_r3710_status on public.supplier_esg_capa_actions_r3710(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) ESG status distribution
create or replace function public.founder_r3710_esg_status_rollup()
returns table(esg_status text, suppliers bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.supplier_esg_r3710)
  select l.esg_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.supplier_esg_r3710 l
  group by l.esg_status
  order by count(*) desc;
end;
$$;

-- 2) Supply-category ESG scorecard
create or replace function public.founder_r3710_supply_category_scorecard()
returns table(
  supply_category text,
  total_suppliers bigint,
  assessed bigint,
  leaders bigint,
  compliant bigint,
  improvement_needed bigint,
  high_risk bigint,
  avg_overall_score numeric,
  open_corrective_plans bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supply_category,
    count(*)::bigint,
    count(*) filter (where l.esg_assessed = true)::bigint,
    count(*) filter (where l.esg_status = 'leader')::bigint,
    count(*) filter (where l.esg_status = 'compliant')::bigint,
    count(*) filter (where l.esg_status = 'improvement_needed')::bigint,
    count(*) filter (where l.esg_status = 'high_risk')::bigint,
    round(avg(l.overall_esg_score), 1),
    coalesce(sum(l.corrective_plans_open),0)::bigint
  from public.supplier_esg_r3710 l
  group by l.supply_category
  order by count(*) desc;
end;
$$;

-- 3) Criticality × ESG status matrix
create or replace function public.founder_r3710_criticality_status_matrix()
returns table(criticality text, esg_status text, suppliers bigint, avg_overall_score numeric, avg_env_score numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.criticality, l.esg_status, count(*)::bigint,
    round(avg(l.overall_esg_score), 1),
    round(avg(l.env_score), 1)
  from public.supplier_esg_r3710 l
  group by l.criticality, l.esg_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly ESG score trend
create or replace function public.founder_r3710_monthly_score_trend()
returns table(
  period_month date,
  suppliers bigint,
  assessed bigint,
  avg_env_score numeric,
  avg_social_score numeric,
  avg_governance_score numeric,
  avg_overall_score numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.esg_assessed = true)::bigint,
    round(avg(l.env_score), 1),
    round(avg(l.social_score), 1),
    round(avg(l.governance_score), 1),
    round(avg(l.overall_esg_score), 1)
  from public.supplier_esg_r3710 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3710_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.supplier_esg_capa_actions_r3710 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3710_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.supplier_esg_capa_actions_r3710)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.supplier_esg_capa_actions_r3710 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) ESG risk-area digest
create or replace function public.founder_r3710_risk_digest()
returns table(esg_risk_area text, actions bigint, open_actions bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.esg_risk_area, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.supplier_esg_capa_actions_r3710 c
  group by c.esg_risk_area
  order by count(*) desc;
end;
$$;

-- 8) High-risk supplier queue
create or replace function public.founder_r3710_high_risk_queue()
returns table(
  supplier_code text,
  supplier_name text,
  supply_category text,
  criticality text,
  esg_status text,
  trend_dir text,
  overall_esg_score numeric,
  corrective_plans_open int,
  reassessment_due date,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_code, l.supplier_name, l.supply_category, l.criticality,
    l.esg_status, l.trend_dir, l.overall_esg_score, l.corrective_plans_open,
    l.reassessment_due, l.notes
  from public.supplier_esg_r3710 l
  where l.esg_status in ('high_risk','not_assessed')
     or l.trend_dir = 'worsening'
     or l.child_labor_declaration = false
     or l.corrective_plans_open >= 3
  order by l.period_month desc, l.supplier_name;
end;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================
revoke all on function public.founder_r3710_esg_status_rollup() from public, anon;
revoke all on function public.founder_r3710_supply_category_scorecard() from public, anon;
revoke all on function public.founder_r3710_criticality_status_matrix() from public, anon;
revoke all on function public.founder_r3710_monthly_score_trend() from public, anon;
revoke all on function public.founder_r3710_capa_status_board() from public, anon;
revoke all on function public.founder_r3710_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3710_risk_digest() from public, anon;
revoke all on function public.founder_r3710_high_risk_queue() from public, anon;

grant execute on function public.founder_r3710_esg_status_rollup() to authenticated;
grant execute on function public.founder_r3710_supply_category_scorecard() to authenticated;
grant execute on function public.founder_r3710_criticality_status_matrix() to authenticated;
grant execute on function public.founder_r3710_monthly_score_trend() to authenticated;
grant execute on function public.founder_r3710_capa_status_board() to authenticated;
grant execute on function public.founder_r3710_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3710_risk_digest() to authenticated;
grant execute on function public.founder_r3710_high_risk_queue() to authenticated;

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

  -- 16 supplier ESG assessment rows
  insert into public.supplier_esg_r3710 (
    organization_id, supplier_code, supplier_name, supply_category, period_month,
    esg_assessed, assessment_date, env_score, social_score, governance_score,
    overall_esg_score, child_labor_declaration, conflict_minerals_declared,
    corrective_plans_open, reassessment_due, criticality, esg_status, trend_dir, notes
  )
  select v_org_id, q.scode, q.sname, q.scat, q.pmon::date,
    q.assessed, q.adate::date, q.envs, q.socs, q.govs,
    q.ovrs, q.childd, q.confd,
    q.cpo, q.rdue::date, q.crit, q.est, q.tdir, q.nt
  from (values
    ('SUP-ELC-001','Sunrise Electronics Chennai','electronic_components','2026-07-01',
     true,'2026-07-08',82.5,86.0,88.5,85.7,true,true,0,'2027-07-08','critical','leader','improving','ISO 14001 + SA8000 certified; solar-powered SMT lines'),
    ('SUP-PCB-002','Deccan PCB Assemblies Pune','pcb_assembly','2026-07-01',
     true,'2026-07-10',74.0,78.5,80.0,77.5,true,true,1,'2027-01-10','critical','compliant','stable','Effluent recycling live; one packaging CAPA open'),
    ('SUP-MCH-003','Sri Venkateswara Precision Works','precision_machining','2026-07-01',
     true,'2026-07-06',58.5,62.0,55.0,58.5,true,false,3,'2026-10-06','critical','improvement_needed','improving','Conflict-minerals declaration pending; coolant disposal upgrade underway'),
    ('SUP-PLS-004','Ganga Polymers Vapi','plastics_polymers','2026-07-01',
     true,'2026-07-12',41.0,52.5,48.0,47.2,true,false,4,'2026-09-12','major','high_risk','worsening','Untreated effluent finding at Vapi unit; GPCB notice risk'),
    ('SUP-PKG-005','Kaveri Packaging Industries','packaging','2026-07-01',
     true,'2026-07-05',68.0,71.5,66.0,68.5,true,true,2,'2026-12-05','standard','compliant','improving','Shifting to FSC-certified corrugates by Q3'),
    ('SUP-CST-006','Jyoti Metal Castings Rajkot','castings_metals','2026-07-01',
     true,'2026-07-09',49.5,44.0,50.5,48.0,false,false,5,'2026-09-09','major','high_risk','worsening','Child-labor declaration not signed; labor audit gaps at foundry'),
    ('SUP-STR-007','Medisteril Sterilization Services','sterilization_services','2026-07-01',
     true,'2026-07-11',77.0,80.0,83.5,80.2,true,true,0,'2027-07-11','critical','leader','stable','EtO emissions scrubber validated; zero open findings'),
    ('SUP-LOG-008','Trident Logistics India','logistics_distribution','2026-07-01',
     false,null,null,null,null,null,false,false,0,'2026-08-15','standard','not_assessed','stable','Assessment questionnaire not returned; second reminder sent'),
    ('SUP-TXT-009','Arvind Surgical Textiles','surgical_textiles','2026-07-01',
     true,'2026-07-07',64.5,59.0,61.0,61.5,true,true,2,'2026-11-07','major','improvement_needed','stable','Worker grievance mechanism being set up at Bhiwandi unit'),
    ('SUP-ELC-010','Bharat Micro Components Bengaluru','electronic_components','2026-06-01',
     true,'2026-06-18',79.5,75.0,72.5,75.7,true,true,1,'2027-06-18','major','compliant','improving','RoHS + REACH data complete; governance disclosures thin'),
    ('SUP-PLS-011','Meditube Extrusions Ahmedabad','plastics_polymers','2026-06-01',
     true,'2026-06-20',55.0,60.5,58.0,57.8,true,false,3,'2026-09-20','critical','improvement_needed','improving','Regrind traceability CAPA open; conflict-minerals scope under review'),
    ('SUP-PKG-012','GreenPack Corrugates Hosur','packaging','2026-06-01',
     true,'2026-06-15',72.5,68.0,65.5,68.7,true,true,1,'2026-12-15','low_risk','compliant','stable','Recycled-content share at 62 percent'),
    ('SUP-MCH-013','Precitech Toolings Rajkot','precision_machining','2026-06-01',
     true,'2026-06-22',38.5,42.0,36.0,38.8,false,false,6,'2026-08-22','major','high_risk','worsening','Failed social audit — overtime records missing; escalated to sourcing council'),
    ('SUP-STR-014','SteriGamma Irradiation Vashi','sterilization_services','2026-06-01',
     true,'2026-06-25',70.0,73.5,76.0,73.2,true,true,1,'2027-06-25','critical','compliant','stable','AERB compliance current; one energy-audit action open'),
    ('SUP-CST-015','Shakti Alloys Coimbatore','castings_metals','2026-06-01',
     false,null,null,null,null,null,true,false,0,'2026-08-30','major','not_assessed','worsening','New supplier onboarded; baseline ESG assessment overdue'),
    ('SUP-PCB-016','Nova Circuit Boards Noida','pcb_assembly','2026-06-01',
     true,'2026-06-12',66.5,64.0,70.5,67.0,true,true,2,'2026-12-12','standard','improvement_needed','improving','Solder-dross recycling contract signed; social score lagging')
  ) as q(scode, sname, scat, pmon, assessed, adate, envs, socs, govs, ovrs, childd, confd, cpo, rdue, crit, est, tdir, nt);

  -- 8 CAPA rows — attach to specific assessments via supplier_code
  insert into public.supplier_esg_capa_actions_r3710 (
    assessment_id, finding_category, root_cause, corrective_action,
    capa_status, esg_risk_area, target_closure_date, actual_closure_date,
    estimated_cost_rupees, owner, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.era, q.tcd::date, q.acd::date,
    q.cost, q.own, q.nt
  from (values
    ('SUP-PLS-004','environmental_noncompliance','untreated_effluent_discharge','effluent_treatment_upgrade','escalated','regulatory','2026-08-20',null,1850000.00,'Rohit Kulkarni (Sourcing)','ETP upgrade quote approved; GPCB pre-notice risk flagged to leadership'),
    ('SUP-CST-006','declaration_missing','labor_records_gap','third_party_social_audit','in_progress','social','2026-08-25',null,240000.00,'Priya Nair (Sustainability)','SA8000-lead auditor engaged for foundry labor audit'),
    ('SUP-MCH-013','social_noncompliance','labor_records_gap','escalate_to_sourcing_council','open','reputational','2026-08-18',null,0.00,'Rohit Kulkarni (Sourcing)','Overtime records missing — supplier hold recommended pending council review'),
    ('SUP-LOG-008','assessment_overdue','questionnaire_not_returned','esg_policy_rollout','open','supply_continuity','2026-08-15',null,35000.00,'Anita Deshmukh (SCM Excellence)','Onboarding workshop scheduled; questionnaire walkthrough planned'),
    ('SUP-MCH-003','declaration_missing','conflict_minerals_data_missing','collect_smelter_declarations','verification_pending','regulatory','2026-08-10',null,60000.00,'Priya Nair (Sustainability)','CMRT received from 3 of 4 smelters — final chase underway'),
    ('SUP-TXT-009','social_noncompliance','no_grievance_mechanism','grievance_mechanism_setup','in_progress','social','2026-09-05',null,120000.00,'Anita Deshmukh (SCM Excellence)','Worker helpline vendor shortlisted for Bhiwandi unit'),
    ('SUP-ELC-010','governance_gap','board_disclosure_gap','governance_disclosure_training','closed','governance','2026-07-15','2026-07-11',45000.00,'Priya Nair (Sustainability)','Disclosure workshop completed; FY26 BRSR-lite pack submitted'),
    ('SUP-PLS-011','score_deterioration','packaging_waste_excess','packaging_redesign','overdue','environment','2026-07-30',null,310000.00,'Rohit Kulkarni (Sourcing)','Regrind-friendly tray redesign delayed by tooling lead time')
  ) as q(scode, fc, rc, ca, cst, era, tcd, acd, cost, own, nt)
  join public.supplier_esg_r3710 e
    on e.organization_id = v_org_id and e.supplier_code = q.scode;
end;
$seed$;
