-- Round r2428: Customer AMC Renewal Runway Board
-- AMC renewal × days to expiry × renewal probability × discount asked × negotiation owner × follow-up calendar

create extension if not exists pgcrypto;

-- ============================================================
-- TABLE 1: amc_renewal_runway_r2428
-- ============================================================
create table if not exists public.amc_renewal_runway_r2428 (
  id uuid primary key default gen_random_uuid(),
  hospital_user_id uuid not null references public.profiles(id) on delete cascade,
  amc_tier text not null check (amc_tier in ('basic','standard','premium','enterprise')),
  current_term_end date not null,
  days_to_expiry int not null,
  renewal_probability_pct int not null check (renewal_probability_pct between 0 and 100),
  discount_asked_pct numeric(5,2) not null default 0 check (discount_asked_pct >= 0),
  our_offer_pct numeric(5,2) not null default 0 check (our_offer_pct >= 0),
  negotiation_owner_email text not null,
  last_touch_at timestamptz,
  next_followup_at timestamptz,
  escalation_required boolean not null default false,
  status text not null default 'green' check (status in ('green','yellow','red','lost','renewed')),
  arr_at_risk_rupees int not null default 0 check (arr_at_risk_rupees >= 0),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_amc_renewal_runway_r2428_hospital on public.amc_renewal_runway_r2428(hospital_user_id);
create index if not exists idx_amc_renewal_runway_r2428_status on public.amc_renewal_runway_r2428(status);
create index if not exists idx_amc_renewal_runway_r2428_expiry on public.amc_renewal_runway_r2428(current_term_end);

alter table public.amc_renewal_runway_r2428 enable row level security;

drop policy if exists founder_all on public.amc_renewal_runway_r2428;
create policy founder_all on public.amc_renewal_runway_r2428
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- ============================================================
-- TABLE 2: renewal_followup_calendar_r2428
-- ============================================================
create table if not exists public.renewal_followup_calendar_r2428 (
  id uuid primary key default gen_random_uuid(),
  amc_renewal_id uuid not null references public.amc_renewal_runway_r2428(id) on delete cascade,
  followup_at timestamptz not null,
  followup_kind text not null check (followup_kind in ('call','email','visit','meeting','email_followup')),
  agenda text not null,
  owner_email text not null,
  status text not null default 'scheduled' check (status in ('scheduled','done','cancelled','no_show')),
  outcome text check (outcome in ('positive','neutral','negative','no_change')),
  outcome_notes text,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_renewal_followup_cal_r2428_renewal on public.renewal_followup_calendar_r2428(amc_renewal_id);
create index if not exists idx_renewal_followup_cal_r2428_followup_at on public.renewal_followup_calendar_r2428(followup_at);
create index if not exists idx_renewal_followup_cal_r2428_status on public.renewal_followup_calendar_r2428(status);

alter table public.renewal_followup_calendar_r2428 enable row level security;

drop policy if exists founder_all on public.renewal_followup_calendar_r2428;
create policy founder_all on public.renewal_followup_calendar_r2428
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- ============================================================
-- SEED DATA
-- ============================================================
do $seed$
declare
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_hosp3 uuid;
  v_hosp4 uuid;
  v_hosp5 uuid;
  v_ren1 uuid;
  v_ren2 uuid;
  v_ren3 uuid;
  v_ren4 uuid;
  v_ren5 uuid;
begin
  select id into v_hosp1 from public.profiles where role='hospital_admin' order by created_at limit 1 offset 0;
  select id into v_hosp2 from public.profiles where role='hospital_admin' order by created_at limit 1 offset 1;
  select id into v_hosp3 from public.profiles where role='hospital_admin' order by created_at limit 1 offset 2;
  select id into v_hosp4 from public.profiles where role='hospital_admin' order by created_at limit 1 offset 3;
  select id into v_hosp5 from public.profiles where role='hospital_admin' order by created_at limit 1 offset 4;

  if v_hosp1 is null then return; end if;
  if v_hosp2 is null then v_hosp2 := v_hosp1; end if;
  if v_hosp3 is null then v_hosp3 := v_hosp1; end if;
  if v_hosp4 is null then v_hosp4 := v_hosp1; end if;
  if v_hosp5 is null then v_hosp5 := v_hosp1; end if;

  insert into public.amc_renewal_runway_r2428(
    hospital_user_id, amc_tier, current_term_end, days_to_expiry, renewal_probability_pct,
    discount_asked_pct, our_offer_pct, negotiation_owner_email, last_touch_at, next_followup_at,
    escalation_required, status, arr_at_risk_rupees, notes
  ) values (
    v_hosp1, 'premium', (current_date + 18), 18, 78,
    15.00, 8.00, 'renewals1@equipseva.com', now() - interval '3 days', now() + interval '2 days',
    false, 'yellow', 480000, 'Asked 15% — willing to walk if no movement'
  ) returning id into v_ren1;

  insert into public.amc_renewal_runway_r2428(
    hospital_user_id, amc_tier, current_term_end, days_to_expiry, renewal_probability_pct,
    discount_asked_pct, our_offer_pct, negotiation_owner_email, last_touch_at, next_followup_at,
    escalation_required, status, arr_at_risk_rupees, notes
  ) values (
    v_hosp2, 'enterprise', (current_date + 7), 7, 42,
    25.00, 12.00, 'renewals2@equipseva.com', now() - interval '1 day', now() + interval '1 day',
    true, 'red', 1200000, 'CRITICAL — competing quote from rival vendor; founder must call'
  ) returning id into v_ren2;

  insert into public.amc_renewal_runway_r2428(
    hospital_user_id, amc_tier, current_term_end, days_to_expiry, renewal_probability_pct,
    discount_asked_pct, our_offer_pct, negotiation_owner_email, last_touch_at, next_followup_at,
    escalation_required, status, arr_at_risk_rupees, notes
  ) values (
    v_hosp3, 'standard', (current_date + 45), 45, 92,
    5.00, 5.00, 'renewals1@equipseva.com', now() - interval '7 days', now() + interval '14 days',
    false, 'green', 180000, 'Smooth — already agreed on terms, contract drafting'
  ) returning id into v_ren3;

  insert into public.amc_renewal_runway_r2428(
    hospital_user_id, amc_tier, current_term_end, days_to_expiry, renewal_probability_pct,
    discount_asked_pct, our_offer_pct, negotiation_owner_email, last_touch_at, next_followup_at,
    escalation_required, status, arr_at_risk_rupees, notes
  ) values (
    v_hosp4, 'basic', (current_date - 5), -5, 0,
    20.00, 10.00, 'renewals2@equipseva.com', now() - interval '20 days', null,
    false, 'lost', 60000, 'Lost to in-house team; reduced eqp count'
  ) returning id into v_ren4;

  insert into public.amc_renewal_runway_r2428(
    hospital_user_id, amc_tier, current_term_end, days_to_expiry, renewal_probability_pct,
    discount_asked_pct, our_offer_pct, negotiation_owner_email, last_touch_at, next_followup_at,
    escalation_required, status, arr_at_risk_rupees, notes
  ) values (
    v_hosp5, 'premium', (current_date + 90), 90, 100,
    8.00, 8.00, 'renewals1@equipseva.com', now() - interval '2 days', null,
    false, 'renewed', 0, 'Renewed 90 days early — bonus quarter'
  ) returning id into v_ren5;

  -- followups
  insert into public.renewal_followup_calendar_r2428(
    amc_renewal_id, followup_at, followup_kind, agenda, owner_email, status, outcome, outcome_notes, notes
  ) values
    (v_ren1, now() + interval '2 days', 'call', 'Counter-offer 8% discount + 1 free preventive visit',
     'renewals1@equipseva.com', 'scheduled', null, null, 'Use uptime SLA as anchor'),
    (v_ren2, now() + interval '1 day', 'visit', 'Founder on-site, present 12% offer + uptime guarantee',
     'founder@equipseva.com', 'scheduled', null, null, 'Bring CTO for tech credibility'),
    (v_ren2, now() - interval '2 days', 'call', 'Initial counter-offer discussion',
     'renewals2@equipseva.com', 'done', 'negative', 'They want 25% or they walk', 'Escalated to founder'),
    (v_ren3, now() + interval '14 days', 'email', 'Send signed contract draft',
     'renewals1@equipseva.com', 'scheduled', null, null, 'Standard 12-mo terms'),
    (v_ren5, now() - interval '2 days', 'meeting', 'Sign renewal 90 days early',
     'renewals1@equipseva.com', 'done', 'positive', 'Renewed 13-mo with 1 mo bonus', 'Win — case study candidate');
end
$seed$;

-- ============================================================
-- RPC 1: list_runway_r2428
-- ============================================================
create or replace function public.list_runway_r2428()
returns table(
  id uuid,
  hospital_user_id uuid,
  amc_tier text,
  current_term_end date,
  days_to_expiry int,
  renewal_probability_pct int,
  discount_asked_pct numeric,
  our_offer_pct numeric,
  negotiation_owner_email text,
  last_touch_at timestamptz,
  next_followup_at timestamptz,
  escalation_required boolean,
  status text,
  arr_at_risk_rupees int,
  notes text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.id, r.hospital_user_id, r.amc_tier, r.current_term_end, r.days_to_expiry,
         r.renewal_probability_pct, r.discount_asked_pct, r.our_offer_pct,
         r.negotiation_owner_email, r.last_touch_at, r.next_followup_at,
         r.escalation_required, r.status, r.arr_at_risk_rupees, r.notes, r.created_at
  from public.amc_renewal_runway_r2428 r
  order by r.days_to_expiry asc nulls last, r.arr_at_risk_rupees desc;
end
$fn$;
revoke execute on function public.list_runway_r2428() from public, anon;
grant execute on function public.list_runway_r2428() to authenticated;

-- ============================================================
-- RPC 2: list_followups_r2428
-- ============================================================
create or replace function public.list_followups_r2428()
returns table(
  id uuid,
  amc_renewal_id uuid,
  followup_at timestamptz,
  followup_kind text,
  agenda text,
  owner_email text,
  status text,
  outcome text,
  outcome_notes text,
  notes text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.id, f.amc_renewal_id, f.followup_at, f.followup_kind, f.agenda,
         f.owner_email, f.status, f.outcome, f.outcome_notes, f.notes, f.created_at
  from public.renewal_followup_calendar_r2428 f
  order by f.followup_at asc;
end
$fn$;
revoke execute on function public.list_followups_r2428() from public, anon;
grant execute on function public.list_followups_r2428() to authenticated;

-- ============================================================
-- RPC 3: expiring_30d_r2428
-- ============================================================
create or replace function public.expiring_30d_r2428()
returns table(
  id uuid,
  hospital_user_id uuid,
  amc_tier text,
  current_term_end date,
  days_to_expiry int,
  renewal_probability_pct int,
  status text,
  arr_at_risk_rupees int,
  negotiation_owner_email text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.id, r.hospital_user_id, r.amc_tier, r.current_term_end, r.days_to_expiry,
         r.renewal_probability_pct, r.status, r.arr_at_risk_rupees, r.negotiation_owner_email
  from public.amc_renewal_runway_r2428 r
  where r.days_to_expiry between 0 and 30
    and r.status not in ('lost','renewed')
  order by r.days_to_expiry asc;
end
$fn$;
revoke execute on function public.expiring_30d_r2428() from public, anon;
grant execute on function public.expiring_30d_r2428() to authenticated;

-- ============================================================
-- RPC 4: red_status_focus_r2428
-- ============================================================
create or replace function public.red_status_focus_r2428()
returns table(
  id uuid,
  hospital_user_id uuid,
  amc_tier text,
  days_to_expiry int,
  renewal_probability_pct int,
  arr_at_risk_rupees int,
  escalation_required boolean,
  negotiation_owner_email text,
  notes text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.id, r.hospital_user_id, r.amc_tier, r.days_to_expiry,
         r.renewal_probability_pct, r.arr_at_risk_rupees, r.escalation_required,
         r.negotiation_owner_email, r.notes
  from public.amc_renewal_runway_r2428 r
  where r.status = 'red'
  order by r.arr_at_risk_rupees desc;
end
$fn$;
revoke execute on function public.red_status_focus_r2428() from public, anon;
grant execute on function public.red_status_focus_r2428() to authenticated;

-- ============================================================
-- RPC 5: top_arr_at_risk_r2428
-- ============================================================
create or replace function public.top_arr_at_risk_r2428()
returns table(
  id uuid,
  hospital_user_id uuid,
  amc_tier text,
  status text,
  days_to_expiry int,
  arr_at_risk_rupees int,
  renewal_probability_pct int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.id, r.hospital_user_id, r.amc_tier, r.status, r.days_to_expiry,
         r.arr_at_risk_rupees, r.renewal_probability_pct
  from public.amc_renewal_runway_r2428 r
  where r.status not in ('renewed')
  order by r.arr_at_risk_rupees desc
  limit 10;
end
$fn$;
revoke execute on function public.top_arr_at_risk_r2428() from public, anon;
grant execute on function public.top_arr_at_risk_r2428() to authenticated;

-- ============================================================
-- RPC 6: this_week_followups_r2428
-- ============================================================
create or replace function public.this_week_followups_r2428()
returns table(
  id uuid,
  amc_renewal_id uuid,
  followup_at timestamptz,
  followup_kind text,
  agenda text,
  owner_email text,
  status text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.id, f.amc_renewal_id, f.followup_at, f.followup_kind, f.agenda,
         f.owner_email, f.status
  from public.renewal_followup_calendar_r2428 f
  where f.followup_at between now() and (now() + interval '7 days')
    and f.status = 'scheduled'
  order by f.followup_at asc;
end
$fn$;
revoke execute on function public.this_week_followups_r2428() from public, anon;
grant execute on function public.this_week_followups_r2428() to authenticated;

-- ============================================================
-- RPC 7: renewal_funnel_r2428
-- ============================================================
create or replace function public.renewal_funnel_r2428()
returns table(
  status text,
  renewal_count int,
  total_arr_at_risk_rupees int,
  avg_probability_pct numeric,
  avg_discount_asked_pct numeric,
  avg_our_offer_pct numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.status,
         count(*)::int as renewal_count,
         coalesce(sum(r.arr_at_risk_rupees),0)::int as total_arr_at_risk_rupees,
         round(avg(r.renewal_probability_pct)::numeric,2) as avg_probability_pct,
         round(avg(r.discount_asked_pct)::numeric,2) as avg_discount_asked_pct,
         round(avg(r.our_offer_pct)::numeric,2) as avg_our_offer_pct
  from public.amc_renewal_runway_r2428 r
  group by r.status
  order by r.status;
end
$fn$;
revoke execute on function public.renewal_funnel_r2428() from public, anon;
grant execute on function public.renewal_funnel_r2428() to authenticated;
