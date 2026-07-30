-- Round 3645: Founder ISO-13485 QMS Internal-Audit / Nonconformity Board
-- Device-manufacturing QMS internal-audit log — clause ref × process area × audits done × findings raised × major/minor NC × observations × closure % × avg closure days × NC severity × audit status × trend × CAPA

-- =============================================================================
-- TABLE 1: iso13485_qms_r3645 — clause-wise internal-audit nonconformity records
-- =============================================================================
create table if not exists public.iso13485_qms_r3645 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  audit_ref text not null,
  clause_ref text not null,
  process_area text not null,
  period_month date not null,
  audits_done int not null,
  findings_raised int not null,
  major_nc int not null,
  minor_nc int not null,
  observations int not null,
  closure_pct numeric(5,2),
  avg_closure_days numeric(6,2),
  audit_date date not null,
  next_audit_due date,
  nc_severity text not null check (nc_severity in (
    'major_nc','minor_nc','observation','ofi','conformant'
  )),
  audit_status text not null check (audit_status in (
    'closed','in_progress','verification_pending','overdue','escalated'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.iso13485_qms_r3645 enable row level security;

create index if not exists idx_iso13485_qms_r3645_org on public.iso13485_qms_r3645(organization_id);
create index if not exists idx_iso13485_qms_r3645_month on public.iso13485_qms_r3645(period_month);
create index if not exists idx_iso13485_qms_r3645_status on public.iso13485_qms_r3645(audit_status);

-- =============================================================================
-- TABLE 2: iso13485_qms_capa_actions_r3645 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.iso13485_qms_capa_actions_r3645 (
  id uuid primary key default gen_random_uuid(),
  audit_log_id uuid not null references public.iso13485_qms_r3645(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'document_control_gap','records_control_gap','management_review_gap','design_control_gap',
    'supplier_control_gap','process_validation_gap','sterilization_validation_gap',
    'calibration_record_gap','complaint_handling_delay','risk_management_gap',
    'capa_ineffectiveness','training_competence_gap','nonconforming_product_gap','traceability_gap'
  )),
  root_cause text not null check (root_cause in (
    'inadequate_procedure','insufficient_training','resource_constraint','supplier_quality_issue',
    'documentation_error','process_drift','system_configuration_gap','pending_investigation',
    'management_review_gap','measurement_system_error'
  )),
  corrective_action text not null check (corrective_action in (
    'revise_sop','retrain_staff','update_risk_file','supplier_requalification','revalidate_process',
    'strengthen_document_control','implement_capa_tracking','escalate_to_management',
    'schedule_reaudit','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'mdr_notifiable','iso_13485_major_nc','iso_13485_minor_nc','cdsco_observation',
    'internal_only','none','certification_risk'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.iso13485_qms_capa_actions_r3645 enable row level security;

create index if not exists idx_iso13485_capa_r3645_log on public.iso13485_qms_capa_actions_r3645(audit_log_id);
create index if not exists idx_iso13485_capa_r3645_status on public.iso13485_qms_capa_actions_r3645(capa_status);

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

  -- 16 internal-audit clause rows
  insert into public.iso13485_qms_r3645 (
    organization_id, audit_ref, clause_ref, process_area, period_month,
    audits_done, findings_raised, major_nc, minor_nc, observations,
    closure_pct, avg_closure_days, audit_date, next_audit_due,
    nc_severity, audit_status, trend_dir, notes
  )
  select v_org_id, q.aref, q.clref, q.parea, q.pmonth::date,
    q.adone, q.fraised, q.majnc, q.minnc, q.obsv,
    q.cpct, q.avgcd, q.adate::date, q.naud::date,
    q.sev, q.astat, q.tdir, q.nt
  from (values
    ('IA-2026-01','4.2.4','document_control','2026-01-01',
     3,5,0,2,3,100.0,12.5,'2026-01-15','2026-07-15','minor_nc','closed','improving',
     'Document control audit — obsolete SOP copies at ventilator line withdrawn; all NCs closed'),
    ('IA-2026-02','7.4.1','purchasing_supplier','2026-01-01',
     2,4,1,1,2,75.0,28.0,'2026-01-20','2026-07-20','major_nc','in_progress','stable',
     'Supplier control — unapproved vendor used for infusion-pump pressure sensor sourcing'),
    ('IA-2026-03','7.6','calibration_metrology','2026-02-01',
     4,6,0,3,3,83.0,15.0,'2026-02-10','2026-08-10','minor_nc','verification_pending','improving',
     'Calibration control — 3 torque gauges past due; recall and recalibration underway'),
    ('IA-2026-04','7.5.7','sterilization_validation','2026-02-01',
     2,3,1,1,1,60.0,40.0,'2026-02-18','2026-08-18','major_nc','overdue','worsening',
     'EO sterilization revalidation overdue on dialysis-line cycle B — bioburden data pending'),
    ('IA-2026-05','7.3','design_development','2026-03-01',
     3,4,0,2,2,90.0,18.0,'2026-03-05','2026-09-05','minor_nc','closed','improving',
     'Design change control — DHF updates for patient-monitor v2 verified and released'),
    ('IA-2026-06','8.2.4','complaint_handling','2026-03-01',
     2,5,1,2,2,70.0,33.0,'2026-03-22','2026-09-22','major_nc','escalated','worsening',
     'Complaint handling — defibrillator field complaint MDR decision delayed beyond timeline'),
    ('IA-2026-07','7.5.6','production_process','2026-04-01',
     3,4,0,1,3,88.0,16.0,'2026-04-08','2026-10-08','observation','in_progress','stable',
     'Production process validation — C-arm assembly line IQ/OQ records incomplete'),
    ('IA-2026-08','8.5.2','capa_management','2026-04-01',
     2,3,0,1,2,95.0,10.0,'2026-04-19','2026-10-19','minor_nc','closed','improving',
     'CAPA management — corrective-action effectiveness checks now evidenced; NC closed'),
    ('IA-2026-09','8.2.2','internal_audit','2026-05-01',
     1,2,0,0,2,100.0,8.0,'2026-05-06','2026-11-06','ofi','closed','stable',
     'Internal audit programme — auditor independence matrix updated; OFIs logged'),
    ('IA-2026-10','7.1','risk_management','2026-05-01',
     2,4,1,1,2,65.0,30.0,'2026-05-21','2026-11-21','major_nc','overdue','worsening',
     'Risk management — ISO 14971 risk file for ICU ventilator not updated post design change'),
    ('IA-2026-11','6.2','training_competence','2026-06-01',
     3,3,0,2,1,92.0,14.0,'2026-06-04','2026-12-04','minor_nc','verification_pending','improving',
     'Training and competence — operator requalification records lagging on sterilization line'),
    ('IA-2026-12','8.3','nonconforming_product','2026-06-01',
     2,4,1,2,1,78.0,22.0,'2026-06-17','2026-12-17','major_nc','in_progress','stable',
     'Nonconforming product — quarantine segregation gap in infusion-pump reject area'),
    ('IA-2026-13','4.2.5','records_control','2026-06-01',
     2,2,0,0,2,100.0,6.0,'2026-06-25','2026-12-25','conformant','closed','improving',
     'Records control — DHR retention and retrievability verified conformant'),
    ('IA-2026-14','5.6','management_review','2026-07-01',
     1,1,0,0,1,100.0,5.0,'2026-07-02','2027-01-02','ofi','closed','stable',
     'Management review — quality objectives tracked; one OFI on supplier KPI dashboard'),
    ('IA-2026-15','7.5.8','traceability_identification','2026-07-01',
     3,5,1,2,2,60.0,26.0,'2026-07-09','2027-01-09','major_nc','escalated','worsening',
     'Traceability — UDI and lot-trace break on defibrillator battery sub-assembly'),
    ('IA-2026-16','7.6','calibration_metrology','2026-07-01',
     4,3,0,1,2,85.0,13.0,'2026-07-14','2027-01-14','minor_nc','in_progress','improving',
     'Calibration control — reference standard traceability certificates being re-filed')
  ) as q(aref, clref, parea, pmonth, adone, fraised, majnc, minnc, obsv, cpct, avgcd, adate, naud, sev, astat, tdir, nt);

  -- CAPA seed — attach to specific audits via audit_ref
  insert into public.iso13485_qms_capa_actions_r3645 (
    audit_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('IA-2026-02','supplier_control_gap','supplier_quality_issue','supplier_requalification','in_progress','iso_13485_major_nc','Priya Nair (QA)','2026-02-28',null,85000.00,'Vendor requalification and incoming inspection plan for sensor supplier'),
    ('IA-2026-04','process_validation_gap','process_drift','revalidate_process','overdue','certification_risk','Rahul Menon (Production)','2026-03-20',null,140000.00,'EO cycle B revalidation past target — external lab bioburden delay'),
    ('IA-2026-06','complaint_handling_delay','inadequate_procedure','revise_sop','escalated','mdr_notifiable','Anita Rao (Regulatory)','2026-04-15',null,60000.00,'Complaint-to-MDR SOP timelines revised; escalated for vigilance filing'),
    ('IA-2026-03','calibration_record_gap','measurement_system_error','schedule_reaudit','verification_pending','iso_13485_minor_nc','Suresh Kumar (Metrology)','2026-03-05',null,42000.00,'Overdue gauges recalibrated; re-audit scheduled to verify closure'),
    ('IA-2026-10','risk_management_gap','management_review_gap','update_risk_file','overdue','certification_risk','Anita Rao (Regulatory)','2026-06-10',null,75000.00,'ISO 14971 risk file for ventilator to be updated post design change'),
    ('IA-2026-12','capa_ineffectiveness','pending_investigation','implement_capa_tracking','in_progress','iso_13485_major_nc','Priya Nair (QA)','2026-07-05',null,30000.00,'Quarantine segregation controls and CAPA tracking board rolled out'),
    ('IA-2026-15','traceability_gap','insufficient_training','retrain_staff','escalated','iso_13485_major_nc','Deepa Iyer (Stores)','2026-07-25',null,25000.00,'UDI/lot-trace training and scan verification at battery sub-assembly'),
    ('IA-2026-01','document_control_gap','documentation_error','strengthen_document_control','closed','internal_only','Ravi Shankar (Doc Control)','2026-02-01','2026-01-28',15000.00,'Obsolete SOP withdrawal and master list update completed and verified'),
    ('IA-2026-05','design_control_gap','system_configuration_gap','revise_sop','closed','iso_13485_minor_nc','Karthik Reddy (R&D)','2026-03-30','2026-03-25',48000.00,'DHF change-control SOP revised; monitor v2 design outputs re-verified')
  ) as q(aref, fc, rc, ca, cst, ri, ownr, tcd, acd, cost, nt)
  join public.iso13485_qms_r3645 e
    on e.organization_id = v_org_id and e.audit_ref = q.aref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit status distribution
create or replace function public.founder_r3645_audit_status_rollup()
returns table(audit_status text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.iso13485_qms_r3645)
  select l.audit_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.iso13485_qms_r3645 l
  group by l.audit_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3645_audit_status_rollup() from public, anon;
grant execute on function public.founder_r3645_audit_status_rollup() to authenticated;

-- 2) Process-area scorecard
create or replace function public.founder_r3645_process_area_scorecard()
returns table(
  process_area text,
  audits bigint,
  findings_raised bigint,
  major_nc bigint,
  minor_nc bigint,
  observations bigint,
  avg_closure_pct numeric,
  avg_closure_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.process_area,
    count(*)::bigint,
    coalesce(sum(l.findings_raised),0)::bigint,
    coalesce(sum(l.major_nc),0)::bigint,
    coalesce(sum(l.minor_nc),0)::bigint,
    coalesce(sum(l.observations),0)::bigint,
    round(avg(l.closure_pct), 1),
    round(avg(l.avg_closure_days), 1)
  from public.iso13485_qms_r3645 l
  group by l.process_area
  order by coalesce(sum(l.findings_raised),0) desc;
end;
$$;

revoke execute on function public.founder_r3645_process_area_scorecard() from public, anon;
grant execute on function public.founder_r3645_process_area_scorecard() to authenticated;

-- 3) Process-area × NC-severity matrix
create or replace function public.founder_r3645_process_area_severity_matrix()
returns table(process_area text, nc_severity text, audits bigint, findings_raised bigint, avg_closure_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.process_area, l.nc_severity, count(*)::bigint,
    coalesce(sum(l.findings_raised),0)::bigint,
    round(avg(l.closure_pct), 1)
  from public.iso13485_qms_r3645 l
  group by l.process_area, l.nc_severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3645_process_area_severity_matrix() from public, anon;
grant execute on function public.founder_r3645_process_area_severity_matrix() to authenticated;

-- 4) Monthly finding trend
create or replace function public.founder_r3645_monthly_finding_trend()
returns table(
  period_month date,
  audits bigint,
  findings_raised bigint,
  major_nc bigint,
  minor_nc bigint,
  observations bigint,
  avg_closure_pct numeric
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
    coalesce(sum(l.findings_raised),0)::bigint,
    coalesce(sum(l.major_nc),0)::bigint,
    coalesce(sum(l.minor_nc),0)::bigint,
    coalesce(sum(l.observations),0)::bigint,
    round(avg(l.closure_pct), 1)
  from public.iso13485_qms_r3645 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3645_monthly_finding_trend() from public, anon;
grant execute on function public.founder_r3645_monthly_finding_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3645_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.iso13485_qms_capa_actions_r3645 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3645_capa_status_board() from public, anon;
grant execute on function public.founder_r3645_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3645_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.iso13485_qms_capa_actions_r3645)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.iso13485_qms_capa_actions_r3645 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3645_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3645_root_cause_pareto() to authenticated;

-- 7) NC regulatory-impact digest
create or replace function public.founder_r3645_nc_impact_digest()
returns table(regulatory_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
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
  from public.iso13485_qms_capa_actions_r3645 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3645_nc_impact_digest() from public, anon;
grant execute on function public.founder_r3645_nc_impact_digest() to authenticated;

-- 8) High-risk audit queue (overdue / escalated / major NC / worsening)
create or replace function public.founder_r3645_high_risk_queue()
returns table(
  audit_ref text,
  clause_ref text,
  process_area text,
  period_month date,
  audit_date date,
  nc_severity text,
  audit_status text,
  major_nc int,
  minor_nc int,
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
  select l.audit_ref, l.clause_ref, l.process_area, l.period_month, l.audit_date,
    l.nc_severity, l.audit_status, l.major_nc, l.minor_nc, l.trend_dir, l.notes
  from public.iso13485_qms_r3645 l
  where l.audit_status in ('overdue','escalated')
     or l.nc_severity = 'major_nc'
     or l.trend_dir = 'worsening'
     or l.major_nc > 0
  order by l.audit_date desc, l.audit_ref;
end;
$$;

revoke execute on function public.founder_r3645_high_risk_queue() from public, anon;
grant execute on function public.founder_r3645_high_risk_queue() to authenticated;
