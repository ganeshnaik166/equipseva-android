-- Round 3708: Founder Insurance-Broker Performance Scorecard Board
-- Broker service quality — broker × LOB × period × placement TAT × renewals on time × claims support × premium benchmark variance × endorsement TAT × service issues × CAPA

-- =============================================================================
-- TABLE 1: ins_broker_r3708 — per-broker / per-LOB monthly performance scorecard
-- =============================================================================
create table if not exists public.ins_broker_r3708 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  scorecard_code text not null,
  broker_name text not null,
  line_of_business text not null,
  period_month date not null,
  policies_placed int not null,
  placement_tat_days numeric(6,2) not null,
  renewals_on_time_pct numeric(5,2),
  claims_supported int not null default 0,
  claim_settlement_support_score numeric(4,1),
  premium_benchmark_variance_pct numeric(6,2),
  endorsements_tat_days numeric(6,2),
  service_issues int not null default 0,
  lob_class text not null check (lob_class in (
    'asset_property','liability','marine_transit','employee_health','cyber'
  )),
  performance_status text not null check (performance_status in (
    'excellent','on_target','slipping','poor','review_replacement'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ins_broker_r3708 enable row level security;

create index if not exists idx_ins_broker_r3708_org on public.ins_broker_r3708(organization_id);
create index if not exists idx_ins_broker_r3708_month on public.ins_broker_r3708(period_month);
create index if not exists idx_ins_broker_r3708_status on public.ins_broker_r3708(performance_status);

-- =============================================================================
-- TABLE 2: ins_broker_capa_actions_r3708 — CAPA & broker-improvement actions
-- =============================================================================
create table if not exists public.ins_broker_capa_actions_r3708 (
  id uuid primary key default gen_random_uuid(),
  scorecard_id uuid not null references public.ins_broker_r3708(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'placement_delay','renewal_lapse_risk','claims_support_gap','premium_overpricing',
    'endorsement_backlog','service_responsiveness','mis_reporting_gap','compliance_documentation'
  )),
  root_cause text not null check (root_cause in (
    'insurer_quote_delay','broker_staff_attrition','incomplete_risk_data','weak_insurer_panel',
    'manual_endorsement_process','single_point_dependency','benchmarking_not_done',
    'pending_investigation','sla_not_defined'
  )),
  corrective_action text not null check (corrective_action in (
    'define_placement_sla','add_backup_broker','rebroke_to_market','dedicated_claims_spoc',
    'digitize_endorsement_tracker','quarterly_benchmarking_review','escalate_to_broker_principal',
    'switch_broker','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  premium_impact_rupees numeric(12,2),
  action_owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ins_broker_capa_actions_r3708 enable row level security;

create index if not exists idx_ins_broker_capa_r3708_log on public.ins_broker_capa_actions_r3708(scorecard_id);
create index if not exists idx_ins_broker_capa_r3708_status on public.ins_broker_capa_actions_r3708(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Performance status distribution
create or replace function public.founder_r3708_performance_status_rollup()
returns table(performance_status text, scorecards bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ins_broker_r3708)
  select l.performance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ins_broker_r3708 l
  group by l.performance_status
  order by count(*) desc;
end;
$$;

-- 2) Broker-level performance scorecard
create or replace function public.founder_r3708_broker_scorecard()
returns table(
  broker_name text,
  scorecards bigint,
  policies_placed bigint,
  avg_placement_tat_days numeric,
  avg_renewals_on_time_pct numeric,
  avg_claim_support_score numeric,
  avg_benchmark_variance_pct numeric,
  service_issues bigint,
  healthy_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.broker_name,
    count(*)::bigint,
    coalesce(sum(l.policies_placed),0)::bigint,
    round(avg(l.placement_tat_days), 2),
    round(avg(l.renewals_on_time_pct), 1),
    round(avg(l.claim_settlement_support_score), 2),
    round(avg(l.premium_benchmark_variance_pct), 2),
    coalesce(sum(l.service_issues),0)::bigint,
    round(100.0 * count(*) filter (where l.performance_status in ('excellent','on_target'))::numeric / nullif(count(*),0), 1)
  from public.ins_broker_r3708 l
  group by l.broker_name
  order by count(*) desc;
end;
$$;

-- 3) LOB class × performance status matrix
create or replace function public.founder_r3708_lob_status_matrix()
returns table(lob_class text, performance_status text, scorecards bigint, policies_placed bigint, avg_placement_tat_days numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lob_class, l.performance_status, count(*)::bigint,
    coalesce(sum(l.policies_placed),0)::bigint,
    round(avg(l.placement_tat_days), 2)
  from public.ins_broker_r3708 l
  group by l.lob_class, l.performance_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly TAT trend
create or replace function public.founder_r3708_monthly_tat_trend()
returns table(period_month date, scorecards bigint, policies_placed bigint, avg_placement_tat_days numeric, avg_endorsements_tat_days numeric, service_issues bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.policies_placed),0)::bigint,
    round(avg(l.placement_tat_days), 2),
    round(avg(l.endorsements_tat_days), 2),
    coalesce(sum(l.service_issues),0)::bigint
  from public.ins_broker_r3708 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3708_capa_status_board()
returns table(capa_status text, findings bigint, avg_premium_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.premium_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.ins_broker_capa_actions_r3708 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3708_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_premium_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ins_broker_capa_actions_r3708)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.premium_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ins_broker_capa_actions_r3708 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Premium benchmark-variance digest per LOB class
create or replace function public.founder_r3708_benchmark_variance_digest()
returns table(lob_class text, scorecards bigint, avg_benchmark_variance_pct numeric, worst_benchmark_variance_pct numeric, avg_renewals_on_time_pct numeric, service_issues bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lob_class,
    count(*)::bigint,
    round(avg(l.premium_benchmark_variance_pct), 2),
    max(l.premium_benchmark_variance_pct)::numeric,
    round(avg(l.renewals_on_time_pct), 1),
    coalesce(sum(l.service_issues),0)::bigint
  from public.ins_broker_r3708 l
  group by l.lob_class
  order by round(avg(l.premium_benchmark_variance_pct), 2) desc nulls last;
end;
$$;

-- 8) High-risk broker queue (poor / review_replacement / worsening / overpriced)
create or replace function public.founder_r3708_high_risk_queue()
returns table(
  broker_name text,
  scorecard_code text,
  line_of_business text,
  period_month date,
  lob_class text,
  performance_status text,
  trend_dir text,
  placement_tat_days numeric,
  premium_benchmark_variance_pct numeric,
  service_issues int,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.broker_name, l.scorecard_code, l.line_of_business, l.period_month,
    l.lob_class, l.performance_status, l.trend_dir,
    l.placement_tat_days, l.premium_benchmark_variance_pct, l.service_issues, l.notes
  from public.ins_broker_r3708 l
  where l.performance_status in ('poor','review_replacement')
     or l.trend_dir = 'worsening'
     or l.service_issues > 2
     or l.premium_benchmark_variance_pct > 8
     or l.renewals_on_time_pct < 80
  order by l.period_month desc, l.broker_name;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated-only surface
-- =============================================================================
revoke all on function public.founder_r3708_performance_status_rollup() from public, anon;
revoke all on function public.founder_r3708_broker_scorecard() from public, anon;
revoke all on function public.founder_r3708_lob_status_matrix() from public, anon;
revoke all on function public.founder_r3708_monthly_tat_trend() from public, anon;
revoke all on function public.founder_r3708_capa_status_board() from public, anon;
revoke all on function public.founder_r3708_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3708_benchmark_variance_digest() from public, anon;
revoke all on function public.founder_r3708_high_risk_queue() from public, anon;

grant execute on function public.founder_r3708_performance_status_rollup() to authenticated;
grant execute on function public.founder_r3708_broker_scorecard() to authenticated;
grant execute on function public.founder_r3708_lob_status_matrix() to authenticated;
grant execute on function public.founder_r3708_monthly_tat_trend() to authenticated;
grant execute on function public.founder_r3708_capa_status_board() to authenticated;
grant execute on function public.founder_r3708_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3708_benchmark_variance_digest() to authenticated;
grant execute on function public.founder_r3708_high_risk_queue() to authenticated;

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

  -- 16 scorecard rows
  insert into public.ins_broker_r3708 (
    organization_id, scorecard_code, broker_name, line_of_business, period_month,
    policies_placed, placement_tat_days, renewals_on_time_pct,
    claims_supported, claim_settlement_support_score,
    premium_benchmark_variance_pct, endorsements_tat_days, service_issues,
    lob_class, performance_status, trend_dir, notes
  )
  select v_org_id, q.scode, q.bname, q.lob, q.pmon::date,
    q.pol, q.ptat, q.ren,
    q.clm, q.css,
    q.pbv, q.etat, q.sisu,
    q.lclass, q.pstat, q.tdir, q.nt
  from (values
    ('INS-MRSH-EH-05','Marsh India','Group Health & GPA','2026-05-01',
     6,12.5,92.0,14,4.2,-3.5,2.1,1,'employee_health','on_target','stable','GMC renewal placed ahead of expiry; premium 3.5 pct under benchmark'),
    ('INS-MRSH-EH-06','Marsh India','Group Health & GPA','2026-06-01',
     4,10.8,95.5,18,4.5,-4.2,1.8,0,'employee_health','excellent','improving','Dedicated claims SPOC cut settlement follow-ups sharply'),
    ('INS-MRSH-EH-07','Marsh India','Group Health & GPA','2026-07-01',
     5,10.2,96.0,16,4.6,-4.8,1.6,0,'employee_health','excellent','stable','Best-in-panel claims support; endorsements under 2 days'),
    ('INS-PRUD-PROP-05','Prudent Insurance Brokers','Fire & Property All-Risk','2026-05-01',
     3,18.4,88.0,2,3.8,2.1,3.4,1,'asset_property','on_target','stable','Factory all-risk placed within window; minor endorsement lag'),
    ('INS-PRUD-PROP-06','Prudent Insurance Brokers','Fire & Property All-Risk','2026-06-01',
     2,24.6,81.5,3,3.4,6.8,4.9,2,'asset_property','slipping','worsening','Quote turnaround slowed; premium crept above benchmark'),
    ('INS-PRUD-PROP-07','Prudent Insurance Brokers','Fire & Property All-Risk','2026-07-01',
     2,29.3,74.0,1,3.1,9.4,6.2,3,'asset_property','poor','worsening','Placement 29 days vs 15-day SLA; renewal slipped into grace period'),
    ('INS-AON-CYB-05','Aon India','Cyber Liability','2026-05-01',
     1,21.0,100.0,0,4.0,-1.2,2.5,0,'cyber','on_target','stable','Cyber tower renewed with improved ransomware sub-limits'),
    ('INS-AON-CYB-06','Aon India','Cyber Liability','2026-06-01',
     1,19.5,100.0,1,4.3,-2.6,2.2,0,'cyber','excellent','improving','Benchmarked against 4 insurers; premium 2.6 pct under market'),
    ('INS-HOWD-LIA-05','Howden Insurance Brokers India','Product & Public Liability','2026-05-01',
     2,16.2,90.0,1,3.9,1.4,2.8,1,'liability','on_target','stable','Product liability placed clean; one E&O query pending'),
    ('INS-HOWD-LIA-06','Howden Insurance Brokers India','Product & Public Liability','2026-06-01',
     2,17.8,84.5,2,3.2,4.9,5.6,2,'liability','slipping','worsening','Endorsement backlog building on distributor additions'),
    ('INS-HOWD-LIA-07','Howden Insurance Brokers India','Product & Public Liability','2026-07-01',
     1,22.4,78.0,2,2.8,7.3,7.1,4,'liability','poor','worsening','Four unresolved service tickets; claims desk unresponsive'),
    ('INS-GLOB-MAR-05','Global Insurance Brokers','Marine Cargo Open Policy','2026-05-01',
     4,8.6,93.5,5,4.1,-2.0,1.9,0,'marine_transit','excellent','stable','Open-policy declarations processed same week'),
    ('INS-GLOB-MAR-06','Global Insurance Brokers','Marine Cargo Open Policy','2026-06-01',
     3,9.4,91.0,6,3.9,-1.1,2.3,1,'marine_transit','on_target','stable','Transit claim on ICU monitor shipment settled in 18 days'),
    ('INS-GLOB-MAR-07','Global Insurance Brokers','Marine Cargo Open Policy','2026-07-01',
     4,9.1,92.5,4,4.0,-1.8,2.0,0,'marine_transit','on_target','improving','Marine lane steady; benchmarking refreshed this quarter'),
    ('INS-ANRT-EH-06','Anand Rathi Insurance Brokers','Group Term Life & GPA','2026-06-01',
     2,14.9,86.0,3,3.0,3.2,4.4,2,'employee_health','slipping','worsening','GPA endorsements delayed for new Coimbatore plant hires'),
    ('INS-ANRT-EH-07','Anand Rathi Insurance Brokers','Group Term Life & GPA','2026-07-01',
     1,26.7,70.0,2,2.4,11.6,8.3,5,'employee_health','review_replacement','worsening','Premium 11.6 pct over benchmark; rebroke and broker replacement initiated')
  ) as q(scode, bname, lob, pmon, pol, ptat, ren, clm, css, pbv, etat, sisu, lclass, pstat, tdir, nt);

  -- 8 CAPA rows — attach to specific scorecards via scorecard_code
  insert into public.ins_broker_capa_actions_r3708 (
    scorecard_id, finding_category, root_cause, corrective_action,
    capa_status, premium_impact_rupees, action_owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr,
    q.tgt::date, q.act::date, q.nt
  from (values
    ('INS-PRUD-PROP-06','placement_delay','insurer_quote_delay','define_placement_sla','in_progress',185000.00,'CFO Office — Meera Iyer','2026-07-20',null,'15-day placement SLA drafted; insurer panel widened to 5 markets'),
    ('INS-PRUD-PROP-07','renewal_lapse_risk','weak_insurer_panel','rebroke_to_market','escalated',420000.00,'CFO Office — Meera Iyer','2026-08-05',null,'Factory all-risk rebroked to 3 alternate insurers; grace-period cover confirmed'),
    ('INS-HOWD-LIA-06','endorsement_backlog','manual_endorsement_process','digitize_endorsement_tracker','verification_pending',36000.00,'Admin Ops — Suresh Patil','2026-07-25',null,'Endorsement tracker live on Zoho; verifying TAT over next 10 endorsements'),
    ('INS-HOWD-LIA-07','service_responsiveness','broker_staff_attrition','escalate_to_broker_principal','open',0.00,'Admin Ops — Suresh Patil','2026-08-12',null,'Principal-officer review meeting scheduled; open service tickets tabled'),
    ('INS-ANRT-EH-07','premium_overpricing','benchmarking_not_done','switch_broker','open',310000.00,'CFO Office — Meera Iyer','2026-08-20',null,'GTL and GPA moving to Marsh from September renewal; savings quantified'),
    ('INS-ANRT-EH-06','claims_support_gap','single_point_dependency','dedicated_claims_spoc','in_progress',54000.00,'HR Ops — Lakshmi Venkat','2026-07-30',null,'Broker assigning named claims SPOC for the employee-health desk'),
    ('INS-PRUD-PROP-05','compliance_documentation','sla_not_defined','quarterly_benchmarking_review','closed',0.00,'CFO Office — Meera Iyer','2026-06-30','2026-06-27','Benchmarking calendar agreed; Q2 review completed on time'),
    ('INS-GLOB-MAR-06','mis_reporting_gap','incomplete_risk_data','none_required','closed',12000.00,'Logistics Mgr — Kavitha R','2026-07-05','2026-07-02','Declaration MIS gap traced to our shipment data feed — fixed internally')
  ) as q(scode, fc, rc, ca, cst, impact, ownr, tgt, act, nt)
  join public.ins_broker_r3708 e
    on e.organization_id = v_org_id and e.scorecard_code = q.scode;
end;
$seed$;
