-- Round 3029 — Founder Quarterly Strategic Engineering Conference Sponsorship & Booth ROI Audit
-- HEAVY ★★★★

create table if not exists conference_sponsorships_r3029 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  conference_name text not null,
  host_org text not null,
  city text not null,
  start_date date not null,
  end_date date not null,
  tier text not null check (tier in ('platinum','gold','silver','bronze','community')),
  sponsorship_fee_rupees bigint not null check (sponsorship_fee_rupees >= 0),
  booth_build_cost_rupees bigint not null check (booth_build_cost_rupees >= 0),
  travel_lodging_rupees bigint not null check (travel_lodging_rupees >= 0),
  swag_collateral_rupees bigint not null check (swag_collateral_rupees >= 0),
  total_invested_rupees bigint not null check (total_invested_rupees >= 0),
  badge_scans int not null check (badge_scans >= 0),
  qualified_meetings int not null check (qualified_meetings >= 0),
  pipeline_generated_rupees bigint not null check (pipeline_generated_rupees >= 0),
  closed_won_rupees bigint not null check (closed_won_rupees >= 0),
  roi_multiple numeric(6,2) not null check (roi_multiple >= 0),
  payback_days int check (payback_days >= 0),
  nps_score int check (nps_score between -100 and 100),
  status text not null check (status in ('planned','contracted','live','wrapped','audited','cancelled')),
  notes text
);

create table if not exists conference_booth_activities_r3029 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  sponsorship_id uuid not null references conference_sponsorships_r3029(id) on delete cascade,
  day_index int not null check (day_index between 1 and 5),
  activity_date date not null,
  hours_staffed numeric(4,1) not null check (hours_staffed >= 0 and hours_staffed <= 24),
  demos_run int not null check (demos_run >= 0),
  hot_leads int not null check (hot_leads >= 0),
  warm_leads int not null check (warm_leads >= 0),
  cold_scans int not null check (cold_scans >= 0),
  social_mentions int not null check (social_mentions >= 0),
  swag_distributed int not null check (swag_distributed >= 0),
  cost_per_lead_rupees int check (cost_per_lead_rupees >= 0),
  staff_engineers_present int not null check (staff_engineers_present >= 0),
  competitor_booth_distance_m int check (competitor_booth_distance_m >= 0),
  rating int check (rating between 1 and 5),
  recap_note text
);

alter table conference_sponsorships_r3029 enable row level security;
alter table conference_booth_activities_r3029 enable row level security;

drop policy if exists r3029_sp_sel on conference_sponsorships_r3029;
create policy r3029_sp_sel on conference_sponsorships_r3029 for select using (is_founder());
drop policy if exists r3029_act_sel on conference_booth_activities_r3029;
create policy r3029_act_sel on conference_booth_activities_r3029 for select using (is_founder());

