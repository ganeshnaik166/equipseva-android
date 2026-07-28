-- Round 3558: Customer Hospital Immunohematology Analyzer (Blood-Grouping) QC Audit
-- Immunohematology QA — analyzer model × parameter (reaction grade / centrifuge rpm / incubation temp / optical read / carryover / gel-card fill) × qc level (anti-A/B/D/control) × reference vs measured × deviation × tolerance × calibration × CAPA

-- =============================================================================
-- TABLE 1: immunohematology_qc_r3558 — per-analyzer blood-grouping QC measurements
-- =============================================================================
create table if not exists public.immunohematology_qc_r3558 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'reaction_grade_accuracy','centrifuge_rpm','incubation_temp_c',
    'optical_read','carryover_pct','gel_card_fill'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  qc_level text not null check (qc_level in (
    'anti_a','anti_b','anti_d','control'
  )),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.immunohematology_qc_r3558 enable row level security;

create index if not exists idx_immunohematology_qc_r3558_org on public.immunohematology_qc_r3558(organization_id);
create index if not exists idx_immunohematology_qc_r3558_cal on public.immunohematology_qc_r3558(calibration_date);
create index if not exists idx_immunohematology_qc_r3558_verdict on public.immunohematology_qc_r3558(qc_verdict);

-- =============================================================================
-- TABLE 2: immunohematology_qc_capa_actions_r3558 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.immunohematology_qc_capa_actions_r3558 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.immunohematology_qc_r3558(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'reaction_grade_out_of_tolerance','centrifuge_rpm_drift','incubation_temp_deviation',
    'optical_read_error','carryover_exceeded','gel_card_fill_defect',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'reagent_lot_degraded','centrifuge_bearing_wear','heater_element_fault','optical_lamp_aged',
    'probe_wash_insufficient','gel_card_manufacturing_defect','software_config_error',
    'operator_technique_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_analyzer','replace_reagent_lot','service_centrifuge','replace_heater_module',
    'replace_optical_lamp','enhance_probe_wash','replace_gel_card_lot','update_software_config',
    'retrain_lab_staff','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.immunohematology_qc_capa_actions_r3558 enable row level security;

create index if not exists idx_immunohematology_capa_r3558_log on public.immunohematology_qc_capa_actions_r3558(qc_log_id);
create index if not exists idx_immunohematology_capa_r3558_status on public.immunohematology_qc_capa_actions_r3558(capa_status);

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

  -- 16 QC measurement rows
  insert into public.immunohematology_qc_r3558 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, qc_level, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.qclevel, q.wtol,
    q.caldate::date, q.verdict, q.nt
  from (values
    ('Apollo Chennai','IH-APL-01','Ortho Vision','reaction_grade_accuracy',
     4.0,4.0,0.0,'anti_a',true,'2026-07-05','pass','Anti-A gel-card agglutination graded 4+ matches expected'),
    ('Apollo Chennai','IH-APL-02','Ortho Vision','centrifuge_rpm',
     895,892,0.34,'control',true,'2026-07-05','pass','Centrifuge RPM within +/-1% of setpoint'),
    ('Fortis Mulund','IH-FRT-11','Bio-Rad IH-500','incubation_temp_c',
     37.0,37.3,0.81,'control',true,'2026-06-20','pass','Incubation block at 37.3C within tolerance'),
    ('Fortis Mulund','IH-FRT-12','Bio-Rad IH-500','optical_read',
     1.00,1.06,6.0,'anti_d',false,'2026-06-20','conditional_pass','Optical read drift 6% on anti-D channel — lamp aging'),
    ('Manipal Bengaluru','IH-MNP-21','Grifols Erytra','carryover_pct',
     0.10,0.42,320.0,'anti_b',false,'2026-06-18','fail','Carryover 0.42% exceeds 0.1% limit — probe wash fault'),
    ('Manipal Bengaluru','IH-MNP-22','Grifols Erytra','gel_card_fill',
     100.0,100.0,0.0,'control',true,'2026-06-18','pass','Gel-card dispense fill volume nominal'),
    ('AIIMS Delhi','IH-AIM-31','Immucor Galileo','reaction_grade_accuracy',
     3.0,2.0,33.33,'anti_d',false,'2026-06-15','fail','Weak-D control graded 2+ vs expected 3+ — reagent lot suspect'),
    ('AIIMS Delhi','IH-AIM-32','Immucor Galileo','incubation_temp_c',
     37.0,38.4,3.78,'control',false,'2026-06-15','conditional_pass','Incubation temp 38.4C above tolerance — heater recheck'),
    ('CMC Vellore','IH-CMC-41','Ortho AutoVue Innova','centrifuge_rpm',
     900,861,4.33,'control',false,'2026-05-22','conditional_pass','Centrifuge RPM 4.3% low — bearing wear suspected'),
    ('CMC Vellore','IH-CMC-42','Ortho AutoVue Innova','reaction_grade_accuracy',
     4.0,4.0,0.0,'anti_b',true,'2026-05-22','pass','Anti-B agglutination grade matches expected'),
    ('KIMS Hyderabad','IH-KIM-51','Diagast Qwalys','optical_read',
     1.00,1.01,1.0,'anti_a',true,'2026-05-10','pass','Optical density read within 1% — EMT technology'),
    ('KIMS Hyderabad','IH-KIM-52','Diagast Qwalys','carryover_pct',
     0.10,0.08,-20.0,'control',true,'2026-05-10','pass','Carryover 0.08% below limit'),
    ('Kokilaben Mumbai','IH-KKB-61','Ortho Vision','gel_card_fill',
     100.0,92.0,-8.0,'anti_d',false,'2026-07-01','conditional_pass','Gel-card underfill 8% — dispense head recalibrated'),
    ('Yashoda Hyderabad','IH-YSH-71','Bio-Rad IH-500','reaction_grade_accuracy',
     4.0,1.0,75.0,'anti_a',false,'2026-06-28','fail','Anti-A false-weak 1+ vs 4+ — analyzer withheld pending service'),
    ('Narayana Bengaluru','IH-NAR-81','Grifols Erytra','incubation_temp_c',
     37.0,37.1,0.27,'control',true,'2026-07-03','pass','Incubation temp nominal'),
    ('Medanta Gurugram','IH-MDT-91','Immucor Galileo','centrifuge_rpm',
     895,903,0.89,'control',true,'2026-06-25','pass','Centrifuge RPM within tolerance post-PM')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, qclevel, wtol, caldate, verdict, nt);

  -- CAPA seed — attach to specific measurements via device_code
  insert into public.immunohematology_qc_capa_actions_r3558 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('IH-FRT-12','optical_read_error','optical_lamp_aged','replace_optical_lamp','in_progress','iso_15189_deviation','2026-07-10',null,28000.00,'Anti-D optical channel lamp aged — replacement scheduled'),
    ('IH-MNP-21','carryover_exceeded','probe_wash_insufficient','enhance_probe_wash','escalated','patient_safety_alert','2026-06-25',null,15000.00,'Carryover risk to cross-match — wash cycle escalated to OEM'),
    ('IH-AIM-31','reaction_grade_out_of_tolerance','reagent_lot_degraded','replace_reagent_lot','closed','nabl_finding','2026-06-20','2026-06-18',12000.00,'Anti-D reagent lot quarantined; new lot validated'),
    ('IH-AIM-32','incubation_temp_deviation','heater_element_fault','replace_heater_module','verification_pending','iso_15189_deviation','2026-06-22',null,34000.00,'Heater module replaced — verify block temperature uniformity'),
    ('IH-CMC-41','centrifuge_rpm_drift','centrifuge_bearing_wear','service_centrifuge','open','internal_only','2026-05-30',null,22000.00,'Centrifuge bearing service booked with vendor'),
    ('IH-KKB-61','gel_card_fill_defect','gel_card_manufacturing_defect','replace_gel_card_lot','closed','nabl_finding','2026-07-05','2026-07-03',8000.00,'Gel-card lot underfill — lot replaced and revalidated'),
    ('IH-YSH-71','reaction_grade_out_of_tolerance','reagent_lot_degraded','schedule_oem_service','overdue','patient_safety_alert','2026-07-02',null,46000.00,'False-weak Anti-A — analyzer withheld; OEM service overdue'),
    ('IH-MDT-91','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','2026-08-01',null,9000.00,'Routine PM due — scheduled with service partner')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.immunohematology_qc_r3558 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3558_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.immunohematology_qc_r3558)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.immunohematology_qc_r3558 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3558_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3558_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3558_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_model,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.immunohematology_qc_r3558 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3558_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3558_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3558_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.immunohematology_qc_r3558 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3558_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3558_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3558_monthly_qc_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.immunohematology_qc_r3558 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3558_monthly_qc_trend() from public, anon;
grant execute on function public.founder_r3558_monthly_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3558_capa_status_board()
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
  from public.immunohematology_qc_capa_actions_r3558 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3558_capa_status_board() from public, anon;
grant execute on function public.founder_r3558_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3558_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.immunohematology_qc_capa_actions_r3558)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.immunohematology_qc_capa_actions_r3558 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3558_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3558_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3558_accuracy_impact_digest()
returns table(parameter text, checks bigint, out_of_tolerance bigint, worst_deviation_pct numeric, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(max(abs(l.deviation_pct)), 2),
    round(avg(abs(l.deviation_pct)), 2)
  from public.immunohematology_qc_r3558 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3558_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3558_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3558_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  qc_level text,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  tolerance_state text,
  qc_verdict text,
  calibration_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.qc_level,
    l.reference_value, l.measured_value, l.deviation_pct,
    (case when l.within_tolerance then 'in_tolerance' else 'out_of_tolerance' end)::text,
    l.qc_verdict, l.calibration_date, l.notes
  from public.immunohematology_qc_r3558 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3558_high_risk_queue() from public, anon;
grant execute on function public.founder_r3558_high_risk_queue() to authenticated;
