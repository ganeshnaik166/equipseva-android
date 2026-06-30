-- Round 3072: Customer Monthly Engineer Hospital Bedside Tablet Charging Cable Wear & Lock Discipline

create table if not exists public.tablet_charging_cable_inspections_r3072 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  hospital_org_id uuid,
  hospital_name text not null,
  ward_code text not null,
  bedside_tablet_serial text not null,
  cable_type text not null check (cable_type in ('usb_c_pd','lightning_mfi','micro_usb','barrel_dc','magsafe')),
  inspection_date date not null,
  engineer_user_id uuid,
  engineer_name text not null,
  wear_score_pct numeric(5,2) not null check (wear_score_pct >= 0 and wear_score_pct <= 100),
  jacket_condition text not null check (jacket_condition in ('intact','scuffed','cracked','exposed_shield','frayed')),
  connector_play_mm numeric(4,2) not null check (connector_play_mm >= 0 and connector_play_mm <= 10),
  continuity_ok boolean not null,
  fast_charge_negotiated boolean not null,
  lock_tether_present boolean not null,
  lock_torque_nm numeric(4,2) check (lock_torque_nm >= 0 and lock_torque_nm <= 5),
  replaced_on_visit boolean not null default false,
  verdict text not null check (verdict in ('pass','watch','replace','urgent_replace','escalate')),
  notes text
);

create table if not exists public.bedside_tablet_lock_discipline_r3072 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  hospital_org_id uuid,
  hospital_name text not null,
  ward_code text not null,
  bedside_tablet_serial text not null,
  audit_month date not null,
  lock_kit_model text not null check (lock_kit_model in ('kensington_mini','noble_wedge','maclocks_ledge','custom_bracket','no_kit')),
  lock_engaged_pct numeric(5,2) not null check (lock_engaged_pct >= 0 and lock_engaged_pct <= 100),
  cable_strain_relief_ok boolean not null,
  unauthorized_unplug_events int not null check (unauthorized_unplug_events >= 0),
  theft_attempts int not null check (theft_attempts >= 0),
  staff_acknowledged_sop boolean not null,
  monthly_visit_completed boolean not null,
  discipline_grade text not null check (discipline_grade in ('A','B','C','D','F')),
  remediation_due_date date,
  customer_signoff_user_id uuid,
  remarks text
);

alter table public.tablet_charging_cable_inspections_r3072 enable row level security;
alter table public.bedside_tablet_lock_discipline_r3072 enable row level security;

drop policy if exists tcci_r3072_founder_select on public.tablet_charging_cable_inspections_r3072;
create policy tcci_r3072_founder_select on public.tablet_charging_cable_inspections_r3072 for select using (is_founder());

drop policy if exists btld_r3072_founder_select on public.bedside_tablet_lock_discipline_r3072;
create policy btld_r3072_founder_select on public.bedside_tablet_lock_discipline_r3072 for select using (is_founder());

insert into public.tablet_charging_cable_inspections_r3072
  (hospital_name, ward_code, bedside_tablet_serial, cable_type, inspection_date, engineer_name, wear_score_pct, jacket_condition, connector_play_mm, continuity_ok, fast_charge_negotiated, lock_tether_present, lock_torque_nm, replaced_on_visit, verdict, notes)
