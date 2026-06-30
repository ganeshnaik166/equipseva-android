-- Round 3088: Customer Monthly Engineer Hospital Code-Blue Drill Activation Latency Tracker
-- HEAVY star x4

-- ============================================================================
-- TABLE 1: code_blue_drill_events_r3088
-- ============================================================================
create table if not exists public.code_blue_drill_events_r3088 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  drill_code text not null,
  hospital_org_id uuid,
  hospital_name text not null,
  hospital_tier text not null,
  drill_month date not null,
  drill_scheduled_at timestamptz not null,
  drill_started_at timestamptz,
  drill_ended_at timestamptz,
  alarm_triggered_at timestamptz,
  first_engineer_responded_at timestamptz,
  equipment_activated_at timestamptz,
  activation_latency_seconds int,
  response_latency_seconds int,
  total_latency_seconds int,
  equipment_count int not null default 0,
  equipment_passed int not null default 0,
  drill_status text not null,
  outcome_grade text,
  drill_severity text not null,
  responder_engineer_id uuid,
  responder_name text,
  customer_profile_id uuid,
  notes text
);

alter table public.code_blue_drill_events_r3088 enable row level security;

alter table public.code_blue_drill_events_r3088
  add constraint code_blue_drill_events_r3088_hospital_tier_chk
  check (hospital_tier in ('tier_1','tier_2','tier_3','super_specialty'));

alter table public.code_blue_drill_events_r3088
  add constraint code_blue_drill_events_r3088_drill_status_chk
  check (drill_status in ('scheduled','in_progress','completed','failed','aborted'));

alter table public.code_blue_drill_events_r3088
  add constraint code_blue_drill_events_r3088_outcome_grade_chk
  check (outcome_grade in ('A','B','C','D','F') or outcome_grade is null);

alter table public.code_blue_drill_events_r3088
  add constraint code_blue_drill_events_r3088_drill_severity_chk
  check (drill_severity in ('routine','urgent','critical','catastrophic'));

drop policy if exists cbd_r3088_founder_all on public.code_blue_drill_events_r3088;
create policy cbd_r3088_founder_all on public.code_blue_drill_events_r3088
  for all using (is_founder()) with check (is_founder());

-- ============================================================================
-- TABLE 2: code_blue_drill_equipment_r3088
-- ============================================================================
create table if not exists public.code_blue_drill_equipment_r3088 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  drill_event_id uuid not null references public.code_blue_drill_events_r3088(id) on delete cascade,
  equipment_kind text not null,
  equipment_serial text not null,
  activation_attempted_at timestamptz,
  activation_succeeded_at timestamptz,
  activation_latency_seconds int,
  activation_result text not null,
  failure_reason text,
  engineer_id uuid,
  engineer_name text
);

alter table public.code_blue_drill_equipment_r3088 enable row level security;

alter table public.code_blue_drill_equipment_r3088
  add constraint code_blue_drill_equipment_r3088_kind_chk
  check (equipment_kind in ('defibrillator','crash_cart','ventilator','suction_pump','oxygen_cylinder','ecg_monitor','aed'));

alter table public.code_blue_drill_equipment_r3088
  add constraint code_blue_drill_equipment_r3088_result_chk
  check (activation_result in ('pass','fail','partial','not_attempted'));

drop policy if exists cbde_r3088_founder_all on public.code_blue_drill_equipment_r3088;
create policy cbde_r3088_founder_all on public.code_blue_drill_equipment_r3088
  for all using (is_founder()) with check (is_founder());

-- ============================================================================
-- SEED: code_blue_drill_events_r3088 (18 rows)
-- ============================================================================
insert into public.code_blue_drill_events_r3088
  (drill_code, hospital_name, hospital_tier, drill_month, drill_scheduled_at, drill_started_at, drill_ended_at, alarm_triggered_at, first_engineer_responded_at, equipment_activated_at, activation_latency_seconds, response_latency_seconds, total_latency_seconds, equipment_count, equipment_passed, drill_status, outcome_grade, drill_severity, responder_name, notes)
