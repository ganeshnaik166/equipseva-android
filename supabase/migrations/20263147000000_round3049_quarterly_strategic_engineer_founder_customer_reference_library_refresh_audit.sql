-- Round r3049 — Quarterly Strategic Engineer-Founder Customer-Reference Library Refresh Audit
-- 2 tables (_r3049) + 7 RPCs (is_founder gated) + seed rows

begin;

-- ========================================
-- Table 1: customer reference library entries
-- ========================================
create table if not exists customer_reference_library_r3049 (
  id uuid primary key default gen_random_uuid(),
  hospital_name text not null,
  hospital_tier text not null check (hospital_tier in ('tier1','tier2','tier3','super_specialty','chain','government')),
  reference_type text not null check (reference_type in ('case_study','testimonial','video','logo_only','press_quote','site_visit_host')),
  vertical text not null check (vertical in ('dental','imaging','laboratory','surgical','dialysis','ophthalmology','general')),
  refresh_status text not null check (refresh_status in ('current','stale','needs_refresh','expired','draft')),
  founder_owner text not null,
  engineer_anchor text,
  last_refreshed_on date not null,
  expires_on date not null,
  strategic_score int not null check (strategic_score between 0 and 100),
  freshness_days int not null check (freshness_days >= 0),
  amc_value_rupees bigint not null check (amc_value_rupees >= 0),
  reference_calls_q int not null check (reference_calls_q >= 0),
  audit_notes text,
  created_at timestamptz default now()
);

alter table customer_reference_library_r3049 enable row level security;

drop policy if exists crl_r3049_founder_select on customer_reference_library_r3049;
create policy crl_r3049_founder_select on customer_reference_library_r3049
  for select using (is_founder());

revoke all on customer_reference_library_r3049 from public, anon;
grant select on customer_reference_library_r3049 to authenticated;

insert into customer_reference_library_r3049
  (hospital_name, hospital_tier, reference_type, vertical, refresh_status, founder_owner, engineer_anchor, last_refreshed_on, expires_on, strategic_score, freshness_days, amc_value_rupees, reference_calls_q, audit_notes)
