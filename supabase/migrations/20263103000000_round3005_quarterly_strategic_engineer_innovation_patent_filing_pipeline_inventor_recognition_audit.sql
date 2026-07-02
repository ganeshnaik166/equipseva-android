-- Round r3005: Founder Quarterly Strategic Engineer-Innovation Patent-Filing Pipeline & Inventor Recognition Audit

create table if not exists patent_filing_pipeline_r3005 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  invention_title text not null,
  inventor_engineer_id uuid references auth.users(id),
  inventor_name text not null,
  invention_category text not null check (invention_category in ('repair_tool','diagnostic_device','process_method','software_algorithm','spare_part_design','calibration_method')),
  filing_stage text not null check (filing_stage in ('disclosure','novelty_search','draft','provisional_filed','complete_filed','published','granted','abandoned')),
  filing_jurisdiction text not null check (filing_jurisdiction in ('IN','US','EU','PCT','JP','CN')),
  provisional_filed_at date,
  complete_filed_at date,
  granted_at date,
  application_number text,
  filing_cost_rupees int not null default 0,
  estimated_value_rupees bigint not null default 0,
  commercial_potential text not null check (commercial_potential in ('low','medium','high','strategic')),
  attorney_assigned text,
  next_action_due_at date,
  notes text
);

create table if not exists inventor_recognition_audit_r3005 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  engineer_id uuid references auth.users(id),
  engineer_name text not null,
  region text not null check (region in ('north','south','east','west','central')),
  invention_count int not null default 0,
  patents_granted_count int not null default 0,
  recognition_tier text not null check (recognition_tier in ('bronze','silver','gold','platinum','distinguished_inventor')),
  cash_award_rupees int not null default 0,
  equity_grant_units int not null default 0,
  recognition_status text not null check (recognition_status in ('nominated','approved','awarded','pending_review','rejected')),
  hall_of_fame_inducted boolean not null default false,
  total_revenue_impact_rupees bigint not null default 0,
  last_recognition_at date,
  notes text
);

alter table patent_filing_pipeline_r3005 enable row level security;
alter table inventor_recognition_audit_r3005 enable row level security;

drop policy if exists pfp_r3005_founder_all on patent_filing_pipeline_r3005;
create policy pfp_r3005_founder_all on patent_filing_pipeline_r3005 for all using (is_founder()) with check (is_founder());

drop policy if exists ira_r3005_founder_all on inventor_recognition_audit_r3005;
create policy ira_r3005_founder_all on inventor_recognition_audit_r3005 for all using (is_founder()) with check (is_founder());

