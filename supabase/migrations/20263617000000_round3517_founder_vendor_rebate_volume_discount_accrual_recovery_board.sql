-- Round 3517: Founder Vendor-Rebate / Volume-Discount Accrual & Recovery Board
-- Vendor rebate / volume-discount accrual + recovery vs earned per supplier tier —
-- rebate type × recovery status × YTD purchase × threshold × earned/accrued/received × gap × attainment × CAPA

-- =============================================================================
-- TABLE 1: vendor_rebate_accrual_r3517 — per-program rebate accrual & recovery
-- =============================================================================
create table if not exists public.vendor_rebate_accrual_r3517 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_name text not null,
  program_code text not null,
  rebate_program text not null,
  rebate_type text not null check (rebate_type in (
    'volume_tier','early_payment','loyalty','growth','marketing_coop','mix'
  )),
  ytd_purchase_rupees numeric(14,2),
  threshold_rupees numeric(14,2),
  earned_rebate_rupees numeric(14,2),
  accrued_rupees numeric(14,2),
  received_rupees numeric(14,2),
  gap_rupees numeric(14,2),
  attainment_pct numeric(6,2),
  recovery_status text not null check (recovery_status in (
    'on_track','at_risk','shortfall','fully_recovered','disputed'
  )),
  period_month date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_rebate_accrual_r3517 enable row level security;

create index if not exists idx_vendor_rebate_accrual_r3517_org on public.vendor_rebate_accrual_r3517(organization_id);
create index if not exists idx_vendor_rebate_accrual_r3517_month on public.vendor_rebate_accrual_r3517(period_month);
create index if not exists idx_vendor_rebate_accrual_r3517_status on public.vendor_rebate_accrual_r3517(recovery_status);

