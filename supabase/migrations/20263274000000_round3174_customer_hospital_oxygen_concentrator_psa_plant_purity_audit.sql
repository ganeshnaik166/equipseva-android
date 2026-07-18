-- Round 3174: Customer Hospital Oxygen-Concentrator & PSA-Plant Output-Purity Audit
-- Medical O2 source QA log — source type × gas standard × purity % × flow × dew point × pressure × sieve-bed age × backup-changeover × alarm test × verdict + CAPA

-- =============================================================================
-- TABLE 1: oxygen_psa_r3174 — individual O2 source purity audits
-- =============================================================================
create table if not exists public.oxygen_psa_r3174 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  plant_location text not null,
  source_asset_tag text not null,
  source_model text not null,
  source_type text not null check (source_type in (
    'oxygen_concentrator','psa_plant','cylinder_manifold',
    'liquid_oxygen_vie','portable_concentrator','bulk_lox_tank'
  )),
  audit_number int not null,
  audit_date date not null,
  audit_started_at timestamptz not null,
  audit_ended_at timestamptz,
  gas_standard text not null check (gas_standard in (
    'ip_2018_93pct','usp_93pct','en_iso_10083','htm_02_01','nabh_medical_gas'
  )),
  o2_purity_pct numeric(5,2) not null,
  purity_verdict text not null check (purity_verdict in (
    'above_spec','at_spec','marginal','below_spec','critical_low'
  )),
  flow_lpm numeric(6,2),
  dew_point_c numeric(5,2),
  dew_point_verdict text check (dew_point_verdict in (
    'pass','fail','marginal','not_measured'
  )),
  pressure_bar numeric(5,2),
  sieve_bed_age_months int,
  backup_changeover_test text not null check (backup_changeover_test in (
    'pass','fail','not_tested','delayed_switchover','manual_only'
  )),
  alarm_test_result text not null check (alarm_test_result in (
    'pass','fail','not_tested','partial','false_alarm'
  )),
  auditor_profile_id uuid references public.profiles(id) on delete set null,
  audit_verdict text not null check (audit_verdict in (
    'compliant','conditional','non_compliant','fail_shutdown','pending_review','recall_source'
  )),
  signed_off_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oxygen_psa_r3174 enable row level security;

create index if not exists idx_oxygen_psa_r3174_org on public.oxygen_psa_r3174(organization_id);
create index if not exists idx_oxygen_psa_r3174_date on public.oxygen_psa_r3174(audit_date);
create index if not exists idx_oxygen_psa_r3174_verdict on public.oxygen_psa_r3174(audit_verdict);

