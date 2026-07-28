-- Round 3521: Founder Trade-Receivables Factoring / Bill-Discounting Board
-- Trade-receivables factoring / bill-discounting utilization + cost + recourse risk —
-- financier × facility type × advance rate × discount charge × effective cost × tenor ×
-- recourse × status × monthly utilization × CAPA closure

-- =============================================================================
-- TABLE 1: receivables_factoring_r3521 — per-deal factoring / bill-discounting facts
-- =============================================================================
create table if not exists public.receivables_factoring_r3521 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  deal_ref text not null,
  financier text not null,
  facility_type text not null check (facility_type in (
    'factoring','bill_discounting','invoice_financing','reverse_factoring','treds'
  )),
  invoice_value_rupees numeric(14,2) not null,
  advance_rupees numeric(14,2) not null,
  advance_rate_pct numeric(5,2),
  discount_charge_rupees numeric(14,2),
  effective_cost_pct numeric(5,2),
  tenor_days int,
  recourse text not null check (recourse in (
    'with_recourse','without_recourse'
  )),
  status text not null check (status in (
    'active','settled','overdue','recourse_triggered','disputed'
  )),
  period_month date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.receivables_factoring_r3521 enable row level security;

create index if not exists idx_receivables_factoring_r3521_org on public.receivables_factoring_r3521(organization_id);
create index if not exists idx_receivables_factoring_r3521_month on public.receivables_factoring_r3521(period_month);
create index if not exists idx_receivables_factoring_r3521_status on public.receivables_factoring_r3521(status);

