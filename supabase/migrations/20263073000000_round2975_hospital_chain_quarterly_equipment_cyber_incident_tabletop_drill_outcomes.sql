-- Round 2975: Hospital Chain Quarterly Equipment Cyber-Incident Tabletop Drill Outcomes
-- HEAVY ★★★★

begin;

-- ============================================================
-- TABLES
-- ============================================================

create table if not exists hospital_chain_cyber_drill_sessions_r2975 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  drill_quarter text not null check (drill_quarter in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  drill_date date not null,
  scenario_code text not null check (scenario_code in ('ransomware_mri','phishing_pacs','iot_pump_breach','insider_data_leak','vendor_supplychain','ddos_emr','firmware_tamper','credential_stuff')),
  severity_tier text not null check (severity_tier in ('tier_1_critical','tier_2_high','tier_3_medium','tier_4_low')),
  facilitator_name text not null,
  participants_count int not null check (participants_count > 0 and participants_count <= 200),
  rto_target_minutes int not null check (rto_target_minutes > 0),
  rto_achieved_minutes int not null check (rto_achieved_minutes > 0),
  mttd_minutes int not null check (mttd_minutes >= 0),
  mttr_minutes int not null check (mttr_minutes >= 0),
  drill_score int not null check (drill_score between 0 and 100),
  status text not null check (status in ('scheduled','in_progress','completed','reviewed','closed')),
  affected_equipment_count int not null check (affected_equipment_count >= 0),
  passed boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists hospital_chain_cyber_drill_findings_r2975 (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references hospital_chain_cyber_drill_sessions_r2975(id) on delete cascade,
  finding_category text not null check (finding_category in ('detection_gap','response_delay','comm_breakdown','tool_failure','training_gap','playbook_gap','vendor_gap','recovery_gap')),
  finding_severity text not null check (finding_severity in ('critical','high','medium','low')),
  finding_text text not null,
  remediation_owner text not null,
  remediation_due date not null,
  remediation_status text not null check (remediation_status in ('open','in_progress','blocked','closed','deferred')),
  cost_estimate_rupees int not null check (cost_estimate_rupees >= 0),
  evidence_gathered boolean not null default false,
  created_at timestamptz not null default now()
);

alter table hospital_chain_cyber_drill_sessions_r2975 enable row level security;
alter table hospital_chain_cyber_drill_findings_r2975 enable row level security;

drop policy if exists sessions_founder_read_r2975 on hospital_chain_cyber_drill_sessions_r2975;
create policy sessions_founder_read_r2975 on hospital_chain_cyber_drill_sessions_r2975 for select using (is_founder());

drop policy if exists findings_founder_read_r2975 on hospital_chain_cyber_drill_findings_r2975;
create policy findings_founder_read_r2975 on hospital_chain_cyber_drill_findings_r2975 for select using (is_founder());

-- ============================================================
-- SEED DATA
-- ============================================================

insert into hospital_chain_cyber_drill_sessions_r2975
(chain_name, drill_quarter, drill_date, scenario_code, severity_tier, facilitator_name, participants_count, rto_target_minutes, rto_achieved_minutes, mttd_minutes, mttr_minutes, drill_score, status, affected_equipment_count, passed, notes)
values
('Apollo Hospitals','Q1-2026','2026-01-12'::date,'ransomware_mri','tier_1_critical','CISO Rao',42,60,82,18,75,72,'closed',14,false,'PACS isolation slow'),
('Fortis Healthcare','Q1-2026','2026-01-19'::date,'phishing_pacs','tier_2_high','SOC Lead Iyer',28,45,38,12,32,88,'closed',6,true,'Strong email triage'),
('Manipal Hospitals','Q1-2026','2026-02-02'::date,'iot_pump_breach','tier_1_critical','Biomed Dir Shah',35,30,55,22,48,65,'closed',9,false,'Pump segmentation missing'),
('Max Healthcare','Q1-2026','2026-02-15'::date,'insider_data_leak','tier_2_high','CISO Menon',22,90,78,40,65,82,'closed',3,true,'DLP caught exfil'),
('Narayana Health','Q1-2026','2026-03-01'::date,'vendor_supplychain','tier_3_medium','Risk Lead Pillai',31,120,135,55,110,71,'closed',11,false,'Vendor patch lag'),
('Medanta','Q2-2026','2026-04-10'::date,'ddos_emr','tier_2_high','Network Dir Khan',26,45,42,8,38,90,'closed',2,true,'CDN failover clean'),
('AIIMS Delhi','Q2-2026','2026-04-22'::date,'firmware_tamper','tier_1_critical','CISO Verma',48,60,95,30,82,68,'closed',16,false,'Firmware verify weak'),
('Kokilaben','Q2-2026','2026-05-05'::date,'credential_stuff','tier_3_medium','IAM Lead Desai',19,30,28,9,24,93,'closed',1,true,'MFA prevented breach'),
('Yashoda Hospitals','Q2-2026','2026-05-18'::date,'ransomware_mri','tier_1_critical','CISO Reddy',38,60,72,20,62,76,'closed',12,false,'Backup restore slow'),
('Aster DM','Q2-2026','2026-06-08'::date,'phishing_pacs','tier_2_high','SOC Mgr Nair',24,45,52,15,45,80,'reviewed',5,true,'Awareness training paid off'),
('Continental','Q3-2026','2026-07-15'::date,'iot_pump_breach','tier_1_critical','Biomed Lead Joshi',29,30,38,11,32,84,'reviewed',7,true,'Segmented VLAN held'),
('KIMS Hyderabad','Q3-2026','2026-08-02'::date,'insider_data_leak','tier_2_high','HR-Sec Patel',33,90,105,48,90,70,'completed',4,false,'Detection latency'),
('Care Hospitals','Q3-2026','2026-08-20'::date,'vendor_supplychain','tier_3_medium','Procurement Dir Saxena',21,120,110,42,95,86,'completed',8,true,'SBOM checks worked'),
('Wockhardt','Q3-2026','2026-09-05'::date,'ddos_emr','tier_2_high','NetOps Singh',25,45,68,12,58,67,'completed',2,false,'Need scrubbing service'),
('Columbia Asia','Q4-2026','2026-10-12'::date,'firmware_tamper','tier_1_critical','CISO Bhat',40,60,58,25,50,89,'in_progress',13,true,'TPM attestation worked'),
('Sterling','Q4-2026','2026-10-25'::date,'credential_stuff','tier_3_medium','IAM Lead Kumar',18,30,35,14,30,78,'in_progress',1,false,'MFA gap on legacy app'),
('Global Hospitals','Q4-2026','2026-11-08'::date,'ransomware_mri','tier_1_critical','CISO Pillai',45,60,68,22,58,81,'scheduled',15,true,'Immutable backup recovered'),
('PD Hinduja','Q1-2027','2027-01-15'::date,'phishing_pacs','tier_2_high','SOC Dir Jain',27,45,40,10,35,87,'scheduled',5,true,'Quick containment');

with s as (
  select id, scenario_code, drill_score
  from hospital_chain_cyber_drill_sessions_r2975
)
insert into hospital_chain_cyber_drill_findings_r2975
(session_id, finding_category, finding_severity, finding_text, remediation_owner, remediation_due, remediation_status, cost_estimate_rupees, evidence_gathered)
select id,'detection_gap','critical','SIEM missed MRI agent beaconing for 18 min','SOC Lead','2026-03-01'::date,'closed',850000,true from s where scenario_code='ransomware_mri' and drill_score=72
union all
select id,'response_delay','high','PACS isolation playbook not auto-triggered','IR Manager','2026-02-15'::date,'closed',420000,true from s where scenario_code='phishing_pacs' and drill_score=88
union all
select id,'tool_failure','critical','IoT pump segmentation policy bypassed','Biomed Dir','2026-04-30'::date,'in_progress',1250000,true from s where scenario_code='iot_pump_breach' and drill_score=65
union all
select id,'training_gap','medium','HR team unaware of insider exfil playbook','HR Sec','2026-05-15'::date,'closed',180000,true from s where scenario_code='insider_data_leak' and drill_score=82
union all
select id,'vendor_gap','high','Vendor patch SLA exceeded 30 days','Procurement','2026-06-01'::date,'in_progress',620000,false from s where scenario_code='vendor_supplychain' and drill_score=71
union all
select id,'comm_breakdown','low','War-room bridge had audio issues 4 min','IT Ops','2026-05-20'::date,'closed',45000,true from s where scenario_code='ddos_emr' and drill_score=90
union all
select id,'playbook_gap','critical','Firmware rollback procedure missing','CISO','2026-07-01'::date,'in_progress',980000,true from s where scenario_code='firmware_tamper' and drill_score=68
union all
select id,'detection_gap','low','MFA bypass attempt logged but not alerted','IAM Lead','2026-06-15'::date,'closed',95000,true from s where scenario_code='credential_stuff' and drill_score=93
union all
select id,'recovery_gap','high','Backup restore took 72 min vs 30 min target','Backup Admin','2026-08-01'::date,'open',540000,true from s where scenario_code='ransomware_mri' and drill_score=76
union all
select id,'training_gap','medium','New SOC analysts not trained on PACS isolation','SOC Mgr','2026-07-20'::date,'closed',220000,true from s where scenario_code='phishing_pacs' and drill_score=80
union all
select id,'response_delay','low','Containment doc was 2 versions old','IR Lead','2026-09-01'::date,'closed',35000,true from s where scenario_code='iot_pump_breach' and drill_score=84
union all
select id,'detection_gap','high','DLP rule missed PHI in DICOM tags','Data Sec','2026-10-15'::date,'in_progress',680000,false from s where scenario_code='insider_data_leak' and drill_score=70
union all
select id,'vendor_gap','medium','SBOM ingestion delayed','Vendor Mgmt','2026-10-30'::date,'closed',310000,true from s where scenario_code='vendor_supplychain' and drill_score=86
union all
select id,'tool_failure','high','DDoS scrubbing tier insufficient','NetOps','2026-11-15'::date,'open',1450000,true from s where scenario_code='ddos_emr' and drill_score=67
union all
select id,'comm_breakdown','medium','Founder paging chain stale','CISO Office','2026-12-01'::date,'in_progress',75000,false from s where scenario_code='firmware_tamper' and drill_score=89
union all
select id,'playbook_gap','medium','Legacy app credential rotation manual','IAM Lead','2026-12-15'::date,'blocked',420000,false from s where scenario_code='credential_stuff' and drill_score=78
union all
select id,'recovery_gap','high','MRI vendor key escrow not tested','Biomed','2027-01-30'::date,'open',780000,true from s where scenario_code='ransomware_mri' and drill_score=81
union all
select id,'training_gap','low','New IT staff onboarding lacks IR module','HR-IT','2027-02-15'::date,'open',150000,false from s where scenario_code='phishing_pacs' and drill_score=87;

-- ============================================================
-- RPCs
-- ============================================================

create or replace function founder_r2975_session_overview()
returns table (
  total_drills int,
  passed_drills int,
  failed_drills int,
  avg_score numeric,
  critical_tier int,
  high_tier int,
  total_affected int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where passed))::int,
    (count(*) filter (where not passed))::int,
    round(avg(drill_score)::numeric, 2),
    (count(*) filter (where severity_tier = 'tier_1_critical'))::int,
    (count(*) filter (where severity_tier = 'tier_2_high'))::int,
    coalesce(sum(affected_equipment_count),0)::int
  from hospital_chain_cyber_drill_sessions_r2975;
