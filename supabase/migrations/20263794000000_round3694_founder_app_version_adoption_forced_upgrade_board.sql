-- Round 3694: Founder App-Version Adoption / Forced-Upgrade Board
-- Platform ops — EquipSeva app version adoption per release channel × staged rollout × forced-upgrade wall × legacy-device tail × upgrade-prompt CTR × crash-free % × CAPA

-- =============================================================================
-- TABLE 1: app_version_r3694 — per-release-channel app version adoption facts
-- =============================================================================
create table if not exists public.app_version_r3694 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  version_name text not null,
  release_channel text not null,
  period_month date not null,
  release_date date not null,
  days_since_release int not null,
  installs_on_version int not null,
  adoption_pct numeric(5,2),
  target_adoption_pct numeric(5,2),
  devices_below_min_version int not null,
  forced_upgrade_active boolean not null,
  upgrade_prompt_ctr_pct numeric(5,2),
  crash_free_pct numeric(5,2),
  channel_class text not null check (channel_class in (
    'production','beta','internal_testing','staged_rollout','hotfix'
  )),
  adoption_status text not null check (adoption_status in (
    'healthy','ramping','lagging','fragmented','blocked_legacy'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.app_version_r3694 enable row level security;

create index if not exists idx_app_version_r3694_org on public.app_version_r3694(organization_id);
create index if not exists idx_app_version_r3694_month on public.app_version_r3694(period_month);
create index if not exists idx_app_version_r3694_status on public.app_version_r3694(adoption_status);

-- =============================================================================
-- TABLE 2: app_version_capa_actions_r3694 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.app_version_capa_actions_r3694 (
  id uuid primary key default gen_random_uuid(),
  version_log_id uuid not null references public.app_version_r3694(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'legacy_os_devices','staged_rollout_halted','low_prompt_visibility',
    'crash_regression_on_new_build','oem_store_propagation_delay',
    'min_version_policy_not_enforced','offline_field_devices','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'enable_forced_upgrade','raise_min_supported_version','fix_crash_and_rerelease',
    'increase_prompt_frequency','expand_staged_rollout','coordinate_play_store_rollout',
    'notify_field_teams','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impacted_installs numeric(12,0),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.app_version_capa_actions_r3694 enable row level security;

create index if not exists idx_app_version_capa_r3694_log on public.app_version_capa_actions_r3694(version_log_id);
create index if not exists idx_app_version_capa_r3694_status on public.app_version_capa_actions_r3694(capa_status);

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

  -- 16 version-adoption rows
  insert into public.app_version_r3694 (
    organization_id, version_name, release_channel, period_month, release_date,
    days_since_release, installs_on_version, adoption_pct, target_adoption_pct,
    devices_below_min_version, forced_upgrade_active, upgrade_prompt_ctr_pct,
    crash_free_pct, channel_class, adoption_status, trend_dir, notes
  )
  select v_org_id, q.ver, q.chan, q.pmon::date, q.rdate::date,
    q.dsr, q.inst, q.adop, q.tadop,
    q.legacy, q.forced, q.ctr,
    q.crashfree, q.cclass, q.astatus, q.tdir, q.nt
  from (values
    ('2.15.0','play_store_production','2026-08-01','2026-07-24',
     16,15240,62.5,60.0,410,false,38.6,99.58,'staged_rollout','ramping','improving','Staged rollout at 50% — adoption tracking ahead of target'),
    ('2.14.2','play_store_production','2026-08-01','2026-07-08',
     32,20110,82.4,85.0,260,false,33.1,99.66,'production','lagging','stable','Prompt CTR flat; adoption 2.6 pts below target'),
    ('2.14.1','play_store_production','2026-07-01','2026-06-30',
     40,22480,91.2,85.0,180,false,44.8,99.74,'hotfix','healthy','improving','Payments crash hotfix — forced prompt drove fast uptake'),
    ('2.14.0','play_store_production','2026-07-01','2026-06-12',
     58,4310,17.6,10.0,520,true,27.9,99.41,'production','fragmented','worsening','Residual 2.14.0 cohort fragmented across old OEM builds'),
    ('2.13.4','play_store_production','2026-07-01','2026-05-20',
     81,1860,7.6,5.0,1140,true,19.4,99.02,'production','blocked_legacy','worsening','Android 8 devices cannot take 2.14+ — forced-upgrade wall active'),
    ('2.15.0-beta.2','play_store_beta','2026-08-01','2026-07-18',
     22,940,71.3,70.0,40,false,52.7,99.35,'beta','healthy','stable','Beta cohort healthy; marketplace flows validated'),
    ('2.15.0-beta.1','play_store_beta','2026-07-01','2026-07-04',
     36,310,23.5,15.0,60,false,29.8,98.92,'beta','lagging','improving','Old beta lingering on tester devices — nudge sent'),
    ('2.16.0-int.3','play_store_internal','2026-08-01','2026-07-30',
     10,84,93.3,90.0,2,false,66.4,98.75,'internal_testing','healthy','stable','Internal track auto-updates; QA devices current'),
    ('2.14.2-field','field_ops_sideload','2026-08-01','2026-07-10',
     30,620,48.4,70.0,330,false,12.6,99.55,'staged_rollout','blocked_legacy','worsening','Field engineer tablets offline for weeks — sideload lagging'),
    ('2.13.0','play_store_production','2026-06-01','2026-04-28',
     103,640,2.6,2.0,610,true,15.2,98.88,'production','blocked_legacy','worsening','EOL build behind forced-upgrade wall; store listing removed'),
    ('2.14.0-beta.3','play_store_beta','2026-06-01','2026-05-30',
     71,120,9.8,5.0,25,true,21.7,99.12,'beta','fragmented','stable','Stale beta cohort — forced update onto 2.15 beta line'),
    ('2.15.1','play_store_production','2026-08-01','2026-08-05',
     4,3480,14.3,12.0,90,false,47.9,99.69,'hotfix','ramping','improving','Auth token-refresh hotfix ramping on schedule'),
    ('2.16.0-int.2','play_store_internal','2026-07-01','2026-07-16',
     24,12,13.3,10.0,0,false,58.3,99.05,'internal_testing','ramping','stable','Older internal build cycling out as QA devices update'),
    ('2.15.0-rc.1','play_store_production','2026-07-01','2026-07-20',
     20,8240,33.8,30.0,150,false,36.5,99.48,'staged_rollout','ramping','improving','RC staged at 20% then promoted — no blocking crashes'),
    ('2.13.2','play_store_production','2026-06-01','2026-03-30',
     132,380,1.5,1.0,380,true,9.8,98.61,'production','blocked_legacy','stable','Legacy Android 7/8 devices pinned — replacement program running'),
    ('2.14.3','play_store_production','2026-08-01','2026-08-02',
     7,5920,24.1,20.0,120,false,43.2,99.77,'hotfix','healthy','improving','Marketplace bid-refresh hotfix adopted quickly')
  ) as q(ver, chan, pmon, rdate, dsr, inst, adop, tadop, legacy, forced, ctr, crashfree, cclass, astatus, tdir, nt);

  -- CAPA seed — attach to specific releases via version_name
  insert into public.app_version_capa_actions_r3694 (
    version_log_id, root_cause, corrective_action, capa_status,
    impacted_installs, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.impacted, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('2.13.4','legacy_os_devices','raise_min_supported_version','in_progress',1140,'Priya Nair (Mobile Lead)','2026-08-20',null,'Min SDK raised to 26 in 2.16; device-replacement list shared with field ops'),
    ('2.14.0','min_version_policy_not_enforced','enable_forced_upgrade','closed',520,'Arjun Mehta (Release Mgr)','2026-07-25','2026-07-21','Forced-upgrade flag enabled for builds below 2.14.1; cohort draining'),
    ('2.14.2-field','offline_field_devices','notify_field_teams','escalated',330,'Kavitha Rao (Field Ops)','2026-08-12',null,'Field tablets offline over 3 weeks; depot-sync push scheduled'),
    ('2.13.0','legacy_os_devices','raise_min_supported_version','overdue',610,'Priya Nair (Mobile Lead)','2026-07-31',null,'EOL cohort not draining — hardware refresh budget pending'),
    ('2.14.2','low_prompt_visibility','increase_prompt_frequency','verification_pending',260,'Sneha Iyer (Growth)','2026-08-15',null,'Prompt cadence raised from 7d to 3d; measuring CTR lift'),
    ('2.15.0','staged_rollout_halted','expand_staged_rollout','in_progress',410,'Arjun Mehta (Release Mgr)','2026-08-14',null,'Rollout expanded 20% to 50% after crash-free held above 99.5'),
    ('2.15.0-beta.1','crash_regression_on_new_build','fix_crash_and_rerelease','closed',60,'Dev Platform Squad','2026-07-18','2026-07-16','ANR in bid-sync fixed in beta.2; testers migrated'),
    ('2.14.0-beta.3','oem_store_propagation_delay','coordinate_play_store_rollout','open',25,'Arjun Mehta (Release Mgr)','2026-08-18',null,'Play tester track propagation slow on two OEM stores')
  ) as q(verkey, rc, ca, cst, impacted, ownr, tcd, acd, nt)
  join public.app_version_r3694 e
    on e.organization_id = v_org_id and e.version_name = q.verkey;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Adoption status distribution
create or replace function public.founder_r3694_adoption_status_rollup()
returns table(adoption_status text, releases bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.app_version_r3694)
  select l.adoption_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.app_version_r3694 l
  group by l.adoption_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3694_adoption_status_rollup() from public, anon;
grant execute on function public.founder_r3694_adoption_status_rollup() to authenticated;

-- 2) Release-channel scorecard
create or replace function public.founder_r3694_channel_scorecard()
returns table(
  release_channel text,
  total_releases bigint,
  healthy bigint,
  lagging bigint,
  fragmented_or_blocked bigint,
  forced_active bigint,
  legacy_devices bigint,
  avg_adoption_pct numeric,
  avg_crash_free_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.release_channel,
    count(*)::bigint,
    count(*) filter (where l.adoption_status = 'healthy')::bigint,
    count(*) filter (where l.adoption_status = 'lagging')::bigint,
    count(*) filter (where l.adoption_status in ('fragmented','blocked_legacy'))::bigint,
    count(*) filter (where l.forced_upgrade_active = true)::bigint,
    coalesce(sum(l.devices_below_min_version),0)::bigint,
    round(avg(l.adoption_pct), 1),
    round(avg(l.crash_free_pct), 2)
  from public.app_version_r3694 l
  group by l.release_channel
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3694_channel_scorecard() from public, anon;
grant execute on function public.founder_r3694_channel_scorecard() to authenticated;

-- 3) Channel-class × adoption-status matrix
create or replace function public.founder_r3694_channel_class_status_matrix()
returns table(channel_class text, adoption_status text, releases bigint, avg_adoption_pct numeric, legacy_devices bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.channel_class, l.adoption_status, count(*)::bigint,
    round(avg(l.adoption_pct), 1),
    coalesce(sum(l.devices_below_min_version),0)::bigint
  from public.app_version_r3694 l
  group by l.channel_class, l.adoption_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3694_channel_class_status_matrix() from public, anon;
grant execute on function public.founder_r3694_channel_class_status_matrix() to authenticated;

-- 4) Monthly adoption trend
create or replace function public.founder_r3694_monthly_adoption_trend()
returns table(period_month date, releases bigint, avg_adoption_pct numeric, avg_crash_free_pct numeric, forced_active bigint, legacy_devices bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.adoption_pct), 1),
    round(avg(l.crash_free_pct), 2),
    count(*) filter (where l.forced_upgrade_active = true)::bigint,
    coalesce(sum(l.devices_below_min_version),0)::bigint
  from public.app_version_r3694 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3694_monthly_adoption_trend() from public, anon;
grant execute on function public.founder_r3694_monthly_adoption_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3694_capa_status_board()
returns table(capa_status text, findings bigint, avg_impacted_installs numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impacted_installs)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.app_version_capa_actions_r3694 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3694_capa_status_board() from public, anon;
grant execute on function public.founder_r3694_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3694_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impacted_installs numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.app_version_capa_actions_r3694)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impacted_installs),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.app_version_capa_actions_r3694 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3694_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3694_root_cause_pareto() to authenticated;

