-- Round 3484: Engineer Technician Onboarding Ramp-Time / Productivity Tracker
-- New field-technician onboarding ramp -> full-productivity tracker — stage progression × ramp status ×
-- days-to-stage vs target × certification pass × job throughput × first-time-fix × region × mentor × CAPA

-- =============================================================================
-- TABLE 1: tech_onboarding_ramp_r3484 — per-technician onboarding ramp progress
-- =============================================================================
create table if not exists public.tech_onboarding_ramp_r3484 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_code text not null,
  engineer_name text not null,
  region text not null,
  hire_date date not null,
  onboarding_stage text not null check (onboarding_stage in (
    'induction','shadowing','supervised','certification','solo_ready','full_productive'
  )),
  days_to_stage int,
  target_days int,
  cert_pass_pct numeric(5,2),
  jobs_completed int,
  first_time_fix_pct numeric(5,2),
  ramp_status text not null check (ramp_status in (
    'ahead','on_track','lagging','at_risk'
  )),
  mentor_name text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tech_onboarding_ramp_r3484 enable row level security;

create index if not exists idx_tech_onboarding_ramp_r3484_org on public.tech_onboarding_ramp_r3484(organization_id);
create index if not exists idx_tech_onboarding_ramp_r3484_hire on public.tech_onboarding_ramp_r3484(hire_date);
create index if not exists idx_tech_onboarding_ramp_r3484_status on public.tech_onboarding_ramp_r3484(ramp_status);

