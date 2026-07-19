-- Round 3351: Customer Hospital MRI RF-Coil & Gradient Integrity QC Audit
-- MRI QA — coil/subsystem type × field strength × coil SNR × element dropout × image uniformity × gradient linearity × cable/connector × helium/cold-head × phantom QC × calibration × CAPA

-- =============================================================================
-- TABLE 1: mri_coil_gradient_r3351 — per-coil / subsystem QC checks
-- =============================================================================
create table if not exists public.mri_coil_gradient_r3351 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  mri_code text not null,
  component_type text not null check (component_type in (
    'head_coil','spine_coil','body_coil','surface_flex_coil','gradient_system','cold_head_cryo'
  )),
  field_strength text not null check (field_strength in (
    '1_5t','3t','7t','open_mri'
  )),
  check_date date not null,
  snr_within_spec boolean,
  coil_element_dropout_count int,
  image_uniformity_ok boolean,
  gradient_linearity_ok text not null check (gradient_linearity_ok in (
    'ok','drift','fail','not_applicable'
  )),
  cable_connector_condition text not null check (cable_connector_condition in (
    'good','worn','cracked','replace_due'
  )),
  helium_level_pct numeric(5,2),
  cold_head_function_ok boolean,
  phantom_qc_pass boolean,
  calibration_current boolean,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mri_coil_gradient_r3351 enable row level security;

create index if not exists idx_mri_coil_gradient_r3351_org on public.mri_coil_gradient_r3351(organization_id);
create index if not exists idx_mri_coil_gradient_r3351_date on public.mri_coil_gradient_r3351(check_date);
create index if not exists idx_mri_coil_gradient_r3351_verdict on public.mri_coil_gradient_r3351(qc_verdict);

