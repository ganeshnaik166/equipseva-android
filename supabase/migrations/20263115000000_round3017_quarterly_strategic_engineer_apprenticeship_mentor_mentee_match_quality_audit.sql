-- Round r3017 — Founder Quarterly Strategic Engineer-Apprenticeship Mentor-Mentee Match Quality Audit
-- HEAVY ★★★★ : 2 tables + 7 RPCs + seed rows

set local search_path = public, pg_temp;

-- ============================================================================
-- Table 1: mentor_mentee_matches_r3017
-- ============================================================================
create table if not exists mentor_mentee_matches_r3017 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  quarter text not null,
  mentor_name text not null,
  mentor_city text not null,
  mentor_tier text not null check (mentor_tier in ('bronze','silver','gold','platinum')),
  mentee_name text not null,
  mentee_city text not null,
  mentee_cohort text not null check (mentee_cohort in ('apprentice','junior','intermediate')),
  match_score int not null check (match_score between 0 and 100),
  skill_alignment_score int not null check (skill_alignment_score between 0 and 100),
  geo_proximity_km int not null check (geo_proximity_km between 0 and 2000),
  sessions_completed int not null check (sessions_completed between 0 and 50),
  sessions_scheduled int not null check (sessions_scheduled between 0 and 50),
  mentee_satisfaction_score int not null check (mentee_satisfaction_score between 0 and 100),
  mentor_satisfaction_score int not null check (mentor_satisfaction_score between 0 and 100),
  certifications_progressed int not null check (certifications_progressed between 0 and 20),
  jobs_co_serviced int not null check (jobs_co_serviced between 0 and 200),
  match_status text not null check (match_status in ('active','paused','closed','flagged')),
  flagged_reason text,
  matched_at timestamptz,
  closed_at timestamptz
);

alter table mentor_mentee_matches_r3017 enable row level security;

drop policy if exists mmm_r3017_founder_select on mentor_mentee_matches_r3017;
create policy mmm_r3017_founder_select on mentor_mentee_matches_r3017
  for select to authenticated using (is_founder());

-- ============================================================================
-- Table 2: match_quality_audit_findings_r3017
-- ============================================================================
create table if not exists match_quality_audit_findings_r3017 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  quarter text not null,
  finding_category text not null check (finding_category in ('skill_gap','geo_mismatch','engagement_drop','satisfaction_low','attrition_risk','process_breach','strength')),
  severity text not null check (severity in ('p0','p1','p2','p3','info')),
  finding_title text not null,
  affected_matches int not null check (affected_matches between 0 and 500),
  recommended_action text not null,
  expected_uplift_pct int not null check (expected_uplift_pct between 0 and 100),
  estimated_cost_rupees int not null check (estimated_cost_rupees between 0 and 5000000),
  status text not null check (status in ('open','in_review','accepted','rejected','closed')),
  owner_role text not null check (owner_role in ('founder','ops_lead','training_lead','engineer_success','none')),
  opened_at timestamptz,
  closed_at timestamptz
);

alter table match_quality_audit_findings_r3017 enable row level security;

drop policy if exists mqaf_r3017_founder_select on match_quality_audit_findings_r3017;
create policy mqaf_r3017_founder_select on match_quality_audit_findings_r3017
  for select to authenticated using (is_founder());

-- ============================================================================
-- Seeds: mentor_mentee_matches_r3017 (18 rows)
-- ============================================================================
insert into mentor_mentee_matches_r3017
  (quarter, mentor_name, mentor_city, mentor_tier, mentee_name, mentee_city, mentee_cohort,
   match_score, skill_alignment_score, geo_proximity_km, sessions_completed, sessions_scheduled,
   mentee_satisfaction_score, mentor_satisfaction_score, certifications_progressed, jobs_co_serviced,
   match_status, flagged_reason, matched_at, closed_at)
