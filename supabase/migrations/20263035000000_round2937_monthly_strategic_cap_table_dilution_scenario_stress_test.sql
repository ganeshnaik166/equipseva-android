-- Round r2937 — Founder Monthly Strategic Cap-Table Dilution Scenario Stress Test
-- 2 tables (_r2937), 7 RPCs (is_founder gated), realistic seeds

create table if not exists cap_table_dilution_scenarios_r2937 (
  id uuid primary key default gen_random_uuid(),
  scenario_code text not null unique,
  scenario_label text not null,
  round_stage text not null check (round_stage in ('seed','pre_a','series_a','series_b','series_c','bridge','esop_topup')),
  pre_money_inr_cr numeric(12,2) not null check (pre_money_inr_cr > 0),
  raise_amount_inr_cr numeric(12,2) not null check (raise_amount_inr_cr > 0),
  new_esop_pool_pct numeric(5,2) not null default 0 check (new_esop_pool_pct >= 0 and new_esop_pool_pct <= 30),
  liquidation_pref_x numeric(4,2) not null default 1 check (liquidation_pref_x >= 1 and liquidation_pref_x <= 4),
  pref_type text not null default 'non_participating' check (pref_type in ('non_participating','participating','participating_capped')),
  anti_dilution text not null default 'broad_based' check (anti_dilution in ('none','broad_based','narrow_based','full_ratchet')),
  founder_dilution_pct numeric(5,2) not null check (founder_dilution_pct >= 0 and founder_dilution_pct <= 100),
  post_money_inr_cr numeric(12,2) not null,
  scenario_status text not null default 'modeled' check (scenario_status in ('modeled','board_review','approved','rejected','executed')),
  stress_score int not null check (stress_score between 0 and 100),
  notes text,
  created_at timestamptz default now()
);
alter table cap_table_dilution_scenarios_r2937 enable row level security;

create table if not exists cap_table_stakeholder_positions_r2937 (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references cap_table_dilution_scenarios_r2937(id) on delete cascade,
  stakeholder_name text not null,
  stakeholder_type text not null check (stakeholder_type in ('founder','co_founder','employee_esop','angel','seed_vc','growth_vc','strategic','advisor')),
  pre_round_pct numeric(6,3) not null check (pre_round_pct >= 0 and pre_round_pct <= 100),
  post_round_pct numeric(6,3) not null check (post_round_pct >= 0 and post_round_pct <= 100),
  shares_owned_lakh numeric(10,4) not null check (shares_owned_lakh >= 0),
  voting_rights_pct numeric(6,3) not null check (voting_rights_pct >= 0 and voting_rights_pct <= 100),
  board_seat boolean not null default false,
  protective_provisions boolean not null default false,
  created_at timestamptz default now()
);
alter table cap_table_stakeholder_positions_r2937 enable row level security;

-- Seed scenarios (15)
insert into cap_table_dilution_scenarios_r2937 (scenario_code, scenario_label, round_stage, pre_money_inr_cr, raise_amount_inr_cr, new_esop_pool_pct, liquidation_pref_x, pref_type, anti_dilution, founder_dilution_pct, post_money_inr_cr, scenario_status, stress_score, notes) values
('S-001','Seed-Conservative','seed',12.00,3.00,5.00,1.00,'non_participating','broad_based',8.50,15.00,'executed',22,'Initial angel round closed Q1'),
('S-002','Seed-Aggressive','seed',10.00,5.00,10.00,1.50,'participating','broad_based',18.30,15.00,'modeled',58,'High dilution variant'),
('S-003','PreA-Standard','pre_a',35.00,8.00,7.50,1.00,'non_participating','broad_based',14.20,43.00,'approved',31,'Bridge to Series A'),
('S-004','SeriesA-Tier1VC','series_a',80.00,25.00,12.00,1.00,'non_participating','broad_based',22.50,105.00,'board_review',45,'Lead VC Sequoia term sheet'),
('S-005','SeriesA-Down','series_a',55.00,20.00,10.00,2.00,'participating_capped','full_ratchet',38.00,75.00,'modeled',88,'Down-round stress test'),
('S-006','SeriesB-Growth','series_b',220.00,60.00,8.00,1.00,'non_participating','broad_based',18.70,280.00,'modeled',42,'Healthy up-round'),
('S-007','SeriesB-StratPartner','series_b',200.00,75.00,5.00,1.50,'participating','narrow_based',26.40,275.00,'board_review',64,'Strategic with veto rights'),
('S-008','Bridge-Insider','bridge',150.00,12.00,3.00,1.25,'non_participating','broad_based',7.20,162.00,'approved',28,'Existing investors bridge'),
('S-009','SeriesC-IPOPath','series_c',650.00,180.00,6.00,1.00,'non_participating','broad_based',21.80,830.00,'modeled',38,'Pre-IPO crossover'),
('S-010','SeriesC-Crammed','series_c',480.00,150.00,15.00,3.00,'participating','full_ratchet',52.30,630.00,'rejected',96,'Worst-case cramdown'),
('S-011','ESOP-Topup-FY26','esop_topup',420.00,0.50,8.00,1.00,'non_participating','broad_based',6.40,420.50,'approved',18,'Annual ESOP refresh'),
('S-012','SeriesA-FlatExtension','series_a',75.00,18.00,9.00,1.00,'non_participating','broad_based',19.50,93.00,'modeled',35,'Flat round with new lead'),
('S-013','SeriesB-DownProtection','series_b',180.00,50.00,10.00,2.00,'participating_capped','narrow_based',34.10,230.00,'modeled',72,'Anti-dilution triggers'),
('S-014','Seed-AngelSyndicate','seed',8.00,2.50,4.00,1.00,'non_participating','none',13.20,10.50,'executed',24,'25 angels SAFE conversion'),
('S-015','SeriesC-Mega','series_c',900.00,300.00,5.00,1.00,'non_participating','broad_based',24.90,1200.00,'board_review',48,'Tiger Global lead');

