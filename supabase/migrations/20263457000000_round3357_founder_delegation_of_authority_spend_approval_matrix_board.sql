-- Round 3357: Founder Delegation-of-Authority (DoA) & Spend-Approval-Matrix Compliance Board
-- Spend/commitment approval log — category × amount × required vs actual approver level × within-authority × exception flag × audit-trail × DoA verdict × CAPA

-- =============================================================================
-- TABLE 1: doa_spend_approvals_r3357 — individual spend/commitment approvals
-- =============================================================================
create table if not exists public.doa_spend_approvals_r3357 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  transaction_ref text not null,
  category text not null check (category in (
    'capex','opex_spare_purchase','vendor_contract','discount_approval',
    'write_off','hiring_offer','credit_note','travel_expense'
  )),
  amount_rupees numeric(14,2) not null,
  initiated_by text not null,
  required_approver_level text not null check (required_approver_level in (
    'l1_manager','l2_head','l3_director','founder','board'
  )),
  actual_approver_level text check (actual_approver_level in (
    'l1_manager','l2_head','l3_director','founder','board'
  )),
  within_authority boolean not null,
  approval_date date not null,
  sla_days_to_approve numeric(6,1),
  exception_flag text not null check (exception_flag in (
    'compliant','over_limit_self_approved','skip_level','post_facto','missing_approval','split_to_avoid_limit'
  )),
  audit_trail_complete boolean not null,
  doa_verdict text not null check (doa_verdict in (
    'compliant','minor_deviation','authority_breach','post_facto_regularize','investigate'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.doa_spend_approvals_r3357 enable row level security;

create index if not exists idx_doa_spend_approvals_r3357_org on public.doa_spend_approvals_r3357(organization_id);
create index if not exists idx_doa_spend_approvals_r3357_date on public.doa_spend_approvals_r3357(approval_date);
create index if not exists idx_doa_spend_approvals_r3357_verdict on public.doa_spend_approvals_r3357(doa_verdict);

-- =============================================================================
-- TABLE 2: doa_spend_approvals_capa_actions_r3357 — CAPA & regularization actions
-- =============================================================================
create table if not exists public.doa_spend_approvals_capa_actions_r3357 (
  id uuid primary key default gen_random_uuid(),
  approval_id uuid not null references public.doa_spend_approvals_r3357(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'over_limit_self_approval','skip_level_approval','post_facto_approval','missing_approval',
    'split_transaction','wrong_category_mapping','audit_trail_gap','matrix_not_updated',
    'delegation_expired','board_ratification_pending'
  )),
  root_cause text not null check (root_cause in (
    'matrix_ambiguity','system_workflow_bypass','urgency_pressure','delegation_letter_lapsed',
    'training_gap','approver_unavailable','policy_not_communicated','deliberate_circumvention',
    'pending_investigation','erp_config_error'
  )),
  corrective_action text not null check (corrective_action in (
    'regularize_with_correct_approver','update_authority_matrix','board_ratification',
    'recover_or_reverse_spend','enforce_erp_workflow_block','retrain_initiators',
    'reissue_delegation_letter','disciplinary_action','tighten_split_detection','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'companies_act_sec188_rpt','income_tax_disallowance','gst_itc_risk','none','internal_only','statutory_audit_qualification'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.doa_spend_approvals_capa_actions_r3357 enable row level security;

create index if not exists idx_doa_capa_r3357_approval on public.doa_spend_approvals_capa_actions_r3357(approval_id);
create index if not exists idx_doa_capa_r3357_status on public.doa_spend_approvals_capa_actions_r3357(capa_status);

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

  -- 14 spend-approval rows
  insert into public.doa_spend_approvals_r3357 (
    organization_id, entity_name, transaction_ref, category, amount_rupees,
    initiated_by, required_approver_level, actual_approver_level, within_authority, approval_date,
    sla_days_to_approve, exception_flag, audit_trail_complete, doa_verdict, notes
  )
  select v_org_id, q.entity, q.tref, q.cat, q.amt,
    q.initby, q.reqlvl, q.actlvl, q.within, q.apdate::date,
    q.sla, q.exc, q.audit, q.verdict, q.nt
  from (values
    ('EquipSeva South — Apollo Chennai','TXN-2026-0412','capex',4500000.00,
     'Ravi Teja Kondapalli','board','board',true,'2026-07-02',
     6.0,'compliant',true,'compliant','New CT-service rig capex — board approved per authority matrix'),
    ('EquipSeva South — Apollo Chennai','TXN-2026-0418','opex_spare_purchase',85000.00,
     'Meghana Rao','l1_manager','l1_manager',true,'2026-07-03',
     1.0,'compliant',true,'compliant','Ventilator spares within L1 manager limit'),
    ('EquipSeva North — Fortis Gurgaon','TXN-2026-0421','vendor_contract',1200000.00,
     'Arjun Nair','l3_director','l2_head',false,'2026-07-01',
     4.0,'skip_level',true,'authority_breach','AMC contract signed by L2 head; matrix required L3 director'),
    ('EquipSeva North — Fortis Gurgaon','TXN-2026-0425','discount_approval',320000.00,
     'Divya Krishnan','l2_head','l2_head',true,'2026-07-04',
     2.0,'compliant',true,'compliant','12 pct discount on Fortis renewal, within L2 band'),
    ('EquipSeva West — KIMS Hyderabad','TXN-2026-0430','write_off',560000.00,
     'Sandeep Kulkarni','founder','l3_director',false,'2026-06-30',
     9.0,'over_limit_self_approved',false,'authority_breach','Bad-debt write-off self-approved by L3 above ceiling; needs founder'),
    ('EquipSeva West — KIMS Hyderabad','TXN-2026-0433','hiring_offer',2800000.00,
     'Farhan Sheikh','founder','founder',true,'2026-06-29',
     5.0,'compliant',true,'compliant','Regional sales-head CTC offer, founder approved'),
    ('EquipSeva Central — AIIMS Delhi','TXN-2026-0440','credit_note',145000.00,
     'Priyanka Chauhan','l2_head','l1_manager',false,'2026-06-28',
     3.0,'skip_level',true,'minor_deviation','Credit note approved one level below; low value, regularized'),
    ('EquipSeva Central — AIIMS Delhi','TXN-2026-0444','travel_expense',48000.00,
     'Vikram Malhotra','l1_manager','l1_manager',true,'2026-07-05',
     1.0,'compliant',true,'compliant','Field-engineer travel reimbursement within L1'),
    ('EquipSeva South — Manipal Bengaluru','TXN-2026-0447','capex',1900000.00,
     'Anusha Reddy','l3_director','l3_director',true,'2026-07-06',
     7.0,'compliant',true,'compliant','Calibration-lab equipment capex, L3 director approved'),
    ('EquipSeva East — CMC Vellore','TXN-2026-0450','vendor_contract',780000.00,
     'Rohit Deshmukh','l3_director',null,false,'2026-06-27',
     12.0,'missing_approval',false,'investigate','PO released to vendor with no recorded approval on file'),
    ('EquipSeva East — CMC Vellore','TXN-2026-0455','opex_spare_purchase',260000.00,
     'Kavya Iyer','l2_head','l2_head',true,'2026-06-26',
     2.0,'compliant',true,'compliant','Bulk ultrasound-probe order, L2 head approved'),
    ('EquipSeva North — Fortis Gurgaon','TXN-2026-0459','discount_approval',95000.00,
     'Joseph Mathew','l1_manager','l1_manager',true,'2026-07-07',
     1.0,'compliant',true,'compliant','5 pct AMC discount within L1 band'),
    ('EquipSeva West — Manipal Bengaluru','TXN-2026-0462','vendor_contract',640000.00,
     'Nandini Prasad','l3_director','l3_director',true,'2026-07-08',
     5.0,'post_facto',true,'post_facto_regularize','Contract signed under urgency, ratified post-facto by L3'),
    ('EquipSeva South — Apollo Chennai','TXN-2026-0466','capex',3200000.00,
     'Suresh Babu Gandham','board','founder',false,'2026-06-25',
     11.0,'split_to_avoid_limit',false,'investigate','Two POs of 16L each to one vendor to stay under board limit')
  ) as q(entity, tref, cat, amt, initby, reqlvl, actlvl, within, apdate, sla, exc, audit, verdict, nt);

  -- CAPA seed — attach to specific approvals by transaction_ref
  insert into public.doa_spend_approvals_capa_actions_r3357 (
    approval_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TXN-2026-0421','skip_level_approval','delegation_letter_lapsed','regularize_with_correct_approver',
     'in_progress','internal_only','2026-07-12',null,15000.00,'L3 delegation letter expired; L2 signed AMC — re-approving with director'),
    ('TXN-2026-0430','over_limit_self_approval','deliberate_circumvention','board_ratification',
     'escalated','statutory_audit_qualification','2026-07-10',null,560000.00,'Write-off above L3 ceiling self-approved; escalated to board + auditor note'),
    ('TXN-2026-0440','skip_level_approval','urgency_pressure','regularize_with_correct_approver',
     'closed','none','2026-07-05','2026-07-04',0.00,'Low-value credit note regularized with L2 sign-off retrospectively'),
    ('TXN-2026-0450','missing_approval','system_workflow_bypass','enforce_erp_workflow_block',
     'open','income_tax_disallowance','2026-07-15',null,780000.00,'PO released bypassing ERP approval gate; workflow block being enforced'),
    ('TXN-2026-0462','post_facto_approval','approver_unavailable','update_authority_matrix',
     'verification_pending','internal_only','2026-07-14',null,10000.00,'Emergency contract; adding urgency-delegation clause to matrix'),
    ('TXN-2026-0466','split_transaction','deliberate_circumvention','tighten_split_detection',
     'escalated','companies_act_sec188_rpt','2026-07-11',null,3200000.00,'Split PO to dodge board limit; same-vendor aggregation control + RPT check'),
    ('TXN-2026-0433','board_ratification_pending','policy_not_communicated','board_ratification',
     'overdue','internal_only','2026-06-30',null,20000.00,'Founder hiring offer needs board comp-committee ratification; past due')
  ) as q(tref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.doa_spend_approvals_r3357 e
    on e.organization_id = v_org_id and e.transaction_ref = q.tref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) DoA verdict distribution
create or replace function public.founder_r3357_doa_verdict_rollup()
returns table(doa_verdict text, approvals bigint, total_amount_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.doa_spend_approvals_r3357)
  select a.doa_verdict, count(*)::bigint,
         coalesce(sum(a.amount_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.doa_spend_approvals_r3357 a
  group by a.doa_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3357_doa_verdict_rollup() from public, anon;
grant execute on function public.founder_r3357_doa_verdict_rollup() to authenticated;

-- 2) Entity / business-unit compliance scorecard
create or replace function public.founder_r3357_entity_scorecard()
returns table(
  entity_name text,
  total_approvals bigint,
  compliant bigint,
  breaches bigint,
  within_authority_ct bigint,
  incomplete_audit_trail bigint,
  total_amount_rupees numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.entity_name,
    count(*)::bigint,
    count(*) filter (where a.doa_verdict = 'compliant')::bigint,
    count(*) filter (where a.doa_verdict in ('authority_breach','investigate'))::bigint,
    count(*) filter (where a.within_authority)::bigint,
    count(*) filter (where a.audit_trail_complete = false)::bigint,
    coalesce(sum(a.amount_rupees),0)::numeric,
    round(100.0 * count(*) filter (where a.doa_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.doa_spend_approvals_r3357 a
  group by a.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3357_entity_scorecard() from public, anon;
grant execute on function public.founder_r3357_entity_scorecard() to authenticated;

-- 3) Category × required-approver-level matrix
create or replace function public.founder_r3357_category_approver_matrix()
returns table(category text, required_approver_level text, approvals bigint, breaches bigint, avg_amount_rupees numeric, avg_sla_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.category, a.required_approver_level, count(*)::bigint,
    count(*) filter (where a.doa_verdict in ('authority_breach','investigate'))::bigint,
    round(avg(a.amount_rupees), 0),
    round(avg(a.sla_days_to_approve), 1)
  from public.doa_spend_approvals_r3357 a
  group by a.category, a.required_approver_level
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3357_category_approver_matrix() from public, anon;
grant execute on function public.founder_r3357_category_approver_matrix() to authenticated;

-- 4) Daily approval trend
create or replace function public.founder_r3357_daily_approval_trend()
returns table(approval_date date, approvals bigint, compliant bigint, breaches bigint, total_amount_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.approval_date,
    count(*)::bigint,
    count(*) filter (where a.doa_verdict = 'compliant')::bigint,
    count(*) filter (where a.doa_verdict in ('authority_breach','investigate'))::bigint,
    coalesce(sum(a.amount_rupees),0)::numeric
  from public.doa_spend_approvals_r3357 a
  group by a.approval_date
  order by a.approval_date desc;
end;
$$;

revoke execute on function public.founder_r3357_daily_approval_trend() from public, anon;
grant execute on function public.founder_r3357_daily_approval_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3357_capa_status_board()
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
  from public.doa_spend_approvals_capa_actions_r3357 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3357_capa_status_board() from public, anon;
grant execute on function public.founder_r3357_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3357_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.doa_spend_approvals_capa_actions_r3357)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.doa_spend_approvals_capa_actions_r3357 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3357_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3357_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3357_regulatory_impact_digest()
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
  from public.doa_spend_approvals_capa_actions_r3357 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3357_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3357_regulatory_impact_digest() to authenticated;

-- 8) High-risk approval queue (top authority concerns)
create or replace function public.founder_r3357_high_risk_queue()
returns table(
  entity_name text,
  transaction_ref text,
  category text,
  amount_rupees numeric,
  required_approver_level text,
  actual_approver_level text,
  exception_flag text,
  doa_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.entity_name, a.transaction_ref, a.category, a.amount_rupees,
    a.required_approver_level, a.actual_approver_level, a.exception_flag, a.doa_verdict, a.notes
  from public.doa_spend_approvals_r3357 a
  where a.doa_verdict in ('minor_deviation','authority_breach','post_facto_regularize','investigate')
     or a.within_authority = false
     or a.exception_flag in ('over_limit_self_approved','skip_level','post_facto','missing_approval','split_to_avoid_limit')
     or a.audit_trail_complete = false
  order by case a.doa_verdict
             when 'investigate' then 0
             when 'authority_breach' then 1
             when 'post_facto_regularize' then 2
             when 'minor_deviation' then 3
             else 4
           end,
           a.approval_date desc, a.entity_name;
end;
$$;

revoke execute on function public.founder_r3357_high_risk_queue() from public, anon;
grant execute on function public.founder_r3357_high_risk_queue() to authenticated;
