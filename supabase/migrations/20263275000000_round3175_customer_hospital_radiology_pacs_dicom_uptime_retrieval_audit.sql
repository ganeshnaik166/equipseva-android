-- Round 3175: Customer Hospital Radiology PACS / DICOM Uptime & Image-Retrieval Audit
-- PACS QA log — modality × study volume × DICOM send-success × retrieval time × storage used
--   × downtime × backup verified × report-turnaround × verdict + CAPA closure

-- =============================================================================
-- TABLE 1: pacs_dicom_r3175 — per-modality PACS/DICOM audit windows
-- =============================================================================
create table if not exists public.pacs_dicom_r3175 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  pacs_node_code text not null,
  pacs_vendor text not null check (pacs_vendor in (
    'ge_centricity','philips_intellispace','agfa_enterprise','sectra_pacs',
    'fujifilm_synapse','carestream_vue','merge_pacs','open_source_orthanc'
  )),
  modality text not null check (modality in (
    'ct_scanner','mr_scanner','cr_dr_xray','ultrasound',
    'mammography','pet_ct','cath_lab_angio','nuclear_medicine'
  )),
  audit_date date not null,
  window_started_at timestamptz not null,
  window_ended_at timestamptz,
  study_volume int not null,
  dicom_send_success_pct numeric(5,2) not null,
  retrieval_time_seconds numeric(6,2) not null,
  storage_used_pct numeric(5,2) not null,
  downtime_minutes int not null,
  backup_verified boolean not null default false,
  report_turnaround_hours numeric(6,2),
  network_link_status text not null check (network_link_status in (
    'stable','intermittent','degraded','congested','failover_active'
  )),
  archive_tier text check (archive_tier in (
    'online_ssd','nearline_disk','offline_tape','cloud_cold','hybrid_cloud','not_configured'
  )),
  audit_verdict text not null check (audit_verdict in (
    'compliant','watch','minor_deviation','major_deviation','critical_outage','pending_review'
  )),
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pacs_dicom_r3175 enable row level security;

create index if not exists idx_pacs_dicom_r3175_org on public.pacs_dicom_r3175(organization_id);
create index if not exists idx_pacs_dicom_r3175_date on public.pacs_dicom_r3175(audit_date);
create index if not exists idx_pacs_dicom_r3175_verdict on public.pacs_dicom_r3175(audit_verdict);

