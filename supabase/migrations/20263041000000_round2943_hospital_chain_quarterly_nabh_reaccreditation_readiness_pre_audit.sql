-- Round 2943: Hospital Chain Quarterly NABH Re-Accreditation Readiness Pre-Audit
-- HEAVY ★★★★

create table if not exists hospital_chain_nabh_reaccred_chapters_r2943 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  chain_name text not null,
  hospital_unit text not null,
  chapter_code text not null check (chapter_code in ('AAC','COP','MOM','PRE','HIC','PRI','HRP','HIS','FMS','IMS')),
  chapter_name text not null,
  standards_total int not null check (standards_total > 0),
  objective_elements_total int not null check (objective_elements_total > 0),
  oes_compliant int not null check (oes_compliant >= 0),
  oes_partial int not null check (oes_partial >= 0),
  oes_non_compliant int not null check (oes_non_compliant >= 0),
  readiness_score numeric(5,2) not null check (readiness_score >= 0 and readiness_score <= 100),
  readiness_band text not null check (readiness_band in ('green','amber','red','critical')),
  last_internal_audit_at timestamptz not null,
  next_review_due_at timestamptz not null,
  lead_auditor text not null,
  remarks text
);

create table if not exists hospital_chain_nabh_reaccred_findings_r2943 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  chain_name text not null,
  hospital_unit text not null,
  chapter_code text not null check (chapter_code in ('AAC','COP','MOM','PRE','HIC','PRI','HRP','HIS','FMS','IMS')),
  finding_severity text not null check (finding_severity in ('minor','major','critical','observation')),
  finding_title text not null,
  finding_description text not null,
  root_cause text,
  capa_status text not null check (capa_status in ('open','in_progress','verified','closed','overdue')),
  capa_owner text not null,
  capa_due_at timestamptz not null,
  evidence_attached boolean not null default false,
  cost_to_close_rupees int not null check (cost_to_close_rupees >= 0),
  reaccred_blocker boolean not null default false
);

alter table hospital_chain_nabh_reaccred_chapters_r2943 enable row level security;
alter table hospital_chain_nabh_reaccred_findings_r2943 enable row level security;

-- skipped is_founder redefinition (kept prod version)

