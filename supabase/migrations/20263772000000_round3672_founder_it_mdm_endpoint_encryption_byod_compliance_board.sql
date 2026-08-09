-- Round 3672: IT MDM / Endpoint-Encryption / BYOD Compliance Board
-- IT governance — MDM enrollment × endpoint encryption × OS patching × jailbreak/root detection × BYOD policy × remote-wipe readiness per device fleet × CAPA

-- =============================================================================
-- TABLE 1: mdm_endpoint_r3672 — per-fleet MDM / endpoint compliance snapshots
-- =============================================================================
create table if not exists public.mdm_endpoint_r3672 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  fleet_code text not null,
  fleet_name text not null,
  os_platform text not null check (os_platform in (
    'windows','macos','android','ios','linux'
  )),
  period_month date not null,
  devices_total int not null,
  mdm_enrolled int not null,
  enrollment_pct numeric(5,2),
  encrypted_pct numeric(5,2),
  os_patched_pct numeric(5,2),
  jailbroken_rooted int not null default 0,
  byod_devices int not null default 0,
  remote_wipe_ready_pct numeric(5,2),
  non_compliant_devices int not null default 0,
  device_class text not null check (device_class in (
    'company_laptop','company_mobile','byod_mobile','field_tablet','shared_kiosk'
  )),
  compliance_status text not null check (compliance_status in (
    'compliant','minor_gap','exposure','high_risk','unmanaged'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mdm_endpoint_r3672 enable row level security;

create index if not exists idx_mdm_endpoint_r3672_org on public.mdm_endpoint_r3672(organization_id);
create index if not exists idx_mdm_endpoint_r3672_month on public.mdm_endpoint_r3672(period_month);
create index if not exists idx_mdm_endpoint_r3672_status on public.mdm_endpoint_r3672(compliance_status);

-- =============================================================================
-- TABLE 2: mdm_endpoint_capa_actions_r3672 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.mdm_endpoint_capa_actions_r3672 (
  id uuid primary key default gen_random_uuid(),
  endpoint_log_id uuid not null references public.mdm_endpoint_r3672(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'enrollment_gap','encryption_gap','patch_lag','jailbreak_detected',
    'byod_policy_violation','remote_wipe_untested','unmanaged_devices',
    'mdm_agent_outdated','cert_profile_expired','shadow_it_device'
  )),
  root_cause text not null check (root_cause in (
    'mdm_license_shortfall','user_enrollment_resistance','legacy_os_unsupported',
    'agent_deployment_failure','byod_policy_undefined','patch_ring_misconfigured',
    'asset_register_stale','vendor_api_outage','pending_investigation','field_connectivity_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'force_enrollment_campaign','enable_full_disk_encryption','push_os_patch_ring',
    'quarantine_jailbroken_device','rollout_byod_policy','remote_wipe_drill',
    'procure_mdm_licenses','redeploy_mdm_agent','retire_legacy_devices',
    'update_asset_register','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  exposure_level text not null check (exposure_level in (
    'critical','high','medium','low','informational'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mdm_endpoint_capa_actions_r3672 enable row level security;

create index if not exists idx_mdm_endpoint_capa_r3672_log on public.mdm_endpoint_capa_actions_r3672(endpoint_log_id);
create index if not exists idx_mdm_endpoint_capa_r3672_status on public.mdm_endpoint_capa_actions_r3672(capa_status);

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

  -- 16 fleet compliance snapshot rows
  insert into public.mdm_endpoint_r3672 (
    organization_id, fleet_code, fleet_name, os_platform, period_month,
    devices_total, mdm_enrolled, enrollment_pct, encrypted_pct, os_patched_pct,
    jailbroken_rooted, byod_devices, remote_wipe_ready_pct, non_compliant_devices,
    device_class, compliance_status, trend_dir, notes
  )
  select v_org_id, q.fcode, q.fname, q.osp, q.pmon::date,
    q.dtot, q.denr, q.epct, q.encp, q.patp,
    q.jbr, q.byod, q.rwp, q.ncd,
    q.dcls, q.cst, q.trd, q.nt
  from (values
    ('FLT-HQWIN-07','HQ Corporate Laptops','windows','2026-07-01',
     420,412,98.1,97.4,93.2,0,0,96.0,9,'company_laptop','compliant','stable','Intune ring healthy; nine laptops pending July cumulative patch'),
    ('FLT-FSEAND-07','Field Service Engineer Phones','android','2026-07-01',
     310,301,97.1,95.8,88.7,2,0,91.5,14,'company_mobile','minor_gap','improving','Two rooted handsets quarantined; patch ring lagging in tier-2 towns'),
    ('FLT-SALESIOS-07','Sales and KAM iPhones','ios','2026-07-01',
     146,144,98.6,100.0,96.5,0,0,98.0,3,'company_mobile','compliant','improving','Supervised iOS fleet via ABM; enrollment near-total'),
    ('FLT-BYODAND-07','BYOD Android — Ops and Support','android','2026-07-01',
     210,138,65.7,71.2,62.4,5,210,54.0,72,'byod_mobile','high_risk','worsening','BYOD work-profile adoption stalling; five rooted devices detected'),
    ('FLT-BYODIOS-07','BYOD iOS — Managers','ios','2026-07-01',
     88,71,80.7,92.3,84.1,0,88,70.5,17,'byod_mobile','exposure','stable','User-enrollment BYOD; remote-wipe readiness below policy floor'),
    ('FLT-MACDES-07','Design and Engineering MacBooks','macos','2026-07-01',
     64,63,98.4,100.0,95.3,0,0,97.0,1,'company_laptop','compliant','stable','FileVault enforced via Jamf; one loaner pending enrollment'),
    ('FLT-DEMOTAB-07','Clinical Demo Tablets','android','2026-07-01',
     95,88,92.6,90.5,79.4,1,0,83.0,11,'field_tablet','minor_gap','improving','Demo tablets on kiosk profile; agent 7.2 push failing on eleven units'),
    ('FLT-WHKSK-07','Warehouse Scanning Kiosks','android','2026-07-01',
     36,29,80.6,68.9,55.2,0,0,42.0,12,'shared_kiosk','exposure','worsening','Legacy Android 9 kiosks unsupported by latest MDM agent'),
    ('FLT-SRVTAB-07','Service Engineer Field Tablets','android','2026-07-01',
     124,120,96.8,94.2,86.9,1,0,89.5,8,'field_tablet','minor_gap','stable','Calibration-app tablets; one rooted unit wiped and re-imaged'),
    ('FLT-CONLEG-07','Legacy Contractor Laptops','windows','2026-07-01',
     28,9,32.1,41.8,38.6,0,12,18.0,19,'company_laptop','unmanaged','worsening','Contractor laptops outside Intune scope — onboarding CAPA open'),
    ('FLT-HQWIN-06','HQ Corporate Laptops','windows','2026-06-01',
     415,404,97.3,96.8,91.5,0,0,95.0,12,'company_laptop','compliant','stable','June baseline before patch-ring reconfiguration'),
    ('FLT-BYODAND-06','BYOD Android — Ops and Support','android','2026-06-01',
     205,146,71.2,74.6,66.1,3,205,58.5,61,'byod_mobile','exposure','worsening','Work-profile opt-outs rising after stipend freeze'),
    ('FLT-WHKSK-06','Warehouse Scanning Kiosks','android','2026-06-01',
     36,31,86.1,72.4,58.9,0,0,47.0,10,'shared_kiosk','exposure','worsening','Two kiosks dropped off MDM after OS image rollback'),
    ('FLT-HQWIN-05','HQ Corporate Laptops','windows','2026-05-01',
     408,395,96.8,96.1,90.2,0,0,94.0,14,'company_laptop','compliant','stable','May snapshot; BitLocker coverage steady'),
    ('FLT-BYODAND-05','BYOD Android — Ops and Support','android','2026-05-01',
     198,152,76.8,78.3,70.5,1,198,63.0,49,'byod_mobile','minor_gap','stable','BYOD program pre-decline baseline'),
    ('FLT-FSEAND-05','Field Service Engineer Phones','android','2026-05-01',
     302,288,95.4,93.7,84.2,3,0,87.0,21,'company_mobile','minor_gap','improving','Three rooted handsets found during May sweep')
  ) as q(fcode, fname, osp, pmon, dtot, denr, epct, encp, patp, jbr, byod, rwp, ncd, dcls, cst, trd, nt);

  -- CAPA seed — attach to specific fleet snapshots via fleet_code
  insert into public.mdm_endpoint_capa_actions_r3672 (
    endpoint_log_id, finding_category, root_cause, corrective_action,
    capa_status, exposure_level, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.exl, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FLT-BYODAND-07','enrollment_gap','user_enrollment_resistance','rollout_byod_policy','in_progress','critical','Ravi Kulkarni (IT Ops)','2026-07-20',null,180000.00,'BYOD work-profile mandate plus stipend comms drafted; HR sign-off pending'),
    ('FLT-CONLEG-07','unmanaged_devices','asset_register_stale','force_enrollment_campaign','escalated','critical','Meera Nair (IT Security)','2026-07-15',null,95000.00,'Contractor laptops missing from CMDB — vendor onboarding escalated to CISO'),
    ('FLT-WHKSK-07','patch_lag','legacy_os_unsupported','retire_legacy_devices','open','high','Arjun Shetty (Infra)','2026-07-31',null,420000.00,'Android 9 kiosks end-of-life — rugged replacement tablets quoted'),
    ('FLT-FSEAND-07','jailbreak_detected','pending_investigation','quarantine_jailbroken_device','closed','high','Ravi Kulkarni (IT Ops)','2026-07-08','2026-07-05',0.00,'Two rooted handsets wiped and re-imaged; users counselled'),
    ('FLT-BYODIOS-07','remote_wipe_untested','byod_policy_undefined','remote_wipe_drill','verification_pending','medium','Meera Nair (IT Security)','2026-07-18',null,12000.00,'Wipe drill run on ten-device sample — evidence under review'),
    ('FLT-DEMOTAB-07','mdm_agent_outdated','agent_deployment_failure','redeploy_mdm_agent','in_progress','medium','Arjun Shetty (Infra)','2026-07-22',null,8000.00,'Agent 7.2 push failing on eleven tablets — staged rollout in progress'),
    ('FLT-HQWIN-07','encryption_gap','patch_ring_misconfigured','enable_full_disk_encryption','closed','low','Divya Prasad (EUC)','2026-07-10','2026-07-07',5000.00,'BitLocker re-enabled on nine rebuilt laptops; ring config fixed'),
    ('FLT-SRVTAB-07','patch_lag','field_connectivity_gap','push_os_patch_ring','overdue','high','Arjun Shetty (Infra)','2026-06-30',null,26000.00,'Field tablets miss patch window on low-bandwidth sites — offline patch kits shipping')
  ) as q(fcode, fc, rc, ca, cst, exl, own, tcd, acd, cost, nt)
  join public.mdm_endpoint_r3672 e
    on e.organization_id = v_org_id and e.fleet_code = q.fcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance status distribution
create or replace function public.founder_r3672_compliance_status_rollup()
returns table(compliance_status text, fleets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mdm_endpoint_r3672)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.mdm_endpoint_r3672 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3672_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3672_compliance_status_rollup() to authenticated;

-- 2) OS platform scorecard
create or replace function public.founder_r3672_os_platform_scorecard()
returns table(
  os_platform text,
  fleets bigint,
  devices bigint,
  enrolled bigint,
  avg_enrollment_pct numeric,
  avg_encrypted_pct numeric,
  avg_patched_pct numeric,
  jailbroken bigint,
  non_compliant bigint,
  compliant_fleet_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.os_platform,
    count(*)::bigint,
    coalesce(sum(l.devices_total),0)::bigint,
    coalesce(sum(l.mdm_enrolled),0)::bigint,
    round(avg(l.enrollment_pct), 1),
    round(avg(l.encrypted_pct), 1),
    round(avg(l.os_patched_pct), 1),
    coalesce(sum(l.jailbroken_rooted),0)::bigint,
    coalesce(sum(l.non_compliant_devices),0)::bigint,
    round(100.0 * count(*) filter (where l.compliance_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.mdm_endpoint_r3672 l
  group by l.os_platform
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3672_os_platform_scorecard() from public, anon;
grant execute on function public.founder_r3672_os_platform_scorecard() to authenticated;

-- 3) Device-class × compliance-status matrix
create or replace function public.founder_r3672_device_class_status_matrix()
returns table(device_class text, compliance_status text, fleets bigint, devices bigint, avg_enrollment_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_class, l.compliance_status, count(*)::bigint,
    coalesce(sum(l.devices_total),0)::bigint,
    round(avg(l.enrollment_pct), 1)
  from public.mdm_endpoint_r3672 l
  group by l.device_class, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3672_device_class_status_matrix() from public, anon;
grant execute on function public.founder_r3672_device_class_status_matrix() to authenticated;

-- 4) Monthly enrollment trend
create or replace function public.founder_r3672_monthly_enrollment_trend()
returns table(period_month date, fleets bigint, devices bigint, enrolled bigint, avg_enrollment_pct numeric, avg_encrypted_pct numeric, non_compliant bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.devices_total),0)::bigint,
    coalesce(sum(l.mdm_enrolled),0)::bigint,
    round(avg(l.enrollment_pct), 1),
    round(avg(l.encrypted_pct), 1),
    coalesce(sum(l.non_compliant_devices),0)::bigint
  from public.mdm_endpoint_r3672 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3672_monthly_enrollment_trend() from public, anon;
grant execute on function public.founder_r3672_monthly_enrollment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3672_capa_status_board()
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
  from public.mdm_endpoint_capa_actions_r3672 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3672_capa_status_board() from public, anon;
grant execute on function public.founder_r3672_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3672_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mdm_endpoint_capa_actions_r3672)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.mdm_endpoint_capa_actions_r3672 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3672_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3672_root_cause_pareto() to authenticated;

-- 7) Exposure digest
create or replace function public.founder_r3672_exposure_digest()
returns table(exposure_level text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.exposure_level, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.mdm_endpoint_capa_actions_r3672 c
  group by c.exposure_level
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3672_exposure_digest() from public, anon;
grant execute on function public.founder_r3672_exposure_digest() to authenticated;

-- 8) High-risk fleet queue
create or replace function public.founder_r3672_high_risk_queue()
returns table(
  fleet_code text,
  fleet_name text,
  os_platform text,
  device_class text,
  period_month date,
  compliance_status text,
  enrollment_pct numeric,
  encrypted_pct numeric,
  jailbroken_rooted int,
  non_compliant_devices int,
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
  select l.fleet_code, l.fleet_name, l.os_platform, l.device_class, l.period_month,
    l.compliance_status, l.enrollment_pct, l.encrypted_pct, l.jailbroken_rooted,
    l.non_compliant_devices, l.trend_dir, l.notes
  from public.mdm_endpoint_r3672 l
  where l.compliance_status in ('exposure','high_risk','unmanaged')
     or l.jailbroken_rooted > 0
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.fleet_name;
end;
$$;

revoke all on function public.founder_r3672_high_risk_queue() from public, anon;
grant execute on function public.founder_r3672_high_risk_queue() to authenticated;
