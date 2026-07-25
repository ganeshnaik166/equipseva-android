-- Round 3419: Customer Hospital Sterilizer BI-Incubator Sterility-Assurance QC Audit
-- CSSD sterility assurance — device type × sterilizer × BI incubator temp × positive-control × BI result × rapid readout × load release × lot traceability × recall readiness × calibration × CAPA

-- =============================================================================
-- TABLE 1: sterility_assurance_qc_r3419 — per-device/cycle sterility-assurance QC checks
-- =============================================================================
create table if not exists public.sterility_assurance_qc_r3419 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'bi_incubator','rapid_readout_bi','auto_reader_incubator','spore_test_station','parametric_monitor'
  )),
  cssd_area text not null check (cssd_area in (
    'decontamination','prep_packaging','sterilization','sterile_storage','endoscopy_reprocessing'
  )),
  check_date date not null,
  incubator_temp_accuracy_error_c numeric(5,2),
  positive_control_growth_ok boolean not null,
  bi_result text not null check (bi_result in (
    'negative_pass','positive_fail','pending','not_run'
  )),
  rapid_readout_time_ok boolean not null,
  load_release_documented boolean not null,
  sterilizer_linked text not null check (sterilizer_linked in (
    'steam','eto','plasma','mixed'
  )),
  lot_traceability_ok boolean not null,
  recall_procedure_ready boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','quarantined'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.sterility_assurance_qc_r3419 enable row level security;

create index if not exists idx_sterility_assurance_qc_r3419_org on public.sterility_assurance_qc_r3419(organization_id);
create index if not exists idx_sterility_assurance_qc_r3419_date on public.sterility_assurance_qc_r3419(check_date);
create index if not exists idx_sterility_assurance_qc_r3419_verdict on public.sterility_assurance_qc_r3419(qc_verdict);