-- =============================================================================
-- TABLE 2: tech_onboarding_ramp_capa_actions_r3484 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.tech_onboarding_ramp_capa_actions_r3484 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  ramp_log_id uuid not null references public.tech_onboarding_ramp_r3484(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'ramp_behind_target','certification_fail','low_first_time_fix','low_job_throughput',
    'stage_stall','mentor_gap','skill_gap','attrition_risk'
  )),
  root_cause text not null check (root_cause in (
    'insufficient_mentorship','training_content_gap','tooling_access_delay','complex_region_mix',
    'personal_capability_gap','onboarding_process_bottleneck','certification_scheduling_delay',
    'workload_overallocation','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'assign_dedicated_mentor','extra_training_module','expedite_tool_provisioning','rebalance_job_allocation',
    'reschedule_certification','shadowing_extension','performance_improvement_plan','escalate_to_regional_lead',
    'none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  ramp_impact_days numeric(6,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tech_onboarding_ramp_capa_actions_r3484 enable row level security;

create index if not exists idx_tech_onboarding_capa_r3484_log on public.tech_onboarding_ramp_capa_actions_r3484(ramp_log_id);
create index if not exists idx_tech_onboarding_capa_r3484_status on public.tech_onboarding_ramp_capa_actions_r3484(capa_status);

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

  -- 16 technician ramp rows
  insert into public.tech_onboarding_ramp_r3484 (
    organization_id, engineer_code, engineer_name, region, hire_date, onboarding_stage,
    days_to_stage, target_days, cert_pass_pct, jobs_completed, first_time_fix_pct,
    ramp_status, mentor_name, notes
  )
  select v_org_id, q.ecode, q.ename, q.rgn, q.hdate::date, q.stg,
    q.dts::int, q.tgt::int, q.cpp::numeric, q.jc::int, q.ftf::numeric,
    q.rs, q.mnt, q.nt
  from (values
    ('TECH-N-001','Arjun Mehta','North','2026-01-12','full_productive',
     82,90,94.5,148,92.0,'ahead','Rakesh Sharma','Reached full productivity 8 days early — strong ramp'),
    ('TECH-N-002','Priya Nair','North','2026-02-03','solo_ready',
     95,90,88.0,96,85.5,'on_track','Rakesh Sharma','Solo-ready on schedule, first-time-fix climbing'),
    ('TECH-S-011','Karthik Iyer','South','2026-02-18','certification',
     70,60,62.0,54,71.0,'lagging','Deepa Menon','Certification attempt below pass mark — retake scheduled'),
    ('TECH-S-012','Lakshmi Rao','South','2026-03-05','supervised',
     48,45,90.0,38,80.0,'on_track','Deepa Menon','Supervised jobs progressing well'),
    ('TECH-W-021','Sameer Joshi','West','2026-01-28','full_productive',
     88,90,96.0,162,90.5,'ahead','Vikram Patel','Top performer in West region ramp cohort'),
    ('TECH-W-022','Neha Kulkarni','West','2026-03-20','shadowing',
     30,25,55.0,12,60.0,'at_risk','Vikram Patel','Shadowing overrun, low cert mock scores — flagged'),
    ('TECH-E-031','Rohan Das','East','2026-02-25','certification',
     68,60,58.5,44,66.0,'at_risk','Anil Kumar','Failed first cert, low first-time-fix — PIP under review'),
    ('TECH-E-032','Ananya Ghosh','East','2026-03-12','supervised',
     50,45,84.0,34,78.5,'on_track','Anil Kumar','Steady supervised progress'),
    ('TECH-C-041','Manish Verma','Central','2026-01-15','full_productive',
     86,90,92.0,140,88.0,'ahead','Sunita Yadav','Reached full productivity ahead of target'),
    ('TECH-C-042','Divya Singh','Central','2026-04-02','induction',
     14,10,null,4,null,'lagging','Sunita Yadav','Induction extended due to tooling access delay'),
    ('TECH-N-003','Vivek Chauhan','North','2026-03-28','shadowing',
     28,25,72.0,10,68.0,'on_track','Rakesh Sharma','Shadowing on track, cert mock passing'),
    ('TECH-S-013','Meera Pillai','South','2026-02-10','solo_ready',
     100,90,86.0,88,82.0,'lagging','Deepa Menon','Solo-ready reached late — throughput below cohort'),
    ('TECH-W-023','Aditya Shah','West','2026-04-10','induction',
     12,10,null,3,null,'on_track','Vikram Patel','Newest West hire, induction nominal'),
    ('TECH-E-033','Sneha Bose','East','2026-01-30','full_productive',
     90,90,91.0,134,89.5,'on_track','Anil Kumar','Hit full productivity exactly on target'),
    ('TECH-C-043','Rahul Nair','Central','2026-03-01','certification',
     65,60,60.5,48,64.0,'at_risk','Sunita Yadav','Low cert pass and low first-time-fix — high attrition risk'),
    ('TECH-N-004','Pooja Reddy','North','2026-04-05','supervised',
     52,45,89.0,30,76.0,'lagging','Rakesh Sharma','Supervised stage overrun — workload rebalancing needed')
  ) as q(ecode, ename, rgn, hdate, stg, dts, tgt, cpp, jc, ftf, rs, mnt, nt);

  -- CAPA seed — attach to specific technicians via engineer_code
  insert into public.tech_onboarding_ramp_capa_actions_r3484 (
    organization_id, ramp_log_id, finding_category, root_cause, corrective_action,
    capa_status, ramp_impact_days, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact::numeric, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('TECH-S-011','certification_fail','training_content_gap','extra_training_module','in_progress',10,'Deepa Menon','2026-08-05',null,'Cert retake prep — supplementary modules assigned'),
    ('TECH-W-022','ramp_behind_target','insufficient_mentorship','assign_dedicated_mentor','open',12,'Vikram Patel','2026-08-10',null,'Shadowing overrun — dedicated mentor assigned'),
    ('TECH-E-031','low_first_time_fix','personal_capability_gap','performance_improvement_plan','escalated',18,'Anil Kumar','2026-08-08',null,'PIP initiated after failed cert and low first-time-fix'),
    ('TECH-C-042','stage_stall','tooling_access_delay','expedite_tool_provisioning','closed',6,'Sunita Yadav','2026-07-20','2026-07-18','Laptop and diagnostic kit provisioned — induction resumed'),
    ('TECH-S-013','low_job_throughput','workload_overallocation','rebalance_job_allocation','verification_pending',9,'Deepa Menon','2026-08-01',null,'Job allocation rebalanced — monitoring throughput'),
    ('TECH-C-043','attrition_risk','onboarding_process_bottleneck','escalate_to_regional_lead','escalated',15,'Sunita Yadav','2026-08-06',null,'High attrition risk — escalated to Central regional lead'),
    ('TECH-N-004','ramp_behind_target','workload_overallocation','rebalance_job_allocation','open',7,'Rakesh Sharma','2026-08-12',null,'Supervised overrun — reducing concurrent job load'),
    ('TECH-E-031','certification_fail','certification_scheduling_delay','reschedule_certification','overdue',20,'Anil Kumar','2026-07-15',null,'Cert reschedule slipped — vendor slot unavailable')
  ) as q(ecode, fc, rc, ca, cst, impact, own, tcd, acd, nt)
  join public.tech_onboarding_ramp_r3484 e
    on e.organization_id = v_org_id and e.engineer_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Ramp status distribution
create or replace function public.founder_r3484_ramp_status_rollup()
returns table(ramp_status text, technicians bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tech_onboarding_ramp_r3484)
  select l.ramp_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.tech_onboarding_ramp_r3484 l
  group by l.ramp_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3484_ramp_status_rollup() from public, anon;
grant execute on function public.founder_r3484_ramp_status_rollup() to authenticated;

-- 2) Region scorecard
create or replace function public.founder_r3484_region_scorecard()
returns table(
  region text,
  technicians bigint,
  ahead bigint,
  on_track bigint,
  lagging bigint,
  at_risk bigint,
  avg_days_to_stage numeric,
  avg_cert_pass_pct numeric,
  avg_first_time_fix_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.ramp_status = 'ahead')::bigint,
    count(*) filter (where l.ramp_status = 'on_track')::bigint,
    count(*) filter (where l.ramp_status = 'lagging')::bigint,
    count(*) filter (where l.ramp_status = 'at_risk')::bigint,
    round(avg(l.days_to_stage), 1),
    round(avg(l.cert_pass_pct), 1),
    round(avg(l.first_time_fix_pct), 1)
  from public.tech_onboarding_ramp_r3484 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3484_region_scorecard() from public, anon;
grant execute on function public.founder_r3484_region_scorecard() to authenticated;

-- 3) Onboarding stage × ramp status matrix
create or replace function public.founder_r3484_stage_ramp_matrix()
returns table(onboarding_stage text, ramp_status text, technicians bigint, avg_days_to_stage numeric, avg_target_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.onboarding_stage, l.ramp_status, count(*)::bigint,
    round(avg(l.days_to_stage), 1),
    round(avg(l.target_days), 1)
  from public.tech_onboarding_ramp_r3484 l
  group by l.onboarding_stage, l.ramp_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3484_stage_ramp_matrix() from public, anon;
grant execute on function public.founder_r3484_stage_ramp_matrix() to authenticated;

-- 4) Monthly ramp trend (by hire month)
create or replace function public.founder_r3484_monthly_ramp_trend()
returns table(hire_month date, hires bigint, ahead bigint, on_track bigint, lagging bigint, at_risk bigint, avg_days_to_stage numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.hire_date)::date,
    count(*)::bigint,
    count(*) filter (where l.ramp_status = 'ahead')::bigint,
    count(*) filter (where l.ramp_status = 'on_track')::bigint,
    count(*) filter (where l.ramp_status = 'lagging')::bigint,
    count(*) filter (where l.ramp_status = 'at_risk')::bigint,
    round(avg(l.days_to_stage), 1)
  from public.tech_onboarding_ramp_r3484 l
  group by date_trunc('month', l.hire_date)
  order by date_trunc('month', l.hire_date) desc;
