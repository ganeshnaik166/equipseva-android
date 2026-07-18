-- Round 3271: Customer Hospital Pulmonary Function Test (PFT) Lab Equipment QC Audit
-- PFT lab QA — device type × volume-calibration (3L syringe) × flow linearity × leak test × bio-control × DLCO gas-analyzer cal × BTPS correction × filter hygiene × predicted-equation currency × CAPA

-- =============================================================================
-- TABLE 1: pft_lab_qc_r3271 — per-device PFT lab QC checks
-- =============================================================================
create table if not exists public.pft_lab_qc_r3271 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'spirometer_desktop','spirometer_portable','body_plethysmograph','dlco_unit','calibration_syringe_3l'
  )),
  department text not null,
  check_date date not null,
  volume_calibration_error_pct numeric(5,2),
  flow_linearity_ok boolean,
  leak_test text not null check (leak_test in (
    'pass','fail','not_done'
  )),
  biological_control_within_range boolean,
  gas_analyzer_calibration_ok boolean,
  ambient_btps_correction_ok boolean,
  filter_hygiene_ok boolean,
  software_predicted_set_current boolean,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pft_lab_qc_r3271 enable row level security;

create index if not exists idx_pft_lab_qc_r3271_org on public.pft_lab_qc_r3271(organization_id);
create index if not exists idx_pft_lab_qc_r3271_date on public.pft_lab_qc_r3271(check_date);
create index if not exists idx_pft_lab_qc_r3271_verdict on public.pft_lab_qc_r3271(qc_verdict);

