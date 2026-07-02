-- Round r2954: Engineer Monthly Customer Site Patient-Privacy Curtain & Drape Discipline Audit
-- Founder console: enforce privacy curtain/drape discipline at hospital sites during engineer visits.

set search_path = public, pg_temp;

-- =====================================================================
-- TABLE 1: monthly site curtain audits
-- =====================================================================
create table if not exists engineer_curtain_audits_r2954 (
  id uuid primary key default gen_random_uuid(),
  audit_month date not null,
  engineer_user_id uuid,
  engineer_name text not null,
  hospital_org_id uuid,
  hospital_name text not null,
  ward_name text not null,
  curtain_count_total int not null check (curtain_count_total >= 0),
  curtain_count_compliant int not null check (curtain_count_compliant >= 0),
  drape_count_total int not null check (drape_count_total >= 0),
  drape_count_compliant int not null check (drape_count_compliant >= 0),
  privacy_score_pct numeric(5,2) not null check (privacy_score_pct between 0 and 100),
  discipline_grade text not null check (discipline_grade in ('A','B','C','D','F')),
  audit_status text not null check (audit_status in ('pending','in_progress','completed','escalated','remediation_required')),
  notes text,
  created_at timestamptz not null default now()
);

alter table engineer_curtain_audits_r2954 enable row level security;

drop policy if exists curtain_audits_r2954_founder_select on engineer_curtain_audits_r2954;
create policy curtain_audits_r2954_founder_select on engineer_curtain_audits_r2954
  for select to authenticated using (is_founder());

-- =====================================================================
-- TABLE 2: discipline incidents discovered during audits
-- =====================================================================
create table if not exists curtain_discipline_incidents_r2954 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid references engineer_curtain_audits_r2954(id) on delete cascade,
  incident_month date not null,
  hospital_name text not null,
  ward_name text not null,
  engineer_name text not null,
  incident_type text not null check (incident_type in ('torn_curtain','missing_drape','soiled_fabric','wrong_size','rail_damaged','no_curtain_zone','privacy_breach')),
  severity text not null check (severity in ('low','medium','high','critical')),
  patient_exposure_minutes int not null check (patient_exposure_minutes >= 0),
  remediation_status text not null check (remediation_status in ('open','assigned','in_repair','resolved','waived')),
  fine_amount_rupees int not null default 0 check (fine_amount_rupees >= 0),
  reported_at timestamptz not null default now(),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

alter table curtain_discipline_incidents_r2954 enable row level security;

drop policy if exists curtain_incidents_r2954_founder_select on curtain_discipline_incidents_r2954;
create policy curtain_incidents_r2954_founder_select on curtain_discipline_incidents_r2954
  for select to authenticated using (is_founder());

-- =====================================================================
-- SEED — audits (18 rows)
-- =====================================================================
insert into engineer_curtain_audits_r2954
  (audit_month, engineer_name, hospital_name, ward_name, curtain_count_total, curtain_count_compliant, drape_count_total, drape_count_compliant, privacy_score_pct, discipline_grade, audit_status, notes)
