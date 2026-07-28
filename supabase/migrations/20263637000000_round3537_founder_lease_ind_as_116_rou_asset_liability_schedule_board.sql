-- Round 3537: Founder Lease IND-AS-116 ROU-Asset / Liability Schedule Board
-- Founder IND-AS-116 lease accounting — per-lease ROU asset + lease liability schedule × asset class ×
-- lease status × term × discount rate × interest/depreciation YTD × monthly amortization trend × CAPA closure

-- =============================================================================
-- TABLE 1: lease_ind_as_116_r3537 — per-lease ROU asset & lease liability schedule
-- =============================================================================
create table if not exists public.lease_ind_as_116_r3537 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  lease_name text not null,
  lease_code text not null,
  asset_class text not null check (asset_class in (
    'office','warehouse','vehicle','equipment','land','it_hardware'
  )),
  lease_term_months int,
  rou_asset_rupees numeric(16,2),
  lease_liability_rupees numeric(16,2),
  monthly_rental_rupees numeric(14,2),
  discount_rate_pct numeric(5,2),
  interest_ytd_rupees numeric(16,2),
  depreciation_ytd_rupees numeric(16,2),
  lease_status text not null check (lease_status in (
    'active','renewed','modified','terminated','expiring'
  )),
  commencement_date date,
  period_month date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lease_ind_as_116_r3537 enable row level security;

create index if not exists idx_lease_ind_as_116_r3537_org on public.lease_ind_as_116_r3537(organization_id);
create index if not exists idx_lease_ind_as_116_r3537_month on public.lease_ind_as_116_r3537(period_month);
create index if not exists idx_lease_ind_as_116_r3537_status on public.lease_ind_as_116_r3537(lease_status);

