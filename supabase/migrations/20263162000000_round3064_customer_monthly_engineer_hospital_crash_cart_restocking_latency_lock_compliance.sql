-- Round r3064: Customer Monthly Engineer Hospital Crash-Cart Restocking Latency & Lock Compliance
-- Batch 440 milestone

create table if not exists crash_cart_restock_events_r3064 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_name text not null,
  cart_code text not null,
  ward text not null check (ward in ('icu','er','pediatrics','cardiac','general','ot')),
  engineer_name text not null,
  customer_org text not null,
  restock_month date not null,
  alert_at timestamptz not null,
  restocked_at timestamptz,
  latency_minutes int not null check (latency_minutes >= 0 and latency_minutes <= 1440),
  sla_target_minutes int not null check (sla_target_minutes >= 15 and sla_target_minutes <= 240),
  status text not null check (status in ('open','restocked','breached','escalated','cancelled'))
);

create table if not exists crash_cart_lock_audits_r3064 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_name text not null,
  cart_code text not null,
  audit_date date not null,
  lock_type text not null check (lock_type in ('numeric','rfid','biometric','tamper_seal','padlock')),
  compliance_score int not null check (compliance_score >= 0 and compliance_score <= 100),
  violations int not null check (violations >= 0 and violations <= 50),
  auditor text not null,
  result text not null check (result in ('pass','warn','fail','critical')),
  remediated_at timestamptz
);

alter table crash_cart_restock_events_r3064 enable row level security;
alter table crash_cart_lock_audits_r3064 enable row level security;

drop policy if exists r3064_restock_founder on crash_cart_restock_events_r3064;
create policy r3064_restock_founder on crash_cart_restock_events_r3064 for select using (is_founder());

drop policy if exists r3064_lock_founder on crash_cart_lock_audits_r3064;
create policy r3064_lock_founder on crash_cart_lock_audits_r3064 for select using (is_founder());

insert into crash_cart_restock_events_r3064 (hospital_name, cart_code, ward, engineer_name, customer_org, restock_month, alert_at, restocked_at, latency_minutes, sla_target_minutes, status) values
('Apollo Hyderabad','CC-A01','icu','Ravi Kumar','Apollo Group','2026-06-01'::date,'2026-06-02 09:00+05:30'::timestamptz,'2026-06-02 09:45+05:30'::timestamptz,45,60,'restocked'),
('Yashoda Secunderabad','CC-Y02','er','Sneha Reddy','Yashoda Hospitals','2026-06-01'::date,'2026-06-03 11:00+05:30'::timestamptz,'2026-06-03 12:30+05:30'::timestamptz,90,60,'breached'),
('KIMS Kondapur','CC-K03','cardiac','Arjun Patel','KIMS','2026-06-01'::date,'2026-06-04 14:00+05:30'::timestamptz,'2026-06-04 14:25+05:30'::timestamptz,25,45,'restocked'),
('Continental Gachibowli','CC-C04','pediatrics','Pooja Sharma','Continental','2026-06-01'::date,'2026-06-05 08:00+05:30'::timestamptz,'2026-06-05 09:10+05:30'::timestamptz,70,60,'breached'),
('Care Banjara','CC-CB5','general','Vikas Singh','Care Hospitals','2026-06-01'::date,'2026-06-06 10:00+05:30'::timestamptz,'2026-06-06 10:30+05:30'::timestamptz,30,60,'restocked'),
('Sunshine Paradise','CC-S06','ot','Anita Rao','Sunshine','2026-06-01'::date,'2026-06-07 13:00+05:30'::timestamptz,null::timestamptz,180,90,'escalated'),
('Rainbow Banjara','CC-R07','pediatrics','Karthik Nair','Rainbow','2026-06-01'::date,'2026-06-08 09:30+05:30'::timestamptz,'2026-06-08 10:15+05:30'::timestamptz,45,60,'restocked'),
('AIG Gachibowli','CC-AG8','icu','Ramesh Iyer','AIG','2026-06-01'::date,'2026-06-09 15:00+05:30'::timestamptz,'2026-06-09 16:00+05:30'::timestamptz,60,45,'breached'),
('Olive Sherlingampally','CC-O09','er','Divya Mishra','Olive','2026-06-01'::date,'2026-06-10 12:00+05:30'::timestamptz,'2026-06-10 12:20+05:30'::timestamptz,20,60,'restocked'),
('Star Begumpet','CC-ST10','cardiac','Suresh Babu','Star','2026-06-01'::date,'2026-06-11 11:00+05:30'::timestamptz,'2026-06-11 11:50+05:30'::timestamptz,50,60,'restocked'),
('MaxCure Madhapur','CC-MX11','general','Lakshmi Devi','MaxCure','2026-06-01'::date,'2026-06-12 10:00+05:30'::timestamptz,null::timestamptz,240,90,'open'),
('Apollo Hyderabad','CC-A12','er','Ravi Kumar','Apollo Group','2026-06-01'::date,'2026-06-13 08:00+05:30'::timestamptz,'2026-06-13 08:35+05:30'::timestamptz,35,45,'restocked'),
('Yashoda Secunderabad','CC-Y13','icu','Sneha Reddy','Yashoda Hospitals','2026-06-01'::date,'2026-06-14 14:00+05:30'::timestamptz,'2026-06-14 15:30+05:30'::timestamptz,90,60,'breached'),
('KIMS Kondapur','CC-K14','ot','Arjun Patel','KIMS','2026-06-01'::date,'2026-06-15 09:00+05:30'::timestamptz,'2026-06-15 09:20+05:30'::timestamptz,20,60,'restocked'),
('Continental Gachibowli','CC-C15','general','Pooja Sharma','Continental','2026-06-01'::date,'2026-06-16 11:00+05:30'::timestamptz,'2026-06-16 12:10+05:30'::timestamptz,70,60,'breached'),
('Care Banjara','CC-CB6','icu','Vikas Singh','Care Hospitals','2026-06-01'::date,'2026-06-17 13:00+05:30'::timestamptz,null::timestamptz,0,60,'cancelled'),
('Sunshine Paradise','CC-S17','cardiac','Anita Rao','Sunshine','2026-06-01'::date,'2026-06-18 10:00+05:30'::timestamptz,'2026-06-18 10:55+05:30'::timestamptz,55,60,'restocked'),
('Rainbow Banjara','CC-R18','pediatrics','Karthik Nair','Rainbow','2026-06-01'::date,'2026-06-19 12:00+05:30'::timestamptz,'2026-06-19 13:30+05:30'::timestamptz,90,60,'breached');

