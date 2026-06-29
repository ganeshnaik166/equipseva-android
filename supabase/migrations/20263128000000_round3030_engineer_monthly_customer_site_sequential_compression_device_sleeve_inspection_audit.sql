-- Round 3030: Engineer Monthly Customer Site Sequential-Compression-Device Sleeve Inspection Audit
-- Two tables tracking monthly SCD sleeve audits at customer sites by field engineers.

create table if not exists scd_sleeve_audits_r3030 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  audit_month date not null,
  customer_site text not null,
  city text not null,
  engineer_name text not null,
  sleeves_inspected int not null check (sleeves_inspected between 0 and 500),
  sleeves_passed int not null check (sleeves_passed between 0 and 500),
  sleeves_failed int not null check (sleeves_failed between 0 and 500),
  failure_mode text not null check (failure_mode in ('seam_leak','bladder_rupture','velcro_worn','hose_kink','none')),
  remediation_status text not null check (remediation_status in ('pending','scheduled','in_progress','closed','escalated')),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  next_audit_due date,
  notes text
);

create table if not exists scd_sleeve_audit_actions_r3030 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  audit_id uuid references scd_sleeve_audits_r3030(id) on delete cascade,
  action_type text not null check (action_type in ('replace_sleeve','recalibrate_pump','vendor_rma','training','escalate_biomed')),
  action_status text not null check (action_status in ('open','in_progress','done','cancelled')),
  owner text not null,
  due_date date,
  closed_at timestamptz,
  cost_rupees int check (cost_rupees between 0 and 500000),
  notes text
);

alter table scd_sleeve_audits_r3030 enable row level security;
alter table scd_sleeve_audit_actions_r3030 enable row level security;

drop policy if exists scd_sleeve_audits_r3030_founder on scd_sleeve_audits_r3030;
create policy scd_sleeve_audits_r3030_founder on scd_sleeve_audits_r3030 for select using (is_founder());

drop policy if exists scd_sleeve_audit_actions_r3030_founder on scd_sleeve_audit_actions_r3030;
create policy scd_sleeve_audit_actions_r3030_founder on scd_sleeve_audit_actions_r3030 for select using (is_founder());

