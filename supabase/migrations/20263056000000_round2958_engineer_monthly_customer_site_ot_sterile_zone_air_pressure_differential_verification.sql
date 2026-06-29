-- Round 2958: Engineer Monthly Customer Site OT-Sterile-Zone Air-Pressure Differential Verification
-- HEAVY ★★★★

begin;

create table if not exists ot_air_pressure_verifications_r2958 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_name text not null,
  ot_room_code text not null,
  zone_class text not null check (zone_class in ('iso5','iso6','iso7','iso8')),
  required_delta_pa numeric(6,2) not null,
  measured_delta_pa numeric(6,2) not null,
  ambient_temp_c numeric(5,2) not null,
  ambient_rh_pct numeric(5,2) not null,
  hepa_age_months int not null,
  engineer_id uuid,
  visited_on date not null,
  status text not null check (status in ('pass','marginal','fail','retest')),
  remediation_required boolean not null default false,
  nabh_clause text not null,
  notes text
);

create table if not exists ot_pressure_remediation_actions_r2958 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  verification_id uuid references ot_air_pressure_verifications_r2958(id) on delete cascade,
  action_kind text not null check (action_kind in ('hepa_replace','damper_adjust','door_seal','blower_service','recalibrate','escalate')),
  priority text not null check (priority in ('p0','p1','p2','p3')),
  eta_hours int not null,
  cost_estimate_rupees int not null,
  vendor_required boolean not null default false,
  status text not null check (status in ('open','in_progress','done','blocked')),
  closed_on date
);

alter table ot_air_pressure_verifications_r2958 enable row level security;
alter table ot_pressure_remediation_actions_r2958 enable row level security;

drop policy if exists ot_apv_r2958_founder on ot_air_pressure_verifications_r2958;
create policy ot_apv_r2958_founder on ot_air_pressure_verifications_r2958
  for select to authenticated using (is_founder());

drop policy if exists ot_pra_r2958_founder on ot_pressure_remediation_actions_r2958;
create policy ot_pra_r2958_founder on ot_pressure_remediation_actions_r2958
  for select to authenticated using (is_founder());

insert into ot_air_pressure_verifications_r2958
  (hospital_name, ot_room_code, zone_class, required_delta_pa, measured_delta_pa, ambient_temp_c, ambient_rh_pct, hepa_age_months, visited_on, status, remediation_required, nabh_clause, notes)