-- Seed sponsorships (16 rows)
insert into conference_sponsorships_r3029
(conference_name, host_org, city, start_date, end_date, tier, sponsorship_fee_rupees, booth_build_cost_rupees, travel_lodging_rupees, swag_collateral_rupees, total_invested_rupees, badge_scans, qualified_meetings, pipeline_generated_rupees, closed_won_rupees, roi_multiple, payback_days, nps_score, status, notes) values
('MedTech India Summit Q1', 'AdvaMed India', 'Mumbai', '2026-01-14'::date, '2026-01-16'::date, 'platinum', 1800000, 650000, 420000, 180000, 3050000, 1240, 84, 18400000, 6200000, 2.03, 92, 62, 'audited', 'Anchor sponsor, keynote slot landed AIIMS lead'),
('Hospital CIO Forum', 'IHCC', 'Bengaluru', '2026-02-04'::date, '2026-02-05'::date, 'gold', 950000, 280000, 180000, 90000, 1500000, 612, 47, 8600000, 2400000, 1.60, 140, 48, 'audited', 'Tier-2 hospital CIO pipeline strong'),
('Biomedical Engineers Congress', 'BMESI', 'Hyderabad', '2026-02-18'::date, '2026-02-20'::date, 'gold', 850000, 240000, 140000, 70000, 1300000, 980, 62, 6800000, 1900000, 1.46, 168, 55, 'audited', 'Engineer recruiting wins'),
('AMC Vendor Expo', 'FIMHO', 'Chennai', '2026-03-03'::date, '2026-03-04'::date, 'silver', 480000, 160000, 110000, 50000, 800000, 410, 31, 4200000, 1100000, 1.38, 182, 41, 'audited', 'Solid AMC tier discovery'),
('Radiology India 2026', 'IRIA', 'New Delhi', '2026-03-12'::date, '2026-03-15'::date, 'platinum', 2200000, 720000, 480000, 200000, 3600000, 1480, 96, 22600000, 8400000, 2.33, 78, 71, 'audited', 'Best ROI Q1; expanded modality demo'),
('Cath Lab Symposium', 'CSI', 'Pune', '2026-04-08'::date, '2026-04-10'::date, 'gold', 980000, 290000, 200000, 95000, 1565000, 720, 54, 9200000, 2800000, 1.79, 124, 58, 'audited', 'Cardiology vertical traction'),
('Tier-2 Hospital Conclave', 'AHPI', 'Indore', '2026-04-22'::date, '2026-04-23'::date, 'silver', 420000, 140000, 95000, 45000, 700000, 380, 28, 3600000, 920000, 1.31, 198, 39, 'audited', 'Tier-2 outreach valuable but slow close'),
('Dental Equipment Show', 'IDA', 'Ahmedabad', '2026-05-06'::date, '2026-05-08'::date, 'silver', 510000, 170000, 120000, 60000, 860000, 460, 36, 4400000, 1300000, 1.51, 162, 52, 'audited', 'Dental vertical pilot ROI'),
('Pediatric MedTech Meet', 'IAP', 'Kolkata', '2026-05-20'::date, '2026-05-21'::date, 'bronze', 280000, 90000, 70000, 30000, 470000, 220, 18, 1800000, 380000, 0.81, null, 28, 'audited', 'Underperformer; small TAM'),
('Engineering Talent Job Fair', 'IIT-M', 'Chennai', '2026-06-04'::date, '2026-06-05'::date, 'community', 120000, 40000, 35000, 25000, 220000, 880, 0, 0, 0, 0.00, null, 64, 'wrapped', 'Talent only; 14 offers extended'),
('Healthcare Procurement Expo', 'HPI', 'Mumbai', '2026-06-18'::date, '2026-06-20'::date, 'platinum', 2000000, 700000, 460000, 190000, 3350000, 1320, 88, 19800000, 5100000, 1.52, 110, 60, 'live', 'Q2 anchor, awaiting final close-out'),
('Surgical Robotics Forum', 'ISRR', 'Bengaluru', '2026-07-09'::date, '2026-07-11'::date, 'gold', 1100000, 320000, 220000, 100000, 1740000, 0, 0, 0, 0, 0.00, null, null, 'contracted', 'Q3 contracted; booth design pending'),
('Northeast Medical Summit', 'NMS', 'Guwahati', '2026-07-23'::date, '2026-07-24'::date, 'bronze', 220000, 80000, 110000, 28000, 438000, 0, 0, 0, 0, 0.00, null, null, 'planned', 'Greenfield region experiment'),
('IIT Madras Healthcare Hack', 'CFI', 'Chennai', '2026-08-14'::date, '2026-08-16'::date, 'community', 90000, 30000, 25000, 20000, 165000, 0, 0, 0, 0, 0.00, null, null, 'planned', 'Talent + brand'),
('Pharma + MedTech Convergence', 'OPPI', 'Mumbai', '2026-09-10'::date, '2026-09-12'::date, 'gold', 1050000, 310000, 230000, 105000, 1695000, 0, 0, 0, 0, 0.00, null, null, 'planned', 'Cross-vertical bet'),
('Hospital Chain Procurement Day', 'Apollo Group', 'Hyderabad', '2025-11-12'::date, '2025-11-13'::date, 'platinum', 1900000, 680000, 440000, 175000, 3195000, 1180, 78, 16200000, 4800000, 1.50, 132, 58, 'cancelled', 'FY25 — kept for trend baseline');

