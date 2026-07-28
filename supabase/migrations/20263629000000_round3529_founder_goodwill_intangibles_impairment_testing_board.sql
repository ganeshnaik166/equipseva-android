-- Round 3529: Founder Goodwill / Intangibles Impairment-Testing Board
-- Impairment testing — CGU carrying vs recoverable value × asset type × headroom × discount/growth assumptions × impairment status × trend × CAPA

-- =============================================================================
-- TABLE 1: goodwill_impairment_r3529 — per-CGU impairment test results
-- =============================================================================
create table if not exists public.goodwill_impairment_r3529 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cgu_code text not null,
  cgu_name text not null,
  reporting_unit text not null,
  asset_type text not null check (asset_type in (
    'goodwill','brand','customer_relationship','technology','license','software'
  )),
  valuation_basis text not null check (valuation_basis in (
    'value_in_use','fair_value_less_costs'
  )),
  carrying_value_rupees numeric(16,2),
  recoverable_value_rupees numeric(16,2),
  headroom_rupees numeric(16,2),
  headroom_pct numeric(7,2),
  discount_rate_pct numeric(5,2),
  growth_rate_pct numeric(5,2),
  impairment_status text not null check (impairment_status in (
    'no_impairment','watch','trigger_review','impaired','reversed'
  )),
  test_date date not null,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.goodwill_impairment_r3529 enable row level security;

create index if not exists idx_goodwill_impairment_r3529_org on public.goodwill_impairment_r3529(organization_id);
create index if not exists idx_goodwill_impairment_r3529_date on public.goodwill_impairment_r3529(test_date);
create index if not exists idx_goodwill_impairment_r3529_status on public.goodwill_impairment_r3529(impairment_status);

