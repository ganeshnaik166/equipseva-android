-- Round 3136: Customer Hospital OT Autoclave Sterilization Cycle Bowie-Dick Vacuum Leak Compliance Tracker
-- Steam autoclave cycle log — load type × cycle temp/time × Bowie-Dick × vacuum-leak × biological indicator × helix test × CAPA

-- =============================================================================
-- TABLE 1: autoclave_cycle_log_r3136 — individual sterilization cycle runs
-- =============================================================================
create table if not exists public.autoclave_cycle_log_r3136 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  autoclave_asset_tag text not null,
  autoclave_model text not null,
  cycle_number int not null,
  cycle_date date not null,
  cycle_started_at timestamptz not null,
  cycle_ended_at timestamptz,
  load_type text not null check (load_type in (
    'wrapped_instruments','unwrapped_instruments','textiles_linen',
    'rubber_goods','hollow_lumen_endoscope','porous_load','liquids','implants_orthopedic'
  )),
  program_name text not null check (program_name in (
    '134C_prevac_4min','134C_prevac_18min_prion','121C_gravity_30min',
    '134C_flash_3min_ifu','helix_test_program','bowie_dick_program','vacuum_leak_program','liquid_121C_60min'
  )),
  peak_temperature_c numeric(5,2) not null,
  hold_temperature_min_c numeric(5,2),
  hold_time_seconds int,
  peak_pressure_bar numeric(4,2),
  bowie_dick_result text check (bowie_dick_result in ('pass','fail','uniform_dark','light_center','not_applicable')),
  vacuum_leak_mbar_per_min numeric(5,2),
  vacuum_leak_verdict text check (vacuum_leak_verdict in ('pass','fail','borderline','not_run')),
  biological_indicator_used boolean not null default false,
  bi_result text check (bi_result in ('negative','positive','pending','not_run')),
  helix_test_result text check (helix_test_result in ('pass','fail','not_run','not_applicable')),
  operator_profile_id uuid references public.profiles(id) on delete set null,
  cycle_verdict text not null check (cycle_verdict in (
    'released','quarantined','rejected','recall_needed','pending_review','conditional_release'
  )),
  released_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.autoclave_cycle_log_r3136 enable row level security;

create index if not exists idx_autoclave_cycle_r3136_org on public.autoclave_cycle_log_r3136(organization_id);
create index if not exists idx_autoclave_cycle_r3136_date on public.autoclave_cycle_log_r3136(cycle_date);
create index if not exists idx_autoclave_cycle_r3136_verdict on public.autoclave_cycle_log_r3136(cycle_verdict);

