-- Round 3702: Founder Feature-Flag Lifecycle / Stale-Flag Hygiene Board
-- Flag governance — flag inventory × owning team × flag class × rollout % × environments × kill-switches × evaluations × code references × lifecycle status × CAPA (NOT experiment outcomes)

-- =============================================================================
-- TABLE 1: feature_flag_r3702 — per-flag lifecycle hygiene facts
-- =============================================================================
create table if not exists public.feature_flag_r3702 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  flag_name text not null,
  owning_team text not null,
  period_month date not null,
  created_date date not null,
  age_days int not null,
  rollout_pct numeric(5,2),
  environments_active int not null,
  is_kill_switch boolean not null,
  last_evaluated_date date,
  evaluations_30d int not null,
  cleanup_ticket_open boolean not null,
  code_references int not null,
  flag_class text not null check (flag_class in (
    'release_flag','ops_kill_switch','experiment_flag','permission_flag','config_flag'
  )),
  lifecycle_status text not null check (lifecycle_status in (
    'active_managed','fully_rolled_out','stale','zombie_unreferenced','cleanup_overdue'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.feature_flag_r3702 enable row level security;

create index if not exists idx_feature_flag_r3702_org on public.feature_flag_r3702(organization_id);
create index if not exists idx_feature_flag_r3702_month on public.feature_flag_r3702(period_month);
create index if not exists idx_feature_flag_r3702_status on public.feature_flag_r3702(lifecycle_status);

-- =============================================================================
-- TABLE 2: feature_flag_capa_actions_r3702 — flag-hygiene CAPA actions
-- =============================================================================
create table if not exists public.feature_flag_capa_actions_r3702 (
  id uuid primary key default gen_random_uuid(),
  flag_log_id uuid not null references public.feature_flag_r3702(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'missing_cleanup_ticket','owner_left_team','release_train_backlog',
    'experiment_never_archived','no_flag_expiry_policy','code_refs_not_removed',
    'pending_investigation','flag_platform_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'delete_flag_and_code_refs','archive_experiment_flag','assign_new_owner',
    'open_cleanup_ticket','schedule_removal_pr','add_expiry_date',
    'document_as_permanent','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  engineering_hours_est numeric(6,1),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.feature_flag_capa_actions_r3702 enable row level security;

create index if not exists idx_feature_flag_capa_r3702_log on public.feature_flag_capa_actions_r3702(flag_log_id);
create index if not exists idx_feature_flag_capa_r3702_status on public.feature_flag_capa_actions_r3702(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Lifecycle status distribution
create or replace function public.founder_r3702_lifecycle_status_rollup()
returns table(lifecycle_status text, flags bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.feature_flag_r3702)
  select l.lifecycle_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.feature_flag_r3702 l
  group by l.lifecycle_status
  order by count(*) desc;
end;
$$;

-- 2) Owning-team hygiene scorecard
create or replace function public.founder_r3702_owning_team_scorecard()
returns table(
  owning_team text,
  total_flags bigint,
  active_managed bigint,
  fully_rolled_out bigint,
  stale_flags bigint,
  zombie_flags bigint,
  cleanup_overdue_flags bigint,
  kill_switches bigint,
  avg_age_days numeric,
  hygiene_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.owning_team,
    count(*)::bigint,
    count(*) filter (where l.lifecycle_status = 'active_managed')::bigint,
    count(*) filter (where l.lifecycle_status = 'fully_rolled_out')::bigint,
    count(*) filter (where l.lifecycle_status = 'stale')::bigint,
    count(*) filter (where l.lifecycle_status = 'zombie_unreferenced')::bigint,
    count(*) filter (where l.lifecycle_status = 'cleanup_overdue')::bigint,
    count(*) filter (where l.is_kill_switch = true)::bigint,
    round(avg(l.age_days)::numeric, 1),
    round(100.0 * count(*) filter (where l.lifecycle_status in ('active_managed','fully_rolled_out'))::numeric / nullif(count(*),0), 1)
  from public.feature_flag_r3702 l
  group by l.owning_team
  order by count(*) desc;
end;
$$;

-- 3) Flag class × lifecycle status matrix
create or replace function public.founder_r3702_flag_class_lifecycle_matrix()
returns table(flag_class text, lifecycle_status text, flags bigint, avg_age_days numeric, avg_rollout_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.flag_class, l.lifecycle_status, count(*)::bigint,
    round(avg(l.age_days)::numeric, 1),
    round(avg(l.rollout_pct)::numeric, 1)
  from public.feature_flag_r3702 l
  group by l.flag_class, l.lifecycle_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly flag-age trend
create or replace function public.founder_r3702_monthly_flag_age_trend()
returns table(period_month date, flags bigint, avg_age_days numeric, stale_plus bigint, cleanup_tickets_open bigint, avg_evaluations_30d numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.age_days)::numeric, 1),
    count(*) filter (where l.lifecycle_status in ('stale','zombie_unreferenced','cleanup_overdue'))::bigint,
    count(*) filter (where l.cleanup_ticket_open = true)::bigint,
    round(avg(l.evaluations_30d)::numeric, 0)
  from public.feature_flag_r3702 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3702_capa_status_board()
returns table(capa_status text, actions bigint, avg_hours_est numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.engineering_hours_est)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.feature_flag_capa_actions_r3702 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3702_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_hours_est numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.feature_flag_capa_actions_r3702)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.engineering_hours_est),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.feature_flag_capa_actions_r3702 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Stale-flag digest by trend direction
create or replace function public.founder_r3702_stale_flag_digest()
returns table(trend_dir text, flags bigint, stale_flags bigint, zombie_flags bigint, cleanup_overdue_flags bigint, avg_age_days numeric, total_code_references bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.trend_dir, count(*)::bigint,
    count(*) filter (where l.lifecycle_status = 'stale')::bigint,
    count(*) filter (where l.lifecycle_status = 'zombie_unreferenced')::bigint,
    count(*) filter (where l.lifecycle_status = 'cleanup_overdue')::bigint,
    round(avg(l.age_days)::numeric, 1),
    coalesce(sum(l.code_references),0)::bigint
  from public.feature_flag_r3702 l
  group by l.trend_dir
  order by count(*) desc;
end;
$$;

-- 8) High-risk flag queue (zombie / cleanup-overdue / stale)
create or replace function public.founder_r3702_high_risk_queue()
returns table(
  flag_name text,
  owning_team text,
  flag_class text,
  lifecycle_status text,
  age_days int,
  rollout_pct numeric,
  evaluations_30d int,
  code_references int,
  cleanup_ticket_open boolean,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.flag_name, l.owning_team, l.flag_class, l.lifecycle_status,
    l.age_days, l.rollout_pct, l.evaluations_30d, l.code_references,
    l.cleanup_ticket_open, l.trend_dir, l.notes
  from public.feature_flag_r3702 l
  where l.lifecycle_status in ('zombie_unreferenced','cleanup_overdue','stale')
     or (l.evaluations_30d = 0 and l.is_kill_switch = false)
  order by l.age_days desc, l.flag_name;
end;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================
revoke all on function public.founder_r3702_lifecycle_status_rollup() from public, anon;
revoke all on function public.founder_r3702_owning_team_scorecard() from public, anon;
revoke all on function public.founder_r3702_flag_class_lifecycle_matrix() from public, anon;
revoke all on function public.founder_r3702_monthly_flag_age_trend() from public, anon;
revoke all on function public.founder_r3702_capa_status_board() from public, anon;
revoke all on function public.founder_r3702_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3702_stale_flag_digest() from public, anon;
revoke all on function public.founder_r3702_high_risk_queue() from public, anon;

grant execute on function public.founder_r3702_lifecycle_status_rollup() to authenticated;
grant execute on function public.founder_r3702_owning_team_scorecard() to authenticated;
grant execute on function public.founder_r3702_flag_class_lifecycle_matrix() to authenticated;
grant execute on function public.founder_r3702_monthly_flag_age_trend() to authenticated;
grant execute on function public.founder_r3702_capa_status_board() to authenticated;
grant execute on function public.founder_r3702_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3702_stale_flag_digest() to authenticated;
grant execute on function public.founder_r3702_high_risk_queue() to authenticated;

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

  -- 16 flag inventory rows
  insert into public.feature_flag_r3702 (
    organization_id, flag_name, owning_team, period_month, created_date, age_days,
    rollout_pct, environments_active, is_kill_switch, last_evaluated_date,
    evaluations_30d, cleanup_ticket_open, code_references,
    flag_class, lifecycle_status, trend_dir, notes
  )
  select v_org_id, q.fname, q.team, q.pmon::date, q.cdate::date, q.age,
    q.rpct, q.envs, q.ks, q.ledate::date,
    q.ev30, q.cto, q.crefs,
    q.fclass, q.lstat, q.tdir, q.nt
  from (values
    ('new_bid_flow_v2','android','2026-07-01','2026-03-12',148,
     100.0,3,false,'2026-08-05',48200,true,14,
     'release_flag','fully_rolled_out','improving','At 100% for 60+ days — cleanup ticket ESQ-2214 open, removal targeted Sept train'),
    ('kyc_v3_rollout','backend','2026-07-01','2026-04-02',127,
     85.0,3,false,'2026-08-06',31500,false,22,
     'release_flag','active_managed','stable','Staged rollout at 85% — GA target end of August, dashboards green'),
    ('upi_mandate_killswitch','payments','2026-07-01','2025-11-20',260,
     0.0,3,true,'2026-08-06',9800,false,6,
     'ops_kill_switch','active_managed','stable','Permanent kill-switch for UPI mandate flow — reviewed quarterly'),
    ('marketplace_search_rank_v2','web','2026-07-01','2026-01-15',204,
     100.0,3,false,'2026-06-30',120,true,9,
     'release_flag','cleanup_overdue','worsening','Fully rolled out since March — cleanup ticket idle 90+ days'),
    ('legacy_chat_polling','android','2026-07-01','2025-06-10',423,
     0.0,1,false,null,0,false,0,
     'config_flag','zombie_unreferenced','worsening','Zero evaluations and zero code references — safe to delete from flag platform'),
    ('bid_price_suggestions_exp','growth','2026-07-01','2026-05-18',81,
     50.0,2,false,'2026-08-05',15400,false,11,
     'experiment_flag','active_managed','improving','A/B at 50% — decision review scheduled 15 Aug'),
    ('org_rls_bypass_admin','backend','2026-07-01','2025-09-01',340,
     5.0,3,false,'2026-07-02',35,false,4,
     'permission_flag','stale','worsening','Admin-only gate with near-zero usage — needs owner review'),
    ('amc_reminder_batch_v2','backend','2026-07-01','2026-02-20',168,
     100.0,3,false,'2026-08-04',7600,true,8,
     'release_flag','fully_rolled_out','stable','GA complete — removal PR queued behind backend release train'),
    ('payments_gateway_failover','payments','2026-06-01','2025-08-14',358,
     0.0,3,true,'2026-07-28',2100,false,7,
     'ops_kill_switch','active_managed','stable','Failover kill-switch exercised in July game-day drill'),
    ('web_dark_mode','web','2026-06-01','2025-10-05',306,
     100.0,2,false,'2026-05-20',60,true,3,
     'config_flag','cleanup_overdue','worsening','Fully rolled out in January — 3 components still branch on flag'),
    ('engineer_dispatch_v2_exp','growth','2026-06-01','2026-04-25',104,
     25.0,2,false,'2026-08-03',8900,false,10,
     'experiment_flag','active_managed','stable','Experiment extended — sample size low in tier-2 cities'),
    ('old_invoice_pdf_renderer','backend','2026-06-01','2025-04-30',464,
     0.0,1,false,'2026-01-10',4,false,2,
     'config_flag','zombie_unreferenced','worsening','Legacy fallback path — last real evaluation in January'),
    ('kyc_doc_upload_retry','android','2026-06-01','2026-03-01',159,
     100.0,3,false,'2026-08-01',22800,false,12,
     'release_flag','fully_rolled_out','improving','Cleanup scheduled with September Android release'),
    ('perm_founder_boards','web','2026-06-01','2025-12-12',238,
     10.0,3,false,'2026-08-06',640,false,5,
     'permission_flag','active_managed','stable','Founder-only gate — intentionally long-lived, documented'),
    ('push_notif_batch_exp','growth','2026-06-01','2026-01-08',211,
     0.0,2,false,'2026-04-15',12,false,6,
     'experiment_flag','stale','worsening','Experiment concluded in April — flag never archived'),
    ('sms_provider_killswitch','platform','2026-06-01','2025-07-22',381,
     0.0,3,true,'2026-08-05',1500,false,5,
     'ops_kill_switch','active_managed','improving','Kill-switch validated during SMS provider outage drill')
  ) as q(fname, team, pmon, cdate, age, rpct, envs, ks, ledate, ev30, cto, crefs, fclass, lstat, tdir, nt);

  -- 8 CAPA rows — attach to specific flags via flag_name
  insert into public.feature_flag_capa_actions_r3702 (
    flag_log_id, root_cause, corrective_action, capa_status,
    engineering_hours_est, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.hrs, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('marketplace_search_rank_v2','release_train_backlog','schedule_removal_pr','in_progress',6.0,'Rohit S','2026-08-20',null,'Removal PR drafted — waiting on web release train slot'),
    ('legacy_chat_polling','owner_left_team','delete_flag_and_code_refs','open',3.5,'Priya K','2026-08-25',null,'Zero refs — delete from flag platform and archive config'),
    ('web_dark_mode','code_refs_not_removed','delete_flag_and_code_refs','overdue',8.0,'Aman T','2026-07-31',null,'3 components still branch on flag — refactor past target date'),
    ('push_notif_batch_exp','experiment_never_archived','archive_experiment_flag','verification_pending',2.0,'Sneha R','2026-08-12',null,'Experiment archived — verifying no residual evaluations'),
    ('old_invoice_pdf_renderer','no_flag_expiry_policy','add_expiry_date','escalated',4.0,'Vikram D','2026-08-10',null,'464-day-old zombie — escalated to platform guild'),
    ('org_rls_bypass_admin','pending_investigation','assign_new_owner','open',1.5,'Neha G','2026-08-18',null,'Original owner moved teams — permission gate currently unowned'),
    ('amc_reminder_batch_v2','release_train_backlog','schedule_removal_pr','closed',5.0,'Rohit S','2026-08-01','2026-07-30','Flag removed in backend v2.41 — code refs cleaned'),
    ('upi_mandate_killswitch','no_flag_expiry_policy','document_as_permanent','closed',1.0,'Priya K','2026-07-15','2026-07-12','Documented as permanent ops kill-switch with quarterly review')
  ) as q(fname, rc, ca, cst, hrs, ownr, tcd, acd, nt)
  join public.feature_flag_r3702 e
    on e.organization_id = v_org_id and e.flag_name = q.fname;
end;
$seed$;
