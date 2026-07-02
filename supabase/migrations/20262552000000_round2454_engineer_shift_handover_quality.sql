-- Round 2454: engineer-shift-handover-quality
-- Tables: engineer_shift_handovers_r2454 + handover_loss_bugs_r2454

set search_path = public, pg_temp;

-- ============================================================
-- TABLE 1: engineer_shift_handovers_r2454
-- ============================================================
create table if not exists public.engineer_shift_handovers_r2454 (
  id uuid primary key default gen_random_uuid(),
  outgoing_engineer_user_id uuid not null references public.engineers(id) on delete cascade,
  incoming_engineer_user_id uuid not null references public.engineers(id) on delete cascade,
  handover_at timestamptz not null default now(),
  hospital_user_id uuid not null references public.profiles(id) on delete cascade,
  equipment_label text not null,
  handover_completeness_pct int not null check (handover_completeness_pct between 0 and 100),
  time_spent_minutes int not null check (time_spent_minutes >= 0),
  next_shift_issues_count int not null default 0 check (next_shift_issues_count >= 0),
  loss_of_context_bug_count int not null default 0 check (loss_of_context_bug_count >= 0),
  handover_kind text not null check (handover_kind in ('verbal','written','checklist','recorded')),
  quality_grade text not null check (quality_grade in ('A','B','C','D','F')),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_shift_handovers_r2454 enable row level security;

drop policy if exists founder_all on public.engineer_shift_handovers_r2454;
create policy founder_all on public.engineer_shift_handovers_r2454
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- ============================================================
-- TABLE 2: handover_loss_bugs_r2454
-- ============================================================
create table if not exists public.handover_loss_bugs_r2454 (
  id uuid primary key default gen_random_uuid(),
  handover_id uuid not null references public.engineer_shift_handovers_r2454(id) on delete cascade,
  bug_kind text not null check (bug_kind in ('missed_step','wrong_part','wrong_calibration','missing_signoff','communication')),
  severity text not null check (severity in ('low','medium','high','critical')),
  discovered_at timestamptz not null default now(),
  discovered_by_engineer_user_id uuid not null references public.engineers(id) on delete cascade,
  root_cause_md text,
  corrective_action_md text,
  status text not null default 'open' check (status in ('open','closed','escalated')),
  closed_at timestamptz,
  closed_by_email text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.handover_loss_bugs_r2454 enable row level security;

drop policy if exists founder_all on public.handover_loss_bugs_r2454;
create policy founder_all on public.handover_loss_bugs_r2454
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- ============================================================
-- SEED
-- ============================================================
do $seed$
declare
  v_eng_a uuid;
  v_eng_b uuid;
  v_eng_c uuid;
  v_hosp uuid;
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_h4 uuid;
begin
  select id into v_eng_a from public.engineers order by created_at asc limit 1;
  select id into v_eng_b from public.engineers order by created_at asc offset 1 limit 1;
  select id into v_eng_c from public.engineers order by created_at desc limit 1;
  select id into v_hosp from public.profiles where role = 'hospital_admin' order by created_at asc limit 1;

  if v_eng_a is null or v_eng_b is null or v_hosp is null then
    return;
  end if;

  if v_eng_c is null then v_eng_c := v_eng_a; end if;

  insert into public.engineer_shift_handovers_r2454
    (outgoing_engineer_user_id, incoming_engineer_user_id, handover_at, hospital_user_id, equipment_label, handover_completeness_pct, time_spent_minutes, next_shift_issues_count, loss_of_context_bug_count, handover_kind, quality_grade, notes)
  values
    (v_eng_a, v_eng_b, now() - interval '1 day', v_hosp, 'GE Logiq P9 Ultrasound', 95, 18, 0, 0, 'checklist', 'A', 'clean handover, all calibrations logged')
  returning id into v_h1;

  insert into public.engineer_shift_handovers_r2454
    (outgoing_engineer_user_id, incoming_engineer_user_id, handover_at, hospital_user_id, equipment_label, handover_completeness_pct, time_spent_minutes, next_shift_issues_count, loss_of_context_bug_count, handover_kind, quality_grade, notes)
  values
    (v_eng_b, v_eng_c, now() - interval '3 days', v_hosp, 'Philips IntelliVue MX450', 60, 8, 2, 1, 'verbal', 'C', 'rushed verbal handover, calibration drift missed')
  returning id into v_h2;

  insert into public.engineer_shift_handovers_r2454
    (outgoing_engineer_user_id, incoming_engineer_user_id, handover_at, hospital_user_id, equipment_label, handover_completeness_pct, time_spent_minutes, next_shift_issues_count, loss_of_context_bug_count, handover_kind, quality_grade, notes)
  values
    (v_eng_c, v_eng_a, now() - interval '7 days', v_hosp, 'Siemens MAGNETOM Sola MRI', 40, 5, 4, 3, 'verbal', 'F', 'shift ended early, no written log')
  returning id into v_h3;

  insert into public.engineer_shift_handovers_r2454
    (outgoing_engineer_user_id, incoming_engineer_user_id, handover_at, hospital_user_id, equipment_label, handover_completeness_pct, time_spent_minutes, next_shift_issues_count, loss_of_context_bug_count, handover_kind, quality_grade, notes)
  values
    (v_eng_a, v_eng_c, now() - interval '14 days', v_hosp, 'Drager Evita V500 Ventilator', 80, 22, 1, 0, 'written', 'B', 'good written log, missed one preventive task')
  returning id into v_h4;

  insert into public.handover_loss_bugs_r2454
    (handover_id, bug_kind, severity, discovered_at, discovered_by_engineer_user_id, root_cause_md, corrective_action_md, status, closed_at, closed_by_email, notes)
  values
    (v_h2, 'wrong_calibration', 'high', now() - interval '2 days', v_eng_c, 'verbal handover skipped calibration drift note', 'mandatory checklist for monitoring equipment', 'closed', now() - interval '1 day', 'founder@equipseva.com', 'patient monitor reading off by 4%');

  insert into public.handover_loss_bugs_r2454
    (handover_id, bug_kind, severity, discovered_at, discovered_by_engineer_user_id, root_cause_md, corrective_action_md, status, notes)
  values
    (v_h3, 'missed_step', 'critical', now() - interval '6 days', v_eng_a, 'cryogen top-up step skipped at MRI handover', 'add cryogen check to MRI checklist; alert ops at <30%', 'escalated', 'escalated to hospital biomed lead');

  insert into public.handover_loss_bugs_r2454
    (handover_id, bug_kind, severity, discovered_at, discovered_by_engineer_user_id, root_cause_md, corrective_action_md, status, notes)
  values
    (v_h3, 'missing_signoff', 'medium', now() - interval '6 days', v_eng_a, 'no incoming engineer signoff captured', 'require signoff button in app to close handover', 'open', null);

  insert into public.handover_loss_bugs_r2454
    (handover_id, bug_kind, severity, discovered_at, discovered_by_engineer_user_id, root_cause_md, corrective_action_md, status, notes)
  values
    (v_h3, 'communication', 'high', now() - interval '5 days', v_eng_a, 'outgoing engineer left before incoming arrived', 'enforce 15-min overlap window in shift planner', 'open', null);

  insert into public.handover_loss_bugs_r2454
    (handover_id, bug_kind, severity, discovered_at, discovered_by_engineer_user_id, root_cause_md, corrective_action_md, status, closed_at, closed_by_email, notes)
  values
    (v_h4, 'wrong_part', 'low', now() - interval '13 days', v_eng_c, 'wrong filter SKU referenced in log', 'cross-link part catalog in handover form', 'closed', now() - interval '12 days', 'founder@equipseva.com', 'minor part-id confusion, no patient impact');
end
$seed$;

-- ============================================================
-- RPC 1: list_handovers_r2454
-- ============================================================
create or replace function public.list_handovers_r2454()
returns table (
  id uuid,
  handover_at timestamptz,
  equipment_label text,
  handover_kind text,
  quality_grade text,
  handover_completeness_pct int,
  time_spent_minutes int,
  next_shift_issues_count int,
  loss_of_context_bug_count int,
  notes text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.id, h.handover_at, h.equipment_label, h.handover_kind, h.quality_grade,
           h.handover_completeness_pct, h.time_spent_minutes, h.next_shift_issues_count,
           h.loss_of_context_bug_count, h.notes
    from public.engineer_shift_handovers_r2454 h
    order by h.handover_at desc
    limit 200;
end;
$$;
revoke execute on function public.list_handovers_r2454() from public, anon;
grant execute on function public.list_handovers_r2454() to authenticated;

-- ============================================================
-- RPC 2: list_loss_bugs_r2454
-- ============================================================
create or replace function public.list_loss_bugs_r2454()
returns table (
  id uuid,
  discovered_at timestamptz,
  bug_kind text,
  severity text,
  status text,
  equipment_label text,
  root_cause_md text,
  corrective_action_md text,
  closed_at timestamptz,
  closed_by_email text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.id, b.discovered_at, b.bug_kind, b.severity, b.status,
           h.equipment_label, b.root_cause_md, b.corrective_action_md,
           b.closed_at, b.closed_by_email
    from public.handover_loss_bugs_r2454 b
    join public.engineer_shift_handovers_r2454 h on h.id = b.handover_id
    order by b.discovered_at desc
    limit 200;
end;
$$;
revoke execute on function public.list_loss_bugs_r2454() from public, anon;
grant execute on function public.list_loss_bugs_r2454() to authenticated;

-- ============================================================
-- RPC 3: low_quality_handovers_r2454
-- ============================================================
create or replace function public.low_quality_handovers_r2454()
returns table (
  id uuid,
  handover_at timestamptz,
  equipment_label text,
  quality_grade text,
  handover_completeness_pct int,
  next_shift_issues_count int,
  loss_of_context_bug_count int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.id, h.handover_at, h.equipment_label, h.quality_grade,
           h.handover_completeness_pct, h.next_shift_issues_count, h.loss_of_context_bug_count
    from public.engineer_shift_handovers_r2454 h
    where h.quality_grade in ('C','D','F') or h.handover_completeness_pct < 70
    order by h.handover_at desc
    limit 100;
end;
$$;
revoke execute on function public.low_quality_handovers_r2454() from public, anon;
grant execute on function public.low_quality_handovers_r2454() to authenticated;

-- ============================================================
-- RPC 4: top_loss_bug_kinds_r2454
-- ============================================================
create or replace function public.top_loss_bug_kinds_r2454()
returns table (
  bug_kind text,
  bug_count bigint,
  critical_count bigint,
  open_count bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.bug_kind,
           count(*)::bigint,
           count(*) filter (where b.severity = 'critical')::bigint,
           count(*) filter (where b.status = 'open')::bigint
    from public.handover_loss_bugs_r2454 b
    group by b.bug_kind
    order by count(*) desc;
end;
$$;
revoke execute on function public.top_loss_bug_kinds_r2454() from public, anon;
grant execute on function public.top_loss_bug_kinds_r2454() to authenticated;

-- ============================================================
-- RPC 5: top_outgoing_offenders_r2454
-- ============================================================
create or replace function public.top_outgoing_offenders_r2454()
returns table (
  outgoing_engineer_user_id uuid,
  outgoing_email text,
  handover_count bigint,
  avg_completeness_pct numeric,
  total_loss_bugs bigint,
  poor_grade_count bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.outgoing_engineer_user_id,
           p.email,
           count(*)::bigint,
           round(avg(h.handover_completeness_pct)::numeric, 1),
           coalesce(sum(h.loss_of_context_bug_count), 0)::bigint,
           count(*) filter (where h.quality_grade in ('D','F'))::bigint
    from public.engineer_shift_handovers_r2454 h
    join public.engineers e on e.id = h.outgoing_engineer_user_id
    left join public.profiles p on p.id = e.user_id
    group by h.outgoing_engineer_user_id, p.email
    order by count(*) filter (where h.quality_grade in ('D','F')) desc, sum(h.loss_of_context_bug_count) desc nulls last
    limit 20;
end;
$$;
revoke execute on function public.top_outgoing_offenders_r2454() from public, anon;
grant execute on function public.top_outgoing_offenders_r2454() to authenticated;

-- ============================================================
-- RPC 6: weekly_quality_trend_r2454
-- ============================================================
create or replace function public.weekly_quality_trend_r2454()
returns table (
  week_start date,
  handover_count bigint,
  avg_completeness_pct numeric,
  total_next_shift_issues bigint,
  total_loss_bugs bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select (date_trunc('week', h.handover_at))::date,
           count(*)::bigint,
           round(avg(h.handover_completeness_pct)::numeric, 1),
           coalesce(sum(h.next_shift_issues_count), 0)::bigint,
           coalesce(sum(h.loss_of_context_bug_count), 0)::bigint
    from public.engineer_shift_handovers_r2454 h
    where h.handover_at >= now() - interval '12 weeks'
    group by date_trunc('week', h.handover_at)
    order by date_trunc('week', h.handover_at) desc;
end;
$$;
revoke execute on function public.weekly_quality_trend_r2454() from public, anon;
grant execute on function public.weekly_quality_trend_r2454() to authenticated;

-- ============================================================
-- RPC 7: handover_kind_breakdown_r2454
-- ============================================================
create or replace function public.handover_kind_breakdown_r2454()
returns table (
  handover_kind text,
  handover_count bigint,
  avg_completeness_pct numeric,
  avg_time_spent_minutes numeric,
  total_loss_bugs bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.handover_kind,
           count(*)::bigint,
           round(avg(h.handover_completeness_pct)::numeric, 1),
           round(avg(h.time_spent_minutes)::numeric, 1),
           coalesce(sum(h.loss_of_context_bug_count), 0)::bigint
    from public.engineer_shift_handovers_r2454 h
    group by h.handover_kind
    order by count(*) desc;
end;
$$;
revoke execute on function public.handover_kind_breakdown_r2454() from public, anon;
grant execute on function public.handover_kind_breakdown_r2454() to authenticated;
