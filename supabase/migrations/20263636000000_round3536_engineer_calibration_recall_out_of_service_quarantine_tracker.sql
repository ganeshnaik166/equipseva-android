-- Round 3536: Engineer Calibration-Recall / Out-of-Service Quarantine Tracker
-- Calibration-due recall -> out-of-service / quarantine / re-cal disposition tracker
-- Asset × recall reason × service state × disposition × clinical risk × days overdue × CAPA closure

-- =============================================================================
-- TABLE 1: calibration_recall_r3536 — per-asset calibration-recall / quarantine log
-- =============================================================================
create table if not exists public.calibration_recall_r3536 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  device_model text not null,
  asset_tag text not null,
  recall_reason text not null check (recall_reason in (
    'calibration_overdue','failed_verification','damage_suspected','recall_notice','drift_detected','statutory_due'
  )),
  calibration_due date,
  days_overdue int,
  service_state text not null check (service_state in (
    'in_service','flagged','quarantined','out_of_service','recalibrated','condemned'
  )),
  disposition text not null check (disposition in (
    'recalibrate','repair','replace','extend_with_risk','condemn','pending'
  )),
  clinical_risk text not null check (clinical_risk in (
    'low','medium','high','critical'
  )),
  quarantined boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.calibration_recall_r3536 enable row level security;

create index if not exists idx_calibration_recall_r3536_org on public.calibration_recall_r3536(organization_id);
create index if not exists idx_calibration_recall_r3536_due on public.calibration_recall_r3536(calibration_due);
create index if not exists idx_calibration_recall_r3536_state on public.calibration_recall_r3536(service_state);

