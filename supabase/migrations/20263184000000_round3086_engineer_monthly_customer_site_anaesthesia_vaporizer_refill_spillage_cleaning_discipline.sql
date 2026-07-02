-- Round 3086: Engineer Monthly Customer Site Anaesthesia Vaporizer Refill Spillage & Cleaning Discipline

create table if not exists vaporizer_refill_visits_r3086 (
  id uuid primary key default gen_random_uuid(),
  visit_month date not null,
  engineer_id uuid references engineers(id),
  hospital_org_id uuid references organizations(id),
  vaporizer_serial text not null,
  agent_type text not null check (agent_type in ('sevoflurane','isoflurane','desflurane','halothane')),
  refill_volume_ml int not null,
  spillage_ml int not null default 0,
  spillage_severity text not null check (spillage_severity in ('none','minor','moderate','major','critical')),
  cleaning_protocol_followed boolean not null default true,
  ppe_compliance text not null check (ppe_compliance in ('full','partial','missing','exempt')),
  visit_duration_minutes int not null,
  outcome_status text not null check (outcome_status in ('clean','needs_followup','escalated','reopened')),
  notes text,
  created_at timestamptz not null default now()
);

alter table vaporizer_refill_visits_r3086 enable row level security;
drop policy if exists vrv_r3086_founder_select on vaporizer_refill_visits_r3086;
create policy vrv_r3086_founder_select on vaporizer_refill_visits_r3086 for select using (is_founder());

create table if not exists vaporizer_discipline_scorecards_r3086 (
  id uuid primary key default gen_random_uuid(),
  scorecard_month date not null,
  engineer_id uuid references engineers(id),
  region text not null check (region in ('north','south','east','west','central')),
  total_visits int not null default 0,
  spillage_incidents int not null default 0,
  cleaning_audits_passed int not null default 0,
  cleaning_audits_failed int not null default 0,
  discipline_score numeric(5,2) not null,
  tier text not null check (tier in ('platinum','gold','silver','bronze','watchlist')),
  coaching_required boolean not null default false,
  remediation_status text check (remediation_status in ('not_required','assigned','in_progress','completed','overdue')),
  last_incident_at timestamptz,
  created_at timestamptz not null default now()
);

alter table vaporizer_discipline_scorecards_r3086 enable row level security;
drop policy if exists vds_r3086_founder_select on vaporizer_discipline_scorecards_r3086;
create policy vds_r3086_founder_select on vaporizer_discipline_scorecards_r3086 for select using (is_founder());

-- Seed: 16 visits
insert into vaporizer_refill_visits_r3086 (visit_month, vaporizer_serial, agent_type, refill_volume_ml, spillage_ml, spillage_severity, cleaning_protocol_followed, ppe_compliance, visit_duration_minutes, outcome_status, notes) values
('2026-06-01'::date, 'VAP-AX-1001', 'sevoflurane', 250, 0, 'none', true, 'full', 35, 'clean', 'Standard refill, no incidents'),
('2026-06-01'::date, 'VAP-AX-1002', 'isoflurane', 250, 5, 'minor', true, 'full', 42, 'clean', 'Minor drip during disconnect'),
('2026-06-02'::date, 'VAP-AX-1003', 'desflurane', 240, 0, 'none', true, 'full', 30, 'clean', null),
('2026-06-02'::date, 'VAP-AX-1004', 'sevoflurane', 250, 18, 'moderate', false, 'partial', 55, 'needs_followup', 'Operator skipped wipe-down step'),
('2026-06-03'::date, 'VAP-AX-1005', 'sevoflurane', 250, 0, 'none', true, 'full', 38, 'clean', null),
('2026-06-03'::date, 'VAP-AX-1006', 'halothane', 200, 35, 'major', false, 'missing', 70, 'escalated', 'PPE missing, spill on floor'),
('2026-06-04'::date, 'VAP-AX-1007', 'isoflurane', 250, 0, 'none', true, 'full', 33, 'clean', null),
('2026-06-04'::date, 'VAP-AX-1008', 'sevoflurane', 250, 2, 'minor', true, 'full', 36, 'clean', null),
('2026-06-05'::date, 'VAP-AX-1009', 'desflurane', 240, 60, 'critical', false, 'partial', 95, 'reopened', 'Major spill, ventilation triggered'),
('2026-06-05'::date, 'VAP-AX-1010', 'sevoflurane', 250, 0, 'none', true, 'full', 40, 'clean', null),
('2026-06-06'::date, 'VAP-AX-1011', 'isoflurane', 250, 8, 'minor', true, 'full', 45, 'clean', 'Small drip, cleaned promptly'),
('2026-06-06'::date, 'VAP-AX-1012', 'sevoflurane', 250, 0, 'none', true, 'full', 32, 'clean', null),
('2026-06-07'::date, 'VAP-AX-1013', 'desflurane', 240, 22, 'moderate', true, 'partial', 60, 'needs_followup', 'PPE goggles fogged'),
('2026-06-07'::date, 'VAP-AX-1014', 'sevoflurane', 250, 0, 'none', true, 'full', 34, 'clean', null),
('2026-06-08'::date, 'VAP-AX-1015', 'halothane', 200, 0, 'none', true, 'exempt', 28, 'clean', 'Legacy unit, exempt PPE'),
('2026-06-08'::date, 'VAP-AX-1016', 'sevoflurane', 250, 12, 'moderate', false, 'partial', 50, 'needs_followup', 'Funnel slip during pour');

