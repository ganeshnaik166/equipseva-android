-- Round 3524: Engineer Service-Quality Random-Visit Audit Scorecard Tracker
-- Random supervisor field-visit service-quality audit scorecard — engineer × hospital × auditor ×
-- audit dimension (workmanship / safety-PPE / documentation / tool-calibration / customer-interaction /
-- SOP-adherence / cleanliness) × score × grade × critical-finding × re-audit × CAPA closure.

-- =============================================================================
-- TABLE 1: service_quality_audit_r3524 — per-visit service-quality audit scores
-- =============================================================================
create table if not exists public.service_quality_audit_r3524 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  audit_ref text not null,
  engineer_name text not null,
  hospital_name text not null,
  auditor_name text not null,
  visit_date date not null,
  audit_dimension text not null check (audit_dimension in (
    'workmanship','safety_ppe','documentation','tool_calibration',
    'customer_interaction','sop_adherence','cleanliness'
  )),
  score int not null,
  max_score int not null,
  score_pct numeric(5,2),
  grade text not null check (grade in (
    'excellent','good','satisfactory','needs_improvement','fail'
  )),
  critical_finding boolean not null,
  reaudit_required boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.service_quality_audit_r3524 enable row level security;

create index if not exists idx_service_quality_audit_r3524_org on public.service_quality_audit_r3524(organization_id);
create index if not exists idx_service_quality_audit_r3524_date on public.service_quality_audit_r3524(visit_date);
create index if not exists idx_service_quality_audit_r3524_grade on public.service_quality_audit_r3524(grade);

