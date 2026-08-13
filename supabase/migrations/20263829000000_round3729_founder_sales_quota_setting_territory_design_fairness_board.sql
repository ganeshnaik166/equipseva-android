-- Round 3729: Founder Sales Quota-Setting / Territory-Design Fairness Board
-- Quota-setting process governance — rep x territory x period month x prior-year attainment vs
-- new quota vs territory potential x quota-to-potential ratio x quota increase % x appeal outcomes
-- x territory realignment x fairness score x CAPA. Distinct from territory geographic heatmap /
-- coverage-visualization pages and from commission attainment/payout-accuracy pages (this page
-- covers the quota-SETTING process, not post-quota payout accuracy).

-- =============================================================================
-- TABLE 1: quota_fairness_r3729 — per-rep/territory quota-setting fairness facts
-- =============================================================================
create table if not exists public.quota_fairness_r3729 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  rep_name text not null,
  territory_name text not null,
  period_month date not null,
  prior_year_attainment_pct numeric,
  new_quota_rupees numeric,
  territory_potential_rupees numeric,
  quota_to_potential_ratio numeric,
  quota_increase_pct numeric,
  appeal_filed boolean not null,
  appeal_upheld boolean not null,
  territory_realigned boolean not null,
  rep_fairness_score numeric,
  quota_class text not null check (quota_class in (
    'new_equipment','amc_renewal','spare_parts','service_contracts','mixed'
  )),
  fairness_status text not null check (fairness_status in (
    'well_calibrated','stretch_but_fair','overreach','appeal_pending','disputed_unresolved'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.quota_fairness_r3729 enable row level security;

create index if not exists idx_quota_fairness_r3729_org on public.quota_fairness_r3729(organization_id);
create index if not exists idx_quota_fairness_r3729_month on public.quota_fairness_r3729(period_month);
create index if not exists idx_quota_fairness_r3729_status on public.quota_fairness_r3729(fairness_status);

-- =============================================================================
-- TABLE 2: quota_fairness_capa_actions_r3729 — CAPA & quota-fairness remediation actions
-- =============================================================================
create table if not exists public.quota_fairness_capa_actions_r3729 (
  id uuid primary key default gen_random_uuid(),
  quota_fairness_id uuid references public.quota_fairness_r3729(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.quota_fairness_capa_actions_r3729 enable row level security;

create index if not exists idx_quota_fairness_capa_r3729_qf on public.quota_fairness_capa_actions_r3729(quota_fairness_id);
create index if not exists idx_quota_fairness_capa_r3729_status on public.quota_fairness_capa_actions_r3729(capa_status);

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

  -- 16 quota-fairness rows
  insert into public.quota_fairness_r3729 (
    organization_id, rep_name, territory_name, period_month,
    prior_year_attainment_pct, new_quota_rupees, territory_potential_rupees,
    quota_to_potential_ratio, quota_increase_pct, appeal_filed, appeal_upheld,
    territory_realigned, rep_fairness_score, quota_class, fairness_status, trend_dir, notes
  )
  select v_org_id, q.rep, q.terr, q.pm::date,
    q.pya::numeric, q.nq::numeric, q.tp::numeric,
    q.qtpr::numeric, q.qip::numeric, q.af, q.au,
    q.tr, q.rfs::numeric, q.qc, q.fs, q.trd, q.nt
  from (values
    ('Arjun Mehta','Mumbai Metro','2026-07-01',
     112.0,8400000,7600000,1.105,14.5,false,false,false,88.0,'new_equipment','well_calibrated','stable','FY27 quota set at 14.5% uplift, matched to territory growth'),
    ('Sunita Rao','Delhi NCR West','2026-07-01',
     98.5,7200000,6800000,1.059,9.0,false,false,false,82.0,'amc_renewal','well_calibrated','improving','Renewal base grew organically, quota bump modest'),
    ('Vikram Singh','Bengaluru South','2026-07-01',
     76.0,9600000,6200000,1.548,22.0,true,true,true,41.0,'new_equipment','disputed_unresolved','worsening','Quota set on old territory potential before hospital-count drop; realignment approved'),
    ('Priya Nair','Chennai Central','2026-07-01',
     104.0,5400000,5300000,1.019,7.5,false,false,false,90.0,'spare_parts','well_calibrated','stable','Textbook calibration, attainment history tracked closely'),
    ('Rohan Kapoor','Pune West','2026-06-01',
     89.0,6100000,5000000,1.220,18.0,true,false,false,58.0,'service_contracts','overreach','worsening','Appeal filed citing new competitor entry, still under review'),
    ('Meera Iyer','Hyderabad Hitech','2026-06-01',
     121.0,8900000,8600000,1.035,11.0,false,false,false,93.0,'mixed','well_calibrated','improving','Strong prior-year performer, quota tracks fairly'),
    ('Karan Malhotra','Kolkata East','2026-06-01',
     67.0,7000000,4500000,1.556,25.0,true,true,true,35.0,'new_equipment','disputed_unresolved','worsening','Territory potential overstated by legacy model; appeal upheld, quota being revised'),
    ('Divya Krishnan','Ahmedabad Central','2026-06-01',
     95.0,4800000,4600000,1.043,10.0,false,false,false,85.0,'amc_renewal','well_calibrated','stable','Renewal book stable, minimal quota friction'),
    ('Sameer Joshi','Jaipur Region','2026-05-01',
     83.0,5600000,4300000,1.302,19.5,true,false,false,55.0,'spare_parts','appeal_pending','worsening','Appeal filed two weeks ago, review board decision pending'),
    ('Ananya Ghosh','Lucknow Zone','2026-05-01',
     91.0,4200000,4000000,1.050,12.0,false,false,false,87.0,'service_contracts','well_calibrated','stable','Consistent attainment history, quota changes moderate'),
    ('Faisal Ahmed','Coimbatore District','2026-05-01',
     79.0,6300000,4900000,1.286,20.0,true,false,false,52.0,'mixed','overreach','worsening','New OEM tie-up expected but not yet reflected in territory potential'),
    ('Neha Bhatt','Indore Central','2026-05-01',
     107.0,5900000,5700000,1.035,13.0,false,false,false,89.0,'new_equipment','well_calibrated','improving','Territory has grown two years straight, quota kept pace'),
    ('Gaurav Desai','Nagpur Zone','2026-07-01',
     72.0,6800000,4700000,1.447,21.0,true,true,true,39.0,'amc_renewal','disputed_unresolved','worsening','AMC base double-counted across two reps pre-split; territory realigned post-appeal'),
    ('Shreya Pillai','Kochi Coastal','2026-07-01',
     99.0,3900000,3850000,1.013,8.0,false,false,false,91.0,'spare_parts','well_calibrated','stable','Textbook mapping of quota to territory potential'),
    ('Aditya Verma','Bhopal Region','2026-06-01',
     85.0,5200000,4100000,1.268,17.0,true,false,false,60.0,'service_contracts','stretch_but_fair','improving','Appeal rejected but rep agrees stretch is achievable given pipeline'),
    ('Ritu Chawla','Guwahati Northeast','2026-06-01',
     94.0,3600000,3400000,1.059,15.0,false,false,false,84.0,'mixed','stretch_but_fair','stable','Modest stretch quota, rep on track at mid-cycle checkpoint')
  ) as q(rep, terr, pm, pya, nq, tp, qtpr, qip, af, au, tr, rfs, qc, fs, trd, nt);

  -- CAPA seed — attach to specific rows via rep_name + territory_name
  insert into public.quota_fairness_capa_actions_r3729 (
    quota_fairness_id, root_cause, corrective_action,
    capa_status, owner, target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca,
    q.cst, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('Vikram Singh','Bengaluru South','Stale territory potential model used pre-quota-setting','Recompute territory potential with current hospital census and realign quota','in_progress','Sales Ops Lead','2026-08-25',null,'Territory potential model refreshed; new quota being validated with rep'),
    ('Karan Malhotra','Kolkata East','Legacy potential model overstated addressable market','Rebuild potential estimate bottoms-up and revise quota downward','closed','VP Sales','2026-07-20','2026-07-18','Quota revised down 14%, appeal formally closed and communicated'),
    ('Sameer Joshi','Jaipur Region','Appeal review board backlog delaying decision','Escalate appeal to fast-track review committee','open','Sales Ops Manager','2026-08-20',null,'Escalated after two-week SLA breach on standard appeal review'),
    ('Faisal Ahmed','Coimbatore District','New OEM partnership pipeline not reflected in territory model','Incorporate OEM pipeline forecast into next quota-setting cycle','open','Regional Sales Director','2026-09-01',null,'Pending confirmation of OEM contract signature before quota adjustment'),
    ('Gaurav Desai','Nagpur Zone','AMC base double-counted across two adjacent territories','Split AMC book cleanly and realign territory boundaries','closed','Sales Ops Lead','2026-07-10','2026-07-08','Territory boundary redrawn, AMC accounts reassigned to single owner'),
    ('Rohan Kapoor','Pune West','Competitor entry not modeled into territory potential at quota-setting time','Adjust territory potential for competitive pressure and revisit quota','in_progress','Sales Ops Manager','2026-08-30',null,'Competitive intelligence update in progress ahead of appeal decision'),
    ('Aditya Verma','Bhopal Region','Pipeline visibility gap during quota-setting review','Improve pipeline data feed into quota-setting model','overdue','Sales Ops Lead','2026-08-05',null,'Data feed fix delayed by CRM migration; new target date being set'),
    ('Meera Iyer','Hyderabad Hitech','No corrective action required — quota well calibrated','None required, monitor next cycle','closed','Sales Ops Lead','2026-07-01','2026-07-01','Included in CAPA log as a calibration baseline reference, no issue found')
  ) as q(rep, terr, rc, ca, cst, ownr, tcd, acd, nt)
  join public.quota_fairness_r3729 e
    on e.organization_id = v_org_id and e.rep_name = q.rep and e.territory_name = q.terr;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Fairness-status distribution
create or replace function public.founder_r3729_fairness_status_rollup()
returns table(fairness_status text, reps bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.quota_fairness_r3729)
  select l.fairness_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.quota_fairness_r3729 l
  group by l.fairness_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3729_fairness_status_rollup() from public, anon;
grant execute on function public.founder_r3729_fairness_status_rollup() to authenticated;

-- 2) Territory scorecard
create or replace function public.founder_r3729_territory_scorecard()
returns table(
  territory_name text,
  reps bigint,
  well_calibrated bigint,
  overreach bigint,
  disputed_unresolved bigint,
  appeals_filed bigint,
  appeals_upheld bigint,
  avg_quota_to_potential_ratio numeric,
  avg_fairness_score numeric,
  total_new_quota_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.territory_name,
    count(*)::bigint,
    count(*) filter (where l.fairness_status = 'well_calibrated')::bigint,
    count(*) filter (where l.fairness_status = 'overreach')::bigint,
    count(*) filter (where l.fairness_status = 'disputed_unresolved')::bigint,
    count(*) filter (where l.appeal_filed = true)::bigint,
    count(*) filter (where l.appeal_upheld = true)::bigint,
    round(avg(l.quota_to_potential_ratio), 3),
    round(avg(l.rep_fairness_score), 1),
    coalesce(sum(l.new_quota_rupees),0)::numeric
  from public.quota_fairness_r3729 l
  group by l.territory_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3729_territory_scorecard() from public, anon;
grant execute on function public.founder_r3729_territory_scorecard() to authenticated;

-- 3) Quota-class x fairness-status matrix
create or replace function public.founder_r3729_quota_class_status_matrix()
returns table(quota_class text, fairness_status text, reps bigint, avg_quota_increase_pct numeric, avg_fairness_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.quota_class, l.fairness_status, count(*)::bigint,
    round(avg(l.quota_increase_pct), 1),
    round(avg(l.rep_fairness_score), 1)
  from public.quota_fairness_r3729 l
  group by l.quota_class, l.fairness_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3729_quota_class_status_matrix() from public, anon;
grant execute on function public.founder_r3729_quota_class_status_matrix() to authenticated;

-- 4) Monthly quota-increase trend
create or replace function public.founder_r3729_monthly_quota_increase_trend()
returns table(period_month date, reps bigint, avg_quota_increase_pct numeric, avg_quota_to_potential_ratio numeric, appeals_filed bigint, worsening_reps bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.quota_increase_pct), 1),
    round(avg(l.quota_to_potential_ratio), 3),
    count(*) filter (where l.appeal_filed = true)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.quota_fairness_r3729 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3729_monthly_quota_increase_trend() from public, anon;
grant execute on function public.founder_r3729_monthly_quota_increase_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3729_capa_status_board()
returns table(capa_status text, findings bigint, closed_count bigint, overdue_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'closed')::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.quota_fairness_capa_actions_r3729 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3729_capa_status_board() from public, anon;
grant execute on function public.founder_r3729_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3729_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.quota_fairness_capa_actions_r3729)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.quota_fairness_capa_actions_r3729 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3729_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3729_root_cause_pareto() to authenticated;

-- 7) Appeal digest
create or replace function public.founder_r3729_appeal_digest()
returns table(
  territory_name text,
  rep_name text,
  period_month date,
  prior_year_attainment_pct numeric,
  quota_to_potential_ratio numeric,
  appeal_upheld boolean,
  territory_realigned boolean,
  fairness_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.territory_name, l.rep_name, l.period_month,
    l.prior_year_attainment_pct, l.quota_to_potential_ratio,
    l.appeal_upheld, l.territory_realigned, l.fairness_status
  from public.quota_fairness_r3729 l
  where l.appeal_filed = true
  order by l.quota_to_potential_ratio desc;
end;
$$;

revoke all on function public.founder_r3729_appeal_digest() from public, anon;
grant execute on function public.founder_r3729_appeal_digest() to authenticated;

-- 8) High-risk quota queue (disputed / overreach territories)
create or replace function public.founder_r3729_high_risk_queue()
returns table(
  rep_name text,
  territory_name text,
  period_month date,
  fairness_status text,
  quota_to_potential_ratio numeric,
  quota_increase_pct numeric,
  rep_fairness_score numeric,
  appeal_filed boolean,
  territory_realigned boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.rep_name, l.territory_name, l.period_month, l.fairness_status,
    l.quota_to_potential_ratio, l.quota_increase_pct, l.rep_fairness_score,
    l.appeal_filed, l.territory_realigned, l.notes
  from public.quota_fairness_r3729 l
  where l.fairness_status in ('disputed_unresolved','overreach')
  order by l.rep_fairness_score asc nulls last, l.quota_to_potential_ratio desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3729_high_risk_queue() from public, anon;
grant execute on function public.founder_r3729_high_risk_queue() to authenticated;
