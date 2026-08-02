-- Round 3659: IT Backup / DR Restore-Test Verification Board
-- IT governance — backup success × restore-test verification × RPO/RTO targets vs achieved × offsite copy × tier × DR status × trend × CAPA

-- =============================================================================
-- TABLE 1: backup_dr_r3659 — per-system backup & DR restore-test verification
-- =============================================================================
create table if not exists public.backup_dr_r3659 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  system_name text not null,
  backup_type text not null check (backup_type in (
    'full_daily','incremental_hourly','differential_nightly','snapshot',
    'continuous_replication','weekly_full'
  )),
  period_month date not null,
  backup_jobs int not null,
  backup_success_pct numeric(5,2) not null,
  last_restore_test date,
  restore_test_passed boolean not null,
  rpo_target_hrs numeric(6,1) not null,
  rpo_achieved_hrs numeric(6,1),
  rto_target_hrs numeric(6,1) not null,
  rto_achieved_hrs numeric(6,1),
  offsite_copy boolean not null,
  tier text not null check (tier in (
    'tier_1_critical','tier_2_important','tier_3_standard','tier_4_archive'
  )),
  dr_status text not null check (dr_status in (
    'verified','on_track','test_overdue','rpo_rto_breach','unprotected'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.backup_dr_r3659 enable row level security;

create index if not exists idx_backup_dr_r3659_org on public.backup_dr_r3659(organization_id);
create index if not exists idx_backup_dr_r3659_month on public.backup_dr_r3659(period_month);
create index if not exists idx_backup_dr_r3659_status on public.backup_dr_r3659(dr_status);

-- =============================================================================
-- TABLE 2: backup_dr_capa_actions_r3659 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.backup_dr_capa_actions_r3659 (
  id uuid primary key default gen_random_uuid(),
  backup_dr_id uuid not null references public.backup_dr_r3659(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'backup_failure_spike','restore_test_overdue','restore_test_failed',
    'rpo_breach','rto_breach','offsite_copy_missing','media_verification_gap','runbook_gap'
  )),
  root_cause text not null check (root_cause in (
    'backup_window_overrun','storage_capacity_exhausted','tape_media_degraded',
    'network_bandwidth_saturation','agent_version_mismatch','runbook_outdated',
    'staffing_gap','vendor_replication_lag','config_drift','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'rerun_backup_job','expand_storage_capacity','replace_backup_media',
    'schedule_restore_drill','upgrade_backup_agent','update_dr_runbook',
    'enable_offsite_replication','tune_backup_window','engage_vendor_support','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  downtime_risk_hrs numeric(6,1),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.backup_dr_capa_actions_r3659 enable row level security;

create index if not exists idx_backup_dr_capa_r3659_link on public.backup_dr_capa_actions_r3659(backup_dr_id);
create index if not exists idx_backup_dr_capa_r3659_status on public.backup_dr_capa_actions_r3659(capa_status);

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

  -- 16 backup/DR verification rows
  insert into public.backup_dr_r3659 (
    organization_id, system_name, backup_type, period_month, backup_jobs,
    backup_success_pct, last_restore_test, restore_test_passed,
    rpo_target_hrs, rpo_achieved_hrs, rto_target_hrs, rto_achieved_hrs,
    offsite_copy, tier, dr_status, trend_dir, notes
  )
  select v_org_id, q.sys, q.btype, q.pmon::date, q.jobs,
    q.spct, q.lrt::date, q.rtp,
    q.rpot, q.rpoa, q.rtot, q.rtoa,
    q.offc, q.tier, q.dst, q.tdir, q.nt
  from (values
    ('SAP ERP Production','full_daily','2026-07-01',31,100.00,'2026-06-20',true,
     4.0,2.5,8.0,5.5,true,'tier_1_critical','verified','stable','Monthly restore drill to DR site Chennai passed — RPO/RTO within target'),
    ('Supabase Prod (EquipSeva App DB)','continuous_replication','2026-07-01',744,99.90,'2026-07-05',true,
     0.5,0.2,2.0,1.4,true,'tier_1_critical','verified','improving','PITR verified via point-in-time restore into staging project'),
    ('Field-Service App Object Storage','snapshot','2026-07-01',124,99.20,'2026-05-18',true,
     12.0,6.0,12.0,9.0,true,'tier_2_important','on_track','stable','Bucket snapshot restore sampled 500 job-card attachments OK'),
    ('Zoho CRM Export Vault','weekly_full','2026-07-01',5,100.00,null,false,
     24.0,null,24.0,null,false,'tier_2_important','test_overdue','worsening','SaaS export never restore-tested and offsite copy missing'),
    ('O365 Exchange Online Mail','incremental_hourly','2026-07-01',720,99.80,'2026-06-28',true,
     1.0,0.8,6.0,4.0,true,'tier_2_important','verified','stable','Mailbox-level restore of 3 sample users verified'),
    ('GreytHR HRMS DB','full_daily','2026-07-01',31,96.80,'2026-04-10',true,
     24.0,20.0,24.0,30.0,true,'tier_3_standard','rpo_rto_breach','worsening','RTO achieved 30h vs 24h target in April drill — runbook gaps'),
    ('Tally Finance Server','full_daily','2026-07-01',31,100.00,'2026-06-15',true,
     24.0,18.0,12.0,8.0,true,'tier_1_critical','verified','stable','Tally data plus licence config restored to spare VM successfully'),
    ('Payroll Processing DB','differential_nightly','2026-07-01',31,98.40,'2026-03-22',true,
     24.0,22.0,24.0,20.0,true,'tier_2_important','test_overdue','stable','Quarterly restore drill slipped past due date — rescheduled with finance'),
    ('Biometric Attendance Server','full_daily','2026-07-01',31,92.50,null,false,
     24.0,null,48.0,null,false,'tier_3_standard','unprotected','worsening','Local USB-disk backup only; no offsite copy and never restore-tested'),
    ('Active Directory Domain Controllers','snapshot','2026-07-01',62,99.50,'2026-06-25',true,
     4.0,3.0,8.0,6.5,true,'tier_1_critical','verified','stable','Forest-recovery drill with system-state restore passed'),
    ('VPN Concentrator Config','weekly_full','2026-07-01',5,100.00,'2026-06-08',true,
     168.0,96.0,4.0,2.0,true,'tier_2_important','verified','stable','Config restore to standby appliance validated'),
    ('QMS Document Server (ISO 13485)','full_daily','2026-07-01',31,99.70,'2026-05-30',true,
     24.0,16.0,24.0,18.0,true,'tier_1_critical','on_track','stable','DHF/DMR archive restore sampled; next full drill in August'),
    ('Warehouse WMS Bhiwandi','incremental_hourly','2026-07-01',696,97.10,'2026-06-02',false,
     2.0,6.0,8.0,12.0,true,'tier_2_important','rpo_rto_breach','worsening','Restore drill failed at app-tier reconfig; RPO 6h vs 2h target'),
    ('Service Ticket Portal','snapshot','2026-07-01',124,99.00,'2026-06-18',true,
     6.0,4.0,12.0,7.0,true,'tier_3_standard','verified','improving','Portal DB plus uploads restored to UAT and smoke-tested'),
    ('Corporate File Server Mumbai HO','full_daily','2026-07-01',31,95.20,'2026-02-14',true,
     24.0,20.0,24.0,22.0,false,'tier_3_standard','test_overdue','stable','Offsite copy job disabled after NAS migration — re-enable pending'),
    ('CCTV NVR Archive','weekly_full','2026-07-01',5,88.00,null,false,
     168.0,null,72.0,null,false,'tier_4_archive','unprotected','worsening','NVR retention on single disk; no backup beyond 30-day loop')
  ) as q(sys, btype, pmon, jobs, spct, lrt, rtp, rpot, rpoa, rtot, rtoa, offc, tier, dst, tdir, nt);

  -- CAPA seed — attach to specific systems via system_name
  insert into public.backup_dr_capa_actions_r3659 (
    backup_dr_id, finding_category, root_cause, corrective_action,
    capa_status, downtime_risk_hrs, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.drisk, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('Zoho CRM Export Vault','restore_test_overdue','runbook_outdated','schedule_restore_drill','in_progress',24.0,'IT Ops Lead','2026-08-10',null,'SaaS export restore drill being scripted with vendor sandbox'),
    ('Biometric Attendance Server','offsite_copy_missing','config_drift','enable_offsite_replication','open',48.0,'Infra Engineer','2026-08-20',null,'Route USB-disk backup to NAS plus cloud tier; procurement raised'),
    ('GreytHR HRMS DB','rto_breach','runbook_outdated','update_dr_runbook','verification_pending',6.0,'IT Ops Lead','2026-08-05',null,'Runbook rewritten with app-tier steps — verify in next drill'),
    ('Warehouse WMS Bhiwandi','rpo_breach','backup_window_overrun','tune_backup_window','escalated',10.0,'Infra Engineer','2026-07-28',null,'Hourly incrementals overrun into shift hours — escalated to backup vendor'),
    ('Corporate File Server Mumbai HO','offsite_copy_missing','config_drift','enable_offsite_replication','overdue',12.0,'Sysadmin Mumbai','2026-07-15',null,'Offsite job still disabled post NAS migration — past target date'),
    ('CCTV NVR Archive','backup_failure_spike','storage_capacity_exhausted','expand_storage_capacity','open',0.5,'Facilities IT','2026-08-25',null,'NVR disk at 96 percent — quote received for expansion shelf'),
    ('Payroll Processing DB','restore_test_overdue','staffing_gap','schedule_restore_drill','closed',4.0,'IT Ops Lead','2026-07-20','2026-07-18','Drill completed with finance sign-off; restore within RTO'),
    ('Warehouse WMS Bhiwandi','restore_test_failed','agent_version_mismatch','upgrade_backup_agent','in_progress',10.0,'Infra Engineer','2026-08-08',null,'App-tier agent upgraded on DR host; retest scheduled')
  ) as q(sys, fc, rc, ca, cst, drisk, own, tcd, acd, nt)
  join public.backup_dr_r3659 e
    on e.organization_id = v_org_id and e.system_name = q.sys;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) DR status distribution
create or replace function public.founder_r3659_dr_status_rollup()
returns table(dr_status text, systems bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.backup_dr_r3659)
  select l.dr_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.backup_dr_r3659 l
  group by l.dr_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3659_dr_status_rollup() from public, anon;
grant execute on function public.founder_r3659_dr_status_rollup() to authenticated;

-- 2) Backup-type scorecard
create or replace function public.founder_r3659_backup_type_scorecard()
returns table(
  backup_type text,
  total_systems bigint,
  verified bigint,
  test_overdue bigint,
  breached bigint,
  unprotected bigint,
  restore_passed bigint,
  offsite_gap bigint,
  avg_success_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.backup_type,
    count(*)::bigint,
    count(*) filter (where l.dr_status = 'verified')::bigint,
    count(*) filter (where l.dr_status = 'test_overdue')::bigint,
    count(*) filter (where l.dr_status = 'rpo_rto_breach')::bigint,
    count(*) filter (where l.dr_status = 'unprotected')::bigint,
    count(*) filter (where l.restore_test_passed = true)::bigint,
    count(*) filter (where l.offsite_copy = false)::bigint,
    round(avg(l.backup_success_pct), 2)
  from public.backup_dr_r3659 l
  group by l.backup_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3659_backup_type_scorecard() from public, anon;
grant execute on function public.founder_r3659_backup_type_scorecard() to authenticated;

-- 3) Tier × DR-status matrix
create or replace function public.founder_r3659_tier_dr_status_matrix()
returns table(tier text, dr_status text, systems bigint, restore_passed bigint, avg_success_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.tier, l.dr_status, count(*)::bigint,
    count(*) filter (where l.restore_test_passed = true)::bigint,
    round(avg(l.backup_success_pct), 2)
  from public.backup_dr_r3659 l
  group by l.tier, l.dr_status
  order by l.tier, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3659_tier_dr_status_matrix() from public, anon;
grant execute on function public.founder_r3659_tier_dr_status_matrix() to authenticated;

-- 4) Monthly restore-test trend
create or replace function public.founder_r3659_monthly_restore_test_trend()
returns table(test_month date, restore_tests bigint, tests_passed bigint, tests_failed bigint, avg_rpo_achieved_hrs numeric, avg_rto_achieved_hrs numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select (date_trunc('month', l.last_restore_test))::date,
    count(*)::bigint,
    count(*) filter (where l.restore_test_passed = true)::bigint,
    count(*) filter (where l.restore_test_passed = false)::bigint,
    round(avg(l.rpo_achieved_hrs), 1),
    round(avg(l.rto_achieved_hrs), 1)
  from public.backup_dr_r3659 l
  where l.last_restore_test is not null
  group by (date_trunc('month', l.last_restore_test))::date
  order by 1 desc;
end;
$$;

revoke execute on function public.founder_r3659_monthly_restore_test_trend() from public, anon;
grant execute on function public.founder_r3659_monthly_restore_test_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3659_capa_status_board()
returns table(capa_status text, findings bigint, avg_downtime_risk_hrs numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.downtime_risk_hrs)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.backup_dr_capa_actions_r3659 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3659_capa_status_board() from public, anon;
grant execute on function public.founder_r3659_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3659_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_downtime_risk_hrs numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.backup_dr_capa_actions_r3659)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.downtime_risk_hrs),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.backup_dr_capa_actions_r3659 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3659_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3659_root_cause_pareto() to authenticated;

-- 7) RPO/RTO breach digest
create or replace function public.founder_r3659_rpo_rto_breach_digest()
returns table(
  system_name text,
  tier text,
  rpo_target_hrs numeric,
  rpo_achieved_hrs numeric,
  rto_target_hrs numeric,
  rto_achieved_hrs numeric,
  dr_status text,
  trend_dir text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_name, l.tier,
    l.rpo_target_hrs, l.rpo_achieved_hrs,
    l.rto_target_hrs, l.rto_achieved_hrs,
    l.dr_status, l.trend_dir
  from public.backup_dr_r3659 l
  where l.dr_status = 'rpo_rto_breach'
     or l.rpo_achieved_hrs > l.rpo_target_hrs
     or l.rto_achieved_hrs > l.rto_target_hrs
  order by l.tier, l.system_name;
end;
$$;

revoke execute on function public.founder_r3659_rpo_rto_breach_digest() from public, anon;
grant execute on function public.founder_r3659_rpo_rto_breach_digest() to authenticated;

-- 8) High-risk queue (unprotected / breached / overdue / gaps)
create or replace function public.founder_r3659_high_risk_queue()
returns table(
  system_name text,
  backup_type text,
  tier text,
  dr_status text,
  backup_success_pct numeric,
  last_restore_test date,
  restore_test_passed boolean,
  offsite_copy boolean,
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
  select l.system_name, l.backup_type, l.tier, l.dr_status,
    l.backup_success_pct, l.last_restore_test, l.restore_test_passed,
    l.offsite_copy, l.trend_dir, l.notes
  from public.backup_dr_r3659 l
  where l.dr_status in ('unprotected','rpo_rto_breach','test_overdue')
     or l.restore_test_passed = false
     or l.offsite_copy = false
     or l.backup_success_pct < 95.0
  order by l.tier, l.system_name;
end;
$$;

revoke execute on function public.founder_r3659_high_risk_queue() from public, anon;
grant execute on function public.founder_r3659_high_risk_queue() to authenticated;
