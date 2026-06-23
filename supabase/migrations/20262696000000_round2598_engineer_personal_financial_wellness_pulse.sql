-- Round r2598 — Engineer Personal Financial Wellness Pulse
-- 2 tables, founder-only RLS, 7 RPCs

create table if not exists public.engineer_financial_wellness_r2598 (
  id uuid primary key default gen_random_uuid(),
  engineer_user_id uuid not null references public.engineers(id) on delete cascade,
  pulse_at timestamptz not null default now(),
  emergency_fund_months numeric(5,2) not null default 0,
  savings_rate_pct numeric(5,2) not null default 0,
  debt_burden_pct numeric(5,2) not null default 0,
  financial_stress_score int not null default 5 check (financial_stress_score between 0 and 10),
  planning_session_attended boolean not null default false,
  owner_email text,
  status text not null default 'monitoring' check (status in ('monitoring','at_risk','healthy','champion')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_efw_r2598_engineer on public.engineer_financial_wellness_r2598(engineer_user_id);
create index if not exists idx_efw_r2598_status on public.engineer_financial_wellness_r2598(status);
create index if not exists idx_efw_r2598_pulse_at on public.engineer_financial_wellness_r2598(pulse_at desc);

create table if not exists public.financial_wellness_planning_actions_r2598 (
  id uuid primary key default gen_random_uuid(),
  pulse_id uuid not null references public.engineer_financial_wellness_r2598(id) on delete cascade,
  action_at timestamptz not null default now(),
  action_kind text not null check (action_kind in ('savings_increase','debt_reduction','insurance','sip_setup','coaching')),
  outcome text not null default 'pending' check (outcome in ('positive','neutral','negative','pending')),
  owner_email text,
  status text not null default 'open' check (status in ('open','done','dropped')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_fwpa_r2598_pulse on public.financial_wellness_planning_actions_r2598(pulse_id);
create index if not exists idx_fwpa_r2598_kind on public.financial_wellness_planning_actions_r2598(action_kind);
create index if not exists idx_fwpa_r2598_status on public.financial_wellness_planning_actions_r2598(status);

alter table public.engineer_financial_wellness_r2598 enable row level security;
alter table public.financial_wellness_planning_actions_r2598 enable row level security;

drop policy if exists founder_all on public.engineer_financial_wellness_r2598;
create policy founder_all on public.engineer_financial_wellness_r2598
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

drop policy if exists founder_all on public.financial_wellness_planning_actions_r2598;
create policy founder_all on public.financial_wellness_planning_actions_r2598
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- Seed pulses (3 rows, single-row INSERT ... RETURNING)
do $$
declare
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_pulse1 uuid;
  v_pulse2 uuid;
  v_pulse3 uuid;
begin
  select id into v_eng1 from public.engineers order by created_at asc limit 1;
  select id into v_eng2 from public.engineers order by created_at asc offset 1 limit 1;
  select id into v_eng3 from public.engineers order by created_at desc limit 1;

  if v_eng1 is not null then
    insert into public.engineer_financial_wellness_r2598
      (engineer_user_id, pulse_at, emergency_fund_months, savings_rate_pct, debt_burden_pct, financial_stress_score, planning_session_attended, owner_email, status, notes)
    values
      (v_eng1, now() - interval '5 days', 1.5, 8.0, 42.0, 8, false, 'founder@equipseva.com', 'at_risk', 'Personal loan EMI eating into savings; needs coaching.')
    returning id into v_pulse1;

    insert into public.financial_wellness_planning_actions_r2598
      (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
    values (v_pulse1, now() - interval '3 days', 'debt_reduction', 'pending', 'founder@equipseva.com', 'open', 'Refinance personal loan via partner NBFC.');

    insert into public.financial_wellness_planning_actions_r2598
      (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
    values (v_pulse1, now() - interval '2 days', 'coaching', 'positive', 'founder@equipseva.com', 'done', 'Attended 1:1 with finance coach.');
  end if;

  if v_eng2 is not null then
    insert into public.engineer_financial_wellness_r2598
      (engineer_user_id, pulse_at, emergency_fund_months, savings_rate_pct, debt_burden_pct, financial_stress_score, planning_session_attended, owner_email, status, notes)
    values
      (v_eng2, now() - interval '10 days', 4.5, 22.0, 18.0, 4, true, 'founder@equipseva.com', 'healthy', 'On track; SIP active.')
    returning id into v_pulse2;

    insert into public.financial_wellness_planning_actions_r2598
      (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
    values (v_pulse2, now() - interval '8 days', 'sip_setup', 'positive', 'founder@equipseva.com', 'done', 'Bumped SIP from 5k to 8k per month.');
  end if;

  if v_eng3 is not null then
    insert into public.engineer_financial_wellness_r2598
      (engineer_user_id, pulse_at, emergency_fund_months, savings_rate_pct, debt_burden_pct, financial_stress_score, planning_session_attended, owner_email, status, notes)
    values
      (v_eng3, now() - interval '2 days', 8.0, 35.0, 5.0, 1, true, 'founder@equipseva.com', 'champion', 'Exemplar; mentor for peers.')
    returning id into v_pulse3;

    insert into public.financial_wellness_planning_actions_r2598
      (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
    values (v_pulse3, now() - interval '1 day', 'insurance', 'positive', 'founder@equipseva.com', 'done', 'Top-up health cover purchased.');
  end if;
end $$;

-- RPC 1: list pulses
create or replace function public.list_wellness_r2598()
returns table (
  id uuid,
  engineer_user_id uuid,
  pulse_at timestamptz,
  emergency_fund_months numeric,
  savings_rate_pct numeric,
  debt_burden_pct numeric,
  financial_stress_score int,
  planning_session_attended boolean,
  owner_email text,
  status text,
  notes text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select w.id, w.engineer_user_id, w.pulse_at, w.emergency_fund_months, w.savings_rate_pct,
           w.debt_burden_pct, w.financial_stress_score, w.planning_session_attended,
           w.owner_email, w.status, w.notes
    from public.engineer_financial_wellness_r2598 w
    order by w.pulse_at desc nulls last
    limit 200;
end;
$$;
revoke execute on function public.list_wellness_r2598() from public, anon;
grant execute on function public.list_wellness_r2598() to authenticated;

-- RPC 2: list actions
create or replace function public.list_planning_actions_r2598()
returns table (
  id uuid,
  pulse_id uuid,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.id, a.pulse_id, a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
    from public.financial_wellness_planning_actions_r2598 a
    order by a.action_at desc nulls last
    limit 200;
end;
$$;
revoke execute on function public.list_planning_actions_r2598() from public, anon;
grant execute on function public.list_planning_actions_r2598() to authenticated;

-- RPC 3: top at-risk engineers (latest pulse per engineer where status='at_risk' or stress>=7)
create or replace function public.top_at_risk_engineers_r2598()
returns table (
  engineer_user_id uuid,
  pulse_at timestamptz,
  financial_stress_score int,
  emergency_fund_months numeric,
  debt_burden_pct numeric,
  status text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    with latest as (
      select distinct on (w.engineer_user_id)
        w.engineer_user_id, w.pulse_at, w.financial_stress_score,
        w.emergency_fund_months, w.debt_burden_pct, w.status
      from public.engineer_financial_wellness_r2598 w
      order by w.engineer_user_id, w.pulse_at desc
    )
    select l.engineer_user_id, l.pulse_at, l.financial_stress_score,
           l.emergency_fund_months, l.debt_burden_pct, l.status
    from latest l
    where l.status = 'at_risk' or l.financial_stress_score >= 7
    order by l.financial_stress_score desc, l.debt_burden_pct desc
    limit 50;
end;
$$;
revoke execute on function public.top_at_risk_engineers_r2598() from public, anon;
grant execute on function public.top_at_risk_engineers_r2598() to authenticated;

-- RPC 4: status distribution
create or replace function public.status_distribution_r2598()
returns table (status text, pulse_count bigint)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select w.status, count(*)::bigint
    from public.engineer_financial_wellness_r2598 w
    group by w.status
    order by count(*) desc nulls last;
end;
$$;
revoke execute on function public.status_distribution_r2598() from public, anon;
grant execute on function public.status_distribution_r2598() to authenticated;

-- RPC 5: monthly pulse trend
create or replace function public.monthly_pulse_trend_r2598()
returns table (
  month_start timestamptz,
  pulse_count bigint,
  avg_stress numeric,
  avg_emergency_fund numeric,
  avg_debt_burden numeric
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select date_trunc('month', w.pulse_at) as month_start,
           count(*)::bigint,
           round(avg(w.financial_stress_score)::numeric, 2),
           round(avg(w.emergency_fund_months)::numeric, 2),
           round(avg(w.debt_burden_pct)::numeric, 2)
    from public.engineer_financial_wellness_r2598 w
    group by date_trunc('month', w.pulse_at)
    order by date_trunc('month', w.pulse_at) desc nulls last
    limit 24;
end;
$$;
revoke execute on function public.monthly_pulse_trend_r2598() from public, anon;
grant execute on function public.monthly_pulse_trend_r2598() to authenticated;

-- RPC 6: planning attendance rate
create or replace function public.planning_attendance_rate_r2598()
returns table (
  total_pulses bigint,
  attended_count bigint,
  attendance_pct numeric
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select count(*)::bigint as total_pulses,
           count(*) filter (where w.planning_session_attended)::bigint as attended_count,
           case when count(*) = 0 then 0
                else round((count(*) filter (where w.planning_session_attended))::numeric * 100.0 / count(*)::numeric, 2)
           end as attendance_pct
    from public.engineer_financial_wellness_r2598 w;
end;
$$;
revoke execute on function public.planning_attendance_rate_r2598() from public, anon;
grant execute on function public.planning_attendance_rate_r2598() to authenticated;

-- RPC 7: action kind breakdown
create or replace function public.action_kind_breakdown_r2598()
returns table (
  action_kind text,
  total_actions bigint,
  positive_count bigint,
  positive_pct numeric
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.action_kind,
           count(*)::bigint as total_actions,
           count(*) filter (where a.outcome = 'positive')::bigint as positive_count,
           case when count(*) = 0 then 0
                else round((count(*) filter (where a.outcome = 'positive'))::numeric * 100.0 / count(*)::numeric, 2)
           end as positive_pct
    from public.financial_wellness_planning_actions_r2598 a
    group by a.action_kind
    order by count(*) desc nulls last;
end;
$$;
revoke execute on function public.action_kind_breakdown_r2598() from public, anon;
grant execute on function public.action_kind_breakdown_r2598() to authenticated;
