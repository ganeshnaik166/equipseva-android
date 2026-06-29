-- Round 2968: Customer Monthly Engineer Spare-Part Authenticity QR-Scan Compliance
-- HEAVY ★★★★

create table if not exists customer_engineer_qr_scan_compliance_r2968 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  scan_month date not null,
  customer_org_name text not null,
  engineer_name text not null,
  engineer_tier text not null check (engineer_tier in ('bronze','silver','gold','platinum')),
  parts_installed_count int not null,
  parts_scanned_count int not null,
  scan_compliance_pct numeric(5,2) not null,
  authentic_count int not null,
  counterfeit_flagged_count int not null,
  unscannable_count int not null,
  status text not null check (status in ('compliant','warning','breach','critical')),
  sla_target_pct numeric(5,2) not null default 95.00,
  avg_scan_latency_seconds int not null,
  escalated boolean not null default false
);

create table if not exists customer_engineer_qr_scan_audit_actions_r2968 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  compliance_id uuid not null references customer_engineer_qr_scan_compliance_r2968(id) on delete cascade,
  action_type text not null check (action_type in ('warning_email','training_assigned','suspension','retraining_completed','escalated_to_founder','cleared')),
  action_taken_at timestamptz not null default now(),
  action_owner text not null,
  notes text,
  resolved boolean not null default false
);

alter table customer_engineer_qr_scan_compliance_r2968 enable row level security;
alter table customer_engineer_qr_scan_audit_actions_r2968 enable row level security;

drop policy if exists qrc_r2968_sel on customer_engineer_qr_scan_compliance_r2968;
create policy qrc_r2968_sel on customer_engineer_qr_scan_compliance_r2968 for select using (is_founder());

drop policy if exists qra_r2968_sel on customer_engineer_qr_scan_audit_actions_r2968;
create policy qra_r2968_sel on customer_engineer_qr_scan_audit_actions_r2968 for select using (is_founder());

-- Seed compliance rows (18)
insert into customer_engineer_qr_scan_compliance_r2968 (scan_month, customer_org_name, engineer_name, engineer_tier, parts_installed_count, parts_scanned_count, scan_compliance_pct, authentic_count, counterfeit_flagged_count, unscannable_count, status, avg_scan_latency_seconds, escalated) values
('2026-05-01'::date,'Apollo Hyderabad','Ravi Kumar','platinum',42,42,100.00,42,0,0,'compliant',8,false),
('2026-05-01'::date,'Apollo Hyderabad','Sneha Reddy','gold',38,36,94.74,35,1,0,'warning',11,false),
('2026-05-01'::date,'Yashoda Secunderabad','Arjun Patel','platinum',55,55,100.00,54,1,0,'compliant',7,false),
('2026-05-01'::date,'Yashoda Secunderabad','Meera Iyer','silver',29,24,82.76,23,0,1,'breach',18,true),
('2026-05-01'::date,'KIMS Kondapur','Vikram Singh','gold',47,46,97.87,46,0,0,'compliant',9,false),
('2026-05-01'::date,'KIMS Kondapur','Pooja Sharma','bronze',21,15,71.43,14,0,1,'critical',24,true),
('2026-05-01'::date,'Continental Gachibowli','Karthik Rao','platinum',61,61,100.00,60,1,0,'compliant',6,false),
('2026-05-01'::date,'Continental Gachibowli','Anita Joshi','gold',34,33,97.06,33,0,0,'compliant',10,false),
('2026-05-01'::date,'Care Banjara','Suresh Babu','silver',31,28,90.32,27,1,0,'warning',14,false),
('2026-05-01'::date,'Care Banjara','Divya Nair','bronze',19,12,63.16,12,0,0,'critical',28,true),
('2026-04-01'::date,'Apollo Hyderabad','Ravi Kumar','platinum',39,39,100.00,39,0,0,'compliant',7,false),
('2026-04-01'::date,'Yashoda Secunderabad','Meera Iyer','silver',26,21,80.77,20,0,1,'breach',19,true),
('2026-04-01'::date,'KIMS Kondapur','Pooja Sharma','bronze',18,13,72.22,13,0,0,'critical',25,true),
('2026-04-01'::date,'Continental Gachibowli','Karthik Rao','platinum',58,58,100.00,57,1,0,'compliant',6,false),
('2026-04-01'::date,'Care Banjara','Divya Nair','bronze',17,11,64.71,11,0,0,'critical',27,true),
('2026-04-01'::date,'Sunshine Begumpet','Naveen Goud','gold',33,32,96.97,32,0,0,'compliant',10,false),
('2026-04-01'::date,'Sunshine Begumpet','Lakshmi Devi','silver',28,27,96.43,27,0,0,'compliant',12,false),
('2026-03-01'::date,'Apollo Hyderabad','Ravi Kumar','platinum',41,41,100.00,40,1,0,'compliant',8,false);

