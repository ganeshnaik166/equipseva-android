-- Round 3274: Customer Hospital Central-Lab Clinical-Chemistry & Hematology Analyzer QC Audit
-- Central-lab QA — analyzer type × control level × Westgard-rule violation × CV% × bias% × calibration status × reagent-lot × maintenance × EQAS/PT × CAPA

-- =============================================================================
-- TABLE 1: central_lab_qc_r3274 — individual analyzer QC checks (Westgard / Levey-Jennings)
-- =============================================================================
create table if not exists public.central_lab_qc_r3274 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  analyzer_code text not null,
  analyzer_type text not null check (analyzer_type in (
    'clinical_chemistry','hematology_5part','immunoassay','electrolyte_ise','coagulation','urine_analyzer'
  )),
  lab_section text not null,
  check_date date not null,
  control_level text not null check (control_level in (
    'level_1_normal','level_2_abnormal','level_3_high'
  )),
  westgard_rule_violation text not null check (westgard_rule_violation in (
    'none','warn_1_2s','reject_1_3s','reject_2_2s','reject_r_4s','reject_4_1s'
  )),
  cv_percent numeric(5,2),
  bias_percent numeric(5,2),
  calibration_status text not null check (calibration_status in (
    'in_cal','recal_due','recal_overdue'
  )),
  reagent_lot_verified boolean not null default false,
  maintenance_current boolean not null default false,
  eqas_pt_participation_ok boolean not null default false,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','analyzer_grounded'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.central_lab_qc_r3274 enable row level security;

create index if not exists idx_central_lab_qc_r3274_org on public.central_lab_qc_r3274(organization_id);
create index if not exists idx_central_lab_qc_r3274_date on public.central_lab_qc_r3274(check_date);
create index if not exists idx_central_lab_qc_r3274_verdict on public.central_lab_qc_r3274(qc_verdict);