end;
$$;

revoke execute on function public.founder_r3484_monthly_ramp_trend() from public, anon;
grant execute on function public.founder_r3484_monthly_ramp_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3484_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_days numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.ramp_impact_days)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.tech_onboarding_ramp_capa_actions_r3484 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3484_capa_status_board() from public, anon;
grant execute on function public.founder_r3484_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3484_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_days numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tech_onboarding_ramp_capa_actions_r3484)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.ramp_impact_days),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.tech_onboarding_ramp_capa_actions_r3484 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3484_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3484_root_cause_pareto() to authenticated;

-- 7) Ramp-time impact digest (by finding category)
create or replace function public.founder_r3484_ramp_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_impact_days numeric, avg_impact_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.ramp_impact_days),0)::numeric,
    round(avg(c.ramp_impact_days)::numeric, 1)
  from public.tech_onboarding_ramp_capa_actions_r3484 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3484_ramp_impact_digest() from public, anon;
grant execute on function public.founder_r3484_ramp_impact_digest() to authenticated;

-- 8) High-risk ramp queue (at-risk / lagging / low-cert)
create or replace function public.founder_r3484_high_risk_queue()
returns table(
  engineer_name text,
  engineer_code text,
  region text,
  onboarding_stage text,
  hire_date date,
  days_to_stage int,
  target_days int,
  cert_pass_pct numeric,
  jobs_completed int,
  first_time_fix_pct numeric,
  ramp_status text,
  mentor_name text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.engineer_code, l.region, l.onboarding_stage, l.hire_date,
    l.days_to_stage, l.target_days, l.cert_pass_pct, l.jobs_completed, l.first_time_fix_pct,
    l.ramp_status, l.mentor_name, l.notes
  from public.tech_onboarding_ramp_r3484 l
  where l.ramp_status in ('at_risk','lagging')
     or l.cert_pass_pct < 70
     or l.first_time_fix_pct < 70
     or (l.days_to_stage is not null and l.target_days is not null and l.days_to_stage > l.target_days)
  order by l.hire_date desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3484_high_risk_queue() from public, anon;
grant execute on function public.founder_r3484_high_risk_queue() to authenticated;
