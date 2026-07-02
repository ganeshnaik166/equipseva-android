-- Round 3131: Founder Quarterly Strategic Engineer-Founder Investor Reference Call Outreach Engineering Tracker
-- Scope: founder-led inbound investor reference calls — investor x founder/customer reference x
--        call status x sentiment x outcome x follow-up commit x velocity.

begin;

-- ============================================================================
-- TABLE 1: investor reference call outreach
-- ============================================================================
create table if not exists public.investor_reference_call_outreach_r3131 (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  investor_firm   text not null,
  investor_lead   text not null,
  fund_stage      text not null check (fund_stage in (
                    'seed','pre_series_a','series_a','series_b','growth','strategic'
                  )),
  reference_type  text not null check (reference_type in (
                    'hospital_customer','engineer_partner','co_founder','channel_partner','clinical_kol'
                  )),
  reference_name  text not null,
  reference_org   text not null,
  call_status     text not null check (call_status in (
                    'queued','outreached','scheduled','completed','no_show','declined','rescheduled'
                  )),
  sentiment       text not null check (sentiment in (
                    'strong_positive','positive','neutral','mixed','negative','not_rated'
                  )),
  outcome         text not null check (outcome in (
                    'advanced_to_dd','advanced_to_term_sheet','requested_more_refs',
                    'parked','dropped','closed_won','closed_lost'
                  )),
  followup_commit text not null check (followup_commit in (
                    'investor_followup_owed','founder_followup_owed','reference_followup_owed',
                    'no_followup_needed','blocked_on_legal'
                  )),
  velocity_band   text not null check (velocity_band in (
                    'same_day','within_48h','within_week','within_fortnight','stale','dormant'
                  )),
  scheduled_at    timestamptz,
  completed_at    timestamptz,
  duration_min    int check (duration_min is null or duration_min between 0 and 240),
  call_score      numeric(4,2) check (call_score is null or call_score between 0 and 10),
  founder_notes   text,
  created_at      timestamptz not null default now()
);

create index if not exists idx_ircoutr_r3131_org      on public.investor_reference_call_outreach_r3131(organization_id);
create index if not exists idx_ircoutr_r3131_status   on public.investor_reference_call_outreach_r3131(call_status);
create index if not exists idx_ircoutr_r3131_outcome  on public.investor_reference_call_outreach_r3131(outcome);
create index if not exists idx_ircoutr_r3131_velocity on public.investor_reference_call_outreach_r3131(velocity_band);

alter table public.investor_reference_call_outreach_r3131 enable row level security;