insert into patent_filing_pipeline_r3005 (invention_title, inventor_name, invention_category, filing_stage, filing_jurisdiction, provisional_filed_at, complete_filed_at, granted_at, application_number, filing_cost_rupees, estimated_value_rupees, commercial_potential, attorney_assigned, next_action_due_at, notes) values
('Self-Calibrating Defibrillator Probe', 'Arjun Mehta', 'diagnostic_device', 'granted', 'IN', '2025-03-15'::date, '2025-09-20'::date, '2026-04-10'::date, 'IN/2025/345678', 185000, 8500000, 'strategic', 'Khaitan & Co', '2026-08-15'::date, 'First granted patent - flagship'),
('Modular Ultrasound Repair Kit', 'Priya Sharma', 'repair_tool', 'complete_filed', 'IN', '2025-06-01'::date, '2026-01-15'::date, null, 'IN/2026/123456', 145000, 4200000, 'high', 'Anand & Anand', '2026-07-20'::date, 'Examination response due'),
('AI-Driven X-Ray Tube Wear Prediction', 'Rajesh Kumar', 'software_algorithm', 'published', 'PCT', '2025-04-22'::date, '2025-11-30'::date, null, 'PCT/IN2025/050678', 425000, 12500000, 'strategic', 'K&S Partners', '2026-09-01'::date, 'PCT national phase imminent'),
('Hospital-Grade ECG Cable Strain Relief', 'Sneha Patel', 'spare_part_design', 'provisional_filed', 'IN', '2026-02-10'::date, null, null, 'IN/2026/PROV/8899', 35000, 1800000, 'medium', 'Khaitan & Co', '2027-02-10'::date, 'Complete spec due in 12 months'),
('Auto-Sterilization Cycle for Endoscopes', 'Vikram Singh', 'process_method', 'draft', 'IN', null, null, null, null, 25000, 6500000, 'high', 'Lakshmikumaran & Sridharan', '2026-07-30'::date, 'Draft review with attorney'),
('Wireless Calibration Beacon for MRI', 'Anita Desai', 'calibration_method', 'novelty_search', 'PCT', null, null, null, null, 75000, 9800000, 'strategic', 'K&S Partners', '2026-08-05'::date, 'Prior art search ongoing'),
('Portable Ventilator Diagnostic Tool', 'Karthik Reddy', 'diagnostic_device', 'complete_filed', 'US', '2025-08-15'::date, '2026-03-01'::date, null, 'US/16/789,012', 850000, 18000000, 'strategic', 'Foley & Lardner', '2026-09-15'::date, 'USPTO office action pending'),
('Predictive Maintenance ML Model for CT', 'Meera Iyer', 'software_algorithm', 'granted', 'IN', '2024-10-01'::date, '2025-05-20'::date, '2026-02-28'::date, 'IN/2024/987654', 195000, 7200000, 'high', 'Anand & Anand', null, 'Granted - licensing potential'),
('Disposable Probe Cover with RFID', 'Suresh Nair', 'spare_part_design', 'disclosure', 'IN', null, null, null, null, 5000, 950000, 'medium', null, '2026-07-10'::date, 'Initial disclosure review'),
('Bio-Compatible Adhesive for Sensors', 'Deepa Krishnan', 'spare_part_design', 'abandoned', 'IN', '2024-08-01'::date, null, null, 'IN/2024/ABDN/1122', 30000, 0, 'low', 'Khaitan & Co', null, 'Prior art too close - abandoned'),
('Smart Surgical Light Auto-Focus', 'Ravi Verma', 'diagnostic_device', 'provisional_filed', 'IN', '2026-01-20'::date, null, null, 'IN/2026/PROV/3344', 45000, 3200000, 'high', 'Anand & Anand', '2027-01-20'::date, 'Complete filing due Jan 2027'),
('Compact Anesthesia Vaporizer Mechanism', 'Lakshmi Pillai', 'spare_part_design', 'complete_filed', 'EU', '2025-09-12'::date, '2026-02-20'::date, null, 'EP25/678901', 1250000, 22000000, 'strategic', 'D Young & Co', '2026-10-05'::date, 'EPO search report awaited'),
('Quick-Release Surgical Camera Mount', 'Anil Kapoor', 'repair_tool', 'draft', 'IN', null, null, null, null, 18000, 1500000, 'medium', 'Lakshmikumaran & Sridharan', '2026-07-25'::date, 'Specs being finalized'),
('Vibration-Damping Patient Bed Wheel', 'Geeta Rao', 'spare_part_design', 'granted', 'IN', '2024-05-10'::date, '2025-01-15'::date, '2025-12-08'::date, 'IN/2024/445566', 165000, 5400000, 'high', 'Khaitan & Co', null, 'Granted - already licensed'),
('Bluetooth Pulse Oximeter Calibrator', 'Mohan Das', 'calibration_method', 'complete_filed', 'IN', '2025-07-08'::date, '2026-04-01'::date, null, 'IN/2026/789012', 155000, 3800000, 'high', 'Anand & Anand', '2026-08-12'::date, 'Examination report under review'),
('Auto-Diagnostic Module for Dialysis', 'Sunita Joshi', 'diagnostic_device', 'novelty_search', 'IN', null, null, null, null, 65000, 8200000, 'strategic', 'K&S Partners', '2026-07-28'::date, 'Search ongoing - promising'),
('Modular Suction Pump Repair Frame', 'Harish Bhat', 'repair_tool', 'provisional_filed', 'IN', '2026-03-05'::date, null, null, 'IN/2026/PROV/5566', 38000, 2100000, 'medium', 'Lakshmikumaran & Sridharan', '2027-03-05'::date, 'Provisional filed'),
('Universal Probe Compatibility Algorithm', 'Vandana Shah', 'software_algorithm', 'published', 'US', '2025-02-18'::date, '2025-10-12'::date, null, 'US/17/234,567', 950000, 15500000, 'strategic', 'Foley & Lardner', '2026-08-22'::date, 'Published - office action awaited');

