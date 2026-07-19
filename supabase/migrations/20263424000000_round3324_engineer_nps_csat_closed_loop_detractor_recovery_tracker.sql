-- Round 3324: Engineer NPS/CSAT Closed-Loop Detractor-Recovery Tracker
-- CX closed-loop — feedback channel × score type × sentiment × primary gripe × 48h follow-up × root-cause × recovery action × loop verdict × CAPA

-- =============================================================================
-- TABLE 1: nps_recovery_r3324 — per-feedback-case detractor-recovery follow-through
-- =============================================================================
create table if not exists public.nps_recovery_r3324 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  region text not null,
  job_code text not null,
  feedback_channel text not null check (feedback_channel in (
    'post_visit_survey','phone_nps','email_csat','escalation','google_review'
  )),
  score_type text not null check (score_type in (
    'nps','csat_5star'
  )),
  score int not null,
  sentiment text not null check (sentiment in (
    'promoter','passive','detractor'
  )),
  primary_gripe text not null check (primary_gripe in (
    'delay','repeat_issue','behavior','billing','part_unavailable','communication','unresolved'
  )),
  followup_within_48h boolean not null,
  root_cause_identified boolean not null,
  recovery_action_taken text not null check (recovery_action_taken in (
    'apology_visit','free_service','credit_note','escalated_fix','manager_call','none'
  )),
  recovered_status text not null check (recovered_status in (
    'recovered','partially','unrecovered','churn_risk'
  )),
  rerated_score int,
  loop_verdict text not null check (loop_verdict in (
    'closed_recovered','closed_unrecovered','open_in_progress','open_overdue','escalated'
  )),
  feedback_date date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nps_recovery_r3324 enable row level security;

create index if not exists idx_nps_recovery_r3324_org on public.nps_recovery_r3324(organization_id);
create index if not exists idx_nps_recovery_r3324_date on public.nps_recovery_r3324(feedback_date);
create index if not exists idx_nps_recovery_r3324_verdict on public.nps_recovery_r3324(loop_verdict);