-- Seeds: audits (18 rows)
insert into scd_sleeve_audits_r3030 (audit_month, customer_site, city, engineer_name, sleeves_inspected, sleeves_passed, sleeves_failed, failure_mode, remediation_status, severity, next_audit_due, notes)
select '2026-04-01'::date, 'Apollo Jubilee', 'Hyderabad', 'Ravi K', 24, 22, 2, 'seam_leak', 'closed', 'p2', '2026-05-01'::date, 'two sleeves replaced'
union all select '2026-04-01'::date, 'KIMS Secunderabad', 'Hyderabad', 'Suresh M', 32, 30, 2, 'velcro_worn', 'closed', 'p3', '2026-05-01'::date, 'velcro refresh'
union all select '2026-04-01'::date, 'Yashoda Somajiguda', 'Hyderabad', 'Anil P', 18, 14, 4, 'bladder_rupture', 'escalated', 'p1', '2026-05-01'::date, 'vendor RMA filed'
union all select '2026-04-01'::date, 'Continental Gachibowli', 'Hyderabad', 'Ravi K', 20, 20, 0, 'none', 'closed', 'p3', '2026-05-01'::date, 'clean audit'
union all select '2026-04-01'::date, 'AIG Gachibowli', 'Hyderabad', 'Pranay V', 28, 25, 3, 'hose_kink', 'in_progress', 'p2', '2026-05-01'::date, 'hose kit ordered'
union all select '2026-04-01'::date, 'Manipal Vijayawada', 'Vijayawada', 'Karthik S', 16, 13, 3, 'seam_leak', 'scheduled', 'p2', '2026-05-01'::date, 'pending visit'
union all select '2026-05-01'::date, 'Apollo Jubilee', 'Hyderabad', 'Ravi K', 26, 25, 1, 'velcro_worn', 'closed', 'p3', '2026-06-01'::date, 'single sleeve'
union all select '2026-05-01'::date, 'KIMS Secunderabad', 'Hyderabad', 'Suresh M', 34, 31, 3, 'bladder_rupture', 'in_progress', 'p1', '2026-06-01'::date, 'three bladders flagged'
union all select '2026-05-01'::date, 'Yashoda Somajiguda', 'Hyderabad', 'Anil P', 20, 19, 1, 'hose_kink', 'closed', 'p3', '2026-06-01'::date, 'minor'
union all select '2026-05-01'::date, 'Continental Gachibowli', 'Hyderabad', 'Ravi K', 22, 22, 0, 'none', 'closed', 'p3', '2026-06-01'::date, 'clean'
union all select '2026-05-01'::date, 'AIG Gachibowli', 'Hyderabad', 'Pranay V', 30, 28, 2, 'seam_leak', 'closed', 'p2', '2026-06-01'::date, 'seam repair'
union all select '2026-05-01'::date, 'Manipal Vijayawada', 'Vijayawada', 'Karthik S', 18, 15, 3, 'velcro_worn', 'in_progress', 'p2', '2026-06-01'::date, 'velcro kit dispatched'
union all select '2026-06-01'::date, 'Apollo Jubilee', 'Hyderabad', 'Ravi K', 28, 27, 1, 'hose_kink', 'closed', 'p3', '2026-07-01'::date, 'tightened clamp'
union all select '2026-06-01'::date, 'KIMS Secunderabad', 'Hyderabad', 'Suresh M', 36, 32, 4, 'bladder_rupture', 'escalated', 'p0', '2026-07-01'::date, 'batch defect suspected'
union all select '2026-06-01'::date, 'Yashoda Somajiguda', 'Hyderabad', 'Anil P', 22, 21, 1, 'velcro_worn', 'closed', 'p3', '2026-07-01'::date, 'minor'
union all select '2026-06-01'::date, 'Continental Gachibowli', 'Hyderabad', 'Ravi K', 24, 23, 1, 'seam_leak', 'pending', 'p2', '2026-07-01'::date, 'sleeve on order'
union all select '2026-06-01'::date, 'AIG Gachibowli', 'Hyderabad', 'Pranay V', 32, 30, 2, 'hose_kink', 'scheduled', 'p2', '2026-07-01'::date, 'next visit 06-15'
union all select '2026-06-01'::date, 'Manipal Vijayawada', 'Vijayawada', 'Karthik S', 20, 18, 2, 'seam_leak', 'in_progress', 'p2', '2026-07-01'::date, 'repair underway';