-- =============================================================================
-- TABLE 2: mri_coil_gradient_capa_actions_r3351 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.mri_coil_gradient_capa_actions_r3351 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.mri_coil_gradient_r3351(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'snr_degradation','coil_element_dropout','image_non_uniformity','gradient_linearity_drift',
    'cable_connector_damage','helium_boiloff_high','cold_head_failure','phantom_qc_failure',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'coil_element_failure','preamp_fault','connector_pin_corrosion','gradient_coil_degradation',
    'cold_head_wear','helium_compressor_fault','vibration_induced_drift','software_calibration_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_coil','repair_preamp','replace_connector_cable','recalibrate_gradient',
    'replace_cold_head','service_helium_compressor','refill_cryogen','rerun_phantom_qc',
    'update_calibration','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mri_coil_gradient_capa_actions_r3351 enable row level security;

create index if not exists idx_mri_coil_capa_r3351_log on public.mri_coil_gradient_capa_actions_r3351(qc_log_id);
create index if not exists idx_mri_coil_capa_r3351_status on public.mri_coil_gradient_capa_actions_r3351(capa_status);

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

  -- 14 per-coil / subsystem QC rows
  insert into public.mri_coil_gradient_r3351 (
    organization_id, hospital_name, mri_code, component_type, field_strength, check_date,
    snr_within_spec, coil_element_dropout_count, image_uniformity_ok, gradient_linearity_ok,
    cable_connector_condition, helium_level_pct, cold_head_function_ok, phantom_qc_pass,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.comp, q.fs, q.cd::date,
    q.snr, q.dropc, q.iuni, q.glin,
    q.cable, q.helium, q.coldfn, q.phantom,
    q.calib, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','MRI-APL-CHN-01','head_coil','3t','2026-07-03',
     true,0,true,'not_applicable','good',null,null,true,true,'pass','Quarterly coil QC — SNR and uniformity nominal'),
    ('Apollo Chennai Greams Road','MRI-APL-CHN-01','gradient_system','3t','2026-07-03',
     null,null,true,'ok','good',null,null,true,true,'pass','Gradient linearity within spec across all axes'),
    ('Fortis Gurgaon','MRI-FRT-GGN-01','spine_coil','1_5t','2026-07-02',
     true,1,true,'not_applicable','worn',null,null,true,true,'conditional_pass','One element dropout, connector worn — monitor next cycle'),
    ('Fortis Gurgaon','MRI-FRT-GGN-01','surface_flex_coil','1_5t','2026-07-02',
     false,3,false,'not_applicable','cracked',null,null,false,true,'fail','SNR out of spec, 3 element dropout, cracked connector housing'),
    ('Manipal Bengaluru Old Airport Road','MRI-MNP-BLR-01','body_coil','3t','2026-07-01',
     true,0,true,'not_applicable','good',null,null,true,true,'pass','Body coil clean pass on phantom QC'),
    ('Manipal Bengaluru Old Airport Road','MRI-MNP-BLR-01','cold_head_cryo','3t','2026-07-01',
     null,null,null,'not_applicable','good',68.50,false,null,true,'fail','Cold-head function fault, helium 68.5% and dropping'),
    ('AIIMS Delhi Ansari Nagar','MRI-AIM-DEL-01','head_coil','7t','2026-06-30',
     true,0,true,'not_applicable','good',null,null,true,true,'pass','7T research head coil nominal, SNR excellent'),
    ('AIIMS Delhi Ansari Nagar','MRI-AIM-DEL-01','gradient_system','7t','2026-06-30',
     null,null,false,'drift','good',null,null,false,false,'conditional_pass','Gradient linearity drift on Z, phantom borderline, cal due'),
    ('CMC Vellore','MRI-CMC-VEL-01','spine_coil','1_5t','2026-06-29',
     true,2,true,'not_applicable','replace_due',null,null,true,false,'conditional_pass','Two element dropout, connector replace due, cal overdue'),
    ('CMC Vellore','MRI-CMC-VEL-01','cold_head_cryo','1_5t','2026-06-29',
     null,null,null,'not_applicable','good',92.00,true,null,true,'pass','Cryo system healthy, helium 92%, cold-head nominal'),
    ('KIMS Hyderabad','MRI-KIM-HYD-01','body_coil','3t','2026-06-28',
     false,4,false,'not_applicable','cracked',null,null,false,true,'removed_from_service','Body coil failed SNR and uniformity — removed from service'),
    ('KIMS Hyderabad','MRI-KIM-HYD-01','gradient_system','3t','2026-06-28',
     null,null,true,'fail','good',null,null,false,true,'fail','Gradient linearity fail on Y axis, phantom QC fail'),
    ('Narayana Health Bengaluru','MRI-NRY-BLR-01','surface_flex_coil','open_mri','2026-06-27',
     true,0,true,'not_applicable','good',null,null,true,true,'pass','Open MRI flex coil pass, uniformity nominal'),
    ('Medanta Gurugram','MRI-MED-GGN-01','cold_head_cryo','3t','2026-06-27',
     null,null,null,'not_applicable','worn',74.00,false,null,false,'fail','Cold-head efficiency low, helium 74%, connector worn, cal overdue')
  ) as q(hosp, code, comp, fs, cd, snr, dropc, iuni, glin, cable, helium, coldfn, phantom, calib, qv, nt);

  -- CAPA seed — attach to specific checks via mri_code + component_type
  insert into public.mri_coil_gradient_capa_actions_r3351 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MRI-FRT-GGN-01','surface_flex_coil','coil_element_dropout','coil_element_failure','replace_coil','open','patient_safety_alert','2026-07-10',null,145000.00,'3 element dropout with cracked connector — coil replacement ordered'),
    ('MRI-MNP-BLR-01','cold_head_cryo','cold_head_failure','cold_head_wear','replace_cold_head','escalated','patient_safety_alert','2026-07-08',null,320000.00,'Cold-head fault, helium boiloff — OEM cryo service escalated'),
    ('MRI-AIM-DEL-01','gradient_system','gradient_linearity_drift','vibration_induced_drift','recalibrate_gradient','in_progress','iso_13485_deviation','2026-07-07',null,58000.00,'Gradient Z-axis drift — recalibration in progress'),
    ('MRI-CMC-VEL-01','spine_coil','calibration_overdue','preventive_service_backlog','update_calibration','verification_pending','internal_only','2026-07-05',null,8000.00,'Spine coil cal overdue, connector replace due — awaiting verification'),
    ('MRI-KIM-HYD-01','body_coil','snr_degradation','coil_element_failure','remove_from_service','closed','nabh_finding','2026-07-02','2026-06-30',210000.00,'Body coil failed SNR/uniformity — removed, replacement coil installed'),
    ('MRI-KIM-HYD-01','gradient_system','gradient_linearity_drift','gradient_coil_degradation','schedule_oem_service','overdue','cdsco_notifiable','2026-06-30',null,275000.00,'Gradient linearity fail Y axis — OEM service overdue'),
    ('MRI-MED-GGN-01','cold_head_cryo','helium_boiloff_high','helium_compressor_fault','service_helium_compressor','open','internal_only','2026-07-09',null,96000.00,'Helium at 74% with low cold-head efficiency — compressor service booked')
  ) as q(code, comp, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.mri_coil_gradient_r3351 e
    on e.organization_id = v_org_id and e.mri_code = q.code and e.component_type = q.comp;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3351_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mri_coil_gradient_r3351)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.mri_coil_gradient_r3351 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3351_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3351_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3351_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  snr_fail bigint,
  gradient_fail bigint,
  phantom_fail bigint,
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
    count(*) filter (where l.snr_within_spec = false)::bigint,
    count(*) filter (where l.gradient_linearity_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.phantom_qc_pass = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.mri_coil_gradient_r3351 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3351_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3351_hospital_scorecard() to authenticated;

-- 3) Component type × field strength matrix
create or replace function public.founder_r3351_component_field_matrix()
returns table(component_type text, field_strength text, checks bigint, passed bigint, avg_dropout numeric, avg_helium_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.component_type, l.field_strength, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.coil_element_dropout_count), 2),
    round(avg(l.helium_level_pct), 1)
  from public.mri_coil_gradient_r3351 l
  group by l.component_type, l.field_strength
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3351_component_field_matrix() from public, anon;
grant execute on function public.founder_r3351_component_field_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3351_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, snr_fail bigint, gradient_fail bigint)
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
    count(*) filter (where l.snr_within_spec = false)::bigint,
    count(*) filter (where l.gradient_linearity_ok in ('drift','fail'))::bigint
  from public.mri_coil_gradient_r3351 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3351_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3351_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3351_capa_status_board()
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
  from public.mri_coil_gradient_capa_actions_r3351 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3351_capa_status_board() from public, anon;
grant execute on function public.founder_r3351_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3351_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mri_coil_gradient_capa_actions_r3351)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.mri_coil_gradient_capa_actions_r3351 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3351_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3351_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3351_regulatory_impact_digest()
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
  from public.mri_coil_gradient_capa_actions_r3351 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3351_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3351_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3351_high_risk_queue()
returns table(
  hospital_name text,
  mri_code text,
  component_type text,
  field_strength text,
  check_date date,
  qc_verdict text,
  gradient_linearity_ok text,
  cable_connector_condition text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.mri_code, l.component_type, l.field_strength, l.check_date,
    l.qc_verdict, l.gradient_linearity_ok, l.cable_connector_condition, l.notes
  from public.mri_coil_gradient_r3351 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.snr_within_spec = false
     or l.image_uniformity_ok = false
     or l.gradient_linearity_ok in ('drift','fail')
     or l.phantom_qc_pass = false
     or l.cold_head_function_ok = false
     or l.cable_connector_condition in ('cracked','replace_due')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3351_high_risk_queue() from public, anon;
grant execute on function public.founder_r3351_high_risk_queue() to authenticated;
