-- Round r2982: Engineer Monthly Customer Site OT Microphone-Headset Sterilization Audit
-- Heavy founder console — 2 tables + 7 RPCs

set check_function_bodies = off;

------------------------------------------------------------
-- Tables
------------------------------------------------------------

create table if not exists ot_mic_headset_steril_audits_r2982 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_month date not null,
  hospital_org_id uuid,
  hospital_name text not null,
  ot_room_code text not null,
  engineer_user_id uuid,
  engineer_name text not null,
  headset_serial text not null,
  microphone_model text not null,
  sterilization_method text not null check (sterilization_method in ('etylene_oxide','hydrogen_peroxide_vapor','uvc_chamber','alcohol_wipe','autoclave_low_temp')),
  cycle_pass boolean not null,
  bioburden_cfu int not null check (bioburden_cfu >= 0),
  residual_etylene_ppm numeric(6,2) not null check (residual_etylene_ppm >= 0),
  audit_score int not null check (audit_score between 0 and 100),
  compliance_band text not null check (compliance_band in ('green','amber','red')),
  rework_required boolean not null,
  invoice_rupees int not null check (invoice_rupees >= 0)
);

create table if not exists ot_mic_headset_steril_findings_r2982 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid not null references ot_mic_headset_steril_audits_r2982(id) on delete cascade,
  finding_code text not null,
  severity text not null check (severity in ('p0','p1','p2','p3')),
  description text not null,
  capa_due_on date not null,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue'))
);

alter table ot_mic_headset_steril_audits_r2982 enable row level security;
alter table ot_mic_headset_steril_findings_r2982 enable row level security;

drop policy if exists ot_mic_headset_steril_audits_r2982_founder on ot_mic_headset_steril_audits_r2982;
create policy ot_mic_headset_steril_audits_r2982_founder on ot_mic_headset_steril_audits_r2982 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists ot_mic_headset_steril_findings_r2982_founder on ot_mic_headset_steril_findings_r2982;
create policy ot_mic_headset_steril_findings_r2982_founder on ot_mic_headset_steril_findings_r2982 for all to authenticated using (is_founder()) with check (is_founder());

revoke all on ot_mic_headset_steril_audits_r2982 from public, anon;
revoke all on ot_mic_headset_steril_findings_r2982 from public, anon;
grant select, insert, update, delete on ot_mic_headset_steril_audits_r2982 to authenticated;
grant select, insert, update, delete on ot_mic_headset_steril_findings_r2982 to authenticated;

------------------------------------------------------------
-- Seed data
------------------------------------------------------------

insert into ot_mic_headset_steril_audits_r2982
  (audit_month, hospital_name, ot_room_code, engineer_name, headset_serial, microphone_model, sterilization_method, cycle_pass, bioburden_cfu, residual_etylene_ppm, audit_score, compliance_band, rework_required, invoice_rupees)