-- Seed: 15 scorecards
insert into vaporizer_discipline_scorecards_r3086 (scorecard_month, region, total_visits, spillage_incidents, cleaning_audits_passed, cleaning_audits_failed, discipline_score, tier, coaching_required, remediation_status, last_incident_at) values
('2026-06-01'::date, 'south', 22, 1, 21, 1, 95.50, 'platinum', false, 'not_required', '2026-06-02 10:00:00+00'::timestamptz),
('2026-06-01'::date, 'north', 18, 3, 15, 3, 78.20, 'silver', true, 'assigned', '2026-06-05 14:30:00+00'::timestamptz),
('2026-06-01'::date, 'west', 20, 0, 20, 0, 99.00, 'platinum', false, 'not_required', null),
('2026-06-01'::date, 'east', 16, 5, 11, 5, 62.40, 'bronze', true, 'in_progress', '2026-06-07 09:15:00+00'::timestamptz),
('2026-06-01'::date, 'central', 14, 1, 13, 1, 91.30, 'gold', false, 'not_required', '2026-06-03 11:00:00+00'::timestamptz),
('2026-06-01'::date, 'south', 19, 2, 17, 2, 86.10, 'gold', false, 'completed', '2026-06-04 16:00:00+00'::timestamptz),
('2026-06-01'::date, 'north', 12, 6, 6, 6, 48.20, 'watchlist', true, 'overdue', '2026-06-08 13:45:00+00'::timestamptz),
('2026-06-01'::date, 'west', 21, 0, 21, 0, 98.50, 'platinum', false, 'not_required', null),
('2026-06-01'::date, 'east', 17, 2, 15, 2, 84.70, 'gold', false, 'completed', '2026-06-06 10:30:00+00'::timestamptz),
('2026-06-01'::date, 'central', 15, 4, 11, 4, 70.10, 'silver', true, 'in_progress', '2026-06-07 15:00:00+00'::timestamptz),
('2026-06-01'::date, 'south', 23, 1, 22, 1, 94.80, 'platinum', false, 'not_required', '2026-06-02 12:00:00+00'::timestamptz),
('2026-06-01'::date, 'north', 16, 3, 13, 3, 76.50, 'silver', true, 'assigned', '2026-06-06 09:00:00+00'::timestamptz),
('2026-06-01'::date, 'west', 14, 0, 14, 0, 100.00, 'platinum', false, 'not_required', null),
('2026-06-01'::date, 'east', 18, 7, 11, 7, 55.60, 'bronze', true, 'overdue', '2026-06-08 17:00:00+00'::timestamptz),
('2026-06-01'::date, 'central', 20, 2, 18, 2, 88.40, 'gold', false, 'completed', '2026-06-05 13:30:00+00'::timestamptz);

