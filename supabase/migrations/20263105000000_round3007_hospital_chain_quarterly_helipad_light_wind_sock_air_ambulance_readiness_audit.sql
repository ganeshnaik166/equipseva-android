-- Round 3007: Hospital Chain Quarterly Helipad-Light & Wind-Sock Air-Ambulance Readiness Audit

create table if not exists hospital_helipad_audits_r3007 (
  id uuid primary key default gen_random_uuid(),
  hospital_chain_name text not null,
  hospital_site_code text not null,
  city text not null,
  quarter text not null check (quarter in ('Q1','Q2','Q3','Q4')),
  audit_date date not null,
  helipad_class text not null check (helipad_class in ('rooftop','ground_level','elevated_deck','floating_barge')),
  perimeter_light_status text not null check (perimeter_light_status in ('all_green','one_amber','two_amber','red_fail')),
  flood_light_status text not null check (flood_light_status in ('pass','marginal','fail','not_installed')),
  windsock_condition text not null check (windsock_condition in ('crisp','faded','torn','missing')),
  windsock_secondary_present boolean not null default false,
  generator_backup_minutes int not null check (generator_backup_minutes between 0 and 720),
  last_lift_test_days_ago int not null check (last_lift_test_days_ago between 0 and 540),
  air_ambulance_drill_score int not null check (air_ambulance_drill_score between 0 and 100),
  readiness_grade text not null check (readiness_grade in ('A','B','C','D','F')),
  blocker_count int not null default 0 check (blocker_count between 0 and 20),
  remediation_owner_email text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists hospital_helipad_remediations_r3007 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references hospital_helipad_audits_r3007(id) on delete cascade,
  finding_code text not null,
  finding_severity text not null check (finding_severity in ('p0','p1','p2','p3')),
  finding_category text not null check (finding_category in ('lighting','windsock','power','surface','signage','comms','training','medical')),
  finding_summary text not null,
  status text not null check (status in ('open','scheduled','in_remediation','verified','waived')),
  assigned_team text not null check (assigned_team in ('inhouse_facilities','vendor_lighting','vendor_aviation','dgca_liaison','medical_ops')),
  scheduled_for date,
  closed_at timestamptz,
  cost_estimate_rupees int not null default 0 check (cost_estimate_rupees between 0 and 5000000),
  notes text,
  created_at timestamptz not null default now()
);

alter table hospital_helipad_audits_r3007 enable row level security;
alter table hospital_helipad_remediations_r3007 enable row level security;

drop policy if exists r3007_audits_founder_all on hospital_helipad_audits_r3007;
create policy r3007_audits_founder_all on hospital_helipad_audits_r3007
  for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists r3007_rem_founder_all on hospital_helipad_remediations_r3007;
create policy r3007_rem_founder_all on hospital_helipad_remediations_r3007
  for all to authenticated using (is_founder()) with check (is_founder());

