-- Round 3465: Founder Net-Revenue-Retention (NRR) / Gross-Retention Board
-- Per customer-cohort NRR + gross-retention decomposition — starting ARR, expansion, contraction,
-- churn, ending ARR, NRR% / GRR%, retention status, monthly trend & CAPA remediation closure.

-- =============================================================================
-- TABLE 1: nrr_retention_r3465 — per customer-account monthly NRR / GRR decomposition
-- =============================================================================
create table if not exists public.nrr_retention_r3465 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  account_code text not null,
  customer_name text not null,
  customer_segment text not null check (customer_segment in (
    'enterprise_hospital','regional_chain','standalone_clinic','diagnostic_lab','government'
  )),
  cohort text not null,
  starting_arr_rupees numeric(14,2),
  expansion_rupees numeric(14,2),
  contraction_rupees numeric(14,2),
  churn_rupees numeric(14,2),
  ending_arr_rupees numeric(14,2),
  nrr_pct numeric(6,2),
  grr_pct numeric(6,2),
  retention_status text not null check (retention_status in (
    'expanding','stable','contracting','churning'
  )),
  period_month date not null,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nrr_retention_r3465 enable row level security;

create index if not exists idx_nrr_retention_r3465_org on public.nrr_retention_r3465(organization_id);
create index if not exists idx_nrr_retention_r3465_month on public.nrr_retention_r3465(period_month);
create index if not exists idx_nrr_retention_r3465_status on public.nrr_retention_r3465(retention_status);

