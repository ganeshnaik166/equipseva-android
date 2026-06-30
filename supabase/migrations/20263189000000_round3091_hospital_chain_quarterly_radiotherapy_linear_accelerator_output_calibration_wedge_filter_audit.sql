-- Round r3091 — Hospital Chain Quarterly Radiotherapy Linear Accelerator
-- Output Calibration & Wedge Filter Audit

create table if not exists radiotherapy_linac_calibrations_r3091 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid references organizations(id) on delete set null,
  hospital_name text not null,
  chain_code text not null,
  linac_serial text not null,
  linac_vendor text not null check (linac_vendor in ('varian','elekta','siemens','accuray','bhabhatron')),
  energy_mode text not null check (energy_mode in ('6mv','10mv','15mv','6mv_fff','10mv_fff','6mev','9mev','12mev','15mev','18mev')),
  calibration_quarter text not null check (calibration_quarter in ('q1_2026','q2_2026','q3_2026','q4_2026')),
  calibration_date date not null,
  expected_output_cgy_per_mu numeric(7,3) not null,
  measured_output_cgy_per_mu numeric(7,3) not null,
  deviation_pct numeric(6,3) not null,
  tolerance_pct numeric(5,2) not null default 2.00,
  outcome text not null check (outcome in ('within_tolerance','warning','out_of_tolerance','recalibration_required')),
  aerb_compliant boolean not null default true,
  rso_user_id uuid references profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

alter table radiotherapy_linac_calibrations_r3091 enable row level security;
drop policy if exists r3091_calib_founder_select on radiotherapy_linac_calibrations_r3091;
create policy r3091_calib_founder_select on radiotherapy_linac_calibrations_r3091 for select to authenticated using (is_founder());

