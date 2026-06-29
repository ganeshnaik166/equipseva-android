-- Round 3015: Hospital Chain Quarterly Pharmacy Cold-Storage Crash-Cabinet Lock & Expiry Audit
-- HEAVY ★★★★

create table if not exists pharmacy_cold_storage_audits_r3015 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  hospital_name text not null,
  city text not null,
  chain_brand text not null,
  audit_quarter text not null check (audit_quarter in ('Q1','Q2','Q3','Q4')),
  audit_year int not null check (audit_year between 2025 and 2027),
  audited_at timestamptz,
  scheduled_for timestamptz not null,
  asset_kind text not null check (asset_kind in ('cold_storage','crash_cabinet','vaccine_fridge','narcotic_safe')),
  asset_label text not null,
  lock_status text not null check (lock_status in ('intact','tamper_evident','broken','missing','seal_replaced')),
  temperature_min_celsius numeric(5,2),
  temperature_max_celsius numeric(5,2),
  temperature_breach_minutes int not null default 0 check (temperature_breach_minutes between 0 and 4320),
  expired_skus_count int not null default 0 check (expired_skus_count between 0 and 200),
  near_expiry_skus_count int not null default 0 check (near_expiry_skus_count between 0 and 500),
  controlled_substance_count int not null default 0 check (controlled_substance_count between 0 and 100),
  controlled_substance_variance int not null default 0 check (controlled_substance_variance between -20 and 20),
  audit_score int not null check (audit_score between 0 and 100),
  status text not null check (status in ('scheduled','in_progress','passed','flagged','failed','escalated')),
  pharmacist_in_charge text,
  drug_inspector_notified boolean not null default false,
  cdsco_reportable boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists pharmacy_cold_storage_findings_r3015 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid references pharmacy_cold_storage_audits_r3015(id) on delete cascade,
  finding_category text not null check (finding_category in ('lock_breach','expired_stock','temperature','controlled_substance','documentation','sop_deviation')),
  severity text not null check (severity in ('critical','high','medium','low','info')),
  sku_or_asset text not null,
  batch_number text,
  expiry_date date,
  observed_value text not null,
  expected_value text not null,
  quantity_affected int not null default 0 check (quantity_affected between 0 and 5000),
  rupees_at_risk int not null default 0 check (rupees_at_risk between 0 and 5000000),
  remediation_eta_hours int not null default 24 check (remediation_eta_hours between 0 and 720),
  resolution_status text not null check (resolution_status in ('open','acknowledged','in_progress','resolved','accepted_risk')),
  resolved_at timestamptz,
  regulatory_clock_hours int not null default 0 check (regulatory_clock_hours between 0 and 168),
  created_at timestamptz not null default now()
);

alter table pharmacy_cold_storage_audits_r3015 enable row level security;
alter table pharmacy_cold_storage_findings_r3015 enable row level security;

drop policy if exists pcsa_r3015_founder_select on pharmacy_cold_storage_audits_r3015;
create policy pcsa_r3015_founder_select on pharmacy_cold_storage_audits_r3015 for select to authenticated using (is_founder());

drop policy if exists pcsf_r3015_founder_select on pharmacy_cold_storage_findings_r3015;
create policy pcsf_r3015_founder_select on pharmacy_cold_storage_findings_r3015 for select to authenticated using (is_founder());

