-- Round r3079: Hospital Chain Quarterly Catheter Lab Lead-Apron Inventory & Wear Audit

create table if not exists hospital_chain_lead_apron_inventory_r3079 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  chain_name text not null,
  hospital_branch text not null,
  cath_lab_room text not null,
  apron_asset_tag text not null,
  apron_type text not null check (apron_type in ('full_wrap','front_only','vest_skirt','thyroid_collar','pediatric')),
  lead_equivalent_mm numeric(3,2) not null,
  manufacture_date date not null,
  in_service_date date not null,
  last_audit_date date,
  fluoroscopy_pass_status text not null check (fluoroscopy_pass_status in ('pass','fail','marginal','pending')),
  wear_severity text not null check (wear_severity in ('none','minor','moderate','severe','condemned')),
  defect_area_cm2 numeric(6,2),
  retire_recommended boolean not null default false,
  replacement_cost_rupees integer
);

create table if not exists hospital_chain_lead_apron_audit_events_r3079 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  apron_id uuid references hospital_chain_lead_apron_inventory_r3079(id) on delete cascade,
  audit_quarter text not null check (audit_quarter in ('Q1','Q2','Q3','Q4')),
  audit_year integer not null,
  auditor_name text not null,
  audit_method text not null check (audit_method in ('fluoroscopy','visual','tactile','radiography','combined')),
  finding_summary text not null,
  defect_count integer not null default 0,
  action_taken text not null check (action_taken in ('cleared','quarantined','retired','sent_for_repair','rescheduled')),
  compliance_status text not null check (compliance_status in ('aerb_compliant','nabh_compliant','non_compliant','provisional')),
  audited_at timestamptz not null
);

alter table hospital_chain_lead_apron_inventory_r3079 enable row level security;
alter table hospital_chain_lead_apron_audit_events_r3079 enable row level security;

drop policy if exists hclai_r3079_founder_select on hospital_chain_lead_apron_inventory_r3079;
create policy hclai_r3079_founder_select on hospital_chain_lead_apron_inventory_r3079 for select to authenticated using (is_founder());

drop policy if exists hclae_r3079_founder_select on hospital_chain_lead_apron_audit_events_r3079;
create policy hclae_r3079_founder_select on hospital_chain_lead_apron_audit_events_r3079 for select to authenticated using (is_founder());

