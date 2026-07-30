-- Round 3606: Founder Deferred-Tax / MAT-Credit / Timing-Difference Board
-- Deferred-tax log — entity × period × accounting vs taxable profit × timing difference × DTA/DTL × net deferred tax × MAT credit build/utilization × effective tax rate × deferred-tax status × trend × CAPA

-- =============================================================================
-- TABLE 1: deferred_tax_r3606 — per-entity deferred-tax / MAT-credit position
-- =============================================================================
create table if not exists public.deferred_tax_r3606 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  entry_code text not null,
  period_month date not null,
  accounting_profit_rupees numeric(16,2) not null,
  taxable_profit_rupees numeric(16,2) not null,
  timing_difference_rupees numeric(16,2) not null,
  dta_rupees numeric(16,2) not null,
  dtl_rupees numeric(16,2) not null,
  net_deferred_tax_rupees numeric(16,2) not null,
  mat_credit_rupees numeric(16,2) not null,
  mat_credit_utilized_rupees numeric(16,2) not null,
  effective_tax_rate_pct numeric(6,2) not null,
  dt_status text not null check (dt_status in (
    'dta_dominant','dtl_dominant','balanced','mat_credit_risk','unrecognized_dta'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.deferred_tax_r3606 enable row level security;

create index if not exists idx_deferred_tax_r3606_org on public.deferred_tax_r3606(organization_id);
create index if not exists idx_deferred_tax_r3606_period on public.deferred_tax_r3606(period_month);
create index if not exists idx_deferred_tax_r3606_status on public.deferred_tax_r3606(dt_status);

-- =============================================================================
-- TABLE 2: deferred_tax_capa_actions_r3606 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.deferred_tax_capa_actions_r3606 (
  id uuid primary key default gen_random_uuid(),
  dt_log_id uuid not null references public.deferred_tax_r3606(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'timing_difference_reversal_risk','mat_credit_expiry_risk','dta_recoverability_doubt',
    'dtl_understated','effective_tax_rate_spike','depreciation_difference',
    'provision_disallowance','carryforward_loss_lapse','tax_rate_change_impact'
  )),
  root_cause text not null check (root_cause in (
    'depreciation_wdv_vs_slm_gap','provision_not_deductible_till_paid','mat_credit_15yr_expiry_approaching',
    'unabsorbed_loss_expiry','section_43b_disallowance','profit_insufficient_to_absorb',
    'tax_rate_regime_change','fair_value_remeasurement','pending_investigation','estimation_error'
  )),
  corrective_action text not null check (corrective_action in (
    'recognize_dta_with_convincing_evidence','derecognize_dta','accelerate_mat_credit_utilization',
    'reforecast_taxable_profit','reverse_timing_difference','reclassify_dta_dtl',
    'opt_new_tax_regime','book_provision_adjustment','escalate_to_auditor','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.deferred_tax_capa_actions_r3606 enable row level security;

create index if not exists idx_deferred_tax_capa_r3606_log on public.deferred_tax_capa_actions_r3606(dt_log_id);
create index if not exists idx_deferred_tax_capa_r3606_status on public.deferred_tax_capa_actions_r3606(capa_status);

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

  -- 16 deferred-tax rows
  insert into public.deferred_tax_r3606 (
    organization_id, entity_name, entry_code, period_month,
    accounting_profit_rupees, taxable_profit_rupees, timing_difference_rupees,
    dta_rupees, dtl_rupees, net_deferred_tax_rupees,
    mat_credit_rupees, mat_credit_utilized_rupees, effective_tax_rate_pct,
    dt_status, trend_dir, notes
  )
  select v_org_id, q.ent, q.ecode, q.pmon::date,
    q.aprof, q.tprof, q.tdiff,
    q.dta, q.dtl, q.ndt,
    q.matc, q.matu, q.etr,
    q.dst, q.trd, q.nt
  from (values
    ('AMC Services Division','DT-AMC-2604','2026-04-01',
     18500000,16200000,2300000,578000,0,-578000,0,0,22.40,'dta_dominant','improving','Warranty and leave-encashment provisions create DTA reversing over AMC contract period'),
    ('AMC Services Division','DT-AMC-2605','2026-05-01',
     19200000,17100000,2100000,528000,0,-528000,0,0,22.90,'dta_dominant','stable','AMC provision DTA steady month on month'),
    ('Spare Parts Trading','DT-SPT-2604','2026-04-01',
     9400000,10100000,-700000,0,176000,176000,0,0,26.10,'dtl_dominant','stable','Higher tax depreciation on warehouse plant creates DTL'),
    ('Spare Parts Trading','DT-SPT-2605','2026-05-01',
     8800000,9600000,-800000,0,201000,201000,0,0,26.40,'dtl_dominant','worsening','Accelerated tax depreciation widening DTL'),
    ('Turnkey Projects','DT-TKP-2604','2026-04-01',
     12000000,12100000,-100000,210000,235000,25000,0,0,25.20,'balanced','stable','POC revenue timing roughly offsets depreciation DTL'),
    ('Turnkey Projects','DT-TKP-2605','2026-05-01',
     6500000,4200000,2300000,320000,260000,-60000,480000,0,18.10,'mat_credit_risk','worsening','Book profit high vs low taxable profit; MAT paid and credit accumulating'),
    ('Diagnostics Labs','DT-DGN-2604','2026-04-01',
     15600000,9800000,5800000,0,0,0,1015000,0,15.50,'mat_credit_risk','worsening','Sec 35AD weighted deduction; MAT credit building, utilization uncertain'),
    ('Diagnostics Labs','DT-DGN-2605','2026-05-01',
     16100000,10500000,5600000,0,0,0,980000,120000,16.20,'mat_credit_risk','stable','MAT credit partially utilized; monitor 15-year expiry window'),
    ('Equipment Rentals','DT-RNT-2604','2026-04-01',
     4200000,5600000,-1400000,0,352000,352000,0,0,27.00,'dtl_dominant','stable','Rental-asset depreciation faster for tax purposes creating DTL'),
    ('Equipment Rentals','DT-RNT-2605','2026-05-01',
     3900000,5100000,-1200000,0,302000,302000,0,0,26.70,'dtl_dominant','improving','DTL narrowing as rental fleet matures'),
    ('Biomedical Engineering','DT-BME-2604','2026-04-01',
     -2100000,-3400000,1300000,0,0,0,0,0,0.00,'unrecognized_dta','worsening','Carryforward-loss DTA not recognized; no convincing evidence of future taxable profit'),
    ('Biomedical Engineering','DT-BME-2605','2026-05-01',
     -1800000,-2900000,1100000,0,0,0,0,0,0.00,'unrecognized_dta','stable','Unrecognized DTA on unabsorbed depreciation carried forward'),
    ('Imports and Distribution','DT-IMP-2604','2026-04-01',
     7300000,6900000,400000,100000,88000,-12000,0,0,24.60,'balanced','stable','Sec 43B disallowance DTA vs depreciation DTL nearly offset'),
    ('Imports and Distribution','DT-IMP-2605','2026-05-01',
     7600000,7050000,550000,138000,92000,-46000,0,0,24.10,'dta_dominant','improving','Sec 43B provisions increase DTA position'),
    ('AMC Services Division','DT-AMC-2606','2026-06-01',
     20100000,18000000,2100000,528000,0,-528000,0,0,23.00,'dta_dominant','stable','Q1 close — AMC provision DTA consistent'),
    ('Diagnostics Labs','DT-DGN-2606','2026-06-01',
     17000000,11200000,5800000,0,0,0,1030000,90000,16.80,'mat_credit_risk','worsening','MAT credit at risk of partial lapse within three years')
  ) as q(ent, ecode, pmon, aprof, tprof, tdiff, dta, dtl, ndt, matc, matu, etr, dst, trd, nt);

  -- CAPA seed — attach to specific entries via entry_code
  insert into public.deferred_tax_capa_actions_r3606 (
    dt_log_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DT-DGN-2604','mat_credit_expiry_risk','mat_credit_15yr_expiry_approaching','accelerate_mat_credit_utilization','in_progress',1015000,'CFO','2026-08-31',null,'Shift new equipment capex to build taxable profit and absorb MAT credit'),
    ('DT-BME-2604','dta_recoverability_doubt','profit_insufficient_to_absorb','derecognize_dta','closed',1300000,'Financial Controller','2026-06-15','2026-06-10','DTA on carryforward loss derecognized — no convincing evidence of recovery'),
    ('DT-SPT-2605','dtl_understated','depreciation_wdv_vs_slm_gap','reclassify_dta_dtl','verification_pending',201000,'Tax Manager','2026-08-15',null,'DTL recomputed on WDV vs SLM gap — awaiting auditor review'),
    ('DT-TKP-2605','mat_credit_expiry_risk','section_43b_disallowance','reforecast_taxable_profit','open',480000,'CFO','2026-09-30',null,'Reforecast Turnkey taxable profit to justify MAT-credit recovery'),
    ('DT-DGN-2606','carryforward_loss_lapse','mat_credit_15yr_expiry_approaching','escalate_to_auditor','escalated',1030000,'CFO','2026-07-20',null,'MAT credit at risk of lapse within three years — escalated to statutory auditor'),
    ('DT-RNT-2604','depreciation_difference','depreciation_wdv_vs_slm_gap','book_provision_adjustment','closed',352000,'Tax Manager','2026-06-30','2026-06-25','Rental-asset DTL booked and reconciled'),
    ('DT-BME-2605','dta_recoverability_doubt','unabsorbed_loss_expiry','derecognize_dta','overdue',1100000,'Financial Controller','2026-07-10',null,'Unabsorbed-depreciation DTA review past target date'),
    ('DT-IMP-2604','provision_disallowance','section_43b_disallowance','book_provision_adjustment','in_progress',100000,'Tax Manager','2026-08-05',null,'Sec 43B provision DTA validation in progress')
  ) as q(ecode, fc, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.deferred_tax_r3606 e
    on e.organization_id = v_org_id and e.entry_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Deferred-tax status distribution
create or replace function public.founder_r3606_dt_status_rollup()
returns table(dt_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.deferred_tax_r3606)
  select l.dt_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.deferred_tax_r3606 l
  group by l.dt_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3606_dt_status_rollup() from public, anon;
grant execute on function public.founder_r3606_dt_status_rollup() to authenticated;

-- 2) Entity-level deferred-tax scorecard
create or replace function public.founder_r3606_entity_scorecard()
returns table(
  entity_name text,
  total_entries bigint,
  dta_dominant bigint,
  dtl_dominant bigint,
  mat_credit_risk bigint,
  unrecognized_dta bigint,
  net_deferred_tax_rupees numeric,
  mat_credit_outstanding_rupees numeric,
  avg_effective_tax_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    count(*) filter (where l.dt_status = 'dta_dominant')::bigint,
    count(*) filter (where l.dt_status = 'dtl_dominant')::bigint,
    count(*) filter (where l.dt_status = 'mat_credit_risk')::bigint,
    count(*) filter (where l.dt_status = 'unrecognized_dta')::bigint,
    coalesce(sum(l.net_deferred_tax_rupees),0)::numeric,
    coalesce(sum(l.mat_credit_rupees - l.mat_credit_utilized_rupees),0)::numeric,
    round(avg(l.effective_tax_rate_pct), 2)
  from public.deferred_tax_r3606 l
  group by l.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3606_entity_scorecard() from public, anon;
grant execute on function public.founder_r3606_entity_scorecard() to authenticated;

-- 3) Entity × deferred-tax status matrix
create or replace function public.founder_r3606_entity_status_matrix()
returns table(entity_name text, dt_status text, entries bigint, net_deferred_tax_rupees numeric, timing_difference_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.dt_status, count(*)::bigint,
    coalesce(sum(l.net_deferred_tax_rupees),0)::numeric,
    coalesce(sum(l.timing_difference_rupees),0)::numeric
  from public.deferred_tax_r3606 l
  group by l.entity_name, l.dt_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3606_entity_status_matrix() from public, anon;
grant execute on function public.founder_r3606_entity_status_matrix() to authenticated;

-- 4) Monthly deferred-tax trend
create or replace function public.founder_r3606_monthly_deferred_tax_trend()
returns table(period_month date, entries bigint, net_deferred_tax_rupees numeric, dta_rupees numeric, dtl_rupees numeric, mat_credit_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.net_deferred_tax_rupees),0)::numeric,
    coalesce(sum(l.dta_rupees),0)::numeric,
    coalesce(sum(l.dtl_rupees),0)::numeric,
    coalesce(sum(l.mat_credit_rupees),0)::numeric
  from public.deferred_tax_r3606 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3606_monthly_deferred_tax_trend() from public, anon;
grant execute on function public.founder_r3606_monthly_deferred_tax_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3606_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.deferred_tax_capa_actions_r3606 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3606_capa_status_board() from public, anon;
grant execute on function public.founder_r3606_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3606_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.deferred_tax_capa_actions_r3606)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.deferred_tax_capa_actions_r3606 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3606_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3606_root_cause_pareto() to authenticated;

-- 7) Timing-difference digest (by trend direction)
create or replace function public.founder_r3606_timing_difference_digest()
returns table(
  trend_dir text,
  entries bigint,
  total_timing_difference_rupees numeric,
  total_net_deferred_tax_rupees numeric,
  avg_effective_tax_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.trend_dir,
    count(*)::bigint,
    coalesce(sum(l.timing_difference_rupees),0)::numeric,
    coalesce(sum(l.net_deferred_tax_rupees),0)::numeric,
    round(avg(l.effective_tax_rate_pct), 2)
  from public.deferred_tax_r3606 l
  group by l.trend_dir
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3606_timing_difference_digest() from public, anon;
grant execute on function public.founder_r3606_timing_difference_digest() to authenticated;

-- 8) High-risk deferred-tax queue (MAT-credit risk / unrecognized DTA / worsening)
create or replace function public.founder_r3606_high_risk_queue()
returns table(
  entity_name text,
  entry_code text,
  period_month date,
  dt_status text,
  trend_dir text,
  timing_difference_rupees numeric,
  net_deferred_tax_rupees numeric,
  mat_credit_rupees numeric,
  effective_tax_rate_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.entry_code, l.period_month, l.dt_status, l.trend_dir,
    l.timing_difference_rupees, l.net_deferred_tax_rupees, l.mat_credit_rupees,
    l.effective_tax_rate_pct, l.notes
  from public.deferred_tax_r3606 l
  where l.dt_status in ('mat_credit_risk','unrecognized_dta')
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.entity_name;
end;
$$;

revoke execute on function public.founder_r3606_high_risk_queue() from public, anon;
grant execute on function public.founder_r3606_high_risk_queue() to authenticated;