-- Seeds: 18 audits
insert into pharmacy_cold_storage_audits_r3015
(hospital_name, city, chain_brand, audit_quarter, audit_year, audited_at, scheduled_for, asset_kind, asset_label, lock_status, temperature_min_celsius, temperature_max_celsius, temperature_breach_minutes, expired_skus_count, near_expiry_skus_count, controlled_substance_count, controlled_substance_variance, audit_score, status, pharmacist_in_charge, drug_inspector_notified, cdsco_reportable)
values
('Apollo Jubilee Hills','Hyderabad','Apollo','Q2',2026,'2026-06-14 10:00:00+05:30'::timestamptz,'2026-06-14 10:00:00+05:30'::timestamptz,'cold_storage','CS-A1-Insulin','intact',2.1,7.8,12,3,18,0,0,87,'passed','Dr R. Iyer',false,false),
('Apollo Banjara Hills','Hyderabad','Apollo','Q2',2026,'2026-06-14 11:30:00+05:30'::timestamptz,'2026-06-14 11:30:00+05:30'::timestamptz,'crash_cabinet','CC-ER-01','tamper_evident',null,null,0,0,4,12,-1,72,'flagged','Dr S. Menon',true,false),
('Apollo Hyderguda','Hyderabad','Apollo','Q2',2026,'2026-06-15 09:15:00+05:30'::timestamptz,'2026-06-15 09:15:00+05:30'::timestamptz,'vaccine_fridge','VF-PED-02','intact',2.5,7.5,0,0,6,0,0,94,'passed','Dr K. Reddy',false,false),
('Fortis Mulund','Mumbai','Fortis','Q2',2026,'2026-06-12 14:00:00+05:30'::timestamptz,'2026-06-12 14:00:00+05:30'::timestamptz,'narcotic_safe','NS-OT-1','broken',null,null,0,0,0,28,-3,38,'failed','Dr A. Khan',true,true),
('Fortis Bandra','Mumbai','Fortis','Q2',2026,'2026-06-13 10:00:00+05:30'::timestamptz,'2026-06-13 10:00:00+05:30'::timestamptz,'cold_storage','CS-B2-Vaccines','intact',3.0,8.2,38,1,22,0,0,79,'flagged','Dr V. Sharma',false,false),
('Manipal Old Airport','Bengaluru','Manipal','Q2',2026,'2026-06-10 11:00:00+05:30'::timestamptz,'2026-06-10 11:00:00+05:30'::timestamptz,'crash_cabinet','CC-ICU-02','seal_replaced',null,null,0,2,11,8,0,82,'passed','Dr P. Hegde',false,false),
('Manipal Whitefield','Bengaluru','Manipal','Q2',2026,'2026-06-11 09:30:00+05:30'::timestamptz,'2026-06-11 09:30:00+05:30'::timestamptz,'cold_storage','CS-C1','intact',2.8,7.9,5,0,9,0,0,91,'passed','Dr N. Rao',false,false),
('Max Saket','Delhi','Max','Q2',2026,'2026-06-09 13:00:00+05:30'::timestamptz,'2026-06-09 13:00:00+05:30'::timestamptz,'narcotic_safe','NS-OT-2','missing',null,null,0,0,0,20,-8,12,'escalated','Dr M. Gupta',true,true),
('Max Patparganj','Delhi','Max','Q2',2026,'2026-06-09 15:30:00+05:30'::timestamptz,'2026-06-09 15:30:00+05:30'::timestamptz,'vaccine_fridge','VF-PED-01','intact',2.2,7.6,0,4,15,0,0,76,'flagged','Dr L. Singh',false,false),
('Medanta Gurugram','Gurugram','Medanta','Q2',2026,'2026-06-08 10:00:00+05:30'::timestamptz,'2026-06-08 10:00:00+05:30'::timestamptz,'crash_cabinet','CC-ER-03','intact',null,null,0,0,3,10,0,96,'passed','Dr T. Verma',false,false),
('AIIMS Pharmacy Block-A','Delhi','AIIMS','Q2',2026,'2026-06-07 14:00:00+05:30'::timestamptz,'2026-06-07 14:00:00+05:30'::timestamptz,'cold_storage','CS-A','tamper_evident',1.8,8.5,72,6,28,0,0,58,'flagged','Dr U. Joshi',true,false),
('AIIMS Trauma','Delhi','AIIMS','Q2',2026,'2026-06-07 16:00:00+05:30'::timestamptz,'2026-06-07 16:00:00+05:30'::timestamptz,'narcotic_safe','NS-TRA-1','intact',null,null,0,0,0,32,0,89,'passed','Dr B. Pillai',false,false),
('Apollo Bengaluru','Bengaluru','Apollo','Q3',2026,null::timestamptz,'2026-07-05 10:00:00+05:30'::timestamptz,'cold_storage','CS-D1','intact',null,null,0,0,0,0,0,0,'scheduled',null,false,false),
('Fortis Noida','Noida','Fortis','Q3',2026,null::timestamptz,'2026-07-06 11:00:00+05:30'::timestamptz,'crash_cabinet','CC-ICU-01','intact',null,null,0,0,0,0,0,0,'scheduled',null,false,false),
('Manipal Yeshwanthpur','Bengaluru','Manipal','Q3',2026,null::timestamptz,'2026-07-08 09:00:00+05:30'::timestamptz,'vaccine_fridge','VF-NEO-01','intact',null,null,0,0,0,0,0,0,'scheduled',null,false,false),
('Max Shalimar Bagh','Delhi','Max','Q3',2026,null::timestamptz,'2026-07-10 14:00:00+05:30'::timestamptz,'narcotic_safe','NS-OT-3','intact',null,null,0,0,0,0,0,0,'scheduled',null,false,false),
('KIMS Secunderabad','Hyderabad','KIMS','Q2',2026,'2026-06-16 10:00:00+05:30'::timestamptz,'2026-06-16 10:00:00+05:30'::timestamptz,'cold_storage','CS-K1','intact',2.4,7.4,2,1,12,0,0,88,'passed','Dr H. Krishna',false,false),
('Yashoda Somajiguda','Hyderabad','Yashoda','Q2',2026,'2026-06-17 11:30:00+05:30'::timestamptz,'2026-06-17 11:30:00+05:30'::timestamptz,'crash_cabinet','CC-ER-Y1','tamper_evident',null,null,0,1,7,15,-2,68,'flagged','Dr G. Naidu',true,false);

