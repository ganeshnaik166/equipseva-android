-- Round 3408: Engineer Fuel-Card & Expense Fraud / Duplicate-Claim Analytics Tracker
-- Field-engineer expense integrity — fraud verdict × engineer × expense type × region × GPS/fuel-distance checks × duplicate detection × out-of-policy × blacklisted vendor × anomaly score × flagged amount × CAPA recovery

-- =============================================================================
-- TABLE 1: fuel_expense_fraud_r3408 — per-claim fuel-card / expense fraud analytics
-- =============================================================================
create table if not exists public.fuel_expense_fraud_r3408 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null check (region in (
    'north','south','east','west','central'
  )),
  claim_ref text not null,
  expense_type text not null check (expense_type in (
    'fuel','travel','toll','meals','accommodation','consumables','misc'
  )),
  claim_amount_rupees numeric(12,2) not null,
  claim_date date not null,
  receipt_attached boolean not null,
  gps_route_consistent boolean not null,
  fuel_qty_vs_distance_ok boolean,
  duplicate_suspected boolean not null,
  out_of_policy boolean not null,
  weekend_holiday_flag boolean not null,
  vendor_blacklisted boolean not null,
  anomaly_score numeric(4,2),
  flagged_amount_rupees numeric(12,2),
  fraud_verdict text not null check (fraud_verdict in (
    'clean','minor_policy_gap','anomaly_review','duplicate_flagged','fraud_suspected','recovered'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fuel_expense_fraud_r3408 enable row level security;

create index if not exists idx_fuel_expense_fraud_r3408_org on public.fuel_expense_fraud_r3408(organization_id);
create index if not exists idx_fuel_expense_fraud_r3408_date on public.fuel_expense_fraud_r3408(claim_date);
create index if not exists idx_fuel_expense_fraud_r3408_verdict on public.fuel_expense_fraud_r3408(fraud_verdict);

-- =============================================================================
-- TABLE 2: fuel_expense_fraud_capa_actions_r3408 — investigation / recovery / policy actions
-- =============================================================================
create table if not exists public.fuel_expense_fraud_capa_actions_r3408 (
  id uuid primary key default gen_random_uuid(),
  claim_log_id uuid not null references public.fuel_expense_fraud_r3408(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'duplicate_claim','gps_route_mismatch','fuel_qty_distance_mismatch','missing_receipt',
    'out_of_policy_amount','weekend_holiday_claim','blacklisted_vendor','inflated_amount',
    'split_transaction','personal_expense'
  )),
  root_cause text not null check (root_cause in (
    'intentional_fraud','duplicate_submission_error','policy_unaware','receipt_lost',
    'vendor_overcharge','card_misuse','manager_approval_gap','system_dedup_failure',
    'pending_investigation','odometer_tampering'
  )),
  corrective_action text not null check (corrective_action in (
    'recover_from_salary','recover_from_vendor','issue_warning','reject_claim',
    'block_fuel_card','update_expense_policy','retrain_engineer','escalate_to_hr',
    'file_police_complaint','tighten_dedup_rules','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  recovery_status text not null check (recovery_status in (
    'recovered_full','recovered_partial','write_off','pending_recovery','no_loss','disciplinary_action'
  )),
  target_closure_date date,
  actual_closure_date date,
  recovered_amount_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fuel_expense_fraud_capa_actions_r3408 enable row level security;

create index if not exists idx_fuel_expense_fraud_capa_r3408_log on public.fuel_expense_fraud_capa_actions_r3408(claim_log_id);
create index if not exists idx_fuel_expense_fraud_capa_r3408_status on public.fuel_expense_fraud_capa_actions_r3408(capa_status);

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

  -- 14 claim rows
  insert into public.fuel_expense_fraud_r3408 (
    organization_id, engineer_name, region, claim_ref, expense_type, claim_amount_rupees, claim_date,
    receipt_attached, gps_route_consistent, fuel_qty_vs_distance_ok, duplicate_suspected, out_of_policy,
    weekend_holiday_flag, vendor_blacklisted, anomaly_score, flagged_amount_rupees, fraud_verdict, notes
  )
  select v_org_id, q.eng, q.region, q.cref, q.etype, q.amt, q.cdate::date,
    q.receipt, q.gps, q.fuelqty, q.dup, q.oop,
    q.weekend, q.blk, q.anom, q.flag, q.verdict, q.nt
  from (values
    ('Ravi Kumar','south','CLM-2026-0801','fuel',3200.00,'2026-07-05',
     true,true,true,false,false,false,false,0.08,0.00,'clean','Fuel claim matches GPS route and odometer at Apollo Chennai site'),
    ('Suresh Nair','south','CLM-2026-0802','travel',1800.00,'2026-07-05',
     true,true,null,false,false,false,false,0.10,0.00,'clean','Inter-city travel to CMC Vellore — receipts verified'),
    ('Anil Verma','north','CLM-2026-0803','fuel',5400.00,'2026-07-04',
     true,false,false,false,false,false,false,0.62,1800.00,'anomaly_review','Fuel qty exceeds distance and GPS route deviates near AIIMS Delhi — under review'),
    ('Deepak Sharma','north','CLM-2026-0804','fuel',4200.00,'2026-07-04',
     true,true,true,true,false,false,false,0.74,4200.00,'duplicate_flagged','Same fuel receipt submitted twice within 48h — duplicate flagged'),
    ('Vijay Reddy','south','CLM-2026-0805','meals',900.00,'2026-07-03',
     false,true,null,false,true,false,false,0.45,400.00,'minor_policy_gap','Meal claim missing receipt and above per-diem cap at Manipal Bengaluru'),
    ('Manoj Gupta','west','CLM-2026-0806','toll',650.00,'2026-07-03',
     true,true,null,false,false,false,false,0.09,0.00,'clean','FASTag toll matches logged route to Fortis Mumbai'),
    ('Prakash Iyer','west','CLM-2026-0807','fuel',8900.00,'2026-07-02',
     true,false,false,false,true,true,true,0.93,8900.00,'fraud_suspected','Fuel from blacklisted pump on public holiday, no site visit logged — fraud suspected'),
    ('Sanjay Rao','east','CLM-2026-0808','accommodation',6200.00,'2026-07-02',
     true,true,null,false,true,false,false,0.55,2200.00,'anomaly_review','Hotel above city cap near KIMS Bhubaneswar — pending clarification'),
    ('Ramesh Pillai','south','CLM-2026-0809','consumables',1500.00,'2026-07-01',
     true,true,null,false,false,false,false,0.12,0.00,'clean','Spare-part reimbursement verified against work order at Fortis Gurgaon'),
    ('Anil Verma','north','CLM-2026-0810','fuel',7100.00,'2026-07-01',
     false,false,false,true,true,false,false,0.88,7100.00,'fraud_suspected','Missing receipt, duplicate ref and fuel-distance mismatch — recovery initiated'),
    ('Deepak Sharma','north','CLM-2026-0811','fuel',3600.00,'2026-06-30',
     true,true,true,false,false,false,false,0.71,3600.00,'recovered','Earlier over-claim recovered in full from salary — closed'),
    ('Manoj Gupta','west','CLM-2026-0812','misc',2400.00,'2026-06-30',
     false,true,null,false,true,true,false,0.40,1200.00,'minor_policy_gap','Misc claim on weekend without pre-approval — receipt missing'),
    ('Vijay Reddy','south','CLM-2026-0813','travel',2100.00,'2026-06-29',
     true,true,null,false,false,false,false,0.11,0.00,'clean','Auto and taxi travel within policy at Manipal Bengaluru'),
    ('Prakash Iyer','west','CLM-2026-0814','fuel',5300.00,'2026-06-29',
     true,false,false,true,false,false,true,0.81,5300.00,'duplicate_flagged','Duplicate fuel receipt from blacklisted vendor — flagged for recovery')
  ) as q(eng, region, cref, etype, amt, cdate, receipt, gps, fuelqty, dup, oop, weekend, blk, anom, flag, verdict, nt);

  -- CAPA seed — attach to specific claims via claim_ref
  insert into public.fuel_expense_fraud_capa_actions_r3408 (
    claim_log_id, finding_category, root_cause, corrective_action,
    capa_status, recovery_status, target_closure_date, actual_closure_date,
    recovered_amount_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.rst, q.tcd::date, q.acd::date,
    q.recov, q.nt
  from (values
    ('CLM-2026-0804','duplicate_claim','duplicate_submission_error','reject_claim','closed','no_loss','2026-07-07','2026-07-06',0.00,'Duplicate rejected before payout — no financial loss'),
    ('CLM-2026-0807','blacklisted_vendor','intentional_fraud','block_fuel_card','escalated','disciplinary_action','2026-07-08',null,0.00,'Fuel card blocked; HR disciplinary and police complaint underway'),
    ('CLM-2026-0810','fuel_qty_distance_mismatch','odometer_tampering','recover_from_salary','in_progress','recovered_partial','2026-07-09',null,3500.00,'Partial recovery deducted from salary; balance pending'),
    ('CLM-2026-0803','gps_route_mismatch','pending_investigation','issue_warning','in_progress','pending_recovery','2026-07-08',null,0.00,'Route deviation under investigation — warning issued to engineer'),
    ('CLM-2026-0805','missing_receipt','receipt_lost','update_expense_policy','verification_pending','no_loss','2026-07-06',null,0.00,'Reminded on per-diem policy; receipt waiver logged for review'),
    ('CLM-2026-0814','duplicate_claim','vendor_overcharge','recover_from_vendor','open','pending_recovery','2026-07-10',null,0.00,'Blacklisted vendor duplicate — recovery claim raised against vendor'),
    ('CLM-2026-0808','out_of_policy_amount','policy_unaware','retrain_engineer','overdue','write_off','2026-06-30',null,0.00,'Hotel over-cap written off; engineer retraining overdue')
  ) as q(cref, fc, rc, ca, cst, rst, tcd, acd, recov, nt)
  join public.fuel_expense_fraud_r3408 e
    on e.organization_id = v_org_id and e.claim_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Fraud verdict distribution
create or replace function public.founder_r3408_fraud_verdict_rollup()
returns table(fraud_verdict text, claims bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fuel_expense_fraud_r3408)
  select l.fraud_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fuel_expense_fraud_r3408 l
  group by l.fraud_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3408_fraud_verdict_rollup() from public, anon;
grant execute on function public.founder_r3408_fraud_verdict_rollup() to authenticated;

-- 2) Engineer-level fraud scorecard
create or replace function public.founder_r3408_engineer_scorecard()
returns table(
  engineer_name text,
  total_claims bigint,
  clean bigint,
  anomaly_review bigint,
  fraud_flagged bigint,
  duplicate_suspected bigint,
  out_of_policy bigint,
  total_flagged_rupees numeric,
  clean_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.fraud_verdict = 'clean')::bigint,
    count(*) filter (where l.fraud_verdict = 'anomaly_review')::bigint,
    count(*) filter (where l.fraud_verdict in ('duplicate_flagged','fraud_suspected'))::bigint,
    count(*) filter (where l.duplicate_suspected = true)::bigint,
    count(*) filter (where l.out_of_policy = true)::bigint,
    coalesce(sum(l.flagged_amount_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.fraud_verdict = 'clean')::numeric / nullif(count(*),0), 1)
  from public.fuel_expense_fraud_r3408 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3408_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3408_engineer_scorecard() to authenticated;

-- 3) Expense-type × region matrix
create or replace function public.founder_r3408_expense_type_region_matrix()
returns table(expense_type text, region text, claims bigint, flagged bigint, total_flagged_rupees numeric, avg_anomaly_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.expense_type, l.region, count(*)::bigint,
    count(*) filter (where l.fraud_verdict in ('anomaly_review','duplicate_flagged','fraud_suspected'))::bigint,
    coalesce(sum(l.flagged_amount_rupees),0)::numeric,
    round(avg(l.anomaly_score), 2)
  from public.fuel_expense_fraud_r3408 l
  group by l.expense_type, l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3408_expense_type_region_matrix() from public, anon;
grant execute on function public.founder_r3408_expense_type_region_matrix() to authenticated;

-- 4) Daily claim trend
create or replace function public.founder_r3408_daily_claim_trend()
returns table(claim_date date, claims bigint, clean bigint, flagged bigint, duplicate_suspected bigint, total_flagged_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.claim_date,
    count(*)::bigint,
    count(*) filter (where l.fraud_verdict = 'clean')::bigint,
    count(*) filter (where l.fraud_verdict in ('anomaly_review','duplicate_flagged','fraud_suspected'))::bigint,
    count(*) filter (where l.duplicate_suspected = true)::bigint,
    coalesce(sum(l.flagged_amount_rupees),0)::numeric
  from public.fuel_expense_fraud_r3408 l
  group by l.claim_date
  order by l.claim_date desc;
end;
$$;

revoke execute on function public.founder_r3408_daily_claim_trend() from public, anon;
grant execute on function public.founder_r3408_daily_claim_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3408_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovered_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovered_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.fuel_expense_fraud_capa_actions_r3408 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3408_capa_status_board() from public, anon;
grant execute on function public.founder_r3408_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3408_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovered_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fuel_expense_fraud_capa_actions_r3408)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovered_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fuel_expense_fraud_capa_actions_r3408 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3408_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3408_root_cause_pareto() to authenticated;

-- 7) Recovery impact digest
create or replace function public.founder_r3408_recovery_impact_digest()
returns table(recovery_status text, findings bigint, open_findings bigint, total_recovered_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.recovery_status, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.recovered_amount_rupees),0)::numeric
  from public.fuel_expense_fraud_capa_actions_r3408 c
  group by c.recovery_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3408_recovery_impact_digest() from public, anon;
grant execute on function public.founder_r3408_recovery_impact_digest() to authenticated;

-- 8) High-risk claim queue (top individual concerns)
create or replace function public.founder_r3408_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  claim_ref text,
  expense_type text,
  claim_date date,
  fraud_verdict text,
  claim_amount_rupees numeric,
  flagged_amount_rupees numeric,
  anomaly_score numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.claim_ref, l.expense_type, l.claim_date,
    l.fraud_verdict, l.claim_amount_rupees, l.flagged_amount_rupees, l.anomaly_score, l.notes
  from public.fuel_expense_fraud_r3408 l
  where l.fraud_verdict in ('anomaly_review','duplicate_flagged','fraud_suspected')
     or l.duplicate_suspected = true
     or l.out_of_policy = true
     or l.vendor_blacklisted = true
     or l.gps_route_consistent = false
     or l.fuel_qty_vs_distance_ok = false
     or l.receipt_attached = false
     or l.weekend_holiday_flag = true
  order by l.anomaly_score desc nulls last, l.claim_date desc;
end;
$$;

revoke execute on function public.founder_r3408_high_risk_queue() from public, anon;
grant execute on function public.founder_r3408_high_risk_queue() to authenticated;
