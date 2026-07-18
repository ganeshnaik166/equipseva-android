-- Round 3154: Customer Hospital MRI Cryogen-Level & Quench-Vent Safety Audit
-- MRI helium safety log — field strength x helium level x boil-off x cold-head x quench-pipe x O2 sensor x magnetic-safety signage x verdict x CAPA

-- =============================================================================
-- TABLE 1: mri_cryogen_r3154 — per-scanner monthly cryogen & quench-vent safety check
-- =============================================================================
create table if not exists public.mri_cryogen_r3154 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  mri_suite_code text not null,
  scanner_asset_tag text not null,
  scanner_model text not null,
  field_strength_tesla text not null check (field_strength_tesla in (
    '0_35_tesla','0_55_tesla','1_5_tesla','3_0_tesla','7_0_tesla'
  )),
  check_date date not null,
  checked_at timestamptz not null,
  helium_level_pct numeric(5,2) not null,
  boil_off_rate_pct_per_month numeric(5,2),
  cold_head_status text not null check (cold_head_status in (
    'operational','degraded','failed','offline','recently_replaced','service_due'
  )),
  quench_pipe_integrity text not null check (quench_pipe_integrity in (
    'intact','corrosion_minor','corrosion_major','blocked_partial','disconnected','not_inspected'
  )),
  o2_depletion_sensor_status text not null check (o2_depletion_sensor_status in (
    'functional','fault','calibration_due','offline','not_installed','recently_calibrated'
  )),
  magnetic_safety_signage text not null check (magnetic_safety_signage in (
    'compliant','partial_missing','missing','faded_illegible','not_applicable'
  )),
  helium_level_band text check (helium_level_band in (
    'optimal','adequate','low','critical','refill_scheduled'
  )),
  last_refill_date date,
  audit_verdict text not null check (audit_verdict in (
    'pass','conditional_pass','monitor','fail','quench_risk','refill_required','scan_halt'
  )),
  resolved_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mri_cryogen_r3154 enable row level security;

create index if not exists idx_mri_cryogen_r3154_org on public.mri_cryogen_r3154(organization_id);
create index if not exists idx_mri_cryogen_r3154_date on public.mri_cryogen_r3154(check_date);
create index if not exists idx_mri_cryogen_r3154_verdict on public.mri_cryogen_r3154(audit_verdict);

