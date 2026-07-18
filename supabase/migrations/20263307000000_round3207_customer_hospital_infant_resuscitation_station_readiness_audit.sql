-- Round 3207: Customer Hospital Infant-Warmer T-Piece Resuscitator & Apgar-Station Readiness Audit
-- Resus station log — location × T-piece PIP/PEEP × blender FiO2 accuracy × suction × laryngoscope × masks × Apgar timer × checklist × CAPA

-- =============================================================================
-- TABLE 1: infant_resus_r3207 — individual resuscitation-station readiness audits
-- =============================================================================
create table if not exists public.infant_resus_r3207 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  station_code text not null,
  station_location text not null check (station_location in (
    'labour_delivery_room','operation_theatre','nicu','emergency_room','postnatal_ward','triage_bay'
  )),
  audit_date date not null,
  warmer_model text not null,
  warmer_heater_status text not null check (warmer_heater_status in (
    'heats_to_setpoint','slow_warmup','overshoot','heater_fail','skin_probe_missing'
  )),
  tpiece_pip_setting_cmh2o numeric(4,1),
  tpiece_peep_setting_cmh2o numeric(4,1),
  tpiece_settings_verdict text not null check (tpiece_settings_verdict in (
    'within_target','pip_too_high','pip_too_low','peep_too_high','peep_too_low','not_tested','device_missing'
  )),
  blender_fio2_set_pct int,
  blender_fio2_measured_pct int,
  blender_accuracy_verdict text not null check (blender_accuracy_verdict in (
    'accurate','drift_minor','drift_major','analyzer_unavailable','blender_missing'
  )),
  suction_pressure_mmhg int,
  suction_verdict text not null check (suction_verdict in (
    'within_80_100','too_weak','too_strong','no_vacuum','tubing_missing'
  )),
  laryngoscope_light_status text not null check (laryngoscope_light_status in (
    'bright_white','dim','flickering','dead','blade_missing','spare_bulb_absent'
  )),
  masks_sizes_status text not null check (masks_sizes_status in (
    'complete_00_0_1','size_00_missing','size_0_missing','size_1_missing','multiple_missing','all_missing'
  )),
  apgar_timer_status text not null check (apgar_timer_status in (
    'functional','battery_low','not_working','missing','wall_clock_only'
  )),
  checklist_status text not null check (checklist_status in (
    'current_signed_today','signed_this_week','outdated','missing','unsigned'
  )),
  readiness_verdict text not null check (readiness_verdict in (
    'fully_ready','ready_with_gaps','conditional','not_ready','out_of_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.infant_resus_r3207 enable row level security;

create index if not exists idx_infant_resus_r3207_org on public.infant_resus_r3207(organization_id);
create index if not exists idx_infant_resus_r3207_date on public.infant_resus_r3207(audit_date);
create index if not exists idx_infant_resus_r3207_verdict on public.infant_resus_r3207(readiness_verdict);

-- =============================================================================
-- TABLE 2: infant_resus_capa_actions_r3207 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.infant_resus_capa_actions_r3207 (
  id uuid primary key default gen_random_uuid(),
  resus_audit_id uuid not null references public.infant_resus_r3207(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'tpiece_setting_deviation','blender_fio2_drift','suction_failure','laryngoscope_light_fail',
    'mask_inventory_gap','apgar_timer_fail','checklist_lapse','warmer_heater_fault','training_gap','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'device_calibration_overdue','battery_not_replaced','consumable_stockout',
    'staff_turnover_untrained','biomed_service_backlog','vacuum_line_leak',
    'bulb_life_exceeded','checklist_ownership_unclear','oxygen_analyzer_cell_expired','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_blender','replace_laryngoscope_bulb','restock_mask_sizes',
    'replace_timer_battery','repair_vacuum_line','retrain_staff_nrp',
    'assign_checklist_owner','schedule_biomed_pm','replace_analyzer_cell','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','nrp_protocol_deviation','none','internal_only','patient_safety_alert','laqshya_finding'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.infant_resus_capa_actions_r3207 enable row level security;

create index if not exists idx_infant_resus_capa_r3207_audit on public.infant_resus_capa_actions_r3207(resus_audit_id);
create index if not exists idx_infant_resus_capa_r3207_status on public.infant_resus_capa_actions_r3207(capa_status);

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

  -- 14 station audit rows
  insert into public.infant_resus_r3207 (
    organization_id, hospital_name, station_code, station_location, audit_date,
    warmer_model, warmer_heater_status,
    tpiece_pip_setting_cmh2o, tpiece_peep_setting_cmh2o, tpiece_settings_verdict,
    blender_fio2_set_pct, blender_fio2_measured_pct, blender_accuracy_verdict,
    suction_pressure_mmhg, suction_verdict,
    laryngoscope_light_status, masks_sizes_status, apgar_timer_status, checklist_status,
    readiness_verdict, notes
  )
  select v_org_id, q.hosp, q.sc, q.loc, q.ad::date,
    q.wm, q.wh,
    q.pip, q.peep, q.tv,
    q.fs, q.fm, q.bv,
    q.sp, q.sv,
    q.ll, q.ms, q.apg, q.cl,
    q.rv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','RS-APL-LDR1','labour_delivery_room','2026-07-10','GE Panda iRes Warmer','heats_to_setpoint',
     20.0,5.0,'within_target',21,21,'accurate',90,'within_80_100','bright_white','complete_00_0_1','functional','current_signed_today','fully_ready','Model NRP corner — no gaps found'),
    ('Apollo Hyderabad Jubilee Hills','RS-APL-OT2','operation_theatre','2026-07-10','GE Panda iRes Warmer','heats_to_setpoint',
     22.0,5.0,'pip_too_high',21,24,'drift_minor',95,'within_80_100','dim','complete_00_0_1','functional','signed_this_week','ready_with_gaps','PIP dialed 22 vs target 20; laryngoscope light dim'),
    ('Fortis Bannerghatta Bengaluru','RS-FRT-NICU1','nicu','2026-07-09','Drager Babyroo TN300','heats_to_setpoint',
     20.0,5.0,'within_target',30,36,'drift_major',88,'within_80_100','bright_white','size_0_missing','functional','current_signed_today','conditional','Blender reads 36% at 30% set — analyzer confirms drift'),
    ('Fortis Bannerghatta Bengaluru','RS-FRT-LDR3','labour_delivery_room','2026-07-09','Drager Resuscitaire','slow_warmup',
     20.0,5.0,'within_target',21,null,'analyzer_unavailable',40,'too_weak','bright_white','complete_00_0_1','battery_low','signed_this_week','ready_with_gaps','Suction only 40 mmHg — vacuum line leak suspected'),
    ('Manipal Whitefield Bengaluru','RS-MNP-LDR2','labour_delivery_room','2026-07-08','Phoenix Warmer WIT-100','heats_to_setpoint',
     18.0,4.0,'peep_too_low',21,21,'accurate',92,'within_80_100','flickering','complete_00_0_1','functional','outdated','conditional','PEEP at 4 cmH2O; checklist last signed 3 weeks ago'),
    ('Manipal Whitefield Bengaluru','RS-MNP-OT1','operation_theatre','2026-07-08','Phoenix Warmer WIT-100','heats_to_setpoint',
     20.0,5.0,'within_target',21,22,'accurate',100,'within_80_100','bright_white','complete_00_0_1','functional','current_signed_today','fully_ready','Clean audit — OT resus trolley exemplary'),
    ('AIIMS New Delhi Ansari Nagar','RS-AIM-NICU2','nicu','2026-07-07','GE Giraffe Warmer','heats_to_setpoint',
     20.0,5.0,'within_target',21,21,'accurate',85,'within_80_100','bright_white','complete_00_0_1','functional','current_signed_today','fully_ready','NRP instructor-led station'),
    ('AIIMS New Delhi Ansari Nagar','RS-AIM-ER1','emergency_room','2026-07-07','Zeal Medical RHW1100','skin_probe_missing',
     25.0,8.0,'pip_too_high',21,null,'blender_missing',null,'no_vacuum','dead','multiple_missing','missing','missing','not_ready','ER backup station stripped for parts — immediate escalation'),
    ('KIMS Secunderabad','RS-KIM-LDR1','labour_delivery_room','2026-07-06','Neokraft NK-100','heats_to_setpoint',
     20.0,5.0,'within_target',21,21,'accurate',110,'too_strong','bright_white','complete_00_0_1','functional','signed_this_week','ready_with_gaps','Suction regulator left at 110 mmHg — retraining needed'),
    ('Care Hospitals Banjara Hills','RS-CAR-LDR1','labour_delivery_room','2026-07-06','Drager Resuscitaire','heats_to_setpoint',
     20.0,5.0,'within_target',21,23,'drift_minor',90,'within_80_100','bright_white','size_00_missing','wall_clock_only','current_signed_today','ready_with_gaps','Preemie mask 00 out of stock; no dedicated Apgar timer'),
    ('Yashoda Somajiguda Hyderabad','RS-YSH-OT3','operation_theatre','2026-07-05','GE Panda Warmer','heats_to_setpoint',
     20.0,5.0,'within_target',21,21,'accurate',95,'within_80_100','bright_white','complete_00_0_1','functional','current_signed_today','fully_ready','Ready — quarterly biomed PM completed last week'),
    ('St John''s Bengaluru','RS-STJ-PNW1','postnatal_ward','2026-07-05','Phoenix Warmer WIT-100','heats_to_setpoint',
     16.0,3.0,'pip_too_low',21,21,'accurate',90,'within_80_100','spare_bulb_absent','complete_00_0_1','functional','unsigned','conditional','PIP 16 below 20 target; no spare bulb in drawer'),
    ('Rainbow Children''s Hyderabad','RS-RBW-NICU1','nicu','2026-07-04','Drager Babyroo TN300','heats_to_setpoint',
     20.0,5.0,'within_target',30,31,'accurate',90,'within_80_100','bright_white','complete_00_0_1','functional','current_signed_today','fully_ready','Level III NICU — exemplar station'),
    ('Rainbow Children''s Hyderabad','RS-RBW-TRG1','triage_bay','2026-07-04','Zeal Medical RHW1100','heater_fail',
     20.0,5.0,'not_tested',21,null,'analyzer_unavailable',88,'within_80_100','dim','size_1_missing','battery_low','outdated','out_of_service','Triage warmer heater fault — station taken out of service')
  ) as q(hosp, sc, loc, ad, wm, wh, pip, peep, tv, fs, fm, bv, sp, sv, ll, ms, apg, cl, rv, nt);

  -- CAPA seed — attach to specific stations
  insert into public.infant_resus_capa_actions_r3207 (
    resus_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('RS-FRT-NICU1','blender_fio2_drift','oxygen_analyzer_cell_expired','recalibrate_blender','2026-07-14',null,'in_progress','patient_safety_alert',9500.00,'Loaner blender installed; O2 cell on order'),
    ('RS-FRT-LDR3','suction_failure','vacuum_line_leak','repair_vacuum_line','2026-07-13','2026-07-11','closed','nabh_finding',6200.00,'Wall vacuum joint resealed; retest reads 92 mmHg'),
    ('RS-AIM-ER1','mask_inventory_gap','consumable_stockout','restock_mask_sizes','2026-07-12',null,'overdue','laqshya_finding',1800.00,'Sizes 00 and 0 missing; store indent pending 9 days'),
    ('RS-AIM-ER1','warmer_heater_fault','biomed_service_backlog','schedule_biomed_pm','2026-07-20',null,'escalated','patient_safety_alert',52000.00,'ER station cannibalized — full rebuild quoted'),
    ('RS-MNP-LDR2','checklist_lapse','checklist_ownership_unclear','assign_checklist_owner','2026-07-12','2026-07-10','closed','internal_only',0.00,'Shift in-charge now owns daily sign-off'),
    ('RS-KIM-LDR1','training_gap','staff_turnover_untrained','retrain_staff_nrp','2026-07-18',null,'in_progress','nrp_protocol_deviation',15000.00,'NRP refresher scheduled for 12 LDR nurses'),
    ('RS-RBW-TRG1','apgar_timer_fail','battery_not_replaced','replace_timer_battery','2026-07-09',null,'verification_pending','internal_only',350.00,'Battery replaced; awaiting night-shift verification'),
    ('RS-STJ-PNW1','laryngoscope_light_fail','bulb_life_exceeded','replace_laryngoscope_bulb','2026-07-16',null,'open','none',450.00,'Spare LED bulb indent raised')
  ) as q(sck, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.infant_resus_r3207 e
    on e.organization_id = v_org_id and e.station_code = q.sck;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness verdict distribution
create or replace function public.founder_r3207_readiness_verdict_rollup()
returns table(readiness_verdict text, stations bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.infant_resus_r3207)
  select l.readiness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.infant_resus_r3207 l
  group by l.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3207_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3207_readiness_verdict_rollup() to authenticated;

-- 2) Hospital-level readiness scorecard
create or replace function public.founder_r3207_hospital_scorecard()
returns table(
  hospital_name text,
  total_stations bigint,
  fully_ready bigint,
  not_ready bigint,
  blender_drift bigint,
  suction_issues bigint,
  mask_gaps bigint,
  readiness_pct numeric
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
    count(*) filter (where l.readiness_verdict = 'fully_ready')::bigint,
    count(*) filter (where l.readiness_verdict in ('not_ready','out_of_service'))::bigint,
    count(*) filter (where l.blender_accuracy_verdict in ('drift_minor','drift_major'))::bigint,
    count(*) filter (where l.suction_verdict <> 'within_80_100')::bigint,
    count(*) filter (where l.masks_sizes_status <> 'complete_00_0_1')::bigint,
    round(100.0 * count(*) filter (where l.readiness_verdict = 'fully_ready')::numeric / nullif(count(*),0), 1)
  from public.infant_resus_r3207 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3207_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3207_hospital_scorecard() to authenticated;

-- 3) Station-location × check matrix
create or replace function public.founder_r3207_location_check_matrix()
returns table(station_location text, stations bigint, fully_ready bigint, tpiece_within_target bigint, blender_accurate bigint, avg_suction_mmhg numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.station_location, count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'fully_ready')::bigint,
    count(*) filter (where l.tpiece_settings_verdict = 'within_target')::bigint,
    count(*) filter (where l.blender_accuracy_verdict = 'accurate')::bigint,
    round(avg(l.suction_pressure_mmhg)::numeric, 0)
  from public.infant_resus_r3207 l
  group by l.station_location
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3207_location_check_matrix() from public, anon;
grant execute on function public.founder_r3207_location_check_matrix() to authenticated;

-- 4) Daily readiness trend
create or replace function public.founder_r3207_daily_readiness_trend()
returns table(audit_date date, stations_audited bigint, fully_ready bigint, ready_with_gaps bigint, conditional_or_worse bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'fully_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'ready_with_gaps')::bigint,
    count(*) filter (where l.readiness_verdict in ('conditional','not_ready','out_of_service'))::bigint
  from public.infant_resus_r3207 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3207_daily_readiness_trend() from public, anon;
grant execute on function public.founder_r3207_daily_readiness_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3207_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.infant_resus_capa_actions_r3207 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3207_capa_status_board() from public, anon;
grant execute on function public.founder_r3207_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3207_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.infant_resus_capa_actions_r3207)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.infant_resus_capa_actions_r3207 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3207_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3207_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3207_regulatory_impact_digest()
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
  from public.infant_resus_capa_actions_r3207 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3207_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3207_regulatory_impact_digest() to authenticated;

-- 8) High-risk stations queue (top individual concerns)
create or replace function public.founder_r3207_high_risk_stations()
returns table(
  hospital_name text,
  station_code text,
  station_location text,
  audit_date date,
  readiness_verdict text,
  blender_accuracy_verdict text,
  suction_verdict text,
  laryngoscope_light_status text,
  apgar_timer_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.station_code, l.station_location, l.audit_date,
    l.readiness_verdict, l.blender_accuracy_verdict, l.suction_verdict,
    l.laryngoscope_light_status, l.apgar_timer_status, l.notes
  from public.infant_resus_r3207 l
  where l.readiness_verdict in ('conditional','not_ready','out_of_service')
     or l.blender_accuracy_verdict in ('drift_major','blender_missing')
     or l.suction_verdict in ('too_weak','no_vacuum')
     or l.laryngoscope_light_status in ('dead','flickering')
     or l.apgar_timer_status in ('missing','not_working')
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3207_high_risk_stations() from public, anon;
grant execute on function public.founder_r3207_high_risk_stations() to authenticated;
