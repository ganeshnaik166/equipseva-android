-- Round r2984 — Customer Monthly Engineer Hospital Visitor-WiFi-Throttle Network-Hygiene Discipline
-- Batch 420 milestone. HEAVY ★★★★.

create table if not exists visitor_wifi_throttle_events_r2984 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  hospital_name text not null,
  city text not null,
  ssid text not null,
  event_month date not null,
  visitor_sessions int not null check (visitor_sessions between 0 and 100000),
  peak_mbps numeric(8,2) not null check (peak_mbps between 0 and 10000),
  throttle_kicks int not null check (throttle_kicks between 0 and 10000),
  bandwidth_cap_mbps int not null check (bandwidth_cap_mbps between 1 and 1000),
  policy_tier text not null check (policy_tier in ('strict','balanced','permissive','custom')),
  guest_isolation_on boolean not null default true,
  hygiene_grade text not null check (hygiene_grade in ('A','B','C','D','F')),
  reviewer_role text not null check (reviewer_role in ('hospital_admin','engineer','founder','auditor')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists engineer_network_hygiene_discipline_r2984 (
  id uuid primary key default gen_random_uuid(),
  engineer_user_id uuid,
  engineer_name text not null,
  hospital_name text not null,
  visit_month date not null,
  ap_audits_done int not null check (ap_audits_done between 0 and 500),
  firmware_patches_applied int not null check (firmware_patches_applied between 0 and 500),
  rogue_devices_flagged int not null check (rogue_devices_flagged between 0 and 500),
  guest_segregation_verified boolean not null default false,
  discipline_score int not null check (discipline_score between 0 and 100),
  monthly_visits int not null check (monthly_visits between 0 and 60),
  status text not null check (status in ('on_track','watch','warning','escalated','resolved')),
  next_action text not null,
  created_at timestamptz not null default now()
);

alter table visitor_wifi_throttle_events_r2984 enable row level security;
alter table engineer_network_hygiene_discipline_r2984 enable row level security;

drop policy if exists vwte_r2984_founder on visitor_wifi_throttle_events_r2984;
create policy vwte_r2984_founder on visitor_wifi_throttle_events_r2984 for select using (is_founder());

drop policy if exists enhd_r2984_founder on engineer_network_hygiene_discipline_r2984;
create policy enhd_r2984_founder on engineer_network_hygiene_discipline_r2984 for select using (is_founder());

insert into visitor_wifi_throttle_events_r2984
(hospital_name, city, ssid, event_month, visitor_sessions, peak_mbps, throttle_kicks, bandwidth_cap_mbps, policy_tier, guest_isolation_on, hygiene_grade, reviewer_role, notes) values
('Apollo Jubilee','Hyderabad','APOLLO-GUEST','2026-05-01'::date, 4820, 420.50, 312, 50, 'balanced', true, 'A', 'founder', 'Smooth month'),
('Apollo Jubilee','Hyderabad','APOLLO-GUEST','2026-04-01'::date, 4510, 380.10, 290, 50, 'balanced', true, 'A', 'engineer', 'Patched APs'),
('KIMS Secunderabad','Hyderabad','KIMS-VISITOR','2026-05-01'::date, 6210, 510.20, 612, 40, 'strict', true, 'B', 'hospital_admin', 'High visitor load'),
('KIMS Secunderabad','Hyderabad','KIMS-VISITOR','2026-04-01'::date, 5890, 488.90, 580, 40, 'strict', true, 'B', 'auditor', 'Throttle tuned'),
('Yashoda Somajiguda','Hyderabad','YASHODA-GUEST','2026-05-01'::date, 3720, 295.40, 198, 30, 'balanced', true, 'A', 'founder', 'All green'),
('Manipal Vijayawada','Vijayawada','MANIPAL-WIFI','2026-05-01'::date, 2810, 220.10, 142, 30, 'balanced', true, 'B', 'engineer', 'Firmware lag'),
('Care Banjara','Hyderabad','CARE-GUEST','2026-05-01'::date, 1980, 180.30, 88, 25, 'permissive', false, 'C', 'auditor', 'Isolation off — flagged'),
('Continental Gachibowli','Hyderabad','CONT-VISITOR','2026-05-01'::date, 5410, 460.70, 401, 50, 'strict', true, 'A', 'founder', 'Clean'),
('Rainbow Banjara','Hyderabad','RAINBOW-GUEST','2026-05-01'::date, 2240, 198.50, 110, 25, 'balanced', true, 'B', 'hospital_admin', 'OK'),
('AIG Gachibowli','Hyderabad','AIG-VISITOR','2026-05-01'::date, 7120, 590.80, 712, 60, 'strict', true, 'A', 'engineer', 'Peak Friday spike'),
('Sunshine Paradise','Hyderabad','SUN-GUEST','2026-05-01'::date, 1890, 160.20, 75, 20, 'balanced', true, 'C', 'auditor', 'Two rogue APs found'),
('Medicover HiTec','Hyderabad','MEDI-GUEST','2026-05-01'::date, 3340, 280.60, 188, 30, 'balanced', true, 'B', 'founder', 'Steady'),
('Star Banjara','Hyderabad','STAR-VISITOR','2026-05-01'::date, 1450, 130.40, 62, 20, 'permissive', false, 'D', 'auditor', 'Hygiene drop'),
('Citizens Nallagandla','Hyderabad','CITZ-GUEST','2026-05-01'::date, 980, 95.10, 38, 15, 'permissive', true, 'C', 'engineer', 'Low traffic'),
('Renova Hitech','Hyderabad','RENOVA-GUEST','2026-05-01'::date, 2670, 235.70, 154, 30, 'balanced', true, 'B', 'hospital_admin', 'Normal'),
('Omega Banjara','Hyderabad','OMEGA-GUEST','2026-05-01'::date, 1210, 110.50, 48, 15, 'strict', true, 'A', 'founder', 'Tight policy'),
('SLG Bachupally','Hyderabad','SLG-VISITOR','2026-05-01'::date, 880, 85.30, 32, 15, 'balanced', true, 'B', 'engineer', 'Light'),
('Pace Hospital','Hyderabad','PACE-GUEST','2026-05-01'::date, 1690, 145.80, 80, 20, 'balanced', true, 'B', 'auditor', 'OK');

insert into engineer_network_hygiene_discipline_r2984
(engineer_name, hospital_name, visit_month, ap_audits_done, firmware_patches_applied, rogue_devices_flagged, guest_segregation_verified, discipline_score, monthly_visits, status, next_action) values
('Ravi Kumar','Apollo Jubilee','2026-05-01'::date, 24, 18, 2, true, 92, 4, 'on_track', 'Continue monthly cadence'),
('Ravi Kumar','Apollo Jubilee','2026-04-01'::date, 22, 16, 1, true, 90, 4, 'on_track', 'Maintain'),
('Suresh Reddy','KIMS Secunderabad','2026-05-01'::date, 31, 24, 5, true, 85, 5, 'watch', 'Investigate spike'),
('Anil Verma','Yashoda Somajiguda','2026-05-01'::date, 18, 14, 1, true, 88, 3, 'on_track', 'Hold'),
('Priya Nair','Manipal Vijayawada','2026-05-01'::date, 15, 8, 3, true, 72, 3, 'warning', 'Patch backlog'),
('Vikram Singh','Care Banjara','2026-05-01'::date, 12, 6, 8, false, 55, 2, 'escalated', 'Enable guest isolation'),
('Deepak Joshi','Continental Gachibowli','2026-05-01'::date, 28, 22, 3, true, 91, 5, 'on_track', 'Maintain'),
('Meera Patel','Rainbow Banjara','2026-05-01'::date, 16, 12, 1, true, 84, 3, 'on_track', 'Hold'),
('Karthik Iyer','AIG Gachibowli','2026-05-01'::date, 35, 28, 6, true, 89, 6, 'on_track', 'Watch Friday peaks'),
('Sneha Rao','Sunshine Paradise','2026-05-01'::date, 14, 7, 4, true, 65, 3, 'warning', 'Replace 2 rogue APs'),
('Arjun Mehta','Medicover HiTec','2026-05-01'::date, 19, 15, 2, true, 82, 3, 'on_track', 'Continue'),
('Pooja Sharma','Star Banjara','2026-05-01'::date, 10, 4, 6, false, 48, 2, 'escalated', 'Full network audit'),
('Rahul Das','Citizens Nallagandla','2026-05-01'::date, 13, 9, 1, true, 78, 2, 'on_track', 'Normal'),
('Lakshmi Pillai','Renova Hitech','2026-05-01'::date, 17, 13, 2, true, 83, 3, 'on_track', 'Maintain'),
('Manoj Bhat','Omega Banjara','2026-05-01'::date, 14, 11, 0, true, 94, 2, 'on_track', 'Exemplar'),
('Sandeep Roy','SLG Bachupally','2026-05-01'::date, 11, 8, 1, true, 80, 2, 'on_track', 'OK'),
('Geeta Menon','Pace Hospital','2026-05-01'::date, 15, 11, 2, true, 81, 3, 'on_track', 'Normal'),
('Vivek Shetty','Care Banjara','2026-04-01'::date, 11, 5, 7, false, 52, 2, 'escalated', 'Repeat offender — chain alert');

create or replace function rpc_r2984_throttle_overview()
returns table(hospital text, city text, sessions int, peak_mbps numeric, throttle_kicks int, grade text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select hospital_name, v.city, visitor_sessions, peak_mbps, throttle_kicks, hygiene_grade
    from visitor_wifi_throttle_events_r2984 v
    where event_month = '2026-05-01'::date
    order by visitor_sessions desc;
end $$;

create or replace function rpc_r2984_engineer_discipline()
returns table(engineer text, hospital text, score int, status text, next_action text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select engineer_name, hospital_name, discipline_score, e.status, e.next_action
    from engineer_network_hygiene_discipline_r2984 e
    where visit_month = '2026-05-01'::date
    order by discipline_score asc;
end $$;

create or replace function rpc_r2984_hygiene_grade_mix()
returns table(grade text, hospitals int, avg_sessions int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select hygiene_grade, count(*)::int, avg(visitor_sessions)::int
    from visitor_wifi_throttle_events_r2984
    where event_month = '2026-05-01'::date
    group by hygiene_grade order by hygiene_grade;
end $$;

create or replace function rpc_r2984_isolation_offenders()
returns table(hospital text, city text, policy text, sessions int, grade text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select hospital_name, v.city, policy_tier, visitor_sessions, hygiene_grade
    from visitor_wifi_throttle_events_r2984 v
    where guest_isolation_on = false and event_month = '2026-05-01'::date
    order by visitor_sessions desc;
end $$;

create or replace function rpc_r2984_escalated_engineers()
returns table(engineer text, hospital text, score int, rogue_devices int, action text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select engineer_name, hospital_name, discipline_score, rogue_devices_flagged, next_action
    from engineer_network_hygiene_discipline_r2984
    where status = 'escalated'
    order by discipline_score asc;
end $$;

create or replace function rpc_r2984_policy_tier_breakdown()
returns table(tier text, hospitals int, avg_kicks int, avg_cap int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select policy_tier, count(*)::int, avg(throttle_kicks)::int, avg(bandwidth_cap_mbps)::int
    from visitor_wifi_throttle_events_r2984
    where event_month = '2026-05-01'::date
    group by policy_tier order by policy_tier;
end $$;

create or replace function rpc_r2984_monthly_visit_top()
returns table(engineer text, monthly_visits int, ap_audits int, patches int, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select engineer_name, monthly_visits, ap_audits_done, firmware_patches_applied, e.status
    from engineer_network_hygiene_discipline_r2984 e
    where visit_month = '2026-05-01'::date
    order by monthly_visits desc, ap_audits_done desc;
end $$;

revoke all on visitor_wifi_throttle_events_r2984 from public, anon;
revoke all on engineer_network_hygiene_discipline_r2984 from public, anon;
grant select on visitor_wifi_throttle_events_r2984 to authenticated;
grant select on engineer_network_hygiene_discipline_r2984 to authenticated;

revoke all on function rpc_r2984_throttle_overview() from public, anon;
revoke all on function rpc_r2984_engineer_discipline() from public, anon;
revoke all on function rpc_r2984_hygiene_grade_mix() from public, anon;
revoke all on function rpc_r2984_isolation_offenders() from public, anon;
revoke all on function rpc_r2984_escalated_engineers() from public, anon;
revoke all on function rpc_r2984_policy_tier_breakdown() from public, anon;
revoke all on function rpc_r2984_monthly_visit_top() from public, anon;

grant execute on function rpc_r2984_throttle_overview() to authenticated;
grant execute on function rpc_r2984_engineer_discipline() to authenticated;
grant execute on function rpc_r2984_hygiene_grade_mix() to authenticated;
grant execute on function rpc_r2984_isolation_offenders() to authenticated;
grant execute on function rpc_r2984_escalated_engineers() to authenticated;
grant execute on function rpc_r2984_policy_tier_breakdown() to authenticated;
grant execute on function rpc_r2984_monthly_visit_top() to authenticated;