values
  ('Apollo Hyderabad', 'super_specialty', 'case_study', 'imaging', 'current', 'Ganesh', 'Ravi K', '2026-05-12'::date, '2026-11-12'::date, 94, 40, 4800000, 7, 'Anchor account; CT scan uptime case'),
  ('Yashoda Secunderabad', 'super_specialty', 'video', 'surgical', 'current', 'Ganesh', 'Suresh M', '2026-05-20'::date, '2026-11-20'::date, 91, 32, 5200000, 5, 'Video testimonial CMO'),
  ('KIMS Begumpet', 'tier1', 'case_study', 'dialysis', 'needs_refresh', 'Priya', 'Rahul B', '2026-02-18'::date, '2026-08-18'::date, 82, 123, 3100000, 3, 'Refresh: new dialysis floor'),
  ('Care Hospitals Banjara', 'tier1', 'testimonial', 'laboratory', 'current', 'Ganesh', 'Anil D', '2026-04-30'::date, '2026-10-30'::date, 88, 52, 2700000, 4, 'CFO testimonial; lab AMC'),
  ('Continental Gachibowli', 'super_specialty', 'site_visit_host', 'imaging', 'stale', 'Priya', 'Vikram T', '2025-12-05'::date, '2026-06-05'::date, 75, 198, 4100000, 2, 'Stale; need fresh site visit'),
  ('Sunshine Paradise', 'tier1', 'press_quote', 'surgical', 'current', 'Ganesh', 'Naveen P', '2026-06-01'::date, '2026-12-01'::date, 86, 20, 3600000, 6, 'ET Healthworld press quote'),
  ('AIG Hospitals', 'super_specialty', 'case_study', 'imaging', 'current', 'Ganesh', 'Ravi K', '2026-05-28'::date, '2026-11-28'::date, 95, 24, 6200000, 8, 'Top reference; GI imaging'),
  ('Olive Hospitals', 'tier2', 'logo_only', 'general', 'expired', 'Priya', null, '2025-09-10'::date, '2026-03-10'::date, 45, 285, 800000, 0, 'Logo expired; renew consent'),
  ('Sunrise Dental Hub', 'tier2', 'video', 'dental', 'current', 'Ganesh', 'Kiran S', '2026-04-12'::date, '2026-10-12'::date, 79, 70, 1100000, 3, 'Dental vertical anchor'),
  ('Rainbow Childrens', 'tier1', 'case_study', 'general', 'needs_refresh', 'Priya', 'Mohan R', '2026-01-22'::date, '2026-07-22'::date, 80, 151, 2900000, 2, 'Refresh: new NICU AMC'),
  ('Maxivision Bengaluru', 'super_specialty', 'testimonial', 'ophthalmology', 'current', 'Ganesh', 'Deepak L', '2026-05-05'::date, '2026-11-05'::date, 87, 47, 2400000, 4, 'COO testimonial'),
  ('Asian Institute Mumbai', 'super_specialty', 'site_visit_host', 'surgical', 'current', 'Ganesh', 'Suresh M', '2026-06-08'::date, '2026-12-08'::date, 92, 13, 5800000, 9, 'Top site visit host'),
  ('Manipal Whitefield', 'chain', 'case_study', 'imaging', 'stale', 'Priya', 'Ravi K', '2025-11-30'::date, '2026-05-30'::date, 70, 203, 4400000, 1, 'Chain stale; refresh urgent'),
  ('Fortis Mulund', 'chain', 'press_quote', 'general', 'current', 'Ganesh', null, '2026-05-15'::date, '2026-11-15'::date, 83, 37, 3900000, 5, 'BS press quote'),
  ('Narayana Bangalore', 'chain', 'video', 'surgical', 'needs_refresh', 'Priya', 'Naveen P', '2026-02-02'::date, '2026-08-02'::date, 81, 140, 4700000, 2, 'Refresh: chain-wide AMC'),
  ('Lilavati Bandra', 'tier1', 'testimonial', 'laboratory', 'current', 'Ganesh', 'Anil D', '2026-04-25'::date, '2026-10-25'::date, 85, 57, 2200000, 3, 'Lab chief testimonial'),
  ('Wockhardt Mira Road', 'tier2', 'logo_only', 'general', 'draft', 'Priya', null, '2026-06-10'::date, '2026-12-10'::date, 50, 11, 600000, 0, 'Draft; awaiting MSA'),
  ('Aster Medcity Kochi', 'super_specialty', 'case_study', 'dialysis', 'current', 'Ganesh', 'Rahul B', '2026-05-18'::date, '2026-11-18'::date, 89, 34, 3700000, 6, 'South India dialysis anchor'),
  ('Kauvery Trichy', 'tier1', 'testimonial', 'imaging', 'expired', 'Priya', 'Vikram T', '2025-08-22'::date, '2026-02-22'::date, 40, 304, 1500000, 0, 'Expired; deprioritize'),
  ('Global Hospitals Chennai', 'super_specialty', 'site_visit_host', 'surgical', 'current', 'Ganesh', 'Suresh M', '2026-05-25'::date, '2026-11-25'::date, 90, 27, 5100000, 7, 'Liver tx site visit'),
  ('SRM Hospitals', 'tier2', 'case_study', 'general', 'needs_refresh', 'Priya', 'Mohan R', '2026-01-10'::date, '2026-07-10'::date, 72, 163, 1800000, 1, 'Refresh: new ICU'),
  ('Tata Memorial Mumbai', 'government', 'press_quote', 'imaging', 'current', 'Ganesh', 'Ravi K', '2026-04-18'::date, '2026-10-18'::date, 93, 64, 0, 4, 'Govt; no AMC revenue but strategic'),
  ('AIIMS Delhi', 'government', 'site_visit_host', 'general', 'stale', 'Priya', null, '2025-12-15'::date, '2026-06-15'::date, 77, 188, 0, 1, 'Govt stale; renew'),
  ('Medanta Gurgaon', 'super_specialty', 'video', 'surgical', 'current', 'Ganesh', 'Naveen P', '2026-05-30'::date, '2026-11-30'::date, 88, 22, 4900000, 5, 'Robotic surgery video'),
  ('Jaslok Mumbai', 'tier1', 'testimonial', 'ophthalmology', 'current', 'Ganesh', 'Deepak L', '2026-06-05'::date, '2026-12-05'::date, 84, 16, 2100000, 3, 'Recent testimonial');

