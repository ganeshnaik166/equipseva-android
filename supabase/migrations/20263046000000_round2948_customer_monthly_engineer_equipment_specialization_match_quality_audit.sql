-- Round 2948: Customer Monthly Engineer Equipment-Specialization Match Quality Audit
-- HEAVY ★★★★

create table if not exists engineer_equipment_specialization_match_audits_r2948 (
  id uuid primary key default gen_random_uuid(),
  audit_month date not null,
  engineer_label text not null,
  equipment_category text not null check (equipment_category in ('ventilator','dialysis','imaging','anesthesia','patient_monitor','infusion_pump','defibrillator','ultrasound','ecg','autoclave')),
  customer_label text not null,
  customer_segment text not null check (customer_segment in ('tier1_hospital','tier2_hospital','tier3_clinic','dental','diagnostic_lab','super_specialty')),
  declared_specialization text not null,
  match_score numeric(5,2) not null check (match_score >= 0 and match_score <= 100),
  match_tier text not null check (match_tier in ('exact','adjacent','partial','mismatch')),
  jobs_completed int not null default 0,
  rework_count int not null default 0,
  csat_avg numeric(3,2) check (csat_avg is null or (csat_avg >= 0 and csat_avg <= 5)),
  audit_status text not null default 'pending' check (audit_status in ('pending','reviewed','flagged','cleared','escalated')),
  reviewer_note text,
  created_at timestamptz not null default now()
);

alter table engineer_equipment_specialization_match_audits_r2948 enable row level security;

create table if not exists engineer_specialization_audit_findings_r2948 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references engineer_equipment_specialization_match_audits_r2948(id) on delete cascade,
  finding_type text not null check (finding_type in ('skill_gap','training_needed','recertify','reassign','commendation','escalate_founder')),
  severity text not null check (severity in ('low','medium','high','critical')),
  finding_note text not null,
  action_owner text not null check (action_owner in ('ops','training','founder','engineer_self')),
  resolution_status text not null default 'open' check (resolution_status in ('open','in_progress','resolved','wontfix')),
  rupees_impact_estimate int not null default 0,
  created_at timestamptz not null default now()
);

alter table engineer_specialization_audit_findings_r2948 enable row level security;

-- Seeds: 18 audits
insert into engineer_equipment_specialization_match_audits_r2948
  (audit_month, engineer_label, equipment_category, customer_label, customer_segment, declared_specialization, match_score, match_tier, jobs_completed, rework_count, csat_avg, audit_status, reviewer_note)
values
  ('2026-05-01'::date,'ENG-Ravi K.','ventilator','Apollo Jubilee','tier1_hospital','ventilator',96.50,'exact',14,0,4.80,'cleared','exact match high CSAT'),
  ('2026-05-01'::date,'ENG-Sita M.','dialysis','NephroCare Hub','super_specialty','dialysis',92.10,'exact',11,1,4.60,'reviewed','one rework on RO unit'),
  ('2026-05-01'::date,'ENG-Anwar P.','imaging','Yashoda Imaging','tier1_hospital','imaging',88.40,'exact',9,1,4.40,'reviewed',null),
  ('2026-05-01'::date,'ENG-Deepa R.','anesthesia','KIMS OT Block','tier1_hospital','anesthesia',94.20,'exact',12,0,4.70,'cleared',null),
  ('2026-05-01'::date,'ENG-Mohan T.','patient_monitor','Care Hospitals','tier2_hospital','patient_monitor',81.30,'adjacent',8,2,4.10,'flagged','adjacent skill drift'),
  ('2026-05-01'::date,'ENG-Pavan S.','infusion_pump','SunRise Clinic','tier3_clinic','infusion_pump',76.80,'adjacent',7,1,3.90,'reviewed',null),
  ('2026-05-01'::date,'ENG-Lakshmi B.','defibrillator','Rainbow Kids','tier1_hospital','defibrillator',91.00,'exact',6,0,4.80,'cleared','top performer'),
  ('2026-05-01'::date,'ENG-Rakesh G.','ultrasound','City Diagnostic','diagnostic_lab','ultrasound',68.20,'partial',10,3,3.50,'flagged','probe-handling gaps'),
  ('2026-05-01'::date,'ENG-Vimal C.','ecg','SmileBright Dental','dental','ecg',58.40,'mismatch',4,2,3.20,'escalated','dental ECG rare; mismatch'),
  ('2026-05-01'::date,'ENG-Ganga N.','autoclave','OrthoCare Centre','tier2_hospital','autoclave',85.70,'exact',13,1,4.30,'reviewed',null),
  ('2026-04-01'::date,'ENG-Ravi K.','ventilator','Apollo Jubilee','tier1_hospital','ventilator',95.20,'exact',12,1,4.70,'cleared',null),
  ('2026-04-01'::date,'ENG-Sita M.','dialysis','NephroCare Hub','super_specialty','dialysis',90.80,'exact',10,1,4.50,'cleared',null),
  ('2026-04-01'::date,'ENG-Mohan T.','patient_monitor','Care Hospitals','tier2_hospital','patient_monitor',79.40,'adjacent',7,2,4.00,'flagged','same pattern as May'),
  ('2026-04-01'::date,'ENG-Rakesh G.','ultrasound','City Diagnostic','diagnostic_lab','ultrasound',71.30,'partial',9,2,3.70,'flagged','training scheduled'),
  ('2026-04-01'::date,'ENG-Vimal C.','ecg','SmileBright Dental','dental','ecg',61.20,'mismatch',3,1,3.40,'escalated','reassign in progress'),
  ('2026-05-01'::date,'ENG-Hari D.','imaging','Star Imaging','tier2_hospital','imaging',83.50,'exact',8,1,4.20,'reviewed',null),
  ('2026-05-01'::date,'ENG-Komal V.','anesthesia','Yashoda OT','tier1_hospital','anesthesia',89.70,'exact',9,0,4.60,'cleared',null),
  ('2026-05-01'::date,'ENG-Suresh A.','ventilator','Tier3 ICU Hub','tier3_clinic','ventilator',64.10,'partial',5,2,3.30,'flagged','tier3 vent rare experience');

