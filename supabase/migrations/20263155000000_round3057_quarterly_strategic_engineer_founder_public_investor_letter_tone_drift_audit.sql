-- Round r3057: Quarterly Strategic Engineer-Founder Public Investor Letter Tone Drift Audit
-- 2 tables + 7 RPCs (is_founder gated) + seeds

create table if not exists public.investor_letters_r3057 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  quarter text not null check (quarter in ('2024-Q1','2024-Q2','2024-Q3','2024-Q4','2025-Q1','2025-Q2','2025-Q3','2025-Q4','2026-Q1','2026-Q2')),
  author_role text not null check (author_role in ('founder','engineer_founder','co_ceo','interim_cfo')),
  letter_title text not null,
  word_count int not null,
  tone_label text not null check (tone_label in ('confident','measured','cautious','defensive','exuberant','contrite','neutral')),
  optimism_score numeric(4,2) not null,
  hedge_word_count int not null,
  first_person_singular_ratio numeric(4,2) not null,
  first_person_plural_ratio numeric(4,2) not null,
  drift_flag text not null check (drift_flag in ('stable','minor_drift','material_drift','reversal','escalation')),
  reviewer_note text
);

create table if not exists public.tone_drift_findings_r3057 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  letter_id uuid references public.investor_letters_r3057(id) on delete cascade,
  finding_kind text not null check (finding_kind in ('hedge_spike','exuberance_spike','blame_shift','missing_metric','tense_shift','passive_voice_spike','jargon_creep','contradiction_with_prior')),
  severity text not null check (severity in ('low','medium','high','critical')),
  excerpt text not null,
  delta_vs_prior numeric(5,2),
  resolution_status text not null check (resolution_status in ('open','acknowledged','rewritten','accepted','escalated_to_board')),
  owner text not null check (owner in ('founder','engineer_founder','co_ceo','interim_cfo','board_secretary'))
);

alter table public.investor_letters_r3057 enable row level security;
alter table public.tone_drift_findings_r3057 enable row level security;

drop policy if exists letters_r3057_founder_all on public.investor_letters_r3057;
create policy letters_r3057_founder_all on public.investor_letters_r3057 for all using (public.is_founder()) with check (public.is_founder());

drop policy if exists findings_r3057_founder_all on public.tone_drift_findings_r3057;
create policy findings_r3057_founder_all on public.tone_drift_findings_r3057 for all using (public.is_founder()) with check (public.is_founder());

insert into public.investor_letters_r3057 (quarter, author_role, letter_title, word_count, tone_label, optimism_score, hedge_word_count, first_person_singular_ratio, first_person_plural_ratio, drift_flag, reviewer_note) values
('2024-Q1','founder','Building the foundation',1820,'confident',0.78,12,0.04,0.22,'stable','Baseline tone'),
('2024-Q2','founder','Steady customer pull',1940,'confident',0.74,15,0.05,0.20,'stable','Hedge slightly up'),
('2024-Q3','engineer_founder','Engineering at scale',2210,'measured',0.62,28,0.08,0.18,'minor_drift','Engineer voice introduced'),
('2024-Q4','founder','Closing the year strong',2050,'exuberant',0.88,8,0.07,0.19,'material_drift','Exuberance vs Q3 measured'),
('2025-Q1','founder','Recalibrating growth',1780,'cautious',0.52,42,0.11,0.15,'reversal','Sharp pivot to cautious'),
('2025-Q2','co_ceo','Operating discipline',1990,'measured',0.60,31,0.06,0.21,'stable','Co-CEO debut'),
('2025-Q3','engineer_founder','Platform reliability wins',2330,'confident',0.71,18,0.09,0.17,'minor_drift','Reliability framing'),
('2025-Q4','founder','A reflective year-end',2110,'contrite',0.45,38,0.14,0.13,'escalation','Contrite tone first appearance'),
('2026-Q1','interim_cfo','Numbers speak first',1640,'neutral',0.58,22,0.02,0.24,'stable','CFO interim, fact-heavy'),
('2026-Q2','founder','Forward with focus',1875,'measured',0.66,19,0.06,0.20,'stable','Tone re-stabilized'),
('2026-Q1','engineer_founder','Build quality compounding',2060,'confident',0.73,16,0.10,0.18,'minor_drift','Parallel engineer letter'),
('2025-Q4','engineer_founder','Outage learnings',1920,'measured',0.56,34,0.12,0.14,'material_drift','Tone clash with founder Q4'),
('2025-Q1','engineer_founder','Resilience roadmap',1880,'cautious',0.50,40,0.09,0.16,'reversal','Concurrent reversal'),
('2024-Q4','engineer_founder','Throughput milestones',1990,'confident',0.80,11,0.08,0.20,'stable','Aligned with founder Q4'),
('2026-Q2','co_ceo','Margin expansion path',1870,'measured',0.64,24,0.05,0.22,'stable','Co-CEO on margins'),
('2024-Q2','engineer_founder','Test coverage milestone',1750,'confident',0.75,14,0.07,0.21,'stable','Aligned baseline'),
('2026-Q1','co_ceo','Customer concentration',1720,'cautious',0.49,36,0.04,0.23,'escalation','Concentration risk surfaced'),
('2025-Q3','founder','Compounding bets',2140,'exuberant',0.86,9,0.13,0.16,'material_drift','Exuberance vs co-CEO measured'),
('2024-Q3','founder','Two-CEO experiment',1950,'measured',0.63,26,0.09,0.19,'minor_drift','Governance shift signaled');

insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'exuberance_spike', 'high', 'best quarter ever, by far', 0.14, 'open', 'founder' from public.investor_letters_r3057 where letter_title='Closing the year strong' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'hedge_spike', 'high', 'we may, we might, we could', 27.00, 'rewritten', 'founder' from public.investor_letters_r3057 where letter_title='Recalibrating growth' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'contradiction_with_prior', 'critical', 'demand softened materially this quarter', -0.36, 'escalated_to_board', 'founder' from public.investor_letters_r3057 where letter_title='Recalibrating growth' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'missing_metric', 'medium', 'no churn disclosure', null, 'acknowledged', 'interim_cfo' from public.investor_letters_r3057 where letter_title='A reflective year-end' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'blame_shift', 'high', 'macro headwinds beyond our control', 0.22, 'rewritten', 'co_ceo' from public.investor_letters_r3057 where letter_title='Recalibrating growth' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'tense_shift', 'low', 'mixing past and present in same paragraph', null, 'accepted', 'board_secretary' from public.investor_letters_r3057 where letter_title='Steady customer pull' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'passive_voice_spike', 'medium', 'mistakes were made', 0.18, 'rewritten', 'founder' from public.investor_letters_r3057 where letter_title='A reflective year-end' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'jargon_creep', 'low', 'synergistic platform velocity', null, 'open', 'engineer_founder' from public.investor_letters_r3057 where letter_title='Platform reliability wins' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'exuberance_spike', 'medium', 'unstoppable compounding', 0.11, 'acknowledged', 'founder' from public.investor_letters_r3057 where letter_title='Compounding bets' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'contradiction_with_prior', 'high', 'concentration risk previously denied', 0.32, 'escalated_to_board', 'co_ceo' from public.investor_letters_r3057 where letter_title='Customer concentration' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'hedge_spike', 'medium', 'numerous instances of perhaps', 0.13, 'acknowledged', 'engineer_founder' from public.investor_letters_r3057 where letter_title='Outage learnings' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'missing_metric', 'high', 'no NPS or retention number', null, 'open', 'interim_cfo' from public.investor_letters_r3057 where letter_title='Forward with focus' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'jargon_creep', 'low', 'flywheel of flywheels', null, 'accepted', 'founder' from public.investor_letters_r3057 where letter_title='Two-CEO experiment' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'passive_voice_spike', 'low', 'targets were established', null, 'acknowledged', 'board_secretary' from public.investor_letters_r3057 where letter_title='Engineering at scale' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'blame_shift', 'medium', 'vendor-driven shortfall', 0.09, 'rewritten', 'engineer_founder' from public.investor_letters_r3057 where letter_title='Resilience roadmap' limit 1;
insert into public.tone_drift_findings_r3057 (letter_id, finding_kind, severity, excerpt, delta_vs_prior, resolution_status, owner)
select id, 'tense_shift', 'medium', 'past wins framed as current state', null, 'open', 'founder' from public.investor_letters_r3057 where letter_title='Closing the year strong' limit 1;

-- RPC 1: letter tone trend
create or replace function public.r3057_letter_tone_trend()
returns table (quarter text, avg_optimism numeric, avg_hedges numeric, letters int) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query select l.quarter, round(avg(l.optimism_score)::numeric,2), round(avg(l.hedge_word_count)::numeric,2), count(*)::int
    from public.investor_letters_r3057 l group by l.quarter order by l.quarter;
end$$;

