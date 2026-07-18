-- Round 3228: Engineer Second-Opinion Consult & Remote-Diagnosis Assist Tracker
-- Remote assist log — requesting engineer × assisting expert × channel × equipment category × resolved-remotely × visit-avoided × minutes × KB article × CAPA

-- =============================================================================
-- TABLE 1: remote_assist_r3228 — second-opinion / remote-diagnosis sessions
-- =============================================================================
create table if not exists public.remote_assist_r3228 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  assist_ref_code text not null,
  requesting_engineer_name text not null,
  assisting_expert_name text not null,
  assist_channel text not null check (assist_channel in (
    'video_call','photo_annotation','chat_thread','phone_call','screen_share','ar_remote_overlay'
  )),
  equipment_category text not null check (equipment_category in (
    'ventilator','dialysis_machine','ct_scanner','mri','ultrasound','patient_monitor',
    'defibrillator','infusion_pump','c_arm','anesthesia_workstation','autoclave','x_ray'
  )),
  fault_summary text not null,
  request_date date not null,
  session_started_at timestamptz not null,
  session_ended_at timestamptz,
  minutes_spent int,
  resolved_remotely boolean not null default false,
  visit_avoided boolean not null default false,
  kb_article_created boolean not null default false,
  complexity_level text not null check (complexity_level in (
    'basic','intermediate','advanced','expert_level'
  )),
  assist_verdict text not null check (assist_verdict in (
    'resolved_remotely','partial_fix_visit_needed','escalated_oem','parts_required',
    'unresolved_visit_scheduled','guidance_only','pending_followup'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.remote_assist_r3228 enable row level security;

create index if not exists idx_remote_assist_r3228_org on public.remote_assist_r3228(organization_id);
create index if not exists idx_remote_assist_r3228_date on public.remote_assist_r3228(request_date);
create index if not exists idx_remote_assist_r3228_verdict on public.remote_assist_r3228(assist_verdict);

-- =============================================================================
-- TABLE 2: remote_assist_capa_actions_r3228 — CAPA & improvement actions
-- =============================================================================
create table if not exists public.remote_assist_capa_actions_r3228 (
  id uuid primary key default gen_random_uuid(),
  remote_assist_id uuid not null references public.remote_assist_r3228(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'misdiagnosis_remote','knowledge_gap','connectivity_failure','escalation_delay',
    'documentation_missing','unnecessary_visit','sla_breach','repeat_fault','tooling_gap','kb_not_updated'
  )),
  root_cause text not null check (root_cause in (
    'engineer_training_gap','poor_video_quality','no_service_manual_access',
    'oem_support_unavailable','spare_part_unavailable','network_bandwidth_low',
    'process_not_followed','kb_article_outdated','pending_investigation','expert_roster_thin'
  )),
  corrective_action text not null check (corrective_action in (
    'schedule_training','update_kb_article','provision_ar_headset','upgrade_network_link',
    'add_expert_to_roster','escalate_to_oem','create_service_manual_library',
    'revise_triage_checklist','none_required','stock_critical_spare'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.remote_assist_capa_actions_r3228 enable row level security;

create index if not exists idx_remote_assist_capa_r3228_assist on public.remote_assist_capa_actions_r3228(remote_assist_id);
create index if not exists idx_remote_assist_capa_r3228_status on public.remote_assist_capa_actions_r3228(capa_status);

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

  -- 13 remote-assist session rows
  insert into public.remote_assist_r3228 (
    organization_id, hospital_name, assist_ref_code, requesting_engineer_name, assisting_expert_name,
    assist_channel, equipment_category, fault_summary,
    request_date, session_started_at, session_ended_at, minutes_spent,
    resolved_remotely, visit_avoided, kb_article_created,
    complexity_level, assist_verdict, notes
  )
  select v_org_id, q.hosp, q.ref, q.req_eng, q.expert,
    q.ch, q.cat, q.fault,
    q.rd::date, q.ss::timestamptz, q.se::timestamptz, q.mins,
    q.rr, q.va, q.kb,
    q.cx, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','RA-001','Ganesh Kotari','Suresh Menon (L3 Ventilators)','video_call','ventilator',
     'PEEP valve alarm persisting after circuit change','2026-07-02','2026-07-02 09:15:00+05:30','2026-07-02 09:55:00+05:30',40,
     true,true,true,'intermediate','resolved_remotely','Flow-sensor recalibration guided over video'),
    ('Apollo Hyderabad Jubilee Hills','RA-002','Ganesh Kotari','Priya Nair (Infusion SME)','phone_call','infusion_pump',
     'Occlusion alarm at low flow rates','2026-07-02','2026-07-02 14:05:00+05:30','2026-07-02 14:22:00+05:30',17,
     true,true,false,'basic','resolved_remotely','Occlusion sensitivity set per IFU; alarm cleared'),
    ('Fortis Bannerghatta Bengaluru','RA-003','Imran Shaikh','Rajesh Iyer (CT Specialist)','video_call','ct_scanner',
     'Tube arc detection error on warm-up','2026-07-01','2026-07-01 10:30:00+05:30','2026-07-01 11:45:00+05:30',75,
     false,false,true,'advanced','partial_fix_visit_needed','Arc counter reset remotely; tube seasoning visit scheduled'),
    ('Fortis Bannerghatta Bengaluru','RA-004','Imran Shaikh','Anita Desai (Monitoring SME)','chat_thread','patient_monitor',
     'SpO2 module intermittent dropout','2026-07-01','2026-07-01 16:10:00+05:30','2026-07-01 16:35:00+05:30',25,
     true,true,false,'basic','resolved_remotely','Cable reseated and module firmware toggle applied'),
    ('Manipal Whitefield Bengaluru','RA-005','Deepak Rao','Vikram Joshi (Dialysis L3)','screen_share','dialysis_machine',
     'Conductivity drift post disinfection','2026-06-30','2026-06-30 08:40:00+05:30','2026-06-30 09:35:00+05:30',55,
     true,true,true,'intermediate','resolved_remotely','Conductivity cell recalibration guided via HMI screen share'),
    ('Manipal Whitefield Bengaluru','RA-006','Deepak Rao','Karthik Reddy (MRI Expert)','video_call','mri',
     'Helium level alarm with compressor fault','2026-06-30','2026-06-30 11:00:00+05:30','2026-06-30 12:10:00+05:30',70,
     false,false,false,'expert_level','escalated_oem','Cold-head degradation suspected; OEM cryo team engaged'),
    ('AIIMS New Delhi Ansari Nagar','RA-007','Neha Sharma','Suresh Menon (L3 Ventilators)','ar_remote_overlay','anesthesia_workstation',
     'Vaporizer output deviation on agent check','2026-06-29','2026-06-29 09:20:00+05:30','2026-06-29 10:05:00+05:30',45,
     true,true,true,'advanced','resolved_remotely','AR overlay walked engineer through vaporizer seat cleaning'),
    ('AIIMS New Delhi Ansari Nagar','RA-008','Neha Sharma','Anita Desai (Monitoring SME)','photo_annotation','x_ray',
     'Collimator lamp not turning on','2026-06-29','2026-06-29 15:00:00+05:30','2026-06-29 15:12:00+05:30',12,
     true,false,false,'basic','guidance_only','Annotated photo showed lamp fuse location; engineer replaced onsite'),
    ('KIMS Secunderabad','RA-009','Ravi Teja','Priya Nair (Infusion SME)','video_call','defibrillator',
     'Capacitor charge time exceeding 12 seconds','2026-06-28','2026-06-28 10:45:00+05:30','2026-06-28 11:20:00+05:30',35,
     false,false,false,'intermediate','parts_required','HV capacitor ageing confirmed; part quote raised'),
    ('Care Hospitals Banjara Hills','RA-010','Sandeep Verma','Vikram Joshi (Dialysis L3)','phone_call','ultrasound',
     'Probe artifact on curvilinear transducer','2026-06-28','2026-06-28 12:30:00+05:30','2026-06-28 12:50:00+05:30',20,
     true,true,false,'basic','resolved_remotely','Probe connector cleaned; artifact gone on retest'),
    ('Yashoda Somajiguda Hyderabad','RA-011','Mahesh Gupta','Rajesh Iyer (CT Specialist)','video_call','c_arm',
     'Image intensifier flickering during fluoro','2026-06-27','2026-06-27 09:00:00+05:30','2026-06-27 10:15:00+05:30',75,
     false,false,false,'advanced','unresolved_visit_scheduled','Video froze repeatedly on hospital wifi; onsite visit booked'),
    ('St John''s Bengaluru','RA-012','Alwin D''Souza','Karthik Reddy (MRI Expert)','chat_thread','autoclave',
     'Vacuum pump noise after descale','2026-06-27','2026-06-27 14:20:00+05:30','2026-06-27 14:50:00+05:30',30,
     true,true,true,'intermediate','resolved_remotely','Pump oil top-up procedure shared; noise resolved'),
    ('Rainbow Children''s Hyderabad','RA-013','Farhan Ali','Suresh Menon (L3 Ventilators)','video_call','ventilator',
     'Neonatal vent oxygen blender drift','2026-06-26','2026-06-26 08:10:00+05:30',null,60,
     false,false,false,'expert_level','pending_followup','Blender behaviour intermittent; second session scheduled')
  ) as q(hosp, ref, req_eng, expert, ch, cat, fault, rd, ss, se, mins, rr, va, kb, cx, verdict, nt);

  -- CAPA seed — attach to specific assist sessions by ref code
  insert into public.remote_assist_capa_actions_r3228 (
    remote_assist_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('RA-003','knowledge_gap','no_service_manual_access','create_service_manual_library','2026-07-10',null,'in_progress','internal_only',8500.00,'CT service manual library being provisioned for L2 engineers'),
    ('RA-006','escalation_delay','oem_support_unavailable','escalate_to_oem','2026-07-12',null,'escalated','patient_safety_alert',150000.00,'OEM cryo engineer ETA 5 days; scanner down'),
    ('RA-009','repeat_fault','spare_part_unavailable','stock_critical_spare','2026-07-08',null,'open','nabh_finding',22000.00,'HV capacitor added to critical-spares stocking list'),
    ('RA-011','connectivity_failure','network_bandwidth_low','upgrade_network_link','2026-07-15',null,'in_progress','internal_only',35000.00,'Dedicated 4G router approved for biomedical workshop'),
    ('RA-008','kb_not_updated','kb_article_outdated','update_kb_article','2026-07-05','2026-07-03','closed','none',0.00,'Collimator fuse KB article refreshed with annotated photos'),
    ('RA-013','sla_breach','expert_roster_thin','add_expert_to_roster','2026-07-20',null,'open','iso_13485_deviation',60000.00,'Second neonatal ventilator expert being onboarded')
  ) as q(ref_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.remote_assist_r3228 e
    on e.organization_id = v_org_id and e.assist_ref_code = q.ref_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Assist verdict distribution
create or replace function public.founder_r3228_verdict_rollup()
returns table(assist_verdict text, sessions bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.remote_assist_r3228)
  select l.assist_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.remote_assist_r3228 l
  group by l.assist_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3228_verdict_rollup() from public, anon;
grant execute on function public.founder_r3228_verdict_rollup() to authenticated;

-- 2) Hospital-level remote-assist scorecard
create or replace function public.founder_r3228_hospital_scorecard()
returns table(
  hospital_name text,
  total_sessions bigint,
  resolved_remote bigint,
  visits_avoided bigint,
  kb_articles bigint,
  avg_minutes numeric,
  remote_fix_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.resolved_remotely)::bigint,
    count(*) filter (where l.visit_avoided)::bigint,
    count(*) filter (where l.kb_article_created)::bigint,
    round(avg(l.minutes_spent)::numeric, 1),
    round(100.0 * count(*) filter (where l.resolved_remotely)::numeric / nullif(count(*),0), 1)
  from public.remote_assist_r3228 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3228_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3228_hospital_scorecard() to authenticated;

-- 3) Channel × equipment category matrix
create or replace function public.founder_r3228_channel_category_matrix()
returns table(assist_channel text, equipment_category text, sessions bigint, resolved_remote bigint, avg_minutes numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.assist_channel, l.equipment_category, count(*)::bigint,
    count(*) filter (where l.resolved_remotely)::bigint,
    round(avg(l.minutes_spent)::numeric, 1)
  from public.remote_assist_r3228 l
  group by l.assist_channel, l.equipment_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3228_channel_category_matrix() from public, anon;
grant execute on function public.founder_r3228_channel_category_matrix() to authenticated;

-- 4) Daily remote-assist trend
create or replace function public.founder_r3228_daily_trend()
returns table(request_date date, sessions bigint, resolved_remote bigint, visits_avoided bigint, total_minutes bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.request_date,
    count(*)::bigint,
    count(*) filter (where l.resolved_remotely)::bigint,
    count(*) filter (where l.visit_avoided)::bigint,
    coalesce(sum(l.minutes_spent),0)::bigint
  from public.remote_assist_r3228 l
  group by l.request_date
  order by l.request_date desc;
end;
$$;

revoke execute on function public.founder_r3228_daily_trend() from public, anon;
grant execute on function public.founder_r3228_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3228_capa_status_board()
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
  from public.remote_assist_capa_actions_r3228 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3228_capa_status_board() from public, anon;
grant execute on function public.founder_r3228_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3228_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.remote_assist_capa_actions_r3228)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.remote_assist_capa_actions_r3228 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3228_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3228_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3228_regulatory_impact_digest()
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
  from public.remote_assist_capa_actions_r3228 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3228_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3228_regulatory_impact_digest() to authenticated;

-- 8) High-risk / unresolved assist queue
create or replace function public.founder_r3228_high_risk_queue()
returns table(
  hospital_name text,
  assist_ref_code text,
  requesting_engineer_name text,
  equipment_category text,
  assist_channel text,
  request_date date,
  minutes_spent int,
  assist_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.assist_ref_code, l.requesting_engineer_name, l.equipment_category,
    l.assist_channel, l.request_date, l.minutes_spent, l.assist_verdict, l.notes
  from public.remote_assist_r3228 l
  where l.assist_verdict in ('partial_fix_visit_needed','escalated_oem','parts_required','unresolved_visit_scheduled','pending_followup')
     or l.resolved_remotely = false
  order by l.request_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3228_high_risk_queue() from public, anon;
grant execute on function public.founder_r3228_high_risk_queue() to authenticated;
