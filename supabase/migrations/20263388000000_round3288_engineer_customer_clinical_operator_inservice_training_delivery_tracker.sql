-- Round 3288: Engineer / Ops Tracker — Clinical & Operator In-Service Training Delivery
-- Per-session training log — engineer × hospital × equipment × session type × cadre ×
-- competency assessment × pass rate × feedback × no-shows × delivery verdict × CAPA re-training

-- =============================================================================
-- TABLE 1: inservice_training_r3288 — one row per in-service training session
-- =============================================================================
create table if not exists public.inservice_training_r3288 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  session_ref text not null,
  equipment_type text not null check (equipment_type in (
    'patient_monitor','ventilator','infusion_pump','dialysis','imaging','defibrillator','anesthesia_machine'
  )),
  session_type text not null check (session_type in (
    'installation_handover','refresher','new_staff_onboarding','post_upgrade','recall_related'
  )),
  session_date date not null,
  attendees_count int not null,
  cadre text not null check (cadre in (
    'staff_nurses','icu_nurses','biomedical_techs','doctors','mixed'
  )),
  competency_assessment_done boolean not null default false,
  pass_rate_pct numeric(5,2),
  materials_provided boolean not null default false,
  followup_required boolean not null default false,
  customer_feedback_score int check (customer_feedback_score between 1 and 5),
  no_show_count int not null default 0,
  delivery_verdict text not null check (delivery_verdict in (
    'completed_effective','completed_needs_followup','partial','rescheduled','not_delivered'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.inservice_training_r3288 enable row level security;

create index if not exists idx_inservice_training_r3288_org on public.inservice_training_r3288(organization_id);
create index if not exists idx_inservice_training_r3288_date on public.inservice_training_r3288(session_date);
create index if not exists idx_inservice_training_r3288_verdict on public.inservice_training_r3288(delivery_verdict);

-- =============================================================================
-- TABLE 2: inservice_training_capa_actions_r3288 — follow-up / re-training actions
-- =============================================================================
create table if not exists public.inservice_training_capa_actions_r3288 (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.inservice_training_r3288(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'low_pass_rate','high_no_show','competency_not_assessed','materials_missing',
    'negative_feedback','staff_turnover_gap','session_not_delivered','recall_training_incomplete'
  )),
  root_cause text not null check (root_cause in (
    'scheduling_conflict','language_barrier','insufficient_hands_on_time','trainer_unavailable',
    'equipment_not_ready','staff_shortage','inadequate_materials','pending_investigation','high_staff_attrition'
  )),
  corrective_action text not null check (corrective_action in (
    'reschedule_session','conduct_refresher','translate_materials','extend_handson_time',
    'assign_backup_trainer','provide_printed_guides','competency_reassessment','escalate_to_biomed_head','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.inservice_training_capa_actions_r3288 enable row level security;

create index if not exists idx_inservice_training_capa_r3288_session on public.inservice_training_capa_actions_r3288(session_id);
create index if not exists idx_inservice_training_capa_r3288_status on public.inservice_training_capa_actions_r3288(capa_status);

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

  -- 14 training-session rows
  insert into public.inservice_training_r3288 (
    organization_id, engineer_name, hospital_name, session_ref, equipment_type, session_type,
    session_date, attendees_count, cadre, competency_assessment_done, pass_rate_pct,
    materials_provided, followup_required, customer_feedback_score, no_show_count, delivery_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.sref, q.eqt, q.stype,
    q.sdate::date, q.att, q.cadre, q.comp, q.prate,
    q.mats, q.fup, q.fb, q.noshow, q.verdict, q.nt
  from (values
    ('Ramesh Iyer','Apollo Chennai','TRN-APL-01','patient_monitor','installation_handover',
     '2026-07-02',12,'staff_nurses',true,94.0,
     true,false,5,0,'completed_effective','New Draeger monitors handover — all nurses cleared competency'),
    ('Priya Nair','Apollo Chennai','TRN-APL-02','ventilator','new_staff_onboarding',
     '2026-07-02',9,'icu_nurses',true,68.0,
     true,true,4,1,'completed_needs_followup','ICU vent onboarding — 68% pass below 80% target, refresher booked'),
    ('Arjun Menon','Fortis Gurgaon','TRN-FRT-01','infusion_pump','refresher',
     '2026-07-01',15,'staff_nurses',true,88.0,
     true,false,4,2,'completed_effective','Annual infusion-pump refresher — smooth, minor no-shows'),
    ('Suresh Reddy','Fortis Gurgaon','TRN-FRT-02','dialysis','post_upgrade',
     '2026-07-01',6,'biomedical_techs',false,null,
     true,true,3,3,'partial','Firmware-upgrade training cut short — 3 techs no-show, competency deferred'),
    ('Kavita Rao','Manipal Bengaluru','TRN-MNP-01','imaging','installation_handover',
     '2026-06-30',8,'biomedical_techs',true,91.0,
     true,false,5,0,'completed_effective','CT console handover — biomed team certified'),
    ('Anil Kumar','Manipal Bengaluru','TRN-MNP-02','defibrillator','recall_related',
     '2026-06-30',20,'mixed',true,75.0,
     true,true,3,4,'completed_needs_followup','Recall re-training on defib pads — 75% pass, 4 absent, re-brief needed'),
    ('Deepak Sharma','AIIMS Delhi','TRN-AIM-01','anesthesia_machine','installation_handover',
     '2026-06-29',10,'doctors',true,96.0,
     true,false,5,0,'completed_effective','New anaesthesia workstations — anaesthetists trained'),
    ('Fatima Sheikh','AIIMS Delhi','TRN-AIM-02','patient_monitor','new_staff_onboarding',
     '2026-06-29',0,'staff_nurses',false,null,
     false,true,null,14,'not_delivered','Session cancelled — trainer double-booked, 14 nurses awaiting reschedule'),
    ('Vikram Singh','CMC Vellore','TRN-CMC-01','ventilator','refresher',
     '2026-06-28',11,'icu_nurses',true,85.0,
     true,false,4,1,'completed_effective','Ventilator refresher — good hands-on engagement'),
    ('Meena Pillai','CMC Vellore','TRN-CMC-02','infusion_pump','new_staff_onboarding',
     '2026-06-28',7,'staff_nurses',true,72.0,
     false,true,2,2,'completed_needs_followup','Guides not printed in Tamil — feedback low, translation to be provided'),
    ('Ramesh Iyer','KIMS Hyderabad','TRN-KIM-01','dialysis','installation_handover',
     '2026-06-27',9,'biomedical_techs',true,90.0,
     true,false,5,0,'completed_effective','New dialysis units handover — techs certified'),
    ('Priya Nair','KIMS Hyderabad','TRN-KIM-02','imaging','post_upgrade',
     '2026-06-27',0,'biomedical_techs',false,null,
     true,true,null,5,'rescheduled','MRI software-upgrade session rescheduled — equipment not ready on day'),
    ('Arjun Menon','Narayana Bengaluru','TRN-NAR-01','defibrillator','refresher',
     '2026-06-26',18,'mixed',true,87.0,
     true,false,4,1,'completed_effective','Quarterly defib refresher across CCU — solid attendance'),
    ('Suresh Reddy','Medanta Gurgaon','TRN-MED-01','anesthesia_machine','post_upgrade',
     '2026-06-26',5,'doctors',true,60.0,
     true,true,3,3,'partial','Post-upgrade anaesthesia briefing — only 5 of 8 attended, 60% pass, reassessment needed')
  ) as q(eng, hosp, sref, eqt, stype, sdate, att, cadre, comp, prate, mats, fup, fb, noshow, verdict, nt);

  -- CAPA seed — attach to specific sessions via session_ref
  insert into public.inservice_training_capa_actions_r3288 (
    session_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TRN-APL-02','low_pass_rate','insufficient_hands_on_time','conduct_refresher','in_progress','nabh_finding','2026-07-09',null,8000.00,'Refresher scheduled for ICU vent cohort — pass rate below NABH training threshold'),
    ('TRN-FRT-02','high_no_show','staff_shortage','reschedule_session','open','internal_only','2026-07-08',null,5000.00,'Dialysis firmware training to be re-run with full biomed team'),
    ('TRN-MNP-02','recall_training_incomplete','scheduling_conflict','conduct_refresher','escalated','patient_safety_alert','2026-07-05',null,12000.00,'Defib recall re-training incomplete — 4 staff pending, patient-safety escalation'),
    ('TRN-AIM-02','session_not_delivered','trainer_unavailable','assign_backup_trainer','overdue','nabh_finding','2026-07-02',null,0.00,'Cancelled monitor onboarding past target — backup trainer to be assigned'),
    ('TRN-CMC-02','materials_missing','language_barrier','translate_materials','verification_pending','iso_13485_deviation','2026-07-04',null,6500.00,'Tamil-language infusion-pump guides drafted — pending biomed sign-off'),
    ('TRN-KIM-02','high_no_show','equipment_not_ready','reschedule_session','closed','internal_only','2026-07-01','2026-06-30',3000.00,'MRI upgrade session re-run after console ready — techs certified'),
    ('TRN-MED-01','low_pass_rate','insufficient_hands_on_time','competency_reassessment','open','nabh_finding','2026-07-07',null,9000.00,'Anaesthesia post-upgrade competency reassessment for 3 doctors')
  ) as q(sref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.inservice_training_r3288 e
    on e.organization_id = v_org_id and e.session_ref = q.sref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Delivery verdict distribution
create or replace function public.founder_r3288_delivery_verdict_rollup()
returns table(delivery_verdict text, sessions bigint, pct numeric)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.inservice_training_r3288)
  select l.delivery_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.inservice_training_r3288 l
  group by l.delivery_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3288_delivery_verdict_rollup() from public, anon;
grant execute on function public.founder_r3288_delivery_verdict_rollup() to authenticated;

-- 2) Hospital-level training scorecard
create or replace function public.founder_r3288_hospital_scorecard()
returns table(
  hospital_name text,
  total_sessions bigint,
  effective bigint,
  needs_followup bigint,
  not_effective bigint,
  total_attendees bigint,
  avg_pass_rate_pct numeric,
  avg_feedback numeric,
  effective_pct numeric
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.delivery_verdict = 'completed_effective')::bigint,
    count(*) filter (where l.delivery_verdict = 'completed_needs_followup')::bigint,
    count(*) filter (where l.delivery_verdict in ('partial','rescheduled','not_delivered'))::bigint,
    coalesce(sum(l.attendees_count),0)::bigint,
    round(avg(l.pass_rate_pct), 1),
    round(avg(l.customer_feedback_score), 2),
    round(100.0 * count(*) filter (where l.delivery_verdict = 'completed_effective')::numeric / nullif(count(*),0), 1)
  from public.inservice_training_r3288 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3288_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3288_hospital_scorecard() to authenticated;

-- 3) Equipment type × session type matrix
create or replace function public.founder_r3288_equipment_session_matrix()
returns table(equipment_type text, session_type text, sessions bigint, effective bigint, avg_pass_rate_pct numeric, avg_feedback numeric)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.session_type, count(*)::bigint,
    count(*) filter (where l.delivery_verdict = 'completed_effective')::bigint,
    round(avg(l.pass_rate_pct), 1),
    round(avg(l.customer_feedback_score), 2)
  from public.inservice_training_r3288 l
  group by l.equipment_type, l.session_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3288_equipment_session_matrix() from public, anon;
grant execute on function public.founder_r3288_equipment_session_matrix() to authenticated;

-- 4) Daily delivery trend
create or replace function public.founder_r3288_daily_delivery_trend()
returns table(session_date date, sessions bigint, effective bigint, not_delivered bigint, total_attendees bigint, total_no_shows bigint)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.session_date,
    count(*)::bigint,
    count(*) filter (where l.delivery_verdict = 'completed_effective')::bigint,
    count(*) filter (where l.delivery_verdict = 'not_delivered')::bigint,
    coalesce(sum(l.attendees_count),0)::bigint,
    coalesce(sum(l.no_show_count),0)::bigint
  from public.inservice_training_r3288 l
  group by l.session_date
  order by l.session_date desc;
end;
$$;

revoke execute on function public.founder_r3288_daily_delivery_trend() from public, anon;
grant execute on function public.founder_r3288_daily_delivery_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3288_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.inservice_training_capa_actions_r3288 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3288_capa_status_board() from public, anon;
grant execute on function public.founder_r3288_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3288_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.inservice_training_capa_actions_r3288)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.inservice_training_capa_actions_r3288 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3288_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3288_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3288_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.inservice_training_capa_actions_r3288 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3288_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3288_regulatory_impact_digest() to authenticated;

-- 8) High-risk training queue (top individual concerns)
create or replace function public.founder_r3288_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  equipment_type text,
  session_date date,
  delivery_verdict text,
  cadre text,
  pass_rate_pct numeric,
  customer_feedback_score int,
  no_show_count int,
  notes text
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.equipment_type, l.session_date,
    l.delivery_verdict, l.cadre, l.pass_rate_pct, l.customer_feedback_score,
    l.no_show_count, l.notes
  from public.inservice_training_r3288 l
  where l.delivery_verdict in ('completed_needs_followup','partial','rescheduled','not_delivered')
     or l.pass_rate_pct < 80
     or l.customer_feedback_score <= 3
     or l.no_show_count >= 3
     or l.followup_required = true
     or l.competency_assessment_done = false
  order by l.session_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3288_high_risk_queue() from public, anon;
grant execute on function public.founder_r3288_high_risk_queue() to authenticated;