-- Seed audits (16 rows)
insert into hospital_helipad_audits_r3007
(hospital_chain_name, hospital_site_code, city, quarter, audit_date, helipad_class, perimeter_light_status, flood_light_status, windsock_condition, windsock_secondary_present, generator_backup_minutes, last_lift_test_days_ago, air_ambulance_drill_score, readiness_grade, blocker_count, remediation_owner_email, notes)
values
('Apollo Helix','APX-HYD-01','Hyderabad','Q2','2026-06-02'::date,'rooftop','all_green','pass','crisp',true,480,21,94,'A',0,'facilities.apollo@example.com','Gold-standard site'),
('Apollo Helix','APX-CHN-02','Chennai','Q2','2026-06-04'::date,'rooftop','one_amber','pass','crisp',true,360,45,88,'B',1,'facilities.apollo@example.com','One LED driver flickering'),
('Apollo Helix','APX-BLR-03','Bengaluru','Q2','2026-06-06'::date,'elevated_deck','two_amber','marginal','faded',true,300,62,79,'B',2,'facilities.apollo@example.com','Windsock fade beyond DGCA threshold'),
('Manipal Skyline','MAN-BLR-11','Bengaluru','Q2','2026-06-07'::date,'rooftop','all_green','pass','crisp',true,420,30,90,'A',0,'ops.manipal@example.com','Recently recommissioned'),
('Manipal Skyline','MAN-MNG-12','Mangalore','Q2','2026-06-09'::date,'ground_level','one_amber','marginal','faded',false,180,120,68,'C',3,'ops.manipal@example.com','No backup windsock'),
('Manipal Skyline','MAN-MYS-13','Mysuru','Q2','2026-06-11'::date,'rooftop','red_fail','fail','torn',false,90,200,42,'F',6,'ops.manipal@example.com','Failed quarterly — grounded'),
('Fortis Wings','FOR-DEL-21','Delhi','Q2','2026-06-12'::date,'rooftop','all_green','pass','crisp',true,540,18,96,'A',0,'aviation.fortis@example.com','Best in class'),
('Fortis Wings','FOR-MUM-22','Mumbai','Q2','2026-06-14'::date,'floating_barge','two_amber','marginal','faded',true,240,75,72,'C',4,'aviation.fortis@example.com','Saline corrosion on lights'),
('Fortis Wings','FOR-GUR-23','Gurugram','Q2','2026-06-15'::date,'rooftop','one_amber','pass','crisp',true,360,52,85,'B',1,'aviation.fortis@example.com','Driver replacement pending'),
('Max Aero','MAX-DEL-31','Delhi','Q2','2026-06-16'::date,'rooftop','all_green','pass','crisp',true,480,28,91,'A',0,'max.aero@example.com','On track'),
('Max Aero','MAX-LKO-32','Lucknow','Q2','2026-06-17'::date,'ground_level','two_amber','marginal','torn',false,150,180,55,'D',5,'max.aero@example.com','Multiple issues'),
('Narayana Helix','NAR-BLR-41','Bengaluru','Q2','2026-06-18'::date,'rooftop','all_green','pass','crisp',true,360,40,89,'B',1,'narayana.ops@example.com','Minor signage'),
('Narayana Helix','NAR-KOL-42','Kolkata','Q2','2026-06-19'::date,'elevated_deck','one_amber','pass','faded',true,300,90,76,'C',2,'narayana.ops@example.com','Windsock replacement scheduled'),
('AIIMS Federal','AII-NDL-51','New Delhi','Q2','2026-06-20'::date,'rooftop','all_green','pass','crisp',true,720,15,98,'A',0,'aiims.helipad@example.com','Reference site'),
('AIIMS Federal','AII-BPL-52','Bhopal','Q2','2026-06-20'::date,'rooftop','red_fail','fail','missing',false,60,300,30,'F',8,'aiims.helipad@example.com','Grounded — major capex needed'),
('Yashoda Air','YAS-HYD-61','Hyderabad','Q2','2026-06-21'::date,'rooftop','one_amber','marginal','faded',true,240,85,73,'C',2,'yashoda.air@example.com','Quarter close push');

