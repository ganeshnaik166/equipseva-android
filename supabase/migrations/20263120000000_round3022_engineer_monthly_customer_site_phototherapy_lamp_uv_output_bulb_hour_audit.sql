-- Round r3022: Engineer Monthly Customer Site Phototherapy Lamp UV Output & Bulb Hour Audit
-- Tracks monthly UV radiometer readings + bulb hour ledger at hospital sites.

create table if not exists phototherapy_lamp_uv_audits_r3022 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_month date not null,
  hospital_name text not null,
  city text not null,
  ward text not null,
  lamp_serial text not null,
  lamp_model text not null,
  engineer_name text not null,
  measured_irradiance_uw_cm2 numeric(8,2) not null,
  spec_min_irradiance_uw_cm2 numeric(8,2) not null default 30.00,
  bulb_hours_used int not null,
  bulb_hours_rated int not null default 2000,
  pass_fail text not null check (pass_fail in ('pass','marginal','fail')),
  action_taken text not null check (action_taken in ('none','bulb_replaced','lamp_swapped','escalated','rescheduled')),
  bulb_replacement_due_within_days int,
  audit_notes text
);

create table if not exists phototherapy_bulb_hour_ledger_r3022 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid references phototherapy_lamp_uv_audits_r3022(id) on delete cascade,
  event_date date not null,
  event_type text not null check (event_type in ('reading','bulb_install','bulb_replace','lamp_decommission','recalibration')),
  hours_delta int not null default 0,
  cumulative_hours int not null,
  performed_by text not null,
  part_cost_rupees int not null default 0,
  labor_cost_rupees int not null default 0,
  notes text
);

alter table phototherapy_lamp_uv_audits_r3022 enable row level security;
alter table phototherapy_bulb_hour_ledger_r3022 enable row level security;

drop policy if exists founder_read_uv on phototherapy_lamp_uv_audits_r3022;
create policy founder_read_uv on phototherapy_lamp_uv_audits_r3022 for select to authenticated using (is_founder());

drop policy if exists founder_read_ledger on phototherapy_bulb_hour_ledger_r3022;
create policy founder_read_ledger on phototherapy_bulb_hour_ledger_r3022 for select to authenticated using (is_founder());

-- Seed audits (18 rows)
insert into phototherapy_lamp_uv_audits_r3022
  (audit_month, hospital_name, city, ward, lamp_serial, lamp_model, engineer_name, measured_irradiance_uw_cm2, bulb_hours_used, pass_fail, action_taken, bulb_replacement_due_within_days, audit_notes)
