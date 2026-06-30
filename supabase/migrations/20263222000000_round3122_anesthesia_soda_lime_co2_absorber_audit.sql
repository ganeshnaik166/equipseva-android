-- Round 3122: Anesthesia Workstation Soda Lime CO2 Absorber Spent-Capacity & Channeling Audit
-- Tracks soda lime canister hours, indicator color, end-tidal CO2 rebreathing, heat-rise, CAPA

begin;

create table if not exists soda_lime_canister_audits_r3122 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_label text not null,
  workstation_make_model text not null,
  workstation_serial text not null,
  canister_lot_no text not null,
  canister_install_date date not null,
  canister_hours_in_use numeric(7,2) not null check (canister_hours_in_use >= 0 and canister_hours_in_use <= 500),
  manufacturer_recommended_hours numeric(7,2) not null check (manufacturer_recommended_hours > 0),
  indicator_color text not null check (indicator_color in ('white','pale_violet','violet','deep_violet','fully_purple')),
  indicator_zone_percent_purple numeric(5,2) not null check (indicator_zone_percent_purple >= 0 and indicator_zone_percent_purple <= 100),
  inspired_co2_mmhg numeric(5,2) not null check (inspired_co2_mmhg >= 0 and inspired_co2_mmhg <= 20),
  rebreathing_detected boolean not null,
  canister_inlet_temp_c numeric(5,2) not null check (canister_inlet_temp_c >= 15 and canister_inlet_temp_c <= 60),
  canister_outlet_temp_c numeric(5,2) not null check (canister_outlet_temp_c >= 15 and canister_outlet_temp_c <= 60),
  heat_rise_c numeric(5,2) not null check (heat_rise_c >= 0 and heat_rise_c <= 40),
  channeling_suspected boolean not null,
  channeling_evidence text not null check (channeling_evidence in ('none','uneven_color_band','cold_spot_thermal','co2_rebreathing','soft_spot_palpation','dust_caking')),
  fresh_gas_flow_lpm numeric(5,2) not null check (fresh_gas_flow_lpm > 0 and fresh_gas_flow_lpm <= 15),
  audit_severity text not null check (audit_severity in ('green_ok','amber_replace_soon','red_replace_now','critical_patient_risk')),
  capa_action text not null check (capa_action in ('continue_use','replace_at_eod','replace_immediately','swap_canister_and_recalibrate','quarantine_machine','escalate_biomed','vendor_warranty_claim')),
  audited_by uuid references profiles(id),
  audited_at timestamptz not null default now()
);

create table if not exists soda_lime_capa_followups_r3122 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references soda_lime_canister_audits_r3122(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,
  followup_kind text not null check (followup_kind in ('canister_replacement','co2_sensor_recalibration','circuit_leak_test','vaporizer_check','vendor_warranty','biomed_escalation','training_refresher')),
  followup_status text not null check (followup_status in ('pending','scheduled','in_progress','completed','blocked','closed_with_findings')),
  scheduled_for timestamptz,
  completed_at timestamptz,
  engineer_id uuid references engineers(id),
  parts_used text,
  spent_lime_kg numeric(6,2) check (spent_lime_kg is null or (spent_lime_kg >= 0 and spent_lime_kg <= 50)),
  post_replacement_inspired_co2_mmhg numeric(5,2) check (post_replacement_inspired_co2_mmhg is null or (post_replacement_inspired_co2_mmhg >= 0 and post_replacement_inspired_co2_mmhg <= 20)),
  cost_inr numeric(10,2) check (cost_inr is null or cost_inr >= 0),
  notes text,
  created_at timestamptz not null default now()
);

