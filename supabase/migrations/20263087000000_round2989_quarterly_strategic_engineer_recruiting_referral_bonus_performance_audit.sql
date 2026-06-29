-- Round 2989: Founder Quarterly Strategic Engineer-Recruiting Referral Bonus Performance Audit
-- Two tables + 7 RPCs, is_founder gated, RLS enabled.

create table if not exists engineer_recruiting_referral_bonuses_r2989 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  quarter_label text not null,
  referrer_name text not null,
  referrer_tier text not null check (referrer_tier in ('founder','platinum','gold','silver','bronze')),
  recruit_name text not null,
  recruit_city text not null,
  recruit_specialty text not null check (recruit_specialty in ('biomedical','radiology','dental','dialysis','imaging','general')),
  bonus_rupees integer not null check (bonus_rupees between 0 and 500000),
  bonus_status text not null check (bonus_status in ('pending','approved','paid','clawback','rejected')),
  recruit_activated_at timestamptz,
  first_job_at timestamptz,
  recruit_quality_score numeric(4,2) not null check (recruit_quality_score between 0 and 10),
  notes text
);

create table if not exists engineer_recruiting_audit_findings_r2989 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  quarter_label text not null,
  finding_category text not null check (finding_category in ('roi_drift','tier_concentration','clawback_risk','quality_dip','geographic_gap','payout_lag')),
  severity text not null check (severity in ('critical','high','medium','low','info')),
  metric_value numeric(10,2) not null,
  threshold_value numeric(10,2) not null,
  status text not null check (status in ('open','triaging','mitigated','accepted','closed')),
  owner text not null,
  recommendation text not null,
  due_date date
);

alter table engineer_recruiting_referral_bonuses_r2989 enable row level security;
alter table engineer_recruiting_audit_findings_r2989 enable row level security;

drop policy if exists bonuses_r2989_founder_select on engineer_recruiting_referral_bonuses_r2989;
create policy bonuses_r2989_founder_select on engineer_recruiting_referral_bonuses_r2989 for select to authenticated using (is_founder());

drop policy if exists findings_r2989_founder_select on engineer_recruiting_audit_findings_r2989;
create policy findings_r2989_founder_select on engineer_recruiting_audit_findings_r2989 for select to authenticated using (is_founder());

-- Seed bonuses (18 rows)
insert into engineer_recruiting_referral_bonuses_r2989
  (quarter_label, referrer_name, referrer_tier, recruit_name, recruit_city, recruit_specialty, bonus_rupees, bonus_status, recruit_activated_at, first_job_at, recruit_quality_score, notes)
values
  ('Q1-2026','Ravi Kumar','platinum','Anil Mehta','Hyderabad','biomedical',15000,'paid','2026-01-12'::timestamptz,'2026-01-20'::timestamptz,8.4,'Strong first quarter'),
  ('Q1-2026','Suresh Naidu','gold','Pradeep Rao','Bangalore','radiology',12000,'paid','2026-01-18'::timestamptz,'2026-01-25'::timestamptz,7.9,'Solid recruit'),
  ('Q1-2026','Priya Shah','silver','Vinod Singh','Mumbai','dental',8000,'paid','2026-02-02'::timestamptz,'2026-02-10'::timestamptz,7.2,'Quick activation'),
  ('Q1-2026','Ravi Kumar','platinum','Karthik Iyer','Chennai','dialysis',15000,'pending',null,null,6.8,'Awaiting first job'),
  ('Q1-2026','Founder','founder','Manoj Pillai','Kochi','imaging',20000,'approved','2026-02-15'::timestamptz,'2026-02-22'::timestamptz,9.1,'Founder-sourced'),
  ('Q1-2026','Geeta Nair','bronze','Rakesh Joshi','Pune','general',5000,'clawback','2026-01-05'::timestamptz,'2026-01-12'::timestamptz,4.1,'Quality dip - clawback'),
  ('Q1-2026','Suresh Naidu','gold','Deepak Verma','Delhi','biomedical',12000,'paid','2026-02-25'::timestamptz,'2026-03-01'::timestamptz,8.0,'On track'),
  ('Q1-2026','Priya Shah','silver','Amit Sharma','Ahmedabad','radiology',8000,'rejected',null,null,3.5,'Rejected - poor onboarding'),
  ('Q1-2026','Ravi Kumar','platinum','Sunil Reddy','Vijayawada','dental',15000,'paid','2026-03-05'::timestamptz,'2026-03-10'::timestamptz,8.6,'Quality recruit'),
  ('Q1-2026','Geeta Nair','bronze','Harish Menon','Trivandrum','general',5000,'pending',null,null,6.5,'New'),
  ('Q4-2025','Ravi Kumar','platinum','Vivek Patil','Hyderabad','biomedical',15000,'paid','2025-10-15'::timestamptz,'2025-10-22'::timestamptz,8.8,'Top performer'),
  ('Q4-2025','Suresh Naidu','gold','Naveen Krishnan','Bangalore','imaging',12000,'paid','2025-11-02'::timestamptz,'2025-11-09'::timestamptz,7.7,'Steady'),
  ('Q4-2025','Founder','founder','Ramesh Babu','Hyderabad','radiology',20000,'paid','2025-10-28'::timestamptz,'2025-11-04'::timestamptz,9.3,'Excellent'),
  ('Q4-2025','Priya Shah','silver','Sandeep Joshi','Mumbai','dialysis',8000,'clawback','2025-11-15'::timestamptz,'2025-11-20'::timestamptz,3.9,'Clawback - poor quality'),
  ('Q4-2025','Geeta Nair','bronze','Mahesh Pillai','Pune','dental',5000,'paid','2025-12-01'::timestamptz,'2025-12-08'::timestamptz,7.0,'OK'),
  ('Q3-2025','Ravi Kumar','platinum','Sanjay Gupta','Hyderabad','general',15000,'paid','2025-07-12'::timestamptz,'2025-07-20'::timestamptz,8.2,'Reliable'),
  ('Q3-2025','Suresh Naidu','gold','Arjun Das','Bangalore','biomedical',12000,'paid','2025-08-05'::timestamptz,'2025-08-12'::timestamptz,7.6,'Good'),
  ('Q3-2025','Founder','founder','Kiran Bhatia','Delhi','radiology',20000,'paid','2025-09-01'::timestamptz,'2025-09-08'::timestamptz,9.0,'Strategic hire');

