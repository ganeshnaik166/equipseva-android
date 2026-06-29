-- Round 2977: Quarterly Strategic Engineering Salary-Band Compression Risk Audit
-- Tables: salary_band_snapshots_r2977, salary_band_compression_findings_r2977

create table if not exists public.salary_band_snapshots_r2977 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  quarter text not null,
  band_level text not null check (band_level in ('L1','L2','L3','L4','L5','L6','L7','staff','principal')),
  job_family text not null check (job_family in ('field_engineer','sr_field_engineer','specialist','lead','manager','platform','data')),
  city text not null,
  band_min_lpa numeric(8,2) not null check (band_min_lpa > 0),
  band_mid_lpa numeric(8,2) not null check (band_mid_lpa > 0),
  band_max_lpa numeric(8,2) not null check (band_max_lpa > 0),
  current_median_lpa numeric(8,2) not null check (current_median_lpa > 0),
  current_p25_lpa numeric(8,2) not null check (current_p25_lpa > 0),
  current_p75_lpa numeric(8,2) not null check (current_p75_lpa > 0),
  headcount int not null check (headcount >= 0),
  compa_ratio numeric(5,3) not null check (compa_ratio > 0),
  range_penetration_pct numeric(5,2) not null check (range_penetration_pct >= 0 and range_penetration_pct <= 200),
  market_p50_lpa numeric(8,2) not null check (market_p50_lpa > 0),
  market_gap_pct numeric(6,2) not null,
  yoy_band_change_pct numeric(5,2) not null,
  notes text
);

alter table public.salary_band_snapshots_r2977 enable row level security;
drop policy if exists sbs_r2977_founder_select on public.salary_band_snapshots_r2977;
create policy sbs_r2977_founder_select on public.salary_band_snapshots_r2977 for select using (public.is_founder());

create table if not exists public.salary_band_compression_findings_r2977 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  quarter text not null,
  finding_type text not null check (finding_type in ('compression','inversion','overlap','laggard','runaway','equity_gap','market_lag','retention_risk')),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  lower_band text not null,
  upper_band text not null,
  job_family text not null,
  city text not null,
  delta_lpa numeric(8,2) not null,
  overlap_pct numeric(5,2) not null check (overlap_pct >= 0 and overlap_pct <= 100),
  affected_headcount int not null check (affected_headcount >= 0),
  est_correction_cost_lpa numeric(10,2) not null check (est_correction_cost_lpa >= 0),
  attrition_risk_pct numeric(5,2) not null check (attrition_risk_pct >= 0 and attrition_risk_pct <= 100),
  status text not null default 'open' check (status in ('open','reviewing','approved','correcting','resolved','accepted_risk')),
  recommended_action text not null,
  owner text not null,
  due_date date not null
);

alter table public.salary_band_compression_findings_r2977 enable row level security;
drop policy if exists sbcf_r2977_founder_select on public.salary_band_compression_findings_r2977;
create policy sbcf_r2977_founder_select on public.salary_band_compression_findings_r2977 for select using (public.is_founder());

