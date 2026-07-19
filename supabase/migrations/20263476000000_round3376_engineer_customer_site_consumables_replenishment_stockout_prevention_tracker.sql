-- Round 3376: Engineer / Customer-Site Consumables & Reagent Replenishment / Stockout-Prevention Tracker
-- Field ops — consumable type × linked equipment × days-of-cover × reorder point × lead time × expiry risk × auto-reorder × stockout events × CAPA

-- =============================================================================
-- TABLE 1: consumable_replenishment_r3376 — per consumable-site replenishment status
-- =============================================================================
create table if not exists public.consumable_replenishment_r3376 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  region text not null,
  tracking_ref text not null,
  consumable_type text not null check (consumable_type in (
    'ecg_electrodes','glucometer_strips','reagent_pack','spo2_sensors',
    'printer_paper','bp_cuffs','dialysis_consumables','filters'
  )),
  linked_equipment text not null check (linked_equipment in (
    'patient_monitor','glucometer','lab_analyzer','dialysis','ecg','general'
  )),
  check_date date not null,
  on_hand_qty int not null,
  avg_daily_consumption numeric(6,2),
  days_of_cover numeric(6,1),
  reorder_point int not null,
  lead_time_days int not null,
  expiry_risk_qty int not null default 0,
  last_replenished date,
  auto_reorder_enabled boolean not null default false,
  stockout_events_last_90 int not null default 0,
  replenishment_verdict text not null check (replenishment_verdict in (
    'healthy','reorder_now','stockout_risk','stocked_out_clinical_impact','expiry_action','overstocked'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.consumable_replenishment_r3376 enable row level security;

create index if not exists idx_consumable_repl_r3376_org on public.consumable_replenishment_r3376(organization_id);
create index if not exists idx_consumable_repl_r3376_date on public.consumable_replenishment_r3376(check_date);
create index if not exists idx_consumable_repl_r3376_verdict on public.consumable_replenishment_r3376(replenishment_verdict);

-- =============================================================================
-- TABLE 2: consumable_replenishment_capa_actions_r3376 — replenishment / expedite CAPA actions
-- =============================================================================
create table if not exists public.consumable_replenishment_capa_actions_r3376 (
  id uuid primary key default gen_random_uuid(),
  replenishment_log_id uuid not null references public.consumable_replenishment_r3376(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'below_reorder_point','stockout_clinical_impact','expiry_write_off_risk','long_lead_time_exposure',
    'auto_reorder_disabled','overstock_capital_tied','consumption_spike'
  )),
  root_cause text not null check (root_cause in (
    'demand_spike_unplanned','supplier_lead_time_slip','po_approval_delay','auto_reorder_not_configured',
    'forecast_underestimate','expiry_fifo_not_followed','budget_hold','vendor_stockout','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_emergency_po','enable_auto_reorder','raise_reorder_point','transfer_stock_from_sister_site',
    'negotiate_vmi_consignment','fifo_relabel_and_rotate','adjust_forecast_model','escalate_to_procurement','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  clinical_impact text not null check (clinical_impact in (
    'none','internal_only','procedure_delay_risk','clinical_procedure_halted','patient_reschedule','revenue_impact'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.consumable_replenishment_capa_actions_r3376 enable row level security;

create index if not exists idx_consumable_capa_r3376_log on public.consumable_replenishment_capa_actions_r3376(replenishment_log_id);
create index if not exists idx_consumable_capa_r3376_status on public.consumable_replenishment_capa_actions_r3376(capa_status);

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

  -- 14 consumable-site replenishment rows
  insert into public.consumable_replenishment_r3376 (
    organization_id, hospital_name, engineer_name, region, tracking_ref,
    consumable_type, linked_equipment, check_date,
    on_hand_qty, avg_daily_consumption, days_of_cover,
    reorder_point, lead_time_days, expiry_risk_qty,
    last_replenished, auto_reorder_enabled, stockout_events_last_90,
    replenishment_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.reg, q.ref,
    q.ctype, q.equip, q.cdate::date,
    q.onhand::int, q.adc::numeric, q.doc::numeric,
    q.rop::int, q.lead::int, q.exprisk::int,
    q.lastrep::date, q.autoreorder, q.stockouts::int,
    q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','Ramesh Kumar','South','RPL-APL-CHN-01','ecg_electrodes','ecg','2026-07-10',
     420,55.0,7.6,150,5,0,'2026-07-05',true,0,'healthy','ECG electrodes well stocked, auto-reorder active'),
    ('Apollo Chennai Greams Road','Ramesh Kumar','South','RPL-APL-CHN-02','glucometer_strips','glucometer','2026-07-10',
     48,22.0,2.2,60,4,0,'2026-06-28',true,1,'reorder_now','Strips below reorder point, PO to be raised'),
    ('Fortis Gurgaon','Amit Sharma','North','RPL-FRT-GGN-01','reagent_pack','lab_analyzer','2026-07-09',
     6,3.0,2.0,12,9,2,'2026-06-20',false,2,'stockout_risk','Reagent below reorder, 9d lead exceeds cover, auto-reorder off'),
    ('Fortis Gurgaon','Amit Sharma','North','RPL-FRT-GGN-02','spo2_sensors','patient_monitor','2026-07-09',
     0,4.0,0.0,20,6,0,'2026-06-15',false,3,'stocked_out_clinical_impact','SpO2 sensors out — 2 ICU monitors idle, expedite raised'),
    ('Manipal Bengaluru Old Airport Rd','Suresh Rao','South','RPL-MNP-BLR-01','printer_paper','general','2026-07-08',
     180,8.0,22.5,40,3,0,'2026-07-01',true,0,'healthy','Thermal roll stock comfortable'),
    ('Manipal Bengaluru Old Airport Rd','Suresh Rao','South','RPL-MNP-BLR-02','bp_cuffs','patient_monitor','2026-07-08',
     260,2.0,130.0,30,7,0,'2026-05-10',false,0,'overstocked','Cuff stock 8x reorder — capital tied, pause procurement'),
    ('AIIMS Delhi Ansari Nagar','Vikram Singh','North','RPL-AIM-DEL-01','dialysis_consumables','dialysis','2026-07-07',
     34,18.0,1.9,80,12,0,'2026-06-25',false,1,'stockout_risk','Dialysis lines short vs 12d lead — expedite advised'),
    ('AIIMS Delhi Ansari Nagar','Vikram Singh','North','RPL-AIM-DEL-02','filters','dialysis','2026-07-07',
     95,6.0,15.8,40,8,40,'2026-04-12',true,0,'expiry_action','40 filters expire in 30d — rotate/return, FIFO breach'),
    ('CMC Vellore','Joseph Thomas','South','RPL-CMC-VLR-01','ecg_electrodes','ecg','2026-07-06',
     110,40.0,2.8,150,5,0,'2026-06-22',false,0,'reorder_now','Electrodes dipping, enable auto-reorder'),
    ('KIMS Hyderabad','Prakash Reddy','South','RPL-KIM-HYD-01','glucometer_strips','glucometer','2026-07-06',
     300,20.0,15.0,60,4,0,'2026-07-02',true,0,'healthy','Strips healthy'),
    ('Medanta Gurgaon','Rohit Verma','North','RPL-MDT-GGN-01','reagent_pack','lab_analyzer','2026-07-05',
     0,5.0,0.0,15,10,0,'2026-06-10',false,4,'stocked_out_clinical_impact','Biochem reagent out — lab batch halted, patient reschedule'),
    ('Narayana Health Bengaluru','Girish Nair','South','RPL-NAR-BLR-01','spo2_sensors','patient_monitor','2026-07-05',
     75,3.0,25.0,20,6,0,'2026-06-30',true,0,'healthy','Sensors adequate'),
    ('Ruby Hall Clinic Pune','Sanjay Patil','West','RPL-RBY-PUN-01','printer_paper','general','2026-07-04',
     30,7.0,4.3,40,3,0,'2026-06-18',false,1,'reorder_now','Below reorder point, quick top-up'),
    ('Aster Medcity Kochi','Thomas Kurian','South','RPL-AST-KOC-01','filters','lab_analyzer','2026-07-04',
     12,null,null,30,8,5,null,false,2,'stockout_risk','New line — consumption not yet baselined, cover unknown')
  ) as q(hosp, eng, reg, ref, ctype, equip, cdate, onhand, adc, doc, rop, lead, exprisk, lastrep, autoreorder, stockouts, verdict, nt);

  -- CAPA seed — attach to at-risk rows via tracking_ref
  insert into public.consumable_replenishment_capa_actions_r3376 (
    replenishment_log_id, finding_category, root_cause, corrective_action,
    capa_status, clinical_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('RPL-FRT-GGN-01','long_lead_time_exposure','supplier_lead_time_slip','expedite_emergency_po','in_progress','procedure_delay_risk','2026-07-13',null,22000.00,'9d lead vs 2d cover — emergency PO placed with backup vendor'),
    ('RPL-FRT-GGN-02','stockout_clinical_impact','auto_reorder_not_configured','enable_auto_reorder','open','clinical_procedure_halted','2026-07-12',null,15000.00,'2 ICU monitors idle — auto-reorder to be enabled, stock transferred'),
    ('RPL-AIM-DEL-02','expiry_write_off_risk','expiry_fifo_not_followed','fifo_relabel_and_rotate','verification_pending','revenue_impact','2026-07-11','2026-07-09',8000.00,'40 filters near expiry — relabelled, FIFO rack enforced'),
    ('RPL-MDT-GGN-01','stockout_clinical_impact','vendor_stockout','transfer_stock_from_sister_site','escalated','patient_reschedule','2026-07-10',null,30000.00,'Vendor stockout — reagent transferred from sister site, 6 patients rescheduled'),
    ('RPL-CMC-VLR-01','auto_reorder_disabled','auto_reorder_not_configured','enable_auto_reorder','closed','internal_only','2026-07-09','2026-07-08',3500.00,'Auto-reorder enabled for electrodes, reorder point tuned'),
    ('RPL-MNP-BLR-02','overstock_capital_tied','forecast_underestimate','adjust_forecast_model','open','internal_only','2026-07-14',null,0.00,'260 cuffs vs 30 reorder — procurement paused, forecast recalibrated'),
    ('RPL-AIM-DEL-01','below_reorder_point','po_approval_delay','escalate_to_procurement','overdue','procedure_delay_risk','2026-07-08',null,12000.00,'Dialysis consumables PO stuck in approval past target — escalated')
  ) as q(tag, fc, rc, ca, cst, ci, tcd, acd, cost, nt)
  join public.consumable_replenishment_r3376 e
    on e.organization_id = v_org_id and e.tracking_ref = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Replenishment verdict distribution
create or replace function public.founder_r3376_replenishment_verdict_rollup()
returns table(replenishment_verdict text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.consumable_replenishment_r3376)
  select l.replenishment_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.consumable_replenishment_r3376 l
  group by l.replenishment_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3376_replenishment_verdict_rollup() from public, anon;
grant execute on function public.founder_r3376_replenishment_verdict_rollup() to authenticated;

-- 2) Hospital-level replenishment scorecard
create or replace function public.founder_r3376_hospital_scorecard()
returns table(
  hospital_name text,
  total_lines bigint,
  healthy bigint,
  reorder_now bigint,
  stockout_risk bigint,
  stocked_out bigint,
  expiry_action bigint,
  auto_reorder_on bigint,
  healthy_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.replenishment_verdict = 'healthy')::bigint,
    count(*) filter (where l.replenishment_verdict = 'reorder_now')::bigint,
    count(*) filter (where l.replenishment_verdict = 'stockout_risk')::bigint,
    count(*) filter (where l.replenishment_verdict = 'stocked_out_clinical_impact')::bigint,
    count(*) filter (where l.replenishment_verdict = 'expiry_action')::bigint,
    count(*) filter (where l.auto_reorder_enabled)::bigint,
    round(100.0 * count(*) filter (where l.replenishment_verdict = 'healthy')::numeric / nullif(count(*),0), 1)
  from public.consumable_replenishment_r3376 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3376_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3376_hospital_scorecard() to authenticated;

-- 3) Consumable type × linked equipment matrix
create or replace function public.founder_r3376_consumable_equipment_matrix()
returns table(consumable_type text, linked_equipment text, lines bigint, at_risk bigint, avg_days_of_cover numeric, total_stockout_events bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.consumable_type, l.linked_equipment, count(*)::bigint,
    count(*) filter (where l.replenishment_verdict in ('reorder_now','stockout_risk','stocked_out_clinical_impact','expiry_action'))::bigint,
    round(avg(l.days_of_cover), 1),
    coalesce(sum(l.stockout_events_last_90),0)::bigint
  from public.consumable_replenishment_r3376 l
  group by l.consumable_type, l.linked_equipment
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3376_consumable_equipment_matrix() from public, anon;
grant execute on function public.founder_r3376_consumable_equipment_matrix() to authenticated;

-- 4) Daily replenishment check trend
create or replace function public.founder_r3376_daily_check_trend()
returns table(check_date date, lines bigint, reorder_now bigint, stockout_risk bigint, stocked_out bigint, expiry_action bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.replenishment_verdict = 'reorder_now')::bigint,
    count(*) filter (where l.replenishment_verdict = 'stockout_risk')::bigint,
    count(*) filter (where l.replenishment_verdict = 'stocked_out_clinical_impact')::bigint,
    count(*) filter (where l.replenishment_verdict = 'expiry_action')::bigint
  from public.consumable_replenishment_r3376 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3376_daily_check_trend() from public, anon;
grant execute on function public.founder_r3376_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3376_capa_status_board()
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
  from public.consumable_replenishment_capa_actions_r3376 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3376_capa_status_board() from public, anon;
grant execute on function public.founder_r3376_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3376_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.consumable_replenishment_capa_actions_r3376)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.consumable_replenishment_capa_actions_r3376 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3376_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3376_root_cause_pareto() to authenticated;

