-- Round 2949: Founder Monthly Strategic Engineer-Network Geographic Coverage Heatmap & Gap Plan

create table if not exists engineer_geo_coverage_cells_r2949 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  cell_month date not null,
  state_code text not null,
  city text not null,
  pincode_prefix text not null,
  tier text not null check (tier in ('tier1','tier2','tier3','tier4')),
  active_engineers int not null default 0,
  open_jobs int not null default 0,
  avg_response_hours numeric(6,2) not null default 0,
  sla_breach_pct numeric(5,2) not null default 0,
  hospital_count int not null default 0,
  coverage_score numeric(5,2) not null default 0,
  gap_status text not null check (gap_status in ('healthy','watch','strained','critical')),
  notes text
);

create table if not exists engineer_geo_gap_actions_r2949 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  cell_id uuid not null references engineer_geo_coverage_cells_r2949(id) on delete cascade,
  action_type text not null check (action_type in ('hire','partner','train','relocate','retain','contract')),
  target_engineers int not null default 0,
  budget_rupees bigint not null default 0,
  deadline date not null,
  owner text not null,
  status text not null check (status in ('proposed','approved','in_progress','completed','blocked')),
  expected_impact_score numeric(5,2) not null default 0,
  notes text
);

alter table engineer_geo_coverage_cells_r2949 enable row level security;
alter table engineer_geo_gap_actions_r2949 enable row level security;

drop policy if exists p_cells_r2949 on engineer_geo_coverage_cells_r2949;
create policy p_cells_r2949 on engineer_geo_coverage_cells_r2949 for select to authenticated using (is_founder());

drop policy if exists p_actions_r2949 on engineer_geo_gap_actions_r2949;
create policy p_actions_r2949 on engineer_geo_gap_actions_r2949 for select to authenticated using (is_founder());

insert into engineer_geo_coverage_cells_r2949 (cell_month, state_code, city, pincode_prefix, tier, active_engineers, open_jobs, avg_response_hours, sla_breach_pct, hospital_count, coverage_score, gap_status, notes) values
('2026-06-01'::date,'TS','Hyderabad','500','tier1',42,118,4.20,6.10,86,88.50,'healthy','core hub'),
('2026-06-01'::date,'KA','Bengaluru','560','tier1',38,104,4.80,7.40,79,84.20,'healthy','strong'),
('2026-06-01'::date,'MH','Mumbai','400','tier1',31,128,6.10,11.80,92,71.40,'watch','demand spike'),
('2026-06-01'::date,'DL','New Delhi','110','tier1',28,121,6.80,13.20,88,67.90,'watch','need 6 more'),
('2026-06-01'::date,'TN','Chennai','600','tier1',24,96,5.90,10.20,71,73.10,'watch','steady'),
('2026-06-01'::date,'WB','Kolkata','700','tier1',16,82,8.40,18.60,64,54.20,'strained','low bench'),
('2026-06-01'::date,'GJ','Ahmedabad','380','tier2',12,58,7.10,14.40,41,61.80,'watch','tier2 anchor'),
('2026-06-01'::date,'RJ','Jaipur','302','tier2',9,46,9.20,21.30,32,48.70,'strained','hire ASAP'),
('2026-06-01'::date,'UP','Lucknow','226','tier2',7,52,11.40,28.10,38,38.40,'critical','gap zone'),
('2026-06-01'::date,'MP','Bhopal','462','tier2',6,38,10.80,26.40,27,41.20,'critical','no bench'),
('2026-06-01'::date,'KL','Kochi','682','tier2',11,44,6.40,9.80,29,69.30,'watch','solid'),
('2026-06-01'::date,'PB','Ludhiana','141','tier2',5,29,12.10,32.40,22,32.80,'critical','escalate'),
('2026-06-01'::date,'AP','Visakhapatnam','530','tier2',8,33,8.90,19.70,24,52.40,'strained','retain'),
('2026-06-01'::date,'OR','Bhubaneswar','751','tier2',4,27,13.60,38.20,19,28.10,'critical','partner needed'),
('2026-06-01'::date,'HR','Gurugram','122','tier1',14,71,5.40,8.20,46,76.40,'healthy','satellite-NCR'),
('2026-06-01'::date,'TS','Warangal','506','tier3',3,18,14.20,41.30,12,24.60,'critical','zero growth'),
('2026-06-01'::date,'KA','Mysuru','570','tier3',5,22,9.80,22.10,15,46.30,'strained','train locals'),
('2026-06-01'::date,'JH','Ranchi','834','tier3',2,16,16.40,46.80,11,18.20,'critical','red zone'),
('2026-06-01'::date,'CG','Raipur','492','tier3',3,19,15.10,42.60,13,22.40,'critical','red zone'),
('2026-06-01'::date,'AS','Guwahati','781','tier3',4,21,13.20,36.40,16,30.70,'critical','NE anchor'),
('2026-06-01'::date,'BR','Patna','800','tier3',3,24,14.80,44.10,17,21.30,'critical','escalate'),
('2026-06-01'::date,'UK','Dehradun','248','tier3',2,12,12.40,34.20,9,29.40,'critical','low volume');

insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'hire', 4, 480000, '2026-07-15'::date, 'talent-ops', 'approved', 18.40, 'urgent hire' from engineer_geo_coverage_cells_r2949 where city='Lucknow' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'partner', 3, 220000, '2026-07-20'::date, 'bd-east', 'in_progress', 14.20, 'local svc co' from engineer_geo_coverage_cells_r2949 where city='Kolkata' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'hire', 6, 720000, '2026-08-01'::date, 'talent-ops', 'proposed', 22.60, 'NCR scale' from engineer_geo_coverage_cells_r2949 where city='New Delhi' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'train', 5, 150000, '2026-08-15'::date, 'training', 'approved', 11.80, 'upskill' from engineer_geo_coverage_cells_r2949 where city='Bhopal' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'relocate', 2, 90000, '2026-07-30'::date, 'ops-lead', 'in_progress', 9.30, 'shift from HYD bench' from engineer_geo_coverage_cells_r2949 where city='Visakhapatnam' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'contract', 4, 320000, '2026-08-10'::date, 'bd-west', 'proposed', 13.40, 'gig pool' from engineer_geo_coverage_cells_r2949 where city='Jaipur' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'partner', 2, 180000, '2026-09-01'::date, 'bd-east', 'proposed', 8.60, 'NE coverage' from engineer_geo_coverage_cells_r2949 where city='Guwahati' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'hire', 3, 360000, '2026-07-25'::date, 'talent-ops', 'in_progress', 12.80, 'Patna anchor' from engineer_geo_coverage_cells_r2949 where city='Patna' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'retain', 2, 60000, '2026-07-10'::date, 'people-ops', 'approved', 6.40, 'bonus pkg' from engineer_geo_coverage_cells_r2949 where city='Mumbai' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'train', 4, 120000, '2026-08-20'::date, 'training', 'proposed', 7.80, 'cohort-3' from engineer_geo_coverage_cells_r2949 where city='Mysuru' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'contract', 3, 240000, '2026-08-30'::date, 'bd-central', 'blocked', 9.10, 'vendor mou' from engineer_geo_coverage_cells_r2949 where city='Raipur' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'partner', 2, 140000, '2026-09-15'::date, 'bd-north', 'proposed', 6.20, 'Ludhiana net' from engineer_geo_coverage_cells_r2949 where city='Ludhiana' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'hire', 2, 180000, '2026-08-05'::date, 'talent-ops', 'approved', 8.30, 'Ranchi pilot' from engineer_geo_coverage_cells_r2949 where city='Ranchi' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'train', 3, 90000, '2026-09-10'::date, 'training', 'in_progress', 5.40, 'tier3 program' from engineer_geo_coverage_cells_r2949 where city='Warangal' limit 1;
insert into engineer_geo_gap_actions_r2949 (cell_id, action_type, target_engineers, budget_rupees, deadline, owner, status, expected_impact_score, notes)
select id, 'relocate', 1, 45000, '2026-07-18'::date, 'ops-lead', 'completed', 3.20, 'UK pilot done' from engineer_geo_coverage_cells_r2949 where city='Dehradun' limit 1;

