-- Round 3333: Founder Trade-Payables, Vendor-Payment Aging & Days-Payable-Outstanding (DPO) Board
-- Working-capital governance — vendor category × payment verdict × aging buckets × DPO × early-pay discount × dispute holds × CAPA

-- =============================================================================
-- TABLE 1: trade_payables_r3333 — per vendor/period trade-payables aging line
-- =============================================================================
create table if not exists public.trade_payables_r3333 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  vendor_name text not null,
  vendor_category text not null check (vendor_category in (
    'spare_parts_oem','logistics','it_saas','professional_services','utilities','subcontractor','office_admin'
  )),
  as_of_date date not null,
  outstanding_rupees numeric not null,
  current_0_30_rupees numeric not null default 0,
  overdue_31_60_rupees numeric not null default 0,
  overdue_61_90_rupees numeric not null default 0,
  overdue_over_90_rupees numeric not null default 0,
  credit_terms_days int not null,
  dpo_days numeric not null,
  early_pay_discount_available boolean not null default false,
  discount_captured boolean not null default false,
  on_hold_dispute boolean not null default false,
  criticality text not null check (criticality in (
    'critical_supply','important','routine'
  )),
  payment_verdict text not null check (payment_verdict in (
    'pay_on_schedule','capture_early_discount','negotiate_terms','release_hold','overdue_pay_now','dispute_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.trade_payables_r3333 enable row level security;

create index if not exists idx_trade_payables_r3333_org on public.trade_payables_r3333(organization_id);
create index if not exists idx_trade_payables_r3333_date on public.trade_payables_r3333(as_of_date);
create index if not exists idx_trade_payables_r3333_verdict on public.trade_payables_r3333(payment_verdict);

-- =============================================================================
-- TABLE 2: trade_payables_capa_actions_r3333 — payment / dispute / discount actions
-- =============================================================================
create table if not exists public.trade_payables_capa_actions_r3333 (
  id uuid primary key default gen_random_uuid(),
  payable_id uuid not null references public.trade_payables_r3333(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'payment_delay','invoice_dispute','discount_missed','terms_renegotiation','over_90_aging','duplicate_invoice','credit_hold','gst_mismatch'
  )),
  root_cause text not null check (root_cause in (
    'cash_flow_constraint','pricing_dispute','goods_not_received','approval_bottleneck',
    'vendor_documentation_error','system_posting_delay','contract_terms_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'schedule_payment','release_payment','capture_discount','renegotiate_terms',
    'resolve_dispute','request_credit_note','escalate_finance','place_on_hold','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  risk_impact text not null check (risk_impact in (
    'supply_disruption_risk','discount_forfeit_risk','late_fee_risk','vendor_relationship_risk','dispute_exposure','none','routine'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_amount_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.trade_payables_capa_actions_r3333 enable row level security;

create index if not exists idx_trade_payables_capa_r3333_payable on public.trade_payables_capa_actions_r3333(payable_id);
create index if not exists idx_trade_payables_capa_r3333_status on public.trade_payables_capa_actions_r3333(capa_status);

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

  -- 14 trade-payables aging rows
  insert into public.trade_payables_r3333 (
    organization_id, vendor_name, vendor_category, as_of_date,
    outstanding_rupees, current_0_30_rupees, overdue_31_60_rupees, overdue_61_90_rupees, overdue_over_90_rupees,
    credit_terms_days, dpo_days, early_pay_discount_available, discount_captured, on_hold_dispute,
    criticality, payment_verdict, notes
  )
  select v_org_id, q.vname, q.vcat, q.asof::date,
    q.outr, q.cur, q.od1, q.od2, q.od3,
    q.terms, q.dpo, q.disc_av, q.disc_cap, q.hold,
    q.crit, q.verd, q.nt
  from (values
    ('GE Healthcare India Spares Pvt Ltd','spare_parts_oem','2026-07-15',
     1250000,800000,300000,150000,0,45,38.5,true,true,false,
     'critical_supply','pay_on_schedule','2% early-pay discount captured on imaging spares batch'),
    ('Siemens Healthineers Spare Parts','spare_parts_oem','2026-07-15',
     2100000,900000,500000,400000,300000,60,72.0,true,false,false,
     'critical_supply','capture_early_discount','1.5% discount window open till month-end on CT tubes'),
    ('Blue Dart Express Ltd','logistics','2026-07-15',
     480000,480000,0,0,0,30,22.0,false,false,false,
     'important','pay_on_schedule','Courier billing current — within 30-day terms'),
    ('VRL Logistics Ltd','logistics','2026-06-30',
     360000,120000,90000,90000,60000,30,58.0,false,false,true,
     'important','dispute_review','Damaged-consignment claim under dispute — 3 LRs contested'),
    ('Freshworks Technologies (SaaS)','it_saas','2026-07-15',
     220000,220000,0,0,0,15,12.0,true,true,false,
     'routine','pay_on_schedule','Annual CRM subscription — auto-debit discount taken'),
    ('Amazon Web Services India','it_saas','2026-06-30',
     540000,300000,240000,0,0,30,41.0,false,false,false,
     'important','overdue_pay_now','Cloud hosting 31-60 bucket rising — clear to avoid throttling'),
    ('Lakshmikumaran and Sridharan Attorneys','professional_services','2026-05-31',
     310000,0,0,110000,200000,30,96.0,false,false,true,
     'routine','dispute_review','Retainer invoice scope contested — over-90 exposure'),
    ('Deloitte Haskins and Sells LLP','professional_services','2026-06-30',
     650000,400000,250000,0,0,45,40.0,true,false,false,
     'important','capture_early_discount','Statutory-audit fee — early settlement rebate offered'),
    ('Tata Power Mumbai','utilities','2026-07-15',
     145000,145000,0,0,0,15,10.0,false,false,false,
     'critical_supply','pay_on_schedule','Facility power bill — current, never overdue'),
    ('Bharti Airtel Business','utilities','2026-06-30',
     98000,40000,30000,28000,0,15,46.0,false,false,false,
     'routine','overdue_pay_now','Enterprise connectivity — 46-day DPO past 15-day terms'),
    ('Kaveri Biomedical Services','subcontractor','2026-07-15',
     780000,300000,200000,180000,100000,45,66.0,false,false,true,
     'critical_supply','negotiate_terms','Field-service subcontractor — renegotiating volume rate and terms'),
    ('Sri Venkateswara Engineering Works','subcontractor','2026-05-31',
     420000,0,100000,120000,200000,45,108.0,false,false,false,
     'important','overdue_pay_now','Fabrication subcontractor — over-90 balance, expedite payment'),
    ('Om Sai Facility and Housekeeping','office_admin','2026-07-15',
     76000,76000,0,0,0,30,18.0,false,false,false,
     'routine','pay_on_schedule','Office housekeeping AMC — current'),
    ('Reliable Stationers and Print','office_admin','2026-04-30',
     54000,0,0,0,54000,30,152.0,false,false,true,
     'routine','release_hold','Small over-90 balance held pending GST invoice correction — now resolved')
  ) as q(vname, vcat, asof, outr, cur, od1, od2, od3, terms, dpo, disc_av, disc_cap, hold, crit, verd, nt);

  -- CAPA seed — attach to specific payables via vendor_name
  insert into public.trade_payables_capa_actions_r3333 (
    payable_id, finding_category, root_cause, corrective_action,
    capa_status, risk_impact, target_closure_date, actual_closure_date,
    estimated_amount_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.amt, q.nt
  from (values
    ('Siemens Healthineers Spare Parts','discount_missed','contract_terms_gap','capture_discount','in_progress','discount_forfeit_risk','2026-07-31',null,31500.00,'Capture 1.5% early-pay on CT-tube invoice before window closes'),
    ('VRL Logistics Ltd','invoice_dispute','pricing_dispute','resolve_dispute','open','dispute_exposure','2026-07-25',null,60000.00,'Damaged-consignment claim — reconcile 3 LRs with vendor'),
    ('Amazon Web Services India','payment_delay','approval_bottleneck','schedule_payment','escalated','late_fee_risk','2026-07-20',null,240000.00,'31-60 bucket rising — escalate to CFO for immediate release'),
    ('Lakshmikumaran and Sridharan Attorneys','over_90_aging','pricing_dispute','request_credit_note','verification_pending','dispute_exposure','2026-07-28',null,200000.00,'Contest retainer scope — credit note requested for over-90 balance'),
    ('Kaveri Biomedical Services','terms_renegotiation','cash_flow_constraint','renegotiate_terms','in_progress','supply_disruption_risk','2026-08-05',null,480000.00,'Renegotiate volume rate and extend terms to 60 days — critical field vendor'),
    ('Sri Venkateswara Engineering Works','over_90_aging','cash_flow_constraint','schedule_payment','overdue','vendor_relationship_risk','2026-07-10',null,320000.00,'Over-90 fabrication balance — payment plan past due, expedite'),
    ('Reliable Stationers and Print','credit_hold','vendor_documentation_error','release_payment','closed','none','2026-07-05','2026-07-16',54000.00,'GST invoice corrected — hold released and paid')
  ) as q(vname, fc, rc, ca, cst, ri, tcd, acd, amt, nt)
  join public.trade_payables_r3333 e
    on e.organization_id = v_org_id and e.vendor_name = q.vname;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Payment verdict distribution
create or replace function public.founder_r3333_payment_verdict_rollup()
returns table(payment_verdict text, vendors bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.trade_payables_r3333)
  select l.payment_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.trade_payables_r3333 l
  group by l.payment_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3333_payment_verdict_rollup() from public, anon;
grant execute on function public.founder_r3333_payment_verdict_rollup() to authenticated;

-- 2) Vendor-category payables scorecard
create or replace function public.founder_r3333_vendor_category_scorecard()
returns table(
  vendor_category text,
  total_lines bigint,
  outstanding_total_rupees numeric,
  over_90_total_rupees numeric,
  on_hold_count bigint,
  discount_available_count bigint,
  discount_captured_count bigint,
  avg_dpo_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_category,
    count(*)::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    coalesce(sum(l.overdue_over_90_rupees),0)::numeric,
    count(*) filter (where l.on_hold_dispute)::bigint,
    count(*) filter (where l.early_pay_discount_available)::bigint,
    count(*) filter (where l.discount_captured)::bigint,
    round(avg(l.dpo_days), 1)
  from public.trade_payables_r3333 l
  group by l.vendor_category
  order by coalesce(sum(l.outstanding_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3333_vendor_category_scorecard() from public, anon;
grant execute on function public.founder_r3333_vendor_category_scorecard() to authenticated;

-- 3) Vendor category × criticality matrix
create or replace function public.founder_r3333_category_criticality_matrix()
returns table(vendor_category text, criticality text, vendors bigint, outstanding_total_rupees numeric, over_90_total_rupees numeric, avg_dpo_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_category, l.criticality, count(*)::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    coalesce(sum(l.overdue_over_90_rupees),0)::numeric,
    round(avg(l.dpo_days), 1)
  from public.trade_payables_r3333 l
  group by l.vendor_category, l.criticality
  order by coalesce(sum(l.outstanding_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3333_category_criticality_matrix() from public, anon;
grant execute on function public.founder_r3333_category_criticality_matrix() to authenticated;

-- 4) Payables aging trend by period date
create or replace function public.founder_r3333_payables_aging_trend()
returns table(as_of_date date, lines bigint, outstanding_total_rupees numeric, over_90_total_rupees numeric, on_hold_count bigint, avg_dpo_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.as_of_date,
    count(*)::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    coalesce(sum(l.overdue_over_90_rupees),0)::numeric,
    count(*) filter (where l.on_hold_dispute)::bigint,
    round(avg(l.dpo_days), 1)
  from public.trade_payables_r3333 l
  group by l.as_of_date
  order by l.as_of_date desc;
end;
$$;

revoke execute on function public.founder_r3333_payables_aging_trend() from public, anon;
grant execute on function public.founder_r3333_payables_aging_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3333_capa_status_board()
returns table(capa_status text, findings bigint, avg_amount_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.trade_payables_capa_actions_r3333 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3333_capa_status_board() from public, anon;
grant execute on function public.founder_r3333_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3333_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_amount_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.trade_payables_capa_actions_r3333)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.trade_payables_capa_actions_r3333 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3333_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3333_root_cause_pareto() to authenticated;

-- 7) Risk / cash impact digest
create or replace function public.founder_r3333_risk_impact_digest()
returns table(risk_impact text, findings bigint, open_findings bigint, total_amount_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.risk_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_amount_rupees),0)::numeric
  from public.trade_payables_capa_actions_r3333 c
  group by c.risk_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3333_risk_impact_digest() from public, anon;
grant execute on function public.founder_r3333_risk_impact_digest() to authenticated;

-- 8) High-risk payables queue (top individual concerns)
create or replace function public.founder_r3333_high_risk_queue()
returns table(
  vendor_name text,
  vendor_category text,
  criticality text,
  as_of_date date,
  payment_verdict text,
  outstanding_rupees numeric,
  overdue_over_90_rupees numeric,
  dpo_days numeric,
  on_hold_dispute boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name, l.vendor_category, l.criticality, l.as_of_date,
    l.payment_verdict, l.outstanding_rupees, l.overdue_over_90_rupees, l.dpo_days,
    l.on_hold_dispute, l.notes
  from public.trade_payables_r3333 l
  where l.payment_verdict in ('negotiate_terms','overdue_pay_now','dispute_review','release_hold')
     or l.on_hold_dispute
     or l.overdue_over_90_rupees > 0
     or l.dpo_days > l.credit_terms_days
  order by l.overdue_over_90_rupees desc, l.dpo_days desc, l.vendor_name;
end;
$$;

revoke execute on function public.founder_r3333_high_risk_queue() from public, anon;
grant execute on function public.founder_r3333_high_risk_queue() to authenticated;
