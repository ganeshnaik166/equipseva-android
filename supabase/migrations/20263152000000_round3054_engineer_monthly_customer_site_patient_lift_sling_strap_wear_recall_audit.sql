-- Round 3054 — Engineer Monthly Customer Site Patient-Lift Sling Strap Wear & Recall Audit
-- Founder-only console for tracking sling-strap inspections, wear scoring, and recall actions

create table if not exists patient_lift_sling_audits_r3054 (
  id uuid primary key default gen_random_uuid(),
  audit_month date not null,
  customer_site_name text not null,
  customer_city text not null,
  engineer_name text not null,
  lift_model text not null,
  sling_serial text not null,
  sling_type text not null check (sling_type in ('full_body','toileting','standing','amputee','pediatric','bariatric')),
  wear_score int not null check (wear_score between 0 and 100),
  wear_grade text not null check (wear_grade in ('pristine','light','moderate','heavy','condemn')),
  strap_load_test_kg numeric(7,2),
  fail_load_threshold_kg numeric(7,2) not null,
  visible_fray boolean not null default false,
  stitch_integrity_pct int check (stitch_integrity_pct between 0 and 100),
  buckle_corrosion text not null check (buckle_corrosion in ('none','surface','pitting','severe')),
  recall_flag boolean not null default false,
  recall_batch_code text,
  action_taken text not null check (action_taken in ('passed','retire_immediate','rotate_quarantine','vendor_warranty','order_replacement','no_action')),
  audit_status text not null check (audit_status in ('clean','watch','warning','urgent','escalated')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists sling_recall_actions_r3054 (
  id uuid primary key default gen_random_uuid(),
  recall_batch_code text not null,
  vendor_name text not null,
  vendor_region text not null check (vendor_region in ('south','north','west','east','imported')),
  issued_on date not null,
  closed_on date,
  total_units_affected int not null,
  units_recovered int not null default 0,
  units_replaced int not null default 0,
  units_outstanding int not null,
  severity text not null check (severity in ('advisory','voluntary','mandatory','urgent_field_action')),
  action_status text not null check (action_status in ('open','in_progress','blocked','closed','dropped')),
  cost_per_unit_rupees numeric(10,2) not null,
  refund_received_rupees numeric(12,2) not null default 0,
  cdsco_notified boolean not null default false,
  customer_notified_count int not null default 0,
  created_at timestamptz not null default now()
);

alter table patient_lift_sling_audits_r3054 enable row level security;
alter table sling_recall_actions_r3054 enable row level security;

drop policy if exists founder_select_psa_r3054 on patient_lift_sling_audits_r3054;
create policy founder_select_psa_r3054 on patient_lift_sling_audits_r3054 for select using (is_founder());

drop policy if exists founder_select_sra_r3054 on sling_recall_actions_r3054;
create policy founder_select_sra_r3054 on sling_recall_actions_r3054 for select using (is_founder());

revoke all on patient_lift_sling_audits_r3054 from public, anon;
revoke all on sling_recall_actions_r3054 from public, anon;
grant select on patient_lift_sling_audits_r3054 to authenticated;
grant select on sling_recall_actions_r3054 to authenticated;

insert into patient_lift_sling_audits_r3054 (audit_month, customer_site_name, customer_city, engineer_name, lift_model, sling_serial, sling_type, wear_score, wear_grade, strap_load_test_kg, fail_load_threshold_kg, visible_fray, stitch_integrity_pct, buckle_corrosion, recall_flag, recall_batch_code, action_taken, audit_status, notes) values
('2026-06-01'::date,'Apollo Jubilee Hills','Hyderabad','Ravi Kumar','Arjo Maxi Sky 600','SL-AJ-0012','full_body',12,'pristine',310.5,250.0,false,98,'none',false,null,'passed','clean','New sling, 2 months in service'),
('2026-06-01'::date,'Yashoda Secunderabad','Hyderabad','Suresh Reddy','Hill-Rom Liko Golvo','SL-YS-0034','toileting',38,'light',285.0,200.0,false,92,'surface',false,null,'passed','clean','Minor surface corrosion on buckle'),
('2026-06-01'::date,'KIMS Kondapur','Hyderabad','Lakshmi Devi','Invacare Reliant 450','SL-KK-0078','standing',58,'moderate',225.0,200.0,true,84,'surface',false,null,'rotate_quarantine','watch','Fray edge spotted, rotated to backup pool'),
('2026-06-01'::date,'Continental Nallagandla','Hyderabad','Pradeep Kumar','Arjo Sara Plus','SL-CN-0101','full_body',82,'heavy',195.0,200.0,true,62,'pitting',true,'BATCH-RECALL-SEED','retire_immediate','urgent','Below load threshold, retired on-site'),
('2026-06-01'::date,'AIG Gachibowli','Hyderabad','Anil Reddy','Liko Viking XL','SL-AG-0145','bariatric',45,'moderate',420.0,350.0,false,88,'none',false,null,'passed','clean','Bariatric sling, monthly cycle baseline'),
('2026-06-01'::date,'Care Banjara','Hyderabad','Mahesh Babu','Invacare Birdie','SL-CB-0188','pediatric',22,'light',95.0,75.0,false,96,'none',false,null,'passed','clean','Pediatric unit, low usage ward'),
('2026-06-01'::date,'Sunshine Paradise','Hyderabad','Ramesh Reddy','Arjo Maxi Sky 2','SL-SP-0221','full_body',91,'condemn',null,250.0,true,38,'severe',true,'BATCH-LMK-2025-Q4','retire_immediate','escalated','Recall batch unit, severe wear'),
('2026-06-01'::date,'Rainbow Banjara','Hyderabad','Sunil Kumar','Hill-Rom Liko M220','SL-RB-0244','pediatric',31,'light',88.0,75.0,false,94,'none',false,null,'passed','clean','Children ward sling'),
('2026-06-01'::date,'Olive Hospital','Hyderabad','Vijay Kumar','Invacare Reliant 350','SL-OH-0265','standing',67,'moderate',210.0,200.0,true,72,'surface',false,null,'rotate_quarantine','warning','Stitch integrity dropping fast'),
('2026-06-01'::date,'Maxcure Madhapur','Hyderabad','Krishna Reddy','Arjo Sara 3000','SL-MM-0289','amputee',54,'moderate',180.0,150.0,false,80,'pitting',false,null,'vendor_warranty','watch','Vendor warranty claim filed'),
('2026-05-01'::date,'Apollo Jubilee Hills','Hyderabad','Ravi Kumar','Arjo Maxi Sky 600','SL-AJ-0011','full_body',88,'condemn',180.0,250.0,true,42,'severe',true,'BATCH-LMK-2025-Q4','retire_immediate','escalated','First recall match in fleet'),
('2026-05-01'::date,'Yashoda Secunderabad','Hyderabad','Suresh Reddy','Hill-Rom Liko Golvo','SL-YS-0033','toileting',73,'heavy',195.0,200.0,true,58,'pitting',false,null,'order_replacement','urgent','Ordered replacement, gap covered'),
('2026-05-01'::date,'Continental Nallagandla','Hyderabad','Pradeep Kumar','Arjo Sara Plus','SL-CN-0099','full_body',49,'moderate',240.0,200.0,false,86,'surface',false,null,'passed','clean','Within tolerance'),
('2026-05-01'::date,'AIG Gachibowli','Hyderabad','Anil Reddy','Liko Viking XL','SL-AG-0144','bariatric',62,'heavy',380.0,350.0,true,70,'pitting',false,null,'rotate_quarantine','warning','Bariatric edge fray, rotated'),
('2026-04-01'::date,'KIMS Kondapur','Hyderabad','Lakshmi Devi','Invacare Reliant 450','SL-KK-0077','standing',95,'condemn',null,200.0,true,28,'severe',true,'BATCH-INV-2025-Q3','retire_immediate','escalated','Third recall batch unit'),
('2026-04-01'::date,'Sunshine Paradise','Hyderabad','Ramesh Reddy','Arjo Maxi Sky 2','SL-SP-0220','full_body',41,'moderate',260.0,250.0,false,84,'surface',false,null,'passed','watch','Borderline pass'),
('2026-06-01'::date,'Star Banjara','Hyderabad','Naresh Kumar','Hill-Rom Liko M230','SL-SB-0301','amputee',28,'light',165.0,150.0,false,90,'none',false,null,'passed','clean','New deployment'),
('2026-06-01'::date,'Pace Hospitals','Hyderabad','Murali Mohan','Invacare Birdie Compact','SL-PH-0322','toileting',76,'heavy',180.0,200.0,true,55,'severe',false,null,'retire_immediate','urgent','Failed load test, retired'),
('2026-06-01'::date,'Citizens Specialty','Hyderabad','Bhaskar Rao','Arjo Maxi Move','SL-CS-0345','full_body',18,'pristine',305.0,250.0,false,97,'none',false,null,'passed','clean','New install Q2'),
('2026-06-01'::date,'Medicover Hi-Tech','Hyderabad','Srinivas Rao','Liko Viking M','SL-MH-0367','standing',52,'moderate',215.0,200.0,false,82,'surface',false,null,'passed','clean','Routine clean pass');

insert into sling_recall_actions_r3054 (recall_batch_code, vendor_name, vendor_region, issued_on, closed_on, total_units_affected, units_recovered, units_replaced, units_outstanding, severity, action_status, cost_per_unit_rupees, refund_received_rupees, cdsco_notified, customer_notified_count) values
('BATCH-LMK-2025-Q4','Lakshmi Medical Karnataka','south','2025-12-15'::date,null,42,28,24,14,'mandatory','in_progress',8500.00,204000.00,true,38),
('BATCH-INV-2025-Q3','Invacare India','imported','2025-09-20'::date,'2026-03-15'::date,18,18,18,0,'urgent_field_action','closed',12500.00,225000.00,true,18),
('BATCH-ARJ-2026-Q1','Arjo India','imported','2026-02-10'::date,null,67,41,35,26,'mandatory','in_progress',15000.00,525000.00,true,62),
('BATCH-HR-2025-Q4','Hill-Rom Liko APAC','imported','2025-11-05'::date,'2026-04-22'::date,24,24,22,0,'voluntary','closed',11000.00,242000.00,false,24),
('BATCH-MED-2026-Q1','Medline Industries','imported','2026-01-18'::date,null,33,19,15,14,'mandatory','blocked',7800.00,117000.00,true,30),
('BATCH-PRM-2025-Q3','Prism Healthcare','south','2025-08-30'::date,'2026-02-10'::date,15,15,14,0,'advisory','closed',5500.00,77000.00,false,15),
('BATCH-GUL-2026-Q2','Gulmohar Medilife','west','2026-05-12'::date,null,52,8,5,44,'urgent_field_action','open',9200.00,46000.00,true,48),
('BATCH-SPC-2025-Q4','Spectrum Surgicals','north','2025-10-25'::date,null,29,21,18,8,'mandatory','in_progress',6700.00,120600.00,true,26),
('BATCH-NOV-2026-Q1','Novacare Medequip','south','2026-03-08'::date,null,38,12,9,26,'urgent_field_action','open',10200.00,91800.00,true,34),
('BATCH-TRU-2025-Q2','Trumpf Medical India','imported','2025-06-15'::date,'2025-12-20'::date,21,21,20,0,'voluntary','closed',8800.00,176000.00,false,21),
('BATCH-DLF-2024-Q4','Delphi Lifesciences','north','2024-12-01'::date,'2025-08-15'::date,12,11,10,1,'advisory','dropped',4500.00,49500.00,false,11),
('BATCH-RKS-2026-Q1','Rakshana Surgicals','south','2026-01-30'::date,null,45,17,14,28,'mandatory','blocked',7100.00,99400.00,true,40),
('BATCH-VTL-2025-Q4','Vitality Medequip','west','2025-11-20'::date,null,27,9,7,18,'urgent_field_action','open',12800.00,89600.00,true,24),
('BATCH-ORN-2026-Q2','Ornate Medical','east','2026-04-18'::date,null,19,3,2,16,'voluntary','open',6300.00,12600.00,false,17);

create or replace function r3054_overview()
returns table(metric text, value text) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select 'total_audits'::text, count(*)::text from patient_lift_sling_audits_r3054
    union all
    select 'urgent_or_escalated'::text, (count(*) filter (where audit_status in ('urgent','escalated')))::text from patient_lift_sling_audits_r3054
    union all
    select 'condemned_slings'::text, (count(*) filter (where wear_grade = 'condemn'))::text from patient_lift_sling_audits_r3054
    union all
    select 'open_recall_batches'::text, (count(*) filter (where action_status in ('open','in_progress','blocked')))::text from sling_recall_actions_r3054
    union all
    select 'outstanding_units'::text, coalesce(sum(units_outstanding),0)::text from sling_recall_actions_r3054
    union all
    select 'refund_total_rupees'::text, coalesce(sum(refund_received_rupees),0)::text from sling_recall_actions_r3054;
end; $$;

create or replace function r3054_wear_grade_distribution()
returns table(wear_grade text, audits int, avg_wear_score numeric, condemn_share_pct numeric) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.wear_grade, count(*)::int, round(avg(a.wear_score)::numeric,1),
           round(100.0 * (count(*) filter (where a.wear_grade='condemn'))::numeric / nullif(count(*),0), 1)
    from patient_lift_sling_audits_r3054 a
    group by a.wear_grade
    order by avg(a.wear_score) desc;
end; $$;

create or replace function r3054_site_risk_ranking()
returns table(customer_site_name text, audits int, urgent_count int, condemn_count int, recall_hits int) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.customer_site_name, count(*)::int,
           (count(*) filter (where a.audit_status in ('urgent','escalated')))::int,
           (count(*) filter (where a.wear_grade = 'condemn'))::int,
           (count(*) filter (where a.recall_flag = true))::int
    from patient_lift_sling_audits_r3054 a
    group by a.customer_site_name
    order by (count(*) filter (where a.audit_status in ('urgent','escalated'))) desc, count(*) desc;
end; $$;

create or replace function r3054_engineer_audit_throughput()
returns table(engineer_name text, audits int, urgent_share_pct numeric, avg_wear_score numeric) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.engineer_name, count(*)::int,
           round(100.0 * (count(*) filter (where a.audit_status in ('urgent','escalated')))::numeric / nullif(count(*),0), 1),
           round(avg(a.wear_score)::numeric,1)
    from patient_lift_sling_audits_r3054 a
    group by a.engineer_name
    order by count(*) desc;
end; $$;

create or replace function r3054_recall_batch_progress()
returns table(recall_batch_code text, vendor_name text, severity text, action_status text, total_units_affected int, units_outstanding int, recovery_pct numeric) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.recall_batch_code, s.vendor_name, s.severity, s.action_status,
           s.total_units_affected, s.units_outstanding,
           round(100.0 * s.units_recovered::numeric / nullif(s.total_units_affected,0), 1)
    from sling_recall_actions_r3054 s
    order by s.units_outstanding desc;
end; $$;

create or replace function r3054_monthly_trend()
returns table(audit_month date, audits int, urgent_count int, condemn_count int, avg_wear_score numeric) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.audit_month, count(*)::int,
           (count(*) filter (where a.audit_status in ('urgent','escalated')))::int,
           (count(*) filter (where a.wear_grade = 'condemn'))::int,
           round(avg(a.wear_score)::numeric,1)
    from patient_lift_sling_audits_r3054 a
    group by a.audit_month
    order by a.audit_month desc;
end; $$;

create or replace function r3054_action_taken_breakdown()
returns table(action_taken text, audits int, urgent_count int, share_pct numeric) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.action_taken, count(*)::int,
           (count(*) filter (where a.audit_status in ('urgent','escalated')))::int,
           round(100.0 * count(*)::numeric / nullif((select count(*) from patient_lift_sling_audits_r3054),0), 1)
    from patient_lift_sling_audits_r3054 a
    group by a.action_taken
    order by count(*) desc;
end; $$;

revoke all on function r3054_overview() from public, anon;
revoke all on function r3054_wear_grade_distribution() from public, anon;
revoke all on function r3054_site_risk_ranking() from public, anon;
revoke all on function r3054_engineer_audit_throughput() from public, anon;
revoke all on function r3054_recall_batch_progress() from public, anon;
revoke all on function r3054_monthly_trend() from public, anon;
revoke all on function r3054_action_taken_breakdown() from public, anon;

grant execute on function r3054_overview() to authenticated;
grant execute on function r3054_wear_grade_distribution() to authenticated;
grant execute on function r3054_site_risk_ranking() to authenticated;
grant execute on function r3054_engineer_audit_throughput() to authenticated;
grant execute on function r3054_recall_batch_progress() to authenticated;
grant execute on function r3054_monthly_trend() to authenticated;
grant execute on function r3054_action_taken_breakdown() to authenticated;
