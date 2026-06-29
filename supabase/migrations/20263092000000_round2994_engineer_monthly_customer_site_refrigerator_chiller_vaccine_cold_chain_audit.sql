-- Round r2994 — Engineer Monthly Customer Site Refrigerator-Chiller Vaccine Cold-Chain Audit

create table if not exists cold_chain_audit_visits_r2994 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  customer_site text not null,
  city text not null,
  engineer_name text not null,
  visit_date date not null,
  asset_kind text not null check (asset_kind in ('vaccine_refrigerator','blood_bank_chiller','plasma_freezer','ilr_350l','walk_in_cold_room','transport_box')),
  temperature_band text not null check (temperature_band in ('2_to_8c','minus_20c','minus_40c','minus_70c','ambient_15_25c')),
  audit_score int not null check (audit_score between 0 and 100),
  outcome text not null check (outcome in ('pass','pass_with_observations','conditional','fail','rescheduled')),
  excursion_minutes_last_30d int not null default 0,
  vaccine_value_at_risk_rupees int not null default 0
);

create table if not exists cold_chain_audit_findings_r2994 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  visit_id uuid references cold_chain_audit_visits_r2994(id) on delete cascade,
  finding_category text not null check (finding_category in ('compressor_wear','door_gasket_leak','thermostat_drift','data_logger_offline','power_backup_fail','frost_buildup','ventilation_block','calibration_overdue','sop_breach','documentation_gap')),
  severity text not null check (severity in ('p0','p1','p2','p3','observation')),
  corrective_action text not null,
  parts_required_rupees int not null default 0,
  closure_status text not null check (closure_status in ('open','in_progress','closed','escalated','deferred_customer'))
);

alter table cold_chain_audit_visits_r2994 enable row level security;
alter table cold_chain_audit_findings_r2994 enable row level security;

drop policy if exists ccav_r2994_founder on cold_chain_audit_visits_r2994;
create policy ccav_r2994_founder on cold_chain_audit_visits_r2994 for select using (is_founder());
drop policy if exists ccaf_r2994_founder on cold_chain_audit_findings_r2994;
create policy ccaf_r2994_founder on cold_chain_audit_findings_r2994 for select using (is_founder());

-- Seeds: visits (15)
insert into cold_chain_audit_visits_r2994 (customer_site, city, engineer_name, visit_date, asset_kind, temperature_band, audit_score, outcome, excursion_minutes_last_30d, vaccine_value_at_risk_rupees) values
('Apollo Jubilee Hills','Hyderabad','Ravi Kumar','2026-06-02'::date,'vaccine_refrigerator','2_to_8c',92,'pass',0,0),
('Fortis Bannerghatta','Bengaluru','Suresh Patel','2026-06-03'::date,'blood_bank_chiller','2_to_8c',78,'pass_with_observations',45,180000),
('AIIMS Delhi','Delhi','Anjali Sharma','2026-06-04'::date,'plasma_freezer','minus_40c',65,'conditional',220,950000),
('Manipal Whitefield','Bengaluru','Karthik Reddy','2026-06-05'::date,'ilr_350l','2_to_8c',88,'pass',12,25000),
('Yashoda Secunderabad','Hyderabad','Priya Nair','2026-06-06'::date,'walk_in_cold_room','2_to_8c',71,'pass_with_observations',95,420000),
('Kokilaben Mumbai','Mumbai','Amit Joshi','2026-06-09'::date,'vaccine_refrigerator','2_to_8c',45,'fail',410,1850000),
('CMC Vellore','Vellore','Deepa Iyer','2026-06-10'::date,'plasma_freezer','minus_70c',83,'pass',8,0),
('Tata Memorial','Mumbai','Rohit Singh','2026-06-11'::date,'blood_bank_chiller','2_to_8c',90,'pass',0,0),
('SGPGI Lucknow','Lucknow','Vikash Yadav','2026-06-12'::date,'transport_box','2_to_8c',55,'fail',180,310000),
('PGI Chandigarh','Chandigarh','Neha Gupta','2026-06-13'::date,'ilr_350l','2_to_8c',81,'pass_with_observations',28,55000),
('NIMHANS Bengaluru','Bengaluru','Sunil Rao','2026-06-16'::date,'vaccine_refrigerator','2_to_8c',96,'pass',0,0),
('KIMS Hyderabad','Hyderabad','Lakshmi Devi','2026-06-17'::date,'walk_in_cold_room','2_to_8c',62,'conditional',155,680000),
('Narayana Bengaluru','Bengaluru','Pradeep Kumar','2026-06-18'::date,'plasma_freezer','minus_40c',74,'pass_with_observations',38,210000),
('Max Saket','Delhi','Ritu Verma','2026-06-19'::date,'vaccine_refrigerator','2_to_8c',0,'rescheduled',0,0),
('Sankara Nethralaya','Chennai','Murali Krishnan','2026-06-20'::date,'ilr_350l','2_to_8c',87,'pass',5,15000);

