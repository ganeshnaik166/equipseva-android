-- Round 3716: Founder Equipment Trade-In / Buyback Program Board
-- Trade-in/buyback economics — equipment model x period x old-unit valuation x credit issued x new-sale attach x resale recovery x net program margin x disposition route x CAPA

-- =============================================================================
-- TABLE 1: trade_in_r3716 — per-trade-in valuation, credit & disposition facts
-- =============================================================================
create table if not exists public.trade_in_r3716 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  trade_in_ref text not null,
  equipment_model text not null,
  period_month date not null,
  customer_name text not null,
  old_unit_age_years numeric(4,1),
  valuation_rupees numeric(12,2),
  credit_issued_rupees numeric(12,2),
  new_sale_value_rupees numeric(12,2),
  attach_to_new_sale boolean not null,
  resale_recovery_rupees numeric(12,2),
  net_program_margin_rupees numeric(12,2),
  days_to_disposition int,
  route_class text not null check (route_class in (
    'refurb_resale','parts_harvest','scrap','oem_return','pending_disposition'
  )),
  program_status text not null check (program_status in (
    'profitable','breakeven','credit_heavy','stuck_inventory','loss_making'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.trade_in_r3716 enable row level security;

create index if not exists idx_trade_in_r3716_org on public.trade_in_r3716(organization_id);
create index if not exists idx_trade_in_r3716_month on public.trade_in_r3716(period_month);
create index if not exists idx_trade_in_r3716_status on public.trade_in_r3716(program_status);

-- =============================================================================
-- TABLE 2: trade_in_capa_actions_r3716 — CAPA & program-governance actions
-- =============================================================================
create table if not exists public.trade_in_capa_actions_r3716 (
  id uuid primary key default gen_random_uuid(),
  trade_in_id uuid not null references public.trade_in_r3716(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'overvalued_appraisal','credit_leakage_no_attach','aging_disposition_backlog',
    'resale_recovery_shortfall','route_class_misassignment','margin_erosion',
    'compliance_hold','documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'inflated_initial_appraisal','condition_assessment_missed_defect','no_attach_condition_enforced',
    'weak_resale_channel','disposition_backlog_warehouse_space','regulatory_recall_hold',
    'refurb_cost_overrun','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'revise_appraisal_matrix','enforce_attach_condition','expedite_resale_channel',
    'reroute_to_parts_harvest','reroute_to_scrap','escalate_oem_recall_return',
    'liquidate_aged_inventory','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.trade_in_capa_actions_r3716 enable row level security;

create index if not exists idx_trade_in_capa_r3716_trade on public.trade_in_capa_actions_r3716(trade_in_id);
create index if not exists idx_trade_in_capa_r3716_status on public.trade_in_capa_actions_r3716(capa_status);

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

  -- 16 trade-in rows
  insert into public.trade_in_r3716 (
    organization_id, trade_in_ref, equipment_model, period_month, customer_name,
    old_unit_age_years, valuation_rupees, credit_issued_rupees, new_sale_value_rupees,
    attach_to_new_sale, resale_recovery_rupees, net_program_margin_rupees, days_to_disposition,
    route_class, program_status, trend_dir, notes
  )
  select v_org_id, q.ref, q.model, q.pm::date, q.cust,
    q.age, q.val, q.credit, q.nsale,
    q.att, q.recov, q.marg, q.days,
    q.rte, q.pst, q.trd, q.nt
  from (values
    ('TRD-3716-001','Ventilator (Getinge Servo-U)','2026-07-01','Apollo Chennai',
     6.5,210000,195000,1850000,true,245000,50000,18,'refurb_resale','profitable','improving','Refurbished and resold to a tier-2 hospital within three weeks — strong margin'),
    ('TRD-3716-002','Patient Monitor (Philips IntelliVue MX450)','2026-07-01','Fortis Gurgaon',
     4.0,68000,65000,420000,true,71000,6000,25,'refurb_resale','breakeven','stable','Refurb margin thin after parts replacement — near breakeven'),
    ('TRD-3716-003','Defibrillator (Zoll R Series)','2026-07-01','Manipal Bengaluru',
     8.0,92000,92000,610000,true,30000,-62000,40,'refurb_resale','credit_heavy','worsening','Full appraisal value credited to close a competitive deal — resale recovered far below cost'),
    ('TRD-3716-004','Infusion Pump (B. Braun Infusomat Space)','2026-06-01','Max Saket Delhi',
     5.5,18000,16000,95000,true,21000,5000,15,'refurb_resale','profitable','stable','Battery and tubing refurb kit applied — resold to a diagnostic chain'),
    ('TRD-3716-005','ECG Machine (BPL Cardiart 6208)','2026-06-01','CMC Vellore',
     9.0,22000,20000,78000,false,4000,-16000,62,'parts_harvest','loss_making','worsening','Thermal-printer fault missed at appraisal — unit stripped for spares only'),
    ('TRD-3716-006','Ultrasound System (GE Voluson E10)','2026-06-01','KIMS Hyderabad',
     3.5,480000,450000,3200000,true,560000,110000,22,'refurb_resale','profitable','improving','High-demand probe set drove a strong resale premium'),
    ('TRD-3716-007','X-Ray Machine Portable (Siemens Mobilett)','2026-06-01','Yashoda Hyderabad',
     7.0,145000,145000,890000,true,60000,-85000,55,'refurb_resale','credit_heavy','worsening','Detector panel degraded post-appraisal — recovery fell far short of credited value'),
    ('TRD-3716-008','Anesthesia Workstation (Drager Fabius Plus)','2026-05-01','Kokilaben Mumbai',
     10.0,165000,150000,1450000,true,0,-150000,96,'oem_return','stuck_inventory','worsening','Vaporizer recall notice holding unit in warehouse pending OEM return authorisation'),
    ('TRD-3716-009','ICU Bed Electric (Stryker InTouch)','2026-05-01','Global Hospitals Chennai',
     6.0,58000,55000,320000,true,62000,7000,20,'refurb_resale','breakeven','stable','Actuator motor serviced — resold to a nursing-home chain'),
    ('TRD-3716-010','Autoclave Sterilizer (Getinge 400 Series)','2026-05-01','Narayana Health Bengaluru',
     12.0,35000,32000,210000,true,6000,-26000,70,'scrap','loss_making','worsening','Chamber corrosion beyond service limit — scrapped for steel recovery only'),
    ('TRD-3716-011','Dialysis Machine (Fresenius 4008S)','2026-06-01','Ruby Hall Clinic Pune',
     5.0,210000,195000,1150000,true,250000,55000,16,'refurb_resale','profitable','improving','Dialyzer housing refurb kit applied — resold to a dialysis chain in a tier-2 city'),
    ('TRD-3716-012','OT Table (Maquet Alphamaxx)','2026-06-01','Sunrise Multispeciality Kochi',
     8.5,88000,88000,620000,true,40000,-48000,48,'refurb_resale','credit_heavy','worsening','Hydraulic column leak found post-appraisal — full credit already committed'),
    ('TRD-3716-013','Pulse Oximeter Bedside (Masimo Radical-7)','2026-05-01','Care Hospitals Hyderabad',
     4.5,15000,14000,62000,true,17000,3000,12,'refurb_resale','profitable','stable','Sensor-cable kit replaced — quick resale via reseller network'),
    ('TRD-3716-014','Nebulizer Hospital-Grade (Philips InnoSpire)','2026-05-01','Medanta Gurugram',
     6.5,4200,4000,18000,false,800,-3200,58,'parts_harvest','loss_making','worsening','Compressor motor seized — harvested for cup and tubing only'),
    ('TRD-3716-015','Suction Unit Hospital (Allied Healthcare)','2026-04-01','Wockhardt Mumbai',
     9.5,8500,8000,32000,true,500,-7500,110,'pending_disposition','stuck_inventory','worsening','Awaiting biomedical disposal certificate before route decision'),
    ('TRD-3716-016','C-Arm Machine (Siemens Arcadis Avantic)','2026-04-01','Fortis Gurgaon',
     7.5,620000,600000,4100000,true,30000,-570000,130,'pending_disposition','stuck_inventory','worsening','Image-intensifier fault discovered post-credit — legal review before OEM-return claim')
  ) as q(ref, model, pm, cust, age, val, credit, nsale, att, recov, marg, days, rte, pst, trd, nt);

  -- CAPA seed — attach to specific trade-ins via trade_in_ref
  insert into public.trade_in_capa_actions_r3716 (
    trade_in_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('TRD-3716-003','overvalued_appraisal','inflated_initial_appraisal','revise_appraisal_matrix','in_progress',62000.00,'Trade-In Program Manager','2026-08-20',null,'Full appraisal credited without a bench test — appraisal matrix revision in progress'),
    ('TRD-3716-005','margin_erosion','condition_assessment_missed_defect','reroute_to_parts_harvest','closed',16000.00,'Refurb Ops Lead','2026-07-10','2026-07-08','Thermal-printer fault missed at appraisal — unit stripped for spares, valuation checklist flagged'),
    ('TRD-3716-007','overvalued_appraisal','condition_assessment_missed_defect','revise_appraisal_matrix','verification_pending',85000.00,'Trade-In Program Manager','2026-08-18',null,'Detector-panel degradation not caught pre-credit — bench-test checklist update awaiting sign-off'),
    ('TRD-3716-008','compliance_hold','regulatory_recall_hold','escalate_oem_recall_return','escalated',150000.00,'Regulatory Affairs Lead','2026-08-10',null,'Vaporizer recall notice holds the unit — escalated to OEM for return authorisation'),
    ('TRD-3716-010','route_class_misassignment','condition_assessment_missed_defect','reroute_to_scrap','closed',26000.00,'Refurb Ops Lead','2026-06-15','2026-06-12','Chamber corrosion beyond service limit confirmed post-scrap — appraisal checklist updated'),
    ('TRD-3716-012','overvalued_appraisal','inflated_initial_appraisal','revise_appraisal_matrix','open',48000.00,'Trade-In Program Manager','2026-08-25',null,'Hydraulic-column leak surfaced after full credit was committed — hydraulic test added to checklist'),
    ('TRD-3716-015','aging_disposition_backlog','disposition_backlog_warehouse_space','liquidate_aged_inventory','overdue',7500.00,'Warehouse Ops Manager','2026-07-20',null,'Biomedical disposal certificate delayed three months — liquidation past target date'),
    ('TRD-3716-016','compliance_hold','condition_assessment_missed_defect','escalate_oem_recall_return','escalated',570000.00,'Legal & Compliance Lead','2026-08-05',null,'Image-intensifier fault found after credit committed — legal review before OEM-return claim, largest program exposure')
  ) as q(ref, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.trade_in_r3716 e
    on e.organization_id = v_org_id and e.trade_in_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Program-status distribution
create or replace function public.founder_r3716_program_status_rollup()
returns table(program_status text, trade_ins bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.trade_in_r3716)
  select l.program_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.trade_in_r3716 l
  group by l.program_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3716_program_status_rollup() from public, anon;
grant execute on function public.founder_r3716_program_status_rollup() to authenticated;

-- 2) Equipment-model scorecard
create or replace function public.founder_r3716_equipment_model_scorecard()
returns table(
  equipment_model text,
  total_trade_ins bigint,
  profitable bigint,
  credit_heavy bigint,
  stuck_inventory bigint,
  loss_making bigint,
  attach_rate_pct numeric,
  avg_net_margin_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_model,
    count(*)::bigint,
    count(*) filter (where l.program_status = 'profitable')::bigint,
    count(*) filter (where l.program_status = 'credit_heavy')::bigint,
    count(*) filter (where l.program_status = 'stuck_inventory')::bigint,
    count(*) filter (where l.program_status = 'loss_making')::bigint,
    round(100.0 * count(*) filter (where l.attach_to_new_sale = true)::numeric / nullif(count(*),0), 1),
    round(avg(l.net_program_margin_rupees), 0)
  from public.trade_in_r3716 l
  group by l.equipment_model
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3716_equipment_model_scorecard() from public, anon;
grant execute on function public.founder_r3716_equipment_model_scorecard() to authenticated;

-- 3) Route class x program status matrix
create or replace function public.founder_r3716_route_program_matrix()
returns table(route_class text, program_status text, trade_ins bigint, avg_net_margin_rupees numeric, avg_days_to_disposition numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.route_class, l.program_status, count(*)::bigint,
    round(avg(l.net_program_margin_rupees), 0),
    round(avg(l.days_to_disposition), 1)
  from public.trade_in_r3716 l
  group by l.route_class, l.program_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3716_route_program_matrix() from public, anon;
grant execute on function public.founder_r3716_route_program_matrix() to authenticated;

-- 4) Monthly margin trend
create or replace function public.founder_r3716_monthly_margin_trend()
returns table(
  period_month date,
  trade_ins bigint,
  total_valuation_rupees numeric,
  total_credit_issued_rupees numeric,
  total_resale_recovery_rupees numeric,
  total_net_margin_rupees numeric,
  stuck_inventory bigint
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
    coalesce(sum(l.valuation_rupees),0)::numeric,
    coalesce(sum(l.credit_issued_rupees),0)::numeric,
    coalesce(sum(l.resale_recovery_rupees),0)::numeric,
    coalesce(sum(l.net_program_margin_rupees),0)::numeric,
    count(*) filter (where l.program_status = 'stuck_inventory')::bigint
  from public.trade_in_r3716 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3716_monthly_margin_trend() from public, anon;
grant execute on function public.founder_r3716_monthly_margin_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3716_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.trade_in_capa_actions_r3716 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3716_capa_status_board() from public, anon;
grant execute on function public.founder_r3716_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3716_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.trade_in_capa_actions_r3716)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.trade_in_capa_actions_r3716 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3716_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3716_root_cause_pareto() to authenticated;

-- 7) Stuck-inventory digest by route class
create or replace function public.founder_r3716_stuck_inventory_digest()
returns table(
  route_class text,
  units bigint,
  avg_days_to_disposition numeric,
  total_valuation_rupees numeric,
  total_net_margin_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.route_class,
    count(*)::bigint,
    round(avg(l.days_to_disposition), 1),
    coalesce(sum(l.valuation_rupees),0)::numeric,
    coalesce(sum(l.net_program_margin_rupees),0)::numeric
  from public.trade_in_r3716 l
  where l.program_status = 'stuck_inventory'
     or l.route_class = 'pending_disposition'
  group by l.route_class
  order by avg(l.days_to_disposition) desc;
end;
$$;

revoke all on function public.founder_r3716_stuck_inventory_digest() from public, anon;
grant execute on function public.founder_r3716_stuck_inventory_digest() to authenticated;

-- 8) High-risk trade-in queue (loss-making / stuck inventory)
create or replace function public.founder_r3716_high_risk_queue()
returns table(
  trade_in_ref text,
  equipment_model text,
  customer_name text,
  period_month date,
  program_status text,
  route_class text,
  days_to_disposition int,
  net_program_margin_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.trade_in_ref, l.equipment_model, l.customer_name, l.period_month,
    l.program_status, l.route_class, l.days_to_disposition, l.net_program_margin_rupees, l.notes
  from public.trade_in_r3716 l
  where l.program_status in ('loss_making','stuck_inventory')
  order by l.net_program_margin_rupees asc, l.days_to_disposition desc;
end;
$$;

revoke all on function public.founder_r3716_high_risk_queue() from public, anon;
grant execute on function public.founder_r3716_high_risk_queue() to authenticated;
