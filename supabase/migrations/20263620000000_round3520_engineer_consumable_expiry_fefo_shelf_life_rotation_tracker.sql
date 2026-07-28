-- Round 3520: Engineer Consumable-Expiry / FEFO Shelf-Life Rotation Tracker
-- Field/van consumable expiry + FEFO (first-expiry-first-out) rotation + shelf-life tracker —
-- consumable type x location x batch/lot x qty-on-hand x expiry x days-to-expiry x shelf-life-used x
-- FEFO status x rotation action x value-at-risk x CAPA closure

-- =============================================================================
-- TABLE 1: consumable_expiry_fefo_r3520 — per-item FEFO shelf-life checks
-- =============================================================================
create table if not exists public.consumable_expiry_fefo_r3520 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  location_name text not null,
  consumable_name text not null,
  batch_lot text not null,
  consumable_type text not null check (consumable_type in (
    'reagent','filter','electrode','battery','calibration_gas','test_strip','lubricant'
  )),
  qty_on_hand int not null,
  expiry_date date not null,
  days_to_expiry int not null,
  shelf_life_used_pct numeric(5,1),
  fefo_status text not null check (fefo_status in (
    'fresh','use_soon','expiring','expired','quarantined'
  )),
  action text not null check (action in (
    'none','rotate','use_first','return','dispose'
  )),
  value_at_risk_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.consumable_expiry_fefo_r3520 enable row level security;

create index if not exists idx_consumable_expiry_fefo_r3520_org on public.consumable_expiry_fefo_r3520(organization_id);
create index if not exists idx_consumable_expiry_fefo_r3520_exp on public.consumable_expiry_fefo_r3520(expiry_date);
create index if not exists idx_consumable_expiry_fefo_r3520_status on public.consumable_expiry_fefo_r3520(fefo_status);

