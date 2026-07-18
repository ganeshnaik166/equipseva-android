-- Round 3275: Customer Hospital Molecular / RT-PCR Lab Equipment QC Audit
-- Molecular-diagnostics QA — device type × lab zone × thermal uniformity × optical channels × extraction yield × amplicon contamination × freezer cold-chain × controls × calibration × CAPA

-- =============================================================================
-- TABLE 1: molecular_rtpcr_qc_r3275 — per-device molecular-lab QC checks
-- =============================================================================
create table if not exists public.molecular_rtpcr_qc_r3275 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'realtime_thermocycler','extraction_system','pcr_biosafety_cabinet',
    'minus80_freezer','cold_chain_fridge','centrifuge_refrigerated'
  )),
  lab_zone text not null check (lab_zone in (
    'pre_pcr','amplification','post_pcr'
  )),
  check_date date not null,
  thermal_uniformity_error_c numeric(4,1),
  optical_channel_check text not null check (optical_channel_check in (
    'pass','drift','fail','not_applicable'
  )),
  extraction_yield_ok boolean,
  contamination_swab_result text check (contamination_swab_result in (
    'clean','low_positive','fail'
  )),
  freezer_temp_error_c numeric(4,1),
  temp_logger_ok boolean,
  positive_negative_controls_ok boolean,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.molecular_rtpcr_qc_r3275 enable row level security;

create index if not exists idx_molecular_rtpcr_qc_r3275_org on public.molecular_rtpcr_qc_r3275(organization_id);
create index if not exists idx_molecular_rtpcr_qc_r3275_date on public.molecular_rtpcr_qc_r3275(check_date);
create index if not exists idx_molecular_rtpcr_qc_r3275_verdict on public.molecular_rtpcr_qc_r3275(qc_verdict);

