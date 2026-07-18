-- Round 3264: Engineer Subcontractor / Channel-Partner Field-Work Quality Tracker
-- Partner-technician quality governance — partner firm × equipment type × SLA × first-time-fix × workmanship × safety compliance × customer rating × verdict + CAPA

-- =============================================================================
-- TABLE 1: subcontractor_field_work_r3264 — per-subcontractor field-work jobs
-- =============================================================================
create table if not exists public.subcontractor_field_work_r3264 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  partner_firm text not null,
  partner_technician text not null,
  region text not null,
  job_code text not null,
  equipment_type text not null check (equipment_type in (
    'patient_monitor','dialysis','imaging','lab_analyzer','ot_equipment','general_biomedical'
  )),
  job_date date not null,
  sla_met boolean not null,
  first_time_fix boolean not null,
  workmanship_grade text not null check (workmanship_grade in (
    'excellent','acceptable','rework_needed','rejected'
  )),
  safety_compliance text not null check (safety_compliance in (
    'compliant','minor_gap','major_violation'
  )),
  documentation_complete boolean not null,
  customer_rating int not null check (customer_rating between 1 and 5),
  warranty_callback_within_30d boolean not null,
  invoice_dispute boolean not null,
  partner_verdict text not null check (partner_verdict in (
    'preferred','approved','on_watch','probation','blacklisted'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.subcontractor_field_work_r3264 enable row level security;

create index if not exists idx_subcontractor_field_work_r3264_org on public.subcontractor_field_work_r3264(organization_id);
create index if not exists idx_subcontractor_field_work_r3264_date on public.subcontractor_field_work_r3264(job_date);
create index if not exists idx_subcontractor_field_work_r3264_verdict on public.subcontractor_field_work_r3264(partner_verdict);

-- =============================================================================
-- TABLE 2: subcontractor_field_work_capa_actions_r3264 — CAPA for at-risk partners
-- =============================================================================
create table if not exists public.subcontractor_field_work_capa_actions_r3264 (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.subcontractor_field_work_r3264(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'workmanship_defect','sla_breach','safety_violation','documentation_gap',
    'warranty_callback','invoice_dispute','repeat_failure','certification_lapse'
  )),
  root_cause text not null check (root_cause in (
    'inadequate_training','wrong_parts_used','rushed_job','tool_calibration_lapse',
    'process_not_followed','communication_gap','partner_capacity_overload','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'retraining_mandated','partner_audit_scheduled','rework_at_partner_cost','warning_issued',
    'probation_imposed','blacklist_partner','sop_reissued','replace_technician','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  risk_level text not null check (risk_level in (
    'low','medium','high','critical'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.subcontractor_field_work_capa_actions_r3264 enable row level security;

create index if not exists idx_subcontractor_capa_r3264_job on public.subcontractor_field_work_capa_actions_r3264(job_id);
create index if not exists idx_subcontractor_capa_r3264_status on public.subcontractor_field_work_capa_actions_r3264(capa_status);

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

  -- 14 subcontractor field-work rows
  insert into public.subcontractor_field_work_r3264 (
    organization_id, partner_firm, partner_technician, region, job_code, equipment_type,
    job_date, sla_met, first_time_fix, workmanship_grade, safety_compliance,
    documentation_complete, customer_rating, warranty_callback_within_30d, invoice_dispute,
    partner_verdict, notes
  )
  select v_org_id, q.firm, q.tech, q.region, q.jcode, q.eqt,
    q.jd::date, q.sla, q.ftf, q.wg, q.sc,
    q.doc, q.rating, q.cb, q.disp,
    q.pv, q.nt
  from (values
    ('MedTech Field Services','Ramesh Kumar','Chennai','SC-CHN-7001','patient_monitor',
     '2026-07-05',true,true,'excellent','compliant',true,5,false,false,'preferred','Apollo Chennai ICU monitor PM — flawless, closed same visit'),
    ('MedTech Field Services','Suresh Nair','Chennai','SC-CHN-7002','dialysis',
     '2026-07-04',true,true,'acceptable','compliant',true,4,false,false,'approved','Apollo Chennai dialysis unit RO service — minor delay documented'),
    ('BioServe Partners','Anil Verma','Gurgaon','SC-GGN-8001','imaging',
     '2026-07-04',false,false,'rework_needed','minor_gap',false,2,true,false,'on_watch','Fortis Gurgaon CT calibration incomplete — callback within 30d'),
    ('BioServe Partners','Priya Sharma','Gurgaon','SC-GGN-8002','lab_analyzer',
     '2026-07-03',true,false,'acceptable','compliant',true,4,false,false,'approved','Fortis Gurgaon analyzer — second visit resolved fault'),
    ('CareTech Solutions','Karthik Reddy','Bengaluru','SC-BLR-9001','patient_monitor',
     '2026-07-03',true,true,'excellent','compliant',true,5,false,false,'preferred','Manipal Bengaluru monitor bank PM — exemplary workmanship'),
    ('CareTech Solutions','Deepak Joshi','Bengaluru','SC-BLR-9002','ot_equipment',
     '2026-07-02',false,false,'rejected','major_violation',false,1,true,true,'probation','Manipal Bengaluru OT table — safety violation, work rejected'),
    ('Sundaram Biomedical','Vijay Menon','Vellore','SC-VLR-6001','general_biomedical',
     '2026-07-02',true,true,'acceptable','compliant',true,4,false,false,'approved','CMC Vellore biomed round — satisfactory, all docs signed'),
    ('Sundaram Biomedical','Fatima Sheikh','Vellore','SC-VLR-6002','dialysis',
     '2026-07-01',false,false,'rework_needed','minor_gap',false,2,true,true,'on_watch','CMC Vellore dialysis RO — rework needed plus invoice dispute'),
    ('Zenith Clinical Engineering','Arjun Pillai','Hyderabad','SC-HYD-5001','imaging',
     '2026-07-01',true,true,'excellent','compliant',true,5,false,false,'preferred','KIMS Hyderabad MRI chiller PM — top marks from biomed HOD'),
    ('Zenith Clinical Engineering','Neha Gupta','Hyderabad','SC-HYD-5002','lab_analyzer',
     '2026-06-30',true,false,'acceptable','minor_gap',true,3,false,false,'approved','KIMS Hyderabad analyzer — service report template gap noted'),
    ('Reliance Healthtech Services','Sanjay Rao','Delhi','SC-DEL-4001','ot_equipment',
     '2026-06-30',false,false,'rework_needed','major_violation',false,1,true,false,'probation','AIIMS Delhi electrosurgical unit — earth leakage not verified'),
    ('Reliance Healthtech Services','Meena Iyer','Delhi','SC-DEL-4002','patient_monitor',
     '2026-06-29',true,true,'acceptable','compliant',true,4,false,false,'approved','AIIMS Delhi telemetry central — clean, on-time'),
    ('Apex Biomed Partners','Rohit Malhotra','Mumbai','SC-MUM-3001','general_biomedical',
     '2026-06-29',false,false,'rejected','major_violation',false,1,true,true,'blacklisted','Nova IVF Mumbai — repeated failures, partner blacklisted'),
    ('Apex Biomed Partners','Sneha Kulkarni','Pune','SC-PUN-2001','dialysis',
     '2026-06-28',true,true,'excellent','compliant',true,5,false,false,'preferred','Cloudnine Pune dialysis unit — excellent turnaround, zero callbacks')
  ) as q(firm, tech, region, jcode, eqt, jd, sla, ftf, wg, sc, doc, rating, cb, disp, pv, nt);

  -- CAPA seed — attach to specific jobs via job_code
  insert into public.subcontractor_field_work_capa_actions_r3264 (
    job_id, finding_category, root_cause, corrective_action,
    capa_status, risk_level, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.rl, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SC-GGN-8001','workmanship_defect','process_not_followed','rework_at_partner_cost','in_progress','high','2026-07-11',null,25000.00,'CT calibration redo scheduled at partner cost — verify HU accuracy'),
    ('SC-BLR-9002','safety_violation','inadequate_training','retraining_mandated','escalated','critical','2026-07-08',null,40000.00,'OT table brake failure — technician retraining plus partner audit'),
    ('SC-VLR-6002','sla_breach','partner_capacity_overload','partner_audit_scheduled','open','medium','2026-07-14',null,15000.00,'RO rework plus invoice dispute — partner capacity audit booked'),
    ('SC-DEL-4001','safety_violation','process_not_followed','probation_imposed','overdue','critical','2026-06-30',null,35000.00,'Earth leakage not verified — partner placed on probation'),
    ('SC-MUM-3001','repeat_failure','communication_gap','blacklist_partner','closed','critical','2026-07-02','2026-07-05',0.00,'Third failure this quarter — partner blacklisted, jobs reassigned'),
    ('SC-HYD-5002','documentation_gap','communication_gap','sop_reissued','verification_pending','low','2026-07-05',null,5000.00,'Service report SOP reissued to partner — verify next submission'),
    ('SC-BLR-9002','warranty_callback','wrong_parts_used','replace_technician','in_progress','high','2026-07-10',null,18000.00,'Wrong brake kit fitted — technician swapped, warranty callback logged')
  ) as q(jcode, fc, rc, ca, cst, rl, tcd, acd, cost, nt)
  join public.subcontractor_field_work_r3264 e
    on e.organization_id = v_org_id and e.job_code = q.jcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Partner verdict distribution
create or replace function public.founder_r3264_partner_verdict_rollup()
returns table(partner_verdict text, jobs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.subcontractor_field_work_r3264)
  select l.partner_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.subcontractor_field_work_r3264 l
  group by l.partner_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3264_partner_verdict_rollup() from public, anon;
grant execute on function public.founder_r3264_partner_verdict_rollup() to authenticated;

-- 2) Partner-firm quality scorecard
create or replace function public.founder_r3264_partner_scorecard()
returns table(
  partner_firm text,
  total_jobs bigint,
  sla_met_jobs bigint,
  first_time_fix_jobs bigint,
  rework_rejected bigint,
  safety_violations bigint,
  warranty_callbacks bigint,
  invoice_disputes bigint,
  avg_rating numeric,
  quality_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.partner_firm,
    count(*)::bigint,
    count(*) filter (where l.sla_met)::bigint,
    count(*) filter (where l.first_time_fix)::bigint,
    count(*) filter (where l.workmanship_grade in ('rework_needed','rejected'))::bigint,
    count(*) filter (where l.safety_compliance in ('minor_gap','major_violation'))::bigint,
    count(*) filter (where l.warranty_callback_within_30d)::bigint,
    count(*) filter (where l.invoice_dispute)::bigint,
    round(avg(l.customer_rating), 2),
    round(100.0 * count(*) filter (where l.workmanship_grade in ('excellent','acceptable'))::numeric / nullif(count(*),0), 1)
  from public.subcontractor_field_work_r3264 l
  group by l.partner_firm
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3264_partner_scorecard() from public, anon;
grant execute on function public.founder_r3264_partner_scorecard() to authenticated;

-- 3) Partner-firm × equipment-type matrix
create or replace function public.founder_r3264_firm_equipment_matrix()
returns table(partner_firm text, equipment_type text, jobs bigint, sla_met_jobs bigint, first_time_fix_jobs bigint, avg_rating numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.partner_firm, l.equipment_type, count(*)::bigint,
    count(*) filter (where l.sla_met)::bigint,
    count(*) filter (where l.first_time_fix)::bigint,
    round(avg(l.customer_rating), 2)
  from public.subcontractor_field_work_r3264 l
  group by l.partner_firm, l.equipment_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3264_firm_equipment_matrix() from public, anon;
grant execute on function public.founder_r3264_firm_equipment_matrix() to authenticated;

-- 4) Daily quality trend
create or replace function public.founder_r3264_daily_quality_trend()
returns table(job_date date, jobs bigint, sla_met_jobs bigint, first_time_fix_jobs bigint, rework_rejected bigint, safety_gaps bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.job_date,
    count(*)::bigint,
    count(*) filter (where l.sla_met)::bigint,
    count(*) filter (where l.first_time_fix)::bigint,
    count(*) filter (where l.workmanship_grade in ('rework_needed','rejected'))::bigint,
    count(*) filter (where l.safety_compliance in ('minor_gap','major_violation'))::bigint
  from public.subcontractor_field_work_r3264 l
  group by l.job_date
  order by l.job_date desc;
end;
$$;

revoke execute on function public.founder_r3264_daily_quality_trend() from public, anon;
grant execute on function public.founder_r3264_daily_quality_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3264_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, escalated_flag bigint)
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
  from public.subcontractor_field_work_capa_actions_r3264 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3264_capa_status_board() from public, anon;
grant execute on function public.founder_r3264_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3264_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.subcontractor_field_work_capa_actions_r3264)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.subcontractor_field_work_capa_actions_r3264 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3264_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3264_root_cause_pareto() to authenticated;

-- 7) Risk-impact & cost digest
create or replace function public.founder_r3264_risk_impact_digest()
returns table(risk_level text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.risk_level, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.subcontractor_field_work_capa_actions_r3264 c
  group by c.risk_level
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3264_risk_impact_digest() from public, anon;
grant execute on function public.founder_r3264_risk_impact_digest() to authenticated;

-- 8) High-risk partner-job queue (individual concerns)
create or replace function public.founder_r3264_high_risk_queue()
returns table(
  partner_firm text,
  partner_technician text,
  region text,
  job_code text,
  job_date date,
  partner_verdict text,
  workmanship_grade text,
  safety_compliance text,
  customer_rating int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.partner_firm, l.partner_technician, l.region, l.job_code, l.job_date,
    l.partner_verdict, l.workmanship_grade, l.safety_compliance, l.customer_rating, l.notes
  from public.subcontractor_field_work_r3264 l
  where l.partner_verdict in ('on_watch','probation','blacklisted')
     or l.workmanship_grade in ('rework_needed','rejected')
     or l.safety_compliance in ('minor_gap','major_violation')
     or l.sla_met = false
     or l.warranty_callback_within_30d = true
     or l.invoice_dispute = true
     or l.customer_rating <= 2
  order by l.job_date desc, l.partner_firm;
end;
$$;

revoke execute on function public.founder_r3264_high_risk_queue() from public, anon;
grant execute on function public.founder_r3264_high_risk_queue() to authenticated;
