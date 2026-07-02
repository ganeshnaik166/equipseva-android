-- Round r3041: Founder Quarterly Strategic Engineer-Driven Customer-Advisory-Board Health & Output Audit

create table if not exists customer_advisory_board_members_r3041 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  member_name text not null,
  hospital_org text not null,
  member_role text not null check (member_role in ('chief_biomed','procurement_head','cfo','coo','clinical_director','facilities_head')),
  city text not null,
  joined_on date not null,
  term_quarters int not null check (term_quarters between 1 and 8),
  engineer_sponsor text not null,
  attendance_rate_pct numeric(5,2) not null check (attendance_rate_pct between 0 and 100),
  contributions_count int not null check (contributions_count between 0 and 200),
  status text not null check (status in ('active','rotating_off','on_leave','alumni'))
);

create table if not exists cab_quarterly_outputs_r3041 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  quarter_label text not null check (quarter_label in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  output_title text not null,
  output_type text not null check (output_type in ('feature_request','policy_change','sla_revision','pricing_input','training_curriculum','vendor_review')),
  driving_engineer text not null,
  proposed_by_member text not null,
  votes_for int not null check (votes_for between 0 and 50),
  votes_against int not null check (votes_against between 0 and 50),
  est_revenue_impact_lakhs numeric(8,2) not null check (est_revenue_impact_lakhs between -50 and 500),
  adoption_status text not null check (adoption_status in ('proposed','under_review','approved','shipped','rejected','deferred')),
  health_score int not null check (health_score between 0 and 100)
);

alter table customer_advisory_board_members_r3041 enable row level security;
alter table cab_quarterly_outputs_r3041 enable row level security;

drop policy if exists cab_members_r3041_founder_select on customer_advisory_board_members_r3041;
create policy cab_members_r3041_founder_select on customer_advisory_board_members_r3041 for select using (is_founder());

drop policy if exists cab_outputs_r3041_founder_select on cab_quarterly_outputs_r3041;
create policy cab_outputs_r3041_founder_select on cab_quarterly_outputs_r3041 for select using (is_founder());

revoke all on customer_advisory_board_members_r3041 from public, anon;
revoke all on cab_quarterly_outputs_r3041 from public, anon;
grant select on customer_advisory_board_members_r3041 to authenticated;
grant select on cab_quarterly_outputs_r3041 to authenticated;

insert into customer_advisory_board_members_r3041 (member_name, hospital_org, member_role, city, joined_on, term_quarters, engineer_sponsor, attendance_rate_pct, contributions_count, status) values
('Dr. Anita Rao','Apollo Hyderabad','chief_biomed','Hyderabad','2026-01-15'::date,4,'Ravi Kumar',95.50,42,'active'),
('Suresh Iyer','Fortis Bangalore','procurement_head','Bangalore','2026-01-20'::date,4,'Priya Menon',88.00,31,'active'),
('Meera Joshi','Manipal Hospitals','cfo','Bangalore','2026-02-01'::date,3,'Arjun Singh',92.30,28,'active'),
('Dr. Vikram Shah','Max Saket','coo','Delhi','2026-02-10'::date,4,'Neha Gupta',76.50,19,'active'),
('Rajeev Pillai','KIMS Trivandrum','clinical_director','Trivandrum','2026-01-08'::date,5,'Ravi Kumar',98.00,55,'active'),
('Sunita Verma','Yashoda Hospitals','facilities_head','Hyderabad','2026-02-15'::date,2,'Priya Menon',81.20,14,'active'),
('Dr. Kiran Bose','Narayana Health','chief_biomed','Bangalore','2025-10-01'::date,6,'Arjun Singh',89.40,67,'rotating_off'),
('Manoj Tiwari','AIIMS Bhubaneswar','procurement_head','Bhubaneswar','2026-03-01'::date,3,'Neha Gupta',73.00,11,'active'),
('Dr. Lalita Menon','Rainbow Childrens','clinical_director','Hyderabad','2026-02-20'::date,4,'Ravi Kumar',94.10,38,'active'),
('Pradeep Nair','Aster Medcity','cfo','Kochi','2026-01-12'::date,4,'Priya Menon',86.70,25,'active'),
('Dr. Harish Gowda','Columbia Asia','coo','Bangalore','2025-12-05'::date,5,'Arjun Singh',79.50,33,'on_leave'),
('Anjali Krishnan','Continental Hospitals','facilities_head','Hyderabad','2026-02-25'::date,3,'Neha Gupta',91.00,22,'active'),
('Dr. Sanjay Kapoor','Medanta Gurgaon','chief_biomed','Gurgaon','2025-09-15'::date,7,'Ravi Kumar',96.80,89,'alumni'),
('Bhavna Desai','Wockhardt Mumbai','procurement_head','Mumbai','2026-03-10'::date,2,'Priya Menon',82.40,9,'active'),
('Dr. Rakesh Patil','Ruby Hall Pune','clinical_director','Pune','2026-01-25'::date,4,'Arjun Singh',87.90,30,'active');