values
  ('2026-06-01'::date,'Rainbow Childrens','Hyderabad','NICU-A','PT-RC-001','Phoenix BiliBlue 360',  'Ravi K',     42.10, 380, 'pass','none',          1620,'optimal output'),
  ('2026-06-01'::date,'Rainbow Childrens','Hyderabad','NICU-B','PT-RC-002','Phoenix BiliBlue 360',  'Ravi K',     31.40,1640, 'marginal','none',       360,'within spec but bulb nearing EOL'),
  ('2026-06-01'::date,'Rainbow Childrens','Hyderabad','NICU-C','PT-RC-003','Phoenix BiliBlue 360',  'Ravi K',     24.80,1980, 'fail','bulb_replaced',  2000,'irradiance below 30, replaced bulb same visit'),
  ('2026-06-01'::date,'Apollo Cradle','Bangalore','SCBU-1','PT-AC-101','GE Lullaby LED',           'Suresh M',   45.20, 120, 'pass','none',          1880,'new install month 2'),
  ('2026-06-01'::date,'Apollo Cradle','Bangalore','SCBU-2','PT-AC-102','GE Lullaby LED',           'Suresh M',   38.60, 720, 'pass','none',          1280,'normal aging'),
  ('2026-06-01'::date,'Fortis La Femme','Delhi','NICU-1','PT-FL-201','Phoenix BiliBlue 360',       'Naveen P',   28.10,1850, 'fail','bulb_replaced',  2000,'fail then replace, post-replace 44.5'),
  ('2026-06-01'::date,'Fortis La Femme','Delhi','NICU-2','PT-FL-202','Atom Phototherapy 2000',     'Naveen P',   33.40, 940, 'marginal','none',      1060,'spec ok bulb mid-life'),
  ('2026-06-01'::date,'Manipal Hospital','Pune','Special Care','PT-MN-301','GE Lullaby LED',       'Kiran D',    41.70, 560, 'pass','none',          1440,'routine'),
  ('2026-06-01'::date,'Manipal Hospital','Pune','NICU','PT-MN-302','GE Lullaby LED',               'Kiran D',    19.20, 220, 'fail','lamp_swapped',   1780,'unexpected fail at 220h — lamp swapped, RMA'),
  ('2026-06-01'::date,'Cloudnine','Chennai','NICU-East','PT-CN-401','Phoenix BiliBlue 360',        'Ashok V',    36.80, 880, 'pass','none',          1120,'fine'),
  ('2026-06-01'::date,'Cloudnine','Chennai','NICU-West','PT-CN-402','Phoenix BiliBlue 360',        'Ashok V',    29.40,1720, 'fail','escalated',     2000,'engineer flagged, awaiting parts'),
  ('2026-06-01'::date,'KIMS Cuddles','Hyderabad','NICU','PT-KI-501','Atom Phototherapy 2000',      'Ravi K',     34.10, 410, 'pass','none',          1590,'good'),
  ('2026-06-01'::date,'Motherhood','Bangalore','Level-2','PT-MO-601','GE Lullaby LED',             'Suresh M',   30.20,1550, 'marginal','none',       450,'right at threshold'),
  ('2026-06-01'::date,'Motherhood','Bangalore','Level-3','PT-MO-602','GE Lullaby LED',             'Suresh M',   46.80, 60,  'pass','none',          1940,'new bulb installed last month'),
  ('2026-06-01'::date,'Surya Hospital','Mumbai','NICU-A','PT-SU-701','Phoenix BiliBlue 360',       'Vikas T',    27.50,1880, 'fail','rescheduled',   2000,'rescheduled — hospital busy, return in 7d'),
  ('2026-06-01'::date,'Surya Hospital','Mumbai','NICU-B','PT-SU-702','Phoenix BiliBlue 360',       'Vikas T',    39.40, 640, 'pass','none',          1360,'normal'),
  ('2026-06-01'::date,'Ankura Hospital','Hyderabad','NICU','PT-AN-801','Atom Phototherapy 2000',   'Ravi K',     22.10,1940, 'fail','bulb_replaced',  2000,'critical fail — bulb replaced'),
  ('2026-06-01'::date,'Ankura Hospital','Hyderabad','Special Care','PT-AN-802','Atom Phototherapy 2000','Ravi K',43.60, 280, 'pass','none',          1720,'fresh install');

-- Seed ledger (24 rows)
insert into phototherapy_bulb_hour_ledger_r3022
  (event_date, event_type, hours_delta, cumulative_hours, performed_by, part_cost_rupees, labor_cost_rupees, notes)
values
  ('2026-06-01'::date,'reading',     0,  380, 'Ravi K',     0,    400,  'monthly reading rainbow NICU-A'),
  ('2026-06-01'::date,'reading',     0, 1640, 'Ravi K',     0,    400,  'monthly reading rainbow NICU-B'),
  ('2026-06-01'::date,'bulb_replace',0,    0, 'Ravi K',  3800,    600,  'rainbow NICU-C bulb swap after fail'),
  ('2026-06-01'::date,'reading',     0,  120, 'Suresh M',   0,    400,  'apollo SCBU-1'),
  ('2026-06-01'::date,'reading',     0,  720, 'Suresh M',   0,    400,  'apollo SCBU-2'),
  ('2026-06-01'::date,'bulb_replace',0,    0, 'Naveen P',3800,    600,  'fortis NICU-1 bulb swap'),
  ('2026-06-01'::date,'reading',     0,  940, 'Naveen P',   0,    400,  'fortis NICU-2'),
  ('2026-06-01'::date,'reading',     0,  560, 'Kiran D',    0,    400,  'manipal special care'),
  ('2026-06-01'::date,'lamp_decommission',0,220,'Kiran D',  0,   1200,  'manipal NICU lamp swap, RMA outbound'),
  ('2026-06-01'::date,'bulb_install',0,    0, 'Kiran D', 3800,    900,  'manipal NICU replacement lamp install'),
  ('2026-06-01'::date,'reading',     0,  880, 'Ashok V',    0,    400,  'cloudnine east'),
  ('2026-06-01'::date,'reading',     0, 1720, 'Ashok V',    0,    400,  'cloudnine west — fail logged, parts on order'),
  ('2026-06-01'::date,'reading',     0,  410, 'Ravi K',     0,    400,  'kims cuddles'),
  ('2026-06-01'::date,'reading',     0, 1550, 'Suresh M',   0,    400,  'motherhood L2 marginal'),
  ('2026-06-01'::date,'reading',     0,   60, 'Suresh M',   0,    400,  'motherhood L3 new bulb'),
  ('2026-06-01'::date,'reading',     0, 1880, 'Vikas T',    0,    400,  'surya NICU-A — return scheduled'),
  ('2026-06-01'::date,'reading',     0,  640, 'Vikas T',    0,    400,  'surya NICU-B'),
  ('2026-06-01'::date,'bulb_replace',0,    0, 'Ravi K',  3800,    600,  'ankura NICU bulb replace'),
  ('2026-06-01'::date,'reading',     0,  280, 'Ravi K',     0,    400,  'ankura special care'),
  ('2026-05-01'::date,'bulb_install',0,    0, 'Suresh M',3800,    900,  'motherhood L3 prior month install'),
  ('2026-05-01'::date,'bulb_install',0,    0, 'Ravi K',  3800,    900,  'ankura special care prior month install'),
  ('2026-05-01'::date,'recalibration',0,   0, 'Suresh M',   0,    500,  'apollo radiometer recalibration'),
  ('2026-04-01'::date,'bulb_install',0,    0, 'Ravi K',  3800,    900,  'rainbow NICU-A initial install date'),
  ('2026-03-01'::date,'bulb_install',0,    0, 'Naveen P',3800,    900,  'fortis NICU-1 prior bulb install');