-- Seed remediations (20 rows)
insert into hospital_helipad_remediations_r3007
(audit_id, finding_code, finding_severity, finding_category, finding_summary, status, assigned_team, scheduled_for, closed_at, cost_estimate_rupees, notes)
select id, 'F-LITE-01','p1','lighting','Replace 2x perimeter LED drivers','scheduled','vendor_lighting','2026-06-28'::date, null::timestamptz, 140000,'Driver SKU CRE-LD-48' from hospital_helipad_audits_r3007 where hospital_site_code='APX-CHN-02'
union all select id,'F-WIND-02','p2','windsock','Swap faded primary windsock','in_remediation','inhouse_facilities','2026-06-25'::date,null,18000,'Stock on hand' from hospital_helipad_audits_r3007 where hospital_site_code='APX-BLR-03'
union all select id,'F-LITE-03','p2','lighting','Amber-rated flood lamp marginal lux','scheduled','vendor_lighting','2026-07-02'::date,null,220000,'Lux at 480, need 540' from hospital_helipad_audits_r3007 where hospital_site_code='APX-BLR-03'
union all select id,'F-WIND-04','p1','windsock','Install secondary windsock pole','scheduled','vendor_aviation','2026-07-05'::date,null,95000,'DGCA dual-sock rule' from hospital_helipad_audits_r3007 where hospital_site_code='MAN-MNG-12'
union all select id,'F-POWER-05','p1','power','Generator only 180 min, target 360','open','vendor_aviation',null,null,850000,'Upgrade UPS bank' from hospital_helipad_audits_r3007 where hospital_site_code='MAN-MNG-12'
union all select id,'F-SURF-06','p2','surface','Faded H marking re-paint','scheduled','inhouse_facilities','2026-06-26'::date,null,35000,'Reflective epoxy' from hospital_helipad_audits_r3007 where hospital_site_code='MAN-MNG-12'
union all select id,'F-LITE-07','p0','lighting','Complete perimeter circuit fail','open','vendor_lighting',null,null,1800000,'Site grounded pending fix' from hospital_helipad_audits_r3007 where hospital_site_code='MAN-MYS-13'
union all select id,'F-WIND-08','p0','windsock','Both windsocks torn / missing','open','vendor_aviation',null,null,140000,'DGCA notice issued' from hospital_helipad_audits_r3007 where hospital_site_code='MAN-MYS-13'
union all select id,'F-POWER-09','p0','power','Backup generator 90 min only','open','dgca_liaison',null,null,1200000,'Critical' from hospital_helipad_audits_r3007 where hospital_site_code='MAN-MYS-13'
union all select id,'F-LITE-10','p2','lighting','Corrosion on floodlight housings','in_remediation','vendor_lighting','2026-06-30'::date,null,260000,'Marine-grade swap' from hospital_helipad_audits_r3007 where hospital_site_code='FOR-MUM-22'
union all select id,'F-WIND-11','p2','windsock','Salt fade on primary windsock','scheduled','inhouse_facilities','2026-07-01'::date,null,18000,'90-day cycle' from hospital_helipad_audits_r3007 where hospital_site_code='FOR-MUM-22'
union all select id,'F-COMMS-12','p3','comms','VHF radio handset crackle','verified','medical_ops','2026-06-10'::date,'2026-06-14'::timestamptz,12000,'Closed' from hospital_helipad_audits_r3007 where hospital_site_code='FOR-MUM-22'
union all select id,'F-SIGN-13','p3','signage','Approach signage faded','waived','inhouse_facilities',null,null,8000,'Deferred to Q3' from hospital_helipad_audits_r3007 where hospital_site_code='FOR-MUM-22'
union all select id,'F-LITE-14','p1','lighting','One amber LED driver fault','scheduled','vendor_lighting','2026-06-27'::date,null,70000,'SKU in stock' from hospital_helipad_audits_r3007 where hospital_site_code='FOR-GUR-23'
union all select id,'F-LITE-15','p1','lighting','Two perimeter strips dim','scheduled','vendor_lighting','2026-07-03'::date,null,180000,'LED bar swap' from hospital_helipad_audits_r3007 where hospital_site_code='MAX-LKO-32'
union all select id,'F-WIND-16','p1','windsock','Primary windsock torn','in_remediation','inhouse_facilities','2026-06-24'::date,null,22000,'Replacement enroute' from hospital_helipad_audits_r3007 where hospital_site_code='MAX-LKO-32'
union all select id,'F-TRAIN-17','p2','training','Drill score 55 — re-train pilots','scheduled','medical_ops','2026-07-10'::date,null,55000,'2-day refresher' from hospital_helipad_audits_r3007 where hospital_site_code='MAX-LKO-32'
union all select id,'F-MED-18','p2','medical','Crash trolley stock check overdue','open','medical_ops',null,null,15000,'Pending audit' from hospital_helipad_audits_r3007 where hospital_site_code='NAR-KOL-42'
union all select id,'F-LITE-19','p0','lighting','Total perimeter blackout','open','dgca_liaison',null,null,2400000,'Site grounded' from hospital_helipad_audits_r3007 where hospital_site_code='AII-BPL-52'
union all select id,'F-WIND-20','p0','windsock','Both windsocks missing','open','vendor_aviation',null,null,180000,'Capex pending' from hospital_helipad_audits_r3007 where hospital_site_code='AII-BPL-52';

-- RPCs (7)