-- Seeds: findings (24)
with v as (select id, customer_site from cold_chain_audit_visits_r2994)
insert into cold_chain_audit_findings_r2994 (visit_id, finding_category, severity, corrective_action, parts_required_rupees, closure_status)
select v.id, x.cat, x.sev, x.act, x.cost, x.st from v join (values
('Apollo Jubilee Hills','calibration_overdue','p3','schedule NABL calibration within 30 days',8000,'closed'),
('Fortis Bannerghatta','door_gasket_leak','p2','replace gasket strip and re-test seal',4500,'in_progress'),
('Fortis Bannerghatta','data_logger_offline','p2','restore SIM connectivity for logger',2000,'closed'),
('AIIMS Delhi','compressor_wear','p1','replace condenser fan motor',38000,'escalated'),
('AIIMS Delhi','thermostat_drift','p1','recalibrate thermostat and validate 24h',6000,'in_progress'),
('AIIMS Delhi','documentation_gap','p2','reconstruct last 30d log register',0,'closed'),
('Manipal Whitefield','frost_buildup','p3','manual defrost cycle and SOP retrain',1500,'closed'),
('Yashoda Secunderabad','power_backup_fail','p1','replace UPS battery bank',55000,'escalated'),
('Yashoda Secunderabad','ventilation_block','p2','clear coil dust and reposition unit',3500,'closed'),
('Kokilaben Mumbai','compressor_wear','p0','emergency compressor swap',125000,'escalated'),
('Kokilaben Mumbai','sop_breach','p0','suspend vaccine storage pending fix',0,'open'),
('Kokilaben Mumbai','data_logger_offline','p1','replace logger and audit gaps',18000,'in_progress'),
('CMC Vellore','calibration_overdue','p3','book MFG-rep visit Q3',12000,'open'),
('Tata Memorial','documentation_gap','observation','digitize paper log to portal',0,'closed'),
('SGPGI Lucknow','power_backup_fail','p0','transport box battery replacement',22000,'escalated'),
('SGPGI Lucknow','sop_breach','p1','retrain transport staff on cold-chain SOP',0,'in_progress'),
('PGI Chandigarh','thermostat_drift','p3','tighten sensor mount and recheck',1200,'closed'),
('NIMHANS Bengaluru','calibration_overdue','observation','annual cal due Sep',0,'deferred_customer'),
('KIMS Hyderabad','ventilation_block','p1','relocate unit away from wall',5000,'in_progress'),
('KIMS Hyderabad','frost_buildup','p2','full defrost and gasket inspection',2500,'closed'),
('KIMS Hyderabad','door_gasket_leak','p1','dual-door gasket swap',9000,'open'),
('Narayana Bengaluru','data_logger_offline','p2','reseat antenna and verify uplink',1800,'closed'),
('Narayana Bengaluru','documentation_gap','p3','close prior-month log gap',0,'closed'),
('Sankara Nethralaya','calibration_overdue','observation','plan with vendor',7000,'deferred_customer')
) as x(site, cat, sev, act, cost, st) on x.site = v.customer_site;