-- Seed audit actions (16)
insert into customer_engineer_qr_scan_audit_actions_r2968 (compliance_id, action_type, action_owner, notes, resolved)
select id,'warning_email','ops_team','Compliance dipped below 95%',true from customer_engineer_qr_scan_compliance_r2968 where status='warning' limit 3;

insert into customer_engineer_qr_scan_audit_actions_r2968 (compliance_id, action_type, action_owner, notes, resolved)
select id,'training_assigned','quality_lead','QR scan refresher module assigned',false from customer_engineer_qr_scan_compliance_r2968 where status='breach' limit 3;

insert into customer_engineer_qr_scan_audit_actions_r2968 (compliance_id, action_type, action_owner, notes, resolved)
select id,'suspension','founder','Suspended pending retraining',false from customer_engineer_qr_scan_compliance_r2968 where status='critical' limit 3;

insert into customer_engineer_qr_scan_audit_actions_r2968 (compliance_id, action_type, action_owner, notes, resolved)
select id,'escalated_to_founder','ops_lead','Engineer below 75% for 2 months',false from customer_engineer_qr_scan_compliance_r2968 where escalated=true limit 4;

insert into customer_engineer_qr_scan_audit_actions_r2968 (compliance_id, action_type, action_owner, notes, resolved)
select id,'retraining_completed','training_team','Engineer passed retraining',true from customer_engineer_qr_scan_compliance_r2968 where status='compliant' limit 3;

revoke all on customer_engineer_qr_scan_compliance_r2968 from public, anon;
revoke all on customer_engineer_qr_scan_audit_actions_r2968 from public, anon;
grant select on customer_engineer_qr_scan_compliance_r2968 to authenticated;
grant select on customer_engineer_qr_scan_audit_actions_r2968 to authenticated;