-- =============================================================================
-- TABLE 2: nrr_retention_capa_actions_r3465 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.nrr_retention_capa_actions_r3465 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  retention_log_id uuid not null references public.nrr_retention_r3465(id) on delete cascade,
  finding_category text not null check (finding_category in (
    'contraction_seat_reduction','churn_full_logo','downgrade_plan_tier','expansion_stalled',
    'usage_decline','payment_delinquency','competitive_displacement','renewal_at_risk','nrr_below_target'
  )),
  root_cause text not null check (root_cause in (
    'pricing_objection','budget_cut','competitor_switch','poor_onboarding','product_gap',
    'service_sla_breach','champion_left','merger_consolidation','low_product_adoption','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'executive_sponsor_engagement','discount_renegotiation','success_plan_reset','product_roadmap_commitment',
    'onboarding_redo','sla_remediation','multi_year_lock_in','win_back_campaign','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nrr_retention_capa_actions_r3465 enable row level security;

create index if not exists idx_nrr_retention_capa_r3465_log on public.nrr_retention_capa_actions_r3465(retention_log_id);
create index if not exists idx_nrr_retention_capa_r3465_status on public.nrr_retention_capa_actions_r3465(capa_status);

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

  -- 16 NRR / GRR account rows
  insert into public.nrr_retention_r3465 (
    organization_id, account_code, customer_name, customer_segment, cohort,
    starting_arr_rupees, expansion_rupees, contraction_rupees, churn_rupees, ending_arr_rupees,
    nrr_pct, grr_pct, retention_status, period_month, trend_dir, notes
  )
  select v_org_id, q.acode, q.cname, q.seg, q.coh,
    q.sarr, q.expn, q.contr, q.chrn, q.earr,
    q.nrr, q.grr, q.rstat, q.pmon::date, q.tdir, q.nt
  from (values
    ('APL-ENT-001','Apollo Hospitals Enterprise','enterprise_hospital','2024-Q1',
     8000000,1200000,200000,0,9000000,112.50,97.50,'expanding','2026-06-01','improving','AMC upsell plus new imaging-site rollout drove strong expansion'),
    ('FRT-ENT-002','Fortis Healthcare','enterprise_hospital','2024-Q1',
     6500000,700000,200000,0,7000000,107.69,96.92,'expanding','2026-06-01','stable','Modality coverage expansion partly offset by one site descope'),
    ('MNP-ENT-003','Manipal Hospitals','enterprise_hospital','2024-Q2',
     5200000,0,400000,0,4800000,92.31,92.31,'contracting','2026-06-01','worsening','Capex freeze led to AMC seat reduction across two units'),
    ('MAX-ENT-004','Max Healthcare','enterprise_hospital','2024-Q2',
     5800000,600000,0,0,6400000,110.34,100.00,'expanding','2026-05-01','improving','Multi-year AMC renewal with added ventilator fleet coverage'),
    ('NAR-ENT-005','Narayana Health','enterprise_hospital','2024-Q3',
     4400000,200000,150000,0,4450000,101.14,96.59,'stable','2026-05-01','stable','Flat renewal; small expansion netted against cath-lab descope'),
    ('MED-CHN-006','Medanta Regional Chain','regional_chain','2024-Q1',
     3200000,300000,100000,0,3400000,106.25,96.88,'expanding','2026-06-01','improving','Regional chain added two secondary-care sites to service contract'),
    ('KIM-CHN-007','KIMS Regional Chain','regional_chain','2024-Q3',
     2800000,0,0,2800000,0,0.00,0.00,'churning','2026-06-01','worsening','Full logo churn — moved to competitor OEM captive service contract'),
    ('YAS-CHN-008','Yashoda Regional Chain','regional_chain','2024-Q2',
     3000000,250000,200000,0,3050000,101.67,93.33,'stable','2026-05-01','stable','Expansion at flagship offset by spares descope at older sites'),
    ('THY-LAB-009','Thyrocare Diagnostics','diagnostic_lab','2024-Q1',
     1800000,400000,0,0,2200000,122.22,100.00,'expanding','2026-06-01','improving','Lab-analyzer AMC and reagent-linked service scaled with new labs'),
    ('DRL-LAB-010','Dr Lal PathLabs','diagnostic_lab','2024-Q2',
     2100000,0,300000,0,1800000,85.71,85.71,'contracting','2026-04-01','worsening','Descope on missing LIS integration; renewal scope reduced'),
    ('MET-LAB-011','Metropolis Labs','diagnostic_lab','2024-Q3',
     1500000,150000,0,0,1650000,110.00,100.00,'expanding','2026-05-01','stable','Added preventive-maintenance tier across analyzer fleet'),
    ('VIJ-CLN-012','Vijaya Diagnostic Clinic','standalone_clinic','2024-Q2',
     900000,0,0,450000,450000,50.00,50.00,'churning','2026-04-01','worsening','Partial churn after repeated service-turnaround SLA breaches'),
    ('CLD-CLN-013','Cloudnine Clinic','standalone_clinic','2024-Q3',
     1100000,100000,50000,0,1150000,104.55,95.45,'stable','2026-06-01','stable','Modest expansion; onboarding gaps kept adoption below target'),
    ('RAI-CLN-014','Rainbow Childrens Clinic','standalone_clinic','2024-Q1',
     1300000,0,200000,0,1100000,84.62,84.62,'contracting','2026-04-01','worsening','Champion exit triggered plan-tier downgrade at renewal'),
    ('ESI-GOV-015','ESIC Govt Hospitals','government','2024-Q2',
     4000000,500000,0,0,4500000,112.50,100.00,'expanding','2026-05-01','improving','Tender win added biomedical-fleet AMC across new govt sites'),
    ('AII-GOV-016','AIIMS Govt Network','government','2024-Q3',
     3600000,0,0,0,3600000,100.00,100.00,'stable','2026-06-01','stable','Renewed at par under annual govt maintenance framework')
  ) as q(acode, cname, seg, coh, sarr, expn, contr, chrn, earr, nrr, grr, rstat, pmon, tdir, nt);

  -- CAPA seed — attach to specific accounts via account_code
  insert into public.nrr_retention_capa_actions_r3465 (
    organization_id, retention_log_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('MNP-ENT-003','contraction_seat_reduction','budget_cut','discount_renegotiation','in_progress',400000,'Priya Nair (CS Lead)','2026-08-15',null,'Seat reduction after capex freeze; renegotiating AMC scope and pricing'),
    ('KIM-CHN-007','churn_full_logo','competitor_switch','win_back_campaign','escalated',2800000,'Rahul Verma (VP CS)','2026-08-01',null,'Full logo lost to competitor OEM; executive win-back campaign launched'),
    ('DRL-LAB-010','contraction_seat_reduction','product_gap','product_roadmap_commitment','open',300000,'Sneha Iyer (Account Mgr)','2026-08-30',null,'Descope on missing LIS integration; roadmap commitment shared'),
    ('VIJ-CLN-012','churn_full_logo','service_sla_breach','sla_remediation','escalated',450000,'Amit Deshpande (Ops)','2026-07-20',null,'Partial churn after repeated SLA breaches; remediation plan active'),
    ('RAI-CLN-014','downgrade_plan_tier','champion_left','executive_sponsor_engagement','open',200000,'Divya Menon (Account Mgr)','2026-08-10',null,'Champion exit drove tier downgrade; new sponsor engagement underway'),
    ('THY-LAB-009','expansion_stalled','low_product_adoption','success_plan_reset','verification_pending',0,'Karan Malhotra (CS)','2026-07-15',null,'Further expansion stalled; adoption success plan reset and in review'),
    ('NAR-ENT-005','renewal_at_risk','pricing_objection','multi_year_lock_in','closed',150000,'Meera Rao (CS Lead)','2026-06-30','2026-06-25','Renewal pricing objection resolved with a multi-year lock-in'),
    ('CLD-CLN-013','nrr_below_target','poor_onboarding','onboarding_redo','overdue',50000,'Vikram Shah (Onboarding)','2026-06-20',null,'NRR under target from weak onboarding; redo overdue on resourcing')
  ) as q(acode, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.nrr_retention_r3465 e
    on e.organization_id = v_org_id and e.account_code = q.acode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Retention-status distribution
create or replace function public.founder_r3465_retention_status_rollup()
returns table(retention_status text, accounts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nrr_retention_r3465)
  select l.retention_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nrr_retention_r3465 l
  group by l.retention_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3465_retention_status_rollup() from public, anon;
grant execute on function public.founder_r3465_retention_status_rollup() to authenticated;

-- 2) Customer-segment scorecard
create or replace function public.founder_r3465_segment_scorecard()
returns table(
  customer_segment text,
  accounts bigint,
  expanding bigint,
  stable bigint,
  contracting bigint,
  churning bigint,
  total_starting_arr_rupees numeric,
  total_ending_arr_rupees numeric,
  avg_nrr_pct numeric,
  avg_grr_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment,
    count(*)::bigint,
    count(*) filter (where l.retention_status = 'expanding')::bigint,
    count(*) filter (where l.retention_status = 'stable')::bigint,
    count(*) filter (where l.retention_status = 'contracting')::bigint,
    count(*) filter (where l.retention_status = 'churning')::bigint,
    coalesce(sum(l.starting_arr_rupees),0)::numeric,
    coalesce(sum(l.ending_arr_rupees),0)::numeric,
    round(avg(l.nrr_pct), 1),
    round(avg(l.grr_pct), 1)
  from public.nrr_retention_r3465 l
  group by l.customer_segment
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3465_segment_scorecard() from public, anon;
grant execute on function public.founder_r3465_segment_scorecard() to authenticated;

-- 3) Segment x retention-status matrix
create or replace function public.founder_r3465_segment_status_matrix()
returns table(customer_segment text, retention_status text, accounts bigint, total_ending_arr_rupees numeric, avg_nrr_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment, l.retention_status, count(*)::bigint,
    coalesce(sum(l.ending_arr_rupees),0)::numeric,
    round(avg(l.nrr_pct), 1)
  from public.nrr_retention_r3465 l
  group by l.customer_segment, l.retention_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3465_segment_status_matrix() from public, anon;
grant execute on function public.founder_r3465_segment_status_matrix() to authenticated;

-- 4) Monthly NRR / GRR trend
create or replace function public.founder_r3465_monthly_nrr_trend()
returns table(
  period_month date,
  accounts bigint,
  total_starting_arr_rupees numeric,
  total_expansion_rupees numeric,
  total_contraction_rupees numeric,
  total_churn_rupees numeric,
  total_ending_arr_rupees numeric,
  avg_nrr_pct numeric,
  avg_grr_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.starting_arr_rupees),0)::numeric,
    coalesce(sum(l.expansion_rupees),0)::numeric,
    coalesce(sum(l.contraction_rupees),0)::numeric,
    coalesce(sum(l.churn_rupees),0)::numeric,
    coalesce(sum(l.ending_arr_rupees),0)::numeric,
    round(avg(l.nrr_pct), 1),
    round(avg(l.grr_pct), 1)
  from public.nrr_retention_r3465 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3465_monthly_nrr_trend() from public, anon;
grant execute on function public.founder_r3465_monthly_nrr_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3465_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.nrr_retention_capa_actions_r3465 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3465_capa_status_board() from public, anon;
grant execute on function public.founder_r3465_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3465_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nrr_retention_capa_actions_r3465)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nrr_retention_capa_actions_r3465 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3465_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3465_root_cause_pareto() to authenticated;

