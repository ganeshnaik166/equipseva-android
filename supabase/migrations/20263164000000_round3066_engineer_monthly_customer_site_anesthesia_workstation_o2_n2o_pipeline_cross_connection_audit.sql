-- Round 3066: Engineer Monthly Customer Site Anesthesia Workstation O2-N2O Pipeline Cross-Connection Audit
-- Two tables + 7 founder-gated RPCs.

set search_path = public, pg_temp;

-- =========================================================
-- TABLE 1: audit visits (one per engineer per customer per month)
-- =========================================================
create table if not exists engineer_anesthesia_pipeline_audits_r3066 (
  id uuid primary key default gen_random_uuid(),
  audit_month date not null,
  hospital_name text not null,
  hospital_city text not null,
  hospital_tier text not null check (hospital_tier in ('tier1','tier2','tier3','metro')),
  engineer_name text not null,
  engineer_certification text not null check (engineer_certification in ('basic','advanced','master','expert')),
  workstation_brand text not null check (workstation_brand in ('drager','ge','mindray','penlon','spacelabs')),
  workstation_model text not null,
  workstation_age_years int not null check (workstation_age_years between 0 and 25),
  audit_outcome text not null check (audit_outcome in ('pass','minor_findings','major_findings','critical_fail','retest_required')),
  cross_connection_detected boolean not null,
  o2_purity_pct numeric(5,2) not null check (o2_purity_pct between 0 and 100),
  n2o_purity_pct numeric(5,2) not null check (n2o_purity_pct between 0 and 100),
  pipeline_pressure_bar numeric(5,2) not null check (pipeline_pressure_bar between 0 and 10),
  audit_duration_minutes int not null check (audit_duration_minutes between 15 and 480),
  billing_amount_rupees int not null check (billing_amount_rupees between 0 and 500000),
  followup_required boolean not null,
  next_audit_due date,
  created_at timestamptz not null default now()
);

alter table engineer_anesthesia_pipeline_audits_r3066 enable row level security;

drop policy if exists pipeline_audits_r3066_founder_select on engineer_anesthesia_pipeline_audits_r3066;
create policy pipeline_audits_r3066_founder_select on engineer_anesthesia_pipeline_audits_r3066
  for select to authenticated using (is_founder());

