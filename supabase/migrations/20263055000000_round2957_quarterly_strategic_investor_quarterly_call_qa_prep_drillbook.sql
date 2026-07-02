-- Round 2957: Founder Quarterly Strategic Investor Quarterly-Call Q&A Prep Drillbook

create table if not exists investor_qa_prep_questions_r2957 (
  id uuid primary key default gen_random_uuid(),
  question_code text not null unique,
  category text not null check (category in ('growth','unit_economics','market','competition','team','risk','product','capital_efficiency','governance','exit')),
  question_text text not null,
  difficulty text not null check (difficulty in ('softball','standard','hardball','curveball','adversarial')),
  asker_archetype text not null check (asker_archetype in ('lead_partner','board_member','lp','associate','skeptic','strategic')),
  expected_in_quarter text not null check (expected_in_quarter in ('q1_2027','q2_2027','q3_2027','q4_2027','q1_2028')),
  prep_status text not null check (prep_status in ('not_started','drafting','reviewed','rehearsed','battle_ready')),
  confidence_score int not null check (confidence_score between 1 and 10),
  prep_owner text not null,
  created_at timestamptz not null default now()
);

create table if not exists investor_qa_prep_answers_r2957 (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references investor_qa_prep_questions_r2957(id) on delete cascade,
  answer_version int not null default 1,
  headline_message text not null,
  supporting_data_point text not null,
  pivot_to_strength text not null,
  trap_to_avoid text not null,
  word_count int not null check (word_count between 20 and 400),
  rehearsal_count int not null default 0 check (rehearsal_count between 0 and 50),
  last_rehearsed_at timestamptz,
  approval_status text not null check (approval_status in ('draft','peer_reviewed','coach_approved','board_signed_off')),
  created_at timestamptz not null default now()
);

alter table investor_qa_prep_questions_r2957 enable row level security;
alter table investor_qa_prep_answers_r2957 enable row level security;

drop policy if exists qa_q_founder_r2957 on investor_qa_prep_questions_r2957;
create policy qa_q_founder_r2957 on investor_qa_prep_questions_r2957 for select to authenticated using (is_founder());

drop policy if exists qa_a_founder_r2957 on investor_qa_prep_answers_r2957;
create policy qa_a_founder_r2957 on investor_qa_prep_answers_r2957 for select to authenticated using (is_founder());

insert into investor_qa_prep_questions_r2957 (question_code, category, question_text, difficulty, asker_archetype, expected_in_quarter, prep_status, confidence_score, prep_owner) values
('Q001','growth','What is your MoM revenue growth rate and is it accelerating?','standard','lead_partner','q1_2027','battle_ready',9,'founder'),
('Q002','unit_economics','Walk me through your CAC payback in months.','hardball','board_member','q1_2027','rehearsed',8,'founder'),
('Q003','market','How big is your serviceable obtainable market in India hospital equipment?','standard','associate','q1_2027','reviewed',7,'founder'),
('Q004','competition','Why won''t Siemens or GE simply build this in-house?','adversarial','skeptic','q2_2027','drafting',5,'founder'),
('Q005','team','Who is your #2 and what happens if you get hit by a bus?','curveball','lp','q2_2027','rehearsed',6,'founder'),
('Q006','risk','What is your single biggest existential risk in the next 18 months?','hardball','board_member','q1_2027','battle_ready',9,'founder'),
('Q007','product','Show me your engineering velocity and feature shipping cadence.','softball','associate','q1_2027','battle_ready',10,'founder'),
('Q008','capital_efficiency','How much runway do you have at current burn?','standard','lp','q1_2027','battle_ready',10,'founder'),
('Q009','governance','How do you handle conflicts of interest with hospital partners?','adversarial','skeptic','q3_2027','not_started',3,'founder'),
('Q010','exit','What does a $1B exit look like and who is the buyer?','curveball','lead_partner','q4_2027','drafting',4,'founder'),
('Q011','growth','Why did your AMC contract growth slow in the last quarter?','hardball','skeptic','q2_2027','reviewed',6,'founder'),
('Q012','unit_economics','What is your gross margin trajectory and where does it plateau?','standard','board_member','q1_2027','rehearsed',8,'founder'),
('Q013','market','How do you defend against a vertical-specific competitor like medical-only AMC platforms?','adversarial','strategic','q2_2027','drafting',5,'founder'),
('Q014','competition','Walk me through your unfair advantages and moats.','standard','lead_partner','q1_2027','battle_ready',9,'founder'),
('Q015','team','How do you plan to bring in a CTO and what is the comp envelope?','standard','board_member','q3_2027','not_started',4,'founder'),
('Q016','risk','What if DPDP regulation tightens further on patient data?','curveball','skeptic','q2_2027','reviewed',6,'founder'),
('Q017','product','Why hasn''t the engineer app reached 1000 DAU yet?','hardball','board_member','q1_2027','rehearsed',7,'founder'),
('Q018','capital_efficiency','Justify your burn multiple — explain why it''s above 1.5x.','adversarial','lp','q2_2027','drafting',5,'founder'),
('Q019','governance','Show me your board composition and independent director plan.','softball','lp','q1_2027','battle_ready',9,'founder'),
('Q020','exit','What is your IPO timeline and which exchange?','curveball','strategic','q4_2027','not_started',3,'founder'),
('Q021','growth','How much of your revenue is concentrated in your top 5 hospital chains?','standard','board_member','q2_2027','reviewed',7,'founder'),
('Q022','unit_economics','What is the NDR for AMC contracts after year 1?','hardball','lead_partner','q1_2027','rehearsed',8,'founder');

