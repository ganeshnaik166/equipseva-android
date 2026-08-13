-- Round 3726: Founder MRP / Price-List Version-Control & Compliance Board
-- Commercial price-list/MRP version control — active vs superseded price lists, quotes issued
-- against stale lists, unauthorized discount-beyond-list incidents, per product category.
-- Distinct from any QMS controlled-document/SOP board (that is quality-management documents,
-- not commercial pricing) and from any per-deal discount-approval-queue board (that is a
-- single-deal approval queue, not list-version governance).

-- =============================================================================
-- TABLE 1: price_list_r3726 — per-price-list per-month version-control & compliance facts
-- =============================================================================
create table if not exists public.price_list_r3726 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  price_list_ref text not null,
  product_category text not null,
  period_month date not null,
  current_version text not null,
  effective_date date,
  superseded_date date,
  quotes_on_stale_list int,
  unauthorized_discount_incidents int,
  mrp_variance_pct numeric,
  gst_slab_correct boolean not null,
  approval_on_file boolean not null,
  distribution_channels_notified int,
  list_class text not null check (list_class in (
    'new_equipment','spare_parts','amc_service','accessories','consumables'
  )),
  control_status text not null check (control_status in (
    'current_active','superseded_in_use','pending_approval','unauthorized_variance','under_revision'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.price_list_r3726 enable row level security;

create index if not exists idx_price_list_r3726_org on public.price_list_r3726(organization_id);
create index if not exists idx_price_list_r3726_month on public.price_list_r3726(period_month);
create index if not exists idx_price_list_r3726_status on public.price_list_r3726(control_status);

-- =============================================================================
-- TABLE 2: price_list_capa_actions_r3726 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.price_list_capa_actions_r3726 (
  id uuid primary key default gen_random_uuid(),
  price_list_id uuid references public.price_list_r3726(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.price_list_capa_actions_r3726 enable row level security;

create index if not exists idx_price_list_capa_r3726_plist on public.price_list_capa_actions_r3726(price_list_id);
create index if not exists idx_price_list_capa_r3726_status on public.price_list_capa_actions_r3726(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Control-status distribution
create or replace function public.founder_r3726_control_status_rollup()
returns table(control_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.price_list_r3726)
  select l.control_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.price_list_r3726 l
  group by l.control_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3726_control_status_rollup() from public, anon;
grant execute on function public.founder_r3726_control_status_rollup() to authenticated;

-- 2) Product-category scorecard
create or replace function public.founder_r3726_product_category_scorecard()
returns table(
  product_category text,
  periods bigint,
  total_quotes_on_stale_list bigint,
  total_unauthorized_discount_incidents bigint,
  avg_mrp_variance_pct numeric,
  gst_slab_correct_count bigint,
  approval_on_file_count bigint,
  avg_distribution_channels_notified numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_category,
    count(*)::bigint,
    coalesce(sum(l.quotes_on_stale_list),0)::bigint,
    coalesce(sum(l.unauthorized_discount_incidents),0)::bigint,
    round(avg(l.mrp_variance_pct), 2),
    count(*) filter (where l.gst_slab_correct = true)::bigint,
    count(*) filter (where l.approval_on_file = true)::bigint,
    round(avg(l.distribution_channels_notified), 1)
  from public.price_list_r3726 l
  group by l.product_category
  order by coalesce(sum(l.quotes_on_stale_list),0) desc;
end;
$$;

revoke all on function public.founder_r3726_product_category_scorecard() from public, anon;
grant execute on function public.founder_r3726_product_category_scorecard() to authenticated;

-- 3) List-class x control-status matrix
create or replace function public.founder_r3726_list_class_status_matrix()
returns table(list_class text, control_status text, entries bigint, total_quotes_on_stale_list bigint, avg_mrp_variance_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.list_class, l.control_status, count(*)::bigint,
    coalesce(sum(l.quotes_on_stale_list),0)::bigint,
    round(avg(l.mrp_variance_pct), 2)
  from public.price_list_r3726 l
  group by l.list_class, l.control_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3726_list_class_status_matrix() from public, anon;
grant execute on function public.founder_r3726_list_class_status_matrix() to authenticated;

-- 4) Monthly stale-list trend
create or replace function public.founder_r3726_monthly_stale_list_trend()
returns table(
  period_month date,
  entries bigint,
  total_quotes_on_stale_list bigint,
  total_unauthorized_discount_incidents bigint,
  avg_mrp_variance_pct numeric,
  worsening_entries bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.quotes_on_stale_list),0)::bigint,
    coalesce(sum(l.unauthorized_discount_incidents),0)::bigint,
    round(avg(l.mrp_variance_pct), 2),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.price_list_r3726 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3726_monthly_stale_list_trend() from public, anon;
grant execute on function public.founder_r3726_monthly_stale_list_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3726_capa_status_board()
returns table(capa_status text, actions bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.price_list_capa_actions_r3726 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3726_capa_status_board() from public, anon;
grant execute on function public.founder_r3726_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3726_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.price_list_capa_actions_r3726)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.price_list_capa_actions_r3726 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3726_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3726_root_cause_pareto() to authenticated;

-- 7) Unauthorized-discount digest
create or replace function public.founder_r3726_unauthorized_discount_digest()
returns table(
  product_category text,
  entries_with_incidents bigint,
  total_unauthorized_discount_incidents bigint,
  avg_mrp_variance_pct numeric,
  approval_on_file_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_category,
    count(*)::bigint,
    coalesce(sum(l.unauthorized_discount_incidents),0)::bigint,
    round(avg(l.mrp_variance_pct), 2),
    count(*) filter (where l.approval_on_file = true)::bigint
  from public.price_list_r3726 l
  where l.unauthorized_discount_incidents > 0
  group by l.product_category
  order by coalesce(sum(l.unauthorized_discount_incidents),0) desc;
end;
$$;

revoke all on function public.founder_r3726_unauthorized_discount_digest() from public, anon;
grant execute on function public.founder_r3726_unauthorized_discount_digest() to authenticated;

-- 8) High-risk price-list queue (unauthorized variance, superseded-in-use, worsening trend)
create or replace function public.founder_r3726_high_risk_queue()
returns table(
  price_list_ref text,
  product_category text,
  period_month date,
  list_class text,
  control_status text,
  quotes_on_stale_list int,
  unauthorized_discount_incidents int,
  mrp_variance_pct numeric,
  approval_on_file boolean,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.price_list_ref, l.product_category, l.period_month, l.list_class, l.control_status,
    l.quotes_on_stale_list, l.unauthorized_discount_incidents, l.mrp_variance_pct,
    l.approval_on_file, l.trend_dir, l.notes
  from public.price_list_r3726 l
  where l.control_status in ('unauthorized_variance','superseded_in_use')
     or l.trend_dir = 'worsening'
     or coalesce(l.unauthorized_discount_incidents,0) > 0
  order by coalesce(l.unauthorized_discount_incidents,0) desc, coalesce(l.quotes_on_stale_list,0) desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3726_high_risk_queue() from public, anon;
grant execute on function public.founder_r3726_high_risk_queue() to authenticated;

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

  -- 16 price-list version-control rows
  insert into public.price_list_r3726 (
    organization_id, price_list_ref, product_category, period_month, current_version,
    effective_date, superseded_date, quotes_on_stale_list, unauthorized_discount_incidents,
    mrp_variance_pct, gst_slab_correct, approval_on_file, distribution_channels_notified,
    list_class, control_status, trend_dir, notes
  )
  select v_org_id, q.plr, q.pcat, q.pm::date, q.cver,
    q.efd::date, q.sfd::date, q.qos::int, q.udi::int,
    q.mvp::numeric, q.gsc, q.aof, q.dcn::int,
    q.lcls, q.cstat, q.tdir, q.nt
  from (values
    ('PL-EXC-2607-V4','Excavators','2026-07-01','V4.2','2026-07-01',null,
     0,0,0.5,true,true,6,
     'new_equipment','current_active','stable',
     'Latest excavator price list active across all zones, GST slab verified'),
    ('PL-EXC-2606-V3','Excavators','2026-06-01','V3.8','2026-05-15','2026-06-30',
     4,1,1.2,true,true,6,
     'new_equipment','superseded_in_use','worsening',
     'Old V3.8 still quoted by 2 dealers post cutover'),
    ('PL-CRN-2607-V5','Mobile Cranes','2026-07-01','V5.1','2026-07-05',null,
     0,0,0.3,true,false,5,
     'new_equipment','pending_approval','stable',
     'Finance sign-off pending before publishing to channel'),
    ('PL-CRN-2606-V4','Mobile Cranes','2026-06-01','V4.6','2026-06-01',null,
     0,3,4.8,false,true,5,
     'new_equipment','unauthorized_variance','worsening',
     'Three deals booked below floor price without approval'),
    ('PL-GEN-2607-V6','Diesel Generators','2026-07-01','V6.0',null,null,
     0,0,0.0,true,true,7,
     'new_equipment','under_revision','stable',
     'Revising for new emission-norm SKUs — draft with product team'),
    ('PL-SPB-2607-V9','Spare Parts - Hydraulics','2026-07-01','V9.3','2026-07-01',null,
     1,0,0.8,true,true,8,
     'spare_parts','current_active','improving',
     'Hydraulics spares list refreshed post vendor rate revision'),
    ('PL-SPB-2606-V8','Spare Parts - Hydraulics','2026-06-01','V8.9','2026-05-01','2026-06-30',
     9,2,2.5,true,true,8,
     'spare_parts','superseded_in_use','worsening',
     'Branch billing team still on V8.9 for 9 quotes this month'),
    ('PL-SPE-2607-V5','Spare Parts - Engine','2026-07-01','V5.4','2026-07-10',null,
     0,0,0.4,true,false,6,
     'spare_parts','pending_approval','stable',
     'Engine spares revision awaiting CFO approval before go-live'),
    ('PL-SPE-2606-V4','Spare Parts - Engine','2026-06-01','V4.9','2026-06-01',null,
     0,5,6.2,false,true,6,
     'spare_parts','unauthorized_variance','worsening',
     'Five branch quotes issued below MRP without discount sign-off'),
    ('PL-AMC-2607-V3','AMC - Cranes & Excavators','2026-07-01','V3.1','2026-07-01',null,
     0,0,0.2,true,true,5,
     'amc_service','current_active','stable',
     'AMC service price list current — renewal quotes aligned'),
    ('PL-AMC-2606-V2','AMC - Compactors','2026-06-01','V2.7','2026-05-01','2026-06-15',
     5,1,1.9,true,true,5,
     'amc_service','superseded_in_use','worsening',
     'Renewal desk quoted 5 customers off the old AMC rate card'),
    ('PL-ACC-2607-V4','Accessories - Buckets & Attachments','2026-07-01','V4.4',null,null,
     0,0,0.0,true,false,4,
     'accessories','under_revision','stable',
     'Attachment pricing under revision for new bucket variants'),
    ('PL-ACC-2606-V3','Accessories - Buckets & Attachments','2026-06-01','V3.6','2026-06-05',null,
     0,2,3.4,false,true,4,
     'accessories','unauthorized_variance','worsening',
     'Two dealer quotes bundled attachments below approved floor'),
    ('PL-CON-2607-V6','Consumables - Filters & Lubricants','2026-07-01','V6.2','2026-07-01',null,
     2,0,1.0,true,true,9,
     'consumables','current_active','improving',
     'Consumables list current — GST slab corrected after audit'),
    ('PL-CON-2606-V5','Consumables - Filters & Lubricants','2026-06-01','V5.8','2026-05-01','2026-06-20',
     7,0,1.5,true,true,9,
     'consumables','superseded_in_use','stable',
     'Old filter price list still referenced by 7 stale quotes'),
    ('PL-CMX-2607-V4','Concrete Equipment','2026-07-01','V4.0','2026-07-08',null,
     0,1,2.1,false,false,5,
     'new_equipment','pending_approval','worsening',
     'New concrete-mixer list awaiting approval; one quote used draft discount')
  ) as q(plr, pcat, pm, cver, efd, sfd, qos, udi, mvp, gsc, aof, dcn, lcls, cstat, tdir, nt);

  -- CAPA seed — attach to specific price-list rows via price_list_ref
  insert into public.price_list_capa_actions_r3726 (
    price_list_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('PL-EXC-2606-V3','Sales team not notified of price-list cutover date',
     'Push automated cutover alert to all branch billing desks','in_progress',
     'Rakesh Verma (Pricing Desk)','2026-08-20',null,
     'Two dealers still quoting V3.8 — cutover alert being rolled out to CRM'),
    ('PL-CRN-2606-V4','Regional sales head approved discounts beyond delegated authority',
     'Restrict discount approval workflow to finance sign-off above 3%','open',
     'Meera Krishnan (Finance Controller)','2026-08-10',null,
     'Three unauthorized crane deals under review — discount workflow being tightened'),
    ('PL-SPB-2606-V8','Branch billing team using cached PDF price list instead of portal',
     'Disable manual PDF distribution; enforce portal-only quoting','overdue',
     'Suresh Pillai (Spares Ops)','2026-07-25',null,
     'Nine stale-list quotes traced to one branch — PDF access revoked, monitoring'),
    ('PL-SPE-2606-V4','Engine-spares floor price not synced to dealer portal after revision',
     'Automate floor-price sync job on every price-list publish','in_progress',
     'Rakesh Verma (Pricing Desk)','2026-08-05',null,
     'Five below-MRP quotes flagged — sync automation in UAT'),
    ('PL-AMC-2606-V2','AMC renewal desk referencing archived rate card in shared drive',
     'Remove archived rate cards from shared drive; link portal-only access','closed',
     'Anita Deshmukh (AMC Ops)','2026-07-10','2026-07-08',
     'Archived rate card removed — renewal desk confirmed portal-only access'),
    ('PL-ACC-2606-V3','Dealer bundled attachment discount without floor-price validation',
     'Add floor-price validation check to bundle-quote tool','open',
     'Rakesh Verma (Pricing Desk)','2026-08-15',null,
     'Two bundled quotes below floor — validation check being added to quote tool'),
    ('PL-CON-2606-V5','Consumables price list update delayed past effective date communication',
     'Shift consumables list publish two weeks ahead of effective date','in_progress',
     'Suresh Pillai (Spares Ops)','2026-08-12',null,
     'Seven stale quotes traced to delayed rollout — publish lead-time being extended'),
    ('PL-CMX-2607-V4','Concrete-equipment quote issued using draft price list before approval',
     'Lock draft price lists from quote-tool selection until approved','overdue',
     'Meera Krishnan (Finance Controller)','2026-07-30',null,
     'One draft-discount quote flagged — quote-tool lock pending IT deployment')
  ) as q(plr, rc, ca, cst, ownr, tcd, acd, nt)
  join public.price_list_r3726 e
    on e.organization_id = v_org_id and e.price_list_ref = q.plr;
end;
$seed$;
