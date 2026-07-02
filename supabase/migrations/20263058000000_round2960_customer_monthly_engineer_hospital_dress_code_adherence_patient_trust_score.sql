-- Round r2960: Customer Monthly Engineer Hospital Dress Code Adherence & Patient Trust Score

create table if not exists engineer_dress_code_audits_r2960 (
  id uuid primary key default gen_random_uuid(),
  audit_month date not null,
  engineer_name text not null,
  hospital_name text not null,
  city text not null,
  uniform_clean_score int not null check (uniform_clean_score between 0 and 100),
  id_badge_visible boolean not null default true,
  shoe_cover_worn boolean not null default true,
  hair_cap_worn boolean not null default true,
  ppe_compliance_score int not null check (ppe_compliance_score between 0 and 100),
  overall_adherence_pct numeric(5,2) not null check (overall_adherence_pct between 0 and 100),
  audit_outcome text not null check (audit_outcome in ('pass','warn','fail','exemplary')),
  auditor_role text not null check (auditor_role in ('hospital_admin','nurse_lead','infection_control','founder')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists patient_trust_scores_r2960 (
  id uuid primary key default gen_random_uuid(),
  score_month date not null,
  hospital_name text not null,
  city text not null,
  patient_count int not null check (patient_count >= 0),
  avg_trust_score numeric(4,2) not null check (avg_trust_score between 0 and 10),
  dress_code_mention_count int not null check (dress_code_mention_count >= 0),
  positive_comments int not null check (positive_comments >= 0),
  negative_comments int not null check (negative_comments >= 0),
  nps_score numeric(5,2) not null check (nps_score between -100 and 100),
  trust_band text not null check (trust_band in ('low','medium','high','elite')),
  follow_up_required boolean not null default false,
  created_at timestamptz not null default now()
);

alter table engineer_dress_code_audits_r2960 enable row level security;
alter table patient_trust_scores_r2960 enable row level security;

drop policy if exists dca_r2960_founder_all on engineer_dress_code_audits_r2960;
create policy dca_r2960_founder_all on engineer_dress_code_audits_r2960
  for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists pts_r2960_founder_all on patient_trust_scores_r2960;
create policy pts_r2960_founder_all on patient_trust_scores_r2960
  for all to authenticated using (is_founder()) with check (is_founder());

insert into engineer_dress_code_audits_r2960 (audit_month, engineer_name, hospital_name, city, uniform_clean_score, id_badge_visible, shoe_cover_worn, hair_cap_worn, ppe_compliance_score, overall_adherence_pct, audit_outcome, auditor_role, notes)
select '2026-06-01'::date, 'Ravi Kumar', 'Apollo Jubilee', 'Hyderabad', 95, true, true, true, 98, 96.50, 'exemplary', 'infection_control', 'Top performer'
union all select '2026-06-01'::date, 'Suresh Reddy', 'KIMS Secunderabad', 'Hyderabad', 88, true, true, true, 90, 89.00, 'pass', 'hospital_admin', null
union all select '2026-06-01'::date, 'Amit Sharma', 'Yashoda Somajiguda', 'Hyderabad', 72, true, false, true, 75, 73.50, 'warn', 'nurse_lead', 'Missing shoe cover'
union all select '2026-06-01'::date, 'Vikram Singh', 'Continental Gachibowli', 'Hyderabad', 92, true, true, true, 94, 93.00, 'pass', 'hospital_admin', null
union all select '2026-06-01'::date, 'Pradeep Naik', 'Care Banjara', 'Hyderabad', 60, false, false, true, 58, 59.00, 'fail', 'infection_control', 'Badge missing, repeat offender'
union all select '2026-06-01'::date, 'Manoj Verma', 'Sunshine Begumpet', 'Hyderabad', 85, true, true, true, 88, 86.50, 'pass', 'hospital_admin', null
union all select '2026-06-01'::date, 'Kiran Patel', 'Apollo DRDO', 'Hyderabad', 98, true, true, true, 99, 98.50, 'exemplary', 'founder', 'Showcase engineer'
union all select '2026-05-01'::date, 'Ravi Kumar', 'Apollo Jubilee', 'Hyderabad', 90, true, true, true, 92, 91.00, 'pass', 'hospital_admin', null
union all select '2026-05-01'::date, 'Suresh Reddy', 'KIMS Secunderabad', 'Hyderabad', 80, true, true, false, 82, 81.00, 'warn', 'nurse_lead', 'No hair cap'
union all select '2026-05-01'::date, 'Amit Sharma', 'Yashoda Somajiguda', 'Hyderabad', 65, true, false, false, 60, 62.50, 'fail', 'infection_control', 'Multiple violations'
union all select '2026-05-01'::date, 'Naveen Rao', 'Manipal Tadepally', 'Hyderabad', 87, true, true, true, 89, 88.00, 'pass', 'hospital_admin', null
union all select '2026-05-01'::date, 'Deepak Joshi', 'Rainbow Banjara', 'Hyderabad', 93, true, true, true, 95, 94.00, 'pass', 'nurse_lead', null
union all select '2026-04-01'::date, 'Ravi Kumar', 'Apollo Jubilee', 'Hyderabad', 88, true, true, true, 90, 89.00, 'pass', 'hospital_admin', null
union all select '2026-04-01'::date, 'Rajesh Iyer', 'AIG Gachibowli', 'Hyderabad', 78, true, true, false, 80, 79.00, 'warn', 'infection_control', 'Hair cap inconsistent'
union all select '2026-06-01'::date, 'Sanjay Kulkarni', 'Fortis Bannerghatta', 'Bangalore', 91, true, true, true, 93, 92.00, 'pass', 'hospital_admin', null
union all select '2026-06-01'::date, 'Arun Pillai', 'Manipal Whitefield', 'Bangalore', 86, true, true, true, 88, 87.00, 'pass', 'nurse_lead', null
union all select '2026-06-01'::date, 'Harish Gowda', 'Narayana Bommasandra', 'Bangalore', 70, false, true, true, 72, 71.00, 'warn', 'infection_control', 'Badge missing'
union all select '2026-06-01'::date, 'Mahesh Bhat', 'Sakra World', 'Bangalore', 96, true, true, true, 97, 96.50, 'exemplary', 'founder', null
union all select '2026-06-01'::date, 'Pawan Tiwari', 'Kokilaben Andheri', 'Mumbai', 89, true, true, true, 91, 90.00, 'pass', 'hospital_admin', null
union all select '2026-06-01'::date, 'Rohit Mishra', 'Hinduja Mahim', 'Mumbai', 55, false, false, false, 50, 52.50, 'fail', 'infection_control', 'Critical, retrain'
union all select '2026-06-01'::date, 'Saurabh Jain', 'Lilavati Bandra', 'Mumbai', 90, true, true, true, 92, 91.00, 'pass', 'hospital_admin', null
union all select '2026-06-01'::date, 'Yogesh Pandey', 'Fortis Shalimar', 'Delhi', 84, true, true, true, 86, 85.00, 'pass', 'nurse_lead', null
union all select '2026-06-01'::date, 'Ankit Goyal', 'Max Saket', 'Delhi', 92, true, true, true, 94, 93.00, 'pass', 'hospital_admin', null
union all select '2026-06-01'::date, 'Tarun Sethi', 'AIIMS Ansari Nagar', 'Delhi', 97, true, true, true, 98, 97.50, 'exemplary', 'founder', 'Government showcase';

insert into patient_trust_scores_r2960 (score_month, hospital_name, city, patient_count, avg_trust_score, dress_code_mention_count, positive_comments, negative_comments, nps_score, trust_band, follow_up_required)
select '2026-06-01'::date, 'Apollo Jubilee', 'Hyderabad', 245, 9.20, 87, 198, 12, 75.50, 'elite', false
union all select '2026-06-01'::date, 'KIMS Secunderabad', 'Hyderabad', 198, 8.40, 65, 142, 22, 60.20, 'high', false
union all select '2026-06-01'::date, 'Yashoda Somajiguda', 'Hyderabad', 312, 6.80, 48, 165, 78, 28.40, 'medium', true
union all select '2026-06-01'::date, 'Continental Gachibowli', 'Hyderabad', 156, 8.90, 72, 128, 14, 68.30, 'high', false
union all select '2026-06-01'::date, 'Care Banjara', 'Hyderabad', 89, 5.20, 18, 32, 38, -12.40, 'low', true
union all select '2026-06-01'::date, 'Sunshine Begumpet', 'Hyderabad', 134, 8.10, 56, 102, 18, 55.80, 'high', false
union all select '2026-06-01'::date, 'Apollo DRDO', 'Hyderabad', 178, 9.50, 95, 162, 6, 82.10, 'elite', false
union all select '2026-05-01'::date, 'Apollo Jubilee', 'Hyderabad', 238, 9.10, 82, 192, 14, 73.80, 'elite', false
union all select '2026-05-01'::date, 'KIMS Secunderabad', 'Hyderabad', 195, 8.20, 60, 138, 25, 57.90, 'high', false
union all select '2026-05-01'::date, 'Yashoda Somajiguda', 'Hyderabad', 305, 6.50, 42, 158, 82, 24.90, 'medium', true
union all select '2026-04-01'::date, 'Apollo Jubilee', 'Hyderabad', 232, 9.00, 78, 188, 16, 72.40, 'elite', false
union all select '2026-04-01'::date, 'Care Banjara', 'Hyderabad', 92, 5.40, 20, 36, 35, -8.20, 'low', true
union all select '2026-06-01'::date, 'Fortis Bannerghatta', 'Bangalore', 210, 8.60, 70, 158, 18, 64.20, 'high', false
union all select '2026-06-01'::date, 'Manipal Whitefield', 'Bangalore', 188, 8.30, 62, 142, 22, 58.40, 'high', false
union all select '2026-06-01'::date, 'Narayana Bommasandra', 'Bangalore', 145, 7.20, 38, 98, 32, 35.60, 'medium', true
union all select '2026-06-01'::date, 'Sakra World', 'Bangalore', 167, 9.40, 88, 155, 8, 78.90, 'elite', false
union all select '2026-06-01'::date, 'Kokilaben Andheri', 'Mumbai', 225, 8.80, 75, 175, 16, 67.50, 'high', false
union all select '2026-06-01'::date, 'Hinduja Mahim', 'Mumbai', 178, 5.80, 22, 58, 65, -3.20, 'low', true
union all select '2026-06-01'::date, 'Lilavati Bandra', 'Mumbai', 198, 8.70, 73, 162, 18, 65.80, 'high', false
union all select '2026-06-01'::date, 'Fortis Shalimar', 'Delhi', 156, 8.20, 58, 118, 22, 56.70, 'high', false
union all select '2026-06-01'::date, 'Max Saket', 'Delhi', 189, 8.90, 82, 158, 12, 70.20, 'high', false
union all select '2026-06-01'::date, 'AIIMS Ansari Nagar', 'Delhi', 412, 9.60, 158, 358, 14, 80.40, 'elite', false;

create or replace function r2960_monthly_adherence_overview()
returns table(audit_month date, total_audits int, exemplary_count int, pass_count int, warn_count int, fail_count int, avg_adherence numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_month,
    count(*)::int as total_audits,
    (count(*) filter (where a.audit_outcome='exemplary'))::int,
    (count(*) filter (where a.audit_outcome='pass'))::int,
    (count(*) filter (where a.audit_outcome='warn'))::int,
    (count(*) filter (where a.audit_outcome='fail'))::int,
    round(avg(a.overall_adherence_pct),2)
  from engineer_dress_code_audits_r2960 a
  group by a.audit_month order by a.audit_month desc;
end; $$;

create or replace function r2960_top_engineers_current()
returns table(engineer_name text, hospital_name text, city text, adherence_pct numeric, audit_outcome text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name, a.hospital_name, a.city, a.overall_adherence_pct, a.audit_outcome
  from engineer_dress_code_audits_r2960 a
  where a.audit_month = '2026-06-01'::date
  order by a.overall_adherence_pct desc limit 10;
end; $$;

create or replace function r2960_failing_engineers()
returns table(engineer_name text, hospital_name text, city text, adherence_pct numeric, notes text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name, a.hospital_name, a.city, a.overall_adherence_pct, a.notes
  from engineer_dress_code_audits_r2960 a
  where a.audit_outcome in ('warn','fail') and a.audit_month = '2026-06-01'::date
  order by a.overall_adherence_pct asc;
end; $$;

create or replace function r2960_trust_band_distribution()
returns table(score_month date, low_band int, medium_band int, high_band int, elite_band int, avg_trust numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.score_month,
    (count(*) filter (where p.trust_band='low'))::int,
    (count(*) filter (where p.trust_band='medium'))::int,
    (count(*) filter (where p.trust_band='high'))::int,
    (count(*) filter (where p.trust_band='elite'))::int,
    round(avg(p.avg_trust_score),2)
  from patient_trust_scores_r2960 p
  group by p.score_month order by p.score_month desc;
end; $$;

create or replace function r2960_hospitals_needing_follow_up()
returns table(hospital_name text, city text, avg_trust_score numeric, negative_comments int, nps_score numeric, trust_band text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.hospital_name, p.city, p.avg_trust_score, p.negative_comments, p.nps_score, p.trust_band
  from patient_trust_scores_r2960 p
  where p.follow_up_required = true and p.score_month = '2026-06-01'::date
  order by p.nps_score asc;
end; $$;

create or replace function r2960_city_breakdown()
returns table(city text, hospital_count int, avg_adherence numeric, avg_trust numeric, total_patients int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.city,
    count(distinct p.hospital_name)::int,
    coalesce(round(avg(a.overall_adherence_pct),2), 0),
    round(avg(p.avg_trust_score),2),
    sum(p.patient_count)::int
  from patient_trust_scores_r2960 p
  left join engineer_dress_code_audits_r2960 a on a.city = p.city and a.audit_month = p.score_month
  where p.score_month = '2026-06-01'::date
  group by p.city order by avg(p.avg_trust_score) desc;
end; $$;

create or replace function r2960_dress_code_correlation()
returns table(hospital_name text, city text, adherence_pct numeric, trust_score numeric, nps_score numeric, dress_mentions int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.hospital_name, p.city,
    coalesce(round(avg(a.overall_adherence_pct),2), 0) as adherence_pct,
    p.avg_trust_score, p.nps_score, p.dress_code_mention_count
  from patient_trust_scores_r2960 p
  left join engineer_dress_code_audits_r2960 a on a.hospital_name = p.hospital_name and a.audit_month = p.score_month
  where p.score_month = '2026-06-01'::date
  group by p.hospital_name, p.city, p.avg_trust_score, p.nps_score, p.dress_code_mention_count
  order by p.avg_trust_score desc;
end; $$;

revoke all on engineer_dress_code_audits_r2960 from public, anon;
revoke all on patient_trust_scores_r2960 from public, anon;
grant select, insert, update, delete on engineer_dress_code_audits_r2960 to authenticated;
grant select, insert, update, delete on patient_trust_scores_r2960 to authenticated;

revoke all on function r2960_monthly_adherence_overview() from public, anon;
revoke all on function r2960_top_engineers_current() from public, anon;
revoke all on function r2960_failing_engineers() from public, anon;
revoke all on function r2960_trust_band_distribution() from public, anon;
revoke all on function r2960_hospitals_needing_follow_up() from public, anon;
revoke all on function r2960_city_breakdown() from public, anon;
revoke all on function r2960_dress_code_correlation() from public, anon;

grant execute on function r2960_monthly_adherence_overview() to authenticated;
grant execute on function r2960_top_engineers_current() to authenticated;
grant execute on function r2960_failing_engineers() to authenticated;
grant execute on function r2960_trust_band_distribution() to authenticated;
grant execute on function r2960_hospitals_needing_follow_up() to authenticated;
grant execute on function r2960_city_breakdown() to authenticated;
grant execute on function r2960_dress_code_correlation() to authenticated;
