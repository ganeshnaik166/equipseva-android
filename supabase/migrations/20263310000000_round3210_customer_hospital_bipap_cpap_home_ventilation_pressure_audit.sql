-- Round 3210: Customer Hospital BiPAP/CPAP & Home-Ventilation Device Pressure-Accuracy Audit
-- NIV / home-vent QA log — device type × set vs measured IPAP/EPAP × pressure error % × mask leak × humidifier × filter × ramp × CAPA

-- =============================================================================
-- TABLE 1: bipap_cpap_r3210 — individual device pressure-accuracy audits
-- =============================================================================
create table if not exists public.bipap_cpap_r3210 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ward_code text not null,
  device_asset_tag text not null,
  device_model text not null,
  device_type text not null check (device_type in (
    'cpap','bipap','hfnc','home_ventilator'
  )),
  audit_date date not null,
  audited_at timestamptz not null,
  set_ipap_cmh2o numeric(5,2),
  set_epap_cmh2o numeric(5,2),
  measured_ipap_cmh2o numeric(5,2),
  measured_epap_cmh2o numeric(5,2),
  pressure_error_pct numeric(5,2),
  mask_type text check (mask_type in (
    'full_face','nasal','nasal_pillow','oronasal_vented','helmet','tracheostomy_interface','not_applicable'
  )),
  mask_leak_lpm numeric(5,2),
  leak_verdict text check (leak_verdict in ('within_limit','excessive','gross_leak','not_measured')),
  humidifier_temp_c numeric(4,1),
  humidifier_status text check (humidifier_status in (
    'working','over_temperature','under_temperature','not_fitted','faulty'
  )),
  filter_condition text not null check (filter_condition in (
    'clean','due_replacement','clogged','missing','replaced_during_audit'
  )),
  ramp_function_ok boolean not null default true,
  audit_verdict text not null check (audit_verdict in (
    'pass','recalibrate','service_required','condemned','pending_review','conditional_pass'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bipap_cpap_r3210 enable row level security;

create index if not exists idx_bipap_cpap_r3210_org on public.bipap_cpap_r3210(organization_id);
create index if not exists idx_bipap_cpap_r3210_date on public.bipap_cpap_r3210(audit_date);
create index if not exists idx_bipap_cpap_r3210_verdict on public.bipap_cpap_r3210(audit_verdict);

-- =============================================================================
-- TABLE 2: bipap_cpap_capa_actions_r3210 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.bipap_cpap_capa_actions_r3210 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.bipap_cpap_r3210(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'pressure_drift','excessive_mask_leak','humidifier_fault','filter_clogged',
    'ramp_failure','blower_wear','alarm_failure','hose_condensation','operator_error','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'blower_motor_worn','pressure_sensor_drift','mask_cushion_degraded',
    'hose_pinhole_leak','humidifier_plate_scaled','filter_overdue_replacement',
    'patient_setup_error','firmware_bug','power_adapter_fault','pending_investigation','service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_pressure_sensor','replace_blower_assembly','replace_mask_cushion',
    'replace_hose','descale_humidifier_plate','replace_filters','retrain_caregiver',
    'firmware_update','replace_power_adapter','condemn_device','schedule_amc_visit','none_required'
  )),
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

alter table public.bipap_cpap_capa_actions_r3210 enable row level security;

create index if not exists idx_bipap_capa_r3210_audit on public.bipap_cpap_capa_actions_r3210(audit_id);
create index if not exists idx_bipap_capa_r3210_status on public.bipap_cpap_capa_actions_r3210(capa_status);

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

  -- 14 audit rows
  insert into public.bipap_cpap_r3210 (
    organization_id, hospital_name, ward_code, device_asset_tag, device_model, device_type,
    audit_date, audited_at,
    set_ipap_cmh2o, set_epap_cmh2o, measured_ipap_cmh2o, measured_epap_cmh2o, pressure_error_pct,
    mask_type, mask_leak_lpm, leak_verdict,
    humidifier_temp_c, humidifier_status, filter_condition, ramp_function_ok,
    audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ward, q.tag, q.model, q.dt,
    q.ad::date, q.at_ts::timestamptz,
    q.sip, q.sep, q.mip, q.mep, q.perr,
    q.mask, q.leak, q.lv,
    q.ht, q.hstat, q.fc, q.ramp,
    q.av, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU-4','BP-APL-101','ResMed AirCurve 10 VAuto','bipap','2026-07-02','2026-07-02 09:10:00+05:30',
     16.00,6.00,15.80,6.10,-1.25,'full_face',18.50,'within_limit',31.0,'working','clean',true,'pass','IPAP within plus-minus 5 percent tolerance'),
    ('Apollo Hyderabad Jubilee Hills','HOME-CARE','CP-APL-118','Philips DreamStation 2','cpap','2026-07-02','2026-07-02 11:40:00+05:30',
     10.00,10.00,9.40,9.40,-6.00,'nasal',24.00,'within_limit',27.5,'working','due_replacement',true,'recalibrate','Pressure reads 6 percent low — recalibration booked'),
    ('Fortis Bannerghatta Bengaluru','RESP-2','BP-FRT-052','ResMed Lumis 150','bipap','2026-07-01','2026-07-01 08:20:00+05:30',
     18.00,8.00,17.90,7.95,-0.56,'oronasal_vented',45.00,'excessive',30.0,'working','clean',true,'service_required','Mask leak 45 L/min — cushion degraded'),
    ('Fortis Bannerghatta Bengaluru','HOME-CARE','HV-FRT-009','Loewenstein Prisma VENT40','home_ventilator','2026-07-01','2026-07-01 10:05:00+05:30',
     22.00,6.00,20.60,5.70,-6.36,'tracheostomy_interface',12.00,'within_limit',34.0,'working','clogged',false,'service_required','Blower wear suspected; ramp failed self-test'),
    ('Manipal Whitefield Bengaluru','NICU-1','HF-MNP-014','Fisher and Paykel Airvo 2','hfnc','2026-06-30','2026-06-30 09:00:00+05:30',
     null,null,null,null,null,'not_applicable',null,'not_measured',37.0,'working','clean',true,'pass','HFNC flow and temperature nominal'),
    ('Manipal Whitefield Bengaluru','RESP-1','CP-MNP-030','ResMed AirSense 11','cpap','2026-06-30','2026-06-30 11:30:00+05:30',
     8.00,8.00,8.05,8.02,0.63,'nasal_pillow',20.00,'within_limit',28.0,'working','replaced_during_audit',true,'pass','Filter swapped during audit'),
    ('AIIMS New Delhi Ansari Nagar','PULMO-3','BP-AIM-076','Philips BiPAP A40','bipap','2026-06-29','2026-06-29 08:45:00+05:30',
     20.00,8.00,17.20,7.10,-14.00,'full_face',52.00,'gross_leak',24.0,'under_temperature','clogged',false,'condemned','14 percent pressure error plus gross leak — device condemned'),
    ('AIIMS New Delhi Ansari Nagar','PULMO-3','BP-AIM-081','ResMed Stellar 150','bipap','2026-06-29','2026-06-29 10:15:00+05:30',
     18.00,7.00,18.10,7.05,0.56,'oronasal_vented',16.00,'within_limit',32.0,'working','clean',true,'pass','Routine annual pressure audit'),
    ('KIMS Secunderabad','ICU-2','HV-KIM-005','ResMed Astral 150','home_ventilator','2026-06-28','2026-06-28 09:30:00+05:30',
     24.00,6.00,23.50,5.90,-2.08,'tracheostomy_interface',8.00,'within_limit',35.5,'working','due_replacement',true,'conditional_pass','Pass pending filter replacement this week'),
    ('KIMS Secunderabad','HOME-CARE','CP-KIM-041','BMC RESmart G2','cpap','2026-06-28','2026-06-28 12:00:00+05:30',
     12.00,12.00,11.10,11.05,-7.50,'nasal',30.00,'excessive',39.0,'over_temperature','clean',true,'recalibrate','Humidifier plate over-temperature at 39C; sensor drift'),
    ('Care Hospitals Banjara Hills','RESP-1','BP-CAR-022','Philips DreamStation BiPAP autoSV','bipap','2026-06-27','2026-06-27 09:20:00+05:30',
     15.00,5.00,15.10,5.05,0.67,'helmet',22.00,'within_limit',30.5,'working','clean',true,'pass','ASV mode verified against analyser'),
    ('Yashoda Somajiguda Hyderabad','PULMO-1','CP-YSH-063','ResMed AirSense 10','cpap','2026-06-27','2026-06-27 11:10:00+05:30',
     9.00,9.00,8.10,8.15,-10.00,'nasal',26.00,'within_limit',26.5,'faulty','missing',true,'service_required','Humidifier not heating; inlet filter missing'),
    ('St John''s Bengaluru','HOME-CARE','HV-STJ-002','Breas Vivo 45','home_ventilator','2026-06-26','2026-06-26 08:40:00+05:30',
     20.00,5.00,null,null,null,'tracheostomy_interface',null,'not_measured',null,'not_fitted','clean',false,'pending_review','Pressure analyser unavailable — audit incomplete'),
    ('Rainbow Children''s Hyderabad','PICU-2','BP-RBW-017','Philips Trilogy Evo','bipap','2026-06-26','2026-06-26 10:30:00+05:30',
     14.00,5.00,13.90,4.95,-0.71,'nasal',15.00,'within_limit',33.0,'working','clean',true,'pass','Paediatric NIV audit clear')
  ) as q(hosp, ward, tag, model, dt, ad, at_ts, sip, sep, mip, mep, perr, mask, leak, lv, ht, hstat, fc, ramp, av, nt);

  -- CAPA seed — attach to specific audited devices
  insert into public.bipap_cpap_capa_actions_r3210 (
    audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('CP-APL-118','pressure_drift','pressure_sensor_drift','recalibrate_pressure_sensor','2026-07-08',null,'in_progress','internal_only',4500.00,'Bench recalibration against calibrated manometer'),
    ('BP-FRT-052','excessive_mask_leak','mask_cushion_degraded','replace_mask_cushion','2026-07-06','2026-07-03','closed','none',2800.00,'Cushion replaced; leak now 14 L/min'),
    ('HV-FRT-009','blower_wear','blower_motor_worn','replace_blower_assembly','2026-07-12',null,'escalated','patient_safety_alert',36000.00,'Home ventilator swapped with standby unit'),
    ('BP-AIM-076','pressure_drift','blower_motor_worn','condemn_device','2026-07-05',null,'verification_pending','cdsco_notifiable',0.00,'Condemnation certificate awaiting biomedical HOD sign-off'),
    ('CP-KIM-041','humidifier_fault','humidifier_plate_scaled','descale_humidifier_plate','2026-07-09',null,'open','iso_13485_deviation',1200.00,'Hard-water scaling on heater plate'),
    ('CP-YSH-063','filter_clogged','filter_overdue_replacement','replace_filters','2026-07-01',null,'overdue','nabh_finding',900.00,'Filter kit stockout at ward store'),
    ('HV-STJ-002','preventive_maintenance_due','service_backlog','schedule_amc_visit','2026-07-15',null,'open','internal_only',15000.00,'Annual PM with pressure analyser to be scheduled')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.bipap_cpap_r3210 e
    on e.organization_id = v_org_id and e.device_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3210_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bipap_cpap_r3210)
  select a.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.bipap_cpap_r3210 a
  group by a.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3210_verdict_rollup() from public, anon;
