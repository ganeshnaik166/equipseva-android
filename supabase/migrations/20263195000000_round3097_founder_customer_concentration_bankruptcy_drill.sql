-- Round 3097 — Founder Quarterly Strategic Engineer-Founder Catastrophic
-- Single-Customer Concentration Bankruptcy Risk Drill
--
-- Two round-suffixed tables:
--   1) concentration_customers_r3097   — top customers, ARR share, payment behaviour,
--                                        public solvency signals, covenant flags
--   2) concentration_actions_r3097     — diversification / hedging action queue
--
-- All functions are SECURITY DEFINER plpgsql with inline is_founder() gate,
-- search_path locked to public, pg_temp, and EXECUTE revoked from PUBLIC/anon
-- then granted to authenticated only.

begin;

------------------------------------------------------------------------------
-- 1) Top-5 concentration customers table
------------------------------------------------------------------------------
create table if not exists public.concentration_customers_r3097 (
  id                          uuid primary key default gen_random_uuid(),
  organization_id             uuid references public.organizations(id) on delete set null,
  customer_name               text not null,
  customer_segment            text not null check (customer_segment in (
                                'super_specialty','tier1_hospital','dental_chain',
                                'diagnostic_chain','imaging_center','government'
                              )),
  state_code                  text not null check (length(state_code) = 2),
  annual_run_rate_inr_lakh    numeric(12,2) not null check (annual_run_rate_inr_lakh >= 0
                                                       and annual_run_rate_inr_lakh <= 100000),
  arr_share_pct               numeric(5,2) not null check (arr_share_pct >= 0
                                                       and arr_share_pct <= 100),
  rank_in_top5                int not null check (rank_in_top5 between 1 and 5),
  avg_dso_days                int not null check (avg_dso_days between 0 and 365),
  payment_behaviour           text not null check (payment_behaviour in (
                                'on_time','slow_30','slow_60','slow_90','defaulting'
                              )),
  outstanding_inr_lakh        numeric(12,2) not null default 0
                              check (outstanding_inr_lakh >= 0 and outstanding_inr_lakh <= 100000),
  public_solvency_signal      text not null check (public_solvency_signal in (
                                'clean','watch','negative','distressed','nclt_filed'
                              )),
  credit_rating               text not null check (credit_rating in (
                                'AAA','AA','A','BBB','BB','B','C','D','NR'
                              )),
  covenant_flag               text not null check (covenant_flag in (
                                'none','minor','material','breached','waived'
                              )),
  runway_impact_days_if_lost  int not null check (runway_impact_days_if_lost between -365 and 1000),
  diversification_status      text not null check (diversification_status in (
                                'on_track','at_risk','off_track','escalated'
                              )),
  contract_renewal_at         date,
  last_reviewed_at            timestamptz not null default now(),
  notes                       text,
  created_at                  timestamptz not null default now()
);

create index if not exists idx_cc_r3097_segment
  on public.concentration_customers_r3097(customer_segment);
create index if not exists idx_cc_r3097_rank
  on public.concentration_customers_r3097(rank_in_top5);
create index if not exists idx_cc_r3097_solvency
  on public.concentration_customers_r3097(public_solvency_signal);

