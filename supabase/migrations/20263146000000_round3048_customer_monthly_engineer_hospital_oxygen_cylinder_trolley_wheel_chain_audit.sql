-- Round 3048: Customer Monthly Engineer Hospital Oxygen-Cylinder Trolley Wheel & Chain Audit

create table if not exists public.oxygen_trolley_wheel_audits_r3048 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_name text not null,
  city text not null,
  trolley_code text not null,
  wheel_position text not null check (wheel_position in ('front_left','front_right','rear_left','rear_right','caster_swivel')),
  wheel_condition text not null check (wheel_condition in ('ok','worn','cracked','seized','missing')),
  chain_tension_mm numeric(6,2) not null check (chain_tension_mm >= 0 and chain_tension_mm <= 50),
  chain_rust_score int not null check (chain_rust_score between 0 and 10),
  rolling_resistance_n numeric(6,2) not null check (rolling_resistance_n >= 0 and rolling_resistance_n <= 200),
  engineer_name text not null,
  audit_month date not null,
  defect_count int not null check (defect_count >= 0),
  replacement_needed boolean not null default false,
  cost_estimate_rupees int check (cost_estimate_rupees >= 0)
);

create table if not exists public.oxygen_trolley_monthly_summary_r3048 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_name text not null,
  audit_month date not null,
  total_trolleys int not null check (total_trolleys >= 0),
  trolleys_passed int not null check (trolleys_passed >= 0),
  trolleys_failed int not null check (trolleys_failed >= 0),
  avg_chain_rust numeric(4,2) not null check (avg_chain_rust >= 0 and avg_chain_rust <= 10),
  avg_rolling_resistance numeric(6,2) not null check (avg_rolling_resistance >= 0),
  total_replacement_cost_rupees int not null check (total_replacement_cost_rupees >= 0),
  engineer_lead text not null,
  compliance_status text not null check (compliance_status in ('compliant','watch','breach','escalated')),
  customer_signoff boolean not null default false
);

alter table public.oxygen_trolley_wheel_audits_r3048 enable row level security;
alter table public.oxygen_trolley_monthly_summary_r3048 enable row level security;

drop policy if exists wheel_audit_founder_r3048 on public.oxygen_trolley_wheel_audits_r3048;
create policy wheel_audit_founder_r3048 on public.oxygen_trolley_wheel_audits_r3048
  for select to authenticated using (public.is_founder());

drop policy if exists wheel_summary_founder_r3048 on public.oxygen_trolley_monthly_summary_r3048;
create policy wheel_summary_founder_r3048 on public.oxygen_trolley_monthly_summary_r3048
  for select to authenticated using (public.is_founder());

