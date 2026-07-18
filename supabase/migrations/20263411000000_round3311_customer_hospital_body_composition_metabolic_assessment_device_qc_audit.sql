-- Round 3311: Customer Hospital Body-Composition & Metabolic-Assessment Device QC Audit
-- Nutrition / endocrinology / sports-medicine QA — device type × phantom reference × impedance accuracy × gas-analyzer cal × flow-sensor cal × electrode condition × reference-gas stock × software equations × hygiene × calibration × CAPA

-- =============================================================================
-- TABLE 1: body_composition_metabolic_qc_r3311 — per-device QC checks
-- =============================================================================
create table if not exists public.body_composition_metabolic_qc_r3311 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'bia_analyzer','segmental_bia','metabolic_cart','indirect_calorimeter','rmr_hood_system'
  )),
  department text not null,
  check_date date not null,
  phantom_reference_ok boolean,
  impedance_accuracy_error_pct numeric(5,2),
  gas_analyzer_calibration_ok boolean,
  flow_sensor_calibration_ok boolean,
  electrode_condition text not null check (electrode_condition in (
    'good','worn','replace_due','not_applicable'
  )),
  reference_gas_stock_ok boolean,
  software_equations_current boolean,
  hygiene_ok boolean,
  calibration_current boolean,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.body_composition_metabolic_qc_r3311 enable row level security;

create index if not exists idx_body_comp_metabolic_qc_r3311_org on public.body_composition_metabolic_qc_r3311(organization_id);
create index if not exists idx_body_comp_metabolic_qc_r3311_date on public.body_composition_metabolic_qc_r3311(check_date);
create index if not exists idx_body_comp_metabolic_qc_r3311_verdict on public.body_composition_metabolic_qc_r3311(qc_verdict);