-- RPC 1: Summary
create or replace function r2968_summary()
returns table(total_engineers int, total_parts_installed bigint, total_parts_scanned bigint, overall_compliance_pct numeric, counterfeit_flagged bigint, critical_count int, breach_count int, compliant_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select
    count(distinct engineer_name)::int,
    sum(parts_installed_count)::bigint,
    sum(parts_scanned_count)::bigint,
    round(100.0 * sum(parts_scanned_count)::numeric / nullif(sum(parts_installed_count),0), 2),
    sum(counterfeit_flagged_count)::bigint,
    (count(*) filter (where status='critical'))::int,
    (count(*) filter (where status='breach'))::int,
    (count(*) filter (where status='compliant'))::int
  from customer_engineer_qr_scan_compliance_r2968;
end; $$;

-- RPC 2: Latest month compliance
create or replace function r2968_latest_month()
returns table(engineer_name text, customer_org_name text, engineer_tier text, parts_installed_count int, parts_scanned_count int, scan_compliance_pct numeric, status text, escalated boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.engineer_name, c.customer_org_name, c.engineer_tier, c.parts_installed_count, c.parts_scanned_count, c.scan_compliance_pct, c.status, c.escalated
  from customer_engineer_qr_scan_compliance_r2968 c
  where c.scan_month = (select max(scan_month) from customer_engineer_qr_scan_compliance_r2968)
  order by c.scan_compliance_pct asc;
end; $$;

-- RPC 3: Tier breakdown
create or replace function r2968_tier_breakdown()
returns table(engineer_tier text, engineer_count int, avg_compliance_pct numeric, breach_count int, critical_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.engineer_tier, count(distinct c.engineer_name)::int, round(avg(c.scan_compliance_pct),2),
    (count(*) filter (where c.status='breach'))::int,
    (count(*) filter (where c.status='critical'))::int
  from customer_engineer_qr_scan_compliance_r2968 c
  group by c.engineer_tier
  order by c.engineer_tier;
end; $$;

-- RPC 4: Counterfeit alerts
create or replace function r2968_counterfeit_alerts()
returns table(engineer_name text, customer_org_name text, scan_month date, counterfeit_flagged_count int, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.engineer_name, c.customer_org_name, c.scan_month, c.counterfeit_flagged_count, c.status
  from customer_engineer_qr_scan_compliance_r2968 c
  where c.counterfeit_flagged_count > 0
  order by c.counterfeit_flagged_count desc, c.scan_month desc;
end; $$;

-- RPC 5: Escalated engineers
create or replace function r2968_escalated_engineers()
returns table(engineer_name text, customer_org_name text, engineer_tier text, scan_compliance_pct numeric, status text, scan_month date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.engineer_name, c.customer_org_name, c.engineer_tier, c.scan_compliance_pct, c.status, c.scan_month
  from customer_engineer_qr_scan_compliance_r2968 c
  where c.escalated=true
  order by c.scan_compliance_pct asc;
end; $$;

-- RPC 6: Audit action log
create or replace function r2968_audit_actions()
returns table(action_type text, action_owner text, notes text, resolved boolean, action_taken_at timestamptz, engineer_name text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.action_type, a.action_owner, a.notes, a.resolved, a.action_taken_at, c.engineer_name
  from customer_engineer_qr_scan_audit_actions_r2968 a
  join customer_engineer_qr_scan_compliance_r2968 c on c.id=a.compliance_id
  order by a.action_taken_at desc;
end; $$;

-- RPC 7: Monthly trend
create or replace function r2968_monthly_trend()
returns table(scan_month date, total_engineers int, avg_compliance_pct numeric, total_counterfeit bigint, escalated_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.scan_month, count(distinct c.engineer_name)::int, round(avg(c.scan_compliance_pct),2),
    sum(c.counterfeit_flagged_count)::bigint,
    (count(*) filter (where c.escalated=true))::int
  from customer_engineer_qr_scan_compliance_r2968 c
  group by c.scan_month
  order by c.scan_month desc;
end; $$;

-- RPC 8: Action type breakdown
create or replace function r2968_action_type_breakdown()
returns table(action_type text, action_count int, resolved_count int, pending_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.action_type, count(*)::int,
    (count(*) filter (where a.resolved=true))::int,
    (count(*) filter (where a.resolved=false))::int
  from customer_engineer_qr_scan_audit_actions_r2968 a
  group by a.action_type
  order by count(*) desc;
end; $$;

revoke all on function r2968_summary() from public, anon;
revoke all on function r2968_latest_month() from public, anon;
revoke all on function r2968_tier_breakdown() from public, anon;
revoke all on function r2968_counterfeit_alerts() from public, anon;
revoke all on function r2968_escalated_engineers() from public, anon;
revoke all on function r2968_audit_actions() from public, anon;
revoke all on function r2968_monthly_trend() from public, anon;
revoke all on function r2968_action_type_breakdown() from public, anon;
grant execute on function r2968_summary() to authenticated;
grant execute on function r2968_latest_month() to authenticated;
grant execute on function r2968_tier_breakdown() to authenticated;
grant execute on function r2968_counterfeit_alerts() to authenticated;
grant execute on function r2968_escalated_engineers() to authenticated;
grant execute on function r2968_audit_actions() to authenticated;
grant execute on function r2968_monthly_trend() to authenticated;
grant execute on function r2968_action_type_breakdown() to authenticated;
