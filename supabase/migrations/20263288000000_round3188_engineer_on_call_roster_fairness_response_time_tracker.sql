-- Round 3188: Engineer On-Call Roster Fairness & Response-Time Compliance Tracker
-- On-call week log — engineer × tier × shift pattern × response SLA × weekend share × fairness index × comp-off × CAPA

-- =============================================================================
-- TABLE 1: on_call_roster_r3188 — engineer on-call weeks
-- =============================================================================
create table if not exists public.on_call_roster_r3188 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  engineer_code text not null,
  roster_ref text not null,
  on_call_tier text not null check (on_call_tier in (
    'primary_first_responder','secondary_backup','escalation_l3','remote_telephonic_only'
  )),
  shift_pattern text not null check (shift_pattern in (
    'weekday_night','weekend_day','weekend_night','full_week_24x7',
    'public_holiday','split_shift_rotation'
  )),
  week_start_date date not null,
  on_call_hours numeric(5,1) not null,
  calls_received int not null,
  calls_attended int,
  avg_response_minutes numeric(5,1),
  worst_response_minutes int,
  sla_met_pct numeric(5,1),
  weekend_share_pct numeric(5,1),
  fairness_index numeric(4,2),
  comp_off_days_due numeric(3,1),
  comp_off_status text not null check (comp_off_status in (
    'not_due','accrued','scheduled','availed','lapsed','encashed'
  )),
  roster_status text not null check (roster_status in (
    'compliant','response_sla_breach','overloaded','underutilized',
    'fairness_violation','pending_review','swap_requested'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.on_call_roster_r3188 enable row level security;

create index if not exists idx_on_call_roster_r3188_org on public.on_call_roster_r3188(organization_id);
create index if not exists idx_on_call_roster_r3188_week on public.on_call_roster_r3188(week_start_date);
create index if not exists idx_on_call_roster_r3188_status on public.on_call_roster_r3188(roster_status);

-- =============================================================================
-- TABLE 2: on_call_roster_capa_actions_r3188 — CAPA & fairness actions
-- =============================================================================
create table if not exists public.on_call_roster_capa_actions_r3188 (
  id uuid primary key default gen_random_uuid(),
  roster_id uuid not null references public.on_call_roster_r3188(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sla_response_breach','excessive_weekend_load','fairness_index_violation',
    'comp_off_backlog','missed_call','roster_swap_unapproved','burnout_risk','coverage_gap'
  )),
  root_cause text not null check (root_cause in (
    'understaffed_region','skill_concentration','leave_clash',
    'notification_system_delay','engineer_fatigue','uneven_roster_algorithm',
    'travel_distance_far','pending_investigation','new_engineer_ramp'
  )),
  corrective_action text not null check (corrective_action in (
    'hire_additional_engineer','rebalance_roster_next_cycle','grant_comp_off',
    'escalation_matrix_update','pager_system_upgrade','mandatory_rest_period',
    'cross_train_backup','swap_approved_retro','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'labour_law_exposure','contract_sla_penalty','none','internal_only',
    'client_escalation_risk','safety_incident_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.on_call_roster_capa_actions_r3188 enable row level security;

create index if not exists idx_on_call_capa_r3188_roster on public.on_call_roster_capa_actions_r3188(roster_id);
create index if not exists idx_on_call_capa_r3188_status on public.on_call_roster_capa_actions_r3188(capa_status);

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

  -- 13 on-call roster weeks
  insert into public.on_call_roster_r3188 (
    organization_id, hospital_name, engineer_name, engineer_code, roster_ref,
    on_call_tier, shift_pattern, week_start_date,
    on_call_hours, calls_received, calls_attended,
    avg_response_minutes, worst_response_minutes, sla_met_pct, weekend_share_pct,
    fairness_index, comp_off_days_due, comp_off_status, roster_status, notes
  )
  select v_org_id, q.hosp, q.eng, q.ecode, q.rref,
    q.tier, q.sp, q.ws::date,
    q.hrs, q.cr, q.ca,
    q.arm, q.wrm, q.sla, q.wsp,
    q.fi, q.cod, q.cos, q.rs, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ravi Kumar','ENG-HYD-01','OCR-001','primary_first_responder','full_week_24x7','2026-07-06',
     168.0,14,14,18.5,42,92.9,28.6,1.35,2.0,'accrued','overloaded','168h continuous week — rotation overdue'),
    ('Apollo Hyderabad Jubilee Hills','Sneha Reddy','ENG-HYD-02','OCR-002','secondary_backup','weekday_night','2026-07-06',
     60.0,5,5,22.0,35,100.0,0.0,0.71,0.5,'not_due','underutilized','Backup rarely paged — candidate for primary next cycle'),
    ('Fortis Bannerghatta Bengaluru','Arjun Nair','ENG-BLR-03','OCR-003','primary_first_responder','weekend_day','2026-07-06',
     48.0,11,10,34.2,95,72.7,100.0,1.20,1.5,'scheduled','response_sla_breach','Two responses beyond 30-min SLA — traffic on Bannerghatta Rd'),
    ('Fortis Bannerghatta Bengaluru','Meera Iyer','ENG-BLR-04','OCR-004','escalation_l3','split_shift_rotation','2026-07-06',
     36.0,3,3,15.0,25,100.0,33.3,0.85,0.0,'not_due','compliant','L3 escalations resolved within SLA'),
    ('Manipal Whitefield Bengaluru','Vikram Shetty','ENG-BLR-05','OCR-005','primary_first_responder','weekend_night','2026-07-06',
     24.0,7,6,41.0,120,57.1,100.0,1.48,1.0,'accrued','fairness_violation','Third consecutive weekend night for same engineer'),
    ('Manipal Whitefield Bengaluru','Divya Menon','ENG-BLR-06','OCR-006','secondary_backup','weekday_night','2026-06-29',
     50.0,6,6,19.5,28,100.0,0.0,0.90,0.0,'not_due','compliant','Clean week — all pages answered within 30 min'),
    ('AIIMS New Delhi Ansari Nagar','Rahul Verma','ENG-DEL-07','OCR-007','primary_first_responder','full_week_24x7','2026-06-29',
     168.0,19,17,26.0,75,84.2,25.0,1.42,2.5,'accrued','overloaded','Highest call volume in network — split roster proposed'),
    ('AIIMS New Delhi Ansari Nagar','Priya Sharma','ENG-DEL-08','OCR-008','remote_telephonic_only','public_holiday','2026-06-29',
     12.0,4,4,8.0,14,100.0,0.0,0.60,0.5,'availed','compliant','Holiday telephonic triage only'),
    ('KIMS Secunderabad','Suresh Babu','ENG-HYD-09','OCR-009','primary_first_responder','weekend_day','2026-06-29',
     48.0,9,8,38.5,88,66.7,100.0,1.25,1.5,'lapsed','response_sla_breach','Comp-off lapsed unclaimed — morale risk flagged'),
    ('Care Hospitals Banjara Hills','Anita Desai','ENG-HYD-10','OCR-010','secondary_backup','split_shift_rotation','2026-06-22',
     40.0,5,5,21.0,30,100.0,20.0,0.95,0.0,'not_due','compliant','Split shift covering dialysis and ICU units'),
    ('Yashoda Somajiguda Hyderabad','Karthik Rao','ENG-HYD-11','OCR-011','primary_first_responder','weekday_night','2026-06-22',
     55.0,8,7,29.0,65,87.5,0.0,1.05,1.0,'scheduled','swap_requested','Swap requested for next week — family function'),
    ('St John''s Bengaluru','Farhan Ali','ENG-BLR-12','OCR-012','escalation_l3','weekend_night','2026-06-22',
     24.0,2,2,12.5,18,100.0,100.0,0.80,1.0,'accrued','compliant','Quiet weekend — both ventilator pages resolved remotely'),
    ('Rainbow Children''s Hyderabad','Lakshmi Priya','ENG-HYD-13','OCR-013','primary_first_responder','public_holiday','2026-06-22',
     12.0,6,5,33.0,70,66.7,0.0,1.10,0.5,'accrued','pending_review','Holiday NICU incubator call missed once — review open')
  ) as q(hosp, eng, ecode, rref, tier, sp, ws, hrs, cr, ca, arm, wrm, sla, wsp, fi, cod, cos, rs, nt);

  -- CAPA seed — attach to specific roster weeks
  insert into public.on_call_roster_capa_actions_r3188 (
    roster_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('OCR-001','burnout_risk','understaffed_region','hire_additional_engineer','2026-08-15',null,'in_progress','labour_law_exposure',95000.00,'Hyderabad region one primary short — JD released'),
    ('OCR-003','sla_response_breach','travel_distance_far','escalation_matrix_update','2026-07-20',null,'open','contract_sla_penalty',5000.00,'Add nearer backup for Bannerghatta corridor'),
    ('OCR-005','fairness_index_violation','uneven_roster_algorithm','rebalance_roster_next_cycle','2026-07-13','2026-07-12','closed','internal_only',0.00,'Roster generator weekend-weight fixed and re-run'),
    ('OCR-007','excessive_weekend_load','skill_concentration','cross_train_backup','2026-07-25',null,'verification_pending','client_escalation_risk',30000.00,'Backup engineer shadowing ventilator calls at AIIMS'),
    ('OCR-009','comp_off_backlog','leave_clash','grant_comp_off','2026-07-10',null,'overdue','labour_law_exposure',8000.00,'Two lapsed comp-offs to be reinstated with payroll'),
    ('OCR-013','missed_call','notification_system_delay','pager_system_upgrade','2026-07-30',null,'escalated','safety_incident_risk',65000.00,'NICU page delayed 25 min — pager vendor RCA demanded')
  ) as q(rref, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.on_call_roster_r3188 e
    on e.organization_id = v_org_id and e.roster_ref = q.rref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Roster status distribution
create or replace function public.founder_r3188_roster_status_rollup()
returns table(roster_status text, weeks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.on_call_roster_r3188)
  select l.roster_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.on_call_roster_r3188 l
  group by l.roster_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3188_roster_status_rollup() from public, anon;
grant execute on function public.founder_r3188_roster_status_rollup() to authenticated;

-- 2) Engineer fairness scorecard
create or replace function public.founder_r3188_engineer_scorecard()
returns table(
  engineer_name text,
  hospital_name text,
  weeks bigint,
  total_hours numeric,
  total_calls bigint,
  avg_response_min numeric,
  avg_sla_met_pct numeric,
  avg_fairness_index numeric,
  comp_off_due numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    l.hospital_name,
    count(*)::bigint,
    coalesce(sum(l.on_call_hours),0)::numeric,
    coalesce(sum(l.calls_received),0)::bigint,
    round(avg(l.avg_response_minutes), 1),
    round(avg(l.sla_met_pct), 1),
    round(avg(l.fairness_index), 2),
    coalesce(sum(l.comp_off_days_due),0)::numeric
  from public.on_call_roster_r3188 l
  group by l.engineer_name, l.hospital_name
  order by sum(l.on_call_hours) desc;
end;
$$;

revoke execute on function public.founder_r3188_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3188_engineer_scorecard() to authenticated;

-- 3) Tier × shift-pattern breakdown
create or replace function public.founder_r3188_tier_shift_matrix()
returns table(on_call_tier text, shift_pattern text, weeks bigint, avg_hours numeric, avg_response_min numeric, avg_sla_met_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.on_call_tier, l.shift_pattern, count(*)::bigint,
    round(avg(l.on_call_hours), 1),
    round(avg(l.avg_response_minutes), 1),
    round(avg(l.sla_met_pct), 1)
  from public.on_call_roster_r3188 l
  group by l.on_call_tier, l.shift_pattern
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3188_tier_shift_matrix() from public, anon;
grant execute on function public.founder_r3188_tier_shift_matrix() to authenticated;

-- 4) Weekly response-time trend
create or replace function public.founder_r3188_weekly_trend()
returns table(week_start_date date, engineers_on_call bigint, total_calls bigint, avg_response_min numeric, avg_sla_met_pct numeric, breaches bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.week_start_date,
    count(*)::bigint,
    coalesce(sum(l.calls_received),0)::bigint,
    round(avg(l.avg_response_minutes), 1),
    round(avg(l.sla_met_pct), 1),
    count(*) filter (where l.roster_status = 'response_sla_breach')::bigint
  from public.on_call_roster_r3188 l
  group by l.week_start_date
  order by l.week_start_date desc;
end;
$$;

revoke execute on function public.founder_r3188_weekly_trend() from public, anon;
grant execute on function public.founder_r3188_weekly_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3188_capa_status_board()
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
  from public.on_call_roster_capa_actions_r3188 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3188_capa_status_board() from public, anon;
grant execute on function public.founder_r3188_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3188_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.on_call_roster_capa_actions_r3188)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.on_call_roster_capa_actions_r3188 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3188_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3188_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3188_regulatory_impact_digest()
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
  from public.on_call_roster_capa_actions_r3188 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3188_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3188_regulatory_impact_digest() to authenticated;

-- 8) High-risk roster queue (top individual concerns)
create or replace function public.founder_r3188_high_risk_roster_queue()
returns table(
  engineer_name text,
  hospital_name text,
  week_start_date date,
  roster_status text,
  avg_response_minutes numeric,
  sla_met_pct numeric,
  fairness_index numeric,
  comp_off_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.week_start_date,
    l.roster_status, l.avg_response_minutes, l.sla_met_pct, l.fairness_index, l.comp_off_status, l.notes
  from public.on_call_roster_r3188 l
  where l.roster_status in ('response_sla_breach','overloaded','fairness_violation','pending_review','swap_requested')
     or l.fairness_index > 1.30
     or l.sla_met_pct < 80.0
     or l.comp_off_status = 'lapsed'
  order by l.week_start_date desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3188_high_risk_roster_queue() from public, anon;
grant execute on function public.founder_r3188_high_risk_roster_queue() to authenticated;