-- ========================================
-- Table 2: refresh audit findings
-- ========================================
create table if not exists reference_refresh_audit_r3049 (
  id uuid primary key default gen_random_uuid(),
  quarter text not null check (quarter in ('q1_2026','q2_2026','q3_2026','q4_2026')),
  audit_area text not null check (audit_area in ('consent','content','engineer_anchor','strategic_fit','expiry','founder_handoff')),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  hospital_name text not null,
  finding_summary text not null,
  owner_role text not null check (owner_role in ('founder','sales','marketing','engineering','legal')),
  status text not null check (status in ('open','in_progress','resolved','deferred','wont_fix')),
  days_open int not null check (days_open >= 0),
  remediation_effort_hours int not null check (remediation_effort_hours >= 0),
  blast_radius_rupees bigint not null check (blast_radius_rupees >= 0),
  audit_round int not null check (audit_round between 1 and 8),
  raised_on date not null,
  due_on date not null,
  notes text,
  created_at timestamptz default now()
);

alter table reference_refresh_audit_r3049 enable row level security;

drop policy if exists rra_r3049_founder_select on reference_refresh_audit_r3049;
create policy rra_r3049_founder_select on reference_refresh_audit_r3049
  for select using (is_founder());

revoke all on reference_refresh_audit_r3049 from public, anon;
grant select on reference_refresh_audit_r3049 to authenticated;

insert into reference_refresh_audit_r3049
  (quarter, audit_area, severity, hospital_name, finding_summary, owner_role, status, days_open, remediation_effort_hours, blast_radius_rupees, audit_round, raised_on, due_on, notes)
values
  ('q2_2026','consent','p1','Olive Hospitals','Logo consent expired; still on website','legal','open',15,4,800000,3,'2026-06-06'::date,'2026-06-21'::date,'Take down ASAP'),
  ('q2_2026','content','p2','KIMS Begumpet','Case study mentions decommissioned CT','marketing','in_progress',9,8,3100000,3,'2026-06-12'::date,'2026-06-26'::date,'Rewrite due'),
  ('q2_2026','engineer_anchor','p1','Continental Gachibowli','Anchor engineer left org','engineering','open',22,12,4100000,2,'2026-05-30'::date,'2026-06-29'::date,'Reassign Vikram T'),
  ('q2_2026','strategic_fit','p3','Kauvery Trichy','No longer strategic; expired ref','founder','resolved',0,2,1500000,1,'2026-05-15'::date,'2026-05-22'::date,'Archived'),
  ('q2_2026','expiry','p0','Manipal Whitefield','Reference past expiry; still in deck','founder','open',23,6,4400000,3,'2026-05-29'::date,'2026-06-12'::date,'Pull from deck'),
  ('q2_2026','founder_handoff','p2','Aster Medcity Kochi','Handoff doc missing','founder','in_progress',7,3,3700000,3,'2026-06-14'::date,'2026-06-28'::date,'Priya to draft'),
  ('q2_2026','consent','p1','AIIMS Delhi','Govt MoU clause review pending','legal','open',6,10,0,3,'2026-06-15'::date,'2026-06-30'::date,'DGHS clearance'),
  ('q2_2026','content','p2','Narayana Bangalore','Chain-wide stats outdated','marketing','open',12,6,4700000,3,'2026-06-09'::date,'2026-06-23'::date,'2025 data only'),
  ('q2_2026','engineer_anchor','p2','SRM Hospitals','Anchor unaware of reference','engineering','open',8,2,1800000,3,'2026-06-13'::date,'2026-06-27'::date,'Brief Mohan R'),
  ('q2_2026','strategic_fit','p2','Wockhardt Mira Road','Logo-only; weak signal','marketing','deferred',18,4,600000,2,'2026-06-03'::date,'2026-07-03'::date,'Q3 push'),
  ('q2_2026','expiry','p1','Olive Hospitals','Expired 3 months ago','founder','open',15,2,800000,3,'2026-06-06'::date,'2026-06-20'::date,'Same as consent finding'),
  ('q2_2026','founder_handoff','p3','Apollo Hyderabad','Handoff complete but not logged','founder','resolved',0,1,4800000,3,'2026-06-01'::date,'2026-06-05'::date,'Logged'),
  ('q1_2026','consent','p0','Yashoda Secunderabad','Video consent edge case','legal','resolved',0,16,5200000,1,'2026-02-10'::date,'2026-02-24'::date,'Re-signed'),
  ('q1_2026','content','p1','AIG Hospitals','Case study had wrong AMC tier','marketing','resolved',0,5,6200000,1,'2026-03-05'::date,'2026-03-19'::date,'Fixed'),
  ('q1_2026','engineer_anchor','p2','Care Hospitals Banjara','Backup anchor missing','engineering','resolved',0,3,2700000,1,'2026-03-12'::date,'2026-03-26'::date,'Anil D primary; backup added'),
  ('q1_2026','strategic_fit','p1','Sunrise Dental Hub','Dental vertical fit weak Q1','founder','resolved',0,4,1100000,1,'2026-02-20'::date,'2026-03-06'::date,'Reclassified strategic'),
  ('q1_2026','expiry','p1','Manipal Whitefield','First expiry warning','founder','wont_fix',0,2,4400000,1,'2026-03-15'::date,'2026-03-29'::date,'Re-raised in Q2'),
  ('q1_2026','founder_handoff','p2','Global Hospitals Chennai','Handoff template draft','founder','resolved',0,6,5100000,1,'2026-02-25'::date,'2026-03-11'::date,'Template v2'),
  ('q2_2026','consent','p2','Lilavati Bandra','Quote attribution unclear','legal','resolved',0,2,2200000,3,'2026-06-02'::date,'2026-06-09'::date,'Re-attributed'),
  ('q2_2026','content','p3','Maxivision Bengaluru','Minor typo in testimonial','marketing','resolved',0,1,2400000,3,'2026-06-04'::date,'2026-06-06'::date,'Fixed'),
  ('q2_2026','strategic_fit','p1','Tata Memorial Mumbai','Govt fit excellent; underutilized','marketing','open',5,8,0,3,'2026-06-16'::date,'2026-06-30'::date,'Amplify in deck'),
  ('q2_2026','expiry','p2','Asian Institute Mumbai','Re-confirmed; not expired','founder','resolved',0,1,5800000,3,'2026-06-07'::date,'2026-06-08'::date,'False alarm'),
  ('q2_2026','engineer_anchor','p3','Sunshine Paradise','Anchor available but unbriefed','engineering','in_progress',4,2,3600000,3,'2026-06-17'::date,'2026-06-24'::date,'Briefing scheduled'),
  ('q2_2026','founder_handoff','p1','Medanta Gurgaon','Founder owner unclear post-pivot','founder','open',10,5,4900000,3,'2026-06-11'::date,'2026-06-25'::date,'Ganesh owns');

