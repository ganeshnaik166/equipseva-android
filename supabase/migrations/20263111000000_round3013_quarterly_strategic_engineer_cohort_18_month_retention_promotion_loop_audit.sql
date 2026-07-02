-- Round 3013: Founder Quarterly Strategic Engineer-Cohort 18-Month Retention & Promotion Loop Audit
-- Two _r3013 tables + 7 founder-gated RPCs

create table if not exists engineer_cohort_retention_loop_audit_r3013 (
  id uuid primary key default gen_random_uuid(),
  cohort_label text not null,
  cohort_start_date date not null,
  cohort_size_engineers int not null check (cohort_size_engineers >= 0),
  months_since_join int not null check (months_since_join between 0 and 24),
  active_engineers int not null check (active_engineers >= 0),
  churned_engineers int not null check (churned_engineers >= 0),
  promoted_tier_count int not null check (promoted_tier_count >= 0),
  retention_pct numeric(5,2) not null check (retention_pct between 0 and 100),
  promotion_pct numeric(5,2) not null check (promotion_pct between 0 and 100),
  avg_monthly_payout_rupees numeric(12,2) not null check (avg_monthly_payout_rupees >= 0),
  loop_health text not null check (loop_health in ('strong','steady','soft','weak','critical')),
  audit_status text not null check (audit_status in ('pending','in_review','signed_off','escalated','blocked')),
  founder_notes text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists engineer_cohort_promotion_loop_decisions_r3013 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references engineer_cohort_retention_loop_audit_r3013(id) on delete cascade,
  decision_label text not null,
  decision_type text not null check (decision_type in ('promote','retain','coach','warn','offboard','reassign')),
  target_tier text not null check (target_tier in ('tier1','tier2','tier3','tier4','tier5')),
  budget_rupees numeric(12,2) not null check (budget_rupees >= 0),
  expected_retention_lift_pct numeric(5,2) not null check (expected_retention_lift_pct between 0 and 100),
  priority text not null check (priority in ('p0','p1','p2','p3')),
  decision_status text not null check (decision_status in ('drafted','approved','executed','deferred','rejected')),
  owner_role text not null check (owner_role in ('founder','ops_lead','engineer_manager','finance','people_ops')),
  due_date date,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table engineer_cohort_retention_loop_audit_r3013 enable row level security;
alter table engineer_cohort_promotion_loop_decisions_r3013 enable row level security;

drop policy if exists founder_read_eca_r3013 on engineer_cohort_retention_loop_audit_r3013;
create policy founder_read_eca_r3013 on engineer_cohort_retention_loop_audit_r3013
  for select using (is_founder());

drop policy if exists founder_read_ecd_r3013 on engineer_cohort_promotion_loop_decisions_r3013;
create policy founder_read_ecd_r3013 on engineer_cohort_promotion_loop_decisions_r3013
  for select using (is_founder());

-- Seed 18 retention audit rows
insert into engineer_cohort_retention_loop_audit_r3013
  (cohort_label, cohort_start_date, cohort_size_engineers, months_since_join, active_engineers, churned_engineers, promoted_tier_count, retention_pct, promotion_pct, avg_monthly_payout_rupees, loop_health, audit_status, founder_notes, reviewed_at)
select * from (values
  ('Q1-2025 Hyderabad',    '2025-01-15'::date, 24, 18, 21, 3, 11, 87.50, 45.83, 38500.00, 'strong',   'signed_off',  'flagship cohort, lift via referral bonus', '2026-06-10T09:00:00Z'::timestamptz),
  ('Q1-2025 Bangalore',    '2025-01-20'::date, 20, 18, 16, 4, 7,  80.00, 35.00, 36200.00, 'steady',   'signed_off',  'two coaching saves applied',                '2026-06-10T09:30:00Z'::timestamptz),
  ('Q2-2025 Chennai',      '2025-04-10'::date, 18, 15, 14, 4, 6,  77.77, 33.33, 34000.00, 'steady',   'in_review',   'mid-cohort dip month 9',                    null::timestamptz),
  ('Q2-2025 Pune',         '2025-04-22'::date, 16, 15, 12, 4, 4,  75.00, 25.00, 32100.00, 'soft',     'in_review',   'tier2 stuck — coach plan needed',           null::timestamptz),
  ('Q3-2025 Hyderabad',    '2025-07-12'::date, 26, 12, 23, 3, 9,  88.46, 34.61, 35800.00, 'strong',   'signed_off',  'best onboarding NPS to date',               '2026-06-12T10:15:00Z'::timestamptz),
  ('Q3-2025 Bangalore',    '2025-07-18'::date, 22, 12, 17, 5, 5,  77.27, 22.72, 33000.00, 'soft',     'escalated',   'churn driver = AMC route shortage',         '2026-06-12T10:45:00Z'::timestamptz),
  ('Q3-2025 Mumbai',       '2025-07-25'::date, 14, 12, 12, 2, 4,  85.71, 28.57, 37200.00, 'steady',   'signed_off',  'mumbai trial cohort holding',               '2026-06-12T11:00:00Z'::timestamptz),
  ('Q4-2025 Hyderabad',    '2025-10-05'::date, 28, 9,  25, 3, 8,  89.28, 28.57, 34500.00, 'strong',   'in_review',   'on track for 18m benchmark',                null::timestamptz),
  ('Q4-2025 Bangalore',    '2025-10-11'::date, 24, 9,  19, 5, 4,  79.16, 16.66, 31900.00, 'soft',     'in_review',   'promotion lag visible',                     null::timestamptz),
  ('Q4-2025 Chennai',      '2025-10-19'::date, 18, 9,  15, 3, 3,  83.33, 16.66, 32400.00, 'steady',   'pending',     'awaiting Q3 review',                        null::timestamptz),
  ('Q1-2026 Hyderabad',    '2026-01-08'::date, 30, 6,  28, 2, 5,  93.33, 16.66, 30200.00, 'strong',   'pending',     'early signal — promote leaders fast',       null::timestamptz),
  ('Q1-2026 Bangalore',    '2026-01-15'::date, 26, 6,  22, 4, 3,  84.61, 11.53, 28700.00, 'steady',   'pending',     'comparison vs 2025 cohort tracking',        null::timestamptz),
  ('Q1-2026 Chennai',      '2026-01-22'::date, 20, 6,  17, 3, 2,  85.00, 10.00, 29100.00, 'steady',   'pending',     'normal early ramp',                         null::timestamptz),
  ('Q1-2026 Pune',         '2026-01-29'::date, 16, 6,  14, 2, 2,  87.50, 12.50, 30500.00, 'steady',   'pending',     'pune recovery cohort',                      null::timestamptz),
  ('Q1-2026 Mumbai',       '2026-02-03'::date, 18, 5,  16, 2, 2,  88.88, 11.11, 31100.00, 'strong',   'pending',     'momentum from Q3 mumbai',                   null::timestamptz),
  ('Pilot SL-Colombo',     '2025-11-04'::date, 8,  8,  6,  2, 1,  75.00, 12.50, 22000.00, 'soft',     'escalated',   'small N, currency exposure',                '2026-06-11T14:00:00Z'::timestamptz),
  ('Pilot BD-Dhaka',       '2025-12-01'::date, 6,  7,  4,  2, 0,  66.66, 0.00,  19500.00, 'weak',     'escalated',   'low ticket volume, reassess',               '2026-06-11T14:30:00Z'::timestamptz),
  ('Legacy 2024-Hyd',      '2024-09-12'::date, 22, 22, 13, 9, 12, 59.09, 54.54, 41200.00, 'critical', 'signed_off',  'reference baseline — 18m+ erosion',         '2026-06-09T16:00:00Z'::timestamptz)
) as t(cohort_label, cohort_start_date, cohort_size_engineers, months_since_join, active_engineers, churned_engineers, promoted_tier_count, retention_pct, promotion_pct, avg_monthly_payout_rupees, loop_health, audit_status, founder_notes, reviewed_at);

-- Seed 18 decisions
insert into engineer_cohort_promotion_loop_decisions_r3013
  (audit_id, decision_label, decision_type, target_tier, budget_rupees, expected_retention_lift_pct, priority, decision_status, owner_role, due_date, closed_at)
select a.id, d.decision_label, d.decision_type, d.target_tier, d.budget_rupees, d.expected_retention_lift_pct, d.priority, d.decision_status, d.owner_role, d.due_date, d.closed_at
from engineer_cohort_retention_loop_audit_r3013 a
join (values
  ('Q1-2025 Hyderabad',    'Promote 5 tier2 to tier3',           'promote',   'tier3', 75000.00,  8.50, 'p1', 'executed', 'founder',         '2026-07-15'::date, '2026-06-08T10:00:00Z'::timestamptz),
  ('Q1-2025 Bangalore',    'Coach 3 stalled tier1',              'coach',     'tier2', 18000.00,  5.20, 'p2', 'approved', 'engineer_manager','2026-08-01'::date, null::timestamptz),
  ('Q2-2025 Chennai',      'Retain 2 high-NPS engineers',        'retain',    'tier2', 24000.00,  6.10, 'p1', 'approved', 'ops_lead',        '2026-07-30'::date, null::timestamptz),
  ('Q2-2025 Pune',         'Warn 1 underperformer',              'warn',      'tier1', 0.00,      2.00, 'p2', 'drafted',  'people_ops',      '2026-07-25'::date, null::timestamptz),
  ('Q3-2025 Hyderabad',    'Promote 4 tier3 to tier4',           'promote',   'tier4', 96000.00,  9.40, 'p0', 'executed', 'founder',         '2026-06-30'::date, '2026-06-15T11:00:00Z'::timestamptz),
  ('Q3-2025 Bangalore',    'Reassign 2 to AMC routes',           'reassign',  'tier2', 12000.00,  7.30, 'p0', 'approved', 'ops_lead',        '2026-07-05'::date, null::timestamptz),
  ('Q3-2025 Mumbai',       'Promote 1 to tier3',                 'promote',   'tier3', 15000.00,  4.50, 'p2', 'executed', 'founder',         '2026-06-20'::date, '2026-06-14T09:30:00Z'::timestamptz),
  ('Q4-2025 Hyderabad',    'Coach 4 mid-cohort',                 'coach',     'tier2', 28000.00,  6.80, 'p1', 'approved', 'engineer_manager','2026-08-10'::date, null::timestamptz),
  ('Q4-2025 Bangalore',    'Promote 2 fast-track',               'promote',   'tier3', 30000.00,  5.50, 'p1', 'drafted',  'founder',         '2026-08-15'::date, null::timestamptz),
  ('Q4-2025 Chennai',      'Retain top 3',                       'retain',    'tier2', 21000.00,  4.20, 'p2', 'drafted',  'ops_lead',        '2026-08-20'::date, null::timestamptz),
  ('Q1-2026 Hyderabad',    'Promote 3 early leaders',            'promote',   'tier3', 45000.00,  7.10, 'p1', 'drafted',  'founder',         '2026-09-01'::date, null::timestamptz),
  ('Q1-2026 Bangalore',    'Coach 4 onboarding gap',             'coach',     'tier1', 16000.00,  4.80, 'p2', 'drafted',  'engineer_manager','2026-09-05'::date, null::timestamptz),
  ('Q1-2026 Chennai',      'Retain referral seeders',            'retain',    'tier2', 14000.00,  3.90, 'p3', 'drafted',  'people_ops',      '2026-09-10'::date, null::timestamptz),
  ('Q1-2026 Pune',         'Promote 1 super-specialty',          'promote',   'tier4', 22000.00,  6.40, 'p1', 'drafted',  'founder',         '2026-09-12'::date, null::timestamptz),
  ('Q1-2026 Mumbai',       'Coach 2 weekend coverage',           'coach',     'tier2', 11000.00,  3.50, 'p3', 'drafted',  'engineer_manager','2026-09-15'::date, null::timestamptz),
  ('Pilot SL-Colombo',     'Reassess pilot — offboard 1',        'offboard',  'tier1', 0.00,      0.00, 'p2', 'deferred', 'finance',         '2026-07-20'::date, null::timestamptz),
  ('Pilot BD-Dhaka',       'Reject expansion, scale down',       'offboard',  'tier1', 0.00,      0.00, 'p1', 'rejected', 'finance',         '2026-07-10'::date, '2026-06-11T15:00:00Z'::timestamptz),
  ('Legacy 2024-Hyd',      'Promote 4 veterans to tier5',        'promote',   'tier5', 120000.00, 10.50,'p0', 'executed', 'founder',         '2026-06-25'::date, '2026-06-09T17:00:00Z'::timestamptz)
) as d(cohort_label, decision_label, decision_type, target_tier, budget_rupees, expected_retention_lift_pct, priority, decision_status, owner_role, due_date, closed_at)
  on a.cohort_label = d.cohort_label;

-- ============ RPC 1: cohort retention rollup ============
create or replace function founder_cohort_retention_rollup_r3013()
returns table (
  cohort_label text,
  months_since_join int,
  cohort_size_engineers int,
  active_engineers int,
  retention_pct numeric,
  promotion_pct numeric,
  loop_health text,
  audit_status text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.cohort_label, a.months_since_join, a.cohort_size_engineers,
           a.active_engineers, a.retention_pct, a.promotion_pct,
           a.loop_health, a.audit_status
    from engineer_cohort_retention_loop_audit_r3013 a
    order by a.cohort_start_date desc, a.cohort_label;
end $$;

-- ============ RPC 2: loop health breakdown ============
create or replace function founder_cohort_loop_health_breakdown_r3013()
returns table (
  loop_health text,
  cohort_count int,
  total_engineers int,
  active_engineers int,
  avg_retention_pct numeric,
  avg_promotion_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.loop_health,
           count(*)::int,
           sum(a.cohort_size_engineers)::int,
           sum(a.active_engineers)::int,
           round(avg(a.retention_pct), 2),
           round(avg(a.promotion_pct), 2)
    from engineer_cohort_retention_loop_audit_r3013 a
    group by a.loop_health
    order by avg(a.retention_pct) desc;
end $$;

-- ============ RPC 3: 18-month benchmark ============
create or replace function founder_cohort_18month_benchmark_r3013()
returns table (
  cohort_label text,
  months_since_join int,
  retention_pct numeric,
  promotion_pct numeric,
  benchmark_status text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.cohort_label, a.months_since_join, a.retention_pct, a.promotion_pct,
      case
        when a.months_since_join >= 18 and a.retention_pct >= 80 then 'above_benchmark'
        when a.months_since_join >= 18 and a.retention_pct >= 70 then 'at_benchmark'
        when a.months_since_join >= 18 then 'below_benchmark'
        else 'pre_18m'
      end::text
    from engineer_cohort_retention_loop_audit_r3013 a
    order by a.months_since_join desc, a.retention_pct desc;
end $$;

-- ============ RPC 4: pending decisions queue ============
create or replace function founder_cohort_pending_decisions_r3013()
returns table (
  cohort_label text,
  decision_label text,
  decision_type text,
  target_tier text,
  budget_rupees numeric,
  priority text,
  owner_role text,
  due_date date
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.cohort_label, d.decision_label, d.decision_type, d.target_tier,
           d.budget_rupees, d.priority, d.owner_role, d.due_date
    from engineer_cohort_promotion_loop_decisions_r3013 d
    join engineer_cohort_retention_loop_audit_r3013 a on a.id = d.audit_id
    where d.decision_status in ('drafted','approved')
    order by case d.priority when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 else 3 end,
             d.due_date nulls last;
end $$;

-- ============ RPC 5: decision-type budget summary ============
create or replace function founder_cohort_decision_budget_summary_r3013()
returns table (
  decision_type text,
  decision_count int,
  executed_count int,
  total_budget_rupees numeric,
  avg_expected_lift_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select d.decision_type,
           count(*)::int,
           (count(*) filter (where d.decision_status = 'executed'))::int,
           sum(d.budget_rupees),
           round(avg(d.expected_retention_lift_pct), 2)
    from engineer_cohort_promotion_loop_decisions_r3013 d
    group by d.decision_type
    order by sum(d.budget_rupees) desc;
end $$;

-- ============ RPC 6: escalations + critical loops ============
create or replace function founder_cohort_escalated_loops_r3013()
returns table (
  cohort_label text,
  cohort_start_date date,
  months_since_join int,
  loop_health text,
  audit_status text,
  founder_notes text,
  open_decisions int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.cohort_label, a.cohort_start_date, a.months_since_join,
           a.loop_health, a.audit_status, a.founder_notes,
           (select (count(*) filter (where d.decision_status in ('drafted','approved')))::int
              from engineer_cohort_promotion_loop_decisions_r3013 d
              where d.audit_id = a.id)
    from engineer_cohort_retention_loop_audit_r3013 a
    where a.audit_status = 'escalated' or a.loop_health in ('weak','critical')
    order by a.cohort_start_date;
end $$;

-- ============ RPC 7: owner-role workload ============
create or replace function founder_cohort_owner_workload_r3013()
returns table (
  owner_role text,
  open_decisions int,
  executed_decisions int,
  total_budget_open_rupees numeric,
  avg_expected_lift_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select d.owner_role,
           (count(*) filter (where d.decision_status in ('drafted','approved')))::int,
           (count(*) filter (where d.decision_status = 'executed'))::int,
           coalesce(sum(d.budget_rupees) filter (where d.decision_status in ('drafted','approved')), 0),
           round(avg(d.expected_retention_lift_pct), 2)
    from engineer_cohort_promotion_loop_decisions_r3013 d
    group by d.owner_role
    order by (count(*) filter (where d.decision_status in ('drafted','approved')))::int desc;
end $$;

revoke all on function founder_cohort_retention_rollup_r3013()      from public, anon;
revoke all on function founder_cohort_loop_health_breakdown_r3013() from public, anon;
revoke all on function founder_cohort_18month_benchmark_r3013()     from public, anon;
revoke all on function founder_cohort_pending_decisions_r3013()     from public, anon;
revoke all on function founder_cohort_decision_budget_summary_r3013() from public, anon;
revoke all on function founder_cohort_escalated_loops_r3013()       from public, anon;
revoke all on function founder_cohort_owner_workload_r3013()        from public, anon;

grant execute on function founder_cohort_retention_rollup_r3013()      to authenticated;
grant execute on function founder_cohort_loop_health_breakdown_r3013() to authenticated;
grant execute on function founder_cohort_18month_benchmark_r3013()     to authenticated;
grant execute on function founder_cohort_pending_decisions_r3013()     to authenticated;
grant execute on function founder_cohort_decision_budget_summary_r3013() to authenticated;
grant execute on function founder_cohort_escalated_loops_r3013()       to authenticated;
grant execute on function founder_cohort_owner_workload_r3013()        to authenticated;