-- Seed activities (24 rows tied to first 8 audited sponsorships)
with sp as (select id, conference_name from conference_sponsorships_r3029)
insert into conference_booth_activities_r3029
(sponsorship_id, day_index, activity_date, hours_staffed, demos_run, hot_leads, warm_leads, cold_scans, social_mentions, swag_distributed, cost_per_lead_rupees, staff_engineers_present, competitor_booth_distance_m, rating, recap_note)
select sp.id, 1, '2026-01-14'::date, 9.0, 32, 14, 28, 380, 41, 410, 6200, 5, 12, 5, 'Keynote drove huge booth traffic morning of day 1' from sp where sp.conference_name='MedTech India Summit Q1'
union all
select sp.id, 2, '2026-01-15'::date, 9.5, 38, 18, 34, 420, 36, 460, 5400, 5, 12, 5, 'CFO of 4 hospital chains stopped by' from sp where sp.conference_name='MedTech India Summit Q1'
union all
select sp.id, 3, '2026-01-16'::date, 7.0, 24, 9, 19, 280, 22, 290, 7800, 4, 12, 4, 'Tapering attendance; quality stayed high' from sp where sp.conference_name='MedTech India Summit Q1'
union all
select sp.id, 1, '2026-02-04'::date, 8.5, 22, 11, 18, 180, 18, 220, 8200, 4, 18, 4, 'CIO-only floor; quality > quantity' from sp where sp.conference_name='Hospital CIO Forum'
union all
select sp.id, 2, '2026-02-05'::date, 8.0, 18, 8, 14, 140, 14, 180, 9100, 4, 18, 4, 'Day 2 wind-down; demo focused' from sp where sp.conference_name='Hospital CIO Forum'
union all
select sp.id, 1, '2026-02-18'::date, 9.0, 28, 12, 22, 320, 24, 360, 5800, 4, 22, 4, 'Engineers-only crowd, AMC pricing buzz' from sp where sp.conference_name='Biomedical Engineers Congress'
union all
select sp.id, 2, '2026-02-19'::date, 9.0, 30, 14, 24, 340, 28, 380, 5600, 5, 22, 5, 'Engineer recruiting day' from sp where sp.conference_name='Biomedical Engineers Congress'
union all
select sp.id, 3, '2026-02-20'::date, 6.5, 16, 6, 12, 220, 18, 220, 7200, 3, 22, 3, 'Slow finish; competitor pulled stunt' from sp where sp.conference_name='Biomedical Engineers Congress'
union all
select sp.id, 1, '2026-03-03'::date, 8.0, 18, 8, 14, 180, 12, 200, 8800, 3, 14, 4, 'Smaller venue, focused AMC vendors' from sp where sp.conference_name='AMC Vendor Expo'
union all
select sp.id, 2, '2026-03-04'::date, 7.5, 16, 6, 12, 160, 10, 180, 9400, 3, 14, 3, 'Final-day discount talk dominated' from sp where sp.conference_name='AMC Vendor Expo'
union all
select sp.id, 1, '2026-03-12'::date, 9.5, 36, 18, 30, 420, 48, 480, 5200, 6, 8, 5, 'IRIA opening day record' from sp where sp.conference_name='Radiology India 2026'
union all
select sp.id, 2, '2026-03-13'::date, 9.5, 40, 22, 36, 440, 52, 520, 4800, 6, 8, 5, 'Highest demo throughput ever' from sp where sp.conference_name='Radiology India 2026'
union all
select sp.id, 3, '2026-03-14'::date, 9.0, 34, 16, 28, 380, 38, 420, 5400, 6, 8, 5, 'CT/MR modality demos popular' from sp where sp.conference_name='Radiology India 2026'
union all
select sp.id, 4, '2026-03-15'::date, 7.0, 22, 8, 18, 240, 26, 280, 7100, 5, 8, 4, 'Wind-down day; closed 3 verbal commits' from sp where sp.conference_name='Radiology India 2026'
union all
select sp.id, 1, '2026-04-08'::date, 8.5, 24, 10, 20, 200, 22, 260, 7400, 4, 16, 4, 'Cath lab heads engaged on uptime SLA' from sp where sp.conference_name='Cath Lab Symposium'
union all
select sp.id, 2, '2026-04-09'::date, 9.0, 28, 12, 22, 220, 26, 280, 6800, 4, 16, 5, 'Live demo of cath lab workflow won crowd' from sp where sp.conference_name='Cath Lab Symposium'
union all
select sp.id, 3, '2026-04-10'::date, 7.0, 20, 8, 16, 180, 18, 220, 7800, 4, 16, 4, 'Last day; networking heavy' from sp where sp.conference_name='Cath Lab Symposium'
union all
select sp.id, 1, '2026-04-22'::date, 8.0, 16, 7, 12, 160, 14, 190, 8900, 3, 12, 4, 'Tier-2 founders open to AMC bundles' from sp where sp.conference_name='Tier-2 Hospital Conclave'
union all
select sp.id, 2, '2026-04-23'::date, 7.5, 14, 5, 10, 140, 12, 170, 9600, 3, 12, 3, 'Smaller turnout day 2' from sp where sp.conference_name='Tier-2 Hospital Conclave'
union all
select sp.id, 1, '2026-05-06'::date, 8.5, 20, 9, 16, 180, 16, 220, 7600, 3, 20, 4, 'Dental chains showing AMC interest' from sp where sp.conference_name='Dental Equipment Show'
union all
select sp.id, 2, '2026-05-07'::date, 9.0, 22, 11, 18, 200, 18, 240, 7100, 3, 20, 4, 'Strongest dental day' from sp where sp.conference_name='Dental Equipment Show'
union all
select sp.id, 3, '2026-05-08'::date, 7.5, 16, 6, 12, 160, 12, 180, 8400, 3, 20, 4, 'Wind-down day' from sp where sp.conference_name='Dental Equipment Show'
union all
select sp.id, 1, '2026-05-20'::date, 8.0, 12, 4, 9, 110, 8, 140, 11200, 2, 28, 3, 'Pediatric niche; small but warm' from sp where sp.conference_name='Pediatric MedTech Meet'
union all
select sp.id, 2, '2026-05-21'::date, 7.0, 10, 3, 7, 90, 6, 110, 12400, 2, 28, 3, 'Underperformed expectations' from sp where sp.conference_name='Pediatric MedTech Meet';