values
  ('Apollo Jubilee Hills','OT-1','iso5',15.0,16.2,20.5,55.0,8,'2026-06-01'::date,'pass',false,'HCSO.1','baseline pass'),
  ('Apollo Jubilee Hills','OT-2','iso5',15.0,14.1,20.8,57.0,14,'2026-06-01'::date,'marginal',true,'HCSO.1','below spec by 0.9 Pa'),
  ('KIMS Secunderabad','OT-A','iso5',15.0,18.4,20.1,52.0,4,'2026-06-02'::date,'pass',false,'HCSO.1','fresh HEPA'),
  ('KIMS Secunderabad','OT-B','iso6',12.5,9.8,21.2,58.0,22,'2026-06-02'::date,'fail',true,'HCSO.1','HEPA loaded'),
  ('Yashoda Somajiguda','OT-3','iso5',15.0,15.5,20.0,54.0,10,'2026-06-03'::date,'pass',false,'HCSO.1','ok'),
  ('Yashoda Somajiguda','OT-4','iso7',10.0,10.6,21.0,56.5,16,'2026-06-03'::date,'pass',false,'HCSO.1','ok'),
  ('Continental Gachibowli','OT-1','iso5',15.0,11.2,20.4,59.0,28,'2026-06-04'::date,'fail',true,'HCSO.2','door seal worn'),
  ('Continental Gachibowli','OT-2','iso6',12.5,12.9,20.6,55.5,12,'2026-06-04'::date,'pass',false,'HCSO.1','ok'),
  ('Care Banjara','OT-A','iso5',15.0,13.8,20.9,57.5,18,'2026-06-05'::date,'marginal',true,'HCSO.1','damper tweak needed'),
  ('Care Banjara','OT-B','iso5',15.0,16.0,20.5,54.0,6,'2026-06-05'::date,'pass',false,'HCSO.1','ok'),
  ('Star Banjara','OT-1','iso7',10.0,7.8,21.5,60.0,20,'2026-06-06'::date,'fail',true,'HCSO.2','blower fault'),
  ('Star Banjara','OT-2','iso6',12.5,12.7,21.0,56.0,9,'2026-06-06'::date,'pass',false,'HCSO.1','ok'),
  ('Sunshine Paradise','OT-3','iso5',15.0,15.2,20.3,55.5,11,'2026-06-07'::date,'pass',false,'HCSO.1','ok'),
  ('Sunshine Paradise','OT-4','iso8',5.0,3.9,21.8,61.0,24,'2026-06-07'::date,'retest',true,'HCSO.1','recalibrate gauge'),
  ('Rainbow Hyd','OT-A','iso5',15.0,16.8,20.2,53.0,5,'2026-06-08'::date,'pass',false,'HCSO.1','ok'),
  ('Rainbow Hyd','OT-B','iso6',12.5,10.4,20.9,57.0,17,'2026-06-08'::date,'fail',true,'HCSO.2','damper jammed'),
  ('AIG Gachibowli','OT-1','iso5',15.0,15.9,20.6,55.0,7,'2026-06-09'::date,'pass',false,'HCSO.1','ok'),
  ('AIG Gachibowli','OT-2','iso5',15.0,14.5,20.8,56.5,13,'2026-06-09'::date,'marginal',true,'HCSO.1','watch HEPA'),
  ('Medicover Hitec','OT-3','iso7',10.0,11.1,21.2,58.0,15,'2026-06-10'::date,'pass',false,'HCSO.1','ok'),
  ('Medicover Hitec','OT-4','iso5',15.0,8.6,21.4,59.5,30,'2026-06-10'::date,'fail',true,'HCSO.2','HEPA replace now'),
  ('Citizens Nallagandla','OT-A','iso5',15.0,15.7,20.1,54.5,8,'2026-06-11'::date,'pass',false,'HCSO.1','ok'),
  ('Citizens Nallagandla','OT-B','iso6',12.5,13.2,20.7,55.0,11,'2026-06-11'::date,'pass',false,'HCSO.1','ok');

insert into ot_pressure_remediation_actions_r2958
  (verification_id, action_kind, priority, eta_hours, cost_estimate_rupees, vendor_required, status, closed_on)
select id, 'hepa_replace','p1',48,42000,true,'open',null from ot_air_pressure_verifications_r2958 where status='fail' limit 1;

insert into ot_pressure_remediation_actions_r2958
  (action_kind, priority, eta_hours, cost_estimate_rupees, vendor_required, status, closed_on)
values
  ('hepa_replace','p1',48,42000,true,'in_progress',null),
  ('damper_adjust','p2',24,4500,false,'open',null),
  ('door_seal','p1',12,2800,false,'done','2026-06-05'::date),
  ('blower_service','p0',8,18000,true,'in_progress',null),
  ('recalibrate','p3',72,1500,false,'open',null),
  ('hepa_replace','p1',48,42000,true,'done','2026-06-12'::date),
  ('damper_adjust','p2',24,4500,false,'blocked',null),
  ('escalate','p0',4,0,false,'done','2026-06-04'::date),
  ('door_seal','p2',24,3200,false,'open',null),
  ('blower_service','p1',24,15000,true,'open',null),
  ('hepa_replace','p1',48,42000,true,'in_progress',null),
  ('recalibrate','p3',72,1500,false,'done','2026-06-08'::date),
  ('damper_adjust','p1',12,5200,false,'open',null),
  ('door_seal','p2',24,2900,false,'in_progress',null),
  ('escalate','p0',4,0,false,'open',null);

