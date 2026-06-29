-- Round 2947 — Hospital Chain Quarterly Doctor-Survey Equipment-Confidence Net Score
-- HEAVY ★★★★ — 2 tables + 7 RPCs + seed data, is_founder gated

-- ============================================================
-- Table 1: hospital_chain_doctor_surveys_r2947
-- ============================================================
create table if not exists public.hospital_chain_doctor_surveys_r2947 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  quarter text not null check (quarter in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  invited_count int not null check (invited_count >= 0),
  responded_count int not null check (responded_count >= 0),
  survey_status text not null check (survey_status in ('open','closed','analyzing','published')),
  total_beds int not null check (total_beds > 0),
  hospitals_in_chain int not null check (hospitals_in_chain > 0),
  region text not null check (region in ('north','south','east','west','central')),
  launched_at timestamptz not null default now(),
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.hospital_chain_doctor_surveys_r2947 enable row level security;

-- ============================================================
-- Table 2: doctor_equipment_confidence_responses_r2947
-- ============================================================
create table if not exists public.doctor_equipment_confidence_responses_r2947 (
  id uuid primary key default gen_random_uuid(),
  survey_id uuid not null references public.hospital_chain_doctor_surveys_r2947(id) on delete cascade,
  doctor_specialty text not null check (doctor_specialty in ('cardiology','radiology','orthopedics','oncology','neurology','nephrology','pulmonology','general')),
  confidence_score int not null check (confidence_score between 0 and 10),
  category text not null check (category in ('promoter','passive','detractor')),
  equipment_class text not null check (equipment_class in ('class_a','class_b','class_c','class_d')),
  downtime_concern text not null check (downtime_concern in ('none','minor','moderate','severe')),
  free_text_flag boolean not null default false,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.doctor_equipment_confidence_responses_r2947 enable row level security;

-- ============================================================
-- Seed Table 1: 15 surveys across chains/quarters
-- ============================================================
insert into public.hospital_chain_doctor_surveys_r2947 (chain_name, quarter, invited_count, responded_count, survey_status, total_beds, hospitals_in_chain, region, launched_at, closed_at) values
('Apollo Hospitals', 'Q1-2026', 450, 312, 'published', 8500, 24, 'south', '2026-01-15'::timestamptz, '2026-02-15'::timestamptz),
('Fortis Healthcare', 'Q1-2026', 380, 248, 'published', 6200, 18, 'north', '2026-01-20'::timestamptz, '2026-02-20'::timestamptz),
('Manipal Hospitals', 'Q1-2026', 290, 195, 'published', 4800, 14, 'south', '2026-01-22'::timestamptz, '2026-02-22'::timestamptz),
('Max Healthcare', 'Q1-2026', 340, 221, 'published', 5500, 16, 'north', '2026-01-25'::timestamptz, '2026-02-25'::timestamptz),
('Narayana Health', 'Q1-2026', 410, 287, 'published', 7200, 21, 'south', '2026-01-28'::timestamptz, '2026-02-28'::timestamptz),
('Apollo Hospitals', 'Q2-2026', 470, 334, 'published', 8500, 24, 'south', '2026-04-10'::timestamptz, '2026-05-10'::timestamptz),
('Fortis Healthcare', 'Q2-2026', 390, 262, 'published', 6200, 18, 'north', '2026-04-12'::timestamptz, '2026-05-12'::timestamptz),
('Manipal Hospitals', 'Q2-2026', 300, 208, 'published', 4800, 14, 'south', '2026-04-15'::timestamptz, '2026-05-15'::timestamptz),
('Max Healthcare', 'Q2-2026', 350, 234, 'published', 5500, 16, 'north', '2026-04-18'::timestamptz, '2026-05-18'::timestamptz),
('Narayana Health', 'Q2-2026', 420, 298, 'published', 7200, 21, 'south', '2026-04-20'::timestamptz, '2026-05-20'::timestamptz),
('Columbia Asia', 'Q2-2026', 220, 142, 'published', 3400, 11, 'west', '2026-04-22'::timestamptz, '2026-05-22'::timestamptz),
('Apollo Hospitals', 'Q3-2026', 480, 0, 'open', 8500, 24, 'south', '2026-07-01'::timestamptz, null),
('Fortis Healthcare', 'Q3-2026', 395, 0, 'open', 6200, 18, 'north', '2026-07-03'::timestamptz, null),
('Manipal Hospitals', 'Q3-2026', 310, 87, 'analyzing', 4800, 14, 'south', '2026-07-05'::timestamptz, null),
('KIMS Hospitals', 'Q2-2026', 180, 128, 'published', 2800, 9, 'south', '2026-04-25'::timestamptz, '2026-05-25'::timestamptz);

-- ============================================================
-- Seed Table 2: 24 response buckets
-- ============================================================
insert into public.doctor_equipment_confidence_responses_r2947 (survey_id, doctor_specialty, confidence_score, category, equipment_class, downtime_concern, free_text_flag, submitted_at)
select id, 'cardiology', 9, 'promoter', 'class_a', 'none', false, launched_at + interval '5 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Apollo Hospitals' and quarter='Q1-2026'
union all select id, 'radiology', 8, 'passive', 'class_b', 'minor', false, launched_at + interval '6 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Apollo Hospitals' and quarter='Q1-2026'
union all select id, 'orthopedics', 5, 'detractor', 'class_c', 'moderate', true, launched_at + interval '7 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Apollo Hospitals' and quarter='Q1-2026'
union all select id, 'oncology', 9, 'promoter', 'class_a', 'none', false, launched_at + interval '8 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Apollo Hospitals' and quarter='Q2-2026'
union all select id, 'neurology', 10, 'promoter', 'class_a', 'none', false, launched_at + interval '4 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Apollo Hospitals' and quarter='Q2-2026'
union all select id, 'nephrology', 7, 'passive', 'class_b', 'minor', false, launched_at + interval '5 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Fortis Healthcare' and quarter='Q1-2026'
union all select id, 'cardiology', 4, 'detractor', 'class_c', 'severe', true, launched_at + interval '6 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Fortis Healthcare' and quarter='Q1-2026'
union all select id, 'pulmonology', 9, 'promoter', 'class_a', 'none', false, launched_at + interval '7 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Fortis Healthcare' and quarter='Q2-2026'
union all select id, 'general', 8, 'passive', 'class_b', 'minor', false, launched_at + interval '8 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Fortis Healthcare' and quarter='Q2-2026'
union all select id, 'radiology', 10, 'promoter', 'class_a', 'none', false, launched_at + interval '4 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Manipal Hospitals' and quarter='Q1-2026'
union all select id, 'orthopedics', 6, 'passive', 'class_b', 'moderate', false, launched_at + interval '5 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Manipal Hospitals' and quarter='Q1-2026'
union all select id, 'oncology', 3, 'detractor', 'class_d', 'severe', true, launched_at + interval '6 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Manipal Hospitals' and quarter='Q2-2026'
union all select id, 'cardiology', 9, 'promoter', 'class_a', 'none', false, launched_at + interval '7 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Max Healthcare' and quarter='Q1-2026'
union all select id, 'neurology', 8, 'passive', 'class_b', 'minor', false, launched_at + interval '5 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Max Healthcare' and quarter='Q1-2026'
union all select id, 'nephrology', 5, 'detractor', 'class_c', 'moderate', true, launched_at + interval '6 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Max Healthcare' and quarter='Q2-2026'
union all select id, 'pulmonology', 10, 'promoter', 'class_a', 'none', false, launched_at + interval '4 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Narayana Health' and quarter='Q1-2026'
union all select id, 'general', 9, 'promoter', 'class_a', 'none', false, launched_at + interval '5 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Narayana Health' and quarter='Q1-2026'
union all select id, 'cardiology', 7, 'passive', 'class_b', 'minor', false, launched_at + interval '6 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Narayana Health' and quarter='Q2-2026'
union all select id, 'radiology', 4, 'detractor', 'class_c', 'severe', true, launched_at + interval '7 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Narayana Health' and quarter='Q2-2026'
union all select id, 'orthopedics', 8, 'passive', 'class_b', 'minor', false, launched_at + interval '5 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Columbia Asia' and quarter='Q2-2026'
union all select id, 'oncology', 9, 'promoter', 'class_a', 'none', false, launched_at + interval '6 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Columbia Asia' and quarter='Q2-2026'
union all select id, 'neurology', 6, 'passive', 'class_b', 'moderate', false, launched_at + interval '7 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='Manipal Hospitals' and quarter='Q3-2026'
union all select id, 'cardiology', 10, 'promoter', 'class_a', 'none', false, launched_at + interval '4 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='KIMS Hospitals' and quarter='Q2-2026'
union all select id, 'general', 8, 'passive', 'class_b', 'minor', false, launched_at + interval '5 days' from public.hospital_chain_doctor_surveys_r2947 where chain_name='KIMS Hospitals' and quarter='Q2-2026';

-- ============================================================
-- RPC 1: chain_net_score_overview
-- ============================================================
create or replace function public.r2947_chain_net_score_overview()
returns table(chain_name text, total_responses int, promoters int, detractors int, net_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.chain_name,
         count(r.id)::int as total_responses,
         (count(*) filter (where r.category='promoter'))::int as promoters,
         (count(*) filter (where r.category='detractor'))::int as detractors,
         case when count(r.id) = 0 then 0
              else (((count(*) filter (where r.category='promoter'))::numeric
                    - (count(*) filter (where r.category='detractor'))::numeric)
                   * 100 / count(r.id)::numeric)::int end as net_score
  from public.hospital_chain_doctor_surveys_r2947 s
  left join public.doctor_equipment_confidence_responses_r2947 r on r.survey_id = s.id
  group by s.chain_name
  order by net_score desc nulls last;
end; $$;

-- ============================================================
-- RPC 2: quarterly_trend
-- ============================================================
create or replace function public.r2947_quarterly_trend()
returns table(quarter text, surveys_count int, total_responses int, promoters int, detractors int, net_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.quarter,
         count(distinct s.id)::int,
         count(r.id)::int,
         (count(*) filter (where r.category='promoter'))::int,
         (count(*) filter (where r.category='detractor'))::int,
         case when count(r.id) = 0 then 0
              else (((count(*) filter (where r.category='promoter'))::numeric
                    - (count(*) filter (where r.category='detractor'))::numeric)
                   * 100 / count(r.id)::numeric)::int end
  from public.hospital_chain_doctor_surveys_r2947 s
  left join public.doctor_equipment_confidence_responses_r2947 r on r.survey_id = s.id
  group by s.quarter
  order by s.quarter;
end; $$;

-- ============================================================
-- RPC 3: response_rate_by_chain
-- ============================================================
create or replace function public.r2947_response_rate_by_chain()
returns table(chain_name text, quarter text, invited int, responded int, response_pct int, survey_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.chain_name, s.quarter, s.invited_count, s.responded_count,
         case when s.invited_count = 0 then 0
              else (s.responded_count::numeric * 100 / s.invited_count::numeric)::int end,
         s.survey_status
  from public.hospital_chain_doctor_surveys_r2947 s
  order by s.quarter desc, s.chain_name;
end; $$;

-- ============================================================
-- RPC 4: specialty_breakdown
-- ============================================================
create or replace function public.r2947_specialty_breakdown()
returns table(specialty text, responses int, avg_score numeric, promoters int, detractors int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.doctor_specialty,
         count(*)::int,
         round(avg(r.confidence_score)::numeric, 2),
         (count(*) filter (where r.category='promoter'))::int,
         (count(*) filter (where r.category='detractor'))::int
  from public.doctor_equipment_confidence_responses_r2947 r
  group by r.doctor_specialty
  order by avg(r.confidence_score) desc;
end; $$;

-- ============================================================
-- RPC 5: detractor_alerts (severe downtime concerns)
-- ============================================================
create or replace function public.r2947_detractor_alerts()
returns table(chain_name text, quarter text, specialty text, equipment_class text, downtime_concern text, score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.chain_name, s.quarter, r.doctor_specialty, r.equipment_class, r.downtime_concern, r.confidence_score
  from public.doctor_equipment_confidence_responses_r2947 r
  join public.hospital_chain_doctor_surveys_r2947 s on s.id = r.survey_id
  where r.category = 'detractor' and r.downtime_concern in ('moderate','severe')
  order by r.confidence_score asc, s.chain_name;
end; $$;

-- ============================================================
-- RPC 6: equipment_class_confidence
-- ============================================================
create or replace function public.r2947_equipment_class_confidence()
returns table(equipment_class text, responses int, avg_score numeric, net_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.equipment_class,
         count(*)::int,
         round(avg(r.confidence_score)::numeric, 2),
         case when count(*) = 0 then 0
              else (((count(*) filter (where r.category='promoter'))::numeric
                    - (count(*) filter (where r.category='detractor'))::numeric)
                   * 100 / count(*)::numeric)::int end
  from public.doctor_equipment_confidence_responses_r2947 r
  group by r.equipment_class
  order by r.equipment_class;
end; $$;

-- ============================================================
-- RPC 7: region_summary
-- ============================================================
create or replace function public.r2947_region_summary()
returns table(region text, chains int, total_beds int, total_responses int, net_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.region,
         count(distinct s.chain_name)::int,
         sum(s.total_beds)::int,
         count(r.id)::int,
         case when count(r.id) = 0 then 0
              else (((count(*) filter (where r.category='promoter'))::numeric
                    - (count(*) filter (where r.category='detractor'))::numeric)
                   * 100 / count(r.id)::numeric)::int end
  from public.hospital_chain_doctor_surveys_r2947 s
  left join public.doctor_equipment_confidence_responses_r2947 r on r.survey_id = s.id
  group by s.region
  order by s.region;
end; $$;

-- ============================================================
-- Permissions
-- ============================================================
revoke all on public.hospital_chain_doctor_surveys_r2947 from public, anon;
revoke all on public.doctor_equipment_confidence_responses_r2947 from public, anon;

revoke all on function public.r2947_chain_net_score_overview() from public, anon;
revoke all on function public.r2947_quarterly_trend() from public, anon;
revoke all on function public.r2947_response_rate_by_chain() from public, anon;
revoke all on function public.r2947_specialty_breakdown() from public, anon;
revoke all on function public.r2947_detractor_alerts() from public, anon;
revoke all on function public.r2947_equipment_class_confidence() from public, anon;
revoke all on function public.r2947_region_summary() from public, anon;

grant execute on function public.r2947_chain_net_score_overview() to authenticated;
grant execute on function public.r2947_quarterly_trend() to authenticated;
grant execute on function public.r2947_response_rate_by_chain() to authenticated;
grant execute on function public.r2947_specialty_breakdown() to authenticated;
grant execute on function public.r2947_detractor_alerts() to authenticated;
grant execute on function public.r2947_equipment_class_confidence() to authenticated;
grant execute on function public.r2947_region_summary() to authenticated;
