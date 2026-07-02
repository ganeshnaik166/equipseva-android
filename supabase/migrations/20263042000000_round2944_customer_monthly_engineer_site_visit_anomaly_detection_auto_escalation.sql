-- Round 2944: Customer Monthly Engineer Site-Visit Anomaly Detection & Auto-Escalation
-- HEAVY ★★★★

create table if not exists customer_visit_anomaly_signals_r2944 (
  id uuid primary key default gen_random_uuid(),
  customer_org_name text not null,
  engineer_name text not null,
  visit_month date not null,
  expected_visits int not null check (expected_visits between 0 and 30),
  actual_visits int not null check (actual_visits between 0 and 30),
  anomaly_score numeric(5,2) not null check (anomaly_score between 0 and 100),
  anomaly_type text not null check (anomaly_type in ('no_show','under_visit','over_visit','duration_short','gps_mismatch','signature_missing','duplicate_log')),
  severity text not null check (severity in ('low','medium','high','critical')),
  detected_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists customer_visit_anomaly_escalations_r2944 (
  id uuid primary key default gen_random_uuid(),
  signal_id uuid references customer_visit_anomaly_signals_r2944(id) on delete cascade,
  escalation_tier text not null check (escalation_tier in ('tier_1_engineer','tier_2_supervisor','tier_3_regional','tier_4_founder')),
  status text not null check (status in ('open','acknowledged','investigating','resolved','dismissed')),
  assigned_to text not null,
  opened_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution_notes text,
  customer_credit_rupees int default 0 check (customer_credit_rupees >= 0),
  created_at timestamptz not null default now()
);

alter table customer_visit_anomaly_signals_r2944 enable row level security;
alter table customer_visit_anomaly_escalations_r2944 enable row level security;

-- Seeds
insert into customer_visit_anomaly_signals_r2944 (customer_org_name, engineer_name, visit_month, expected_visits, actual_visits, anomaly_score, anomaly_type, severity, notes) values
('Apollo Hyderabad','Ramesh K','2026-05-01'::date,4,1,82.50,'no_show','critical','3 missed visits in May'),
('Yashoda Secunderabad','Suresh P','2026-05-01'::date,4,2,68.00,'under_visit','high','Half coverage'),
('KIMS Kondapur','Mahesh R','2026-05-01'::date,2,0,95.00,'no_show','critical','Zero visits logged'),
('Continental Gachibowli','Naresh M','2026-05-01'::date,4,4,15.20,'duration_short','low','Avg duration 18 min'),
('Sunshine Begumpet','Ganesh V','2026-05-01'::date,2,3,42.00,'over_visit','medium','One extra unexplained'),
('Care Banjara','Dinesh T','2026-05-01'::date,4,3,55.50,'gps_mismatch','medium','One visit GPS 8km off'),
('Rainbow LB Nagar','Lokesh S','2026-05-01'::date,2,2,38.00,'signature_missing','medium','Both missing biosignature'),
('Krishna Institute','Hitesh B','2026-05-01'::date,4,1,78.00,'no_show','high','3 no-shows confirmed'),
('Star Hospitals','Jitesh N','2026-05-01'::date,2,2,72.00,'duplicate_log','high','Same checklist twice'),
('AIG Hospitals','Mukesh L','2026-05-01'::date,4,2,61.00,'under_visit','high','Customer complained'),
('Citizens Specialty','Rakesh D','2026-05-01'::date,2,1,58.00,'no_show','medium','One missed'),
('Olive Sherlin','Brijesh A','2026-05-01'::date,4,4,28.00,'duration_short','low','Avg 22 min'),
('Pinnacle Heart','Yogesh C','2026-05-01'::date,2,3,45.00,'over_visit','medium','Suspicious extra'),
('Medicover','Pritesh E','2026-05-01'::date,4,2,65.00,'gps_mismatch','high','2 visits geofence fail'),
('Care Outpatient','Hardik F','2026-05-01'::date,2,0,98.00,'no_show','critical','Zero engagement'),
('Asian Institute','Karthik G','2026-05-01'::date,4,3,48.00,'signature_missing','medium','Audit fail'),
('Global Hospitals','Sandeep H','2026-05-01'::date,4,4,32.00,'duration_short','low','Borderline'),
('Magna Centre','Pradeep I','2026-05-01'::date,2,2,75.00,'duplicate_log','high','Two duplicates'),
('Tulasi Hospital','Sudeep J','2026-05-01'::date,4,1,80.00,'no_show','critical','Engineer absent');

insert into customer_visit_anomaly_escalations_r2944 (signal_id, escalation_tier, status, assigned_to, resolved_at, resolution_notes, customer_credit_rupees) values
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Apollo Hyderabad'),'tier_4_founder','investigating','founder@equipseva.in',null,'Reviewing engineer assignment',12000),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Yashoda Secunderabad'),'tier_3_regional','open','regional.south@equipseva.in',null,null,6000),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='KIMS Kondapur'),'tier_4_founder','acknowledged','founder@equipseva.in',null,'Emergency re-assign',15000),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Continental Gachibowli'),'tier_1_engineer','resolved','ramesh@equipseva.in','2026-05-25 10:00'::timestamptz,'Duration coached',0),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Sunshine Begumpet'),'tier_2_supervisor','dismissed','supervisor1@equipseva.in','2026-05-26 11:00'::timestamptz,'Legitimate emergency call',0),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Care Banjara'),'tier_2_supervisor','investigating','supervisor2@equipseva.in',null,null,3000),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Rainbow LB Nagar'),'tier_2_supervisor','open','supervisor3@equipseva.in',null,null,2000),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Krishna Institute'),'tier_3_regional','investigating','regional.south@equipseva.in',null,'Pattern detected',8000),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Star Hospitals'),'tier_3_regional','open','regional.south@equipseva.in',null,null,4000),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='AIG Hospitals'),'tier_3_regional','acknowledged','regional.south@equipseva.in',null,'Customer NPS dip',7500),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Citizens Specialty'),'tier_2_supervisor','resolved','supervisor1@equipseva.in','2026-05-28 14:00'::timestamptz,'Made up visit',2500),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Olive Sherlin'),'tier_1_engineer','resolved','brijesh@equipseva.in','2026-05-27 09:00'::timestamptz,'Self-corrected',0),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Pinnacle Heart'),'tier_2_supervisor','investigating','supervisor2@equipseva.in',null,null,1500),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Medicover'),'tier_3_regional','open','regional.south@equipseva.in',null,null,5500),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Care Outpatient'),'tier_4_founder','investigating','founder@equipseva.in',null,'Account at risk',18000),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Asian Institute'),'tier_2_supervisor','open','supervisor3@equipseva.in',null,null,2200),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Global Hospitals'),'tier_1_engineer','dismissed','sandeep@equipseva.in','2026-05-29 12:00'::timestamptz,'Within tolerance',0),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Magna Centre'),'tier_3_regional','acknowledged','regional.south@equipseva.in',null,'Tampering suspected',6500),
((select id from customer_visit_anomaly_signals_r2944 where customer_org_name='Tulasi Hospital'),'tier_4_founder','open','founder@equipseva.in',null,null,14000);

