-- Round 3234: Customer Hospital Laparoscopic-Insufflator CO2-Purity & Flow-Calibration Audit
-- Insufflator QA — CO2 source × gas purity × set/measured flow × flow error × pressure-limit × over-pressure relief × heater × filter × CAPA

-- =============================================================================
-- TABLE 1: insufflator_co2_r3234 — individual insufflator audit runs
-- =============================================================================
create table if not exists public.insufflator_co2_r3234 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  insufflator_asset_tag text not null,
  insufflator_model text not null,
  audit_date date not null,
  co2_source text not null check (co2_source in (
    'medical_grade_cylinder','pipeline_manifold','central_gas_plant','portable_mini_cylinder'
  )),
  gas_purity_pct numeric(5,2) not null,
  purity_grade text not null check (purity_grade in (
    'usp_medical_grade','certified_batch','unverified_supplier','industrial_grade_flagged'
  )),
  set_flow_lpm numeric(5,2) not null,
  measured_flow_lpm numeric(5,2) not null,
  flow_error_pct numeric(5,2) not null,
  flow_calibration_verdict text not null check (flow_calibration_verdict in (
    'within_tolerance','marginal','out_of_tolerance','not_tested'
  )),
  pressure_limit_set_mmhg int not null,
  pressure_limit_measured_mmhg int,
  overpressure_relief_result text not null check (overpressure_relief_result in (
    'pass','fail','sluggish_response','not_tested'
  )),
  heater_function text not null check (heater_function in (
    'working','not_working','intermittent','not_fitted'
  )),
  filter_status text not null check (filter_status in (
    'new_hydrophobic_fitted','due_replacement','expired_in_use','missing','reused_flagged'
  )),
  audit_verdict text not null check (audit_verdict in (
    'pass','conditional_pass','fail','remove_from_service','recalibration_required','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.insufflator_co2_r3234 enable row level security;

create index if not exists idx_insufflator_co2_r3234_org on public.insufflator_co2_r3234(organization_id);
create index if not exists idx_insufflator_co2_r3234_date on public.insufflator_co2_r3234(audit_date);
create index if not exists idx_insufflator_co2_r3234_verdict on public.insufflator_co2_r3234(audit_verdict);

-- =============================================================================
-- TABLE 2: insufflator_co2_capa_actions_r3234 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.insufflator_co2_capa_actions_r3234 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.insufflator_co2_r3234(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'gas_purity_low','flow_error_high','overpressure_relief_fail','heater_fault',
    'filter_expired','pressure_limit_drift','co2_source_nonconforming','calibration_overdue'
  )),
  root_cause text not null check (root_cause in (
    'industrial_cylinder_substitution','flow_sensor_drift','relief_valve_stiction',
    'heater_element_burnout','filter_stock_out','regulator_creep',
    'supplier_certificate_missing','pending_investigation','service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'switch_to_medical_grade_supplier','recalibrate_flow_sensor','replace_relief_valve',
    'replace_heater_element','fit_new_hydrophobic_filter','replace_pressure_regulator',
    'quarantine_unit','schedule_oem_service','retrain_ot_staff','none_required'
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

alter table public.insufflator_co2_capa_actions_r3234 enable row level security;

create index if not exists idx_insufflator_capa_r3234_audit on public.insufflator_co2_capa_actions_r3234(audit_id);
create index if not exists idx_insufflator_capa_r3234_status on public.insufflator_co2_capa_actions_r3234(capa_status);

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

  -- 13 insufflator audit rows
  insert into public.insufflator_co2_r3234 (
    organization_id, hospital_name, ot_room_code, insufflator_asset_tag, insufflator_model,
    audit_date, co2_source, gas_purity_pct, purity_grade,
    set_flow_lpm, measured_flow_lpm, flow_error_pct, flow_calibration_verdict,
    pressure_limit_set_mmhg, pressure_limit_measured_mmhg, overpressure_relief_result,
    heater_function, filter_status, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ot, q.tag, q.model,
    q.ad::date, q.src, q.gp, q.pg,
    q.sf, q.mf, q.fe, q.fv,
    q.pls, q.plm, q.opr,
    q.hf, q.fs, q.av, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','OT-2','INS-APL-101','Karl Storz Endoflator 50',
     '2026-07-02','medical_grade_cylinder',99.98,'usp_medical_grade',20.00,19.60,-2.00,'within_tolerance',
     15,15,'pass','working','new_hydrophobic_fitted','pass','Routine quarterly audit — all parameters nominal'),
    ('Apollo Hyderabad Jubilee Hills','OT-4','INS-APL-102','Olympus UHI-4',
     '2026-07-02','pipeline_manifold',99.95,'certified_batch',35.00,33.20,-5.14,'marginal',
     15,14,'pass','working','due_replacement','conditional_pass','High-flow mode reads 5% low — filter replacement scheduled'),
    ('Fortis Bannerghatta Bengaluru','OT-1','INS-FRT-201','Stryker PneumoSure XL',
     '2026-07-01','medical_grade_cylinder',99.50,'unverified_supplier',20.00,21.80,9.00,'out_of_tolerance',
     15,18,'sluggish_response','working','expired_in_use','fail','Purity certificate missing, flow 9% high, relief sluggish'),
    ('Fortis Bannerghatta Bengaluru','OT-3','INS-FRT-202','Karl Storz Thermoflator',
     '2026-07-01','pipeline_manifold',99.97,'usp_medical_grade',30.00,29.70,-1.00,'within_tolerance',
     15,15,'pass','intermittent','new_hydrophobic_fitted','conditional_pass','Heater cuts out intermittently — hypothermia risk on long cases'),
    ('Manipal Whitefield Bengaluru','OT-2','INS-MNP-301','Olympus UHI-4',
     '2026-06-30','central_gas_plant',99.99,'certified_batch',40.00,39.60,-1.00,'within_tolerance',
     20,20,'pass','working','new_hydrophobic_fitted','pass','Bariatric OT high-flow profile verified'),
    ('Manipal Whitefield Bengaluru','OT-5','INS-MNP-302','Stryker 45L PneumoSure',
     '2026-06-30','portable_mini_cylinder',98.90,'industrial_grade_flagged',15.00,14.80,-1.33,'within_tolerance',
     15,15,'pass','working','reused_flagged','remove_from_service','Industrial-grade CO2 cylinder found connected — unit pulled'),
    ('AIIMS New Delhi Ansari Nagar','OT-7','INS-AIM-401','Karl Storz Endoflator 50',
     '2026-06-29','pipeline_manifold',99.98,'usp_medical_grade',25.00,24.90,-0.40,'within_tolerance',
     15,15,'pass','working','new_hydrophobic_fitted','pass','Teaching OT reference unit'),
    ('AIIMS New Delhi Ansari Nagar','OT-9','INS-AIM-402','Olympus UHI-3',
     '2026-06-29','medical_grade_cylinder',99.96,'certified_batch',20.00,17.40,-13.00,'out_of_tolerance',
     15,12,'not_tested','working','due_replacement','recalibration_required','Flow 13% low and pressure limit reads 12 vs 15 set'),
    ('KIMS Secunderabad','OT-3','INS-KIM-501','Stryker PneumoSure',
     '2026-06-28','medical_grade_cylinder',99.97,'usp_medical_grade',20.00,20.30,1.50,'within_tolerance',
     15,15,'fail','working','new_hydrophobic_fitted','fail','Over-pressure relief did not vent at 20 mmHg bench test'),
    ('Care Hospitals Banjara Hills','OT-1','INS-CAR-601','Karl Storz Thermoflator',
     '2026-06-27','pipeline_manifold',99.94,'certified_batch',30.00,28.90,-3.67,'marginal',
     15,15,'pass','not_working','due_replacement','conditional_pass','Heater element dead — cold CO2 flagged for long lap cases'),
    ('Yashoda Somajiguda Hyderabad','OT-6','INS-YSH-701','Olympus UHI-4',
     '2026-06-26','central_gas_plant',99.99,'usp_medical_grade',35.00,34.80,-0.57,'within_tolerance',
     20,20,'pass','working','new_hydrophobic_fitted','pass','Annual calibration certificate current'),
    ('St John''s Bengaluru','OT-2','INS-STJ-801','Karl Storz Endoflator 40',
     '2026-06-25','medical_grade_cylinder',99.30,'unverified_supplier',20.00,19.90,-0.50,'within_tolerance',
     15,15,'pass','working','missing','fail','Hydrophobic filter missing and purity below 99.5 spec'),
    ('Rainbow Children''s Hyderabad','OT-1','INS-RBW-901','Stryker PneumoSure',
     '2026-06-24','portable_mini_cylinder',99.95,'certified_batch',10.00,10.20,2.00,'within_tolerance',
     12,null,'not_tested','working','new_hydrophobic_fitted','pending_review','Paediatric low-flow unit — pressure bench test pending')
  ) as q(hosp, ot, tag, model, ad, src, gp, pg, sf, mf, fe, fv, pls, plm, opr, hf, fs, av, nt);

  -- CAPA seed — attach to specific audits by asset tag
  insert into public.insufflator_co2_capa_actions_r3234 (
    audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('INS-FRT-201','gas_purity_low','supplier_certificate_missing','switch_to_medical_grade_supplier',
     '2026-07-08',null,'in_progress','cdsco_notifiable',22000.00,'New USP-grade contract with certified batch CoA'),
    ('INS-FRT-201','flow_error_high','flow_sensor_drift','recalibrate_flow_sensor',
     '2026-07-06',null,'open','nabh_finding',9500.00,'OEM calibration kit visit booked'),
    ('INS-MNP-302','co2_source_nonconforming','industrial_cylinder_substitution','quarantine_unit',
     '2026-07-03','2026-06-30','closed','patient_safety_alert',15000.00,'Unit quarantined same day, cylinder vendor delisted'),
    ('INS-KIM-501','overpressure_relief_fail','relief_valve_stiction','replace_relief_valve',
     '2026-07-05',null,'verification_pending','patient_safety_alert',18500.00,'New relief valve fitted — bench retest pending'),
    ('INS-AIM-402','calibration_overdue','service_backlog','schedule_oem_service',
     '2026-07-10',null,'escalated','iso_13485_deviation',26000.00,'Calibration overdue 90 days — escalated to biomedical HOD'),
    ('INS-CAR-601','heater_fault','heater_element_burnout','replace_heater_element',
     '2026-06-24',null,'overdue','internal_only',12500.00,'Element on backorder — overdue 3 days'),
    ('INS-STJ-801','filter_expired','filter_stock_out','fit_new_hydrophobic_filter',
     '2026-07-01','2026-06-26','closed','nabh_finding',1800.00,'Filter stock replenished, fitted and logged')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.insufflator_co2_r3234 e
    on e.organization_id = v_org_id and e.insufflator_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3234_audit_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.insufflator_co2_r3234)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.insufflator_co2_r3234 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3234_audit_verdict_rollup() from public, anon;
grant execute on function public.founder_r3234_audit_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3234_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  removed bigint,
  avg_gas_purity_pct numeric,
  avg_flow_error_pct numeric,
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
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.audit_verdict = 'fail')::bigint,
    count(*) filter (where l.audit_verdict = 'remove_from_service')::bigint,
    round(avg(l.gas_purity_pct), 2),
    round(avg(l.flow_error_pct), 2),
    round(100.0 * count(*) filter (where l.audit_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.insufflator_co2_r3234 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3234_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3234_hospital_scorecard() to authenticated;

-- 3) CO2 source × purity grade matrix
create or replace function public.founder_r3234_source_purity_matrix()
returns table(co2_source text, purity_grade text, audits bigint, passed bigint, avg_purity_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.co2_source, l.purity_grade, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    round(avg(l.gas_purity_pct), 2)
  from public.insufflator_co2_r3234 l
  group by l.co2_source, l.purity_grade
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3234_source_purity_matrix() from public, anon;
grant execute on function public.founder_r3234_source_purity_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3234_daily_audit_trend()
returns table(audit_date date, audits bigint, passed bigint, failed bigint, flow_out_of_tolerance bigint, avg_flow_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict in ('fail','remove_from_service'))::bigint,
    count(*) filter (where l.flow_calibration_verdict = 'out_of_tolerance')::bigint,
    round(avg(l.flow_error_pct), 2)
  from public.insufflator_co2_r3234 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3234_daily_audit_trend() from public, anon;
grant execute on function public.founder_r3234_daily_audit_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3234_capa_status_board()
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
  from public.insufflator_co2_capa_actions_r3234 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3234_capa_status_board() from public, anon;
grant execute on function public.founder_r3234_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3234_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.insufflator_co2_capa_actions_r3234)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.insufflator_co2_capa_actions_r3234 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3234_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3234_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3234_regulatory_impact_digest()
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
  from public.insufflator_co2_capa_actions_r3234 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3234_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3234_regulatory_impact_digest() to authenticated;

-- 8) High-risk units queue (top individual concerns)
create or replace function public.founder_r3234_high_risk_units()
returns table(
  hospital_name text,
  ot_room_code text,
  insufflator_asset_tag text,
  audit_date date,
  audit_verdict text,
  flow_calibration_verdict text,
  overpressure_relief_result text,
  heater_function text,
  filter_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_room_code, l.insufflator_asset_tag, l.audit_date,
    l.audit_verdict, l.flow_calibration_verdict, l.overpressure_relief_result,
    l.heater_function, l.filter_status, l.notes
  from public.insufflator_co2_r3234 l
  where l.audit_verdict in ('fail','remove_from_service','recalibration_required','pending_review','conditional_pass')
     or l.flow_calibration_verdict = 'out_of_tolerance'
     or l.overpressure_relief_result in ('fail','sluggish_response')
     or l.filter_status in ('expired_in_use','missing','reused_flagged')
     or l.purity_grade in ('unverified_supplier','industrial_grade_flagged')
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3234_high_risk_units() from public, anon;
grant execute on function public.founder_r3234_high_risk_units() to authenticated;
