-- Round 3363: Customer Hospital Suction, Nebulizer & Oxygen-Therapy Device Fleet QC Audit
-- Respiratory-support QA — device type × ward × vacuum-pressure accuracy × flow-rate error × oxygen purity × filter condition × canister seal × alarm test × tubing hygiene × calibration × CAPA

-- =============================================================================
-- TABLE 1: suction_oxygen_qc_r3363 — per-device respiratory-support QC checks
-- =============================================================================
create table if not exists public.suction_oxygen_qc_r3363 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'suction_machine','thoracic_suction','nebulizer',
    'oxygen_concentrator_ward','oxygen_flowmeter','humidifier_bottle'
  )),
  ward text not null,
  check_date date not null,
  vacuum_pressure_accuracy_ok text not null check (vacuum_pressure_accuracy_ok in (
    'ok','low','fail','not_applicable'
  )),
  flow_rate_accuracy_error_pct numeric(5,2),
  oxygen_purity_pct numeric(5,2),
  filter_condition text not null check (filter_condition in (
    'clean','due','blocked','replace_due'
  )),
  canister_seal_ok boolean not null,
  alarm_test text not null check (alarm_test in (
    'pass','fail','not_tested','not_applicable'
  )),
  tubing_hygiene_ok boolean not null,
  noise_level_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.suction_oxygen_qc_r3363 enable row level security;

create index if not exists idx_suction_oxygen_qc_r3363_org on public.suction_oxygen_qc_r3363(organization_id);
create index if not exists idx_suction_oxygen_qc_r3363_date on public.suction_oxygen_qc_r3363(check_date);
create index if not exists idx_suction_oxygen_qc_r3363_verdict on public.suction_oxygen_qc_r3363(qc_verdict);

