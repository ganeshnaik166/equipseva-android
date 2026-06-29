-- Round 2980: Customer Monthly Engineer-Initiated Hospital BMW Color-Code Disposal Coaching
-- Heavy ★★★★ — 2 tables (_r2980) + 7 RPCs (is_founder gated)

create table if not exists customer_bmw_color_coaching_sessions_r2980 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_org_id uuid,
  hospital_name text not null,
  engineer_user_id uuid,
  engineer_name text not null,
  session_month date not null,
  color_code text not null check (color_code in ('yellow','red','blue','white','black')),
  waste_category text not null check (waste_category in ('infectious','sharps','glass','cytotoxic','general','chemical')),
  staff_trained_count int not null check (staff_trained_count > 0),
  pre_score numeric(5,2) not null check (pre_score >= 0 and pre_score <= 100),
  post_score numeric(5,2) not null check (post_score >= 0 and post_score <= 100),
  segregation_compliance_pct numeric(5,2) not null check (segregation_compliance_pct >= 0 and segregation_compliance_pct <= 100),
  session_duration_minutes int not null check (session_duration_minutes > 0),
  initiated_by_engineer boolean not null default true,
  coaching_status text not null check (coaching_status in ('scheduled','in_progress','completed','follow_up','escalated')),
  cpcb_compliant boolean not null default false,
  notes text
);

alter table customer_bmw_color_coaching_sessions_r2980 enable row level security;

drop policy if exists pol_bmw_coach_r2980_sel on customer_bmw_color_coaching_sessions_r2980;
create policy pol_bmw_coach_r2980_sel on customer_bmw_color_coaching_sessions_r2980 for select to authenticated using (is_founder());

create table if not exists customer_bmw_disposal_audits_r2980 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  session_id uuid references customer_bmw_color_coaching_sessions_r2980(id) on delete set null,
  hospital_name text not null,
  audit_date date not null,
  yellow_bin_kg numeric(8,2) not null check (yellow_bin_kg >= 0),
  red_bin_kg numeric(8,2) not null check (red_bin_kg >= 0),
  blue_bin_kg numeric(8,2) not null check (blue_bin_kg >= 0),
  white_bin_kg numeric(8,2) not null check (white_bin_kg >= 0),
  black_bin_kg numeric(8,2) not null check (black_bin_kg >= 0),
  mis_segregation_incidents int not null default 0 check (mis_segregation_incidents >= 0),
  cpcb_penalty_risk text not null check (cpcb_penalty_risk in ('none','low','medium','high','critical')),
  auditor_rating int not null check (auditor_rating between 1 and 5),
  follow_up_required boolean not null default false
);

alter table customer_bmw_disposal_audits_r2980 enable row level security;

drop policy if exists pol_bmw_audit_r2980_sel on customer_bmw_disposal_audits_r2980;
create policy pol_bmw_audit_r2980_sel on customer_bmw_disposal_audits_r2980 for select to authenticated using (is_founder());

-- Seed sessions (18 rows)
insert into customer_bmw_color_coaching_sessions_r2980
  (hospital_name, engineer_name, session_month, color_code, waste_category, staff_trained_count, pre_score, post_score, segregation_compliance_pct, session_duration_minutes, coaching_status, cpcb_compliant, notes)
