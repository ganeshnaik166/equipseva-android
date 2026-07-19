-- Round 3335: Customer Hospital CT Dose-Management & Radiation-Tracking QC Audit
-- CT dose QA — scanner type × protocol × CTDIvol/DLP × DRL compliance × AEC verification × dose-software logging × phantom CTDI error × image quality × CAPA

-- =============================================================================
-- TABLE 1: ct_dose_qc_r3335 — per-scanner/protocol CT dose QC checks
-- =============================================================================
create table if not exists public.ct_dose_qc_r3335 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  scanner_code text not null,
  scanner_type text not null check (scanner_type in (
    'ct_64_slice','ct_128_slice','ct_dual_energy','pet_ct','cone_beam_ct'
  )),
  protocol text not null check (protocol in (
    'head','chest','abdomen_pelvis','cardiac','pediatric'
  )),
  check_date date not null,
  ctdivol_mgy numeric(6,2),
  dlp_mgycm numeric(8,2),
  within_drl boolean,
  aec_function_ok boolean,
  dose_software_logging_ok boolean,
  pediatric_protocol_optimized boolean,
  dose_alert_configured boolean,
  phantom_ctdi_error_pct numeric(5,2),
  image_quality_adequate boolean,
  calibration_current boolean,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','dose_optimization_needed'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ct_dose_qc_r3335 enable row level security;

create index if not exists idx_ct_dose_qc_r3335_org on public.ct_dose_qc_r3335(organization_id);
create index if not exists idx_ct_dose_qc_r3335_date on public.ct_dose_qc_r3335(check_date);
create index if not exists idx_ct_dose_qc_r3335_verdict on public.ct_dose_qc_r3335(qc_verdict);

