-- Round 3104 HEAVY ★★★★
-- Customer Hospital Reverse-Osmosis Dialysis Water Quality Endotoxin Audit
-- Monthly dialysis-loop RO water testing — endotoxin EU/mL, chlorine ppm,
-- hardness, bacterial colony count, AAMI/ISO compliance + purification action queue.

set search_path = public, pg_temp;

-- =========================================================================
-- TABLE 1: monthly RO water sample test results
-- =========================================================================
create table if not exists dialysis_ro_water_samples_r3104 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  hospital_unit_name text not null,
  sample_collected_at timestamptz not null default now(),
  sample_point text not null check (sample_point in (
    'pre_ro_feed','post_ro_permeate','loop_return','distal_port','mid_loop_tap','reuse_machine_inlet'
  )),
  endotoxin_eu_per_ml numeric(8,3) not null check (endotoxin_eu_per_ml >= 0),
  chlorine_ppm numeric(6,3) not null check (chlorine_ppm >= 0),
  total_hardness_mg_l numeric(8,2) not null check (total_hardness_mg_l >= 0),
  bacterial_colony_cfu_per_ml numeric(10,2) not null check (bacterial_colony_cfu_per_ml >= 0),
  conductivity_us_cm numeric(8,2) not null check (conductivity_us_cm >= 0),
  ph_value numeric(4,2) not null check (ph_value between 0 and 14),
  aami_compliance_status text not null check (aami_compliance_status in (
    'aami_compliant','aami_action_level','aami_failure','iso23500_compliant','iso23500_failure','pending_recheck'
  )),
  test_method text not null check (test_method in (
    'lal_kinetic_chromogenic','lal_gel_clot','dpd_colorimetric','edta_titration','membrane_filtration_r2a','tryptic_soy_agar_pour_plate'
  )),
  lab_partner text not null check (lab_partner in (
    'sgs_india_hyderabad','tuv_sud_bangalore','intertek_chennai','equinox_mumbai','in_house_microbiology_lab'
  )),
  sampled_by_engineer_id uuid references engineers(id) on delete set null,
  reviewed_by_profile_id uuid references profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_ro_samples_org_r3104 on dialysis_ro_water_samples_r3104(organization_id);
create index if not exists idx_ro_samples_status_r3104 on dialysis_ro_water_samples_r3104(aami_compliance_status);
create index if not exists idx_ro_samples_collected_r3104 on dialysis_ro_water_samples_r3104(sample_collected_at desc);

alter table dialysis_ro_water_samples_r3104 enable row level security;