-- =============================================================================
-- TABLE 2: central_lab_qc_capa_actions_r3274 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.central_lab_qc_capa_actions_r3274 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.central_lab_qc_r3274(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'westgard_rule_violation','high_cv_imprecision','bias_out_of_range','calibration_overdue',
    'reagent_lot_issue','maintenance_overdue','eqas_pt_failure'
  )),
  root_cause text not null check (root_cause in (
    'reagent_lot_shift','calibrator_degradation','instrument_drift','pipette_probe_fault',
    'lamp_photometer_aging','operator_technique','temperature_control_fault',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_analyzer','replace_reagent_lot','replace_calibrator','service_pipette_probe',
    'replace_lamp_photometer','retrain_lab_tech','repair_temperature_control',
    'ground_analyzer','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','cap_finding','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.central_lab_qc_capa_actions_r3274 enable row level security;

create index if not exists idx_central_lab_capa_r3274_log on public.central_lab_qc_capa_actions_r3274(qc_log_id);
create index if not exists idx_central_lab_capa_r3274_status on public.central_lab_qc_capa_actions_r3274(capa_status);

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

  -- 14 analyzer QC check rows
  insert into public.central_lab_qc_r3274 (
    organization_id, hospital_name, analyzer_code, analyzer_type, lab_section,
    check_date, control_level, westgard_rule_violation, cv_percent, bias_percent,
    calibration_status, reagent_lot_verified, maintenance_current, eqas_pt_participation_ok,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.acode, q.atype, q.sec,
    q.cdate::date, q.clevel, q.wrv, q.cv, q.bias,
    q.calst, q.rlv, q.mc, q.eqas,
    q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','CHEM-APL-01','clinical_chemistry','biochemistry','2026-07-02','level_1_normal','none',1.80,0.90,'in_cal',true,true,true,'pass','Daily QC — Levey-Jennings in control across the panel'),
    ('Apollo Chennai Greams Road','HEM-APL-02','hematology_5part','hematology','2026-07-02','level_2_abnormal','warn_1_2s',2.40,1.60,'in_cal',true,true,true,'conditional_pass','1_2s warning on abnormal control — monitored, no reject'),
    ('Fortis Gurgaon','CHEM-FRT-01','clinical_chemistry','biochemistry','2026-07-01','level_2_abnormal','reject_1_3s',4.10,3.20,'recal_due',true,true,true,'fail','1_3s reject on level 2 — recalibration triggered'),
    ('Fortis Gurgaon','IMM-FRT-02','immunoassay','immunoassay','2026-07-01','level_1_normal','reject_2_2s',3.60,2.90,'recal_due',false,true,true,'fail','2_2s across two levels — reagent lot suspect'),
    ('Manipal Bengaluru Old Airport Road','ISE-MNP-01','electrolyte_ise','biochemistry','2026-06-30','level_3_high','none',1.50,0.70,'in_cal',true,true,true,'pass','ISE electrolyte module within tolerance'),
    ('Manipal Bengaluru Old Airport Road','COAG-MNP-02','coagulation','coagulation','2026-06-30','level_2_abnormal','warn_1_2s',2.90,2.10,'in_cal',true,false,true,'conditional_pass','PT/INR 1_2s warn; preventive maintenance overdue on analyzer'),
    ('AIIMS Delhi Ansari Nagar','CHEM-AIM-01','clinical_chemistry','biochemistry','2026-06-29','level_2_abnormal','reject_r_4s',3.90,1.20,'recal_overdue',true,true,false,'fail','R_4s range violation and EQAS PT flagged — recal overdue'),
    ('AIIMS Delhi Ansari Nagar','HEM-AIM-02','hematology_5part','hematology','2026-06-29','level_1_normal','none',1.70,0.80,'in_cal',true,true,true,'pass','CBC 5-part differential QC nominal'),
    ('CMC Vellore','IMM-CMC-01','immunoassay','immunoassay','2026-06-28','level_3_high','reject_4_1s',3.30,2.60,'recal_due',true,true,true,'fail','4_1s trend — systematic bias on high control'),
    ('CMC Vellore','URN-CMC-02','urine_analyzer','urinalysis','2026-06-28','level_1_normal','none',2.00,1.00,'in_cal',true,true,true,'pass','Urine chemistry strip QC passed'),
    ('KIMS Hyderabad','CHEM-KIM-01','clinical_chemistry','biochemistry','2026-06-27','level_2_abnormal','warn_1_2s',2.60,1.90,'in_cal',true,true,false,'conditional_pass','1_2s warn plus prior EQAS PT miss — watch'),
    ('KIMS Hyderabad','ISE-KIM-02','electrolyte_ise','biochemistry','2026-06-27','level_2_abnormal','reject_1_3s',4.50,3.80,'recal_overdue',false,false,false,'analyzer_grounded','1_3s reject, recal overdue, PM overdue, reagent unverified — grounded'),
    ('Yashoda Somajiguda Hyderabad','COAG-YSH-01','coagulation','coagulation','2026-06-26','level_1_normal','none',1.90,0.60,'in_cal',true,true,true,'pass','APTT/PT controls in range'),
    ('Rainbow Children''s Hyderabad','HEM-RBW-01','hematology_5part','hematology','2026-06-26','level_2_abnormal','reject_2_2s',3.70,2.40,'recal_due',true,true,true,'fail','Paediatric CBC 2_2s reject on abnormal control')
  ) as q(hosp, acode, atype, sec, cdate, clevel, wrv, cv, bias, calst, rlv, mc, eqas, qv, nt);

  -- CAPA seed — attach to specific checks via analyzer_code
  insert into public.central_lab_qc_capa_actions_r3274 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CHEM-FRT-01','westgard_rule_violation','calibrator_degradation','replace_calibrator','in_progress','nabl_finding','2026-07-06',null,22000.00,'1_3s reject — calibrator lot replaced, awaiting revalidation'),
    ('IMM-FRT-02','reagent_lot_issue','reagent_lot_shift','replace_reagent_lot','escalated','patient_safety_alert','2026-07-05',null,38000.00,'2_2s systematic shift traced to reagent lot — escalated to OEM'),
    ('CHEM-AIM-01','eqas_pt_failure','instrument_drift','recalibrate_analyzer','open','cap_finding','2026-07-08',null,15000.00,'R_4s and EQAS PT fail — full recalibration scheduled'),
    ('IMM-CMC-01','bias_out_of_range','lamp_photometer_aging','replace_lamp_photometer','verification_pending','iso_15189_deviation','2026-07-04',null,46000.00,'4_1s systematic bias — photometer lamp replaced, verifying'),
    ('ISE-KIM-02','calibration_overdue','pipette_probe_fault','service_pipette_probe','escalated','nabl_finding','2026-07-03',null,54000.00,'Analyzer grounded — probe fault plus overdue recal, OEM service'),
    ('HEM-RBW-01','westgard_rule_violation','reagent_lot_shift','replace_reagent_lot','closed','internal_only','2026-07-01','2026-06-27',12000.00,'2_2s reject — abnormal control lot replaced, back in control'),
    ('COAG-MNP-02','maintenance_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-24',null,9000.00,'PM overdue on coagulation analyzer — vendor delayed')
  ) as q(acode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.central_lab_qc_r3274 e
    on e.organization_id = v_org_id and e.analyzer_code = q.acode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3274_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.central_lab_qc_r3274)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.central_lab_qc_r3274 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3274_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3274_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3274_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  westgard_reject bigint,
  recal_overdue bigint,
  eqas_pt_fail bigint,
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
    count(*) filter (where l.qc_verdict in ('fail','analyzer_grounded'))::bigint,
    count(*) filter (where l.westgard_rule_violation in ('reject_1_3s','reject_2_2s','reject_r_4s','reject_4_1s'))::bigint,
    count(*) filter (where l.calibration_status = 'recal_overdue')::bigint,
    count(*) filter (where l.eqas_pt_participation_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.central_lab_qc_r3274 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3274_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3274_hospital_scorecard() to authenticated;

-- 3) Analyzer type × control level matrix
create or replace function public.founder_r3274_analyzer_control_matrix()
returns table(analyzer_type text, control_level text, checks bigint, passed bigint, avg_cv_percent numeric, avg_bias_percent numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.analyzer_type, l.control_level, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.cv_percent), 2),
    round(avg(l.bias_percent), 2)
  from public.central_lab_qc_r3274 l
  group by l.analyzer_type, l.control_level
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3274_analyzer_control_matrix() from public, anon;
grant execute on function public.founder_r3274_analyzer_control_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3274_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, westgard_reject bigint, recal_overdue bigint)
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
    count(*) filter (where l.qc_verdict in ('fail','analyzer_grounded'))::bigint,
    count(*) filter (where l.westgard_rule_violation in ('reject_1_3s','reject_2_2s','reject_r_4s','reject_4_1s'))::bigint,
    count(*) filter (where l.calibration_status = 'recal_overdue')::bigint
  from public.central_lab_qc_r3274 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3274_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3274_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3274_capa_status_board()
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
  from public.central_lab_qc_capa_actions_r3274 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3274_capa_status_board() from public, anon;
