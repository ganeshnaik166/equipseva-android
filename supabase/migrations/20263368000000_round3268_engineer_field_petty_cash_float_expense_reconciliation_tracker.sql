-- Round 3268: Engineer Field Petty-Cash Float & Expense-Reconciliation Tracker
-- Field-ops discipline — float issued × spend × receipts submitted × unreconciled balance × missing receipts × spend category × policy violation × settlement × recon verdict × CAPA recovery

-- =============================================================================
-- TABLE 1: petty_cash_float_r3268 — per engineer float-cycle reconciliation
-- =============================================================================
create table if not exists public.petty_cash_float_r3268 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  cycle_month text not null,
  float_issued_rupees numeric(12,2) not null,
  spent_rupees numeric(12,2) not null,
  receipts_submitted_rupees numeric(12,2) not null,
  unreconciled_rupees numeric(12,2) not null,
  receipts_count int not null,
  missing_receipt_count int not null,
  days_to_reconcile int,
  top_spend_category text not null check (top_spend_category in (
    'spares','travel_fuel','consumables','customer_hospitality','tools','misc'
  )),
  policy_violation text not null check (policy_violation in (
    'none','over_limit_item','missing_gst_bill','personal_expense','duplicate_claim'
  )),
  settlement_status text not null check (settlement_status in (
    'settled','partially_settled','pending','disputed','recovered_from_salary'
  )),
  recon_verdict text not null check (recon_verdict in (
    'clean','minor_gaps','major_gaps','escalated'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.petty_cash_float_r3268 enable row level security;

create index if not exists idx_petty_cash_float_r3268_org on public.petty_cash_float_r3268(organization_id);
create index if not exists idx_petty_cash_float_r3268_cycle on public.petty_cash_float_r3268(cycle_month);
create index if not exists idx_petty_cash_float_r3268_verdict on public.petty_cash_float_r3268(recon_verdict);

-- =============================================================================
-- TABLE 2: petty_cash_float_capa_actions_r3268 — recovery & policy CAPA actions
-- =============================================================================
create table if not exists public.petty_cash_float_capa_actions_r3268 (
  id uuid primary key default gen_random_uuid(),
  cycle_log_id uuid not null references public.petty_cash_float_r3268(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'unreconciled_balance','missing_receipts','over_limit_spend','personal_expense_claim',
    'duplicate_claim','missing_gst_bill','delayed_reconciliation','float_top_up_misuse'
  )),
  root_cause text not null check (root_cause in (
    'receipt_not_collected','vendor_no_gst_bill','engineer_negligence','policy_unaware',
    'genuine_emergency_spend','system_entry_error','fraud_suspected','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recover_from_salary','collect_missing_receipts','reissue_reduced_float','retrain_engineer',
    'escalate_to_finance','write_off_approved','freeze_float','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact text not null check (financial_impact in (
    'recoverable','write_off','disputed','none','under_review','fraud_flagged'
  )),
  target_closure_date date,
  actual_closure_date date,
  recovery_amount_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.petty_cash_float_capa_actions_r3268 enable row level security;

create index if not exists idx_petty_cash_capa_r3268_log on public.petty_cash_float_capa_actions_r3268(cycle_log_id);
create index if not exists idx_petty_cash_capa_r3268_status on public.petty_cash_float_capa_actions_r3268(capa_status);

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

  -- 14 float-cycle reconciliation rows
  insert into public.petty_cash_float_r3268 (
    organization_id, engineer_name, region, cycle_month,
    float_issued_rupees, spent_rupees, receipts_submitted_rupees, unreconciled_rupees,
    receipts_count, missing_receipt_count, days_to_reconcile,
    top_spend_category, policy_violation, settlement_status, recon_verdict, notes
  )
  select v_org_id, q.eng, q.region, q.cyc,
    q.fi, q.sp, q.rs, q.unr,
    q.rc, q.mrc, q.dtr,
    q.tsc, q.pv, q.ss, q.rv, q.nt
  from (values
    ('Ramesh Iyer','South','2026-06',
     50000,46200,46200,0,18,0,6,'spares','none','settled','clean','All receipts matched — Apollo Chennai spares zone'),
    ('Suresh Nair','South','2026-06',
     40000,38500,36000,2500,14,1,12,'travel_fuel','missing_gst_bill','partially_settled','minor_gaps','One diesel bill without GST — Manipal Bengaluru route'),
    ('Vijay Kumar','North','2026-06',
     60000,61800,52000,9800,20,3,21,'consumables','over_limit_item','disputed','major_gaps','Over-limit consumable purchase at AIIMS Delhi — disputed'),
    ('Anil Sharma','North','2026-06',
     45000,42000,42000,0,16,0,5,'spares','none','settled','clean','Fortis Gurgaon — clean float cycle'),
    ('Praveen Rao','South','2026-06',
     55000,58900,41000,17900,15,5,28,'customer_hospitality','personal_expense','recovered_from_salary','escalated','Personal dinner claim flagged — KIMS Hyderabad; salary recovery raised'),
    ('Deepak Menon','West','2026-06',
     50000,47500,45000,2500,17,1,14,'travel_fuel','none','partially_settled','minor_gaps','Toll receipt lost — small unreconciled gap'),
    ('Karthik Reddy','South','2026-06',
     35000,33200,33200,0,12,0,7,'tools','none','settled','clean','CMC Vellore — torque tools bought, all billed'),
    ('Manoj Pillai','South','2026-05',
     50000,51500,44000,7500,19,4,19,'spares','duplicate_claim','disputed','major_gaps','Duplicate spare invoice submitted — under review'),
    ('Sanjay Gupta','North','2026-05',
     45000,43800,43800,0,15,0,9,'consumables','none','settled','clean','AIIMS Delhi — consumables cycle clean'),
    ('Rakesh Verma','West','2026-06',
     40000,39000,37500,1500,13,1,11,'misc','missing_gst_bill','partially_settled','minor_gaps','Courier bill without GST — chase vendor'),
    ('Arun Prasad','East','2026-06',
     48000,52000,38000,14000,14,6,30,'travel_fuel','over_limit_item','disputed','escalated','Excess airfare vs travel policy — escalated to finance'),
    ('Naveen Joshi','West','2026-05',
     50000,48000,48000,0,20,0,8,'spares','none','settled','clean','Post-cycle audit clean — Mumbai zone'),
    ('Ganesh Babu','South','2026-06',
     42000,40500,40500,0,16,0,6,'consumables','none','settled','clean','Manipal Bengaluru — consumables clean'),
    ('Imran Sheikh','North','2026-05',
     55000,57200,49000,8200,18,2,24,'customer_hospitality','personal_expense','recovered_from_salary','major_gaps','Gift purchase not policy-approved — Fortis Gurgaon; recovered from salary')
  ) as q(eng, region, cyc, fi, sp, rs, unr, rc, mrc, dtr, tsc, pv, ss, rv, nt);

  -- CAPA seed — attach to at-risk cycles via engineer + cycle_month
  insert into public.petty_cash_float_capa_actions_r3268 (
    cycle_log_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact, target_closure_date, actual_closure_date,
    recovery_amount_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.ramt, q.nt
  from (values
    ('Vijay Kumar','2026-06','over_limit_spend','policy_unaware','retrain_engineer','in_progress','disputed','2026-07-15',null,9800.00,'Over-limit consumable — engineer retrained on spend limits; amount disputed'),
    ('Praveen Rao','2026-06','personal_expense_claim','engineer_negligence','recover_from_salary','closed','recoverable','2026-06-30','2026-07-05',17900.00,'Personal hospitality claim recovered from salary in full'),
    ('Manoj Pillai','2026-05','duplicate_claim','system_entry_error','collect_missing_receipts','verification_pending','under_review','2026-07-10',null,7500.00,'Duplicate spare invoice — verifying original vendor copies'),
    ('Arun Prasad','2026-06','over_limit_spend','genuine_emergency_spend','escalate_to_finance','escalated','disputed','2026-07-12',null,14000.00,'Excess airfare — emergency travel; finance to approve exception or recover'),
    ('Imran Sheikh','2026-05','personal_expense_claim','policy_unaware','recover_from_salary','closed','recoverable','2026-06-28','2026-07-02',8200.00,'Non-approved gift purchase recovered from salary'),
    ('Suresh Nair','2026-06','missing_gst_bill','vendor_no_gst_bill','collect_missing_receipts','open','recoverable','2026-07-20',null,2500.00,'Fuel vendor to reissue GST-compliant bill for reconciliation')
  ) as q(eng, cyc, fc, rc, ca, cst, fi, tcd, acd, ramt, nt)
  join public.petty_cash_float_r3268 e
    on e.organization_id = v_org_id and e.engineer_name = q.eng and e.cycle_month = q.cyc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Reconciliation verdict distribution
create or replace function public.founder_r3268_recon_verdict_rollup()
returns table(recon_verdict text, cycles bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.petty_cash_float_r3268)
  select l.recon_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.petty_cash_float_r3268 l
  group by l.recon_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3268_recon_verdict_rollup() from public, anon;
grant execute on function public.founder_r3268_recon_verdict_rollup() to authenticated;

-- 2) Region-level reconciliation scorecard
create or replace function public.founder_r3268_region_scorecard()
returns table(
  region text,
  total_cycles bigint,
  clean bigint,
  minor_gaps bigint,
  major_gaps bigint,
  total_unreconciled_rupees numeric,
  total_missing_receipts bigint,
  clean_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.recon_verdict = 'clean')::bigint,
    count(*) filter (where l.recon_verdict = 'minor_gaps')::bigint,
    count(*) filter (where l.recon_verdict in ('major_gaps','escalated'))::bigint,
    coalesce(sum(l.unreconciled_rupees),0)::numeric,
    coalesce(sum(l.missing_receipt_count),0)::bigint,
    round(100.0 * count(*) filter (where l.recon_verdict = 'clean')::numeric / nullif(count(*),0), 1)
  from public.petty_cash_float_r3268 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3268_region_scorecard() from public, anon;
grant execute on function public.founder_r3268_region_scorecard() to authenticated;

-- 3) Spend category × settlement status matrix
create or replace function public.founder_r3268_category_settlement_matrix()
returns table(top_spend_category text, settlement_status text, cycles bigint, clean bigint, avg_spent_rupees numeric, avg_unreconciled_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.top_spend_category, l.settlement_status, count(*)::bigint,
    count(*) filter (where l.recon_verdict = 'clean')::bigint,
    round(avg(l.spent_rupees), 0),
    round(avg(l.unreconciled_rupees), 0)
  from public.petty_cash_float_r3268 l
  group by l.top_spend_category, l.settlement_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3268_category_settlement_matrix() from public, anon;
grant execute on function public.founder_r3268_category_settlement_matrix() to authenticated;

-- 4) Monthly reconciliation trend
create or replace function public.founder_r3268_monthly_recon_trend()
returns table(cycle_month text, cycles bigint, clean bigint, major_gaps bigint, total_unreconciled_rupees numeric, total_missing_receipts bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cycle_month,
    count(*)::bigint,
    count(*) filter (where l.recon_verdict = 'clean')::bigint,
    count(*) filter (where l.recon_verdict in ('major_gaps','escalated'))::bigint,
    coalesce(sum(l.unreconciled_rupees),0)::numeric,
    coalesce(sum(l.missing_receipt_count),0)::bigint
  from public.petty_cash_float_r3268 l
  group by l.cycle_month
  order by l.cycle_month desc;
end;
$$;

revoke execute on function public.founder_r3268_monthly_recon_trend() from public, anon;
grant execute on function public.founder_r3268_monthly_recon_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3268_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovery_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovery_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.petty_cash_float_capa_actions_r3268 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3268_capa_status_board() from public, anon;
grant execute on function public.founder_r3268_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3268_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.petty_cash_float_capa_actions_r3268)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.petty_cash_float_capa_actions_r3268 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3268_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3268_root_cause_pareto() to authenticated;

-- 7) Financial-impact digest
create or replace function public.founder_r3268_financial_impact_digest()
returns table(financial_impact text, findings bigint, open_findings bigint, total_recovery_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.recovery_amount_rupees),0)::numeric
  from public.petty_cash_float_capa_actions_r3268 c
  group by c.financial_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3268_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3268_financial_impact_digest() to authenticated;

-- 8) High-risk reconciliation queue (top individual concerns)
create or replace function public.founder_r3268_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  cycle_month text,
  unreconciled_rupees numeric,
  missing_receipt_count int,
  top_spend_category text,
  policy_violation text,
  settlement_status text,
  recon_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.cycle_month, l.unreconciled_rupees,
    l.missing_receipt_count, l.top_spend_category, l.policy_violation,
    l.settlement_status, l.recon_verdict, l.notes
  from public.petty_cash_float_r3268 l
  where l.recon_verdict in ('minor_gaps','major_gaps','escalated')
     or l.policy_violation <> 'none'
     or l.settlement_status in ('disputed','recovered_from_salary')
     or l.missing_receipt_count > 0
  order by l.unreconciled_rupees desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3268_high_risk_queue() from public, anon;
grant execute on function public.founder_r3268_high_risk_queue() to authenticated;
