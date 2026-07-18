-- Round 3183: Customer Hospital Pharmacy Cold-Chain Vaccine-Fridge & Ice-Pack Logger Audit
-- Pharmacy cold-chain audit — unit type × logger coverage × logging interval × 30-day excursions × alarm health × stock value at risk × CAPA

-- =============================================================================
-- TABLE 1: pharmacy_coldchain_r3183 — per-unit cold-chain audit log
-- =============================================================================
create table if not exists public.pharmacy_coldchain_r3183 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  pharmacy_code text not null,
  unit_asset_tag text not null,
  unit_type text not null check (unit_type in (
    'ilr','deep_freezer','vaccine_carrier','walk_in_cooler',
    'walk_in_freezer','pharmacy_refrigerator','cold_box'
  )),
  unit_make_model text not null,
  audit_date date not null,
  target_range text not null check (target_range in (
    'plus_2_to_plus_8_c','minus_25_to_minus_15_c','minus_70_c_ultra'
  )),
  logger_present boolean not null default false,
  logger_type text not null check (logger_type in (
    'thirty_dtr','fridge_tag_2','usb_logger','iot_realtime','manual_thermometer_only','none'
  )),
  logging_interval_min int,
  excursion_count_30d int not null default 0,
  max_excursion_c numeric(5,2),
  alarm_functional text not null check (alarm_functional in (
    'functional','not_functional','intermittent','not_fitted','untested'
  )),
  power_backup text not null check (power_backup in (
    'generator_auto','generator_manual','ups_only','solar_hybrid','none'
  )),
  stock_value_at_risk_rupees numeric(12,2),
  audit_verdict text not null check (audit_verdict in (
    'compliant','minor_gaps','major_gaps','critical_failure','decommission_recommended','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pharmacy_coldchain_r3183 enable row level security;

create index if not exists idx_pharmacy_coldchain_r3183_org on public.pharmacy_coldchain_r3183(organization_id);
create index if not exists idx_pharmacy_coldchain_r3183_date on public.pharmacy_coldchain_r3183(audit_date);
create index if not exists idx_pharmacy_coldchain_r3183_verdict on public.pharmacy_coldchain_r3183(audit_verdict);

-- =============================================================================
-- TABLE 2: pharmacy_coldchain_capa_actions_r3183 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.pharmacy_coldchain_capa_actions_r3183 (
  id uuid primary key default gen_random_uuid(),
  coldchain_log_id uuid not null references public.pharmacy_coldchain_r3183(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'logger_missing','excursion_uninvestigated','alarm_defect','door_gasket_leak',
    'power_backup_gap','stock_arrangement_error','calibration_overdue',
    'icepack_conditioning_fault','temperature_mapping_missing','training_gap'
  )),
  root_cause text not null check (root_cause in (
    'compressor_ageing','door_gasket_worn','power_outage_frequent',
    'logger_battery_dead','staff_untrained','overstocking_beyond_capacity',
    'defrost_cycle_misconfigured','sensor_drift','alarm_pcb_failed','procurement_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'install_data_logger','replace_door_gasket','recalibrate_sensor',
    'service_compressor','repair_alarm_module','add_ups_backup',
    'retrain_pharmacy_staff','redistribute_stock','replace_unit','schedule_amc_visit','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','who_uip_evm_finding','drug_license_risk','internal_only','none'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pharmacy_coldchain_capa_actions_r3183 enable row level security;

create index if not exists idx_pharmacy_capa_r3183_log on public.pharmacy_coldchain_capa_actions_r3183(coldchain_log_id);
create index if not exists idx_pharmacy_capa_r3183_status on public.pharmacy_coldchain_capa_actions_r3183(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only (per rule 8)
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 cold-chain unit audit rows
  insert into public.pharmacy_coldchain_r3183 (
    organization_id, hospital_name, pharmacy_code, unit_asset_tag, unit_type, unit_make_model,
    audit_date, target_range, logger_present, logger_type, logging_interval_min,
    excursion_count_30d, max_excursion_c, alarm_functional, power_backup,
    stock_value_at_risk_rupees, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.pc, q.tag, q.ut, q.mm,
    q.ad::date, q.tr, q.lp, q.lt, q.li,
    q.exc, q.mx, q.al, q.pb,
    q.sv, q.av, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','PH-MAIN','CC-APL-201','ilr','Haier HBC-200','2026-07-10','plus_2_to_plus_8_c',
     true,'iot_realtime',5,0,null,'functional','generator_auto',1850000.00,'compliant','Realtime IoT logger, zero excursions in 30 days'),
    ('Apollo Hyderabad Jubilee Hills','PH-ONCO','CC-APL-207','deep_freezer','Vestfrost MF-314','2026-07-10','minus_25_to_minus_15_c',
     true,'fridge_tag_2',10,2,-9.50,'functional','generator_auto',3200000.00,'minor_gaps','Two brief defrost-window excursions, both investigated'),
    ('Fortis Bannerghatta Bengaluru','PH-MAIN','CC-FRT-102','ilr','Godrej GMR-120','2026-07-09','plus_2_to_plus_8_c',
     true,'thirty_dtr',30,6,13.40,'not_functional','ups_only',950000.00,'major_gaps','Alarm PCB dead — six excursions went unalerted'),
    ('Fortis Bannerghatta Bengaluru','PH-VAC','CC-FRT-108','vaccine_carrier','Blowkings CB-46L','2026-07-09','plus_2_to_plus_8_c',
     false,'none',null,1,11.20,'not_fitted','none',45000.00,'major_gaps','Carrier dispatched without logger; ice-pack conditioning SOP missing'),
    ('Manipal Whitefield Bengaluru','PH-MAIN','CC-MNP-310','ilr','Haier HBC-260','2026-07-08','plus_2_to_plus_8_c',
     true,'usb_logger',15,1,9.10,'functional','generator_manual',1240000.00,'minor_gaps','Single excursion during 40-min power changeover'),
    ('Manipal Whitefield Bengaluru','PH-COLD','CC-MNP-317','walk_in_cooler','Rinac CRS-9000','2026-07-08','plus_2_to_plus_8_c',
     true,'iot_realtime',5,0,null,'functional','generator_auto',5600000.00,'compliant','Walk-in temperature-mapped; hot and cold points tagged'),
    ('AIIMS New Delhi Ansari Nagar','PH-MAIN','CC-AIM-410','ilr','Godrej GMR-300','2026-07-07','plus_2_to_plus_8_c',
     true,'thirty_dtr',30,4,12.00,'intermittent','generator_auto',2100000.00,'major_gaps','Alarm chirps intermittently; door gasket visibly worn'),
    ('AIIMS New Delhi Ansari Nagar','PH-ULTRA','CC-AIM-415','deep_freezer','Thermo Scientific TSX-600','2026-07-07','minus_70_c_ultra',
     true,'iot_realtime',2,0,null,'functional','generator_auto',8900000.00,'compliant','Ultra-low freezer for mRNA stock; dual probes healthy'),
    ('KIMS Secunderabad','PH-MAIN','CC-KIM-501','ilr','Vestfrost MK-304','2026-07-06','plus_2_to_plus_8_c',
     false,'manual_thermometer_only',null,3,10.80,'untested','ups_only',780000.00,'major_gaps','Twice-daily manual register only — no continuous logger'),
    ('KIMS Secunderabad','PH-VAC','CC-KIM-509','vaccine_carrier','Apex AVC-44','2026-07-06','plus_2_to_plus_8_c',
     true,'usb_logger',10,0,null,'not_fitted','none',38000.00,'minor_gaps','Carrier logger healthy; alarm not fitted by design'),
    ('Care Hospitals Banjara Hills','PH-MAIN','CC-CAR-601','pharmacy_refrigerator','Blue Star MC-350','2026-07-05','plus_2_to_plus_8_c',
     true,'fridge_tag_2',15,8,14.60,'not_functional','generator_manual',660000.00,'critical_failure','Compressor failing — stock shifted to backup ILR overnight'),
    ('Yashoda Somajiguda Hyderabad','PH-MAIN','CC-YSH-701','ilr','Haier HBC-200','2026-07-04','plus_2_to_plus_8_c',
     true,'iot_realtime',5,1,8.90,'functional','generator_auto',1420000.00,'minor_gaps','One excursion investigated and closed same day'),
    ('St John''s Bengaluru','PH-MAIN','CC-STJ-801','deep_freezer','Vestfrost MF-214','2026-07-03','minus_25_to_minus_15_c',
     true,'thirty_dtr',30,0,null,'functional','solar_hybrid',540000.00,'compliant','Solar-hybrid backup validated with 6-hour hold test'),
    ('Rainbow Children''s Hyderabad','PH-VAC','CC-RBW-901','ilr','Godrej GMR-51','2026-07-02','plus_2_to_plus_8_c',
     false,'none',null,5,15.30,'not_fitted','none',310000.00,'pending_review','Aged unit under decommission evaluation; five excursions')
  ) as q(hosp, pc, tag, ut, mm, ad, tr, lp, lt, li, exc, mx, al, pb, sv, av, nt);

  -- CAPA seed — attach to specific units by asset tag
  insert into public.pharmacy_coldchain_capa_actions_r3183 (
    coldchain_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('CC-FRT-102','alarm_defect','alarm_pcb_failed','repair_alarm_module','2026-07-20',null,'in_progress','nabh_finding',28000.00,'Alarm PCB ordered from Godrej service'),
    ('CC-FRT-108','logger_missing','procurement_delay','install_data_logger','2026-07-18',null,'open','who_uip_evm_finding',9500.00,'Fridge-tag loggers stuck in procurement pipeline'),
    ('CC-CAR-601','excursion_uninvestigated','compressor_ageing','replace_unit','2026-07-25',null,'escalated','drug_license_risk',185000.00,'Compressor beyond economic repair — replacement ILR quoted'),
    ('CC-AIM-410','door_gasket_leak','door_gasket_worn','replace_door_gasket','2026-07-15','2026-07-12','closed','internal_only',6500.00,'Gasket replaced; overnight hold test passed'),
    ('CC-KIM-501','logger_missing','staff_untrained','install_data_logger','2026-07-22',null,'verification_pending','cdsco_notifiable',12000.00,'USB logger installed; register-to-logger SOP retraining scheduled'),
    ('CC-RBW-901','calibration_overdue','pending_investigation','schedule_amc_visit','2026-07-05',null,'overdue','nabh_finding',15000.00,'Vendor assessment pending for decommission decision')
  ) as q(tag, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.pharmacy_coldchain_r3183 e
    on e.organization_id = v_org_id and e.unit_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3183_verdict_rollup()
returns table(audit_verdict text, units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pharmacy_coldchain_r3183)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pharmacy_coldchain_r3183 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3183_verdict_rollup() from public, anon;
grant execute on function public.founder_r3183_verdict_rollup() to authenticated;

-- 2) Hospital-level cold-chain scorecard
create or replace function public.founder_r3183_hospital_scorecard()
returns table(
  hospital_name text,
  total_units bigint,
  compliant bigint,
  major_gaps bigint,
  critical bigint,
  no_logger bigint,
  excursions_30d bigint,
  stock_at_risk_rupees numeric,
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
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    count(*) filter (where l.audit_verdict = 'major_gaps')::bigint,
    count(*) filter (where l.audit_verdict = 'critical_failure')::bigint,
    count(*) filter (where l.logger_present = false)::bigint,
    coalesce(sum(l.excursion_count_30d),0)::bigint,
    coalesce(sum(l.stock_value_at_risk_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.audit_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.pharmacy_coldchain_r3183 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3183_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3183_hospital_scorecard() to authenticated;

-- 3) Unit type × target range matrix
create or replace function public.founder_r3183_unit_type_matrix()
returns table(unit_type text, target_range text, units bigint, compliant bigint, avg_excursions_30d numeric, avg_interval_min numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.unit_type, l.target_range, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    round(avg(l.excursion_count_30d)::numeric, 1),
    round(avg(l.logging_interval_min)::numeric, 1)
  from public.pharmacy_coldchain_r3183 l
  group by l.unit_type, l.target_range
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3183_unit_type_matrix() from public, anon;
grant execute on function public.founder_r3183_unit_type_matrix() to authenticated;

-- 4) Audit daily trend
create or replace function public.founder_r3183_audit_daily_trend()
returns table(audit_date date, units_audited bigint, compliant bigint, gaps bigint, critical bigint, excursions_logged bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    count(*) filter (where l.audit_verdict in ('minor_gaps','major_gaps'))::bigint,
    count(*) filter (where l.audit_verdict in ('critical_failure','decommission_recommended'))::bigint,
    coalesce(sum(l.excursion_count_30d),0)::bigint
  from public.pharmacy_coldchain_r3183 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3183_audit_daily_trend() from public, anon;
grant execute on function public.founder_r3183_audit_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3183_capa_status_board()
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
  from public.pharmacy_coldchain_capa_actions_r3183 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3183_capa_status_board() from public, anon;
grant execute on function public.founder_r3183_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3183_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pharmacy_coldchain_capa_actions_r3183)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pharmacy_coldchain_capa_actions_r3183 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3183_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3183_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3183_regulatory_impact_digest()
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
  from public.pharmacy_coldchain_capa_actions_r3183 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3183_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3183_regulatory_impact_digest() to authenticated;

-- 8) High-risk units queue (top individual concerns)
create or replace function public.founder_r3183_high_risk_units()
returns table(
  hospital_name text,
  pharmacy_code text,
  unit_asset_tag text,
  unit_type text,
  audit_date date,
  audit_verdict text,
  excursion_count_30d int,
  max_excursion_c numeric,
  stock_value_at_risk_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.pharmacy_code, l.unit_asset_tag, l.unit_type, l.audit_date,
    l.audit_verdict, l.excursion_count_30d, l.max_excursion_c::numeric, l.stock_value_at_risk_rupees::numeric, l.notes
  from public.pharmacy_coldchain_r3183 l
  where l.audit_verdict in ('major_gaps','critical_failure','decommission_recommended','pending_review')
     or l.excursion_count_30d >= 3
     or l.logger_present = false
     or l.alarm_functional in ('not_functional','intermittent')
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3183_high_risk_units() from public, anon;
grant execute on function public.founder_r3183_high_risk_units() to authenticated;