-- =============================================================================
-- TABLE 2: vendor_rebate_accrual_capa_actions_r3517 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.vendor_rebate_accrual_capa_actions_r3517 (
  id uuid primary key default gen_random_uuid(),
  accrual_id uuid not null references public.vendor_rebate_accrual_r3517(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'accrual_gap','threshold_miss','underclaimed_rebate','pricing_mismatch','missing_credit_note',
    'late_claim_submission','tier_slippage','disputed_rebate','contract_terms_unclear','forecast_shortfall'
  )),
  root_cause text not null check (root_cause in (
    'purchase_volume_below_forecast','claim_not_submitted','supplier_credit_delayed','contract_tier_misread',
    'pricing_data_error','po_split_across_entities','rebate_terms_ambiguous','early_payment_missed',
    'marketing_proof_missing','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'submit_rebate_claim','escalate_to_supplier','consolidate_purchase_volume','renegotiate_tier',
    'correct_pricing_master','reconcile_credit_notes','accelerate_payment_terms','submit_marketing_proof',
    'dispute_resolution_meeting','write_off_gap','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  owner text,
  recovery_amount_rupees numeric(14,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_rebate_accrual_capa_actions_r3517 enable row level security;

create index if not exists idx_vendor_rebate_capa_r3517_accrual on public.vendor_rebate_accrual_capa_actions_r3517(accrual_id);
create index if not exists idx_vendor_rebate_capa_r3517_status on public.vendor_rebate_accrual_capa_actions_r3517(capa_status);

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

  -- 16 rebate-accrual rows
  insert into public.vendor_rebate_accrual_r3517 (
    organization_id, supplier_name, program_code, rebate_program, rebate_type,
    ytd_purchase_rupees, threshold_rupees, earned_rebate_rupees, accrued_rupees, received_rupees,
    gap_rupees, attainment_pct, recovery_status, period_month, notes
  )
  select v_org_id, q.sup, q.pcode, q.prog, q.rtype,
    q.ytd, q.thr, q.earn, q.accr, q.recv,
    q.gap, q.att, q.rstat, q.pm::date, q.nt
  from (values
    ('GE Healthcare India','GEHC-VT-2607','Q3 Imaging Volume Tier','volume_tier',
     42000000,40000000,2100000,2100000,2100000,0,105.0,'fully_recovered','2026-07-01','CT/MRI volume tier crossed — full rebate credited'),
    ('Philips India','PHIL-EP-2607','Early Payment Discount','early_payment',
     28000000,25000000,840000,840000,560000,280000,112.0,'on_track','2026-07-01','Early-payment discounts mostly captured; one invoice cycle pending'),
    ('Siemens Healthineers','SIEM-GR-2607','Growth Incentive FY26','growth',
     31000000,35000000,1550000,1550000,0,1550000,88.6,'at_risk','2026-07-01','Growth target trailing — Q4 pull-in needed to earn full slab'),
    ('Mindray India','MIND-VT-2606','Monitors Volume Slab','volume_tier',
     9500000,15000000,0,0,0,950000,63.3,'shortfall','2026-06-01','Patient-monitor volume well below slab — likely miss'),
    ('Trivitron Healthcare','TRIV-LOY-2606','Loyalty Reagent Rebate','loyalty',
     18000000,16000000,720000,720000,720000,0,112.5,'fully_recovered','2026-06-01','Reagent loyalty rebate fully received'),
    ('BPL Medical','BPL-MIX-2606','Mixed Basket Rebate','mix',
     12000000,12000000,360000,360000,180000,180000,100.0,'on_track','2026-06-01','Mixed-basket rebate at threshold; half credited'),
    ('Nihon Kohden India','NKI-MC-2607','Marketing Co-op Fund','marketing_coop',
     7000000,6000000,350000,350000,0,350000,116.7,'disputed','2026-07-01','Co-op proof-of-spend rejected by supplier — under dispute'),
    ('Drager India','DRAG-VT-2605','Anaesthesia Volume Tier','volume_tier',
     22000000,20000000,1100000,1100000,1100000,0,110.0,'fully_recovered','2026-05-01','Anaesthesia workstation tier fully credited'),
    ('Medtronic India','MDT-GR-2607','Cardiac Growth Slab','growth',
     26000000,30000000,1300000,900000,0,1300000,86.7,'at_risk','2026-07-01','Cardiac consumable growth slab at risk; accrual partial'),
    ('Fresenius India','FRES-LOY-2606','Dialysis Loyalty Rebate','loyalty',
     14000000,18000000,0,0,0,700000,77.8,'shortfall','2026-06-01','Dialysis consumable loyalty target trailing badly'),
    ('Wipro GE','WGE-EP-2607','Early Settlement Rebate','early_payment',
     33000000,30000000,990000,990000,990000,0,110.0,'fully_recovered','2026-07-01','Early settlement rebate fully realised'),
    ('Skanray Technologies','SKAN-MIX-2605','Mixed Equipment Rebate','mix',
     8000000,10000000,0,0,0,400000,80.0,'at_risk','2026-05-01','Mixed equipment spend below plan; borderline'),
    ('BD India','BD-VT-2606','Consumables Volume Tier','volume_tier',
     19000000,18000000,760000,760000,380000,380000,105.6,'on_track','2026-06-01','Consumables tier earned; half received'),
    ('Allengers Medical','ALLN-MC-2607','X-ray Co-op Marketing','marketing_coop',
     5500000,5000000,275000,275000,0,275000,110.0,'disputed','2026-07-01','X-ray co-op claim disputed — invoice mismatch'),
    ('Nihon Kohden India','NKI-GR-2605','Neuro Growth Incentive','growth',
     11000000,14000000,0,0,0,550000,78.6,'shortfall','2026-05-01','Neuro monitor growth incentive shortfall'),
    ('Siemens Healthineers','SIEM-LOY-2606','Lab Loyalty Rebate','loyalty',
     24000000,22000000,960000,960000,960000,0,109.1,'fully_recovered','2026-06-01','Lab reagent loyalty rebate fully credited')
  ) as q(sup, pcode, prog, rtype, ytd, thr, earn, accr, recv, gap, att, rstat, pm, nt);

  -- CAPA seed — attach to specific programs via program_code
  insert into public.vendor_rebate_accrual_capa_actions_r3517 (
    accrual_id, finding_category, root_cause, corrective_action,
    capa_status, owner, recovery_amount_rupees, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.own, q.amt, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SIEM-GR-2607','forecast_shortfall','purchase_volume_below_forecast','consolidate_purchase_volume','in_progress','Procurement - Imaging',1550000,'2026-08-15',null,'Pull-in Q4 imaging POs to close growth slab'),
    ('MIND-VT-2606','threshold_miss','purchase_volume_below_forecast','renegotiate_tier','open','Category Lead - Monitoring',950000,'2026-08-10',null,'Monitor volume short; renegotiate lower slab with Mindray'),
    ('NKI-MC-2607','disputed_rebate','marketing_proof_missing','submit_marketing_proof','escalated','Marketing Ops',350000,'2026-08-05',null,'Resubmit co-op proof-of-spend; escalate to Nihon Kohden KAM'),
    ('MDT-GR-2607','forecast_shortfall','purchase_volume_below_forecast','consolidate_purchase_volume','in_progress','Procurement - Cardiac',1300000,'2026-08-20',null,'Consolidate cardiac consumable spend to hit growth slab'),
    ('FRES-LOY-2606','threshold_miss','purchase_volume_below_forecast','renegotiate_tier','open','Category Lead - Renal',700000,'2026-08-12',null,'Dialysis loyalty target unreachable; renegotiate terms'),
    ('ALLN-MC-2607','disputed_rebate','pricing_data_error','dispute_resolution_meeting','escalated','Finance - AP',275000,'2026-08-08',null,'Invoice mismatch on X-ray co-op; schedule dispute meeting'),
    ('PHIL-EP-2607','late_claim_submission','claim_not_submitted','submit_rebate_claim','verification_pending','Finance - AP',280000,'2026-07-25',null,'Early-payment claim filed; awaiting Philips credit note'),
    ('NKI-GR-2605','accrual_gap','purchase_volume_below_forecast','write_off_gap','closed','Procurement - Neuro',550000,'2026-07-20','2026-07-18','Neuro growth slab missed; gap written off after review')
  ) as q(pcode, fc, rc, ca, cst, own, amt, tcd, acd, nt)
  join public.vendor_rebate_accrual_r3517 e
    on e.organization_id = v_org_id and e.program_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Recovery-status distribution
create or replace function public.founder_r3517_recovery_status_rollup()
returns table(recovery_status text, programs bigint, total_gap_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_rebate_accrual_r3517)
  select l.recovery_status, count(*)::bigint,
         coalesce(sum(l.gap_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.vendor_rebate_accrual_r3517 l
  group by l.recovery_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3517_recovery_status_rollup() from public, anon;
grant execute on function public.founder_r3517_recovery_status_rollup() to authenticated;

-- 2) Rebate-type scorecard
create or replace function public.founder_r3517_rebate_type_scorecard()
returns table(
  rebate_type text,
  programs bigint,
  total_ytd_purchase_rupees numeric,
  total_earned_rupees numeric,
  total_accrued_rupees numeric,
  total_received_rupees numeric,
  total_gap_rupees numeric,
  avg_attainment_pct numeric,
  shortfall_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.rebate_type,
    count(*)::bigint,
    coalesce(sum(l.ytd_purchase_rupees),0)::numeric,
    coalesce(sum(l.earned_rebate_rupees),0)::numeric,
    coalesce(sum(l.accrued_rupees),0)::numeric,
    coalesce(sum(l.received_rupees),0)::numeric,
    coalesce(sum(l.gap_rupees),0)::numeric,
    round(avg(l.attainment_pct), 1),
    count(*) filter (where l.recovery_status in ('shortfall','at_risk','disputed'))::bigint
  from public.vendor_rebate_accrual_r3517 l
  group by l.rebate_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3517_rebate_type_scorecard() from public, anon;
grant execute on function public.founder_r3517_rebate_type_scorecard() to authenticated;

-- 3) Rebate-type × recovery-status matrix
create or replace function public.founder_r3517_rebate_type_recovery_matrix()
returns table(rebate_type text, recovery_status text, programs bigint, total_gap_rupees numeric, avg_attainment_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.rebate_type, l.recovery_status, count(*)::bigint,
    coalesce(sum(l.gap_rupees),0)::numeric,
    round(avg(l.attainment_pct), 1)
  from public.vendor_rebate_accrual_r3517 l
  group by l.rebate_type, l.recovery_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3517_rebate_type_recovery_matrix() from public, anon;
grant execute on function public.founder_r3517_rebate_type_recovery_matrix() to authenticated;

-- 4) Monthly accrual trend
create or replace function public.founder_r3517_monthly_accrual_trend()
returns table(period_month date, programs bigint, total_accrued_rupees numeric, total_received_rupees numeric, total_gap_rupees numeric, avg_attainment_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.accrued_rupees),0)::numeric,
    coalesce(sum(l.received_rupees),0)::numeric,
    coalesce(sum(l.gap_rupees),0)::numeric,
    round(avg(l.attainment_pct), 1)
  from public.vendor_rebate_accrual_r3517 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3517_monthly_accrual_trend() from public, anon;
grant execute on function public.founder_r3517_monthly_accrual_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3517_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovery_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovery_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.vendor_rebate_accrual_capa_actions_r3517 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3517_capa_status_board() from public, anon;
grant execute on function public.founder_r3517_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3517_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_rebate_accrual_capa_actions_r3517)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.vendor_rebate_accrual_capa_actions_r3517 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3517_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3517_root_cause_pareto() to authenticated;

-- 7) Rebate-gap impact digest (per supplier)
create or replace function public.founder_r3517_rebate_gap_impact_digest()
returns table(supplier_name text, programs bigint, total_earned_rupees numeric, total_received_rupees numeric, total_gap_rupees numeric, avg_attainment_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_name,
    count(*)::bigint,
    coalesce(sum(l.earned_rebate_rupees),0)::numeric,
    coalesce(sum(l.received_rupees),0)::numeric,
    coalesce(sum(l.gap_rupees),0)::numeric,
    round(avg(l.attainment_pct), 1)
  from public.vendor_rebate_accrual_r3517 l
  group by l.supplier_name
  order by coalesce(sum(l.gap_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3517_rebate_gap_impact_digest() from public, anon;
grant execute on function public.founder_r3517_rebate_gap_impact_digest() to authenticated;

-- 8) High-risk recovery queue (shortfall / at-risk / disputed)
create or replace function public.founder_r3517_high_risk_queue()
returns table(
  supplier_name text,
  program_code text,
  rebate_program text,
  rebate_type text,
  period_month date,
  recovery_status text,
  ytd_purchase_rupees numeric,
  threshold_rupees numeric,
  gap_rupees numeric,
  attainment_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_name, l.program_code, l.rebate_program, l.rebate_type, l.period_month,
    l.recovery_status, l.ytd_purchase_rupees, l.threshold_rupees, l.gap_rupees, l.attainment_pct, l.notes
  from public.vendor_rebate_accrual_r3517 l
  where l.recovery_status in ('shortfall','at_risk','disputed')
     or l.attainment_pct < 90
     or l.gap_rupees > 0
  order by l.gap_rupees desc nulls last, l.supplier_name;
end;
$$;

revoke execute on function public.founder_r3517_high_risk_queue() from public, anon;
grant execute on function public.founder_r3517_high_risk_queue() to authenticated;
