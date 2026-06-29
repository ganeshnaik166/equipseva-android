-- Round 2942: Engineer Monthly Customer-Site Wheelchair-Accessible Workspace Compliance
-- HEAVY: 2 tables + 7 RPCs, is_founder gated

create table if not exists engineer_site_accessibility_audits_r2942 (
  id uuid primary key default gen_random_uuid(),
  engineer_id uuid not null,
  engineer_name text not null,
  site_org_id uuid not null,
  site_org_name text not null,
  site_city text not null,
  audit_month date not null,
  audit_date date not null,
  ramp_present boolean not null default false,
  ramp_slope_compliant boolean not null default false,
  doorway_width_cm int not null default 0,
  doorway_compliant boolean not null default false,
  accessible_restroom boolean not null default false,
  workspace_clearance_cm int not null default 0,
  workspace_compliant boolean not null default false,
  overall_score int not null default 0 check (overall_score between 0 and 100),
  compliance_status text not null check (compliance_status in ('compliant','partial','non_compliant','blocked')),
  blockers_count int not null default 0,
  photo_evidence_count int not null default 0,
  notes text,
  created_at timestamptz not null default now()
);
alter table engineer_site_accessibility_audits_r2942 enable row level security;

create table if not exists engineer_site_accessibility_actions_r2942 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references engineer_site_accessibility_audits_r2942(id) on delete cascade,
  action_type text not null check (action_type in ('install_ramp','widen_doorway','restroom_retrofit','clear_workspace','signage','escalate_hospital','engineer_training')),
  priority text not null check (priority in ('p0','p1','p2','p3')),
  assigned_to text not null,
  status text not null check (status in ('open','in_progress','done','deferred','blocked')),
  due_date date not null,
  closed_date date,
  cost_estimate_rupees int not null default 0,
  notes text,
  created_at timestamptz not null default now()
);
alter table engineer_site_accessibility_actions_r2942 enable row level security;

insert into engineer_site_accessibility_audits_r2942 (engineer_name, engineer_id, site_org_id, site_org_name, site_city, audit_month, audit_date, ramp_present, ramp_slope_compliant, doorway_width_cm, doorway_compliant, accessible_restroom, workspace_clearance_cm, workspace_compliant, overall_score, compliance_status, blockers_count, photo_evidence_count, notes)
select 'Eng '||i, gen_random_uuid(), gen_random_uuid(), 'Site '||i, (array['Hyderabad','Bengaluru','Chennai','Mumbai','Pune','Delhi'])[1+(i%6)], '2026-06-01'::date, ('2026-06-'||lpad(((i%27)+1)::text,2,'0'))::date,
  (i%2=0), (i%3=0), 80+(i%40), ((80+(i%40))>=90), (i%4=0), 100+(i%60), ((100+(i%60))>=140),
  50+(i%50), (array['compliant','partial','non_compliant','blocked'])[1+(i%4)], i%5, i%6, 'audit notes '||i
from generate_series(1,18) i;

insert into engineer_site_accessibility_actions_r2942 (audit_id, action_type, priority, assigned_to, status, due_date, closed_date, cost_estimate_rupees, notes)
select a.id, (array['install_ramp','widen_doorway','restroom_retrofit','clear_workspace','signage','escalate_hospital','engineer_training'])[1+(row_number() over () %7)::int],
  (array['p0','p1','p2','p3'])[1+(row_number() over () %4)::int],
  'team '||row_number() over (),
  (array['open','in_progress','done','deferred','blocked'])[1+(row_number() over () %5)::int],
  ('2026-07-'||lpad(((row_number() over () %27)+1)::text,2,'0'))::date,
  case when row_number() over () %3=0 then ('2026-06-'||lpad(((row_number() over () %27)+1)::text,2,'0'))::date end,
  5000+(row_number() over () *1000)::int,
  'action note'
from engineer_site_accessibility_audits_r2942 a limit 22;

-- skipped is_founder redefinition (kept prod version)

