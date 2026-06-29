-- Round 3033 — Founder Quarterly Strategic Engineer-Founder Direct-Line Skip-Level Pulse Audit
-- HEAVY ★★★★

create table if not exists skip_level_pulse_sessions_r3033 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  quarter text not null check (quarter in ('Q1','Q2','Q3','Q4')),
  fiscal_year int not null check (fiscal_year between 2024 and 2030),
  engineer_code text not null,
  engineer_tier text not null check (engineer_tier in ('bronze','silver','gold','platinum')),
  region text not null check (region in ('north','south','east','west','central')),
  session_status text not null check (session_status in ('scheduled','completed','cancelled','rescheduled','no_show')),
  scheduled_at timestamptz,
  completed_at timestamptz,
  duration_minutes int check (duration_minutes between 0 and 120),
  candor_score numeric(3,1) check (candor_score between 0 and 10),
  morale_score numeric(3,1) check (morale_score between 0 and 10),
  flight_risk text check (flight_risk in ('low','medium','high','critical')),
  net_promoter int check (net_promoter between -100 and 100),
  top_concern text,
  founder_action_committed text,
  follow_up_required boolean default false
);

create table if not exists skip_level_strategic_signals_r3033 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  session_id uuid references skip_level_pulse_sessions_r3033(id) on delete cascade,
  signal_category text not null check (signal_category in ('strategy','culture','process','tooling','compensation','growth','customer','leadership')),
  signal_severity text not null check (signal_severity in ('info','low','medium','high','critical')),
  signal_theme text not null,
  signal_summary text not null,
  recurrence_count int default 1 check (recurrence_count >= 1),
  confidence_pct int check (confidence_pct between 0 and 100),
  founder_response_status text not null check (founder_response_status in ('open','acknowledged','in_progress','resolved','wont_fix')),
  resolved_at timestamptz,
  impact_score numeric(4,1) check (impact_score between 0 and 100)
);

alter table skip_level_pulse_sessions_r3033 enable row level security;
alter table skip_level_strategic_signals_r3033 enable row level security;

drop policy if exists founder_read_sessions_r3033 on skip_level_pulse_sessions_r3033;
create policy founder_read_sessions_r3033 on skip_level_pulse_sessions_r3033 for select to authenticated using (is_founder());

drop policy if exists founder_read_signals_r3033 on skip_level_strategic_signals_r3033;
create policy founder_read_signals_r3033 on skip_level_strategic_signals_r3033 for select to authenticated using (is_founder());