-- =============================================================================
-- TABLE 2: mri_cryogen_capa_actions_r3154 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.mri_cryogen_capa_actions_r3154 (
  id uuid primary key default gen_random_uuid(),
  cryogen_log_id uuid not null references public.mri_cryogen_r3154(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'helium_low','high_boil_off','cold_head_failure','quench_pipe_corrosion',
    'o2_sensor_fault','signage_noncompliance','magnet_ramp_risk','refill_overdue',
    'vent_path_obstruction','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'coldhead_compressor_degraded','helium_leak_seal','chiller_water_flow_low',
    'sensor_calibration_drift','vent_pipe_corrosion','power_interruption',
    'delayed_helium_supply','installation_defect','operator_procedure_gap',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_cold_head','rebuild_compressor','seal_helium_leak','schedule_helium_refill',
    'recalibrate_o2_sensor','repair_quench_vent','install_safety_signage','restore_chiller_flow',
    'trigger_scan_halt','none_required','schedule_amc_visit'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','manufacturer_advisory','patient_safety_alert','none','internal_only','iso_13485_deviation'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mri_cryogen_capa_actions_r3154 enable row level security;

create index if not exists idx_mri_cryogen_capa_r3154_log on public.mri_cryogen_capa_actions_r3154(cryogen_log_id);
create index if not exists idx_mri_cryogen_capa_r3154_status on public.mri_cryogen_capa_actions_r3154(capa_status);

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

  -- 13 cryogen audit rows
  insert into public.mri_cryogen_r3154 (
    organization_id, hospital_name, mri_suite_code, scanner_asset_tag, scanner_model,
    field_strength_tesla, check_date, checked_at,
    helium_level_pct, boil_off_rate_pct_per_month, cold_head_status, quench_pipe_integrity,
    o2_depletion_sensor_status, magnetic_safety_signage, helium_level_band, last_refill_date,
    audit_verdict, resolved_at, notes
  )
  select v_org_id, q.hosp, q.suite, q.tag, q.model,
    q.fst, q.cd::date, q.ca::timestamptz,
    q.hlp, q.bor, q.chs, q.qpi, q.o2s, q.mss, q.hlb, q.lrd::date,
    q.av, q.res::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','MRI-1','MRI-APL-101','Siemens Magnetom Vida','3_0_tesla','2026-07-15','2026-07-15 07:30:00+05:30',
     78.50,2.10,'operational','intact','functional','compliant','optimal','2026-05-20','pass','2026-07-15 08:00:00+05:30','Routine monthly cryogen check all nominal'),
    ('Apollo Hyderabad Jubilee Hills','MRI-2','MRI-APL-102','GE Signa Premier','3_0_tesla','2026-07-15','2026-07-15 09:00:00+05:30',
     62.00,3.80,'degraded','corrosion_minor','calibration_due','partial_missing','adequate','2026-04-10','conditional_pass',null,'Boil-off trending up and cold head degraded - monitor'),
    ('Fortis Bannerghatta Bengaluru','MRI-1','MRI-FRT-201','Philips Ingenia 1.5T','1_5_tesla','2026-07-14','2026-07-14 06:45:00+05:30',
     41.00,5.60,'degraded','corrosion_major','fault','missing','low','2026-03-01','refill_required',null,'Helium 41pct with high boil-off - refill plus O2 sensor fault'),
    ('Fortis Bannerghatta Bengaluru','MRI-2','MRI-FRT-202','Siemens Magnetom Sola','1_5_tesla','2026-07-14','2026-07-14 08:15:00+05:30',
     29.50,7.20,'failed','blocked_partial','offline','faded_illegible','critical','2026-02-15','quench_risk',null,'Cold head failed and quench pipe partially blocked - quench risk'),
    ('Manipal Whitefield Bengaluru','MRI-1','MRI-MNP-301','GE Signa Artist','1_5_tesla','2026-07-13','2026-07-13 07:00:00+05:30',
     85.00,1.80,'operational','intact','functional','compliant','optimal','2026-06-25','pass','2026-07-13 07:40:00+05:30','Post-refill baseline excellent'),
    ('Manipal Whitefield Bengaluru','MRI-2','MRI-MNP-302','Siemens Magnetom Aera','1_5_tesla','2026-07-13','2026-07-13 09:30:00+05:30',
     55.00,4.10,'recently_replaced','intact','recently_calibrated','compliant','adequate','2026-05-30','monitor',null,'New cold head bedding in - watch boil-off'),
    ('AIIMS New Delhi Ansari Nagar','MRI-3','MRI-AIM-401','Philips Achieva 3.0T','3_0_tesla','2026-07-12','2026-07-12 06:30:00+05:30',
     71.00,2.90,'operational','corrosion_minor','functional','partial_missing','adequate','2026-05-05','conditional_pass',null,'Zone III signage partially missing - facilities notified'),
    ('AIIMS New Delhi Ansari Nagar','MRI-4','MRI-AIM-402','GE Signa HDxt','1_5_tesla','2026-07-12','2026-07-12 08:45:00+05:30',
     18.00,9.50,'failed','disconnected','offline','missing','critical','2026-01-20','scan_halt',null,'Quench vent disconnected and helium 18pct - scans halted immediately'),
    ('KIMS Secunderabad','MRI-1','MRI-KIM-501','Siemens Magnetom Skyra','3_0_tesla','2026-07-11','2026-07-11 07:15:00+05:30',
     67.50,3.10,'operational','intact','calibration_due','compliant','adequate','2026-04-28','conditional_pass',null,'O2 sensor calibration overdue by 3 weeks'),
    ('Care Hospitals Banjara Hills','MRI-2','MRI-CAR-601','Philips Ingenia Ambition','1_5_tesla','2026-07-10','2026-07-10 06:50:00+05:30',
     74.00,2.40,'operational','intact','functional','compliant','optimal','2026-06-01','pass','2026-07-10 07:20:00+05:30','BlueSeal sealed magnet nominal'),
    ('Yashoda Somajiguda Hyderabad','MRI-1','MRI-YSH-701','GE Signa Voyager','1_5_tesla','2026-07-09','2026-07-09 08:00:00+05:30',
     48.00,5.00,'degraded','corrosion_minor','fault','partial_missing','refill_scheduled','2026-03-18','refill_required',null,'Refill scheduled and O2 sensor intermittent fault'),
    ('St John''s Bengaluru','MRI-1','MRI-STJ-801','Siemens Magnetom Essenza','1_5_tesla','2026-07-08','2026-07-08 07:40:00+05:30',
     60.00,3.50,'operational','not_inspected','functional','compliant','adequate','2026-05-12','monitor',null,'Quench pipe not inspected this cycle - schedule'),
    ('Rainbow Children''s Hyderabad','MRI-1','MRI-RBW-901','Hitachi Echelon Oval','1_5_tesla','2026-07-07','2026-07-07 09:10:00+05:30',
     33.00,6.40,'service_due','corrosion_major','calibration_due','faded_illegible','critical','2026-02-02','quench_risk',null,'Multiple deficiencies and cold head service overdue')
  ) as q(hosp, suite, tag, model, fst, cd, ca, hlp, bor, chs, qpi, o2s, mss, hlb, lrd, av, res, nt);

  -- CAPA seed — attach to specific scanners by asset tag
  insert into public.mri_cryogen_capa_actions_r3154 (
    cryogen_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca_, q.tcd::date, q.acd::date, q.st, q.ri, q.cost, q.nt
  from (values
    ('MRI-FRT-201','helium_low','helium_leak_seal','seal_helium_leak','2026-07-25',null,'in_progress','patient_safety_alert',185000.00,'Helium leak at magnet seal - refill and seal repair'),
    ('MRI-FRT-202','cold_head_failure','coldhead_compressor_degraded','replace_cold_head','2026-07-22',null,'escalated','patient_safety_alert',950000.00,'Cold head failed and quench risk - emergency replacement'),
    ('MRI-AIM-402','vent_path_obstruction','vent_pipe_corrosion','repair_quench_vent','2026-07-20',null,'escalated','patient_safety_alert',320000.00,'Quench vent disconnected - scans halted, urgent repair'),
    ('MRI-AIM-401','signage_noncompliance','operator_procedure_gap','install_safety_signage','2026-07-19','2026-07-16','closed','nabh_finding',25000.00,'Zone III signage reinstalled and verified'),
    ('MRI-YSH-701','o2_sensor_fault','sensor_calibration_drift','recalibrate_o2_sensor','2026-07-21',null,'open','internal_only',18000.00,'O2 depletion sensor intermittent - recalibrate'),
    ('MRI-RBW-901','high_boil_off','coldhead_compressor_degraded','rebuild_compressor','2026-07-24',null,'overdue','manufacturer_advisory',420000.00,'Compressor degraded and boil-off 6.4pct per month - rebuild overdue')
  ) as q(tag_ref, fc, rc, ca_, tcd, acd, st, ri, cost, nt)
  join public.mri_cryogen_r3154 e
    on e.organization_id = v_org_id and e.scanner_asset_tag = q.tag_ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3154_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mri_cryogen_r3154)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.mri_cryogen_r3154 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3154_verdict_rollup() from public, anon;
