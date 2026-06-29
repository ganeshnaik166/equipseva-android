-- Round r2997: Quarterly Strategic Founder-Spouse Family-Time Boundary & Wellness Tracker
-- HEAVY ★★★★

create table if not exists founder_spouse_family_boundaries_r2997 (
  id uuid primary key default gen_random_uuid(),
  quarter text not null check (quarter in ('Q1_2026','Q2_2026','Q3_2026','Q4_2026','Q1_2027')),
  boundary_category text not null check (boundary_category in ('dinner_protected','weekend_offsite','phone_curfew','vacation_block','date_night','school_event','anniversary','health_appt','family_dinner','no_laptop_zone','morning_walk','sleep_hours')),
  boundary_label text not null,
  spouse_name text not null default 'Priya',
  agreed_at timestamptz not null,
  honored_count int not null default 0,
  violated_count int not null default 0,
  total_count int not null default 0,
  honor_rate_pct numeric(5,2) not null default 0,
  status text not null check (status in ('active','renegotiating','paused','violated','retired')),
  spouse_satisfaction_1_5 int not null check (spouse_satisfaction_1_5 between 1 and 5),
  founder_stress_1_5 int not null check (founder_stress_1_5 between 1 and 5),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists founder_spouse_wellness_checkins_r2997 (
  id uuid primary key default gen_random_uuid(),
  quarter text not null check (quarter in ('Q1_2026','Q2_2026','Q3_2026','Q4_2026','Q1_2027')),
  checkin_week_starting date not null,
  boundary_id uuid references founder_spouse_family_boundaries_r2997(id) on delete cascade,
  checkin_type text not null check (checkin_type in ('weekly_sync','quarterly_review','crisis_chat','date_night_debrief','therapy_session','journal_entry','spouse_solo','founder_solo')),
  family_time_hours numeric(5,2) not null,
  work_hours numeric(5,2) not null,
  sleep_hours numeric(4,2) not null,
  exercise_minutes int not null default 0,
  mood_score_1_10 int not null check (mood_score_1_10 between 1 and 10),
  marriage_health_1_10 int not null check (marriage_health_1_10 between 1 and 10),
  conflict_count_week int not null default 0,
  resolution_count_week int not null default 0,
  wins_summary text,
  concerns_summary text,
  next_action text,
  created_at timestamptz not null default now()
);

alter table founder_spouse_family_boundaries_r2997 enable row level security;
alter table founder_spouse_wellness_checkins_r2997 enable row level security;

drop policy if exists boundaries_founder_read on founder_spouse_family_boundaries_r2997;
create policy boundaries_founder_read on founder_spouse_family_boundaries_r2997 for select using (is_founder());

drop policy if exists checkins_founder_read on founder_spouse_wellness_checkins_r2997;
create policy checkins_founder_read on founder_spouse_wellness_checkins_r2997 for select using (is_founder());

-- Seeds: boundaries (16 rows)
insert into founder_spouse_family_boundaries_r2997 (quarter, boundary_category, boundary_label, spouse_name, agreed_at, honored_count, violated_count, total_count, honor_rate_pct, status, spouse_satisfaction_1_5, founder_stress_1_5, notes) values
('Q2_2026','dinner_protected','Dinner 8-9pm phones away','Priya','2026-04-01'::timestamptz,78,12,90,86.67,'active',4,2,'Strong adherence'),
('Q2_2026','weekend_offsite','One Sunday/month no laptop','Priya','2026-04-01'::timestamptz,2,1,3,66.67,'renegotiating',3,3,'Cashfree crisis broke one'),
('Q2_2026','phone_curfew','No phone after 10pm','Priya','2026-04-05'::timestamptz,65,25,90,72.22,'active',3,3,'Slipping during fundraise'),
('Q2_2026','vacation_block','Goa 4 days unplugged June','Priya','2026-04-10'::timestamptz,4,0,4,100.00,'active',5,1,'Best week of year'),
('Q2_2026','date_night','Friday dinner out','Priya','2026-04-01'::timestamptz,10,3,13,76.92,'active',4,2,'Cinnabar most weeks'),
('Q2_2026','school_event','Daughter recital attendance','Priya','2026-04-15'::timestamptz,3,1,4,75.00,'active',4,2,'Missed one for board'),
('Q2_2026','anniversary','May 12 anniversary protected','Priya','2026-04-01'::timestamptz,1,0,1,100.00,'active',5,1,'Bandhavgarh trip'),
('Q2_2026','health_appt','Couples therapy biweekly','Priya','2026-04-20'::timestamptz,6,0,6,100.00,'active',5,2,'Dr Rao Banjara Hills'),
('Q2_2026','family_dinner','Sunday lunch in-laws','Priya','2026-04-01'::timestamptz,11,2,13,84.62,'active',4,2,'Mostly held'),
('Q2_2026','no_laptop_zone','Bedroom no-laptop','Priya','2026-04-01'::timestamptz,85,5,90,94.44,'active',5,1,'Best honored'),
('Q2_2026','morning_walk','6am walk together','Priya','2026-04-08'::timestamptz,55,35,90,61.11,'renegotiating',3,4,'Founder oversleeping'),
('Q2_2026','sleep_hours','7h minimum nightly','Priya','2026-04-01'::timestamptz,60,30,90,66.67,'active',3,4,'Cashfree week killed'),
('Q1_2026','dinner_protected','Dinner 8-9pm phones away','Priya','2026-01-05'::timestamptz,75,15,90,83.33,'retired',4,2,'Renewed Q2'),
('Q1_2026','vacation_block','Lonavala 3 days March','Priya','2026-01-10'::timestamptz,3,0,3,100.00,'retired',5,1,'Reset week'),
('Q3_2026','weekend_offsite','Two Sundays/month','Priya','2026-06-15'::timestamptz,0,0,0,0.00,'active',4,2,'Upcoming quarter'),
('Q3_2026','date_night','Saturday dinner','Priya','2026-06-20'::timestamptz,0,0,0,0.00,'active',4,2,'Q3 reboot');

-- Seeds: checkins (20 rows)
insert into founder_spouse_wellness_checkins_r2997 (quarter, checkin_week_starting, boundary_id, checkin_type, family_time_hours, work_hours, sleep_hours, exercise_minutes, mood_score_1_10, marriage_health_1_10, conflict_count_week, resolution_count_week, wins_summary, concerns_summary, next_action) values
('Q2_2026','2026-04-06'::date,null,'weekly_sync',14.5,72,6.5,90,7,8,1,1,'Date night held','Late night Sundays','Hold Sunday boundary'),
('Q2_2026','2026-04-13'::date,null,'weekly_sync',16,68,7,120,8,8,0,0,'Daughter recital attended','None','Continue'),
('Q2_2026','2026-04-20'::date,null,'therapy_session',2,65,7,60,7,7,2,2,'Honest convo about phone','Phone curfew slipping','Phone in drawer 10pm'),
('Q2_2026','2026-04-27'::date,null,'weekly_sync',12,80,5.5,30,5,6,2,1,'Cashfree shipped','Cashfree week brutal','Recovery weekend'),
('Q2_2026','2026-05-04'::date,null,'weekly_sync',18,60,7.5,150,9,9,0,0,'Goa booked','None','Goa prep'),
('Q2_2026','2026-05-11'::date,null,'date_night_debrief',20,55,7.5,120,9,10,0,0,'Anniversary Bandhavgarh','None','Photos to family'),
('Q2_2026','2026-05-18'::date,null,'weekly_sync',16,65,7,90,8,9,0,1,'Back from Bandhavgarh','School pickup missed','Calendar block'),
('Q2_2026','2026-05-25'::date,null,'therapy_session',2,68,6.5,60,7,8,1,1,'Forgave board incident','Travel-life balance','Limit weekend travel'),
('Q2_2026','2026-06-01'::date,null,'weekly_sync',14,75,6,90,6,7,1,1,'Investor pitch done','Sleep dropped','Sleep priority'),
('Q2_2026','2026-06-08'::date,null,'weekly_sync',22,50,8,180,9,9,0,0,'Goa unplugged','None','Hold this rhythm'),
('Q2_2026','2026-06-15'::date,null,'quarterly_review',18,60,7.5,120,9,9,3,3,'Q2 wrap','Q3 fundraise looming','Pre-negotiate Q3'),
('Q2_2026','2026-06-22'::date,null,'crisis_chat',8,90,5,0,4,5,3,1,'None','Cashfree emergency','24h recovery'),
('Q1_2026','2026-01-12'::date,null,'weekly_sync',15,70,7,90,7,8,1,1,'Year start aligned','New baseline','Q1 plan'),
('Q1_2026','2026-02-09'::date,null,'therapy_session',2,72,6.5,60,7,7,2,2,'Communication tools','Conflict avoidance','Direct asks'),
('Q1_2026','2026-03-09'::date,null,'weekly_sync',17,65,7,120,8,8,0,0,'Lonavala','None','Continue'),
('Q1_2026','2026-03-23'::date,null,'quarterly_review',16,68,7,100,8,8,5,5,'Q1 honest review','Phone curfew','Stricter Q2'),
('Q2_2026','2026-04-13'::date,null,'journal_entry',0,0,0,0,8,8,0,0,'Grateful for Priya patience','Solo reflection','Continue therapy'),
('Q2_2026','2026-05-04'::date,null,'spouse_solo',0,0,0,0,7,8,0,0,'Spouse weekend with mom','Founder solo time','Founder gym'),
('Q2_2026','2026-05-25'::date,null,'founder_solo',0,0,0,0,6,7,0,0,'Founder solo walk','Burnout signal','Reduce travel'),
('Q2_2026','2026-06-15'::date,null,'date_night_debrief',6,55,7,90,9,9,0,0,'Cinnabar 3rd time','None','Try new place');

-- RPC 1: boundary summary
create or replace function r2997_boundary_summary()
returns table(quarter text, total_boundaries int, active_boundaries int, avg_honor_rate numeric, avg_spouse_satisfaction numeric, avg_founder_stress numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.quarter,
    count(*)::int as total_boundaries,
    (count(*) filter (where b.status = 'active'))::int as active_boundaries,
    round(avg(b.honor_rate_pct),2) as avg_honor_rate,
    round(avg(b.spouse_satisfaction_1_5),2) as avg_spouse_satisfaction,
    round(avg(b.founder_stress_1_5),2) as avg_founder_stress
  from founder_spouse_family_boundaries_r2997 b
  group by b.quarter
  order by b.quarter desc;
end $$;

-- RPC 2: top honored boundaries
create or replace function r2997_top_honored()
returns table(boundary_label text, boundary_category text, honor_rate_pct numeric, spouse_satisfaction_1_5 int, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.boundary_label, b.boundary_category, b.honor_rate_pct, b.spouse_satisfaction_1_5, b.status
  from founder_spouse_family_boundaries_r2997 b
  where b.quarter = 'Q2_2026' and b.total_count > 0
  order by b.honor_rate_pct desc
  limit 10;
end $$;

-- RPC 3: at-risk boundaries
create or replace function r2997_at_risk_boundaries()
returns table(boundary_label text, boundary_category text, honor_rate_pct numeric, founder_stress_1_5 int, status text, notes text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.boundary_label, b.boundary_category, b.honor_rate_pct, b.founder_stress_1_5, b.status, b.notes
  from founder_spouse_family_boundaries_r2997 b
  where b.quarter = 'Q2_2026' and (b.honor_rate_pct < 80 or b.status = 'renegotiating')
  order by b.honor_rate_pct asc;
end $$;

-- RPC 4: weekly wellness trend
create or replace function r2997_weekly_wellness_trend()
returns table(checkin_week_starting date, family_time_hours numeric, work_hours numeric, sleep_hours numeric, mood_score_1_10 int, marriage_health_1_10 int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.checkin_week_starting, c.family_time_hours, c.work_hours, c.sleep_hours, c.mood_score_1_10, c.marriage_health_1_10
  from founder_spouse_wellness_checkins_r2997 c
  where c.checkin_type in ('weekly_sync','quarterly_review')
  order by c.checkin_week_starting desc
  limit 20;
end $$;

-- RPC 5: conflict resolution stats
create or replace function r2997_conflict_resolution()
returns table(quarter text, total_conflicts int, total_resolutions int, resolution_rate_pct numeric, avg_mood numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.quarter,
    sum(c.conflict_count_week)::int as total_conflicts,
    sum(c.resolution_count_week)::int as total_resolutions,
    case when sum(c.conflict_count_week) > 0 then round(sum(c.resolution_count_week)::numeric * 100 / sum(c.conflict_count_week),2) else 100.00 end as resolution_rate_pct,
    round(avg(c.mood_score_1_10),2) as avg_mood
  from founder_spouse_wellness_checkins_r2997 c
  group by c.quarter
  order by c.quarter desc;
end $$;

-- RPC 6: checkin type breakdown
create or replace function r2997_checkin_breakdown()
returns table(checkin_type text, checkin_count int, avg_marriage_health numeric, avg_family_hours numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.checkin_type,
    count(*)::int as checkin_count,
    round(avg(c.marriage_health_1_10),2) as avg_marriage_health,
    round(avg(c.family_time_hours),2) as avg_family_hours
  from founder_spouse_wellness_checkins_r2997 c
  group by c.checkin_type
  order by checkin_count desc;
end $$;

-- RPC 7: recent wins and concerns
create or replace function r2997_recent_wins_concerns()
returns table(checkin_week_starting date, checkin_type text, wins_summary text, concerns_summary text, next_action text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.checkin_week_starting, c.checkin_type, c.wins_summary, c.concerns_summary, c.next_action
  from founder_spouse_wellness_checkins_r2997 c
  where c.wins_summary is not null or c.concerns_summary is not null
  order by c.checkin_week_starting desc
  limit 12;
end $$;

-- RPC 8: category honor leaderboard
create or replace function r2997_category_leaderboard()
returns table(boundary_category text, avg_honor_rate numeric, avg_satisfaction numeric, boundary_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.boundary_category,
    round(avg(b.honor_rate_pct),2) as avg_honor_rate,
    round(avg(b.spouse_satisfaction_1_5),2) as avg_satisfaction,
    count(*)::int as boundary_count
  from founder_spouse_family_boundaries_r2997 b
  where b.total_count > 0
  group by b.boundary_category
  order by avg_honor_rate desc;
end $$;

revoke all on function r2997_boundary_summary() from public, anon;
revoke all on function r2997_top_honored() from public, anon;
revoke all on function r2997_at_risk_boundaries() from public, anon;
revoke all on function r2997_weekly_wellness_trend() from public, anon;
revoke all on function r2997_conflict_resolution() from public, anon;
revoke all on function r2997_checkin_breakdown() from public, anon;
revoke all on function r2997_recent_wins_concerns() from public, anon;
revoke all on function r2997_category_leaderboard() from public, anon;

grant execute on function r2997_boundary_summary() to authenticated;
grant execute on function r2997_top_honored() to authenticated;
grant execute on function r2997_at_risk_boundaries() to authenticated;
grant execute on function r2997_weekly_wellness_trend() to authenticated;
grant execute on function r2997_conflict_resolution() to authenticated;
grant execute on function r2997_checkin_breakdown() to authenticated;
grant execute on function r2997_recent_wins_concerns() to authenticated;
grant execute on function r2997_category_leaderboard() to authenticated;