insert into skip_level_pulse_sessions_r3033 (quarter, fiscal_year, engineer_code, engineer_tier, region, session_status, scheduled_at, completed_at, duration_minutes, candor_score, morale_score, flight_risk, net_promoter, top_concern, founder_action_committed, follow_up_required) values
('Q2', 2026, 'ENG-101', 'platinum', 'south', 'completed', '2026-06-02 10:00'::timestamptz, '2026-06-02 10:45'::timestamptz, 45, 9.2, 8.5, 'low', 70, 'spare parts ETA visibility', 'launch parts ETA dashboard by Q3', false),
('Q2', 2026, 'ENG-102', 'gold', 'north', 'completed', '2026-06-03 11:00'::timestamptz, '2026-06-03 11:50'::timestamptz, 50, 8.7, 7.8, 'medium', 40, 'on-call rotation fairness', 'rotation algorithm rewrite', true),
('Q2', 2026, 'ENG-103', 'silver', 'east', 'completed', '2026-06-04 14:00'::timestamptz, '2026-06-04 14:35'::timestamptz, 35, 7.5, 6.2, 'high', -10, 'compensation gap vs market', 'comp band review in Q3', true),
('Q2', 2026, 'ENG-104', 'gold', 'west', 'completed', '2026-06-05 09:30'::timestamptz, '2026-06-05 10:20'::timestamptz, 50, 9.0, 8.8, 'low', 80, 'hospital chain RFP scope', 'pilot 3 chains Q3', false),
('Q2', 2026, 'ENG-105', 'bronze', 'central', 'completed', '2026-06-06 15:00'::timestamptz, '2026-06-06 15:25'::timestamptz, 25, 6.8, 5.5, 'critical', -30, 'training pipeline broken', 'reboot training Q3 week 1', true),
('Q2', 2026, 'ENG-106', 'platinum', 'south', 'completed', '2026-06-08 10:00'::timestamptz, '2026-06-08 10:55'::timestamptz, 55, 9.5, 9.1, 'low', 90, 'AI triage rollout plan', 'beta with top 10 engineers', false),
('Q2', 2026, 'ENG-107', 'gold', 'north', 'completed', '2026-06-09 11:30'::timestamptz, '2026-06-09 12:15'::timestamptz, 45, 8.3, 7.5, 'medium', 30, 'customer dispute frequency', 'auto-mediation tool', true),
('Q2', 2026, 'ENG-108', 'silver', 'east', 'no_show', '2026-06-10 14:00'::timestamptz, null::timestamptz, null, null, null, null, null, null, null, true),
('Q2', 2026, 'ENG-109', 'gold', 'west', 'completed', '2026-06-11 09:00'::timestamptz, '2026-06-11 09:40'::timestamptz, 40, 8.8, 8.0, 'low', 60, 'AMC churn signals', 'churn dashboard Q3', false),
('Q2', 2026, 'ENG-110', 'platinum', 'south', 'completed', '2026-06-12 10:30'::timestamptz, '2026-06-12 11:20'::timestamptz, 50, 9.3, 8.9, 'low', 85, 'engineer app v0.6 wishlist', 'ship 3 top requests', false),
('Q2', 2026, 'ENG-111', 'silver', 'central', 'rescheduled', '2026-06-13 13:00'::timestamptz, null::timestamptz, null, null, null, null, null, null, null, true),
('Q2', 2026, 'ENG-112', 'bronze', 'north', 'completed', '2026-06-14 11:00'::timestamptz, '2026-06-14 11:30'::timestamptz, 30, 7.0, 6.5, 'high', 10, 'mentor allocation', 'pair with platinum Q3', true),
('Q2', 2026, 'ENG-113', 'gold', 'east', 'completed', '2026-06-15 14:30'::timestamptz, '2026-06-15 15:15'::timestamptz, 45, 8.5, 7.9, 'medium', 35, 'tooling lag on Android', 'fix 5 P0 bugs Q3', true),
('Q2', 2026, 'ENG-114', 'platinum', 'west', 'completed', '2026-06-16 10:00'::timestamptz, '2026-06-16 10:50'::timestamptz, 50, 9.1, 8.7, 'low', 75, 'investor narrative clarity', 'share board pack monthly', false),
('Q2', 2026, 'ENG-115', 'silver', 'south', 'cancelled', '2026-06-17 15:00'::timestamptz, null::timestamptz, null, null, null, null, null, null, null, false),
('Q2', 2026, 'ENG-116', 'gold', 'central', 'completed', '2026-06-18 09:30'::timestamptz, '2026-06-18 10:15'::timestamptz, 45, 8.6, 8.1, 'low', 50, 'hospital portal latency', 'CDN rollout Q3', true),
('Q2', 2026, 'ENG-117', 'bronze', 'north', 'completed', '2026-06-19 11:00'::timestamptz, '2026-06-19 11:25'::timestamptz, 25, 6.5, 5.8, 'high', -5, 'first-week onboarding chaos', 'onboarding revamp Q3', true),
('Q2', 2026, 'ENG-118', 'platinum', 'east', 'completed', '2026-06-20 14:00'::timestamptz, '2026-06-20 14:55'::timestamptz, 55, 9.4, 9.0, 'low', 88, 'international pilot readiness', 'SL/BD scoping Q3', false);

