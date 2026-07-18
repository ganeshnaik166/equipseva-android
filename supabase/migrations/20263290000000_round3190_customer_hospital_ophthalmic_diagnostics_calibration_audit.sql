-- Round 3190: Customer Hospital Slit-Lamp, Phoropter & Ophthalmic-Diagnostics Calibration Audit
-- Ophthalmic QA — device type × illumination × IOP-cal offset mmHg × optics clarity × alignment × filter wheel × chin-rest hygiene × CAPA

-- =============================================================================
-- TABLE 1: ophthalmic_diag_r3190 — individual device calibration audit checks
-- =============================================================================
create table if not exists public.ophthalmic_diag_r3190 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  eye_unit_code text not null,
  device_asset_tag text not null,
  device_model text not null,
  device_type text not null check (device_type in (
    'slit_lamp','phoropter','applanation_tonometer','non_contact_tonometer',
    'autorefractor','fundus_camera','keratometer','lensmeter'
  )),
  calibration_date date not null,
  checked_at timestamptz,
  illumination_check text not null check (illumination_check in (
    'uniform_bright','dim_output','flicker_detected','bulb_replaced','led_degraded','not_applicable'
  )),
  iop_cal_offset_mmhg numeric(4,1),
  optics_clarity text not null check (optics_clarity in (
    'crystal_clear','minor_dust','fungus_etching','haze_coating_damage','scratched_lens','not_applicable'
  )),
  alignment_status text not null check (alignment_status in (
    'aligned','minor_offset','decentered','collimation_required','not_applicable'
  )),
  filter_wheel_status text not null check (filter_wheel_status in (
    'all_filters_ok','cobalt_blue_faded','red_free_stuck','filter_missing','wheel_jammed','not_applicable'
  )),
  chin_rest_hygiene text not null check (chin_rest_hygiene in (
    'clean_disinfected','paper_stock_low','soiled','strap_damaged','not_applicable'
  )),
  technician_profile_id uuid references public.profiles(id) on delete set null,
  calibration_verdict text not null check (calibration_verdict in (
    'calibrated_released','adjusted_released','quarantined','service_required','condemned_recommend','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ophthalmic_diag_r3190 enable row level security;

create index if not exists idx_ophthalmic_diag_r3190_org on public.ophthalmic_diag_r3190(organization_id);
create index if not exists idx_ophthalmic_diag_r3190_date on public.ophthalmic_diag_r3190(calibration_date);
create index if not exists idx_ophthalmic_diag_r3190_verdict on public.ophthalmic_diag_r3190(calibration_verdict);

-- =============================================================================
-- TABLE 2: ophthalmic_diag_capa_actions_r3190 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ophthalmic_diag_capa_actions_r3190 (
  id uuid primary key default gen_random_uuid(),
  diag_log_id uuid not null references public.ophthalmic_diag_r3190(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'iop_offset_out_of_tolerance','illumination_fail','optics_fungus','alignment_fail',
    'filter_wheel_fault','hygiene_lapse','calibration_overdue','operator_error',
    'preventive_maintenance_due','power_supply_fault'
  )),
  root_cause text not null check (root_cause in (
    'humidity_fungal_growth','bulb_lamp_aging','mechanical_wear','transport_shock',
    'voltage_fluctuation','operator_mishandling','cleaning_protocol_gap','sensor_drift',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_iop_probe','replace_bulb_led','fungus_cleaning_optics','realign_optical_axis',
    'replace_filter_wheel','deep_disinfection','retrain_operator','install_dehumidifier',
    'schedule_amc_visit','condemn_and_replace','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ophthalmic_diag_capa_actions_r3190 enable row level security;

create index if not exists idx_ophthalmic_capa_r3190_log on public.ophthalmic_diag_capa_actions_r3190(diag_log_id);
create index if not exists idx_ophthalmic_capa_r3190_status on public.ophthalmic_diag_capa_actions_r3190(capa_status);

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

  -- 13 calibration audit rows
  insert into public.ophthalmic_diag_r3190 (
    organization_id, hospital_name, eye_unit_code, device_asset_tag, device_model, device_type,
    calibration_date, checked_at, illumination_check, iop_cal_offset_mmhg,
    optics_clarity, alignment_status, filter_wheel_status, chin_rest_hygiene,
    calibration_verdict, notes
  )
  select v_org_id, q.hosp, q.unit, q.tag, q.model, q.dtype,
    q.cd::date, q.ca::timestamptz, q.ill, q.iop,
    q.oc, q.al, q.fw, q.ch,
    q.cv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','EYE-OPD-1','SL-APL-101','Haag-Streit BQ 900','slit_lamp',
     '2026-07-02','2026-07-02 09:15:00+05:30','uniform_bright',null,'crystal_clear','aligned','all_filters_ok','clean_disinfected','calibrated_released','Annual calibration — all checks nominal'),
    ('Apollo Hyderabad Jubilee Hills','EYE-OPD-1','AT-APL-102','Haag-Streit AT 900','applanation_tonometer',
     '2026-07-02','2026-07-02 10:00:00+05:30','not_applicable',0.5,'crystal_clear','aligned','not_applicable','clean_disinfected','calibrated_released','IOP offset 0.5 mmHg within plus-minus 1 tolerance'),
    ('Fortis Bannerghatta Bengaluru','EYE-OPD-2','AT-FRT-201','Keeler KAT R-type','applanation_tonometer',
     '2026-07-01','2026-07-01 11:30:00+05:30','not_applicable',2.5,'minor_dust','aligned','not_applicable','paper_stock_low','quarantined','Offset 2.5 mmHg exceeds tolerance — prism recalibration needed'),
    ('Fortis Bannerghatta Bengaluru','EYE-OPD-2','SL-FRT-202','Zeiss SL 220','slit_lamp',
     '2026-07-01','2026-07-01 12:10:00+05:30','flicker_detected',null,'crystal_clear','minor_offset','cobalt_blue_faded','clean_disinfected','service_required','Illumination flicker plus faded cobalt-blue filter'),
    ('Manipal Whitefield Bengaluru','EYE-OPD-1','FC-MNP-301','Zeiss Visucam 524','fundus_camera',
     '2026-06-30','2026-06-30 09:40:00+05:30','dim_output',null,'fungus_etching','aligned','red_free_stuck','clean_disinfected','quarantined','Fungus on objective lens — monsoon humidity in fundus room'),
    ('Manipal Whitefield Bengaluru','EYE-OPD-1','AR-MNP-302','Topcon KR-800','autorefractor',
     '2026-06-30','2026-06-30 10:25:00+05:30','uniform_bright',null,'crystal_clear','aligned','not_applicable','clean_disinfected','calibrated_released','Model-eye verification within 0.12 D'),
    ('AIIMS New Delhi RP Centre','EYE-OPD-3','PH-AIM-401','Topcon VT-10','phoropter',
     '2026-06-29','2026-06-29 08:50:00+05:30','not_applicable',null,'minor_dust','aligned','not_applicable','clean_disinfected','adjusted_released','Cylinder-axis detent cleaned and lubricated'),
    ('AIIMS New Delhi RP Centre','EYE-OPD-3','NT-AIM-402','Topcon CT-800','non_contact_tonometer',
     '2026-06-29','2026-06-29 09:35:00+05:30','not_applicable',-1.8,'crystal_clear','minor_offset','not_applicable','clean_disinfected','service_required','NCT reads 1.8 mmHg low vs Goldmann reference'),
    ('KIMS Secunderabad','EYE-OPD-1','SL-KIM-501','Appasamy AIA-11','slit_lamp',
     '2026-06-28','2026-06-28 10:05:00+05:30','bulb_replaced',null,'crystal_clear','aligned','all_filters_ok','soiled','adjusted_released','Halogen bulb replaced — chin-rest re-disinfection flagged'),
    ('Care Hospitals Banjara Hills','EYE-OPD-2','PH-CAR-601','Nidek RT-5100','phoropter',
     '2026-06-28','2026-06-28 11:20:00+05:30','not_applicable',null,'haze_coating_damage','decentered','not_applicable','clean_disinfected','condemned_recommend','Lens-coating haze widespread — beyond economic repair'),
    ('Yashoda Somajiguda Hyderabad','EYE-OPD-1','AT-YSH-701','Haag-Streit AT 870','applanation_tonometer',
     '2026-06-27','2026-06-27 09:10:00+05:30','not_applicable',0.8,'crystal_clear','aligned','not_applicable','clean_disinfected','calibrated_released','Offset within tolerance — annual sticker updated'),
    ('St John''s Bengaluru','EYE-OPD-2','FC-STJ-801','Canon CR-2 AF','fundus_camera',
     '2026-06-27','2026-06-27 10:45:00+05:30','uniform_bright',null,'minor_dust','collimation_required','all_filters_ok','clean_disinfected','pending_review','Collimation check pending optical-bench slot'),
    ('Rainbow Children''s Hyderabad','EYE-OPD-1','AR-RBW-901','Plusoptix A12C','autorefractor',
     '2026-06-26','2026-06-26 08:30:00+05:30','led_degraded',null,'crystal_clear','aligned','not_applicable','strap_damaged','service_required','IR LED output down 30 percent — paediatric screening on hold')
  ) as q(hosp, unit, tag, model, dtype, cd, ca, ill, iop, oc, al, fw, ch, cv, nt);

  -- CAPA seed — attach to specific devices by asset tag
  insert into public.ophthalmic_diag_capa_actions_r3190 (
    diag_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.act, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('AT-FRT-201','iop_offset_out_of_tolerance','sensor_drift','recalibrate_iop_probe','2026-07-08',null,'in_progress','patient_safety_alert',8500.00,'Prism set sent to Keeler service centre'),
    ('SL-FRT-202','filter_wheel_fault','bulb_lamp_aging','replace_bulb_led','2026-07-10',null,'open','nabh_finding',6200.00,'LED conversion kit quoted by OEM'),
    ('FC-MNP-301','optics_fungus','humidity_fungal_growth','fungus_cleaning_optics','2026-07-05','2026-07-03','closed','iso_13485_deviation',14500.00,'Optics cleaned — dehumidifier installed in fundus room'),
    ('NT-AIM-402','iop_offset_out_of_tolerance','sensor_drift','recalibrate_iop_probe','2026-07-06',null,'verification_pending','cdsco_notifiable',9800.00,'Pressure transducer recalibrated — parallel Goldmann check pending'),
    ('PH-CAR-601','alignment_fail','mechanical_wear','condemn_and_replace','2026-07-20',null,'escalated','internal_only',185000.00,'Replacement digital phoropter capex raised'),
    ('AR-RBW-901','illumination_fail','bulb_lamp_aging','replace_bulb_led','2026-06-30',null,'overdue','patient_safety_alert',7200.00,'IR LED module awaited — paediatric screening backlog growing')
  ) as q(tag_key, fc, rc, act, tcd, acd, cst, ri, cost, nt)
  join public.ophthalmic_diag_r3190 e
    on e.organization_id = v_org_id and e.device_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Calibration verdict distribution
create or replace function public.founder_r3190_verdict_rollup()
returns table(calibration_verdict text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_diag_r3190)
  select l.calibration_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ophthalmic_diag_r3190 l
  group by l.calibration_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3190_verdict_rollup() from public, anon;
grant execute on function public.founder_r3190_verdict_rollup() to authenticated;

-- 2) Hospital-level calibration scorecard
create or replace function public.founder_r3190_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  released bigint,
  quarantined bigint,
  service_required bigint,
  condemned bigint,
  fungus_cases bigint,
  compliance_pct numeric
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
    count(*) filter (where l.calibration_verdict in ('calibrated_released','adjusted_released'))::bigint,
    count(*) filter (where l.calibration_verdict = 'quarantined')::bigint,
    count(*) filter (where l.calibration_verdict = 'service_required')::bigint,
    count(*) filter (where l.calibration_verdict = 'condemned_recommend')::bigint,
    count(*) filter (where l.optics_clarity = 'fungus_etching')::bigint,
    round(100.0 * count(*) filter (where l.calibration_verdict in ('calibrated_released','adjusted_released'))::numeric / nullif(count(*),0), 1)
  from public.ophthalmic_diag_r3190 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3190_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3190_hospital_scorecard() to authenticated;

-- 3) Device-type × verdict matrix
create or replace function public.founder_r3190_device_type_matrix()
returns table(device_type text, checks bigint, released bigint, quarantined bigint, avg_abs_iop_offset_mmhg numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, count(*)::bigint,
    count(*) filter (where l.calibration_verdict in ('calibrated_released','adjusted_released'))::bigint,
    count(*) filter (where l.calibration_verdict = 'quarantined')::bigint,
    round(avg(abs(l.iop_cal_offset_mmhg)), 2)
  from public.ophthalmic_diag_r3190 l
  group by l.device_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3190_device_type_matrix() from public, anon;
grant execute on function public.founder_r3190_device_type_matrix() to authenticated;

-- 4) Daily calibration trend
create or replace function public.founder_r3190_daily_trend()
returns table(calibration_date date, checks bigint, released bigint, quarantined bigint, service_required bigint, illumination_faults bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.calibration_date,
    count(*)::bigint,
    count(*) filter (where l.calibration_verdict in ('calibrated_released','adjusted_released'))::bigint,
    count(*) filter (where l.calibration_verdict = 'quarantined')::bigint,
    count(*) filter (where l.calibration_verdict = 'service_required')::bigint,
    count(*) filter (where l.illumination_check in ('dim_output','flicker_detected','led_degraded'))::bigint
  from public.ophthalmic_diag_r3190 l
  group by l.calibration_date
  order by l.calibration_date desc;
end;
$$;

revoke execute on function public.founder_r3190_daily_trend() from public, anon;
grant execute on function public.founder_r3190_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3190_capa_status_board()
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
  from public.ophthalmic_diag_capa_actions_r3190 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3190_capa_status_board() from public, anon;
grant execute on function public.founder_r3190_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3190_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_diag_capa_actions_r3190)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ophthalmic_diag_capa_actions_r3190 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3190_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3190_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3190_regulatory_impact_digest()
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
  from public.ophthalmic_diag_capa_actions_r3190 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3190_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3190_regulatory_impact_digest() to authenticated;

-- 8) High-risk devices queue (top individual concerns)
create or replace function public.founder_r3190_high_risk_devices()
returns table(
  hospital_name text,
  eye_unit_code text,
  device_asset_tag text,
  device_type text,
  calibration_date date,
  calibration_verdict text,
  iop_cal_offset_mmhg numeric,
  optics_clarity text,
  alignment_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.eye_unit_code, l.device_asset_tag, l.device_type, l.calibration_date,
    l.calibration_verdict, l.iop_cal_offset_mmhg, l.optics_clarity, l.alignment_status, l.notes
  from public.ophthalmic_diag_r3190 l
  where l.calibration_verdict in ('quarantined','service_required','condemned_recommend','pending_review')
     or abs(l.iop_cal_offset_mmhg) > 1.5
     or l.optics_clarity in ('fungus_etching','haze_coating_damage','scratched_lens')
     or l.alignment_status in ('decentered','collimation_required')
     or l.illumination_check in ('dim_output','flicker_detected','led_degraded')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3190_high_risk_devices() from public, anon;
grant execute on function public.founder_r3190_high_risk_devices() to authenticated;
