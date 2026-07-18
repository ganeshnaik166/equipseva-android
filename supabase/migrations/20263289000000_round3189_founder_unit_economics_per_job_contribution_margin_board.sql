-- Round 3189: Founder Unit-Economics Per-Job Contribution-Margin Board
-- Per-job economics — job category × revenue × engineer payout × parts × travel × platform fee × contribution margin × take-rate × CAPA

-- =============================================================================
-- TABLE 1: unit_economics_r3189 — per-job contribution-margin log
-- =============================================================================
create table if not exists public.unit_economics_r3189 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  job_code text not null,
  job_date date not null,
  job_category text not null check (job_category in (
    'breakdown_repair','preventive_maintenance','installation_commissioning',
    'amc_visit','cmc_visit','calibration_service','spare_parts_supply','equipment_rental'
  )),
  equipment_type text not null check (equipment_type in (
    'ventilator','anesthesia_workstation','ct_scanner','mri_scanner','patient_monitor',
    'defibrillator','autoclave_sterilizer','dialysis_machine','c_arm','infusion_pump'
  )),
  pricing_model text not null check (pricing_model in (
    'fixed_quote','time_and_material','amc_contract','marketplace_bid','emergency_surge'
  )),
  revenue_rupees numeric(12,2) not null,
  engineer_payout_rupees numeric(12,2) not null,
  parts_cost_rupees numeric(12,2) not null default 0,
  travel_cost_rupees numeric(12,2) not null default 0,
  platform_fee_rupees numeric(12,2) not null,
  contribution_margin_rupees numeric(12,2) not null,
  margin_pct numeric(6,2) not null,
  take_rate_pct numeric(6,2) not null,
  payment_status text not null check (payment_status in (
    'collected','escrow_held','invoiced','partially_collected','written_off'
  )),
  margin_verdict text not null check (margin_verdict in (
    'healthy','acceptable','thin','negative','loss_leader_strategic','pricing_error'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.unit_economics_r3189 enable row level security;

create index if not exists idx_unit_econ_r3189_org on public.unit_economics_r3189(organization_id);
create index if not exists idx_unit_econ_r3189_date on public.unit_economics_r3189(job_date);
create index if not exists idx_unit_econ_r3189_verdict on public.unit_economics_r3189(margin_verdict);

-- =============================================================================
-- TABLE 2: unit_economics_capa_actions_r3189 — margin-improvement CAPA actions
-- =============================================================================
create table if not exists public.unit_economics_capa_actions_r3189 (
  id uuid primary key default gen_random_uuid(),
  unit_economics_id uuid not null references public.unit_economics_r3189(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'negative_margin','underpriced_quote','excess_engineer_payout','parts_cost_overrun',
    'travel_cost_leakage','fee_waiver_unapproved','discount_stacking','escrow_leak',
    'surge_pricing_missed','rework_unbilled'
  )),
  root_cause text not null check (root_cause in (
    'quote_below_cost_floor','payout_matrix_outdated','parts_procured_retail',
    'route_not_clustered','manual_fee_override','competitor_price_match',
    'scope_creep_unbilled','warranty_misclassification','data_entry_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'raise_price_floor','update_payout_matrix','negotiate_parts_vendor_rate',
    'cluster_travel_routing','lock_fee_override_approval','rebill_out_of_scope_work',
    'retrain_pricing_team','sunset_loss_making_sku','add_surge_multiplier','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'gst_invoice_correction','tds_adjustment','none','internal_only',
    'audit_committee_flag','investor_reporting_impact'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.unit_economics_capa_actions_r3189 enable row level security;

create index if not exists idx_unit_econ_capa_r3189_job on public.unit_economics_capa_actions_r3189(unit_economics_id);
create index if not exists idx_unit_econ_capa_r3189_status on public.unit_economics_capa_actions_r3189(capa_status);

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

  -- 13 per-job unit-economics rows
  insert into public.unit_economics_r3189 (
    organization_id, hospital_name, job_code, job_date, job_category, equipment_type, pricing_model,
    revenue_rupees, engineer_payout_rupees, parts_cost_rupees, travel_cost_rupees, platform_fee_rupees,
    contribution_margin_rupees, margin_pct, take_rate_pct, payment_status, margin_verdict, notes
  )
  select v_org_id, q.hosp, q.jc, q.jd::date, q.cat, q.eq, q.pm,
    q.rev, q.pay, q.parts, q.trav, q.fee,
    q.cm, q.mp, q.tr, q.ps, q.mv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','JOB-3189-001','2026-07-01','breakdown_repair','ventilator','marketplace_bid',
     18500.00,11000.00,3200.00,450.00,2775.00,3850.00,20.81,15.00,'collected','healthy','Standard ventilator breakdown — bid landed within band'),
    ('Apollo Hyderabad Jubilee Hills','JOB-3189-002','2026-07-02','amc_visit','anesthesia_workstation','amc_contract',
     9500.00,5200.00,0.00,380.00,1425.00,3920.00,41.26,15.00,'collected','healthy','Quarterly AMC visit, no parts consumed'),
    ('Fortis Bannerghatta Bengaluru','JOB-3189-003','2026-07-02','breakdown_repair','ct_scanner','emergency_surge',
     82000.00,38000.00,29500.00,1200.00,16400.00,13300.00,16.22,20.00,'escrow_held','acceptable','CT tube arcing — emergency surge multiplier applied'),
    ('Fortis Bannerghatta Bengaluru','JOB-3189-004','2026-07-03','calibration_service','patient_monitor','fixed_quote',
     4200.00,3600.00,650.00,520.00,630.00,-570.00,-13.57,15.00,'invoiced','negative','Quoted below cost floor — probe replacement not anticipated'),
    ('Manipal Whitefield Bengaluru','JOB-3189-005','2026-07-03','preventive_maintenance','dialysis_machine','amc_contract',
     12000.00,6800.00,1500.00,600.00,1800.00,3100.00,25.83,15.00,'collected','healthy','PM on 4 dialysis machines clustered in one visit'),
    ('Manipal Whitefield Bengaluru','JOB-3189-006','2026-07-04','spare_parts_supply','infusion_pump','fixed_quote',
     26500.00,1500.00,22800.00,0.00,2650.00,2200.00,8.30,10.00,'collected','thin','Pump module procured at retail — margin compressed'),
    ('AIIMS New Delhi Ansari Nagar','JOB-3189-007','2026-07-04','installation_commissioning','mri_scanner','fixed_quote',
     145000.00,62000.00,18500.00,5400.00,21750.00,59100.00,40.76,15.00,'invoiced','healthy','MRI coil installation and commissioning — 3-day job'),
    ('AIIMS New Delhi Ansari Nagar','JOB-3189-008','2026-07-05','breakdown_repair','defibrillator','marketplace_bid',
     6800.00,4900.00,1400.00,750.00,1020.00,-250.00,-3.68,15.00,'partially_collected','pricing_error','Bid accepted below payout + parts stack'),
    ('KIMS Secunderabad','JOB-3189-009','2026-07-05','cmc_visit','autoclave_sterilizer','amc_contract',
     15500.00,8200.00,3800.00,420.00,2325.00,3080.00,19.87,15.00,'collected','acceptable','CMC visit including door-gasket replacement'),
    ('Care Hospitals Banjara Hills','JOB-3189-010','2026-07-06','breakdown_repair','c_arm','time_and_material',
     32000.00,17500.00,9200.00,480.00,4800.00,4820.00,15.06,15.00,'escrow_held','acceptable','C-arm collimator replacement on T&M terms'),
    ('Yashoda Somajiguda Hyderabad','JOB-3189-011','2026-07-06','equipment_rental','ventilator','fixed_quote',
     21000.00,2500.00,0.00,900.00,4200.00,17600.00,83.81,20.00,'collected','healthy','Weekly ventilator rental — platform-owned asset'),
    ('St John''s Bengaluru','JOB-3189-012','2026-07-07','preventive_maintenance','patient_monitor','marketplace_bid',
     5500.00,3800.00,300.00,650.00,550.00,750.00,13.64,10.00,'collected','thin','Small PM lot — travel not clustered with nearby jobs'),
    ('Rainbow Children''s Hyderabad','JOB-3189-013','2026-07-07','breakdown_repair','infusion_pump','marketplace_bid',
     3800.00,3200.00,950.00,400.00,570.00,-750.00,-19.74,15.00,'written_off','loss_leader_strategic','Strategic account entry job — approved loss leader')
  ) as q(hosp, jc, jd, cat, eq, pm, rev, pay, parts, trav, fee, cm, mp, tr, ps, mv, nt);

  -- CAPA seed — attach to specific jobs by job_code
  insert into public.unit_economics_capa_actions_r3189 (
    unit_economics_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('JOB-3189-004','negative_margin','quote_below_cost_floor','raise_price_floor',
     '2026-07-12',null,'in_progress','internal_only',0.00,'Cost-floor calculator being added to the quote form'),
    ('JOB-3189-008','underpriced_quote','payout_matrix_outdated','update_payout_matrix',
     '2026-07-14',null,'open','investor_reporting_impact',8500.00,'Defibrillator payout band 14 months stale — refresh queued'),
    ('JOB-3189-013','negative_margin','competitor_price_match','sunset_loss_making_sku',
     '2026-07-20',null,'escalated','audit_committee_flag',12000.00,'Third loss-leader for the same account this quarter'),
    ('JOB-3189-006','parts_cost_overrun','parts_procured_retail','negotiate_parts_vendor_rate',
     '2026-07-10','2026-07-08','closed','none',0.00,'Distributor rate card signed — 18% below retail'),
    ('JOB-3189-012','travel_cost_leakage','route_not_clustered','cluster_travel_routing',
     '2026-07-15',null,'verification_pending','internal_only',3500.00,'Routing-engine pilot live in Bengaluru zone'),
    ('JOB-3189-003','escrow_leak','manual_fee_override','lock_fee_override_approval',
     '2026-07-05',null,'overdue','gst_invoice_correction',6800.00,'Surge-fee override lacked approval — GST credit note needed')
  ) as q(jc, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.unit_economics_r3189 e
    on e.organization_id = v_org_id and e.job_code = q.jc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Margin verdict distribution
create or replace function public.founder_r3189_margin_verdict_rollup()
returns table(margin_verdict text, jobs bigint, total_margin_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.unit_economics_r3189)
  select u.margin_verdict, count(*)::bigint,
         coalesce(sum(u.contribution_margin_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.unit_economics_r3189 u
  group by u.margin_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3189_margin_verdict_rollup() from public, anon;
grant execute on function public.founder_r3189_margin_verdict_rollup() to authenticated;

-- 2) Hospital-level unit-economics scorecard
create or replace function public.founder_r3189_hospital_scorecard()
returns table(
  hospital_name text,
  jobs bigint,
  total_revenue_rupees numeric,
  total_payout_rupees numeric,
  total_margin_rupees numeric,
  avg_margin_pct numeric,
  negative_margin_jobs bigint,
  avg_take_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select u.hospital_name,
    count(*)::bigint,
    coalesce(sum(u.revenue_rupees),0)::numeric,
    coalesce(sum(u.engineer_payout_rupees),0)::numeric,
    coalesce(sum(u.contribution_margin_rupees),0)::numeric,
    round(avg(u.margin_pct), 2),
    count(*) filter (where u.contribution_margin_rupees < 0)::bigint,
    round(avg(u.take_rate_pct), 2)
  from public.unit_economics_r3189 u
  group by u.hospital_name
  order by sum(u.contribution_margin_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3189_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3189_hospital_scorecard() to authenticated;

-- 3) Job category × pricing model matrix
create or replace function public.founder_r3189_category_pricing_matrix()
returns table(job_category text, pricing_model text, jobs bigint, total_revenue_rupees numeric, total_margin_rupees numeric, avg_margin_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select u.job_category, u.pricing_model, count(*)::bigint,
    coalesce(sum(u.revenue_rupees),0)::numeric,
    coalesce(sum(u.contribution_margin_rupees),0)::numeric,
    round(avg(u.margin_pct), 2)
  from public.unit_economics_r3189 u
  group by u.job_category, u.pricing_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3189_category_pricing_matrix() from public, anon;
grant execute on function public.founder_r3189_category_pricing_matrix() to authenticated;

-- 4) Daily margin trend
create or replace function public.founder_r3189_daily_margin_trend()
returns table(job_date date, jobs bigint, total_revenue_rupees numeric, total_margin_rupees numeric, avg_margin_pct numeric, avg_take_rate_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select u.job_date, count(*)::bigint,
    coalesce(sum(u.revenue_rupees),0)::numeric,
    coalesce(sum(u.contribution_margin_rupees),0)::numeric,
    round(avg(u.margin_pct), 2),
    round(avg(u.take_rate_pct), 2)
  from public.unit_economics_r3189 u
  group by u.job_date
  order by u.job_date desc;
end;
$$;

revoke execute on function public.founder_r3189_daily_margin_trend() from public, anon;
grant execute on function public.founder_r3189_daily_margin_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3189_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(coalesce(avg(c.estimated_cost_rupees),0)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.unit_economics_capa_actions_r3189 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3189_capa_status_board() from public, anon;
grant execute on function public.founder_r3189_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3189_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.unit_economics_capa_actions_r3189)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.unit_economics_capa_actions_r3189 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3189_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3189_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3189_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.unit_economics_capa_actions_r3189 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3189_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3189_regulatory_impact_digest() to authenticated;

-- 8) Priority margin-risk job queue
create or replace function public.founder_r3189_priority_margin_queue()
returns table(
  hospital_name text,
  job_code text,
  job_date date,
  job_category text,
  revenue_rupees numeric,
  contribution_margin_rupees numeric,
  margin_pct numeric,
  margin_verdict text,
  payment_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select u.hospital_name, u.job_code, u.job_date, u.job_category,
    u.revenue_rupees, u.contribution_margin_rupees, u.margin_pct,
    u.margin_verdict, u.payment_status, u.notes
  from public.unit_economics_r3189 u
  where u.margin_verdict in ('negative','thin','pricing_error','loss_leader_strategic')
     or u.contribution_margin_rupees < 0
     or u.payment_status in ('written_off','partially_collected')
  order by u.contribution_margin_rupees asc, u.job_date desc;
end;
$$;

revoke execute on function public.founder_r3189_priority_margin_queue() from public, anon;
grant execute on function public.founder_r3189_priority_margin_queue() to authenticated;