-- =============================================================================
-- TABLE 2: receivables_factoring_capa_actions_r3521 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.receivables_factoring_capa_actions_r3521 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  deal_ref text not null,
  finding_category text not null check (finding_category in (
    'high_effective_cost','overdue_settlement','recourse_triggered','disputed_invoice',
    'concentration_risk','advance_rate_shortfall','documentation_gap','covenant_breach'
  )),
  root_cause text not null check (root_cause in (
    'customer_payment_delay','financier_rate_hike','invoice_dispute','buyer_credit_deterioration',
    'over_reliance_single_financier','weak_credit_policy','documentation_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_rate','diversify_financiers','tighten_credit_policy','escalate_collection',
    'switch_to_without_recourse','resolve_dispute','improve_documentation','none_required'
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

alter table public.receivables_factoring_capa_actions_r3521 enable row level security;

create index if not exists idx_receivables_factoring_capa_r3521_org on public.receivables_factoring_capa_actions_r3521(organization_id);
create index if not exists idx_receivables_factoring_capa_r3521_status on public.receivables_factoring_capa_actions_r3521(capa_status);

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

  -- 16 deal rows
  insert into public.receivables_factoring_r3521 (
    organization_id, deal_ref, financier, facility_type, invoice_value_rupees, advance_rupees,
    advance_rate_pct, discount_charge_rupees, effective_cost_pct, tenor_days, recourse, status,
    period_month, notes
  )
  select v_org_id, q.dref, q.fin, q.ftype, q.ival, q.adv,
    q.arate, q.dchg, q.ecost, q.tenor, q.rec, q.stat,
    q.pmon::date, q.nt
  from (values
    ('FAC-2026-001','SBI Global Factors','factoring',1250000.00,1000000.00,
     80.0,28750.00,11.5,90,'with_recourse','active','2026-07-01','Domestic factoring against pharma distributor invoices'),
    ('BD-2026-014','HDFC Bank','bill_discounting',850000.00,807500.00,
     95.0,14025.00,9.9,60,'with_recourse','settled','2026-07-01','LC-backed bill discounting settled on due date'),
    ('INV-2026-032','Tata Capital','invoice_financing',600000.00,480000.00,
     80.0,19800.00,13.4,75,'with_recourse','active','2026-06-01','Invoice financing for hospital equipment supply'),
    ('RF-2026-008','ICICI Bank','reverse_factoring',2100000.00,2079000.00,
     99.0,25200.00,7.2,45,'without_recourse','settled','2026-06-01','Reverse factoring anchor-led programme — OEM supplier'),
    ('TR-2026-051','RXIL TReDS','treds',450000.00,441000.00,
     98.0,5512.00,8.1,55,'without_recourse','active','2026-07-01','TReDS auction bill discounted at competitive rate'),
    ('FAC-2026-002','Canbank Factors','factoring',980000.00,735000.00,
     75.0,34300.00,15.8,120,'with_recourse','overdue','2026-05-01','Overdue — buyer payment delayed beyond tenor'),
    ('BD-2026-019','Yes Bank','bill_discounting',720000.00,684000.00,
     95.0,17640.00,14.7,70,'with_recourse','recourse_triggered','2026-05-01','Recourse triggered — drawee dishonoured bill'),
    ('INV-2026-040','IFCI Factors','invoice_financing',1500000.00,1200000.00,
     80.0,52500.00,16.2,110,'with_recourse','disputed','2026-06-01','Disputed invoice — quality claim raised by buyer'),
    ('TR-2026-062','M1xchange','treds',380000.00,372400.00,
     98.0,4560.00,7.6,50,'without_recourse','settled','2026-07-01','TReDS financed and auto-settled T+2'),
    ('RF-2026-011','Kotak Mahindra Bank','reverse_factoring',1750000.00,1732500.00,
     99.0,21000.00,7.5,48,'without_recourse','active','2026-07-01','Anchor reverse factoring — auto medical devices'),
    ('FAC-2026-003','SBI Global Factors','factoring',1100000.00,880000.00,
     80.0,38500.00,14.2,105,'with_recourse','active','2026-06-01','Export factoring vs consumables importer'),
    ('BD-2026-024','Axis Bank','bill_discounting',640000.00,608000.00,
     95.0,11200.00,10.8,58,'with_recourse','settled','2026-06-01','Clean bill discounting settled'),
    ('INV-2026-047','Bibby Financial','invoice_financing',520000.00,416000.00,
     80.0,18720.00,17.5,95,'with_recourse','overdue','2026-05-01','High-cost invoice financing overdue — collection escalated'),
    ('TR-2026-070','RXIL TReDS','treds',410000.00,401800.00,
     98.0,4920.00,7.9,52,'without_recourse','active','2026-07-01','TReDS discounting active — MSME supplier'),
    ('RF-2026-015','ICICI Bank','reverse_factoring',2300000.00,2277000.00,
     99.0,27600.00,7.1,44,'without_recourse','settled','2026-06-01','Reverse factoring settled early — anchor programme'),
    ('FAC-2026-004','Canbank Factors','factoring',870000.00,652500.00,
     75.0,30450.00,16.9,115,'with_recourse','recourse_triggered','2026-05-01','Recourse invoked — buyer insolvency signal')
  ) as q(dref, fin, ftype, ival, adv, arate, dchg, ecost, tenor, rec, stat, pmon, nt);

  -- CAPA seed — org-scoped, linked to deals via deal_ref
  insert into public.receivables_factoring_capa_actions_r3521 (
    organization_id, deal_ref, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, q.dref, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('FAC-2026-002','overdue_settlement','customer_payment_delay','escalate_collection','in_progress',34300.00,'Priya Nair','2026-07-20',null,'Buyer payment chased — DSO breach; recourse risk building'),
    ('BD-2026-019','recourse_triggered','buyer_credit_deterioration','switch_to_without_recourse','open',17640.00,'Rahul Menon','2026-07-25',null,'Drawee dishonour — negotiating without-recourse facility'),
    ('INV-2026-040','disputed_invoice','invoice_dispute','resolve_dispute','escalated',52500.00,'Anita Desai','2026-07-18',null,'Quality claim under arbitration — high exposure'),
    ('INV-2026-047','high_effective_cost','financier_rate_hike','renegotiate_rate','open',18720.00,'Vikram Shah','2026-07-30',null,'17.5% effective cost — renegotiate or migrate to TReDS'),
    ('FAC-2026-004','recourse_triggered','buyer_credit_deterioration','escalate_collection','overdue',30450.00,'Priya Nair','2026-07-15',null,'Buyer insolvency signal — recourse invoked, legal notice served'),
    ('INV-2026-032','high_effective_cost','over_reliance_single_financier','diversify_financiers','verification_pending',19800.00,'Sanjay Rao','2026-07-22',null,'Concentration on Tata Capital — onboarding second financier'),
    ('FAC-2026-003','concentration_risk','over_reliance_single_financier','diversify_financiers','closed',38500.00,'Sanjay Rao','2026-06-28','2026-06-25','SBI concentration reduced via RXIL TReDS onboarding'),
    ('BD-2026-024','documentation_gap','documentation_error','improve_documentation','closed',11200.00,'Meera Iyer','2026-06-20','2026-06-18','Bill documentation checklist tightened — CAPA closed')
  ) as q(dref, fc, rc, ca, cst, imp, ownr, tcd, acd, nt);
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Status distribution
create or replace function public.founder_r3521_status_rollup()
returns table(status text, deals bigint, total_invoice_value_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.receivables_factoring_r3521)
  select l.status, count(*)::bigint,
         coalesce(sum(l.invoice_value_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.receivables_factoring_r3521 l
  group by l.status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3521_status_rollup() from public, anon;
grant execute on function public.founder_r3521_status_rollup() to authenticated;

-- 2) Facility-type scorecard
create or replace function public.founder_r3521_facility_type_scorecard()
returns table(
  facility_type text,
  deals bigint,
  total_invoice_value_rupees numeric,
  total_advance_rupees numeric,
  total_discount_charge_rupees numeric,
  avg_advance_rate_pct numeric,
  avg_effective_cost_pct numeric,
  avg_tenor_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.facility_type,
    count(*)::bigint,
    coalesce(sum(l.invoice_value_rupees),0)::numeric,
    coalesce(sum(l.advance_rupees),0)::numeric,
    coalesce(sum(l.discount_charge_rupees),0)::numeric,
    round(avg(l.advance_rate_pct), 2),
    round(avg(l.effective_cost_pct), 2),
    round(avg(l.tenor_days), 1)
  from public.receivables_factoring_r3521 l
  group by l.facility_type
  order by coalesce(sum(l.invoice_value_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3521_facility_type_scorecard() from public, anon;
grant execute on function public.founder_r3521_facility_type_scorecard() to authenticated;

-- 3) Facility-type × status matrix
create or replace function public.founder_r3521_facility_type_status_matrix()
returns table(
  facility_type text,
  status text,
  deals bigint,
  total_invoice_value_rupees numeric,
  total_discount_charge_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.facility_type, l.status, count(*)::bigint,
    coalesce(sum(l.invoice_value_rupees),0)::numeric,
    coalesce(sum(l.discount_charge_rupees),0)::numeric
  from public.receivables_factoring_r3521 l
  group by l.facility_type, l.status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3521_facility_type_status_matrix() from public, anon;
grant execute on function public.founder_r3521_facility_type_status_matrix() to authenticated;

-- 4) Monthly utilization trend
create or replace function public.founder_r3521_monthly_utilization_trend()
returns table(
  period_month date,
  deals bigint,
  total_invoice_value_rupees numeric,
  total_advance_rupees numeric,
  total_discount_charge_rupees numeric,
  avg_effective_cost_pct numeric
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
    coalesce(sum(l.invoice_value_rupees),0)::numeric,
    coalesce(sum(l.advance_rupees),0)::numeric,
    coalesce(sum(l.discount_charge_rupees),0)::numeric,
    round(avg(l.effective_cost_pct), 2)
  from public.receivables_factoring_r3521 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3521_monthly_utilization_trend() from public, anon;
grant execute on function public.founder_r3521_monthly_utilization_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3521_capa_status_board()
returns table(capa_status text, findings bigint, total_impact_rupees numeric, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(avg(c.impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.receivables_factoring_capa_actions_r3521 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3521_capa_status_board() from public, anon;
grant execute on function public.founder_r3521_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3521_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.receivables_factoring_capa_actions_r3521)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.receivables_factoring_capa_actions_r3521 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3521_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3521_root_cause_pareto() to authenticated;

-- 7) Cost-impact digest by finding category
create or replace function public.founder_r3521_cost_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_impact_rupees numeric, avg_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(avg(c.impact_rupees)::numeric, 0)
  from public.receivables_factoring_capa_actions_r3521 c
  group by c.finding_category
  order by coalesce(sum(c.impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3521_cost_impact_digest() from public, anon;
grant execute on function public.founder_r3521_cost_impact_digest() to authenticated;

-- 8) High-risk deal queue (overdue / recourse-triggered / disputed / high-cost)
create or replace function public.founder_r3521_high_risk_queue()
returns table(
  financier text,
  deal_ref text,
  facility_type text,
  status text,
  recourse text,
  period_month date,
  invoice_value_rupees numeric,
  effective_cost_pct numeric,
  tenor_days int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.financier, l.deal_ref, l.facility_type, l.status, l.recourse, l.period_month,
    l.invoice_value_rupees, l.effective_cost_pct, l.tenor_days, l.notes
  from public.receivables_factoring_r3521 l
  where l.status in ('overdue','recourse_triggered','disputed')
     or l.effective_cost_pct >= 14
  order by l.effective_cost_pct desc nulls last, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3521_high_risk_queue() from public, anon;
grant execute on function public.founder_r3521_high_risk_queue() to authenticated;