grant execute on function public.founder_r3154_verdict_rollup() to authenticated;

-- 2) Hospital-level safety scorecard
create or replace function public.founder_r3154_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  refill_required bigint,
  quench_risk bigint,
  scan_halt bigint,
  cold_head_issues bigint,
  low_helium bigint,
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
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict = 'refill_required')::bigint,
    count(*) filter (where l.audit_verdict = 'quench_risk')::bigint,
    count(*) filter (where l.audit_verdict = 'scan_halt')::bigint,
    count(*) filter (where l.cold_head_status in ('degraded','failed','service_due','offline'))::bigint,
    count(*) filter (where l.helium_level_band in ('low','critical'))::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict in ('pass','conditional_pass'))::numeric / nullif(count(*),0), 1)
  from public.mri_cryogen_r3154 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3154_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3154_hospital_scorecard() to authenticated;

-- 3) Field strength x cold-head status matrix
create or replace function public.founder_r3154_field_status_matrix()
returns table(
  field_strength_tesla text,
  cold_head_status text,
  audits bigint,
  passed bigint,
  avg_helium_pct numeric,
  avg_boil_off numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.field_strength_tesla, l.cold_head_status, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    round(avg(l.helium_level_pct), 2),
    round(avg(l.boil_off_rate_pct_per_month), 2)
  from public.mri_cryogen_r3154 l
  group by l.field_strength_tesla, l.cold_head_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3154_field_status_matrix() from public, anon;
grant execute on function public.founder_r3154_field_status_matrix() to authenticated;

-- 4) Helium / boil-off daily trend
create or replace function public.founder_r3154_helium_daily_trend()
returns table(
  check_date date,
  audits bigint,
  avg_helium_pct numeric,
  avg_boil_off numeric,
  refill_required bigint,
  quench_risk bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date, count(*)::bigint,
    round(avg(l.helium_level_pct), 2),
    round(avg(l.boil_off_rate_pct_per_month), 2),
    count(*) filter (where l.audit_verdict = 'refill_required')::bigint,
    count(*) filter (where l.audit_verdict in ('quench_risk','scan_halt'))::bigint
  from public.mri_cryogen_r3154 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3154_helium_daily_trend() from public, anon;
grant execute on function public.founder_r3154_helium_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3154_capa_status_board()
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
  from public.mri_cryogen_capa_actions_r3154 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3154_capa_status_board() from public, anon;
grant execute on function public.founder_r3154_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3154_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mri_cryogen_capa_actions_r3154)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.mri_cryogen_capa_actions_r3154 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3154_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3154_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3154_regulatory_impact_digest()
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
  from public.mri_cryogen_capa_actions_r3154 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3154_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3154_regulatory_impact_digest() to authenticated;

-- 8) High-risk priority queue
create or replace function public.founder_r3154_high_risk_audits()
returns table(
  hospital_name text,
  mri_suite_code text,
  scanner_asset_tag text,
  check_date date,
  audit_verdict text,
  helium_level_pct numeric,
  cold_head_status text,
  quench_pipe_integrity text,
  o2_depletion_sensor_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.mri_suite_code, l.scanner_asset_tag, l.check_date,
    l.audit_verdict, l.helium_level_pct, l.cold_head_status, l.quench_pipe_integrity,
    l.o2_depletion_sensor_status, l.notes
  from public.mri_cryogen_r3154 l
  where l.audit_verdict in ('refill_required','quench_risk','scan_halt','fail','monitor','conditional_pass')
     or l.helium_level_band in ('low','critical')
     or l.cold_head_status in ('failed','service_due')
     or l.quench_pipe_integrity in ('corrosion_major','blocked_partial','disconnected')
     or l.o2_depletion_sensor_status = 'fault'
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3154_high_risk_audits() from public, anon;
grant execute on function public.founder_r3154_high_risk_audits() to authenticated;