values
  ('Apollo Hyderabad','ICU-A','TAB-AP-001','usb_c_pd','2026-06-01'::date,'Ravi Kumar',12.5,'intact',0.30,true,true,true,1.20,false,'pass','baseline ok'),
  ('Apollo Hyderabad','ICU-A','TAB-AP-002','usb_c_pd','2026-06-01'::date,'Ravi Kumar',38.0,'scuffed',0.80,true,true,true,1.10,false,'watch','jacket scuffed at strain relief'),
  ('Apollo Hyderabad','ICU-B','TAB-AP-003','lightning_mfi','2026-06-02'::date,'Sneha Reddy',62.0,'cracked',1.40,true,false,true,0.90,true,'replace','fast-charge dropped to 5W'),
  ('Yashoda Secunderabad','ER-1','TAB-YS-010','usb_c_pd','2026-06-02'::date,'Imran Shaikh',81.0,'exposed_shield',2.10,false,false,false,null,true,'urgent_replace','shield exposed; replaced on visit'),
  ('Yashoda Secunderabad','ER-1','TAB-YS-011','barrel_dc','2026-06-03'::date,'Imran Shaikh',22.0,'intact',0.50,true,false,true,1.30,false,'pass','barrel still tight'),
  ('KIMS Kondapur','OPD-3','TAB-KI-020','usb_c_pd','2026-06-03'::date,'Anitha Rao',45.0,'scuffed',0.70,true,true,true,1.00,false,'watch','watchlist next month'),
  ('KIMS Kondapur','OPD-3','TAB-KI-021','magsafe','2026-06-04'::date,'Anitha Rao',9.0,'intact',0.10,true,true,true,0.80,false,'pass','magsafe baseline'),
  ('Care Banjara','WARD-2','TAB-CB-030','micro_usb','2026-06-04'::date,'Karan Verma',74.0,'frayed',1.90,true,false,true,0.70,true,'replace','frayed micro-usb retired'),
  ('Care Banjara','WARD-2','TAB-CB-031','usb_c_pd','2026-06-05'::date,'Karan Verma',16.0,'intact',0.40,true,true,true,1.40,false,'pass','clean'),
  ('Rainbow Children','NICU-1','TAB-RB-040','usb_c_pd','2026-06-05'::date,'Priya Nair',58.0,'cracked',1.20,true,true,false,null,false,'escalate','no tether on NICU bedside'),
  ('Rainbow Children','NICU-1','TAB-RB-041','usb_c_pd','2026-06-06'::date,'Priya Nair',31.0,'scuffed',0.60,true,true,true,1.10,false,'watch','revisit 30d'),
  ('Continental Gachibowli','ICU-C','TAB-CG-050','lightning_mfi','2026-06-06'::date,'Vikram Singh',88.0,'exposed_shield',2.40,false,false,true,0.50,true,'urgent_replace','intermittent continuity'),
  ('Continental Gachibowli','ICU-C','TAB-CG-051','usb_c_pd','2026-06-07'::date,'Vikram Singh',19.0,'intact',0.30,true,true,true,1.50,false,'pass','torque good'),
  ('AIG Gachibowli','ENDO-1','TAB-AI-060','usb_c_pd','2026-06-07'::date,'Meera Joshi',41.0,'scuffed',0.90,true,true,true,1.20,false,'watch','schedule replace in 60d'),
  ('AIG Gachibowli','ENDO-1','TAB-AI-061','usb_c_pd','2026-06-08'::date,'Meera Joshi',7.0,'intact',0.20,true,true,true,1.30,false,'pass','new cable'),
  ('Sunshine Paradise','CARDIO-2','TAB-SS-070','barrel_dc','2026-06-08'::date,'Naveen Goud',55.0,'cracked',1.00,true,false,true,0.80,false,'replace','schedule swap'),
  ('Sunshine Paradise','CARDIO-2','TAB-SS-071','usb_c_pd','2026-06-09'::date,'Naveen Goud',23.0,'intact',0.40,true,true,true,1.10,false,'pass','clean'),
  ('Olive Asian','GEN-1','TAB-OA-080','usb_c_pd','2026-06-09'::date,'Divya Sharma',69.0,'frayed',1.60,true,true,true,0.60,true,'replace','frayed near plug'),
  ('Olive Asian','GEN-1','TAB-OA-081','micro_usb','2026-06-10'::date,'Divya Sharma',92.0,'exposed_shield',2.80,false,false,false,null,true,'urgent_replace','EOL micro_usb pulled'),
  ('Medicover HiTec','ICU-D','TAB-MC-090','usb_c_pd','2026-06-10'::date,'Rohit Pillai',27.0,'scuffed',0.50,true,true,true,1.40,false,'watch','minor scuff');

insert into public.bedside_tablet_lock_discipline_r3072
  (hospital_name, ward_code, bedside_tablet_serial, audit_month, lock_kit_model, lock_engaged_pct, cable_strain_relief_ok, unauthorized_unplug_events, theft_attempts, staff_acknowledged_sop, monthly_visit_completed, discipline_grade, remediation_due_date, remarks)