insert into engineer_anesthesia_pipeline_audits_r3066 (
  audit_month, hospital_name, hospital_city, hospital_tier, engineer_name, engineer_certification,
  workstation_brand, workstation_model, workstation_age_years, audit_outcome, cross_connection_detected,
  o2_purity_pct, n2o_purity_pct, pipeline_pressure_bar, audit_duration_minutes, billing_amount_rupees,
  followup_required, next_audit_due
) values
  ('2026-06-01'::date,'Apollo Jubilee','Hyderabad','metro','Ramesh Kumar','master','drager','Fabius Tiro',4,'pass',false,99.6,98.4,4.10,95,18500,false,'2026-07-01'::date),
  ('2026-06-01'::date,'Yashoda Secunderabad','Hyderabad','metro','Priya Sharma','expert','ge','Aisys CS2',6,'minor_findings',false,99.2,97.8,4.05,120,22000,true,'2026-07-01'::date),
  ('2026-06-01'::date,'Care Banjara','Hyderabad','metro','Anil Verma','advanced','mindray','WATO EX-65',3,'pass',false,99.7,98.6,4.20,85,17500,false,'2026-07-01'::date),
  ('2026-06-01'::date,'KIMS Kondapur','Hyderabad','metro','Sunita Reddy','master','drager','Primus',8,'major_findings',false,98.5,96.4,3.85,180,32000,true,'2026-06-15'::date),
  ('2026-06-01'::date,'Continental Gachibowli','Hyderabad','metro','Rahul Singh','expert','penlon','Prima 460',2,'pass',false,99.8,98.9,4.15,75,16000,false,'2026-07-01'::date),
  ('2026-06-01'::date,'Sunshine Begumpet','Hyderabad','tier1','Meena Iyer','advanced','ge','Carestation 650',5,'minor_findings',false,99.1,97.5,4.00,110,20500,true,'2026-07-01'::date),
  ('2026-06-01'::date,'Star Nampally','Hyderabad','tier1','Vikram Patil','master','drager','Fabius Plus',7,'critical_fail',true,96.2,94.1,3.60,240,48000,true,'2026-06-10'::date),
  ('2026-06-01'::date,'Aware Gachibowli','Hyderabad','tier1','Deepa Nair','basic','mindray','WATO EX-35',9,'retest_required',false,98.3,96.8,3.95,150,28000,true,'2026-06-20'::date),
  ('2026-05-01'::date,'Apollo Greams','Chennai','metro','Karthik Menon','expert','drager','Perseus A500',1,'pass',false,99.9,99.1,4.25,70,15500,false,'2026-06-01'::date),
  ('2026-05-01'::date,'MIOT International','Chennai','metro','Lakshmi Rao','master','ge','Avance CS2',4,'pass',false,99.5,98.2,4.10,90,18000,false,'2026-06-01'::date),
  ('2026-05-01'::date,'Fortis Malar','Chennai','metro','Suresh Babu','advanced','spacelabs','Arkon',6,'minor_findings',false,99.0,97.3,3.98,115,21500,true,'2026-06-01'::date),
  ('2026-05-01'::date,'Kauvery Alwarpet','Chennai','metro','Anjali Pillai','master','drager','Fabius Tiro',5,'pass',false,99.6,98.5,4.12,80,17000,false,'2026-06-01'::date),
  ('2026-05-01'::date,'SIMS Vadapalani','Chennai','tier1','Mohan Das','expert','mindray','WATO EX-65 Pro',3,'pass',false,99.7,98.7,4.18,75,16500,false,'2026-06-01'::date),
  ('2026-05-01'::date,'Be Well Kilpauk','Chennai','tier2','Geetha Krishna','basic','penlon','Prima 320',12,'major_findings',false,97.8,95.6,3.75,200,38000,true,'2026-05-20'::date),
  ('2026-06-01'::date,'Manipal Whitefield','Bengaluru','metro','Arjun Reddy','master','drager','Perseus A500',2,'pass',false,99.8,98.9,4.22,70,15800,false,'2026-07-01'::date),
  ('2026-06-01'::date,'Narayana Mazumdar','Bengaluru','metro','Pooja Bhat','expert','ge','Aisys CS2',5,'pass',false,99.5,98.3,4.08,85,17200,false,'2026-07-01'::date),
  ('2026-06-01'::date,'Fortis Bannerghatta','Bengaluru','metro','Rohan Joshi','advanced','mindray','WATO EX-65',4,'minor_findings',false,99.2,97.7,4.02,105,19800,true,'2026-07-01'::date),
  ('2026-06-01'::date,'Aster CMI','Bengaluru','metro','Shruti Kapoor','master','drager','Fabius Plus',6,'pass',false,99.4,98.1,4.06,90,18200,false,'2026-07-01'::date),
  ('2026-06-01'::date,'Sakra World','Bengaluru','tier1','Naveen Gowda','basic','spacelabs','Arkon Mini',10,'critical_fail',true,95.8,93.7,3.55,260,52000,true,'2026-06-12'::date),
  ('2026-04-01'::date,'Tata Memorial','Mumbai','metro','Ashok Pandey','expert','drager','Perseus A500',3,'pass',false,99.7,98.6,4.15,80,16800,false,'2026-05-01'::date),
  ('2026-04-01'::date,'Hinduja Mahim','Mumbai','metro','Reena Shah','master','ge','Aisys CS2',7,'minor_findings',false,99.1,97.4,4.00,125,22500,true,'2026-05-01'::date),
  ('2026-04-01'::date,'Kokilaben','Mumbai','metro','Vivek Desai','advanced','mindray','WATO EX-65 Pro',4,'pass',false,99.6,98.4,4.12,85,17500,false,'2026-05-01'::date),
  ('2026-04-01'::date,'Lilavati','Mumbai','metro','Sneha Mehta','expert','drager','Fabius Tiro',9,'retest_required',false,98.4,96.5,3.92,160,30000,true,'2026-04-20'::date),
  ('2026-04-01'::date,'Holy Family Bandra','Mumbai','tier1','Imran Sheikh','master','penlon','Prima 460',5,'pass',false,99.5,98.2,4.08,90,18000,false,'2026-05-01'::date),
  ('2026-06-01'::date,'AIIMS Delhi','Delhi','metro','Manish Tyagi','expert','drager','Perseus A500',1,'pass',false,99.9,99.2,4.28,65,15000,false,'2026-07-01'::date),
  ('2026-06-01'::date,'Max Saket','Delhi','metro','Kavita Bansal','master','ge','Avance CS2',5,'pass',false,99.4,98.0,4.05,90,18500,false,'2026-07-01'::date),
  ('2026-06-01'::date,'Sir Ganga Ram','Delhi','metro','Rajat Khanna','advanced','mindray','WATO EX-65',6,'minor_findings',false,99.0,97.2,3.98,115,21000,true,'2026-07-01'::date),
  ('2026-06-01'::date,'BLK Pusa','Delhi','metro','Tanvi Goyal','master','spacelabs','Arkon',4,'pass',false,99.5,98.3,4.10,85,17800,false,'2026-07-01'::date);

