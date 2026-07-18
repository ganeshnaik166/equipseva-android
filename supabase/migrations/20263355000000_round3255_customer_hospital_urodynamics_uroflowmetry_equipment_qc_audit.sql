-- Round 3255: Customer Hospital Urodynamics & Uroflowmetry Equipment QC Audit
-- Urology diagnostics QA — device type × transducer zero-cal × pump flow accuracy × load-cell verification × catheter stock × printer report × infection-control wipe log × software currency × CAPA

-- =============================================================================
-- TABLE 1: urodynamics_uroflow_qc_r3255 — per-device QC checks
-- =============================================================================
create table if not exists public.urodynamics_uroflow_qc_r3255 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'urodynamics_multichannel','uroflowmeter_standalone','cystometry_pump','emg_pelvic_module'
  )),
  department text not null,
  check_date date not null,
  transducer_zero_calibration_ok boolean not null,
  pump_flow_accuracy_error_pct numeric(5,2),
  load_cell_verification text not null check (load_cell_verification in (
    'pass','drift_detected','fail'
  )),
  catheter_stock_adequate boolean not null,
  printer_report_ok text not null check (printer_report_ok in (
    'ok','faulty','not_configured'
  )),
  infection_control_wipe_log_ok boolean not null,
  software_version_current boolean not null,
  studies_this_month int not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.urodynamics_uroflow_qc_r3255 enable row level security;

create index if not exists idx_urodyn_qc_r3255_org on public.urodynamics_uroflow_qc_r3255(organization_id);
create index if not exists idx_urodyn_qc_r3255_date on public.urodynamics_uroflow_qc_r3255(check_date);
create index if not exists idx_urodyn_qc_r3255_verdict on public.urodynamics_uroflow_qc_r3255(qc_verdict);