-- Seed findings (14 rows)
insert into engineer_recruiting_audit_findings_r2989
  (quarter_label, finding_category, severity, metric_value, threshold_value, status, owner, recommendation, due_date)
values
  ('Q1-2026','roi_drift','high',2.40,3.50,'open','Founder','Tighten bonus payout to quality-gated recruits only','2026-04-30'::date),
  ('Q1-2026','tier_concentration','medium',62.50,50.00,'triaging','Ops','Diversify referrer tiers - platinum over-weighted','2026-05-15'::date),
  ('Q1-2026','clawback_risk','critical',16.67,10.00,'open','Founder','Clawback rate above red-line','2026-04-20'::date),
  ('Q1-2026','quality_dip','high',6.40,7.50,'triaging','Ops','Avg quality score dropped below threshold','2026-05-01'::date),
  ('Q1-2026','geographic_gap','medium',3.00,5.00,'open','Growth','No recruits in NE / east India','2026-06-01'::date),
  ('Q1-2026','payout_lag','low',12.00,7.00,'mitigated','Finance','Bonus payout cycle reduced to weekly','2026-04-10'::date),
  ('Q4-2025','roi_drift','medium',3.10,3.50,'closed','Founder','Q4 ROI fixed via tier-bonus realignment',null),
  ('Q4-2025','clawback_risk','high',20.00,10.00,'closed','Founder','Q4 clawback addressed - quality gates added',null),
  ('Q4-2025','tier_concentration','low',45.00,50.00,'accepted','Ops','Within tolerance',null),
  ('Q4-2025','quality_dip','medium',7.30,7.50,'mitigated','Ops','Onboarding revamped Q4',null),
  ('Q3-2025','geographic_gap','high',2.00,5.00,'closed','Growth','Q3 - 3 new metros added',null),
  ('Q3-2025','payout_lag','medium',14.00,7.00,'closed','Finance','Payout SLA improved',null),
  ('Q3-2025','roi_drift','info',4.20,3.50,'closed','Founder','Healthy ROI',null),
  ('Q1-2026','tier_concentration','info',12.50,50.00,'open','Ops','Founder-sourced tier diversification check','2026-05-30'::date);

