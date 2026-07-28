-- Round 3563: Customer Hospital Cholangioscope (Biliary Endoscope) QC Audit
-- Biliary / SpyGlass endoscope QC — image resolution × light transmission × channel flow × viewing angle × color fidelity × seal leak × tolerance × accuracy deviation × verdict × CAPA

-- =============================================================================
-- TABLE 1: cholangioscope_qc_r3563 — per-parameter cholangioscope QC checks
-- =============================================================================
create table if not exists public.cholangioscope_qc_r3563 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  unit text not null check (unit in (
    'ercp_suite','gi_endoscopy','operation_theatre','day_care'
  )),
  parameter text not null check (parameter in (
    'image_resolution','light_transmission','channel_flow_ml','viewing_angle_deg','color_fidelity','seal_leak_test'
  )),
  check_date date not null,
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_current boolean not null,
  calibration_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cholangioscope_qc_r3563 enable row level security;

create index if not exists idx_cholangioscope_qc_r3563_org on public.cholangioscope_qc_r3563(organization_id);
create index if not exists idx_cholangioscope_qc_r3563_date on public.cholangioscope_qc_r3563(check_date);
create index if not exists idx_cholangioscope_qc_r3563_verdict on public.cholangioscope_qc_r3563(qc_verdict);

-- =============================================================================
-- TABLE 2: cholangioscope_qc_capa_actions_r3563 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cholangioscope_qc_capa_actions_r3563 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cholangioscope_qc_r3563(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'channel_flow_low','seal_leak_failure','image_resolution_degraded','light_transmission_low',
    'viewing_angle_out_of_spec','color_fidelity_drift','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'fiber_bundle_damage','channel_obstruction','seal_gasket_worn','light_guide_degraded',
    'ccd_sensor_aging','white_balance_drift','distal_tip_damage','cleaning_protocol_gap',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_fiber_bundle','clean_flush_channel','replace_seal_gasket','replace_light_guide',
    'replace_image_sensor','recalibrate_white_balance','repair_distal_tip','retrain_reprocessing_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cholangioscope_qc_capa_actions_r3563 enable row level security;

create index if not exists idx_cholangioscope_capa_r3563_log on public.cholangioscope_qc_capa_actions_r3563(qc_log_id);
create index if not exists idx_cholangioscope_capa_r3563_status on public.cholangioscope_qc_capa_actions_r3563(capa_status);

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
  insert into public.cholangioscope_qc_r3563 (
    organization_id, hospital_name, device_code, device_model, unit, parameter, check_date,
    reference_value, measured_value, deviation_pct, within_tolerance, calibration_current,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.unit, q.param, q.cdate::date,
    q.refv::numeric, q.measv::numeric, q.devp::numeric, q.wtol, q.calcur,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','CHOL-APL-01','SpyGlass DS II','ercp_suite','image_resolution','2026-07-05',
     60,58,-3.3,true,true,'2026-01-10','pass','ERCP-suite SpyGlass image resolution within spec'),
    ('Apollo Chennai','CHOL-APL-02','SpyGlass DS II','ercp_suite','light_transmission','2026-07-05',
     100,96,-4.0,true,true,'2026-01-10','pass','Light transmission nominal post-reprocessing'),
    ('Fortis Gurgaon','CHOL-FRT-11','SpyGlass Discover','gi_endoscopy','channel_flow_ml','2026-07-04',
     30,24,-20.0,false,true,'2026-02-02','conditional_pass','Working-channel flow low — flush and recheck required'),
    ('Fortis Gurgaon','CHOL-FRT-12','SpyGlass Discover','gi_endoscopy','seal_leak_test','2026-07-04',
     160,120,-25.0,false,false,'2026-02-02','fail','Leak test failed — pressure hold dropped, water ingress risk'),
    ('Manipal Bengaluru','CHOL-MNP-21','CholangioFlex CHF-B290','operation_theatre','viewing_angle_deg','2026-07-03',
     120,119,-0.8,true,true,'2026-03-01','pass','Viewing angle within tolerance'),
    ('Manipal Bengaluru','CHOL-MNP-22','CholangioFlex CHF-B290','operation_theatre','color_fidelity','2026-07-03',
     95,88,-7.4,false,true,'2026-03-01','conditional_pass','Color fidelity drift — white-balance recalibration due'),
    ('AIIMS Delhi','CHOL-AIM-31','PolyScope 3.0','gi_endoscopy','image_resolution','2026-06-28',
     55,44,-20.0,false,false,'2025-12-15','fail','Image resolution degraded — fiber bundle damage suspected'),
    ('AIIMS Delhi','CHOL-AIM-32','PolyScope 3.0','gi_endoscopy','light_transmission','2026-06-28',
     100,98,-2.0,true,true,'2026-01-20','pass','Light-guide transmission good'),
    ('CMC Vellore','CHOL-CMC-41','eyeMAX Ultra','ercp_suite','channel_flow_ml','2026-06-27',
     30,29,-3.3,true,true,'2026-02-10','pass','Channel flow within spec'),
    ('CMC Vellore','CHOL-CMC-42','eyeMAX Ultra','ercp_suite','seal_leak_test','2026-06-27',
     160,158,-1.3,true,true,'2026-02-10','pass','Leak test pass — seal intact'),
    ('KIMS Hyderabad','CHOL-KIM-51','SpyGlass DS II','day_care','viewing_angle_deg','2026-06-26',
     120,112,-6.7,false,true,'2026-01-05','conditional_pass','Viewing angle reduced — distal-tip inspection scheduled'),
    ('KIMS Hyderabad','CHOL-KIM-52','SpyGlass DS II','day_care','color_fidelity','2026-06-26',
     95,94,-1.1,true,true,'2026-01-05','pass','Color fidelity nominal'),
    ('Yashoda Hyderabad','CHOL-YSH-61','SpyGlass Discover','gi_endoscopy','image_resolution','2026-06-25',
     60,59,-1.7,true,true,'2026-03-12','pass','Image resolution good post-service'),
    ('Kokilaben Mumbai','CHOL-KKB-71','CholangioFlex CHF-B290','operation_theatre','seal_leak_test','2026-06-24',
     160,90,-43.8,false,false,'2025-11-30','fail','Major leak — removed from service, water resistance breached'),
    ('Kokilaben Mumbai','CHOL-KKB-72','CholangioFlex CHF-B290','operation_theatre','channel_flow_ml','2026-06-24',
     30,21,-30.0,false,false,'2025-11-30','fail','Channel obstructed — flow far below spec'),
    ('Medanta Gurugram','CHOL-MDT-81','PolyScope 3.0','gi_endoscopy','light_transmission','2026-06-23',
     100,90,-10.0,false,true,'2026-02-18','conditional_pass','Light transmission low — light-guide cleaning scheduled')
  ) as q(hosp, dcode, dmodel, unit, param, cdate, refv, measv, devp, wtol, calcur, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cholangioscope_qc_capa_actions_r3563 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('CHOL-FRT-11','channel_flow_low','channel_obstruction','clean_flush_channel','in_progress','internal_only','Biomed - R. Nair','2026-07-08',null,6000.00,'Channel flushed; awaiting flow recheck'),
    ('CHOL-FRT-12','seal_leak_failure','seal_gasket_worn','replace_seal_gasket','escalated','patient_safety_alert','Biomed - S. Rao','2026-07-07',null,38000.00,'Leak breach — escalated to OEM, endoscope quarantined'),
    ('CHOL-MNP-22','color_fidelity_drift','white_balance_drift','recalibrate_white_balance','verification_pending','internal_only','QC - A. Menon','2026-07-06',null,3500.00,'White balance recalibrated — verify on next case'),
    ('CHOL-AIM-31','image_resolution_degraded','fiber_bundle_damage','replace_fiber_bundle','open','cdsco_notifiable','Biomed - K. Iyer','2026-07-10',null,145000.00,'Fiber bundle replacement quoted by OEM'),
    ('CHOL-KIM-51','viewing_angle_out_of_spec','distal_tip_damage','repair_distal_tip','open','iso_13485_deviation','Biomed - P. Shah','2026-07-09',null,22000.00,'Distal-tip inspection and repair scheduled'),
    ('CHOL-KKB-71','seal_leak_failure','seal_gasket_worn','remove_from_service','closed','cdsco_notifiable','Biomed - S. Rao','2026-07-02','2026-06-30',52000.00,'Removed from service; seal assembly replaced and leak-tested OK'),
    ('CHOL-KKB-72','channel_flow_low','cleaning_protocol_gap','retrain_reprocessing_staff','overdue','nabh_finding','Reprocessing - L. Das','2026-06-30',null,4000.00,'Reprocessing SOP retraining overdue — vendor delay'),
    ('CHOL-MDT-81','light_transmission_low','light_guide_degraded','replace_light_guide','in_progress','internal_only','Biomed - N. Verma','2026-07-11',null,28000.00,'Light-guide replacement ordered')
  ) as q(dcode, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.cholangioscope_qc_r3563 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3563_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cholangioscope_qc_r3563)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cholangioscope_qc_r3563 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3563_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3563_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3563_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  calibration_overdue bigint,
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
    count(*) filter (where l.calibration_current = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cholangioscope_qc_r3563 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3563_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3563_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3563_parameter_verdict_matrix()
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
  from public.cholangioscope_qc_r3563 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3563_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3563_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3563_monthly_accuracy_trend()
returns table(period date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.check_date)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.cholangioscope_qc_r3563 l
  group by date_trunc('month', l.check_date)
  order by date_trunc('month', l.check_date) desc;
end;
$$;

revoke execute on function public.founder_r3563_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3563_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3563_capa_status_board()
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
  from public.cholangioscope_qc_capa_actions_r3563 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3563_capa_status_board() from public, anon;
grant execute on function public.founder_r3563_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3563_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cholangioscope_qc_capa_actions_r3563)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cholangioscope_qc_capa_actions_r3563 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3563_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3563_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (deviation severity bands)
create or replace function public.founder_r3563_accuracy_impact_digest()
returns table(severity_band text, checks bigint, avg_abs_deviation_pct numeric, out_of_tolerance bigint, failed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    case
      when abs(coalesce(l.deviation_pct,0)) <= 2 then 'within_2pct'
      when abs(coalesce(l.deviation_pct,0)) <= 5 then 'minor_2_5pct'
      when abs(coalesce(l.deviation_pct,0)) <= 10 then 'major_5_10pct'
      else 'critical_over_10pct'
    end as severity_band,
    count(*)::bigint,
    round(avg(abs(coalesce(l.deviation_pct,0))), 2),
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.cholangioscope_qc_r3563 l
  group by 1
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3563_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3563_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / leak-fail / verdict concerns)
create or replace function public.founder_r3563_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  check_date date,
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
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.check_date,
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct, l.notes
  from public.cholangioscope_qc_r3563 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
     or (l.parameter = 'seal_leak_test' and l.within_tolerance = false)
     or abs(coalesce(l.deviation_pct,0)) > 10
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3563_high_risk_queue() from public, anon;
grant execute on function public.founder_r3563_high_risk_queue() to authenticated;
