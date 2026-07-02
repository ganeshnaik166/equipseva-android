-- Round 3085: Founder Quarterly Strategic Engineer-Founder Long-Term Founder-Care Trust-Fund Audit
-- Heavy 4-star: 2 tables + 7 RPCs + seeds

-- =========================================================================
-- TABLE 1: trust fund quarterly audit periods
-- =========================================================================
create table if not exists public.founder_trust_fund_audit_periods_r3085 (
  id uuid primary key default gen_random_uuid(),
  fiscal_quarter text not null check (fiscal_quarter in ('Q1','Q2','Q3','Q4')),
  fiscal_year int not null check (fiscal_year between 2024 and 2035),
  period_start date not null,
  period_end date not null,
  audit_status text not null check (audit_status in ('scheduled','in_progress','review','signed_off','archived')),
  trust_fund_balance_rupees bigint not null default 0,
  total_contributions_rupees bigint not null default 0,
  total_disbursements_rupees bigint not null default 0,
  engineer_count_covered int not null default 0,
  governance_tier text not null check (governance_tier in ('founder_solo','founder_plus_cfo','full_board','external_audit')),
  audit_notes text,
  signed_off_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.founder_trust_fund_audit_periods_r3085 enable row level security;

drop policy if exists trust_fund_periods_read_r3085 on public.founder_trust_fund_audit_periods_r3085;
create policy trust_fund_periods_read_r3085 on public.founder_trust_fund_audit_periods_r3085
  for select to authenticated using (public.is_founder());

revoke all on public.founder_trust_fund_audit_periods_r3085 from public, anon;
grant select on public.founder_trust_fund_audit_periods_r3085 to authenticated;

insert into public.founder_trust_fund_audit_periods_r3085
  (fiscal_quarter, fiscal_year, period_start, period_end, audit_status, trust_fund_balance_rupees, total_contributions_rupees, total_disbursements_rupees, engineer_count_covered, governance_tier, audit_notes, signed_off_at)
values
  ('Q1', 2025, '2025-04-01'::date, '2025-06-30'::date, 'signed_off',  4250000, 1200000,  340000,  84, 'founder_solo',      'First-ever trust fund audit. Clean.', '2025-07-12 10:00:00+05:30'::timestamptz),
  ('Q2', 2025, '2025-07-01'::date, '2025-09-30'::date, 'signed_off',  5800000, 1850000,  300000,  98, 'founder_solo',      'Engineer coverage expanded.',          '2025-10-15 11:00:00+05:30'::timestamptz),
  ('Q3', 2025, '2025-10-01'::date, '2025-12-31'::date, 'signed_off',  7400000, 2100000,  500000, 112, 'founder_plus_cfo',  'CFO co-signed. Disbursements doubled.', '2026-01-18 09:30:00+05:30'::timestamptz),
  ('Q4', 2025, '2026-01-01'::date, '2026-03-31'::date, 'signed_off',  9100000, 2300000,  600000, 128, 'founder_plus_cfo',  'Annual rollup clean.',                  '2026-04-20 14:00:00+05:30'::timestamptz),
  ('Q1', 2026, '2026-04-01'::date, '2026-06-30'::date, 'review',     10600000, 2050000,  550000, 142, 'full_board',        'Board added Sandeep + Priya as trustees.', null),
  ('Q2', 2026, '2026-07-01'::date, '2026-09-30'::date, 'in_progress',11800000, 1900000,  700000, 156, 'full_board',         'Mid-quarter spot check pending.',        null),
  ('Q3', 2026, '2026-10-01'::date, '2026-12-31'::date, 'scheduled',  12000000,       0,       0, 156, 'full_board',         'Auto-scheduled.',                        null),
  ('Q4', 2026, '2027-01-01'::date, '2027-03-31'::date, 'scheduled',         0,       0,       0,   0, 'external_audit',     'External auditor engaged for annual close.', null),
  ('Q1', 2027, '2027-04-01'::date, '2027-06-30'::date, 'scheduled',         0,       0,       0,   0, 'external_audit',     'Planned.',                               null),
  ('Q4', 2024, '2025-01-01'::date, '2025-03-31'::date, 'archived',    3050000,  950000,  120000,  62, 'founder_solo',       'Pre-formal-trust era; archived.',        '2025-04-30 12:00:00+05:30'::timestamptz),
  ('Q3', 2024, '2024-10-01'::date, '2024-12-31'::date, 'archived',    2100000,  720000,   90000,  48, 'founder_solo',       'Pre-formal-trust era; archived.',        '2025-04-30 12:05:00+05:30'::timestamptz),
  ('Q2', 2024, '2024-07-01'::date, '2024-09-30'::date, 'archived',    1380000,  540000,   60000,  34, 'founder_solo',       'Pre-formal-trust era; archived.',        '2025-04-30 12:10:00+05:30'::timestamptz),
  ('Q1', 2024, '2024-04-01'::date, '2024-06-30'::date, 'archived',     840000,  320000,   30000,  22, 'founder_solo',       'Genesis quarter.',                       '2025-04-30 12:15:00+05:30'::timestamptz);

-- =========================================================================
-- TABLE 2: trust fund line items (long-term engineer care)
-- =========================================================================
create table if not exists public.founder_trust_fund_line_items_r3085 (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.founder_trust_fund_audit_periods_r3085(id) on delete cascade,
  engineer_name text not null,
  care_category text not null check (care_category in ('medical_emergency','family_education','retirement_bridge','disability_support','bereavement','wellness_grant','sabbatical_allowance','equipment_relief','adjustment')),
  flow_direction text not null check (flow_direction in ('contribution_in','disbursement_out','reversal','adjustment')),
  amount_rupees bigint not null,
  recipient_relationship text check (recipient_relationship in ('self','spouse','child','parent','sibling','dependent','estate')),
  long_term_horizon_years int check (long_term_horizon_years between 0 and 40),
  founder_approval_status text not null check (founder_approval_status in ('pending','approved','rejected','escalated','auto_approved')),
  audit_red_flag boolean not null default false,
  audit_note text,
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.founder_trust_fund_line_items_r3085 enable row level security;

drop policy if exists trust_fund_line_items_read_r3085 on public.founder_trust_fund_line_items_r3085;
create policy trust_fund_line_items_read_r3085 on public.founder_trust_fund_line_items_r3085
  for select to authenticated using (public.is_founder());

revoke all on public.founder_trust_fund_line_items_r3085 from public, anon;
grant select on public.founder_trust_fund_line_items_r3085 to authenticated;

insert into public.founder_trust_fund_line_items_r3085
  (period_id, engineer_name, care_category, flow_direction, amount_rupees, recipient_relationship, long_term_horizon_years, founder_approval_status, audit_red_flag, audit_note, approved_at)
select id, 'Rajesh Kumar',     'medical_emergency',   'disbursement_out',  85000, 'self',      0,  'approved',      false, 'Cardiac procedure; immediate.',           '2025-05-12 10:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q1' and fiscal_year=2025 
union all
select id, 'Priya Sharma',     'family_education',    'disbursement_out',  45000, 'child',     12, 'approved',      false, 'Daughter engineering admission.',         '2025-05-20 11:30:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q1' and fiscal_year=2025 
union all
select id, 'Amit Patel',       'wellness_grant',      'disbursement_out',  15000, 'self',      0,  'auto_approved', false, 'Annual wellness checkup grant.',          '2025-06-01 09:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q1' and fiscal_year=2025 
union all
select id, 'Founder Match',    'retirement_bridge',   'contribution_in',  300000, null,        20, 'approved',      false, 'Founder personal contribution.',          '2025-04-05 08:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q1' and fiscal_year=2025 
union all
select id, 'Suresh Reddy',     'disability_support',  'disbursement_out',  60000, 'self',      5,  'approved',      false, 'Long-term back injury support.',          '2025-08-14 10:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q2' and fiscal_year=2025 
union all
select id, 'Lakshmi Iyer',     'bereavement',         'disbursement_out',  90000, 'estate',    0,  'approved',      false, 'Father passed; estate support.',          '2025-09-02 16:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q2' and fiscal_year=2025 
union all
select id, 'Quarterly Pool',   'retirement_bridge',   'contribution_in',  450000, null,        25, 'auto_approved', false, 'Engineer payroll contribution 2%.',       '2025-07-31 23:59:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q2' and fiscal_year=2025 
union all
select id, 'Vijay Singh',      'sabbatical_allowance','disbursement_out',  80000, 'self',      1,  'escalated',     true,  'Sabbatical request flagged for board review.', null from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q3' and fiscal_year=2025 
union all
select id, 'Anjali Mehta',     'family_education',    'disbursement_out',  55000, 'child',     10, 'approved',      false, 'Son school admission.',                  '2025-11-08 11:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q3' and fiscal_year=2025 
union all
select id, 'Founder Match',    'retirement_bridge',   'contribution_in',  500000, null,        20, 'approved',      false, 'Q3 founder contribution match.',          '2025-12-31 23:59:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q3' and fiscal_year=2025 
union all
select id, 'Ravi Verma',       'equipment_relief',    'disbursement_out',  35000, 'self',      0,  'approved',      false, 'Tool replacement after theft.',           '2026-02-10 14:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q4' and fiscal_year=2025 
union all
select id, 'Neha Kapoor',      'medical_emergency',   'disbursement_out', 120000, 'parent',    0,  'approved',      false, 'Mother bypass surgery.',                  '2026-02-18 09:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q4' and fiscal_year=2025 
union all
select id, 'Arvind Joshi',     'wellness_grant',      'disbursement_out',  18000, 'self',      0,  'auto_approved', false, 'Annual checkup.',                         '2026-03-15 10:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q4' and fiscal_year=2025 
union all
select id, 'Quarterly Pool',   'retirement_bridge',   'contribution_in',  600000, null,        25, 'auto_approved', false, 'Q4 engineer payroll contribution.',       '2026-03-31 23:59:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q4' and fiscal_year=2025 
union all
select id, 'Kiran Desai',      'disability_support',  'disbursement_out',  75000, 'self',      8,  'approved',      false, 'Knee surgery + rehab.',                   '2026-05-04 11:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q1' and fiscal_year=2026 
union all
select id, 'Manish Rao',       'family_education',    'disbursement_out',  65000, 'child',     14, 'approved',      false, 'Daughter coaching for NEET.',             '2026-05-22 10:30:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q1' and fiscal_year=2026 
union all
select id, 'Sunita Bose',      'bereavement',         'disbursement_out', 110000, 'spouse',    0,  'approved',      false, 'Husband passed; long-term care.',         '2026-06-08 15:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q1' and fiscal_year=2026 
union all
select id, 'Anonymous Audit',  'adjustment'::text,    'reversal',          25000, null,        0,  'approved',      true,  'Reversal: double-paid disbursement Q4 2025.', '2026-06-15 12:00:00+05:30'::timestamptz from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q1' and fiscal_year=2026 
union all
select id, 'Founder Match',    'retirement_bridge',   'contribution_in',  700000, null,        20, 'pending',       false, 'Q2 2026 founder match queued.',           null from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q2' and fiscal_year=2026 
union all
select id, 'Deepak Nair',      'sabbatical_allowance','disbursement_out',  95000, 'self',      1,  'pending',       false, 'Sabbatical request for upskilling.',      null from public.founder_trust_fund_audit_periods_r3085 where fiscal_quarter='Q2' and fiscal_year=2026;

-- Fix line above: adjustment is not in care_category. Re-do that row with valid category.
update public.founder_trust_fund_line_items_r3085
  set care_category = 'equipment_relief'
  where engineer_name = 'Anonymous Audit';

-- =========================================================================
-- RPC 1: list audit periods
-- =========================================================================
create or replace function public.founder_trust_fund_list_periods_r3085()
returns table(
  id uuid,
  fiscal_quarter text,
  fiscal_year int,
  period_start date,
  period_end date,
  audit_status text,
  trust_fund_balance_rupees bigint,
  total_contributions_rupees bigint,
  total_disbursements_rupees bigint,
  engineer_count_covered int,
  governance_tier text,
  signed_off_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select p.id, p.fiscal_quarter, p.fiscal_year, p.period_start, p.period_end, p.audit_status,
           p.trust_fund_balance_rupees, p.total_contributions_rupees, p.total_disbursements_rupees,
           p.engineer_count_covered, p.governance_tier, p.signed_off_at
    from public.founder_trust_fund_audit_periods_r3085 p
    order by p.fiscal_year desc, p.fiscal_quarter desc;
end;
$$;

revoke all on function public.founder_trust_fund_list_periods_r3085() from public, anon;
grant execute on function public.founder_trust_fund_list_periods_r3085() to authenticated;

-- =========================================================================
-- RPC 2: line items
-- =========================================================================
create or replace function public.founder_trust_fund_list_line_items_r3085()
returns table(
  id uuid,
  engineer_name text,
  care_category text,
  flow_direction text,
  amount_rupees bigint,
  recipient_relationship text,
  long_term_horizon_years int,
  founder_approval_status text,
  audit_red_flag boolean,
  audit_note text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select l.id, l.engineer_name, l.care_category, l.flow_direction, l.amount_rupees,
           l.recipient_relationship, l.long_term_horizon_years, l.founder_approval_status,
           l.audit_red_flag, l.audit_note
    from public.founder_trust_fund_line_items_r3085 l
    order by l.created_at desc
    limit 50;
end;
$$;

revoke all on function public.founder_trust_fund_list_line_items_r3085() from public, anon;
grant execute on function public.founder_trust_fund_list_line_items_r3085() to authenticated;

-- =========================================================================
-- RPC 3: rollup by quarter
-- =========================================================================
create or replace function public.founder_trust_fund_rollup_by_quarter_r3085()
returns table(
  fiscal_year int,
  fiscal_quarter text,
  audit_status text,
  total_contributions_rupees bigint,
  total_disbursements_rupees bigint,
  net_change_rupees bigint,
  balance_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select p.fiscal_year, p.fiscal_quarter, p.audit_status,
           p.total_contributions_rupees,
           p.total_disbursements_rupees,
           (p.total_contributions_rupees - p.total_disbursements_rupees)::bigint as net_change_rupees,
           p.trust_fund_balance_rupees
    from public.founder_trust_fund_audit_periods_r3085 p
    order by p.fiscal_year desc, p.fiscal_quarter desc;
end;
$$;

revoke all on function public.founder_trust_fund_rollup_by_quarter_r3085() from public, anon;
grant execute on function public.founder_trust_fund_rollup_by_quarter_r3085() to authenticated;

-- =========================================================================
-- RPC 4: category breakdown
-- =========================================================================
create or replace function public.founder_trust_fund_category_breakdown_r3085()
returns table(
  care_category text,
  disbursement_count int,
  total_amount_rupees bigint,
  red_flag_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select l.care_category,
           (count(*) filter (where l.flow_direction = 'disbursement_out'))::int as disbursement_count,
           coalesce(sum(l.amount_rupees) filter (where l.flow_direction = 'disbursement_out'),0)::bigint as total_amount_rupees,
           (count(*) filter (where l.audit_red_flag))::int as red_flag_count
    from public.founder_trust_fund_line_items_r3085 l
    group by l.care_category
    order by total_amount_rupees desc;
end;
$$;

revoke all on function public.founder_trust_fund_category_breakdown_r3085() from public, anon;
grant execute on function public.founder_trust_fund_category_breakdown_r3085() to authenticated;

-- =========================================================================
-- RPC 5: pending approvals
-- =========================================================================
create or replace function public.founder_trust_fund_pending_approvals_r3085()
returns table(
  id uuid,
  engineer_name text,
  care_category text,
  amount_rupees bigint,
  founder_approval_status text,
  audit_note text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select l.id, l.engineer_name, l.care_category, l.amount_rupees, l.founder_approval_status, l.audit_note
    from public.founder_trust_fund_line_items_r3085 l
    where l.founder_approval_status in ('pending','escalated')
    order by l.amount_rupees desc;
end;
$$;

revoke all on function public.founder_trust_fund_pending_approvals_r3085() from public, anon;
grant execute on function public.founder_trust_fund_pending_approvals_r3085() to authenticated;

-- =========================================================================
-- RPC 6: governance tier rollup
-- =========================================================================
create or replace function public.founder_trust_fund_governance_rollup_r3085()
returns table(
  governance_tier text,
  period_count int,
  total_balance_rupees bigint,
  signed_off_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select p.governance_tier,
           count(*)::int as period_count,
           coalesce(sum(p.trust_fund_balance_rupees),0)::bigint as total_balance_rupees,
           (count(*) filter (where p.audit_status = 'signed_off'))::int as signed_off_count
    from public.founder_trust_fund_audit_periods_r3085 p
    group by p.governance_tier
    order by total_balance_rupees desc;
end;
$$;

revoke all on function public.founder_trust_fund_governance_rollup_r3085() from public, anon;
grant execute on function public.founder_trust_fund_governance_rollup_r3085() to authenticated;

-- =========================================================================
-- RPC 7: red flag audit summary
-- =========================================================================
create or replace function public.founder_trust_fund_red_flag_summary_r3085()
returns table(
  total_line_items int,
  red_flag_items int,
  total_amount_flagged_rupees bigint,
  pending_count int,
  escalated_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select count(*)::int as total_line_items,
           (count(*) filter (where l.audit_red_flag))::int as red_flag_items,
           coalesce(sum(l.amount_rupees) filter (where l.audit_red_flag),0)::bigint as total_amount_flagged_rupees,
           (count(*) filter (where l.founder_approval_status = 'pending'))::int as pending_count,
           (count(*) filter (where l.founder_approval_status = 'escalated'))::int as escalated_count
    from public.founder_trust_fund_line_items_r3085 l;
end;
$$;

revoke all on function public.founder_trust_fund_red_flag_summary_r3085() from public, anon;
grant execute on function public.founder_trust_fund_red_flag_summary_r3085() to authenticated;

-- =========================================================================
-- RPC 8 (bonus): long-term horizon distribution
-- =========================================================================
create or replace function public.founder_trust_fund_horizon_distribution_r3085()
returns table(
  horizon_bucket text,
  item_count int,
  total_amount_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select case
             when l.long_term_horizon_years is null then 'unspecified'
             when l.long_term_horizon_years = 0 then 'immediate'
             when l.long_term_horizon_years between 1 and 5 then 'short_term_1_5y'
             when l.long_term_horizon_years between 6 and 15 then 'mid_term_6_15y'
             else 'long_term_16_plus_y'
           end as horizon_bucket,
           count(*)::int as item_count,
           coalesce(sum(l.amount_rupees),0)::bigint as total_amount_rupees
    from public.founder_trust_fund_line_items_r3085 l
    group by 1
    order by total_amount_rupees desc;
end;
$$;

revoke all on function public.founder_trust_fund_horizon_distribution_r3085() from public, anon;
grant execute on function public.founder_trust_fund_horizon_distribution_r3085() to authenticated;
