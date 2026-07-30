-- Round 3648: Medical-Device Clinical-Evaluation-Report (CER) Evidence Board
-- CER clinical-evidence sufficiency — device class × evidence route × clinical data sources × literature refs × PMCF studies × evidence sufficiency % × residual risks × equivalence × CER due × CAPA

-- =============================================================================
-- TABLE 1: cer_r3648 — per-device CER clinical-evidence sufficiency records
-- =============================================================================
create table if not exists public.cer_r3648 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  device_name text not null,
  cer_ref text not null,
  device_class text not null,
  period_month date not null,
  clinical_data_sources int,
  literature_refs int,
  pmcf_studies int,
  evidence_sufficiency_pct numeric(5,2),
  residual_risks_open int,
  cer_date date,
  cer_update_due date,
  equivalence_claimed boolean not null,
  evidence_route text not null check (evidence_route in (
    'own_clinical','literature','equivalence','pmcf','clinical_investigation'
  )),
  cer_status text not null check (cer_status in (
    'sufficient','update_due','evidence_gap','under_review','insufficient'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cer_r3648 enable row level security;

create index if not exists idx_cer_r3648_org on public.cer_r3648(organization_id);
create index if not exists idx_cer_r3648_month on public.cer_r3648(period_month);
create index if not exists idx_cer_r3648_status on public.cer_r3648(cer_status);

-- =============================================================================
-- TABLE 2: cer_capa_actions_r3648 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cer_capa_actions_r3648 (
  id uuid primary key default gen_random_uuid(),
  cer_id uuid not null references public.cer_r3648(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'insufficient_clinical_data','literature_search_outdated','pmcf_plan_missing',
    'pmcf_data_overdue','equivalence_not_justified','residual_risk_unresolved',
    'cer_update_overdue','benefit_risk_not_demonstrated','sota_not_addressed','post_market_data_gap'
  )),
  root_cause text not null check (root_cause in (
    'limited_clinical_investigation','no_pmcf_activities','weak_equivalence_evidence',
    'outdated_literature_review','incomplete_risk_analysis','insufficient_real_world_data',
    'resource_constraint','vendor_data_delay','regulatory_scope_change','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'conduct_clinical_investigation','initiate_pmcf_study','update_literature_review',
    'strengthen_equivalence_rationale','update_risk_analysis','collect_real_world_data',
    'engage_notified_body','revise_cer','escalate_to_management','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'mdr_nonconformity','cdsco_notifiable','notified_body_finding','iso_13485_deviation',
    'internal_only','none','patient_safety_signal'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cer_capa_actions_r3648 enable row level security;

create index if not exists idx_cer_capa_r3648_cer on public.cer_capa_actions_r3648(cer_id);
create index if not exists idx_cer_capa_r3648_status on public.cer_capa_actions_r3648(capa_status);

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

  -- 16 CER records
  insert into public.cer_r3648 (
    organization_id, device_name, cer_ref, device_class, period_month,
    clinical_data_sources, literature_refs, pmcf_studies, evidence_sufficiency_pct, residual_risks_open,
    cer_date, cer_update_due, equivalence_claimed, evidence_route, cer_status, trend_dir, notes
  )
  select v_org_id, q.dname, q.cref, q.dclass, q.pmonth::date,
    q.cds, q.litr, q.pmcf, q.evsuf, q.rrisk,
    q.cdate::date, q.cdue::date, q.equiv, q.route, q.cst, q.trnd, q.nt
  from (values
    ('ICU Ventilator V500','CER-VENT-01','class_c','2026-07-01',
     6,42,2,92.0,1,'2025-11-15','2027-11-15',false,'own_clinical','sufficient','improving','CER backed by own clinical data and PMS; residual risk acceptable'),
    ('Infusion Pump IP-200','CER-INF-02','class_c','2026-07-01',
     4,28,1,74.5,3,'2024-09-10','2026-09-10',false,'pmcf','update_due','stable','PMCF ongoing; CER update due within 60 days'),
    ('Patient Monitor PM-12','CER-MON-03','class_b','2026-07-01',
     3,35,0,88.0,1,'2025-06-20','2027-06-20',true,'equivalence','sufficient','stable','Equivalence to predicate monitor justified; literature adequate'),
    ('Dialysis Machine DX-9','CER-DIAL-04','class_c','2026-07-01',
     5,18,1,61.0,5,'2024-03-05','2026-03-05',false,'literature','evidence_gap','worsening','Literature-only route with high residual risks; PMCF plan missing'),
    ('Defibrillator DF-360','CER-DEF-05','class_c','2026-07-01',
     7,50,3,95.0,0,'2026-01-12','2028-01-12',false,'own_clinical','sufficient','improving','Strong clinical evidence base; all residual risks closed'),
    ('Mobile C-Arm CA-7','CER-CARM-06','class_c','2026-06-01',
     2,12,0,48.0,6,'2023-08-01','2025-08-01',true,'equivalence','insufficient','worsening','Equivalence poorly justified and CER update overdue — insufficient'),
    ('Syringe Pump SP-50','CER-SYR-07','class_c','2026-06-01',
     4,22,1,70.0,2,'2025-02-18','2027-02-18',false,'pmcf','under_review','stable','Under notified-body review; PMCF interim data submitted'),
    ('Anesthesia Workstation AW-8','CER-ANES-08','class_c','2026-06-01',
     6,40,2,90.0,1,'2025-10-01','2027-10-01',false,'own_clinical','sufficient','stable','Own clinical plus literature sufficient; minor residual risk tracked'),
    ('ECG Machine EC-6','CER-ECG-09','class_b','2026-06-01',
     3,30,0,85.0,1,'2025-05-22','2027-05-22',true,'equivalence','sufficient','improving','Equivalence route accepted; SOTA addressed'),
    ('Pulse Oximeter PO-3','CER-OXI-10','class_b','2026-06-01',
     2,25,0,80.0,1,'2025-12-05','2027-12-05',true,'literature','update_due','stable','Literature current but update cycle due'),
    ('Surgical Diathermy SD-4','CER-DIA-11','class_c','2026-05-01',
     4,20,1,66.0,4,'2024-07-30','2026-07-30',false,'clinical_investigation','evidence_gap','worsening','Clinical investigation incomplete; benefit-risk not fully demonstrated'),
    ('Ultrasound Scanner US-15','CER-USG-12','class_b','2026-05-01',
     5,38,1,89.0,1,'2025-09-14','2027-09-14',true,'equivalence','sufficient','stable','Equivalence and literature sufficient for Class B'),
    ('Portable X-Ray PX-2','CER-XRAY-13','class_c','2026-05-01',
     3,16,0,55.0,5,'2023-11-20','2025-11-20',true,'literature','insufficient','worsening','CER long overdue, literature-only, high residual risk — insufficient'),
    ('BiPAP Ventilator BP-30','CER-BIPAP-14','class_b','2026-05-01',
     4,26,1,78.0,2,'2025-03-11','2027-03-11',false,'pmcf','under_review','improving','PMCF study enrolling; interim results promising'),
    ('Implantable Pacemaker PC-D1','CER-PACE-15','class_d','2026-07-01',
     9,60,4,93.0,1,'2026-02-01','2027-02-01',false,'own_clinical','sufficient','improving','Class D — robust clinical investigation and PMCF registry'),
    ('Drug-Eluting Stent DES-D2','CER-STENT-16','class_d','2026-06-01',
     5,45,2,63.0,6,'2024-05-15','2026-05-15',false,'clinical_investigation','evidence_gap','worsening','Class D high risk; PMCF data overdue and residual risks open')
  ) as q(dname, cref, dclass, pmonth, cds, litr, pmcf, evsuf, rrisk, cdate, cdue, equiv, route, cst, trnd, nt);

  -- CAPA seed — attach to specific CERs via cer_ref
  insert into public.cer_capa_actions_r3648 (
    cer_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CER-DIAL-04','pmcf_plan_missing','no_pmcf_activities','initiate_pmcf_study','in_progress','mdr_nonconformity','2026-09-30',null,250000.00,'PMCF study protocol drafted for dialysis machine evidence gap'),
    ('CER-CARM-06','cer_update_overdue','regulatory_scope_change','revise_cer','escalated','notified_body_finding','2026-08-31',null,180000.00,'C-arm CER overdue 12 months — escalated to management'),
    ('CER-XRAY-13','benefit_risk_not_demonstrated','weak_equivalence_evidence','strengthen_equivalence_rationale','open','cdsco_notifiable','2026-10-15',null,120000.00,'Portable X-ray equivalence rationale insufficient'),
    ('CER-STENT-16','pmcf_data_overdue','vendor_data_delay','collect_real_world_data','overdue','patient_safety_signal','2026-07-20',null,500000.00,'Class D stent PMCF registry data overdue — high priority'),
    ('CER-DIA-11','residual_risk_unresolved','incomplete_risk_analysis','update_risk_analysis','verification_pending','iso_13485_deviation','2026-08-10',null,90000.00,'Diathermy residual risk analysis updated — verifying closure'),
    ('CER-INF-02','literature_search_outdated','outdated_literature_review','update_literature_review','closed','internal_only','2026-06-30','2026-06-25',60000.00,'Infusion pump literature refresh completed and CER updated'),
    ('CER-SYR-07','sota_not_addressed','regulatory_scope_change','engage_notified_body','in_progress','notified_body_finding','2026-09-05',null,75000.00,'Syringe pump SOTA gap raised during NB review'),
    ('CER-BIPAP-14','insufficient_clinical_data','limited_clinical_investigation','initiate_pmcf_study','open','mdr_nonconformity','2026-10-01',null,140000.00,'BiPAP PMCF enrollment to close clinical data gap'),
    ('CER-OXI-10','cer_update_overdue','resource_constraint','revise_cer','closed','none','2026-06-15','2026-06-12',30000.00,'Pulse oximeter CER refreshed ahead of due date')
  ) as q(cref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cer_r3648 e
    on e.organization_id = v_org_id and e.cer_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) CER status distribution
create or replace function public.founder_r3648_cer_status_rollup()
returns table(cer_status text, cers bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cer_r3648)
  select l.cer_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cer_r3648 l
  group by l.cer_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3648_cer_status_rollup() from public, anon;
grant execute on function public.founder_r3648_cer_status_rollup() to authenticated;

-- 2) Device-class scorecard
create or replace function public.founder_r3648_device_class_scorecard()
returns table(
  device_class text,
  total_cers bigint,
  sufficient bigint,
  update_due bigint,
  evidence_gap bigint,
  insufficient bigint,
  equivalence_cers bigint,
  avg_evidence_sufficiency_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_class,
    count(*)::bigint,
    count(*) filter (where l.cer_status = 'sufficient')::bigint,
    count(*) filter (where l.cer_status = 'update_due')::bigint,
    count(*) filter (where l.cer_status = 'evidence_gap')::bigint,
    count(*) filter (where l.cer_status = 'insufficient')::bigint,
    count(*) filter (where l.equivalence_claimed = true)::bigint,
    round(avg(l.evidence_sufficiency_pct), 1)
  from public.cer_r3648 l
  group by l.device_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3648_device_class_scorecard() from public, anon;
grant execute on function public.founder_r3648_device_class_scorecard() to authenticated;

-- 3) Evidence-route × CER-status matrix
create or replace function public.founder_r3648_route_status_matrix()
returns table(evidence_route text, cer_status text, cers bigint, avg_evidence_sufficiency_pct numeric, total_residual_risks bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.evidence_route, l.cer_status, count(*)::bigint,
    round(avg(l.evidence_sufficiency_pct), 1),
    coalesce(sum(l.residual_risks_open),0)::bigint
  from public.cer_r3648 l
  group by l.evidence_route, l.cer_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3648_route_status_matrix() from public, anon;
grant execute on function public.founder_r3648_route_status_matrix() to authenticated;

-- 4) Monthly CER trend
create or replace function public.founder_r3648_monthly_cer_trend()
returns table(period_month date, cers bigint, sufficient bigint, gap_or_insufficient bigint, avg_evidence_sufficiency_pct numeric, total_residual_risks bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.cer_status = 'sufficient')::bigint,
    count(*) filter (where l.cer_status in ('evidence_gap','insufficient'))::bigint,
    round(avg(l.evidence_sufficiency_pct), 1),
    coalesce(sum(l.residual_risks_open),0)::bigint
  from public.cer_r3648 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3648_monthly_cer_trend() from public, anon;
grant execute on function public.founder_r3648_monthly_cer_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3648_capa_status_board()
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
  from public.cer_capa_actions_r3648 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3648_capa_status_board() from public, anon;
grant execute on function public.founder_r3648_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3648_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cer_capa_actions_r3648)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cer_capa_actions_r3648 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3648_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3648_root_cause_pareto() to authenticated;

-- 7) Evidence-gap digest (by evidence route)
create or replace function public.founder_r3648_evidence_gap_digest()
returns table(evidence_route text, cers bigint, gap_or_insufficient bigint, avg_evidence_sufficiency_pct numeric, total_residual_risks_open bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.evidence_route,
    count(*)::bigint,
    count(*) filter (where l.cer_status in ('evidence_gap','insufficient'))::bigint,
    round(avg(l.evidence_sufficiency_pct), 1),
    coalesce(sum(l.residual_risks_open),0)::bigint
  from public.cer_r3648 l
  group by l.evidence_route
  order by count(*) filter (where l.cer_status in ('evidence_gap','insufficient')) desc;
end;
$$;

revoke execute on function public.founder_r3648_evidence_gap_digest() from public, anon;
grant execute on function public.founder_r3648_evidence_gap_digest() to authenticated;

-- 8) High-risk CER queue (insufficient / evidence_gap and other concerns)
create or replace function public.founder_r3648_high_risk_queue()
returns table(
  device_name text,
  cer_ref text,
  device_class text,
  period_month date,
  cer_status text,
  evidence_route text,
  evidence_sufficiency_pct numeric,
  residual_risks_open int,
  cer_update_due date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name, l.cer_ref, l.device_class, l.period_month,
    l.cer_status, l.evidence_route, l.evidence_sufficiency_pct, l.residual_risks_open,
    l.cer_update_due, l.notes
  from public.cer_r3648 l
  where l.cer_status in ('evidence_gap','insufficient','update_due','under_review')
     or l.evidence_sufficiency_pct < 70
     or l.residual_risks_open >= 3
     or l.trend_dir = 'worsening'
  order by l.evidence_sufficiency_pct asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3648_high_risk_queue() from public, anon;
grant execute on function public.founder_r3648_high_risk_queue() to authenticated;