-- =============================================================================
-- TABLE 2: ct_dose_qc_capa_actions_r3335 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ct_dose_qc_capa_actions_r3335 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ct_dose_qc_r3335(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'dose_overrun','drl_exceedance','aec_malfunction','dose_logging_gap',
    'pediatric_protocol_not_optimized','dose_alert_not_configured','phantom_ctdi_error',
    'image_quality_inadequate','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'aec_sensor_drift','protocol_misconfiguration','software_logging_disabled','pediatric_protocol_missing',
    'tube_output_drift','detector_calibration_drift','operator_setup_error','dose_alert_threshold_unset',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_aec','reconfigure_protocol','enable_dose_logging','build_pediatric_protocol',
    'recalibrate_tube_output','recalibrate_detector','retrain_ct_staff','configure_dose_alert',
    'schedule_oem_service','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_notifiable','nabh_finding','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ct_dose_qc_capa_actions_r3335 enable row level security;

create index if not exists idx_ct_dose_capa_r3335_log on public.ct_dose_qc_capa_actions_r3335(qc_log_id);
create index if not exists idx_ct_dose_capa_r3335_status on public.ct_dose_qc_capa_actions_r3335(capa_status);

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

  -- 14 CT dose QC rows
  insert into public.ct_dose_qc_r3335 (
    organization_id, hospital_name, scanner_code, scanner_type, protocol, check_date,
    ctdivol_mgy, dlp_mgycm, within_drl, aec_function_ok, dose_software_logging_ok,
    pediatric_protocol_optimized, dose_alert_configured, phantom_ctdi_error_pct,
    image_quality_adequate, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.scode, q.stype, q.proto, q.cdate::date,
    q.ctdi, q.dlp, q.drl, q.aec, q.logok,
    q.pedopt, q.alert, q.pherr,
    q.iq, q.calib, q.qv, q.nt
  from (values
    ('Apollo Chennai','APL-CT-01','ct_128_slice','head','2026-07-03',
     58.0,980.0,true,true,true,true,true,2.1,true,true,'pass','Quarterly dose QC — head CTDIvol/DLP within DRL'),
    ('Apollo Chennai','APL-CT-02','ct_64_slice','chest','2026-07-03',
     16.5,520.0,false,true,true,true,true,3.4,true,true,'dose_optimization_needed','Chest DLP 520 above 400 DRL — protocol tuning advised'),
    ('Fortis Gurgaon','FRT-CT-01','ct_dual_energy','abdomen_pelvis','2026-07-02',
     18.2,760.0,true,true,true,true,true,1.8,true,true,'pass','Dual-energy abdomen-pelvis — dose nominal'),
    ('Fortis Gurgaon','FRT-CT-02','ct_64_slice','cardiac','2026-07-02',
     46.0,720.0,false,false,true,true,true,4.2,true,true,'fail','AEC not modulating on cardiac gating — DLP over DRL'),
    ('Manipal Bengaluru','MNP-CT-01','ct_128_slice','head','2026-07-01',
     61.0,1040.0,false,true,true,true,true,2.6,true,true,'dose_optimization_needed','Head DLP 1040 over 1000 DRL — kV/mA review scheduled'),
    ('Manipal Bengaluru','MNP-CT-02','pet_ct','chest','2026-07-01',
     12.0,410.0,true,true,false,true,true,2.0,true,true,'conditional_pass','Dose-logging to software intermittent — IT ticket raised'),
    ('AIIMS Delhi','AIM-CT-03','ct_128_slice','pediatric','2026-06-30',
     22.0,300.0,false,true,true,false,true,3.1,true,true,'fail','Pediatric run on adult protocol — not size-optimized'),
    ('AIIMS Delhi','AIM-CT-04','ct_dual_energy','abdomen_pelvis','2026-06-30',
     15.8,690.0,true,true,true,true,true,1.5,true,true,'pass','Annual dose QC clean pass'),
    ('CMC Vellore','CMC-CT-01','ct_64_slice','chest','2026-06-29',
     11.0,380.0,true,true,true,true,false,2.4,true,true,'conditional_pass','Dose-alert threshold not configured on console'),
    ('CMC Vellore','CMC-CT-02','cone_beam_ct','head','2026-06-29',
     8.0,210.0,true,true,true,true,true,5.6,false,false,'fail','Phantom CTDI error 5.6% and image noise high — calibration overdue'),
    ('KIMS Hyderabad','KIM-CT-01','ct_128_slice','cardiac','2026-06-28',
     33.0,560.0,true,true,true,true,true,2.2,true,true,'pass','Cardiac gating dose within DRL'),
    ('KIMS Hyderabad','KIM-CT-02','ct_64_slice','abdomen_pelvis','2026-06-28',
     21.5,890.0,false,false,true,true,true,3.8,true,true,'fail','Abdomen DLP 890 over 800 DRL, AEC drift suspected'),
    ('Narayana Health Bengaluru','NAR-CT-01','pet_ct','abdomen_pelvis','2026-06-27',
     14.0,640.0,true,true,true,true,true,1.9,true,true,'pass','PET-CT low-dose CT component dose nominal'),
    ('Rainbow Children''s Hyderabad','RBW-CT-01','ct_128_slice','pediatric','2026-06-27',
     6.5,140.0,true,true,true,true,true,1.6,true,true,'pass','Pediatric size-based protocol verified')
  ) as q(hosp, scode, stype, proto, cdate, ctdi, dlp, drl, aec, logok, pedopt, alert, pherr, iq, calib, qv, nt);

  -- CAPA seed — attach to specific checks via scanner_code
  insert into public.ct_dose_qc_capa_actions_r3335 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('APL-CT-02','dose_overrun','protocol_misconfiguration','reconfigure_protocol','in_progress','aerb_notifiable','2026-07-10',null,15000.00,'Chest protocol mA too high — reference protocol being rebuilt'),
    ('FRT-CT-02','aec_malfunction','aec_sensor_drift','recalibrate_aec','escalated','patient_safety_alert','2026-07-08',null,55000.00,'AEC not modulating on cardiac gating — OEM service escalated'),
    ('MNP-CT-01','drl_exceedance','protocol_misconfiguration','reconfigure_protocol','open','nabh_finding','2026-07-12',null,12000.00,'Head DLP over DRL — kV/mA review scheduled'),
    ('AIM-CT-03','pediatric_protocol_not_optimized','pediatric_protocol_missing','build_pediatric_protocol','in_progress','patient_safety_alert','2026-07-07',null,20000.00,'Building size-based pediatric CT protocol library'),
    ('CMC-CT-02','calibration_overdue','detector_calibration_drift','recalibrate_detector','open','aerb_notifiable','2026-07-09',null,48000.00,'Detector calibration overdue — phantom CTDI 5.6% error'),
    ('CMC-CT-01','dose_alert_not_configured','dose_alert_threshold_unset','configure_dose_alert','closed','internal_only','2026-07-02','2026-06-30',0.00,'Dose-alert thresholds configured per AERB DRL'),
    ('KIM-CT-02','drl_exceedance','aec_sensor_drift','recalibrate_aec','overdue','nabh_finding','2026-06-26',null,38000.00,'Abdomen DLP over DRL and AEC drift — past target date')
  ) as q(scode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ct_dose_qc_r3335 e
    on e.organization_id = v_org_id and e.scanner_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3335_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ct_dose_qc_r3335)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ct_dose_qc_r3335 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3335_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3335_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level dose QC scorecard
create or replace function public.founder_r3335_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  dose_opt_needed bigint,
  drl_exceedances bigint,
  aec_failures bigint,
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
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.qc_verdict = 'dose_optimization_needed')::bigint,
    count(*) filter (where l.within_drl is false)::bigint,
    count(*) filter (where l.aec_function_ok is false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ct_dose_qc_r3335 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3335_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3335_hospital_scorecard() to authenticated;

-- 3) Scanner type × protocol matrix
create or replace function public.founder_r3335_scanner_protocol_matrix()
returns table(scanner_type text, protocol text, checks bigint, passed bigint, avg_ctdivol_mgy numeric, avg_dlp_mgycm numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scanner_type, l.protocol, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.ctdivol_mgy), 2),
    round(avg(l.dlp_mgycm), 1)
  from public.ct_dose_qc_r3335 l
  group by l.scanner_type, l.protocol
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3335_scanner_protocol_matrix() from public, anon;
grant execute on function public.founder_r3335_scanner_protocol_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3335_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, drl_exceedances bigint, aec_failures bigint)
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
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_drl is false)::bigint,
    count(*) filter (where l.aec_function_ok is false)::bigint
  from public.ct_dose_qc_r3335 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3335_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3335_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3335_capa_status_board()
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
  from public.ct_dose_qc_capa_actions_r3335 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3335_capa_status_board() from public, anon;