select * from (values
  ('Q2-2026','Ravi Kumar','Hyderabad','platinum','Arjun Sharma','Hyderabad','apprentice',92,95,5,10,12,88,90,3,18,'active',null::text,(now()-interval '85 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Priya Reddy','Bengaluru','gold','Sneha Iyer','Bengaluru','junior',88,90,8,8,10,85,87,2,14,'active',null,(now()-interval '80 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Suresh Babu','Chennai','platinum','Karthik Raja','Chennai','apprentice',90,92,4,12,12,91,93,4,22,'active',null,(now()-interval '78 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Anita Desai','Mumbai','silver','Rohit Mehta','Pune','junior',72,75,148,6,10,68,70,1,9,'active',null,(now()-interval '70 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Vikram Singh','Delhi','gold','Aman Verma','Noida','apprentice',85,88,22,9,10,82,84,2,13,'active',null,(now()-interval '75 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Lakshmi Nair','Kochi','silver','Deepa Menon','Trivandrum','intermediate',78,80,205,5,8,72,75,1,11,'paused','mentor on leave',(now()-interval '65 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Manoj Patil','Pune','gold','Sagar Kale','Mumbai','junior',80,82,148,7,9,78,80,2,12,'active',null,(now()-interval '60 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Geeta Rao','Hyderabad','bronze','Pooja Singh','Warangal','apprentice',62,65,148,3,8,55,60,0,4,'flagged','low engagement',(now()-interval '55 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Rajesh Khanna','Delhi','platinum','Naveen Gupta','Gurgaon','apprentice',94,96,32,14,14,93,95,5,28,'active',null,(now()-interval '88 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Sunita Joshi','Ahmedabad','gold','Hiren Patel','Ahmedabad','junior',86,88,7,10,11,84,86,3,16,'active',null,(now()-interval '72 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Kiran Bhat','Mangalore','silver','Ravi Shenoy','Udupi','apprentice',75,78,58,6,9,70,72,1,8,'active',null,(now()-interval '50 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Deepak Shetty','Bengaluru','platinum','Vivek Anand','Bengaluru','intermediate',91,93,6,11,12,89,91,4,20,'active',null,(now()-interval '82 days')::timestamptz,null::timestamptz),
  ('Q1-2026','Anil Kapoor','Mumbai','gold','Sahil Khan','Mumbai','apprentice',83,85,9,12,12,80,82,2,15,'closed',null,(now()-interval '170 days')::timestamptz,(now()-interval '12 days')::timestamptz),
  ('Q1-2026','Meera Iyengar','Chennai','silver','Ashwin Pillai','Chennai','junior',70,72,11,5,10,60,65,0,6,'closed','mentee dropped',(now()-interval '165 days')::timestamptz,(now()-interval '30 days')::timestamptz),
  ('Q1-2026','Sanjay Tiwari','Lucknow','bronze','Rakesh Yadav','Kanpur','apprentice',58,60,82,2,8,48,52,0,3,'closed','attrition',(now()-interval '160 days')::timestamptz,(now()-interval '45 days')::timestamptz),
  ('Q2-2026','Neha Sharma','Jaipur','silver','Megha Agarwal','Jaipur','junior',77,80,5,7,9,74,76,1,10,'active',null,(now()-interval '48 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Harish Menon','Coimbatore','gold','Bala Krishnan','Salem','apprentice',81,83,165,8,10,79,81,2,13,'active',null,(now()-interval '45 days')::timestamptz,null::timestamptz),
  ('Q2-2026','Pradeep Naidu','Visakhapatnam','platinum','Ramesh Babu','Visakhapatnam','intermediate',93,95,3,13,13,92,94,4,24,'active',null,(now()-interval '85 days')::timestamptz,null::timestamptz)
) as v(quarter,mentor_name,mentor_city,mentor_tier,mentee_name,mentee_city,mentee_cohort,match_score,skill_alignment_score,geo_proximity_km,sessions_completed,sessions_scheduled,mentee_satisfaction_score,mentor_satisfaction_score,certifications_progressed,jobs_co_serviced,match_status,flagged_reason,matched_at,closed_at);

-- ============================================================================
-- Seeds: match_quality_audit_findings_r3017 (15 rows)
-- ============================================================================
insert into match_quality_audit_findings_r3017
  (quarter, finding_category, severity, finding_title, affected_matches, recommended_action,
   expected_uplift_pct, estimated_cost_rupees, status, owner_role, opened_at, closed_at)
select * from (values
  ('Q2-2026','geo_mismatch','p1','3 active matches with mentor>150km — switch to remote-first cadence',3,'Move bi-weekly to video; co-visit once per quarter',18,45000,'open','ops_lead',(now()-interval '20 days')::timestamptz,null::timestamptz),
  ('Q2-2026','engagement_drop','p1','Bronze-tier mentor Geeta Rao — 3/8 sessions in 55 days',1,'Reassign Pooja Singh to silver mentor in Hyderabad',25,15000,'in_review','training_lead',(now()-interval '15 days')::timestamptz,null::timestamptz),
  ('Q2-2026','satisfaction_low','p0','Q1 attrition pair Sanjay-Rakesh — satisfaction 48; root-cause skill ladder mismatch',1,'Add skill-gap pre-screen before match commit',32,80000,'accepted','founder',(now()-interval '40 days')::timestamptz,null::timestamptz),
  ('Q2-2026','strength','info','Pradeep Naidu cohort — 93 match score, 24 jobs co-serviced',1,'Replicate Visakhapatnam pairing playbook to Bhubaneswar',0,5000,'accepted','engineer_success',(now()-interval '10 days')::timestamptz,null::timestamptz),
  ('Q2-2026','skill_gap','p2','Apprentice cohort missing CT/MRI service ladder progression',5,'Add NABH-aligned CT/MRI micro-cert by Q3 kickoff',22,250000,'in_review','training_lead',(now()-interval '25 days')::timestamptz,null::timestamptz),
  ('Q2-2026','attrition_risk','p1','2 mentees with satisfaction<70 trending toward dropout',2,'Triage call + alternate mentor offer within 7 days',28,30000,'open','engineer_success',(now()-interval '8 days')::timestamptz,null::timestamptz),
  ('Q2-2026','process_breach','p2','Match closed without exit-interview (Q1 Meera-Ashwin)',1,'Make exit interview a required transition gate',12,10000,'accepted','ops_lead',(now()-interval '30 days')::timestamptz,null::timestamptz),
  ('Q2-2026','strength','info','Platinum-tier pairs deliver 4.6 cert progressions on avg — 3.8x bronze',4,'Lock platinum-tier capacity for Q3 apprentice intake',0,0,'closed','founder',(now()-interval '50 days')::timestamptz,(now()-interval '5 days')::timestamptz),
  ('Q2-2026','geo_mismatch','p3','Harish-Bala 165km gap acceptable but watch travel reimbursement',1,'Cap travel reimbursement at ₹8k/quarter',5,8000,'open','ops_lead',(now()-interval '12 days')::timestamptz,null::timestamptz),
  ('Q2-2026','engagement_drop','p2','Tier-2 cities trail metros by 18% in sessions_completed',6,'Pilot WhatsApp-based async mentorship in tier-2',15,120000,'in_review','training_lead',(now()-interval '22 days')::timestamptz,null::timestamptz),
  ('Q2-2026','satisfaction_low','p1','Mentee satisfaction <75 in 4 matches — common theme = job-co-service cadence',4,'Mandate 2 co-service ride-alongs per quarter',20,65000,'open','engineer_success',(now()-interval '18 days')::timestamptz,null::timestamptz),
  ('Q2-2026','skill_gap','p2','Endoscopy depth gap in Chennai mentee pool',3,'Source endoscopy-cert mentor from Bangalore',16,180000,'rejected','training_lead',(now()-interval '35 days')::timestamptz,(now()-interval '7 days')::timestamptz),
  ('Q2-2026','process_breach','p1','Match commit happened before background check on 1 mentor',1,'Block match commit until bg-check status=clear',40,0,'accepted','founder',(now()-interval '14 days')::timestamptz,null::timestamptz),
  ('Q2-2026','strength','info','Q2 cohort avg match_score=82.4 vs Q1 baseline=70.1',12,'Document scoring algo as v2 baseline',0,0,'closed','founder',(now()-interval '6 days')::timestamptz,(now()-interval '1 days')::timestamptz),
  ('Q2-2026','attrition_risk','p2','Flagged match Geeta-Pooja — predicted 65% dropout in 30 days',1,'Force reassignment within 14 days',22,15000,'open','engineer_success',(now()-interval '11 days')::timestamptz,null::timestamptz)
) as v(quarter,finding_category,severity,finding_title,affected_matches,recommended_action,expected_uplift_pct,estimated_cost_rupees,status,owner_role,opened_at,closed_at);

-- ============================================================================
-- RPC 1: r3017_match_overview
-- ============================================================================
create or replace function r3017_match_overview()
returns table(
  total_matches int,
  active_matches int,
  paused_matches int,
  closed_matches int,
  flagged_matches int,
  avg_match_score numeric
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where match_status='active'))::int,
    (count(*) filter (where match_status='paused'))::int,
    (count(*) filter (where match_status='closed'))::int,
    (count(*) filter (where match_status='flagged'))::int,
    round(avg(match_score)::numeric,1)
  from mentor_mentee_matches_r3017;
end $$;

revoke all on function r3017_match_overview() from public, anon;
grant execute on function r3017_match_overview() to authenticated;

-- ============================================================================
-- RPC 2: r3017_tier_breakdown
-- ============================================================================
create or replace function r3017_tier_breakdown()
returns table(
  mentor_tier text,
  match_count int,
  avg_score numeric,
  avg_certs numeric,
  avg_satisfaction numeric
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    m.mentor_tier,
    count(*)::int,
    round(avg(m.match_score)::numeric,1),
    round(avg(m.certifications_progressed)::numeric,2),
    round(avg(m.mentee_satisfaction_score)::numeric,1)
  from mentor_mentee_matches_r3017 m
  group by m.mentor_tier
  order by avg(m.match_score) desc;
end $$;

revoke all on function r3017_tier_breakdown() from public, anon;
grant execute on function r3017_tier_breakdown() to authenticated;

-- ============================================================================
-- RPC 3: r3017_top_matches
-- ============================================================================
create or replace function r3017_top_matches()
returns table(
  mentor_name text,
  mentee_name text,
  mentor_city text,
  mentor_tier text,
  match_score int,
  mentee_satisfaction_score int,
  jobs_co_serviced int,
  certifications_progressed int
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.mentor_name, m.mentee_name, m.mentor_city, m.mentor_tier,
         m.match_score, m.mentee_satisfaction_score, m.jobs_co_serviced, m.certifications_progressed
  from mentor_mentee_matches_r3017 m
  where m.match_status='active'
  order by m.match_score desc, m.mentee_satisfaction_score desc
  limit 8;
end $$;

revoke all on function r3017_top_matches() from public, anon;
grant execute on function r3017_top_matches() to authenticated;

-- ============================================================================
-- RPC 4: r3017_flagged_matches
-- ============================================================================
create or replace function r3017_flagged_matches()
returns table(
  mentor_name text,
  mentee_name text,
  mentor_tier text,
  match_score int,
  match_status text,
  flagged_reason text,
  sessions_completed int,
  sessions_scheduled int
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.mentor_name, m.mentee_name, m.mentor_tier, m.match_score,
         m.match_status, m.flagged_reason, m.sessions_completed, m.sessions_scheduled
  from mentor_mentee_matches_r3017 m
  where m.match_status in ('flagged','paused') or m.mentee_satisfaction_score < 70
  order by m.match_score asc;
end $$;

revoke all on function r3017_flagged_matches() from public, anon;
grant execute on function r3017_flagged_matches() to authenticated;

-- ============================================================================
-- RPC 5: r3017_geo_proximity_buckets
-- ============================================================================
create or replace function r3017_geo_proximity_buckets()
returns table(
  bucket text,
  match_count int,
  avg_score numeric,
  avg_sessions numeric
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    case
      when geo_proximity_km <= 25 then '00-25 km (same city)'
      when geo_proximity_km <= 75 then '26-75 km (metro region)'
      when geo_proximity_km <= 175 then '76-175 km (state)'
      else '176+ km (remote)'
    end as bucket,
    count(*)::int,
    round(avg(match_score)::numeric,1),
    round(avg(sessions_completed)::numeric,1)
  from mentor_mentee_matches_r3017
  group by 1
  order by 1;
end $$;

revoke all on function r3017_geo_proximity_buckets() from public, anon;
grant execute on function r3017_geo_proximity_buckets() to authenticated;

-- ============================================================================
-- RPC 6: r3017_findings_by_severity
-- ============================================================================
create or replace function r3017_findings_by_severity()
returns table(
  severity text,
  open_count int,
  in_review_count int,
  accepted_count int,
  total_uplift_pct int,
  total_cost_rupees int
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.severity,
    (count(*) filter (where f.status='open'))::int,
    (count(*) filter (where f.status='in_review'))::int,
    (count(*) filter (where f.status='accepted'))::int,
    sum(f.expected_uplift_pct)::int,
    sum(f.estimated_cost_rupees)::int
  from match_quality_audit_findings_r3017 f
  group by f.severity
  order by case f.severity when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 when 'p3' then 3 else 4 end;
end $$;

revoke all on function r3017_findings_by_severity() from public, anon;
grant execute on function r3017_findings_by_severity() to authenticated;

-- ============================================================================
-- RPC 7: r3017_open_action_items
-- ============================================================================
create or replace function r3017_open_action_items()
returns table(
  finding_title text,
  finding_category text,
  severity text,
  owner_role text,
  affected_matches int,
  expected_uplift_pct int,
  estimated_cost_rupees int,
  recommended_action text
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_title, f.finding_category, f.severity, f.owner_role,
         f.affected_matches, f.expected_uplift_pct, f.estimated_cost_rupees, f.recommended_action
  from match_quality_audit_findings_r3017 f
  where f.status in ('open','in_review','accepted')
  order by case f.severity when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 when 'p3' then 3 else 4 end,
           f.expected_uplift_pct desc;
end $$;

revoke all on function r3017_open_action_items() from public, anon;
grant execute on function r3017_open_action_items() to authenticated;
