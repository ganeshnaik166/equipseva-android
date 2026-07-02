-- Round 2973 — Founder Quarterly Strategic Engineer-Tier Promotion Velocity & Retention Audit

create table if not exists engineer_tier_promotion_events_r2973 (
  id uuid primary key default gen_random_uuid(),
  engineer_code text not null,
  engineer_name text not null,
  from_tier text not null check (from_tier in ('bronze','silver','gold','platinum')),
  to_tier text not null check (to_tier in ('silver','gold','platinum','diamond')),
  promotion_quarter text not null check (promotion_quarter in ('Q1-FY26','Q2-FY26','Q3-FY26','Q4-FY26','Q1-FY27')),
  promotion_date date not null,
  days_in_prior_tier int not null check (days_in_prior_tier > 0),
  jobs_completed_in_tier int not null check (jobs_completed_in_tier >= 0),
  avg_csat numeric(3,2) not null check (avg_csat between 1.0 and 5.0),
  retention_status text not null check (retention_status in ('active','at_risk','churned','star_performer')),
  region text not null check (region in ('south','north','west','east','central')),
  city text not null,
  promotion_velocity_score int not null check (promotion_velocity_score between 0 and 100),
  created_at timestamptz not null default now()
);

create table if not exists engineer_tier_retention_cohorts_r2973 (
  id uuid primary key default gen_random_uuid(),
  cohort_label text not null,
  tier text not null check (tier in ('bronze','silver','gold','platinum','diamond')),
  cohort_quarter text not null check (cohort_quarter in ('Q1-FY26','Q2-FY26','Q3-FY26','Q4-FY26','Q1-FY27')),
  engineers_promoted int not null check (engineers_promoted >= 0),
  engineers_retained_90d int not null check (engineers_retained_90d >= 0),
  engineers_retained_180d int not null check (engineers_retained_180d >= 0),
  retention_rate_90d numeric(5,2) not null check (retention_rate_90d between 0 and 100),
  retention_rate_180d numeric(5,2) not null check (retention_rate_180d between 0 and 100),
  median_jobs_post_promotion int not null check (median_jobs_post_promotion >= 0),
  churn_reason text not null check (churn_reason in ('compensation','workload','geo_move','health','better_offer','none')),
  intervention_recommended text not null check (intervention_recommended in ('bonus','mentorship','workload_balance','retention_call','none')),
  created_at timestamptz not null default now()
);

alter table engineer_tier_promotion_events_r2973 enable row level security;
alter table engineer_tier_retention_cohorts_r2973 enable row level security;

drop policy if exists r2973_promo_founder_read on engineer_tier_promotion_events_r2973;
create policy r2973_promo_founder_read on engineer_tier_promotion_events_r2973 for select to authenticated using (is_founder());

drop policy if exists r2973_cohort_founder_read on engineer_tier_retention_cohorts_r2973;
create policy r2973_cohort_founder_read on engineer_tier_retention_cohorts_r2973 for select to authenticated using (is_founder());