-- =========================================================
-- TABLE 2: line-item findings per audit
-- =========================================================
create table if not exists pipeline_audit_findings_r3066 (
  id uuid primary key default gen_random_uuid(),
  finding_month date not null,
  hospital_name text not null,
  finding_category text not null check (finding_category in ('cross_connection','purity_drift','pressure_drop','valve_leak','labelling_error','sensor_calibration','vacuum_loss','documentation_gap')),
  severity text not null check (severity in ('info','low','medium','high','critical')),
  patient_risk_level text not null check (patient_risk_level in ('none','low','moderate','high','life_threatening')),
  detected_value numeric(8,3) not null,
  threshold_value numeric(8,3) not null,
  deviation_pct numeric(6,2) not null,
  corrective_action text not null check (corrective_action in ('immediate_shutdown','rectify_24h','rectify_7d','schedule_next_visit','customer_acknowledged','escalate_oem')),
  rectification_cost_rupees int not null check (rectification_cost_rupees between 0 and 1000000),
  rectified_at timestamptz,
  rectified boolean not null,
  oem_dispatch_required boolean not null,
  created_at timestamptz not null default now()
);

alter table pipeline_audit_findings_r3066 enable row level security;

drop policy if exists pipeline_findings_r3066_founder_select on pipeline_audit_findings_r3066;
create policy pipeline_findings_r3066_founder_select on pipeline_audit_findings_r3066
  for select to authenticated using (is_founder());