-- ========================================
-- RPC 1: library overview
-- ========================================
create or replace function founder_r3049_library_overview()
returns table(
  total_refs int,
  current_refs int,
  needs_refresh_refs int,
  stale_refs int,
  expired_refs int,
  draft_refs int,
  avg_strategic_score numeric,
  total_amc_value_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      count(*)::int as total_refs,
      (count(*) filter (where refresh_status = 'current'))::int as current_refs,
      (count(*) filter (where refresh_status = 'needs_refresh'))::int as needs_refresh_refs,
      (count(*) filter (where refresh_status = 'stale'))::int as stale_refs,
      (count(*) filter (where refresh_status = 'expired'))::int as expired_refs,
      (count(*) filter (where refresh_status = 'draft'))::int as draft_refs,
      round(avg(strategic_score)::numeric, 1) as avg_strategic_score,
      coalesce(sum(amc_value_rupees), 0)::bigint as total_amc_value_rupees
    from customer_reference_library_r3049;
end;
$$;

revoke all on function founder_r3049_library_overview() from public, anon;
grant execute on function founder_r3049_library_overview() to authenticated;

-- ========================================
-- RPC 2: by vertical
-- ========================================
create or replace function founder_r3049_by_vertical()
returns table(
  vertical text,
  ref_count int,
  current_count int,
  avg_score numeric,
  amc_value_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      v.vertical,
      count(*)::int as ref_count,
      (count(*) filter (where v.refresh_status = 'current'))::int as current_count,
      round(avg(v.strategic_score)::numeric, 1) as avg_score,
      coalesce(sum(v.amc_value_rupees), 0)::bigint as amc_value_rupees
    from customer_reference_library_r3049 v
    group by v.vertical
    order by amc_value_rupees desc;
end;
$$;

revoke all on function founder_r3049_by_vertical() from public, anon;
grant execute on function founder_r3049_by_vertical() to authenticated;

-- ========================================
-- RPC 3: top strategic
-- ========================================
create or replace function founder_r3049_top_strategic()
returns table(
  hospital_name text,
  hospital_tier text,
  vertical text,
  reference_type text,
  refresh_status text,
  strategic_score int,
  amc_value_rupees bigint,
  founder_owner text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      t.hospital_name, t.hospital_tier, t.vertical, t.reference_type,
      t.refresh_status, t.strategic_score, t.amc_value_rupees, t.founder_owner
    from customer_reference_library_r3049 t
    order by t.strategic_score desc, t.amc_value_rupees desc
    limit 10;
end;
$$;

revoke all on function founder_r3049_top_strategic() from public, anon;
grant execute on function founder_r3049_top_strategic() to authenticated;

-- ========================================
-- RPC 4: refresh queue (stale + needs_refresh + expired)
-- ========================================
create or replace function founder_r3049_refresh_queue()
returns table(
  hospital_name text,
  refresh_status text,
  freshness_days int,
  expires_on date,
  strategic_score int,
  founder_owner text,
  engineer_anchor text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      q.hospital_name, q.refresh_status, q.freshness_days,
      q.expires_on, q.strategic_score, q.founder_owner, q.engineer_anchor
    from customer_reference_library_r3049 q
    where q.refresh_status in ('stale','needs_refresh','expired')
    order by q.strategic_score desc, q.freshness_days desc;
end;
$$;

revoke all on function founder_r3049_refresh_queue() from public, anon;
grant execute on function founder_r3049_refresh_queue() to authenticated;

-- ========================================
-- RPC 5: audit findings by severity
-- ========================================
create or replace function founder_r3049_audit_by_severity()
returns table(
  severity text,
  finding_count int,
  open_count int,
  resolved_count int,
  total_blast_radius_rupees bigint,
  avg_days_open numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      a.severity,
      count(*)::int as finding_count,
      (count(*) filter (where a.status = 'open'))::int as open_count,
      (count(*) filter (where a.status = 'resolved'))::int as resolved_count,
      coalesce(sum(a.blast_radius_rupees), 0)::bigint as total_blast_radius_rupees,
      round(avg(a.days_open)::numeric, 1) as avg_days_open
    from reference_refresh_audit_r3049 a
    group by a.severity
    order by a.severity;
end;
$$;

revoke all on function founder_r3049_audit_by_severity() from public, anon;
grant execute on function founder_r3049_audit_by_severity() to authenticated;

-- ========================================
-- RPC 6: open p0/p1 findings
-- ========================================
create or replace function founder_r3049_open_critical()
returns table(
  hospital_name text,
  audit_area text,
  severity text,
  finding_summary text,
  owner_role text,
  days_open int,
  due_on date,
  blast_radius_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      o.hospital_name, o.audit_area, o.severity, o.finding_summary,
      o.owner_role, o.days_open, o.due_on, o.blast_radius_rupees
    from reference_refresh_audit_r3049 o
    where o.severity in ('p0','p1')
      and o.status in ('open','in_progress')
    order by o.severity, o.days_open desc;
end;
$$;

revoke all on function founder_r3049_open_critical() from public, anon;
grant execute on function founder_r3049_open_critical() to authenticated;

-- ========================================
-- RPC 7: owner workload
-- ========================================
create or replace function founder_r3049_owner_workload()
returns table(
  owner_role text,
  finding_count int,
  open_count int,
  total_effort_hours int,
  total_blast_radius_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      w.owner_role,
      count(*)::int as finding_count,
      (count(*) filter (where w.status in ('open','in_progress')))::int as open_count,
      coalesce(sum(w.remediation_effort_hours), 0)::int as total_effort_hours,
      coalesce(sum(w.blast_radius_rupees), 0)::bigint as total_blast_radius_rupees
    from reference_refresh_audit_r3049 w
    group by w.owner_role
    order by open_count desc;
end;
$$;

revoke all on function founder_r3049_owner_workload() from public, anon;
grant execute on function founder_r3049_owner_workload() to authenticated;

-- ========================================
-- RPC 8: founder owner book
-- ========================================
create or replace function founder_r3049_founder_owner_book()
returns table(
  founder_owner text,
  ref_count int,
  current_count int,
  needs_attention_count int,
  total_amc_value_rupees bigint,
  avg_strategic_score numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      b.founder_owner,
      count(*)::int as ref_count,
      (count(*) filter (where b.refresh_status = 'current'))::int as current_count,
      (count(*) filter (where b.refresh_status in ('stale','needs_refresh','expired')))::int as needs_attention_count,
      coalesce(sum(b.amc_value_rupees), 0)::bigint as total_amc_value_rupees,
      round(avg(b.strategic_score)::numeric, 1) as avg_strategic_score
    from customer_reference_library_r3049 b
    group by b.founder_owner
    order by total_amc_value_rupees desc;
end;
$$;

revoke all on function founder_r3049_founder_owner_book() from public, anon;
grant execute on function founder_r3049_founder_owner_book() to authenticated;

commit;
