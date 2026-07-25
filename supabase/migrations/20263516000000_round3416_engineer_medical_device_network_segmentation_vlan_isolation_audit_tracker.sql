-- Round 3416: Engineer Medical-Device Network-Segmentation & VLAN-Isolation Audit Tracker
-- Networked medical devices must be isolated on segmented VLANs from hospital IT to reduce cyber risk.
-- Per device/segment field-audit — equipment type × region × isolation/hardening controls × open vulns × segmentation verdict × CAPA hardening actions

-- =============================================================================
-- TABLE 1: device_net_segmentation_r3416 — per-device network-segmentation field audit
-- =============================================================================
create table if not exists public.device_net_segmentation_r3416 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  region text not null check (region in (
    'north','south','east','west','central','northeast'
  )),
  equipment_type text not null check (equipment_type in (
    'imaging_pacs','patient_monitoring','lab_analyzer','infusion_pump_network','ot_integration','dialysis_network'
  )),
  device_code text not null,
  audit_date date not null,
  on_isolated_vlan boolean not null,
  firewall_rules_reviewed boolean not null,
  default_credentials_changed boolean not null,
  unnecessary_ports_closed boolean not null,
  os_patch_current boolean not null,
  antivirus_or_whitelist_ok text not null check (antivirus_or_whitelist_ok in (
    'ok','outdated','not_applicable','none'
  )),
  remote_access_controlled boolean not null,
  data_at_rest_encrypted boolean not null,
  vulnerability_scan_done boolean not null,
  open_vulnerabilities int not null default 0,
  segmentation_verdict text not null check (segmentation_verdict in (
    'fully_isolated','minor_gap','segmentation_missing','critical_exposure','remediated'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.device_net_segmentation_r3416 enable row level security;

create index if not exists idx_device_net_seg_r3416_org on public.device_net_segmentation_r3416(organization_id);
create index if not exists idx_device_net_seg_r3416_date on public.device_net_segmentation_r3416(audit_date);
create index if not exists idx_device_net_seg_r3416_verdict on public.device_net_segmentation_r3416(segmentation_verdict);

-- =============================================================================
-- TABLE 2: device_net_segmentation_capa_actions_r3416 — hardening / isolation CAPA actions
-- =============================================================================
create table if not exists public.device_net_segmentation_capa_actions_r3416 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.device_net_segmentation_r3416(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'not_on_isolated_vlan','firewall_rules_gap','default_credentials_present',
    'open_unnecessary_ports','os_unpatched','antivirus_outdated',
    'remote_access_uncontrolled','data_not_encrypted','vulnerability_scan_missing','open_vulnerabilities_high'
  )),
  root_cause text not null check (root_cause in (
    'legacy_flat_network','vendor_default_config','patch_incompatibility','unmanaged_vendor_access',
    'missing_network_documentation','end_of_life_os','misconfigured_firewall',
    'pending_investigation','budget_constraint','no_asset_owner'
  )),
  hardening_action text not null check (hardening_action in (
    'migrate_to_isolated_vlan','tighten_firewall_rules','rotate_credentials','close_unused_ports',
    'apply_os_patches','update_antivirus_whitelist','enforce_remote_access_control',
    'enable_disk_encryption','run_vulnerability_scan','isolate_and_monitor','oem_coordination','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  exposure_impact text not null check (exposure_impact in (
    'hipaa_phi_exposure','patient_safety_risk','ransomware_risk','none','internal_only','regulatory_finding'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.device_net_segmentation_capa_actions_r3416 enable row level security;

create index if not exists idx_device_net_seg_capa_r3416_audit on public.device_net_segmentation_capa_actions_r3416(audit_id);
create index if not exists idx_device_net_seg_capa_r3416_status on public.device_net_segmentation_capa_actions_r3416(capa_status);

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

  -- 14 network-segmentation audit rows
  insert into public.device_net_segmentation_r3416 (
    organization_id, engineer_name, hospital_name, region, equipment_type, device_code, audit_date,
    on_isolated_vlan, firewall_rules_reviewed, default_credentials_changed, unnecessary_ports_closed, os_patch_current,
    antivirus_or_whitelist_ok, remote_access_controlled, data_at_rest_encrypted, vulnerability_scan_done, open_vulnerabilities,
    segmentation_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.reg, q.etype, q.dcode, q.adate::date,
    q.vlan, q.fw, q.creds, q.ports, q.ospatch,
    q.av, q.remote, q.encrypt, q.vscan, q.openvuln,
    q.verdict, q.nt
  from (values
    ('Ravi Kumar','Apollo Chennai','south','imaging_pacs','PACS-APL-01','2026-07-10',
     true,true,true,true,true,'ok',true,true,true,0,'fully_isolated','PACS on dedicated imaging VLAN, all hardening controls verified'),
    ('Ravi Kumar','Apollo Chennai','south','patient_monitoring','MON-APL-02','2026-07-10',
     true,true,true,true,false,'outdated',true,true,true,2,'minor_gap','Monitors isolated but OS patch backlog and AV signatures outdated'),
    ('Anjali Nair','Fortis Gurgaon','north','infusion_pump_network','INF-FRT-11','2026-07-09',
     false,false,false,false,false,'none',false,false,false,9,'critical_exposure','Infusion pumps on flat hospital IT LAN, default creds, no scan'),
    ('Anjali Nair','Fortis Gurgaon','north','lab_analyzer','LAB-FRT-12','2026-07-09',
     true,true,false,true,true,'ok',true,false,true,3,'minor_gap','Analyzer on VLAN but default vendor creds present and data unencrypted'),
    ('Suresh Rao','Manipal Bengaluru','south','ot_integration','OTI-MNP-21','2026-07-08',
     true,true,true,true,true,'ok',true,true,true,0,'fully_isolated','OT integration segment fully isolated with controlled remote access'),
    ('Suresh Rao','Manipal Bengaluru','south','dialysis_network','DIA-MNP-22','2026-07-08',
     false,true,true,false,false,'outdated',true,true,false,5,'segmentation_missing','Dialysis network shares subnet with staff Wi-Fi, EOL OS, no scan'),
    ('Deepa Menon','AIIMS Delhi','north','imaging_pacs','PACS-AIM-31','2026-07-07',
     true,false,true,false,false,'outdated',false,true,true,6,'minor_gap','PACS isolated but firewall rules unreviewed, ports open, AV outdated'),
    ('Deepa Menon','AIIMS Delhi','north','patient_monitoring','MON-AIM-32','2026-07-07',
     false,false,false,false,false,'none',false,false,false,11,'critical_exposure','Central station reachable from IT LAN, default creds, no controls'),
    ('John Varghese','CMC Vellore','south','lab_analyzer','LAB-CMC-41','2026-07-06',
     true,true,true,true,true,'ok',true,true,true,0,'fully_isolated','Lab analyzer segment isolated and hardened, clean scan'),
    ('John Varghese','CMC Vellore','south','infusion_pump_network','INF-CMC-42','2026-07-06',
     true,true,true,true,false,'not_applicable',true,false,true,4,'minor_gap','Pump gateway isolated, embedded OS unpatched, data unencrypted'),
    ('Kiran Reddy','KIMS Hyderabad','south','ot_integration','OTI-KIM-51','2026-07-05',
     true,true,true,true,true,'ok',true,true,true,1,'remediated','Previously flat; migrated to isolated VLAN and rescanned, 1 low residual'),
    ('Kiran Reddy','KIMS Hyderabad','south','dialysis_network','DIA-KIM-52','2026-07-05',
     false,false,true,false,false,'outdated',false,true,false,7,'segmentation_missing','Dialysis units on shared VLAN, firewall gaps, remote access open'),
    ('Meera Iyer','Yashoda Hyderabad','south','imaging_pacs','PACS-YSH-61','2026-07-04',
     true,true,true,true,true,'ok',true,true,true,0,'fully_isolated','Imaging VLAN isolated, all controls pass, quarterly scan clean'),
    ('Arjun Singh','Kokilaben Mumbai','west','infusion_pump_network','INF-KKB-71','2026-07-04',
     false,false,false,false,false,'none',false,false,false,14,'critical_exposure','Legacy pump network fully exposed to IT LAN — urgent isolation needed')
  ) as q(eng, hosp, reg, etype, dcode, adate, vlan, fw, creds, ports, ospatch, av, remote, encrypt, vscan, openvuln, verdict, nt);

  -- CAPA seed — attach to specific audits via device_code
  insert into public.device_net_segmentation_capa_actions_r3416 (
    audit_id, finding_category, root_cause, hardening_action,
    capa_status, exposure_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ha,
    q.cst, q.ei, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('INF-FRT-11','not_on_isolated_vlan','legacy_flat_network','migrate_to_isolated_vlan','in_progress','ransomware_risk','2026-07-20',null,120000.00,'Design dedicated pump VLAN and re-cable switch ports'),
    ('MON-AIM-32','default_credentials_present','vendor_default_config','rotate_credentials','open','patient_safety_risk','2026-07-18',null,15000.00,'Rotate default monitoring creds and lock down management ports'),
    ('DIA-MNP-22','os_unpatched','end_of_life_os','apply_os_patches','escalated','regulatory_finding','2026-07-15',null,85000.00,'EOL OS on dialysis gateway — escalate OEM upgrade or isolate-and-monitor'),
    ('INF-KKB-71','not_on_isolated_vlan','legacy_flat_network','migrate_to_isolated_vlan','open','ransomware_risk','2026-07-22',null,150000.00,'Full segmentation project for legacy infusion pump fleet'),
    ('LAB-FRT-12','data_not_encrypted','misconfigured_firewall','enable_disk_encryption','verification_pending','hipaa_phi_exposure','2026-07-16',null,40000.00,'Enable disk encryption and re-verify firewall egress rules'),
    ('DIA-KIM-52','firewall_rules_gap','misconfigured_firewall','tighten_firewall_rules','overdue','regulatory_finding','2026-07-12',null,30000.00,'Firewall hardening past target date — vendor change window pending'),
    ('PACS-AIM-31','antivirus_outdated','patch_incompatibility','update_antivirus_whitelist','closed','internal_only','2026-07-14','2026-07-13',22000.00,'Deployed application whitelisting compatible with PACS workstation')
  ) as q(dcode, fc, rc, ha, cst, ei, tcd, acd, cost, nt)
  join public.device_net_segmentation_r3416 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Segmentation verdict distribution
create or replace function public.founder_r3416_segmentation_verdict_rollup()
returns table(segmentation_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.device_net_segmentation_r3416)
  select l.segmentation_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.device_net_segmentation_r3416 l
  group by l.segmentation_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3416_segmentation_verdict_rollup() from public, anon;
grant execute on function public.founder_r3416_segmentation_verdict_rollup() to authenticated;

-- 2) Hospital-level segmentation scorecard
create or replace function public.founder_r3416_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fully_isolated bigint,
  minor_gap bigint,
  exposed bigint,
  not_on_vlan bigint,
  default_creds_present bigint,
  open_vuln_total bigint,
  isolated_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.segmentation_verdict in ('fully_isolated','remediated'))::bigint,
    count(*) filter (where l.segmentation_verdict = 'minor_gap')::bigint,
    count(*) filter (where l.segmentation_verdict in ('segmentation_missing','critical_exposure'))::bigint,
    count(*) filter (where l.on_isolated_vlan = false)::bigint,
    count(*) filter (where l.default_credentials_changed = false)::bigint,
    coalesce(sum(l.open_vulnerabilities),0)::bigint,
    round(100.0 * count(*) filter (where l.segmentation_verdict in ('fully_isolated','remediated'))::numeric / nullif(count(*),0), 1)
  from public.device_net_segmentation_r3416 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3416_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3416_hospital_scorecard() to authenticated;

-- 3) Equipment-type × region matrix
create or replace function public.founder_r3416_equipment_region_matrix()
returns table(equipment_type text, region text, audits bigint, fully_isolated bigint, exposed bigint, avg_open_vulnerabilities numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.region, count(*)::bigint,
    count(*) filter (where l.segmentation_verdict in ('fully_isolated','remediated'))::bigint,
    count(*) filter (where l.segmentation_verdict in ('segmentation_missing','critical_exposure'))::bigint,
    round(avg(l.open_vulnerabilities), 2)
  from public.device_net_segmentation_r3416 l
  group by l.equipment_type, l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3416_equipment_region_matrix() from public, anon;
grant execute on function public.founder_r3416_equipment_region_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3416_daily_audit_trend()
returns table(audit_date date, audits bigint, fully_isolated bigint, exposed bigint, not_on_vlan bigint, open_vuln_total bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.segmentation_verdict in ('fully_isolated','remediated'))::bigint,
    count(*) filter (where l.segmentation_verdict in ('segmentation_missing','critical_exposure'))::bigint,
    count(*) filter (where l.on_isolated_vlan = false)::bigint,
    coalesce(sum(l.open_vulnerabilities),0)::bigint
  from public.device_net_segmentation_r3416 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3416_daily_audit_trend() from public, anon;
grant execute on function public.founder_r3416_daily_audit_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3416_capa_status_board()
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
  from public.device_net_segmentation_capa_actions_r3416 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3416_capa_status_board() from public, anon;
grant execute on function public.founder_r3416_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3416_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.device_net_segmentation_capa_actions_r3416)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.device_net_segmentation_capa_actions_r3416 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3416_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3416_root_cause_pareto() to authenticated;

-- 7) Exposure impact digest
create or replace function public.founder_r3416_exposure_impact_digest()
returns table(exposure_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.exposure_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.device_net_segmentation_capa_actions_r3416 c
  group by c.exposure_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3416_exposure_impact_digest() from public, anon;
grant execute on function public.founder_r3416_exposure_impact_digest() to authenticated;

-- 8) High-risk exposure queue (top individual concerns)
create or replace function public.founder_r3416_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  equipment_type text,
  region text,
  audit_date date,
  segmentation_verdict text,
  antivirus_or_whitelist_ok text,
  open_vulnerabilities int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.equipment_type, l.region, l.audit_date,
    l.segmentation_verdict, l.antivirus_or_whitelist_ok, l.open_vulnerabilities, l.notes
  from public.device_net_segmentation_r3416 l
  where l.segmentation_verdict in ('minor_gap','segmentation_missing','critical_exposure')
     or l.on_isolated_vlan = false
     or l.firewall_rules_reviewed = false
     or l.default_credentials_changed = false
     or l.unnecessary_ports_closed = false
     or l.os_patch_current = false
     or l.antivirus_or_whitelist_ok in ('outdated','none')
     or l.remote_access_controlled = false
     or l.data_at_rest_encrypted = false
     or l.vulnerability_scan_done = false
     or l.open_vulnerabilities > 0
  order by l.open_vulnerabilities desc, l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3416_high_risk_queue() from public, anon;
grant execute on function public.founder_r3416_high_risk_queue() to authenticated;