insert into engineer_tier_promotion_events_r2973 (engineer_code, engineer_name, from_tier, to_tier, promotion_quarter, promotion_date, days_in_prior_tier, jobs_completed_in_tier, avg_csat, retention_status, region, city, promotion_velocity_score) values
('ENG-1001','Ravi Kumar','bronze','silver','Q1-FY26','2026-04-12'::date,180,42,4.6,'star_performer','south','Hyderabad',88),
('ENG-1002','Anita Sharma','silver','gold','Q1-FY26','2026-04-18'::date,210,67,4.7,'active','north','Delhi',82),
('ENG-1003','Suresh Patil','gold','platinum','Q1-FY26','2026-05-02'::date,365,134,4.8,'star_performer','west','Pune',91),
('ENG-1004','Meera Iyer','bronze','silver','Q2-FY26','2026-07-09'::date,150,38,4.4,'active','south','Chennai',75),
('ENG-1005','Vikram Singh','silver','gold','Q2-FY26','2026-07-21'::date,240,58,4.5,'at_risk','north','Lucknow',68),
('ENG-1006','Pooja Reddy','gold','platinum','Q2-FY26','2026-08-15'::date,400,142,4.9,'star_performer','south','Bangalore',94),
('ENG-1007','Arjun Mehta','platinum','diamond','Q3-FY26','2026-10-04'::date,500,189,4.95,'star_performer','west','Mumbai',97),
('ENG-1008','Sneha Gupta','bronze','silver','Q3-FY26','2026-10-19'::date,170,45,4.3,'at_risk','central','Bhopal',71),
('ENG-1009','Rohit Joshi','silver','gold','Q3-FY26','2026-11-11'::date,220,72,4.6,'active','west','Ahmedabad',79),
('ENG-1010','Kavita Nair','gold','platinum','Q4-FY26','2026-01-08'::date,380,128,4.7,'active','south','Kochi',85),
('ENG-1011','Sanjay Verma','bronze','silver','Q4-FY26','2026-02-14'::date,160,40,4.2,'churned','north','Jaipur',60),
('ENG-1012','Deepa Rao','silver','gold','Q4-FY26','2026-03-01'::date,250,65,4.4,'active','south','Mysuru',73),
('ENG-1013','Manish Yadav','platinum','diamond','Q1-FY27','2026-04-22'::date,520,201,4.92,'star_performer','north','Gurgaon',96),
('ENG-1014','Lakshmi Pillai','bronze','silver','Q1-FY27','2026-05-05'::date,140,36,4.5,'active','south','Trivandrum',80),
('ENG-1015','Ajay Kapoor','gold','platinum','Q1-FY27','2026-05-29'::date,395,138,4.8,'star_performer','north','Chandigarh',89),
('ENG-1016','Nisha Bose','silver','gold','Q2-FY26','2026-08-30'::date,235,61,4.5,'active','east','Kolkata',77),
('ENG-1017','Prakash Menon','gold','platinum','Q3-FY26','2026-11-26'::date,420,150,4.7,'active','south','Coimbatore',83),
('ENG-1018','Rekha Das','bronze','silver','Q1-FY26','2026-05-15'::date,175,44,4.4,'churned','east','Bhubaneswar',64);

insert into engineer_tier_retention_cohorts_r2973 (cohort_label, tier, cohort_quarter, engineers_promoted, engineers_retained_90d, engineers_retained_180d, retention_rate_90d, retention_rate_180d, median_jobs_post_promotion, churn_reason, intervention_recommended) values
('Bronze→Silver Q1','silver','Q1-FY26',28,26,24,92.86,85.71,18,'none','none'),
('Silver→Gold Q1','gold','Q1-FY26',14,13,12,92.85,85.71,32,'workload','workload_balance'),
('Gold→Platinum Q1','platinum','Q1-FY26',6,6,5,100.00,83.33,58,'better_offer','bonus'),
('Bronze→Silver Q2','silver','Q2-FY26',31,28,25,90.32,80.65,20,'compensation','bonus'),
('Silver→Gold Q2','gold','Q2-FY26',16,14,13,87.50,81.25,30,'geo_move','retention_call'),
('Gold→Platinum Q2','platinum','Q2-FY26',5,5,4,100.00,80.00,62,'none','none'),
('Bronze→Silver Q3','silver','Q3-FY26',35,32,29,91.43,82.86,19,'workload','mentorship'),
('Silver→Gold Q3','gold','Q3-FY26',18,17,15,94.44,83.33,34,'none','none'),
('Gold→Platinum Q3','platinum','Q3-FY26',7,7,6,100.00,85.71,60,'health','retention_call'),
('Platinum→Diamond Q3','diamond','Q3-FY26',2,2,2,100.00,100.00,78,'none','none'),
('Bronze→Silver Q4','silver','Q4-FY26',29,25,22,86.21,75.86,17,'compensation','bonus'),
('Silver→Gold Q4','gold','Q4-FY26',15,13,11,86.67,73.33,28,'better_offer','bonus'),
('Gold→Platinum Q4','platinum','Q4-FY26',8,8,7,100.00,87.50,64,'none','none'),
('Bronze→Silver Q1FY27','silver','Q1-FY27',33,31,0,93.94,0.00,15,'none','none'),
('Silver→Gold Q1FY27','gold','Q1-FY27',17,16,0,94.12,0.00,25,'workload','mentorship'),
('Platinum→Diamond Q1FY27','diamond','Q1-FY27',3,3,0,100.00,0.00,72,'none','none');