-- Seed chapters (16 rows)
insert into hospital_chain_nabh_reaccred_chapters_r2943
(chain_name, hospital_unit, chapter_code, chapter_name, standards_total, objective_elements_total, oes_compliant, oes_partial, oes_non_compliant, readiness_score, readiness_band, last_internal_audit_at, next_review_due_at, lead_auditor, remarks)
values
('Apollo Group','Apollo Jubilee Hills','AAC','Access Assessment & Continuity',12,68,54,10,4,79.41,'amber','2026-06-01'::timestamptz,'2026-07-15'::timestamptz,'Dr. Meera Iyer','triage SOP needs refresh'),
('Apollo Group','Apollo Jubilee Hills','COP','Care of Patients',23,142,128,11,3,90.14,'green','2026-06-02'::timestamptz,'2026-07-16'::timestamptz,'Dr. Anil Verma','strong compliance'),
('Apollo Group','Apollo Jubilee Hills','MOM','Management of Medication',18,92,71,15,6,77.17,'amber','2026-06-03'::timestamptz,'2026-07-17'::timestamptz,'Dr. Priya Kapoor','high-alert drug labels lacking'),
('Apollo Group','Apollo Jubilee Hills','HIC','Hospital Infection Control',12,72,48,18,6,66.67,'red','2026-06-04'::timestamptz,'2026-07-18'::timestamptz,'Dr. Rakesh Mohan','HAI surveillance gaps'),
('Apollo Group','Apollo Hyderguda','PRE','Patient Rights & Education',8,56,45,7,4,80.36,'amber','2026-06-05'::timestamptz,'2026-07-19'::timestamptz,'Dr. Sneha Rao','consent forms outdated'),
('Apollo Group','Apollo Hyderguda','HRP','Human Resource Management',9,52,40,8,4,76.92,'amber','2026-06-06'::timestamptz,'2026-07-20'::timestamptz,'Mr. Suresh Pillai','credentialing files thin'),
('Manipal Hospitals','Manipal Bangalore','AAC','Access Assessment & Continuity',12,68,60,6,2,88.24,'green','2026-06-07'::timestamptz,'2026-07-21'::timestamptz,'Dr. Kavita Sharma','minor wayfinding'),
('Manipal Hospitals','Manipal Bangalore','FMS','Facility Management & Safety',12,74,52,15,7,70.27,'red','2026-06-08'::timestamptz,'2026-07-22'::timestamptz,'Mr. Anand Reddy','fire-safety drill overdue'),
('Manipal Hospitals','Manipal Whitefield','IMS','Information Management',7,42,30,8,4,71.43,'amber','2026-06-09'::timestamptz,'2026-07-23'::timestamptz,'Ms. Lakshmi Iyer','MRD retention gaps'),
('Manipal Hospitals','Manipal Whitefield','HIS','Hospital Infrastructure Services',6,38,22,10,6,57.89,'critical','2026-06-10'::timestamptz,'2026-07-24'::timestamptz,'Mr. Vinod Pai','medical-gas line leaks'),
('Fortis Healthcare','Fortis Mulund','PRI','Patient Rights',8,48,40,6,2,83.33,'amber','2026-06-11'::timestamptz,'2026-07-25'::timestamptz,'Dr. Ramesh Joshi','grievance log lacks closure'),
('Fortis Healthcare','Fortis Mulund','MOM','Management of Medication',18,92,80,8,4,86.96,'amber','2026-06-12'::timestamptz,'2026-07-26'::timestamptz,'Dr. Anita Desai','LASA segregation good'),
('Fortis Healthcare','Fortis Vashi','COP','Care of Patients',23,142,110,22,10,77.46,'amber','2026-06-13'::timestamptz,'2026-07-27'::timestamptz,'Dr. Manish Tiwari','reassessment timing miss'),
('Max Healthcare','Max Saket','HIC','Hospital Infection Control',12,72,58,10,4,80.56,'amber','2026-06-14'::timestamptz,'2026-07-28'::timestamptz,'Dr. Sunita Bhatia','hand-hygiene audit lapsed'),
('Max Healthcare','Max Patparganj','AAC','Access Assessment & Continuity',12,68,38,18,12,55.88,'critical','2026-06-15'::timestamptz,'2026-07-29'::timestamptz,'Dr. Vikram Singh','ED-to-ward handoff fails'),
('Narayana Health','NH Bangalore','HRP','Human Resource Management',9,52,46,4,2,88.46,'green','2026-06-16'::timestamptz,'2026-07-30'::timestamptz,'Ms. Geeta Murthy','training matrix current');

