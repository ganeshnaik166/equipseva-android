-- Round 3743: Founder Corporate Gifting / Promotional-Merchandise Spend Board
-- Corporate gifting & promo-merch governance — campaign × merchandise category × period ×
-- budget vs actual spend × units ordered/distributed/remaining inventory × approval-on-file ×
-- vendor × cost per unit × event class × spend status × CAPA

-- =============================================================================
-- TABLE 1: corp_gifting_r3743 — per-campaign gifting/merchandise spend facts
-- =============================================================================
create table if not exists public.corp_gifting_r3743 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  campaign_name text not null,
  merchandise_category text not null,
  period_month date not null,
  budget_rupees numeric(12,2),
  actual_spend_rupees numeric(12,2),
  units_ordered int,
  units_distributed int,
  units_remaining_inventory int,
  approval_on_file boolean not null,
  vendor_name text,
  cost_per_unit_rupees numeric,
  event_class text not null check (event_class in (
    'conference_giveaway','client_appreciation','employee_swag','onboarding_kit','festival_gifting'
  )),
  spend_status text not null check (spend_status in (
    'within_budget','over_budget','pending_approval','inventory_excess','unaccounted_variance'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.corp_gifting_r3743 enable row level security;

create index if not exists idx_corp_gifting_r3743_org on public.corp_gifting_r3743(organization_id);
create index if not exists idx_corp_gifting_r3743_month on public.corp_gifting_r3743(period_month);
create index if not exists idx_corp_gifting_r3743_status on public.corp_gifting_r3743(spend_status);

-- =============================================================================
-- TABLE 2: corp_gifting_capa_actions_r3743 — CAPA & spend-governance actions
-- =============================================================================
create table if not exists public.corp_gifting_capa_actions_r3743 (
  id uuid primary key default gen_random_uuid(),
  gifting_log_id uuid references public.corp_gifting_r3743(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.corp_gifting_capa_actions_r3743 enable row level security;

create index if not exists idx_corp_gifting_capa_r3743_log on public.corp_gifting_capa_actions_r3743(gifting_log_id);
create index if not exists idx_corp_gifting_capa_r3743_status on public.corp_gifting_capa_actions_r3743(capa_status);

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

  -- 16 corporate gifting / promo-merchandise spend rows
  insert into public.corp_gifting_r3743 (
    organization_id, campaign_name, merchandise_category, period_month,
    budget_rupees, actual_spend_rupees, units_ordered, units_distributed,
    units_remaining_inventory, approval_on_file, vendor_name, cost_per_unit_rupees,
    event_class, spend_status, trend_dir, notes
  )
  select v_org_id, q.camp, q.cat, q.pm::date,
    q.bud::numeric, q.act::numeric, q.uo::int, q.ud::int,
    q.uri::int, q.appr, q.vend, q.cpu::numeric,
    q.ecl, q.sst, q.trd, q.nt
  from (values
    ('Excon 2026 Booth Giveaway','Branded Tech Accessories','2026-07-01',
     450000,438000,3000,2760,240,true,'Printwell Merchandising','146.00',
     'conference_giveaway','within_budget','stable','Power banks & USB drives — booth traffic count matched distribution'),
    ('Client Diwali Hampers FY26','Festive Hampers','2026-07-01',
     900000,1120000,600,600,0,true,'Ferns N Petals Corporate','1866.67',
     'client_appreciation','over_budget','worsening','Premium hamper upgrade mid-cycle without revised PO'),
    ('New-Hire Onboarding Kit Q2','Onboarding Kit','2026-05-01',
     280000,265000,400,388,12,true,'Officewear Solutions','683.00',
     'onboarding_kit','within_budget','improving','Backpack + notebook + bottle kit — steady issue rate'),
    ('Annual Day Employee Swag','Apparel','2026-06-01',
     620000,598000,1200,1140,60,true,'ThreadCraft Apparel','498.33',
     'employee_swag','within_budget','stable','Polo shirts sized S-XXL — minor overrun in XL size'),
    ('Bauma Conexpo Delegate Kit','Branded Tech Accessories','2026-06-01',
     510000,612000,500,500,0,false,'Printwell Merchandising','1224.00',
     'conference_giveaway','pending_approval','worsening','Invoice raised before purchase-order sign-off — finance holding payment'),
    ('Top-Dealer Appreciation Boxes','Premium Gift Boxes','2026-07-01',
     780000,742000,150,148,2,true,'Ferns N Petals Corporate','5013.51',
     'client_appreciation','within_budget','stable','Curated boxes for top 150 dealers by volume'),
    ('Onboarding Kit Refresh Q3','Onboarding Kit','2026-07-01',
     300000,196000,420,210,210,true,'Officewear Solutions','933.33',
     'onboarding_kit','inventory_excess','worsening','Hiring slowdown left half the ordered kits unissued in warehouse'),
    ('Ganesh Chaturthi Client Gifting','Festive Hampers','2026-06-01',
     520000,505000,350,350,0,true,'Sweets & Spice Corporate Gifting','1442.86','festival_gifting','within_budget','stable','Modak boxes & dry-fruit hampers — dispatched before festival week'),
    ('Republic Day Swag Drive','Apparel','2026-05-01',
     180000,231000,900,900,0,true,'ThreadCraft Apparel','256.67',
     'employee_swag','over_budget','worsening','Tricolor scarves reprinted after first batch color mismatch'),
    ('Regional Sales Kickoff Giveaway','Branded Tech Accessories','2026-05-01',
     340000,318000,600,540,60,true,'Printwell Merchandising','530.00',
     'conference_giveaway','within_budget','improving','Bluetooth speakers — regional distribution slightly behind schedule'),
    ('Key-Account Anniversary Gifts','Premium Gift Boxes','2026-05-01',
     410000,455000,80,80,0,false,'Godiva Corporate Gifting','5687.50',
     'client_appreciation','unaccounted_variance','worsening','Vendor billed 80 boxes but only 72 delivery acknowledgements on file'),
    ('Monsoon Onboarding Kit','Onboarding Kit','2026-06-01',
     260000,248000,300,296,4,true,'Officewear Solutions','837.84',
     'onboarding_kit','within_budget','stable','Rain jackets added to standard field-engineer kit'),
    ('Service Team Winter Swag','Apparel','2026-07-01',
     390000,142000,700,210,490,true,'ThreadCraft Apparel','676.19',
     'employee_swag','inventory_excess','worsening','Fleece jackets ordered ahead of season — distribution lagging badly'),
    ('EXCON Delegate Lanyard Reorder','Branded Tech Accessories','2026-06-01',
     95000,101000,2000,1950,50,false,'Printwell Merchandising','51.79',
     'conference_giveaway','pending_approval','stable','Emergency reorder mid-event — PO backdated, awaiting sign-off'),
    ('Onam Client Hampers South Zone','Festive Hampers','2026-07-01',
     360000,347000,280,278,2,true,'Sweets & Spice Corporate Gifting','1248.20','festival_gifting','within_budget','improving','Regional zone hampers — tighter vendor SLA than last cycle'),
    ('Distributor Loyalty Gift Boxes','Premium Gift Boxes','2026-06-01',
     560000,590000,110,102,8,true,'Godiva Corporate Gifting','5785.71',
     'client_appreciation','unaccounted_variance','worsening','8 boxes unaccounted between vendor dispatch and warehouse GRN')
  ) as q(camp, cat, pm, bud, act, uo, ud, uri, appr, vend, cpu, ecl, sst, trd, nt);

  -- CAPA seed — attach to specific campaigns via campaign_name
  insert into public.corp_gifting_capa_actions_r3743 (
    gifting_log_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Client Diwali Hampers FY26','Scope change mid-campaign without revised approval','Institute mandatory revised-PO sign-off before vendor upgrade','in_progress','Marketing Ops Lead','2026-08-25',null,'Approval workflow being retrofitted to flag hamper-tier upgrades'),
    ('Bauma Conexpo Delegate Kit','Invoice raised ahead of purchase-order approval','Enforce PO-before-invoice policy with finance gate','open','Procurement Manager','2026-08-30',null,'Finance holding payment pending backdated approval review'),
    ('Onboarding Kit Refresh Q3','Order volume not aligned to actual hiring pipeline','Tie kit order quantity to rolling headcount forecast','open','HR Ops Lead','2026-09-05',null,'210 kits sitting in warehouse — reforecast in progress'),
    ('Republic Day Swag Drive','Vendor print quality control gap causing reprint','Add pre-dispatch quality sign-off sample to vendor SLA','closed','Brand Manager','2026-06-20','2026-06-18','Reprint absorbed by vendor at 50% cost after escalation'),
    ('Key-Account Anniversary Gifts','Delivery acknowledgement not reconciled against vendor invoice','Require signed delivery acknowledgement before invoice clearance','in_progress','Finance Controller','2026-08-28',null,'8-unit variance under investigation with vendor and warehouse'),
    ('Service Team Winter Swag','Seasonal ordering not synced with distribution capacity','Stagger seasonal swag dispatch across regional depots','overdue','Field Ops Manager','2026-08-05',null,'490 units still in inventory — dispatch plan overdue by a week'),
    ('EXCON Delegate Lanyard Reorder','Emergency on-site reorder bypassed standard approval','Pre-authorize a contingency reorder buffer for future events','open','Events Manager','2026-08-22',null,'Backdated PO awaiting finance sign-off before vendor payment'),
    ('Distributor Loyalty Gift Boxes','Discrepancy between vendor dispatch count and warehouse GRN','Reconcile dispatch-to-GRN counts before vendor payment release','in_progress','Warehouse Supervisor','2026-08-31',null,'8-box gap traced to possible mislabeled carton at vendor end')
  ) as q(camp, rc, ca, cst, ownr, tcd, acd, nt)
  join public.corp_gifting_r3743 e
    on e.organization_id = v_org_id and e.campaign_name = q.camp;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Spend-status distribution
create or replace function public.founder_r3743_spend_status_rollup()
returns table(spend_status text, campaigns bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.corp_gifting_r3743)
  select l.spend_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.corp_gifting_r3743 l
  group by l.spend_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3743_spend_status_rollup() from public, anon;
grant execute on function public.founder_r3743_spend_status_rollup() to authenticated;

-- 2) Merchandise category scorecard
create or replace function public.founder_r3743_merchandise_category_scorecard()
returns table(
  merchandise_category text,
  campaigns bigint,
  total_budget_rupees numeric,
  total_actual_spend_rupees numeric,
  over_budget_campaigns bigint,
  total_units_ordered bigint,
  total_units_distributed bigint,
  total_units_remaining_inventory bigint,
  avg_cost_per_unit_rupees numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.merchandise_category,
    count(*)::bigint,
    coalesce(sum(l.budget_rupees),0)::numeric,
    coalesce(sum(l.actual_spend_rupees),0)::numeric,
    count(*) filter (where l.spend_status = 'over_budget')::bigint,
    coalesce(sum(l.units_ordered),0)::bigint,
    coalesce(sum(l.units_distributed),0)::bigint,
    coalesce(sum(l.units_remaining_inventory),0)::bigint,
    round(avg(l.cost_per_unit_rupees), 2)
  from public.corp_gifting_r3743 l
  group by l.merchandise_category
  order by coalesce(sum(l.actual_spend_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3743_merchandise_category_scorecard() from public, anon;
grant execute on function public.founder_r3743_merchandise_category_scorecard() to authenticated;

-- 3) Event-class × spend-status matrix
create or replace function public.founder_r3743_event_class_status_matrix()
returns table(event_class text, spend_status text, campaigns bigint, total_actual_spend_rupees numeric, approval_missing bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.event_class, l.spend_status, count(*)::bigint,
    coalesce(sum(l.actual_spend_rupees),0)::numeric,
    count(*) filter (where l.approval_on_file = false)::bigint
  from public.corp_gifting_r3743 l
  group by l.event_class, l.spend_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3743_event_class_status_matrix() from public, anon;
grant execute on function public.founder_r3743_event_class_status_matrix() to authenticated;

-- 4) Monthly spend trend
create or replace function public.founder_r3743_monthly_spend_trend()
returns table(period_month date, campaigns bigint, total_budget_rupees numeric, total_actual_spend_rupees numeric, variance_rupees numeric, worsening_campaigns bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.budget_rupees),0)::numeric,
    coalesce(sum(l.actual_spend_rupees),0)::numeric,
    coalesce(sum(l.actual_spend_rupees - l.budget_rupees),0)::numeric,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.corp_gifting_r3743 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3743_monthly_spend_trend() from public, anon;
grant execute on function public.founder_r3743_monthly_spend_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3743_capa_status_board()
returns table(capa_status text, actions bigint, overdue_flag bigint, closed_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint,
    count(*) filter (where c.capa_status = 'closed')::bigint
  from public.corp_gifting_capa_actions_r3743 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3743_capa_status_board() from public, anon;
grant execute on function public.founder_r3743_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3743_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.corp_gifting_capa_actions_r3743 where root_cause is not null)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.corp_gifting_capa_actions_r3743 c
  where c.root_cause is not null
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3743_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3743_root_cause_pareto() to authenticated;

-- 7) Inventory variance digest
create or replace function public.founder_r3743_inventory_variance_digest()
returns table(
  campaign_name text,
  merchandise_category text,
  period_month date,
  units_ordered int,
  units_distributed int,
  units_remaining_inventory int,
  spend_status text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.campaign_name, l.merchandise_category, l.period_month,
    l.units_ordered, l.units_distributed, l.units_remaining_inventory,
    l.spend_status, l.notes
  from public.corp_gifting_r3743 l
  where l.spend_status in ('inventory_excess','unaccounted_variance')
     or (l.units_ordered is not null and l.units_ordered > 0
         and l.units_remaining_inventory is not null
         and l.units_remaining_inventory::numeric / l.units_ordered::numeric >= 0.15)
  order by l.units_remaining_inventory desc;
end;
$$;

revoke all on function public.founder_r3743_inventory_variance_digest() from public, anon;
grant execute on function public.founder_r3743_inventory_variance_digest() to authenticated;

-- 8) High-risk spend queue
create or replace function public.founder_r3743_high_risk_queue()
returns table(
  campaign_name text,
  merchandise_category text,
  event_class text,
  period_month date,
  spend_status text,
  budget_rupees numeric,
  actual_spend_rupees numeric,
  approval_on_file boolean,
  vendor_name text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.campaign_name, l.merchandise_category, l.event_class, l.period_month,
    l.spend_status, l.budget_rupees, l.actual_spend_rupees, l.approval_on_file,
    l.vendor_name, l.notes
  from public.corp_gifting_r3743 l
  where l.spend_status in ('over_budget','pending_approval','unaccounted_variance')
     or l.approval_on_file = false
  order by (l.actual_spend_rupees - coalesce(l.budget_rupees,0)) desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3743_high_risk_queue() from public, anon;
grant execute on function public.founder_r3743_high_risk_queue() to authenticated;