insert into inventor_recognition_audit_r3005 (engineer_name, region, invention_count, patents_granted_count, recognition_tier, cash_award_rupees, equity_grant_units, recognition_status, hall_of_fame_inducted, total_revenue_impact_rupees, last_recognition_at, notes) values
('Arjun Mehta', 'south', 5, 2, 'distinguished_inventor', 500000, 10000, 'awarded', true, 15000000, '2026-05-01'::date, 'Flagship inventor - 2 grants'),
('Priya Sharma', 'west', 4, 1, 'platinum', 300000, 6000, 'awarded', true, 8500000, '2026-04-15'::date, 'Strong portfolio'),
('Rajesh Kumar', 'north', 3, 1, 'gold', 200000, 4000, 'awarded', false, 6200000, '2026-03-20'::date, 'PCT filing in progress'),
('Sneha Patel', 'west', 2, 0, 'silver', 100000, 2000, 'approved', false, 2800000, '2026-02-10'::date, 'Provisional only so far'),
('Vikram Singh', 'north', 2, 0, 'silver', 100000, 2000, 'pending_review', false, 0, null, 'Pending committee review'),
('Anita Desai', 'west', 3, 0, 'gold', 200000, 4000, 'approved', false, 4500000, '2026-05-15'::date, 'Strategic MRI work'),
('Karthik Reddy', 'south', 4, 1, 'platinum', 300000, 6000, 'awarded', true, 11500000, '2026-04-28'::date, 'US filing complete'),
('Meera Iyer', 'south', 3, 1, 'gold', 200000, 4000, 'awarded', false, 7100000, '2026-03-15'::date, 'CT-ML model granted'),
('Suresh Nair', 'south', 1, 0, 'bronze', 50000, 1000, 'nominated', false, 800000, null, 'First disclosure'),
('Deepa Krishnan', 'south', 1, 0, 'bronze', 25000, 500, 'rejected', false, 0, null, 'Abandoned application'),
('Ravi Verma', 'central', 2, 0, 'silver', 100000, 2000, 'approved', false, 1900000, '2026-06-01'::date, 'Surgical lighting innovation'),
('Lakshmi Pillai', 'south', 5, 0, 'platinum', 350000, 7000, 'awarded', true, 9800000, '2026-05-10'::date, 'EU strategic filing'),
('Anil Kapoor', 'north', 1, 0, 'bronze', 50000, 1000, 'pending_review', false, 600000, null, 'Draft stage'),
('Geeta Rao', 'central', 4, 1, 'platinum', 300000, 6000, 'awarded', true, 8200000, '2026-01-20'::date, 'Already-licensed grant'),
('Mohan Das', 'east', 3, 0, 'gold', 200000, 4000, 'awarded', false, 3500000, '2026-04-05'::date, 'Bluetooth calibrator filed'),
('Sunita Joshi', 'east', 2, 0, 'silver', 100000, 2000, 'approved', false, 4200000, '2026-05-22'::date, 'Dialysis diagnostic strategic'),
('Harish Bhat', 'south', 1, 0, 'bronze', 50000, 1000, 'nominated', false, 700000, null, 'New provisional'),
('Vandana Shah', 'west', 4, 0, 'platinum', 300000, 6000, 'awarded', true, 10200000, '2026-05-30'::date, 'US publication strong');