-- Seed findings (18 rows)
insert into hospital_chain_nabh_reaccred_findings_r2943
(chain_name, hospital_unit, chapter_code, finding_severity, finding_title, finding_description, root_cause, capa_status, capa_owner, capa_due_at, evidence_attached, cost_to_close_rupees, reaccred_blocker)
values
('Apollo Group','Apollo Jubilee Hills','HIC','major','HAI surveillance not monthly','Last surveillance bundle 47 days old vs 30-day requirement','Infection control nurse on leave, no backup','open','Dr. Rakesh Mohan','2026-07-05'::timestamptz,false,45000,true),
('Apollo Group','Apollo Jubilee Hills','MOM','major','High-alert drug labels missing in ICU-3','12 of 18 high-alert vials lack red sticker','Pharmacy SOP not updated post-2025 amendment','in_progress','Dr. Priya Kapoor','2026-07-10'::timestamptz,true,18000,false),
('Apollo Group','Apollo Jubilee Hills','AAC','minor','Triage colour codes inconsistent','ED uses 4-tier; SOP mandates 5-tier ESI','Training gap for new joiners','in_progress','Dr. Meera Iyer','2026-07-12'::timestamptz,true,12000,false),
('Apollo Group','Apollo Hyderguda','PRE','minor','Consent forms not bilingual','OT consent in English only','Print vendor delivered single-language batch','open','Dr. Sneha Rao','2026-07-08'::timestamptz,false,8500,false),
('Apollo Group','Apollo Hyderguda','HRP','major','Credentialing files incomplete for 6 consultants','Privilege re-verification not done in 24 months','HR system did not flag renewals','overdue','Mr. Suresh Pillai','2026-06-25'::timestamptz,false,22000,true),
('Manipal Hospitals','Manipal Bangalore','AAC','observation','Wayfinding signage faded on 4th floor','Letters illegible at 5m distance','Signage maintenance contract lapsed','closed','Dr. Kavita Sharma','2026-06-20'::timestamptz,true,15000,false),
('Manipal Hospitals','Manipal Bangalore','FMS','critical','Quarterly fire-safety drill not conducted','Last drill 6 months ago','Facility manager rotation','open','Mr. Anand Reddy','2026-07-02'::timestamptz,false,35000,true),
('Manipal Hospitals','Manipal Bangalore','FMS','major','Emergency exit blocked in B-wing basement','Storage cartons in egress path','Stores overflow','in_progress','Mr. Anand Reddy','2026-07-04'::timestamptz,true,5000,false),
('Manipal Hospitals','Manipal Whitefield','IMS','major','MRD destruction not as per retention policy','Records older than 7 yr still in active rack','Vendor SLA breach','open','Ms. Lakshmi Iyer','2026-07-11'::timestamptz,false,28000,false),
('Manipal Hospitals','Manipal Whitefield','HIS','critical','Medical-gas line leak in ward 4B','Oxygen flow drop detected during audit','Aged copper joint','open','Mr. Vinod Pai','2026-07-01'::timestamptz,true,180000,true),
('Manipal Hospitals','Manipal Whitefield','HIS','major','Backup DG set ATS fails self-test','Auto-transfer takes 18s vs 10s spec','ATS panel firmware','in_progress','Mr. Vinod Pai','2026-07-06'::timestamptz,true,65000,false),
('Fortis Healthcare','Fortis Mulund','PRI','minor','Grievance log lacks closure timestamp','40% of 2026Q1 entries missing close date','Manual log, no system enforcement','verified','Dr. Ramesh Joshi','2026-06-22'::timestamptz,true,4000,false),
('Fortis Healthcare','Fortis Vashi','COP','major','Reassessment timing not documented for 14 ICU pts','EMR field left blank','Template default missing','in_progress','Dr. Manish Tiwari','2026-07-09'::timestamptz,true,16000,false),
('Max Healthcare','Max Saket','HIC','major','Hand-hygiene audit compliance only 62%','Target ≥ 85%','Sink placement, training fatigue','open','Dr. Sunita Bhatia','2026-07-14'::timestamptz,false,32000,false),
('Max Healthcare','Max Patparganj','AAC','critical','ED-to-ward handoff SBAR not used','7 of 10 sampled handoffs verbal-only','SBAR pocket cards depleted','open','Dr. Vikram Singh','2026-07-03'::timestamptz,false,55000,true),
('Max Healthcare','Max Patparganj','AAC','major','Discharge summary delay > 24h in 18% cases','Target ≤ 5%','Consultant sign-off bottleneck','in_progress','Dr. Vikram Singh','2026-07-07'::timestamptz,true,12000,false),
('Narayana Health','NH Bangalore','HRP','observation','Annual BLS refresh pending for 4 staff','Certification expires in 22 days','Scheduling clash','closed','Ms. Geeta Murthy','2026-06-18'::timestamptz,true,3000,false),
('Apollo Group','Apollo Jubilee Hills','HIC','critical','OT culture report turnaround 11 days','Spec ≤ 5 days','Microbiology lab understaffed','open','Dr. Rakesh Mohan','2026-07-13'::timestamptz,false,72000,true);