-- Seed data
with org_pick as (
  select id from organizations order by created_at asc limit 1
), audit_seed as (
  insert into soda_lime_canister_audits_r3122 (
    organization_id, hospital_name, ot_room_label, workstation_make_model, workstation_serial,
    canister_lot_no, canister_install_date, canister_hours_in_use, manufacturer_recommended_hours,
    indicator_color, indicator_zone_percent_purple, inspired_co2_mmhg, rebreathing_detected,
    canister_inlet_temp_c, canister_outlet_temp_c, heat_rise_c,
    channeling_suspected, channeling_evidence, fresh_gas_flow_lpm,
    audit_severity, capa_action, audited_at
  )
  select org_pick.id, h.hospital_name, h.ot_room_label, h.workstation_make_model, h.workstation_serial,
         h.canister_lot_no, h.canister_install_date::date, h.canister_hours_in_use, h.manufacturer_recommended_hours,
         h.indicator_color, h.indicator_zone_percent_purple, h.inspired_co2_mmhg, h.rebreathing_detected,
         h.canister_inlet_temp_c, h.canister_outlet_temp_c, h.heat_rise_c,
         h.channeling_suspected, h.channeling_evidence, h.fresh_gas_flow_lpm,
         h.audit_severity, h.capa_action, h.audited_at::timestamptz
  from org_pick, (values
    ('Apollo Hospitals Hyderabad','OT-1 Cardiac','Drager Fabius Tiro','DFT-44A-2023-001','LOT-SL-2026-A14','2026-06-10',38.5,72.0,'pale_violet',22.50,1.20,false,22.50,28.40,5.90,false,'none',1.50,'green_ok','continue_use','2026-06-20 08:30:00+05:30'),
    ('Yashoda Hospitals Secunderabad','OT-3 Neuro','GE Aisys CS2','AISYS-CS2-2022-117','LOT-SL-2026-B09','2026-06-05',62.0,72.0,'violet',58.00,3.20,false,23.10,33.20,10.10,false,'none',1.20,'amber_replace_soon','replace_at_eod','2026-06-20 09:15:00+05:30'),
    ('KIMS Hospitals Hyderabad','OT-5 Ortho','Mindray A7','A7-2024-088','LOT-SL-2026-C22','2026-05-28',78.5,72.0,'deep_violet',82.00,5.80,true,24.00,38.50,14.50,false,'none',1.00,'red_replace_now','replace_immediately','2026-06-20 10:00:00+05:30'),
    ('Continental Hospitals Gachibowli','OT-2 General','Drager Atlan A350','ATLAN-A350-2023-044','LOT-SL-2026-D11','2026-06-12',26.0,72.0,'white',8.00,8.40,true,23.50,40.20,16.70,true,'co2_rebreathing',1.00,'critical_patient_risk','swap_canister_and_recalibrate','2026-06-20 11:20:00+05:30'),
    ('Sunshine Hospitals Paradise','OT-4 OBG','Maquet Flow-i','FLOW-I-2022-009','LOT-SL-2026-E07','2026-06-08',54.0,80.0,'violet',64.00,2.80,false,22.80,31.90,9.10,false,'none',1.50,'amber_replace_soon','replace_at_eod','2026-06-20 12:05:00+05:30'),
    ('AIG Hospitals Gachibowli','OT-6 Liver Transplant','GE Carestation 650','CS650-2024-021','LOT-SL-2026-F13','2026-06-15',18.0,72.0,'pale_violet',18.00,0.80,false,21.90,27.50,5.60,false,'none',2.00,'green_ok','continue_use','2026-06-20 13:10:00+05:30'),
    ('Care Hospitals Banjara Hills','OT-2 CTVS','Drager Fabius Tiro','DFT-44A-2022-077','LOT-SL-2026-G02','2026-06-02',88.0,72.0,'fully_purple',96.00,7.10,true,24.20,42.10,17.90,true,'cold_spot_thermal',0.80,'critical_patient_risk','quarantine_machine','2026-06-20 14:00:00+05:30'),
    ('Rainbow Childrens Hospital Banjara Hills','OT-Peds 1','Mindray A5','A5-2023-055','LOT-SL-2026-H18','2026-06-09',42.0,60.0,'violet',54.00,2.40,false,22.60,32.80,10.20,false,'none',1.30,'amber_replace_soon','replace_at_eod','2026-06-20 15:25:00+05:30'),
    ('Olive Hospitals Mehdipatnam','OT-1','GE Aespire View','AESPIRE-V-2021-099','LOT-SL-2026-I05','2026-05-30',95.0,80.0,'deep_violet',88.50,4.90,false,23.80,37.40,13.60,true,'uneven_color_band',1.10,'red_replace_now','replace_immediately','2026-06-20 16:10:00+05:30'),
    ('Krishna Institute of Medical Sciences','OT-7 Trauma','Drager Atlan A350','ATLAN-A350-2024-012','LOT-SL-2026-J21','2026-06-14',22.0,72.0,'white',12.00,1.10,false,22.30,28.90,6.60,false,'none',1.40,'green_ok','continue_use','2026-06-20 17:00:00+05:30'),
    ('St John''s Medical College Bangalore','OT-Main 3','Maquet Flow-c','FLOW-C-2022-066','LOT-SL-2026-K14','2026-05-25',102.0,80.0,'fully_purple',98.00,9.20,true,24.50,43.80,19.30,true,'dust_caking',0.90,'critical_patient_risk','escalate_biomed','2026-06-20 18:30:00+05:30'),
    ('Manipal Hospital Vijayawada','OT-2 General','Mindray A7','A7-2023-101','LOT-SL-2026-L08','2026-06-07',48.0,72.0,'violet',60.00,3.60,false,23.30,34.10,10.80,false,'none',1.20,'amber_replace_soon','vendor_warranty_claim','2026-06-20 19:45:00+05:30'),
    ('Fortis Hospital Mulund','OT-9 Cardiac','GE Aisys CS2','AISYS-CS2-2023-200','LOT-SL-2026-M03','2026-06-11',34.0,72.0,'pale_violet',28.00,1.60,false,22.70,29.80,7.10,false,'soft_spot_palpation',1.50,'green_ok','continue_use','2026-06-20 20:30:00+05:30')
  ) as h(
    hospital_name, ot_room_label, workstation_make_model, workstation_serial,
    canister_lot_no, canister_install_date, canister_hours_in_use, manufacturer_recommended_hours,
    indicator_color, indicator_zone_percent_purple, inspired_co2_mmhg, rebreathing_detected,
    canister_inlet_temp_c, canister_outlet_temp_c, heat_rise_c,
    channeling_suspected, channeling_evidence, fresh_gas_flow_lpm,
    audit_severity, capa_action, audited_at
  )
  returning id, organization_id, audit_severity
)
insert into soda_lime_capa_followups_r3122 (
  audit_id, organization_id, followup_kind, followup_status,
  scheduled_for, completed_at, parts_used, spent_lime_kg,
  post_replacement_inspired_co2_mmhg, cost_inr, notes
)
select id, organization_id,
  case audit_severity
    when 'green_ok' then 'circuit_leak_test'
    when 'amber_replace_soon' then 'canister_replacement'
    when 'red_replace_now' then 'canister_replacement'
    else 'biomed_escalation'
  end,
  case audit_severity
    when 'green_ok' then 'pending'
    when 'amber_replace_soon' then 'scheduled'
    when 'red_replace_now' then 'in_progress'
    else 'completed'
  end,
  (now() + interval '1 day')::timestamptz,
  case when audit_severity = 'critical_patient_risk' then now()::timestamptz else null::timestamptz end,
  case when audit_severity in ('red_replace_now','critical_patient_risk') then 'Sodasorb LF 5kg pre-pack' else null end,
  case when audit_severity in ('red_replace_now','critical_patient_risk') then 4.80 else null::numeric end,
  case when audit_severity = 'critical_patient_risk' then 0.60 else null::numeric end,
  case when audit_severity in ('red_replace_now','critical_patient_risk') then 4200.00 else null::numeric end,
  'Auto-seeded CAPA from r3122 audit'
