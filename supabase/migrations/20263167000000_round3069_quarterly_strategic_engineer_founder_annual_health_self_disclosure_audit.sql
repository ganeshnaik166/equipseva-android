-- Round 3069 — Founder Quarterly Strategic Engineer-Founder Annual Health Self-Disclosure Audit
-- 2 tables _r3069 + 7 RPCs, all is_founder gated

create table if not exists engineer_founder_health_disclosures_r3069 (
  id uuid primary key default gen_random_uuid(),
  disclosure_quarter text not null check (disclosure_quarter in ('2026-Q1','2026-Q2','2026-Q3','2026-Q4','2027-Q1','2027-Q2')),
  subject_role text not null check (subject_role in ('founder','co_founder','engineering_lead','principal_engineer','staff_engineer','senior_engineer')),
  subject_name text not null,
  region text not null check (region in ('south','north','east','west','central','remote')),
  overall_health_score int not null check (overall_health_score between 0 and 100),
  sleep_hours_per_night numeric(4,2) not null check (sleep_hours_per_night between 0 and 14),
  weekly_exercise_hours numeric(5,2) not null check (weekly_exercise_hours between 0 and 40),
  stress_level int not null check (stress_level between 1 and 10),
  burnout_risk text not null check (burnout_risk in ('low','moderate','elevated','high','critical')),
  chronic_condition_flag boolean not null default false,
  last_medical_checkup_at timestamptz,
  mental_health_self_report text not null check (mental_health_self_report in ('thriving','stable','strained','struggling','crisis')),
  founder_review_status text not null check (founder_review_status in ('pending','reviewed','intervention_planned','intervention_active','closed')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists engineer_founder_health_interventions_r3069 (
  id uuid primary key default gen_random_uuid(),
  disclosure_id uuid not null references engineer_founder_health_disclosures_r3069(id) on delete cascade,
  intervention_type text not null check (intervention_type in ('paid_leave','therapy_stipend','workload_reduction','mandatory_offline','medical_referral','sabbatical','wellness_budget','peer_buddy')),
  budget_rupees int not null check (budget_rupees between 0 and 1000000),
  approved_by_founder boolean not null default false,
  approved_at timestamptz,
  outcome text check (outcome in ('not_started','in_progress','succeeded','partial','failed','abandoned')),
  outcome_score int check (outcome_score between 0 and 100),
  follow_up_required boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);

alter table engineer_founder_health_disclosures_r3069 enable row level security;
alter table engineer_founder_health_interventions_r3069 enable row level security;

drop policy if exists r3069_disc_founder_all on engineer_founder_health_disclosures_r3069;
create policy r3069_disc_founder_all on engineer_founder_health_disclosures_r3069 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists r3069_int_founder_all on engineer_founder_health_interventions_r3069;
create policy r3069_int_founder_all on engineer_founder_health_interventions_r3069 for all to authenticated using (is_founder()) with check (is_founder());

insert into engineer_founder_health_disclosures_r3069 (disclosure_quarter, subject_role, subject_name, region, overall_health_score, sleep_hours_per_night, weekly_exercise_hours, stress_level, burnout_risk, chronic_condition_flag, last_medical_checkup_at, mental_health_self_report, founder_review_status, notes) values
('2026-Q2','founder','Ganesh D.','south',62,5.5,3.0,8,'elevated',false,'2026-03-15'::timestamptz,'strained','intervention_planned','founder self-disclosure baseline'),
('2026-Q2','co_founder','Priya R.','south',71,6.5,4.5,6,'moderate',false,'2026-04-02'::timestamptz,'stable','reviewed','co-founder ok, monitor'),
('2026-Q2','engineering_lead','Arjun K.','north',55,5.0,1.5,9,'high',true,'2026-02-20'::timestamptz,'struggling','intervention_active','hypertension flag, on meds'),
('2026-Q2','principal_engineer','Sneha M.','south',78,7.0,5.0,5,'low',false,'2026-05-10'::timestamptz,'thriving','closed','healthy baseline'),
('2026-Q2','staff_engineer','Rohit S.','west',48,4.5,0.5,10,'critical',true,'2026-01-08'::timestamptz,'crisis','intervention_active','sabbatical recommended urgently'),
('2026-Q2','staff_engineer','Vikram P.','central',66,6.0,3.5,7,'moderate',false,'2026-04-22'::timestamptz,'stable','reviewed','workload ok'),
('2026-Q2','senior_engineer','Anjali T.','remote',73,7.5,6.0,4,'low',false,'2026-05-18'::timestamptz,'thriving','closed','remote work suits her'),
('2026-Q2','senior_engineer','Kiran N.','east',59,5.8,2.0,8,'elevated',false,null,'strained','pending','no checkup record, push for medical'),
('2026-Q2','senior_engineer','Manish G.','north',52,4.8,1.0,9,'high',true,'2026-03-30'::timestamptz,'struggling','intervention_planned','diabetes type-2 disclosed'),
('2026-Q2','principal_engineer','Lakshmi V.','south',81,7.2,5.5,4,'low',false,'2026-05-25'::timestamptz,'thriving','closed','exemplar profile'),
('2026-Q2','engineering_lead','Suresh B.','west',58,5.5,2.5,8,'elevated',false,'2026-02-14'::timestamptz,'strained','intervention_active','therapy stipend approved'),
('2026-Q2','staff_engineer','Deepa C.','south',64,6.2,3.0,7,'moderate',false,'2026-04-11'::timestamptz,'stable','reviewed','okay, light intervention'),
('2026-Q1','founder','Ganesh D.','south',58,5.2,2.5,9,'high',false,'2025-12-20'::timestamptz,'struggling','closed','prior quarter — improved'),
('2026-Q1','engineering_lead','Arjun K.','north',50,4.5,1.0,10,'critical',true,'2025-11-30'::timestamptz,'crisis','closed','intervention worked, now stable-ish'),
('2026-Q1','staff_engineer','Rohit S.','west',45,4.0,0.0,10,'critical',true,'2025-10-15'::timestamptz,'crisis','closed','still in crisis Q2'),
('2026-Q3','founder','Ganesh D.','south',68,6.0,4.0,7,'moderate',false,null,'stable','pending','self-projection forecast');

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'therapy_stipend', 25000, true, '2026-06-01'::timestamptz, 'in_progress', 60, true, 'weekly sessions' from engineer_founder_health_disclosures_r3069 where subject_name='Ganesh D.' and disclosure_quarter='2026-Q2' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'workload_reduction', 0, true, '2026-05-20'::timestamptz, 'succeeded', 85, false, 'shifted to 32hr week' from engineer_founder_health_disclosures_r3069 where subject_name='Arjun K.' and disclosure_quarter='2026-Q2' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'sabbatical', 350000, true, '2026-06-10'::timestamptz, 'in_progress', 40, true, '3 month paid sabbatical' from engineer_founder_health_disclosures_r3069 where subject_name='Rohit S.' and disclosure_quarter='2026-Q2' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'medical_referral', 15000, true, '2026-05-15'::timestamptz, 'succeeded', 75, true, 'cardio follow-up' from engineer_founder_health_disclosures_r3069 where subject_name='Manish G.' and disclosure_quarter='2026-Q2' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'wellness_budget', 10000, true, '2026-05-22'::timestamptz, 'partial', 55, false, 'gym membership' from engineer_founder_health_disclosures_r3069 where subject_name='Suresh B.' and disclosure_quarter='2026-Q2' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'mandatory_offline', 0, true, '2026-06-05'::timestamptz, 'in_progress', 50, true, 'no slack after 7pm' from engineer_founder_health_disclosures_r3069 where subject_name='Kiran N.' and disclosure_quarter='2026-Q2' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'peer_buddy', 5000, true, '2026-05-12'::timestamptz, 'succeeded', 80, false, 'paired with Lakshmi' from engineer_founder_health_disclosures_r3069 where subject_name='Deepa C.' and disclosure_quarter='2026-Q2' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'paid_leave', 80000, true, '2026-05-30'::timestamptz, 'in_progress', 65, true, '2 week leave' from engineer_founder_health_disclosures_r3069 where subject_name='Vikram P.' and disclosure_quarter='2026-Q2' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'therapy_stipend', 25000, false, null, 'not_started', null, true, 'awaiting founder approval' from engineer_founder_health_disclosures_r3069 where subject_name='Kiran N.' and disclosure_quarter='2026-Q2' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'workload_reduction', 0, true, '2026-02-15'::timestamptz, 'succeeded', 90, false, 'Q1 win' from engineer_founder_health_disclosures_r3069 where subject_name='Arjun K.' and disclosure_quarter='2026-Q1' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'sabbatical', 300000, true, '2026-01-20'::timestamptz, 'partial', 50, true, 'Q1 sabbatical' from engineer_founder_health_disclosures_r3069 where subject_name='Rohit S.' and disclosure_quarter='2026-Q1' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'wellness_budget', 8000, true, '2026-06-12'::timestamptz, 'in_progress', 45, false, 'yoga classes' from engineer_founder_health_disclosures_r3069 where subject_name='Priya R.' and disclosure_quarter='2026-Q2' limit 1;

insert into engineer_founder_health_interventions_r3069 (disclosure_id, intervention_type, budget_rupees, approved_by_founder, approved_at, outcome, outcome_score, follow_up_required, notes)
select id, 'mandatory_offline', 0, true, '2026-06-15'::timestamptz, 'in_progress', 55, true, 'weekends off enforced' from engineer_founder_health_disclosures_r3069 where subject_name='Ganesh D.' and disclosure_quarter='2026-Q2' limit 1;

-- RPC 1: roster overview
create or replace function founder_r3069_roster_overview()
returns table(disclosure_quarter text, subject_role text, subject_name text, region text, overall_health_score int, burnout_risk text, mental_health_self_report text, founder_review_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.disclosure_quarter, d.subject_role, d.subject_name, d.region, d.overall_health_score, d.burnout_risk, d.mental_health_self_report, d.founder_review_status
  from engineer_founder_health_disclosures_r3069 d
  order by d.disclosure_quarter desc, d.overall_health_score asc;
end; $$;

-- RPC 2: burnout risk breakdown
create or replace function founder_r3069_burnout_risk_breakdown()
returns table(burnout_risk text, headcount int, avg_health_score numeric, avg_stress numeric, chronic_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.burnout_risk,
         count(*)::int as headcount,
         round(avg(d.overall_health_score)::numeric, 1) as avg_health_score,
         round(avg(d.stress_level)::numeric, 2) as avg_stress,
         (count(*) filter (where d.chronic_condition_flag))::int as chronic_count
  from engineer_founder_health_disclosures_r3069 d
  group by d.burnout_risk
  order by avg(d.overall_health_score) asc;
end; $$;

-- RPC 3: pending founder reviews
create or replace function founder_r3069_pending_reviews()
returns table(subject_name text, subject_role text, disclosure_quarter text, burnout_risk text, mental_health_self_report text, last_medical_checkup_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.subject_name, d.subject_role, d.disclosure_quarter, d.burnout_risk, d.mental_health_self_report, d.last_medical_checkup_at
  from engineer_founder_health_disclosures_r3069 d
  where d.founder_review_status in ('pending','intervention_planned')
  order by d.overall_health_score asc;
end; $$;

-- RPC 4: intervention budget summary
create or replace function founder_r3069_intervention_budget_summary()
returns table(intervention_type text, count_total int, approved_count int, total_budget int, avg_outcome_score numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.intervention_type,
         count(*)::int as count_total,
         (count(*) filter (where i.approved_by_founder))::int as approved_count,
         coalesce(sum(i.budget_rupees) filter (where i.approved_by_founder), 0)::int as total_budget,
         round(avg(i.outcome_score)::numeric, 1) as avg_outcome_score
  from engineer_founder_health_interventions_r3069 i
  group by i.intervention_type
  order by sum(i.budget_rupees) desc nulls last;
end; $$;

-- RPC 5: quarter trend
create or replace function founder_r3069_quarter_trend()
returns table(disclosure_quarter text, headcount int, avg_health_score numeric, avg_sleep numeric, high_risk_count int, crisis_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.disclosure_quarter,
         count(*)::int as headcount,
         round(avg(d.overall_health_score)::numeric, 1) as avg_health_score,
         round(avg(d.sleep_hours_per_night)::numeric, 2) as avg_sleep,
         (count(*) filter (where d.burnout_risk in ('high','critical')))::int as high_risk_count,
         (count(*) filter (where d.mental_health_self_report = 'crisis'))::int as crisis_count
  from engineer_founder_health_disclosures_r3069 d
  group by d.disclosure_quarter
  order by d.disclosure_quarter;
end; $$;

-- RPC 6: critical cases needing immediate action
create or replace function founder_r3069_critical_cases()
returns table(subject_name text, subject_role text, region text, overall_health_score int, burnout_risk text, mental_health_self_report text, chronic_condition_flag boolean, founder_review_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.subject_name, d.subject_role, d.region, d.overall_health_score, d.burnout_risk, d.mental_health_self_report, d.chronic_condition_flag, d.founder_review_status
  from engineer_founder_health_disclosures_r3069 d
  where d.burnout_risk in ('high','critical') or d.mental_health_self_report in ('struggling','crisis')
  order by d.overall_health_score asc;
end; $$;

-- RPC 7: intervention outcomes by subject
create or replace function founder_r3069_intervention_outcomes_by_subject()
returns table(subject_name text, intervention_count int, approved_count int, total_spent int, succeeded_count int, follow_up_required_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.subject_name,
         count(i.id)::int as intervention_count,
         (count(*) filter (where i.approved_by_founder))::int as approved_count,
         coalesce(sum(i.budget_rupees) filter (where i.approved_by_founder), 0)::int as total_spent,
         (count(*) filter (where i.outcome = 'succeeded'))::int as succeeded_count,
         (count(*) filter (where i.follow_up_required))::int as follow_up_required_count
  from engineer_founder_health_disclosures_r3069 d
  left join engineer_founder_health_interventions_r3069 i on i.disclosure_id = d.id
  group by d.subject_name
  having count(i.id) > 0
  order by sum(i.budget_rupees) desc nulls last;
end; $$;

revoke all on function founder_r3069_roster_overview() from public, anon;
revoke all on function founder_r3069_burnout_risk_breakdown() from public, anon;
revoke all on function founder_r3069_pending_reviews() from public, anon;
revoke all on function founder_r3069_intervention_budget_summary() from public, anon;
revoke all on function founder_r3069_quarter_trend() from public, anon;
revoke all on function founder_r3069_critical_cases() from public, anon;
revoke all on function founder_r3069_intervention_outcomes_by_subject() from public, anon;

grant execute on function founder_r3069_roster_overview() to authenticated;
grant execute on function founder_r3069_burnout_risk_breakdown() to authenticated;
grant execute on function founder_r3069_pending_reviews() to authenticated;
grant execute on function founder_r3069_intervention_budget_summary() to authenticated;
grant execute on function founder_r3069_quarter_trend() to authenticated;
grant execute on function founder_r3069_critical_cases() to authenticated;
grant execute on function founder_r3069_intervention_outcomes_by_subject() to authenticated;
