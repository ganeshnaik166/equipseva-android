-- Round 3355: Customer Hospital Lab Water-Purification, Fume-Hood & Chemical-Storage QC Audit
-- Lab support-infra QC — unit type × water resistivity/TDS × filter cartridge × UV lamp × fume-hood face velocity × storage ventilation × spill containment × microbial × calibration × CAPA

-- =============================================================================
-- TABLE 1: lab_infra_qc_r3355 — per-unit lab support-infrastructure QC checks
-- =============================================================================
create table if not exists public.lab_infra_qc_r3355 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  unit_code text not null,
  unit_type text not null check (unit_type in (
    'type1_ultrapure_water','ro_water_system','deionizer','fume_hood',
    'chemical_storage_cabinet','reagent_refrigerator'
  )),
  lab_section text not null,
  check_date date not null,
  water_resistivity_mohm numeric(5,2),
  tds_ppm numeric(6,2),
  filter_cartridge_status text not null check (filter_cartridge_status in (
    'fresh','due_soon','overdue','not_applicable'
  )),
  uv_lamp_ok text not null check (uv_lamp_ok in (
    'ok','degraded','not_applicable'
  )),
  fume_hood_face_velocity_ok text not null check (fume_hood_face_velocity_ok in (
    'ok','low','fail','not_applicable'
  )),
  storage_ventilation_ok boolean not null,
  spill_containment_ok boolean not null,
  microbial_test_ok text not null check (microbial_test_ok in (
    'pass','fail','not_run','not_applicable'
  )),
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lab_infra_qc_r3355 enable row level security;

create index if not exists idx_lab_infra_qc_r3355_org on public.lab_infra_qc_r3355(organization_id);
create index if not exists idx_lab_infra_qc_r3355_date on public.lab_infra_qc_r3355(check_date);
create index if not exists idx_lab_infra_qc_r3355_verdict on public.lab_infra_qc_r3355(qc_verdict);

