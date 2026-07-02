-- Round 2933 — Founder Quarterly Strategic Working-Capital Letter-of-Credit & Bank Stack Audit
-- HEAVY ★★★★ — 1500/50 milestone crossing batch

-- ============================================================
-- TABLE 1: working_capital_facilities_r2933
-- ============================================================
create table if not exists public.working_capital_facilities_r2933 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  bank_name text not null,
  facility_type text not null check (facility_type in ('cash_credit','overdraft','term_loan','loc','bg','wcdl','invoice_discounting','export_packing_credit')),
  sanctioned_limit_rupees bigint not null,
  utilised_rupees bigint not null default 0,
  available_rupees bigint generated always as (sanctioned_limit_rupees - utilised_rupees) stored,
  interest_rate_pct numeric(5,2) not null,
  sanction_date date not null,
  review_due_date date not null,
  collateral_summary text,
  primary_security text,
  facility_status text not null check (facility_status in ('active','expired','under_renewal','suspended','closed')),
  relationship_manager text,
  rm_phone text,
  branch_city text,
  covenant_compliance text check (covenant_compliance in ('compliant','breach','watchlist','na')),
  last_drawdown_at timestamptz,
  notes text
);

alter table public.working_capital_facilities_r2933 enable row level security;

-- ============================================================
-- TABLE 2: loc_transactions_r2933
-- ============================================================
create table if not exists public.loc_transactions_r2933 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  facility_id uuid references public.working_capital_facilities_r2933(id) on delete cascade,
  txn_type text not null check (txn_type in ('drawdown','repayment','interest_accrued','fee_charged','margin_blocked','margin_released','renewal','amendment')),
  txn_date date not null,
  amount_rupees bigint not null,
  counterparty text,
  purpose text,
  reference_number text,
  beneficiary text,
  currency text not null default 'INR',
  fx_rate numeric(10,4),
  status text not null check (status in ('posted','pending','reversed','disputed','reconciled')),
  reconciled_at timestamptz,
  approver_email text,
  notes text
);

alter table public.loc_transactions_r2933 enable row level security;

