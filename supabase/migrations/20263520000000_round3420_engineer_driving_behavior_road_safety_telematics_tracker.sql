-- Round 3420: Engineer Driving-Behavior Road-Safety Telematics Tracker
-- Field-engineer driving safety — engineer × region × period × harsh-events × overspeeding × night-driving × fatigue × seatbelt × mobile-use × safety-score × accidents × near-misses × CAPA

-- =============================================================================
-- TABLE 1: engineer_driving_behavior_r3420 — per engineer-period telematics safety record
-- =============================================================================
create table if not exists public.engineer_driving_behavior_r3420 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null check (region in (
    'north','south','east','west','central'
  )),
  period_month text not null,
  km_driven int not null,
  harsh_braking_events int not null,
  harsh_acceleration_events int not null,
  overspeeding_events int not null,
  night_driving_hours numeric(6,1),
  fatigue_alert_count int not null,
  seatbelt_compliance_pct numeric(5,2),
  mobile_use_while_driving_events int not null,
  safety_score numeric(5,2),
  accidents int not null,
  near_misses int not null,
  license_valid boolean not null,
  defensive_training_current boolean not null,
  safety_verdict text not null check (safety_verdict in (
    'safe','watch','coaching_needed','high_risk','suspend_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_driving_behavior_r3420 enable row level security;

create index if not exists idx_engineer_driving_behavior_r3420_org on public.engineer_driving_behavior_r3420(organization_id);
create index if not exists idx_engineer_driving_behavior_r3420_period on public.engineer_driving_behavior_r3420(period_month);
create index if not exists idx_engineer_driving_behavior_r3420_verdict on public.engineer_driving_behavior_r3420(safety_verdict);

-- =============================================================================
-- TABLE 2: engineer_driving_behavior_capa_actions_r3420 — coaching / training / escalation actions
-- =============================================================================
create table if not exists public.engineer_driving_behavior_capa_actions_r3420 (
  id uuid primary key default gen_random_uuid(),
  driving_log_id uuid not null references public.engineer_driving_behavior_r3420(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'harsh_braking','harsh_acceleration','overspeeding','fatigue_driving','mobile_use_while_driving',
    'seatbelt_noncompliance','accident','near_miss','license_expired','defensive_training_overdue'
  )),
  root_cause text not null check (root_cause in (
    'aggressive_driving_habit','route_time_pressure','insufficient_rest','phone_distraction',
    'poor_vehicle_condition','inadequate_training','adverse_road_weather','pending_investigation',
    'scheduling_overload','seatbelt_habit_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'defensive_driving_training','route_rescheduling','fatigue_management_counseling','phone_lockout_policy',
    'vehicle_maintenance','coaching_session','written_warning','license_renewal_support',
    'ride_along_audit','suspend_from_driving','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  escalation_impact text not null check (escalation_impact in (
    'none','internal_only','verbal_warning','written_warning','insurance_notifiable','hr_disciplinary','license_action_review'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_driving_behavior_capa_actions_r3420 enable row level security;

create index if not exists idx_engineer_driving_capa_r3420_log on public.engineer_driving_behavior_capa_actions_r3420(driving_log_id);
create index if not exists idx_engineer_driving_capa_r3420_status on public.engineer_driving_behavior_capa_actions_r3420(capa_status);

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

  -- 14 engineer-period telematics rows
  insert into public.engineer_driving_behavior_r3420 (
    organization_id, engineer_name, region, period_month, km_driven,
    harsh_braking_events, harsh_acceleration_events, overspeeding_events, night_driving_hours,
    fatigue_alert_count, seatbelt_compliance_pct, mobile_use_while_driving_events, safety_score,
    accidents, near_misses, license_valid, defensive_training_current, safety_verdict, notes
  )
  select v_org_id, q.eng, q.region, q.pm, q.km,
    q.hb, q.ha, q.os, q.ndh,
    q.fa, q.sb, q.mu, q.ss,
    q.acc, q.nm, q.lic, q.dtc, q.sv, q.nt
  from (values
    ('Rajesh Kumar','south','2026-06',2450,
     3,2,1,6.5,0,99.0,0,88.5,0,0,true,true,'safe','Chennai-Vellore corridor; clean telematics quarter'),
    ('Anil Sharma','north','2026-06',3120,
     12,9,7,18.0,3,82.0,4,61.0,0,2,true,false,'coaching_needed','Delhi-NCR; frequent harsh events, defensive training overdue'),
    ('Suresh Reddy','south','2026-06',2890,
     5,4,2,9.0,1,95.0,1,79.5,0,1,true,true,'watch','Hyderabad zone; mild overspeeding on Outer Ring Road'),
    ('Vikram Singh','north','2026-06',3600,
     18,14,15,26.0,6,68.0,9,41.0,1,4,true,false,'high_risk','Gurgaon; one minor collision, heavy phone use flagged'),
    ('Mohammed Irfan','west','2026-06',2760,
     6,5,3,8.5,1,92.0,2,76.0,0,1,true,true,'watch','Mumbai metro; congestion-related braking events'),
    ('Karthik Nair','south','2026-06',2200,
     2,1,0,4.0,0,100.0,0,91.0,0,0,true,true,'safe','Bengaluru; exemplary driving record'),
    ('Deepak Verma','central','2026-06',3050,
     22,17,19,30.0,8,55.0,12,33.0,2,6,false,false,'suspend_review','Bhopal-Indore; expired license, two accidents — suspend pending review'),
    ('Sanjay Patel','west','2026-06',2980,
     8,7,6,14.0,2,88.0,3,66.5,0,2,true,false,'coaching_needed','Ahmedabad; night driving high, coaching scheduled'),
    ('Ramesh Iyer','south','2026-05',2650,
     4,3,1,7.0,0,97.0,1,84.0,0,0,true,true,'safe','Chennai; consistent safe scores'),
    ('Ajay Malhotra','north','2026-05',3300,
     15,11,12,22.0,5,74.0,6,48.0,0,3,true,false,'high_risk','Delhi; sustained aggressive driving pattern'),
    ('Prakash Rao','east','2026-06',2540,
     7,6,4,11.0,2,90.0,2,72.0,0,1,true,true,'watch','Kolkata; monsoon braking events elevated'),
    ('Naveen Menon','south','2026-05',2410,
     3,2,1,5.5,0,98.0,0,87.0,0,0,true,true,'safe','Kochi; clean quarter'),
    ('Harish Gupta','central','2026-05',3150,
     19,15,16,28.0,7,60.0,10,38.0,1,5,true,false,'high_risk','Nagpur; one accident, defensive training overdue'),
    ('Farhan Khan','west','2026-06',2870,
     9,8,5,13.0,3,85.0,4,63.0,0,2,true,false,'coaching_needed','Pune; fatigue alerts trending up')
  ) as q(eng, region, pm, km, hb, ha, os, ndh, fa, sb, mu, ss, acc, nm, lic, dtc, sv, nt);

  -- CAPA seed — attach to specific records via engineer_name + period_month
  insert into public.engineer_driving_behavior_capa_actions_r3420 (
    driving_log_id, finding_category, root_cause, corrective_action,
    capa_status, escalation_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ei, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('Vikram Singh','2026-06','accident','phone_distraction','defensive_driving_training','in_progress','hr_disciplinary','2026-07-15',null,25000.00,'Minor collision plus phone use — mandatory retraining and HR note'),
    ('Deepak Verma','2026-06','license_expired','pending_investigation','suspend_from_driving','escalated','license_action_review','2026-07-05',null,0.00,'Expired license and two accidents — suspended from field driving pending review'),
    ('Anil Sharma','2026-06','overspeeding','aggressive_driving_habit','coaching_session','open','written_warning','2026-07-20',null,3000.00,'Repeated harsh events — coaching and written warning issued'),
    ('Ajay Malhotra','2026-05','harsh_braking','route_time_pressure','route_rescheduling','verification_pending','internal_only','2026-06-30',null,5000.00,'Route load rebalanced — verify next-cycle telematics'),
    ('Harish Gupta','2026-05','defensive_training_overdue','inadequate_training','defensive_driving_training','closed','internal_only','2026-06-15','2026-06-12',8000.00,'Completed OEM defensive driving course — scores improving'),
    ('Sanjay Patel','2026-06','fatigue_driving','insufficient_rest','fatigue_management_counseling','open','internal_only','2026-07-18',null,4500.00,'High night-driving hours — fatigue counseling and schedule review'),
    ('Farhan Khan','2026-06','fatigue_driving','scheduling_overload','route_rescheduling','overdue','internal_only','2026-07-10',null,4500.00,'Fatigue alerts up — reschedule overdue, vendor delay')
  ) as q(eng, pm, fc, rc, ca, cst, ei, tcd, acd, cost, nt)
  join public.engineer_driving_behavior_r3420 e
    on e.organization_id = v_org_id and e.engineer_name = q.eng and e.period_month = q.pm;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Safety verdict distribution
create or replace function public.founder_r3420_safety_verdict_rollup()
returns table(safety_verdict text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_driving_behavior_r3420)
  select l.safety_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_driving_behavior_r3420 l
  group by l.safety_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3420_safety_verdict_rollup() from public, anon;
grant execute on function public.founder_r3420_safety_verdict_rollup() to authenticated;

-- 2) Engineer-level safety scorecard
create or replace function public.founder_r3420_engineer_scorecard()
returns table(
  engineer_name text,
  periods bigint,
  total_km bigint,
  harsh_braking bigint,
  harsh_accel bigint,
  overspeeding bigint,
  fatigue_alerts bigint,
  mobile_use bigint,
  accidents bigint,
  near_misses bigint,
  avg_safety_score numeric,
  avg_seatbelt_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    coalesce(sum(l.km_driven),0)::bigint,
    coalesce(sum(l.harsh_braking_events),0)::bigint,
    coalesce(sum(l.harsh_acceleration_events),0)::bigint,
    coalesce(sum(l.overspeeding_events),0)::bigint,
    coalesce(sum(l.fatigue_alert_count),0)::bigint,
    coalesce(sum(l.mobile_use_while_driving_events),0)::bigint,
    coalesce(sum(l.accidents),0)::bigint,
    coalesce(sum(l.near_misses),0)::bigint,
    round(avg(l.safety_score), 1),
    round(avg(l.seatbelt_compliance_pct), 1)
  from public.engineer_driving_behavior_r3420 l
  group by l.engineer_name
  order by round(avg(l.safety_score), 1) asc nulls last;
end;
$$;

revoke execute on function public.founder_r3420_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3420_engineer_scorecard() to authenticated;

-- 3) Region × period matrix
create or replace function public.founder_r3420_region_period_matrix()
returns table(region text, period_month text, records bigint, avg_safety_score numeric, accidents bigint, near_misses bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region, l.period_month, count(*)::bigint,
    round(avg(l.safety_score), 1),
    coalesce(sum(l.accidents),0)::bigint,
    coalesce(sum(l.near_misses),0)::bigint
  from public.engineer_driving_behavior_r3420 l
  group by l.region, l.period_month
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3420_region_period_matrix() from public, anon;
grant execute on function public.founder_r3420_region_period_matrix() to authenticated;

-- 4) Period trend
create or replace function public.founder_r3420_period_trend()
returns table(period_month text, records bigint, total_km bigint, accidents bigint, near_misses bigint, avg_safety_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.km_driven),0)::bigint,
    coalesce(sum(l.accidents),0)::bigint,
    coalesce(sum(l.near_misses),0)::bigint,
    round(avg(l.safety_score), 1)
  from public.engineer_driving_behavior_r3420 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3420_period_trend() from public, anon;
grant execute on function public.founder_r3420_period_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3420_capa_status_board()
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
  from public.engineer_driving_behavior_capa_actions_r3420 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3420_capa_status_board() from public, anon;
grant execute on function public.founder_r3420_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3420_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_driving_behavior_capa_actions_r3420)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_driving_behavior_capa_actions_r3420 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3420_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3420_root_cause_pareto() to authenticated;

-- 7) Escalation-impact digest
create or replace function public.founder_r3420_escalation_impact_digest()
returns table(escalation_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.escalation_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.engineer_driving_behavior_capa_actions_r3420 c
  group by c.escalation_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3420_escalation_impact_digest() from public, anon;
grant execute on function public.founder_r3420_escalation_impact_digest() to authenticated;

-- 8) High-risk driving queue (top individual concerns)
create or replace function public.founder_r3420_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  period_month text,
  safety_score numeric,
  safety_verdict text,
  accidents integer,
  near_misses integer,
  overspeeding_events integer,
  fatigue_alert_count integer,
  mobile_use_while_driving_events integer,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.period_month, l.safety_score, l.safety_verdict,
    l.accidents, l.near_misses, l.overspeeding_events, l.fatigue_alert_count, l.mobile_use_while_driving_events, l.notes
  from public.engineer_driving_behavior_r3420 l
  where l.safety_verdict in ('coaching_needed','high_risk','suspend_review')
     or l.accidents > 0
     or l.near_misses > 0
     or l.license_valid = false
     or l.defensive_training_current = false
     or l.safety_score < 70
  order by l.safety_score asc nulls first, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3420_high_risk_queue() from public, anon;
grant execute on function public.founder_r3420_high_risk_queue() to authenticated;
