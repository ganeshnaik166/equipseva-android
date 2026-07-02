-- Round 3009: Founder Quarterly Strategic Engineering Bench-Strength Cross-Coverage Risk Audit
-- HEAVY: 2 tables + 7 RPCs + seed data

-- =========================================================
-- TABLE 1: engineer_bench_strength_r3009
-- =========================================================
create table if not exists public.engineer_bench_strength_r3009 (
  id uuid primary key default gen_random_uuid(),
  engineer_name text not null,
  primary_skill text not null,
  region text not null check (region in ('north','south','east','west','central')),
  tier text not null check (tier in ('t1','t2','t3','t4','t5')),
  certifications_count int not null default 0,
  backup_engineers_count int not null default 0,
  active_amc_load int not null default 0,
  utilization_pct numeric(5,2) not null default 0,
  attrition_risk text not null check (attrition_risk in ('low','medium','high','critical')),
  cross_coverage_score numeric(5,2) not null default 0,
  single_point_of_failure boolean not null default false,
  bench_status text not null check (bench_status in ('strong','adequate','thin','critical_gap')),
  notes text,
  audit_quarter text not null check (audit_quarter in ('q1_2026','q2_2026','q3_2026','q4_2026')),
  created_at timestamptz not null default now()
);

alter table public.engineer_bench_strength_r3009 enable row level security;
drop policy if exists founder_read_eb_r3009 on public.engineer_bench_strength_r3009;
create policy founder_read_eb_r3009 on public.engineer_bench_strength_r3009
  for select using (is_founder());

-- =========================================================
-- TABLE 2: coverage_risk_findings_r3009
-- =========================================================
create table if not exists public.coverage_risk_findings_r3009 (
  id uuid primary key default gen_random_uuid(),
  finding_title text not null,
  region text not null check (region in ('north','south','east','west','central')),
  skill_gap text not null,
  affected_amc_count int not null default 0,
  affected_revenue_rupees bigint not null default 0,
  severity text not null check (severity in ('p0','p1','p2','p3')),
  status text not null check (status in ('open','in_review','mitigation_planned','resolved','accepted')),
  recommended_action text not null,
  target_close_date date,
  owner text not null,
  audit_quarter text not null check (audit_quarter in ('q1_2026','q2_2026','q3_2026','q4_2026')),
  created_at timestamptz not null default now()
);

alter table public.coverage_risk_findings_r3009 enable row level security;
drop policy if exists founder_read_crf_r3009 on public.coverage_risk_findings_r3009;
create policy founder_read_crf_r3009 on public.coverage_risk_findings_r3009
  for select using (is_founder());

-- =========================================================
-- SEED: engineer_bench_strength_r3009 (18 rows)
-- =========================================================
insert into public.engineer_bench_strength_r3009
  (engineer_name, primary_skill, region, tier, certifications_count, backup_engineers_count, active_amc_load, utilization_pct, attrition_risk, cross_coverage_score, single_point_of_failure, bench_status, notes, audit_quarter)