values
  ('2026-06-01'::date, 'Rajesh Kumar', 'Apollo Hyderabad', 'ICU-3', 24, 23, 12, 12, 97.22, 'A', 'completed', 'Excellent discipline'),
  ('2026-06-01'::date, 'Priya Sharma', 'Yashoda Secunderabad', 'Maternity Wing', 32, 28, 16, 14, 87.50, 'B', 'completed', 'Two drapes need replacement'),
  ('2026-06-01'::date, 'Arun Patel', 'KIMS Begumpet', 'General Ward A', 40, 30, 20, 16, 76.67, 'C', 'remediation_required', 'Multiple torn curtains'),
  ('2026-06-01'::date, 'Sneha Reddy', 'Continental Hospitals', 'Cath Lab', 16, 16, 8, 8, 100.00, 'A', 'completed', 'Perfect compliance'),
  ('2026-06-01'::date, 'Vikram Singh', 'Care Banjara', 'Pediatric Ward', 28, 19, 14, 10, 69.05, 'D', 'escalated', 'Critical breach in peds'),
  ('2026-06-01'::date, 'Lakshmi Iyer', 'Rainbow Children', 'NICU', 20, 20, 10, 10, 100.00, 'A', 'completed', 'NICU pristine'),
  ('2026-06-01'::date, 'Mohammed Ali', 'Sunshine Hospitals', 'Ortho Ward', 36, 30, 18, 15, 83.33, 'B', 'completed', 'Acceptable'),
  ('2026-06-01'::date, 'Deepak Verma', 'AIG Hospitals', 'GI Wing', 30, 27, 15, 13, 88.89, 'B', 'completed', 'Two stained drapes'),
  ('2026-06-01'::date, 'Anita Joshi', 'Star Hospitals', 'Cardiac OT', 12, 12, 6, 6, 100.00, 'A', 'completed', 'OT-grade clean'),
  ('2026-06-01'::date, 'Rakesh Nair', 'Medicover', 'Onco Day Care', 22, 14, 11, 8, 64.39, 'F', 'escalated', 'Major non-compliance'),
  ('2026-05-01'::date, 'Rajesh Kumar', 'Apollo Hyderabad', 'ICU-3', 24, 22, 12, 11, 93.06, 'A', 'completed', 'Previous month'),
  ('2026-05-01'::date, 'Priya Sharma', 'Yashoda Secunderabad', 'Maternity Wing', 32, 25, 16, 12, 79.17, 'C', 'completed', 'Previous month'),
  ('2026-05-01'::date, 'Arun Patel', 'KIMS Begumpet', 'General Ward A', 40, 28, 20, 14, 73.33, 'C', 'remediation_required', 'Recurring issue'),
  ('2026-06-01'::date, 'Suresh Goud', 'Omega Hospitals', 'Onco IPD', 26, 22, 13, 11, 84.62, 'B', 'completed', 'Stable'),
  ('2026-06-01'::date, 'Kavya Menon', 'Pace Hospitals', 'General OPD', 18, 17, 9, 9, 96.30, 'A', 'completed', 'Near perfect'),
  ('2026-06-01'::date, 'Harish Bhat', 'Citizens Hospitals', 'ICU-2', 24, 18, 12, 9, 75.00, 'C', 'remediation_required', 'ICU under pressure'),
  ('2026-06-01'::date, 'Neha Kapoor', 'Virinchi Hospitals', 'Step-down ICU', 20, 19, 10, 10, 96.67, 'A', 'completed', 'Strong recovery'),
  ('2026-06-01'::date, 'Tarun Iyer', 'Asian Institute', 'GI OT', 14, 14, 7, 7, 100.00, 'A', 'completed', 'OT spotless');

-- =====================================================================
-- SEED — incidents (24 rows)
-- =====================================================================
insert into curtain_discipline_incidents_r2954
  (incident_month, hospital_name, ward_name, engineer_name, incident_type, severity, patient_exposure_minutes, remediation_status, fine_amount_rupees, resolved_at)