insert into public.oxygen_trolley_wheel_audits_r3048
  (hospital_name, city, trolley_code, wheel_position, wheel_condition, chain_tension_mm, chain_rust_score, rolling_resistance_n, engineer_name, audit_month, defect_count, replacement_needed, cost_estimate_rupees) values
  ('Apollo Jubilee Hills','Hyderabad','TRL-AP-001','front_left','ok',12.50,1,45.20,'Ramesh Kumar','2026-06-01'::date,0,false,0),
  ('Apollo Jubilee Hills','Hyderabad','TRL-AP-002','rear_right','worn',18.30,4,78.40,'Ramesh Kumar','2026-06-01'::date,2,true,3200),
  ('Yashoda Secunderabad','Hyderabad','TRL-YS-014','caster_swivel','cracked',22.10,6,112.50,'Suresh Reddy','2026-06-01'::date,3,true,5800),
  ('Manipal Whitefield','Bangalore','TRL-MN-021','front_right','ok',10.80,2,42.10,'Karthik N','2026-06-01'::date,1,false,750),
  ('Fortis Bannerghatta','Bangalore','TRL-FR-008','rear_left','seized',35.00,9,180.00,'Karthik N','2026-06-01'::date,5,true,9500),
  ('AIIMS Delhi','Delhi','TRL-AI-033','front_left','worn',16.40,5,88.20,'Vikram Singh','2026-06-01'::date,2,true,2900),
  ('Max Saket','Delhi','TRL-MX-019','rear_right','ok',11.20,1,38.50,'Vikram Singh','2026-06-01'::date,0,false,0),
  ('Kokilaben Mumbai','Mumbai','TRL-KK-005','caster_swivel','worn',19.80,3,72.30,'Anil Patil','2026-06-01'::date,1,false,1200),
  ('Hinduja Mahim','Mumbai','TRL-HJ-027','front_right','missing',0.00,0,0.00,'Anil Patil','2026-06-01'::date,4,true,7400),
  ('CMC Vellore','Vellore','TRL-CM-012','rear_left','ok',13.50,2,48.70,'Joseph Mathew','2026-06-01'::date,0,false,0),
  ('SCTIMST Trivandrum','Trivandrum','TRL-SC-006','front_left','cracked',24.60,7,128.40,'Joseph Mathew','2026-06-01'::date,3,true,6100),
  ('Tata Memorial Parel','Mumbai','TRL-TM-018','caster_swivel','ok',12.00,1,40.20,'Anil Patil','2026-06-01'::date,0,false,0),
  ('Sankara Nethralaya','Chennai','TRL-SN-009','rear_right','worn',17.20,4,82.60,'Murali T','2026-06-01'::date,2,true,2400),
  ('PGI Chandigarh','Chandigarh','TRL-PG-031','front_right','seized',31.00,8,165.00,'Harpreet S','2026-06-01'::date,5,true,8900),
  ('NIMHANS Bangalore','Bangalore','TRL-NM-024','rear_left','ok',11.60,2,44.30,'Karthik N','2026-06-01'::date,1,false,650),
  ('JIPMER Puducherry','Puducherry','TRL-JP-013','front_left','worn',20.40,5,95.10,'Murali T','2026-06-01'::date,2,true,3600),
  ('SGPGI Lucknow','Lucknow','TRL-SG-007','caster_swivel','cracked',26.80,7,138.20,'Vikram Singh','2026-06-01'::date,3,true,6800),
  ('KEM Parel','Mumbai','TRL-KM-029','rear_right','ok',12.80,1,41.60,'Anil Patil','2026-06-01'::date,0,false,0);

insert into public.oxygen_trolley_monthly_summary_r3048
  (hospital_name, audit_month, total_trolleys, trolleys_passed, trolleys_failed, avg_chain_rust, avg_rolling_resistance, total_replacement_cost_rupees, engineer_lead, compliance_status, customer_signoff) values
  ('Apollo Jubilee Hills','2026-06-01'::date,42,38,4,2.30,52.40,18400,'Ramesh Kumar','compliant',true),
  ('Yashoda Secunderabad','2026-06-01'::date,38,29,9,5.10,98.20,42800,'Suresh Reddy','watch',true),
  ('Manipal Whitefield','2026-06-01'::date,51,47,4,1.80,46.20,12600,'Karthik N','compliant',true),
  ('Fortis Bannerghatta','2026-06-01'::date,34,22,12,7.20,142.50,68400,'Karthik N','breach',false),
  ('AIIMS Delhi','2026-06-01'::date,89,76,13,3.40,72.80,54200,'Vikram Singh','watch',true),
  ('Max Saket','2026-06-01'::date,46,43,3,1.60,41.20,9800,'Vikram Singh','compliant',true),
  ('Kokilaben Mumbai','2026-06-01'::date,55,48,7,2.80,68.40,28600,'Anil Patil','compliant',true),
  ('Hinduja Mahim','2026-06-01'::date,41,28,13,6.40,128.30,71200,'Anil Patil','breach',false),
  ('CMC Vellore','2026-06-01'::date,67,62,5,2.10,49.80,16400,'Joseph Mathew','compliant',true),
  ('SCTIMST Trivandrum','2026-06-01'::date,29,21,8,5.80,108.40,38600,'Joseph Mathew','watch',true),
  ('Tata Memorial Parel','2026-06-01'::date,48,46,2,1.40,40.60,7200,'Anil Patil','compliant',true),
  ('Sankara Nethralaya','2026-06-01'::date,32,28,4,2.60,58.20,15800,'Murali T','compliant',true),
  ('PGI Chandigarh','2026-06-01'::date,72,54,18,7.80,148.20,89400,'Harpreet S','escalated',false),
  ('NIMHANS Bangalore','2026-06-01'::date,38,35,3,1.90,45.30,11200,'Karthik N','compliant',true),
  ('JIPMER Puducherry','2026-06-01'::date,44,36,8,4.20,86.40,32800,'Murali T','watch',true);

