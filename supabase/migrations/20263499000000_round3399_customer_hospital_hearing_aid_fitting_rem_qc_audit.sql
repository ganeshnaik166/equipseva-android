-- Round 3399: Customer Hospital Hearing-Aid Fitting / Real-Ear-Measurement (REM) & Analyzer QC Audit
-- Audiology fitting QA — device type × department × calibration signal × reference mic × probe tube × coupler seal × frequency response × THD × sound level × background noise × CAPA

-- =============================================================================
-- TABLE 1: hearing_aid_fitting_qc_r3399 — per-device QC checks
-- =============================================================================
create table if not exists public.hearing_aid_fitting_qc_r3399 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'real_ear_measurement','hearing_aid_analyzer','audiometer_fitting',
    'probe_mic_system','test_box_coupler','verification_unit'
  )),
  department text not null,
  check_date date not null,
  calibration_signal_ok boolean not null,
  reference_mic_calibration_ok boolean not null,
  probe_tube_condition text not null check (probe_tube_condition in (
    'good','worn','blocked','replace_due','not_applicable'
  )),
  coupler_seal_ok boolean not null,
  frequency_response_error_db numeric(5,2),
  thd_within_limit boolean not null,
  sound_level_accuracy_ok text not null check (sound_level_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  background_noise_ok boolean not null,
  software_targets_current boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hearing_aid_fitting_qc_r3399 enable row level security;

create index if not exists idx_hearing_aid_fitting_qc_r3399_org on public.hearing_aid_fitting_qc_r3399(organization_id);
create index if not exists idx_hearing_aid_fitting_qc_r3399_date on public.hearing_aid_fitting_qc_r3399(check_date);
create index if not exists idx_hearing_aid_fitting_qc_r3399_verdict on public.hearing_aid_fitting_qc_r3399(qc_verdict);

-- =============================================================================
-- TABLE 2: hearing_aid_fitting_qc_capa_actions_r3399 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.hearing_aid_fitting_qc_capa_actions_r3399 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.hearing_aid_fitting_qc_r3399(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'calibration_signal_failure','reference_mic_drift','probe_tube_fault','coupler_seal_failure',
    'frequency_response_error','thd_exceeded','sound_level_error',
    'background_noise_high','software_targets_outdated','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'mic_drift','probe_tube_worn','coupler_wear','transducer_aging',
    'consumable_quality_issue','environment_noise','software_update_pending','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_reference_mic','replace_probe_tube','replace_coupler','recalibrate_transducer',
    'soundproof_environment','apply_software_update','recalibrate','retrain_audiology_staff',
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

alter table public.hearing_aid_fitting_qc_capa_actions_r3399 enable row level security;

create index if not exists idx_hearing_aid_fitting_capa_r3399_log on public.hearing_aid_fitting_qc_capa_actions_r3399(qc_log_id);
create index if not exists idx_hearing_aid_fitting_capa_r3399_status on public.hearing_aid_fitting_qc_capa_actions_r3399(capa_status);

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

  insert into public.hearing_aid_fitting_qc_r3399 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    calibration_signal_ok, reference_mic_calibration_ok, probe_tube_condition, coupler_seal_ok,
    frequency_response_error_db, thd_within_limit, sound_level_accuracy_ok, background_noise_ok,
    software_targets_current, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.calsig, q.refmic, q.probe, q.coupler,
    q.freqerr, q.thd, q.sla, q.bgnoise,
    q.sw, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','HA-APL-01','real_ear_measurement','audiology','2026-07-03',
     true,true,'good',true,1.2,true,'ok',true,true,true,'pass','Quarterly QC — REM probe-mic system within spec'),
    ('Apollo Chennai','HA-APL-02','hearing_aid_analyzer','audiology','2026-07-03',
     true,true,'not_applicable',true,0.8,true,'ok',true,true,true,'pass','Hearing-aid analyzer test box QC nominal'),
    ('Fortis Gurgaon','HA-FRT-11','real_ear_measurement','audiology','2026-07-02',
     true,true,'worn',true,2.6,true,'ok',true,true,true,'conditional_pass','REM probe tube worn and frequency response 2.6 dB off — recheck'),
    ('Fortis Gurgaon','HA-FRT-12','hearing_aid_analyzer','audiology','2026-07-02',
     false,false,'not_applicable',false,4.5,false,'fail','no',true,true,'fail','Cal-signal, ref-mic, coupler and THD all failed — pulled'),
    ('Manipal Bengaluru','HA-MNP-21','probe_mic_system','audiology','2026-07-01',
     true,true,'blocked',true,1.4,true,'ok',true,false,false,'conditional_pass','Probe tube blocked, software targets and calibration overdue'),
    ('Manipal Bengaluru','HA-MNP-22','verification_unit','audiology','2026-07-01',
     true,true,'good',true,0.9,true,'ok',true,true,true,'pass','Fitting verification unit QC nominal'),
    ('AIIMS Delhi','HA-AIM-31','test_box_coupler','audiology','2026-06-30',
     true,true,'not_applicable',true,1.1,true,'drift',true,true,true,'conditional_pass','Test box sound level drift — recalibrate transducer'),
    ('AIIMS Delhi','HA-AIM-32','real_ear_measurement','audiology','2026-06-30',
     true,true,'good',true,1.0,true,'ok',false,true,true,'fail','High background noise invalidates REM — soundproofing required'),
    ('CMC Vellore','HA-CMC-41','hearing_aid_analyzer','audiology','2026-06-29',
     true,true,'not_applicable',true,0.7,true,'ok',true,true,true,'pass','Hearing-aid analyzer QC pass'),
    ('CMC Vellore','HA-CMC-42','probe_mic_system','audiology','2026-06-29',
     true,true,'replace_due',true,1.3,true,'ok',true,true,false,'conditional_pass','Probe tube replace-due and calibration overdue — plan swap'),
    ('KIMS Hyderabad','HA-KIM-51','real_ear_measurement','audiology','2026-06-28',
     true,true,'good',true,0.9,true,'ok',true,true,true,'pass','REM QC pass post-AMC'),
    ('KIMS Hyderabad','HA-KIM-52','audiometer_fitting','audiology','2026-06-28',
     true,true,'not_applicable',true,1.6,true,'drift',true,true,true,'conditional_pass','Fitting audiometer level drift within limit — monitor'),
    ('Yashoda Hyderabad','HA-YSH-61','verification_unit','audiology','2026-06-27',
     true,true,'good',true,0.8,true,'ok',true,true,true,'pass','Verification unit QC nominal'),
    ('Kokilaben Mumbai','HA-KKB-71','real_ear_measurement','audiology','2026-06-27',
     false,false,'blocked',false,5.8,false,'fail','no',false,false,'removed_from_service','Multiple failures across cal, mic, probe, coupler, noise — removed')
  ) as q(hosp, dcode, dtype, dept, cdate, calsig, refmic, probe, coupler, freqerr, thd, sla, bgnoise, sw, calcur, qv, nt);

  insert into public.hearing_aid_fitting_qc_capa_actions_r3399 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('HA-FRT-12','reference_mic_drift','mic_drift','recalibrate_reference_mic','in_progress','iso_15189_deviation','2026-07-06',null,9000.00,'Reference mic recalibration; coupler and THD checks after'),
    ('HA-MNP-21','probe_tube_fault','probe_tube_worn','replace_probe_tube','open','internal_only','2026-07-05',null,1500.00,'Blocked probe tube replacement and software target update'),
    ('HA-AIM-32','background_noise_high','environment_noise','soundproof_environment','escalated','patient_safety_alert','2026-07-04',null,40000.00,'Audiology room soundproofing to validate REM'),
    ('HA-KKB-71','calibration_signal_failure','transducer_aging','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-28',28000.00,'REM unit removed; transducer replaced and revalidated'),
    ('HA-AIM-31','sound_level_error','transducer_aging','recalibrate_transducer','verification_pending','internal_only','2026-07-05',null,6000.00,'Test box transducer recalibrated — verify level'),
    ('HA-CMC-42','calibration_overdue','preventive_service_backlog','recalibrate','overdue','internal_only','2026-06-30',null,4000.00,'Probe-mic calibration past target — vendor delay'),
    ('HA-FRT-11','frequency_response_error','probe_tube_worn','replace_probe_tube','open','none','2026-07-07',null,1500.00,'REM probe tube replacement scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.hearing_aid_fitting_qc_r3399 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3399_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hearing_aid_fitting_qc_r3399)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hearing_aid_fitting_qc_r3399 l group by l.qc_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3399_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3399_qc_verdict_rollup() to authenticated;

create or replace function public.founder_r3399_hospital_scorecard()
returns table(
  hospital_name text, total_checks bigint, passed bigint, conditional bigint, failed bigint,
  freq_issue bigint, noise_issue bigint, calibration_overdue bigint, pass_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.frequency_response_error_db > 2.0)::bigint,
    count(*) filter (where l.background_noise_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.hearing_aid_fitting_qc_r3399 l group by l.hospital_name order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3399_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3399_hospital_scorecard() to authenticated;

create or replace function public.founder_r3399_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint, avg_freq_error_db numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.frequency_response_error_db), 2)
  from public.hearing_aid_fitting_qc_r3399 l group by l.device_type, l.department order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3399_device_department_matrix() from public, anon;