-- Seeds: snapshots (18 rows)
insert into public.salary_band_snapshots_r2977
(quarter,band_level,job_family,city,band_min_lpa,band_mid_lpa,band_max_lpa,current_median_lpa,current_p25_lpa,current_p75_lpa,headcount,compa_ratio,range_penetration_pct,market_p50_lpa,market_gap_pct,yoy_band_change_pct,notes) values
('2026Q2','L1','field_engineer','Hyderabad',3.50,4.50,5.50,4.20,3.80,4.80,42,0.933,35.00,4.80,-12.50,8.00,'entry band tight'),
('2026Q2','L2','field_engineer','Hyderabad',4.50,5.75,7.00,5.90,5.20,6.40,38,1.026,56.00,6.20,-4.84,7.50,'healthy mid'),
('2026Q2','L3','sr_field_engineer','Hyderabad',6.50,8.00,9.50,8.40,7.80,9.10,28,1.050,63.33,9.10,-7.69,6.00,'overlap with L2'),
('2026Q2','L3','sr_field_engineer','Bengaluru',7.50,9.25,11.00,9.80,8.90,10.60,22,1.059,65.71,10.80,-9.26,6.50,'market hot'),
('2026Q2','L4','specialist','Bengaluru',10.00,12.50,15.00,13.20,12.10,14.40,18,1.056,64.00,15.00,-12.00,5.00,'lagging market'),
('2026Q2','L4','specialist','Chennai',9.00,11.25,13.50,11.80,10.90,12.90,15,1.049,62.22,13.40,-11.94,5.50,'inversion risk vs L5'),
('2026Q2','L5','lead','Bengaluru',14.00,17.00,20.00,17.50,16.20,19.10,12,1.029,58.33,21.00,-16.67,4.50,'P75 nearly = L6 P25'),
('2026Q2','L5','lead','Hyderabad',12.50,15.50,18.50,15.80,14.40,17.20,14,1.019,55.00,18.50,-14.59,5.00,'compressed'),
('2026Q2','L6','manager','Bengaluru',18.00,22.50,27.00,23.00,21.40,25.10,8,1.022,55.56,28.00,-17.86,4.00,'overlap L5'),
('2026Q2','L6','manager','Hyderabad',16.50,20.50,24.50,21.20,19.80,23.00,9,1.034,58.75,24.00,-11.67,4.50,'mid healthy'),
('2026Q2','L7','platform','Bengaluru',26.00,32.00,38.00,33.50,31.20,36.40,5,1.047,62.50,42.00,-20.24,3.50,'severe market gap'),
('2026Q2','staff','platform','Bengaluru',38.00,46.00,54.00,48.50,45.00,52.00,3,1.054,65.62,58.00,-16.38,3.00,'staff lag'),
('2026Q2','principal','platform','Bengaluru',54.00,65.00,76.00,67.00,62.00,73.50,2,1.031,59.09,82.00,-18.29,3.00,'principal lag'),
('2026Q2','L2','data','Hyderabad',5.00,6.50,8.00,7.20,6.40,7.80,6,1.108,73.33,7.80,-7.69,7.00,'above mid'),
('2026Q2','L3','data','Bengaluru',8.00,10.00,12.00,10.80,9.90,11.60,7,1.080,70.00,12.50,-13.60,6.00,'lag'),
('2026Q2','L4','data','Bengaluru',12.00,15.00,18.00,15.80,14.60,17.10,5,1.053,63.33,18.50,-14.59,5.50,'lag'),
('2026Q2','L1','field_engineer','Chennai',3.20,4.20,5.20,3.90,3.60,4.40,30,0.929,35.00,4.50,-13.33,8.50,'tier-2 city'),
('2026Q2','L2','field_engineer','Chennai',4.20,5.40,6.60,5.50,4.90,6.10,26,1.019,54.17,5.80,-5.17,8.00,'mid');

