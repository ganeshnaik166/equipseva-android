-- Round 3134: Customer Hospital Blood Bank Refrigerator Temperature Excursion & Alarm Compliance Audit
-- Cold-chain event log — appliance type × setpoint × excursion × alarm × product impact × CAPA closure

-- =============================================================================
-- TABLE 1: blood_bank_fridge_event_r3134 — individual temperature / alarm events
-- =============================================================================
create table if not exists public.blood_bank_fridge_event_r3134 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  blood_bank_code text not null,
  appliance_asset_tag text not null,
  appliance_type text not null check (appliance_type in (
    'blood_fridge_2_6c','plasma_freezer_minus30','platelet_incubator_20_24c',
    'cryo_freezer_minus80','reagent_fridge','walk_in_cold_room'
  )),
  appliance_model text not null,
  event_date date not null,
  event_started_at timestamptz not null,
  event_ended_at timestamptz,
  setpoint_low_c numeric(5,2),
  setpoint_high_c numeric(5,2),
  excursion_peak_c numeric(5,2),
  duration_minutes int,
  alarm_type text not null check (alarm_type in (
    'high_temp','low_temp','power_failure','door_ajar','sensor_fault',
    'compressor_fail','battery_backup_low','probe_calibration_due','none'
  )),
  alarm_acknowledged boolean not null default false,
  ack_delay_minutes int,
  product_category text check (product_category in (
    'whole_blood','packed_red_cells','fresh_frozen_plasma','platelets','cryoprecipitate','reagents'
  )),
  units_affected int not null default 0,
  product_impact text not null check (product_impact in (
    'none','quarantined','discarded','recalled','revalidated_released','under_review'
  )),
  operator_profile_id uuid references public.profiles(id) on delete set null,
  event_verdict text not null check (event_verdict in (
    'within_range','excursion_managed','product_loss','recall_needed','pending_review','conditional_release'
  )),
  resolved_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.blood_bank_fridge_event_r3134 enable row level security;

create index if not exists idx_bb_fridge_event_r3134_org on public.blood_bank_fridge_event_r3134(organization_id);
create index if not exists idx_bb_fridge_event_r3134_date on public.blood_bank_fridge_event_r3134(event_date);
create index if not exists idx_bb_fridge_event_r3134_verdict on public.blood_bank_fridge_event_r3134(event_verdict);

