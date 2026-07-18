-- Round 3270: Customer Hospital Histopathology Lab Equipment QC Audit
-- Histopath QA — device type × lab section × section-thickness accuracy × blade advance × cryostat temp × reagent rotation × staining consistency × temp log × biohazard containment × CAPA

-- =============================================================================
-- TABLE 1: histopath_lab_qc_r3270 — per-device histopathology equipment QC checks
-- =============================================================================
create table if not exists public.histopath_lab_qc_r3270 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'rotary_microtome','cryostat','tissue_processor','embedding_station','auto_slide_stainer','coverslipper'
  )),
  lab_section text not null,
  check_date date not null,
  section_thickness_accuracy_um numeric(5,2),
  blade_advance_ok boolean not null,
  cryostat_chamber_temp_error_c numeric(4,1),
  processor_reagent_rotation_current boolean not null,
  staining_consistency text check (staining_consistency in (
    'excellent','acceptable','uneven','fail'
  )),
  temperature_log_ok boolean not null,
  biohazard_containment_ok boolean not null,
  preventive_maint_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.histopath_lab_qc_r3270 enable row level security;

create index if not exists idx_histopath_lab_qc_r3270_org on public.histopath_lab_qc_r3270(organization_id);
create index if not exists idx_histopath_lab_qc_r3270_date on public.histopath_lab_qc_r3270(check_date);
create index if not exists idx_histopath_lab_qc_r3270_verdict on public.histopath_lab_qc_r3270(qc_verdict);

