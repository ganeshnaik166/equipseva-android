-- Round 3011: Hospital Chain Quarterly Equipment OEM Field-Service-Engineer Coordination Latency Audit

create table if not exists hospital_chain_quarterly_oem_engineer_audit_r3011 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  quarter_label text not null check (quarter_label in ('Q4-2025','Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  hospital_count int not null check (hospital_count between 1 and 500),
  equipment_units int not null check (equipment_units between 10 and 5000),
  oem_partner text not null check (oem_partner in ('GE Healthcare','Siemens Healthineers','Philips','Mindray','BPL Medical','Drager','Nihon Kohden','Medtronic')),
  audit_status text not null check (audit_status in ('scheduled','in_progress','completed','escalated','signed_off')),
  median_dispatch_latency_min int not null check (median_dispatch_latency_min between 0 and 600),
  median_onsite_latency_min int not null check (median_onsite_latency_min between 0 and 1440),
  median_resolution_latency_min int not null check (median_resolution_latency_min between 0 and 5760),
  sla_breach_count int not null default 0 check (sla_breach_count >= 0),
  audit_score numeric(5,2) not null check (audit_score between 0 and 100),
  audit_window_start timestamptz not null,
  audit_window_end timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists hospital_chain_quarterly_oem_engineer_audit_visits_r3011 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references hospital_chain_quarterly_oem_engineer_audit_r3011(id) on delete cascade,
  hospital_unit text not null,
  city text not null check (city in ('Mumbai','Delhi','Bengaluru','Hyderabad','Chennai','Kolkata','Pune','Ahmedabad','Jaipur','Lucknow')),
  equipment_category text not null check (equipment_category in ('mri','ct','ultrasound','ventilator','dialysis','xray','cath_lab','anesthesia','monitor','lab_analyzer')),
  visit_type text not null check (visit_type in ('preventive','corrective','calibration','upgrade','emergency')),
  visit_status text not null check (visit_status in ('open','en_route','on_site','closed','reopened','no_show')),
  engineer_assigned text not null,
  dispatch_latency_min int not null check (dispatch_latency_min between 0 and 2880),
  onsite_latency_min int not null check (onsite_latency_min between 0 and 5760),
  resolution_latency_min int not null check (resolution_latency_min between 0 and 11520),
  sla_status text not null check (sla_status in ('within','at_risk','breached','waived')),
  pass_fail text not null check (pass_fail in ('pass','fail','partial')),
  visited_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

alter table hospital_chain_quarterly_oem_engineer_audit_r3011 enable row level security;
alter table hospital_chain_quarterly_oem_engineer_audit_visits_r3011 enable row level security;

drop policy if exists hcq_audit_r3011_founder on hospital_chain_quarterly_oem_engineer_audit_r3011;
create policy hcq_audit_r3011_founder on hospital_chain_quarterly_oem_engineer_audit_r3011
  for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists hcq_visits_r3011_founder on hospital_chain_quarterly_oem_engineer_audit_visits_r3011;
create policy hcq_visits_r3011_founder on hospital_chain_quarterly_oem_engineer_audit_visits_r3011
  for all to authenticated using (is_founder()) with check (is_founder());

revoke all on hospital_chain_quarterly_oem_engineer_audit_r3011 from public, anon;
revoke all on hospital_chain_quarterly_oem_engineer_audit_visits_r3011 from public, anon;
grant select, insert, update, delete on hospital_chain_quarterly_oem_engineer_audit_r3011 to authenticated;
grant select, insert, update, delete on hospital_chain_quarterly_oem_engineer_audit_visits_r3011 to authenticated;

-- Seed audits
insert into hospital_chain_quarterly_oem_engineer_audit_r3011
  (chain_name, quarter_label, hospital_count, equipment_units, oem_partner, audit_status, median_dispatch_latency_min, median_onsite_latency_min, median_resolution_latency_min, sla_breach_count, audit_score, audit_window_start, audit_window_end)
select 'Apollo Group', 'Q1-2026', 72, 3400, 'GE Healthcare', 'completed', 42, 180, 720, 14, 87.50, '2026-01-05'::timestamptz, '2026-03-25'::timestamptz
union all select 'Fortis Healthcare', 'Q1-2026', 36, 1800, 'Siemens Healthineers', 'signed_off', 38, 165, 640, 9, 90.20, '2026-01-08'::timestamptz, '2026-03-28'::timestamptz
union all select 'Max Healthcare', 'Q1-2026', 18, 920, 'Philips', 'completed', 55, 220, 880, 18, 82.10, '2026-01-12'::timestamptz, '2026-03-30'::timestamptz
union all select 'Manipal Hospitals', 'Q2-2026', 28, 1340, 'GE Healthcare', 'in_progress', 48, 195, 760, 12, 85.40, '2026-04-02'::timestamptz, null::timestamptz
union all select 'Narayana Health', 'Q2-2026', 24, 1100, 'Mindray', 'in_progress', 62, 245, 920, 21, 78.90, '2026-04-05'::timestamptz, null
union all select 'Aster DM', 'Q2-2026', 16, 780, 'Siemens Healthineers', 'escalated', 95, 360, 1480, 34, 68.20, '2026-04-07'::timestamptz, null
union all select 'Medanta Group', 'Q2-2026', 8, 540, 'Philips', 'completed', 35, 150, 580, 6, 92.80, '2026-04-10'::timestamptz, '2026-06-20'::timestamptz
union all select 'Wockhardt Hospitals', 'Q2-2026', 10, 420, 'BPL Medical', 'scheduled', 70, 280, 1100, 19, 75.60, '2026-05-01'::timestamptz, null
union all select 'KIMS Hospitals', 'Q3-2026', 14, 680, 'Drager', 'scheduled', 58, 230, 880, 15, 80.40, '2026-07-01'::timestamptz, null
union all select 'Yashoda Hospitals', 'Q3-2026', 6, 360, 'Nihon Kohden', 'scheduled', 44, 175, 690, 8, 88.10, '2026-07-05'::timestamptz, null
union all select 'Columbia Asia', 'Q4-2025', 12, 540, 'GE Healthcare', 'signed_off', 50, 210, 840, 13, 84.20, '2025-10-01'::timestamptz, '2025-12-22'::timestamptz
union all select 'Care Hospitals', 'Q4-2025', 16, 720, 'Medtronic', 'signed_off', 65, 260, 1020, 22, 76.80, '2025-10-05'::timestamptz, '2025-12-28'::timestamptz
union all select 'Continental Hospitals', 'Q1-2027', 4, 280, 'Philips', 'scheduled', 0, 0, 0, 0, 0.00, '2027-01-08'::timestamptz, null
union all select 'Ramaiah Memorial', 'Q1-2026', 5, 240, 'Siemens Healthineers', 'completed', 40, 170, 670, 7, 89.30, '2026-01-15'::timestamptz, '2026-03-29'::timestamptz
union all select 'Sahyadri Hospitals', 'Q2-2026', 9, 380, 'GE Healthcare', 'escalated', 110, 420, 1680, 41, 64.50, '2026-04-12'::timestamptz, null;

-- Seed visits
with a as (select id, chain_name from hospital_chain_quarterly_oem_engineer_audit_r3011)
insert into hospital_chain_quarterly_oem_engineer_audit_visits_r3011
  (audit_id, hospital_unit, city, equipment_category, visit_type, visit_status, engineer_assigned, dispatch_latency_min, onsite_latency_min, resolution_latency_min, sla_status, pass_fail, visited_at, resolved_at)
select (select id from a where chain_name='Apollo Group'), 'Apollo Jubilee Hills', 'Hyderabad', 'mri', 'corrective', 'closed', 'R. Kumar', 35, 160, 640, 'within', 'pass', '2026-01-12 09:30'::timestamptz, '2026-01-12 20:10'::timestamptz
union all select (select id from a where chain_name='Apollo Group'), 'Apollo Chennai', 'Chennai', 'ct', 'preventive', 'closed', 'M. Iyer', 28, 140, 520, 'within', 'pass', '2026-01-18 10:00'::timestamptz, '2026-01-18 18:40'::timestamptz
union all select (select id from a where chain_name='Apollo Group'), 'Apollo Bannerghatta', 'Bengaluru', 'cath_lab', 'emergency', 'closed', 'S. Reddy', 75, 280, 1320, 'breached', 'partial', '2026-02-04 14:15'::timestamptz, '2026-02-05 12:15'::timestamptz
union all select (select id from a where chain_name='Fortis Healthcare'), 'Fortis Mulund', 'Mumbai', 'ventilator', 'corrective', 'closed', 'A. Shah', 32, 150, 600, 'within', 'pass', '2026-01-22 11:00'::timestamptz, '2026-01-22 21:00'::timestamptz
union all select (select id from a where chain_name='Fortis Healthcare'), 'Fortis Gurgaon', 'Delhi', 'mri', 'calibration', 'closed', 'V. Singh', 45, 200, 780, 'within', 'pass', '2026-02-08 09:45'::timestamptz, '2026-02-08 22:45'::timestamptz
union all select (select id from a where chain_name='Max Healthcare'), 'Max Saket', 'Delhi', 'dialysis', 'corrective', 'reopened', 'P. Mehta', 88, 320, 1280, 'breached', 'fail', '2026-02-14 13:20'::timestamptz, null::timestamptz
union all select (select id from a where chain_name='Max Healthcare'), 'Max Patparganj', 'Delhi', 'anesthesia', 'preventive', 'closed', 'D. Gupta', 50, 210, 820, 'within', 'pass', '2026-02-20 10:30'::timestamptz, '2026-02-21 00:10'::timestamptz
union all select (select id from a where chain_name='Manipal Hospitals'), 'Manipal Whitefield', 'Bengaluru', 'ultrasound', 'corrective', 'on_site', 'K. Rao', 42, 180, 0, 'at_risk', 'partial', '2026-04-15 12:00'::timestamptz, null
union all select (select id from a where chain_name='Manipal Hospitals'), 'Manipal Old Airport', 'Bengaluru', 'monitor', 'preventive', 'closed', 'N. Hegde', 30, 140, 540, 'within', 'pass', '2026-04-22 09:00'::timestamptz, '2026-04-22 18:00'::timestamptz
union all select (select id from a where chain_name='Narayana Health'), 'NH Bommasandra', 'Bengaluru', 'cath_lab', 'emergency', 'closed', 'T. Nair', 105, 380, 1520, 'breached', 'fail', '2026-04-18 16:30'::timestamptz, '2026-04-19 18:00'::timestamptz
union all select (select id from a where chain_name='Narayana Health'), 'NH RTIICS Kolkata', 'Kolkata', 'lab_analyzer', 'calibration', 'closed', 'B. Das', 55, 220, 880, 'within', 'pass', '2026-04-25 10:00'::timestamptz, '2026-04-26 00:40'::timestamptz
union all select (select id from a where chain_name='Aster DM'), 'Aster Medcity', 'Bengaluru', 'mri', 'upgrade', 'en_route', 'J. Pillai', 130, 0, 0, 'breached', 'partial', null, null
union all select (select id from a where chain_name='Aster DM'), 'Aster CMI', 'Bengaluru', 'ct', 'corrective', 'no_show', 'L. Joseph', 240, 0, 0, 'breached', 'fail', null, null
union all select (select id from a where chain_name='Medanta Group'), 'Medanta Gurgaon', 'Delhi', 'cath_lab', 'preventive', 'closed', 'H. Verma', 28, 130, 510, 'within', 'pass', '2026-04-15 09:30'::timestamptz, '2026-04-15 18:00'::timestamptz
union all select (select id from a where chain_name='Medanta Group'), 'Medanta Lucknow', 'Lucknow', 'dialysis', 'corrective', 'closed', 'R. Tiwari', 38, 160, 600, 'within', 'pass', '2026-05-02 11:00'::timestamptz, '2026-05-02 21:00'::timestamptz
union all select (select id from a where chain_name='Sahyadri Hospitals'), 'Sahyadri Deccan', 'Pune', 'ventilator', 'emergency', 'closed', 'A. Kulkarni', 145, 460, 1840, 'breached', 'fail', '2026-04-22 18:00'::timestamptz, '2026-04-24 00:40'::timestamptz
union all select (select id from a where chain_name='KIMS Hospitals'), 'KIMS Secunderabad', 'Hyderabad', 'anesthesia', 'preventive', 'open', 'S. Murthy', 0, 0, 0, 'at_risk', 'partial', null, null
union all select (select id from a where chain_name='Yashoda Hospitals'), 'Yashoda Somajiguda', 'Hyderabad', 'monitor', 'calibration', 'open', 'G. Prasad', 0, 0, 0, 'within', 'partial', null, null
union all select (select id from a where chain_name='Care Hospitals'), 'Care Banjara Hills', 'Hyderabad', 'xray', 'preventive', 'closed', 'V. Naidu', 60, 240, 920, 'within', 'pass', '2025-10-15 09:00'::timestamptz, '2025-10-16 00:20'::timestamptz
union all select (select id from a where chain_name='Care Hospitals'), 'Care Nampally', 'Hyderabad', 'ct', 'corrective', 'closed', 'P. Krishna', 78, 300, 1180, 'breached', 'partial', '2025-11-04 14:00'::timestamptz, '2025-11-05 09:40'::timestamptz
union all select (select id from a where chain_name='Ramaiah Memorial'), 'Ramaiah MSR', 'Bengaluru', 'ultrasound', 'preventive', 'closed', 'C. Bhat', 40, 170, 670, 'within', 'pass', '2026-01-20 09:00'::timestamptz, '2026-01-20 20:10'::timestamptz
union all select (select id from a where chain_name='Columbia Asia'), 'Columbia Hebbal', 'Bengaluru', 'mri', 'calibration', 'closed', 'F. Khan', 52, 215, 840, 'within', 'pass', '2025-10-22 10:00'::timestamptz, '2025-10-23 00:00'::timestamptz
union all select (select id from a where chain_name='Wockhardt Hospitals'), 'Wockhardt Mira Road', 'Mumbai', 'lab_analyzer', 'preventive', 'open', 'I. Patel', 0, 0, 0, 'within', 'partial', null, null;

-- RPC 1: chain summary
create or replace function founder_r3011_chain_summary()
returns table(chain_name text, quarters_audited int, hospitals int, units int, avg_score numeric, total_breaches int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select a.chain_name, count(*)::int, sum(a.hospital_count)::int, sum(a.equipment_units)::int,
         round(avg(a.audit_score),2), sum(a.sla_breach_count)::int
  from hospital_chain_quarterly_oem_engineer_audit_r3011 a
  group by a.chain_name order by sum(a.sla_breach_count) desc;
end; $$;

-- RPC 2: oem latency
create or replace function founder_r3011_oem_latency()
returns table(oem_partner text, audits int, avg_dispatch numeric, avg_onsite numeric, avg_resolution numeric, breaches int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select a.oem_partner, count(*)::int,
         round(avg(a.median_dispatch_latency_min),1),
         round(avg(a.median_onsite_latency_min),1),
         round(avg(a.median_resolution_latency_min),1),
         sum(a.sla_breach_count)::int
  from hospital_chain_quarterly_oem_engineer_audit_r3011 a
  group by a.oem_partner order by avg(a.median_resolution_latency_min) desc;
end; $$;

-- RPC 3: quarter trend
create or replace function founder_r3011_quarter_trend()
returns table(quarter_label text, audits int, avg_score numeric, avg_breaches numeric, escalated int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select a.quarter_label, count(*)::int, round(avg(a.audit_score),2),
         round(avg(a.sla_breach_count),1),
         (count(*) filter (where a.audit_status='escalated'))::int
  from hospital_chain_quarterly_oem_engineer_audit_r3011 a
  group by a.quarter_label order by a.quarter_label;
end; $$;

-- RPC 4: city breaches
create or replace function founder_r3011_city_breaches()
returns table(city text, visits int, breached int, breach_pct numeric, avg_resolution numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select v.city, count(*)::int,
         (count(*) filter (where v.sla_status='breached'))::int,
         round(100.0*(count(*) filter (where v.sla_status='breached'))::numeric/nullif(count(*),0),2),
         round(avg(v.resolution_latency_min) filter (where v.resolution_latency_min>0),1)
  from hospital_chain_quarterly_oem_engineer_audit_visits_r3011 v
  group by v.city order by (count(*) filter (where v.sla_status='breached')) desc;
end; $$;

-- RPC 5: category latency
create or replace function founder_r3011_category_latency()
returns table(equipment_category text, visits int, avg_dispatch numeric, avg_onsite numeric, avg_resolution numeric, fails int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select v.equipment_category, count(*)::int,
         round(avg(v.dispatch_latency_min) filter (where v.dispatch_latency_min>0),1),
         round(avg(v.onsite_latency_min) filter (where v.onsite_latency_min>0),1),
         round(avg(v.resolution_latency_min) filter (where v.resolution_latency_min>0),1),
         (count(*) filter (where v.pass_fail='fail'))::int
  from hospital_chain_quarterly_oem_engineer_audit_visits_r3011 v
  group by v.equipment_category order by avg(v.resolution_latency_min) desc nulls last;
end; $$;

-- RPC 6: engineer scorecard
create or replace function founder_r3011_engineer_scorecard()
returns table(engineer_assigned text, visits int, passes int, fails int, avg_resolution numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select v.engineer_assigned, count(*)::int,
         (count(*) filter (where v.pass_fail='pass'))::int,
         (count(*) filter (where v.pass_fail='fail'))::int,
         round(avg(v.resolution_latency_min) filter (where v.resolution_latency_min>0),1)
  from hospital_chain_quarterly_oem_engineer_audit_visits_r3011 v
  group by v.engineer_assigned order by (count(*) filter (where v.pass_fail='fail')) desc, count(*) desc;
end; $$;

-- RPC 7: escalations
create or replace function founder_r3011_escalations()
returns table(chain_name text, quarter_label text, oem_partner text, audit_score numeric, breaches int, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select a.chain_name, a.quarter_label, a.oem_partner, a.audit_score, a.sla_breach_count, a.audit_status
  from hospital_chain_quarterly_oem_engineer_audit_r3011 a
  where a.audit_status in ('escalated','in_progress') or a.sla_breach_count >= 20
  order by a.sla_breach_count desc;
end; $$;

revoke all on function founder_r3011_chain_summary() from public, anon;
revoke all on function founder_r3011_oem_latency() from public, anon;
revoke all on function founder_r3011_quarter_trend() from public, anon;
revoke all on function founder_r3011_city_breaches() from public, anon;
revoke all on function founder_r3011_category_latency() from public, anon;
revoke all on function founder_r3011_engineer_scorecard() from public, anon;
revoke all on function founder_r3011_escalations() from public, anon;

grant execute on function founder_r3011_chain_summary() to authenticated;
grant execute on function founder_r3011_oem_latency() to authenticated;
grant execute on function founder_r3011_quarter_trend() to authenticated;
grant execute on function founder_r3011_city_breaches() to authenticated;
grant execute on function founder_r3011_category_latency() to authenticated;
grant execute on function founder_r3011_engineer_scorecard() to authenticated;
grant execute on function founder_r3011_escalations() to authenticated;
