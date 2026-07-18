-- Round 3237: Founder Pricing-Experiment & Discount-Guardrail Outcome Board
-- Pricing board — experiment × segment × control/test price × discount × take-rate delta × revenue delta × margin impact × guardrail × decision × CAPA

-- =============================================================================
-- TABLE 1: pricing_experiment_r3237 — pricing experiment outcome log
-- =============================================================================
create table if not exists public.pricing_experiment_r3237 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  experiment_code text not null,
  experiment_name text not null,
  customer_segment text not null check (customer_segment in (
    'large_private_chain','mid_size_private','government_institute','trust_charitable',
    'specialty_pediatric','specialty_oncology','tier2_city_hospital','diagnostic_lab_chain'
  )),
  service_line text not null check (service_line in (
    'amc_contract','cmc_contract','on_demand_repair','installation_commissioning',
    'calibration_service','spare_parts','preventive_maintenance','equipment_rental'
  )),
  experiment_start_date date not null,
  experiment_end_date date,
  control_price_rupees numeric(12,2) not null,
  test_price_rupees numeric(12,2) not null,
  discount_pct numeric(5,2) not null,
  control_take_rate_pct numeric(5,2),
  test_take_rate_pct numeric(5,2),
  take_rate_delta_pct numeric(6,2),
  revenue_delta_rupees numeric(12,2),
  margin_impact_pct numeric(6,2),
  guardrail_breached boolean not null default false,
  guardrail_type text check (guardrail_type in (
    'min_margin_floor','max_discount_cap','price_integrity_band',
    'segment_parity','ltv_cac_ratio','channel_conflict','none'
  )),
  decision text not null check (decision in (
    'rollout','rollback','iterate','extend_test','pause','segment_rollout'
  )),
  experiment_verdict text not null check (experiment_verdict in (
    'win','loss','flat','inconclusive','guardrail_violation','pending_analysis'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pricing_experiment_r3237 enable row level security;

create index if not exists idx_pricing_exp_r3237_org on public.pricing_experiment_r3237(organization_id);
create index if not exists idx_pricing_exp_r3237_start on public.pricing_experiment_r3237(experiment_start_date);
create index if not exists idx_pricing_exp_r3237_verdict on public.pricing_experiment_r3237(experiment_verdict);

-- =============================================================================
-- TABLE 2: pricing_experiment_capa_actions_r3237 — CAPA & guardrail actions
-- =============================================================================
create table if not exists public.pricing_experiment_capa_actions_r3237 (
  id uuid primary key default gen_random_uuid(),
  experiment_id uuid not null references public.pricing_experiment_r3237(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'margin_erosion','guardrail_breach','discount_stacking','take_rate_miss',
    'cannibalization','price_integrity_leak','measurement_gap','segment_mispricing'
  )),
  root_cause text not null check (root_cause in (
    'discount_cap_not_enforced','segment_misclassification','competitor_price_war',
    'sales_override_abuse','weak_experiment_design','insufficient_sample_size',
    'cost_model_stale','channel_conflict','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'enforce_discount_cap_in_crm','retrain_sales_on_guardrails','rebuild_cost_model',
    'rerun_with_larger_sample','rollback_test_price','tighten_approval_workflow',
    'segment_repricing','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'board_reportable','investor_covenant','audit_committee_flag',
    'revenue_recognition_risk','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pricing_experiment_capa_actions_r3237 enable row level security;

create index if not exists idx_pricing_capa_r3237_exp on public.pricing_experiment_capa_actions_r3237(experiment_id);
create index if not exists idx_pricing_capa_r3237_status on public.pricing_experiment_capa_actions_r3237(capa_status);

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

  -- 13 pricing experiment rows
  insert into public.pricing_experiment_r3237 (
    organization_id, hospital_name, experiment_code, experiment_name,
    customer_segment, service_line, experiment_start_date, experiment_end_date,
    control_price_rupees, test_price_rupees, discount_pct,
    control_take_rate_pct, test_take_rate_pct, take_rate_delta_pct,
    revenue_delta_rupees, margin_impact_pct,
    guardrail_breached, guardrail_type, decision, experiment_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.nm,
    q.seg, q.sl, q.sd::date, q.ed::date,
    q.cp, q.tp, q.disc,
    q.ctr, q.ttr, q.trd,
    q.rev, q.mi,
    q.gb, q.gt, q.dcn, q.vd, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','EXP-3237-001','AMC festive 10pct discount','large_private_chain','amc_contract','2026-06-01','2026-06-30',
     180000.00,162000.00,10.00,22.00,31.00,9.00,412000.00,-2.10,false,'none','rollout','win','Take-rate lift outweighed margin dip — rolling out chain-wide'),
    ('Apollo Hyderabad Jubilee Hills','EXP-3237-002','Spare parts bundle 18pct','large_private_chain','spare_parts','2026-06-05','2026-07-05',
     45000.00,36900.00,18.00,30.00,34.00,4.00,61000.00,-6.40,true,'min_margin_floor','rollback','guardrail_violation','Margin floor 12pct breached at 18pct discount'),
    ('Fortis Bannerghatta Bengaluru','EXP-3237-003','CMC annual prepay 12pct','large_private_chain','cmc_contract','2026-05-20','2026-06-20',
     320000.00,281600.00,12.00,18.00,27.00,9.00,690000.00,-1.80,false,'none','rollout','win','Prepay reduced collection risk alongside take-rate lift'),
    ('Fortis Bannerghatta Bengaluru','EXP-3237-004','On-demand repair 10pct parity','large_private_chain','on_demand_repair','2026-06-10','2026-07-10',
     8500.00,7650.00,10.00,41.00,43.00,2.00,28000.00,-3.20,false,'none','iterate','flat','Lift within noise band — iterate with 15pct variant'),
    ('Manipal Whitefield Bengaluru','EXP-3237-005','Calibration multi-asset 15pct','mid_size_private','calibration_service','2026-06-01','2026-06-28',
     25000.00,21250.00,15.00,26.00,38.00,12.00,145000.00,-2.90,false,'none','rollout','win','Multi-asset bundling drove strong attach'),
    ('Manipal Whitefield Bengaluru','EXP-3237-006','PM visit unbundle test','mid_size_private','preventive_maintenance','2026-06-15','2026-07-15',
     12000.00,10800.00,10.00,33.00,30.00,-3.00,-54000.00,-4.10,false,'none','rollback','loss','Unbundled PM cannibalized AMC renewals'),
    ('AIIMS New Delhi Ansari Nagar','EXP-3237-007','Govt tender rate-card 8pct','government_institute','installation_commissioning','2026-05-25','2026-06-25',
     95000.00,87400.00,8.00,15.00,19.00,4.00,132000.00,-1.20,false,'none','segment_rollout','win','Rollout limited to government segment rate card'),
    ('AIIMS New Delhi Ansari Nagar','EXP-3237-008','Rental long-term 25pct','government_institute','equipment_rental','2026-06-08','2026-07-08',
     60000.00,45000.00,25.00,20.00,29.00,9.00,96000.00,-9.80,true,'max_discount_cap','rollback','guardrail_violation','Discount cap 20pct exceeded via sales override'),
    ('KIMS Secunderabad','EXP-3237-009','AMC tier2 intro 14pct','tier2_city_hospital','amc_contract','2026-06-03','2026-07-03',
     150000.00,129000.00,14.00,12.00,24.00,12.00,258000.00,-2.60,false,'none','rollout','win','Tier2 penetration doubled take-rate'),
    ('Care Hospitals Banjara Hills','EXP-3237-010','Spare parts channel parity','mid_size_private','spare_parts','2026-06-12','2026-07-12',
     38000.00,34200.00,10.00,28.00,29.00,1.00,9000.00,-3.50,true,'price_integrity_band','pause','guardrail_violation','Distributor undercut breached price integrity band'),
    ('Yashoda Somajiguda Hyderabad','EXP-3237-011','CMC oncology suite 12pct','specialty_oncology','cmc_contract','2026-06-06','2026-07-06',
     410000.00,360800.00,12.00,16.00,21.00,5.00,380000.00,-2.00,false,'none','extend_test','inconclusive','Small oncology sample — extending four weeks'),
    ('St John''s Bengaluru','EXP-3237-012','Trust hospital AMC 20pct','trust_charitable','amc_contract','2026-06-01','2026-06-30',
     140000.00,112000.00,20.00,14.00,26.00,12.00,168000.00,-7.90,true,'ltv_cac_ratio','iterate','loss','LTV to CAC dipped below 3.0 guardrail'),
    ('Rainbow Children''s Hyderabad','EXP-3237-013','Pediatric calibration 12pct','specialty_pediatric','calibration_service','2026-06-18','2026-07-18',
     22000.00,19360.00,12.00,24.00,null,null,null,null,false,'none','extend_test','pending_analysis','Test window still open — readout due 2026-07-20')
  ) as q(hosp, code, nm, seg, sl, sd, ed, cp, tp, disc, ctr, ttr, trd, rev, mi, gb, gt, dcn, vd, nt);

  -- 6 CAPA rows — attach to specific experiments by code
  insert into public.pricing_experiment_capa_actions_r3237 (
    experiment_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('EXP-3237-002','margin_erosion','discount_cap_not_enforced','enforce_discount_cap_in_crm','2026-07-10',null,'in_progress','audit_committee_flag',85000.00,'CRM discount-cap rule in deployment'),
    ('EXP-3237-008','guardrail_breach','sales_override_abuse','tighten_approval_workflow','2026-07-08','2026-07-05','closed','board_reportable',120000.00,'Two-level approval now mandatory above 15pct'),
    ('EXP-3237-010','price_integrity_leak','channel_conflict','segment_repricing','2026-07-20',null,'open','internal_only',60000.00,'Distributor MAP policy being drafted'),
    ('EXP-3237-006','cannibalization','weak_experiment_design','rerun_with_larger_sample','2026-07-25',null,'verification_pending','none',35000.00,'Holdout group added for AMC renewal cohort'),
    ('EXP-3237-012','margin_erosion','cost_model_stale','rebuild_cost_model','2026-06-28',null,'overdue','revenue_recognition_risk',95000.00,'Field-visit cost inputs three quarters old'),
    ('EXP-3237-011','measurement_gap','insufficient_sample_size','rerun_with_larger_sample','2026-07-30',null,'escalated','investor_covenant',40000.00,'Oncology segment too thin — pooling with cardiac')
  ) as q(code_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.pricing_experiment_r3237 e
    on e.organization_id = v_org_id and e.experiment_code = q.code_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Experiment verdict distribution
create or replace function public.founder_r3237_verdict_rollup()
returns table(experiment_verdict text, experiments bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pricing_experiment_r3237)
  select l.experiment_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pricing_experiment_r3237 l
  group by l.experiment_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3237_verdict_rollup() from public, anon;
grant execute on function public.founder_r3237_verdict_rollup() to authenticated;

-- 2) Hospital-level pricing scorecard
create or replace function public.founder_r3237_hospital_scorecard()
returns table(
  hospital_name text,
  total_experiments bigint,
  wins bigint,
  losses bigint,
  guardrail_breaches bigint,
  rollouts bigint,
  rollbacks bigint,
  avg_discount_pct numeric,
  win_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.experiment_verdict = 'win')::bigint,
    count(*) filter (where l.experiment_verdict = 'loss')::bigint,
    count(*) filter (where l.guardrail_breached)::bigint,
    count(*) filter (where l.decision in ('rollout','segment_rollout'))::bigint,
    count(*) filter (where l.decision = 'rollback')::bigint,
    round(avg(l.discount_pct), 2),
    round(100.0 * count(*) filter (where l.experiment_verdict = 'win')::numeric / nullif(count(*),0), 1)
  from public.pricing_experiment_r3237 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3237_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3237_hospital_scorecard() to authenticated;

-- 3) Segment × service-line matrix
create or replace function public.founder_r3237_segment_service_matrix()
returns table(customer_segment text, service_line text, experiments bigint, wins bigint, avg_discount_pct numeric, total_revenue_delta_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment, l.service_line, count(*)::bigint,
    count(*) filter (where l.experiment_verdict = 'win')::bigint,
    round(avg(l.discount_pct), 2),
    coalesce(sum(l.revenue_delta_rupees),0)::numeric
  from public.pricing_experiment_r3237 l
  group by l.customer_segment, l.service_line
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3237_segment_service_matrix() from public, anon;
grant execute on function public.founder_r3237_segment_service_matrix() to authenticated;

-- 4) Daily start-date trend
create or replace function public.founder_r3237_daily_trend()
returns table(experiment_start_date date, experiments bigint, wins bigint, guardrail_breaches bigint, avg_margin_impact_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.experiment_start_date, count(*)::bigint,
    count(*) filter (where l.experiment_verdict = 'win')::bigint,
    count(*) filter (where l.guardrail_breached)::bigint,
    round(avg(l.margin_impact_pct), 2)
  from public.pricing_experiment_r3237 l
  group by l.experiment_start_date
  order by l.experiment_start_date desc;
end;
$$;

revoke execute on function public.founder_r3237_daily_trend() from public, anon;
grant execute on function public.founder_r3237_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3237_capa_status_board()
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
  from public.pricing_experiment_capa_actions_r3237 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3237_capa_status_board() from public, anon;
grant execute on function public.founder_r3237_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3237_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pricing_experiment_capa_actions_r3237)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pricing_experiment_capa_actions_r3237 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3237_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3237_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3237_regulatory_impact_digest()
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
  from public.pricing_experiment_capa_actions_r3237 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3237_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3237_regulatory_impact_digest() to authenticated;

-- 8) High-risk experiment queue
create or replace function public.founder_r3237_high_risk_queue()
returns table(
  hospital_name text,
  experiment_code text,
  experiment_name text,
  customer_segment text,
  discount_pct numeric,
  margin_impact_pct numeric,
  guardrail_type text,
  decision text,
  experiment_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.experiment_code, l.experiment_name, l.customer_segment,
    l.discount_pct, l.margin_impact_pct, l.guardrail_type, l.decision, l.experiment_verdict, l.notes
  from public.pricing_experiment_r3237 l
  where l.guardrail_breached
     or l.experiment_verdict in ('loss','guardrail_violation')
     or l.decision in ('rollback','pause')
  order by l.discount_pct desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3237_high_risk_queue() from public, anon;
grant execute on function public.founder_r3237_high_risk_queue() to authenticated;