-- =============================================================================
-- TABLE 2: histopath_lab_qc_capa_actions_r3270 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.histopath_lab_qc_capa_actions_r3270 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.histopath_lab_qc_r3270(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'section_thickness_deviation','blade_advance_failure','cryostat_temp_excursion','reagent_rotation_overdue',
    'staining_quality_failure','temperature_log_gap','biohazard_containment_breach','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'microtome_blade_worn','micrometer_mechanism_wear','cryostat_compressor_fault','reagent_schedule_lapsed',
    'stainer_dispense_clog','processor_heater_drift','staff_technique_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_blade','recalibrate_micrometer','service_cryostat_compressor','rotate_reagents',
    'clean_stainer_dispensers','recalibrate_processor_heater','retrain_lab_staff','remove_from_service',
    'schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','nabl_15189_deviation','cap_finding','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.histopath_lab_qc_capa_actions_r3270 enable row level security;

create index if not exists idx_histopath_capa_r3270_log on public.histopath_lab_qc_capa_actions_r3270(qc_log_id);
create index if not exists idx_histopath_capa_r3270_status on public.histopath_lab_qc_capa_actions_r3270(capa_status);

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

  -- 14 histopathology equipment QC rows
  insert into public.histopath_lab_qc_r3270 (
    organization_id, hospital_name, device_code, device_type, lab_section, check_date,
    section_thickness_accuracy_um, blade_advance_ok, cryostat_chamber_temp_error_c,
    processor_reagent_rotation_current, staining_consistency, temperature_log_ok,
    biohazard_containment_ok, preventive_maint_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.dtype, q.sect, q.cdt::date,
    q.thick, q.blade, q.cryo,
    q.reagent, q.staining, q.templog,
    q.biohaz, q.pm, q.verdict, q.notes
  from (values
    ('Apollo Chennai','HP-APL-MIC-01','rotary_microtome','surgical_pathology','2026-07-05',
     0.3,true,null,true,'excellent',true,true,true,'pass','Routine QC — 4um sections within tolerance'),
    ('Apollo Chennai','HP-APL-CRY-01','cryostat','frozen_section','2026-07-05',
     0.6,true,1.2,true,'acceptable',true,true,true,'pass','Frozen-section cryostat holding -22C, within band'),
    ('Fortis Gurgaon','HP-FRT-PRO-01','tissue_processor','histology','2026-07-04',
     null,true,null,false,'uneven',true,true,true,'conditional_pass','Reagent rotation 3 days overdue — staining uneven downstream'),
    ('Fortis Gurgaon','HP-FRT-STN-01','auto_slide_stainer','histology','2026-07-04',
     null,true,null,true,'fail',true,true,false,'fail','H&E staining failed — dispense line clog, PM overdue'),
    ('Manipal Bengaluru','HP-MNP-MIC-01','rotary_microtome','surgical_pathology','2026-07-03',
     1.4,false,null,true,'acceptable',true,true,true,'conditional_pass','Section thickness drift 1.4um and blade advance sticking'),
    ('Manipal Bengaluru','HP-MNP-CRY-01','cryostat','frozen_section','2026-07-03',
     0.9,true,4.6,true,'acceptable',false,true,true,'fail','Chamber temp 4.6C off setpoint, temp log gap — held for service'),
    ('AIIMS Delhi','HP-AIM-PRO-01','tissue_processor','histology','2026-07-02',
     null,true,null,true,'excellent',true,true,true,'pass','Processor reagent rotation current, all baths nominal'),
    ('AIIMS Delhi','HP-AIM-EMB-01','embedding_station','histology','2026-07-02',
     null,true,null,true,'acceptable',false,true,true,'conditional_pass','Embedding paraffin bath temp log intermittent — recheck booked'),
    ('CMC Vellore','HP-CMC-STN-01','auto_slide_stainer','cytology','2026-07-01',
     null,true,null,true,'uneven',true,true,true,'conditional_pass','Pap stain uneven on 2 racks — dispenser priming adjusted'),
    ('CMC Vellore','HP-CMC-COV-01','coverslipper','histology','2026-07-01',
     null,true,null,true,'acceptable',true,false,true,'fail','Solvent fume/biohazard containment breach — unit stopped'),
    ('KIMS Hyderabad','HP-KIM-MIC-01','rotary_microtome','surgical_pathology','2026-06-30',
     0.4,true,null,true,'excellent',true,true,true,'pass','New blade, sections crisp at 3um'),
    ('KIMS Hyderabad','HP-KIM-CRY-01','cryostat','frozen_section','2026-06-30',
     2.1,false,6.8,true,'fail',false,true,false,'removed_from_service','Multiple failures — compressor fault, blade advance dead, removed from service'),
    ('Narayana Health Bengaluru','HP-NAR-EMB-01','embedding_station','histology','2026-06-29',
     null,true,null,true,'excellent',true,true,true,'pass','Cold plate and paraffin dispense nominal'),
    ('Medanta Gurgaon','HP-MED-STN-01','auto_slide_stainer','surgical_pathology','2026-06-29',
     null,true,null,true,'excellent',true,true,true,'pass','IHC stainer QC pass, controls acceptable')
  ) as q(hosp, code, dtype, sect, cdt, thick, blade, cryo, reagent, staining, templog, biohaz, pm, verdict, notes);

  -- CAPA seed — attach to specific QC checks via device_code
  insert into public.histopath_lab_qc_capa_actions_r3270 (
    qc_log_id, organization_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, v_org_id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('HP-FRT-STN-01','staining_quality_failure','stainer_dispense_clog','clean_stainer_dispensers','in_progress','nabl_15189_deviation','2026-07-09',null,14500.00,'H&E dispense line cleared, reprime — awaiting control slide re-run'),
    ('HP-MNP-CRY-01','cryostat_temp_excursion','cryostat_compressor_fault','service_cryostat_compressor','escalated','patient_safety_alert','2026-07-06',null,68000.00,'Chamber 4.6C off setpoint — OEM compressor service escalated'),
    ('HP-CMC-COV-01','biohazard_containment_breach','pending_investigation','schedule_oem_service','open','nabh_finding','2026-07-08',null,22000.00,'Fume containment breach — OEM inspection of solvent seals pending'),
    ('HP-KIM-CRY-01','cryostat_temp_excursion','cryostat_compressor_fault','remove_from_service','closed','iso_15189_deviation','2026-07-02','2026-06-30',0.00,'Cryostat removed from service; frozen sections rerouted to backup unit'),
    ('HP-FRT-PRO-01','reagent_rotation_overdue','reagent_schedule_lapsed','rotate_reagents','closed','internal_only','2026-07-05','2026-07-04',3500.00,'Reagents rotated, fresh alcohols and xylene loaded — staining verified'),
    ('HP-MNP-MIC-01','section_thickness_deviation','microtome_blade_worn','replace_blade','verification_pending','internal_only','2026-07-05',null,4200.00,'Blade replaced, micrometer re-checked — verify 4um ribbon next batch'),
    ('HP-AIM-EMB-01','temperature_log_gap','preventive_service_backlog','recalibrate_processor_heater','overdue','internal_only','2026-07-01',null,7800.00,'Paraffin bath thermocouple recal past due — AMC vendor delayed')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.histopath_lab_qc_r3270 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3270_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.histopath_lab_qc_r3270)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.histopath_lab_qc_r3270 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3270_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3270_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3270_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  staining_fail bigint,
  temp_log_fail bigint,
  biohazard_fail bigint,
  pass_pct numeric
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
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.staining_consistency in ('uneven','fail'))::bigint,
    count(*) filter (where l.temperature_log_ok = false)::bigint,
    count(*) filter (where l.biohazard_containment_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.histopath_lab_qc_r3270 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3270_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3270_hospital_scorecard() to authenticated;

-- 3) Device type × lab section matrix
create or replace function public.founder_r3270_device_section_matrix()
returns table(device_type text, lab_section text, checks bigint, passed bigint, avg_thickness_dev_um numeric, avg_cryo_temp_error_c numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.lab_section, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.section_thickness_accuracy_um), 2),
    round(avg(l.cryostat_chamber_temp_error_c), 1)
  from public.histopath_lab_qc_r3270 l
  group by l.device_type, l.lab_section
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3270_device_section_matrix() from public, anon;
grant execute on function public.founder_r3270_device_section_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3270_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, staining_fail bigint, containment_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.staining_consistency in ('uneven','fail'))::bigint,
    count(*) filter (where l.biohazard_containment_ok = false)::bigint
  from public.histopath_lab_qc_r3270 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3270_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3270_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3270_capa_status_board()
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
  from public.histopath_lab_qc_capa_actions_r3270 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3270_capa_status_board() from public, anon;
grant execute on function public.founder_r3270_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3270_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.histopath_lab_qc_capa_actions_r3270)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.histopath_lab_qc_capa_actions_r3270 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3270_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3270_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3270_regulatory_impact_digest()
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
  from public.histopath_lab_qc_capa_actions_r3270 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3270_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3270_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3270_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  lab_section text,
  check_date date,
  qc_verdict text,
  staining_consistency text,
  temperature_log_ok boolean,
  biohazard_containment_ok boolean,
  preventive_maint_current boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.lab_section, l.check_date,
    l.qc_verdict, l.staining_consistency, l.temperature_log_ok, l.biohazard_containment_ok,
    l.preventive_maint_current, l.notes
  from public.histopath_lab_qc_r3270 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.staining_consistency in ('uneven','fail')
     or l.temperature_log_ok = false
     or l.biohazard_containment_ok = false
     or l.preventive_maint_current = false
     or l.blade_advance_ok = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3270_high_risk_queue() from public, anon;
grant execute on function public.founder_r3270_high_risk_queue() to authenticated;