-- =============================================================================
-- TABLE 2: body_composition_metabolic_qc_capa_actions_r3311 — CAPA findings
-- =============================================================================
create table if not exists public.body_composition_metabolic_qc_capa_actions_r3311 (
  id uuid primary key default gen_random_uuid(),
  qc_id uuid not null references public.body_composition_metabolic_qc_r3311(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'phantom_reference_failure','impedance_accuracy_deviation','gas_analyzer_calibration_failure',
    'flow_sensor_calibration_failure','electrode_worn','reference_gas_depleted',
    'software_equations_outdated','hygiene_deficiency','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'electrode_degradation','sensor_drift','gas_analyzer_drift','flow_sensor_fault',
    'reference_gas_empty','o2_cell_aging','firmware_out_of_date','equation_library_outdated',
    'cleaning_protocol_lapse','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_electrodes','recalibrate_impedance','recalibrate_gas_analyzer','replace_flow_sensor',
    'replace_reference_gas_cylinder','replace_o2_cell','update_firmware','update_equation_library',
    'deep_clean_and_disinfect','remove_from_service','schedule_oem_service','retrain_staff','none_required'
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

alter table public.body_composition_metabolic_qc_capa_actions_r3311 enable row level security;

create index if not exists idx_body_comp_metabolic_capa_r3311_qc on public.body_composition_metabolic_qc_capa_actions_r3311(qc_id);
create index if not exists idx_body_comp_metabolic_capa_r3311_status on public.body_composition_metabolic_qc_capa_actions_r3311(capa_status);

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

  -- 14 QC check rows
  insert into public.body_composition_metabolic_qc_r3311 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    phantom_reference_ok, impedance_accuracy_error_pct, gas_analyzer_calibration_ok,
    flow_sensor_calibration_ok, electrode_condition, reference_gas_stock_ok,
    software_equations_current, hygiene_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.phantom, q.imperr, q.gasok,
    q.flowok, q.electrode, q.refgas,
    q.sweq, q.hyg, q.calcur, q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','BCM-APL-01','bia_analyzer','nutrition','2026-07-05',
     true,1.20,null,null,'good',null,true,true,true,'pass','Quarterly QC — phantom within tolerance, impedance 1.2%'),
    ('Apollo Chennai Greams Road','BCM-APL-02','segmental_bia','sports_medicine','2026-07-05',
     true,4.80,null,null,'worn',null,true,true,true,'conditional_pass','Impedance error 4.8% near 5% ceiling; electrodes worn — replacement booked'),
    ('Fortis Gurgaon','BCM-FRT-01','metabolic_cart','endocrinology','2026-07-04',
     true,null,true,true,'not_applicable',true,true,true,true,'pass','Gas analyzer and flow sensor cal verified; reference gas full'),
    ('Fortis Gurgaon','BCM-FRT-02','indirect_calorimeter','endocrinology','2026-07-04',
     true,null,false,true,'not_applicable',false,true,true,false,'fail','Gas-analyzer cal failed and reference-gas cylinder empty — calibration lapsed'),
    ('Manipal Bengaluru Old Airport Road','BCM-MNP-01','bia_analyzer','nutrition','2026-07-03',
     false,7.90,null,null,'replace_due',null,true,true,false,'fail','Phantom reference out of range; impedance error 7.9% — calibration overdue'),
    ('Manipal Bengaluru Old Airport Road','BCM-MNP-02','rmr_hood_system','endocrinology','2026-07-03',
     true,null,true,false,'not_applicable',true,true,true,true,'conditional_pass','Canopy flow-sensor cal drift flagged; recheck scheduled'),
    ('AIIMS New Delhi Ansari Nagar','BCM-AIM-01','segmental_bia','sports_medicine','2026-07-02',
     true,2.10,null,null,'good',null,false,true,true,'conditional_pass','Segmental equation library one version behind — update pending'),
    ('AIIMS New Delhi Ansari Nagar','BCM-AIM-02','metabolic_cart','endocrinology','2026-07-02',
     true,null,true,true,'not_applicable',true,true,true,true,'pass','Annual QC clean pass — combustion verification within spec'),
    ('CMC Vellore','BCM-CMC-01','indirect_calorimeter','nutrition','2026-07-01',
     true,null,true,true,'not_applicable',false,true,false,true,'conditional_pass','Reference gas low and hygiene wipe-down overdue — flagged for action'),
    ('KIMS Hyderabad','BCM-KIM-01','bia_analyzer','nutrition','2026-06-30',
     true,0.90,null,null,'good',null,true,true,true,'pass','Phantom and impedance nominal; software equations current'),
    ('KIMS Hyderabad','BCM-KIM-02','metabolic_cart','endocrinology','2026-06-30',
     false,null,false,true,'not_applicable',true,false,true,false,'removed_from_service','Combustion verification failed twice; O2 cell aged — unit pulled from service'),
    ('Narayana Health Bengaluru','BCM-NAR-01','segmental_bia','sports_medicine','2026-06-29',
     true,3.30,null,null,'worn',null,true,true,true,'conditional_pass','Electrodes worn, replacement scheduled; impedance 3.3% within limit'),
    ('Medanta Gurugram','BCM-MED-01','rmr_hood_system','endocrinology','2026-06-28',
     true,null,true,true,'not_applicable',true,true,true,true,'pass','Hood system canopy leak-check and flow cal passed'),
    ('Aster Kochi','BCM-AST-01','indirect_calorimeter','nutrition','2026-06-27',
     true,null,false,false,'not_applicable',false,true,true,false,'fail','Gas-analyzer, flow-sensor and reference-gas checks failed — OEM service required')
  ) as q(hosp, dcode, dtype, dept, cdate, phantom, imperr, gasok, flowok, electrode, refgas, sweq, hyg, calcur, verdict, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.body_composition_metabolic_qc_capa_actions_r3311 (
    qc_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BCM-FRT-02','gas_analyzer_calibration_failure','gas_analyzer_drift','recalibrate_gas_analyzer','escalated','cdsco_notifiable','2026-07-09',null,38000.00,'O2/CO2 analyzer failed span cal — OEM engineer engaged, new reference gas ordered'),
    ('BCM-MNP-01','impedance_accuracy_deviation','sensor_drift','recalibrate_impedance','open','nabh_finding','2026-07-10',null,22000.00,'Phantom out of range and 7.9% impedance error — full recalibration scheduled'),
    ('BCM-KIM-02','calibration_overdue','o2_cell_aging','replace_o2_cell','in_progress','patient_safety_alert','2026-07-07',null,45000.00,'O2 fuel cell aged past life; replacement cell on order, unit quarantined'),
    ('BCM-AST-01','flow_sensor_calibration_failure','flow_sensor_fault','replace_flow_sensor','open','iso_15189_deviation','2026-07-11',null,31000.00,'Pneumotach flow sensor out of tolerance — OEM service visit booked'),
    ('BCM-AIM-01','software_equations_outdated','equation_library_outdated','update_equation_library','closed','internal_only','2026-07-04','2026-07-03',0.00,'Segmental equation library updated to current release — verified on QC subject'),
    ('BCM-CMC-01','reference_gas_depleted','reference_gas_empty','replace_reference_gas_cylinder','verification_pending','internal_only','2026-07-06',null,14000.00,'Reference gas cylinder swapped; awaiting post-swap calibration verification'),
    ('BCM-MNP-02','flow_sensor_calibration_failure','flow_sensor_fault','replace_flow_sensor','overdue','internal_only','2026-06-30',null,29000.00,'Canopy flow-sensor drift past target closure — AMC vendor delayed')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.body_composition_metabolic_qc_r3311 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3311_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.body_composition_metabolic_qc_r3311)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.body_composition_metabolic_qc_r3311 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3311_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3311_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3311_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  phantom_fail bigint,
  impedance_fail bigint,
  gas_flow_fail bigint,
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
    count(*) filter (where l.phantom_reference_ok = false)::bigint,
    count(*) filter (where l.impedance_accuracy_error_pct > 5)::bigint,
    count(*) filter (where l.gas_analyzer_calibration_ok = false or l.flow_sensor_calibration_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.body_composition_metabolic_qc_r3311 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3311_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3311_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3311_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_impedance_error_pct numeric, calibration_current_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.impedance_accuracy_error_pct), 2),
    round(100.0 * count(*) filter (where l.calibration_current = true)::numeric / nullif(count(*),0), 1)
  from public.body_composition_metabolic_qc_r3311 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3311_device_department_matrix() from public, anon;
