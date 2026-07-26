-- Round 3453: Founder Cost-to-Serve / Customer-Segment Profitability Board
-- Cost-to-serve allocated across customer segments — revenue × direct service cost × allocated overhead
-- × cost-to-serve × gross/net margin × service intensity × profitability verdict × monthly trend × CAPA

-- =============================================================================
-- TABLE 1: cost_to_serve_segment_r3453 — per-segment cost-to-serve & profitability
-- =============================================================================
create table if not exists public.cost_to_serve_segment_r3453 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  segment_code text not null,
  customer_segment text not null,
  region text not null,
  revenue_rupees numeric(14,2) not null,
  direct_service_cost_rupees numeric(14,2) not null,
  allocated_overhead_rupees numeric(14,2) not null,
  cost_to_serve_rupees numeric(14,2) not null,
  gross_margin_pct numeric(6,2),
  net_margin_pct numeric(6,2),
  service_intensity text not null check (service_intensity in (
    'low','medium','high','very_high'
  )),
  profitability text not null check (profitability in (
    'highly_profitable','profitable','breakeven','loss_making'
  )),
  period_month date not null,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cost_to_serve_segment_r3453 enable row level security;

create index if not exists idx_cost_to_serve_segment_r3453_org on public.cost_to_serve_segment_r3453(organization_id);
create index if not exists idx_cost_to_serve_segment_r3453_month on public.cost_to_serve_segment_r3453(period_month);
create index if not exists idx_cost_to_serve_segment_r3453_prof on public.cost_to_serve_segment_r3453(profitability);

