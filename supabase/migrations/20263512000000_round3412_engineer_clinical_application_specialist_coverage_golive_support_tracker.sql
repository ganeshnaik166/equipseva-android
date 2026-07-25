-- Round 3412: Engineer Clinical Application Specialist (CAS) Coverage & Go-Live Support Tracker
-- CAS coverage QA — specialist × hospital × region × equipment_type × engagement_type × go-live on-schedule × competency sign-off × users trained × satisfaction × coverage gap × CAPA

-- =============================================================================
-- TABLE 1: cas_coverage_golive_r3412 — per go-live / applications-support engagement
-- =============================================================================
create table if not exists public.cas_coverage_golive_r3412 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engagement_code text not null,
  specialist_name text not null,
  hospital_name text not null,
  region text not null check (region in (
    'north','south','east','west','central'
  )),
  equipment_type text not null check (equipment_type in (
    'imaging','cath_lab','lab_analyzer','patient_monitoring','dialysis','ot_equipment','anesthesia'
  )),
  engagement_type text not null check (engagement_type in (
    'installation_go_live','applications_training','protocol_optimization','refresher','escalation_support','remote_support'
  )),
  engagement_date date not null,
  planned_hours numeric(6,2),
  actual_hours numeric(6,2),
  sessions_delivered integer not null default 0,
  clinical_users_trained integer not null default 0,
  competency_signoff_obtained boolean not null,
  go_live_on_schedule boolean not null,
  customer_satisfaction integer,
  follow_up_required boolean not null,
  coverage_gap_flag boolean not null,
  engagement_verdict text not null check (engagement_verdict in (
    'successful','needs_followup','partial','delayed','escalated'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cas_coverage_golive_r3412 enable row level security;

create index if not exists idx_cas_coverage_golive_r3412_org on public.cas_coverage_golive_r3412(organization_id);
create index if not exists idx_cas_coverage_golive_r3412_date on public.cas_coverage_golive_r3412(engagement_date);
create index if not exists idx_cas_coverage_golive_r3412_verdict on public.cas_coverage_golive_r3412(engagement_verdict);

-- =============================================================================
-- TABLE 2: cas_coverage_golive_capa_actions_r3412 — coverage / training / scheduling CAPA
-- =============================================================================
create table if not exists public.cas_coverage_golive_capa_actions_r3412 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engagement_id uuid not null references public.cas_coverage_golive_r3412(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'coverage_gap','insufficient_training_hours','competency_signoff_missing','go_live_delay',
    'low_satisfaction','follow_up_overdue','specialist_availability_shortfall','protocol_optimization_pending'
  )),
  root_cause text not null check (root_cause in (
    'specialist_understaffed','scheduling_conflict','equipment_delivery_delay','user_availability_low',
    'skill_gap_specialist','travel_logistics','oem_dependency','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'add_specialist_coverage','schedule_refresher','reassign_specialist','extend_training_hours',
    'remote_support_setup','escalate_to_oem','recruit_hire_cas','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  coverage_impact text not null check (coverage_impact in (
    'service_continuity_risk','training_backlog','go_live_slip','customer_escalation','none','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cas_coverage_golive_capa_actions_r3412 enable row level security;

create index if not exists idx_cas_coverage_golive_capa_r3412_eng on public.cas_coverage_golive_capa_actions_r3412(engagement_id);
create index if not exists idx_cas_coverage_golive_capa_r3412_status on public.cas_coverage_golive_capa_actions_r3412(capa_status);

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

  -- 14 engagement rows
  insert into public.cas_coverage_golive_r3412 (
    organization_id, engagement_code, specialist_name, hospital_name, region, equipment_type, engagement_type,
    engagement_date, planned_hours, actual_hours, sessions_delivered, clinical_users_trained,
    competency_signoff_obtained, go_live_on_schedule, customer_satisfaction, follow_up_required,
    coverage_gap_flag, engagement_verdict, notes
  )
  select v_org_id, q.ecode, q.spec, q.hosp, q.region, q.etype, q.engtype,
    q.edate::date, q.ph, q.ah, q.sess, q.trained,
    q.signoff, q.onsched, q.csat, q.followup,
    q.gap, q.verdict, q.nt
  from (values
    ('CAS-APL-1001','Kavya Reddy','Apollo Chennai','south','imaging','installation_go_live','2026-07-05',
     16.0,15.5,5,22,true,true,5,false,false,'successful','New 3T MRI go-live — full applications sign-off, on schedule'),
    ('CAS-FRT-1002','Arjun Mehta','Fortis Gurgaon','north','cath_lab','installation_go_live','2026-07-04',
     20.0,24.0,6,14,true,false,4,true,false,'needs_followup','Cath lab go-live slipped a day; extra hours logged; refresher planned'),
    ('CAS-MNP-1003','Priya Nair','Manipal Bengaluru','south','lab_analyzer','applications_training','2026-07-03',
     8.0,8.0,3,18,true,true,5,false,false,'successful','Chemistry analyzer applications training completed on schedule'),
    ('CAS-AIM-1004','Rohan Iyer','AIIMS Delhi','north','patient_monitoring','installation_go_live','2026-07-02',
     12.0,12.0,4,30,false,false,3,true,true,'delayed','Central station go-live delayed; competency sign-off pending; night-shift coverage gap'),
    ('CAS-CMC-1005','Sneha Kulkarni','CMC Vellore','south','dialysis','applications_training','2026-07-02',
     10.0,9.5,4,12,true,true,4,false,false,'successful','Dialysis machine fleet applications training clean'),
    ('CAS-KIM-1006','Vikram Singh','KIMS Hyderabad','south','ot_equipment','protocol_optimization','2026-07-01',
     6.0,7.5,2,8,true,true,4,true,false,'needs_followup','OT integration protocol tuning; minor follow-up on endoscopy presets'),
    ('CAS-YSH-1007','Anjali Rao','Yashoda Hyderabad','south','anesthesia','refresher','2026-06-30',
     4.0,4.0,2,10,true,true,5,false,false,'successful','Anesthesia workstation refresher for new residents'),
    ('CAS-KKB-1008','Deepak Nambiar','Kokilaben Mumbai','west','imaging','escalation_support','2026-06-30',
     8.0,14.0,3,6,false,false,2,true,true,'escalated','CT reconstruction workflow escalation unresolved; specialist stretched thin — coverage gap'),
    ('CAS-MDT-1009','Kavya Reddy','Medanta Gurgaon','north','cath_lab','applications_training','2026-06-29',
     12.0,11.0,4,16,true,true,4,false,false,'successful','Hemodynamics applications training on schedule'),
    ('CAS-NAR-1010','Arjun Mehta','Narayana Bengaluru','south','patient_monitoring','remote_support','2026-06-28',
     3.0,3.5,2,5,true,true,4,false,false,'successful','Remote telemetry configuration support session'),
    ('CAS-TMH-1011','Priya Nair','Tata Memorial Mumbai','west','lab_analyzer','installation_go_live','2026-06-27',
     18.0,20.0,5,20,true,false,3,true,true,'partial','Immunoassay line go-live partial; second analyzer pending; weekend coverage gap'),
    ('CAS-SGP-1012','Rohan Iyer','SGPGI Lucknow','central','ot_equipment','installation_go_live','2026-06-26',
     14.0,13.0,4,15,true,true,5,false,false,'successful','Modular OT equipment go-live successful and on schedule'),
    ('CAS-AMR-1013','Sneha Kulkarni','AMRI Kolkata','east','dialysis','escalation_support','2026-06-25',
     6.0,9.0,3,4,false,false,2,true,true,'escalated','Recurring dialysis alarm training escalation; sign-off not obtained; low satisfaction'),
    ('CAS-RBY-1014','Vikram Singh','Ruby Hall Pune','west','anesthesia','protocol_optimization','2026-06-24',
     5.0,5.0,2,9,true,true,4,false,false,'successful','Anesthesia gas module protocol optimization completed')
  ) as q(ecode, spec, hosp, region, etype, engtype, edate, ph, ah, sess, trained, signoff, onsched, csat, followup, gap, verdict, nt);

  -- CAPA seed — attach to specific engagements via engagement_code
  insert into public.cas_coverage_golive_capa_actions_r3412 (
    organization_id, engagement_id, finding_category, root_cause, corrective_action,
    capa_status, coverage_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CAS-FRT-1002','go_live_delay','scheduling_conflict','schedule_refresher','in_progress','go_live_slip','2026-07-08',null,18000.00,'Cath lab go-live slipped; refresher session scheduled next week'),
    ('CAS-AIM-1004','competency_signoff_missing','user_availability_low','extend_training_hours','open','training_backlog','2026-07-09',null,12000.00,'Night-shift nurses unavailable; extra sessions to obtain sign-off'),
    ('CAS-AIM-1004','coverage_gap','specialist_understaffed','add_specialist_coverage','escalated','service_continuity_risk','2026-07-07',null,25000.00,'Night-shift monitoring coverage gap — second specialist required'),
    ('CAS-KIM-1006','protocol_optimization_pending','skill_gap_specialist','schedule_refresher','closed','internal_only','2026-07-06','2026-07-04',4000.00,'Endoscopy preset tuning completed and verified'),
    ('CAS-KKB-1008','low_satisfaction','oem_dependency','escalate_to_oem','escalated','customer_escalation','2026-07-05',null,30000.00,'CT recon workflow unresolved; OEM applications escalation raised'),
    ('CAS-TMH-1011','coverage_gap','travel_logistics','remote_support_setup','open','training_backlog','2026-07-10',null,9000.00,'Weekend coverage gap on second analyzer; remote support bridge set up'),
    ('CAS-AMR-1013','competency_signoff_missing','specialist_understaffed','recruit_hire_cas','overdue','service_continuity_risk','2026-06-30',null,40000.00,'East-region CAS shortfall; sign-off overdue — hiring in progress')
  ) as q(ecode, fc, rc, ca, cst, ci, tcd, acd, cost, nt)
  join public.cas_coverage_golive_r3412 e
    on e.organization_id = v_org_id and e.engagement_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Engagement verdict distribution
create or replace function public.founder_r3412_engagement_verdict_rollup()
returns table(engagement_verdict text, engagements bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cas_coverage_golive_r3412)
  select l.engagement_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cas_coverage_golive_r3412 l
  group by l.engagement_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3412_engagement_verdict_rollup() from public, anon;
grant execute on function public.founder_r3412_engagement_verdict_rollup() to authenticated;

-- 2) Specialist-level coverage scorecard
create or replace function public.founder_r3412_specialist_scorecard()
returns table(
  specialist_name text,
  total_engagements bigint,
  successful bigint,
  needs_followup bigint,
  delayed bigint,
  coverage_gaps bigint,
  users_trained bigint,
  avg_satisfaction numeric,
  on_schedule_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.specialist_name,
    count(*)::bigint,
    count(*) filter (where l.engagement_verdict = 'successful')::bigint,
    count(*) filter (where l.engagement_verdict = 'needs_followup')::bigint,
    count(*) filter (where l.engagement_verdict in ('delayed','escalated','partial'))::bigint,
    count(*) filter (where l.coverage_gap_flag = true)::bigint,
    coalesce(sum(l.clinical_users_trained),0)::bigint,
    round(avg(l.customer_satisfaction), 2),
    round(100.0 * count(*) filter (where l.go_live_on_schedule = true)::numeric / nullif(count(*),0), 1)
  from public.cas_coverage_golive_r3412 l
  group by l.specialist_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3412_specialist_scorecard() from public, anon;
grant execute on function public.founder_r3412_specialist_scorecard() to authenticated;

-- 3) Equipment-type × engagement-type matrix
create or replace function public.founder_r3412_equipment_engagement_matrix()
returns table(equipment_type text, engagement_type text, engagements bigint, successful bigint, delayed bigint, avg_actual_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.engagement_type, count(*)::bigint,
    count(*) filter (where l.engagement_verdict = 'successful')::bigint,
    count(*) filter (where l.engagement_verdict in ('delayed','escalated','partial'))::bigint,
    round(avg(l.actual_hours), 2)
  from public.cas_coverage_golive_r3412 l
  group by l.equipment_type, l.engagement_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3412_equipment_engagement_matrix() from public, anon;
grant execute on function public.founder_r3412_equipment_engagement_matrix() to authenticated;

-- 4) Daily engagement trend
create or replace function public.founder_r3412_daily_engagement_trend()
returns table(engagement_date date, engagements bigint, successful bigint, delayed bigint, coverage_gaps bigint, users_trained bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engagement_date,
    count(*)::bigint,
    count(*) filter (where l.engagement_verdict = 'successful')::bigint,
    count(*) filter (where l.engagement_verdict in ('delayed','escalated','partial'))::bigint,
    count(*) filter (where l.coverage_gap_flag = true)::bigint,
    coalesce(sum(l.clinical_users_trained),0)::bigint
  from public.cas_coverage_golive_r3412 l
  group by l.engagement_date
  order by l.engagement_date desc;
end;
$$;

revoke execute on function public.founder_r3412_daily_engagement_trend() from public, anon;
grant execute on function public.founder_r3412_daily_engagement_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3412_capa_status_board()
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
  from public.cas_coverage_golive_capa_actions_r3412 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3412_capa_status_board() from public, anon;
grant execute on function public.founder_r3412_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3412_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cas_coverage_golive_capa_actions_r3412)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cas_coverage_golive_capa_actions_r3412 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3412_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3412_root_cause_pareto() to authenticated;

-- 7) Coverage impact digest
create or replace function public.founder_r3412_coverage_impact_digest()
returns table(coverage_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.coverage_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.cas_coverage_golive_capa_actions_r3412 c
  group by c.coverage_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3412_coverage_impact_digest() from public, anon;
grant execute on function public.founder_r3412_coverage_impact_digest() to authenticated;

-- 8) High-risk coverage queue (top individual concerns)
create or replace function public.founder_r3412_high_risk_queue()
returns table(
  specialist_name text,
  hospital_name text,
  region text,
  equipment_type text,
  engagement_type text,
  engagement_date date,
  engagement_verdict text,
  customer_satisfaction integer,
  coverage_gap_flag boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.specialist_name, l.hospital_name, l.region, l.equipment_type, l.engagement_type,
    l.engagement_date, l.engagement_verdict, l.customer_satisfaction, l.coverage_gap_flag, l.notes
  from public.cas_coverage_golive_r3412 l
  where l.engagement_verdict in ('needs_followup','partial','delayed','escalated')
     or l.coverage_gap_flag = true
     or l.follow_up_required = true
     or l.competency_signoff_obtained = false
     or l.go_live_on_schedule = false
     or l.customer_satisfaction <= 3
  order by l.engagement_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3412_high_risk_queue() from public, anon;
grant execute on function public.founder_r3412_high_risk_queue() to authenticated;
