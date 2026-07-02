-- Round 3045: Founder Quarterly Strategic Engineer-Founder Local-Language Tier-2 Outreach Effectiveness Audit

create table if not exists tier2_outreach_sessions_r3045 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  quarter text not null check (quarter in ('Q1','Q2','Q3','Q4')),
  fiscal_year int not null check (fiscal_year between 2024 and 2030),
  tier2_city text not null,
  state_code text not null check (state_code in ('TS','AP','KA','TN','MH','GJ','UP','MP','RJ','WB','OR','KL','HR','PB')),
  local_language text not null check (local_language in ('telugu','tamil','kannada','marathi','gujarati','hindi','punjabi','bengali','odia','malayalam')),
  engineer_count int not null check (engineer_count between 0 and 500),
  attendance_count int not null check (attendance_count between 0 and 500),
  founder_present boolean not null default true,
  session_duration_minutes int not null check (session_duration_minutes between 15 and 360),
  nps_score numeric(4,2) not null check (nps_score between -100 and 100),
  conversion_pct numeric(5,2) not null check (conversion_pct between 0 and 100),
  effectiveness_band text not null check (effectiveness_band in ('exceptional','strong','adequate','weak','poor')),
  session_date date not null
);

create table if not exists tier2_outreach_followups_r3045 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  session_id uuid references tier2_outreach_sessions_r3045(id) on delete cascade,
  followup_kind text not null check (followup_kind in ('whatsapp_local','phone_call','site_visit','training_invite','contract_offer','referral_bonus')),
  language_used text not null check (language_used in ('telugu','tamil','kannada','marathi','gujarati','hindi','punjabi','bengali','odia','malayalam')),
  outreach_count int not null check (outreach_count between 0 and 5000),
  response_count int not null check (response_count between 0 and 5000),
  conversion_count int not null check (conversion_count between 0 and 5000),
  revenue_rupees bigint not null check (revenue_rupees between 0 and 100000000),
  cost_rupees bigint not null check (cost_rupees between 0 and 10000000),
  status text not null check (status in ('planned','in_progress','completed','blocked','cancelled')),
  followup_date date not null
);

alter table tier2_outreach_sessions_r3045 enable row level security;
alter table tier2_outreach_followups_r3045 enable row level security;

drop policy if exists tier2_outreach_sessions_r3045_select on tier2_outreach_sessions_r3045;
create policy tier2_outreach_sessions_r3045_select on tier2_outreach_sessions_r3045 for select using (is_founder());

drop policy if exists tier2_outreach_followups_r3045_select on tier2_outreach_followups_r3045;
create policy tier2_outreach_followups_r3045_select on tier2_outreach_followups_r3045 for select using (is_founder());

insert into tier2_outreach_sessions_r3045 (quarter, fiscal_year, tier2_city, state_code, local_language, engineer_count, attendance_count, founder_present, session_duration_minutes, nps_score, conversion_pct, effectiveness_band, session_date) values
  ('Q1', 2026, 'Warangal', 'TS', 'telugu', 45, 42, true, 120, 72.50, 68.20, 'exceptional', '2026-01-15'::date),
  ('Q1', 2026, 'Vijayawada', 'AP', 'telugu', 38, 35, true, 90, 65.00, 58.40, 'strong', '2026-01-22'::date),
  ('Q1', 2026, 'Mysuru', 'KA', 'kannada', 52, 48, true, 150, 70.00, 64.50, 'exceptional', '2026-02-05'::date),
  ('Q1', 2026, 'Madurai', 'TN', 'tamil', 41, 38, true, 100, 60.00, 52.30, 'strong', '2026-02-12'::date),
  ('Q1', 2026, 'Nashik', 'MH', 'marathi', 33, 28, true, 90, 55.00, 48.10, 'adequate', '2026-02-20'::date),
  ('Q2', 2026, 'Rajkot', 'GJ', 'gujarati', 47, 44, true, 120, 68.50, 62.00, 'strong', '2026-04-10'::date),
  ('Q2', 2026, 'Varanasi', 'UP', 'hindi', 29, 25, true, 75, 45.00, 38.70, 'adequate', '2026-04-18'::date),
  ('Q2', 2026, 'Indore', 'MP', 'hindi', 55, 52, true, 135, 75.00, 71.20, 'exceptional', '2026-04-25'::date),
  ('Q2', 2026, 'Jodhpur', 'RJ', 'hindi', 22, 18, false, 60, 30.00, 25.50, 'weak', '2026-05-08'::date),
  ('Q2', 2026, 'Durgapur', 'WB', 'bengali', 35, 30, true, 90, 50.00, 44.80, 'adequate', '2026-05-22'::date),
  ('Q3', 2026, 'Cuttack', 'OR', 'odia', 28, 24, true, 80, 52.00, 46.30, 'adequate', '2026-07-15'::date),
  ('Q3', 2026, 'Thrissur', 'KL', 'malayalam', 44, 40, true, 110, 67.00, 60.90, 'strong', '2026-07-28'::date),
  ('Q3', 2026, 'Ludhiana', 'PB', 'punjabi', 18, 12, false, 60, 20.00, 15.20, 'poor', '2026-08-05'::date),
  ('Q3', 2026, 'Faridabad', 'HR', 'hindi', 36, 33, true, 100, 58.00, 51.40, 'strong', '2026-08-19'::date),
  ('Q4', 2026, 'Tirupati', 'AP', 'telugu', 49, 46, true, 130, 73.00, 69.50, 'exceptional', '2026-10-12'::date),
  ('Q4', 2026, 'Hubballi', 'KA', 'kannada', 31, 27, true, 90, 56.00, 49.80, 'adequate', '2026-10-25'::date),
  ('Q4', 2026, 'Coimbatore', 'TN', 'tamil', 58, 55, true, 150, 78.00, 74.30, 'exceptional', '2026-11-08'::date),
  ('Q4', 2026, 'Aurangabad', 'MH', 'marathi', 25, 20, false, 70, 35.00, 28.90, 'weak', '2026-11-20'::date);

