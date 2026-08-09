-- Round 3709: Founder App Localization / i18n String-Coverage Board
-- App i18n governance — language × app surface × string coverage × machine-translation share × native review × stale strings × critical untranslated × trend × CAPA

-- =============================================================================
-- TABLE 1: i18n_coverage_r3709 — per-language / per-surface string-coverage board
-- =============================================================================
create table if not exists public.i18n_coverage_r3709 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  coverage_code text not null,
  language_name text not null,
  app_surface text not null,
  period_month date not null,
  strings_total int not null,
  strings_translated int not null,
  coverage_pct numeric(5,2),
  machine_translated_pct numeric(5,2),
  reviewed_by_native_pct numeric(5,2),
  stale_translations int not null,
  untranslated_critical int not null,
  user_pct_on_language numeric(5,2),
  surface_class text not null check (surface_class in (
    'onboarding_kyc','job_flow','payments','notifications','help_support'
  )),
  coverage_status text not null check (coverage_status in (
    'complete','near_complete','gaps','critical_gaps','not_started'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.i18n_coverage_r3709 enable row level security;

create index if not exists idx_i18n_coverage_r3709_org on public.i18n_coverage_r3709(organization_id);
create index if not exists idx_i18n_coverage_r3709_month on public.i18n_coverage_r3709(period_month);
create index if not exists idx_i18n_coverage_r3709_status on public.i18n_coverage_r3709(coverage_status);

-- =============================================================================
-- TABLE 2: i18n_coverage_capa_actions_r3709 — CAPA & localization remediation actions
-- =============================================================================
create table if not exists public.i18n_coverage_capa_actions_r3709 (
  id uuid primary key default gen_random_uuid(),
  coverage_id uuid not null references public.i18n_coverage_r3709(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'translator_capacity_shortage','new_feature_strings_untagged','glossary_terminology_gap',
    'machine_translation_low_quality','string_freeze_missed','vendor_delivery_delay',
    'plural_gender_rules_missing','no_native_reviewer','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'assign_translation_vendor','hire_native_reviewer','run_machine_translation_pass',
    'update_glossary','enforce_string_freeze','add_i18n_lint_ci_gate',
    'prioritize_critical_strings','escalate_to_product','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_level text not null check (impact_level in (
    'critical','high','medium','low'
  )),
  users_impacted_pct numeric(5,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.i18n_coverage_capa_actions_r3709 enable row level security;

create index if not exists idx_i18n_coverage_capa_r3709_cov on public.i18n_coverage_capa_actions_r3709(coverage_id);
create index if not exists idx_i18n_coverage_capa_r3709_status on public.i18n_coverage_capa_actions_r3709(capa_status);

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

  -- 16 coverage board rows
  insert into public.i18n_coverage_r3709 (
    organization_id, coverage_code, language_name, app_surface, period_month,
    strings_total, strings_translated, coverage_pct, machine_translated_pct,
    reviewed_by_native_pct, stale_translations, untranslated_critical,
    user_pct_on_language, surface_class, coverage_status, trend_dir, notes
  )
  select v_org_id, q.ccode, q.lang, q.surf, q.pmonth::date,
    q.stot, q.stx, q.cov, q.mtp,
    q.nrp, q.stale, q.ucrit,
    q.upct, q.sclass, q.cstat, q.tdir, q.nt
  from (values
    ('I18N-HI-ONB','Hindi','Onboarding & KYC','2026-07-01',
     620,620,100.00,12.50,88.00,4,0,38.50,'onboarding_kyc','complete','stable','Hindi onboarding fully covered — glossary refresh done'),
    ('I18N-HI-PAY','Hindi','Payments & Payouts','2026-07-01',
     480,470,97.90,8.20,92.00,6,2,38.50,'payments','near_complete','improving','Two critical payout error strings pending Hindi native review'),
    ('I18N-TA-ONB','Tamil','Onboarding & KYC','2026-07-01',
     620,588,94.80,22.00,71.50,11,3,14.20,'onboarding_kyc','near_complete','improving','Tamil KYC flow near complete — Aadhaar consent copy in review'),
    ('I18N-TA-JOB','Tamil','Job Flow','2026-07-01',
     910,742,81.50,34.00,55.00,28,9,14.20,'job_flow','gaps','stable','Tamil job-flow backlog with vendor — bid & AMC strings pending'),
    ('I18N-TE-JOB','Telugu','Job Flow','2026-07-01',
     910,655,72.00,41.00,48.00,35,14,11.80,'job_flow','gaps','improving','Telugu job flow catching up after vendor batch delivery'),
    ('I18N-TE-NOTIF','Telugu','Push Notifications','2026-07-01',
     340,190,55.90,62.00,30.00,22,18,11.80,'notifications','critical_gaps','worsening','Telugu notifications mostly machine translated — quality complaints'),
    ('I18N-KN-ONB','Kannada','Onboarding & KYC','2026-07-01',
     620,502,81.00,38.00,44.00,19,6,8.60,'onboarding_kyc','gaps','stable','Kannada onboarding gaps in bank-detail and GST screens'),
    ('I18N-KN-HELP','Kannada','Help Centre','2026-07-01',
     1250,0,0.00,0.00,0.00,0,42,8.60,'help_support','not_started','stable','Kannada help centre not started — vendor scoping in progress'),
    ('I18N-MR-JOB','Marathi','Job Flow','2026-07-01',
     910,819,90.00,26.00,64.00,15,4,9.40,'job_flow','near_complete','improving','Marathi job flow strong — Pune engineer cohort feedback positive'),
    ('I18N-MR-PAY','Marathi','Payments & Payouts','2026-07-01',
     480,331,69.00,44.00,38.00,26,11,9.40,'payments','critical_gaps','worsening','Marathi payout error strings shipped in English after freeze miss'),
    ('I18N-BN-ONB','Bengali','Onboarding & KYC','2026-07-01',
     620,366,59.00,51.00,25.00,31,16,7.20,'onboarding_kyc','critical_gaps','stable','Bengali onboarding blocked — no native reviewer on panel'),
    ('I18N-BN-NOTIF','Bengali','Push Notifications','2026-07-01',
     340,0,0.00,0.00,0.00,0,36,7.20,'notifications','not_started','stable','Bengali notifications untagged in i18n pipeline — CI gate missing'),
    ('I18N-HI-JOB-JUN','Hindi','Job Flow','2026-06-01',
     880,858,97.50,10.00,90.00,8,1,37.90,'job_flow','near_complete','improving','June Hindi job-flow snapshot — steady native-review cadence'),
    ('I18N-TA-PAY-JUN','Tamil','Payments & Payouts','2026-06-01',
     470,376,80.00,30.00,52.00,18,7,13.80,'payments','gaps','stable','June Tamil payments snapshot — UPI mandate strings pending'),
    ('I18N-TE-ONB-MAY','Telugu','Onboarding & KYC','2026-05-01',
     600,384,64.00,47.00,33.00,27,12,11.10,'onboarding_kyc','critical_gaps','improving','May Telugu onboarding snapshot — plural rules missing in ICU format'),
    ('I18N-KN-JOB-MAY','Kannada','Job Flow','2026-05-01',
     860,559,65.00,45.00,29.00,30,10,8.10,'job_flow','gaps','worsening','May Kannada job-flow snapshot — stale strings piling after release')
  ) as q(ccode, lang, surf, pmonth, stot, stx, cov, mtp, nrp, stale, ucrit, upct, sclass, cstat, tdir, nt);

  -- CAPA seed — attach to specific coverage rows via coverage_code
  insert into public.i18n_coverage_capa_actions_r3709 (
    coverage_id, root_cause, corrective_action, capa_status,
    impact_level, users_impacted_pct, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.impl, q.uip, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('I18N-TE-NOTIF','machine_translation_low_quality','hire_native_reviewer','in_progress','high',11.80,'Lakshmi Naidu','2026-07-20',null,'Telugu push notifications MT-heavy — native reviewer onboarding this sprint'),
    ('I18N-KN-HELP','translator_capacity_shortage','assign_translation_vendor','open','critical',8.60,'Prakash Shetty','2026-08-10',null,'Kannada help centre 1250 strings — vendor RFQ out to two Bengaluru agencies'),
    ('I18N-MR-PAY','string_freeze_missed','enforce_string_freeze','escalated','critical',9.40,'Sneha Kulkarni','2026-07-15',null,'Payout strings shipped after freeze — Marathi users see English error copy'),
    ('I18N-BN-ONB','no_native_reviewer','hire_native_reviewer','open','high',7.20,'Anirban Sen','2026-07-25',null,'Bengali reviewer panel empty — Kolkata freelancer shortlist in progress'),
    ('I18N-BN-NOTIF','new_feature_strings_untagged','add_i18n_lint_ci_gate','in_progress','medium',7.20,'Anirban Sen','2026-07-30',null,'Notification templates bypass i18n extraction — CI lint gate being added'),
    ('I18N-HI-PAY','glossary_terminology_gap','update_glossary','verification_pending','medium',38.50,'Ravi Verma','2026-07-12',null,'UPI mandate terminology standardized in Hindi glossary — verify next release'),
    ('I18N-TA-JOB','vendor_delivery_delay','escalate_to_product','overdue','high',14.20,'Meena Sundaram','2026-07-05',null,'Tamil job-flow vendor batch two weeks late — escalated for re-prioritization'),
    ('I18N-TE-ONB-MAY','plural_gender_rules_missing','run_machine_translation_pass','closed','low',11.10,'Lakshmi Naidu','2026-06-15','2026-06-12','Telugu plural rules added to ICU message format — MT backfill completed')
  ) as q(ccode, rc, ca, cst, impl, uip, own, tcd, acd, nt)
  join public.i18n_coverage_r3709 e
    on e.organization_id = v_org_id and e.coverage_code = q.ccode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Coverage status distribution
create or replace function public.founder_r3709_coverage_status_rollup()
returns table(coverage_status text, boards bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.i18n_coverage_r3709)
  select l.coverage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.i18n_coverage_r3709 l
  group by l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3709_coverage_status_rollup() from public, anon;
grant execute on function public.founder_r3709_coverage_status_rollup() to authenticated;

-- 2) Language-level coverage scorecard
create or replace function public.founder_r3709_language_scorecard()
returns table(
  language_name text,
  surfaces bigint,
  strings_total bigint,
  strings_translated bigint,
  avg_coverage_pct numeric,
  avg_machine_pct numeric,
  avg_native_review_pct numeric,
  stale_total bigint,
  critical_untranslated bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.language_name,
    count(*)::bigint,
    coalesce(sum(l.strings_total),0)::bigint,
    coalesce(sum(l.strings_translated),0)::bigint,
    round(avg(l.coverage_pct), 1),
    round(avg(l.machine_translated_pct), 1),
    round(avg(l.reviewed_by_native_pct), 1),
    coalesce(sum(l.stale_translations),0)::bigint,
    coalesce(sum(l.untranslated_critical),0)::bigint
  from public.i18n_coverage_r3709 l
  group by l.language_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3709_language_scorecard() from public, anon;
grant execute on function public.founder_r3709_language_scorecard() to authenticated;

-- 3) Surface class × coverage status matrix
create or replace function public.founder_r3709_surface_status_matrix()
returns table(surface_class text, coverage_status text, boards bigint, avg_coverage_pct numeric, critical_untranslated bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.surface_class, l.coverage_status, count(*)::bigint,
    round(avg(l.coverage_pct), 1),
    coalesce(sum(l.untranslated_critical),0)::bigint
  from public.i18n_coverage_r3709 l
  group by l.surface_class, l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3709_surface_status_matrix() from public, anon;
grant execute on function public.founder_r3709_surface_status_matrix() to authenticated;

-- 4) Monthly coverage trend
create or replace function public.founder_r3709_monthly_coverage_trend()
returns table(period_month date, boards bigint, avg_coverage_pct numeric, avg_machine_pct numeric, stale_total bigint, critical_untranslated bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.coverage_pct), 1),
    round(avg(l.machine_translated_pct), 1),
    coalesce(sum(l.stale_translations),0)::bigint,
    coalesce(sum(l.untranslated_critical),0)::bigint
  from public.i18n_coverage_r3709 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3709_monthly_coverage_trend() from public, anon;
grant execute on function public.founder_r3709_monthly_coverage_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3709_capa_status_board()
returns table(capa_status text, findings bigint, avg_users_impacted_pct numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.users_impacted_pct)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.i18n_coverage_capa_actions_r3709 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3709_capa_status_board() from public, anon;
grant execute on function public.founder_r3709_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3709_root_cause_pareto()
returns table(root_cause text, occurrences bigint, avg_users_impacted_pct numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.i18n_coverage_capa_actions_r3709)
  select c.root_cause, count(*)::bigint,
    round(avg(c.users_impacted_pct)::numeric, 1),
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.i18n_coverage_capa_actions_r3709 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3709_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3709_root_cause_pareto() to authenticated;

-- 7) Impact-level digest
create or replace function public.founder_r3709_impact_digest()
returns table(impact_level text, findings bigint, open_findings bigint, avg_users_impacted_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.impact_level, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    round(avg(c.users_impacted_pct)::numeric, 1)
  from public.i18n_coverage_capa_actions_r3709 c
  group by c.impact_level
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3709_impact_digest() from public, anon;
grant execute on function public.founder_r3709_impact_digest() to authenticated;

-- 8) High-risk coverage queue (critical gaps / not started / worsening)
create or replace function public.founder_r3709_high_risk_queue()
returns table(
  language_name text,
  app_surface text,
  coverage_code text,
  period_month date,
  coverage_pct numeric,
  coverage_status text,
  untranslated_critical int,
  stale_translations int,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.language_name, l.app_surface, l.coverage_code, l.period_month,
    l.coverage_pct, l.coverage_status, l.untranslated_critical, l.stale_translations,
    l.trend_dir, l.notes
  from public.i18n_coverage_r3709 l
  where l.coverage_status in ('critical_gaps','not_started')
     or l.trend_dir = 'worsening'
     or l.untranslated_critical > 10
     or l.stale_translations > 25
  order by l.period_month desc, l.untranslated_critical desc;
end;
$$;

revoke execute on function public.founder_r3709_high_risk_queue() from public, anon;
grant execute on function public.founder_r3709_high_risk_queue() to authenticated;