-- Seeds: 22 findings
with a as (select id, hospital_name, asset_kind from pharmacy_cold_storage_audits_r3015)
insert into pharmacy_cold_storage_findings_r3015
(audit_id, finding_category, severity, sku_or_asset, batch_number, expiry_date, observed_value, expected_value, quantity_affected, rupees_at_risk, remediation_eta_hours, resolution_status, resolved_at, regulatory_clock_hours)
select id, 'temperature', 'low', 'CS-A1-Insulin', 'INS-2026-04', '2027-03-31'::date, '7.8C peak', '2-8C', 0, 12000, 4, 'resolved', '2026-06-14 14:00:00+05:30'::timestamptz, 0 from a where hospital_name='Apollo Jubilee Hills'
union all
select id, 'controlled_substance', 'high', 'Morphine 10mg', 'MOR-25-11', '2027-08-15'::date, '11 vials', '12 vials', 1, 8500, 24, 'in_progress', null::timestamptz, 48 from a where hospital_name='Apollo Banjara Hills'
union all
select id, 'lock_breach', 'critical', 'NS-OT-1', null, null::date, 'lock broken', 'tamper-evident seal intact', 1, 250000, 4, 'open', null::timestamptz, 24 from a where hospital_name='Fortis Mulund'
union all
select id, 'controlled_substance', 'critical', 'Fentanyl patch', 'FEN-26-02', '2027-02-10'::date, '25 patches', '28 patches', 3, 18000, 4, 'open', null::timestamptz, 24 from a where hospital_name='Fortis Mulund'
union all
select id, 'temperature', 'medium', 'Hep-B vaccine', 'HEP-26-05', '2026-12-15'::date, '8.2C 38min', '2-8C', 120, 45000, 12, 'acknowledged', null::timestamptz, 72 from a where hospital_name='Fortis Bandra'
union all
select id, 'expired_stock', 'medium', 'Insulin Glargine', 'GLA-25-09', '2026-05-30'::date, 'expired', 'in-date', 8, 22000, 24, 'resolved', '2026-06-13 12:00:00+05:30'::timestamptz, 0 from a where hospital_name='Fortis Bandra'
union all
select id, 'expired_stock', 'low', 'Atropine', 'ATR-25-12', '2026-06-30'::date, 'expires in 14d', 'rotate', 2, 1200, 48, 'resolved', '2026-06-10 16:00:00+05:30'::timestamptz, 0 from a where hospital_name='Manipal Old Airport'
union all
select id, 'lock_breach', 'critical', 'NS-OT-2', null, null::date, 'lock + key missing', 'lock present + dual custody', 1, 500000, 2, 'in_progress', null::timestamptz, 12 from a where hospital_name='Max Saket'
union all
select id, 'controlled_substance', 'critical', 'Pethidine 50mg', 'PET-26-01', '2027-01-20'::date, '12 amp', '20 amp', 8, 32000, 2, 'open', null::timestamptz, 8 from a where hospital_name='Max Saket'
union all
select id, 'documentation', 'high', 'register OT-2', null, null::date, 'last entry 2026-06-02', 'daily entries', 0, 0, 24, 'open', null::timestamptz, 24 from a where hospital_name='Max Saket'
union all
select id, 'expired_stock', 'medium', 'MMR vaccine', 'MMR-25-08', '2026-06-15'::date, 'expired 6 days', 'in-date', 4, 16000, 12, 'in_progress', null::timestamptz, 48 from a where hospital_name='Max Patparganj'
union all
select id, 'expired_stock', 'medium', 'BCG vaccine', 'BCG-25-10', '2026-06-20'::date, 'expires in 4d', 'rotate or destroy', 12, 9000, 24, 'in_progress', null::timestamptz, 48 from a where hospital_name='Max Patparganj'
union all
select id, 'temperature', 'high', 'CS-A peak 8.5C', 'CS-A-zone-3', null::date, '8.5C 72min', '2-8C', 0, 75000, 8, 'acknowledged', null::timestamptz, 24 from a where hospital_name='AIIMS Pharmacy Block-A'
union all
select id, 'expired_stock', 'high', 'Insulin Aspart', 'ASP-25-07', '2026-06-10'::date, 'expired 4d', 'in-date', 14, 38000, 8, 'in_progress', null::timestamptz, 24 from a where hospital_name='AIIMS Pharmacy Block-A'
union all
select id, 'sop_deviation', 'medium', 'CS-A door log', null, null::date, '14 door-opens/hour', 'max 6/hour', 0, 0, 72, 'open', null::timestamptz, 0 from a where hospital_name='AIIMS Pharmacy Block-A'
union all
select id, 'temperature', 'low', 'CS-D fluct', null, null::date, '7.4C peak', '2-8C', 0, 0, 24, 'resolved', '2026-06-16 16:00:00+05:30'::timestamptz, 0 from a where hospital_name='KIMS Secunderabad'
union all
select id, 'lock_breach', 'high', 'CC-ER-Y1', null, null::date, 'tamper seal cracked', 'intact', 1, 60000, 12, 'in_progress', null::timestamptz, 48 from a where hospital_name='Yashoda Somajiguda'
union all
select id, 'controlled_substance', 'high', 'Ketamine 50mg', 'KET-26-03', '2027-04-15'::date, '13 vials', '15 vials', 2, 14000, 24, 'open', null::timestamptz, 48 from a where hospital_name='Yashoda Somajiguda'
union all
select id, 'expired_stock', 'medium', 'Adrenaline', 'ADR-25-11', '2026-06-25'::date, 'expires in 9d', 'rotate', 1, 800, 72, 'open', null::timestamptz, 0 from a where hospital_name='Yashoda Somajiguda'
union all
select id, 'documentation', 'low', 'CC-ER-03 audit log', null, null::date, 'minor gaps', 'complete', 0, 0, 168, 'accepted_risk', null::timestamptz, 0 from a where hospital_name='Medanta Gurugram'
union all
select id, 'temperature', 'low', 'VF-PED-02', null, null::date, '7.5C peak transient', '2-8C', 0, 0, 24, 'resolved', '2026-06-15 12:00:00+05:30'::timestamptz, 0 from a where hospital_name='Apollo Hyderguda'
union all
select id, 'controlled_substance', 'medium', 'Diazepam 10mg', 'DZ-26-02', '2027-06-10'::date, '7 vials', '8 vials', 1, 2400, 48, 'acknowledged', null::timestamptz, 72 from a where hospital_name='Apollo Banjara Hills';

