-- Round 3170: Customer Hospital Blood-Gas Analyzer QC & Calibration-Drift Audit
-- ABG analyzer QC log — analyte × QC level × target/measured/bias × Westgard rule × cal-drift × sensor age × verdict × CAPA

-- =============================================================================
-- TABLE 1: blood_gas_qc_r3170 — individual ABG analyzer QC runs
-- =============================================================================
create table if not exists public.blood_gas_qc_r3170 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  lab_section_code text not null,
  analyzer_asset_tag text not null,
  analyzer_model text not null,
  qc_run_number int not null,
  qc_date date not null,
  qc_run_at timestamptz not null,
  analyte text not null check (analyte in (
    'ph','pco2','po2','sodium_na','potassium_k','lactate',
    'ionized_calcium','glucose','hematocrit','chloride_cl'
  )),
  qc_level text not null check (qc_level in (
    'level_1_low','level_2_normal','level_3_high','level_4_hyper'
  )),
  qc_lot_number text,
  target_value numeric(8,3) not null,
  measured_value numeric(8,3) not null,
  allowable_sd numeric(6,3),
  bias_pct numeric(6,2),
  sd_index numeric(6,2),
  westgard_rule text not null check (westgard_rule in (
    'in_control','warning_1_2s','reject_1_3s','reject_2_2s','reject_r_4s',
    'reject_4_1s','reject_10x','reject_2of3_2s','reject_8x','reject_6x'
  )),
  cal_drift_pct numeric(6,2),
  sensor_type text check (sensor_type in (
    'ph_electrode','pco2_electrode','po2_electrode','na_ise','k_ise',
    'lactate_biosensor','ca_ise','glucose_biosensor','reference_electrode','conductivity_hct'
  )),
  sensor_age_days int,
  last_calibration_at timestamptz,
  operator_profile_id uuid references public.profiles(id) on delete set null,
  qc_verdict text not null check (qc_verdict in (
    'accepted','warning_flagged','rejected','recalibrated',
    'sensor_replaced','pending_review','conditional_accept'
  )),
  resolved_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.blood_gas_qc_r3170 enable row level security;

create index if not exists idx_blood_gas_qc_r3170_org on public.blood_gas_qc_r3170(organization_id);
create index if not exists idx_blood_gas_qc_r3170_date on public.blood_gas_qc_r3170(qc_date);
create index if not exists idx_blood_gas_qc_r3170_verdict on public.blood_gas_qc_r3170(qc_verdict);

