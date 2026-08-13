-- Round 3740: Founder Directors & Officers (D&O) Insurance Coverage Adequacy Board
-- D&O coverage adequacy — entity/subsidiary x policy year x period month x coverage limit vs peer benchmark x claims history x exclusions x CAPA
-- Distinct from insurance-broker-performance-scorecard (broker SERVICE quality) — this is D&O coverage adequacy itself.

-- =============================================================================
-- TABLE 1: do_insurance_r3740 — per-entity D&O policy coverage-adequacy facts
-- =============================================================================
create table if not exists public.do_insurance_r3740 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  policy_year text not null,
  period_month date not null,
  coverage_limit_rupees numeric(14,2),
  premium_rupees numeric(12,2),
  deductible_rupees numeric(12,2),
  claims_filed int,
  claims_paid_rupees numeric(12,2),
  peer_benchmark_limit_rupees numeric(14,2),
  coverage_gap_pct numeric,
  key_exclusions_flagged int,
  renewal_due_date date,
  entity_class text not null check (entity_class in (
    'parent_company','subsidiary','joint_venture','holding_entity','esop_trust'
  )),
  adequacy_status text not null check (adequacy_status in (
    'adequate','marginal','underinsured','claim_impacted','renewal_pending'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.do_insurance_r3740 enable row level security;

create index if not exists idx_do_insurance_r3740_org on public.do_insurance_r3740(organization_id);
create index if not exists idx_do_insurance_r3740_month on public.do_insurance_r3740(period_month);
create index if not exists idx_do_insurance_r3740_status on public.do_insurance_r3740(adequacy_status);

-- =============================================================================
-- TABLE 2: do_insurance_capa_actions_r3740 — CAPA & coverage-remediation actions
-- =============================================================================
create table if not exists public.do_insurance_capa_actions_r3740 (
  id uuid primary key default gen_random_uuid(),
  do_insurance_id uuid references public.do_insurance_r3740(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in (
    'open','in_progress','closed','overdue'
  )),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.do_insurance_capa_actions_r3740 enable row level security;

create index if not exists idx_do_insurance_capa_r3740_main on public.do_insurance_capa_actions_r3740(do_insurance_id);
create index if not exists idx_do_insurance_capa_r3740_status on public.do_insurance_capa_actions_r3740(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Adequacy status distribution
create or replace function public.founder_r3740_adequacy_status_rollup()
returns table(adequacy_status text, entities bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.do_insurance_r3740)
  select l.adequacy_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.do_insurance_r3740 l
  group by l.adequacy_status
  order by count(*) desc;
end;
$$;

-- 2) Entity-level coverage scorecard
create or replace function public.founder_r3740_entity_scorecard()
returns table(
  entity_name text,
  policies bigint,
  avg_coverage_limit_rupees numeric,
  avg_peer_benchmark_limit_rupees numeric,
  avg_coverage_gap_pct numeric,
  total_claims_filed bigint,
  total_claims_paid_rupees numeric,
  underinsured_count bigint,
  avg_key_exclusions_flagged numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    round(avg(l.coverage_limit_rupees), 2),
    round(avg(l.peer_benchmark_limit_rupees), 2),
    round(avg(l.coverage_gap_pct), 1),
    coalesce(sum(l.claims_filed), 0)::bigint,
    coalesce(sum(l.claims_paid_rupees), 0)::numeric,
    count(*) filter (where l.adequacy_status = 'underinsured')::bigint,
    round(avg(l.key_exclusions_flagged), 1)
  from public.do_insurance_r3740 l
  group by l.entity_name
  order by round(avg(l.coverage_gap_pct), 1) asc nulls last;
end;
$$;

-- 3) Entity-class x adequacy-status matrix
create or replace function public.founder_r3740_entity_class_status_matrix()
returns table(entity_class text, adequacy_status text, entities bigint, avg_coverage_gap_pct numeric, total_claims_paid_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_class, l.adequacy_status, count(*)::bigint,
    round(avg(l.coverage_gap_pct), 1),
    coalesce(sum(l.claims_paid_rupees), 0)::numeric
  from public.do_insurance_r3740 l
  group by l.entity_class, l.adequacy_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly coverage-gap trend
create or replace function public.founder_r3740_monthly_coverage_gap_trend()
returns table(period_month date, entities bigint, avg_coverage_gap_pct numeric, total_premium_rupees numeric, total_claims_paid_rupees numeric, underinsured_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.coverage_gap_pct), 1),
    coalesce(sum(l.premium_rupees), 0)::numeric,
    coalesce(sum(l.claims_paid_rupees), 0)::numeric,
    count(*) filter (where l.adequacy_status = 'underinsured')::bigint
  from public.do_insurance_r3740 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3740_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.do_insurance_capa_actions_r3740 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3740_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.do_insurance_capa_actions_r3740)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot), 0) * 100.0, 1)
  from public.do_insurance_capa_actions_r3740 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Exclusion digest by entity class
