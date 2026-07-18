-- Round 3179: Customer Hospital Laboratory Centrifuge & Incubator-Shaker Calibration Audit
-- Lab equipment QA log — device type × set/measured rpm & temp × error % × timer accuracy × rotor integrity × lid interlock × verdict + CAPA

-- =============================================================================
-- TABLE 1: lab_centrifuge_r3179 — individual calibration/verification runs
-- =============================================================================
create table if not exists public.lab_centrifuge_r3179 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  lab_section text not null,
  device_asset_tag text not null,
  device_model text not null,
  device_type text not null check (device_type in (
    'centrifuge','refrigerated_centrifuge','microcentrifuge','incubator',
    'co2_incubator','shaker_incubator','orbital_shaker','water_bath','dry_bath','hematology_mixer'
  )),
  calibration_date date not null,
  calibrated_at timestamptz not null,
  set_rpm int,
  measured_rpm int,
  rpm_error_pct numeric(5,2),
  set_temperature_c numeric(5,2),
  measured_temperature_c numeric(5,2),
  temp_error_pct numeric(5,2),
  timer_set_seconds int,
  timer_measured_seconds int,
  timer_accuracy_verdict text not null check (timer_accuracy_verdict in (
    'within_tolerance','out_of_tolerance','not_tested','not_applicable'
  )),
  rotor_integrity text not null check (rotor_integrity in (
    'intact','minor_corrosion','crack_detected','imbalance_detected','not_applicable'
  )),
  lid_interlock_status text not null check (lid_interlock_status in (
    'functional','sluggish','failed','bypassed','not_applicable'
  )),
  calibration_verdict text not null check (calibration_verdict in (
    'passed','passed_with_deviation','failed','quarantined','recalibration_required','pending_review'
  )),
  next_due_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lab_centrifuge_r3179 enable row level security;

create index if not exists idx_lab_centrifuge_r3179_org on public.lab_centrifuge_r3179(organization_id);
create index if not exists idx_lab_centrifuge_r3179_date on public.lab_centrifuge_r3179(calibration_date);
create index if not exists idx_lab_centrifuge_r3179_verdict on public.lab_centrifuge_r3179(calibration_verdict);