-- Seeds: actions (16 rows)
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'replace_sleeve', 'done', 'Ravi K', '2026-04-10'::date, '2026-04-09'::timestamptz, 4800, 'two units'
  from scd_sleeve_audits_r3030 a where a.customer_site='Apollo Jubilee' and a.audit_month='2026-04-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'vendor_rma', 'in_progress', 'Anil P', '2026-05-15'::date, null::timestamptz, 0, 'awaiting credit note'
  from scd_sleeve_audits_r3030 a where a.customer_site='Yashoda Somajiguda' and a.audit_month='2026-04-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'recalibrate_pump', 'done', 'Suresh M', '2026-04-12'::date, '2026-04-12'::timestamptz, 1200, 'pump 3 recalibrated'
  from scd_sleeve_audits_r3030 a where a.customer_site='KIMS Secunderabad' and a.audit_month='2026-04-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'replace_sleeve', 'done', 'Pranay V', '2026-04-15'::date, '2026-04-14'::timestamptz, 7200, 'three sleeves'
  from scd_sleeve_audits_r3030 a where a.customer_site='AIG Gachibowli' and a.audit_month='2026-04-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'training', 'done', 'Karthik S', '2026-04-20'::date, '2026-04-19'::timestamptz, 0, 'onsite biomed training'
  from scd_sleeve_audits_r3030 a where a.customer_site='Manipal Vijayawada' and a.audit_month='2026-04-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'replace_sleeve', 'done', 'Ravi K', '2026-05-08'::date, '2026-05-07'::timestamptz, 2400, 'one unit'
  from scd_sleeve_audits_r3030 a where a.customer_site='Apollo Jubilee' and a.audit_month='2026-05-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'escalate_biomed', 'in_progress', 'Suresh M', '2026-05-20'::date, null::timestamptz, 0, 'biomed reviewing batch'
  from scd_sleeve_audits_r3030 a where a.customer_site='KIMS Secunderabad' and a.audit_month='2026-05-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'replace_sleeve', 'done', 'Anil P', '2026-05-10'::date, '2026-05-10'::timestamptz, 2400, 'one unit'
  from scd_sleeve_audits_r3030 a where a.customer_site='Yashoda Somajiguda' and a.audit_month='2026-05-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'recalibrate_pump', 'done', 'Pranay V', '2026-05-18'::date, '2026-05-17'::timestamptz, 1800, 'two pumps'
  from scd_sleeve_audits_r3030 a where a.customer_site='AIG Gachibowli' and a.audit_month='2026-05-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'replace_sleeve', 'in_progress', 'Karthik S', '2026-05-25'::date, null::timestamptz, 7200, 'three sleeves on order'
  from scd_sleeve_audits_r3030 a where a.customer_site='Manipal Vijayawada' and a.audit_month='2026-05-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'replace_sleeve', 'open', 'Ravi K', '2026-06-15'::date, null::timestamptz, 2400, 'sleeve pending'
  from scd_sleeve_audits_r3030 a where a.customer_site='Continental Gachibowli' and a.audit_month='2026-06-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'escalate_biomed', 'open', 'Suresh M', '2026-06-20'::date, null::timestamptz, 0, 'p0 batch defect'
  from scd_sleeve_audits_r3030 a where a.customer_site='KIMS Secunderabad' and a.audit_month='2026-06-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'vendor_rma', 'open', 'Suresh M', '2026-06-25'::date, null::timestamptz, 0, 'RMA paperwork'
  from scd_sleeve_audits_r3030 a where a.customer_site='KIMS Secunderabad' and a.audit_month='2026-06-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'training', 'open', 'Pranay V', '2026-06-30'::date, null::timestamptz, 0, 'refresher for nursing'
  from scd_sleeve_audits_r3030 a where a.customer_site='AIG Gachibowli' and a.audit_month='2026-06-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'replace_sleeve', 'open', 'Karthik S', '2026-06-28'::date, null::timestamptz, 4800, 'two sleeves'
  from scd_sleeve_audits_r3030 a where a.customer_site='Manipal Vijayawada' and a.audit_month='2026-06-01' limit 1;
insert into scd_sleeve_audit_actions_r3030 (audit_id, action_type, action_status, owner, due_date, closed_at, cost_rupees, notes)
select a.id, 'recalibrate_pump', 'done', 'Ravi K', '2026-06-10'::date, '2026-06-09'::timestamptz, 1200, 'single pump'
  from scd_sleeve_audits_r3030 a where a.customer_site='Apollo Jubilee' and a.audit_month='2026-06-01' limit 1;

