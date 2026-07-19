-- Round 3361: Founder Customer Credit-Risk, Receivables-Provisioning (ECL) & Bad-Debt Governance Board
-- Receivables risk log — customer segment × credit limit × outstanding × overdue > 90 × credit rating × ECL provision × security held × legal action × account verdict × CAPA

-- =============================================================================
-- TABLE 1: customer_credit_risk_r3361 — per customer/account credit-risk & provisioning
-- =============================================================================
create table if not exists public.customer_credit_risk_r3361 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  customer_account_code text not null,
  customer_segment text not null check (customer_segment in (
    'govt_hospital','large_private_chain','standalone_private','nursing_home','diagnostic_center','medical_college'
  )),
  review_date date not null,
  credit_limit_rupees numeric(14,2) not null,
  total_outstanding_rupees numeric(14,2) not null,
  overdue_over_90_rupees numeric(14,2) not null,
  oldest_invoice_days int not null,
  credit_rating text not null check (credit_rating in (
    'aaa_prompt','a_reliable','b_watch','c_slow','d_default_risk'
  )),
  disputes_open int not null default 0,
  payment_trend text not null check (payment_trend in (
    'improving','stable','deteriorating'
  )),
  ecl_provision_pct numeric(5,2) not null,
  provision_amount_rupees numeric(14,2) not null,
  security_held text not null check (security_held in (
    'bank_guarantee','advance','pdc','none'
  )),
  legal_action_status text not null check (legal_action_status in (
    'none','notice_sent','arbitration','litigation','settled'
  )),
  account_verdict text not null check (account_verdict in (
    'healthy','tighten_credit','provision_increase','stop_supply','legal_recovery','write_off_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.customer_credit_risk_r3361 enable row level security;

create index if not exists idx_customer_credit_risk_r3361_org on public.customer_credit_risk_r3361(organization_id);
create index if not exists idx_customer_credit_risk_r3361_review on public.customer_credit_risk_r3361(review_date);
create index if not exists idx_customer_credit_risk_r3361_verdict on public.customer_credit_risk_r3361(account_verdict);

-- =============================================================================
-- TABLE 2: customer_credit_risk_capa_actions_r3361 — credit-control / recovery / provisioning actions
-- =============================================================================
create table if not exists public.customer_credit_risk_capa_actions_r3361 (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.customer_credit_risk_r3361(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'credit_limit_breach','overdue_over_90_days','provision_shortfall','dispute_unresolved',
    'no_security_held','payment_default','ecl_model_gap','collection_follow_up_lapse',
    'legal_action_delay','write_off_pending'
  )),
  root_cause text not null check (root_cause in (
    'customer_cashflow_stress','billing_dispute','delivery_documentation_gap','budget_sanction_delay_govt',
    'credit_policy_override','manual_ledger_error','no_credit_insurance','collection_team_understaffed',
    'pending_investigation','economic_downturn'
  )),
  corrective_action text not null check (corrective_action in (
    'reduce_credit_limit','demand_bank_guarantee','issue_legal_notice','initiate_arbitration',
    'increase_ecl_provision','restructure_payment_plan','hold_further_supply','escalate_to_collection_agency',
    'write_off_account','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'ind_as_109_provisioning','rbi_npa_norms','statutory_audit_finding','none','internal_only','board_audit_committee'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.customer_credit_risk_capa_actions_r3361 enable row level security;

create index if not exists idx_customer_credit_risk_capa_r3361_acct on public.customer_credit_risk_capa_actions_r3361(account_id);
create index if not exists idx_customer_credit_risk_capa_r3361_status on public.customer_credit_risk_capa_actions_r3361(capa_status);

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

  -- 14 customer credit-risk rows
  insert into public.customer_credit_risk_r3361 (
    organization_id, hospital_name, customer_account_code, customer_segment, review_date,
    credit_limit_rupees, total_outstanding_rupees, overdue_over_90_rupees, oldest_invoice_days,
    credit_rating, disputes_open, payment_trend, ecl_provision_pct, provision_amount_rupees,
    security_held, legal_action_status, account_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.seg, q.rvd::date,
    q.clim, q.tout, q.o90, q.oldest,
    q.rating, q.disp, q.trend, q.eclpct, q.prov,
    q.sec, q.legal, q.verdict, q.nt
  from (values
    ('Apollo Chennai','CR-APL-CHN-01','large_private_chain','2026-07-15',
     8000000.00,5200000.00,0.00,42,'aaa_prompt',0,'improving',0.50,26000.00,'bank_guarantee','none','healthy','Prompt payer; BG on file, ageing within contract terms'),
    ('Fortis Gurgaon','CR-FRT-GGN-02','large_private_chain','2026-07-15',
     6000000.00,4800000.00,900000.00,105,'a_reliable',1,'stable',2.00,96000.00,'advance','none','tighten_credit','One AMC line slipped past 90 days; limit review advised'),
    ('Manipal Bengaluru','CR-MNP-BLR-03','large_private_chain','2026-07-14',
     5000000.00,3100000.00,0.00,30,'aaa_prompt',0,'improving',0.50,15500.00,'bank_guarantee','none','healthy','Clean ledger; auto-debit mandate active'),
    ('AIIMS Delhi','CR-AIM-DEL-04','govt_hospital','2026-07-14',
     12000000.00,9800000.00,4200000.00,190,'b_watch',2,'deteriorating',8.00,784000.00,'none','notice_sent','provision_increase','Govt PAO sanction delayed; ECL raised to 8 percent'),
    ('CMC Vellore','CR-CMC-VEL-05','medical_college','2026-07-13',
     4000000.00,1800000.00,0.00,25,'a_reliable',0,'stable',1.00,18000.00,'advance','none','healthy','Teaching-hospital account; pays on 45-day cycle'),
    ('KIMS Hyderabad','CR-KIM-HYD-06','large_private_chain','2026-07-13',
     5500000.00,4600000.00,1500000.00,140,'c_slow',3,'deteriorating',15.00,690000.00,'pdc','notice_sent','stop_supply','Repeated slippage and three open disputes; supply hold placed'),
    ('Care Hospitals Hyderabad','CR-CAR-HYD-07','standalone_private','2026-07-12',
     3000000.00,2700000.00,2100000.00,240,'d_default_risk',4,'deteriorating',45.00,1215000.00,'none','litigation','legal_recovery','Suit filed; 240-day ageing, no security held'),
    ('Yashoda Hyderabad','CR-YSH-HYD-08','large_private_chain','2026-07-12',
     4500000.00,2000000.00,0.00,35,'aaa_prompt',0,'improving',0.50,10000.00,'bank_guarantee','none','healthy','BG-backed; consistent early settlement'),
    ('Rainbow Childrens Hyderabad','CR-RBW-HYD-09','standalone_private','2026-07-11',
     2500000.00,2300000.00,1200000.00,160,'c_slow',2,'stable',20.00,460000.00,'advance','arbitration','provision_increase','Contested AMC billing under arbitration; provision at 20 percent'),
    ('Narayana Health Bengaluru','CR-NAR-BLR-10','large_private_chain','2026-07-11',
     7000000.00,5500000.00,800000.00,100,'a_reliable',1,'stable',3.00,165000.00,'bank_guarantee','none','healthy','Large chain; single overdue invoice under follow-up'),
    ('SGPGI Lucknow','CR-SGP-LKO-11','govt_hospital','2026-07-10',
     9000000.00,7200000.00,3600000.00,210,'b_watch',1,'deteriorating',10.00,720000.00,'none','notice_sent','provision_increase','State budget release pending; instalment plan proposed'),
    ('Kokilaben Mumbai','CR-KOK-MUM-12','large_private_chain','2026-07-10',
     6500000.00,3200000.00,0.00,28,'aaa_prompt',0,'improving',0.50,16000.00,'bank_guarantee','none','healthy','Marquee account; pays within 30 days'),
    ('Sunrise Nursing Home Kochi','CR-SUN-KOC-13','nursing_home','2026-07-09',
     1200000.00,1150000.00,1050000.00,320,'d_default_risk',1,'deteriorating',80.00,920000.00,'none','litigation','write_off_review','Near-total default at 320 days; write-off review at board'),
    ('Vijaya Diagnostics Hyderabad','CR-VIJ-HYD-14','diagnostic_center','2026-07-09',
     1800000.00,900000.00,200000.00,95,'b_watch',0,'stable',4.00,36000.00,'pdc','none','tighten_credit','PDC held; one invoice tipped past 90 days')
  ) as q(hosp, code, seg, rvd, clim, tout, o90, oldest, rating, disp, trend, eclpct, prov, sec, legal, verdict, nt);

  -- CAPA seed — attach to specific at-risk accounts by customer_account_code
  insert into public.customer_credit_risk_capa_actions_r3361 (
    account_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CR-CAR-HYD-07','payment_default','customer_cashflow_stress','issue_legal_notice','escalated','rbi_npa_norms','2026-07-30',null,2100000.00,'Recovery suit filed; account NPA-classified per RBI norms'),
    ('CR-SUN-KOC-13','write_off_pending','customer_cashflow_stress','write_off_account','in_progress','board_audit_committee','2026-08-10',null,1050000.00,'Board approval sought for full write-off; 320-day ageing'),
    ('CR-AIM-DEL-04','overdue_over_90_days','budget_sanction_delay_govt','increase_ecl_provision','open','ind_as_109_provisioning','2026-08-05',null,784000.00,'PAO sanction pending; ECL provision raised to 8 percent'),
    ('CR-KIM-HYD-06','credit_limit_breach','credit_policy_override','hold_further_supply','escalated','internal_only','2026-07-28',null,0.00,'Limit breached; further supply on hold pending PDC clearance'),
    ('CR-RBW-HYD-09','dispute_unresolved','billing_dispute','initiate_arbitration','verification_pending','statutory_audit_finding','2026-07-25',null,460000.00,'Contested AMC billing; arbitration invoked, awaiting award'),
    ('CR-FRT-GGN-02','provision_shortfall','manual_ledger_error','increase_ecl_provision','closed','internal_only','2026-07-12','2026-07-14',96000.00,'Ledger reconciliation fixed; provision topped up to 2 percent'),
    ('CR-SGP-LKO-11','collection_follow_up_lapse','collection_team_understaffed','restructure_payment_plan','overdue','board_audit_committee','2026-07-05',null,720000.00,'Follow-up cadence missed; instalment plan under negotiation')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.customer_credit_risk_r3361 e
    on e.organization_id = v_org_id and e.customer_account_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Account-verdict distribution
create or replace function public.founder_r3361_account_verdict_rollup()
returns table(account_verdict text, accounts bigint, total_outstanding_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.customer_credit_risk_r3361)
  select a.account_verdict, count(*)::bigint,
         coalesce(sum(a.total_outstanding_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.customer_credit_risk_r3361 a
  group by a.account_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3361_account_verdict_rollup() from public, anon;
grant execute on function public.founder_r3361_account_verdict_rollup() to authenticated;

-- 2) Customer-segment scorecard
create or replace function public.founder_r3361_segment_scorecard()
returns table(
  customer_segment text,
  total_accounts bigint,
  healthy bigint,
  at_risk bigint,
  total_outstanding_rupees numeric,
  overdue_over_90_rupees numeric,
  total_provision_rupees numeric,
  avg_ecl_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.customer_segment,
    count(*)::bigint,
    count(*) filter (where a.account_verdict = 'healthy')::bigint,
    count(*) filter (where a.account_verdict in ('provision_increase','stop_supply','legal_recovery','write_off_review'))::bigint,
    coalesce(sum(a.total_outstanding_rupees),0)::numeric,
    coalesce(sum(a.overdue_over_90_rupees),0)::numeric,
    coalesce(sum(a.provision_amount_rupees),0)::numeric,
    round(avg(a.ecl_provision_pct), 2)
  from public.customer_credit_risk_r3361 a
  group by a.customer_segment
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3361_segment_scorecard() from public, anon;
grant execute on function public.founder_r3361_segment_scorecard() to authenticated;

-- 3) Segment × credit-rating matrix
create or replace function public.founder_r3361_segment_rating_matrix()
returns table(customer_segment text, credit_rating text, accounts bigint, total_outstanding_rupees numeric, avg_ecl_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.customer_segment, a.credit_rating, count(*)::bigint,
    coalesce(sum(a.total_outstanding_rupees),0)::numeric,
    round(avg(a.ecl_provision_pct), 2)
  from public.customer_credit_risk_r3361 a
  group by a.customer_segment, a.credit_rating
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3361_segment_rating_matrix() from public, anon;
grant execute on function public.founder_r3361_segment_rating_matrix() to authenticated;

-- 4) Review-date trend
create or replace function public.founder_r3361_review_date_trend()
returns table(review_date date, accounts bigint, total_outstanding_rupees numeric, overdue_over_90_rupees numeric, total_provision_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.review_date, count(*)::bigint,
    coalesce(sum(a.total_outstanding_rupees),0)::numeric,
    coalesce(sum(a.overdue_over_90_rupees),0)::numeric,
    coalesce(sum(a.provision_amount_rupees),0)::numeric
  from public.customer_credit_risk_r3361 a
  group by a.review_date
  order by a.review_date desc;
end;
$$;

revoke execute on function public.founder_r3361_review_date_trend() from public, anon;
grant execute on function public.founder_r3361_review_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3361_capa_status_board()
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
  from public.customer_credit_risk_capa_actions_r3361 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3361_capa_status_board() from public, anon;
grant execute on function public.founder_r3361_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3361_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.customer_credit_risk_capa_actions_r3361)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.customer_credit_risk_capa_actions_r3361 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3361_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3361_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3361_regulatory_impact_digest()
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
  from public.customer_credit_risk_capa_actions_r3361 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3361_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3361_regulatory_impact_digest() to authenticated;

-- 8) High-risk accounts queue (top receivables concerns)
create or replace function public.founder_r3361_high_risk_accounts()
returns table(
  hospital_name text,
  customer_account_code text,
  customer_segment text,
  credit_rating text,
  total_outstanding_rupees numeric,
  overdue_over_90_rupees numeric,
  oldest_invoice_days int,
  legal_action_status text,
  account_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.customer_account_code, a.customer_segment, a.credit_rating,
    a.total_outstanding_rupees, a.overdue_over_90_rupees, a.oldest_invoice_days,
    a.legal_action_status, a.account_verdict, a.notes
  from public.customer_credit_risk_r3361 a
  where a.credit_rating in ('c_slow','d_default_risk')
     or a.account_verdict in ('provision_increase','stop_supply','legal_recovery','write_off_review')
     or a.payment_trend = 'deteriorating'
     or a.overdue_over_90_rupees > 0
  order by case a.account_verdict
             when 'write_off_review' then 0
             when 'legal_recovery' then 1
             when 'stop_supply' then 2
             when 'provision_increase' then 3
             else 4
           end,
           a.oldest_invoice_days desc;
end;
$$;

revoke execute on function public.founder_r3361_high_risk_accounts() from public, anon;
grant execute on function public.founder_r3361_high_risk_accounts() to authenticated;