-- 7) Legacy-device digest
create or replace function public.founder_r3694_legacy_device_digest()
returns table(
  release_channel text,
  releases bigint,
  releases_with_legacy bigint,
  total_legacy_devices bigint,
  forced_walls_active bigint,
  avg_prompt_ctr_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.release_channel,
    count(*)::bigint,
    count(*) filter (where l.devices_below_min_version > 0)::bigint,
    coalesce(sum(l.devices_below_min_version),0)::bigint,
    count(*) filter (where l.forced_upgrade_active = true)::bigint,
    round(avg(l.upgrade_prompt_ctr_pct), 1)
  from public.app_version_r3694 l
  group by l.release_channel
  order by coalesce(sum(l.devices_below_min_version),0) desc;
end;
$$;

revoke all on function public.founder_r3694_legacy_device_digest() from public, anon;
grant execute on function public.founder_r3694_legacy_device_digest() to authenticated;

-- 8) High-risk adoption queue (blocked_legacy / fragmented / worsening)
create or replace function public.founder_r3694_high_risk_queue()
returns table(
  version_name text,
  release_channel text,
  channel_class text,
  period_month date,
  adoption_status text,
  trend_dir text,
  adoption_pct numeric,
  target_adoption_pct numeric,
  devices_below_min_version int,
  forced_upgrade_active boolean,
  crash_free_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.version_name, l.release_channel, l.channel_class, l.period_month,
    l.adoption_status, l.trend_dir, l.adoption_pct, l.target_adoption_pct,
    l.devices_below_min_version, l.forced_upgrade_active, l.crash_free_pct, l.notes
  from public.app_version_r3694 l
  where l.adoption_status in ('blocked_legacy','fragmented')
     or l.trend_dir = 'worsening'
     or l.devices_below_min_version >= 300
     or l.crash_free_pct < 99.0
  order by l.devices_below_min_version desc, l.version_name;
end;
$$;

revoke all on function public.founder_r3694_high_risk_queue() from public, anon;
grant execute on function public.founder_r3694_high_risk_queue() to authenticated;