-- =============================================================================
-- TABLE 2: calibration_recall_capa_actions_r3536 — CAPA & disposition actions
-- =============================================================================
create table if not exists public.calibration_recall_capa_actions_r3536 (
  id uuid primary key default gen_random_uuid(),
  recall_id uuid not null references public.calibration_recall_r3536(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'calibration_overdue','verification_failure','sensor_drift','physical_damage',
    'vendor_recall','statutory_compliance_gap','quarantine_breach','disposition_delay'
  )),
  root_cause text not null check (root_cause in (
    'reference_standard_drift','sensor_end_of_life','mechanical_wear','operator_handling_error',
    'vendor_defect','pm_backlog','documentation_gap','environmental_stress',
    'pending_investigation','spare_unavailable'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_against_standard','replace_sensor','replace_component','repair_and_verify',
    'quarantine_and_tag','condemn_and_scrap','vendor_rma','retrain_staff',
    'update_pm_schedule','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','aerb_reportable','none','internal_only',
    'patient_safety_alert','iso_13485_deviation'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.calibration_recall_capa_actions_r3536 enable row level security;

create index if not exists idx_calibration_recall_capa_r3536_link on public.calibration_recall_capa_actions_r3536(recall_id);
create index if not exists idx_calibration_recall_capa_r3536_status on public.calibration_recall_capa_actions_r3536(capa_status);

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

  -- 16 calibration-recall rows
  insert into public.calibration_recall_r3536 (
    organization_id, engineer_name, hospital_name, device_model, asset_tag, recall_reason,
    calibration_due, days_overdue, service_state, disposition, clinical_risk, quarantined, notes
  )
  select v_org_id, q.eng, q.hosp, q.model, q.tag, q.rreason,
    q.caldue::date, q.odays::int, q.sstate, q.disp, q.crisk, q.quar, q.nt
  from (values
    ('Rajesh Kumar','Apollo Chennai','Infusion Pump Alaris GP','AST-APL-1001','calibration_overdue',
     '2026-05-15',42,'flagged','recalibrate','medium',false,'Flow-rate cal overdue 42 days; flagged pending re-cal slot'),
    ('Rajesh Kumar','Apollo Chennai','Defibrillator Zoll R Series','AST-APL-1002','statutory_due',
     '2026-06-01',27,'quarantined','recalibrate','high',true,'Energy-delivery statutory cal due; quarantined until verified'),
    ('Priya Nair','Fortis Gurgaon','Patient Monitor Philips MX550','AST-FRT-2001','drift_detected',
     '2026-04-20',67,'out_of_service','repair','high',true,'NIBP drift beyond tolerance; out of service pending repair'),
    ('Priya Nair','Fortis Gurgaon','Ventilator Draeger Evita V300','AST-FRT-2002','failed_verification',
     '2026-05-10',47,'quarantined','repair','critical',true,'Tidal-volume verification failed; quarantined ICU ventilator'),
    ('Anil Deshmukh','Manipal Bengaluru','Syringe Pump BBraun Perfusor','AST-MNP-3001','calibration_overdue',
     '2026-06-10',18,'flagged','recalibrate','low',false,'Low-risk cal overdue; flagged, extension under review'),
    ('Anil Deshmukh','Manipal Bengaluru','ECG Machine GE MAC 2000','AST-MNP-3002','recall_notice',
     '2026-05-25',33,'out_of_service','replace','medium',true,'Vendor recall notice on lead board; out of service'),
    ('Sunita Rao','AIIMS Delhi','Anesthesia Machine GE Aisys','AST-AIM-4001','statutory_due',
     '2026-06-15',13,'recalibrated','recalibrate','high',false,'Agent-delivery statutory cal completed; returned to service'),
    ('Sunita Rao','AIIMS Delhi','Pulse Oximeter Masimo Rad-8','AST-AIM-4002','damage_suspected',
     '2026-04-05',82,'condemned','condemn','medium',false,'Housing crack and sensor damage; condemned and scrapped'),
    ('Vikram Singh','CMC Vellore','Infusion Pump Alaris GP','AST-CMC-5001','drift_detected',
     '2026-06-20',8,'flagged','recalibrate','low',false,'Minor flow drift; flagged, low-risk ward pump'),
    ('Vikram Singh','CMC Vellore','Defibrillator Philips HeartStart','AST-CMC-5002','failed_verification',
     '2026-05-05',52,'out_of_service','repair','critical',true,'Shock-energy verification failed; ED unit out of service'),
    ('Meena Iyer','KIMS Hyderabad','Patient Monitor Mindray N17','AST-KIM-6001','calibration_overdue',
     '2026-06-25',3,'in_service','extend_with_risk','low',false,'Cal marginally overdue; extended with documented risk'),
    ('Meena Iyer','KIMS Hyderabad','Ventilator Hamilton C6','AST-KIM-6002','recall_notice',
     '2026-04-15',72,'quarantined','replace','high',true,'Recall on flow sensor; ICU ventilator quarantined pending swap'),
    ('Arjun Menon','Yashoda Hyderabad','Electrosurgical Unit Valleylab','AST-YSH-7001','statutory_due',
     '2026-06-05',23,'recalibrated','recalibrate','medium',false,'Output-power statutory cal done; back in OT service'),
    ('Arjun Menon','Yashoda Hyderabad','Infant Warmer GE Lullaby','AST-YSH-7002','damage_suspected',
     '2026-03-28',90,'out_of_service','replace','critical',true,'Temp-probe damage suspected on NICU warmer; out of service'),
    ('Kavita Joshi','Kokilaben Mumbai','Dialysis Machine Fresenius 4008','AST-KKB-8001','drift_detected',
     '2026-05-20',37,'quarantined','repair','high',true,'Conductivity drift; dialysis unit quarantined pending repair'),
    ('Kavita Joshi','Kokilaben Mumbai','Blood Pressure Monitor Omron HBP','AST-KKB-8002','calibration_overdue',
     '2026-06-28',0,'in_service','recalibrate','low',false,'Cal due today; scheduled recalibration, remains in service')
  ) as q(eng, hosp, model, tag, rreason, caldue, odays, sstate, disp, crisk, quar, nt);

  -- CAPA seed — attach to specific recalls via asset_tag
  insert into public.calibration_recall_capa_actions_r3536 (
    recall_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('AST-FRT-2002','verification_failure','sensor_end_of_life','replace_sensor','in_progress','patient_safety_alert','2026-06-05',null,38000.00,'ICU ventilator flow-sensor replacement in progress'),
    ('AST-CMC-5002','verification_failure','vendor_defect','repair_and_verify','escalated','patient_safety_alert','2026-06-01',null,26000.00,'ED defibrillator shock-energy fault escalated to OEM'),
    ('AST-YSH-7002','physical_damage','sensor_end_of_life','replace_component','open','cdsco_notifiable','2026-06-10',null,55000.00,'NICU warmer temp-probe replacement ordered'),
    ('AST-AIM-4002','physical_damage','mechanical_wear','condemn_and_scrap','closed','internal_only','2026-05-20','2026-05-18',0.00,'Damaged pulse oximeter condemned and scrapped'),
    ('AST-KIM-6002','vendor_recall','vendor_defect','vendor_rma','verification_pending','cdsco_notifiable','2026-06-15',null,42000.00,'Hamilton flow-sensor recall RMA awaiting verification'),
    ('AST-KKB-8001','sensor_drift','reference_standard_drift','recalibrate_against_standard','overdue','nabh_finding','2026-06-08',null,12000.00,'Dialysis conductivity recal past target — vendor delay'),
    ('AST-FRT-2001','sensor_drift','sensor_end_of_life','replace_sensor','in_progress','nabh_finding','2026-06-12',null,18500.00,'MX550 NIBP module replacement underway'),
    ('AST-MNP-3002','vendor_recall','vendor_defect','vendor_rma','open','cdsco_notifiable','2026-06-18',null,31000.00,'GE MAC 2000 lead-board recall — RMA raised')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.calibration_recall_r3536 e
    on e.organization_id = v_org_id and e.asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Service-state distribution
create or replace function public.founder_r3536_service_state_rollup()
returns table(service_state text, assets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.calibration_recall_r3536)
  select l.service_state, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.calibration_recall_r3536 l
  group by l.service_state
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3536_service_state_rollup() from public, anon;
grant execute on function public.founder_r3536_service_state_rollup() to authenticated;

-- 2) Recall-reason scorecard
create or replace function public.founder_r3536_recall_reason_scorecard()
returns table(
  recall_reason text,
  total_assets bigint,
  quarantined_count bigint,
  out_of_service_count bigint,
  condemned_count bigint,
  critical_risk bigint,
  avg_days_overdue numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.recall_reason,
    count(*)::bigint,
    count(*) filter (where l.quarantined = true)::bigint,
    count(*) filter (where l.service_state = 'out_of_service')::bigint,
    count(*) filter (where l.service_state = 'condemned')::bigint,
    count(*) filter (where l.clinical_risk = 'critical')::bigint,
    round(avg(l.days_overdue), 1)
  from public.calibration_recall_r3536 l
  group by l.recall_reason
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3536_recall_reason_scorecard() from public, anon;
grant execute on function public.founder_r3536_recall_reason_scorecard() to authenticated;

-- 3) Recall-reason × clinical-risk matrix
create or replace function public.founder_r3536_reason_risk_matrix()
returns table(recall_reason text, clinical_risk text, assets bigint, quarantined_count bigint, avg_days_overdue numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.recall_reason, l.clinical_risk, count(*)::bigint,
    count(*) filter (where l.quarantined = true)::bigint,
    round(avg(l.days_overdue), 1)
  from public.calibration_recall_r3536 l
  group by l.recall_reason, l.clinical_risk
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3536_reason_risk_matrix() from public, anon;
grant execute on function public.founder_r3536_reason_risk_matrix() to authenticated;

-- 4) Monthly recall trend (by calibration-due month)
create or replace function public.founder_r3536_monthly_recall_trend()
returns table(recall_month date, assets bigint, quarantined_count bigint, out_of_service_count bigint, avg_days_overdue numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_due)::date,
    count(*)::bigint,
    count(*) filter (where l.quarantined = true)::bigint,
    count(*) filter (where l.service_state = 'out_of_service')::bigint,
    round(avg(l.days_overdue), 1)
  from public.calibration_recall_r3536 l
  where l.calibration_due is not null
  group by date_trunc('month', l.calibration_due)
  order by date_trunc('month', l.calibration_due) desc;
end;
$$;

revoke execute on function public.founder_r3536_monthly_recall_trend() from public, anon;
grant execute on function public.founder_r3536_monthly_recall_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3536_capa_status_board()
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
  from public.calibration_recall_capa_actions_r3536 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3536_capa_status_board() from public, anon;
grant execute on function public.founder_r3536_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3536_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.calibration_recall_capa_actions_r3536)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.calibration_recall_capa_actions_r3536 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3536_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3536_root_cause_pareto() to authenticated;

-- 7) Clinical-risk impact digest
create or replace function public.founder_r3536_clinical_risk_digest()
returns table(
  clinical_risk text,
  assets bigint,
  quarantined_count bigint,
  out_of_service_count bigint,
  condemned_count bigint,
  avg_days_overdue numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.clinical_risk,
    count(*)::bigint,
    count(*) filter (where l.quarantined = true)::bigint,
    count(*) filter (where l.service_state = 'out_of_service')::bigint,
    count(*) filter (where l.service_state = 'condemned')::bigint,
    round(avg(l.days_overdue), 1)
  from public.calibration_recall_r3536 l
  group by l.clinical_risk
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3536_clinical_risk_digest() from public, anon;
grant execute on function public.founder_r3536_clinical_risk_digest() to authenticated;

-- 8) High-risk recall queue (critical / out-of-service / aged-overdue / quarantined)
create or replace function public.founder_r3536_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  device_model text,
  asset_tag text,
  recall_reason text,
  calibration_due date,
  days_overdue int,
  service_state text,
  disposition text,
  clinical_risk text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.device_model, l.asset_tag, l.recall_reason,
    l.calibration_due, l.days_overdue, l.service_state, l.disposition, l.clinical_risk, l.notes
  from public.calibration_recall_r3536 l
  where l.clinical_risk in ('high','critical')
     or l.service_state in ('out_of_service','condemned','quarantined')
     or l.days_overdue >= 45
     or l.quarantined = true
  order by l.days_overdue desc nulls last, l.clinical_risk;
end;
$$;

revoke execute on function public.founder_r3536_high_risk_queue() from public, anon;
grant execute on function public.founder_r3536_high_risk_queue() to authenticated;