insert into crash_cart_lock_audits_r3064 (hospital_name, cart_code, audit_date, lock_type, compliance_score, violations, auditor, result, remediated_at) values
('Apollo Hyderabad','CC-A01','2026-06-05'::date,'rfid',95,0,'Founder QA','pass','2026-06-05 18:00+05:30'::timestamptz),
('Yashoda Secunderabad','CC-Y02','2026-06-05'::date,'numeric',60,4,'Founder QA','fail',null::timestamptz),
('KIMS Kondapur','CC-K03','2026-06-06'::date,'biometric',88,1,'Internal Audit','warn','2026-06-07 11:00+05:30'::timestamptz),
('Continental Gachibowli','CC-C04','2026-06-06'::date,'tamper_seal',45,8,'Founder QA','critical',null::timestamptz),
('Care Banjara','CC-CB5','2026-06-07'::date,'rfid',92,0,'Internal Audit','pass','2026-06-07 16:00+05:30'::timestamptz),
('Sunshine Paradise','CC-S06','2026-06-08'::date,'padlock',30,12,'Founder QA','critical',null::timestamptz),
('Rainbow Banjara','CC-R07','2026-06-08'::date,'biometric',98,0,'Internal Audit','pass','2026-06-08 17:00+05:30'::timestamptz),
('AIG Gachibowli','CC-AG8','2026-06-09'::date,'rfid',75,2,'Founder QA','warn','2026-06-10 09:00+05:30'::timestamptz),
('Olive Sherlingampally','CC-O09','2026-06-10'::date,'numeric',55,5,'Internal Audit','fail',null::timestamptz),
('Star Begumpet','CC-ST10','2026-06-10'::date,'biometric',90,0,'Founder QA','pass','2026-06-10 19:00+05:30'::timestamptz),
('MaxCure Madhapur','CC-MX11','2026-06-11'::date,'tamper_seal',40,9,'Founder QA','critical',null::timestamptz),
('Apollo Hyderabad','CC-A12','2026-06-12'::date,'rfid',97,0,'Internal Audit','pass','2026-06-12 15:00+05:30'::timestamptz),
('Yashoda Secunderabad','CC-Y13','2026-06-12'::date,'numeric',65,3,'Founder QA','warn','2026-06-13 10:00+05:30'::timestamptz),
('KIMS Kondapur','CC-K14','2026-06-13'::date,'biometric',93,0,'Internal Audit','pass','2026-06-13 16:00+05:30'::timestamptz),
('Continental Gachibowli','CC-C15','2026-06-13'::date,'tamper_seal',50,6,'Founder QA','fail',null::timestamptz),
('Care Banjara','CC-CB6','2026-06-14'::date,'rfid',85,1,'Internal Audit','warn','2026-06-15 10:00+05:30'::timestamptz),
('Sunshine Paradise','CC-S17','2026-06-14'::date,'padlock',35,10,'Founder QA','critical',null::timestamptz),
('Rainbow Banjara','CC-R18','2026-06-15'::date,'biometric',91,0,'Internal Audit','pass','2026-06-15 17:00+05:30'::timestamptz);