create table if not exists radiotherapy_wedge_filter_audits_r3091 (
  id uuid primary key default gen_random_uuid(),
  calibration_id uuid references radiotherapy_linac_calibrations_r3091(id) on delete set null,
  hospital_name text not null,
  wedge_type text not null check (wedge_type in ('physical_15','physical_30','physical_45','physical_60','dynamic_edw','virtual','motorized')),
  wedge_angle_deg int not null,
  expected_factor numeric(6,4) not null,
  measured_factor numeric(6,4) not null,
  factor_deviation_pct numeric(6,3) not null,
  symmetry_pct numeric(6,3),
  flatness_pct numeric(6,3),
  audit_status text not null check (audit_status in ('pass','marginal','fail','equipment_fault')),
  corrective_action text check (corrective_action in ('none','recalibrate','replace_wedge','vendor_service','quarantine')),
  audited_at timestamptz not null,
  qa_engineer_id uuid references engineers(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table radiotherapy_wedge_filter_audits_r3091 enable row level security;
drop policy if exists r3091_wedge_founder_select on radiotherapy_wedge_filter_audits_r3091;
create policy r3091_wedge_founder_select on radiotherapy_wedge_filter_audits_r3091 for select to authenticated using (is_founder());

-- Seeds: 18 calibrations
insert into radiotherapy_linac_calibrations_r3091
  (hospital_name, chain_code, linac_serial, linac_vendor, energy_mode, calibration_quarter, calibration_date, expected_output_cgy_per_mu, measured_output_cgy_per_mu, deviation_pct, tolerance_pct, outcome, aerb_compliant, notes)
values
  ('Apollo Jubilee Hills','APOLLO','VAR-TB-9921','varian','6mv','q2_2026','2026-04-08'::date,1.000,1.004,0.400,2.00,'within_tolerance',true,'TG-51 protocol'),
  ('Apollo Jubilee Hills','APOLLO','VAR-TB-9921','varian','10mv','q2_2026','2026-04-08'::date,1.000,1.012,1.200,2.00,'within_tolerance',true,'10MV nominal'),
  ('Apollo Bannerghatta','APOLLO','VAR-CL-7812','varian','6mv_fff','q2_2026','2026-04-12'::date,1.400,1.378,-1.571,2.00,'within_tolerance',true,'FFF mode'),
  ('Manipal Hebbal','MANIPAL','ELE-VS-3344','elekta','6mv','q2_2026','2026-04-15'::date,1.000,1.025,2.500,2.00,'out_of_tolerance',false,'Drift since Q1'),
  ('Manipal Old Airport','MANIPAL','ELE-IF-5566','elekta','10mv','q2_2026','2026-04-16'::date,1.000,0.978,-2.200,2.00,'out_of_tolerance',false,'Magnetron suspect'),
  ('Fortis Mulund','FORTIS','SIE-AR-2211','siemens','15mv','q2_2026','2026-04-20'::date,1.000,1.018,1.800,2.00,'warning',true,'Near tolerance'),
  ('Fortis Shalimar Bagh','FORTIS','SIE-AR-2299','siemens','6mv','q2_2026','2026-04-21'::date,1.000,1.003,0.300,2.00,'within_tolerance',true,'Routine'),
  ('Tata Memorial Mumbai','TMC','VAR-ED-1100','varian','6mv','q2_2026','2026-04-25'::date,1.000,1.001,0.100,2.00,'within_tolerance',true,'Reference standard'),
  ('Tata Memorial Mumbai','TMC','VAR-ED-1100','varian','9mev','q2_2026','2026-04-25'::date,1.000,1.015,1.500,2.00,'within_tolerance',true,'Electron mode'),
  ('AIIMS Delhi NCI','AIIMS','ACC-CK-0042','accuray','6mv_fff','q2_2026','2026-04-28'::date,1.400,1.435,2.500,2.00,'out_of_tolerance',false,'CyberKnife drift'),
  ('AIIMS Delhi NCI','AIIMS','VAR-HA-8800','varian','10mv_fff','q2_2026','2026-04-29'::date,1.667,1.701,2.040,2.00,'out_of_tolerance',false,'HalcyonA recall flag'),
  ('Rajiv Gandhi Cancer Delhi','RGCIRC','ELE-SY-4422','elekta','15mv','q2_2026','2026-05-02'::date,1.000,0.992,-0.800,2.00,'within_tolerance',true,'Synergy'),
  ('Kidwai Memorial Bangalore','KIDWAI','BHA-25-0017','bhabhatron','6mev','q2_2026','2026-05-05'::date,1.000,1.022,2.200,2.00,'out_of_tolerance',false,'BARC unit aging'),
  ('Tata Memorial Varanasi','TMC','VAR-TB-9933','varian','6mv','q2_2026','2026-05-08'::date,1.000,1.005,0.500,2.00,'within_tolerance',true,'TrueBeam'),
  ('HCG Bangalore','HCG','ELE-VR-7755','elekta','6mv','q2_2026','2026-05-10'::date,1.000,1.019,1.900,2.00,'warning',true,'Versa HD'),
  ('HCG Ahmedabad','HCG','VAR-CL-3399','varian','12mev','q2_2026','2026-05-12'::date,1.000,1.034,3.400,2.00,'recalibration_required',false,'Schedule physicist visit'),
  ('Yashoda Hyderabad','YASHODA','VAR-TB-2266','varian','6mv','q2_2026','2026-05-14'::date,1.000,1.007,0.700,2.00,'within_tolerance',true,'Stable'),
  ('Continental Hyderabad','CONTINENTAL','ELE-IF-9911','elekta','15mev','q2_2026','2026-05-16'::date,1.000,1.041,4.100,2.00,'recalibration_required',false,'Major deviation - halt clinical use');

-- Seeds: 22 wedge audits
insert into radiotherapy_wedge_filter_audits_r3091
  (hospital_name, wedge_type, wedge_angle_deg, expected_factor, measured_factor, factor_deviation_pct, symmetry_pct, flatness_pct, audit_status, corrective_action, audited_at)
values
  ('Apollo Jubilee Hills','physical_15',15,0.7800,0.7821,0.269,1.20,2.10,'pass','none','2026-04-08 10:00'::timestamptz),
  ('Apollo Jubilee Hills','physical_30',30,0.6200,0.6188,-0.194,1.10,2.30,'pass','none','2026-04-08 11:00'::timestamptz),
  ('Apollo Jubilee Hills','physical_45',45,0.4900,0.4922,0.449,1.50,2.40,'pass','none','2026-04-08 12:00'::timestamptz),
  ('Apollo Jubilee Hills','physical_60',60,0.3700,0.3711,0.297,1.80,2.60,'pass','none','2026-04-08 13:00'::timestamptz),
  ('Apollo Bannerghatta','dynamic_edw',30,0.7100,0.7045,-0.775,2.10,3.00,'marginal','recalibrate','2026-04-12 14:00'::timestamptz),
  ('Manipal Hebbal','physical_15',15,0.7800,0.7989,2.423,2.40,3.30,'fail','vendor_service','2026-04-15 09:30'::timestamptz),
  ('Manipal Hebbal','physical_30',30,0.6200,0.6411,3.403,2.80,3.60,'fail','replace_wedge','2026-04-15 10:30'::timestamptz),
  ('Manipal Old Airport','physical_45',45,0.4900,0.4744,-3.184,3.10,3.80,'fail','vendor_service','2026-04-16 11:00'::timestamptz),
  ('Fortis Mulund','dynamic_edw',45,0.5800,0.5901,1.741,1.90,2.80,'marginal','recalibrate','2026-04-20 10:00'::timestamptz),
  ('Fortis Shalimar Bagh','virtual',60,0.4100,0.4114,0.341,1.40,2.20,'pass','none','2026-04-21 11:00'::timestamptz),
  ('Tata Memorial Mumbai','physical_15',15,0.7800,0.7799,-0.013,0.90,1.80,'pass','none','2026-04-25 09:00'::timestamptz),
  ('Tata Memorial Mumbai','physical_30',30,0.6200,0.6201,0.016,0.95,1.85,'pass','none','2026-04-25 10:00'::timestamptz),
  ('Tata Memorial Mumbai','motorized',60,0.3700,0.3705,0.135,1.10,2.00,'pass','none','2026-04-25 11:00'::timestamptz),
  ('AIIMS Delhi NCI','dynamic_edw',30,0.7100,0.7321,3.113,3.20,3.90,'fail','vendor_service','2026-04-28 15:00'::timestamptz),
  ('AIIMS Delhi NCI','virtual',45,0.5400,0.5089,-5.759,4.10,4.80,'equipment_fault','quarantine','2026-04-29 16:00'::timestamptz),
  ('Rajiv Gandhi Cancer Delhi','physical_45',45,0.4900,0.4878,-0.449,1.30,2.20,'pass','none','2026-05-02 10:00'::timestamptz),
  ('Kidwai Memorial Bangalore','physical_30',30,0.6200,0.6433,3.758,3.40,4.10,'fail','vendor_service','2026-05-05 11:00'::timestamptz),
  ('Tata Memorial Varanasi','dynamic_edw',60,0.4800,0.4811,0.229,1.20,2.10,'pass','none','2026-05-08 10:00'::timestamptz),
  ('HCG Bangalore','physical_60',60,0.3700,0.3782,2.216,2.30,3.20,'marginal','recalibrate','2026-05-10 12:00'::timestamptz),
  ('HCG Ahmedabad','physical_15',15,0.7800,0.8055,3.269,3.10,3.80,'fail','replace_wedge','2026-05-12 13:00'::timestamptz),
  ('Yashoda Hyderabad','virtual',45,0.5400,0.5414,0.259,1.30,2.20,'pass','none','2026-05-14 14:00'::timestamptz),
  ('Continental Hyderabad','dynamic_edw',45,0.5800,0.6101,5.190,4.20,4.90,'equipment_fault','quarantine','2026-05-16 15:00'::timestamptz);

-- RPC 1 — chain summary
create or replace function rpc_r3091_chain_summary()
returns table(chain_code text, calibrations_total int, out_of_tolerance int, recalibration_required int, aerb_noncompliant int, avg_deviation_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.chain_code,
      count(*)::int,
      (count(*) filter (where c.outcome='out_of_tolerance'))::int,
      (count(*) filter (where c.outcome='recalibration_required'))::int,
      (count(*) filter (where c.aerb_compliant=false))::int,
      round(avg(abs(c.deviation_pct))::numeric,3)
    from radiotherapy_linac_calibrations_r3091 c
    group by c.chain_code
    order by avg(abs(c.deviation_pct)) desc;
end; $$;
revoke all on function rpc_r3091_chain_summary() from public, anon;
grant execute on function rpc_r3091_chain_summary() to authenticated;

-- RPC 2 — outcome breakdown
create or replace function rpc_r3091_outcome_breakdown()
returns table(outcome text, n int, pct_of_total numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
declare total int;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into total from radiotherapy_linac_calibrations_r3091;
  return query
    select c.outcome, count(*)::int, round((count(*)::numeric*100/nullif(total,0)),2)
    from radiotherapy_linac_calibrations_r3091 c
    group by c.outcome
    order by count(*) desc;
end; $$;
revoke all on function rpc_r3091_outcome_breakdown() from public, anon;
grant execute on function rpc_r3091_outcome_breakdown() to authenticated;

-- RPC 3 — vendor reliability
create or replace function rpc_r3091_vendor_reliability()
returns table(linac_vendor text, units int, avg_abs_deviation numeric, out_of_tol_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.linac_vendor,
      count(*)::int,
      round(avg(abs(c.deviation_pct))::numeric,3),
      round(((count(*) filter (where c.outcome in ('out_of_tolerance','recalibration_required')))::numeric*100/count(*)),2)
    from radiotherapy_linac_calibrations_r3091 c
    group by c.linac_vendor
    order by avg(abs(c.deviation_pct)) desc;
end; $$;
revoke all on function rpc_r3091_vendor_reliability() from public, anon;
grant execute on function rpc_r3091_vendor_reliability() to authenticated;

-- RPC 4 — energy mode performance
create or replace function rpc_r3091_energy_performance()
returns table(energy_mode text, units int, avg_deviation numeric, max_deviation numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.energy_mode, count(*)::int,
      round(avg(abs(c.deviation_pct))::numeric,3),
      round(max(abs(c.deviation_pct))::numeric,3)
    from radiotherapy_linac_calibrations_r3091 c
    group by c.energy_mode
    order by max(abs(c.deviation_pct)) desc;
end; $$;
revoke all on function rpc_r3091_energy_performance() from public, anon;
grant execute on function rpc_r3091_energy_performance() to authenticated;

-- RPC 5 — wedge audit summary
create or replace function rpc_r3091_wedge_summary()
returns table(wedge_type text, audits int, pass_n int, fail_n int, equipment_fault_n int, avg_abs_dev numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select w.wedge_type, count(*)::int,
      (count(*) filter (where w.audit_status='pass'))::int,
      (count(*) filter (where w.audit_status='fail'))::int,
      (count(*) filter (where w.audit_status='equipment_fault'))::int,
      round(avg(abs(w.factor_deviation_pct))::numeric,3)
    from radiotherapy_wedge_filter_audits_r3091 w
    group by w.wedge_type
    order by count(*) filter (where w.audit_status in ('fail','equipment_fault')) desc;
end; $$;
revoke all on function rpc_r3091_wedge_summary() from public, anon;
grant execute on function rpc_r3091_wedge_summary() to authenticated;

-- RPC 6 — corrective action queue
create or replace function rpc_r3091_corrective_queue()
returns table(hospital_name text, wedge_type text, factor_deviation_pct numeric, audit_status text, corrective_action text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select w.hospital_name, w.wedge_type, w.factor_deviation_pct, w.audit_status, w.corrective_action
    from radiotherapy_wedge_filter_audits_r3091 w
    where w.audit_status in ('fail','equipment_fault','marginal')
    order by abs(w.factor_deviation_pct) desc;
end; $$;
revoke all on function rpc_r3091_corrective_queue() from public, anon;
grant execute on function rpc_r3091_corrective_queue() to authenticated;

-- RPC 7 — AERB non-compliance
create or replace function rpc_r3091_aerb_noncompliance()
returns table(hospital_name text, linac_serial text, energy_mode text, deviation_pct numeric, outcome text, calibration_date date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.hospital_name, c.linac_serial, c.energy_mode, c.deviation_pct, c.outcome, c.calibration_date
    from radiotherapy_linac_calibrations_r3091 c
    where c.aerb_compliant = false
    order by abs(c.deviation_pct) desc;
end; $$;
revoke all on function rpc_r3091_aerb_noncompliance() from public, anon;
grant execute on function rpc_r3091_aerb_noncompliance() to authenticated;

-- RPC 8 — hospital scorecard
create or replace function rpc_r3091_hospital_scorecard()
returns table(hospital_name text, calibrations int, wedge_audits int, failures int, max_dev_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.hospital_name,
      count(distinct c.id)::int,
      (select count(*)::int from radiotherapy_wedge_filter_audits_r3091 w where w.hospital_name=c.hospital_name),
      ((count(*) filter (where c.outcome in ('out_of_tolerance','recalibration_required')))::int
        + coalesce((select count(*)::int from radiotherapy_wedge_filter_audits_r3091 w where w.hospital_name=c.hospital_name and w.audit_status in ('fail','equipment_fault')),0)),
      round(max(abs(c.deviation_pct))::numeric,3)
    from radiotherapy_linac_calibrations_r3091 c
    group by c.hospital_name
    order by max(abs(c.deviation_pct)) desc;
end; $$;
revoke all on function rpc_r3091_hospital_scorecard() from public, anon;
grant execute on function rpc_r3091_hospital_scorecard() to authenticated;