-- =============================================================================
-- TABLE 2: consumable_expiry_fefo_capa_actions_r3520 — CAPA & disposition actions
-- =============================================================================
create table if not exists public.consumable_expiry_fefo_capa_actions_r3520 (
  id uuid primary key default gen_random_uuid(),
  log_id uuid not null references public.consumable_expiry_fefo_r3520(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'expired_stock_on_shelf','fefo_rotation_breach','near_expiry_not_flagged',
    'quarantine_not_isolated','shelf_life_exceeded','cold_chain_excursion',
    'overstock_expiry_risk','return_window_missed'
  )),
  root_cause text not null check (root_cause in (
    'fefo_process_not_followed','poor_stock_visibility','over_ordering','slow_moving_item',
    'storage_temp_excursion','vendor_short_dated_delivery','pending_investigation',
    'manual_tracking_error','delayed_consumption'
  )),
  corrective_action text not null check (corrective_action in (
    'rotate_to_front','dispose_expired_stock','return_to_vendor','use_first_priority',
    'adjust_reorder_qty','quarantine_and_segregate','implement_fefo_labeling',
    'retrain_engineer','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  disposition_impact text not null check (disposition_impact in (
    'write_off','patient_safety_risk','none','internal_only','vendor_credit_pending','audit_finding'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.consumable_expiry_fefo_capa_actions_r3520 enable row level security;

create index if not exists idx_consumable_expiry_fefo_capa_r3520_log on public.consumable_expiry_fefo_capa_actions_r3520(log_id);
create index if not exists idx_consumable_expiry_fefo_capa_r3520_status on public.consumable_expiry_fefo_capa_actions_r3520(capa_status);

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

  -- 16 FEFO shelf-life rows
  insert into public.consumable_expiry_fefo_r3520 (
    organization_id, engineer_name, location_name, consumable_name, batch_lot, consumable_type,
    qty_on_hand, expiry_date, days_to_expiry, shelf_life_used_pct, fefo_status, action,
    value_at_risk_rupees, notes
  )
  select v_org_id, q.eng, q.loc, q.cname, q.batch, q.ctype,
    q.qty, q.edate::date, q.dte, q.slu, q.fefo, q.act,
    q.vrisk, q.nt
  from (values
    ('Rajesh Kumar','Chennai South Van','Glucose Reagent Pack','RGT-CHN-8801','reagent',
     24,'2027-03-15',230,35.0,'fresh','none',18000,'Reagent stock healthy, FEFO order maintained'),
    ('Rajesh Kumar','Chennai South Van','HbA1c Test Strips','STP-CHN-8802','test_strip',
     12,'2026-09-10',44,78.0,'use_soon','use_first',9600,'Strips nearing expiry — prioritise for next diabetic camp'),
    ('Anil Verma','Delhi NCR Van','HEPA Intake Filter','FLT-DEL-5501','filter',
     6,'2026-08-12',15,88.0,'expiring','use_first',7200,'Filter cartridge expiring in 2 weeks, move to front of van'),
    ('Anil Verma','Delhi NCR Van','Li-ion Backup Battery','BAT-DEL-5502','battery',
     4,'2026-07-20',-8,100.0,'expired','dispose',12000,'Battery pack past shelf life — dispose per e-waste norms'),
    ('Suresh Nair','Kochi Regional Store','SpO2 Calibration Gas','GAS-KOC-3301','calibration_gas',
     2,'2026-08-30',33,65.0,'expiring','return',15400,'Cal gas cylinder short-dated, return to vendor'),
    ('Suresh Nair','Kochi Regional Store','ECG Electrode Set','ELC-KOC-3302','electrode',
     40,'2027-01-25',181,28.0,'fresh','none',4000,'Electrode gel pads fresh stock'),
    ('Priya Menon','Bengaluru East Van','Silicone Probe Lubricant','LUB-BLR-7701','lubricant',
     8,'2026-10-05',69,55.0,'use_soon','rotate',3200,'Lubricant tubes — rotate ahead of newer batch'),
    ('Priya Menon','Bengaluru East Van','CO2 Absorber Reagent','RGT-BLR-7702','reagent',
     10,'2026-08-05',8,92.0,'expiring','use_first',11000,'Soda-lime absorbent near expiry, consume first'),
    ('Mohan Rao','Hyderabad Central Store','Blood Gas Electrode','ELC-HYD-6601','electrode',
     3,'2026-07-15',-13,100.0,'expired','dispose',21000,'Sensor electrode expired, move to quarantine bin then dispose'),
    ('Mohan Rao','Hyderabad Central Store','Multi-gas Cal Cylinder','GAS-HYD-6602','calibration_gas',
     1,'2026-12-20',145,40.0,'fresh','none',9800,'Cal gas cylinder well within shelf life'),
    ('Kavita Joshi','Pune West Van','Urinalysis Test Strips','STP-PUN-4401','test_strip',
     20,'2026-08-20',23,82.0,'expiring','use_first',6000,'Urinalysis strips expiring — camp scheduled next week'),
    ('Kavita Joshi','Pune West Van','Inline Water Filter','FLT-PUN-4402','filter',
     5,'2026-06-30',-28,100.0,'quarantined','dispose',8500,'Dialysis water filter expired, quarantined pending disposal'),
    ('Deepak Shah','Ahmedabad Van','Coagulation Reagent','RGT-AHM-9901','reagent',
     15,'2027-05-10',286,20.0,'fresh','none',22500,'Coag reagent long shelf life remaining'),
    ('Deepak Shah','Ahmedabad Van','Defib Backup Battery','BAT-AHM-9902','battery',
     2,'2026-09-25',59,70.0,'use_soon','rotate',16000,'Defibrillator battery — rotate to front of van'),
    ('Lakshmi Iyer','Coimbatore Store','Chlorine Test Strips','STP-CBE-2201','test_strip',
     30,'2026-08-02',5,95.0,'expiring','use_first',4500,'RO plant chlorine strips almost expired'),
    ('Lakshmi Iyer','Coimbatore Store','Analyzer Reagent Kit','RGT-CBE-2202','reagent',
     6,'2026-05-15',-74,100.0,'quarantined','return',19000,'Analyzer reagent grossly expired, quarantined for vendor return')
  ) as q(eng, loc, cname, batch, ctype, qty, edate, dte, slu, fefo, act, vrisk, nt);

  -- CAPA seed — attach to specific items via batch_lot
  insert into public.consumable_expiry_fefo_capa_actions_r3520 (
    log_id, finding_category, root_cause, corrective_action,
    capa_status, disposition_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.dimp, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BAT-DEL-5502','expired_stock_on_shelf','delayed_consumption','dispose_expired_stock','in_progress','write_off','2026-08-05',null,12000,'Expired Li-ion pack scheduled for e-waste disposal'),
    ('GAS-KOC-3301','return_window_missed','vendor_short_dated_delivery','return_to_vendor','open','vendor_credit_pending','2026-08-15',null,15400,'Short-dated cal gas — vendor credit note requested'),
    ('ELC-HYD-6601','expired_stock_on_shelf','poor_stock_visibility','dispose_expired_stock','closed','write_off','2026-07-22','2026-07-21',21000,'Expired blood-gas electrode disposed and logged'),
    ('FLT-PUN-4402','quarantine_not_isolated','storage_temp_excursion','quarantine_and_segregate','escalated','patient_safety_risk','2026-07-18',null,8500,'Dialysis water filter quarantined — patient-safety escalation to QA'),
    ('RGT-BLR-7702','near_expiry_not_flagged','poor_stock_visibility','use_first_priority','verification_pending','internal_only','2026-08-01',null,11000,'Absorber flagged use-first — verify consumption at next service'),
    ('RGT-CBE-2202','shelf_life_exceeded','slow_moving_item','return_to_vendor','overdue','audit_finding','2026-07-10',null,19000,'Grossly expired analyzer reagent — return overdue, audit flagged'),
    ('STP-CBE-2201','fefo_rotation_breach','fefo_process_not_followed','implement_fefo_labeling','open','audit_finding','2026-08-10',null,4500,'Newer strips used before older — FEFO labeling to be implemented'),
    ('FLT-DEL-5501','near_expiry_not_flagged','manual_tracking_error','rotate_to_front','closed','none','2026-07-25','2026-07-24',7200,'Filter rotated to front of van, tracking corrected')
  ) as q(batch, fc, rc, ca, cst, dimp, tcd, acd, cost, nt)
  join public.consumable_expiry_fefo_r3520 e
    on e.organization_id = v_org_id and e.batch_lot = q.batch;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) FEFO status distribution
create or replace function public.founder_r3520_fefo_status_rollup()
returns table(fefo_status text, items bigint, total_qty bigint, value_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.consumable_expiry_fefo_r3520)
  select l.fefo_status, count(*)::bigint,
         coalesce(sum(l.qty_on_hand),0)::bigint,
         coalesce(sum(l.value_at_risk_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.consumable_expiry_fefo_r3520 l
  group by l.fefo_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3520_fefo_status_rollup() from public, anon;
grant execute on function public.founder_r3520_fefo_status_rollup() to authenticated;

-- 2) Consumable-type scorecard
create or replace function public.founder_r3520_consumable_type_scorecard()
returns table(
  consumable_type text,
  total_items bigint,
  fresh bigint,
  use_soon bigint,
  expiring bigint,
  expired bigint,
  quarantined bigint,
  value_at_risk_rupees numeric,
  expired_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.consumable_type,
    count(*)::bigint,
    count(*) filter (where l.fefo_status = 'fresh')::bigint,
    count(*) filter (where l.fefo_status = 'use_soon')::bigint,
    count(*) filter (where l.fefo_status = 'expiring')::bigint,
    count(*) filter (where l.fefo_status = 'expired')::bigint,
    count(*) filter (where l.fefo_status = 'quarantined')::bigint,
    coalesce(sum(l.value_at_risk_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.fefo_status in ('expired','quarantined'))::numeric / nullif(count(*),0), 1)
  from public.consumable_expiry_fefo_r3520 l
  group by l.consumable_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3520_consumable_type_scorecard() from public, anon;
grant execute on function public.founder_r3520_consumable_type_scorecard() to authenticated;

-- 3) Consumable-type x FEFO-status matrix
create or replace function public.founder_r3520_type_status_matrix()
returns table(consumable_type text, fefo_status text, items bigint, total_qty bigint, avg_shelf_life_used_pct numeric, value_at_risk_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.consumable_type, l.fefo_status, count(*)::bigint,
    coalesce(sum(l.qty_on_hand),0)::bigint,
    round(avg(l.shelf_life_used_pct), 1),
    coalesce(sum(l.value_at_risk_rupees),0)::numeric
  from public.consumable_expiry_fefo_r3520 l
  group by l.consumable_type, l.fefo_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3520_type_status_matrix() from public, anon;
grant execute on function public.founder_r3520_type_status_matrix() to authenticated;

-- 4) Monthly expiry trend
create or replace function public.founder_r3520_monthly_expiry_trend()
returns table(expiry_month date, items bigint, expiring bigint, expired bigint, quarantined bigint, value_at_risk_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.expiry_date)::date,
    count(*)::bigint,
    count(*) filter (where l.fefo_status = 'expiring')::bigint,
    count(*) filter (where l.fefo_status = 'expired')::bigint,
    count(*) filter (where l.fefo_status = 'quarantined')::bigint,
    coalesce(sum(l.value_at_risk_rupees),0)::numeric
  from public.consumable_expiry_fefo_r3520 l
  group by date_trunc('month', l.expiry_date)
  order by date_trunc('month', l.expiry_date);
end;
$$;

revoke execute on function public.founder_r3520_monthly_expiry_trend() from public, anon;
grant execute on function public.founder_r3520_monthly_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3520_capa_status_board()
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
  from public.consumable_expiry_fefo_capa_actions_r3520 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3520_capa_status_board() from public, anon;
grant execute on function public.founder_r3520_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3520_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.consumable_expiry_fefo_capa_actions_r3520)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.consumable_expiry_fefo_capa_actions_r3520 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3520_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3520_root_cause_pareto() to authenticated;

-- 7) Value-at-risk impact digest (by location)
create or replace function public.founder_r3520_value_at_risk_digest()
returns table(
  location_name text,
  items bigint,
  expiring bigint,
  expired bigint,
  quarantined bigint,
  value_at_risk_rupees numeric,
  avg_shelf_life_used_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.location_name,
    count(*)::bigint,
    count(*) filter (where l.fefo_status = 'expiring')::bigint,
    count(*) filter (where l.fefo_status = 'expired')::bigint,
    count(*) filter (where l.fefo_status = 'quarantined')::bigint,
    coalesce(sum(l.value_at_risk_rupees),0)::numeric,
    round(avg(l.shelf_life_used_pct), 1)
  from public.consumable_expiry_fefo_r3520 l
  group by l.location_name
  order by coalesce(sum(l.value_at_risk_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3520_value_at_risk_digest() from public, anon;
grant execute on function public.founder_r3520_value_at_risk_digest() to authenticated;

-- 8) High-risk queue (expired / expiring / quarantined)
create or replace function public.founder_r3520_high_risk_queue()
returns table(
  engineer_name text,
  location_name text,
  consumable_name text,
  batch_lot text,
  consumable_type text,
  expiry_date date,
  days_to_expiry integer,
  fefo_status text,
  action text,
  value_at_risk_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.location_name, l.consumable_name, l.batch_lot, l.consumable_type,
    l.expiry_date, l.days_to_expiry, l.fefo_status, l.action, l.value_at_risk_rupees, l.notes
  from public.consumable_expiry_fefo_r3520 l
  where l.fefo_status in ('expiring','expired','quarantined')
     or l.action in ('return','dispose','use_first')
     or l.days_to_expiry <= 30
  order by l.days_to_expiry asc, l.expiry_date asc;
end;
$$;

revoke execute on function public.founder_r3520_high_risk_queue() from public, anon;
grant execute on function public.founder_r3520_high_risk_queue() to authenticated;
