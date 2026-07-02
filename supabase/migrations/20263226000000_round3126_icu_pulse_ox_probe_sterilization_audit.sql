-- Round 3126 — ICU Pulse Oximeter Probe Cable Reuse Sterilization Cycle Compliance Audit
-- Quarterly audit of pulse-ox probe sterilization: probe sn x reuse count x sterilization method
-- x signal degradation x biological-load test x replace queue.

set search_path = public, pg_temp;

-- =============================================================================
-- TABLE 1: probe_sterilization_cycles_r3126
-- Per-probe sterilization cycle history with signal degradation + bioload result.
-- =============================================================================
create table if not exists public.probe_sterilization_cycles_r3126 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid not null references public.organizations(id) on delete cascade,
  probe_serial_number text not null,
  probe_manufacturer text not null,
  probe_model text not null,
  icu_ward text not null,
  bed_number text,
  cycle_number integer not null,
  cumulative_reuse_count integer not null,
  sterilization_method text not null,
  sterilization_started_at timestamptz not null,
  sterilization_completed_at timestamptz,
  cycle_operator_id uuid references public.profiles(id) on delete set null,
  signal_quality_index_percent numeric(5,2),
  signal_degradation_status text not null,
  biological_load_cfu_per_ml numeric(10,2),
  bioload_test_result text not null,
  compliance_status text not null,
  recorded_at timestamptz not null default now(),
  constraint probe_str_method_r3126_chk check (sterilization_method in (
    'ethylene_oxide','hydrogen_peroxide_plasma','glutaraldehyde_soak',
    'ortho_phthalaldehyde','uv_c_chamber','isopropyl_wipe'
  )),
  constraint probe_str_signal_r3126_chk check (signal_degradation_status in (
    'pristine','minor','moderate','severe','failed'
  )),
  constraint probe_str_bioload_r3126_chk check (bioload_test_result in (
    'pass_sterile','pass_low_burden','fail_high_burden','fail_contaminated','not_tested'
  )),
  constraint probe_str_compliance_r3126_chk check (compliance_status in (
    'compliant','minor_deviation','major_deviation','non_compliant'
  )),
  constraint probe_str_cycle_pos_r3126_chk check (cycle_number > 0 and cumulative_reuse_count >= 0)
);

create index if not exists idx_probe_str_org_r3126 on public.probe_sterilization_cycles_r3126(hospital_org_id);
create index if not exists idx_probe_str_serial_r3126 on public.probe_sterilization_cycles_r3126(probe_serial_number);
create index if not exists idx_probe_str_compliance_r3126 on public.probe_sterilization_cycles_r3126(compliance_status);

alter table public.probe_sterilization_cycles_r3126 enable row level security;

-- =============================================================================
-- TABLE 2: probe_replacement_queue_r3126
-- Replace queue for probes flagged degraded or non-compliant.
-- =============================================================================
create table if not exists public.probe_replacement_queue_r3126 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid not null references public.organizations(id) on delete cascade,
  probe_serial_number text not null,
  flagged_cycle_id uuid references public.probe_sterilization_cycles_r3126(id) on delete set null,
  flag_reason text not null,
  priority_tier text not null,
  replace_status text not null,
  replacement_cost_rupees numeric(10,2),
  flagged_at timestamptz not null default now(),
  scheduled_replacement_at timestamptz,
  completed_replacement_at timestamptz,
  replacement_engineer_id uuid references public.engineers(id) on delete set null,
  notes text,
  constraint probe_repl_reason_r3126_chk check (flag_reason in (
    'reuse_limit_exceeded','signal_severe_degradation','signal_failed',
    'bioload_high_burden','bioload_contaminated','method_non_compliant','cable_visible_damage'
  )),
  constraint probe_repl_tier_r3126_chk check (priority_tier in ('p0_immediate','p1_24h','p2_72h','p3_routine')),
  constraint probe_repl_status_r3126_chk check (replace_status in (
    'queued','engineer_assigned','part_ordered','in_progress','completed','cancelled'
  ))
);

create index if not exists idx_probe_repl_org_r3126 on public.probe_replacement_queue_r3126(hospital_org_id);
create index if not exists idx_probe_repl_status_r3126 on public.probe_replacement_queue_r3126(replace_status);
create index if not exists idx_probe_repl_tier_r3126 on public.probe_replacement_queue_r3126(priority_tier);

