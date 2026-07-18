-- Round 3250: Customer Hospital EEG/EMG Neurodiagnostic Equipment QC Audit
-- Neurodiagnostic QA — device type × calibration square-wave × electrode impedance × channel dropout × photic stimulator × amplifier noise uV × filter settings × electrical leakage uA × accessories × CAPA

-- =============================================================================
-- TABLE 1: neurodiag_qc_r3250 — per-device neurodiagnostic QC checks
-- =============================================================================
create table if not exists public.neurodiag_qc_r3250 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'eeg_32ch','eeg_64ch','emg_ncv','evoked_potential','polysomnography'
  )),
  department text not null,
  check_date date not null,
  calibration_signal_ok boolean not null,
  electrode_impedance_check text not null check (electrode_impedance_check in (
    'pass','high_impedance','fail'
  )),
  channel_dropout_count int not null default 0,
  photic_stimulator_ok text not null check (photic_stimulator_ok in (
    'ok','flicker_fault','not_applicable'
  )),
  amplifier_noise_uv numeric(6,2),
  filter_settings_verified boolean not null,
  electrical_safety_leakage_ua numeric(6,1),
  accessories_condition text not null check (accessories_condition in (
    'complete','worn','missing_items'
  )),
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.neurodiag_qc_r3250 enable row level security;

create index if not exists idx_neurodiag_qc_r3250_org on public.neurodiag_qc_r3250(organization_id);
create index if not exists idx_neurodiag_qc_r3250_date on public.neurodiag_qc_r3250(check_date);
create index if not exists idx_neurodiag_qc_r3250_verdict on public.neurodiag_qc_r3250(qc_verdict);