-- RPC 1: monthly summary
create or replace function r3086_monthly_summary()
returns table (
  total_visits int,
  clean_visits int,
  needs_followup int,
  escalated int,
  reopened int,
  total_spillage_ml int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where outcome_status = 'clean'))::int,
    (count(*) filter (where outcome_status = 'needs_followup'))::int,
    (count(*) filter (where outcome_status = 'escalated'))::int,
    (count(*) filter (where outcome_status = 'reopened'))::int,
    coalesce(sum(spillage_ml), 0)::int
  from vaporizer_refill_visits_r3086;
end; $$;

-- RPC 2: spillage by severity
create or replace function r3086_spillage_by_severity()
returns table (
  severity text,
  visit_count int,
  total_ml int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select spillage_severity, count(*)::int, coalesce(sum(spillage_ml), 0)::int
  from vaporizer_refill_visits_r3086
  group by spillage_severity
  order by total_ml desc;
end; $$;

-- RPC 3: agent type breakdown
create or replace function r3086_agent_type_breakdown()
returns table (
  agent text,
  visits int,
  avg_duration numeric,
  spillage_total int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select agent_type, count(*)::int, round(avg(visit_duration_minutes)::numeric, 1), coalesce(sum(spillage_ml), 0)::int
  from vaporizer_refill_visits_r3086
  group by agent_type
  order by visits desc;
end; $$;

-- RPC 4: ppe compliance
create or replace function r3086_ppe_compliance()
returns table (
  ppe_level text,
  visits int,
  spillage_incidents int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select ppe_compliance, count(*)::int, (count(*) filter (where spillage_ml > 0))::int
  from vaporizer_refill_visits_r3086
  group by ppe_compliance
  order by visits desc;
end; $$;

-- RPC 5: tier distribution
create or replace function r3086_tier_distribution()
returns table (
  tier_name text,
  engineer_count int,
  avg_score numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select tier, count(*)::int, round(avg(discipline_score)::numeric, 2)
  from vaporizer_discipline_scorecards_r3086
  group by tier
  order by avg_score desc;
end; $$;

-- RPC 6: regional discipline
create or replace function r3086_regional_discipline()
returns table (
  region_name text,
  scorecards int,
  avg_score numeric,
  watchlist_count int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select region, count(*)::int, round(avg(discipline_score)::numeric, 2), (count(*) filter (where tier = 'watchlist'))::int
  from vaporizer_discipline_scorecards_r3086
  group by region
  order by avg_score desc;
end; $$;

-- RPC 7: remediation status
create or replace function r3086_remediation_status()
returns table (
  status text,
  count_scorecards int,
  coaching_required_count int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select coalesce(remediation_status, 'unset'), count(*)::int, (count(*) filter (where coaching_required))::int
  from vaporizer_discipline_scorecards_r3086
  group by remediation_status
  order by count_scorecards desc;
end; $$;

revoke all on function r3086_monthly_summary() from public, anon;
revoke all on function r3086_spillage_by_severity() from public, anon;
revoke all on function r3086_agent_type_breakdown() from public, anon;
revoke all on function r3086_ppe_compliance() from public, anon;
revoke all on function r3086_tier_distribution() from public, anon;
revoke all on function r3086_regional_discipline() from public, anon;
revoke all on function r3086_remediation_status() from public, anon;

grant execute on function r3086_monthly_summary() to authenticated;
grant execute on function r3086_spillage_by_severity() to authenticated;
grant execute on function r3086_agent_type_breakdown() to authenticated;
grant execute on function r3086_ppe_compliance() to authenticated;
grant execute on function r3086_tier_distribution() to authenticated;
grant execute on function r3086_regional_discipline() to authenticated;
grant execute on function r3086_remediation_status() to authenticated;