-- =============================================================================
-- TABLE 2: pacs_dicom_capa_actions_r3175 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.pacs_dicom_capa_actions_r3175 (
  id uuid primary key default gen_random_uuid(),
  pacs_log_id uuid not null references public.pacs_dicom_r3175(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'send_failure_high','slow_retrieval','storage_near_full','excess_downtime',
    'backup_unverified','report_turnaround_breach','image_corruption',
    'modality_worklist_mismatch','network_congestion','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'storage_array_full','network_switch_fault','dicom_config_error','pacs_db_index_bloat',
    'tape_drive_failure','vpn_link_flapping','worklist_hl7_mismatch','server_undersized',
    'power_ups_fault','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'expand_storage_array','replace_network_switch','reconfigure_dicom_ae','rebuild_pacs_db_index',
    'replace_tape_drive','stabilize_vpn_link','remap_hl7_worklist','upgrade_pacs_server',
    'add_ups_capacity','none_required','schedule_amc_visit'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','abdm_notifiable','none','internal_only','iso_27001_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pacs_dicom_capa_actions_r3175 enable row level security;

create index if not exists idx_pacs_capa_r3175_log on public.pacs_dicom_capa_actions_r3175(pacs_log_id);
create index if not exists idx_pacs_capa_r3175_status on public.pacs_dicom_capa_actions_r3175(capa_status);

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

  -- 14 PACS/DICOM audit-window rows
  insert into public.pacs_dicom_r3175 (
    organization_id, hospital_name, pacs_node_code, pacs_vendor, modality,
    audit_date, window_started_at, window_ended_at,
    study_volume, dicom_send_success_pct, retrieval_time_seconds, storage_used_pct,
    downtime_minutes, backup_verified, report_turnaround_hours,
    network_link_status, archive_tier, audit_verdict, reviewed_at, notes
  )
  select v_org_id, q.hosp, q.node, q.vendor, q.mod,
    q.ad::date, q.ws::timestamptz, q.we::timestamptz,
    q.sv, q.ds, q.rt, q.su,
    q.dt, q.bv, q.rtat,
    q.nls, q.arch, q.av, q.rev::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','PACS-APL-CT01','ge_centricity','ct_scanner',
     '2026-07-01','2026-07-01 00:00:00+05:30','2026-07-01 23:59:00+05:30',
     1240,99.60,2.40,62.50,8,true,4.20,'stable','online_ssd','compliant','2026-07-02 09:00:00+05:30','Peak OPD load handled, retrieval within SLA'),
    ('Apollo Hyderabad Jubilee Hills','PACS-APL-MR01','ge_centricity','mr_scanner',
     '2026-07-01','2026-07-01 00:00:00+05:30','2026-07-01 23:59:00+05:30',
     320,98.90,3.80,64.00,15,true,9.50,'stable','nearline_disk','watch',null,'MR turnaround creeping up, radiologist backlog'),
    ('Fortis Bannerghatta Bengaluru','PACS-FRT-CT02','philips_intellispace','ct_scanner',
     '2026-07-01','2026-07-01 00:00:00+05:30','2026-07-01 23:59:00+05:30',
     980,94.20,6.90,88.50,46,false,14.00,'degraded','nearline_disk','major_deviation',null,'Send-success dropped, storage 88 pct — archive backlog'),
    ('Fortis Bannerghatta Bengaluru','PACS-FRT-US01','philips_intellispace','ultrasound',
     '2026-07-01','2026-07-01 00:00:00+05:30','2026-07-01 23:59:00+05:30',
     540,97.10,3.10,71.00,22,true,6.20,'intermittent','online_ssd','minor_deviation',null,'Intermittent link to US room, occasional resend'),
    ('Manipal Whitefield Bengaluru','PACS-MNP-MR02','sectra_pacs','mr_scanner',
     '2026-06-30','2026-06-30 00:00:00+05:30','2026-06-30 23:59:00+05:30',
     410,99.10,3.40,58.00,5,true,7.80,'stable','hybrid_cloud','compliant','2026-07-01 10:00:00+05:30','Cloud tier healthy, all studies archived'),
    ('Manipal Whitefield Bengaluru','PACS-MNP-CR01','sectra_pacs','cr_dr_xray',
     '2026-06-30','2026-06-30 00:00:00+05:30','2026-06-30 23:59:00+05:30',
     1520,99.80,1.90,60.50,3,true,3.10,'stable','online_ssd','compliant','2026-07-01 10:15:00+05:30','High CR volume, fast retrieval'),
    ('AIIMS New Delhi Ansari Nagar','PACS-AIM-CT03','agfa_enterprise','ct_scanner',
     '2026-06-30','2026-06-30 00:00:00+05:30','2026-06-30 23:59:00+05:30',
     2100,96.40,8.20,92.00,62,false,18.50,'congested','offline_tape','critical_outage',null,'Storage 92 pct, tape restore slow, 62min downtime'),
    ('AIIMS New Delhi Ansari Nagar','PACS-AIM-PET1','agfa_enterprise','pet_ct',
     '2026-06-30','2026-06-30 00:00:00+05:30','2026-06-30 23:59:00+05:30',
     85,99.30,5.60,74.00,10,true,22.00,'stable','nearline_disk','watch',null,'PET turnaround long by nature, review flagged'),
    ('KIMS Secunderabad','PACS-KIM-CT04','fujifilm_synapse','ct_scanner',
     '2026-06-29','2026-06-29 00:00:00+05:30','2026-06-29 23:59:00+05:30',
     760,92.80,7.40,69.00,38,false,11.20,'degraded','nearline_disk','major_deviation',null,'DICOM AE misconfig after upgrade, resend spike'),
    ('KIMS Secunderabad','PACS-KIM-MG01','fujifilm_synapse','mammography',
     '2026-06-29','2026-06-29 00:00:00+05:30','2026-06-29 23:59:00+05:30',
     210,98.60,4.10,66.00,12,true,8.90,'stable','online_ssd','minor_deviation',null,'Mammo priors retrieval slightly slow'),
    ('Care Hospitals Banjara Hills','PACS-CAR-NM01','carestream_vue','nuclear_medicine',
     '2026-06-29','2026-06-29 00:00:00+05:30','2026-06-29 23:59:00+05:30',
     60,99.00,6.30,55.00,4,true,16.00,'stable','cloud_cold','compliant','2026-06-30 09:30:00+05:30','Low volume NM, cold archive verified'),
    ('Yashoda Somajiguda Hyderabad','PACS-YSH-CT05','merge_pacs','ct_scanner',
     '2026-06-28','2026-06-28 00:00:00+05:30','2026-06-28 23:59:00+05:30',
     1180,97.90,4.80,79.50,18,true,6.60,'stable','hybrid_cloud','watch',null,'Storage nearing 80 pct, plan expansion'),
    ('St John''s Bengaluru','PACS-STJ-CR02','carestream_vue','cr_dr_xray',
     '2026-06-28','2026-06-28 00:00:00+05:30','2026-06-28 23:59:00+05:30',
     1350,99.70,2.10,57.00,2,true,3.60,'stable','online_ssd','compliant','2026-06-29 08:45:00+05:30','Stable node, backup verified nightly'),
    ('Rainbow Children''s Hyderabad','PACS-RBW-US02','open_source_orthanc','ultrasound',
     '2026-06-27','2026-06-27 00:00:00+05:30','2026-06-27 23:59:00+05:30',
     430,95.50,5.90,63.00,28,false,7.10,'failover_active','not_configured','pending_review',null,'Orthanc backup not configured, failover active')
  ) as q(hosp, node, vendor, mod, ad, ws, we, sv, ds, rt, su, dt, bv, rtat, nls, arch, av, rev, nt);

  -- CAPA seed — attach to specific PACS nodes
  insert into public.pacs_dicom_capa_actions_r3175 (
    pacs_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('PACS-FRT-CT02','storage_near_full','storage_array_full','expand_storage_array','2026-07-08',null,'in_progress','nabh_finding',850000.00,'Add 40TB tier, migrate cold studies to nearline'),
    ('PACS-AIM-CT03','excess_downtime','tape_drive_failure','replace_tape_drive','2026-07-05',null,'escalated','patient_safety_alert',220000.00,'62min outage, tape restore failed — urgent replacement'),
    ('PACS-KIM-CT04','send_failure_high','dicom_config_error','reconfigure_dicom_ae','2026-07-03','2026-07-02','closed','iso_27001_deviation',15000.00,'AE title remapped post-upgrade, resend verified clean'),
    ('PACS-RBW-US02','backup_unverified','pending_investigation','none_required','2026-07-10',null,'open','abdm_notifiable',30000.00,'Configure Orthanc nightly backup + verification job'),
    ('PACS-FRT-US01','slow_retrieval','network_switch_fault','replace_network_switch','2026-07-06',null,'verification_pending','internal_only',45000.00,'Edge switch flapping to US room, RMA raised'),
    ('PACS-YSH-CT05','preventive_maintenance_due','preventive_service_backlog','schedule_amc_visit','2026-06-26',null,'overdue','nabh_finding',25000.00,'Storage PM overdue, schedule capacity-expansion visit')
  ) as q(node_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.pacs_dicom_r3175 e
    on e.organization_id = v_org_id and e.pacs_node_code = q.node_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3175_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pacs_dicom_r3175)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pacs_dicom_r3175 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3175_verdict_rollup() from public, anon;
