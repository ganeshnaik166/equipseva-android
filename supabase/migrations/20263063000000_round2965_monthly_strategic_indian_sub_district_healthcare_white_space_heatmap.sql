-- Round 2965: Founder Monthly Strategic Indian Sub-District Healthcare White-Space Heatmap
-- HEAVY: 2 tables + 7 RPCs + seeds

create table if not exists sub_district_white_space_r2965 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  state_name text not null,
  district_name text not null,
  sub_district_name text not null,
  population_thousands int not null check (population_thousands > 0),
  hospital_count int not null check (hospital_count >= 0),
  equipment_units_installed int not null check (equipment_units_installed >= 0),
  amc_penetration_pct numeric(5,2) not null check (amc_penetration_pct between 0 and 100),
  white_space_score numeric(5,2) not null check (white_space_score between 0 and 100),
  tier_classification text not null check (tier_classification in ('tier_2','tier_3','tier_4','rural')),
  priority_rank text not null check (priority_rank in ('p0','p1','p2','p3')),
  estimated_tam_lakhs_inr numeric(12,2) not null check (estimated_tam_lakhs_inr >= 0),
  surveyed_on date not null
);

alter table sub_district_white_space_r2965 enable row level security;

drop policy if exists sub_district_white_space_r2965_select on sub_district_white_space_r2965;
create policy sub_district_white_space_r2965_select on sub_district_white_space_r2965
  for select using (is_founder());

create table if not exists sub_district_expansion_plan_r2965 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  sub_district_name text not null,
  state_name text not null,
  planned_launch_date date not null,
  go_live_status text not null check (go_live_status in ('planned','scouting','negotiating','launched','paused')),
  partner_hospital_target int not null check (partner_hospital_target >= 0),
  engineer_hire_target int not null check (engineer_hire_target >= 0),
  capex_budget_lakhs_inr numeric(12,2) not null check (capex_budget_lakhs_inr >= 0),
  expected_arr_lakhs_inr numeric(12,2) not null check (expected_arr_lakhs_inr >= 0),
  payback_months int not null check (payback_months > 0),
  owner_name text not null,
  notes text
);

alter table sub_district_expansion_plan_r2965 enable row level security;

drop policy if exists sub_district_expansion_plan_r2965_select on sub_district_expansion_plan_r2965;
create policy sub_district_expansion_plan_r2965_select on sub_district_expansion_plan_r2965
  for select using (is_founder());

-- Seeds: white space
insert into sub_district_white_space_r2965 (state_name, district_name, sub_district_name, population_thousands, hospital_count, equipment_units_installed, amc_penetration_pct, white_space_score, tier_classification, priority_rank, estimated_tam_lakhs_inr, surveyed_on) values
('Telangana','Karimnagar','Huzurabad', 245, 12, 18, 12.50, 87.50, 'tier_3','p0', 145.00, '2026-06-01'::date),
('Telangana','Warangal','Parkal', 180, 8, 9, 8.00, 92.00, 'tier_3','p0', 118.50, '2026-06-01'::date),
('Andhra Pradesh','Kurnool','Adoni', 320, 22, 41, 28.00, 72.00, 'tier_2','p1', 210.00, '2026-06-02'::date),
('Andhra Pradesh','Chittoor','Madanapalle', 165, 11, 14, 15.00, 85.00, 'tier_3','p0', 132.00, '2026-06-02'::date),
('Karnataka','Tumkur','Sira', 95, 5, 4, 5.00, 95.00, 'rural','p0', 78.00, '2026-06-03'::date),
('Karnataka','Mysuru','Hunsur', 142, 9, 11, 18.00, 82.00, 'tier_3','p1', 105.00, '2026-06-03'::date),
('Tamil Nadu','Salem','Mettur', 210, 14, 22, 32.00, 68.00, 'tier_2','p1', 168.00, '2026-06-04'::date),
('Tamil Nadu','Erode','Bhavani', 88, 6, 7, 22.00, 78.00, 'tier_3','p1', 64.00, '2026-06-04'::date),
('Kerala','Palakkad','Mannarkkad', 75, 7, 12, 45.00, 55.00, 'tier_3','p2', 52.00, '2026-06-05'::date),
('Maharashtra','Nashik','Sinnar', 195, 13, 19, 24.00, 76.00, 'tier_2','p1', 142.00, '2026-06-06'::date),
('Maharashtra','Ahmednagar','Sangamner', 158, 10, 15, 19.50, 80.50, 'tier_3','p0', 121.00, '2026-06-06'::date),
('Gujarat','Rajkot','Gondal', 235, 16, 28, 35.00, 65.00, 'tier_2','p2', 178.00, '2026-06-07'::date),
('Madhya Pradesh','Indore','Mhow', 125, 8, 10, 14.00, 86.00, 'tier_3','p0', 92.00, '2026-06-08'::date),
('Rajasthan','Ajmer','Beawar', 175, 11, 16, 26.00, 74.00, 'tier_3','p1', 128.00, '2026-06-09'::date),
('Uttar Pradesh','Meerut','Mawana', 110, 7, 6, 9.00, 91.00, 'tier_3','p0', 88.00, '2026-06-10'::date),
('Bihar','Patna','Barh', 68, 4, 3, 4.50, 95.50, 'rural','p0', 55.00, '2026-06-11'::date),
('West Bengal','Hooghly','Arambagh', 145, 9, 13, 17.00, 83.00, 'tier_3','p1', 112.00, '2026-06-12'::date),
('Odisha','Cuttack','Banki', 82, 5, 5, 11.00, 89.00, 'rural','p0', 62.00, '2026-06-13'::date),
('Punjab','Patiala','Nabha', 135, 9, 18, 38.00, 62.00, 'tier_3','p2', 98.00, '2026-06-14'::date),
('Haryana','Hisar','Hansi', 92, 6, 8, 20.00, 80.00, 'tier_3','p1', 72.00, '2026-06-15'::date);