-- ============================================================================
-- TABLE 2: reference call follow-up actions / commitments
-- ============================================================================
create table if not exists public.investor_reference_followup_actions_r3131 (
  id              uuid primary key default gen_random_uuid(),
  outreach_id     uuid not null references public.investor_reference_call_outreach_r3131(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  action_owner    text not null check (action_owner in (
                    'founder','investor','reference','ops','legal','finance'
                  )),
  action_type     text not null check (action_type in (
                    'send_data_room_link','share_amc_metrics','intro_second_reference',
                    'draft_term_sheet','book_factory_visit','share_engineer_attrition',
                    'send_unit_economics','share_nps_report','legal_clearance'
                  )),
  action_status   text not null check (action_status in (
                    'open','in_progress','blocked','completed','cancelled','overdue'
                  )),
  priority_band   text not null check (priority_band in (
                    'p0_critical','p1_high','p2_medium','p3_low','p4_backlog'
                  )),
  sla_band        text not null check (sla_band in (
                    'in_sla','at_risk','breached','recovered','no_sla'
                  )),
  due_at          timestamptz,
  completed_at    timestamptz,
  ageing_days     int check (ageing_days is null or ageing_days >= 0),
  founder_notes   text,
  created_at      timestamptz not null default now()
);

create index if not exists idx_irfu_r3131_outreach on public.investor_reference_followup_actions_r3131(outreach_id);
create index if not exists idx_irfu_r3131_status   on public.investor_reference_followup_actions_r3131(action_status);
create index if not exists idx_irfu_r3131_sla      on public.investor_reference_followup_actions_r3131(sla_band);

alter table public.investor_reference_followup_actions_r3131 enable row level security;

-- ============================================================================
-- SEED DATA (12+ rows split across both tables)
-- ============================================================================
with first_org as (select id from public.organizations order by created_at asc limit 1)
insert into public.investor_reference_call_outreach_r3131
  (organization_id, investor_firm, investor_lead, fund_stage, reference_type, reference_name, reference_org,
   call_status, sentiment, outcome, followup_commit, velocity_band,
   scheduled_at, completed_at, duration_min, call_score, founder_notes)
select fo.id, q.investor_firm, q.investor_lead, q.fund_stage, q.reference_type, q.reference_name, q.reference_org,
       q.call_status, q.sentiment, q.outcome, q.followup_commit, q.velocity_band,
       q.scheduled_at::timestamptz, q.completed_at::timestamptz, q.duration_min, q.call_score, q.founder_notes
from first_org fo, (values
  ('Peak XV Healthcare',     'Anika Reddy',    'series_a',     'hospital_customer', 'Dr Rao',            'Apollo Hyderabad',          'completed',   'strong_positive', 'advanced_to_term_sheet', 'investor_followup_owed', 'within_48h',     '2026-06-15 10:00+05:30', '2026-06-15 10:42+05:30', 42,   9.20, 'Dr Rao gave glowing AMC uptime numbers; Anika asking for term sheet draft'),
  ('Elevation Capital',      'Mukund Mohan',   'pre_series_a', 'engineer_partner',  'Suresh Iyer',       'Field Engineer Bengaluru',  'completed',   'positive',        'advanced_to_dd',         'founder_followup_owed',  'within_week',    '2026-06-12 16:00+05:30', '2026-06-12 16:35+05:30', 35,   8.10, 'Engineer attrition story landed well; need to send 12-month rotation data'),
  ('Lightspeed India',       'Rahul Taneja',   'series_b',     'hospital_customer', 'Sister Mariam',     'St John''s Bangalore',       'completed',   'positive',        'requested_more_refs',    'founder_followup_owed',  'within_48h',     '2026-06-18 11:00+05:30', '2026-06-18 11:30+05:30', 30,   7.80, 'Asked for 2 more Tier-2 references — Indore + Coimbatore queued'),
  ('Accel Partners',         'Prayank Swaroop','series_a',     'co_founder',        'Co-founder CTO',    'EquipSeva HQ',              'scheduled',   'not_rated',       'parked',                 'investor_followup_owed', 'within_week',    '2026-07-02 15:00+05:30', null,                     null, null, 'Investor lead asked for live walkthrough of triage RPC'),
  ('Matrix Partners',        'Tarun Davda',    'series_a',     'clinical_kol',      'Dr Khanna',         'AIIMS Delhi cardiology',    'completed',   'mixed',           'parked',                 'reference_followup_owed','within_fortnight','2026-06-08 09:30+05:30', '2026-06-08 10:15+05:30', 45,   6.20, 'KOL raised pricing concern — needs clarification email from Dr Khanna directly'),
  ('Nexus Venture Partners', 'Suvir Sujan',    'pre_series_a', 'channel_partner',   'Mehta Surgicals',   'Mumbai distributor',        'no_show',     'not_rated',       'dropped',                'founder_followup_owed',  'stale',          '2026-05-28 17:00+05:30', null,                     null, null, 'Channel partner skipped — bad signal; deprioritising this channel reference type'),
  ('Stellaris VP',           'Rahul Chowdhri', 'series_b',     'hospital_customer', 'Dr Padmaja',        'KIMS Secunderabad',         'completed',   'strong_positive', 'closed_won',             'no_followup_needed',     'same_day',       '2026-06-20 14:00+05:30', '2026-06-20 14:55+05:30', 55,   9.60, 'Closed-won signal — Stellaris committed lead cheque pending IC approval'),
  ('Blume Ventures',         'Karthik Reddy',  'seed',         'engineer_partner',  'Lakshmi Pillai',    'Field Engineer Kochi',      'declined',    'negative',        'dropped',                'no_followup_needed',     'dormant',        '2026-05-15 12:00+05:30', null,                     null, null, 'Engineer declined the call citing busy season — moving on'),
  ('Iron Pillar',            'Mohanjit Jolly', 'growth',       'hospital_customer', 'Dr Subramaniam',    'CMC Vellore',               'rescheduled', 'not_rated',       'parked',                 'reference_followup_owed','within_fortnight','2026-06-25 11:00+05:30', null,                     null, null, 'Dr Subramaniam moved call by a week; reference still warm'),
  ('Bessemer India',         'Vishal Gupta',   'series_a',     'clinical_kol',      'Dr Sengupta',       'Tata Medical Kolkata',      'outreached',  'not_rated',       'parked',                 'investor_followup_owed', 'within_week',    null,                     null,                     null, null, 'Sent calendar invite — awaiting confirmation'),
  ('Norwest Venture',        'Mohan Kumar',    'growth',       'hospital_customer', 'CEO Manipal',       'Manipal Bangalore',         'completed',   'positive',        'advanced_to_dd',         'investor_followup_owed', 'within_48h',     '2026-06-22 09:00+05:30', '2026-06-22 09:50+05:30', 50,   8.50, 'CEO Manipal pitched chain bulk story strongly; DD checklist incoming'),
  ('Sofina Capital',         'Sridhar Iyer',   'strategic',    'co_founder',        'Co-founder COO',    'EquipSeva HQ',              'queued',      'not_rated',       'parked',                 'founder_followup_owed',  'within_fortnight',null,                    null,                     null, null, 'Strategic — Sofina interested in cross-border SL/BD/NP angle; queue COO call'),
  ('Trifecta Capital',       'Rahul Khanna',   'series_b',     'hospital_customer', 'Dr Vasanth',        'Yashoda Hyderabad',         'completed',   'positive',        'requested_more_refs',    'founder_followup_owed',  'within_week',    '2026-06-10 15:30+05:30', '2026-06-10 16:10+05:30', 40,   7.90, 'Asked for AMC payment-first cohort retention proof — pulling cohort data'),
  ('Avaana Capital',         'Anjali Bansal',  'series_a',     'clinical_kol',      'Dr Anitha',         'NIMHANS Bangalore',         'completed',   'strong_positive', 'closed_won',             'no_followup_needed',     'same_day',       '2026-06-19 10:00+05:30', '2026-06-19 10:35+05:30', 35,   9.40, 'Avaana committed sustainability angle anchor cheque')
) as q(investor_firm, investor_lead, fund_stage, reference_type, reference_name, reference_org,
       call_status, sentiment, outcome, followup_commit, velocity_band,
       scheduled_at, completed_at, duration_min, call_score, founder_notes);

-- Follow-up actions tied to outreach rows
with first_outreach as (
  select id, organization_id from public.investor_reference_call_outreach_r3131 order by created_at asc limit 1
),
all_outreach as (
  select id, organization_id, row_number() over (order by created_at asc) as rn
  from public.investor_reference_call_outreach_r3131
)
insert into public.investor_reference_followup_actions_r3131
  (outreach_id, organization_id, action_owner, action_type, action_status, priority_band, sla_band,
   due_at, completed_at, ageing_days, founder_notes)
select coalesce(ao.id, fo.id), coalesce(ao.organization_id, fo.organization_id),
       q.action_owner, q.action_type, q.action_status, q.priority_band, q.sla_band,
       q.due_at::timestamptz, q.completed_at::timestamptz, q.ageing_days, q.founder_notes
from first_outreach fo
cross join (values
  (1, 'founder',   'send_data_room_link',      'completed',   'p0_critical', 'in_sla',   '2026-06-16 18:00+05:30', '2026-06-16 14:30+05:30', 0,  'Sent investor data room link to Anika same evening'),
  (2, 'founder',   'share_engineer_attrition', 'in_progress', 'p1_high',     'at_risk',  '2026-06-19 18:00+05:30', null,                     5,  'Pulling 12-month rotation data — eng analytics owner blocked'),
  (3, 'founder',   'intro_second_reference',   'completed',   'p1_high',     'in_sla',   '2026-06-20 18:00+05:30', '2026-06-19 11:00+05:30', 0,  'Intro mail sent to Indore + Coimbatore Tier-2 customers'),
  (4, 'ops',       'book_factory_visit',       'open',        'p2_medium',   'in_sla',   '2026-07-05 18:00+05:30', null,                     2,  'Factory visit calendar pending HQ confirmation'),
  (5, 'reference', 'share_nps_report',         'blocked',     'p1_high',     'breached', '2026-06-12 18:00+05:30', null,                     22, 'Dr Khanna AIIMS clarification mail not yet drafted — chase'),
  (6, 'founder',   'share_amc_metrics',        'cancelled',   'p3_low',      'no_sla',   null,                     null,                     null, 'Channel-partner track dropped; cancelling tied AMC metrics work'),
  (7, 'investor',  'draft_term_sheet',         'in_progress', 'p0_critical', 'in_sla',   '2026-07-10 18:00+05:30', null,                     5,  'Stellaris IC scheduled — term sheet draft owner = investor side'),
  (8, 'founder',   'send_unit_economics',      'completed',   'p2_medium',   'recovered','2026-06-26 18:00+05:30', '2026-06-25 16:00+05:30', 0,  'CMC Vellore reschedule — sent unit-econ pack to investor preemptively'),
  (9, 'investor',  'legal_clearance',          'overdue',     'p1_high',     'breached', '2026-06-15 18:00+05:30', null,                     17, 'Bessemer legal clearance overdue — kill switch on horizon'),
  (10,'finance',   'send_unit_economics',      'completed',   'p1_high',     'in_sla',   '2026-06-24 18:00+05:30', '2026-06-23 18:30+05:30', 0,  'Norwest DD checklist line 1 closed'),
  (11,'legal',     'legal_clearance',          'open',        'p2_medium',   'in_sla',   '2026-07-12 18:00+05:30', null,                     1,  'Sofina cross-border legal pre-check kicked off'),
  (12,'founder',   'share_amc_metrics',        'in_progress', 'p1_high',     'at_risk',  '2026-06-30 18:00+05:30', null,                     6,  'AMC payment-first cohort retention proof — partial pull done'),
  (13,'founder',   'share_nps_report',         'completed',   'p0_critical', 'in_sla',   '2026-06-21 18:00+05:30', '2026-06-20 09:00+05:30', 0,  'Avaana sustainability NPS pack delivered on close-won'),
  (14,'ops',       'book_factory_visit',       'open',        'p3_low',      'no_sla',   null,                     null,                     3,  'Factory visit nice-to-have follow-up for Trifecta')
) as q(target_rn, action_owner, action_type, action_status, priority_band, sla_band,
       due_at, completed_at, ageing_days, founder_notes)
left join all_outreach ao on ao.rn = q.target_rn;

-- ============================================================================
-- RPCs (founder-gated, SECURITY DEFINER plpgsql)
-- ============================================================================

-- RPC 1: outreach pipeline by call status
create or replace function public.rpc_r3131_outreach_status_pipeline()
returns table(call_status text, n bigint, avg_score numeric, total_duration_min bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.call_status,
           count(*)::bigint,
           round(avg(o.call_score)::numeric, 2),
           coalesce(sum(o.duration_min), 0)::bigint
    from public.investor_reference_call_outreach_r3131 o
    group by o.call_status
    order by count(*) desc;
end;
$fn$;

revoke execute on function public.rpc_r3131_outreach_status_pipeline() from public, anon;
grant execute on function public.rpc_r3131_outreach_status_pipeline() to authenticated;

-- RPC 2: sentiment x outcome rollup
create or replace function public.rpc_r3131_sentiment_outcome_matrix()
returns table(sentiment text, outcome text, n bigint, avg_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.sentiment, o.outcome,
           count(*)::bigint,
           round(avg(o.call_score)::numeric, 2)
    from public.investor_reference_call_outreach_r3131 o
    group by o.sentiment, o.outcome
    order by count(*) desc;
end;
$fn$;

revoke execute on function public.rpc_r3131_sentiment_outcome_matrix() from public, anon;
grant execute on function public.rpc_r3131_sentiment_outcome_matrix() to authenticated;

-- RPC 3: velocity band rollup
create or replace function public.rpc_r3131_velocity_rollup()
returns table(velocity_band text, n bigint, completed_n bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.velocity_band,
           count(*)::bigint,
           count(*) filter (where o.call_status = 'completed')::bigint
    from public.investor_reference_call_outreach_r3131 o
    group by o.velocity_band
    order by count(*) desc;
end;
$fn$;

revoke execute on function public.rpc_r3131_velocity_rollup() from public, anon;
grant execute on function public.rpc_r3131_velocity_rollup() to authenticated;

-- RPC 4: top investor leads by score
create or replace function public.rpc_r3131_top_investors()
returns table(investor_firm text, investor_lead text, n_calls bigint, avg_score numeric, best_outcome text)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.investor_firm, o.investor_lead,
           count(*)::bigint,
           round(avg(o.call_score)::numeric, 2),
           max(o.outcome)
    from public.investor_reference_call_outreach_r3131 o
    group by o.investor_firm, o.investor_lead
    order by avg(o.call_score) desc nulls last
    limit 20;
end;
$fn$;

revoke execute on function public.rpc_r3131_top_investors() from public, anon;
grant execute on function public.rpc_r3131_top_investors() to authenticated;

-- RPC 5: reference-type performance
create or replace function public.rpc_r3131_reference_type_performance()
returns table(reference_type text, n bigint, avg_score numeric, won_n bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.reference_type,
           count(*)::bigint,
           round(avg(o.call_score)::numeric, 2),
           count(*) filter (where o.outcome = 'closed_won')::bigint
    from public.investor_reference_call_outreach_r3131 o
    group by o.reference_type
    order by count(*) filter (where o.outcome = 'closed_won') desc, count(*) desc;
end;
$fn$;

revoke execute on function public.rpc_r3131_reference_type_performance() from public, anon;
grant execute on function public.rpc_r3131_reference_type_performance() to authenticated;

-- RPC 6: follow-up SLA breach rollup
create or replace function public.rpc_r3131_followup_sla_rollup()
returns table(sla_band text, action_status text, n bigint, avg_ageing numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.sla_band, a.action_status,
           count(*)::bigint,
           round(avg(a.ageing_days)::numeric, 1)
    from public.investor_reference_followup_actions_r3131 a
    group by a.sla_band, a.action_status
    order by count(*) desc;
end;
$fn$;

revoke execute on function public.rpc_r3131_followup_sla_rollup() from public, anon;
grant execute on function public.rpc_r3131_followup_sla_rollup() to authenticated;

-- RPC 7: action owner load
create or replace function public.rpc_r3131_action_owner_load()
returns table(action_owner text, open_n bigint, breached_n bigint, completed_n bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.action_owner,
           count(*) filter (where a.action_status in ('open','in_progress'))::bigint,
           count(*) filter (where a.sla_band = 'breached')::bigint,
           count(*) filter (where a.action_status = 'completed')::bigint
    from public.investor_reference_followup_actions_r3131 a
    group by a.action_owner
    order by count(*) filter (where a.sla_band = 'breached') desc, count(*) desc;
end;
$fn$;

revoke execute on function public.rpc_r3131_action_owner_load() from public, anon;
grant execute on function public.rpc_r3131_action_owner_load() to authenticated;

-- RPC 8: priority x action-type matrix
create or replace function public.rpc_r3131_priority_action_matrix()
returns table(priority_band text, action_type text, n bigint, overdue_n bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.priority_band, a.action_type,
           count(*)::bigint,
           count(*) filter (where a.action_status = 'overdue' or a.sla_band = 'breached')::bigint
    from public.investor_reference_followup_actions_r3131 a
    group by a.priority_band, a.action_type
    order by count(*) desc;
end;
$fn$;

revoke execute on function public.rpc_r3131_priority_action_matrix() from public, anon;
grant execute on function public.rpc_r3131_priority_action_matrix() to authenticated;

-- RPC 9: hot follow-ups (overdue / breached)
create or replace function public.rpc_r3131_hot_followups()
returns table(action_owner text, action_type text, priority_band text, sla_band text, ageing_days int, founder_notes text)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.action_owner, a.action_type, a.priority_band, a.sla_band, a.ageing_days, a.founder_notes
    from public.investor_reference_followup_actions_r3131 a
    where a.sla_band in ('breached','at_risk') or a.action_status in ('overdue','blocked')
    order by case a.sla_band when 'breached' then 0 when 'at_risk' then 1 else 2 end,
             a.ageing_days desc nulls last
    limit 25;
end;
$fn$;

revoke execute on function public.rpc_r3131_hot_followups() from public, anon;
grant execute on function public.rpc_r3131_hot_followups() to authenticated;

commit;
