-- Round 3012: Customer Monthly Engineer Hospital Refrigerator Door Gasket Seal Integrity Tracker
-- Two tables track monthly seal integrity inspections + corrective actions on hospital refrigerators.

create table if not exists public.gasket_seal_inspections_r3012 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  hospital_name text not null,
  refrigerator_asset_tag text not null,
  refrigerator_zone text not null check (refrigerator_zone in ('pharmacy','lab','blood_bank','vaccine_cold_chain','kitchen','morgue')),
  engineer_user_id uuid,
  engineer_name text not null,
  inspection_month date not null,
  inspected_at timestamptz not null,
  dollar_bill_slip_test_grams int not null,
  vacuum_decay_pa_per_min numeric(10,2) not null,
  visual_crack_score int not null check (visual_crack_score between 0 and 10),
  mold_growth_level text not null check (mold_growth_level in ('none','spot','moderate','severe')),
  door_alignment_mm numeric(6,2) not null,
  ambient_temp_c numeric(5,2) not null,
  interior_temp_c numeric(5,2) not null,
  seal_age_months int not null,
  pass_fail text not null check (pass_fail in ('pass','fail','marginal')),
  visit_status text not null check (visit_status in ('completed','rescheduled','no_show','partial')),
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.gasket_corrective_actions_r3012 (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid references public.gasket_seal_inspections_r3012(id) on delete cascade,
  hospital_name text not null,
  refrigerator_asset_tag text not null,
  action_type text not null check (action_type in ('replace_gasket','clean_realign','tighten_hinge','full_door_swap','escalate_oem','monitor')),
  action_status text not null check (action_status in ('open','in_progress','completed','deferred','cancelled')),
  part_cost_rupees int not null,
  labor_cost_rupees int not null,
  scheduled_at timestamptz,
  completed_at timestamptz,
  downtime_hours numeric(6,2) not null,
  customer_billed boolean not null default false,
  warranty_covered boolean not null default false,
  follow_up_required boolean not null default true,
  priority text not null check (priority in ('p0','p1','p2','p3')),
  created_at timestamptz default now()
);

alter table public.gasket_seal_inspections_r3012 enable row level security;
alter table public.gasket_corrective_actions_r3012 enable row level security;

drop policy if exists gasket_seal_inspections_r3012_founder_read on public.gasket_seal_inspections_r3012;
create policy gasket_seal_inspections_r3012_founder_read on public.gasket_seal_inspections_r3012 for select to authenticated using (is_founder());

drop policy if exists gasket_corrective_actions_r3012_founder_read on public.gasket_corrective_actions_r3012;
create policy gasket_corrective_actions_r3012_founder_read on public.gasket_corrective_actions_r3012 for select to authenticated using (is_founder());

-- Seeds: gasket_seal_inspections_r3012 (18 rows)
insert into public.gasket_seal_inspections_r3012 (
  hospital_org_id, hospital_name, refrigerator_asset_tag, refrigerator_zone,
  engineer_user_id, engineer_name, inspection_month, inspected_at,
  dollar_bill_slip_test_grams, vacuum_decay_pa_per_min, visual_crack_score, mold_growth_level,
  door_alignment_mm, ambient_temp_c, interior_temp_c, seal_age_months, pass_fail, visit_status, notes
)
select null::uuid, 'Apollo Hyderabad', 'FRG-AH-001', 'pharmacy', null::uuid, 'Ravi Kumar',
  '2026-06-01'::date, '2026-06-03 09:15:00+05:30'::timestamptz, 45, 12.50, 1, 'none', 0.50, 24.5, 4.2, 8, 'pass', 'completed', 'Clean seal, minor dust'