-- =============================================================================
-- TABLE 2: goodwill_impairment_capa_actions_r3529 — CAPA & accounting actions
-- =============================================================================
create table if not exists public.goodwill_impairment_capa_actions_r3529 (
  id uuid primary key default gen_random_uuid(),
  impairment_id uuid not null references public.goodwill_impairment_r3529(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'headroom_erosion','recoverable_value_decline','discount_rate_increase','growth_assumption_cut',
    'carrying_value_overstated','trigger_event_identified','impairment_recognized','reversal_assessment',
    'goodwill_allocation_error','budget_shortfall'
  )),
  root_cause text not null check (root_cause in (
    'market_multiple_compression','customer_churn','competitive_pressure','cost_inflation',
    'wacc_increase','revenue_miss','integration_underperformance','technology_obsolescence',
    'regulatory_change','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'revise_cash_flow_forecast','recognize_impairment_charge','reallocate_goodwill','update_discount_rate',
    'commission_independent_valuation','restructure_cgu','divest_asset','strengthen_monitoring',
    'disclose_in_notes','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  accounting_treatment text not null check (accounting_treatment in (
    'ind_as_36_impairment','ifrs_disclosure','audit_committee_review','board_note','internal_only','none'
  )),
  owner text not null,
  impairment_charge_rupees numeric(16,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.goodwill_impairment_capa_actions_r3529 enable row level security;

create index if not exists idx_goodwill_impairment_capa_r3529_link on public.goodwill_impairment_capa_actions_r3529(impairment_id);
create index if not exists idx_goodwill_impairment_capa_r3529_status on public.goodwill_impairment_capa_actions_r3529(capa_status);

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

  -- 16 CGU impairment test rows
  insert into public.goodwill_impairment_r3529 (
    organization_id, cgu_code, cgu_name, reporting_unit, asset_type, valuation_basis,
    carrying_value_rupees, recoverable_value_rupees, headroom_rupees, headroom_pct,
    discount_rate_pct, growth_rate_pct, impairment_status, test_date, trend_dir, notes
  )
  select v_org_id, q.code, q.nm, q.rptu, q.atype, q.vbasis,
    q.cval, q.rval, q.hrup, q.hpct,
    q.drate, q.grate, q.istat, q.tdate::date, q.tdir, q.nt
  from (values
    ('CGU-DIAG-01','Diagnostics Services CGU','Diagnostics','goodwill','value_in_use',
     480000000,612000000,132000000,27.50,13.50,6.00,'no_impairment','2026-03-31','improving','Annual Ind AS 36 test — comfortable headroom on volume growth'),
    ('CGU-HOSP-02','Hospital Chain CGU','Hospitals','goodwill','value_in_use',
     920000000,985000000,65000000,7.07,12.80,5.50,'watch','2026-03-31','stable','Headroom thinning on occupancy dip — placed on watch'),
    ('CGU-PHAR-03','Pharma Retail CGU','Pharmacy','goodwill','fair_value_less_costs',
     350000000,318000000,-32000000,-9.14,14.20,4.00,'impaired','2026-03-31','worsening','Recoverable below carrying — impairment charge recognised'),
    ('CGU-BRND-04','MediTrust Brand','Brand Portfolio','brand','value_in_use',
     210000000,268000000,58000000,27.62,13.00,5.00,'no_impairment','2026-04-30','stable','Brand valuation robust across metros'),
    ('CGU-CREL-05','Corporate Client Relationships','B2B','customer_relationship','value_in_use',
     140000000,132000000,-8000000,-5.71,13.80,3.50,'trigger_review','2026-04-30','worsening','Key account churn flagged as impairment trigger event'),
    ('CGU-TECH-06','LIS Platform Technology','Technology','technology','value_in_use',
     95000000,118000000,23000000,24.21,15.00,7.00,'no_impairment','2026-04-30','improving','Platform adoption ahead of plan'),
    ('CGU-LIC-07','Radiology License CGU','Imaging','license','fair_value_less_costs',
     60000000,58500000,-1500000,-2.50,12.50,2.00,'watch','2026-05-31','worsening','Regulatory license fair value slipping'),
    ('CGU-SOFT-08','HMS Software CGU','Software','software','value_in_use',
     78000000,96000000,18000000,23.08,14.50,6.50,'no_impairment','2026-05-31','stable','SaaS renewals steady'),
    ('CGU-DIAG-09','Wellness Diagnostics CGU','Diagnostics','goodwill','value_in_use',
     265000000,241000000,-24000000,-9.06,13.60,4.50,'impaired','2026-05-31','worsening','Volume decline post-normalisation — impaired'),
    ('CGU-BRND-10','HealthPlus Brand','Brand Portfolio','brand','fair_value_less_costs',
     120000000,155000000,35000000,29.17,12.90,5.00,'no_impairment','2026-06-30','improving','Brand equity strong in South region'),
    ('CGU-CREL-11','Insurance TPA Relationships','B2B','customer_relationship','value_in_use',
     88000000,92000000,4000000,4.55,13.40,3.00,'watch','2026-06-30','stable','Thin headroom on TPA contract renewals'),
    ('CGU-TECH-12','Teleradiology Tech CGU','Technology','technology','value_in_use',
     54000000,49000000,-5000000,-9.26,15.50,4.00,'trigger_review','2026-06-30','worsening','Competitive pressure on teleradiology pricing'),
    ('CGU-HOSP-13','Tier-2 Hospital CGU','Hospitals','goodwill','value_in_use',
     410000000,452000000,42000000,10.24,12.60,5.80,'watch','2026-06-30','stable','Ramp-up slower than acquisition model'),
    ('CGU-SOFT-14','Analytics Module CGU','Software','software','value_in_use',
     42000000,61000000,19000000,45.24,14.80,8.00,'reversed','2026-06-30','improving','Prior year impairment reversed on demand recovery'),
    ('CGU-LIC-15','Blood Bank License CGU','Imaging','license','fair_value_less_costs',
     36000000,38500000,2500000,6.94,12.20,2.50,'watch','2026-06-30','stable','License headroom modest — monitor renewals'),
    ('CGU-PHAR-16','e-Pharmacy CGU','Pharmacy','goodwill','value_in_use',
     175000000,148000000,-27000000,-15.43,15.20,5.00,'impaired','2026-06-30','worsening','Cash burn and margin compression — impaired')
  ) as q(code, nm, rptu, atype, vbasis, cval, rval, hrup, hpct, drate, grate, istat, tdate, tdir, nt);

  -- CAPA seed — attach to specific CGUs via cgu_code
  insert into public.goodwill_impairment_capa_actions_r3529 (
    impairment_id, organization_id, finding_category, root_cause, corrective_action,
    capa_status, accounting_treatment, owner, impairment_charge_rupees,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, v_org_id, q.fc, q.rc, q.ca,
    q.cst, q.acct, q.own, q.chg,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('CGU-PHAR-03','impairment_recognized','market_multiple_compression','recognize_impairment_charge','closed','ind_as_36_impairment','CFO Office',32000000,'2026-04-15','2026-04-10','Impairment charge booked and disclosed in FY audit'),
    ('CGU-CREL-05','trigger_event_identified','customer_churn','commission_independent_valuation','in_progress','audit_committee_review','FP and A Lead',8000000,'2026-05-20',null,'Independent valuation commissioned after churn trigger'),
    ('CGU-DIAG-09','impairment_recognized','revenue_miss','recognize_impairment_charge','closed','ind_as_36_impairment','CFO Office',24000000,'2026-06-15','2026-06-12','Impairment recognised on sustained revenue miss'),
    ('CGU-PHAR-16','impairment_recognized','integration_underperformance','recognize_impairment_charge','verification_pending','ind_as_36_impairment','Controller',27000000,'2026-07-10',null,'Charge posted — audit committee verification pending'),
    ('CGU-TECH-12','trigger_event_identified','competitive_pressure','restructure_cgu','open','board_note','BU Head Tech',5000000,'2026-07-25',null,'CGU restructuring plan drafted for board review'),
    ('CGU-HOSP-02','headroom_erosion','cost_inflation','revise_cash_flow_forecast','in_progress','internal_only','FP and A Lead',0,'2026-07-15',null,'Cash-flow model refreshed for cost inflation'),
    ('CGU-LIC-07','recoverable_value_decline','regulatory_change','update_discount_rate','open','ifrs_disclosure','Treasury',1500000,'2026-07-30',null,'Discount rate revisited for licence regulatory risk'),
    ('CGU-CREL-11','headroom_erosion','customer_churn','strengthen_monitoring','escalated','audit_committee_review','FP and A Lead',0,'2026-07-05',null,'Thin headroom escalated — quarterly monitoring instituted'),
    ('CGU-SOFT-14','reversal_assessment','revenue_miss','disclose_in_notes','closed','ind_as_36_impairment','Controller',0,'2026-07-05','2026-07-02','Prior impairment reversed — disclosed in notes')
  ) as q(code, fc, rc, ca, cst, acct, own, chg, tcd, acd, nt)
  join public.goodwill_impairment_r3529 e
    on e.organization_id = v_org_id and e.cgu_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Impairment status distribution
create or replace function public.founder_r3529_impairment_status_rollup()
returns table(impairment_status text, cgus bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.goodwill_impairment_r3529)
  select l.impairment_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.goodwill_impairment_r3529 l
  group by l.impairment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3529_impairment_status_rollup() from public, anon;
grant execute on function public.founder_r3529_impairment_status_rollup() to authenticated;

-- 2) Asset-type scorecard
create or replace function public.founder_r3529_asset_type_scorecard()
returns table(
  asset_type text,
  total_cgus bigint,
  clean bigint,
  watch bigint,
  trigger_review bigint,
  impaired bigint,
  reversed bigint,
  avg_headroom_pct numeric,
  total_carrying_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_type,
    count(*)::bigint,
    count(*) filter (where l.impairment_status = 'no_impairment')::bigint,
    count(*) filter (where l.impairment_status = 'watch')::bigint,
    count(*) filter (where l.impairment_status = 'trigger_review')::bigint,
    count(*) filter (where l.impairment_status = 'impaired')::bigint,
    count(*) filter (where l.impairment_status = 'reversed')::bigint,
    round(avg(l.headroom_pct), 2),
    coalesce(sum(l.carrying_value_rupees),0)::numeric
  from public.goodwill_impairment_r3529 l
  group by l.asset_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3529_asset_type_scorecard() from public, anon;
grant execute on function public.founder_r3529_asset_type_scorecard() to authenticated;

-- 3) Asset-type × impairment-status matrix
create or replace function public.founder_r3529_asset_status_matrix()
returns table(
  asset_type text,
  impairment_status text,
  cgus bigint,
  total_carrying_rupees numeric,
  total_headroom_rupees numeric,
  avg_headroom_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_type, l.impairment_status, count(*)::bigint,
    coalesce(sum(l.carrying_value_rupees),0)::numeric,
    coalesce(sum(l.headroom_rupees),0)::numeric,
    round(avg(l.headroom_pct), 2)
  from public.goodwill_impairment_r3529 l
  group by l.asset_type, l.impairment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3529_asset_status_matrix() from public, anon;
grant execute on function public.founder_r3529_asset_status_matrix() to authenticated;

-- 4) Monthly headroom trend
create or replace function public.founder_r3529_monthly_headroom_trend()
returns table(
  test_month date,
  cgus bigint,
  impaired bigint,
  thin_headroom bigint,
  avg_headroom_pct numeric,
  total_headroom_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.test_date)::date,
    count(*)::bigint,
    count(*) filter (where l.impairment_status = 'impaired')::bigint,
    count(*) filter (where l.headroom_pct < 10)::bigint,
    round(avg(l.headroom_pct), 2),
    coalesce(sum(l.headroom_rupees),0)::numeric
  from public.goodwill_impairment_r3529 l
  group by date_trunc('month', l.test_date)
  order by date_trunc('month', l.test_date) desc;