-- =============================================================================
-- TABLE 2: service_quality_audit_capa_actions_r3524 — CAPA & quality actions
-- =============================================================================
create table if not exists public.service_quality_audit_capa_actions_r3524 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  audit_id uuid not null references public.service_quality_audit_r3524(id) on delete cascade,
  finding_category text not null check (finding_category in (
    'poor_workmanship','ppe_non_compliance','incomplete_documentation','tool_out_of_calibration',
    'poor_customer_interaction','sop_deviation','poor_cleanliness','safety_hazard',
    'missing_calibration_cert','repeat_defect'
  )),
  root_cause text not null check (root_cause in (
    'inadequate_training','time_pressure','missing_tools','unclear_sop','carelessness',
    'tool_calibration_lapsed','staffing_shortage','supervisor_gap','pending_investigation','process_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_engineer','issue_ppe_kit','update_documentation','recalibrate_tools','coaching_session',
    'revise_sop','reaudit_visit','disciplinary_warning','assign_mentor','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  quality_impact text not null check (quality_impact in (
    'customer_complaint_risk','safety_risk','warranty_risk','none','internal_only',
    'sla_breach_risk','rework_cost'
  )),
  owner text not null,
  estimated_cost_rupees numeric(12,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.service_quality_audit_capa_actions_r3524 enable row level security;

create index if not exists idx_service_quality_capa_r3524_audit on public.service_quality_audit_capa_actions_r3524(audit_id);
create index if not exists idx_service_quality_capa_r3524_status on public.service_quality_audit_capa_actions_r3524(capa_status);

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

  -- 16 audit rows
  insert into public.service_quality_audit_r3524 (
    organization_id, audit_ref, engineer_name, hospital_name, auditor_name, visit_date,
    audit_dimension, score, max_score, score_pct, grade,
    critical_finding, reaudit_required, notes
  )
  select v_org_id, q.aref, q.eng, q.hosp, q.aud, q.vd::date,
    q.dim, q.sc, q.mx, q.pct, q.grd,
    q.crit, q.reaud, q.nt
  from (values
    ('SQA-0001','Ravi Kumar','Apollo Chennai','Rajesh Iyer','2026-07-05','workmanship',
     94,100,94.0,'excellent',false,false,'Ventilator PM workmanship neat — cable dressing and labelling per SOP'),
    ('SQA-0002','Suresh Nair','Fortis Gurgaon','Meena Gopal','2026-07-04','safety_ppe',
     62,100,62.0,'needs_improvement',true,true,'Worked on live panel without insulated gloves — critical PPE lapse'),
    ('SQA-0003','Anil Deshmukh','Manipal Bengaluru','Karthik Reddy','2026-07-04','documentation',
     78,100,78.0,'satisfactory',false,false,'Service report complete but calibration values not recorded'),
    ('SQA-0004','Priya Menon','AIIMS Delhi','Rajesh Iyer','2026-07-03','tool_calibration',
     45,100,45.0,'fail',true,true,'Torque wrench calibration expired 4 months — re-audit mandated'),
    ('SQA-0005','Vikram Singh','CMC Vellore','Meena Gopal','2026-07-03','customer_interaction',
     91,100,91.0,'excellent',false,false,'Biomed HOD praised communication and turnaround time'),
    ('SQA-0006','Deepak Rao','KIMS Hyderabad','Karthik Reddy','2026-07-02','sop_adherence',
     83,100,83.0,'good',false,false,'Minor SOP deviation — skipped one pre-check step but recovered'),
    ('SQA-0007','Ravi Kumar','Yashoda Hyderabad','Rajesh Iyer','2026-07-02','cleanliness',
     72,100,72.0,'satisfactory',false,true,'Work area left with packing debris — re-visit to confirm cleanup'),
    ('SQA-0008','Suresh Nair','Kokilaben Mumbai','Meena Gopal','2026-07-01','workmanship',
     55,100,55.0,'needs_improvement',true,true,'Poor cable termination on defibrillator — potential safety concern'),
    ('SQA-0009','Anil Deshmukh','Apollo Chennai','Karthik Reddy','2026-06-28','documentation',
     96,100,96.0,'excellent',false,false,'Documentation exemplary — full asset traceability captured'),
    ('SQA-0010','Priya Menon','Fortis Gurgaon','Rajesh Iyer','2026-06-27','safety_ppe',
     85,100,85.0,'good',false,false,'PPE compliant; minor lapse in LOTO tagging noted and corrected'),
    ('SQA-0011','Vikram Singh','Manipal Bengaluru','Meena Gopal','2026-06-26','tool_calibration',
     68,100,68.0,'needs_improvement',false,true,'Multimeter calibration certificate missing — re-audit after cal'),
    ('SQA-0012','Deepak Rao','AIIMS Delhi','Karthik Reddy','2026-06-25','sop_adherence',
     40,100,40.0,'fail',true,true,'Bypassed electrical safety test SOP entirely — critical deviation'),
    ('SQA-0013','Ravi Kumar','CMC Vellore','Rajesh Iyer','2026-06-24','customer_interaction',
     80,100,80.0,'good',false,false,'Good rapport with staff; response to a query slightly delayed'),
    ('SQA-0014','Suresh Nair','KIMS Hyderabad','Meena Gopal','2026-05-30','cleanliness',
     89,100,89.0,'good',false,false,'Site left clean; consumables disposed per biomedical protocol'),
    ('SQA-0015','Anil Deshmukh','Yashoda Hyderabad','Karthik Reddy','2026-05-29','workmanship',
     76,100,76.0,'satisfactory',false,false,'Acceptable workmanship; wire routing and strain relief could improve'),
    ('SQA-0016','Priya Menon','Kokilaben Mumbai','Rajesh Iyer','2026-05-28','documentation',
     58,100,58.0,'needs_improvement',false,true,'Missing signatures and asset IDs on service sheet — rework required')
  ) as q(aref, eng, hosp, aud, vd, dim, sc, mx, pct, grd, crit, reaud, nt);

  -- 8 CAPA rows — attach to specific audits via audit_ref
  insert into public.service_quality_audit_capa_actions_r3524 (
    organization_id, audit_id, finding_category, root_cause, corrective_action,
    capa_status, quality_impact, owner, estimated_cost_rupees,
    target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.qi, q.own, q.cost,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('SQA-0002','ppe_non_compliance','inadequate_training','issue_ppe_kit','in_progress','safety_risk',
     'Meena Gopal',3500.00,'2026-07-10',null,'PPE kit reissued; toolbox talk on live-panel safety scheduled'),
    ('SQA-0004','tool_out_of_calibration','tool_calibration_lapsed','recalibrate_tools','open','warranty_risk',
     'Rajesh Iyer',6000.00,'2026-07-12',null,'Torque wrench sent for calibration; re-audit after certificate'),
    ('SQA-0008','poor_workmanship','carelessness','disciplinary_warning','escalated','safety_risk',
     'Rajesh Iyer',0.00,'2026-07-08',null,'Defibrillator cable reworked; written warning issued — escalated to ops head'),
    ('SQA-0011','missing_calibration_cert','process_gap','recalibrate_tools','verification_pending','internal_only',
     'Meena Gopal',2500.00,'2026-07-06',null,'Multimeter calibration certificate obtained; verifying on next visit'),
    ('SQA-0012','safety_hazard','unclear_sop','revise_sop','open','safety_risk',
     'Karthik Reddy',1500.00,'2026-07-15',null,'Electrical safety test SOP being rewritten; mandatory retrain queued'),
    ('SQA-0016','incomplete_documentation','inadequate_training','update_documentation','closed','none',
     'Rajesh Iyer',500.00,'2026-06-30','2026-06-29','Service sheet corrected; engineer coached on asset-ID capture'),
    ('SQA-0007','poor_cleanliness','time_pressure','coaching_session','overdue','customer_complaint_risk',
     'Meena Gopal',800.00,'2026-06-28',null,'Cleanup coaching past due — reschedule pending engineer availability'),
    ('SQA-0003','incomplete_documentation','carelessness','update_documentation','closed','internal_only',
     'Karthik Reddy',400.00,'2026-07-01','2026-06-30','Calibration values back-filled; report re-issued and verified')
  ) as q(aref, fc, rc, ca, cst, qi, own, cost, tcd, acd, nt)
  join public.service_quality_audit_r3524 e
    on e.organization_id = v_org_id and e.audit_ref = q.aref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Grade distribution
create or replace function public.founder_r3524_grade_rollup()
returns table(grade text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.service_quality_audit_r3524)
  select l.grade, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.service_quality_audit_r3524 l
  group by l.grade
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3524_grade_rollup() from public, anon;
grant execute on function public.founder_r3524_grade_rollup() to authenticated;

-- 2) Engineer scorecard
create or replace function public.founder_r3524_engineer_scorecard()
returns table(
  engineer_name text,
  total_audits bigint,
  excellent bigint,
  good bigint,
  satisfactory bigint,
  needs_improvement bigint,
  failed bigint,
  critical_findings bigint,
  reaudits bigint,
  avg_score_pct numeric
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
    count(*) filter (where l.grade = 'excellent')::bigint,
    count(*) filter (where l.grade = 'good')::bigint,
    count(*) filter (where l.grade = 'satisfactory')::bigint,
    count(*) filter (where l.grade = 'needs_improvement')::bigint,
    count(*) filter (where l.grade = 'fail')::bigint,
    count(*) filter (where l.critical_finding = true)::bigint,
    count(*) filter (where l.reaudit_required = true)::bigint,
    round(avg(l.score_pct), 1)
  from public.service_quality_audit_r3524 l
  group by l.engineer_name
  order by round(avg(l.score_pct), 1) desc;
end;
$$;

revoke execute on function public.founder_r3524_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3524_engineer_scorecard() to authenticated;

-- 3) Audit-dimension × grade matrix
create or replace function public.founder_r3524_dimension_grade_matrix()
returns table(audit_dimension text, grade text, audits bigint, critical_findings bigint, avg_score_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_dimension, l.grade, count(*)::bigint,
    count(*) filter (where l.critical_finding = true)::bigint,
    round(avg(l.score_pct), 2)
  from public.service_quality_audit_r3524 l
  group by l.audit_dimension, l.grade
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3524_dimension_grade_matrix() from public, anon;
grant execute on function public.founder_r3524_dimension_grade_matrix() to authenticated;

-- 4) Monthly quality trend
create or replace function public.founder_r3524_monthly_quality_trend()
returns table(
  audit_month date,
  audits bigint,
  passed bigint,
  failed bigint,
  critical_findings bigint,
  reaudits bigint,
  avg_score_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.visit_date)::date,
    count(*)::bigint,
    count(*) filter (where l.grade in ('excellent','good','satisfactory'))::bigint,
    count(*) filter (where l.grade in ('needs_improvement','fail'))::bigint,
    count(*) filter (where l.critical_finding = true)::bigint,
    count(*) filter (where l.reaudit_required = true)::bigint,
    round(avg(l.score_pct), 2)
  from public.service_quality_audit_r3524 l
  group by date_trunc('month', l.visit_date)
  order by date_trunc('month', l.visit_date) desc;