-- Seeds: findings (16 rows)
insert into public.salary_band_compression_findings_r2977
(quarter,finding_type,severity,lower_band,upper_band,job_family,city,delta_lpa,overlap_pct,affected_headcount,est_correction_cost_lpa,attrition_risk_pct,status,recommended_action,owner,due_date) values
('2026Q2','compression','p0','L2','L3','field_engineer','Hyderabad',1.50,42.00,28,28.00,32.50,'open','Widen L3 band floor by 8%, lift mid 6%','people_ops','2026-07-15'::date),
('2026Q2','inversion','p0','L4','L5','specialist','Bengaluru',0.40,18.00,12,18.50,38.00,'reviewing','Promote 4 L4s to L5, recalibrate L5 floor','head_eng','2026-07-20'::date),
('2026Q2','overlap','p1','L5','L6','lead','Bengaluru',-0.90,28.00,12,22.40,24.00,'open','Lift L6 floor by 12%, freeze L5 max','head_eng','2026-08-01'::date),
('2026Q2','market_lag','p0','L7','L7','platform','Bengaluru',8.50,0.00,5,42.50,55.00,'approved','Out-of-band adjustment +18% for retention','founder','2026-07-10'::date),
('2026Q2','market_lag','p1','staff','staff','platform','Bengaluru',9.50,0.00,3,28.50,40.00,'reviewing','Match market p50, staff retention','founder','2026-07-25'::date),
('2026Q2','runaway','p2','L2','L2','data','Hyderabad',0.70,0.00,6,4.20,8.00,'open','Cap further increases until band reset','people_ops','2026-08-15'::date),
('2026Q2','laggard','p1','L4','L4','specialist','Chennai',1.60,0.00,15,24.00,28.00,'open','Catch-up cycle Q3','people_ops','2026-08-10'::date),
('2026Q2','compression','p1','L1','L2','field_engineer','Hyderabad',1.70,22.00,42,21.00,18.00,'reviewing','Lift L1 max by 6%','people_ops','2026-08-05'::date),
('2026Q2','retention_risk','p0','L3','L3','sr_field_engineer','Bengaluru',1.00,0.00,22,22.00,42.00,'approved','Spot bonus + band shift','head_eng','2026-07-12'::date),
('2026Q2','equity_gap','p2','L3','L3','sr_field_engineer','Hyderabad',0.60,0.00,28,16.80,15.00,'open','Audit female:male pay parity','people_ops','2026-08-20'::date),
('2026Q2','overlap','p2','L4','L5','data','Bengaluru',-0.80,32.00,5,9.50,22.00,'open','Recalibrate L5 floor','head_eng','2026-08-25'::date),
('2026Q2','market_lag','p1','principal','principal','platform','Bengaluru',15.00,0.00,2,30.00,45.00,'reviewing','Match principal market p50','founder','2026-07-30'::date),
('2026Q2','compression','p2','L5','L6','manager','Hyderabad',1.70,18.00,9,13.50,16.00,'open','Lift L6 mid 5%','people_ops','2026-09-01'::date),
('2026Q2','laggard','p2','L1','L1','field_engineer','Chennai',0.60,0.00,30,18.00,20.00,'open','Tier-2 band lift Q3','people_ops','2026-09-05'::date),
('2026Q2','runaway','p3','L2','L2','field_engineer','Chennai',0.10,0.00,26,2.60,5.00,'accepted_risk','Monitor next quarter','people_ops','2026-09-15'::date),
('2026Q2','retention_risk','p1','L6','L6','manager','Bengaluru',5.00,0.00,8,20.00,30.00,'open','Long-term incentive grants','founder','2026-08-12'::date);

-- RPC 1: summary KPI
create or replace function public.r2977_summary()
returns table(total_findings int, p0_count int, p1_count int, total_headcount_affected int, total_correction_cost_lpa numeric, avg_attrition_risk numeric, open_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where severity = 'p0'))::int,
    (count(*) filter (where severity = 'p1'))::int,
    coalesce(sum(affected_headcount),0)::int,
    coalesce(sum(est_correction_cost_lpa),0)::numeric,
    coalesce(avg(attrition_risk_pct),0)::numeric,
    (count(*) filter (where status = 'open'))::int
  from public.salary_band_compression_findings_r2977;
end; $$;