-- ============================================================
-- SEED DATA: facilities (16 rows)
-- ============================================================
insert into public.working_capital_facilities_r2933 (bank_name, facility_type, sanctioned_limit_rupees, utilised_rupees, interest_rate_pct, sanction_date, review_due_date, collateral_summary, primary_security, facility_status, relationship_manager, rm_phone, branch_city, covenant_compliance, last_drawdown_at, notes) values
('HDFC Bank','cash_credit',50000000,32000000,9.25,'2026-01-15'::date,'2027-01-14'::date,'Stock + Book debts hypothecation','Current assets','active','Rajesh Kumar','+91-9876543210','Hyderabad','compliant','2026-06-15'::timestamptz,'Primary working capital line'),
('ICICI Bank','overdraft',30000000,18500000,9.50,'2026-02-01'::date,'2027-01-31'::date,'Fixed deposit lien 50L','FD pledged','active','Priya Sharma','+91-9876543211','Hyderabad','compliant','2026-06-18'::timestamptz,'Secondary OD against FD'),
('SBI','term_loan',80000000,72000000,8.75,'2025-08-10'::date,'2030-08-09'::date,'Equipment hypothecation','Medical equipment','active','Anand Reddy','+91-9876543212','Bangalore','compliant','2025-08-12'::timestamptz,'CapEx loan for diagnostic units'),
('Axis Bank','loc',25000000,8750000,7.80,'2026-03-20'::date,'2027-03-19'::date,'Counter-guarantee + 10% margin','Margin money 25L','active','Vikram Singh','+91-9876543213','Mumbai','compliant','2026-05-22'::timestamptz,'LC for imported spare parts'),
('Kotak Mahindra','bg',15000000,12000000,2.50,'2026-04-05'::date,'2027-04-04'::date,'100% cash margin','FD lien','active','Sunita Patel','+91-9876543214','Delhi','compliant','2026-06-01'::timestamptz,'BG for hospital chain contracts'),
('IndusInd Bank','wcdl',20000000,20000000,9.10,'2026-05-01'::date,'2026-11-01'::date,'Receivables hypothecation','Book debts','active','Mohammed Khan','+91-9876543215','Chennai','watchlist','2026-05-02'::timestamptz,'Short-term WCDL — review in Q3'),
('Yes Bank','invoice_discounting',40000000,28000000,10.25,'2026-02-15'::date,'2027-02-14'::date,'Invoice assignment','Invoices','active','Neha Gupta','+91-9876543216','Pune','compliant','2026-06-19'::timestamptz,'Hospital invoice discounting'),
('HSBC India','export_packing_credit',35000000,15000000,6.50,'2026-01-10'::date,'2027-01-09'::date,'Export orders','LC backed','active','Sanjay Mehta','+91-9876543217','Mumbai','compliant','2026-06-10'::timestamptz,'For SL/BD/NP export pilot'),
('Standard Chartered','loc',18000000,6300000,7.95,'2026-03-01'::date,'2027-02-28'::date,'5% margin','Cash margin 9L','active','Aisha Khan','+91-9876543218','Bangalore','compliant','2026-04-15'::timestamptz,'Secondary LC line'),
('Federal Bank','cash_credit',12000000,11500000,9.75,'2025-12-01'::date,'2026-11-30'::date,'Stock hypothecation','Inventory','active','Ravi Pillai','+91-9876543219','Kochi','breach','2026-06-17'::timestamptz,'DSCR covenant breached — escalate'),
('IDFC First','overdraft',10000000,4200000,9.40,'2026-04-12'::date,'2027-04-11'::date,'Personal guarantee','PG founder','active','Karthik Iyer','+91-9876543220','Hyderabad','compliant','2026-06-05'::timestamptz,'Founder PG backed OD'),
('Punjab National Bank','bg',8000000,8000000,2.25,'2026-02-20'::date,'2026-08-19'::date,'100% margin','FD lien','under_renewal','Deepak Verma','+91-9876543221','Delhi','compliant','2026-02-21'::timestamptz,'BG expiring — renew before Aug 19'),
('Bank of Baroda','term_loan',45000000,35000000,8.90,'2025-06-15'::date,'2030-06-14'::date,'Plant & machinery','Fixed assets','active','Suresh Joshi','+91-9876543222','Vadodara','compliant','2025-06-20'::timestamptz,'Manufacturing setup loan'),
('RBL Bank','wcdl',15000000,0,9.80,'2026-06-01'::date,'2026-12-01'::date,'Receivables','Book debts','active','Pooja Singh','+91-9876543223','Mumbai','compliant',null,'New line — undrawn'),
('Citi Bank','loc',22000000,0,7.60,'2025-11-15'::date,'2026-08-14'::date,'10% margin','Cash margin','expired','Arjun Kapoor','+91-9876543224','Mumbai','na','2026-04-20'::timestamptz,'Expired — not renewing'),
('Bandhan Bank','cash_credit',8000000,7800000,10.50,'2026-03-15'::date,'2027-03-14'::date,'Stock + debtors','Current assets','active','Tapan Roy','+91-9876543225','Kolkata','watchlist','2026-06-12'::timestamptz,'High utilisation — monitor');

