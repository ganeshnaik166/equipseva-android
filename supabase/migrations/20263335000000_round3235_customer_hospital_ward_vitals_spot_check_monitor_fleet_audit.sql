-- Round 3235: Customer Hospital Ward Vital-Signs Spot-Check Monitor Fleet Audit
-- Spot-check fleet log — ward × device count × NIBP cuff set × SpO2 probe × temp cal × battery health × cleaning compliance × drop damage × availability × CAPA

-- =============================================================================
-- TABLE 1: spot_monitor_r3235 — per-ward spot-check monitor fleet audits
-- =============================================================================
create table if not exists public.spot_monitor_r3235 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ward_code text not null,
  ward_name text not null,
  device_make_model text not null,
  devices_total int not null,
  devices_functional int not null,
  audit_date date not null,
  nibp_cuff_set_status text not null check (nibp_cuff_set_status in (
    'full_set_all_sizes','missing_neonatal','missing_paediatric',
    'missing_large_adult','multiple_sizes_missing','cuffs_damaged'
  )),
  spo2_probe_condition text not null check (spo2_probe_condition in (
    'good','cable_frayed','sensor_window_scratched','clip_spring_weak',
    'adhesive_wrap_worn','probe_failed'
  )),
  temp_probe_cal_status text not null check (temp_probe_cal_status in (
    'calibrated_in_date','due_within_30_days','overdue',
    'failed_verification','not_applicable_disposable'
  )),
  battery_health_pct numeric(5,2) not null,
  cleaning_protocol_compliance text not null check (cleaning_protocol_compliance in (
    'fully_compliant','wipes_wrong_type','logs_incomplete',
    'no_cleaning_between_patients','disinfectant_expired'
  )),
  dropped_device_damage text not null check (dropped_device_damage in (
    'none_reported','cracked_housing','loose_connector',
    'screen_damaged','internal_damage_suspected','writeoff'
  )),
  fleet_availability_pct numeric(5,2) not null,
  audit_verdict text not null check (audit_verdict in (
    'fleet_fit','minor_gaps','degraded','critical_shortfall','ward_escalation'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spot_monitor_r3235 enable row level security;

create index if not exists idx_spot_monitor_r3235_org on public.spot_monitor_r3235(organization_id);
create index if not exists idx_spot_monitor_r3235_date on public.spot_monitor_r3235(audit_date);
create index if not exists idx_spot_monitor_r3235_verdict on public.spot_monitor_r3235(audit_verdict);

-- =============================================================================
-- TABLE 2: spot_monitor_capa_actions_r3235 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.spot_monitor_capa_actions_r3235 (
  id uuid primary key default gen_random_uuid(),
  spot_audit_id uuid not null references public.spot_monitor_r3235(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'nibp_cuff_gap','spo2_probe_wear','temp_cal_overdue','battery_degraded',
    'cleaning_lapse','drop_damage','availability_shortfall','documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'procurement_delay','high_ward_utilisation','no_probe_spares_stock',
    'battery_past_cycle_life','staff_training_gap','no_drop_protection_case',
    'cal_vendor_backlog','store_indent_pending','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'order_cuff_set','replace_spo2_probe','schedule_calibration_visit',
    'replace_battery_pack','retrain_ward_staff','fit_protective_boot',
    'redistribute_fleet','writeoff_and_replace','update_cleaning_sop','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','patient_safety_alert','internal_only','none',
    'iso_13485_deviation','biomedical_committee_review'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spot_monitor_capa_actions_r3235 enable row level security;

create index if not exists idx_spot_capa_r3235_audit on public.spot_monitor_capa_actions_r3235(spot_audit_id);
create index if not exists idx_spot_capa_r3235_status on public.spot_monitor_capa_actions_r3235(capa_status);

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

  -- 13 ward fleet audit rows
  insert into public.spot_monitor_r3235 (
    organization_id, hospital_name, ward_code, ward_name, device_make_model,
    devices_total, devices_functional, audit_date,
    nibp_cuff_set_status, spo2_probe_condition, temp_probe_cal_status,
    battery_health_pct, cleaning_protocol_compliance, dropped_device_damage,
    fleet_availability_pct, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.wc, q.ward, q.mk,
    q.dt, q.df, q.ad::date,
    q.cuff, q.spo2, q.tcal,
    q.bh, q.clean, q.dmg,
    q.fa, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','APL-GW3','General Ward 3','Mindray VS-9',12,11,'2026-07-02',
     'full_set_all_sizes','good','calibrated_in_date',88.50,'fully_compliant','none_reported',91.70,'fleet_fit','Strong ward — one unit in planned PM'),
    ('Apollo Hyderabad Jubilee Hills','APL-SW5','Surgical Ward 5','Mindray VS-9',10,8,'2026-07-02',
     'missing_large_adult','cable_frayed','due_within_30_days',72.00,'logs_incomplete','loose_connector',80.00,'minor_gaps','Two probes on order; cal due 28 Jul'),
    ('Fortis Bannerghatta Bengaluru','FRT-MW2','Medical Ward 2','Philips SureSigns VS4',9,6,'2026-07-01',
     'multiple_sizes_missing','sensor_window_scratched','overdue',54.30,'wipes_wrong_type','cracked_housing',66.70,'degraded','Cuff pilferage suspected; battery swap list raised'),
    ('Fortis Bannerghatta Bengaluru','FRT-PED1','Paediatric Ward 1','Masimo Rad-97',8,7,'2026-07-01',
     'missing_neonatal','good','calibrated_in_date',81.20,'fully_compliant','none_reported',87.50,'minor_gaps','Neonatal cuff indent pending with stores'),
    ('Manipal Whitefield Bengaluru','MNP-ICU-SD','ICU Step-Down','GE Carescape VC150',14,13,'2026-06-30',
     'full_set_all_sizes','clip_spring_weak','calibrated_in_date',77.80,'fully_compliant','none_reported',92.90,'fleet_fit','Clip probes to be rotated out next quarter'),
    ('Manipal Whitefield Bengaluru','MNP-ONC4','Oncology Ward 4','GE Carescape VC150',10,7,'2026-06-30',
     'missing_paediatric','adhesive_wrap_worn','due_within_30_days',61.40,'no_cleaning_between_patients','loose_connector',70.00,'degraded','Cleaning lapse flagged to nursing lead'),
    ('AIIMS New Delhi Ansari Nagar','AIM-EM-OBS','Emergency Observation','BPL Ultima Prime',16,12,'2026-06-29',
     'cuffs_damaged','probe_failed','overdue',48.90,'disinfectant_expired','screen_damaged',75.00,'critical_shortfall','High-churn bay — three CAPAs raised'),
    ('AIIMS New Delhi Ansari Nagar','AIM-GW12','General Ward 12','BPL Ultima Prime',12,11,'2026-06-29',
     'full_set_all_sizes','good','calibrated_in_date',83.60,'fully_compliant','none_reported',91.70,'fleet_fit','Benchmark ward this audit cycle'),
    ('KIMS Secunderabad','KIM-CARD3','Cardiology Ward 3','Nihon Kohden SVM-7203',11,9,'2026-06-28',
     'missing_large_adult','cable_frayed','failed_verification',69.10,'logs_incomplete','none_reported',81.80,'degraded','Temp probe failed verification vs reference thermometer'),
    ('Care Hospitals Banjara Hills','CAR-MW1','Medical Ward 1','Contec CMS8000',7,5,'2026-06-28',
     'multiple_sizes_missing','sensor_window_scratched','overdue',52.70,'wipes_wrong_type','internal_damage_suspected',71.40,'critical_shortfall','Dropped unit shows intermittent NIBP — quarantined'),
    ('Yashoda Somajiguda Hyderabad','YSH-NEU2','Neurology Ward 2','Mindray VS-8',10,9,'2026-06-27',
     'full_set_all_sizes','good','due_within_30_days',79.30,'fully_compliant','none_reported',90.00,'fleet_fit','Calibration visit booked for 20 Jul'),
    ('St John''s Bengaluru','STJ-GW7','General Ward 7','Philips SureSigns VS4',9,8,'2026-06-27',
     'missing_neonatal','adhesive_wrap_worn','calibrated_in_date',74.50,'logs_incomplete','loose_connector',88.90,'minor_gaps','Wrap sensors overused — stock spares at ward level'),
    ('Rainbow Children''s Hyderabad','RBW-PICU','Paediatric ICU','Masimo Rad-97',13,10,'2026-06-26',
     'missing_paediatric','probe_failed','overdue',58.20,'no_cleaning_between_patients','writeoff',76.90,'ward_escalation','Escalated to biomedical committee — paediatric cuff and probe crisis')
  ) as q(hosp, wc, ward, mk, dt, df, ad, cuff, spo2, tcal, bh, clean, dmg, fa, verdict, nt);

  -- CAPA seed — attach to specific ward audits
  insert into public.spot_monitor_capa_actions_r3235 (
    spot_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('AIM-EM-OBS','spo2_probe_wear','no_probe_spares_stock','replace_spo2_probe','2026-07-06',null,'in_progress','patient_safety_alert',18500.00,'Four compatible probes ordered from vendor'),
    ('AIM-EM-OBS','battery_degraded','battery_past_cycle_life','replace_battery_pack','2026-07-10',null,'open','internal_only',42000.00,'Six packs below 50 percent health flagged'),
    ('FRT-MW2','temp_cal_overdue','cal_vendor_backlog','schedule_calibration_visit','2026-07-08',null,'escalated','nabh_finding',9500.00,'Vendor slot slipped twice — escalated to AMC manager'),
    ('CAR-MW1','drop_damage','no_drop_protection_case','writeoff_and_replace','2026-07-12',null,'open','biomedical_committee_review',95000.00,'Replacement monitor quote attached; boots for rest of fleet'),
    ('MNP-ONC4','cleaning_lapse','staff_training_gap','retrain_ward_staff','2026-07-04','2026-07-02','closed','nabh_finding',0.00,'Nursing in-service completed; spot re-audit passed'),
    ('RBW-PICU','nibp_cuff_gap','procurement_delay','order_cuff_set','2026-07-05',null,'overdue','patient_safety_alert',12800.00,'Paediatric cuff set stuck at supplier — expedite'),
    ('KIM-CARD3','temp_cal_overdue','cal_vendor_backlog','schedule_calibration_visit','2026-07-09',null,'verification_pending','iso_13485_deviation',7200.00,'Probe recalibrated — verification pending against reference')
  ) as q(wc, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.spot_monitor_r3235 e
    on e.organization_id = v_org_id and e.ward_code = q.wc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3235_verdict_rollup()
returns table(audit_verdict text, wards bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spot_monitor_r3235)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.spot_monitor_r3235 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3235_verdict_rollup() from public, anon;
grant execute on function public.founder_r3235_verdict_rollup() to authenticated;

-- 2) Hospital fleet scorecard
create or replace function public.founder_r3235_hospital_scorecard()
returns table(
  hospital_name text,
  wards_audited bigint,
  devices_total bigint,
  devices_functional bigint,
  fleet_fit_wards bigint,
  critical_wards bigint,
  avg_battery_pct numeric,
  avg_availability_pct numeric
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
    coalesce(sum(l.devices_total),0)::bigint,
    coalesce(sum(l.devices_functional),0)::bigint,
    count(*) filter (where l.audit_verdict = 'fleet_fit')::bigint,
    count(*) filter (where l.audit_verdict in ('critical_shortfall','ward_escalation'))::bigint,
    round(avg(l.battery_health_pct), 1),
    round(avg(l.fleet_availability_pct), 1)
  from public.spot_monitor_r3235 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3235_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3235_hospital_scorecard() to authenticated;

-- 3) SpO2 probe condition × temp cal status matrix
create or replace function public.founder_r3235_probe_cal_matrix()
returns table(spo2_probe_condition text, temp_probe_cal_status text, wards bigint, avg_battery_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.spo2_probe_condition, l.temp_probe_cal_status, count(*)::bigint,
    round(avg(l.battery_health_pct), 1)
  from public.spot_monitor_r3235 l
  group by l.spo2_probe_condition, l.temp_probe_cal_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3235_probe_cal_matrix() from public, anon;
grant execute on function public.founder_r3235_probe_cal_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3235_daily_trend()
returns table(audit_date date, wards bigint, fleet_fit bigint, degraded_or_worse bigint, avg_availability_pct numeric, avg_battery_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fleet_fit')::bigint,
    count(*) filter (where l.audit_verdict in ('degraded','critical_shortfall','ward_escalation'))::bigint,
    round(avg(l.fleet_availability_pct), 1),
    round(avg(l.battery_health_pct), 1)
  from public.spot_monitor_r3235 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3235_daily_trend() from public, anon;
grant execute on function public.founder_r3235_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3235_capa_status_board()
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
  from public.spot_monitor_capa_actions_r3235 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3235_capa_status_board() from public, anon;
grant execute on function public.founder_r3235_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3235_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spot_monitor_capa_actions_r3235)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.spot_monitor_capa_actions_r3235 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3235_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3235_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3235_regulatory_impact_digest()
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
  from public.spot_monitor_capa_actions_r3235 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3235_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3235_regulatory_impact_digest() to authenticated;

-- 8) High-risk wards queue
create or replace function public.founder_r3235_high_risk_wards()
returns table(
  hospital_name text,
  ward_code text,
  ward_name text,
  audit_date date,
  audit_verdict text,
  battery_health_pct numeric,
  fleet_availability_pct numeric,
  dropped_device_damage text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ward_code, l.ward_name, l.audit_date,
    l.audit_verdict, l.battery_health_pct, l.fleet_availability_pct,
    l.dropped_device_damage, l.notes
  from public.spot_monitor_r3235 l
  where l.audit_verdict in ('degraded','critical_shortfall','ward_escalation')
     or l.battery_health_pct < 60.00
     or l.fleet_availability_pct < 75.00
     or l.spo2_probe_condition = 'probe_failed'
     or l.temp_probe_cal_status in ('overdue','failed_verification')
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3235_high_risk_wards() from public, anon;
grant execute on function public.founder_r3235_high_risk_wards() to authenticated;