-- =============================================================================
-- TABLE 2: molecular_rtpcr_qc_capa_actions_r3275 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.molecular_rtpcr_qc_capa_actions_r3275 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.molecular_rtpcr_qc_r3275(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'thermal_uniformity_deviation','optical_channel_drift','extraction_yield_low','amplicon_contamination',
    'freezer_temp_excursion','temp_logger_failure','control_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'peltier_block_aging','optical_filter_degradation','extraction_reagent_lot_issue','workflow_zone_breach',
    'freezer_compressor_fault','door_seal_failure','logger_battery_dead','control_reagent_degraded',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_peltier_block','recalibrate_optics','switch_reagent_lot','deep_clean_decontaminate',
    'repair_compressor','replace_door_seal','replace_logger_battery','replace_control_reagents',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','biosafety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.molecular_rtpcr_qc_capa_actions_r3275 enable row level security;

create index if not exists idx_molecular_rtpcr_capa_r3275_log on public.molecular_rtpcr_qc_capa_actions_r3275(qc_log_id);
create index if not exists idx_molecular_rtpcr_capa_r3275_status on public.molecular_rtpcr_qc_capa_actions_r3275(capa_status);

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
  insert into public.molecular_rtpcr_qc_r3275 (
    organization_id, hospital_name, device_code, device_type, lab_zone,
    check_date, thermal_uniformity_error_c, optical_channel_check, extraction_yield_ok,
    contamination_swab_result, freezer_temp_error_c, temp_logger_ok,
    positive_negative_controls_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.zone,
    q.cdate::date, q.tue, q.occ, q.eyo,
    q.csr, q.fte, q.tlo,
    q.pnc, q.cc, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','MOL-APL-TC01','realtime_thermocycler','amplification','2026-07-02',
     0.3,'pass',null,'clean',null,null,true,true,'pass','Quarterly QC — thermal uniformity within +/-0.5C, all optical channels nominal'),
    ('Apollo Chennai Greams Road','MOL-APL-EX02','extraction_system','pre_pcr','2026-07-02',
     null,'not_applicable',true,'clean',null,null,true,true,'pass','Automated extraction yield within spec on QC panel'),
    ('Fortis Gurgaon','MOL-FRT-TC01','realtime_thermocycler','amplification','2026-07-01',
     1.4,'drift',null,'low_positive',null,null,true,true,'conditional_pass','Optical channel drift on FAM and low-positive swab — decontamination booked'),
    ('Fortis Gurgaon','MOL-FRT-F80','minus80_freezer','pre_pcr','2026-07-01',
     null,'not_applicable',null,null,3.5,true,null,true,'conditional_pass','-80C freezer holding -76.5C, 3.5C warm — compressor watch'),
    ('Manipal Bengaluru Old Airport Road','MOL-MNP-BSC1','pcr_biosafety_cabinet','pre_pcr','2026-06-30',
     null,'not_applicable',null,'fail',null,null,null,false,'fail','Amplicon contamination on cabinet swab and HEPA cert lapsed — removed pending decon'),
    ('Manipal Bengaluru Old Airport Road','MOL-MNP-TC02','realtime_thermocycler','amplification','2026-06-30',
     0.6,'pass',null,'clean',null,null,false,true,'fail','Positive/negative control failure — no-template control amplified, run invalidated'),
    ('AIIMS Delhi Ansari Nagar','MOL-AIM-EX01','extraction_system','pre_pcr','2026-06-29',
     null,'not_applicable',false,'clean',null,null,true,true,'conditional_pass','Extraction yield below threshold on 2 of 8 wells — reagent lot suspect'),
    ('AIIMS Delhi Ansari Nagar','MOL-AIM-F80','minus80_freezer','post_pcr','2026-06-29',
     null,'not_applicable',null,null,8.2,false,null,true,'removed_from_service','-80C excursion to -71.8C and logger battery dead — samples relocated, unit pulled'),
    ('CMC Vellore','MOL-CMC-TC01','realtime_thermocycler','amplification','2026-06-28',
     0.4,'pass',null,'clean',null,null,true,true,'pass','Annual QC clean pass across all six optical channels'),
    ('CMC Vellore','MOL-CMC-CF01','cold_chain_fridge','pre_pcr','2026-06-28',
     null,'not_applicable',null,null,1.2,true,null,true,'pass','2-8C reagent fridge within range, data logger verified'),
    ('KIMS Hyderabad','MOL-KIM-CEN1','centrifuge_refrigerated','pre_pcr','2026-06-27',
     null,'not_applicable',null,'clean',2.1,true,null,false,'conditional_pass','Refrigerated centrifuge 2.1C warm and calibration overdue — service scheduled'),
    ('KIMS Hyderabad','MOL-KIM-TC01','realtime_thermocycler','amplification','2026-06-27',
     2.3,'fail',null,'clean',null,null,false,true,'fail','Thermal uniformity 2.3C out of spec and optical channel fail on VIC — block service required'),
    ('Narayana Health Bengaluru','MOL-NAR-BSC1','pcr_biosafety_cabinet','amplification','2026-06-26',
     null,'not_applicable',null,'low_positive',null,null,null,true,'conditional_pass','Master-mix cabinet swab low-positive — reclean and re-swab scheduled'),
    ('Kokilaben Mumbai','MOL-KOK-F80','minus80_freezer','pre_pcr','2026-06-26',
     null,'not_applicable',null,null,0.8,true,null,true,'pass','-80C freezer within 1C of setpoint, backup CO2 system verified')
  ) as q(hosp, dcode, dtype, zone, cdate, tue, occ, eyo, csr, fte, tlo, pnc, cc, qv, nt);

  -- CAPA seed — attach to specific checks via device code
  insert into public.molecular_rtpcr_qc_capa_actions_r3275 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MOL-FRT-TC01','optical_channel_drift','optical_filter_degradation','recalibrate_optics','in_progress','iso_15189_deviation','2026-07-06',null,22000.00,'FAM channel drift — OEM optics recalibration in progress'),
    ('MOL-FRT-F80','freezer_temp_excursion','freezer_compressor_fault','repair_compressor','open','internal_only','2026-07-05',null,48000.00,'-80C compressor labouring — service call raised, samples on backup unit'),
    ('MOL-MNP-BSC1','amplicon_contamination','workflow_zone_breach','deep_clean_decontaminate','escalated','biosafety_alert','2026-07-04',null,15000.00,'Amplicon carryover — full decon plus workflow audit, cabinet quarantined'),
    ('MOL-MNP-TC02','control_failure','control_reagent_degraded','replace_control_reagents','closed','nabl_finding','2026-07-02','2026-06-30',8000.00,'NTC contamination traced to degraded control lot — replaced, re-run clean'),
    ('MOL-AIM-EX01','extraction_yield_low','extraction_reagent_lot_issue','switch_reagent_lot','verification_pending','iso_15189_deviation','2026-07-03',null,12000.00,'Low yield on reagent lot — switched to new lot, verify on next batch'),
    ('MOL-AIM-F80','temp_logger_failure','logger_battery_dead','replace_logger_battery','overdue','cdsco_notifiable','2026-06-30',null,3500.00,'Logger battery dead during excursion — replaced, closure past target date'),
    ('MOL-KIM-TC01','thermal_uniformity_deviation','peltier_block_aging','replace_peltier_block','open','nabl_finding','2026-07-08',null,95000.00,'Peltier block failing thermal-uniformity map — replacement quoted by OEM')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.molecular_rtpcr_qc_r3275 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3275_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.molecular_rtpcr_qc_r3275)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.molecular_rtpcr_qc_r3275 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3275_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3275_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3275_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  contamination_fail bigint,
  optical_fail bigint,
  control_fail bigint,
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
    count(*) filter (where l.contamination_swab_result in ('low_positive','fail'))::bigint,
    count(*) filter (where l.optical_channel_check in ('drift','fail'))::bigint,
    count(*) filter (where l.positive_negative_controls_ok is false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.molecular_rtpcr_qc_r3275 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3275_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3275_hospital_scorecard() to authenticated;

-- 3) Device type × lab zone matrix
create or replace function public.founder_r3275_device_zone_matrix()
returns table(device_type text, lab_zone text, checks bigint, passed bigint, avg_thermal_error_c numeric, avg_freezer_error_c numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.lab_zone, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.thermal_uniformity_error_c), 2),
    round(avg(l.freezer_temp_error_c), 2)
  from public.molecular_rtpcr_qc_r3275 l
  group by l.device_type, l.lab_zone
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3275_device_zone_matrix() from public, anon;
grant execute on function public.founder_r3275_device_zone_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3275_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, contamination_fail bigint, control_fail bigint)
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
    count(*) filter (where l.contamination_swab_result in ('low_positive','fail'))::bigint,
    count(*) filter (where l.positive_negative_controls_ok is false)::bigint
  from public.molecular_rtpcr_qc_r3275 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3275_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3275_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3275_capa_status_board()
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
  from public.molecular_rtpcr_qc_capa_actions_r3275 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3275_capa_status_board() from public, anon;