grant execute on function public.founder_r3311_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3311_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, impedance_fail bigint, gas_analyzer_fail bigint)
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
    count(*) filter (where l.impedance_accuracy_error_pct > 5)::bigint,
    count(*) filter (where l.gas_analyzer_calibration_ok = false)::bigint
  from public.body_composition_metabolic_qc_r3311 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3311_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3311_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3311_capa_status_board()
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
  from public.body_composition_metabolic_qc_capa_actions_r3311 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3311_capa_status_board() from public, anon;
grant execute on function public.founder_r3311_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3311_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.body_composition_metabolic_qc_capa_actions_r3311)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.body_composition_metabolic_qc_capa_actions_r3311 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3311_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3311_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3311_regulatory_impact_digest()
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
  from public.body_composition_metabolic_qc_capa_actions_r3311 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3311_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3311_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (individual concerns)
create or replace function public.founder_r3311_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  electrode_condition text,
  impedance_accuracy_error_pct numeric,
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
    l.qc_verdict, l.electrode_condition, l.impedance_accuracy_error_pct, l.notes
  from public.body_composition_metabolic_qc_r3311 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.phantom_reference_ok = false
     or l.impedance_accuracy_error_pct > 5
     or l.gas_analyzer_calibration_ok = false
     or l.flow_sensor_calibration_ok = false
     or l.reference_gas_stock_ok = false
     or l.electrode_condition = 'replace_due'
     or l.software_equations_current = false
     or l.hygiene_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3311_high_risk_queue() from public, anon;
grant execute on function public.founder_r3311_high_risk_queue() to authenticated;