-- Seed stakeholder positions (24)
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Ganesh Dhanavath','founder', 62.500, 57.180, 28.5900, 57.180, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-001';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Co-Founder A','co_founder', 25.000, 22.870, 11.4350, 22.870, true, false from cap_table_dilution_scenarios_r2937 where scenario_code='S-001';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Angel Syndicate I','angel', 0.000, 14.950, 7.4750, 14.950, false, false from cap_table_dilution_scenarios_r2937 where scenario_code='S-001';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'ESOP Pool','employee_esop', 12.500, 5.000, 2.5000, 0.000, false, false from cap_table_dilution_scenarios_r2937 where scenario_code='S-001';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Ganesh Dhanavath','founder', 60.000, 46.500, 23.2500, 46.500, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-004';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Sequoia India','seed_vc', 0.000, 23.800, 11.9000, 23.800, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-004';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Earlier Angels','angel', 15.000, 11.620, 5.8100, 11.620, false, false from cap_table_dilution_scenarios_r2937 where scenario_code='S-004';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'ESOP Pool','employee_esop', 8.000, 12.000, 6.0000, 0.000, false, false from cap_table_dilution_scenarios_r2937 where scenario_code='S-004';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Ganesh Dhanavath','founder', 48.000, 29.760, 18.5760, 29.760, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-005';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Down-Round Lead','growth_vc', 0.000, 35.500, 22.1875, 35.500, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-005';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Ganesh Dhanavath','founder', 42.000, 34.150, 27.3200, 34.150, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-006';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Series B Lead','growth_vc', 0.000, 21.430, 17.1440, 21.430, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-006';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Existing Series A','seed_vc', 22.000, 17.880, 14.3040, 17.880, true, false from cap_table_dilution_scenarios_r2937 where scenario_code='S-006';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Ganesh Dhanavath','founder', 38.500, 28.330, 35.4125, 28.330, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-009';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Crossover Fund','growth_vc', 0.000, 21.690, 27.1125, 21.690, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-009';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Ganesh Dhanavath','founder', 35.000, 16.700, 10.5210, 16.700, true, false from cap_table_dilution_scenarios_r2937 where scenario_code='S-010';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Cramdown Lead','growth_vc', 0.000, 31.250, 19.6875, 31.250, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-010';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Ganesh Dhanavath','founder', 36.000, 33.700, 30.3300, 33.700, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-011';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'ESOP Pool','employee_esop', 10.000, 18.000, 16.2000, 0.000, false, false from cap_table_dilution_scenarios_r2937 where scenario_code='S-011';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Ganesh Dhanavath','founder', 30.500, 22.900, 28.6250, 22.900, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-015';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Tiger Global','growth_vc', 0.000, 25.000, 31.2500, 25.000, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-015';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Ganesh Dhanavath','founder', 55.000, 47.730, 23.8650, 47.730, true, true from cap_table_dilution_scenarios_r2937 where scenario_code='S-014';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, '25-Angel Syndicate','angel', 0.000, 23.810, 11.9050, 23.810, false, false from cap_table_dilution_scenarios_r2937 where scenario_code='S-014';
insert into cap_table_stakeholder_positions_r2937 (scenario_id, stakeholder_name, stakeholder_type, pre_round_pct, post_round_pct, shares_owned_lakh, voting_rights_pct, board_seat, protective_provisions)
select id, 'Advisor Pool','advisor', 2.500, 2.140, 1.0700, 0.000, false, false from cap_table_dilution_scenarios_r2937 where scenario_code='S-014';