alter table public.probe_replacement_queue_r3126 enable row level security;

-- =============================================================================
-- SEED DATA
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
  v_cycle_a uuid;
  v_cycle_b uuid;
  v_cycle_c uuid;
  v_cycle_d uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  insert into public.probe_sterilization_cycles_r3126 (
    hospital_org_id, probe_serial_number, probe_manufacturer, probe_model,
    icu_ward, bed_number, cycle_number, cumulative_reuse_count,
    sterilization_method, sterilization_started_at, sterilization_completed_at,
    signal_quality_index_percent, signal_degradation_status,
    biological_load_cfu_per_ml, bioload_test_result, compliance_status, recorded_at
  ) values
  (v_org_id, 'MX-PO-2201-A', 'Masimo', 'LNCS Adt', 'ICU-1', 'B-12', 1, 1,
   'hydrogen_peroxide_plasma', '2026-04-02 08:00:00+05:30'::timestamptz, '2026-04-02 09:30:00+05:30'::timestamptz,
   98.50, 'pristine', 5.00, 'pass_sterile', 'compliant', '2026-04-02 10:00:00+05:30'::timestamptz),
  (v_org_id, 'MX-PO-2201-A', 'Masimo', 'LNCS Adt', 'ICU-1', 'B-12', 12, 12,
   'ethylene_oxide', '2026-05-15 06:00:00+05:30'::timestamptz, '2026-05-15 14:00:00+05:30'::timestamptz,
   91.20, 'minor', 22.40, 'pass_low_burden', 'compliant', '2026-05-15 15:00:00+05:30'::timestamptz),
  (v_org_id, 'MX-PO-2201-A', 'Masimo', 'LNCS Adt', 'ICU-1', 'B-12', 25, 25,
   'glutaraldehyde_soak', '2026-06-20 07:00:00+05:30'::timestamptz, '2026-06-20 08:00:00+05:30'::timestamptz,
   78.30, 'moderate', 88.10, 'pass_low_burden', 'minor_deviation', '2026-06-20 09:00:00+05:30'::timestamptz),
  (v_org_id, 'NK-PO-3308-B', 'Nellcor', 'MAX-A', 'ICU-2', 'C-04', 1, 1,
   'hydrogen_peroxide_plasma', '2026-04-05 08:00:00+05:30'::timestamptz, '2026-04-05 09:30:00+05:30'::timestamptz,
   99.10, 'pristine', 3.20, 'pass_sterile', 'compliant', '2026-04-05 10:00:00+05:30'::timestamptz),
  (v_org_id, 'NK-PO-3308-B', 'Nellcor', 'MAX-A', 'ICU-2', 'C-04', 18, 18,
   'isopropyl_wipe', '2026-05-22 11:00:00+05:30'::timestamptz, '2026-05-22 11:15:00+05:30'::timestamptz,
   65.40, 'severe', 412.80, 'fail_high_burden', 'major_deviation', '2026-05-22 12:00:00+05:30'::timestamptz),
  (v_org_id, 'NK-PO-3308-B', 'Nellcor', 'MAX-A', 'ICU-2', 'C-04', 22, 22,
   'ortho_phthalaldehyde', '2026-06-25 07:30:00+05:30'::timestamptz, '2026-06-25 08:30:00+05:30'::timestamptz,
   42.10, 'failed', 980.50, 'fail_contaminated', 'non_compliant', '2026-06-25 09:00:00+05:30'::timestamptz),
  (v_org_id, 'PH-PO-4412-C', 'Philips', 'M1191B', 'NICU-1', 'N-02', 5, 5,
   'uv_c_chamber', '2026-04-18 06:00:00+05:30'::timestamptz, '2026-04-18 06:45:00+05:30'::timestamptz,
   96.80, 'pristine', 7.10, 'pass_sterile', 'compliant', '2026-04-18 07:00:00+05:30'::timestamptz),
  (v_org_id, 'PH-PO-4412-C', 'Philips', 'M1191B', 'NICU-1', 'N-02', 14, 14,
   'hydrogen_peroxide_plasma', '2026-05-30 08:00:00+05:30'::timestamptz, '2026-05-30 09:30:00+05:30'::timestamptz,
   88.40, 'minor', 18.90, 'pass_low_burden', 'compliant', '2026-05-30 10:00:00+05:30'::timestamptz),
  (v_org_id, 'GE-PO-5523-D', 'GE Healthcare', 'TruSignal', 'CTICU', 'T-07', 8, 8,
   'ethylene_oxide', '2026-04-22 06:00:00+05:30'::timestamptz, '2026-04-22 14:00:00+05:30'::timestamptz,
   94.10, 'pristine', 9.80, 'pass_sterile', 'compliant', '2026-04-22 15:00:00+05:30'::timestamptz),
  (v_org_id, 'GE-PO-5523-D', 'GE Healthcare', 'TruSignal', 'CTICU', 'T-07', 20, 20,
   'glutaraldehyde_soak', '2026-06-12 07:00:00+05:30'::timestamptz, '2026-06-12 08:00:00+05:30'::timestamptz,
   71.20, 'moderate', 134.60, 'fail_high_burden', 'major_deviation', '2026-06-12 09:00:00+05:30'::timestamptz),
  (v_org_id, 'MX-PO-2208-E', 'Masimo', 'M-LNCS Neo', 'NICU-2', 'N-09', 3, 3,
   'uv_c_chamber', '2026-04-10 06:00:00+05:30'::timestamptz, '2026-04-10 06:45:00+05:30'::timestamptz,
   97.90, 'pristine', 4.40, 'pass_sterile', 'compliant', '2026-04-10 07:00:00+05:30'::timestamptz),
  (v_org_id, 'MX-PO-2208-E', 'Masimo', 'M-LNCS Neo', 'NICU-2', 'N-09', 16, 16,
   'isopropyl_wipe', '2026-06-18 10:00:00+05:30'::timestamptz, '2026-06-18 10:10:00+05:30'::timestamptz,
   58.70, 'severe', null::numeric, 'not_tested', 'non_compliant', '2026-06-18 11:00:00+05:30'::timestamptz),
  (v_org_id, 'NK-PO-3315-F', 'Nellcor', 'MAX-N', 'PICU', 'P-03', 11, 11,
   'hydrogen_peroxide_plasma', '2026-05-08 08:00:00+05:30'::timestamptz, '2026-05-08 09:30:00+05:30'::timestamptz,
   85.30, 'minor', 28.10, 'pass_low_burden', 'minor_deviation', '2026-05-08 10:00:00+05:30'::timestamptz);

  -- Re-select a few cycles to link into replacement queue.
  select id into v_cycle_a from public.probe_sterilization_cycles_r3126
   where probe_serial_number = 'NK-PO-3308-B' and compliance_status = 'non_compliant' limit 1;
  select id into v_cycle_b from public.probe_sterilization_cycles_r3126
   where probe_serial_number = 'GE-PO-5523-D' and compliance_status = 'major_deviation' limit 1;
  select id into v_cycle_c from public.probe_sterilization_cycles_r3126
   where probe_serial_number = 'MX-PO-2208-E' and compliance_status = 'non_compliant' limit 1;
  select id into v_cycle_d from public.probe_sterilization_cycles_r3126
   where probe_serial_number = 'MX-PO-2201-A' and compliance_status = 'minor_deviation' limit 1;

  insert into public.probe_replacement_queue_r3126 (
    hospital_org_id, probe_serial_number, flagged_cycle_id, flag_reason,
    priority_tier, replace_status, replacement_cost_rupees,
    flagged_at, scheduled_replacement_at, completed_replacement_at, notes
  ) values
  (v_org_id, 'NK-PO-3308-B', v_cycle_a, 'bioload_contaminated', 'p0_immediate', 'engineer_assigned', 8450.00,
   '2026-06-25 09:30:00+05:30'::timestamptz, '2026-06-26 09:00:00+05:30'::timestamptz, null::timestamptz,
   'Critical: failed contaminated bioload at cycle 22; ICU-2 bed C-04 swapped to backup.'),
  (v_org_id, 'GE-PO-5523-D', v_cycle_b, 'bioload_high_burden', 'p1_24h', 'part_ordered', 12200.00,
   '2026-06-12 09:30:00+05:30'::timestamptz, '2026-06-13 11:00:00+05:30'::timestamptz, null::timestamptz,
   'High CFU on cycle 20; TruSignal replacement OEM lead time 36h.'),
  (v_org_id, 'MX-PO-2208-E', v_cycle_c, 'signal_severe_degradation', 'p1_24h', 'queued', 7600.00,
   '2026-06-18 11:30:00+05:30'::timestamptz, null::timestamptz, null::timestamptz,
   'NICU-2 N-09 neonatal probe — SQI 58.7%; bioload not tested.'),
  (v_org_id, 'MX-PO-2201-A', v_cycle_d, 'reuse_limit_exceeded', 'p2_72h', 'completed', 6900.00,
   '2026-06-20 09:30:00+05:30'::timestamptz, '2026-06-22 10:00:00+05:30'::timestamptz, '2026-06-22 12:15:00+05:30'::timestamptz,
   'Reuse 25 exceeds Masimo LNCS Adt 20-cycle vendor cap; replaced.'),
  (v_org_id, 'NK-PO-3315-F', null::uuid, 'method_non_compliant', 'p3_routine', 'queued', 5400.00,
   '2026-05-08 10:30:00+05:30'::timestamptz, null::timestamptz, null::timestamptz,
   'PICU P-03 — minor deviation logged for documentation only.');
