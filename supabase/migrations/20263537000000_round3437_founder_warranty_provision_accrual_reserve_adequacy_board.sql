-- Round 3437: Founder Warranty-Provision Accrual / Reserve-Adequacy Board
-- Warranty provisioning — accrual vs actual claims, reserve adequacy per product line ×
-- warranty type × utilization × cost trend × monthly MTM × CAPA closure

-- =============================================================================
-- TABLE 1: warranty_provision_reserve_r3437 — per product-line warranty provision balances
-- =============================================================================
create table if not exists public.warranty_provision_reserve_r3437 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  product_line text not null,
  provision_ref text not null,
  warranty_type text not null check (warranty_type in (
    'standard','extended','amc_bundled','goodwill'
  )),
  units_under_warranty int not null,
  provision_rate_pct numeric(6,2),
  provision_balance_rupees numeric(14,2),
  claims_paid_ytd_rupees numeric(14,2),
  claims_incurred_rupees numeric(14,2),
  utilization_pct numeric(6,2),
  reserve_adequacy text not null check (reserve_adequacy in (
    'adequate','marginal','under_reserved','over_reserved'
  )),
  period_month date not null,
  cost_trend text not null check (cost_trend in (
    'rising','stable','falling'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.warranty_provision_reserve_r3437 enable row level security;

create index if not exists idx_warranty_provision_reserve_r3437_org on public.warranty_provision_reserve_r3437(organization_id);
create index if not exists idx_warranty_provision_reserve_r3437_month on public.warranty_provision_reserve_r3437(period_month);
create index if not exists idx_warranty_provision_reserve_r3437_adeq on public.warranty_provision_reserve_r3437(reserve_adequacy);

-- =============================================================================
-- TABLE 2: warranty_provision_reserve_capa_actions_r3437 — CAPA & true-up actions
-- =============================================================================
create table if not exists public.warranty_provision_reserve_capa_actions_r3437 (
  id uuid primary key default gen_random_uuid(),
  provision_log_id uuid not null references public.warranty_provision_reserve_r3437(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'under_reserved_provision','provision_rate_too_low','claims_spike','utilization_breach',
    'cost_trend_rising','reserve_release_needed','amc_bundle_mispricing','goodwill_claims_excess',
    'accrual_true_up_required','forecast_variance'
  )),
  root_cause text not null check (root_cause in (
    'claims_frequency_higher_than_expected','component_failure_rate_up','provision_rate_understated',
    'extended_warranty_underpriced','spare_parts_cost_inflation','labor_cost_inflation',
    'goodwill_policy_too_generous','actuarial_model_stale','pending_investigation','one_time_batch_defect'
  )),
  corrective_action text not null check (corrective_action in (
    'increase_provision_rate','top_up_reserve','release_excess_reserve','reprice_extended_warranty',
    'reprice_amc_bundle','tighten_goodwill_policy','renegotiate_supplier_terms','update_actuarial_model',
    'engineering_root_cause_fix','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  provision_impact_class text not null check (provision_impact_class in (
    'reserve_shortfall','reserve_surplus','pnl_charge','pnl_release','no_impact','forecast_only'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  financial_impact_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.warranty_provision_reserve_capa_actions_r3437 enable row level security;

create index if not exists idx_warranty_provision_reserve_capa_r3437_log on public.warranty_provision_reserve_capa_actions_r3437(provision_log_id);
create index if not exists idx_warranty_provision_reserve_capa_r3437_status on public.warranty_provision_reserve_capa_actions_r3437(capa_status);

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

  -- 16 provision-balance rows
  insert into public.warranty_provision_reserve_r3437 (
    organization_id, product_line, provision_ref, warranty_type, units_under_warranty,
    provision_rate_pct, provision_balance_rupees, claims_paid_ytd_rupees, claims_incurred_rupees,
    utilization_pct, reserve_adequacy, period_month, cost_trend, notes
  )
  select v_org_id, q.pl, q.pref, q.wt, q.units::int,
    q.prate::numeric, q.pbal::numeric, q.cpaid::numeric, q.cinc::numeric,
    q.util::numeric, q.adeq, q.pmon::date, q.trend, q.nt
  from (values
    ('Hemodialysis Machines','WPR-DIAL-STD-01','standard',420,3.5,1850000,640000,720000,38.9,'adequate','2026-07-01','stable','Dialysis standard warranty pool well funded against claims'),
    ('Hemodialysis Machines','WPR-DIAL-EXT-02','extended',180,5.2,1420000,880000,1310000,92.3,'under_reserved','2026-07-01','rising','Extended warranty claims spiking on membrane pumps — reserve short'),
    ('Ventilators','WPR-VENT-STD-03','standard',260,4.0,2100000,540000,610000,29.0,'adequate','2026-07-01','stable','Ventilator standard pool healthy post-demand normalisation'),
    ('Ventilators','WPR-VENT-AMC-04','amc_bundled',140,6.5,980000,910000,1180000,120.4,'under_reserved','2026-07-01','rising','AMC-bundled ventilator warranty underpriced, blower failures up'),
    ('Patient Monitors','WPR-MON-STD-05','standard',680,2.8,1560000,420000,470000,30.1,'adequate','2026-07-01','falling','Monitor claims trending down after SMPS redesign'),
    ('Patient Monitors','WPR-MON-EXT-06','extended',210,4.5,720000,690000,760000,105.6,'under_reserved','2026-06-01','rising','Extended monitor warranty running hot on touchscreen failures'),
    ('Infusion Pumps','WPR-INF-STD-07','standard',540,3.0,880000,210000,240000,27.3,'adequate','2026-06-01','stable','Infusion pump standard pool adequate'),
    ('Infusion Pumps','WPR-INF-GDW-08','goodwill',0,0.0,150000,180000,205000,136.7,'under_reserved','2026-06-01','rising','Goodwill replacements exceeding reserve on legacy pumps'),
    ('C-Arm Imaging','WPR-CARM-EXT-09','extended',60,7.5,2650000,540000,620000,23.4,'over_reserved','2026-06-01','falling','C-arm extended reserve over-provisioned, release candidate'),
    ('Ultrasound','WPR-US-STD-10','standard',320,3.2,1180000,360000,410000,34.7,'adequate','2026-07-01','stable','Ultrasound probe claims stable and within reserve'),
    ('Ultrasound','WPR-US-AMC-11','amc_bundled',95,5.8,540000,470000,560000,103.7,'marginal','2026-07-01','rising','AMC ultrasound probe reserve marginal, watch cost trend'),
    ('Autoclaves / CSSD','WPR-ACLV-STD-12','standard',150,4.2,690000,150000,175000,25.4,'adequate','2026-06-01','stable','CSSD autoclave warranty pool adequate'),
    ('Defibrillators','WPR-DEFIB-STD-13','standard',240,3.6,820000,260000,300000,36.6,'marginal','2026-07-01','stable','Defib battery claims edging up, reserve marginal'),
    ('Anesthesia Workstations','WPR-ANES-AMC-14','amc_bundled',110,6.0,1340000,380000,430000,32.1,'adequate','2026-06-01','stable','Anesthesia AMC-bundled warranty adequately reserved'),
    ('Anesthesia Workstations','WPR-ANES-GDW-15','goodwill',0,0.0,90000,95000,140000,155.6,'under_reserved','2026-05-01','rising','Goodwill vaporizer replacements over reserve'),
    ('Surgical Lights / OT','WPR-OTL-EXT-16','extended',130,4.8,1120000,190000,220000,19.6,'over_reserved','2026-05-01','falling','OT LED light failures low, reserve can be released')
  ) as q(pl, pref, wt, units, prate, pbal, cpaid, cinc, util, adeq, pmon, trend, nt);

  -- CAPA seed — attach to specific provision lines via provision_ref
  insert into public.warranty_provision_reserve_capa_actions_r3437 (
    provision_log_id, finding_category, root_cause, corrective_action,
    capa_status, provision_impact_class, owner, target_closure_date, actual_closure_date,
    financial_impact_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.pic, q.own, q.tcd::date, q.acd::date,
    q.fin::numeric, q.nt
  from (values
    ('WPR-DIAL-EXT-02','under_reserved_provision','extended_warranty_underpriced','reprice_extended_warranty','in_progress','reserve_shortfall','Priya Nair (Finance)','2026-08-15',null,620000.00,'Top-up reserve and reprice dialysis extended warranty for FY27'),
    ('WPR-VENT-AMC-04','provision_rate_too_low','component_failure_rate_up','increase_provision_rate','open','reserve_shortfall','R. Krishnan (Service Head)','2026-08-20',null,540000.00,'Blower failure rate up 40 percent, raise AMC provision rate to 8.5 percent'),
    ('WPR-MON-EXT-06','claims_spike','component_failure_rate_up','engineering_root_cause_fix','escalated','pnl_charge','Anil Deshmukh (QA)','2026-08-05',null,310000.00,'Touchscreen supplier defect batch, escalate to OEM for warranty credit'),
    ('WPR-INF-GDW-08','goodwill_claims_excess','goodwill_policy_too_generous','tighten_goodwill_policy','open','pnl_charge','Meera Iyer (Ops)','2026-08-25',null,95000.00,'Legacy pump goodwill policy too generous, cap replacement value'),
    ('WPR-CARM-EXT-09','reserve_release_needed','actuarial_model_stale','release_excess_reserve','verification_pending','reserve_surplus','Priya Nair (Finance)','2026-08-10',null,850000.00,'C-arm reserve over-provisioned, release after audit sign-off'),
    ('WPR-US-AMC-11','cost_trend_rising','spare_parts_cost_inflation','renegotiate_supplier_terms','in_progress','reserve_shortfall','R. Krishnan (Service Head)','2026-08-18',null,140000.00,'Probe cost inflation, renegotiate spares and watch reserve adequacy'),
    ('WPR-ANES-GDW-15','goodwill_claims_excess','goodwill_policy_too_generous','tighten_goodwill_policy','overdue','reserve_shortfall','Meera Iyer (Ops)','2026-07-15',null,90000.00,'Vaporizer goodwill overspend, action now past due date'),
    ('WPR-OTL-EXT-16','reserve_release_needed','actuarial_model_stale','release_excess_reserve','closed','reserve_surplus','Priya Nair (Finance)','2026-07-10','2026-07-08',430000.00,'OT light reserve released after LED reliability confirmed')
  ) as q(pref, fc, rc, ca, cst, pic, own, tcd, acd, fin, nt)
  join public.warranty_provision_reserve_r3437 e
    on e.organization_id = v_org_id and e.provision_ref = q.pref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Reserve-adequacy distribution
create or replace function public.founder_r3437_reserve_adequacy_rollup()
returns table(reserve_adequacy text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.warranty_provision_reserve_r3437)
  select l.reserve_adequacy, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.warranty_provision_reserve_r3437 l
  group by l.reserve_adequacy
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3437_reserve_adequacy_rollup() from public, anon;
grant execute on function public.founder_r3437_reserve_adequacy_rollup() to authenticated;

-- 2) Product-line provision scorecard
create or replace function public.founder_r3437_product_line_scorecard()
returns table(
  product_line text,
  total_lines bigint,
  adequate bigint,
  marginal bigint,
  under_reserved bigint,
  over_reserved bigint,
  units_under_warranty bigint,
  provision_balance_rupees numeric,
  claims_incurred_rupees numeric,
  avg_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_line,
    count(*)::bigint,
    count(*) filter (where l.reserve_adequacy = 'adequate')::bigint,
    count(*) filter (where l.reserve_adequacy = 'marginal')::bigint,
    count(*) filter (where l.reserve_adequacy = 'under_reserved')::bigint,
    count(*) filter (where l.reserve_adequacy = 'over_reserved')::bigint,
    coalesce(sum(l.units_under_warranty),0)::bigint,
    coalesce(sum(l.provision_balance_rupees),0)::numeric,
    coalesce(sum(l.claims_incurred_rupees),0)::numeric,
    round(avg(l.utilization_pct), 1)
  from public.warranty_provision_reserve_r3437 l
  group by l.product_line
  order by count(*) filter (where l.reserve_adequacy = 'under_reserved') desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3437_product_line_scorecard() from public, anon;
grant execute on function public.founder_r3437_product_line_scorecard() to authenticated;

-- 3) Warranty-type × reserve-adequacy matrix
create or replace function public.founder_r3437_warranty_type_adequacy_matrix()
returns table(
  warranty_type text,
  reserve_adequacy text,
  lines bigint,
  provision_balance_rupees numeric,
  claims_incurred_rupees numeric,
  avg_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.warranty_type, l.reserve_adequacy, count(*)::bigint,
    coalesce(sum(l.provision_balance_rupees),0)::numeric,
    coalesce(sum(l.claims_incurred_rupees),0)::numeric,
    round(avg(l.utilization_pct), 1)
  from public.warranty_provision_reserve_r3437 l
  group by l.warranty_type, l.reserve_adequacy
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3437_warranty_type_adequacy_matrix() from public, anon;
grant execute on function public.founder_r3437_warranty_type_adequacy_matrix() to authenticated;

-- 4) Monthly provision / MTM trend
create or replace function public.founder_r3437_monthly_provision_trend()
returns table(
  period_month date,
  lines bigint,
  provision_balance_rupees numeric,
  claims_paid_ytd_rupees numeric,
  claims_incurred_rupees numeric,
  avg_utilization_pct numeric
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
    coalesce(sum(l.provision_balance_rupees),0)::numeric,
    coalesce(sum(l.claims_paid_ytd_rupees),0)::numeric,
    coalesce(sum(l.claims_incurred_rupees),0)::numeric,
    round(avg(l.utilization_pct), 1)
  from public.warranty_provision_reserve_r3437 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3437_monthly_provision_trend() from public, anon;
grant execute on function public.founder_r3437_monthly_provision_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3437_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.financial_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.warranty_provision_reserve_capa_actions_r3437 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3437_capa_status_board() from public, anon;
grant execute on function public.founder_r3437_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3437_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.warranty_provision_reserve_capa_actions_r3437)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.warranty_provision_reserve_capa_actions_r3437 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3437_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3437_root_cause_pareto() to authenticated;

-- 7) Financial-impact digest
create or replace function public.founder_r3437_financial_impact_digest()
returns table(provision_impact_class text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.provision_impact_class, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric
  from public.warranty_provision_reserve_capa_actions_r3437 c
  group by c.provision_impact_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3437_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3437_financial_impact_digest() to authenticated;

-- 8) High-risk queue (under-reserved / marginal / rising cost)
create or replace function public.founder_r3437_high_risk_queue()
returns table(
  product_line text,
  provision_ref text,
  warranty_type text,
  period_month date,
  reserve_adequacy text,
  provision_balance_rupees numeric,
  claims_incurred_rupees numeric,
  utilization_pct numeric,
  cost_trend text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_line, l.provision_ref, l.warranty_type, l.period_month,
    l.reserve_adequacy, l.provision_balance_rupees, l.claims_incurred_rupees,
    l.utilization_pct, l.cost_trend, l.notes
  from public.warranty_provision_reserve_r3437 l
  where l.reserve_adequacy in ('under_reserved','marginal')
     or l.cost_trend = 'rising'
     or l.utilization_pct >= 100
  order by l.utilization_pct desc nulls last, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3437_high_risk_queue() from public, anon;
grant execute on function public.founder_r3437_high_risk_queue() to authenticated;