grant execute on function public.founder_r3399_device_department_matrix() to authenticated;

create or replace function public.founder_r3399_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, freq_issue bigint, noise_issue bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.frequency_response_error_db > 2.0)::bigint,
    count(*) filter (where l.background_noise_ok = false)::bigint
  from public.hearing_aid_fitting_qc_r3399 l group by l.check_date order by l.check_date desc;
end;
$$;
revoke execute on function public.founder_r3399_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3399_daily_qc_trend() to authenticated;

create or replace function public.founder_r3399_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.hearing_aid_fitting_qc_capa_actions_r3399 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3399_capa_status_board() from public, anon;
grant execute on function public.founder_r3399_capa_status_board() to authenticated;

create or replace function public.founder_r3399_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hearing_aid_fitting_qc_capa_actions_r3399)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hearing_aid_fitting_qc_capa_actions_r3399 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3399_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3399_root_cause_pareto() to authenticated;

create or replace function public.founder_r3399_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.hearing_aid_fitting_qc_capa_actions_r3399 c group by c.regulatory_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3399_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3399_regulatory_impact_digest() to authenticated;

create or replace function public.founder_r3399_high_risk_queue()
returns table(
  hospital_name text, device_code text, device_type text, department text, check_date date,
  qc_verdict text, probe_tube_condition text, frequency_response_error_db numeric, sound_level_accuracy_ok text, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.probe_tube_condition, l.frequency_response_error_db, l.sound_level_accuracy_ok, l.notes
  from public.hearing_aid_fitting_qc_r3399 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.calibration_signal_ok = false
     or l.reference_mic_calibration_ok = false
     or l.probe_tube_condition in ('worn','blocked','replace_due')
     or l.coupler_seal_ok = false
     or l.frequency_response_error_db > 2.0
     or l.thd_within_limit = false
     or l.sound_level_accuracy_ok in ('drift','fail')
     or l.background_noise_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;
revoke execute on function public.founder_r3399_high_risk_queue() from public, anon;
grant execute on function public.founder_r3399_high_risk_queue() to authenticated;
