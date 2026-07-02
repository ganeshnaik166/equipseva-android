-- Round r2956 — Customer Monthly Engineer Hospital-Cafeteria Hygiene Quick-Audit Sidebar
-- HEAVY ★★★★

begin;

create table if not exists cafeteria_hygiene_audits_r2956 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_name text not null,
  cafeteria_name text not null,
  city text not null,
  engineer_name text not null,
  audit_month date not null,
  audit_status text not null check (audit_status in ('scheduled','in_progress','completed','overdue','escalated')),
  hygiene_score int not null check (hygiene_score between 0 and 100),
  risk_tier text not null check (risk_tier in ('green','amber','red','critical')),
  meals_per_day int not null check (meals_per_day >= 0),
  audit_duration_minutes int not null check (audit_duration_minutes >= 0),
  findings_count int not null default 0 check (findings_count >= 0),
  customer_signoff boolean not null default false,
  sidebar_pinned boolean not null default false
);

create table if not exists cafeteria_hygiene_findings_r2956 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid not null references cafeteria_hygiene_audits_r2956(id) on delete cascade,
  category text not null check (category in ('food_safety','equipment','staff_hygiene','pest_control','water_quality','waste_disposal','documentation')),
  severity text not null check (severity in ('low','medium','high','critical')),
  finding_summary text not null,
  remediation_status text not null check (remediation_status in ('open','in_progress','resolved','deferred','rejected')),
  remediation_days int not null check (remediation_days >= 0),
  cost_impact_rupees int not null default 0 check (cost_impact_rupees >= 0)
);

alter table cafeteria_hygiene_audits_r2956 enable row level security;
alter table cafeteria_hygiene_findings_r2956 enable row level security;

drop policy if exists r2956_audits_founder on cafeteria_hygiene_audits_r2956;
create policy r2956_audits_founder on cafeteria_hygiene_audits_r2956 for select to authenticated using (is_founder());

drop policy if exists r2956_findings_founder on cafeteria_hygiene_findings_r2956;
create policy r2956_findings_founder on cafeteria_hygiene_findings_r2956 for select to authenticated using (is_founder());

revoke all on cafeteria_hygiene_audits_r2956 from public, anon;
revoke all on cafeteria_hygiene_findings_r2956 from public, anon;
grant select on cafeteria_hygiene_audits_r2956 to authenticated;
grant select on cafeteria_hygiene_findings_r2956 to authenticated;

-- Seed audits (18 rows)
insert into cafeteria_hygiene_audits_r2956 (hospital_name, cafeteria_name, city, engineer_name, audit_month, audit_status, hygiene_score, risk_tier, meals_per_day, audit_duration_minutes, findings_count, customer_signoff, sidebar_pinned) values
  ('Apollo Jubilee', 'Main Block Cafe', 'Hyderabad', 'Ravi K', '2026-06-01'::date, 'completed', 92, 'green', 1200, 95, 2, true, true),
  ('Yashoda Secunderabad', 'Tower 2 Bistro', 'Hyderabad', 'Suresh M', '2026-06-01'::date, 'completed', 78, 'amber', 800, 110, 5, true, false),
  ('Continental Gachibowli', 'Roof Cafe', 'Hyderabad', 'Anita P', '2026-06-01'::date, 'in_progress', 65, 'amber', 600, 80, 7, false, true),
  ('KIMS Kondapur', 'Ground Floor Mess', 'Hyderabad', 'Vikram S', '2026-06-01'::date, 'overdue', 54, 'red', 950, 0, 0, false, true),
  ('Manipal Vijayawada', 'Staff Canteen', 'Vijayawada', 'Priya R', '2026-06-01'::date, 'completed', 88, 'green', 700, 100, 3, true, false),
  ('Star Banjara', 'Visitor Lounge', 'Hyderabad', 'Ramesh T', '2026-06-01'::date, 'escalated', 41, 'critical', 450, 130, 11, false, true),
  ('Sunshine Begumpet', 'Main Cafe', 'Hyderabad', 'Lakshmi V', '2026-05-01'::date, 'completed', 95, 'green', 1100, 85, 1, true, false),
  ('Aster Kakatiya', 'Tower Mess', 'Warangal', 'Ajay D', '2026-05-01'::date, 'completed', 82, 'amber', 550, 105, 4, true, true),
  ('Care Banjara', 'Cardiac Cafe', 'Hyderabad', 'Neha B', '2026-05-01'::date, 'completed', 76, 'amber', 650, 115, 6, true, false),
  ('Olive Vizag', 'Pediatric Bistro', 'Vizag', 'Karthik J', '2026-05-01'::date, 'completed', 89, 'green', 500, 90, 2, true, false),
  ('Krishna Institute', 'OPD Cafe', 'Secunderabad', 'Divya N', '2026-05-01'::date, 'completed', 71, 'amber', 720, 120, 5, true, true),
  ('Asian Institute', 'Main Mess', 'Hyderabad', 'Mohan G', '2026-04-01'::date, 'completed', 58, 'red', 880, 140, 9, true, true),
  ('Citizens Specialty', 'Surgical Cafe', 'Hyderabad', 'Sneha L', '2026-06-01'::date, 'scheduled', 0, 'amber', 400, 0, 0, false, false),
  ('Renova Tarnaka', 'Block A Mess', 'Hyderabad', 'Arjun K', '2026-06-01'::date, 'completed', 84, 'green', 600, 95, 3, true, false),
  ('Medicover Madhapur', 'Atrium Cafe', 'Hyderabad', 'Pooja S', '2026-06-01'::date, 'completed', 73, 'amber', 750, 110, 5, true, true),
  ('Maxcure Madhapur', 'OPD Bistro', 'Hyderabad', 'Rajesh M', '2026-06-01'::date, 'completed', 67, 'amber', 580, 105, 6, true, false),
  ('Rainbow Banjara', 'Pediatric Cafe', 'Hyderabad', 'Kavya P', '2026-06-01'::date, 'completed', 91, 'green', 480, 85, 2, true, true),
  ('AIG Gachibowli', 'Main Atrium', 'Hyderabad', 'Vinod R', '2026-06-01'::date, 'in_progress', 79, 'amber', 1300, 75, 4, false, true);