-- =============================================================================
-- TABLE 2: urodynamics_uroflow_qc_capa_actions_r3255 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.urodynamics_uroflow_qc_capa_actions_r3255 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.urodynamics_uroflow_qc_r3255(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'transducer_zero_failure','pump_flow_deviation','load_cell_failure','printer_fault',
    'consumable_stockout','infection_control_gap','software_outdated','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_dome_wear','pump_tubing_degraded','load_cell_ageing','printer_head_worn',
    'procurement_delay','staff_documentation_lapse','oem_patch_pending',
    'pending_investigation','service_contract_lapsed'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_transducer_dome','replace_pump_tubing','recalibrate_load_cell','replace_printer_head',
    'expedite_catheter_order','retrain_urology_staff','apply_software_update',
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

alter table public.urodynamics_uroflow_qc_capa_actions_r3255 enable row level security;

create index if not exists idx_urodyn_capa_r3255_log on public.urodynamics_uroflow_qc_capa_actions_r3255(qc_log_id);
create index if not exists idx_urodyn_capa_r3255_status on public.urodynamics_uroflow_qc_capa_actions_r3255(capa_status);

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
  insert into public.urodynamics_uroflow_qc_r3255 (
    organization_id, hospital_name, device_code, device_type, department,
    check_date, transducer_zero_calibration_ok, pump_flow_accuracy_error_pct,
    load_cell_verification, catheter_stock_adequate, printer_report_ok,
    infection_control_wipe_log_ok, software_version_current, studies_this_month,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept,
    q.cdate::date, q.tzc, q.pfe,
    q.lcv, q.cstock, q.prn,
    q.icw, q.swv, q.studies,
    q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','URO-APL-001','urodynamics_multichannel','Urology OPD','2026-07-03',
     true,1.40,'pass',true,'ok',true,true,42,'pass','Quarterly QC clean — all six pressure channels within tolerance'),
    ('Apollo Chennai Greams Road','URO-APL-002','uroflowmeter_standalone','Urology OPD','2026-07-03',
     true,null,'drift_detected',true,'ok',true,true,88,'conditional_pass','Load cell read 3.1% low on 200 mL reference pour — recalibration booked'),
    ('Fortis Gurgaon Sector 44','URO-FRT-101','urodynamics_multichannel','Urology','2026-07-02',
     false,2.20,'pass',true,'ok',true,false,35,'conditional_pass','Pves transducer zero drifted on power-up; software two releases behind'),
    ('Fortis Gurgaon Sector 44','URO-FRT-102','cystometry_pump','Urodynamics Lab','2026-07-02',
     true,9.80,'pass',false,'ok',true,true,31,'fail','Pump infusing 9.8% fast at 50 mL/min; dual-lumen catheters at nil stock'),
    ('Manipal Bengaluru Old Airport Road','URO-MNP-201','uroflowmeter_standalone','Urology OPD','2026-07-01',
     true,null,'pass',true,'faulty',true,true,96,'conditional_pass','Thermal printer skipping lines — flow traces handwritten meanwhile'),
    ('Manipal Bengaluru Old Airport Road','URO-MNP-202','emg_pelvic_module','Urodynamics Lab','2026-07-01',
     true,null,'pass',true,'ok',false,true,18,'conditional_pass','EMG surface-electrode wipe log blank for last two weeks'),
    ('AIIMS Delhi Ansari Nagar','URO-AIM-301','urodynamics_multichannel','Urology','2026-06-30',
     true,1.10,'pass',true,'ok',true,true,64,'pass','High-volume lab — QC nominal, verified by engineer Arvind Nair'),
    ('AIIMS Delhi Ansari Nagar','URO-AIM-302','cystometry_pump','Urodynamics Lab','2026-06-30',
     false,12.50,'fail',true,'ok',true,false,27,'removed_from_service','Load cell failed 3-point check and pump 12.5% off — unit pulled'),
    ('CMC Vellore','URO-CMC-401','urodynamics_multichannel','Urology','2026-06-29',
     true,0.90,'pass',true,'ok',true,true,52,'pass','Annual QC pass — witnessed by Dr Ranjith Kumar'),
    ('CMC Vellore','URO-CMC-402','uroflowmeter_standalone','Paediatric Urology','2026-06-29',
     true,null,'pass',true,'not_configured',true,true,44,'conditional_pass','Flow reports exported to EMR only — bedside printer never configured'),
    ('KIMS Hyderabad Secunderabad','URO-KIM-501','urodynamics_multichannel','Urodynamics Lab','2026-06-28',
     true,4.80,'drift_detected',true,'ok',true,true,39,'conditional_pass','Pump error 4.8% near 5% limit plus load-cell drift — Suresh Babu to recalibrate'),
    ('KIMS Hyderabad Secunderabad','URO-KIM-502','emg_pelvic_module','Urodynamics Lab','2026-06-28',
     true,null,'pass',false,'ok',true,true,22,'conditional_pass','EMG patch electrodes below reorder level — indent raised'),
    ('Sri Ramachandra Chennai Porur','URO-SRM-601','cystometry_pump','Urology','2026-06-27',
     true,1.80,'pass',true,'ok',true,true,29,'pass','Post-AMC verification pass — engineer Vikram Shetty'),
    ('Medanta Gurgaon','URO-MDT-701','uroflowmeter_standalone','Urology OPD','2026-06-26',
     false,null,'fail',true,'faulty',false,false,71,'fail','Zero-cal, load cell, printer and wipe log all failed — escalated to OEM')
  ) as q(hosp, dcode, dtype, dept, cdate, tzc, pfe, lcv, cstock, prn, icw, swv, studies, qv, nt);

  -- CAPA seed — attach to specific checks via device code
  insert into public.urodynamics_uroflow_qc_capa_actions_r3255 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('URO-APL-002','load_cell_failure','load_cell_ageing','recalibrate_load_cell','in_progress','internal_only','2026-07-08',null,8500.00,'Reference-weight recalibration scheduled with OEM engineer'),
    ('URO-FRT-102','pump_flow_deviation','pump_tubing_degraded','replace_pump_tubing','open','nabh_finding','2026-07-09',null,6200.00,'Tubing kit ordered; interim manual-fill protocol in force'),
    ('URO-FRT-102','consumable_stockout','procurement_delay','expedite_catheter_order','escalated','patient_safety_alert','2026-07-05',null,45000.00,'Dual-lumen catheters at nil stock — urodynamics studies postponed'),
    ('URO-AIM-302','load_cell_failure','load_cell_ageing','remove_from_service','verification_pending','iso_13485_deviation','2026-07-12',null,145000.00,'Replacement load-cell module quoted by OEM — unit out of service'),
    ('URO-MNP-201','printer_fault','printer_head_worn','replace_printer_head','closed','internal_only','2026-07-04','2026-07-03',4800.00,'Print head replaced by Manipal biomedical team'),
    ('URO-MNP-202','infection_control_gap','staff_documentation_lapse','retrain_urology_staff','open','nabh_finding','2026-07-10',null,0.00,'Wipe-log refresher for urodynamics technicians — Sister Mary Joseph to lead'),
    ('URO-MDT-701','transducer_zero_failure','pending_investigation','schedule_oem_service','overdue','patient_safety_alert','2026-06-30',null,32000.00,'OEM visit past target date — unit restricted to supervised use')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.urodynamics_uroflow_qc_r3255 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3255_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.urodynamics_uroflow_qc_r3255)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.urodynamics_uroflow_qc_r3255 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3255_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3255_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3255_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  zero_cal_fail bigint,
  load_cell_issue bigint,
  stock_gap bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where not l.transducer_zero_calibration_ok)::bigint,
    count(*) filter (where l.load_cell_verification in ('drift_detected','fail'))::bigint,
    count(*) filter (where not l.catheter_stock_adequate)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.urodynamics_uroflow_qc_r3255 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3255_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3255_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3255_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_flow_error_pct numeric, total_studies bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.pump_flow_accuracy_error_pct), 2),
    coalesce(sum(l.studies_this_month),0)::bigint
  from public.urodynamics_uroflow_qc_r3255 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3255_device_department_matrix() from public, anon;
grant execute on function public.founder_r3255_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3255_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, zero_cal_fail bigint, printer_issue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where not l.transducer_zero_calibration_ok)::bigint,
    count(*) filter (where l.printer_report_ok in ('faulty','not_configured'))::bigint
  from public.urodynamics_uroflow_qc_r3255 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3255_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3255_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3255_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.urodynamics_uroflow_qc_capa_actions_r3255 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3255_capa_status_board() from public, anon;
grant execute on function public.founder_r3255_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3255_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.urodynamics_uroflow_qc_capa_actions_r3255)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.urodynamics_uroflow_qc_capa_actions_r3255 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3255_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3255_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3255_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.urodynamics_uroflow_qc_capa_actions_r3255 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3255_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3255_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3255_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  zero_cal_ok text,
  load_cell_verification text,
  printer_report_ok text,
  studies_this_month int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.check_date,
    l.qc_verdict,
    case when l.transducer_zero_calibration_ok then 'yes' else 'no' end,
    l.load_cell_verification, l.printer_report_ok,
    l.studies_this_month, l.notes
  from public.urodynamics_uroflow_qc_r3255 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or not l.transducer_zero_calibration_ok
     or l.load_cell_verification in ('drift_detected','fail')
     or l.printer_report_ok in ('faulty','not_configured')
     or not l.catheter_stock_adequate
     or not l.infection_control_wipe_log_ok
     or not l.software_version_current
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3255_high_risk_queue() from public, anon;
grant execute on function public.founder_r3255_high_risk_queue() to authenticated;
