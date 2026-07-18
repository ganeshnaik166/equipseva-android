-- Round 3291: Customer Hospital Echocardiography & Cardiac/General Ultrasound QC Audit
-- Ultrasound QA — system type × B-mode uniformity × Doppler sensitivity × element dropout × probe damage × TEE air-bubble × elastography cal × measurement accuracy × leakage current × DICOM export × CAPA

-- =============================================================================
-- TABLE 1: echo_ultrasound_qc_r3291 — per-system ultrasound QC checks
-- =============================================================================
create table if not exists public.echo_ultrasound_qc_r3291 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  system_code text not null,
  system_type text not null check (system_type in (
    'echo_cardiology','general_ultrasound','portable_pocus','tee_system','vascular_doppler'
  )),
  department text not null,
  check_date date not null,
  checked_at timestamptz not null,
  bmode_image_uniformity_ok boolean not null,
  doppler_sensitivity_ok boolean not null,
  transducer_element_dropout_count int not null,
  probe_physical_damage text not null check (probe_physical_damage in (
    'none','lens_wear','cable_fray','crack','tee_bite_damage'
  )),
  air_bubble_test_ok boolean,
  elastography_calibration_ok text not null check (elastography_calibration_ok in (
    'pass','drift','not_applicable'
  )),
  measurement_accuracy_error_pct numeric(5,2),
  leakage_current_ua numeric(6,2),
  dicom_export_ok boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.echo_ultrasound_qc_r3291 enable row level security;

create index if not exists idx_echo_ultrasound_qc_r3291_org on public.echo_ultrasound_qc_r3291(organization_id);
create index if not exists idx_echo_ultrasound_qc_r3291_date on public.echo_ultrasound_qc_r3291(check_date);
create index if not exists idx_echo_ultrasound_qc_r3291_verdict on public.echo_ultrasound_qc_r3291(qc_verdict);

