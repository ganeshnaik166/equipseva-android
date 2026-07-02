-- Round 3100: Customer Hospital Operating-Theatre HEPA Filter Bank Particulate Count Compliance Tracker
-- Tracks OT HEPA filter bank performance: at-rest / in-operation particulate counts,
-- ISO Class compliance, filter age, differential pressure, replacement queue.

begin;

-- =====================================================================
-- Table 1: OT HEPA filter bank registry (per-filter inventory + lifecycle)
-- =====================================================================
create table if not exists public.ot_hepa_filter_bank_r3100 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid not null references public.organizations(id) on delete cascade,
  ot_room_code text not null,
  ot_classification text not null check (ot_classification in (
    'super_specialty_iso5','general_iso7','minor_procedure_iso8','cath_lab_iso7','transplant_iso5'
  )),
  filter_position text not null check (filter_position in (
    'terminal_ceiling','return_air','prefilter_stage1','prefilter_stage2','laminar_flow_panel'
  )),
  filter_grade text not null check (filter_grade in (
    'hepa_h13','hepa_h14','ulpa_u15','ulpa_u16','prefilter_f7','prefilter_f9'
  )),
  manufacturer text not null check (manufacturer in (
    'camfil_india','aaf_flanders','spectrum_filtration','dynamic_filters','clean_air_concept','thermadyne'
  )),
  installed_on date not null,
  rated_life_months integer not null check (rated_life_months between 6 and 60),
  current_age_months integer not null check (current_age_months >= 0),
  last_dop_test_on date,
  filter_status text not null check (filter_status in (
    'in_service','watchlist','replacement_due','breached_compliance','decommissioned','quarantine'
  )),
  replacement_priority text not null check (replacement_priority in (
    'p0_immediate','p1_within_7d','p2_within_30d','p3_scheduled','p4_no_action'
  )),
  amc_contract_id uuid references public.amc_contracts(id) on delete set null,
  assigned_engineer_id uuid references public.engineers(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_hepa_bank_r3100_hosp on public.ot_hepa_filter_bank_r3100(hospital_org_id);
create index if not exists idx_hepa_bank_r3100_status on public.ot_hepa_filter_bank_r3100(filter_status);
create index if not exists idx_hepa_bank_r3100_priority on public.ot_hepa_filter_bank_r3100(replacement_priority);

-- =====================================================================
-- Table 2: Particulate count test readings (per-filter, per-test event)
-- =====================================================================
create table if not exists public.ot_hepa_particulate_readings_r3100 (
  id uuid primary key default gen_random_uuid(),
  filter_id uuid not null references public.ot_hepa_filter_bank_r3100(id) on delete cascade,
  reading_taken_at timestamptz not null,
  operational_state text not null check (operational_state in (
    'at_rest','in_operation','recovery_test','post_replacement','post_dop'
  )),
  particle_size_um numeric(4,2) not null check (particle_size_um in (0.30, 0.50, 1.00, 5.00)),
  count_per_m3 bigint not null check (count_per_m3 >= 0),
  iso_class_target text not null check (iso_class_target in ('iso5','iso6','iso7','iso8')),
  iso_class_observed text not null check (iso_class_observed in ('iso5','iso6','iso7','iso8','iso9','out_of_class')),
  differential_pressure_pa integer not null check (differential_pressure_pa between -50 and 800),
  air_changes_per_hour integer not null check (air_changes_per_hour between 0 and 60),
  temperature_celsius numeric(4,1) not null check (temperature_celsius between 12.0 and 30.0),
  relative_humidity_pct numeric(4,1) not null check (relative_humidity_pct between 20.0 and 80.0),
  compliance_verdict text not null check (compliance_verdict in (
    'pass','marginal','fail','catastrophic','requires_retest'
  )),
  nabh_reportable boolean not null default false,
  test_method text not null check (test_method in (
    'iso_14644_handheld','iso_14644_remote_probe','dop_aerosol','pao_aerosol','particle_imager'
  )),
  recorded_by_profile_id uuid references public.profiles(id) on delete set null,
  repair_job_id uuid references public.repair_jobs(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_particulate_r3100_filter on public.ot_hepa_particulate_readings_r3100(filter_id);
create index if not exists idx_particulate_r3100_verdict on public.ot_hepa_particulate_readings_r3100(compliance_verdict);
create index if not exists idx_particulate_r3100_state on public.ot_hepa_particulate_readings_r3100(operational_state);

-- =====================================================================
-- Seed data
-- =====================================================================
do $seed$
declare
  v_org uuid;
  v_filter1 uuid := gen_random_uuid();
  v_filter2 uuid := gen_random_uuid();
  v_filter3 uuid := gen_random_uuid();
  v_filter4 uuid := gen_random_uuid();
  v_filter5 uuid := gen_random_uuid();
  v_filter6 uuid := gen_random_uuid();
begin
  select id into v_org from public.organizations where true limit 1;
  if v_org is null then
    return;
  end if;

  insert into public.ot_hepa_filter_bank_r3100
    (id, hospital_org_id, ot_room_code, ot_classification, filter_position, filter_grade, manufacturer,
     installed_on, rated_life_months, current_age_months, last_dop_test_on, filter_status, replacement_priority)
  values
    (v_filter1, v_org, 'OT-1-CARDIAC', 'super_specialty_iso5', 'terminal_ceiling', 'hepa_h14', 'camfil_india',
     '2024-03-12', 36, 27, '2026-04-10', 'watchlist', 'p2_within_30d'),
    (v_filter2, v_org, 'OT-2-NEURO', 'super_specialty_iso5', 'laminar_flow_panel', 'ulpa_u15', 'aaf_flanders',
     '2023-11-05', 36, 31, '2026-03-22', 'replacement_due', 'p1_within_7d'),
    (v_filter3, v_org, 'OT-3-GENERAL', 'general_iso7', 'terminal_ceiling', 'hepa_h13', 'spectrum_filtration',
     '2025-01-18', 24, 17, '2026-05-02', 'in_service', 'p4_no_action'),
    (v_filter4, v_org, 'OT-4-ORTHO', 'general_iso7', 'return_air', 'prefilter_f9', 'dynamic_filters',
     '2024-09-21', 18, 21, null, 'breached_compliance', 'p0_immediate'),
    (v_filter5, v_org, 'CATH-LAB-1', 'cath_lab_iso7', 'terminal_ceiling', 'hepa_h14', 'clean_air_concept',
     '2025-06-30', 30, 12, '2026-05-15', 'in_service', 'p3_scheduled'),
    (v_filter6, v_org, 'OT-5-MINOR', 'minor_procedure_iso8', 'prefilter_stage1', 'prefilter_f7', 'thermadyne',
     '2024-12-01', 12, 18, null, 'decommissioned', 'p4_no_action');

  insert into public.ot_hepa_particulate_readings_r3100
    (filter_id, reading_taken_at, operational_state, particle_size_um, count_per_m3,
     iso_class_target, iso_class_observed, differential_pressure_pa, air_changes_per_hour,
     temperature_celsius, relative_humidity_pct, compliance_verdict, nabh_reportable, test_method)
  values
    (v_filter1, now() - interval '2 days', 'at_rest', 0.50, 2840, 'iso5', 'iso5', 245, 24, 21.5, 48.0, 'pass', false, 'iso_14644_handheld'),
    (v_filter1, now() - interval '2 days', 'in_operation', 0.50, 18420, 'iso5', 'iso6', 235, 24, 22.1, 51.0, 'marginal', false, 'iso_14644_remote_probe'),
    (v_filter2, now() - interval '1 day', 'in_operation', 0.30, 41200, 'iso5', 'iso7', 180, 18, 22.8, 55.0, 'fail', true, 'iso_14644_remote_probe'),
    (v_filter2, now() - interval '1 day', 'at_rest', 0.50, 12300, 'iso5', 'iso6', 175, 18, 22.0, 52.0, 'fail', true, 'iso_14644_handheld'),
    (v_filter3, now() - interval '5 days', 'at_rest', 0.50, 89500, 'iso7', 'iso7', 290, 20, 21.0, 47.0, 'pass', false, 'iso_14644_handheld'),
    (v_filter3, now() - interval '5 days', 'in_operation', 1.00, 12400, 'iso7', 'iso7', 285, 20, 21.4, 49.0, 'pass', false, 'iso_14644_handheld'),
    (v_filter4, now() - interval '12 hours', 'in_operation', 0.50, 980000, 'iso7', 'out_of_class', 95, 12, 24.5, 62.0, 'catastrophic', true, 'particle_imager'),
    (v_filter4, now() - interval '12 hours', 'at_rest', 5.00, 88000, 'iso7', 'iso9', 92, 12, 24.0, 60.0, 'catastrophic', true, 'iso_14644_handheld'),
    (v_filter5, now() - interval '3 days', 'at_rest', 0.50, 14200, 'iso7', 'iso6', 260, 22, 21.8, 46.0, 'pass', false, 'dop_aerosol'),
    (v_filter5, now() - interval '3 days', 'post_dop', 0.30, 8400, 'iso7', 'iso6', 268, 22, 21.6, 45.0, 'pass', false, 'dop_aerosol'),
    (v_filter6, now() - interval '20 days', 'in_operation', 5.00, 720000, 'iso8', 'iso9', 60, 10, 25.2, 64.0, 'fail', true, 'iso_14644_handheld'),
    (v_filter6, now() - interval '20 days', 'at_rest', 1.00, 240000, 'iso8', 'iso8', 65, 10, 24.8, 63.0, 'marginal', false, 'iso_14644_handheld'),
    (v_filter1, now() - interval '14 days', 'recovery_test', 0.50, 6800, 'iso5', 'iso5', 248, 24, 21.3, 47.5, 'pass', false, 'iso_14644_remote_probe'),
    (v_filter2, now() - interval '7 days', 'post_replacement', 0.30, 22500, 'iso5', 'iso6', 178, 18, 22.4, 53.0, 'requires_retest', false, 'pao_aerosol');
end;
$seed$;

-- =====================================================================
-- RPC 1: bank summary by hospital
-- =====================================================================
create or replace function public.r3100_hepa_bank_by_hospital()
returns table (
  hospital_org_id uuid,
  hospital_name text,
  total_filters bigint,
  breached bigint,
  replacement_due bigint,
  watchlist bigint,
  in_service bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.hospital_org_id,
         o.name,
         count(*)::bigint,
         count(*) filter (where b.filter_status = 'breached_compliance')::bigint,
         count(*) filter (where b.filter_status = 'replacement_due')::bigint,
         count(*) filter (where b.filter_status = 'watchlist')::bigint,
         count(*) filter (where b.filter_status = 'in_service')::bigint
  from public.ot_hepa_filter_bank_r3100 b
  join public.organizations o on o.id = b.hospital_org_id
  group by b.hospital_org_id, o.name
  order by count(*) filter (where b.filter_status = 'breached_compliance') desc;
end;
$$;

revoke execute on function public.r3100_hepa_bank_by_hospital() from public, anon;
grant execute on function public.r3100_hepa_bank_by_hospital() to authenticated;

-- =====================================================================
-- RPC 2: replacement priority queue
-- =====================================================================
create or replace function public.r3100_replacement_priority_queue()
returns table (
  priority text,
  filter_count bigint,
  avg_age_months numeric,
  oldest_install_date date
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.replacement_priority,
         count(*)::bigint,
         round(avg(b.current_age_months)::numeric, 1),
         min(b.installed_on)
  from public.ot_hepa_filter_bank_r3100 b
  group by b.replacement_priority
  order by case b.replacement_priority
    when 'p0_immediate' then 0
    when 'p1_within_7d' then 1
    when 'p2_within_30d' then 2
    when 'p3_scheduled' then 3
    when 'p4_no_action' then 4 end;
end;
$$;

revoke execute on function public.r3100_replacement_priority_queue() from public, anon;
grant execute on function public.r3100_replacement_priority_queue() to authenticated;

-- =====================================================================
-- RPC 3: ISO class compliance breakdown
-- =====================================================================
create or replace function public.r3100_iso_class_compliance()
returns table (
  iso_class_target text,
  total_readings bigint,
  pass_count bigint,
  marginal_count bigint,
  fail_count bigint,
  catastrophic_count bigint,
  pass_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.iso_class_target,
         count(*)::bigint,
         count(*) filter (where r.compliance_verdict = 'pass')::bigint,
         count(*) filter (where r.compliance_verdict = 'marginal')::bigint,
         count(*) filter (where r.compliance_verdict = 'fail')::bigint,
         count(*) filter (where r.compliance_verdict = 'catastrophic')::bigint,
         round(100.0 * count(*) filter (where r.compliance_verdict = 'pass') / nullif(count(*),0), 1)
  from public.ot_hepa_particulate_readings_r3100 r
  group by r.iso_class_target
  order by r.iso_class_target;
end;
$$;

revoke execute on function public.r3100_iso_class_compliance() from public, anon;
grant execute on function public.r3100_iso_class_compliance() to authenticated;

-- =====================================================================
-- RPC 4: differential pressure outliers
-- =====================================================================
create or replace function public.r3100_pressure_outliers()
returns table (
  ot_room_code text,
  filter_position text,
  min_pressure_pa integer,
  max_pressure_pa integer,
  avg_pressure_pa numeric,
  last_reading_at timestamptz
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.ot_room_code,
         b.filter_position,
         min(r.differential_pressure_pa),
         max(r.differential_pressure_pa),
         round(avg(r.differential_pressure_pa)::numeric, 1),
         max(r.reading_taken_at)
  from public.ot_hepa_filter_bank_r3100 b
  join public.ot_hepa_particulate_readings_r3100 r on r.filter_id = b.id
  group by b.ot_room_code, b.filter_position
  having min(r.differential_pressure_pa) < 150 or max(r.differential_pressure_pa) > 350
  order by min(r.differential_pressure_pa);
end;
$$;

revoke execute on function public.r3100_pressure_outliers() from public, anon;
grant execute on function public.r3100_pressure_outliers() to authenticated;

-- =====================================================================
-- RPC 5: filter age vs life expectancy
-- =====================================================================
create or replace function public.r3100_filter_age_vs_life()
returns table (
  ot_room_code text,
  filter_grade text,
  manufacturer text,
  current_age_months integer,
  rated_life_months integer,
  pct_life_used numeric,
  filter_status text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.ot_room_code,
         b.filter_grade,
         b.manufacturer,
         b.current_age_months,
         b.rated_life_months,
         round(100.0 * b.current_age_months / nullif(b.rated_life_months,0), 1),
         b.filter_status
  from public.ot_hepa_filter_bank_r3100 b
  order by (100.0 * b.current_age_months / nullif(b.rated_life_months,0)) desc nulls last;
end;
$$;

revoke execute on function public.r3100_filter_age_vs_life() from public, anon;
grant execute on function public.r3100_filter_age_vs_life() to authenticated;

-- =====================================================================
-- RPC 6: at-rest vs in-operation delta
-- =====================================================================
create or replace function public.r3100_at_rest_vs_operation_delta()
returns table (
  ot_room_code text,
  at_rest_avg_count numeric,
  in_op_avg_count numeric,
  delta_multiplier numeric,
  reading_pairs bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.ot_room_code,
         round(avg(r.count_per_m3) filter (where r.operational_state = 'at_rest')::numeric, 0),
         round(avg(r.count_per_m3) filter (where r.operational_state = 'in_operation')::numeric, 0),
         round((avg(r.count_per_m3) filter (where r.operational_state = 'in_operation') /
                nullif(avg(r.count_per_m3) filter (where r.operational_state = 'at_rest'),0))::numeric, 2),
         count(*)::bigint
  from public.ot_hepa_filter_bank_r3100 b
  join public.ot_hepa_particulate_readings_r3100 r on r.filter_id = b.id
  group by b.ot_room_code
  having count(*) filter (where r.operational_state = 'at_rest') > 0
     and count(*) filter (where r.operational_state = 'in_operation') > 0
  order by 4 desc;
end;
$$;

revoke execute on function public.r3100_at_rest_vs_operation_delta() from public, anon;
grant execute on function public.r3100_at_rest_vs_operation_delta() to authenticated;

-- =====================================================================
-- RPC 7: NABH reportable incidents
-- =====================================================================
create or replace function public.r3100_nabh_reportable_incidents()
returns table (
  ot_room_code text,
  ot_classification text,
  reading_taken_at timestamptz,
  operational_state text,
  count_per_m3 bigint,
  iso_class_observed text,
  compliance_verdict text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.ot_room_code,
         b.ot_classification,
         r.reading_taken_at,
         r.operational_state,
         r.count_per_m3,
         r.iso_class_observed,
         r.compliance_verdict
  from public.ot_hepa_particulate_readings_r3100 r
  join public.ot_hepa_filter_bank_r3100 b on b.id = r.filter_id
  where r.nabh_reportable = true
  order by r.reading_taken_at desc;
end;
$$;

revoke execute on function public.r3100_nabh_reportable_incidents() from public, anon;
grant execute on function public.r3100_nabh_reportable_incidents() to authenticated;

-- =====================================================================
-- RPC 8: manufacturer reliability scorecard
-- =====================================================================
create or replace function public.r3100_manufacturer_scorecard()
returns table (
  manufacturer text,
  filter_count bigint,
  avg_age_months numeric,
  fail_or_worse_readings bigint,
  total_readings bigint,
  failure_rate_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.manufacturer,
         count(distinct b.id)::bigint,
         round(avg(b.current_age_months)::numeric, 1),
         count(*) filter (where r.compliance_verdict in ('fail','catastrophic'))::bigint,
         count(r.id)::bigint,
         round(100.0 * count(*) filter (where r.compliance_verdict in ('fail','catastrophic')) /
               nullif(count(r.id),0), 1)
  from public.ot_hepa_filter_bank_r3100 b
  left join public.ot_hepa_particulate_readings_r3100 r on r.filter_id = b.id
  group by b.manufacturer
  order by 6 desc nulls last;
end;
$$;

revoke execute on function public.r3100_manufacturer_scorecard() from public, anon;
grant execute on function public.r3100_manufacturer_scorecard() to authenticated;

commit;