values
  ('CBD-3088-001','Apollo Jubilee Hills','super_specialty','2026-06-01'::date,'2026-06-03 09:00:00+05:30'::timestamptz,'2026-06-03 09:00:12+05:30'::timestamptz,'2026-06-03 09:14:00+05:30'::timestamptz,'2026-06-03 09:00:05+05:30'::timestamptz,'2026-06-03 09:00:47+05:30'::timestamptz,'2026-06-03 09:01:38+05:30'::timestamptz,93,42,840,6,6,'completed','A','critical','Ravi Kumar','clean drill, all equipment activated under target'),
  ('CBD-3088-002','KIMS Secunderabad','tier_1','2026-06-01'::date,'2026-06-05 10:30:00+05:30'::timestamptz,'2026-06-05 10:30:18+05:30'::timestamptz,'2026-06-05 10:46:00+05:30'::timestamptz,'2026-06-05 10:30:08+05:30'::timestamptz,'2026-06-05 10:31:22+05:30'::timestamptz,'2026-06-05 10:32:55+05:30'::timestamptz,167,74,960,5,5,'completed','A','urgent','Suresh Babu','engineer response within SLA'),
  ('CBD-3088-003','Yashoda Somajiguda','tier_1','2026-06-01'::date,'2026-06-07 11:00:00+05:30'::timestamptz,'2026-06-07 11:00:25+05:30'::timestamptz,'2026-06-07 11:18:00+05:30'::timestamptz,'2026-06-07 11:00:10+05:30'::timestamptz,'2026-06-07 11:02:14+05:30'::timestamptz,'2026-06-07 11:04:08+05:30'::timestamptz,238,124,1080,7,6,'completed','B','urgent','Priya Sharma','one ventilator partial activation'),
  ('CBD-3088-004','Continental Hospitals','super_specialty','2026-06-01'::date,'2026-06-09 14:00:00+05:30'::timestamptz,'2026-06-09 14:00:15+05:30'::timestamptz,'2026-06-09 14:13:00+05:30'::timestamptz,'2026-06-09 14:00:07+05:30'::timestamptz,'2026-06-09 14:00:51+05:30'::timestamptz,'2026-06-09 14:01:42+05:30'::timestamptz,99,44,780,6,6,'completed','A','critical','Arun Reddy','best-in-class response'),
  ('CBD-3088-005','Care Hospital Banjara','tier_2','2026-06-01'::date,'2026-06-11 09:30:00+05:30'::timestamptz,'2026-06-11 09:30:45+05:30'::timestamptz,'2026-06-11 09:52:00+05:30'::timestamptz,'2026-06-11 09:30:20+05:30'::timestamptz,'2026-06-11 09:33:08+05:30'::timestamptz,'2026-06-11 09:36:14+05:30'::timestamptz,354,168,1320,5,4,'completed','C','routine','Manoj Verma','crash cart slow to activate'),
  ('CBD-3088-006','Sunshine Paradise','tier_2','2026-06-01'::date,'2026-06-13 15:00:00+05:30'::timestamptz,'2026-06-13 15:00:30+05:30'::timestamptz,'2026-06-13 15:20:00+05:30'::timestamptz,'2026-06-13 15:00:15+05:30'::timestamptz,'2026-06-13 15:02:48+05:30'::timestamptz,'2026-06-13 15:05:22+05:30'::timestamptz,307,153,1200,4,3,'completed','C','urgent','Deepak Singh','aed battery low fail'),
  ('CBD-3088-007','MaxCure Madhapur','tier_2','2026-06-01'::date,'2026-06-15 08:30:00+05:30'::timestamptz,'2026-06-15 08:30:22+05:30'::timestamptz,'2026-06-15 08:50:00+05:30'::timestamptz,'2026-06-15 08:30:10+05:30'::timestamptz,'2026-06-15 08:31:55+05:30'::timestamptz,'2026-06-15 08:33:48+05:30'::timestamptz,218,105,1200,5,5,'completed','B','urgent','Rakesh Naidu','within SLA'),
  ('CBD-3088-008','Star Hospitals Banjara','tier_1','2026-06-01'::date,'2026-06-17 10:00:00+05:30'::timestamptz,'2026-06-17 10:00:14+05:30'::timestamptz,'2026-06-17 10:15:00+05:30'::timestamptz,'2026-06-17 10:00:06+05:30'::timestamptz,'2026-06-17 10:00:42+05:30'::timestamptz,'2026-06-17 10:01:28+05:30'::timestamptz,86,36,900,6,6,'completed','A','critical','Vinod Kumar','exemplary drill'),
  ('CBD-3088-009','Citizens Hospital Nallagandla','tier_2','2026-06-01'::date,'2026-06-19 11:30:00+05:30'::timestamptz,'2026-06-19 11:31:08+05:30'::timestamptz,'2026-06-19 11:55:00+05:30'::timestamptz,'2026-06-19 11:30:18+05:30'::timestamptz,'2026-06-19 11:34:22+05:30'::timestamptz,'2026-06-19 11:38:55+05:30'::timestamptz,548,244,1440,5,3,'completed','D','urgent','Sandeep Patel','defibrillator pad expired'),
  ('CBD-3088-010','AIG Gachibowli','super_specialty','2026-05-01'::date,'2026-05-04 09:00:00+05:30'::timestamptz,'2026-05-04 09:00:10+05:30'::timestamptz,'2026-05-04 09:12:00+05:30'::timestamptz,'2026-05-04 09:00:04+05:30'::timestamptz,'2026-05-04 09:00:38+05:30'::timestamptz,'2026-05-04 09:01:22+05:30'::timestamptz,82,34,720,7,7,'completed','A','catastrophic','Ravi Kumar','perfect run'),
  ('CBD-3088-011','Rainbow Childrens','tier_1','2026-05-01'::date,'2026-05-06 10:00:00+05:30'::timestamptz,'2026-05-06 10:00:20+05:30'::timestamptz,'2026-05-06 10:18:00+05:30'::timestamptz,'2026-05-06 10:00:09+05:30'::timestamptz,'2026-05-06 10:01:14+05:30'::timestamptz,'2026-05-06 10:02:42+05:30'::timestamptz,153,65,1080,6,6,'completed','B','critical','Priya Sharma','clean'),
  ('CBD-3088-012','SLG Hospital','tier_2','2026-05-01'::date,'2026-05-08 14:00:00+05:30'::timestamptz,'2026-05-08 14:01:08+05:30'::timestamptz,'2026-05-08 14:22:00+05:30'::timestamptz,'2026-05-08 14:00:22+05:30'::timestamptz,'2026-05-08 14:03:14+05:30'::timestamptz,'2026-05-08 14:07:48+05:30'::timestamptz,556,172,1320,5,3,'completed','D','urgent','Manoj Verma','suction pump dead'),
  ('CBD-3088-013','Olive Hospitals','tier_3','2026-05-01'::date,'2026-05-10 09:30:00+05:30'::timestamptz,'2026-05-10 09:31:42+05:30'::timestamptz,'2026-05-10 09:58:00+05:30'::timestamptz,'2026-05-10 09:30:35+05:30'::timestamptz,'2026-05-10 09:36:18+05:30'::timestamptz,'2026-05-10 09:42:08+05:30'::timestamptz,690,343,1680,4,2,'completed','F','urgent','Deepak Singh','two equipment failed activation'),
  ('CBD-3088-014','Asian Institute','super_specialty','2026-05-01'::date,'2026-05-12 11:00:00+05:30'::timestamptz,'2026-05-12 11:00:08+05:30'::timestamptz,'2026-05-12 11:11:00+05:30'::timestamptz,'2026-05-12 11:00:03+05:30'::timestamptz,'2026-05-12 11:00:32+05:30'::timestamptz,'2026-05-12 11:01:08+05:30'::timestamptz,65,29,660,7,7,'completed','A','catastrophic','Arun Reddy','best response of month'),
  ('CBD-3088-015','Image Hospitals','tier_2','2026-05-01'::date,'2026-05-14 10:30:00+05:30'::timestamptz,'2026-05-14 10:30:32+05:30'::timestamptz,'2026-05-14 10:48:00+05:30'::timestamptz,'2026-05-14 10:30:14+05:30'::timestamptz,'2026-05-14 10:31:48+05:30'::timestamptz,'2026-05-14 10:33:22+05:30'::timestamptz,188,94,1080,5,5,'completed','B','urgent','Suresh Babu','solid drill'),
  ('CBD-3088-016','Mediciti Hospital','tier_3','2026-05-01'::date,'2026-05-16 15:00:00+05:30'::timestamptz,null::timestamptz,null::timestamptz,'2026-05-16 15:00:15+05:30'::timestamptz,null::timestamptz,null::timestamptz,null,null,null,4,0,'aborted','F','routine','Sandeep Patel','engineer no-show'),
  ('CBD-3088-017','Premier Hospital','tier_2','2026-06-01'::date,'2026-06-21 09:00:00+05:30'::timestamptz,'2026-06-21 09:00:24+05:30'::timestamptz,null::timestamptz,'2026-06-21 09:00:10+05:30'::timestamptz,'2026-06-21 09:02:08+05:30'::timestamptz,null::timestamptz,null,118,null,5,2,'in_progress',null,'urgent','Rakesh Naidu','live drill ongoing'),
  ('CBD-3088-018','Krishna Institute','tier_1','2026-06-01'::date,'2026-06-25 10:00:00+05:30'::timestamptz,null::timestamptz,null::timestamptz,null::timestamptz,null::timestamptz,null::timestamptz,null,null,null,6,0,'scheduled',null,'critical','Vinod Kumar','upcoming');