values
  ('2026-06-01'::date, 'KIMS Begumpet', 'General Ward A', 'Arun Patel', 'torn_curtain', 'high', 45, 'in_repair', 5000, null),
  ('2026-06-01'::date, 'KIMS Begumpet', 'General Ward A', 'Arun Patel', 'missing_drape', 'medium', 20, 'resolved', 2000, now()),
  ('2026-06-01'::date, 'Care Banjara', 'Pediatric Ward', 'Vikram Singh', 'privacy_breach', 'critical', 90, 'assigned', 25000, null),
  ('2026-06-01'::date, 'Care Banjara', 'Pediatric Ward', 'Vikram Singh', 'soiled_fabric', 'high', 30, 'open', 7500, null),
  ('2026-06-01'::date, 'Medicover', 'Onco Day Care', 'Rakesh Nair', 'torn_curtain', 'high', 60, 'in_repair', 5000, null),
  ('2026-06-01'::date, 'Medicover', 'Onco Day Care', 'Rakesh Nair', 'rail_damaged', 'critical', 120, 'assigned', 15000, null),
  ('2026-06-01'::date, 'Medicover', 'Onco Day Care', 'Rakesh Nair', 'no_curtain_zone', 'critical', 180, 'open', 30000, null),
  ('2026-06-01'::date, 'Yashoda Secunderabad', 'Maternity Wing', 'Priya Sharma', 'soiled_fabric', 'medium', 25, 'resolved', 2000, now()),
  ('2026-06-01'::date, 'Yashoda Secunderabad', 'Maternity Wing', 'Priya Sharma', 'wrong_size', 'low', 10, 'resolved', 500, now()),
  ('2026-06-01'::date, 'Sunshine Hospitals', 'Ortho Ward', 'Mohammed Ali', 'torn_curtain', 'medium', 15, 'resolved', 1500, now()),
  ('2026-06-01'::date, 'AIG Hospitals', 'GI Wing', 'Deepak Verma', 'soiled_fabric', 'low', 8, 'resolved', 500, now()),
  ('2026-06-01'::date, 'Citizens Hospitals', 'ICU-2', 'Harish Bhat', 'missing_drape', 'high', 40, 'in_repair', 5000, null),
  ('2026-06-01'::date, 'Citizens Hospitals', 'ICU-2', 'Harish Bhat', 'torn_curtain', 'medium', 22, 'assigned', 2000, null),
  ('2026-06-01'::date, 'Citizens Hospitals', 'ICU-2', 'Harish Bhat', 'rail_damaged', 'high', 50, 'open', 7500, null),
  ('2026-06-01'::date, 'Omega Hospitals', 'Onco IPD', 'Suresh Goud', 'wrong_size', 'low', 5, 'resolved', 500, now()),
  ('2026-05-01'::date, 'KIMS Begumpet', 'General Ward A', 'Arun Patel', 'torn_curtain', 'medium', 35, 'resolved', 2000, now()),
  ('2026-05-01'::date, 'Yashoda Secunderabad', 'Maternity Wing', 'Priya Sharma', 'missing_drape', 'medium', 18, 'resolved', 2000, now()),
  ('2026-06-01'::date, 'Pace Hospitals', 'General OPD', 'Kavya Menon', 'torn_curtain', 'low', 6, 'resolved', 500, now()),
  ('2026-06-01'::date, 'Star Hospitals', 'Cardiac OT', 'Anita Joshi', 'wrong_size', 'low', 4, 'waived', 0, now()),
  ('2026-06-01'::date, 'Apollo Hyderabad', 'ICU-3', 'Rajesh Kumar', 'soiled_fabric', 'low', 7, 'resolved', 500, now()),
  ('2026-06-01'::date, 'Continental Hospitals', 'Cath Lab', 'Sneha Reddy', 'wrong_size', 'low', 3, 'waived', 0, now()),
  ('2026-06-01'::date, 'Care Banjara', 'Pediatric Ward', 'Vikram Singh', 'torn_curtain', 'high', 55, 'in_repair', 5000, null),
  ('2026-06-01'::date, 'Virinchi Hospitals', 'Step-down ICU', 'Neha Kapoor', 'soiled_fabric', 'low', 5, 'resolved', 500, now()),
  ('2026-06-01'::date, 'Rainbow Children', 'NICU', 'Lakshmi Iyer', 'wrong_size', 'low', 2, 'waived', 0, now());