values
  ('2026-05-01'::date, 'Apollo Jubilee Hills',  'OT-1A', 'Rajesh Kumar',    'HS-AX-00118', 'AxMic Pro 3',   'etylene_oxide',         true,  4,  1.20, 96, 'green', false, 1800),
  ('2026-05-01'::date, 'KIMS Secunderabad',     'OT-2B', 'Suresh Naidu',    'HS-AX-00122', 'AxMic Pro 3',   'hydrogen_peroxide_vapor', true,  8,  0.00, 92, 'green', false, 1800),
  ('2026-05-01'::date, 'Yashoda Somajiguda',    'OT-3A', 'Anil Reddy',      'HS-CL-00045', 'ClearVox 2',    'uvc_chamber',           false, 38, 0.00, 64, 'amber', true,  2400),
  ('2026-05-01'::date, 'Continental Gachibowli','OT-1B', 'Pavan Goud',      'HS-AX-00131', 'AxMic Pro 3',   'etylene_oxide',         true,  6,  1.80, 90, 'green', false, 1800),
  ('2026-05-01'::date, 'Care Banjara',          'OT-4',  'Mahesh Yadav',    'HS-CL-00077', 'ClearVox 2',    'autoclave_low_temp',    true,  10, 0.00, 88, 'green', false, 1800),
  ('2026-05-01'::date, 'Sunshine Paradise',     'OT-2A', 'Kiran Rao',       'HS-AX-00140', 'AxMic Pro 3',   'alcohol_wipe',          false, 55, 0.00, 48, 'red',   true,  2800),
  ('2026-05-01'::date, 'AIG Gachibowli',        'OT-5',  'Bhaskar Sharma',  'HS-AX-00151', 'AxMic Pro 3',   'hydrogen_peroxide_vapor', true,  3,  0.00, 98, 'green', false, 1800),
  ('2026-05-01'::date, 'Rainbow Banjara',       'OT-2',  'Naveen Teja',     'HS-CL-00091', 'ClearVox 2',    'etylene_oxide',         true,  9,  1.50, 86, 'green', false, 1800),
  ('2026-04-01'::date, 'Apollo Jubilee Hills',  'OT-1A', 'Rajesh Kumar',    'HS-AX-00118', 'AxMic Pro 3',   'etylene_oxide',         true,  5,  1.40, 94, 'green', false, 1800),
  ('2026-04-01'::date, 'KIMS Secunderabad',     'OT-2B', 'Suresh Naidu',    'HS-AX-00122', 'AxMic Pro 3',   'hydrogen_peroxide_vapor', true,  7,  0.00, 91, 'green', false, 1800),
  ('2026-04-01'::date, 'Yashoda Somajiguda',    'OT-3A', 'Anil Reddy',      'HS-CL-00045', 'ClearVox 2',    'uvc_chamber',           true,  12, 0.00, 82, 'amber', false, 1800),
  ('2026-04-01'::date, 'Sunshine Paradise',     'OT-2A', 'Kiran Rao',       'HS-AX-00140', 'AxMic Pro 3',   'alcohol_wipe',          false, 48, 0.00, 55, 'red',   true,  2600),
  ('2026-04-01'::date, 'Care Banjara',          'OT-4',  'Mahesh Yadav',    'HS-CL-00077', 'ClearVox 2',    'autoclave_low_temp',    true,  14, 0.00, 84, 'green', false, 1800),
  ('2026-04-01'::date, 'Continental Gachibowli','OT-1B', 'Pavan Goud',      'HS-AX-00131', 'AxMic Pro 3',   'etylene_oxide',         true,  8,  1.90, 88, 'green', false, 1800),
  ('2026-03-01'::date, 'Apollo Jubilee Hills',  'OT-1A', 'Rajesh Kumar',    'HS-AX-00118', 'AxMic Pro 3',   'etylene_oxide',         true,  6,  1.30, 93, 'green', false, 1800),
  ('2026-03-01'::date, 'Yashoda Somajiguda',    'OT-3A', 'Anil Reddy',      'HS-CL-00045', 'ClearVox 2',    'uvc_chamber',           false, 42, 0.00, 58, 'red',   true,  2700),
  ('2026-05-01'::date, 'Olive Banjara',         'OT-1',  'Rohit Verma',     'HS-AX-00170', 'AxMic Pro 3',   'etylene_oxide',         true,  5,  1.10, 95, 'green', false, 1800),
  ('2026-05-01'::date, 'Star Banjara',          'OT-3',  'Deepak Soma',     'HS-CL-00102', 'ClearVox 2',    'hydrogen_peroxide_vapor', true,  9,  0.00, 87, 'green', false, 1800);

insert into ot_mic_headset_steril_findings_r2982 (audit_id, finding_code, severity, description, capa_due_on, capa_status)
select id, 'F-ETO-RESIDUAL', 'p1', 'Residual ETO above 1.5 ppm — extend aeration cycle by 30 min.', '2026-06-15'::date, 'in_progress'
from ot_mic_headset_steril_audits_r2982 where residual_etylene_ppm > 1.4 limit 6;

insert into ot_mic_headset_steril_findings_r2982 (audit_id, finding_code, severity, description, capa_due_on, capa_status)
select id, 'F-BIOBURDEN', 'p0', 'Bioburden CFU exceeds 25 — immediate re-cycle required.', '2026-06-05'::date, 'overdue'
from ot_mic_headset_steril_audits_r2982 where bioburden_cfu > 25 limit 5;

insert into ot_mic_headset_steril_findings_r2982 (audit_id, finding_code, severity, description, capa_due_on, capa_status)
select id, 'F-METHOD-ALCOHOL', 'p2', 'Alcohol-wipe insufficient for porous foam — switch to ETO.', '2026-06-20'::date, 'open'
from ot_mic_headset_steril_audits_r2982 where sterilization_method = 'alcohol_wipe' limit 4;

insert into ot_mic_headset_steril_findings_r2982 (audit_id, finding_code, severity, description, capa_due_on, capa_status)
select id, 'F-DOC-MISSING', 'p3', 'Cycle log signature missing — retrain engineer on SOP-OT-MIC-04.', '2026-06-30'::date, 'closed'
from ot_mic_headset_steril_audits_r2982 where audit_score < 90 limit 5;

