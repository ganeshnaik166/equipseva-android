-- Round r2925: Founder Monthly Strategic Investor Wire & Bank-Reserve Movement Audit
-- HEAVY founder ops round

-- =========================================================
-- TABLE 1: monthly_investor_wires_r2925
-- =========================================================
create table if not exists public.monthly_investor_wires_r2925 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  wire_month date not null,
  investor_name text not null,
  investor_class text not null check (investor_class in ('lead','follow','strategic','angel','venture_debt')),
  wire_amount_inr numeric(14,2) not null,
  wire_currency text not null default 'INR',
  wire_status text not null check (wire_status in ('initiated','in_transit','received','reconciled','disputed','clawback')),
  bank_account_label text not null,
  expected_at timestamptz not null,
  received_at timestamptz,
  reconciled_at timestamptz,
  fx_rate numeric(10,4),
  notes text
);

alter table public.monthly_investor_wires_r2925 enable row level security;

-- =========================================================
-- TABLE 2: monthly_bank_reserve_movements_r2925
-- =========================================================
create table if not exists public.monthly_bank_reserve_movements_r2925 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  movement_month date not null,
  reserve_account text not null,
  movement_type text not null check (movement_type in ('inflow_wire','outflow_payout','outflow_payroll','outflow_capex','sweep_internal','escrow_lock','escrow_release','interest_credit')),
  amount_inr numeric(14,2) not null,
  opening_balance_inr numeric(14,2) not null,
  closing_balance_inr numeric(14,2) not null,
  movement_at timestamptz not null,
  counterparty text,
  approval_status text not null check (approval_status in ('pending','founder_approved','auto_approved','rejected','flagged')),
  variance_flag boolean default false,
  notes text
);

alter table public.monthly_bank_reserve_movements_r2925 enable row level security;