values
  ('Rajesh K', 'MRI Service', 'south', 't1', 7, 2, 14, 87.5, 'low', 78.0, false, 'strong', 'Senior MRI lead, mentor pool', 'q2_2026'),
  ('Priya S', 'CT Scanner', 'south', 't2', 5, 1, 12, 92.0, 'medium', 55.0, false, 'adequate', 'Single backup, watch attrition', 'q2_2026'),
  ('Anil V', 'Ultrasound', 'west', 't3', 4, 3, 18, 75.5, 'low', 82.0, false, 'strong', 'Deep bench in Mumbai region', 'q2_2026'),
  ('Sneha M', 'Dialysis', 'north', 't2', 6, 0, 9, 95.0, 'high', 22.0, true, 'critical_gap', 'SPOF for Delhi dialysis fleet', 'q2_2026'),
  ('Vikram J', 'Ventilator', 'central', 't1', 8, 2, 11, 80.0, 'low', 71.0, false, 'strong', 'Cross-trained on 3 vendors', 'q2_2026'),
  ('Deepa R', 'X-Ray', 'east', 't4', 3, 4, 22, 68.0, 'low', 88.0, false, 'strong', 'Strongest bench in east', 'q2_2026'),
  ('Suresh B', 'Cath Lab', 'south', 't1', 9, 1, 8, 88.0, 'critical', 18.0, true, 'critical_gap', 'Resignation rumor, no backup', 'q2_2026'),
  ('Meera T', 'Endoscopy', 'west', 't3', 5, 2, 15, 78.0, 'medium', 64.0, false, 'adequate', 'Bench thin in Pune', 'q2_2026'),
  ('Arjun P', 'Anesthesia', 'north', 't2', 6, 1, 13, 85.0, 'medium', 48.0, false, 'thin', 'Need 1 more backup', 'q2_2026'),
  ('Kavya N', 'Patient Monitor', 'south', 't4', 4, 5, 20, 72.0, 'low', 91.0, false, 'strong', 'Excellent cross-coverage', 'q2_2026'),
  ('Ravi D', 'Infusion Pump', 'central', 't5', 3, 6, 25, 65.0, 'low', 94.0, false, 'strong', 'Commodity skill, deep pool', 'q2_2026'),
  ('Lakshmi G', 'Laboratory', 'east', 't2', 5, 0, 10, 90.0, 'high', 25.0, true, 'critical_gap', 'Only certified lab tech in east', 'q2_2026'),
  ('Mohan I', 'Sterilizer', 'west', 't3', 4, 2, 16, 76.0, 'low', 68.0, false, 'adequate', 'Adequate for now', 'q2_2026'),
  ('Pooja H', 'Defibrillator', 'north', 't2', 6, 1, 11, 82.0, 'medium', 52.0, false, 'thin', 'Backup is junior', 'q2_2026'),
  ('Sanjay W', 'OT Lights', 'central', 't4', 3, 4, 19, 70.0, 'low', 86.0, false, 'strong', 'Stable bench', 'q2_2026'),
  ('Nisha L', 'PACS/Imaging IT', 'south', 't1', 8, 0, 7, 93.0, 'critical', 15.0, true, 'critical_gap', 'CRITICAL SPOF — IT skill', 'q2_2026'),
  ('Karthik O', 'Centrifuge', 'east', 't5', 3, 5, 23, 67.0, 'low', 89.0, false, 'strong', 'Strong bench', 'q2_2026'),
  ('Geetha U', 'ECG/Holter', 'west', 't3', 5, 3, 17, 74.0, 'low', 79.0, false, 'strong', 'Well covered', 'q2_2026');

-- =========================================================
-- SEED: coverage_risk_findings_r3009 (15 rows)
-- =========================================================
insert into public.coverage_risk_findings_r3009
  (finding_title, region, skill_gap, affected_amc_count, affected_revenue_rupees, severity, status, recommended_action, target_close_date, owner, audit_quarter)