values
  ('Apollo Hyderabad','Ravi Kumar','2026-06-01'::date,'yellow','infectious',18,42.50,88.00,92.30,75,'completed',true,'Excellent improvement in surgical waste handling'),
  ('Yashoda Secunderabad','Suresh Reddy','2026-06-01'::date,'red','infectious',22,55.00,91.50,94.10,90,'completed',true,'IV tubing segregation now perfect'),
  ('Continental Hospitals','Priya Sharma','2026-06-01'::date,'blue','glass',15,38.00,82.50,87.20,60,'completed',true,'Glass vial separation improved'),
  ('KIMS Kondapur','Anil Verma','2026-06-01'::date,'white','sharps',20,48.50,93.00,96.50,80,'completed',true,'Sharps puncture-proof container adoption'),
  ('Care Hospitals Banjara','Manoj Patel','2026-06-01'::date,'yellow','infectious',12,45.00,85.50,89.40,70,'follow_up',false,'Needs reinforcement on autoclave staging'),
  ('Star Hospitals','Deepak Singh','2026-06-01'::date,'red','infectious',16,52.00,87.00,90.10,65,'completed',true,'Catheter disposal protocol clear'),
  ('Sunshine Hospitals','Vikram Joshi','2026-06-01'::date,'black','chemical',10,30.00,75.00,82.00,55,'follow_up',false,'Chemical waste needs PPE refresher'),
  ('Rainbow Childrens','Kavita Iyer','2026-06-01'::date,'yellow','infectious',14,58.00,92.00,95.30,85,'completed',true,'Paediatric ward exemplary'),
  ('Medicover Hitech','Ramesh Naidu','2026-06-01'::date,'white','sharps',19,40.00,86.00,91.20,75,'completed',true,'Needle recap practice eliminated'),
  ('Aware Gleneagles','Sunita Rao','2026-06-01'::date,'blue','glass',11,35.50,78.00,84.50,50,'follow_up',true,'Ampoule disposal needs work'),
  ('Citizens Hospital','Arjun Mehta','2026-06-01'::date,'yellow','cytotoxic',8,28.00,72.00,80.00,90,'escalated',false,'Cytotoxic handling — escalated to CPCB'),
  ('Pace Hospital','Geeta Pillai','2026-06-01'::date,'red','infectious',17,50.00,89.50,92.80,70,'completed',true,'Blood bag handling standardised'),
  ('Virinchi Hospitals','Nitin Bansal','2026-06-01'::date,'white','sharps',21,46.00,90.00,93.40,80,'completed',true,'Scalpel disposal procedure adopted'),
  ('Olive Hospital','Pooja Malhotra','2026-06-01'::date,'yellow','infectious',13,43.50,84.00,88.10,65,'completed',true,'Gauze + dressing protocol updated'),
  ('Maxcure Hospitals','Sandeep Kapoor','2026-06-01'::date,'black','chemical',9,32.00,76.50,83.20,60,'follow_up',true,'Formalin disposal coached'),
  ('Continental Nallagandla','Lakshmi Devi','2026-06-01'::date,'blue','glass',12,37.00,81.00,86.40,55,'completed',true,'Lab glassware procedure clear'),
  ('Apollo DRDO','Harish Goud','2026-06-01'::date,'red','infectious',20,54.00,90.50,93.70,85,'completed',true,'OT waste streaming exemplar'),
  ('Yashoda Malakpet','Bhavna Shah','2026-06-01'::date,'yellow','infectious',15,47.50,86.50,90.00,75,'completed',true,'Bedside segregation training');

-- Seed audits (16 rows)
insert into customer_bmw_disposal_audits_r2980
  (hospital_name, audit_date, yellow_bin_kg, red_bin_kg, blue_bin_kg, white_bin_kg, black_bin_kg, mis_segregation_incidents, cpcb_penalty_risk, auditor_rating, follow_up_required)
values
  ('Apollo Hyderabad','2026-06-15'::date,142.50,88.20,32.10,18.50,12.40,1,'low',5,false),
  ('Yashoda Secunderabad','2026-06-15'::date,168.30,105.40,38.50,22.30,15.20,2,'low',5,false),
  ('Continental Hospitals','2026-06-15'::date,98.40,62.50,24.30,14.80,9.50,3,'medium',4,true),
  ('KIMS Kondapur','2026-06-15'::date,155.20,92.10,35.40,26.40,13.80,1,'low',5,false),
  ('Care Hospitals Banjara','2026-06-15'::date,82.50,58.30,21.40,12.50,8.20,5,'medium',3,true),
  ('Star Hospitals','2026-06-15'::date,118.40,72.50,28.30,16.20,11.10,2,'low',4,false),
  ('Sunshine Hospitals','2026-06-15'::date,72.30,48.20,18.50,10.30,18.40,7,'high',3,true),
  ('Rainbow Childrens','2026-06-15'::date,108.50,68.40,26.20,15.50,9.80,1,'none',5,false),
  ('Medicover Hitech','2026-06-15'::date,132.40,82.50,31.40,22.30,12.50,2,'low',4,false),
  ('Aware Gleneagles','2026-06-15'::date,68.50,42.30,22.50,11.40,7.80,4,'medium',3,true),
  ('Citizens Hospital','2026-06-15'::date,58.40,38.20,16.30,9.50,12.40,9,'critical',2,true),
  ('Pace Hospital','2026-06-15'::date,112.50,72.40,28.50,15.30,10.20,2,'low',4,false),
  ('Virinchi Hospitals','2026-06-15'::date,148.30,88.50,34.20,24.10,13.50,1,'low',5,false),
  ('Olive Hospital','2026-06-15'::date,92.40,58.30,22.40,13.50,8.50,3,'medium',4,true),
  ('Maxcure Hospitals','2026-06-15'::date,68.20,42.50,18.30,10.80,14.50,5,'medium',3,true),
  ('Apollo DRDO','2026-06-15'::date,158.40,98.50,36.40,25.20,14.30,1,'none',5,false);