-- =========================================================
-- SEED DATA: monthly_investor_wires_r2925 (16 rows)
-- =========================================================
insert into public.monthly_investor_wires_r2925 (wire_month, investor_name, investor_class, wire_amount_inr, wire_currency, wire_status, bank_account_label, expected_at, received_at, reconciled_at, fx_rate, notes) values
('2026-06-01'::date, 'Accel India VII', 'lead', 45000000.00, 'INR', 'reconciled', 'HDFC Escrow A1', '2026-06-02'::timestamptz, '2026-06-02 11:22:00'::timestamptz, '2026-06-02 17:00:00'::timestamptz, 1.0000, 'Series A tranche 2 of 3'),
('2026-06-01'::date, 'Sequoia SEA Surge', 'follow', 22500000.00, 'INR', 'reconciled', 'HDFC Escrow A1', '2026-06-03'::timestamptz, '2026-06-03 09:15:00'::timestamptz, '2026-06-03 18:30:00'::timestamptz, 1.0000, 'Pro-rata follow-on'),
('2026-06-01'::date, 'Tiger Global', 'strategic', 80000000.00, 'USD', 'received', 'ICICI USD Nostro', '2026-06-04'::timestamptz, '2026-06-05 06:00:00'::timestamptz, null, 83.4200, 'Awaiting FIRC reconciliation'),
('2026-06-01'::date, 'Blume Ventures', 'follow', 15000000.00, 'INR', 'reconciled', 'HDFC Escrow A1', '2026-06-06'::timestamptz, '2026-06-06 14:00:00'::timestamptz, '2026-06-07 10:00:00'::timestamptz, 1.0000, null),
('2026-05-01'::date, 'Matrix Partners', 'lead', 38000000.00, 'INR', 'reconciled', 'HDFC Escrow A1', '2026-05-03'::timestamptz, '2026-05-03 12:00:00'::timestamptz, '2026-05-04 09:00:00'::timestamptz, 1.0000, 'Prior month'),
('2026-05-01'::date, 'Nexus Venture', 'follow', 12000000.00, 'INR', 'disputed', 'HDFC Escrow A2', '2026-05-15'::timestamptz, '2026-05-16 18:00:00'::timestamptz, null, 1.0000, 'Wire memo mismatch'),
('2026-06-01'::date, 'Kalaari Capital', 'follow', 18500000.00, 'INR', 'in_transit', 'HDFC Escrow A1', '2026-06-20'::timestamptz, null, null, 1.0000, 'Cleared at HDFC pending IFSC route'),
('2026-06-01'::date, 'Lightspeed India', 'strategic', 30000000.00, 'INR', 'reconciled', 'HDFC Escrow A2', '2026-06-08'::timestamptz, '2026-06-08 10:30:00'::timestamptz, '2026-06-08 19:00:00'::timestamptz, 1.0000, null),
('2026-06-01'::date, 'Angel Syndicate Alpha', 'angel', 4500000.00, 'INR', 'reconciled', 'HDFC Escrow A1', '2026-06-10'::timestamptz, '2026-06-10 11:00:00'::timestamptz, '2026-06-10 16:00:00'::timestamptz, 1.0000, '12 angels pooled'),
('2026-06-01'::date, 'InnoVen Capital', 'venture_debt', 60000000.00, 'INR', 'received', 'HDFC Debt Account', '2026-06-12'::timestamptz, '2026-06-12 09:00:00'::timestamptz, null, 1.0000, 'Tranche 1 venture debt'),
('2026-06-01'::date, 'Trifecta Capital', 'venture_debt', 25000000.00, 'INR', 'initiated', 'HDFC Debt Account', '2026-06-25'::timestamptz, null, null, 1.0000, 'Draw-down pending board nod'),
('2026-04-01'::date, 'Stride Ventures', 'venture_debt', 50000000.00, 'INR', 'reconciled', 'HDFC Debt Account', '2026-04-15'::timestamptz, '2026-04-15 10:00:00'::timestamptz, '2026-04-16 11:00:00'::timestamptz, 1.0000, null),
('2026-06-01'::date, 'Saama Capital', 'follow', 8000000.00, 'INR', 'clawback', 'HDFC Escrow A2', '2026-06-05'::timestamptz, '2026-06-05 09:00:00'::timestamptz, null, 1.0000, 'Wire reversed due to AML hold'),
('2026-06-01'::date, 'Iron Pillar', 'strategic', 55000000.00, 'USD', 'received', 'ICICI USD Nostro', '2026-06-14'::timestamptz, '2026-06-15 07:00:00'::timestamptz, null, 83.5500, null),
('2026-05-01'::date, 'Chiratae Ventures', 'follow', 14000000.00, 'INR', 'reconciled', 'HDFC Escrow A1', '2026-05-18'::timestamptz, '2026-05-18 12:30:00'::timestamptz, '2026-05-19 09:00:00'::timestamptz, 1.0000, null),
('2026-06-01'::date, 'Strategic Family Office', 'strategic', 35000000.00, 'INR', 'in_transit', 'HDFC Escrow A2', '2026-06-22'::timestamptz, null, null, 1.0000, 'Singapore family office');