-- =============================================================================
-- TABLE 2: oxygen_psa_capa_actions_r3174 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.oxygen_psa_capa_actions_r3174 (
  id uuid primary key default gen_random_uuid(),
  audit_log_id uuid not null references public.oxygen_psa_r3174(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'low_purity','high_dew_point','low_flow','pressure_deviation','sieve_bed_exhausted',
    'changeover_failure','alarm_failure','moisture_ingress','contamination_detected','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'sieve_material_degraded','compressor_worn','air_dryer_failure','moisture_filter_saturated',
    'valve_leak','sensor_drift','inlet_air_contamination','power_fluctuation','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_sieve_beds','overhaul_compressor','service_air_dryer','replace_moisture_filter',
    'repair_changeover_valve','recalibrate_oxygen_analyzer','purge_and_dry_system',
    'switch_to_backup_source','schedule_amc_visit','none_required','replace_o2_sensor'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','ip_pharmacopoeia_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oxygen_psa_capa_actions_r3174 enable row level security;

create index if not exists idx_oxygen_psa_capa_r3174_audit on public.oxygen_psa_capa_actions_r3174(audit_log_id);
create index if not exists idx_oxygen_psa_capa_r3174_status on public.oxygen_psa_capa_actions_r3174(capa_status);

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

  -- 14 O2 source audit rows
  insert into public.oxygen_psa_r3174 (
    organization_id, hospital_name, plant_location, source_asset_tag, source_model,
    source_type, audit_number, audit_date, audit_started_at, audit_ended_at,
    gas_standard, o2_purity_pct, purity_verdict, flow_lpm, dew_point_c, dew_point_verdict,
    pressure_bar, sieve_bed_age_months, backup_changeover_test, alarm_test_result,
    audit_verdict, signed_off_at, notes
  )
  select v_org_id, q.hosp, q.loc, q.tag, q.model,
    q.st, q.an::int, q.ad::date, q.as_start::timestamptz, q.ae::timestamptz,
    q.gs, q.pur, q.pv, q.flow, q.dp, q.dpv,
    q.press, q.sba::int, q.bct, q.atr,
    q.av, q.so::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','PSA-PLANT-A','O2-APL-001','Oxymat OM-40','psa_plant','101','2026-07-14','2026-07-14 06:00:00+05:30','2026-07-14 07:30:00+05:30',
     'ip_2018_93pct',94.50,'above_spec',850.00,-52.00,'pass',4.20,'18','pass','pass','compliant','2026-07-14 08:00:00+05:30','PSA plant A monthly output audit — parameters within IP limits'),
    ('Apollo Hyderabad Jubilee Hills','MANIFOLD-B','O2-APL-014','BeaconMedaes CM','cylinder_manifold','102','2026-07-14','2026-07-14 08:00:00+05:30','2026-07-14 08:45:00+05:30',
     'nabh_medical_gas',99.20,'above_spec',120.00,-60.00,'pass',4.10,null,'pass','pass','compliant','2026-07-14 09:00:00+05:30','Backup cylinder manifold — medical-grade cylinders verified'),
    ('Fortis Bannerghatta Bengaluru','PSA-PLANT-1','O2-FRT-007','Atlas Copco OGP','psa_plant','55','2026-07-13','2026-07-13 05:30:00+05:30','2026-07-13 07:00:00+05:30',
     'ip_2018_93pct',89.30,'below_spec',620.00,-38.00,'marginal',3.80,'42','delayed_switchover','pass','non_compliant',null,'Purity 89.3 pct below 93 pct IP minimum — sieve beds aged 42 months'),
    ('Fortis Bannerghatta Bengaluru','CONC-ICU-3','O2-FRT-022','Philips EverFlo','oxygen_concentrator','56','2026-07-13','2026-07-13 07:30:00+05:30','2026-07-13 08:00:00+05:30',
     'usp_93pct',82.10,'critical_low',4.50,-20.00,'fail',0.35,'60','fail','fail','fail_shutdown',null,'Bedside concentrator critical low purity — unit removed from service'),
    ('Manipal Whitefield Bengaluru','PSA-PLANT-2','O2-MNP-021','Inmatec IMT PO','psa_plant','77','2026-07-12','2026-07-12 08:15:00+05:30','2026-07-12 09:45:00+05:30',
     'en_iso_10083',93.80,'at_spec',900.00,-55.00,'pass',4.30,'24','pass','pass','compliant','2026-07-12 10:00:00+05:30','Post sieve-bed top-up first audit — dew point restored'),
    ('Manipal Whitefield Bengaluru','VIE-LOX-MAIN','O2-MNP-030','INOX VIE 11000L','liquid_oxygen_vie','78','2026-07-12','2026-07-12 10:15:00+05:30','2026-07-12 11:00:00+05:30',
     'ip_2018_93pct',99.60,'above_spec',1500.00,-65.00,'pass',4.15,null,'pass','pass','compliant','2026-07-12 11:15:00+05:30','Liquid oxygen VIE main supply — vaporizer inspected'),
    ('AIIMS New Delhi Ansari Nagar','PSA-PLANT-C','O2-AIM-033','Oxywise OW-60','psa_plant','210','2026-07-11','2026-07-11 06:00:00+05:30','2026-07-11 07:40:00+05:30',
     'ip_2018_93pct',93.10,'at_spec',1100.00,-48.00,'pass',4.25,'30','pass','partial','conditional','2026-07-11 08:00:00+05:30','Purity at IP boundary; low-purity alarm partial — sensor recalib scheduled'),
    ('AIIMS New Delhi Ansari Nagar','MANIFOLD-EMERG','O2-AIM-041','BPR Manifold 2x10','cylinder_manifold','211','2026-07-11','2026-07-11 08:15:00+05:30','2026-07-11 09:00:00+05:30',
     'nabh_medical_gas',98.90,'above_spec',200.00,-58.00,'pass',4.00,null,'manual_only','pass','conditional',null,'Emergency manifold changeover manual-only — auto valve pending'),
    ('KIMS Secunderabad','PSA-PLANT-1','O2-KIM-011','Oxymat OM-30','psa_plant','88','2026-07-10','2026-07-10 05:45:00+05:30','2026-07-10 07:15:00+05:30',
     'ip_2018_93pct',90.80,'below_spec',700.00,-30.00,'fail',3.90,'48','delayed_switchover','fail','non_compliant',null,'High dew point -30C indicates air dryer failure; purity dropping'),
    ('KIMS Secunderabad','CONC-WARD-5','O2-KIM-025','DeVilbiss 525','oxygen_concentrator','89','2026-07-10','2026-07-10 07:30:00+05:30','2026-07-10 08:00:00+05:30',
     'usp_93pct',91.50,'marginal',5.00,-25.00,'marginal',0.40,'36','not_tested','not_tested','pending_review',null,'Ward concentrator marginal — full test pending biomedical review'),
    ('Care Hospitals Banjara Hills','PSA-PLANT-A','O2-CAR-005','Atlas Copco OGP+','psa_plant','33','2026-07-09','2026-07-09 09:00:00+05:30','2026-07-09 10:20:00+05:30',
     'ip_2018_93pct',94.10,'above_spec',820.00,-54.00,'pass',4.20,'12','pass','pass','compliant','2026-07-09 10:35:00+05:30','Routine monthly audit — plant commissioned last year'),
    ('Yashoda Somajiguda Hyderabad','PSA-PLANT-2','O2-YSH-018','Inmatec IMT PO 8','psa_plant','145','2026-07-08','2026-07-08 06:30:00+05:30','2026-07-08 08:00:00+05:30',
     'en_iso_10083',87.40,'below_spec',560.00,-28.00,'fail',3.70,'54','fail','false_alarm','recall_source',null,'Purity 87.4 pct and changeover fail — source recall, switch to VIE'),
    ('St John''s Bengaluru','CONC-OT-1','O2-STJ-003','Nidek Nuvo Lite','oxygen_concentrator','19','2026-07-08','2026-07-08 05:50:00+05:30','2026-07-08 06:25:00+05:30',
     'usp_93pct',95.20,'above_spec',5.00,-35.00,'pass',0.45,'6','pass','pass','compliant','2026-07-08 06:40:00+05:30','OT backup concentrator — weekly check all pass'),
    ('Rainbow Children''s Hyderabad','PSA-PLANT-PEDS','O2-RBW-009','Oxywise OW-30','psa_plant','61','2026-07-07','2026-07-07 07:00:00+05:30',null,
     'ip_2018_93pct',92.30,'marginal',480.00,-42.00,'marginal',3.85,'33','delayed_switchover','partial','pending_review',null,'Paeds PSA plant marginal purity; audit paused for sieve inspection')
  ) as q(hosp, loc, tag, model, st, an, ad, as_start, ae, gs, pur, pv, flow, dp, dpv, press, sba, bct, atr, av, so, nt)
  where q.an ~ '^[0-9]+$';

  -- CAPA seed — attach to specific audits by hospital + audit number
  insert into public.oxygen_psa_capa_actions_r3174 (
    audit_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('Fortis Bannerghatta Bengaluru', 55, 'low_purity','sieve_material_degraded','replace_sieve_beds','2026-07-20',null,'in_progress','nabh_finding',185000.00,'Sieve beds 42 months — full zeolite replacement scheduled'),
    ('Fortis Bannerghatta Bengaluru', 56, 'low_purity','sieve_material_degraded','switch_to_backup_source','2026-07-15','2026-07-13','closed','patient_safety_alert',25000.00,'Bedside unit condemned; patient moved to central O2'),
    ('KIMS Secunderabad',            88, 'high_dew_point','air_dryer_failure','service_air_dryer','2026-07-16',null,'escalated','cdsco_notifiable',95000.00,'Refrigerant dryer failed — high moisture risk to pipeline'),
    ('Yashoda Somajiguda Hyderabad', 145,'changeover_failure','valve_leak','repair_changeover_valve','2026-07-14',null,'overdue','patient_safety_alert',62000.00,'Auto-changeover valve leak — hospital on VIE backup'),
    ('AIIMS New Delhi Ansari Nagar', 210,'alarm_failure','sensor_drift','recalibrate_oxygen_analyzer','2026-07-18',null,'verification_pending','ip_pharmacopoeia_deviation',8500.00,'Low-purity alarm threshold drift — analyzer recalibration'),
    ('Rainbow Children''s Hyderabad', 61, 'sieve_bed_exhausted','sieve_material_degraded','replace_sieve_beds','2026-07-22',null,'open','nabh_finding',150000.00,'Paeds plant sieve beds 33 months — replacement planned'),
    ('Apollo Hyderabad Jubilee Hills',101,'preventive_maintenance_due','preventive_service_backlog','schedule_amc_visit','2026-07-25',null,'open','none',15000.00,'Quarterly PSA plant PM upcoming'),
    ('Manipal Whitefield Bengaluru',  77, 'moisture_ingress','moisture_filter_saturated','replace_moisture_filter','2026-07-15','2026-07-12','closed','internal_only',4200.00,'Moisture filter swapped during sieve top-up')
  ) as q(hosp_key, an_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.oxygen_psa_r3174 e
    on e.organization_id = v_org_id and e.hospital_name = q.hosp_key and e.audit_number = q.an_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3174_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oxygen_psa_r3174)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.oxygen_psa_r3174 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3174_verdict_rollup() from public, anon;
