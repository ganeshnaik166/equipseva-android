-- Round 2950: Engineer Monthly Customer Site Pre-Visit Equipment Risk Briefing Discipline

create table if not exists engineer_previsit_risk_briefings_r2950 (
  id uuid primary key default gen_random_uuid(),
  briefing_month date not null,
  engineer_name text not null,
  hospital_name text not null,
  city text not null,
  equipment_category text not null check (equipment_category in ('imaging','laboratory','life_support','surgical','dental','sterilization')),
  risk_tier text not null check (risk_tier in ('low','medium','high','critical')),
  briefing_status text not null check (briefing_status in ('completed_on_time','completed_late','skipped','pending')),
  briefing_duration_minutes int not null,
  risks_flagged int not null,
  parts_prepped int not null,
  quality_score int not null check (quality_score between 0 and 100),
  created_at timestamptz not null default now()
);

create table if not exists engineer_previsit_risk_outcomes_r2950 (
  id uuid primary key default gen_random_uuid(),
  outcome_month date not null,
  engineer_name text not null,
  briefings_total int not null,
  briefings_on_time int not null,
  visits_first_time_fix int not null,
  visits_repeat_required int not null,
  incidents_avoided int not null,
  customer_csat_avg numeric(4,2) not null,
  discipline_grade text not null check (discipline_grade in ('A+','A','B','C','D')),
  coaching_required boolean not null default false,
  created_at timestamptz not null default now()
);

alter table engineer_previsit_risk_briefings_r2950 enable row level security;
alter table engineer_previsit_risk_outcomes_r2950 enable row level security;

drop policy if exists pol_briefings_r2950 on engineer_previsit_risk_briefings_r2950;
create policy pol_briefings_r2950 on engineer_previsit_risk_briefings_r2950 for select using (is_founder());

drop policy if exists pol_outcomes_r2950 on engineer_previsit_risk_outcomes_r2950;
create policy pol_outcomes_r2950 on engineer_previsit_risk_outcomes_r2950 for select using (is_founder());

insert into engineer_previsit_risk_briefings_r2950 (briefing_month, engineer_name, hospital_name, city, equipment_category, risk_tier, briefing_status, briefing_duration_minutes, risks_flagged, parts_prepped, quality_score) values
('2026-06-01'::date,'Ravi Kumar','Apollo Jubilee','Hyderabad','imaging','high','completed_on_time',45,7,12,92),
('2026-06-01'::date,'Suresh Patel','Fortis Bannerghatta','Bengaluru','life_support','critical','completed_on_time',60,9,15,95),
('2026-06-01'::date,'Anil Sharma','Manipal Whitefield','Bengaluru','laboratory','medium','completed_late',30,4,6,68),
('2026-06-01'::date,'Vikram Singh','AIIMS Mangalagiri','Vijayawada','surgical','high','completed_on_time',50,6,10,88),
('2026-06-01'::date,'Deepa Reddy','KIMS Secunderabad','Hyderabad','dental','low','skipped',0,0,0,15),
('2026-06-01'::date,'Mohan Iyer','Yashoda Somajiguda','Hyderabad','sterilization','medium','completed_on_time',35,5,8,82),
('2026-06-01'::date,'Priya Nair','Rainbow Banjara','Hyderabad','imaging','high','completed_on_time',42,6,11,90),
('2026-06-01'::date,'Karthik Rao','Continental Gachibowli','Hyderabad','life_support','critical','pending',0,0,0,0),
('2026-06-01'::date,'Sneha Joshi','Care Banjara','Hyderabad','laboratory','low','completed_on_time',25,3,5,78),
('2026-06-01'::date,'Rahul Verma','Sunshine Secunderabad','Hyderabad','surgical','medium','completed_late',28,3,4,55),
('2026-06-01'::date,'Ravi Kumar','Star Hyderabad','Hyderabad','imaging','critical','completed_on_time',55,8,13,94),
('2026-06-01'::date,'Suresh Patel','Aster CMI','Bengaluru','life_support','high','completed_on_time',48,7,12,91),
('2026-06-01'::date,'Anil Sharma','Narayana Health','Bengaluru','laboratory','medium','skipped',0,0,0,10),
('2026-06-01'::date,'Vikram Singh','Citizens Specialty','Hyderabad','surgical','high','completed_on_time',46,6,9,87),
('2026-06-01'::date,'Mohan Iyer','Pace Hospitals','Hyderabad','sterilization','low','completed_on_time',22,2,4,75),
('2026-06-01'::date,'Priya Nair','Olive Hospital','Hyderabad','imaging','medium','completed_late',26,3,5,58),
('2026-06-01'::date,'Sneha Joshi','Virinchi Hospitals','Hyderabad','dental','low','completed_on_time',20,2,3,72),
('2026-06-01'::date,'Rahul Verma','Medicover Hitec','Hyderabad','surgical','critical','completed_on_time',58,9,14,93);