insert into skip_level_strategic_signals_r3033 (session_id, signal_category, signal_severity, signal_theme, signal_summary, recurrence_count, confidence_pct, founder_response_status, resolved_at, impact_score)
select s.id, 'tooling', 'high', 'parts_eta_visibility', 'engineers blind to parts ETA', 4, 92, 'in_progress', null::timestamptz, 72.5 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-101'
union all
select s.id, 'process', 'medium', 'oncall_rotation', 'rotation perceived unfair', 6, 85, 'acknowledged', null::timestamptz, 55.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-102'
union all
select s.id, 'compensation', 'critical', 'comp_gap_market', 'silver tier 18% below market', 8, 96, 'open', null::timestamptz, 88.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-103'
union all
select s.id, 'strategy', 'high', 'hospital_chains_rfp', 'chain RFP requires v2 features', 3, 78, 'in_progress', null::timestamptz, 70.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-104'
union all
select s.id, 'growth', 'critical', 'training_pipeline_broken', 'bronze tier training stalled', 5, 90, 'in_progress', null::timestamptz, 82.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-105'
union all
select s.id, 'tooling', 'medium', 'ai_triage_rollout', 'AI triage beta interest high', 7, 82, 'in_progress', null::timestamptz, 65.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-106'
union all
select s.id, 'customer', 'high', 'dispute_frequency', 'hospital disputes spiking', 4, 88, 'acknowledged', null::timestamptz, 68.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-107'
union all
select s.id, 'strategy', 'medium', 'amc_churn_signals', 'AMC churn ticking up Q2', 3, 75, 'in_progress', null::timestamptz, 60.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-109'
union all
select s.id, 'tooling', 'high', 'engineer_app_v06', 'top 3 feature requests recurring', 9, 94, 'in_progress', null::timestamptz, 76.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-110'
union all
select s.id, 'culture', 'medium', 'mentor_allocation', 'bronze lacks platinum mentor', 4, 80, 'acknowledged', null::timestamptz, 50.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-112'
union all
select s.id, 'tooling', 'high', 'android_p0_bugs', '5 P0 bugs blocking field', 6, 91, 'in_progress', null::timestamptz, 74.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-113'
union all
select s.id, 'leadership', 'low', 'investor_narrative', 'platinum wants board visibility', 2, 70, 'resolved', '2026-06-22 12:00'::timestamptz, 35.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-114'
union all
select s.id, 'tooling', 'medium', 'hospital_portal_latency', 'portal slow >2s p95', 5, 86, 'in_progress', null::timestamptz, 62.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-116'
union all
select s.id, 'process', 'critical', 'onboarding_revamp', 'first-week churn risk', 7, 93, 'open', null::timestamptz, 85.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-117'
union all
select s.id, 'strategy', 'low', 'international_pilot', 'SL/BD ready Q4 targets', 2, 65, 'open', null::timestamptz, 40.0 from skip_level_pulse_sessions_r3033 s where s.engineer_code='ENG-118';