grant execute on function public.founder_r3335_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3335_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ct_dose_qc_capa_actions_r3335)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ct_dose_qc_capa_actions_r3335 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3335_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3335_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3335_regulatory_impact_digest()
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
  from public.ct_dose_qc_capa_actions_r3335 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3335_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3335_regulatory_impact_digest() to authenticated;

-- 8) High-risk dose QC queue (top individual concerns)
create or replace function public.founder_r3335_high_risk_queue()
returns table(
  hospital_name text,
  scanner_code text,
  scanner_type text,
  protocol text,
  check_date date,
  qc_verdict text,
  ctdivol_mgy numeric,
  dlp_mgycm numeric,
  within_drl boolean,
  aec_function_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.scanner_code, l.scanner_type, l.protocol, l.check_date,
    l.qc_verdict, l.ctdivol_mgy, l.dlp_mgycm, l.within_drl, l.aec_function_ok, l.notes
  from public.ct_dose_qc_r3335 l
  where l.qc_verdict in ('conditional_pass','fail','dose_optimization_needed')
     or l.within_drl is false
     or l.aec_function_ok is false
     or l.dose_software_logging_ok is false
     or l.pediatric_protocol_optimized is false
     or l.dose_alert_configured is false
     or l.image_quality_adequate is false
     or l.calibration_current is false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3335_high_risk_queue() from public, anon;
grant execute on function public.founder_r3335_high_risk_queue() to authenticated;
