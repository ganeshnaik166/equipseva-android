-- Round 3697: Founder Meeting-Room / Workspace Utilization Board
-- Facilities ops — room × site × period × bookings × hours booked/used × utilization × no-shows × overruns × AV faults × occupancy ratio × CAPA

-- =============================================================================
-- TABLE 1: meeting_room_r3697 — per-room monthly workspace utilization facts
-- =============================================================================
create table if not exists public.meeting_room_r3697 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  room_code text not null,
  room_name text not null,
  site_name text not null,
  period_month date not null,
  capacity_seats int not null,
  bookings int not null,
  hours_booked numeric(7,1),
  hours_used numeric(7,1),
  utilization_pct numeric(5,1),
  no_shows int not null,
  no_show_pct numeric(5,1),
  overruns int not null,
  av_equipment_faults int not null,
  avg_occupancy_ratio numeric(4,2),
  room_class text not null check (room_class in (
    'board_room','meeting_room','huddle_space','training_room','demo_lab'
  )),
  utilization_status text not null check (utilization_status in (
    'optimal','under_used','over_subscribed','no_show_heavy','equipment_issues'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.meeting_room_r3697 enable row level security;

create index if not exists idx_meeting_room_r3697_org on public.meeting_room_r3697(organization_id);
create index if not exists idx_meeting_room_r3697_month on public.meeting_room_r3697(period_month);
create index if not exists idx_meeting_room_r3697_status on public.meeting_room_r3697(utilization_status);

-- =============================================================================
-- TABLE 2: meeting_room_capa_actions_r3697 — CAPA & workspace-discipline actions
-- =============================================================================
create table if not exists public.meeting_room_capa_actions_r3697 (
  id uuid primary key default gen_random_uuid(),
  room_log_id uuid not null references public.meeting_room_r3697(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'chronic_no_shows','ghost_recurring_bookings','av_equipment_failure',
    'oversized_room_allocation','chronic_under_booking','overrun_conflicts',
    'sensor_data_gap','over_subscription'
  )),
  root_cause text not null check (root_cause in (
    'no_auto_release_policy','stale_recurring_invites','projector_vc_hardware_fault',
    'room_capacity_mismatch','poor_booking_etiquette','occupancy_sensor_sync_gap',
    'peak_hour_demand_spike','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'enable_auto_release','purge_recurring_bookings','repair_av_equipment',
    'reclassify_room_capacity','run_etiquette_campaign','fix_sensor_calendar_sync',
    'add_overflow_huddle_capacity','rebalance_room_mix','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_hours_lost numeric(7,1),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.meeting_room_capa_actions_r3697 enable row level security;

create index if not exists idx_meeting_room_capa_r3697_log on public.meeting_room_capa_actions_r3697(room_log_id);
create index if not exists idx_meeting_room_capa_r3697_status on public.meeting_room_capa_actions_r3697(capa_status);

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

  -- 16 room-month utilization rows
  insert into public.meeting_room_r3697 (
    organization_id, room_code, room_name, site_name, period_month,
    capacity_seats, bookings, hours_booked, hours_used, utilization_pct,
    no_shows, no_show_pct, overruns, av_equipment_faults, avg_occupancy_ratio,
    room_class, utilization_status, trend_dir, notes
  )
  select v_org_id, q.rcode, q.rname, q.site, q.pm::date,
    q.cap, q.bkg, q.hb, q.hu, q.util,
    q.ns, q.nsp, q.ovr, q.avf, q.occ,
    q.rcls, q.ust, q.trd, q.nt
  from (values
    ('MR-MUM-BR1','Boardroom Everest','Mumbai HQ','2026-07-01',
     18,42,96.5,88.0,91.2,2,4.8,3,0,0.62,'board_room','optimal','stable','Exec boardroom — booked well in advance, occupancy healthy'),
    ('MR-MUM-TR1','Training Hall Sahyadri','Mumbai HQ','2026-07-01',
     40,18,72.0,39.5,54.9,5,27.8,1,1,0.41,'training_room','no_show_heavy','worsening','Recurring training slots ghosted — auto-release not yet enabled'),
    ('MR-MUM-HS1','Huddle Konkan','Mumbai HQ','2026-07-01',
     4,96,88.0,83.5,94.9,3,3.1,11,0,0.88,'huddle_space','over_subscribed','worsening','Walk-in queue at peak hours — overruns bumping next bookings'),
    ('MR-MUM-DL1','Demo Lab Ganga','Mumbai HQ','2026-06-01',
     12,22,64.0,58.0,66.1,1,4.5,2,3,0.55,'demo_lab','equipment_issues','worsening','4K display flicker and VC codec drops during customer demos'),
    ('MR-MUM-MR2','Meeting Room Tapti','Mumbai HQ','2026-06-01',
     8,51,78.5,71.0,82.4,4,7.8,4,0,0.58,'meeting_room','optimal','improving','Auto-release pilot cut ghost meetings by half'),
    ('MR-CHN-BR1','Boardroom Marina','Chennai Office','2026-07-01',
     14,26,61.0,44.0,60.1,6,23.1,2,0,0.37,'board_room','no_show_heavy','stable','Weekly leadership sync often skipped without releasing the slot'),
    ('MR-CHN-MR1','Meeting Room Kaveri','Chennai Office','2026-07-01',
     10,58,92.0,86.5,89.4,2,3.4,5,0,0.66,'meeting_room','optimal','stable','Healthy mix of service-ops and sales reviews'),
    ('MR-CHN-HS1','Huddle Coromandel','Chennai Office','2026-06-01',
     5,34,40.0,21.5,42.1,1,2.9,0,0,0.35,'huddle_space','under_used','stable','New floor huddle — signage added to lift discovery'),
    ('MR-CHN-TR1','Training Room Pallava','Chennai Office','2026-05-01',
     25,12,54.0,47.0,68.3,1,8.3,1,2,0.52,'training_room','equipment_issues','improving','Projector lamp replaced — mic array RMA in transit'),
    ('MR-DEL-BR1','Boardroom Aravalli','Delhi Office','2026-07-01',
     16,31,74.5,69.0,84.7,1,3.2,2,0,0.59,'board_room','optimal','improving','Customer MSA negotiations booked well in advance'),
    ('MR-DEL-MR1','Meeting Room Yamuna','Delhi Office','2026-06-01',
     8,44,70.0,48.5,63.4,9,20.5,3,0,0.44,'meeting_room','no_show_heavy','worsening','Field-team recurring standups ghosted during tour weeks'),
    ('MR-DEL-HS1','Huddle Ridge','Delhi Office','2026-06-01',
     4,71,66.5,61.0,87.1,2,2.8,8,0,0.79,'huddle_space','over_subscribed','stable','Only huddle on the floor — second pod proposed in CAPA'),
    ('MR-DEL-DL1','Demo Lab Indus','Delhi Office','2026-05-01',
     10,9,31.0,26.0,51.6,1,11.1,0,1,0.48,'demo_lab','under_used','stable','Demo traffic seasonal — evaluating shared calendar with sales'),
    ('MR-BLR-MR1','Meeting Room Vrishabha','Bengaluru R&D','2026-05-01',
     12,39,82.0,75.5,86.9,2,5.1,6,0,0.63,'meeting_room','optimal','stable','Sprint ceremonies dominate — utilization consistent'),
    ('MR-BLR-TR1','Training Room Nandi','Bengaluru R&D','2026-04-01',
     30,15,60.0,33.0,52.4,6,40.0,1,0,0.30,'training_room','no_show_heavy','improving','Onboarding batches no-showed before auto-release rollout'),
    ('MR-BLR-DL1','Demo Lab Hebbal','Bengaluru R&D','2026-04-01',
     8,20,55.0,49.5,74.4,1,5.0,2,4,0.61,'demo_lab','equipment_issues','stable','Test-bench power trips during load demos — UPS sizing under review')
  ) as q(rcode, rname, site, pm, cap, bkg, hb, hu, util, ns, nsp, ovr, avf, occ, rcls, ust, trd, nt);

  -- CAPA seed — attach to specific rooms via room_code
  insert into public.meeting_room_capa_actions_r3697 (
    room_log_id, finding_category, root_cause, corrective_action,
    capa_status, estimated_hours_lost, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ehl, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('MR-MUM-TR1','chronic_no_shows','no_auto_release_policy','enable_auto_release','in_progress',32.5,'Facilities Manager Mumbai','2026-08-20',null,'15-minute auto-release going live for training hall bookings'),
    ('MR-MUM-HS1','over_subscription','peak_hour_demand_spike','add_overflow_huddle_capacity','open',18.0,'Workplace Ops Lead','2026-09-05',null,'Two phone-booth pods quoted for seventh-floor overflow'),
    ('MR-MUM-DL1','av_equipment_failure','projector_vc_hardware_fault','repair_av_equipment','escalated',26.0,'IT AV Engineer','2026-08-12',null,'Codec RMA delayed — customer demos rerouted to Meeting Room Tapti'),
    ('MR-CHN-BR1','ghost_recurring_bookings','stale_recurring_invites','purge_recurring_bookings','verification_pending',21.5,'Facilities Manager Chennai','2026-08-15',null,'Cleared 11 stale weekly invites — monitoring next two cycles'),
    ('MR-CHN-TR1','av_equipment_failure','projector_vc_hardware_fault','repair_av_equipment','closed',12.0,'IT AV Engineer','2026-07-30','2026-07-24','Lamp and mic array replaced — training room QC passed'),
    ('MR-DEL-MR1','chronic_no_shows','poor_booking_etiquette','run_etiquette_campaign','open',24.0,'Delhi Office Admin','2026-08-25',null,'No-show scorecards to team leads plus release nudges in booking app'),
    ('MR-DEL-HS1','over_subscription','room_capacity_mismatch','rebalance_room_mix','in_progress',15.5,'Workplace Ops Lead','2026-09-10',null,'Converting store room into second huddle pod — fit-out started'),
    ('MR-CHN-HS1','sensor_data_gap','occupancy_sensor_sync_gap','fix_sensor_calendar_sync','overdue',8.0,'Workplace Ops Lead','2026-07-28',null,'Occupancy sensor offline since June — utilization understated'),
    ('MR-BLR-DL1','av_equipment_failure','pending_investigation','none_required','open',10.0,'Bengaluru Site Lead','2026-08-18',null,'Power-trip root cause under electrical audit before AV repair scoped')
  ) as q(rcode, fc, rc, ca, cst, ehl, ownr, tcd, acd, nt)
  join public.meeting_room_r3697 e
    on e.organization_id = v_org_id and e.room_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Utilization-status distribution
create or replace function public.founder_r3697_utilization_status_rollup()
returns table(utilization_status text, rooms bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.meeting_room_r3697)
  select l.utilization_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.meeting_room_r3697 l
  group by l.utilization_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3697_utilization_status_rollup() from public, anon;
grant execute on function public.founder_r3697_utilization_status_rollup() to authenticated;

-- 2) Site-level workspace scorecard
create or replace function public.founder_r3697_site_scorecard()
returns table(
  site_name text,
  rooms bigint,
  total_bookings bigint,
  avg_utilization_pct numeric,
  total_no_shows bigint,
  avg_no_show_pct numeric,
  av_faults bigint,
  optimal_rooms bigint,
  at_risk_rooms bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    coalesce(sum(l.bookings),0)::bigint,
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.no_shows),0)::bigint,
    round(avg(l.no_show_pct), 1),
    coalesce(sum(l.av_equipment_faults),0)::bigint,
    count(*) filter (where l.utilization_status = 'optimal')::bigint,
    count(*) filter (where l.utilization_status in ('no_show_heavy','equipment_issues','over_subscribed'))::bigint
  from public.meeting_room_r3697 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3697_site_scorecard() from public, anon;
grant execute on function public.founder_r3697_site_scorecard() to authenticated;

-- 3) Room-class × utilization-status matrix
create or replace function public.founder_r3697_room_class_status_matrix()
returns table(room_class text, utilization_status text, rooms bigint, avg_utilization_pct numeric, total_no_shows bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.room_class, l.utilization_status, count(*)::bigint,
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.no_shows),0)::bigint
  from public.meeting_room_r3697 l
  group by l.room_class, l.utilization_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3697_room_class_status_matrix() from public, anon;
