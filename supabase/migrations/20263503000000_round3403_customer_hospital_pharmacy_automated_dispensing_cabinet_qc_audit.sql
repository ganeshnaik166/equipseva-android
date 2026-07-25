-- Round 3403: Customer Hospital Pharmacy Automated-Dispensing-Cabinet & Unit-Dose Packager QC Audit
-- Pharmacy ADC QA — device type × location × drawer access/biometric × inventory accuracy × controlled-substance reconciliation × temperature × barcode × seal integrity × label print × override log × calibration × CAPA

-- =============================================================================
-- TABLE 1: pharmacy_adc_qc_r3403 — per-device ADC / unit-dose packager QC checks
-- =============================================================================
create table if not exists public.pharmacy_adc_qc_r3403 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'automated_dispensing_cabinet','unit_dose_packager','iv_admixture_pump',
    'narcotic_vault_cabinet','carousel_storage'
  )),
  location text not null check (location in (
    'central_pharmacy','icu_satellite','ed_pharmacy','or_suite','oncology_pharmacy','general_ward'
  )),
  check_date date not null,
  drawer_access_control_ok boolean not null,
  biometric_login_ok boolean not null,
  inventory_accuracy_pct numeric(5,2),
  controlled_substance_reconciliation_ok boolean not null,
  temperature_monitored_ok boolean not null,
  barcode_verification_ok boolean not null,
  packager_seal_integrity_ok text not null check (packager_seal_integrity_ok in (
    'ok','weak','fail','not_applicable'
  )),
  label_print_ok boolean not null,
  override_log_reviewed boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pharmacy_adc_qc_r3403 enable row level security;

create index if not exists idx_pharmacy_adc_qc_r3403_org on public.pharmacy_adc_qc_r3403(organization_id);
create index if not exists idx_pharmacy_adc_qc_r3403_date on public.pharmacy_adc_qc_r3403(check_date);
create index if not exists idx_pharmacy_adc_qc_r3403_verdict on public.pharmacy_adc_qc_r3403(qc_verdict);