-- =============================================================================
-- TABLE 2: pft_lab_qc_capa_actions_r3271 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.pft_lab_qc_capa_actions_r3271 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.pft_lab_qc_r3271(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'volume_calibration_error','flow_nonlinearity','leak_detected','biological_control_out_of_range',
    'gas_analyzer_drift','btps_correction_error','filter_hygiene_failure','predicted_set_outdated','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'syringe_seal_wear','flow_sensor_drift','pneumotach_contamination','gas_analyzer_cell_aging',
    'ambient_sensor_fault','filter_reuse','software_not_updated','operator_technique_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_syringe_seal','recalibrate_flow_sensor','clean_replace_pneumotach','replace_gas_analyzer_cell',
    'replace_ambient_sensor','replace_inline_filter','update_predicted_equations','retrain_pft_technician',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pft_lab_qc_capa_actions_r3271 enable row level security;

create index if not exists idx_pft_capa_r3271_log on public.pft_lab_qc_capa_actions_r3271(qc_log_id);
create index if not exists idx_pft_capa_r3271_status on public.pft_lab_qc_capa_actions_r3271(capa_status);

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

  -- 14 PFT lab QC rows
  insert into public.pft_lab_qc_r3271 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    volume_calibration_error_pct, flow_linearity_ok, leak_test, biological_control_within_range,
    gas_analyzer_calibration_ok, ambient_btps_correction_ok, filter_hygiene_ok, software_predicted_set_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.vcerr, q.flin, q.leak, q.bio,
    q.gas, q.btps, q.filt, q.sw,
    q.qv, q.nt
  from (values
    ('Apollo Hospitals Chennai Greams Road','PFT-APL-D01','spirometer_desktop','Pulmonology','2026-07-02',
     0.42,true,'pass',true,null,true,true,true,'pass','Quarterly QC — 3L syringe within 0.42%, all checks nominal'),
    ('Apollo Hospitals Chennai Greams Road','PFT-APL-C02','dlco_unit','Pulmonology','2026-07-02',
     1.10,true,'pass',true,true,true,true,false,'conditional_pass','DLCO gas analyzer OK but reference equations pre-GLI — update predicted set'),
    ('Fortis Memorial Gurgaon','PFT-FRT-P03','spirometer_portable','Respiratory Medicine','2026-07-01',
     2.90,false,'fail',false,null,true,true,true,'fail','Leak at mouthpiece connector and flow non-linear — unit tagged out'),
    ('Fortis Memorial Gurgaon','PFT-FRT-B04','body_plethysmograph','Pulmonology','2026-07-01',
     0.78,true,'pass',true,null,true,true,true,'pass','Cabin leak test pass, box calibration within spec'),
    ('Manipal Hospital Old Airport Road Bengaluru','PFT-MNP-S05','calibration_syringe_3l','Pulmonary Function Lab','2026-06-30',
     3.10,null,'pass',null,null,true,null,null,'conditional_pass','3L syringe volume error 3.1% approaching 3.5% limit — reseal advised'),
    ('Manipal Hospital Old Airport Road Bengaluru','PFT-MNP-C06','dlco_unit','Pulmonology','2026-06-30',
     1.60,true,'pass',false,false,true,true,true,'fail','DLCO gas analyzer CO/CH4 drift beyond 3% and bio-control low — recalibration required'),
    ('AIIMS New Delhi Ansari Nagar','PFT-AIM-D07','spirometer_desktop','Pulmonary Medicine','2026-06-29',
     0.55,true,'pass',true,null,true,true,true,'pass','Daily bio-QC subject within 5% of baseline — pass'),
    ('AIIMS New Delhi Ansari Nagar','PFT-AIM-B08','body_plethysmograph','Pulmonology','2026-06-29',
     4.20,false,'fail',false,null,false,false,true,'removed_from_service','Cabin leak fail, BTPS correction off and filter fouled — box withdrawn for service'),
    ('CMC Vellore','PFT-CMC-P09','spirometer_portable','Respiratory Medicine','2026-06-28',
     1.80,true,'pass',false,null,true,true,true,'conditional_pass','Bio-control subject FEV1 6.2% below range — repeat with second operator'),
    ('CMC Vellore','PFT-CMC-C10','dlco_unit','Pulmonology','2026-06-28',
     0.90,true,'pass',true,true,true,true,true,'pass','DLCO single-breath QC nominal, gas cal within 1%'),
    ('KIMS Hospital Secunderabad','PFT-KIM-S11','calibration_syringe_3l','PFT Lab','2026-06-27',
     5.40,null,'fail',null,null,true,null,null,'fail','Syringe volume error 5.4% and plunger leak — reference syringe quarantined'),
    ('KIMS Hospital Secunderabad','PFT-KIM-D12','spirometer_desktop','Pulmonology','2026-06-27',
     1.20,true,'pass',true,null,false,true,true,'conditional_pass','Ambient BTPS correction sensor reading high — verify temp/humidity probe'),
    ('Narayana Health City Bengaluru','PFT-NAR-P13','spirometer_portable','Respiratory Medicine','2026-06-26',
     0.66,true,'pass',true,null,true,true,true,'pass','Portable spirometer field QC pass after pneumotach clean'),
    ('Medanta The Medicity Gurugram','PFT-MDT-C14','dlco_unit','Pulmonology','2026-06-26',
     1.05,true,'pass',true,true,true,true,false,'conditional_pass','DLCO hardware pass but predicted set still ECSC 1993 — migrate to GLI 2017')
  ) as q(hosp, dcode, dtype, dept, cdate, vcerr, flin, leak, bio, gas, btps, filt, sw, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.pft_lab_qc_capa_actions_r3271 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PFT-FRT-P03','flow_nonlinearity','flow_sensor_drift','recalibrate_flow_sensor','open','nabh_finding','2026-07-08',null,15000.00,'Flow sensor non-linear and mouthpiece leak — recalibrate and reseal connector'),
    ('PFT-MNP-C06','gas_analyzer_drift','gas_analyzer_cell_aging','replace_gas_analyzer_cell','in_progress','iso_15189_deviation','2026-07-07',null,48000.00,'DLCO analyzer cell aged — replacement CO/CH4 cell ordered from OEM'),
    ('PFT-AIM-B08','btps_correction_error','ambient_sensor_fault','replace_ambient_sensor','escalated','patient_safety_alert','2026-07-04',null,22000.00,'Plethysmograph BTPS probe fault plus cabin leak — box removed, OEM service raised'),
    ('PFT-KIM-S11','volume_calibration_error','syringe_seal_wear','replace_syringe_seal','in_progress','iso_15189_deviation','2026-07-05',null,8000.00,'Reference 3L syringe leaking — seal kit sourced, whole lab affected'),
    ('PFT-KIM-D12','btps_correction_error','ambient_sensor_fault','replace_ambient_sensor','verification_pending','internal_only','2026-07-03',null,6500.00,'Temp/humidity probe swapped — verify BTPS factor on next daily QC'),
    ('PFT-CMC-P09','biological_control_out_of_range','operator_technique_error','retrain_pft_technician','closed','internal_only','2026-07-01','2026-06-30',0.00,'Repeat bio-QC with senior operator within range — coaching complete'),
    ('PFT-MDT-C14','predicted_set_outdated','software_not_updated','update_predicted_equations','overdue','internal_only','2026-06-20',null,5000.00,'Predicted set migration to GLI 2017 past target date — vendor licence pending')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.pft_lab_qc_r3271 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3271_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pft_lab_qc_r3271)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pft_lab_qc_r3271 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3271_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3271_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3271_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  leak_fail bigint,
  bio_control_fail bigint,
  btps_fail bigint,
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
    count(*) filter (where l.leak_test = 'fail')::bigint,
    count(*) filter (where l.biological_control_within_range is false)::bigint,
    count(*) filter (where l.ambient_btps_correction_ok is false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.pft_lab_qc_r3271 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3271_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3271_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3271_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_volume_cal_error_pct numeric, fail_checks bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.volume_calibration_error_pct), 2),
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint
  from public.pft_lab_qc_r3271 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3271_device_department_matrix() from public, anon;
grant execute on function public.founder_r3271_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3271_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, leak_fail bigint, bio_control_fail bigint)
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
    count(*) filter (where l.leak_test = 'fail')::bigint,
    count(*) filter (where l.biological_control_within_range is false)::bigint
  from public.pft_lab_qc_r3271 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3271_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3271_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3271_capa_status_board()
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
  from public.pft_lab_qc_capa_actions_r3271 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3271_capa_status_board() from public, anon;
grant execute on function public.founder_r3271_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3271_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pft_lab_qc_capa_actions_r3271)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pft_lab_qc_capa_actions_r3271 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3271_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3271_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3271_regulatory_impact_digest()
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
  from public.pft_lab_qc_capa_actions_r3271 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3271_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3271_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3271_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  leak_test text,
  volume_calibration_error_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.leak_test, l.volume_calibration_error_pct, l.notes
  from public.pft_lab_qc_r3271 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.leak_test = 'fail'
     or l.flow_linearity_ok is false
     or l.biological_control_within_range is false
     or l.gas_analyzer_calibration_ok is false
     or l.ambient_btps_correction_ok is false
     or l.filter_hygiene_ok is false
     or l.software_predicted_set_current is false
     or l.volume_calibration_error_pct >= 3.0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3271_high_risk_queue() from public, anon;
grant execute on function public.founder_r3271_high_risk_queue() to authenticated;