-- =============================================================================
-- TABLE 2: neurodiag_qc_capa_actions_r3250 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.neurodiag_qc_capa_actions_r3250 (
  id uuid primary key default gen_random_uuid(),
  qc_check_id uuid not null references public.neurodiag_qc_r3250(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'calibration_signal_failure','high_electrode_impedance','channel_dropout','photic_stimulator_fault',
    'amplifier_noise_excess','filter_config_error','electrical_leakage_excess','accessories_incomplete',
    'preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'electrode_lead_wear','headbox_connector_damage','amplifier_board_fault','photic_lamp_ageing',
    'earth_bonding_degraded','software_filter_misconfig','operator_setup_error','accessory_loss_in_ward',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_electrode_leads','replace_headbox_connector','repair_amplifier_board','replace_photic_lamp',
    'restore_earth_bonding','reconfigure_filter_settings','retrain_technologist','reissue_accessory_kit',
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

alter table public.neurodiag_qc_capa_actions_r3250 enable row level security;

create index if not exists idx_neurodiag_capa_r3250_check on public.neurodiag_qc_capa_actions_r3250(qc_check_id);
create index if not exists idx_neurodiag_capa_r3250_status on public.neurodiag_qc_capa_actions_r3250(capa_status);

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
  insert into public.neurodiag_qc_r3250 (
    organization_id, hospital_name, device_code, device_type, department,
    check_date, calibration_signal_ok, electrode_impedance_check, channel_dropout_count,
    photic_stimulator_ok, amplifier_noise_uv, filter_settings_verified,
    electrical_safety_leakage_ua, accessories_condition, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dev, q.dtype, q.dept,
    q.cdate::date, q.cal, q.imp, q.dcount,
    q.photic, q.noise, q.filt,
    q.leak, q.acc, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','EEG-APL-101','eeg_64ch','Neurology','2026-07-03',
     true,'pass',0,'ok',1.20,true,42.0,'complete','pass','Quarterly QC — cal square-wave and impedance all nominal'),
    ('Apollo Chennai Greams Road','EMG-APL-102','emg_ncv','Neurophysiology Lab','2026-07-03',
     true,'high_impedance',1,'not_applicable',2.80,true,55.0,'worn','conditional_pass','Surface electrode leads worn — impedance above 10 kOhm on two leads'),
    ('Fortis Gurgaon','EEG-FRT-201','eeg_32ch','Neurology','2026-07-02',
     true,'pass',0,'flicker_fault',1.50,true,48.0,'complete','conditional_pass','Photic stimulator flickers above 20 Hz — lamp ageing suspected'),
    ('Fortis Gurgaon','EP-FRT-202','evoked_potential','Neurophysiology Lab','2026-07-02',
     false,'pass',2,'not_applicable',4.60,false,61.0,'complete','fail','Cal square-wave distorted and filters left at wrong bandpass'),
    ('Manipal Old Airport Road Bengaluru','EEG-MNP-301','eeg_64ch','Epilepsy Monitoring Unit','2026-07-01',
     true,'pass',0,'ok',1.10,true,38.0,'complete','pass','LTM unit verified before EMU admission week'),
    ('Manipal Old Airport Road Bengaluru','PSG-MNP-302','polysomnography','Sleep Lab','2026-07-01',
     true,'high_impedance',3,'not_applicable',3.40,true,52.0,'worn','conditional_pass','3 EEG channels dropped during overnight simulation — headbox connector check due'),
    ('AIIMS New Delhi','EEG-AIM-401','eeg_32ch','Neurology OPD','2026-06-30',
     true,'fail',6,'ok',8.90,true,74.0,'missing_items','fail','Impedance fail on 6 channels and electrode kit incomplete'),
    ('AIIMS New Delhi','EMG-AIM-402','emg_ncv','Neurophysiology Lab','2026-06-30',
     true,'pass',0,'not_applicable',1.90,true,44.0,'complete','pass','NCV stimulator output verified within 5 percent by Ramesh Iyer'),
    ('CMC Vellore','EP-CMC-501','evoked_potential','Audiology & EP Lab','2026-06-29',
     true,'pass',1,'not_applicable',2.20,true,47.0,'complete','pass','BAEP click latency check within tolerance'),
    ('CMC Vellore','EEG-CMC-502','eeg_64ch','Epilepsy Monitoring Unit','2026-06-29',
     false,'high_impedance',4,'ok',6.70,true,118.0,'worn','removed_from_service','Cal signal absent and leakage 118 uA above 100 uA limit — unit pulled'),
    ('KIMS Secunderabad','EEG-KIM-601','eeg_32ch','ICU Neuro-monitoring','2026-06-28',
     true,'pass',0,'not_applicable',1.70,true,41.0,'complete','pass','Portable ICU EEG verified after AMC visit by Suresh Babu'),
    ('KIMS Secunderabad','PSG-KIM-602','polysomnography','Sleep Lab','2026-06-28',
     true,'pass',2,'not_applicable',2.60,false,49.0,'complete','conditional_pass','Filter defaults wrong after software update — corrected on the spot'),
    ('NIMHANS Bengaluru','EMG-NIM-701','emg_ncv','Neuromuscular Lab','2026-06-27',
     true,'pass',0,'not_applicable',1.40,true,39.0,'complete','pass','Repetitive nerve stimulation module OK — checked by Priya Nair'),
    ('NIMHANS Bengaluru','EEG-NIM-702','eeg_64ch','Neurology','2026-06-27',
     true,'high_impedance',1,'flicker_fault',3.10,true,57.0,'worn','conditional_pass','Photic lamp fault plus worn cap electrodes — CAPA raised')
  ) as q(hosp, dev, dtype, dept, cdate, cal, imp, dcount, photic, noise, filt, leak, acc, qv, nt);

  -- CAPA seed — attach to specific QC checks via device code
  insert into public.neurodiag_qc_capa_actions_r3250 (
    qc_check_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('EMG-APL-102','high_electrode_impedance','electrode_lead_wear','replace_electrode_leads','in_progress','internal_only','2026-07-10',null,14500.00,'Replacement surface-electrode lead set on order'),
    ('EEG-FRT-201','photic_stimulator_fault','photic_lamp_ageing','replace_photic_lamp','open','internal_only','2026-07-09',null,6500.00,'Photic lamp module quoted by OEM'),
    ('EP-FRT-202','filter_config_error','software_filter_misconfig','reconfigure_filter_settings','verification_pending','iso_13485_deviation','2026-07-06',null,0.00,'Bandpass restored to protocol defaults — verify on next EP list'),
    ('EEG-AIM-401','accessories_incomplete','accessory_loss_in_ward','reissue_accessory_kit','escalated','nabh_finding','2026-07-05',null,22000.00,'Electrode kit reissue escalated to biomedical stores'),
    ('EEG-CMC-502','electrical_leakage_excess','earth_bonding_degraded','restore_earth_bonding','open','patient_safety_alert','2026-07-04',null,18000.00,'Leakage 118 uA — earth bonding rework before return to EMU'),
    ('PSG-MNP-302','channel_dropout','headbox_connector_damage','replace_headbox_connector','closed','internal_only','2026-07-02','2026-06-30',9800.00,'Headbox connector replaced — overnight retest clean'),
    ('EEG-NIM-702','high_electrode_impedance','electrode_lead_wear','replace_electrode_leads','overdue','internal_only','2026-06-25',null,12000.00,'Electrode cap replacement past target date — vendor delayed')
  ) as q(dev, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.neurodiag_qc_r3250 e
    on e.organization_id = v_org_id and e.device_code = q.dev;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3250_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neurodiag_qc_r3250)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.neurodiag_qc_r3250 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3250_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3250_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3250_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  impedance_issues bigint,
  cal_signal_fail bigint,
  avg_noise_uv numeric,
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
    count(*) filter (where l.electrode_impedance_check in ('high_impedance','fail'))::bigint,
    count(*) filter (where l.calibration_signal_ok = false)::bigint,
    round(avg(l.amplifier_noise_uv), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.neurodiag_qc_r3250 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3250_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3250_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3250_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_noise_uv numeric, avg_leakage_ua numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.amplifier_noise_uv), 2),
    round(avg(l.electrical_safety_leakage_ua), 1)
  from public.neurodiag_qc_r3250 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3250_device_department_matrix() from public, anon;