-- RPC 1
create or replace function founder_r2949_coverage_overview()
returns table(total_cells int, critical_cells int, strained_cells int, watch_cells int, healthy_cells int, total_engineers int, total_open_jobs int, avg_coverage numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select count(*)::int,
    (count(*) filter (where gap_status='critical'))::int,
    (count(*) filter (where gap_status='strained'))::int,
    (count(*) filter (where gap_status='watch'))::int,
    (count(*) filter (where gap_status='healthy'))::int,
    coalesce(sum(active_engineers),0)::int,
    coalesce(sum(open_jobs),0)::int,
    round(avg(coverage_score),2)
  from engineer_geo_coverage_cells_r2949;
end; $$;

-- RPC 2
create or replace function founder_r2949_critical_cells()
returns setof engineer_geo_coverage_cells_r2949
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select * from engineer_geo_coverage_cells_r2949 where gap_status='critical' order by coverage_score asc;
end; $$;

-- RPC 3
create or replace function founder_r2949_tier_breakdown()
returns table(tier text, cells int, engineers int, avg_coverage numeric, critical_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.tier, count(*)::int, coalesce(sum(c.active_engineers),0)::int, round(avg(c.coverage_score),2),
    (count(*) filter (where c.gap_status='critical'))::int
  from engineer_geo_coverage_cells_r2949 c group by c.tier order by c.tier;
end; $$;

-- RPC 4
create or replace function founder_r2949_state_summary()
returns table(state_code text, cells int, engineers int, hospitals int, avg_sla_breach numeric, avg_coverage numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.state_code, count(*)::int, coalesce(sum(c.active_engineers),0)::int, coalesce(sum(c.hospital_count),0)::int,
    round(avg(c.sla_breach_pct),2), round(avg(c.coverage_score),2)
  from engineer_geo_coverage_cells_r2949 c group by c.state_code order by avg(c.coverage_score) asc;
end; $$;

-- RPC 5
create or replace function founder_r2949_gap_actions_pipeline()
returns table(status text, action_count int, total_engineers int, total_budget bigint, avg_impact numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.status, count(*)::int, coalesce(sum(a.target_engineers),0)::int, coalesce(sum(a.budget_rupees),0)::bigint,
    round(avg(a.expected_impact_score),2)
  from engineer_geo_gap_actions_r2949 a group by a.status order by a.status;
end; $$;

-- RPC 6
create or replace function founder_r2949_action_type_mix()
returns table(action_type text, n int, target_engineers int, budget bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.action_type, count(*)::int, coalesce(sum(a.target_engineers),0)::int, coalesce(sum(a.budget_rupees),0)::bigint
  from engineer_geo_gap_actions_r2949 a group by a.action_type order by sum(a.budget_rupees) desc;
end; $$;

-- RPC 7
create or replace function founder_r2949_top_gap_actions()
returns table(city text, state_code text, action_type text, target_engineers int, budget_rupees bigint, deadline date, status text, expected_impact_score numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.city, c.state_code, a.action_type, a.target_engineers, a.budget_rupees, a.deadline, a.status, a.expected_impact_score
  from engineer_geo_gap_actions_r2949 a join engineer_geo_coverage_cells_r2949 c on c.id=a.cell_id
  order by a.expected_impact_score desc limit 12;
end; $$;

revoke all on function founder_r2949_coverage_overview() from public, anon;
revoke all on function founder_r2949_critical_cells() from public, anon;
revoke all on function founder_r2949_tier_breakdown() from public, anon;
revoke all on function founder_r2949_state_summary() from public, anon;
revoke all on function founder_r2949_gap_actions_pipeline() from public, anon;
revoke all on function founder_r2949_action_type_mix() from public, anon;
revoke all on function founder_r2949_top_gap_actions() from public, anon;

grant execute on function founder_r2949_coverage_overview() to authenticated;
grant execute on function founder_r2949_critical_cells() to authenticated;
grant execute on function founder_r2949_tier_breakdown() to authenticated;
grant execute on function founder_r2949_state_summary() to authenticated;
grant execute on function founder_r2949_gap_actions_pipeline() to authenticated;
grant execute on function founder_r2949_action_type_mix() to authenticated;
grant execute on function founder_r2949_top_gap_actions() to authenticated;
