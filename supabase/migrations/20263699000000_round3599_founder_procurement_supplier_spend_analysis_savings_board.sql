-- Round 3599: Founder Procurement / Supplier Spend-Analysis & Savings Board
-- Per-supplier monthly spend snapshot — spend concentration, on-contract vs maverick spend,
-- savings realized vs target, price variance & payment terms — with spend status, trend,
-- monthly spend trend, root-cause pareto & CAPA remediation.

-- =============================================================================
-- TABLE 1: spend_analysis_r3599 — per-supplier monthly spend-analysis snapshot
-- =============================================================================
create table if not exists public.spend_analysis_r3599 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_code text not null,
  supplier_name text not null,
  category text not null,
  period_month date not null,
  spend_rupees numeric(16,2),
  po_count int,
  on_contract_pct numeric(6,2),
  maverick_spend_pct numeric(6,2),
  savings_realized_rupees numeric(16,2),
  savings_target_rupees numeric(16,2),
  price_variance_pct numeric(6,2),
  payment_terms_days int,
  spend_status text not null check (spend_status in (
    'strategic','preferred','tail','maverick_risk','single_source_risk'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spend_analysis_r3599 enable row level security;

create index if not exists idx_spend_analysis_r3599_org on public.spend_analysis_r3599(organization_id);
create index if not exists idx_spend_analysis_r3599_month on public.spend_analysis_r3599(period_month);
create index if not exists idx_spend_analysis_r3599_status on public.spend_analysis_r3599(spend_status);

-- =============================================================================
-- TABLE 2: spend_analysis_capa_actions_r3599 — CAPA / savings-improvement actions
-- =============================================================================
create table if not exists public.spend_analysis_capa_actions_r3599 (
  id uuid primary key default gen_random_uuid(),
  spend_log_id uuid not null references public.spend_analysis_r3599(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'maverick_spend_high','off_contract_purchase','price_variance_high','single_source_dependency',
    'savings_target_miss','payment_terms_unfavorable','spend_concentration_risk','supplier_performance_issue'
  )),
  root_cause text not null check (root_cause in (
    'no_negotiated_contract','urgent_unplanned_purchase','supplier_price_increase','sole_source_component',
    'poor_demand_forecasting','fragmented_buying','contract_expired','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'negotiate_framework_contract','consolidate_suppliers','introduce_second_source','renegotiate_pricing',
    'enforce_po_policy','extend_payment_terms','competitive_rfq','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  savings_impact_rupees numeric(16,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spend_analysis_capa_actions_r3599 enable row level security;

create index if not exists idx_spend_analysis_capa_r3599_log on public.spend_analysis_capa_actions_r3599(spend_log_id);
create index if not exists idx_spend_analysis_capa_r3599_status on public.spend_analysis_capa_actions_r3599(capa_status);

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

  -- 16 supplier spend-analysis rows
  insert into public.spend_analysis_r3599 (
    organization_id, supplier_code, supplier_name, category, period_month,
    spend_rupees, po_count, on_contract_pct, maverick_spend_pct,
    savings_realized_rupees, savings_target_rupees, price_variance_pct, payment_terms_days,
    spend_status, trend_dir, notes
  )
  select v_org_id, q.scode, q.sname, q.cat, q.pmonth::date,
    q.spend, q.pocnt, q.oncon, q.mav,
    q.savr, q.savt, q.pvar, q.payt,
    q.sstat, q.tdir, q.nt
  from (values
    ('SUP-SIE-01','Siemens Healthineers India','capital_equipment','2026-06-01',
     8850000,12,96.5,2.0,620000,700000,1.5,60,'strategic','improving','Imaging capex on framework contract, savings on track'),
    ('SUP-GEH-02','GE Healthcare India','spare_parts','2026-06-01',
     4200000,48,92.0,5.5,310000,350000,2.8,45,'strategic','stable','CT/MRI spares mostly on rate contract'),
    ('SUP-PHI-03','Philips India','amc_services','2026-06-01',
     3650000,22,98.0,1.0,280000,260000,-1.2,60,'strategic','improving','AMC contracts renegotiated, beating savings target'),
    ('SUP-TRV-04','Trivitron Healthcare','diagnostics_reagents','2026-06-01',
     2950000,65,88.0,8.0,180000,240000,4.5,30,'preferred','stable','Reagent spend with some off-contract urgent buys'),
    ('SUP-BPL-05','BPL Medical Technologies','spare_parts','2026-06-01',
     1850000,40,85.0,12.0,95000,150000,6.2,45,'preferred','worsening','Patient-monitor spares, maverick spend creeping up'),
    ('SUP-MND-06','Mindray India','capital_equipment','2026-06-01',
     2450000,9,94.0,4.0,160000,180000,2.1,60,'preferred','stable','Ventilator and monitor capex on contract'),
    ('SUP-NHK-07','Nihon Kohden India','spare_parts','2026-06-01',
     1250000,28,70.0,26.0,40000,120000,9.8,30,'maverick_risk','worsening','High maverick spend, no framework contract in place'),
    ('SUP-SKN-08','Skanray Technologies','projects_capex','2026-06-01',
     3100000,6,91.0,6.0,210000,230000,1.8,90,'strategic','improving','Turnkey project supply on negotiated contract'),
    ('SUP-TRA-09','Transasia Bio-Medicals','diagnostics_reagents','2026-06-01',
     2200000,52,82.0,15.0,120000,200000,5.5,30,'preferred','worsening','Lab reagents, fragmented buying across sites'),
    ('SUP-ROC-10','Roche Diagnostics India','diagnostics_reagents','2026-06-01',
     5400000,30,97.0,2.0,380000,400000,0.8,45,'single_source_risk','stable','Sole-source immunoassay reagents, supply risk'),
    ('SUP-AGP-11','Agappe Diagnostics','diagnostics_reagents','2026-06-01',
     680000,34,60.0,34.0,15000,60000,11.5,30,'maverick_risk','worsening','Tail supplier, mostly off-contract spot buys'),
    ('SUP-POL-12','Poly Medicure','consumables','2026-06-01',
     920000,70,78.0,18.0,55000,90000,3.9,45,'tail','stable','Disposables with moderate off-contract share'),
    ('SUP-HMD-13','Hindustan Syringes','consumables','2026-06-01',
     540000,44,74.0,20.0,22000,55000,4.2,30,'tail','stable','Syringes and needles, tail spend'),
    ('SUP-BLU-14','Blue Star Facilities','facility_hvac','2026-06-01',
     1150000,18,89.0,7.0,70000,85000,2.6,60,'preferred','stable','HVAC and facility AMC for equipment rooms'),
    ('SUP-WGE-15','Wipro GE','rentals','2026-06-01',
     1620000,14,95.0,3.0,90000,95000,1.1,60,'strategic','improving','Equipment rentals on framework, savings near target'),
    ('SUP-CAL-16','National Calibration Labs','calibration_services','2026-06-01',
     430000,60,55.0,40.0,8000,45000,13.2,30,'maverick_risk','worsening','Calibration services heavily off-contract, single small vendor')
  ) as q(scode, sname, cat, pmonth, spend, pocnt, oncon, mav, savr, savt, pvar, payt, sstat, tdir, nt);

  -- CAPA seed — attach to specific suppliers via supplier_code
  insert into public.spend_analysis_capa_actions_r3599 (
    spend_log_id, finding_category, root_cause, corrective_action,
    capa_status, savings_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SUP-NHK-07','maverick_spend_high','no_negotiated_contract','negotiate_framework_contract','in_progress',80000,'Procurement Lead','2026-08-15',null,'Draft framework contract with Nihon Kohden to cut maverick spend'),
    ('SUP-AGP-11','off_contract_purchase','fragmented_buying','consolidate_suppliers','open',45000,'Category Manager','2026-08-30',null,'Consolidate Agappe spot buys under a rate contract'),
    ('SUP-ROC-10','single_source_dependency','sole_source_component','introduce_second_source','escalated',120000,'Head of Procurement','2026-09-15',null,'Qualify a second immunoassay reagent supplier to de-risk'),
    ('SUP-BPL-05','price_variance_high','supplier_price_increase','renegotiate_pricing','verification_pending',55000,'Procurement Lead','2026-08-10',null,'Renegotiate BPL spare pricing after 6 percent variance'),
    ('SUP-TRA-09','spend_concentration_risk','poor_demand_forecasting','enforce_po_policy','open',80000,'Category Manager','2026-08-20',null,'Enforce PO policy and improve reagent demand forecasting'),
    ('SUP-CAL-16','single_source_dependency','sole_source_component','competitive_rfq','open',37000,'Quality Manager','2026-08-25',null,'Run competitive RFQ for calibration services'),
    ('SUP-TRV-04','savings_target_miss','contract_expired','negotiate_framework_contract','closed',60000,'Procurement Lead','2026-07-20','2026-07-18','Renewed reagent framework, savings target restored'),
    ('SUP-POL-12','off_contract_purchase','urgent_unplanned_purchase','enforce_po_policy','in_progress',35000,'Category Manager','2026-08-05',null,'Reduce urgent off-contract disposable buys'),
    ('SUP-BLU-14','payment_terms_unfavorable','no_negotiated_contract','extend_payment_terms','overdue',15000,'Finance Controller','2026-07-10',null,'Extend facility AMC payment terms to 60 days, vendor pushback')
  ) as q(scode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.spend_analysis_r3599 e
    on e.organization_id = v_org_id and e.supplier_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Spend-status distribution
create or replace function public.founder_r3599_spend_status_rollup()
returns table(spend_status text, suppliers bigint, total_spend_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spend_analysis_r3599)
  select l.spend_status, count(*)::bigint,
         coalesce(sum(l.spend_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.spend_analysis_r3599 l
  group by l.spend_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3599_spend_status_rollup() from public, anon;
grant execute on function public.founder_r3599_spend_status_rollup() to authenticated;

-- 2) Category spend scorecard
create or replace function public.founder_r3599_category_scorecard()
returns table(
  category text,
  suppliers bigint,
  total_spend_rupees numeric,
  avg_on_contract_pct numeric,
  avg_maverick_pct numeric,
  savings_realized_rupees numeric,
  savings_target_rupees numeric,
  savings_attainment_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category,
    count(*)::bigint,
    coalesce(sum(l.spend_rupees),0)::numeric,
    round(avg(l.on_contract_pct), 1),
    round(avg(l.maverick_spend_pct), 1),
    coalesce(sum(l.savings_realized_rupees),0)::numeric,
    coalesce(sum(l.savings_target_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.savings_realized_rupees),0) / nullif(sum(l.savings_target_rupees),0), 1)
  from public.spend_analysis_r3599 l
  group by l.category
  order by coalesce(sum(l.spend_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3599_category_scorecard() from public, anon;
grant execute on function public.founder_r3599_category_scorecard() to authenticated;

-- 3) Category × spend-status matrix
create or replace function public.founder_r3599_category_status_matrix()
returns table(category text, spend_status text, suppliers bigint, total_spend_rupees numeric, avg_price_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category, l.spend_status, count(*)::bigint,
    coalesce(sum(l.spend_rupees),0)::numeric,
    round(avg(l.price_variance_pct), 2)
  from public.spend_analysis_r3599 l
  group by l.category, l.spend_status
  order by coalesce(sum(l.spend_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3599_category_status_matrix() from public, anon;
grant execute on function public.founder_r3599_category_status_matrix() to authenticated;

-- 4) Monthly spend trend
create or replace function public.founder_r3599_monthly_spend_trend()
returns table(period_month date, suppliers bigint, total_spend_rupees numeric, savings_realized_rupees numeric, avg_on_contract_pct numeric, avg_maverick_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.spend_rupees),0)::numeric,
    coalesce(sum(l.savings_realized_rupees),0)::numeric,
    round(avg(l.on_contract_pct), 1),
    round(avg(l.maverick_spend_pct), 1)
  from public.spend_analysis_r3599 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3599_monthly_spend_trend() from public, anon;
grant execute on function public.founder_r3599_monthly_spend_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3599_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.savings_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.spend_analysis_capa_actions_r3599 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3599_capa_status_board() from public, anon;
grant execute on function public.founder_r3599_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3599_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spend_analysis_capa_actions_r3599)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.savings_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.spend_analysis_capa_actions_r3599 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3599_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3599_root_cause_pareto() to authenticated;

-- 7) Savings-impact digest (by finding category)
create or replace function public.founder_r3599_savings_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.savings_impact_rupees),0)::numeric
  from public.spend_analysis_capa_actions_r3599 c
  group by c.finding_category
  order by coalesce(sum(c.savings_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3599_savings_impact_digest() from public, anon;
grant execute on function public.founder_r3599_savings_impact_digest() to authenticated;

-- 8) High-risk spend queue (maverick_risk / single_source_risk)
create or replace function public.founder_r3599_high_risk_queue()
returns table(
  supplier_name text,
  supplier_code text,
  category text,
  period_month date,
  spend_rupees numeric,
  spend_status text,
  maverick_spend_pct numeric,
  on_contract_pct numeric,
  price_variance_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_name, l.supplier_code, l.category, l.period_month,
    l.spend_rupees, l.spend_status, l.maverick_spend_pct, l.on_contract_pct, l.price_variance_pct, l.notes
  from public.spend_analysis_r3599 l
  where l.spend_status in ('maverick_risk','single_source_risk')
     or l.maverick_spend_pct >= 15
     or l.on_contract_pct < 75
     or l.price_variance_pct >= 6
     or l.trend_dir = 'worsening'
     or l.savings_realized_rupees < l.savings_target_rupees * 0.5
  order by l.spend_rupees desc, l.supplier_name;
end;
$$;

revoke execute on function public.founder_r3599_high_risk_queue() from public, anon;
grant execute on function public.founder_r3599_high_risk_queue() to authenticated;