-- =============================================================================
-- TABLE 2: blood_gas_qc_capa_actions_r3170 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.blood_gas_qc_capa_actions_r3170 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.blood_gas_qc_r3170(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'westgard_reject','excessive_bias','cal_drift_high','sensor_aging',
    'qc_material_expired','reagent_depletion','maintenance_overdue',
    'operator_error','temperature_deviation','carryover_contamination'
  )),
  root_cause text not null check (root_cause in (
    'sensor_end_of_life','membrane_fouling','calibrant_degraded','reagent_lot_variance',
    'electrode_drift','pump_tubing_wear','temperature_control_fault',
    'operator_technique','qc_lot_change','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_sensor','recalibrate_2point','replace_qc_lot','replace_reagent_pack',
    'clean_membrane','replace_pump_tubing','retrain_operator',
    'schedule_amc_visit','firmware_update','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cap_deviation','iso_15189_deviation',
    'none','internal_only','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.blood_gas_qc_capa_actions_r3170 enable row level security;

create index if not exists idx_blood_gas_capa_r3170_log on public.blood_gas_qc_capa_actions_r3170(qc_log_id);
create index if not exists idx_blood_gas_capa_r3170_status on public.blood_gas_qc_capa_actions_r3170(capa_status);

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

  -- 14 QC run rows
  insert into public.blood_gas_qc_r3170 (
    organization_id, hospital_name, lab_section_code, analyzer_asset_tag, analyzer_model,
    qc_run_number, qc_date, qc_run_at,
    analyte, qc_level, qc_lot_number,
    target_value, measured_value, allowable_sd, bias_pct, sd_index,
    westgard_rule, cal_drift_pct, sensor_type, sensor_age_days, last_calibration_at,
    qc_verdict, resolved_at, notes
  )
  select v_org_id, q.hosp, q.sect, q.tag, q.model,
    q.rn::int, q.qd::date, q.ra::timestamptz,
    q.an, q.lv, q.lot,
    q.tv, q.mv, q.asd, q.bias, q.sdi,
    q.wg, q.drift, q.st, q.age::int, q.lc::timestamptz,
    q.vd, q.res::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ABG Lab','ABL-APL-014','Radiometer ABL800 Flex','1001','2026-07-01','2026-07-01 06:15:00+05:30',
     'ph','level_2_normal','QCLOT-A231',7.400,7.390,0.020,-0.14,0.5,'in_control',0.30,'ph_electrode','95','2026-07-01 05:30:00+05:30','accepted','2026-07-01 06:20:00+05:30','Level 2 pH within control limits'),
    ('Apollo Hyderabad Jubilee Hills','ABG Lab','ABL-APL-014','Radiometer ABL800 Flex','1002','2026-07-01','2026-07-01 06:40:00+05:30',
     'pco2','level_1_low','QCLOT-A231',30.0,31.8,0.8,6.00,1.8,'warning_1_2s',1.20,'pco2_electrode','140','2026-07-01 05:30:00+05:30','warning_flagged',null,'pCO2 low QC 1-2s warning — monitor next run'),
    ('Fortis Bannerghatta Bengaluru','Blood Gas Bench','ABL-FRT-007','Werfen GEM Premier 5000','1003','2026-07-01','2026-07-01 05:35:00+05:30',
     'po2','level_3_high','QCLOT-B118',150.0,168.0,3.0,12.00,4.5,'reject_1_3s',3.50,'po2_electrode','210','2026-06-30 22:00:00+05:30','rejected',null,'pO2 high QC 1-3s reject — patient runs held'),
    ('Fortis Bannerghatta Bengaluru','Blood Gas Bench','ABL-FRT-007','Werfen GEM Premier 5000','1004','2026-07-01','2026-07-01 06:25:00+05:30',
     'sodium_na','level_2_normal','QCLOT-B118',140.0,133.0,1.5,-5.00,3.2,'reject_2_2s',2.80,'na_ise','175','2026-07-01 06:00:00+05:30','recalibrated','2026-07-01 07:10:00+05:30','Na 2-2s reject — recalibrated, back in control'),
    ('Manipal Whitefield Bengaluru','ICU Point of Care','ABL-MNP-021','Siemens RAPIDPoint 500e','1005','2026-06-30','2026-06-30 08:20:00+05:30',
     'potassium_k','level_2_normal','QCLOT-C540',4.00,4.62,0.15,15.50,4.8,'reject_1_3s',4.20,'k_ise','260','2026-06-30 07:00:00+05:30','sensor_replaced','2026-06-30 11:00:00+05:30','K+ ISE end of life — sensor replaced'),
    ('Manipal Whitefield Bengaluru','ICU Point of Care','ABL-MNP-021','Siemens RAPIDPoint 500e','1006','2026-06-30','2026-06-30 09:35:00+05:30',
     'lactate','level_1_low','QCLOT-C540',1.50,1.55,0.10,3.30,0.9,'in_control',0.60,'lactate_biosensor','60','2026-06-30 09:00:00+05:30','accepted','2026-06-30 09:40:00+05:30','Post sensor-swap lactate in control'),
    ('AIIMS New Delhi Ansari Nagar','Central Lab ABG','ABL-AIM-033','Radiometer ABL90 Flex Plus','1007','2026-06-30','2026-06-30 06:05:00+05:30',
     'ph','level_3_high','QCLOT-D902',7.600,7.610,0.020,0.13,0.4,'in_control',0.25,'ph_electrode','45','2026-06-30 05:30:00+05:30','accepted','2026-06-30 06:10:00+05:30','Level 3 pH nominal'),
    ('AIIMS New Delhi Ansari Nagar','Central Lab ABG','ABL-AIM-033','Radiometer ABL90 Flex Plus','1008','2026-06-30','2026-06-30 07:05:00+05:30',
     'ionized_calcium','level_2_normal','QCLOT-D902',1.150,1.090,0.030,-5.20,2.6,'reject_4_1s',2.10,'ca_ise','190','2026-06-30 05:30:00+05:30','conditional_accept',null,'iCa 4-1s systematic bias — conditional pending review'),
    ('KIMS Secunderabad','ABG Lab','ABL-KIM-011','Werfen GEM Premier 4000','1009','2026-06-29','2026-06-29 05:50:00+05:30',
     'pco2','level_2_normal','QCLOT-E077',40.0,43.6,1.0,9.00,3.6,'reject_r_4s',2.90,'pco2_electrode','230','2026-06-29 05:00:00+05:30','pending_review',null,'pCO2 R-4s range violation — under review'),
    ('KIMS Secunderabad','ABG Lab','ABL-KIM-011','Werfen GEM Premier 4000','1010','2026-06-29','2026-06-29 07:10:00+05:30',
     'sodium_na','level_3_high','QCLOT-E077',160.0,152.0,2.0,-5.00,4.0,'reject_10x',3.10,'na_ise','240','2026-06-29 05:00:00+05:30','rejected',null,'Na 10x mean shift — systematic error flagged'),
    ('Care Hospitals Banjara Hills','Emergency ABG','ABL-CAR-005','Nova Biomedical Stat Profile Prime','1011','2026-06-29','2026-06-29 09:05:00+05:30',
     'glucose','level_2_normal','QCLOT-F314',100.0,108.0,2.5,8.00,2.2,'warning_1_2s',1.50,'glucose_biosensor','130','2026-06-29 08:30:00+05:30','warning_flagged',null,'Glucose 1-2s warning — trending high'),
    ('Yashoda Somajiguda Hyderabad','NICU Point of Care','ABL-YSH-018','Radiometer ABL800 Flex','1012','2026-06-28','2026-06-28 06:35:00+05:30',
     'po2','level_2_normal','QCLOT-G620',100.0,97.0,2.5,-3.00,1.2,'in_control',0.90,'po2_electrode','80','2026-06-28 06:00:00+05:30','accepted','2026-06-28 06:40:00+05:30','pO2 level 2 within limits'),
    ('St John''s Bengaluru','Blood Gas Lab','ABL-STJ-003','Siemens RAPIDPoint 500e','1013','2026-06-28','2026-06-28 05:55:00+05:30',
     'potassium_k','level_1_low','QCLOT-H815',3.00,3.02,0.10,0.70,0.3,'in_control',0.40,'k_ise','55','2026-06-28 05:30:00+05:30','accepted','2026-06-28 06:00:00+05:30','K+ low QC nominal'),
    ('Rainbow Children''s Hyderabad','PICU ABG','ABL-RBW-009','Nova Biomedical Stat Profile Prime','1014','2026-06-27','2026-06-27 07:05:00+05:30',
     'lactate','level_3_high','QCLOT-J119',8.00,9.20,0.30,15.00,5.5,'reject_2of3_2s',5.00,'lactate_biosensor','300','2026-06-27 06:00:00+05:30','rejected',null,'Lactate biosensor EOL — 2of3-2s reject, replacement due')
  ) as q(hosp, sect, tag, model, rn, qd, ra, an, lv, lot, tv, mv, asd, bias, sdi, wg, drift, st, age, lc, vd, res, nt)
  where q.rn ~ '^[0-9]+$';

  -- CAPA seed — attach to specific QC runs
  insert into public.blood_gas_qc_capa_actions_r3170 (
    qc_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select l.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('Fortis Bannerghatta Bengaluru',1003,'westgard_reject','electrode_drift','recalibrate_2point','2026-07-05',null,'in_progress','nabl_finding',8500,'pO2 electrode drift 3.5% — 2-point recalibration ordered'),
    ('Manipal Whitefield Bengaluru',1005,'sensor_aging','sensor_end_of_life','replace_sensor','2026-07-03','2026-07-02','closed','cap_deviation',42000,'K+ ISE 260 days replaced, QC back in control'),
    ('KIMS Secunderabad',1009,'excessive_bias','membrane_fouling','clean_membrane','2026-07-04',null,'verification_pending','iso_15189_deviation',3200,'pCO2 membrane cleaned, monitoring 5 runs'),
    ('KIMS Secunderabad',1010,'cal_drift_high','calibrant_degraded','replace_qc_lot','2026-07-06',null,'escalated','nabh_finding',5600,'Na systematic 10x shift — calibrant & QC lot replaced'),
    ('Rainbow Children''s Hyderabad',1014,'sensor_aging','sensor_end_of_life','replace_sensor','2026-06-30',null,'overdue','patient_safety_alert',38000,'Lactate biosensor EOL at 300 days — replacement overdue'),
    ('AIIMS New Delhi Ansari Nagar',1008,'maintenance_overdue','pending_investigation','schedule_amc_visit','2026-07-08',null,'open','internal_only',15000,'iCa drift under investigation — AMC visit scheduled')
  ) as q(hosp_key, rn_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.blood_gas_qc_r3170 l
    on l.hospital_name = q.hosp_key and l.qc_run_number = q.rn_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3170_qc_verdict_rollup()
returns table(qc_verdict text, runs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.blood_gas_qc_r3170)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.blood_gas_qc_r3170 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3170_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3170_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3170_hospital_scorecard()
returns table(
  hospital_name text,
  total_runs bigint,
  accepted bigint,
  rejected bigint,
  recalibrated bigint,
  sensor_replaced bigint,
  westgard_rejects bigint,
  avg_bias_pct numeric,
  acceptance_pct numeric
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
    count(*) filter (where l.qc_verdict = 'accepted')::bigint,
    count(*) filter (where l.qc_verdict = 'rejected')::bigint,
    count(*) filter (where l.qc_verdict = 'recalibrated')::bigint,
    count(*) filter (where l.qc_verdict = 'sensor_replaced')::bigint,
    count(*) filter (where l.westgard_rule like 'reject%')::bigint,
    round(avg(l.bias_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'accepted')::numeric / nullif(count(*),0), 1)
  from public.blood_gas_qc_r3170 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3170_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3170_hospital_scorecard() to authenticated;

-- 3) Analyte × QC level breakdown
create or replace function public.founder_r3170_analyte_level_matrix()
returns table(analyte text, qc_level text, runs bigint, rejected bigint, avg_bias_pct numeric, avg_drift_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.analyte, l.qc_level, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'rejected')::bigint,
    round(avg(l.bias_pct), 2),
    round(avg(l.cal_drift_pct), 2)
  from public.blood_gas_qc_r3170 l
  group by l.analyte, l.qc_level
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3170_analyte_level_matrix() from public, anon;
grant execute on function public.founder_r3170_analyte_level_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3170_qc_daily_trend()
returns table(qc_date date, runs bigint, accepted bigint, warnings bigint, rejected bigint, avg_bias_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.qc_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'accepted')::bigint,
    count(*) filter (where l.qc_verdict = 'warning_flagged')::bigint,
    count(*) filter (where l.qc_verdict = 'rejected')::bigint,
    round(avg(l.bias_pct), 2)
  from public.blood_gas_qc_r3170 l
  group by l.qc_date
  order by l.qc_date desc;
end;
$$;

revoke execute on function public.founder_r3170_qc_daily_trend() from public, anon;
grant execute on function public.founder_r3170_qc_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3170_capa_status_board()
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
  from public.blood_gas_qc_capa_actions_r3170 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3170_capa_status_board() from public, anon;
grant execute on function public.founder_r3170_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3170_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.blood_gas_qc_capa_actions_r3170)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.blood_gas_qc_capa_actions_r3170 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3170_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3170_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3170_regulatory_impact_digest()
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
  from public.blood_gas_qc_capa_actions_r3170 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3170_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3170_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC runs (priority queue)
create or replace function public.founder_r3170_high_risk_runs()
returns table(
  hospital_name text,
  lab_section_code text,
  analyzer_asset_tag text,
  qc_date date,
  analyte text,
  qc_level text,
  bias_pct numeric,
  cal_drift_pct numeric,
  westgard_rule text,
  qc_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.lab_section_code, l.analyzer_asset_tag, l.qc_date,
    l.analyte, l.qc_level, l.bias_pct, l.cal_drift_pct, l.westgard_rule, l.qc_verdict, l.notes
  from public.blood_gas_qc_r3170 l
  where l.qc_verdict in ('rejected','pending_review','conditional_accept','recalibrated','sensor_replaced','warning_flagged')
     or l.westgard_rule like 'reject%'
     or abs(l.bias_pct) >= 5.0
     or l.cal_drift_pct >= 2.5
  order by l.qc_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3170_high_risk_runs() from public, anon;
grant execute on function public.founder_r3170_high_risk_runs() to authenticated;
