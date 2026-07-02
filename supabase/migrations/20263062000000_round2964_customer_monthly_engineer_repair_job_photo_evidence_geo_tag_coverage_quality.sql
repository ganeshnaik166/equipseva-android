-- Round 2964: Customer Monthly Engineer Repair-Job Photo-Evidence Geo-Tag Coverage Quality

create table if not exists customer_monthly_engineer_photo_coverage_r2964 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  month_start date not null,
  customer_org_name text not null,
  engineer_name text not null,
  city text not null,
  jobs_completed int not null,
  jobs_with_photo int not null,
  jobs_with_geotag int not null,
  photo_coverage_pct numeric(5,2) not null,
  geotag_coverage_pct numeric(5,2) not null,
  quality_tier text not null check (quality_tier in ('platinum','gold','silver','bronze','flagged')),
  notes text
);

create table if not exists customer_monthly_engineer_photo_quality_audit_r2964 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  coverage_id uuid references customer_monthly_engineer_photo_coverage_r2964(id) on delete cascade,
  audit_date date not null,
  audited_photo_count int not null,
  blurry_count int not null,
  off_site_count int not null,
  duplicate_count int not null,
  rejection_rate_pct numeric(5,2) not null,
  audit_status text not null check (audit_status in ('passed','warning','failed','re_audit_required'))
);

alter table customer_monthly_engineer_photo_coverage_r2964 enable row level security;
alter table customer_monthly_engineer_photo_quality_audit_r2964 enable row level security;

drop policy if exists cmepc_r2964_sel on customer_monthly_engineer_photo_coverage_r2964;
create policy cmepc_r2964_sel on customer_monthly_engineer_photo_coverage_r2964 for select using (is_founder());

drop policy if exists cmepqa_r2964_sel on customer_monthly_engineer_photo_quality_audit_r2964;
create policy cmepqa_r2964_sel on customer_monthly_engineer_photo_quality_audit_r2964 for select using (is_founder());

insert into customer_monthly_engineer_photo_coverage_r2964 (month_start, customer_org_name, engineer_name, city, jobs_completed, jobs_with_photo, jobs_with_geotag, photo_coverage_pct, geotag_coverage_pct, quality_tier, notes) values
('2026-05-01'::date, 'Apollo Jubilee', 'Ravi Kumar', 'Hyderabad', 42, 42, 41, 100.00, 97.62, 'platinum', 'Perfect photo discipline'),
('2026-05-01'::date, 'KIMS Secunderabad', 'Suresh M', 'Hyderabad', 38, 36, 35, 94.74, 92.11, 'gold', 'Two missed photos on AMC visits'),
('2026-05-01'::date, 'Yashoda Somajiguda', 'Anil P', 'Hyderabad', 51, 47, 44, 92.16, 86.27, 'gold', 'Geotag drift in basement floor'),
('2026-05-01'::date, 'Continental Gachibowli', 'Vikram S', 'Hyderabad', 29, 24, 22, 82.76, 75.86, 'silver', 'Below threshold — coach'),
('2026-05-01'::date, 'Care Banjara', 'Manoj T', 'Hyderabad', 33, 28, 26, 84.85, 78.79, 'silver', 'Need indoor geotag training'),
('2026-05-01'::date, 'Sunshine Hospitals', 'Deepak R', 'Hyderabad', 47, 45, 43, 95.74, 91.49, 'gold', 'Solid'),
('2026-05-01'::date, 'Manipal Vijayawada', 'Krishna B', 'Vijayawada', 22, 14, 12, 63.64, 54.55, 'bronze', 'CRITICAL coverage gap'),
('2026-05-01'::date, 'Aster Medcity Bengaluru', 'Naveen K', 'Bengaluru', 56, 55, 54, 98.21, 96.43, 'platinum', 'Top performer'),
('2026-05-01'::date, 'Fortis Bannerghatta', 'Ajay V', 'Bengaluru', 44, 41, 40, 93.18, 90.91, 'gold', 'Consistent'),
('2026-05-01'::date, 'Narayana Health City', 'Rakesh G', 'Bengaluru', 39, 30, 28, 76.92, 71.79, 'silver', 'Improvement needed'),
('2026-05-01'::date, 'Columbia Asia Yeshwanthpur', 'Sandeep L', 'Bengaluru', 27, 17, 15, 62.96, 55.56, 'bronze', 'Coach or rotate'),
('2026-05-01'::date, 'Kauvery Chennai', 'Mohan E', 'Chennai', 35, 19, 16, 54.29, 45.71, 'flagged', 'PIP issued'),
('2026-05-01'::date, 'MIOT International', 'Bharath S', 'Chennai', 48, 46, 45, 95.83, 93.75, 'gold', 'Reliable'),
('2026-05-01'::date, 'Apollo Greams Road', 'Karthik N', 'Chennai', 53, 53, 52, 100.00, 98.11, 'platinum', 'Audit-ready'),
('2026-05-01'::date, 'Lilavati Bandra', 'Pravin J', 'Mumbai', 41, 38, 36, 92.68, 87.80, 'gold', 'Geotag in tower-B weak'),
('2026-05-01'::date, 'Hinduja Mahim', 'Sanjay D', 'Mumbai', 32, 20, 17, 62.50, 53.13, 'bronze', 'Coverage red flag'),
('2026-05-01'::date, 'Kokilaben DAH', 'Yogesh P', 'Mumbai', 46, 45, 44, 97.83, 95.65, 'platinum', 'Excellent'),
('2026-05-01'::date, 'AIIMS Delhi', 'Rohan K', 'Delhi', 58, 50, 47, 86.21, 81.03, 'silver', 'Volume pressure'),
('2026-05-01'::date, 'Max Saket', 'Aditya M', 'Delhi', 37, 35, 33, 94.59, 89.19, 'gold', 'Good'),
('2026-05-01'::date, 'Medanta Gurgaon', 'Vivek R', 'Gurgaon', 43, 43, 42, 100.00, 97.67, 'platinum', 'Benchmark'),
('2026-05-01'::date, 'Fortis Memorial', 'Harish C', 'Gurgaon', 31, 22, 19, 70.97, 61.29, 'bronze', 'Coach urgently');