-- RPC 1: scenario overview
create or replace function founder_r2937_scenario_overview()
returns table(scenario_code text, scenario_label text, round_stage text, pre_money_inr_cr numeric, raise_amount_inr_cr numeric, post_money_inr_cr numeric, founder_dilution_pct numeric, scenario_status text, stress_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.scenario_code, s.scenario_label, s.round_stage, s.pre_money_inr_cr, s.raise_amount_inr_cr, s.post_money_inr_cr, s.founder_dilution_pct, s.scenario_status, s.stress_score
    from cap_table_dilution_scenarios_r2937 s order by s.stress_score desc;
end; $$;

-- RPC 2: dilution by stage
create or replace function founder_r2937_dilution_by_stage()
returns table(round_stage text, scenarios_count int, avg_dilution_pct numeric, max_dilution_pct numeric, total_raise_cr numeric, avg_stress int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.round_stage, count(*)::int, round(avg(s.founder_dilution_pct),2), max(s.founder_dilution_pct), sum(s.raise_amount_inr_cr), round(avg(s.stress_score))::int
    from cap_table_dilution_scenarios_r2937 s group by s.round_stage order by avg(s.founder_dilution_pct) desc;
end; $$;

-- RPC 3: stress hotspots
create or replace function founder_r2937_stress_hotspots()
returns table(scenario_code text, scenario_label text, stress_score int, founder_dilution_pct numeric, liquidation_pref_x numeric, anti_dilution text, pref_type text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.scenario_code, s.scenario_label, s.stress_score, s.founder_dilution_pct, s.liquidation_pref_x, s.anti_dilution, s.pref_type
    from cap_table_dilution_scenarios_r2937 s where s.stress_score >= 60 order by s.stress_score desc;
end; $$;

-- RPC 4: stakeholder ownership distribution
create or replace function founder_r2937_stakeholder_distribution()
returns table(stakeholder_type text, holders int, avg_post_pct numeric, total_shares_lakh numeric, board_seats int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select p.stakeholder_type, count(*)::int, round(avg(p.post_round_pct),2), round(sum(p.shares_owned_lakh),2), (count(*) filter (where p.board_seat))::int
    from cap_table_stakeholder_positions_r2937 p group by p.stakeholder_type order by avg(p.post_round_pct) desc;
end; $$;

-- RPC 5: founder position trajectory
create or replace function founder_r2937_founder_trajectory()
returns table(scenario_code text, round_stage text, founder_pre_pct numeric, founder_post_pct numeric, delta_pct numeric, voting_post_pct numeric, protective boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.scenario_code, s.round_stage, p.pre_round_pct, p.post_round_pct, round(p.pre_round_pct - p.post_round_pct,3), p.voting_rights_pct, p.protective_provisions
    from cap_table_stakeholder_positions_r2937 p join cap_table_dilution_scenarios_r2937 s on s.id = p.scenario_id
    where p.stakeholder_type = 'founder' order by s.stress_score desc;
end; $$;

-- RPC 6: protection terms exposure
create or replace function founder_r2937_protection_terms_exposure()
returns table(anti_dilution text, pref_type text, scenarios int, avg_stress numeric, total_raise_cr numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.anti_dilution, s.pref_type, count(*)::int, round(avg(s.stress_score),1), sum(s.raise_amount_inr_cr)
    from cap_table_dilution_scenarios_r2937 s group by s.anti_dilution, s.pref_type order by avg(s.stress_score) desc;
end; $$;

-- RPC 7: scenario status pipeline
create or replace function founder_r2937_status_pipeline()
returns table(scenario_status text, scenarios int, total_post_money_cr numeric, total_raise_cr numeric, avg_dilution numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.scenario_status, count(*)::int, sum(s.post_money_inr_cr), sum(s.raise_amount_inr_cr), round(avg(s.founder_dilution_pct),2)
    from cap_table_dilution_scenarios_r2937 s group by s.scenario_status order by sum(s.post_money_inr_cr) desc;
end; $$;

-- Grants
revoke execute on function founder_r2937_scenario_overview() from public, anon;
revoke execute on function founder_r2937_dilution_by_stage() from public, anon;
revoke execute on function founder_r2937_stress_hotspots() from public, anon;
revoke execute on function founder_r2937_stakeholder_distribution() from public, anon;
revoke execute on function founder_r2937_founder_trajectory() from public, anon;
revoke execute on function founder_r2937_protection_terms_exposure() from public, anon;
revoke execute on function founder_r2937_status_pipeline() from public, anon;

grant execute on function founder_r2937_scenario_overview() to authenticated;
grant execute on function founder_r2937_dilution_by_stage() to authenticated;
grant execute on function founder_r2937_stress_hotspots() to authenticated;
grant execute on function founder_r2937_stakeholder_distribution() to authenticated;
grant execute on function founder_r2937_founder_trajectory() to authenticated;
grant execute on function founder_r2937_protection_terms_exposure() to authenticated;
grant execute on function founder_r2937_status_pipeline() to authenticated;