------------------------------------------------------------------------------
-- 2) Diversification / hedging action queue
------------------------------------------------------------------------------
create table if not exists public.concentration_actions_r3097 (
  id                       uuid primary key default gen_random_uuid(),
  customer_id              uuid not null
                             references public.concentration_customers_r3097(id)
                             on delete cascade,
  action_type              text not null check (action_type in (
                             'pursue_new_logo','negotiate_lc','tighten_credit',
                             'demand_advance','escrow_setup','insurance_hedge',
                             'engineer_redeploy','escalate_legal','wind_down'
                           )),
  priority                 text not null check (priority in ('p0','p1','p2','p3')),
  owner_role               text not null check (owner_role in (
                             'founder','head_of_sales','head_of_ops',
                             'cfo','legal','collections'
                           )),
  target_close_at          date not null,
  expected_revenue_replace_inr_lakh numeric(12,2) not null default 0
                                       check (expected_revenue_replace_inr_lakh >= 0
                                          and expected_revenue_replace_inr_lakh <= 100000),
  status                   text not null check (status in (
                             'queued','in_progress','blocked','completed','dropped'
                           )),
  bankruptcy_drill_outcome text not null check (bankruptcy_drill_outcome in (
                             'survives','cash_strapped','layoffs_needed','insolvent','unknown'
                           )),
  blocker_note             text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

create index if not exists idx_ca_r3097_status
  on public.concentration_actions_r3097(status);
create index if not exists idx_ca_r3097_priority
  on public.concentration_actions_r3097(priority);
create index if not exists idx_ca_r3097_customer
  on public.concentration_actions_r3097(customer_id);

------------------------------------------------------------------------------
-- Seed data — 6 customers + 8 actions = 14 rows total
------------------------------------------------------------------------------
insert into public.concentration_customers_r3097
  (id, customer_name, customer_segment, state_code, annual_run_rate_inr_lakh,
   arr_share_pct, rank_in_top5, avg_dso_days, payment_behaviour,
   outstanding_inr_lakh, public_solvency_signal, credit_rating, covenant_flag,
   runway_impact_days_if_lost, diversification_status, contract_renewal_at, notes)
values
  ('11111111-aaaa-4aaa-aaaa-000000003097','Apollo Super Specialty Hyderabad',
   'super_specialty','TG', 312.50, 27.40, 1, 62, 'slow_60', 58.30,
   'watch','A','minor', 184, 'at_risk', '2027-03-31',
   'Single largest logo. Renewal slipping; CFO escalation needed.'),
  ('22222222-aaaa-4aaa-aaaa-000000003097','Yashoda Hospitals Group',
   'tier1_hospital','TG', 248.75, 21.80, 2, 45, 'slow_30', 31.20,
   'clean','AA','none', 142, 'on_track', '2027-09-30',
   'Reliable payer; expanding ICU footprint.'),
  ('33333333-aaaa-4aaa-aaaa-000000003097','Clove Dental Chain North',
   'dental_chain','DL', 168.40, 14.75, 3, 88, 'slow_90', 41.10,
   'negative','BBB','material', 96, 'off_track', '2026-12-31',
   'Working-capital strain; covenant breach risk in Q3.'),
  ('44444444-aaaa-4aaa-aaaa-000000003097','Vijaya Diagnostic Centre',
   'diagnostic_chain','TG', 134.20, 11.76, 4, 38, 'on_time', 12.40,
   'clean','AA','none', 78, 'on_track', '2027-06-30',
   'Anchor diagnostic; quarterly QA partner.'),
  ('55555555-aaaa-4aaa-aaaa-000000003097','HCG Imaging Bengaluru',
   'imaging_center','KA', 102.80, 9.01, 5, 122, 'slow_90', 67.50,
   'distressed','B','breached', 64, 'escalated', '2026-09-30',
   'Parent group rating cut; collections team on weekly call.'),
  ('66666666-aaaa-4aaa-aaaa-000000003097','TS Govt District Hospital Karimnagar',
   'government','TG', 74.60, 6.54, 5, 156, 'defaulting', 29.80,
   'watch','NR','waived', 38, 'at_risk', '2027-01-31',
   'Govt payment delays expected; LC route attempted.');

insert into public.concentration_actions_r3097
  (customer_id, action_type, priority, owner_role, target_close_at,
   expected_revenue_replace_inr_lakh, status, bankruptcy_drill_outcome, blocker_note)
values
  ('11111111-aaaa-4aaa-aaaa-000000003097','pursue_new_logo','p0','head_of_sales',
   '2026-09-30', 80.00, 'in_progress','cash_strapped',
   'Pipeline: 2 super-specialty logos at Bengaluru.'),
  ('11111111-aaaa-4aaa-aaaa-000000003097','tighten_credit','p1','cfo',
   '2026-08-15', 0.00, 'queued','survives', null),
  ('22222222-aaaa-4aaa-aaaa-000000003097','engineer_redeploy','p2','head_of_ops',
   '2026-10-31', 25.00, 'queued','survives', null),
  ('33333333-aaaa-4aaa-aaaa-000000003097','demand_advance','p0','founder',
   '2026-07-31', 0.00, 'blocked','layoffs_needed',
   'Customer refused 30 percent advance; legal review pending.'),
  ('33333333-aaaa-4aaa-aaaa-000000003097','escrow_setup','p1','legal',
   '2026-08-30', 0.00, 'in_progress','cash_strapped', null),
  ('44444444-aaaa-4aaa-aaaa-000000003097','insurance_hedge','p2','cfo',
   '2026-11-15', 0.00, 'queued','survives', null),
  ('55555555-aaaa-4aaa-aaaa-000000003097','escalate_legal','p0','legal',
   '2026-07-15', 0.00, 'in_progress','insolvent',
   'NCLT filing expected by parent group; recover via IBC pool.'),
  ('66666666-aaaa-4aaa-aaaa-000000003097','negotiate_lc','p1','collections',
   '2026-09-15', 15.00, 'blocked','cash_strapped',
   'Govt LC issuance held at treasury 4 weeks.');

------------------------------------------------------------------------------
-- RPC 1: Status summary
------------------------------------------------------------------------------
create or replace function public.rpc_r3097_status_summary()
returns table (
  total_customers       int,
  total_arr_inr_lakh    numeric,
  total_outstanding_inr_lakh numeric,
  weighted_avg_dso      numeric,
  top1_share_pct        numeric,
  top3_share_pct        numeric,
  customers_distressed  int,
  covenant_breaches     int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    coalesce(sum(annual_run_rate_inr_lakh),0),
    coalesce(sum(outstanding_inr_lakh),0),
    case when sum(annual_run_rate_inr_lakh) = 0 then 0
         else round(sum(avg_dso_days * annual_run_rate_inr_lakh)
                  / nullif(sum(annual_run_rate_inr_lakh),0), 2) end,
    coalesce(max(case when rank_in_top5 = 1 then arr_share_pct end),0),
    coalesce(sum(case when rank_in_top5 between 1 and 3 then arr_share_pct end),0),
    count(*) filter (where public_solvency_signal in ('distressed','nclt_filed'))::int,
    count(*) filter (where covenant_flag = 'breached')::int
  from public.concentration_customers_r3097;
end;
$$;

revoke execute on function public.rpc_r3097_status_summary() from public, anon;
grant  execute on function public.rpc_r3097_status_summary() to authenticated;

------------------------------------------------------------------------------
-- RPC 2: Customer hotlist (ranked by combined risk)
------------------------------------------------------------------------------
create or replace function public.rpc_r3097_customer_hotlist()
returns table (
  customer_name      text,
  segment            text,
  arr_share_pct      numeric,
  outstanding_inr_lakh numeric,
  solvency           text,
  covenant           text,
  runway_impact_days int,
  risk_score         int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.customer_name,
    c.customer_segment,
    c.arr_share_pct,
    c.outstanding_inr_lakh,
    c.public_solvency_signal,
    c.covenant_flag,
    c.runway_impact_days_if_lost,
    (
      (case c.public_solvency_signal
         when 'nclt_filed' then 50 when 'distressed' then 40
         when 'negative' then 25  when 'watch' then 10 else 0 end)
      + (case c.covenant_flag
         when 'breached' then 30 when 'material' then 20
         when 'minor' then 10    when 'waived' then 5 else 0 end)
      + (c.arr_share_pct)::int
    )::int
  from public.concentration_customers_r3097 c
  order by 8 desc, c.arr_share_pct desc;
end;
$$;

revoke execute on function public.rpc_r3097_customer_hotlist() from public, anon;
grant  execute on function public.rpc_r3097_customer_hotlist() to authenticated;

------------------------------------------------------------------------------
-- RPC 3: Segment breakdown
------------------------------------------------------------------------------
create or replace function public.rpc_r3097_segment_breakdown()
returns table (
  segment            text,
  customer_count     int,
  total_arr_inr_lakh numeric,
  avg_dso_days       numeric,
  outstanding_inr_lakh numeric,
  share_pct          numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_total numeric;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select coalesce(sum(annual_run_rate_inr_lakh),0)
    into v_total from public.concentration_customers_r3097;
  return query
  select
    c.customer_segment,
    count(*)::int,
    sum(c.annual_run_rate_inr_lakh),
    round(avg(c.avg_dso_days)::numeric, 2),
    sum(c.outstanding_inr_lakh),
    case when v_total = 0 then 0
         else round(sum(c.annual_run_rate_inr_lakh) / v_total * 100, 2) end
  from public.concentration_customers_r3097 c
  group by c.customer_segment
  order by 3 desc;
end;
$$;

revoke execute on function public.rpc_r3097_segment_breakdown() from public, anon;
grant  execute on function public.rpc_r3097_segment_breakdown() to authenticated;

------------------------------------------------------------------------------
-- RPC 4: Payment behaviour rollup
------------------------------------------------------------------------------
create or replace function public.rpc_r3097_payment_behaviour()
returns table (
  payment_behaviour text,
  customer_count    int,
  total_outstanding_inr_lakh numeric,
  avg_dso_days      numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.payment_behaviour,
    count(*)::int,
    sum(c.outstanding_inr_lakh),
    round(avg(c.avg_dso_days)::numeric, 2)
  from public.concentration_customers_r3097 c
  group by c.payment_behaviour
  order by 3 desc nulls last;
end;
$$;

revoke execute on function public.rpc_r3097_payment_behaviour() from public, anon;
grant  execute on function public.rpc_r3097_payment_behaviour() to authenticated;

------------------------------------------------------------------------------
-- RPC 5: Action queue by priority
------------------------------------------------------------------------------
create or replace function public.rpc_r3097_action_queue()
returns table (
  customer_name     text,
  action_type       text,
  priority          text,
  owner_role        text,
  status            text,
  bankruptcy_drill_outcome text,
  target_close_at   date,
  expected_replace_inr_lakh numeric,
  blocker_note      text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.customer_name,
    a.action_type,
    a.priority,
    a.owner_role,
    a.status,
    a.bankruptcy_drill_outcome,
    a.target_close_at,
    a.expected_revenue_replace_inr_lakh,
    a.blocker_note
  from public.concentration_actions_r3097 a
  join public.concentration_customers_r3097 c on c.id = a.customer_id
  order by
    case a.priority when 'p0' then 0 when 'p1' then 1
                    when 'p2' then 2 else 3 end,
    a.target_close_at asc;
end;
$$;

revoke execute on function public.rpc_r3097_action_queue() from public, anon;
grant  execute on function public.rpc_r3097_action_queue() to authenticated;

------------------------------------------------------------------------------
-- RPC 6: Bankruptcy drill scorecard
------------------------------------------------------------------------------
create or replace function public.rpc_r3097_drill_scorecard()
returns table (
  customer_name      text,
  arr_share_pct      numeric,
  runway_impact_days int,
  worst_outcome      text,
  open_actions       int,
  blocked_actions    int,
  diversification_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.customer_name,
    c.arr_share_pct,
    c.runway_impact_days_if_lost,
    (
      select a2.bankruptcy_drill_outcome
      from public.concentration_actions_r3097 a2
      where a2.customer_id = c.id
      order by case a2.bankruptcy_drill_outcome
                 when 'insolvent' then 0
                 when 'layoffs_needed' then 1
                 when 'cash_strapped' then 2
                 when 'survives' then 3
                 else 4 end
      limit 1
    ),
    (select count(*) from public.concentration_actions_r3097 a3
       where a3.customer_id = c.id and a3.status in ('queued','in_progress'))::int,
    (select count(*) from public.concentration_actions_r3097 a4
       where a4.customer_id = c.id and a4.status = 'blocked')::int,
    c.diversification_status
  from public.concentration_customers_r3097 c
  order by c.arr_share_pct desc;
end;
$$;

revoke execute on function public.rpc_r3097_drill_scorecard() from public, anon;
grant  execute on function public.rpc_r3097_drill_scorecard() to authenticated;

------------------------------------------------------------------------------
-- RPC 7: Solvency / covenant heat map
------------------------------------------------------------------------------
create or replace function public.rpc_r3097_solvency_heatmap()
returns table (
  public_solvency_signal text,
  covenant_flag          text,
  customer_count         int,
  arr_at_risk_inr_lakh   numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.public_solvency_signal,
    c.covenant_flag,
    count(*)::int,
    sum(c.annual_run_rate_inr_lakh)
  from public.concentration_customers_r3097 c
  group by c.public_solvency_signal, c.covenant_flag
  order by 4 desc nulls last;
end;
$$;

revoke execute on function public.rpc_r3097_solvency_heatmap() from public, anon;
grant  execute on function public.rpc_r3097_solvency_heatmap() to authenticated;

------------------------------------------------------------------------------
-- RPC 8: Renewal calendar (next 12 months)
------------------------------------------------------------------------------
create or replace function public.rpc_r3097_renewal_calendar()
returns table (
  customer_name       text,
  segment             text,
  arr_share_pct       numeric,
  contract_renewal_at date,
  days_to_renewal     int,
  diversification_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.customer_name,
    c.customer_segment,
    c.arr_share_pct,
    c.contract_renewal_at,
    (c.contract_renewal_at - current_date)::int,
    c.diversification_status
  from public.concentration_customers_r3097 c
  where c.contract_renewal_at is not null
  order by c.contract_renewal_at asc;
end;
$$;

revoke execute on function public.rpc_r3097_renewal_calendar() from public, anon;
grant  execute on function public.rpc_r3097_renewal_calendar() to authenticated;

commit;