-- =============================================================================
-- TABLE 2: autoclave_capa_actions_r3136 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.autoclave_capa_actions_r3136 (
  id uuid primary key default gen_random_uuid(),
  cycle_log_id uuid not null references public.autoclave_cycle_log_r3136(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'bowie_dick_fail','vacuum_leak_fail','bi_positive','helix_fail',
    'temperature_deviation','pressure_deviation','cycle_abort','wet_pack','operator_error','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'door_gasket_worn','vacuum_pump_degraded','steam_trap_blocked',
    'water_quality_hard','chamber_scale_buildup','sensor_drift',
    'operator_load_error','packaging_defect','power_fluctuation','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_door_gasket','rebuild_vacuum_pump','descale_chamber',
    'replace_steam_trap','recalibrate_temperature_sensor','retrain_operator',
    'requarantine_load','trigger_recall','schedule_amc_visit','none_required','swap_water_softener_cartridge'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees int,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.autoclave_capa_actions_r3136 enable row level security;

create index if not exists idx_autoclave_capa_r3136_cycle on public.autoclave_capa_actions_r3136(cycle_log_id);
create index if not exists idx_autoclave_capa_r3136_status on public.autoclave_capa_actions_r3136(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only (per rule 8)
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
  v_cycle_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 cycle log rows
  insert into public.autoclave_cycle_log_r3136 (
    organization_id, hospital_name, ot_room_code, autoclave_asset_tag, autoclave_model,
    cycle_number, cycle_date, cycle_started_at, cycle_ended_at,
    load_type, program_name, peak_temperature_c, hold_temperature_min_c, hold_time_seconds, peak_pressure_bar,
    bowie_dick_result, vacuum_leak_mbar_per_min, vacuum_leak_verdict,
    biological_indicator_used, bi_result, helix_test_result,
    cycle_verdict, released_at, notes
  )
  select v_org_id, q.hosp, q.ot, q.tag, q.model,
    q.cn, q.cd, q.cs::timestamptz, q.ce::timestamptz,
    q.lt, q.prog, q.pt, q.ht, q.hs, q.pp,
    q.bd, q.vl, q.vv, q.biu, q.br, q.he,
    q.cv, q.rel::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','OT-3','AC-APL-014','Getinge HS6606','1','2026-07-01','2026-07-01 06:10:00+05:30','2026-07-01 06:45:00+05:30',
     'wrapped_instruments','bowie_dick_program',134.20,134.00,210,3.05,'pass',null,'not_run',false,'not_run','not_applicable','released','2026-07-01 07:00:00+05:30','Morning BD test uniform dark change'),
    ('Apollo Hyderabad Jubilee Hills','OT-3','AC-APL-014','Getinge HS6606','2','2026-07-01','2026-07-01 07:05:00+05:30','2026-07-01 07:55:00+05:30',
     'wrapped_instruments','134C_prevac_4min',134.80,134.10,240,3.10,'not_applicable',null,'not_run',true,'negative','not_run','released','2026-07-01 08:10:00+05:30','Routine ortho set'),
    ('Fortis Bannerghatta Bengaluru','OT-1','AC-FRT-007','Steris Amsco 400','8','2026-07-01','2026-07-01 05:30:00+05:30','2026-07-01 06:00:00+05:30',
     'porous_load','vacuum_leak_program',22.00,null,60,null,'not_applicable',1.80,'fail',false,'not_run','not_run','quarantined',null,'Leak 1.8 mbar/min exceeds 1.3 threshold'),
    ('Fortis Bannerghatta Bengaluru','OT-1','AC-FRT-007','Steris Amsco 400','9','2026-07-01','2026-07-01 06:20:00+05:30','2026-07-01 07:10:00+05:30',
     'hollow_lumen_endoscope','helix_test_program',134.10,134.00,220,3.02,'not_applicable',null,'not_run',false,'not_run','fail','recall_needed',null,'Helix indicator failed — endoscope reprocessing suspended'),
    ('Manipal Whitefield Bengaluru','OT-2','AC-MNP-021','Belimed MST-V','15','2026-06-30','2026-06-30 08:15:00+05:30','2026-06-30 09:00:00+05:30',
     'textiles_linen','121C_gravity_30min',121.50,121.10,1800,2.10,'not_applicable',null,'not_run',true,'positive','not_run','recall_needed',null,'BI positive — full load recall triggered'),
    ('Manipal Whitefield Bengaluru','OT-2','AC-MNP-021','Belimed MST-V','16','2026-06-30','2026-06-30 09:30:00+05:30','2026-06-30 10:20:00+05:30',
     'rubber_goods','134C_prevac_4min',134.30,134.00,240,3.08,'pass',0.90,'pass',true,'negative','not_run','released','2026-06-30 10:35:00+05:30','Post-descale first cycle'),
    ('AIIMS New Delhi Ansari Nagar','OT-5','AC-AIM-033','MELAG Vacuklav 44','42','2026-06-30','2026-06-30 06:00:00+05:30','2026-06-30 06:40:00+05:30',
     'unwrapped_instruments','134C_flash_3min_ifu',134.60,134.20,180,3.07,'not_applicable',null,'not_run',false,'not_run','not_applicable','conditional_release','2026-06-30 06:55:00+05:30','Flash cycle emergency only per IFU'),
    ('AIIMS New Delhi Ansari Nagar','OT-5','AC-AIM-033','MELAG Vacuklav 44','43','2026-06-30','2026-06-30 07:00:00+05:30','2026-06-30 08:15:00+05:30',
     'implants_orthopedic','134C_prevac_18min_prion',134.90,134.30,1080,3.12,'pass',0.60,'pass',true,'negative','pass','released','2026-06-30 08:30:00+05:30','Prion-cycle for high-risk implants'),
    ('KIMS Secunderabad','OT-4','AC-KIM-011','Tuttnauer 5075HSG','28','2026-06-29','2026-06-29 05:45:00+05:30','2026-06-29 06:35:00+05:30',
     'wrapped_instruments','134C_prevac_4min',133.20,132.80,240,3.01,'not_applicable',null,'not_run',true,'negative','not_run','quarantined',null,'Temp below 134C setpoint — sensor drift suspected'),
    ('KIMS Secunderabad','OT-4','AC-KIM-011','Tuttnauer 5075HSG','29','2026-06-29','2026-06-29 07:00:00+05:30','2026-06-29 07:20:00+05:30',
     'wrapped_instruments','bowie_dick_program',134.00,133.90,210,3.04,'light_center',null,'not_run',false,'not_run','not_applicable','rejected',null,'BD light-center — vacuum pump likely degraded'),
    ('Care Hospitals Banjara Hills','OT-2','AC-CAR-005','Steelco VS 5-6-9','11','2026-06-29','2026-06-29 09:00:00+05:30','2026-06-29 10:00:00+05:30',
     'liquids','liquid_121C_60min',121.80,121.20,3600,2.08,'not_applicable',null,'not_run',true,'negative','not_run','released','2026-06-29 10:15:00+05:30','Media autoclaving for lab'),
    ('Yashoda Somajiguda Hyderabad','OT-6','AC-YSH-018','Getinge HS6617','67','2026-06-28','2026-06-28 06:30:00+05:30','2026-06-28 07:20:00+05:30',
     'porous_load','134C_prevac_4min',134.40,134.10,240,3.09,'pass',0.75,'pass',false,'not_run','not_run','released','2026-06-28 07:35:00+05:30','Routine daily monitored'),
    ('St John''s Bengaluru','OT-1','AC-STJ-003','MELAG Cliniclave 45','9','2026-06-28','2026-06-28 05:50:00+05:30','2026-06-28 06:30:00+05:30',
     'wrapped_instruments','helix_test_program',134.20,134.00,220,3.05,'not_applicable',null,'not_run',false,'not_run','pass','released','2026-06-28 06:45:00+05:30','Weekly helix — full penetration'),
    ('Rainbow Children''s Hyderabad','OT-3','AC-RBW-009','Tuttnauer T-Max','24','2026-06-27','2026-06-27 07:00:00+05:30',null,
     'wrapped_instruments','134C_prevac_4min',128.50,null,null,2.60,'not_applicable',null,'borderline',false,'not_run','not_run','pending_review',null,'Cycle aborted at 128C — power fluctuation')
  ) as q(hosp, ot, tag, model, cn, cd, cs, ce, lt, prog, pt, ht, hs, pp, bd, vl, vv, biu, br, he, cv, rel, nt)
  where q.cn ~ '^[0-9]+$';

  -- CAPA seed — attach to specific cycles
  insert into public.autoclave_capa_actions_r3136 (
    cycle_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select c.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('Fortis Bannerghatta Bengaluru', 8, 'vacuum_leak_fail','vacuum_pump_degraded','rebuild_vacuum_pump','2026-07-05',null,'in_progress','nabh_finding',48000,'Pump seal kit ordered from Steris'),
    ('Fortis Bannerghatta Bengaluru', 9, 'helix_fail','vacuum_pump_degraded','rebuild_vacuum_pump','2026-07-05',null,'in_progress','patient_safety_alert',48000,'Same root cause as leak — endoscope batch quarantined'),
    ('Manipal Whitefield Bengaluru',15, 'bi_positive','chamber_scale_buildup','descale_chamber','2026-07-02','2026-07-01','closed','cdsco_notifiable',12000,'Scale removal completed, retest passed'),
    ('KIMS Secunderabad',            28, 'temperature_deviation','sensor_drift','recalibrate_temperature_sensor','2026-07-03',null,'verification_pending','iso_13485_deviation',6500,'Calibration company visit scheduled'),
    ('KIMS Secunderabad',            29, 'bowie_dick_fail','vacuum_pump_degraded','rebuild_vacuum_pump','2026-07-04',null,'escalated','nabh_finding',52000,'Second BD fail this week — escalated to service AMC'),
    ('Rainbow Children''s Hyderabad',24, 'cycle_abort','power_fluctuation','schedule_amc_visit','2026-07-06',null,'open','internal_only',3500,'Add UPS to autoclave circuit'),
    ('Apollo Hyderabad Jubilee Hills',1,'preventive_maintenance_due','preventive_service_backlog','schedule_amc_visit','2026-07-15',null,'open','none',15000,'Quarterly PM overdue by 12 days'),
    ('AIIMS New Delhi Ansari Nagar',42,'operator_error','operator_load_error','retrain_operator','2026-07-07','2026-06-30','closed','internal_only',0,'Operator retrained on flash-cycle IFU'),
    ('Manipal Whitefield Bengaluru',16,'wet_pack','water_quality_hard','swap_water_softener_cartridge','2026-07-10',null,'in_progress','iso_13485_deviation',4200,'Feed-water hardness 8 dH — softener saturated'),
    ('Fortis Bannerghatta Bengaluru', 8,'preventive_maintenance_due','preventive_service_backlog','schedule_amc_visit','2026-06-25',null,'overdue','nabh_finding',15000,'PM overdue 6 days — visible in NABH audit')
  ) as q(hosp_key, cn_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.autoclave_cycle_log_r3136 c
    on c.hospital_name = q.hosp_key and c.cycle_number = q.cn_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Cycle verdict distribution
create or replace function public.founder_r3136_cycle_verdict_rollup()
returns table(cycle_verdict text, cycles bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.autoclave_cycle_log_r3136)
  select l.cycle_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.autoclave_cycle_log_r3136 l
  group by l.cycle_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3136_cycle_verdict_rollup() from public, anon;
grant execute on function public.founder_r3136_cycle_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3136_hospital_scorecard()
returns table(
  hospital_name text,
  total_cycles bigint,
  released bigint,
  quarantined bigint,
  recalls bigint,
  bd_fail bigint,
  vl_fail bigint,
  bi_positive bigint,
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
    count(*) filter (where l.cycle_verdict = 'released')::bigint,
    count(*) filter (where l.cycle_verdict = 'quarantined')::bigint,
    count(*) filter (where l.cycle_verdict = 'recall_needed')::bigint,
    count(*) filter (where l.bowie_dick_result in ('fail','light_center'))::bigint,
    count(*) filter (where l.vacuum_leak_verdict = 'fail')::bigint,
    count(*) filter (where l.bi_result = 'positive')::bigint,
    round(100.0 * count(*) filter (where l.cycle_verdict = 'released')::numeric / nullif(count(*),0), 1)
  from public.autoclave_cycle_log_r3136 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3136_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3136_hospital_scorecard() to authenticated;

-- 3) Load-type × program breakdown
create or replace function public.founder_r3136_load_program_matrix()
returns table(load_type text, program_name text, cycles bigint, released bigint, avg_peak_temp numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.load_type, l.program_name, count(*)::bigint,
    count(*) filter (where l.cycle_verdict = 'released')::bigint,
    round(avg(l.peak_temperature_c), 2)
  from public.autoclave_cycle_log_r3136 l
  group by l.load_type, l.program_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3136_load_program_matrix() from public, anon;
grant execute on function public.founder_r3136_load_program_matrix() to authenticated;

-- 4) Bowie-Dick + vacuum leak weekly trend
create or replace function public.founder_r3136_bd_vl_daily_trend()
returns table(cycle_date date, bd_pass bigint, bd_fail bigint, vl_pass bigint, vl_fail bigint, vl_borderline bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cycle_date,
    count(*) filter (where l.bowie_dick_result = 'pass')::bigint,
    count(*) filter (where l.bowie_dick_result in ('fail','light_center'))::bigint,
    count(*) filter (where l.vacuum_leak_verdict = 'pass')::bigint,
    count(*) filter (where l.vacuum_leak_verdict = 'fail')::bigint,
    count(*) filter (where l.vacuum_leak_verdict = 'borderline')::bigint
  from public.autoclave_cycle_log_r3136 l
  group by l.cycle_date
  order by l.cycle_date desc;
end;
$$;

revoke execute on function public.founder_r3136_bd_vl_daily_trend() from public, anon;
grant execute on function public.founder_r3136_bd_vl_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3136_capa_status_board()
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
  from public.autoclave_capa_actions_r3136 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3136_capa_status_board() from public, anon;
grant execute on function public.founder_r3136_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3136_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.autoclave_capa_actions_r3136)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.autoclave_capa_actions_r3136 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3136_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3136_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3136_regulatory_impact_digest()
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
  from public.autoclave_capa_actions_r3136 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3136_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3136_regulatory_impact_digest() to authenticated;

-- 8) High-risk cycles list (top individual concerns)
create or replace function public.founder_r3136_high_risk_cycles()
returns table(
  hospital_name text,
  ot_room_code text,
  autoclave_asset_tag text,
  cycle_date date,
  cycle_verdict text,
  bowie_dick_result text,
  vacuum_leak_verdict text,
  bi_result text,
  helix_test_result text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_room_code, l.autoclave_asset_tag, l.cycle_date,
    l.cycle_verdict, l.bowie_dick_result, l.vacuum_leak_verdict, l.bi_result, l.helix_test_result, l.notes
  from public.autoclave_cycle_log_r3136 l
  where l.cycle_verdict in ('quarantined','rejected','recall_needed','pending_review','conditional_release')
     or l.bi_result = 'positive'
     or l.bowie_dick_result in ('fail','light_center')
     or l.vacuum_leak_verdict = 'fail'
     or l.helix_test_result = 'fail'
  order by l.cycle_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3136_high_risk_cycles() from public, anon;
grant execute on function public.founder_r3136_high_risk_cycles() to authenticated;