create or replace function r2942_monthly_compliance_overview()
returns table(audit_month date, total_sites int, compliant_sites int, partial_sites int, non_compliant_sites int, blocked_sites int, avg_score numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.audit_month,
    count(*)::int,
    (count(*) filter (where a.compliance_status='compliant'))::int,
    (count(*) filter (where a.compliance_status='partial'))::int,
    (count(*) filter (where a.compliance_status='non_compliant'))::int,
    (count(*) filter (where a.compliance_status='blocked'))::int,
    round(avg(a.overall_score)::numeric,1)
  from engineer_site_accessibility_audits_r2942 a
  group by a.audit_month order by a.audit_month desc;
end $$;
revoke all on function r2942_monthly_compliance_overview() from public, anon;
grant execute on function r2942_monthly_compliance_overview() to authenticated;

create or replace function r2942_site_leaderboard()
returns table(site_org_name text, site_city text, audits int, avg_score numeric, last_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.site_org_name, a.site_city, count(*)::int, round(avg(a.overall_score)::numeric,1),
    (array_agg(a.compliance_status order by a.audit_date desc))[1]
  from engineer_site_accessibility_audits_r2942 a
  group by a.site_org_name, a.site_city
  order by avg(a.overall_score) desc nulls last limit 30;
end $$;
revoke all on function r2942_site_leaderboard() from public, anon;
grant execute on function r2942_site_leaderboard() to authenticated;

create or replace function r2942_engineer_compliance()
returns table(engineer_name text, audits int, avg_score numeric, compliant_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.engineer_name, count(*)::int, round(avg(a.overall_score)::numeric,1),
    round((100.0 * (count(*) filter (where a.compliance_status='compliant'))::numeric / nullif(count(*),0)),1)
  from engineer_site_accessibility_audits_r2942 a
  group by a.engineer_name order by count(*) desc limit 30;
end $$;
revoke all on function r2942_engineer_compliance() from public, anon;
grant execute on function r2942_engineer_compliance() to authenticated;

create or replace function r2942_blockers_by_city()
returns table(site_city text, blockers int, non_compliant int, audits int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.site_city, sum(a.blockers_count)::int,
    (count(*) filter (where a.compliance_status='non_compliant'))::int,
    count(*)::int
  from engineer_site_accessibility_audits_r2942 a group by a.site_city order by sum(a.blockers_count) desc;
end $$;
revoke all on function r2942_blockers_by_city() from public, anon;
grant execute on function r2942_blockers_by_city() to authenticated;

create or replace function r2942_action_funnel()
returns table(status text, actions int, total_cost_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select x.status, count(*)::int, sum(x.cost_estimate_rupees)::bigint
  from engineer_site_accessibility_actions_r2942 x group by x.status order by count(*) desc;
end $$;
revoke all on function r2942_action_funnel() from public, anon;
grant execute on function r2942_action_funnel() to authenticated;

create or replace function r2942_open_p0_actions()
returns table(action_type text, priority text, assigned_to text, due_date date, cost_estimate_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select x.action_type, x.priority, x.assigned_to, x.due_date, x.cost_estimate_rupees
  from engineer_site_accessibility_actions_r2942 x where x.status in ('open','in_progress') and x.priority in ('p0','p1')
  order by x.priority, x.due_date limit 30;
end $$;
revoke all on function r2942_open_p0_actions() from public, anon;
grant execute on function r2942_open_p0_actions() to authenticated;

create or replace function r2942_dimension_failures()
returns table(dimension text, failures int, total int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select 'ramp_present'::text, (count(*) filter (where not ramp_present))::int, count(*)::int from engineer_site_accessibility_audits_r2942
    union all select 'ramp_slope', (count(*) filter (where not ramp_slope_compliant))::int, count(*)::int from engineer_site_accessibility_audits_r2942
    union all select 'doorway', (count(*) filter (where not doorway_compliant))::int, count(*)::int from engineer_site_accessibility_audits_r2942
    union all select 'restroom', (count(*) filter (where not accessible_restroom))::int, count(*)::int from engineer_site_accessibility_audits_r2942
    union all select 'workspace_clearance', (count(*) filter (where not workspace_compliant))::int, count(*)::int from engineer_site_accessibility_audits_r2942;
end $$;
revoke all on function r2942_dimension_failures() from public, anon;
grant execute on function r2942_dimension_failures() to authenticated;

create or replace function r2942_recent_audits()
returns table(audit_date date, engineer_name text, site_org_name text, site_city text, overall_score int, compliance_status text, blockers_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.audit_date, a.engineer_name, a.site_org_name, a.site_city, a.overall_score, a.compliance_status, a.blockers_count
  from engineer_site_accessibility_audits_r2942 a order by a.audit_date desc limit 30;
end $$;
revoke all on function r2942_recent_audits() from public, anon;
grant execute on function r2942_recent_audits() to authenticated;