grant execute on function public.founder_r3274_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3274_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.central_lab_qc_capa_actions_r3274)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.central_lab_qc_capa_actions_r3274 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3274_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3274_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3274_regulatory_impact_digest()
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
  from public.central_lab_qc_capa_actions_r3274 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3274_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3274_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3274_high_risk_queue()
returns table(
  hospital_name text,
  analyzer_code text,
  analyzer_type text,
  lab_section text,
  check_date date,
  qc_verdict text,
  westgard_rule_violation text,
  calibration_status text,
  cv_percent numeric,
  bias_percent numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.analyzer_code, l.analyzer_type, l.lab_section, l.check_date,
    l.qc_verdict, l.westgard_rule_violation, l.calibration_status, l.cv_percent, l.bias_percent,
    l.notes
  from public.central_lab_qc_r3274 l
  where l.qc_verdict in ('conditional_pass','fail','analyzer_grounded')
     or l.westgard_rule_violation in ('reject_1_3s','reject_2_2s','reject_r_4s','reject_4_1s')
     or l.calibration_status = 'recal_overdue'
     or l.eqas_pt_participation_ok = false
     or l.reagent_lot_verified = false
     or l.maintenance_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3274_high_risk_queue() from public, anon;
grant execute on function public.founder_r3274_high_risk_queue() to authenticated;
