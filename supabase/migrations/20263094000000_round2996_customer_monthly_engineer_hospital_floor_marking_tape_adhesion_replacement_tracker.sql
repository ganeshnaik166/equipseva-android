-- Round r2996 — Customer Monthly Engineer Hospital Floor-Marking Tape Adhesion & Replacement Tracker
-- HEAVY ★★★★

create table if not exists floor_marking_tape_inspections_r2996 (
  id uuid primary key default gen_random_uuid(),
  hospital_name text not null,
  hospital_city text not null,
  zone_label text not null,
  zone_type text not null check (zone_type in ('operating_theatre','icu','ward','corridor','pharmacy','radiology','sterile_supply','er_triage','lab','reception')),
  tape_color text not null check (tape_color in ('red','yellow','green','blue','white','black_yellow_hazard','red_white_hazard')),
  tape_purpose text not null check (tape_purpose in ('walkway','equipment_zone','hazard','emergency_route','quarantine','clean_zone','sterile_perimeter','no_step')),
  inspected_on date not null,
  engineer_code text not null,
  adhesion_score_pct numeric(5,2) not null,
  visibility_score_pct numeric(5,2) not null,
  abrasion_level text not null check (abrasion_level in ('none','light','moderate','heavy','tape_detached')),
  edge_lift_mm numeric(6,2) not null,
  status text not null check (status in ('healthy','watch','schedule_replace','urgent_replace','already_replaced')),
  meters_installed numeric(8,2) not null,
  next_check_on date not null,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists floor_marking_tape_replacements_r2996 (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid references floor_marking_tape_inspections_r2996(id) on delete set null,
  hospital_name text not null,
  zone_label text not null,
  replaced_on date not null,
  engineer_code text not null,
  tape_sku text not null,
  meters_replaced numeric(8,2) not null,
  surface_prep text not null check (surface_prep in ('alcohol_wipe','solvent_clean','mechanical_scuff','primer_applied','none')),
  cure_hours numeric(5,2) not null,
  cost_rupees numeric(10,2) not null,
  warranty_months int not null,
  outcome text not null check (outcome in ('excellent','good','acceptable','rework_needed','failed_24h')),
  reinspect_on date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table floor_marking_tape_inspections_r2996 enable row level security;
alter table floor_marking_tape_replacements_r2996 enable row level security;

drop policy if exists fmt_insp_founder_r2996 on floor_marking_tape_inspections_r2996;
create policy fmt_insp_founder_r2996 on floor_marking_tape_inspections_r2996 for select to authenticated using (is_founder());

drop policy if exists fmt_repl_founder_r2996 on floor_marking_tape_replacements_r2996;
create policy fmt_repl_founder_r2996 on floor_marking_tape_replacements_r2996 for select to authenticated using (is_founder());

insert into floor_marking_tape_inspections_r2996 (hospital_name, hospital_city, zone_label, zone_type, tape_color, tape_purpose, inspected_on, engineer_code, adhesion_score_pct, visibility_score_pct, abrasion_level, edge_lift_mm, status, meters_installed, next_check_on, notes) values
('Apollo Jubilee','Hyderabad','OT-1 Perimeter','operating_theatre','red','sterile_perimeter','2026-06-01'::date,'ENG-101',92.5,95.0,'light',0.5,'healthy',48.0,'2026-07-01'::date,'clean'),
('Apollo Jubilee','Hyderabad','OT-2 Walkway','operating_theatre','green','walkway','2026-06-01'::date,'ENG-101',71.0,82.0,'moderate',2.4,'watch',36.0,'2026-06-22'::date,'edge lifting near door'),
('Yashoda Somajiguda','Hyderabad','ICU Bed Zones','icu','yellow','equipment_zone','2026-06-02'::date,'ENG-104',58.0,74.0,'heavy',5.8,'schedule_replace',64.0,'2026-06-15'::date,'wheel abrasion heavy'),
('Yashoda Somajiguda','Hyderabad','ICU Hazard','icu','black_yellow_hazard','hazard','2026-06-02'::date,'ENG-104',88.0,90.0,'light',1.0,'healthy',12.0,'2026-07-02'::date,null),
('Manipal Vijayawada','Vijayawada','Corridor A','corridor','blue','walkway','2026-06-03'::date,'ENG-202',44.0,61.0,'tape_detached',12.0,'urgent_replace',58.0,'2026-06-10'::date,'detached 2m strip'),
('Manipal Vijayawada','Vijayawada','Pharmacy','pharmacy','white','clean_zone','2026-06-03'::date,'ENG-202',85.0,88.0,'light',0.8,'healthy',22.0,'2026-07-03'::date,null),
('Fortis Bannerghatta','Bengaluru','OT-3 Sterile','operating_theatre','red','sterile_perimeter','2026-06-04'::date,'ENG-310',95.0,96.0,'none',0.2,'healthy',52.0,'2026-07-04'::date,'pristine'),
('Fortis Bannerghatta','Bengaluru','Radiology','radiology','yellow','no_step','2026-06-04'::date,'ENG-310',67.0,78.0,'moderate',3.2,'watch',18.0,'2026-06-25'::date,null),
('AIIMS Mangalagiri','Mangalagiri','Triage','er_triage','red_white_hazard','emergency_route','2026-06-05'::date,'ENG-411',39.0,55.0,'tape_detached',15.5,'urgent_replace',40.0,'2026-06-12'::date,'high foot traffic'),
('AIIMS Mangalagiri','Mangalagiri','Lab Bench','lab','green','equipment_zone','2026-06-05'::date,'ENG-411',78.0,84.0,'light',1.4,'healthy',28.0,'2026-07-05'::date,null),
('KIMS Secunderabad','Hyderabad','Ward 4','ward','blue','walkway','2026-06-06'::date,'ENG-101',62.0,71.0,'moderate',2.8,'schedule_replace',44.0,'2026-06-20'::date,null),
('KIMS Secunderabad','Hyderabad','Sterile Supply','sterile_supply','white','clean_zone','2026-06-06'::date,'ENG-101',91.0,93.0,'none',0.3,'healthy',32.0,'2026-07-06'::date,null),
('Care Banjara','Hyderabad','OT-1 Hazard','operating_theatre','black_yellow_hazard','hazard','2026-06-07'::date,'ENG-104',82.0,86.0,'light',1.1,'healthy',14.0,'2026-07-07'::date,null),
('Care Banjara','Hyderabad','Quarantine','ward','red','quarantine','2026-06-07'::date,'ENG-104',54.0,65.0,'heavy',4.7,'schedule_replace',26.0,'2026-06-21'::date,'cleaner chemicals'),
('SLG Bachupally','Hyderabad','ICU Walkway','icu','green','walkway','2026-06-08'::date,'ENG-202',73.0,79.0,'moderate',2.1,'watch',38.0,'2026-06-28'::date,null),
('SLG Bachupally','Hyderabad','Reception','reception','blue','walkway','2026-06-08'::date,'ENG-202',86.0,89.0,'light',0.7,'healthy',20.0,'2026-07-08'::date,null),
('Continental Gachibowli','Hyderabad','OT-4 Perimeter','operating_theatre','red','sterile_perimeter','2026-06-09'::date,'ENG-310',96.0,97.0,'none',0.1,'healthy',56.0,'2026-07-09'::date,null),
('Continental Gachibowli','Hyderabad','Pharmacy Aisle','pharmacy','white','clean_zone','2026-06-09'::date,'ENG-310',64.0,72.0,'moderate',2.9,'watch',24.0,'2026-06-30'::date,null),
('Rainbow Banjara','Hyderabad','NICU Bed Zone','icu','yellow','equipment_zone','2026-06-10'::date,'ENG-411',88.0,91.0,'light',0.9,'already_replaced',30.0,'2026-07-10'::date,'replaced last week'),
('Rainbow Banjara','Hyderabad','Lab Hazard','lab','black_yellow_hazard','hazard','2026-06-10'::date,'ENG-411',48.0,60.0,'heavy',6.2,'urgent_replace',16.0,'2026-06-17'::date,'spill damage'),
('Sunshine Paradise','Hyderabad','Ward 7 Walkway','ward','green','walkway','2026-06-11'::date,'ENG-101',69.0,76.0,'moderate',2.5,'watch',42.0,'2026-07-02'::date,null),
('Sunshine Paradise','Hyderabad','OT-2 No-Step','operating_theatre','yellow','no_step','2026-06-11'::date,'ENG-101',81.0,84.0,'light',1.3,'healthy',20.0,'2026-07-11'::date,null),
('AIG Gachibowli','Hyderabad','Radiology Zone','radiology','blue','equipment_zone','2026-06-12'::date,'ENG-104',74.0,80.0,'light',1.5,'healthy',26.0,'2026-07-12'::date,null),
('AIG Gachibowli','Hyderabad','ER Emergency Lane','er_triage','red_white_hazard','emergency_route','2026-06-12'::date,'ENG-104',57.0,68.0,'heavy',4.4,'schedule_replace',34.0,'2026-06-26'::date,'high traffic'),
('Omega Vizag','Visakhapatnam','OT-5 Sterile','operating_theatre','red','sterile_perimeter','2026-06-13'::date,'ENG-202',93.0,94.0,'none',0.4,'healthy',50.0,'2026-07-13'::date,null);

insert into floor_marking_tape_replacements_r2996 (hospital_name, zone_label, replaced_on, engineer_code, tape_sku, meters_replaced, surface_prep, cure_hours, cost_rupees, warranty_months, outcome, reinspect_on, notes) values
('Yashoda Somajiguda','ICU Bed Zones','2026-06-16'::date,'ENG-104','3M-971-Y-50mm',64.0,'solvent_clean',24.0,8400.00,12,'excellent','2026-07-16'::date,'full cure'),
('Manipal Vijayawada','Corridor A','2026-06-11'::date,'ENG-202','3M-971-B-50mm',58.0,'mechanical_scuff',12.0,7200.00,12,'good','2026-07-11'::date,null),
('AIIMS Mangalagiri','Triage','2026-06-13'::date,'ENG-411','3M-971-RW-100mm',40.0,'primer_applied',48.0,9800.00,18,'excellent','2026-07-13'::date,'primer worth it'),
('KIMS Secunderabad','Ward 4','2026-06-21'::date,'ENG-101','3M-471-B-50mm',44.0,'alcohol_wipe',6.0,4800.00,6,'acceptable','2026-07-05'::date,'budget tape'),
('Care Banjara','Quarantine','2026-06-22'::date,'ENG-104','3M-971-R-75mm',26.0,'solvent_clean',24.0,5200.00,12,'good','2026-07-22'::date,null),
('Rainbow Banjara','Lab Hazard','2026-06-18'::date,'ENG-411','3M-971-BY-50mm',16.0,'solvent_clean',24.0,3600.00,12,'rework_needed','2026-06-25'::date,'lifted in 48h'),
('AIG Gachibowli','ER Emergency Lane','2026-06-27'::date,'ENG-104','3M-971-RW-100mm',34.0,'primer_applied',48.0,8500.00,18,'excellent','2026-07-27'::date,null),
('Yashoda Somajiguda','ICU Hazard','2026-05-20'::date,'ENG-104','3M-471-BY-50mm',12.0,'none',2.0,1400.00,3,'failed_24h','2026-05-22'::date,'rushed prep, redo'),
('Apollo Jubilee','OT-2 Walkway','2026-05-15'::date,'ENG-101','3M-971-G-50mm',36.0,'alcohol_wipe',12.0,4500.00,12,'good','2026-06-15'::date,null),
('Fortis Bannerghatta','Radiology','2026-05-10'::date,'ENG-310','3M-971-Y-50mm',18.0,'solvent_clean',24.0,2400.00,12,'excellent','2026-06-10'::date,null),
('SLG Bachupally','ICU Walkway','2026-05-25'::date,'ENG-202','3M-471-G-50mm',38.0,'mechanical_scuff',12.0,4200.00,6,'acceptable','2026-06-25'::date,null),
('Continental Gachibowli','Pharmacy Aisle','2026-05-30'::date,'ENG-310','3M-971-W-50mm',24.0,'solvent_clean',24.0,3000.00,12,'good','2026-06-30'::date,null),
('Sunshine Paradise','Ward 7 Walkway','2026-05-22'::date,'ENG-101','3M-471-G-50mm',42.0,'alcohol_wipe',12.0,4600.00,6,'acceptable','2026-06-22'::date,null),
('Omega Vizag','OT-5 Sterile','2026-05-13'::date,'ENG-202','3M-971-R-75mm',50.0,'primer_applied',48.0,10500.00,18,'excellent','2026-06-13'::date,null),
('Apollo Jubilee','OT-1 Perimeter','2026-05-01'::date,'ENG-101','3M-971-R-75mm',48.0,'primer_applied',48.0,10000.00,18,'excellent','2026-06-01'::date,null);

create or replace function founder_fmt_inspection_summary_r2996()
returns table(total_inspections int, total_meters numeric, avg_adhesion_pct numeric, urgent_count int, healthy_count int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    coalesce(sum(meters_installed),0)::numeric,
    coalesce(round(avg(adhesion_score_pct),2),0)::numeric,
    (count(*) filter (where status = 'urgent_replace'))::int,
    (count(*) filter (where status = 'healthy'))::int
  from floor_marking_tape_inspections_r2996;
end; $$;

create or replace function founder_fmt_status_breakdown_r2996()
returns table(status text, n int, total_meters numeric, avg_edge_lift_mm numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.status, count(*)::int, sum(i.meters_installed)::numeric, round(avg(i.edge_lift_mm),2)::numeric
  from floor_marking_tape_inspections_r2996 i
  group by i.status
  order by n desc;
end; $$;

create or replace function founder_fmt_zone_type_health_r2996()
returns table(zone_type text, inspections int, avg_adhesion_pct numeric, urgent_count int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.zone_type, count(*)::int, round(avg(i.adhesion_score_pct),2)::numeric,
    (count(*) filter (where i.status = 'urgent_replace'))::int
  from floor_marking_tape_inspections_r2996 i
  group by i.zone_type
  order by avg_adhesion_pct asc;
end; $$;

create or replace function founder_fmt_urgent_replacements_r2996()
returns table(hospital_name text, zone_label text, zone_type text, adhesion_score_pct numeric, edge_lift_mm numeric, next_check_on date, engineer_code text)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.hospital_name, i.zone_label, i.zone_type, i.adhesion_score_pct, i.edge_lift_mm, i.next_check_on, i.engineer_code
  from floor_marking_tape_inspections_r2996 i
  where i.status in ('urgent_replace','schedule_replace')
  order by i.adhesion_score_pct asc;
end; $$;

create or replace function founder_fmt_engineer_performance_r2996()
returns table(engineer_code text, inspections int, replacements int, avg_adhesion_post_pct numeric, rework_count int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    coalesce(i.engineer_code, r.engineer_code) as engineer_code,
    count(distinct i.id)::int,
    count(distinct r.id)::int,
    coalesce(round(avg(case when r.outcome in ('excellent','good') then 95.0 when r.outcome = 'acceptable' then 80.0 else 50.0 end),2),0)::numeric,
    (count(*) filter (where r.outcome in ('rework_needed','failed_24h')))::int
  from floor_marking_tape_inspections_r2996 i
  full outer join floor_marking_tape_replacements_r2996 r on r.engineer_code = i.engineer_code
  group by coalesce(i.engineer_code, r.engineer_code)
  order by rework_count desc, inspections desc;
end; $$;

create or replace function founder_fmt_replacement_outcomes_r2996()
returns table(outcome text, n int, total_meters numeric, avg_cost_rupees numeric, avg_cure_hours numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.outcome, count(*)::int, sum(r.meters_replaced)::numeric,
    round(avg(r.cost_rupees),2)::numeric, round(avg(r.cure_hours),2)::numeric
  from floor_marking_tape_replacements_r2996 r
  group by r.outcome
  order by n desc;
end; $$;

create or replace function founder_fmt_surface_prep_efficacy_r2996()
returns table(surface_prep text, replacements int, excellent_count int, rework_or_failed int, avg_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.surface_prep, count(*)::int,
    (count(*) filter (where r.outcome = 'excellent'))::int,
    (count(*) filter (where r.outcome in ('rework_needed','failed_24h')))::int,
    round(avg(r.cost_rupees),2)::numeric
  from floor_marking_tape_replacements_r2996 r
  group by r.surface_prep
  order by excellent_count desc;
end; $$;

revoke all on function founder_fmt_inspection_summary_r2996() from public, anon;
revoke all on function founder_fmt_status_breakdown_r2996() from public, anon;
revoke all on function founder_fmt_zone_type_health_r2996() from public, anon;
revoke all on function founder_fmt_urgent_replacements_r2996() from public, anon;
revoke all on function founder_fmt_engineer_performance_r2996() from public, anon;
revoke all on function founder_fmt_replacement_outcomes_r2996() from public, anon;
revoke all on function founder_fmt_surface_prep_efficacy_r2996() from public, anon;

grant execute on function founder_fmt_inspection_summary_r2996() to authenticated;
grant execute on function founder_fmt_status_breakdown_r2996() to authenticated;
grant execute on function founder_fmt_zone_type_health_r2996() to authenticated;
grant execute on function founder_fmt_urgent_replacements_r2996() to authenticated;
grant execute on function founder_fmt_engineer_performance_r2996() to authenticated;
grant execute on function founder_fmt_replacement_outcomes_r2996() to authenticated;
grant execute on function founder_fmt_surface_prep_efficacy_r2996() to authenticated;
