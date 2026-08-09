-- Round 3682: Founder Premises Physical-Security / CCTV / Access-Control Board
-- Own-premises security — site × zone × security vendor × CCTV uptime × recording retention × access readers × guard deployment × tailgating × incident load × CAPA

-- =============================================================================
-- TABLE 1: physical_security_r3682 — per-site monthly physical-security audit facts
-- =============================================================================
create table if not exists public.physical_security_r3682 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  audit_code text not null,
  site_name text not null,
  security_vendor text not null,
  period_month date not null,
  cameras_total int not null,
  cameras_online int not null,
  cctv_uptime_pct numeric(5,1),
  recording_retention_days int not null,
  access_readers int not null,
  readers_faulty int not null,
  guard_posts int not null,
  guard_attendance_pct numeric(5,1),
  incidents_reported int not null,
  tailgating_events int not null,
  site_zone text not null check (site_zone in (
    'office','warehouse','refurb_center','server_room','parking_perimeter'
  )),
  security_status text not null check (security_status in (
    'secure','minor_gaps','coverage_gap','vendor_issue','vulnerable'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.physical_security_r3682 enable row level security;

create index if not exists idx_physical_security_r3682_org on public.physical_security_r3682(organization_id);
create index if not exists idx_physical_security_r3682_month on public.physical_security_r3682(period_month);
create index if not exists idx_physical_security_r3682_status on public.physical_security_r3682(security_status);

-- =============================================================================
-- TABLE 2: physical_security_capa_actions_r3682 — CAPA & security-hardening actions
-- =============================================================================
create table if not exists public.physical_security_capa_actions_r3682 (
  id uuid primary key default gen_random_uuid(),
  security_log_id uuid not null references public.physical_security_r3682(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'camera_downtime','recording_retention_shortfall','reader_fault',
    'guard_absenteeism','tailgating_breach','perimeter_blind_spot',
    'vendor_sla_miss','access_rights_stale'
  )),
  root_cause text not null check (root_cause in (
    'dvr_hard_disk_failure','camera_power_supply_fault','reader_controller_firmware_bug',
    'guard_vendor_understaffing','cabling_rodent_damage','layout_blind_spot',
    'badge_process_gap','vendor_sla_breach','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_dvr_disk','repair_camera_power','update_reader_firmware',
    'replace_reader','penalize_guard_vendor','add_camera_coverage',
    'recable_and_shield','revoke_stale_badges','retrain_guards','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.physical_security_capa_actions_r3682 enable row level security;

create index if not exists idx_physical_security_capa_r3682_log on public.physical_security_capa_actions_r3682(security_log_id);
create index if not exists idx_physical_security_capa_r3682_status on public.physical_security_capa_actions_r3682(capa_status);

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

  -- 16 physical-security audit rows
  insert into public.physical_security_r3682 (
    organization_id, audit_code, site_name, security_vendor, period_month,
    cameras_total, cameras_online, cctv_uptime_pct, recording_retention_days,
    access_readers, readers_faulty, guard_posts, guard_attendance_pct,
    incidents_reported, tailgating_events, site_zone, security_status, trend_dir, notes
  )
  select v_org_id, q.acode, q.site, q.vend, q.pmon::date,
    q.camt, q.camo, q.upct, q.rdays,
    q.ardr, q.rflt, q.gpost, q.gatt,
    q.incd, q.tgev, q.zone, q.sst, q.tdir, q.nt
  from (values
    ('PSA-MHQ-2607','Mumbai HQ','SIS Security','2026-07-01',
     48,47,99.1,30,12,0,4,98.5,0,1,'office','secure','stable','Lobby turnstile plus 12 readers healthy; one tailgate at cafeteria door counselled'),
    ('PSA-MSR-2607','Mumbai HQ Server Room','SIS Security','2026-07-01',
     8,8,99.8,90,4,0,1,100.0,0,0,'server_room','secure','improving','Biometric plus card two-factor at server room; 90-day retention verified'),
    ('PSA-CHN-2607','Chennai Branch','G4S India','2026-07-01',
     24,21,96.4,30,8,1,2,93.2,1,3,'office','minor_gaps','stable','Three tailgating events at rear entry; reader R-05 intermittent'),
    ('PSA-DLW-2607','Delhi Warehouse','Securitas India','2026-07-01',
     36,29,88.7,15,6,2,6,84.1,3,5,'warehouse','coverage_gap','worsening','Seven dock cameras dark after DVR disk failure; retention down to 15 days'),
    ('PSA-BRC-2607','Bengaluru Refurb Center','Checkmate Services','2026-07-01',
     30,28,97.6,30,10,1,3,95.8,1,2,'refurb_center','minor_gaps','improving','ESD bay reader firmware patched; two cameras awaiting lens swap'),
    ('PSA-MPK-2607','Mumbai HQ Parking','SIS Security','2026-07-01',
     16,11,81.3,30,2,1,2,88.9,2,4,'parking_perimeter','vulnerable','worsening','Perimeter blind spot near ramp B; patrol vehicle MH01AB1234 rounds increased'),
    ('PSA-CSR-2607','Chennai Server Room','G4S India','2026-07-01',
     6,6,99.6,90,3,0,1,99.0,0,0,'server_room','secure','stable','Rack-aisle cameras clean; access log audit matched HR roster'),
    ('PSA-DPK-2607','Delhi Warehouse Parking','Securitas India','2026-07-01',
     12,9,84.5,15,2,0,2,79.4,2,6,'parking_perimeter','vendor_issue','worsening','Night-shift guard absenteeism at gate 2; six tailgates behind trucks DL01GC7788'),
    ('PSA-MHQ-2606','Mumbai HQ','SIS Security','2026-06-01',
     48,46,98.4,30,12,1,4,97.2,1,2,'office','secure','stable','Visitor-badge printer outage one day; reader R-09 replaced'),
    ('PSA-CHN-2606','Chennai Branch','G4S India','2026-06-01',
     24,22,95.1,30,8,1,2,91.8,1,4,'office','minor_gaps','stable','Tailgating repeat offenders briefed; awning glare on camera C-14'),
    ('PSA-DLW-2606','Delhi Warehouse','Securitas India','2026-06-01',
     36,31,91.2,15,6,1,6,87.6,2,4,'warehouse','coverage_gap','worsening','Retention shortfall flagged in June audit; DVR disk order raised'),
    ('PSA-BRC-2606','Bengaluru Refurb Center','Checkmate Services','2026-06-01',
     30,27,95.9,30,10,2,3,94.3,1,3,'refurb_center','minor_gaps','improving','Two readers faulty at refurb stores; spares fitted first week of July'),
    ('PSA-MPK-2606','Mumbai HQ Parking','SIS Security','2026-06-01',
     16,13,86.8,30,2,0,2,90.2,1,3,'parking_perimeter','coverage_gap','worsening','Ramp-B camera power supply tripping; temporary guard post added'),
    ('PSA-MSR-2606','Mumbai HQ Server Room','SIS Security','2026-06-01',
     8,8,99.5,90,4,0,1,100.0,0,0,'server_room','secure','stable','Quarterly access-rights recertification completed with zero exceptions'),
    ('PSA-BPK-2607','Bengaluru Refurb Parking','Checkmate Services','2026-07-01',
     10,10,98.9,30,2,0,1,96.7,0,1,'parking_perimeter','secure','improving','New ANPR camera live at gate; service van KA03MN4521 movements logged'),
    ('PSA-CWH-2606','Chennai Branch Warehouse','G4S India','2026-06-01',
     18,15,89.9,15,4,1,3,85.5,2,3,'warehouse','vendor_issue','stable','Guard vendor missed two night musters; stale contractor badges found active')
  ) as q(acode, site, vend, pmon, camt, camo, upct, rdays, ardr, rflt, gpost, gatt, incd, tgev, zone, sst, tdir, nt);

  -- CAPA seed — attach to specific audits via audit_code
  insert into public.physical_security_capa_actions_r3682 (
    security_log_id, finding_category, root_cause, corrective_action,
    capa_status, estimated_cost_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.cost, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('PSA-DLW-2607','camera_downtime','dvr_hard_disk_failure','replace_dvr_disk','in_progress',58000.00,'Rajesh Nair (Admin Ops)','2026-07-20',null,'Replacement 8 TB surveillance disks in transit; dock cameras on temp NVR'),
    ('PSA-MPK-2607','perimeter_blind_spot','layout_blind_spot','add_camera_coverage','open',72000.00,'Meera Kulkarni (Facilities)','2026-07-25',null,'Two bullet cameras plus pole quoted for ramp-B blind spot'),
    ('PSA-DPK-2607','guard_absenteeism','guard_vendor_understaffing','penalize_guard_vendor','escalated',0.00,'Vikram Singh (Security Lead)','2026-07-15',null,'SLA penalty invoked on vendor; night-shift roster escalated to vendor RVP'),
    ('PSA-CHN-2607','tailgating_breach','badge_process_gap','retrain_guards','verification_pending',12000.00,'S. Lakshmi (Branch Admin)','2026-07-18',null,'Anti-tailgating drill done; verifying rear-entry counts for two weeks'),
    ('PSA-BRC-2607','reader_fault','reader_controller_firmware_bug','update_reader_firmware','closed',8500.00,'Arun Prasad (IT Infra)','2026-07-10','2026-07-08','Controller firmware 4.2.1 rollout fixed intermittent reader drops'),
    ('PSA-DLW-2606','recording_retention_shortfall','dvr_hard_disk_failure','replace_dvr_disk','overdue',61000.00,'Rajesh Nair (Admin Ops)','2026-06-30',null,'June retention CAPA past target — merged into July disk replacement'),
    ('PSA-MPK-2606','camera_downtime','camera_power_supply_fault','repair_camera_power','closed',9800.00,'Meera Kulkarni (Facilities)','2026-06-25','2026-06-22','SMPS replaced and surge protector added on ramp-B camera loop'),
    ('PSA-CWH-2606','access_rights_stale','badge_process_gap','revoke_stale_badges','in_progress',0.00,'S. Lakshmi (Branch Admin)','2026-07-12',null,'Eleven stale contractor badges revoked; weekly HR-to-ACS sync being wired')
  ) as q(acode, fc, rc, ca, cst, cost, own, tcd, acd, nt)
  join public.physical_security_r3682 e
    on e.organization_id = v_org_id and e.audit_code = q.acode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Security status distribution
create or replace function public.founder_r3682_security_status_rollup()
returns table(security_status text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.physical_security_r3682)
  select l.security_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.physical_security_r3682 l
  group by l.security_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3682_security_status_rollup() from public, anon;
grant execute on function public.founder_r3682_security_status_rollup() to authenticated;

-- 2) Security-vendor scorecard
create or replace function public.founder_r3682_vendor_scorecard()
returns table(
  security_vendor text,
  total_audits bigint,
  secure_sites bigint,
  minor_gap_sites bigint,
  gap_or_vulnerable bigint,
  avg_cctv_uptime_pct numeric,
  avg_guard_attendance_pct numeric,
  total_tailgating bigint,
  secure_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.security_vendor,
    count(*)::bigint,
    count(*) filter (where l.security_status = 'secure')::bigint,
    count(*) filter (where l.security_status = 'minor_gaps')::bigint,
    count(*) filter (where l.security_status in ('coverage_gap','vendor_issue','vulnerable'))::bigint,
    round(avg(l.cctv_uptime_pct), 1),
    round(avg(l.guard_attendance_pct), 1),
    coalesce(sum(l.tailgating_events),0)::bigint,
    round(100.0 * count(*) filter (where l.security_status = 'secure')::numeric / nullif(count(*),0), 1)
  from public.physical_security_r3682 l
  group by l.security_vendor
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3682_vendor_scorecard() from public, anon;
grant execute on function public.founder_r3682_vendor_scorecard() to authenticated;

-- 3) Site-zone × security-status matrix
create or replace function public.founder_r3682_zone_status_matrix()
returns table(site_zone text, security_status text, audits bigint, avg_cctv_uptime_pct numeric, total_incidents bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_zone, l.security_status, count(*)::bigint,
    round(avg(l.cctv_uptime_pct), 1),
    coalesce(sum(l.incidents_reported),0)::bigint
  from public.physical_security_r3682 l
  group by l.site_zone, l.security_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3682_zone_status_matrix() from public, anon;
grant execute on function public.founder_r3682_zone_status_matrix() to authenticated;

-- 4) Monthly uptime & attendance trend
create or replace function public.founder_r3682_monthly_uptime_trend()
returns table(period_month date, audits bigint, avg_cctv_uptime_pct numeric, avg_guard_attendance_pct numeric, total_incidents bigint, total_tailgating bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.cctv_uptime_pct), 1),
    round(avg(l.guard_attendance_pct), 1),
    coalesce(sum(l.incidents_reported),0)::bigint,
    coalesce(sum(l.tailgating_events),0)::bigint
  from public.physical_security_r3682 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3682_monthly_uptime_trend() from public, anon;
grant execute on function public.founder_r3682_monthly_uptime_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3682_capa_status_board()
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
  from public.physical_security_capa_actions_r3682 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3682_capa_status_board() from public, anon;
grant execute on function public.founder_r3682_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3682_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.physical_security_capa_actions_r3682)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.physical_security_capa_actions_r3682 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3682_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3682_root_cause_pareto() to authenticated;

-- 7) Coverage-gap digest (offline cameras / faulty readers by site)
create or replace function public.founder_r3682_coverage_gap_digest()
returns table(
  site_name text,
  site_zone text,
  audits bigint,
  cameras_offline bigint,
  faulty_readers bigint,
  tailgating_total bigint,
  incidents_total bigint,
  worst_uptime_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.site_zone,
    count(*)::bigint,
    coalesce(sum(l.cameras_total - l.cameras_online),0)::bigint,
    coalesce(sum(l.readers_faulty),0)::bigint,
    coalesce(sum(l.tailgating_events),0)::bigint,
    coalesce(sum(l.incidents_reported),0)::bigint,
    min(l.cctv_uptime_pct)
  from public.physical_security_r3682 l
  where l.security_status in ('coverage_gap','vendor_issue','vulnerable')
     or l.cameras_online < l.cameras_total
     or l.readers_faulty > 0
  group by l.site_name, l.site_zone
  order by coalesce(sum(l.cameras_total - l.cameras_online),0) desc, l.site_name;
end;
$$;

revoke all on function public.founder_r3682_coverage_gap_digest() from public, anon;
grant execute on function public.founder_r3682_coverage_gap_digest() to authenticated;

-- 8) High-risk site queue (vulnerable / coverage-gap)
create or replace function public.founder_r3682_high_risk_queue()
returns table(
  audit_code text,
  site_name text,
  site_zone text,
  security_vendor text,
  period_month date,
  security_status text,
  cctv_uptime_pct numeric,
  guard_attendance_pct numeric,
  tailgating_events int,
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
  select l.audit_code, l.site_name, l.site_zone, l.security_vendor, l.period_month,
    l.security_status, l.cctv_uptime_pct, l.guard_attendance_pct,
    l.tailgating_events, l.trend_dir, l.notes
  from public.physical_security_r3682 l
  where l.security_status in ('vulnerable','coverage_gap','vendor_issue')
     or l.cctv_uptime_pct < 90.0
     or l.guard_attendance_pct < 85.0
     or l.tailgating_events >= 4
  order by l.period_month desc, l.cctv_uptime_pct asc;
end;
$$;

revoke all on function public.founder_r3682_high_risk_queue() from public, anon;
grant execute on function public.founder_r3682_high_risk_queue() to authenticated;