-- RPC 1: monthly compliance summary
create or replace function rpc_r2980_monthly_compliance_summary()
returns table (
  session_month date,
  total_sessions int,
  hospitals_covered int,
  avg_segregation_compliance numeric,
  cpcb_compliant_count int,
  escalated_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select s.session_month,
           count(*)::int,
           count(distinct s.hospital_name)::int,
           round(avg(s.segregation_compliance_pct),2),
           (count(*) filter (where s.cpcb_compliant))::int,
           (count(*) filter (where s.coaching_status = 'escalated'))::int
      from customer_bmw_color_coaching_sessions_r2980 s
     group by s.session_month
     order by s.session_month desc;
end$$;

revoke all on function rpc_r2980_monthly_compliance_summary() from public, anon;
grant execute on function rpc_r2980_monthly_compliance_summary() to authenticated;

-- RPC 2: engineer coaching leaderboard
create or replace function rpc_r2980_engineer_leaderboard()
returns table (
  engineer_name text,
  sessions_initiated int,
  staff_trained_total int,
  avg_score_delta numeric,
  avg_post_score numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select s.engineer_name,
           count(*)::int,
           sum(s.staff_trained_count)::int,
           round(avg(s.post_score - s.pre_score),2),
           round(avg(s.post_score),2)
      from customer_bmw_color_coaching_sessions_r2980 s
     where s.initiated_by_engineer
     group by s.engineer_name
     order by avg(s.post_score - s.pre_score) desc;
end$$;

revoke all on function rpc_r2980_engineer_leaderboard() from public, anon;
grant execute on function rpc_r2980_engineer_leaderboard() to authenticated;

-- RPC 3: color-code breakdown
create or replace function rpc_r2980_color_code_breakdown()
returns table (
  color_code text,
  session_count int,
  staff_trained int,
  avg_compliance numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select s.color_code,
           count(*)::int,
           sum(s.staff_trained_count)::int,
           round(avg(s.segregation_compliance_pct),2),
           round(100.0 * (count(*) filter (where s.cpcb_compliant))::numeric / nullif(count(*),0), 2)
      from customer_bmw_color_coaching_sessions_r2980 s
     group by s.color_code
     order by count(*) desc;
end$$;

revoke all on function rpc_r2980_color_code_breakdown() from public, anon;
grant execute on function rpc_r2980_color_code_breakdown() to authenticated;

-- RPC 4: hospital risk roster
create or replace function rpc_r2980_hospital_risk_roster()
returns table (
  hospital_name text,
  total_waste_kg numeric,
  mis_segregation_total int,
  highest_risk text,
  avg_rating numeric,
  follow_up_required boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select a.hospital_name,
           round(sum(a.yellow_bin_kg + a.red_bin_kg + a.blue_bin_kg + a.white_bin_kg + a.black_bin_kg),2),
           sum(a.mis_segregation_incidents)::int,
           max(a.cpcb_penalty_risk),
           round(avg(a.auditor_rating)::numeric,2),
           bool_or(a.follow_up_required)
      from customer_bmw_disposal_audits_r2980 a
     group by a.hospital_name
     order by sum(a.mis_segregation_incidents) desc;
end$$;

revoke all on function rpc_r2980_hospital_risk_roster() from public, anon;
grant execute on function rpc_r2980_hospital_risk_roster() to authenticated;

-- RPC 5: waste category mix
create or replace function rpc_r2980_waste_category_mix()
returns table (
  waste_category text,
  sessions int,
  avg_duration_minutes numeric,
  avg_post_score numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select s.waste_category,
           count(*)::int,
           round(avg(s.session_duration_minutes)::numeric,1),
           round(avg(s.post_score),2)
      from customer_bmw_color_coaching_sessions_r2980 s
     group by s.waste_category
     order by count(*) desc;
end$$;

revoke all on function rpc_r2980_waste_category_mix() from public, anon;
grant execute on function rpc_r2980_waste_category_mix() to authenticated;

-- RPC 6: cpcb penalty exposure
create or replace function rpc_r2980_cpcb_penalty_exposure()
returns table (
  penalty_risk text,
  hospital_count int,
  total_waste_kg numeric,
  follow_ups_open int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select a.cpcb_penalty_risk,
           count(distinct a.hospital_name)::int,
           round(sum(a.yellow_bin_kg + a.red_bin_kg + a.blue_bin_kg + a.white_bin_kg + a.black_bin_kg),2),
           (count(*) filter (where a.follow_up_required))::int
      from customer_bmw_disposal_audits_r2980 a
     group by a.cpcb_penalty_risk
     order by count(*) desc;
end$$;

revoke all on function rpc_r2980_cpcb_penalty_exposure() from public, anon;
grant execute on function rpc_r2980_cpcb_penalty_exposure() to authenticated;

-- RPC 7: training impact deltas
create or replace function rpc_r2980_training_impact()
returns table (
  hospital_name text,
  pre_avg numeric,
  post_avg numeric,
  delta numeric,
  staff_trained int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select s.hospital_name,
           round(avg(s.pre_score),2),
           round(avg(s.post_score),2),
           round(avg(s.post_score - s.pre_score),2),
           sum(s.staff_trained_count)::int
      from customer_bmw_color_coaching_sessions_r2980 s
     group by s.hospital_name
     order by avg(s.post_score - s.pre_score) desc;
end$$;

revoke all on function rpc_r2980_training_impact() from public, anon;
grant execute on function rpc_r2980_training_impact() to authenticated;