-- =============================================================================
-- TABLE 2: echo_ultrasound_qc_capa_actions_r3291 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.echo_ultrasound_qc_capa_actions_r3291 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.echo_ultrasound_qc_r3291(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_uniformity_defect','doppler_sensitivity_loss','element_dropout','probe_damage',
    'air_bubble_leak','elastography_drift','measurement_inaccuracy','leakage_current_high',
    'dicom_export_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_element_failure','probe_lens_wear','cable_insulation_damage','tee_probe_bite_damage',
    'beamformer_fault','calibration_drift','fluid_ingress','software_config_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_transducer','repair_probe_cable','replace_tee_probe','recalibrate_system',
    'beamformer_board_service','seal_and_leak_test','update_software_config','retrain_sonographer',
    'remove_from_service','schedule_oem_service','none_required'
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

alter table public.echo_ultrasound_qc_capa_actions_r3291 enable row level security;

create index if not exists idx_echo_ultrasound_capa_r3291_log on public.echo_ultrasound_qc_capa_actions_r3291(qc_log_id);
create index if not exists idx_echo_ultrasound_capa_r3291_status on public.echo_ultrasound_qc_capa_actions_r3291(capa_status);

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

  -- 14 ultrasound QC check rows
  insert into public.echo_ultrasound_qc_r3291 (
    organization_id, hospital_name, system_code, system_type, department, check_date, checked_at,
    bmode_image_uniformity_ok, doppler_sensitivity_ok, transducer_element_dropout_count, probe_physical_damage,
    air_bubble_test_ok, elastography_calibration_ok, measurement_accuracy_error_pct, leakage_current_ua,
    dicom_export_ok, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.stype, q.dept, q.cd::date, q.ts::timestamptz,
    q.bmode, q.doppler, q.dropout, q.damage,
    q.airbubble, q.elasto, q.merr, q.leak,
    q.dicom, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','US-APL-C01','echo_cardiology','Cardiology','2026-07-03','2026-07-03 07:20:00+05:30',
     true,true,0,'none',true,'pass',1.20,8.40,true,'pass','Quarterly QC — B-mode uniform, Doppler nominal'),
    ('Apollo Chennai Greams Road','US-APL-T02','tee_system','Cardiac Anaesthesia','2026-07-03','2026-07-03 08:30:00+05:30',
     true,true,2,'lens_wear',true,'not_applicable',2.10,9.10,true,'conditional_pass','Minor lens wear on TEE probe — image still diagnostic, monitor'),
    ('Fortis Gurgaon','US-FRT-T01','tee_system','Cardiology','2026-07-02','2026-07-02 06:50:00+05:30',
     true,true,3,'tee_bite_damage',false,'not_applicable',2.80,11.20,true,'removed_from_service','TEE bite-mark + air-bubble leak test failed — probe quarantined'),
    ('Fortis Gurgaon','US-FRT-G02','general_ultrasound','Radiology','2026-07-02','2026-07-02 09:10:00+05:30',
     false,true,6,'none',true,'drift',5.60,9.80,true,'fail','B-mode non-uniform + elastography drift beyond tolerance'),
    ('Manipal Bengaluru Old Airport Road','US-MNP-C01','echo_cardiology','Cardiology','2026-07-01','2026-07-01 07:40:00+05:30',
     true,true,4,'none',true,'not_applicable',1.90,8.90,true,'conditional_pass','4 element dropout on phased-array probe — recheck in 30 days'),
    ('Manipal Bengaluru Old Airport Road','US-MNP-V02','vascular_doppler','Vascular Surgery','2026-07-01','2026-07-01 08:50:00+05:30',
     true,true,0,'none',true,'not_applicable',1.10,7.60,true,'pass','Vascular Doppler sensitivity within spec'),
    ('AIIMS Delhi Ansari Nagar','US-AIM-G01','general_ultrasound','Radiology','2026-06-30','2026-06-30 06:30:00+05:30',
     true,false,5,'cable_fray',true,'not_applicable',4.30,13.50,false,'fail','Doppler sensitivity loss + frayed cable, DICOM export failing'),
    ('AIIMS Delhi Ansari Nagar','US-AIM-P02','portable_pocus','Emergency','2026-06-30','2026-06-30 10:15:00+05:30',
     true,true,1,'none',true,'not_applicable',1.40,6.20,true,'pass','POCUS handheld — clean QC'),
    ('CMC Vellore','US-CMC-C01','echo_cardiology','Cardiology','2026-06-29','2026-06-29 07:10:00+05:30',
     true,true,0,'none',true,'pass',0.90,7.90,true,'pass','Annual QC — elastography cal within limits'),
    ('CMC Vellore','US-CMC-T02','tee_system','Cardiac Surgery','2026-06-29','2026-06-29 08:20:00+05:30',
     true,true,1,'none',true,'not_applicable',2.00,17.80,true,'conditional_pass','Leakage current 17.8uA nearing 20uA action limit — watch'),
    ('KIMS Hyderabad Kondapur','US-KIM-G01','general_ultrasound','Radiology','2026-06-28','2026-06-28 06:40:00+05:30',
     true,true,2,'crack',false,'drift',3.10,26.40,true,'removed_from_service','Housing crack + leakage 26.4uA over limit — unit withdrawn'),
    ('KIMS Hyderabad Kondapur','US-KIM-V02','vascular_doppler','Vascular Surgery','2026-06-28','2026-06-28 09:30:00+05:30',
     true,false,3,'none',true,'not_applicable',2.60,9.30,true,'conditional_pass','Colour Doppler sensitivity marginal — probe swap scheduled'),
    ('Narayana Health Bengaluru','US-NAR-T01','tee_system','Cardiology','2026-06-27','2026-06-27 07:00:00+05:30',
     false,false,8,'crack',false,'not_applicable',null,null,false,'fail','Multiple defects — QC aborted, DICOM node unreachable, revisit booked'),
    ('Rainbow Hospitals Hyderabad','US-RBW-P01','portable_pocus','Paediatric ICU','2026-06-27','2026-06-27 08:40:00+05:30',
     true,true,0,'none',true,'not_applicable',1.00,6.80,true,'pass','Paediatric POCUS verified')
  ) as q(hosp, code, stype, dept, cd, ts, bmode, doppler, dropout, damage, airbubble, elasto, merr, leak, dicom, qv, nt);

  -- CAPA seed — attach to specific checks via system_code
  insert into public.echo_ultrasound_qc_capa_actions_r3291 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('US-FRT-T01','air_bubble_leak','tee_probe_bite_damage','replace_tee_probe','escalated','patient_safety_alert','2026-07-06',null,485000.00,'Bite-damaged TEE probe leaking — OEM replacement quoted'),
    ('US-FRT-G02','elastography_drift','calibration_drift','recalibrate_system','in_progress','iso_13485_deviation','2026-07-07',null,15000.00,'Elastography phantom recal + B-mode uniformity retest booked'),
    ('US-AIM-G01','doppler_sensitivity_loss','cable_insulation_damage','repair_probe_cable','open','nabh_finding','2026-07-09',null,32000.00,'Frayed curvilinear probe cable — repair + DICOM node fix'),
    ('US-KIM-G01','leakage_current_high','fluid_ingress','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-30',0.00,'Cracked housing with fluid ingress — permanently retired'),
    ('US-NAR-T01','element_dropout','transducer_element_failure','replace_transducer','escalated','patient_safety_alert','2026-07-04',null,520000.00,'8-element dropout on TEE array — condemned, replacement sourced'),
    ('US-APL-T02','probe_damage','probe_lens_wear','schedule_oem_service','verification_pending','internal_only','2026-07-15',null,28000.00,'Lens wear monitored — OEM refurb scheduled next PM window'),
    ('US-CMC-T02','leakage_current_high','pending_investigation','seal_and_leak_test','overdue','internal_only','2026-06-30',null,9000.00,'Leakage nearing limit — seal/leak test past target date')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.echo_ultrasound_qc_r3291 e
    on e.organization_id = v_org_id and e.system_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3291_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.echo_ultrasound_qc_r3291)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.echo_ultrasound_qc_r3291 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3291_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3291_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3291_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  bmode_fail bigint,
  doppler_fail bigint,
  probe_damaged bigint,
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
    count(*) filter (where l.bmode_image_uniformity_ok = false)::bigint,
    count(*) filter (where l.doppler_sensitivity_ok = false)::bigint,
    count(*) filter (where l.probe_physical_damage <> 'none')::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.echo_ultrasound_qc_r3291 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3291_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3291_hospital_scorecard() to authenticated;