-- RPC 1: city rollup
create or replace function r2994_city_rollup()
returns table(city text, visits int, avg_score numeric, fails int, value_at_risk_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.city,
         count(*)::int,
         round(avg(v.audit_score)::numeric, 1),
         (count(*) filter (where v.outcome = 'fail'))::int,
         sum(v.vaccine_value_at_risk_rupees)::bigint
  from cold_chain_audit_visits_r2994 v
  group by v.city
  order by sum(v.vaccine_value_at_risk_rupees) desc;
end; $$;

-- RPC 2: engineer scoreboard
create or replace function r2994_engineer_scoreboard()
returns table(engineer_name text, visits int, avg_score numeric, passes int, fails int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.engineer_name,
         count(*)::int,
         round(avg(v.audit_score)::numeric, 1),
         (count(*) filter (where v.outcome = 'pass'))::int,
         (count(*) filter (where v.outcome = 'fail'))::int
  from cold_chain_audit_visits_r2994 v
  group by v.engineer_name
  order by avg(v.audit_score) desc nulls last;
end; $$;

-- RPC 3: asset risk mix
create or replace function r2994_asset_risk_mix()
returns table(asset_kind text, visits int, excursion_minutes_total int, value_at_risk_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.asset_kind,
         count(*)::int,
         sum(v.excursion_minutes_last_30d)::int,
         sum(v.vaccine_value_at_risk_rupees)::bigint
  from cold_chain_audit_visits_r2994 v
  group by v.asset_kind
  order by sum(v.vaccine_value_at_risk_rupees) desc;
end; $$;

-- RPC 4: severity ladder
create or replace function r2994_severity_ladder()
returns table(severity text, findings int, open_count int, parts_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.severity,
         count(*)::int,
         (count(*) filter (where f.closure_status in ('open','in_progress','escalated')))::int,
         sum(f.parts_required_rupees)::bigint
  from cold_chain_audit_findings_r2994 f
  group by f.severity
  order by case f.severity when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 when 'p3' then 3 else 4 end;
end; $$;

-- RPC 5: top sites at risk
create or replace function r2994_top_sites_at_risk()
returns table(customer_site text, city text, audit_score int, excursion_minutes_last_30d int, value_at_risk_rupees int, outcome text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.customer_site, v.city, v.audit_score, v.excursion_minutes_last_30d, v.vaccine_value_at_risk_rupees, v.outcome
  from cold_chain_audit_visits_r2994 v
  order by v.vaccine_value_at_risk_rupees desc, v.excursion_minutes_last_30d desc
  limit 10;
end; $$;

-- RPC 6: finding category mix
create or replace function r2994_finding_category_mix()
returns table(finding_category text, findings int, escalated int, parts_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_category,
         count(*)::int,
         (count(*) filter (where f.closure_status = 'escalated'))::int,
         sum(f.parts_required_rupees)::bigint
  from cold_chain_audit_findings_r2994 f
  group by f.finding_category
  order by count(*) desc;
end; $$;

-- RPC 7: monthly kpi
create or replace function r2994_monthly_kpi()
returns table(metric text, value text)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  total_visits int; pass_rate numeric; total_var bigint; open_p0p1 int; avg_excursion numeric;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into total_visits from cold_chain_audit_visits_r2994;
  select round(100.0 * (count(*) filter (where outcome = 'pass'))::numeric / nullif(count(*),0), 1)
    into pass_rate from cold_chain_audit_visits_r2994;
  select coalesce(sum(vaccine_value_at_risk_rupees),0) into total_var from cold_chain_audit_visits_r2994;
  select (count(*) filter (where severity in ('p0','p1') and closure_status in ('open','in_progress','escalated')))::int
    into open_p0p1 from cold_chain_audit_findings_r2994;
  select round(avg(excursion_minutes_last_30d)::numeric, 1) into avg_excursion from cold_chain_audit_visits_r2994;
  return query values
    ('total_visits_june', total_visits::text),
    ('pass_rate_pct', coalesce(pass_rate::text,'0')),
    ('vaccine_value_at_risk_rupees', total_var::text),
    ('open_p0_p1_findings', open_p0p1::text),
    ('avg_excursion_minutes_30d', coalesce(avg_excursion::text,'0'));
end; $$;

revoke all on cold_chain_audit_visits_r2994 from public, anon;
revoke all on cold_chain_audit_findings_r2994 from public, anon;
grant select on cold_chain_audit_visits_r2994 to authenticated;
grant select on cold_chain_audit_findings_r2994 to authenticated;

revoke all on function r2994_city_rollup() from public, anon;
revoke all on function r2994_engineer_scoreboard() from public, anon;
revoke all on function r2994_asset_risk_mix() from public, anon;
revoke all on function r2994_severity_ladder() from public, anon;
revoke all on function r2994_top_sites_at_risk() from public, anon;
revoke all on function r2994_finding_category_mix() from public, anon;
revoke all on function r2994_monthly_kpi() from public, anon;

grant execute on function r2994_city_rollup() to authenticated;
grant execute on function r2994_engineer_scoreboard() to authenticated;
grant execute on function r2994_asset_risk_mix() to authenticated;
grant execute on function r2994_severity_ladder() to authenticated;
grant execute on function r2994_top_sites_at_risk() to authenticated;
grant execute on function r2994_finding_category_mix() to authenticated;
grant execute on function r2994_monthly_kpi() to authenticated;