create or replace function r2973_promotion_velocity_overview()
returns table(promotion_quarter text, promotions int, avg_velocity numeric, avg_days_in_prior_tier numeric, star_performers int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.promotion_quarter,
         count(*)::int,
         round(avg(e.promotion_velocity_score)::numeric,2),
         round(avg(e.days_in_prior_tier)::numeric,1),
         (count(*) filter (where e.retention_status='star_performer'))::int
  from engineer_tier_promotion_events_r2973 e
  group by e.promotion_quarter
  order by e.promotion_quarter;
end;$$;

create or replace function r2973_tier_transition_matrix()
returns table(from_tier text, to_tier text, transitions int, avg_csat numeric, avg_velocity numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.from_tier, e.to_tier,
         count(*)::int,
         round(avg(e.avg_csat)::numeric,2),
         round(avg(e.promotion_velocity_score)::numeric,2)
  from engineer_tier_promotion_events_r2973 e
  group by e.from_tier, e.to_tier
  order by e.from_tier, e.to_tier;
end;$$;

create or replace function r2973_retention_cohort_summary()
returns table(cohort_quarter text, tier text, promoted int, retained_90d int, retained_180d int, retention_90 numeric, retention_180 numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.cohort_quarter, c.tier,
         sum(c.engineers_promoted)::int,
         sum(c.engineers_retained_90d)::int,
         sum(c.engineers_retained_180d)::int,
         round(avg(c.retention_rate_90d)::numeric,2),
         round(avg(c.retention_rate_180d)::numeric,2)
  from engineer_tier_retention_cohorts_r2973 c
  group by c.cohort_quarter, c.tier
  order by c.cohort_quarter, c.tier;
end;$$;

create or replace function r2973_at_risk_engineers()
returns table(engineer_code text, engineer_name text, to_tier text, region text, city text, avg_csat numeric, velocity int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.engineer_code, e.engineer_name, e.to_tier, e.region, e.city,
         e.avg_csat, e.promotion_velocity_score
  from engineer_tier_promotion_events_r2973 e
  where e.retention_status in ('at_risk','churned')
  order by e.promotion_velocity_score asc;
end;$$;

create or replace function r2973_region_promotion_breakdown()
returns table(region text, promotions int, star_performers int, churned int, avg_velocity numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.region,
         count(*)::int,
         (count(*) filter (where e.retention_status='star_performer'))::int,
         (count(*) filter (where e.retention_status='churned'))::int,
         round(avg(e.promotion_velocity_score)::numeric,2)
  from engineer_tier_promotion_events_r2973 e
  group by e.region
  order by count(*) desc;
end;$$;

create or replace function r2973_churn_reasons_top()
returns table(churn_reason text, cohorts int, intervention_recommended text, avg_retention_90 numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.churn_reason,
         count(*)::int,
         max(c.intervention_recommended),
         round(avg(c.retention_rate_90d)::numeric,2)
  from engineer_tier_retention_cohorts_r2973 c
  where c.churn_reason <> 'none'
  group by c.churn_reason
  order by count(*) desc;
end;$$;

create or replace function r2973_top_velocity_promotions()
returns table(engineer_code text, engineer_name text, from_tier text, to_tier text, velocity int, days_in_prior_tier int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.engineer_code, e.engineer_name, e.from_tier, e.to_tier,
         e.promotion_velocity_score, e.days_in_prior_tier
  from engineer_tier_promotion_events_r2973 e
  order by e.promotion_velocity_score desc
  limit 10;
end;$$;

revoke all on function r2973_promotion_velocity_overview() from public, anon;
revoke all on function r2973_tier_transition_matrix() from public, anon;
revoke all on function r2973_retention_cohort_summary() from public, anon;
revoke all on function r2973_at_risk_engineers() from public, anon;
revoke all on function r2973_region_promotion_breakdown() from public, anon;
revoke all on function r2973_churn_reasons_top() from public, anon;
revoke all on function r2973_top_velocity_promotions() from public, anon;

grant execute on function r2973_promotion_velocity_overview() to authenticated;
grant execute on function r2973_tier_transition_matrix() to authenticated;
grant execute on function r2973_retention_cohort_summary() to authenticated;
grant execute on function r2973_at_risk_engineers() to authenticated;
grant execute on function r2973_region_promotion_breakdown() to authenticated;
grant execute on function r2973_churn_reasons_top() to authenticated;
grant execute on function r2973_top_velocity_promotions() to authenticated;