-- =============================================================================
-- TABLE 2: cost_to_serve_segment_capa_actions_r3453 — CAPA & margin-recovery actions
-- =============================================================================
create table if not exists public.cost_to_serve_segment_capa_actions_r3453 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  segment_log_id uuid not null references public.cost_to_serve_segment_r3453(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'margin_erosion','cost_to_serve_overrun','overhead_over_allocation','low_revenue_density',
    'discount_leakage','service_intensity_mismatch','contract_underpricing','payment_delay_drag'
  )),
  root_cause text not null check (root_cause in (
    'excessive_site_visits','high_travel_cost','sla_over_commitment','spare_parts_cost_high',
    'manual_process_overhead','underpriced_contract','low_ticket_volume','payment_delays',
    'aging_equipment_fleet','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reprice_contract','optimize_visit_schedule','renegotiate_sla','consolidate_routes',
    'automate_workflow','shift_to_remote_support','exit_segment','upsell_amc',
    'enforce_payment_terms','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  margin_impact_rupees numeric(14,2),
  action_owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cost_to_serve_segment_capa_actions_r3453 enable row level security;

create index if not exists idx_cost_to_serve_capa_r3453_log on public.cost_to_serve_segment_capa_actions_r3453(segment_log_id);
create index if not exists idx_cost_to_serve_capa_r3453_status on public.cost_to_serve_segment_capa_actions_r3453(capa_status);

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

  -- 16 segment cost-to-serve rows
  insert into public.cost_to_serve_segment_r3453 (
    organization_id, segment_code, customer_segment, region, revenue_rupees,
    direct_service_cost_rupees, allocated_overhead_rupees, cost_to_serve_rupees,
    gross_margin_pct, net_margin_pct, service_intensity, profitability,
    period_month, trend_dir, notes
  )
  select v_org_id, q.sc, q.seg, q.reg, q.rev,
    q.dsc, q.aoh, q.cts,
    q.gm, q.nm, q.si, q.prof,
    q.pm::date, q.td, q.nt
  from (values
    ('CTS-LHC-S01','large_hospital_chain','south',5200000,2100000,900000,3000000,
     59.6,42.3,'medium','highly_profitable','2026-07-01','improving','Multi-site AMC portfolio, strong imaging-service margins'),
    ('CTS-LHC-N02','large_hospital_chain','north',4800000,2050000,950000,3000000,
     57.3,37.5,'high','profitable','2026-06-01','stable','North chain, higher travel cost dents net margin'),
    ('CTS-STD-W03','standalone_hospital','west',2600000,1350000,620000,1970000,
     48.1,24.2,'high','profitable','2026-05-01','worsening','Rising spare-parts cost eroding net margin'),
    ('CTS-DGL-S04','diagnostic_lab','south',1900000,780000,410000,1190000,
     58.9,37.4,'low','highly_profitable','2026-07-01','improving','Remote-support heavy lab chain, low visit intensity'),
    ('CTS-NRS-E05','nursing_home','east',640000,470000,210000,680000,
     26.6,-6.3,'high','loss_making','2026-06-01','worsening','Small nursing homes below cost-to-serve break-even'),
    ('CTS-GOV-C06','government_hospital','central',3100000,1980000,1050000,3030000,
     36.1,2.3,'very_high','breakeven','2026-05-01','stable','Tender-priced govt contract, thin net margin'),
    ('CTS-DIA-S07','dialysis_center','south',2200000,1020000,480000,1500000,
     53.6,31.8,'medium','profitable','2026-07-01','improving','RO water plus dialysis machine AMC bundle'),
    ('CTS-IVF-W08','ivf_clinic','west',1500000,560000,300000,860000,
     62.7,42.7,'low','highly_profitable','2026-07-01','stable','Premium IVF equipment, low fault rate'),
    ('CTS-MED-N09','medical_college','north',3600000,2200000,1150000,3350000,
     38.9,6.9,'very_high','breakeven','2026-06-01','worsening','Large install base, aging fleet raising visit load'),
    ('CTS-CLN-E10','clinic','east',420000,360000,180000,540000,
     14.3,-28.6,'very_high','loss_making','2026-05-01','worsening','Scattered single-clinic accounts, uneconomic to serve'),
    ('CTS-STD-S11','standalone_hospital','south',2900000,1300000,640000,1940000,
     55.2,33.1,'medium','profitable','2026-07-01','improving','Route consolidation improving net margin'),
    ('CTS-GOV-E12','government_hospital','east',2700000,1750000,980000,2730000,
     35.2,-1.1,'very_high','loss_making','2026-06-01','worsening','Delayed payments and high overhead push net negative'),
    ('CTS-DGL-N13','diagnostic_lab','north',1650000,720000,360000,1080000,
     56.4,34.5,'low','highly_profitable','2026-07-01','stable','Efficient lab AMC, mostly remote diagnostics'),
    ('CTS-DIA-C14','dialysis_center','central',1850000,980000,470000,1450000,
     47.0,21.6,'high','profitable','2026-06-01','stable','Dialysis water-treatment adds service load'),
    ('CTS-NRS-W15','nursing_home','west',720000,500000,240000,740000,
     30.6,-2.8,'high','loss_making','2026-05-01','improving','Bundling nearby homes to cut per-visit cost'),
    ('CTS-LHC-C16','large_hospital_chain','central',4400000,1900000,880000,2780000,
     56.8,36.8,'medium','profitable','2026-07-01','improving','Central region chain, scaling AMC coverage')
  ) as q(sc, seg, reg, rev, dsc, aoh, cts, gm, nm, si, prof, pm, td, nt);

  -- CAPA seed — attach to specific segments via segment_code
  insert into public.cost_to_serve_segment_capa_actions_r3453 (
    organization_id, segment_log_id, finding_category, root_cause, corrective_action,
    capa_status, margin_impact_rupees, action_owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.mi, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CTS-NRS-E05','margin_erosion','high_travel_cost','consolidate_routes','in_progress',180000,'Regional Ops Lead - East','2026-08-15',null,'Cluster nursing-home visits onto a single service route'),
    ('CTS-CLN-E10','cost_to_serve_overrun','low_ticket_volume','exit_segment','escalated',260000,'Segment Head - Clinics','2026-08-01',null,'Uneconomic scattered clinics — proposing a managed exit'),
    ('CTS-GOV-E12','payment_delay_drag','payment_delays','enforce_payment_terms','open',320000,'Finance Controller','2026-08-20',null,'Govt receivables past 120 days inflating cost-to-serve'),
    ('CTS-STD-W03','service_intensity_mismatch','spare_parts_cost_high','upsell_amc','verification_pending',150000,'Key Account Manager - West','2026-07-30',null,'Move to comprehensive AMC to cap spare-parts exposure'),
    ('CTS-MED-N09','cost_to_serve_overrun','aging_equipment_fleet','reprice_contract','open',410000,'Regional Ops Lead - North','2026-09-10',null,'Aging fleet driving visits — reprice at renewal'),
    ('CTS-GOV-C06','contract_underpricing','underpriced_contract','reprice_contract','in_progress',220000,'Bid Manager - Central','2026-08-25',null,'Tender priced below cost-to-serve — renegotiate scope'),
    ('CTS-NRS-W15','margin_erosion','excessive_site_visits','optimize_visit_schedule','closed',95000,'Regional Ops Lead - West','2026-07-05','2026-07-18','Preventive-visit schedule optimized; margin restored'),
    ('CTS-LHC-N02','overhead_over_allocation','manual_process_overhead','automate_workflow','verification_pending',130000,'Ops Excellence','2026-08-05',null,'Automate dispatch to cut allocated overhead'),
    ('CTS-DIA-C14','service_intensity_mismatch','sla_over_commitment','renegotiate_sla','open',110000,'Key Account Manager - Central','2026-08-12',null,'SLA over-committed relative to contract value')
  ) as q(sc, fc, rc, ca, cst, mi, own, tcd, acd, nt)
  join public.cost_to_serve_segment_r3453 e
    on e.organization_id = v_org_id and e.segment_code = q.sc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Profitability distribution
create or replace function public.founder_r3453_profitability_rollup()
returns table(profitability text, segments bigint, total_revenue_rupees numeric, avg_net_margin_pct numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cost_to_serve_segment_r3453)
  select l.profitability, count(*)::bigint,
         coalesce(sum(l.revenue_rupees),0)::numeric,
         round(avg(l.net_margin_pct), 1),
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cost_to_serve_segment_r3453 l
  group by l.profitability
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3453_profitability_rollup() from public, anon;
grant execute on function public.founder_r3453_profitability_rollup() to authenticated;

-- 2) Customer-segment scorecard
create or replace function public.founder_r3453_segment_scorecard()
returns table(
  customer_segment text,
  segments bigint,
  total_revenue_rupees numeric,
  total_cost_to_serve_rupees numeric,
  avg_gross_margin_pct numeric,
  avg_net_margin_pct numeric,
  loss_making bigint,
  profitable_pct numeric
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
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.cost_to_serve_rupees),0)::numeric,
    round(avg(l.gross_margin_pct), 1),
    round(avg(l.net_margin_pct), 1),
    count(*) filter (where l.profitability = 'loss_making')::bigint,
    round(100.0 * count(*) filter (where l.profitability in ('highly_profitable','profitable'))::numeric / nullif(count(*),0), 1)
  from public.cost_to_serve_segment_r3453 l
  group by l.customer_segment
  order by sum(l.revenue_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3453_segment_scorecard() from public, anon;
grant execute on function public.founder_r3453_segment_scorecard() to authenticated;

-- 3) Segment × profitability matrix
create or replace function public.founder_r3453_segment_profitability_matrix()
returns table(customer_segment text, profitability text, segments bigint, total_revenue_rupees numeric, avg_net_margin_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment, l.profitability, count(*)::bigint,
    coalesce(sum(l.revenue_rupees),0)::numeric,
    round(avg(l.net_margin_pct), 1)
  from public.cost_to_serve_segment_r3453 l
  group by l.customer_segment, l.profitability
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3453_segment_profitability_matrix() from public, anon;
grant execute on function public.founder_r3453_segment_profitability_matrix() to authenticated;

-- 4) Monthly margin trend
create or replace function public.founder_r3453_monthly_margin_trend()
returns table(
  period_month date,
  segments bigint,
  total_revenue_rupees numeric,
  total_cost_to_serve_rupees numeric,
  avg_gross_margin_pct numeric,
  avg_net_margin_pct numeric,
  loss_making bigint
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
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.cost_to_serve_rupees),0)::numeric,
    round(avg(l.gross_margin_pct), 1),
    round(avg(l.net_margin_pct), 1),
    count(*) filter (where l.profitability = 'loss_making')::bigint
  from public.cost_to_serve_segment_r3453 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3453_monthly_margin_trend() from public, anon;