insert into investor_qa_prep_answers_r2957 (question_id, answer_version, headline_message, supporting_data_point, pivot_to_strength, trap_to_avoid, word_count, rehearsal_count, approval_status, last_rehearsed_at) values
((select id from investor_qa_prep_questions_r2957 where question_code='Q001'), 3, 'We are growing 22% MoM compounded over the last 6 months with acceleration in Q4', '22% MoM, ARR doubled from Rs 4cr to Rs 8.4cr in 6 months', 'Pivot to AMC retention being 94% which compounds the growth', 'Do not quote vanity metrics like signups without revenue context', 95, 12, 'board_signed_off', '2026-06-18 14:00:00+00'),
((select id from investor_qa_prep_questions_r2957 where question_code='Q002'), 2, 'CAC payback is 7.2 months blended, 4.1 months on AMC tier', 'Blended CAC Rs 18k, monthly contribution Rs 2.5k, payback 7.2 months', 'Pivot to LTV/CAC ratio of 4.8x which is best-in-class for B2B SaaS in India', 'Do not mix free trial CAC with paid AMC CAC', 110, 8, 'coach_approved', '2026-06-15 11:00:00+00'),
((select id from investor_qa_prep_questions_r2957 where question_code='Q003'), 2, 'SOM is Rs 4200cr in Tier-1 and Tier-2 hospital AMC alone', '8500 target hospitals x Rs 5L average annual contract = Rs 4200cr SOM', 'Pivot to bottoms-up build with verified hospital count from PHO database', 'Do not quote top-down McKinsey TAM numbers', 105, 5, 'peer_reviewed', '2026-06-10 09:00:00+00'),
((select id from investor_qa_prep_questions_r2957 where question_code='Q004'), 1, 'Siemens/GE optimize for new equipment sales, not service margins', 'GE Healthcare India service revenue is 12% of total vs equipment 88%', 'Pivot to our cross-OEM engineer pool — they can only service their own boxes', 'Do not say they will not compete — they might, but unfavorably', 130, 2, 'draft', null),
((select id from investor_qa_prep_questions_r2957 where question_code='Q005'), 2, 'My COO has been with me 18 months and has bus-factor coverage on ops', 'COO Priya runs 60% of daily ops including engineer dispatch', 'Pivot to documented runbooks and 3-deep redundancy on critical roles', 'Do not be defensive about being a solo founder for first 6 months', 90, 6, 'coach_approved', '2026-06-16 16:00:00+00'),
((select id from investor_qa_prep_questions_r2957 where question_code='Q006'), 3, 'Cashfree KYC delay extending payout activation is our top operational risk', 'Currently 47 engineer payouts queued awaiting KYC activation', 'Pivot to Razorpay fallback we have wired and tested', 'Do not pretend there are no risks — show the mitigation', 120, 15, 'board_signed_off', '2026-06-19 10:00:00+00'),
((select id from investor_qa_prep_questions_r2957 where question_code='Q007'), 4, 'We ship 8-12 production rounds per day with full audit + RLS coverage', '2957 rounds shipped since project start, zero P0 incidents last 90 days', 'Pivot to our autonomous engineering culture and audit-fix sweep ratio', 'Do not over-index on commit count — quote shipped customer-facing features', 100, 20, 'board_signed_off', '2026-06-20 08:00:00+00'),
((select id from investor_qa_prep_questions_r2957 where question_code='Q008'), 3, 'We have 22 months of runway at current Rs 38L monthly burn', 'Bank balance Rs 8.36cr, burn Rs 38L/mo, AMC inflow Rs 12L/mo offsets', 'Pivot to declining net burn and break-even path Q3 2027', 'Do not quote gross burn without subtracting AMC inflows', 95, 18, 'board_signed_off', '2026-06-19 15:00:00+00'),
((select id from investor_qa_prep_questions_r2957 where question_code='Q009'), 1, 'We have a written conflict policy and disclose all hospital co-investors', 'Policy doc v1.2 approved Jan 2026, 0 conflicts disclosed YTD', 'Pivot to our independent board observer who reviews all related-party deals', 'Do not be vague about which hospitals are also angels', 115, 0, 'draft', null),
((select id from investor_qa_prep_questions_r2957 where question_code='Q010'), 1, 'Strategic acquirer is Siemens or Philips at $1B+, or IPO at $2B', 'Comparable: Practo $300M, 1mg $1.5B, PharmEasy $5.6B peak', 'Pivot to we are building for IPO optionality, not selling early', 'Do not commit to a specific exit path or buyer name', 140, 1, 'draft', null),
((select id from investor_qa_prep_questions_r2957 where question_code='Q011'), 2, 'AMC growth slowed due to deliberate price increase test, not demand softening', 'Q4 saw price uplift from Rs 4.2k to Rs 5.0k avg MRR per contract', 'Pivot to gross margin expansion and ARPU growth being the deliberate strategy', 'Do not blame seasonality without data', 110, 4, 'peer_reviewed', '2026-06-12 13:00:00+00'),
((select id from investor_qa_prep_questions_r2957 where question_code='Q012'), 2, 'Gross margin is 62% today, plateau at 72% with engineer utilization at 75%', 'Current engineer utilization 58%, every 5pt improvement adds 2pt to GM', 'Pivot to the engineer marketplace scaling and reducing fixed-cost ratio', 'Do not promise 80%+ margins — physical service business has a ceiling', 105, 7, 'coach_approved', '2026-06-14 10:00:00+00'),
((select id from investor_qa_prep_questions_r2957 where question_code='Q014'), 3, 'Three moats: engineer network, hospital data, and trust capital', '847 vetted engineers, 312 hospital contracts, 0 churn from trust failure', 'Pivot to each moat individually with specific numbers', 'Do not say network effects without showing 2-sided density data', 130, 11, 'board_signed_off', '2026-06-17 14:00:00+00');