-- =============================================================================
-- TABLE 2: lab_infra_qc_capa_actions_r3355 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.lab_infra_qc_capa_actions_r3355 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.lab_infra_qc_r3355(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'water_quality_out_of_spec','filter_cartridge_overdue','uv_lamp_degraded',
    'fume_hood_low_face_velocity','storage_ventilation_failure','spill_containment_failure',
    'microbial_contamination','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'filter_saturation','ro_membrane_fouling','uv_lamp_end_of_life','resin_bed_exhausted',
    'blower_belt_worn','sash_seal_leak','ventilation_fan_failure','containment_tray_cracked',
    'biofilm_growth','calibration_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_filter_cartridge','replace_ro_membrane','replace_uv_lamp','regenerate_resin_bed',
    'service_fume_hood_blower','repair_sash_seal','replace_ventilation_fan','replace_containment_tray',
    'sanitize_and_flush_system','recalibrate_instrument','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','nabl_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lab_infra_qc_capa_actions_r3355 enable row level security;

create index if not exists idx_lab_infra_capa_r3355_log on public.lab_infra_qc_capa_actions_r3355(qc_log_id);
create index if not exists idx_lab_infra_capa_r3355_status on public.lab_infra_qc_capa_actions_r3355(capa_status);

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
  insert into public.lab_infra_qc_r3355 (
    organization_id, hospital_name, unit_code, unit_type, lab_section, check_date,
    water_resistivity_mohm, tds_ppm, filter_cartridge_status, uv_lamp_ok,
    fume_hood_face_velocity_ok, storage_ventilation_ok, spill_containment_ok,
    microbial_test_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.ucode, q.utype, q.lsec, q.cdate::date,
    q.res, q.tds, q.fcs, q.uv,
    q.fhv, q.sv, q.sc,
    q.mt, q.cal, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','WPS-APL-01','type1_ultrapure_water','Microbiology','2026-07-10',
     18.20,0.50,'fresh','ok','not_applicable',true,true,'pass',true,'pass','Type-1 Milli-Q 18.2 MOhm-cm, all parameters nominal'),
    ('Apollo Chennai Greams Road','WPS-APL-02','ro_water_system','Biochemistry','2026-07-10',
     0.08,12.00,'due_soon','ok','not_applicable',true,true,'pass',true,'conditional_pass','RO pre-filter due soon, TDS 12 ppm within analyser tolerance'),
    ('Fortis Gurgaon','FH-FRT-11','fume_hood','Histopathology','2026-07-09',
     null,null,'not_applicable','not_applicable','ok',true,true,'not_applicable',true,'pass','Face velocity 0.52 m/s nominal, sash alarm functional'),
    ('Fortis Gurgaon','FH-FRT-12','fume_hood','Microbiology','2026-07-09',
     null,null,'not_applicable','not_applicable','low',true,true,'not_applicable',true,'conditional_pass','Face velocity 0.35 m/s below 0.4 floor, blower on watch'),
    ('Manipal Bengaluru Old Airport Road','WPS-MNP-01','type1_ultrapure_water','Molecular Lab','2026-07-08',
     17.90,0.80,'overdue','degraded','not_applicable',true,true,'fail',true,'fail','UV lamp degraded, filter overdue, microbial fail, loop flush ordered'),
    ('Manipal Bengaluru Old Airport Road','DI-MNP-02','deionizer','Biochemistry','2026-07-08',
     2.50,3.00,'due_soon','not_applicable','not_applicable',true,true,'pass',true,'conditional_pass','Resin bed nearing exhaustion, resistivity trending down'),
    ('AIIMS Delhi Ansari Nagar','CSC-AIM-01','chemical_storage_cabinet','Toxicology','2026-07-07',
     null,null,'not_applicable','not_applicable','not_applicable',false,true,'not_applicable',true,'fail','Flammables cabinet ventilation fan failed, solvent vapours detected'),
    ('AIIMS Delhi Ansari Nagar','RRF-AIM-02','reagent_refrigerator','Blood Bank','2026-07-07',
     null,null,'not_applicable','not_applicable','not_applicable',true,true,'not_applicable',false,'conditional_pass','Reagent fridge temp calibration overdue, chart recorder drift'),
    ('CMC Vellore','WPS-CMC-01','type1_ultrapure_water','Microbiology','2026-07-06',
     18.10,0.40,'fresh','ok','not_applicable',true,true,'pass',true,'pass','Annual QC clean pass, endotoxin below limit'),
    ('CMC Vellore','FH-CMC-02','fume_hood','Histopathology','2026-07-06',
     null,null,'not_applicable','not_applicable','fail',true,true,'not_applicable',true,'removed_from_service','Face velocity 0.15 m/s, blower belt broken, hood tagged out'),
    ('KIMS Hyderabad','RO-KIM-01','ro_water_system','Dialysis Lab','2026-07-05',
     0.05,18.00,'overdue','ok','not_applicable',true,true,'fail',true,'fail','RO membrane fouled, microbial fail, sanitize and flush scheduled'),
    ('KIMS Hyderabad','CSC-KIM-02','chemical_storage_cabinet','Chemistry','2026-07-05',
     null,null,'not_applicable','not_applicable','not_applicable',true,false,'not_applicable',true,'conditional_pass','Spill containment tray cracked, replacement tray ordered'),
    ('Yashoda Hyderabad Somajiguda','RRF-YSH-01','reagent_refrigerator','Immunoassay','2026-07-04',
     null,null,'not_applicable','not_applicable','not_applicable',true,true,'not_applicable',true,'pass','Reagent fridge 4.2C within range, calibration current'),
    ('Narayana Health Bengaluru','DI-NAR-01','deionizer','Biochemistry','2026-07-04',
     1.20,6.50,'due_soon','not_applicable','not_applicable',true,true,'not_run',true,'conditional_pass','Resistivity 1.2 MOhm low for polishing loop, microbial not run')
  ) as q(hosp, ucode, utype, lsec, cdate, res, tds, fcs, uv, fhv, sv, sc, mt, cal, qv, nt);

  -- CAPA seed — attach to specific checks via unit_code
  insert into public.lab_infra_qc_capa_actions_r3355 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('WPS-MNP-01','microbial_contamination','biofilm_growth','sanitize_and_flush_system','in_progress','patient_safety_alert','2026-07-14',null,22000.00,'Loop sanitized, UV lamp replaced, awaiting re-culture'),
    ('FH-CMC-02','fume_hood_low_face_velocity','blower_belt_worn','service_fume_hood_blower','open','nabh_finding','2026-07-13',null,15000.00,'Hood tagged out of service, blower belt on order'),
    ('CSC-AIM-01','storage_ventilation_failure','ventilation_fan_failure','replace_ventilation_fan','escalated','cdsco_notifiable','2026-07-11',null,34000.00,'Flammables cabinet fan failed, escalated to facilities and safety'),
    ('RO-KIM-01','water_quality_out_of_spec','ro_membrane_fouling','replace_ro_membrane','in_progress','nabl_finding','2026-07-12',null,48000.00,'RO membrane replacement scheduled, interim bottled ultrapure water'),
    ('WPS-APL-02','filter_cartridge_overdue','filter_saturation','replace_filter_cartridge','closed','internal_only','2026-07-12','2026-07-11',6000.00,'Pre-filter replaced, TDS back down to 8 ppm'),
    ('RRF-AIM-02','calibration_overdue','calibration_backlog','recalibrate_instrument','verification_pending','iso_15189_deviation','2026-07-10',null,4500.00,'Reagent fridge recalibrated, verifying 24h temperature log'),
    ('CSC-KIM-02','spill_containment_failure','containment_tray_cracked','replace_containment_tray','overdue','internal_only','2026-07-06',null,3000.00,'Replacement tray delayed by vendor, past target closure date')
  ) as q(ucode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.lab_infra_qc_r3355 e
    on e.organization_id = v_org_id and e.unit_code = q.ucode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3355_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lab_infra_qc_r3355)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.lab_infra_qc_r3355 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3355_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3355_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3355_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  filter_overdue bigint,
  microbial_fail bigint,
  fume_hood_fail bigint,
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
    count(*) filter (where l.filter_cartridge_status = 'overdue')::bigint,
    count(*) filter (where l.microbial_test_ok = 'fail')::bigint,
    count(*) filter (where l.fume_hood_face_velocity_ok in ('low','fail'))::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.lab_infra_qc_r3355 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3355_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3355_hospital_scorecard() to authenticated;

