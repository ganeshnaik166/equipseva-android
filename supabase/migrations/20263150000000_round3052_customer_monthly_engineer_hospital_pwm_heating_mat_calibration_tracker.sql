-- Round 3052 — Customer Monthly Engineer Hospital PWM Heating-Mat Calibration Tracker

create table if not exists pwm_heating_mat_calibration_runs_r3052 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_name text not null,
  hospital_city text not null,
  engineer_name text not null,
  mat_model text not null,
  serial_no text not null,
  month_label text not null,
  run_started_at timestamptz not null,
  run_ended_at timestamptz not null,
  duty_cycle_pct numeric(5,2) not null check (duty_cycle_pct >= 0 and duty_cycle_pct <= 100),
  pwm_frequency_hz int not null check (pwm_frequency_hz between 50 and 20000),
  target_temp_c numeric(5,2) not null check (target_temp_c between 25 and 60),
  measured_temp_c numeric(5,2) not null check (measured_temp_c between 0 and 80),
  temp_drift_c numeric(5,2) not null,
  ripple_mv int not null check (ripple_mv >= 0),
  calibration_result text not null check (calibration_result in ('pass','marginal','fail','retry_required')),
  severity text not null check (severity in ('ok','watch','warn','critical')),
  customer_signed boolean not null default false,
  rerun_required boolean not null default false
);

create table if not exists pwm_heating_mat_calibration_actions_r3052 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  run_id uuid references pwm_heating_mat_calibration_runs_r3052(id) on delete cascade,
  action_kind text not null check (action_kind in ('recalibrate','firmware_flash','element_swap','sensor_swap','customer_notify','rma_request','training_flag')),
  performed_by text not null,
  performed_at timestamptz not null,
  outcome text not null check (outcome in ('resolved','partial','failed','pending')),
  notes text,
  followup_days int check (followup_days >= 0 and followup_days <= 365)
);

alter table pwm_heating_mat_calibration_runs_r3052 enable row level security;
alter table pwm_heating_mat_calibration_actions_r3052 enable row level security;

drop policy if exists pwm_runs_founder_r on pwm_heating_mat_calibration_runs_r3052;
create policy pwm_runs_founder_r on pwm_heating_mat_calibration_runs_r3052 for select to authenticated using (is_founder());
drop policy if exists pwm_actions_founder_r on pwm_heating_mat_calibration_actions_r3052;
create policy pwm_actions_founder_r on pwm_heating_mat_calibration_actions_r3052 for select to authenticated using (is_founder());