-- =============================================================================
-- TABLE 2: pharmacy_adc_qc_capa_actions_r3403 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.pharmacy_adc_qc_capa_actions_r3403 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.pharmacy_adc_qc_r3403(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'drawer_access_control_failure','biometric_login_failure','inventory_count_discrepancy',
    'controlled_substance_reconciliation_failure','temperature_excursion','barcode_verification_failure',
    'packager_seal_defect','label_print_error','override_log_unreviewed','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'solenoid_lock_fault','biometric_reader_fault','stocking_error','diversion_suspected',
    'count_process_error','sensor_calibration_drift','barcode_scanner_fault','sealing_element_worn',
    'printer_hardware_fault','software_config_error','operator_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_lock_mechanism','replace_biometric_reader','recount_and_correct_inventory',
    'initiate_diversion_investigation','recalibrate_temperature_sensor','replace_barcode_scanner',
    'replace_sealing_element','replace_printer_head','update_software_config','retrain_pharmacy_staff',
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

alter table public.pharmacy_adc_qc_capa_actions_r3403 enable row level security;

create index if not exists idx_pharmacy_adc_capa_r3403_log on public.pharmacy_adc_qc_capa_actions_r3403(qc_log_id);
create index if not exists idx_pharmacy_adc_capa_r3403_status on public.pharmacy_adc_qc_capa_actions_r3403(capa_status);

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
  insert into public.pharmacy_adc_qc_r3403 (
    organization_id, hospital_name, device_code, device_type, location, check_date,
    drawer_access_control_ok, biometric_login_ok, inventory_accuracy_pct,
    controlled_substance_reconciliation_ok, temperature_monitored_ok, barcode_verification_ok,
    packager_seal_integrity_ok, label_print_ok, override_log_reviewed,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.loc, q.cdate::date,
    q.access, q.bio, q.invacc,
    q.csr, q.temp, q.barcode,
    q.seal, q.label, q.override,
    q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','ADC-APL-01','automated_dispensing_cabinet','central_pharmacy','2026-07-10',
     true,true,99.6,true,true,true,'not_applicable',true,true,true,'pass','Monthly ADC QC — access, biometric and inventory reconciliation clean'),
    ('Apollo Chennai','UDP-APL-02','unit_dose_packager','central_pharmacy','2026-07-10',
     true,true,null,true,true,true,'ok',true,true,true,'pass','Unit-dose packager seal and label print QC nominal'),
    ('Fortis Gurgaon','ADC-FRT-11','automated_dispensing_cabinet','icu_satellite','2026-07-09',
     true,true,97.8,true,true,true,'not_applicable',true,false,true,'conditional_pass','Override log not reviewed within 24h window — pharmacist follow-up'),
    ('Fortis Gurgaon','NVC-FRT-12','narcotic_vault_cabinet','icu_satellite','2026-07-09',
     false,true,94.2,false,true,true,'not_applicable',true,false,true,'fail','Drawer access control fault and controlled-substance reconciliation discrepancy'),
    ('Manipal Bengaluru','UDP-MNP-21','unit_dose_packager','central_pharmacy','2026-07-08',
     true,true,null,true,true,false,'fail',false,true,false,'removed_from_service','Seal integrity fail with barcode/label errors and calibration overdue — removed'),
    ('Manipal Bengaluru','IVP-MNP-22','iv_admixture_pump','oncology_pharmacy','2026-07-08',
     true,true,null,true,true,true,'not_applicable',true,true,true,'pass','IV admixture compounding pump QC nominal'),
    ('AIIMS Delhi','ADC-AIM-31','automated_dispensing_cabinet','ed_pharmacy','2026-07-07',
     true,true,98.9,true,true,true,'not_applicable',true,true,true,'conditional_pass','Minor inventory variance trend flagged for watch'),
    ('AIIMS Delhi','NVC-AIM-32','narcotic_vault_cabinet','or_suite','2026-07-07',
     true,false,91.5,false,true,true,'not_applicable',true,false,true,'fail','Biometric login failure and reconciliation shortfall — diversion review opened'),
    ('CMC Vellore','CAR-CMC-41','carousel_storage','central_pharmacy','2026-07-06',
     true,true,99.1,true,true,true,'not_applicable',true,true,true,'pass','Carousel storage inventory QC pass'),
    ('CMC Vellore','ADC-CMC-42','automated_dispensing_cabinet','general_ward','2026-07-06',
     true,true,96.4,true,false,true,'not_applicable',true,true,false,'conditional_pass','Temperature monitoring gap and calibration overdue — service scheduled'),
    ('KIMS Hyderabad','ADC-KIM-51','automated_dispensing_cabinet','icu_satellite','2026-07-05',
     true,true,99.3,true,true,true,'not_applicable',true,true,true,'pass','ADC QC pass post-AMC'),
    ('KIMS Hyderabad','UDP-KIM-52','unit_dose_packager','central_pharmacy','2026-07-05',
     true,true,null,true,true,true,'weak',true,true,true,'conditional_pass','Packager seal weak on strip edge — recheck due'),
    ('Yashoda Hyderabad','IVP-YSH-61','iv_admixture_pump','oncology_pharmacy','2026-07-04',
     true,true,null,true,true,true,'not_applicable',true,true,true,'pass','Chemo IV admixture pump QC nominal'),
    ('Kokilaben Mumbai','NVC-KKB-71','narcotic_vault_cabinet','or_suite','2026-07-04',
     false,false,88.7,false,true,false,'not_applicable',true,false,false,'removed_from_service','Multiple failures incl. access, biometric, reconciliation and calibration — removed from service')
  ) as q(hosp, dcode, dtype, loc, cdate, access, bio, invacc, csr, temp, barcode, seal, label, override, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.pharmacy_adc_qc_capa_actions_r3403 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('NVC-FRT-12','drawer_access_control_failure','solenoid_lock_fault','replace_lock_mechanism','in_progress','iso_13485_deviation','2026-07-13',null,18000.00,'Access solenoid lock replacement in progress; reconciliation recount pending'),
    ('UDP-MNP-21','packager_seal_defect','sealing_element_worn','replace_sealing_element','open','nabh_finding','2026-07-12',null,26000.00,'Sealing element worn — replacement kit ordered, packager offline'),
    ('NVC-AIM-32','controlled_substance_reconciliation_failure','diversion_suspected','initiate_diversion_investigation','escalated','patient_safety_alert','2026-07-11',null,12000.00,'Reconciliation shortfall — diversion investigation escalated to compliance'),
    ('NVC-KKB-71','biometric_login_failure','biometric_reader_fault','replace_biometric_reader','closed','cdsco_notifiable','2026-07-09','2026-07-06',34000.00,'Faulty biometric reader replaced; cabinet revalidated and returned to service'),
    ('ADC-FRT-11','override_log_unreviewed','operator_error','retrain_pharmacy_staff','verification_pending','internal_only','2026-07-12',null,3500.00,'Pharmacy staff retrained on override review SLA — verify next audit'),
    ('ADC-CMC-42','temperature_excursion','sensor_calibration_drift','recalibrate_temperature_sensor','overdue','internal_only','2026-07-08',null,9500.00,'Temperature sensor recalibration past target date — vendor delay'),
    ('ADC-AIM-31','inventory_count_discrepancy','stocking_error','recount_and_correct_inventory','open','none','2026-07-11',null,0.00,'Inventory variance investigated — cycle-count correction scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.pharmacy_adc_qc_r3403 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3403_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pharmacy_adc_qc_r3403)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pharmacy_adc_qc_r3403 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3403_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3403_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3403_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  access_control_fail bigint,
  reconciliation_fail bigint,
  calibration_overdue bigint,
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
    count(*) filter (where l.drawer_access_control_ok = false or l.biometric_login_ok = false)::bigint,
    count(*) filter (where l.controlled_substance_reconciliation_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.pharmacy_adc_qc_r3403 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3403_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3403_hospital_scorecard() to authenticated;

-- 3) Device-type × location matrix
create or replace function public.founder_r3403_device_type_location_matrix()
returns table(device_type text, location text, checks bigint, passed bigint, failed bigint, avg_inventory_accuracy_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.location, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.inventory_accuracy_pct), 2)
  from public.pharmacy_adc_qc_r3403 l
  group by l.device_type, l.location
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3403_device_type_location_matrix() from public, anon;
grant execute on function public.founder_r3403_device_type_location_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3403_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, access_control_fail bigint, reconciliation_fail bigint)
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
    count(*) filter (where l.drawer_access_control_ok = false or l.biometric_login_ok = false)::bigint,
    count(*) filter (where l.controlled_substance_reconciliation_ok = false)::bigint
  from public.pharmacy_adc_qc_r3403 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3403_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3403_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3403_capa_status_board()
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
  from public.pharmacy_adc_qc_capa_actions_r3403 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3403_capa_status_board() from public, anon;
grant execute on function public.founder_r3403_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3403_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pharmacy_adc_qc_capa_actions_r3403)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pharmacy_adc_qc_capa_actions_r3403 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3403_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3403_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3403_regulatory_impact_digest()
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
  from public.pharmacy_adc_qc_capa_actions_r3403 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3403_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3403_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3403_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  location text,
  check_date date,
  qc_verdict text,
  packager_seal_integrity_ok text,
  inventory_accuracy_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.location, l.check_date,
    l.qc_verdict, l.packager_seal_integrity_ok, l.inventory_accuracy_pct, l.notes
  from public.pharmacy_adc_qc_r3403 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.drawer_access_control_ok = false
     or l.biometric_login_ok = false
     or l.controlled_substance_reconciliation_ok = false
     or l.temperature_monitored_ok = false
     or l.barcode_verification_ok = false
     or l.label_print_ok = false
     or l.override_log_reviewed = false
     or l.calibration_current = false
     or l.packager_seal_integrity_ok in ('weak','fail')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3403_high_risk_queue() from public, anon;
grant execute on function public.founder_r3403_high_risk_queue() to authenticated;