-- =========================================================
-- SEED DATA: monthly_bank_reserve_movements_r2925 (18 rows)
-- =========================================================
insert into public.monthly_bank_reserve_movements_r2925 (movement_month, reserve_account, movement_type, amount_inr, opening_balance_inr, closing_balance_inr, movement_at, counterparty, approval_status, variance_flag, notes) values
('2026-06-01'::date, 'HDFC Escrow A1', 'inflow_wire', 45000000.00, 120000000.00, 165000000.00, '2026-06-02 11:22:00'::timestamptz, 'Accel India VII', 'auto_approved', false, null),
('2026-06-01'::date, 'HDFC Escrow A1', 'inflow_wire', 22500000.00, 165000000.00, 187500000.00, '2026-06-03 09:15:00'::timestamptz, 'Sequoia SEA Surge', 'auto_approved', false, null),
('2026-06-01'::date, 'HDFC Escrow A1', 'outflow_payroll', 18200000.00, 187500000.00, 169300000.00, '2026-06-05 18:00:00'::timestamptz, 'RazorpayX Payroll', 'founder_approved', false, 'June salary cycle'),
('2026-06-01'::date, 'HDFC Escrow A1', 'outflow_payout', 9800000.00, 169300000.00, 159500000.00, '2026-06-07 14:00:00'::timestamptz, 'Cashfree Payouts', 'auto_approved', false, 'Engineer payouts batch'),
('2026-06-01'::date, 'HDFC Escrow A2', 'sweep_internal', 30000000.00, 50000000.00, 80000000.00, '2026-06-08 11:00:00'::timestamptz, 'Inter-account sweep', 'founder_approved', false, 'Liquidity rebalance'),
('2026-06-01'::date, 'HDFC Escrow A1', 'outflow_capex', 12500000.00, 159500000.00, 147000000.00, '2026-06-09 10:00:00'::timestamptz, 'Phillips Healthcare', 'founder_approved', true, 'Capex variance 8% over budget'),
('2026-06-01'::date, 'ICICI USD Nostro', 'inflow_wire', 6673600000.00, 0.00, 6673600000.00, '2026-06-05 06:00:00'::timestamptz, 'Tiger Global', 'pending', false, 'Awaiting FIRC'),
('2026-06-01'::date, 'HDFC Debt Account', 'inflow_wire', 60000000.00, 0.00, 60000000.00, '2026-06-12 09:00:00'::timestamptz, 'InnoVen Capital', 'founder_approved', false, null),
('2026-06-01'::date, 'HDFC Debt Account', 'escrow_lock', 15000000.00, 60000000.00, 45000000.00, '2026-06-13 12:00:00'::timestamptz, 'Debt service reserve', 'auto_approved', false, null),
('2026-06-01'::date, 'HDFC Escrow A1', 'interest_credit', 145000.00, 147000000.00, 147145000.00, '2026-06-15 23:59:00'::timestamptz, 'HDFC Interest', 'auto_approved', false, 'Monthly interest accrual'),
('2026-05-01'::date, 'HDFC Escrow A1', 'inflow_wire', 38000000.00, 80000000.00, 118000000.00, '2026-05-03 12:00:00'::timestamptz, 'Matrix Partners', 'auto_approved', false, null),
('2026-05-01'::date, 'HDFC Escrow A1', 'outflow_payroll', 17500000.00, 118000000.00, 100500000.00, '2026-05-05 18:00:00'::timestamptz, 'RazorpayX Payroll', 'founder_approved', false, null),
('2026-05-01'::date, 'HDFC Escrow A2', 'outflow_capex', 22000000.00, 50000000.00, 28000000.00, '2026-05-20 10:00:00'::timestamptz, 'Siemens Healthineers', 'flagged', true, 'Variance 18% — flagged'),
('2026-06-01'::date, 'HDFC Escrow A2', 'escrow_release', 8000000.00, 80000000.00, 72000000.00, '2026-06-18 11:00:00'::timestamptz, 'AMC Customer Pool', 'auto_approved', false, null),
('2026-06-01'::date, 'HDFC Escrow A1', 'outflow_payout', 11200000.00, 147145000.00, 135945000.00, '2026-06-19 15:00:00'::timestamptz, 'Cashfree Payouts', 'auto_approved', false, null),
('2026-06-01'::date, 'HDFC Escrow A2', 'sweep_internal', 20000000.00, 72000000.00, 52000000.00, '2026-06-20 11:00:00'::timestamptz, 'Sweep to FD', 'founder_approved', false, null),
('2026-04-01'::date, 'HDFC Debt Account', 'inflow_wire', 50000000.00, 0.00, 50000000.00, '2026-04-15 10:00:00'::timestamptz, 'Stride Ventures', 'auto_approved', false, null),
('2026-06-01'::date, 'HDFC Escrow A1', 'outflow_capex', 4200000.00, 135945000.00, 131745000.00, '2026-06-21 09:00:00'::timestamptz, 'GE Healthcare', 'rejected', true, 'Rejected — PO mismatch');

