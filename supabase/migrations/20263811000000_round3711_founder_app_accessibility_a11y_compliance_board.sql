-- Round 3711: Founder App Accessibility (a11y) Compliance Board
-- App a11y compliance — surface × platform × TalkBack labels × contrast × touch targets × font scaling × critical issues × WCAG target × CAPA

-- =============================================================================
-- TABLE 1: a11y_r3711 — per-surface / per-platform monthly a11y audit rollups
-- =============================================================================
create table if not exists public.a11y_r3711 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  audit_code text not null,
  app_surface text not null,
  platform text not null check (platform in (
    'android','ios','mobile_web'
  )),
  period_month date not null,
  screens_total int not null,
  screens_audited int not null,
  audit_pct numeric(5,2),
  talkback_labeled_pct numeric(5,2),
  contrast_pass_pct numeric(5,2),
  touch_target_pass_pct numeric(5,2),
  font_scaling_pass_pct numeric(5,2),
  critical_issues int not null default 0,
  issues_fixed int not null default 0,
  wcag_level_target text not null check (wcag_level_target in (
    'wcag_2_1_a','wcag_2_1_aa','wcag_2_2_aa'
  )),
  surface_class text not null check (surface_class in (
    'onboarding_kyc','job_flow','payments','notifications','help_support'
  )),
  a11y_status text not null check (a11y_status in (
    'compliant','minor_issues','major_issues','critical_blockers','not_audited'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.a11y_r3711 enable row level security;

create index if not exists idx_a11y_r3711_org on public.a11y_r3711(organization_id);
create index if not exists idx_a11y_r3711_month on public.a11y_r3711(period_month);
create index if not exists idx_a11y_r3711_status on public.a11y_r3711(a11y_status);

-- =============================================================================
-- TABLE 2: a11y_capa_actions_r3711 — a11y CAPA & remediation actions
-- =============================================================================
create table if not exists public.a11y_capa_actions_r3711 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.a11y_r3711(id) on delete cascade,
  raised_at timestamptz not null default now(),
  issue_category text not null check (issue_category in (
    'missing_talkback_label','low_contrast','small_touch_target','font_scaling_break',
    'focus_order_issue','screen_reader_trap','unaudited_surface','third_party_sdk_gap'
  )),
  root_cause text not null check (root_cause in (
    'missing_content_description','hardcoded_font_sizes','low_contrast_brand_palette',
    'small_touch_targets','custom_view_no_a11y_node','third_party_sdk_screen',
    'focus_order_broken','no_a11y_testing_in_ci','legacy_screen_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'add_content_descriptions','migrate_to_sp_units','update_color_tokens',
    'increase_touch_targets','implement_a11y_delegate','escalate_to_sdk_vendor',
    'fix_focus_traversal','add_a11y_ci_checks','redesign_screen','retrain_dev_team','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  affected_users_pct numeric(5,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.a11y_capa_actions_r3711 enable row level security;

create index if not exists idx_a11y_capa_r3711_audit on public.a11y_capa_actions_r3711(audit_id);
create index if not exists idx_a11y_capa_r3711_status on public.a11y_capa_actions_r3711(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) a11y status distribution
create or replace function public.founder_r3711_a11y_status_rollup()
returns table(a11y_status text, surfaces bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.a11y_r3711)
  select l.a11y_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.a11y_r3711 l
  group by l.a11y_status
  order by count(*) desc;
end;
$$;

-- 2) Platform a11y scorecard
create or replace function public.founder_r3711_platform_scorecard()
returns table(
  platform text,
  total_surfaces bigint,
  compliant bigint,
  minor bigint,
  major bigint,
  critical bigint,
  unaudited bigint,
  avg_talkback_pct numeric,
  avg_contrast_pct numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.platform,
    count(*)::bigint,
    count(*) filter (where l.a11y_status = 'compliant')::bigint,
    count(*) filter (where l.a11y_status = 'minor_issues')::bigint,
    count(*) filter (where l.a11y_status = 'major_issues')::bigint,
    count(*) filter (where l.a11y_status = 'critical_blockers')::bigint,
    count(*) filter (where l.a11y_status = 'not_audited')::bigint,
    round(avg(l.talkback_labeled_pct), 1),
    round(avg(l.contrast_pass_pct), 1),
    round(100.0 * count(*) filter (where l.a11y_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.a11y_r3711 l
  group by l.platform
  order by count(*) desc;
end;
$$;

-- 3) Surface class × a11y status matrix
create or replace function public.founder_r3711_surface_class_status_matrix()
returns table(surface_class text, a11y_status text, surfaces bigint, avg_audit_pct numeric, total_critical_issues bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.surface_class, l.a11y_status, count(*)::bigint,
    round(avg(l.audit_pct), 1),
    coalesce(sum(l.critical_issues),0)::bigint
  from public.a11y_r3711 l
  group by l.surface_class, l.a11y_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly issue trend
create or replace function public.founder_r3711_monthly_issue_trend()
returns table(period_month date, surfaces bigint, total_critical_issues bigint, total_issues_fixed bigint, avg_audit_pct numeric, avg_talkback_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.critical_issues),0)::bigint,
    coalesce(sum(l.issues_fixed),0)::bigint,
    round(avg(l.audit_pct), 1),
    round(avg(l.talkback_labeled_pct), 1)
  from public.a11y_r3711 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3711_capa_status_board()
returns table(capa_status text, actions bigint, avg_affected_users_pct numeric, overdue_or_escalated bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.affected_users_pct), 2),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.a11y_capa_actions_r3711 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3711_root_cause_pareto()
returns table(root_cause text, occurrences bigint, avg_affected_users_pct numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.a11y_capa_actions_r3711)
  select c.root_cause, count(*)::bigint,
    round(avg(c.affected_users_pct), 2),
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.a11y_capa_actions_r3711 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Critical-issue digest (by issue category)
create or replace function public.founder_r3711_critical_issue_digest()
returns table(issue_category text, actions bigint, open_actions bigint, avg_affected_users_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.issue_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    round(avg(c.affected_users_pct), 2)
  from public.a11y_capa_actions_r3711 c
  group by c.issue_category
  order by count(*) desc;
end;
$$;

-- 8) High-risk surface queue
create or replace function public.founder_r3711_high_risk_queue()
returns table(
  app_surface text,
  audit_code text,
  platform text,
  surface_class text,
  period_month date,
  a11y_status text,
  critical_issues int,
  issues_fixed int,
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
  select l.app_surface, l.audit_code, l.platform, l.surface_class, l.period_month,
    l.a11y_status, l.critical_issues, l.issues_fixed, l.trend_dir, l.notes
  from public.a11y_r3711 l
  where l.a11y_status in ('critical_blockers','not_audited','major_issues')
     or l.critical_issues > l.issues_fixed
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.app_surface;
end;
$$;

-- =============================================================================
-- Grants
-- =============================================================================
revoke all on function public.founder_r3711_a11y_status_rollup() from public, anon;
revoke all on function public.founder_r3711_platform_scorecard() from public, anon;
revoke all on function public.founder_r3711_surface_class_status_matrix() from public, anon;
revoke all on function public.founder_r3711_monthly_issue_trend() from public, anon;
revoke all on function public.founder_r3711_capa_status_board() from public, anon;
revoke all on function public.founder_r3711_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3711_critical_issue_digest() from public, anon;
revoke all on function public.founder_r3711_high_risk_queue() from public, anon;

grant execute on function public.founder_r3711_a11y_status_rollup() to authenticated;
grant execute on function public.founder_r3711_platform_scorecard() to authenticated;
grant execute on function public.founder_r3711_surface_class_status_matrix() to authenticated;
grant execute on function public.founder_r3711_monthly_issue_trend() to authenticated;
grant execute on function public.founder_r3711_capa_status_board() to authenticated;
grant execute on function public.founder_r3711_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3711_critical_issue_digest() to authenticated;
grant execute on function public.founder_r3711_high_risk_queue() to authenticated;

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

  -- 16 a11y audit rows
  insert into public.a11y_r3711 (
    organization_id, audit_code, app_surface, platform, period_month,
    screens_total, screens_audited, audit_pct, talkback_labeled_pct,
    contrast_pass_pct, touch_target_pass_pct, font_scaling_pass_pct,
    critical_issues, issues_fixed, wcag_level_target, surface_class,
    a11y_status, trend_dir, notes
  )
  select v_org_id, q.acode, q.surf, q.plat, q.pmonth::date,
    q.stot, q.saud, q.apct, q.tbpct,
    q.ctpct, q.ttpct, q.fspct,
    q.crit, q.fixd, q.wcag, q.sclass,
    q.ast, q.trd, q.nt
  from (values
    ('A11Y-ONB-AND-07','Onboarding & Aadhaar KYC','android','2026-07-01',
     14,14,100.00,92.50,88.00,95.50,90.00,2,2,'wcag_2_1_aa','onboarding_kyc','minor_issues','improving','TalkBack labels added to OTP and PAN entry — two contrast fixes shipped'),
    ('A11Y-ONB-IOS-07','Onboarding & Aadhaar KYC','ios','2026-07-01',
     14,12,85.70,89.00,84.50,93.00,88.50,3,1,'wcag_2_1_aa','onboarding_kyc','major_issues','stable','VoiceOver focus order broken on selfie-capture screen'),
    ('A11Y-JOB-AND-07','Job posting & bid flow','android','2026-07-01',
     22,20,90.90,86.00,91.50,89.00,84.00,4,2,'wcag_2_1_aa','job_flow','major_issues','improving','Custom bid-slider missing a11y node — delegate implementation in progress'),
    ('A11Y-JOB-IOS-07','Job posting & bid flow','ios','2026-07-01',
     22,18,81.80,83.50,90.00,87.50,82.00,5,1,'wcag_2_1_aa','job_flow','major_issues','worsening','Dynamic Type breaks bid-comparison layout at XXL sizes'),
    ('A11Y-PAY-AND-07','Payments & payout ledger','android','2026-07-01',
     12,12,100.00,95.00,93.50,97.00,94.50,1,1,'wcag_2_1_aa','payments','compliant','stable','Payout ledger fully labeled — quarterly TalkBack sweep clean'),
    ('A11Y-PAY-IOS-07','Payments & payout ledger','ios','2026-07-01',
     12,10,83.30,78.00,72.50,80.00,75.50,7,2,'wcag_2_1_aa','payments','critical_blockers','worsening','UPI mandate sheet from third-party SDK unreadable by VoiceOver'),
    ('A11Y-NOT-AND-07','Notifications & alerts inbox','android','2026-07-01',
     8,8,100.00,90.50,94.00,92.50,91.00,1,0,'wcag_2_1_aa','notifications','minor_issues','stable','Alert badge lacks state announcement — fix queued for next sprint'),
    ('A11Y-NOT-WEB-07','Notifications & alerts inbox','mobile_web','2026-07-01',
     8,0,0.00,null,null,null,null,0,0,'wcag_2_1_aa','notifications','not_audited','stable','Mobile-web inbox audit not yet scheduled'),
    ('A11Y-HLP-AND-07','Help & support chat','android','2026-07-01',
     10,9,90.00,88.50,86.00,91.50,87.00,2,1,'wcag_2_1_aa','help_support','minor_issues','improving','Chat composer hint text now announced — one contrast issue open'),
    ('A11Y-HLP-WEB-07','Help & support chat','mobile_web','2026-07-01',
     10,7,70.00,74.00,69.50,77.00,72.50,6,1,'wcag_2_1_a','help_support','critical_blockers','stable','Chat widget contrast fails on brand orange — token fix pending'),
    ('A11Y-ONB-AND-06','Onboarding & Aadhaar KYC','android','2026-06-01',
     14,13,92.90,88.00,85.50,93.00,87.50,4,3,'wcag_2_1_aa','onboarding_kyc','major_issues','improving','June sweep — OTP field contentDescription shipped mid-month'),
    ('A11Y-JOB-AND-06','Job posting & bid flow','android','2026-06-01',
     22,19,86.40,82.50,89.00,86.50,81.00,6,3,'wcag_2_1_aa','job_flow','major_issues','improving','Job-card touch targets enlarged — three critical issues carried over'),
    ('A11Y-PAY-AND-06','Payments & payout ledger','android','2026-06-01',
     12,11,91.70,90.50,91.00,94.50,90.00,3,2,'wcag_2_1_aa','payments','minor_issues','improving','Invoice download button labeled — one focus issue remained'),
    ('A11Y-NOT-IOS-06','Notifications & alerts inbox','ios','2026-06-01',
     8,6,75.00,80.00,82.50,85.00,79.50,3,1,'wcag_2_1_a','notifications','major_issues','stable','VoiceOver reads timestamps before titles — ordering fix scoped'),
    ('A11Y-HLP-IOS-06','Help & support chat','ios','2026-06-01',
     10,8,80.00,79.50,81.00,84.50,78.00,4,2,'wcag_2_1_a','help_support','major_issues','stable','FAQ accordion traps screen-reader focus on collapse'),
    ('A11Y-JOB-WEB-05','Job posting & bid flow','mobile_web','2026-05-01',
     22,15,68.20,70.50,73.00,75.50,68.00,8,2,'wcag_2_1_a','job_flow','critical_blockers','improving','Baseline mobile-web audit — bid buttons below 44px target')
  ) as q(acode, surf, plat, pmonth, stot, saud, apct, tbpct, ctpct, ttpct, fspct, crit, fixd, wcag, sclass, ast, trd, nt);

  -- CAPA seed — attach to specific audits via audit_code
  insert into public.a11y_capa_actions_r3711 (
    audit_id, issue_category, root_cause, corrective_action,
    capa_status, affected_users_pct, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.ic, q.rc, q.ca,
    q.cst, q.aup, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('A11Y-PAY-IOS-07','third_party_sdk_gap','third_party_sdk_screen','escalate_to_sdk_vendor','escalated',18.50,'Ravi Iyer','2026-07-20',null,'UPI SDK vendor engaged — a11y fix committed for their Q3 release'),
    ('A11Y-HLP-WEB-07','low_contrast','low_contrast_brand_palette','update_color_tokens','in_progress',9.25,'Sneha Kulkarni','2026-07-15',null,'Brand orange token darkened to 4.6:1 — rollout behind feature flag'),
    ('A11Y-JOB-AND-07','missing_talkback_label','custom_view_no_a11y_node','implement_a11y_delegate','verification_pending',12.00,'Arjun Mehta','2026-07-10',null,'Bid-slider a11y delegate merged — TalkBack re-audit booked'),
    ('A11Y-ONB-IOS-07','focus_order_issue','focus_order_broken','fix_focus_traversal','open',7.75,'Priya Nair','2026-07-18',null,'Selfie-capture focus loop reproduced on iOS 17 — fix scoped'),
    ('A11Y-NOT-WEB-07','unaudited_surface','no_a11y_testing_in_ci','add_a11y_ci_checks','open',5.00,'Vikram Shetty','2026-07-25',null,'axe-core CI job being added before first mobile-web audit'),
    ('A11Y-JOB-WEB-05','small_touch_target','small_touch_targets','increase_touch_targets','closed',10.50,'Arjun Mehta','2026-06-15','2026-06-12','Bid buttons resized to 48dp equivalent — verified on May cohort'),
    ('A11Y-JOB-IOS-07','font_scaling_break','hardcoded_font_sizes','migrate_to_sp_units','overdue',8.25,'Priya Nair','2026-07-01',null,'Dynamic Type migration slipped — layout breaks at XXL sizes'),
    ('A11Y-ONB-AND-06','missing_talkback_label','missing_content_description','add_content_descriptions','closed',6.00,'Sneha Kulkarni','2026-06-20','2026-06-18','OTP field contentDescription shipped in June release')
  ) as q(acode, ic, rc, ca, cst, aup, own, tcd, acd, nt)
  join public.a11y_r3711 e
    on e.organization_id = v_org_id and e.audit_code = q.acode;
end;
$seed$;