grant execute on function public.founder_r3250_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3250_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, impedance_issues bigint, cal_signal_fail bigint)
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
    count(*) filter (where l.electrode_impedance_check in ('high_impedance','fail'))::bigint,
    count(*) filter (where l.calibration_signal_ok = false)::bigint
  from public.neurodiag_qc_r3250 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3250_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3250_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3250_capa_status_board()
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
  from public.neurodiag_qc_capa_actions_r3250 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3250_capa_status_board() from public, anon;
grant execute on function public.founder_r3250_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3250_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neurodiag_qc_capa_actions_r3250)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.neurodiag_qc_capa_actions_r3250 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3250_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3250_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3250_regulatory_impact_digest()
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
  from public.neurodiag_qc_capa_actions_r3250 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3250_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3250_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3250_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  electrode_impedance_check text,
  channel_dropout_count int,
  photic_stimulator_ok text,
  accessories_condition text,
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
    l.qc_verdict, l.electrode_impedance_check, l.channel_dropout_count,
    l.photic_stimulator_ok, l.accessories_condition, l.notes
  from public.neurodiag_qc_r3250 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.electrode_impedance_check in ('high_impedance','fail')
     or l.calibration_signal_ok = false
     or l.channel_dropout_count >= 3
     or l.photic_stimulator_ok = 'flicker_fault'
     or l.electrical_safety_leakage_ua > 100
     or l.accessories_condition in ('worn','missing_items')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3250_high_risk_queue() from public, anon;
grant execute on function public.founder_r3250_high_risk_queue() to authenticated;