-- =============================================================================
-- TABLE 2: nps_recovery_capa_actions_r3324 — systemic CAPA fixes for recurring gripes
-- =============================================================================
create table if not exists public.nps_recovery_capa_actions_r3324 (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.nps_recovery_r3324(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'repeat_dispatch_delay','recurring_repeat_issue','behavior_complaint_pattern','billing_dispute_pattern',
    'parts_stockout_pattern','communication_gap_pattern','chronic_unresolved','sla_breach_cluster'
  )),
  root_cause text not null check (root_cause in (
    'regional_understaffing','spares_supply_chain','engineer_training_gap','crm_process_gap',
    'dispatch_scheduling_gap','oem_vendor_dependency','pending_investigation','no_systemic_cause'
  )),
  corrective_action text not null check (corrective_action in (
    'add_field_engineer','regional_spares_buffer','soft_skills_training','revise_sla_matrix',
    'crm_auto_escalation','dedicated_account_manager','root_cause_analysis','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  churn_risk_tier text not null check (churn_risk_tier in (
    'strategic_flagship','high_value_account','mid_value_account','low_value_account','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nps_recovery_capa_actions_r3324 enable row level security;

create index if not exists idx_nps_recovery_capa_r3324_case on public.nps_recovery_capa_actions_r3324(case_id);
create index if not exists idx_nps_recovery_capa_r3324_status on public.nps_recovery_capa_actions_r3324(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 feedback-case rows
  insert into public.nps_recovery_r3324 (
    organization_id, hospital_name, engineer_name, region, job_code,
    feedback_channel, score_type, score, sentiment, primary_gripe,
    followup_within_48h, root_cause_identified, recovery_action_taken, recovered_status, rerated_score,
    loop_verdict, feedback_date, notes
  )
  select v_org_id, q.hosp, q.eng, q.region, q.job,
    q.chan, q.stype, q.score, q.sent, q.gripe,
    q.f48, q.rci, q.rat, q.rst, q.rerate,
    q.verdict, q.fdate::date, q.nt
  from (values
    ('Apollo Chennai','Ramesh Iyer','South','JOB-CHN-4471','post_visit_survey','nps',3,'detractor','delay',
     true,true,'apology_visit','recovered',9,'closed_recovered','2026-07-14','Late 2 days on CT tube swap; apology visit + priority slot; re-rated 9'),
    ('Fortis Gurgaon','Amit Chauhan','North','JOB-GGN-8823','phone_nps','nps',4,'detractor','repeat_issue',
     true,true,'escalated_fix','recovered',8,'closed_recovered','2026-07-13','Ventilator alarm recurred; senior re-fixed board; passive on re-rate'),
    ('Manipal Bengaluru','Kavya Nair','South','JOB-BLR-2290','email_csat','csat_5star',2,'detractor','communication',
     true,false,'manager_call','partially',3,'open_in_progress','2026-07-13','No updates during 4-day repair; manager call done; root cause pending'),
    ('AIIMS Delhi','Suresh Yadav','North','JOB-DEL-1145','escalation','nps',1,'detractor','unresolved',
     false,true,'escalated_fix','churn_risk',null,'open_overdue','2026-07-11','Dialysis RO still down after 2 visits; 48h follow-up missed; churn risk'),
    ('CMC Vellore','Deepa Menon','South','JOB-VLR-6678','post_visit_survey','csat_5star',5,'promoter','delay',
     false,false,'none','recovered',null,'closed_recovered','2026-07-14','Minor delay noted but overall delighted; no recovery needed'),
    ('KIMS Hyderabad','Vikram Reddy','South','JOB-HYD-3391','google_review','nps',5,'detractor','billing',
     true,true,'credit_note','recovered',8,'closed_recovered','2026-07-12','Public 2-star review re AMC billing; credit note issued; review updated'),
    ('Fortis Mumbai Mulund','Prakash Shetty','West','JOB-MUM-7712','phone_nps','nps',6,'detractor','behavior',
     true,true,'apology_visit','partially',7,'open_in_progress','2026-07-12','Engineer curt with nursing staff; apology + soft-skills flag; partial recovery'),
    ('Max Saket Delhi','Neha Gupta','North','JOB-SKT-5540','email_csat','csat_5star',3,'detractor','part_unavailable',
     false,true,'escalated_fix','unrecovered',3,'open_overdue','2026-07-10','Probe out of stock 9 days; no 48h follow-up; still unrecovered'),
    ('Narayana Health Bengaluru','Kavya Nair','South','JOB-BLR-9903','post_visit_survey','nps',9,'promoter','delay',
     false,false,'none','recovered',null,'closed_recovered','2026-07-14','Promoter; praised turnaround on infusion pumps'),
    ('Medanta Gurgaon','Amit Chauhan','North','JOB-GGN-2214','phone_nps','nps',7,'passive','communication',
     false,false,'none','partially',null,'closed_unrecovered','2026-07-11','Passive; wanted clearer ETA comms; no action taken, loop closed unrecovered'),
    ('Yashoda Hyderabad','Vikram Reddy','South','JOB-HYD-8846','escalation','nps',2,'detractor','repeat_issue',
     true,true,'manager_call','churn_risk',4,'escalated','2026-07-13','Third repeat on same C-arm; escalated to regional head; churn risk'),
    ('Kokilaben Mumbai','Prakash Shetty','West','JOB-MUM-3358','email_csat','csat_5star',4,'passive','billing',
     false,false,'none','partially',null,'closed_unrecovered','2026-07-12','Passive; small billing query resolved on call; no formal recovery'),
    ('SGPGI Lucknow','Suresh Yadav','North','JOB-LKO-6621','post_visit_survey','csat_5star',1,'detractor','unresolved',
     true,false,'escalated_fix','unrecovered',2,'open_overdue','2026-07-10','Autoclave still failing sterilization cycle; root cause not found; overdue'),
    ('Aster Kochi','Deepa Menon','South','JOB-KOC-4409','google_review','nps',8,'passive','delay',
     false,true,'credit_note','recovered',9,'closed_recovered','2026-07-14','Passive review re slow parts; goodwill credit; re-rated promoter')
  ) as q(hosp, eng, region, job, chan, stype, score, sent, gripe, f48, rci, rat, rst, rerate, verdict, fdate, nt);

  -- CAPA seed — systemic fixes attached to at-risk cases via job_code
  insert into public.nps_recovery_capa_actions_r3324 (
    case_id, finding_category, root_cause, corrective_action,
    capa_status, churn_risk_tier, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.crt, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('JOB-DEL-1145','chronic_unresolved','regional_understaffing','add_field_engineer','open','strategic_flagship','2026-07-22',null,85000.00,'Dialysis RO repeat failures — sanction 2nd north-region engineer for renal accounts'),
    ('JOB-SKT-5540','parts_stockout_pattern','spares_supply_chain','regional_spares_buffer','in_progress','high_value_account','2026-07-20',null,60000.00,'Ultrasound probe 9-day stockout — stand up Delhi consignment buffer for critical spares'),
    ('JOB-HYD-8846','recurring_repeat_issue','oem_vendor_dependency','root_cause_analysis','escalated','high_value_account','2026-07-19',null,120000.00,'Third C-arm repeat — joint RCA with OEM on recurring image-intensifier fault'),
    ('JOB-MUM-7712','behavior_complaint_pattern','engineer_training_gap','soft_skills_training','in_progress','mid_value_account','2026-07-25',null,15000.00,'Behavior complaint pattern in West — enroll cohort in on-site soft-skills module'),
    ('JOB-LKO-6621','chronic_unresolved','pending_investigation','root_cause_analysis','overdue','high_value_account','2026-07-14',null,45000.00,'Autoclave sterilization cycle still failing — RCA past target date, escalate to OEM'),
    ('JOB-BLR-2290','communication_gap_pattern','crm_process_gap','crm_auto_escalation','verification_pending','mid_value_account','2026-07-18',null,22000.00,'Silent-repair complaints — CRM auto-status trigger at 24h/48h under verification'),
    ('JOB-HYD-3391','billing_dispute_pattern','crm_process_gap','dedicated_account_manager','closed','high_value_account','2026-07-16','2026-07-15',0.00,'AMC billing disputes — named account manager assigned, credit workflow closed')
  ) as q(job, fc, rc, ca, cst, crt, tcd, acd, cost, nt)
  join public.nps_recovery_r3324 e
    on e.organization_id = v_org_id and e.job_code = q.job;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Loop verdict distribution
create or replace function public.founder_r3324_loop_verdict_rollup()
returns table(loop_verdict text, cases bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nps_recovery_r3324)
  select l.loop_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nps_recovery_r3324 l
  group by l.loop_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3324_loop_verdict_rollup() from public, anon;
grant execute on function public.founder_r3324_loop_verdict_rollup() to authenticated;

-- 2) Engineer-level recovery scorecard
create or replace function public.founder_r3324_engineer_scorecard()
returns table(
  engineer_name text,
  total_cases bigint,
  promoters bigint,
  passives bigint,
  detractors bigint,
  recovered bigint,
  churn_risk bigint,
  followup_48h bigint,
  recovery_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.sentiment = 'promoter')::bigint,
    count(*) filter (where l.sentiment = 'passive')::bigint,
    count(*) filter (where l.sentiment = 'detractor')::bigint,
    count(*) filter (where l.recovered_status = 'recovered')::bigint,
    count(*) filter (where l.recovered_status = 'churn_risk')::bigint,
    count(*) filter (where l.followup_within_48h)::bigint,
    round(100.0 * count(*) filter (where l.recovered_status = 'recovered')::numeric
      / nullif(count(*) filter (where l.sentiment = 'detractor'),0), 1)
  from public.nps_recovery_r3324 l
  group by l.engineer_name
  order by count(*) filter (where l.sentiment = 'detractor') desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3324_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3324_engineer_scorecard() to authenticated;

-- 3) Feedback channel × sentiment matrix
create or replace function public.founder_r3324_channel_sentiment_matrix()
returns table(feedback_channel text, sentiment text, cases bigint, avg_score numeric, avg_rerated_score numeric, recovered bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.feedback_channel, l.sentiment, count(*)::bigint,
    round(avg(l.score), 1),
    round(avg(l.rerated_score), 1),
    count(*) filter (where l.recovered_status = 'recovered')::bigint
  from public.nps_recovery_r3324 l
  group by l.feedback_channel, l.sentiment
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3324_channel_sentiment_matrix() from public, anon;
grant execute on function public.founder_r3324_channel_sentiment_matrix() to authenticated;

-- 4) Daily feedback trend
create or replace function public.founder_r3324_daily_feedback_trend()
returns table(feedback_date date, cases bigint, detractors bigint, recovered bigint, churn_risk bigint, followup_48h bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.feedback_date,
    count(*)::bigint,
    count(*) filter (where l.sentiment = 'detractor')::bigint,
    count(*) filter (where l.recovered_status = 'recovered')::bigint,
    count(*) filter (where l.recovered_status = 'churn_risk')::bigint,
    count(*) filter (where l.followup_within_48h)::bigint
  from public.nps_recovery_r3324 l
  group by l.feedback_date
  order by l.feedback_date desc;
end;
$$;

revoke execute on function public.founder_r3324_daily_feedback_trend() from public, anon;
grant execute on function public.founder_r3324_daily_feedback_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3324_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.nps_recovery_capa_actions_r3324 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3324_capa_status_board() from public, anon;
grant execute on function public.founder_r3324_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3324_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nps_recovery_capa_actions_r3324)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nps_recovery_capa_actions_r3324 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3324_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3324_root_cause_pareto() to authenticated;

-- 7) Churn-risk / cost digest
create or replace function public.founder_r3324_churn_risk_digest()
returns table(churn_risk_tier text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.churn_risk_tier, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.nps_recovery_capa_actions_r3324 c
  group by c.churn_risk_tier
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3324_churn_risk_digest() from public, anon;
grant execute on function public.founder_r3324_churn_risk_digest() to authenticated;

-- 8) High-risk recovery queue (open detractor cases needing attention)
create or replace function public.founder_r3324_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  region text,
  job_code text,
  feedback_date date,
  score_type text,
  score int,
  primary_gripe text,
  recovered_status text,
  loop_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.region, l.job_code, l.feedback_date,
    l.score_type, l.score, l.primary_gripe, l.recovered_status, l.loop_verdict, l.notes
  from public.nps_recovery_r3324 l
  where l.sentiment = 'detractor'
     or l.recovered_status in ('unrecovered','churn_risk')
     or l.loop_verdict in ('open_in_progress','open_overdue','escalated')
     or (l.sentiment = 'detractor' and not l.followup_within_48h)
  order by
    case l.loop_verdict when 'escalated' then 0 when 'open_overdue' then 1 when 'open_in_progress' then 2 else 3 end,
    l.feedback_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3324_high_risk_queue() from public, anon;
grant execute on function public.founder_r3324_high_risk_queue() to authenticated;