-- Seed findings (20 rows)
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'food_safety', 'medium', 'Refrigerator temp drift logged twice', 'resolved', 3, 4500 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Apollo Jubilee' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'equipment', 'low', 'Dishwasher gasket showing wear', 'in_progress', 7, 2200 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Yashoda Secunderabad' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'staff_hygiene', 'high', 'Hairnet compliance 60% on spot check', 'open', 1, 800 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Continental Gachibowli' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'pest_control', 'critical', 'Rodent droppings near dry storage', 'open', 1, 15000 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Star Banjara' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'water_quality', 'medium', 'RO membrane past service date', 'in_progress', 5, 8500 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Manipal Vijayawada' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'waste_disposal', 'high', 'Biohazard bin mixed with food waste', 'resolved', 2, 3200 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Sunshine Begumpet' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'documentation', 'low', 'Daily temp log gaps on 2 days', 'resolved', 4, 500 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Aster Kakatiya' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'food_safety', 'high', 'Raw and cooked meat shared cutting board', 'in_progress', 2, 6800 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Care Banjara' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'equipment', 'medium', 'Walk-in chiller seal leak', 'deferred', 14, 12000 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Olive Vizag' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'staff_hygiene', 'medium', 'Glove change frequency below SOP', 'resolved', 3, 1500 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Krishna Institute' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'pest_control', 'critical', 'Cockroach nest behind tandoor', 'in_progress', 1, 18000 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Asian Institute' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'water_quality', 'high', 'TDS reading 380 vs 250 spec', 'open', 2, 5400 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Asian Institute' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'food_safety', 'low', 'Spice container labels faded', 'resolved', 5, 900 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Renova Tarnaka' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'documentation', 'medium', 'FSSAI license copy missing from board', 'in_progress', 6, 0 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Medicover Madhapur' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'waste_disposal', 'medium', 'Grease trap overdue cleaning', 'open', 3, 3800 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Maxcure Madhapur' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'equipment', 'low', 'Steam table thermostat off by 4C', 'resolved', 4, 2100 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Rainbow Banjara' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'staff_hygiene', 'low', 'One handwash station missing soap', 'resolved', 1, 300 from cafeteria_hygiene_audits_r2956 where hospital_name = 'AIG Gachibowli' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'food_safety', 'medium', 'Egg storage above 8C', 'rejected', 0, 0 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Yashoda Secunderabad' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'pest_control', 'high', 'Fly screen mesh torn at vent', 'in_progress', 4, 2700 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Continental Gachibowli' limit 1;
insert into cafeteria_hygiene_findings_r2956 (audit_id, category, severity, finding_summary, remediation_status, remediation_days, cost_impact_rupees)
select id, 'documentation', 'high', 'Pest control vendor contract expired', 'open', 2, 0 from cafeteria_hygiene_audits_r2956 where hospital_name = 'Star Banjara' limit 1;