-- =============================================================================
-- TABLE 2: lab_centrifuge_capa_actions_r3179 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.lab_centrifuge_capa_actions_r3179 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.lab_centrifuge_r3179(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'rpm_deviation','temperature_deviation','timer_inaccuracy','rotor_corrosion','rotor_crack',
    'lid_interlock_failure','imbalance_cutoff_fail','calibration_overdue','sensor_drift','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'tachometer_drift','temperature_sensor_drift','motor_brush_wear','rotor_fatigue','door_switch_worn',
    'control_board_fault','ambient_temp_fluctuation','operator_overload','calibration_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_tachometer','recalibrate_temperature_sensor','replace_rotor','replace_motor_brushes',
    'replace_door_switch','replace_control_board','retrain_operator','quarantine_device','schedule_amc_visit','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cap_deviation','iso_15189_deviation','internal_only','patient_safety_alert','none'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lab_centrifuge_capa_actions_r3179 enable row level security;

create index if not exists idx_lab_centrifuge_capa_r3179_audit on public.lab_centrifuge_capa_actions_r3179(audit_id);
create index if not exists idx_lab_centrifuge_capa_r3179_status on public.lab_centrifuge_capa_actions_r3179(capa_status);

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

  -- 14 calibration audit rows
  insert into public.lab_centrifuge_r3179 (
    organization_id, hospital_name, lab_section, device_asset_tag, device_model,
    device_type, calibration_date, calibrated_at,
    set_rpm, measured_rpm, rpm_error_pct,
    set_temperature_c, measured_temperature_c, temp_error_pct,
    timer_set_seconds, timer_measured_seconds, timer_accuracy_verdict,
    rotor_integrity, lid_interlock_status,
    calibration_verdict, next_due_date, notes
  )
  select v_org_id, q.hosp, q.sec, q.tag, q.model,
    q.dt, q.cd::date, q.ca::timestamptz,
    q.srpm, q.mrpm, q.rerr,
    q.stemp, q.mtemp, q.terr,
    q.tset, q.tmeas, q.tv,
    q.ri, q.li,
    q.cv, q.nd::date, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Biochemistry','CFG-APL-101','Eppendorf 5810R','centrifuge','2026-07-02','2026-07-02 09:15:00+05:30',4000,3980,0.50,null,null,null,600,598,'within_tolerance','intact','functional','passed','2027-01-02','Annual calibration — all parameters within spec'),
    ('Apollo Hyderabad Jubilee Hills','Hematology','CFG-APL-102','Thermo Megafuge ST4','refrigerated_centrifuge','2026-07-02','2026-07-02 10:30:00+05:30',3500,3430,2.00,4.00,4.30,7.50,900,896,'within_tolerance','intact','functional','passed_with_deviation','2027-01-02','Temp +0.3C at 4C setpoint — within deviation band'),
    ('Fortis Bannerghatta Bengaluru','Microbiology','INC-FRT-201','Memmert INB400','incubator','2026-07-01','2026-07-01 08:45:00+05:30',null,null,null,37.00,37.10,0.27,null,null,'not_applicable','not_applicable','not_applicable','passed','2027-01-01','Bacteriology incubator holding 37C stable'),
    ('Fortis Bannerghatta Bengaluru','Molecular Lab','CFG-FRT-202','Eppendorf 5424','microcentrifuge','2026-07-01','2026-07-01 11:10:00+05:30',15000,14100,6.00,null,null,null,300,315,'out_of_tolerance','intact','functional','failed','2026-07-15','Speed 6% low + timer +15s — failed, tachometer recalibration required'),
    ('Manipal Whitefield Bengaluru','Blood Bank','CFG-MNP-301','Hettich Rotixa 500','refrigerated_centrifuge','2026-06-30','2026-06-30 09:00:00+05:30',3000,2950,1.67,4.00,4.20,5.00,600,599,'within_tolerance','crack_detected','functional','quarantined','2026-07-10','Hairline rotor crack found — component quarantined pending replacement'),
    ('Manipal Whitefield Bengaluru','Microbiology','SHK-MNP-302','New Brunswick Innova 44','shaker_incubator','2026-06-30','2026-06-30 12:20:00+05:30',200,198,1.00,37.00,37.20,0.54,null,null,'not_applicable','not_applicable','not_applicable','passed','2027-06-30','Orbital speed and chamber temp within spec'),
    ('AIIMS New Delhi Ansari Nagar','Central Diagnostic Lab','CFG-AIM-401','Beckman Allegra X-30','centrifuge','2026-06-29','2026-06-29 10:05:00+05:30',4000,3990,0.25,null,null,null,600,640,'out_of_tolerance','intact','functional','recalibration_required','2026-07-06','Timer +40s at 10min — recalibration of control timer required'),
    ('AIIMS New Delhi Ansari Nagar','Molecular Lab','INC-AIM-402','Thermo Heracell 150i','co2_incubator','2026-06-29','2026-06-29 13:40:00+05:30',null,null,null,37.00,37.00,0.00,null,null,'not_applicable','not_applicable','not_applicable','passed','2027-06-29','CO2 incubator temp exact at setpoint'),
    ('KIMS Secunderabad','Hematology','CFG-KIM-501','Remi C-24 Plus','centrifuge','2026-06-28','2026-06-28 09:30:00+05:30',3500,3480,0.57,null,null,null,600,601,'within_tolerance','intact','failed','failed','2026-07-04','Lid interlock failed — lid can open during spin, device tagged out of service'),
    ('KIMS Secunderabad','Biochemistry','WBH-KIM-502','Julabo TW12','water_bath','2026-06-28','2026-06-28 11:50:00+05:30',null,null,null,37.00,38.10,2.97,null,null,'not_applicable','not_applicable','not_applicable','passed_with_deviation','2026-12-28','Water bath +1.1C high — sensor recalibration recommended'),
    ('Care Hospitals Banjara Hills','Blood Bank','CFG-CAR-601','Hettich Rotanta 460R','refrigerated_centrifuge','2026-06-27','2026-06-27 08:20:00+05:30',3000,2985,0.50,4.00,4.10,2.50,600,600,'within_tolerance','intact','functional','passed','2026-12-27','Blood-bank centrifuge fully within tolerance'),
    ('Yashoda Somajiguda Hyderabad','Microbiology','SHK-YSH-701','Remi RIS-24 Plus','orbital_shaker','2026-06-27','2026-06-27 14:10:00+05:30',250,247,1.20,null,null,null,null,null,'not_applicable','not_applicable','not_applicable','passed','2027-06-27','Orbital shaker speed within 1.2% of setpoint'),
    ('St John''s Bengaluru','IVF Lab','INC-STJ-801','Esco Miri CO2','co2_incubator','2026-06-26','2026-06-26 09:55:00+05:30',null,null,null,37.00,36.60,1.08,null,null,'not_applicable','not_applicable','not_applicable','pending_review','2026-09-26','IVF incubator -0.4C — embryology review pending before release'),
    ('Rainbow Children''s Hyderabad','Hematology','CFG-RBW-901','Remi R-8C','refrigerated_centrifuge','2026-06-26','2026-06-26 12:35:00+05:30',3000,2900,3.33,4.00,4.40,10.00,600,605,'within_tolerance','imbalance_detected','functional','quarantined','2026-07-12','Imbalance cutoff trips early + speed 3.3% low — quarantined for motor service')
  ) as q(hosp, sec, tag, model, dt, cd, ca, srpm, mrpm, rerr, stemp, mtemp, terr, tset, tmeas, tv, ri, li, cv, nd, nt);

  -- CAPA seed — attach to specific audited devices by asset tag
  insert into public.lab_centrifuge_capa_actions_r3179 (
    audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('CFG-FRT-202','rpm_deviation','tachometer_drift','recalibrate_tachometer','2026-07-08',null,'in_progress','nabl_finding',8500.00,'Microcentrifuge 6% over-speed at 15k — tachometer recalibration scheduled'),
    ('CFG-MNP-301','rotor_crack','rotor_fatigue','replace_rotor','2026-07-06',null,'escalated','patient_safety_alert',62000.00,'Hairline crack on swing-out rotor — device quarantined, rotor on order'),
    ('CFG-AIM-401','timer_inaccuracy','control_board_fault','replace_control_board','2026-07-05','2026-07-03','closed','nabh_finding',18500.00,'Timer +40s at 10min — control board replaced and reverified'),
    ('CFG-KIM-501','lid_interlock_failure','door_switch_worn','replace_door_switch','2026-07-04',null,'open','patient_safety_alert',4500.00,'Lid opens during spin — interlock microswitch failed, device tagged out'),
    ('WBH-KIM-502','temperature_deviation','temperature_sensor_drift','recalibrate_temperature_sensor','2026-07-07',null,'verification_pending','iso_15189_deviation',3200.00,'Water bath +1.1C at 37C — PT100 sensor recalibrated, awaiting verification'),
    ('CFG-RBW-901','imbalance_cutoff_fail','motor_brush_wear','replace_motor_brushes','2026-07-09',null,'in_progress','nabl_finding',9800.00,'Imbalance cutoff trips early — worn motor brushes causing vibration')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.lab_centrifuge_r3179 e
    on e.organization_id = v_org_id and e.device_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Calibration verdict distribution
create or replace function public.founder_r3179_calibration_verdict_rollup()
returns table(calibration_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lab_centrifuge_r3179)
  select l.calibration_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.lab_centrifuge_r3179 l
  group by l.calibration_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3179_calibration_verdict_rollup() from public, anon;
grant execute on function public.founder_r3179_calibration_verdict_rollup() to authenticated;

-- 2) Hospital-level calibration scorecard
create or replace function public.founder_r3179_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  deviations bigint,
  failed bigint,
  quarantined bigint,
  recal_required bigint,
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
    count(*) filter (where l.calibration_verdict = 'passed')::bigint,
    count(*) filter (where l.calibration_verdict = 'passed_with_deviation')::bigint,
    count(*) filter (where l.calibration_verdict = 'failed')::bigint,
    count(*) filter (where l.calibration_verdict = 'quarantined')::bigint,
    count(*) filter (where l.calibration_verdict = 'recalibration_required')::bigint,
    round(100.0 * count(*) filter (where l.calibration_verdict in ('passed','passed_with_deviation'))::numeric / nullif(count(*),0), 1)
  from public.lab_centrifuge_r3179 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3179_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3179_hospital_scorecard() to authenticated;