create or replace function r3005_patent_pipeline_overview()
returns table(filing_stage text, patent_count int, total_filing_cost_rupees bigint, total_estimated_value_rupees bigint, strategic_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    p.filing_stage,
    count(*)::int,
    sum(p.filing_cost_rupees)::bigint,
    sum(p.estimated_value_rupees)::bigint,
    (count(*) filter (where p.commercial_potential = 'strategic'))::int
  from patent_filing_pipeline_r3005 p
  group by p.filing_stage
  order by sum(p.estimated_value_rupees) desc nulls last;
end $$;

create or replace function r3005_jurisdiction_breakdown()
returns table(filing_jurisdiction text, total_filings int, granted_count int, total_cost_rupees bigint, avg_value_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    p.filing_jurisdiction,
    count(*)::int,
    (count(*) filter (where p.filing_stage = 'granted'))::int,
    sum(p.filing_cost_rupees)::bigint,
    (avg(p.estimated_value_rupees))::bigint
  from patent_filing_pipeline_r3005 p
  group by p.filing_jurisdiction
  order by sum(p.filing_cost_rupees) desc;
end $$;

create or replace function r3005_inventor_leaderboard()
returns table(engineer_name text, region text, invention_count int, patents_granted_count int, recognition_tier text, cash_award_rupees int, total_revenue_impact_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.engineer_name, i.region, i.invention_count, i.patents_granted_count, i.recognition_tier, i.cash_award_rupees, i.total_revenue_impact_rupees
  from inventor_recognition_audit_r3005 i
  order by i.total_revenue_impact_rupees desc, i.patents_granted_count desc
  limit 12;
end $$;

create or replace function r3005_recognition_tier_summary()
returns table(recognition_tier text, inventor_count int, total_cash_award_rupees bigint, total_equity_units bigint, hall_of_fame_count int, total_revenue_impact_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    i.recognition_tier,
    count(*)::int,
    sum(i.cash_award_rupees)::bigint,
    sum(i.equity_grant_units)::bigint,
    (count(*) filter (where i.hall_of_fame_inducted = true))::int,
    sum(i.total_revenue_impact_rupees)::bigint
  from inventor_recognition_audit_r3005 i
  group by i.recognition_tier
  order by sum(i.total_revenue_impact_rupees)::bigint desc;
end $$;

create or replace function r3005_upcoming_filing_actions()
returns table(invention_title text, inventor_name text, filing_stage text, next_action_due_at date, days_until_due int, attorney_assigned text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    p.invention_title,
    p.inventor_name,
    p.filing_stage,
    p.next_action_due_at,
    (p.next_action_due_at - current_date)::int,
    p.attorney_assigned
  from patent_filing_pipeline_r3005 p
  where p.next_action_due_at is not null
    and p.next_action_due_at >= current_date
  order by p.next_action_due_at asc
  limit 15;
end $$;

create or replace function r3005_category_value_analysis()
returns table(invention_category text, filing_count int, total_estimated_value_rupees bigint, granted_count int, strategic_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    p.invention_category,
    count(*)::int,
    sum(p.estimated_value_rupees)::bigint,
    (count(*) filter (where p.filing_stage = 'granted'))::int,
    (count(*) filter (where p.commercial_potential = 'strategic'))::int
  from patent_filing_pipeline_r3005 p
  group by p.invention_category
  order by sum(p.estimated_value_rupees) desc;
end $$;

create or replace function r3005_recognition_status_audit()
returns table(recognition_status text, inventor_count int, total_cash_award_rupees bigint, avg_invention_count numeric, pending_review_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    i.recognition_status,
    count(*)::int,
    sum(i.cash_award_rupees)::bigint,
    round(avg(i.invention_count)::numeric, 2),
    (count(*) filter (where i.recognition_status = 'pending_review'))::int
  from inventor_recognition_audit_r3005 i
  group by i.recognition_status
  order by count(*) desc;
end $$;

create or replace function r3005_regional_innovation_map()
returns table(region text, inventor_count int, total_inventions int, total_grants int, hall_of_fame_count int, total_revenue_impact_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    i.region,
    count(*)::int,
    sum(i.invention_count)::int,
    sum(i.patents_granted_count)::int,
    (count(*) filter (where i.hall_of_fame_inducted = true))::int,
    sum(i.total_revenue_impact_rupees)::bigint
  from inventor_recognition_audit_r3005 i
  group by i.region
  order by sum(i.total_revenue_impact_rupees)::bigint desc;
end $$;

revoke all on patent_filing_pipeline_r3005 from public, anon;
revoke all on inventor_recognition_audit_r3005 from public, anon;
grant select, insert, update, delete on patent_filing_pipeline_r3005 to authenticated;
grant select, insert, update, delete on inventor_recognition_audit_r3005 to authenticated;

revoke all on function r3005_patent_pipeline_overview() from public, anon;
revoke all on function r3005_jurisdiction_breakdown() from public, anon;
revoke all on function r3005_inventor_leaderboard() from public, anon;
revoke all on function r3005_recognition_tier_summary() from public, anon;
revoke all on function r3005_upcoming_filing_actions() from public, anon;
revoke all on function r3005_category_value_analysis() from public, anon;
revoke all on function r3005_recognition_status_audit() from public, anon;
revoke all on function r3005_regional_innovation_map() from public, anon;

grant execute on function r3005_patent_pipeline_overview() to authenticated;
grant execute on function r3005_jurisdiction_breakdown() to authenticated;
grant execute on function r3005_inventor_leaderboard() to authenticated;
grant execute on function r3005_recognition_tier_summary() to authenticated;
grant execute on function r3005_upcoming_filing_actions() to authenticated;
grant execute on function r3005_category_value_analysis() to authenticated;
grant execute on function r3005_recognition_status_audit() to authenticated;
grant execute on function r3005_regional_innovation_map() to authenticated;