insert into tier2_outreach_followups_r3045 (session_id, followup_kind, language_used, outreach_count, response_count, conversion_count, revenue_rupees, cost_rupees, status, followup_date)
select id, 'whatsapp_local', local_language, 50, 32, 18, 450000, 15000, 'completed', session_date + 7 from tier2_outreach_sessions_r3045 where tier2_city = 'Warangal'
union all
select id, 'phone_call', local_language, 40, 25, 15, 380000, 12000, 'completed', session_date + 5 from tier2_outreach_sessions_r3045 where tier2_city = 'Vijayawada'
union all
select id, 'site_visit', local_language, 20, 18, 12, 720000, 45000, 'completed', session_date + 14 from tier2_outreach_sessions_r3045 where tier2_city = 'Mysuru'
union all
select id, 'training_invite', local_language, 35, 22, 14, 420000, 18000, 'completed', session_date + 10 from tier2_outreach_sessions_r3045 where tier2_city = 'Madurai'
union all
select id, 'contract_offer', local_language, 28, 15, 8, 320000, 9500, 'in_progress', session_date + 21 from tier2_outreach_sessions_r3045 where tier2_city = 'Nashik'
union all
select id, 'referral_bonus', local_language, 45, 30, 20, 600000, 25000, 'completed', session_date + 8 from tier2_outreach_sessions_r3045 where tier2_city = 'Rajkot'
union all
select id, 'whatsapp_local', local_language, 22, 10, 4, 120000, 5500, 'completed', session_date + 6 from tier2_outreach_sessions_r3045 where tier2_city = 'Varanasi'
union all
select id, 'phone_call', local_language, 55, 40, 28, 850000, 22000, 'completed', session_date + 4 from tier2_outreach_sessions_r3045 where tier2_city = 'Indore'
union all
select id, 'site_visit', local_language, 15, 6, 2, 80000, 8000, 'blocked', session_date + 12 from tier2_outreach_sessions_r3045 where tier2_city = 'Jodhpur'
union all
select id, 'training_invite', local_language, 32, 18, 11, 290000, 14500, 'completed', session_date + 9 from tier2_outreach_sessions_r3045 where tier2_city = 'Durgapur'
union all
select id, 'contract_offer', local_language, 26, 16, 9, 340000, 11000, 'in_progress', session_date + 15 from tier2_outreach_sessions_r3045 where tier2_city = 'Cuttack'
union all
select id, 'referral_bonus', local_language, 42, 28, 17, 510000, 19000, 'completed', session_date + 7 from tier2_outreach_sessions_r3045 where tier2_city = 'Thrissur'
union all
select id, 'whatsapp_local', local_language, 12, 4, 1, 35000, 3500, 'cancelled', session_date + 5 from tier2_outreach_sessions_r3045 where tier2_city = 'Ludhiana'
union all
select id, 'phone_call', local_language, 38, 24, 14, 410000, 13500, 'completed', session_date + 6 from tier2_outreach_sessions_r3045 where tier2_city = 'Faridabad'
union all
select id, 'site_visit', local_language, 18, 15, 11, 680000, 38000, 'completed', session_date + 16 from tier2_outreach_sessions_r3045 where tier2_city = 'Tirupati'
union all
select id, 'training_invite', local_language, 30, 17, 10, 270000, 12500, 'completed', session_date + 11 from tier2_outreach_sessions_r3045 where tier2_city = 'Hubballi'
union all
select id, 'contract_offer', local_language, 60, 45, 32, 980000, 28000, 'completed', session_date + 13 from tier2_outreach_sessions_r3045 where tier2_city = 'Coimbatore'
union all
select id, 'referral_bonus', local_language, 16, 8, 3, 90000, 6500, 'planned', session_date + 14 from tier2_outreach_sessions_r3045 where tier2_city = 'Aurangabad';