insert into pipeline_audit_findings_r3066 (
  finding_month, hospital_name, finding_category, severity, patient_risk_level,
  detected_value, threshold_value, deviation_pct, corrective_action,
  rectification_cost_rupees, rectified_at, rectified, oem_dispatch_required
) values
  ('2026-06-01'::date,'Star Nampally','cross_connection','critical','life_threatening',96.200,99.500,3.32,'immediate_shutdown',180000,'2026-06-02 14:30:00+05:30'::timestamptz,true,true),
  ('2026-06-01'::date,'Star Nampally','purity_drift','high','high',94.100,98.000,3.98,'rectify_24h',45000,'2026-06-02 18:00:00+05:30'::timestamptz,true,true),
  ('2026-06-01'::date,'Sakra World','cross_connection','critical','life_threatening',95.800,99.500,3.72,'immediate_shutdown',195000,'2026-06-13 09:15:00+05:30'::timestamptz,true,true),
  ('2026-06-01'::date,'Sakra World','valve_leak','high','high',3.550,4.000,11.25,'rectify_24h',32000,'2026-06-13 16:45:00+05:30'::timestamptz,true,true),
  ('2026-06-01'::date,'KIMS Kondapur','purity_drift','high','moderate',96.400,98.000,1.63,'rectify_7d',28000,'2026-06-09 11:00:00+05:30'::timestamptz,true,false),
  ('2026-06-01'::date,'KIMS Kondapur','pressure_drop','medium','moderate',3.850,4.100,6.10,'rectify_7d',15000,'2026-06-09 11:30:00+05:30'::timestamptz,true,false),
  ('2026-06-01'::date,'Yashoda Secunderabad','sensor_calibration','medium','low',97.800,98.500,0.71,'schedule_next_visit',8500,null::timestamptz,false,false),
  ('2026-06-01'::date,'Sunshine Begumpet','labelling_error','low','low',0.000,0.000,0.00,'customer_acknowledged',2500,'2026-06-08 10:00:00+05:30'::timestamptz,true,false),
  ('2026-06-01'::date,'Aware Gachibowli','documentation_gap','medium','none',0.000,0.000,0.00,'rectify_7d',5000,null::timestamptz,false,false),
  ('2026-05-01'::date,'Be Well Kilpauk','purity_drift','high','moderate',95.600,98.000,2.45,'rectify_7d',35000,'2026-05-22 13:00:00+05:30'::timestamptz,true,true),
  ('2026-05-01'::date,'Be Well Kilpauk','vacuum_loss','medium','low',0.450,0.600,25.00,'rectify_7d',12000,'2026-05-25 09:30:00+05:30'::timestamptz,true,false),
  ('2026-05-01'::date,'Fortis Malar','sensor_calibration','low','low',97.300,98.500,1.22,'schedule_next_visit',6500,null::timestamptz,false,false),
  ('2026-04-01'::date,'Hinduja Mahim','pressure_drop','medium','moderate',4.000,4.100,2.44,'rectify_7d',14000,'2026-04-12 15:00:00+05:30'::timestamptz,true,false),
  ('2026-04-01'::date,'Lilavati','valve_leak','high','moderate',3.920,4.100,4.39,'rectify_24h',38000,'2026-04-22 11:00:00+05:30'::timestamptz,true,true),
  ('2026-04-01'::date,'Lilavati','documentation_gap','low','none',0.000,0.000,0.00,'customer_acknowledged',1500,'2026-04-23 10:00:00+05:30'::timestamptz,true,false),
  ('2026-06-01'::date,'Fortis Bannerghatta','sensor_calibration','medium','low',97.700,98.500,0.81,'schedule_next_visit',7500,null::timestamptz,false,false),
  ('2026-06-01'::date,'Sir Ganga Ram','purity_drift','medium','low',97.200,98.000,0.82,'schedule_next_visit',9000,null::timestamptz,false,false),
  ('2026-06-01'::date,'Apollo Jubilee','documentation_gap','info','none',0.000,0.000,0.00,'customer_acknowledged',500,'2026-06-03 09:00:00+05:30'::timestamptz,true,false),
  ('2026-06-01'::date,'Continental Gachibowli','labelling_error','info','none',0.000,0.000,0.00,'customer_acknowledged',1000,'2026-06-04 11:00:00+05:30'::timestamptz,true,false),
  ('2026-05-01'::date,'MIOT International','sensor_calibration','low','low',98.200,98.500,0.30,'schedule_next_visit',6000,null::timestamptz,false,false),
  ('2026-06-01'::date,'Max Saket','documentation_gap','info','none',0.000,0.000,0.00,'customer_acknowledged',500,'2026-06-05 10:00:00+05:30'::timestamptz,true,false),
  ('2026-06-01'::date,'BLK Pusa','sensor_calibration','low','none',98.300,98.500,0.20,'schedule_next_visit',5500,null::timestamptz,false,false),
  ('2026-06-01'::date,'Manipal Whitefield','documentation_gap','info','none',0.000,0.000,0.00,'customer_acknowledged',500,'2026-06-04 09:30:00+05:30'::timestamptz,true,false),
  ('2026-04-01'::date,'Holy Family Bandra','labelling_error','low','none',0.000,0.000,0.00,'customer_acknowledged',2000,'2026-04-15 14:00:00+05:30'::timestamptz,true,false),
  ('2026-05-01'::date,'Apollo Greams','documentation_gap','info','none',0.000,0.000,0.00,'customer_acknowledged',500,'2026-05-03 10:00:00+05:30'::timestamptz,true,false);

