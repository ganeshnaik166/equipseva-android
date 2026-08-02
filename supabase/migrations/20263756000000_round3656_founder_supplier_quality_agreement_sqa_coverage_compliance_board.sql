-- Round 3656: Supplier Quality-Agreement (SQA) Coverage & Compliance Board
-- Supplier quality — SQA signed × effective/expiry currency × change-notification clause × audit-rights clause × spend coverage × open deviations × criticality × CAPA

-- =============================================================================
-- TABLE 1: sqa_coverage_r3656 — per-supplier per-month SQA coverage snapshot
-- =============================================================================
create table if not exists public.sqa_coverage_r3656 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_code text not null,
  supplier_name text not null,
  supply_category text not null,
  period_month date not null,
  sqa_signed boolean not null,
  sqa_effective_date date,
  sqa_expiry_date date,
  days_to_expiry int,
  change_notification_clause boolean not null,
  audit_rights_clause boolean not null,
  spend_covered_pct numeric(5,2) not null default 0,
  open_deviations int not null default 0,
  criticality text not null check (criticality in (
    'critical','major','standard','low_risk'
  )),
  sqa_status text not null check (sqa_status in (
    'current','renewal_due','expired','unsigned','under_negotiation'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.sqa_coverage_r3656 enable row level security;

create index if not exists idx_sqa_coverage_r3656_org on public.sqa_coverage_r3656(organization_id);
create index if not exists idx_sqa_coverage_r3656_month on public.sqa_coverage_r3656(period_month);
create index if not exists idx_sqa_coverage_r3656_status on public.sqa_coverage_r3656(sqa_status);

-- =============================================================================
-- TABLE 2: sqa_coverage_capa_actions_r3656 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.sqa_coverage_capa_actions_r3656 (
  id uuid primary key default gen_random_uuid(),
  sqa_record_id uuid not null references public.sqa_coverage_r3656(id) on delete cascade,
  raised_at timestamptz not null default now(),
  gap_category text not null check (gap_category in (
    'unsigned_agreement','expired_agreement','renewal_window_open',
    'missing_change_notification_clause','missing_audit_rights_clause',
    'low_spend_coverage','open_deviation_backlog','legacy_template'
  )),
  root_cause text not null check (root_cause in (
    'supplier_legal_pushback','ownership_unassigned','renewal_tracking_gap',
    'legacy_template_used','procurement_bypass','supplier_acquisition_transition',
    'resource_constraint','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'execute_new_sqa','renew_agreement','amend_clause','migrate_to_current_template',
    'assign_sqa_owner','implement_renewal_alerts','escalate_to_leadership',
    'supplier_audit_scheduled','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  spend_at_risk_lakh numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.sqa_coverage_capa_actions_r3656 enable row level security;

create index if not exists idx_sqa_coverage_capa_r3656_rec on public.sqa_coverage_capa_actions_r3656(sqa_record_id);
create index if not exists idx_sqa_coverage_capa_r3656_status on public.sqa_coverage_capa_actions_r3656(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) SQA status distribution
create or replace function public.founder_r3656_sqa_status_rollup()
returns table(sqa_status text, suppliers bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sqa_coverage_r3656)
  select l.sqa_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.sqa_coverage_r3656 l
  group by l.sqa_status
  order by count(*) desc;
end;
$$;

-- 2) Supply-category scorecard
create or replace function public.founder_r3656_supply_category_scorecard()
returns table(
  supply_category text,
  suppliers bigint,
  signed_cnt bigint,
  unsigned_cnt bigint,
  expired_cnt bigint,
  renewal_due_cnt bigint,
  avg_spend_covered_pct numeric,
  total_open_deviations bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supply_category,
    count(*)::bigint,
    count(*) filter (where l.sqa_signed = true)::bigint,
    count(*) filter (where l.sqa_status in ('unsigned','under_negotiation'))::bigint,
    count(*) filter (where l.sqa_status = 'expired')::bigint,
    count(*) filter (where l.sqa_status = 'renewal_due')::bigint,
    round(avg(l.spend_covered_pct), 1),
    coalesce(sum(l.open_deviations),0)::bigint
  from public.sqa_coverage_r3656 l
  group by l.supply_category
  order by count(*) desc;
end;
$$;

-- 3) Criticality × SQA-status matrix
create or replace function public.founder_r3656_criticality_status_matrix()
returns table(criticality text, sqa_status text, suppliers bigint, avg_spend_covered_pct numeric, open_deviations bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.criticality, l.sqa_status, count(*)::bigint,
    round(avg(l.spend_covered_pct), 1),
    coalesce(sum(l.open_deviations),0)::bigint
  from public.sqa_coverage_r3656 l
  group by l.criticality, l.sqa_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly coverage trend
create or replace function public.founder_r3656_monthly_coverage_trend()
returns table(period_month date, suppliers bigint, signed_cnt bigint, unsigned_cnt bigint, expired_cnt bigint, avg_spend_covered_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.sqa_signed = true)::bigint,
    count(*) filter (where l.sqa_status in ('unsigned','under_negotiation'))::bigint,
    count(*) filter (where l.sqa_status = 'expired')::bigint,
    round(avg(l.spend_covered_pct), 1)
  from public.sqa_coverage_r3656 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3656_capa_status_board()
returns table(capa_status text, actions bigint, avg_spend_at_risk_lakh numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.spend_at_risk_lakh)::numeric, 2),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.sqa_coverage_capa_actions_r3656 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3656_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_spend_at_risk_lakh numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sqa_coverage_capa_actions_r3656)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.spend_at_risk_lakh),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.sqa_coverage_capa_actions_r3656 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Coverage-gap digest
create or replace function public.founder_r3656_coverage_gap_digest()
returns table(gap_category text, actions bigint, open_actions bigint, total_spend_at_risk_lakh numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.gap_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.spend_at_risk_lakh),0)::numeric
  from public.sqa_coverage_capa_actions_r3656 c
  group by c.gap_category
  order by count(*) desc;
end;
$$;

-- 8) High-risk supplier queue (unsigned / expired / expiring / low coverage)
create or replace function public.founder_r3656_high_risk_queue()
returns table(
  supplier_code text,
  supplier_name text,
  supply_category text,
  period_month date,
  criticality text,
  sqa_status text,
  days_to_expiry int,
  spend_covered_pct numeric,
  open_deviations int,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_code, l.supplier_name, l.supply_category, l.period_month,
    l.criticality, l.sqa_status, l.days_to_expiry, l.spend_covered_pct::numeric,
    l.open_deviations, l.notes
  from public.sqa_coverage_r3656 l
  where l.sqa_status in ('unsigned','expired','renewal_due','under_negotiation')
     or (l.days_to_expiry is not null and l.days_to_expiry <= 60)
     or l.spend_covered_pct < 80
     or l.open_deviations >= 2
  order by l.period_month desc, l.supplier_name;
end;
$$;

revoke all on function public.founder_r3656_sqa_status_rollup() from public, anon;
revoke all on function public.founder_r3656_supply_category_scorecard() from public, anon;
revoke all on function public.founder_r3656_criticality_status_matrix() from public, anon;
revoke all on function public.founder_r3656_monthly_coverage_trend() from public, anon;
revoke all on function public.founder_r3656_capa_status_board() from public, anon;
revoke all on function public.founder_r3656_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3656_coverage_gap_digest() from public, anon;
revoke all on function public.founder_r3656_high_risk_queue() from public, anon;

grant execute on function public.founder_r3656_sqa_status_rollup() to authenticated;
grant execute on function public.founder_r3656_supply_category_scorecard() to authenticated;
grant execute on function public.founder_r3656_criticality_status_matrix() to authenticated;
grant execute on function public.founder_r3656_monthly_coverage_trend() to authenticated;
grant execute on function public.founder_r3656_capa_status_board() to authenticated;
grant execute on function public.founder_r3656_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3656_coverage_gap_digest() to authenticated;
grant execute on function public.founder_r3656_high_risk_queue() to authenticated;

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

  -- 16 SQA coverage snapshot rows
  insert into public.sqa_coverage_r3656 (
    organization_id, supplier_code, supplier_name, supply_category, period_month,
    sqa_signed, sqa_effective_date, sqa_expiry_date, days_to_expiry,
    change_notification_clause, audit_rights_clause, spend_covered_pct,
    open_deviations, criticality, sqa_status, trend_dir, notes
  )
  select v_org_id, q.scode, q.sname, q.cat, q.pmon::date,
    q.sgn, q.effd::date, q.expd::date, q.dte::int,
    q.chn, q.aud, q.spct::numeric,
    q.odev::int, q.crit, q.st, q.trend, q.nt
  from (values
    ('SUP-STM-01','Sterimed Components Pvt Ltd','sensors_transducers','2026-07-01',
     true,'2025-04-01','2027-03-31','241',true,true,'96.5','0','critical','current','stable','Full SQA with change-notification and audit-rights clauses — coverage healthy'),
    ('SUP-PLM-02','Poly Medicure Ltd','plastics_molding','2026-07-01',
     true,'2024-09-15','2026-09-14','43',true,true,'92.0','1','critical','renewal_due','stable','SQA expires in 43 days — renewal pack sent to supplier'),
    ('SUP-TVT-03','Trivitron Component Works','pcb_electronics','2026-07-01',
     true,'2024-06-01','2026-06-01','-30',true,false,'88.0','2','major','expired','worsening','SQA lapsed last month — operating on expired agreement'),
    ('SUP-SSK-04','Sahajanand Surgical Kits','contract_manufacturing','2026-07-01',
     false,null,null,null,false,false,'0.0','3','critical','unsigned','worsening','Critical contract manufacturer with no SQA — escalated to leadership'),
    ('SUP-STE-05','Steriline Sterilization Services','sterilization_services','2026-07-01',
     true,'2025-11-01','2027-10-31','455',true,true,'100.0','0','critical','current','improving','EO sterilization SQA current incl parametric-release clause'),
    ('SUP-CAL-06','Calibron Metrology Labs','calibration_services','2026-07-01',
     false,null,null,null,true,true,'0.0','0','major','under_negotiation','improving','Draft SQA in legal redline — clauses agreed, signature pending'),
    ('SUP-PKG-07','Bilcare Packaging Solutions','packaging_labels','2026-07-01',
     true,'2025-01-10','2027-01-09','160',true,false,'85.5','1','low_risk','current','stable','SQA current but lacks audit-rights clause — amendment in progress'),
    ('SUP-CBL-08','Elcon Cables and Connectors','cables_connectors','2026-07-01',
     true,'2024-08-01','2026-08-15','13',false,false,'71.0','2','major','renewal_due','worsening','Renewal due in 13 days; legacy SQA missing both modern clauses'),
    ('SUP-RAW-09','Gujarat Medi Polymers','raw_materials','2026-07-01',
     true,'2025-06-01','2028-05-31','667',true,true,'94.0','0','standard','current','improving','Three-year SQA with resin change-notification rider executed'),
    ('SUP-SWC-10','Medsoft Embedded Systems','software_components','2026-07-01',
     false,null,null,null,false,false,'0.0','1','major','unsigned','stable','SOUP/software supplier unsigned — IEC 62304 rider drafted'),
    ('SUP-PLM-02','Poly Medicure Ltd','plastics_molding','2026-06-01',
     true,'2024-09-15','2026-09-14','73',true,true,'92.0','0','critical','renewal_due','stable','T-90 renewal window entered during June review'),
    ('SUP-TVT-03','Trivitron Component Works','pcb_electronics','2026-06-01',
     true,'2024-06-01','2026-06-01','0',true,false,'88.0','1','major','expired','worsening','SQA hit expiry on 01-Jun — extension letter not executed'),
    ('SUP-STM-01','Sterimed Components Pvt Ltd','sensors_transducers','2026-06-01',
     true,'2025-04-01','2027-03-31','271',true,true,'96.0','0','critical','current','stable','June review — no coverage changes'),
    ('SUP-SSK-04','Sahajanand Surgical Kits','contract_manufacturing','2026-06-01',
     false,null,null,null,false,false,'0.0','2','critical','unsigned','worsening','Unsigned for second consecutive review cycle'),
    ('SUP-CAL-06','Calibron Metrology Labs','calibration_services','2026-05-01',
     false,null,null,null,false,false,'0.0','0','major','unsigned','stable','SQA negotiation kicked off in May'),
    ('SUP-CBL-08','Elcon Cables and Connectors','cables_connectors','2026-05-01',
     true,'2024-08-01','2026-08-15','106',false,false,'71.0','1','major','current','stable','Legacy SQA without modern clauses — flagged for rewrite')
  ) as q(scode, sname, cat, pmon, sgn, effd, expd, dte, chn, aud, spct, odev, crit, st, trend, nt);

  -- CAPA seed — attach to July snapshot rows via supplier_code
  insert into public.sqa_coverage_capa_actions_r3656 (
    sqa_record_id, gap_category, root_cause, corrective_action,
    capa_status, spend_at_risk_lakh, owner, target_closure_date,
    actual_closure_date, notes
  )
  select e.id, q.gc, q.rc, q.ca,
    q.cst, q.risk, q.ownr, q.tcd::date,
    q.acd::date, q.nt
  from (values
    ('SUP-SSK-04','unsigned_agreement','supplier_legal_pushback','escalate_to_leadership','escalated',240.00,'Ravi Menon (SQE Lead)','2026-08-20',null,'Critical CM supplier refusing liability clause — CEO-level call scheduled'),
    ('SUP-TVT-03','expired_agreement','renewal_tracking_gap','renew_agreement','in_progress',130.00,'Anita Deshpande (Quality Head)','2026-08-10',null,'Renewal in signature loop; interim quality letter executed'),
    ('SUP-SWC-10','unsigned_agreement','ownership_unassigned','assign_sqa_owner','open',54.00,'Karthik Iyer (SQE)','2026-08-25',null,'Software supplier had no assigned SQE — owner now named'),
    ('SUP-CBL-08','legacy_template','legacy_template_used','migrate_to_current_template','open',36.50,'Meera Nair (Supplier Quality)','2026-08-15',null,'Old-format SQA missing both modern clauses — rewrite on current template'),
    ('SUP-PKG-07','missing_audit_rights_clause','legacy_template_used','amend_clause','verification_pending',22.00,'Meera Nair (Supplier Quality)','2026-07-30',null,'Amendment signed by supplier — QA verification of filed copy pending'),
    ('SUP-PLM-02','renewal_window_open','renewal_tracking_gap','implement_renewal_alerts','in_progress',95.00,'Karthik Iyer (SQE)','2026-08-05',null,'T-90/T-60/T-30 alert rule added to contract tracker; renewal underway'),
    ('SUP-CAL-06','unsigned_agreement','supplier_legal_pushback','execute_new_sqa','in_progress',18.75,'Anita Deshpande (Quality Head)','2026-08-12',null,'Redlines resolved on liability cap — signature expected this week'),
    ('SUP-RAW-09','missing_change_notification_clause','legacy_template_used','amend_clause','closed',0.00,'Meera Nair (Supplier Quality)','2026-06-30','2026-06-24','Resin change-notification rider executed and filed')
  ) as q(scode, gc, rc, ca, cst, risk, ownr, tcd, acd, nt)
  join public.sqa_coverage_r3656 e
    on e.organization_id = v_org_id
   and e.supplier_code = q.scode
   and e.period_month = date '2026-07-01';
end;
$seed$;