insert into hospital_chain_lead_apron_inventory_r3079 (chain_name, hospital_branch, cath_lab_room, apron_asset_tag, apron_type, lead_equivalent_mm, manufacture_date, in_service_date, last_audit_date, fluoroscopy_pass_status, wear_severity, defect_area_cm2, retire_recommended, replacement_cost_rupees) values
('Apollo Chain','Hyderabad Jubilee','CathLab-1','APL-HYD-001','full_wrap',0.50,'2022-03-15'::date,'2022-04-01'::date,'2026-03-12'::date,'pass','minor',2.5,false,18500),
('Apollo Chain','Hyderabad Jubilee','CathLab-1','APL-HYD-002','vest_skirt',0.35,'2021-08-20'::date,'2021-09-10'::date,'2026-03-12'::date,'marginal','moderate',8.3,false,22000),
('Apollo Chain','Bangalore Bannerghatta','CathLab-2','APL-BLR-005','full_wrap',0.50,'2020-01-10'::date,'2020-02-15'::date,'2026-02-28'::date,'fail','severe',24.8,true,19500),
('Apollo Chain','Chennai Greams','CathLab-1','APL-MAA-011','front_only',0.25,'2023-06-01'::date,'2023-06-25'::date,'2026-04-05'::date,'pass','none',0.0,false,9500),
('Fortis Chain','Mumbai Mulund','CathLab-3','FRT-MUM-021','full_wrap',0.50,'2019-11-12'::date,'2020-01-05'::date,'2026-03-30'::date,'fail','condemned',42.1,true,20500),
('Fortis Chain','Delhi Vasant Kunj','CathLab-1','FRT-DEL-022','vest_skirt',0.35,'2022-09-09'::date,'2022-10-15'::date,'2026-04-01'::date,'pass','minor',1.8,false,21500),
('Fortis Chain','Bangalore Cunningham','CathLab-2','FRT-BLR-024','thyroid_collar',0.50,'2023-02-20'::date,'2023-03-10'::date,'2026-03-22'::date,'pass','none',0.0,false,3500),
('Manipal Chain','Bangalore Old Airport','CathLab-1','MNP-BLR-031','full_wrap',0.35,'2021-05-18'::date,'2021-06-20'::date,'2026-03-15'::date,'marginal','moderate',6.7,false,17500),
('Manipal Chain','Bangalore Old Airport','CathLab-1','MNP-BLR-032','pediatric',0.25,'2022-11-08'::date,'2022-12-01'::date,'2026-03-15'::date,'pass','minor',0.9,false,8500),
('Manipal Chain','Jaipur','CathLab-2','MNP-JAI-041','vest_skirt',0.50,'2020-07-22'::date,'2020-08-15'::date,'2026-02-10'::date,'fail','severe',18.4,true,23000),
('Max Chain','Delhi Saket','CathLab-1','MAX-DEL-051','full_wrap',0.50,'2023-08-30'::date,'2023-09-20'::date,'2026-04-12'::date,'pass','none',0.0,false,19500),
('Max Chain','Delhi Patparganj','CathLab-2','MAX-DEL-052','front_only',0.35,'2021-12-05'::date,'2022-01-10'::date,'2026-03-25'::date,'marginal','moderate',9.6,false,14500),
('Max Chain','Mohali','CathLab-1','MAX-MOH-061','full_wrap',0.50,'2019-04-14'::date,'2019-05-20'::date,'2026-03-08'::date,'fail','condemned',51.2,true,20000),
('Medanta Chain','Gurgaon','CathLab-3','MDT-GGN-071','vest_skirt',0.50,'2022-06-11'::date,'2022-07-05'::date,'2026-04-18'::date,'pass','minor',2.1,false,24500),
('Medanta Chain','Lucknow','CathLab-1','MDT-LKO-081','full_wrap',0.35,'2021-10-19'::date,'2021-11-15'::date,'2026-03-20'::date,'marginal','moderate',7.4,false,18000),
('KIMS Chain','Hyderabad Secunderabad','CathLab-2','KIM-HYD-091','full_wrap',0.50,'2020-12-25'::date,'2021-01-20'::date,'2026-02-22'::date,'pass','minor',3.2,false,17000),
('KIMS Chain','Vizag','CathLab-1','KIM-VIZ-101','front_only',0.25,'2023-04-08'::date,'2023-05-01'::date,'2026-04-10'::date,'pending','none',0.0,false,9800),
('Narayana Chain','Bangalore Health City','CathLab-4','NRN-BLR-111','full_wrap',0.50,'2019-09-30'::date,'2019-10-25'::date,'2026-03-05'::date,'fail','severe',28.9,true,19800),
('Narayana Chain','Kolkata Mukundapur','CathLab-2','NRN-KOL-121','vest_skirt',0.35,'2022-02-14'::date,'2022-03-10'::date,'2026-03-28'::date,'pass','minor',1.5,false,21800),
('Yashoda Chain','Hyderabad Somajiguda','CathLab-1','YSH-HYD-131','full_wrap',0.50,'2023-01-22'::date,'2023-02-15'::date,'2026-04-02'::date,'pass','none',0.0,false,18500),
('AIIMS Chain','Delhi Ansari Nagar','CathLab-3','AMS-DEL-141','full_wrap',0.50,'2018-06-12'::date,'2018-07-20'::date,'2026-02-15'::date,'fail','condemned',62.4,true,16500),
('AIIMS Chain','Rishikesh','CathLab-1','AMS-RSH-151','vest_skirt',0.35,'2022-07-04'::date,'2022-08-01'::date,'2026-03-18'::date,'marginal','moderate',5.9,false,19000);

