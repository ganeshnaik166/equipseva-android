-- Round 3713: Founder Sales-Commission Plan / Attainment & Payout Board
-- Sales incentive comp — rep × region × period × quota vs attainment × commission earned/paid × payout accuracy & timeliness × disputes × accelerators × clawbacks × CAPA

-- =============================================================================
-- TABLE 1: sales_commission_r3713 — per-rep per-month commission attainment & payout facts
-- =============================================================================
create table if not exists public.sales_commission_r3713 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  rep_code text not null,
  rep_name text not null,
  region text not null,
  period_month date not null,
  plan_class text not null check (plan_class in (
    'new_equipment','amc_renewal','spare_parts','service_contracts','mixed'
  )),
  quota_rupees numeric(14,2) not null,
  attainment_rupees numeric(14,2) not null,
  attainment_pct numeric(6,1),
  commission_earned_rupees numeric(12,2) not null,
  commission_paid_rupees numeric(12,2) not null,
  payout_accuracy_pct numeric(5,1),
  payout_on_time boolean not null,
  disputes_open int not null default 0,
  accelerator_triggered boolean not null,
  clawbacks_rupees numeric(12,2),
  attainment_status text not null check (attainment_status in (
    'over_achiever','on_quota','below_quota','at_risk','payout_disputed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.sales_commission_r3713 enable row level security;

create index if not exists idx_sales_commission_r3713_org on public.sales_commission_r3713(organization_id);
create index if not exists idx_sales_commission_r3713_month on public.sales_commission_r3713(period_month);
create index if not exists idx_sales_commission_r3713_status on public.sales_commission_r3713(attainment_status);

-- =============================================================================
-- TABLE 2: sales_commission_capa_actions_r3713 — CAPA & comp-governance actions
-- =============================================================================
create table if not exists public.sales_commission_capa_actions_r3713 (
  id uuid primary key default gen_random_uuid(),
  commission_log_id uuid not null references public.sales_commission_r3713(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'payout_miscalculation','delayed_payout','quota_setting_error','dispute_backlog',
    'clawback_disputed','accelerator_misapplied','plan_ambiguity','crm_booking_lag'
  )),
  root_cause text not null check (root_cause in (
    'manual_spreadsheet_calc','crm_data_entry_error','plan_document_ambiguity',
    'quota_split_error','delayed_order_booking','territory_realignment_lag',
    'finance_approval_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalculate_and_repay','issue_plan_addendum','correct_crm_pipeline_data',
    'automate_commission_engine','retrain_sales_ops','adjust_quota_split',
    'expedite_dispute_resolution','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  payout_impact_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.sales_commission_capa_actions_r3713 enable row level security;

create index if not exists idx_sales_commission_capa_r3713_log on public.sales_commission_capa_actions_r3713(commission_log_id);
create index if not exists idx_sales_commission_capa_r3713_status on public.sales_commission_capa_actions_r3713(capa_status);

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

  -- 16 commission attainment rows
  insert into public.sales_commission_r3713 (
    organization_id, rep_code, rep_name, region, period_month, plan_class,
    quota_rupees, attainment_rupees, attainment_pct,
    commission_earned_rupees, commission_paid_rupees, payout_accuracy_pct,
    payout_on_time, disputes_open, accelerator_triggered, clawbacks_rupees,
    attainment_status, trend_dir, notes
  )
  select v_org_id, q.rcode, q.rname, q.rgn, q.pm::date, q.pclass,
    q.quota, q.attain, q.apct,
    q.cearn, q.cpaid, q.pacc,
    q.ontime, q.disp, q.accel, q.clawb,
    q.st, q.trd, q.nt
  from (values
    ('SCM-MUM-01','Arjun Deshmukh','Mumbai','2026-07-01','new_equipment',
     2500000,3125000,125.0,250000,250000,100.0,true,0,true,0,'over_achiever','improving','Accelerator 1.5x above 110% — ventilator fleet deal closed at Kokilaben'),
    ('SCM-MUM-02','Priya Nair','Mumbai','2026-07-01','amc_renewal',
     1800000,1830000,101.7,128100,128100,100.0,true,0,false,0,'on_quota','stable','14 AMC contracts renewed on time across Mumbai installed base'),
    ('SCM-CHN-01','Karthik Subramanian','Chennai','2026-07-01','new_equipment',
     2200000,1672000,76.0,100320,88000,87.7,false,1,false,0,'below_quota','worsening','Apollo tender slipped to Q2 — July payout short 12%, repay pending'),
    ('SCM-CHN-02','Divya Raghavan','Chennai','2026-07-01','spare_parts',
     900000,981000,109.0,68670,68670,100.0,true,0,false,0,'on_quota','improving','Spares attach rate up on patient-monitor installed base'),
    ('SCM-DEL-01','Rohit Malhotra','Delhi NCR','2026-07-01','service_contracts',
     1500000,690000,46.0,34500,34500,100.0,true,0,false,0,'at_risk','worsening','Two hospital-chain service deals stalled at procurement — coaching plan on'),
    ('SCM-DEL-02','Sneha Kapoor','Delhi NCR','2026-07-01','mixed',
     2000000,2140000,107.0,149800,121000,80.8,false,2,false,18500,'payout_disputed','worsening','Split-credit dispute with inside sales on AIIMS order — payout held'),
    ('SCM-BLR-01','Manjunath Gowda','Bengaluru','2026-07-01','new_equipment',
     2400000,2688000,112.0,214000,214000,100.0,true,0,true,0,'over_achiever','stable','Manipal cath-lab upgrade closed — tier-1 accelerator triggered'),
    ('SCM-BLR-02','Ayesha Khan','Bengaluru','2026-07-01','amc_renewal',
     1600000,1408000,88.0,84480,84480,100.0,true,0,false,12000,'below_quota','improving','Two AMC churns clawed back — recovery plan on track for August'),
    ('SCM-HYD-01','Venkatesh Rao','Hyderabad','2026-07-01','mixed',
     1900000,1995000,105.0,139650,139650,100.0,true,0,false,0,'on_quota','stable','Balanced month across KIMS and Yashoda accounts'),
    ('SCM-PUN-01','Amruta Joshi','Pune','2026-07-01','spare_parts',
     800000,512000,64.0,25600,25600,100.0,true,0,false,0,'at_risk','stable','Distributor stock correction suppressed spares orders — demand intact'),
    ('SCM-MUM-03','Nikhil Shetty','Mumbai','2026-06-01','new_equipment',
     2500000,2250000,90.0,135000,110700,82.0,false,1,false,0,'payout_disputed','stable','June accelerator applied at wrong tier — recalculation in progress'),
    ('SCM-CHN-03','Lakshmi Venkat','Chennai','2026-06-01','amc_renewal',
     1700000,1938000,114.0,155040,155040,100.0,true,0,true,0,'over_achiever','improving','Early-renewal push covered 9 expiring AMCs at CMC and SRM'),
    ('SCM-DEL-03','Gaurav Bansal','Delhi NCR','2026-06-01','service_contracts',
     1400000,1442000,103.0,100940,100940,100.0,true,0,false,0,'on_quota','stable','Fortis multi-site service contract signed — steady pipeline'),
    ('SCM-BLR-03','Deepa Iyer','Bengaluru','2026-06-01','mixed',
     2100000,1596000,76.0,95760,95760,100.0,true,1,false,0,'below_quota','improving','Territory realignment reset quota — carried-pipeline credit disputed'),
    ('SCM-HYD-02','Suresh Chandra','Hyderabad','2026-05-01','new_equipment',
     2300000,1035000,45.0,51750,51750,100.0,true,0,false,26000,'at_risk','worsening','Lost two tenders on pricing — May clawback on cancelled PO contested'),
    ('SCM-PUN-02','Ritika Sharma','Pune','2026-05-01','amc_renewal',
     1200000,1272000,106.0,89040,71200,80.0,false,1,false,0,'payout_disputed','improving','May payout short — plan-document ambiguity on multi-year AMC rate')
  ) as q(rcode, rname, rgn, pm, pclass, quota, attain, apct, cearn, cpaid, pacc, ontime, disp, accel, clawb, st, trd, nt);

  -- CAPA seed — attach to specific rep-months via rep_code
  insert into public.sales_commission_capa_actions_r3713 (
    commission_log_id, finding_category, root_cause, corrective_action,
    capa_status, payout_impact_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('SCM-DEL-02','dispute_backlog','crm_data_entry_error','expedite_dispute_resolution','escalated',28800.00,'Sales Ops Manager','2026-08-05',null,'Split-credit rule applied wrongly in CRM — dual credit memo drafted'),
    ('SCM-MUM-03','accelerator_misapplied','manual_spreadsheet_calc','automate_commission_engine','in_progress',24300.00,'Sales Comp Analyst','2026-08-14',null,'Tier-2 rate used instead of tier-1 — commission engine to replace sheet'),
    ('SCM-PUN-02','payout_miscalculation','plan_document_ambiguity','issue_plan_addendum','verification_pending',17840.00,'Sales Ops Manager','2026-08-10',null,'Multi-year AMC rate clarified at 7% — addendum with rep for sign-off'),
    ('SCM-CHN-01','delayed_payout','finance_approval_backlog','recalculate_and_repay','open',12320.00,'Finance Controller','2026-08-18',null,'July variable payout under-paid 12% — repay in next cycle'),
    ('SCM-BLR-03','quota_setting_error','territory_realignment_lag','adjust_quota_split','in_progress',0.00,'Regional Sales Head','2026-08-20',null,'Carried pipeline from old territory not credited — quota re-split modelled'),
    ('SCM-HYD-02','clawback_disputed','delayed_order_booking','expedite_dispute_resolution','open',26000.00,'Sales Comp Analyst','2026-08-22',null,'Cancelled-PO clawback contested — hospital re-issuing order next quarter'),
    ('SCM-DEL-01','quota_setting_error','quota_split_error','retrain_sales_ops','closed',0.00,'Sales Ops Manager','2026-07-28','2026-07-25','Service-contract quota double-counted across two reps — corrected'),
    ('SCM-BLR-02','clawback_disputed','crm_data_entry_error','correct_crm_pipeline_data','closed',12000.00,'Sales Comp Analyst','2026-07-30','2026-07-27','AMC churn flag wrong on one contract — clawback reversed after fix')
  ) as q(rcode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.sales_commission_r3713 e
    on e.organization_id = v_org_id and e.rep_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Attainment-status distribution
create or replace function public.founder_r3713_attainment_status_rollup()
returns table(attainment_status text, reps bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sales_commission_r3713)
  select l.attainment_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.sales_commission_r3713 l
  group by l.attainment_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3713_attainment_status_rollup() from public, anon;
grant execute on function public.founder_r3713_attainment_status_rollup() to authenticated;

-- 2) Region attainment scorecard
create or replace function public.founder_r3713_region_scorecard()
returns table(
  region text,
  total_reps bigint,
  over_achievers bigint,
  on_quota bigint,
  below_quota bigint,
  at_risk bigint,
  disputed bigint,
  avg_attainment_pct numeric,
  total_commission_paid_rupees numeric,
  on_time_payout_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.attainment_status = 'over_achiever')::bigint,
    count(*) filter (where l.attainment_status = 'on_quota')::bigint,
    count(*) filter (where l.attainment_status = 'below_quota')::bigint,
    count(*) filter (where l.attainment_status = 'at_risk')::bigint,
    count(*) filter (where l.attainment_status = 'payout_disputed')::bigint,
    round(avg(l.attainment_pct), 1),
    coalesce(sum(l.commission_paid_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.payout_on_time = true)::numeric / nullif(count(*),0), 1)
  from public.sales_commission_r3713 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3713_region_scorecard() from public, anon;
grant execute on function public.founder_r3713_region_scorecard() to authenticated;

-- 3) Plan-class × attainment-status matrix
create or replace function public.founder_r3713_plan_class_status_matrix()
returns table(plan_class text, attainment_status text, reps bigint, avg_attainment_pct numeric, total_commission_earned_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.plan_class, l.attainment_status, count(*)::bigint,
    round(avg(l.attainment_pct), 1),
    coalesce(sum(l.commission_earned_rupees),0)::numeric
  from public.sales_commission_r3713 l
  group by l.plan_class, l.attainment_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3713_plan_class_status_matrix() from public, anon;
grant execute on function public.founder_r3713_plan_class_status_matrix() to authenticated;

-- 4) Monthly attainment trend
create or replace function public.founder_r3713_monthly_attainment_trend()
returns table(period_month date, reps bigint, total_quota_rupees numeric, total_attainment_rupees numeric, avg_attainment_pct numeric, total_commission_paid_rupees numeric, late_payouts bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.quota_rupees),0)::numeric,
    coalesce(sum(l.attainment_rupees),0)::numeric,
    round(avg(l.attainment_pct), 1),
    coalesce(sum(l.commission_paid_rupees),0)::numeric,
    count(*) filter (where l.payout_on_time = false)::bigint
  from public.sales_commission_r3713 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3713_monthly_attainment_trend() from public, anon;
grant execute on function public.founder_r3713_monthly_attainment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3713_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.payout_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.sales_commission_capa_actions_r3713 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3713_capa_status_board() from public, anon;
grant execute on function public.founder_r3713_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3713_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sales_commission_capa_actions_r3713)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.payout_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.sales_commission_capa_actions_r3713 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3713_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3713_root_cause_pareto() to authenticated;

-- 7) Dispute & clawback digest
create or replace function public.founder_r3713_dispute_clawback_digest()
returns table(region text, reps bigint, total_disputes_open bigint, disputed_reps bigint, total_clawbacks_rupees numeric, avg_payout_accuracy_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    coalesce(sum(l.disputes_open),0)::bigint,
    count(*) filter (where l.attainment_status = 'payout_disputed')::bigint,
    coalesce(sum(l.clawbacks_rupees),0)::numeric,
    round(avg(l.payout_accuracy_pct), 1)
  from public.sales_commission_r3713 l
  group by l.region
  order by coalesce(sum(l.disputes_open),0) desc, count(*) desc;
end;
$$;

revoke all on function public.founder_r3713_dispute_clawback_digest() from public, anon;
grant execute on function public.founder_r3713_dispute_clawback_digest() to authenticated;

-- 8) High-risk payout queue (disputed / at-risk / late / clawback)
create or replace function public.founder_r3713_high_risk_queue()
returns table(
  rep_code text,
  rep_name text,
  region text,
  period_month date,
  plan_class text,
  attainment_status text,
  attainment_pct numeric,
  disputes_open int,
  clawbacks_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.rep_code, l.rep_name, l.region, l.period_month, l.plan_class,
    l.attainment_status, l.attainment_pct, l.disputes_open, l.clawbacks_rupees, l.notes
  from public.sales_commission_r3713 l
  where l.attainment_status in ('payout_disputed','at_risk')
     or l.disputes_open > 0
     or l.payout_on_time = false
     or coalesce(l.clawbacks_rupees,0) > 0
  order by l.period_month desc, l.region, l.rep_code;
end;
$$;

revoke all on function public.founder_r3713_high_risk_queue() from public, anon;
grant execute on function public.founder_r3713_high_risk_queue() to authenticated;