-- =============================================================================
-- TABLE 2: blood_bank_fridge_capa_actions_r3134 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.blood_bank_fridge_capa_actions_r3134 (
  id uuid primary key default gen_random_uuid(),
  event_log_id uuid not null references public.blood_bank_fridge_event_r3134(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'high_temp_excursion','power_failure','compressor_failure','door_left_open',
    'sensor_calibration_drift','alarm_ack_delay','battery_backup_failure',
    'product_loss_event','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'compressor_degraded','power_grid_outage','ups_battery_dead','door_gasket_worn',
    'probe_out_of_cal','staff_ack_delay','overstocking_airflow_block','ambient_hvac_failure'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_compressor','install_ups_backup','replace_door_gasket','recalibrate_probe',
    'retrain_staff_alarm_response','redistribute_stock','repair_hvac','add_redundant_monitoring'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','overdue','escalated','verification_pending','closed'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'none','nabh_finding','cdsco_bloodbank_license','patient_safety_alert',
    'product_wastage_report','haemovigilance_reportable'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.blood_bank_fridge_capa_actions_r3134 enable row level security;

create index if not exists idx_bb_fridge_capa_r3134_event on public.blood_bank_fridge_capa_actions_r3134(event_log_id);
create index if not exists idx_bb_fridge_capa_r3134_status on public.blood_bank_fridge_capa_actions_r3134(capa_status);

-- =============================================================================
-- SEED — demo cold-chain events + CAPA for the founder view (org-scoped)
-- =============================================================================
do $$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at limit 1;
  if v_org_id is null then
    return;
  end if;

  insert into public.blood_bank_fridge_event_r3134 (
    organization_id, hospital_name, blood_bank_code, appliance_asset_tag, appliance_type, appliance_model,
    event_date, event_started_at, event_ended_at, setpoint_low_c, setpoint_high_c, excursion_peak_c,
    duration_minutes, alarm_type, alarm_acknowledged, ack_delay_minutes,
    product_category, units_affected, product_impact, event_verdict, resolved_at, notes
  )
  select v_org_id, q.hosp, q.bb, q.tag, q.at, q.model,
    q.ed::date, q.es::timestamptz, q.ee::timestamptz, q.sl, q.sh, q.pk,
    q.dur, q.al, q.ack, q.ackd,
    q.pc, q.units, q.pi, q.ev, q.res::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','BB-01','BF-APL-002','blood_fridge_2_6c','Vestfrost BFR340',
     '2026-07-01','2026-07-01 02:10:00+05:30','2026-07-01 02:35:00+05:30',2.00,6.00,8.40,
     25,'high_temp',true,6,'packed_red_cells',18,'quarantined','excursion_managed','2026-07-01 03:00:00+05:30','Night compressor cycling — 8.4C peak 25min, units quarantined pending review'),
    ('Apollo Hyderabad Jubilee Hills','BB-01','PF-APL-005','plasma_freezer_minus30','Thermo TSX3020',
     '2026-07-01','2026-07-01 06:00:00+05:30',null,-40.00,-30.00,-30.00,null,'none',false,null,'fresh_frozen_plasma',0,'none','within_range','2026-07-01 06:05:00+05:30','Routine daily check — stable'),
    ('Fortis Bannerghatta Bengaluru','BB-01','PI-FRT-011','platelet_incubator_20_24c','Helmer PC2200',
     '2026-07-01','2026-07-01 04:20:00+05:30','2026-07-01 05:50:00+05:30',20.00,24.00,27.10,90,'high_temp',true,22,'platelets',12,'discarded','product_loss',null,'Agitator + heater fault — 27C for 90min, 12 platelet units discarded'),
    ('Fortis Bannerghatta Bengaluru','BB-01','BF-FRT-004','blood_fridge_2_6c','Vestfrost BFR340',
     '2026-06-30','2026-06-30 22:00:00+05:30','2026-07-01 00:10:00+05:30',2.00,6.00,11.20,130,'power_failure',true,4,'packed_red_cells',34,'recalled','recall_needed',null,'Grid outage + UPS battery dead — 11.2C 130min, 34 PRC units recalled'),
    ('Manipal Whitefield Bengaluru','BB-02','CF-MNP-008','cryo_freezer_minus80','Eppendorf CryoCube',
     '2026-06-30','2026-06-30 03:00:00+05:30','2026-06-30 03:12:00+05:30',-86.00,-70.00,-64.00,12,'high_temp',true,3,'cryoprecipitate',0,'revalidated_released','excursion_managed','2026-06-30 03:40:00+05:30','Brief door-open during stock audit — recovered, product revalidated'),
    ('Manipal Whitefield Bengaluru','BB-02','BF-MNP-013','reagent_fridge','Blue Star MedFridge',
     '2026-06-30','2026-06-30 09:15:00+05:30',null,2.00,8.00,5.10,null,'probe_calibration_due',false,null,'reagents',0,'none','within_range',null,'Calibration reminder — probe due this week'),
    ('AIIMS New Delhi Ansari Nagar','BB-01','BF-AIM-021','blood_fridge_2_6c','Godrej BBR-500',
     '2026-06-29','2026-06-29 01:40:00+05:30','2026-06-29 02:30:00+05:30',2.00,6.00,7.20,50,'door_ajar',true,14,'whole_blood',9,'under_review','pending_review',null,'Door left ajar overnight — ack delayed 14min, units under review'),
    ('AIIMS New Delhi Ansari Nagar','BB-01','WK-AIM-030','walk_in_cold_room','Blue Star WICR',
     '2026-06-29','2026-06-29 05:00:00+05:30','2026-06-29 05:20:00+05:30',2.00,8.00,9.00,20,'compressor_fail',true,8,'packed_red_cells',0,'revalidated_released','conditional_release','2026-06-29 06:00:00+05:30','Standby compressor engaged automatically — conditional release'),
    ('KIMS Secunderabad','BB-01','BF-KIM-006','blood_fridge_2_6c','Vestfrost BFR340',
     '2026-06-28','2026-06-28 23:30:00+05:30','2026-06-29 00:05:00+05:30',2.00,6.00,6.80,35,'high_temp',false,40,'packed_red_cells',22,'quarantined','excursion_managed','2026-06-29 01:00:00+05:30','Alarm unacknowledged 40min — night staff response gap, 22 units quarantined'),
    ('KIMS Secunderabad','BB-01','PF-KIM-009','plasma_freezer_minus30','Thermo TSX3020',
     '2026-06-28','2026-06-28 07:00:00+05:30','2026-06-28 07:08:00+05:30',-40.00,-30.00,-26.00,8,'low_temp',true,2,'fresh_frozen_plasma',0,'revalidated_released','excursion_managed','2026-06-28 07:30:00+05:30','Defrost cycle brief warm — within managed limits'),
    ('Care Hospitals Banjara Hills','BB-01','PI-CAR-014','platelet_incubator_20_24c','Helmer PC2200',
     '2026-06-27','2026-06-27 08:00:00+05:30',null,20.00,24.00,22.10,null,'none',false,null,'platelets',0,'none','within_range',null,'Routine — agitation + temp nominal'),
    ('Yashoda Somajiguda Hyderabad','BB-02','CF-YSH-019','cryo_freezer_minus80','Eppendorf CryoCube',
     '2026-06-27','2026-06-27 02:00:00+05:30','2026-06-27 04:30:00+05:30',-86.00,-70.00,-58.00,150,'battery_backup_low',true,18,'cryoprecipitate',6,'discarded','product_loss',null,'Extended outage, UPS depleted — 150min excursion, 6 cryo units discarded'),
    ('St John''s Bengaluru','BB-01','BF-STJ-003','blood_fridge_2_6c','Godrej BBR-500',
     '2026-06-26','2026-06-26 06:30:00+05:30','2026-06-26 06:45:00+05:30',2.00,6.00,6.40,15,'sensor_fault',true,5,'whole_blood',0,'revalidated_released','excursion_managed','2026-06-26 07:15:00+05:30','Probe glitch flagged high — verified false by second probe'),
    ('Rainbow Children''s Hyderabad','BB-01','BF-RBW-010','blood_fridge_2_6c','Blue Star MedFridge',
     '2026-06-26','2026-06-26 04:15:00+05:30',null,2.00,6.00,10.50,null,'compressor_fail',true,9,'packed_red_cells',15,'under_review','pending_review',null,'Compressor tripped — awaiting engineer, 15 units under review')
  ) as q(hosp, bb, tag, at, model, ed, es, ee, sl, sh, pk, dur, al, ack, ackd, pc, units, pi, ev, res, nt)
  where q.tag ~ '^[A-Z]';

  insert into public.blood_bank_fridge_capa_actions_r3134 (
    event_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('PI-FRT-011','product_loss_event','compressor_degraded','replace_compressor','2026-07-06',null,'in_progress','product_wastage_report',72000,'12 platelet units discarded — incubator heater + agitator board replacement'),
    ('BF-FRT-004','power_failure','ups_battery_dead','install_ups_backup','2026-07-04',null,'escalated','haemovigilance_reportable',95000,'34 PRC recalled — UPS battery bank dead, redundant genset transfer added'),
    ('BF-KIM-006','alarm_ack_delay','staff_ack_delay','retrain_staff_alarm_response','2026-07-08',null,'open','nabh_finding',15000,'Night-shift alarm response SOP + escalation pager retraining'),
    ('CF-YSH-019','product_loss_event','ups_battery_dead','install_ups_backup','2026-07-05',null,'in_progress','product_wastage_report',110000,'6 cryo units lost — extended outage, second UPS + -80 backup freezer'),
    ('BF-AIM-021','door_left_open','door_gasket_worn','replace_door_gasket','2026-07-03','2026-07-02','closed','nabh_finding',8000,'Gasket replaced + door-ajar alarm sensitivity increased'),
    ('BF-RBW-010','compressor_failure','compressor_degraded','replace_compressor','2026-07-07',null,'overdue','patient_safety_alert',68000,'Compressor awaiting part — temporary transfer of stock to backup fridge')
  ) as q(tag, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.blood_bank_fridge_event_r3134 e
    on e.organization_id = v_org_id and e.appliance_asset_tag = q.tag;
end $$;

-- =============================================================================
-- RPCs — founder-gated analytics (RLS has no policies; access only via these)
-- =============================================================================

-- 1) Event verdict distribution
create or replace function public.founder_r3134_event_verdict_rollup()
returns table(event_verdict text, events bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_total bigint;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into v_total from public.blood_bank_fridge_event_r3134;
  return query
  select e.event_verdict, count(*)::bigint,
    round(100.0 * count(*) / nullif(v_total, 0), 1)
  from public.blood_bank_fridge_event_r3134 e
  group by e.event_verdict
  order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3134_event_verdict_rollup() from public, anon;
grant execute on function public.founder_r3134_event_verdict_rollup() to authenticated;

-- 2) Hospital cold-chain scorecard
create or replace function public.founder_r3134_hospital_scorecard()
returns table(
  hospital_name text, total_events bigint, within_range bigint, excursions bigint,
  product_loss bigint, recalls bigint, units_affected bigint, compliance_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.hospital_name,
    count(*)::bigint,
    count(*) filter (where e.event_verdict = 'within_range')::bigint,
    count(*) filter (where e.event_verdict in ('excursion_managed','conditional_release'))::bigint,
    count(*) filter (where e.event_verdict = 'product_loss')::bigint,
    count(*) filter (where e.event_verdict = 'recall_needed')::bigint,
    coalesce(sum(e.units_affected),0)::bigint,
    round(100.0 * count(*) filter (where e.event_verdict in ('within_range','excursion_managed','conditional_release'))
      / nullif(count(*), 0), 1)
  from public.blood_bank_fridge_event_r3134 e
  group by e.hospital_name
  order by count(*) filter (where e.event_verdict in ('product_loss','recall_needed')) desc, e.hospital_name;
end;
$$;
revoke execute on function public.founder_r3134_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3134_hospital_scorecard() to authenticated;

-- 3) Appliance type × alarm type matrix
create or replace function public.founder_r3134_appliance_alarm_matrix()
returns table(appliance_type text, alarm_type text, events bigint, avg_excursion_c numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.appliance_type, e.alarm_type, count(*)::bigint,
    round(avg(e.excursion_peak_c), 2)
  from public.blood_bank_fridge_event_r3134 e
  group by e.appliance_type, e.alarm_type
  order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3134_appliance_alarm_matrix() from public, anon;
grant execute on function public.founder_r3134_appliance_alarm_matrix() to authenticated;

-- 4) Daily excursion trend
create or replace function public.founder_r3134_excursion_daily_trend()
returns table(
  event_date date, within_range bigint, excursions bigint, product_loss bigint, recalls bigint
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.event_date,
    count(*) filter (where e.event_verdict = 'within_range')::bigint,
    count(*) filter (where e.event_verdict in ('excursion_managed','conditional_release','pending_review'))::bigint,
    count(*) filter (where e.event_verdict = 'product_loss')::bigint,
    count(*) filter (where e.event_verdict = 'recall_needed')::bigint
  from public.blood_bank_fridge_event_r3134 e
  group by e.event_date
  order by e.event_date desc;
end;
$$;
revoke execute on function public.founder_r3134_excursion_daily_trend() from public, anon;
grant execute on function public.founder_r3134_excursion_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3134_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees), 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.blood_bank_fridge_capa_actions_r3134 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3134_capa_status_board() from public, anon;
grant execute on function public.founder_r3134_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3134_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_total bigint;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into v_total from public.blood_bank_fridge_capa_actions_r3134;
  return query
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(100.0 * count(*) / nullif(v_total, 0), 1)
  from public.blood_bank_fridge_capa_actions_r3134 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3134_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3134_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3134_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.blood_bank_fridge_capa_actions_r3134 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3134_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3134_regulatory_impact_digest() to authenticated;

-- 8) High-risk events queue (top individual concerns)
create or replace function public.founder_r3134_high_risk_events()
returns table(
  hospital_name text, blood_bank_code text, appliance_asset_tag text, event_date date,
  event_verdict text, alarm_type text, excursion_peak_c numeric, units_affected int,
  product_impact text, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.hospital_name, e.blood_bank_code, e.appliance_asset_tag, e.event_date,
    e.event_verdict, e.alarm_type, e.excursion_peak_c, e.units_affected, e.product_impact, e.notes
  from public.blood_bank_fridge_event_r3134 e
  where e.event_verdict in ('product_loss','recall_needed','pending_review','conditional_release')
     or e.product_impact in ('discarded','recalled')
     or e.alarm_acknowledged = false
  order by e.event_date desc, e.units_affected desc;
end;
$$;
revoke execute on function public.founder_r3134_high_risk_events() from public, anon;
grant execute on function public.founder_r3134_high_risk_events() to authenticated;