end $$;

create or replace function founder_r2975_quarter_breakdown()
returns table (
  quarter text,
  drills int,
  passed int,
  avg_score numeric,
  avg_rto_gap numeric,
  total_affected int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    drill_quarter,
    count(*)::int,
    (count(*) filter (where passed))::int,
    round(avg(drill_score)::numeric, 2),
    round(avg(rto_achieved_minutes - rto_target_minutes)::numeric, 2),
    coalesce(sum(affected_equipment_count),0)::int
  from hospital_chain_cyber_drill_sessions_r2975
  group by drill_quarter
  order by drill_quarter;
end $$;

create or replace function founder_r2975_scenario_performance()
returns table (
  scenario_code text,
  drills int,
  pass_rate_pct numeric,
  avg_score numeric,
  avg_mttd numeric,
  avg_mttr numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    s.scenario_code,
    count(*)::int,
    round(((count(*) filter (where s.passed))::numeric / nullif(count(*),0)) * 100, 2),
    round(avg(s.drill_score)::numeric, 2),
    round(avg(s.mttd_minutes)::numeric, 2),
    round(avg(s.mttr_minutes)::numeric, 2)
  from hospital_chain_cyber_drill_sessions_r2975 s
  group by s.scenario_code
  order by avg(s.drill_score) desc;
end $$;

create or replace function founder_r2975_chain_leaderboard()
returns table (
  chain_name text,
  drills int,
  passed int,
  avg_score numeric,
  total_affected int,
  rank_pos int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    chain_name,
    count(*)::int,
    (count(*) filter (where passed))::int,
    round(avg(drill_score)::numeric, 2),
    coalesce(sum(affected_equipment_count),0)::int,
    (row_number() over (order by avg(drill_score) desc))::int
  from hospital_chain_cyber_drill_sessions_r2975
  group by chain_name
  order by avg(drill_score) desc;
end $$;

create or replace function founder_r2975_findings_by_category()
returns table (
  finding_category text,
  total int,
  critical_count int,
  high_count int,
  open_count int,
  total_cost_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.finding_category,
    count(*)::int,
    (count(*) filter (where f.finding_severity='critical'))::int,
    (count(*) filter (where f.finding_severity='high'))::int,
    (count(*) filter (where f.remediation_status in ('open','in_progress','blocked')))::int,
    coalesce(sum(f.cost_estimate_rupees),0)::bigint
  from hospital_chain_cyber_drill_findings_r2975 f
  group by f.finding_category
  order by count(*) desc;
end $$;

create or replace function founder_r2975_open_critical_findings()
returns table (
  chain_name text,
  scenario_code text,
  finding_category text,
  finding_text text,
  remediation_owner text,
  remediation_due date,
  remediation_status text,
  cost_estimate_rupees int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    s.chain_name,
    s.scenario_code,
    f.finding_category,
    f.finding_text,
    f.remediation_owner,
    f.remediation_due,
    f.remediation_status,
    f.cost_estimate_rupees
  from hospital_chain_cyber_drill_findings_r2975 f
  join hospital_chain_cyber_drill_sessions_r2975 s on s.id = f.session_id
  where f.finding_severity in ('critical','high')
    and f.remediation_status in ('open','in_progress','blocked')
  order by f.remediation_due asc;
end $$;

create or replace function founder_r2975_rto_gap_outliers()
returns table (
  chain_name text,
  drill_quarter text,
  scenario_code text,
  rto_target_minutes int,
  rto_achieved_minutes int,
  gap_minutes int,
  drill_score int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    chain_name,
    drill_quarter,
    scenario_code,
    rto_target_minutes,
    rto_achieved_minutes,
    (rto_achieved_minutes - rto_target_minutes)::int as gap_minutes,
    drill_score
  from hospital_chain_cyber_drill_sessions_r2975
  where rto_achieved_minutes > rto_target_minutes
  order by (rto_achieved_minutes - rto_target_minutes) desc
  limit 20;
end $$;

create or replace function founder_r2975_remediation_burndown()
returns table (
  remediation_status text,
  count_findings int,
  total_cost_rupees bigint,
  critical_count int,
  evidence_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.remediation_status,
    count(*)::int,
    coalesce(sum(f.cost_estimate_rupees),0)::bigint,
    (count(*) filter (where f.finding_severity='critical'))::int,
    round(((count(*) filter (where f.evidence_gathered))::numeric / nullif(count(*),0)) * 100, 2)
  from hospital_chain_cyber_drill_findings_r2975 f
  group by f.remediation_status
  order by count(*) desc;
end $$;

-- ============================================================
-- GRANTS
-- ============================================================

revoke all on function founder_r2975_session_overview() from public, anon;
revoke all on function founder_r2975_quarter_breakdown() from public, anon;
revoke all on function founder_r2975_scenario_performance() from public, anon;
revoke all on function founder_r2975_chain_leaderboard() from public, anon;
revoke all on function founder_r2975_findings_by_category() from public, anon;
revoke all on function founder_r2975_open_critical_findings() from public, anon;
revoke all on function founder_r2975_rto_gap_outliers() from public, anon;
revoke all on function founder_r2975_remediation_burndown() from public, anon;

grant execute on function founder_r2975_session_overview() to authenticated;
grant execute on function founder_r2975_quarter_breakdown() to authenticated;
grant execute on function founder_r2975_scenario_performance() to authenticated;
grant execute on function founder_r2975_chain_leaderboard() to authenticated;
grant execute on function founder_r2975_findings_by_category() to authenticated;
grant execute on function founder_r2975_open_critical_findings() to authenticated;
grant execute on function founder_r2975_rto_gap_outliers() to authenticated;
grant execute on function founder_r2975_remediation_burndown() to authenticated;

commit;
