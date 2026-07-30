-- Round 3594: Customer Hospital OT Isolation Power Supply (IPS) / Line Isolation Monitor (LIM) QC Audit
-- OT electrical-safety QA — device model × parameter × isolation resistance / leakage / hazard current / transformer load / LIM alarm setpoint / ground continuity × tolerance × verdict × CAPA

-- =============================================================================
-- TABLE 1: ot_ips_lim_qc_r3594 — per-device IPS/LIM electrical-safety QC checks
-- =============================================================================
create table if not exists public.ot_ips_lim_qc_r3594 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  ot_location text not null,
  parameter text not null check (parameter in (
    'isolation_resistance_kohm','line_leakage_current_ma','hazard_current_ma',
    'transformer_load_pct','lim_alarm_threshold_ma','ground_continuity_ohm'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  alarm_functional boolean not null,
  calibration_date date not null,
  next_due_date date,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ot_ips_lim_qc_r3594 enable row level security;

create index if not exists idx_ot_ips_lim_qc_r3594_org on public.ot_ips_lim_qc_r3594(organization_id);
create index if not exists idx_ot_ips_lim_qc_r3594_date on public.ot_ips_lim_qc_r3594(calibration_date);
create index if not exists idx_ot_ips_lim_qc_r3594_verdict on public.ot_ips_lim_qc_r3594(qc_verdict);

-- =============================================================================
-- TABLE 2: ot_ips_lim_qc_capa_actions_r3594 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ot_ips_lim_qc_capa_actions_r3594 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ot_ips_lim_qc_r3594(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'isolation_resistance_low','leakage_current_high','hazard_current_exceeded',
    'transformer_overload','lim_alarm_threshold_drift','ground_continuity_high',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'insulation_degradation','moisture_ingress','transformer_winding_fault','lim_sensor_drift',
    'loose_ground_connection','cable_insulation_damage','connected_load_excess',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_isolation_transformer','dry_and_reinsulate','recalibrate_lim','retighten_ground_bond',
    'replace_damaged_cable','redistribute_connected_load','retrain_ot_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iec_60364_710_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ot_ips_lim_qc_capa_actions_r3594 enable row level security;

create index if not exists idx_ot_ips_lim_capa_r3594_log on public.ot_ips_lim_qc_capa_actions_r3594(qc_log_id);
create index if not exists idx_ot_ips_lim_capa_r3594_status on public.ot_ips_lim_qc_capa_actions_r3594(capa_status);

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

  -- 16 QC check rows
  insert into public.ot_ips_lim_qc_r3594 (
    organization_id, hospital_name, device_code, device_model, ot_location, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, alarm_functional,
    calibration_date, next_due_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.model, q.otl, q.param,
    q.refv::numeric, q.measv::numeric, q.devp::numeric, q.wtol, q.alarm,
    q.caldt::date, q.nxtdt::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','IPS-APL-OT1','Bender IsoMed 427','OT-1 Cardiac','hazard_current_ma',
     5.0,3.6,-28.0,true,true,'2026-07-05','2027-01-05',true,'pass','LIM hazard current 3.6 mA well below 5 mA alarm setpoint'),
    ('Apollo Chennai','IPS-APL-OT2','Bender 107TD47','OT-2 Neuro','isolation_resistance_kohm',
     200.0,215.0,7.5,true,true,'2026-07-05','2027-01-05',true,'pass','Isolation resistance healthy, LIM display nominal'),
    ('Fortis Gurgaon','IPS-FRT-OT1','Schneider Vigilohm','OT-1 Ortho','line_leakage_current_ma',
     0.5,0.46,-8.0,true,true,'2026-06-28','2026-12-28',true,'pass','Line leakage within IEC 60364-7-710 limits'),
    ('Fortis Gurgaon','IPS-FRT-OT2','Bender IsoMed 427','OT-2 Cardiac','lim_alarm_threshold_ma',
     5.0,5.9,18.0,false,true,'2026-06-28','2026-12-28',true,'conditional_pass','LIM alarm setpoint drifted to 5.9 mA — recalibration advised'),
    ('Manipal Bengaluru','IPS-MNP-OT1','IME OT Panel LIM','OT-1 General','transformer_load_pct',
     80.0,92.0,15.0,false,true,'2026-06-25','2026-12-25',true,'conditional_pass','Isolation transformer loaded to 92% — redistribute connected equipment'),
    ('Manipal Bengaluru','IPS-MNP-OT2','Legrand LIM 340','OT-2 Neuro','ground_continuity_ohm',
     0.20,0.11,-45.0,true,true,'2026-06-25','2026-12-25',true,'pass','Protective earth continuity 0.11 ohm — pass'),
    ('AIIMS Delhi','IPS-AIM-OT1','Bender 107TD47','OT-1 Trauma','isolation_resistance_kohm',
     200.0,48.0,-76.0,false,false,'2026-06-20','2026-12-20',true,'fail','Isolation resistance collapsed to 48 kohm, LIM alarm did not annunciate — line isolated'),
    ('AIIMS Delhi','IPS-AIM-OT2','Schneider Vigilohm','OT-2 Cardiac','hazard_current_ma',
     5.0,6.8,36.0,false,true,'2026-06-20','2026-12-20',true,'fail','Hazard current 6.8 mA above 5 mA threshold — leakage source under investigation'),
    ('CMC Vellore','IPS-CMC-OT1','IME OT Panel LIM','OT-1 General','line_leakage_current_ma',
     0.5,0.44,-12.0,true,true,'2026-06-18','2026-12-18',true,'pass','Leakage current normal post-PM'),
    ('CMC Vellore','IPS-CMC-OT2','Bender IsoMed 427','OT-2 Ortho','ground_continuity_ohm',
     0.20,0.28,40.0,false,true,'2026-06-18','2026-12-18',false,'conditional_pass','Ground continuity 0.28 ohm — loose bonding, calibration overdue'),
    ('KIMS Hyderabad','IPS-KIM-OT1','Legrand LIM 340','OT-1 Cardiac','transformer_load_pct',
     80.0,58.0,-27.5,true,true,'2026-06-15','2026-12-15',true,'pass','Transformer load 58% — headroom adequate'),
    ('KIMS Hyderabad','IPS-KIM-OT2','Bender 107TD47','OT-2 Neuro','lim_alarm_threshold_ma',
     5.0,5.1,2.0,true,true,'2026-06-15','2026-12-15',true,'pass','LIM alarm setpoint verified at 5.1 mA — within band'),
    ('Yashoda Hyderabad','IPS-YSH-OT1','Schneider Vigilohm','OT-1 General','isolation_resistance_kohm',
     200.0,190.0,-5.0,true,true,'2026-06-12','2026-12-12',true,'pass','Isolation resistance stable'),
    ('Yashoda Hyderabad','IPS-YSH-OT2','IME OT Panel LIM','OT-2 Cardiac','hazard_current_ma',
     5.0,4.9,-2.0,true,false,'2026-06-12','2026-12-12',true,'conditional_pass','Hazard current fine but LIM audible alarm inoperative on test'),
    ('Kokilaben Mumbai','IPS-KKB-OT1','Bender IsoMed 427','OT-1 Neuro','transformer_load_pct',
     80.0,104.0,30.0,false,false,'2026-06-08','2026-12-08',false,'fail','Transformer overloaded at 104% with alarm fault and calibration overdue — removed from schedule'),
    ('Kokilaben Mumbai','IPS-KKB-OT2','Legrand LIM 340','OT-2 Ortho','line_leakage_current_ma',
     0.5,0.72,44.0,false,true,'2026-06-08','2026-12-08',true,'fail','Line leakage 0.72 mA exceeds limit — cable insulation damage suspected')
  ) as q(hosp, dcode, model, otl, param, refv, measv, devp, wtol, alarm, caldt, nxtdt, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.ot_ips_lim_qc_capa_actions_r3594 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('IPS-AIM-OT1','isolation_resistance_low','insulation_degradation','replace_isolation_transformer','escalated','patient_safety_alert','2026-06-24',null,185000.00,'Isolation resistance collapse with LIM alarm miss — transformer replacement escalated to OEM'),
    ('IPS-AIM-OT2','leakage_current_high','cable_insulation_damage','replace_damaged_cable','in_progress','cdsco_notifiable','2026-06-27',null,24000.00,'Hazard current above threshold — tracing leakage circuit'),
    ('IPS-FRT-OT2','lim_alarm_threshold_drift','lim_sensor_drift','recalibrate_lim','verification_pending','internal_only','2026-07-04',null,6500.00,'LIM setpoint recalibrated to 5.0 mA — verify next round'),
    ('IPS-MNP-OT1','transformer_overload','connected_load_excess','redistribute_connected_load','closed','nabh_finding','2026-06-30','2026-06-29',0.00,'Non-essential load moved off IT panel — load now 74%'),
    ('IPS-CMC-OT2','ground_continuity_high','loose_ground_connection','retighten_ground_bond','closed','internal_only','2026-06-22','2026-06-21',1800.00,'Earth bonding retightened, continuity restored to 0.09 ohm'),
    ('IPS-YSH-OT2','lim_alarm_threshold_drift','lim_sensor_drift','recalibrate_lim','open','iec_60364_710_deviation','2026-06-20',null,5200.00,'LIM audible alarm inoperative — module recalibration/repair scheduled'),
    ('IPS-KKB-OT1','transformer_overload','transformer_winding_fault','replace_isolation_transformer','overdue','patient_safety_alert','2026-06-14',null,210000.00,'Overloaded transformer with alarm fault — replacement overdue, vendor delay'),
    ('IPS-KKB-OT2','leakage_current_high','moisture_ingress','dry_and_reinsulate','in_progress','cdsco_notifiable','2026-06-13',null,15000.00,'Suspected moisture ingress on OT cabling — drying and reinsulation underway')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ot_ips_lim_qc_r3594 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3594_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_ips_lim_qc_r3594)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ot_ips_lim_qc_r3594 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3594_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3594_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3594_device_model_scorecard()
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
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ot_ips_lim_qc_r3594 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3594_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3594_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3594_parameter_verdict_matrix()
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
    round(avg(l.deviation_pct), 2)
  from public.ot_ips_lim_qc_r3594 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3594_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3594_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3594_monthly_trend()
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
    round(avg(l.deviation_pct), 2)
  from public.ot_ips_lim_qc_r3594 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3594_monthly_trend() from public, anon;
grant execute on function public.founder_r3594_monthly_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3594_capa_status_board()
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
  from public.ot_ips_lim_qc_capa_actions_r3594 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3594_capa_status_board() from public, anon;
grant execute on function public.founder_r3594_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3594_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_ips_lim_qc_capa_actions_r3594)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ot_ips_lim_qc_capa_actions_r3594 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3594_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3594_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3594_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  within_tolerance_pct numeric,
  avg_deviation_pct numeric,
  max_abs_deviation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter,
    count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(100.0 * count(*) filter (where l.within_tolerance = true)::numeric / nullif(count(*),0), 1),
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.ot_ips_lim_qc_r3594 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3594_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3594_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3594_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.calibration_date,
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct, l.notes
  from public.ot_ips_lim_qc_r3594 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.alarm_functional = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3594_high_risk_queue() from public, anon;
grant execute on function public.founder_r3594_high_risk_queue() to authenticated;