-- =====================================================================
-- RPC 1: monthly summary
-- =====================================================================
create or replace function founder_curtain_monthly_summary_r2954()
returns table (
  audit_month date,
  audits_total int,
  audits_completed int,
  audits_escalated int,
  avg_privacy_score_pct numeric,
  grade_a_count int,
  grade_f_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    a.audit_month,
    count(*)::int,
    (count(*) filter (where a.audit_status = 'completed'))::int,
    (count(*) filter (where a.audit_status = 'escalated'))::int,
    round(avg(a.privacy_score_pct), 2),
    (count(*) filter (where a.discipline_grade = 'A'))::int,
    (count(*) filter (where a.discipline_grade = 'F'))::int
  from engineer_curtain_audits_r2954 a
  group by a.audit_month
  order by a.audit_month desc;
end;
$$;

revoke all on function founder_curtain_monthly_summary_r2954() from public, anon;
grant execute on function founder_curtain_monthly_summary_r2954() to authenticated;

-- =====================================================================
-- RPC 2: engineer leaderboard
-- =====================================================================
create or replace function founder_curtain_engineer_leaderboard_r2954()
returns table (
  engineer_name text,
  audits_done int,
  avg_score numeric,
  grade_a_count int,
  remediation_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    a.engineer_name,
    count(*)::int,
    round(avg(a.privacy_score_pct), 2),
    (count(*) filter (where a.discipline_grade = 'A'))::int,
    (count(*) filter (where a.audit_status = 'remediation_required'))::int
  from engineer_curtain_audits_r2954 a
  group by a.engineer_name
  order by avg(a.privacy_score_pct) desc;
end;
$$;

revoke all on function founder_curtain_engineer_leaderboard_r2954() from public, anon;
grant execute on function founder_curtain_engineer_leaderboard_r2954() to authenticated;

-- =====================================================================
-- RPC 3: hospital roll-up
-- =====================================================================
create or replace function founder_curtain_hospital_rollup_r2954()
returns table (
  hospital_name text,
  wards_audited int,
  avg_score numeric,
  incidents_open int,
  total_fines_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    a.hospital_name,
    count(distinct a.ward_name)::int,
    round(avg(a.privacy_score_pct), 2),
    coalesce((select (count(*) filter (where i.remediation_status in ('open','assigned','in_repair')))::int
              from curtain_discipline_incidents_r2954 i
              where i.hospital_name = a.hospital_name), 0),
    coalesce((select sum(i.fine_amount_rupees) from curtain_discipline_incidents_r2954 i
              where i.hospital_name = a.hospital_name), 0)
  from engineer_curtain_audits_r2954 a
  group by a.hospital_name
  order by avg(a.privacy_score_pct) asc;
end;
$$;

revoke all on function founder_curtain_hospital_rollup_r2954() from public, anon;
grant execute on function founder_curtain_hospital_rollup_r2954() to authenticated;

-- =====================================================================
-- RPC 4: incident severity breakdown
-- =====================================================================
create or replace function founder_curtain_incident_severity_r2954()
returns table (
  severity text,
  incident_count int,
  total_exposure_minutes bigint,
  total_fines_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    i.severity,
    count(*)::int,
    sum(i.patient_exposure_minutes)::bigint,
    sum(i.fine_amount_rupees)::bigint
  from curtain_discipline_incidents_r2954 i
  group by i.severity
  order by
    case i.severity
      when 'critical' then 1
      when 'high' then 2
      when 'medium' then 3
      when 'low' then 4
    end;
end;
$$;

revoke all on function founder_curtain_incident_severity_r2954() from public, anon;
grant execute on function founder_curtain_incident_severity_r2954() to authenticated;

-- =====================================================================
-- RPC 5: incident type frequency
-- =====================================================================
create or replace function founder_curtain_incident_types_r2954()
returns table (
  incident_type text,
  occurrences int,
  open_count int,
  avg_exposure_minutes numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    i.incident_type,
    count(*)::int,
    (count(*) filter (where i.remediation_status = 'open'))::int,
    round(avg(i.patient_exposure_minutes), 1)
  from curtain_discipline_incidents_r2954 i
  group by i.incident_type
  order by count(*) desc;
end;
$$;

revoke all on function founder_curtain_incident_types_r2954() from public, anon;
grant execute on function founder_curtain_incident_types_r2954() to authenticated;

-- =====================================================================
-- RPC 6: open critical incidents
-- =====================================================================
create or replace function founder_curtain_open_critical_r2954()
returns table (
  id uuid,
  hospital_name text,
  ward_name text,
  engineer_name text,
  incident_type text,
  patient_exposure_minutes int,
  fine_amount_rupees int,
  reported_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    i.id, i.hospital_name, i.ward_name, i.engineer_name,
    i.incident_type, i.patient_exposure_minutes, i.fine_amount_rupees, i.reported_at
  from curtain_discipline_incidents_r2954 i
  where i.severity in ('high','critical')
    and i.remediation_status in ('open','assigned','in_repair')
  order by i.patient_exposure_minutes desc;
end;
$$;

revoke all on function founder_curtain_open_critical_r2954() from public, anon;
grant execute on function founder_curtain_open_critical_r2954() to authenticated;

-- =====================================================================
-- RPC 7: month-over-month delta per engineer
-- =====================================================================
create or replace function founder_curtain_mom_delta_r2954()
returns table (
  engineer_name text,
  current_score numeric,
  prior_score numeric,
  score_delta numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with cur as (
    select a.engineer_name, avg(a.privacy_score_pct) as s
    from engineer_curtain_audits_r2954 a
    where a.audit_month = '2026-06-01'::date
    group by a.engineer_name
  ),
  prv as (
    select a.engineer_name, avg(a.privacy_score_pct) as s
    from engineer_curtain_audits_r2954 a
    where a.audit_month = '2026-05-01'::date
    group by a.engineer_name
  )
  select
    cur.engineer_name,
    round(cur.s, 2),
    round(coalesce(prv.s, 0), 2),
    round(cur.s - coalesce(prv.s, 0), 2)
  from cur left join prv on prv.engineer_name = cur.engineer_name
  order by (cur.s - coalesce(prv.s, 0)) desc;
end;
$$;

revoke all on function founder_curtain_mom_delta_r2954() from public, anon;
grant execute on function founder_curtain_mom_delta_r2954() to authenticated;
