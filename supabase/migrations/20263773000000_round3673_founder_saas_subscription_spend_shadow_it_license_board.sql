-- Round 3673: Founder SaaS-Subscription Spend / Shadow-IT License Board
-- SaaS governance — app × owner department × period × seats licensed/active × utilization × annual spend × cost-per-active-seat × renewal runway × SSO × shadow-IT discovery × CAPA

-- =============================================================================
-- TABLE 1: saas_spend_r3673 — per-application SaaS spend & seat-utilization facts
-- =============================================================================
create table if not exists public.saas_spend_r3673 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  app_name text not null,
  owner_department text not null,
  period_month date not null,
  seats_licensed int not null,
  seats_active int not null,
  seat_utilization_pct numeric(5,1),
  annual_spend_rupees numeric(12,2),
  cost_per_active_seat_rupees numeric(12,2),
  renewal_date date,
  days_to_renewal int,
  sso_integrated boolean not null,
  discovered_shadow boolean not null,
  app_category text not null check (app_category in (
    'productivity','crm_sales','engineering','finance_hr','communication','analytics'
  )),
  spend_status text not null check (spend_status in (
    'optimized','on_target','underutilized','shadow_it','redundant'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.saas_spend_r3673 enable row level security;

create index if not exists idx_saas_spend_r3673_org on public.saas_spend_r3673(organization_id);
create index if not exists idx_saas_spend_r3673_month on public.saas_spend_r3673(period_month);
create index if not exists idx_saas_spend_r3673_status on public.saas_spend_r3673(spend_status);

-- =============================================================================
-- TABLE 2: saas_spend_capa_actions_r3673 — CAPA & license-governance actions
-- =============================================================================
create table if not exists public.saas_spend_capa_actions_r3673 (
  id uuid primary key default gen_random_uuid(),
  spend_log_id uuid not null references public.saas_spend_r3673(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'seat_overprovisioning','shadow_app_discovered','duplicate_tool_overlap',
    'missed_renewal_negotiation','sso_gap','auto_renewal_risk',
    'license_tier_mismatch','inactive_seat_buildup'
  )),
  root_cause text not null check (root_cause in (
    'no_license_ownership','departmental_self_purchase','headcount_reduction_not_synced',
    'feature_overlap_unreviewed','renewal_calendar_missing','tier_upsell_unquestioned',
    'offboarding_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'downgrade_license_tier','reclaim_inactive_seats','consolidate_duplicate_tools',
    'negotiate_renewal_discount','migrate_to_sso','cancel_subscription',
    'enforce_procurement_policy','reassign_owner','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  potential_savings_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.saas_spend_capa_actions_r3673 enable row level security;

create index if not exists idx_saas_spend_capa_r3673_log on public.saas_spend_capa_actions_r3673(spend_log_id);
create index if not exists idx_saas_spend_capa_r3673_status on public.saas_spend_capa_actions_r3673(capa_status);

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

  -- 16 SaaS spend rows
  insert into public.saas_spend_r3673 (
    organization_id, app_name, owner_department, period_month,
    seats_licensed, seats_active, seat_utilization_pct, annual_spend_rupees,
    cost_per_active_seat_rupees, renewal_date, days_to_renewal,
    sso_integrated, discovered_shadow, app_category, spend_status, trend_dir, notes
  )
  select v_org_id, q.appn, q.dept, q.pm::date,
    q.slic, q.sact, q.util, q.spend,
    q.cpas, q.rdate::date, q.dtr,
    q.sso, q.shadow, q.cat, q.st, q.trd, q.nt
  from (values
    ('Zoho CRM','Sales','2026-07-01',
     120,112,93.3,1512000,13500.00,'2027-03-31',241,true,false,'crm_sales','optimized','stable','Enterprise tier renegotiated FY26 — per-seat cost down 11%'),
    ('Slack','Engineering','2026-07-01',
     220,201,91.4,1848000,9194.03,'2026-11-30',120,true,false,'communication','on_target','stable','Business+ plan — usage steady across squads'),
    ('Figma','Product Design','2026-07-01',
     45,27,60.0,1418000,52518.52,'2026-09-15',44,true,false,'engineering','underutilized','worsening','18 org seats idle over 60 days — dev-mode seats over-provisioned'),
    ('Tally Prime','Finance','2026-06-01',
     12,11,91.7,108000,9818.18,'2027-01-31',214,true,false,'finance_hr','on_target','stable','Gold multi-user licence — GST filings current'),
    ('Darwinbox','Human Resources','2026-06-01',
     180,141,78.3,1620000,11489.36,'2026-10-01',122,true,false,'finance_hr','underutilized','improving','39 seats belong to exited employees — offboarding sync fixed in July'),
    ('GitHub Enterprise','Engineering','2026-07-01',
     95,92,96.8,1995000,21684.78,'2027-02-28',211,true,false,'engineering','optimized','improving','Copilot bundle added at flat renewal — high active-committer ratio'),
    ('Jira Software','Engineering','2026-06-01',
     140,96,68.6,812000,8458.33,'2026-08-31',91,true,false,'engineering','underutilized','stable','Premium-tier features unused — downgrade candidate at renewal'),
    ('Zoom','Operations','2026-05-01',
     150,63,42.0,945000,15000.00,'2026-12-31',244,true,false,'communication','redundant','worsening','Google Meet covers 90% of meeting minutes — consolidation review running'),
    ('Google Workspace','IT','2026-07-01',
     260,254,97.7,3062400,12056.69,'2027-04-30',272,true,false,'productivity','optimized','stable','Business Plus — primary identity provider, near-full utilization'),
    ('Freshdesk','Customer Support','2026-06-01',
     48,44,91.7,633600,14400.00,'2026-10-15',136,true,false,'crm_sales','on_target','stable','Growth plan — ticket volume matches seat count'),
    ('Notion','Product','2026-05-01',
     80,51,63.8,384000,7529.41,'2026-09-30',152,true,false,'productivity','underutilized','improving','Wiki consolidation moving pages from Confluence — adoption rising'),
    ('Postman','Engineering','2026-05-01',
     60,57,95.0,342000,6000.00,'2027-01-15',260,true,false,'engineering','on_target','stable','API collections shared across firmware and cloud teams'),
    ('Mixpanel','Product','2026-06-01',
     25,14,56.0,1150000,82142.86,'2026-08-20',80,true,false,'analytics','underutilized','worsening','Renewal in under 90 days with no negotiation started — event-volume tier too high'),
    ('Canva Pro','Marketing','2026-07-01',
     35,33,94.3,231000,7000.00,'2026-08-10',40,false,true,'productivity','shadow_it','worsening','Purchased on corporate card outside procurement — no SSO, no DPA on file'),
    ('Airtable','Field Service Ops','2026-07-01',
     42,19,45.2,294000,15473.68,'2026-09-05',66,false,true,'productivity','shadow_it','stable','Discovered via CASB scan — duplicates Zoho Creator asset tracker'),
    ('Miro','Product Design','2026-05-01',
     50,22,44.0,437500,19886.36,'2026-08-25',85,false,true,'productivity','redundant','worsening','FigJam overlap — usage falling since May; cancel at renewal')
  ) as q(appn, dept, pm, slic, sact, util, spend, cpas, rdate, dtr, sso, shadow, cat, st, trd, nt);

  -- CAPA seed — attach to specific apps via app_name
  insert into public.saas_spend_capa_actions_r3673 (
    spend_log_id, finding_category, root_cause, corrective_action,
    capa_status, potential_savings_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.sav, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Figma','seat_overprovisioning','headcount_reduction_not_synced','reclaim_inactive_seats','in_progress',380000.00,'IT Asset Manager','2026-08-15',null,'18 idle full seats being downgraded to viewer before renewal'),
    ('Darwinbox','inactive_seat_buildup','offboarding_gap','reclaim_inactive_seats','open',240000.00,'HR Ops Lead','2026-08-31',null,'Exit-sync webhook live — reclaiming 39 stale seats this cycle'),
    ('Zoom','duplicate_tool_overlap','feature_overlap_unreviewed','consolidate_duplicate_tools','verification_pending',610000.00,'IT Director','2026-08-20',null,'Webinar licences moved to Meet — verifying no client-call breakage'),
    ('Canva Pro','shadow_app_discovered','departmental_self_purchase','enforce_procurement_policy','escalated',168000.00,'CISO','2026-08-08',null,'No DPA and card-billed — escalated to finance controller for clawback'),
    ('Airtable','shadow_app_discovered','no_license_ownership','cancel_subscription','open',294000.00,'IT Asset Manager','2026-09-01',null,'Field-service base migrating to Zoho Creator before cancellation'),
    ('Miro','duplicate_tool_overlap','feature_overlap_unreviewed','cancel_subscription','overdue',350000.00,'Design Ops Lead','2026-07-25',null,'Board export to FigJam behind schedule — renewal auto-charge risk'),
    ('Jira Software','license_tier_mismatch','tier_upsell_unquestioned','downgrade_license_tier','closed',420000.00,'Engineering Manager','2026-07-15','2026-07-10','Dropped Premium to Standard at renewal — automation limits acceptable'),
    ('Mixpanel','missed_renewal_negotiation','renewal_calendar_missing','negotiate_renewal_discount','in_progress',275000.00,'Product Ops','2026-08-12',null,'Event-volume audit done — quoting one tier down with annual prepay')
  ) as q(appn, fc, rc, ca, cst, sav, ownr, tcd, acd, nt)
  join public.saas_spend_r3673 e
    on e.organization_id = v_org_id and e.app_name = q.appn;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Spend-status distribution
create or replace function public.founder_r3673_spend_status_rollup()
returns table(spend_status text, apps bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.saas_spend_r3673)
  select l.spend_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.saas_spend_r3673 l
  group by l.spend_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3673_spend_status_rollup() from public, anon;
grant execute on function public.founder_r3673_spend_status_rollup() to authenticated;

-- 2) Department spend scorecard
create or replace function public.founder_r3673_department_scorecard()
returns table(
  owner_department text,
  total_apps bigint,
  optimized bigint,
  underutilized bigint,
  shadow_apps bigint,
  redundant_apps bigint,
  sso_missing bigint,
  total_annual_spend_rupees numeric,
  avg_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.owner_department,
    count(*)::bigint,
    count(*) filter (where l.spend_status = 'optimized')::bigint,
    count(*) filter (where l.spend_status = 'underutilized')::bigint,
    count(*) filter (where l.spend_status = 'shadow_it')::bigint,
    count(*) filter (where l.spend_status = 'redundant')::bigint,
    count(*) filter (where l.sso_integrated = false)::bigint,
    coalesce(sum(l.annual_spend_rupees),0)::numeric,
    round(avg(l.seat_utilization_pct), 1)
  from public.saas_spend_r3673 l
  group by l.owner_department
  order by coalesce(sum(l.annual_spend_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3673_department_scorecard() from public, anon;
grant execute on function public.founder_r3673_department_scorecard() to authenticated;

-- 3) App-category × spend-status matrix
create or replace function public.founder_r3673_category_status_matrix()
returns table(app_category text, spend_status text, apps bigint, total_annual_spend_rupees numeric, avg_utilization_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.app_category, l.spend_status, count(*)::bigint,
    coalesce(sum(l.annual_spend_rupees),0)::numeric,
    round(avg(l.seat_utilization_pct), 1)
  from public.saas_spend_r3673 l
  group by l.app_category, l.spend_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3673_category_status_matrix() from public, anon;
grant execute on function public.founder_r3673_category_status_matrix() to authenticated;

-- 4) Monthly spend trend
create or replace function public.founder_r3673_monthly_spend_trend()
returns table(period_month date, apps bigint, total_annual_spend_rupees numeric, avg_utilization_pct numeric, shadow_apps bigint, worsening_apps bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.annual_spend_rupees),0)::numeric,
    round(avg(l.seat_utilization_pct), 1),
    count(*) filter (where l.spend_status = 'shadow_it')::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.saas_spend_r3673 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3673_monthly_spend_trend() from public, anon;
grant execute on function public.founder_r3673_monthly_spend_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3673_capa_status_board()
returns table(capa_status text, findings bigint, avg_savings_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.potential_savings_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.saas_spend_capa_actions_r3673 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3673_capa_status_board() from public, anon;
grant execute on function public.founder_r3673_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3673_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_savings_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.saas_spend_capa_actions_r3673)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.potential_savings_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.saas_spend_capa_actions_r3673 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3673_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3673_root_cause_pareto() to authenticated;

-- 7) Seat-waste digest by department
create or replace function public.founder_r3673_seat_waste_digest()
returns table(
  owner_department text,
  apps bigint,
  seats_licensed_total bigint,
  seats_active_total bigint,
  seats_wasted bigint,
  wasted_spend_rupees numeric,
  avg_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.owner_department,
    count(*)::bigint,
    sum(l.seats_licensed)::bigint,
    sum(l.seats_active)::bigint,
    sum(l.seats_licensed - l.seats_active)::bigint,
    round(coalesce(sum(l.annual_spend_rupees / nullif(l.seats_licensed,0) * (l.seats_licensed - l.seats_active)),0), 0),
    round(avg(l.seat_utilization_pct), 1)
  from public.saas_spend_r3673 l
  group by l.owner_department
  order by sum(l.seats_licensed - l.seats_active) desc;
end;
$$;

revoke all on function public.founder_r3673_seat_waste_digest() from public, anon;
grant execute on function public.founder_r3673_seat_waste_digest() to authenticated;

-- 8) High-risk license queue (shadow-IT / redundant / low-utilization / near-renewal)
create or replace function public.founder_r3673_high_risk_queue()
returns table(
  app_name text,
  owner_department text,
  app_category text,
  period_month date,
  spend_status text,
  seats_licensed int,
  seats_active int,
  seat_utilization_pct numeric,
  annual_spend_rupees numeric,
  days_to_renewal int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.app_name, l.owner_department, l.app_category, l.period_month,
    l.spend_status, l.seats_licensed, l.seats_active, l.seat_utilization_pct,
    l.annual_spend_rupees, l.days_to_renewal, l.notes
  from public.saas_spend_r3673 l
  where l.spend_status in ('shadow_it','redundant')
     or l.discovered_shadow = true
     or l.sso_integrated = false
     or l.seat_utilization_pct < 50
     or l.days_to_renewal <= 45
  order by l.days_to_renewal asc, l.annual_spend_rupees desc;
end;
$$;

revoke all on function public.founder_r3673_high_risk_queue() from public, anon;
grant execute on function public.founder_r3673_high_risk_queue() to authenticated;