end;
$$;

revoke execute on function public.founder_r3529_monthly_headroom_trend() from public, anon;
grant execute on function public.founder_r3529_monthly_headroom_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3529_capa_status_board()
returns table(capa_status text, findings bigint, avg_charge_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impairment_charge_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.goodwill_impairment_capa_actions_r3529 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3529_capa_status_board() from public, anon;
grant execute on function public.founder_r3529_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3529_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_charge_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.goodwill_impairment_capa_actions_r3529)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impairment_charge_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.goodwill_impairment_capa_actions_r3529 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3529_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3529_root_cause_pareto() to authenticated;

-- 7) Impairment-impact digest (by impairment status)
create or replace function public.founder_r3529_impairment_impact_digest()
returns table(
  impairment_status text,
  cgus bigint,
  total_carrying_rupees numeric,
  total_recoverable_rupees numeric,
  total_headroom_rupees numeric,
  avg_discount_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.impairment_status, count(*)::bigint,
    coalesce(sum(l.carrying_value_rupees),0)::numeric,
    coalesce(sum(l.recoverable_value_rupees),0)::numeric,
    coalesce(sum(l.headroom_rupees),0)::numeric,
    round(avg(l.discount_rate_pct), 2)
  from public.goodwill_impairment_r3529 l
  group by l.impairment_status
  order by coalesce(sum(l.carrying_value_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3529_impairment_impact_digest() from public, anon;
grant execute on function public.founder_r3529_impairment_impact_digest() to authenticated;

-- 8) High-risk queue (impaired / trigger-review / thin-headroom / worsening)
create or replace function public.founder_r3529_high_risk_queue()
returns table(
  cgu_name text,
  cgu_code text,
  asset_type text,
  reporting_unit text,
  test_date date,
  impairment_status text,
  carrying_value_rupees numeric,
  recoverable_value_rupees numeric,
  headroom_rupees numeric,
  headroom_pct numeric,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cgu_name, l.cgu_code, l.asset_type, l.reporting_unit, l.test_date,
    l.impairment_status, l.carrying_value_rupees, l.recoverable_value_rupees,
    l.headroom_rupees, l.headroom_pct, l.trend_dir, l.notes
  from public.goodwill_impairment_r3529 l
  where l.impairment_status in ('impaired','trigger_review')
     or l.headroom_pct < 10
     or l.trend_dir = 'worsening'
  order by l.headroom_pct asc, l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3529_high_risk_queue() from public, anon;
grant execute on function public.founder_r3529_high_risk_queue() to authenticated;
