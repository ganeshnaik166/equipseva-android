-- Round 3737: Founder Data-Retention Policy / Data-Purge Compliance Board
-- Retention-schedule adherence & systematic data-purge compliance per data category —
-- retention period vs actual, purge-due backlog, legal-hold overrides, storage cost.
-- Distinct from any DPDP data-principal-request/DSAR-fulfilment page (individual REQUEST-driven
-- access/erasure) and from any legal-hold/e-discovery page (preservation, not scheduled purge) —
-- this ship is proactive, systematic retention-schedule compliance.

-- =============================================================================
-- TABLE 1: data_retain_r3737 — retention-schedule & purge-compliance facts
-- =============================================================================
create table if not exists public.data_retain_r3737 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  data_category text not null,
  system_name text not null,
  period_month date not null,
  retention_period_months int,
  records_due_for_purge int,
  records_purged int,
  purge_backlog int,
  legal_hold_override boolean not null,
  purge_verification_logged boolean not null,
  avg_purge_delay_days numeric,
  storage_cost_rupees numeric(12,2),
  category_class text not null check (category_class in (
    'customer_pii','employee_records','financial_records','clinical_service_logs','marketing_data'
  )),
  retention_status text not null check (retention_status in (
    'compliant','purge_due_soon','purge_backlog','legal_hold_active','policy_violation'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.data_retain_r3737 enable row level security;

create index if not exists idx_data_retain_r3737_org on public.data_retain_r3737(organization_id);
create index if not exists idx_data_retain_r3737_month on public.data_retain_r3737(period_month);
create index if not exists idx_data_retain_r3737_status on public.data_retain_r3737(retention_status);

-- =============================================================================
-- TABLE 2: data_retain_capa_actions_r3737 — CAPA for retention/purge gaps
-- =============================================================================
create table if not exists public.data_retain_capa_actions_r3737 (
  id uuid primary key default gen_random_uuid(),
  retain_id uuid references public.data_retain_r3737(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.data_retain_capa_actions_r3737 enable row level security;

create index if not exists idx_data_retain_capa_r3737_retain on public.data_retain_capa_actions_r3737(retain_id);
create index if not exists idx_data_retain_capa_r3737_status on public.data_retain_capa_actions_r3737(capa_status);

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

  -- 16 retention rows
  insert into public.data_retain_r3737 (
    organization_id, data_category, system_name, period_month, retention_period_months,
    records_due_for_purge, records_purged, purge_backlog, legal_hold_override,
    purge_verification_logged, avg_purge_delay_days, storage_cost_rupees,
    category_class, retention_status, trend_dir, notes
  )
  select v_org_id, q.dc, q.sn, q.pm::date, q.rpm::int,
    q.rdp::int, q.rp::int, q.pb::int, q.lho,
    q.pvl, q.apd::numeric, q.scr::numeric,
    q.cc, q.rs, q.td, q.nt
  from (values
    ('Customer KYC Documents','CRM Platform','2026-07-01',84,
     420,420,0,false,true,2.0,18500.00,'customer_pii','compliant','stable','KYC docs purged on schedule per RBI 8-year retention rule'),
    ('Ex-Employee HR Files','HRMS','2026-07-01',96,
     65,40,25,false,true,18.0,9200.00,'employee_records','purge_backlog','worsening','HRMS batch-purge job failing silently for exited-employee cohort since May'),
    ('GST Invoice Records','Finance ERP','2026-07-01',96,
     0,0,0,false,true,null,42000.00,'financial_records','compliant','stable','Statutory 8-year GST retention — next purge window opens 2028'),
    ('Field-Service Job Logs','Field Ops App','2026-07-01',36,
     310,180,130,false,false,25.0,15400.00,'clinical_service_logs','purge_backlog','worsening','Verification logging disabled on job-log purge cron — audit trail incomplete'),
    ('Marketing Campaign Leads','Marketing Automation','2026-07-01',24,
     980,910,70,false,true,6.0,4300.00,'marketing_data','purge_due_soon','improving','Stale-lead purge sweep scheduled for Aug 15 to clear remaining backlog'),
    ('Litigation-Hold Customer Records','CRM Platform','2026-07-01',84,
     0,0,0,true,true,null,6800.00,'customer_pii','legal_hold_active','stable','Consumer-forum dispute — purge suspended pending case closure, hold documented'),
    ('Payroll Bank Details','Payroll System','2026-06-01',96,
     15,15,0,false,true,3.0,7100.00,'employee_records','compliant','improving','Payroll retention automation matured after Q1 remediation'),
    ('AMC Contract Financials','Finance ERP','2026-06-01',96,
     0,0,0,false,true,null,38500.00,'financial_records','compliant','stable','Companies Act 8-year rule — no purge due this cycle'),
    ('Technician Visit Photos','Field Ops App','2026-06-01',36,
     450,120,330,false,false,42.0,21000.00,'clinical_service_logs','policy_violation','worsening','Photo-purge job has not run successfully in 3 months — storage cost climbing'),
    ('Unsubscribed Newsletter Contacts','Marketing Automation','2026-06-01',24,
     620,600,20,false,true,5.0,3100.00,'marketing_data','purge_due_soon','stable','Near-complete purge — residual 20 records held for suppression-list dedup'),
    ('Ex-Customer Account Data','CRM Platform','2026-06-01',84,
     140,60,80,false,false,30.0,11200.00,'customer_pii','purge_backlog','worsening','Account-closure purge trigger not firing for churned SME accounts'),
    ('Terminated Vendor Employee Access Logs','IAM Platform','2026-06-01',60,
     55,55,0,false,true,4.0,2900.00,'employee_records','compliant','improving','Access-log purge tightened after IT security audit recommendation'),
    ('Refund & Chargeback Records','Finance ERP','2026-05-01',96,
     0,0,0,false,true,null,26400.00,'financial_records','compliant','stable','No purge activity due — within statutory window'),
    ('Service-Call Recordings','Support Desk','2026-05-01',18,
     260,150,110,false,false,20.0,17800.00,'clinical_service_logs','purge_backlog','stable','Call-recording purge backlog persists — storage vendor invoice flagged by finance'),
    ('Consent-Withdrawn Marketing Profiles','Marketing Automation','2026-05-01',24,
     0,0,0,true,true,null,1500.00,'marketing_data','legal_hold_active','stable','Regulator inquiry on consent practices — profiles held pending closure'),
    ('Disputed Insurance-Claim Customer Files','CRM Platform','2026-05-01',84,
     0,0,0,true,false,null,8900.00,'customer_pii','legal_hold_active','worsening','Legal hold active but purge-verification logging not yet wired for held records')
  ) as q(dc, sn, pm, rpm, rdp, rp, pb, lho, pvl, apd, scr, cc, rs, td, nt);

  -- 8 CAPA rows — attach to retention rows via data_category + system_name
  insert into public.data_retain_capa_actions_r3737 (
    retain_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Ex-Employee HR Files','HRMS','Batch-purge job silently failing on exited-employee cohort','Fix HRMS purge job error handling & add failure alerting','in_progress','IT Systems Lead','2026-08-25',null,'Root cause traced to schema change in exit-date field last release'),
    ('Field-Service Job Logs','Field Ops App','Verification logging flag disabled during last app update','Re-enable purge-verification logging & backfill audit trail','open','Field Ops Engineering Lead','2026-08-20',null,'Flag reset accidentally during v4.2 config migration'),
    ('Technician Visit Photos','Field Ops App','Photo-purge cron job crashing on large media batches','Rewrite purge job with chunked batch processing','overdue','Field Ops Engineering Lead','2026-08-10',null,'Storage cost up 40% quarter-on-quarter while job has been broken'),
    ('Ex-Customer Account Data','CRM Platform','Account-closure event not triggering purge workflow for SME tier','Wire SME closure event to purge-trigger webhook','open','CRM Platform Owner','2026-08-28',null,'Only SME-tier accounts affected — enterprise tier purges correctly'),
    ('Service-Call Recordings','Support Desk','No automated purge rule configured for call-recording storage','Configure lifecycle rule on recording storage bucket','in_progress','Support Ops Manager','2026-08-22',null,'Vendor storage invoice flagged the gap during finance review'),
    ('Disputed Insurance-Claim Customer Files','CRM Platform','Legal-hold workflow does not enforce verification logging','Extend hold workflow to require verification log entry','open','Data Protection Officer','2026-09-05',null,'Gap found during internal DPDP readiness audit'),
    ('Marketing Campaign Leads','Marketing Automation','Stale-lead threshold set too conservatively, delaying purge','Tighten stale-lead threshold from 18 to 12 months','closed','Marketing Ops Lead','2026-07-30','2026-07-28','Threshold change deployed and backlog cleared same week'),
    ('Unsubscribed Newsletter Contacts','Marketing Automation','Residual suppression-list records not auto-expiring','Add expiry rule for suppression-list residual records','in_progress','Marketing Ops Lead','2026-08-15',null,'Low-priority cleanup — only 20 records affected this cycle')
  ) as q(dc, sn, rc, ca, cst, ownr, tcd, acd, nt)
  join public.data_retain_r3737 e
    on e.organization_id = v_org_id and e.data_category = q.dc and e.system_name = q.sn;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Retention-status distribution
create or replace function public.founder_r3737_retention_status_rollup()
returns table(retention_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.data_retain_r3737)
  select l.retention_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.data_retain_r3737 l
  group by l.retention_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3737_retention_status_rollup() from public, anon;
grant execute on function public.founder_r3737_retention_status_rollup() to authenticated;

-- 2) System-name scorecard
create or replace function public.founder_r3737_system_name_scorecard()
returns table(
  system_name text,
  records bigint,
  compliant_records bigint,
  purge_backlog_records bigint,
  total_purge_backlog bigint,
  avg_purge_delay_days numeric,
  total_storage_cost_rupees numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_name,
    count(*)::bigint,
    count(*) filter (where l.retention_status = 'compliant')::bigint,
    count(*) filter (where l.retention_status = 'purge_backlog')::bigint,
    coalesce(sum(l.purge_backlog),0)::bigint,
    round(avg(l.avg_purge_delay_days), 1),
    round(coalesce(sum(l.storage_cost_rupees),0), 2)
  from public.data_retain_r3737 l
  group by l.system_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3737_system_name_scorecard() from public, anon;
grant execute on function public.founder_r3737_system_name_scorecard() to authenticated;

-- 3) Category-class × retention-status matrix
create or replace function public.founder_r3737_category_class_status_matrix()
returns table(category_class text, retention_status text, records bigint, avg_purge_delay_days numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category_class, l.retention_status, count(*)::bigint,
    round(avg(l.avg_purge_delay_days), 1)
  from public.data_retain_r3737 l
  group by l.category_class, l.retention_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3737_category_class_status_matrix() from public, anon;
grant execute on function public.founder_r3737_category_class_status_matrix() to authenticated;

-- 4) Monthly purge-backlog trend
create or replace function public.founder_r3737_monthly_purge_backlog_trend()
returns table(
  period_month date,
  records bigint,
  total_backlog bigint,
  total_due_for_purge bigint,
  total_purged bigint,
  worsening_records bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.purge_backlog),0)::bigint,
    coalesce(sum(l.records_due_for_purge),0)::bigint,
    coalesce(sum(l.records_purged),0)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.data_retain_r3737 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3737_monthly_purge_backlog_trend() from public, anon;
grant execute on function public.founder_r3737_monthly_purge_backlog_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3737_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.data_retain_capa_actions_r3737 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3737_capa_status_board() from public, anon;
grant execute on function public.founder_r3737_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3737_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.data_retain_capa_actions_r3737)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.data_retain_capa_actions_r3737 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3737_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3737_root_cause_pareto() to authenticated;

-- 7) Purge-backlog digest (backlog present or policy violation, unresolved risk)
create or replace function public.founder_r3737_backlog_digest()
returns table(
  category_class text,
  records bigint,
  total_backlog bigint,
  legal_hold_records bigint,
  verification_not_logged bigint,
  avg_purge_delay_days numeric,
  total_storage_cost_rupees numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category_class,
    count(*)::bigint,
    coalesce(sum(l.purge_backlog),0)::bigint,
    count(*) filter (where l.legal_hold_override = true)::bigint,
    count(*) filter (where l.purge_verification_logged = false)::bigint,
    round(avg(l.avg_purge_delay_days), 1),
    round(coalesce(sum(l.storage_cost_rupees),0), 2)
  from public.data_retain_r3737 l
  where l.retention_status in ('purge_backlog','policy_violation') or l.purge_backlog > 0
  group by l.category_class
  order by total_backlog desc;
end;
$$;

revoke all on function public.founder_r3737_backlog_digest() from public, anon;
grant execute on function public.founder_r3737_backlog_digest() to authenticated;

-- 8) High-risk retention queue (purge backlog / policy violation, worst first)
create or replace function public.founder_r3737_high_risk_queue()
returns table(
  data_category text,
  system_name text,
  category_class text,
  period_month date,
  retention_status text,
  purge_backlog int,
  avg_purge_delay_days numeric,
  legal_hold_override boolean,
  purge_verification_logged boolean,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.data_category, l.system_name, l.category_class, l.period_month,
    l.retention_status, l.purge_backlog, l.avg_purge_delay_days,
    l.legal_hold_override, l.purge_verification_logged, l.notes
  from public.data_retain_r3737 l
  where l.retention_status in ('policy_violation','purge_backlog')
  order by l.purge_backlog desc nulls last, l.period_month desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3737_high_risk_queue() from public, anon;
grant execute on function public.founder_r3737_high_risk_queue() to authenticated;