values
  ('Apollo Hyderabad','ICU-A','TAB-AP-001','2026-06-01'::date,'kensington_mini',98.0,true,1,0,true,true,'A',null,'gold standard ward'),
  ('Apollo Hyderabad','ICU-A','TAB-AP-002','2026-06-01'::date,'kensington_mini',95.0,true,2,0,true,true,'A',null,'consistent'),
  ('Apollo Hyderabad','ICU-B','TAB-AP-003','2026-06-01'::date,'noble_wedge',88.0,true,4,0,true,true,'B','2026-07-15'::date,'wedge slot loosening'),
  ('Yashoda Secunderabad','ER-1','TAB-YS-010','2026-06-01'::date,'maclocks_ledge',72.0,false,9,1,false,true,'C','2026-07-10'::date,'SOP refresh required'),
  ('Yashoda Secunderabad','ER-1','TAB-YS-011','2026-06-01'::date,'maclocks_ledge',81.0,true,3,0,true,true,'B','2026-07-20'::date,'strain relief retorque'),
  ('KIMS Kondapur','OPD-3','TAB-KI-020','2026-06-01'::date,'custom_bracket',90.0,true,2,0,true,true,'A',null,'bracket holding well'),
  ('KIMS Kondapur','OPD-3','TAB-KI-021','2026-06-01'::date,'custom_bracket',93.0,true,1,0,true,true,'A',null,'magsafe + bracket combo'),
  ('Care Banjara','WARD-2','TAB-CB-030','2026-06-01'::date,'no_kit',35.0,false,18,2,false,false,'F','2026-06-25'::date,'no kit installed; ESCALATED'),
  ('Care Banjara','WARD-2','TAB-CB-031','2026-06-01'::date,'kensington_mini',87.0,true,4,0,true,true,'B','2026-07-18'::date,'good baseline'),
  ('Rainbow Children','NICU-1','TAB-RB-040','2026-06-01'::date,'no_kit',12.0,false,22,3,false,false,'F','2026-06-22'::date,'NICU urgent: no tether'),
  ('Rainbow Children','NICU-1','TAB-RB-041','2026-06-01'::date,'noble_wedge',79.0,true,5,0,true,true,'C','2026-07-12'::date,'install proper kit'),
  ('Continental Gachibowli','ICU-C','TAB-CG-050','2026-06-01'::date,'kensington_mini',60.0,false,11,1,false,true,'D','2026-07-05'::date,'lock often disengaged'),
  ('Continental Gachibowli','ICU-C','TAB-CG-051','2026-06-01'::date,'kensington_mini',96.0,true,0,0,true,true,'A',null,'exemplary'),
  ('AIG Gachibowli','ENDO-1','TAB-AI-060','2026-06-01'::date,'maclocks_ledge',84.0,true,3,0,true,true,'B','2026-07-25'::date,'minor improvement plan'),
  ('AIG Gachibowli','ENDO-1','TAB-AI-061','2026-06-01'::date,'maclocks_ledge',91.0,true,2,0,true,true,'A',null,'good'),
  ('Sunshine Paradise','CARDIO-2','TAB-SS-070','2026-06-01'::date,'custom_bracket',68.0,false,8,1,true,true,'C','2026-07-08'::date,'strain relief failing'),
  ('Sunshine Paradise','CARDIO-2','TAB-SS-071','2026-06-01'::date,'custom_bracket',86.0,true,3,0,true,true,'B','2026-07-28'::date,'bracket ok'),
  ('Olive Asian','GEN-1','TAB-OA-080','2026-06-01'::date,'no_kit',28.0,false,14,2,false,false,'F','2026-06-24'::date,'no kit; theft attempt logged'),
  ('Olive Asian','GEN-1','TAB-OA-081','2026-06-01'::date,'no_kit',18.0,false,20,3,false,false,'F','2026-06-23'::date,'urgent kit install'),
  ('Medicover HiTec','ICU-D','TAB-MC-090','2026-06-01'::date,'kensington_mini',89.0,true,3,0,true,true,'B','2026-07-30'::date,'on track');

