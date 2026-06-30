-- Round 3116 — Customer Hospital Defibrillator AED Pediatric-Pad Energy-Delivery Compliance Tracker
-- Monthly defibrillator + AED self-test + manual shock test —
-- joules delivered x pad expiry x pediatric/adult mode x battery x CAPA when fail.

set search_path = public, pg_temp;

-- =======================================================================
-- Table 1: defib_aed_units_r3116
-- Defibrillator / AED hardware roster across customer hospitals.
-- =======================================================================
create table if not exists public.defib_aed_units_r3116 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_tag text not null,
  device_type text not null check (device_type in ('manual_defib','aed_semi_auto','aed_fully_auto','biphasic_manual','monophasic_legacy','dual_mode_pediatric')),
  manufacturer text not null check (manufacturer in ('philips','zoll','physio_control_stryker','schiller','mindray','ge_healthcare','nihon_kohden','bpl_medical')),
  model_number text not null,
  serial_number text not null,
  ward_location text not null check (ward_location in ('emergency_room','icu','cathlab','operation_theatre','crash_cart_floor3','crash_cart_floor5','ambulance_bay','pediatric_icu','labour_room','public_lobby_aed','dialysis_unit','recovery_room')),
  pediatric_mode_capable boolean not null default false,
  rated_max_joules integer not null check (rated_max_joules between 50 and 360),
  pad_expiry_date date not null,
  pediatric_pad_expiry_date date,
  battery_install_date date not null,
  battery_rated_months integer not null check (battery_rated_months between 12 and 60),
  last_self_test_at timestamptz,
  next_self_test_due_at timestamptz not null,
  compliance_status text not null default 'pending_check' check (compliance_status in ('compliant','pending_check','battery_warning','pad_expired','pediatric_pad_expired','energy_deviation','self_test_fail','withdrawn_capa','overdue_monthly_test')),
  nabh_chapter_ref text check (nabh_chapter_ref in ('fms_8a','fms_8b','aac_3','coi_1','none')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_defib_aed_units_r3116_org on public.defib_aed_units_r3116(organization_id);
create index if not exists idx_defib_aed_units_r3116_status on public.defib_aed_units_r3116(compliance_status);
create index if not exists idx_defib_aed_units_r3116_due on public.defib_aed_units_r3116(next_self_test_due_at);

alter table public.defib_aed_units_r3116 enable row level security;

-- =======================================================================
-- Table 2: defib_aed_shock_tests_r3116
-- Monthly self-test + manual shock-energy verification log + CAPA.
-- =======================================================================
create table if not exists public.defib_aed_shock_tests_r3116 (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.defib_aed_units_r3116(id) on delete cascade,
  test_performed_at timestamptz not null default now(),
  test_kind text not null check (test_kind in ('monthly_self_test','quarterly_manual_shock','post_repair_verify','post_pad_swap','post_battery_swap','annual_pm','event_after_use')),
  mode_tested text not null check (mode_tested in ('adult','pediatric','aed_auto','manual_sync','manual_async')),
  target_joules integer not null check (target_joules between 1 and 360),
  delivered_joules numeric(6,2) not null check (delivered_joules >= 0 and delivered_joules <= 400),
  energy_deviation_pct numeric(5,2),
  pad_serial text,
  pad_lot text,
  pediatric_pad_attached boolean not null default false,
  battery_voltage_v numeric(4,2) check (battery_voltage_v >= 0 and battery_voltage_v <= 30),
  self_test_result text not null check (self_test_result in ('pass','warn','fail','aborted','inconclusive')),
  capa_required boolean not null default false,
  capa_action text check (capa_action in ('none','pad_replacement','battery_replacement','vendor_recall','withdraw_to_biomed','firmware_update','retrain_staff','pediatric_pad_order','escalate_oem')),
  capa_closed_at timestamptz,
  performed_by_engineer_id uuid references public.engineers(id) on delete set null,
  cost_rupees integer not null default 0 check (cost_rupees >= 0),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_defib_aed_shock_tests_r3116_unit on public.defib_aed_shock_tests_r3116(unit_id);
create index if not exists idx_defib_aed_shock_tests_r3116_result on public.defib_aed_shock_tests_r3116(self_test_result);
create index if not exists idx_defib_aed_shock_tests_r3116_capa on public.defib_aed_shock_tests_r3116(capa_required);

alter table public.defib_aed_shock_tests_r3116 enable row level security;

-- =======================================================================
-- SEED DATA
-- =======================================================================
do $seed$
declare
  v_org uuid;
  v_eng uuid;
begin
  select id into v_org from public.organizations order by created_at asc limit 1;
  select id into v_eng from public.engineers order by created_at asc limit 1;

  if v_org is null then
    return;
  end if;

  insert into public.defib_aed_units_r3116
    (organization_id, asset_tag, device_type, manufacturer, model_number, serial_number,
     ward_location, pediatric_mode_capable, rated_max_joules, pad_expiry_date,
     pediatric_pad_expiry_date, battery_install_date, battery_rated_months,
     last_self_test_at, next_self_test_due_at, compliance_status, nabh_chapter_ref, notes)
  select q.organization_id, q.asset_tag, q.device_type, q.manufacturer, q.model_number, q.serial_number,
         q.ward_location, q.pediatric_mode_capable, q.rated_max_joules, q.pad_expiry_date,
         q.pediatric_pad_expiry_date::date, q.battery_install_date, q.battery_rated_months,
         q.last_self_test_at::timestamptz, q.next_self_test_due_at::timestamptz,
         q.compliance_status, q.nabh_chapter_ref, q.notes
  from (values
    (v_org, 'DEF-ER-001', 'biphasic_manual', 'philips', 'HeartStart MRx', 'PHL-MRX-22001',
       'emergency_room', true, 200, date '2026-09-15', date '2026-08-20', date '2025-04-10', 24,
       (now() - interval '6 days'), (now() + interval '24 days'),
       'compliant', 'fms_8a', 'Apollo ER primary unit, biphasic 200J adult.'),
    (v_org, 'DEF-ICU-002', 'manual_defib', 'zoll', 'R Series Plus', 'ZOL-RS-44210',
       'icu', true, 200, date '2026-07-30', date '2026-07-30', date '2024-12-01', 36,
       (now() - interval '12 days'), (now() + interval '18 days'),
       'pending_check', 'fms_8a', 'ICU bay-3, dual-mode pediatric pads on board.'),
    (v_org, 'AED-LOBBY-003', 'aed_fully_auto', 'physio_control_stryker', 'LIFEPAK CR2', 'STK-CR2-77321',
       'public_lobby_aed', false, 200, date '2026-04-12', null, date '2024-03-15', 48,
       (now() - interval '31 days'), (now() - interval '1 days'),
       'overdue_monthly_test', 'fms_8b', 'Public lobby AED — overdue monthly self-test.'),
    (v_org, 'DEF-OT-004', 'biphasic_manual', 'schiller', 'DEFIGARD Touch 7', 'SCH-DG7-88112',
       'operation_theatre', true, 360, date '2026-11-02', date '2026-10-10', date '2025-08-20', 24,
       (now() - interval '4 days'), (now() + interval '26 days'),
       'compliant', 'fms_8a', 'OT-1 anaesthesia trolley.'),
    (v_org, 'DEF-PICU-005', 'dual_mode_pediatric', 'mindray', 'BeneHeart D6', 'MIN-D6-55009',
       'pediatric_icu', true, 200, date '2026-03-25', date '2025-12-30', date '2024-06-12', 36,
       (now() - interval '8 days'), (now() + interval '22 days'),
       'pediatric_pad_expired', 'fms_8a', 'PICU — pediatric pads expired Dec-2025, adult pads still valid.'),
    (v_org, 'AED-AMB-006', 'aed_semi_auto', 'bpl_medical', 'Relife 900', 'BPL-RL9-30021',
       'ambulance_bay', true, 200, date '2026-06-01', date '2026-05-20', date '2023-11-08', 36,
       (now() - interval '15 days'), (now() + interval '15 days'),
       'battery_warning', 'fms_8b', 'Ambulance-2 AED — battery 30+ months, voltage drift.'),
    (v_org, 'DEF-CATH-007', 'biphasic_manual', 'ge_healthcare', 'CARESCAPE R860 DC', 'GE-CR860-66001',
       'cathlab', true, 360, date '2026-12-10', date '2026-12-10', date '2025-09-01', 24,
       (now() - interval '2 days'), (now() + interval '28 days'),
       'compliant', 'aac_3', 'Cathlab synchronised cardioversion ready.'),
    (v_org, 'DEF-LR-008', 'monophasic_legacy', 'nihon_kohden', 'TEC-5631', 'NK-5631-12009',
       'labour_room', false, 360, date '2026-02-18', null, date '2023-05-04', 48,
       (now() - interval '20 days'), (now() + interval '10 days'),
       'withdrawn_capa', 'fms_8a', 'Legacy monophasic — CAPA: replace with biphasic in FY2026-27.'),
    (v_org, 'DEF-ER-009', 'biphasic_manual', 'philips', 'HeartStart XL+', 'PHL-XLP-91002',
       'emergency_room', true, 200, date '2026-08-08', date '2026-07-15', date '2025-01-22', 24,
       (now() - interval '5 days'), (now() + interval '25 days'),
       'energy_deviation', 'fms_8a', 'ER backup — delivered 178J on 200J target, 11% deviation flagged.'),
    (v_org, 'AED-DIAL-010', 'aed_fully_auto', 'zoll', 'AED Plus', 'ZOL-AED-43388',
       'dialysis_unit', false, 200, date '2026-01-05', null, date '2024-09-10', 48,
       (now() - interval '40 days'), (now() - interval '10 days'),
       'pad_expired', 'fms_8b', 'Dialysis unit — pads expired Jan-2026, pending procurement.'),
    (v_org, 'DEF-REC-011', 'biphasic_manual', 'mindray', 'BeneHeart D3', 'MIN-D3-22118',
       'recovery_room', true, 200, date '2026-10-22', date '2026-09-30', date '2025-06-18', 36,
       (now() - interval '7 days'), (now() + interval '23 days'),
       'compliant', 'fms_8a', 'Post-op recovery bay.'),
    (v_org, 'DEF-CC3-012', 'biphasic_manual', 'philips', 'HeartStart MRx', 'PHL-MRX-22444',
       'crash_cart_floor3', true, 200, date '2026-09-30', date '2026-08-15', date '2025-03-05', 24,
       (now() - interval '10 days'), (now() + interval '20 days'),
       'self_test_fail', 'fms_8a', 'Floor-3 crash cart — last self-test FAIL on capacitor charge time.'),
    (v_org, 'DEF-CC5-013', 'biphasic_manual', 'zoll', 'R Series BLS', 'ZOL-RBS-55667',
       'crash_cart_floor5', true, 200, date '2026-11-18', date '2026-10-25', date '2025-07-30', 36,
       (now() - interval '3 days'), (now() + interval '27 days'),
       'compliant', 'fms_8a', 'Floor-5 crash cart routine OK.'),
    (v_org, 'AED-PED-014', 'dual_mode_pediatric', 'schiller', 'FRED easyport', 'SCH-FEZ-99001',
       'pediatric_icu', true, 100, date '2026-07-04', date '2026-06-20', date '2024-08-14', 48,
       (now() - interval '11 days'), (now() + interval '19 days'),
       'compliant', 'fms_8a', 'PICU portable pediatric-priority AED.')
  ) as q(organization_id, asset_tag, device_type, manufacturer, model_number, serial_number,
         ward_location, pediatric_mode_capable, rated_max_joules, pad_expiry_date,
         pediatric_pad_expiry_date, battery_install_date, battery_rated_months,
         last_self_test_at, next_self_test_due_at, compliance_status, nabh_chapter_ref, notes);

  insert into public.defib_aed_shock_tests_r3116
    (unit_id, test_performed_at, test_kind, mode_tested, target_joules, delivered_joules,
     energy_deviation_pct, pad_serial, pad_lot, pediatric_pad_attached, battery_voltage_v,
     self_test_result, capa_required, capa_action, capa_closed_at, performed_by_engineer_id,
     cost_rupees, notes)
  select u.id, q.test_performed_at::timestamptz, q.test_kind, q.mode_tested, q.target_joules,
         q.delivered_joules, q.energy_deviation_pct, q.pad_serial, q.pad_lot, q.pediatric_pad_attached,
         q.battery_voltage_v, q.self_test_result, q.capa_required, q.capa_action,
         q.capa_closed_at::timestamptz, v_eng, q.cost_rupees, q.notes
  from (values
    ('DEF-ER-001',    (now() - interval '6 days'),  'monthly_self_test',     'adult',       200, 198.4::numeric, -0.80::numeric, 'PAD-MRX-AD-101',  'LOT-2026-04', false, 12.40::numeric, 'pass',  false, 'none',                null,                          1500, 'Routine monthly OK.'),
    ('DEF-ICU-002',   (now() - interval '12 days'), 'quarterly_manual_shock','adult',       200, 201.2::numeric,  0.60::numeric, 'PAD-ZOL-AD-220',  'LOT-2026-02', false, 12.80::numeric, 'pass',  false, 'none',                null,                          2200, 'Manual 200J biphasic verified.'),
    ('AED-LOBBY-003', (now() - interval '31 days'), 'monthly_self_test',     'aed_auto',    150, 149.0::numeric, -0.67::numeric, 'PAD-CR2-AD-310',  'LOT-2025-11', false, 11.90::numeric, 'pass',  false, 'none',                null,                          1200, 'Lobby AED last test 31d ago — now overdue.'),
    ('DEF-OT-004',    (now() - interval '4 days'),  'monthly_self_test',     'adult',       360, 355.5::numeric, -1.25::numeric, 'PAD-DG7-AD-401',  'LOT-2026-05', false, 13.10::numeric, 'pass',  false, 'none',                null,                          1800, 'OT-1 high-energy verified.'),
    ('DEF-PICU-005',  (now() - interval '8 days'),  'monthly_self_test',     'pediatric',   100, 0.00::numeric,   null,           'PAD-D6-PED-501',  'LOT-2025-08', true,  12.70::numeric, 'fail',  true,  'pediatric_pad_order', null,                          3500, 'Pediatric pads expired — could not deliver test shock.'),
    ('AED-AMB-006',   (now() - interval '15 days'), 'monthly_self_test',     'aed_auto',    150, 142.5::numeric, -5.00::numeric, 'PAD-RL9-AD-602',  'LOT-2025-12', false, 10.80::numeric, 'warn',  true,  'battery_replacement', null,                          2800, 'Ambulance AED battery voltage low — CAPA open.'),
    ('DEF-CATH-007',  (now() - interval '2 days'),  'monthly_self_test',     'manual_sync', 200, 199.6::numeric, -0.20::numeric, 'PAD-CR860-AD-701','LOT-2026-06', false, 13.00::numeric, 'pass',  false, 'none',                null,                          2000, 'Cathlab sync cardioversion OK.'),
    ('DEF-LR-008',    (now() - interval '20 days'), 'annual_pm',             'adult',       360, 322.0::numeric, -10.56::numeric,'PAD-5631-AD-801', 'LOT-2025-09', false, 12.50::numeric, 'fail',  true,  'withdraw_to_biomed',  (now() - interval '5 days'),    8500, 'Monophasic legacy — withdrawn, CAPA closed by replacement plan.'),
    ('DEF-ER-009',    (now() - interval '5 days'),  'monthly_self_test',     'adult',       200, 178.0::numeric, -11.00::numeric,'PAD-XLP-AD-901',  'LOT-2026-03', false, 12.20::numeric, 'fail',  true,  'escalate_oem',        null,                          5500, 'Delivered 178J on 200J — 11% deviation, OEM escalated.'),
    ('AED-DIAL-010',  (now() - interval '40 days'), 'monthly_self_test',     'aed_auto',    150, 0.00::numeric,   null,           'PAD-AED-AD-1001', 'LOT-2024-12', false, 12.00::numeric, 'aborted', true, 'pad_replacement',     null,                          2400, 'Dialysis AED — pads expired, aborted self-test.'),
    ('DEF-REC-011',   (now() - interval '7 days'),  'monthly_self_test',     'adult',       200, 199.1::numeric, -0.45::numeric, 'PAD-D3-AD-1101',  'LOT-2026-05', false, 12.90::numeric, 'pass',  false, 'none',                null,                          1600, 'Recovery bay OK.'),
    ('DEF-CC3-012',   (now() - interval '10 days'), 'monthly_self_test',     'adult',       200, 0.00::numeric,   null,           'PAD-MRX-AD-1201', 'LOT-2026-04', false, 12.60::numeric, 'fail',  true,  'firmware_update',     null,                          4200, 'Capacitor charge timeout — firmware update queued.'),
    ('DEF-CC5-013',   (now() - interval '3 days'),  'monthly_self_test',     'adult',       200, 200.8::numeric,  0.40::numeric, 'PAD-RBS-AD-1301', 'LOT-2026-06', false, 13.20::numeric, 'pass',  false, 'none',                null,                          1500, 'Floor-5 crash cart routine OK.'),
    ('AED-PED-014',   (now() - interval '11 days'), 'monthly_self_test',     'pediatric',   50,  49.5::numeric,  -1.00::numeric, 'PAD-FEZ-PED-1401','LOT-2026-05', true,  12.80::numeric, 'pass',  false, 'none',                null,                          1700, 'Pediatric portable AED OK at 50J.'),
    ('DEF-ER-001',    (now() - interval '37 days'), 'monthly_self_test',     'adult',       200, 197.9::numeric, -1.05::numeric, 'PAD-MRX-AD-100',  'LOT-2026-03', false, 12.50::numeric, 'pass',  false, 'none',                null,                          1500, 'Prior-month ER routine.'),
    ('DEF-ICU-002',   (now() - interval '95 days'), 'post_pad_swap',         'adult',       200, 200.5::numeric,  0.25::numeric, 'PAD-ZOL-AD-219',  'LOT-2025-12', false, 12.85::numeric, 'pass',  false, 'none',                (now() - interval '95 days'),  2100, 'Post pad-swap verify.')
  ) as q(asset_tag, test_performed_at, test_kind, mode_tested, target_joules, delivered_joules,
         energy_deviation_pct, pad_serial, pad_lot, pediatric_pad_attached, battery_voltage_v,
         self_test_result, capa_required, capa_action, capa_closed_at, cost_rupees, notes)
  join public.defib_aed_units_r3116 u
    on u.asset_tag = q.asset_tag and u.organization_id = v_org;

end
$seed$;

-- =======================================================================
-- RPC 1: founder_defib_aed_fleet_overview_r3116
-- Fleet-wide compliance status rollup.
-- =======================================================================
create or replace function public.founder_defib_aed_fleet_overview_r3116()
returns table (
  compliance_status text,
  unit_count integer,
  pediatric_capable_count integer,
  avg_battery_age_months numeric,
  pct_of_fleet numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_total integer;
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  select count(*) into v_total from public.defib_aed_units_r3116;
  if v_total = 0 then v_total := 1; end if;

  return query
  select u.compliance_status::text,
         count(*)::int as unit_count,
         sum(case when u.pediatric_mode_capable then 1 else 0 end)::int as pediatric_capable_count,
         round(avg(extract(epoch from (now() - u.battery_install_date::timestamptz)) / (86400.0 * 30.0))::numeric, 1) as avg_battery_age_months,
         round((count(*)::numeric * 100.0 / v_total::numeric), 1) as pct_of_fleet
  from public.defib_aed_units_r3116 u
  group by u.compliance_status
  order by unit_count desc;
end;
$$;

revoke execute on function public.founder_defib_aed_fleet_overview_r3116() from public, anon;
grant execute on function public.founder_defib_aed_fleet_overview_r3116() to authenticated;

-- =======================================================================
-- RPC 2: founder_defib_aed_pad_expiry_alerts_r3116
-- Units with adult OR pediatric pad expiry within 90 days or already expired.
-- =======================================================================
create or replace function public.founder_defib_aed_pad_expiry_alerts_r3116()
returns table (
  asset_tag text,
  ward_location text,
  manufacturer text,
  adult_pad_expiry date,
  pediatric_pad_expiry date,
  days_to_adult_expiry integer,
  days_to_pediatric_expiry integer,
  urgency text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select u.asset_tag::text,
         u.ward_location::text,
         u.manufacturer::text,
         u.pad_expiry_date,
         u.pediatric_pad_expiry_date,
         (u.pad_expiry_date - current_date)::int as days_to_adult_expiry,
         case when u.pediatric_pad_expiry_date is null then null
              else (u.pediatric_pad_expiry_date - current_date)::int end as days_to_pediatric_expiry,
         case
           when u.pad_expiry_date < current_date then 'adult_pad_expired'
           when u.pediatric_pad_expiry_date is not null and u.pediatric_pad_expiry_date < current_date then 'pediatric_pad_expired'
           when u.pad_expiry_date - current_date <= 30 then 'expiring_30d'
           when u.pad_expiry_date - current_date <= 90 then 'expiring_90d'
           else 'ok'
         end::text as urgency
  from public.defib_aed_units_r3116 u
  where u.pad_expiry_date - current_date <= 120
     or (u.pediatric_pad_expiry_date is not null and u.pediatric_pad_expiry_date - current_date <= 120)
  order by u.pad_expiry_date asc;
end;
$$;

revoke execute on function public.founder_defib_aed_pad_expiry_alerts_r3116() from public, anon;
grant execute on function public.founder_defib_aed_pad_expiry_alerts_r3116() to authenticated;

-- =======================================================================
-- RPC 3: founder_defib_aed_energy_deviation_r3116
-- Delivered-vs-target joule deviation rollup per unit (last 6 months).
-- =======================================================================
create or replace function public.founder_defib_aed_energy_deviation_r3116()
returns table (
  asset_tag text,
  manufacturer text,
  tests_in_window integer,
  worst_deviation_pct numeric,
  avg_deviation_pct numeric,
  failing_tests integer,
  deviation_flag text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select u.asset_tag::text,
         u.manufacturer::text,
         count(t.*)::int as tests_in_window,
         coalesce(round(min(t.energy_deviation_pct), 2), 0) as worst_deviation_pct,
         coalesce(round(avg(t.energy_deviation_pct), 2), 0) as avg_deviation_pct,
         sum(case when t.self_test_result = 'fail' then 1 else 0 end)::int as failing_tests,
         case
           when min(t.energy_deviation_pct) is null then 'no_data'
           when min(t.energy_deviation_pct) <= -10 then 'critical_deviation'
           when min(t.energy_deviation_pct) <= -5  then 'warning_deviation'
           else 'within_spec'
         end::text as deviation_flag
  from public.defib_aed_units_r3116 u
  left join public.defib_aed_shock_tests_r3116 t
    on t.unit_id = u.id
   and t.test_performed_at >= now() - interval '180 days'
   and t.delivered_joules > 0
  group by u.asset_tag, u.manufacturer
  order by worst_deviation_pct asc nulls last;
end;
$$;

revoke execute on function public.founder_defib_aed_energy_deviation_r3116() from public, anon;
grant execute on function public.founder_defib_aed_energy_deviation_r3116() to authenticated;

-- =======================================================================
-- RPC 4: founder_defib_aed_battery_health_r3116
-- Battery age + voltage rollup per ward.
-- =======================================================================
create or replace function public.founder_defib_aed_battery_health_r3116()
returns table (
  ward_location text,
  unit_count integer,
  avg_battery_age_months numeric,
  units_past_rated_life integer,
  avg_last_voltage_v numeric,
  battery_alert_flag text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  with latest_v as (
    select t.unit_id, t.battery_voltage_v,
           row_number() over (partition by t.unit_id order by t.test_performed_at desc) as rn
    from public.defib_aed_shock_tests_r3116 t
    where t.battery_voltage_v is not null
  )
  select u.ward_location::text,
         count(*)::int as unit_count,
         round(avg(extract(epoch from (now() - u.battery_install_date::timestamptz)) / (86400.0 * 30.0))::numeric, 1) as avg_battery_age_months,
         sum(case when extract(epoch from (now() - u.battery_install_date::timestamptz)) / (86400.0 * 30.0) > u.battery_rated_months then 1 else 0 end)::int as units_past_rated_life,
         coalesce(round(avg(lv.battery_voltage_v), 2), 0) as avg_last_voltage_v,
         case
           when sum(case when extract(epoch from (now() - u.battery_install_date::timestamptz)) / (86400.0 * 30.0) > u.battery_rated_months then 1 else 0 end) > 0 then 'replace_soon'
           when avg(lv.battery_voltage_v) is not null and avg(lv.battery_voltage_v) < 11.5 then 'low_voltage'
           else 'healthy'
         end::text as battery_alert_flag
  from public.defib_aed_units_r3116 u
  left join latest_v lv on lv.unit_id = u.id and lv.rn = 1
  group by u.ward_location
  order by units_past_rated_life desc, avg_battery_age_months desc;
end;
$$;

revoke execute on function public.founder_defib_aed_battery_health_r3116() from public, anon;
grant execute on function public.founder_defib_aed_battery_health_r3116() to authenticated;

-- =======================================================================
-- RPC 5: founder_defib_aed_pediatric_readiness_r3116
-- Pediatric-mode readiness: pediatric-capable units that lack valid pediatric pads.
-- =======================================================================
create or replace function public.founder_defib_aed_pediatric_readiness_r3116()
returns table (
  ward_location text,
  pediatric_capable_units integer,
  pediatric_pad_valid integer,
  pediatric_pad_expired integer,
  pediatric_pad_missing integer,
  readiness_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select u.ward_location::text,
         sum(case when u.pediatric_mode_capable then 1 else 0 end)::int as pediatric_capable_units,
         sum(case when u.pediatric_mode_capable and u.pediatric_pad_expiry_date is not null and u.pediatric_pad_expiry_date >= current_date then 1 else 0 end)::int as pediatric_pad_valid,
         sum(case when u.pediatric_mode_capable and u.pediatric_pad_expiry_date is not null and u.pediatric_pad_expiry_date < current_date then 1 else 0 end)::int as pediatric_pad_expired,
         sum(case when u.pediatric_mode_capable and u.pediatric_pad_expiry_date is null then 1 else 0 end)::int as pediatric_pad_missing,
         case when sum(case when u.pediatric_mode_capable then 1 else 0 end) = 0 then 0
              else round((sum(case when u.pediatric_mode_capable and u.pediatric_pad_expiry_date is not null and u.pediatric_pad_expiry_date >= current_date then 1 else 0 end)::numeric * 100.0)
                         / sum(case when u.pediatric_mode_capable then 1 else 0 end)::numeric, 1)
         end as readiness_pct
  from public.defib_aed_units_r3116 u
  group by u.ward_location
  order by readiness_pct asc nulls last;
end;
$$;

revoke execute on function public.founder_defib_aed_pediatric_readiness_r3116() from public, anon;
grant execute on function public.founder_defib_aed_pediatric_readiness_r3116() to authenticated;

-- =======================================================================
-- RPC 6: founder_defib_aed_monthly_test_compliance_r3116
-- Monthly self-test compliance: when was last test, is it overdue.
-- =======================================================================
create or replace function public.founder_defib_aed_monthly_test_compliance_r3116()
returns table (
  asset_tag text,
  ward_location text,
  last_test_at timestamptz,
  next_test_due_at timestamptz,
  days_overdue integer,
  last_result text,
  compliance_flag text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  with latest as (
    select t.unit_id, t.self_test_result, t.test_performed_at,
           row_number() over (partition by t.unit_id order by t.test_performed_at desc) as rn
    from public.defib_aed_shock_tests_r3116 t
  )
  select u.asset_tag::text,
         u.ward_location::text,
         u.last_self_test_at,
         u.next_self_test_due_at,
         greatest(0, (extract(epoch from (now() - u.next_self_test_due_at)) / 86400.0)::int) as days_overdue,
         coalesce(l.self_test_result, 'none')::text as last_result,
         case
           when u.next_self_test_due_at < now() then 'overdue'
           when l.self_test_result = 'fail'    then 'last_test_failed'
           when l.self_test_result = 'warn'    then 'last_test_warn'
           when l.self_test_result = 'aborted' then 'last_test_aborted'
           else 'on_schedule'
         end::text as compliance_flag
  from public.defib_aed_units_r3116 u
  left join latest l on l.unit_id = u.id and l.rn = 1
  order by days_overdue desc, u.next_self_test_due_at asc;
end;
$$;

revoke execute on function public.founder_defib_aed_monthly_test_compliance_r3116() from public, anon;
grant execute on function public.founder_defib_aed_monthly_test_compliance_r3116() to authenticated;

-- =======================================================================
-- RPC 7: founder_defib_aed_capa_register_r3116
-- Open CAPA actions across the fleet.
-- =======================================================================
create or replace function public.founder_defib_aed_capa_register_r3116()
returns table (
  capa_action text,
  open_count integer,
  closed_count integer,
  total_cost_rupees integer,
  avg_close_days numeric,
  latest_open_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select coalesce(t.capa_action, 'none')::text as capa_action,
         sum(case when t.capa_required and t.capa_closed_at is null then 1 else 0 end)::int as open_count,
         sum(case when t.capa_required and t.capa_closed_at is not null then 1 else 0 end)::int as closed_count,
         sum(t.cost_rupees)::int as total_cost_rupees,
         round(avg(case when t.capa_closed_at is not null
                        then extract(epoch from (t.capa_closed_at - t.test_performed_at)) / 86400.0
                        end)::numeric, 1) as avg_close_days,
         max(case when t.capa_required and t.capa_closed_at is null then t.test_performed_at end) as latest_open_at
  from public.defib_aed_shock_tests_r3116 t
  where t.capa_required = true
  group by coalesce(t.capa_action, 'none')
  order by open_count desc, total_cost_rupees desc;
end;
$$;

revoke execute on function public.founder_defib_aed_capa_register_r3116() from public, anon;
grant execute on function public.founder_defib_aed_capa_register_r3116() to authenticated;

-- =======================================================================
-- RPC 8: founder_defib_aed_manufacturer_reliability_r3116
-- Reliability index per manufacturer.
-- =======================================================================
create or replace function public.founder_defib_aed_manufacturer_reliability_r3116()
returns table (
  manufacturer text,
  unit_count integer,
  total_tests integer,
  pass_count integer,
  fail_count integer,
  pass_rate_pct numeric,
  avg_energy_deviation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select u.manufacturer::text,
         count(distinct u.id)::int as unit_count,
         count(t.*)::int as total_tests,
         sum(case when t.self_test_result = 'pass' then 1 else 0 end)::int as pass_count,
         sum(case when t.self_test_result = 'fail' then 1 else 0 end)::int as fail_count,
         case when count(t.*) = 0 then 0
              else round((sum(case when t.self_test_result = 'pass' then 1 else 0 end)::numeric * 100.0) / count(t.*)::numeric, 1)
         end as pass_rate_pct,
         coalesce(round(avg(t.energy_deviation_pct), 2), 0) as avg_energy_deviation_pct
  from public.defib_aed_units_r3116 u
  left join public.defib_aed_shock_tests_r3116 t on t.unit_id = u.id
  group by u.manufacturer
  order by pass_rate_pct desc nulls last, unit_count desc;
end;
$$;

revoke execute on function public.founder_defib_aed_manufacturer_reliability_r3116() from public, anon;
grant execute on function public.founder_defib_aed_manufacturer_reliability_r3116() to authenticated;

-- =======================================================================
-- RPC 9: founder_defib_aed_capa_cost_by_ward_r3116
-- CAPA cost rolled up by ward.
-- =======================================================================
create or replace function public.founder_defib_aed_capa_cost_by_ward_r3116()
returns table (
  ward_location text,
  test_count integer,
  capa_count integer,
  total_cost_rupees integer,
  avg_cost_per_test_rupees integer,
  high_cost_flag text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select u.ward_location::text,
         count(t.*)::int as test_count,
         sum(case when t.capa_required then 1 else 0 end)::int as capa_count,
         coalesce(sum(t.cost_rupees), 0)::int as total_cost_rupees,
         case when count(t.*) = 0 then 0
              else (sum(t.cost_rupees) / count(t.*))::int
         end as avg_cost_per_test_rupees,
         case
           when coalesce(sum(t.cost_rupees), 0) >= 7000 then 'high_cost'
           when coalesce(sum(t.cost_rupees), 0) >= 3500 then 'mid_cost'
           else 'low_cost'
         end::text as high_cost_flag
  from public.defib_aed_units_r3116 u
  left join public.defib_aed_shock_tests_r3116 t on t.unit_id = u.id
  group by u.ward_location
  order by total_cost_rupees desc;
end;
$$;

revoke execute on function public.founder_defib_aed_capa_cost_by_ward_r3116() from public, anon;
grant execute on function public.founder_defib_aed_capa_cost_by_ward_r3116() to authenticated;