-- =========================================================================
-- TABLE 2: purification action queue (what to do about failing samples)
-- =========================================================================
create table if not exists dialysis_ro_purification_actions_r3104 (
  id uuid primary key default gen_random_uuid(),
  sample_id uuid not null references dialysis_ro_water_samples_r3104(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,
  action_type text not null check (action_type in (
    'heat_disinfect_loop','chemical_disinfect_peracetic','replace_ro_membrane','regenerate_softener_resin',
    'flush_distal_dead_leg','replace_carbon_filter','escalate_to_nephrology','schedule_third_party_audit',
    'shut_down_unit_until_pass','add_uv_sterilizer'
  )),
  priority text not null check (priority in ('p0_patient_safety','p1_urgent','p2_planned','p3_routine')),
  status text not null check (status in (
    'queued','in_progress','awaiting_parts','completed','verified_clean','escalated_to_founder','cancelled'
  )),
  assigned_engineer_id uuid references engineers(id) on delete set null,
  target_completion_at timestamptz not null,
  completed_at timestamptz,
  cost_estimate_rupees numeric(12,2) not null default 0 check (cost_estimate_rupees >= 0),
  actual_cost_rupees numeric(12,2) check (actual_cost_rupees is null or actual_cost_rupees >= 0),
  vendor_required text check (vendor_required is null or vendor_required in (
    'fresenius_india','b_braun_avitum','nipro_medical','aquatech_chennai','ion_exchange_india','none'
  )),
  resolution_notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_ro_actions_status_r3104 on dialysis_ro_purification_actions_r3104(status);
create index if not exists idx_ro_actions_priority_r3104 on dialysis_ro_purification_actions_r3104(priority);
create index if not exists idx_ro_actions_sample_r3104 on dialysis_ro_purification_actions_r3104(sample_id);

alter table dialysis_ro_purification_actions_r3104 enable row level security;

-- =========================================================================
-- SEED DATA — 14 sample rows + 12 action rows
-- =========================================================================
do $seed$
declare
  v_org uuid;
  v_eng uuid;
  v_prof uuid;
  s1 uuid; s2 uuid; s3 uuid; s4 uuid; s5 uuid; s6 uuid;
  s7 uuid; s8 uuid; s9 uuid; s10 uuid; s11 uuid; s12 uuid;
  s13 uuid; s14 uuid;
begin
  select id into v_org from organizations order by created_at asc limit 1;
  if v_org is null then
    return;
  end if;
  select id into v_eng from engineers order by created_at asc limit 1;
  select id into v_prof from profiles order by created_at asc limit 1;

  insert into dialysis_ro_water_samples_r3104
    (id, organization_id, hospital_unit_name, sample_collected_at, sample_point,
     endotoxin_eu_per_ml, chlorine_ppm, total_hardness_mg_l, bacterial_colony_cfu_per_ml,
     conductivity_us_cm, ph_value, aami_compliance_status, test_method, lab_partner,
     sampled_by_engineer_id, reviewed_by_profile_id, notes)
  values
    (gen_random_uuid(), v_org, 'Apollo Hyderabad Dialysis Ward A', now() - interval '2 days', 'post_ro_permeate',
      0.045, 0.02, 0.8, 12.0, 8.5, 6.9, 'aami_compliant', 'lal_kinetic_chromogenic', 'sgs_india_hyderabad', v_eng, v_prof, 'Monthly routine, clean pass'),
    (gen_random_uuid(), v_org, 'Yashoda Secunderabad NephroBlock', now() - interval '5 days', 'loop_return',
      0.32, 0.08, 1.2, 95.0, 11.2, 7.1, 'aami_action_level', 'lal_kinetic_chromogenic', 'tuv_sud_bangalore', v_eng, v_prof, 'Action level — disinfect loop'),
    (gen_random_uuid(), v_org, 'KIMS Kondapur Dialysis Unit', now() - interval '8 days', 'distal_port',
      0.61, 0.15, 2.1, 245.0, 14.8, 7.4, 'aami_failure', 'lal_gel_clot', 'intertek_chennai', v_eng, v_prof, 'FAILURE — distal dead leg suspect'),
    (gen_random_uuid(), v_org, 'Sunshine Begumpet Renal Care', now() - interval '12 days', 'pre_ro_feed',
      4.5, 0.45, 185.0, 1200.0, 480.0, 7.6, 'iso23500_failure', 'dpd_colorimetric', 'equinox_mumbai', v_eng, v_prof, 'Pre-RO feed — softener exhausted'),
    (gen_random_uuid(), v_org, 'Care Banjara Hills Acute Dialysis', now() - interval '15 days', 'post_ro_permeate',
      0.08, 0.01, 0.5, 8.0, 6.8, 6.8, 'iso23500_compliant', 'lal_kinetic_chromogenic', 'in_house_microbiology_lab', v_eng, v_prof, 'Within ISO 23500 ultrapure'),
    (gen_random_uuid(), v_org, 'Continental Gachibowli HemoDialysis', now() - interval '18 days', 'mid_loop_tap',
      0.28, 0.06, 0.9, 78.0, 9.4, 7.0, 'aami_action_level', 'membrane_filtration_r2a', 'sgs_india_hyderabad', v_eng, v_prof, 'Mid loop — bacterial trending up'),
    (gen_random_uuid(), v_org, 'AIG Gachibowli Renal Ward 2', now() - interval '21 days', 'reuse_machine_inlet',
      0.18, 0.03, 1.0, 42.0, 9.9, 6.95, 'aami_compliant', 'lal_kinetic_chromogenic', 'tuv_sud_bangalore', v_eng, v_prof, 'Reuse machine — within spec'),
    (gen_random_uuid(), v_org, 'NIMS Punjagutta Dialysis Centre', now() - interval '25 days', 'loop_return',
      0.55, 0.12, 1.8, 188.0, 13.5, 7.3, 'aami_failure', 'tryptic_soy_agar_pour_plate', 'intertek_chennai', v_eng, v_prof, 'Loop return failure — heat disinfect ordered'),
    (gen_random_uuid(), v_org, 'Olive Hospital Mehdipatnam Dialysis', now() - interval '28 days', 'distal_port',
      0.12, 0.02, 0.6, 22.0, 8.1, 6.85, 'aami_compliant', 'lal_kinetic_chromogenic', 'equinox_mumbai', v_eng, v_prof, 'Distal port pass'),
    (gen_random_uuid(), v_org, 'Star Banjara Hills Renal Unit', now() - interval '32 days', 'post_ro_permeate',
      0.42, 0.09, 1.4, 132.0, 12.6, 7.2, 'aami_action_level', 'lal_kinetic_chromogenic', 'sgs_india_hyderabad', v_eng, v_prof, 'Action level — schedule peracetic'),
    (gen_random_uuid(), v_org, 'Medicover HiTech City Nephro', now() - interval '38 days', 'pre_ro_feed',
      3.8, 0.38, 165.0, 950.0, 420.0, 7.55, 'iso23500_failure', 'edta_titration', 'tuv_sud_bangalore', v_eng, v_prof, 'Feed water hardness exceeded'),
    (gen_random_uuid(), v_org, 'Rainbow Children Banjara Pediatric Dialysis', now() - interval '42 days', 'post_ro_permeate',
      0.02, 0.01, 0.3, 4.0, 5.9, 6.75, 'iso23500_compliant', 'lal_kinetic_chromogenic', 'in_house_microbiology_lab', v_eng, v_prof, 'Pediatric ultrapure — excellent'),
    (gen_random_uuid(), v_org, 'Citizens Specialty Nallagandla Dialysis', now() - interval '48 days', 'loop_return',
      0.22, 0.05, 1.1, 64.0, 10.5, 7.05, 'pending_recheck', 'membrane_filtration_r2a', 'intertek_chennai', v_eng, v_prof, 'Borderline — recheck in 48h'),
    (gen_random_uuid(), v_org, 'Asian Institute Mindspace Renal', now() - interval '55 days', 'mid_loop_tap',
      0.68, 0.18, 2.4, 312.0, 16.2, 7.5, 'aami_failure', 'lal_gel_clot', 'equinox_mumbai', v_eng, v_prof, 'Severe failure — unit shutdown initiated')
  ;

  -- Re-collect ids in collection order for actions
  select id into s1 from dialysis_ro_water_samples_r3104 where hospital_unit_name='Yashoda Secunderabad NephroBlock' limit 1;
  select id into s2 from dialysis_ro_water_samples_r3104 where hospital_unit_name='KIMS Kondapur Dialysis Unit' limit 1;
  select id into s3 from dialysis_ro_water_samples_r3104 where hospital_unit_name='Sunshine Begumpet Renal Care' limit 1;
  select id into s4 from dialysis_ro_water_samples_r3104 where hospital_unit_name='Continental Gachibowli HemoDialysis' limit 1;
  select id into s5 from dialysis_ro_water_samples_r3104 where hospital_unit_name='NIMS Punjagutta Dialysis Centre' limit 1;
  select id into s6 from dialysis_ro_water_samples_r3104 where hospital_unit_name='Star Banjara Hills Renal Unit' limit 1;
  select id into s7 from dialysis_ro_water_samples_r3104 where hospital_unit_name='Medicover HiTech City Nephro' limit 1;
  select id into s8 from dialysis_ro_water_samples_r3104 where hospital_unit_name='Citizens Specialty Nallagandla Dialysis' limit 1;
  select id into s9 from dialysis_ro_water_samples_r3104 where hospital_unit_name='Asian Institute Mindspace Renal' limit 1;
  select id into s10 from dialysis_ro_water_samples_r3104 where hospital_unit_name='Apollo Hyderabad Dialysis Ward A' limit 1;
  select id into s11 from dialysis_ro_water_samples_r3104 where hospital_unit_name='Care Banjara Hills Acute Dialysis' limit 1;
  select id into s12 from dialysis_ro_water_samples_r3104 where hospital_unit_name='Olive Hospital Mehdipatnam Dialysis' limit 1;

  insert into dialysis_ro_purification_actions_r3104
    (sample_id, organization_id, action_type, priority, status, assigned_engineer_id,
     target_completion_at, completed_at, cost_estimate_rupees, actual_cost_rupees, vendor_required, resolution_notes)
  values
    (s1, v_org, 'chemical_disinfect_peracetic', 'p1_urgent', 'in_progress', v_eng,
      now() + interval '2 days', null, 18500.00, null, 'fresenius_india', 'Peracetic acid disinfection scheduled overnight'),
    (s2, v_org, 'flush_distal_dead_leg', 'p0_patient_safety', 'queued', v_eng,
      now() + interval '1 day', null, 22000.00, null, 'aquatech_chennai', 'Distal dead leg flush — coordinate with nephrology'),
    (s3, v_org, 'regenerate_softener_resin', 'p1_urgent', 'awaiting_parts', v_eng,
      now() + interval '3 days', null, 8500.00, null, 'ion_exchange_india', 'Awaiting brine salt resupply'),
    (s4, v_org, 'add_uv_sterilizer', 'p2_planned', 'queued', v_eng,
      now() + interval '7 days', null, 145000.00, null, 'aquatech_chennai', 'UV sterilizer install for bacterial control'),
    (s5, v_org, 'heat_disinfect_loop', 'p0_patient_safety', 'completed', v_eng,
      now() + interval '1 day', now() - interval '20 days', 12000.00, 11800.00, 'b_braun_avitum', 'Heat cycle 85C 30min — clean'),
    (s6, v_org, 'chemical_disinfect_peracetic', 'p1_urgent', 'verified_clean', v_eng,
      now() + interval '2 days', now() - interval '28 days', 18500.00, 18000.00, 'fresenius_india', 'Post-disinfect endotoxin 0.04 EU/mL'),
    (s7, v_org, 'replace_ro_membrane', 'p1_urgent', 'in_progress', v_eng,
      now() + interval '5 days', null, 285000.00, null, 'nipro_medical', 'Hardness breakthrough — RO membrane fouled'),
    (s8, v_org, 'schedule_third_party_audit', 'p3_routine', 'queued', v_eng,
      now() + interval '14 days', null, 35000.00, null, 'none', 'Quarterly third-party AAMI audit'),
    (s9, v_org, 'shut_down_unit_until_pass', 'p0_patient_safety', 'escalated_to_founder', v_eng,
      now() + interval '1 day', null, 0.00, null, 'none', 'Unit shutdown — patients shifted to peer hospital'),
    (s10, v_org, 'replace_carbon_filter', 'p3_routine', 'completed', v_eng,
      now() + interval '10 days', now() - interval '1 day', 6500.00, 6500.00, 'aquatech_chennai', 'Annual carbon swap'),
    (s11, v_org, 'escalate_to_nephrology', 'p2_planned', 'cancelled', v_eng,
      now() + interval '4 days', null, 0.00, null, 'none', 'Cancelled — false alarm on borderline result'),
    (s12, v_org, 'heat_disinfect_loop', 'p3_routine', 'verified_clean', v_eng,
      now() + interval '6 days', now() - interval '25 days', 12000.00, 11500.00, 'b_braun_avitum', 'Routine monthly heat cycle');
end;
$seed$;

-- =========================================================================
-- RPC 1: overall AAMI/ISO compliance rollup
-- =========================================================================
create or replace function founder_r3104_compliance_rollup()
returns table (
  compliance_status text,
  sample_count bigint,
  avg_endotoxin_eu_per_ml numeric,
  avg_cfu_per_ml numeric,
  worst_endotoxin numeric
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
    select s.aami_compliance_status,
           count(*)::bigint,
           round(avg(s.endotoxin_eu_per_ml)::numeric, 3),
           round(avg(s.bacterial_colony_cfu_per_ml)::numeric, 1),
           max(s.endotoxin_eu_per_ml)
    from dialysis_ro_water_samples_r3104 s
    group by s.aami_compliance_status
    order by sample_count desc;
end;
$$;
revoke execute on function founder_r3104_compliance_rollup() from public, anon;
grant execute on function founder_r3104_compliance_rollup() to authenticated;

-- =========================================================================
-- RPC 2: failing units by hospital (latest-sample basis)
-- =========================================================================
create or replace function founder_r3104_failing_units()
returns table (
  hospital_unit_name text,
  latest_status text,
  latest_endotoxin numeric,
  latest_cfu numeric,
  latest_sample_at timestamptz
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
    select distinct on (s.hospital_unit_name)
      s.hospital_unit_name,
      s.aami_compliance_status,
      s.endotoxin_eu_per_ml,
      s.bacterial_colony_cfu_per_ml,
      s.sample_collected_at
    from dialysis_ro_water_samples_r3104 s
    where s.aami_compliance_status in ('aami_failure','iso23500_failure','aami_action_level')
    order by s.hospital_unit_name, s.sample_collected_at desc;
end;
$$;
revoke execute on function founder_r3104_failing_units() from public, anon;
grant execute on function founder_r3104_failing_units() to authenticated;

-- =========================================================================
-- RPC 3: sample point breakdown (where do failures cluster?)
-- =========================================================================
create or replace function founder_r3104_sample_point_breakdown()
returns table (
  sample_point text,
  total_samples bigint,
  failures bigint,
  avg_chlorine_ppm numeric,
  avg_conductivity numeric
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
    select s.sample_point,
           count(*)::bigint,
           count(*) filter (where s.aami_compliance_status in ('aami_failure','iso23500_failure'))::bigint,
           round(avg(s.chlorine_ppm)::numeric, 3),
           round(avg(s.conductivity_us_cm)::numeric, 2)
    from dialysis_ro_water_samples_r3104 s
    group by s.sample_point
    order by failures desc, total_samples desc;
end;
$$;
revoke execute on function founder_r3104_sample_point_breakdown() from public, anon;
grant execute on function founder_r3104_sample_point_breakdown() to authenticated;

-- =========================================================================
-- RPC 4: purification action queue by priority/status
-- =========================================================================
create or replace function founder_r3104_action_queue()
returns table (
  priority text,
  status text,
  action_count bigint,
  total_cost_estimate_rupees numeric,
  total_actual_cost_rupees numeric
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
    select a.priority,
           a.status,
           count(*)::bigint,
           coalesce(sum(a.cost_estimate_rupees), 0),
           coalesce(sum(a.actual_cost_rupees), 0)
    from dialysis_ro_purification_actions_r3104 a
    group by a.priority, a.status
    order by a.priority, a.status;
end;
$$;
revoke execute on function founder_r3104_action_queue() from public, anon;
grant execute on function founder_r3104_action_queue() to authenticated;

-- =========================================================================
-- RPC 5: lab partner performance (which labs we use most)
-- =========================================================================
create or replace function founder_r3104_lab_partner_mix()
returns table (
  lab_partner text,
  samples_processed bigint,
  pass_rate_pct numeric,
  avg_endotoxin numeric
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
    select s.lab_partner,
           count(*)::bigint,
           round(100.0 * count(*) filter (where s.aami_compliance_status in ('aami_compliant','iso23500_compliant'))::numeric / nullif(count(*),0), 1),
           round(avg(s.endotoxin_eu_per_ml)::numeric, 3)
    from dialysis_ro_water_samples_r3104 s
    group by s.lab_partner
    order by samples_processed desc;
end;
$$;
revoke execute on function founder_r3104_lab_partner_mix() from public, anon;
grant execute on function founder_r3104_lab_partner_mix() to authenticated;

-- =========================================================================
-- RPC 6: action type cost rollup
-- =========================================================================
create or replace function founder_r3104_action_type_cost()
returns table (
  action_type text,
  action_count bigint,
  total_actual_cost_rupees numeric,
  avg_actual_cost_rupees numeric
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
    select a.action_type,
           count(*)::bigint,
           coalesce(sum(a.actual_cost_rupees), 0),
           coalesce(round(avg(a.actual_cost_rupees)::numeric, 2), 0)
    from dialysis_ro_purification_actions_r3104 a
    group by a.action_type
    order by total_actual_cost_rupees desc;
end;
$$;
revoke execute on function founder_r3104_action_type_cost() from public, anon;
grant execute on function founder_r3104_action_type_cost() to authenticated;

-- =========================================================================
-- RPC 7: p0 patient-safety queue (escalated to founder)
-- =========================================================================
create or replace function founder_r3104_p0_patient_safety()
returns table (
  hospital_unit_name text,
  action_type text,
  status text,
  target_completion_at timestamptz,
  cost_estimate_rupees numeric,
  resolution_notes text
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
    select s.hospital_unit_name,
           a.action_type,
           a.status,
           a.target_completion_at,
           a.cost_estimate_rupees,
           a.resolution_notes
    from dialysis_ro_purification_actions_r3104 a
    join dialysis_ro_water_samples_r3104 s on s.id = a.sample_id
    where a.priority = 'p0_patient_safety'
    order by a.target_completion_at asc;
end;
$$;
revoke execute on function founder_r3104_p0_patient_safety() from public, anon;
grant execute on function founder_r3104_p0_patient_safety() to authenticated;

-- =========================================================================
-- RPC 8: test method usage (which assay methods dominate)
-- =========================================================================
create or replace function founder_r3104_test_method_usage()
returns table (
  test_method text,
  sample_count bigint,
  failures bigint,
  avg_endotoxin numeric
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
    select s.test_method,
           count(*)::bigint,
           count(*) filter (where s.aami_compliance_status in ('aami_failure','iso23500_failure'))::bigint,
           round(avg(s.endotoxin_eu_per_ml)::numeric, 3)
    from dialysis_ro_water_samples_r3104 s
    group by s.test_method
    order by sample_count desc;
end;
$$;
revoke execute on function founder_r3104_test_method_usage() from public, anon;
grant execute on function founder_r3104_test_method_usage() to authenticated;

-- =========================================================================
-- RPC 9: vendor mix for purification actions
-- =========================================================================
create or replace function founder_r3104_vendor_mix()
returns table (
  vendor_required text,
  action_count bigint,
  total_cost_estimate_rupees numeric
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
    select coalesce(a.vendor_required, 'unassigned'),
           count(*)::bigint,
           coalesce(sum(a.cost_estimate_rupees), 0)
    from dialysis_ro_purification_actions_r3104 a
    group by a.vendor_required
    order by action_count desc;
end;
$$;
revoke execute on function founder_r3104_vendor_mix() from public, anon;
grant execute on function founder_r3104_vendor_mix() to authenticated;