-- RPC 1: sidebar pinned audits
create or replace function rpc_r2956_sidebar_pinned()
returns table (hospital_name text, cafeteria_name text, city text, audit_status text, risk_tier text, hygiene_score int, findings_count int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.hospital_name, a.cafeteria_name, a.city, a.audit_status, a.risk_tier, a.hygiene_score, a.findings_count
    from cafeteria_hygiene_audits_r2956 a
    where a.sidebar_pinned = true
    order by a.hygiene_score asc;
end $$;

-- RPC 2: monthly summary
create or replace function rpc_r2956_monthly_summary()
returns table (audit_month date, total_audits int, completed_audits int, avg_score numeric, red_or_critical int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.audit_month,
           count(*)::int as total_audits,
           (count(*) filter (where a.audit_status = 'completed'))::int as completed_audits,
           round(avg(a.hygiene_score) filter (where a.audit_status = 'completed')::numeric, 1) as avg_score,
           (count(*) filter (where a.risk_tier in ('red','critical')))::int as red_or_critical
    from cafeteria_hygiene_audits_r2956 a
    group by a.audit_month
    order by a.audit_month desc;
end $$;

-- RPC 3: risk-tier breakdown
create or replace function rpc_r2956_risk_tier_breakdown()
returns table (risk_tier text, audit_count int, avg_findings numeric, avg_meals int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.risk_tier,
           count(*)::int as audit_count,
           round(avg(a.findings_count)::numeric, 1) as avg_findings,
           avg(a.meals_per_day)::int as avg_meals
    from cafeteria_hygiene_audits_r2956 a
    group by a.risk_tier
    order by case a.risk_tier when 'critical' then 1 when 'red' then 2 when 'amber' then 3 when 'green' then 4 end;
end $$;

-- RPC 4: engineer leaderboard
create or replace function rpc_r2956_engineer_leaderboard()
returns table (engineer_name text, audits_done int, avg_score numeric, avg_duration int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.engineer_name,
           (count(*) filter (where a.audit_status = 'completed'))::int as audits_done,
           round(avg(a.hygiene_score) filter (where a.audit_status = 'completed')::numeric, 1) as avg_score,
           avg(a.audit_duration_minutes) filter (where a.audit_status = 'completed')::int as avg_duration
    from cafeteria_hygiene_audits_r2956 a
    group by a.engineer_name
    order by avg_score desc nulls last;
end $$;

-- RPC 5: top open findings
create or replace function rpc_r2956_top_open_findings()
returns table (hospital_name text, category text, severity text, finding_summary text, remediation_days int, cost_impact_rupees int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.hospital_name, f.category, f.severity, f.finding_summary, f.remediation_days, f.cost_impact_rupees
    from cafeteria_hygiene_findings_r2956 f
    join cafeteria_hygiene_audits_r2956 a on a.id = f.audit_id
    where f.remediation_status in ('open','in_progress')
    order by case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 when 'low' then 4 end,
             f.cost_impact_rupees desc
    limit 12;
end $$;

-- RPC 6: category cost rollup
create or replace function rpc_r2956_category_cost_rollup()
returns table (category text, finding_count int, total_cost_rupees int, critical_count int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.category,
           count(*)::int as finding_count,
           sum(f.cost_impact_rupees)::int as total_cost_rupees,
           (count(*) filter (where f.severity = 'critical'))::int as critical_count
    from cafeteria_hygiene_findings_r2956 f
    group by f.category
    order by total_cost_rupees desc;
end $$;

-- RPC 7: signoff funnel
create or replace function rpc_r2956_signoff_funnel()
returns table (audit_status text, total int, signed_off int, signoff_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.audit_status,
           count(*)::int as total,
           (count(*) filter (where a.customer_signoff = true))::int as signed_off,
           round(100.0 * (count(*) filter (where a.customer_signoff = true))::numeric / nullif(count(*),0), 1) as signoff_rate_pct
    from cafeteria_hygiene_audits_r2956 a
    group by a.audit_status
    order by total desc;
end $$;

-- RPC 8: overdue + escalated list
create or replace function rpc_r2956_overdue_escalated()
returns table (hospital_name text, city text, engineer_name text, audit_status text, risk_tier text, meals_per_day int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.hospital_name, a.city, a.engineer_name, a.audit_status, a.risk_tier, a.meals_per_day
    from cafeteria_hygiene_audits_r2956 a
    where a.audit_status in ('overdue','escalated')
    order by a.meals_per_day desc;
end $$;

revoke all on function rpc_r2956_sidebar_pinned() from public, anon;
revoke all on function rpc_r2956_monthly_summary() from public, anon;
revoke all on function rpc_r2956_risk_tier_breakdown() from public, anon;
revoke all on function rpc_r2956_engineer_leaderboard() from public, anon;
revoke all on function rpc_r2956_top_open_findings() from public, anon;
revoke all on function rpc_r2956_category_cost_rollup() from public, anon;
revoke all on function rpc_r2956_signoff_funnel() from public, anon;
revoke all on function rpc_r2956_overdue_escalated() from public, anon;

grant execute on function rpc_r2956_sidebar_pinned() to authenticated;
grant execute on function rpc_r2956_monthly_summary() to authenticated;
grant execute on function rpc_r2956_risk_tier_breakdown() to authenticated;
grant execute on function rpc_r2956_engineer_leaderboard() to authenticated;
grant execute on function rpc_r2956_top_open_findings() to authenticated;
grant execute on function rpc_r2956_category_cost_rollup() to authenticated;
grant execute on function rpc_r2956_signoff_funnel() to authenticated;
grant execute on function rpc_r2956_overdue_escalated() to authenticated;

commit;