create or replace function rpc_r3045_session_overview()
returns table(session_date date, tier2_city text, state_code text, local_language text, attendance_count int, nps_score numeric, conversion_pct numeric, effectiveness_band text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.session_date, s.tier2_city, s.state_code, s.local_language, s.attendance_count, s.nps_score, s.conversion_pct, s.effectiveness_band
    from tier2_outreach_sessions_r3045 s order by s.session_date desc;
end $$;

create or replace function rpc_r3045_band_distribution()
returns table(effectiveness_band text, session_count int, avg_nps numeric, avg_conversion numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.effectiveness_band, count(*)::int, round(avg(s.nps_score),2), round(avg(s.conversion_pct),2)
    from tier2_outreach_sessions_r3045 s group by s.effectiveness_band order by avg(s.nps_score) desc nulls last;
end $$;

create or replace function rpc_r3045_language_effectiveness()
returns table(local_language text, sessions int, avg_attendance numeric, avg_nps numeric, exceptional_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.local_language, count(*)::int, round(avg(s.attendance_count),1), round(avg(s.nps_score),2),
    (count(*) filter (where s.effectiveness_band = 'exceptional'))::int
    from tier2_outreach_sessions_r3045 s group by s.local_language order by avg(s.nps_score) desc nulls last;
end $$;

create or replace function rpc_r3045_quarterly_trend()
returns table(quarter text, fiscal_year int, sessions int, total_attendance int, avg_conversion numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.quarter, s.fiscal_year, count(*)::int, sum(s.attendance_count)::int, round(avg(s.conversion_pct),2)
    from tier2_outreach_sessions_r3045 s group by s.quarter, s.fiscal_year order by s.fiscal_year, s.quarter;
end $$;

create or replace function rpc_r3045_followup_roi()
returns table(followup_kind text, total_outreach int, total_conversions int, total_revenue bigint, total_cost bigint, roi_x numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select f.followup_kind, sum(f.outreach_count)::int, sum(f.conversion_count)::int, sum(f.revenue_rupees)::bigint, sum(f.cost_rupees)::bigint,
    case when sum(f.cost_rupees) > 0 then round(sum(f.revenue_rupees)::numeric / sum(f.cost_rupees)::numeric, 2) else 0 end
    from tier2_outreach_followups_r3045 f group by f.followup_kind order by sum(f.revenue_rupees) desc;
end $$;

create or replace function rpc_r3045_blocked_followups()
returns table(followup_date date, followup_kind text, language_used text, outreach_count int, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select f.followup_date, f.followup_kind, f.language_used, f.outreach_count, f.status
    from tier2_outreach_followups_r3045 f where f.status in ('blocked','cancelled','planned') order by f.followup_date;
end $$;

create or replace function rpc_r3045_founder_presence_impact()
returns table(founder_present boolean, sessions int, avg_nps numeric, avg_conversion numeric, avg_attendance numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.founder_present, count(*)::int, round(avg(s.nps_score),2), round(avg(s.conversion_pct),2), round(avg(s.attendance_count),1)
    from tier2_outreach_sessions_r3045 s group by s.founder_present order by s.founder_present desc;
end $$;

revoke all on function rpc_r3045_session_overview() from public, anon;
revoke all on function rpc_r3045_band_distribution() from public, anon;
revoke all on function rpc_r3045_language_effectiveness() from public, anon;
revoke all on function rpc_r3045_quarterly_trend() from public, anon;
revoke all on function rpc_r3045_followup_roi() from public, anon;
revoke all on function rpc_r3045_blocked_followups() from public, anon;
revoke all on function rpc_r3045_founder_presence_impact() from public, anon;

grant execute on function rpc_r3045_session_overview() to authenticated;
grant execute on function rpc_r3045_band_distribution() to authenticated;
grant execute on function rpc_r3045_language_effectiveness() to authenticated;
grant execute on function rpc_r3045_quarterly_trend() to authenticated;
grant execute on function rpc_r3045_followup_roi() to authenticated;
grant execute on function rpc_r3045_blocked_followups() to authenticated;
grant execute on function rpc_r3045_founder_presence_impact() to authenticated;