create or replace function r3064_restock_summary()
returns table(total_events int, restocked int, breached int, escalated int, open_count int, avg_latency_min numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select
    count(*)::int,
    (count(*) filter (where status='restocked'))::int,
    (count(*) filter (where status='breached'))::int,
    (count(*) filter (where status='escalated'))::int,
    (count(*) filter (where status='open'))::int,
    round(avg(latency_minutes)::numeric,2)
  from crash_cart_restock_events_r3064;
end; $$;

create or replace function r3064_latency_by_hospital()
returns table(hospital_name text, events int, avg_latency numeric, breaches int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select e.hospital_name,
    count(*)::int,
    round(avg(e.latency_minutes)::numeric,2),
    (count(*) filter (where e.status='breached'))::int
  from crash_cart_restock_events_r3064 e
  group by e.hospital_name
  order by avg(e.latency_minutes) desc;
end; $$;

create or replace function r3064_latency_by_ward()
returns table(ward text, events int, avg_latency numeric, breach_rate numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select e.ward,
    count(*)::int,
    round(avg(e.latency_minutes)::numeric,2),
    round(((count(*) filter (where e.status='breached'))::numeric / nullif(count(*),0))*100,2)
  from crash_cart_restock_events_r3064 e
  group by e.ward
  order by e.ward;
end; $$;

create or replace function r3064_engineer_performance()
returns table(engineer_name text, events int, avg_latency numeric, on_time int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select e.engineer_name,
    count(*)::int,
    round(avg(e.latency_minutes)::numeric,2),
    (count(*) filter (where e.latency_minutes <= e.sla_target_minutes))::int
  from crash_cart_restock_events_r3064 e
  group by e.engineer_name
  order by avg(e.latency_minutes) asc;
end; $$;

create or replace function r3064_lock_compliance_summary()
returns table(total_audits int, passed int, warned int, failed int, critical_count int, avg_score numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select
    count(*)::int,
    (count(*) filter (where result='pass'))::int,
    (count(*) filter (where result='warn'))::int,
    (count(*) filter (where result='fail'))::int,
    (count(*) filter (where result='critical'))::int,
    round(avg(compliance_score)::numeric,2)
  from crash_cart_lock_audits_r3064;
end; $$;

create or replace function r3064_lock_by_type()
returns table(lock_type text, audits int, avg_score numeric, total_violations int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.lock_type,
    count(*)::int,
    round(avg(a.compliance_score)::numeric,2),
    sum(a.violations)::int
  from crash_cart_lock_audits_r3064 a
  group by a.lock_type
  order by avg(a.compliance_score) asc;
end; $$;

create or replace function r3064_critical_alerts()
returns table(hospital_name text, cart_code text, lock_type text, compliance_score int, violations int, audit_date date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.hospital_name, a.cart_code, a.lock_type, a.compliance_score, a.violations, a.audit_date
  from crash_cart_lock_audits_r3064 a
  where a.result in ('critical','fail') and a.remediated_at is null
  order by a.compliance_score asc;
end; $$;

revoke all on function r3064_restock_summary() from public, anon;
revoke all on function r3064_latency_by_hospital() from public, anon;
revoke all on function r3064_latency_by_ward() from public, anon;
revoke all on function r3064_engineer_performance() from public, anon;
revoke all on function r3064_lock_compliance_summary() from public, anon;
revoke all on function r3064_lock_by_type() from public, anon;
revoke all on function r3064_critical_alerts() from public, anon;

grant execute on function r3064_restock_summary() to authenticated;
grant execute on function r3064_latency_by_hospital() to authenticated;
grant execute on function r3064_latency_by_ward() to authenticated;
grant execute on function r3064_engineer_performance() to authenticated;
grant execute on function r3064_lock_compliance_summary() to authenticated;
grant execute on function r3064_lock_by_type() to authenticated;
grant execute on function r3064_critical_alerts() to authenticated;