from audit_seed;

-- RPC 1: severity rollup
create or replace function r3122_severity_rollup()
returns table(audit_severity text, audit_count bigint, channeling_count bigint, rebreathing_count bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_severity,
         count(*)::bigint,
         count(*) filter (where a.channeling_suspected)::bigint,
         count(*) filter (where a.rebreathing_detected)::bigint
  from soda_lime_canister_audits_r3122 a
  group by a.audit_severity
  order by case a.audit_severity
    when 'critical_patient_risk' then 1
    when 'red_replace_now' then 2
    when 'amber_replace_soon' then 3
    when 'green_ok' then 4 end;
end$$;
revoke execute on function r3122_severity_rollup() from public, anon;
grant execute on function r3122_severity_rollup() to authenticated;

-- RPC 2: indicator color distribution
create or replace function r3122_indicator_color_distribution()
returns table(indicator_color text, audit_count bigint, avg_percent_purple numeric, avg_inspired_co2 numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.indicator_color, count(*)::bigint,
         round(avg(a.indicator_zone_percent_purple), 2),
         round(avg(a.inspired_co2_mmhg), 2)
  from soda_lime_canister_audits_r3122 a
  group by a.indicator_color
  order by avg(a.indicator_zone_percent_purple) desc;
end$$;
revoke execute on function r3122_indicator_color_distribution() from public, anon;
grant execute on function r3122_indicator_color_distribution() to authenticated;

-- RPC 3: top channeling offenders
create or replace function r3122_channeling_offenders()
returns table(hospital_name text, workstation_make_model text, ot_room_label text, heat_rise_c numeric, inspired_co2_mmhg numeric, channeling_evidence text, audit_severity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.workstation_make_model, a.ot_room_label,
         a.heat_rise_c, a.inspired_co2_mmhg, a.channeling_evidence, a.audit_severity
  from soda_lime_canister_audits_r3122 a
  where a.channeling_suspected
  order by a.heat_rise_c desc;
end$$;
revoke execute on function r3122_channeling_offenders() from public, anon;
grant execute on function r3122_channeling_offenders() to authenticated;

-- RPC 4: rebreathing risk list
create or replace function r3122_rebreathing_risk()
returns table(hospital_name text, ot_room_label text, workstation_make_model text, inspired_co2_mmhg numeric, fresh_gas_flow_lpm numeric, canister_hours_in_use numeric, capa_action text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.ot_room_label, a.workstation_make_model,
         a.inspired_co2_mmhg, a.fresh_gas_flow_lpm, a.canister_hours_in_use, a.capa_action
  from soda_lime_canister_audits_r3122 a
  where a.rebreathing_detected or a.inspired_co2_mmhg >= 3.0
  order by a.inspired_co2_mmhg desc;
end$$;
revoke execute on function r3122_rebreathing_risk() from public, anon;
grant execute on function r3122_rebreathing_risk() to authenticated;

-- RPC 5: spent-capacity per workstation model
create or replace function r3122_spent_capacity_by_model()
returns table(workstation_make_model text, audit_count bigint, avg_hours_used numeric, avg_pct_of_recommended numeric, max_heat_rise numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.workstation_make_model, count(*)::bigint,
         round(avg(a.canister_hours_in_use), 2),
         round(avg(100.0 * a.canister_hours_in_use / nullif(a.manufacturer_recommended_hours, 0)), 2),
         max(a.heat_rise_c)
  from soda_lime_canister_audits_r3122 a
  group by a.workstation_make_model
  order by avg(a.canister_hours_in_use) desc;
end$$;
revoke execute on function r3122_spent_capacity_by_model() from public, anon;
grant execute on function r3122_spent_capacity_by_model() to authenticated;

-- RPC 6: CAPA followup status
create or replace function r3122_capa_followup_status()
returns table(followup_kind text, followup_status text, followup_count bigint, total_cost_inr numeric, total_spent_lime_kg numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.followup_kind, f.followup_status, count(*)::bigint,
         coalesce(sum(f.cost_inr), 0),
         coalesce(sum(f.spent_lime_kg), 0)
  from soda_lime_capa_followups_r3122 f
  group by f.followup_kind, f.followup_status
  order by f.followup_kind, f.followup_status;
end$$;
revoke execute on function r3122_capa_followup_status() from public, anon;
grant execute on function r3122_capa_followup_status() to authenticated;

-- RPC 7: capa action distribution
create or replace function r3122_capa_action_distribution()
returns table(capa_action text, audit_count bigint, avg_inspired_co2 numeric, avg_heat_rise numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.capa_action, count(*)::bigint,
         round(avg(a.inspired_co2_mmhg), 2),
         round(avg(a.heat_rise_c), 2)
  from soda_lime_canister_audits_r3122 a
  group by a.capa_action
  order by count(*) desc;
end$$;
revoke execute on function r3122_capa_action_distribution() from public, anon;
grant execute on function r3122_capa_action_distribution() to authenticated;

-- RPC 8: hospital-level worst exposure (top critical/red)
create or replace function r3122_hospital_worst_exposure()
returns table(hospital_name text, total_audits bigint, critical_or_red bigint, max_inspired_co2 numeric, max_heat_rise numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name,
         count(*)::bigint,
         count(*) filter (where a.audit_severity in ('red_replace_now','critical_patient_risk'))::bigint,
         max(a.inspired_co2_mmhg),
         max(a.heat_rise_c)
  from soda_lime_canister_audits_r3122 a
  group by a.hospital_name
  order by count(*) filter (where a.audit_severity in ('red_replace_now','critical_patient_risk')) desc, max(a.inspired_co2_mmhg) desc;
end$$;
revoke execute on function r3122_hospital_worst_exposure() from public, anon;
grant execute on function r3122_hospital_worst_exposure() to authenticated;

commit;