union all select null, 'Yashoda Secunderabad', 'FRG-YS-014', 'blood_bank', null, 'Sneha Reddy', '2026-06-01', '2026-06-04 10:30:00+05:30', 95, 38.20, 4, 'spot', 1.20, 25.1, 3.8, 22, 'marginal', 'completed', 'Spot mold on bottom corner'
union all select null, 'KIMS Kondapur', 'FRG-KK-007', 'vaccine_cold_chain', null, 'Arjun Patil', '2026-06-01', '2026-06-05 14:00:00+05:30', 180, 95.40, 8, 'moderate', 3.50, 26.2, 6.1, 36, 'fail', 'completed', 'Gasket cracked, immediate replacement'
union all select null, 'NIMS Punjagutta', 'FRG-NP-022', 'lab', null, 'Priya Sharma', '2026-06-01', '2026-06-06 11:45:00+05:30', 60, 18.70, 2, 'none', 0.80, 23.8, 4.5, 12, 'pass', 'completed', null
union all select null, 'Care Banjara', 'FRG-CB-009', 'pharmacy', null, 'Vikram Singh', '2026-06-01', '2026-06-07 16:20:00+05:30', 110, 45.30, 5, 'spot', 1.80, 24.9, 5.2, 18, 'marginal', 'completed', 'Recommend monitoring'
union all select null, 'Sunshine Secunderabad', 'FRG-SS-031', 'kitchen', null, 'Ravi Kumar', '2026-06-01', '2026-06-08 08:50:00+05:30', 220, 110.80, 9, 'severe', 4.20, 27.5, 8.3, 42, 'fail', 'completed', 'Severe mold + tear'
union all select null, 'Continental Gachibowli', 'FRG-CG-005', 'blood_bank', null, 'Sneha Reddy', '2026-06-01', '2026-06-09 13:10:00+05:30', 50, 14.20, 1, 'none', 0.60, 24.2, 3.9, 6, 'pass', 'completed', null
union all select null, 'Olive Banjara', 'FRG-OB-012', 'vaccine_cold_chain', null, 'Arjun Patil', '2026-06-01', '2026-06-10 09:30:00+05:30', 75, 25.40, 3, 'spot', 1.10, 25.5, 4.7, 16, 'pass', 'completed', 'Acceptable for vaccine zone'
union all select null, 'Star Hospitals', 'FRG-SH-018', 'morgue', null, 'Priya Sharma', '2026-06-01', '2026-06-11 15:00:00+05:30', 140, 62.70, 6, 'moderate', 2.50, 22.8, 4.1, 28, 'marginal', 'rescheduled', 'Visit cut short - power outage'
union all select null, 'Rainbow Hyderguda', 'FRG-RH-003', 'pharmacy', null, 'Vikram Singh', '2026-06-01', '2026-06-12 10:15:00+05:30', 55, 16.80, 1, 'none', 0.70, 24.0, 4.0, 9, 'pass', 'completed', null
union all select null, 'Asian Institute', 'FRG-AI-025', 'lab', null, 'Ravi Kumar', '2026-06-01', '2026-06-13 12:40:00+05:30', 200, 105.20, 9, 'severe', 3.90, 26.8, 7.5, 40, 'fail', 'completed', 'Lab specimens at risk'
union all select null, 'AIG Hospitals', 'FRG-AG-011', 'pharmacy', null, 'Sneha Reddy', '2026-06-01', '2026-06-14 14:25:00+05:30', 80, 28.60, 3, 'spot', 1.30, 25.0, 4.8, 20, 'marginal', 'completed', null
union all select null, 'Pace Hospitals', 'FRG-PH-006', 'blood_bank', null, 'Arjun Patil', '2026-06-01', '2026-06-15 09:00:00+05:30', 48, 13.10, 1, 'none', 0.55, 24.3, 3.7, 5, 'pass', 'completed', 'Brand new gasket'
union all select null, 'Citizens Specialty', 'FRG-CS-019', 'kitchen', null, 'Priya Sharma', '2026-06-01', '2026-06-16 11:30:00+05:30', 165, 78.40, 7, 'moderate', 2.90, 28.1, 6.8, 32, 'fail', 'no_show', 'Site closed for fumigation'
union all select null, 'Medicover', 'FRG-MC-027', 'vaccine_cold_chain', null, 'Vikram Singh', '2026-06-01', '2026-06-17 13:50:00+05:30', 65, 21.30, 2, 'none', 0.95, 24.7, 4.3, 14, 'pass', 'completed', null
union all select null, 'Vinn Hospital', 'FRG-VH-004', 'lab', null, 'Ravi Kumar', '2026-06-01', '2026-06-18 15:40:00+05:30', 130, 58.90, 6, 'spot', 2.30, 25.8, 5.5, 26, 'marginal', 'partial', 'Door alignment check pending'
union all select null, 'Sunshine Begumpet', 'FRG-SB-016', 'morgue', null, 'Sneha Reddy', '2026-06-01', '2026-06-19 10:05:00+05:30', 240, 125.60, 10, 'severe', 4.80, 23.2, 9.1, 48, 'fail', 'completed', 'OEM door swap recommended'
union all select null, 'Renova Soujanya', 'FRG-RS-021', 'pharmacy', null, 'Arjun Patil', '2026-06-01', '2026-06-20 12:15:00+05:30', 70, 23.80, 2, 'spot', 1.05, 24.6, 4.4, 13, 'pass', 'completed', null;