-- 7) Clinical / cost-impact digest
create or replace function public.founder_r3376_clinical_impact_digest()
returns table(clinical_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.clinical_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.consumable_replenishment_capa_actions_r3376 c
  group by c.clinical_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3376_clinical_impact_digest() from public, anon;
grant execute on function public.founder_r3376_clinical_impact_digest() to authenticated;

-- 8) High-risk replenishment queue (top individual concerns)
create or replace function public.founder_r3376_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  tracking_ref text,
  consumable_type text,
  linked_equipment text,
  check_date date,
  days_of_cover numeric,
  on_hand_qty int,
  replenishment_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.tracking_ref, l.consumable_type,
    l.linked_equipment, l.check_date, l.days_of_cover, l.on_hand_qty,
    l.replenishment_verdict, l.notes
  from public.consumable_replenishment_r3376 l
  where l.replenishment_verdict in ('reorder_now','stockout_risk','stocked_out_clinical_impact','expiry_action')
     or l.expiry_risk_qty > 0
     or l.stockout_events_last_90 > 0
  order by
    case l.replenishment_verdict
      when 'stocked_out_clinical_impact' then 0
      when 'stockout_risk' then 1
      when 'reorder_now' then 2
      when 'expiry_action' then 3
      else 4
    end,
    l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3376_high_risk_queue() from public, anon;
grant execute on function public.founder_r3376_high_risk_queue() to authenticated;
