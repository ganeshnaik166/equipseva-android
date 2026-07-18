-- Round 3229: Founder Founder-Health, Sleep & Sustainable-Pace Scorecard
-- Weekly founder health log — sleep × workouts × screen-time × deep-work × stress × recovery × energy trend × burnout-risk verdict × rebalance CAPA

-- =============================================================================
-- TABLE 1: founder_health_r3229 — weekly founder health & pace log
-- =============================================================================
create table if not exists public.founder_health_r3229 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  founder_name text not null,
  anchor_hospital_site text not null,
  week_label text not null,
  week_start_date date not null,
  avg_sleep_hours numeric(4,2) not null,
  sleep_quality text not null check (sleep_quality in (
    'deep_restorative','adequate','fragmented','poor_interrupted','severely_deprived'
  )),
  workout_sessions int not null,
  workout_type_mix text not null check (workout_type_mix in (
    'strength_cardio_mix','cardio_only','strength_only','yoga_mobility','walking_only','none'
  )),
  avg_screen_time_hours numeric(4,2) not null,
  deep_work_blocks int not null,
  meetings_load text not null check (meetings_load in (
    'light','moderate','heavy','back_to_back_overload'
  )),
  stress_rating text not null check (stress_rating in (
    'calm','manageable','elevated','high','severe'
  )),
  recovery_day_taken boolean not null default false,
  caffeine_intake_level text not null check (caffeine_intake_level in (
    'none','low','moderate','high','excessive'
  )),
  energy_trend text not null check (energy_trend in (
    'improving','stable','declining','volatile','crashed'
  )),
  burnout_risk_verdict text not null check (burnout_risk_verdict in (
    'sustainable','watch','at_risk','high_risk','critical_intervention'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.founder_health_r3229 enable row level security;

create index if not exists idx_founder_health_r3229_org on public.founder_health_r3229(organization_id);
create index if not exists idx_founder_health_r3229_week on public.founder_health_r3229(week_start_date);
create index if not exists idx_founder_health_r3229_verdict on public.founder_health_r3229(burnout_risk_verdict);

-- =============================================================================
-- TABLE 2: founder_health_capa_actions_r3229 — rebalance / CAPA actions
-- =============================================================================
create table if not exists public.founder_health_capa_actions_r3229 (
  id uuid primary key default gen_random_uuid(),
  health_log_id uuid not null references public.founder_health_r3229(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sleep_debt','overtraining_or_no_training','screen_time_overload','deep_work_collapse',
    'chronic_stress','no_recovery_days','energy_crash','travel_fatigue'
  )),
  root_cause text not null check (root_cause in (
    'late_night_firefighting','investor_deadline_crunch','on_site_escalations',
    'poor_sleep_hygiene','excessive_travel','delegation_gap','doomscrolling_habit','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'enforce_sleep_window','delegate_onsite_escalations','block_deep_work_mornings',
    'schedule_recovery_weekend','hire_ea_support','digital_sunset_rule',
    'travel_batching','therapy_coaching_session','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'board_flagged','investor_visible','team_visible','personal_only','medical_attention_needed','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.founder_health_capa_actions_r3229 enable row level security;

create index if not exists idx_founder_health_capa_r3229_log on public.founder_health_capa_actions_r3229(health_log_id);
create index if not exists idx_founder_health_capa_r3229_status on public.founder_health_capa_actions_r3229(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 13 weekly health log rows
  insert into public.founder_health_r3229 (
    organization_id, founder_name, anchor_hospital_site, week_label, week_start_date,
    avg_sleep_hours, sleep_quality, workout_sessions, workout_type_mix,
    avg_screen_time_hours, deep_work_blocks, meetings_load, stress_rating,
    recovery_day_taken, caffeine_intake_level, energy_trend, burnout_risk_verdict, notes
  )
  select v_org_id, q.fn, q.site, q.wl, q.wsd::date,
    q.ash, q.sq, q.ws, q.wt,
    q.sth, q.dwb, q.ml, q.sr,
    q.rd, q.caf, q.et, q.brv, q.nt
  from (values
    ('Ganesh','Apollo Hyderabad Jubilee Hills','2026-W16','2026-04-13',7.40,'adequate',4,'strength_cardio_mix',5.10,9,'moderate','manageable',true,'moderate','stable','sustainable','Good baseline week — morning workouts held'),
    ('Ganesh','Fortis Bannerghatta Bengaluru','2026-W17','2026-04-20',6.80,'adequate',3,'cardio_only',6.20,7,'heavy','elevated',true,'moderate','stable','watch','Travel to Bengaluru mid-week compressed sleep'),
    ('Ganesh','Manipal Whitefield Bengaluru','2026-W18','2026-04-27',6.10,'fragmented',2,'walking_only',7.40,5,'heavy','elevated',false,'high','declining','watch','Two escalations at Manipal ate deep-work mornings'),
    ('Ganesh','AIIMS New Delhi Ansari Nagar','2026-W19','2026-05-04',5.60,'poor_interrupted',1,'walking_only',8.30,3,'back_to_back_overload','high',false,'high','declining','at_risk','Delhi tender week — late-night document firefighting'),
    ('Ganesh','AIIMS New Delhi Ansari Nagar','2026-W20','2026-05-11',5.20,'severely_deprived',0,'none',9.10,2,'back_to_back_overload','severe',false,'excessive','crashed','high_risk','Slept under 5.5 hrs on 4 nights — energy crash Friday'),
    ('Ganesh','KIMS Secunderabad','2026-W21','2026-05-18',6.40,'fragmented',2,'yoga_mobility',7.00,5,'heavy','high',true,'high','volatile','at_risk','Forced Sunday recovery day after crash'),
    ('Ganesh','Care Hospitals Banjara Hills','2026-W22','2026-05-25',7.10,'adequate',3,'strength_cardio_mix',5.80,7,'moderate','elevated',true,'moderate','improving','watch','Digital sunset rule started — screen time down'),
    ('Ganesh','Yashoda Somajiguda Hyderabad','2026-W23','2026-06-01',7.60,'deep_restorative',4,'strength_cardio_mix',4.90,10,'moderate','manageable',true,'low','improving','sustainable','Best deep-work week of the quarter'),
    ('Ganesh','St John''s Bengaluru','2026-W24','2026-06-08',6.90,'adequate',3,'strength_only',5.60,8,'moderate','manageable',true,'moderate','stable','sustainable','Bengaluru trip batched into two days'),
    ('Ganesh','Rainbow Children''s Hyderabad','2026-W25','2026-06-15',6.30,'fragmented',2,'cardio_only',6.90,6,'heavy','elevated',false,'high','declining','watch','Board deck prep crept into nights'),
    ('Ganesh','Fortis Bannerghatta Bengaluru','2026-W26','2026-06-22',5.90,'poor_interrupted',1,'walking_only',8.00,4,'back_to_back_overload','high',false,'high','declining','at_risk','Investor diligence calls across time zones'),
    ('Ganesh','Apollo Hyderabad Jubilee Hills','2026-W27','2026-06-29',5.40,'severely_deprived',1,'walking_only',8.70,3,'back_to_back_overload','severe',false,'excessive','crashed','critical_intervention','Two all-nighters — coach escalated intervention plan'),
    ('Ganesh','KIMS Secunderabad','2026-W28','2026-07-06',6.70,'adequate',3,'yoga_mobility',6.10,6,'moderate','elevated',true,'moderate','improving','watch','Recovery plan week one — sleep window enforced')
  ) as q(fn, site, wl, wsd, ash, sq, ws, wt, sth, dwb, ml, sr, rd, caf, et, brv, nt);

  -- Rebalance / CAPA seed — attach to specific weeks
  insert into public.founder_health_capa_actions_r3229 (
    health_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('2026-W20','sleep_debt','investor_deadline_crunch','enforce_sleep_window','2026-05-25','2026-05-24','closed','personal_only',0,'Fixed 23:00-06:30 sleep window with phone outside bedroom'),
    ('2026-W20','energy_crash','late_night_firefighting','delegate_onsite_escalations','2026-06-01',null,'in_progress','team_visible',60000.00,'Senior engineer now owns AIIMS on-site escalations'),
    ('2026-W21','no_recovery_days','delegation_gap','hire_ea_support','2026-06-30',null,'in_progress','board_flagged',45000.00,'EA hiring in final round — calendar triage offload'),
    ('2026-W25','screen_time_overload','doomscrolling_habit','digital_sunset_rule','2026-06-22','2026-06-20','closed','personal_only',0,'App limits after 21:30 — screen time down 1.8 hrs'),
    ('2026-W26','travel_fatigue','excessive_travel','travel_batching','2026-07-10',null,'verification_pending','team_visible',12000.00,'Bengaluru visits batched to alternate weeks'),
    ('2026-W27','chronic_stress','investor_deadline_crunch','therapy_coaching_session','2026-07-20',null,'escalated','medical_attention_needed',18000.00,'Fortnightly coaching sessions booked — physician review advised'),
    ('2026-W27','deep_work_collapse','on_site_escalations','block_deep_work_mornings','2026-07-05',null,'overdue','board_flagged',0,'Morning 08:00-11:00 maker blocks still being broken')
  ) as q(wl_key, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.founder_health_r3229 e
    on e.organization_id = v_org_id and e.week_label = q.wl_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Burnout-risk verdict distribution
create or replace function public.founder_r3229_burnout_verdict_rollup()
returns table(burnout_risk_verdict text, weeks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.founder_health_r3229)
  select h.burnout_risk_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.founder_health_r3229 h
  group by h.burnout_risk_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3229_burnout_verdict_rollup() from public, anon;
grant execute on function public.founder_r3229_burnout_verdict_rollup() to authenticated;

-- 2) Anchor-site scorecard (where the founder spent the week)
create or replace function public.founder_r3229_site_scorecard()
returns table(
  anchor_hospital_site text,
  weeks bigint,
  avg_sleep_hours numeric,
  avg_screen_time_hours numeric,
  total_workouts bigint,
  recovery_weeks bigint,
  at_risk_weeks bigint,
  sustainable_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select h.anchor_hospital_site,
    count(*)::bigint,
    round(avg(h.avg_sleep_hours), 2),
    round(avg(h.avg_screen_time_hours), 2),
    coalesce(sum(h.workout_sessions),0)::bigint,
    count(*) filter (where h.recovery_day_taken)::bigint,
    count(*) filter (where h.burnout_risk_verdict in ('at_risk','high_risk','critical_intervention'))::bigint,
    round(100.0 * count(*) filter (where h.burnout_risk_verdict = 'sustainable')::numeric / nullif(count(*),0), 1)
  from public.founder_health_r3229 h
  group by h.anchor_hospital_site
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3229_site_scorecard() from public, anon;
grant execute on function public.founder_r3229_site_scorecard() to authenticated;

-- 3) Stress × energy trend matrix
create or replace function public.founder_r3229_stress_energy_matrix()
returns table(stress_rating text, energy_trend text, weeks bigint, avg_sleep_hours numeric, avg_deep_work_blocks numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select h.stress_rating, h.energy_trend, count(*)::bigint,
    round(avg(h.avg_sleep_hours), 2),
    round(avg(h.deep_work_blocks), 1)
  from public.founder_health_r3229 h
  group by h.stress_rating, h.energy_trend
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3229_stress_energy_matrix() from public, anon;
grant execute on function public.founder_r3229_stress_energy_matrix() to authenticated;

-- 4) Weekly pace trend
create or replace function public.founder_r3229_weekly_pace_trend()
returns table(
  week_start_date date,
  week_label text,
  avg_sleep_hours numeric,
  workout_sessions int,
  avg_screen_time_hours numeric,
  deep_work_blocks int,
  recovery_day_taken boolean,
  burnout_risk_verdict text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select h.week_start_date, h.week_label, h.avg_sleep_hours, h.workout_sessions,
    h.avg_screen_time_hours, h.deep_work_blocks, h.recovery_day_taken, h.burnout_risk_verdict
  from public.founder_health_r3229 h
  order by h.week_start_date desc;
end;
$$;

revoke execute on function public.founder_r3229_weekly_pace_trend() from public, anon;
grant execute on function public.founder_r3229_weekly_pace_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3229_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.founder_health_capa_actions_r3229 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3229_capa_status_board() from public, anon;
grant execute on function public.founder_r3229_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3229_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.founder_health_capa_actions_r3229)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.founder_health_capa_actions_r3229 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3229_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3229_root_cause_pareto() to authenticated;

-- 7) Visibility / impact digest
create or replace function public.founder_r3229_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.founder_health_capa_actions_r3229 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3229_impact_digest() from public, anon;
grant execute on function public.founder_r3229_impact_digest() to authenticated;

-- 8) High-risk weeks queue (top individual concerns)
create or replace function public.founder_r3229_high_risk_weeks_queue()
returns table(
  week_label text,
  week_start_date date,
  anchor_hospital_site text,
  avg_sleep_hours numeric,
  stress_rating text,
  energy_trend text,
  burnout_risk_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select h.week_label, h.week_start_date, h.anchor_hospital_site,
    h.avg_sleep_hours, h.stress_rating, h.energy_trend, h.burnout_risk_verdict, h.notes
  from public.founder_health_r3229 h
  where h.burnout_risk_verdict in ('at_risk','high_risk','critical_intervention')
     or h.stress_rating = 'severe'
     or h.energy_trend = 'crashed'
     or h.avg_sleep_hours < 6.0
  order by h.week_start_date desc;
end;
$$;

revoke execute on function public.founder_r3229_high_risk_weeks_queue() from public, anon;
grant execute on function public.founder_r3229_high_risk_weeks_queue() to authenticated;