-- RPC 1: monthly fleet summary
create or replace function rpc_r3022_fleet_summary()
returns table(
  total_lamps int,
  passed int,
  marginal int,
  failed int,
  pass_rate_pct numeric,
  avg_irradiance numeric,
  bulbs_replaced int,
  lamps_swapped int
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int as total_lamps,
    (count(*) filter (where pass_fail='pass'))::int as passed,
    (count(*) filter (where pass_fail='marginal'))::int as marginal,
    (count(*) filter (where pass_fail='fail'))::int as failed,
    round(100.0 * (count(*) filter (where pass_fail='pass'))::numeric / nullif(count(*),0), 1) as pass_rate_pct,
    round(avg(measured_irradiance_uw_cm2), 2) as avg_irradiance,
    (count(*) filter (where action_taken='bulb_replaced'))::int as bulbs_replaced,
    (count(*) filter (where action_taken='lamp_swapped'))::int as lamps_swapped
  from phototherapy_lamp_uv_audits_r3022;
end; $$;

-- RPC 2: failures detail
create or replace function rpc_r3022_failures()
returns table(
  hospital_name text,
  ward text,
  lamp_serial text,
  measured_irradiance_uw_cm2 numeric,
  bulb_hours_used int,
  action_taken text,
  audit_notes text
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.ward, a.lamp_serial, a.measured_irradiance_uw_cm2,
         a.bulb_hours_used, a.action_taken, a.audit_notes
  from phototherapy_lamp_uv_audits_r3022 a
  where a.pass_fail = 'fail'
  order by a.measured_irradiance_uw_cm2 asc;
end; $$;

-- RPC 3: hospital rollup
create or replace function rpc_r3022_hospital_rollup()
returns table(
  hospital_name text,
  city text,
  lamps_audited int,
  failures int,
  avg_irradiance numeric,
  oldest_bulb_hours int
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.city,
         count(*)::int as lamps_audited,
         (count(*) filter (where a.pass_fail='fail'))::int as failures,
         round(avg(a.measured_irradiance_uw_cm2),2) as avg_irradiance,
         max(a.bulb_hours_used)::int as oldest_bulb_hours
  from phototherapy_lamp_uv_audits_r3022 a
  group by a.hospital_name, a.city
  order by failures desc, lamps_audited desc;
end; $$;

-- RPC 4: engineer scorecard
create or replace function rpc_r3022_engineer_scorecard()
returns table(
  engineer_name text,
  lamps_audited int,
  failures_found int,
  bulbs_replaced int,
  avg_irradiance numeric
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name,
         count(*)::int as lamps_audited,
         (count(*) filter (where a.pass_fail='fail'))::int as failures_found,
         (count(*) filter (where a.action_taken='bulb_replaced'))::int as bulbs_replaced,
         round(avg(a.measured_irradiance_uw_cm2),2) as avg_irradiance
  from phototherapy_lamp_uv_audits_r3022 a
  group by a.engineer_name
  order by lamps_audited desc;
end; $$;

-- RPC 5: bulbs nearing EOL
create or replace function rpc_r3022_bulbs_nearing_eol()
returns table(
  hospital_name text,
  ward text,
  lamp_serial text,
  bulb_hours_used int,
  bulb_hours_rated int,
  pct_consumed numeric,
  replacement_due_within_days int
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.ward, a.lamp_serial, a.bulb_hours_used, a.bulb_hours_rated,
         round(100.0 * a.bulb_hours_used::numeric / nullif(a.bulb_hours_rated,0), 1) as pct_consumed,
         a.bulb_replacement_due_within_days
  from phototherapy_lamp_uv_audits_r3022 a
  where a.bulb_hours_used::numeric / nullif(a.bulb_hours_rated,0) >= 0.75
    and a.action_taken not in ('bulb_replaced','lamp_swapped')
  order by pct_consumed desc;
end; $$;

-- RPC 6: lamp model performance
create or replace function rpc_r3022_lamp_model_perf()
returns table(
  lamp_model text,
  units int,
  failures int,
  fail_pct numeric,
  avg_irradiance numeric
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.lamp_model,
         count(*)::int as units,
         (count(*) filter (where a.pass_fail='fail'))::int as failures,
         round(100.0 * (count(*) filter (where a.pass_fail='fail'))::numeric / nullif(count(*),0), 1) as fail_pct,
         round(avg(a.measured_irradiance_uw_cm2),2) as avg_irradiance
  from phototherapy_lamp_uv_audits_r3022 a
  group by a.lamp_model
  order by fail_pct desc;
end; $$;

-- RPC 7: cost ledger summary
create or replace function rpc_r3022_cost_summary()
returns table(
  event_type text,
  events int,
  total_parts_rupees int,
  total_labor_rupees int,
  total_rupees int
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.event_type,
         count(*)::int as events,
         sum(l.part_cost_rupees)::int as total_parts_rupees,
         sum(l.labor_cost_rupees)::int as total_labor_rupees,
         (sum(l.part_cost_rupees) + sum(l.labor_cost_rupees))::int as total_rupees
  from phototherapy_bulb_hour_ledger_r3022 l
  group by l.event_type
  order by total_rupees desc;
end; $$;

-- RPC 8: recent ledger feed
create or replace function rpc_r3022_recent_ledger()
returns table(
  event_date date,
  event_type text,
  performed_by text,
  cumulative_hours int,
  part_cost_rupees int,
  labor_cost_rupees int,
  notes text
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.event_date, l.event_type, l.performed_by, l.cumulative_hours,
         l.part_cost_rupees, l.labor_cost_rupees, l.notes
  from phototherapy_bulb_hour_ledger_r3022 l
  order by l.event_date desc, l.created_at desc
  limit 30;
end; $$;

revoke all on function rpc_r3022_fleet_summary() from public, anon;
revoke all on function rpc_r3022_failures() from public, anon;
revoke all on function rpc_r3022_hospital_rollup() from public, anon;
revoke all on function rpc_r3022_engineer_scorecard() from public, anon;
revoke all on function rpc_r3022_bulbs_nearing_eol() from public, anon;
revoke all on function rpc_r3022_lamp_model_perf() from public, anon;
revoke all on function rpc_r3022_cost_summary() from public, anon;
revoke all on function rpc_r3022_recent_ledger() from public, anon;

grant execute on function rpc_r3022_fleet_summary() to authenticated;
grant execute on function rpc_r3022_failures() to authenticated;
grant execute on function rpc_r3022_hospital_rollup() to authenticated;
grant execute on function rpc_r3022_engineer_scorecard() to authenticated;
grant execute on function rpc_r3022_bulbs_nearing_eol() to authenticated;
grant execute on function rpc_r3022_lamp_model_perf() to authenticated;
grant execute on function rpc_r3022_cost_summary() to authenticated;
grant execute on function rpc_r3022_recent_ledger() to authenticated;

revoke all on phototherapy_lamp_uv_audits_r3022 from public, anon;
revoke all on phototherapy_bulb_hour_ledger_r3022 from public, anon;
grant select on phototherapy_lamp_uv_audits_r3022 to authenticated;
grant select on phototherapy_bulb_hour_ledger_r3022 to authenticated;