insert into pwm_heating_mat_calibration_runs_r3052
(hospital_name, hospital_city, engineer_name, mat_model, serial_no, month_label, run_started_at, run_ended_at, duty_cycle_pct, pwm_frequency_hz, target_temp_c, measured_temp_c, temp_drift_c, ripple_mv, calibration_result, severity, customer_signed, rerun_required)
values
('Apollo Jubilee','Hyderabad','Ravi K','WarmCare X1','WC-X1-00121','2026-06','2026-06-02 09:10:00+05:30'::timestamptz,'2026-06-02 09:55:00+05:30'::timestamptz,42.5,1000,37.0,36.8,-0.2,18,'pass','ok',true,false),
('Yashoda Secunderabad','Hyderabad','Ravi K','WarmCare X1','WC-X1-00122','2026-06','2026-06-03 10:00:00+05:30'::timestamptz,'2026-06-03 10:48:00+05:30'::timestamptz,55.0,1200,37.0,37.4,0.4,22,'pass','watch',true,false),
('Continental','Hyderabad','Pooja S','ThermoMat Pro','TM-P-00081','2026-06','2026-06-04 11:30:00+05:30'::timestamptz,'2026-06-04 12:20:00+05:30'::timestamptz,68.0,1500,38.0,39.2,1.2,41,'marginal','warn',true,true),
('KIMS Kondapur','Hyderabad','Aditi N','WarmCare X1','WC-X1-00135','2026-06','2026-06-05 09:00:00+05:30'::timestamptz,'2026-06-05 09:50:00+05:30'::timestamptz,38.0,1000,36.5,36.4,-0.1,15,'pass','ok',true,false),
('Care Banjara','Hyderabad','Aditi N','ThermoMat Pro','TM-P-00099','2026-06','2026-06-06 14:00:00+05:30'::timestamptz,'2026-06-06 14:55:00+05:30'::timestamptz,72.0,1500,38.0,40.1,2.1,58,'fail','critical',false,true),
('Manipal Tadepalli','Vijayawada','Sandeep R','HeatSafe 200','HS-200-00044','2026-06','2026-06-07 10:15:00+05:30'::timestamptz,'2026-06-07 11:05:00+05:30'::timestamptz,48.0,800,37.0,37.1,0.1,19,'pass','ok',true,false),
('Aster Medcity','Kochi','Lekha V','WarmCare X1','WC-X1-00210','2026-06','2026-06-08 08:30:00+05:30'::timestamptz,'2026-06-08 09:18:00+05:30'::timestamptz,52.0,1000,37.5,37.6,0.1,17,'pass','ok',true,false),
('Fortis BG Road','Bangalore','Naveen P','ThermoMat Pro','TM-P-00121','2026-06','2026-06-09 12:00:00+05:30'::timestamptz,'2026-06-09 12:50:00+05:30'::timestamptz,61.0,1200,37.5,38.6,1.1,38,'marginal','warn',true,true),
('Narayana Hrudayalaya','Bangalore','Naveen P','HeatSafe 200','HS-200-00071','2026-06','2026-06-10 13:00:00+05:30'::timestamptz,'2026-06-10 13:45:00+05:30'::timestamptz,44.0,800,36.0,35.9,-0.1,14,'pass','ok',true,false),
('Hinduja Mahim','Mumbai','Farhan Q','WarmCare X1','WC-X1-00301','2026-06','2026-06-11 09:45:00+05:30'::timestamptz,'2026-06-11 10:35:00+05:30'::timestamptz,49.5,1000,37.0,37.2,0.2,21,'pass','ok',true,false),
('Kokilaben','Mumbai','Farhan Q','ThermoMat Pro','TM-P-00188','2026-06','2026-06-12 11:00:00+05:30'::timestamptz,'2026-06-12 11:55:00+05:30'::timestamptz,75.0,1500,38.5,41.0,2.5,66,'fail','critical',false,true),
('Lilavati','Mumbai','Farhan Q','HeatSafe 200','HS-200-00102','2026-06','2026-06-13 14:30:00+05:30'::timestamptz,'2026-06-13 15:25:00+05:30'::timestamptz,46.0,800,36.5,36.7,0.2,16,'pass','ok',true,false),
('AIIMS Delhi','Delhi','Ishita G','WarmCare X1','WC-X1-00404','2026-06','2026-06-14 09:00:00+05:30'::timestamptz,'2026-06-14 09:48:00+05:30'::timestamptz,53.0,1000,37.0,37.0,0.0,12,'pass','ok',true,false),
('Max Saket','Delhi','Ishita G','ThermoMat Pro','TM-P-00220','2026-06','2026-06-15 10:30:00+05:30'::timestamptz,'2026-06-15 11:25:00+05:30'::timestamptz,64.0,1200,38.0,39.1,1.1,36,'marginal','warn',true,true),
('Medanta Gurugram','Gurugram','Ishita G','HeatSafe 200','HS-200-00141','2026-06','2026-06-16 12:00:00+05:30'::timestamptz,'2026-06-16 12:55:00+05:30'::timestamptz,41.0,800,36.0,36.1,0.1,15,'pass','ok',true,false),
('Tata Memorial','Mumbai','Farhan Q','WarmCare X1','WC-X1-00410','2026-06','2026-06-17 09:15:00+05:30'::timestamptz,'2026-06-17 10:05:00+05:30'::timestamptz,58.0,1000,37.5,37.8,0.3,24,'pass','watch',true,false),
('CMC Vellore','Vellore','Suresh T','ThermoMat Pro','TM-P-00250','2026-06','2026-06-18 11:00:00+05:30'::timestamptz,'2026-06-18 11:50:00+05:30'::timestamptz,69.0,1500,38.0,40.3,2.3,61,'fail','critical',false,true),
('PGIMER Chandigarh','Chandigarh','Manpreet K','HeatSafe 200','HS-200-00170','2026-06','2026-06-19 08:30:00+05:30'::timestamptz,'2026-06-19 09:20:00+05:30'::timestamptz,45.0,800,36.5,36.5,0.0,13,'pass','ok',true,false),
('SGPGI Lucknow','Lucknow','Anirudh M','WarmCare X1','WC-X1-00501','2026-06','2026-06-20 10:00:00+05:30'::timestamptz,'2026-06-20 10:50:00+05:30'::timestamptz,50.0,1000,37.0,37.1,0.1,18,'pass','ok',true,false),
('Ruby Hall Pune','Pune','Karthik J','ThermoMat Pro','TM-P-00301','2026-06','2026-06-21 11:30:00+05:30'::timestamptz,'2026-06-21 12:25:00+05:30'::timestamptz,66.0,1200,38.0,39.4,1.4,44,'marginal','warn',true,true);

