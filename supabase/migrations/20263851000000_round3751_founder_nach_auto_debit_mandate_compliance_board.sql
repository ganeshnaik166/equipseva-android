-- Round 3751: Founder NACH / Auto-Debit Mandate Compliance Board
-- Customer AMC/EMI NACH auto-debit mandate compliance — registration status, debit success rate,
-- bounce/reversal handling, mandate expiry. Tracks the payment-COLLECTION mechanism itself,
-- distinct from generic AMC contract-renewal/price-escalation boards.

-- =============================================================================
-- TABLE 1: nach_mandate_r3751 — per-customer NACH/auto-debit mandate facts
-- =============================================================================
create table if not exists public.nach_mandate_r3751 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_name text not null,
  mandate_type text not null,
  period_month date not null,
  mandate_ref text,
  mandate_registered_date date,
  mandate_expiry_date date,
  debits_attempted int,
  debits_successful int,
  debit_success_pct numeric,
  bounced_debits int,
  bounce_reason text,
  amount_at_risk_rupees numeric(12,2),
  mandate_class text not null check (mandate_class in (
    'nach_amc_recurring','nach_emi','e_mandate_upi','physical_ecs','one_time_debit'
  )),
  mandate_status text not null check (mandate_status in (
    'active_healthy','active_bounce_risk','expiring_soon','lapsed','revoked_by_customer'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nach_mandate_r3751 enable row level security;

create index if not exists idx_nach_mandate_r3751_org on public.nach_mandate_r3751(organization_id);
create index if not exists idx_nach_mandate_r3751_month on public.nach_mandate_r3751(period_month);
create index if not exists idx_nach_mandate_r3751_status on public.nach_mandate_r3751(mandate_status);

-- =============================================================================
-- TABLE 2: nach_mandate_capa_actions_r3751 — CAPA & mandate-remediation actions
-- =============================================================================
create table if not exists public.nach_mandate_capa_actions_r3751 (
  id uuid primary key default gen_random_uuid(),
  mandate_id uuid references public.nach_mandate_r3751(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nach_mandate_capa_actions_r3751 enable row level security;

create index if not exists idx_nach_mandate_capa_r3751_mandate on public.nach_mandate_capa_actions_r3751(mandate_id);
create index if not exists idx_nach_mandate_capa_r3751_status on public.nach_mandate_capa_actions_r3751(capa_status);

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

  -- 16 NACH mandate rows
  insert into public.nach_mandate_r3751 (
    organization_id, customer_name, mandate_type, period_month, mandate_ref,
    mandate_registered_date, mandate_expiry_date, debits_attempted, debits_successful,
    debit_success_pct, bounced_debits, bounce_reason, amount_at_risk_rupees,
    mandate_class, mandate_status, trend_dir, notes
  )
  select v_org_id, q.cust, q.mtyp, q.pm::date, q.mref,
    q.mrd::date, q.med::date, q.datt::int, q.dsuc::int,
    q.dpct::numeric, q.bdeb::int, q.brsn, q.risk::numeric,
    q.mcls, q.mst, q.trd, q.nt
  from (values
    ('Reliance Retail FM','AMC Quarterly',        '2026-07-01','NACH-RR-1042','2025-04-10','2028-04-10',3,3,100.0,0,null,0.00,'nach_amc_recurring','active_healthy','stable','HDFC mandate — three consecutive quarters cleared on first attempt'),
    ('Tata Steel Plant-3','EMI 24-Month',         '2026-07-01','NACH-TS-2231','2025-01-15','2027-01-15',12,12,100.0,0,null,0.00,'nach_emi','active_healthy','stable','Compressor EMI — zero bounce history since inception'),
    ('Adani Ports Mundra','AMC Annual',           '2026-06-01','NACH-AP-3390','2024-11-20','2026-11-20',1,1,100.0,0,null,0.00,'nach_amc_recurring','active_healthy','improving','Crane AMC — moved from cheque to NACH last cycle, clean debit'),
    ('Infosys Campus Facilities','AMC Quarterly', '2026-07-01','NACH-INF-0087','2025-06-05','2026-09-05',3,2,66.7,1,'insufficient_funds',85000.00,'nach_amc_recurring','active_bounce_risk','worsening','Second consecutive bounce — finance escalated to vendor desk'),
    ('Godrej Agrovet Unit-2','EMI 12-Month',      '2026-07-01','NACH-GA-5512','2025-08-01','2026-08-01',7,5,71.4,2,'insufficient_funds',142000.00,'nach_emi','active_bounce_risk','worsening','Two bounces in trailing 90 days — mandate nearing expiry too'),
    ('Mahindra Logistics Hub','E-Mandate UPI',    '2026-07-01','UPI-ML-7781','2026-01-12','2027-01-12',6,6,100.0,0,null,0.00,'e_mandate_upi','active_healthy','stable','Auto-pay via UPI — no manual intervention needed'),
    ('DHL Supply Chain WH-4','AMC Semi-Annual',   '2026-06-01','NACH-DHL-9021','2025-03-01','2026-09-01',2,2,100.0,0,null,0.00,'nach_amc_recurring','expiring_soon','stable','Mandate lapses in under 45 days — renewal form sent to customer'),
    ('Blue Dart Express Depot','EMI 18-Month',    '2026-07-01','NACH-BD-4456','2024-10-10','2026-04-10',18,15,83.3,3,'account_closed',96000.00,'nach_emi','lapsed','worsening','Underlying account closed — collections team pursuing fresh mandate'),
    ('Amazon India FC-Blr','AMC Quarterly',       '2026-07-01','NACH-AIF-1190','2025-05-22','2028-05-22',3,3,100.0,0,null,0.00,'nach_amc_recurring','active_healthy','stable','Forklift fleet AMC — SBI mandate performing well'),
    ('Flipkart Fulfilment Ctr','One-Time Debit',  '2026-05-01','OTD-FK-6603',null,null,1,1,100.0,0,null,0.00,'one_time_debit','active_healthy','stable','Emergency repair — single approved debit, no recurring mandate'),
    ('Larsen & Toubro Yard-2','EMI 24-Month',     '2026-06-01','NACH-LT-8817','2025-02-18','2027-02-18',6,3,50.0,3,'signature_mismatch',210000.00,'nach_emi','active_bounce_risk','worsening','Bank rejected on signature mismatch thrice — re-registration initiated'),
    ('Ultratech Cement Depot','AMC Annual',       '2026-05-01','NACH-UC-2245','2024-09-30','2025-09-30',1,0,0.0,1,'mandate_expired',68000.00,'nach_amc_recurring','lapsed','worsening','Mandate expired before debit date — no valid authorization on file'),
    ('JSW Steel Vijayanagar','Physical ECS',      '2026-06-01','ECS-JSW-0099','2023-12-01','2026-12-01',1,1,100.0,0,null,0.00,'physical_ecs','expiring_soon','stable','Legacy ECS form — migrating to NACH before next renewal cycle'),
    ('Cipla Warehousing','E-Mandate UPI',         '2026-07-01','UPI-CIP-3321','2026-02-01','2027-02-01',3,3,100.0,0,null,0.00,'e_mandate_upi','active_healthy','improving','Switched from NACH to UPI e-mandate — faster settlement'),
    ('Britannia Cold Chain','EMI 12-Month',       '2026-07-01','NACH-BR-6674','2025-09-15','2026-09-15',10,9,90.0,1,'insufficient_funds',34000.00,'nach_emi','active_bounce_risk','stable','Single bounce recovered next cycle — customer cleared arrears'),
    ('Zomato Dark Store Ntwk','AMC Quarterly',    '2026-06-01','NACH-ZM-4482','2025-07-01','2026-07-01',2,2,100.0,0,null,0.00,'nach_amc_recurring','revoked_by_customer','worsening','Customer cancelled mandate at bank — switching to manual invoicing')
  ) as q(cust, mtyp, pm, mref, mrd, med, datt, dsuc, dpct, bdeb, brsn, risk, mcls, mst, trd, nt);

  -- CAPA seed — attach to mandates via mandate_ref
  insert into public.nach_mandate_capa_actions_r3751 (
    mandate_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('NACH-INF-0087','insufficient_funds_recurring','notify_customer_reattempt_debit','in_progress','Collections Lead','2026-08-20',null,'Second reattempt scheduled after payroll credit date'),
    ('NACH-GA-5512','insufficient_funds_recurring','shift_debit_date_post_payroll','open','Collections Lead','2026-08-25',null,'Aligning debit date to customer payroll cycle to cut bounces'),
    ('NACH-BD-4456','underlying_account_closed','register_fresh_mandate_new_account','open','Key Account Manager','2026-09-05',null,'Customer confirmed new operating account — fresh NACH form issued'),
    ('NACH-LT-8817','signature_mismatch_bank_reject','re_register_mandate_updated_kyc','in_progress','Key Account Manager','2026-08-18',null,'Updated signatory KYC submitted to bank for re-registration'),
    ('NACH-UC-2245','mandate_expired_not_renewed','register_fresh_mandate_new_account','overdue','Finance Ops Manager','2026-07-31',null,'Renewal form pending customer signature — 30 days past target'),
    ('ECS-JSW-0099','legacy_ecs_migration_pending','migrate_ecs_to_nach','in_progress','Finance Ops Manager','2026-09-30',null,'Bank onboarding for NACH replacement of legacy ECS in progress'),
    ('NACH-BR-6674','insufficient_funds_recurring','notify_customer_reattempt_debit','closed','Collections Lead','2026-07-20','2026-07-18','Arrears cleared on reattempt — mandate healthy again'),
    ('NACH-ZM-4482','customer_revoked_mandate','switch_to_manual_invoicing','closed','Key Account Manager','2026-08-05','2026-08-02','Manual invoicing process activated per customer request')
  ) as q(mref, rc, ca, cst, ownr, tcd, acd, nt)
  join public.nach_mandate_r3751 e
    on e.organization_id = v_org_id and e.mandate_ref = q.mref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Mandate-status distribution
create or replace function public.founder_r3751_mandate_status_rollup()
returns table(mandate_status text, mandates bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nach_mandate_r3751)
  select l.mandate_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nach_mandate_r3751 l
  group by l.mandate_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3751_mandate_status_rollup() from public, anon;
grant execute on function public.founder_r3751_mandate_status_rollup() to authenticated;

-- 2) Customer scorecard
create or replace function public.founder_r3751_customer_scorecard()
returns table(
  customer_name text,
  mandates bigint,
  active_healthy bigint,
  active_bounce_risk bigint,
  lapsed_or_revoked bigint,
  debits_attempted_total bigint,
  debits_successful_total bigint,
  avg_debit_success_pct numeric,
  amount_at_risk_total_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_name,
    count(*)::bigint,
    count(*) filter (where l.mandate_status = 'active_healthy')::bigint,
    count(*) filter (where l.mandate_status = 'active_bounce_risk')::bigint,
    count(*) filter (where l.mandate_status in ('lapsed','revoked_by_customer'))::bigint,
    coalesce(sum(l.debits_attempted),0)::bigint,
    coalesce(sum(l.debits_successful),0)::bigint,
    round(avg(l.debit_success_pct), 1),
    coalesce(sum(l.amount_at_risk_rupees),0)::numeric
  from public.nach_mandate_r3751 l
  group by l.customer_name
  order by coalesce(sum(l.amount_at_risk_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3751_customer_scorecard() from public, anon;
grant execute on function public.founder_r3751_customer_scorecard() to authenticated;

-- 3) Mandate-class × mandate-status matrix
create or replace function public.founder_r3751_mandate_class_status_matrix()
returns table(mandate_class text, mandate_status text, mandates bigint, avg_debit_success_pct numeric, amount_at_risk_total_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.mandate_class, l.mandate_status, count(*)::bigint,
    round(avg(l.debit_success_pct), 1),
    coalesce(sum(l.amount_at_risk_rupees),0)::numeric
  from public.nach_mandate_r3751 l
  group by l.mandate_class, l.mandate_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3751_mandate_class_status_matrix() from public, anon;
grant execute on function public.founder_r3751_mandate_class_status_matrix() to authenticated;

-- 4) Monthly debit success-rate trend
create or replace function public.founder_r3751_monthly_success_rate_trend()
returns table(period_month date, mandates bigint, debits_attempted_total bigint, debits_successful_total bigint, avg_debit_success_pct numeric, bounced_debits_total bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.debits_attempted),0)::bigint,
    coalesce(sum(l.debits_successful),0)::bigint,
    round(avg(l.debit_success_pct), 1),
    coalesce(sum(l.bounced_debits),0)::bigint
  from public.nach_mandate_r3751 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3751_monthly_success_rate_trend() from public, anon;
grant execute on function public.founder_r3751_monthly_success_rate_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3751_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.nach_mandate_capa_actions_r3751 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3751_capa_status_board() from public, anon;
grant execute on function public.founder_r3751_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3751_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nach_mandate_capa_actions_r3751)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nach_mandate_capa_actions_r3751 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3751_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3751_root_cause_pareto() to authenticated;

-- 7) Bounce digest — customers/months with active bounce activity
create or replace function public.founder_r3751_bounce_digest()
returns table(
  customer_name text,
  period_month date,
  mandate_class text,
  bounced_debits int,
  bounce_reason text,
  amount_at_risk_rupees numeric,
  trend_dir text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_name, l.period_month, l.mandate_class,
    l.bounced_debits, l.bounce_reason, l.amount_at_risk_rupees, l.trend_dir
  from public.nach_mandate_r3751 l
  where coalesce(l.bounced_debits,0) > 0
  order by l.amount_at_risk_rupees desc nulls last, l.bounced_debits desc;
end;
$$;

revoke all on function public.founder_r3751_bounce_digest() from public, anon;
grant execute on function public.founder_r3751_bounce_digest() to authenticated;

-- 8) High-risk mandate queue (lapsed, revoked, expiring soon, active bounce risk)
create or replace function public.founder_r3751_high_risk_queue()
returns table(
  customer_name text,
  mandate_type text,
  mandate_class text,
  mandate_status text,
  period_month date,
  mandate_expiry_date date,
  debit_success_pct numeric,
  amount_at_risk_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_name, l.mandate_type, l.mandate_class, l.mandate_status,
    l.period_month, l.mandate_expiry_date, l.debit_success_pct,
    l.amount_at_risk_rupees, l.notes
  from public.nach_mandate_r3751 l
  where l.mandate_status in ('lapsed','revoked_by_customer','active_bounce_risk','expiring_soon')
  order by l.mandate_expiry_date asc nulls last, l.amount_at_risk_rupees desc nulls last
  limit 20;
end;
$$;

revoke all on function public.founder_r3751_high_risk_queue() from public, anon;
grant execute on function public.founder_r3751_high_risk_queue() to authenticated;
