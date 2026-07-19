-- Round 3334: Customer Hospital HIFU / IORT / PDT Advanced-Oncology Therapy Device QC Audit
-- Oncology device QA — device type × output-energy accuracy × focal targeting × thermometry × dose verify
--   × applicator cone × interlock × cooling × radiation shielding × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: oncology_device_qc_r3334 — per-device advanced-oncology therapy QC checks
-- =============================================================================
create table if not exists public.oncology_device_qc_r3334 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'hifu_ablation','iort_mobile_linac','iort_electron','pdt_laser_source','focused_ultrasound_neuro'
  )),
  department text not null,
  check_date date not null,
  output_energy_accuracy_error_pct numeric(5,2),
  targeting_focal_accuracy_mm numeric(5,2),
  thermometry_monitoring_ok text not null check (thermometry_monitoring_ok in (
    'ok','drift','fail','not_applicable'
  )),
  dose_delivery_verified boolean not null,
  applicator_cone_condition text not null check (applicator_cone_condition in (
    'good','worn','damaged','not_applicable'
  )),
  interlock_safety_ok boolean not null,
  cooling_system_ok boolean not null,
  radiation_shielding_ok text not null check (radiation_shielding_ok in (
    'ok','gap','not_applicable'
  )),
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oncology_device_qc_r3334 enable row level security;

create index if not exists idx_oncology_device_qc_r3334_org on public.oncology_device_qc_r3334(organization_id);
create index if not exists idx_oncology_device_qc_r3334_date on public.oncology_device_qc_r3334(check_date);
create index if not exists idx_oncology_device_qc_r3334_verdict on public.oncology_device_qc_r3334(qc_verdict);