-- RPCs (7) — is_founder() gated
create or replace function fn_r3030_monthly_overview()
returns table(audit_month date, sites_audited int, sleeves_inspected int, sleeves_failed int, failure_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.audit_month,
           count(distinct a.customer_site)::int,
           sum(a.sleeves_inspected)::int,
           sum(a.sleeves_failed)::int,
           round((sum(a.sleeves_failed)::numeric / nullif(sum(a.sleeves_inspected),0)) * 100, 2)
      from scd_sleeve_audits_r3030 a
     group by a.audit_month
     order by a.audit_month;
end; $$;

create or replace function fn_r3030_site_failure_leaderboard()
returns table(customer_site text, city text, total_inspected int, total_failed int, failure_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.customer_site, a.city,
           sum(a.sleeves_inspected)::int,
           sum(a.sleeves_failed)::int,
           round((sum(a.sleeves_failed)::numeric / nullif(sum(a.sleeves_inspected),0)) * 100, 2)
      from scd_sleeve_audits_r3030 a
     group by a.customer_site, a.city
     order by sum(a.sleeves_failed) desc;
end; $$;

create or replace function fn_r3030_failure_mode_mix()
returns table(failure_mode text, audits int, total_failed int, share_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.failure_mode,
           count(*)::int,
           sum(a.sleeves_failed)::int,
           round((sum(a.sleeves_failed)::numeric / nullif((select sum(sleeves_failed) from scd_sleeve_audits_r3030),0)) * 100, 2)
      from scd_sleeve_audits_r3030 a
     group by a.failure_mode
     order by sum(a.sleeves_failed) desc;
end; $$;

create or replace function fn_r3030_severity_breakdown()
returns table(severity text, audits int, open_audits int, escalated_audits int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.severity,
           count(*)::int,
           (count(*) filter (where a.remediation_status in ('pending','scheduled','in_progress')))::int,
           (count(*) filter (where a.remediation_status = 'escalated'))::int
      from scd_sleeve_audits_r3030 a
     group by a.severity
     order by a.severity;
end; $$;

create or replace function fn_r3030_engineer_throughput()
returns table(engineer_name text, audits int, sleeves_inspected int, clean_audits int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.engineer_name,
           count(*)::int,
           sum(a.sleeves_inspected)::int,
           (count(*) filter (where a.failure_mode = 'none'))::int
      from scd_sleeve_audits_r3030 a
     group by a.engineer_name
     order by count(*) desc;
end; $$;

create or replace function fn_r3030_open_actions_queue()
returns table(customer_site text, action_type text, owner text, due_date date, action_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.customer_site, ac.action_type, ac.owner, ac.due_date, ac.action_status
      from scd_sleeve_audit_actions_r3030 ac
      join scd_sleeve_audits_r3030 a on a.id = ac.audit_id
     where ac.action_status in ('open','in_progress')
     order by ac.due_date nulls last;
end; $$;

create or replace function fn_r3030_remediation_cost_summary()
returns table(action_type text, actions int, total_cost_rupees int, closed_actions int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select ac.action_type,
           count(*)::int,
           coalesce(sum(ac.cost_rupees),0)::int,
           (count(*) filter (where ac.action_status = 'done'))::int
      from scd_sleeve_audit_actions_r3030 ac
     group by ac.action_type
     order by sum(ac.cost_rupees) desc nulls last;
end; $$;

revoke all on function fn_r3030_monthly_overview() from public, anon;
revoke all on function fn_r3030_site_failure_leaderboard() from public, anon;
revoke all on function fn_r3030_failure_mode_mix() from public, anon;
revoke all on function fn_r3030_severity_breakdown() from public, anon;
revoke all on function fn_r3030_engineer_throughput() from public, anon;
revoke all on function fn_r3030_open_actions_queue() from public, anon;
revoke all on function fn_r3030_remediation_cost_summary() from public, anon;

grant execute on function fn_r3030_monthly_overview() to authenticated;
grant execute on function fn_r3030_site_failure_leaderboard() to authenticated;
grant execute on function fn_r3030_failure_mode_mix() to authenticated;
grant execute on function fn_r3030_severity_breakdown() to authenticated;
grant execute on function fn_r3030_engineer_throughput() to authenticated;
grant execute on function fn_r3030_open_actions_queue() to authenticated;
grant execute on function fn_r3030_remediation_cost_summary() to authenticated;