grant execute on function public.founder_r3275_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3275_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.molecular_rtpcr_qc_capa_actions_r3275)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.molecular_rtpcr_qc_capa_actions_r3275 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3275_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3275_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3275_regulatory_impact_digest()
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
  from public.molecular_rtpcr_qc_capa_actions_r3275 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3275_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3275_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3275_high_risk_queue()
returns table(
  hospital_name text,
  lab_zone text,
  device_code text,
  check_date date,
  qc_verdict text,
  optical_channel_check text,
  contamination_swab_result text,
  controls_status text,
  logger_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.lab_zone, l.device_code, l.check_date,
    l.qc_verdict, l.optical_channel_check,
    coalesce(l.contamination_swab_result, 'not_swabbed'),
    case when l.positive_negative_controls_ok is true then 'controls_ok'
         when l.positive_negative_controls_ok is false then 'controls_fail'
         else 'not_applicable' end,
    case when l.temp_logger_ok is true then 'logger_ok'
         when l.temp_logger_ok is false then 'logger_fail'
         else 'not_applicable' end,
    l.notes
  from public.molecular_rtpcr_qc_r3275 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.optical_channel_check in ('drift','fail')
     or l.contamination_swab_result in ('low_positive','fail')
     or l.positive_negative_controls_ok is false
     or l.temp_logger_ok is false
     or l.extraction_yield_ok is false
     or l.calibration_current is false
     or l.freezer_temp_error_c >= 3.0
     or l.thermal_uniformity_error_c >= 1.0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3275_high_risk_queue() from public, anon;
grant execute on function public.founder_r3275_high_risk_queue() to authenticated;
