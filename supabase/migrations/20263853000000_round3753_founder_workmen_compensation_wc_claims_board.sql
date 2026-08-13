-- Round 3753: Founder Workmen-Compensation (WC) Claims Board
-- Workmen-compensation / Employee's Compensation Act claims for on-duty injuries
-- (field engineers/site staff) — claims filed, insurer settlement, TAT, disability
-- classification. Distinct from safety-incident/near-miss/PPE logging — this is the
-- insurance-claim/compensation process.

-- =============================================================================
-- TABLE 1: wc_claims_r3753 — per-claim WC insurance/compensation facts
-- =============================================================================
create table if not exists public.wc_claims_r3753 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_name text not null,
  incident_location text not null,
  period_month date not null,
  incident_date date,
  claim_filed_date date,
  claim_amount_rupees numeric(12,2),
  settlement_amount_rupees numeric(12,2),
  settlement_date date,
  days_to_settlement int,
  disability_pct numeric,
  insurer_name text,
  litigation_involved boolean not null,
  injury_class text not null check (injury_class in (
    'temporary_disability','permanent_partial_disability','permanent_total_disability',
    'fatal','minor_no_disability'
  )),
  claim_status text not null check (claim_status in (
    'settled_on_time','settled_delayed','under_assessment','disputed','litigation_pending'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.wc_claims_r3753 enable row level security;

create index if not exists idx_wc_claims_r3753_org on public.wc_claims_r3753(organization_id);
create index if not exists idx_wc_claims_r3753_month on public.wc_claims_r3753(period_month);
create index if not exists idx_wc_claims_r3753_status on public.wc_claims_r3753(claim_status);

-- =============================================================================
-- TABLE 2: wc_claims_capa_actions_r3753 — CAPA for claim-handling/process gaps
-- =============================================================================
create table if not exists public.wc_claims_capa_actions_r3753 (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid references public.wc_claims_r3753(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.wc_claims_capa_actions_r3753 enable row level security;

create index if not exists idx_wc_claims_capa_r3753_claim on public.wc_claims_capa_actions_r3753(claim_id);
create index if not exists idx_wc_claims_capa_r3753_status on public.wc_claims_capa_actions_r3753(capa_status);

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

  -- 16 WC claim rows
  insert into public.wc_claims_r3753 (
    organization_id, employee_name, incident_location, period_month,
    incident_date, claim_filed_date, claim_amount_rupees, settlement_amount_rupees,
    settlement_date, days_to_settlement, disability_pct, insurer_name,
    litigation_involved, injury_class, claim_status, trend_dir, notes
  )
  select v_org_id, q.emp, q.loc, q.pm::date,
    q.idate::date, q.fdate::date, q.camt::numeric, q.samt::numeric,
    q.sdate::date, q.dts::int, q.dpct::numeric, q.ins,
    q.lit, q.icls, q.cst, q.trd, q.nt
  from (values
    ('Ramesh Yadav','Pune Site Yard','2026-07-01',
     '2026-07-03','2026-07-05',185000,175000,'2026-07-28',23,8,'National Insurance Co.',
     false,'temporary_disability','settled_on_time','stable','Crane rigging hand injury — TAT within 30-day SLA'),
    ('Suresh Pawar','Nagpur Highway Depot','2026-07-01',
     '2026-07-10',null,420000,null,null,null,35,'New India Assurance',
     false,'permanent_partial_disability','under_assessment','stable','Loader fall — medical board review pending for disability %'),
    ('Anil Kadam','Mumbai Port Yard','2026-06-01',
     '2026-06-02','2026-06-04',95000,95000,'2026-06-20',16,0,'ICICI Lombard',
     false,'minor_no_disability','settled_on_time','improving','Minor hand laceration on excavator maintenance — quick closure'),
    ('Dattatray More','Nashik Field Site','2026-06-01',
     '2026-06-15','2026-06-25',650000,null,null,null,45,'National Insurance Co.',
     true,'permanent_partial_disability','litigation_pending','worsening','Family disputing disability assessment — legal notice received'),
    ('Vikas Shinde','Aurangabad Depot','2026-06-01',
     '2026-06-05','2026-06-08',310000,260000,'2026-08-02',58,15,'Bajaj Allianz',
     false,'temporary_disability','settled_delayed','worsening','Insurer document re-submission delayed settlement past 45-day target'),
    ('Ganesh Wagh','Pune Site Yard','2026-05-01',
     '2026-05-08','2026-05-10',75000,72000,'2026-05-30',20,0,'ICICI Lombard',
     false,'minor_no_disability','settled_on_time','stable','Forklift toe injury — steel-cap boot policy reinforced'),
    ('Prakash Bhosale','Nagpur Highway Depot','2026-05-01',
     '2026-05-20','2026-05-24',1250000,null,null,null,100,'New India Assurance',
     true,'fatal','litigation_pending','worsening','Fatal electrocution at site transformer — compensation dispute with next of kin'),
    ('Santosh Jadhav','Mumbai Port Yard','2026-05-01',
     '2026-05-12','2026-05-14',220000,210000,'2026-06-28',45,10,'National Insurance Co.',
     false,'temporary_disability','settled_delayed','stable','Backhoe hydraulic hose burst — settled just past 30-day target'),
    ('Mahesh Deshmukh','Nashik Field Site','2026-07-01',
     '2026-07-14','2026-07-16',540000,null,null,null,60,'Bajaj Allianz',
     true,'permanent_partial_disability','disputed','worsening','Insurer contests pre-existing condition claim — third medical opinion sought'),
    ('Rahul Salunkhe','Aurangabad Depot','2026-07-01',
     '2026-07-20','2026-07-22',60000,58000,'2026-08-05',14,0,'ICICI Lombard',
     false,'minor_no_disability','settled_on_time','improving','Grease-slip minor sprain — fastest closure this quarter'),
    ('Yogesh Kale','Pune Site Yard','2026-04-01',
     '2026-04-04','2026-04-06',980000,910000,'2026-06-10',65,55,'New India Assurance',
     false,'permanent_partial_disability','settled_delayed','stable','Crane boom collapse — settlement delayed by medical board rescheduling'),
    ('Nitin Gaikwad','Nagpur Highway Depot','2026-04-01',
     '2026-04-18','2026-04-20',110000,105000,'2026-05-15',25,5,'National Insurance Co.',
     false,'temporary_disability','settled_on_time','improving','Site-yard scaffolding fall — recovered within TAT'),
    ('Sachin Chavan','Mumbai Port Yard','2026-04-01',
     '2026-04-25',null,380000,null,null,null,30,'Bajaj Allianz',
     false,'permanent_partial_disability','under_assessment','stable','Container-crane crush injury — awaiting disability certification'),
    ('Kiran Patil','Nashik Field Site','2026-06-01',
     '2026-06-28','2026-07-01',1500000,null,null,null,100,'New India Assurance',
     true,'fatal','disputed','worsening','Fatal fall from height — insurer disputes site safety-compliance clause'),
    ('Umesh Kulkarni','Aurangabad Depot','2026-05-01',
     '2026-05-02','2026-05-04',48000,46000,'2026-05-22',18,0,'ICICI Lombard',
     false,'minor_no_disability','settled_on_time','stable','Wrist strain during equipment tie-down — no lost workdays'),
    ('Vaibhav Thorat','Pune Site Yard','2026-07-01',
     '2026-07-08','2026-07-11',260000,null,null,null,20,'National Insurance Co.',
     false,'temporary_disability','under_assessment','stable','Excavator bucket pinch injury — insurer survey scheduled next week')
  ) as q(emp, loc, pm, idate, fdate, camt, samt, sdate, dts, dpct, ins, lit, icls, cst, trd, nt);

  -- CAPA seed — attach to specific claims via employee_name + incident_location
  insert into public.wc_claims_capa_actions_r3753 (
    claim_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Suresh Pawar','Nagpur Highway Depot','Medical board scheduling backlog delaying disability assessment','Escalate case to insurer TPA for expedited medical board slot','in_progress','Insurance Cell Coordinator','2026-08-20',null,'Third follow-up call placed with TPA this week'),
    ('Dattatray More','Nashik Field Site','Family disputes disability percentage awarded by first medical board','Arrange independent second medical opinion and legal mediation','open','HR-Legal Liaison','2026-09-10',null,'Advocate engaged — mediation date awaited from labour court'),
    ('Vikas Shinde','Aurangabad Depot','Insurer requested re-submission of wage-slip documentation late','Standardise pre-filing document checklist to avoid repeat delays','closed','Insurance Cell Coordinator','2026-08-05','2026-08-01','Checklist rolled out to all site HR points-of-contact'),
    ('Prakash Bhosale','Nagpur Highway Depot','Fatal electrocution linked to inadequate transformer lockout-tagout','File compensation per Act minimums and audit LOTO procedure sitewide','in_progress','EHS Head','2026-09-01',null,'LOTO audit at 3 of 5 depots complete; compensation filing in progress'),
    ('Santosh Jadhav','Mumbai Port Yard','Hydraulic maintenance interval exceeded on ageing backhoe fleet','Tighten preventive-maintenance schedule for hydraulic assemblies','closed','Fleet Maintenance Lead','2026-07-15','2026-07-12','PM interval reduced from 500hr to 350hr fleet-wide'),
    ('Mahesh Deshmukh','Nashik Field Site','Insurer disputing pre-existing condition without documented pre-employment medical','Introduce mandatory pre-employment medical baseline for field hires','open','HR-Legal Liaison','2026-08-30',null,'Baseline medical policy drafted, awaiting sign-off'),
    ('Yogesh Kale','Pune Site Yard','Crane boom inspection interval lapsed before failure','Enforce monthly third-party crane inspection with sign-off log','closed','EHS Head','2026-06-30','2026-06-25','Inspection log now audited monthly by EHS'),
    ('Kiran Patil','Nashik Field Site','Fall-arrest harness not in use at height per site audit findings','Mandate harness compliance checks with site supervisor daily sign-off','overdue','EHS Head','2026-07-20',null,'Rollout delayed pending harness stock replenishment at 2 sites')
  ) as q(emp, loc, rc, ca, cst, ownr, tcd, acd, nt)
  join public.wc_claims_r3753 e
    on e.organization_id = v_org_id and e.employee_name = q.emp and e.incident_location = q.loc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Claim-status distribution
create or replace function public.founder_r3753_claim_status_rollup()
returns table(claim_status text, claims bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.wc_claims_r3753)
  select l.claim_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.wc_claims_r3753 l
  group by l.claim_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3753_claim_status_rollup() from public, anon;
grant execute on function public.founder_r3753_claim_status_rollup() to authenticated;

-- 2) Incident-location scorecard
create or replace function public.founder_r3753_incident_location_scorecard()
returns table(
  incident_location text,
  total_claims bigint,
  settled_on_time bigint,
  settled_delayed bigint,
  litigation_pending bigint,
  fatal_claims bigint,
  total_claim_amount_rupees numeric,
  total_settlement_amount_rupees numeric,
  avg_days_to_settlement numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.incident_location,
    count(*)::bigint,
    count(*) filter (where l.claim_status = 'settled_on_time')::bigint,
    count(*) filter (where l.claim_status = 'settled_delayed')::bigint,
    count(*) filter (where l.claim_status = 'litigation_pending')::bigint,
    count(*) filter (where l.injury_class = 'fatal')::bigint,
    coalesce(sum(l.claim_amount_rupees),0)::numeric,
    coalesce(sum(l.settlement_amount_rupees),0)::numeric,
    round(avg(l.days_to_settlement), 1)
  from public.wc_claims_r3753 l
  group by l.incident_location
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3753_incident_location_scorecard() from public, anon;
grant execute on function public.founder_r3753_incident_location_scorecard() to authenticated;

-- 3) Injury-class x claim-status matrix
create or replace function public.founder_r3753_injury_class_status_matrix()
returns table(injury_class text, claim_status text, claims bigint, avg_disability_pct numeric, total_settlement_amount_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.injury_class, l.claim_status, count(*)::bigint,
    round(avg(l.disability_pct), 1),
    coalesce(sum(l.settlement_amount_rupees),0)::numeric
  from public.wc_claims_r3753 l
  group by l.injury_class, l.claim_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3753_injury_class_status_matrix() from public, anon;
grant execute on function public.founder_r3753_injury_class_status_matrix() to authenticated;

-- 4) Monthly settlement trend
create or replace function public.founder_r3753_monthly_settlement_trend()
returns table(period_month date, claims bigint, total_claim_amount_rupees numeric, total_settlement_amount_rupees numeric, avg_days_to_settlement numeric, litigation_claims bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.claim_amount_rupees),0)::numeric,
    coalesce(sum(l.settlement_amount_rupees),0)::numeric,
    round(avg(l.days_to_settlement), 1),
    count(*) filter (where l.litigation_involved = true)::bigint
  from public.wc_claims_r3753 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3753_monthly_settlement_trend() from public, anon;
grant execute on function public.founder_r3753_monthly_settlement_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3753_capa_status_board()
returns table(capa_status text, actions bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.wc_claims_capa_actions_r3753 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3753_capa_status_board() from public, anon;
grant execute on function public.founder_r3753_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3753_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.wc_claims_capa_actions_r3753)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.wc_claims_capa_actions_r3753 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3753_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3753_root_cause_pareto() to authenticated;

-- 7) Settlement-delay digest
create or replace function public.founder_r3753_delay_digest()
returns table(
  incident_location text,
  delayed_or_pending_claims bigint,
  avg_days_to_settlement numeric,
  max_days_to_settlement numeric,
  litigation_claims bigint,
  disputed_claims bigint,
  amount_at_risk_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.incident_location,
    count(*) filter (where l.claim_status in ('settled_delayed','under_assessment','disputed','litigation_pending'))::bigint,
    round(avg(l.days_to_settlement), 1),
    max(l.days_to_settlement)::numeric,
    count(*) filter (where l.claim_status = 'litigation_pending')::bigint,
    count(*) filter (where l.claim_status = 'disputed')::bigint,
    coalesce(sum(l.claim_amount_rupees) filter (where l.settlement_date is null),0)::numeric
  from public.wc_claims_r3753 l
  group by l.incident_location
  order by count(*) filter (where l.claim_status in ('settled_delayed','under_assessment','disputed','litigation_pending')) desc;
end;
$$;

revoke all on function public.founder_r3753_delay_digest() from public, anon;
grant execute on function public.founder_r3753_delay_digest() to authenticated;

-- 8) High-risk claims queue (disputed / litigation / fatal / severe disability)
create or replace function public.founder_r3753_high_risk_queue()
returns table(
  employee_name text,
  incident_location text,
  period_month date,
  injury_class text,
  claim_status text,
  claim_amount_rupees numeric,
  disability_pct numeric,
  litigation_involved boolean,
  insurer_name text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_name, l.incident_location, l.period_month,
    l.injury_class, l.claim_status, l.claim_amount_rupees,
    l.disability_pct, l.litigation_involved, l.insurer_name, l.notes
  from public.wc_claims_r3753 l
  where l.claim_status in ('disputed','litigation_pending')
     or l.injury_class in ('fatal','permanent_total_disability')
     or l.litigation_involved = true
     or coalesce(l.disability_pct,0) >= 50
  order by
    (l.injury_class = 'fatal') desc,
    (l.claim_status = 'litigation_pending') desc,
    l.claim_amount_rupees desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3753_high_risk_queue() from public, anon;
grant execute on function public.founder_r3753_high_risk_queue() to authenticated;