-- RPC 1
create or replace function public.rpc_r3072_hospital_wear_rollup()
returns table(hospital_name text, inspections int, avg_wear numeric, urgent_replaces int, escalations int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.hospital_name,
         count(*)::int as inspections,
         round(avg(t.wear_score_pct)::numeric, 2) as avg_wear,
         (count(*) filter (where t.verdict = 'urgent_replace'))::int as urgent_replaces,
         (count(*) filter (where t.verdict = 'escalate'))::int as escalations
  from public.tablet_charging_cable_inspections_r3072 t
  group by t.hospital_name
  order by avg_wear desc;
end;
$$;

-- RPC 2
create or replace function public.rpc_r3072_cable_type_failure_mix()
returns table(cable_type text, total int, fail_count int, fail_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.cable_type,
         count(*)::int as total,
         (count(*) filter (where t.verdict in ('replace','urgent_replace','escalate')))::int as fail_count,
         round(100.0 * (count(*) filter (where t.verdict in ('replace','urgent_replace','escalate'))) / nullif(count(*),0), 2) as fail_pct
  from public.tablet_charging_cable_inspections_r3072 t
  group by t.cable_type
  order by fail_pct desc nulls last;
end;
$$;

-- RPC 3
create or replace function public.rpc_r3072_engineer_inspection_quality()
returns table(engineer_name text, visits int, replaced_count int, avg_torque numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.engineer_name,
         count(*)::int as visits,
         (count(*) filter (where t.replaced_on_visit))::int as replaced_count,
         round(avg(t.lock_torque_nm)::numeric, 2) as avg_torque
  from public.tablet_charging_cable_inspections_r3072 t
  group by t.engineer_name
  order by visits desc;
end;
$$;

-- RPC 4
create or replace function public.rpc_r3072_lock_discipline_grade_distribution()
returns table(discipline_grade text, hospitals int, avg_lock_engaged numeric, theft_attempts int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.discipline_grade,
         count(distinct b.hospital_name)::int as hospitals,
         round(avg(b.lock_engaged_pct)::numeric, 2) as avg_lock_engaged,
         coalesce(sum(b.theft_attempts),0)::int as theft_attempts
  from public.bedside_tablet_lock_discipline_r3072 b
  group by b.discipline_grade
  order by b.discipline_grade asc;
end;
$$;

-- RPC 5
create or replace function public.rpc_r3072_no_kit_red_alerts()
returns table(hospital_name text, ward_code text, bedside_tablet_serial text, unauthorized_unplug_events int, theft_attempts int, remediation_due_date date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.hospital_name, b.ward_code, b.bedside_tablet_serial, b.unauthorized_unplug_events, b.theft_attempts, b.remediation_due_date
  from public.bedside_tablet_lock_discipline_r3072 b
  where b.lock_kit_model = 'no_kit'
  order by b.theft_attempts desc, b.unauthorized_unplug_events desc;
end;
$$;

-- RPC 6
create or replace function public.rpc_r3072_jacket_condition_heatmap()
returns table(jacket_condition text, count_n int, avg_connector_play numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.jacket_condition,
         count(*)::int as count_n,
         round(avg(t.connector_play_mm)::numeric, 2) as avg_connector_play
  from public.tablet_charging_cable_inspections_r3072 t
  group by t.jacket_condition
  order by count_n desc;
end;
$$;

-- RPC 7
create or replace function public.rpc_r3072_monthly_visit_compliance()
returns table(hospital_name text, tablets int, visits_done int, compliance_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.hospital_name,
         count(*)::int as tablets,
         (count(*) filter (where b.monthly_visit_completed))::int as visits_done,
         round(100.0 * (count(*) filter (where b.monthly_visit_completed)) / nullif(count(*),0), 2) as compliance_pct
  from public.bedside_tablet_lock_discipline_r3072 b
  group by b.hospital_name
  order by compliance_pct asc nulls last;
end;
$$;

revoke all on public.tablet_charging_cable_inspections_r3072 from public, anon;
revoke all on public.bedside_tablet_lock_discipline_r3072 from public, anon;
grant select on public.tablet_charging_cable_inspections_r3072 to authenticated;
grant select on public.bedside_tablet_lock_discipline_r3072 to authenticated;

revoke all on function public.rpc_r3072_hospital_wear_rollup() from public, anon;
revoke all on function public.rpc_r3072_cable_type_failure_mix() from public, anon;
revoke all on function public.rpc_r3072_engineer_inspection_quality() from public, anon;
revoke all on function public.rpc_r3072_lock_discipline_grade_distribution() from public, anon;
revoke all on function public.rpc_r3072_no_kit_red_alerts() from public, anon;
revoke all on function public.rpc_r3072_jacket_condition_heatmap() from public, anon;
revoke all on function public.rpc_r3072_monthly_visit_compliance() from public, anon;

grant execute on function public.rpc_r3072_hospital_wear_rollup() to authenticated;
grant execute on function public.rpc_r3072_cable_type_failure_mix() to authenticated;
grant execute on function public.rpc_r3072_engineer_inspection_quality() to authenticated;
grant execute on function public.rpc_r3072_lock_discipline_grade_distribution() to authenticated;
grant execute on function public.rpc_r3072_no_kit_red_alerts() to authenticated;
grant execute on function public.rpc_r3072_jacket_condition_heatmap() to authenticated;
grant execute on function public.rpc_r3072_monthly_visit_compliance() to authenticated;
