-- Round 3669: Founder IT Change-Management (CAB) Change-Success Board
-- IT change governance — change volume x approval x implementation x success rate x emergency changes x rollbacks x lead time per system x CAPA

-- =============================================================================
-- TABLE 1: change_cab_r3669 — per-system per-month CAB change-management metrics
-- =============================================================================
create table if not exists public.change_cab_r3669 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  change_ref text not null,
  system_name text not null,
  period_month date not null,
  changes_submitted int not null,
  changes_approved int not null,
  changes_implemented int not null,
  success_rate_pct numeric(5,2),
  failed_changes int not null,
  emergency_changes int not null,
  emergency_pct numeric(5,2),
  rollback_count int not null,
  avg_lead_time_days numeric(6,2),
  change_category text not null check (change_category in (
    'standard','normal','emergency','major_release','infra'
  )),
  change_status text not null check (change_status in (
    'successful','partial_success','failed_rolled_back','caused_incident','unauthorized'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.change_cab_r3669 enable row level security;

create index if not exists idx_change_cab_r3669_org on public.change_cab_r3669(organization_id);
create index if not exists idx_change_cab_r3669_month on public.change_cab_r3669(period_month);
create index if not exists idx_change_cab_r3669_status on public.change_cab_r3669(change_status);

-- =============================================================================
-- TABLE 2: change_cab_capa_actions_r3669 — CAPA & governance actions
-- =============================================================================
create table if not exists public.change_cab_capa_actions_r3669 (
  id uuid primary key default gen_random_uuid(),
  change_log_id uuid not null references public.change_cab_r3669(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'inadequate_testing','poor_rollback_plan','untracked_dependency','vendor_patch_defect',
    'config_drift','insufficient_cab_review','emergency_bypass_abuse','capacity_shortfall',
    'pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'strengthen_test_coverage','mandate_rollback_plan','dependency_mapping_update',
    'vendor_escalation','config_baseline_enforcement','tighten_cab_quorum',
    'restrict_emergency_approvals','capacity_upgrade','freeze_window_review','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  downtime_impact_minutes numeric(8,2),
  action_owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.change_cab_capa_actions_r3669 enable row level security;

create index if not exists idx_change_cab_capa_r3669_log on public.change_cab_capa_actions_r3669(change_log_id);
create index if not exists idx_change_cab_capa_r3669_status on public.change_cab_capa_actions_r3669(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Change-status distribution
create or replace function public.founder_r3669_change_status_rollup()
returns table(change_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.change_cab_r3669)
  select l.change_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.change_cab_r3669 l
  group by l.change_status
  order by count(*) desc;
end;
$$;

-- 2) System-level change scorecard
create or replace function public.founder_r3669_system_scorecard()
returns table(
  system_name text,
  periods bigint,
  total_submitted bigint,
  total_implemented bigint,
  avg_success_rate_pct numeric,
  total_failed bigint,
  total_rollbacks bigint,
  avg_lead_time_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_name,
    count(*)::bigint,
    coalesce(sum(l.changes_submitted),0)::bigint,
    coalesce(sum(l.changes_implemented),0)::bigint,
    round(avg(l.success_rate_pct), 1),
    coalesce(sum(l.failed_changes),0)::bigint,
    coalesce(sum(l.rollback_count),0)::bigint,
    round(avg(l.avg_lead_time_days), 1)
  from public.change_cab_r3669 l
  group by l.system_name
  order by coalesce(sum(l.changes_submitted),0) desc;
end;
$$;

-- 3) Change-category x change-status matrix
create or replace function public.founder_r3669_category_status_matrix()
returns table(change_category text, change_status text, entries bigint, total_implemented bigint, total_rollbacks bigint, avg_success_rate_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.change_category, l.change_status, count(*)::bigint,
    coalesce(sum(l.changes_implemented),0)::bigint,
    coalesce(sum(l.rollback_count),0)::bigint,
    round(avg(l.success_rate_pct), 1)
  from public.change_cab_r3669 l
  group by l.change_category, l.change_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly change trend
create or replace function public.founder_r3669_monthly_change_trend()
returns table(period_month date, entries bigint, total_submitted bigint, total_implemented bigint, total_failed bigint, total_emergency bigint, avg_success_rate_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.changes_submitted),0)::bigint,
    coalesce(sum(l.changes_implemented),0)::bigint,
    coalesce(sum(l.failed_changes),0)::bigint,
    coalesce(sum(l.emergency_changes),0)::bigint,
    round(avg(l.success_rate_pct), 1)
  from public.change_cab_r3669 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3669_capa_status_board()
returns table(capa_status text, findings bigint, avg_downtime_minutes numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.downtime_impact_minutes)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.change_cab_capa_actions_r3669 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3669_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_downtime_minutes numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.change_cab_capa_actions_r3669)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.downtime_impact_minutes),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.change_cab_capa_actions_r3669 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Failed-change impact digest
create or replace function public.founder_r3669_failed_change_digest()
returns table(system_name text, failed_entries bigint, total_failed_changes bigint, total_rollbacks bigint, total_emergency bigint, avg_success_rate_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_name,
    count(*)::bigint,
    coalesce(sum(l.failed_changes),0)::bigint,
    coalesce(sum(l.rollback_count),0)::bigint,
    coalesce(sum(l.emergency_changes),0)::bigint,
    round(avg(l.success_rate_pct), 1)
  from public.change_cab_r3669 l
  where l.change_status in ('failed_rolled_back','caused_incident','unauthorized')
  group by l.system_name
  order by coalesce(sum(l.failed_changes),0) desc;
end;
$$;

-- 8) High-risk change queue (incidents, unauthorized, rollbacks, worsening trend)
create or replace function public.founder_r3669_high_risk_queue()
returns table(
  change_ref text,
  system_name text,
  period_month date,
  change_category text,
  change_status text,
  failed_changes int,
  rollback_count int,
  emergency_pct numeric,
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
  select l.change_ref, l.system_name, l.period_month, l.change_category,
    l.change_status, l.failed_changes, l.rollback_count, l.emergency_pct,
    l.trend_dir, l.notes
  from public.change_cab_r3669 l
  where l.change_status in ('failed_rolled_back','caused_incident','unauthorized')
     or l.trend_dir = 'worsening'
     or l.rollback_count > 0
  order by l.period_month desc, l.system_name;
end;
$$;

-- =============================================================================
-- Grants
-- =============================================================================
revoke all on function public.founder_r3669_change_status_rollup() from public, anon;
revoke all on function public.founder_r3669_system_scorecard() from public, anon;
revoke all on function public.founder_r3669_category_status_matrix() from public, anon;
revoke all on function public.founder_r3669_monthly_change_trend() from public, anon;
revoke all on function public.founder_r3669_capa_status_board() from public, anon;
revoke all on function public.founder_r3669_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3669_failed_change_digest() from public, anon;
revoke all on function public.founder_r3669_high_risk_queue() from public, anon;

grant execute on function public.founder_r3669_change_status_rollup() to authenticated;
grant execute on function public.founder_r3669_system_scorecard() to authenticated;
grant execute on function public.founder_r3669_category_status_matrix() to authenticated;
grant execute on function public.founder_r3669_monthly_change_trend() to authenticated;
grant execute on function public.founder_r3669_capa_status_board() to authenticated;
grant execute on function public.founder_r3669_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3669_failed_change_digest() to authenticated;
grant execute on function public.founder_r3669_high_risk_queue() to authenticated;

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

  -- 16 change-management rows
  insert into public.change_cab_r3669 (
    organization_id, change_ref, system_name, period_month,
    changes_submitted, changes_approved, changes_implemented, success_rate_pct,
    failed_changes, emergency_changes, emergency_pct, rollback_count,
    avg_lead_time_days, change_category, change_status, trend_dir, notes
  )
  select v_org_id, q.cref, q.sysn, q.pmon::date,
    q.subm, q.appr, q.impl, q.sucp,
    q.failc, q.emrg, q.emrp, q.rollb,
    q.leadd, q.ccat, q.cstat, q.tdir, q.nt
  from (values
    ('CHG-ERP-2606','SAP ERP Production','2026-06-01',
     24,22,21,90.5,2,1,4.8,1,6.5,'normal','successful','improving','ERP month clean — one MRP job change failed and was reworked'),
    ('CHG-ERP-2607','SAP ERP Production','2026-07-01',
     28,26,25,92.0,2,2,8.0,1,5.8,'normal','successful','improving','GST-return patch and pricing config shipped without incident'),
    ('CHG-CRM-2606','Salesforce CRM','2026-06-01',
     15,14,14,85.7,2,0,0.0,1,4.2,'standard','partial_success','stable','Vendor patch defect degraded lead-routing for two days'),
    ('CHG-CRM-2607','Salesforce CRM','2026-07-01',
     18,17,16,93.8,1,1,6.3,0,3.9,'standard','successful','improving','Dealer-portal flow updates landed cleanly post vendor hotfix'),
    ('CHG-FLD-2606','EquipSeva Field App','2026-06-01',
     32,30,29,89.7,3,3,10.3,2,2.4,'major_release','partial_success','stable','Release 4.2 config drift between staging and prod caused two rollbacks'),
    ('CHG-FLD-2607','EquipSeva Field App','2026-07-01',
     35,33,32,96.9,1,2,6.3,1,2.1,'major_release','successful','improving','Release 4.3 clean after config baseline enforcement'),
    ('CHG-SUP-2606','Supabase Prod DB','2026-06-01',
     20,19,18,83.3,3,4,22.2,2,1.8,'infra','failed_rolled_back','worsening','Schema migration rolled back on prod — staging parity gap'),
    ('CHG-SUP-2607','Supabase Prod DB','2026-07-01',
     22,21,20,90.0,2,3,15.0,1,1.6,'infra','partial_success','improving','Connection-pool saturation during release window — one rollback'),
    ('CHG-WMS-2606','Warehouse WMS Bhiwandi','2026-06-01',
     10,9,9,77.8,2,1,11.1,1,7.4,'normal','caused_incident','worsening','Picking outage 95 min after label-printer dependency missed in CAB'),
    ('CHG-WMS-2607','Warehouse WMS Bhiwandi','2026-07-01',
     12,11,10,90.0,1,1,10.0,0,6.8,'normal','successful','improving','Dispatch-slotting change landed with dependency map updated'),
    ('CHG-NET-2606','Corporate Firewall Mumbai HQ','2026-06-01',
     8,8,8,87.5,1,2,25.0,1,3.0,'emergency','failed_rolled_back','stable','Emergency rule change rolled back — VPN split-tunnel break'),
    ('CHG-NET-2607','Corporate Firewall Mumbai HQ','2026-07-01',
     9,9,9,100.0,0,1,11.1,0,2.7,'emergency','successful','improving','All firewall changes clean with new rollback template'),
    ('CHG-PAY-2606','Keka HR Payroll','2026-06-01',
     6,6,6,100.0,0,0,0.0,0,8.2,'standard','successful','stable','Payroll cycle changes routine — PF slab update on schedule'),
    ('CHG-CICD-2607','GitHub Actions CI-CD','2026-07-01',
     14,12,12,91.7,1,0,0.0,1,1.2,'infra','partial_success','stable','Runner upgrade slipped through with single approver — one rollback'),
    ('CHG-O365-2606','Microsoft 365 Tenant','2026-06-01',
     7,6,6,83.3,1,0,0.0,0,5.5,'standard','unauthorized','worsening','Untracked tenant-level mail-flow change by admin outside CAB'),
    ('CHG-BI-2607','Zoho Analytics BI','2026-07-01',
     5,5,5,100.0,0,0,0.0,0,4.0,'standard','successful','stable','Dashboard refresh-schedule changes all successful')
  ) as q(cref, sysn, pmon, subm, appr, impl, sucp, failc, emrg, emrp, rollb, leadd, ccat, cstat, tdir, nt);

  -- CAPA seed — attach to specific change rows via change_ref
  insert into public.change_cab_capa_actions_r3669 (
    change_log_id, root_cause, corrective_action, capa_status,
    downtime_impact_minutes, action_owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.dtm, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CHG-SUP-2606','inadequate_testing','strengthen_test_coverage','in_progress',
     42.0,'Nikhil Sharma (DB Lead)','2026-07-20',null,'Prod migration rollback — staging parity test suite being added'),
    ('CHG-WMS-2606','untracked_dependency','dependency_mapping_update','escalated',
     95.0,'Priya Nair (IT Ops)','2026-07-15',null,'Picking outage traced to undocumented label-printer dependency'),
    ('CHG-NET-2606','poor_rollback_plan','mandate_rollback_plan','closed',
     30.0,'Arjun Mehta (NetSec)','2026-07-05','2026-07-02','Firewall change rolled back cleanly after rollback-plan template mandated'),
    ('CHG-O365-2606','emergency_bypass_abuse','restrict_emergency_approvals','open',
     0.0,'Kavita Rao (CISO)','2026-08-10',null,'Untracked tenant change — emergency approval rights narrowed to two admins'),
    ('CHG-FLD-2606','config_drift','config_baseline_enforcement','verification_pending',
     18.0,'Rohit Kulkarni (Mobile Lead)','2026-07-25',null,'Field-app config drift between staging and prod — baseline enforced, verifying'),
    ('CHG-CRM-2606','vendor_patch_defect','vendor_escalation','closed',
     25.0,'Sneha Iyer (CRM Admin)','2026-07-08','2026-07-06','Salesforce patch defect fixed via vendor hotfix and regression pass'),
    ('CHG-CICD-2607','insufficient_cab_review','tighten_cab_quorum','in_progress',
     12.0,'Vikram Singh (DevOps)','2026-08-05',null,'Runner upgrade approved by single reviewer — CAB quorum raised to two'),
    ('CHG-SUP-2607','capacity_shortfall','capacity_upgrade','overdue',
     20.0,'Nikhil Sharma (DB Lead)','2026-07-28',null,'Connection-pool saturation during release window — pool upgrade pending')
  ) as q(cref, rc, ca, cst, dtm, ownr, tcd, acd, nt)
  join public.change_cab_r3669 e
    on e.organization_id = v_org_id and e.change_ref = q.cref;
end;
$seed$;