-- 7) ARR-impact digest by retention status
create or replace function public.founder_r3465_arr_impact_digest()
returns table(
  retention_status text,
  accounts bigint,
  total_expansion_rupees numeric,
  total_contraction_rupees numeric,
  total_churn_rupees numeric,
  net_arr_change_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.retention_status,
    count(*)::bigint,
    coalesce(sum(l.expansion_rupees),0)::numeric,
    coalesce(sum(l.contraction_rupees),0)::numeric,
    coalesce(sum(l.churn_rupees),0)::numeric,
    coalesce(sum(l.expansion_rupees - l.contraction_rupees - l.churn_rupees),0)::numeric
  from public.nrr_retention_r3465 l
  group by l.retention_status
  order by coalesce(sum(l.expansion_rupees - l.contraction_rupees - l.churn_rupees),0) asc;
end;
$$;

revoke execute on function public.founder_r3465_arr_impact_digest() from public, anon;
grant execute on function public.founder_r3465_arr_impact_digest() to authenticated;

-- 8) High-risk retention queue (churning / contracting / worsening)
create or replace function public.founder_r3465_high_risk_queue()
returns table(
  customer_name text,
  account_code text,
  customer_segment text,
  cohort text,
  period_month date,
  retention_status text,
  nrr_pct numeric,
  grr_pct numeric,
  contraction_rupees numeric,
  churn_rupees numeric,
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
  select l.customer_name, l.account_code, l.customer_segment, l.cohort, l.period_month,
    l.retention_status, l.nrr_pct, l.grr_pct, l.contraction_rupees, l.churn_rupees, l.trend_dir, l.notes
  from public.nrr_retention_r3465 l
  where l.retention_status in ('contracting','churning')
     or l.trend_dir = 'worsening'
     or l.nrr_pct < 100
  order by l.nrr_pct asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3465_high_risk_queue() from public, anon;
grant execute on function public.founder_r3465_high_risk_queue() to authenticated;