-- =============================================================================
-- TABLE 2: oncology_device_qc_capa_actions_r3334 — CAPA findings for failed/at-risk devices
-- =============================================================================
create table if not exists public.oncology_device_qc_capa_actions_r3334 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.oncology_device_qc_r3334(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'output_energy_deviation','targeting_accuracy_deviation','thermometry_failure','dose_verification_failure',
    'applicator_cone_damage','interlock_failure','cooling_system_failure','radiation_shielding_gap',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_element_degradation','beam_output_drift','thermometry_sensor_fault','positioning_encoder_drift',
    'applicator_wear','interlock_switch_fault','coolant_pump_failure','shielding_seal_gap',
    'calibration_backlog','pending_investigation','operator_setup_error'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_transducer_array','recalibrate_beam_output','replace_thermometry_sensor','realign_positioning_system',
    'replace_applicator_cone','replace_interlock_switch','service_cooling_system','reseal_radiation_shielding',
    'recalibrate_and_verify','remove_from_service','schedule_oem_service','retrain_clinical_staff','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','aerb_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oncology_device_qc_capa_actions_r3334 enable row level security;

create index if not exists idx_oncology_device_capa_r3334_log on public.oncology_device_qc_capa_actions_r3334(qc_log_id);
create index if not exists idx_oncology_device_capa_r3334_status on public.oncology_device_qc_capa_actions_r3334(capa_status);

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

  -- 14 per-device QC rows
  insert into public.oncology_device_qc_r3334 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    output_energy_accuracy_error_pct, targeting_focal_accuracy_mm, thermometry_monitoring_ok,
    dose_delivery_verified, applicator_cone_condition, interlock_safety_ok, cooling_system_ok,
    radiation_shielding_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.oeerr, q.tfacc, q.therm,
    q.dosev, q.cone, q.interlock, q.cooling,
    q.shield, q.calcur, q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','HIFU-APL-01','hifu_ablation','Interventional Oncology','2026-07-03',
     1.80,0.90,'ok',true,'not_applicable',true,true,'not_applicable',true,'pass','Quarterly HIFU QC — focal and thermometry nominal'),
    ('Apollo Chennai Greams Road','IORT-APL-02','iort_mobile_linac','Surgical Oncology OT','2026-07-03',
     6.50,1.20,'not_applicable',true,'good',true,true,'ok',true,'conditional_pass','Output energy 6.5% above 5% action level — recheck booked'),
    ('Fortis Gurgaon','FUS-FRT-01','focused_ultrasound_neuro','Neurosurgery MRgFUS','2026-07-02',
     2.10,2.40,'drift',true,'not_applicable',true,true,'not_applicable',true,'conditional_pass','Focal targeting 2.4mm and thermometry drift on MRgFUS'),
    ('Fortis Gurgaon','IORT-FRT-02','iort_electron','Surgical Oncology OT','2026-07-02',
     3.20,1.00,'not_applicable',false,'worn',true,true,'gap',true,'fail','Dose delivery unverified and shielding gap at applicator dock'),
    ('Manipal Bengaluru Old Airport Road','PDT-MNP-01','pdt_laser_source','Dermatologic Oncology','2026-07-01',
     0.90,null,'not_applicable',true,'not_applicable',true,true,'not_applicable',true,'pass','630nm PDT source output within spec'),
    ('Manipal Bengaluru Old Airport Road','HIFU-MNP-02','hifu_ablation','Uro-Oncology','2026-07-01',
     1.10,1.10,'ok',true,'not_applicable',false,true,'not_applicable',true,'removed_from_service','Patient-motion interlock failed to halt sonication — unit removed'),
    ('AIIMS Delhi Ansari Nagar','IORT-AIM-01','iort_mobile_linac','Radiation Oncology OT','2026-06-30',
     4.10,1.30,'not_applicable',true,'good',true,true,'ok',false,'conditional_pass','AERB-traceable calibration lapsed — recal scheduled'),
    ('AIIMS Delhi Ansari Nagar','PDT-AIM-02','pdt_laser_source','Interventional Pulmonology','2026-06-30',
     8.40,null,'not_applicable',false,'not_applicable',true,false,'not_applicable',true,'fail','Light output 8.4% low and chiller fault — endobronchial PDT deferred'),
    ('CMC Vellore','HIFU-CMC-01','hifu_ablation','Hepatobiliary Oncology','2026-06-29',
     2.00,1.00,'ok',true,'not_applicable',true,true,'not_applicable',true,'pass','Annual HIFU QC clean pass'),
    ('CMC Vellore','IORT-CMC-02','iort_electron','Surgical Oncology OT','2026-06-29',
     5.60,1.50,'not_applicable',true,'damaged',true,true,'ok',true,'fail','Electron applicator cone cracked and energy 5.6% off — cone replaced'),
    ('KIMS Hyderabad','FUS-KIM-01','focused_ultrasound_neuro','Neurology MRgFUS','2026-06-28',
     1.40,0.80,'ok',true,'not_applicable',true,true,'not_applicable',true,'pass','Essential-tremor MRgFUS QC pass'),
    ('KIMS Hyderabad','HIFU-KIM-02','hifu_ablation','Uro-Oncology','2026-06-28',
     3.60,1.90,'drift',true,'not_applicable',true,true,'not_applicable',true,'conditional_pass','Thermometry drift and focal 1.9mm — transducer element check due'),
    ('Tata Memorial Hospital Mumbai','IORT-TMH-01','iort_mobile_linac','Radiation Oncology','2026-06-27',
     null,null,'not_applicable',false,'not_applicable',false,false,'gap',false,'removed_from_service','QC aborted — interlock, cooling and shielding faults, unit quarantined'),
    ('HCG Cancer Centre Bengaluru','PDT-HCG-01','pdt_laser_source','Head and Neck Oncology','2026-06-27',
     1.20,null,'not_applicable',true,'not_applicable',true,true,'not_applicable',true,'pass','Head and neck PDT source verified')
  ) as q(hosp, dcode, dtype, dept, cdate, oeerr, tfacc, therm, dosev, cone, interlock, cooling, shield, calcur, verdict, nt);

  -- CAPA seed — attach to specific QC checks via device_code
  insert into public.oncology_device_qc_capa_actions_r3334 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('IORT-APL-02','output_energy_deviation','beam_output_drift','recalibrate_beam_output','overdue','nabh_finding','2026-06-30',null,55000.00,'Beam output recal past target — AMC vendor delayed'),
    ('IORT-FRT-02','radiation_shielding_gap','shielding_seal_gap','reseal_radiation_shielding','in_progress','aerb_notifiable','2026-07-08',null,38000.00,'Shielding gap at applicator dock — reseal in progress'),
    ('PDT-AIM-02','cooling_system_failure','coolant_pump_failure','service_cooling_system','open','internal_only','2026-07-06',null,22000.00,'Chiller pump replacement scheduled with OEM'),
    ('IORT-CMC-02','applicator_cone_damage','applicator_wear','replace_applicator_cone','closed','iso_13485_deviation','2026-07-02','2026-06-30',47000.00,'Cracked electron cone replaced and re-verified'),
    ('HIFU-MNP-02','interlock_failure','interlock_switch_fault','replace_interlock_switch','escalated','patient_safety_alert','2026-07-04',null,61000.00,'Motion interlock did not halt sonication — escalated to OEM'),
    ('IORT-TMH-01','dose_verification_failure','pending_investigation','remove_from_service','escalated','cdsco_notifiable','2026-07-05',null,0.00,'Unit quarantined pending full multi-fault investigation'),
    ('HIFU-KIM-02','thermometry_failure','thermometry_sensor_fault','replace_thermometry_sensor','verification_pending','internal_only','2026-07-07',null,15000.00,'Thermometry sensor replaced — awaiting verification sonication')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.oncology_device_qc_r3334 e
    on e.organization_id = v_org_id and e.device_code = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3334_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oncology_device_qc_r3334)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.oncology_device_qc_r3334 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3334_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3334_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3334_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  thermometry_fail bigint,
  shielding_gap bigint,
  calibration_lapsed bigint,
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
    count(*) filter (where l.thermometry_monitoring_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.radiation_shielding_ok = 'gap')::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.oncology_device_qc_r3334 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3334_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3334_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3334_device_type_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_energy_error_pct numeric, avg_focal_accuracy_mm numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.output_energy_accuracy_error_pct), 2),
    round(avg(l.targeting_focal_accuracy_mm), 2)
  from public.oncology_device_qc_r3334 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3334_device_type_department_matrix() from public, anon;