values
  ('Dialysis SPOF in north', 'north', 'Dialysis machine service', 9, 1800000, 'p0', 'open', 'Hire 2 dialysis engineers within 30 days', '2026-07-30'::date, 'Head of Ops', 'q2_2026'),
  ('Cath Lab attrition risk south', 'south', 'Cardiac cath lab service', 8, 4400000, 'p0', 'in_review', 'Retention bonus + immediate cross-train', '2026-07-15'::date, 'CEO', 'q2_2026'),
  ('Lab tech zero backup east', 'east', 'Laboratory diagnostics', 10, 2100000, 'p0', 'mitigation_planned', 'Recruit 1 senior + 1 junior lab tech', '2026-08-10'::date, 'Regional Head East', 'q2_2026'),
  ('PACS IT critical SPOF', 'south', 'Imaging IT/PACS admin', 7, 3200000, 'p0', 'open', 'Hire PACS engineer + document SOPs', '2026-07-22'::date, 'CTO', 'q2_2026'),
  ('Endoscopy bench thin west', 'west', 'Endoscope reprocessing', 15, 1500000, 'p1', 'in_review', 'Cross-train 2 ultrasound engineers', '2026-08-20'::date, 'Regional Head West', 'q2_2026'),
  ('Anesthesia coverage thin north', 'north', 'Anesthesia machines', 13, 1700000, 'p1', 'mitigation_planned', 'Promote senior junior to T2', '2026-08-05'::date, 'L&D Lead', 'q2_2026'),
  ('Defibrillator backup junior', 'north', 'Defib & AED service', 11, 880000, 'p1', 'open', 'Pair with senior for 60 days', '2026-09-01'::date, 'Regional Head North', 'q2_2026'),
  ('Sterilizer adequate but no surplus', 'west', 'Autoclave service', 16, 960000, 'p2', 'accepted', 'Monitor quarterly', '2026-09-30'::date, 'Regional Head West', 'q2_2026'),
  ('CT scanner single backup', 'south', 'CT scanner service', 12, 2880000, 'p1', 'in_review', 'Recruit 1 T2 CT engineer', '2026-08-15'::date, 'Regional Head South', 'q2_2026'),
  ('Ventilator cross-vendor gap', 'central', 'Multi-vendor ventilator', 11, 1320000, 'p2', 'mitigation_planned', 'Vendor cert training program', '2026-09-15'::date, 'L&D Lead', 'q2_2026'),
  ('X-ray bench strong — no action', 'east', 'X-Ray service', 22, 1760000, 'p3', 'resolved', 'No action needed', '2026-06-30'::date, 'Regional Head East', 'q2_2026'),
  ('Infusion pump commodity coverage', 'central', 'Infusion pump service', 25, 1250000, 'p3', 'resolved', 'No action needed', '2026-06-30'::date, 'Regional Head Central', 'q2_2026'),
  ('Patient monitor bench strong', 'south', 'Patient monitor service', 20, 1400000, 'p3', 'resolved', 'Maintain current state', '2026-06-30'::date, 'Regional Head South', 'q2_2026'),
  ('OT lights stable', 'central', 'OT light service', 19, 950000, 'p3', 'accepted', 'No action — accept low risk', '2026-09-30'::date, 'Regional Head Central', 'q2_2026'),
  ('Ultrasound deep bench west', 'west', 'Ultrasound service', 18, 1620000, 'p3', 'resolved', 'No action', '2026-06-30'::date, 'Regional Head West', 'q2_2026');

-- =========================================================
-- RPC 1: bench summary
-- =========================================================
create or replace function public.fn_r3009_bench_summary()
returns table(
  total_engineers int,
  spof_count int,
  critical_gaps int,
  strong_bench int,
  high_attrition_risk int,
  avg_utilization numeric,
  avg_cross_coverage numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where single_point_of_failure))::int,
    (count(*) filter (where bench_status = 'critical_gap'))::int,
    (count(*) filter (where bench_status = 'strong'))::int,
    (count(*) filter (where attrition_risk in ('high','critical')))::int,
    round(avg(utilization_pct), 2),
    round(avg(cross_coverage_score), 2)
  from public.engineer_bench_strength_r3009;
end;
$$;

revoke all on function public.fn_r3009_bench_summary() from public, anon;
grant execute on function public.fn_r3009_bench_summary() to authenticated;