insert into hospital_chain_lead_apron_audit_events_r3079 (apron_id, audit_quarter, audit_year, auditor_name, audit_method, finding_summary, defect_count, action_taken, compliance_status, audited_at) values
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='APL-HYD-001'),'Q1',2026,'Dr Ramesh Kulkarni','combined','Minor surface scuff, lead intact',1,'cleared','aerb_compliant','2026-03-12 10:30:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='APL-HYD-002'),'Q1',2026,'Dr Ramesh Kulkarni','fluoroscopy','Hairline crack in shoulder seam',3,'sent_for_repair','provisional','2026-03-12 11:15:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='APL-BLR-005'),'Q1',2026,'Smt Lakshmi N','fluoroscopy','Multiple lead voids on back panel',7,'retired','non_compliant','2026-02-28 09:00:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='APL-MAA-011'),'Q2',2026,'Dr Priya Iyer','visual','New apron, no findings',0,'cleared','aerb_compliant','2026-04-05 14:20:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='FRT-MUM-021'),'Q1',2026,'Dr Anand Joshi','radiography','Catastrophic lead failure, immediate retire',12,'retired','non_compliant','2026-03-30 16:45:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='FRT-DEL-022'),'Q2',2026,'Dr Vikram Singh','combined','Light wear on velcro, lead OK',1,'cleared','aerb_compliant','2026-04-01 10:00:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='FRT-BLR-024'),'Q1',2026,'Dr Meera Patel','visual','Thyroid collar pristine',0,'cleared','nabh_compliant','2026-03-22 09:30:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='MNP-BLR-031'),'Q1',2026,'Dr Rakesh Gowda','fluoroscopy','Two small pinholes near hip',2,'quarantined','provisional','2026-03-15 13:00:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='MNP-BLR-032'),'Q1',2026,'Dr Rakesh Gowda','tactile','Pediatric apron, minor edge fray',1,'cleared','aerb_compliant','2026-03-15 13:45:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='MNP-JAI-041'),'Q1',2026,'Dr Sunita Sharma','radiography','Seam separation, lead exposure risk',5,'retired','non_compliant','2026-02-10 11:00:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='MAX-DEL-051'),'Q2',2026,'Dr Sanjay Kapoor','visual','Brand new, factory cert intact',0,'cleared','nabh_compliant','2026-04-12 08:30:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='MAX-DEL-052'),'Q1',2026,'Dr Sanjay Kapoor','fluoroscopy','Lead thinning observed shoulder',3,'sent_for_repair','provisional','2026-03-25 15:00:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='MAX-MOH-061'),'Q1',2026,'Dr Harpreet Kaur','radiography','End-of-life, multiple defects',9,'retired','non_compliant','2026-03-08 10:15:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='MDT-GGN-071'),'Q2',2026,'Dr Naresh Trehan Jr','combined','Premium apron, light scuffs',1,'cleared','aerb_compliant','2026-04-18 12:00:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='MDT-LKO-081'),'Q1',2026,'Dr Alok Mishra','fluoroscopy','Crack near armhole',2,'quarantined','provisional','2026-03-20 14:30:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='KIM-HYD-091'),'Q1',2026,'Dr Bhaskar Rao','visual','Surface wear only',1,'cleared','aerb_compliant','2026-02-22 09:45:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='KIM-VIZ-101'),'Q2',2026,'Dr Bhaskar Rao','visual','New apron, audit pending fluoro',0,'rescheduled','provisional','2026-04-10 11:30:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='NRN-BLR-111'),'Q1',2026,'Dr Devi Shetty Jr','radiography','Severe back panel degradation',8,'retired','non_compliant','2026-03-05 10:00:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='NRN-KOL-121'),'Q1',2026,'Dr Sourav Banerjee','combined','Minor wear, within tolerance',1,'cleared','nabh_compliant','2026-03-28 13:15:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='YSH-HYD-131'),'Q2',2026,'Dr Pavan Yashoda','visual','Pristine, no findings',0,'cleared','aerb_compliant','2026-04-02 09:00:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='AMS-DEL-141'),'Q1',2026,'Prof Randeep Guleria','radiography','8 years in service, condemned',15,'retired','non_compliant','2026-02-15 11:00:00+05:30'::timestamptz),
((select id from hospital_chain_lead_apron_inventory_r3079 where apron_asset_tag='AMS-RSH-151'),'Q1',2026,'Dr Ashok Joshi','fluoroscopy','Moderate wear front panel',3,'sent_for_repair','provisional','2026-03-18 14:00:00+05:30'::timestamptz);

