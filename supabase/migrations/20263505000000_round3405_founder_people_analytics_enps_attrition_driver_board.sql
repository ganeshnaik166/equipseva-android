-- Round 3405: Founder People-Analytics eNPS & Attrition-Driver Board
-- EquipSeva HR governance — department × cohort × period_quarter × eNPS × attrition × regretted attrition × engagement × absenteeism × internal mobility × flight risk × people verdict × retention CAPA

-- =============================================================================
-- TABLE 1: people_analytics_enps_r3405 — per department/cohort/period people metrics
-- =============================================================================
create table if not exists public.people_analytics_enps_r3405 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cohort_code text not null,
  department text not null check (department in (
    'field_engineering','office_ops','sales','finance','leadership','support'
  )),
  cohort text not null check (cohort in (
    'tenure_0_1yr','tenure_1_3yr','tenure_3_5yr','tenure_5plus','all'
  )),
  period_quarter text not null,
  headcount int not null,
  enps_score int not null check (enps_score between -100 and 100),
  attrition_pct numeric(5,2),
  regretted_attrition_pct numeric(5,2),
  avg_tenure_years numeric(5,2),
  top_attrition_driver text not null check (top_attrition_driver in (
    'compensation','growth','manager','workload','commute','role_fit','better_offer'
  )),
  engagement_index numeric(5,2),
  absenteeism_pct numeric(5,2),
  internal_mobility_pct numeric(5,2),
  flight_risk_count int not null default 0,
  people_verdict text not null check (people_verdict in (
    'healthy','watch','retention_action','manager_intervention','comp_review','culture_risk'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.people_analytics_enps_r3405 enable row level security;

create index if not exists idx_people_analytics_enps_r3405_org on public.people_analytics_enps_r3405(organization_id);
create index if not exists idx_people_analytics_enps_r3405_dept on public.people_analytics_enps_r3405(department);
create index if not exists idx_people_analytics_enps_r3405_verdict on public.people_analytics_enps_r3405(people_verdict);

-- =============================================================================
-- TABLE 2: people_analytics_enps_capa_actions_r3405 — retention & engagement CAPA
-- =============================================================================
create table if not exists public.people_analytics_enps_capa_actions_r3405 (
  id uuid primary key default gen_random_uuid(),
  people_row_id uuid not null references public.people_analytics_enps_r3405(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'high_attrition','low_enps','regretted_loss_spike','engagement_decline','high_absenteeism',
    'flight_risk_concentration','low_internal_mobility','comp_below_market','manager_effectiveness_gap','onboarding_ramp_issue'
  )),
  root_cause text not null check (root_cause in (
    'compensation_gap','career_growth_stall','manager_quality','workload_burnout','commute_relocation',
    'role_misfit','external_offer_pull','culture_misalignment','pending_investigation','recognition_deficit'
  )),
  corrective_action text not null check (corrective_action in (
    'comp_band_revision','career_pathing_program','manager_coaching','workload_rebalancing','hybrid_flex_policy',
    'role_redesign','retention_bonus','stay_interview_program','recognition_program','engagement_survey_followup','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  people_impact text not null check (people_impact in (
    'attrition_reduction','engagement_lift','comp_correction','culture_health','manager_capability','dei_inclusion','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.people_analytics_enps_capa_actions_r3405 enable row level security;

create index if not exists idx_people_analytics_enps_capa_r3405_row on public.people_analytics_enps_capa_actions_r3405(people_row_id);
create index if not exists idx_people_analytics_enps_capa_r3405_status on public.people_analytics_enps_capa_actions_r3405(capa_status);

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

  -- 14 people-analytics rows
  insert into public.people_analytics_enps_r3405 (
    organization_id, cohort_code, department, cohort, period_quarter, headcount,
    enps_score, attrition_pct, regretted_attrition_pct, avg_tenure_years, top_attrition_driver,
    engagement_index, absenteeism_pct, internal_mobility_pct, flight_risk_count, people_verdict, notes
  )
  select v_org_id, q.code, q.dept, q.cohort, q.pq, q.hc,
    q.enps, q.attr, q.reg, q.tenure, q.driver,
    q.eng, q.absent, q.mobility, q.flight, q.verdict, q.nt
  from (values
    ('FE-0Y-Q1','field_engineering','tenure_0_1yr','FY26-Q1',62,
     22,24.0,11.0,0.6,'commute',68.0,4.1,3.0,9,'retention_action','New field engineers churning early — long commutes to hospital sites'),
    ('FE-1Y-Q1','field_engineering','tenure_1_3yr','FY26-Q1',88,
     41,11.5,5.5,1.9,'better_offer',75.0,3.0,9.0,6,'watch','Mid-tenure field engineers poached by OEM competitors'),
    ('FE-ALL-Q1','field_engineering','all','FY26-Q1',240,
     36,14.2,7.1,2.8,'commute',73.0,3.4,7.5,18,'watch','Overall FE health stable; commute is top exit reason'),
    ('SL-0Y-Q1','sales','tenure_0_1yr','FY26-Q1',34,
     -8,33.0,18.0,0.5,'compensation',58.0,5.2,2.0,11,'comp_review','Early sales attrition high — variable pay below market'),
    ('SL-3Y-Q1','sales','tenure_3_5yr','FY26-Q1',26,
     12,15.0,9.0,3.8,'better_offer',66.0,3.9,6.0,7,'retention_action','Tenured AEs leaving for larger medtech firms'),
    ('OO-ALL-Q1','office_ops','all','FY26-Q1',54,
     48,7.0,3.0,3.6,'role_fit',80.0,2.4,12.0,3,'healthy','Office ops engaged and stable'),
    ('FN-1Y-Q1','finance','tenure_1_3yr','FY26-Q1',18,
     30,9.0,4.5,2.2,'growth',71.0,2.8,5.0,2,'watch','Finance analysts want a clearer growth ladder'),
    ('SP-0Y-Q1','support','tenure_0_1yr','FY26-Q1',40,
     5,28.0,13.0,0.7,'workload',61.0,6.1,4.0,12,'manager_intervention','Support new-hires burning out on ticket volume; team-lead spans too wide'),
    ('SP-ALL-Q1','support','all','FY26-Q1',96,
     27,18.5,8.8,2.1,'workload',67.0,4.7,6.5,20,'retention_action','Support workload and shift patterns driving exits'),
    ('LD-5Y-Q1','leadership','tenure_5plus','FY26-Q1',12,
     55,4.0,2.0,6.4,'growth',82.0,1.5,15.0,1,'healthy','Senior leadership retention strong'),
    ('FE-5Y-Q1','field_engineering','tenure_5plus','FY26-Q1',44,
     44,6.5,3.2,6.8,'manager',76.0,2.9,10.0,4,'watch','Veteran field engineers cite regional-manager friction'),
    ('FN-ALL-Q1','finance','all','FY26-Q1',30,
     -20,21.0,12.0,2.5,'manager',54.0,5.5,3.5,8,'culture_risk','Finance eNPS negative — manager style and trust concerns flagged in survey'),
    ('SL-ALL-Q2','sales','all','FY26-Q2',74,
     18,19.0,10.5,2.4,'compensation',63.0,4.3,5.5,15,'comp_review','Q2 sales comp plan under review after regretted losses'),
    ('FE-ALL-Q2','field_engineering','all','FY26-Q2',246,
     39,13.0,6.4,2.9,'commute',74.0,3.3,8.0,16,'watch','Q2 FE stabilising after commute-allowance pilot')
  ) as q(code, dept, cohort, pq, hc, enps, attr, reg, tenure, driver, eng, absent, mobility, flight, verdict, nt);

  -- CAPA seed — attach to specific at-risk cohorts via cohort_code
  insert into public.people_analytics_enps_capa_actions_r3405 (
    people_row_id, finding_category, root_cause, corrective_action,
    capa_status, people_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FE-0Y-Q1','high_attrition','commute_relocation','hybrid_flex_policy','in_progress','attrition_reduction','2026-08-15',null,450000.00,'Commute allowance + regional-hub pilot for new field engineers'),
    ('SL-0Y-Q1','comp_below_market','compensation_gap','comp_band_revision','open','comp_correction','2026-08-30',null,1200000.00,'Revise SDR/AE variable-pay bands to 60th percentile'),
    ('SP-0Y-Q1','high_absenteeism','workload_burnout','workload_rebalancing','escalated','engagement_lift','2026-08-10',null,300000.00,'Add support headcount and cap ticket load; manager span reduced'),
    ('SP-ALL-Q1','high_attrition','workload_burnout','stay_interview_program','verification_pending','attrition_reduction','2026-07-31',null,150000.00,'Stay interviews rolled out — verify retention next cycle'),
    ('FN-ALL-Q1','low_enps','manager_quality','manager_coaching','overdue','manager_capability','2026-07-10',null,250000.00,'Manager coaching past target — escalated to HR head'),
    ('SL-ALL-Q2','regretted_loss_spike','external_offer_pull','retention_bonus','in_progress','attrition_reduction','2026-09-01',null,800000.00,'Targeted retention bonuses for top-quartile AEs'),
    ('SL-3Y-Q1','high_attrition','career_growth_stall','career_pathing_program','closed','engagement_lift','2026-06-30','2026-06-25',200000.00,'Career ladder + IC/manager tracks launched for tenured sales')
  ) as q(code, fc, rc, ca, cst, imp, tcd, acd, cost, nt)
  join public.people_analytics_enps_r3405 e
    on e.organization_id = v_org_id and e.cohort_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) People verdict distribution
create or replace function public.founder_r3405_people_verdict_rollup()
returns table(people_verdict text, cohorts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.people_analytics_enps_r3405)
  select l.people_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.people_analytics_enps_r3405 l
  group by l.people_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3405_people_verdict_rollup() from public, anon;
grant execute on function public.founder_r3405_people_verdict_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3405_department_scorecard()
returns table(
  department text,
  cohort_rows bigint,
  total_headcount bigint,
  avg_enps numeric,
  avg_attrition_pct numeric,
  avg_regretted_pct numeric,
  avg_engagement numeric,
  flight_risk bigint,
  action_rows bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    coalesce(sum(l.headcount),0)::bigint,
    round(avg(l.enps_score), 1),
    round(avg(l.attrition_pct), 1),
    round(avg(l.regretted_attrition_pct), 1),
    round(avg(l.engagement_index), 1),
    coalesce(sum(l.flight_risk_count),0)::bigint,
    count(*) filter (where l.people_verdict in ('retention_action','manager_intervention','comp_review','culture_risk'))::bigint
  from public.people_analytics_enps_r3405 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3405_department_scorecard() from public, anon;
grant execute on function public.founder_r3405_department_scorecard() to authenticated;

-- 3) Department × cohort matrix
create or replace function public.founder_r3405_department_cohort_matrix()
returns table(
  department text,
  cohort text,
  rows_count bigint,
  total_headcount bigint,
  avg_enps numeric,
  avg_attrition_pct numeric,
  avg_tenure_years numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department, l.cohort, count(*)::bigint,
    coalesce(sum(l.headcount),0)::bigint,
    round(avg(l.enps_score), 1),
    round(avg(l.attrition_pct), 1),
    round(avg(l.avg_tenure_years), 1)
  from public.people_analytics_enps_r3405 l
  group by l.department, l.cohort
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3405_department_cohort_matrix() from public, anon;
grant execute on function public.founder_r3405_department_cohort_matrix() to authenticated;

-- 4) Quarterly people trend
create or replace function public.founder_r3405_quarterly_trend()
returns table(
  period_quarter text,
  cohort_rows bigint,
  total_headcount bigint,
  avg_enps numeric,
  avg_attrition_pct numeric,
  avg_engagement numeric,
  flight_risk bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_quarter,
    count(*)::bigint,
    coalesce(sum(l.headcount),0)::bigint,
    round(avg(l.enps_score), 1),
    round(avg(l.attrition_pct), 1),
    round(avg(l.engagement_index), 1),
    coalesce(sum(l.flight_risk_count),0)::bigint
  from public.people_analytics_enps_r3405 l
  group by l.period_quarter
  order by l.period_quarter desc;
end;
$$;

revoke execute on function public.founder_r3405_quarterly_trend() from public, anon;
grant execute on function public.founder_r3405_quarterly_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3405_capa_status_board()
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
  from public.people_analytics_enps_capa_actions_r3405 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3405_capa_status_board() from public, anon;
grant execute on function public.founder_r3405_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3405_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.people_analytics_enps_capa_actions_r3405)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.people_analytics_enps_capa_actions_r3405 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3405_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3405_root_cause_pareto() to authenticated;

-- 7) People-impact digest
create or replace function public.founder_r3405_people_impact_digest()
returns table(people_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.people_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.people_analytics_enps_capa_actions_r3405 c
  group by c.people_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3405_people_impact_digest() from public, anon;
grant execute on function public.founder_r3405_people_impact_digest() to authenticated;

-- 8) High-risk cohort queue (top individual concerns)
create or replace function public.founder_r3405_high_risk_queue()
returns table(
  department text,
  cohort text,
  period_quarter text,
  headcount int,
  enps_score int,
  attrition_pct numeric,
  people_verdict text,
  top_attrition_driver text,
  flight_risk_count int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department, l.cohort, l.period_quarter, l.headcount, l.enps_score,
    l.attrition_pct, l.people_verdict, l.top_attrition_driver, l.flight_risk_count, l.notes
  from public.people_analytics_enps_r3405 l
  where l.people_verdict in ('watch','retention_action','manager_intervention','comp_review','culture_risk')
     or l.enps_score < 0
     or l.attrition_pct >= 15.0
     or l.regretted_attrition_pct >= 8.0
     or l.flight_risk_count >= 10
  order by l.period_quarter desc, l.attrition_pct desc, l.department;
end;
$$;

revoke execute on function public.founder_r3405_high_risk_queue() from public, anon;
grant execute on function public.founder_r3405_high_risk_queue() to authenticated;