-- RPCs
create or replace function founder_r3029_sponsorships_overview()
returns setof conference_sponsorships_r3029
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query select * from conference_sponsorships_r3029 order by start_date desc;
end;
$$;

create or replace function founder_r3029_roi_leaderboard()
returns table (
  conference_name text,
  city text,
  tier text,
  total_invested_rupees bigint,
  closed_won_rupees bigint,
  roi_multiple numeric,
  payback_days int,
  rank int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select s.conference_name, s.city, s.tier, s.total_invested_rupees, s.closed_won_rupees,
         s.roi_multiple, s.payback_days,
         (row_number() over (order by s.roi_multiple desc))::int as rank
  from conference_sponsorships_r3029 s
  where s.status = 'audited'
  order by s.roi_multiple desc;
end;
$$;

create or replace function founder_r3029_tier_summary()
returns table (
  tier text,
  events int,
  total_invested bigint,
  total_pipeline bigint,
  total_closed bigint,
  avg_roi numeric,
  avg_nps numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select s.tier,
         count(*)::int as events,
         sum(s.total_invested_rupees)::bigint,
         sum(s.pipeline_generated_rupees)::bigint,
         sum(s.closed_won_rupees)::bigint,
         round(avg(s.roi_multiple)::numeric, 2),
         round(avg(s.nps_score)::numeric, 1)
  from conference_sponsorships_r3029 s
  where s.status in ('audited','wrapped','live')
  group by s.tier
  order by sum(s.closed_won_rupees) desc nulls last;
end;
$$;

create or replace function founder_r3029_city_breakdown()
returns table (
  city text,
  events int,
  total_invested bigint,
  total_closed bigint,
  avg_roi numeric,
  audited_events int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select s.city,
         count(*)::int as events,
         sum(s.total_invested_rupees)::bigint,
         sum(s.closed_won_rupees)::bigint,
         round(avg(s.roi_multiple)::numeric, 2),
         (count(*) filter (where s.status = 'audited'))::int as audited_events
  from conference_sponsorships_r3029 s
  group by s.city
  order by sum(s.closed_won_rupees) desc nulls last;
end;
$$;

create or replace function founder_r3029_booth_activity_rollup()
returns table (
  conference_name text,
  total_hours numeric,
  total_demos int,
  total_hot_leads int,
  total_warm_leads int,
  total_scans int,
  avg_rating numeric,
  best_cpl_rupees int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select s.conference_name,
         round(sum(a.hours_staffed)::numeric, 1),
         sum(a.demos_run)::int,
         sum(a.hot_leads)::int,
         sum(a.warm_leads)::int,
         sum(a.cold_scans)::int,
         round(avg(a.rating)::numeric, 2),
         min(a.cost_per_lead_rupees)
  from conference_booth_activities_r3029 a
  join conference_sponsorships_r3029 s on s.id = a.sponsorship_id
  group by s.conference_name
  order by sum(a.hot_leads) desc nulls last;
end;
$$;

create or replace function founder_r3029_underperformers()
returns table (
  conference_name text,
  city text,
  tier text,
  roi_multiple numeric,
  total_invested bigint,
  closed_won bigint,
  reason text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select s.conference_name, s.city, s.tier, s.roi_multiple,
         s.total_invested_rupees, s.closed_won_rupees,
         case
           when s.roi_multiple < 1.0 then 'Negative ROI'
           when s.roi_multiple < 1.5 then 'Below threshold'
           when s.nps_score < 40 then 'Low NPS'
           else 'Watch'
         end as reason
  from conference_sponsorships_r3029 s
  where s.status = 'audited'
    and (s.roi_multiple < 1.5 or s.nps_score < 40)
  order by s.roi_multiple asc;
end;
$$;

create or replace function founder_r3029_pipeline_funnel()
returns table (
  stage text,
  count_value bigint,
  rupee_value bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select 'Badge Scans'::text, sum(s.badge_scans)::bigint, 0::bigint from conference_sponsorships_r3029 s where s.status='audited'
  union all
  select 'Qualified Meetings'::text, sum(s.qualified_meetings)::bigint, 0::bigint from conference_sponsorships_r3029 s where s.status='audited'
  union all
  select 'Pipeline Generated'::text, 0::bigint, sum(s.pipeline_generated_rupees)::bigint from conference_sponsorships_r3029 s where s.status='audited'
  union all
  select 'Closed Won'::text, 0::bigint, sum(s.closed_won_rupees)::bigint from conference_sponsorships_r3029 s where s.status='audited';
end;
$$;

create or replace function founder_r3029_quarter_health()
returns table (
  quarter text,
  events int,
  invested bigint,
  closed_won bigint,
  blended_roi numeric,
  avg_nps numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select to_char(date_trunc('quarter', s.start_date), 'YYYY "Q"Q') as quarter,
         count(*)::int,
         sum(s.total_invested_rupees)::bigint,
         sum(s.closed_won_rupees)::bigint,
         case when sum(s.total_invested_rupees) > 0
              then round((sum(s.closed_won_rupees)::numeric / sum(s.total_invested_rupees)::numeric), 2)
              else 0 end,
         round(avg(s.nps_score)::numeric, 1)
  from conference_sponsorships_r3029 s
  where s.status in ('audited','wrapped','live')
  group by date_trunc('quarter', s.start_date)
  order by date_trunc('quarter', s.start_date) desc;
end;
$$;

revoke all on conference_sponsorships_r3029 from public, anon;
revoke all on conference_booth_activities_r3029 from public, anon;
grant select on conference_sponsorships_r3029 to authenticated;
grant select on conference_booth_activities_r3029 to authenticated;

revoke all on function founder_r3029_sponsorships_overview() from public, anon;
revoke all on function founder_r3029_roi_leaderboard() from public, anon;
revoke all on function founder_r3029_tier_summary() from public, anon;
revoke all on function founder_r3029_city_breakdown() from public, anon;
revoke all on function founder_r3029_booth_activity_rollup() from public, anon;
revoke all on function founder_r3029_underperformers() from public, anon;
revoke all on function founder_r3029_pipeline_funnel() from public, anon;
revoke all on function founder_r3029_quarter_health() from public, anon;

grant execute on function founder_r3029_sponsorships_overview() to authenticated;
grant execute on function founder_r3029_roi_leaderboard() to authenticated;
grant execute on function founder_r3029_tier_summary() to authenticated;
grant execute on function founder_r3029_city_breakdown() to authenticated;
grant execute on function founder_r3029_booth_activity_rollup() to authenticated;
grant execute on function founder_r3029_underperformers() to authenticated;
grant execute on function founder_r3029_pipeline_funnel() to authenticated;
grant execute on function founder_r3029_quarter_health() to authenticated;