-- =============================================================================
-- TABLE 2: suction_oxygen_qc_capa_actions_r3363 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.suction_oxygen_qc_capa_actions_r3363 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.suction_oxygen_qc_r3363(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'vacuum_pressure_low','flow_rate_deviation','oxygen_purity_low','filter_blocked',
    'canister_seal_leak','alarm_test_failure','tubing_contamination','excessive_noise',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'pump_diaphragm_worn','vacuum_seal_perished','sieve_bed_saturated','filter_not_replaced',
    'canister_gasket_cracked','alarm_module_fault','tubing_reuse_breach','motor_bearing_wear',
    'calibration_lapsed','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_pump_diaphragm','replace_vacuum_seal','replace_sieve_bed','replace_filter',
    'replace_canister_gasket','repair_alarm_module','replace_tubing_set','service_motor_assembly',
    'recalibrate_device','remove_from_service','schedule_oem_service','none_required'
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

alter table public.suction_oxygen_qc_capa_actions_r3363 enable row level security;

create index if not exists idx_suction_oxygen_capa_r3363_log on public.suction_oxygen_qc_capa_actions_r3363(qc_log_id);
create index if not exists idx_suction_oxygen_capa_r3363_status on public.suction_oxygen_qc_capa_actions_r3363(capa_status);

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

  -- 14 per-device QC check rows
  insert into public.suction_oxygen_qc_r3363 (
    organization_id, hospital_name, device_code, device_type, ward, check_date,
    vacuum_pressure_accuracy_ok, flow_rate_accuracy_error_pct, oxygen_purity_pct,
    filter_condition, canister_seal_ok, alarm_test, tubing_hygiene_ok,
    noise_level_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.ward, q.cd::date,
    q.vac, q.ferr, q.opurity,
    q.filt, q.cseal, q.alarm, q.tub,
    q.noise, q.calib, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','SUC-APL-101','suction_machine','ICU 1','2026-07-10',
     'ok',2.10,null,'clean',true,'pass',true,true,true,'pass','Quarterly QC — vacuum and canister seal nominal'),
    ('Apollo Chennai Greams Road','THS-APL-102','thoracic_suction','OT 2','2026-07-10',
     'low',6.80,null,'due',true,'pass',true,true,false,'conditional_pass','Vacuum 15% low and calibration lapsed — recalibration booked'),
    ('Fortis Gurgaon','NEB-FRT-201','nebulizer','Paediatric Ward','2026-07-09',
     'not_applicable',3.40,null,'clean',true,'not_applicable',true,true,true,'pass','Nebulizer particle output within spec'),
    ('Fortis Gurgaon','OCW-FRT-202','oxygen_concentrator_ward','General Ward B','2026-07-09',
     'not_applicable',1.90,92.50,'clean',true,'pass',true,true,true,'pass','Ward concentrator purity 92.5% — good'),
    ('Manipal Bengaluru','OCW-MNP-301','oxygen_concentrator_ward','Respiratory HDU','2026-07-08',
     'not_applicable',2.20,85.40,'due',true,'fail',true,true,true,'fail','Purity 85.4% below 90% floor and O2 alarm failed — unit pulled'),
    ('Manipal Bengaluru','FLM-MNP-302','oxygen_flowmeter','ICU 2','2026-07-08',
     'not_applicable',9.60,null,'clean',true,'not_applicable',true,true,false,'conditional_pass','Flowmeter error 9.6% above 5% tolerance and calibration overdue'),
    ('AIIMS Delhi Ansari Nagar','SUC-AIM-401','suction_machine','Emergency','2026-07-07',
     'fail',4.10,null,'blocked',false,'fail',false,false,true,'removed_from_service','Vacuum fail, filter blocked, canister seal leak — removed from service'),
    ('AIIMS Delhi Ansari Nagar','NEB-AIM-402','nebulizer','Chest Ward','2026-07-07',
     'not_applicable',2.80,null,'due',true,'not_applicable',false,true,true,'conditional_pass','Tubing hygiene lapse — single-use tubing set replacement scheduled'),
    ('CMC Vellore','HUM-CMC-501','humidifier_bottle','ICU 3','2026-07-06',
     'not_applicable',null,null,'replace_due',false,'not_applicable',true,true,true,'conditional_pass','Humidifier bottle seal cracked and filter replace-due'),
    ('CMC Vellore','OCW-CMC-502','oxygen_concentrator_ward','General Ward A','2026-07-06',
     'not_applicable',1.50,94.10,'clean',true,'pass',true,true,true,'pass','Annual QC clean pass — purity 94.1%'),
    ('KIMS Hyderabad','SUC-KIM-601','suction_machine','OT 1','2026-07-05',
     'ok',3.20,null,'due',true,'pass',true,false,true,'conditional_pass','Noise level above limit — motor bearing check due'),
    ('KIMS Hyderabad','THS-KIM-602','thoracic_suction','CTVS ICU','2026-07-05',
     'ok',1.80,null,'clean',true,'pass',true,true,true,'pass','Chest-drain suction verified'),
    ('Yashoda Hyderabad','FLM-YSH-701','oxygen_flowmeter','NICU','2026-07-04',
     'not_applicable',12.40,null,'clean',true,'not_tested',true,true,false,'fail','Flowmeter 12.4% error, alarm not tested, calibration expired — fail'),
    ('Rainbow Hyderabad','NEB-RBW-702','nebulizer','Paediatric ICU','2026-07-04',
     'not_applicable',2.10,null,'clean',true,'not_applicable',true,true,true,'pass','Paediatric nebulizer output within spec')
  ) as q(hosp, dcode, dtype, ward, cd, vac, ferr, opurity, filt, cseal, alarm, tub, noise, calib, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.suction_oxygen_qc_capa_actions_r3363 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('THS-APL-102','calibration_overdue','calibration_lapsed','recalibrate_device','in_progress','nabh_finding','2026-07-16',null,8500.00,'Recalibration scheduled with biomed team'),
    ('OCW-MNP-301','oxygen_purity_low','sieve_bed_saturated','replace_sieve_bed','escalated','cdsco_notifiable','2026-07-14',null,45000.00,'Purity 85.4% — sieve bed replacement escalated to OEM'),
    ('FLM-MNP-302','flow_rate_deviation','calibration_lapsed','recalibrate_device','open','internal_only','2026-07-18',null,6000.00,'Flowmeter recalibration pending biomed slot'),
    ('SUC-AIM-401','canister_seal_leak','canister_gasket_cracked','replace_canister_gasket','closed','iso_13485_deviation','2026-07-11','2026-07-08',3200.00,'Gasket and filter replaced, vacuum restored, unit returned'),
    ('NEB-AIM-402','tubing_contamination','tubing_reuse_breach','replace_tubing_set','verification_pending','patient_safety_alert','2026-07-13',null,1500.00,'Single-use tubing policy reinforced — verify next round'),
    ('HUM-CMC-501','canister_seal_leak','canister_gasket_cracked','replace_canister_gasket','open','internal_only','2026-07-15',null,900.00,'Humidifier bottle replacement on order'),
    ('FLM-YSH-701','alarm_test_failure','alarm_module_fault','repair_alarm_module','overdue','patient_safety_alert','2026-07-09',null,15500.00,'NICU flowmeter alarm past target date — vendor delayed')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.suction_oxygen_qc_r3363 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3363_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.suction_oxygen_qc_r3363)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.suction_oxygen_qc_r3363 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3363_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3363_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3363_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  vacuum_fail bigint,
  alarm_fail bigint,
  filter_issue bigint,
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
    count(*) filter (where l.vacuum_pressure_accuracy_ok in ('low','fail'))::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint,
    count(*) filter (where l.filter_condition in ('blocked','replace_due'))::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.suction_oxygen_qc_r3363 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3363_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3363_hospital_scorecard() to authenticated;