grant execute on function public.founder_r3175_verdict_rollup() to authenticated;

-- 2) Hospital-level PACS scorecard
create or replace function public.founder_r3175_hospital_scorecard()
returns table(
  hospital_name text,
  audits bigint,
  compliant bigint,
  watch bigint,
  major_critical bigint,
  avg_send_success numeric,
  avg_retrieval_sec numeric,
  avg_storage_pct numeric,
  total_downtime_min bigint,
  compliance_pct numeric
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
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    count(*) filter (where l.audit_verdict = 'watch')::bigint,
    count(*) filter (where l.audit_verdict in ('major_deviation','critical_outage'))::bigint,
    round(avg(l.dicom_send_success_pct), 2),
    round(avg(l.retrieval_time_seconds), 2),
    round(avg(l.storage_used_pct), 2),
    sum(l.downtime_minutes)::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.pacs_dicom_r3175 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3175_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3175_hospital_scorecard() to authenticated;

-- 3) Modality performance matrix
create or replace function public.founder_r3175_modality_matrix()
returns table(
  modality text,
  audits bigint,
  total_studies bigint,
  avg_send_success numeric,
  avg_retrieval_sec numeric,
  avg_storage_pct numeric,
  avg_turnaround_hrs numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.modality, count(*)::bigint,
    coalesce(sum(l.study_volume),0)::bigint,
    round(avg(l.dicom_send_success_pct), 2),
    round(avg(l.retrieval_time_seconds), 2),
    round(avg(l.storage_used_pct), 2),
    round(avg(l.report_turnaround_hours), 2)
  from public.pacs_dicom_r3175 l
  group by l.modality
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3175_modality_matrix() from public, anon;
grant execute on function public.founder_r3175_modality_matrix() to authenticated;

-- 4) Daily uptime & retrieval trend
create or replace function public.founder_r3175_daily_trend()
returns table(
  audit_date date,
  audits bigint,
  avg_send_success numeric,
  avg_retrieval_sec numeric,
  total_downtime_min bigint,
  backups_verified bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    round(avg(l.dicom_send_success_pct), 2),
    round(avg(l.retrieval_time_seconds), 2),
    sum(l.downtime_minutes)::bigint,
    count(*) filter (where l.backup_verified)::bigint
  from public.pacs_dicom_r3175 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3175_daily_trend() from public, anon;
grant execute on function public.founder_r3175_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3175_capa_status_board()
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
  from public.pacs_dicom_capa_actions_r3175 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3175_capa_status_board() from public, anon;
grant execute on function public.founder_r3175_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3175_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pacs_dicom_capa_actions_r3175)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pacs_dicom_capa_actions_r3175 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3175_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3175_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3175_regulatory_impact_digest()
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
  from public.pacs_dicom_capa_actions_r3175 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3175_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3175_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority audit queue
create or replace function public.founder_r3175_high_risk_queue()
returns table(
  hospital_name text,
  pacs_node_code text,
  modality text,
  audit_date date,
  audit_verdict text,
  dicom_send_success_pct numeric,
  retrieval_time_seconds numeric,
  storage_used_pct numeric,
  downtime_minutes int,
  backup_verified boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.pacs_node_code, l.modality, l.audit_date,
    l.audit_verdict, l.dicom_send_success_pct, l.retrieval_time_seconds,
    l.storage_used_pct, l.downtime_minutes, l.backup_verified, l.notes
  from public.pacs_dicom_r3175 l
  where l.audit_verdict in ('minor_deviation','major_deviation','critical_outage','pending_review')
     or l.dicom_send_success_pct < 97.0
     or l.storage_used_pct >= 85.0
     or l.downtime_minutes >= 30
     or l.backup_verified = false
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3175_high_risk_queue() from public, anon;
grant execute on function public.founder_r3175_high_risk_queue() to authenticated;
