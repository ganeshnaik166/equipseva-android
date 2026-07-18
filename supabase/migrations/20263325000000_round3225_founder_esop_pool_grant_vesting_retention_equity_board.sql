-- Round 3225: Founder ESOP Pool, Grant Vesting & Retention Equity Board
-- ESOP grant log — grantee role × grant units × strike price × vest start × cliff × vested % × exercised × leaver status × pool remaining × retention-risk verdict × CAPA

-- =============================================================================
-- TABLE 1: esop_grants_r3225 — individual ESOP grant records
-- =============================================================================
create table if not exists public.esop_grants_r3225 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  grantee_name text not null,
  grantee_role text not null check (grantee_role in (
    'field_service_engineer','senior_engineer','regional_ops_manager','sales_lead',
    'product_manager','software_engineer','finance_controller','customer_success_lead',
    'founder_office','quality_head'
  )),
  grant_code text not null,
  grant_units int not null,
  strike_price_rupees numeric(10,2) not null,
  vest_start_date date not null,
  cliff_months int not null,
  vesting_schedule text not null check (vesting_schedule in (
    'four_year_monthly','four_year_quarterly','three_year_annual',
    'five_year_monthly','milestone_based','performance_gated'
  )),
  vested_pct numeric(5,2) not null,
  exercised_units int not null default 0,
  leaver_status text not null check (leaver_status in (
    'active','notice_period','good_leaver','bad_leaver','retired','deceased'
  )),
  pool_remaining_pct numeric(5,2),
  retention_risk_verdict text not null check (retention_risk_verdict in (
    'secure','stable','watch','flight_risk','critical_flight_risk','exited'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.esop_grants_r3225 enable row level security;

create index if not exists idx_esop_grants_r3225_org on public.esop_grants_r3225(organization_id);
create index if not exists idx_esop_grants_r3225_vest_start on public.esop_grants_r3225(vest_start_date);
create index if not exists idx_esop_grants_r3225_verdict on public.esop_grants_r3225(retention_risk_verdict);

-- =============================================================================
-- TABLE 2: esop_grants_capa_actions_r3225 — CAPA & follow-up actions
-- =============================================================================
create table if not exists public.esop_grants_capa_actions_r3225 (
  id uuid primary key default gen_random_uuid(),
  grant_id uuid not null references public.esop_grants_r3225(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'vesting_calc_error','cliff_breach_exercise','pool_over_allocation','missing_grant_letter',
    'board_approval_pending','strike_price_mismatch','leaver_clawback_due','tax_withholding_gap',
    'cap_table_discrepancy','retention_grant_needed'
  )),
  root_cause text not null check (root_cause in (
    'manual_spreadsheet_tracking','hr_system_sync_failure','policy_ambiguity',
    'legal_review_backlog','valuation_report_outdated','clerical_entry_error',
    'board_calendar_slip','pending_investigation','esop_scheme_amendment_lag'
  )),
  corrective_action text not null check (corrective_action in (
    'reissue_grant_letter','recompute_vesting_schedule','board_ratification',
    'clawback_unvested_units','top_up_retention_grant','migrate_to_cap_table_software',
    'update_esop_policy','withhold_tds_correction','legal_opinion_obtained','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'companies_act_filing','income_tax_tds','sebi_disclosure','none','internal_only','shareholder_agreement_breach'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.esop_grants_capa_actions_r3225 enable row level security;

create index if not exists idx_esop_capa_r3225_grant on public.esop_grants_capa_actions_r3225(grant_id);
create index if not exists idx_esop_capa_r3225_status on public.esop_grants_capa_actions_r3225(capa_status);

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

  -- 14 grant rows
  insert into public.esop_grants_r3225 (
    organization_id, entity_name, grantee_name, grantee_role, grant_code,
    grant_units, strike_price_rupees, vest_start_date, cliff_months, vesting_schedule,
    vested_pct, exercised_units, leaver_status, pool_remaining_pct, retention_risk_verdict, notes
  )
  select v_org_id, q.entity, q.gname, q.role, q.gcode,
    q.units, q.strike, q.vsd::date, q.cliff, q.sched,
    q.vpct, q.exu, q.lst, q.pool, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ravi Teja Kondapalli','field_service_engineer','ESOP-2024-001',
     12000,10.00,'2024-04-01',12,'four_year_monthly',56.25,0,'active',9.82,'secure','Anchor engineer on Apollo OT account'),
    ('Apollo Hyderabad Jubilee Hills','Meghana Rao','senior_engineer','ESOP-2024-007',
     18000,10.00,'2024-06-01',12,'four_year_monthly',52.08,4000,'active',9.55,'watch','Competing offer rumoured from OEM service arm'),
    ('Fortis Bannerghatta Bengaluru','Arjun Nair','regional_ops_manager','ESOP-2023-004',
     30000,6.50,'2023-10-01',12,'four_year_quarterly',68.75,10000,'active',9.10,'flight_risk','Exercised early; open-to-work signal on LinkedIn'),
    ('Fortis Bannerghatta Bengaluru','Divya Krishnan','customer_success_lead','ESOP-2025-011',
     9000,18.00,'2025-01-15',12,'four_year_monthly',37.50,0,'active',8.95,'stable','Owns Fortis renewal book'),
    ('Manipal Whitefield Bengaluru','Sandeep Kulkarni','software_engineer','ESOP-2024-015',
     15000,10.00,'2024-02-01',12,'four_year_monthly',60.42,0,'active',8.70,'secure','Built marketplace bidding engine'),
    ('Manipal Whitefield Bengaluru','Farhan Sheikh','sales_lead','ESOP-2023-002',
     22000,6.50,'2023-07-01',12,'three_year_annual',100.00,22000,'good_leaver',8.70,'exited','Fully vested; resigned on good terms Mar 2026'),
    ('AIIMS New Delhi Ansari Nagar','Priyanka Chauhan','product_manager','ESOP-2024-020',
     16000,10.00,'2024-09-01',12,'four_year_monthly',45.83,0,'active',8.40,'stable','Leads govt-hospital compliance roadmap'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Malhotra','finance_controller','ESOP-2025-003',
     12000,18.00,'2025-04-01',12,'four_year_quarterly',25.00,0,'notice_period',8.15,'critical_flight_risk','Serving notice; retention counter pending board nod'),
    ('KIMS Secunderabad','Anusha Reddy','field_service_engineer','ESOP-2025-008',
     8000,18.00,'2025-06-01',12,'four_year_monthly',27.08,0,'active',7.90,'watch','Cliff crossed; workload complaints logged'),
    ('Care Hospitals Banjara Hills','Rohit Deshmukh','senior_engineer','ESOP-2023-009',
     20000,6.50,'2023-12-01',12,'five_year_monthly',51.67,5000,'active',7.65,'secure','Ventilator vertical anchor'),
    ('Yashoda Somajiguda Hyderabad','Kavya Iyer','quality_head','ESOP-2024-012',
     14000,10.00,'2024-11-01',12,'milestone_based',40.00,0,'active',7.40,'stable','NABH milestone tranche 2 pending'),
    ('St John''s Bengaluru','Joseph Mathew','field_service_engineer','ESOP-2022-005',
     10000,4.00,'2022-08-01',12,'four_year_monthly',97.92,8000,'active',7.20,'secure','Longest-tenured engineer; near full vest'),
    ('Rainbow Children''s Hyderabad','Nandini Prasad','customer_success_lead','ESOP-2024-018',
     7000,10.00,'2024-05-01',18,'performance_gated',0.00,0,'bad_leaver',7.20,'exited','Terminated for cause pre-cliff; units lapsed to pool'),
    ('Yashoda Somajiguda Hyderabad','Suresh Babu Gandham','founder_office','ESOP-2023-001',
     40000,6.50,'2023-05-01',24,'four_year_quarterly',75.00,0,'active',6.85,'watch','Largest single grant; comp review due')
  ) as q(entity, gname, role, gcode, units, strike, vsd, cliff, sched, vpct, exu, lst, pool, verdict, nt);

  -- CAPA seed — attach to specific grants by grant_code
  insert into public.esop_grants_capa_actions_r3225 (
    grant_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('ESOP-2025-003','retention_grant_needed','board_calendar_slip','top_up_retention_grant',
     '2026-07-25',null,'escalated','internal_only',850000.00,'Counter-offer stuck; next board meet 28 Jul'),
    ('ESOP-2024-018','leaver_clawback_due','policy_ambiguity','clawback_unvested_units',
     '2026-07-20','2026-07-10','closed','shareholder_agreement_breach',0.00,'7000 units lapsed back to pool; SHA annexure updated'),
    ('ESOP-2023-002','tax_withholding_gap','clerical_entry_error','withhold_tds_correction',
     '2026-07-31',null,'in_progress','income_tax_tds',310000.00,'Perquisite TDS short-deducted on exercise FMV'),
    ('ESOP-2024-007','vesting_calc_error','manual_spreadsheet_tracking','recompute_vesting_schedule',
     '2026-07-22',null,'verification_pending','internal_only',15000.00,'Monthly tranche rounded up 3 months running'),
    ('ESOP-2023-001','board_approval_pending','legal_review_backlog','board_ratification',
     '2026-06-30',null,'overdue','companies_act_filing',45000.00,'Grant above 1 pct threshold needs MGT-14 filing'),
    ('ESOP-2022-005','missing_grant_letter','hr_system_sync_failure','reissue_grant_letter',
     '2026-08-05',null,'open','none',5000.00,'2022 grant letter lost in HRMS migration')
  ) as q(gcode, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.esop_grants_r3225 e
    on e.organization_id = v_org_id and e.grant_code = q.gcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Retention-risk verdict distribution
create or replace function public.founder_r3225_retention_verdict_rollup()
returns table(retention_risk_verdict text, grants bigint, total_units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.esop_grants_r3225)
  select g.retention_risk_verdict, count(*)::bigint,
         coalesce(sum(g.grant_units),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.esop_grants_r3225 g
  group by g.retention_risk_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3225_retention_verdict_rollup() from public, anon;
grant execute on function public.founder_r3225_retention_verdict_rollup() to authenticated;

-- 2) Entity / hospital-account scorecard
create or replace function public.founder_r3225_entity_scorecard()
returns table(
  entity_name text,
  total_grants bigint,
  active_grants bigint,
  flight_risk bigint,
  total_units bigint,
  exercised_units bigint,
  avg_vested_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.entity_name,
    count(*)::bigint,
    count(*) filter (where g.leaver_status = 'active')::bigint,
    count(*) filter (where g.retention_risk_verdict in ('flight_risk','critical_flight_risk'))::bigint,
    coalesce(sum(g.grant_units),0)::bigint,
    coalesce(sum(g.exercised_units),0)::bigint,
    round(avg(g.vested_pct), 2)
  from public.esop_grants_r3225 g
  group by g.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3225_entity_scorecard() from public, anon;
grant execute on function public.founder_r3225_entity_scorecard() to authenticated;

-- 3) Grantee role × vesting schedule matrix
create or replace function public.founder_r3225_role_schedule_matrix()
returns table(grantee_role text, vesting_schedule text, grants bigint, total_units bigint, avg_vested_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.grantee_role, g.vesting_schedule, count(*)::bigint,
    coalesce(sum(g.grant_units),0)::bigint,
    round(avg(g.vested_pct), 2)
  from public.esop_grants_r3225 g
  group by g.grantee_role, g.vesting_schedule
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3225_role_schedule_matrix() from public, anon;
grant execute on function public.founder_r3225_role_schedule_matrix() to authenticated;

-- 4) Vest-start date trend
create or replace function public.founder_r3225_vest_start_trend()
returns table(vest_start_date date, grants bigint, units_granted bigint, avg_cliff_months numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.vest_start_date, count(*)::bigint,
    coalesce(sum(g.grant_units),0)::bigint,
    round(avg(g.cliff_months), 1)
  from public.esop_grants_r3225 g
  group by g.vest_start_date
  order by g.vest_start_date desc;
end;
$$;

revoke execute on function public.founder_r3225_vest_start_trend() from public, anon;
grant execute on function public.founder_r3225_vest_start_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3225_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.esop_grants_capa_actions_r3225 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3225_capa_status_board() from public, anon;
grant execute on function public.founder_r3225_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3225_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.esop_grants_capa_actions_r3225)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.esop_grants_capa_actions_r3225 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3225_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3225_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3225_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.esop_grants_capa_actions_r3225 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3225_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3225_regulatory_impact_digest() to authenticated;

-- 8) High-risk grants queue (top retention concerns)
create or replace function public.founder_r3225_high_risk_grants()
returns table(
  entity_name text,
  grantee_name text,
  grantee_role text,
  grant_code text,
  grant_units int,
  vested_pct numeric,
  exercised_units int,
  leaver_status text,
  retention_risk_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.entity_name, g.grantee_name, g.grantee_role, g.grant_code,
    g.grant_units, g.vested_pct, g.exercised_units, g.leaver_status, g.retention_risk_verdict, g.notes
  from public.esop_grants_r3225 g
  where g.retention_risk_verdict in ('watch','flight_risk','critical_flight_risk')
     or g.leaver_status in ('notice_period','bad_leaver')
  order by case g.retention_risk_verdict
             when 'critical_flight_risk' then 0
             when 'flight_risk' then 1
             when 'watch' then 2
             else 3
           end,
           g.entity_name;
end;
$$;

revoke execute on function public.founder_r3225_high_risk_grants() from public, anon;
grant execute on function public.founder_r3225_high_risk_grants() to authenticated;
