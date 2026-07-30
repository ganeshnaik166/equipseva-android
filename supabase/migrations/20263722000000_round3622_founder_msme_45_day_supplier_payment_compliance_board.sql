-- Round 3622: Founder MSME 45-Day Supplier-Payment Compliance Board
-- MSMED-Act 45-day supplier-payment compliance + interest-liability exposure — supplier × msme category
-- × business unit × invoice value × due/paid within 45 days × overdue × days outstanding × interest liability
-- × avg payment days × compliance % × compliance status × trend × CAPA closure

-- =============================================================================
-- TABLE 1: msme_payment_r3622 — per-supplier 45-day payment compliance fact rows
-- =============================================================================
create table if not exists public.msme_payment_r3622 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_name text not null,
  supplier_code text not null,
  msme_category text not null check (msme_category in (
    'micro','small','medium'
  )),
  business_unit text not null check (business_unit in (
    'amc_services','spare_parts','projects','diagnostics','installation','consumables'
  )),
  period_month date not null,
  invoice_value_rupees numeric(14,2),
  due_within_45_days_rupees numeric(14,2),
  paid_within_45_days_rupees numeric(14,2),
  overdue_beyond_45_rupees numeric(14,2),
  days_outstanding int,
  interest_liability_rupees numeric(14,2),
  avg_payment_days numeric(6,2),
  compliance_pct numeric(5,2),
  compliance_status text not null check (compliance_status in (
    'compliant','at_risk','breached','interest_accruing','disputed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.msme_payment_r3622 enable row level security;

create index if not exists idx_msme_payment_r3622_org on public.msme_payment_r3622(organization_id);
create index if not exists idx_msme_payment_r3622_month on public.msme_payment_r3622(period_month);
create index if not exists idx_msme_payment_r3622_status on public.msme_payment_r3622(compliance_status);

-- =============================================================================
-- TABLE 2: msme_payment_capa_actions_r3622 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.msme_payment_capa_actions_r3622 (
  id uuid primary key default gen_random_uuid(),
  payment_log_id uuid not null references public.msme_payment_r3622(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'payment_delay_beyond_45_days','interest_liability_accrued','disputed_invoice',
    'cash_flow_shortfall','vendor_reconciliation_gap','process_approval_delay',
    'msme_status_unverified','recurring_breach'
  )),
  root_cause text not null check (root_cause in (
    'working_capital_constraint','invoice_approval_bottleneck','vendor_dispute',
    'gst_mismatch','po_grn_mismatch','manual_process_delay',
    'bank_processing_delay','msme_declaration_missing','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_payment','setup_auto_payment_schedule','resolve_vendor_dispute',
    'reconcile_ledger','automate_approval_workflow','arrange_working_capital',
    'verify_msme_registration','provision_interest_liability','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  interest_exposure_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.msme_payment_capa_actions_r3622 enable row level security;

create index if not exists idx_msme_payment_capa_r3622_log on public.msme_payment_capa_actions_r3622(payment_log_id);
create index if not exists idx_msme_payment_capa_r3622_status on public.msme_payment_capa_actions_r3622(capa_status);

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

  -- 16 supplier-payment compliance rows
  insert into public.msme_payment_r3622 (
    organization_id, supplier_name, supplier_code, msme_category, business_unit, period_month,
    invoice_value_rupees, due_within_45_days_rupees, paid_within_45_days_rupees, overdue_beyond_45_rupees,
    days_outstanding, interest_liability_rupees, avg_payment_days, compliance_pct,
    compliance_status, trend_dir, notes
  )
  select v_org_id, q.supp, q.scode, q.cat, q.bu, q.pmon::date,
    q.invval, q.dueval, q.paidval, q.ovd,
    q.dso, q.intliab, q.avgpd, q.comppct,
    q.cstat, q.trend, q.nt
  from (values
    ('Meditech Spares Pvt Ltd','MSE-01','micro','spare_parts','2026-06-01',
     480000,480000,480000,0,22,0,28.0,100.0,'compliant','improving','All spare-parts invoices cleared within 45 days'),
    ('Sterling Consumables','SCN-02','small','consumables','2026-06-01',
     1250000,1250000,900000,350000,58,4200,49.0,72.0,'at_risk','worsening','Consumables batch payment slipping past 45-day line'),
    ('Precision Calib Services','PCS-03','micro','amc_services','2026-06-01',
     320000,320000,180000,140000,67,3100,61.0,56.0,'breached','worsening','AMC subcontractor payment breached 45-day limit'),
    ('BioMed Imaging Parts','BIP-04','medium','spare_parts','2026-06-01',
     2100000,2100000,2100000,0,31,0,33.0,100.0,'compliant','stable','Imaging spares paid on schedule'),
    ('Krishna Surgical Supplies','KSS-05','small','consumables','2026-06-01',
     760000,760000,400000,360000,74,5400,63.0,52.0,'interest_accruing','worsening','Interest accruing on overdue surgical consumables'),
    ('Ganga Diagnostics Reagents','GDR-06','medium','diagnostics','2026-05-01',
     1850000,1850000,1500000,350000,52,2900,44.0,81.0,'at_risk','stable','Reagent supplier nearing breach threshold'),
    ('Apex Installation Crew','AIC-07','micro','installation','2026-05-01',
     540000,540000,540000,0,19,0,25.0,100.0,'compliant','improving','Installation vendor paid promptly'),
    ('Nova Electro Components','NEC-08','small','spare_parts','2026-05-01',
     990000,990000,600000,390000,63,4700,57.0,61.0,'breached','worsening','Electronic components payment breached window'),
    ('Shakti Project Contractors','SPC-09','medium','projects','2026-05-01',
     3400000,3400000,2200000,1200000,88,18500,71.0,65.0,'interest_accruing','worsening','Project milestone payment overdue, interest accruing'),
    ('Vedant Medical Gases','VMG-10','small','consumables','2026-05-01',
     420000,420000,420000,0,27,0,30.0,100.0,'compliant','stable','Medical gas supplier compliant'),
    ('Orbit Cal Lab','OCL-11','micro','amc_services','2026-04-01',
     280000,280000,150000,130000,59,2400,55.0,54.0,'disputed','stable','Calibration invoice disputed on scope of work'),
    ('Deccan Spare Depot','DSD-12','small','spare_parts','2026-04-01',
     680000,680000,680000,0,34,0,36.0,100.0,'compliant','improving','Spare depot cleared within window'),
    ('Ashwini Diagnostics Lab','ADL-13','medium','diagnostics','2026-04-01',
     1560000,1560000,1000000,560000,71,7200,59.0,64.0,'breached','worsening','Diagnostics lab payment breached repeatedly'),
    ('Trinity Projects LLP','TPL-14','medium','projects','2026-04-01',
     2750000,2750000,2750000,0,40,0,42.0,100.0,'compliant','stable','Project vendor paid within 45 days'),
    ('Lotus Consumable Mart','LCM-15','micro','consumables','2026-03-01',
     310000,310000,180000,130000,62,2200,58.0,58.0,'interest_accruing','worsening','Small consumable vendor interest accruing'),
    ('Sunrise AMC Partners','SAP-16','small','amc_services','2026-03-01',
     870000,870000,500000,370000,66,4900,60.0,57.0,'breached','stable','AMC partner recurring breach on payment')
  ) as q(supp, scode, cat, bu, pmon, invval, dueval, paidval, ovd, dso, intliab, avgpd, comppct, cstat, trend, nt);

  -- CAPA seed — attach to specific rows via supplier_code
  insert into public.msme_payment_capa_actions_r3622 (
    payment_log_id, finding_category, root_cause, corrective_action,
    capa_status, interest_exposure_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.iexp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SCN-02','payment_delay_beyond_45_days','working_capital_constraint','arrange_working_capital','in_progress',4200,'Ravi Menon (Finance)','2026-07-15',null,'Working-capital line being arranged to clear consumables backlog'),
    ('PCS-03','recurring_breach','invoice_approval_bottleneck','automate_approval_workflow','open',3100,'Anita Desai (AP)','2026-07-20',null,'Approval-workflow automation to prevent AMC breach recurrence'),
    ('KSS-05','interest_liability_accrued','working_capital_constraint','provision_interest_liability','escalated',5400,'Ravi Menon (Finance)','2026-07-10',null,'Interest provisioned; escalated to CFO for expedited payment'),
    ('NEC-08','payment_delay_beyond_45_days','po_grn_mismatch','reconcile_ledger','verification_pending',4700,'Suresh Iyer (Procurement)','2026-07-18',null,'PO-GRN mismatch reconciled; verifying before release'),
    ('SPC-09','interest_liability_accrued','working_capital_constraint','arrange_working_capital','escalated',18500,'Priya Nair (CFO office)','2026-07-05',null,'Large project interest exposure; bridge finance being arranged'),
    ('OCL-11','disputed_invoice','vendor_dispute','resolve_vendor_dispute','open',2400,'Anita Desai (AP)','2026-07-22',null,'Scope-of-work dispute under negotiation with calibration lab'),
    ('ADL-13','recurring_breach','manual_process_delay','automate_approval_workflow','overdue',7200,'Suresh Iyer (Procurement)','2026-06-30',null,'Repeated diagnostics breach; automation past target date'),
    ('SAP-16','interest_liability_accrued','bank_processing_delay','setup_auto_payment_schedule','closed',4900,'Ravi Menon (Finance)','2026-06-25','2026-06-24','Auto-payment schedule set up; AMC partner now current')
  ) as q(scode, fc, rc, ca, cst, iexp, ownr, tcd, acd, nt)
  join public.msme_payment_r3622 e
    on e.organization_id = v_org_id and e.supplier_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3622_compliance_status_rollup()
returns table(compliance_status text, suppliers bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.msme_payment_r3622)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.msme_payment_r3622 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3622_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3622_compliance_status_rollup() to authenticated;

-- 2) MSME-category scorecard
create or replace function public.founder_r3622_msme_category_scorecard()
returns table(
  msme_category text,
  total_lines bigint,
  compliant bigint,
  at_risk bigint,
  breached bigint,
  interest_accruing bigint,
  total_interest_rupees numeric,
  avg_compliance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.msme_category,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'at_risk')::bigint,
    count(*) filter (where l.compliance_status = 'breached')::bigint,
    count(*) filter (where l.compliance_status = 'interest_accruing')::bigint,
    coalesce(sum(l.interest_liability_rupees),0)::numeric,
    round(avg(l.compliance_pct), 1)
  from public.msme_payment_r3622 l
  group by l.msme_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3622_msme_category_scorecard() from public, anon;
grant execute on function public.founder_r3622_msme_category_scorecard() to authenticated;

-- 3) MSME-category × compliance-status matrix
create or replace function public.founder_r3622_category_status_matrix()
returns table(msme_category text, compliance_status text, lines bigint, invoice_value_rupees numeric, interest_liability_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.msme_category, l.compliance_status, count(*)::bigint,
    coalesce(sum(l.invoice_value_rupees),0)::numeric,
    coalesce(sum(l.interest_liability_rupees),0)::numeric
  from public.msme_payment_r3622 l
  group by l.msme_category, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3622_category_status_matrix() from public, anon;
grant execute on function public.founder_r3622_category_status_matrix() to authenticated;

-- 4) Monthly compliance trend
create or replace function public.founder_r3622_monthly_compliance_trend()
returns table(period_month date, lines bigint, compliant bigint, breached bigint, interest_accruing bigint, total_interest_rupees numeric, avg_compliance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'breached')::bigint,
    count(*) filter (where l.compliance_status = 'interest_accruing')::bigint,
    coalesce(sum(l.interest_liability_rupees),0)::numeric,
    round(avg(l.compliance_pct), 1)
  from public.msme_payment_r3622 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3622_monthly_compliance_trend() from public, anon;
grant execute on function public.founder_r3622_monthly_compliance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3622_capa_status_board()
returns table(capa_status text, findings bigint, avg_interest_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.interest_exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.msme_payment_capa_actions_r3622 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3622_capa_status_board() from public, anon;
grant execute on function public.founder_r3622_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3622_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.msme_payment_capa_actions_r3622)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.interest_exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.msme_payment_capa_actions_r3622 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3622_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3622_root_cause_pareto() to authenticated;

-- 7) Interest-exposure digest (by business unit)
create or replace function public.founder_r3622_interest_exposure_digest()
returns table(business_unit text, lines bigint, total_interest_rupees numeric, total_overdue_rupees numeric, at_risk_lines bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, count(*)::bigint,
    coalesce(sum(l.interest_liability_rupees),0)::numeric,
    coalesce(sum(l.overdue_beyond_45_rupees),0)::numeric,
    count(*) filter (where l.compliance_status in ('at_risk','breached','interest_accruing'))::bigint
  from public.msme_payment_r3622 l
  group by l.business_unit
  order by coalesce(sum(l.interest_liability_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3622_interest_exposure_digest() from public, anon;
grant execute on function public.founder_r3622_interest_exposure_digest() to authenticated;

-- 8) High-risk queue (breached / interest_accruing / disputed / overdue)
create or replace function public.founder_r3622_high_risk_queue()
returns table(
  supplier_name text,
  supplier_code text,
  msme_category text,
  business_unit text,
  period_month date,
  compliance_status text,
  days_outstanding int,
  overdue_beyond_45_rupees numeric,
  interest_liability_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_name, l.supplier_code, l.msme_category, l.business_unit, l.period_month,
    l.compliance_status, l.days_outstanding, l.overdue_beyond_45_rupees, l.interest_liability_rupees, l.notes
  from public.msme_payment_r3622 l
  where l.compliance_status in ('breached','interest_accruing','disputed')
     or l.days_outstanding > 45
     or l.overdue_beyond_45_rupees > 0
  order by l.interest_liability_rupees desc nulls last, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3622_high_risk_queue() from public, anon;
grant execute on function public.founder_r3622_high_risk_queue() to authenticated;