-- Seeds: gasket_corrective_actions_r3012 (16 rows)
insert into public.gasket_corrective_actions_r3012 (
  inspection_id, hospital_name, refrigerator_asset_tag, action_type, action_status,
  part_cost_rupees, labor_cost_rupees, scheduled_at, completed_at, downtime_hours,
  customer_billed, warranty_covered, follow_up_required, priority
)
select null::uuid, 'KIMS Kondapur', 'FRG-KK-007', 'replace_gasket', 'completed', 4200, 1500,
  '2026-06-06 09:00:00+05:30'::timestamptz, '2026-06-06 11:30:00+05:30'::timestamptz, 2.5, true, false, true, 'p1'
union all select null, 'Sunshine Secunderabad', 'FRG-SS-031', 'full_door_swap', 'in_progress', 28500, 4500, '2026-06-12 08:00:00+05:30'::timestamptz, null::timestamptz, 8.0, true, false, true, 'p0'
union all select null, 'Continental Gachibowli', 'FRG-CG-005', 'monitor', 'open', 0, 0, '2026-07-09 10:00:00+05:30'::timestamptz, null, 0.0, false, false, true, 'p3'
union all select null, 'Star Hospitals', 'FRG-SH-018', 'clean_realign', 'deferred', 800, 1200, '2026-06-25 14:00:00+05:30'::timestamptz, null, 1.5, false, true, true, 'p2'
union all select null, 'Asian Institute', 'FRG-AI-025', 'replace_gasket', 'completed', 4500, 1600, '2026-06-14 09:00:00+05:30'::timestamptz, '2026-06-14 12:00:00+05:30'::timestamptz, 3.0, true, false, true, 'p1'
union all select null, 'AIG Hospitals', 'FRG-AG-011', 'clean_realign', 'completed', 600, 1000, '2026-06-15 11:00:00+05:30'::timestamptz, '2026-06-15 12:30:00+05:30'::timestamptz, 1.5, false, true, false, 'p2'
union all select null, 'Citizens Specialty', 'FRG-CS-019', 'escalate_oem', 'open', 0, 0, '2026-06-30 10:00:00+05:30'::timestamptz, null, 0.0, false, true, true, 'p1'
union all select null, 'Vinn Hospital', 'FRG-VH-004', 'tighten_hinge', 'completed', 250, 800, '2026-06-19 09:30:00+05:30'::timestamptz, '2026-06-19 10:15:00+05:30'::timestamptz, 0.75, false, true, false, 'p2'
union all select null, 'Sunshine Begumpet', 'FRG-SB-016', 'full_door_swap', 'open', 32000, 5000, '2026-06-28 08:00:00+05:30'::timestamptz, null, 10.0, true, false, true, 'p0'
union all select null, 'Yashoda Secunderabad', 'FRG-YS-014', 'replace_gasket', 'completed', 3800, 1400, '2026-06-05 09:00:00+05:30'::timestamptz, '2026-06-05 11:00:00+05:30'::timestamptz, 2.0, false, true, true, 'p1'
union all select null, 'Care Banjara', 'FRG-CB-009', 'monitor', 'open', 0, 0, '2026-07-07 10:00:00+05:30'::timestamptz, null, 0.0, false, false, true, 'p3'
union all select null, 'Olive Banjara', 'FRG-OB-012', 'monitor', 'completed', 0, 500, '2026-06-11 14:00:00+05:30'::timestamptz, '2026-06-11 14:30:00+05:30'::timestamptz, 0.5, false, true, false, 'p3'
union all select null, 'Rainbow Hyderguda', 'FRG-RH-003', 'monitor', 'completed', 0, 400, '2026-06-13 09:00:00+05:30'::timestamptz, '2026-06-13 09:20:00+05:30'::timestamptz, 0.33, false, true, false, 'p3'
union all select null, 'Apollo Hyderabad', 'FRG-AH-001', 'monitor', 'cancelled', 0, 0, null::timestamptz, null, 0.0, false, false, false, 'p3'
union all select null, 'Medicover', 'FRG-MC-027', 'monitor', 'open', 0, 0, '2026-07-18 11:00:00+05:30'::timestamptz, null, 0.0, false, false, true, 'p3'
union all select null, 'Renova Soujanya', 'FRG-RS-021', 'tighten_hinge', 'in_progress', 200, 700, '2026-06-22 10:00:00+05:30'::timestamptz, null, 1.0, false, true, true, 'p2';