-- Seeds: expansion plan
insert into sub_district_expansion_plan_r2965 (sub_district_name, state_name, planned_launch_date, go_live_status, partner_hospital_target, engineer_hire_target, capex_budget_lakhs_inr, expected_arr_lakhs_inr, payback_months, owner_name, notes) values
('Huzurabad','Telangana','2026-07-15'::date,'negotiating', 8, 3, 22.00, 78.00, 4, 'Ravi Kumar','3 hospitals signed LOI'),
('Parkal','Telangana','2026-08-01'::date,'scouting', 6, 2, 18.00, 62.00, 4, 'Ravi Kumar','Survey complete'),
('Adoni','Andhra Pradesh','2026-07-20'::date,'planned', 12, 4, 28.00, 105.00, 4, 'Lakshmi N','Tier-2 anchor'),
('Madanapalle','Andhra Pradesh','2026-09-01'::date,'scouting', 7, 3, 20.00, 68.00, 4, 'Lakshmi N','Awaiting district approval'),
('Sira','Karnataka','2026-10-15'::date,'planned', 4, 1, 12.00, 38.00, 4, 'Manjunath','Rural pilot'),
('Hunsur','Karnataka','2026-08-15'::date,'negotiating', 6, 2, 16.00, 52.00, 4, 'Manjunath','Hospital chain interested'),
('Mettur','Tamil Nadu','2026-07-10'::date,'launched', 10, 4, 25.00, 88.00, 4, 'Suresh R','Live since June'),
('Bhavani','Tamil Nadu','2026-11-01'::date,'planned', 5, 2, 14.00, 42.00, 4, 'Suresh R','Q4 launch'),
('Sinnar','Maharashtra','2026-08-20'::date,'negotiating', 8, 3, 21.00, 72.00, 4, 'Priya M','Marathi staff training'),
('Sangamner','Maharashtra','2026-09-15'::date,'scouting', 7, 3, 19.00, 65.00, 4, 'Priya M','Survey ongoing'),
('Mhow','Madhya Pradesh','2026-10-01'::date,'planned', 5, 2, 15.00, 48.00, 4, 'Arjun S','Hindi belt'),
('Mawana','Uttar Pradesh','2026-09-30'::date,'paused', 4, 2, 13.00, 42.00, 5, 'Arjun S','Awaiting govt clearance'),
('Barh','Bihar','2026-12-01'::date,'planned', 3, 1, 10.00, 28.00, 5, 'Vijay K','Rural deep'),
('Arambagh','West Bengal','2026-11-15'::date,'scouting', 6, 2, 17.00, 56.00, 4, 'Tanmoy D','Bengali ops needed'),
('Banki','Odisha','2027-01-15'::date,'planned', 3, 1, 11.00, 32.00, 5, 'Tanmoy D','Coastal pilot');