-- RPC 1: chain rollup
create or replace function r3015_chain_rollup()
returns table(chain_brand text, audits int, avg_score numeric, failed int, escalated int, cdsco_reportable int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.chain_brand,
    count(*)::int as audits,
    round(avg(a.audit_score) filter (where a.status <> 'scheduled'), 1) as avg_score,
    (count(*) filter (where a.status = 'failed'))::int as failed,
    (count(*) filter (where a.status = 'escalated'))::int as escalated,
    (count(*) filter (where a.cdsco_reportable))::int as cdsco_reportable
  from pharmacy_cold_storage_audits_r3015 a
  group by a.chain_brand
  order by avg_score nulls last;
end; $$;

-- RPC 2: lock-breach watchlist
create or replace function r3015_lock_breach_watchlist()
returns table(hospital_name text, chain_brand text, asset_label text, lock_status text, audit_score int, drug_inspector_notified boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.chain_brand, a.asset_label, a.lock_status, a.audit_score, a.drug_inspector_notified
  from pharmacy_cold_storage_audits_r3015 a
  where a.lock_status in ('broken','missing','tamper_evident','seal_replaced')
  order by case a.lock_status when 'missing' then 1 when 'broken' then 2 when 'tamper_evident' then 3 else 4 end, a.audit_score;
end; $$;

-- RPC 3: controlled-substance variance
create or replace function r3015_controlled_substance_variance()
returns table(hospital_name text, chain_brand text, asset_label text, controlled_substance_count int, controlled_substance_variance int, cdsco_reportable boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.chain_brand, a.asset_label, a.controlled_substance_count, a.controlled_substance_variance, a.cdsco_reportable
  from pharmacy_cold_storage_audits_r3015 a
  where a.asset_kind in ('narcotic_safe','crash_cabinet') and a.controlled_substance_variance <> 0
  order by abs(a.controlled_substance_variance) desc;
end; $$;

-- RPC 4: temperature-breach hotspots
create or replace function r3015_temperature_breach_hotspots()
returns table(hospital_name text, asset_label text, asset_kind text, temperature_max_celsius numeric, temperature_breach_minutes int, audit_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.asset_label, a.asset_kind, a.temperature_max_celsius, a.temperature_breach_minutes, a.audit_score
  from pharmacy_cold_storage_audits_r3015 a
  where a.temperature_breach_minutes > 0
  order by a.temperature_breach_minutes desc;
end; $$;

-- RPC 5: expiry risk window
create or replace function r3015_expiry_risk_window()
returns table(hospital_name text, asset_label text, expired_skus_count int, near_expiry_skus_count int, total_at_risk int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.asset_label, a.expired_skus_count, a.near_expiry_skus_count, (a.expired_skus_count + a.near_expiry_skus_count) as total_at_risk
  from pharmacy_cold_storage_audits_r3015 a
  where a.expired_skus_count + a.near_expiry_skus_count > 0
  order by total_at_risk desc
  limit 12;
end; $$;

-- RPC 6: critical open findings
create or replace function r3015_critical_open_findings()
returns table(hospital_name text, finding_category text, severity text, sku_or_asset text, rupees_at_risk int, regulatory_clock_hours int, resolution_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, f.finding_category, f.severity, f.sku_or_asset, f.rupees_at_risk, f.regulatory_clock_hours, f.resolution_status
  from pharmacy_cold_storage_findings_r3015 f
  join pharmacy_cold_storage_audits_r3015 a on a.id = f.audit_id
  where f.severity in ('critical','high') and f.resolution_status in ('open','acknowledged','in_progress')
  order by case f.severity when 'critical' then 1 else 2 end, f.regulatory_clock_hours;
end; $$;

-- RPC 7: quarter status summary
create or replace function r3015_quarter_status_summary()
returns table(audit_quarter text, scheduled int, in_progress int, passed int, flagged int, failed int, escalated int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_quarter,
    (count(*) filter (where a.status = 'scheduled'))::int,
    (count(*) filter (where a.status = 'in_progress'))::int,
    (count(*) filter (where a.status = 'passed'))::int,
    (count(*) filter (where a.status = 'flagged'))::int,
    (count(*) filter (where a.status = 'failed'))::int,
    (count(*) filter (where a.status = 'escalated'))::int
  from pharmacy_cold_storage_audits_r3015 a
  group by a.audit_quarter
  order by a.audit_quarter;
end; $$;

revoke all on function r3015_chain_rollup() from public, anon;
revoke all on function r3015_lock_breach_watchlist() from public, anon;
revoke all on function r3015_controlled_substance_variance() from public, anon;
revoke all on function r3015_temperature_breach_hotspots() from public, anon;
revoke all on function r3015_expiry_risk_window() from public, anon;
revoke all on function r3015_critical_open_findings() from public, anon;
revoke all on function r3015_quarter_status_summary() from public, anon;

grant execute on function r3015_chain_rollup() to authenticated;
grant execute on function r3015_lock_breach_watchlist() to authenticated;
grant execute on function r3015_controlled_substance_variance() to authenticated;
grant execute on function r3015_temperature_breach_hotspots() to authenticated;
grant execute on function r3015_expiry_risk_window() to authenticated;
grant execute on function r3015_critical_open_findings() to authenticated;
grant execute on function r3015_quarter_status_summary() to authenticated;
