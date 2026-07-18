-- Round 3173: Founder Payroll & Statutory-Compliance (PF/ESI/TDS) Board
-- Monthly payroll statutory log — headcount × gross payroll × PF/ESI/TDS due-vs-paid × challan filing × penalty risk × verdict × CAPA

-- =============================================================================
-- TABLE 1: payroll_compliance_r3173 — monthly statutory-compliance record per entity
-- =============================================================================
create table if not exists public.payroll_compliance_r3173 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  entity_state text not null,
  payroll_officer text,
  pay_month date not null,
  pay_cycle_label text not null,
  headcount int not null,
  gross_payroll_rupees numeric(14,2) not null,
  pf_due_rupees numeric(14,2),
  pf_paid_rupees numeric(14,2),
  esi_due_rupees numeric(14,2),
  esi_paid_rupees numeric(14,2),
  tds_due_rupees numeric(14,2),
  tds_paid_rupees numeric(14,2),
  pf_status text not null check (pf_status in (
    'paid_full','paid_partial','unpaid','not_applicable','disputed'
  )),
  esi_status text not null check (esi_status in (
    'paid_full','paid_partial','unpaid','not_applicable','exempt_above_ceiling'
  )),
  tds_status text not null check (tds_status in (
    'deposited_full','deposited_partial','not_deposited','nil_liability','not_applicable'
  )),
  challan_filed_date date,
  filing_status text not null check (filing_status in (
    'all_filed_on_time','partially_filed','filed_late','not_filed','nil_return','revised_filed'
  )),
  penalty_risk text not null check (penalty_risk in (
    'none','low','moderate','high','severe','under_notice'
  )),
  estimated_penalty_rupees numeric(12,2),
  compliance_verdict text not null check (compliance_verdict in (
    'fully_compliant','minor_gaps','material_non_compliance','under_remediation','escalated_to_auditor','clean_certified'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.payroll_compliance_r3173 enable row level security;

create index if not exists idx_payroll_compliance_r3173_org on public.payroll_compliance_r3173(organization_id);
create index if not exists idx_payroll_compliance_r3173_month on public.payroll_compliance_r3173(pay_month);
create index if not exists idx_payroll_compliance_r3173_verdict on public.payroll_compliance_r3173(compliance_verdict);

-- =============================================================================
-- TABLE 2: payroll_compliance_capa_actions_r3173 — follow-up / CAPA actions
-- =============================================================================
create table if not exists public.payroll_compliance_capa_actions_r3173 (
  id uuid primary key default gen_random_uuid(),
  compliance_log_id uuid not null references public.payroll_compliance_r3173(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'pf_challan_late','esi_challan_late','tds_short_deposit','tds_return_late',
    'pf_ecr_mismatch','esi_wage_error','uan_kyc_pending','pt_not_deducted',
    'gratuity_provision_gap','bonus_act_noncompliance','minimum_wage_shortfall','form16_delay'
  )),
  root_cause text not null check (root_cause in (
    'cashflow_shortfall','portal_downtime','staff_attrition_payroll','data_entry_error',
    'vendor_delay','statutory_rate_change_missed','reconciliation_backlog',
    'new_joiner_uan_delay','bank_challan_failure','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'pay_challan_with_interest','file_revised_return','reconcile_ecr','update_uan_kyc',
    'automate_challan_reminder','engage_payroll_consultant','recover_from_employee',
    'provision_penalty_reserve','escalate_to_cfo','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'epfo_notice','esic_notice','it_dept_notice','none','internal_only',
    'labour_dept_inspection','statutory_audit_qualification'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.payroll_compliance_capa_actions_r3173 enable row level security;

create index if not exists idx_payroll_capa_r3173_log on public.payroll_compliance_capa_actions_r3173(compliance_log_id);
create index if not exists idx_payroll_capa_r3173_status on public.payroll_compliance_capa_actions_r3173(capa_status);

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

  -- 14 monthly statutory-compliance rows
  insert into public.payroll_compliance_r3173 (
    organization_id, entity_name, entity_state, payroll_officer, pay_month, pay_cycle_label,
    headcount, gross_payroll_rupees,
    pf_due_rupees, pf_paid_rupees, esi_due_rupees, esi_paid_rupees, tds_due_rupees, tds_paid_rupees,
    pf_status, esi_status, tds_status, challan_filed_date,
    filing_status, penalty_risk, estimated_penalty_rupees, compliance_verdict, notes
  )
  select v_org_id, q.ent, q.st, q.ofc, q.pm::date, q.lbl,
    q.hc, q.gross,
    q.pfd, q.pfp, q.esid, q.esip, q.tdsd, q.tdsp,
    q.pfs, q.esis, q.tdss, q.cfd::date,
    q.fs, q.pr, q.pen, q.cv, q.nt
  from (values
    ('Apollo Hospitals Jubilee Hills','Telangana','Ramesh Kumar','2026-06-01','Jun 2026',
     1240,78500000.00,4200000.00,4200000.00,620000.00,620000.00,5800000.00,5800000.00,
     'paid_full','paid_full','deposited_full','2026-07-14',
     'all_filed_on_time','none',0.00,'fully_compliant','All challans filed before 15th; clean month'),
    ('Fortis Bannerghatta Bengaluru','Karnataka','Anitha Reddy','2026-06-01','Jun 2026',
     860,54200000.00,2900000.00,2900000.00,410000.00,205000.00,3600000.00,3600000.00,
     'paid_full','paid_partial','deposited_full','2026-07-16',
     'filed_late','moderate',18000.00,'minor_gaps','ESI paid partially; challan 1 day late'),
    ('Manipal Whitefield Bengaluru','Karnataka','Suresh Nair','2026-06-01','Jun 2026',
     1520,96800000.00,5100000.00,5100000.00,740000.00,740000.00,7200000.00,6000000.00,
     'paid_full','paid_full','deposited_partial','2026-07-15',
     'partially_filed','high',120000.00,'material_non_compliance','TDS short deposit 12L; interest accruing'),
    ('AIIMS New Delhi Ansari Nagar','Delhi','Vikram Singh','2026-06-01','Jun 2026',
     3200,145000000.00,7800000.00,7800000.00,0.00,0.00,11200000.00,11200000.00,
     'paid_full','exempt_above_ceiling','deposited_full','2026-07-13',
     'all_filed_on_time','none',0.00,'clean_certified','Govt entity; most wages above ESI ceiling; audited clean'),
    ('KIMS Secunderabad','Telangana','Padma Rao','2026-06-01','Jun 2026',
     980,61200000.00,3300000.00,1650000.00,470000.00,470000.00,4100000.00,4100000.00,
     'paid_partial','paid_full','deposited_full','2026-07-18',
     'partially_filed','high',95000.00,'under_remediation','PF paid 50%; cashflow issue escalated to CFO'),
    ('Care Hospitals Banjara Hills','Telangana','Mohan Das','2026-06-01','Jun 2026',
     720,44500000.00,2400000.00,2400000.00,360000.00,360000.00,2900000.00,2900000.00,
     'paid_full','paid_full','deposited_full','2026-07-12',
     'all_filed_on_time','none',0.00,'fully_compliant','Fully compliant month'),
    ('Yashoda Somajiguda Hyderabad','Telangana','Lakshmi Prasad','2026-06-01','Jun 2026',
     1100,69300000.00,3700000.00,3700000.00,540000.00,540000.00,4600000.00,4600000.00,
     'paid_full','paid_full','deposited_full','2026-07-16',
     'filed_late','low',12000.00,'minor_gaps','All paid but PF ECR uploaded 1 day late'),
    ('St John''s Medical College Bengaluru','Karnataka','George Thomas','2026-06-01','Jun 2026',
     640,38900000.00,2100000.00,2100000.00,320000.00,320000.00,2400000.00,0.00,
     'paid_full','paid_full','not_deposited',null,
     'not_filed','severe',240000.00,'escalated_to_auditor','TDS not deposited; 24Q return pending — escalated'),
    ('Rainbow Children''s Banjara Hills','Telangana','Sunita Menon','2026-06-01','Jun 2026',
     410,26800000.00,1450000.00,1450000.00,210000.00,105000.00,1700000.00,1700000.00,
     'paid_full','paid_partial','deposited_full','2026-07-17',
     'filed_late','moderate',22000.00,'minor_gaps','ESI underpaid for 3 new joiners; UAN KYC pending'),
    ('Apollo Health City Gachibowli','Telangana','Kiran Babu','2026-06-01','Jun 2026',
     1350,85600000.00,4600000.00,4600000.00,680000.00,680000.00,6300000.00,6300000.00,
     'paid_full','paid_full','deposited_full','2026-07-14',
     'all_filed_on_time','none',0.00,'fully_compliant','Clean; automated challan pipeline'),
    ('Fortis Malar Chennai','Tamil Nadu','Deepa Iyer','2026-06-01','Jun 2026',
     560,33400000.00,1800000.00,1800000.00,270000.00,270000.00,2100000.00,1050000.00,
     'paid_full','paid_full','deposited_partial','2026-07-15',
     'partially_filed','high',88000.00,'material_non_compliance','TDS deposited 50%; TN professional tax also pending'),
    ('Manipal Old Airport Road Bengaluru','Karnataka','Rahul Verma','2026-06-01','Jun 2026',
     1180,74200000.00,3900000.00,3900000.00,580000.00,580000.00,5100000.00,5100000.00,
     'paid_full','paid_full','deposited_full','2026-07-16',
     'filed_late','low',9000.00,'minor_gaps','TDS challan 1 day late; negligible interest'),
    ('Narayana Health City Bengaluru','Karnataka','Sneha Kulkarni','2026-06-01','Jun 2026',
     2100,118000000.00,6300000.00,6300000.00,920000.00,920000.00,8400000.00,8400000.00,
     'paid_full','paid_full','deposited_full','2026-07-13',
     'all_filed_on_time','none',0.00,'clean_certified','Large entity; statutory audit passed clean'),
    ('Yashoda Malakpet Hyderabad','Telangana','Arun Joshi','2026-06-01','Jun 2026',
     890,55700000.00,3000000.00,0.00,430000.00,0.00,3800000.00,3800000.00,
     'unpaid','unpaid','deposited_full',null,
     'not_filed','under_notice',380000.00,'escalated_to_auditor','PF & ESI unpaid 2 months; EPFO notice received')
  ) as q(ent, st, ofc, pm, lbl, hc, gross, pfd, pfp, esid, esip, tdsd, tdsp, pfs, esis, tdss, cfd, fs, pr, pen, cv, nt);

  -- 6 CAPA / follow-up actions — attach to specific entities
  insert into public.payroll_compliance_capa_actions_r3173 (
    compliance_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.cs, q.ri, q.tcd::date, q.acd::date, q.cost, q.nt
  from (values
    ('Manipal Whitefield Bengaluru','tds_short_deposit','cashflow_shortfall','pay_challan_with_interest','in_progress','it_dept_notice','2026-07-25',null,150000.00,'12L TDS shortfall; paying with 1.5% monthly interest'),
    ('St John''s Medical College Bengaluru','tds_return_late','reconciliation_backlog','file_revised_return','escalated','statutory_audit_qualification','2026-07-22',null,260000.00,'24Q pending; auditor flagged qualification risk'),
    ('KIMS Secunderabad','pf_challan_late','cashflow_shortfall','escalate_to_cfo','in_progress','epfo_notice','2026-07-28',null,110000.00,'PF 50% short; CFO arranging funds'),
    ('Yashoda Malakpet Hyderabad','esi_challan_late','staff_attrition_payroll','engage_payroll_consultant','open','esic_notice','2026-07-30',null,420000.00,'PF+ESI 2 months unpaid; consultant onboarded'),
    ('Rainbow Children''s Banjara Hills','uan_kyc_pending','new_joiner_uan_delay','update_uan_kyc','verification_pending','internal_only','2026-07-20','2026-07-19',18000.00,'3 new-joiner UAN KYC completed; verifying ECR'),
    ('Fortis Malar Chennai','pt_not_deducted','statutory_rate_change_missed','file_revised_return','in_progress','labour_dept_inspection','2026-07-26',null,75000.00,'TN PT slab missed; revising and depositing')
  ) as q(ent_key, fc, rc, ca, cs, ri, tcd, acd, cost, nt)
  join public.payroll_compliance_r3173 e
    on e.organization_id = v_org_id and e.entity_name = q.ent_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-verdict distribution (+pct)
create or replace function public.founder_r3173_verdict_rollup()
returns table(compliance_verdict text, entities bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.payroll_compliance_r3173)
  select l.compliance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.payroll_compliance_r3173 l
  group by l.compliance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3173_verdict_rollup() from public, anon;
grant execute on function public.founder_r3173_verdict_rollup() to authenticated;

-- 2) Entity-level statutory scorecard
create or replace function public.founder_r3173_entity_scorecard()
returns table(
  entity_name text,
  records bigint,
  total_headcount bigint,
  total_gross_rupees numeric,
  pf_gap_rupees numeric,
  esi_gap_rupees numeric,
  tds_gap_rupees numeric,
  penalty_exposure_rupees numeric,
  compliance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    coalesce(sum(l.headcount),0)::bigint,
    coalesce(sum(l.gross_payroll_rupees),0)::numeric,
    coalesce(sum(coalesce(l.pf_due_rupees,0) - coalesce(l.pf_paid_rupees,0)),0)::numeric,
    coalesce(sum(coalesce(l.esi_due_rupees,0) - coalesce(l.esi_paid_rupees,0)),0)::numeric,
    coalesce(sum(coalesce(l.tds_due_rupees,0) - coalesce(l.tds_paid_rupees,0)),0)::numeric,
    coalesce(sum(l.estimated_penalty_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.compliance_verdict in ('fully_compliant','clean_certified'))::numeric / nullif(count(*),0), 1)
  from public.payroll_compliance_r3173 l
  group by l.entity_name
  order by coalesce(sum(l.estimated_penalty_rupees),0) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3173_entity_scorecard() from public, anon;
grant execute on function public.founder_r3173_entity_scorecard() to authenticated;

-- 3) Filing-status × penalty-risk matrix
create or replace function public.founder_r3173_filing_penalty_matrix()
returns table(filing_status text, penalty_risk text, entities bigint, penalty_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.filing_status, l.penalty_risk, count(*)::bigint,
    coalesce(sum(l.estimated_penalty_rupees),0)::numeric
  from public.payroll_compliance_r3173 l
  group by l.filing_status, l.penalty_risk
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3173_filing_penalty_matrix() from public, anon;
grant execute on function public.founder_r3173_filing_penalty_matrix() to authenticated;

-- 4) Pay-month trend
create or replace function public.founder_r3173_pay_month_trend()
returns table(
  pay_month date,
  entities bigint,
  total_gross_rupees numeric,
  total_penalty_rupees numeric,
  fully_compliant bigint,
  non_compliant bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pay_month,
    count(*)::bigint,
    coalesce(sum(l.gross_payroll_rupees),0)::numeric,
    coalesce(sum(l.estimated_penalty_rupees),0)::numeric,
    count(*) filter (where l.compliance_verdict in ('fully_compliant','clean_certified'))::bigint,
    count(*) filter (where l.compliance_verdict in ('material_non_compliance','under_remediation','escalated_to_auditor'))::bigint
  from public.payroll_compliance_r3173 l
  group by l.pay_month
  order by l.pay_month desc;
end;
$$;

revoke execute on function public.founder_r3173_pay_month_trend() from public, anon;
grant execute on function public.founder_r3173_pay_month_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3173_capa_status_board()
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
  from public.payroll_compliance_capa_actions_r3173 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3173_capa_status_board() from public, anon;
grant execute on function public.founder_r3173_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3173_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.payroll_compliance_capa_actions_r3173)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.payroll_compliance_capa_actions_r3173 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3173_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3173_root_cause_pareto() to authenticated;

-- 7) Regulatory-impact digest
create or replace function public.founder_r3173_regulatory_impact_digest()
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
  from public.payroll_compliance_capa_actions_r3173 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3173_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3173_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority queue
create or replace function public.founder_r3173_high_risk_queue()
returns table(
  entity_name text,
  entity_state text,
  pay_cycle_label text,
  filing_status text,
  penalty_risk text,
  compliance_verdict text,
  estimated_penalty_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.entity_state, l.pay_cycle_label,
    l.filing_status, l.penalty_risk, l.compliance_verdict,
    coalesce(l.estimated_penalty_rupees,0)::numeric, l.notes
  from public.payroll_compliance_r3173 l
  where l.penalty_risk in ('high','severe','under_notice')
     or l.filing_status in ('not_filed','partially_filed')
     or l.compliance_verdict in ('material_non_compliance','under_remediation','escalated_to_auditor')
  order by coalesce(l.estimated_penalty_rupees,0) desc, l.entity_name;
end;
$$;

revoke execute on function public.founder_r3173_high_risk_queue() from public, anon;
grant execute on function public.founder_r3173_high_risk_queue() to authenticated;