-- =========================================================
-- RPC 1: kpi summary
-- =========================================================
create or replace function public.r2925_kpi_summary()
returns table (
  total_wires bigint,
  total_wired_inr numeric,
  reconciled_count bigint,
  in_transit_count bigint,
  disputed_count bigint,
  current_month_inflow_inr numeric,
  flagged_movements bigint,
  closing_reserve_inr numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    (select count(*) from public.monthly_investor_wires_r2925),
    (select coalesce(sum(wire_amount_inr * coalesce(fx_rate,1)),0) from public.monthly_investor_wires_r2925),
    (select count(*) from public.monthly_investor_wires_r2925 where wire_status = 'reconciled'),
    (select count(*) from public.monthly_investor_wires_r2925 where wire_status = 'in_transit'),
    (select count(*) from public.monthly_investor_wires_r2925 where wire_status = 'disputed'),
    (select coalesce(sum(amount_inr),0) from public.monthly_bank_reserve_movements_r2925
       where movement_month = '2026-06-01'::date and movement_type = 'inflow_wire'),
    (select count(*) from public.monthly_bank_reserve_movements_r2925 where variance_flag = true),
    (select closing_balance_inr from public.monthly_bank_reserve_movements_r2925
       order by movement_at desc limit 1);
end; $$;

-- =========================================================
-- RPC 2: list wires
-- =========================================================
create or replace function public.r2925_list_wires()
returns table (
  id uuid,
  wire_month date,
  investor_name text,
  investor_class text,
  wire_amount_inr numeric,
  wire_currency text,
  wire_status text,
  bank_account_label text,
  expected_at timestamptz,
  received_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.id, w.wire_month, w.investor_name, w.investor_class, w.wire_amount_inr,
         w.wire_currency, w.wire_status, w.bank_account_label, w.expected_at, w.received_at
  from public.monthly_investor_wires_r2925 w
  order by w.expected_at desc;
end; $$;

-- =========================================================
-- RPC 3: list reserve movements
-- =========================================================
create or replace function public.r2925_list_movements()
returns table (
  id uuid,
  movement_month date,
  reserve_account text,
  movement_type text,
  amount_inr numeric,
  closing_balance_inr numeric,
  movement_at timestamptz,
  counterparty text,
  approval_status text,
  variance_flag boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.id, m.movement_month, m.reserve_account, m.movement_type, m.amount_inr,
         m.closing_balance_inr, m.movement_at, m.counterparty, m.approval_status, m.variance_flag
  from public.monthly_bank_reserve_movements_r2925 m
  order by m.movement_at desc;
end; $$;

-- =========================================================
-- RPC 4: investor class breakdown
-- =========================================================
create or replace function public.r2925_investor_class_breakdown()
returns table (
  investor_class text,
  wire_count bigint,
  total_inr numeric,
  reconciled_inr numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.investor_class,
         count(*)::bigint,
         coalesce(sum(w.wire_amount_inr * coalesce(w.fx_rate,1)),0),
         coalesce(sum(case when w.wire_status = 'reconciled' then w.wire_amount_inr * coalesce(w.fx_rate,1) else 0 end),0)
  from public.monthly_investor_wires_r2925 w
  group by w.investor_class
  order by 3 desc;
end; $$;

-- =========================================================
-- RPC 5: account balance trail
-- =========================================================
create or replace function public.r2925_account_balance_trail()
returns table (
  reserve_account text,
  movement_count bigint,
  net_change_inr numeric,
  latest_closing_inr numeric,
  flagged_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.reserve_account,
         count(*)::bigint,
         coalesce(sum(case when m.movement_type like 'inflow%' or m.movement_type in ('sweep_internal','escrow_release','interest_credit')
                           then m.amount_inr else -m.amount_inr end),0),
         (select closing_balance_inr from public.monthly_bank_reserve_movements_r2925
            where reserve_account = m.reserve_account order by movement_at desc limit 1),
         count(*) filter (where m.variance_flag = true)::bigint
  from public.monthly_bank_reserve_movements_r2925 m
  group by m.reserve_account
  order by 3 desc;
end; $$;

-- =========================================================
-- RPC 6: month-over-month inflow trend
-- =========================================================
create or replace function public.r2925_monthly_inflow_trend()
returns table (
  movement_month date,
  total_inflow_inr numeric,
  total_outflow_inr numeric,
  net_inr numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.movement_month,
         coalesce(sum(case when m.movement_type like 'inflow%' or m.movement_type = 'interest_credit'
                           then m.amount_inr else 0 end),0),
         coalesce(sum(case when m.movement_type like 'outflow%' or m.movement_type = 'escrow_lock'
                           then m.amount_inr else 0 end),0),
         coalesce(sum(case when m.movement_type like 'inflow%' or m.movement_type = 'interest_credit'
                           then m.amount_inr
                           when m.movement_type like 'outflow%' or m.movement_type = 'escrow_lock'
                           then -m.amount_inr else 0 end),0)
  from public.monthly_bank_reserve_movements_r2925 m
  group by m.movement_month
  order by m.movement_month desc;
end; $$;

-- =========================================================
-- RPC 7: variance alerts
-- =========================================================
create or replace function public.r2925_variance_alerts()
returns table (
  id uuid,
  reserve_account text,
  movement_type text,
  amount_inr numeric,
  counterparty text,
  approval_status text,
  movement_at timestamptz,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.id, m.reserve_account, m.movement_type, m.amount_inr, m.counterparty,
         m.approval_status, m.movement_at, m.notes
  from public.monthly_bank_reserve_movements_r2925 m
  where m.variance_flag = true or m.approval_status in ('flagged','rejected','pending')
  order by m.movement_at desc;
end; $$;

-- =========================================================
-- RPC 8: pending wire reconciliation
-- =========================================================
create or replace function public.r2925_pending_reconciliation()
returns table (
  id uuid,
  investor_name text,
  investor_class text,
  wire_amount_inr numeric,
  wire_currency text,
  wire_status text,
  expected_at timestamptz,
  days_pending integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.id, w.investor_name, w.investor_class, w.wire_amount_inr, w.wire_currency,
         w.wire_status, w.expected_at,
         greatest(0, extract(day from (now() - w.expected_at))::integer)
  from public.monthly_investor_wires_r2925 w
  where w.wire_status in ('initiated','in_transit','received','disputed')
  order by w.expected_at asc;
end; $$;

-- =========================================================
-- GRANTS — gate by is_founder()
-- =========================================================
revoke execute on function public.r2925_kpi_summary() from public, anon;
revoke execute on function public.r2925_list_wires() from public, anon;
revoke execute on function public.r2925_list_movements() from public, anon;
revoke execute on function public.r2925_investor_class_breakdown() from public, anon;
revoke execute on function public.r2925_account_balance_trail() from public, anon;
revoke execute on function public.r2925_monthly_inflow_trend() from public, anon;
revoke execute on function public.r2925_variance_alerts() from public, anon;
revoke execute on function public.r2925_pending_reconciliation() from public, anon;

grant execute on function public.r2925_kpi_summary() to authenticated;
grant execute on function public.r2925_list_wires() to authenticated;
grant execute on function public.r2925_list_movements() to authenticated;
grant execute on function public.r2925_investor_class_breakdown() to authenticated;
grant execute on function public.r2925_account_balance_trail() to authenticated;
grant execute on function public.r2925_monthly_inflow_trend() to authenticated;
grant execute on function public.r2925_variance_alerts() to authenticated;
grant execute on function public.r2925_pending_reconciliation() to authenticated;