grant execute on function public.founder_r3453_monthly_margin_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3453_capa_status_board()
returns table(capa_status text, findings bigint, total_margin_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.margin_impact_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.cost_to_serve_segment_capa_actions_r3453 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3453_capa_status_board() from public, anon;
grant execute on function public.founder_r3453_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3453_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_margin_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cost_to_serve_segment_capa_actions_r3453)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.margin_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cost_to_serve_segment_capa_actions_r3453 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3453_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3453_root_cause_pareto() to authenticated;

-- 7) Margin-impact digest (by finding category)
create or replace function public.founder_r3453_margin_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_margin_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.margin_impact_rupees),0)::numeric
  from public.cost_to_serve_segment_capa_actions_r3453 c
  group by c.finding_category
  order by sum(c.margin_impact_rupees) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3453_margin_impact_digest() from public, anon;
grant execute on function public.founder_r3453_margin_impact_digest() to authenticated;

-- 8) High-risk queue (loss-making / worsening / high-intensity segments)
create or replace function public.founder_r3453_high_risk_queue()
returns table(
  customer_segment text,
  segment_code text,
  region text,
  period_month date,
  profitability text,
  service_intensity text,
  trend_dir text,
  revenue_rupees numeric,
  net_margin_pct numeric,
  cost_to_serve_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment, l.segment_code, l.region, l.period_month,
    l.profitability, l.service_intensity, l.trend_dir,
    l.revenue_rupees, l.net_margin_pct, l.cost_to_serve_rupees, l.notes
  from public.cost_to_serve_segment_r3453 l
  where l.profitability in ('loss_making','breakeven')
     or l.trend_dir = 'worsening'
     or l.service_intensity in ('high','very_high')
     or l.net_margin_pct < 25
  order by l.net_margin_pct asc, l.cost_to_serve_rupees desc;
end;
$$;

revoke execute on function public.founder_r3453_high_risk_queue() from public, anon;
grant execute on function public.founder_r3453_high_risk_queue() to authenticated;
