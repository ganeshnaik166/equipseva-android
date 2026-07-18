-- Round 3245: Founder SaaS, Domain, SSL-Certificate & Software-License Renewal Cost Board
-- Founder business governance — asset type × vendor × owner team × billing cycle × seats × annual cost × renewal date × auto-renew × utilization × renewal decision × CAPA

-- =============================================================================
-- TABLE 1: saas_domain_ssl_license_r3245 — individual subscription / asset rows
-- =============================================================================
create table if not exists public.saas_domain_ssl_license_r3245 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_name text not null,
  asset_type text not null check (asset_type in (
    'saas_subscription','domain','ssl_certificate','software_license','api_plan'
  )),
  vendor text not null,
  owner_team text not null check (owner_team in (
    'engineering','ops','finance','sales','founder_office'
  )),
  billing_cycle text not null check (billing_cycle in (
    'monthly','annual','triennial'
  )),
  seats_or_units int not null,
  annual_cost_rupees numeric(12,2) not null,
  renewal_date date not null,
  auto_renew boolean not null,
  last_usage_review_date date,
  utilization_pct numeric(5,1),
  renewal_decision text not null check (renewal_decision in (
    'renew','renegotiate','downgrade','cancel','pending_review'
  )),
  criticality text not null check (criticality in (
    'business_critical','important','nice_to_have'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.saas_domain_ssl_license_r3245 enable row level security;

create index if not exists idx_saas_asset_r3245_org on public.saas_domain_ssl_license_r3245(organization_id);
create index if not exists idx_saas_asset_r3245_renewal on public.saas_domain_ssl_license_r3245(renewal_date);
create index if not exists idx_saas_asset_r3245_decision on public.saas_domain_ssl_license_r3245(renewal_decision);

-- =============================================================================
-- TABLE 2: saas_domain_ssl_license_capa_actions_r3245 — cost-optimization / risk CAPA
-- =============================================================================
create table if not exists public.saas_domain_ssl_license_capa_actions_r3245 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_id uuid not null references public.saas_domain_ssl_license_r3245(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'ssl_expiry_risk','domain_lapse_risk','unused_seats','duplicate_tooling',
    'auto_renew_price_hike','license_non_compliance','shadow_it_spend','missing_usage_review'
  )),
  root_cause text not null check (root_cause in (
    'no_renewal_calendar','owner_left_company','seat_overprovisioning','vendor_price_increase',
    'procurement_bypass','tool_overlap_unreviewed','pending_investigation','budget_review_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'set_renewal_reminder','reassign_owner','reduce_seats','renegotiate_contract',
    'consolidate_tools','cancel_subscription','enable_auto_renew','complete_usage_review','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  cost_impact text not null check (cost_impact in (
    'high_savings','moderate_savings','low_savings','risk_mitigation_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_savings_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.saas_domain_ssl_license_capa_actions_r3245 enable row level security;

create index if not exists idx_saas_capa_r3245_asset on public.saas_domain_ssl_license_capa_actions_r3245(asset_id);
create index if not exists idx_saas_capa_r3245_status on public.saas_domain_ssl_license_capa_actions_r3245(capa_status);

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

  -- 14 subscription / asset rows
  insert into public.saas_domain_ssl_license_r3245 (
    organization_id, asset_name, asset_type, vendor, owner_team,
    billing_cycle, seats_or_units, annual_cost_rupees, renewal_date, auto_renew,
    last_usage_review_date, utilization_pct, renewal_decision, criticality, notes
  )
  select v_org_id, q.name, q.atype, q.vendor, q.team,
    q.cycle, q.seats, q.cost, q.rdate::date, q.autor,
    q.lrev::date, q.util, q.rdec, q.crit, q.nt
  from (values
    ('Supabase Pro Plan','saas_subscription','Supabase Inc','engineering',
     'monthly',6,249000.00,'2026-08-01',true,
     '2026-06-15',92.0,'renew','business_critical','Core backend — prod plus staging projects'),
    ('equipseva.com domain','domain','GoDaddy India','founder_office',
     'annual',1,1499.00,'2026-09-12',true,
     '2026-05-10',100.0,'renew','business_critical','Primary customer-facing domain'),
    ('equipseva.in domain','domain','GoDaddy India','founder_office',
     'annual',1,899.00,'2026-07-25',false,
     null,100.0,'pending_review','important','Auto-renew off — 7 days to lapse, registrar account under ex-employee email'),
    ('*.equipseva.com wildcard SSL','ssl_certificate','DigiCert','engineering',
     'annual',1,24500.00,'2026-07-24',false,
     '2026-04-02',100.0,'renew','business_critical','Expires in 6 days — manual renewal, DNS validation ticket open'),
    ('payments.equipseva.com SSL','ssl_certificate','Sectigo','engineering',
     'annual',1,8900.00,'2026-10-18',true,
     '2026-06-01',100.0,'renew','business_critical','EV cert for payment gateway origin'),
    ('Google Workspace Business Standard','saas_subscription','Google Cloud India','ops',
     'annual',28,302400.00,'2027-01-05',true,
     '2026-06-20',96.0,'renew','business_critical','Email plus Drive for all staff'),
    ('Slack Pro','saas_subscription','Salesforce','ops',
     'monthly',28,218400.00,'2026-08-14',true,
     '2026-06-18',61.0,'renegotiate','important','11 seats inactive 60 plus days — trim at renewal'),
    ('Zoho Books','saas_subscription','Zoho Corp','finance',
     'annual',4,35400.00,'2026-11-02',true,
     '2026-05-28',88.0,'renew','business_critical','GST filings and AR ledger'),
    ('Freshdesk Growth','saas_subscription','Freshworks','ops',
     'annual',12,142800.00,'2026-09-30',true,
     '2026-03-11',44.0,'downgrade','important','Only 5 of 12 agent seats active — downgrade quoted'),
    ('JetBrains All Products Pack','software_license','JetBrains','engineering',
     'annual',8,172000.00,'2026-12-10',false,
     '2026-06-25',75.0,'renew','important','6 of 8 devs active weekly'),
    ('Figma Professional','saas_subscription','Figma Inc','engineering',
     'annual',5,74250.00,'2026-08-22',true,
     null,38.0,'downgrade','nice_to_have','No usage review since purchase — only 2 active editors'),
    ('Google Maps Platform API','api_plan','Google Cloud India','engineering',
     'monthly',1,384000.00,'2026-07-31',true,
     '2026-06-30',97.0,'renegotiate','business_critical','Volume discount discussion open with GCP account team'),
    ('MS Office LTSC 2024','software_license','Microsoft India','finance',
     'triennial',6,54000.00,'2028-03-15',false,
     '2026-02-14',82.0,'renew','important','Perpetual-style license for finance desktops'),
    ('Zoom Pro','saas_subscription','Zoom Video','sales',
     'monthly',10,132000.00,'2026-08-05',true,
     '2026-06-22',29.0,'cancel','nice_to_have','Google Meet covers need — duplicate tooling')
  ) as q(name, atype, vendor, team, cycle, seats, cost, rdate, autor, lrev, util, rdec, crit, nt);

  -- CAPA seed — attach to specific assets via asset name
  insert into public.saas_domain_ssl_license_capa_actions_r3245 (
    organization_id, asset_id, finding_category, root_cause, corrective_action,
    capa_status, cost_impact, target_closure_date, actual_closure_date,
    estimated_savings_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.tcd::date, q.acd::date,
    q.sav, q.nt
  from (values
    ('*.equipseva.com wildcard SSL','ssl_expiry_risk','no_renewal_calendar','set_renewal_reminder',
     'escalated','risk_mitigation_only','2026-07-22',null,0.00,'Wildcard cert expires 24 Jul — renewal PO raised, DNS validation pending'),
    ('equipseva.in domain','domain_lapse_risk','owner_left_company','reassign_owner',
     'in_progress','risk_mitigation_only','2026-07-23',null,0.00,'Registrar account on ex-employee email — transfer to founder_office initiated'),
    ('Slack Pro','unused_seats','seat_overprovisioning','reduce_seats',
     'open','moderate_savings','2026-08-10',null,85800.00,'11 inactive seats — trim to 17 at monthly renewal'),
    ('Freshdesk Growth','unused_seats','seat_overprovisioning','reduce_seats',
     'verification_pending','high_savings','2026-09-25',null,83300.00,'Downgrade to 5-agent plan quoted by Freshworks — verify ticket routing'),
    ('Zoom Pro','duplicate_tooling','tool_overlap_unreviewed','cancel_subscription',
     'closed','high_savings','2026-07-10','2026-07-08',132000.00,'Cancelled — Google Meet standardized company-wide'),
    ('Figma Professional','missing_usage_review','budget_review_backlog','complete_usage_review',
     'overdue','low_savings','2026-07-05',null,44550.00,'Usage review past due — 3 editor seats to drop'),
    ('Google Maps Platform API','auto_renew_price_hike','vendor_price_increase','renegotiate_contract',
     'in_progress','moderate_savings','2026-08-15',null,57600.00,'GCP committed-use discount negotiation in flight')
  ) as q(name, fc, rc, ca, cst, ci, tcd, acd, sav, nt)
  join public.saas_domain_ssl_license_r3245 e
    on e.organization_id = v_org_id and e.asset_name = q.name;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Renewal decision distribution
create or replace function public.founder_r3245_renewal_decision_rollup()
returns table(renewal_decision text, assets bigint, total_annual_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.saas_domain_ssl_license_r3245)
  select l.renewal_decision, count(*)::bigint,
         coalesce(sum(l.annual_cost_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.saas_domain_ssl_license_r3245 l
  group by l.renewal_decision
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3245_renewal_decision_rollup() from public, anon;
grant execute on function public.founder_r3245_renewal_decision_rollup() to authenticated;

-- 2) Owner-team spend scorecard
create or replace function public.founder_r3245_owner_team_scorecard()
returns table(
  owner_team text,
  total_assets bigint,
  business_critical bigint,
  auto_renew_on bigint,
  low_utilization bigint,
  cancel_or_downgrade bigint,
  avg_utilization_pct numeric,
  total_annual_cost_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.owner_team,
    count(*)::bigint,
    count(*) filter (where l.criticality = 'business_critical')::bigint,
    count(*) filter (where l.auto_renew)::bigint,
    count(*) filter (where l.utilization_pct is not null and l.utilization_pct < 50)::bigint,
    count(*) filter (where l.renewal_decision in ('cancel','downgrade'))::bigint,
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.annual_cost_rupees),0)::numeric
  from public.saas_domain_ssl_license_r3245 l
  group by l.owner_team
  order by sum(l.annual_cost_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3245_owner_team_scorecard() from public, anon;
grant execute on function public.founder_r3245_owner_team_scorecard() to authenticated;

-- 3) Asset type × billing cycle matrix
create or replace function public.founder_r3245_asset_type_billing_matrix()
returns table(asset_type text, billing_cycle text, assets bigint, total_annual_cost_rupees numeric, avg_utilization_pct numeric, auto_renew_on bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_type, l.billing_cycle, count(*)::bigint,
    coalesce(sum(l.annual_cost_rupees),0)::numeric,
    round(avg(l.utilization_pct), 1),
    count(*) filter (where l.auto_renew)::bigint
  from public.saas_domain_ssl_license_r3245 l
  group by l.asset_type, l.billing_cycle
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3245_asset_type_billing_matrix() from public, anon;
grant execute on function public.founder_r3245_asset_type_billing_matrix() to authenticated;

-- 4) Renewal date trend (upcoming renewal load)
create or replace function public.founder_r3245_renewal_date_trend()
returns table(renewal_date date, assets bigint, total_annual_cost_rupees numeric, auto_renew_on bigint, business_critical bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.renewal_date,
    count(*)::bigint,
    coalesce(sum(l.annual_cost_rupees),0)::numeric,
    count(*) filter (where l.auto_renew)::bigint,
    count(*) filter (where l.criticality = 'business_critical')::bigint
  from public.saas_domain_ssl_license_r3245 l
  group by l.renewal_date
  order by l.renewal_date asc;
end;
$$;

revoke execute on function public.founder_r3245_renewal_date_trend() from public, anon;
grant execute on function public.founder_r3245_renewal_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3245_capa_status_board()
returns table(capa_status text, findings bigint, avg_savings_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_savings_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.saas_domain_ssl_license_capa_actions_r3245 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3245_capa_status_board() from public, anon;
grant execute on function public.founder_r3245_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3245_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_savings_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.saas_domain_ssl_license_capa_actions_r3245)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_savings_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.saas_domain_ssl_license_capa_actions_r3245 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3245_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3245_root_cause_pareto() to authenticated;

-- 7) Cost impact digest
create or replace function public.founder_r3245_cost_impact_digest()
returns table(cost_impact text, findings bigint, open_findings bigint, total_savings_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.cost_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_savings_rupees),0)::numeric
  from public.saas_domain_ssl_license_capa_actions_r3245 c
  group by c.cost_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3245_cost_impact_digest() from public, anon;
grant execute on function public.founder_r3245_cost_impact_digest() to authenticated;

-- 8) High-risk renewal queue (top individual concerns)
create or replace function public.founder_r3245_high_risk_queue()
returns table(
  asset_name text,
  asset_type text,
  vendor text,
  owner_team text,
  renewal_date date,
  annual_cost_rupees numeric,
  utilization_pct numeric,
  renewal_decision text,
  criticality text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_name, l.asset_type, l.vendor, l.owner_team, l.renewal_date,
    l.annual_cost_rupees, l.utilization_pct, l.renewal_decision, l.criticality, l.notes
  from public.saas_domain_ssl_license_r3245 l
  where l.renewal_decision in ('pending_review','renegotiate','downgrade','cancel')
     or (l.utilization_pct is not null and l.utilization_pct < 50)
     or (l.criticality = 'business_critical' and not l.auto_renew)
     or l.last_usage_review_date is null
  order by l.renewal_date asc, l.asset_name;
end;
$$;

revoke execute on function public.founder_r3245_high_risk_queue() from public, anon;
grant execute on function public.founder_r3245_high_risk_queue() to authenticated;