insert into cab_quarterly_outputs_r3041 (quarter_label, output_title, output_type, driving_engineer, proposed_by_member, votes_for, votes_against, est_revenue_impact_lakhs, adoption_status, health_score) values
('Q1-2026','SLA tiered response 2h/4h/8h','sla_revision','Ravi Kumar','Dr. Anita Rao',12,2,45.00,'shipped',92),
('Q1-2026','AMC tier pricing transparency','pricing_input','Priya Menon','Suresh Iyer',10,3,28.50,'shipped',85),
('Q1-2026','MRI breakdown ETA flow','feature_request','Arjun Singh','Meera Joshi',14,0,62.00,'shipped',95),
('Q2-2026','Engineer rotation policy quarterly','policy_change','Neha Gupta','Dr. Vikram Shah',9,4,12.00,'approved',78),
('Q2-2026','Hospital procurement training','training_curriculum','Ravi Kumar','Rajeev Pillai',13,1,38.00,'shipped',90),
('Q2-2026','Spare-part vendor blacklist','vendor_review','Priya Menon','Sunita Verma',11,3,55.00,'approved',82),
('Q2-2026','24x7 oncology equipment SLA','sla_revision','Arjun Singh','Dr. Kiran Bose',15,0,75.50,'shipped',97),
('Q3-2026','Predictive maintenance billing','pricing_input','Neha Gupta','Manoj Tiwari',8,5,42.00,'under_review',68),
('Q3-2026','Pediatric incubator priority queue','feature_request','Ravi Kumar','Dr. Lalita Menon',12,2,33.00,'approved',88),
('Q3-2026','GST invoice consolidation monthly','feature_request','Priya Menon','Pradeep Nair',10,3,18.50,'shipped',80),
('Q3-2026','Engineer attrition early-warning','policy_change','Arjun Singh','Dr. Harish Gowda',7,6,8.00,'deferred',55),
('Q3-2026','Hospital code-red drill quarterly','training_curriculum','Neha Gupta','Anjali Krishnan',13,1,22.00,'approved',86),
('Q4-2026','AMC bundled diagnostics pricing','pricing_input','Ravi Kumar','Dr. Sanjay Kapoor',14,0,95.00,'proposed',91),
('Q4-2026','Cardiology vendor consolidation','vendor_review','Priya Menon','Bhavna Desai',9,4,48.00,'under_review',72),
('Q4-2026','Multi-site SLA dashboard','feature_request','Arjun Singh','Dr. Rakesh Patil',11,2,52.00,'proposed',83),
('Q1-2027','Tier-2 city expansion playbook','policy_change','Ravi Kumar','Dr. Anita Rao',12,1,120.00,'proposed',89);