-- RPC 1: hospital-level pass/fail summary
create or replace function public.gasket_r3012_hospital_summary()
returns table (hospital_name text, inspections int, pass_count int, fail_count int, marginal_count int, fail_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select g.hospital_name,
    count(*)::int as inspections,
    (count(*) filter (where g.pass_fail='pass'))::int as pass_count,
    (count(*) filter (where g.pass_fail='fail'))::int as fail_count,
    (count(*) filter (where g.pass_fail='marginal'))::int as marginal_count,
    round(100.0 * (count(*) filter (where g.pass_fail='fail'))::numeric / nullif(count(*),0), 1) as fail_rate_pct
  from public.gasket_seal_inspections_r3012 g
  group by g.hospital_name
  order by fail_count desc, inspections desc;
end $$;

-- RPC 2: zone-level seal health
create or replace function public.gasket_r3012_zone_health()
returns table (refrigerator_zone text, total int, avg_decay numeric, avg_crack numeric, severe_mold_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select g.refrigerator_zone,
    count(*)::int as total,
    round(avg(g.vacuum_decay_pa_per_min), 2) as avg_decay,
    round(avg(g.visual_crack_score), 2) as avg_crack,
    (count(*) filter (where g.mold_growth_level='severe'))::int as severe_mold_count
  from public.gasket_seal_inspections_r3012 g
  group by g.refrigerator_zone
  order by avg_decay desc;
end $$;

-- RPC 3: engineer scorecard
create or replace function public.gasket_r3012_engineer_scorecard()
returns table (engineer_name text, visits int, completed int, no_shows int, rescheduled int, completion_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select g.engineer_name,
    count(*)::int as visits,
    (count(*) filter (where g.visit_status='completed'))::int as completed,
    (count(*) filter (where g.visit_status='no_show'))::int as no_shows,
    (count(*) filter (where g.visit_status='rescheduled'))::int as rescheduled,
    round(100.0 * (count(*) filter (where g.visit_status='completed'))::numeric / nullif(count(*),0), 1) as completion_rate_pct
  from public.gasket_seal_inspections_r3012 g
  group by g.engineer_name
  order by visits desc;
end $$;

-- RPC 4: corrective action cost rollup
create or replace function public.gasket_r3012_action_cost_rollup()
returns table (action_type text, action_count int, total_part_cost int, total_labor_cost int, total_downtime_hours numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select a.action_type,
    count(*)::int as action_count,
    coalesce(sum(a.part_cost_rupees),0)::int as total_part_cost,
    coalesce(sum(a.labor_cost_rupees),0)::int as total_labor_cost,
    coalesce(round(sum(a.downtime_hours),2),0) as total_downtime_hours
  from public.gasket_corrective_actions_r3012 a
  group by a.action_type
  order by total_part_cost desc;
end $$;

-- RPC 5: open priority queue
create or replace function public.gasket_r3012_open_priority_queue()
returns table (hospital_name text, refrigerator_asset_tag text, action_type text, priority text, scheduled_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select a.hospital_name, a.refrigerator_asset_tag, a.action_type, a.priority, a.scheduled_at
  from public.gasket_corrective_actions_r3012 a
  where a.action_status in ('open','in_progress')
  order by case a.priority when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 else 3 end, a.scheduled_at nulls last;
end $$;

-- RPC 6: failed inspections detail
create or replace function public.gasket_r3012_failed_inspections()
returns table (hospital_name text, refrigerator_asset_tag text, refrigerator_zone text, inspected_at timestamptz, vacuum_decay_pa_per_min numeric, mold_growth_level text, seal_age_months int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select g.hospital_name, g.refrigerator_asset_tag, g.refrigerator_zone, g.inspected_at, g.vacuum_decay_pa_per_min, g.mold_growth_level, g.seal_age_months
  from public.gasket_seal_inspections_r3012 g
  where g.pass_fail='fail'
  order by g.vacuum_decay_pa_per_min desc;
end $$;

-- RPC 7: warranty vs billed split
create or replace function public.gasket_r3012_warranty_split()
returns table (billing_path text, action_count int, total_cost int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select case when a.warranty_covered then 'warranty' when a.customer_billed then 'customer_billed' else 'absorbed' end as billing_path,
    count(*)::int as action_count,
    coalesce(sum(a.part_cost_rupees + a.labor_cost_rupees),0)::int as total_cost
  from public.gasket_corrective_actions_r3012 a
  group by 1
  order by total_cost desc;
end $$;

-- RPC 8: seal aging bucket
create or replace function public.gasket_r3012_seal_aging_buckets()
returns table (age_bucket text, inspections int, fail_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select case
      when g.seal_age_months < 12 then '0-12m'
      when g.seal_age_months < 24 then '12-24m'
      when g.seal_age_months < 36 then '24-36m'
      else '36m+'
    end as age_bucket,
    count(*)::int as inspections,
    (count(*) filter (where g.pass_fail='fail'))::int as fail_count
  from public.gasket_seal_inspections_r3012 g
  group by 1
  order by 1;
end $$;

revoke all on function public.gasket_r3012_hospital_summary() from public, anon;
revoke all on function public.gasket_r3012_zone_health() from public, anon;
revoke all on function public.gasket_r3012_engineer_scorecard() from public, anon;
revoke all on function public.gasket_r3012_action_cost_rollup() from public, anon;
revoke all on function public.gasket_r3012_open_priority_queue() from public, anon;
revoke all on function public.gasket_r3012_failed_inspections() from public, anon;
revoke all on function public.gasket_r3012_warranty_split() from public, anon;
revoke all on function public.gasket_r3012_seal_aging_buckets() from public, anon;

grant execute on function public.gasket_r3012_hospital_summary() to authenticated;
grant execute on function public.gasket_r3012_zone_health() to authenticated;
grant execute on function public.gasket_r3012_engineer_scorecard() to authenticated;
grant execute on function public.gasket_r3012_action_cost_rollup() to authenticated;
grant execute on function public.gasket_r3012_open_priority_queue() to authenticated;
grant execute on function public.gasket_r3012_failed_inspections() to authenticated;
grant execute on function public.gasket_r3012_warranty_split() to authenticated;
grant execute on function public.gasket_r3012_seal_aging_buckets() to authenticated;
