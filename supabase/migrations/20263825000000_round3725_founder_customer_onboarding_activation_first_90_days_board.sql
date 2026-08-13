-- Round 3725: Founder Customer Onboarding Activation — First-90-Days Milestone Board
-- New-customer onboarding journey (0-90 days post contract-sign) — install completion, training
-- completion, first-use activation, steady-state adoption × region × month, with CAPA closure
-- for stalled/at-risk onboardings. Distinct from recurring periodic audit-cycle boards for
-- existing chains — this tracks a NEW customer's one-time onboarding milestone journey.

-- =============================================================================
-- TABLE 1: onboard_90d_r3725 — per-customer first-90-days onboarding milestone facts
-- =============================================================================
create table if not exists public.onboard_90d_r3725 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_name text not null,
  region text not null,
  period_month date not null,
  contract_signed_date date,
  install_completed_date date,
  training_completed_date date,
  first_use_date date,
  days_to_install int,
  days_to_first_use int,
  milestones_completed int,
  milestones_total int,
  on_track boolean not null,
  champion_identified boolean not null,
  adoption_score numeric,
  onboarding_stage text not null check (onboarding_stage in (
    'contracting','install_pending','training_pending','activated','steady_state'
  )),
  onboarding_status text not null check (onboarding_status in (
    'on_track','minor_delay','stalled','at_risk_churn','completed_success'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.onboard_90d_r3725 enable row level security;

create index if not exists idx_onboard_90d_r3725_org on public.onboard_90d_r3725(organization_id);
create index if not exists idx_onboard_90d_r3725_month on public.onboard_90d_r3725(period_month);
create index if not exists idx_onboard_90d_r3725_status on public.onboard_90d_r3725(onboarding_status);

-- =============================================================================
-- TABLE 2: onboard_90d_capa_actions_r3725 — CAPA & remediation actions for stalled onboardings
-- =============================================================================
create table if not exists public.onboard_90d_capa_actions_r3725 (
  id uuid primary key default gen_random_uuid(),
  onboarding_id uuid references public.onboard_90d_r3725(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.onboard_90d_capa_actions_r3725 enable row level security;

create index if not exists idx_onboard_90d_capa_r3725_onb on public.onboard_90d_capa_actions_r3725(onboarding_id);
create index if not exists idx_onboard_90d_capa_r3725_status on public.onboard_90d_capa_actions_r3725(capa_status);

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

  -- 16 onboarding milestone rows
  insert into public.onboard_90d_r3725 (
    organization_id, customer_name, region, period_month,
    contract_signed_date, install_completed_date, training_completed_date, first_use_date,
    days_to_install, days_to_first_use, milestones_completed, milestones_total,
    on_track, champion_identified, adoption_score,
    onboarding_stage, onboarding_status, trend_dir, notes, created_at
  )
  select v_org_id, q.cname, q.rgn, q.pm::date,
    q.csd::date, q.icd::date, q.tcd::date, q.fud::date,
    q.dti::int, q.dtf::int, q.mc::int, q.mt::int,
    q.otk, q.champ, q.ascore::numeric,
    q.stg, q.stat, q.trd, q.nt, now()
  from (values
    ('BuildRight Infra Pvt Ltd','North','2026-07-01',
     '2026-07-02',null,null,null,
     null,null,0,4,
     false,false,null,
     'contracting','on_track','stable','Contract signed — kickoff call scheduled for next week'),
    ('Sunrise Logistics Co','West','2026-07-01',
     '2026-06-20','2026-06-30',null,null,
     10,null,1,4,
     true,true,20.0,
     'install_pending','on_track','stable','Site install done ahead of schedule — training slot confirmed'),
    ('Metro Freight Carriers','South','2026-06-01',
     '2026-06-01','2026-06-18',null,null,
     17,null,1,4,
     false,false,15.0,
     'install_pending','minor_delay','worsening','Install slipped 5 days due to site access — no champion yet'),
    ('Everest Earthmovers Ltd','North','2026-06-01',
     '2026-05-25','2026-06-05','2026-06-20',null,
     11,null,2,4,
     true,true,45.0,
     'training_pending','on_track','improving','Ops team trained — first job scheduling in progress'),
    ('Coastal Cranes & Rigs','East','2026-06-01',
     '2026-05-15','2026-06-10','2026-06-28',null,
     26,null,2,4,
     false,false,30.0,
     'training_pending','stalled','worsening','Champion left the account — training refresher needed'),
    ('Deccan Construction Grp','South','2026-05-01',
     '2026-04-28','2026-05-10','2026-05-22','2026-05-30',
     12,32,3,4,
     true,true,68.0,
     'activated','on_track','improving','First job dispatched via app — usage climbing weekly'),
    ('Ganges Earthworks Pvt Ltd','North','2026-05-01',
     '2026-04-20','2026-05-25','2026-06-08',null,
     35,null,2,4,
     false,false,22.0,
     'training_pending','at_risk_churn','worsening','Install delayed 35 days — sponsor considering rollback to manual tracking'),
    ('Malabar Marine Equip','South','2026-05-01',
     '2026-04-15','2026-04-25','2026-05-05','2026-05-12',
     10,27,4,4,
     true,true,82.0,
     'steady_state','completed_success','stable','Weekly active usage across all sites — reference-customer candidate'),
    ('Silverline Warehousing','West','2026-05-01',
     '2026-04-10','2026-04-22','2026-05-01','2026-05-09',
     12,29,4,4,
     true,true,75.0,
     'steady_state','completed_success','improving','Adoption steady across 3 depots — champion actively promoting internally'),
    ('Trident Heavy Movers','East','2026-04-01',
     '2026-03-20','2026-04-15','2026-05-02',null,
     26,null,2,4,
     false,false,18.0,
     'training_pending','stalled','worsening','Training rescheduled twice — regional manager unresponsive to CSM'),
    ('Pinnacle Port Services','West','2026-04-01',
     '2026-03-10','2026-03-25','2026-04-08','2026-04-20',
     15,41,4,4,
     true,true,60.0,
     'steady_state','on_track','stable','Steady logins weekly — adoption score trending up slowly'),
    ('Riverbend Roadworks Ltd','North','2026-04-01',
     '2026-03-05','2026-04-28',null,null,
     54,null,1,4,
     false,false,10.0,
     'training_pending','at_risk_churn','worsening','Install 54 days late — customer escalated to account director'),
    ('Nilgiri Estate Equip Co','South','2026-06-01',
     '2026-05-28',null,null,null,
     null,null,0,4,
     false,false,null,
     'contracting','minor_delay','stable','Kickoff pushed a week — customer awaiting internal sign-off'),
    ('Vindhya Mining Support','Central','2026-06-01',
     '2026-05-10','2026-05-30','2026-06-15',null,
     20,null,2,4,
     true,false,38.0,
     'training_pending','on_track','improving','Training complete for lead operators — champion not yet assigned'),
    ('Aravalli Aggregates Pvt Ltd','Central','2026-07-01',
     '2026-06-25',null,null,null,
     null,null,0,4,
     true,false,null,
     'contracting','on_track','stable','New logo — implementation manager assigned, install scheduled'),
    ('Konkan Coastal Builders','West','2026-06-01',
     '2026-05-20','2026-06-02','2026-06-14','2026-06-25',
     13,36,4,4,
     true,true,71.0,
     'steady_state','completed_success','improving','Full adoption across dispatch team — expansion conversation started')
  ) as q(cname, rgn, pm, csd, icd, tcd, fud, dti, dtf, mc, mt, otk, champ, ascore, stg, stat, trd, nt);

  -- CAPA seed — attach to specific onboardings via customer_name
  insert into public.onboard_90d_capa_actions_r3725 (
    onboarding_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Coastal Cranes & Rigs','Champion attrition mid-onboarding','Assign new internal champion and re-run training session','open','CSM - East Region','2026-08-20',null,'New ops lead identified — refresher training being scheduled'),
    ('Ganges Earthworks Pvt Ltd','Install delayed by site-readiness gaps','Escalate to implementation manager and expedite site survey','in_progress','Implementation Manager','2026-08-15',null,'Site survey redone — install now targeted for next week'),
    ('Trident Heavy Movers','Regional manager unresponsive to scheduling','Escalate to account director and offer virtual training slot','overdue','Account Director','2026-07-30',null,'Two reschedules missed — director outreach sent, awaiting response'),
    ('Riverbend Roadworks Ltd','Install vendor availability shortfall','Expedite install with backup vendor and compensate downtime','in_progress','Account Director','2026-08-18',null,'Backup install crew dispatched — customer partially appeased'),
    ('Metro Freight Carriers','Site access restrictions delayed install','Coordinate access window with customer security team','closed','CSM - South Region','2026-07-05','2026-07-03','Access window secured — install completed within revised plan'),
    ('Vindhya Mining Support','No champion assigned post-training','Work with sponsor to formally designate a site champion','open','CSM - Central Region','2026-08-25',null,'Sponsor identifying candidate — expect confirmation this week'),
    ('Nilgiri Estate Equip Co','Internal sign-off pending on customer side','Follow up with procurement contact for kickoff confirmation','open','CSM - South Region','2026-08-22',null,'Procurement contact confirmed kickoff slot for next Monday'),
    ('Deccan Construction Grp','Minor delay in job-scheduling adoption','Provide targeted usage nudge and best-practice walkthrough','closed','CSM - South Region','2026-06-10','2026-06-08','Usage walkthrough delivered — adoption score improved post-session')
  ) as q(cname, rc, ca, cst, ownr, tcd, acd, nt)
  join public.onboard_90d_r3725 e
    on e.organization_id = v_org_id and e.customer_name = q.cname;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Onboarding-status distribution
create or replace function public.founder_r3725_onboarding_status_rollup()
returns table(onboarding_status text, customers bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.onboard_90d_r3725)
  select l.onboarding_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.onboard_90d_r3725 l
  group by l.onboarding_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3725_onboarding_status_rollup() from public, anon;
grant execute on function public.founder_r3725_onboarding_status_rollup() to authenticated;

-- 2) Region scorecard
create or replace function public.founder_r3725_region_scorecard()
returns table(
  region text,
  total_customers bigint,
  on_track bigint,
  stalled bigint,
  at_risk_churn bigint,
  completed_success bigint,
  champion_identified_count bigint,
  avg_adoption_score numeric,
  avg_days_to_install numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.onboarding_status = 'on_track')::bigint,
    count(*) filter (where l.onboarding_status = 'stalled')::bigint,
    count(*) filter (where l.onboarding_status = 'at_risk_churn')::bigint,
    count(*) filter (where l.onboarding_status = 'completed_success')::bigint,
    count(*) filter (where l.champion_identified = true)::bigint,
    round(avg(l.adoption_score), 1),
    round(avg(l.days_to_install), 1)
  from public.onboard_90d_r3725 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3725_region_scorecard() from public, anon;
grant execute on function public.founder_r3725_region_scorecard() to authenticated;

-- 3) Onboarding-stage × onboarding-status matrix
create or replace function public.founder_r3725_onboarding_stage_status_matrix()
returns table(onboarding_stage text, onboarding_status text, customers bigint, avg_adoption_score numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.onboarding_stage, l.onboarding_status, count(*)::bigint,
    round(avg(l.adoption_score), 1)
  from public.onboard_90d_r3725 l
  group by l.onboarding_stage, l.onboarding_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3725_onboarding_stage_status_matrix() from public, anon;
grant execute on function public.founder_r3725_onboarding_stage_status_matrix() to authenticated;

-- 4) Monthly activation trend
create or replace function public.founder_r3725_monthly_activation_trend()
returns table(
  period_month date,
  customers bigint,
  activated_or_beyond bigint,
  avg_days_to_first_use numeric,
  avg_adoption_score numeric,
  worsening_customers bigint
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
    count(*) filter (where l.onboarding_stage in ('activated','steady_state'))::bigint,
    round(avg(l.days_to_first_use), 1),
    round(avg(l.adoption_score), 1),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.onboard_90d_r3725 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3725_monthly_activation_trend() from public, anon;
grant execute on function public.founder_r3725_monthly_activation_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3725_capa_status_board()
returns table(capa_status text, actions bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.onboard_90d_capa_actions_r3725 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3725_capa_status_board() from public, anon;
grant execute on function public.founder_r3725_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3725_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.onboard_90d_capa_actions_r3725)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.onboard_90d_capa_actions_r3725 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3725_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3725_root_cause_pareto() to authenticated;

-- 7) Stalled-onboarding digest (customers with no milestone progress recently)
create or replace function public.founder_r3725_stalled_onboarding_digest()
returns table(
  region text,
  stalled_or_at_risk_customers bigint,
  avg_days_to_install numeric,
  no_champion_count bigint,
  avg_milestones_completed numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    round(avg(l.days_to_install), 1),
    count(*) filter (where l.champion_identified = false)::bigint,
    round(avg(l.milestones_completed), 1)
  from public.onboard_90d_r3725 l
  where l.onboarding_status in ('stalled','at_risk_churn')
  group by l.region
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3725_stalled_onboarding_digest() from public, anon;
grant execute on function public.founder_r3725_stalled_onboarding_digest() to authenticated;

-- 8) High-risk onboarding queue (stalled / at-risk-churn, row-level detail)
create or replace function public.founder_r3725_high_risk_queue()
returns table(
  customer_name text,
  region text,
  period_month date,
  onboarding_stage text,
  onboarding_status text,
  days_to_install int,
  days_to_first_use int,
  milestones_completed int,
  milestones_total int,
  champion_identified boolean,
  adoption_score numeric,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_name, l.region, l.period_month, l.onboarding_stage, l.onboarding_status,
    l.days_to_install, l.days_to_first_use, l.milestones_completed, l.milestones_total,
    l.champion_identified, l.adoption_score, l.notes
  from public.onboard_90d_r3725 l
  where l.onboarding_status in ('stalled','at_risk_churn')
  order by l.days_to_install desc nulls last, l.period_month asc
  limit 20;
end;
$$;

revoke all on function public.founder_r3725_high_risk_queue() from public, anon;
grant execute on function public.founder_r3725_high_risk_queue() to authenticated;
