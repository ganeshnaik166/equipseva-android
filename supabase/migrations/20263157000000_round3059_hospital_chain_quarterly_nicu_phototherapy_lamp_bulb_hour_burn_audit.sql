-- Round 3059 — Hospital Chain Quarterly NICU Phototherapy Lamp Bulb-Hour Burn Audit
-- HEAVY ★★★★

create table if not exists nicu_phototherapy_lamps_r3059 (
  id uuid primary key default gen_random_uuid(),
  chain_code text not null,
  hospital_unit text not null,
  lamp_serial text not null unique,
  lamp_model text not null check (lamp_model in ('bilibed_pro','bilisoft_led','medela_blue','natus_neoblue','gigmed_360','phoenix_intensive')),
  light_source text not null check (light_source in ('led_blue','cfl_blue','halogen','fiberoptic')),
  rated_life_hours int not null check (rated_life_hours between 1000 and 50000),
  burn_hours_quarter numeric(10,2) not null check (burn_hours_quarter between 0 and 2200),
  cumulative_burn_hours numeric(12,2) not null check (cumulative_burn_hours >= 0),
  irradiance_mw_cm2_nm numeric(6,2) not null check (irradiance_mw_cm2_nm between 0 and 80),
  irradiance_threshold_mw numeric(6,2) not null check (irradiance_threshold_mw between 8 and 40),
  last_calibration_date date not null,
  next_replacement_due date,
  replacement_status text not null check (replacement_status in ('healthy','watch','due_soon','overdue','replaced','condemned')),
  ward_acuity text not null check (ward_acuity in ('level_1','level_2','level_3','level_3plus')),
  decommissioned boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists nicu_phototherapy_audit_findings_r3059 (
  id uuid primary key default gen_random_uuid(),
  lamp_id uuid not null references nicu_phototherapy_lamps_r3059(id) on delete cascade,
  audit_quarter text not null check (audit_quarter in ('q1_2026','q2_2026','q3_2026','q4_2026')),
  finding_severity text not null check (finding_severity in ('info','minor','major','critical')),
  finding_category text not null check (finding_category in ('over_burn','under_irradiance','missed_calibration','documentation_gap','infection_risk','electrical_fault')),
  babies_exposed int not null check (babies_exposed between 0 and 400),
  remediation_cost_rupees int not null check (remediation_cost_rupees between 0 and 500000),
  remediation_status text not null check (remediation_status in ('open','in_progress','closed','escalated')),
  flagged_at timestamptz not null default now(),
  closed_at timestamptz,
  auditor_note text,
  created_at timestamptz not null default now()
);

alter table nicu_phototherapy_lamps_r3059 enable row level security;
alter table nicu_phototherapy_audit_findings_r3059 enable row level security;

drop policy if exists nicu_lamps_r3059_founder_all on nicu_phototherapy_lamps_r3059;
create policy nicu_lamps_r3059_founder_all on nicu_phototherapy_lamps_r3059 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists nicu_findings_r3059_founder_all on nicu_phototherapy_audit_findings_r3059;
create policy nicu_findings_r3059_founder_all on nicu_phototherapy_audit_findings_r3059 for all to authenticated using (is_founder()) with check (is_founder());

-- Seed lamps (18 rows)
insert into nicu_phototherapy_lamps_r3059 (chain_code, hospital_unit, lamp_serial, lamp_model, light_source, rated_life_hours, burn_hours_quarter, cumulative_burn_hours, irradiance_mw_cm2_nm, irradiance_threshold_mw, last_calibration_date, next_replacement_due, replacement_status, ward_acuity, decommissioned, notes) values
('apollo','apollo_hyd_jubilee','PT-AHJ-001','bilisoft_led','led_blue',20000,1820.50,18450.00,28.40,30.00,'2026-04-10'::date,'2026-09-15'::date,'due_soon','level_3',false,'led bank 2 dim'),
('apollo','apollo_chn_greams','PT-ACG-002','natus_neoblue','led_blue',20000,2100.00,19800.50,22.10,30.00,'2026-03-22'::date,'2026-07-05'::date,'overdue','level_3plus',false,'replacement parts in transit'),
('manipal','manipal_blr_old','PT-MBO-003','bilibed_pro','cfl_blue',8000,1450.75,7820.25,18.50,25.00,'2026-05-01'::date,'2026-08-10'::date,'due_soon','level_2',false,null),
('manipal','manipal_blr_whitefield','PT-MBW-004','phoenix_intensive','led_blue',25000,1980.00,12400.00,42.30,30.00,'2026-05-15'::date,'2027-02-28'::date,'healthy','level_3plus',false,'newer unit'),
('fortis','fortis_mlsr','PT-FMR-005','gigmed_360','halogen',5000,1700.25,4920.00,12.20,20.00,'2026-02-18'::date,'2026-06-30'::date,'overdue','level_2',false,'halogen bulb yellowing'),
('fortis','fortis_noida','PT-FNO-006','medela_blue','fiberoptic',15000,1200.00,9800.50,26.00,25.00,'2026-04-28'::date,'2026-11-12'::date,'watch','level_3',false,null),
('rainbow','rainbow_hyd_banjara','PT-RHB-007','natus_neoblue','led_blue',20000,2050.50,16720.00,31.50,30.00,'2026-05-20'::date,'2026-10-08'::date,'watch','level_3plus',false,'high traffic'),
('rainbow','rainbow_blr_marathahalli','PT-RBM-008','bilisoft_led','led_blue',20000,1100.00,3200.00,38.40,30.00,'2026-06-01'::date,'2027-08-30'::date,'healthy','level_3',false,null),
('cloudnine','cloudnine_blr_hrbr','PT-CBH-009','bilibed_pro','cfl_blue',8000,890.25,8120.00,15.00,25.00,'2026-01-15'::date,'2026-05-01'::date,'overdue','level_2',false,'past life'),
('cloudnine','cloudnine_mum_malad','PT-CMM-010','phoenix_intensive','led_blue',25000,1560.00,7800.00,44.20,30.00,'2026-05-30'::date,'2027-12-15'::date,'healthy','level_3',false,null),
('motherhood','motherhood_pun_khar','PT-MPK-011','gigmed_360','halogen',5000,1950.50,5100.50,9.80,20.00,'2026-03-05'::date,'2026-05-20'::date,'overdue','level_2',false,'condemnation pending'),
('motherhood','motherhood_chn_alwarpet','PT-MCA-012','medela_blue','fiberoptic',15000,1340.00,14600.00,21.30,25.00,'2026-04-12'::date,'2026-07-25'::date,'due_soon','level_3',false,null),
('aster','aster_kochi','PT-AKO-013','bilisoft_led','led_blue',20000,1680.00,11200.00,33.60,30.00,'2026-05-08'::date,'2027-04-18'::date,'healthy','level_3plus',false,null),
('aster','aster_blr_cunningham','PT-ABC-014','natus_neoblue','led_blue',20000,2150.75,21300.00,18.90,30.00,'2026-02-28'::date,'2026-04-15'::date,'overdue','level_3plus',false,'over rated life'),
('kims','kims_secunderabad','PT-KSE-015','phoenix_intensive','led_blue',25000,1820.00,9450.00,40.10,30.00,'2026-05-22'::date,'2028-01-10'::date,'healthy','level_3',false,null),
('kims','kims_nellore','PT-KNE-016','bilibed_pro','cfl_blue',8000,1240.50,7980.00,16.40,25.00,'2026-04-02'::date,'2026-06-22'::date,'overdue','level_2',false,'cfl flicker'),
('narayana','narayana_blr_health','PT-NBH-017','medela_blue','fiberoptic',15000,1480.00,15400.00,19.70,25.00,'2026-03-18'::date,null,'replaced','level_3',true,'replaced 2026-06-10'),
('narayana','narayana_jaipur','PT-NJA-018','gigmed_360','halogen',5000,0.00,5050.00,0.00,20.00,'2026-01-30'::date,null,'condemned','level_2',true,'unit condemned 2026-05-05');

-- Seed findings (24 rows)
with l as (select id, lamp_serial from nicu_phototherapy_lamps_r3059)
insert into nicu_phototherapy_audit_findings_r3059 (lamp_id, audit_quarter, finding_severity, finding_category, babies_exposed, remediation_cost_rupees, remediation_status, flagged_at, closed_at, auditor_note)
select id, 'q2_2026', 'major', 'over_burn', 42, 18000, 'in_progress', now() - interval '12 days', null::timestamptz, 'projected over-life by q3' from l where lamp_serial='PT-AHJ-001' union all
select id, 'q2_2026', 'critical', 'over_burn', 71, 42000, 'escalated', now() - interval '20 days', null, 'cumulative 19800 > 20000 rated' from l where lamp_serial='PT-ACG-002' union all
select id, 'q2_2026', 'major', 'under_irradiance', 38, 22000, 'in_progress', now() - interval '8 days', null, 'cfl below 25mw threshold' from l where lamp_serial='PT-MBO-003' union all
select id, 'q1_2026', 'minor', 'documentation_gap', 0, 1500, 'closed', now() - interval '90 days', now() - interval '70 days', 'log book missing q4_2025' from l where lamp_serial='PT-MBW-004' union all
select id, 'q2_2026', 'critical', 'under_irradiance', 55, 35000, 'escalated', now() - interval '25 days', null, 'halogen yellowing; replace bulb' from l where lamp_serial='PT-FMR-005' union all
select id, 'q2_2026', 'info', 'documentation_gap', 0, 0, 'closed', now() - interval '40 days', now() - interval '30 days', 'minor log entry typo' from l where lamp_serial='PT-FNO-006' union all
select id, 'q2_2026', 'major', 'over_burn', 60, 26000, 'open', now() - interval '5 days', null, 'high traffic ward; trending over' from l where lamp_serial='PT-RHB-007' union all
select id, 'q2_2026', 'info', 'missed_calibration', 0, 800, 'closed', now() - interval '15 days', now() - interval '7 days', 'recalibrated next-day' from l where lamp_serial='PT-RBM-008' union all
select id, 'q1_2026', 'critical', 'over_burn', 88, 48000, 'escalated', now() - interval '110 days', null, 'cumulative past rated life cfl' from l where lamp_serial='PT-CBH-009' union all
select id, 'q2_2026', 'minor', 'electrical_fault', 4, 6500, 'in_progress', now() - interval '6 days', null, 'ballast hum reported' from l where lamp_serial='PT-CMM-010' union all
select id, 'q2_2026', 'critical', 'under_irradiance', 33, 38000, 'escalated', now() - interval '35 days', null, 'halogen 9.8mw -- below 20 threshold' from l where lamp_serial='PT-MPK-011' union all
select id, 'q2_2026', 'major', 'missed_calibration', 12, 3500, 'in_progress', now() - interval '14 days', null, 'calibration overdue by 30 days' from l where lamp_serial='PT-MCA-012' union all
select id, 'q1_2026', 'minor', 'documentation_gap', 0, 1200, 'closed', now() - interval '95 days', now() - interval '85 days', 'minor calib note missing' from l where lamp_serial='PT-AKO-013' union all
select id, 'q2_2026', 'critical', 'over_burn', 102, 55000, 'escalated', now() - interval '45 days', null, 'cumulative 21300 hours -- decommission' from l where lamp_serial='PT-ABC-014' union all
select id, 'q2_2026', 'info', 'documentation_gap', 0, 500, 'closed', now() - interval '20 days', now() - interval '15 days', 'auditor note updated' from l where lamp_serial='PT-KSE-015' union all
select id, 'q2_2026', 'major', 'over_burn', 29, 16500, 'in_progress', now() - interval '11 days', null, 'cfl pulled for replacement' from l where lamp_serial='PT-KNE-016' union all
select id, 'q1_2026', 'critical', 'infection_risk', 18, 32000, 'closed', now() - interval '100 days', now() - interval '60 days', 'biofilm on lamp head; cleaned + replaced' from l where lamp_serial='PT-NBH-017' union all
select id, 'q1_2026', 'critical', 'electrical_fault', 6, 45000, 'closed', now() - interval '120 days', now() - interval '90 days', 'capacitor blew; condemned unit' from l where lamp_serial='PT-NJA-018' union all
select id, 'q2_2026', 'minor', 'documentation_gap', 0, 900, 'open', now() - interval '3 days', null, 'q2 mid-quarter readings missing' from l where lamp_serial='PT-AHJ-001' union all
select id, 'q2_2026', 'major', 'missed_calibration', 14, 4200, 'open', now() - interval '7 days', null, 'calib slipped to next month' from l where lamp_serial='PT-RHB-007' union all
select id, 'q2_2026', 'minor', 'infection_risk', 3, 8000, 'in_progress', now() - interval '4 days', null, 'lamp shroud not wiped per protocol' from l where lamp_serial='PT-CMM-010' union all
select id, 'q2_2026', 'major', 'electrical_fault', 9, 14500, 'in_progress', now() - interval '9 days', null, 'flicker reported by nurses' from l where lamp_serial='PT-KNE-016' union all
select id, 'q2_2026', 'info', 'documentation_gap', 0, 0, 'closed', now() - interval '17 days', now() - interval '12 days', 'log book clarification only' from l where lamp_serial='PT-AKO-013' union all
select id, 'q2_2026', 'major', 'under_irradiance', 21, 19500, 'open', now() - interval '6 days', null, 'irradiance 18.9 vs threshold 30 -- escalate' from l where lamp_serial='PT-ABC-014';

-- RPC 1: chain rollup
create or replace function founder_r3059_chain_rollup()
returns table (chain_code text, lamps int, overdue int, due_soon int, avg_burn_hours numeric, avg_irradiance numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.chain_code,
         count(*)::int,
         (count(*) filter (where l.replacement_status='overdue'))::int,
         (count(*) filter (where l.replacement_status='due_soon'))::int,
         round(avg(l.burn_hours_quarter)::numeric, 2),
         round(avg(l.irradiance_mw_cm2_nm)::numeric, 2)
  from nicu_phototherapy_lamps_r3059 l
  where l.decommissioned = false
  group by l.chain_code
  order by (count(*) filter (where l.replacement_status='overdue')) desc;
end;
$$;

-- RPC 2: lamps over rated life
create or replace function founder_r3059_lamps_over_rated_life()
returns table (chain_code text, hospital_unit text, lamp_serial text, lamp_model text, cumulative_burn_hours numeric, rated_life_hours int, pct_of_rated numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.chain_code, l.hospital_unit, l.lamp_serial, l.lamp_model, l.cumulative_burn_hours, l.rated_life_hours,
         round((l.cumulative_burn_hours / nullif(l.rated_life_hours,0) * 100)::numeric, 1)
  from nicu_phototherapy_lamps_r3059 l
  where l.cumulative_burn_hours >= (l.rated_life_hours * 0.85)
    and l.decommissioned = false
  order by (l.cumulative_burn_hours / nullif(l.rated_life_hours,0)) desc;
end;
$$;

-- RPC 3: under-irradiance lamps
create or replace function founder_r3059_under_irradiance_lamps()
returns table (chain_code text, hospital_unit text, lamp_serial text, irradiance_mw_cm2_nm numeric, irradiance_threshold_mw numeric, gap_mw numeric, ward_acuity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.chain_code, l.hospital_unit, l.lamp_serial, l.irradiance_mw_cm2_nm, l.irradiance_threshold_mw,
         round((l.irradiance_threshold_mw - l.irradiance_mw_cm2_nm)::numeric, 2),
         l.ward_acuity
  from nicu_phototherapy_lamps_r3059 l
  where l.irradiance_mw_cm2_nm < l.irradiance_threshold_mw
    and l.decommissioned = false
  order by (l.irradiance_threshold_mw - l.irradiance_mw_cm2_nm) desc;
end;
$$;

-- RPC 4: critical open findings
create or replace function founder_r3059_critical_open_findings()
returns table (lamp_serial text, chain_code text, finding_category text, babies_exposed int, remediation_cost_rupees int, remediation_status text, auditor_note text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.lamp_serial, l.chain_code, f.finding_category, f.babies_exposed, f.remediation_cost_rupees, f.remediation_status, f.auditor_note
  from nicu_phototherapy_audit_findings_r3059 f
  join nicu_phototherapy_lamps_r3059 l on l.id = f.lamp_id
  where f.finding_severity = 'critical'
    and f.remediation_status in ('open','in_progress','escalated')
  order by f.babies_exposed desc;
end;
$$;

-- RPC 5: finding category mix
create or replace function founder_r3059_finding_category_mix()
returns table (finding_category text, total int, open_count int, closed_count int, total_remediation_rupees int, babies_exposed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select f.finding_category,
         count(*)::int,
         (count(*) filter (where f.remediation_status in ('open','in_progress','escalated')))::int,
         (count(*) filter (where f.remediation_status = 'closed'))::int,
         coalesce(sum(f.remediation_cost_rupees),0)::int,
         coalesce(sum(f.babies_exposed),0)::int
  from nicu_phototherapy_audit_findings_r3059 f
  group by f.finding_category
  order by count(*) desc;
end;
$$;

-- RPC 6: calibration overdue
create or replace function founder_r3059_calibration_overdue()
returns table (chain_code text, hospital_unit text, lamp_serial text, last_calibration_date date, days_since_calibration int, ward_acuity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.chain_code, l.hospital_unit, l.lamp_serial, l.last_calibration_date,
         (current_date - l.last_calibration_date)::int,
         l.ward_acuity
  from nicu_phototherapy_lamps_r3059 l
  where (current_date - l.last_calibration_date) > 90
    and l.decommissioned = false
  order by (current_date - l.last_calibration_date) desc;
end;
$$;

-- RPC 7: quarter burn pace
create or replace function founder_r3059_quarter_burn_pace()
returns table (chain_code text, lamps int, total_quarter_burn_hours numeric, projected_annualised numeric, projected_replacement_risk text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.chain_code,
         count(*)::int,
         round(sum(l.burn_hours_quarter)::numeric, 2),
         round((sum(l.burn_hours_quarter) * 4)::numeric, 2),
         case
           when avg(l.burn_hours_quarter) > 1900 then 'high'
           when avg(l.burn_hours_quarter) > 1500 then 'medium'
           else 'low'
         end
  from nicu_phototherapy_lamps_r3059 l
  where l.decommissioned = false
  group by l.chain_code
  order by sum(l.burn_hours_quarter) desc;
end;
$$;

-- RPC 8: replacement status spread
create or replace function founder_r3059_replacement_status_spread()
returns table (replacement_status text, lamps int, avg_cumulative_burn numeric, total_babies_at_risk int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.replacement_status,
         count(*)::int,
         round(avg(l.cumulative_burn_hours)::numeric, 2),
         coalesce((select sum(f.babies_exposed)::int
                   from nicu_phototherapy_audit_findings_r3059 f
                   where f.lamp_id in (select l2.id from nicu_phototherapy_lamps_r3059 l2 where l2.replacement_status = l.replacement_status)
                     and f.remediation_status in ('open','in_progress','escalated')), 0)
  from nicu_phototherapy_lamps_r3059 l
  group by l.replacement_status
  order by count(*) desc;
end;
$$;

revoke all on nicu_phototherapy_lamps_r3059 from public, anon;
revoke all on nicu_phototherapy_audit_findings_r3059 from public, anon;
grant select, insert, update, delete on nicu_phototherapy_lamps_r3059 to authenticated;
grant select, insert, update, delete on nicu_phototherapy_audit_findings_r3059 to authenticated;

revoke all on function founder_r3059_chain_rollup() from public, anon;
revoke all on function founder_r3059_lamps_over_rated_life() from public, anon;
revoke all on function founder_r3059_under_irradiance_lamps() from public, anon;
revoke all on function founder_r3059_critical_open_findings() from public, anon;
revoke all on function founder_r3059_finding_category_mix() from public, anon;
revoke all on function founder_r3059_calibration_overdue() from public, anon;
revoke all on function founder_r3059_quarter_burn_pace() from public, anon;
revoke all on function founder_r3059_replacement_status_spread() from public, anon;

grant execute on function founder_r3059_chain_rollup() to authenticated;
grant execute on function founder_r3059_lamps_over_rated_life() to authenticated;
grant execute on function founder_r3059_under_irradiance_lamps() to authenticated;
grant execute on function founder_r3059_critical_open_findings() to authenticated;
grant execute on function founder_r3059_finding_category_mix() to authenticated;
grant execute on function founder_r3059_calibration_overdue() to authenticated;
grant execute on function founder_r3059_quarter_burn_pace() to authenticated;
grant execute on function founder_r3059_replacement_status_spread() to authenticated;
