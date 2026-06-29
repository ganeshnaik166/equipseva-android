-- Round r2936 — Customer Monthly Engineer Repair-Job Customer-Education Minutes Tracker

create table if not exists customer_education_minutes_r2936 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  month_label text not null,
  customer_org_name text not null,
  engineer_handle text not null,
  repair_job_code text not null,
  topic text not null check (topic in ('preventive_care','safety_protocols','calibration_basics','consumable_handling','infection_control','user_settings','troubleshooting','escalation_path')),
  minutes_taught int not null check (minutes_taught between 1 and 240),
  delivery_mode text not null check (delivery_mode in ('in_person','video_call','hands_on_drill','quick_recap')),
  customer_satisfaction int check (customer_satisfaction between 1 and 5),
  status text not null default 'logged' check (status in ('logged','verified','disputed','reimbursed'))
);
alter table customer_education_minutes_r2936 enable row level security;

create table if not exists customer_education_monthly_rollup_r2936 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  month_label text not null,
  customer_org_name text not null,
  total_minutes int not null default 0,
  total_jobs int not null default 0,
  unique_engineers int not null default 0,
  avg_satisfaction numeric(3,2),
  tier_band text not null check (tier_band in ('gold','silver','bronze','watchlist'))
);
alter table customer_education_monthly_rollup_r2936 enable row level security;

insert into customer_education_minutes_r2936 (month_label, customer_org_name, engineer_handle, repair_job_code, topic, minutes_taught, delivery_mode, customer_satisfaction, status) values
('2026-06','Apollo Hyderabad','eng_ravi','RJ-88201','preventive_care',32,'in_person',5,'verified'),
('2026-06','Apollo Hyderabad','eng_ravi','RJ-88204','safety_protocols',18,'quick_recap',4,'verified'),
('2026-06','KIMS Secunderabad','eng_priya','RJ-88212','calibration_basics',45,'hands_on_drill',5,'reimbursed'),
('2026-06','KIMS Secunderabad','eng_arjun','RJ-88220','consumable_handling',22,'in_person',4,'verified'),
('2026-06','Yashoda Somajiguda','eng_meera','RJ-88231','infection_control',38,'in_person',5,'verified'),
('2026-06','Yashoda Somajiguda','eng_meera','RJ-88239','user_settings',12,'video_call',3,'disputed'),
('2026-06','Care Banjara Hills','eng_kiran','RJ-88245','troubleshooting',55,'hands_on_drill',5,'reimbursed'),
('2026-06','Care Banjara Hills','eng_kiran','RJ-88251','escalation_path',9,'quick_recap',4,'logged'),
('2026-06','Continental Gachibowli','eng_lakshmi','RJ-88262','preventive_care',28,'in_person',5,'verified'),
('2026-06','Continental Gachibowli','eng_sahil','RJ-88270','safety_protocols',15,'video_call',3,'logged'),
('2026-06','Sunshine Paradise','eng_naveen','RJ-88278','calibration_basics',40,'hands_on_drill',5,'verified'),
('2026-06','Sunshine Paradise','eng_naveen','RJ-88284','infection_control',25,'in_person',4,'verified'),
('2026-05','Apollo Hyderabad','eng_ravi','RJ-87102','user_settings',20,'quick_recap',4,'reimbursed'),
('2026-05','KIMS Secunderabad','eng_priya','RJ-87118','troubleshooting',50,'hands_on_drill',5,'reimbursed'),
('2026-05','Yashoda Somajiguda','eng_meera','RJ-87125','escalation_path',8,'video_call',3,'logged'),
('2026-05','Care Banjara Hills','eng_kiran','RJ-87133','preventive_care',35,'in_person',5,'reimbursed'),
('2026-05','Continental Gachibowli','eng_lakshmi','RJ-87141','consumable_handling',18,'quick_recap',4,'verified'),
('2026-05','Sunshine Paradise','eng_naveen','RJ-87149','safety_protocols',30,'in_person',5,'verified');