create or replace function founder_r3041_member_roster()
returns table(member_name text, hospital_org text, member_role text, city text, attendance_rate_pct numeric, contributions_count int, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select m.member_name, m.hospital_org, m.member_role, m.city, m.attendance_rate_pct, m.contributions_count, m.status
    from customer_advisory_board_members_r3041 m order by m.contributions_count desc;
end; $$;

create or replace function founder_r3041_attendance_by_role()
returns table(member_role text, members int, avg_attendance numeric, avg_contributions numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select m.member_role, count(*)::int, round(avg(m.attendance_rate_pct),2), round(avg(m.contributions_count),2)
    from customer_advisory_board_members_r3041 m group by m.member_role order by count(*) desc;
end; $$;

create or replace function founder_r3041_engineer_sponsor_load()
returns table(engineer_sponsor text, members_sponsored int, active_members int, avg_attendance numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select m.engineer_sponsor, count(*)::int,
    (count(*) filter (where m.status='active'))::int,
    round(avg(m.attendance_rate_pct),2)
    from customer_advisory_board_members_r3041 m group by m.engineer_sponsor order by count(*) desc;
end; $$;

create or replace function founder_r3041_quarterly_output_summary()
returns table(quarter_label text, total_outputs int, shipped int, approved int, total_impact_lakhs numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select o.quarter_label, count(*)::int,
    (count(*) filter (where o.adoption_status='shipped'))::int,
    (count(*) filter (where o.adoption_status='approved'))::int,
    round(sum(o.est_revenue_impact_lakhs),2)
    from cab_quarterly_outputs_r3041 o group by o.quarter_label order by o.quarter_label;
end; $$;

create or replace function founder_r3041_output_type_breakdown()
returns table(output_type text, total int, shipped int, avg_health int, total_impact_lakhs numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select o.output_type, count(*)::int,
    (count(*) filter (where o.adoption_status='shipped'))::int,
    round(avg(o.health_score))::int,
    round(sum(o.est_revenue_impact_lakhs),2)
    from cab_quarterly_outputs_r3041 o group by o.output_type order by sum(o.est_revenue_impact_lakhs) desc;
end; $$;

create or replace function founder_r3041_top_outputs_by_impact()
returns table(output_title text, quarter_label text, driving_engineer text, est_revenue_impact_lakhs numeric, adoption_status text, health_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select o.output_title, o.quarter_label, o.driving_engineer, o.est_revenue_impact_lakhs, o.adoption_status, o.health_score
    from cab_quarterly_outputs_r3041 o order by o.est_revenue_impact_lakhs desc limit 10;
end; $$;

create or replace function founder_r3041_board_health_snapshot()
returns table(metric text, value numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select 'active_members'::text, (count(*) filter (where status='active'))::numeric from customer_advisory_board_members_r3041
    union all
    select 'avg_attendance_pct'::text, round(avg(attendance_rate_pct),2)::numeric from customer_advisory_board_members_r3041
    union all
    select 'total_contributions'::text, sum(contributions_count)::numeric from customer_advisory_board_members_r3041
    union all
    select 'outputs_shipped'::text, (count(*) filter (where adoption_status='shipped'))::numeric from cab_quarterly_outputs_r3041
    union all
    select 'total_impact_lakhs'::text, round(sum(est_revenue_impact_lakhs),2)::numeric from cab_quarterly_outputs_r3041
    union all
    select 'avg_health_score'::text, round(avg(health_score),2)::numeric from cab_quarterly_outputs_r3041;
end; $$;

revoke all on function founder_r3041_member_roster() from public, anon;
revoke all on function founder_r3041_attendance_by_role() from public, anon;
revoke all on function founder_r3041_engineer_sponsor_load() from public, anon;
revoke all on function founder_r3041_quarterly_output_summary() from public, anon;
revoke all on function founder_r3041_output_type_breakdown() from public, anon;
revoke all on function founder_r3041_top_outputs_by_impact() from public, anon;
revoke all on function founder_r3041_board_health_snapshot() from public, anon;

grant execute on function founder_r3041_member_roster() to authenticated;
grant execute on function founder_r3041_attendance_by_role() to authenticated;
grant execute on function founder_r3041_engineer_sponsor_load() to authenticated;
grant execute on function founder_r3041_quarterly_output_summary() to authenticated;
grant execute on function founder_r3041_output_type_breakdown() to authenticated;
grant execute on function founder_r3041_top_outputs_by_impact() to authenticated;
grant execute on function founder_r3041_board_health_snapshot() to authenticated;