-- RPC 1: priority heatmap
create or replace function rpc_r2965_priority_heatmap()
returns table(state_name text, sub_district_name text, white_space_score numeric, priority_rank text, estimated_tam_lakhs_inr numeric, tier_classification text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select w.state_name, w.sub_district_name, w.white_space_score, w.priority_rank, w.estimated_tam_lakhs_inr, w.tier_classification
    from sub_district_white_space_r2965 w
    order by w.white_space_score desc, w.estimated_tam_lakhs_inr desc;
end;$$;

revoke all on function rpc_r2965_priority_heatmap() from public, anon;
grant execute on function rpc_r2965_priority_heatmap() to authenticated;

-- RPC 2: state rollup
create or replace function rpc_r2965_state_rollup()
returns table(state_name text, sub_districts_surveyed int, avg_white_space numeric, total_tam_lakhs numeric, p0_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select w.state_name,
           count(*)::int,
           round(avg(w.white_space_score),2),
           round(sum(w.estimated_tam_lakhs_inr),2),
           (count(*) filter (where w.priority_rank='p0'))::int
    from sub_district_white_space_r2965 w
    group by w.state_name
    order by sum(w.estimated_tam_lakhs_inr) desc;
end;$$;

revoke all on function rpc_r2965_state_rollup() from public, anon;
grant execute on function rpc_r2965_state_rollup() to authenticated;

-- RPC 3: tier breakdown
create or replace function rpc_r2965_tier_breakdown()
returns table(tier_classification text, sub_district_count int, avg_amc_penetration numeric, avg_white_space numeric, total_tam_lakhs numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select w.tier_classification,
           count(*)::int,
           round(avg(w.amc_penetration_pct),2),
           round(avg(w.white_space_score),2),
           round(sum(w.estimated_tam_lakhs_inr),2)
    from sub_district_white_space_r2965 w
    group by w.tier_classification
    order by sum(w.estimated_tam_lakhs_inr) desc;
end;$$;

revoke all on function rpc_r2965_tier_breakdown() from public, anon;
grant execute on function rpc_r2965_tier_breakdown() to authenticated;

-- RPC 4: expansion pipeline
create or replace function rpc_r2965_expansion_pipeline()
returns table(sub_district_name text, state_name text, go_live_status text, planned_launch_date date, expected_arr_lakhs_inr numeric, payback_months int, owner_name text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.sub_district_name, p.state_name, p.go_live_status, p.planned_launch_date, p.expected_arr_lakhs_inr, p.payback_months, p.owner_name
    from sub_district_expansion_plan_r2965 p
    order by p.planned_launch_date asc;
end;$$;

revoke all on function rpc_r2965_expansion_pipeline() from public, anon;
grant execute on function rpc_r2965_expansion_pipeline() to authenticated;

-- RPC 5: status mix
create or replace function rpc_r2965_status_mix()
returns table(go_live_status text, plan_count int, total_capex_lakhs numeric, total_expected_arr_lakhs numeric, avg_payback_months numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.go_live_status,
           count(*)::int,
           round(sum(p.capex_budget_lakhs_inr),2),
           round(sum(p.expected_arr_lakhs_inr),2),
           round(avg(p.payback_months),2)
    from sub_district_expansion_plan_r2965 p
    group by p.go_live_status
    order by sum(p.expected_arr_lakhs_inr) desc;
end;$$;

revoke all on function rpc_r2965_status_mix() from public, anon;
grant execute on function rpc_r2965_status_mix() to authenticated;

-- RPC 6: matched candidates (white space joined to plan)
create or replace function rpc_r2965_matched_candidates()
returns table(sub_district_name text, state_name text, white_space_score numeric, priority_rank text, go_live_status text, expected_arr_lakhs_inr numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select w.sub_district_name, w.state_name, w.white_space_score, w.priority_rank, p.go_live_status, p.expected_arr_lakhs_inr
    from sub_district_white_space_r2965 w
    join sub_district_expansion_plan_r2965 p
      on p.sub_district_name = w.sub_district_name and p.state_name = w.state_name
    order by w.white_space_score desc;
end;$$;

revoke all on function rpc_r2965_matched_candidates() from public, anon;
grant execute on function rpc_r2965_matched_candidates() to authenticated;

-- RPC 7: unaddressed white space
create or replace function rpc_r2965_unaddressed_whitespace()
returns table(sub_district_name text, state_name text, white_space_score numeric, priority_rank text, estimated_tam_lakhs_inr numeric, population_thousands int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select w.sub_district_name, w.state_name, w.white_space_score, w.priority_rank, w.estimated_tam_lakhs_inr, w.population_thousands
    from sub_district_white_space_r2965 w
    where not exists (
      select 1 from sub_district_expansion_plan_r2965 p
      where p.sub_district_name = w.sub_district_name and p.state_name = w.state_name
    )
    order by w.white_space_score desc, w.estimated_tam_lakhs_inr desc;
end;$$;

revoke all on function rpc_r2965_unaddressed_whitespace() from public, anon;
grant execute on function rpc_r2965_unaddressed_whitespace() to authenticated;