-- 3) Device-type performance matrix
create or replace function public.founder_r3179_device_type_matrix()
returns table(device_type text, audits bigint, passed bigint, avg_rpm_error numeric, avg_temp_error numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, count(*)::bigint,
    count(*) filter (where l.calibration_verdict in ('passed','passed_with_deviation'))::bigint,
    round(avg(l.rpm_error_pct), 2),
    round(avg(l.temp_error_pct), 2)
  from public.lab_centrifuge_r3179 l
  group by l.device_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3179_device_type_matrix() from public, anon;
grant execute on function public.founder_r3179_device_type_matrix() to authenticated;

-- 4) Calibration daily trend
create or replace function public.founder_r3179_calibration_daily_trend()
returns table(calibration_date date, audits bigint, passed bigint, failed bigint, quarantined bigint, deviations bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.calibration_date,
    count(*)::bigint,
    count(*) filter (where l.calibration_verdict = 'passed')::bigint,
    count(*) filter (where l.calibration_verdict = 'failed')::bigint,
    count(*) filter (where l.calibration_verdict = 'quarantined')::bigint,
    count(*) filter (where l.calibration_verdict = 'passed_with_deviation')::bigint
  from public.lab_centrifuge_r3179 l
  group by l.calibration_date
  order by l.calibration_date desc;
end;
$$;

revoke execute on function public.founder_r3179_calibration_daily_trend() from public, anon;
grant execute on function public.founder_r3179_calibration_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3179_capa_status_board()
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
  from public.lab_centrifuge_capa_actions_r3179 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3179_capa_status_board() from public, anon;
grant execute on function public.founder_r3179_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3179_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lab_centrifuge_capa_actions_r3179)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.lab_centrifuge_capa_actions_r3179 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3179_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3179_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3179_regulatory_impact_digest()
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
  from public.lab_centrifuge_capa_actions_r3179 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3179_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3179_regulatory_impact_digest() to authenticated;

-- 8) High-risk device priority queue
create or replace function public.founder_r3179_high_risk_queue()
returns table(
  hospital_name text,
  lab_section text,
  device_asset_tag text,
  device_type text,
  calibration_date date,
  calibration_verdict text,
  rpm_error_pct numeric,
  temp_error_pct numeric,
  rotor_integrity text,
  lid_interlock_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.lab_section, l.device_asset_tag, l.device_type, l.calibration_date,
    l.calibration_verdict, l.rpm_error_pct, l.temp_error_pct, l.rotor_integrity, l.lid_interlock_status, l.notes
  from public.lab_centrifuge_r3179 l
  where l.calibration_verdict in ('failed','quarantined','recalibration_required','pending_review','passed_with_deviation')
     or l.rotor_integrity in ('crack_detected','imbalance_detected','minor_corrosion')
     or l.lid_interlock_status in ('failed','sluggish','bypassed')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3179_high_risk_queue() from public, anon;
grant execute on function public.founder_r3179_high_risk_queue() to authenticated;