-- RPC 2: bands by city
create or replace function public.r2977_bands_by_city()
returns table(city text, band_count int, total_headcount int, avg_compa numeric, avg_market_gap numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.city, count(*)::int, sum(s.headcount)::int, avg(s.compa_ratio)::numeric, avg(s.market_gap_pct)::numeric
  from public.salary_band_snapshots_r2977 s group by s.city order by s.city;
end; $$;

-- RPC 3: compression hotspots
create or replace function public.r2977_compression_hotspots()
returns table(lower_band text, upper_band text, job_family text, city text, overlap_pct numeric, affected_headcount int, severity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.lower_band, f.upper_band, f.job_family, f.city, f.overlap_pct, f.affected_headcount, f.severity
  from public.salary_band_compression_findings_r2977 f
  where f.finding_type in ('compression','overlap','inversion')
  order by f.overlap_pct desc, f.severity;
end; $$;

-- RPC 4: market lag report
create or replace function public.r2977_market_lag()
returns table(band_level text, job_family text, city text, current_median_lpa numeric, market_p50_lpa numeric, market_gap_pct numeric, headcount int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.band_level, s.job_family, s.city, s.current_median_lpa, s.market_p50_lpa, s.market_gap_pct, s.headcount
  from public.salary_band_snapshots_r2977 s
  where s.market_gap_pct < -10
  order by s.market_gap_pct;
end; $$;

-- RPC 5: correction budget by family
create or replace function public.r2977_budget_by_family()
returns table(job_family text, findings int, headcount_affected int, total_cost_lpa numeric, avg_attrition_risk numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.job_family, count(*)::int, sum(f.affected_headcount)::int, sum(f.est_correction_cost_lpa)::numeric, avg(f.attrition_risk_pct)::numeric
  from public.salary_band_compression_findings_r2977 f
  group by f.job_family order by sum(f.est_correction_cost_lpa) desc;
end; $$;

-- RPC 6: due soon
create or replace function public.r2977_due_soon()
returns table(finding_type text, severity text, lower_band text, upper_band text, city text, owner text, due_date date, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_type, f.severity, f.lower_band, f.upper_band, f.city, f.owner, f.due_date, f.status
  from public.salary_band_compression_findings_r2977 f
  where f.due_date <= ('2026-08-15'::date) and f.status <> 'resolved'
  order by f.due_date;
end; $$;

-- RPC 7: range penetration distribution
create or replace function public.r2977_penetration_dist()
returns table(bucket text, band_count int, total_headcount int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    case
      when s.range_penetration_pct < 40 then 'under_40'
      when s.range_penetration_pct < 60 then '40_to_60'
      when s.range_penetration_pct < 80 then '60_to_80'
      else 'over_80'
    end as bucket,
    count(*)::int,
    sum(s.headcount)::int
  from public.salary_band_snapshots_r2977 s
  group by 1 order by 1;
end; $$;

-- RPC 8: status board
create or replace function public.r2977_status_board()
returns table(status text, findings int, total_cost_lpa numeric, headcount_affected int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.status, count(*)::int, sum(f.est_correction_cost_lpa)::numeric, sum(f.affected_headcount)::int
  from public.salary_band_compression_findings_r2977 f
  group by f.status order by f.status;
end; $$;

revoke all on public.salary_band_snapshots_r2977 from public, anon;
revoke all on public.salary_band_compression_findings_r2977 from public, anon;
grant select on public.salary_band_snapshots_r2977 to authenticated;
grant select on public.salary_band_compression_findings_r2977 to authenticated;

revoke all on function public.r2977_summary() from public, anon;
revoke all on function public.r2977_bands_by_city() from public, anon;
revoke all on function public.r2977_compression_hotspots() from public, anon;
revoke all on function public.r2977_market_lag() from public, anon;
revoke all on function public.r2977_budget_by_family() from public, anon;
revoke all on function public.r2977_due_soon() from public, anon;
revoke all on function public.r2977_penetration_dist() from public, anon;
revoke all on function public.r2977_status_board() from public, anon;

grant execute on function public.r2977_summary() to authenticated;
grant execute on function public.r2977_bands_by_city() to authenticated;
grant execute on function public.r2977_compression_hotspots() to authenticated;
grant execute on function public.r2977_market_lag() to authenticated;
grant execute on function public.r2977_budget_by_family() to authenticated;
grant execute on function public.r2977_due_soon() to authenticated;
grant execute on function public.r2977_penetration_dist() to authenticated;
grant execute on function public.r2977_status_board() to authenticated;