------------------------------------------------------------
-- RPCs
------------------------------------------------------------

create or replace function r2982_monthly_compliance_summary()
returns table(audit_month date, audits int, green int, amber int, red int, avg_score numeric, rework int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_month,
         count(*)::int as audits,
         (count(*) filter (where a.compliance_band = 'green'))::int as green,
         (count(*) filter (where a.compliance_band = 'amber'))::int as amber,
         (count(*) filter (where a.compliance_band = 'red'))::int as red,
         round(avg(a.audit_score)::numeric, 1) as avg_score,
         (count(*) filter (where a.rework_required))::int as rework
  from ot_mic_headset_steril_audits_r2982 a
  group by a.audit_month
  order by a.audit_month desc;
end;
$$;

create or replace function r2982_hospital_leaderboard()
returns table(hospital_name text, audits int, avg_score numeric, red_count int, total_invoice int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name,
         count(*)::int,
         round(avg(a.audit_score)::numeric, 1),
         (count(*) filter (where a.compliance_band = 'red'))::int,
         sum(a.invoice_rupees)::int
  from ot_mic_headset_steril_audits_r2982 a
  group by a.hospital_name
  order by avg(a.audit_score) desc;
end;
$$;

create or replace function r2982_engineer_performance()
returns table(engineer_name text, audits int, avg_score numeric, fail_rate numeric, rework int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name,
         count(*)::int,
         round(avg(a.audit_score)::numeric, 1),
         round((count(*) filter (where not a.cycle_pass))::numeric * 100.0 / nullif(count(*),0), 1),
         (count(*) filter (where a.rework_required))::int
  from ot_mic_headset_steril_audits_r2982 a
  group by a.engineer_name
  order by avg(a.audit_score) desc;
end;
$$;

create or replace function r2982_method_efficacy()
returns table(sterilization_method text, audits int, pass_rate numeric, avg_bioburden numeric, avg_score numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.sterilization_method,
         count(*)::int,
         round((count(*) filter (where a.cycle_pass))::numeric * 100.0 / nullif(count(*),0), 1),
         round(avg(a.bioburden_cfu)::numeric, 1),
         round(avg(a.audit_score)::numeric, 1)
  from ot_mic_headset_steril_audits_r2982 a
  group by a.sterilization_method
  order by avg(a.audit_score) desc;
end;
$$;

create or replace function r2982_open_findings()
returns table(finding_code text, severity text, count int, overdue int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_code,
         f.severity,
         count(*)::int,
         (count(*) filter (where f.capa_status = 'overdue'))::int
  from ot_mic_headset_steril_findings_r2982 f
  where f.capa_status in ('open','in_progress','overdue')
  group by f.finding_code, f.severity
  order by f.severity asc, count(*) desc;
end;
$$;

create or replace function r2982_residual_eto_watchlist()
returns table(hospital_name text, ot_room_code text, headset_serial text, residual_etylene_ppm numeric, audit_month date)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.ot_room_code, a.headset_serial, a.residual_etylene_ppm, a.audit_month
  from ot_mic_headset_steril_audits_r2982 a
  where a.residual_etylene_ppm > 1.0
  order by a.residual_etylene_ppm desc;
end;
$$;

create or replace function r2982_invoice_rollup()
returns table(audit_month date, hospitals int, total_invoice int, rework_invoice int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_month,
         count(distinct a.hospital_name)::int,
         sum(a.invoice_rupees)::int,
         (sum(a.invoice_rupees) filter (where a.rework_required))::int
  from ot_mic_headset_steril_audits_r2982 a
  group by a.audit_month
  order by a.audit_month desc;
end;
$$;

revoke all on function r2982_monthly_compliance_summary() from public, anon;
revoke all on function r2982_hospital_leaderboard() from public, anon;
revoke all on function r2982_engineer_performance() from public, anon;
revoke all on function r2982_method_efficacy() from public, anon;
revoke all on function r2982_open_findings() from public, anon;
revoke all on function r2982_residual_eto_watchlist() from public, anon;
revoke all on function r2982_invoice_rollup() from public, anon;

grant execute on function r2982_monthly_compliance_summary() to authenticated;
grant execute on function r2982_hospital_leaderboard() to authenticated;
grant execute on function r2982_engineer_performance() to authenticated;
grant execute on function r2982_method_efficacy() to authenticated;
grant execute on function r2982_open_findings() to authenticated;
grant execute on function r2982_residual_eto_watchlist() to authenticated;
grant execute on function r2982_invoice_rollup() to authenticated;