grant execute on function public.founder_r3174_verdict_rollup() to authenticated;

-- 2) Hospital-level purity scorecard
create or replace function public.founder_r3174_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  compliant bigint,
  non_compliant bigint,
  fail_shutdown bigint,
  below_spec bigint,
  changeover_fail bigint,
  avg_purity_pct numeric,
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
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    count(*) filter (where l.audit_verdict = 'non_compliant')::bigint,
    count(*) filter (where l.audit_verdict in ('fail_shutdown','recall_source'))::bigint,
    count(*) filter (where l.purity_verdict in ('below_spec','critical_low'))::bigint,
    count(*) filter (where l.backup_changeover_test = 'fail')::bigint,
    round(avg(l.o2_purity_pct), 2),
    round(100.0 * count(*) filter (where l.audit_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.oxygen_psa_r3174 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3174_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3174_hospital_scorecard() to authenticated;

-- 3) Source-type × gas-standard matrix
create or replace function public.founder_r3174_source_standard_matrix()
returns table(source_type text, gas_standard text, audits bigint, compliant bigint, avg_purity_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.source_type, l.gas_standard, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    round(avg(l.o2_purity_pct), 2)
  from public.oxygen_psa_r3174 l
  group by l.source_type, l.gas_standard
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3174_source_standard_matrix() from public, anon;
grant execute on function public.founder_r3174_source_standard_matrix() to authenticated;

-- 4) Purity daily trend
create or replace function public.founder_r3174_purity_daily_trend()
returns table(audit_date date, audits bigint, avg_purity_pct numeric, compliant bigint, non_compliant bigint, below_spec bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    round(avg(l.o2_purity_pct), 2),
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    count(*) filter (where l.audit_verdict in ('non_compliant','fail_shutdown','recall_source'))::bigint,
    count(*) filter (where l.purity_verdict in ('below_spec','critical_low'))::bigint
  from public.oxygen_psa_r3174 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3174_purity_daily_trend() from public, anon;
grant execute on function public.founder_r3174_purity_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3174_capa_status_board()
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
  from public.oxygen_psa_capa_actions_r3174 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3174_capa_status_board() from public, anon;
grant execute on function public.founder_r3174_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3174_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oxygen_psa_capa_actions_r3174)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.oxygen_psa_capa_actions_r3174 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3174_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3174_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3174_regulatory_impact_digest()
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
  from public.oxygen_psa_capa_actions_r3174 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3174_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3174_regulatory_impact_digest() to authenticated;

-- 8) High-risk O2 sources queue
create or replace function public.founder_r3174_high_risk_sources()
returns table(
  hospital_name text,
  plant_location text,
  source_asset_tag text,
  audit_date date,
  audit_verdict text,
  o2_purity_pct numeric,
  purity_verdict text,
  dew_point_verdict text,
  backup_changeover_test text,
  alarm_test_result text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.plant_location, l.source_asset_tag, l.audit_date,
    l.audit_verdict, l.o2_purity_pct, l.purity_verdict, l.dew_point_verdict,
    l.backup_changeover_test, l.alarm_test_result, l.notes
  from public.oxygen_psa_r3174 l
  where l.audit_verdict in ('non_compliant','fail_shutdown','recall_source','pending_review','conditional')
     or l.purity_verdict in ('below_spec','critical_low')
     or l.backup_changeover_test = 'fail'
     or l.alarm_test_result = 'fail'
     or l.dew_point_verdict = 'fail'
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3174_high_risk_sources() from public, anon;
grant execute on function public.founder_r3174_high_risk_sources() to authenticated;