-- is_founder gate (assume exists in project)
create or replace function is_founder_r2944() returns boolean
LANGUAGE plpgsql stable security definer set search_path = public, pg_temp as $$
BEGIN
  RETURN is_founder();
END;
$$;

-- RPC 1: top anomalies
create or replace function r2944_top_anomalies()
returns table(customer_org_name text, engineer_name text, anomaly_type text, severity text, anomaly_score numeric, actual_visits int, expected_visits int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder_r2944() then raise exception 'forbidden'; end if;
  return query select s.customer_org_name, s.engineer_name, s.anomaly_type, s.severity, s.anomaly_score, s.actual_visits, s.expected_visits
    from customer_visit_anomaly_signals_r2944 s order by s.anomaly_score desc limit 15;
end; $$;

-- RPC 2: severity rollup
create or replace function r2944_severity_rollup()
returns table(severity text, signal_count int, avg_score numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder_r2944() then raise exception 'forbidden'; end if;
  return query select s.severity, count(*)::int, round(avg(s.anomaly_score),2)
    from customer_visit_anomaly_signals_r2944 s group by s.severity order by avg(s.anomaly_score) desc;
end; $$;

-- RPC 3: anomaly type breakdown
create or replace function r2944_anomaly_type_breakdown()
returns table(anomaly_type text, total int, critical_count int, high_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder_r2944() then raise exception 'forbidden'; end if;
  return query select s.anomaly_type, count(*)::int,
    (count(*) filter (where s.severity='critical'))::int,
    (count(*) filter (where s.severity='high'))::int
    from customer_visit_anomaly_signals_r2944 s group by s.anomaly_type order by count(*) desc;
end; $$;

-- RPC 4: engineer offender ranking
create or replace function r2944_engineer_offenders()
returns table(engineer_name text, signal_count int, avg_score numeric, critical_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder_r2944() then raise exception 'forbidden'; end if;
  return query select s.engineer_name, count(*)::int, round(avg(s.anomaly_score),2),
    (count(*) filter (where s.severity='critical'))::int
    from customer_visit_anomaly_signals_r2944 s group by s.engineer_name order by avg(s.anomaly_score) desc;
end; $$;

-- RPC 5: open escalations
create or replace function r2944_open_escalations()
returns table(customer_org_name text, engineer_name text, escalation_tier text, status text, assigned_to text, credit_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder_r2944() then raise exception 'forbidden'; end if;
  return query select s.customer_org_name, s.engineer_name, e.escalation_tier, e.status, e.assigned_to, e.customer_credit_rupees
    from customer_visit_anomaly_escalations_r2944 e
    join customer_visit_anomaly_signals_r2944 s on s.id = e.signal_id
    where e.status in ('open','acknowledged','investigating')
    order by e.customer_credit_rupees desc;
end; $$;

-- RPC 6: tier rollup
create or replace function r2944_tier_rollup()
returns table(escalation_tier text, open_count int, resolved_count int, total_credit int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder_r2944() then raise exception 'forbidden'; end if;
  return query select e.escalation_tier,
    (count(*) filter (where e.status in ('open','acknowledged','investigating')))::int,
    (count(*) filter (where e.status='resolved'))::int,
    coalesce(sum(e.customer_credit_rupees),0)::int
    from customer_visit_anomaly_escalations_r2944 e group by e.escalation_tier order by e.escalation_tier;
end; $$;

-- RPC 7: founder dollar exposure
create or replace function r2944_founder_exposure()
returns table(metric text, value text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder_r2944() then raise exception 'forbidden'; end if;
  return query
    select 'Total Signals'::text, count(*)::text from customer_visit_anomaly_signals_r2944
    union all select 'Critical Signals', (count(*) filter (where severity='critical'))::text from customer_visit_anomaly_signals_r2944
    union all select 'Open Escalations', (count(*) filter (where status in ('open','acknowledged','investigating')))::text from customer_visit_anomaly_escalations_r2944
    union all select 'Total Credit Exposure (INR)', coalesce(sum(customer_credit_rupees),0)::text from customer_visit_anomaly_escalations_r2944
    union all select 'Founder-Tier Escalations', (count(*) filter (where escalation_tier='tier_4_founder'))::text from customer_visit_anomaly_escalations_r2944
    union all select 'Resolved Rate %', round((count(*) filter (where status='resolved'))::numeric * 100 / nullif(count(*),0), 1)::text from customer_visit_anomaly_escalations_r2944;
end; $$;

revoke all on function r2944_top_anomalies() from public, anon;
revoke all on function r2944_severity_rollup() from public, anon;
revoke all on function r2944_anomaly_type_breakdown() from public, anon;
revoke all on function r2944_engineer_offenders() from public, anon;
revoke all on function r2944_open_escalations() from public, anon;
revoke all on function r2944_tier_rollup() from public, anon;
revoke all on function r2944_founder_exposure() from public, anon;

grant execute on function r2944_top_anomalies() to authenticated;
grant execute on function r2944_severity_rollup() to authenticated;
grant execute on function r2944_anomaly_type_breakdown() to authenticated;
grant execute on function r2944_engineer_offenders() to authenticated;
grant execute on function r2944_open_escalations() to authenticated;
grant execute on function r2944_tier_rollup() to authenticated;
grant execute on function r2944_founder_exposure() to authenticated;