create or replace function public.founder_r3740_exclusion_digest()
returns table(entity_class text, entities bigint, total_key_exclusions_flagged bigint, avg_key_exclusions_flagged numeric, high_exclusion_entities bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_class,
    count(*)::bigint,
    coalesce(sum(l.key_exclusions_flagged), 0)::bigint,
    round(avg(l.key_exclusions_flagged), 1),
    count(*) filter (where l.key_exclusions_flagged >= 3)::bigint
  from public.do_insurance_r3740 l
  group by l.entity_class
  order by coalesce(sum(l.key_exclusions_flagged), 0) desc;
end;
$$;

-- 8) High-risk coverage queue (underinsured / claim-impacted)
create or replace function public.founder_r3740_high_risk_queue()
returns table(
  entity_name text,
  entity_class text,
  policy_year text,
  period_month date,
  adequacy_status text,
  coverage_limit_rupees numeric,
  peer_benchmark_limit_rupees numeric,
  coverage_gap_pct numeric,
  claims_filed int,
  key_exclusions_flagged int,
  renewal_due_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.entity_class, l.policy_year, l.period_month,
    l.adequacy_status, l.coverage_limit_rupees, l.peer_benchmark_limit_rupees,
    l.coverage_gap_pct, l.claims_filed, l.key_exclusions_flagged,
    l.renewal_due_date, l.notes
  from public.do_insurance_r3740 l
  where l.adequacy_status in ('underinsured','claim_impacted')
  order by l.coverage_gap_pct asc nulls last, l.renewal_due_date asc
  limit 20;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated-only surface
-- =============================================================================
revoke all on function public.founder_r3740_adequacy_status_rollup() from public, anon;
revoke all on function public.founder_r3740_entity_scorecard() from public, anon;
revoke all on function public.founder_r3740_entity_class_status_matrix() from public, anon;
revoke all on function public.founder_r3740_monthly_coverage_gap_trend() from public, anon;
revoke all on function public.founder_r3740_capa_status_board() from public, anon;
revoke all on function public.founder_r3740_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3740_exclusion_digest() from public, anon;
revoke all on function public.founder_r3740_high_risk_queue() from public, anon;

grant execute on function public.founder_r3740_adequacy_status_rollup() to authenticated;
grant execute on function public.founder_r3740_entity_scorecard() to authenticated;
grant execute on function public.founder_r3740_entity_class_status_matrix() to authenticated;
grant execute on function public.founder_r3740_monthly_coverage_gap_trend() to authenticated;
grant execute on function public.founder_r3740_capa_status_board() to authenticated;
grant execute on function public.founder_r3740_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3740_exclusion_digest() to authenticated;
grant execute on function public.founder_r3740_high_risk_queue() to authenticated;

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

  -- 16 D&O coverage-adequacy rows across entities, classes, statuses & months
  insert into public.do_insurance_r3740 (
    organization_id, entity_name, policy_year, period_month,
    coverage_limit_rupees, premium_rupees, deductible_rupees,
    claims_filed, claims_paid_rupees, peer_benchmark_limit_rupees,
    coverage_gap_pct, key_exclusions_flagged, renewal_due_date,
    entity_class, adequacy_status, trend_dir, notes
  )
  select v_org_id, q.en, q.py, q.pm::date,
    q.cl, q.prem, q.ded,
    q.cf, q.cpaid, q.pbl,
    q.cgp, q.kef, q.rdd::date,
    q.ecl, q.ads, q.trd, q.nt
  from (values
    ('EquipSeva Industries Ltd','2026-27','2026-05-01',
     500000000.00,3200000.00,5000000.00,0,0.00,600000000.00,-16.7,2,'2027-03-31',
     'parent_company','marginal','stable','Parent D&O limit trails peer benchmark by ~17%; board reviewing top-up layer'),
    ('EquipSeva Industries Ltd','2026-27','2026-06-01',
     500000000.00,3200000.00,5000000.00,0,0.00,600000000.00,-16.7,2,'2027-03-31',
     'parent_company','marginal','stable','No new claims; top-up quote requested from insurer for FY27 renewal'),
    ('EquipSeva Industries Ltd','2026-27','2026-07-01',
     650000000.00,3550000.00,5000000.00,0,0.00,600000000.00,8.3,1,'2027-03-31',
     'parent_company','adequate','improving','Top-up layer of INR 15 Cr bound; limit now above peer benchmark'),
    ('EquipSeva Karnataka Pvt Ltd','2025-26','2026-05-01',
     100000000.00,850000.00,1000000.00,1,4200000.00,150000000.00,-33.3,3,'2026-09-30',
     'subsidiary','claim_impacted','worsening','Open claim from former-director allegation eroding aggregate limit'),
    ('EquipSeva Karnataka Pvt Ltd','2025-26','2026-06-01',
     100000000.00,850000.00,1000000.00,1,6800000.00,150000000.00,-33.3,3,'2026-09-30',
     'subsidiary','claim_impacted','worsening','Claim reserve increased; remaining aggregate limit under 45 pct'),
    ('EquipSeva Karnataka Pvt Ltd','2025-26','2026-07-01',
     100000000.00,850000.00,1000000.00,1,6800000.00,150000000.00,-33.3,3,'2026-09-30',
     'subsidiary','renewal_pending','stable','Renewal underwriting submission filed ahead of Sept 30 expiry'),
    ('EquipSeva Maharashtra Pvt Ltd','2026-27','2026-05-01',
     120000000.00,640000.00,1000000.00,0,0.00,150000000.00,-20.0,1,'2027-01-31',
     'subsidiary','marginal','stable','Limit unchanged since 2024; peer benchmark has risen 12 pct YoY'),
    ('EquipSeva Maharashtra Pvt Ltd','2026-27','2026-06-01',
     120000000.00,640000.00,1000000.00,0,0.00,150000000.00,-20.0,1,'2027-01-31',
     'subsidiary','marginal','improving','Broker sourcing three competing quotes for January renewal'),
    ('EquipSeva Maharashtra Pvt Ltd','2026-27','2026-07-01',
     150000000.00,720000.00,1000000.00,0,0.00,150000000.00,0.0,1,'2027-01-31',
     'subsidiary','adequate','improving','Limit raised to match peer benchmark ahead of schedule'),
    ('EquipSeva Tamil Nadu Pvt Ltd','2025-26','2026-05-01',
     80000000.00,520000.00,800000.00,0,0.00,100000000.00,-20.0,4,'2026-08-31',
     'subsidiary','underinsured','worsening','Four material exclusions including a cyber-related D&O carve-out'),
    ('EquipSeva Tamil Nadu Pvt Ltd','2025-26','2026-06-01',
     80000000.00,520000.00,800000.00,0,0.00,100000000.00,-20.0,4,'2026-08-31',
     'subsidiary','underinsured','worsening','Broker flagged exclusions as non-standard for sector; renewal at risk'),
    ('EquipSeva Tamil Nadu Pvt Ltd','2025-26','2026-07-01',
     80000000.00,520000.00,800000.00,0,0.00,100000000.00,-20.0,4,'2026-08-31',
     'subsidiary','renewal_pending','stable','RFQ issued to two alternate insurers ahead of Aug 31 expiry'),
    ('EquipSeva-Komatsu JV','2026-27','2026-05-01',
     60000000.00,410000.00,600000.00,0,0.00,70000000.00,-14.3,2,'2027-02-28',
     'joint_venture','marginal','stable','JV shares parent policy; standalone limit review pending'),
    ('EquipSeva-Komatsu JV','2026-27','2026-06-01',
     60000000.00,410000.00,600000.00,0,0.00,70000000.00,-14.3,2,'2027-02-28',
     'joint_venture','adequate','improving','Joint underwriting review with Komatsu parent confirmed limit sufficiency'),
    ('EquipSeva Holdings Trust','2026-27','2026-06-01',
     40000000.00,260000.00,500000.00,0,0.00,50000000.00,-20.0,1,'2027-04-30',
     'holding_entity','adequate','stable','Trust-level cover adequate for passive holding risk profile'),
    ('EquipSeva ESOP Trust','2026-27','2026-07-01',
     20000000.00,140000.00,300000.00,0,0.00,30000000.00,-33.3,2,'2027-05-31',
     'esop_trust','underinsured','worsening','Trustee liability limit unchanged since ESOP pool tripled in FY26')
  ) as q(en, py, pm, cl, prem, ded, cf, cpaid, pbl, cgp, kef, rdd, ecl, ads, trd, nt);

  -- 8 CAPA rows — attach to specific rows via entity_name + period_month
  insert into public.do_insurance_capa_actions_r3740 (
    do_insurance_id, root_cause, corrective_action, capa_status,
    owner, target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('EquipSeva Karnataka Pvt Ltd','2026-05-01',
     'Former-director D&O claim eroded aggregate policy limit',
     'Bind stand-alone excess layer of INR 5 Cr to restore headroom',
     'in_progress','Group Risk and Insurance Head','2026-09-15',null,
     'Excess-layer quote received from two insurers; board sign-off pending'),
    ('EquipSeva Karnataka Pvt Ltd','2026-06-01',
     'Claim reserve increase reduced remaining aggregate limit below 45 pct',
     'Escalate to insurer for interim limit reinstatement endorsement',
     'open','Group Risk and Insurance Head','2026-08-31',null,
     'Interim reinstatement endorsement requested pending claim triage'),
    ('EquipSeva Tamil Nadu Pvt Ltd','2026-05-01',
     'Coverage limit unchanged for three renewal cycles versus rising peer benchmark',
     'Increase primary limit to INR 10 Cr at next renewal',
     'open','CFO Office','2026-08-31',null,
     'RFQ issued to alternate insurers ahead of Aug 31 expiry'),
    ('EquipSeva Tamil Nadu Pvt Ltd','2026-06-01',
     'Non-standard exclusions carved out by incumbent insurer',
     'Negotiate removal of cyber-related D&O exclusion at renewal',
     'in_progress','Group Risk and Insurance Head','2026-08-20',null,
     'Two alternate insurers willing to drop the exclusion at an 8 pct premium uplift'),
    ('EquipSeva ESOP Trust','2026-07-01',
     'Trustee liability limit unchanged since ESOP pool tripled in FY26',
     'Raise trustee liability sub-limit proportionate to pool size',
     'open','Company Secretary','2026-09-30',null,
     'Actuarial sizing of revised pool submitted to insurer for quote'),
    ('EquipSeva Industries Ltd','2026-05-01',
     'Parent D&O limit trailing peer benchmark by ~17 pct',
     'Bind INR 15 Cr top-up excess layer',
     'closed','Group CFO','2026-07-15','2026-07-10',
     'Top-up layer bound ahead of schedule; limit now above peer benchmark'),
    ('EquipSeva Maharashtra Pvt Ltd','2026-05-01',
     'Static coverage limit against a 12 pct YoY peer benchmark increase',
     'Raise primary limit to match revised peer benchmark',
     'closed','CFO Office','2026-07-31','2026-07-05',
     'Limit raised to INR 15 Cr, matching peer benchmark ahead of January renewal'),
    ('EquipSeva-Komatsu JV','2026-05-01',
     'Standalone D&O limit review pending since JV inception',
     'Complete standalone limit adequacy review with Komatsu risk team',
     'overdue','JV Governance Lead','2026-07-01',null,
     'Joint review delayed by Komatsu-side sign-off; escalated to JV board')
  ) as q(en, pm, rc, ca, cst, ownr, tcd, acd, nt)
  join public.do_insurance_r3740 e
    on e.organization_id = v_org_id and e.entity_name = q.en and e.period_month = q.pm::date;
end;
$seed$;
