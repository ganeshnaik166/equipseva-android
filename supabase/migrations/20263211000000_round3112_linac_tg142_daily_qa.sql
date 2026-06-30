-- Round 3112 — LINAC TG-142 Daily QA, Output Drift, MLC, CAPA
-- HEAVY ★★★★ — Customer hospital cancer-centre linear accelerator daily quality audit
-- per AAPM TG-142 with energy, symmetry, flatness, output stability, MLC positioning,
-- beam profile drift tracking and CAPA workflow.

set search_path = public, pg_temp;

-- =========================================================================
-- Table 1: linac_tg142_daily_runs_r3112
--   One row per LINAC × day × energy mode (e.g. 6 MV photon, 6 MeV electron).
-- =========================================================================
create table if not exists public.linac_tg142_daily_runs_r3112 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  hospital_site_name text not null,
  linac_serial text not null,
  linac_make_model text not null,
  run_date date not null,
  energy_mode text not null,
  beam_type text not null,
  monitor_units_delivered integer not null,
  measured_output_cgy_per_mu numeric(8,4) not null,
  baseline_output_cgy_per_mu numeric(8,4) not null,
  output_drift_percent numeric(6,3) not null,
  inline_symmetry_percent numeric(6,3) not null,
  crossline_symmetry_percent numeric(6,3) not null,
  inline_flatness_percent numeric(6,3) not null,
  crossline_flatness_percent numeric(6,3) not null,
  beam_energy_constancy_percent numeric(6,3) not null,
  mlc_max_leaf_position_error_mm numeric(6,3) not null,
  mlc_picket_fence_passed boolean not null,
  isocenter_walkout_mm numeric(6,3) not null,
  laser_alignment_mm numeric(6,3) not null,
  odi_accuracy_mm numeric(6,3) not null,
  ambient_temperature_c numeric(5,2) not null,
  ambient_pressure_kpa numeric(6,2) not null,
  ambient_humidity_percent numeric(5,2) not null,
  chamber_used text not null,
  physicist_profile_id uuid references public.profiles(id),
  engineer_id uuid references public.engineers(id),
  qa_phantom_used text not null,
  tg142_status text not null,
  drift_classification text not null,
  patient_treatment_held boolean not null default false,
  patients_affected_count integer not null default 0,
  notes text,
  recorded_at timestamptz not null default now(),
  constraint linac_runs_r3112_energy_chk check (energy_mode in (
    '6mv_photon','10mv_photon','15mv_photon','18mv_photon',
    '6mv_fff','10mv_fff',
    '6mev_electron','9mev_electron','12mev_electron','15mev_electron','18mev_electron'
  )),
  constraint linac_runs_r3112_beamtype_chk check (beam_type in (
    'photon','electron','photon_fff','imrt','vmat','sbrt','srs'
  )),
  constraint linac_runs_r3112_status_chk check (tg142_status in (
    'within_tolerance','action_level','suspend_clinical','machine_down','baseline_reset_required'
  )),
  constraint linac_runs_r3112_drift_chk check (drift_classification in (
    'nominal','minor_drift','moderate_drift','major_drift','out_of_spec','trending_alarm'
  )),
  constraint linac_runs_r3112_chamber_chk check (chamber_used in (
    'ptw_31010_semiflex','ptw_30013_farmer','iba_fc65g','iba_cc13','sun_nuclear_daily_qa3','dosimetrix_blue'
  )),
  constraint linac_runs_r3112_phantom_chk check (qa_phantom_used in (
    'sun_nuclear_daily_qa3','ptw_quickcheck_webline','iba_starcheck','imrt_mapcheck2','arccheck','none_handheld'
  ))
);

create index if not exists linac_runs_r3112_org_idx on public.linac_tg142_daily_runs_r3112(org_id, run_date desc);
create index if not exists linac_runs_r3112_serial_idx on public.linac_tg142_daily_runs_r3112(linac_serial, run_date desc);
create index if not exists linac_runs_r3112_status_idx on public.linac_tg142_daily_runs_r3112(tg142_status);

alter table public.linac_tg142_daily_runs_r3112 enable row level security;