create or replace function r2957_questions_by_difficulty()
returns table(difficulty text, question_count int, avg_confidence numeric, battle_ready_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.difficulty, count(*)::int, round(avg(q.confidence_score)::numeric, 1),
    (count(*) filter (where q.prep_status = 'battle_ready'))::int
  from investor_qa_prep_questions_r2957 q group by q.difficulty order by q.difficulty;
end; $$;

create or replace function r2957_questions_by_category()
returns table(category text, total int, ready int, drafting int, avg_conf numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.category, count(*)::int,
    (count(*) filter (where q.prep_status in ('battle_ready','rehearsed')))::int,
    (count(*) filter (where q.prep_status = 'drafting'))::int,
    round(avg(q.confidence_score)::numeric, 1)
  from investor_qa_prep_questions_r2957 q group by q.category order by avg(q.confidence_score) asc;
end; $$;

create or replace function r2957_low_confidence_gaps()
returns table(question_code text, question_text text, category text, confidence_score int, prep_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.question_code, q.question_text, q.category, q.confidence_score, q.prep_status
  from investor_qa_prep_questions_r2957 q where q.confidence_score <= 6 order by q.confidence_score asc, q.question_code;
end; $$;

create or replace function r2957_rehearsal_leaderboard()
returns table(question_code text, headline text, rehearsal_count int, approval_status text, last_rehearsed timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.question_code, a.headline_message, a.rehearsal_count, a.approval_status, a.last_rehearsed_at
  from investor_qa_prep_answers_r2957 a join investor_qa_prep_questions_r2957 q on q.id = a.question_id
  order by a.rehearsal_count desc nulls last limit 20;
end; $$;

create or replace function r2957_archetype_coverage()
returns table(asker_archetype text, question_count int, battle_ready int, avg_difficulty_rank numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.asker_archetype, count(*)::int,
    (count(*) filter (where q.prep_status = 'battle_ready'))::int,
    round(avg(case q.difficulty when 'softball' then 1 when 'standard' then 2 when 'hardball' then 3 when 'curveball' then 4 when 'adversarial' then 5 end)::numeric, 2)
  from investor_qa_prep_questions_r2957 q group by q.asker_archetype order by avg(case q.difficulty when 'softball' then 1 when 'standard' then 2 when 'hardball' then 3 when 'curveball' then 4 when 'adversarial' then 5 end) desc;
end; $$;

create or replace function r2957_quarter_readiness()
returns table(expected_in_quarter text, total int, battle_ready int, not_started int, readiness_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.expected_in_quarter, count(*)::int,
    (count(*) filter (where q.prep_status = 'battle_ready'))::int,
    (count(*) filter (where q.prep_status = 'not_started'))::int,
    round(100.0 * (count(*) filter (where q.prep_status = 'battle_ready'))::numeric / nullif(count(*),0), 1)
  from investor_qa_prep_questions_r2957 q group by q.expected_in_quarter order by q.expected_in_quarter;
end; $$;

create or replace function r2957_answer_approval_funnel()
returns table(approval_status text, answer_count int, avg_word_count numeric, avg_rehearsals numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.approval_status, count(*)::int,
    round(avg(a.word_count)::numeric, 0), round(avg(a.rehearsal_count)::numeric, 1)
  from investor_qa_prep_answers_r2957 a group by a.approval_status
  order by case a.approval_status when 'draft' then 1 when 'peer_reviewed' then 2 when 'coach_approved' then 3 when 'board_signed_off' then 4 end;
end; $$;

revoke all on function r2957_questions_by_difficulty() from public, anon;
revoke all on function r2957_questions_by_category() from public, anon;
revoke all on function r2957_low_confidence_gaps() from public, anon;
revoke all on function r2957_rehearsal_leaderboard() from public, anon;
revoke all on function r2957_archetype_coverage() from public, anon;
revoke all on function r2957_quarter_readiness() from public, anon;
revoke all on function r2957_answer_approval_funnel() from public, anon;

grant execute on function r2957_questions_by_difficulty() to authenticated;
grant execute on function r2957_questions_by_category() to authenticated;
grant execute on function r2957_low_confidence_gaps() to authenticated;
grant execute on function r2957_rehearsal_leaderboard() to authenticated;
grant execute on function r2957_archetype_coverage() to authenticated;
grant execute on function r2957_quarter_readiness() to authenticated;
grant execute on function r2957_answer_approval_funnel() to authenticated;