with r as (select id, calibration_result, severity, hospital_name from pwm_heating_mat_calibration_runs_r3052)
insert into pwm_heating_mat_calibration_actions_r3052
(run_id, action_kind, performed_by, performed_at, outcome, notes, followup_days)
select id,'recalibrate','Ravi K','2026-06-02 10:00:00+05:30'::timestamptz,'resolved','Within tolerance after second pass',30 from r where hospital_name='Apollo Jubilee'
union all
select id,'customer_notify','Pooja S','2026-06-04 12:30:00+05:30'::timestamptz,'partial','Customer notified of marginal drift; rerun scheduled',7 from r where hospital_name='Continental'
union all
select id,'firmware_flash','Aditi N','2026-06-06 15:00:00+05:30'::timestamptz,'failed','Firmware v2.1 did not lower drift; element swap queued',3 from r where hospital_name='Care Banjara'
union all
select id,'element_swap','Aditi N','2026-06-09 10:00:00+05:30'::timestamptz,'pending','RMA element en route to site',5 from r where hospital_name='Care Banjara'
union all
select id,'recalibrate','Naveen P','2026-06-09 13:00:00+05:30'::timestamptz,'resolved','Pass on second attempt with frequency bump to 1400Hz',30 from r where hospital_name='Fortis BG Road'
union all
select id,'sensor_swap','Farhan Q','2026-06-12 12:30:00+05:30'::timestamptz,'resolved','Probe drift traced to faulty NTC; replaced and re-verified',14 from r where hospital_name='Kokilaben'
union all
select id,'rma_request','Farhan Q','2026-06-12 13:00:00+05:30'::timestamptz,'pending','RMA opened with WarmCare for unit WC-X1-00301',10 from r where hospital_name='Hinduja Mahim'
union all
select id,'training_flag','Ishita G','2026-06-15 12:00:00+05:30'::timestamptz,'partial','Engineer needs refresher on PWM duty-cycle calc',21 from r where hospital_name='Max Saket'
union all
select id,'customer_notify','Suresh T','2026-06-18 12:30:00+05:30'::timestamptz,'failed','Customer rejected unit; escalation to RMA',2 from r where hospital_name='CMC Vellore'
union all
select id,'rma_request','Suresh T','2026-06-18 13:00:00+05:30'::timestamptz,'pending','Full unit return to vendor',7 from r where hospital_name='CMC Vellore'
union all
select id,'recalibrate','Karthik J','2026-06-21 13:00:00+05:30'::timestamptz,'partial','Marginal pass — scheduled re-verify in 7d',7 from r where hospital_name='Ruby Hall Pune'
union all
select id,'training_flag','Naveen P','2026-06-09 14:00:00+05:30'::timestamptz,'resolved','Flagged for tier-2 PWM diagnostic module',30 from r where hospital_name='Fortis BG Road'
union all
select id,'recalibrate','Ravi K','2026-06-03 11:00:00+05:30'::timestamptz,'resolved','Watch-tier within tolerance; logged for trend',30 from r where hospital_name='Yashoda Secunderabad'
union all
select id,'customer_notify','Farhan Q','2026-06-17 10:30:00+05:30'::timestamptz,'resolved','Customer informed of watch status',14 from r where hospital_name='Tata Memorial';

