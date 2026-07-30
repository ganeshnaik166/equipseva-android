-- Round 3618: Founder Solvency / Capital-Adequacy / Net-Debt Gearing Board
-- Founder solvency finance — entity × period × net-debt gearing × D/E × net-debt/EBITDA × interest-cover
--   × target-gearing headroom × solvency status × trend × CAPA remediation

-- =============================================================================
-- TABLE 1: solvency_r3618 — per-entity monthly solvency / gearing snapshot
-- =============================================================================
create table if not exists public.solvency_r3618 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  entity_code text not null,
  period_month date not null,
  business_unit text not null check (business_unit in (
    'amc_services','spare_parts','projects','diagnostics','rentals','consolidated'
  )),
  total_debt_rupees numeric(16,2),
  net_debt_rupees numeric(16,2),
  equity_rupees numeric(16,2),
  ebitda_rupees numeric(16,2),
  debt_to_equity_ratio numeric(8,2),
  net_debt_to_ebitda_ratio numeric(8,2),
  interest_coverage_ratio numeric(8,2),
  target_gearing_ratio numeric(8,2),
  gearing_headroom_pct numeric(6,2),
  solvency_status text not null check (solvency_status in (
    'robust','healthy','leveraged','stretched','distressed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.solvency_r3618 enable row level security;

create index if not exists idx_solvency_r3618_org on public.solvency_r3618(organization_id);
create index if not exists idx_solvency_r3618_period on public.solvency_r3618(period_month);
create index if not exists idx_solvency_r3618_status on public.solvency_r3618(solvency_status);

-- =============================================================================
-- TABLE 2: solvency_capa_actions_r3618 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.solvency_capa_actions_r3618 (
  id uuid primary key default gen_random_uuid(),
  solvency_log_id uuid not null references public.solvency_r3618(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'gearing_above_target','net_debt_ebitda_breach','interest_cover_thin','debt_to_equity_high',
    'covenant_headroom_low','refinancing_due','equity_erosion','liquidity_pressure'
  )),
  root_cause text not null check (root_cause in (
    'capex_overrun','working_capital_stretch','ebitda_shortfall','high_interest_cost',
    'acquisition_debt','delayed_receivables','fx_loss','dividend_payout','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'refinance_debt','equity_infusion','deleverage_asset_sale','tighten_working_capital',
    'cost_reduction','renegotiate_covenants','pause_capex','accelerate_collections','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_category text not null check (impact_category in (
    'covenant_breach','rating_watch','lender_notifiable','internal_only','board_escalation','refinancing_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  ebitda_impact_rupees numeric(16,2),
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.solvency_capa_actions_r3618 enable row level security;

create index if not exists idx_solvency_capa_r3618_log on public.solvency_capa_actions_r3618(solvency_log_id);
create index if not exists idx_solvency_capa_r3618_status on public.solvency_capa_actions_r3618(capa_status);

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

  -- 16 solvency snapshot rows
  insert into public.solvency_r3618 (
    organization_id, entity_name, entity_code, period_month, business_unit,
    total_debt_rupees, net_debt_rupees, equity_rupees, ebitda_rupees,
    debt_to_equity_ratio, net_debt_to_ebitda_ratio, interest_coverage_ratio,
    target_gearing_ratio, gearing_headroom_pct, solvency_status, trend_dir, notes
  )
  select v_org_id, q.enm, q.ecode, q.pmon::date, q.bunit,
    q.tdebt, q.ndebt, q.eqty, q.ebit,
    q.de, q.nde, q.icov,
    q.tgear, q.hroom, q.sstat, q.tdir, q.nt
  from (values
    ('AMC Services BU','AMC-BU-M05','2026-05-01','amc_services',
     90000000,60000000,180000000,42000000,0.50,1.43,8.40,0.60,16.67,'robust','improving','AMC annuity book keeps leverage low; strong interest cover'),
    ('AMC Services BU','AMC-BU-M06','2026-06-01','amc_services',
     95000000,64000000,182000000,43000000,0.52,1.49,8.10,0.60,13.33,'robust','stable','AMC BU steady; headroom vs 0.60 target intact'),
    ('AMC Services BU','AMC-BU-M07','2026-07-01','amc_services',
     98000000,66000000,184000000,44000000,0.53,1.50,8.00,0.60,11.67,'healthy','stable','Minor debt uptick for tool vans; still comfortable'),
    ('Spare Parts BU','SPR-BU-M06','2026-06-01','spare_parts',
     140000000,120000000,160000000,52000000,0.88,2.31,5.20,0.90,2.22,'healthy','worsening','Inventory build for import buffer lifted working-capital debt'),
    ('Spare Parts BU','SPR-BU-M07','2026-07-01','spare_parts',
     158000000,138000000,158000000,51000000,1.00,2.71,4.60,0.90,-11.11,'leveraged','worsening','Spare-parts stocking pushed D/E to target ceiling; headroom negative'),
    ('Projects BU','PRJ-BU-M05','2026-05-01','projects',
     260000000,230000000,150000000,58000000,1.73,3.97,2.80,1.25,-38.40,'stretched','worsening','Turnkey OT project drawdowns; milestone billing lag strained gearing'),
    ('Projects BU','PRJ-BU-M06','2026-06-01','projects',
     248000000,218000000,152000000,60000000,1.63,3.63,3.10,1.25,-30.40,'leveraged','improving','Milestone collection eased net debt; recovering toward target'),
    ('Projects BU','PRJ-BU-M07','2026-07-01','projects',
     232000000,205000000,156000000,62000000,1.49,3.31,3.40,1.25,-19.20,'leveraged','improving','Deleveraging on collections; interest cover rebuilding'),
    ('Diagnostics BU','DGN-BU-M06','2026-06-01','diagnostics',
     310000000,290000000,120000000,54000000,2.58,5.37,1.40,1.50,-72.00,'distressed','worsening','Lab-equipment capex debt heavy; interest cover below 1.5'),
    ('Diagnostics BU','DGN-BU-M07','2026-07-01','diagnostics',
     305000000,284000000,118000000,55000000,2.58,5.16,1.45,1.50,-72.30,'distressed','stable','Refinancing under negotiation; covenant breach flagged'),
    ('Rentals BU','RNT-BU-M06','2026-06-01','rentals',
     200000000,176000000,140000000,46000000,1.43,3.83,2.20,1.20,-19.20,'stretched','worsening','Rental-fleet expansion debt; utilization dip cut EBITDA'),
    ('Rentals BU','RNT-BU-M07','2026-07-01','rentals',
     194000000,170000000,142000000,48000000,1.37,3.54,2.45,1.20,-14.20,'stretched','improving','Utilization recovering; net debt easing slightly'),
    ('Consolidated Group','GRP-CON-M05','2026-05-01','consolidated',
     920000000,800000000,760000000,250000000,1.21,3.20,3.50,1.10,-10.00,'leveraged','worsening','Group gearing above target on projects and diagnostics drag'),
    ('Consolidated Group','GRP-CON-M06','2026-06-01','consolidated',
     905000000,785000000,768000000,258000000,1.18,3.04,3.70,1.10,-7.30,'leveraged','stable','Consolidated leverage flat; treasury monitoring covenants'),
    ('Consolidated Group','GRP-CON-M07','2026-07-01','consolidated',
     880000000,760000000,778000000,266000000,1.13,2.86,3.95,1.10,-2.70,'healthy','improving','Group deleveraging on collections; nearing target gearing'),
    ('Imaging Solutions BU','IMG-BU-M07','2026-07-01','diagnostics',
     175000000,150000000,95000000,40000000,1.84,3.75,2.10,1.30,-41.50,'stretched','worsening','CT/MRI install debt heavy; billing pending on new installs')
  ) as q(enm, ecode, pmon, bunit, tdebt, ndebt, eqty, ebit, de, nde, icov, tgear, hroom, sstat, tdir, nt);

  -- CAPA seed — attach to specific snapshots via entity_code
  insert into public.solvency_capa_actions_r3618 (
    solvency_log_id, finding_category, root_cause, corrective_action,
    capa_status, impact_category, target_closure_date, actual_closure_date,
    ebitda_impact_rupees, owner, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ic, q.tcd::date, q.acd::date,
    q.imp, q.ownr, q.nt
  from (values
    ('PRJ-BU-M05','gearing_above_target','capex_overrun','tighten_working_capital','in_progress','board_escalation','2026-06-15',null,12000000,'Group Treasury','Turnkey drawdowns; accelerate milestone billing to deleverage'),
    ('SPR-BU-M07','net_debt_ebitda_breach','working_capital_stretch','tighten_working_capital','open','covenant_breach','2026-08-10',null,6000000,'FP&A Lead','Trim import buffer stock to free up working capital'),
    ('DGN-BU-M06','interest_cover_thin','high_interest_cost','refinance_debt','escalated','lender_notifiable','2026-07-31',null,22000000,'CFO','Refinance high-cost lab-capex debt; lender covenant watch'),
    ('DGN-BU-M07','covenant_headroom_low','ebitda_shortfall','deleverage_asset_sale','in_progress','rating_watch','2026-08-20',null,18000000,'CFO','Asset-light pivot on idle analyzers; rating agency review'),
    ('RNT-BU-M06','debt_to_equity_high','ebitda_shortfall','cost_reduction','open','internal_only','2026-08-05',null,5000000,'BU Finance Head','Fleet utilization below breakeven; cut idle-unit cost'),
    ('GRP-CON-M05','gearing_above_target','delayed_receivables','accelerate_collections','closed','covenant_breach','2026-06-30','2026-06-28',30000000,'CFO','Group collections drive closed the covenant gap'),
    ('IMG-BU-M07','net_debt_ebitda_breach','capex_overrun','equity_infusion','open','board_escalation','2026-08-25',null,15000000,'CEO','CT/MRI install debt; promoter equity infusion planned'),
    ('PRJ-BU-M07','gearing_above_target','delayed_receivables','accelerate_collections','verification_pending','internal_only','2026-07-25',null,8000000,'FP&A Lead','Milestone collections landing; verify deleverage next month'),
    ('RNT-BU-M07','covenant_headroom_low','ebitda_shortfall','renegotiate_covenants','overdue','lender_notifiable','2026-07-15',null,7000000,'Group Treasury','Covenant reset talks slipped past target date')
  ) as q(ecode, fc, rc, ca, cst, ic, tcd, acd, imp, ownr, nt)
  join public.solvency_r3618 e
    on e.organization_id = v_org_id and e.entity_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Solvency status distribution
create or replace function public.founder_r3618_solvency_status_rollup()
returns table(solvency_status text, entities bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.solvency_r3618)
  select l.solvency_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.solvency_r3618 l
  group by l.solvency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3618_solvency_status_rollup() from public, anon;
grant execute on function public.founder_r3618_solvency_status_rollup() to authenticated;

-- 2) Entity solvency scorecard
create or replace function public.founder_r3618_entity_scorecard()
returns table(
  entity_name text,
  snapshots bigint,
  robust bigint,
  healthy bigint,
  leveraged bigint,
  stretched bigint,
  distressed bigint,
  avg_debt_to_equity numeric,
  avg_net_debt_to_ebitda numeric,
  avg_interest_coverage numeric,
  avg_gearing_headroom_pct numeric
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
    count(*) filter (where l.solvency_status = 'robust')::bigint,
    count(*) filter (where l.solvency_status = 'healthy')::bigint,
    count(*) filter (where l.solvency_status = 'leveraged')::bigint,
    count(*) filter (where l.solvency_status = 'stretched')::bigint,
    count(*) filter (where l.solvency_status = 'distressed')::bigint,
    round(avg(l.debt_to_equity_ratio), 2),
    round(avg(l.net_debt_to_ebitda_ratio), 2),
    round(avg(l.interest_coverage_ratio), 2),
    round(avg(l.gearing_headroom_pct), 2)
  from public.solvency_r3618 l
  group by l.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3618_entity_scorecard() from public, anon;
grant execute on function public.founder_r3618_entity_scorecard() to authenticated;

-- 3) Entity × solvency-status matrix
create or replace function public.founder_r3618_entity_status_matrix()
returns table(entity_name text, solvency_status text, snapshots bigint, avg_debt_to_equity numeric, avg_net_debt_to_ebitda numeric, avg_interest_coverage numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.solvency_status, count(*)::bigint,
    round(avg(l.debt_to_equity_ratio), 2),
    round(avg(l.net_debt_to_ebitda_ratio), 2),
    round(avg(l.interest_coverage_ratio), 2)
  from public.solvency_r3618 l
  group by l.entity_name, l.solvency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3618_entity_status_matrix() from public, anon;
grant execute on function public.founder_r3618_entity_status_matrix() to authenticated;

-- 4) Monthly gearing trend
create or replace function public.founder_r3618_monthly_gearing_trend()
returns table(period_month date, snapshots bigint, avg_debt_to_equity numeric, avg_net_debt_to_ebitda numeric, avg_interest_coverage numeric, stretched_distressed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.debt_to_equity_ratio), 2),
    round(avg(l.net_debt_to_ebitda_ratio), 2),
    round(avg(l.interest_coverage_ratio), 2),
    count(*) filter (where l.solvency_status in ('stretched','distressed'))::bigint
  from public.solvency_r3618 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3618_monthly_gearing_trend() from public, anon;
grant execute on function public.founder_r3618_monthly_gearing_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3618_capa_status_board()
returns table(capa_status text, findings bigint, avg_ebitda_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.ebitda_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.solvency_capa_actions_r3618 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3618_capa_status_board() from public, anon;
grant execute on function public.founder_r3618_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3618_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_ebitda_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.solvency_capa_actions_r3618)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.ebitda_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.solvency_capa_actions_r3618 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3618_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3618_root_cause_pareto() to authenticated;

-- 7) Leverage-impact digest
create or replace function public.founder_r3618_leverage_impact_digest()
returns table(impact_category text, findings bigint, open_findings bigint, total_ebitda_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.impact_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.ebitda_impact_rupees),0)::numeric
  from public.solvency_capa_actions_r3618 c
  group by c.impact_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3618_leverage_impact_digest() from public, anon;
grant execute on function public.founder_r3618_leverage_impact_digest() to authenticated;

-- 8) High-risk solvency queue (stretched / distressed)
create or replace function public.founder_r3618_high_risk_queue()
returns table(
  entity_name text,
  entity_code text,
  business_unit text,
  period_month date,
  solvency_status text,
  debt_to_equity_ratio numeric,
  net_debt_to_ebitda_ratio numeric,
  interest_coverage_ratio numeric,
  gearing_headroom_pct numeric,
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
  select l.entity_name, l.entity_code, l.business_unit, l.period_month, l.solvency_status,
    l.debt_to_equity_ratio, l.net_debt_to_ebitda_ratio, l.interest_coverage_ratio,
    l.gearing_headroom_pct, l.trend_dir, l.notes
  from public.solvency_r3618 l
  where l.solvency_status in ('stretched','distressed')
     or l.net_debt_to_ebitda_ratio >= 3.5
     or l.interest_coverage_ratio < 2.0
     or l.gearing_headroom_pct < 0
  order by l.period_month desc, l.entity_name;
end;
$$;

revoke execute on function public.founder_r3618_high_risk_queue() from public, anon;
grant execute on function public.founder_r3618_high_risk_queue() to authenticated;