insert into engineer_previsit_risk_outcomes_r2950 (outcome_month, engineer_name, briefings_total, briefings_on_time, visits_first_time_fix, visits_repeat_required, incidents_avoided, customer_csat_avg, discipline_grade, coaching_required) values
('2026-06-01'::date,'Ravi Kumar',12,11,10,2,5,4.72,'A+',false),
('2026-06-01'::date,'Suresh Patel',14,13,12,2,7,4.68,'A+',false),
('2026-06-01'::date,'Anil Sharma',10,5,4,6,1,3.42,'C',true),
('2026-06-01'::date,'Vikram Singh',11,10,9,2,4,4.55,'A',false),
('2026-06-01'::date,'Deepa Reddy',8,2,3,5,0,2.85,'D',true),
('2026-06-01'::date,'Mohan Iyer',9,8,8,1,3,4.40,'A',false),
('2026-06-01'::date,'Priya Nair',10,8,7,3,3,4.18,'B',false),
('2026-06-01'::date,'Karthik Rao',7,1,2,5,0,2.50,'D',true),
('2026-06-01'::date,'Sneha Joshi',8,7,6,2,2,4.22,'B',false),
('2026-06-01'::date,'Rahul Verma',9,4,5,4,1,3.30,'C',true),
('2026-06-01'::date,'Lakshmi Pillai',11,10,9,2,4,4.50,'A',false),
('2026-06-01'::date,'Naveen Gupta',10,9,8,2,3,4.35,'A',false),
('2026-06-01'::date,'Sandeep Yadav',8,3,4,5,1,3.10,'C',true),
('2026-06-01'::date,'Ashok Pillai',12,12,11,1,6,4.80,'A+',false);

revoke all on engineer_previsit_risk_briefings_r2950 from public, anon;
revoke all on engineer_previsit_risk_outcomes_r2950 from public, anon;
grant select on engineer_previsit_risk_briefings_r2950 to authenticated;
grant select on engineer_previsit_risk_outcomes_r2950 to authenticated;

create or replace function rpc_r2950_discipline_summary()
returns table(metric text, value numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select 'total_briefings'::text, count(*)::numeric from engineer_previsit_risk_briefings_r2950
    union all select 'on_time_briefings', (count(*) filter (where briefing_status='completed_on_time'))::numeric from engineer_previsit_risk_briefings_r2950
    union all select 'skipped_briefings', (count(*) filter (where briefing_status='skipped'))::numeric from engineer_previsit_risk_briefings_r2950
    union all select 'avg_quality_score', round(avg(quality_score)::numeric,2) from engineer_previsit_risk_briefings_r2950
    union all select 'engineers_needing_coaching', (count(*) filter (where coaching_required))::numeric from engineer_previsit_risk_outcomes_r2950;
end; $$;

create or replace function rpc_r2950_by_engineer()
returns table(engineer_name text, briefings int, on_time int, avg_quality numeric, total_risks int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select b.engineer_name, count(*)::int,
      (count(*) filter (where b.briefing_status='completed_on_time'))::int,
      round(avg(b.quality_score)::numeric,2),
      sum(b.risks_flagged)::int
    from engineer_previsit_risk_briefings_r2950 b
    group by b.engineer_name order by avg(b.quality_score) desc;
end; $$;

create or replace function rpc_r2950_by_risk_tier()
returns table(risk_tier text, briefings int, completed_on_time int, avg_duration numeric, avg_quality numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select b.risk_tier, count(*)::int,
      (count(*) filter (where b.briefing_status='completed_on_time'))::int,
      round(avg(b.briefing_duration_minutes)::numeric,2),
      round(avg(b.quality_score)::numeric,2)
    from engineer_previsit_risk_briefings_r2950 b
    group by b.risk_tier order by b.risk_tier;
end; $$;

create or replace function rpc_r2950_by_equipment_category()
returns table(equipment_category text, briefings int, risks_flagged int, parts_prepped int, avg_quality numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select b.equipment_category, count(*)::int, sum(b.risks_flagged)::int, sum(b.parts_prepped)::int,
      round(avg(b.quality_score)::numeric,2)
    from engineer_previsit_risk_briefings_r2950 b
    group by b.equipment_category order by sum(b.risks_flagged) desc;
end; $$;

create or replace function rpc_r2950_outcomes_grade()
returns table(discipline_grade text, engineers int, avg_csat numeric, total_incidents_avoided int, coaching_needed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select o.discipline_grade, count(*)::int, round(avg(o.customer_csat_avg)::numeric,2),
      sum(o.incidents_avoided)::int, (count(*) filter (where o.coaching_required))::int
    from engineer_previsit_risk_outcomes_r2950 o
    group by o.discipline_grade order by o.discipline_grade;
end; $$;

create or replace function rpc_r2950_skipped_briefings()
returns table(engineer_name text, hospital_name text, equipment_category text, risk_tier text, briefing_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select b.engineer_name, b.hospital_name, b.equipment_category, b.risk_tier, b.briefing_status
    from engineer_previsit_risk_briefings_r2950 b
    where b.briefing_status in ('skipped','pending')
    order by b.risk_tier desc;
end; $$;

create or replace function rpc_r2950_coaching_roster()
returns table(engineer_name text, briefings_on_time int, briefings_total int, discipline_grade text, customer_csat_avg numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select o.engineer_name, o.briefings_on_time, o.briefings_total, o.discipline_grade, o.customer_csat_avg
    from engineer_previsit_risk_outcomes_r2950 o
    where o.coaching_required = true
    order by o.customer_csat_avg asc;
end; $$;

revoke all on function rpc_r2950_discipline_summary() from public, anon;
revoke all on function rpc_r2950_by_engineer() from public, anon;
revoke all on function rpc_r2950_by_risk_tier() from public, anon;
revoke all on function rpc_r2950_by_equipment_category() from public, anon;
revoke all on function rpc_r2950_outcomes_grade() from public, anon;
revoke all on function rpc_r2950_skipped_briefings() from public, anon;
revoke all on function rpc_r2950_coaching_roster() from public, anon;
grant execute on function rpc_r2950_discipline_summary() to authenticated;
grant execute on function rpc_r2950_by_engineer() to authenticated;
grant execute on function rpc_r2950_by_risk_tier() to authenticated;
grant execute on function rpc_r2950_by_equipment_category() to authenticated;
grant execute on function rpc_r2950_outcomes_grade() to authenticated;
grant execute on function rpc_r2950_skipped_briefings() to authenticated;
grant execute on function rpc_r2950_coaching_roster() to authenticated;
