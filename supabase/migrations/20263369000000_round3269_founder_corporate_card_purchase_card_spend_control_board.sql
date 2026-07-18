-- Round 3269: Founder Corporate-Card & Purchase-Card Spend-Control Board
-- Card spend governance — cardholder × department × card type × monthly limit × spend × utilization × top merchant × receipts × out-of-policy × flagged amount × payment status × fraud alert × spend verdict × CAPA

-- =============================================================================
-- TABLE 1: corp_card_spend_r3269 — per cardholder / card spend-control record
-- =============================================================================
create table if not exists public.corp_card_spend_r3269 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  cardholder_name text not null,
  department text not null check (department in (
    'field_service','procurement','sales','marketing','ops','founder_office'
  )),
  card_type text not null check (card_type in (
    'corporate_credit','purchase_card','fuel_card','virtual_subscription_card'
  )),
  cycle_close_date date not null,
  monthly_limit_rupees numeric(12,2) not null,
  spent_this_cycle_rupees numeric(12,2) not null,
  utilization_pct numeric(6,2),
  top_merchant_category text not null check (top_merchant_category in (
    'travel','fuel','saas','office_supplies','vendor_payments','meals_entertainment'
  )),
  receipts_attached_pct numeric(5,2),
  out_of_policy_txn_count int not null default 0,
  flagged_amount_rupees numeric(12,2),
  payment_status text not null check (payment_status in (
    'auto_paid','paid_on_time','overdue','disputed'
  )),
  fraud_alert boolean not null default false,
  card_verdict text not null check (card_verdict in (
    'healthy','high_utilization','policy_gaps','overdue_payment','fraud_review','suspend_recommended'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.corp_card_spend_r3269 enable row level security;

create index if not exists idx_corp_card_spend_r3269_org on public.corp_card_spend_r3269(org_id);
create index if not exists idx_corp_card_spend_r3269_cycle on public.corp_card_spend_r3269(cycle_close_date);
create index if not exists idx_corp_card_spend_r3269_verdict on public.corp_card_spend_r3269(card_verdict);

-- =============================================================================
-- TABLE 2: corp_card_spend_capa_actions_r3269 — policy / fraud / limit actions
-- =============================================================================
create table if not exists public.corp_card_spend_capa_actions_r3269 (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references public.corp_card_spend_r3269(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'over_limit_utilization','missing_receipts','out_of_policy_spend','fraud_suspected',
    'overdue_payment','duplicate_transaction','personal_use_on_card','vendor_split_transaction'
  )),
  root_cause text not null check (root_cause in (
    'weak_approval_workflow','no_receipt_capture_habit','limit_set_too_high','compromised_card_number',
    'cardholder_travel_backlog','vendor_billing_error','policy_not_communicated','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'lower_monthly_limit','enforce_receipt_capture','freeze_card','reissue_card_number',
    'clawback_personal_spend','retrain_cardholder','tighten_approval_workflow','escalate_to_finance_head','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  risk_impact text not null check (risk_impact in (
    'financial_leakage','fraud_loss','audit_finding','none','internal_only','board_escalation'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_recovery_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.corp_card_spend_capa_actions_r3269 enable row level security;

create index if not exists idx_corp_card_capa_r3269_card on public.corp_card_spend_capa_actions_r3269(card_id);
create index if not exists idx_corp_card_capa_r3269_status on public.corp_card_spend_capa_actions_r3269(capa_status);

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

  -- 14 cardholder / card spend rows
  insert into public.corp_card_spend_r3269 (
    org_id, cardholder_name, department, card_type, cycle_close_date,
    monthly_limit_rupees, spent_this_cycle_rupees, utilization_pct, top_merchant_category,
    receipts_attached_pct, out_of_policy_txn_count, flagged_amount_rupees,
    payment_status, fraud_alert, card_verdict, notes
  )
  select v_org_id, q.name, q.dept, q.ctype, q.ccd::date,
    q.mlimit, q.spent, q.util, q.tmc,
    q.rcpt, q.oop, q.flag,
    q.pstat, q.fraud, q.verdict, q.nt
  from (values
    ('Rajesh Kumar','field_service','fuel_card','2026-06-30',
     40000,31200,78.00,'fuel',96.00,0,0,'auto_paid',false,'healthy','Fuel spend within norm — all receipts attached'),
    ('Priya Sharma','procurement','purchase_card','2026-06-30',
     500000,472000,94.40,'vendor_payments',88.00,1,45000,'paid_on_time',false,'high_utilization','94% utilization — vendor payments spiked, limit review due'),
    ('Anil Mehta','sales','corporate_credit','2026-06-30',
     150000,98000,65.33,'travel',62.00,3,28000,'paid_on_time',false,'policy_gaps','38% of travel receipts missing — chase submission'),
    ('Sunita Reddy','marketing','virtual_subscription_card','2026-06-30',
     200000,187500,93.75,'saas',100.00,0,0,'auto_paid',false,'high_utilization','SaaS renewals stacked this cycle — near limit'),
    ('Vikram Singh','ops','corporate_credit','2026-06-30',
     120000,61000,50.83,'office_supplies',91.00,0,0,'auto_paid',false,'healthy','Office supplies steady, clean cycle'),
    ('Deepak Nair','founder_office','corporate_credit','2026-05-31',
     300000,142000,47.33,'meals_entertainment',74.00,2,22000,'paid_on_time',false,'policy_gaps','Client dinners over per-head cap twice'),
    ('Kavya Iyer','field_service','fuel_card','2026-06-30',
     35000,41200,117.71,'fuel',80.00,4,18500,'overdue',false,'overdue_payment','Over limit and payment 12 days overdue'),
    ('Manish Gupta','procurement','purchase_card','2026-05-31',
     400000,96000,24.00,'vendor_payments',95.00,0,0,'auto_paid',false,'healthy','Low utilization, fully on-policy'),
    ('Rohan Desai','sales','corporate_credit','2026-06-30',
     150000,133000,88.67,'travel',55.00,5,61000,'disputed',true,'fraud_review','Two unrecognized hotel charges disputed — fraud alert raised'),
    ('Ananya Rao','marketing','virtual_subscription_card','2026-05-31',
     180000,168000,93.33,'saas',90.00,1,12000,'paid_on_time',false,'high_utilization','Duplicate SaaS subscription found — consolidate'),
    ('Suresh Menon','ops','purchase_card','2026-06-30',
     250000,240000,96.00,'office_supplies',70.00,3,35000,'overdue',false,'overdue_payment','Near limit, payment overdue, receipts lagging'),
    ('Neha Joshi','founder_office','virtual_subscription_card','2026-04-30',
     220000,88000,40.00,'saas',98.00,0,0,'auto_paid',false,'healthy','Founder-office SaaS tooling on-policy'),
    ('Arjun Pillai','field_service','corporate_credit','2026-06-30',
     100000,132000,132.00,'travel',40.00,7,95000,'disputed',true,'suspend_recommended','Over limit 32%, heavy out-of-policy travel, fraud pattern — suspend recommended'),
    ('Meera Nambiar','procurement','purchase_card','2026-05-31',
     350000,205000,58.57,'vendor_payments',84.00,2,40000,'paid_on_time',false,'policy_gaps','Two vendor split transactions under approval threshold')
  ) as q(name, dept, ctype, ccd, mlimit, spent, util, tmc, rcpt, oop, flag, pstat, fraud, verdict, nt);

  -- CAPA seed — attach to specific flagged / at-risk cards by cardholder_name
  insert into public.corp_card_spend_capa_actions_r3269 (
    card_id, finding_category, root_cause, corrective_action,
    capa_status, risk_impact, target_closure_date, actual_closure_date,
    estimated_recovery_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.recov, q.nt
  from (values
    ('Priya Sharma','over_limit_utilization','limit_set_too_high','lower_monthly_limit','in_progress','financial_leakage','2026-07-10',null,45000.00,'Limit review with finance — propose 15% cut on purchase card'),
    ('Kavya Iyer','overdue_payment','cardholder_travel_backlog','retrain_cardholder','open','financial_leakage','2026-07-08',null,18500.00,'Over-limit fuel spend, payment chase initiated, statement retrain booked'),
    ('Rohan Desai','fraud_suspected','compromised_card_number','reissue_card_number','escalated','fraud_loss','2026-07-05',null,61000.00,'Disputed hotel charges — card reissue and chargeback filed'),
    ('Suresh Menon','overdue_payment','weak_approval_workflow','tighten_approval_workflow','overdue','audit_finding','2026-06-28',null,35000.00,'Payment past due, approval workflow gap flagged in internal audit'),
    ('Arjun Pillai','out_of_policy_spend','policy_not_communicated','freeze_card','escalated','board_escalation','2026-07-04',null,95000.00,'Card frozen pending review — suspend recommendation to board'),
    ('Anil Mehta','missing_receipts','no_receipt_capture_habit','enforce_receipt_capture','verification_pending','internal_only','2026-07-06','2026-07-09',28000.00,'Travel receipts recovered — verifying completeness'),
    ('Ananya Rao','duplicate_transaction','vendor_billing_error','escalate_to_finance_head','closed','financial_leakage','2026-07-02','2026-07-07',12000.00,'Duplicate SaaS subscription cancelled, refund secured')
  ) as q(name, fc, rc, ca, cst, ri, tcd, acd, recov, nt)
  join public.corp_card_spend_r3269 e
    on e.org_id = v_org_id and e.cardholder_name = q.name;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Card verdict distribution
create or replace function public.founder_r3269_card_verdict_rollup()
returns table(card_verdict text, cards bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.corp_card_spend_r3269)
  select l.card_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.corp_card_spend_r3269 l
  group by l.card_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3269_card_verdict_rollup() from public, anon;
grant execute on function public.founder_r3269_card_verdict_rollup() to authenticated;

-- 2) Department spend-control scorecard
create or replace function public.founder_r3269_department_scorecard()
returns table(
  department text,
  total_cards bigint,
  healthy bigint,
  high_util bigint,
  policy_gaps bigint,
  overdue bigint,
  fraud_review bigint,
  avg_utilization_pct numeric,
  total_spent_rupees numeric,
  total_flagged_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    count(*) filter (where l.card_verdict = 'healthy')::bigint,
    count(*) filter (where l.card_verdict = 'high_utilization')::bigint,
    count(*) filter (where l.card_verdict = 'policy_gaps')::bigint,
    count(*) filter (where l.card_verdict = 'overdue_payment')::bigint,
    count(*) filter (where l.card_verdict in ('fraud_review','suspend_recommended'))::bigint,
    round(avg(l.utilization_pct), 2),
    coalesce(sum(l.spent_this_cycle_rupees),0)::numeric,
    coalesce(sum(l.flagged_amount_rupees),0)::numeric
  from public.corp_card_spend_r3269 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3269_department_scorecard() from public, anon;
grant execute on function public.founder_r3269_department_scorecard() to authenticated;

-- 3) Card type × department matrix
create or replace function public.founder_r3269_card_type_department_matrix()
returns table(card_type text, department text, cards bigint, avg_utilization_pct numeric, total_spent_rupees numeric, flagged_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.card_type, l.department, count(*)::bigint,
    round(avg(l.utilization_pct), 2),
    coalesce(sum(l.spent_this_cycle_rupees),0)::numeric,
    coalesce(sum(l.flagged_amount_rupees),0)::numeric
  from public.corp_card_spend_r3269 l
  group by l.card_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3269_card_type_department_matrix() from public, anon;
grant execute on function public.founder_r3269_card_type_department_matrix() to authenticated;

-- 4) Cycle-close spend trend
create or replace function public.founder_r3269_cycle_spend_trend()
returns table(cycle_close_date date, cards bigint, total_spent_rupees numeric, flagged_rupees numeric, out_of_policy_txns bigint, fraud_alerts bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cycle_close_date,
    count(*)::bigint,
    coalesce(sum(l.spent_this_cycle_rupees),0)::numeric,
    coalesce(sum(l.flagged_amount_rupees),0)::numeric,
    coalesce(sum(l.out_of_policy_txn_count),0)::bigint,
    count(*) filter (where l.fraud_alert)::bigint
  from public.corp_card_spend_r3269 l
  group by l.cycle_close_date
  order by l.cycle_close_date desc;
end;
$$;

revoke execute on function public.founder_r3269_cycle_spend_trend() from public, anon;
grant execute on function public.founder_r3269_cycle_spend_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3269_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovery_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_recovery_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.corp_card_spend_capa_actions_r3269 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3269_capa_status_board() from public, anon;
grant execute on function public.founder_r3269_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3269_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.corp_card_spend_capa_actions_r3269)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_recovery_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.corp_card_spend_capa_actions_r3269 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3269_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3269_root_cause_pareto() to authenticated;

-- 7) Risk-impact digest
create or replace function public.founder_r3269_risk_impact_digest()
returns table(risk_impact text, findings bigint, open_findings bigint, total_recovery_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.risk_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_recovery_rupees),0)::numeric
  from public.corp_card_spend_capa_actions_r3269 c
  group by c.risk_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3269_risk_impact_digest() from public, anon;
grant execute on function public.founder_r3269_risk_impact_digest() to authenticated;

-- 8) High-risk card queue (top spend-control concerns)
create or replace function public.founder_r3269_high_risk_queue()
returns table(
  cardholder_name text,
  department text,
  card_type text,
  cycle_close_date date,
  card_verdict text,
  utilization_pct numeric,
  payment_status text,
  out_of_policy_txn_count int,
  flagged_amount_rupees numeric,
  fraud_alert boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cardholder_name, l.department, l.card_type, l.cycle_close_date,
    l.card_verdict, l.utilization_pct, l.payment_status, l.out_of_policy_txn_count,
    l.flagged_amount_rupees, l.fraud_alert, l.notes
  from public.corp_card_spend_r3269 l
  where l.card_verdict in ('high_utilization','policy_gaps','overdue_payment','fraud_review','suspend_recommended')
     or l.fraud_alert
     or l.payment_status in ('overdue','disputed')
     or l.utilization_pct >= 90
     or l.out_of_policy_txn_count >= 3
  order by case l.card_verdict
             when 'suspend_recommended' then 0
             when 'fraud_review' then 1
             when 'overdue_payment' then 2
             when 'policy_gaps' then 3
             when 'high_utilization' then 4
             else 5
           end,
           l.flagged_amount_rupees desc nulls last;
end;
$$;

revoke execute on function public.founder_r3269_high_risk_queue() from public, anon;
grant execute on function public.founder_r3269_high_risk_queue() to authenticated;
