-- Round 3663: Founder Demurrage / Detention / Port-Storage Charges Board
-- Import logistics finance — per-shipment dwell days × free days × chargeable days × demurrage × detention × storage charges × hold type × charge status × trend × CAPA

-- =============================================================================
-- TABLE 1: demurrage_r3663 — per-shipment demurrage / detention / storage charges
-- =============================================================================
create table if not exists public.demurrage_r3663 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  shipment_ref text not null,
  port_name text not null,
  period_month date not null,
  eta_date date,
  clearance_date date,
  dwell_days int,
  free_days int,
  chargeable_days int,
  demurrage_rupees numeric(12,2),
  detention_rupees numeric(12,2),
  storage_rupees numeric(12,2),
  total_charges_rupees numeric(12,2),
  hold_type text not null check (hold_type in (
    'documentation','duty_payment','customs_query','cdsco_noc','space_congestion'
  )),
  charge_status text not null check (charge_status in (
    'no_charge','minor','significant','heavy','disputed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.demurrage_r3663 enable row level security;

create index if not exists idx_demurrage_r3663_org on public.demurrage_r3663(organization_id);
create index if not exists idx_demurrage_r3663_month on public.demurrage_r3663(period_month);
create index if not exists idx_demurrage_r3663_status on public.demurrage_r3663(charge_status);

-- =============================================================================
-- TABLE 2: demurrage_capa_actions_r3663 — CAPA & charge-recovery actions
-- =============================================================================
create table if not exists public.demurrage_capa_actions_r3663 (
  id uuid primary key default gen_random_uuid(),
  charge_id uuid not null references public.demurrage_r3663(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'checklist_delay','duty_funds_delay','query_response_slow','noc_processing_backlog',
    'port_congestion','cha_coordination_gap','shipping_line_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'pre_file_documents','advance_duty_deposit','dedicated_query_desk','cdsco_liaison_engaged',
    'shift_to_alternate_port','change_cha_partner','negotiate_free_days','dispute_with_line','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  charge_impact_rupees numeric(12,2),
  capa_owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.demurrage_capa_actions_r3663 enable row level security;

create index if not exists idx_demurrage_capa_r3663_charge on public.demurrage_capa_actions_r3663(charge_id);
create index if not exists idx_demurrage_capa_r3663_status on public.demurrage_capa_actions_r3663(capa_status);

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

  -- 16 shipment charge rows
  insert into public.demurrage_r3663 (
    organization_id, shipment_ref, port_name, period_month, eta_date, clearance_date,
    dwell_days, free_days, chargeable_days, demurrage_rupees, detention_rupees,
    storage_rupees, total_charges_rupees, hold_type, charge_status, trend_dir, notes
  )
  select v_org_id, q.sref, q.prt, q.pmon::date, q.eta::date, q.clr::date,
    q.dwl, q.frd, q.chd, q.dem, q.det,
    q.sto, q.tot, q.ht, q.cs, q.td, q.nt
  from (values
    ('SHP-NSA-4501','Nhava Sheva','2026-05-01','2026-05-04','2026-05-06',
     2,3,0,0,0,0,0,'documentation','no_charge','stable','Cleared within free days — checklist pre-filed with CHA'),
    ('SHP-NSA-4508','Nhava Sheva','2026-05-01','2026-05-10','2026-05-19',
     9,3,6,84000,52500,21000,157500,'customs_query','heavy','worsening','Valuation query on ICU ventilator lot — 9-day dwell, heaviest of May'),
    ('SHP-CHN-4512','Chennai Port','2026-05-01','2026-05-12','2026-05-17',
     5,3,2,24000,15000,8000,47000,'duty_payment','minor','stable','Duty funds credited a day late — 2 chargeable days'),
    ('SHP-DAC-4515','Delhi Air Cargo','2026-05-01','2026-05-15','2026-05-21',
     6,2,4,0,38000,26400,64400,'cdsco_noc','significant','worsening','CDSCO NOC for imaging tubes pending 4 days beyond free period'),
    ('SHP-MUN-4520','Mundra','2026-05-01','2026-05-18','2026-05-20',
     2,4,0,0,0,0,0,'documentation','no_charge','improving','BOE pre-filed — cleared inside free window'),
    ('SHP-NSA-4602','Nhava Sheva','2026-06-01','2026-06-03','2026-06-10',
     7,3,4,56000,35000,14000,105000,'space_congestion','significant','worsening','Berth congestion week — CFS space full, boxes rolled'),
    ('SHP-CHN-4607','Chennai Port','2026-06-01','2026-06-08','2026-06-12',
     4,3,1,12000,7500,4000,23500,'documentation','minor','improving','Late COO correction cost one chargeable day'),
    ('SHP-DAC-4611','Delhi Air Cargo','2026-06-01','2026-06-10','2026-06-11',
     1,2,0,0,0,0,0,'documentation','no_charge','improving','Air shipment cleared same day — dedicated desk working'),
    ('SHP-KOL-4614','Kolkata Port','2026-06-01','2026-06-14','2026-06-24',
     10,3,7,98000,61250,24500,183750,'cdsco_noc','heavy','worsening','Dialysis consumables NOC backlog — 10-day dwell, heaviest of June'),
    ('SHP-COK-4618','Cochin Port','2026-06-01','2026-06-16','2026-06-20',
     4,3,1,11000,6875,3600,21475,'duty_payment','minor','stable','IGST challan retry delayed clearance by one day'),
    ('SHP-NSA-4703','Nhava Sheva','2026-07-01','2026-07-02','2026-07-07',
     5,3,2,26000,16250,6500,48750,'customs_query','minor','improving','HSN query resolved in 24h — big improvement over May'),
    ('SHP-BLR-4706','Bengaluru Air Cargo','2026-07-01','2026-07-05','2026-07-12',
     7,2,5,0,47500,33000,80500,'cdsco_noc','significant','stable','Ortho implant NOC took 5 extra days — liaison engaged'),
    ('SHP-CHN-4709','Chennai Port','2026-07-01','2026-07-08','2026-07-18',
     10,3,7,91000,56875,22750,170625,'space_congestion','disputed','worsening','Line billed demurrage during port strike — invoice disputed'),
    ('SHP-MUN-4712','Mundra','2026-07-01','2026-07-10','2026-07-13',
     3,4,0,0,0,0,0,'documentation','no_charge','stable','Cleared inside free window — Mundra lane steady'),
    ('SHP-HYD-4715','Hyderabad Air Cargo','2026-07-01','2026-07-12','2026-07-16',
     4,2,2,0,19000,13200,32200,'duty_payment','minor','stable','Duty payment gateway outage — two chargeable days'),
    ('SHP-DAC-4718','Delhi Air Cargo','2026-07-01','2026-07-14','2026-07-23',
     9,2,7,0,66500,46200,112700,'customs_query','heavy','worsening','Provisional assessment query on catheter lot — 9-day dwell')
  ) as q(sref, prt, pmon, eta, clr, dwl, frd, chd, dem, det, sto, tot, ht, cs, td, nt);

  -- CAPA seed — attach to specific shipments via shipment_ref
  insert into public.demurrage_capa_actions_r3663 (
    charge_id, root_cause, corrective_action, capa_status,
    charge_impact_rupees, capa_owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.imp, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SHP-NSA-4508','query_response_slow','dedicated_query_desk','in_progress',157500,'Imports Lead — Rohit Nair','2026-07-25',null,'Valuation desk SLA set to 24h — tracking next 3 consignments'),
    ('SHP-DAC-4515','noc_processing_backlog','cdsco_liaison_engaged','verification_pending',64400,'RA Manager — Kavitha Rao','2026-07-20',null,'CDSCO liaison engaged; NOC pre-application now filed at PO stage'),
    ('SHP-NSA-4602','port_congestion','shift_to_alternate_port','open',105000,'Logistics Head — Arjun Mehta','2026-08-10',null,'Evaluating Mundra routing for west-coast sea imports in congestion weeks'),
    ('SHP-KOL-4614','noc_processing_backlog','cdsco_liaison_engaged','escalated',183750,'RA Manager — Kavitha Rao','2026-07-15',null,'Heaviest June charge — escalated to CDSCO zonal office'),
    ('SHP-CHN-4709','shipping_line_delay','dispute_with_line','in_progress',170625,'Logistics Head — Arjun Mehta','2026-08-05',null,'Force-majeure clause cited — credit note demanded from shipping line'),
    ('SHP-CHN-4512','duty_funds_delay','advance_duty_deposit','closed',47000,'Finance Controller — Sneha Iyer','2026-06-15','2026-06-10','PD account topped up weekly — no repeat in July'),
    ('SHP-BLR-4706','noc_processing_backlog','negotiate_free_days','open',80500,'Imports Lead — Rohit Nair','2026-08-12',null,'Negotiating 4 free days with airline terminal for NOC-class cargo'),
    ('SHP-DAC-4718','query_response_slow','pre_file_documents','overdue',112700,'Imports Lead — Rohit Nair','2026-07-28',null,'Pre-filing pack for provisional-assessment lots past target — vendor docs pending')
  ) as q(sref, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.demurrage_r3663 e
    on e.organization_id = v_org_id and e.shipment_ref = q.sref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Charge status distribution
create or replace function public.founder_r3663_charge_status_rollup()
returns table(charge_status text, shipments bigint, total_charges_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.demurrage_r3663)
  select l.charge_status, count(*)::bigint,
         coalesce(sum(l.total_charges_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.demurrage_r3663 l
  group by l.charge_status
  order by count(*) desc;
end;
$$;

-- 2) Port-level charges scorecard
create or replace function public.founder_r3663_port_scorecard()
returns table(
  port_name text,
  shipments bigint,
  clean_clearances bigint,
  heavy_or_disputed bigint,
  avg_dwell_days numeric,
  total_chargeable_days bigint,
  total_charges_rupees numeric,
  clean_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.port_name,
    count(*)::bigint,
    count(*) filter (where l.charge_status = 'no_charge')::bigint,
    count(*) filter (where l.charge_status in ('heavy','disputed'))::bigint,
    round(avg(l.dwell_days)::numeric, 1),
    coalesce(sum(l.chargeable_days),0)::bigint,
    coalesce(sum(l.total_charges_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.charge_status = 'no_charge')::numeric / nullif(count(*),0), 1)
  from public.demurrage_r3663 l
  group by l.port_name
  order by coalesce(sum(l.total_charges_rupees),0) desc;
end;
$$;

-- 3) Hold type × charge status matrix
create or replace function public.founder_r3663_hold_type_status_matrix()
returns table(hold_type text, charge_status text, shipments bigint, total_charges_rupees numeric, avg_dwell_days numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hold_type, l.charge_status, count(*)::bigint,
    coalesce(sum(l.total_charges_rupees),0)::numeric,
    round(avg(l.dwell_days)::numeric, 1)
  from public.demurrage_r3663 l
  group by l.hold_type, l.charge_status
  order by coalesce(sum(l.total_charges_rupees),0) desc;
end;
$$;

-- 4) Monthly charges trend
create or replace function public.founder_r3663_monthly_charges_trend()
returns table(
  period_month date,
  shipments bigint,
  total_demurrage_rupees numeric,
  total_detention_rupees numeric,
  total_storage_rupees numeric,
  total_charges_rupees numeric,
  avg_dwell_days numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.demurrage_rupees),0)::numeric,
    coalesce(sum(l.detention_rupees),0)::numeric,
    coalesce(sum(l.storage_rupees),0)::numeric,
    coalesce(sum(l.total_charges_rupees),0)::numeric,
    round(avg(l.dwell_days)::numeric, 1)
  from public.demurrage_r3663 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3663_capa_status_board()
returns table(capa_status text, actions bigint, total_impact_rupees numeric, overdue_or_escalated bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.charge_impact_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.demurrage_capa_actions_r3663 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3663_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.demurrage_capa_actions_r3663)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.charge_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.demurrage_capa_actions_r3663 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Dwell-band impact digest
create or replace function public.founder_r3663_dwell_impact_digest()
returns table(dwell_band text, shipments bigint, avg_chargeable_days numeric, total_charges_rupees numeric, share_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with banded as (
    select case
      when l.dwell_days <= 3 then '0-3 days'
      when l.dwell_days <= 6 then '4-6 days'
      when l.dwell_days <= 9 then '7-9 days'
      else '10+ days'
    end as band,
    l.chargeable_days as chd,
    l.total_charges_rupees as tot
    from public.demurrage_r3663 l
  ),
  grand as (select nullif(sum(b.tot),0) as g from banded b)
  select b.band, count(*)::bigint,
    round(avg(b.chd)::numeric, 1),
    coalesce(sum(b.tot),0)::numeric,
    round(coalesce(sum(b.tot),0) / (select g from grand) * 100.0, 1)
  from banded b
  group by b.band
  order by coalesce(sum(b.tot),0) desc;
end;
$$;

-- 8) High-risk charges queue (heavy / disputed / worsening)
create or replace function public.founder_r3663_high_risk_queue()
returns table(
  shipment_ref text,
  port_name text,
  period_month date,
  hold_type text,
  charge_status text,
  dwell_days int,
  chargeable_days int,
  total_charges_rupees numeric,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.shipment_ref, l.port_name, l.period_month, l.hold_type, l.charge_status,
    l.dwell_days, l.chargeable_days, l.total_charges_rupees, l.trend_dir, l.notes
  from public.demurrage_r3663 l
  where l.charge_status in ('heavy','disputed')
     or (l.charge_status = 'significant' and l.trend_dir = 'worsening')
  order by l.total_charges_rupees desc nulls last, l.period_month desc;
end;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================
revoke all on function public.founder_r3663_charge_status_rollup() from public, anon;
revoke all on function public.founder_r3663_port_scorecard() from public, anon;
revoke all on function public.founder_r3663_hold_type_status_matrix() from public, anon;
revoke all on function public.founder_r3663_monthly_charges_trend() from public, anon;
revoke all on function public.founder_r3663_capa_status_board() from public, anon;
revoke all on function public.founder_r3663_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3663_dwell_impact_digest() from public, anon;
revoke all on function public.founder_r3663_high_risk_queue() from public, anon;

grant execute on function public.founder_r3663_charge_status_rollup() to authenticated;
grant execute on function public.founder_r3663_port_scorecard() to authenticated;
grant execute on function public.founder_r3663_hold_type_status_matrix() to authenticated;
grant execute on function public.founder_r3663_monthly_charges_trend() to authenticated;
grant execute on function public.founder_r3663_capa_status_board() to authenticated;
grant execute on function public.founder_r3663_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3663_dwell_impact_digest() to authenticated;
grant execute on function public.founder_r3663_high_risk_queue() to authenticated;