-- =========================================================
-- RPC 2: bench by region
-- =========================================================
create or replace function public.fn_r3009_bench_by_region()
returns table(
  region text,
  engineer_count int,
  spof_count int,
  avg_utilization numeric,
  avg_cross_coverage numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    b.region,
    count(*)::int,
    (count(*) filter (where b.single_point_of_failure))::int,
    round(avg(b.utilization_pct), 2),
    round(avg(b.cross_coverage_score), 2)
  from public.engineer_bench_strength_r3009 b
  group by b.region
  order by b.region;
end;
$$;

revoke all on function public.fn_r3009_bench_by_region() from public, anon;
grant execute on function public.fn_r3009_bench_by_region() to authenticated;

-- =========================================================
-- RPC 3: critical engineers (SPOFs)
-- =========================================================
create or replace function public.fn_r3009_critical_engineers()
returns table(
  engineer_name text,
  primary_skill text,
  region text,
  tier text,
  attrition_risk text,
  active_amc_load int,
  bench_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.engineer_name, b.primary_skill, b.region, b.tier, b.attrition_risk, b.active_amc_load, b.bench_status, b.notes
  from public.engineer_bench_strength_r3009 b
  where b.single_point_of_failure = true or b.bench_status = 'critical_gap'
  order by
    case b.attrition_risk when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end,
    b.active_amc_load desc;
end;
$$;

revoke all on function public.fn_r3009_critical_engineers() from public, anon;
grant execute on function public.fn_r3009_critical_engineers() to authenticated;

-- =========================================================
-- RPC 4: findings summary
-- =========================================================
create or replace function public.fn_r3009_findings_summary()
returns table(
  total_findings int,
  p0_count int,
  p1_count int,
  open_count int,
  resolved_count int,
  total_revenue_at_risk bigint,
  total_amcs_affected int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where severity = 'p0'))::int,
    (count(*) filter (where severity = 'p1'))::int,
    (count(*) filter (where status = 'open'))::int,
    (count(*) filter (where status = 'resolved'))::int,
    coalesce(sum(affected_revenue_rupees), 0)::bigint,
    coalesce(sum(affected_amc_count), 0)::int
  from public.coverage_risk_findings_r3009;
end;
$$;

revoke all on function public.fn_r3009_findings_summary() from public, anon;
grant execute on function public.fn_r3009_findings_summary() to authenticated;

-- =========================================================
-- RPC 5: open p0/p1 findings
-- =========================================================
create or replace function public.fn_r3009_urgent_findings()
returns table(
  finding_title text,
  region text,
  skill_gap text,
  severity text,
  status text,
  affected_amc_count int,
  affected_revenue_rupees bigint,
  target_close_date date,
  owner text,
  recommended_action text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_title, f.region, f.skill_gap, f.severity, f.status,
         f.affected_amc_count, f.affected_revenue_rupees, f.target_close_date, f.owner, f.recommended_action
  from public.coverage_risk_findings_r3009 f
  where f.severity in ('p0','p1') and f.status not in ('resolved','accepted')
  order by
    case f.severity when 'p0' then 1 when 'p1' then 2 else 3 end,
    f.affected_revenue_rupees desc;
end;
$$;

revoke all on function public.fn_r3009_urgent_findings() from public, anon;
grant execute on function public.fn_r3009_urgent_findings() to authenticated;

-- =========================================================
-- RPC 6: findings by region
-- =========================================================
create or replace function public.fn_r3009_findings_by_region()
returns table(
  region text,
  finding_count int,
  p0_count int,
  open_count int,
  revenue_at_risk bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.region,
    count(*)::int,
    (count(*) filter (where f.severity = 'p0'))::int,
    (count(*) filter (where f.status = 'open'))::int,
    coalesce(sum(f.affected_revenue_rupees), 0)::bigint
  from public.coverage_risk_findings_r3009 f
  group by f.region
  order by revenue_at_risk desc;
end;
$$;

revoke all on function public.fn_r3009_findings_by_region() from public, anon;
grant execute on function public.fn_r3009_findings_by_region() to authenticated;

-- =========================================================
-- RPC 7: top skill gaps by revenue
-- =========================================================
create or replace function public.fn_r3009_top_skill_gaps()
returns table(
  skill_gap text,
  finding_count int,
  total_amc_affected int,
  total_revenue_at_risk bigint,
  worst_severity text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.skill_gap,
    count(*)::int,
    sum(f.affected_amc_count)::int,
    sum(f.affected_revenue_rupees)::bigint,
    min(f.severity)
  from public.coverage_risk_findings_r3009 f
  group by f.skill_gap
  order by total_revenue_at_risk desc
  limit 10;
end;
$$;

revoke all on function public.fn_r3009_top_skill_gaps() from public, anon;
grant execute on function public.fn_r3009_top_skill_gaps() to authenticated;

-- =========================================================
-- RPC 8: attrition risk roster
-- =========================================================
create or replace function public.fn_r3009_attrition_roster()
returns table(
  engineer_name text,
  primary_skill text,
  region text,
  tier text,
  attrition_risk text,
  backup_engineers_count int,
  active_amc_load int,
  cross_coverage_score numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.engineer_name, b.primary_skill, b.region, b.tier, b.attrition_risk,
         b.backup_engineers_count, b.active_amc_load, b.cross_coverage_score
  from public.engineer_bench_strength_r3009 b
  where b.attrition_risk in ('medium','high','critical')
  order by
    case b.attrition_risk when 'critical' then 1 when 'high' then 2 else 3 end,
    b.active_amc_load desc;
end;
$$;

revoke all on function public.fn_r3009_attrition_roster() from public, anon;
grant execute on function public.fn_r3009_attrition_roster() to authenticated;