create or replace function public.r3048_wheel_condition_breakdown()
returns table(wheel_condition text, audits int, replace_needed int, avg_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.wheel_condition,
         count(*)::int,
         (count(*) filter (where w.replacement_needed))::int,
         round(avg(coalesce(w.cost_estimate_rupees,0))::numeric,2)
  from public.oxygen_trolley_wheel_audits_r3048 w
  group by w.wheel_condition
  order by count(*) desc;
end;$$;

create or replace function public.r3048_city_risk()
returns table(city text, audits int, defects int, replace_cost int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.city,
         count(*)::int,
         sum(w.defect_count)::int,
         sum(coalesce(w.cost_estimate_rupees,0))::int
  from public.oxygen_trolley_wheel_audits_r3048 w
  group by w.city
  order by sum(w.defect_count) desc;
end;$$;

create or replace function public.r3048_engineer_load()
returns table(engineer_name text, trolleys_audited int, replace_flagged int, avg_rust numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.engineer_name,
         count(*)::int,
         (count(*) filter (where w.replacement_needed))::int,
         round(avg(w.chain_rust_score)::numeric,2)
  from public.oxygen_trolley_wheel_audits_r3048 w
  group by w.engineer_name
  order by count(*) desc;
end;$$;

create or replace function public.r3048_hospital_compliance()
returns table(hospital_name text, status text, total int, failed int, cost int, signoff boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.hospital_name, s.compliance_status, s.total_trolleys, s.trolleys_failed,
         s.total_replacement_cost_rupees, s.customer_signoff
  from public.oxygen_trolley_monthly_summary_r3048 s
  order by s.trolleys_failed desc;
end;$$;

create or replace function public.r3048_breach_hospitals()
returns table(hospital_name text, engineer_lead text, failed int, avg_rust numeric, cost int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.hospital_name, s.engineer_lead, s.trolleys_failed, s.avg_chain_rust, s.total_replacement_cost_rupees
  from public.oxygen_trolley_monthly_summary_r3048 s
  where s.compliance_status in ('breach','escalated')
  order by s.trolleys_failed desc;
end;$$;

create or replace function public.r3048_wheel_position_defects()
returns table(wheel_position text, audits int, defects int, avg_resistance numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.wheel_position,
         count(*)::int,
         sum(w.defect_count)::int,
         round(avg(w.rolling_resistance_n)::numeric,2)
  from public.oxygen_trolley_wheel_audits_r3048 w
  group by w.wheel_position
  order by sum(w.defect_count) desc;
end;$$;

create or replace function public.r3048_kpis()
returns table(metric text, value text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select 'total_audits'::text, count(*)::text from public.oxygen_trolley_wheel_audits_r3048
  union all
  select 'replacement_flagged'::text, (count(*) filter (where replacement_needed))::text from public.oxygen_trolley_wheel_audits_r3048
  union all
  select 'avg_chain_rust'::text, round(avg(chain_rust_score)::numeric,2)::text from public.oxygen_trolley_wheel_audits_r3048
  union all
  select 'total_replacement_cost_rupees'::text, sum(coalesce(cost_estimate_rupees,0))::text from public.oxygen_trolley_wheel_audits_r3048
  union all
  select 'hospitals_audited'::text, count(distinct hospital_name)::text from public.oxygen_trolley_monthly_summary_r3048
  union all
  select 'breach_hospitals'::text, (count(*) filter (where compliance_status in ('breach','escalated')))::text from public.oxygen_trolley_monthly_summary_r3048
  union all
  select 'customer_signoff_rate_pct'::text, round((count(*) filter (where customer_signoff))::numeric * 100.0 / nullif(count(*),0),2)::text from public.oxygen_trolley_monthly_summary_r3048;
end;$$;

revoke all on function public.r3048_wheel_condition_breakdown() from public, anon;
revoke all on function public.r3048_city_risk() from public, anon;
revoke all on function public.r3048_engineer_load() from public, anon;
revoke all on function public.r3048_hospital_compliance() from public, anon;
revoke all on function public.r3048_breach_hospitals() from public, anon;
revoke all on function public.r3048_wheel_position_defects() from public, anon;
revoke all on function public.r3048_kpis() from public, anon;

grant execute on function public.r3048_wheel_condition_breakdown() to authenticated;
grant execute on function public.r3048_city_risk() to authenticated;
grant execute on function public.r3048_engineer_load() to authenticated;
grant execute on function public.r3048_hospital_compliance() to authenticated;
grant execute on function public.r3048_breach_hospitals() to authenticated;
grant execute on function public.r3048_wheel_position_defects() to authenticated;
grant execute on function public.r3048_kpis() to authenticated;