-- Seeds: 22 findings
insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'commendation','low','Zero rework, high CSAT — recognize publicly','founder','resolved',0
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Ravi K.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'training_needed','medium','RO unit module — 1 day refresher','training','in_progress',12000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Sita M.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'skill_gap','medium','Imaging firmware update workflow weak','training','open',18000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Anwar P.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'commendation','low','OT-block readiness consistent','ops','resolved',0
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Deepa R.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'skill_gap','high','2 rework events on monitor calibration','training','in_progress',45000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Mohan T.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'recertify','high','Recertify on infusion pump model X','training','open',35000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Pavan S.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'commendation','low','6 perfect jobs in tier1 cardiac','founder','resolved',0
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Lakshmi B.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'skill_gap','high','Probe handling — 3 rework events','training','in_progress',62000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Rakesh G.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'reassign','critical','Dental + ECG mismatch — reassign segment','ops','in_progress',85000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Vimal C.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'escalate_founder','critical','Pattern repeating month-over-month','founder','open',150000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Vimal C.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'training_needed','medium','Autoclave seal-test SOP refresh','training','open',9000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Ganga N.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'commendation','low','April carryover — sustained excellence','founder','resolved',0
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Ravi K.' and audit_month='2026-04-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'skill_gap','high','Repeat issue — escalate to training','training','in_progress',48000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Mohan T.' and audit_month='2026-04-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'training_needed','high','Probe handling course booked','training','in_progress',58000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Rakesh G.' and audit_month='2026-04-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'reassign','critical','Move out of dental ECG queue','ops','in_progress',92000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Vimal C.' and audit_month='2026-04-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'training_needed','medium','MRI service-mode familiarity','training','open',22000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Hari D.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'commendation','low','Zero rework anesthesia month','founder','resolved',0
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Komal V.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'recertify','high','Tier3 vent recert needed','training','open',40000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Suresh A.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'skill_gap','medium','Calibration drift on Care Hospitals route','training','open',16000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Mohan T.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'training_needed','low','Soft skills — escalation phrasing','training','open',5000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Pavan S.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'escalate_founder','high','Tier3 vent route — strategic gap','founder','open',75000
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Suresh A.' and audit_month='2026-05-01'::date;

insert into engineer_specialization_audit_findings_r2948
  (audit_id, finding_type, severity, finding_note, action_owner, resolution_status, rupees_impact_estimate)
select id,'commendation','low','Adjacent-tier recovery — improving trend','ops','resolved',0
from engineer_equipment_specialization_match_audits_r2948 where engineer_label='ENG-Ganga N.' and audit_month='2026-05-01'::date;