-- =========================================================================
-- Table 2: linac_tg142_capa_actions_r3112
--   CAPA (Corrective And Preventive Action) tickets raised against QA runs.
-- =========================================================================
create table if not exists public.linac_tg142_capa_actions_r3112 (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.linac_tg142_daily_runs_r3112(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  capa_code text not null,
  capa_category text not null,
  trigger_parameter text not null,
  measured_value numeric(8,3) not null,
  tolerance_limit numeric(8,3) not null,
  severity text not null,
  root_cause_class text not null,
  action_owner_engineer_id uuid references public.engineers(id),
  action_owner_physicist_id uuid references public.profiles(id),
  capa_status text not null,
  opened_at timestamptz not null default now(),
  due_at timestamptz,
  closed_at timestamptz,
  hours_to_close numeric(8,2),
  spare_part_required text,
  vendor_escalated_to text,
  patient_safety_event boolean not null default false,
  aerb_notification_required boolean not null default false,
  aerb_notified_at timestamptz,
  follow_up_qa_run_id uuid references public.linac_tg142_daily_runs_r3112(id),
  resolution_summary text,
  effectiveness_check_passed boolean,
  constraint linac_capa_r3112_category_chk check (capa_category in (
    'output_drift','energy_constancy','symmetry','flatness','mlc_positioning',
    'isocenter_walkout','laser_alignment','odi_calibration','chamber_drift',
    'environmental','interlock_failure','beam_profile_skew'
  )),
  constraint linac_capa_r3112_trigger_chk check (trigger_parameter in (
    'output_drift_percent','beam_energy_constancy_percent',
    'inline_symmetry_percent','crossline_symmetry_percent',
    'inline_flatness_percent','crossline_flatness_percent',
    'mlc_max_leaf_position_error_mm','isocenter_walkout_mm',
    'laser_alignment_mm','odi_accuracy_mm','ambient_temperature_c'
  )),
  constraint linac_capa_r3112_severity_chk check (severity in (
    'info','minor','moderate','major','critical','clinical_suspend'
  )),
  constraint linac_capa_r3112_rootcause_chk check (root_cause_class in (
    'gun_filament_aging','dose_chamber_drift','bend_magnet_current',
    'mlc_motor_wear','collimator_jaw_slip','laser_mount_shift',
    'odi_optical_drift','hvac_temperature_swing','phantom_setup_error',
    'physicist_procedure_deviation','firmware_bug','unknown_investigating'
  )),
  constraint linac_capa_r3112_status_chk check (capa_status in (
    'open','in_progress','awaiting_part','vendor_escalated','effectiveness_pending','closed','dropped_false_alarm'
  ))
);

create index if not exists linac_capa_r3112_run_idx on public.linac_tg142_capa_actions_r3112(run_id);
create index if not exists linac_capa_r3112_status_idx on public.linac_tg142_capa_actions_r3112(capa_status);
create index if not exists linac_capa_r3112_severity_idx on public.linac_tg142_capa_actions_r3112(severity);

alter table public.linac_tg142_capa_actions_r3112 enable row level security;

-- =========================================================================
-- Seed data — 12 rows of runs across 4 cancer-centre hospital sites,
--             10 CAPA actions of varying severity.
-- =========================================================================
do $seed$
declare
  v_org uuid;
  v_phys uuid;
  v_eng uuid;
  v_run1 uuid; v_run2 uuid; v_run3 uuid; v_run4 uuid;
  v_run5 uuid; v_run6 uuid; v_run7 uuid; v_run8 uuid;
  v_run9 uuid; v_run10 uuid; v_run11 uuid; v_run12 uuid;
begin
  select id into v_org from public.organizations order by created_at asc limit 1;
  if v_org is null then
    raise notice 'no organizations row found, skipping seed';
    return;
  end if;

  select id into v_phys from public.profiles order by created_at asc limit 1;
  select id into v_eng from public.engineers order by created_at asc limit 1;

  -- 12 daily run rows
  insert into public.linac_tg142_daily_runs_r3112 (
    org_id, hospital_site_name, linac_serial, linac_make_model,
    run_date, energy_mode, beam_type,
    monitor_units_delivered, measured_output_cgy_per_mu, baseline_output_cgy_per_mu, output_drift_percent,
    inline_symmetry_percent, crossline_symmetry_percent,
    inline_flatness_percent, crossline_flatness_percent,
    beam_energy_constancy_percent,
    mlc_max_leaf_position_error_mm, mlc_picket_fence_passed,
    isocenter_walkout_mm, laser_alignment_mm, odi_accuracy_mm,
    ambient_temperature_c, ambient_pressure_kpa, ambient_humidity_percent,
    chamber_used, physicist_profile_id, engineer_id, qa_phantom_used,
    tg142_status, drift_classification, patient_treatment_held, patients_affected_count, notes
  ) values
  (v_org,'Apollo Cancer Centre Hyderabad','LINAC-VBT-7821','Varian TrueBeam STx',
    current_date,'6mv_photon','photon',
    200, 1.0012, 1.0000, 0.120,
    100.4, 100.6, 102.1, 102.3, 100.2,
    0.3, true, 0.4, 0.5, 0.6,
    22.1, 101.20, 48.0,
    'ptw_31010_semiflex', v_phys, v_eng, 'sun_nuclear_daily_qa3',
    'within_tolerance','nominal', false, 0, 'Morning warm-up, three-beam check passed'),
  (v_org,'Apollo Cancer Centre Hyderabad','LINAC-VBT-7821','Varian TrueBeam STx',
    current_date - 1,'6mv_fff','photon_fff',
    400, 1.0028, 1.0000, 0.280,
    100.7, 100.9, 0.0, 0.0, 100.3,
    0.4, true, 0.5, 0.6, 0.7,
    22.4, 101.10, 49.0,
    'ptw_31010_semiflex', v_phys, v_eng, 'sun_nuclear_daily_qa3',
    'within_tolerance','minor_drift', false, 0, 'FFF — flatness not applicable, unflattened beam'),
  (v_org,'Apollo Cancer Centre Hyderabad','LINAC-VBT-7821','Varian TrueBeam STx',
    current_date - 2,'10mv_photon','imrt',
    300, 1.0085, 1.0000, 0.850,
    100.9, 101.4, 102.6, 102.9, 100.5,
    0.7, true, 0.6, 0.7, 0.8,
    23.8, 101.05, 52.0,
    'ptw_30013_farmer', v_phys, v_eng, 'imrt_mapcheck2',
    'action_level','moderate_drift', false, 0, 'Output drift breaching 1% action threshold, recalibration scheduled'),
  (v_org,'Tata Memorial Mumbai','LINAC-EX-4521','Elekta Versa HD',
    current_date,'6mv_photon','photon',
    200, 0.9970, 1.0000, -0.300,
    99.6, 99.4, 101.8, 101.9, 99.8,
    0.4, true, 0.5, 0.6, 0.7,
    21.8, 101.25, 46.0,
    'iba_fc65g', v_phys, v_eng, 'ptw_quickcheck_webline',
    'within_tolerance','nominal', false, 0, 'Morning daily QA, all parameters green'),
  (v_org,'Tata Memorial Mumbai','LINAC-EX-4521','Elekta Versa HD',
    current_date - 1,'15mv_photon','vmat',
    500, 1.0155, 1.0000, 1.550,
    101.4, 101.8, 103.4, 103.7, 101.1,
    1.1, false, 1.3, 1.4, 1.5,
    25.2, 100.90, 58.0,
    'iba_cc13', v_phys, v_eng, 'arccheck',
    'suspend_clinical','out_of_spec', true, 8, 'Major drift on 15MV, MLC picket-fence failed — clinical suspended pending vendor visit'),
  (v_org,'Tata Memorial Mumbai','LINAC-EX-4521','Elekta Versa HD',
    current_date - 2,'6mev_electron','electron',
    150, 1.0045, 1.0000, 0.450,
    100.5, 100.7, 102.3, 102.4, 100.4,
    0.5, true, 0.6, 0.7, 0.8,
    22.0, 101.15, 50.0,
    'iba_fc65g', v_phys, v_eng, 'sun_nuclear_daily_qa3',
    'within_tolerance','minor_drift', false, 0, 'Electron 6MeV daily check, within TG-142 tolerance'),
  (v_org,'HCG Cancer Centre Bengaluru','LINAC-VTC-9912','Varian Clinac iX',
    current_date,'6mv_photon','photon',
    200, 1.0050, 1.0000, 0.500,
    100.6, 100.8, 102.2, 102.4, 100.3,
    0.6, true, 0.7, 0.8, 0.9,
    23.0, 101.00, 51.0,
    'ptw_30013_farmer', v_phys, v_eng, 'sun_nuclear_daily_qa3',
    'within_tolerance','minor_drift', false, 0, 'Daily morning baseline within tolerance'),
  (v_org,'HCG Cancer Centre Bengaluru','LINAC-VTC-9912','Varian Clinac iX',
    current_date - 1,'10mv_photon','sbrt',
    600, 1.0210, 1.0000, 2.100,
    101.9, 102.4, 103.8, 104.1, 101.5,
    1.4, false, 1.7, 1.8, 2.0,
    27.5, 100.80, 62.0,
    'iba_cc13', v_phys, v_eng, 'arccheck',
    'machine_down','out_of_spec', true, 12, 'Critical — output 2.1% high, MLC error 1.4mm, isocenter walkout 1.7mm, HVAC fault upstream'),
  (v_org,'HCG Cancer Centre Bengaluru','LINAC-VTC-9912','Varian Clinac iX',
    current_date - 2,'12mev_electron','electron',
    180, 1.0090, 1.0000, 0.900,
    100.9, 101.0, 102.5, 102.6, 100.6,
    0.7, true, 0.8, 0.9, 1.0,
    22.6, 101.10, 49.0,
    'iba_fc65g', v_phys, v_eng, 'sun_nuclear_daily_qa3',
    'action_level','moderate_drift', false, 0, 'Electron 12MeV slightly above 0.5% action limit, monitoring'),
  (v_org,'AIIMS Delhi RT Block','LINAC-EVH-3344','Elekta Versa HD',
    current_date,'6mv_photon','imrt',
    300, 1.0008, 1.0000, 0.080,
    100.2, 100.3, 101.9, 102.0, 100.1,
    0.2, true, 0.3, 0.4, 0.5,
    21.5, 101.30, 45.0,
    'ptw_31010_semiflex', v_phys, v_eng, 'sun_nuclear_daily_qa3',
    'within_tolerance','nominal', false, 0, 'AIIMS RT-1 daily QA, gold-standard reading'),
  (v_org,'AIIMS Delhi RT Block','LINAC-EVH-3344','Elekta Versa HD',
    current_date - 1,'18mv_photon','imrt',
    400, 1.0125, 1.0000, 1.250,
    101.2, 101.5, 102.9, 103.1, 100.8,
    0.9, true, 1.0, 1.1, 1.2,
    24.6, 101.00, 55.0,
    'iba_fc65g', v_phys, v_eng, 'imrt_mapcheck2',
    'action_level','major_drift', false, 0, 'High-energy photon trending up, physics flagged CAPA'),
  (v_org,'AIIMS Delhi RT Block','LINAC-EVH-3344','Elekta Versa HD',
    current_date - 2,'9mev_electron','electron',
    160, 1.0035, 1.0000, 0.350,
    100.4, 100.5, 102.0, 102.1, 100.2,
    0.4, true, 0.5, 0.6, 0.7,
    21.9, 101.20, 47.0,
    'iba_fc65g', v_phys, v_eng, 'sun_nuclear_daily_qa3',
    'within_tolerance','nominal', false, 0, 'Electron 9MeV baseline check, no issues');

  -- pick up run ids for CAPA linkage
  select id into v_run3 from public.linac_tg142_daily_runs_r3112
    where tg142_status = 'action_level' and energy_mode = '10mv_photon' and hospital_site_name = 'Apollo Cancer Centre Hyderabad' order by recorded_at desc limit 1;
  select id into v_run5 from public.linac_tg142_daily_runs_r3112
    where tg142_status = 'suspend_clinical' and energy_mode = '15mv_photon' order by recorded_at desc limit 1;
  select id into v_run8 from public.linac_tg142_daily_runs_r3112
    where tg142_status = 'machine_down' and hospital_site_name = 'HCG Cancer Centre Bengaluru' order by recorded_at desc limit 1;
  select id into v_run9 from public.linac_tg142_daily_runs_r3112
    where tg142_status = 'action_level' and energy_mode = '12mev_electron' order by recorded_at desc limit 1;
  select id into v_run11 from public.linac_tg142_daily_runs_r3112
    where tg142_status = 'action_level' and energy_mode = '18mv_photon' order by recorded_at desc limit 1;

  insert into public.linac_tg142_capa_actions_r3112 (
    run_id, org_id, capa_code, capa_category, trigger_parameter,
    measured_value, tolerance_limit, severity, root_cause_class,
    action_owner_engineer_id, action_owner_physicist_id,
    capa_status, opened_at, due_at, closed_at, hours_to_close,
    spare_part_required, vendor_escalated_to,
    patient_safety_event, aerb_notification_required, aerb_notified_at,
    resolution_summary, effectiveness_check_passed
  ) values
  (v_run3, v_org, 'CAPA-3112-001','output_drift','output_drift_percent',
    0.850, 1.000, 'moderate', 'dose_chamber_drift',
    v_eng, v_phys, 'in_progress',
    now() - interval '1 day', now() + interval '1 day', null, null,
    'ion chamber bias supply board', 'Varian India FSE',
    false, false, null,
    null, null),
  (v_run5, v_org, 'CAPA-3112-002','output_drift','output_drift_percent',
    1.550, 1.000, 'critical', 'bend_magnet_current',
    v_eng, v_phys, 'vendor_escalated',
    now() - interval '1 day', now() + interval '12 hours', null, null,
    'bend magnet PSU module', 'Elekta India L2 support',
    true, true, now() - interval '20 hours',
    null, null),
  (v_run5, v_org, 'CAPA-3112-003','mlc_positioning','mlc_max_leaf_position_error_mm',
    1.100, 1.000, 'major', 'mlc_motor_wear',
    v_eng, v_phys, 'awaiting_part',
    now() - interval '20 hours', now() + interval '2 days', null, null,
    'MLC leaf motor assembly bank-A', 'Elekta India',
    false, false, null,
    null, null),
  (v_run8, v_org, 'CAPA-3112-004','output_drift','output_drift_percent',
    2.100, 1.000, 'clinical_suspend', 'hvac_temperature_swing',
    v_eng, v_phys, 'in_progress',
    now() - interval '2 days', now() + interval '6 hours', null, null,
    null, 'Hospital facilities + Varian FSE',
    true, true, now() - interval '40 hours',
    null, null),
  (v_run8, v_org, 'CAPA-3112-005','mlc_positioning','mlc_max_leaf_position_error_mm',
    1.400, 1.000, 'major', 'mlc_motor_wear',
    v_eng, v_phys, 'open',
    now() - interval '2 days', now() + interval '3 days', null, null,
    'MLC leaf bank-B replacement kit', 'Varian India',
    false, false, null,
    null, null),
  (v_run8, v_org, 'CAPA-3112-006','isocenter_walkout','isocenter_walkout_mm',
    1.700, 1.000, 'major', 'collimator_jaw_slip',
    v_eng, v_phys, 'effectiveness_pending',
    now() - interval '36 hours', now() + interval '12 hours', now() - interval '4 hours', 32.00,
    'collimator drive belt', 'Varian India',
    false, false, null,
    'Replaced collimator drive belt and re-aligned per Winston-Lutz; awaiting 7-day effectiveness QA', null),
  (v_run9, v_org, 'CAPA-3112-007','energy_constancy','beam_energy_constancy_percent',
    100.600, 100.500, 'minor', 'gun_filament_aging',
    v_eng, v_phys, 'closed',
    now() - interval '3 days', now() - interval '1 day', now() - interval '18 hours', 54.00,
    null, null,
    false, false, null,
    'Gun current rebalanced via service mode; energy back within 0.2%', true),
  (v_run11, v_org, 'CAPA-3112-008','output_drift','output_drift_percent',
    1.250, 1.000, 'moderate', 'dose_chamber_drift',
    v_eng, v_phys, 'in_progress',
    now() - interval '1 day', now() + interval '2 days', null, null,
    null, 'Elekta India L1 support',
    false, false, null,
    null, null),
  (v_run5, v_org, 'CAPA-3112-009','symmetry','crossline_symmetry_percent',
    101.800, 101.500, 'moderate', 'bend_magnet_current',
    v_eng, v_phys, 'closed',
    now() - interval '4 days', now() - interval '2 days', now() - interval '50 hours', 46.00,
    null, null,
    false, false, null,
    'Steering coils re-tuned, crossline symmetry restored to 100.4%', true),
  (v_run3, v_org, 'CAPA-3112-010','flatness','crossline_flatness_percent',
    102.900, 102.500, 'minor', 'physicist_procedure_deviation',
    v_eng, v_phys, 'dropped_false_alarm',
    now() - interval '5 days', now() - interval '3 days', now() - interval '4 days', 24.00,
    null, null,
    false, false, null,
    'Phantom alignment off by 2mm — repeat measurement showed flatness 102.3%, within tolerance. False alarm.', true);
end
$seed$;

-- =========================================================================
-- RPC 1 — site-level daily summary
-- =========================================================================
create or replace function public.fn_r3112_linac_site_daily_summary()
returns table (
  hospital_site_name text,
  runs_total bigint,
  runs_today bigint,
  pct_within_tolerance numeric,
  pct_action_level numeric,
  pct_suspend_or_down numeric,
  worst_output_drift_percent numeric,
  patients_held_today bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      r.hospital_site_name,
      count(*)::bigint,
      count(*) filter (where r.run_date = current_date)::bigint,
      round(100.0 * count(*) filter (where r.tg142_status = 'within_tolerance') / nullif(count(*),0), 1),
      round(100.0 * count(*) filter (where r.tg142_status = 'action_level') / nullif(count(*),0), 1),
      round(100.0 * count(*) filter (where r.tg142_status in ('suspend_clinical','machine_down')) / nullif(count(*),0), 1),
      max(abs(r.output_drift_percent)),
      coalesce(sum(r.patients_affected_count) filter (where r.run_date = current_date), 0)::bigint
    from public.linac_tg142_daily_runs_r3112 r
    group by r.hospital_site_name
    order by max(abs(r.output_drift_percent)) desc;
end;
$$;

revoke execute on function public.fn_r3112_linac_site_daily_summary() from public, anon;
grant execute on function public.fn_r3112_linac_site_daily_summary() to authenticated;

-- =========================================================================
-- RPC 2 — energy-mode performance distribution
-- =========================================================================
create or replace function public.fn_r3112_linac_energy_mode_drift()
returns table (
  energy_mode text,
  runs_count bigint,
  avg_output_drift_percent numeric,
  max_output_drift_percent numeric,
  avg_energy_constancy_percent numeric,
  picket_fence_failure_rate_percent numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      r.energy_mode,
      count(*)::bigint,
      round(avg(r.output_drift_percent)::numeric, 3),
      round(max(abs(r.output_drift_percent))::numeric, 3),
      round(avg(r.beam_energy_constancy_percent)::numeric, 3),
      round(100.0 * count(*) filter (where r.mlc_picket_fence_passed = false) / nullif(count(*),0), 1)
    from public.linac_tg142_daily_runs_r3112 r
    group by r.energy_mode
    order by max(abs(r.output_drift_percent)) desc;
end;
$$;

revoke execute on function public.fn_r3112_linac_energy_mode_drift() from public, anon;
grant execute on function public.fn_r3112_linac_energy_mode_drift() to authenticated;

-- =========================================================================
-- RPC 3 — out-of-tolerance machines today
-- =========================================================================
create or replace function public.fn_r3112_linac_out_of_tolerance_today()
returns table (
  hospital_site_name text,
  linac_serial text,
  linac_make_model text,
  energy_mode text,
  output_drift_percent numeric,
  tg142_status text,
  drift_classification text,
  patient_treatment_held boolean,
  patients_affected_count integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      r.hospital_site_name,
      r.linac_serial,
      r.linac_make_model,
      r.energy_mode,
      r.output_drift_percent,
      r.tg142_status,
      r.drift_classification,
      r.patient_treatment_held,
      r.patients_affected_count
    from public.linac_tg142_daily_runs_r3112 r
    where r.tg142_status in ('action_level','suspend_clinical','machine_down','baseline_reset_required')
    order by r.run_date desc, abs(r.output_drift_percent) desc;
end;
$$;

revoke execute on function public.fn_r3112_linac_out_of_tolerance_today() from public, anon;
grant execute on function public.fn_r3112_linac_out_of_tolerance_today() to authenticated;

-- =========================================================================
-- RPC 4 — CAPA backlog by severity
-- =========================================================================
create or replace function public.fn_r3112_linac_capa_backlog()
returns table (
  severity text,
  open_count bigint,
  in_progress_count bigint,
  awaiting_part_count bigint,
  vendor_escalated_count bigint,
  closed_count bigint,
  avg_hours_to_close numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      c.severity,
      count(*) filter (where c.capa_status = 'open')::bigint,
      count(*) filter (where c.capa_status = 'in_progress')::bigint,
      count(*) filter (where c.capa_status = 'awaiting_part')::bigint,
      count(*) filter (where c.capa_status = 'vendor_escalated')::bigint,
      count(*) filter (where c.capa_status = 'closed')::bigint,
      round(avg(c.hours_to_close) filter (where c.capa_status = 'closed')::numeric, 1)
    from public.linac_tg142_capa_actions_r3112 c
    group by c.severity
    order by case c.severity
      when 'clinical_suspend' then 1
      when 'critical' then 2
      when 'major' then 3
      when 'moderate' then 4
      when 'minor' then 5
      else 6
    end;
end;
$$;

revoke execute on function public.fn_r3112_linac_capa_backlog() from public, anon;
grant execute on function public.fn_r3112_linac_capa_backlog() to authenticated;

-- =========================================================================
-- RPC 5 — root-cause analysis rollup
-- =========================================================================
create or replace function public.fn_r3112_linac_root_cause_rollup()
returns table (
  root_cause_class text,
  capa_count bigint,
  critical_or_clinical_count bigint,
  patient_safety_events bigint,
  avg_hours_to_close numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      c.root_cause_class,
      count(*)::bigint,
      count(*) filter (where c.severity in ('critical','clinical_suspend'))::bigint,
      count(*) filter (where c.patient_safety_event = true)::bigint,
      round(avg(c.hours_to_close)::numeric, 1)
    from public.linac_tg142_capa_actions_r3112 c
    group by c.root_cause_class
    order by count(*) filter (where c.severity in ('critical','clinical_suspend')) desc, count(*) desc;
end;
$$;

revoke execute on function public.fn_r3112_linac_root_cause_rollup() from public, anon;
grant execute on function public.fn_r3112_linac_root_cause_rollup() to authenticated;

-- =========================================================================
-- RPC 6 — MLC and isocenter physics rollup
-- =========================================================================
create or replace function public.fn_r3112_linac_mlc_isocenter_rollup()
returns table (
  hospital_site_name text,
  runs_count bigint,
  avg_mlc_max_leaf_position_error_mm numeric,
  worst_mlc_max_leaf_position_error_mm numeric,
  picket_fence_failures bigint,
  worst_isocenter_walkout_mm numeric,
  worst_laser_alignment_mm numeric,
  worst_odi_accuracy_mm numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      r.hospital_site_name,
      count(*)::bigint,
      round(avg(r.mlc_max_leaf_position_error_mm)::numeric, 3),
      max(r.mlc_max_leaf_position_error_mm),
      count(*) filter (where r.mlc_picket_fence_passed = false)::bigint,
      max(r.isocenter_walkout_mm),
      max(r.laser_alignment_mm),
      max(r.odi_accuracy_mm)
    from public.linac_tg142_daily_runs_r3112 r
    group by r.hospital_site_name
    order by max(r.mlc_max_leaf_position_error_mm) desc;
end;
$$;

revoke execute on function public.fn_r3112_linac_mlc_isocenter_rollup() from public, anon;
grant execute on function public.fn_r3112_linac_mlc_isocenter_rollup() to authenticated;

-- =========================================================================
-- RPC 7 — beam profile symmetry/flatness rollup
-- =========================================================================
create or replace function public.fn_r3112_linac_beam_profile_rollup()
returns table (
  energy_mode text,
  runs_count bigint,
  worst_inline_symmetry_percent numeric,
  worst_crossline_symmetry_percent numeric,
  worst_inline_flatness_percent numeric,
  worst_crossline_flatness_percent numeric,
  beam_profile_skew_capa_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      r.energy_mode,
      count(*)::bigint,
      max(r.inline_symmetry_percent),
      max(r.crossline_symmetry_percent),
      max(r.inline_flatness_percent),
      max(r.crossline_flatness_percent),
      (select count(*) from public.linac_tg142_capa_actions_r3112 c
        join public.linac_tg142_daily_runs_r3112 r2 on r2.id = c.run_id
        where r2.energy_mode = r.energy_mode and c.capa_category in ('symmetry','flatness','beam_profile_skew'))::bigint
    from public.linac_tg142_daily_runs_r3112 r
    group by r.energy_mode
    order by max(r.crossline_flatness_percent) desc nulls last;
end;
$$;

revoke execute on function public.fn_r3112_linac_beam_profile_rollup() from public, anon;
grant execute on function public.fn_r3112_linac_beam_profile_rollup() to authenticated;

-- =========================================================================
-- RPC 8 — AERB-notifiable events
-- =========================================================================
create or replace function public.fn_r3112_linac_aerb_notifiable()
returns table (
  capa_code text,
  hospital_site_name text,
  linac_serial text,
  severity text,
  capa_status text,
  patient_safety_event boolean,
  aerb_notification_required boolean,
  aerb_notified_at timestamptz,
  trigger_parameter text,
  measured_value numeric,
  tolerance_limit numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      c.capa_code,
      r.hospital_site_name,
      r.linac_serial,
      c.severity,
      c.capa_status,
      c.patient_safety_event,
      c.aerb_notification_required,
      c.aerb_notified_at,
      c.trigger_parameter,
      c.measured_value,
      c.tolerance_limit
    from public.linac_tg142_capa_actions_r3112 c
    join public.linac_tg142_daily_runs_r3112 r on r.id = c.run_id
    where c.aerb_notification_required = true or c.patient_safety_event = true
    order by c.opened_at desc;
end;
$$;

revoke execute on function public.fn_r3112_linac_aerb_notifiable() from public, anon;
grant execute on function public.fn_r3112_linac_aerb_notifiable() to authenticated;

-- =========================================================================
-- RPC 9 — environmental drift correlation
-- =========================================================================
create or replace function public.fn_r3112_linac_environmental_correlation()
returns table (
  hospital_site_name text,
  avg_temperature_c numeric,
  max_temperature_c numeric,
  avg_humidity_percent numeric,
  max_humidity_percent numeric,
  high_temp_runs bigint,
  high_humidity_runs bigint,
  high_temp_action_level_overlap bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      r.hospital_site_name,
      round(avg(r.ambient_temperature_c)::numeric, 2),
      max(r.ambient_temperature_c),
      round(avg(r.ambient_humidity_percent)::numeric, 2),
      max(r.ambient_humidity_percent),
      count(*) filter (where r.ambient_temperature_c > 24.0)::bigint,
      count(*) filter (where r.ambient_humidity_percent > 55.0)::bigint,
      count(*) filter (where r.ambient_temperature_c > 24.0 and r.tg142_status in ('action_level','suspend_clinical','machine_down'))::bigint
    from public.linac_tg142_daily_runs_r3112 r
    group by r.hospital_site_name
    order by max(r.ambient_temperature_c) desc;
end;
$$;

revoke execute on function public.fn_r3112_linac_environmental_correlation() from public, anon;
grant execute on function public.fn_r3112_linac_environmental_correlation() to authenticated;