insert into customer_education_monthly_rollup_r2936 (month_label, customer_org_name, total_minutes, total_jobs, unique_engineers, avg_satisfaction, tier_band) values
('2026-06','Apollo Hyderabad',50,2,1,4.50,'silver'),
('2026-06','KIMS Secunderabad',67,2,2,4.50,'gold'),
('2026-06','Yashoda Somajiguda',50,2,1,4.00,'silver'),
('2026-06','Care Banjara Hills',64,2,1,4.50,'gold'),
('2026-06','Continental Gachibowli',43,2,2,4.00,'bronze'),
('2026-06','Sunshine Paradise',65,2,1,4.50,'gold'),
('2026-05','Apollo Hyderabad',20,1,1,4.00,'bronze'),
('2026-05','KIMS Secunderabad',50,1,1,5.00,'gold'),
('2026-05','Yashoda Somajiguda',8,1,1,3.00,'watchlist'),
('2026-05','Care Banjara Hills',35,1,1,5.00,'silver'),
('2026-05','Continental Gachibowli',18,1,1,4.00,'watchlist'),
('2026-05','Sunshine Paradise',30,1,1,5.00,'silver');

create or replace function r2936_top_customers_by_minutes()
returns table(customer_org_name text, total_minutes bigint, total_jobs bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.customer_org_name, sum(m.minutes_taught)::bigint, count(*)::bigint
  from customer_education_minutes_r2936 m
  where m.month_label = '2026-06'
  group by m.customer_org_name
  order by sum(m.minutes_taught) desc;
end;$$;

create or replace function r2936_minutes_by_topic()
returns table(topic text, total_minutes bigint, sessions bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.topic, sum(m.minutes_taught)::bigint, count(*)::bigint
  from customer_education_minutes_r2936 m
  group by m.topic
  order by sum(m.minutes_taught) desc;
end;$$;

create or replace function r2936_engineer_leaderboard()
returns table(engineer_handle text, total_minutes bigint, customers_touched bigint, avg_csat numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.engineer_handle, sum(m.minutes_taught)::bigint,
    count(distinct m.customer_org_name)::bigint,
    round(avg(m.customer_satisfaction)::numeric,2)
  from customer_education_minutes_r2936 m
  group by m.engineer_handle
  order by sum(m.minutes_taught) desc;
end;$$;

create or replace function r2936_delivery_mode_breakdown()
returns table(delivery_mode text, sessions bigint, minutes bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.delivery_mode, count(*)::bigint, sum(m.minutes_taught)::bigint
  from customer_education_minutes_r2936 m
  group by m.delivery_mode
  order by sum(m.minutes_taught) desc;
end;$$;

create or replace function r2936_status_funnel()
returns table(status text, sessions bigint, minutes bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.status, count(*)::bigint, sum(m.minutes_taught)::bigint
  from customer_education_minutes_r2936 m
  group by m.status
  order by sum(m.minutes_taught) desc;
end;$$;

create or replace function r2936_tier_band_rollup()
returns table(tier_band text, customers bigint, total_minutes bigint, avg_csat numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.tier_band, count(*)::bigint, sum(r.total_minutes)::bigint,
    round(avg(r.avg_satisfaction)::numeric,2)
  from customer_education_monthly_rollup_r2936 r
  where r.month_label = '2026-06'
  group by r.tier_band
  order by sum(r.total_minutes) desc;
end;$$;

create or replace function r2936_month_over_month()
returns table(month_label text, total_minutes bigint, total_jobs bigint, customers bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.month_label, sum(m.minutes_taught)::bigint, count(*)::bigint,
    count(distinct m.customer_org_name)::bigint
  from customer_education_minutes_r2936 m
  group by m.month_label
  order by m.month_label desc;
end;$$;

revoke execute on function r2936_top_customers_by_minutes() from public, anon;
revoke execute on function r2936_minutes_by_topic() from public, anon;
revoke execute on function r2936_engineer_leaderboard() from public, anon;
revoke execute on function r2936_delivery_mode_breakdown() from public, anon;
revoke execute on function r2936_status_funnel() from public, anon;
revoke execute on function r2936_tier_band_rollup() from public, anon;
revoke execute on function r2936_month_over_month() from public, anon;

grant execute on function r2936_top_customers_by_minutes() to authenticated;
grant execute on function r2936_minutes_by_topic() to authenticated;
grant execute on function r2936_engineer_leaderboard() to authenticated;
grant execute on function r2936_delivery_mode_breakdown() to authenticated;
grant execute on function r2936_status_funnel() to authenticated;
grant execute on function r2936_tier_band_rollup() to authenticated;
grant execute on function r2936_month_over_month() to authenticated;