end
$seed$;

-- =============================================================================
-- RPC 1 — Compliance status rollup across all cycles.
-- =============================================================================
create or replace function public.r3126_compliance_status_rollup()
returns table (
  compliance_status text,
  cycle_count bigint,
  unique_probes bigint,
  avg_signal_quality numeric,
  avg_bioload_cfu numeric,
  share_of_cycles_percent numeric
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
  with totals as (
    select count(*)::numeric as t from public.probe_sterilization_cycles_r3126
  )
  select c.compliance_status,
         count(*)::bigint as cycle_count,
         count(distinct c.probe_serial_number)::bigint as unique_probes,
         round(avg(c.signal_quality_index_percent)::numeric, 2) as avg_signal_quality,
         round(avg(c.biological_load_cfu_per_ml)::numeric, 2) as avg_bioload_cfu,
         round((count(*)::numeric / nullif((select t from totals), 0)) * 100, 2) as share_of_cycles_percent
    from public.probe_sterilization_cycles_r3126 c
   group by c.compliance_status
   order by cycle_count desc;
end;
$$;

revoke execute on function public.r3126_compliance_status_rollup() from public, anon;
grant execute on function public.r3126_compliance_status_rollup() to authenticated;

-- =============================================================================
-- RPC 2 — Sterilization method effectiveness.
-- =============================================================================
create or replace function public.r3126_method_effectiveness()
returns table (
  sterilization_method text,
  cycle_count bigint,
  avg_signal_quality numeric,
  avg_bioload_cfu numeric,
  pass_sterile_count bigint,
  fail_count bigint,
  effectiveness_score numeric
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
  select c.sterilization_method,
         count(*)::bigint as cycle_count,
         round(avg(c.signal_quality_index_percent)::numeric, 2) as avg_signal_quality,
         round(avg(c.biological_load_cfu_per_ml)::numeric, 2) as avg_bioload_cfu,
         count(*) filter (where c.bioload_test_result = 'pass_sterile')::bigint as pass_sterile_count,
         count(*) filter (where c.bioload_test_result in ('fail_high_burden','fail_contaminated'))::bigint as fail_count,
         round(
           (count(*) filter (where c.bioload_test_result in ('pass_sterile','pass_low_burden'))::numeric
            / nullif(count(*)::numeric, 0)) * 100, 2
         ) as effectiveness_score
    from public.probe_sterilization_cycles_r3126 c
   group by c.sterilization_method
   order by effectiveness_score desc nulls last;
end;
$$;

revoke execute on function public.r3126_method_effectiveness() from public, anon;
grant execute on function public.r3126_method_effectiveness() to authenticated;

-- =============================================================================
-- RPC 3 — Per-probe reuse + degradation trajectory.
-- =============================================================================
create or replace function public.r3126_probe_reuse_trajectory()
returns table (
  probe_serial_number text,
  probe_manufacturer text,
  probe_model text,
  icu_ward text,
  cycle_count bigint,
  max_reuse_count integer,
  latest_signal_quality numeric,
  latest_degradation text,
  latest_compliance text
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
    select distinct on (c.probe_serial_number)
           c.probe_serial_number, c.probe_manufacturer, c.probe_model, c.icu_ward,
           c.signal_quality_index_percent, c.signal_degradation_status, c.compliance_status,
           c.cumulative_reuse_count, c.recorded_at
      from public.probe_sterilization_cycles_r3126 c
     order by c.probe_serial_number, c.recorded_at desc
  )
  select l.probe_serial_number,
         l.probe_manufacturer,
         l.probe_model,
         l.icu_ward,
         (select count(*)::bigint from public.probe_sterilization_cycles_r3126 cc
           where cc.probe_serial_number = l.probe_serial_number) as cycle_count,
         l.cumulative_reuse_count as max_reuse_count,
         round(l.signal_quality_index_percent::numeric, 2) as latest_signal_quality,
         l.signal_degradation_status as latest_degradation,
         l.compliance_status as latest_compliance
    from latest l
   order by l.cumulative_reuse_count desc;
end;
$$;

revoke execute on function public.r3126_probe_reuse_trajectory() from public, anon;
grant execute on function public.r3126_probe_reuse_trajectory() to authenticated;

-- =============================================================================
-- RPC 4 — Bioload test outcome distribution.
-- =============================================================================
create or replace function public.r3126_bioload_outcome_distribution()
returns table (
  bioload_test_result text,
  cycle_count bigint,
  avg_cfu numeric,
  max_cfu numeric,
  share_of_cycles_percent numeric
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
  with totals as (
    select count(*)::numeric as t from public.probe_sterilization_cycles_r3126
  )
  select c.bioload_test_result,
         count(*)::bigint as cycle_count,
         round(avg(c.biological_load_cfu_per_ml)::numeric, 2) as avg_cfu,
         round(max(c.biological_load_cfu_per_ml)::numeric, 2) as max_cfu,
         round((count(*)::numeric / nullif((select t from totals), 0)) * 100, 2) as share_of_cycles_percent
    from public.probe_sterilization_cycles_r3126 c
   group by c.bioload_test_result
   order by cycle_count desc;
end;
$$;

revoke execute on function public.r3126_bioload_outcome_distribution() from public, anon;
grant execute on function public.r3126_bioload_outcome_distribution() to authenticated;

-- =============================================================================
-- RPC 5 — ICU ward heatmap of deviations.
-- =============================================================================
create or replace function public.r3126_ward_deviation_heatmap()
returns table (
  icu_ward text,
  cycle_count bigint,
  unique_probes bigint,
  major_or_non_compliant bigint,
  deviation_rate_percent numeric
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
  select c.icu_ward,
         count(*)::bigint as cycle_count,
         count(distinct c.probe_serial_number)::bigint as unique_probes,
         count(*) filter (where c.compliance_status in ('major_deviation','non_compliant'))::bigint as major_or_non_compliant,
         round(
           (count(*) filter (where c.compliance_status in ('major_deviation','non_compliant'))::numeric
            / nullif(count(*)::numeric, 0)) * 100, 2
         ) as deviation_rate_percent
    from public.probe_sterilization_cycles_r3126 c
   group by c.icu_ward
   order by deviation_rate_percent desc;
end;
$$;

revoke execute on function public.r3126_ward_deviation_heatmap() from public, anon;
grant execute on function public.r3126_ward_deviation_heatmap() to authenticated;

-- =============================================================================
-- RPC 6 — Replacement queue by priority tier.
-- =============================================================================
create or replace function public.r3126_replacement_queue_by_tier()
returns table (
  priority_tier text,
  queue_count bigint,
  total_replacement_cost numeric,
  avg_replacement_cost numeric,
  open_count bigint,
  completed_count bigint
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
  select q.priority_tier,
         count(*)::bigint as queue_count,
         round(coalesce(sum(q.replacement_cost_rupees), 0)::numeric, 2) as total_replacement_cost,
         round(coalesce(avg(q.replacement_cost_rupees), 0)::numeric, 2) as avg_replacement_cost,
         count(*) filter (where q.replace_status in ('queued','engineer_assigned','part_ordered','in_progress'))::bigint as open_count,
         count(*) filter (where q.replace_status = 'completed')::bigint as completed_count
    from public.probe_replacement_queue_r3126 q
   group by q.priority_tier
   order by case q.priority_tier
              when 'p0_immediate' then 0
              when 'p1_24h' then 1
              when 'p2_72h' then 2
              when 'p3_routine' then 3
            end;
end;
$$;

revoke execute on function public.r3126_replacement_queue_by_tier() from public, anon;
grant execute on function public.r3126_replacement_queue_by_tier() to authenticated;

-- =============================================================================
-- RPC 7 — Flag reason breakdown.
-- =============================================================================
create or replace function public.r3126_flag_reason_breakdown()
returns table (
  flag_reason text,
  count bigint,
  total_cost numeric,
  share_percent numeric
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
  with totals as (
    select count(*)::numeric as t from public.probe_replacement_queue_r3126
  )
  select q.flag_reason,
         count(*)::bigint as count,
         round(coalesce(sum(q.replacement_cost_rupees), 0)::numeric, 2) as total_cost,
         round((count(*)::numeric / nullif((select t from totals), 0)) * 100, 2) as share_percent
    from public.probe_replacement_queue_r3126 q
   group by q.flag_reason
   order by count desc;
end;
$$;

revoke execute on function public.r3126_flag_reason_breakdown() from public, anon;
grant execute on function public.r3126_flag_reason_breakdown() to authenticated;

-- =============================================================================
-- RPC 8 — Manufacturer scorecard.
-- =============================================================================
create or replace function public.r3126_manufacturer_scorecard()
returns table (
  probe_manufacturer text,
  probe_count bigint,
  cycle_count bigint,
  avg_signal_quality numeric,
  avg_bioload_cfu numeric,
  deviation_rate_percent numeric
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
  select c.probe_manufacturer,
         count(distinct c.probe_serial_number)::bigint as probe_count,
         count(*)::bigint as cycle_count,
         round(avg(c.signal_quality_index_percent)::numeric, 2) as avg_signal_quality,
         round(avg(c.biological_load_cfu_per_ml)::numeric, 2) as avg_bioload_cfu,
         round(
           (count(*) filter (where c.compliance_status in ('major_deviation','non_compliant'))::numeric
            / nullif(count(*)::numeric, 0)) * 100, 2
         ) as deviation_rate_percent
    from public.probe_sterilization_cycles_r3126 c
   group by c.probe_manufacturer
   order by deviation_rate_percent desc nulls last;
end;
$$;

revoke execute on function public.r3126_manufacturer_scorecard() from public, anon;
grant execute on function public.r3126_manufacturer_scorecard() to authenticated;

-- =============================================================================
-- RPC 9 — Headline KPIs.
-- =============================================================================
create or replace function public.r3126_headline_kpis()
returns table (
  metric_name text,
  metric_value text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cycles bigint;
  v_probes bigint;
  v_noncompliant bigint;
  v_fail_bioload bigint;
  v_queue_open bigint;
  v_p0_open bigint;
  v_avg_sqi numeric;
  v_total_repl_cost numeric;
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  select count(*), count(distinct probe_serial_number)
    into v_cycles, v_probes
    from public.probe_sterilization_cycles_r3126;

  select count(*) filter (where compliance_status in ('major_deviation','non_compliant')),
         count(*) filter (where bioload_test_result in ('fail_high_burden','fail_contaminated')),
         round(avg(signal_quality_index_percent)::numeric, 2)
    into v_noncompliant, v_fail_bioload, v_avg_sqi
    from public.probe_sterilization_cycles_r3126;

  select count(*) filter (where replace_status in ('queued','engineer_assigned','part_ordered','in_progress')),
         count(*) filter (where priority_tier = 'p0_immediate'
                            and replace_status in ('queued','engineer_assigned','part_ordered','in_progress')),
         round(coalesce(sum(replacement_cost_rupees), 0)::numeric, 2)
    into v_queue_open, v_p0_open, v_total_repl_cost
    from public.probe_replacement_queue_r3126;

  return query
  select 'total_cycles_audited'::text, v_cycles::text
  union all select 'unique_probes_in_audit'::text, v_probes::text
  union all select 'cycles_major_or_non_compliant'::text, v_noncompliant::text
  union all select 'cycles_failed_bioload'::text, v_fail_bioload::text
  union all select 'avg_signal_quality_percent'::text, coalesce(v_avg_sqi::text, '0')
  union all select 'open_replace_queue_count'::text, v_queue_open::text
  union all select 'p0_immediate_open_count'::text, v_p0_open::text
  union all select 'total_replacement_cost_rupees'::text, coalesce(v_total_repl_cost::text, '0');
end;
$$;

revoke execute on function public.r3126_headline_kpis() from public, anon;
grant execute on function public.r3126_headline_kpis() to authenticated;