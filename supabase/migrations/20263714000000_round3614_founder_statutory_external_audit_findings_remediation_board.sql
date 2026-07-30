-- Round 3614: Founder Statutory / External-Audit Findings Remediation Board
-- Statutory / external-audit findings log — auditor firm × audit area × business unit × period × severity ×
-- financial impact × days open × repeat flag × target date × remediation status × trend × CAPA remediation actions

-- =============================================================================
-- TABLE 1: stat_audit_r3614 — statutory / external-audit finding records
-- =============================================================================
create table if not exists public.stat_audit_r3614 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  finding_ref text not null,
  auditor_firm text not null,
  audit_area text not null,
  business_unit text not null check (business_unit in (
    'amc_services','spare_parts','projects','diagnostics','rentals','corporate'
  )),
  period_month date not null,
  financial_impact_rupees numeric(14,2),
  days_open int not null,
  repeat_finding boolean not null,
  remediation_owner text not null,
  target_date date,
  severity text not null check (severity in (
    'critical','high','medium','low','observation'
  )),
  remediation_status text not null check (remediation_status in (
    'open','in_progress','management_accepted','remediated','overdue','disputed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.stat_audit_r3614 enable row level security;

create index if not exists idx_stat_audit_r3614_org on public.stat_audit_r3614(organization_id);
create index if not exists idx_stat_audit_r3614_period on public.stat_audit_r3614(period_month);
create index if not exists idx_stat_audit_r3614_status on public.stat_audit_r3614(remediation_status);

-- =============================================================================
-- TABLE 2: stat_audit_capa_actions_r3614 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.stat_audit_capa_actions_r3614 (
  id uuid primary key default gen_random_uuid(),
  finding_id uuid not null references public.stat_audit_r3614(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'process_gap','manual_error','policy_not_updated','system_limitation','training_gap',
    'judgmental_estimate','timing_difference','vendor_data_gap','pending_investigation','regulatory_change_lag'
  )),
  corrective_action text not null check (corrective_action in (
    'process_redesign','system_control_added','policy_update','staff_training','provision_created',
    'statutory_payment_made','return_revised','board_approval_obtained','reconciliation_completed','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  statutory_exposure text not null check (statutory_exposure in (
    'companies_act','income_tax','gst','pf_esi','sebi_listing','none','internal_only'
  )),
  remediation_cost_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.stat_audit_capa_actions_r3614 enable row level security;

create index if not exists idx_stat_audit_capa_r3614_finding on public.stat_audit_capa_actions_r3614(finding_id);
create index if not exists idx_stat_audit_capa_r3614_status on public.stat_audit_capa_actions_r3614(capa_status);

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

  -- 16 statutory-audit finding rows
  insert into public.stat_audit_r3614 (
    organization_id, finding_ref, auditor_firm, audit_area, business_unit, period_month,
    financial_impact_rupees, days_open, repeat_finding, remediation_owner, target_date,
    severity, remediation_status, trend_dir, notes
  )
  select v_org_id, q.fref, q.firm, q.area, q.bu, q.pm::date,
    q.fin, q.dopen, q.rpt, q.ownr, q.tgt::date,
    q.sev, q.rst, q.trd, q.nt
  from (values
    ('STAT-2026-001','BSR and Co LLP','revenue_recognition','amc_services','2026-06-01',
     4200000.00,42,true,'Vikram Rao','2026-08-15','high','in_progress','worsening','AMC revenue recognised upfront instead of over the contract period'),
    ('STAT-2026-002','BSR and Co LLP','statutory_dues','corporate','2026-06-01',
     1850000.00,58,false,'Anita Desai','2026-07-31','critical','overdue','worsening','GST payable on advances not deposited within statutory due date'),
    ('STAT-2026-003','SR Batliboi and Co','fixed_assets','diagnostics','2026-05-01',
     950000.00,75,true,'Rahul Menon','2026-08-30','medium','open','stable','Demo diagnostic units not capitalised; depreciation understated'),
    ('STAT-2026-004','SR Batliboi and Co','inventory_valuation','spare_parts','2026-05-01',
     2650000.00,33,false,'Priya Nair','2026-08-10','high','in_progress','improving','Slow-moving spare-parts provision not created per stated policy'),
    ('STAT-2026-005','Walker Chandiok and Co','tds_compliance','corporate','2026-06-01',
     320000.00,20,false,'Suresh Iyer','2026-08-05','medium','management_accepted','stable','TDS on professional fees short-deducted for two vendors'),
    ('STAT-2026-006','Walker Chandiok and Co','gst_compliance','projects','2026-04-01',
     1420000.00,96,true,'Deepak Sharma','2026-07-20','high','overdue','worsening','Input tax credit availed on blocked credits at project site'),
    ('STAT-2026-007','Deloitte Haskins and Sells','related_party','corporate','2026-06-01',
     0.00,15,false,'Anita Desai','2026-08-25','observation','open','stable','Related-party rental agreement not board-approved before execution'),
    ('STAT-2026-008','Deloitte Haskins and Sells','internal_financial_controls','amc_services','2026-05-01',
     0.00,48,true,'Vikram Rao','2026-08-18','high','disputed','worsening','No maker-checker control on AMC credit notes above threshold'),
    ('STAT-2026-009','MSKA and Associates','payroll_pf_esi','corporate','2026-04-01',
     780000.00,110,true,'Kavya Reddy','2026-07-15','medium','overdue','worsening','PF not remitted on overtime component for field engineers'),
    ('STAT-2026-010','MSKA and Associates','vendor_payments','spare_parts','2026-06-01',
     540000.00,25,false,'Priya Nair','2026-08-22','low','in_progress','improving','MSME vendor dues aged beyond 45 days without interest provision'),
    ('STAT-2026-011','TR Chadha and Co','revenue_recognition','rentals','2026-05-01',
     1180000.00,61,false,'Rahul Menon','2026-08-12','high','in_progress','stable','Equipment rental income not accrued for part-month usage'),
    ('STAT-2026-012','TR Chadha and Co','fixed_assets','projects','2026-03-01',
     3100000.00,130,true,'Deepak Sharma','2026-07-10','critical','overdue','worsening','Turnkey project CWIP not transferred to assets on commissioning'),
    ('STAT-2026-013','BSR and Co LLP','statutory_dues','diagnostics','2026-06-01',
     260000.00,18,false,'Suresh Iyer','2026-09-01','low','management_accepted','improving','Profession tax registration pending for Karnataka branch'),
    ('STAT-2026-014','SR Batliboi and Co','inventory_valuation','spare_parts','2026-04-01',
     890000.00,88,true,'Priya Nair','2026-07-28','medium','open','stable','Physical stock variance in spare-parts warehouse unreconciled'),
    ('STAT-2026-015','Walker Chandiok and Co','gst_compliance','amc_services','2026-06-01',
     670000.00,30,false,'Vikram Rao','2026-08-20','medium','remediated','improving','GSTR-2B reconciliation gap on AMC input credits closed'),
    ('STAT-2026-016','Deloitte Haskins and Sells','tds_compliance','projects','2026-05-01',
     145000.00,52,false,'Kavya Reddy','2026-08-08','observation','remediated','improving','TDS certificate mismatch resolved with vendor reconciliation')
  ) as q(fref, firm, area, bu, pm, fin, dopen, rpt, ownr, tgt, sev, rst, trd, nt);

  -- CAPA seed — attach to specific findings by finding_ref
  insert into public.stat_audit_capa_actions_r3614 (
    finding_id, root_cause, corrective_action, capa_status, statutory_exposure,
    remediation_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.exp,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('STAT-2026-002','process_gap','statutory_payment_made','escalated','gst',
     1850000.00,'Anita Desai','2026-07-31',null,'GST on advances being deposited with interest under section 50'),
    ('STAT-2026-006','policy_not_updated','process_redesign','overdue','gst',
     1420000.00,'Deepak Sharma','2026-07-20',null,'Blocked-credit ITC reversal and control redesign pending'),
    ('STAT-2026-008','system_limitation','system_control_added','in_progress','internal_only',
     120000.00,'Vikram Rao','2026-08-18',null,'Maker-checker workflow being built into AMC credit-note module'),
    ('STAT-2026-009','process_gap','statutory_payment_made','overdue','pf_esi',
     780000.00,'Kavya Reddy','2026-07-15',null,'PF on overtime to be remitted with damages under section 14B'),
    ('STAT-2026-012','timing_difference','reconciliation_completed','verification_pending','companies_act',
     3100000.00,'Deepak Sharma','2026-07-10',null,'CWIP-to-asset transfer reconciled; auditor verification awaited'),
    ('STAT-2026-001','judgmental_estimate','policy_update','in_progress','income_tax',
     90000.00,'Vikram Rao','2026-08-15',null,'AMC revenue recognition policy being aligned to Ind AS 115'),
    ('STAT-2026-015','manual_error','reconciliation_completed','closed','gst',
     15000.00,'Vikram Rao','2026-08-01','2026-07-22','GSTR-2B reconciliation control implemented and verified'),
    ('STAT-2026-016','vendor_data_gap','reconciliation_completed','closed','income_tax',
     8000.00,'Kavya Reddy','2026-08-08','2026-07-18','TDS certificate mismatch resolved and closed')
  ) as q(fref, rc, ca, cst, exp, cost, ownr, tcd, acd, nt)
  join public.stat_audit_r3614 e
    on e.organization_id = v_org_id and e.finding_ref = q.fref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Remediation-status distribution
create or replace function public.founder_r3614_remediation_status_rollup()
returns table(remediation_status text, findings bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.stat_audit_r3614)
  select f.remediation_status, count(*)::bigint,
         coalesce(sum(f.financial_impact_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.stat_audit_r3614 f
  group by f.remediation_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3614_remediation_status_rollup() from public, anon;
grant execute on function public.founder_r3614_remediation_status_rollup() to authenticated;

-- 2) Audit-area scorecard
create or replace function public.founder_r3614_audit_area_scorecard()
returns table(
  audit_area text,
  total_findings bigint,
  open_findings bigint,
  overdue bigint,
  repeat_findings bigint,
  critical_high bigint,
  total_impact_rupees numeric,
  remediated_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.audit_area,
    count(*)::bigint,
    count(*) filter (where f.remediation_status in ('open','in_progress','management_accepted'))::bigint,
    count(*) filter (where f.remediation_status = 'overdue')::bigint,
    count(*) filter (where f.repeat_finding = true)::bigint,
    count(*) filter (where f.severity in ('critical','high'))::bigint,
    coalesce(sum(f.financial_impact_rupees),0)::numeric,
    round(100.0 * count(*) filter (where f.remediation_status = 'remediated')::numeric / nullif(count(*),0), 1)
  from public.stat_audit_r3614 f
  group by f.audit_area
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3614_audit_area_scorecard() from public, anon;
grant execute on function public.founder_r3614_audit_area_scorecard() to authenticated;

-- 3) Audit-area × remediation-status matrix
create or replace function public.founder_r3614_area_status_matrix()
returns table(audit_area text, remediation_status text, findings bigint, total_impact_rupees numeric, avg_days_open numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.audit_area, f.remediation_status, count(*)::bigint,
    coalesce(sum(f.financial_impact_rupees),0)::numeric,
    round(avg(f.days_open), 1)
  from public.stat_audit_r3614 f
  group by f.audit_area, f.remediation_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3614_area_status_matrix() from public, anon;
grant execute on function public.founder_r3614_area_status_matrix() to authenticated;

-- 4) Monthly finding trend
create or replace function public.founder_r3614_monthly_finding_trend()
returns table(period_month date, findings bigint, remediated bigint, overdue bigint, repeat_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.period_month,
    count(*)::bigint,
    count(*) filter (where f.remediation_status = 'remediated')::bigint,
    count(*) filter (where f.remediation_status = 'overdue')::bigint,
    count(*) filter (where f.repeat_finding = true)::bigint,
    coalesce(sum(f.financial_impact_rupees),0)::numeric
  from public.stat_audit_r3614 f
  group by f.period_month
  order by f.period_month desc;
end;
$$;

revoke execute on function public.founder_r3614_monthly_finding_trend() from public, anon;
grant execute on function public.founder_r3614_monthly_finding_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3614_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.remediation_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.stat_audit_capa_actions_r3614 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3614_capa_status_board() from public, anon;
grant execute on function public.founder_r3614_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3614_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.stat_audit_capa_actions_r3614)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.remediation_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.stat_audit_capa_actions_r3614 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3614_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3614_root_cause_pareto() to authenticated;

-- 7) Statutory-exposure impact digest
create or replace function public.founder_r3614_impact_digest()
returns table(statutory_exposure text, actions bigint, open_actions bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.statutory_exposure, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.remediation_cost_rupees),0)::numeric
  from public.stat_audit_capa_actions_r3614 c
  group by c.statutory_exposure
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3614_impact_digest() from public, anon;
grant execute on function public.founder_r3614_impact_digest() to authenticated;

-- 8) High-risk queue (overdue / disputed / critical-high / repeat / worsening)
create or replace function public.founder_r3614_high_risk_queue()
returns table(
  finding_ref text,
  audit_area text,
  business_unit text,
  auditor_firm text,
  severity text,
  remediation_status text,
  days_open int,
  financial_impact_rupees numeric,
  repeat_finding boolean,
  target_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_ref, f.audit_area, f.business_unit, f.auditor_firm, f.severity,
    f.remediation_status, f.days_open, f.financial_impact_rupees, f.repeat_finding, f.target_date, f.notes
  from public.stat_audit_r3614 f
  where f.remediation_status in ('overdue','disputed')
     or f.severity in ('critical','high')
     or f.repeat_finding = true
     or f.trend_dir = 'worsening'
  order by case f.severity
             when 'critical' then 0
             when 'high' then 1
             when 'medium' then 2
             when 'low' then 3
             else 4
           end,
           f.days_open desc;
end;
$$;

revoke execute on function public.founder_r3614_high_risk_queue() from public, anon;
grant execute on function public.founder_r3614_high_risk_queue() to authenticated;
