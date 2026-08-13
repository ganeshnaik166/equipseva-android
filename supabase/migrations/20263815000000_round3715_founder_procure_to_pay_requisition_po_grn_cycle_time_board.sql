-- Round 3715: Founder Procure-to-Pay Requisition→PO→GRN Cycle-Time Board
-- P2P cycle time — requisition, approval, PO, GRN, invoice-match stage SLAs per category

-- =============================================================================
-- TABLE 1: p2p_cycle_r3715 — per-category/function P2P cycle-time rollups
-- =============================================================================
create table if not exists public.p2p_cycle_r3715 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  category text not null,
  requesting_function text not null,
  cycle_ref text not null,
  period_month date not null,
  requisitions int not null,
  req_to_approval_days numeric(6,2),
  approval_to_po_days numeric(6,2),
  po_to_grn_days numeric(6,2),
  grn_to_invoice_match_days numeric(6,2),
  total_cycle_days numeric(6,2),
  target_cycle_days numeric(6,2),
  emergency_pos int not null default 0,
  three_way_match_pass_pct numeric(5,2),
  stage_class text not null check (stage_class in (
    'requisition_approval','po_release','delivery_grn','invoice_match','payment_release'
  )),
  cycle_status text not null check (cycle_status in (
    'within_target','on_target','slow','bottlenecked','broken'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.p2p_cycle_r3715 enable row level security;

create index if not exists idx_p2p_cycle_r3715_org on public.p2p_cycle_r3715(organization_id);
create index if not exists idx_p2p_cycle_r3715_month on public.p2p_cycle_r3715(period_month);
create index if not exists idx_p2p_cycle_r3715_status on public.p2p_cycle_r3715(cycle_status);

-- =============================================================================
-- TABLE 2: p2p_cycle_capa_actions_r3715 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.p2p_cycle_capa_actions_r3715 (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.p2p_cycle_r3715(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'requisition_delay','approval_bottleneck','po_release_delay','grn_delay',
    'invoice_match_mismatch','vendor_master_data_issue','budget_approval_pending','emergency_po_spike'
  )),
  root_cause text not null check (root_cause in (
    'approver_unavailable','budget_code_missing','vendor_data_incomplete','manual_grn_entry',
    'three_way_match_exception','procurement_backlog','system_downtime',
    'decentralized_approval_chain','pending_investigation','po_amendment_required'
  )),
  corrective_action text not null check (corrective_action in (
    'escalate_to_approver','auto_route_approval','update_vendor_master','digitize_grn_process',
    'resolve_match_exception','add_procurement_headcount','system_maintenance_fix',
    'centralize_approval_workflow','none_required','amend_po'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  owner text not null,
  cost_impact_rupees numeric(12,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.p2p_cycle_capa_actions_r3715 enable row level security;

create index if not exists idx_p2p_cycle_capa_r3715_cycle on public.p2p_cycle_capa_actions_r3715(cycle_id);
create index if not exists idx_p2p_cycle_capa_r3715_status on public.p2p_cycle_capa_actions_r3715(capa_status);

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

  -- 16 P2P cycle rollup rows
  insert into public.p2p_cycle_r3715 (
    organization_id, category, requesting_function, cycle_ref, period_month,
    requisitions, req_to_approval_days, approval_to_po_days, po_to_grn_days, grn_to_invoice_match_days,
    total_cycle_days, target_cycle_days, emergency_pos, three_way_match_pass_pct,
    stage_class, cycle_status, trend_dir, notes
  )
  select v_org_id, q.cat, q.fn, q.cref, q.pm::date,
    q.req, q.r2a, q.a2p, q.p2g, q.g2i,
    q.tot, q.tgt, q.epo, q.twm,
    q.sc, q.cs, q.td, q.nt
  from (values
    ('capital_equipment','operations','P2P-CAPEX-2026-04','2026-04-01',
     12,3.5,2.0,9.0,2.5,17.0,15.0,1,92.5,'delivery_grn','slow','worsening',
     'Capital equipment PO cycle slipping due to vendor lead-time on ventilator racks'),
    ('spare_parts','service_engineering','P2P-SPARE-2026-04','2026-04-01',
     45,1.0,1.5,4.0,1.0,7.5,8.0,6,97.0,'po_release','within_target','stable',
     'Spare parts requisition-to-PO steady within SLA'),
    ('consumables','warehouse','P2P-CONS-2026-04','2026-04-01',
     60,0.8,1.0,3.0,0.8,5.6,6.0,3,98.5,'requisition_approval','on_target','stable',
     'Consumables cycle on target, low emergency PO volume'),
    ('it_hardware','it','P2P-ITHW-2026-04','2026-04-01',
     8,4.0,3.0,10.0,3.0,20.0,14.0,2,88.0,'delivery_grn','bottlenecked','worsening',
     'IT hardware GRN delayed — import customs clearance for laptops'),
    ('amc_services','finance','P2P-AMC-2026-04','2026-04-01',
     20,2.0,2.5,1.0,4.0,9.5,10.0,0,95.0,'invoice_match','on_target','improving',
     'AMC renewal invoices matched faster after vendor master cleanup'),
    ('logistics_services','warehouse','P2P-LOG-2026-05','2026-05-01',
     30,1.5,1.0,2.0,1.5,6.0,7.0,4,96.0,'po_release','within_target','stable',
     'Freight vendor POs releasing on time'),
    ('packaging_materials','warehouse','P2P-PKG-2026-05','2026-05-01',
     25,1.0,1.2,3.5,1.0,6.7,7.0,2,94.0,'requisition_approval','within_target','improving',
     'Packaging materials requisitions approved faster post-delegation'),
    ('office_supplies','admin','P2P-OFF-2026-05','2026-05-01',
     18,0.5,0.8,2.0,0.5,3.8,5.0,0,99.0,'requisition_approval','within_target','stable',
     'Office supplies cycle comfortably within target'),
    ('capital_equipment','operations','P2P-CAPEX-2026-05','2026-05-01',
     10,3.0,2.5,8.0,2.0,15.5,15.0,1,93.0,'po_release','on_target','improving',
     'Capital equipment cycle recovering after Q1 vendor onboarding'),
    ('spare_parts','service_engineering','P2P-SPARE-2026-05','2026-05-01',
     50,1.2,1.6,5.0,1.2,9.0,8.0,9,95.5,'delivery_grn','slow','worsening',
     'Spare parts GRN slowing — warehouse short-staffed'),
    ('it_hardware','it','P2P-ITHW-2026-06','2026-06-01',
     6,3.5,2.8,6.0,2.5,14.8,14.0,1,91.0,'invoice_match','on_target','stable',
     'IT hardware cycle stabilized after customs process fix'),
    ('consumables','quality','P2P-CONS-2026-06','2026-06-01',
     55,0.9,1.1,3.2,0.9,6.1,6.0,2,97.5,'requisition_approval','on_target','stable',
     'Consumables requisition cycle marginally over target'),
    ('amc_services','finance','P2P-AMC-2026-06','2026-06-01',
     22,2.2,2.8,1.2,6.0,12.2,10.0,0,89.0,'invoice_match','bottlenecked','worsening',
     'AMC invoice match exceptions rising — vendor GSTIN mismatches'),
    ('logistics_services','sales','P2P-LOG-2026-06','2026-06-01',
     35,2.0,1.8,2.5,1.0,7.3,7.0,5,93.5,'po_release','on_target','stable',
     'Logistics POs slightly above target from festive season demand'),
    ('capital_equipment','operations','P2P-CAPEX-2026-06','2026-06-01',
     9,5.0,4.5,14.0,3.5,27.0,15.0,2,80.0,'delivery_grn','broken','worsening',
     'Capital equipment cycle broken — MRI coil import stuck at customs, 45-day delay flagged'),
    ('packaging_materials','warehouse','P2P-PKG-2026-06','2026-06-01',
     27,1.1,1.3,3.0,1.0,6.4,7.0,1,96.5,'requisition_approval','within_target','improving',
     'Packaging cycle improved after new vendor onboarding')
  ) as q(cat, fn, cref, pm, req, r2a, a2p, p2g, g2i, tot, tgt, epo, twm, sc, cs, td, nt);

  -- CAPA seed — attach to specific cycles via cycle_ref
  insert into public.p2p_cycle_capa_actions_r3715 (
    cycle_id, finding_category, root_cause, corrective_action, capa_status, owner,
    target_closure_date, actual_closure_date, cost_impact_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.cst, q.own,
    q.tcd::date, q.acd::date, q.imp, q.nt
  from (values
    ('P2P-CAPEX-2026-04','grn_delay','vendor_data_incomplete','digitize_grn_process','in_progress','Warehouse Ops Manager','2026-05-15',null,180000.00,'Ventilator rack GRN delayed at dock — digitizing receipt scan to cut re-entry time'),
    ('P2P-ITHW-2026-04','grn_delay','procurement_backlog','add_procurement_headcount','open','IT Infra Manager','2026-05-20',null,95000.00,'Customs clearance backlog for laptop import stretching GRN stage'),
    ('P2P-SPARE-2026-05','grn_delay','manual_grn_entry','digitize_grn_process','verification_pending','Warehouse Ops Manager','2026-06-01','2026-05-30',42000.00,'Barcode scanning rolled out at spares warehouse — verifying cycle-time drop'),
    ('P2P-AMC-2026-06','invoice_match_mismatch','three_way_match_exception','resolve_match_exception','escalated','Finance Controller','2026-06-25',null,65000.00,'AMC vendor GSTIN mismatch causing repeated three-way match exceptions — escalated to AP team'),
    ('P2P-CAPEX-2026-06','grn_delay','pending_investigation','none_required','overdue','Operations Director','2026-06-30',null,310000.00,'MRI coil import stuck at customs 45 days — investigation with customs broker ongoing, cost of capital rising'),
    ('P2P-CAPEX-2026-05','approval_bottleneck','approver_unavailable','escalate_to_approver','closed','Procurement Ops Lead','2026-05-25','2026-05-24',18000.00,'Alternate approver assigned during CFO travel — approval SLA restored'),
    ('P2P-ITHW-2026-06','invoice_match_mismatch','three_way_match_exception','update_vendor_master','in_progress','IT Infra Manager','2026-07-05',null,22000.00,'Vendor master GSTIN corrected for laptop supplier — monitoring next invoice cycle'),
    ('P2P-CONS-2026-06','budget_approval_pending','budget_code_missing','auto_route_approval','open','Finance Controller','2026-06-20',null,9000.00,'Consumables budget code missing on requisitions causing approval hold — auto-routing rule being configured')
  ) as q(cref, fc, rc, ca, cst, own, tcd, acd, imp, nt)
  join public.p2p_cycle_r3715 e
    on e.organization_id = v_org_id and e.cycle_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Cycle status distribution
create or replace function public.founder_r3715_cycle_status_rollup()
returns table(cycle_status text, cycles bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.p2p_cycle_r3715)
  select l.cycle_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.p2p_cycle_r3715 l
  group by l.cycle_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3715_cycle_status_rollup() from public, anon;
grant execute on function public.founder_r3715_cycle_status_rollup() to authenticated;

-- 2) Requesting-function scorecard
create or replace function public.founder_r3715_function_scorecard()
returns table(
  requesting_function text,
  total_cycles bigint,
  on_track bigint,
  slow bigint,
  bottlenecked bigint,
  broken bigint,
  avg_total_cycle_days numeric,
  avg_three_way_match_pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.requesting_function,
    count(*)::bigint,
    count(*) filter (where l.cycle_status in ('within_target','on_target'))::bigint,
    count(*) filter (where l.cycle_status = 'slow')::bigint,
    count(*) filter (where l.cycle_status = 'bottlenecked')::bigint,
    count(*) filter (where l.cycle_status = 'broken')::bigint,
    round(avg(l.total_cycle_days), 2),
    round(avg(l.three_way_match_pass_pct), 2)
  from public.p2p_cycle_r3715 l
  group by l.requesting_function
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3715_function_scorecard() from public, anon;
grant execute on function public.founder_r3715_function_scorecard() to authenticated;

-- 3) Stage class × cycle status matrix
create or replace function public.founder_r3715_stage_cycle_matrix()
returns table(stage_class text, cycle_status text, cycles bigint, avg_total_cycle_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.stage_class, l.cycle_status, count(*)::bigint,
    round(avg(l.total_cycle_days), 2)
  from public.p2p_cycle_r3715 l
  group by l.stage_class, l.cycle_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3715_stage_cycle_matrix() from public, anon;
grant execute on function public.founder_r3715_stage_cycle_matrix() to authenticated;

-- 4) Monthly cycle trend
create or replace function public.founder_r3715_monthly_cycle_trend()
returns table(
  period_month date,
  cycles bigint,
  avg_total_cycle_days numeric,
  avg_po_to_grn_days numeric,
  emergency_pos bigint,
  avg_three_way_match_pass_pct numeric
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
    round(avg(l.total_cycle_days), 2),
    round(avg(l.po_to_grn_days), 2),
    coalesce(sum(l.emergency_pos), 0)::bigint,
    round(avg(l.three_way_match_pass_pct), 2)
  from public.p2p_cycle_r3715 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3715_monthly_cycle_trend() from public, anon;
grant execute on function public.founder_r3715_monthly_cycle_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3715_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.cost_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.p2p_cycle_capa_actions_r3715 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3715_capa_status_board() from public, anon;
grant execute on function public.founder_r3715_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3715_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.p2p_cycle_capa_actions_r3715)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.cost_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.p2p_cycle_capa_actions_r3715 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3715_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3715_root_cause_pareto() to authenticated;

-- 7) Bottleneck digest by category
create or replace function public.founder_r3715_bottleneck_digest()
returns table(
  category text,
  cycles bigint,
  bottlenecked bigint,
  broken bigint,
  avg_po_to_grn_days numeric,
  avg_grn_to_invoice_match_days numeric
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
    count(*) filter (where l.cycle_status = 'bottlenecked')::bigint,
    count(*) filter (where l.cycle_status = 'broken')::bigint,
    round(avg(l.po_to_grn_days), 2),
    round(avg(l.grn_to_invoice_match_days), 2)
  from public.p2p_cycle_r3715 l
  group by l.category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3715_bottleneck_digest() from public, anon;
grant execute on function public.founder_r3715_bottleneck_digest() to authenticated;

-- 8) High-risk (broken/bottlenecked) queue
create or replace function public.founder_r3715_high_risk_queue()
returns table(
  category text,
  requesting_function text,
  cycle_ref text,
  period_month date,
  stage_class text,
  cycle_status text,
  total_cycle_days numeric,
  target_cycle_days numeric,
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
  select l.category, l.requesting_function, l.cycle_ref, l.period_month,
    l.stage_class, l.cycle_status, l.total_cycle_days, l.target_cycle_days, l.trend_dir, l.notes
  from public.p2p_cycle_r3715 l
  where l.cycle_status in ('bottlenecked','broken')
     or l.trend_dir = 'worsening'
     or l.total_cycle_days > l.target_cycle_days
  order by l.total_cycle_days desc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3715_high_risk_queue() from public, anon;
grant execute on function public.founder_r3715_high_risk_queue() to authenticated;