-- ============================================================================
-- SEED: code_blue_drill_equipment_r3088 (20 rows)
-- ============================================================================
insert into public.code_blue_drill_equipment_r3088
  (drill_event_id, equipment_kind, equipment_serial, activation_attempted_at, activation_succeeded_at, activation_latency_seconds, activation_result, failure_reason, engineer_name)
select id, 'defibrillator', 'DEF-001', '2026-06-03 09:00:20+05:30'::timestamptz, '2026-06-03 09:00:55+05:30'::timestamptz, 35, 'pass', null, 'Ravi Kumar' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-001'
union all
select id, 'crash_cart', 'CC-001', '2026-06-03 09:00:25+05:30'::timestamptz, '2026-06-03 09:01:10+05:30'::timestamptz, 45, 'pass', null, 'Ravi Kumar' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-001'
union all
select id, 'ventilator', 'VEN-001', '2026-06-03 09:00:30+05:30'::timestamptz, '2026-06-03 09:01:38+05:30'::timestamptz, 68, 'pass', null, 'Ravi Kumar' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-001'
union all
select id, 'defibrillator', 'DEF-002', '2026-06-05 10:30:30+05:30'::timestamptz, '2026-06-05 10:31:20+05:30'::timestamptz, 50, 'pass', null, 'Suresh Babu' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-002'
union all
select id, 'ecg_monitor', 'ECG-002', '2026-06-05 10:30:35+05:30'::timestamptz, '2026-06-05 10:32:55+05:30'::timestamptz, 140, 'pass', null, 'Suresh Babu' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-002'
union all
select id, 'ventilator', 'VEN-003', '2026-06-07 11:01:00+05:30'::timestamptz, '2026-06-07 11:04:08+05:30'::timestamptz, 188, 'partial', 'slow tube connection', 'Priya Sharma' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-003'
union all
select id, 'suction_pump', 'SP-003', '2026-06-07 11:01:05+05:30'::timestamptz, '2026-06-07 11:02:30+05:30'::timestamptz, 85, 'pass', null, 'Priya Sharma' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-003'
union all
select id, 'aed', 'AED-006', '2026-06-13 15:01:00+05:30'::timestamptz, null::timestamptz, null, 'fail', 'battery exhausted', 'Deepak Singh' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-006'
union all
select id, 'oxygen_cylinder', 'OXY-006', '2026-06-13 15:01:10+05:30'::timestamptz, '2026-06-13 15:02:48+05:30'::timestamptz, 98, 'pass', null, 'Deepak Singh' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-006'
union all
select id, 'defibrillator', 'DEF-009', '2026-06-19 11:32:00+05:30'::timestamptz, null::timestamptz, null, 'fail', 'pads expired 2024', 'Sandeep Patel' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-009'
union all
select id, 'ventilator', 'VEN-009', '2026-06-19 11:33:00+05:30'::timestamptz, null::timestamptz, null, 'fail', 'firmware outdated', 'Sandeep Patel' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-009'
union all
select id, 'crash_cart', 'CC-009', '2026-06-19 11:34:00+05:30'::timestamptz, '2026-06-19 11:38:55+05:30'::timestamptz, 295, 'pass', null, 'Sandeep Patel' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-009'
union all
select id, 'defibrillator', 'DEF-010', '2026-05-04 09:00:15+05:30'::timestamptz, '2026-05-04 09:00:45+05:30'::timestamptz, 30, 'pass', null, 'Ravi Kumar' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-010'
union all
select id, 'aed', 'AED-010', '2026-05-04 09:00:20+05:30'::timestamptz, '2026-05-04 09:01:22+05:30'::timestamptz, 62, 'pass', null, 'Ravi Kumar' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-010'
union all
select id, 'suction_pump', 'SP-012', '2026-05-08 14:02:00+05:30'::timestamptz, null::timestamptz, null, 'fail', 'motor dead', 'Manoj Verma' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-012'
union all
select id, 'ventilator', 'VEN-012', '2026-05-08 14:03:00+05:30'::timestamptz, '2026-05-08 14:07:48+05:30'::timestamptz, 288, 'partial', 'slow boot', 'Manoj Verma' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-012'
union all
select id, 'defibrillator', 'DEF-013', '2026-05-10 09:36:30+05:30'::timestamptz, null::timestamptz, null, 'fail', 'pads missing', 'Deepak Singh' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-013'
union all
select id, 'crash_cart', 'CC-013', '2026-05-10 09:37:00+05:30'::timestamptz, '2026-05-10 09:42:08+05:30'::timestamptz, 308, 'partial', 'one drawer jammed', 'Deepak Singh' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-013'
union all
select id, 'ecg_monitor', 'ECG-014', '2026-05-12 11:00:15+05:30'::timestamptz, '2026-05-12 11:00:48+05:30'::timestamptz, 33, 'pass', null, 'Arun Reddy' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-014'
union all
select id, 'oxygen_cylinder', 'OXY-014', '2026-05-12 11:00:20+05:30'::timestamptz, '2026-05-12 11:01:08+05:30'::timestamptz, 48, 'pass', null, 'Arun Reddy' from public.code_blue_drill_events_r3088 where drill_code = 'CBD-3088-014';