create or replace function rpc_r3052_monthly_overview()
returns table(month_label text, total_runs int, passes int, marginals int, fails int, avg_drift numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select r.month_label,
    count(*)::int,
    (count(*) filter (where r.calibration_result='pass'))::int,
    (count(*) filter (where r.calibration_result='marginal'))::int,
    (count(*) filter (where r.calibration_result='fail'))::int,
    round(avg(r.temp_drift_c)::numeric,2)
  from pwm_heating_mat_calibration_runs_r3052 r
  group by r.month_label
  order by r.month_label desc;
end $$;

create or replace function rpc_r3052_engineer_scorecard()
returns table(engineer_name text, runs int, passes int, fails int, avg_drift numeric, critical_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select r.engineer_name,
    count(*)::int,
    (count(*) filter (where r.calibration_result='pass'))::int,
    (count(*) filter (where r.calibration_result='fail'))::int,
    round(avg(r.temp_drift_c)::numeric,2),
    (count(*) filter (where r.severity='critical'))::int
  from pwm_heating_mat_calibration_runs_r3052 r
  group by r.engineer_name
  order by (count(*) filter (where r.severity='critical'))::int desc, r.engineer_name;
end $$;

create or replace function rpc_r3052_hospital_heatmap()
returns table(hospital_name text, hospital_city text, runs int, fails int, marginals int, worst_drift numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select r.hospital_name, r.hospital_city,
    count(*)::int,
    (count(*) filter (where r.calibration_result='fail'))::int,
    (count(*) filter (where r.calibration_result='marginal'))::int,
    max(abs(r.temp_drift_c))
  from pwm_heating_mat_calibration_runs_r3052 r
  group by r.hospital_name, r.hospital_city
  order by max(abs(r.temp_drift_c)) desc;
end $$;

create or replace function rpc_r3052_mat_model_quality()
returns table(mat_model text, runs int, fails int, fail_rate_pct numeric, avg_ripple numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select r.mat_model,
    count(*)::int,
    (count(*) filter (where r.calibration_result='fail'))::int,
    round(100.0 * (count(*) filter (where r.calibration_result='fail'))::numeric / nullif(count(*),0),2),
    round(avg(r.ripple_mv)::numeric,1)
  from pwm_heating_mat_calibration_runs_r3052 r
  group by r.mat_model
  order by round(100.0 * (count(*) filter (where r.calibration_result='fail'))::numeric / nullif(count(*),0),2) desc nulls last;
end $$;

create or replace function rpc_r3052_critical_runs()
returns table(hospital_name text, engineer_name text, mat_model text, serial_no text, measured_temp_c numeric, temp_drift_c numeric, ripple_mv int, calibration_result text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select r.hospital_name, r.engineer_name, r.mat_model, r.serial_no, r.measured_temp_c, r.temp_drift_c, r.ripple_mv, r.calibration_result
  from pwm_heating_mat_calibration_runs_r3052 r
  where r.severity in ('warn','critical')
  order by r.severity desc, abs(r.temp_drift_c) desc;
end $$;

create or replace function rpc_r3052_action_pipeline()
returns table(action_kind text, total int, resolved int, pending int, failed int, partial int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select a.action_kind,
    count(*)::int,
    (count(*) filter (where a.outcome='resolved'))::int,
    (count(*) filter (where a.outcome='pending'))::int,
    (count(*) filter (where a.outcome='failed'))::int,
    (count(*) filter (where a.outcome='partial'))::int
  from pwm_heating_mat_calibration_actions_r3052 a
  group by a.action_kind
  order by count(*) desc;
end $$;

create or replace function rpc_r3052_rerun_backlog()
returns table(hospital_name text, hospital_city text, engineer_name text, mat_model text, serial_no text, temp_drift_c numeric, severity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select r.hospital_name, r.hospital_city, r.engineer_name, r.mat_model, r.serial_no, r.temp_drift_c, r.severity
  from pwm_heating_mat_calibration_runs_r3052 r
  where r.rerun_required = true
  order by r.severity desc, abs(r.temp_drift_c) desc;
end $$;

revoke all on function rpc_r3052_monthly_overview() from public, anon;
revoke all on function rpc_r3052_engineer_scorecard() from public, anon;
revoke all on function rpc_r3052_hospital_heatmap() from public, anon;
revoke all on function rpc_r3052_mat_model_quality() from public, anon;
revoke all on function rpc_r3052_critical_runs() from public, anon;
revoke all on function rpc_r3052_action_pipeline() from public, anon;
revoke all on function rpc_r3052_rerun_backlog() from public, anon;

grant execute on function rpc_r3052_monthly_overview() to authenticated;
grant execute on function rpc_r3052_engineer_scorecard() to authenticated;
grant execute on function rpc_r3052_hospital_heatmap() to authenticated;
grant execute on function rpc_r3052_mat_model_quality() to authenticated;
grant execute on function rpc_r3052_critical_runs() to authenticated;
grant execute on function rpc_r3052_action_pipeline() to authenticated;
grant execute on function rpc_r3052_rerun_backlog() to authenticated;