insert into customer_monthly_engineer_photo_quality_audit_r2964 (coverage_id, audit_date, audited_photo_count, blurry_count, off_site_count, duplicate_count, rejection_rate_pct, audit_status)
select id, '2026-06-05'::date,
  greatest(jobs_with_photo/2, 5),
  case quality_tier when 'platinum' then 0 when 'gold' then 1 when 'silver' then 3 when 'bronze' then 6 else 9 end,
  case quality_tier when 'platinum' then 0 when 'gold' then 0 when 'silver' then 1 when 'bronze' then 3 else 5 end,
  case quality_tier when 'platinum' then 0 when 'gold' then 1 when 'silver' then 2 when 'bronze' then 3 else 4 end,
  case quality_tier when 'platinum' then 0.50 when 'gold' then 4.20 when 'silver' then 11.30 when 'bronze' then 22.80 else 38.50 end,
  case quality_tier when 'platinum' then 'passed' when 'gold' then 'passed' when 'silver' then 'warning' when 'bronze' then 'failed' else 're_audit_required' end
from customer_monthly_engineer_photo_coverage_r2964;

create or replace function founder_r2964_coverage_overview()
returns table(month_start date, engineers_tracked int, avg_photo_pct numeric, avg_geotag_pct numeric, platinum_cnt int, flagged_cnt int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.month_start,
    count(*)::int,
    round(avg(c.photo_coverage_pct),2),
    round(avg(c.geotag_coverage_pct),2),
    (count(*) filter (where c.quality_tier='platinum'))::int,
    (count(*) filter (where c.quality_tier='flagged'))::int
  from customer_monthly_engineer_photo_coverage_r2964 c
  group by c.month_start
  order by c.month_start desc;
end; $$;

create or replace function founder_r2964_tier_breakdown()
returns table(quality_tier text, engineer_count int, total_jobs int, avg_photo_pct numeric, avg_geotag_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.quality_tier,
    count(*)::int,
    sum(c.jobs_completed)::int,
    round(avg(c.photo_coverage_pct),2),
    round(avg(c.geotag_coverage_pct),2)
  from customer_monthly_engineer_photo_coverage_r2964 c
  group by c.quality_tier
  order by case c.quality_tier when 'platinum' then 1 when 'gold' then 2 when 'silver' then 3 when 'bronze' then 4 else 5 end;
end; $$;

create or replace function founder_r2964_city_rollup()
returns table(city text, engineers int, total_jobs int, avg_photo_pct numeric, avg_geotag_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.city,
    count(*)::int,
    sum(c.jobs_completed)::int,
    round(avg(c.photo_coverage_pct),2),
    round(avg(c.geotag_coverage_pct),2)
  from customer_monthly_engineer_photo_coverage_r2964 c
  group by c.city
  order by avg(c.photo_coverage_pct) desc;
end; $$;

create or replace function founder_r2964_top_engineers()
returns table(engineer_name text, customer_org_name text, city text, jobs_completed int, photo_coverage_pct numeric, geotag_coverage_pct numeric, quality_tier text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.engineer_name, c.customer_org_name, c.city, c.jobs_completed, c.photo_coverage_pct, c.geotag_coverage_pct, c.quality_tier
  from customer_monthly_engineer_photo_coverage_r2964 c
  order by c.photo_coverage_pct desc, c.geotag_coverage_pct desc
  limit 10;
end; $$;

create or replace function founder_r2964_flagged_engineers()
returns table(engineer_name text, customer_org_name text, city text, jobs_completed int, photo_coverage_pct numeric, geotag_coverage_pct numeric, notes text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.engineer_name, c.customer_org_name, c.city, c.jobs_completed, c.photo_coverage_pct, c.geotag_coverage_pct, c.notes
  from customer_monthly_engineer_photo_coverage_r2964 c
  where c.quality_tier in ('bronze','flagged')
  order by c.photo_coverage_pct asc;
end; $$;

create or replace function founder_r2964_audit_summary()
returns table(audit_status text, audits int, total_photos int, total_blurry int, total_off_site int, avg_rejection_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_status,
    count(*)::int,
    sum(a.audited_photo_count)::int,
    sum(a.blurry_count)::int,
    sum(a.off_site_count)::int,
    round(avg(a.rejection_rate_pct),2)
  from customer_monthly_engineer_photo_quality_audit_r2964 a
  group by a.audit_status
  order by avg(a.rejection_rate_pct) desc;
end; $$;

create or replace function founder_r2964_audit_detail()
returns table(engineer_name text, customer_org_name text, audit_date date, audited_photo_count int, blurry_count int, off_site_count int, duplicate_count int, rejection_rate_pct numeric, audit_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.engineer_name, c.customer_org_name, a.audit_date, a.audited_photo_count, a.blurry_count, a.off_site_count, a.duplicate_count, a.rejection_rate_pct, a.audit_status
  from customer_monthly_engineer_photo_quality_audit_r2964 a
  join customer_monthly_engineer_photo_coverage_r2964 c on c.id = a.coverage_id
  order by a.rejection_rate_pct desc
  limit 30;
end; $$;

revoke all on function founder_r2964_coverage_overview() from public, anon;
revoke all on function founder_r2964_tier_breakdown() from public, anon;
revoke all on function founder_r2964_city_rollup() from public, anon;
revoke all on function founder_r2964_top_engineers() from public, anon;
revoke all on function founder_r2964_flagged_engineers() from public, anon;
revoke all on function founder_r2964_audit_summary() from public, anon;
revoke all on function founder_r2964_audit_detail() from public, anon;

grant execute on function founder_r2964_coverage_overview() to authenticated;
grant execute on function founder_r2964_tier_breakdown() to authenticated;
grant execute on function founder_r2964_city_rollup() to authenticated;
grant execute on function founder_r2964_top_engineers() to authenticated;
grant execute on function founder_r2964_flagged_engineers() to authenticated;
grant execute on function founder_r2964_audit_summary() to authenticated;
grant execute on function founder_r2964_audit_detail() to authenticated;
