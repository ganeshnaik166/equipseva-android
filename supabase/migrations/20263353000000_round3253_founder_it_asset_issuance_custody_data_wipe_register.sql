-- Round 3253: Founder IT-Asset Issuance, Custody & End-of-Life Data-Wipe Register
-- Founder ops board — asset type × department × issuance × MDM enrolment × disk encryption × patch check × return × data-wipe status × custody verdict × CAPA

-- =============================================================================
-- TABLE 1: it_asset_custody_r3253 — per-asset issuance & custody register
-- =============================================================================
create table if not exists public.it_asset_custody_r3253 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_tag text not null,
  asset_type text not null check (asset_type in (
    'laptop','smartphone','tablet_field','sim_card','dongle_4g','monitor_desktop'
  )),
  assigned_to text not null,
  department text not null check (department in (
    'field_service','engineering','sales','ops','finance','founder_office'
  )),
  issue_date date not null,
  purchase_cost_rupees numeric(12,2) not null,
  condition_status text not null check (condition_status in (
    'new','good','worn','damaged','lost_reported'
  )),
  mdm_enrolled boolean not null,
  disk_encryption_ok boolean not null,
  last_patch_check_date date,
  return_date date,
  data_wipe_status text not null check (data_wipe_status in (
    'not_due','wipe_completed','wipe_pending','wipe_verified','not_recoverable'
  )),
  custody_verdict text not null check (custody_verdict in (
    'in_use_compliant','in_use_at_risk','returned_closed','overdue_return','lost_escalated'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.it_asset_custody_r3253 enable row level security;

create index if not exists idx_it_asset_custody_r3253_org on public.it_asset_custody_r3253(organization_id);
create index if not exists idx_it_asset_custody_r3253_issue on public.it_asset_custody_r3253(issue_date);
create index if not exists idx_it_asset_custody_r3253_verdict on public.it_asset_custody_r3253(custody_verdict);

-- =============================================================================
-- TABLE 2: it_asset_custody_capa_actions_r3253 — recovery / wipe / security CAPA
-- =============================================================================
create table if not exists public.it_asset_custody_capa_actions_r3253 (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.it_asset_custody_r3253(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'encryption_disabled','mdm_not_enrolled','overdue_return','device_lost',
    'data_wipe_pending','patching_lapsed','damage_recovery','sim_dongle_misuse_risk'
  )),
  root_cause text not null check (root_cause in (
    'user_disabled_encryption','mdm_rollout_backlog','exit_process_gap','device_theft_or_loss',
    'accidental_damage','patch_ring_not_assigned','asset_tracking_lapse','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'enforce_encryption_policy','enroll_in_mdm','recover_asset_and_wipe','remote_wipe_and_block',
    'file_fir_and_write_off','repair_and_reissue','push_patch_baseline','deduct_from_settlement',
    'retrain_staff','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  data_risk_level text not null check (data_risk_level in (
    'critical','high','medium','low','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.it_asset_custody_capa_actions_r3253 enable row level security;

create index if not exists idx_it_asset_capa_r3253_asset on public.it_asset_custody_capa_actions_r3253(asset_id);
create index if not exists idx_it_asset_capa_r3253_status on public.it_asset_custody_capa_actions_r3253(capa_status);

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

  -- 14 asset custody rows
  insert into public.it_asset_custody_r3253 (
    organization_id, asset_tag, asset_type, assigned_to, department,
    issue_date, purchase_cost_rupees, condition_status,
    mdm_enrolled, disk_encryption_ok, last_patch_check_date, return_date,
    data_wipe_status, custody_verdict, notes
  )
  select v_org_id, q.tag, q.atype, q.person, q.dept,
    q.idate::date, q.cost, q.cond,
    q.mdm, q.enc, q.patch::date, q.rdate::date,
    q.wipe, q.cv, q.nt
  from (values
    ('EQS-LAP-001','laptop','Ganesh Kumar','founder_office','2024-04-10',82000.00,'good',true,true,'2026-07-10',null,
     'not_due','in_use_compliant','Founder MacBook — MDM and FileVault verified this cycle'),
    ('EQS-LAP-002','laptop','Priya Sharma','engineering','2024-06-18',68500.00,'good',true,true,'2026-07-08',null,
     'not_due','in_use_compliant','Dev ThinkPad — BitLocker on, patch ring current'),
    ('EQS-LAP-003','laptop','Arjun Nair','engineering','2023-11-02',71000.00,'worn',true,false,'2026-05-30',null,
     'not_due','in_use_at_risk','BitLocker found disabled after SSD swap — re-enable pending'),
    ('EQS-LAP-004','laptop','Sneha Reddy','finance','2024-01-15',64000.00,'good',false,true,'2026-07-01',null,
     'not_due','in_use_at_risk','Tally laptop not in MDM — finance exception expired, enrolment due'),
    ('EQS-PHN-101','smartphone','Ravi Verma','field_service','2025-02-20',24500.00,'good',true,true,'2026-07-12',null,
     'not_due','in_use_compliant','Field-service phone for Apollo Chennai route — Intune compliant'),
    ('EQS-PHN-102','smartphone','Mohammed Irfan','field_service','2024-09-05',23000.00,'lost_reported',true,true,'2026-06-15',null,
     'wipe_verified','lost_escalated','Lost in transit near KIMS Hyderabad — remote wipe fired and verified in MDM'),
    ('EQS-PHN-103','smartphone','Kavitha Iyer','sales','2024-12-01',26500.00,'good',false,false,'2026-04-22',null,
     'not_due','in_use_at_risk','Sales phone unmanaged — MDM enrolment overdue three cycles'),
    ('EQS-TAB-201','tablet_field','Suresh Patil','field_service','2026-06-20',31500.00,'new',true,true,'2026-07-05',null,
     'not_due','in_use_compliant','New service-checklist tablet for Fortis Gurgaon route'),
    ('EQS-TAB-202','tablet_field','Deepak Joshi','field_service','2024-03-22',29500.00,'damaged',true,true,'2026-06-02','2026-06-28',
     'wipe_pending','returned_closed','Screen cracked at Manipal Bengaluru site — returned, factory wipe queued at IT desk'),
    ('EQS-SIM-301','sim_card','Ravi Verma','field_service','2025-02-20',199.00,'good',false,false,null,null,
     'not_due','in_use_compliant','Airtel data SIM paired with EQS-PHN-101'),
    ('EQS-SIM-302','sim_card','Anita Desai','sales','2023-08-11',199.00,'good',false,false,null,'2026-05-20',
     'wipe_completed','returned_closed','Employee exit — SIM deactivated with Jio and number recycled'),
    ('EQS-DNG-401','dongle_4g','Vikram Singh','ops','2024-07-30',2400.00,'lost_reported',false,false,'2026-01-18',null,
     'not_recoverable','lost_escalated','4G dongle lost at AIIMS Delhi visit — no remote-wipe path, SIM blocked instead'),
    ('EQS-MON-501','monitor_desktop','Lakshmi Menon','ops','2023-05-09',14500.00,'good',false,false,null,null,
     'not_due','in_use_compliant','Ops desk monitor — no storage, wipe not applicable'),
    ('EQS-LAP-005','laptop','Rahul Deshpande','sales','2023-02-14',59000.00,'worn',true,true,'2025-12-20',null,
     'wipe_pending','overdue_return','Exited 2026-06-30 — laptop not returned, courier recovery from Pune in progress')
  ) as q(tag, atype, person, dept, idate, cost, cond, mdm, enc, patch, rdate, wipe, cv, nt);

  -- CAPA seed — attach to specific assets via asset tag
  insert into public.it_asset_custody_capa_actions_r3253 (
    asset_id, finding_category, root_cause, corrective_action,
    capa_status, data_risk_level, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.drl, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('EQS-LAP-003','encryption_disabled','user_disabled_encryption','enforce_encryption_policy','in_progress','high','2026-07-22',null,0.00,
     'BitLocker re-enable pushed via Intune — awaiting reboot compliance report'),
    ('EQS-LAP-004','mdm_not_enrolled','mdm_rollout_backlog','enroll_in_mdm','open','medium','2026-07-25',null,0.00,
     'Finance exception expired — enrolment slot booked with IT desk'),
    ('EQS-PHN-102','device_lost','device_theft_or_loss','remote_wipe_and_block','closed','critical','2026-06-20','2026-06-16',23000.00,
     'Remote wipe verified in MDM console; IMEI blocked via DoT portal'),
    ('EQS-PHN-103','mdm_not_enrolled','mdm_rollout_backlog','enroll_in_mdm','overdue','high','2026-05-15',null,0.00,
     'Third enrolment reminder ignored — escalating to sales head'),
    ('EQS-TAB-202','data_wipe_pending','accidental_damage','repair_and_reissue','verification_pending','medium','2026-07-15',null,6800.00,
     'Screen replaced and factory reset done — wipe verification pending'),
    ('EQS-DNG-401','device_lost','device_theft_or_loss','file_fir_and_write_off','escalated','low','2026-07-10',null,2400.00,
     'FIR filed at Delhi; SIM blocked; write-off approval with finance'),
    ('EQS-LAP-005','overdue_return','exit_process_gap','recover_asset_and_wipe','in_progress','critical','2026-07-20',null,59000.00,
     'HR exit checklist missed IT sign-off — courier pickup scheduled from Pune')
  ) as q(tag, fc, rc, ca, cst, drl, tcd, acd, cost, nt)
  join public.it_asset_custody_r3253 e
    on e.organization_id = v_org_id and e.asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Custody verdict distribution
create or replace function public.founder_r3253_custody_verdict_rollup()
returns table(custody_verdict text, assets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.it_asset_custody_r3253)
  select l.custody_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.it_asset_custody_r3253 l
  group by l.custody_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3253_custody_verdict_rollup() from public, anon;
grant execute on function public.founder_r3253_custody_verdict_rollup() to authenticated;

-- 2) Department custody scorecard
create or replace function public.founder_r3253_department_scorecard()
returns table(
  department text,
  total_assets bigint,
  compliant bigint,
  at_risk bigint,
  overdue_or_lost bigint,
  mdm_enrolled_count bigint,
  encryption_ok_count bigint,
  total_purchase_cost_rupees numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    count(*) filter (where l.custody_verdict = 'in_use_compliant')::bigint,
    count(*) filter (where l.custody_verdict = 'in_use_at_risk')::bigint,
    count(*) filter (where l.custody_verdict in ('overdue_return','lost_escalated'))::bigint,
    count(*) filter (where l.mdm_enrolled)::bigint,
    count(*) filter (where l.disk_encryption_ok)::bigint,
    coalesce(sum(l.purchase_cost_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.custody_verdict = 'in_use_compliant')::numeric / nullif(count(*),0), 1)
  from public.it_asset_custody_r3253 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3253_department_scorecard() from public, anon;
grant execute on function public.founder_r3253_department_scorecard() to authenticated;

-- 3) Asset type × data-wipe status matrix
create or replace function public.founder_r3253_asset_wipe_matrix()
returns table(asset_type text, data_wipe_status text, assets bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_type, l.data_wipe_status, count(*)::bigint,
    coalesce(sum(l.purchase_cost_rupees),0)::numeric
  from public.it_asset_custody_r3253 l
  group by l.asset_type, l.data_wipe_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3253_asset_wipe_matrix() from public, anon;
grant execute on function public.founder_r3253_asset_wipe_matrix() to authenticated;

-- 4) Issuance-date trend
create or replace function public.founder_r3253_issuance_trend()
returns table(issue_date date, issued bigint, returned bigint, lost bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.issue_date,
    count(*)::bigint,
    count(*) filter (where l.return_date is not null)::bigint,
    count(*) filter (where l.condition_status = 'lost_reported')::bigint,
    coalesce(sum(l.purchase_cost_rupees),0)::numeric
  from public.it_asset_custody_r3253 l
  group by l.issue_date
  order by l.issue_date desc;
end;
$$;

revoke execute on function public.founder_r3253_issuance_trend() from public, anon;
grant execute on function public.founder_r3253_issuance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3253_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.it_asset_custody_capa_actions_r3253 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3253_capa_status_board() from public, anon;
grant execute on function public.founder_r3253_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3253_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.it_asset_custody_capa_actions_r3253)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.it_asset_custody_capa_actions_r3253 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3253_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3253_root_cause_pareto() to authenticated;

-- 7) Data-risk digest
create or replace function public.founder_r3253_data_risk_digest()
returns table(data_risk_level text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.data_risk_level, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.it_asset_custody_capa_actions_r3253 c
  group by c.data_risk_level
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3253_data_risk_digest() from public, anon;
grant execute on function public.founder_r3253_data_risk_digest() to authenticated;

-- 8) High-risk custody queue (top individual concerns)
create or replace function public.founder_r3253_high_risk_queue()
returns table(
  asset_tag text,
  asset_type text,
  assigned_to text,
  department text,
  issue_date date,
  condition_status text,
  mdm_status text,
  encryption_status text,
  data_wipe_status text,
  custody_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_tag, l.asset_type, l.assigned_to, l.department, l.issue_date,
    l.condition_status,
    case when l.mdm_enrolled then 'enrolled' else 'not_enrolled' end,
    case when l.disk_encryption_ok then 'encrypted' else 'not_encrypted' end,
    l.data_wipe_status, l.custody_verdict, l.notes
  from public.it_asset_custody_r3253 l
  where l.custody_verdict in ('in_use_at_risk','overdue_return','lost_escalated')
     or l.data_wipe_status in ('wipe_pending','not_recoverable')
     or (l.asset_type in ('laptop','smartphone','tablet_field')
         and (not l.mdm_enrolled or not l.disk_encryption_ok))
  order by l.issue_date desc, l.asset_tag;
end;
$$;

revoke execute on function public.founder_r3253_high_risk_queue() from public, anon;
grant execute on function public.founder_r3253_high_risk_queue() to authenticated;
