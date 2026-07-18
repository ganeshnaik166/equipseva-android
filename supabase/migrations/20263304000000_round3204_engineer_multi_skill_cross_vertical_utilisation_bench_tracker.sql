-- Round 3204: Engineer Multi-Skill Cross-Vertical Utilisation & Bench-Time Tracker
-- Weekly engineer utilisation log — primary vertical × secondary verticals × billable/bench hours × cross-vertical jobs × skill-gap requests × CAPA

-- =============================================================================
-- TABLE 1: skill_utilisation_r3204 — weekly engineer utilisation snapshots
-- =============================================================================
create table if not exists public.skill_utilisation_r3204 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  engineer_code text not null,
  primary_vertical text not null check (primary_vertical in (
    'imaging_radiology','critical_care_icu','ot_anesthesia','lab_diagnostics',
    'dialysis_nephrology','sterilization_cssd','endoscopy_gi','biomedical_general'
  )),
  secondary_verticals_count int not null default 0,
  week_start_date date not null,
  billable_hours numeric(6,2) not null,
  bench_hours numeric(6,2) not null,
  utilisation_pct numeric(5,2) not null,
  cross_vertical_jobs int not null default 0,
  skill_gap_requested text not null check (skill_gap_requested in (
    'none','ventilator_certification','ct_tube_replacement','dialysis_ro_plant',
    'endoscope_reprocessing','anesthesia_workstation','autoclave_validation','defibrillator_service'
  )),
  utilisation_verdict text not null check (utilisation_verdict in (
    'well_utilised','under_utilised','over_utilised','bench_heavy','cross_trained_star','skill_gap_blocked'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.skill_utilisation_r3204 enable row level security;

create index if not exists idx_skill_util_r3204_org on public.skill_utilisation_r3204(organization_id);
create index if not exists idx_skill_util_r3204_week on public.skill_utilisation_r3204(week_start_date);
create index if not exists idx_skill_util_r3204_verdict on public.skill_utilisation_r3204(utilisation_verdict);

-- =============================================================================
-- TABLE 2: skill_utilisation_capa_actions_r3204 — CAPA & utilisation actions
-- =============================================================================
create table if not exists public.skill_utilisation_capa_actions_r3204 (
  id uuid primary key default gen_random_uuid(),
  utilisation_id uuid not null references public.skill_utilisation_r3204(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'bench_time_excess','utilisation_below_target','skill_gap_unaddressed',
    'cross_vertical_overload','single_vertical_dependency','training_overdue',
    'certification_lapsed','scheduling_conflict'
  )),
  root_cause text not null check (root_cause in (
    'demand_seasonality','territory_overlap','training_budget_freeze',
    'certification_backlog','dispatch_algorithm_bias','vertical_demand_shift',
    'engineer_attrition_coverage','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'enroll_cross_training','rebalance_territory','update_dispatch_weights',
    'sponsor_oem_certification','reassign_primary_vertical','hire_additional_engineer',
    'mentor_pairing','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'none','internal_only','nabh_finding','iso_13485_deviation','oem_warranty_risk','contract_sla_breach'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.skill_utilisation_capa_actions_r3204 enable row level security;

create index if not exists idx_skill_util_capa_r3204_util on public.skill_utilisation_capa_actions_r3204(utilisation_id);
create index if not exists idx_skill_util_capa_r3204_status on public.skill_utilisation_capa_actions_r3204(capa_status);

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

  -- 14 engineer-week utilisation rows
  insert into public.skill_utilisation_r3204 (
    organization_id, hospital_name, engineer_name, engineer_code,
    primary_vertical, secondary_verticals_count, week_start_date,
    billable_hours, bench_hours, utilisation_pct, cross_vertical_jobs,
    skill_gap_requested, utilisation_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.code,
    q.pv, q.svc, q.wk::date,
    q.bh, q.bnh, q.up, q.cvj,
    q.sgr, q.uv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ravi Kiran','ENG-HYD-001','imaging_radiology',2,'2026-07-06',38.50,3.50,91.67,4,'none','cross_trained_star','CT + cath-lab + ventilator certified — top utilisation'),
    ('Apollo Hyderabad Jubilee Hills','Sneha Reddy','ENG-HYD-002','critical_care_icu',1,'2026-07-06',30.00,12.00,71.43,1,'ct_tube_replacement','under_utilised','Requested CT tube swap training to absorb imaging overflow'),
    ('Fortis Bannerghatta Bengaluru','Arun Prasad','ENG-BLR-004','ot_anesthesia',0,'2026-07-06',18.00,24.00,42.86,0,'anesthesia_workstation','bench_heavy','Single-vertical engineer — OT demand dipped this week'),
    ('Fortis Bannerghatta Bengaluru','Divya Nair','ENG-BLR-005','lab_diagnostics',2,'2026-07-06',41.00,1.00,97.62,5,'none','over_utilised','Covering two territories — burnout risk flagged'),
    ('Manipal Whitefield Bengaluru','Karthik Rao','ENG-BLR-009','dialysis_nephrology',1,'2026-06-29',35.00,7.00,83.33,2,'dialysis_ro_plant','well_utilised','RO plant validation cert would unlock AMC upsell'),
    ('Manipal Whitefield Bengaluru','Meera Iyer','ENG-BLR-010','sterilization_cssd',1,'2026-06-29',26.00,16.00,61.90,1,'autoclave_validation','under_utilised','CSSD load seasonal — cross-train into endoscopy'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','ENG-DEL-002','imaging_radiology',3,'2026-06-29',39.00,3.00,92.86,6,'none','cross_trained_star','MRI + CT + ultrasound + endoscopy — highest cross-vertical jobs'),
    ('AIIMS New Delhi Ansari Nagar','Pooja Sharma','ENG-DEL-003','biomedical_general',0,'2026-06-29',20.00,22.00,47.62,0,'ventilator_certification','skill_gap_blocked','Blocked from ICU tickets pending ventilator certification'),
    ('KIMS Secunderabad','Suresh Babu','ENG-HYD-007','endoscopy_gi',1,'2026-06-22',33.50,8.50,79.76,2,'endoscope_reprocessing','well_utilised','Reprocessing cert renewal due next month'),
    ('KIMS Secunderabad','Anita Kumari','ENG-HYD-008','critical_care_icu',2,'2026-06-22',37.00,5.00,88.10,3,'none','well_utilised','Ventilator + dialysis cross-cover working well'),
    ('Care Hospitals Banjara Hills','Rahul Verma','ENG-HYD-012','lab_diagnostics',0,'2026-06-22',15.00,27.00,35.71,0,'ct_tube_replacement','bench_heavy','Lab analyzer AMC lapsed — bench spike; wants imaging pivot'),
    ('Yashoda Somajiguda Hyderabad','Lakshmi Devi','ENG-HYD-015','ot_anesthesia',2,'2026-06-15',36.00,6.00,85.71,3,'none','well_utilised','OT + CSSD + biomedical rotation stable'),
    ('St John''s Bengaluru','Joseph Mathew','ENG-BLR-014','biomedical_general',1,'2026-06-15',29.00,13.00,69.05,1,'defibrillator_service','under_utilised','Defib service cert would absorb cardiology backlog'),
    ('Rainbow Children''s Hyderabad','Farhan Ali','ENG-HYD-019','critical_care_icu',1,'2026-06-15',40.00,2.00,95.24,2,'none','over_utilised','NICU demand surge — needs second engineer coverage')
  ) as q(hosp, eng, code, pv, svc, wk, bh, bnh, up, cvj, sgr, uv, nt);

  -- CAPA seed — attach to specific engineer-weeks by engineer_code
  insert into public.skill_utilisation_capa_actions_r3204 (
    utilisation_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('ENG-BLR-004','bench_time_excess','vertical_demand_shift','enroll_cross_training','2026-07-25',null,'in_progress','internal_only',35000.00,'Anesthesia workstation cross-training batch starts 20 Jul'),
    ('ENG-DEL-003','skill_gap_unaddressed','training_budget_freeze','sponsor_oem_certification','2026-07-30',null,'escalated','contract_sla_breach',85000.00,'ICU SLA at AIIMS at risk — ventilator cert sponsorship escalated to founder'),
    ('ENG-HYD-012','bench_time_excess','demand_seasonality','rebalance_territory','2026-07-20',null,'open','none',0.00,'Move two Banjara Hills lab accounts to shared pool'),
    ('ENG-BLR-005','cross_vertical_overload','engineer_attrition_coverage','hire_additional_engineer','2026-08-15',null,'in_progress','oem_warranty_risk',120000.00,'Backfill req raised — warranty jobs slipping past OEM window'),
    ('ENG-HYD-002','utilisation_below_target','dispatch_algorithm_bias','update_dispatch_weights','2026-07-12','2026-07-10','closed','internal_only',0.00,'Dispatch now weights secondary-vertical certified engineers'),
    ('ENG-BLR-010','training_overdue','certification_backlog','enroll_cross_training','2026-07-22',null,'verification_pending','iso_13485_deviation',28000.00,'Autoclave validation course completed — awaiting assessment'),
    ('ENG-HYD-019','cross_vertical_overload','vertical_demand_shift','hire_additional_engineer','2026-08-01',null,'open','contract_sla_breach',110000.00,'NICU surge — second ICU engineer for Rainbow cluster')
  ) as q(code, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.skill_utilisation_r3204 e
    on e.organization_id = v_org_id and e.engineer_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Utilisation verdict distribution
create or replace function public.founder_r3204_verdict_rollup()
returns table(utilisation_verdict text, engineer_weeks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.skill_utilisation_r3204)
  select l.utilisation_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.skill_utilisation_r3204 l
  group by l.utilisation_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3204_verdict_rollup() from public, anon;
grant execute on function public.founder_r3204_verdict_rollup() to authenticated;

-- 2) Hospital utilisation scorecard
create or replace function public.founder_r3204_hospital_scorecard()
returns table(
  hospital_name text,
  engineer_weeks bigint,
  avg_utilisation_pct numeric,
  total_billable_hours numeric,
  total_bench_hours numeric,
  cross_vertical_jobs bigint,
  skill_gaps_requested bigint
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
    round(avg(l.utilisation_pct), 1),
    coalesce(sum(l.billable_hours),0)::numeric,
    coalesce(sum(l.bench_hours),0)::numeric,
    coalesce(sum(l.cross_vertical_jobs),0)::bigint,
    count(*) filter (where l.skill_gap_requested <> 'none')::bigint
  from public.skill_utilisation_r3204 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3204_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3204_hospital_scorecard() to authenticated;

-- 3) Primary vertical matrix
create or replace function public.founder_r3204_vertical_matrix()
returns table(
  primary_vertical text,
  engineer_weeks bigint,
  avg_utilisation_pct numeric,
  avg_secondary_verticals numeric,
  cross_vertical_jobs bigint,
  bench_heavy bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.primary_vertical,
    count(*)::bigint,
    round(avg(l.utilisation_pct), 1),
    round(avg(l.secondary_verticals_count)::numeric, 2),
    coalesce(sum(l.cross_vertical_jobs),0)::bigint,
    count(*) filter (where l.utilisation_verdict in ('bench_heavy','under_utilised'))::bigint
  from public.skill_utilisation_r3204 l
  group by l.primary_vertical
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3204_vertical_matrix() from public, anon;
grant execute on function public.founder_r3204_vertical_matrix() to authenticated;

-- 4) Weekly utilisation trend
create or replace function public.founder_r3204_weekly_trend()
returns table(
  week_start_date date,
  engineer_weeks bigint,
  avg_utilisation_pct numeric,
  total_billable_hours numeric,
  total_bench_hours numeric,
  cross_vertical_jobs bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.week_start_date,
    count(*)::bigint,
    round(avg(l.utilisation_pct), 1),
    coalesce(sum(l.billable_hours),0)::numeric,
    coalesce(sum(l.bench_hours),0)::numeric,
    coalesce(sum(l.cross_vertical_jobs),0)::bigint
  from public.skill_utilisation_r3204 l
  group by l.week_start_date
  order by l.week_start_date desc;
end;
$$;

revoke execute on function public.founder_r3204_weekly_trend() from public, anon;
grant execute on function public.founder_r3204_weekly_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3204_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, escalated_or_overdue bigint)
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
  from public.skill_utilisation_capa_actions_r3204 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3204_capa_status_board() from public, anon;
grant execute on function public.founder_r3204_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3204_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.skill_utilisation_capa_actions_r3204)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.skill_utilisation_capa_actions_r3204 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3204_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3204_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3204_regulatory_impact_digest()
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
  from public.skill_utilisation_capa_actions_r3204 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3204_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3204_regulatory_impact_digest() to authenticated;

-- 8) Bench-risk & skill-gap queue (top individual concerns)
create or replace function public.founder_r3204_bench_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  engineer_code text,
  week_start_date date,
  primary_vertical text,
  utilisation_pct numeric,
  bench_hours numeric,
  skill_gap_requested text,
  utilisation_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.engineer_code, l.week_start_date,
    l.primary_vertical, l.utilisation_pct, l.bench_hours, l.skill_gap_requested,
    l.utilisation_verdict, l.notes
  from public.skill_utilisation_r3204 l
  where l.utilisation_verdict in ('under_utilised','over_utilised','bench_heavy','skill_gap_blocked')
     or l.skill_gap_requested <> 'none'
  order by l.week_start_date desc, l.utilisation_pct asc;
end;
$$;

revoke execute on function public.founder_r3204_bench_risk_queue() from public, anon;
grant execute on function public.founder_r3204_bench_risk_queue() to authenticated;