create or replace function founder_r2958_summary()
returns table(total_verifications int, pass_count int, fail_count int, marginal_count int, retest_count int, remediation_open int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      (select count(*) from ot_air_pressure_verifications_r2958)::int,
      (select count(*) filter (where status='pass') from ot_air_pressure_verifications_r2958)::int,
      (select count(*) filter (where status='fail') from ot_air_pressure_verifications_r2958)::int,
      (select count(*) filter (where status='marginal') from ot_air_pressure_verifications_r2958)::int,
      (select count(*) filter (where status='retest') from ot_air_pressure_verifications_r2958)::int,
      (select count(*) filter (where status in ('open','in_progress')) from ot_pressure_remediation_actions_r2958)::int;
end $$;

create or replace function founder_r2958_failures()
returns table(hospital_name text, ot_room_code text, zone_class text, required_delta_pa numeric, measured_delta_pa numeric, deficit numeric, visited_on date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.hospital_name, v.ot_room_code, v.zone_class, v.required_delta_pa, v.measured_delta_pa,
           (v.required_delta_pa - v.measured_delta_pa)::numeric as deficit, v.visited_on
    from ot_air_pressure_verifications_r2958 v
    where v.status in ('fail','marginal')
    order by deficit desc;
end $$;

create or replace function founder_r2958_by_zone()
returns table(zone_class text, n int, pass_n int, fail_n int, avg_delta numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.zone_class,
           count(*)::int,
           (count(*) filter (where v.status='pass'))::int,
           (count(*) filter (where v.status='fail'))::int,
           round(avg(v.measured_delta_pa)::numeric, 2)
    from ot_air_pressure_verifications_r2958 v
    group by v.zone_class
    order by v.zone_class;
end $$;

create or replace function founder_r2958_hepa_risk()
returns table(hospital_name text, ot_room_code text, hepa_age_months int, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.hospital_name, v.ot_room_code, v.hepa_age_months, v.status
    from ot_air_pressure_verifications_r2958 v
    where v.hepa_age_months >= 18
    order by v.hepa_age_months desc;
end $$;

create or replace function founder_r2958_remediation_queue()
returns table(action_kind text, priority text, status text, n int, total_cost int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.action_kind, a.priority, a.status,
           count(*)::int,
           sum(a.cost_estimate_rupees)::int
    from ot_pressure_remediation_actions_r2958 a
    group by a.action_kind, a.priority, a.status
    order by a.priority, a.action_kind;
end $$;

create or replace function founder_r2958_hospital_scorecard()
returns table(hospital_name text, rooms int, pass_n int, fail_n int, pass_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.hospital_name,
           count(*)::int,
           (count(*) filter (where v.status='pass'))::int,
           (count(*) filter (where v.status='fail'))::int,
           round(100.0 * (count(*) filter (where v.status='pass'))::numeric / nullif(count(*),0), 1)
    from ot_air_pressure_verifications_r2958 v
    group by v.hospital_name
    order by pass_pct asc nulls last;
end $$;

create or replace function founder_r2958_daily_trend()
returns table(visited_on date, n int, pass_n int, fail_n int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.visited_on,
           count(*)::int,
           (count(*) filter (where v.status='pass'))::int,
           (count(*) filter (where v.status='fail'))::int
    from ot_air_pressure_verifications_r2958 v
    group by v.visited_on
    order by v.visited_on;
end $$;

revoke all on function founder_r2958_summary() from public, anon;
revoke all on function founder_r2958_failures() from public, anon;
revoke all on function founder_r2958_by_zone() from public, anon;
revoke all on function founder_r2958_hepa_risk() from public, anon;
revoke all on function founder_r2958_remediation_queue() from public, anon;
revoke all on function founder_r2958_hospital_scorecard() from public, anon;
revoke all on function founder_r2958_daily_trend() from public, anon;

grant execute on function founder_r2958_summary() to authenticated;
grant execute on function founder_r2958_failures() to authenticated;
grant execute on function founder_r2958_by_zone() to authenticated;
grant execute on function founder_r2958_hepa_risk() to authenticated;
grant execute on function founder_r2958_remediation_queue() to authenticated;
grant execute on function founder_r2958_hospital_scorecard() to authenticated;
grant execute on function founder_r2958_daily_trend() to authenticated;

commit;
