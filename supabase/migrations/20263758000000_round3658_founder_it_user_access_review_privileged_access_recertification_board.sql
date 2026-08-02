-- Round 3658: Founder IT User-Access Review / Privileged-Access Recertification Board
-- IT security governance — per-system quarterly user-access review × privileged-account recertification × orphan-account cleanup × excessive-rights revocation × CAPA

-- =============================================================================
-- TABLE 1: access_review_r3658 — per-system user-access review / recertification
-- =============================================================================
create table if not exists public.access_review_r3658 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  system_name text not null,
  system_owner text not null,
  period_month date not null,
  accounts_total int not null,
  accounts_reviewed int not null,
  review_pct numeric(5,1),
  privileged_accounts int not null,
  orphan_accounts int not null,
  excessive_rights_found int not null,
  revocations_done int not null,
  last_review_date date,
  next_review_due date,
  system_criticality text not null check (system_criticality in (
    'critical','high','medium','low'
  )),
  review_status text not null check (review_status in (
    'certified','in_progress','partial','overdue','not_started'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.access_review_r3658 enable row level security;

create index if not exists idx_access_review_r3658_org on public.access_review_r3658(organization_id);
create index if not exists idx_access_review_r3658_month on public.access_review_r3658(period_month);
create index if not exists idx_access_review_r3658_status on public.access_review_r3658(review_status);

-- =============================================================================
-- TABLE 2: access_review_capa_actions_r3658 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.access_review_capa_actions_r3658 (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.access_review_r3658(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'orphan_account_active','excessive_privileges','segregation_of_duties_conflict',
    'stale_privileged_account','review_not_performed','shared_account_usage',
    'delegation_sprawl','contractor_access_not_expired'
  )),
  root_cause text not null check (root_cause in (
    'offboarding_process_gap','role_mapping_outdated','no_joiner_mover_leaver_sync',
    'manual_provisioning_error','owner_change_unassigned','shadow_it_account',
    'review_cadence_not_enforced','vendor_default_access','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'revoke_access','downgrade_privileges','disable_account','enforce_sso_mfa',
    'automate_deprovisioning','reassign_system_owner','implement_role_matrix',
    'expire_contractor_accounts','complete_review_sprint','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  accounts_impacted numeric(8,0),
  action_owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.access_review_capa_actions_r3658 enable row level security;

create index if not exists idx_access_review_capa_r3658_review on public.access_review_capa_actions_r3658(review_id);
create index if not exists idx_access_review_capa_r3658_status on public.access_review_capa_actions_r3658(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Review status distribution
create or replace function public.founder_r3658_review_status_rollup()
returns table(review_status text, systems bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.access_review_r3658)
  select l.review_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.access_review_r3658 l
  group by l.review_status
  order by count(*) desc;
end;
$$;

-- 2) System-owner scorecard
create or replace function public.founder_r3658_system_owner_scorecard()
returns table(
  system_owner text,
  systems bigint,
  certified bigint,
  overdue_or_missed bigint,
  accounts_total bigint,
  accounts_reviewed bigint,
  avg_review_pct numeric,
  privileged_accounts bigint,
  orphan_accounts bigint,
  revocations_done bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_owner,
    count(*)::bigint,
    count(*) filter (where l.review_status = 'certified')::bigint,
    count(*) filter (where l.review_status in ('overdue','not_started'))::bigint,
    coalesce(sum(l.accounts_total),0)::bigint,
    coalesce(sum(l.accounts_reviewed),0)::bigint,
    round(avg(l.review_pct), 1),
    coalesce(sum(l.privileged_accounts),0)::bigint,
    coalesce(sum(l.orphan_accounts),0)::bigint,
    coalesce(sum(l.revocations_done),0)::bigint
  from public.access_review_r3658 l
  group by l.system_owner
  order by count(*) desc;
end;
$$;

-- 3) System criticality × review status matrix
create or replace function public.founder_r3658_criticality_status_matrix()
returns table(system_criticality text, review_status text, systems bigint, accounts_total bigint, privileged_accounts bigint, avg_review_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_criticality, l.review_status, count(*)::bigint,
    coalesce(sum(l.accounts_total),0)::bigint,
    coalesce(sum(l.privileged_accounts),0)::bigint,
    round(avg(l.review_pct), 1)
  from public.access_review_r3658 l
  group by l.system_criticality, l.review_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly review trend
create or replace function public.founder_r3658_monthly_review_trend()
returns table(period_month date, systems bigint, certified bigint, overdue_or_not_started bigint, avg_review_pct numeric, orphan_accounts bigint, excessive_rights bigint, revocations bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.review_status = 'certified')::bigint,
    count(*) filter (where l.review_status in ('overdue','not_started'))::bigint,
    round(avg(l.review_pct), 1),
    coalesce(sum(l.orphan_accounts),0)::bigint,
    coalesce(sum(l.excessive_rights_found),0)::bigint,
    coalesce(sum(l.revocations_done),0)::bigint
  from public.access_review_r3658 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3658_capa_status_board()
returns table(capa_status text, findings bigint, avg_accounts_impacted numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.accounts_impacted)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.access_review_capa_actions_r3658 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3658_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_accounts_impacted numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.access_review_capa_actions_r3658)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.accounts_impacted),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.access_review_capa_actions_r3658 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Orphan / excessive-rights digest by criticality
create or replace function public.founder_r3658_orphan_excess_digest()
returns table(system_criticality text, systems bigint, orphan_accounts bigint, excessive_rights_found bigint, revocations_done bigint, unremediated_gap bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_criticality,
    count(*)::bigint,
    coalesce(sum(l.orphan_accounts),0)::bigint,
    coalesce(sum(l.excessive_rights_found),0)::bigint,
    coalesce(sum(l.revocations_done),0)::bigint,
    greatest(coalesce(sum(l.orphan_accounts),0) + coalesce(sum(l.excessive_rights_found),0) - coalesce(sum(l.revocations_done),0), 0)::bigint
  from public.access_review_r3658 l
  group by l.system_criticality
  order by count(*) desc;
end;
$$;

-- 8) High-risk recertification queue
create or replace function public.founder_r3658_high_risk_queue()
returns table(
  system_name text,
  system_owner text,
  period_month date,
  system_criticality text,
  review_status text,
  review_pct numeric,
  privileged_accounts int,
  orphan_accounts int,
  excessive_rights_found int,
  next_review_due date,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_name, l.system_owner, l.period_month, l.system_criticality,
    l.review_status, l.review_pct, l.privileged_accounts, l.orphan_accounts,
    l.excessive_rights_found, l.next_review_due, l.notes
  from public.access_review_r3658 l
  where l.review_status in ('overdue','not_started')
     or l.orphan_accounts > 0
     or l.excessive_rights_found > 0
     or l.trend_dir = 'worsening'
  order by case l.system_criticality
      when 'critical' then 0
      when 'high' then 1
      when 'medium' then 2
      else 3
    end,
    l.next_review_due asc nulls last;
end;
$$;

revoke all on function public.founder_r3658_review_status_rollup() from public, anon;
revoke all on function public.founder_r3658_system_owner_scorecard() from public, anon;
revoke all on function public.founder_r3658_criticality_status_matrix() from public, anon;
revoke all on function public.founder_r3658_monthly_review_trend() from public, anon;
revoke all on function public.founder_r3658_capa_status_board() from public, anon;
revoke all on function public.founder_r3658_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3658_orphan_excess_digest() from public, anon;
revoke all on function public.founder_r3658_high_risk_queue() from public, anon;

grant execute on function public.founder_r3658_review_status_rollup() to authenticated;
grant execute on function public.founder_r3658_system_owner_scorecard() to authenticated;
grant execute on function public.founder_r3658_criticality_status_matrix() to authenticated;
grant execute on function public.founder_r3658_monthly_review_trend() to authenticated;
grant execute on function public.founder_r3658_capa_status_board() to authenticated;
grant execute on function public.founder_r3658_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3658_orphan_excess_digest() to authenticated;
grant execute on function public.founder_r3658_high_risk_queue() to authenticated;

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

  -- 16 access-review rows
  insert into public.access_review_r3658 (
    organization_id, system_name, system_owner, period_month,
    accounts_total, accounts_reviewed, review_pct, privileged_accounts,
    orphan_accounts, excessive_rights_found, revocations_done,
    last_review_date, next_review_due, system_criticality, review_status, trend_dir, notes
  )
  select v_org_id, q.sysname, q.owner_nm, q.pmonth::date,
    q.acc_tot, q.acc_rev, q.rev_pct, q.priv_acc,
    q.orph_acc, q.exc_rights, q.revoked,
    q.lastrev::date, q.nextdue::date, q.crit, q.rstatus, q.tdir, q.nt
  from (values
    ('SAP Business One ERP','Ramesh Iyer','2026-07-01',184,184,100.0,12,0,3,3,
     '2026-07-08','2026-10-08','critical','certified','improving','Q2 recert complete; 3 excessive finance roles trimmed to least privilege'),
    ('Zoho CRM','Priya Nair','2026-07-01',126,101,80.2,6,4,5,2,
     '2026-07-10','2026-10-10','high','in_progress','stable','Sales-ops accounts pending manager sign-off; 4 orphan accounts flagged'),
    ('EquipSeva Field-Service App (Prod)','Arjun Mehta','2026-07-01',342,342,100.0,9,2,1,3,
     '2026-07-05','2026-10-05','critical','certified','stable','Engineer offboarding sync now automated from HRMS exit workflow'),
    ('Supabase Production DB','Arjun Mehta','2026-07-01',22,22,100.0,8,1,2,3,
     '2026-07-03','2026-10-03','critical','certified','improving','Service-role keys rotated; one orphan service account disabled'),
    ('Microsoft 365 / Exchange Online','Kavitha Rao','2026-07-01',238,152,63.9,10,7,4,1,
     '2026-07-12','2026-10-12','high','partial','worsening','Shared-mailbox delegations ballooning; review stalled at 64 pct'),
    ('FortiClient VPN','Suresh Menon','2026-07-01',198,198,100.0,5,6,2,8,
     '2026-07-06','2026-10-06','critical','certified','improving','6 orphan contractor VPN accounts found and revoked in-cycle'),
    ('Keka HRMS','Deepa Krishnan','2026-06-01',176,176,100.0,4,1,1,2,
     '2026-06-20','2026-09-20','medium','certified','stable','HR admin rights re-scoped to 4 named users only'),
    ('RazorpayX Payroll','Deepa Krishnan','2026-06-01',14,14,100.0,3,0,1,1,
     '2026-06-18','2026-09-18','critical','certified','stable','Dual-approval enforced on payout-initiator role'),
    ('eSSL Biometric Attendance','Suresh Menon','2026-06-01',58,29,50.0,2,3,0,0,
     '2026-06-25','2026-09-25','low','partial','stable','Branch device-admin list only half reviewed; low criticality'),
    ('GitHub Organization','Arjun Mehta','2026-06-01',46,46,100.0,7,2,3,4,
     '2026-06-15','2026-09-15','high','certified','improving','2 stale outside collaborators removed; 3 over-broad admin grants downgraded'),
    ('Jira / Confluence','Priya Nair','2026-06-01',88,53,60.2,5,2,2,0,
     '2026-06-28','2026-09-28','medium','in_progress','stable','Project-admin sprawl under review across 12 spaces'),
    ('Tally Prime (Accounts)','Ramesh Iyer','2026-05-01',12,12,100.0,4,0,2,2,
     '2026-05-30','2026-08-30','high','certified','stable','Two data-entry users had voucher-delete rights — revoked'),
    ('Warehouse WMS (Unicommerce)','Vikram Shetty','2026-05-01',64,0,0.0,6,5,0,0,
     null,'2026-08-15','high','not_started','worsening','Q2 review not kicked off; system owner changed mid-quarter'),
    ('Metabase BI','Kavitha Rao','2026-05-01',38,21,55.3,3,2,4,0,
     '2026-05-22','2026-08-22','medium','overdue','worsening','Row-level data access too broad for 4 analyst accounts; past due'),
    ('AWS Production Account','Arjun Mehta','2026-05-01',18,18,100.0,6,0,1,1,
     '2026-05-12','2026-08-12','critical','certified','stable','One IAM power-user policy tightened to least privilege'),
    ('Sophos Firewall Admin','Suresh Menon','2026-05-01',9,4,44.4,4,1,1,0,
     '2026-05-28','2026-08-28','critical','overdue','worsening','Firewall admin recert past due — only 4 of 9 accounts reviewed')
  ) as q(sysname, owner_nm, pmonth, acc_tot, acc_rev, rev_pct, priv_acc, orph_acc, exc_rights, revoked, lastrev, nextdue, crit, rstatus, tdir, nt);

  -- CAPA seed — attach to specific reviews via system_name
  insert into public.access_review_capa_actions_r3658 (
    review_id, finding_category, root_cause, corrective_action,
    capa_status, accounts_impacted, action_owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impacted, q.own_nm,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Microsoft 365 / Exchange Online','delegation_sprawl','no_joiner_mover_leaver_sync','automate_deprovisioning','in_progress',7,'Kavitha Rao','2026-08-20',null,'AD-sync deprovisioning connector in build; 7 stale delegations queued for removal'),
    ('Warehouse WMS (Unicommerce)','review_not_performed','owner_change_unassigned','reassign_system_owner','escalated',64,'Vikram Shetty','2026-08-10',null,'Owner transition left Q2 recert unowned — escalated to CISO forum'),
    ('Metabase BI','excessive_privileges','role_mapping_outdated','implement_role_matrix','overdue',4,'Kavitha Rao','2026-07-25',null,'Analyst role-matrix draft late; 4 accounts still see all-org data'),
    ('Sophos Firewall Admin','stale_privileged_account','review_cadence_not_enforced','complete_review_sprint','open',5,'Suresh Menon','2026-08-14',null,'Focused sprint booked to close remaining 5 firewall admin reviews'),
    ('FortiClient VPN','contractor_access_not_expired','offboarding_process_gap','expire_contractor_accounts','closed',6,'Suresh Menon','2026-07-15','2026-07-09','6 contractor VPN accounts revoked; 30-day auto-expiry now enforced'),
    ('Zoho CRM','orphan_account_active','manual_provisioning_error','disable_account','verification_pending',4,'Priya Nair','2026-08-05',null,'4 orphan sales accounts disabled — awaiting manager confirmation'),
    ('GitHub Organization','excessive_privileges','role_mapping_outdated','downgrade_privileges','closed',3,'Arjun Mehta','2026-07-10','2026-07-02','3 org-admin grants downgraded to maintainer per new role matrix'),
    ('Tally Prime (Accounts)','segregation_of_duties_conflict','manual_provisioning_error','revoke_access','closed',2,'Ramesh Iyer','2026-06-20','2026-06-12','Voucher-delete rights revoked from 2 data-entry users; SoD restored')
  ) as q(sysname, fc, rc, ca, cst, impacted, own_nm, tcd, acd, nt)
  join public.access_review_r3658 e
    on e.organization_id = v_org_id and e.system_name = q.sysname;
end;
$seed$;
