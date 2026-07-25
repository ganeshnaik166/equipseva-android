-- Round 3417: Founder LTV:CAC Ratio & CAC-Payback Unit-Economics Board
-- Unit economics governance — customer segment × acquisition channel × cohort quarter × LTV:CAC ratio × CAC payback × gross margin × churn × contribution margin × verdict × CAPA

-- =============================================================================
-- TABLE 1: ltv_cac_unit_economics_r3417 — per segment/channel cohort unit economics
-- =============================================================================
create table if not exists public.ltv_cac_unit_economics_r3417 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cohort_code text not null,
  customer_segment text not null check (customer_segment in (
    'govt_hospital','large_private_chain','standalone_private','nursing_home','diagnostic_center','medical_college'
  )),
  acquisition_channel text not null check (acquisition_channel in (
    'direct_sales','referral','tender','partner','inbound_digital','oem_lead'
  )),
  cohort_quarter text not null,
  customers_acquired int not null,
  cac_rupees numeric(14,2) not null,
  avg_annual_revenue_rupees numeric(14,2) not null,
  gross_margin_pct numeric(5,2) not null,
  avg_lifespan_years numeric(5,2) not null,
  ltv_rupees numeric(14,2) not null,
  ltv_cac_ratio numeric(8,2) not null,
  payback_months numeric(6,2) not null,
  churn_rate_pct numeric(5,2) not null,
  contribution_margin_rupees numeric(14,2) not null,
  unit_econ_verdict text not null check (unit_econ_verdict in (
    'strong','healthy','marginal','unprofitable_channel','improve_retention','reduce_cac'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ltv_cac_unit_economics_r3417 enable row level security;

create index if not exists idx_ltv_cac_unit_economics_r3417_org on public.ltv_cac_unit_economics_r3417(organization_id);
create index if not exists idx_ltv_cac_unit_economics_r3417_segment on public.ltv_cac_unit_economics_r3417(customer_segment);
create index if not exists idx_ltv_cac_unit_economics_r3417_verdict on public.ltv_cac_unit_economics_r3417(unit_econ_verdict);

-- =============================================================================
-- TABLE 2: ltv_cac_unit_economics_capa_actions_r3417 — CAC-reduction / retention / channel-mix actions
-- =============================================================================
create table if not exists public.ltv_cac_unit_economics_capa_actions_r3417 (
  id uuid primary key default gen_random_uuid(),
  cohort_id uuid not null references public.ltv_cac_unit_economics_r3417(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cac_too_high','payback_too_long','ltv_cac_below_target','high_churn',
    'low_gross_margin','unprofitable_channel','negative_contribution_margin','channel_mix_skew'
  )),
  root_cause text not null check (root_cause in (
    'inefficient_sales_spend','long_sales_cycle','discount_heavy_deals','poor_onboarding',
    'service_quality_gap','wrong_channel_fit','low_pricing_power','high_support_cost',
    'pending_investigation','tender_margin_squeeze'
  )),
  corrective_action text not null check (corrective_action in (
    'reallocate_channel_budget','tighten_discount_policy','improve_onboarding','upsell_amc_contracts',
    'renegotiate_pricing','shift_to_referral_channel','pause_unprofitable_channel',
    'improve_retention_program','reduce_cost_to_serve','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_area text not null check (impact_area in (
    'cac_efficiency','retention_ltv','channel_profitability','margin_expansion','board_priority','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_impact_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ltv_cac_unit_economics_capa_actions_r3417 enable row level security;

create index if not exists idx_ltv_cac_unit_economics_capa_r3417_cohort on public.ltv_cac_unit_economics_capa_actions_r3417(cohort_id);
create index if not exists idx_ltv_cac_unit_economics_capa_r3417_status on public.ltv_cac_unit_economics_capa_actions_r3417(capa_status);

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

  -- 14 segment/channel cohort rows
  insert into public.ltv_cac_unit_economics_r3417 (
    organization_id, cohort_code, customer_segment, acquisition_channel, cohort_quarter,
    customers_acquired, cac_rupees, avg_annual_revenue_rupees, gross_margin_pct, avg_lifespan_years,
    ltv_rupees, ltv_cac_ratio, payback_months, churn_rate_pct, contribution_margin_rupees,
    unit_econ_verdict, notes
  )
  select v_org_id, q.code, q.cseg, q.chan, q.cq,
    q.cust, q.cac, q.arev, q.gm, q.life,
    q.ltv, q.ratio, q.payback, q.churn, q.cm,
    q.verdict, q.nt
  from (values
    ('GH-TND-25Q1','govt_hospital','tender','2025-Q1',
     6,180000,320000,34,6.5,
     707200,3.9,20,8,108800,
     'healthy','AIIMS Delhi govt tender cohort — long payback but sticky multi-year AMC contracts'),
    ('LPC-DS-25Q1','large_private_chain','direct_sales','2025-Q1',
     9,145000,480000,40,7,
     1344000,9.3,9,5,192000,
     'strong','Apollo Chennai & Fortis Gurgaon chains — flagship enterprise accounts, best margins'),
    ('SP-REF-25Q1','standalone_private','referral','2025-Q1',
     14,42000,165000,38,5,
     313500,7.5,8,9,62700,
     'strong','Referral cohort of standalone hospitals — low CAC drives high efficiency'),
    ('NH-INB-25Q1','nursing_home','inbound_digital','2025-Q1',
     11,28000,96000,30,3.5,
     100800,3.6,12,16,28800,
     'healthy','Inbound digital nursing-home leads — improving but churn on watchlist'),
    ('DC-OEM-25Q1','diagnostic_center','oem_lead','2025-Q1',
     7,95000,210000,36,4,
     302400,3.2,15,12,75600,
     'marginal','OEM-referred diagnostic centres — margin acceptable but CAC creeping up'),
    ('MC-DS-25Q1','medical_college','direct_sales','2025-Q1',
     4,260000,540000,32,8,
     1382400,5.3,18,4,172800,
     'healthy','CMC Vellore & KIMS teaching-hospital cohort — high CAC offset by long lifespan'),
    ('SP-PTN-25Q2','standalone_private','partner','2025-Q2',
     10,130000,140000,28,3,
     117600,0.9,40,22,39200,
     'unprofitable_channel','Partner-sourced standalone deals — CAC exceeds LTV, channel unprofitable'),
    ('NH-DS-25Q2','nursing_home','direct_sales','2025-Q2',
     5,155000,108000,26,2.5,
     70200,0.45,66,28,28080,
     'unprofitable_channel','Direct sales into small nursing homes — sub-1 LTV:CAC and high churn'),
    ('DC-REF-25Q2','diagnostic_center','referral','2025-Q2',
     12,38000,195000,40,4.5,
     351000,9.2,6,7,78000,
     'strong','Referral diagnostic-centre cohort — best-in-class acquisition efficiency'),
    ('LPC-TND-25Q2','large_private_chain','tender','2025-Q2',
     3,310000,620000,22,6,
     818400,2.6,27,6,136400,
     'reduce_cac','Manipal Bengaluru tender wins — heavy discounting squeezed margin, reduce CAC'),
    ('GH-DS-25Q2','govt_hospital','direct_sales','2025-Q2',
     5,240000,350000,30,7,
     735000,3.1,27,6,105000,
     'reduce_cac','Govt direct-sales — long payback, tender route is the more efficient channel'),
    ('NH-INB-25Q2','nursing_home','inbound_digital','2025-Q2',
     15,24000,88000,29,2.8,
     71456,3.0,11,25,25520,
     'improve_retention','High-volume inbound nursing homes — good CAC but churn erodes LTV'),
    ('SP-INB-25Q2','standalone_private','inbound_digital','2025-Q2',
     13,33000,132000,35,3.2,
     147840,4.5,9,19,46200,
     'improve_retention','Inbound standalone cohort — healthy ratio but 19% churn to address'),
    ('MC-REF-25Q2','medical_college','referral','2025-Q2',
     6,88000,460000,33,7.5,
     1138500,12.9,7,3,151800,
     'strong','Referral medical-college cohort — highest LTV:CAC in the portfolio')
  ) as q(code, cseg, chan, cq, cust, cac, arev, gm, life, ltv, ratio, payback, churn, cm, verdict, nt);

  -- CAPA seed — attach to at-risk cohorts via cohort_code
  insert into public.ltv_cac_unit_economics_capa_actions_r3417 (
    cohort_id, finding_category, root_cause, corrective_action,
    capa_status, impact_area, target_closure_date, actual_closure_date,
    estimated_impact_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ia, q.tcd::date, q.acd::date,
    q.impact, q.nt
  from (values
    ('SP-PTN-25Q2','unprofitable_channel','wrong_channel_fit','pause_unprofitable_channel','in_progress','board_priority','2025-08-15',null,850000,'Partner channel LTV:CAC 0.9 — pausing new partner deals, reallocating budget to referral'),
    ('NH-DS-25Q2','cac_too_high','inefficient_sales_spend','shift_to_referral_channel','overdue','cac_efficiency','2025-07-20',null,620000,'Direct sales into small nursing homes uneconomic — shift to referral/inbound, past due'),
    ('LPC-TND-25Q2','low_gross_margin','discount_heavy_deals','tighten_discount_policy','verification_pending','margin_expansion','2025-08-10',null,480000,'Tender discounting cut margin to 22% — new discount approval matrix rolled out'),
    ('GH-DS-25Q2','payback_too_long','long_sales_cycle','reallocate_channel_budget','open','cac_efficiency','2025-09-01',null,300000,'Govt direct payback 27 months — prioritise tender channel for the govt segment'),
    ('NH-INB-25Q2','high_churn','poor_onboarding','improve_onboarding','in_progress','retention_ltv','2025-08-25',null,410000,'25% churn on inbound nursing homes — onboarding and first-90-day success program'),
    ('DC-OEM-25Q1','ltv_cac_below_target','high_support_cost','reduce_cost_to_serve','escalated','channel_profitability','2025-07-30',null,275000,'OEM-lead diagnostic centres ratio 3.2 and CAC rising — cost-to-serve review escalated'),
    ('SP-INB-25Q2','high_churn','service_quality_gap','improve_retention_program','closed','retention_ltv','2025-07-15','2025-07-12',190000,'Standalone inbound retention program launched — churn trending down, closed')
  ) as q(code, fc, rc, ca, cst, ia, tcd, acd, impact, nt)
  join public.ltv_cac_unit_economics_r3417 e
    on e.organization_id = v_org_id and e.cohort_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Unit-economics verdict distribution
create or replace function public.founder_r3417_verdict_rollup()
returns table(unit_econ_verdict text, cohorts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ltv_cac_unit_economics_r3417)
  select l.unit_econ_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ltv_cac_unit_economics_r3417 l
  group by l.unit_econ_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3417_verdict_rollup() from public, anon;
grant execute on function public.founder_r3417_verdict_rollup() to authenticated;

-- 2) Segment-level unit-economics scorecard
create or replace function public.founder_r3417_segment_scorecard()
returns table(
  customer_segment text,
  cohorts bigint,
  customers bigint,
  avg_ltv_cac numeric,
  avg_payback_months numeric,
  avg_churn_pct numeric,
  total_contribution_rupees numeric,
  unprofitable bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment,
    count(*)::bigint,
    coalesce(sum(l.customers_acquired),0)::bigint,
    round(avg(l.ltv_cac_ratio), 2),
    round(avg(l.payback_months), 1),
    round(avg(l.churn_rate_pct), 1),
    round(coalesce(sum(l.contribution_margin_rupees * l.customers_acquired),0), 0),
    count(*) filter (where l.unit_econ_verdict = 'unprofitable_channel')::bigint
  from public.ltv_cac_unit_economics_r3417 l
  group by l.customer_segment
  order by round(avg(l.ltv_cac_ratio), 2) desc;
end;
$$;

revoke execute on function public.founder_r3417_segment_scorecard() from public, anon;
grant execute on function public.founder_r3417_segment_scorecard() to authenticated;

-- 3) Segment × channel matrix
create or replace function public.founder_r3417_segment_channel_matrix()
returns table(
  customer_segment text,
  acquisition_channel text,
  cohorts bigint,
  customers bigint,
  avg_ltv_cac numeric,
  avg_payback_months numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment, l.acquisition_channel,
    count(*)::bigint,
    coalesce(sum(l.customers_acquired),0)::bigint,
    round(avg(l.ltv_cac_ratio), 2),
    round(avg(l.payback_months), 1)
  from public.ltv_cac_unit_economics_r3417 l
  group by l.customer_segment, l.acquisition_channel
  order by round(avg(l.ltv_cac_ratio), 2) desc;
end;
$$;

revoke execute on function public.founder_r3417_segment_channel_matrix() from public, anon;
grant execute on function public.founder_r3417_segment_channel_matrix() to authenticated;

-- 4) Cohort-quarter trend
create or replace function public.founder_r3417_cohort_quarter_trend()
returns table(
  cohort_quarter text,
  cohorts bigint,
  customers bigint,
  avg_ltv_cac numeric,
  avg_cac_rupees numeric,
  avg_churn_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cohort_quarter,
    count(*)::bigint,
    coalesce(sum(l.customers_acquired),0)::bigint,
    round(avg(l.ltv_cac_ratio), 2),
    round(avg(l.cac_rupees), 0),
    round(avg(l.churn_rate_pct), 1)
  from public.ltv_cac_unit_economics_r3417 l
  group by l.cohort_quarter
  order by l.cohort_quarter;
end;
$$;

revoke execute on function public.founder_r3417_cohort_quarter_trend() from public, anon;
grant execute on function public.founder_r3417_cohort_quarter_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3417_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.ltv_cac_unit_economics_capa_actions_r3417 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3417_capa_status_board() from public, anon;
grant execute on function public.founder_r3417_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3417_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ltv_cac_unit_economics_capa_actions_r3417)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ltv_cac_unit_economics_capa_actions_r3417 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3417_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3417_root_cause_pareto() to authenticated;

-- 7) Impact-area digest
create or replace function public.founder_r3417_impact_digest()
returns table(impact_area text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.impact_area, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_impact_rupees),0)::numeric
  from public.ltv_cac_unit_economics_capa_actions_r3417 c
  group by c.impact_area
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3417_impact_digest() from public, anon;
grant execute on function public.founder_r3417_impact_digest() to authenticated;

-- 8) High-risk unit-economics queue
create or replace function public.founder_r3417_high_risk_queue()
returns table(
  cohort_code text,
  customer_segment text,
  acquisition_channel text,
  cohort_quarter text,
  ltv_cac_ratio numeric,
  payback_months numeric,
  churn_rate_pct numeric,
  unit_econ_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cohort_code, l.customer_segment, l.acquisition_channel, l.cohort_quarter,
    l.ltv_cac_ratio, l.payback_months, l.churn_rate_pct, l.unit_econ_verdict, l.notes
  from public.ltv_cac_unit_economics_r3417 l
  where l.unit_econ_verdict in ('marginal','unprofitable_channel','reduce_cac','improve_retention')
     or l.ltv_cac_ratio < 3.0
     or l.payback_months > 24.0
     or l.churn_rate_pct > 15.0
  order by l.ltv_cac_ratio asc, l.payback_months desc;
end;
$$;

revoke execute on function public.founder_r3417_high_risk_queue() from public, anon;
grant execute on function public.founder_r3417_high_risk_queue() to authenticated;