-- =============================================================================
-- TABLE 2: sterility_assurance_qc_capa_actions_r3419 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.sterility_assurance_qc_capa_actions_r3419 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.sterility_assurance_qc_r3419(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'incubator_temp_out_of_tolerance','positive_control_failure','bi_positive_growth','rapid_readout_timeout',
    'load_release_undocumented','lot_traceability_gap','recall_procedure_missing','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'incubator_thermostat_drift','bi_vial_defect','sterilizer_cycle_failure','operator_documentation_error',
    'reader_optics_degraded','software_config_error','media_expired','pending_investigation',
    'preventive_service_backlog','packaging_wet_pack'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_incubator','requarantine_and_reprocess_load','replace_bi_lot','retrain_cssd_staff',
    'service_sterilizer','update_software_config','replace_reader_unit','document_load_release',
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

alter table public.sterility_assurance_qc_capa_actions_r3419 enable row level security;

create index if not exists idx_sterility_assurance_capa_r3419_log on public.sterility_assurance_qc_capa_actions_r3419(qc_log_id);
create index if not exists idx_sterility_assurance_capa_r3419_status on public.sterility_assurance_qc_capa_actions_r3419(capa_status);

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

  -- 14 sterility-assurance QC check rows
  insert into public.sterility_assurance_qc_r3419 (
    organization_id, hospital_name, device_code, device_type, cssd_area, check_date,
    incubator_temp_accuracy_error_c, positive_control_growth_ok, bi_result,
    rapid_readout_time_ok, load_release_documented, sterilizer_linked,
    lot_traceability_ok, recall_procedure_ready, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.area, q.cdate::date,
    q.temperr, q.posctrl, q.biresult,
    q.rapidtime, q.loadrel, q.sterlink,
    q.lottrace, q.recall, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','BII-APL-01','bi_incubator','sterilization','2026-07-03',
     0.3,true,'negative_pass',true,true,'steam',true,true,true,'pass','Steam load BI incubator QC — negative growth at 24h, temp within tolerance'),
    ('Apollo Chennai','RRB-APL-02','rapid_readout_bi','sterilization','2026-07-03',
     0.2,true,'negative_pass',true,true,'steam',true,true,true,'pass','Rapid-readout BI fluorescence negative at 1h, load release documented'),
    ('Fortis Gurgaon','ARI-FRT-11','auto_reader_incubator','sterilization','2026-07-02',
     1.4,true,'negative_pass',false,true,'eto',true,true,true,'conditional_pass','ETO auto-reader — rapid readout exceeded target time, full incubation negative'),
    ('Fortis Gurgaon','BII-FRT-12','bi_incubator','sterilization','2026-07-02',
     2.8,false,'positive_fail',true,false,'steam',false,true,true,'fail','BI positive growth, positive control failed, temp error 2.8C and load release not documented'),
    ('Manipal Bengaluru','SPT-MNP-21','spore_test_station','sterilization','2026-07-01',
     null,true,'positive_fail',true,true,'plasma',true,false,true,'quarantined','Plasma spore test positive — load quarantined, recall procedure not ready'),
    ('Manipal Bengaluru','RRB-MNP-22','rapid_readout_bi','sterilization','2026-07-01',
     0.4,true,'negative_pass',true,true,'steam',true,true,true,'pass','Rapid-readout BI QC nominal, lot traceability intact'),
    ('AIIMS Delhi','PAR-AIM-31','parametric_monitor','sterilization','2026-06-30',
     0.9,true,'not_run',true,true,'steam',true,true,true,'conditional_pass','Parametric release — BI not run this cycle, parametric criteria met but drift trend flagged'),
    ('AIIMS Delhi','BII-AIM-32','bi_incubator','sterilization','2026-06-30',
     3.1,true,'pending',true,false,'eto',false,true,true,'fail','ETO BI still pending at readout, temp error 3.1C and lot traceability gap'),
    ('CMC Vellore','ARI-CMC-41','auto_reader_incubator','sterilization','2026-06-29',
     0.5,true,'negative_pass',true,true,'steam',true,true,true,'pass','Auto-reader incubator QC pass, all steam loads released'),
    ('CMC Vellore','SPT-CMC-42','spore_test_station','endoscopy_reprocessing','2026-06-29',
     null,true,'negative_pass',true,true,'plasma',true,true,false,'conditional_pass','Endoscope reprocessing spore test negative but incubator calibration overdue'),
    ('KIMS Hyderabad','BII-KIM-51','bi_incubator','sterilization','2026-06-28',
     0.6,true,'negative_pass',true,true,'steam',true,true,true,'pass','BI incubator QC pass post-AMC service'),
    ('KIMS Hyderabad','RRB-KIM-52','rapid_readout_bi','sterilization','2026-06-28',
     1.2,true,'pending',false,true,'mixed',true,true,true,'conditional_pass','Rapid-readout timeout on mixed load, result pending full incubation — recheck due'),
    ('Yashoda Hyderabad','PAR-YSH-61','parametric_monitor','sterilization','2026-06-27',
     0.7,true,'negative_pass',true,true,'steam',true,true,true,'pass','Parametric monitor QC nominal, parametric release validated'),
    ('Kokilaben Mumbai','BII-KKB-71','bi_incubator','sterilization','2026-06-27',
     4.2,false,'positive_fail',true,false,'eto',false,false,false,'quarantined','ETO BI positive with positive-control failure, multiple gaps — all loads quarantined')
  ) as q(hosp, dcode, dtype, area, cdate, temperr, posctrl, biresult, rapidtime, loadrel, sterlink, lottrace, recall, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.sterility_assurance_qc_capa_actions_r3419 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BII-FRT-12','bi_positive_growth','sterilizer_cycle_failure','service_sterilizer','in_progress','patient_safety_alert','2026-07-06',null,55000.00,'Steam sterilizer serviced after BI positive — load reprocessing, verification pending'),
    ('SPT-MNP-21','bi_positive_growth','sterilizer_cycle_failure','requarantine_and_reprocess_load','escalated','cdsco_notifiable','2026-07-05',null,72000.00,'Plasma spore positive — load quarantined and reprocessed, recall SOP being finalised'),
    ('BII-AIM-32','lot_traceability_gap','operator_documentation_error','retrain_cssd_staff','open','nabh_finding','2026-07-04',null,6000.00,'ETO lot traceability gap — staff retraining on load documentation'),
    ('BII-KKB-71','positive_control_failure','bi_vial_defect','replace_bi_lot','closed','cdsco_notifiable','2026-07-02','2026-06-29',18000.00,'Defective BI lot replaced and validated; positive control now growing correctly'),
    ('SPT-CMC-42','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-30',null,24000.00,'Incubator calibration past due — OEM service delayed by vendor'),
    ('RRB-KIM-52','rapid_readout_timeout','reader_optics_degraded','replace_reader_unit','verification_pending','iso_13485_deviation','2026-07-04',null,38000.00,'Rapid-reader optics degraded — replacement reader installed, verify next cycle'),
    ('ARI-FRT-11','rapid_readout_timeout','software_config_error','update_software_config','open','internal_only','2026-07-06',null,0.00,'Auto-reader firmware reconfigured for ETO cycle timing — recheck scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.sterility_assurance_qc_r3419 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3419_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sterility_assurance_qc_r3419)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.sterility_assurance_qc_r3419 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3419_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3419_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3419_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  bi_positive bigint,
  traceability_gap bigint,
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
    count(*) filter (where l.qc_verdict in ('fail','quarantined'))::bigint,
    count(*) filter (where l.bi_result = 'positive_fail')::bigint,
    count(*) filter (where l.lot_traceability_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.sterility_assurance_qc_r3419 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3419_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3419_hospital_scorecard() to authenticated;

-- 3) Device-type × sterilizer matrix
create or replace function public.founder_r3419_device_type_sterilizer_matrix()
returns table(device_type text, sterilizer_linked text, checks bigint, passed bigint, failed bigint, avg_temp_error_c numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.sterilizer_linked, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','quarantined'))::bigint,
    round(avg(l.incubator_temp_accuracy_error_c), 2)
  from public.sterility_assurance_qc_r3419 l
  group by l.device_type, l.sterilizer_linked
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3419_device_type_sterilizer_matrix() from public, anon;
grant execute on function public.founder_r3419_device_type_sterilizer_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3419_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, bi_positive bigint, traceability_gap bigint)
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
    count(*) filter (where l.qc_verdict in ('fail','quarantined'))::bigint,
    count(*) filter (where l.bi_result = 'positive_fail')::bigint,
    count(*) filter (where l.lot_traceability_ok = false)::bigint
  from public.sterility_assurance_qc_r3419 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3419_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3419_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3419_capa_status_board()
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
  from public.sterility_assurance_qc_capa_actions_r3419 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3419_capa_status_board() from public, anon;
grant execute on function public.founder_r3419_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3419_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sterility_assurance_qc_capa_actions_r3419)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.sterility_assurance_qc_capa_actions_r3419 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3419_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3419_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3419_regulatory_impact_digest()
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
  from public.sterility_assurance_qc_capa_actions_r3419 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3419_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3419_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3419_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  sterilizer_linked text,
  cssd_area text,
  check_date date,
  qc_verdict text,
  bi_result text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.sterilizer_linked, l.cssd_area,
    l.check_date, l.qc_verdict, l.bi_result, l.notes
  from public.sterility_assurance_qc_r3419 l
  where l.qc_verdict in ('conditional_pass','fail','quarantined')
     or l.bi_result in ('positive_fail','pending','not_run')
     or l.positive_control_growth_ok = false
     or l.rapid_readout_time_ok = false
     or l.load_release_documented = false
     or l.lot_traceability_ok = false
     or l.recall_procedure_ready = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3419_high_risk_queue() from public, anon;
grant execute on function public.founder_r3419_high_risk_queue() to authenticated;