-- ============================================================
-- SEED DATA: loc_transactions (24 rows)
-- ============================================================
insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'drawdown', '2026-06-15'::date, 5000000, 'Internal', 'Working capital top-up', 'DRW-2026-001', 'EquipSeva Operations', 'INR', null, 'posted', '2026-06-16'::timestamptz, 'cfo@equipseva.com', 'Monthly drawdown' from public.working_capital_facilities_r2933 where bank_name='HDFC Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'repayment', '2026-06-20'::date, 3000000, 'Internal', 'Partial CC repayment', 'REP-2026-002', 'HDFC Bank CC', 'INR', null, 'posted', '2026-06-21'::timestamptz, 'cfo@equipseva.com', 'Receivables collection sweep' from public.working_capital_facilities_r2933 where bank_name='HDFC Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'drawdown', '2026-05-22'::date, 4500000, 'Siemens Healthineers', 'LC for X-ray tube imports', 'LC-AXIS-2026-018', 'Siemens AG Germany', 'EUR', 92.5400, 'posted', '2026-05-23'::timestamptz, 'cfo@equipseva.com', 'Sight LC — 90 day usance' from public.working_capital_facilities_r2933 where bank_name='Axis Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'fee_charged', '2026-05-22'::date, 67500, 'Axis Bank', 'LC issuance commission 1.5%', 'FEE-AXIS-018', 'Axis Bank Trade', 'INR', null, 'posted', '2026-05-23'::timestamptz, 'cfo@equipseva.com', 'LC issuance fee' from public.working_capital_facilities_r2933 where bank_name='Axis Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'drawdown', '2026-06-19'::date, 8000000, 'Apollo Hospitals', 'Invoice discounting', 'INV-YES-2026-045', 'EquipSeva', 'INR', null, 'posted', '2026-06-20'::timestamptz, 'cfo@equipseva.com', '60-day invoice discounted' from public.working_capital_facilities_r2933 where bank_name='Yes Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'interest_accrued', '2026-06-30'::date, 290000, 'Yes Bank', 'Monthly interest accrual', 'INT-YES-2026-06', 'Yes Bank P&L', 'INR', null, 'posted', null, 'cfo@equipseva.com', 'Q1 interest accrual' from public.working_capital_facilities_r2933 where bank_name='Yes Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'margin_blocked', '2026-04-05'::date, 1500000, 'Manipal Hospitals', 'BG for AMC contract', 'BG-KOTAK-2026-007', 'Manipal Hospitals Group', 'INR', null, 'posted', '2026-04-06'::timestamptz, 'cfo@equipseva.com', '10% performance BG' from public.working_capital_facilities_r2933 where bank_name='Kotak Mahindra' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'drawdown', '2026-06-10'::date, 5500000, 'Lanka Medical Imports SL', 'EPC for SL export order', 'EPC-HSBC-2026-012', 'EquipSeva Exports', 'LKR', 0.3050, 'posted', '2026-06-11'::timestamptz, 'cfo@equipseva.com', 'Sri Lanka pilot order' from public.working_capital_facilities_r2933 where bank_name='HSBC India' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'amendment', '2026-06-05'::date, 0, 'IndusInd Bank', 'Tenure extension 6mo', 'AMD-INDUS-2026-003', 'WCDL Account', 'INR', null, 'posted', '2026-06-06'::timestamptz, 'cfo@equipseva.com', 'Q3 review extension granted' from public.working_capital_facilities_r2933 where bank_name='IndusInd Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'fee_charged', '2026-06-01'::date, 25000, 'IDFC First', 'Renewal processing fee', 'FEE-IDFC-RNW-2026', 'IDFC First Bank', 'INR', null, 'posted', '2026-06-02'::timestamptz, 'cfo@equipseva.com', 'OD renewal fee' from public.working_capital_facilities_r2933 where bank_name='IDFC First' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'drawdown', '2026-06-17'::date, 1200000, 'Internal', 'Inventory restock', 'DRW-FED-2026-018', 'EquipSeva Stores', 'INR', null, 'posted', null, 'cfo@equipseva.com', 'Pending reconciliation' from public.working_capital_facilities_r2933 where bank_name='Federal Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'repayment', '2026-06-05'::date, 1500000, 'Internal', 'Term loan EMI', 'EMI-SBI-2026-12', 'SBI Term Loan A/c', 'INR', null, 'posted', '2026-06-06'::timestamptz, 'cfo@equipseva.com', 'Monthly EMI' from public.working_capital_facilities_r2933 where bank_name='SBI' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'drawdown', '2026-04-15'::date, 6300000, 'GE Healthcare', 'LC for CT scanner parts', 'LC-SCB-2026-009', 'GE Healthcare USA', 'USD', 83.4500, 'posted', '2026-04-16'::timestamptz, 'cfo@equipseva.com', 'Usance LC 180 days' from public.working_capital_facilities_r2933 where bank_name='Standard Chartered' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'margin_released', '2026-06-12'::date, 800000, 'Fortis Healthcare', 'BG closed — contract done', 'REL-PNB-2026-002', 'EquipSeva', 'INR', null, 'posted', '2026-06-13'::timestamptz, 'cfo@equipseva.com', 'BG returned by hospital' from public.working_capital_facilities_r2933 where bank_name='Punjab National Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'interest_accrued', '2026-06-30'::date, 245000, 'HDFC Bank', 'CC interest June', 'INT-HDFC-2026-06', 'HDFC P&L', 'INR', null, 'pending', null, 'cfo@equipseva.com', 'Awaiting bank statement' from public.working_capital_facilities_r2933 where bank_name='HDFC Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'drawdown', '2026-06-18'::date, 2500000, 'Internal', 'OD utilisation', 'DRW-ICICI-2026-021', 'EquipSeva Ops', 'INR', null, 'posted', '2026-06-19'::timestamptz, 'cfo@equipseva.com', 'Payroll bridging' from public.working_capital_facilities_r2933 where bank_name='ICICI Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'repayment', '2026-06-25'::date, 1800000, 'Internal', 'OD partial repayment', 'REP-ICICI-2026-022', 'ICICI OD A/c', 'INR', null, 'pending', null, 'cfo@equipseva.com', 'Scheduled repayment' from public.working_capital_facilities_r2933 where bank_name='ICICI Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'fee_charged', '2026-06-01'::date, 45000, 'Bank of Baroda', 'Processing fee CapEx', 'FEE-BOB-2026-003', 'BOB Term Loan', 'INR', null, 'posted', '2026-06-02'::timestamptz, 'cfo@equipseva.com', 'Annual processing' from public.working_capital_facilities_r2933 where bank_name='Bank of Baroda' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'drawdown', '2026-06-12'::date, 1300000, 'Internal', 'Stock purchase', 'DRW-BAND-2026-008', 'EquipSeva Inventory', 'INR', null, 'posted', '2026-06-13'::timestamptz, 'cfo@equipseva.com', 'High util alert' from public.working_capital_facilities_r2933 where bank_name='Bandhan Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'amendment', '2026-05-15'::date, 500000, 'Internal', 'Reversal — duplicate entry', 'REV-HDFC-2026-099', 'HDFC CC', 'INR', null, 'reversed', '2026-05-16'::timestamptz, 'cfo@equipseva.com', 'Duplicate posting reversed' from public.working_capital_facilities_r2933 where bank_name='HDFC Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'renewal', '2026-06-01'::date, 0, 'IDFC First', 'Annual renewal', 'RNW-IDFC-2026-001', 'IDFC OD', 'INR', null, 'posted', '2026-06-02'::timestamptz, 'cfo@equipseva.com', 'Limit retained at 1Cr' from public.working_capital_facilities_r2933 where bank_name='IDFC First' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'drawdown', '2026-06-21'::date, 2000000, 'Internal', 'Engineer payouts run', 'DRW-HDFC-2026-077', 'EquipSeva Payouts', 'INR', null, 'pending', null, 'cfo@equipseva.com', 'Pending bank confirmation' from public.working_capital_facilities_r2933 where bank_name='HDFC Bank' limit 1;

