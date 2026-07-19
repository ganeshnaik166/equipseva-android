-- Round 3368: Engineer Device Software-License & Feature-Key Entitlement Compliance Tracker
-- Post-service entitlement log — equipment type × license module × license type × activation status × expiry × post-service reactivation × unused-paid rationalization × entitlement verdict × CAPA

-- =============================================================================
-- TABLE 1: device_license_r3368 — per device-license entitlement records
-- =============================================================================
create table if not exists public.device_license_r3368 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  equipment_type text not null check (equipment_type in (
    'imaging_workstation','ultrasound_advanced','lab_analyzer',
    'patient_monitor_central','cardiology_reporting','dose_management'
  )),
  oem_vendor text not null,
  license_module text not null check (license_module in (
    'advanced_cardiac','dose_reporting','ai_detection',
    '3d_reconstruction','connectivity_hl7','analytics_pack'
  )),
  license_type text not null check (license_type in (
    'perpetual','annual_subscription','feature_key','concurrent_seat','trial'
  )),
  activation_status text not null check (activation_status in (
    'active','expired','grace_period','not_activated','trial_expiring'
  )),
  expiry_date date,
  days_to_expiry int,
  post_service_reactivation_needed boolean not null default false,
  reactivation_done boolean not null default false,
  unused_licensed_feature boolean not null default false,
  entitlement_verdict text not null check (entitlement_verdict in (
    'compliant','renewal_action','reactivate_now','expired_downtime_risk','unused_cost_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.device_license_r3368 enable row level security;

create index if not exists idx_device_license_r3368_org on public.device_license_r3368(organization_id);
create index if not exists idx_device_license_r3368_expiry on public.device_license_r3368(expiry_date);
create index if not exists idx_device_license_r3368_verdict on public.device_license_r3368(entitlement_verdict);

-- =============================================================================
-- TABLE 2: device_license_capa_actions_r3368 — CAPA & entitlement actions
-- =============================================================================
create table if not exists public.device_license_capa_actions_r3368 (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.device_license_r3368(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'license_expired_downtime','feature_key_not_reactivated','trial_expiring_unrenewed',
    'unused_paid_license','grace_period_breach','concurrent_seat_overuse',
    'oem_reactivation_pending','renewal_po_delay','entitlement_mismatch','activation_after_service'
  )),
  root_cause text not null check (root_cause in (
    'post_service_key_not_reapplied','renewal_po_not_raised','vendor_activation_delay',
    'license_server_offline','feature_never_deployed','seat_count_underprovisioned',
    'contract_auto_renew_missing','asset_moved_not_reactivated','pending_investigation','budget_approval_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'reapply_feature_key','raise_renewal_po','request_oem_reactivation','restart_license_server',
    'rationalize_unused_module','increase_seat_count','enable_auto_renewal','decommission_license',
    'escalate_to_vendor','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'vendor_contract_breach','cdsco_software_compliance','data_privacy_dpdp',
    'nabh_finding','internal_only','none'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.device_license_capa_actions_r3368 enable row level security;

create index if not exists idx_device_license_capa_r3368_license on public.device_license_capa_actions_r3368(license_id);
create index if not exists idx_device_license_capa_r3368_status on public.device_license_capa_actions_r3368(capa_status);

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

  -- 14 device-license rows
  insert into public.device_license_r3368 (
    organization_id, hospital_name, device_code, equipment_type, oem_vendor,
    license_module, license_type, activation_status, expiry_date, days_to_expiry,
    post_service_reactivation_needed, reactivation_done, unused_licensed_feature,
    entitlement_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.etype, q.oem,
    q.lmod, q.ltype, q.astat, q.exp::date, q.dte,
    q.psrn, q.rdone, q.unused,
    q.verdict, q.nt
  from (values
    ('Apollo Chennai','DEV-APL-CT01','imaging_workstation','GE Healthcare','3d_reconstruction','annual_subscription','active','2027-03-31',255,false,false,false,'compliant','CT AW workstation 3D pack active — renewal not due for 8 months'),
    ('Apollo Chennai','DEV-APL-MON1','patient_monitor_central','Philips','connectivity_hl7','concurrent_seat','active','2026-09-30',73,false,false,false,'renewal_action','Central station HL7 seats renew in 73 days — raise PO this quarter'),
    ('Fortis Gurgaon','DEV-FRT-US02','ultrasound_advanced','Canon Medical','advanced_cardiac','feature_key','not_activated',null,null,true,false,false,'reactivate_now','Advanced cardiac key not reapplied after probe-board service — feature dark'),
    ('Fortis Gurgaon','DEV-FRT-CATH','cardiology_reporting','Siemens Healthineers','advanced_cardiac','annual_subscription','expired','2026-06-15',-34,false,false,false,'expired_downtime_risk','Cardiology reporting license expired 34 days ago — reporting module locked'),
    ('Manipal Bengaluru','DEV-MNP-DOSE','dose_management','Bayer Radiology','dose_reporting','annual_subscription','grace_period','2026-07-05',-14,false,false,false,'renewal_action','Dose management in 30-day grace window — renew before hard lock'),
    ('Manipal Bengaluru','DEV-MNP-AI01','imaging_workstation','Siemens Healthineers','ai_detection','feature_key','active','2026-12-31',165,false,false,true,'unused_cost_review','AI detection key paid but radiologists never enabled — rationalize at renewal'),
    ('AIIMS Delhi','DEV-AIM-LAB1','lab_analyzer','Roche Diagnostics','analytics_pack','annual_subscription','active','2027-01-20',185,false,false,false,'compliant','Lab analyzer analytics pack current and in daily use'),
    ('AIIMS Delhi','DEV-AIM-CT02','imaging_workstation','GE Healthcare','dose_reporting','trial','trial_expiring','2026-07-28',9,false,false,false,'renewal_action','Dose reporting trial expires in 9 days — convert to subscription or lose'),
    ('CMC Vellore','DEV-CMC-US03','ultrasound_advanced','Samsung Medison','3d_reconstruction','perpetual','active',null,null,false,false,false,'compliant','Perpetual 3D recon license — no expiry, entitlement compliant'),
    ('CMC Vellore','DEV-CMC-MON2','patient_monitor_central','Mindray','connectivity_hl7','concurrent_seat','active','2026-08-14',26,true,true,false,'compliant','HL7 seats reactivated after central-station upgrade — verified live'),
    ('KIMS Hyderabad','DEV-KIM-CATH','cardiology_reporting','Philips','advanced_cardiac','annual_subscription','active','2026-08-05',17,true,false,false,'reactivate_now','Cardiac reporting key needs reactivation after license-server rebuild; expiry also near'),
    ('KIMS Hyderabad','DEV-KIM-DOSE','dose_management','Guerbet','dose_reporting','annual_subscription','expired','2026-05-20',-60,false,false,false,'expired_downtime_risk','Dose management expired 60 days — contrast dose logging offline'),
    ('Narayana Health Bengaluru','DEV-NAR-AI02','lab_analyzer','Abbott','ai_detection','concurrent_seat','active','2026-11-10',114,false,false,true,'unused_cost_review','AI detection seats paid on analyzer but workflow not adopted'),
    ('Yashoda Hyderabad','DEV-YSH-CT03','imaging_workstation','Canon Medical','3d_reconstruction','feature_key','not_activated',null,null,true,false,false,'reactivate_now','3D recon feature key not reapplied post detector swap — key dark')
  ) as q(hosp, dcode, etype, oem, lmod, ltype, astat, exp, dte, psrn, rdone, unused, verdict, nt);

  -- CAPA seed — attach to specific licenses by device_code
  insert into public.device_license_capa_actions_r3368 (
    license_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('DEV-FRT-US02','feature_key_not_reactivated','post_service_key_not_reapplied','reapply_feature_key','2026-07-24',null,'in_progress','internal_only',15000.00,'Advanced cardiac key export requested from Canon — reapply on next site visit'),
    ('DEV-FRT-CATH','license_expired_downtime','renewal_po_not_raised','raise_renewal_po','2026-07-22',null,'escalated','vendor_contract_breach',480000.00,'Cardiology reporting hard-locked — emergency renewal PO escalated to finance'),
    ('DEV-MNP-DOSE','grace_period_breach','contract_auto_renew_missing','enable_auto_renewal','2026-07-30',null,'open','cdsco_software_compliance',220000.00,'Dose logging must stay live for CDSCO records — enabling auto-renew'),
    ('DEV-MNP-AI01','unused_paid_license','feature_never_deployed','rationalize_unused_module','2026-08-10',null,'open','internal_only',0.00,'AI detection unused 11 months — evaluate drop at renewal to recover cost'),
    ('DEV-KIM-CATH','oem_reactivation_pending','license_server_offline','request_oem_reactivation','2026-07-21',null,'in_progress','nabh_finding',35000.00,'Philips license server rebuilt — OEM reactivation ticket open'),
    ('DEV-KIM-DOSE','license_expired_downtime','budget_approval_delay','raise_renewal_po','2026-07-15',null,'overdue','vendor_contract_breach',260000.00,'Dose management renewal overdue — budget sign-off stuck with finance'),
    ('DEV-NAR-AI02','unused_paid_license','feature_never_deployed','rationalize_unused_module','2026-06-28','2026-07-12','closed','internal_only',0.00,'AI seats confirmed unused — flagged for non-renewal, CAPA closed')
  ) as q(dcode, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.device_license_r3368 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Entitlement verdict distribution
create or replace function public.founder_r3368_entitlement_verdict_rollup()
returns table(entitlement_verdict text, licenses bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.device_license_r3368)
  select l.entitlement_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.device_license_r3368 l
  group by l.entitlement_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3368_entitlement_verdict_rollup() from public, anon;
grant execute on function public.founder_r3368_entitlement_verdict_rollup() to authenticated;

-- 2) Hospital entitlement scorecard
create or replace function public.founder_r3368_hospital_scorecard()
returns table(
  hospital_name text,
  total_licenses bigint,
  active bigint,
  expired bigint,
  grace_period bigint,
  reactivation_pending bigint,
  unused_paid bigint,
  compliant_pct numeric
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
    count(*) filter (where l.activation_status = 'active')::bigint,
    count(*) filter (where l.activation_status = 'expired')::bigint,
    count(*) filter (where l.activation_status = 'grace_period')::bigint,
    count(*) filter (where l.post_service_reactivation_needed and not l.reactivation_done)::bigint,
    count(*) filter (where l.unused_licensed_feature)::bigint,
    round(100.0 * count(*) filter (where l.entitlement_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.device_license_r3368 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3368_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3368_hospital_scorecard() to authenticated;

-- 3) Equipment type × license module matrix
create or replace function public.founder_r3368_equipment_module_matrix()
returns table(equipment_type text, license_module text, licenses bigint, compliant bigint, expired_or_grace bigint, avg_days_to_expiry numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.license_module, count(*)::bigint,
    count(*) filter (where l.entitlement_verdict = 'compliant')::bigint,
    count(*) filter (where l.activation_status in ('expired','grace_period'))::bigint,
    round(avg(l.days_to_expiry), 1)
  from public.device_license_r3368 l
  group by l.equipment_type, l.license_module
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3368_equipment_module_matrix() from public, anon;
grant execute on function public.founder_r3368_equipment_module_matrix() to authenticated;

-- 4) Expiry-date trend
create or replace function public.founder_r3368_expiry_date_trend()
returns table(expiry_date date, licenses bigint, expiring_soon bigint, expired bigint, reactivation_pending bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.expiry_date,
    count(*)::bigint,
    count(*) filter (where l.days_to_expiry between 0 and 90)::bigint,
    count(*) filter (where l.activation_status = 'expired')::bigint,
    count(*) filter (where l.post_service_reactivation_needed and not l.reactivation_done)::bigint
  from public.device_license_r3368 l
  where l.expiry_date is not null
  group by l.expiry_date
  order by l.expiry_date desc;
end;
$$;

revoke execute on function public.founder_r3368_expiry_date_trend() from public, anon;
grant execute on function public.founder_r3368_expiry_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3368_capa_status_board()
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
  from public.device_license_capa_actions_r3368 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3368_capa_status_board() from public, anon;
grant execute on function public.founder_r3368_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3368_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.device_license_capa_actions_r3368)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.device_license_capa_actions_r3368 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3368_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3368_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3368_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.device_license_capa_actions_r3368 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3368_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3368_regulatory_impact_digest() to authenticated;

-- 8) High-risk entitlement queue (expired, needs-reactivation, or renewal/cost concerns)
create or replace function public.founder_r3368_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  equipment_type text,
  license_module text,
  license_type text,
  activation_status text,
  expiry_date date,
  days_to_expiry int,
  entitlement_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.equipment_type, l.license_module,
    l.license_type, l.activation_status, l.expiry_date, l.days_to_expiry,
    l.entitlement_verdict, l.notes
  from public.device_license_r3368 l
  where l.entitlement_verdict in ('renewal_action','reactivate_now','expired_downtime_risk','unused_cost_review')
     or l.activation_status in ('expired','grace_period','not_activated','trial_expiring')
     or (l.post_service_reactivation_needed and not l.reactivation_done)
  order by l.days_to_expiry asc nulls last, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3368_high_risk_queue() from public, anon;
grant execute on function public.founder_r3368_high_risk_queue() to authenticated;