-- RPC 1: quarterly bonus summary
create or replace function rpc_r2989_quarterly_bonus_summary()
returns table (quarter_label text, total_bonus_rupees bigint, paid_count int, pending_count int, clawback_count int, avg_quality numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.quarter_label,
         sum(b.bonus_rupees)::bigint,
         (count(*) filter (where b.bonus_status = 'paid'))::int,
         (count(*) filter (where b.bonus_status = 'pending'))::int,
         (count(*) filter (where b.bonus_status = 'clawback'))::int,
         round(avg(b.recruit_quality_score)::numeric, 2)
  from engineer_recruiting_referral_bonuses_r2989 b
  group by b.quarter_label
  order by b.quarter_label desc;
end $$;

-- RPC 2: tier leaderboard
create or replace function rpc_r2989_tier_leaderboard()
returns table (referrer_tier text, referrer_count int, total_bonus_rupees bigint, avg_quality numeric, paid_share_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.referrer_tier,
         count(distinct b.referrer_name)::int,
         sum(b.bonus_rupees)::bigint,
         round(avg(b.recruit_quality_score)::numeric, 2),
         round((100.0 * (count(*) filter (where b.bonus_status = 'paid'))::numeric / nullif(count(*),0)), 1)
  from engineer_recruiting_referral_bonuses_r2989 b
  group by b.referrer_tier
  order by sum(b.bonus_rupees) desc;
end $$;

-- RPC 3: specialty distribution
create or replace function rpc_r2989_specialty_distribution()
returns table (recruit_specialty text, recruit_count int, avg_bonus_rupees numeric, avg_quality numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.recruit_specialty,
         count(*)::int,
         round(avg(b.bonus_rupees)::numeric, 0),
         round(avg(b.recruit_quality_score)::numeric, 2)
  from engineer_recruiting_referral_bonuses_r2989 b
  group by b.recruit_specialty
  order by count(*) desc;
end $$;

-- RPC 4: clawback risk roster
create or replace function rpc_r2989_clawback_risk_roster()
returns table (quarter_label text, referrer_name text, recruit_name text, recruit_city text, quality_score numeric, bonus_rupees int, bonus_status text)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.quarter_label, b.referrer_name, b.recruit_name, b.recruit_city,
         b.recruit_quality_score, b.bonus_rupees, b.bonus_status
  from engineer_recruiting_referral_bonuses_r2989 b
  where b.recruit_quality_score < 7.0 or b.bonus_status in ('clawback','rejected')
  order by b.recruit_quality_score asc;
end $$;

-- RPC 5: open audit findings
create or replace function rpc_r2989_open_audit_findings()
returns table (quarter_label text, finding_category text, severity text, metric_value numeric, threshold_value numeric, status text, owner text, recommendation text, due_date date)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.quarter_label, f.finding_category, f.severity, f.metric_value, f.threshold_value, f.status, f.owner, f.recommendation, f.due_date
  from engineer_recruiting_audit_findings_r2989 f
  where f.status in ('open','triaging')
  order by case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 when 'low' then 4 else 5 end;
end $$;

-- RPC 6: severity rollup
create or replace function rpc_r2989_severity_rollup()
returns table (severity text, open_count int, mitigated_count int, closed_count int, total_count int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.severity,
         (count(*) filter (where f.status in ('open','triaging')))::int,
         (count(*) filter (where f.status = 'mitigated'))::int,
         (count(*) filter (where f.status in ('closed','accepted')))::int,
         count(*)::int
  from engineer_recruiting_audit_findings_r2989 f
  group by f.severity
  order by case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 when 'low' then 4 else 5 end;
end $$;

-- RPC 7: top referrers
create or replace function rpc_r2989_top_referrers()
returns table (referrer_name text, referrer_tier text, recruit_count int, total_bonus_rupees bigint, avg_quality numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.referrer_name, max(b.referrer_tier),
         count(*)::int,
         sum(b.bonus_rupees)::bigint,
         round(avg(b.recruit_quality_score)::numeric, 2)
  from engineer_recruiting_referral_bonuses_r2989 b
  group by b.referrer_name
  order by sum(b.bonus_rupees) desc
  limit 10;
end $$;

revoke all on function rpc_r2989_quarterly_bonus_summary() from public, anon;
revoke all on function rpc_r2989_tier_leaderboard() from public, anon;
revoke all on function rpc_r2989_specialty_distribution() from public, anon;
revoke all on function rpc_r2989_clawback_risk_roster() from public, anon;
revoke all on function rpc_r2989_open_audit_findings() from public, anon;
revoke all on function rpc_r2989_severity_rollup() from public, anon;
revoke all on function rpc_r2989_top_referrers() from public, anon;

grant execute on function rpc_r2989_quarterly_bonus_summary() to authenticated;
grant execute on function rpc_r2989_tier_leaderboard() to authenticated;
grant execute on function rpc_r2989_specialty_distribution() to authenticated;
grant execute on function rpc_r2989_clawback_risk_roster() to authenticated;
grant execute on function rpc_r2989_open_audit_findings() to authenticated;
grant execute on function rpc_r2989_severity_rollup() to authenticated;
grant execute on function rpc_r2989_top_referrers() to authenticated;