grant execute on function public.founder_r3334_device_type_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3334_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, thermometry_fail bigint, calibration_lapsed bigint)
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
    count(*) filter (where l.thermometry_monitoring_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.oncology_device_qc_r3334 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3334_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3334_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3334_capa_status_board()
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
  from public.oncology_device_qc_capa_actions_r3334 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3334_capa_status_board() from public, anon;
grant execute on function public.founder_r3334_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3334_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oncology_device_qc_capa_actions_r3334)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.oncology_device_qc_capa_actions_r3334 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3334_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3334_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3334_regulatory_impact_digest()
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
  from public.oncology_device_qc_capa_actions_r3334 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3334_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3334_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3334_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  thermometry_monitoring_ok text,
  applicator_cone_condition text,
  radiation_shielding_ok text,
  dose_delivery_verified boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.thermometry_monitoring_ok, l.applicator_cone_condition,
    l.radiation_shielding_ok, l.dose_delivery_verified, l.notes
  from public.oncology_device_qc_r3334 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.thermometry_monitoring_ok in ('drift','fail')
     or l.applicator_cone_condition in ('worn','damaged')
     or l.radiation_shielding_ok = 'gap'
     or l.dose_delivery_verified = false
     or l.interlock_safety_ok = false
     or l.cooling_system_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3334_high_risk_queue() from public, anon;
grant execute on function public.founder_r3334_high_risk_queue() to authenticated;