-- =========================================================
-- RPC 1: monthly audit summary
-- =========================================================
create or replace function rpc_r3066_monthly_audit_summary()
returns table (
  audit_month date,
  total_audits int,
  passed int,
  minor int,
  major int,
  critical_fails int,
  cross_connections int,
  total_billing_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select a.audit_month,
         count(*)::int as total_audits,
         (count(*) filter (where a.audit_outcome='pass'))::int as passed,
         (count(*) filter (where a.audit_outcome='minor_findings'))::int as minor,
         (count(*) filter (where a.audit_outcome='major_findings'))::int as major,
         (count(*) filter (where a.audit_outcome='critical_fail'))::int as critical_fails,
         (count(*) filter (where a.cross_connection_detected))::int as cross_connections,
         sum(a.billing_amount_rupees)::bigint as total_billing_rupees
  from engineer_anesthesia_pipeline_audits_r3066 a
  group by a.audit_month
  order by a.audit_month desc;
end;
$$;

revoke all on function rpc_r3066_monthly_audit_summary() from public, anon;
grant execute on function rpc_r3066_monthly_audit_summary() to authenticated;

-- =========================================================
-- RPC 2: critical cross-connection list
-- =========================================================
create or replace function rpc_r3066_critical_cross_connections()
returns table (
  hospital_name text,
  hospital_city text,
  workstation_brand text,
  o2_purity_pct numeric,
  n2o_purity_pct numeric,
  pipeline_pressure_bar numeric,
  next_audit_due date
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select a.hospital_name, a.hospital_city, a.workstation_brand,
         a.o2_purity_pct, a.n2o_purity_pct, a.pipeline_pressure_bar, a.next_audit_due
  from engineer_anesthesia_pipeline_audits_r3066 a
  where a.cross_connection_detected = true
  order by a.audit_month desc, a.hospital_name;
end;
$$;

revoke all on function rpc_r3066_critical_cross_connections() from public, anon;
grant execute on function rpc_r3066_critical_cross_connections() to authenticated;

-- =========================================================
-- RPC 3: engineer performance ranking
-- =========================================================
create or replace function rpc_r3066_engineer_performance()
returns table (
  engineer_name text,
  certification text,
  audits_done int,
  pass_rate_pct numeric,
  avg_duration_min numeric,
  total_billing_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select a.engineer_name,
         a.engineer_certification,
         count(*)::int as audits_done,
         round(((count(*) filter (where a.audit_outcome='pass'))::numeric * 100.0) / nullif(count(*),0), 2) as pass_rate_pct,
         round(avg(a.audit_duration_minutes)::numeric, 1) as avg_duration_min,
         sum(a.billing_amount_rupees)::bigint as total_billing_rupees
  from engineer_anesthesia_pipeline_audits_r3066 a
  group by a.engineer_name, a.engineer_certification
  order by pass_rate_pct desc nulls last, audits_done desc;
end;
$$;

revoke all on function rpc_r3066_engineer_performance() from public, anon;
grant execute on function rpc_r3066_engineer_performance() to authenticated;

-- =========================================================
-- RPC 4: brand fleet age analysis
-- =========================================================
create or replace function rpc_r3066_brand_fleet_age()
returns table (
  workstation_brand text,
  fleet_count int,
  avg_age_years numeric,
  oldest_unit_years int,
  failure_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select a.workstation_brand,
         count(*)::int as fleet_count,
         round(avg(a.workstation_age_years)::numeric, 1) as avg_age_years,
         max(a.workstation_age_years)::int as oldest_unit_years,
         round(((count(*) filter (where a.audit_outcome in ('major_findings','critical_fail','retest_required')))::numeric * 100.0) / nullif(count(*),0), 2) as failure_rate_pct
  from engineer_anesthesia_pipeline_audits_r3066 a
  group by a.workstation_brand
  order by failure_rate_pct desc nulls last;
end;
$$;

revoke all on function rpc_r3066_brand_fleet_age() from public, anon;
grant execute on function rpc_r3066_brand_fleet_age() to authenticated;

-- =========================================================
-- RPC 5: findings by category
-- =========================================================
create or replace function rpc_r3066_findings_by_category()
returns table (
  finding_category text,
  total_findings int,
  critical_count int,
  high_count int,
  open_count int,
  total_rectification_cost_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select f.finding_category,
         count(*)::int as total_findings,
         (count(*) filter (where f.severity='critical'))::int as critical_count,
         (count(*) filter (where f.severity='high'))::int as high_count,
         (count(*) filter (where f.rectified = false))::int as open_count,
         sum(f.rectification_cost_rupees)::bigint as total_rectification_cost_rupees
  from pipeline_audit_findings_r3066 f
  group by f.finding_category
  order by critical_count desc, high_count desc;
end;
$$;

revoke all on function rpc_r3066_findings_by_category() from public, anon;
grant execute on function rpc_r3066_findings_by_category() to authenticated;

-- =========================================================
-- RPC 6: city tier risk profile
-- =========================================================
create or replace function rpc_r3066_city_tier_risk()
returns table (
  hospital_city text,
  hospital_tier text,
  audit_count int,
  cross_conn_count int,
  avg_o2_purity numeric,
  avg_n2o_purity numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select a.hospital_city,
         a.hospital_tier,
         count(*)::int as audit_count,
         (count(*) filter (where a.cross_connection_detected))::int as cross_conn_count,
         round(avg(a.o2_purity_pct)::numeric, 2) as avg_o2_purity,
         round(avg(a.n2o_purity_pct)::numeric, 2) as avg_n2o_purity
  from engineer_anesthesia_pipeline_audits_r3066 a
  group by a.hospital_city, a.hospital_tier
  order by cross_conn_count desc, audit_count desc;
end;
$$;

revoke all on function rpc_r3066_city_tier_risk() from public, anon;
grant execute on function rpc_r3066_city_tier_risk() to authenticated;

-- =========================================================
-- RPC 7: open findings backlog
-- =========================================================
create or replace function rpc_r3066_open_findings_backlog()
returns table (
  hospital_name text,
  finding_category text,
  severity text,
  patient_risk_level text,
  deviation_pct numeric,
  corrective_action text,
  rectification_cost_rupees int,
  oem_dispatch_required boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select f.hospital_name, f.finding_category, f.severity, f.patient_risk_level,
         f.deviation_pct, f.corrective_action, f.rectification_cost_rupees, f.oem_dispatch_required
  from pipeline_audit_findings_r3066 f
  where f.rectified = false
  order by case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 when 'low' then 4 else 5 end,
           f.finding_month desc;
end;
$$;

revoke all on function rpc_r3066_open_findings_backlog() from public, anon;
grant execute on function rpc_r3066_open_findings_backlog() to authenticated;