-- =============================================================================
-- TABLE 2: lease_ind_as_116_capa_actions_r3537 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.lease_ind_as_116_capa_actions_r3537 (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid not null references public.lease_ind_as_116_r3537(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'discount_rate_error','rou_asset_misstatement','lease_liability_misstatement','lease_term_reassessment',
    'depreciation_error','interest_accrual_error','lease_classification_error','disclosure_gap',
    'modification_not_remeasured','impairment_indicator'
  )),
  root_cause text not null check (root_cause in (
    'incorrect_ibr_rate','missed_modification','manual_schedule_error','index_rate_reset_missed',
    'term_option_misjudged','system_config_error','pending_investigation','data_entry_error',
    'contract_terms_ambiguous','valuation_input_stale'
  )),
  corrective_action text not null check (corrective_action in (
    'remeasure_liability','adjust_discount_rate','reassess_lease_term','correct_depreciation_schedule',
    'restate_disclosure','update_system_config','reclassify_lease','recognize_impairment',
    'obtain_valuation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  capa_impact_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lease_ind_as_116_capa_actions_r3537 enable row level security;

create index if not exists idx_lease_ind_as_116_capa_r3537_link on public.lease_ind_as_116_capa_actions_r3537(lease_id);
create index if not exists idx_lease_ind_as_116_capa_r3537_status on public.lease_ind_as_116_capa_actions_r3537(capa_status);

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

  -- 16 lease schedule rows
  insert into public.lease_ind_as_116_r3537 (
    organization_id, lease_name, lease_code, asset_class, lease_term_months,
    rou_asset_rupees, lease_liability_rupees, monthly_rental_rupees, discount_rate_pct,
    interest_ytd_rupees, depreciation_ytd_rupees, lease_status, commencement_date, period_month, notes
  )
  select v_org_id, q.lname, q.lcode, q.acls, q.term::int,
    q.rou::numeric, q.liab::numeric, q.rent::numeric, q.rate::numeric,
    q.intytd::numeric, q.depytd::numeric, q.lstat, q.cdate::date, q.pmonth::date, q.nt
  from (values
    ('Chennai HQ Office Floor 4','LEASE-CHN-OFF-01','office',84,45000000,42500000,650000,9.00,2870000,3210000,'active','2023-04-01','2026-07-01','7-yr Chennai HQ office ROU; IBR 9%, straight-line depreciation'),
    ('Bengaluru Sales Office','LEASE-BLR-OFF-02','office',60,18000000,16200000,320000,8.75,1080000,1500000,'active','2023-07-01','2026-07-01','Bengaluru branch office, 5-yr term, on schedule'),
    ('Mumbai Regional Office','LEASE-MUM-OFF-03','office',72,28000000,26800000,480000,9.25,2010000,1950000,'modified','2024-01-01','2026-07-01','Rent-escalation modification — remeasurement pending Apr-2026'),
    ('Gurgaon North Warehouse','LEASE-GGN-WH-04','warehouse',120,62000000,58500000,720000,9.50,4680000,3100000,'active','2022-04-01','2026-07-01','Spare-parts warehouse, 10-yr lease, large liability balance'),
    ('Hyderabad Distribution Hub','LEASE-HYD-WH-05','warehouse',96,38000000,35200000,540000,9.00,2820000,2375000,'active','2023-01-01','2026-06-01','Distribution warehouse near Shamshabad, 8-yr lease'),
    ('Pune Service Warehouse','LEASE-PUN-WH-06','warehouse',60,14500000,9800000,290000,8.50,833000,1450000,'expiring','2022-08-01','2026-06-01','Lease expiring Jul-2027; renewal vs exit under review'),
    ('Field Service Van Fleet A','LEASE-VEH-VAN-07','vehicle',48,7200000,4100000,165000,8.00,328000,1200000,'active','2023-10-01','2026-06-01','10 service vans on lease, 4-yr term'),
    ('Executive Car Lease','LEASE-VEH-CAR-08','vehicle',36,3600000,1450000,110000,8.25,120000,900000,'expiring','2024-02-01','2026-06-01','5 exec cars, lease expiring; buy-out being evaluated'),
    ('Ambulance Demo Fleet','LEASE-VEH-AMB-09','vehicle',60,9500000,8700000,195000,8.50,725000,950000,'active','2024-04-01','2026-05-01','Demo ambulances for OEM tie-up, 5-yr lease'),
    ('Calibration Lab Equipment','LEASE-EQP-LAB-10','equipment',60,12000000,10800000,240000,9.00,900000,1200000,'active','2024-01-01','2026-05-01','Leased calibration bench and reference standards'),
    ('Biomedical Test Rigs','LEASE-EQP-RIG-11','equipment',48,8800000,7200000,205000,8.75,595000,1100000,'renewed','2023-06-01','2026-05-01','Test rigs lease renewed with revised term and rate'),
    ('Sterilizer Loaner Unit','LEASE-EQP-STE-12','equipment',36,5400000,2100000,170000,9.50,180000,1350000,'terminated','2024-03-01','2026-05-01','Early terminated; liability derecognised, gain to P&L'),
    ('Chennai Land Parcel','LEASE-LND-CHN-13','land',180,95000000,91000000,600000,10.00,7280000,0,'active','2022-04-01','2026-04-01','15-yr land lease — no ROU depreciation on land element'),
    ('Coimbatore Yard Land','LEASE-LND-CBE-14','land',120,42000000,40500000,340000,9.75,3120000,0,'modified','2023-01-01','2026-04-01','Yard land lease — CPI index-reset modification remeasured'),
    ('Data Center Hardware','LEASE-IT-DC-15','it_hardware',36,15600000,9400000,480000,8.00,752000,3900000,'active','2024-06-01','2026-04-01','Servers and storage on 3-yr lease, fast depreciation'),
    ('Branch Laptop Fleet','LEASE-IT-LAP-16','it_hardware',36,4200000,1650000,135000,8.25,138000,1050000,'expiring','2024-01-01','2026-04-01','Laptop fleet lease expiring; refresh cycle planned')
  ) as q(lname, lcode, acls, term, rou, liab, rent, rate, intytd, depytd, lstat, cdate, pmonth, nt);

  -- CAPA seed — attach to specific leases via lease_code
  insert into public.lease_ind_as_116_capa_actions_r3537 (
    lease_id, finding_category, root_cause, corrective_action,
    capa_status, capa_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp::numeric, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('LEASE-MUM-OFF-03','modification_not_remeasured','missed_modification','remeasure_liability','in_progress',250000,'Finance Controller','2026-08-15',null,'Rent-escalation modification not yet remeasured; ROU/liability to be adjusted'),
    ('LEASE-GGN-WH-04','lease_liability_misstatement','incorrect_ibr_rate','adjust_discount_rate','open',480000,'Lease Accountant','2026-08-30',null,'IBR applied above group treasury rate; liability overstated pending correction'),
    ('LEASE-PUN-WH-06','lease_term_reassessment','term_option_misjudged','reassess_lease_term','verification_pending',90000,'Regional Finance','2026-08-10',null,'Renewal-option reasonably-certain assessment revisited near lease end'),
    ('LEASE-VEH-CAR-08','disclosure_gap','data_entry_error','restate_disclosure','closed',25000,'AP Team','2026-07-20','2026-07-18','Maturity-analysis note corrected in lease-liability disclosure'),
    ('LEASE-EQP-STE-12','lease_classification_error','contract_terms_ambiguous','reclassify_lease','escalated',350000,'Group Controller','2026-08-05',null,'Short-term vs finance-substance classification escalated to audit committee'),
    ('LEASE-LND-CBE-14','discount_rate_error','index_rate_reset_missed','adjust_discount_rate','overdue',175000,'Lease Accountant','2026-07-15',null,'CPI index reset missed for two periods; remeasurement overdue'),
    ('LEASE-IT-DC-15','depreciation_error','manual_schedule_error','correct_depreciation_schedule','in_progress',60000,'Fixed Assets Team','2026-08-20',null,'ROU depreciation schedule mis-keyed; catch-up entry under review'),
    ('LEASE-CHN-OFF-01','interest_accrual_error','system_config_error','update_system_config','closed',40000,'IT Finance','2026-07-25','2026-07-22','Effective-interest posting rule reconfigured in ledger engine')
  ) as q(lcode, fc, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.lease_ind_as_116_r3537 e
    on e.organization_id = v_org_id and e.lease_code = q.lcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Lease-status distribution
create or replace function public.founder_r3537_lease_status_rollup()
returns table(lease_status text, leases bigint, total_liability_rupees numeric, total_rou_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lease_ind_as_116_r3537)
  select l.lease_status,
    count(*)::bigint,
    coalesce(sum(l.lease_liability_rupees),0)::numeric,
    coalesce(sum(l.rou_asset_rupees),0)::numeric,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.lease_ind_as_116_r3537 l
  group by l.lease_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3537_lease_status_rollup() from public, anon;
grant execute on function public.founder_r3537_lease_status_rollup() to authenticated;

-- 2) Asset-class scorecard
create or replace function public.founder_r3537_asset_class_scorecard()
returns table(
  asset_class text,
  leases bigint,
  total_rou_rupees numeric,
  total_liability_rupees numeric,
  total_monthly_rental_rupees numeric,
  expiring bigint,
  modified bigint,
  avg_discount_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_class,
    count(*)::bigint,
    coalesce(sum(l.rou_asset_rupees),0)::numeric,
    coalesce(sum(l.lease_liability_rupees),0)::numeric,
    coalesce(sum(l.monthly_rental_rupees),0)::numeric,
    count(*) filter (where l.lease_status = 'expiring')::bigint,
    count(*) filter (where l.lease_status = 'modified')::bigint,
    round(avg(l.discount_rate_pct), 2)
  from public.lease_ind_as_116_r3537 l
  group by l.asset_class
  order by coalesce(sum(l.lease_liability_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3537_asset_class_scorecard() from public, anon;
grant execute on function public.founder_r3537_asset_class_scorecard() to authenticated;

-- 3) Asset-class × lease-status matrix
create or replace function public.founder_r3537_asset_class_status_matrix()
returns table(asset_class text, lease_status text, leases bigint, total_liability_rupees numeric, avg_term_months numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_class, l.lease_status,
    count(*)::bigint,
    coalesce(sum(l.lease_liability_rupees),0)::numeric,
    round(avg(l.lease_term_months), 1)
  from public.lease_ind_as_116_r3537 l
  group by l.asset_class, l.lease_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3537_asset_class_status_matrix() from public, anon;
grant execute on function public.founder_r3537_asset_class_status_matrix() to authenticated;

-- 4) Monthly liability-amortization trend
create or replace function public.founder_r3537_liability_amortization_trend()
returns table(
  period_month date,
  leases bigint,
  total_liability_rupees numeric,
  total_interest_ytd_rupees numeric,
  total_depreciation_ytd_rupees numeric,
  total_monthly_rental_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.lease_liability_rupees),0)::numeric,
    coalesce(sum(l.interest_ytd_rupees),0)::numeric,
    coalesce(sum(l.depreciation_ytd_rupees),0)::numeric,
    coalesce(sum(l.monthly_rental_rupees),0)::numeric
  from public.lease_ind_as_116_r3537 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3537_liability_amortization_trend() from public, anon;
grant execute on function public.founder_r3537_liability_amortization_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3537_capa_status_board()
returns table(capa_status text, actions bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.capa_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.lease_ind_as_116_capa_actions_r3537 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3537_capa_status_board() from public, anon;
grant execute on function public.founder_r3537_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3537_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lease_ind_as_116_capa_actions_r3537)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.capa_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.lease_ind_as_116_capa_actions_r3537 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3537_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3537_root_cause_pareto() to authenticated;

-- 7) Liability-impact digest (by CAPA finding category)
create or replace function public.founder_r3537_liability_impact_digest()
returns table(finding_category text, actions bigint, open_actions bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.capa_impact_rupees),0)::numeric
  from public.lease_ind_as_116_capa_actions_r3537 c
  group by c.finding_category
  order by coalesce(sum(c.capa_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3537_liability_impact_digest() from public, anon;
grant execute on function public.founder_r3537_liability_impact_digest() to authenticated;

-- 8) High-risk queue (expiring / modified / terminated / large-liability)
create or replace function public.founder_r3537_high_risk_queue()
returns table(
  lease_name text,
  lease_code text,
  asset_class text,
  lease_status text,
  lease_liability_rupees numeric,
  monthly_rental_rupees numeric,
  discount_rate_pct numeric,
  commencement_date date,
  period_month date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lease_name, l.lease_code, l.asset_class, l.lease_status,
    l.lease_liability_rupees, l.monthly_rental_rupees, l.discount_rate_pct,
    l.commencement_date, l.period_month, l.notes
  from public.lease_ind_as_116_r3537 l
  where l.lease_status in ('expiring','modified','terminated')
     or l.lease_liability_rupees >= 40000000
  order by l.lease_liability_rupees desc nulls last, l.lease_name;
end;
$$;

revoke execute on function public.founder_r3537_high_risk_queue() from public, anon;
grant execute on function public.founder_r3537_high_risk_queue() to authenticated;