grant execute on function public.founder_r3210_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3210_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  recalibrations bigint,
  service_needed bigint,
  condemned bigint,
  gross_leaks bigint,
  avg_abs_error_pct numeric,
  compliance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name,
    count(*)::bigint,
    count(*) filter (where a.audit_verdict = 'pass')::bigint,
    count(*) filter (where a.audit_verdict = 'recalibrate')::bigint,
    count(*) filter (where a.audit_verdict = 'service_required')::bigint,
    count(*) filter (where a.audit_verdict = 'condemned')::bigint,
    count(*) filter (where a.leak_verdict = 'gross_leak')::bigint,
    round(avg(abs(a.pressure_error_pct)), 2),
    round(100.0 * count(*) filter (where a.audit_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.bipap_cpap_r3210 a
  group by a.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3210_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3210_hospital_scorecard() to authenticated;

-- 3) Device type × mask type matrix
create or replace function public.founder_r3210_device_mask_matrix()
returns table(device_type text, mask_type text, audits bigint, passed bigint, avg_abs_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.device_type, a.mask_type, count(*)::bigint,
    count(*) filter (where a.audit_verdict = 'pass')::bigint,
    round(avg(abs(a.pressure_error_pct)), 2)
  from public.bipap_cpap_r3210 a
  group by a.device_type, a.mask_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3210_device_mask_matrix() from public, anon;
grant execute on function public.founder_r3210_device_mask_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3210_daily_trend()
returns table(audit_date date, audits bigint, passed bigint, pressure_faults bigint, leak_faults bigint, ramp_failures bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_date,
    count(*)::bigint,
    count(*) filter (where a.audit_verdict = 'pass')::bigint,
    count(*) filter (where abs(a.pressure_error_pct) > 5)::bigint,
    count(*) filter (where a.leak_verdict in ('excessive','gross_leak'))::bigint,
    count(*) filter (where not a.ramp_function_ok)::bigint
  from public.bipap_cpap_r3210 a
  group by a.audit_date
  order by a.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3210_daily_trend() from public, anon;
grant execute on function public.founder_r3210_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3210_capa_status_board()
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
  from public.bipap_cpap_capa_actions_r3210 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3210_capa_status_board() from public, anon;
grant execute on function public.founder_r3210_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3210_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bipap_cpap_capa_actions_r3210)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.bipap_cpap_capa_actions_r3210 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3210_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3210_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3210_regulatory_impact_digest()
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
  from public.bipap_cpap_capa_actions_r3210 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3210_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3210_regulatory_impact_digest() to authenticated;

-- 8) High-risk devices queue (top individual concerns)
create or replace function public.founder_r3210_high_risk_devices()
returns table(
  hospital_name text,
  ward_code text,
  device_asset_tag text,
  device_type text,
  audit_date date,
  audit_verdict text,
  pressure_error_pct numeric,
  leak_verdict text,
  filter_condition text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.ward_code, a.device_asset_tag, a.device_type, a.audit_date,
    a.audit_verdict, a.pressure_error_pct, a.leak_verdict, a.filter_condition, a.notes
  from public.bipap_cpap_r3210 a
  where a.audit_verdict in ('recalibrate','service_required','condemned','pending_review','conditional_pass')
     or a.leak_verdict in ('excessive','gross_leak')
     or abs(a.pressure_error_pct) > 5
     or a.filter_condition in ('clogged','missing')
     or not a.ramp_function_ok
  order by a.audit_date desc, a.hospital_name;
end;
$$;

revoke execute on function public.founder_r3210_high_risk_devices() from public, anon;
grant execute on function public.founder_r3210_high_risk_devices() to authenticated;