-- 3) Unit type × lab section matrix
create or replace function public.founder_r3355_unit_section_matrix()
returns table(unit_type text, lab_section text, checks bigint, passed bigint, avg_resistivity_mohm numeric, avg_tds_ppm numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.unit_type, l.lab_section, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.water_resistivity_mohm), 2),
    round(avg(l.tds_ppm), 2)
  from public.lab_infra_qc_r3355 l
  group by l.unit_type, l.lab_section
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3355_unit_section_matrix() from public, anon;
grant execute on function public.founder_r3355_unit_section_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3355_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, filter_overdue bigint, microbial_fail bigint)
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
    count(*) filter (where l.filter_cartridge_status = 'overdue')::bigint,
    count(*) filter (where l.microbial_test_ok = 'fail')::bigint
  from public.lab_infra_qc_r3355 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3355_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3355_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3355_capa_status_board()
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
  from public.lab_infra_qc_capa_actions_r3355 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3355_capa_status_board() from public, anon;
grant execute on function public.founder_r3355_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3355_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lab_infra_qc_capa_actions_r3355)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.lab_infra_qc_capa_actions_r3355 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3355_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3355_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3355_regulatory_impact_digest()
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
  from public.lab_infra_qc_capa_actions_r3355 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3355_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3355_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3355_high_risk_queue()
returns table(
  hospital_name text,
  unit_code text,
  unit_type text,
  check_date date,
  qc_verdict text,
  filter_cartridge_status text,
  uv_lamp_ok text,
  fume_hood_face_velocity_ok text,
  microbial_test_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.unit_code, l.unit_type, l.check_date,
    l.qc_verdict, l.filter_cartridge_status, l.uv_lamp_ok,
    l.fume_hood_face_velocity_ok, l.microbial_test_ok, l.notes
  from public.lab_infra_qc_r3355 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.filter_cartridge_status = 'overdue'
     or l.uv_lamp_ok = 'degraded'
     or l.fume_hood_face_velocity_ok in ('low','fail')
     or l.microbial_test_ok = 'fail'
     or l.storage_ventilation_ok = false
     or l.spill_containment_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3355_high_risk_queue() from public, anon;
grant execute on function public.founder_r3355_high_risk_queue() to authenticated;