-- ============================================================================
-- RPC 1: monthly summary
-- ============================================================================
create or replace function public.r3088_monthly_summary()
returns table (
  drill_month date,
  total_drills int,
  completed_drills int,
  failed_or_aborted int,
  avg_activation_seconds numeric,
  avg_response_seconds numeric,
  pass_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      e.drill_month,
      count(*)::int as total_drills,
      (count(*) filter (where e.drill_status = 'completed'))::int as completed_drills,
      (count(*) filter (where e.drill_status in ('failed','aborted')))::int as failed_or_aborted,
      round(avg(e.activation_latency_seconds)::numeric, 1) as avg_activation_seconds,
      round(avg(e.response_latency_seconds)::numeric, 1) as avg_response_seconds,
      round(100.0 * (count(*) filter (where e.outcome_grade in ('A','B')))::numeric
        / nullif(count(*) filter (where e.drill_status = 'completed'), 0), 1) as pass_rate_pct
    from public.code_blue_drill_events_r3088 e
    group by e.drill_month
    order by e.drill_month desc;
end;
$$;

revoke all on function public.r3088_monthly_summary() from public, anon;
grant execute on function public.r3088_monthly_summary() to authenticated;

-- ============================================================================
-- RPC 2: hospital tier breakdown
-- ============================================================================
create or replace function public.r3088_hospital_tier_breakdown()
returns table (
  hospital_tier text,
  drill_count int,
  avg_activation_seconds numeric,
  best_grade_count int,
  worst_grade_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      e.hospital_tier,
      count(*)::int as drill_count,
      round(avg(e.activation_latency_seconds)::numeric, 1) as avg_activation_seconds,
      (count(*) filter (where e.outcome_grade = 'A'))::int as best_grade_count,
      (count(*) filter (where e.outcome_grade in ('D','F')))::int as worst_grade_count
    from public.code_blue_drill_events_r3088 e
    group by e.hospital_tier
    order by avg(e.activation_latency_seconds) nulls last;
end;
$$;

revoke all on function public.r3088_hospital_tier_breakdown() from public, anon;
grant execute on function public.r3088_hospital_tier_breakdown() to authenticated;

-- ============================================================================
-- RPC 3: slowest activations
-- ============================================================================
create or replace function public.r3088_slowest_activations()
returns table (
  drill_code text,
  hospital_name text,
  drill_month date,
  activation_latency_seconds int,
  outcome_grade text,
  responder_name text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select e.drill_code, e.hospital_name, e.drill_month, e.activation_latency_seconds, e.outcome_grade, e.responder_name
    from public.code_blue_drill_events_r3088 e
    where e.activation_latency_seconds is not null
    order by e.activation_latency_seconds desc
    limit 10;
end;
$$;

revoke all on function public.r3088_slowest_activations() from public, anon;
grant execute on function public.r3088_slowest_activations() to authenticated;

-- ============================================================================
-- RPC 4: engineer leaderboard
-- ============================================================================
create or replace function public.r3088_engineer_leaderboard()
returns table (
  responder_name text,
  drills_attended int,
  avg_response_seconds numeric,
  avg_activation_seconds numeric,
  grade_a_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      e.responder_name,
      count(*)::int as drills_attended,
      round(avg(e.response_latency_seconds)::numeric, 1) as avg_response_seconds,
      round(avg(e.activation_latency_seconds)::numeric, 1) as avg_activation_seconds,
      (count(*) filter (where e.outcome_grade = 'A'))::int as grade_a_count
    from public.code_blue_drill_events_r3088 e
    where e.responder_name is not null
    group by e.responder_name
    order by avg(e.response_latency_seconds) nulls last;
end;
$$;

revoke all on function public.r3088_engineer_leaderboard() from public, anon;
grant execute on function public.r3088_engineer_leaderboard() to authenticated;

-- ============================================================================
-- RPC 5: equipment failure pareto
-- ============================================================================
create or replace function public.r3088_equipment_failure_pareto()
returns table (
  equipment_kind text,
  total_activations int,
  failures int,
  partials int,
  fail_rate_pct numeric,
  avg_latency_seconds numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      q.equipment_kind,
      count(*)::int as total_activations,
      (count(*) filter (where q.activation_result = 'fail'))::int as failures,
      (count(*) filter (where q.activation_result = 'partial'))::int as partials,
      round(100.0 * (count(*) filter (where q.activation_result = 'fail'))::numeric / nullif(count(*), 0), 1) as fail_rate_pct,
      round(avg(q.activation_latency_seconds)::numeric, 1) as avg_latency_seconds
    from public.code_blue_drill_equipment_r3088 q
    group by q.equipment_kind
    order by failures desc;
end;
$$;

revoke all on function public.r3088_equipment_failure_pareto() from public, anon;
grant execute on function public.r3088_equipment_failure_pareto() to authenticated;

-- ============================================================================
-- RPC 6: severity x grade matrix
-- ============================================================================
create or replace function public.r3088_severity_grade_matrix()
returns table (
  drill_severity text,
  grade_a int,
  grade_b int,
  grade_c int,
  grade_d int,
  grade_f int,
  ungraded int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      e.drill_severity,
      (count(*) filter (where e.outcome_grade = 'A'))::int as grade_a,
      (count(*) filter (where e.outcome_grade = 'B'))::int as grade_b,
      (count(*) filter (where e.outcome_grade = 'C'))::int as grade_c,
      (count(*) filter (where e.outcome_grade = 'D'))::int as grade_d,
      (count(*) filter (where e.outcome_grade = 'F'))::int as grade_f,
      (count(*) filter (where e.outcome_grade is null))::int as ungraded
    from public.code_blue_drill_events_r3088 e
    group by e.drill_severity
    order by e.drill_severity;
end;
$$;

revoke all on function public.r3088_severity_grade_matrix() from public, anon;
grant execute on function public.r3088_severity_grade_matrix() to authenticated;

-- ============================================================================
-- RPC 7: hospital month-over-month delta
-- ============================================================================
create or replace function public.r3088_hospital_mom_delta()
returns table (
  hospital_name text,
  may_avg_latency numeric,
  june_avg_latency numeric,
  delta_seconds numeric,
  trend text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    with may as (
      select hospital_name, avg(activation_latency_seconds) as a
      from public.code_blue_drill_events_r3088
      where drill_month = '2026-05-01'::date and activation_latency_seconds is not null
      group by hospital_name
    ),
    jun as (
      select hospital_name, avg(activation_latency_seconds) as a
      from public.code_blue_drill_events_r3088
      where drill_month = '2026-06-01'::date and activation_latency_seconds is not null
      group by hospital_name
    )
    select
      coalesce(j.hospital_name, m.hospital_name) as hospital_name,
      round(m.a::numeric, 1) as may_avg_latency,
      round(j.a::numeric, 1) as june_avg_latency,
      round((coalesce(j.a, 0) - coalesce(m.a, 0))::numeric, 1) as delta_seconds,
      case
        when m.a is null then 'new'
        when j.a is null then 'no_drill'
        when j.a < m.a then 'improved'
        when j.a > m.a then 'worsened'
        else 'flat'
      end as trend
    from jun j
    full outer join may m on m.hospital_name = j.hospital_name
    order by coalesce(j.a, 0) - coalesce(m.a, 0) desc nulls last;
end;
$$;

revoke all on function public.r3088_hospital_mom_delta() from public, anon;
grant execute on function public.r3088_hospital_mom_delta() to authenticated;

-- ============================================================================
-- RPC 8: in-progress and scheduled queue
-- ============================================================================
create or replace function public.r3088_open_drill_queue()
returns table (
  drill_code text,
  hospital_name text,
  hospital_tier text,
  drill_scheduled_at timestamptz,
  drill_status text,
  drill_severity text,
  responder_name text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select e.drill_code, e.hospital_name, e.hospital_tier, e.drill_scheduled_at, e.drill_status, e.drill_severity, e.responder_name
    from public.code_blue_drill_events_r3088 e
    where e.drill_status in ('scheduled','in_progress')
    order by e.drill_scheduled_at asc;
end;
$$;

revoke all on function public.r3088_open_drill_queue() from public, anon;
grant execute on function public.r3088_open_drill_queue() to authenticated;