grant execute on function public.founder_r3697_room_class_status_matrix() to authenticated;

-- 4) Monthly utilization trend
create or replace function public.founder_r3697_monthly_utilization_trend()
returns table(
  period_month date,
  rooms bigint,
  total_bookings bigint,
  total_hours_booked numeric,
  total_hours_used numeric,
  avg_utilization_pct numeric,
  total_no_shows bigint,
  av_faults bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.bookings),0)::bigint,
    coalesce(sum(l.hours_booked),0)::numeric,
    coalesce(sum(l.hours_used),0)::numeric,
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.no_shows),0)::bigint,
    coalesce(sum(l.av_equipment_faults),0)::bigint
  from public.meeting_room_r3697 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3697_monthly_utilization_trend() from public, anon;
grant execute on function public.founder_r3697_monthly_utilization_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3697_capa_status_board()
returns table(capa_status text, findings bigint, avg_hours_lost numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_hours_lost)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.meeting_room_capa_actions_r3697 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3697_capa_status_board() from public, anon;
grant execute on function public.founder_r3697_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3697_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_hours_lost numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.meeting_room_capa_actions_r3697)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_hours_lost),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.meeting_room_capa_actions_r3697 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3697_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3697_root_cause_pareto() to authenticated;

-- 7) No-show digest by site
create or replace function public.founder_r3697_no_show_digest()
returns table(
  site_name text,
  rooms bigint,
  total_bookings bigint,
  total_no_shows bigint,
  avg_no_show_pct numeric,
  no_show_heavy_rooms bigint,
  worsening_rooms bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    coalesce(sum(l.bookings),0)::bigint,
    coalesce(sum(l.no_shows),0)::bigint,
    round(avg(l.no_show_pct), 1),
    count(*) filter (where l.utilization_status = 'no_show_heavy')::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.meeting_room_r3697 l
  group by l.site_name
  order by coalesce(sum(l.no_shows),0) desc;
end;
$$;

revoke all on function public.founder_r3697_no_show_digest() from public, anon;
grant execute on function public.founder_r3697_no_show_digest() to authenticated;

-- 8) High-risk room queue (no-show heavy / equipment issues)
create or replace function public.founder_r3697_high_risk_queue()
returns table(
  room_code text,
  room_name text,
  site_name text,
  room_class text,
  period_month date,
  utilization_status text,
  no_show_pct numeric,
  av_equipment_faults int,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.room_code, l.room_name, l.site_name, l.room_class, l.period_month,
    l.utilization_status, l.no_show_pct, l.av_equipment_faults, l.trend_dir, l.notes
  from public.meeting_room_r3697 l
  where l.utilization_status in ('no_show_heavy','equipment_issues','over_subscribed')
     or l.no_show_pct >= 20
     or l.av_equipment_faults > 0
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.site_name, l.room_code;
end;
$$;

revoke all on function public.founder_r3697_high_risk_queue() from public, anon;
grant execute on function public.founder_r3697_high_risk_queue() to authenticated;
