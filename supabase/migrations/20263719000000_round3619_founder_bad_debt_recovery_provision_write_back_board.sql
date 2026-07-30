-- Round 3619: Founder Bad-Debt Recovery / Provision Write-Back Board
-- Bad-debt recovery log — customer segment × period × provision opening/closing × write-offs × recoveries × write-backs × recovery-rate × coverage × recovery-status × trend × CAPA

-- =============================================================================
-- TABLE 1: baddebt_recovery_r3619 — per-segment provision movement records
-- =============================================================================
create table if not exists public.baddebt_recovery_r3619 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  business_unit text not null check (business_unit in (
    'amc_services','spare_parts','projects','diagnostics','rentals'
  )),
  ledger_ref text not null,
  customer_segment text not null check (customer_segment in (
    'government_hospitals','private_hospital_chains','standalone_clinics',
    'diagnostic_labs','medical_colleges','dealers_distributors'
  )),
  period_month date not null,
  provision_opening_rupees numeric(14,2) not null,
  write_offs_rupees numeric(14,2) not null,
  recoveries_rupees numeric(14,2) not null,
  write_backs_rupees numeric(14,2) not null,
  provision_closing_rupees numeric(14,2) not null,
  recovery_rate_pct numeric(6,2),
  gross_receivables_rupees numeric(14,2),
  provision_coverage_pct numeric(6,2),
  recovery_status text not null check (recovery_status in (
    'strong_recovery','on_track','stalled','deteriorating','write_off_heavy'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.baddebt_recovery_r3619 enable row level security;

create index if not exists idx_baddebt_recovery_r3619_org on public.baddebt_recovery_r3619(organization_id);
create index if not exists idx_baddebt_recovery_r3619_period on public.baddebt_recovery_r3619(period_month);
create index if not exists idx_baddebt_recovery_r3619_status on public.baddebt_recovery_r3619(recovery_status);

-- =============================================================================
-- TABLE 2: baddebt_recovery_capa_actions_r3619 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.baddebt_recovery_capa_actions_r3619 (
  id uuid primary key default gen_random_uuid(),
  recovery_log_id uuid not null references public.baddebt_recovery_r3619(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'aged_receivable_over_180d','disputed_invoice','customer_insolvency',
    'partial_recovery_negotiation','warranty_deduction_dispute','collection_process_gap',
    'provision_over_estimated','legal_recovery_pending'
  )),
  root_cause text not null check (root_cause in (
    'customer_liquidity_crisis','billing_dispute_unresolved','service_quality_dispute',
    'contract_terms_ambiguity','collection_follow_up_lapse','insolvency_bankruptcy',
    'wrong_provisioning_estimate','payment_delay_government_budget','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'settlement_negotiated','legal_notice_issued','write_off_approved','provision_written_back',
    'payment_plan_agreed','escalate_to_collection_agency','revise_provision_policy',
    'strengthen_credit_control','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  recovery_outlook text not null check (recovery_outlook in (
    'full_recovery_expected','partial_recovery_expected','settlement_route',
    'write_off_route','under_review'
  )),
  recovery_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.baddebt_recovery_capa_actions_r3619 enable row level security;

create index if not exists idx_baddebt_recovery_capa_r3619_log on public.baddebt_recovery_capa_actions_r3619(recovery_log_id);
create index if not exists idx_baddebt_recovery_capa_r3619_status on public.baddebt_recovery_capa_actions_r3619(capa_status);

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

  -- 16 provision-movement rows
  insert into public.baddebt_recovery_r3619 (
    organization_id, business_unit, ledger_ref, customer_segment, period_month,
    provision_opening_rupees, write_offs_rupees, recoveries_rupees, write_backs_rupees,
    provision_closing_rupees, recovery_rate_pct, gross_receivables_rupees, provision_coverage_pct,
    recovery_status, trend_dir, notes
  )
  select v_org_id, q.bunit, q.lref, q.seg, q.pmon::date,
    q.popen, q.woff, q.rec, q.wback,
    q.pclose, q.rrate, q.gross, q.cov,
    q.rstat, q.trend, q.nt
  from (values
    ('amc_services','BDR-AMC-GOV-2607','government_hospitals','2026-07-01',
     4200000,180000,950000,320000,3700000,22.60,12500000,29.60,'strong_recovery','improving','Government AMC dues recovered post budget release; provision written back'),
    ('spare_parts','BDR-SPR-PRV-2607','private_hospital_chains','2026-07-01',
     2600000,240000,610000,90000,2260000,23.50,8400000,26.90,'on_track','stable','Private chain spares dues progressing on structured payment plan'),
    ('projects','BDR-PRJ-MED-2607','medical_colleges','2026-07-01',
     5400000,620000,480000,0,5300000,8.90,15800000,33.50,'stalled','worsening','Medical college turnkey project retention stuck in contract dispute'),
    ('diagnostics','BDR-DIA-LAB-2607','diagnostic_labs','2026-07-01',
     1800000,95000,540000,160000,1005000,30.00,5200000,19.30,'strong_recovery','improving','Diagnostic lab reagent dues cleared ahead of schedule'),
    ('rentals','BDR-RNT-STD-2607','standalone_clinics','2026-07-01',
     1200000,310000,210000,0,1580000,17.50,3100000,51.00,'deteriorating','worsening','Standalone clinic rental equipment dues aging past 180 days'),
    ('spare_parts','BDR-SPR-DLR-2607','dealers_distributors','2026-07-01',
     900000,420000,120000,0,1200000,13.30,2400000,50.00,'write_off_heavy','worsening','Distributor insolvency confirmed — heavy write-off booked'),
    ('amc_services','BDR-AMC-PRV-2606','private_hospital_chains','2026-06-01',
     2800000,160000,720000,140000,2380000,25.70,9100000,26.20,'on_track','improving','AMC dues from private chain recovering steadily'),
    ('projects','BDR-PRJ-GOV-2606','government_hospitals','2026-06-01',
     6100000,210000,1350000,260000,4280000,22.10,18200000,23.50,'strong_recovery','improving','Government project milestone payment released; provision reversed'),
    ('diagnostics','BDR-DIA-MED-2606','medical_colleges','2026-06-01',
     2100000,340000,190000,0,2250000,9.00,6300000,35.70,'stalled','stable','Medical college diagnostics dues under negotiation'),
    ('rentals','BDR-RNT-PRV-2606','private_hospital_chains','2026-06-01',
     1500000,90000,430000,110000,870000,28.70,4100000,21.20,'strong_recovery','improving','Rental fleet dues from private chain settled'),
    ('spare_parts','BDR-SPR-STD-2606','standalone_clinics','2026-06-01',
     780000,260000,90000,0,950000,11.50,1900000,50.00,'deteriorating','worsening','Standalone clinic spares dues deteriorating with weak follow-up'),
    ('amc_services','BDR-AMC-DLR-2605','dealers_distributors','2026-05-01',
     1100000,480000,150000,0,1400000,13.60,2900000,48.30,'write_off_heavy','worsening','Distributor AMC receivables largely written off after bankruptcy'),
    ('projects','BDR-PRJ-PRV-2605','private_hospital_chains','2026-05-01',
     4700000,180000,890000,200000,3630000,18.90,13400000,27.10,'on_track','stable','Private hospital project retention releasing in tranches'),
    ('diagnostics','BDR-DIA-GOV-2605','government_hospitals','2026-05-01',
     3300000,140000,1020000,240000,2140000,30.90,9700000,22.10,'strong_recovery','improving','Government diagnostics dues recovered via treasury clearance'),
    ('rentals','BDR-RNT-MED-2605','medical_colleges','2026-05-01',
     1600000,380000,160000,0,1820000,10.00,3600000,50.60,'deteriorating','worsening','Medical college rental dues aging; escalation raised'),
    ('spare_parts','BDR-SPR-LAB-2605','diagnostic_labs','2026-05-01',
     950000,70000,320000,80000,560000,33.70,2700000,20.70,'strong_recovery','improving','Diagnostic lab spares dues cleared; provision released')
  ) as q(bunit, lref, seg, pmon, popen, woff, rec, wback, pclose, rrate, gross, cov, rstat, trend, nt);

  -- CAPA seed — attach to specific ledger rows via ledger_ref
  insert into public.baddebt_recovery_capa_actions_r3619 (
    recovery_log_id, finding_category, root_cause, corrective_action,
    capa_status, recovery_outlook, recovery_impact_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.rout, q.imp, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('BDR-PRJ-MED-2607','legal_recovery_pending','contract_terms_ambiguity','legal_notice_issued','in_progress','settlement_route',620000,'Collections Lead - Anand','2026-08-15',null,'Medical college project retention dispute — legal notice served'),
    ('BDR-RNT-STD-2607','aged_receivable_over_180d','collection_follow_up_lapse','escalate_to_collection_agency','open','partial_recovery_expected',310000,'Regional AR - Priya','2026-08-10',null,'Standalone clinic rental dues past 180 days — agency engaged'),
    ('BDR-SPR-DLR-2607','customer_insolvency','insolvency_bankruptcy','write_off_approved','closed','write_off_route',420000,'CFO Office','2026-07-20','2026-07-18','Distributor insolvency confirmed; write-off approved by committee'),
    ('BDR-DIA-MED-2606','disputed_invoice','billing_dispute_unresolved','settlement_negotiated','verification_pending','partial_recovery_expected',340000,'Key Accounts - Rahul','2026-08-05',null,'Medical college diagnostics billing dispute in settlement talks'),
    ('BDR-SPR-STD-2606','collection_process_gap','collection_follow_up_lapse','strengthen_credit_control','in_progress','under_review',260000,'Credit Control - Meena','2026-08-12',null,'Standalone clinic spares — credit control process tightened'),
    ('BDR-AMC-DLR-2605','customer_insolvency','insolvency_bankruptcy','write_off_approved','closed','write_off_route',480000,'CFO Office','2026-06-25','2026-06-22','Distributor AMC receivables written off after bankruptcy filing'),
    ('BDR-RNT-MED-2605','aged_receivable_over_180d','payment_delay_government_budget','payment_plan_agreed','overdue','partial_recovery_expected',380000,'Regional AR - Priya','2026-06-30',null,'Medical college rental dues — payment plan slipping past target'),
    ('BDR-PRJ-GOV-2606','partial_recovery_negotiation','payment_delay_government_budget','provision_written_back','closed','full_recovery_expected',260000,'Finance Controller','2026-07-10','2026-07-05','Government project milestone released; provision written back')
  ) as q(lref, fc, rc, ca, cst, rout, imp, ownr, tcd, acd, nt)
  join public.baddebt_recovery_r3619 e
    on e.organization_id = v_org_id and e.ledger_ref = q.lref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Recovery-status distribution
create or replace function public.founder_r3619_recovery_status_rollup()
returns table(recovery_status text, entries bigint, total_write_offs_rupees numeric, total_recoveries_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.baddebt_recovery_r3619)
  select l.recovery_status, count(*)::bigint,
         coalesce(sum(l.write_offs_rupees),0)::numeric,
         coalesce(sum(l.recoveries_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.baddebt_recovery_r3619 l
  group by l.recovery_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3619_recovery_status_rollup() from public, anon;
grant execute on function public.founder_r3619_recovery_status_rollup() to authenticated;

-- 2) Customer-segment scorecard
create or replace function public.founder_r3619_segment_scorecard()
returns table(
  customer_segment text,
  entries bigint,
  total_gross_receivables_rupees numeric,
  total_opening_rupees numeric,
  total_write_offs_rupees numeric,
  total_recoveries_rupees numeric,
  total_write_backs_rupees numeric,
  total_closing_rupees numeric,
  avg_recovery_rate_pct numeric,
  avg_coverage_pct numeric
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
    coalesce(sum(l.gross_receivables_rupees),0)::numeric,
    coalesce(sum(l.provision_opening_rupees),0)::numeric,
    coalesce(sum(l.write_offs_rupees),0)::numeric,
    coalesce(sum(l.recoveries_rupees),0)::numeric,
    coalesce(sum(l.write_backs_rupees),0)::numeric,
    coalesce(sum(l.provision_closing_rupees),0)::numeric,
    round(avg(l.recovery_rate_pct), 2),
    round(avg(l.provision_coverage_pct), 2)
  from public.baddebt_recovery_r3619 l
  group by l.customer_segment
  order by coalesce(sum(l.write_offs_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3619_segment_scorecard() from public, anon;
grant execute on function public.founder_r3619_segment_scorecard() to authenticated;

-- 3) Segment × recovery-status matrix
create or replace function public.founder_r3619_segment_status_matrix()
returns table(customer_segment text, recovery_status text, entries bigint, total_recoveries_rupees numeric, total_write_offs_rupees numeric, avg_recovery_rate_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment, l.recovery_status, count(*)::bigint,
    coalesce(sum(l.recoveries_rupees),0)::numeric,
    coalesce(sum(l.write_offs_rupees),0)::numeric,
    round(avg(l.recovery_rate_pct), 2)
  from public.baddebt_recovery_r3619 l
  group by l.customer_segment, l.recovery_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3619_segment_status_matrix() from public, anon;
grant execute on function public.founder_r3619_segment_status_matrix() to authenticated;

-- 4) Monthly recovery trend
create or replace function public.founder_r3619_monthly_recovery_trend()
returns table(period_month date, entries bigint, total_write_offs_rupees numeric, total_recoveries_rupees numeric, total_write_backs_rupees numeric, avg_recovery_rate_pct numeric, avg_coverage_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.write_offs_rupees),0)::numeric,
    coalesce(sum(l.recoveries_rupees),0)::numeric,
    coalesce(sum(l.write_backs_rupees),0)::numeric,
    round(avg(l.recovery_rate_pct), 2),
    round(avg(l.provision_coverage_pct), 2)
  from public.baddebt_recovery_r3619 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3619_monthly_recovery_trend() from public, anon;
grant execute on function public.founder_r3619_monthly_recovery_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3619_capa_status_board()
returns table(capa_status text, findings bigint, total_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.baddebt_recovery_capa_actions_r3619 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3619_capa_status_board() from public, anon;
grant execute on function public.founder_r3619_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3619_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.baddebt_recovery_capa_actions_r3619)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.baddebt_recovery_capa_actions_r3619 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3619_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3619_root_cause_pareto() to authenticated;

-- 7) Recovery-impact digest
create or replace function public.founder_r3619_recovery_impact_digest()
returns table(recovery_outlook text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.recovery_outlook, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric
  from public.baddebt_recovery_capa_actions_r3619 c
  group by c.recovery_outlook
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3619_recovery_impact_digest() from public, anon;
grant execute on function public.founder_r3619_recovery_impact_digest() to authenticated;

-- 8) High-risk recovery queue (deteriorating / write_off_heavy)
create or replace function public.founder_r3619_high_risk_queue()
returns table(
  business_unit text,
  ledger_ref text,
  customer_segment text,
  period_month date,
  recovery_status text,
  write_offs_rupees numeric,
  recovery_rate_pct numeric,
  provision_coverage_pct numeric,
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
  select l.business_unit, l.ledger_ref, l.customer_segment, l.period_month,
    l.recovery_status, l.write_offs_rupees, l.recovery_rate_pct, l.provision_coverage_pct,
    l.trend_dir, l.notes
  from public.baddebt_recovery_r3619 l
  where l.recovery_status in ('deteriorating','write_off_heavy','stalled')
     or l.trend_dir = 'worsening'
  order by l.write_offs_rupees desc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3619_high_risk_queue() from public, anon;
grant execute on function public.founder_r3619_high_risk_queue() to authenticated;