create or replace function founder_r3079_chain_summary()
returns table(chain_name text, apron_count int, retire_count int, total_replacement_cost int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.chain_name,
         count(*)::int,
         (count(*) filter (where i.retire_recommended))::int,
         coalesce(sum(i.replacement_cost_rupees) filter (where i.retire_recommended),0)::int
  from hospital_chain_lead_apron_inventory_r3079 i
  group by i.chain_name
  order by retire_count desc, i.chain_name;
end $$;

create or replace function founder_r3079_wear_distribution()
returns table(wear_severity text, apron_count int, avg_defect_cm2 numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.wear_severity, count(*)::int, round(avg(coalesce(i.defect_area_cm2,0))::numeric,2)
  from hospital_chain_lead_apron_inventory_r3079 i
  group by i.wear_severity
  order by apron_count desc;
end $$;

create or replace function founder_r3079_failed_fluoro()
returns table(asset_tag text, chain_name text, branch text, room text, wear text, defect_cm2 numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.apron_asset_tag, i.chain_name, i.hospital_branch, i.cath_lab_room, i.wear_severity, i.defect_area_cm2
  from hospital_chain_lead_apron_inventory_r3079 i
  where i.fluoroscopy_pass_status = 'fail'
  order by i.defect_area_cm2 desc nulls last;
end $$;

create or replace function founder_r3079_age_buckets()
returns table(age_bucket text, apron_count int, retire_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select bucket,
         count(*)::int,
         (count(*) filter (where retire_recommended))::int
  from (
    select i.retire_recommended,
      case
        when (current_date - i.in_service_date) < 365 then '0-1 years'
        when (current_date - i.in_service_date) < 1095 then '1-3 years'
        when (current_date - i.in_service_date) < 1825 then '3-5 years'
        else '5+ years'
      end as bucket
    from hospital_chain_lead_apron_inventory_r3079 i
  ) s
  group by bucket
  order by bucket;
end $$;

create or replace function founder_r3079_action_summary()
returns table(action_taken text, event_count int, defect_total int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select e.action_taken, count(*)::int, coalesce(sum(e.defect_count),0)::int
  from hospital_chain_lead_apron_audit_events_r3079 e
  group by e.action_taken
  order by event_count desc;
end $$;

create or replace function founder_r3079_compliance_split()
returns table(compliance_status text, event_count int, pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
declare total int;
begin
  if not is_founder() then raise exception 'not founder'; end if;
  select count(*) into total from hospital_chain_lead_apron_audit_events_r3079;
  return query
  select e.compliance_status, count(*)::int,
         round((count(*)::numeric / nullif(total,0)) * 100, 1)
  from hospital_chain_lead_apron_audit_events_r3079 e
  group by e.compliance_status
  order by event_count desc;
end $$;

create or replace function founder_r3079_top_branches_at_risk()
returns table(chain_name text, branch text, retire_count int, total_cost int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.chain_name, i.hospital_branch,
         (count(*) filter (where i.retire_recommended))::int,
         coalesce(sum(i.replacement_cost_rupees) filter (where i.retire_recommended),0)::int
  from hospital_chain_lead_apron_inventory_r3079 i
  group by i.chain_name, i.hospital_branch
  having (count(*) filter (where i.retire_recommended)) > 0
  order by retire_count desc, total_cost desc;
end $$;

revoke all on function founder_r3079_chain_summary() from public, anon;
revoke all on function founder_r3079_wear_distribution() from public, anon;
revoke all on function founder_r3079_failed_fluoro() from public, anon;
revoke all on function founder_r3079_age_buckets() from public, anon;
revoke all on function founder_r3079_action_summary() from public, anon;
revoke all on function founder_r3079_compliance_split() from public, anon;
revoke all on function founder_r3079_top_branches_at_risk() from public, anon;

grant execute on function founder_r3079_chain_summary() to authenticated;
grant execute on function founder_r3079_wear_distribution() to authenticated;
grant execute on function founder_r3079_failed_fluoro() to authenticated;
grant execute on function founder_r3079_age_buckets() to authenticated;
grant execute on function founder_r3079_action_summary() to authenticated;
grant execute on function founder_r3079_compliance_split() to authenticated;
grant execute on function founder_r3079_top_branches_at_risk() to authenticated;
