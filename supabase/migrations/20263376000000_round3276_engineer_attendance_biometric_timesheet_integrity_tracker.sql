-- Round 3276: Engineer Attendance — Biometric/GPS Check-in & Timesheet-Integrity Tracker
-- Field-engineer HR — region × period-month × attendance × biometric/GPS check-in × timesheet vs billable × geofence mismatch × integrity flag × CAPA

-- =============================================================================
-- TABLE 1: engineer_attendance_r3276 — per engineer-period attendance integrity
-- =============================================================================
create table if not exists public.engineer_attendance_r3276 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  period_month text not null,
  scheduled_days int not null,
  present_days int not null,
  biometric_gps_checkins int not null,
  manual_override_count int not null,
  timesheet_hours numeric(7,1) not null,
  billable_hours numeric(7,1) not null,
  billable_utilization_pct numeric(5,1),
  late_checkin_count int not null,
  missing_checkout_count int not null,
  geofence_mismatch_count int not null,
  regularization_requests int not null,
  integrity_flag text not null check (integrity_flag in (
    'clean','minor_gaps','pattern_suspicious','investigate'
  )),
  attendance_verdict text not null check (attendance_verdict in (
    'compliant','needs_review','policy_breach','escalated'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_attendance_r3276 enable row level security;

create index if not exists idx_engineer_attendance_r3276_org on public.engineer_attendance_r3276(organization_id);
create index if not exists idx_engineer_attendance_r3276_period on public.engineer_attendance_r3276(period_month);
create index if not exists idx_engineer_attendance_r3276_verdict on public.engineer_attendance_r3276(attendance_verdict);

-- =============================================================================
-- TABLE 2: engineer_attendance_capa_actions_r3276 — HR/payroll CAPA actions
-- =============================================================================
create table if not exists public.engineer_attendance_capa_actions_r3276 (
  id uuid primary key default gen_random_uuid(),
  attendance_log_id uuid not null references public.engineer_attendance_r3276(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'attendance_shortfall','excessive_manual_override','geofence_mismatch','missing_checkout',
    'late_checkin_pattern','low_billable_utilization','timesheet_falsification_suspected','regularization_backlog'
  )),
  root_cause text not null check (root_cause in (
    'biometric_device_offline','poor_gps_signal_at_site','genuine_travel_delay','process_noncompliance',
    'timesheet_padding_suspected','manager_override_abuse','field_connectivity_gap','pending_investigation','training_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'counsel_engineer','recover_payroll_overpayment','issue_written_warning','deploy_backup_biometric_device',
    'retrain_on_checkin_policy','tighten_geofence_radius','manager_review_of_overrides','initiate_disciplinary_process','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  hr_impact text not null check (hr_impact in (
    'payroll_adjustment','disciplinary_action','none','internal_only','policy_update','audit_committee_escalation'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_attendance_capa_actions_r3276 enable row level security;

create index if not exists idx_engineer_attendance_capa_r3276_log on public.engineer_attendance_capa_actions_r3276(attendance_log_id);
create index if not exists idx_engineer_attendance_capa_r3276_status on public.engineer_attendance_capa_actions_r3276(capa_status);

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

  -- 14 engineer-period attendance rows
  insert into public.engineer_attendance_r3276 (
    organization_id, engineer_name, region, period_month,
    scheduled_days, present_days, biometric_gps_checkins, manual_override_count,
    timesheet_hours, billable_hours, billable_utilization_pct,
    late_checkin_count, missing_checkout_count, geofence_mismatch_count, regularization_requests,
    integrity_flag, attendance_verdict, notes
  )
  select v_org_id, q.eng, q.reg, q.pm,
    q.sched, q.present, q.checkins, q.override,
    q.tsh, q.bh, q.util,
    q.late, q.missco, q.geo, q.reg_req,
    q.iflag, q.verdict, q.nt
  from (values
    ('Rajesh Kumar','South - Chennai','2026-06',24,24,24,0,192.0,168.0,87.5,1,0,0,0,
     'clean','compliant','Apollo Chennai coverage — all biometric verified, clean'),
    ('Anitha Reddy','South - Hyderabad','2026-06',24,23,22,1,184.0,150.0,81.5,2,1,0,1,
     'minor_gaps','needs_review','One manual override for biometric device outage day'),
    ('Vikram Nair','South - Bengaluru','2026-06',24,24,20,4,190.0,140.0,73.7,3,2,3,2,
     'pattern_suspicious','needs_review','3 geofence mismatches near non-site locations at Manipal Bengaluru'),
    ('Suresh Menon','South - Bengaluru','2026-06',24,22,14,8,186.0,96.0,51.6,5,4,6,4,
     'investigate','policy_breach','High override and low billable — checkins far from job sites'),
    ('Deepa Iyer','South - Chennai','2026-06',24,24,24,0,188.0,172.0,91.5,0,0,0,0,
     'clean','compliant','CMC Vellore rota — model attendance, all biometric verified'),
    ('Arjun Singh','North - Delhi','2026-06',22,21,20,1,176.0,150.0,85.2,1,1,1,1,
     'minor_gaps','compliant','One geofence mismatch — AIIMS Delhi parking GPS drift'),
    ('Mohit Sharma','North - Gurgaon','2026-06',22,18,10,9,180.0,80.0,44.4,6,5,7,5,
     'investigate','escalated','Timesheet 180h vs 10 biometric checkins — falsification suspected'),
    ('Kavya Pillai','South - Vellore','2026-06',24,24,23,1,190.0,165.0,86.8,1,0,0,1,
     'clean','compliant','CMC Vellore coverage — clean check-in trail'),
    ('Farhan Khan','West - Mumbai','2026-06',23,22,19,3,182.0,138.0,75.8,2,3,2,2,
     'minor_gaps','needs_review','Missing checkouts on 3 evening shifts'),
    ('Priya Desai','West - Pune','2026-06',23,23,21,2,184.0,158.0,85.9,1,1,1,1,
     'clean','compliant','Minor GPS drift once — otherwise clean'),
    ('Sandeep Rao','South - Hyderabad','2026-05',21,20,18,2,168.0,140.0,83.3,2,2,1,2,
     'minor_gaps','needs_review','KIMS Hyderabad — 2 late checkins from traffic'),
    ('Naveen Gowda','South - Bengaluru','2026-05',22,15,8,11,176.0,60.0,34.1,7,6,9,6,
     'investigate','policy_breach','Manipal route — 9 geofence mismatches, override abuse'),
    ('Ritu Verma','North - Delhi','2026-05',21,21,21,0,172.0,158.0,91.9,0,0,0,0,
     'clean','compliant','AIIMS Delhi — spotless attendance and billable'),
    ('Imran Sheikh','East - Kolkata','2026-06',22,20,12,6,176.0,100.0,56.8,4,3,5,3,
     'pattern_suspicious','policy_breach','Repeated missing checkouts and geofence issues')
  ) as q(eng, reg, pm, sched, present, checkins, override, tsh, bh, util, late, missco, geo, reg_req, iflag, verdict, nt);

  -- CAPA seed — attach to flagged records via engineer_name
  insert into public.engineer_attendance_capa_actions_r3276 (
    attendance_log_id, finding_category, root_cause, corrective_action,
    capa_status, hr_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.hi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('Suresh Menon','low_billable_utilization','manager_override_abuse','manager_review_of_overrides','in_progress','disciplinary_action','2026-07-15',null,0.00,'Override log under manager review — billable at 51.6%'),
    ('Mohit Sharma','timesheet_falsification_suspected','timesheet_padding_suspected','initiate_disciplinary_process','escalated','audit_committee_escalation','2026-07-10',null,42000.00,'180h claimed vs 10 checkins — payroll recovery pending'),
    ('Naveen Gowda','geofence_mismatch','process_noncompliance','tighten_geofence_radius','open','policy_update','2026-07-20',null,8000.00,'9 geofence mismatches — geofence radius tightened to 150m'),
    ('Imran Sheikh','missing_checkout','field_connectivity_gap','deploy_backup_biometric_device','in_progress','payroll_adjustment','2026-07-18',null,15000.00,'Kolkata East — backup biometric device deployed'),
    ('Vikram Nair','excessive_manual_override','poor_gps_signal_at_site','retrain_on_checkin_policy','closed','internal_only','2026-07-05','2026-07-03',2000.00,'Retrained — GPS drift at Bengaluru sites documented'),
    ('Farhan Khan','missing_checkout','process_noncompliance','counsel_engineer','verification_pending','none','2026-07-12',null,0.00,'Counselled on evening-shift checkout — verify next cycle'),
    ('Sandeep Rao','late_checkin_pattern','genuine_travel_delay','retrain_on_checkin_policy','overdue','internal_only','2026-06-30',null,0.00,'Late checkins due to traffic — reminder policy overdue')
  ) as q(eng, fc, rc, ca, cst, hi, tcd, acd, cost, nt)
  join public.engineer_attendance_r3276 e
    on e.organization_id = v_org_id and e.engineer_name = q.eng;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Attendance verdict distribution
create or replace function public.founder_r3276_attendance_verdict_rollup()
returns table(attendance_verdict text, engineers bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_attendance_r3276)
  select l.attendance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_attendance_r3276 l
  group by l.attendance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3276_attendance_verdict_rollup() from public, anon;
grant execute on function public.founder_r3276_attendance_verdict_rollup() to authenticated;

-- 2) Region-level attendance scorecard
create or replace function public.founder_r3276_region_scorecard()
returns table(
  region text,
  total_records bigint,
  compliant bigint,
  needs_review bigint,
  breach bigint,
  total_geofence_mismatch bigint,
  total_manual_override bigint,
  avg_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.attendance_verdict = 'compliant')::bigint,
    count(*) filter (where l.attendance_verdict = 'needs_review')::bigint,
    count(*) filter (where l.attendance_verdict in ('policy_breach','escalated'))::bigint,
    coalesce(sum(l.geofence_mismatch_count),0)::bigint,
    coalesce(sum(l.manual_override_count),0)::bigint,
    round(avg(l.billable_utilization_pct), 1)
  from public.engineer_attendance_r3276 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3276_region_scorecard() from public, anon;
grant execute on function public.founder_r3276_region_scorecard() to authenticated;

-- 3) Region × period-month matrix
create or replace function public.founder_r3276_region_period_matrix()
returns table(region text, period_month text, records bigint, compliant bigint, avg_utilization_pct numeric, total_late_checkin bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region, l.period_month, count(*)::bigint,
    count(*) filter (where l.attendance_verdict = 'compliant')::bigint,
    round(avg(l.billable_utilization_pct), 1),
    coalesce(sum(l.late_checkin_count),0)::bigint
  from public.engineer_attendance_r3276 l
  group by l.region, l.period_month
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3276_region_period_matrix() from public, anon;
grant execute on function public.founder_r3276_region_period_matrix() to authenticated;

-- 4) Period-month trend
create or replace function public.founder_r3276_period_trend()
returns table(period_month text, records bigint, compliant bigint, breach bigint, geofence_mismatch bigint, manual_override bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.attendance_verdict = 'compliant')::bigint,
    count(*) filter (where l.attendance_verdict in ('policy_breach','escalated'))::bigint,
    coalesce(sum(l.geofence_mismatch_count),0)::bigint,
    coalesce(sum(l.manual_override_count),0)::bigint
  from public.engineer_attendance_r3276 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3276_period_trend() from public, anon;
grant execute on function public.founder_r3276_period_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3276_capa_status_board()
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
  from public.engineer_attendance_capa_actions_r3276 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3276_capa_status_board() from public, anon;
grant execute on function public.founder_r3276_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3276_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_attendance_capa_actions_r3276)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_attendance_capa_actions_r3276 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3276_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3276_root_cause_pareto() to authenticated;

-- 7) HR impact digest
create or replace function public.founder_r3276_hr_impact_digest()
returns table(hr_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.hr_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.engineer_attendance_capa_actions_r3276 c
  group by c.hr_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3276_hr_impact_digest() from public, anon;
grant execute on function public.founder_r3276_hr_impact_digest() to authenticated;

-- 8) High-risk attendance queue (top individual concerns)
create or replace function public.founder_r3276_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  period_month text,
  attendance_verdict text,
  integrity_flag text,
  billable_utilization_pct numeric,
  geofence_mismatch_count int,
  manual_override_count int,
  missing_checkout_count int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.period_month,
    l.attendance_verdict, l.integrity_flag, l.billable_utilization_pct,
    l.geofence_mismatch_count, l.manual_override_count, l.missing_checkout_count, l.notes
  from public.engineer_attendance_r3276 l
  where l.attendance_verdict in ('needs_review','policy_breach','escalated')
     or l.integrity_flag in ('pattern_suspicious','investigate')
     or l.geofence_mismatch_count >= 3
     or l.manual_override_count >= 4
     or l.billable_utilization_pct < 60
  order by l.billable_utilization_pct asc, l.geofence_mismatch_count desc;
end;
$$;

revoke execute on function public.founder_r3276_high_risk_queue() from public, anon;
grant execute on function public.founder_r3276_high_risk_queue() to authenticated;