-- 3) Device-type × ward matrix
create or replace function public.founder_r3363_device_type_ward_matrix()
returns table(device_type text, ward text, checks bigint, passed bigint, avg_flow_error_pct numeric, avg_oxygen_purity_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.ward, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.flow_rate_accuracy_error_pct), 2),
    round(avg(l.oxygen_purity_pct), 1)
  from public.suction_oxygen_qc_r3363 l
  group by l.device_type, l.ward
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3363_device_type_ward_matrix() from public, anon;
grant execute on function public.founder_r3363_device_type_ward_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3363_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, vacuum_fail bigint, alarm_fail bigint)
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
    count(*) filter (where l.vacuum_pressure_accuracy_ok in ('low','fail'))::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint
  from public.suction_oxygen_qc_r3363 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3363_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3363_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3363_capa_status_board()
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
  from public.suction_oxygen_qc_capa_actions_r3363 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3363_capa_status_board() from public, anon;
grant execute on function public.founder_r3363_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3363_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.suction_oxygen_qc_capa_actions_r3363)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.suction_oxygen_qc_capa_actions_r3363 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3363_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3363_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3363_regulatory_impact_digest()
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
  from public.suction_oxygen_qc_capa_actions_r3363 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3363_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3363_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3363_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  ward text,
  check_date date,
  qc_verdict text,
  vacuum_pressure_accuracy_ok text,
  filter_condition text,
  alarm_test text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.ward, l.check_date,
    l.qc_verdict, l.vacuum_pressure_accuracy_ok, l.filter_condition, l.alarm_test, l.notes
  from public.suction_oxygen_qc_r3363 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.vacuum_pressure_accuracy_ok in ('low','fail')
     or l.filter_condition in ('blocked','replace_due')
     or l.alarm_test in ('fail','not_tested')
     or l.canister_seal_ok = false
     or l.tubing_hygiene_ok = false
     or l.noise_level_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3363_high_risk_queue() from public, anon;
grant execute on function public.founder_r3363_high_risk_queue() to authenticated;
