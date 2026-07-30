-- Round 3623: Founder Inter-Unit / Inter-Company Balance Reconciliation Board
-- Founder finance board — inter-unit / inter-company balance reconciliation: unit-pair × period ×
-- receivable/payable balances × difference × matched/unmatched × ageing × matched-% × recon status ×
-- trend × CAPA closure for unmatched aging per unit-pair.

-- =============================================================================
-- TABLE 1: inter_unit_recon_r3623 — per unit-pair / period reconciliation fact
-- =============================================================================
create table if not exists public.inter_unit_recon_r3623 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  recon_ref text not null,
  unit_pair text not null,
  period_month date not null,
  receivable_balance_rupees numeric(14,2),
  payable_balance_rupees numeric(14,2),
  difference_rupees numeric(14,2),
  matched_rupees numeric(14,2),
  unmatched_rupees numeric(14,2),
  ageing_days int,
  transactions_count int,
  matched_pct numeric(5,2),
  recon_status text not null check (recon_status in (
    'matched','minor_diff','material_diff','unreconciled','disputed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.inter_unit_recon_r3623 enable row level security;

create index if not exists idx_inter_unit_recon_r3623_org on public.inter_unit_recon_r3623(organization_id);
create index if not exists idx_inter_unit_recon_r3623_month on public.inter_unit_recon_r3623(period_month);
create index if not exists idx_inter_unit_recon_r3623_status on public.inter_unit_recon_r3623(recon_status);

-- =============================================================================
-- TABLE 2: inter_unit_recon_capa_actions_r3623 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.inter_unit_recon_capa_actions_r3623 (
  id uuid primary key default gen_random_uuid(),
  recon_id uuid not null references public.inter_unit_recon_r3623(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'timing_difference','unrecorded_invoice','duplicate_entry','fx_rate_mismatch',
    'intercompany_markup_error','cutoff_error','missing_grn','manual_journal_error',
    'pending_investigation','system_interface_failure'
  )),
  corrective_action text not null check (corrective_action in (
    'pass_adjusting_entry','reverse_duplicate','book_missing_invoice','correct_fx_rate',
    'align_intercompany_markup','reconcile_cutoff','match_grn','escalate_to_controller',
    'write_off_immaterial','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.inter_unit_recon_capa_actions_r3623 enable row level security;

create index if not exists idx_inter_unit_recon_capa_r3623_recon on public.inter_unit_recon_capa_actions_r3623(recon_id);
create index if not exists idx_inter_unit_recon_capa_r3623_status on public.inter_unit_recon_capa_actions_r3623(capa_status);

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

  -- 16 reconciliation rows
  insert into public.inter_unit_recon_r3623 (
    organization_id, recon_ref, unit_pair, period_month,
    receivable_balance_rupees, payable_balance_rupees, difference_rupees,
    matched_rupees, unmatched_rupees, ageing_days, transactions_count, matched_pct,
    recon_status, trend_dir, notes
  )
  select v_org_id, q.rref, q.upair, q.pmon::date,
    q.recv, q.pay, q.diff,
    q.mtch, q.unmt, q.agd, q.txn, q.mpct,
    q.rstat, q.tdir, q.nt
  from (values
    ('IUR-2607-01','equipseva_ho__chennai_branch','2026-07-01',
     4520000.00,4480000.00,40000.00,4480000.00,40000.00,12,320,99.1,'minor_diff','improving','Chennai branch AMC receivables near-matched; small timing diff'),
    ('IUR-2607-02','equipseva_ho__mumbai_branch','2026-07-01',
     6250000.00,6250000.00,0.00,6250000.00,0.00,0,410,100.0,'matched','stable','Mumbai branch fully reconciled for July close'),
    ('IUR-2607-03','equipseva_ho__delhi_branch','2026-07-01',
     3820000.00,3510000.00,310000.00,3510000.00,310000.00,47,275,91.9,'material_diff','worsening','Delhi branch spare-parts transfers unbooked at HO'),
    ('IUR-2607-04','amc_services__spare_parts','2026-07-01',
     1980000.00,1500000.00,480000.00,1500000.00,480000.00,63,190,75.8,'unreconciled','worsening','Inter-unit spare issues to AMC not invoiced; large open balance'),
    ('IUR-2607-05','projects__diagnostics','2026-07-01',
     2740000.00,2690000.00,50000.00,2690000.00,50000.00,18,145,98.2,'minor_diff','stable','Diagnostics project cross-charge minor cutoff diff'),
    ('IUR-2607-06','equipseva_ltd__equipseva_diagnostics_pvt','2026-07-01',
     8900000.00,8100000.00,800000.00,8100000.00,800000.00,88,96,91.0,'disputed','worsening','Inter-company markup dispute on diagnostics equipment sale'),
    ('IUR-2606-07','equipseva_ho__chennai_branch','2026-06-01',
     4310000.00,4250000.00,60000.00,4250000.00,60000.00,20,305,98.6,'minor_diff','improving','June Chennai reconciliation timing diff partly cleared'),
    ('IUR-2606-08','equipseva_ho__delhi_branch','2026-06-01',
     3600000.00,3280000.00,320000.00,3280000.00,320000.00,55,260,91.1,'material_diff','worsening','Delhi branch June unmatched carried forward'),
    ('IUR-2606-09','chennai_branch__bengaluru_branch','2026-06-01',
     1560000.00,1560000.00,0.00,1560000.00,0.00,0,88,100.0,'matched','stable','Chennai-Bengaluru inter-branch stock transfer fully matched'),
    ('IUR-2606-10','spare_parts__amc_services','2026-06-01',
     2100000.00,1720000.00,380000.00,1720000.00,380000.00,58,210,81.9,'unreconciled','worsening','Spare issues to AMC pending inter-unit invoicing'),
    ('IUR-2605-11','equipseva_ho__mumbai_branch','2026-05-01',
     5980000.00,5930000.00,50000.00,5930000.00,50000.00,15,388,99.2,'minor_diff','improving','May Mumbai near matched at close'),
    ('IUR-2605-12','projects__diagnostics','2026-05-01',
     2510000.00,2210000.00,300000.00,2210000.00,300000.00,72,130,88.0,'material_diff','worsening','May diagnostics cross-charge dispute unresolved'),
    ('IUR-2605-13','equipseva_ltd__equipseva_diagnostics_pvt','2026-05-01',
     8400000.00,8400000.00,0.00,8400000.00,0.00,0,90,100.0,'matched','improving','May inter-company balance fully matched post true-up'),
    ('IUR-2604-14','amc_services__spare_parts','2026-04-01',
     1850000.00,1600000.00,250000.00,1600000.00,250000.00,96,175,86.5,'unreconciled','worsening','Aged April spare-to-AMC balance still open'),
    ('IUR-2604-15','equipseva_ho__delhi_branch','2026-04-01',
     3400000.00,3390000.00,10000.00,3390000.00,10000.00,8,250,99.7,'minor_diff','improving','April Delhi nearly clean; immaterial residual'),
    ('IUR-2607-16','equipseva_ho__bengaluru_branch','2026-07-01',
     2960000.00,2600000.00,360000.00,2600000.00,360000.00,41,168,87.8,'material_diff','stable','Bengaluru branch project billing timing gap')
  ) as q(rref, upair, pmon, recv, pay, diff, mtch, unmt, agd, txn, mpct, rstat, tdir, nt);

  -- 9 CAPA rows — attach to specific reconciliations via recon_ref
  insert into public.inter_unit_recon_capa_actions_r3623 (
    recon_id, root_cause, corrective_action, capa_status,
    impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.imp, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('IUR-2607-03','unrecorded_invoice','book_missing_invoice','in_progress',310000.00,'Priya Nair (Controller)','2026-07-15',null,'Book HO-side spare transfer invoices to clear Delhi diff'),
    ('IUR-2607-04','missing_grn','match_grn','open',480000.00,'Rahul Verma (AP Lead)','2026-07-20',null,'Match spare GRNs against AMC issue notes; raise inter-unit invoice'),
    ('IUR-2607-06','intercompany_markup_error','align_intercompany_markup','escalated',800000.00,'Anita Rao (CFO Office)','2026-07-18',null,'Inter-company markup dispute escalated to CFO for true-up policy'),
    ('IUR-2606-08','timing_difference','pass_adjusting_entry','verification_pending',320000.00,'Priya Nair (Controller)','2026-07-10',null,'Adjusting entry passed; verifying Delhi branch acknowledgement'),
    ('IUR-2606-10','missing_grn','match_grn','in_progress',380000.00,'Rahul Verma (AP Lead)','2026-07-12',null,'GRN matching in progress for spare-to-AMC transfers'),
    ('IUR-2605-12','cutoff_error','reconcile_cutoff','closed',300000.00,'Suresh Iyer (Project Finance)','2026-06-05','2026-06-02','Cutoff realigned across projects and diagnostics ledgers'),
    ('IUR-2604-14','pending_investigation','escalate_to_controller','overdue',250000.00,'Rahul Verma (AP Lead)','2026-06-30',null,'Aged April balance past target; escalated to controller'),
    ('IUR-2607-16','timing_difference','pass_adjusting_entry','open',360000.00,'Kavita Menon (Branch Finance)','2026-07-25',null,'Bengaluru project billing timing gap to be squared next cycle'),
    ('IUR-2604-15','manual_journal_error','write_off_immaterial','closed',10000.00,'Priya Nair (Controller)','2026-04-20','2026-04-18','Immaterial residual written off after approval')
  ) as q(rref, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.inter_unit_recon_r3623 e
    on e.organization_id = v_org_id and e.recon_ref = q.rref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Recon-status distribution
create or replace function public.founder_r3623_recon_status_rollup()
returns table(recon_status text, entries bigint, total_unmatched_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.inter_unit_recon_r3623)
  select l.recon_status, count(*)::bigint,
         coalesce(sum(l.unmatched_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.inter_unit_recon_r3623 l
  group by l.recon_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3623_recon_status_rollup() from public, anon;
grant execute on function public.founder_r3623_recon_status_rollup() to authenticated;

-- 2) Unit-pair scorecard
create or replace function public.founder_r3623_unit_pair_scorecard()
returns table(
  unit_pair text,
  entries bigint,
  total_receivable_rupees numeric,
  total_payable_rupees numeric,
  total_difference_rupees numeric,
  total_unmatched_rupees numeric,
  avg_matched_pct numeric,
  unreconciled bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.unit_pair,
    count(*)::bigint,
    coalesce(sum(l.receivable_balance_rupees),0)::numeric,
    coalesce(sum(l.payable_balance_rupees),0)::numeric,
    coalesce(sum(l.difference_rupees),0)::numeric,
    coalesce(sum(l.unmatched_rupees),0)::numeric,
    round(avg(l.matched_pct), 1),
    count(*) filter (where l.recon_status in ('material_diff','unreconciled','disputed'))::bigint
  from public.inter_unit_recon_r3623 l
  group by l.unit_pair
  order by coalesce(sum(l.unmatched_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3623_unit_pair_scorecard() from public, anon;
grant execute on function public.founder_r3623_unit_pair_scorecard() to authenticated;

-- 3) Unit-pair × recon-status matrix
create or replace function public.founder_r3623_unit_pair_status_matrix()
returns table(unit_pair text, recon_status text, entries bigint, total_unmatched_rupees numeric, avg_ageing_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.unit_pair, l.recon_status, count(*)::bigint,
    coalesce(sum(l.unmatched_rupees),0)::numeric,
    round(avg(l.ageing_days), 1)
  from public.inter_unit_recon_r3623 l
  group by l.unit_pair, l.recon_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3623_unit_pair_status_matrix() from public, anon;
grant execute on function public.founder_r3623_unit_pair_status_matrix() to authenticated;

-- 4) Monthly reconciliation trend
create or replace function public.founder_r3623_monthly_recon_trend()
returns table(
  period_month date,
  entries bigint,
  total_difference_rupees numeric,
  total_unmatched_rupees numeric,
  avg_matched_pct numeric,
  material_or_unreconciled bigint
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
    coalesce(sum(l.difference_rupees),0)::numeric,
    coalesce(sum(l.unmatched_rupees),0)::numeric,
    round(avg(l.matched_pct), 1),
    count(*) filter (where l.recon_status in ('material_diff','unreconciled'))::bigint
  from public.inter_unit_recon_r3623 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3623_monthly_recon_trend() from public, anon;
grant execute on function public.founder_r3623_monthly_recon_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3623_capa_status_board()
returns table(capa_status text, actions bigint, total_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.inter_unit_recon_capa_actions_r3623 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3623_capa_status_board() from public, anon;
grant execute on function public.founder_r3623_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3623_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.inter_unit_recon_capa_actions_r3623)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.inter_unit_recon_capa_actions_r3623 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3623_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3623_root_cause_pareto() to authenticated;

-- 7) Unmatched-impact digest (by recon status)
create or replace function public.founder_r3623_unmatched_impact_digest()
returns table(
  recon_status text,
  entries bigint,
  total_unmatched_rupees numeric,
  total_difference_rupees numeric,
  avg_ageing_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.recon_status, count(*)::bigint,
    coalesce(sum(l.unmatched_rupees),0)::numeric,
    coalesce(sum(l.difference_rupees),0)::numeric,
    round(avg(l.ageing_days), 1)
  from public.inter_unit_recon_r3623 l
  group by l.recon_status
  order by coalesce(sum(l.unmatched_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3623_unmatched_impact_digest() from public, anon;
grant execute on function public.founder_r3623_unmatched_impact_digest() to authenticated;

-- 8) High-risk queue (material_diff / unreconciled / disputed)
create or replace function public.founder_r3623_high_risk_queue()
returns table(
  unit_pair text,
  recon_ref text,
  period_month date,
  recon_status text,
  difference_rupees numeric,
  unmatched_rupees numeric,
  ageing_days int,
  matched_pct numeric,
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
  select l.unit_pair, l.recon_ref, l.period_month, l.recon_status,
    l.difference_rupees, l.unmatched_rupees, l.ageing_days, l.matched_pct, l.trend_dir, l.notes
  from public.inter_unit_recon_r3623 l
  where l.recon_status in ('material_diff','unreconciled','disputed')
     or l.ageing_days >= 60
     or l.matched_pct < 90
     or l.trend_dir = 'worsening'
  order by l.unmatched_rupees desc, l.ageing_days desc;
end;
$$;

revoke execute on function public.founder_r3623_high_risk_queue() from public, anon;
grant execute on function public.founder_r3623_high_risk_queue() to authenticated;