end;
$$;

revoke execute on function public.founder_r3524_monthly_quality_trend() from public, anon;
grant execute on function public.founder_r3524_monthly_quality_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3524_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.service_quality_audit_capa_actions_r3524 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3524_capa_status_board() from public, anon;
grant execute on function public.founder_r3524_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3524_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.service_quality_audit_capa_actions_r3524)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.service_quality_audit_capa_actions_r3524 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3524_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3524_root_cause_pareto() to authenticated;

-- 7) Quality-impact digest
create or replace function public.founder_r3524_quality_impact_digest()
returns table(quality_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.quality_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.service_quality_audit_capa_actions_r3524 c
  group by c.quality_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3524_quality_impact_digest() from public, anon;
grant execute on function public.founder_r3524_quality_impact_digest() to authenticated;

-- 8) High-risk audit queue (fail / needs-improvement / critical finding / re-audit)
create or replace function public.founder_r3524_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  auditor_name text,
  audit_dimension text,
  visit_date date,
  grade text,
  score_pct numeric,
  critical_finding boolean,
  reaudit_required boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.auditor_name, l.audit_dimension, l.visit_date,
    l.grade, l.score_pct, l.critical_finding, l.reaudit_required, l.notes
  from public.service_quality_audit_r3524 l
  where l.grade in ('needs_improvement','fail')
     or l.critical_finding = true
     or l.reaudit_required = true
  order by l.visit_date desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3524_high_risk_queue() from public, anon;
grant execute on function public.founder_r3524_high_risk_queue() to authenticated;