-- 3) System type × probe damage matrix
create or replace function public.founder_r3291_system_probe_matrix()
returns table(system_type text, probe_physical_damage text, checks bigint, passed bigint, avg_measurement_error_pct numeric, avg_leakage_current_ua numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_type, l.probe_physical_damage, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.measurement_accuracy_error_pct), 2),
    round(avg(l.leakage_current_ua), 2)
  from public.echo_ultrasound_qc_r3291 l
  group by l.system_type, l.probe_physical_damage
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3291_system_probe_matrix() from public, anon;
grant execute on function public.founder_r3291_system_probe_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3291_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, doppler_fail bigint, dicom_fail bigint)
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
    count(*) filter (where l.doppler_sensitivity_ok = false)::bigint,
    count(*) filter (where l.dicom_export_ok = false)::bigint
  from public.echo_ultrasound_qc_r3291 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3291_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3291_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3291_capa_status_board()
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
  from public.echo_ultrasound_qc_capa_actions_r3291 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3291_capa_status_board() from public, anon;
grant execute on function public.founder_r3291_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3291_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.echo_ultrasound_qc_capa_actions_r3291)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.echo_ultrasound_qc_capa_actions_r3291 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3291_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3291_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3291_regulatory_impact_digest()
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
  from public.echo_ultrasound_qc_capa_actions_r3291 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3291_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3291_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3291_high_risk_queue()
returns table(
  hospital_name text,
  system_code text,
  system_type text,
  department text,
  check_date date,
  qc_verdict text,
  probe_physical_damage text,
  elastography_calibration_ok text,
  leakage_current_ua numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.system_code, l.system_type, l.department, l.check_date,
    l.qc_verdict, l.probe_physical_damage, l.elastography_calibration_ok, l.leakage_current_ua, l.notes
  from public.echo_ultrasound_qc_r3291 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.bmode_image_uniformity_ok = false
     or l.doppler_sensitivity_ok = false
     or l.probe_physical_damage <> 'none'
     or l.air_bubble_test_ok = false
     or l.elastography_calibration_ok = 'drift'
     or l.dicom_export_ok = false
     or l.transducer_element_dropout_count > 2
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3291_high_risk_queue() from public, anon;
grant execute on function public.founder_r3291_high_risk_queue() to authenticated;