insert into public.loc_transactions_r2933 (facility_id, txn_type, txn_date, amount_rupees, counterparty, purpose, reference_number, beneficiary, currency, fx_rate, status, reconciled_at, approver_email, notes)
select id, 'fee_charged', '2026-06-15'::date, 12000, 'Federal Bank', 'Covenant breach penalty', 'PEN-FED-2026-001', 'Federal Bank P&L', 'INR', null, 'disputed', null, 'cfo@equipseva.com', 'Disputed — DSCR breach contested' from public.working_capital_facilities_r2933 where bank_name='Federal Bank' limit 1;

-- ============================================================
-- RPC 1: facility_summary
-- ============================================================
create or replace function public.r2933_facility_summary()
returns table (
  bank_name text,
  facility_type text,
  sanctioned_rupees bigint,
  utilised_rupees bigint,
  available_rupees bigint,
  utilisation_pct numeric,
  interest_rate_pct numeric,
  facility_status text,
  covenant_compliance text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select f.bank_name, f.facility_type, f.sanctioned_limit_rupees, f.utilised_rupees, f.available_rupees,
    case when f.sanctioned_limit_rupees > 0 then round((f.utilised_rupees::numeric / f.sanctioned_limit_rupees::numeric) * 100, 2) else 0 end,
    f.interest_rate_pct, f.facility_status, f.covenant_compliance
  from public.working_capital_facilities_r2933 f
  order by f.sanctioned_limit_rupees desc;
end;
$$;

-- ============================================================
-- RPC 2: utilisation_concentration
-- ============================================================
create or replace function public.r2933_utilisation_concentration()
returns table (
  facility_type text,
  facility_count int,
  total_sanctioned bigint,
  total_utilised bigint,
  weighted_avg_rate numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select f.facility_type, count(*)::int, sum(f.sanctioned_limit_rupees)::bigint, sum(f.utilised_rupees)::bigint,
    round(sum(f.utilised_rupees * f.interest_rate_pct)::numeric / nullif(sum(f.utilised_rupees), 0)::numeric, 2)
  from public.working_capital_facilities_r2933 f
  where f.facility_status = 'active'
  group by f.facility_type
  order by sum(f.utilised_rupees) desc;
end;
$$;

-- ============================================================
-- RPC 3: renewal_calendar
-- ============================================================
create or replace function public.r2933_renewal_calendar()
returns table (
  bank_name text,
  facility_type text,
  review_due_date date,
  days_to_review int,
  sanctioned_rupees bigint,
  facility_status text,
  urgency text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select f.bank_name, f.facility_type, f.review_due_date,
    (f.review_due_date - current_date)::int,
    f.sanctioned_limit_rupees, f.facility_status,
    case
      when f.review_due_date - current_date < 30 then 'critical'
      when f.review_due_date - current_date < 90 then 'high'
      when f.review_due_date - current_date < 180 then 'medium'
      else 'low'
    end
  from public.working_capital_facilities_r2933 f
  where f.facility_status in ('active','under_renewal')
  order by f.review_due_date asc;
end;
$$;

-- ============================================================
-- RPC 4: covenant_watchlist
-- ============================================================
create or replace function public.r2933_covenant_watchlist()
returns table (
  bank_name text,
  facility_type text,
  utilised_rupees bigint,
  covenant_compliance text,
  relationship_manager text,
  rm_phone text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select f.bank_name, f.facility_type, f.utilised_rupees, f.covenant_compliance, f.relationship_manager, f.rm_phone, f.notes
  from public.working_capital_facilities_r2933 f
  where f.covenant_compliance in ('breach','watchlist')
  order by case f.covenant_compliance when 'breach' then 1 when 'watchlist' then 2 else 3 end;
end;
$$;

-- ============================================================
-- RPC 5: txn_recent_activity
-- ============================================================
create or replace function public.r2933_txn_recent_activity()
returns table (
  txn_date date,
  bank_name text,
  txn_type text,
  amount_rupees bigint,
  currency text,
  counterparty text,
  status text,
  reference_number text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select t.txn_date, f.bank_name, t.txn_type, t.amount_rupees, t.currency, t.counterparty, t.status, t.reference_number
  from public.loc_transactions_r2933 t
  join public.working_capital_facilities_r2933 f on f.id = t.facility_id
  order by t.txn_date desc
  limit 30;
end;
$$;

-- ============================================================
-- RPC 6: interest_cost_by_bank
-- ============================================================
create or replace function public.r2933_interest_cost_by_bank()
returns table (
  bank_name text,
  total_interest_rupees bigint,
  total_fees_rupees bigint,
  txn_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select f.bank_name,
    coalesce(sum(t.amount_rupees) filter (where t.txn_type = 'interest_accrued'), 0)::bigint,
    coalesce(sum(t.amount_rupees) filter (where t.txn_type = 'fee_charged'), 0)::bigint,
    count(*)::int
  from public.working_capital_facilities_r2933 f
  left join public.loc_transactions_r2933 t on t.facility_id = f.id
  group by f.bank_name
  having coalesce(sum(t.amount_rupees) filter (where t.txn_type in ('interest_accrued','fee_charged')), 0) > 0
  order by coalesce(sum(t.amount_rupees) filter (where t.txn_type in ('interest_accrued','fee_charged')), 0) desc;
end;
$$;

-- ============================================================
-- RPC 7: unreconciled_transactions
-- ============================================================
create or replace function public.r2933_unreconciled_transactions()
returns table (
  txn_date date,
  bank_name text,
  txn_type text,
  amount_rupees bigint,
  status text,
  approver_email text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select t.txn_date, f.bank_name, t.txn_type, t.amount_rupees, t.status, t.approver_email, t.notes
  from public.loc_transactions_r2933 t
  join public.working_capital_facilities_r2933 f on f.id = t.facility_id
  where t.status in ('pending','disputed') or t.reconciled_at is null
  order by t.txn_date desc;
end;
$$;

-- ============================================================
-- RPC 8: stack_health_kpis
-- ============================================================
create or replace function public.r2933_stack_health_kpis()
returns table (
  kpi text,
  value text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_total_sanctioned bigint;
  v_total_utilised bigint;
  v_active_count int;
  v_breach_count int;
  v_avg_rate numeric;
  v_renew_30 int;
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  select coalesce(sum(sanctioned_limit_rupees),0), coalesce(sum(utilised_rupees),0)
    into v_total_sanctioned, v_total_utilised
  from public.working_capital_facilities_r2933 where facility_status = 'active';

  select (count(*) filter (where facility_status = 'active'))::int,
         (count(*) filter (where covenant_compliance = 'breach'))::int
    into v_active_count, v_breach_count
  from public.working_capital_facilities_r2933;

  select round(avg(interest_rate_pct), 2) into v_avg_rate
  from public.working_capital_facilities_r2933 where facility_status = 'active';

  select (count(*) filter (where review_due_date - current_date < 30 and facility_status in ('active','under_renewal')))::int
    into v_renew_30
  from public.working_capital_facilities_r2933;

  return query values
    ('Total sanctioned (Cr)', round(v_total_sanctioned::numeric / 10000000, 2)::text),
    ('Total utilised (Cr)', round(v_total_utilised::numeric / 10000000, 2)::text),
    ('Headroom (Cr)', round((v_total_sanctioned - v_total_utilised)::numeric / 10000000, 2)::text),
    ('Active facilities', v_active_count::text),
    ('Covenant breaches', v_breach_count::text),
    ('Avg interest rate', v_avg_rate::text || '%'),
    ('Reviews due in 30 days', v_renew_30::text);
end;
$$;

-- ============================================================
-- PERMISSIONS
-- ============================================================
revoke execute on function public.r2933_facility_summary() from public, anon;
revoke execute on function public.r2933_utilisation_concentration() from public, anon;
revoke execute on function public.r2933_renewal_calendar() from public, anon;
revoke execute on function public.r2933_covenant_watchlist() from public, anon;
revoke execute on function public.r2933_txn_recent_activity() from public, anon;
revoke execute on function public.r2933_interest_cost_by_bank() from public, anon;
revoke execute on function public.r2933_unreconciled_transactions() from public, anon;
revoke execute on function public.r2933_stack_health_kpis() from public, anon;

grant execute on function public.r2933_facility_summary() to authenticated;
grant execute on function public.r2933_utilisation_concentration() to authenticated;
grant execute on function public.r2933_renewal_calendar() to authenticated;
grant execute on function public.r2933_covenant_watchlist() to authenticated;
grant execute on function public.r2933_txn_recent_activity() to authenticated;
grant execute on function public.r2933_interest_cost_by_bank() to authenticated;
grant execute on function public.r2933_unreconciled_transactions() to authenticated;
grant execute on function public.r2933_stack_health_kpis() to authenticated;