create or replace function r3033_quarter_pulse_summary()
returns table(quarter text, fiscal_year int, completed_sessions int, scheduled_sessions int, completion_rate_pct numeric, avg_candor numeric, avg_morale numeric, critical_flight_risk int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.quarter, s.fiscal_year,
      (count(*) filter (where s.session_status='completed'))::int,
      count(*)::int,
      round(100.0 * (count(*) filter (where s.session_status='completed'))::numeric / nullif(count(*),0), 1),
      round(avg(s.candor_score)::numeric, 2),
      round(avg(s.morale_score)::numeric, 2),
      (count(*) filter (where s.flight_risk='critical'))::int
    from skip_level_pulse_sessions_r3033 s
    group by s.quarter, s.fiscal_year
    order by s.fiscal_year desc, s.quarter desc;
end $$;

create or replace function r3033_tier_morale_breakdown()
returns table(engineer_tier text, sessions int, avg_morale numeric, avg_candor numeric, avg_nps numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.engineer_tier, count(*)::int,
      round(avg(s.morale_score)::numeric, 2),
      round(avg(s.candor_score)::numeric, 2),
      round(avg(s.net_promoter)::numeric, 1)
    from skip_level_pulse_sessions_r3033 s
    where s.session_status='completed'
    group by s.engineer_tier
    order by avg(s.morale_score) desc nulls last;
end $$;

create or replace function r3033_flight_risk_register()
returns table(engineer_code text, engineer_tier text, region text, flight_risk text, morale_score numeric, top_concern text, follow_up_required boolean)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.engineer_code, s.engineer_tier, s.region, s.flight_risk, s.morale_score, s.top_concern, s.follow_up_required
    from skip_level_pulse_sessions_r3033 s
    where s.flight_risk in ('high','critical')
    order by case s.flight_risk when 'critical' then 1 when 'high' then 2 else 3 end, s.morale_score asc nulls last;
end $$;

create or replace function r3033_signal_category_heatmap()
returns table(signal_category text, total_signals int, critical_signals int, open_signals int, avg_impact numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select x.signal_category, count(*)::int,
      (count(*) filter (where x.signal_severity='critical'))::int,
      (count(*) filter (where x.founder_response_status in ('open','acknowledged')))::int,
      round(avg(x.impact_score)::numeric, 1)
    from skip_level_strategic_signals_r3033 x
    group by x.signal_category
    order by avg(x.impact_score) desc nulls last;
end $$;

create or replace function r3033_open_critical_signals()
returns table(signal_theme text, signal_category text, signal_severity text, recurrence_count int, confidence_pct int, impact_score numeric, founder_response_status text)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select x.signal_theme, x.signal_category, x.signal_severity, x.recurrence_count, x.confidence_pct, x.impact_score, x.founder_response_status
    from skip_level_strategic_signals_r3033 x
    where x.signal_severity in ('high','critical')
      and x.founder_response_status in ('open','acknowledged','in_progress')
    order by x.impact_score desc nulls last;
end $$;

create or replace function r3033_region_pulse_grid()
returns table(region text, completed int, avg_morale numeric, high_critical_risk int, signals_logged int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.region,
      (count(*) filter (where s.session_status='completed'))::int,
      round(avg(s.morale_score)::numeric, 2),
      (count(*) filter (where s.flight_risk in ('high','critical')))::int,
      (select count(*)::int from skip_level_strategic_signals_r3033 x where x.session_id in (select id from skip_level_pulse_sessions_r3033 s2 where s2.region=s.region))
    from skip_level_pulse_sessions_r3033 s
    group by s.region
    order by avg(s.morale_score) asc nulls last;
end $$;

create or replace function r3033_followup_action_queue()
returns table(engineer_code text, engineer_tier text, top_concern text, founder_action_committed text, flight_risk text, completed_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.engineer_code, s.engineer_tier, s.top_concern, s.founder_action_committed, s.flight_risk, s.completed_at
    from skip_level_pulse_sessions_r3033 s
    where s.follow_up_required = true
    order by case s.flight_risk when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end, s.completed_at desc nulls last;
end $$;

revoke all on function r3033_quarter_pulse_summary() from public, anon;
revoke all on function r3033_tier_morale_breakdown() from public, anon;
revoke all on function r3033_flight_risk_register() from public, anon;
revoke all on function r3033_signal_category_heatmap() from public, anon;
revoke all on function r3033_open_critical_signals() from public, anon;
revoke all on function r3033_region_pulse_grid() from public, anon;
revoke all on function r3033_followup_action_queue() from public, anon;

grant execute on function r3033_quarter_pulse_summary() to authenticated;
grant execute on function r3033_tier_morale_breakdown() to authenticated;
grant execute on function r3033_flight_risk_register() to authenticated;
grant execute on function r3033_signal_category_heatmap() to authenticated;
grant execute on function r3033_open_critical_signals() to authenticated;
grant execute on function r3033_region_pulse_grid() to authenticated;
grant execute on function r3033_followup_action_queue() to authenticated;