-- RPC 2: drift flag distribution
create or replace function public.r3057_drift_flag_distribution()
returns table (drift_flag text, letters int, share_pct numeric) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query with t as (select count(*)::numeric as total from public.investor_letters_r3057)
    select l.drift_flag, count(*)::int, round(count(*)::numeric * 100 / (select total from t), 2)
    from public.investor_letters_r3057 l group by l.drift_flag order by count(*) desc;
end$$;

-- RPC 3: author voice comparison
create or replace function public.r3057_author_voice_compare()
returns table (author_role text, letters int, avg_optimism numeric, avg_singular numeric, avg_plural numeric) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query select l.author_role, count(*)::int, round(avg(l.optimism_score)::numeric,2), round(avg(l.first_person_singular_ratio)::numeric,2), round(avg(l.first_person_plural_ratio)::numeric,2)
    from public.investor_letters_r3057 l group by l.author_role order by avg(l.optimism_score) desc;
end$$;

-- RPC 4: findings by severity
create or replace function public.r3057_findings_by_severity()
returns table (severity text, findings int, open_count int, escalated_count int) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query select f.severity, count(*)::int,
    (count(*) filter (where f.resolution_status='open'))::int,
    (count(*) filter (where f.resolution_status='escalated_to_board'))::int
    from public.tone_drift_findings_r3057 f group by f.severity order by case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end;
end$$;

-- RPC 5: finding kind heatmap
create or replace function public.r3057_finding_kind_heatmap()
returns table (finding_kind text, total int, avg_delta numeric, critical_count int) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query select f.finding_kind, count(*)::int, round(avg(f.delta_vs_prior)::numeric,2),
    (count(*) filter (where f.severity='critical'))::int
    from public.tone_drift_findings_r3057 f group by f.finding_kind order by count(*) desc;
end$$;

-- RPC 6: tone reversal letters
create or replace function public.r3057_tone_reversal_letters()
returns table (quarter text, author_role text, letter_title text, tone_label text, optimism_score numeric, drift_flag text) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query select l.quarter, l.author_role, l.letter_title, l.tone_label, l.optimism_score, l.drift_flag
    from public.investor_letters_r3057 l where l.drift_flag in ('reversal','escalation','material_drift') order by l.quarter desc;
end$$;

-- RPC 7: owner workload
create or replace function public.r3057_owner_workload()
returns table (owner text, total int, open_count int, rewritten_count int, escalated_count int) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query select f.owner, count(*)::int,
    (count(*) filter (where f.resolution_status='open'))::int,
    (count(*) filter (where f.resolution_status='rewritten'))::int,
    (count(*) filter (where f.resolution_status='escalated_to_board'))::int
    from public.tone_drift_findings_r3057 f group by f.owner order by count(*) desc;
end$$;

-- RPC 8: cross-author tone gap same quarter
create or replace function public.r3057_cross_author_tone_gap()
returns table (quarter text, founder_optimism numeric, engineer_optimism numeric, gap numeric) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query select l.quarter,
    round(avg(l.optimism_score) filter (where l.author_role='founder')::numeric,2),
    round(avg(l.optimism_score) filter (where l.author_role='engineer_founder')::numeric,2),
    round((avg(l.optimism_score) filter (where l.author_role='founder') - avg(l.optimism_score) filter (where l.author_role='engineer_founder'))::numeric,2)
    from public.investor_letters_r3057 l
    group by l.quarter
    having count(*) filter (where l.author_role='founder') > 0 and count(*) filter (where l.author_role='engineer_founder') > 0
    order by l.quarter;
end$$;

revoke all on function public.r3057_letter_tone_trend() from public, anon;
revoke all on function public.r3057_drift_flag_distribution() from public, anon;
revoke all on function public.r3057_author_voice_compare() from public, anon;
revoke all on function public.r3057_findings_by_severity() from public, anon;
revoke all on function public.r3057_finding_kind_heatmap() from public, anon;
revoke all on function public.r3057_tone_reversal_letters() from public, anon;
revoke all on function public.r3057_owner_workload() from public, anon;
revoke all on function public.r3057_cross_author_tone_gap() from public, anon;

grant execute on function public.r3057_letter_tone_trend() to authenticated;
grant execute on function public.r3057_drift_flag_distribution() to authenticated;
grant execute on function public.r3057_author_voice_compare() to authenticated;
grant execute on function public.r3057_findings_by_severity() to authenticated;
grant execute on function public.r3057_finding_kind_heatmap() to authenticated;
grant execute on function public.r3057_tone_reversal_letters() to authenticated;
grant execute on function public.r3057_owner_workload() to authenticated;
grant execute on function public.r3057_cross_author_tone_gap() to authenticated;