create or replace function r3007_chain_readiness_overview()
returns table(chain text, sites int, avg_drill_score numeric, a_or_b int, failing int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select hospital_chain_name,
         count(*)::int,
         round(avg(air_ambulance_drill_score)::numeric, 1),
         (count(*) filter (where readiness_grade in ('A','B')))::int,
         (count(*) filter (where readiness_grade in ('D','F')))::int
  from hospital_helipad_audits_r3007
  group by hospital_chain_name
  order by avg(air_ambulance_drill_score) desc;
end$$;

create or replace function r3007_grounded_sites()
returns table(site_code text, chain text, city text, grade text, blockers int, owner text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select hospital_site_code, hospital_chain_name, city, readiness_grade, blocker_count, coalesce(remediation_owner_email,'-')
  from hospital_helipad_audits_r3007
  where readiness_grade in ('D','F')
  order by blocker_count desc, audit_date desc;
end$$;

create or replace function r3007_windsock_compliance()
returns table(condition text, sites int, with_backup int, pct_backup numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select windsock_condition,
         count(*)::int,
         (count(*) filter (where windsock_secondary_present))::int,
         round(100.0 * (count(*) filter (where windsock_secondary_present))::numeric / nullif(count(*),0), 1)
  from hospital_helipad_audits_r3007
  group by windsock_condition
  order by count(*) desc;
end$$;

create or replace function r3007_lighting_failures()
returns table(perimeter text, flood text, sites int, avg_blockers numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select perimeter_light_status, flood_light_status, count(*)::int, round(avg(blocker_count)::numeric, 1)
  from hospital_helipad_audits_r3007
  group by perimeter_light_status, flood_light_status
  order by count(*) desc;
end$$;

create or replace function r3007_remediation_backlog()
returns table(severity text, open_cnt int, scheduled_cnt int, in_rem_cnt int, verified_cnt int, total_cost_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select finding_severity,
         (count(*) filter (where status='open'))::int,
         (count(*) filter (where status='scheduled'))::int,
         (count(*) filter (where status='in_remediation'))::int,
         (count(*) filter (where status='verified'))::int,
         sum(cost_estimate_rupees)::bigint
  from hospital_helipad_remediations_r3007
  group by finding_severity
  order by finding_severity;
end$$;

create or replace function r3007_category_hotspots()
returns table(category text, findings int, p0_p1 int, est_cost_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select finding_category,
         count(*)::int,
         (count(*) filter (where finding_severity in ('p0','p1')))::int,
         sum(cost_estimate_rupees)::bigint
  from hospital_helipad_remediations_r3007
  group by finding_category
  order by count(*) desc;
end$$;

create or replace function r3007_quarterly_scorecard()
returns table(site_code text, chain text, city text, helipad_class text, grade text, drill int, gen_min int, lift_age_days int, blockers int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select hospital_site_code, hospital_chain_name, city, helipad_class, readiness_grade,
         air_ambulance_drill_score, generator_backup_minutes, last_lift_test_days_ago, blocker_count
  from hospital_helipad_audits_r3007
  order by readiness_grade, blocker_count desc;
end$$;

revoke all on function r3007_chain_readiness_overview() from public, anon;
revoke all on function r3007_grounded_sites() from public, anon;
revoke all on function r3007_windsock_compliance() from public, anon;
revoke all on function r3007_lighting_failures() from public, anon;
revoke all on function r3007_remediation_backlog() from public, anon;
revoke all on function r3007_category_hotspots() from public, anon;
revoke all on function r3007_quarterly_scorecard() from public, anon;

grant execute on function r3007_chain_readiness_overview() to authenticated;
grant execute on function r3007_grounded_sites() to authenticated;
grant execute on function r3007_windsock_compliance() to authenticated;
grant execute on function r3007_lighting_failures() to authenticated;
grant execute on function r3007_remediation_backlog() to authenticated;
grant execute on function r3007_category_hotspots() to authenticated;
grant execute on function r3007_quarterly_scorecard() to authenticated;

revoke all on table hospital_helipad_audits_r3007 from public, anon;
revoke all on table hospital_helipad_remediations_r3007 from public, anon;
grant select on table hospital_helipad_audits_r3007 to authenticated;
grant select on table hospital_helipad_remediations_r3007 to authenticated;
