-- Round 3657: Founder Approved-Supplier Qualification / Audit (AVL) Board
-- Supplier quality — supply category × qualification tier × audit status × requal window × audit score × OTD × lot rejection × SCARs × trend × CAPA

-- =============================================================================
-- TABLE 1: supplier_qual_r3657 — per-supplier AVL qualification & audit lifecycle
-- =============================================================================
create table if not exists public.supplier_qual_r3657 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_code text not null,
  supplier_name text not null,
  supply_category text not null,
  period_month date not null,
  qualification_date date not null,
  requalification_due date not null,
  days_to_requal int not null,
  last_audit_score numeric(5,1),
  audit_findings_open int not null default 0,
  on_time_delivery_pct numeric(5,1),
  lot_rejection_pct numeric(5,2),
  scar_open int not null default 0,
  qualification_tier text not null check (qualification_tier in (
    'approved','conditional','probation','disqualified','new_pending'
  )),
  audit_status text not null check (audit_status in (
    'current','requal_due','audit_overdue','findings_open','suspended'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.supplier_qual_r3657 enable row level security;

create index if not exists idx_supplier_qual_r3657_org on public.supplier_qual_r3657(organization_id);
create index if not exists idx_supplier_qual_r3657_month on public.supplier_qual_r3657(period_month);
create index if not exists idx_supplier_qual_r3657_status on public.supplier_qual_r3657(audit_status);

-- =============================================================================
-- TABLE 2: supplier_qual_capa_actions_r3657 — supplier CAPA & SCAR actions
-- =============================================================================
create table if not exists public.supplier_qual_capa_actions_r3657 (
  id uuid primary key default gen_random_uuid(),
  supplier_qual_id uuid not null references public.supplier_qual_r3657(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'audit_major_nc','audit_minor_nc','lot_rejection_spike','late_delivery_trend',
    'scar_unanswered','requalification_lapse','document_expiry','process_change_unnotified'
  )),
  root_cause text not null check (root_cause in (
    'process_control_gap','incoming_material_variation','tooling_wear','operator_training_gap',
    'documentation_lapse','capacity_overload','sub_supplier_issue','pending_investigation',
    'quality_system_gap','logistics_partner_failure'
  )),
  corrective_action text not null check (corrective_action in (
    'process_revalidation','supplier_retraining','tooling_replacement','increase_incoming_inspection',
    'dual_source_activation','quality_agreement_update','on_site_surveillance_audit',
    'downgrade_to_conditional','suspend_and_disqualify','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  rejection_impact text not null check (rejection_impact in (
    'lot_recall','line_stoppage','increased_inspection','rework_only','customer_complaint','none'
  )),
  capa_owner text not null,
  target_closure_date date,
  actual_closure_date date,
  rejection_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.supplier_qual_capa_actions_r3657 enable row level security;

create index if not exists idx_supplier_qual_capa_r3657_link on public.supplier_qual_capa_actions_r3657(supplier_qual_id);
create index if not exists idx_supplier_qual_capa_r3657_status on public.supplier_qual_capa_actions_r3657(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit status distribution
create or replace function public.founder_r3657_audit_status_rollup()
returns table(audit_status text, suppliers bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.supplier_qual_r3657)
  select s.audit_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.supplier_qual_r3657 s
  group by s.audit_status
  order by count(*) desc;
end;
$$;

-- 2) Supply-category scorecard
create or replace function public.founder_r3657_supply_category_scorecard()
returns table(
  supply_category text,
  suppliers bigint,
  approved bigint,
  conditional_or_probation bigint,
  suspended_or_disqualified bigint,
  avg_audit_score numeric,
  avg_on_time_delivery_pct numeric,
  avg_lot_rejection_pct numeric,
  open_findings bigint,
  open_scars bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.supply_category,
    count(*)::bigint,
    count(*) filter (where s.qualification_tier = 'approved')::bigint,
    count(*) filter (where s.qualification_tier in ('conditional','probation'))::bigint,
    count(*) filter (where s.qualification_tier = 'disqualified' or s.audit_status = 'suspended')::bigint,
    round(avg(s.last_audit_score), 1),
    round(avg(s.on_time_delivery_pct), 1),
    round(avg(s.lot_rejection_pct), 2),
    coalesce(sum(s.audit_findings_open),0)::bigint,
    coalesce(sum(s.scar_open),0)::bigint
  from public.supplier_qual_r3657 s
  group by s.supply_category
  order by count(*) desc;
end;
$$;

-- 3) Qualification tier × audit status matrix
create or replace function public.founder_r3657_tier_audit_status_matrix()
returns table(qualification_tier text, audit_status text, suppliers bigint, avg_audit_score numeric, findings_open bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.qualification_tier, s.audit_status, count(*)::bigint,
    round(avg(s.last_audit_score), 1),
    coalesce(sum(s.audit_findings_open),0)::bigint
  from public.supplier_qual_r3657 s
  group by s.qualification_tier, s.audit_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly audit trend
create or replace function public.founder_r3657_monthly_audit_trend()
returns table(
  period_month date,
  suppliers bigint,
  requal_due bigint,
  audit_overdue bigint,
  avg_audit_score numeric,
  avg_on_time_delivery_pct numeric,
  avg_lot_rejection_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.period_month,
    count(*)::bigint,
    count(*) filter (where s.audit_status = 'requal_due')::bigint,
    count(*) filter (where s.audit_status = 'audit_overdue')::bigint,
    round(avg(s.last_audit_score), 1),
    round(avg(s.on_time_delivery_pct), 1),
    round(avg(s.lot_rejection_pct), 2)
  from public.supplier_qual_r3657 s
  group by s.period_month
  order by s.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3657_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.rejection_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.supplier_qual_capa_actions_r3657 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3657_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.supplier_qual_capa_actions_r3657)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.rejection_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.supplier_qual_capa_actions_r3657 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Rejection-impact digest
create or replace function public.founder_r3657_rejection_impact_digest()
returns table(rejection_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.rejection_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.rejection_cost_rupees),0)::numeric
  from public.supplier_qual_capa_actions_r3657 c
  group by c.rejection_impact
  order by count(*) desc;
end;
$$;

-- 8) High-risk supplier queue (suspended / audit overdue / heavy findings)
create or replace function public.founder_r3657_high_risk_queue()
returns table(
  supplier_code text,
  supplier_name text,
  supply_category text,
  period_month date,
  qualification_tier text,
  audit_status text,
  trend_dir text,
  last_audit_score numeric,
  audit_findings_open int,
  scar_open int,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.supplier_code, s.supplier_name, s.supply_category, s.period_month,
    s.qualification_tier, s.audit_status, s.trend_dir,
    s.last_audit_score, s.audit_findings_open, s.scar_open, s.notes
  from public.supplier_qual_r3657 s
  where s.audit_status in ('suspended','audit_overdue')
     or s.qualification_tier in ('probation','disqualified')
     or s.audit_findings_open >= 2
     or s.scar_open >= 2
     or s.lot_rejection_pct >= 3.0
     or s.trend_dir = 'worsening'
  order by s.period_month desc, s.supplier_name;
end;
$$;

-- =============================================================================
-- Grants
-- =============================================================================
revoke all on function public.founder_r3657_audit_status_rollup() from public, anon;
revoke all on function public.founder_r3657_supply_category_scorecard() from public, anon;
revoke all on function public.founder_r3657_tier_audit_status_matrix() from public, anon;
revoke all on function public.founder_r3657_monthly_audit_trend() from public, anon;
revoke all on function public.founder_r3657_capa_status_board() from public, anon;
revoke all on function public.founder_r3657_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3657_rejection_impact_digest() from public, anon;
revoke all on function public.founder_r3657_high_risk_queue() from public, anon;

grant execute on function public.founder_r3657_audit_status_rollup() to authenticated;
grant execute on function public.founder_r3657_supply_category_scorecard() to authenticated;
grant execute on function public.founder_r3657_tier_audit_status_matrix() to authenticated;
grant execute on function public.founder_r3657_monthly_audit_trend() to authenticated;
grant execute on function public.founder_r3657_capa_status_board() to authenticated;
grant execute on function public.founder_r3657_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3657_rejection_impact_digest() to authenticated;
grant execute on function public.founder_r3657_high_risk_queue() to authenticated;

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

  -- 15 supplier qualification rows
  insert into public.supplier_qual_r3657 (
    organization_id, supplier_code, supplier_name, supply_category, period_month,
    qualification_date, requalification_due, days_to_requal, last_audit_score,
    audit_findings_open, on_time_delivery_pct, lot_rejection_pct, scar_open,
    qualification_tier, audit_status, trend_dir, notes
  )
  select v_org_id, q.scode, q.sname, q.cat, q.pmon::date,
    q.qdate::date, q.rqdue::date, q.dtr, q.ascore,
    q.afo, q.otd, q.lrej, q.scar,
    q.tier, q.ast, q.trd, q.nt
  from (values
    ('SUP-001','SFO Technologies Kochi','electronic_assemblies','2026-07-01',
     '2025-08-12','2026-08-12',41,92.5,0,98.4,0.40,0,'approved','current','stable','ISO 13485 certified EMS partner — clean surveillance audit'),
    ('SUP-002','Sahasra Electronics Noida','electronic_assemblies','2026-07-01',
     '2025-03-20','2026-09-20',80,88.0,1,96.1,0.90,1,'approved','findings_open','improving','One minor NC on solder-paste storage logs — SCAR in verification'),
    ('SUP-003','Shaily Engineering Plastics Vadodara','plastics_tubing','2026-07-01',
     '2024-11-05','2026-07-20',18,90.2,0,97.8,0.60,0,'approved','requal_due','stable','Requalification audit scheduled within three weeks'),
    ('SUP-004','Polymed Medicure Faridabad','plastics_tubing','2026-07-01',
     '2025-01-15','2027-01-15',166,85.4,2,93.2,2.10,1,'conditional','findings_open','worsening','Lot rejection creeping up on IV tubing extrusion lots'),
    ('SUP-005','Precision Sensors Pune','sensors_transducers','2026-07-01',
     '2024-06-10','2026-06-10',-22,78.6,3,90.5,3.40,2,'probation','audit_overdue','worsening','Requal audit overdue — pressure-sensor drift complaints from field'),
    ('SUP-006','Sterimed Sterilization Gurugram','sterilization_services','2026-07-01',
     '2025-10-01','2026-10-01',91,94.1,0,99.0,0.20,0,'approved','current','improving','EO sterilization validation records exemplary'),
    ('SUP-007','Accurate Calibration Labs Bengaluru','calibration_services','2026-07-01',
     '2025-05-18','2026-11-18',139,91.0,0,97.2,0.00,0,'approved','current','stable','NABL 17025 scope covers all test instruments used'),
    ('SUP-008','Meditek Metal Works Coimbatore','sheet_metal_enclosures','2026-06-01',
     '2024-12-08','2026-12-08',158,82.3,2,88.7,4.20,2,'conditional','findings_open','worsening','Powder-coat adhesion failures on trolley enclosures'),
    ('SUP-009','BlueWave Software Chennai','software_services','2026-06-01',
     '2025-07-22','2026-07-22',20,89.5,1,100.0,0.00,0,'approved','requal_due','stable','SaMD module vendor — requalification due this month'),
    ('SUP-010','Krishna Packaging Ahmedabad','packaging_labels','2026-06-01',
     '2025-02-14','2027-02-14',196,87.2,1,95.6,1.20,1,'approved','findings_open','stable','Label mix-up near-miss at incoming — SCAR open'),
    ('SUP-011','Omega Castings Rajkot','raw_materials','2026-06-01',
     '2023-09-30','2026-03-30',-94,64.8,5,81.3,7.80,3,'disqualified','suspended','worsening','Suspended after repeat major NCs and unnotified process change'),
    ('SUP-012','NeoLife Contract Mfg Hyderabad','contract_manufacturing','2026-06-01',
     '2026-04-02','2027-04-02',243,86.9,1,94.4,1.50,1,'new_pending','findings_open','improving','New contract manufacturer under first-article qualification'),
    ('SUP-013','Vector Transducers Mumbai','sensors_transducers','2026-05-01',
     '2025-06-25','2026-06-25',-37,74.2,4,87.9,5.60,2,'probation','audit_overdue','worsening','SpO2 probe connector failures — on-site audit pending'),
    ('SUP-014','GreenLeaf Polymers Daman','raw_materials','2026-05-01',
     '2025-09-12','2026-09-12',41,90.8,0,96.7,0.80,0,'approved','current','stable','Medical-grade PVC resin lots consistent across batches'),
    ('SUP-015','Zenith EO Services Vapi','sterilization_services','2026-05-01',
     '2024-08-19','2026-08-19',17,81.5,2,92.1,2.90,1,'conditional','requal_due','stable','Residual EO trending near limit — conditional pending requal')
  ) as q(scode, sname, cat, pmon, qdate, rqdue, dtr, ascore, afo, otd, lrej, scar, tier, ast, trd, nt);

  -- CAPA seed — attach to specific suppliers via supplier_code
  insert into public.supplier_qual_capa_actions_r3657 (
    supplier_qual_id, finding_category, root_cause, corrective_action,
    capa_status, rejection_impact, capa_owner, target_closure_date, actual_closure_date,
    rejection_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.owr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SUP-005','requalification_lapse','quality_system_gap','on_site_surveillance_audit','in_progress','increased_inspection','Ganesh Rao','2026-07-25',null,120000.00,'Surveillance audit booked; 100% incoming inspection as interim control'),
    ('SUP-011','audit_major_nc','process_control_gap','suspend_and_disqualify','closed','line_stoppage','Meera Iyer','2026-06-20','2026-06-18',480000.00,'Supplier suspended; castings moved to alternate approved source'),
    ('SUP-004','lot_rejection_spike','incoming_material_variation','increase_incoming_inspection','open','rework_only','Ganesh Rao','2026-07-30',null,65000.00,'AQL tightened on tubing lots pending supplier root-cause report'),
    ('SUP-008','lot_rejection_spike','tooling_wear','tooling_replacement','escalated','customer_complaint','Sunil Menon','2026-07-15',null,210000.00,'Powder-coat rework complaints from two hospitals — escalated to management review'),
    ('SUP-013','scar_unanswered','sub_supplier_issue','dual_source_activation','overdue','increased_inspection','Meera Iyer','2026-06-30',null,155000.00,'SCAR unanswered 45 days — dual sourcing of SpO2 connectors initiated'),
    ('SUP-010','document_expiry','documentation_lapse','quality_agreement_update','verification_pending','none','Anita Desai','2026-07-20',null,0.00,'Label control SOP updated — verification at next receipt lot'),
    ('SUP-002','audit_minor_nc','operator_training_gap','supplier_retraining','closed','none','Sunil Menon','2026-07-10','2026-07-08',18000.00,'Solder-paste storage retraining completed with objective evidence'),
    ('SUP-015','requalification_lapse','process_control_gap','process_revalidation','in_progress','increased_inspection','Anita Desai','2026-08-05',null,95000.00,'EO cycle revalidation underway; residuals monitored per lot')
  ) as q(scode, fc, rc, ca, cst, ri, owr, tcd, acd, cost, nt)
  join public.supplier_qual_r3657 e
    on e.organization_id = v_org_id and e.supplier_code = q.scode;
end;
$seed$;
