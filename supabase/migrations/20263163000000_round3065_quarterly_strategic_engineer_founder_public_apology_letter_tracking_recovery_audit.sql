-- Round 3065: Quarterly Strategic Engineer-Founder Public-Apology Letter Tracking & Recovery Audit
-- HEAVY ★★★★ — Batch 440 milestone

create table if not exists public.qstr_apology_letters_r3065 (
  id uuid primary key default gen_random_uuid(),
  quarter text not null check (quarter in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  incident_code text not null,
  incident_title text not null,
  severity text not null check (severity in ('p0','p1','p2','p3')),
  audience text not null check (audience in ('hospital','engineer','partner','investor','public','regulator')),
  letter_status text not null check (letter_status in ('drafted','founder_review','legal_review','published','retracted','archived')),
  recovery_state text not null check (recovery_state in ('not_started','in_progress','restitution_paid','trust_restored','escalated')),
  apology_sentiment_score int not null check (apology_sentiment_score between 0 and 100),
  word_count int not null check (word_count between 0 and 5000),
  reach_count int not null check (reach_count between 0 and 1000000),
  restitution_rupees bigint not null check (restitution_rupees between 0 and 100000000),
  drafted_at timestamptz not null,
  published_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.qstr_recovery_actions_r3065 (
  id uuid primary key default gen_random_uuid(),
  letter_id uuid not null references public.qstr_apology_letters_r3065(id) on delete cascade,
  action_type text not null check (action_type in ('refund','goodwill_credit','sla_credit','public_post','one_on_one_call','policy_change','engineer_retraining','founder_visit')),
  action_status text not null check (action_status in ('queued','in_flight','completed','blocked','cancelled')),
  owner_role text not null check (owner_role in ('founder','psm','ops','engineer_lead','legal','support')),
  trust_delta int not null check (trust_delta between -50 and 100),
  cost_rupees bigint not null check (cost_rupees between 0 and 50000000),
  effort_hours numeric(8,2) not null check (effort_hours between 0 and 500),
  due_at timestamptz,
  completed_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.qstr_apology_letters_r3065 enable row level security;
alter table public.qstr_recovery_actions_r3065 enable row level security;

drop policy if exists qstr_letters_founder_r3065 on public.qstr_apology_letters_r3065;
create policy qstr_letters_founder_r3065 on public.qstr_apology_letters_r3065 for select to authenticated using (public.is_founder());

drop policy if exists qstr_actions_founder_r3065 on public.qstr_recovery_actions_r3065;
create policy qstr_actions_founder_r3065 on public.qstr_recovery_actions_r3065 for select to authenticated using (public.is_founder());

insert into public.qstr_apology_letters_r3065 (quarter, incident_code, incident_title, severity, audience, letter_status, recovery_state, apology_sentiment_score, word_count, reach_count, restitution_rupees, drafted_at, published_at, closed_at) values
('Q1-2026','INC-001','Botched ventilator repair Apollo','p0','hospital','published','trust_restored',92,820,4500,450000,'2026-01-05'::timestamptz,'2026-01-07'::timestamptz,'2026-02-10'::timestamptz),
('Q1-2026','INC-002','Engineer no-show Manipal','p1','hospital','published','restitution_paid',85,640,3200,120000,'2026-01-12'::timestamptz,'2026-01-14'::timestamptz,'2026-02-01'::timestamptz),
('Q1-2026','INC-003','AMC billing error wave','p1','hospital','published','trust_restored',88,950,12000,860000,'2026-01-20'::timestamptz,'2026-01-22'::timestamptz,'2026-03-01'::timestamptz),
('Q1-2026','INC-004','Engineer pay delay 12 days','p1','engineer','published','restitution_paid',90,520,840,210000,'2026-02-01'::timestamptz,'2026-02-03'::timestamptz,'2026-02-15'::timestamptz),
('Q1-2026','INC-005','Counterfeit part Fortis','p0','hospital','published','trust_restored',95,1200,8500,1800000,'2026-02-10'::timestamptz,'2026-02-12'::timestamptz,'2026-03-20'::timestamptz),
('Q1-2026','INC-006','Misleading uptime tweet','p2','public','published','trust_restored',75,310,55000,0,'2026-02-18'::timestamptz,'2026-02-19'::timestamptz,'2026-03-05'::timestamptz),
('Q2-2026','INC-007','Investor metric overstatement','p1','investor','published','trust_restored',82,1100,180,0,'2026-04-02'::timestamptz,'2026-04-05'::timestamptz,'2026-04-25'::timestamptz),
('Q2-2026','INC-008','Dental chair AMC mispriced','p2','hospital','published','restitution_paid',80,470,1800,95000,'2026-04-10'::timestamptz,'2026-04-12'::timestamptz,'2026-05-02'::timestamptz),
('Q2-2026','INC-009','Engineer suspension reversed','p1','engineer','published','trust_restored',91,680,1200,150000,'2026-04-20'::timestamptz,'2026-04-22'::timestamptz,'2026-05-10'::timestamptz),
('Q2-2026','INC-010','SLA miss surge surgical','p1','hospital','published','restitution_paid',86,720,5400,540000,'2026-05-01'::timestamptz,'2026-05-03'::timestamptz,'2026-05-30'::timestamptz),
('Q2-2026','INC-011','Misclassified incident severity','p2','regulator','published','trust_restored',78,560,90,0,'2026-05-12'::timestamptz,'2026-05-15'::timestamptz,'2026-06-01'::timestamptz),
('Q2-2026','INC-012','Engineer tier demotion bug','p2','engineer','published','trust_restored',83,490,720,80000,'2026-05-22'::timestamptz,'2026-05-24'::timestamptz,'2026-06-08'::timestamptz),
('Q2-2026','INC-013','Hospital data export delay','p2','hospital','founder_review','in_progress',0,0,0,0,'2026-06-01'::timestamptz,null::timestamptz,null::timestamptz),
('Q2-2026','INC-014','Founder LinkedIn misquote','p3','public','published','trust_restored',70,280,42000,0,'2026-06-05'::timestamptz,'2026-06-06'::timestamptz,'2026-06-15'::timestamptz),
('Q2-2026','INC-015','Spare-part RTO surge','p2','hospital','published','in_progress',81,610,3300,310000,'2026-06-10'::timestamptz,'2026-06-12'::timestamptz,null::timestamptz),
('Q2-2026','INC-016','Engineer onboarding broken','p2','engineer','published','restitution_paid',84,540,1800,180000,'2026-06-15'::timestamptz,'2026-06-17'::timestamptz,'2026-06-28'::timestamptz),
('Q2-2026','INC-017','GST invoice mis-issuance','p1','hospital','legal_review','in_progress',0,0,0,0,'2026-06-20'::timestamptz,null::timestamptz,null::timestamptz),
('Q3-2026','INC-018','Cron job stalled 6h','p2','hospital','drafted','not_started',0,0,0,0,'2026-06-25'::timestamptz,null::timestamptz,null::timestamptz),
('Q3-2026','INC-019','Engineer payout reversal','p1','engineer','founder_review','in_progress',0,0,0,140000,'2026-06-27'::timestamptz,null::timestamptz,null::timestamptz),
('Q3-2026','INC-020','Investor data room leak suspected','p0','investor','legal_review','escalated',0,0,0,0,'2026-06-28'::timestamptz,null::timestamptz,null::timestamptz),
('Q3-2026','INC-021','Hospital chain churn Manipal','p0','hospital','drafted','not_started',0,0,0,0,'2026-06-29'::timestamptz,null::timestamptz,null::timestamptz),
('Q3-2026','INC-022','Engineer collective complaint','p1','engineer','drafted','not_started',0,0,0,0,'2026-06-30'::timestamptz,null::timestamptz,null::timestamptz);

insert into public.qstr_recovery_actions_r3065 (letter_id, action_type, action_status, owner_role, trust_delta, cost_rupees, effort_hours, due_at, completed_at, notes)
select id, 'refund', 'completed', 'founder', 25, 450000, 4.0, '2026-01-08'::timestamptz, '2026-01-09'::timestamptz, 'Full refund + service credit' from public.qstr_apology_letters_r3065 where incident_code='INC-001'
union all
select id, 'founder_visit', 'completed', 'founder', 35, 25000, 8.0, '2026-01-15'::timestamptz, '2026-01-16'::timestamptz, 'Founder visited CMO' from public.qstr_apology_letters_r3065 where incident_code='INC-001'
union all
select id, 'engineer_retraining', 'completed', 'engineer_lead', 15, 18000, 16.0, '2026-01-25'::timestamptz, '2026-02-01'::timestamptz, 'Tier-2 retrain' from public.qstr_apology_letters_r3065 where incident_code='INC-001'
union all
select id, 'sla_credit', 'completed', 'ops', 20, 120000, 2.0, '2026-01-18'::timestamptz, '2026-01-20'::timestamptz, '3 months SLA credit' from public.qstr_apology_letters_r3065 where incident_code='INC-002'
union all
select id, 'public_post', 'completed', 'founder', 12, 0, 1.5, '2026-01-23'::timestamptz, '2026-01-23'::timestamptz, 'LinkedIn post with details' from public.qstr_apology_letters_r3065 where incident_code='INC-003'
union all
select id, 'goodwill_credit', 'completed', 'psm', 18, 240000, 6.0, '2026-02-05'::timestamptz, '2026-02-08'::timestamptz, 'Goodwill credit to top 20 hospitals' from public.qstr_apology_letters_r3065 where incident_code='INC-003'
union all
select id, 'policy_change', 'completed', 'legal', 22, 0, 24.0, '2026-02-15'::timestamptz, '2026-02-28'::timestamptz, 'Payout SLA reduced to 7 days' from public.qstr_apology_letters_r3065 where incident_code='INC-004'
union all
select id, 'refund', 'completed', 'ops', 40, 1800000, 12.0, '2026-02-20'::timestamptz, '2026-02-25'::timestamptz, 'Full refund + recall' from public.qstr_apology_letters_r3065 where incident_code='INC-005'
union all
select id, 'founder_visit', 'completed', 'founder', 30, 45000, 10.0, '2026-02-22'::timestamptz, '2026-02-24'::timestamptz, 'Founder onsite RCA' from public.qstr_apology_letters_r3065 where incident_code='INC-005'
union all
select id, 'public_post', 'completed', 'founder', 8, 0, 2.0, '2026-02-20'::timestamptz, '2026-02-20'::timestamptz, 'Public correction post' from public.qstr_apology_letters_r3065 where incident_code='INC-006'
union all
select id, 'one_on_one_call', 'completed', 'founder', 28, 0, 18.0, '2026-04-08'::timestamptz, '2026-04-12'::timestamptz, '8 investor calls' from public.qstr_apology_letters_r3065 where incident_code='INC-007'
union all
select id, 'refund', 'completed', 'ops', 15, 95000, 3.0, '2026-04-15'::timestamptz, '2026-04-18'::timestamptz, 'AMC repricing + refund' from public.qstr_apology_letters_r3065 where incident_code='INC-008'
union all
select id, 'policy_change', 'completed', 'legal', 20, 0, 16.0, '2026-04-25'::timestamptz, '2026-05-05'::timestamptz, 'Engineer due-process policy' from public.qstr_apology_letters_r3065 where incident_code='INC-009'
union all
select id, 'sla_credit', 'completed', 'psm', 22, 540000, 8.0, '2026-05-05'::timestamptz, '2026-05-15'::timestamptz, 'SLA credit batch' from public.qstr_apology_letters_r3065 where incident_code='INC-010'
union all
select id, 'one_on_one_call', 'completed', 'legal', 14, 0, 6.0, '2026-05-20'::timestamptz, '2026-05-28'::timestamptz, 'Regulator call' from public.qstr_apology_letters_r3065 where incident_code='INC-011'
union all
select id, 'engineer_retraining', 'completed', 'engineer_lead', 16, 80000, 12.0, '2026-05-30'::timestamptz, '2026-06-05'::timestamptz, 'Tier-recalc retrain' from public.qstr_apology_letters_r3065 where incident_code='INC-012'
union all
select id, 'goodwill_credit', 'in_flight', 'psm', 0, 0, 4.0, '2026-07-05'::timestamptz, null::timestamptz, 'Pending founder sign' from public.qstr_apology_letters_r3065 where incident_code='INC-013'
union all
select id, 'public_post', 'completed', 'founder', 6, 0, 1.0, '2026-06-07'::timestamptz, '2026-06-07'::timestamptz, 'LinkedIn correction' from public.qstr_apology_letters_r3065 where incident_code='INC-014'
union all
select id, 'refund', 'in_flight', 'ops', 0, 310000, 6.0, '2026-07-01'::timestamptz, null::timestamptz, 'RTO refund batch' from public.qstr_apology_letters_r3065 where incident_code='INC-015'
union all
select id, 'engineer_retraining', 'completed', 'engineer_lead', 12, 180000, 20.0, '2026-06-25'::timestamptz, '2026-06-27'::timestamptz, 'Onboarding rewrite' from public.qstr_apology_letters_r3065 where incident_code='INC-016'
union all
select id, 'policy_change', 'queued', 'legal', 0, 0, 16.0, '2026-07-10'::timestamptz, null::timestamptz, 'GST template fix' from public.qstr_apology_letters_r3065 where incident_code='INC-017'
union all
select id, 'founder_visit', 'queued', 'founder', 0, 0, 12.0, '2026-07-15'::timestamptz, null::timestamptz, 'Manipal CXO meet' from public.qstr_apology_letters_r3065 where incident_code='INC-021'
union all
select id, 'one_on_one_call', 'blocked', 'legal', -5, 0, 8.0, '2026-07-08'::timestamptz, null::timestamptz, 'Forensics pending' from public.qstr_apology_letters_r3065 where incident_code='INC-020'
union all
select id, 'goodwill_credit', 'queued', 'psm', 0, 50000, 3.0, '2026-07-12'::timestamptz, null::timestamptz, 'Engineer collective goodwill' from public.qstr_apology_letters_r3065 where incident_code='INC-022';

-- ===== 7 RPCs =====

create or replace function public.qstr_letters_overview_r3065()
returns table(quarter text, total_letters int, published int, in_recovery int, restored int, total_restitution bigint, avg_sentiment numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.quarter,
    count(*)::int as total_letters,
    (count(*) filter (where l.letter_status='published'))::int as published,
    (count(*) filter (where l.recovery_state in ('not_started','in_progress')))::int as in_recovery,
    (count(*) filter (where l.recovery_state='trust_restored'))::int as restored,
    sum(l.restitution_rupees)::bigint as total_restitution,
    round(avg(nullif(l.apology_sentiment_score,0))::numeric, 1) as avg_sentiment
  from public.qstr_apology_letters_r3065 l
  group by l.quarter
  order by l.quarter;
end;$$;

create or replace function public.qstr_letters_by_audience_r3065()
returns table(audience text, letter_count int, avg_reach numeric, total_restitution bigint, restored_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audience,
    count(*)::int as letter_count,
    round(avg(l.reach_count)::numeric, 0) as avg_reach,
    sum(l.restitution_rupees)::bigint as total_restitution,
    round(100.0 * (count(*) filter (where l.recovery_state='trust_restored'))::numeric / nullif(count(*),0), 1) as restored_pct
  from public.qstr_apology_letters_r3065 l
  group by l.audience
  order by letter_count desc;
end;$$;

create or replace function public.qstr_severity_funnel_r3065()
returns table(severity text, total int, drafted int, published int, restored int, escalated int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.severity,
    count(*)::int as total,
    (count(*) filter (where l.letter_status='drafted'))::int as drafted,
    (count(*) filter (where l.letter_status='published'))::int as published,
    (count(*) filter (where l.recovery_state='trust_restored'))::int as restored,
    (count(*) filter (where l.recovery_state='escalated'))::int as escalated
  from public.qstr_apology_letters_r3065 l
  group by l.severity
  order by l.severity;
end;$$;

create or replace function public.qstr_open_letters_r3065()
returns table(incident_code text, incident_title text, severity text, audience text, letter_status text, drafted_at timestamptz, days_open int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.incident_code, l.incident_title, l.severity, l.audience, l.letter_status, l.drafted_at,
    extract(day from now() - l.drafted_at)::int as days_open
  from public.qstr_apology_letters_r3065 l
  where l.letter_status in ('drafted','founder_review','legal_review')
  order by l.drafted_at asc;
end;$$;

create or replace function public.qstr_recovery_actions_summary_r3065()
returns table(action_type text, total int, completed int, in_flight int, total_cost bigint, avg_trust_delta numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.action_type,
    count(*)::int as total,
    (count(*) filter (where a.action_status='completed'))::int as completed,
    (count(*) filter (where a.action_status='in_flight'))::int as in_flight,
    sum(a.cost_rupees)::bigint as total_cost,
    round(avg(a.trust_delta)::numeric, 1) as avg_trust_delta
  from public.qstr_recovery_actions_r3065 a
  group by a.action_type
  order by total desc;
end;$$;

create or replace function public.qstr_owner_workload_r3065()
returns table(owner_role text, action_count int, completed int, queued int, blocked int, total_hours numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.owner_role,
    count(*)::int as action_count,
    (count(*) filter (where a.action_status='completed'))::int as completed,
    (count(*) filter (where a.action_status='queued'))::int as queued,
    (count(*) filter (where a.action_status='blocked'))::int as blocked,
    sum(a.effort_hours)::numeric as total_hours
  from public.qstr_recovery_actions_r3065 a
  group by a.owner_role
  order by action_count desc;
end;$$;

create or replace function public.qstr_top_restitution_r3065()
returns table(incident_code text, incident_title text, audience text, restitution_rupees bigint, reach_count int, recovery_state text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.incident_code, l.incident_title, l.audience, l.restitution_rupees, l.reach_count, l.recovery_state
  from public.qstr_apology_letters_r3065 l
  where l.restitution_rupees > 0
  order by l.restitution_rupees desc
  limit 12;
end;$$;

revoke all on public.qstr_apology_letters_r3065 from public, anon;
revoke all on public.qstr_recovery_actions_r3065 from public, anon;
grant select on public.qstr_apology_letters_r3065 to authenticated;
grant select on public.qstr_recovery_actions_r3065 to authenticated;

revoke all on function public.qstr_letters_overview_r3065() from public, anon;
revoke all on function public.qstr_letters_by_audience_r3065() from public, anon;
revoke all on function public.qstr_severity_funnel_r3065() from public, anon;
revoke all on function public.qstr_open_letters_r3065() from public, anon;
revoke all on function public.qstr_recovery_actions_summary_r3065() from public, anon;
revoke all on function public.qstr_owner_workload_r3065() from public, anon;
revoke all on function public.qstr_top_restitution_r3065() from public, anon;

grant execute on function public.qstr_letters_overview_r3065() to authenticated;
grant execute on function public.qstr_letters_by_audience_r3065() to authenticated;
grant execute on function public.qstr_severity_funnel_r3065() to authenticated;
grant execute on function public.qstr_open_letters_r3065() to authenticated;
grant execute on function public.qstr_recovery_actions_summary_r3065() to authenticated;
grant execute on function public.qstr_owner_workload_r3065() to authenticated;
grant execute on function public.qstr_top_restitution_r3065() to authenticated;