-- RPC 1: chain readiness rollup
create or replace function r2943_chain_readiness_rollup()
returns table(chain_name text, units_audited int, avg_readiness numeric, red_or_critical_chapters int, blockers int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.chain_name,
           count(distinct c.hospital_unit)::int as units_audited,
           round(avg(c.readiness_score)::numeric, 2) as avg_readiness,
           (count(*) filter (where c.readiness_band in ('red','critical')))::int as red_or_critical_chapters,
           coalesce((select (count(*) filter (where f.reaccred_blocker))::int
                     from hospital_chain_nabh_reaccred_findings_r2943 f
                     where f.chain_name = c.chain_name), 0) as blockers
    from hospital_chain_nabh_reaccred_chapters_r2943 c
    group by c.chain_name
    order by avg_readiness asc;
end; $$;

-- RPC 2: chapter heatmap
create or replace function r2943_chapter_heatmap()
returns table(chapter_code text, chapter_name text, units_count int, avg_readiness numeric, critical_units int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.chapter_code, max(c.chapter_name) as chapter_name,
           count(*)::int as units_count,
           round(avg(c.readiness_score)::numeric, 2) as avg_readiness,
           (count(*) filter (where c.readiness_band = 'critical'))::int as critical_units
    from hospital_chain_nabh_reaccred_chapters_r2943 c
    group by c.chapter_code
    order by avg_readiness asc;
end; $$;

-- RPC 3: critical units list
create or replace function r2943_critical_units()
returns table(chain_name text, hospital_unit text, chapter_code text, readiness_score numeric, readiness_band text, next_review_due_at timestamptz, lead_auditor text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.chain_name, c.hospital_unit, c.chapter_code, c.readiness_score, c.readiness_band, c.next_review_due_at, c.lead_auditor
    from hospital_chain_nabh_reaccred_chapters_r2943 c
    where c.readiness_band in ('red','critical')
    order by c.readiness_score asc;
end; $$;

-- RPC 4: open blocker findings
create or replace function r2943_open_blocker_findings()
returns table(chain_name text, hospital_unit text, chapter_code text, finding_severity text, finding_title text, capa_status text, capa_due_at timestamptz, cost_to_close_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.chain_name, f.hospital_unit, f.chapter_code, f.finding_severity, f.finding_title, f.capa_status, f.capa_due_at, f.cost_to_close_rupees
    from hospital_chain_nabh_reaccred_findings_r2943 f
    where f.reaccred_blocker = true and f.capa_status <> 'closed'
    order by f.capa_due_at asc;
end; $$;

-- RPC 5: capa status breakdown
create or replace function r2943_capa_status_breakdown()
returns table(capa_status text, finding_count int, total_cost_rupees bigint, blockers int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.capa_status,
           count(*)::int as finding_count,
           coalesce(sum(f.cost_to_close_rupees)::bigint, 0) as total_cost_rupees,
           (count(*) filter (where f.reaccred_blocker))::int as blockers
    from hospital_chain_nabh_reaccred_findings_r2943 f
    group by f.capa_status
    order by finding_count desc;
end; $$;

-- RPC 6: overdue capas
create or replace function r2943_overdue_capas()
returns table(chain_name text, hospital_unit text, finding_title text, capa_owner text, capa_due_at timestamptz, days_overdue int, severity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.chain_name, f.hospital_unit, f.finding_title, f.capa_owner, f.capa_due_at,
           greatest(0, extract(day from (now() - f.capa_due_at))::int) as days_overdue,
           f.finding_severity
    from hospital_chain_nabh_reaccred_findings_r2943 f
    where f.capa_status in ('open','in_progress','overdue') and f.capa_due_at < now()
    order by days_overdue desc;
end; $$;

-- RPC 7: cost to remediation rollup
create or replace function r2943_cost_to_remediation()
returns table(chain_name text, total_findings int, open_findings int, blocker_findings int, total_remediation_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.chain_name,
           count(*)::int as total_findings,
           (count(*) filter (where f.capa_status <> 'closed'))::int as open_findings,
           (count(*) filter (where f.reaccred_blocker))::int as blocker_findings,
           coalesce(sum(f.cost_to_close_rupees)::bigint, 0) as total_remediation_rupees
    from hospital_chain_nabh_reaccred_findings_r2943 f
    group by f.chain_name
    order by total_remediation_rupees desc;
end; $$;

revoke all on function r2943_chain_readiness_rollup() from public, anon;
revoke all on function r2943_chapter_heatmap() from public, anon;
revoke all on function r2943_critical_units() from public, anon;
revoke all on function r2943_open_blocker_findings() from public, anon;
revoke all on function r2943_capa_status_breakdown() from public, anon;
revoke all on function r2943_overdue_capas() from public, anon;
revoke all on function r2943_cost_to_remediation() from public, anon;

grant execute on function r2943_chain_readiness_rollup() to authenticated;
grant execute on function r2943_chapter_heatmap() to authenticated;
grant execute on function r2943_critical_units() to authenticated;
grant execute on function r2943_open_blocker_findings() to authenticated;
grant execute on function r2943_capa_status_breakdown() to authenticated;
grant execute on function r2943_overdue_capas() to authenticated;
grant execute on function r2943_cost_to_remediation() to authenticated;