-- RPC 1: monthly summary
create or replace function founder_r2948_monthly_match_summary()
returns table(audit_month date, audits int, exact_pct numeric, avg_match_score numeric, avg_csat numeric, total_rework int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_month,
         count(*)::int,
         round(100.0 * (count(*) filter (where a.match_tier='exact'))::numeric / nullif(count(*),0), 1),
         round(avg(a.match_score), 2),
         round(avg(a.csat_avg), 2),
         coalesce(sum(a.rework_count),0)::int
  from engineer_equipment_specialization_match_audits_r2948 a
  group by a.audit_month
  order by a.audit_month desc;
end; $$;

-- RPC 2: by match tier
create or replace function founder_r2948_by_match_tier()
returns table(match_tier text, audits int, avg_score numeric, avg_csat numeric, rework_total int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.match_tier,
         count(*)::int,
         round(avg(a.match_score), 2),
         round(avg(a.csat_avg), 2),
         coalesce(sum(a.rework_count),0)::int
  from engineer_equipment_specialization_match_audits_r2948 a
  group by a.match_tier
  order by a.match_tier;
end; $$;

-- RPC 3: by equipment category
create or replace function founder_r2948_by_equipment_category()
returns table(equipment_category text, audits int, avg_match numeric, flagged int, escalated int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.equipment_category,
         count(*)::int,
         round(avg(a.match_score), 2),
         (count(*) filter (where a.audit_status='flagged'))::int,
         (count(*) filter (where a.audit_status='escalated'))::int
  from engineer_equipment_specialization_match_audits_r2948 a
  group by a.equipment_category
  order by avg(a.match_score) asc nulls last;
end; $$;

-- RPC 4: engineer scorecard
create or replace function founder_r2948_engineer_scorecard()
returns table(engineer_label text, audits int, avg_score numeric, avg_csat numeric, flagged int, total_rework int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_label,
         count(*)::int,
         round(avg(a.match_score), 2),
         round(avg(a.csat_avg), 2),
         (count(*) filter (where a.audit_status in ('flagged','escalated')))::int,
         coalesce(sum(a.rework_count),0)::int
  from engineer_equipment_specialization_match_audits_r2948 a
  group by a.engineer_label
  order by avg(a.match_score) asc nulls last;
end; $$;

-- RPC 5: customer-segment lens
create or replace function founder_r2948_customer_segment_lens()
returns table(customer_segment text, audits int, avg_match numeric, mismatch_count int, avg_csat numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.customer_segment,
         count(*)::int,
         round(avg(a.match_score), 2),
         (count(*) filter (where a.match_tier='mismatch'))::int,
         round(avg(a.csat_avg), 2)
  from engineer_equipment_specialization_match_audits_r2948 a
  group by a.customer_segment
  order by a.customer_segment;
end; $$;

-- RPC 6: findings rollup
create or replace function founder_r2948_findings_rollup()
returns table(finding_type text, severity text, items int, rupees_impact int, open_items int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_type,
         f.severity,
         count(*)::int,
         coalesce(sum(f.rupees_impact_estimate),0)::int,
         (count(*) filter (where f.resolution_status in ('open','in_progress')))::int
  from engineer_specialization_audit_findings_r2948 f
  group by f.finding_type, f.severity
  order by sum(f.rupees_impact_estimate) desc nulls last;
end; $$;

-- RPC 7: founder escalation queue
create or replace function founder_r2948_escalation_queue()
returns table(engineer_label text, equipment_category text, customer_label text, audit_month date, match_score numeric, severity text, finding_note text, rupees_impact int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_label,
         a.equipment_category,
         a.customer_label,
         a.audit_month,
         a.match_score,
         f.severity,
         f.finding_note,
         f.rupees_impact_estimate
  from engineer_specialization_audit_findings_r2948 f
  join engineer_equipment_specialization_match_audits_r2948 a on a.id = f.audit_id
  where f.finding_type='escalate_founder' or f.severity='critical' or a.audit_status='escalated'
  order by f.rupees_impact_estimate desc, a.audit_month desc;
end; $$;

-- Grants
revoke all on engineer_equipment_specialization_match_audits_r2948 from public, anon;
revoke all on engineer_specialization_audit_findings_r2948 from public, anon;

revoke all on function founder_r2948_monthly_match_summary() from public, anon;
revoke all on function founder_r2948_by_match_tier() from public, anon;
revoke all on function founder_r2948_by_equipment_category() from public, anon;
revoke all on function founder_r2948_engineer_scorecard() from public, anon;
revoke all on function founder_r2948_customer_segment_lens() from public, anon;
revoke all on function founder_r2948_findings_rollup() from public, anon;
revoke all on function founder_r2948_escalation_queue() from public, anon;

grant execute on function founder_r2948_monthly_match_summary() to authenticated;
grant execute on function founder_r2948_by_match_tier() to authenticated;
grant execute on function founder_r2948_by_equipment_category() to authenticated;
grant execute on function founder_r2948_engineer_scorecard() to authenticated;
grant execute on function founder_r2948_customer_segment_lens() to authenticated;
grant execute on function founder_r2948_findings_rollup() to authenticated;
grant execute on function founder_r2948_escalation_queue() to authenticated;
